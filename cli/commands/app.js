const { spawn, execSync } = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');
const crypto = require('crypto');
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

  if (!server && allServers.length > 0) {
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
  const user = server.user || (server.isHomeWorkstation ? (process.env.USER || 'bigcjat') : 'root');
  const port = server.port || 22;

  const keyCandidates = [
    server.keyPath,
    path.join(os.homedir(), '.ssh', 'id_ed25519'),
    path.join(os.homedir(), '.ssh', 'id_rsa')
  ].filter(Boolean);
  const keyPath = keyCandidates.find(p => fs.existsSync(p)) || path.join(os.homedir(), '.ssh', 'id_ed25519');

  return { server, host, user, port, keyPath, isTailscale };
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

  let debianInstall = `apt-get install -y -qq ${binary} waypipe;`;
  if (binary === 'firefox') {
    debianInstall = `(apt-get install -y -qq firefox-esr || apt-get install -y -qq firefox) && apt-get install -y -qq waypipe;`;
  }

  return [
    'if command -v apt-get >/dev/null 2>&1; then',
    '  export DEBIAN_FRONTEND=noninteractive;',
    '  apt-get update -qq;',
    `  ${debianInstall}`,
    'elif command -v pacman >/dev/null 2>&1; then',
    `  pacman -Sy --noconfirm ${binary} waypipe;`,
    'elif command -v dnf >/dev/null 2>&1; then',
    `  dnf install -y -q ${binary} waypipe;`,
    'elif command -v apk >/dev/null 2>&1; then',
    `  apk add --no-cache ${binary} waypipe;`,
    'elif command -v zypper >/dev/null 2>&1; then',
    `  zypper --non-interactive install ${binary} waypipe;`,
    'fi'
  ].join('\n');
}

async function cmdApp(subcmd, rest, context = {}) {
  const { registry } = context;

  if (subcmd === 'probe' || subcmd === 'check') {
    const targetServer = rest[0];
    const cmd = rest[1];
    if (!cmd) {
      console.error('Usage: ocloud app probe <server_id_or_name> <command>');
      process.exit(1);
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    const binary = cmd.trim().split(' ')[0].split('/').pop();

    const probeCmd = `if PATH=/root/.local/bin:/home/${user}/.local/bin:/usr/local/bin:/usr/bin:$PATH command -v ${binary} >/dev/null 2>&1; then echo "OCLOUD_APP_FOUND"; else echo "OCLOUD_APP_NOT_FOUND"; fi`;
    try {
      const out = execSync(
        `ssh -p ${port} -i "${keyPath}" -o BatchMode=yes -o ConnectTimeout=4 -o StrictHostKeyChecking=no ${user}@${host} "${probeCmd}"`,
        { timeout: 6000, encoding: 'utf8' }
      ).trim();
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
      console.error('Usage: ocloud app install <server_id_or_name> <command>');
      process.exit(1);
    }
    const { server, host, user, port, keyPath } = await resolveServer(targetServer, registry);
    const installScript = getInstallScriptForApp(cmd);
    console.log(`Installing ${cmd} on ${server.name}...`);
    try {
      execSync(
        `ssh -p ${port} -i "${keyPath}" -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no ${user}@${host} "bash -s"`,
        { input: installScript, timeout: 180000, stdio: ['pipe', 'inherit', 'inherit'] }
      );
      console.log(`✔ Successfully installed ${cmd} on ${server.name}.`);
      return;
    } catch (e) {
      console.error(`Failed to install ${cmd} on ${server.name}: ${e.message}`);
      process.exit(1);
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

  if (subcmd === 'launch' || subcmd === 'stream') {
    const targetServer = rest[0];
    const cmd = rest[1];
    if (!cmd) {
      console.error('Usage: ocloud app launch <server_id_or_name> <command>');
      process.exit(1);
    }

    const { server, host, user, port, keyPath, isTailscale } = await resolveServer(targetServer, registry);

    if (!host || host === '-' || host === 'no IP') {
      console.error(`Error: Server '${server.name}' does not have a reachable IPv4 or Tailscale IP.`);
      process.exit(1);
    }

    // Verify waypipe binary
    const waypipeBin = getWaypipeBin();
    if (!waypipeBin) {
      console.error(`Error: 'waypipe' is not installed on this system.`);
      console.error(`Please install it with: sudo pacman -S waypipe`);
      process.exit(1);
    }

    // Pre-flight probe SSH connectivity
    console.log(`Connecting to ${server.name} via ${isTailscale ? 'Tailscale' : 'IPv4'} (${user}@${host}:${port})...`);
    try {
      execSync(`ssh -p ${port} -i "${keyPath}" -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no ${user}@${host} "echo ready"`, {
        timeout: 10000,
        stdio: 'pipe'
      });
    } catch (sshErr) {
      const errMsg = (sshErr.stderr ? sshErr.stderr.toString() : '') || sshErr.message;
      console.error(`Failed to connect to ${server.name} via SSH: ${errMsg.trim()}`);
      process.exit(1);
    }

    // Ensure waypipe exists on remote node, auto-install silently if missing
    let hasDrm = false;
    try {
      const nodeCheck = execSync(
        `ssh -p ${port} -i "${keyPath}" -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no ${user}@${host} "command -v waypipe >/dev/null 2>&1 && echo FOUND || echo NOT_FOUND; test -e /dev/dri/renderD128 && echo DRM_OK || echo NO_DRM"`,
        { timeout: 10000, encoding: 'utf8' }
      ).trim();
      hasDrm = nodeCheck.includes('DRM_OK');
      if (!nodeCheck.includes('FOUND')) {
        console.log(`Auto-installing missing waypipe dependency on ${server.name}...`);
        const wpInstallScript = [
          'if command -v apt-get >/dev/null 2>&1; then',
          '  export DEBIAN_FRONTEND=noninteractive;',
          '  apt-get update -qq;',
          '  apt-get install -y -qq waypipe;',
          'elif command -v pacman >/dev/null 2>&1; then',
          '  pacman -Sy --noconfirm waypipe;',
          'elif command -v dnf >/dev/null 2>&1; then',
          '  dnf install -y -q waypipe;',
          'elif command -v apk >/dev/null 2>&1; then',
          '  apk update -q && apk add --no-cache waypipe;',
          'elif command -v zypper >/dev/null 2>&1; then',
          '  zypper --non-interactive refresh -q && zypper --non-interactive install waypipe;',
          'fi'
        ].join('\n');
        execSync(
          `ssh -p ${port} -i "${keyPath}" -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=no ${user}@${host} "bash -s"`,
          { input: wpInstallScript, timeout: 60000, stdio: ['pipe', 'inherit', 'inherit'] }
        );
      }
    } catch (e) {}

    // Record shortcut in recent_apps
    recordRecentApp(cmd);

    const isHome = Boolean(server.isHomeWorkstation);
    let providerLabel = 'Cloud';
    if (isHome) {
      providerLabel = 'Home Workstation';
    } else if (server.provider === 'hetzner' || (server.providerName && server.providerName.toLowerCase().includes('hetzner'))) {
      providerLabel = 'Hetzner';
    } else if (server.provider === 'gcp' || (server.providerName && server.providerName.toLowerCase().includes('google'))) {
      providerLabel = 'Google Cloud';
    } else if (server.provider === 'aws' || (server.providerName && server.providerName.toLowerCase().includes('amazon'))) {
      providerLabel = 'AWS';
    } else if (server.providerName) {
      providerLabel = server.providerName;
    }

    const titlePrefix = isHome
      ? '[🏠 Home Workstation] '
      : `[☁ ${providerLabel} · ${server.name}] `;

    // Setup pristine low-latency audio tunnel over PipeWire/PulseAudio UNIX socket
    const localPulseSocket = process.env.PULSE_SERVER?.startsWith('unix:')
      ? process.env.PULSE_SERVER.replace('unix:', '')
      : path.join(process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid ? process.getuid() : 1000}`, 'pulse', 'native');
    const hasPulseAudio = fs.existsSync(localPulseSocket);
    const pulseId = crypto.randomBytes(4).toString('hex');
    const remotePulseSocket = `/tmp/pulse-ocloud-${pulseId}.sock`;

    const audioEnv = hasPulseAudio
      ? `PULSE_SERVER=unix:${remotePulseSocket} SDL_AUDIODRIVER=pulseaudio ALSOFT_DRIVERS=pulse`
      : 'PULSE_SERVER=tcp:localhost:4713';

    const remoteExec = `env PATH=/root/.local/bin:/home/${user}/.local/bin:/usr/local/bin:/usr/bin:$PATH OCLOUD_PROVIDER="${providerLabel}" OCLOUD_SERVER="${server.name}" ${audioEnv} QT_QPA_PLATFORM=wayland QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=1500 ${cmd}`;

    console.log(`\x1b[36m🚀 Streaming "${cmd}" from ${server.name} via Waypipe (${hasDrm ? 'Hardware DRM' : 'Software SHM'})...\x1b[0m`);
    console.log(`Window Prefix: "${titlePrefix}"`);
    if (hasPulseAudio) {
      console.log(`🔊 Audio: PipeWire native UNIX socket forwarded (${localPulseSocket} -> ${remotePulseSocket})`);
    }

    const env = {
      ...process.env,
      WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'wayland-1',
      XDG_RUNTIME_DIR: process.env.XDG_RUNTIME_DIR || path.join('/run', 'user', String(process.getuid ? process.getuid() : 1000))
    };

    const sshArgs = [
      '-p', String(port),
      '-i', keyPath,
      '-o', 'BatchMode=yes',
      '-o', 'StrictHostKeyChecking=no'
    ];

    if (hasPulseAudio) {
      sshArgs.push('-R', `${remotePulseSocket}:${localPulseSocket}`);
    } else {
      sshArgs.push('-R', '4713:localhost:4713');
    }

    const waypipeArgs = [
      '--title-prefix', titlePrefix,
      ...(hasDrm ? ['--video=h264'] : ['--no-gpu', '--compress=lz4']),
      '--threads', '4',
      'ssh',
      ...sshArgs,
      `${user}@${host}`,
      remoteExec
    ];

    const child = spawn(
      waypipeBin,
      waypipeArgs,
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
