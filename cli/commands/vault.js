const fs = require('fs');
const path = require('path');

function cmdVault(subcmd, args, { vault }) {
  if (subcmd === 'scan-keys' || subcmd === 'find-keys') {
    const homedir = process.env.HOME || '/home/bigcjat';
    const searchDirs = [
      path.join(homedir, 'Downloads'),
      homedir,
      path.join(homedir, 'Desktop')
    ];
    const found = [];
    for (const dir of searchDirs) {
      if (!fs.existsSync(dir)) continue;
      try {
        const files = fs.readdirSync(dir);
        for (const f of files) {
          if (!f.endsWith('.json')) continue;
          const fullPath = path.join(dir, f);
          try {
            const stat = fs.statSync(fullPath);
            if (stat.isFile() && stat.size > 200 && stat.size < 50000) {
              const head = fs.readFileSync(fullPath, 'utf8');
              if (head.includes('"type": "service_account"') || head.includes('"private_key"')) {
                let projectId = '';
                try {
                  const parsed = JSON.parse(head);
                  projectId = parsed.project_id || '';
                } catch(e) {}
                found.push({ path: fullPath, name: f, projectId });
              }
            }
          } catch(e) {}
        }
      } catch(e) {}
    }
    console.log(JSON.stringify(found));
    return;
  }

  if (subcmd === 'status') {
    const exists = fs.existsSync(vault.vaultPath);
    console.log(`\n\x1b[1;36m🔐 Ocloud Credentials Vault\x1b[0m`);
    console.log(`  • Path:        ${vault.vaultPath}`);
    console.log(`  • Encrypted:   ${exists ? '\x1b[32mYES (AES-256-GCM)\x1b[0m' : '\x1b[33mNO (Not initialized)\x1b[0m'}`);
    console.log(`  • Permissions: chmod 600\n`);
    return;
  }

  if (subcmd === 'clear' || subcmd === 'delete') {
    const key = args[0];
    if (key) {
      vault.set(key, '');
      console.log(`\x1b[32m✔ Cleared vault key: ${key}\x1b[0m`);
    }
    return;
  }

  if (subcmd === 'set-file') {
    const key = args[0];
    const filePath = args[1];
    if (!key || !filePath || !fs.existsSync(filePath)) {
      console.log('Usage: ocloud vault set-file <key> <filePath>');
      return;
    }
    try {
      const content = fs.readFileSync(filePath, 'utf8').trim();
      vault.set(key, content);
      try {
        const parsed = JSON.parse(content);
        if (parsed.project_id) {
          vault.set('gcp_project_id', parsed.project_id);
        }
      } catch(pe) {}
      console.log(`\x1b[32m✔ Imported vault key from file: ${key}\x1b[0m`);
    } catch(err) {
      console.error(`Failed to read file ${filePath}:`, err.message);
    }
    return;
  }

  if (subcmd === 'set') {
    const key = args[0];
    const val = args.slice(1).join(' ');
    if (!key || val === undefined || val === '') {
      console.log('Usage: ocloud vault set <key> <value>');
      return;
    }
    vault.set(key, val);
    console.log(`\x1b[32m✔ Updated vault key: ${key}\x1b[0m`);
    return;
  }

  if (subcmd === 'get') {
    const key = args[0];
    if (!key) {
      console.log('Usage: ocloud vault get <key>');
      return;
    }
    console.log(vault.get(key, ''));
  }
}

module.exports = { cmdVault };
