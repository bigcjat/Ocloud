const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const net = require('net');
const { BaseComputeDriver } = require('../../../base');

class CustomComputeDriver extends BaseComputeDriver {
  constructor(manifest, context = {}) {
    super(manifest);
    if (context && typeof context.get === 'function') {
      this.credentials = {
        custom_servers: context.get('custom_servers', [])
      };
      this.vault = context;
    } else if (context && context.credentials) {
      this.credentials = context.credentials;
      this.saveCredentials = context.saveCredentials;
    } else {
      this.credentials = context || {};
    }
  }

  getServers() {
    if (this.credentials && this.credentials.custom_servers) {
      return this.credentials.custom_servers;
    }
    return this.vault ? this.vault.get('custom_servers', []) : [];
  }

  saveServers(servers) {
    if (this.credentials) {
      this.credentials.custom_servers = servers;
    }
    if (typeof this.saveCredentials === 'function') {
      this.saveCredentials({ custom_servers: servers });
    } else if (this.vault) {
      this.vault.set('custom_servers', servers);
    }
  }

  async checkHostOnline(host, port = 22, timeoutMs = 1200) {
    const tcpResult = await new Promise((resolve) => {
      const socket = new net.Socket();
      socket.setTimeout(timeoutMs);
      socket.on('connect', () => {
        socket.destroy();
        resolve('online');
      });
      socket.on('timeout', () => {
        socket.destroy();
        resolve('timeout');
      });
      socket.on('error', (err) => {
        socket.destroy();
        if (err && err.code === 'ECONNREFUSED') {
          resolve('refused');
        } else {
          resolve('error');
        }
      });
      socket.connect(port, host);
    });

    if (tcpResult === 'online') return true;

    return new Promise((resolve) => {
      const pingCmd = process.platform === 'win32' ? `ping -n 1 -w 1000 ${host}` : `ping -c 1 -W 1 ${host}`;
      require('child_process').exec(pingCmd, (err) => {
        resolve(!err);
      });
    });
  }

  async listServers() {
    const list = this.getServers();
    const results = await Promise.all(
      list.map(async (s) => {
        const isOnline = await this.checkHostOnline(s.host, s.port || 22);
        return {
          id: s.id || `custom-${s.name.toLowerCase().replace(/[^a-z0-9]/g, '-')}`,
          name: s.name,
          status: isOnline ? 'running' : 'offline',
          type: s.type || (s.isHomeWorkstation ? 'workstation' : 'baremetal'),
          ipv4: s.host,
          user: s.user || 'root',
          port: s.port || 22,
          keyPath: s.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519'),
          location: s.location || (s.isHomeWorkstation ? 'Home/Tailscale' : 'Custom'),
          provider: 'custom',
          providerName: 'Custom Rig',
          providerIcon: this.manifest ? this.manifest.iconDataUri : null,
          tags: s.tags || (s.isHomeWorkstation ? ['home', 'workstation'] : ['dedicated', 'custom']),
          isHomeWorkstation: Boolean(s.isHomeWorkstation)
        };
      })
    );
    return results;
  }

  async addServer({ name, host, user = 'root', port = 22, keyPath = null, isHomeWorkstation = false, type = 'baremetal', location = 'Custom' }) {
    const servers = this.getServers();
    const id = `custom-${Date.now().toString(36)}`;
    const newServer = {
      id,
      name,
      host,
      user,
      port: Number(port) || 22,
      keyPath: keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519'),
      isHomeWorkstation: Boolean(isHomeWorkstation),
      type: isHomeWorkstation ? 'workstation' : type,
      location: isHomeWorkstation ? 'Home/Tailscale' : location,
      tags: isHomeWorkstation ? ['home', 'workstation'] : ['custom']
    };
    servers.push(newServer);
    this.saveServers(servers);
    return newServer;
  }

  async removeServer(idOrName) {
    const servers = this.getServers().filter(
      (s) => s.id !== idOrName && s.name.toLowerCase() !== idOrName.toLowerCase()
    );
    this.saveServers(servers);
    return true;
  }

  async createServer(opts) {
    return this.addServer(opts);
  }

  async startServer(id) {
    return { ok: true, message: 'Custom server is an external host; cannot send hardware wake unless WoL configured.' };
  }

  async stopServer(id) {
    const server = this.getServers().find((s) => s.id === id);
    if (!server) throw new Error(`Custom server not found: ${id}`);
    const key = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
    execSync(`ssh -i "${key}" -p ${server.port || 22} -o ConnectTimeout=5 ${server.user || 'root'}@${server.host} "systemctl poweroff || shutdown -h now"`);
    return { ok: true };
  }

  async rebootServer(id) {
    const server = this.getServers().find((s) => s.id === id);
    if (!server) throw new Error(`Custom server not found: ${id}`);
    const key = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
    execSync(`ssh -i "${key}" -p ${server.port || 22} -o ConnectTimeout=5 ${server.user || 'root'}@${server.host} "systemctl reboot || reboot"`);
    return { ok: true };
  }

  async deleteServer(id) {
    return this.removeServer(id);
  }

  async inspectServer(serverOrIp) {
    const host = typeof serverOrIp === 'string' ? serverOrIp : serverOrIp.ipv4;
    const key = (typeof serverOrIp === 'object' && serverOrIp.keyPath) || path.join(os.homedir(), '.ssh', 'id_ed25519');
    const user = (typeof serverOrIp === 'object' && serverOrIp.user) || 'root';
    const port = (typeof serverOrIp === 'object' && serverOrIp.port) || 22;

    const remoteCmd =
      "echo '---CPU---' && cat /proc/loadavg && " +
      "echo '---MEM---' && free -b && " +
      "echo '---DISK---' && df -B1 / && " +
      "echo '---UPTIME---' && uptime -p && " +
      "echo '---PROCS---' && ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -n 6";

    const raw = execSync(
      `ssh -i "${key}" -p ${port} -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${user}@${host} "${remoteCmd}"`,
      { encoding: 'utf8' }
    );

    const data = { ip: host, status: 'online' };
    const sectionLines = {};
    let curSec = null;
    for (const l of raw.split('\n')) {
      const line = l.trim();
      if (line.startsWith('---') && line.endsWith('---')) {
        curSec = line.replace(/-/g, '');
        sectionLines[curSec] = [];
      } else if (curSec && line) {
        sectionLines[curSec].push(line);
      }
    }

    if (sectionLines.CPU && sectionLines.CPU.length > 0) {
      const parts = sectionLines.CPU[0].split(/\s+/);
      data.load_1m = parseFloat(parts[0]) || 0;
      data.load_5m = parseFloat(parts[1]) || 0;
      data.load_15m = parseFloat(parts[2]) || 0;
    }
    if (sectionLines.MEM && sectionLines.MEM.length >= 2) {
      const parts = sectionLines.MEM[1].split(/\s+/);
      data.ram_total = parseInt(parts[1], 10) || 0;
      data.ram_used = parseInt(parts[2], 10) || 0;
      data.ram_percent = data.ram_total ? Number(((data.ram_used / data.ram_total) * 100).toFixed(1)) : 0;
    }
    if (sectionLines.DISK && sectionLines.DISK.length >= 2) {
      const parts = sectionLines.DISK[1].split(/\s+/);
      data.disk_total = parseInt(parts[1], 10) || 0;
      data.disk_used = parseInt(parts[2], 10) || 0;
      data.disk_percent = data.disk_total ? Number(((data.disk_used / data.disk_total) * 100).toFixed(1)) : 0;
    }
    if (sectionLines.UPTIME && sectionLines.UPTIME.length > 0) {
      data.uptime = sectionLines.UPTIME[0].replace(/^up\s+/, '');
    }

    return data;
  }
}

module.exports = CustomComputeDriver;
