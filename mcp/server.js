#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');
const { execSync, spawn } = require('child_process');

const { Vault } = require('../security/vault');
const registry = require('../providers/registry');
const { PluginAuditor } = require('../security/plugin_auditor');
const { cmdWorkload } = require('../cli/commands/workload');

// Initialize Core Subsystems
const vault = new Vault();
registry.init(vault);

/**
 * Redacts any sensitive tokens, secrets, or passwords from an object or string
 * before returning it across the MCP boundary to the LLM.
 */
function redactSecrets(obj) {
  if (!obj) return obj;
  if (typeof obj === 'string') {
    // Redact Bearer tokens, hex hashes, or secret keys
    return obj
      .replace(/Bearer\s+[a-zA-Z0-9_-]+/gi, 'Bearer [REDACTED]')
      .replace(/api_token['":\s]+[a-zA-Z0-9_-]+/gi, 'api_token: "[REDACTED]"');
  }
  if (Array.isArray(obj)) {
    return obj.map(redactSecrets);
  }
  if (typeof obj === 'object') {
    const clean = {};
    for (const [k, v] of Object.entries(obj)) {
      const lower = k.toLowerCase();
      if (
        lower.includes('token') ||
        lower.includes('secret') ||
        lower.includes('password') ||
        lower.includes('auth_key') ||
        lower === 'passphrase'
      ) {
        clean[k] = '[REDACTED]';
      } else {
        clean[k] = redactSecrets(v);
      }
    }
    return clean;
  }
  return obj;
}

/**
 * Tool Definitions Schema for Model Context Protocol
 */
const TOOLS = [
  {
    name: 'ocloud_status',
    description: 'Get current status of all running cloud VMs, bare-metal nodes, and virtual cloud drive mounts. Zero credentials leaked.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'ocloud_list_providers',
    description: 'List all installed Compute and Storage plugins with their capabilities and zero-trust security audit status.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          enum: ['all', 'compute', 'storage'],
          description: 'Filter by provider category (default: all)'
        }
      }
    }
  },
  {
    name: 'ocloud_query_catalog',
    description: 'Query live cloud VM catalog with smart filtering by region, RAM, CPU type (dedicated vs shared), and OS image. E.g. find 4GB dedicated RAM in Singapore.',
    inputSchema: {
      type: 'object',
      properties: {
        provider: {
          type: 'string',
          default: 'hetzner',
          description: 'Compute provider ID (e.g. hetzner)'
        },
        location: {
          type: 'string',
          description: 'Datacenter location code (e.g. "sin" for Singapore, "nbg1" for Nuremberg, "ash" for Virginia, "hel1" for Helsinki)'
        },
        min_ram_gb: {
          type: 'number',
          description: 'Minimum RAM in gigabytes (e.g. 4, 8, 16)'
        },
        cpu_type: {
          type: 'string',
          enum: ['all', 'shared', 'dedicated'],
          description: 'CPU allocation: "dedicated" (CCX lines) or "shared" (CX lines)'
        },
        os_flavor: {
          type: 'string',
          description: 'Desired OS image family (e.g. "rocky" / "rhel", "ubuntu", "debian", "fedora")'
        },
        max_price_hourly: {
          type: 'number',
          description: 'Maximum net hourly price in EUR (e.g. 0.05)'
        }
      }
    }
  },
  {
    name: 'ocloud_provision_vm',
    description: 'Spin up a specific on-demand cloud VM. Automatically enforces spending caps and injects public SSH keys and optional Tailnet mesh enrollment.',
    inputSchema: {
      type: 'object',
      required: ['provider', 'name', 'type'],
      properties: {
        provider: {
          type: 'string',
          default: 'hetzner',
          description: 'Compute provider ID'
        },
        name: {
          type: 'string',
          description: 'Instance hostname (e.g. "singapore-build-node")'
        },
        type: {
          type: 'string',
          description: 'Server type ID (e.g. "cx23", "ccx13", "cax11")'
        },
        location: {
          type: 'string',
          default: 'nbg1',
          description: 'Location code (e.g. "sin" for Singapore, "nbg1", "fsn1", "ash")'
        },
        image: {
          type: 'string',
          default: 'ubuntu-24.04',
          description: 'OS image (e.g. "rocky-linux-9", "almalinux-9", "ubuntu-24.04", "debian-12")'
        },
        tailscale_join: {
          type: 'boolean',
          default: true,
          description: 'Whether to enroll into your private Tailnet mesh on boot'
        }
      }
    }
  },
  {
    name: 'ocloud_launch_app',
    description: 'Launch a graphical app streamed via Waypipe into the local Hyprland workspace, or execute a remote batch command/build over SSH.',
    inputSchema: {
      type: 'object',
      required: ['server_id_or_ip', 'command'],
      properties: {
        server_id_or_ip: {
          type: 'string',
          description: 'Target server public IP address or ID'
        },
        command: {
          type: 'string',
          description: 'Application command to launch (e.g. "firefox", "blender", "cargo build --release")'
        },
        stream_gui: {
          type: 'boolean',
          default: true,
          description: 'If true, wraps with Waypipe to stream GUI window directly into local desktop'
        }
      }
    }
  },
  {
    name: 'ocloud_manage_vm',
    description: 'Control power state of a cloud server: start, stop, reboot, or delete.',
    inputSchema: {
      type: 'object',
      required: ['provider', 'server_id', 'action'],
      properties: {
        provider: {
          type: 'string',
          default: 'hetzner',
          description: 'Compute provider ID'
        },
        server_id: {
          type: 'string',
          description: 'Server ID to act upon'
        },
        action: {
          type: 'string',
          enum: ['start', 'stop', 'reboot', 'delete'],
          description: 'Power action to execute'
        }
      }
    }
  },
  {
    name: 'ocloud_mount_storage',
    description: 'Mount or unmount remote cloud storage (Hetzner Storage Box, Cloudflare R2, Google Drive, OneDrive).',
    inputSchema: {
      type: 'object',
      required: ['remote_name', 'action'],
      properties: {
        remote_name: {
          type: 'string',
          description: 'Rclone remote name (e.g. "storagebox", "r2", "drive", "onedrive")'
        },
        action: {
          type: 'string',
          enum: ['mount', 'unmount'],
          description: 'Mount or unmount the virtual cloud drive'
        },
        mount_point: {
          type: 'string',
          description: 'Optional custom mount path (defaults to configured plugin path)'
        }
      }
    }
  },
  {
    name: 'ocloud_audit_plugin',
    description: 'Run zero-trust security audit on any plugin. Checks AST syntax, prototype climbing, unauthorized shell, and domain boundary compliance.',
    inputSchema: {
      type: 'object',
      required: ['target'],
      properties: {
        target: {
          type: 'string',
          description: 'Plugin ID (e.g. "hetzner") or path to plugin directory/json file'
        }
      }
    }
  },
  {
    name: 'ocloud_get_plugin_template',
    description: 'Get boilerplate starter templates for creating a new Ocloud Storage (pure JSON) or Compute (JSON + JS Driver) plugin.',
    inputSchema: {
      type: 'object',
      required: ['plugin_type', 'provider_id', 'provider_name'],
      properties: {
        plugin_type: {
          type: 'string',
          enum: ['storage', 'compute'],
          description: 'Category of plugin'
        },
        provider_id: {
          type: 'string',
          description: 'Machine identifier (e.g. "minio", "wasabi", "vultr")'
        },
        provider_name: {
          type: 'string',
          description: 'Human display name (e.g. "MinIO S3", "Wasabi Hot Storage")'
        }
      }
    }
  },
  {
    name: 'ocloud_install_plugin',
    description: 'Save and install an AI-generated plugin into ~/.config/ocloud/plugins/. Automatically runs the security audit and quarantines if violations exist.',
    inputSchema: {
      type: 'object',
      required: ['provider_id', 'plugin_type', 'files'],
      properties: {
        provider_id: {
          type: 'string',
          description: 'Unique provider identifier'
        },
        plugin_type: {
          type: 'string',
          enum: ['storage', 'compute']
        },
        files: {
          type: 'object',
          description: 'Key-value map of filename to content (e.g. { "plugin.json": "...", "driver.js": "..." })'
        }
      }
    }
  },
  {
    name: 'ocloud_workload_templates',
    description: 'List all available built-in and user-custom workload container templates (e.g. Ollama, PostgreSQL, Vaultwarden, Uptime Kuma) with their images, ports, and metadata.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'ocloud_workload_status',
    description: 'Check if Docker daemon is installed and actively running on a target cloud VM.',
    inputSchema: {
      type: 'object',
      required: ['server'],
      properties: {
        server: {
          type: 'string',
          description: 'Target server ID or name (e.g. "omarchy-companion" or "runner-891")'
        }
      }
    }
  },
  {
    name: 'ocloud_workload_bootstrap',
    description: '1-click unattended installation and startup of Docker engine on a bare target cloud VM.',
    inputSchema: {
      type: 'object',
      required: ['server'],
      properties: {
        server: {
          type: 'string',
          description: 'Target server ID or name'
        }
      }
    }
  },
  {
    name: 'ocloud_workload_list',
    description: 'List all running and stopped Docker containers on a target server, including their IDs, images, live status, and Tailscale connection URLs.',
    inputSchema: {
      type: 'object',
      required: ['server'],
      properties: {
        server: {
          type: 'string',
          description: 'Target server ID or name'
        }
      }
    }
  },
  {
    name: 'ocloud_workload_deploy',
    description: 'Deploy and launch a container on a target server with optional private Tailscale mesh binding (zero public internet exposure).',
    inputSchema: {
      type: 'object',
      required: ['server', 'template_or_image'],
      properties: {
        server: {
          type: 'string',
          description: 'Target server ID or name'
        },
        template_or_image: {
          type: 'string',
          description: 'Workload plugin ID (e.g. "ollama", "postgresql", "uptime_kuma") or raw Docker image tag (e.g. "redis:alpine")'
        },
        name: {
          type: 'string',
          description: 'Custom container name (optional)'
        },
        ports: {
          type: 'string',
          description: 'Port mappings, comma-separated (e.g. "8080:80" or "5432:5432")'
        },
        tailscale: {
          type: 'boolean',
          default: true,
          description: 'If true, binds ports exclusively to the server Tailscale mesh IP for private, zero-internet exposure'
        },
        env: {
          type: 'object',
          description: 'Key-value environment variables'
        },
        volumes: {
          type: 'array',
          items: { type: 'string' },
          description: 'Volume mount specs (e.g. ["mydata:/data"])'
        }
      }
    }
  },
  {
    name: 'ocloud_workload_action',
    description: 'Control a Docker container on a server: start, stop, restart, delete, or fetch logs.',
    inputSchema: {
      type: 'object',
      required: ['server', 'container_id', 'action'],
      properties: {
        server: {
          type: 'string',
          description: 'Target server ID or name'
        },
        container_id: {
          type: 'string',
          description: 'Container ID or container name'
        },
        action: {
          type: 'string',
          enum: ['start', 'stop', 'restart', 'delete', 'logs'],
          description: 'Action to perform'
        }
      }
    }
  }
];

/**
 * Resources Definition Schema for Model Context Protocol
 */
const RESOURCES = [
  {
    uri: 'ocloud://docs/plugin-guide',
    name: 'Ocloud Plugin Development Guide',
    description: 'Complete specification for authoring Storage (pure JSON) and Compute (JS Driver) plugins with zero-trust security rules.',
    mimeType: 'text/markdown'
  },
  {
    uri: 'ocloud://docs/waypipe-streaming',
    name: 'Waypipe GUI Streaming & Audio Reference',
    description: 'Technical tuning and distro guide for low-latency Waypipe remote application streaming into Hyprland.',
    mimeType: 'text/markdown'
  }
];

/**
 * Tool Execution Handlers
 */
async function handleToolCall(name, args = {}) {
  switch (name) {
    case 'ocloud_status': {
      const servers = await registry.listAllServers();
      const storagePlugins = registry.listStoragePlugins();
      return {
        active_compute_servers: servers.map(s => ({
          id: s.id,
          name: s.name,
          ip: s.ip,
          status: s.status,
          serverType: s.serverType,
          location: s.datacenter || s.location,
          hourlyRate: s.hourlyRate
        })),
        installed_storage_providers: storagePlugins.map(p => ({
          id: p.id,
          name: p.name,
          category: p.category,
          defaultMount: p.defaultMount,
          securityStatus: p.securityStatus
        }))
      };
    }

    case 'ocloud_list_providers': {
      const compute = registry.listComputePlugins();
      const storage = registry.listStoragePlugins();
      const quarantined = Array.from(registry.quarantinedPlugins.entries()).map(([k, v]) => ({
        id: k,
        name: v.manifest.name,
        violations: v.report.violations
      }));

      const filter = args.type || 'all';
      const res = {};
      if (filter === 'all' || filter === 'compute') {
        res.compute_providers = compute.map(p => ({
          id: p.id,
          name: p.name,
          pricingFrom: p.pricingFrom,
          allowedDomains: p.allowedDomains,
          securityStatus: p.securityStatus
        }));
      }
      if (filter === 'all' || filter === 'storage') {
        res.storage_providers = storage.map(p => ({
          id: p.id,
          name: p.name,
          category: p.category,
          defaultMount: p.defaultMount,
          allowedDomains: p.allowedDomains,
          securityStatus: p.securityStatus
        }));
      }
      if (quarantined.length > 0) {
        res.quarantined_providers = quarantined;
      }
      return res;
    }

    case 'ocloud_query_catalog': {
      const provider = args.provider || 'hetzner';
      const catalog = await registry.getCatalog(provider, false);
      let types = catalog.server_types || [];
      let locations = catalog.locations || [];
      let images = catalog.images || [];

      if (args.location) {
        const loc = args.location.toLowerCase();
        locations = locations.filter(l => l.id.toLowerCase() === loc || l.name.toLowerCase().includes(loc) || (l.country && l.country.toLowerCase() === loc));
        types = types.filter(t => !t.prices || t.prices[args.location] || t.prices[loc]);
      }

      // Filter by RAM
      if (args.min_ram_gb) {
        types = types.filter(t => t.memory >= args.min_ram_gb);
      }

      // Filter by CPU allocation
      if (args.cpu_type && args.cpu_type !== 'all') {
        types = types.filter(t => t.cpuType === args.cpu_type);
      }

      // Filter by hourly budget
      if (args.max_price_hourly) {
        types = types.filter(t => t.priceHourlyNet <= args.max_price_hourly);
      }

      // Filter by OS flavor
      if (args.os_flavor) {
        const f = args.os_flavor.toLowerCase();
        images = images.filter(img => (img.osFlavor && img.osFlavor.includes(f)) || (img.name && img.name.includes(f)));
      }

      return {
        provider,
        matching_server_types: types.map(t => ({
          id: t.id,
          cores: t.cores,
          memory_gb: t.memory,
          disk_gb: t.disk,
          cpuType: t.cpuType,
          architecture: t.architecture,
          priceHourlyNet: `€${t.priceHourlyNet}/hr`,
          priceMonthlyNet: `€${t.priceMonthlyNet}/mo`
        })),
        available_locations: locations.map(l => ({
          id: l.id,
          name: l.name,
          country: l.country,
          flag: l.flag
        })),
        available_images: images.map(img => ({
          name: img.name,
          flavor: img.osFlavor,
          description: img.description
        }))
      };
    }

    case 'ocloud_provision_vm': {
      const provider = args.provider || 'hetzner';
      const plugin = registry.getComputePlugin(provider);
      if (!plugin || !plugin.driver) {
        throw new Error(`Compute provider '${provider}' is not available.`);
      }

      // Security spending limit check
      const catalog = await registry.getCatalog(provider, false);
      const chosenType = (catalog.server_types || []).find(t => t.id === args.type);
      if (chosenType && chosenType.priceHourlyNet > 0.15) {
        throw new Error(`Spending Guardrail: Server type "${args.type}" exceeds the automatic AI hourly limit (€${chosenType.priceHourlyNet}/hr > €0.15/hr). User must confirm creation manually in GUI.`);
      }

      // Safe parameter sanitization
      const cleanName = String(args.name).replace(/[^a-zA-Z0-9_-]/g, '');
      if (!cleanName) throw new Error('Invalid instance name.');

      const result = await plugin.driver.createServer({
        name: cleanName,
        type: args.type,
        location: args.location || 'nbg1',
        image: args.image || 'ubuntu-24.04',
        tailscaleKey: args.tailscale_join ? 'auto' : null
      });

      return {
        message: `Instance "${cleanName}" provisioning initiated successfully.`,
        server: redactSecrets(result)
      };
    }

    case 'ocloud_launch_app': {
      const server = String(args.server_id_or_ip).replace(/[^a-zA-Z0-9._-]/g, '');
      const cmd = args.command;
      const streamGui = args.stream_gui !== false;

      if (!server || !cmd) throw new Error('Missing server or command parameter.');

      const keyPath = path.join(os.homedir(), '.ssh', 'id_ed25519');
      let fullCmd = '';
      if (streamGui) {
        fullCmd = `waypipe --title-prefix '[☁ Hetzner · ${server}] ' --video=h264,bpf=1200000 --compress=zstd=1 --threads 4 ssh -c aes128-gcm@openssh.com -o Compression=no -o IPQoS=throughput -o BatchMode=yes -o ConnectTimeout=5 -i "${keyPath}" -R 4713:localhost:4713 root@${server} 'env PULSE_SERVER=tcp:localhost:4713 QT_QPA_PLATFORM=wayland QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=16 QSG_RENDER_LOOP=basic ${cmd}'`;
      } else {
        fullCmd = `ssh -o BatchMode=yes -o ConnectTimeout=5 -i "${keyPath}" root@${server} "${cmd}"`;
      }

      // Run detached for GUI apps, or synchronous for CLI
      if (streamGui) {
        spawn('sh', ['-c', fullCmd], { detached: true, stdio: 'ignore' }).unref();
        return {
          status: 'launched',
          command: cmd,
          streaming: 'waypipe',
          target_server: server,
          note: `Application window "${cmd}" streaming to your active Hyprland workspace via Waypipe.`
        };
      } else {
        try {
          const out = execSync(fullCmd, { encoding: 'utf8', timeout: 30000 });
          return {
            status: 'completed',
            command: cmd,
            output: out
          };
        } catch (e) {
          return {
            status: 'failed',
            error: e.message
          };
        }
      }
    }

    case 'ocloud_manage_vm': {
      const provider = args.provider || 'hetzner';
      const plugin = registry.getComputePlugin(provider);
      if (!plugin || !plugin.driver) {
        throw new Error(`Compute provider '${provider}' is not available.`);
      }
      const res = await plugin.driver.powerAction(args.server_id, args.action);
      return {
        server_id: args.server_id,
        action: args.action,
        result: res
      };
    }

    case 'ocloud_mount_storage': {
      const rcloneBin = 'rclone';
      const remote = args.remote_name;
      const mountPoint = args.mount_point || path.join(os.homedir(), 'Cloud');

      if (args.action === 'mount') {
        fs.mkdirSync(mountPoint, { recursive: true });
        execSync(`${rcloneBin} mount "${remote}:" "${mountPoint}" --vfs-cache-mode full --daemon`, { stdio: 'ignore' });
        return { message: `Remote "${remote}:" mounted successfully to ${mountPoint}` };
      } else {
        execSync(`fusermount3 -u "${mountPoint}" || umount "${mountPoint}" || true`, { stdio: 'ignore' });
        return { message: `Unmounted ${mountPoint}` };
      }
    }

    case 'ocloud_audit_plugin': {
      const target = args.target;
      let report = null;
      if (fs.existsSync(target)) {
        if (fs.statSync(target).isDirectory()) {
          report = PluginAuditor.auditPluginDir(target);
        } else {
          report = PluginAuditor.auditJsonPluginFile(target);
        }
      } else {
        report = registry.auditPlugin(target);
      }
      if (!report) throw new Error(`Plugin or path "${target}" not found.`);
      return report;
    }

    case 'ocloud_get_plugin_template': {
      const id = String(args.provider_id).toLowerCase().replace(/[^a-z0-9_]/g, '');
      const name = args.provider_name;

      if (args.plugin_type === 'storage') {
        const jsonTemplate = {
          id,
          name,
          type: 'storage',
          category: 'cloud',
          authType: 's3',
          rcloneType: 's3',
          defaultRemoteName: id,
          defaultMount: `~/${name.replace(/\s+/g, '')}`,
          badge: 'S3 Storage',
          badgeColor: '#2563eb',
          brandColor: '#2563eb',
          tagline: `Connect your ${name} storage buckets directly into Linux.`,
          dashboardUrl: `https://${id}.com`,
          iconSvg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="48" height="48"><rect width="20" height="20" rx="4" fill="#2563eb"/></svg>`,
          instructions: {
            step1: `Log into ${name} and create an API Access Key and Secret.`,
            step2: 'Enter the endpoint URL, Access Key, and Secret below.',
            step3: `Your storage will automatically mount to ~/${name.replace(/\s+/g, '')}.`
          },
          fields: [
            { key: 'endpoint', label: 'Endpoint URL', placeholder: `https://s3.${id}.com`, type: 'text' },
            { key: 'bucket', label: 'Bucket Name', placeholder: 'my-bucket', type: 'text' },
            { key: 'access_key', label: 'Access Key ID', placeholder: 'AKIA...', type: 'text' },
            { key: 'secret_key', label: 'Secret Access Key', placeholder: '...', type: 'password' }
          ],
          allowedDomains: [`*.${id}.com`],
          permissions: { network: true, rclone: true }
        };
        return {
          plugin_type: 'storage',
          filename: `${id}.json`,
          content: JSON.stringify(jsonTemplate, null, 2)
        };
      } else {
        const manifest = {
          id,
          name,
          type: 'compute',
          driver: 'driver.js',
          badge: 'Cloud API',
          badgeColor: '#10b981',
          brandColor: '#10b981',
          tagline: `On-demand ${name} virtual machines with hourly billing.`,
          description: `Direct API provisioning and Waypipe app streaming for ${name}.`,
          pricingFrom: '€0.01 / hr',
          dashboardUrl: `https://console.${id}.com`,
          iconSvg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48"><rect width="48" height="48" rx="10" fill="#10b981"/></svg>`,
          allowedDomains: [`api.${id}.com`],
          permissions: { network: true, ssh: true, system_shell: false },
          auth: {
            type: 'token',
            fields: [
              { key: 'api_token', label: `${name} API Token`, type: 'password', required: true }
            ]
          }
        };

        const driverCode = `const { BaseComputeDriver } = require('../../base');\n\nconst API_BASE = 'https://api.${id}.com/v1';\n\nclass ${name.replace(/[^a-zA-Z]/g, '')}Driver extends BaseComputeDriver {\n  constructor(manifest, context = {}) {\n    super(manifest);\n    this.credentials = context.credentials || context || {};\n  }\n\n  getToken() {\n    return this.credentials.api_token || '';\n  }\n\n  async fetchCatalog() {\n    return {\n      timestamp: Date.now(),\n      provider: '${id}',\n      server_types: [\n        { id: 'standard-1', name: 'std-1', cores: 2, memory: 4, disk: 50, priceHourlyNet: 0.01, cpuType: 'shared', architecture: 'x86' }\n      ],\n      locations: [\n        { id: 'sin', name: 'Singapore', country: 'SG', flag: '🇸🇬' }\n      ],\n      images: [\n        { name: 'ubuntu-24.04', osFlavor: 'ubuntu', description: 'Ubuntu 24.04' }\n      ]\n    };\n  }\n\n  async listServers() { return []; }\n  async createServer() { return { status: 'running' }; }\n  async powerAction(id, action) { return { action, success: true }; }\n}\n\nmodule.exports = ${name.replace(/[^a-zA-Z]/g, '')}Driver;\n`;

        return {
          plugin_type: 'compute',
          files: {
            'plugin.json': JSON.stringify(manifest, null, 2),
            'driver.js': driverCode
          }
        };
      }
    }

    case 'ocloud_install_plugin': {
      const id = String(args.provider_id).toLowerCase().replace(/[^a-z0-9_]/g, '');
      const basePluginDir = path.join(os.homedir(), '.config', 'ocloud', 'plugins');
      const userPluginDir = path.join(basePluginDir, args.plugin_type === 'storage' ? 'storage' : 'compute');
      fs.mkdirSync(userPluginDir, { recursive: true });

      if (args.plugin_type === 'storage') {
        const filePath = path.join(userPluginDir, `${id}.json`);
        const content = typeof args.files === 'string' ? args.files : (args.files['plugin.json'] || args.files[`${id}.json`]);
        fs.writeFileSync(filePath, content, 'utf8');

        // Audit immediately
        const audit = PluginAuditor.auditJsonPluginFile(filePath);
        if (audit.status === 'BLOCKED') {
          fs.unlinkSync(filePath);
          throw new Error(`Plugin installation failed security audit and was rejected: ${audit.violations.join('; ')}`);
        }
        return { success: true, path: filePath, audit: audit.status };
      } else {
        const dirPath = path.join(userPluginDir, id);
        fs.mkdirSync(dirPath, { recursive: true });
        for (const [fname, fcontent] of Object.entries(args.files || {})) {
          fs.writeFileSync(path.join(dirPath, fname), fcontent, 'utf8');
        }

        // Audit immediately
        const audit = PluginAuditor.auditPluginDir(dirPath);
        if (audit.status === 'BLOCKED') {
          fs.rmSync(dirPath, { recursive: true, force: true });
          throw new Error(`Plugin installation failed security audit and was rejected: ${audit.violations.join('; ')}`);
        }
        return { success: true, path: dirPath, audit: audit.status };
      }
    }

    case 'ocloud_workload_templates': {
      return await cmdWorkload('templates', ['--json'], { registry, vault });
    }

    case 'ocloud_workload_status': {
      return await cmdWorkload('status', [args.server, '--json'], { registry, vault });
    }

    case 'ocloud_workload_bootstrap': {
      return await cmdWorkload('bootstrap', [args.server, '--json'], { registry, vault });
    }

    case 'ocloud_workload_list': {
      return await cmdWorkload('list', [args.server, '--json'], { registry, vault });
    }

    case 'ocloud_workload_deploy': {
      const cliArgs = [args.server, args.template_or_image];
      if (args.name) cliArgs.push(`--name=${args.name}`);
      if (args.ports) cliArgs.push(`--ports=${args.ports}`);
      if (args.tailscale === false) cliArgs.push('--public');
      else cliArgs.push('--tailscale');
      if (args.volumes && Array.isArray(args.volumes)) cliArgs.push(`--volumes=${args.volumes.join(',')}`);
      if (args.env && typeof args.env === 'object') {
        for (const [k, v] of Object.entries(args.env)) {
          cliArgs.push(`--env=${k}=${v}`);
        }
      }
      cliArgs.push('--json');
      return await cmdWorkload('deploy', cliArgs, { registry, vault });
    }

    case 'ocloud_workload_action': {
      return await cmdWorkload('action', [args.server, args.container_id, args.action, '--json'], { registry, vault });
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

/**
 * Handle MCP JSON-RPC Request
 */
async function handleRpcRequest(req) {
  const { id, method, params } = req;

  switch (method) {
    case 'initialize': {
      return {
        protocolVersion: '2024-11-05',
        capabilities: {
          tools: {},
          resources: {}
        },
        serverInfo: {
          name: 'ocloud-mcp',
          version: '1.0.0'
        }
      };
    }

    case 'notifications/initialized':
      return null;

    case 'tools/list':
      return { tools: TOOLS };

    case 'tools/call': {
      const toolName = params.name;
      const toolArgs = params.arguments || {};
      try {
        const rawResult = await handleToolCall(toolName, toolArgs);
        const safeResult = redactSecrets(rawResult);
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(safeResult, null, 2)
            }
          ]
        };
      } catch (err) {
        return {
          isError: true,
          content: [
            {
              type: 'text',
              text: `[Ocloud Error] ${err.message}`
            }
          ]
        };
      }
    }

    case 'resources/list':
      return { resources: RESOURCES };

    case 'resources/read': {
      const uri = params.uri;
      if (uri === 'ocloud://docs/plugin-guide') {
        const guidePath = path.join(__dirname, '..', 'docs', 'PLUGIN_DEVELOPMENT_GUIDE.md');
        const text = fs.existsSync(guidePath) ? fs.readFileSync(guidePath, 'utf8') : 'Guide not found.';
        return {
          contents: [
            { uri, mimeType: 'text/markdown', text }
          ]
        };
      } else if (uri === 'ocloud://docs/waypipe-streaming') {
        const waypipeDoc = path.join(__dirname, '..', 'docs', 'WAYPIPE_STREAMING_REFERENCE.md');
        const text = fs.existsSync(waypipeDoc) ? fs.readFileSync(waypipeDoc, 'utf8') : 'Waypipe docs not found.';
        return {
          contents: [
            { uri, mimeType: 'text/markdown', text }
          ]
        };
      } else {
        throw new Error(`Unknown resource URI: ${uri}`);
      }
    }

    default:
      throw new Error(`Method not found: ${method}`);
  }
}

/**
 * Main stdio loop
 */
function startServer() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  rl.on('line', async (line) => {
    const trimmed = line.trim();
    if (!trimmed) return;

    let req = null;
    try {
      req = JSON.parse(trimmed);
    } catch (e) {
      const errResponse = {
        jsonrpc: '2.0',
        id: null,
        error: { code: -32700, message: 'Parse error' }
      };
      process.stdout.write(JSON.stringify(errResponse) + '\n');
      return;
    }

    try {
      const result = await handleRpcRequest(req);
      if (req.id !== undefined && req.id !== null) {
        const response = {
          jsonrpc: '2.0',
          id: req.id,
          result
        };
        process.stdout.write(JSON.stringify(response) + '\n');
      }
    } catch (err) {
      if (req.id !== undefined && req.id !== null) {
        const response = {
          jsonrpc: '2.0',
          id: req.id,
          error: {
            code: -32603,
            message: err.message
          }
        };
        process.stdout.write(JSON.stringify(response) + '\n');
      }
    }
  });
}

if (require.main === module) {
  startServer();
}

module.exports = { handleRpcRequest, handleToolCall, redactSecrets };
