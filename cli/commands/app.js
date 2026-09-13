const { spawn, execSync } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');
const { loadSettings } = require('../utils/file_manager');

function getWaypipeBin() {
  const candidates = [
    path.join(os.homedir(), '.local', 'bin', 'waypipe'),
    '/usr/bin/waypipe',
    '/usr/local/bin/waypipe'
  ];
  const found = candidates.find(p => fs.existsSync(p));
  if (found) return found;

  try {
    const out = execSync('command -v waypipe 2>/dev/null', { encoding: 'utf8' }).trim();
    if (out) return out;
  } catch (e) {}

  return null;
}

function getSettingsPath() {
  return path.join(os.homedir(), '.config', 'ocloud', 'settings.json');
}

function recordRecentApp(cmdStr) {
  try {
    const settings = loadSettings();
    let recent = settings.recent_apps || [];
    const cleanCmd = cmdStr.trim();
    if (!cleanCmd) return;

    // Deduplicate
    recent = recent.filter(a => (typeof a === 'string' ? a : a.cmd) !== cleanCmd);
    
    const baseName = cleanCmd.split(' ')[0].split('/').pop();
    const appEntry = {
      id: cleanCmd.toLowerCase().replace(/[^a-z0-9]/g, '-'),
      name: baseName.charAt(0).toUpperCase() + baseName.slice(1),
      cmd: cleanCmd,
      lastRun: Date.now()
    };
    recent.unshift(appEntry);
    if (recent.length > 24) recent.length = 24;

    settings.recent_apps = recent;
    const cfgPath = getSettingsPath();
    fs.mkdirSync(path.dirname(cfgPath), { recursive: true });
    fs.writeFileSync(cfgPath, JSON.stringify(settings, null, 2), 'utf8');
  } catch (e) {}
}

const BUILTIN_APPS = [
  { id: 'arcade', name: 'Omarchy Arcade', cmd: 'arcade', tag: 'ARCADE', desc: 'Sovereign standalone retro arcade suite running standalone QML.', featured: true },
  { id: 'foot', name: 'Foot Terminal', cmd: 'foot', tag: 'TERMINAL', desc: 'Fast, lightweight, and minimalistic Wayland native terminal emulator.', featured: false },
  { id: 'gimp', name: 'GIMP', cmd: 'gimp', tag: 'GRAPHICS', desc: 'GNU Image Manipulation Program for remote photo editing.', featured: false },
  { id: 'firefox', name: 'Firefox', cmd: 'firefox', tag: 'BROWSER', desc: 'Secure web browsing streaming directly from your cloud node.', featured: false },
  { id: 'blender', name: 'Blender', cmd: 'blender', tag: '3D', desc: 'Open source 3D graphics creation suite with remote GPU rendering.', featured: false },
  { id: 'mpv', name: 'MPV Player', cmd: 'mpv', tag: 'MEDIA', desc: 'High performance media player with hardware acceleration over Waypipe.', featured: false }
];

async function cmdApp(subcmd, rest, context = {}) {
  const { registry } = context;

  if (subcmd === 'list' || subcmd === 'shortcuts') {
    const settings = loadSettings();
    const recent = (settings.recent_apps || []).map(a => typeof a === 'string' ? { id: a, name: a, cmd: a } : a);
    
    // Combine built-in apps with recent user shortcuts
    const all = [...BUILTIN_APPS];
    for (const r of recent) {
      if (!all.some(b => b.cmd === r.cmd)) {
        all.push({
          id: r.id || r.cmd,
          name: r.name || r.cmd,
          cmd: r.cmd,
          tag: 'RECENT',
          desc: `Custom user application shortcut (${r.cmd})`,
          featured: false
        });
      }
    }
    console.log(JSON.stringify(all, null, 2));
    return;
  }

  if (subcmd === 'launch' || subcmd === 'stream') {
    const targetServer = rest[0];
    const cmd = rest[1];
    if (!cmd) {
      console.error('Usage: ocloud app launch <server_id_or_name> <command>');
      process.exit(1);
    }

    // 1. Resolve server
    let server = null;
    let allServers = [];
    if (registry) {
      try {
        allServers = await registry.listAllServers();
      } catch(e) {}
    }

    if (targetServer) {
      server = allServers.find(s => 
        String(s.id) === String(targetServer) || 
        s.name.toLowerCase() === targetServer.toLowerCase() ||
        s.ipv4 === targetServer ||
        s.tailscale_ip === targetServer
      );
    }

    if (!server && allServers.length > 0) {
      // Pick first running server or first server
      server = allServers.find(s => s.status === 'running') || allServers[0];
    }

    // If still no server object, create fallback using targetServer as host
    if (!server) {
      server = {
        name: targetServer || 'Remote Node',
        ipv4: targetServer || '127.0.0.1',
        tailscale_ip: null,
        user: 'root',
        port: 22
      };
    }

    // Prefer Tailscale IP for private, encrypted peer-to-peer streaming
    const host = server.tailscale_ip || server.ipv4 || server.ip;
    if (!host || host === '-' || host === 'no IP') {
      console.error(`Error: Server '${server.name}' does not have a reachable IPv4 or Tailscale IP.`);
      process.exit(1);
    }

    const user = server.user || (server.isHomeWorkstation ? (process.env.USER || 'bigcjat') : 'root');
    const port = server.port || 22;

    // Resolve SSH Key
    const keyCandidates = [
      server.keyPath,
      path.join(os.homedir(), '.ssh', 'id_ed25519'),
      path.join(os.homedir(), '.ssh', 'id_rsa')
    ].filter(Boolean);
    const keyPath = keyCandidates.find(p => fs.existsSync(p)) || path.join(os.homedir(), '.ssh', 'id_ed25519');

    // Verify waypipe binary
    const waypipeBin = getWaypipeBin();
    if (!waypipeBin) {
      console.error(`Error: 'waypipe' is not installed on this system.`);
      console.error(`Please install it with: sudo pacman -S waypipe`);
      process.exit(1);
    }

    // Pre-flight probe SSH connectivity
    console.log(`Connecting to ${server.name} (${user}@${host}:${port})...`);
    try {
      execSync(`ssh -p ${port} -i "${keyPath}" -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=no ${user}@${host} "echo ready"`, {
        timeout: 5000,
        stdio: 'pipe'
      });
    } catch (sshErr) {
      const errMsg = (sshErr.stderr ? sshErr.stderr.toString() : '') || sshErr.message;
      console.error(`Failed to connect to ${server.name} via SSH: ${errMsg.trim()}`);
      process.exit(1);
    }

    // Record shortcut in recent_apps
    recordRecentApp(cmd);

    const isHome = Boolean(server.isHomeWorkstation);
    const titlePrefix = isHome ? '[🏠 Home Workstation] ' : `[☁ ${server.name}] `;
    const remoteExec = `env PATH=/root/.local/bin:/home/${user}/.local/bin:/usr/local/bin:/usr/bin:$PATH PULSE_SERVER=tcp:localhost:4713 QT_QPA_PLATFORM=wayland QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=1500 ${cmd}`;

    console.log(`\x1b[36m🚀 Streaming "${cmd}" from ${server.name} via Waypipe...\x1b[0m`);
    console.log(`Window Prefix: "${titlePrefix}"`);

    const env = {
      ...process.env,
      WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-1',
      XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || path.join('/run', 'user', String(process.getuid ? process.getuid() : 1000))
    };

    const child = spawn(
      waypipeBin,
      [
        '--title-prefix', titlePrefix,
        '--video=h264',
        '--threads', '4',
        'ssh',
        '-p', String(port),
        '-i', keyPath,
        '-o', 'BatchMode=yes',
        '-o', 'StrictHostKeyChecking=no',
        '-R', '4713:localhost:4713',
        `${user}@${host}`,
        remoteExec
      ],
      {
        env,
        stdio: 'inherit',
        detached: true
      }
    );
    child.unref();
    console.log(`✔ Process spawned in background with Waypipe.`);
    return;
  }

  console.log('Usage: ocloud app [list | launch <server> <command>]');
}

module.exports = { cmdApp };
