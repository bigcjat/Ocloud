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

## 1.1 Remote Application Streaming Architecture: Waypipe vs. Xpra (Option B)

### The Waypipe WAN Bottleneck
Waypipe forwards Wayland protocol events and pixel buffers (`wl_shm` / `dmabuf`) across the network. While excellent over LAN (<5ms latency):
1. **Network RTT Lockstep:** The Wayland protocol requires client and compositor synchronization via `wl_surface.frame` callbacks. Over a 100ms–300ms WAN ping, this throttles frame rates to ~1–3 FPS.
2. **Buffer Flooding / Crash:** Disabling Wayland vsync (`widget.wayland.vsync.enabled=false`) breaks the lockstep, but causes browsers to flood 60 `create_pool` calls per second over SSH, overwhelming socket buffers and triggering Hyprland `invalid object 406` protocol crashes.
3. **No Disconnect Resilience:** If your laptop sleeps, you close the lid, or Wi-Fi drops, Waypipe drops the socket and the remote application dies immediately.

### The Xpra Architecture (Proven Butter-Smooth Solution)
Ocloud uses **Xpra Seamless Sessions** (`ocloud app launch` / `attach`):
1. **Decoupled Local Frame Pacing:** Applications run against a local headless Xvfb display on the cloud VM (`0.01ms` latency). Rendering happens at full native speed regardless of WAN latency.
2. **Adaptive Video Compression:** Xpra captures windows and encodes frame updates into adaptive H.264/VP9 video packets over the wire, dropping intermediate frames gracefully when network jitter occurs.
3. **24/7 Cloud Persistence:** Closing your laptop lid or disconnecting from Wi-Fi does **not** close your cloud applications. Firefox, video streams, and IDEs remain alive 24/7 on the cloud VM and re-attach instantly when you reopen your laptop.
4. **Pristine Opus / PipeWire Audio:** Audio is encoded in Opus 48kHz stereo and streamed into your laptop's native PipeWire speakers without requiring manual SSH socket plumbing.

### WAN Audio Buffer Dynamics (Intercontinental Latency)
When streaming audio across >250ms WAN hops (e.g. Korea to Germany with ~300ms RTT), network jitter (packet arrival variance of ±15–30ms) causes default small jitter buffers (50ms) to experience minor micro-underruns. Disabling AV sync (`--av-sync=no`) prevents these packet gaps from blocking video frames, maintaining buttery-smooth visual rendering while keeping audio continuous and low-latency.

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
3. Over WAN, if the client waits for the compositor before drawing the next frame:
   $$\text{Max FPS} \le \frac{1000}{\text{Network RTT (ms)}}$$

### The Frame Callback Timeout Solution: `QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=16`
* **The Pitfall of `1500`**: Setting `QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=1500` instructs Qt to wait up to **1.5 full seconds** on high network ping or compositor delay before forcing a render.
* **The High-FPS Fix**: Set `QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=16` (or `0`) and `QSG_RENDER_LOOP=basic`. When network latency is higher than 16ms, Qt's timer fires and delivers the next frame anyway, completely decoupling local rendering speed from WAN network round-trip time.

### Dual-Tier Hardware vs. CPU Acceleration

#### Tier 1: Hardware Graphics (Integrated iGPU or Dedicated GPU)
* **Bare Metal Consumer Hardware (Hetzner Auction / Robot)**: Consumer CPUs (Intel Core i7-7700, i7-8700, i5-12500/13500) feature **Intel QuickSync Video (UHD Graphics)**; AMD Ryzen consumer processors feature **Radeon APUs**.
* **Capabilities**:
  - Exposes `/dev/dri/renderD128` via `i915`, `xe`, or `amdgpu` kernel drivers.
  - Waypipe passes `--video=h264,hw,bpf=1500000` to utilize Intel QuickSync / VAAPI hardware encoders.
  - Frames are compressed directly in dedicated CPU silicon with **0% CPU load**, leaving all cores free for the application.
  - Zero-copy DMABUF transfers eliminate RAM copy overhead.

#### Tier 2: Pure Headless Virtual VPS (No iGPU or Dedicated GPU)
* **Software Rasterization**: Launch with `GALLIUM_DRIVER=llvmpipe LP_NUM_THREADS=<cores> LIBGL_ALWAYS_SOFTWARE=1`.
* **Compression Tuning**:
  - **NEVER use `--compress lz4` on graphical buffers**: LZ4 has virtually 0% compression on raw 32-bit RGBA pixels (ratio ~1.004), transmitting 8.3 MB per 1080p frame and choking WAN bandwidth to 2–4 FPS.
  - **Use `--video=h264,bpf=1200000` with fallback to `--compress=zstd=1`**: ZSTD level 1 achieves >770 MB/s compression throughput, reducing bandwidth by 20–30% without CPU lag.

### Transport Optimization (Tailscale & SSH)
1. **Tailscale Mesh (Peer-to-Peer WireGuard)**:
   - When connecting over Tailscale, the connection is already secured end-to-end via kernel-space WireGuard.
2. **OpenSSH Acceleration**:
   - `-c aes128-gcm@openssh.com`: Utilizes CPU AES-NI hardware instructions (3–5× faster stream throughput than default `chacha20-poly1305`).
   - `-o Compression=no`: Explicitly disables SSH zlib re-compression to prevent CPU saturation and buffer bloat over pre-encoded video streams.
   - `-o IPQoS=throughput`: Prevents packet delivery pauses for streaming data.

---

## 7. Recommended Production Launch Command

To launch any remote cloud application with tuned Waypipe, dual-tier graphics detection, decoupled 60 FPS pacing, and bidirectional audio:

```bash
# Production launch command:
WAYLAND_DISPLAY=wayland-1 \
XDG_RUNTIME_DIR=/run/user/1000 \
waypipe --title-prefix '[☁ Hetzner] ' \
  --video=h264,hw,bpf=1500000 \
  --compress=zstd=1 \
  --threads 4 \
  ssh \
    -p 22 \
    -i ~/.ssh/id_ed25519 \
    -c aes128-gcm@openssh.com \
    -o Compression=no \
    -o IPQoS=throughput \
    -o TCPKeepAlive=no \
    -R 4713:localhost:4713 \
    root@companion-ip \
    'env \
       PULSE_SERVER=tcp:localhost:4713 \
       QT_QPA_PLATFORM=wayland \
       QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=16 \
       QSG_RENDER_LOOP=basic \
       <command>'
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

---

## 10. Session Lifecycle: Detaching vs. Terminating

When running persistent cloud applications over Xpra:

### 1. Close Window vs. Detach Viewer
* **Normal Close (`Super+Q` / `killactive` / Window `X` button):** Sends `WM_DELETE_WINDOW` to the application inside the virtual display. Applications like Firefox will prompt to exit or terminate.
* **Detach (`ocloud app detach`):** Disconnects the local viewer process. The remote application, virtual display (`:100`), PulseAudio server, and audio/video state **remain running 24/7 in the cloud**.

### 2. Bringing Back the Session (Re-attach)
* **Ocloud UI:** Navigate to the **Cloud App Suite** tab. The live session card detects the background session (`:100`). Click **`[⚡ Re-attach Window]`**.
* **CLI:**
  ```bash
  ocloud app attach <server-name-or-id>
  ```

### 3. Recommended Hyprland Shortcuts
Add to `~/.config/hypr/hyprland.conf`:
```ini
# Detach cloud streaming window (leaves app alive 24/7 on remote VM)
bind = $mainMod SHIFT, D, exec, ocloud app detach

# Re-attach cloud streaming window instantly
bind = $mainMod SHIFT, A, exec, ocloud app attach omarchy-companion
```


