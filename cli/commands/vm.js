const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync, spawn } = require('child_process');
const { formatBytes, isDriveMounted, safeUnmount } = require('../utils/format');
const { launchFileManager } = require('../utils/file_manager');

async function cmdVm(subcmd, args, { registry, vault }) {
  const allServers = await registry.listAllServers();

  if (subcmd === 'list') {
    if (allServers.length === 0) {
      console.log('No servers found in fleet.');
      return;
    }
    console.log(
      `${'ID'.padEnd(14)} ${'NAME'.padEnd(22)} ${'STATUS'.padEnd(12)} ${'TYPE'.padEnd(14)} ${'IPV4'.padEnd(16)} PROVIDER`
    );
    console.log('-'.repeat(85));
    for (const s of allServers) {
      console.log(
        `${String(s.id).padEnd(14)} ${s.name.padEnd(22)} ${s.status.padEnd(12)} ${(s.type || '-').padEnd(14)} ${(s.ipv4 || '-').padEnd(16)} ${s.provider}`
      );
    }
    return;
  }

  if (subcmd === 'create') {
    const name = args[0] || `runner-${Math.floor(Math.random() * 1000)}`;
    const srvType = args[1] || 'cx23';
    let location = args[2];

    const osArg = args.find((a) => a.startsWith('--os='))?.split('=')[1] ||
                  args.find((a) => a.startsWith('--image='))?.split('=')[1] || 'ubuntu-24.04';
    const tsArg = args.find((a) => a.startsWith('--ts='))?.split('=')[1];
    const provArg = args.find((a) => a.startsWith('--provider='))?.split('=')[1] || 'hetzner';

    if (!location || location.startsWith('--')) {
      location = provArg === 'gcp' ? 'us-central1-a' : 'nbg1';
    }

    const tsKey = tsArg !== undefined ? (tsArg === 'auto' || tsArg === '' ? vault.get('tailscale_auth_key', null) : tsArg) : vault.get('tailscale_auth_key', null);
    console.log(`Procuring server '${name}' (${srvType} in ${location}, OS: ${osArg}, Provider: ${provArg})...`);

    let pubKey = '';
    try {
      const edPath = path.join(os.homedir(), '.ssh', 'id_ed25519.pub');
      const rsaPath = path.join(os.homedir(), '.ssh', 'id_rsa.pub');
      if (fs.existsSync(edPath)) pubKey = fs.readFileSync(edPath, 'utf8').trim();
      else if (fs.existsSync(rsaPath)) pubKey = fs.readFileSync(rsaPath, 'utf8').trim();
    } catch (e) {}

    const plugin = registry.getComputePlugin(provArg);
    if (!plugin || !plugin.driver) {
      console.error(`Error: Provider '${provArg}' not found or has no active compute driver.`);
      process.exit(1);
    }

    try {
      const server = await plugin.driver.createServer({
        name,
        type: srvType,
        location,
        image: osArg,
        tailscaleKey: tsKey,
        publicKey: pubKey
      });
      console.log(`Server created! ID: ${server?.id}, Status: ${server?.status}`);
      const assignedIp = server?.ipv4 || server?.ip;
      if (assignedIp && assignedIp !== 'no IP') {
        try {
          const { exec } = require('child_process');
          exec(`ssh-keyscan -H ${assignedIp} >> ~/.ssh/known_hosts 2>/dev/null`, { timeout: 4000 });
        } catch (e) {}
      }
      return;
    } catch (err) {
      const msg = err.message || '';
      if (err.needsApiEnable || msg.includes('Compute Engine API') || msg.includes('compute.googleapis.com') || msg.includes('disabled')) {
        let projectId = '';
        if (typeof plugin.driver.getProjectId === 'function') {
          projectId = plugin.driver.getProjectId();
        }
        console.error(`\n\x1b[1;31m✖ Deployment Failed: Google Cloud Compute Engine API is disabled.\x1b[0m`);
        console.error(`Google Cloud requires the Compute Engine API to be enabled for project '${projectId || 'your-project'}' before virtual machines can be created.`);
        const url = err.enableUrl || (projectId
          ? `https://console.cloud.google.com/apis/library/compute.googleapis.com?project=${projectId}`
          : 'https://console.cloud.google.com/apis/library/compute.googleapis.com');
        console.error(`\n\x1b[1;33m👉 Enable it here:\x1b[0m ${url}\n`);
        process.exit(1);
      }
      console.error(`Error: Failed to create server: ${msg}`);
      process.exit(1);
    }
  }

  const target = args[0];
  let server = null;
  if (target) {
    server = allServers.find((s) => String(s.id) === String(target) || s.name.toLowerCase() === target.toLowerCase());
  } else {
    server = allServers.find((s) => s.status === 'running') || allServers[0];
  }

  if (!server) {
    console.error(`Error: Server '${target || 'default'}' not found.`);
    process.exit(1);
  }

  const sid = server.id;
  const ip = server.ipv4;
  const plugin = registry.getComputePlugin(server.provider);

  if (subcmd === 'start' || subcmd === 'poweron') {
    if (plugin && plugin.driver && typeof plugin.driver.startServer === 'function') {
      console.log(`Powering on ${server.name} (${sid})...`);
      await plugin.driver.startServer(sid);
      console.log('Action initiated.');
    } else {
      console.log('Provider does not support power on via API.');
    }
  } else if (subcmd === 'stop' || subcmd === 'poweroff') {
    if (plugin && plugin.driver && typeof plugin.driver.stopServer === 'function') {
      console.log(`Powering off ${server.name} (${sid})...`);
      await plugin.driver.stopServer(sid);
      console.log('Action initiated.');
    } else {
      console.log(`Attempting graceful shutdown on ${server.name}...`);
      const keyPath = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
      execSync(`ssh -p ${server.port || 22} -i "${keyPath}" -o StrictHostKeyChecking=no ${server.user || 'root'}@${ip} "shutdown -h now"`);
    }
  } else if (subcmd === 'reboot') {
    if (plugin && plugin.driver && typeof plugin.driver.rebootServer === 'function') {
      console.log(`Rebooting ${server.name} (${sid})...`);
      await plugin.driver.rebootServer(sid);
      console.log('Action initiated.');
    } else {
      console.log(`Attempting reboot on ${server.name}...`);
      const keyPath = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
      execSync(`ssh -p ${server.port || 22} -i "${keyPath}" -o StrictHostKeyChecking=no ${server.user || 'root'}@${ip} "reboot"`);
    }
  } else if (subcmd === 'delete') {
    if (plugin && plugin.driver && typeof plugin.driver.deleteServer === 'function') {
      console.log(`Deleting ${server.name} (${sid})...`);
      await plugin.driver.deleteServer(sid);
      console.log(`Server deleted.`);
    } else {
      console.log(`Provider does not support deletion.`);
    }
  } else if (subcmd === 'ssh') {
    const keyPath = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
    const user = server.user || 'root';
    const port = server.port || 22;
    console.log(`Connecting to ${user}@${ip} on port ${port}...`);
    spawn('ssh', ['-p', String(port), '-i', keyPath, '-o', 'StrictHostKeyChecking=no', `${user}@${ip}`], {
      stdio: 'inherit'
    });
  } else if (subcmd === 'inspect') {
    try {
      const data = plugin && plugin.driver && typeof plugin.driver.inspectServer === 'function'
        ? await plugin.driver.inspectServer(server)
        : { status: 'unknown' };

      if (args.includes('--json')) {
        console.log(JSON.stringify(data, null, 2));
        return;
      }

      console.log(`\n\x1b[1;36m⚡ Resource Inspection: ${server.name} (${ip})\x1b[0m`);
      console.log('━'.repeat(55));
      console.log(`  • Host / Node:  ${server.name} [${server.provider.toUpperCase()}]`);
      console.log(`  • Uptime:       ${data.uptime || 'unknown'}`);
      console.log(`  • Load Avg:     ${data.load_1m} (1m), ${data.load_5m} (5m)`);
      console.log(`  • RAM Usage:    ${formatBytes(data.ram_used)} / ${formatBytes(data.ram_total)} (${data.ram_percent}%)`);
      console.log(`  • Disk Usage:   ${formatBytes(data.disk_used)} / ${formatBytes(data.disk_total)} (${data.disk_percent}%)`);
      if (data.top_processes && data.top_processes.length > 0) {
        console.log('\n\x1b[1mTop Processes:\x1b[0m');
        console.log(`  ${'PID'.padEnd(8)} ${'%CPU'.padEnd(8)} ${'%MEM'.padEnd(8)} COMMAND`);
        for (const pr of data.top_processes) {
          console.log(`  ${pr.pid.padEnd(8)} ${pr.cpu.padEnd(8)} ${pr.mem.padEnd(8)} ${pr.cmd}`);
        }
      }
      console.log('━'.repeat(55) + '\n');
    } catch (e) {
      console.error('Inspection failed: ' + e.message);
    }
  } else if (subcmd === 'kill-proc') {
    const targetPid = args[1];
    if (!targetPid) {
      console.error('Usage: ocloud vm kill-proc <server> <pid>');
      process.exit(1);
    }
    const keyPath = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
    const user = server.user || 'root';
    const port = server.port || 22;
    try {
      execSync(`ssh -p ${port} -i ${keyPath} -o StrictHostKeyChecking=no ${user}@${ip} "kill -9 ${targetPid}" 2>&1`);
      console.log(`Killed process ${targetPid} on ${server.name}`);
    } catch (e) {
      console.error(`Failed to kill process ${targetPid}: ${e.message}`);
    }
  } else if (subcmd === 'exec') {
    const remoteCmd = args.slice(1).join(' ');
    if (!remoteCmd) {
      console.error('Usage: ocloud vm exec <server> <command>');
      process.exit(1);
    }
    const keyPath = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
    const user = server.user || 'root';
    const port = server.port || 22;
    try {
      const out = execSync(`ssh -p ${port} -i "${keyPath}" -o StrictHostKeyChecking=no ${user}@${ip} "${remoteCmd}"`, {
        encoding: 'utf8',
        timeout: 15000
      });
      process.stdout.write(out);
    } catch (e) {
      process.stderr.write(e.message);
      process.exit(1);
    }
  } else if (subcmd === 'app') {
    const appCmd = args[1] || 'arcade';
    const keyPath = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
    const user = server.user || 'root';
    const port = server.port || 22;

    const isHome = Boolean(server.isHomeWorkstation);
    const titlePrefix = isHome ? '[🏠 Home Workstation] ' : '[☁ Hetzner Cloud] ';

    const localWaypipe = [
      path.join(os.homedir(), '.local', 'bin', 'waypipe'),
      '/usr/bin/waypipe',
      '/usr/local/bin/waypipe'
    ].find((p) => fs.existsSync(p)) || 'waypipe';

    console.log(`Launching '${appCmd}' on ${server.name} via Waypipe...`);
    console.log(`Prefix: "${titlePrefix}" (triggers desktop window rules)`);

    const remoteExec = `env PATH=/root/.local/bin:/home/${user}/.local/bin:/usr/local/bin:/usr/bin:$PATH PULSE_SERVER=tcp:localhost:4713 QT_QPA_PLATFORM=wayland QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=1500 ${appCmd}`;

    spawn(
      localWaypipe,
      [
        '--title-prefix', titlePrefix,
        '--video=h264',
        '--threads', '4',
        'ssh',
        '-p', String(port),
        '-i', keyPath,
        '-o', 'StrictHostKeyChecking=no',
        '-R', '4713:localhost:4713',
        `${user}@${ip}`,
        remoteExec
      ],
      { stdio: 'inherit' }
    );
  } else if (subcmd === 'mount' || subcmd === 'mount-ephemeral') {
    const vmMountPoint = path.join(os.homedir(), 'Companion-VM');
    if (isDriveMounted(vmMountPoint)) {
      console.log(`VM drive is already mounted at ${vmMountPoint}`);
      return;
    }

    // Safety Consent Warning
    const forceFlag = args.includes('--yes') || args.includes('-y') || subcmd === 'mount-ephemeral';
    if (!forceFlag && process.stdout.isTTY) {
      console.log('\n\x1b[41;1;37m ⚠️  MANDATORY SAFETY CONSENT: EPHEMERAL COMPUTE DRIVE ⚠️ \x1b[0m');
      console.log('\x1b[31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m');
      console.log('\x1b[1;33mThis drive is hosted on the ephemeral local disk of VM ' + server.name + '.\x1b[0m');
      console.log('\x1b[1;33mThis is NOT a persistent Storage Box or backup array!\x1b[0m');
      console.log('\x1b[31mALL files saved here WILL BE PERMANENTLY DESTROYED when the VM is powered off or deleted.\x1b[0m');
      console.log('\x1b[31m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\x1b[0m\n');
      console.log('To acknowledge and mount, run with: ocloud vm mount [server] --yes\n');
      return;
    }

    fs.mkdirSync(vmMountPoint, { recursive: true });
    const keyPath = server.keyPath || path.join(os.homedir(), '.ssh', 'id_ed25519');
    const user = server.user || 'root';
    const rcloneBin = [
      path.join(os.homedir(), '.local', 'bin', 'rclone'),
      '/usr/bin/rclone'
    ].find((p) => fs.existsSync(p)) || 'rclone';
    const env = vault ? vault.getRcloneEnv() : process.env;

    try {
      execSync(`${rcloneBin} config create companion-vm sftp host "${ip}" user "${user}" key_file "${keyPath}" shell_type unix --non-interactive`, { env, stdio: 'ignore' });
      execSync(`${rcloneBin} mount companion-vm:/root "${vmMountPoint}" --vfs-cache-mode full --daemon </dev/null >/dev/null 2>&1 || true`, { env });
      for (let i = 0; i < 16; i++) {
        if (isDriveMounted(vmMountPoint)) break;
        execSync('sleep 0.5');
      }
      console.log(`\x1b[32m✔ Ephemeral VM drive mounted at ${vmMountPoint}\x1b[0m`);
      if (!args.includes('--no-open') && isDriveMounted(vmMountPoint)) {
        launchFileManager(vmMountPoint);
      }
    } catch (e) {
      console.error('Failed to mount VM drive: ' + e.message);
    }
  } else if (subcmd === 'unmount' || subcmd === 'unmount-ephemeral') {
    const vmMountPoint = path.join(os.homedir(), 'Companion-VM');
    if (!isDriveMounted(vmMountPoint)) {
      console.log(`VM drive is not mounted at ${vmMountPoint}`);
      return;
    }
    const ok = safeUnmount(vmMountPoint);
    if (ok) {
      console.log(`Unmounted ${vmMountPoint}`);
    } else {
      console.error(`Failed to unmount VM drive at ${vmMountPoint}`);
    }
  }
}

module.exports = { cmdVm };
