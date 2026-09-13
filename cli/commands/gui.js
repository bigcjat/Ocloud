const { spawn } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

function cmdGui(subcmd, args = [], context = {}) {
  const shellPath = path.join(__dirname, '..', '..', 'app', 'shell.qml');
  if (!fs.existsSync(shellPath)) {
    console.error(`Desktop app entry point not found at ${shellPath}`);
    process.exit(1);
  }

  const candidates = ['/usr/bin/quickshell', '/usr/local/bin/quickshell'];
  const qsBin = candidates.find(p => fs.existsSync(p)) || 'quickshell';
  const qsArgs = ['-p', shellPath];
  if (subcmd && subcmd !== 'open' && subcmd !== 'start') {
    qsArgs.push('--', subcmd, ...(args || []));
  } else if (args && args.length > 0) {
    qsArgs.push('--', ...args);
  }

  const vault = context && context.vault ? context.vault : null;
  const env = {
    ...process.env,
    WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-1'
  };
  if (vault) {
    env.RCLONE_CONFIG_PASS = vault.getRcloneConfigPass();
  }

  const knownTabs = ['fleet', 'workloads', 'storage', 'accounts', 'shares', 'apps', 'backups', 'settings'];
  if (subcmd) {
    if (knownTabs.includes(subcmd.toLowerCase())) {
      env.OCLOUD_TAB = subcmd.toLowerCase();
    } else if (subcmd !== 'open' && subcmd !== 'start') {
      env.OCLOUD_MODAL = subcmd;
    }
  }

  console.log(`Launching Ocloud Desktop GUI (Quickshell QML / JS)...`);
  const child = spawn(qsBin, qsArgs, {
    stdio: 'inherit',
    detached: true,
    env
  });
  child.unref();
}

module.exports = { cmdGui };
