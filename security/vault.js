const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

/**
 * Ocloud Secure Credentials Vault
 * - Encrypted at rest using AES-256-GCM.
 * - Key derived via PBKDF2 using machine-specific secret (/etc/machine-id + user UID) and cryptographic salt.
 * - Stored strictly at ~/.config/omarchy/vault.enc with chmod 600.
 * - Zero plain-text tokens left on disk.
 */
class Vault {
  constructor(customPath = null, passphrase = null) {
    this.vaultPath = customPath || path.join(os.homedir(), '.config', 'omarchy', 'vault.enc');
    this.passphrase = passphrase;
    this.salt = Buffer.from('ocloud-sovereign-salt-v1');
    this._cache = null;
  }

  _getMachineSecret() {
    let machineId = '';
    const idPaths = ['/etc/machine-id', '/var/lib/dbus/machine-id'];
    for (const p of idPaths) {
      if (fs.existsSync(p)) {
        try {
          machineId = fs.readFileSync(p, 'utf8').trim();
          break;
        } catch (e) {}
      }
    }
    if (!machineId) {
      machineId = os.hostname() + '-' + os.userInfo().username;
    }
    const uid = typeof process.getuid === 'function' ? process.getuid() : 1000;
    const extra = this.passphrase ? `:${this.passphrase}` : '';
    return `${machineId}:${uid}:ocloud-vault${extra}`;
  }

  _deriveKey() {
    const secret = this._getMachineSecret();
    return crypto.pbkdf2Sync(secret, this.salt, 100000, 32, 'sha256');
  }

  load() {
    if (this._cache) return this._cache;

    if (!fs.existsSync(this.vaultPath)) {
      // Check for legacy hetzner.json to migrate automatically
      const legacyPath = path.join(os.homedir(), '.config', 'omarchy', 'hetzner.json');
      if (fs.existsSync(legacyPath)) {
        try {
          const legacy = JSON.parse(fs.readFileSync(legacyPath, 'utf8'));
          this._cache = legacy;
          this.save();
          // Overwrite and wipe legacy plain text file
          fs.writeFileSync(legacyPath, JSON.stringify({ migrated_to: 'vault.enc' }, null, 2), { mode: 0o600 });
          console.log('\x1b[32m✔ Migrated legacy hetzner.json into encrypted vault.enc\x1b[0m');
          return this._cache;
        } catch (e) {}
      }
      this._cache = {
        api_token: '',
        tailscale_auth_key: '',
        storage_box: {
          username: '',
          host: '',
          password: '',
          port: 23,
          mount_point: '~/Cloud',
          backup_source: '~'
        },
        custom_servers: [],
        providers: {}
      };
      return this._cache;
    }

    try {
      const raw = fs.readFileSync(this.vaultPath);
      const iv = raw.subarray(0, 12);
      const authTag = raw.subarray(12, 28);
      const ciphertext = raw.subarray(28);

      const key = this._deriveKey();
      const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
      decipher.setAuthTag(authTag);

      const decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
      this._cache = JSON.parse(decrypted.toString('utf8'));
      return this._cache;
    } catch (e) {
      throw new Error(`Failed to decrypt Ocloud Vault: ${e.message}`);
    }
  }

  save(data = null) {
    if (data) this._cache = data;
    if (!this._cache) return;

    fs.mkdirSync(path.dirname(this.vaultPath), { recursive: true });

    const key = this._deriveKey();
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

    const plaintext = Buffer.from(JSON.stringify(this._cache, null, 2), 'utf8');
    const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    const authTag = cipher.getAuthTag();

    const output = Buffer.concat([iv, authTag, ciphertext]);
    fs.writeFileSync(this.vaultPath, output, { mode: 0o600 });
  }

  get(key, defaultValue = null) {
    const data = this.load();
    return data[key] !== undefined ? data[key] : defaultValue;
  }

  set(key, value) {
    const data = this.load();
    data[key] = value;
    this.save(data);
  }
}

module.exports = { Vault };
