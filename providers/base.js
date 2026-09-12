/**
 * Base interfaces for Pluggable Cloud and Storage Providers in Ocloud.
 * Allows easy extension to Hetzner, Custom SSH / Home Workstations, Vultr, AWS, etc.
 */

class CloudProvider {
  constructor(id, name, config = {}) {
    this.id = id;
    this.name = name;
    this.config = config;
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

class StorageProvider {
  constructor(id, name, config = {}) {
    this.id = id;
    this.name = name;
    this.config = config;
  }

  async getStats() {
    throw new Error(`getStats() not implemented in ${this.constructor.name}`);
  }

  async mount(mountPoint) {
    throw new Error(`mount() not implemented in ${this.constructor.name}`);
  }

  async unmount(mountPoint) {
    throw new Error(`unmount() not implemented in ${this.constructor.name}`);
  }
}

module.exports = { CloudProvider, StorageProvider };
