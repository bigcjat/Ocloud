const fs = require('fs');
const path = require('path');
const os = require('os');
const { PluginAuditor } = require('../security/plugin_auditor');

/**
 * Universal Plugin Registry for Ocloud.
 * Dynamically discovers, audits, loads, and manages Compute and Storage plugins.
 * 
 * Zero-Trust Guarantees:
 * - Automatically audits all manifests and drivers before instantiation.
 * - Quarantines any plugin containing malicious code, unauthorized shell execution, or undeclared domains.
 * - Delivers strictly isolated scoped credentials to drivers (never exposes the full Vault).
 * - Sanitizes all embedded SVG logos against XXE, scripts, and XML bombs.
 */
class PluginRegistry {
  constructor() {
    this.computePlugins = new Map();
    this.storagePlugins = new Map();
    this.workloadPlugins = new Map();
    this.quarantinedPlugins = new Map();
    this._initialized = false;
    this.vault = null;
  }

  init(vault) {
    if (this._initialized) return;
    this.vault = vault;
    this.computePlugins.clear();
    this.storagePlugins.clear();
    this.workloadPlugins.clear();
    this.quarantinedPlugins.clear();

    // 1. Built-in plugins directory
    const builtinDir = path.join(__dirname, 'plugins');
    this._loadFromDirectory(builtinDir);

    // 2. User / Community plugins directory (~/.config/ocloud/plugins/)
    const userDir = path.join(os.homedir(), '.config', 'ocloud', 'plugins');
    this._loadFromDirectory(userDir);

    this._initialized = true;
  }

  _loadFromDirectory(dirPath) {
    if (!fs.existsSync(dirPath)) return;

    let entries = [];
    try {
      entries = fs.readdirSync(dirPath, { withFileTypes: true });
    } catch (e) {
      console.warn(`[PluginRegistry] Cannot read ${dirPath}: ${e.message}`);
      return;
    }

    for (const entry of entries) {
      if (entry.name.startsWith('.')) continue;
      const fullPath = path.join(dirPath, entry.name);
      try {
        if (entry.isFile() && entry.name.endsWith('.json')) {
          // Pure declarative JSON plugin
          this._loadJsonPlugin(fullPath);
        } else if (entry.isDirectory()) {
          // Check if this directory is an individual plugin (contains plugin.json)
          if (fs.existsSync(path.join(fullPath, 'plugin.json'))) {
            this._loadDirPlugin(fullPath);
          } else {
            // Category subfolder (e.g. compute/, storage/) -> recurse
            this._loadFromDirectory(fullPath);
          }
        }
      } catch (err) {
        console.warn(`[PluginRegistry] Failed to load plugin ${entry.name}: ${err.message}`);
      }
    }
  }

  _loadJsonPlugin(filePath) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const manifest = JSON.parse(raw);
    if (!manifest.id || !manifest.name) return;

    // Security Audit
    const auditReport = PluginAuditor.auditJsonPluginFile(filePath);
    manifest.securityStatus = auditReport.status;
    manifest.securityViolations = auditReport.violations;
    manifest.securityWarnings = auditReport.warnings;

    if (auditReport.status === 'BLOCKED') {
      console.warn(`[PluginRegistry] QUARANTINED: Storage plugin "${manifest.id}" blocked by security audit: ${auditReport.violations.join('; ')}`);
      this.quarantinedPlugins.set(manifest.id, { manifest, report: auditReport });
      return;
    }

    this._normalizeManifest(manifest, path.dirname(filePath));

    if (manifest.type === 'compute') {
      this.computePlugins.set(manifest.id, { manifest, driver: null });
    } else if (manifest.category === 'workload' || manifest.type === 'workload') {
      this.workloadPlugins.set(manifest.id, { manifest, driver: null });
    } else {
      this.storagePlugins.set(manifest.id, { manifest, driver: null });
    }
  }

  _loadDirPlugin(dirPath) {
    const manifestPath = path.join(dirPath, 'plugin.json');
    if (!fs.existsSync(manifestPath)) return;

    const raw = fs.readFileSync(manifestPath, 'utf8');
    const manifest = JSON.parse(raw);
    if (!manifest.id || !manifest.name) return;

    // Security Audit
    const auditReport = PluginAuditor.auditPluginDir(dirPath);
    manifest.securityStatus = auditReport.status;
    manifest.securityViolations = auditReport.violations;
    manifest.securityWarnings = auditReport.warnings;
    manifest.extractedDomains = auditReport.extractedDomains;

    if (auditReport.status === 'BLOCKED') {
      console.warn(`\x1b[31m[PluginRegistry] SECURITY BLOCKED: Plugin "${manifest.id}" failed audit and was quarantined:\x1b[0m`);
      for (const v of auditReport.violations) {
        console.warn(`  - ${v}`);
      }
      this.quarantinedPlugins.set(manifest.id, { manifest, report: auditReport });
      return;
    }

    this._normalizeManifest(manifest, dirPath);

    let driverInstance = null;
    if (manifest.driver) {
      const driverPath = path.join(dirPath, manifest.driver);
      if (fs.existsSync(driverPath)) {
        try {
          const DriverClass = require(driverPath);

          // Build isolated capability context (Never pass raw Vault)
          const scopedCreds = this.vault && typeof this.vault.getScopedCredentials === 'function'
            ? this.vault.getScopedCredentials(manifest.id)
            : {};
          
          const scopedContext = {
            credentials: scopedCreds,
            saveCredentials: (updated) => {
              if (this.vault && typeof this.vault.setScopedCredentials === 'function') {
                this.vault.setScopedCredentials(manifest.id, updated);
              }
            }
          };

          driverInstance = new DriverClass(manifest, scopedContext);
        } catch (driverErr) {
          console.warn(`[PluginRegistry] Failed to instantiate driver for ${manifest.id}: ${driverErr.message}`);
        }
      }
    }

    if (manifest.type === 'compute') {
      this.computePlugins.set(manifest.id, { manifest, driver: driverInstance });
    } else if (manifest.category === 'workload' || manifest.type === 'workload') {
      this.workloadPlugins.set(manifest.id, { manifest, driver: driverInstance });
    } else {
      this.storagePlugins.set(manifest.id, { manifest, driver: driverInstance });
    }
  }

  _normalizeManifest(manifest, baseDir) {
    // Sanitize and generate base64 data URI for SVG icon if provided
    if (manifest.iconSvg) {
      const { safeSvg } = PluginAuditor.sanitizeSvg(manifest.iconSvg);
      if (safeSvg) {
        manifest.iconSvg = safeSvg;
        manifest.iconDataUri = `data:image/svg+xml;base64,${Buffer.from(safeSvg).toString('base64')}`;
      }
    }
    manifest.baseDir = baseDir;

    // Normalize instructions & field labels for seamless QML usage
    if (manifest.instructions) {
      manifest.step1Desc = manifest.instructions.step1 || '';
      manifest.step2Desc = manifest.instructions.step2 || '';
      manifest.step3Desc = manifest.instructions.step3 || '';
      manifest.navBreadcrumb = manifest.instructions.navBreadcrumb || '';
    }
    if (Array.isArray(manifest.fields)) {
      for (const f of manifest.fields) {
        if (f.key === 'endpoint') {
          manifest.endpointLabel = f.label;
          manifest.endpointPlaceholder = f.placeholder;
          manifest.endpointHelper = f.helper;
        } else if (f.key === 'bucket') {
          manifest.bucketLabel = f.label;
          manifest.bucketPlaceholder = f.placeholder;
          manifest.bucketHelper = f.helper;
        } else if (f.key === 'access_key' || f.key === 'key' || f.key === 'username') {
          manifest.keyLabel = f.label;
          manifest.keyPlaceholder = f.placeholder;
          manifest.keyHelper = f.helper;
        } else if (f.key === 'secret_key' || f.key === 'secret' || f.key === 'password') {
          manifest.secretLabel = f.label;
          manifest.secretPlaceholder = f.placeholder;
          manifest.secretHelper = f.helper;
        }
      }
    }
    if (!manifest.defaultName) {
      manifest.defaultName = manifest.name;
    }
  }

  // ------------------------------------------------------------- Security Audit APIs
  auditPlugin(pluginId) {
    const compute = this.computePlugins.get(pluginId);
    if (compute) {
      return compute.manifest.baseDir 
        ? PluginAuditor.auditPluginDir(compute.manifest.baseDir)
        : { status: 'PASSED', violations: [], warnings: [] };
    }
    const storage = this.storagePlugins.get(pluginId);
    if (storage) {
      if (storage.manifest.driver) {
        return PluginAuditor.auditPluginDir(storage.manifest.baseDir);
      }
      const res = PluginAuditor.auditManifest(storage.manifest);
      return { id: pluginId, ...res };
    }
    const quarantined = this.quarantinedPlugins.get(pluginId);
    if (quarantined) {
      return quarantined.report;
    }
    return null;
  }

  auditAll() {
    const reports = [];
    const builtinDir = path.join(__dirname, 'plugins');
    const userDir = path.join(os.homedir(), '.config', 'ocloud', 'plugins');

    const scanDir = (dir) => {
      if (!fs.existsSync(dir)) return;
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const e of entries) {
        if (e.name.startsWith('.')) continue;
        const full = path.join(dir, e.name);
        if (e.isFile() && e.name.endsWith('.json')) {
          reports.push(PluginAuditor.auditJsonPluginFile(full));
        } else if (e.isDirectory()) {
          if (fs.existsSync(path.join(full, 'plugin.json'))) {
            reports.push(PluginAuditor.auditPluginDir(full));
          } else {
            scanDir(full);
          }
        }
      }
    };

    scanDir(builtinDir);
    scanDir(userDir);
    return reports;
  }

  // ------------------------------------------------------------- Compute APIs
  listComputePlugins() {
    const list = [];
    for (const [id, item] of this.computePlugins.entries()) {
      const isConfigured = item.driver && typeof item.driver.isConfigured === 'function'
        ? item.driver.isConfigured()
        : true;
      list.push({
        ...item.manifest,
        isConfigured
      });
    }
    return list;
  }

  getComputePlugin(id) {
    return this.computePlugins.get(id) || null;
  }

  async getCatalog(providerId, forceRefresh = false) {
    const plugin = this.getComputePlugin(providerId);
    if (!plugin || !plugin.driver) {
      throw new Error(`Compute provider '${providerId}' has no active driver or catalog.`);
    }
    if (typeof plugin.driver.getCatalog === 'function') {
      return await plugin.driver.getCatalog(forceRefresh);
    }
    if (typeof plugin.driver.fetchCatalog === 'function') {
      return await plugin.driver.fetchCatalog({ forceRefresh });
    }
    throw new Error(`Provider '${providerId}' does not support catalog querying.`);
  }

  async listAllServers() {
    const allServers = [];
    for (const [id, item] of this.computePlugins.entries()) {
      if (item.driver && typeof item.driver.listServers === 'function') {
        try {
          const srvs = await item.driver.listServers();
          allServers.push(...(srvs || []));
        } catch (e) {
          console.warn(`[PluginRegistry] listServers failed for ${id}: ${e.message}`);
        }
      }
    }
    return allServers;
  }

  // ------------------------------------------------------------- Storage APIs
  listStoragePlugins() {
    const list = [];
    for (const [id, item] of this.storagePlugins.entries()) {
      list.push(item.manifest);
    }
    return list;
  }

  getStoragePlugin(id) {
    return this.storagePlugins.get(id) || null;
  }

  // ------------------------------------------------------------- Workload APIs
  listWorkloadPlugins() {
    const list = [];
    for (const [id, item] of this.workloadPlugins.entries()) {
      list.push(item.manifest);
    }
    return list;
  }

  getWorkloadPlugin(id) {
    return this.workloadPlugins.get(id) || null;
  }

  saveCustomWorkloadPlugin(manifest) {
    if (!manifest.id || !manifest.name) {
      throw new Error("Plugin must have id and name");
    }
    manifest.category = "workload";
    manifest.isCustom = true;
    const userWorkloadDir = path.join(os.homedir(), '.config', 'ocloud', 'plugins', 'workload');
    if (!fs.existsSync(userWorkloadDir)) {
      fs.mkdirSync(userWorkloadDir, { recursive: true });
    }
    const targetPath = path.join(userWorkloadDir, `${manifest.id}.json`);
    fs.writeFileSync(targetPath, JSON.stringify(manifest, null, 2), 'utf8');
    this._normalizeManifest(manifest, userWorkloadDir);
    this.workloadPlugins.set(manifest.id, { manifest, driver: null });
    return manifest;
  }

  deleteCustomWorkloadPlugin(id) {
    const userWorkloadDir = path.join(os.homedir(), '.config', 'ocloud', 'plugins', 'workload');
    const targetPath = path.join(userWorkloadDir, `${id}.json`);
    if (fs.existsSync(targetPath)) {
      fs.unlinkSync(targetPath);
    }
    this.workloadPlugins.delete(id);
    return true;
  }
}

module.exports = new PluginRegistry();
