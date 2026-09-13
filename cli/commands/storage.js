const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync, spawn } = require('child_process');
const { isDriveMounted, resolveMountPath, safeUnmount } = require('../utils/format');
const { launchFileManager } = require('../utils/file_manager');

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
      isMounted: isDriveMounted(mountPath)
    });
  }

  return remotes;
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
    const target = args[0];
    const noOpen = args.includes('--no-open');

    if (!target || target === 'box' || target === 'storagebox' || target === 'hetzner_storage_box') {
      if (sbDriver) {
        const res = await sbDriver.mount(null, !noOpen);
        console.log(`✔ Storage Box mounted at ${res.mount_point}`);
        if (!noOpen) console.log('📂 Opened file manager.');
      } else {
        console.log('Hetzner Storage Box plugin not available.');
      }
      return;
    }

    const accounts = getCloudAccounts(registry, vault);
    const acc = accounts.find(a => a.name.toLowerCase() === target.toLowerCase() || a.providerId === target.toLowerCase());
    const remoteName = acc ? acc.name : target;
    const mountPoint = acc ? acc.mountPath : resolveMountPath(`~/Cloud-${target}`);

    fs.mkdirSync(mountPoint, { recursive: true });
    if (isDriveMounted(mountPoint)) {
      console.log(`Drive '${remoteName}' is already mounted at ${mountPoint}`);
      return;
    }

    console.log(`Mounting ${remoteName}: at ${mountPoint}...`);
    try {
      execSync(`${rcloneBin} mount "${remoteName}:" "${mountPoint}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1`, { env });
      for (let i = 0; i < 16; i++) {
        if (isDriveMounted(mountPoint)) break;
        execSync('sleep 0.5');
      }
      console.log(`✔ '${remoteName}' mounted at ${mountPoint}`);
      if (!noOpen && isDriveMounted(mountPoint)) {
        launchFileManager(mountPoint);
      }
    } catch (e) {
      console.error(`Failed to mount ${remoteName}: ${e.message}`);
    }
    return;
  }

  if (subcmd === 'unmount') {
    const target = args[0];
    if (!target || target === 'box' || target === 'storagebox' || target === 'hetzner_storage_box') {
      if (sbDriver) {
        await sbDriver.unmount();
        console.log('✔ Storage Box unmounted.');
      }
      return;
    }

    const accounts = getCloudAccounts(registry, vault);
    const acc = accounts.find(a => a.name.toLowerCase() === target.toLowerCase() || a.providerId === target.toLowerCase());
    const mountPoint = acc ? acc.mountPath : resolveMountPath(`~/Cloud-${target}`);

    if (!isDriveMounted(mountPoint)) {
      console.log(`Drive at ${mountPoint} is not mounted.`);
      return;
    }
    const ok = safeUnmount(mountPoint);
    if (ok) {
      console.log(`✔ Unmounted ${mountPoint}`);
    } else {
      console.error(`Failed to unmount ${mountPoint}`);
    }
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
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'inherit' });
      console.log(`✔ Configured Proton Drive remote '${remoteName}' in Rclone.`);
      // Mount
      execSync(`${rcloneBin} mount "${remoteName}:" "${expMount}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1`, { env });
      console.log(`✔ Mounted '${remoteName}' to ${expMount}`);
    } catch(e) {
      console.error(`Error adding Proton Drive: ${e.message}`);
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

    const cmdArgs = [
      rcloneBin, 'config', 'create', remoteName, 's3',
      'provider', 'Other',
      'endpoint', endpoint,
      'access_key_id', key,
      'secret_access_key', secret,
      '--non-interactive'
    ];
    fs.mkdirSync(expMount, { recursive: true });
    try {
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'inherit' });
      execSync(`${rcloneBin} mount "${remoteName}:${bucket || ''}" "${expMount}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1`, { env });
      console.log(`✔ Configured and mounted S3 remote '${remoteName}' to ${expMount}`);
    } catch(e) {
      console.error(`Error adding S3 storage: ${e.message}`);
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
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'inherit' });
      execSync(`${rcloneBin} mount "${remoteName}:" "${expMount}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1`, { env });
      console.log(`✔ Configured and mounted WebDAV remote '${remoteName}' to ${expMount}`);
    } catch(e) {
      console.error(`Error adding WebDAV storage: ${e.message}`);
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
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'inherit' });
      execSync(`${rcloneBin} mount "${remoteName}:" "${expMount}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1`, { env });
      console.log(`✔ Configured and mounted SFTP remote '${remoteName}' to ${expMount}`);
    } catch(e) {
      console.error(`Error adding SFTP storage: ${e.message}`);
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
      execSync(cmdArgs.map(a => `"${a}"`).join(' '), { env, stdio: 'inherit' });
      execSync(`${rcloneBin} mount "${remoteName}:${share}" "${expMount}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1`, { env });
      console.log(`✔ Mounted SMB share //${host}/${share} to ${expMount}`);
    } catch(e) {
      console.error(`Error mounting SMB share: ${e.message}`);
      process.exit(1);
    }
    return;
  }
}

module.exports = { cmdStorage, getCloudAccounts };
