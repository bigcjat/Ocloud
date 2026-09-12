# ☁ Ocloud

**The Sovereign Cloud Companion for Omarchy (and Linux).**

[https://github.com/bigcjat/Ocloud](https://github.com/bigcjat/Ocloud)

Ocloud bridges personal cloud storage and on-demand cloud compute directly into your desktop environment. It gives you the seamlessness of iCloud—cloud drive mounting, automated encrypted backups, and background compute—without proprietary lock-in, monthly surveillance, or Big Tech bloat.

---

## Architecture & Provider Roadmap

Ocloud is built with a **modular provider architecture**. While **Hetzner** is the initial first-class reference implementation, Ocloud is designed to plug into any cloud infrastructure or self-hosted homelab.

```
                    ┌─────────────────────────┐
                    │      Ocloud Core        │
                    │   (CLI + Omarchy Shell) │
                    └────────────┬────────────┘
                                 │
           ┌─────────────────────┴─────────────────────┐
           ▼                                           ▼
┌──────────────────────┐                   ┌──────────────────────┐
│   Storage Providers  │                   │   Compute Providers  │
├──────────────────────┤                   ├──────────────────────┤
│ • Hetzner Storage Box│                   │ • Hetzner Cloud VMs  │
│ • Backblaze B2 [next]│                   │ • Scaleway     [next]│
│ • S3 / MinIO   [next]│                   │ • DigitalOcean [next]│
│ • rsync.net    [next]│                   │ • Proxmox Homelab    │
└──────────────────────┘                   └──────────────────────┘
```

---

## Core Capabilities

### 1. Cloud Storage Engine
* **Virtual Cloud Drive (`~/Cloud`)**: Mounts your remote storage locally with full VFS caching. Drag-and-drop 100GB files without consuming local disk space.
* **Encrypted Snapshots**: Client-side encrypted, deduplicated background backups (Restic/Borg). Even your cloud provider cannot read your data.

### 2. Disposable & Always-On Cloud Compute
* **Offload Builds & Heavy Jobs**: Compile large projects or run batch tasks on beefy multi-core cloud instances while your laptop stays cold and preserves battery.
* **Native Desktop Window Streaming**: Run graphical apps or games on the remote cloud VM and stream them directly into your local Hyprland workspace via **Waypipe** or X11 forwarding—tiling and resizing like a local app.
* **Tailscale Mesh Integration**: Automatically enrolls newly spawned cloud VMs into your private Tailnet on first boot using ephemeral auth keys. No open SSH ports on the public internet.

### 3. Native Omarchy Top-Bar Widget
* Powered by Quickshell (Qt Quick / QML) to seamlessly match Omarchy’s aesthetics and themes.
* Real-time storage capacity gauge and VM power status in the top bar.
* One-click terminal access, app launcher, and VM power controls.

---

## Quick Start

### 1. Installation

Clone the repository:
```bash
git clone https://github.com/bigcjat/Ocloud.git
cd Ocloud
```

Make `ocloud` available on your PATH:
```bash
mkdir -p ~/.local/bin
ln -sf "$(pwd)/ocloud" ~/.local/bin/ocloud
```

### 2. Configuration

Create your configuration at `~/.config/omarchy/ocloud.json` (or `~/.config/omarchy/hetzner.json`):

```json
{
  "provider": "hetzner",
  "api_token": "YOUR_CLOUD_API_TOKEN",
  "tailscale_auth_key": "",
  "storage_box": {
    "username": "uXXXXXX",
    "host": "uXXXXXX.your-storagebox.de",
    "port": 23,
    "mount_point": "~/Cloud",
    "backup_source": "~"
  },
  "default_vm_type": "cx23",
  "default_location": "nbg1"
}
```

*Note: Your credentials are kept 100% local on your machine and are never tracked by Git.*

---

## CLI Reference (`ocloud`)

### Status Overview
```bash
# Formatted dashboard
ocloud status

# Raw JSON (used by the Omarchy top bar)
ocloud status --json

# Run in simulated mock mode
ocloud --mock status
```

### Cloud Compute (VMs)
```bash
# List all active cloud machines
ocloud vm list

# Create a new server (e.g. cx23 2-core Intel in Nuremberg)
ocloud vm create runner-01 --type cx23 --location nbg1

# Inspect live CPU, RAM, NVMe disk, and active processes
ocloud vm inspect runner-01

# Launch a remote GUI app or game as a native window
ocloud vm app runner-01 /path/to/game

# Connect server to Tailnet
ocloud vm tailscale runner-01 --key tskey-auth-XXXX

# Power controls
ocloud vm start runner-01
ocloud vm stop runner-01
ocloud vm reboot runner-01
ocloud vm ssh runner-01
```

### Cloud Storage
```bash
# Check quota and mount state
ocloud storage status

# Mount virtual drive to ~/Cloud
ocloud storage mount

# Unmount drive
ocloud storage unmount
```

### Automated Backups
```bash
# Trigger immediate incremental snapshot
ocloud backup run

# View last snapshot info
ocloud backup status
```

---

## Installing the Omarchy Top-Bar Plugin

To load the widget into your Omarchy desktop shell:

```bash
mkdir -p ~/.config/omarchy/plugins
ln -s "$(pwd)/plugin" ~/.config/omarchy/plugins/community.ocloud
omarchy-shell shell rescanPlugins
```

---

## License

MIT
