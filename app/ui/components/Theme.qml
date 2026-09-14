import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: theme

  readonly property string home: Quickshell.env("HOME") || "/home/bigcjat"
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentThemePath: stateHome + "/omarchy/current/theme"

  // Base theme mode
  property string themeMode: "dark"

  // Foundational Palette (Defaults to Tokyo Night, reactive to active Omarchy theme)
  property color background: "#1a1b26"
  property color darkBackground: "#13141c"
  property color darkerBackground: "#0e0e14"
  property color lighterBackground: "#24283b"

  property color foreground: "#a9b1d6"
  property color darkForeground: "#565f89"
  property color lightForeground: "#b4bee6"
  property color brightForeground: "#c0caf5"

  property color accent: "#7aa2f7"
  property color muted: "#414868"
  property color selection: "#292e42"

  property color red: "#f7768e"
  property color green: "#9ece6a"
  property color yellow: "#e0af68"
  property color blue: "#7aa2f7"
  property color cyan: "#449dab"
  property color magenta: "#ad8ee6"
  property color orange: "#eb927b"

  // System Typography & Sizing
  property string fontFamily: "monospace"
  property int fontBaseSize: 12
  property int cornerRadius: 8

  // Calculated Theme Mode
  readonly property bool isDark: {
    if (themeMode === "light") return false;
    if (themeMode === "dark") return true;
    var lum = 0.299 * background.r + 0.587 * background.g + 0.114 * background.b;
    return lum < 0.5;
  }

  // Semantic UI Tokens directly consumed across all tabs & components
  readonly property color bgDark: background
  readonly property color headerBg: darkBackground
  readonly property color sidebarBg: darkerBackground
  readonly property color cardBg: isDark ? lighterBackground : darkBackground
  readonly property color cardBgAlt: isDark ? darkBackground : darkerBackground

  readonly property color borderSubtle: Qt.rgba(foreground.r, foreground.g, foreground.b, isDark ? 0.14 : 0.12)
  readonly property color borderActive: accent

  readonly property color textPrimary: brightForeground
  readonly property color textSecondary: foreground
  readonly property color textMuted: isDark ? darkForeground : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.55)

  readonly property color accentSky: accent
  readonly property color accentHover: Qt.lighter(accent, 1.15)
  readonly property color homeGreen: green
  readonly property color warningAmber: yellow
  readonly property color dangerRed: red

  // Parser for ~/.local/state/omarchy/current/theme/colors.toml
  function loadColors(raw) {
    if (!raw) return;
    var lines = String(raw).split("\n");
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line || line.charAt(0) === "#") continue;

      var modeMatch = line.match(/^mode\s*=\s*["']([^"']+)["']/);
      if (modeMatch) {
        themeMode = modeMatch[1];
        continue;
      }

      var match = line.match(/^([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/);
      if (!match) continue;

      var key = match[1].toLowerCase();
      var val = match[2];

      if (key === "background" || key === "bg") background = val;
      else if (key === "dark_background" || key === "dark_bg") darkBackground = val;
      else if (key === "darker_background" || key === "darker_bg") darkerBackground = val;
      else if (key === "lighter_background" || key === "lighter_bg") lighterBackground = val;
      else if (key === "foreground" || key === "fg") foreground = val;
      else if (key === "bright_foreground" || key === "bright_fg") brightForeground = val;
      else if (key === "dark_foreground" || key === "dark_fg") darkForeground = val;
      else if (key === "light_foreground" || key === "light_fg") lightForeground = val;
      else if (key === "accent") accent = val;
      else if (key === "muted") muted = val;
      else if (key === "selection") selection = val;
      else if (key === "red" || key === "color1") red = val;
      else if (key === "green" || key === "color2") green = val;
      else if (key === "yellow" || key === "color3") yellow = val;
      else if (key === "blue" || key === "color4") blue = val;
      else if (key === "cyan" || key === "color6") cyan = val;
      else if (key === "magenta" || key === "color5") magenta = val;
      else if (key === "orange") orange = val;
    }
  }

  // Parser for ~/.local/state/omarchy/current/theme/shell.toml
  function loadShell(raw) {
    if (!raw) return;
    var lines = String(raw).split("\n");
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^\s*base-size\s*=\s*(\d+)/);
      if (match) {
        fontBaseSize = parseInt(match[1]);
      }
    }
  }

  property Timer retryTimer: Timer {
    interval: 80
    repeat: false
    onTriggered: {
      colorsView.reload();
      shellView.reload();
    }
  }

  // Live FileView for system theme colors
  property FileView colorsView: FileView {
    id: colorsView
    path: theme.currentThemePath + "/colors.toml"
    watchChanges: false
    printErrors: false
    onLoaded: theme.loadColors(text())
    onLoadFailed: retryTimer.start()
  }

  // Live FileView for system shell style tokens
  property FileView shellView: FileView {
    id: shellView
    path: theme.currentThemePath + "/shell.toml"
    watchChanges: false
    printErrors: false
    onLoaded: theme.loadShell(text())
    onLoadFailed: retryTimer.start()
  }

  // Watch theme.name: Written atomically after CURRENT_THEME_PATH is swapped
  property FileView themeNameView: FileView {
    id: themeNameView
    path: theme.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: {
      colorsView.reload();
      shellView.reload();
    }
    onFileChanged: reload()
  }

  // Resolve system font family via fontconfig
  property Process fcMatchProc: Process {
    command: ["fc-match", "-f", "%{family[0]}", "monospace"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var name = String(text || "").trim();
        if (name.length > 0) {
          theme.fontFamily = name;
        }
      }
    }
  }

  Component.onCompleted: {
    fcMatchProc.running = true;
  }
}
