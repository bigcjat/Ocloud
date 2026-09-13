# 🛠️ Ocloud Plugin Development Guide (Human & LLM Specification)

This specification defines how to author, audit, and install plugins for Ocloud. Desktop LLMs and human developers must adhere to these schemas and zero-trust security rules.

---

## 1. Plugin Architecture Overview

Ocloud supports two categories of plugins:
1. **Storage Plugins (Pure JSON Manifest):**
   * Stored as a single file: `providers/plugins/storage/<id>.json` (or `~/.config/ocloud/plugins/storage/<id>.json`).
   * 100% declarative JSON. **No executable JavaScript allowed**.
   * Defines UI instructions, credential input fields, embedded vector SVG logo, and Rclone mapping.
2. **Compute Plugins (Directory Hybrid: Manifest + JS Driver):**
   * Stored as a directory: `providers/plugins/compute/<id>/` (or `~/.config/ocloud/plugins/compute/<id>/`).
   * `plugin.json`: Metadata, embedded vector SVG logo, allowed domains, and permission declarations.
   * `driver.js`: Node.js module extending `BaseComputeDriver`. Handles REST APIs, dynamic pricing catalogs, server lifecycle, and remote telemetry.

---

## 2. Manifest Specification (`plugin.json` or `<id>.json`)

Every plugin manifest must satisfy this JSON schema:

```json
{
  "id": "provider_id",
  "name": "Provider Display Name",
  "type": "compute",
  "driver": "driver.js",
  "badge": "Short Badge Text",
  "badgeColor": "#hex",
  "brandColor": "#hex",
  "tagline": "One-line marketing summary.",
  "description": "Detailed explanation of capabilities.",
  "pricingFrom": "€0.005 / hr",
  "dashboardUrl": "https://console.provider.com",
  "iconSvg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 48 48\">...</svg>",
  
  "allowedDomains": [
    "api.provider.com"
  ],
  
  "permissions": {
    "network": true,
    "ssh": true,
    "system_shell": false
  },
  
  "auth": {
    "type": "token",
    "fields": [
      {
        "key": "api_token",
        "label": "API Token",
        "placeholder": "Enter your API token",
        "type": "password",
        "required": true
      }
    ]
  }
}
```

### Manifest Field Rules:
1. **`iconSvg` (Mandatory):** Must be clean, self-contained vector SVG code.
   * **Rule:** Do NOT use `<script>`, `<iframe>`, `<foreignObject>`, or `on*` event handlers.
   * **Rule:** Visual geometry only (`<path>`, `<rect>`, `<circle>`, `<polygon>`).
2. **`allowedDomains` (Mandatory for Network Access):**
   * Array of exact domains (e.g. `["api.provider.com"]`), wildcards (e.g. `["*.provider-storage.com"]`), or dynamic user variables (e.g. `["{{host}}"]`).
   * **Rule:** Do NOT list unrelated secondary root domains. Multi-root declarations trigger a security warning.
3. **`permissions` (Mandatory):**
   * `network`: boolean (allow outbound HTTPS fetch).
   * `ssh`: boolean (allow remote SSH commands for telemetry).
   * `system_shell`: boolean (must always be `false`).

---

## 3. Storage Plugin Schema (Pure Declarative JSON)

For storage providers, no code is needed. Use this template:

```json
{
  "id": "my_storage",
  "name": "My Storage Provider",
  "type": "storage",
  "category": "cloud",
  "authType": "s3",
  "rcloneType": "s3",
  "defaultRemoteName": "mystorage",
  "defaultMount": "~/MyStorage",
  "badge": "S3 Compatible",
  "badgeColor": "#2563eb",
  "brandColor": "#2563eb",
  "tagline": "Secure S3-compatible cloud storage.",
  "dashboardUrl": "https://console.mystorage.com",
  "iconSvg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><rect width=\"20\" height=\"20\" rx=\"4\" fill=\"#2563eb\"/></svg>",
  "instructions": {
    "step1": "Log into your storage console and generate API keys.",
    "step2": "Enter your Endpoint URL, Access Key, and Secret Key below.",
    "step3": "Your files will automatically mount to ~/MyStorage."
  },
  "fields": [
    { "key": "endpoint", "label": "Endpoint URL", "placeholder": "https://s3.mystorage.com", "type": "text" },
    { "key": "bucket", "label": "Bucket Name", "placeholder": "my-bucket", "type": "text" },
    { "key": "access_key", "label": "Access Key ID", "placeholder": "AKIA...", "type": "text" },
    { "key": "secret_key", "label": "Secret Access Key", "placeholder": "...", "type": "password" }
  ],
  "allowedDomains": [
    "*.mystorage.com"
  ],
  "permissions": {
    "network": true,
    "rclone": true
  }
}
```

---

## 4. Compute Driver Specification (`driver.js`)

A compute driver must extend `BaseComputeDriver` and implement the following contract:

```javascript
const { BaseComputeDriver } = require('../../base');

const API_BASE = 'https://api.provider.com/v1';

class MyComputeDriver extends BaseComputeDriver {
  constructor(manifest, context = {}) {
    super(manifest);
    // Credentials are automatically scoped to this provider only
    this.credentials = context.credentials || context || {};
    this.saveCredentials = context.saveCredentials || null;
  }

  getToken() {
    return this.credentials.api_token || '';
  }

  isConfigured() {
    return Boolean(this.getToken());
  }

  // 1. Live Catalog Query with Hourly Pricing
  async fetchCatalog(options = {}) {
    const token = this.getToken();
    // Use standard fetch() - automatically restricted to allowedDomains
    const res = await fetch(`${API_BASE}/plans`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    const data = await res.json();

    return {
      timestamp: Date.now(),
      provider: this.manifest.id,
      server_types: [
        {
          id: 'vps-small',
          name: 'vps-small',
          description: '2 vCPU, 4GB RAM',
          cores: 2,
          memory: 4,
          disk: 50,
          storageType: 'nvme',
          cpuType: 'shared', // 'shared' or 'dedicated'
          architecture: 'x86', // 'x86' or 'arm'
          priceHourlyNet: 0.008, // Net price per hour
          priceMonthlyNet: 5.50
        }
      ],
      locations: [
        { id: 'sin', name: 'Singapore', country: 'SG', flag: '🇸🇬' },
        { id: 'fra', name: 'Frankfurt', country: 'DE', flag: '🇩🇪' }
      ],
      images: [
        { name: 'rocky-linux-9', osFlavor: 'rocky', description: 'Rocky Linux 9 (RHEL)' },
        { name: 'ubuntu-24.04', osFlavor: 'ubuntu', description: 'Ubuntu 24.04 LTS' }
      ]
    };
  }

  // 2. Server Management Lifecycle
  async listServers() {
    // Return array of { id, name, ip, status, serverType, location, hourlyRate }
    return [];
  }

  async createServer({ name, type, location, image, sshKey }) {
    // REST call to provision server
    // Return { id, name, ip, status: 'running' }
  }

  async powerAction(serverId, action) {
    // action: 'start' | 'stop' | 'reboot' | 'delete'
  }
}

module.exports = MyComputeDriver;
```

---

## 5. Zero-Trust Security Requirements

Before any plugin is activated, it is scanned by `security/plugin_auditor.js`. 

**The following will immediately cause your plugin to be QUARANTINED:**
* ❌ Using `eval()` or `new Function()`.
* ❌ Using `[].constructor.constructor()` or attempting prototype climbing.
* ❌ Importing `child_process` without declaring `"permissions": { "ssh": true }`.
* ❌ Making HTTP requests to any domain not declared in `allowedDomains`.
* ❌ Reading files like `~/.ssh/id_*`, `/etc/shadow`, or `vault.enc`.
* ❌ Placing `<script>` tags or inline `on*` event handlers inside the SVG.

---

## 6. How to Test & Install a Plugin

1. **Audit your plugin:**
   ```bash
   ocloud plugin audit <plugin_path>
   ```
2. **Install to user plugins directory:**
   ```bash
   mkdir -p ~/.config/ocloud/plugins/<id>
   cp plugin.json driver.js ~/.config/ocloud/plugins/<id>/
   ```
3. **Verify:**
   ```bash
   ocloud providers --security
   ```

---

## 7. SVG Logo Sourcing, Sanitization & Embedding Standard (Mandatory for Humans & LLMs)

Every plugin in Ocloud requires a crisp, authentic vector brand logo in `"iconSvg"`.
**LLMs and human contributors MUST follow this strict protocol. Never hand-draw or hallucinate SVG path coordinates.**

### Step 1: Sourcing Authentic Official Vectors
1. **Never Hallucinate:** Never write or guess SVG `<path d="...">` coordinates by hand.
2. **Primary Source (Simple Icons — Cloud Providers & Operating Systems):**
   * Use **Simple Icons** ([simpleicons.org](https://simpleicons.org) / [github.com/simple-icons/simple-icons](https://github.com/simple-icons/simple-icons)) as the primary, authoritative source for all cloud infrastructure providers (e.g., Hetzner, Google Cloud, AWS, DigitalOcean, Scaleway, Vultr, Linode, OVHcloud, Cloudflare, Backblaze) and Linux operating system distributions (Ubuntu, Debian, Fedora, Arch Linux, Alpine Linux, Rocky Linux, AlmaLinux, CentOS, openSUSE, etc.).
   * **Why Simple Icons is mandatory for LLMs:**
     - **Normalized Geometry:** All icons are pre-fitted to a clean `viewBox="0 0 24 24"`.
     - **Clean Single Paths:** Icons are usually defined by a single, clean `<path d="..."/>` with zero XML bloat, font dependencies, or inline CSS.
     - **Audit-Ready:** 100% free of JavaScript `<script>` tags, event handlers, or `<foreignObject>` elements.
     - **Official Brand Colors:** Each icon entry in Simple Icons provides the exact verified brand hex color (e.g., `#D50C2D` for Hetzner, `#4285F4` for Google Cloud, `#0080FF` for DigitalOcean, `#E95420` for Ubuntu, `#A81D33` for Debian).
   * **Direct Vector URLs for LLMs & Fetch Scripts:**
     - GitHub Raw: `https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/<slug>.svg`
     - CDN: `https://unpkg.com/simple-icons/icons/<slug>.svg`
   * **Common Provider & Distro Slugs:**
     | Entity | Simple Icons Slug | Official Brand Color |
     | :--- | :--- | :--- |
     | **Hetzner** | `hetzner` | `#D50C2D` |
     | **Google Cloud** | `googlecloud` | `#4285F4` |
     | **AWS** | `amazonaws` | `#232F3E` |
     | **DigitalOcean** | `digitalocean` | `#0080FF` |
     | **Vultr** | `vultr` | `#007BFC` |
     | **Linode / Akamai** | `linode` | `#00A95C` |
     | **Scaleway** | `scaleway` | `#4F0599` |
     | **Cloudflare** | `cloudflare` | `#F38020` |
     | **Backblaze** | `backblaze` | `#E01E2E` |
     | **Ubuntu** | `ubuntu` | `#E95420` |
     | **Debian** | `debian` | `#A81D33` |
     | **Alpine Linux** | `alpinelinux` | `#0D597F` |
     | **Arch Linux** | `archlinux` | `#1793D1` |
     | **Rocky Linux** | `rockylinux` | `#10B981` |
     | **AlmaLinux** | `almalinux` | `#0F4266` |
     | **Fedora** | `fedora` | `#51A2DA` |
3. **Secondary Source (Wikimedia Commons — Multi-Color Vectors):**
   * Search Wikimedia Commons (e.g., `File:<Brand> logo.svg`) when a multi-color vector brand emblem is strictly preferred (such as the 4-color Google Cloud emblem).
4. **Tertiary Source (Official Press Kits / Brand Portals):**
   * Download the official SVG directly from the company's press kit, brand portal, or developer documentation.

### Step 2: Emblem Isolation (Removing Wordmarks)
* If the official SVG contains wordmark text underneath or next to the emblem (e.g., the word "pcloud" underneath the cloud emblem), **strip the text elements/paths**.
* The icon should contain only the recognizable brand emblem/symbol so it renders sharply and legibly at 24px–48px inside the modal grid and status cards.

### Step 3: Minification & Sanitization with SVGO / SVGOMG

> [!IMPORTANT]
> **SVGO v3/v4 Syntax Notice:** Modern SVGO removed the legacy `--enable=...` and `--disable=...` flags. Configuration is managed via `svgo.config.js`.

#### Method A: Using the Repository's Built-In SVGO Config (Recommended)
This repository includes `svgo.config.js` with `multipass: true`, `preset-default`, `removeDimensions`, and `removeScripts`. Simply run:
```bash
# Optimize a single SVG file:
npx -y svgo -i raw_brand.svg -o app/ui/icons/<brand>.svg

# Optimize an entire directory:
npx -y svgo -f app/ui/icons/
```

#### Method B: Batch Optimizing Standalone & Embedded Plugin SVGs
To optimize all `.svg` files in `app/ui/icons/` AND all embedded `"iconSvg"` strings across all plugin manifests in `providers/plugins/` simultaneously:
```bash
node tools/optimize_all_svgs.js
```

#### Method C: Zero-Config One-Liner (Outside this Repo)
If you are generating a plugin in an isolated environment without `svgo.config.js`:
```bash
npx -y svgo -i input.svg -o output.min.svg --multipass -p 3
```

#### Method D: Web GUI (SVGOMG)
If using Jake Archibald's [SVGOMG Web Interface](https://jakearchibald.github.io/svgomg/):
1. Paste or upload the raw SVG.
2. In the right-hand settings panel:
   * **Prefer viewBox to width/height:** ON (strips hardcoded px dimensions).
   * **Remove scripts:** ON (zero-trust sanitization).
   * **Remove metadata & comments:** ON.
   * **Round/rewrite paths:** ON.
3. Click **Copy as text** or **Download**.

### Step 4: Embedding into Plugin JSON
1. Ensure the SVG string starts with `<svg ...>` and ends with `</svg>`.
2. Escape all internal double quotes (`"`) with `\"` for valid JSON:
   ```json
   "iconSvg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 43\"><path fill=\"#1EBCC5\" d=\"...\"/></svg>"
   ```
3. Run the security auditor to confirm compliance:
   ```bash
   node security/plugin_auditor.js providers/plugins/<id>.json
   ```


