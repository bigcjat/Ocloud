/**
 * Base interfaces for Pluggable Cloud and Storage Providers in Ocloud.
 * Every provider is either:
 * 1. A pure declarative JSON manifest (for standard storage protocols), or
 * 2. A manifest + JS driver (for compute clouds or custom APIs).
 */

class BaseComputeDriver {
  constructor(manifest, vault) {
    this.manifest = manifest;
    this.vault = vault;
    this.id = manifest.id;
    this.name = manifest.name;
  }

  async fetchCatalog(options = {}) {
    throw new Error(`fetchCatalog() not implemented in ${this.constructor.name}`);
  }

  async listServers() {
    throw new Error(`listServers() not implemented in ${this.constructor.name}`);
  }

  async createServer(options) {
    throw new Error(`createServer() not implemented in ${this.constructor.name}`);
  }

  async startServer(id) {
    throw new Error(`startServer() not implemented in ${this.constructor.name}`);
  }

  async stopServer(id) {
    throw new Error(`stopServer() not implemented in ${this.constructor.name}`);
  }

  async rebootServer(id) {
    throw new Error(`rebootServer() not implemented in ${this.constructor.name}`);
  }

  async deleteServer(id) {
    throw new Error(`deleteServer() not implemented in ${this.constructor.name}`);
  }

  async inspectServer(id) {
    throw new Error(`inspectServer() not implemented in ${this.constructor.name}`);
  }
}

class BaseStorageDriver {
  constructor(manifest, vault) {
    this.manifest = manifest;
    this.vault = vault;
    this.id = manifest.id;
    this.name = manifest.name;
  }

  async getStats(options = {}) {
    throw new Error(`getStats() not implemented in ${this.constructor.name}`);
  }

  async mount(mountPoint, openFileManager = false) {
    throw new Error(`mount() not implemented in ${this.constructor.name}`);
  }

  async unmount(mountPoint) {
    throw new Error(`unmount() not implemented in ${this.constructor.name}`);
  }
}

module.exports = { BaseComputeDriver, BaseStorageDriver };
