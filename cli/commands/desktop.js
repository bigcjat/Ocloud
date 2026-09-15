const fs = require('fs');
const path = require('path');
const os = require('os');
const net = require('net');
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
    ? ['wlfreerdp', 'xfreerdp', 'sdl-freerdp', 'remmina', 'xpra']
    : ['vncviewer', 'tigervnc', 'remmina', 'xpra'];

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

      // Check RDP & VNC simultaneously
      const [rdpRes, vncRes, sshRes] = await Promise.all([
        probePort(targetIp, 3389, 500),
        probePort(targetIp, 5900, 500),
        probePort(targetIp, 22, 500)
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

      // Retrieve saved credentials if available
      if (vault) {
        try {
          const creds = vault.get(`desktop_creds_${m.id}`) || {};
          m.hasSavedCreds = !!(creds.username || creds.password);
          m.savedUser = creds.username || '';
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
        const portStatus = m.portOpen ? `\x1b[32m${m.detectedProtocol.toUpperCase()} :${m.detectedPort}\x1b[0m` : `\x1b[90m${m.detectedProtocol.toUpperCase()} :${m.detectedPort} (closed)\x1b[0m`;
        const lat = m.latencyMs > 0 ? `\x1b[33m${m.latencyMs}ms\x1b[0m` : '\x1b[90m-\x1b[0m';
        console.log(`  ${statusDot} \x1b[1m${m.name.padEnd(24)}\x1b[0m \x1b[34m${(m.tailscaleIp || 'no-ip').padEnd(16)}\x1b[0m ${portStatus.padEnd(26)} ${lat}`);
      }
      console.log('');
    }
    return enriched;
  }

  // ==========================================
  // 2. PROBE TARGET NODE
  // ==========================================
  if (subcmd === 'probe') {
    const target = filteredArgs[0];
    if (!target) throw new Error('Usage: ocloud desktop probe <node-id-or-name>');
    const machines = await discoverMachines(registry);
    const m = machines.find((item) => item.id === target || item.name.toLowerCase() === target.toLowerCase());
    if (!m) throw new Error(`Node '${target}' not found in fleet or tailnet.`);

    const host = m.tailscaleIp || m.ipv4;
    const [rdp, vnc, ssh] = await Promise.all([
      probePort(host, 3389, 1000),
      probePort(host, 5900, 1000),
      probePort(host, 22, 1000)
    ]);

    const res = {
      id: m.id,
      name: m.name,
      host,
      os: m.os,
      rdp: { port: 3389, open: rdp.open, ms: rdp.ms },
      vnc: { port: 5900, open: vnc.open, ms: vnc.ms },
      ssh: { port: 22, open: ssh.open, ms: ssh.ms }
    };

    if (isJson) {
      console.log(JSON.stringify(res, null, 2));
    } else {
      console.log(`\n\x1b[1;36m🔍 Probe Results for ${m.name} (${host})\x1b[0m`);
      console.log(`  • RDP (3389): ${rdp.open ? `\x1b[32mOPEN (${rdp.ms}ms)\x1b[0m` : '\x1b[90mClosed\x1b[0m'}`);
      console.log(`  • VNC (5900): ${vnc.open ? `\x1b[32mOPEN (${vnc.ms}ms)\x1b[0m` : '\x1b[90mClosed\x1b[0m'}`);
      console.log(`  • SSH (22):   ${ssh.open ? `\x1b[32mOPEN (${ssh.ms}ms)\x1b[0m` : '\x1b[90mClosed\x1b[0m'}\n`);
    }
    return res;
  }

  // ==========================================
  // 3. LAUNCH BREAKOUT WINDOW
  // ==========================================
  if (subcmd === 'launch' || subcmd === 'breakout' || subcmd === 'connect') {
    const target = filteredArgs[0];
    if (!target) throw new Error('Usage: ocloud desktop launch <node> [--user=U] [--password=P]');

    const machines = await discoverMachines(registry);
    const m = machines.find((item) => item.id === target || item.name.toLowerCase() === target.toLowerCase());
    if (!m) throw new Error(`Node '${target}' not found in fleet or tailnet.`);

    const host = m.tailscaleIp || m.ipv4;
    if (!host) throw new Error(`Node '${m.name}' has no reachable IP address.`);

    // Extract user/password from args or vault
    let user = '';
    let pass = '';
    for (const a of filteredArgs) {
      if (a.startsWith('--user=')) user = a.split('=')[1];
      if (a.startsWith('--password=')) pass = a.split('=')[1];
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

    const protocol = m.os === 'windows' ? 'rdp' : (m.os === 'macos' ? 'vnc' : 'rdp');
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

    let spawnArgs = [];
    if (viewer.name === 'wlfreerdp' || viewer.name === 'xfreerdp' || viewer.name === 'sdl-freerdp') {
      spawnArgs = [
        `/v:${host}`,
        '/cert:ignore',
        '/dynamic-resolution',
        '+clipboard',
        '/sound:sys:pulse',
        '+auto-reconnect'
      ];
      if (user) spawnArgs.push(`/u:${user}`);
      if (pass) spawnArgs.push(`/p:${pass}`);
    } else if (viewer.name === 'vncviewer' || viewer.name === 'tigervnc') {
      spawnArgs = [`${host}:5900`];
      if (user) spawnArgs.push(`-user=${user}`);
    } else if (viewer.name === 'xpra') {
      if (protocol === 'vnc') {
        spawnArgs = ['attach', `vnc://${host}:5900`];
      } else {
        spawnArgs = ['shadow', `ssh://${user || 'root'}@${host}`];
      }
    }

    // Detach and run standalone window
    const child = spawn(viewer.path, spawnArgs, {
      detached: true,
      stdio: 'ignore'
    });
    child.unref();

    const result = {
      ok: true,
      node: m.name,
      host,
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
  // 4. SAVE CREDENTIALS IN VAULT
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

  throw new Error(`Unknown desktop subcommand: ${subcmd}`);
}

module.exports = { cmdDesktop, discoverMachines, probePort };
