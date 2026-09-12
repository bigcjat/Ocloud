const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { CloudProvider, StorageProvider } = require('./base');

const API_BASE = 'https://api.hetzner.cloud/v1';

class HetznerCloudProvider extends CloudProvider {
  constructor(vault) {
    super('hetzner', 'Hetzner Cloud');
    this.vault = vault;
  }

  getToken() {
    return process.env.HETZNER_API_TOKEN || this.vault.get('api_token', '');
  }

  async _request(method, endpoint, body = null) {
    const token = this.getToken();
    if (!token) throw new Error('Hetzner API token is missing in Ocloud Vault.');
    const res = await fetch(`${API_BASE}${endpoint}`, {
      method,
      headers: {
        Authorization: `Bearer ${token.trim()}`,
        'Content-Type': 'application/json',
        'User-Agent': 'Ocloud/1.0'
      },
      body: body ? JSON.stringify(body) : undefined
    });
    const text = await res.text();
    let json = {};
    try {
      json = text ? JSON.parse(text) : {};
    } catch (e) {}

    if (!res.ok) {
      const msg = json.error?.message || `HTTP ${res.status}: ${res.statusText}`;
      throw new Error(msg);
    }
    return json;
  }

  async listServers() {
    const token = this.getToken();
    if (!token) return [];
    try {
      const data = await this._request('GET', '/servers');
      return (data.servers || []).map((s) => ({
        id: s.id,
        name: s.name,
        status: s.status,
        type: s.server_type?.name || 'cx23',
        ipv4: s.public_net?.ipv4?.ip || 'no IP',
        location: s.datacenter?.location?.name || 'nbg1',
        provider: 'hetzner',
        datacenter: s.datacenter?.name,
        created: s.created,
        tags: ['cloud', 'hetzner'],
        isHomeWorkstation: false
      }));
    } catch (err) {
      console.error(`[Hetzner] Failed to list servers: ${err.message}`);
      return [];
    }
  }

  async createServer({ name, type = 'cx23', location = 'nbg1', tailscaleKey = null, sshKeys = ['omarchy-laptop'] }) {
    let userData = null;
    if (tailscaleKey) {
      userData = `#!/bin/bash\ncurl -fsSL https://tailscale.com/install.sh | sh\ntailscale up --authkey=${tailscaleKey} --hostname=${name}\n`;
    }

    const payload = {
      name,
      server_type: type,
      location,
      image: 'ubuntu-24.04',
      start_after_create: true,
      ssh_keys: sshKeys
    };
    if (userData) payload.user_data = userData;

    const res = await this._request('POST', '/servers', payload);
    return res.server;
  }

  async startServer(id) {
    return this._request('POST', `/servers/${id}/actions/poweron`);
  }

  async stopServer(id) {
    return this._request('POST', `/servers/${id}/actions/poweroff`);
  }

  async rebootServer(id) {
    return this._request('POST', `/servers/${id}/actions/reboot`);
  }

  async deleteServer(id) {
    return this._request('DELETE', `/servers/${id}`);
  }

  async inspectServer(serverOrIp) {
    const ip = typeof serverOrIp === 'string' ? serverOrIp : serverOrIp.ipv4;
    const keyPath = path.join(os.homedir(), '.ssh', 'id_ed25519');
    const remoteCmd =
      "echo '---CPU---' && cat /proc/loadavg && " +
      "echo '---MEM---' && free -b && " +
      "echo '---DISK---' && df -B1 / && " +
      "echo '---UPTIME---' && uptime -p && " +
      "echo '---PROCS---' && ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -n 6";

    const raw = execSync(
      `ssh -i "${keyPath}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${ip} "${remoteCmd}"`,
      { encoding: 'utf8' }
    );

    const data = { ip, status: 'online' };
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

function resolveMountPath(p) {
  if (!p) return path.join(os.homedir(), 'Cloud');
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  if (p === '~') return os.homedir();
  return path.resolve(p);
}

class HetznerStorageBoxProvider extends StorageProvider {
  constructor(vault) {
    super('hetzner_storage_box', 'Hetzner Storage Box');
    this.vault = vault;
  }

  getConfig() {
    return this.vault.get('storage_box', {
      username: '',
      host: '',
      password: '',
      port: 23,
      mount_point: path.join(os.homedir(), 'Cloud'),
      backup_source: os.homedir()
    });
  }

  isMounted(mountPoint) {
    try {
      const out = execSync('mount', { encoding: 'utf8' });
      return out.includes(mountPoint);
    } catch (e) {
      return false;
    }
  }

  async getStats() {
    const sb = this.getConfig();
    const mountPoint = resolveMountPath(sb.mount_point);
    const mounted = this.isMounted(mountPoint);
    const configured = Boolean(sb.username && sb.host);

    let totalBytes = 0;
    let usedBytes = 0;
    let usedPercent = 0.0;

    if (configured) {
      try {
        const rcloneBin = [
          path.join(os.homedir(), '.local', 'bin', 'rclone'),
          '/usr/bin/rclone'
        ].find((p) => fs.existsSync(p)) || 'rclone';
        const out = execSync(`${rcloneBin} about storagebox: --json 2>/dev/null`, { encoding: 'utf8', timeout: 12000 });
        const parsed = JSON.parse(out);
        if (parsed && typeof parsed.total === 'number') {
          totalBytes = parsed.total;
          usedBytes = parsed.used || 0;
          if (totalBytes > 0) {
            usedPercent = Number(((usedBytes / totalBytes) * 100).toFixed(2));
          }
        }
      } catch (e) {}
    }

    let lastBackup = null;
    const backupFile = path.join(os.homedir(), '.config', 'omarchy', 'backup_status.json');
    if (fs.existsSync(backupFile)) {
      try {
        lastBackup = JSON.parse(fs.readFileSync(backupFile, 'utf8'));
      } catch (e) {}
    }

    return {
      configured,
      username: sb.username,
      host: sb.host,
      mounted,
      mount_point: mountPoint,
      total_bytes: totalBytes,
      used_bytes: usedBytes,
      used_percent: usedPercent,
      last_backup: lastBackup
    };
  }

  async mount(customMountPoint = null, openFileManager = true) {
    const sb = this.getConfig();
    const mountPoint = resolveMountPath(customMountPoint || sb.mount_point);
    if (!this.isMounted(mountPoint)) {
      fs.mkdirSync(mountPoint, { recursive: true });
      const rcloneBin = [
        path.join(os.homedir(), '.local', 'bin', 'rclone'),
        '/usr/bin/rclone'
      ].find((p) => fs.existsSync(p)) || 'rclone';

      execSync(`${rcloneBin} mount storagebox: "${mountPoint}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1 || true`);
      for (let i = 0; i < 16; i++) {
        if (this.isMounted(mountPoint)) break;
        execSync('sleep 0.5');
      }
    }

    if (openFileManager && this.isMounted(mountPoint)) {
      try {
        const { spawn } = require('child_process');
        spawn('xdg-open', [mountPoint], { detached: true, stdio: 'ignore' }).unref();
      } catch (e) {}
    }

    return { success: true, mount_point: mountPoint, mounted: this.isMounted(mountPoint) };
  }

  async unmount(customMountPoint = null) {
    const sb = this.getConfig();
    const mountPoint = resolveMountPath(customMountPoint || sb.mount_point);
    if (!this.isMounted(mountPoint)) {
      return { success: true, message: `${mountPoint} is not mounted.` };
    }
    execSync(`fusermount3 -u "${mountPoint}" || fusermount -u "${mountPoint}" || umount "${mountPoint}" || true`);
    return { success: true, unmounted: mountPoint, mounted: false };
  }
}

module.exports = { HetznerCloudProvider, HetznerStorageBoxProvider };
