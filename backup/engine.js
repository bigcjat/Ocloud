const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

class BackupEngine {
  constructor(vault) {
    this.vault = vault;
    this.backupDir = path.join(os.homedir(), '.config', 'omarchy', 'backups');
    this.historyFile = path.join(this.backupDir, 'history.json');
    this.scheduleFile = path.join(this.backupDir, 'schedule.json');
  }

  _ensureDir() {
    if (!fs.existsSync(this.backupDir)) {
      fs.mkdirSync(this.backupDir, { recursive: true });
    }
  }

  getHistory() {
    this._ensureDir();
    if (!fs.existsSync(this.historyFile)) return [];
    try {
      return JSON.parse(fs.readFileSync(this.historyFile, 'utf8'));
    } catch (e) {
      return [];
    }
  }

  _recordBackup(entry) {
    this._ensureDir();
    const history = this.getHistory();
    history.unshift(entry);
    // Keep last 50 backup records
    if (history.length > 50) history.length = 50;
    fs.writeFileSync(this.historyFile, JSON.stringify(history, null, 2));

    // Also update legacy backup_status.json for compatibility
    const legacyFile = path.join(os.homedir(), '.config', 'omarchy', 'backup_status.json');
    fs.writeFileSync(legacyFile, JSON.stringify(entry, null, 2));
  }

  getSchedule() {
    this._ensureDir();
    if (!fs.existsSync(this.scheduleFile)) {
      return { enabled: false, interval: 'daily', time: '03:00' };
    }
    try {
      return JSON.parse(fs.readFileSync(this.scheduleFile, 'utf8'));
    } catch (e) {
      return { enabled: false, interval: 'daily', time: '03:00' };
    }
  }

  setSchedule({ enabled, interval = 'daily', time = '03:00' }) {
    this._ensureDir();
    const config = { enabled, interval, time, updated_at: new Date().toISOString() };
    fs.writeFileSync(this.scheduleFile, JSON.stringify(config, null, 2));
    this._syncCronOrTimer(config);
    return config;
  }

  _syncCronOrTimer(config) {
    // Generate/update systemd user timer or crontab if available
    try {
      const crontab = execSync('crontab -l 2>/dev/null || true', { encoding: 'utf8' });
      let lines = crontab.split('\n').filter((l) => !l.includes('ocloud backup run'));
      if (config.enabled) {
        let cronTime = '0 3 * * *'; // default daily 3am
        if (config.interval === 'hourly') cronTime = '0 * * * *';
        else if (config.interval === 'weekly') cronTime = '0 3 * * 0';
        lines.push(`${cronTime} /usr/bin/env ocloud backup run --auto >> ~/.config/omarchy/backups/cron.log 2>&1`);
      }
      const newCrontab = lines.filter(Boolean).join('\n') + '\n';
      execSync(`echo "${newCrontab}" | crontab -`);
    } catch (e) {
      // crontab might not be permitted or installed; non-fatal
    }
  }

  async runBackup(options = {}) {
    const sb = this.vault.get('storage_box', {});
    const sourceDir = options.source || sb.backup_source || os.homedir();
    const snapshotName = `snapshot-${new Date().toISOString().replace(/[:.]/g, '-')}`;
    const destination = options.destination || `storagebox:backups/${snapshotName}`;

    console.log(`Starting backup: ${sourceDir} -> ${destination}`);
    const rcloneBin = [
      path.join(os.homedir(), '.local', 'bin', 'rclone'),
      '/usr/bin/rclone'
    ].find((p) => fs.existsSync(p)) || 'rclone';

    const startTime = Date.now();
    let status = 'success';
    let errorMessage = null;
    let filesTransferred = 0;
    let bytesTransferred = 0;

    try {
      // Run rclone copy with exclude filters for temporary / cache directories
      const excludes = [
        '--exclude', '.cache/**',
        '--exclude', '.local/share/Trash/**',
        '--exclude', 'node_modules/**',
        '--exclude', '.npm/**',
        '--exclude', '.cargo/registry/**'
      ];
      const cmd = [rcloneBin, 'copy', sourceDir, destination, ...excludes, '--stats-one-line', '-v'];
      const res = execSync(cmd.join(' '), { encoding: 'utf8', timeout: 120000 });
      // Estimate stats
      const match = res.match(/Transferred:\s+([0-9.]+\s+[A-Za-z]+)/);
      if (match) bytesTransferred = match[1];
    } catch (err) {
      status = 'failed';
      errorMessage = err.message;
      console.error(`Backup error: ${err.message}`);
    }

    const durationSeconds = Math.round((Date.now() - startTime) / 1000);
    const record = {
      id: snapshotName,
      timestamp: new Date().toISOString(),
      status,
      duration_seconds: durationSeconds,
      source: sourceDir,
      destination,
      bytes_transferred: bytesTransferred || '0 B',
      error: errorMessage
    };

    this._recordBackup(record);
    return record;
  }

  listSnapshots() {
    return this.getHistory();
  }
}

module.exports = { BackupEngine };
