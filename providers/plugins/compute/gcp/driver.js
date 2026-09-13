const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const { BaseComputeDriver } = require('../../../base');

const OAUTH_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const COMPUTE_API_BASE = 'https://compute.googleapis.com/compute/v1/projects';

class GoogleComputeDriver extends BaseComputeDriver {
  constructor(manifest, context = {}) {
    super(manifest);
    if (context && typeof context.get === 'function') {
      this.credentials = {
        gcp_service_account_json: context.get('gcp_service_account_json', ''),
        gcp_project_id: context.get('gcp_project_id', ''),
        gcp_default_zone: context.get('gcp_default_zone', 'us-central1-a'),
        tailscale_auth_key: context.get('tailscale_auth_key', '')
      };
    } else if (context && context.credentials) {
      this.credentials = context.credentials;
      this.saveCredentials = context.saveCredentials;
    } else {
      this.credentials = context || {};
    }

    this._cachedToken = null;
    this._tokenExpiry = 0;
  }

  _getServiceAccountData() {
    const raw = (this.credentials && this.credentials.gcp_service_account_json) ||
                process.env.GCP_SERVICE_ACCOUNT_JSON ||
                process.env.GOOGLE_APPLICATION_CREDENTIALS || '';
    if (!raw) return null;

    const trimmed = raw.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        return JSON.parse(trimmed);
      } catch (e) {
        return null;
      }
    }

    if (fs.existsSync(trimmed)) {
      try {
        const fileContent = fs.readFileSync(trimmed, 'utf8');
        return JSON.parse(fileContent);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  getProjectId() {
    if (this.credentials && this.credentials.gcp_project_id) {
      return this.credentials.gcp_project_id.trim();
    }
    const sa = this._getServiceAccountData();
    if (sa && sa.project_id) {
      return sa.project_id;
    }
    return process.env.GCP_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT || '';
  }

  getDefaultZone() {
    return (this.credentials && this.credentials.gcp_default_zone) || 'us-central1-a';
  }

  getTailscaleKey() {
    return (this.credentials && this.credentials.tailscale_auth_key) || '';
  }

  isConfigured() {
    const sa = this._getServiceAccountData();
    return Boolean(sa && sa.client_email && sa.private_key && this.getProjectId());
  }

  async _getAccessToken() {
    const now = Math.floor(Date.now() / 1000);
    if (this._cachedToken && this._tokenExpiry > now + 60) {
      return this._cachedToken;
    }

    const sa = this._getServiceAccountData();
    if (!sa || !sa.client_email || !sa.private_key) {
      throw new Error('Google Cloud Service Account credentials are not configured in Ocloud Vault.');
    }

    const header = { alg: 'RS256', typ: 'JWT' };
    const payload = {
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/compute',
      aud: OAUTH_TOKEN_URL,
      exp: now + 3600,
      iat: now
    };

    const b64Header = Buffer.from(JSON.stringify(header)).toString('base64url');
    const b64Payload = Buffer.from(JSON.stringify(payload)).toString('base64url');
    const unsignedToken = `${b64Header}.${b64Payload}`;

    const signer = crypto.createSign('RSA-SHA256');
    signer.update(unsignedToken);
    const signature = signer.sign(sa.private_key, 'base64url');
    const jwtAssertion = `${unsignedToken}.${signature}`;

    const params = new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwtAssertion
    });

    const res = await fetch(OAUTH_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Ocloud/1.0'
      },
      body: params.toString()
    });

    const data = await res.json();
    if (!res.ok || !data.access_token) {
      const msg = data.error_description || data.error || `HTTP ${res.status}`;
      throw new Error(`Failed to obtain Google Cloud OAuth token: ${msg}`);
    }

    this._cachedToken = data.access_token;
    this._tokenExpiry = now + (data.expires_in || 3600);
    return this._cachedToken;
  }

  async _request(method, endpoint, body = null) {
    const projectId = this.getProjectId();
    if (!projectId) {
      throw new Error('Google Cloud Project ID is missing. Please set gcp_project_id in Vault.');
    }

    const token = await this._getAccessToken();
    const url = `${COMPUTE_API_BASE}/${projectId}${endpoint}`;

    const headers = {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'User-Agent': 'Ocloud/1.0'
    };

    const res = await fetch(url, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined
    });

    const text = await res.text();
    let json = {};
    try {
      json = text ? JSON.parse(text) : {};
    } catch (e) {}

    if (!res.ok) {
      let errorMsg = json.error?.message || `Google Cloud API HTTP ${res.status}: ${res.statusText}`;
      const isServiceDisabled = errorMsg.includes('Compute Engine API has not been used') ||
        errorMsg.includes('compute.googleapis.com') ||
        errorMsg.includes('SERVICE_DISABLED') ||
        (errorMsg.includes('disabled') && errorMsg.includes('project'));
      const projectId = this.getProjectId();
      const enableUrl = `https://console.cloud.google.com/apis/library/compute.googleapis.com?project=${projectId || ''}`;
      if (isServiceDisabled) {
        errorMsg = `Compute Engine API is disabled in project '${projectId || 'unknown'}'. Google Cloud requires this API to be enabled before managing or creating virtual machines. Enable it here: ${enableUrl}`;
      }
      const err = new Error(errorMsg);
      if (isServiceDisabled) {
        err.needsApiEnable = true;
        err.enableUrl = enableUrl;
        err.projectId = projectId;
      }
      throw err;
    }

    return json;
  }

  async verifyCredentials() {
    if (!this.isConfigured()) {
      return { ok: false, error: 'Google Cloud Service Account JSON is missing.' };
    }
    const projectId = this.getProjectId();
    try {
      await this._request('GET', '/aggregated/instances?maxResults=1');
      return { ok: true, projectId };
    } catch (err) {
      const msg = err.message || '';
      if (msg.includes('Compute Engine API has not been used') || msg.includes('disabled') || msg.includes('compute.googleapis.com')) {
        return {
          ok: false,
          needsApiEnable: true,
          projectId: projectId,
          enableUrl: `https://console.cloud.google.com/apis/library/compute.googleapis.com?project=${projectId}`,
          error: `Compute Engine API is disabled in project '${projectId}'. Google Cloud requires this API to be enabled before creating or managing virtual machines.`
        };
      }
      return { ok: false, error: msg, projectId };
    }
  }

  async listServers() {
    if (!this.isConfigured()) return [];
    try {
      const data = await this._request('GET', '/aggregated/instances');
      const items = data.items || {};
      const servers = [];

      for (const [zoneKey, zoneData] of Object.entries(items)) {
        if (!zoneData.instances || !Array.isArray(zoneData.instances)) continue;
        const zoneName = zoneKey.replace('zones/', '');

        for (const inst of zoneData.instances) {
          const natIp = inst.networkInterfaces?.[0]?.accessConfigs?.[0]?.natIP || 'no IP';
          const machineType = inst.machineType ? inst.machineType.split('/').pop() : 'e2-micro';
          let status = 'stopped';
          if (inst.status === 'RUNNING') status = 'running';
          else if (inst.status === 'PROVISIONING' || inst.status === 'STAGING') status = 'starting';
          else if (inst.status === 'STOPPING') status = 'stopping';

          let priceHourly = 0.0084;
          let priceMonthly = 6.11;
          if (machineType.includes('e2-small')) { priceHourly = 0.0168; priceMonthly = 12.23; }
          else if (machineType.includes('e2-medium')) { priceHourly = 0.0336; priceMonthly = 24.46; }
          else if (machineType.includes('e2-standard-2')) { priceHourly = 0.067; priceMonthly = 48.92; }

          servers.push({
            id: inst.id || inst.name,
            name: inst.name,
            status: status,
            type: machineType,
            ipv4: natIp,
            location: zoneName,
            zone: zoneName,
            provider: 'gcp',
            providerName: 'Google Cloud',
            providerIcon: this.manifest ? this.manifest.iconDataUri : null,
            datacenter: zoneName,
            created: inst.creationTimestamp,
            tags: ['cloud', 'gcp'],
            isHomeWorkstation: false,
            priceHourly,
            priceMonthly,
            currency: 'USD',
            currencySymbol: '$'
          });
        }
      }

      return servers;
    } catch (err) {
      console.error(`[Google Cloud Driver] Failed to list servers: ${err.message}`);
      return [];
    }
  }

  async createServer({ name, type = 'e2-micro', location = 'us-central1-a', tailscaleKey = null, image = 'ubuntu-24.04', diskSizeGb = 30, publicKey = '' }) {
    const zone = location || this.getDefaultZone();
    const tsKey = tailscaleKey || this.getTailscaleKey();
    const pubKey = publicKey ? publicKey.trim() : '';

    // Map common OS images to official GCP public image family URLs
    let sourceImage = 'projects/ubuntu-os-cloud/global/images/family/ubuntu-2404-lts';
    if (image.includes('debian-12') || image.includes('debian')) {
      sourceImage = 'projects/debian-cloud/global/images/family/debian-12';
    } else if (image.includes('rocky')) {
      sourceImage = 'projects/rocky-linux-cloud/global/images/family/rocky-linux-9';
    } else if (image.includes('almalinux') || image.includes('alma')) {
      sourceImage = 'projects/almalinux-cloud/global/images/family/almalinux-9';
    } else if (image.includes('ubuntu-22')) {
      sourceImage = 'projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts';
    }

    const startupScript = `#!/bin/bash
mkdir -p /root/.ssh
chmod 700 /root/.ssh
${pubKey ? `echo "${pubKey}" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
` : ''}
# Ensure root SSH access with key
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config 2>/dev/null || true
systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true

# Install fastfetch and configure for SSH login
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y fastfetch || (curl -fsSL https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb -o /tmp/ff.deb && dpkg -i /tmp/ff.deb)
elif command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm fastfetch
elif command -v apk >/dev/null 2>&1; then
  apk add fastfetch
mkdir -p /etc/profile.d
echo '[ -t 1 ] && command -v fastfetch >/dev/null 2>&1 && fastfetch' > /etc/profile.d/fastfetch.sh
chmod +x /etc/profile.d/fastfetch.sh

# Install and configure Tailscale
curl -fsSL -o /tmp/ts_install.sh https://tailscale.com/install.sh
sh /tmp/ts_install.sh
systemctl enable --now tailscaled || true
${tsKey ? `tailscale up --authkey=${tsKey} --hostname=${name} --accept-routes` : `tailscale up --timeout=5s > /var/log/tailscale_auth.log 2>&1 || true`}
`;

    const metadataItems = [
      { key: 'enable-oslogin', value: 'FALSE' },
      { key: 'startup-script', value: startupScript }
    ];
    if (pubKey) {
      metadataItems.push({
        key: 'ssh-keys',
        value: `root:${pubKey} root\nbigcjat:${pubKey} bigcjat\nubuntu:${pubKey} ubuntu\ndebian:${pubKey} debian`
      });
    }

    // Standard Persistent Disk (pd-standard) ensures zero accidental balanced/SSD charges
    const payload = {
      name,
      machineType: `zones/${zone}/machineTypes/${type}`,
      disks: [
        {
          boot: true,
          autoDelete: true,
          initializeParams: {
            sourceImage,
            diskSizeGb: String(diskSizeGb || 30),
            diskType: `zones/${zone}/diskTypes/pd-standard`
          }
        }
      ],
      networkInterfaces: [
        {
          network: 'global/networks/default',
          accessConfigs: [
            {
              name: 'External NAT',
              type: 'ONE_TO_ONE_NAT'
            }
          ]
        }
      ],
      metadata: {
        items: metadataItems
      },
      tags: {
        items: ['ocloud', 'ocloud-runner']
      }
    };

    const res = await this._request('POST', `/zones/${zone}/instances`, payload);
    return {
      id: res.targetId || name,
      name,
      status: 'provisioning',
      zone,
      type
    };
  }

  async _resolveInstanceZone(idOrName) {
    const servers = await this.listServers();
    const match = servers.find((s) => String(s.id) === String(idOrName) || s.name === idOrName);
    return match ? (match.zone || match.location) : this.getDefaultZone();
  }

  async startServer(idOrName) {
    const zone = await this._resolveInstanceZone(idOrName);
    return this._request('POST', `/zones/${zone}/instances/${idOrName}/start`);
  }

  async stopServer(idOrName) {
    const zone = await this._resolveInstanceZone(idOrName);
    return this._request('POST', `/zones/${zone}/instances/${idOrName}/stop`);
  }

  async rebootServer(idOrName) {
    const zone = await this._resolveInstanceZone(idOrName);
    return this._request('POST', `/zones/${zone}/instances/${idOrName}/reset`);
  }

  async deleteServer(idOrName) {
    const zone = await this._resolveInstanceZone(idOrName);
    return this._request('DELETE', `/zones/${zone}/instances/${idOrName}`);
  }

  async inspectServer(serverOrIp) {
    const ip = typeof serverOrIp === 'string' ? serverOrIp : serverOrIp.ipv4;
    const keyPath = path.join(os.homedir(), '.ssh', 'id_ed25519');
    const remoteCmd =
      "echo '---CPU---' && cat /proc/loadavg && " +
      "echo '---MEM---' && free -b && " +
      "echo '---DISK---' && df -B1 / && " +
      "echo '---UPTIME---' && uptime -p && " +
      "echo '---PROCS---' && ps -eo pid,%cpu,%mem,comm --sort=-%cpu | head -n 6";

    const raw = execSync(
      `ssh -i "${keyPath}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${ip} "${remoteCmd}"`,
      { encoding: 'utf8' }
    );

    const data = { ip, status: 'online' };
    const sectionLines = {};
    let curSec = null;
    for (const l of raw.split('\n')) {
      const line = l.trim();
      if (line.startsWith('---') && line.endsWith('---')) {
        curSec = line.replace(/-/g, '');
        sectionLines[curSec] = [];
      } else if (curSec && line) {
        sectionLines[curSec].push(line);
      }
    }

    if (sectionLines.CPU && sectionLines.CPU.length > 0) {
      const parts = sectionLines.CPU[0].split(/\s+/);
      data.load_1m = parseFloat(parts[0]) || 0;
      data.load_5m = parseFloat(parts[1]) || 0;
      data.load_15m = parseFloat(parts[2]) || 0;
    }
    if (sectionLines.MEM && sectionLines.MEM.length >= 2) {
      const parts = sectionLines.MEM[1].split(/\s+/);
      data.ram_total = parseInt(parts[1], 10) || 0;
      data.ram_used = parseInt(parts[2], 10) || 0;
      data.ram_percent = data.ram_total
        ? Number(((data.ram_used / data.ram_total) * 100).toFixed(1))
        : 0;
    }
    if (sectionLines.DISK && sectionLines.DISK.length >= 2) {
      const parts = sectionLines.DISK[1].split(/\s+/);
      data.disk_total = parseInt(parts[1], 10) || 0;
      data.disk_used = parseInt(parts[2], 10) || 0;
      data.disk_percent = data.disk_total
        ? Number(((data.disk_used / data.disk_total) * 100).toFixed(1))
        : 0;
    }
    if (sectionLines.UPTIME && sectionLines.UPTIME.length > 0) {
      data.uptime = sectionLines.UPTIME[0].replace(/^up\s+/, '');
    }
    if (sectionLines.PROCS && sectionLines.PROCS.length > 0) {
      data.processes = sectionLines.PROCS.map((p) => {
        const segs = p.trim().split(/\s+/);
        return {
          pid: segs[0],
          cpu: segs[1] + '%',
          mem: segs[2] + '%',
          command: segs.slice(3).join(' ')
        };
      });
    }

    return data;
  }

  _getDefaultCatalog() {
    return {
      timestamp: Date.now(),
      provider: 'gcp',
      currency: 'USD',
      currencySymbol: '$',
      server_types: [
        {
          id: 'e2-micro',
          name: 'e2-micro',
          cores: 2,
          memory: 1,
          disk: 30,
          storageType: 'pd-standard',
          cpuType: 'shared',
          architecture: 'x86',
          currency: 'USD',
          currencySymbol: '$',
          priceHourlyNet: 0.0084,
          priceMonthlyNet: 6.11,
          description: '2 vCPU (burstable), 1 GB RAM, 30 GB Standard Disk'
        },
        {
          id: 'e2-small',
          name: 'e2-small',
          cores: 2,
          memory: 2,
          disk: 30,
          storageType: 'pd-standard',
          cpuType: 'shared',
          architecture: 'x86',
          currency: 'USD',
          currencySymbol: '$',
          priceHourlyNet: 0.0168,
          priceMonthlyNet: 12.23,
          description: '2 vCPU (burstable), 2 GB RAM, 30 GB Standard Disk'
        },
        {
          id: 'e2-medium',
          name: 'e2-medium',
          cores: 2,
          memory: 4,
          disk: 30,
          storageType: 'pd-standard',
          cpuType: 'shared',
          architecture: 'x86',
          currency: 'USD',
          currencySymbol: '$',
          priceHourlyNet: 0.0335,
          priceMonthlyNet: 24.46,
          description: '2 vCPU, 4 GB RAM, 30 GB Standard Disk'
        },
        {
          id: 'e2-standard-2',
          name: 'e2-standard-2',
          cores: 2,
          memory: 8,
          disk: 50,
          storageType: 'pd-standard',
          cpuType: 'dedicated',
          architecture: 'x86',
          currency: 'USD',
          currencySymbol: '$',
          priceHourlyNet: 0.0671,
          priceMonthlyNet: 48.92,
          description: '2 dedicated vCPUs, 8 GB RAM, 50 GB Standard Disk'
        },
        {
          id: 'e2-standard-4',
          name: 'e2-standard-4',
          cores: 4,
          memory: 16,
          disk: 100,
          storageType: 'pd-standard',
          cpuType: 'dedicated',
          architecture: 'x86',
          currency: 'USD',
          currencySymbol: '$',
          priceHourlyNet: 0.1341,
          priceMonthlyNet: 97.83,
          description: '4 dedicated vCPUs, 16 GB RAM, 100 GB Standard Disk'
        },
        {
          id: 't2a-standard-1',
          name: 't2a-standard-1',
          cores: 1,
          memory: 4,
          disk: 30,
          storageType: 'pd-standard',
          cpuType: 'shared',
          architecture: 'arm',
          currency: 'USD',
          currencySymbol: '$',
          priceHourlyNet: 0.0385,
          priceMonthlyNet: 28.11,
          description: 'Ampere Altra Arm64 1 vCPU, 4 GB RAM, 30 GB Standard Disk'
        }
      ],
      locations: [
        { id: 'us-central1-a', name: 'Iowa', country: 'US', flag: '🇺🇸', description: 'Council Bluffs, Iowa' },
        { id: 'us-east1-b', name: 'South Carolina', country: 'US', flag: '🇺🇸', description: 'Moncks Corner, South Carolina' },
        { id: 'us-west1-b', name: 'Oregon', country: 'US', flag: '🇺🇸', description: 'The Dalles, Oregon' },
        { id: 'europe-west1-b', name: 'Belgium', country: 'BE', flag: '🇧🇪', description: 'St. Ghislain, Belgium' },
        { id: 'europe-west3-a', name: 'Frankfurt', country: 'DE', flag: '🇩🇪', description: 'Frankfurt, Germany' },
        { id: 'asia-east1-a', name: 'Taiwan', country: 'TW', flag: '🇹🇼', description: 'Changhua County, Taiwan' },
        { id: 'asia-northeast1-a', name: 'Tokyo', country: 'JP', flag: '🇯🇵', description: 'Tokyo, Japan' }
      ],
      images: [
        { name: 'ubuntu-24.04', osFlavor: 'ubuntu', description: 'Ubuntu 24.04 LTS (Noble Numbat)' },
        { name: 'ubuntu-22.04', osFlavor: 'ubuntu', description: 'Ubuntu 22.04 LTS (Jammy Jellyfish)' },
        { name: 'debian-12', osFlavor: 'debian', description: 'Debian 12 (Bookworm)' },
        { name: 'rocky-linux-9', osFlavor: 'rocky', description: 'Rocky Linux 9' },
        { name: 'almalinux-9', osFlavor: 'almalinux', description: 'AlmaLinux 9' }
      ]
    };
  }

  async fetchCatalog() {
    // If configured, optionally query live machine types for the default zone
    if (this.isConfigured()) {
      try {
        const zone = this.getDefaultZone();
        const data = await this._request('GET', `/zones/${zone}/machineTypes`);
        const defaultCat = this._getDefaultCatalog();
        const liveTypes = (data.items || []).filter(t => ['e2-micro', 'e2-small', 'e2-medium', 'e2-standard-2', 'e2-standard-4', 't2a-standard-1'].includes(t.name));

        if (liveTypes.length > 0) {
          const mergedTypes = defaultCat.server_types.map(dt => {
            const liveMatch = liveTypes.find(lt => lt.name === dt.id);
            if (liveMatch) {
              return {
                ...dt,
                cores: liveMatch.guestCpus || dt.cores,
                memory: Math.round((liveMatch.memoryMb || 1024) / 1024)
              };
            }
            return dt;
          });
          return {
            ...defaultCat,
            timestamp: Date.now(),
            server_types: mergedTypes
          };
        }
      } catch (err) {
        // Fall back gracefully to curated catalog
      }
    }
    return this._getDefaultCatalog();
  }

  async getCatalog(forceRefresh = false) {
    const cacheFile = path.join(os.homedir(), '.config', 'ocloud', 'gcp_catalog.json');
    if (!forceRefresh && fs.existsSync(cacheFile)) {
      try {
        const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
        if (cached && (Date.now() - (cached.timestamp || 0) < 3600000)) {
          return cached;
        }
      } catch (e) {}
    }

    const cat = await this.fetchCatalog();
    try {
      fs.mkdirSync(path.dirname(cacheFile), { recursive: true });
      fs.writeFileSync(cacheFile, JSON.stringify(cat, null, 2), 'utf8');
    } catch (e) {}
    return cat;
  }
}

module.exports = GoogleComputeDriver;
