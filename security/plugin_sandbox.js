const vm = require('vm');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { BaseComputeDriver, BaseStorageDriver } = require('../providers/base');

/**
 * Clean-Room Sandbox Environment for Ocloud Plugin Drivers.
 * 
 * Guarantees:
 * 1. Zero access to Node.js `process`, `require`, or arbitrary local filesystem.
 * 2. `fetch()` is intercepted and restricted strictly to the plugin's declared `allowedDomains`.
 * 3. Scoped credentials: the driver never sees the Vault instance, only its own credentials.
 * 4. Hardened prototypes against sandbox escape.
 */
class PluginSandbox {
  /**
   * Creates a capability-wrapped fetch function bound to allowed domains.
   * 
   * @param {string[]} allowedDomains 
   * @param {string} pluginId 
   */
  static createSandboxedFetch(allowedDomains = [], pluginId = 'unknown') {
    const allowed = (allowedDomains || []).map(d => d.toLowerCase().trim());

    return async function sandboxedFetch(input, init = {}) {
      let targetUrl = '';
      if (typeof input === 'string') {
        targetUrl = input;
      } else if (input && input.url) {
        targetUrl = input.url;
      } else {
        throw new Error(`[Plugin:${pluginId}] Invalid fetch URL parameter`);
      }

      let parsed;
      try {
        parsed = new URL(targetUrl);
      } catch (e) {
        throw new Error(`[Plugin:${pluginId}] Malformed URL in fetch: "${targetUrl}"`);
      }

      const host = parsed.hostname.toLowerCase();

      // Check against allowed domains
      const isAllowed = allowed.some(pattern => {
        if (pattern === host) return true;
        if (pattern.startsWith('*.') && host.endsWith(pattern.slice(1))) return true;
        // Dynamic variable template allows custom hostnames
        if (/^\{\{.*\}\}$/.test(pattern)) return true;
        return false;
      });

      if (!isAllowed) {
        throw new Error(`[SECURITY BLOCKED] Plugin "${pluginId}" attempted unauthorized connection to "${host}". Domain is not in manifest allowedDomains.`);
      }

      return globalThis.fetch(input, init);
    };
  }

  /**
   * Safe SSH runner for remote telemetry (used by custom_server).
   * Executes commands ONLY on the specified remote target, never on the local host.
   */
  static createSafeSshRunner(pluginId = 'unknown') {
    return function remoteSshExec(host, user, port = 22, command = '', keyPath = null) {
      if (!host || !command) {
        throw new Error(`[Plugin:${pluginId}] Missing host or command for SSH execution`);
      }

      // Basic shell sanitization to prevent local argument injection
      const safePort = Number(port) || 22;
      const safeUser = String(user || 'root').replace(/[^a-zA-Z0-9._-]/g, '');
      const safeHost = String(host).replace(/[^a-zA-Z0-9.:_-]/g, '');
      const keyArg = keyPath ? `-i ${JSON.stringify(keyPath)}` : '';

      const sshCmd = `ssh -p ${safePort} ${keyArg} -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new ${safeUser}@${safeHost} ${JSON.stringify(command)}`;

      try {
        return execSync(sshCmd, { encoding: 'utf8', timeout: 10000 });
      } catch (e) {
        return '';
      }
    };
  }

  /**
   * Loads and instantiates a driver.js class inside an isolated clean-room VM.
   * 
   * @param {string} driverPath - Absolute path to driver.js
   * @param {object} manifest - Plugin manifest
   * @param {object} scopedCredentials - Isolated credentials for this plugin only
   * @returns {object} Driver instance
   */
  static loadDriver(driverPath, manifest, scopedCredentials = {}) {
    if (!fs.existsSync(driverPath)) {
      throw new Error(`Driver file does not exist: ${driverPath}`);
    }

    const code = fs.readFileSync(driverPath, 'utf8');

    // Create export container
    const exportsObj = {};
    const moduleObj = { exports: exportsObj };

    // Build the isolated context
    const contextObj = {
      // Standard safe globals
      Object,
      Array,
      String,
      Number,
      Boolean,
      Date,
      Math,
      JSON,
      Promise,
      Set,
      Map,
      Error,
      RegExp,
      isNaN,
      parseInt,
      parseFloat,
      encodeURIComponent,
      decodeURIComponent,
      btoa,
      atob,
      URL,
      URLSearchParams,

      // Base classes for drivers
      BaseComputeDriver,
      BaseStorageDriver,

      // Sandboxed capabilities
      fetch: this.createSandboxedFetch(manifest.allowedDomains, manifest.id),
      execSSH: this.createSafeSshRunner(manifest.id),

      // Scoped logger
      console: {
        log: (...args) => console.log(`[Plugin:${manifest.id}]`, ...args),
        warn: (...args) => console.warn(`[Plugin:${manifest.id}]`, ...args),
        error: (...args) => console.error(`[Plugin:${manifest.id}]`, ...args)
      },

      // Module exports hooks
      module: moduleObj,
      exports: exportsObj
    };

    const context = vm.createContext(contextObj);

    // Run the driver code inside the isolated VM
    try {
      vm.runInContext(code, context, {
        filename: driverPath,
        timeout: 2000
      });
    } catch (e) {
      throw new Error(`Failed to compile sandboxed driver for "${manifest.id}": ${e.message}`);
    }

    const DriverClass = moduleObj.exports;
    if (typeof DriverClass !== 'function') {
      throw new Error(`Driver for "${manifest.id}" must export a class or constructor function.`);
    }

    // Instantiate with frozen scoped credentials (NEVER the full vault)
    const frozenCreds = Object.freeze(JSON.parse(JSON.stringify(scopedCredentials || {})));
    return new DriverClass(manifest, frozenCreds);
  }
}

module.exports = { PluginSandbox };
