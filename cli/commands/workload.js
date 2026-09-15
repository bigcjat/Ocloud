const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync, spawn } = require('child_process');

/**
 * Resolves a target server from registry by ID or Name.
 */
async function resolveServer(target, registry) {
  let allServers = [];
  try {
    allServers = await registry.listAllServers();
  } catch (e) {
    allServers = [];
  }

  // Fallback check in vault/state if driver servers not populated
  if (allServers.length === 0 && registry.vault) {
    try {
      const state = registry.vault.get('statusData') || {};
      allServers = state.servers || [];
    } catch (e) {}
  }

  if (!target) {
    return allServers.find((s) => s.status === 'running') || allServers[0] || null;
  }

  const s = allServers.find(
    (item) => String(item.id) === String(target) || (item.name && item.name.toLowerCase() === target.toLowerCase())
  );
  return s || null;
}

/**
 * Executes a remote command over SSH safely.
 */
function execRemote(server, remoteScript, options = {}) {
  const host = server.tailscale_ip || server.ipv4;
  if (!host) throw new Error(`Server '${server.name || server.id}' has no IP address.`);

  const port = String(server.port || 22);
  const user = server.user || 'root';
  const defaultKey = path.join(os.homedir(), '.ssh', 'id_ed25519');
  const keyPath = server.keyPath || (fs.existsSync(defaultKey) ? defaultKey : path.join(os.homedir(), '.ssh', 'id_rsa'));

  const sshArgs = [
    '-p', port,
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'ConnectTimeout=10',
    '-o', 'BatchMode=yes'
  ];

  if (fs.existsSync(keyPath)) {
    sshArgs.push('-i', keyPath);
  }

  sshArgs.push(`${user}@${host}`, remoteScript);

  try {
    return execFileSync('ssh', sshArgs, {
      encoding: 'utf8',
      timeout: options.timeout || 30000,
      stdio: options.stdio || ['pipe', 'pipe', 'pipe']
    });
  } catch (err) {
    const stderr = err.stderr ? err.stderr.toString() : '';
    const stdout = err.stdout ? err.stdout.toString() : '';
    throw new Error(stderr.trim() || stdout.trim() || err.message);
  }
}

/**
 * Main Workload CLI entry point.
 */
async function cmdWorkload(subcmd, args = [], context = {}) {
  const { registry } = context;
  const isJson = args.includes('--json');
  const filteredArgs = args.filter((a) => a !== '--json');

  // ==========================================
  // 1. TEMPLATES LISTING
  // ==========================================
  if (subcmd === 'templates' || subcmd === 'template-list') {
    const plugins = registry.listWorkloadPlugins ? registry.listWorkloadPlugins() : [];
    if (isJson) {
      console.log(JSON.stringify(plugins, null, 2));
    } else {
      console.log(`\n\x1b[1;36m📦 Ocloud Workload Templates (${plugins.length} Available)\x1b[0m`);
      console.log('━'.repeat(60));
      for (const p of plugins) {
        const ports = (p.workload && p.workload.ports) ? p.workload.ports.join(', ') : 'none';
        const customTag = p.isCustom ? ' \x1b[33m[Custom]\x1b[0m' : '';
        console.log(`  • \x1b[1m${p.id.padEnd(20)}\x1b[0m ${p.name}${customTag}`);
        console.log(`    \x1b[2mImage:\x1b[0m ${(p.workload && p.workload.image) || 'n/a'}  \x1b[2mPorts:\x1b[0m ${ports}`);
        console.log(`    \x1b[2m${p.description || ''}\x1b[0m\n`);
      }
    }
    return plugins;
  }

  // ==========================================
  // 2. SAVE CUSTOM TEMPLATE
  // ==========================================
  if (subcmd === 'save-template' || subcmd === 'add-template') {
    const rawJson = filteredArgs[0];
    if (!rawJson) {
      throw new Error('Usage: ocloud workload save-template \'<json-manifest>\'');
    }
    const manifest = typeof rawJson === 'object' ? rawJson : JSON.parse(rawJson);
    const saved = registry.saveCustomWorkloadPlugin(manifest);
    if (isJson) {
      console.log(JSON.stringify({ ok: true, plugin: saved }));
    } else {
      console.log(`\x1b[32m✔ Template '${saved.name}' (${saved.id}) saved successfully.\x1b[0m`);
    }
    return;
  }

  // ==========================================
  // 3. DELETE CUSTOM TEMPLATE
  // ==========================================
  if (subcmd === 'delete-template' || subcmd === 'remove-template') {
    const templateId = filteredArgs[0];
    if (!templateId) throw new Error('Usage: ocloud workload delete-template <id>');
    registry.deleteCustomWorkloadPlugin(templateId);
    if (isJson) {
      console.log(JSON.stringify({ ok: true, id: templateId }));
    } else {
      console.log(`\x1b[32m✔ Template '${templateId}' deleted.\x1b[0m`);
    }
    return;
  }

  // Target server is required for all other commands
  const serverTarget = filteredArgs[0];
  const server = await resolveServer(serverTarget, registry);
  if (!server) {
    throw new Error(`Server '${serverTarget || 'default'}' not found.`);
  }

  // ==========================================
  // 4. CHECK DOCKER STATUS
  // ==========================================
  if (subcmd === 'status' || subcmd === 'check') {
    let installed = false;
    let running = false;
    let version = '';

    try {
      const out = execRemote(server, 'command -v docker && docker --version && systemctl is-active docker', { timeout: 10000 });
      const lines = out.trim().split('\n');
      installed = lines.some((l) => l.includes('docker'));
      running = lines.some((l) => l.trim() === 'active');
      const vLine = lines.find((l) => l.toLowerCase().includes('version'));
      if (vLine) version = vLine.trim();
    } catch (e) {
      installed = false;
      running = false;
    }

    const res = {
      serverId: String(server.id),
      serverName: server.name,
      installed,
      running,
      version
    };

    if (isJson) {
      console.log(JSON.stringify(res, null, 2));
    } else {
      console.log(`\n\x1b[1;36m🐳 Docker Daemon Status on ${server.name} (${server.tailscale_ip || server.ipv4}):\x1b[0m`);
      console.log(`  • Installed: ${installed ? '\x1b[32myes\x1b[0m' : '\x1b[31mno\x1b[0m'}`);
      console.log(`  • Running:   ${running ? '\x1b[32myes (active)\x1b[0m' : '\x1b[31mno (inactive)\x1b[0m'}`);
      if (version) console.log(`  • Version:   ${version}`);
      console.log();
    }
    return res;
  }

  // ==========================================
  // 5. BOOTSTRAP DOCKER DAEMON
  // ==========================================
  if (subcmd === 'bootstrap' || subcmd === 'install-docker') {
    console.log(`\n\x1b[1;36m⚡ Bootstrapping Docker daemon on ${server.name}...\x1b[0m`);
    const bootstrapScript = `
      set -e
      if [ -f /etc/arch-release ]; then
        echo "Detected Arch Linux node..."
        pacman -Sy --noconfirm docker docker-compose
        systemctl enable --now docker
      elif [ -f /etc/debian_version ]; then
        echo "Detected Debian/Ubuntu node..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y docker.io docker-compose || apt-get install -y docker.io
        systemctl enable --now docker
      elif [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ]; then
        echo "Detected RHEL/Fedora node..."
        dnf install -y docker
        systemctl enable --now docker
      else
        echo "Running generic Docker installation script..."
        curl -fsSL https://get.docker.com | sh
        systemctl enable --now docker
      fi
      docker --version
    `;

    try {
      const out = execRemote(server, bootstrapScript, { timeout: 180000 });
      const res = { ok: true, server: server.name, out: out.trim() };
      if (isJson) {
        console.log(JSON.stringify(res));
      } else {
        console.log(`\x1b[32m✔ Docker bootstrapped and running on ${server.name}!\x1b[0m\n${out.trim()}`);
      }
      return res;
    } catch (err) {
      throw new Error(`Failed to bootstrap Docker on ${server.name}: ${err.message}`);
    }
    return;
  }

  // ==========================================
  // 6. LIST CONTAINERS
  // ==========================================
  if (subcmd === 'list' || subcmd === 'ps') {
    let containers = [];
    try {
      const out = execRemote(server, "docker ps -a --format '{{json .}}' 2>/dev/null || true", { timeout: 15000 });
      const lines = out.trim().split('\n');
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const raw = JSON.parse(line.trim());
          const name = raw.Names || raw.name || raw.ID;
          const status = raw.Status || raw.status || 'unknown';
          const isRunning = status.toLowerCase().includes('up') || status.toLowerCase().includes('running');
          const ports = raw.Ports || raw.ports || '';
          
          // Generate Tailscale URLs
          const tailscaleIp = server.tailscale_ip;
          const urls = [];
          const portMatches = ports.matchAll(/(\d+)->(\d+)/g);
          for (const m of portMatches) {
            const hostPort = m[1];
            if (tailscaleIp) {
              urls.push({
                port: hostPort,
                tailscaleUrl: `http://${tailscaleIp}:${hostPort}`,
                label: `Port ${hostPort}`
              });
            }
          }

          containers.push({
            id: raw.ID || raw.id,
            name,
            image: raw.Image || raw.image,
            status,
            isRunning,
            ports,
            urls,
            created: raw.CreatedAt || raw.created,
            serverName: server.name,
            serverId: String(server.id)
          });
        } catch (pe) {}
      }
    } catch (err) {
      containers = [];
    }

    if (isJson) {
      console.log(JSON.stringify(containers, null, 2));
    } else {
      console.log(`\n\x1b[1;36m🚢 Active Containers on ${server.name} (${containers.length})\x1b[0m`);
      console.log('━'.repeat(65));
      if (containers.length === 0) {
        console.log('  No containers currently deployed.');
      } else {
        for (const c of containers) {
          const dot = c.isRunning ? '\x1b[32m●\x1b[0m' : '\x1b[31m○\x1b[0m';
          console.log(`  ${dot} \x1b[1m${c.name}\x1b[0m (${c.image})`);
          console.log(`    \x1b[2mStatus:\x1b[0m ${c.status}  \x1b[2mPorts:\x1b[0m ${c.ports || 'none'}`);
          if (c.urls.length > 0) {
            console.log(`    \x1b[34mTailscale URL:\x1b[0m ${c.urls[0].tailscaleUrl}`);
          }
          console.log();
        }
      }
    }
    return containers;
  }

  // ==========================================
  // 7. DEPLOY WORKLOAD CONTAINER
  // ==========================================
  if (subcmd === 'deploy' || subcmd === 'run') {
    const workloadTarget = filteredArgs[1];
    if (!workloadTarget) {
      throw new Error('Usage: ocloud workload deploy <server> <pluginId|image> [--name=...] [--ports=...] [--tailscale]');
    }

    // Check if workloadTarget matches a registered workload plugin
    const plugin = registry.getWorkloadPlugin ? registry.getWorkloadPlugin(workloadTarget) : null;
    const pConf = (plugin && plugin.workload) || {};

    let image = pConf.image || workloadTarget;
    let name = '';
    let ports = pConf.ports || [];
    let volumes = pConf.volumes || [];
    let envMap = { ...(pConf.env || {}) };
    let restart = pConf.restart || 'unless-stopped';
    let command = pConf.command || '';
    let useTailscale = true; // Tailscale private mesh binding enabled by default

    // Parse options from args
    for (let i = 2; i < filteredArgs.length; i++) {
      const arg = filteredArgs[i];
      if (arg.startsWith('--name=')) name = arg.slice(7);
      else if (arg.startsWith('--image=')) image = arg.slice(8);
      else if (arg.startsWith('--ports=')) ports = arg.slice(8).split(',').map((p) => p.trim());
      else if (arg.startsWith('--volumes=')) volumes = arg.slice(10).split(',').map((v) => v.trim());
      else if (arg.startsWith('--restart=')) restart = arg.slice(10);
      else if (arg.startsWith('--env=')) {
        const parts = arg.slice(6).split('=');
        if (parts.length >= 2) envMap[parts[0]] = parts.slice(1).join('=');
      } else if (arg === '--public') {
        useTailscale = false;
      } else if (arg === '--tailscale' || arg === '--private') {
        useTailscale = true;
      }
    }

    if (!name) {
      name = (plugin ? plugin.id : workloadTarget.split(/[/:]/).pop()).replace(/[^a-zA-Z0-9_-]/g, '-');
    }

    // Build docker run command with optional Tailscale binding
    const tailscaleIp = server.tailscale_ip;
    const portFlags = [];

    for (const p of ports) {
      if (!p) continue;
      if (useTailscale && tailscaleIp && !p.includes(':') && !p.includes('/')) {
        // e.g. "8080" -> "100.80.32.106:8080:8080"
        portFlags.push(`-p ${tailscaleIp}:${p}:${p}`);
      } else if (useTailscale && tailscaleIp) {
        // e.g. "8080:80" -> "100.80.32.106:8080:80"
        const parts = p.split(':');
        if (parts.length === 2) {
          portFlags.push(`-p ${tailscaleIp}:${parts[0]}:${parts[1]}`);
        } else {
          portFlags.push(`-p ${p}`);
        }
      } else {
        portFlags.push(`-p ${p}`);
      }
    }

    const volFlags = volumes.map((v) => `-v "${v}"`).join(' ');
    const envFlags = Object.entries(envMap).map(([k, v]) => `-e "${k}=${v}"`).join(' ');

    const dockerCmd = `docker run -d --name "${name}" --restart "${restart}" ${portFlags.join(' ')} ${volFlags} ${envFlags} ${image} ${command}`.replace(/\s+/g, ' ').trim();

    console.log(`\n\x1b[1;36m🚀 Deploying container '${name}' on ${server.name}...\x1b[0m`);
    if (useTailscale && tailscaleIp) {
      console.log(`  \x1b[34m✔ Tailscale mesh-exclusive binding enabled (${tailscaleIp})\x1b[0m`);
    }

    try {
      const cid = execRemote(server, dockerCmd, { timeout: 60000 }).trim();
      
      const res = {
        ok: true,
        containerId: cid,
        name,
        image,
        server: server.name,
        tailscaleIp: tailscaleIp || null,
        ports,
        boundTailscale: !!(useTailscale && tailscaleIp)
      };

      if (isJson) {
        console.log(JSON.stringify(res, null, 2));
      } else {
        console.log(`\x1b[32m✔ Container '${name}' launched successfully! (ID: ${cid.slice(0, 12)})\x1b[0m`);
        if (useTailscale && tailscaleIp && ports.length > 0) {
          const firstPort = ports[0].split(':')[0];
          console.log(`  🔗 Mesh URL: \x1b[1;34mhttp://${tailscaleIp}:${firstPort}\x1b[0m`);
        }
        console.log();
      }
      return res;
    } catch (err) {
      throw new Error(`Failed to deploy container '${name}' on ${server.name}: ${err.message}`);
    }
    return;
  }

  // ==========================================
  // 8. CONTAINER ACTIONS (START, STOP, RESTART, DELETE, LOGS)
  // ==========================================
  if (subcmd === 'action' || subcmd === 'control') {
    const containerId = filteredArgs[1];
    const action = (filteredArgs[2] || 'restart').toLowerCase();

    if (!containerId) {
      throw new Error('Usage: ocloud workload action <server> <containerId> <start|stop|restart|delete|logs>');
    }

    let cmd = '';
    if (action === 'delete' || action === 'remove' || action === 'rm') {
      cmd = `docker rm -f "${containerId}"`;
    } else if (action === 'logs') {
      cmd = `docker logs --tail 100 "${containerId}"`;
    } else {
      cmd = `docker ${action} "${containerId}"`;
    }

    try {
      const out = execRemote(server, cmd, { timeout: 20000 }).trim();
      const res = { ok: true, action, containerId, server: server.name, output: out };
      if (isJson) {
        console.log(JSON.stringify(res, null, 2));
      } else {
        console.log(`\x1b[32m✔ Action '${action}' on '${containerId}' completed on ${server.name}.\x1b[0m`);
        if (action === 'logs' && out) console.log(out);
      }
      return res;
    } catch (err) {
      throw new Error(`Action '${action}' failed on ${containerId}: ${err.message}`);
    }
    return;
  }

  throw new Error(`Unknown workload command: '${subcmd}'. Available: templates, status, bootstrap, list, deploy, action, save-template, delete-template`);
}

module.exports = { cmdWorkload };
