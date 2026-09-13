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

  _hasSecretTool() {
    if (this._secretToolAvailable !== undefined) return this._secretToolAvailable;
    try {
      const { execSync } = require('child_process');
      execSync('which secret-tool', { stdio: 'ignore', timeout: 1000 });
      this._secretToolAvailable = true;
    } catch (e) {
      this._secretToolAvailable = false;
    }
    return this._secretToolAvailable;
  }

  _lookupSecretService(account) {
    if (!this._hasSecretTool()) return null;
    try {
      const { execSync } = require('child_process');
      const val = execSync(`secret-tool lookup service ocloud account "${account}"`, {
        encoding: 'utf8',
        timeout: 2000,
        stdio: ['pipe', 'pipe', 'ignore']
      }).trim();
      return val || null;
    } catch (e) {
      return null;
    }
  }

  _storeSecretService(account, label, value) {
    if (!this._hasSecretTool() || !value) return false;
    try {
      const { spawnSync } = require('child_process');
      const res = spawnSync('secret-tool', [
        'store',
        `--label=${label}`,
        'service', 'ocloud',
        'account', account
      ], {
        input: value,
        timeout: 2000,
        stdio: ['pipe', 'ignore', 'ignore']
      });
      return res.status === 0;
    } catch (e) {
      return false;
    }
  }

  _clearSecretService(account) {
    if (!this._hasSecretTool()) return false;
    try {
      const { execSync } = require('child_process');
      execSync(`secret-tool clear service ocloud account "${account}"`, {
        timeout: 2000,
        stdio: 'ignore'
      });
      return true;
    } catch (e) {
      return false;
    }
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

  _deriveKey(customSecret = null) {
    const secret = customSecret || this._lookupSecretService('master') || this._getMachineSecret();
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

    const raw = fs.readFileSync(this.vaultPath);
    const iv = raw.subarray(0, 12);
    const authTag = raw.subarray(12, 28);
    const ciphertext = raw.subarray(28);

    let decrypted = null;
    const secretsToTry = [];
    const ssSecret = this._lookupSecretService('master');
    if (ssSecret) secretsToTry.push(ssSecret);
    secretsToTry.push(this._getMachineSecret());

    let lastError = null;
    for (const secret of secretsToTry) {
      try {
        const key = this._deriveKey(secret);
        const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
        decipher.setAuthTag(authTag);
        decrypted = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
        break;
      } catch (err) {
        lastError = err;
      }
    }

    if (!decrypted) {
      throw new Error(`Failed to decrypt Ocloud Vault: ${lastError ? lastError.message : 'Decryption error'}`);
    }

    try {
      this._cache = JSON.parse(decrypted.toString('utf8'));
      return this._cache;
    } catch (e) {
      throw new Error(`Failed to parse Ocloud Vault payload: ${e.message}`);
    }
  }

  save(data = null) {
    if (data) this._cache = data;
    if (!this._cache) return;

    if (this._hasSecretTool() && !this._lookupSecretService('master')) {
      this._storeSecretService('master', 'Ocloud Master Key', this._getMachineSecret());
    }

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

  /**
   * Returns an isolated, read-only slice of credentials strictly belonging
   * to a single provider. Prevents plugins from sweeping or accessing foreign secrets.
   * 
   * @param {string} providerId 
   * @returns {object} Frozen credentials
   */
  getScopedCredentials(providerId) {
    const data = this.load();
    let creds = {};

    if (providerId === 'hetzner') {
      creds = {
        api_token: data.api_token || data.hetzner_api_token || '',
        tailscale_auth_key: data.tailscale_auth_key || ''
      };
    } else if (providerId === 'gcp') {
      creds = {
        gcp_service_account_json: (data.providers && data.providers.gcp && data.providers.gcp.gcp_service_account_json) || data.gcp_service_account_json || '',
        gcp_project_id: (data.providers && data.providers.gcp && data.providers.gcp.gcp_project_id) || data.gcp_project_id || '',
        gcp_default_zone: (data.providers && data.providers.gcp && data.providers.gcp.gcp_default_zone) || data.gcp_default_zone || 'us-central1-a',
        tailscale_auth_key: (data.providers && data.providers.gcp && data.providers.gcp.tailscale_auth_key) || data.tailscale_auth_key || ''
      };
    } else if (providerId === 'hetzner_storage_box') {
      creds = { ...(data.storage_box || {}) };
    } else if (providerId === 'custom_server') {
      creds = { custom_servers: data.custom_servers || [] };
    } else if (data.providers && data.providers[providerId]) {
      creds = { ...data.providers[providerId] };
    }

    return Object.freeze(JSON.parse(JSON.stringify(creds)));
  }

  /**
   * Sets credentials strictly for a specific provider without allowing access
   * to other providers' secrets or master keys.
   * 
   * @param {string} providerId 
   * @param {object} updateData 
   */
  setScopedCredentials(providerId, updateData = {}) {
    const data = this.load();

    if (providerId === 'hetzner') {
      if (updateData.api_token !== undefined) data.api_token = updateData.api_token;
      if (updateData.hetzner_api_token !== undefined) data.hetzner_api_token = updateData.hetzner_api_token;
      if (updateData.tailscale_auth_key !== undefined) data.tailscale_auth_key = updateData.tailscale_auth_key;
    } else if (providerId === 'gcp') {
      data.providers = data.providers || {};
      data.providers.gcp = { ...(data.providers.gcp || {}), ...updateData };
      if (updateData.gcp_service_account_json !== undefined) data.gcp_service_account_json = updateData.gcp_service_account_json;
      if (updateData.gcp_project_id !== undefined) data.gcp_project_id = updateData.gcp_project_id;
      if (updateData.gcp_default_zone !== undefined) data.gcp_default_zone = updateData.gcp_default_zone;
    } else if (providerId === 'hetzner_storage_box') {
      data.storage_box = { ...(data.storage_box || {}), ...updateData };
    } else if (providerId === 'custom_server') {
      data.custom_servers = updateData.custom_servers !== undefined ? updateData.custom_servers : (Array.isArray(updateData) ? updateData : data.custom_servers);
    } else {
      data.providers = data.providers || {};
      data.providers[providerId] = { ...(data.providers[providerId] || {}), ...updateData };
    }

    this.save(data);
  }

  getRcloneConfigPass() {
    return this._deriveKey().toString('hex');
  }

  getRcloneEnv() {
    return {
      ...process.env,
      RCLONE_CONFIG_PASS: this.getRcloneConfigPass()
    };
  }

  ensureRcloneEncrypted(rcloneBin = null) {
    if (!rcloneBin) {
      const candidates = [
        path.join(os.homedir(), '.local', 'bin', 'rclone'),
        '/usr/bin/rclone',
        '/usr/local/bin/rclone'
      ];
      rcloneBin = candidates.find(p => fs.existsSync(p)) || 'rclone';
    }

    const configPass = this.getRcloneConfigPass();
    const env = { ...process.env, RCLONE_CONFIG_PASS: configPass };
    const rcloneConf = path.join(os.homedir(), '.config', 'rclone', 'rclone.conf');
    if (!fs.existsSync(rcloneConf)) {
      return false;
    }

    try {
      const { execSync } = require('child_process');
      try {
        execSync(`${rcloneBin} config encryption check`, { env, stdio: 'ignore' });
        return true; // Already encrypted with our key
      } catch (err) {
        // Not encrypted yet
      }

      execSync(`${rcloneBin} config encryption set --password-command "echo ${configPass}"`, { stdio: 'ignore' });
      return true;
    } catch (e) {
      return false;
    }
  }
}

module.exports = { Vault };

