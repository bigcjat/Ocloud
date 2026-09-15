const fs = require('fs');
const path = require('path');
const os = require('os');
const net = require('net');
const crypto = require('crypto');
const { spawn, execSync } = require('child_process');

/**
 * Rapid non-blocking TCP socket port probe.
 */
function probePort(host, port, timeoutMs = 800) {
  return new Promise((resolve) => {
    if (!host) return resolve({ open: false, error: 'no-host', ms: 0 });
    const s = new net.Socket();
    const start = Date.now();
    s.setTimeout(timeoutMs);
    s.on('connect', () => {
      const ms = Date.now() - start;
      s.destroy();
      resolve({ open: true, ms });
    });
    s.on('timeout', () => {
      s.destroy();
      resolve({ open: false, error: 'timeout', ms: timeoutMs });
    });
    s.on('error', (err) => {
      s.destroy();
      resolve({ open: false, error: err.code || 'error', ms: Date.now() - start });
    });
    try {
      s.connect(port, host);
    } catch (e) {
      resolve({ open: false, error: e.message, ms: 0 });
    }
  });
}

/**
 * Discovers reachable machines via Ocloud Registry and local Tailscale peers.
 */
async function discoverMachines(registry) {
  const machines = new Map();

  // 1. Check Cloud Fleet servers
  try {
    const servers = (registry.listAllServers ? await registry.listAllServers() : []) || [];
    for (const s of servers) {
      const id = String(s.id || s.name);
      machines.set(id, {
        id,
        name: s.name || `Node-${s.id}`,
        os: 'linux',
        ipv4: s.ipv4 || '',
        tailscaleIp: s.tailscale_ip || '',
        provider: s.provider || 'cloud',
        providerName: s.providerName || 'Cloud Node',
        type: s.type || 'VM',
        status: s.status || 'unknown',
        isLocal: false,
        online: s.status === 'running'
      });
    }
  } catch (e) {}

  // 2. Discover Tailscale peers
  try {
    const tsRaw = execSync('tailscale status --json', { timeout: 2000, encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
    const tsData = JSON.parse(tsRaw);
    if (tsData && tsData.Peer) {
      for (const p of Object.values(tsData.Peer)) {
        const h = p.HostName || (p.DNSName || '').split('.')[0] || 'Peer';
        const ipv4 = (p.TailscaleIPs || []).find((ip) => ip.includes('.'));
        if (!ipv4) continue;

        let osType = 'linux';
        const rawOs = (p.OS || '').toLowerCase();
        if (rawOs.includes('windows') || rawOs.includes('win')) osType = 'windows';
        else if (rawOs.includes('mac') || rawOs.includes('darwin')) osType = 'macos';
        else if (rawOs.includes('android')) osType = 'android';
        else if (rawOs.includes('ios')) osType = 'ios';

        // Check if already in machines from cloud servers
        let existingKey = null;
        for (const [k, v] of machines.entries()) {
          if (v.name.toLowerCase() === h.toLowerCase() || (v.tailscaleIp && v.tailscaleIp === ipv4)) {
            existingKey = k;
            break;
          }
        }

        if (existingKey) {
          const m = machines.get(existingKey);
          m.tailscaleIp = ipv4;
          m.online = p.Online !== false;
          if (osType !== 'linux') m.os = osType;
        } else {
          // Add peer as standalone machine
          const peerId = `ts_${h.toLowerCase().replace(/[^a-z0-9_-]/g, '_')}`;
          machines.set(peerId, {
            id: peerId,
            name: h,
            os: osType,
            ipv4: '',
            tailscaleIp: ipv4,
            provider: osType === 'macos' ? 'apple' : (osType === 'windows' ? 'microsoft' : 'tailscale'),
            providerName: osType === 'macos' ? 'Apple Mac' : (osType === 'windows' ? 'Windows PC' : 'Tailnet Node'),
            type: osType.toUpperCase(),
            status: p.Online ? 'running' : 'offline',
            isLocal: true,
            online: p.Online !== false
          });
        }
      }
    }
  } catch (e) {}

  return Array.from(machines.values());
}

/**
 * Finds the best installed client viewer for a protocol.
 */
function findInstalledViewer(protocol) {
  const candidates = protocol === 'rdp'
    ? ['xfreerdp', 'wlfreerdp', 'sdl-freerdp', 'remmina']
    : ['vncviewer', 'tigervnc', 'wlvncc', 'remmina'];

  const searchDirs = [
    path.join(os.homedir(), '.local', 'bin'),
    '/usr/local/bin',
    '/usr/bin',
    '/bin'
  ];

  for (const bin of candidates) {
    for (const dir of searchDirs) {
      const full = path.join(dir, bin);
      try {
        if (fs.existsSync(full) && fs.statSync(full).isFile()) {
          return { name: bin, path: full };
        }
      } catch (e) {}
    }
    try {
      const out = execSync(`command -v ${bin} 2>/dev/null`, { encoding: 'utf8' }).trim();
      if (out) return { name: bin, path: out };
    } catch (e) {}
  }
  return null;
}

/**
 * Finds the best installed Wayland/X11 terminal.
 */
function findInstalledTerminal() {
  const candidates = ['foot', 'kitty', 'alacritty', 'ghostty', 'wezterm', 'xterm'];
  for (const bin of candidates) {
    try {
      const out = execSync(`command -v ${bin} 2>/dev/null`, { encoding: 'utf8' }).trim();
      if (out) return { name: bin, path: out };
    } catch (e) {}
  }
  return null;
}

/**
 * Main CLI handler for `ocloud desktop`
 */
async function cmdDesktop(subcmd, args = [], context = {}) {
  const { registry, vault } = context;
  const isJson = args.includes('--json');
  const filteredArgs = args.filter((a) => a !== '--json');

  // ==========================================
  // 1. LIST MACHINES WITH PROTOCOL PROBES
  // ==========================================
  if (subcmd === 'list' || !subcmd) {
    const machines = await discoverMachines(registry);

    // Parallel port probes for RDP (3389), VNC (5900), SSH (22)
    const probePromises = machines.map(async (m) => {
      const targetIp = m.tailscaleIp || m.ipv4;
      if (!targetIp || !m.online) {
        m.detectedProtocol = m.os === 'windows' ? 'rdp' : (m.os === 'macos' ? 'vnc' : 'ssh');
        m.detectedPort = m.detectedProtocol === 'rdp' ? 3389 : (m.detectedProtocol === 'vnc' ? 5900 : 22);
        m.portOpen = false;
        m.latencyMs = 0;
        return m;
      }

      // Check RDP & VNC simultaneously with 1500ms timeout for cross-continent connections
      const [rdpRes, vncRes, sshRes] = await Promise.all([
        probePort(targetIp, 3389, 1500),
        probePort(targetIp, 5900, 1500),
        probePort(targetIp, 22, 1500)
      ]);

      if (rdpRes.open) {
        m.detectedProtocol = 'rdp';
        m.detectedPort = 3389;
        m.portOpen = true;
        m.latencyMs = rdpRes.ms;
      } else if (vncRes.open) {
        m.detectedProtocol = 'vnc';
        m.detectedPort = 5900;
        m.portOpen = true;
        m.latencyMs = vncRes.ms;
      } else if (sshRes.open) {
        m.detectedProtocol = m.os === 'windows' ? 'rdp' : (m.os === 'macos' ? 'vnc' : 'ssh');
        m.detectedPort = m.detectedProtocol === 'rdp' ? 3389 : (m.detectedProtocol === 'vnc' ? 5900 : 22);
        m.portOpen = false;
        m.latencyMs = sshRes.ms;
      } else {
        m.detectedProtocol = m.os === 'windows' ? 'rdp' : (m.os === 'macos' ? 'vnc' : 'ssh');
        m.detectedPort = m.detectedProtocol === 'rdp' ? 3389 : (m.detectedProtocol === 'vnc' ? 5900 : 22);
        m.portOpen = false;
        m.latencyMs = 0;
      }

      // Check viewer availability on host
      const viewer = findInstalledViewer(m.detectedProtocol);
      m.viewer = viewer ? viewer.name : null;
      m.viewerPath = viewer ? viewer.path : null;
      m.viewerInstallCmd = m.detectedProtocol === 'rdp' ? 'sudo pacman -S freerdp' : 'sudo pacman -S tigervnc';

      // Check terminal availability
      const term = findInstalledTerminal();
      m.terminal = term ? term.name : null;

      // Retrieve saved credentials if available
      if (vault) {
        try {
          const creds = vault.get(`desktop_creds_${m.id}`) || {};
          m.hasSavedCreds = !!(creds.username || creds.password);
          m.savedUser = creds.username || '';
          m.savedPass = creds.password || '';
        } catch (e) {}
      }

      return m;
    });

    const enriched = await Promise.all(probePromises);

    if (isJson) {
      console.log(JSON.stringify(enriched, null, 2));
    } else {
      console.log(`\n\x1b[1;36m🖥️  Ocloud Remote Desktop Fleet (${enriched.length} Machines)\x1b[0m`);
      console.log('━'.repeat(75));
      for (const m of enriched) {
        const statusDot = m.online ? '\x1b[32m●\x1b[0m' : '\x1b[90m○\x1b[0m';
        const portStatus = m.portOpen
          ? `\x1b[32m${m.detectedProtocol.toUpperCase()}:${m.detectedPort} OPEN (${m.latencyMs}ms)\x1b[0m`
          : `\x1b[90m${m.detectedProtocol.toUpperCase()}:${m.detectedPort} (offline)\x1b[0m`;
        const clientStatus = m.viewer ? `\x1b[32m${m.viewer}\x1b[0m` : '\x1b[33mNot Installed\x1b[0m';
        console.log(`  ${statusDot} \x1b[1m${m.name.padEnd(26)}\x1b[0m ${(m.tailscaleIp || m.ipv4 || 'No IP').padEnd(16)} ${portStatus.padEnd(38)} Viewer: ${clientStatus}`);
      }
      console.log('━'.repeat(75));
      console.log('  Commands:');
      console.log('    ocloud desktop launch <node>        Launch native standalone desktop session');
      console.log('    ocloud desktop bootstrap <node>     1-click auto-configure remote desktop on server');
      console.log('    ocloud desktop terminal <node>      Spawn native GPU-accelerated foot terminal');
      console.log('    ocloud desktop install-viewers      Install FreeRDP & TigerVNC on this machine\n');
    }
    return enriched;
  }

  // ==========================================
  // 2. PROBE SINGLE MACHINE
  // ==========================================
  if (subcmd === 'probe') {
    const target = filteredArgs[0];
    if (!target) throw new Error('Usage: ocloud desktop probe <node>');

    const machines = await discoverMachines(registry);
    const m = machines.find((item) => item.id === target || item.name.toLowerCase() === target.toLowerCase());
    if (!m) throw new Error(`Node '${target}' not found in fleet or tailnet.`);

    const host = m.tailscaleIp || m.ipv4;
    if (!host) throw new Error(`Node '${m.name}' has no reachable IP address.`);

    const [rdpRes, vncRes, sshRes] = await Promise.all([
      probePort(host, 3389, 1500),
      probePort(host, 5900, 1500),
      probePort(host, 22, 1500)
    ]);

    const res = {
      node: m.name,
      host,
      rdp: rdpRes,
      vnc: vncRes,
      ssh: sshRes,
      recommendedProtocol: rdpRes.open ? 'rdp' : (vncRes.open ? 'vnc' : (m.os === 'macos' ? 'vnc' : 'rdp'))
    };

    if (isJson) console.log(JSON.stringify(res, null, 2));
    else {
      console.log(`\nProbe Results for ${m.name} (${host}):`);
      console.log(`  RDP (3389): ${rdpRes.open ? '\x1b[32mOPEN\x1b[0m' : '\x1b[90mCLOSED\x1b[0m'} (${rdpRes.ms}ms)`);
      console.log(`  VNC (5900): ${vncRes.open ? '\x1b[32mOPEN\x1b[0m' : '\x1b[90mCLOSED\x1b[0m'} (${vncRes.ms}ms)`);
      console.log(`  SSH (22):   ${sshRes.open ? '\x1b[32mOPEN\x1b[0m' : '\x1b[90mCLOSED\x1b[0m'} (${sshRes.ms}ms)`);
      console.log(`  Target Protocol: \x1b[1;36m${res.recommendedProtocol.toUpperCase()}\x1b[0m\n`);
    }
    return res;
  }

  // ==========================================
  // 3. LAUNCH STANDALONE DESKTOP BREAKOUT
  // ==========================================
  if (subcmd === 'launch' || subcmd === 'breakout' || subcmd === 'connect') {
    const target = filteredArgs[0];
    if (!target) throw new Error('Usage: ocloud desktop launch <node> [--user=U] [--password=P] [--protocol=rdp|vnc]');

    const machines = await discoverMachines(registry);
    const m = machines.find((item) => item.id === target || item.name.toLowerCase() === target.toLowerCase());
    if (!m) throw new Error(`Node '${target}' not found in fleet or tailnet.`);

    const host = m.tailscaleIp || m.ipv4;
    if (!host) throw new Error(`Node '${m.name}' has no reachable IP address.`);

    // Extract user/password/protocol from args or vault
    let user = '';
    let pass = '';
    let explicitProto = '';
    for (const a of filteredArgs) {
      if (a.startsWith('--user=')) user = a.split('=')[1];
      if (a.startsWith('--password=')) pass = a.split('=')[1];
      if (a.startsWith('--protocol=')) explicitProto = a.split('=')[1].toLowerCase();
    }

    if (!user || !pass) {
      if (vault) {
        try {
          const saved = vault.get(`desktop_creds_${m.id}`) || {};
          if (!user) user = saved.username || '';
          if (!pass) pass = saved.password || '';
        } catch (e) {}
      }
    }

    // Dynamic protocol and port detection
    let protocol = explicitProto;
    let targetPort = 0;
    if (!protocol) {
      const [rdpCheck, vncCheck] = await Promise.all([
        probePort(host, 3389, 1500),
        probePort(host, 5900, 1500)
      ]);
      if (rdpCheck.open) {
        protocol = 'rdp';
        targetPort = 3389;
      } else if (vncCheck.open) {
        protocol = 'vnc';
        targetPort = 5900;
      } else {
        protocol = m.os === 'windows' ? 'rdp' : (m.os === 'macos' ? 'vnc' : 'rdp');
        targetPort = protocol === 'rdp' ? 3389 : 5900;
      }
    } else {
      targetPort = protocol === 'rdp' ? 3389 : 5900;
    }

    const viewer = findInstalledViewer(protocol);

    if (!viewer) {
      // Fallback hint for installing native viewer
      const installHint = protocol === 'rdp'
        ? 'Please install FreeRDP: sudo pacman -S freerdp'
        : 'Please install TigerVNC: sudo pacman -S tigervnc';

      if (isJson) {
        console.log(JSON.stringify({ ok: false, error: 'no_viewer', installHint }));
      } else {
        console.log(`\x1b[31m✖ No suitable ${protocol.toUpperCase()} viewer found on host.\x1b[0m\n${installHint}`);
      }
      return { ok: false, error: 'no_viewer', installHint };
    }

    if (m.os === 'macos' && protocol === 'vnc' && !user) {
      const msg = `A username is required to authenticate with ${m.name}. Please enter your macOS username in Credentials.`;
      if (isJson) {
        console.log(JSON.stringify({ ok: false, error: 'missing_user', message: msg }));
      } else {
        console.log(`\x1b[31m✖ ${msg}\x1b[0m`);
      }
      return { ok: false, error: 'missing_user', message: msg };
    }

    let spawnArgs = [];
    if (viewer.name === 'wlfreerdp' || viewer.name === 'xfreerdp' || viewer.name === 'sdl-freerdp') {
      spawnArgs = [
        `/v:${host}`,
        '/cert:ignore',
        '/size:1920x1080',
        '/network:auto',
        '+clipboard',
        '/sound:sys:pulse',
        '+auto-reconnect'
      ];
      const rdpUser = user || (m.os === 'macos' ? '' : 'root');
      if (rdpUser) spawnArgs.push(`/u:${rdpUser}`);
      if (pass) spawnArgs.push(`/p:${pass}`);
    } else if (viewer.name === 'vncviewer' || viewer.name === 'tigervnc') {
      const port = targetPort || m.detectedPort || 5900;
      spawnArgs = [`${host}:${port}`];
      if (user && m.os === 'macos') spawnArgs.push(`-user=${user}`);
      if (pass) {
        try {
          const pwFile = path.join(os.tmpdir(), `vnc_pw_${m.id}`);
          const vncpasswdBin = path.join(os.homedir(), '.local', 'bin', 'vncpasswd');
          const binToUse = fs.existsSync(vncpasswdBin) ? vncpasswdBin : 'vncpasswd';
          execSync(`echo "${pass}" | ${binToUse} -f > "${pwFile}" 2>/dev/null && chmod 600 "${pwFile}"`);
          if (fs.existsSync(pwFile) && fs.statSync(pwFile).size > 0) {
            spawnArgs.push(`-passwd=${pwFile}`);
          }
        } catch (e) {}
      }
    }

    const spawnEnv = Object.assign({}, process.env);
    if (!spawnEnv.DISPLAY) spawnEnv.DISPLAY = ':1';
    if (!spawnEnv.WAYLAND_DISPLAY) spawnEnv.WAYLAND_DISPLAY = 'wayland-1';
    if (!spawnEnv.XDG_RUNTIME_DIR) spawnEnv.XDG_RUNTIME_DIR = `/run/user/${process.getuid ? process.getuid() : 1000}`;
    const userLocalBin = path.join(os.homedir(), '.local', 'bin');
    if (!spawnEnv.PATH) spawnEnv.PATH = `${userLocalBin}:/usr/local/bin:/usr/bin:/bin`;
    else if (!spawnEnv.PATH.includes(userLocalBin)) {
      spawnEnv.PATH = `${userLocalBin}:${spawnEnv.PATH}`;
    }

    // Detach and run standalone window
    const child = spawn(viewer.path, spawnArgs, {
      detached: true,
      stdio: 'ignore',
      env: spawnEnv
    });
    child.unref();

    const result = {
      ok: true,
      node: m.name,
      host,
      port: targetPort,
      protocol,
      viewer: viewer.name,
      pid: child.pid
    };

    if (isJson) {
      console.log(JSON.stringify(result));
    } else {
      console.log(`\x1b[32m✔ Launched standalone ${protocol.toUpperCase()} desktop for ${m.name} via ${viewer.name} (PID: ${child.pid})\x1b[0m`);
    }
    return result;
  }

  // ==========================================
  // 4. LAUNCH NATIVE SSH TERMINAL (foot / kitty)
  // ==========================================
  if (subcmd === 'terminal' || subcmd === 'ssh') {
    const target = filteredArgs[0];
    if (!target) throw new Error('Usage: ocloud desktop terminal <node> [--user=U]');

    const machines = await discoverMachines(registry);
    const m = machines.find((item) => item.id === target || item.name.toLowerCase() === target.toLowerCase());
    if (!m) throw new Error(`Node '${target}' not found in fleet or tailnet.`);

    const host = m.tailscaleIp || m.ipv4;
    if (!host) throw new Error(`Node '${m.name}' has no reachable IP address.`);

    let user = '';
    for (const a of filteredArgs) {
      if (a.startsWith('--user=')) user = a.split('=')[1];
    }
    if (!user && vault) {
      try {
        const saved = vault.get(`desktop_creds_${m.id}`) || {};
        user = saved.username || '';
      } catch (e) {}
    }
    if (!user) user = (m.os === 'macos' ? '' : 'root');

    const term = findInstalledTerminal();
    if (!term) throw new Error('No native Wayland terminal found (foot, kitty, alacritty).');

    const sshTarget = user ? `${user}@${host}` : host;
    const child = spawn(term.path, ['-e', 'ssh', '-o', 'StrictHostKeyChecking=no', sshTarget], {
      detached: true,
      stdio: 'ignore',
      env: process.env
    });
    child.unref();

    const res = { ok: true, node: m.name, host, user, terminal: term.name, pid: child.pid };
    if (isJson) console.log(JSON.stringify(res));
    else console.log(`\x1b[32m✔ Launched native terminal for ${sshTarget} via ${term.name} (PID: ${child.pid})\x1b[0m`);
    return res;
  }

  // ==========================================
  // 5. SAVE CREDENTIALS IN VAULT
  // ==========================================
  if (subcmd === 'save-creds') {
    const target = filteredArgs[0];
    const user = filteredArgs[1] || '';
    const pass = filteredArgs[2] || '';
    if (!target) throw new Error('Usage: ocloud desktop save-creds <node> <user> <pass>');

    if (vault) {
      vault.set(`desktop_creds_${target}`, { username: user, password: pass });
    }

    const res = { ok: true, node: target };
    if (isJson) console.log(JSON.stringify(res));
    else console.log(`\x1b[32m✔ Credentials saved for ${target}.\x1b[0m`);
    return res;
  }

  // ==========================================
  // 6. INSTALL LOCAL WAYLAND VIEWERS (1-Click)
  // ==========================================
  if (subcmd === 'install-viewers') {
    const term = findInstalledTerminal();
    if (!term) throw new Error('No native Wayland terminal found to run installer.');

    const installCmd = "echo '==> Ocloud Remote Desktop: Installing FreeRDP & TigerVNC...'; echo ''; if sudo pacman -S --needed freerdp tigervnc; then echo ''; echo '==> Installation successful! Press Enter to close.'; else echo ''; echo '==> Installation failed (incorrect password or cancelled). Press Enter to close.'; fi; read -r";
    const child = spawn(term.path, ['-e', 'sh', '-c', installCmd], {
      detached: true,
      stdio: 'ignore',
      env: process.env
    });
    child.unref();

    const res = { ok: true, terminal: term.name, pid: child.pid };
    if (isJson) console.log(JSON.stringify(res));
    else console.log(`\x1b[32m✔ Launched viewer installer in ${term.name} (PID: ${child.pid})\x1b[0m`);
    return res;
  }

  // ==========================================
  // 7. BOOTSTRAP REMOTE DESKTOP OVER SSH (1-Click)
  // ==========================================
  if (subcmd === 'bootstrap' || subcmd === 'bootstrap-rdp') {
    const target = filteredArgs[0];
    if (!target) throw new Error('Usage: ocloud desktop bootstrap <node> [--user=U]');

    const machines = await discoverMachines(registry);
    const m = machines.find((item) => item.id === target || item.name.toLowerCase() === target.toLowerCase());
    if (!m) throw new Error(`Node '${target}' not found in fleet or tailnet.`);

    const host = m.tailscaleIp || m.ipv4;
    if (!host) throw new Error(`Node '${m.name}' has no reachable IP address.`);

    let user = '';
    let pass = '';
    for (const a of filteredArgs) {
      if (a.startsWith('--user=')) user = a.split('=')[1];
      if (a.startsWith('--password=')) pass = a.split('=')[1];
    }
    if (vault) {
      try {
        const saved = vault.get(`desktop_creds_${m.id}`) || {};
        if (!user) user = saved.username || '';
        if (!pass) pass = saved.password || '';
      } catch (e) {}
    }
    if (!user) user = (m.os === 'macos' ? '' : 'root');
    if (!pass) pass = crypto.randomBytes(6).toString('hex') + '!';

    // Save auto-configured creds to vault
    if (vault) {
      try {
        vault.set(`desktop_creds_${m.id}`, { username: user, password: pass });
      } catch(e) {}
    }

    const defaultKey = path.join(os.homedir(), '.ssh', 'id_ed25519');
    const keyPath = fs.existsSync(defaultKey) ? defaultKey : path.join(os.homedir(), '.ssh', 'id_rsa');

    const setupScript = `
      set -e
      if [ -f /etc/debian_version ]; then
        echo "Configuring XRDP on Debian/Ubuntu..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y xrdp xfce4 xfce4-goodies ssl-cert dbus-x11
        adduser xrdp ssl-cert 2>/dev/null || true
        chmod 644 /etc/xrdp/key.pem 2>/dev/null || true
        killall -9 xfce4-session Xorg 2>/dev/null || true
        rm -rf /tmp/.X11-unix/* /tmp/.xorgxrdp*
        echo "exec dbus-run-session startxfce4" > ~/.xsession
        echo "${user}:${pass}" | chpasswd
        systemctl enable --now xrdp
        systemctl restart xrdp xrdp-sesman
      elif [ -f /etc/arch-release ]; then
        echo "Configuring VNC Desktop on Arch Linux..."
        pacman -Sy --noconfirm tigervnc xorg-server-xvfb xfce4 xfce4-goodies
        mkdir -p ~/.vnc
        echo "${pass}" | vncpasswd -f > ~/.vnc/passwd
        chmod 600 ~/.vnc/passwd
        cat << 'EOF' > /etc/systemd/system/ocloud-vnc.service
[Unit]
Description=Ocloud VNC Desktop Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvnc :1 -geometry 1920x1080 -depth 24 -rfbport 5900 -rfbauth /root/.vnc/passwd -SecurityTypes VncAuth
ExecStartPost=/bin/sh -c "sleep 1; DISPLAY=:1 exec dbus-run-session /usr/bin/startxfce4 &"
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable --now ocloud-vnc.service
        systemctl restart ocloud-vnc.service
      elif [ -f /etc/fedora-release ]; then
        echo "Configuring XRDP on Fedora..."
        dnf install -y xrdp xfce4
        echo "${user}:${pass}" | chpasswd
        systemctl enable --now xrdp
      elif [ "$(uname)" = "Darwin" ]; then
        echo "Configuring macOS Screen Sharing..."
        sudo launchctl enable system/com.apple.screensharing || true
      fi
    `;

    const b64 = Buffer.from(setupScript.trim(), 'utf8').toString('base64');
    const sshArgs = [
      '-o', 'StrictHostKeyChecking=no',
      '-o', 'ConnectTimeout=10',
      '-o', 'BatchMode=yes'
    ];
    if (fs.existsSync(keyPath)) {
      sshArgs.push('-i', keyPath);
    }
    sshArgs.push(`${user}@${host}`);

    const out = execSync(`ssh ${sshArgs.join(' ')} 'echo "${b64}" | base64 -d | bash'`, {
      encoding: 'utf8',
      timeout: 180000
    });

    // Probe both 3389 (RDP) and 5900 (VNC)
    const [probeRdp, probeVnc] = await Promise.all([
      probePort(host, 3389, 2000),
      probePort(host, 5900, 2000)
    ]);
    const openPort = probeRdp.open ? 3389 : (probeVnc.open ? 5900 : null);
    const isOpen = Boolean(openPort);

    const res = {
      ok: true,
      node: m.name,
      host,
      port: openPort || 3389,
      open: isOpen,
      username: user,
      password: pass,
      log: out.trim()
    };
    if (isJson) console.log(JSON.stringify(res));
    else console.log(`\x1b[32m✔ Remote desktop setup complete on ${m.name}! (Port ${res.port} ${isOpen ? 'OPEN' : 'Starting'})\x1b[0m\n${out.trim()}`);
    return res;
  }

  throw new Error(`Unknown desktop subcommand: ${subcmd}`);
}

module.exports = { cmdDesktop, discoverMachines, probePort };
