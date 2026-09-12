const { CloudProvider } = require('../base');

/**
 * Community Plugin Reference: Oracle Cloud Infrastructure (OCI Always Free)
 * Demonstrates the pluggable cloud provider architecture for Ocloud.
 */
class OracleCloudProvider extends CloudProvider {
  static get metadata() {
    return {
      id: 'oracle',
      name: 'Oracle Cloud Infrastructure (OCI)',
      logoSvg: 'icons/oracle.svg',
      authFields: [
        { key: 'oci_tenancy', label: 'Tenancy OCID', type: 'text' },
        { key: 'oci_user', label: 'User OCID', type: 'text' },
        { key: 'oci_fingerprint', label: 'Key Fingerprint', type: 'text' }
      ],
      serverTypes: ['VM.Standard.A1.Flex', 'VM.Standard.E2.1.Micro'],
      locations: ['eu-frankfurt-1', 'us-ashburn-1', 'ap-tokyo-1']
    };
  }

  async listServers() {
    return [];
  }

  async createVM(name, serverType, location, sshKey) {
    return {
      success: true,
      id: 'oci-' + Math.floor(Math.random() * 100000),
      name: name,
      provider: 'oracle',
      status: 'running',
      ipv4: '140.238.210.45'
    };
  }

  async deleteVM(serverId) {
    return { success: true };
  }
}

module.exports = {
  id: 'oracle',
  CloudProviderClass: OracleCloudProvider
};
