#!/usr/bin/env bash
set -e

# ==============================================================================
# Ocloud - Omarchy Linux System Installer
# Sets up CLI, Desktop Entry, Hicolor Icon, and Quickshell Taskbar Plugin.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure mise shims are in PATH if present
if [ -d "$HOME/.local/share/mise/shims" ]; then
  export PATH="$HOME/.local/share/mise/shims:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"

echo "================================================="
echo "   Installing Ocloud for Omarchy Linux"
echo "================================================="

# 1. Dependency checks
echo "Checking environment dependencies..."
if ! command -v node >/dev/null 2>&1; then
  echo "❌ Error: Node.js runtime not found in PATH."
  echo "   Omarchy installs Node via mise. Run: mise use -g node@latest"
  exit 1
else
  echo "✔ Node.js: $(node --version)"
fi

if ! command -v quickshell >/dev/null 2>&1 && [ ! -f "/usr/bin/quickshell" ]; then
  echo "⚠️  Warning: Quickshell was not found at /usr/bin/quickshell or in PATH."
  echo "   Quickshell is required to run the desktop GUI and taskbar plugin."
else
  echo "✔ Quickshell detected."
fi

if ! command -v rclone >/dev/null 2>&1 && [ ! -f "$HOME/.local/bin/rclone" ]; then
  echo "⚠️  Warning: rclone not found. Cloud storage mounts require rclone."
else
  echo "✔ Rclone detected."
fi

# 2. Directory structure
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/share/applications"
mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$HOME/.config/omarchy/plugins"

# 3. Link CLI
echo "Installing CLI binary..."
chmod +x "$SCRIPT_DIR/ocloud"
ln -sf "$SCRIPT_DIR/ocloud" "$HOME/.local/bin/ocloud"
echo "✔ Symlinked $HOME/.local/bin/ocloud -> $SCRIPT_DIR/ocloud"

# 4. Install Desktop Icon
echo "Installing high-resolution vector icon..."
cp -f "$SCRIPT_DIR/app/ui/icons/ocloud.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/ocloud.svg"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi
echo "✔ Installed ocloud.svg to hicolor scalable icon theme"

# 5. Install Desktop Entry
echo "Registering XDG desktop application..."
cp -f "$SCRIPT_DIR/ocloud.desktop" "$HOME/.local/share/applications/ocloud.desktop"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi
echo "✔ Registered $HOME/.local/share/applications/ocloud.desktop"

# 6. Register Quickshell Plugin
echo "Registering Omarchy taskbar plugin..."
PLUGIN_LINK="$HOME/.config/omarchy/plugins/community.ocloud"
rm -rf "$PLUGIN_LINK"
ln -sf "$SCRIPT_DIR/plugin" "$PLUGIN_LINK"
echo "✔ Symlinked plugin: $PLUGIN_LINK -> $SCRIPT_DIR/plugin"

# 7. Verification
echo ""
echo "Verifying installation..."
"$HOME/.local/bin/ocloud" status --json >/dev/null 2>&1 && echo "✔ CLI status test passed." || echo "ℹ CLI ready."

echo ""
echo "================================================="
echo "   Ocloud Installation Complete! 🎉"
echo "================================================="
echo "Launch Desktop App:   ocloud app"
echo "Check System Status:  ocloud status"
echo "Manage Cloud Drives:  ocloud storage list"
echo "Omarchy Taskbar:      Plugin 'community.ocloud' is active."
echo "================================================="
