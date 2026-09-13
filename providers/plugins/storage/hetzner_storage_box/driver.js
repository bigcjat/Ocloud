const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { BaseStorageDriver } = require('../../../base');

function resolveMountPath(p) {
  if (!p) return path.join(os.homedir(), 'Cloud');
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  if (p === '~') return os.homedir();
  return path.resolve(p);
}

class HetznerStorageBoxDriver extends BaseStorageDriver {
  constructor(manifest, context = {}) {
    super(manifest);
    if (context && typeof context.get === 'function') {
      this.vault = context;
      this.credentials = context.get('storage_box', {});
    } else if (context && context.credentials) {
      this.credentials = context.credentials;
      this.saveCredentials = context.saveCredentials;
    } else {
      this.credentials = context || {};
    }
  }

  getConfig() {
    if (this.credentials && (this.credentials.username || this.credentials.host)) {
      return {
        username: '',
        host: '',
        password: '',
        port: 23,
        mount_point: path.join(os.homedir(), 'Cloud'),
        backup_source: os.homedir(),
        ...this.credentials
      };
    }
    return this.vault ? this.vault.get('storage_box', {
      username: '',
      host: '',
      password: '',
      port: 23,
      mount_point: path.join(os.homedir(), 'Cloud'),
      backup_source: os.homedir()
    }) : {};
  }

  isMounted(mountPoint) {
    try {
      const { isDriveMounted } = require('../../../../cli/utils/format');
      return isDriveMounted(mountPoint);
    } catch (e) {
      try {
        const out = execSync('mount', { encoding: 'utf8' });
        return out.includes(mountPoint);
      } catch (err) {
        return false;
      }
    }
  }

  async getStats(options = {}) {
    const forceRefresh = Boolean(options.forceRefresh);
    const sb = this.getConfig();
    const mountPoint = resolveMountPath(sb.mount_point);
    const mounted = this.isMounted(mountPoint);
    const configured = Boolean(sb.username && sb.host);

    let totalBytes = 1073741824000;
    let usedBytes = 262144;
    let usedPercent = 0.0;

    const cacheFile = path.join(os.homedir(), '.config', 'omarchy', 'storagebox_cache.json');
    let cacheValid = false;

    if (!forceRefresh && fs.existsSync(cacheFile)) {
      try {
        const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
        if (cached && (Date.now() - (cached.timestamp || 0) < 300000)) {
          totalBytes = cached.totalBytes || totalBytes;
          usedBytes = cached.usedBytes || usedBytes;
          usedPercent = cached.usedPercent || usedPercent;
          cacheValid = true;
        }
      } catch (e) {}
    }

    if (configured && !cacheValid) {
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
          try {
            fs.mkdirSync(path.dirname(cacheFile), { recursive: true });
            fs.writeFileSync(cacheFile, JSON.stringify({
              timestamp: Date.now(),
              totalBytes,
              usedBytes,
              usedPercent
            }), 'utf8');
          } catch (e) {}
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

      const logFile = `/tmp/rclone-mount-storagebox.log`;
      try {
        execSync(`${rcloneBin} mount storagebox: "${mountPoint}" --vfs-cache-mode full --daemon --log-file="${logFile}" </dev/null >/dev/null 2>&1`);
      } catch (e) {}

      for (let i = 0; i < 20; i++) {
        if (this.isMounted(mountPoint)) break;
        await new Promise(r => setTimeout(r, 500));
      }
    }

    const mounted = this.isMounted(mountPoint);
    if (!mounted) {
      let errDetails = '';
      try {
        const logFile = `/tmp/rclone-mount-storagebox.log`;
        if (fs.existsSync(logFile)) errDetails = fs.readFileSync(logFile, 'utf8').trim();
      } catch(e) {}
      throw new Error(`Failed to mount Storage Box: ${errDetails || 'Mount connection timed out'}`);
    }

    if (openFileManager) {
      try {
        const { launchFileManager } = require('../../../../cli/utils/file_manager');
        launchFileManager(mountPoint);
      } catch (e) {
        try {
          const { spawn } = require('child_process');
          spawn('xdg-open', [mountPoint], { detached: true, stdio: 'ignore' }).unref();
        } catch (err) {}
      }
    }

    return { success: true, mount_point: mountPoint, mounted: true };
  }

  async unmount(customMountPoint = null) {
    const sb = this.getConfig();
    const mountPoint = resolveMountPath(customMountPoint || sb.mount_point);
    if (!this.isMounted(mountPoint)) {
      return { success: true, message: `${mountPoint} is not mounted.` };
    }
    const { safeUnmount } = require('../../../../cli/utils/format');
    const ok = safeUnmount(mountPoint);
    return { success: ok, unmounted: mountPoint, mounted: !ok };
  }
}

module.exports = HetznerStorageBoxDriver;
