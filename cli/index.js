const { Vault } = require('../security/vault');
const registry = require('../providers/registry');
const { BackupEngine } = require('../backup/engine');

const { cmdStatus } = require('./commands/status');
const { cmdVm } = require('./commands/vm');
const { cmdNode } = require('./commands/node');
const { cmdStorage } = require('./commands/storage');
const { cmdBackup } = require('./commands/backup');
const { cmdVault } = require('./commands/vault');
const { cmdProviders } = require('./commands/providers');
const { cmdCatalog } = require('./commands/catalog');
const { cmdApp } = require('./commands/app');
const { cmdGui } = require('./commands/gui');
const { cmdDocs } = require('./commands/docs');
const { cmdSettings } = require('./commands/settings');
const { cmdBridge } = require('./commands/bridge');
const { cmdWorkload } = require('./commands/workload');

async function main() {
  // Initialize Core Subsystems
  const vault = new Vault();
  registry.init(vault);
  const backupEngine = new BackupEngine(vault);

  const context = { vault, registry, backupEngine };

  const argv = process.argv.slice(2);
  const command = argv[0] || 'status';
  const subcmd = argv[1];
  const rest = argv.slice(2);

  try {
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
    } else if (command === 'workload' || command === 'docker' || command === 'container') {
      await cmdWorkload(subcmd || 'templates', rest, context);
    } else if (command === 'storage') {
      await cmdStorage(subcmd || 'status', rest, context);
    } else if (command === 'backup') {
      await cmdBackup(subcmd || 'status', rest, context);
    } else if (command === 'vault') {
      cmdVault(subcmd || 'status', rest, context);
    } else if (command === 'mcp') {
      require('../mcp/server');
    } else if (command === 'docs' || command === 'doc') {
      cmdDocs(subcmd);
    } else if (command === 'gui' || command === 'window') {
      cmdGui(subcmd, rest, context);
    } else if (command === 'app') {
      if (subcmd === 'gui' || subcmd === 'open') {
        cmdGui(subcmd, rest, context);
      } else {
        await cmdApp(subcmd || 'list', rest, context);
      }
    } else if (command === 'bridge' || command === 'daemon') {
      cmdBridge();
    } else if (command === 'settings' || command === 'config' || command === 'preference') {
      await cmdSettings(subcmd, rest);
    } else {
      console.log('Usage: ocloud [status | providers | catalog | vm | node | workload | storage | backup | vault | app | settings | mcp | docs | gui | bridge]');
    }
  } catch (err) {
    console.error(`\x1b[31mError:\x1b[0m ${err.message}`);
    process.exit(1);
  }
}

module.exports = { main };

if (require.main === module) {
  main();
}
