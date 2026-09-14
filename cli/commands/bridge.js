const readline = require('readline');
const { Vault } = require('../../security/vault');
const registry = require('../../providers/registry');
const { BackupEngine } = require('../../backup/engine');

const { cmdStatus } = require('./status');
const { cmdVm } = require('./vm');
const { cmdNode } = require('./node');
const { cmdStorage } = require('./storage');
const { cmdBackup } = require('./backup');
const { cmdVault } = require('./vault');
const { cmdProviders } = require('./providers');
const { cmdCatalog } = require('./catalog');
const { cmdApp } = require('./app');
const { cmdDocs } = require('./docs');
const { cmdSettings } = require('./settings');

async function runCommandWithContext(argv, context) {
  const command = argv[0] || 'status';
  const subcmd = argv[1];
  const rest = argv.slice(2);

  if (command === 'status' || command.startsWith('-')) {
    await cmdStatus(argv, context);
  } else if (command === 'providers' || command === 'plugins' || command === 'plugin') {
    await cmdProviders(subcmd, rest, context);
  } else if (command === 'catalog') {
    await cmdCatalog(subcmd || 'hetzner', rest, context);
  } else if (command === 'vm' || command === 'server') {
    await cmdVm(subcmd || 'list', rest, context);
  } else if (command === 'node') {
    await cmdNode(subcmd || 'list', rest, context);
  } else if (command === 'storage') {
    await cmdStorage(subcmd || 'status', rest, context);
  } else if (command === 'backup') {
    await cmdBackup(subcmd || 'status', rest, context);
  } else if (command === 'vault') {
    cmdVault(subcmd || 'status', rest, context);
  } else if (command === 'docs' || command === 'doc') {
    cmdDocs(subcmd);
  } else if (command === 'app') {
    await cmdApp(subcmd || 'list', rest, context);
  } else if (command === 'settings' || command === 'config' || command === 'preference') {
    await cmdSettings(subcmd, rest);
  } else {
    throw new Error(`Unknown bridge command: ${command}`);
  }
}

class BridgeServer {
  constructor() {
    this.vault = new Vault();
    registry.init(this.vault);
    this.backupEngine = new BackupEngine(this.vault);
    this.context = {
      vault: this.vault,
      registry,
      backupEngine: this.backupEngine
    };
    this.queue = Promise.resolve();
  }

  start() {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      terminal: false
    });

    // Notify ready to parent GUI
    process.stdout.write(JSON.stringify({ type: 'ready', pid: process.pid }) + '\n');

    rl.on('line', (line) => {
      const trimmed = line.trim();
      if (!trimmed) return;

      try {
        const req = JSON.parse(trimmed);
        if (req.id && Array.isArray(req.args)) {
          this.enqueue(req.id, req.args);
        }
      } catch (e) {
        process.stderr.write(`[bridge] Invalid JSON request: ${trimmed}\n`);
      }
    });

    rl.on('close', () => {
      process.exit(0);
    });

    process.on('SIGTERM', () => process.exit(0));
    process.on('SIGINT', () => process.exit(0));
  }

  enqueue(id, args) {
    this.queue = this.queue.then(() => this.execute(id, args));
  }

  async execute(id, args) {
    let captured = '';
    const origLog = console.log;
    const origWarn = console.warn;
    const origError = console.error;

    console.log = (...a) => {
      captured += a.map(x => (typeof x === 'object' ? JSON.stringify(x) : String(x))).join(' ') + '\n';
    };
    console.warn = (...a) => {
      captured += a.map(x => (typeof x === 'object' ? JSON.stringify(x) : String(x))).join(' ') + '\n';
    };
    console.error = (...a) => {
      captured += a.map(x => (typeof x === 'object' ? JSON.stringify(x) : String(x))).join(' ') + '\n';
    };

    let ok = true;
    try {
      await runCommandWithContext(args, this.context);
    } catch (err) {
      ok = false;
      captured += (err.message || String(err)) + '\n';
    } finally {
      console.log = origLog;
      console.warn = origWarn;
      console.error = origError;
    }

    const response = {
      id,
      ok,
      output: captured.trim()
    };

    process.stdout.write(JSON.stringify(response) + '\n');
  }
}

function cmdBridge() {
  const server = new BridgeServer();
  server.start();
}

module.exports = { cmdBridge, BridgeServer };
