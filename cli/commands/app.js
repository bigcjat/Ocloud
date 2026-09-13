const { spawn, execSync } = require('child_process');
const path = require('path');
const os = require('os');

function cmdApp(subcmd, rest) {
  if (subcmd === 'launch') {
    const server = rest[0];
    const cmd = rest[1];
    const isGui = rest.includes('--gui') || !rest.includes('--cli');
    if (!server || !cmd) {
      console.error('Usage: ocloud app launch <server_ip> <command> [--gui|--cli]');
      process.exit(1);
    }
    const keyPath = path.join(os.homedir(), '.ssh', 'id_ed25519');
    if (isGui) {
      console.log(`\x1b[36m🚀 Streaming "${cmd}" from ${server} via Waypipe into desktop...\x1b[0m`);
      spawn('waypipe', ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', '-i', keyPath, `root@${server}`, cmd], { stdio: 'inherit', detached: true }).unref();
    } else {
      console.log(`\x1b[36mExecuting "${cmd}" on ${server}...\x1b[0m`);
      execSync(`ssh -o BatchMode=yes -o ConnectTimeout=5 -i "${keyPath}" root@${server} "${cmd}"`, { stdio: 'inherit' });
    }
  } else {
    console.log('Usage: ocloud app launch <server_ip> <command> [--gui|--cli]');
  }
}

module.exports = { cmdApp };
