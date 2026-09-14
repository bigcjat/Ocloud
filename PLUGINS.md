# 🔌 Ocloud Plugin Inventory & Roadmap

This document is the official tracking manifest for all **Compute** and **Storage** plugins in Ocloud. It details which plugins have been verified end-to-end in production, which plugins exist in code but need live account verification, and which plugins are slated for development.

---

## Quick Summary

| Category | Fully Tested & Working | Created & Awaiting Live Test | Planned / Need To Be Made |
| :--- | :--- | :--- | :--- |
| **Compute Providers** | **3** (`hetzner`, `gcp`, `custom_server`) | **0** | **7** (`vultr`, `digitalocean`, `linode`, `scaleway`, `oracle_cloud`, `aws_lightsail`, `proxmox`) |
| **Storage Providers** | **6** (`hetzner_storage_box`, `cloudflare_r2`, `google_drive`, `onedrive`, `dropbox`, `pcloud`) | **4** (`aws_s3`, `backblaze_b2`, `nextcloud`, `icedrive`) | **7** (`wasabi`, `minio`, `box`, `mega`, `proton_drive`, `generic_sftp`, `generic_webdav`) |
| **Total** | **9 Verified** | **4 Unverified** | **14 Planned** |

> [!NOTE]
> **SVG Logo Sourcing Requirement:** When adding new plugins, follow the [SVG Logo Sourcing & Sanitization Standard](file:///Users/christhompson/macos_wrap/docs/PLUGIN_DEVELOPMENT_GUIDE.md#7-svg-logo-sourcing-sanitization--embedding-standard-mandatory-for-humans--llms). Do not hand-draw SVGs; source official vectors directly from **Simple Icons** (`https://simpleicons.org` / `https://github.com/simple-icons/simple-icons`) or Wikimedia Commons and minify via SVGOMG/SVGO.

---

## 1. Fully Tested & Working Plugins

These plugins are completely implemented, decoupled from core code, and verified live on actual cloud accounts and hardware.

### Compute

#### `hetzner`
* **Path:** `providers/plugins/compute/hetzner/` (`plugin.json` + `driver.js`)
* **Type:** Cloud Compute Provider
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Live Hetzner Cloud REST API integration (`https://api.hetzner.cloud/v1`).
  * Dynamic pricing catalog fetched and cached with hourly billing (`/hr`) as primary display.
  * Real-time server provisioning (`cx22`, `cx23`, `cax11`, etc.) across multiple datacenters (`fsn1`, `nbg1`, `hel1`, `ash`, `hil`).
  * Real-time server power state management (power on, graceful shutdown, hard poweroff, reboot, rebuild, delete).
  * Automated SSH key injection and ephemeral Tailnet enrollment.
  * Native Wayland desktop application streaming via **Waypipe** (verified on live VM `167.233.151.104`).
  * Embedded vector SVG brand logo.

#### `gcp`
* **Path:** `providers/plugins/compute/gcp/` (`plugin.json` + `driver.js`)
* **Type:** Cloud Compute Provider (Google Cloud Platform)
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Zero-dependency Google Service Account RS256 JWT auth token signing using Node.js native `crypto`.
  * Compute Engine API v1 integration (`https://compute.googleapis.com/compute/v1`).
  * Dynamic machine type catalog with honest hourly-first pricing (`$0.0084/hr ($6.11/mo)` for `e2-micro`).
  * Multi-region datacenter zones (`us-central1-a`, `us-east1-b`, `us-west1-b`, `europe-west3-c`, etc.).
  * Dynamic OS distribution catalog binding directly to official GCE public image families (`ubuntu-2404-lts`, `ubuntu-2204-lts`, `debian-12`, `rocky-linux-9`, `almalinux-9`).
  * Strict `pd-standard` (Standard Persistent Disk) 30 GB provisioning to guarantee Free Tier compliance.
  * Real-time server power management (start, stop, reset, delete).
  * SSH key injection, Tailscale mesh network enrollment, and live telemetry inspection.
  * Embedded vector SVG brand logo.

#### `custom_server`
* **Path:** `providers/plugins/compute/custom_server/` (`plugin.json` + `driver.js`)
* **Type:** Custom Bare-Metal / Self-Hosted Server
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Direct SSH remote node management.
  * Real-time host telemetry (CPU load, memory utilization, disk space, active processes) gathered non-intrusively via standard Unix commands over SSH.
  * Remote task/process inspection and termination.
  * Embedded vector SVG server icon.

---

### Storage

#### `hetzner_storage_box`
* **Path:** `providers/plugins/storage/hetzner_storage_box/` (`plugin.json` + `driver.js`)
* **Type:** Dedicated Cloud Storage Box (SFTP / WebDAV)
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Automated Rclone remote creation (`sftp` / `webdav` protocols).
  * VFS caching mount to local directory (`~/Cloud`).
  * Dynamic quota and capacity checking via SSH subsystem (`df -h`).
  * Client-side encrypted backup target integration (Restic).
  * Embedded vector SVG brand logo.

#### `cloudflare_r2`
* **Path:** `providers/plugins/storage/cloudflare_r2.json`
* **Type:** S3-Compatible Object Storage
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * S3 protocol authentication using Account ID, Access Key ID, and Secret Access Key.
  * Automated Rclone S3 remote generation pointing to `https://<account_id>.r2.cloudflarestorage.com`.
  * Local drive mounting (e.g. `~/R2`) with file synchronization.
  * Embedded vector SVG brand logo.

#### `google_drive`
* **Path:** `providers/plugins/storage/google_drive.json`
* **Type:** Consumer / Workspace Cloud Storage
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Rclone OAuth2 browser flow for authentication.
  * Virtual drive mount to `~/GoogleDrive`.
  * Bi-directional file synchronization and quota detection.
  * Embedded vector SVG brand logo.

#### `onedrive`
* **Path:** `providers/plugins/storage/onedrive.json`
* **Type:** Microsoft 365 Personal / Business Cloud Storage
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Rclone Microsoft Graph OAuth authentication.
  * Virtual drive mount to `~/OneDrive`.
  * File transfer and VFS caching.
  * Embedded vector SVG brand logo.

#### `dropbox`
* **Path:** `providers/plugins/storage/dropbox.json`
* **Type:** Consumer / Team Cloud Storage
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Rclone OAuth authentication workflow.
  * Virtual drive mount to `~/Dropbox`.
  * Embedded vector SVG brand logo.

#### `pcloud`
* **Path:** `providers/plugins/storage/pcloud.json`
* **Type:** Consumer Cloud Storage (Multi-Protocol)
* **Status:**  **Production Tested & Verified**
* **Capabilities Tested:**
  * Multi-method connection wizard (OAuth US, OAuth EU, WebDAV Gateway, Linux App client).
  * Sanitized official pCloud vector SVG emblem (`#1EBCC5` cyan cloud + white P emblem).
  * Regional endpoint mapping (`api.pcloud.com` vs `eapi.pcloud.com`).
  * Direct WebDAV encrypted HTTPS mounting with user credentials.
  * Local drive mount to `~/pCloud`.

---

## 2. Implemented Plugins Awaiting Live Account Test

These plugins have complete JSON manifests, embedded SVGs, credential schema definitions, and Rclone generation routines, but have **not yet been connected to an active account with real credentials** to verify edge cases.

### Storage

#### `aws_s3.json`
* **Path:** `providers/plugins/storage/aws_s3.json`
* **Type:** Amazon Web Services Simple Storage Service (S3)
* **Status:** ⏳ **Manifest Implemented — Awaiting Live AWS Account Test**
* **What is ready:**
  * JSON manifest with embedded AWS SVG logo.
  * Parameter schema for Access Key ID, Secret Access Key, Default Region (e.g. `us-east-1`, `eu-central-1`), and optional Bucket Name.
  * Rclone `s3` provider mapping.
* **What needs testing:**
  * Running an end-to-end credential link with an active AWS IAM user.
  * Validating IAM bucket policy error handling (e.g., restricted S3 buckets).

#### `backblaze_b2.json`
* **Path:** `providers/plugins/storage/backblaze_b2.json`
* **Type:** Backblaze B2 Cloud Storage
* **Status:** ⏳ **Manifest Implemented — Awaiting Live B2 Account Test**
* **What is ready:**
  * JSON manifest with embedded Backblaze SVG logo.
  * Parameter schema for Account ID / Key ID and Application Key.
  * Rclone `b2` type mapping.
* **What needs testing:**
  * Running an end-to-end credential link with an active Backblaze B2 Application Key.
  * Validating mount behavior with B2 API upload limits and chunk caching.

#### `nextcloud.json`
* **Path:** `providers/plugins/storage/nextcloud.json`
* **Type:** Self-Hosted / Managed Nextcloud WebDAV
* **Status:** ⏳ **Manifest Implemented — Awaiting Live Nextcloud Instance Test**
* **What is ready:**
  * JSON manifest with embedded Nextcloud SVG logo.
  * Parameter schema for WebDAV Server URL (`https://nextcloud.example.com/remote.php/dav/files/USER/`), Username, and App Password.
  * Rclone `webdav` type mapping (`vendor = nextcloud`).
* **What needs testing:**
  * Live test against a Nextcloud instance (self-hosted or managed).
  * Validating App Password authentication and subfolder mounting.

#### `icedrive.json`
* **Path:** `providers/plugins/storage/icedrive.json`
* **Type:** Icedrive Secure Cloud Storage (WebDAV)
* **Status:** ⏳ **Manifest Implemented — Awaiting Live Icedrive WebDAV Account Test**
* **What is ready:**
  * Clean vector SVG logo hand-drawn and sanitized against zero-trust standards.
  * WebDAV endpoint schema (`https://webdav.icedrive.io`), username (account email), and master WebDAV password.
  * Domain boundary restricted strictly to `webdav.icedrive.io`, `icedrive.net`, `icedrive.io`.
  * Virtual mount destination: `~/Icedrive`.
* **What needs testing:**
  * Running an end-to-end credential link with an active Icedrive Pro/Lite WebDAV key.
  * Verifying VFS directory listing and upload sync.

#### `storj.json`
* **Path:** `providers/plugins/storage/storj.json`
* **Type:** Storj DCS Decentralized Cloud Storage (S3 Compatible)
* **Status:** ⏳ **Manifest Implemented & Audited — Awaiting Live S3 Key Link**
* **What is ready:**
  * Clean vector SVG logo and canonical `#2683ff` Storj brand styling.
  * Standard S3 Gateway endpoint (`https://gateway.storjshare.io`), Access Key ID, Secret Access Key, and Bucket Name schema.
  * Passed zero-trust security audit (`./ocloud providers audit storj`).
  * Virtual mount destination: `~/Storj`.

---

## 3. Plugins That Need To Be Made Still

These providers have been requested or identified in the roadmap, but their manifests and driver code have not yet been written.

### Compute Providers To Build

| Provider ID | Name | Target API | Description & Planned Scope |
| :--- | :--- | :--- | :--- |
| `vultr` | Vultr | Vultr API v2 | High-performance worldwide cloud compute (Cloud Compute, High Frequency, Bare Metal). Support hourly billing, plan selection, and SSH key injection. |
| `digitalocean`| DigitalOcean | DigitalOcean v2 API | Standard Droplets, Basic & CPU-Optimized. Dynamic region/size catalog, SSH key injection, VPC selection. |
| `linode` | Linode / Akamai | Linode API v4 | Linode Compute instances (Nanode, Standard, Dedicated). Hourly pricing catalog, Linode regions (US, EU, AP). |
| `scaleway` | Scaleway | Scaleway Instances API | European cloud provider with cost-effective ARM & x86 instances. Paris, Amsterdam, and Warsaw zones. |
| `oracle_cloud`| Oracle Cloud (OCI)| OCI REST API | Focus on targeting OCI Always-Free Ampere A1 (up to 4 ARM OCPUs, 24GB RAM) and standard E2 micro instances. |
| `aws_lightsail`| AWS Lightsail | AWS Lightsail API | Simplified, flat-rate AWS virtual private servers with bundled bandwidth. |
| `proxmox` | Proxmox VE | Proxmox VE REST API | Local homelab hypervisor driver. Spin up, clone, and manage QEMU/KVM VMs or LXC containers directly from Ocloud desktop. |

### Storage Providers To Build

| Provider ID | Name | Protocol / Backend | Description & Planned Scope |
| :--- | :--- | :--- | :--- |
| `wasabi` | Wasabi Hot Cloud | S3 Compatible | Low-cost S3 object storage without egress fees. Simple Access Key + Secret + Region schema. |
| `minio` | MinIO | S3 Compatible | Self-hosted S3 object storage for homelab and private enterprise infrastructure. Custom endpoint URL + S3 keys. |
| `pcloud` | pCloud | pCloud OAuth / API | Secure cloud storage with European/US datacenter options. OAuth2 authorization flow. |
| `box` | Box.com | Box API / OAuth | Enterprise cloud storage. OAuth token generation and drive mounting. |
| `mega` | MEGA.nz | Mega API | End-to-end encrypted consumer storage. Email + password / encryption key auth. |
| `proton_drive`| Proton Drive | Proton WebDAV / Bridge | Privacy-focused Swiss cloud storage. |
| `generic_sftp`| Generic SFTP Server | SFTP (SSH) | Mount any Linux/Unix machine or NAS with an SSH account directly into `~/Cloud/<name>`. |
| `generic_webdav`| Generic WebDAV | WebDAV | Mount generic WebDAV servers (Synology, QNAP, ownCloud, Apache). |
| `rsync_net` | rsync.net | SFTP / ZFS | High-reliability offsite ZFS storage for backups and direct SFTP mounting. |

---

## 4. Plugin Architecture & Standards

All Ocloud plugins follow a strict decoupling contract. No provider-specific code, URLs, brand logos, or pricing numbers exist in the core application.

### Discovery Directories
Ocloud automatically discovers plugins recursively from two locations:
1. **Built-in System Plugins:** `providers/plugins/` (`compute/` and `storage/`)
2. **User Custom Plugins:** `~/.config/ocloud/plugins/` (`compute/` and `storage/`)

### Format Options
1. **Storage Plugin (Pure JSON):**
   * Single file: `providers/plugins/storage/<provider_id>.json`
   * Contains metadata, embedded SVG brand logo, connection instructions, parameter schema, and Rclone config mappings.
2. **Compute or Advanced Storage Plugin (Directory Hybrid):**
   * Directory: `providers/plugins/compute/<provider_id>/` or `providers/plugins/storage/<provider_id>/`
   * `plugin.json`: Metadata, embedded SVG, parameter schema, default pricing/catalog fallbacks.
   * `driver.js`: Node.js module extending `BaseComputeDriver` or `BaseStorageDriver` to handle dynamic REST API interactions, dynamic pricing catalogs, live provisioning, and telemetry.

### Embedded SVG Standard
All plugins **must** embed their brand logo directly as clean vector SVG code inside the manifest:
```json
{
  "id": "example_cloud",
  "name": "Example Cloud",
  "iconSvg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\">...</svg>"
}
```
The Ocloud registry automatically encodes this into `modelData.iconDataUri` (`data:image/svg+xml;base64,...`), allowing QML and web views to render crisp logos with zero external file dependencies or cache misses.
