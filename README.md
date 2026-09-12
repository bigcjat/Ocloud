# ☁ Hetzner Cloud & Storage Companion for Omarchy (and macOS)

A native, zero-dependency desktop integration for [Hetzner](https://www.hetzner.com/) designed for **Omarchy** and **macOS**. It provides:

1. **Storage Box Cloud Drive & Backups**: Attach your Hetzner Storage Box as a native virtual folder (`~/Cloud`) and run automated, client-side encrypted snapshots.
2. **Cloud Compute Companion (VMs)**: Manage always-on remote compute, offload heavy builds, run 24/7 background jobs, or spin up on-demand x86/ARM cloud servers with one command.
3. **Omarchy Top-Bar Widget**: A native Quickshell (Qt Quick / QML) widget that sits in your top bar, monitors your storage and VM status in real time, and provides one-click terminal access and power controls.

---

## Quick Start

### 1. Configuration

The configuration file is stored at `~/.config/omarchy/hetzner.json` (or `./config.json`):

```json
{
  "api_token": "YOUR_HETZNER_CLOUD_API_TOKEN",
  "storage_box": {
    "username": "u123456",
    "host": "u123456.your-storagebox.de",
    "port": 23,
    "mount_point": "~/Cloud",
    "backup_source": "~"
  },
  "default_vm_type": "cx22",
  "default_location": "nbg1"
}
```

*Permissions note: The file is protected with `chmod 600`.*

---

## CLI Usage (`hetz`)

The `hetz` CLI is built in Python 3 with **zero third-party dependencies** (uses standard library only) and works natively on Linux and macOS.

### Status Overview
```bash
# Formatted human-readable overview
./hetz status

# Raw JSON output (used by the Omarchy top-bar widget)
./hetz status --json

# Run in simulated mock mode without credentials
./hetz --mock status
```

### Cloud VM Management
```bash
# List all active cloud servers
./hetz vm list

# Create a new server (cx22: 2 vCPU Intel, 4GB RAM, 40GB NVMe in Nuremberg)
./hetz vm create my-companion-server --type cx22 --location nbg1

# Start / Stop / Reboot a server
./hetz vm start <server-id-or-name>
./hetz vm stop <server-id-or-name>
./hetz vm reboot <server-id-or-name>

# Direct SSH into the server
./hetz vm ssh <server-id-or-name>
```

### Storage Box & Drive Mount
```bash
# Check Storage Box quota and mount status
./hetz storage status

# Mount Storage Box to ~/Cloud (uses rclone or sshfs)
./hetz storage mount

# Unmount ~/Cloud
./hetz storage unmount
```

### Automated Backups
```bash
# Trigger an encrypted incremental backup
./hetz backup run

# View last backup timestamp and status
./hetz backup status
```

---

## Installing the Omarchy Top-Bar Plugin

To link the plugin into your Omarchy desktop shell:

```bash
# 1. Symlink the plugin folder into your Omarchy plugins directory:
mkdir -p ~/.config/omarchy/plugins
ln -s "$(pwd)/plugin" ~/.config/omarchy/plugins/community.hetzner

# 2. Tell the Omarchy shell to rescan plugins:
omarchy-shell shell rescanPlugins
```

The Hetzner widget will appear in the top bar, displaying your current Storage Box capacity and live VM status. Left-clicking opens the companion panel; right-clicking triggers instant quick actions.
