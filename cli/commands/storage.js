const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync, spawn } = require('child_process');
const { isDriveMounted, resolveMountPath, safeUnmount } = require('../utils/format');
const { launchFileManager, loadSettings } = require('../utils/file_manager');

function ensureAutostartFile(enable = true) {
  const autostartDir = path.join(os.homedir(), '.config', 'autostart');
  const desktopFile = path.join(autostartDir, 'ocloud-mounts.desktop');
  if (!enable) {
    try { if (fs.existsSync(desktopFile)) fs.unlinkSync(desktopFile); } catch(e) {}
    return;
  }
  try {
    fs.mkdirSync(autostartDir, { recursive: true });
    const ocloudBin = path.join(__dirname, '..', '..', 'ocloud');
    const content = `[Desktop Entry]
Type=Application
Name=Ocloud Drive Auto-Mount
Comment=Remount user-configured cloud drives on session startup
Exec=${ocloudBin} storage remount-auto
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
`;
    fs.writeFileSync(desktopFile, content, 'utf8');
  } catch(e) {}
}

function getRcloneBin() {
  const candidates = [
    path.join(os.homedir(), '.local', 'bin', 'rclone'),
    '/usr/bin/rclone',
    '/usr/local/bin/rclone'
  ];
  return candidates.find((p) => fs.existsSync(p)) || 'rclone';
}

function getCloudAccounts(registry, vault = null) {
  const rcloneBin = getRcloneBin();
  const env = vault ? vault.getRcloneEnv() : process.env;
  let dump = {};
  try {
    const out = execSync(`${rcloneBin} config dump`, { env, encoding: 'utf8', timeout: 5000, stdio: ['pipe', 'pipe', 'ignore'] });
    dump = JSON.parse(out);
  } catch (e) {
    return [];
  }

  const plugins = registry ? registry.listStoragePlugins() : [];
  const remotes = [];

  const settings = loadSettings();
  const autoMountList = settings.autoMountRemotes || [];

  for (const [name, cfg] of Object.entries(dump)) {
    if (name === 'companion-vm') continue;
    const t = cfg.type || 'generic';

    let matchedPlugin = null;
    for (const p of plugins) {
      if (p.defaultRemoteName === name || p.id === name) {
        matchedPlugin = p;
        break;
      }
      if (p.id === 'hetzner_storage_box' && (name === 'storagebox' || (t === 'sftp' && String(cfg.host || '').includes('storagebox')))) {
        matchedPlugin = p;
        break;
      }
      if (p.id === 'cloudflare_r2' && (name === 'r2' || String(cfg.provider || '').toLowerCase().includes('cloudflare') || String(cfg.endpoint || '').toLowerCase().includes('r2'))) {
        matchedPlugin = p;
        break;
      }
      if (p.id === 'pcloud' && (name.startsWith('pcloud') || t === 'pcloud')) {
        matchedPlugin = p;
        break;
      }
      if (p.id === 'protondrive' && (name.startsWith('proton') || t === 'protondrive')) {
        matchedPlugin = p;
        break;
      }
      if (p.rcloneType === t) {
        matchedPlugin = p;
      }
    }

    const providerName = matchedPlugin ? matchedPlugin.name : name.charAt(0).toUpperCase() + name.slice(1);
    const iconDataUri = matchedPlugin ? matchedPlugin.iconDataUri : '';
    let defaultMount = matchedPlugin && matchedPlugin.defaultMount ? matchedPlugin.defaultMount : `~/Cloud-${name}`;
    if (name === 'storagebox') defaultMount = '~/Cloud';
    if (name === 'r2') defaultMount = '~/R2';
    if (t === 'protondrive' || name === 'protondrive') defaultMount = '~/ProtonDrive';
    const mountPath = resolveMountPath(defaultMount);

    let detail = cfg.user ? `${cfg.user}@${cfg.host || ''}` : (cfg.endpoint || (matchedPlugin ? matchedPlugin.tagline : 'Cloud Account'));
    if (t === 'pcloud') {
      const reg = cfg.hostname === 'eapi.pcloud.com' ? 'EU' : 'US';
      detail = `pCloud ${reg} (${cfg.username || cfg.user || 'OAuth'})`;
    }
    if (t === 'protondrive') {
      detail = `Proton Drive (${cfg.username || cfg.user || 'Encrypted'})`;
    }

    remotes.push({
      name,
      type: t,
      providerId: matchedPlugin ? matchedPlugin.id : name,
      providerName,
      iconDataUri,
      accountDetail: detail,
      mountPath,
      isMounted: isDriveMounted(mountPath),
      autoMount: autoMountList.includes(name)
    });
  }

  return remotes;
}

async function mountAndVerifyRemote(remoteTarget, mountPoint, rcloneBin, env, remoteName, noOpen = false) {
  fs.mkdirSync(mountPoint, { recursive: true });
  if (isDriveMounted(mountPoint)) {
    console.log(`Drive '${remoteName}' is already mounted at ${mountPoint}`);
    return true;
  }

  // Pre-flight check: verify remote is reachable before attempting FUSE mount
  console.log(`Verifying connection to '${remoteName}'...`);
  try {
    execSync(`${rcloneBin} lsd "${remoteTarget}" --contimeout 8s --timeout 8s --retries 1 --low-level-retries 1 --log-level=ERROR`, {
      env,
      encoding: 'utf8',
      timeout: 12000,
      stdio: ['pipe', 'pipe', 'pipe']
    });
  } catch (probeErr) {
    const errOut = (probeErr.stderr ? probeErr.stderr.toString() : '') || (probeErr.stdout ? probeErr.stdout.toString() : '') || probeErr.message || '';
    const lines = errOut.split('\n').map(l => l.trim()).filter(l => l.length > 0 && !l.includes('DEBUG :') && !l.includes('NOTICE :'));
    let lastLine = lines.length > 0 ? lines[lines.length - 1] : 'Remote connection failed or timed out';
    lastLine = lastLine.replace(/^[\d/:\s]+(ERROR|WARNING|NOTICE)\s*:\s*/i, '');
    throw new Error(`Connection verification failed: ${lastLine}`);
  }

  const logFile = `/tmp/rclone-mount-${remoteName.replace(/[^a-zA-Z0-9_-]/g, '_')}.log`;
  try { if (fs.existsSync(logFile)) fs.unlinkSync(logFile); } catch(e) {}

  console.log(`Mounting ${remoteTarget} at ${mountPoint}...`);
  const child = spawn(rcloneBin, [
    'mount', remoteTarget, mountPoint,
    '--vfs-cache-mode', 'full',
    '--daemon',
    `--log-file=${logFile}`,
    '--log-level=NOTICE'
  ], {
    env,
    detached: true,
    stdio: 'ignore'
  });
  child.unref();

  let mounted = false;
  for (let i = 0; i < 30; i++) {
    if (isDriveMounted(mountPoint)) {
      mounted = true;
      break;
    }
    await new Promise(r => setTimeout(r, 500));
  }

  if (!mounted) {
    let errDetails = '';
    try {
      if (fs.existsSync(logFile)) errDetails = fs.readFileSync(logFile, 'utf8').trim();
    } catch(e) {}
    safeUnmount(mountPoint);
    const cleanErr = errDetails ? errDetails.split('\n').pop().replace(/^[\d/:\s]+(ERROR|WARNING|NOTICE)\s*:\s*/i, '') : 'Drive did not appear in system mount table';
    throw new Error(`Mount verification timed out: ${cleanErr}`);
  }

  console.log(`✔ '${remoteName}' mounted at ${mountPoint}`);
  if (!noOpen && isDriveMounted(mountPoint)) {
    launchFileManager(mountPoint);
  }
  return true;
}

async function cmdStorage(subcmd, args, { registry, vault }) {
  const sbPlugin = registry ? registry.getStoragePlugin('hetzner_storage_box') : null;
  const sbDriver = sbPlugin ? sbPlugin.driver : null;
  const rcloneBin = getRcloneBin();
  const env = vault ? vault.getRcloneEnv() : process.env;

  if (subcmd === 'list' || subcmd === 'accounts') {
    const isJson = args.includes('--json') || process.argv.includes('--json');
    const accounts = getCloudAccounts(registry, vault);
    if (isJson) {
      console.log(JSON.stringify(accounts, null, 2));
      return;
    }
    if (accounts.length === 0) {
      console.log('No cloud storage accounts configured in Rclone.');
      return;
    }
    console.log(`${'NAME'.padEnd(16)} ${'PROVIDER'.padEnd(24)} ${'MOUNT POINT'.padEnd(22)} STATUS`);
    console.log('-'.repeat(75));
    for (const a of accounts) {
      const st = a.isMounted ? '\x1b[32mMounted\x1b[0m' : '\x1b[33mStandby\x1b[0m';
      console.log(`${a.name.padEnd(16)} ${a.providerName.padEnd(24)} ${a.mountPath.padEnd(22)} ${st}`);
    }
    return;
  }

  if (subcmd === 'status') {
    const stats = sbDriver ? await sbDriver.getStats() : null;
    const accounts = getCloudAccounts(registry, vault);
    console.log(JSON.stringify({ storage_box: stats, cloud_accounts: accounts }, null, 2));
    return;
  }

  if (subcmd === 'capacities') {
    const capacities = {};
    try {
      const s = fs.statfsSync('/');
      const tot = (s.blocks * s.bsize) / (1024**3);
      const free = (s.bavail * s.bsize) / (1024**3);
      const used = tot - free;
      const pct = tot > 0 ? used / tot : 0;
      capacities['/'] = {
        totalGb: Math.round(tot * 100) / 100,
        freeGb: Math.round(free * 100) / 100,
        usedGb: Math.round(used * 100) / 100,
        percent: Math.round(pct * 100) / 100,
        displayText: `${free.toFixed(2)} GB available of ${tot.toFixed(2)} GB`
      };
    } catch(e) {}
    console.log(JSON.stringify(capacities, null, 2));
    return;
  }

  if (subcmd === 'shares') {
    const accounts = getCloudAccounts(registry, vault);
    const shares = accounts.filter(a => a.type === 'smb').map(a => ({
      name: a.name,
      mountPath: a.mountPath,
      fullMountPath: a.mountPath,
      isMounted: a.isMounted,
      capacityText: a.isMounted ? 'Active SMB Mount' : 'Offline',
      usedPercent: -1
    }));
    console.log(JSON.stringify(shares, null, 2));
    return;
  }

  if (subcmd === 'plugins') {
    const plugins = registry ? registry.listStoragePlugins() : [];
    console.log(JSON.stringify(plugins, null, 2));
    return;
  }

  if (subcmd === 'open') {
    const target = args[0] || 'storagebox';
    let mountPoint;
    if (target.startsWith('/') || target.startsWith('~')) {
      mountPoint = resolveMountPath(target);
    } else {
      const accounts = getCloudAccounts(registry, vault);
      const acc = accounts.find(a => a.name.toLowerCase() === target.toLowerCase() || a.providerId === target.toLowerCase());
      if (acc) {
        mountPoint = acc.mountPath;
      } else if (target === 'companion-vm' || target === 'vm') {
        mountPoint = resolveMountPath('~/Companion-VM');
      } else {
        mountPoint = resolveMountPath('~/Cloud');
      }
    }
    console.log(`Opening file manager at ${mountPoint}...`);
    launchFileManager(mountPoint);
    return;
  }

  if (subcmd === 'mount') {
    let target = args[0] || 'storagebox';
    if (target === 'box' || target === 'hetzner_storage_box') target = 'storagebox';
    const noOpen = args.includes('--no-open');

    const accounts = getCloudAccounts(registry, vault);
    const acc = accounts.find(a => a.name.toLowerCase() === target.toLowerCase() || a.providerId === target.toLowerCase());
    const remoteName = acc ? acc.name : target;
    const mountPoint = acc ? acc.mountPath : resolveMountPath(target === 'storagebox' ? '~/Cloud' : `~/Cloud-${target}`);

    const scoped = vault ? vault.getScopedCredentials(remoteName) : null;
    const bucket = (scoped && scoped.bucket) ? scoped.bucket : '';
    const remoteTarget = bucket ? `${remoteName}:${bucket}` : `${remoteName}:`;

    try {
      await mountAndVerifyRemote(remoteTarget, mountPoint, rcloneBin, env, remoteName, noOpen);
    } catch (e) {
      console.error(`Failed to mount ${remoteName}: ${e.message}`);
      process.exit(1);
    }
    return;
  }

  if (subcmd === 'unmount') {
    let target = args[0] || 'storagebox';
    if (target === 'box' || target === 'hetzner_storage_box') target = 'storagebox';

    const accounts = getCloudAccounts(registry, vault);
    const resolvedTarget = resolveMountPath(target);
    const acc = accounts.find(a => 
      a.name.toLowerCase() === target.toLowerCase() || 
      a.providerId === target.toLowerCase() ||
      resolveMountPath(a.mountPath).toLowerCase() === resolvedTarget.toLowerCase()
    );

    let mountPoint;
    if (acc) {
      mountPoint = acc.mountPath;
    } else if (target.startsWith('/') || target.startsWith('~') || target.includes('/')) {
      mountPoint = resolveMountPath(target);
    } else {
      mountPoint = resolveMountPath(target === 'storagebox' ? '~/Cloud' : `~/Cloud-${target}`);
    }

    if (!isDriveMounted(mountPoint)) {
      console.log(`Drive at ${mountPoint} is not mounted.`);
      return;
    }
    const ok = safeUnmount(mountPoint);
    if (ok) {
      console.log(`✔ Unmounted ${mountPoint}`);
    } else {
      console.error(`Failed to unmount ${mountPoint}`);
      process.exit(1);
    }
    return;
  }

  if (subcmd === 'remount-auto' || subcmd === 'auto-mount') {
    const settings = loadSettings();
    const list = settings.autoMountRemotes || [];
    if (list.length === 0) {
      console.log('No drives configured for startup auto-mount.');
      return;
    }
    console.log(`Auto-mounting ${list.length} drive(s): ${list.join(', ')}...`);
    const accounts = getCloudAccounts(registry, vault);
    for (const remName of list) {
      const acc = accounts.find(a => a.name === remName || a.type === remName);
      if (!acc) continue;
      if (acc.isMounted) {
        console.log(`• '${remName}' is already mounted at ${acc.mountPath}`);
        continue;
      }
      try {
        console.log(`• Auto-mounting '${remName}' at ${acc.mountPath}...`);
        await cmdStorage('mount', [remName, acc.mountPath, '--no-open'], { registry, vault });
      } catch (err) {
        console.error(`• Failed to auto-mount '${remName}': ${err.message}`);
      }
    }
    return;
  }

  if (subcmd === 'toggle-auto-mount') {
    const rem = args[0];
    if (!rem) {
      console.error('Usage: ocloud storage toggle-auto-mount <remoteName>');
      process.exit(1);
    }
    const settings = loadSettings();
    let list = settings.autoMountRemotes || [];
    let enabled = false;
    if (list.includes(rem)) {
      list = list.filter(r => r !== rem);
      enabled = false;
    } else {
      list.push(rem);
      enabled = true;
    }
    settings.autoMountRemotes = list;
    const cfgPath = path.join(os.homedir(), '.config', 'ocloud', 'settings.json');
    fs.mkdirSync(path.dirname(cfgPath), { recursive: true });
    fs.writeFileSync(cfgPath, JSON.stringify(settings, null, 2), 'utf8');

    ensureAutostartFile(list.length > 0);
    console.log(JSON.stringify({ remote: rem, autoMount: enabled, allAutoMounts: list }));
    return;
  }

  if (subcmd === 'remove' || subcmd === 'delete') {
    const target = args[0];
    if (!target) {
      console.error('Usage: ocloud storage remove <name>');
      return;
    }
    try {
      // Unmount first if mounted
      const accounts = getCloudAccounts(registry, vault);
      const acc = accounts.find(a => a.name.toLowerCase() === target.toLowerCase());
      if (acc && acc.isMounted) {
        safeUnmount(acc.mountPath);
      }
      execSync(`${rcloneBin} config delete "${target}"`, { env, stdio: 'inherit' });
      console.log(`✔ Removed remote '${target}'`);
    } catch(e) {
      console.error(`Failed to remove ${target}: ${e.message}`);
    }
    return;
  }

  if (subcmd === 'add-proton') {
    const [name, username, password, twofa, mailboxPass, mountPoint] = args;
    if (!username || !password) {
      console.error('Usage: ocloud storage add-proton <name> <username> <password> [2fa] [mailbox_pass] [mount_point]');
      process.exit(1);
    }
    const remoteName = (name || 'protondrive').toLowerCase().replace(/ /g, '-');
    const expMount = resolveMountPath(mountPoint || '~/ProtonDrive');

    // 1. Save in Vault
    if (vault) {
      vault.setScopedCredentials('protondrive', { username, password, twofa: twofa || '', mailbox_password: mailboxPass || '' });
      vault.ensureRcloneEncrypted(rcloneBin);
    }

    // 2. Create in Rclone
    const cmdArgs = [
      rcloneBin, 'config', 'create', remoteName, 'protondrive',
      'username', username,
      'password', password,
      'app_version', 'external-drive-ocloud@1.0.0-stable',
      '--non-interactive'
    ];
    if (twofa && twofa.trim()) cmdArgs.push('2fa', twofa.trim());
    if (mailboxPass && mailboxPass.trim()) cmdArgs.push('mailbox_password', mailboxPass.trim());

    fs.mkdirSync(expMount, { recursive: true });
    try {
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'pipe' });
      console.log(`✔ Configured Proton Drive remote '${remoteName}' in Rclone.`);
    } catch(e) {
      console.error(`Error configuring Proton Drive: ${e.message}`);
      process.exit(1);
    }

    try {
      await mountAndVerifyRemote(`${remoteName}:`, expMount, rcloneBin, env, remoteName);
      console.log(`✔ Mounted Proton Drive '${remoteName}' to ${expMount}`);
    } catch(e) {
      try { execSync(`${rcloneBin} config delete "${remoteName}"`, { env, stdio: 'ignore' }); } catch(ex) {}
      try { if (fs.readdirSync(expMount).length === 0) fs.rmdirSync(expMount); } catch(ex) {}
      console.error(`Failed to mount Proton Drive '${remoteName}': ${e.message}`);
      process.exit(1);
    }
    return;
  }

  if (subcmd === 'add-s3') {
    const [name, endpoint, bucket, key, secret, mountPoint] = args;
    const remoteName = (name || 's3').toLowerCase().replace(/ /g, '-');
    const expMount = resolveMountPath(mountPoint || `~/Cloud-${remoteName}`);

    if (vault) {
      vault.setScopedCredentials(remoteName, { endpoint, bucket, key, secret });
      vault.ensureRcloneEncrypted(rcloneBin);
    }

    let s3Provider = 'Other';
    if ((endpoint && (endpoint.includes('storj') || endpoint.includes('storjshare.io'))) || remoteName.includes('storj')) {
      s3Provider = 'Storj';
    } else if (endpoint && endpoint.includes('backblaze')) {
      s3Provider = 'Backblaze';
    } else if (endpoint && (endpoint.includes('cloudflare') || endpoint.includes('r2.cloudflarestorage.com'))) {
      s3Provider = 'Cloudflare';
    }

    const cmdArgs = [
      rcloneBin, 'config', 'create', remoteName, 's3',
      'provider', s3Provider,
      'endpoint', endpoint,
      'access_key_id', key,
      'secret_access_key', secret,
      '--non-interactive'
    ];
    fs.mkdirSync(expMount, { recursive: true });
    try {
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'pipe' });
    } catch(e) {
      console.error(`Error configuring S3 remote '${remoteName}': ${e.message}`);
      process.exit(1);
    }

    const remoteTarget = bucket ? `${remoteName}:${bucket}` : `${remoteName}:`;
    try {
      await mountAndVerifyRemote(remoteTarget, expMount, rcloneBin, env, remoteName);
      console.log(`✔ Configured and mounted S3 remote '${remoteName}' to ${expMount}`);
    } catch(e) {
      try { execSync(`${rcloneBin} config delete "${remoteName}"`, { env, stdio: 'ignore' }); } catch(ex) {}
      try { if (fs.readdirSync(expMount).length === 0) fs.rmdirSync(expMount); } catch(ex) {}
      console.error(`Failed to mount S3 remote '${remoteName}': ${e.message}`);
      process.exit(1);
    }
    return;
  }

  if (subcmd === 'add-webdav') {
    const [name, endpoint, user, pass, vendor, mountPoint] = args;
    const remoteName = (name || 'webdav').toLowerCase().replace(/ /g, '-');
    const expMount = resolveMountPath(mountPoint || `~/Cloud-${remoteName}`);

    if (vault) {
      vault.setScopedCredentials(remoteName, { endpoint, user, pass, vendor: vendor || 'other' });
      vault.ensureRcloneEncrypted(rcloneBin);
    }

    const cmdArgs = [
      rcloneBin, 'config', 'create', remoteName, 'webdav',
      'url', endpoint,
      'vendor', vendor || 'other',
      'user', user,
      'pass', pass,
      '--non-interactive'
    ];
    fs.mkdirSync(expMount, { recursive: true });
    try {
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'pipe' });
    } catch(e) {
      console.error(`Error configuring WebDAV remote '${remoteName}': ${e.message}`);
      process.exit(1);
    }

    try {
      await mountAndVerifyRemote(`${remoteName}:`, expMount, rcloneBin, env, remoteName);
      console.log(`✔ Configured and mounted WebDAV remote '${remoteName}' to ${expMount}`);
    } catch(e) {
      try { execSync(`${rcloneBin} config delete "${remoteName}"`, { env, stdio: 'ignore' }); } catch(ex) {}
      try { if (fs.readdirSync(expMount).length === 0) fs.rmdirSync(expMount); } catch(ex) {}
      console.error(`Failed to mount WebDAV remote '${remoteName}': ${e.message}`);
      process.exit(1);
    }
    return;
  }

  if (subcmd === 'add-sftp') {
    const [name, host, user, pass, mountPoint] = args;
    const remoteName = (name || 'sftp').toLowerCase().replace(/ /g, '-');
    const expMount = resolveMountPath(mountPoint || `~/Cloud-${remoteName}`);

    if (vault) {
      vault.setScopedCredentials(remoteName, { host, user, pass });
      vault.ensureRcloneEncrypted(rcloneBin);
    }

    const cmdArgs = [
      rcloneBin, 'config', 'create', remoteName, 'sftp',
      'host', host,
      'user', user,
      'pass', pass,
      '--non-interactive'
    ];
    fs.mkdirSync(expMount, { recursive: true });
    try {
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'pipe' });
    } catch(e) {
      console.error(`Error configuring SFTP remote '${remoteName}': ${e.message}`);
      process.exit(1);
    }

    try {
      await mountAndVerifyRemote(`${remoteName}:`, expMount, rcloneBin, env, remoteName);
      console.log(`✔ Configured and mounted SFTP remote '${remoteName}' to ${expMount}`);
    } catch(e) {
      try { execSync(`${rcloneBin} config delete "${remoteName}"`, { env, stdio: 'ignore' }); } catch(ex) {}
      try { if (fs.readdirSync(expMount).length === 0) fs.rmdirSync(expMount); } catch(ex) {}
      console.error(`Failed to mount SFTP remote '${remoteName}': ${e.message}`);
      process.exit(1);
    }
    return;
  }

  if (subcmd === 'mount-smb' || subcmd === 'add-smb') {
    const [host, share, user, pass, mountPoint] = args;
    const remoteName = `smb-${host.replace(/[^a-zA-Z0-9]/g, '-')}-${share.replace(/[^a-zA-Z0-9]/g, '-')}`;
    const expMount = resolveMountPath(mountPoint || `~/Shares/${share}`);

    if (vault) {
      vault.setScopedCredentials(remoteName, { host, share, user, pass });
      vault.ensureRcloneEncrypted(rcloneBin);
    }

    const cmdArgs = [
      rcloneBin, 'config', 'create', remoteName, 'smb',
      'host', host,
      'user', user || 'guest',
      '--non-interactive'
    ];
    if (pass) cmdArgs.push('pass', pass);

    fs.mkdirSync(expMount, { recursive: true });
    try {
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'pipe' });
    } catch(e) {
      console.error(`Error configuring SMB remote '${remoteName}': ${e.message}`);
      process.exit(1);
    }

    try {
      await mountAndVerifyRemote(`${remoteName}:${share}`, expMount, rcloneBin, env, remoteName);
      console.log(`✔ Mounted SMB share //${host}/${share} to ${expMount}`);
    } catch(e) {
      try { execSync(`${rcloneBin} config delete "${remoteName}"`, { env, stdio: 'ignore' }); } catch(ex) {}
      try { if (fs.readdirSync(expMount).length === 0) fs.rmdirSync(expMount); } catch(ex) {}
      console.error(`Failed to mount SMB share //${host}/${share}: ${e.message}`);
      process.exit(1);
    }
    return;
  }
}

module.exports = { cmdStorage, getCloudAccounts };
