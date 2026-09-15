const { spawn, execSync, execFileSync } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');
const crypto = require('crypto');

function execRemoteScript(host, port, user, keyPath, script, options = {}) {
  const timeout = options.timeout || 15000;
  const configDir = path.join(os.homedir(), '.config', 'ocloud');
  if (!fs.existsSync(configDir)) fs.mkdirSync(configDir, { recursive: true });
  const knownHosts = path.join(configDir, 'known_hosts');

  const args = [
    '-q',
    '-o', 'LogLevel=ERROR',
    '-p', String(port),
    '-i', keyPath,
    '-o', `UserKnownHostsFile=${knownHosts}`,
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'BatchMode=yes',
    '-o', `ConnectTimeout=${options.connectTimeout || 8}`,
    `${user}@${host}`,
    'bash -s'
  ];

  return execFileSync('ssh', args, {
    input: script,
    timeout,
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe']
  });
}
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

function getXpraBin() {
  const candidates = [
    '/usr/bin/xpra',
    '/usr/local/bin/xpra',
    path.join(os.homedir(), '.local', 'bin', 'xpra')
  ];
  const found = candidates.find(p => fs.existsSync(p));
  if (found) return found;

  try {
    const out = execSync('command -v xpra 2>/dev/null', { encoding: 'utf8' }).trim();
    if (out) return out;
  } catch (e) {}

  return null;
}

function getSettingsPath() {
  return path.join(os.homedir(), '.config', 'ocloud', 'settings.json');
}

function getStreamingEngine() {
  try {
    const settings = loadSettings();
    return settings.app_streaming_engine || 'xpra';
  } catch (e) {
    return 'xpra';
  }
}

function setStreamingEngine(engine) {
  try {
    const settings = loadSettings();
    settings.app_streaming_engine = engine;
    const cfgPath = getSettingsPath();
    fs.mkdirSync(path.dirname(cfgPath), { recursive: true });
    fs.writeFileSync(cfgPath, JSON.stringify(settings, null, 2), 'utf8');
  } catch (e) {}
}

function getStreamingAudio() {
  try {
    const settings = loadSettings();
    return settings.app_streaming_audio !== false;
  } catch (e) {
    return true;
  }
}

function setStreamingAudio(enabled) {
  try {
    const settings = loadSettings();
    settings.app_streaming_audio = Boolean(enabled);
    const cfgPath = getSettingsPath();
    fs.mkdirSync(path.dirname(cfgPath), { recursive: true });
    fs.writeFileSync(cfgPath, JSON.stringify(settings, null, 2), 'utf8');
  } catch (e) {}
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
  // Web & Dev
  { id: 'firefox', name: 'Firefox', cmd: 'firefox', category: 'Dev & Web', tag: 'BROWSER', desc: 'Secure high-speed web browsing & media streaming without local RAM exhaustion.', icon: 'globe.svg', featured: true },
  { id: 'code', name: 'VS Code', cmd: 'code', category: 'Dev & Web', tag: 'DEV', desc: 'Full development IDE with language servers and cloud-native compilation.', icon: 'code.svg', featured: true },
  { id: 'tradingview', name: 'TradingView', cmd: 'tradingview', category: 'Dev & Web', tag: 'FINANCE', desc: '24/7 real-time market charts, technical indicators, and price alerts.', icon: 'chart.svg', featured: false },

  // Work & Office
  { id: 'slack', name: 'Slack', cmd: 'slack', category: 'Work & Office', tag: 'WORK', desc: 'Workplace collaboration with persistent 24/7 active online presence.', icon: 'message-square.svg', featured: true },
  { id: 'teams', name: 'Microsoft Teams', cmd: 'teams-for-linux', category: 'Work & Office', tag: 'ENTERPRISE', desc: 'Enterprise chat, channels, meetings, and always-available status.', icon: 'users.svg', featured: false },
  { id: 'thunderbird', name: 'Thunderbird', cmd: 'thunderbird', category: 'Work & Office', tag: 'EMAIL', desc: 'Corporate email archive, background indexing, and calendar sync.', icon: 'mail.svg', featured: true },
  { id: 'zoom', name: 'Zoom', cmd: 'zoom', category: 'Work & Office', tag: 'MEETINGS', desc: 'Video conferencing and client calling standby.', icon: 'video.svg', featured: false },
  { id: 'mattermost', name: 'Mattermost', cmd: 'mattermost-desktop', category: 'Work & Office', tag: 'TEAM', desc: 'Open source team collaboration platform.', icon: 'message-circle.svg', featured: false },

  // Creative & Media
  { id: 'obs', name: 'OBS Studio', cmd: 'obs', category: 'Creative & Media', tag: 'BROADCAST', desc: 'Live video broadcasting and recording with datacenter uplink bandwidth.', icon: 'camera.svg', featured: true },
  { id: 'handbrake', name: 'HandBrake', cmd: 'ghb', category: 'Creative & Media', tag: 'TRANSCODE', desc: 'Batch video encoding and compression without overheating local CPU.', icon: 'film.svg', featured: false },
  { id: 'blender', name: 'Blender', cmd: 'blender', category: 'Creative & Media', tag: '3D', desc: 'Open source 3D graphics creation and cloud Cycles rendering.', icon: 'box.svg', featured: true },
  { id: 'gimp', name: 'GIMP', cmd: 'gimp', category: 'Creative & Media', tag: 'GRAPHICS', desc: 'High resolution image manipulation without local memory constraints.', icon: 'image.svg', featured: false },

  // Communication
  { id: 'discord', name: 'Discord', cmd: 'discord', category: 'Communication', tag: 'COMMUNITY', desc: 'Voice, video, and community channels running 24/7 without eating local RAM.', icon: 'headphones.svg', featured: true },
  { id: 'telegram', name: 'Telegram', cmd: 'telegram-desktop', category: 'Communication', tag: 'MESSAGING', desc: 'Fast messaging, community channels, and large media sharing.', icon: 'send.svg', featured: false },
  { id: 'signal', name: 'Signal', cmd: 'signal-desktop', category: 'Communication', tag: 'PRIVATE', desc: 'Encrypted private messaging with zero local disk footprint when closed.', icon: 'lock.svg', featured: false }
];

async function resolveServer(targetServer, registry) {
  let server = null;
  let allServers = [];
  if (registry) {
    try {
      allServers = await registry.listAllServers();
    } catch (e) {}
  }

  if (targetServer) {
    server = allServers.find(s => 
      String(s.id) === String(targetServer) || 
      s.name.toLowerCase() === targetServer.toLowerCase() ||
      s.ipv4 === targetServer ||
      s.tailscale_ip === targetServer
    );
  }

  if (!server && !targetServer && allServers.length > 0) {
    server = allServers.find(s => s.status === 'running') || allServers[0];
  }

  if (!server) {
    server = {
      name: targetServer || 'Remote Node',
      ipv4: targetServer || '127.0.0.1',
      tailscale_ip: null,
      user: 'root',
      port: 22
    };
  }

  // Resolve Tailscale IP if available
  let tailscaleIp = server.tailscale_ip;
  if (!tailscaleIp && server.name) {
    try {
      const tsRaw = execSync('tailscale status --json', { timeout: 1500, encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
      const tsData = JSON.parse(tsRaw);
      if (tsData && tsData.Peer) {
        const targetName = server.name.toLowerCase();
        for (const p of Object.values(tsData.Peer)) {
          const peerName = (p.HostName || '').toLowerCase();
          const dnsName = (p.DNSName || '').split('.')[0].toLowerCase();
          if (peerName === targetName || dnsName === targetName) {
            tailscaleIp = (p.TailscaleIPs || []).find(ip => ip.includes('.'));
            if (tailscaleIp) break;
          }
        }
      }
    } catch (e) {}
  }

  const isTailscale = Boolean(tailscaleIp);
  const host = tailscaleIp || server.ipv4 || server.ip;
  const user = server.user || (server.isHomeWorkstation ? (process.env.USER || os.userInfo().username || '') : 'root');
  const port = server.port || 22;

  const keyCandidates = [
    server.keyPath,
    path.join(os.homedir(), '.ssh', 'id_ed25519'),
    path.join(os.homedir(), '.ssh', 'id_rsa')
  ].filter(Boolean);
  const keyPath = keyCandidates.find(p => fs.existsSync(p)) || path.join(os.homedir(), '.ssh', 'id_ed25519');

  return { server, host, user, port, keyPath, isTailscale };
}

function getSshSecurityOpts() {
  const configDir = path.join(os.homedir(), '.config', 'ocloud');
  if (!fs.existsSync(configDir)) fs.mkdirSync(configDir, { recursive: true });
  const knownHosts = path.join(configDir, 'known_hosts');
  return `-o UserKnownHostsFile="${knownHosts}" -o StrictHostKeyChecking=accept-new -o BatchMode=yes`;
}

function getSshSecurityArgs() {
  const configDir = path.join(os.homedir(), '.config', 'ocloud');
  if (!fs.existsSync(configDir)) fs.mkdirSync(configDir, { recursive: true });
  const knownHosts = path.join(configDir, 'known_hosts');
  return [
    '-o', `UserKnownHostsFile=${knownHosts}`,
    '-o', 'StrictHostKeyChecking=accept-new',
    '-o', 'BatchMode=yes'
  ];
}

function ensureRunnerUser(host, port, user, keyPath) {
  if (user !== 'root') return user;
  try {
    const setupScript = [
      'if ! id -u omarchy-runner >/dev/null 2>&1; then',
      '  useradd -m -s /bin/bash omarchy-runner 2>/dev/null || true;',
      '  usermod -aG audio,video,render omarchy-runner 2>/dev/null || true;',
      'fi;',
      'if [ -f /root/.ssh/authorized_keys ]; then',
      '  mkdir -p /home/omarchy-runner/.ssh;',
      '  cp /root/.ssh/authorized_keys /home/omarchy-runner/.ssh/authorized_keys 2>/dev/null || true;',
      '  chown -R omarchy-runner:omarchy-runner /home/omarchy-runner/.ssh 2>/dev/null || true;',
      '  chmod 700 /home/omarchy-runner/.ssh 2>/dev/null || true;',
      '  chmod 600 /home/omarchy-runner/.ssh/authorized_keys 2>/dev/null || true;',
      'fi;',
      'id -u omarchy-runner >/dev/null 2>&1 && echo "RUNNER_READY" || echo "RUNNER_FAIL"'
    ].join('\n');

    const out = execRemoteScript(host, port, 'root', keyPath, setupScript, { timeout: 10000 }).trim();
    if (out.includes('RUNNER_READY')) {
      return 'omarchy-runner';
    }
  } catch (e) {}
  return 'root';
}

function loadAppCatalog() {
  try {
    const p = path.join(__dirname, '..', '..', 'apps', 'catalog.json');
    if (fs.existsSync(p)) {
      const data = JSON.parse(fs.readFileSync(p, 'utf8'));
      if (data && Array.isArray(data.apps)) return data.apps;
    }
  } catch (e) {}
  return BUILTIN_APPS;
}

function getDistroPkg(binary, distro) {
  const catalog = loadAppCatalog();
  const app = catalog.find(a => a.cmd === binary || a.id === binary || (a.aliases && a.aliases.includes(binary)));
  if (app && app.packages) {
    const distroMap = {
      'apt': 'debian',
      'debian': 'debian',
      'ubuntu': 'debian',
      'pacman': 'arch',
      'arch': 'arch',
      'dnf': 'fedora',
      'fedora': 'fedora',
      'apk': 'alpine',
      'alpine': 'alpine'
    };
    const key = distroMap[distro] || distro;
    if (app.packages[key] && app.packages[key].length > 0) {
      return app.packages[key].join(' ');
    }
  }

  const map = {
    'firefox': {
      apt: 'firefox-esr || $SUDO apt-get install -y -qq firefox',
      pacman: 'firefox',
      dnf: 'firefox'
    },
    'obs': {
      apt: 'obs-studio',
      pacman: 'obs-studio',
      dnf: 'obs-studio'
    },
    'obs-studio': {
      apt: 'obs-studio',
      pacman: 'obs-studio',
      dnf: 'obs-studio'
    },
    'ghb': {
      apt: 'handbrake-cli handbrake || $SUDO apt-get install -y -qq ghb',
      pacman: 'handbrake handbrake-cli',
      dnf: 'handbrake'
    }
  };
  return map[binary]?.[distro] || binary;
}

function getInstallScriptForApp(rawCmd) {
  const binary = rawCmd.trim().split(' ')[0].split('/').pop();

  if (binary === 'arcade') {
    return [
      'if [ -f "/root/.local/bin/arcade" ]; then',
      '  echo "arcade already installed";',
      'else',
      '  curl -sSL https://raw.githubusercontent.com/bigcjat/omarchyarcade/main/install.sh | bash;',
      'fi'
    ].join('\n');
  }

  return [
    'if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else SUDO=""; fi',
    'if command -v apt-get >/dev/null 2>&1; then',
    '  export DEBIAN_FRONTEND=noninteractive;',
    '  $SUDO apt-get update -qq;',
    `  $SUDO apt-get install -y -qq ${getDistroPkg(binary, 'apt')} xpra pulseaudio xvfb xauth python3-paramiko gstreamer1.0-plugins-base gstreamer1.0-plugins-good fonts-noto-core waypipe;`,
    'elif command -v pacman >/dev/null 2>&1; then',
    `  $SUDO pacman -Sy --noconfirm ${getDistroPkg(binary, 'pacman')} xpra pulseaudio pulseaudio-alsa xorg-server-xvfb xorg-xauth python-paramiko gst-python gst-plugins-base gst-plugins-good gst-plugins-bad noto-fonts waypipe;`,
    'elif command -v dnf >/dev/null 2>&1; then',
    `  $SUDO dnf install -y ${getDistroPkg(binary, 'dnf')} xpra pulseaudio xorg-x11-server-Xvfb xorg-x11-xauth waypipe;`,
    'elif command -v apk >/dev/null 2>&1; then',
    `  $SUDO apk add ${binary} xpra pulseaudio xvfb xauth waypipe;`,
    'elif command -v zypper >/dev/null 2>&1; then',
    `  $SUDO zypper --non-interactive install ${binary} xpra pulseaudio xvfb xauth waypipe;`,
    'fi'
  ].join('\n');
}

async function cmdApp(subcmd, rest, context = {}) {
  const { registry } = context;

  if (subcmd === 'probe-all') {
    const targetServer = rest[0];
    if (!targetServer) {
      throw new Error('Usage: ocloud app probe-all <server_id_or_name>');
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    const catalog = loadAppCatalog();

    const appChecks = catalog.map(app => {
      const binaries = [app.cmd, ...(app.aliases || [])];
      const checkExpr = binaries.map(b => `command -v ${b} >/dev/null 2>&1`).join(' || ');
      return `if (${checkExpr}); then echo "APP:${app.id}:1"; else echo "APP:${app.id}:0"; fi;`;
    }).join('\n');

    const probeScript = [
      'PATH=/usr/local/bin:/usr/bin:/bin:/root/.local/bin:/home/omarchy-runner/.local/bin:$PATH',
      'echo "SYS:CORES:$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 2)"',
      'echo "SYS:RAM_MB:$(free -m 2>/dev/null | awk \'/^Mem:/{print $2}\' || echo 2048)"',
      'echo "SYS:XPRA:$(command -v xpra >/dev/null 2>&1 && echo 1 || echo 0)"',
      'echo "SYS:WAYPIPE:$(command -v waypipe >/dev/null 2>&1 && echo 1 || echo 0)"',
      appChecks
    ].join('\n');

    try {
      const out = execRemoteScript(host, port, user, keyPath, probeScript, { timeout: 12000 }).trim();

      const lines = out.split('\n');
      const apps = {};
      let cores = 2;
      let ramMb = 2048;
      let hasXpra = false;
      let hasWaypipe = false;

      for (const rawLine of lines) {
        const line = rawLine.trim();
        if (line.startsWith('APP:')) {
          const parts = line.split(':');
          if (parts.length >= 3) {
            apps[parts[1]] = parts[2] === '1';
          }
        } else if (line.startsWith('SYS:CORES:')) {
          cores = parseInt(line.replace('SYS:CORES:', ''), 10) || 2;
        } else if (line.startsWith('SYS:RAM_MB:')) {
          ramMb = parseInt(line.replace('SYS:RAM_MB:', ''), 10) || 2048;
        } else if (line.startsWith('SYS:XPRA:')) {
          hasXpra = line.replace('SYS:XPRA:', '').trim() === '1';
        } else if (line.startsWith('SYS:WAYPIPE:')) {
          hasWaypipe = line.replace('SYS:WAYPIPE:', '').trim() === '1';
        }
      }

      console.log(JSON.stringify({
        success: true,
        serverId: server.id,
        serverName: server.name,
        ramMb,
        cores,
        xpra: hasXpra,
        waypipe: hasWaypipe,
        apps
      }));
      return;
    } catch (e) {
      console.log(JSON.stringify({
        success: false,
        serverId: server.id,
        serverName: server.name,
        error: e.message,
        apps: {}
      }));
      return;
    }
  }

  if (subcmd === 'probe' || subcmd === 'check') {
    const targetServer = rest[0];
    const cmd = rest[1];
    if (!cmd) {
      throw new Error('Usage: ocloud app probe <server_id_or_name> <command>');
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    const binary = cmd.trim().split(' ')[0].split('/').pop();

    let check = `command -v ${binary} >/dev/null 2>&1`;
    if (binary === 'obs' || binary === 'obs-studio') check = `command -v obs >/dev/null 2>&1 || command -v obs-studio >/dev/null 2>&1`;
    if (binary === 'firefox') check = `command -v firefox >/dev/null 2>&1 || command -v firefox-esr >/dev/null 2>&1`;
    if (binary === 'code') check = `command -v code >/dev/null 2>&1 || command -v codium >/dev/null 2>&1`;
    if (binary === 'ghb' || binary === 'handbrake') check = `command -v ghb >/dev/null 2>&1 || command -v handbrake >/dev/null 2>&1 || command -v HandBrakeCLI >/dev/null 2>&1`;

    const probeScript = [
      'PATH=/usr/local/bin:/usr/bin:/bin:/root/.local/bin:/home/omarchy-runner/.local/bin:$PATH',
      `if (${check}); then echo "OCLOUD_APP_FOUND"; else echo "OCLOUD_APP_NOT_FOUND"; fi`
    ].join('\n');

    try {
      const out = execRemoteScript(host, port, user, keyPath, probeScript, { timeout: 8000 }).trim();
      const installed = out.includes('OCLOUD_APP_FOUND');
      console.log(JSON.stringify({
        installed,
        serverName: server.name,
        serverId: server.id,
        cmd: binary
      }));
      return;
    } catch (e) {
      console.log(JSON.stringify({
        installed: false,
        serverName: server.name,
        serverId: server.id,
        cmd: binary,
        error: e.message
      }));
      return;
    }
  }

  if (subcmd === 'install') {
    const targetServer = rest[0];
    const cmd = rest[1];
    if (!cmd) {
      throw new Error('Usage: ocloud app install <server_id_or_name> <command>');
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    const installScript = getInstallScriptForApp(cmd);
    console.log(`Installing ${cmd} on ${server.name}...`);
    try {
      execRemoteScript(host, port, user, keyPath, installScript, { timeout: 180000 });
      console.log(`✔ Successfully installed ${cmd} on ${server.name}.`);
      return;
    } catch (e) {
      throw new Error(`Failed to install ${cmd} on ${server.name}: ${e.message}`);
    }
  }

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

  if (subcmd === 'engine') {
    const targetEngine = rest[0];
    if (!targetEngine || targetEngine === 'get') {
      const current = getStreamingEngine();
      console.log(JSON.stringify({ engine: current }));
      return;
    }
    const clean = targetEngine.toLowerCase();
    if (['xpra', 'waypipe'].includes(clean)) {
      setStreamingEngine(clean);
      console.log(JSON.stringify({ success: true, engine: clean }));
      return;
    }
    throw new Error('Invalid engine. Choose from: xpra (Option B · Persistent & Smooth), waypipe (Original · Direct Wayland)');
  }

  if (subcmd === 'audio') {
    const targetAudio = rest[0];
    if (!targetAudio || targetAudio === 'get') {
      const current = getStreamingAudio();
      console.log(JSON.stringify({ audio: current }));
      return;
    }
    const clean = targetAudio.toLowerCase();
    if (['on', 'true', '1', 'yes', 'enable'].includes(clean)) {
      setStreamingAudio(true);
      console.log(JSON.stringify({ success: true, audio: true }));
      return;
    }
    if (['off', 'false', '0', 'no', 'disable'].includes(clean)) {
      setStreamingAudio(false);
      console.log(JSON.stringify({ success: true, audio: false }));
      return;
    }
    throw new Error('Invalid audio option. Choose from: on, off');
  }


  if (subcmd === 'sessions') {
    const targetServer = rest[0];
    if (!targetServer) {
      throw new Error('Usage: ocloud app sessions <server_id_or_name>');
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    try {
      const sessScript = 'su - omarchy-runner -c "xpra list 2>/dev/null" || xpra list 2>/dev/null || true';
      const out = execRemoteScript(host, port, user, keyPath, sessScript, { timeout: 8000 });
      const sessionLines = out.split('\n')
        .map(l => l.trim())
        .filter(l => l.includes('LIVE session at') || l.includes('xpra sessions:') || l.includes('No xpra sessions'));
      console.log(sessionLines.length > 0 ? sessionLines.join('\n') : 'No active sessions.');
    } catch (e) {
      console.error(`Failed to list sessions on ${server.name}: ${e.message}`);
    }
    return;
  }

  if (subcmd === 'stop' || subcmd === 'kill') {
    const targetServer = rest[0];
    const display = rest[1] || ':100';
    if (!targetServer) {
      throw new Error('Usage: ocloud app stop <server_id_or_name> [display]');
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    try {
      const stopScript = `su - omarchy-runner -c "xpra stop ${display} 2>/dev/null" || xpra stop ${display} 2>/dev/null || true`;
      execRemoteScript(host, port, user, keyPath, stopScript, { timeout: 10000 });
      console.log(`✔ Stopped cloud session ${display} on ${server.name}.`);
    } catch (e) {
      console.error(`Failed to stop session on ${server.name}: ${e.message}`);
    }
    return;
  }

  if (subcmd === 'detach') {
    try {
      execSync('pkill -f "[x]pra attach" 2>/dev/null || true; pkill -f "[_]audio_play" 2>/dev/null || true; pkill -f "[w]aypipe" 2>/dev/null || true;', { stdio: 'ignore' });
      console.log('✔ Detached from cloud session. Remote application remains running 24/7 in the cloud.');
    } catch (e) {
      console.log('No attached sessions to detach.');
    }
    return;
  }

  if (subcmd === 'is-attached') {
    try {
      const out = execSync('pgrep -f "[x]pra attach" || pgrep -f "[w]aypipe"', { encoding: 'utf8' }).trim();
      console.log(JSON.stringify({ attached: Boolean(out) }));
    } catch (e) {
      console.log(JSON.stringify({ attached: false }));
    }
    return;
  }

  if (subcmd === 'attach') {
    let audio = getStreamingAudio();
    const filteredRest = [];
    for (const arg of rest) {
      if (arg === '--audio') audio = true;
      else if (arg === '--no-audio') audio = false;
      else filteredRest.push(arg);
    }
    const targetServer = filteredRest[0];
    const display = (filteredRest[1] || '100').replace(':', '');
    if (!targetServer) {
      throw new Error('Usage: ocloud app attach <server_id_or_name> [display_number] [--audio|--no-audio]');
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    const runUser = ensureRunnerUser(host, port, user, keyPath);
    const xpraBin = getXpraBin();
    if (!xpraBin) {
      throw new Error("Error: 'xpra' is not installed locally. Please run: sudo pacman -S xpra");
    }

    const localPulseSocket = process.env.PULSE_SERVER?.startsWith('unix:')
      ? process.env.PULSE_SERVER.replace('unix:', '')
      : path.join(process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid ? process.getuid() : 1000}`, 'pulse', 'native');

    const env = {
      ...process.env,
      DISPLAY: process.env.DISPLAY || ':1',
      WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-1',
      XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || path.join('/run', 'user', String(process.getuid ? process.getuid() : 1000)),
      PULSE_SERVER: `unix:${localPulseSocket}`
    };

    const providerLabel = server.providerName || (server.provider ? server.provider.toUpperCase() : 'Cloud');
    const attachArgs = [
      'attach',
      '--splash=no',
      audio ? '--speaker=on' : '--speaker=off',
      ...(audio ? ['--speaker-codec=opus'] : []),
      '--av-sync=no',
      '--encoding=vp8',
      '--speed=90',
      '--quality=55',
      '--min-quality=30',
      '--microphone=off',
      '--reconnect=no',
      '--terminate-children=yes',
      '--window-close=disconnect',
      '--border=#ef4444,3',
      `--title=[☁ ${providerLabel}] @title@`,
      `ssh://${runUser}@${host}:${port}/${display}`
    ];

    const child = spawn(xpraBin, attachArgs, {
      env,
      stdio: 'ignore',
      detached: true
    });
    child.unref();
    console.log(`✔ Attached! Window will appear seamlessly on your desktop.`);
    return;
  }

  if (subcmd === 'launch' || subcmd === 'stream') {
    let engine = getStreamingEngine();
    let audio = getStreamingAudio();
    const filteredRest = [];
    for (let i = 0; i < rest.length; i++) {
      if (rest[i].startsWith('--engine=')) {
        engine = rest[i].split('=')[1].toLowerCase();
      } else if (rest[i] === '-e' && rest[i + 1]) {
        engine = rest[++i].toLowerCase();
      } else if (rest[i] === '--audio') {
        audio = true;
      } else if (rest[i] === '--no-audio') {
        audio = false;
      } else {
        filteredRest.push(rest[i]);
      }
    }

    const targetServer = filteredRest[0];
    const cmd = filteredRest.slice(1).join(' ');
    if (!targetServer || !cmd) {
      throw new Error('Usage: ocloud app launch <server_id_or_name> <command> [--engine=xpra|waypipe] [--audio|--no-audio]');
    }

    const { server, host, user, port, keyPath, isTailscale } = await resolveServer(targetServer, registry);

    if (!host || host === '-' || host === 'no IP') {
      throw new Error(`Server '${server.name}' does not have a reachable IPv4 or Tailscale IP.`);
    }

    const xpraBin = getXpraBin();
    const waypipeBin = getWaypipeBin();
    if (!xpraBin && !waypipeBin) {
      throw new Error("Neither 'xpra' nor 'waypipe' is installed on this system. Please install with: sudo pacman -S xpra");
    }

    // Pre-flight probe SSH connectivity
    console.log(`Connecting to ${server.name} via ${isTailscale ? 'Tailscale' : 'IPv4'} (${user}@${host}:${port})...`);
    try {
      execRemoteScript(host, port, user, keyPath, 'echo ready', { timeout: 10000 });
    } catch (sshErr) {
      throw new Error(`Failed to connect to ${server.name} via SSH: ${sshErr.message.trim()}`);
    }

    // Security & Sandbox Hardening: ensure unprivileged omarchy-runner user
    const runUser = ensureRunnerUser(host, port, user, keyPath);

    // Record shortcut in recent_apps
    recordRecentApp(cmd);

    // Probe remote server capabilities
    const binary = cmd.trim().split(' ')[0].split('/').pop();
    let hasRemoteXpra = false;
    let hasRemotePulse = false;
    let hasRemoteWaypipe = false;
    let appFound = false;
    let activeXpraSession = null;
    let remoteCores = 4;

    let check = `command -v ${binary} >/dev/null 2>&1`;
    if (binary === 'obs' || binary === 'obs-studio') check = `command -v obs >/dev/null 2>&1 || command -v obs-studio >/dev/null 2>&1`;
    if (binary === 'firefox') check = `command -v firefox >/dev/null 2>&1 || command -v firefox-esr >/dev/null 2>&1`;
    if (binary === 'code') check = `command -v code >/dev/null 2>&1 || command -v codium >/dev/null 2>&1`;
    if (binary === 'ghb' || binary === 'handbrake') check = `command -v ghb >/dev/null 2>&1 || command -v handbrake >/dev/null 2>&1 || command -v HandBrakeCLI >/dev/null 2>&1`;

    const probeScript = [
      'PATH=/usr/local/bin:/usr/bin:/bin:/root/.local/bin:/home/omarchy-runner/.local/bin:$PATH',
      `echo "OCLOUD_APP:$( (${check}) && echo OK || echo MISSING)"`,
      'echo "OCLOUD_XPRA:$(command -v xpra >/dev/null 2>&1 && echo OK || echo MISSING)"',
      'echo "OCLOUD_PULSE:$( (command -v pulseaudio >/dev/null 2>&1 || command -v pipewire >/dev/null 2>&1) && echo OK || echo MISSING)"',
      'echo "OCLOUD_WAYPIPE:$(command -v waypipe >/dev/null 2>&1 && echo OK || echo MISSING)"',
      'echo "OCLOUD_SESS:$( (su - omarchy-runner -c \\"xpra list 2>/dev/null\\" || xpra list 2>/dev/null) | grep -oE \\":[0-9]+\\" | head -n 1 || echo NONE)"',
      'echo "OCLOUD_CORES:$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 4)"'
    ].join('\n');

    try {
      const probeOut = execRemoteScript(host, port, user, keyPath, probeScript, { timeout: 15000 }).trim().split('\n');

      appFound = probeOut.some(l => l.trim() === 'OCLOUD_APP:OK');
      hasRemoteXpra = probeOut.some(l => l.trim() === 'OCLOUD_XPRA:OK');
      hasRemotePulse = probeOut.some(l => l.trim() === 'OCLOUD_PULSE:OK');
      hasRemoteWaypipe = probeOut.some(l => l.trim() === 'OCLOUD_WAYPIPE:OK');

      const sessLine = probeOut.find(l => l.startsWith('OCLOUD_SESS:'))?.replace('OCLOUD_SESS:', '').trim();
      if (sessLine && sessLine !== 'NONE' && /^:[0-9]+$/.test(sessLine)) {
        activeXpraSession = sessLine;
      }

      const coresLine = probeOut.find(l => l.startsWith('OCLOUD_CORES:'))?.replace('OCLOUD_CORES:', '').trim();
      const parsedCores = parseInt(coresLine, 10);
      if (!isNaN(parsedCores) && parsedCores > 0) {
        remoteCores = Math.min(Math.max(parsedCores, 2), 16);
      }
    } catch (probeErr) {
      console.warn(`[ocloud-app] Probe warning: ${probeErr.message}`);
    }

    // Auto-install missing server packages
    const needsXpra = (engine === 'xpra') && (!hasRemoteXpra || !hasRemotePulse);
    const needsWp = (engine === 'waypipe') && !hasRemoteWaypipe;

    if (!appFound || needsXpra || needsWp) {
      const missingList = [];
      if (!appFound) missingList.push(binary);
      if (needsXpra) {
        if (!hasRemoteXpra) missingList.push('xpra');
        if (!hasRemotePulse) missingList.push('pulseaudio');
      }
      if (needsWp) missingList.push('waypipe');

      console.log(`\x1b[33m⚡ Installing missing remote dependencies (${missingList.join(', ')}) on ${server.name}...\x1b[0m`);
      const installScript = getInstallScriptForApp(cmd);

      try {
        execRemoteScript(host, port, user, keyPath, installScript, { timeout: 300000 });
        // Verify installation
        const verifyScript = 'command -v xpra >/dev/null 2>&1 && echo XPRA_OK; command -v waypipe >/dev/null 2>&1 && echo WP_OK; ' + check + ' && echo APP_OK';
        const verifyOut = execRemoteScript(host, port, user, keyPath, verifyScript, { timeout: 15000 });
        if (verifyOut.includes('XPRA_OK')) hasRemoteXpra = true;
        if (verifyOut.includes('WP_OK')) hasRemoteWaypipe = true;
        if (verifyOut.includes('APP_OK')) appFound = true;
        console.log(`\x1b[32m✔ Dependencies successfully installed on ${server.name}.\x1b[0m`);
      } catch (installErr) {
        console.error(`\x1b[31m✖ Error installing dependencies on ${server.name}: ${installErr.message}\x1b[0m`);
        if (engine === 'xpra' && !hasRemoteXpra) {
          throw new Error(`Cannot launch via Xpra: 'xpra' is not installed on ${server.name} and auto-installation failed.`);
        }
        if (engine === 'waypipe' && !hasRemoteWaypipe) {
          throw new Error(`Cannot launch via Waypipe: 'waypipe' is not installed on ${server.name} and auto-installation failed.`);
        }
      }
    }

    // Resolve local PulseAudio socket for pristine PipeWire output
    const localPulseSocket = process.env.PULSE_SERVER?.startsWith('unix:')
      ? process.env.PULSE_SERVER.replace('unix:', '')
      : path.join(process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid ? process.getuid() : 1000}`, 'pulse', 'native');

    const env = {
      ...process.env,
      DISPLAY: process.env.DISPLAY || ':1',
      WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-1',
      XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || path.join('/run', 'user', String(process.getuid ? process.getuid() : 1000)),
      PULSE_SERVER: `unix:${localPulseSocket}`
    };

    // STRICT ENGINE ENFORCEMENT - NEVER SILENTLY FALL BACK
    if (engine === 'xpra') {
      if (!xpraBin) {
        throw new Error("Local 'xpra' binary not found. Please install xpra on your client system (e.g. sudo pacman -S xpra).");
      }
      if (!hasRemoteXpra) {
        throw new Error(`'xpra' is not available on remote server ${server.name}.`);
      }

      let displayNum = activeXpraSession ? activeXpraSession.replace(':', '') : '100';

      if (!activeXpraSession) {
        console.log(`\x1b[36m🚀 [Xpra Seamless] Starting persistent 24/7 cloud session :${displayNum} on ${server.name}...\x1b[0m`);
        console.log(`   Command:  ${cmd}`);
        console.log(`   Engine:   Xpra Seamless Server (H.264/VP9 adaptive WAN compression)`);
        console.log(`   Audio:    PulseAudio Server -> Opus 48kHz stereo stream`);
        console.log(`   Runner:   Unprivileged (${runUser})`);
        console.log(`   Survival: Laptop sleep & Wi-Fi disconnect resilient`);

        const startCmd = `xpra start :${displayNum} --start="${cmd}" --xvfb=Xvfb --daemon=yes --pulseaudio=yes --speed=90 --quality=55 --min-quality=30 --av-sync=no 2>&1`;
        try {
          execRemoteScript(host, port, runUser, keyPath, startCmd, { timeout: 20000 });
        } catch (startErr) {
          console.error(`Warning: Failed to launch new session: ${startErr.message}`);
        }
      } else {
        console.log(`\x1b[32m⚡ Found active persistent cloud session :${displayNum} on ${server.name}! Starting ${cmd}...\x1b[0m`);
        try {
          execRemoteScript(host, port, runUser, keyPath, `xpra control :${displayNum} start '${cmd}' 2>/dev/null || true`, { timeout: 10000 });
        } catch (e) {}
      }

      const providerLabel = server.providerName || (server.provider ? server.provider.toUpperCase() : 'Cloud');
      console.log(`\x1b[36m🔗 Attaching to display :${displayNum} with tuned VP8 video and ${audio ? 'decoupled Opus audio' : 'audio disabled'}...\x1b[0m`);
      const attachArgs = [
        'attach',
        '--splash=no',
        audio ? '--speaker=on' : '--speaker=off',
        ...(audio ? ['--speaker-codec=opus'] : []),
        '--av-sync=no',
        '--encoding=vp8',
        '--speed=90',
        '--quality=55',
        '--min-quality=30',
        '--microphone=off',
        '--reconnect=no',
        '--terminate-children=yes',
        '--window-close=disconnect',
        '--border=#ef4444,3',
        `--title=[☁ ${providerLabel}] @title@`,
        `ssh://${runUser}@${host}:${port}/${displayNum}`
      ];

      const child = spawn(xpraBin, attachArgs, { env, stdio: 'ignore', detached: true });
      child.unref();
      console.log(`✔ Attached! Cloud window and PipeWire audio are now active on your desktop.`);
      return;
    }

    if (engine === 'waypipe') {
      if (!waypipeBin) {
        throw new Error("Local 'waypipe' binary not found. Please install waypipe on your client system (e.g. sudo pacman -S waypipe).");
      }
      if (!hasRemoteWaypipe) {
        throw new Error(`'waypipe' is not available on remote server ${server.name}.`);
      }

      // ENGINE 2: Waypipe Direct (Original - Pure Wayland protocol over SSH)
      console.log(`\x1b[33m🪟 [Original: Waypipe Direct] Streaming "${cmd}" from ${server.name} via Waypipe...\x1b[0m`);
      console.log(`   Engine:   Direct Wayland socket proxy (LZ4 compression)`);
      console.log(`   Audio:    ${audio ? 'PulseAudio UNIX tunnel' : 'Disabled'}`);
      console.log(`   Latency:  Synchronous Wayland frame callbacks`);
      console.log(`   Runner:   Unprivileged (${runUser})`);

      const isHome = Boolean(server.isHomeWorkstation);
      const providerLabel = isHome ? 'Home Workstation' : (server.providerName || server.provider || 'Cloud');
      const titlePrefix = isHome ? '[🏠 Home Workstation] ' : `[☁ ${providerLabel} · ${server.name}] `;
      const pulseId = crypto.randomBytes(4).toString('hex');
      const remotePulseSocket = `/tmp/pulse-ocloud-${pulseId}.sock`;

      const waypipeArgs = [
        '--title-prefix', titlePrefix,
        '--threads', String(Math.min(remoteCores, 4)),
        '--compress=lz4=1',
        '--no-gpu',
        'ssh',
        '-p', String(port),
        '-i', keyPath,
        '-c', 'aes128-gcm@openssh.com',
        '-o', 'Compression=no',
        '-o', 'IPQoS=throughput',
        ...getSshSecurityArgs(),
        ...(audio ? [
          '-R', `${remotePulseSocket}:${localPulseSocket}`,
          `${runUser}@${host}`,
          `trap 'rm -f ${remotePulseSocket}' EXIT INT TERM; env PULSE_SERVER=unix:${remotePulseSocket} ${cmd}`
        ] : [
          `${runUser}@${host}`,
          cmd
        ])
      ];

      const child = spawn(waypipeBin, waypipeArgs, { env, stdio: 'ignore', detached: true });
      child.unref();
      console.log(`✔ Process spawned in background with Waypipe.`);
      return;
    }

    throw new Error(`Unknown streaming engine: '${engine}'. Must be 'xpra' or 'waypipe'.`);
  }

  console.log('Usage: ocloud app [list | launch <server> <cmd> [--engine=xpra|waypipe] [--audio|--no-audio] | attach <server> [display] [--audio|--no-audio] | sessions <server> | stop <server> [display] | engine [get|set] | audio [get|on|off]]');
}

module.exports = { cmdApp };
