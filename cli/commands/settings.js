const fs = require('fs');
const path = require('path');
const os = require('os');
const { loadSettings } = require('../utils/file_manager');

function getSettingsPath() {
  return path.join(os.homedir(), '.config', 'ocloud', 'settings.json');
}

async function cmdSettings(subcmd, args = []) {
  const cfgPath = getSettingsPath();

  if (subcmd === 'get' || subcmd === 'status' || !subcmd) {
    const current = loadSettings();
    console.log(JSON.stringify(current, null, 2));
    return;
  }

  if (subcmd === 'save' || subcmd === 'set') {
    let newSettings = {};
    const input = args.join(' ').trim();

    try {
      if (input.startsWith('{')) {
        newSettings = JSON.parse(input);
      } else if (args[0] && args[1] !== undefined) {
        const key = args[0];
        let val = args[1];
        if (val === 'true') val = true;
        if (val === 'false') val = false;
        if (!isNaN(val) && val.trim() !== '') val = Number(val);
        newSettings[key] = val;
      }
    } catch (e) {
      console.error(`Invalid settings payload: ${e.message}`);
      process.exit(1);
    }

    const current = loadSettings();
    const merged = Object.assign({}, current, newSettings);

    try {
      fs.mkdirSync(path.dirname(cfgPath), { recursive: true });
      fs.writeFileSync(cfgPath, JSON.stringify(merged, null, 2), 'utf8');
      console.log(`✔ Settings saved to ${cfgPath}`);
    } catch (e) {
      console.error(`Failed to save settings: ${e.message}`);
      process.exit(1);
    }
    return;
  }

  console.log('Usage: ocloud settings [get | save <json> | set <key> <val>]');
}

module.exports = { cmdSettings };
