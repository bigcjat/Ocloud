const { spawn, execSync } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');

function cmdGui(subcmd, args = [], context = {}) {
  const shellPath = path.join(__dirname, '..', '..', 'app', 'shell.qml');
  if (!fs.existsSync(shellPath)) {
    console.error(`Desktop app entry point not found at ${shellPath}`);
    process.exit(1);
  }

  // Single-Instance Enforcement: prevent duplicate Quickshell processes
  try {
    const existingPids = execSync('pgrep -f "quickshell.*shell\\.qml"', { encoding: 'utf8' }).trim();
    if (existingPids) {
      const pids = existingPids.split('\n').filter(Boolean);
      if (pids.length > 0) {
        console.log(`✔ Ocloud Desktop GUI is already running (PID: ${pids.join(', ')}). Bringing window to focus...`);
        // Attempt to focus the existing window via Hyprland IPC if running in Hyprland
        try {
          const sig = execSync('ls -1 /run/user/$(id -u)/hypr/ 2>/dev/null | head -n 1', { encoding: 'utf8' }).trim();
          if (sig) {
            execSync(`HYPRLAND_INSTANCE_SIGNATURE="${sig}" hyprctl dispatch focuswindow "title:Ocloud" 2>/dev/null || true`, { stdio: 'ignore' });
          }
        } catch (e) {}
        return;
      }
    }
  } catch (e) {
    // pgrep exited with non-zero (no process found), proceed to launch
  }

  const candidates = ['/usr/bin/quickshell', '/usr/local/bin/quickshell'];
  const qsBin = candidates.find(p => fs.existsSync(p)) || 'quickshell';
  const qsArgs = ['-p', shellPath];

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
