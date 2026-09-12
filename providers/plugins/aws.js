const { CloudProvider } = require('../base');

/**
 * Community Plugin Reference: AWS Lightsail & EC2
 * Demonstrates the pluggable cloud provider architecture for Ocloud.
 */
class AwsCloudProvider extends CloudProvider {
  static get metadata() {
    return {
      id: 'aws',
      name: 'Amazon Web Services (Lightsail)',
      logoSvg: 'icons/aws.svg',
      authFields: [
        { key: 'aws_access_key', label: 'Access Key ID', type: 'text' },
        { key: 'aws_secret_key', label: 'Secret Access Key', type: 'password' },
        { key: 'aws_region', label: 'Default Region', type: 'text' }
      ],
      serverTypes: ['nano_2_0', 'micro_2_0', 'small_2_0'],
      locations: ['us-east-1', 'us-west-2', 'eu-central-1', 'ap-northeast-1']
    };
  }

  async listServers() {
    return [];
  }

  async createVM(name, serverType, location, sshKey) {
    return {
      success: true,
      id: 'aws-' + Math.floor(Math.random() * 100000),
      name: name,
      provider: 'aws',
      status: 'provisioning',
      ipv4: 'Pending AWS Allocation'
    };
  }

  async deleteVM(serverId) {
    return { success: true };
  }
}

module.exports = {
  id: 'aws',
  CloudProviderClass: AwsCloudProvider
};
