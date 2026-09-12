# 🖥️ Remote Wayland App Streaming & Companion OS Reference Guide

This document captures architectural lessons, packaging quirks, and protocol configurations discovered while running high-fidelity graphical applications and game suites (e.g., PySide6 / QML, Qt6, Wayland) on remote cloud companion VMs (Ubuntu vs. Arch Linux) streaming to **Omarchy Linux (Hyprland + Quickshell)** via **Waypipe** and **PipeWire**.

---

## 1. Operating System Comparison: Ubuntu 24.04 vs. Arch Linux

| Dimension | Ubuntu 24.04 LTS | Arch Linux (Rolling) |
| :--- | :--- | :--- |
| **Waypipe Version** | `0.8.6` (Legacy C implementation) | `0.11.2` (Modern Rust rewrite) |
| **Compression & Codecs** | Basic LZ4; lacks modern video pipeline | LZ4, multi-level ZSTD, DMABUF, Video (H.264/VP9/AV1) |
| **PySide6 Package** | `python3-pyside6` | `pyside6` |
| **Qt Version** | Qt 6.4 - 6.6 (frozen) | Qt 6.8+ (latest upstream matching Omarchy 1:1) |
| **Pulse/PipeWire Tools** | `pulseaudio-utils` (`paplay`) | `pipewire-pulse`, `libpulse` |
| **Mesa & Vulkan Driver** | `mesa-vulkan-drivers` | `mesa`, `vulkan-swrast` (lavapipe), `vulkan-icd-loader` |
| **Companion Verdict** | Slower frame loop over WAN, older Waypipe features | **Recommended:** Matches Omarchy 1:1, full Waypipe 0.11.2 features |

---

## 2. Headless Qt6 / PySide6 / QML Missing Formats: SVGs & WebP

Headless minimal server images strip out GUI dependencies. When running modern QML launchers or apps:

### The Symptoms
- Application runs, but icons, vector logos, and buttons are missing or render as blank squares.
- Game covers and posters encoded in `.webp` or `.svg` fail silently.

### Root Cause
Qt 6 modularized image format loaders. Neither `pyside6` nor `qt6-base` includes SVG or WebP decoders by default.

### The Fix
* **Arch Linux:**
  ```bash
  pacman -Sy --noconfirm qt6-svg qt6-imageformats
  ```
* **Ubuntu / Debian:**
  ```bash
  apt-get install -y libqt6svg6 qt6-image-formats-plugins
  ```

To verify supported formats on the remote machine:
```bash
python3 -c "from PySide6.QtGui import QImageReader; print([bytes(f).decode() for f in QImageReader.supportedImageFormats()])"
# Output must include 'svg', 'svgz', 'webp'
```

---

## 3. Typography & Font Rendering (Fixing Tofu Squares: `□ □□□□`)

### The Symptoms
Every text label, title, or button renders as empty tofu boxes (`□ □□□□`).

### Root Cause
Cloud server templates contain **zero system fonts** in `/usr/share/fonts/`. Fontconfig has nothing to fall back to.

### The Fix
* **Arch Linux:**
  ```bash
  pacman -S --noconfirm noto-fonts noto-fonts-emoji ttf-dejavu ttf-jetbrains-mono cantarell-fonts
  ```
* **Ubuntu / Debian:**
  ```bash
  apt-get install -y fonts-noto-core fonts-noto-color-emoji fonts-dejavu-core fonts-jetbrains-mono
  ```

---

## 4. Headless GPU / Software Rasterization for Waypipe

When running on virtualized VPS instances without a dedicated GPU:

* **Waypipe 0.11.2 Vulkan requirement:** Waypipe attempts zero-copy DMABUF transfers via Vulkan. If no Vulkan driver exists, it will abort with:
  ```
  Failed to create Vulkan instance: Unable to find a Vulkan driver
  ```
* **The Fix:** Install Mesa software rasterization (lavapipe / llvmpipe):
  ```bash
  # Arch Linux
  pacman -S --noconfirm mesa vulkan-swrast vulkan-icd-loader
  ```
  Or pass `--no-gpu` to Waypipe if purely software SHM transfers are desired.

---

## 5. End-to-End Audio Tunneling (PipeWire / PulseAudio over SSH)

Streaming audio from a cloud VM back to the local desktop without running a dedicated streaming server:

### Step 1: Enable TCP Protocol on Local Omarchy PipeWire
Load the PulseAudio TCP module bound strictly to localhost:
```bash
pactl load-module module-native-protocol-tcp port=4713 listen=127.0.0.1 auth-anonymous=1
```

### Step 2: Forward Remote Audio via SSH Reverse Tunnel
Add `-R 4713:localhost:4713` to your SSH or Waypipe connection command.

### Step 3: Configure Cloud VM Audio Routing
Set system-wide defaults on the remote VM so **any** binary (PulseAudio, ALSA, or PipeWire) routes through the tunnel:

1. **PulseAudio Client (`/etc/pulse/client.conf`):**
   ```ini
   default-server = tcp:localhost:4713
   autospawn = no
   ```
2. **ALSA Wrapper (`/etc/asound.conf`):**
   Requires `alsa-plugins` (`pacman -S alsa-plugins` on Arch, `libasound2-plugins` on Ubuntu):
   ```
   pcm.!default {
       type pulse
   }
   ctl.!default {
       type pulse
   }
   ```

### ⚠️ The Critical `pw-play` vs `paplay` Gotcha
Many Python and Linux applications probe audio players using:
```python
player_cmd = shutil.which("pw-play") or shutil.which("paplay") or shutil.which("aplay")
```
* **The Pitfall:** If `pw-play` is installed, it attempts to connect to a local PipeWire daemon socket (`/run/user/$UID/pipewire-0`). In a remote cloud VM with no local PipeWire daemon running, `pw-play` exits with `error: pw_context_connect() failed: Host is down` and ignores `PULSE_SERVER`.
* **The Solution:** On the remote cloud companion VM, disable `pw-play` (`chmod -x /usr/bin/pw-play`) so audio falls back to `paplay`. `paplay` honors `PULSE_SERVER=tcp:localhost:4713` and instantly streams audio over the SSH tunnel.

---

## 6. Frame Rate (FPS), Compression, and Network Latency Physics

### Why Latency Dictates FPS over Wayland
Wayland clients synchronize rendering via `wl_surface.frame` callbacks:
1. The client draws a frame and submits it with a frame callback request.
2. The compositor receives the frame and signals the callback when ready for the next frame.
3. Over WAN, this requires a full round trip:
   $$\text{Frame Time} = \text{Network RTT} + \text{Buffer Compression/Transfer Time}$$

### Real-World Measured Performance
| Server Region | User Location | Latency (RTT) | Observed FPS | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Nuremberg (nbg1)** | East Asia (GMT+9) | ~292 ms | **~2.5 FPS** | Physics ceiling: $292\text{ms} + 100\text{ms} \approx 400\text{ms} \rightarrow 2.5\text{ FPS}$ |
| **Singapore (sin)** | East Asia (GMT+9) | **~35–45 ms** | **25–30+ FPS** | Smooth interactive gaming & desktop use |

### Waypipe Compression Tuning
Benchmarking `waypipe bench` for graphical desktop buffers:
* **`--compress lz4`**: Has almost 0% compression on raw graphical RGBA buffers (ratio ~1.004). Transmits ~4.8 MB uncompressed per frame at 1440x900, saturating WAN bandwidth.
* **`--compress zstd=1 --threads 4`**: Achieves ~0.80 ratio at >770 MB/s compression throughput, saving 20–30% bandwidth without CPU lag.

---

## 7. Recommended Production Launch Command

To launch any remote cloud application with optimized Waypipe, H.264 video encoding, watchdog timeout adjustments, dynamic title tagging, and bidirectional audio:

```bash
WAYLAND_DISPLAY=wayland-1 \
XDG_RUNTIME_DIR=/run/user/1000 \
waypipe --title-prefix '[☁ Hetzner] ' \
  --video=h264 \
  --threads 4 \
  ssh -i ~/.ssh/id_ed25519 -R 4713:localhost:4713 \
  root@companion-ip \
  'env PULSE_SERVER=tcp:localhost:4713 QT_QPA_PLATFORM=wayland QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=1500 <command>'
```

---

## 8. Visual Differentiation: Hetzner Red Border & Badging

## 8. System-Level Visual Distinction & Cloud Provider Badging

A persistent cloud companion VM is actively billing and maintaining state across laptop shutdowns. To prevent users from accidentally confusing cloud windows with local ones, or forgetting that metered compute is running, a multi-tiered visual identification system is used:

### 1. Compositor Level: Hyprland Window Rule (Hetzner Red Border)
In `~/.config/hypr/hyprland.lua`:
```lua
-- Ocloud Hetzner Companion VM Windows: distinctive Hetzner Red border
o.window({ title = ".*Hetzner.*" }, {
  border_color = { colors = { "rgba(d50c2dee)", "rgba(ff4d6dee)" }, angle = 45 },
  tag = "+hetzner-vm"
})
```

#### Key Hyprland Configuration Gotchas:
* **Gradient Table Requirement:** Hyprland Lua rejects raw color strings (`border_color = "#d50c2d"` or `border_color = "rgba(...)"`). It strictly requires a table containing a `colors` array: `{ colors = { "rgba(d50c2dee)", "rgba(ff4d6dee)" }, angle = 45 }`.
* **Lua Regex Escaping:** Avoid over-escaping bracket literals (`".*\\[Hetzner\\].*"`) in Lua string literals, as unescaped brackets or emoji prefixes can cause title matching to fail. Simple wildcards like `".*Hetzner.*"` reliably match all cloud windows.
* **Focus State Behavior:** Hyprland's `border_color` rule styles the **active/focused** window border. When focus shifts, the border returns to the compositor's inactive color. This is why compositor borders must be paired with window title prefixes and persistent visual badges.

---

### 2. Protocol Level: Waypipe Title Prefixing
Waypipe natively supports prepending a title prefix to every client window forwarded across the connection:
```bash
waypipe --title-prefix '[☁ Hetzner Cloud] ' ...
```
* **Universal Application:** Every application, sub-window, dialog, and child process spawned inside the session automatically inherits the prefix (e.g. `[☁ Hetzner Cloud] Omarchy Arcade`, `[☁ Hetzner Cloud] 2048`).
* **Shell Integration:** Hyprland window rules, task switchers (`Alt+Tab`), and bar window title widgets automatically reflect the provider prefix without requiring any application-level modifications.

---

### 3. Application Level: Persistent Bottom-Right Overlay Badge
When rendering a visual badge within graphical suites or games:

#### Why Top Header Badges Fail:
Placing badges in the top navigation bar or subheader causes them to vanish whenever:
* The user opens a detail sheet, full-screen modal, or settings drawer that slides over the header.
* The window width is constrained (e.g., 700px tiled view), causing responsive layouts or crowded rows to clip or push the badge off-screen.
* The user launches an independent sub-game or window that lacks the parent launcher's header bar.

#### The Bottom-Right Overlay Pattern:
Anchor a discreet badge overlay directly to the root item's bottom-right corner with a high z-index:
```qml
// Persistent Cloud VM Status Badge (Bottom Right)
Rectangle {
    id: hetznerCloudBadge
    z: 99999
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: 12
    height: 24
    width: hetznerBadgeRow.implicitWidth + 16
    radius: 12
    color: "#ea10080a"
    border.color: "#d50c2d"
    border.width: 1

    Row {
        id: hetznerBadgeRow
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
            width: 14; height: 14; radius: 3; color: "#d50c2d"
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.centerIn: parent; text: "H"
                font.bold: true; font.pixelSize: 10; font.family: "monospace"
                color: "#FFFFFF"
            }
        }
        Text {
            text: "HETZNER CLOUD"
            font.bold: true; font.pixelSize: 10; font.letterSpacing: 0.8
            color: "#ff6b81"
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
```
* **Unobtrusive:** Sits neatly in the corner outside of game grids, scoreboards, and main navigation targets.
* **Persistent:** Remains visible across all sheet transitions, search views, and gameplay states.

---

## 9. Dedicated Cloud Terminal & SSH Fastfetch Art

When opening a terminal to the cloud companion:

### 1. Distinctive Terminal Color Scheme (`foot`)
Instead of blending in with local terminal sessions, pass theme overrides dynamically on launch:
```bash
foot -T "☁ Ocloud Companion [Arch · 167.233.151.104]" \
     -o "colors-dark.background=080e18" \
     -o "colors-dark.foreground=e2e8f0" \
     -o "colors-dark.regular4=38bdf8" \
     -o "colors-dark.cursor=080e18 38bdf8" \
     -o "colors-dark.selection-background=1e293b" \
     -e ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no -t root@companion-ip
```

### 2. Welcome ASCII Art (`fastfetch`)
Install `fastfetch` on the cloud VM:
```bash
pacman -S --noconfirm fastfetch   # Arch Linux
# or: apt-get install -y fastfetch # Ubuntu
```
Hook it to interactive shell logins (`/etc/profile.d/fastfetch.sh` and `/root/.bashrc`):
```bash
if [ -t 1 ]; then
    fastfetch
fi
```
Every SSH or terminal connection immediately displays the OS ASCII art logo, kernel, uptime, and system resource gauges.

