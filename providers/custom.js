const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const net = require('net');
const { CloudProvider, StorageProvider } = require('./base');

class CustomComputeProvider extends CloudProvider {
  constructor(vault) {
    super('custom', 'Custom & Home Rigs');
    this.vault = vault;
  }

  getServers() {
    return this.vault.get('custom_servers', []);
  }

  saveServers(servers) {
    this.vault.set('custom_servers', servers);
  }

  async checkHostOnline(host, port = 22, timeoutMs = 1200) {
    return new Promise((resolve) => {
      const socket = new net.Socket();
      socket.setTimeout(timeoutMs);
      socket.on('connect', () => {
        socket.destroy();
        resolve(true);
      });
      socket.on('timeout', () => {
        socket.destroy();
        resolve(false);
      });
      socket.on('error', () => {
        socket.destroy();
        resolve(false);
      });
      socket.connect(port, host);
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
    let servers = this.getServers();
    const before = servers.length;
    servers = servers.filter((s) => s.id !== idOrName && s.name !== idOrName);
    if (servers.length < before) {
      this.saveServers(servers);
      return true;
    }
    return false;
  }

  async inspectServer(serverOrHost) {
    const host = typeof serverOrHost === 'string' ? serverOrHost : (serverOrHost.ipv4 || serverOrHost.host);
    const user = serverOrHost.user || 'root';
    const port = serverOrHost.port || 22;
    const keyPath = serverOrHost.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');

    const remoteCmd =
      "echo '---CPU---' && cat /proc/loadavg && " +
      "echo '---MEM---' && free -b && " +
      "echo '---DISK---' && df -B1 / && " +
      "echo '---UPTIME---' && uptime -p && " +
      "echo '---PROCS---' && ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -n 6";

    const raw = execSync(
      `ssh -p ${port} -i "${keyPath}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ${user}@${host} "${remoteCmd}"`,
      { encoding: 'utf8' }
    );

    const data = { host, status: 'online' };
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
      data.ram_percent = data.ram_total
        ? Number(((data.ram_used / data.ram_total) * 100).toFixed(1))
        : 0;
    }
    if (sectionLines.DISK && sectionLines.DISK.length >= 2) {
      const parts = sectionLines.DISK[1].split(/\s+/);
      data.disk_total = parseInt(parts[1], 10) || 0;
      data.disk_used = parseInt(parts[2], 10) || 0;
      data.disk_percent = data.disk_total
        ? Number(((data.disk_used / data.disk_total) * 100).toFixed(1))
        : 0;
    }
    if (sectionLines.UPTIME && sectionLines.UPTIME.length > 0) {
      data.uptime = sectionLines.UPTIME[0];
    }

    const procs = [];
    if (sectionLines.PROCS) {
      for (const pline of sectionLines.PROCS.slice(1)) {
        const pcs = pline.split(/\s+/);
        if (pcs.length >= 4) {
          procs.push({ pid: pcs[0], cpu: pcs[1], mem: pcs[2], cmd: pcs[3] });
        }
      }
    }
    data.top_processes = procs;
    return data;
  }
}

class CustomStorageProvider extends StorageProvider {
  constructor(vault) {
    super('custom_storage', 'Home NAS & Custom SFTP');
    this.vault = vault;
  }

  getStorageTargets() {
    return this.vault.get('custom_storage', []);
  }

  saveStorageTargets(targets) {
    this.vault.set('custom_storage', targets);
  }

  isMounted(mountPoint) {
    try {
      const out = execSync('mount', { encoding: 'utf8' });
      return out.includes(mountPoint);
    } catch (e) {
      return false;
    }
  }

  async listStorage() {
    const targets = this.getStorageTargets();
    return targets.map((t) => ({
      ...t,
      mounted: this.isMounted(t.mountPoint)
    }));
  }

  async addTarget({ name, host, user, port = 22, remotePath = '/', mountPoint, isHomeStorage = false }) {
    const targets = this.getStorageTargets();
    const id = `storage-${Date.now().toString(36)}`;
    const newTarget = {
      id,
      name,
      host,
      user,
      port: Number(port) || 22,
      remotePath: remotePath || '/',
      mountPoint: mountPoint || path.join(os.homedir(), name.replace(/\s+/g, '-')),
      isHomeStorage: Boolean(isHomeStorage)
    };
    targets.push(newTarget);
    this.saveStorageTargets(targets);
    return newTarget;
  }

  async removeTarget(idOrName) {
    let targets = this.getStorageTargets();
    const before = targets.length;
    targets = targets.filter((t) => t.id !== idOrName && t.name !== idOrName);
    if (targets.length < before) {
      this.saveStorageTargets(targets);
      return true;
    }
    return false;
  }

  async mount(targetId) {
    const targets = this.getStorageTargets();
    const target = targets.find((t) => t.id === targetId || t.name === targetId);
    if (!target) throw new Error(`Storage target not found: ${targetId}`);

    if (this.isMounted(target.mountPoint)) {
      return { success: true, message: `Already mounted at ${target.mountPoint}` };
    }

    fs.mkdirSync(target.mountPoint, { recursive: true });
    const keyPath = path.join(os.homedir(), '.ssh', 'id_ed25519');
    const rcloneBin = [
      path.join(os.homedir(), '.local', 'bin', 'rclone'),
      '/usr/bin/rclone'
    ].find((p) => fs.existsSync(p)) || 'rclone';

    // Configure rclone remote dynamically
    const remoteName = `remote-${target.id}`;
    const rcloneConfPath = path.join(os.homedir(), '.config', 'rclone', 'rclone.conf');
    fs.mkdirSync(path.dirname(rcloneConfPath), { recursive: true });
    let conf = fs.existsSync(rcloneConfPath) ? fs.readFileSync(rcloneConfPath, 'utf8') : '';
    const block = `\n[${remoteName}]\ntype = sftp\nhost = ${target.host}\nuser = ${target.user}\nport = ${target.port || 22}\nkey_file = ${keyPath}\nshell_type = unix\n`;
    if (!conf.includes(`[${remoteName}]`)) {
      conf += block;
      fs.writeFileSync(rcloneConfPath, conf, { mode: 0o600 });
    }

    execSync(`${rcloneBin} mount ${remoteName}:${target.remotePath} "${target.mountPoint}" --vfs-cache-mode full --daemon`, { stdio: 'inherit' });
    return { success: true, mount_point: target.mountPoint };
  }

  async unmount(targetId) {
    const targets = this.getStorageTargets();
    const target = targets.find((t) => t.id === targetId || t.name === targetId);
    if (!target) throw new Error(`Storage target not found: ${targetId}`);

    if (!this.isMounted(target.mountPoint)) {
      return { success: true, message: `${target.mountPoint} is not mounted.` };
    }
    execSync(`umount "${target.mountPoint}" || fusermount3 -u "${target.mountPoint}" || fusermount -u "${target.mountPoint}"`, { stdio: 'inherit' });
    return { success: true, unmounted: target.mountPoint };
  }
}

module.exports = { CustomComputeProvider, CustomStorageProvider };
