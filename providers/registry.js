const fs = require('fs');
const path = require('path');
const os = require('os');
const { CloudProvider, StorageProvider } = require('./base');

/**
 * Provider Registry for Ocloud.
 * Discovers and manages both Cloud Compute providers (VMs/servers) and Storage providers (Object/File stores).
 * Allows community plugins to be dropped into ~/.config/omarchy/ocloud/providers/ or providers/plugins/.
 */
class ProviderRegistry {
  constructor() {
    this.cloudProviders = new Map();
    this.storageProviders = new Map();
    this._initialized = false;
  }

  registerCloudProvider(id, providerClass) {
    this.cloudProviders.set(id, providerClass);
  }

  registerStorageProvider(id, providerClass) {
    this.storageProviders.set(id, providerClass);
  }

  init(vault) {
    if (this._initialized) return;

    // 1. Built-in Compute Providers
    const { HetznerCloudProvider } = require('./hetzner');
    const { CustomComputeProvider } = require('./custom');

    this.registerCloudProvider('hetzner', HetznerCloudProvider);
    this.registerCloudProvider('custom', CustomComputeProvider);

    // 2. Built-in Storage Providers
    const { HetznerStorageProvider } = require('./hetzner');
    const { CustomStorageProvider } = require('./custom');

    this.registerStorageProvider('hetzner_box', HetznerStorageProvider);
    this.registerStorageProvider('custom', CustomStorageProvider);

    // 3. Load Internal & External Plugins
    this._loadPluginsFromDir(path.join(__dirname, 'plugins'), vault);
    this._loadPluginsFromDir(path.join(os.homedir(), '.config', 'omarchy', 'ocloud', 'providers'), vault);

    this._initialized = true;
  }

  _loadPluginsFromDir(dirPath, vault) {
    if (!fs.existsSync(dirPath)) return;
    try {
      const files = fs.readdirSync(dirPath).filter((f) => f.endsWith('.js'));
      for (const file of files) {
        try {
          const pluginModule = require(path.join(dirPath, file));
          if (pluginModule.CloudProviderClass && pluginModule.id) {
            this.registerCloudProvider(pluginModule.id, pluginModule.CloudProviderClass);
          }
          if (pluginModule.StorageProviderClass && pluginModule.id) {
            this.registerStorageProvider(pluginModule.id, pluginModule.StorageProviderClass);
          }
        } catch (err) {
          console.warn(`[Ocloud Plugin] Failed to load ${file}: ${err.message}`);
        }
      }
    } catch (e) {}
  }

  getCloudCatalog() {
    return [
      {
        id: 'hetzner',
        name: 'Hetzner Cloud',
        type: 'api',
        logoSvg: 'icons/hetzner.svg',
        description: 'Cost-effective high-performance European & US cloud compute',
        authFields: [{ key: 'api_token', label: 'Hetzner API Token', type: 'password' }],
        serverTypes: ['cx23', 'cx33', 'cpx31', 'cpx41', 'cax11'],
        locations: ['nbg1', 'fsn1', 'hel1', 'ash', 'hil']
      },
      {
        id: 'aws',
        name: 'Amazon Web Services (Lightsail / EC2)',
        type: 'api',
        logoSvg: 'icons/aws.svg',
        description: 'Industry standard compute with global availability',
        authFields: [
          { key: 'aws_access_key', label: 'Access Key ID', type: 'text' },
          { key: 'aws_secret_key', label: 'Secret Access Key', type: 'password' },
          { key: 'aws_region', label: 'Default Region (e.g. us-east-1)', type: 'text' }
        ],
        serverTypes: ['lightsail_micro', 'lightsail_small', 't4g.micro', 't3.small'],
        locations: ['us-east-1', 'us-west-2', 'eu-central-1', 'ap-southeast-1']
      },
      {
        id: 'oracle',
        name: 'Oracle Cloud Infrastructure (OCI)',
        type: 'api',
        logoSvg: 'icons/oracle.svg',
        description: 'Generous Always-Free tier (up to 4 ARM cores, 24GB RAM)',
        authFields: [
          { key: 'oci_tenancy', label: 'Tenancy OCID', type: 'text' },
          { key: 'oci_user', label: 'User OCID', type: 'text' },
          { key: 'oci_fingerprint', label: 'Key Fingerprint', type: 'text' }
        ],
        serverTypes: ['VM.Standard.A1.Flex', 'VM.Standard.E2.1.Micro'],
        locations: ['eu-frankfurt-1', 'us-ashburn-1', 'us-phoenix-1']
      },
      {
        id: 'digitalocean',
        name: 'DigitalOcean',
        type: 'api',
        logoSvg: 'icons/digitalocean.svg',
        description: 'Developer cloud with turnkey Droplets and predictable pricing',
        authFields: [{ key: 'do_api_token', label: 'Personal Access Token', type: 'password' }],
        serverTypes: ['s-1vcpu-1gb', 's-1vcpu-2gb', 's-2vcpu-4gb'],
        locations: ['nyc1', 'sfo3', 'fra1', 'lon1']
      },
      {
        id: 'vultr',
        name: 'Vultr',
        type: 'api',
        logoSvg: 'icons/vultr.svg',
        description: 'Worldwide cloud compute and bare-metal nodes across 32 datacenters',
        authFields: [{ key: 'vultr_api_key', label: 'Vultr API Key', type: 'password' }],
        serverTypes: ['vc2-1c-1gb', 'vc2-1c-2gb', 'vc2-2c-4gb'],
        locations: ['ewr', 'ord', 'fra', 'nrt']
      },
      {
        id: 'custom',
        name: 'Bare-Metal / Custom SSH Server',
        type: 'manual',
        logoSvg: 'icons/server.svg',
        description: 'Connect any existing Linux box, home lab, or unmanaged VPS via SSH',
        authFields: [
          { key: 'host', label: 'Hostname / IP Address', type: 'text' },
          { key: 'port', label: 'SSH Port', type: 'number', default: '22' },
          { key: 'user', label: 'SSH Username', type: 'text', default: 'root' },
          { key: 'key_path', label: 'Private Key Path', type: 'text', default: '~/.ssh/id_ed25519' }
        ]
      }
    ];
  }

  getStorageCatalog() {
    return [
      {
        id: 'hetzner_box',
        name: 'Hetzner Storage Box',
        protocol: 'webdav/sftp',
        logoSvg: 'icons/hetzner.svg',
        description: 'High-capacity RAID storage with WebDAV, SFTP, and snapshot capabilities',
        defaultMount: '~/Cloud',
        fields: [
          { key: 'username', label: 'Storage Box Username (e.g. u123456)', type: 'text' },
          { key: 'host', label: 'Host (e.g. u123456.your-storagebox.de)', type: 'text' },
          { key: 'password', label: 'Storage Box Password', type: 'password' }
        ]
      },
      {
        id: 's3_generic',
        name: 'S3 / Cloudflare R2 / Backblaze B2 / Wasabi',
        protocol: 's3',
        logoSvg: 'icons/cloudflare.svg',
        description: 'Universal S3-compatible object storage mount with zero/low egress',
        defaultMount: '~/S3-Storage',
        fields: [
          { key: 'endpoint', label: 'S3 Endpoint URL (leave blank for AWS S3)', type: 'text' },
          { key: 'bucket', label: 'Bucket Name', type: 'text' },
          { key: 'access_key', label: 'Access Key ID', type: 'text' },
          { key: 'secret_key', label: 'Secret Access Key', type: 'password' }
        ]
      },
      {
        id: 'webdav_generic',
        name: 'Nextcloud / ownCloud / WebDAV',
        protocol: 'webdav',
        logoSvg: 'icons/hard-drive.svg',
        description: 'Mount any self-hosted Nextcloud, ownCloud, or standard WebDAV share',
        defaultMount: '~/Nextcloud',
        fields: [
          { key: 'url', label: 'WebDAV Server URL (e.g. https://cloud.example.com/remote.php/dav/files/user/)', type: 'text' },
          { key: 'user', label: 'Username', type: 'text' },
          { key: 'password', label: 'Password / App Password', type: 'password' }
        ]
      },
      {
        id: 'google_drive',
        name: 'Google Drive',
        protocol: 'rest_api',
        logoSvg: 'icons/gcp.svg',
        description: 'Mount Google Drive personal or workspace storage',
        defaultMount: '~/Google-Drive',
        fields: [
          { key: 'client_id', label: 'OAuth Client ID (optional)', type: 'text' },
          { key: 'client_secret', label: 'OAuth Client Secret (optional)', type: 'password' }
        ]
      },
      {
        id: 'dropbox',
        name: 'Dropbox',
        protocol: 'rest_api',
        logoSvg: 'icons/hard-drive.svg',
        description: 'Mount Dropbox cloud files with automated syncing',
        defaultMount: '~/Dropbox-Cloud',
        fields: [
          { key: 'access_token', label: 'Dropbox API Access Token', type: 'password' }
        ]
      },
      {
        id: 'home_nas',
        name: 'Home NAS (SMB / NFS / Local)',
        protocol: 'smb_nfs',
        logoSvg: 'icons/nas.svg',
        description: 'Local network attached storage (Synology, TrueNAS, Unraid, Raspberry Pi)',
        defaultMount: '~/Home-NAS',
        fields: [
          { key: 'host', label: 'NAS IP Address or Hostname', type: 'text' },
          { key: 'share', label: 'Share Name / Path (e.g. /volume1/data)', type: 'text' },
          { key: 'user', label: 'Username', type: 'text' },
          { key: 'password', label: 'Password', type: 'password' }
        ]
      }
    ];
  }
}

module.exports = new ProviderRegistry();
