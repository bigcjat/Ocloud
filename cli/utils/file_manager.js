const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn, spawnSync } = require('child_process');
const { resolveMountPath } = require('./format');

function loadSettings() {
  const cfgPath = path.join(os.homedir(), '.config', 'ocloud', 'settings.json');
  const defaults = {
    fileManager: 'default',
    customFileManagerCmd: '',
    probeMountsBeforeOpen: true,
    probeTimeoutSeconds: 2,
    autoMountRemotes: [],
    recent_apps: []
  };

  if (fs.existsSync(cfgPath)) {
    try {
      const data = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
      return Object.assign(defaults, data);
    } catch (e) {}
  }
  return defaults;
}

function findBinary(binName) {
  const candidates = [
    path.join(os.homedir(), '.local', 'bin', binName),
    `/usr/bin/${binName}`,
    `/usr/local/bin/${binName}`
  ];
  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return binName;
}

function getDefaultFileManager() {
  const cfg = loadSettings();
  if (cfg.fileManager && cfg.fileManager !== 'default') {
    return cfg.fileManager;
  }
  if (process.platform === 'linux') {
    try {
      const out = spawnSync('xdg-mime', ['query', 'default', 'inode/directory'], {
        encoding: 'utf8',
        timeout: 1000
      });
      const mime = (out.stdout || '').trim().toLowerCase();
      if (mime.includes('flea')) return 'flea';
      if (mime.includes('nautilus')) return 'nautilus';
      if (mime.includes('dolphin')) return 'dolphin';
      if (mime.includes('thunar')) return 'thunar';
    } catch (e) {}
  }
  return 'default';
}

function isFleaDefault() {
  const fm = getDefaultFileManager();
  if (fm === 'flea') return true;
  if (fm === 'default' && process.platform === 'linux') {
    try {
      const out = spawnSync('xdg-mime', ['query', 'default', 'inode/directory'], { encoding: 'utf8', timeout: 1000 });
      if ((out.stdout || '').toLowerCase().includes('flea')) return true;
    } catch (e) {}
  }
  return false;
}

function resolveFileManagerCommand(targetPath, settings) {
  const cfg = settings || loadSettings();
  const fmId = cfg.fileManager || 'default';
  const customCmd = (cfg.customFileManagerCmd || '').trim();
  const resolvedPath = resolveMountPath(targetPath);

  if (fmId === 'flea') {
    return [findBinary('flea'), '--gui', resolvedPath];
  }

  if (fmId === 'nautilus') {
    return [findBinary('nautilus'), '--new-window', resolvedPath];
  }

  if (fmId === 'thunar') {
    return [findBinary('thunar'), resolvedPath];
  }

  if (fmId === 'dolphin') {
    return [findBinary('dolphin'), resolvedPath];
  }

  if (fmId === 'custom' && customCmd.length > 0) {
    const parts = customCmd.match(/(?:[^\s"']+|"[^"]*"|'[^']*')+/g) || [customCmd];
    const cleanParts = parts.map(p => p.replace(/^["']|["']$/g, ''));
    cleanParts.push(resolvedPath);
    return cleanParts;
  }

  const defaultOpener = process.platform === 'darwin' ? 'open' : 'xdg-open';
  return [defaultOpener, resolvedPath];
}

function probeMount(targetPath, timeoutSec = 2) {
  try {
    const res = spawnSync('timeout', [String(timeoutSec), 'ls', '-A', targetPath], {
      stdio: 'ignore',
      timeout: (timeoutSec + 1) * 1000
    });
    return res.status === 0;
  } catch (e) {
    return true;
  }
}

function launchFileManager(targetPath) {
  const expPath = resolveMountPath(targetPath);
  const settings = loadSettings();

  if (!fs.existsSync(expPath)) {
    console.error(`Folder does not exist or is not mounted: ${expPath}`);
    return false;
  }

  if (settings.probeMountsBeforeOpen) {
    const timeoutSec = parseInt(settings.probeTimeoutSeconds, 10) || 2;
    const isOk = probeMount(expPath, timeoutSec);
    if (!isOk) {
      console.error(`Drive at ${expPath} is unresponsive. File manager opening prevented to avoid freezing desktop.`);
      return false;
    }
  }

  const tokens = resolveFileManagerCommand(expPath, settings);
  const bin = tokens[0];
  const args = tokens.slice(1);

  const env = Object.assign({}, process.env);
  env.FLEA_PATH = expPath;
  const localBin = path.join(os.homedir(), '.local', 'bin');
  if (!env.PATH || !env.PATH.includes(localBin)) {
    env.PATH = `${localBin}:${env.PATH || ''}`;
  }

  try {
    const child = spawn(bin, args, {
      detached: true,
      stdio: 'ignore',
      env
    });
    child.on('error', (err) => {
      console.error(`Failed to launch file manager (${bin}): ${err.message}`);
    });
    child.unref();
    return true;
  } catch (e) {
    console.error(`Failed to spawn file manager: ${e.message}`);
    return false;
  }
}

module.exports = {
  loadSettings,
  findBinary,
  getDefaultFileManager,
  isFleaDefault,
  resolveFileManagerCommand,
  probeMount,
  launchFileManager
};
