const path = require('path');
const os = require('os');
const { formatBytes, isDriveMounted } = require('../utils/format');

async function cmdStatus(args, { registry, backupEngine, vault }) {
  const isMock = args.includes('--mock');
  const isJson = args.includes('--json');

  let hetznerServers = [];
  let customServers = [];
  let storageStats = null;
  let customStorageTargets = [];
  let backupHistory = [];

  if (isMock) {
    hetznerServers = [
      {
        id: 1048576,
        name: 'omarchy-companion',
        status: 'running',
        type: 'cx23',
        ipv4: '116.203.42.18',
        location: 'nbg1',
        provider: 'hetzner',
        isHomeWorkstation: false,
        tags: ['cloud', 'hetzner']
      }
    ];
    customServers = [
      {
        id: 'custom-home-rig',
        name: 'Home Studio Rig',
        status: 'running',
        type: 'workstation',
        ipv4: '100.90.80.70',
        location: 'Home/Tailscale',
        provider: 'custom',
        isHomeWorkstation: true,
        tags: ['home', 'workstation', 'gpu-rtx4090']
      }
    ];
    storageStats = {
      configured: true,
      username: 'u123456',
      host: 'u123456.your-storagebox.de',
      mounted: true,
      mount_point: path.join(os.homedir(), 'Cloud'),
      total_bytes: 1073741824000,
      used_bytes: 450971566080,
      used_percent: 42.0,
      last_backup: { timestamp: new Date().toISOString(), status: 'success' }
    };
  } else {
    const sbPlugin = registry.getStoragePlugin('hetzner_storage_box');
    const [allSrvRes, sbRes, backupRes] = await Promise.allSettled([
      registry.listAllServers(),
      sbPlugin && sbPlugin.driver ? sbPlugin.driver.getStats({ forceRefresh: args.includes('--refresh') }) : Promise.resolve(null),
      Promise.resolve(backupEngine.getHistory())
    ]);
    if (allSrvRes.status === 'fulfilled') hetznerServers = allSrvRes.value || [];
    if (sbRes.status === 'fulfilled') storageStats = sbRes.value;
    if (backupRes.status === 'fulfilled') backupHistory = backupRes.value || [];
  }

  const vmMountPoint = path.join(os.homedir(), 'Companion-VM');
  const isVmMounted = isDriveMounted(vmMountPoint);
  const r2MountPoint = path.join(os.homedir(), 'R2');
  const isR2Mounted = isDriveMounted(r2MountPoint);

  // Probe local Tailscale daemon for any connected mesh nodes
  const tailscalePeers = {};
  try {
    const { execSync } = require('child_process');
    const tsRaw = execSync('tailscale status --json', { timeout: 1500, encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
    const tsData = JSON.parse(tsRaw);
    if (tsData && tsData.Peer) {
      for (const p of Object.values(tsData.Peer)) {
        const ipv4 = (p.TailscaleIPs || []).find((ip) => ip.includes('.'));
        if (ipv4) {
          if (p.HostName) tailscalePeers[p.HostName.toLowerCase()] = ipv4;
          if (p.DNSName) {
            const shortName = p.DNSName.split('.')[0].toLowerCase();
            tailscalePeers[shortName] = ipv4;
          }
        }
      }
    }
  } catch (e) {}

  const allServers = hetznerServers.map((s) => ({
    ...s,
    tailscale_ip: tailscalePeers[s.name?.toLowerCase()] || s.tailscale_ip || null,
    is_drive_mounted: isVmMounted && s.status === 'running' && !s.isHomeWorkstation
  }));
  const activeCount = allServers.filter((s) => s.status === 'running').length;

  const { getCloudAccounts } = require('./storage');
  const cloudAccounts = getCloudAccounts(registry, vault);

  const payload = {
    servers: allServers,
    active_count: activeCount,
    total_count: allServers.length,
    storage: {
      storage_box: storageStats,
      custom_storage: customStorageTargets,
      cloud_accounts: cloudAccounts,
      companion_vm: {
        mounted: isVmMounted,
        mount_point: vmMountPoint
      },
      r2_storage: {
        mounted: isR2Mounted,
        mount_point: r2MountPoint,
        bucket: 'ocloud'
      }
    },
    backups: {
      schedule: backupEngine.getSchedule(),
      recent: backupHistory.slice(0, 3)
    }
  };

  if (isJson) {
    console.log(JSON.stringify(payload, null, 2));
    return;
  }

  console.log('\n\x1b[1;36m☁  Ocloud - Cloud Storage & Compute\x1b[0m');
  console.log('━'.repeat(60));

  // Storage Section
  console.log('\x1b[1mStorage Overview:\x1b[0m');
  if (storageStats && storageStats.configured) {
    const used = formatBytes(storageStats.used_bytes);
    const total = formatBytes(storageStats.total_bytes);
    const mnt = storageStats.mounted
      ? '\x1b[32mMounted\x1b[0m'
      : '\x1b[33mNot Mounted\x1b[0m';
    console.log(`  • Storage Box:   ${used} / ${total} (${storageStats.used_percent}%)`);
    console.log(`    Status:        ${mnt} at ${storageStats.mount_point}`);
  } else {
    console.log('  • Storage Box:   \x1b[33mNot configured\x1b[0m in Vault');
  }

  if (customStorageTargets.length > 0) {
    for (const cs of customStorageTargets) {
      const mnt = cs.mounted ? '\x1b[32mMounted\x1b[0m' : '\x1b[33mUnmounted\x1b[0m';
      console.log(`  • Custom SFTP:   ${cs.name} (${cs.host}) - ${mnt} at ${cs.mountPoint}`);
    }
  }

  // Check Ephemeral VM Mount
  const vmMount = path.join(os.homedir(), 'Companion-VM');
  if (isDriveMounted(vmMount)) {
    console.log(`  • \x1b[33m[EPHEMERAL]\x1b[0m VM Drive: \x1b[32mMounted\x1b[0m at ${vmMount} (Wiped on VM shutdown!)`);
  }

  // Check Cloudflare R2 Mount
  const r2Mount = path.join(os.homedir(), 'R2');
  if (isDriveMounted(r2Mount)) {
    console.log(`  • Cloudflare R2: \x1b[32mMounted\x1b[0m at ${r2Mount} (Bucket: ocloud)`);
  }

  // Compute Fleet Section
  console.log('\n\x1b[1mCompute Fleet:\x1b[0m');
  if (allServers.length > 0) {
    console.log(`  • Active: ${activeCount}/${allServers.length} nodes online\n`);
    for (const s of allServers) {
      const statusBadge =
        s.status === 'running'
          ? '\x1b[32m● ONLINE\x1b[0m'
          : `\x1b[31m○ ${s.status.toUpperCase()}\x1b[0m`;
      const kind = s.isHomeWorkstation
        ? '\x1b[32m[🏠 HOME WORKSTATION]\x1b[0m'
        : s.provider === 'custom'
        ? '\x1b[35m[⚡ BARE METAL]\x1b[0m'
        : '\x1b[36m[☁ HETZNER CLOUD]\x1b[0m';
      console.log(`  ${kind} ${s.name} (${s.type}, ${s.location})`);
      console.log(`    Status: ${statusBadge} | IPv4: ${s.ipv4} | ID: ${s.id}`);
    }
  } else {
    console.log('  • No compute nodes found in fleet.');
  }

  // Backups
  console.log('\n\x1b[1mAutomated Backups:\x1b[0m');
  const sched = backupEngine.getSchedule();
  console.log(`  • Schedule: ${sched.enabled ? `\x1b[32mActive\x1b[0m (${sched.interval} at ${sched.time})` : '\x1b[33mDisabled\x1b[0m'}`);
  if (backupHistory.length > 0) {
    console.log(`  • Last snapshot: ${backupHistory[0].timestamp} (${backupHistory[0].status})`);
  }
  console.log('━'.repeat(60) + '\n');
}

module.exports = { cmdStatus };
