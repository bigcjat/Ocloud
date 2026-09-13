const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { BaseComputeDriver } = require('../../../base');

const API_BASE = 'https://api.hetzner.cloud/v1';

class HetznerComputeDriver extends BaseComputeDriver {
  constructor(manifest, context = {}) {
    super(manifest);
    if (context && typeof context.get === 'function') {
      this.credentials = {
        api_token: context.get('api_token', ''),
        tailscale_auth_key: context.get('tailscale_auth_key', '')
      };
    } else if (context && context.credentials) {
      this.credentials = context.credentials;
      this.saveCredentials = context.saveCredentials;
    } else {
      this.credentials = context || {};
    }
  }

  getToken() {
    return (this.credentials && this.credentials.api_token) || process.env.HETZNER_API_TOKEN || '';
  }

  getTailscaleKey() {
    return (this.credentials && this.credentials.tailscale_auth_key) || '';
  }

  isConfigured() {
    return Boolean(this.getToken());
  }

  async _request(method, endpoint, body = null) {
    const token = this.getToken();
    if (!token) throw new Error('Hetzner API token is missing in Ocloud Vault.');
    const res = await fetch(`${API_BASE}${endpoint}`, {
      method,
      headers: {
        Authorization: `Bearer ${token.trim()}`,
        'Content-Type': 'application/json',
        'User-Agent': 'Ocloud/1.0'
      },
      body: body ? JSON.stringify(body) : undefined
    });
    const text = await res.text();
    let json = {};
    try {
      json = text ? JSON.parse(text) : {};
    } catch (e) {}

    if (!res.ok) {
      const msg = json.error?.message || `HTTP ${res.status}: ${res.statusText}`;
      throw new Error(msg);
    }
    return json;
  }

  async verifyCredentials() {
    if (!this.isConfigured()) {
      return { ok: false, error: 'Hetzner Cloud API token is missing in Ocloud Vault.' };
    }
    try {
      await this._request('GET', '/servers?per_page=1');
      return { ok: true };
    } catch (err) {
      return { ok: false, error: err.message || 'Hetzner API token verification failed.' };
    }
  }

  async listServers() {
    const token = this.getToken();
    if (!token) return [];
    try {
      const data = await this._request('GET', '/servers');
      return (data.servers || []).map((s) => {
        const loc = s.datacenter?.location?.name || 'nbg1';
        const priceObj = (s.server_type?.prices || []).find((p) => p.location === loc) || (s.server_type?.prices || [])[0];
        const priceHourly = priceObj ? parseFloat(priceObj.price_hourly?.net || priceObj.price_hourly?.gross || '0.0058') : 0.0058;
        const priceMonthly = priceObj ? parseFloat(priceObj.price_monthly?.net || priceObj.price_monthly?.gross || '3.65') : 3.65;
        return {
          id: s.id,
          name: s.name,
          status: s.status,
          type: s.server_type?.name || 'cx23',
          ipv4: s.public_net?.ipv4?.ip || 'no IP',
          location: loc,
          provider: 'hetzner',
          providerName: 'Hetzner Cloud',
          providerIcon: this.manifest ? this.manifest.iconDataUri : null,
          datacenter: s.datacenter?.name,
          created: s.created,
          tags: ['cloud', 'hetzner'],
          isHomeWorkstation: false,
          priceHourly,
          priceMonthly,
          currency: 'EUR',
          currencySymbol: '€'
        };
      });
    } catch (err) {
      console.error(`[Hetzner Driver] Failed to list servers: ${err.message}`);
      return [];
    }
  }

  async createServer({ name, type = 'cx23', location = 'nbg1', tailscaleKey = null, sshKeys = ['omarchy-laptop'], image = 'ubuntu-24.04' }) {
    const tsKey = tailscaleKey || this.getTailscaleKey();
    const userData = `#!/bin/bash
# Install fastfetch and configure for SSH login
if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm fastfetch
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y && apt-get install -y fastfetch || (curl -fsSL https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-amd64.deb -o /tmp/ff.deb && dpkg -i /tmp/ff.deb)
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

    const payload = {
      name,
      server_type: type,
      location,
      image: image || 'ubuntu-24.04',
      start_after_create: true,
      ssh_keys: sshKeys,
      user_data: userData
    };

    const res = await this._request('POST', '/servers', payload);
    return res.server;
  }

  async startServer(id) {
    return this._request('POST', `/servers/${id}/actions/poweron`);
  }

  async stopServer(id) {
    return this._request('POST', `/servers/${id}/actions/poweroff`);
  }

  async rebootServer(id) {
    return this._request('POST', `/servers/${id}/actions/reboot`);
  }

  async deleteServer(id) {
    return this._request('DELETE', `/servers/${id}`);
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

  async fetchCatalog() {
    const [typesRes, locsRes, imgsRes] = await Promise.all([
      this._request('GET', '/server_types'),
      this._request('GET', '/locations'),
      this._request('GET', '/images?type=system')
    ]);

    const activeTypes = (typesRes.server_types || []).filter(t => !t.deprecated);
    const serverTypes = activeTypes.map(t => {
      const priceMap = {};
      let defaultPrice = { monthly_net: 0, hourly_net: 0, monthly_gross: 0, hourly_gross: 0 };
      if (Array.isArray(t.prices)) {
        t.prices.forEach(p => {
          const mNet = parseFloat(p.price_monthly?.net || 0);
          const hNet = parseFloat(p.price_hourly?.net || 0);
          const mGross = parseFloat(p.price_monthly?.gross || 0);
          const hGross = parseFloat(p.price_hourly?.gross || 0);
          priceMap[p.location] = {
            monthly_net: mNet,
            hourly_net: hNet,
            monthly_gross: mGross,
            hourly_gross: hGross
          };
          if (p.location === 'fsn1' || p.location === 'nbg1' || defaultPrice.monthly_net === 0) {
            defaultPrice = priceMap[p.location];
          }
        });
      }

      return {
        id: t.name,
        name: t.name,
        description: t.description,
        cores: t.cores,
        memory: t.memory,
        disk: t.disk,
        storageType: t.storage_type || 'local',
        cpuType: t.cpu_type || 'shared',
        architecture: t.architecture || 'x86',
        priceMonthlyNet: defaultPrice.monthly_net,
        priceHourlyNet: defaultPrice.hourly_net,
        prices: priceMap
      };
    });

    const locations = (locsRes.locations || []).map(l => ({
      id: l.name,
      locId: l.id,
      name: l.city,
      description: l.description,
      country: l.country,
      networkZone: l.network_zone,
      flag: l.country === 'DE' ? '🇩🇪' : (l.country === 'FI' ? '🇫🇮' : (l.country === 'US' ? '🇺🇸' : (l.country === 'SG' ? '🇸🇬' : '🌐')))
    }));

    const images = (imgsRes.images || []).map(img => ({
      name: img.name,
      osFlavor: img.os_flavor,
      description: img.description,
      architecture: img.architecture
    }));

    const catalog = {
      timestamp: Date.now(),
      provider: 'hetzner',
      server_types: serverTypes,
      locations: locations,
      images: images
    };

    const cacheFile = path.join(os.homedir(), '.config', 'ocloud', 'hetzner_catalog.json');
    try {
      fs.mkdirSync(path.dirname(cacheFile), { recursive: true });
      fs.writeFileSync(cacheFile, JSON.stringify(catalog, null, 2), 'utf8');
    } catch (e) {}

    return catalog;
  }

  _getDefaultCatalog() {
    return {
      timestamp: Date.now(),
      provider: 'hetzner',
      server_types: [
        { id: 'cx22', name: 'cx22', cores: 2, memory: 4, disk: 40, cpuType: 'shared', architecture: 'x86', priceHourlyNet: 0.0056, priceMonthlyNet: 3.49 },
        { id: 'cx23', name: 'cx23', cores: 2, memory: 4, disk: 40, cpuType: 'shared', architecture: 'x86', priceHourlyNet: 0.0058, priceMonthlyNet: 3.65 },
        { id: 'cax11', name: 'cax11', cores: 2, memory: 4, disk: 40, cpuType: 'shared', architecture: 'arm', priceHourlyNet: 0.0053, priceMonthlyNet: 3.29 },
        { id: 'cax21', name: 'cax21', cores: 4, memory: 8, disk: 80, cpuType: 'shared', architecture: 'arm', priceHourlyNet: 0.0098, priceMonthlyNet: 6.10 },
        { id: 'ccx13', name: 'ccx13', cores: 2, memory: 8, disk: 80, cpuType: 'dedicated', architecture: 'x86', priceHourlyNet: 0.024, priceMonthlyNet: 14.90 },
        { id: 'ccx23', name: 'ccx23', cores: 4, memory: 16, disk: 160, cpuType: 'dedicated', architecture: 'x86', priceHourlyNet: 0.048, priceMonthlyNet: 29.80 }
      ],
      locations: [
        { id: 'nbg1', name: 'Nuremberg', country: 'DE', flag: '🇩🇪' },
        { id: 'fsn1', name: 'Falkenstein', country: 'DE', flag: '🇩🇪' },
        { id: 'hel1', name: 'Helsinki', country: 'FI', flag: '🇫🇮' },
        { id: 'ash', name: 'Ashburn', country: 'US', flag: '🇺🇸' },
        { id: 'sin', name: 'Singapore', country: 'SG', flag: '🇸🇬' }
      ],
      images: [
        { name: 'ubuntu-24.04', osFlavor: 'ubuntu', description: 'Ubuntu 24.04 LTS' },
        { name: 'debian-12', osFlavor: 'debian', description: 'Debian 12' },
        { name: 'rocky-linux-9', osFlavor: 'rocky', description: 'Rocky Linux 9 (RHEL Compatible)' },
        { name: 'almalinux-9', osFlavor: 'almalinux', description: 'AlmaLinux 9 (RHEL Compatible)' },
        { name: 'fedora-40', osFlavor: 'fedora', description: 'Fedora 40' }
      ]
    };
  }

  async getCatalog(forceRefresh = false) {
    const cacheFile = path.join(os.homedir(), '.config', 'ocloud', 'hetzner_catalog.json');
    if (!forceRefresh && fs.existsSync(cacheFile)) {
      try {
        const cached = JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
        if (cached && (Date.now() - (cached.timestamp || 0) < 3600000)) {
          return cached;
        }
      } catch (e) {}
    }
    try {
      return await this.fetchCatalog();
    } catch (err) {
      if (fs.existsSync(cacheFile)) {
        try {
          return JSON.parse(fs.readFileSync(cacheFile, 'utf8'));
        } catch (e) {}
      }
      return this._getDefaultCatalog();
    }
  }
}

module.exports = HetznerComputeDriver;
