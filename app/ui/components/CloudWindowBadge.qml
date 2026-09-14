import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: root
  screen: Quickshell.screens[0]
  visible: root.hasCloudWindow
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  // Input mask only covers the badge when visible and NOT dodging mouse hover
  mask: Region {
    item: (!badgeHover.containsMouse && root.hasCloudWindow) ? badge : null
  }

  property int badgeX: 100
  property int badgeY: 100
  property string providerLabel: "HETZNER CLOUD"
  property string providerLetter: "H"
  property string providerColor: "#d50c2d"
  property bool hasCloudWindow: false

  Process {
    id: proc
    command: ["sh", "-c", "export HYPRLAND_INSTANCE_SIGNATURE=$(ls -1 /run/user/$(id -u)/hypr/ 2>/dev/null | head -n 1); hyprctl clients -j"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var clients = JSON.parse(text);
          var cloudWin = clients.find(function(c) {
            if (!c.mapped || c.hidden) return false;
            // 1. Tagged by Hyprland rule
            if (c.tags && c.tags.some(function(t) { return t.indexOf("cloud-vm") !== -1; })) return true;
            // 2. Prefixed by [☁ ...] title (Waypipe or Xpra)
            if (c.title && (c.title.indexOf("[☁") !== -1 || c.title.indexOf("☁") !== -1)) return true;
            // 3. Xpra class or title with remote IP
            if (c.class === "Xpra" || c.initialClass === "Xpra") return true;
            if (c.title && (c.title.indexOf("100.77.43.44") !== -1 || c.title.indexOf("167.233.151.104") !== -1 || c.title.indexOf("35.254.203.25") !== -1)) return true;
            return false;
          });

          if (cloudWin) {
            root.hasCloudWindow = true;

            // Multi-monitor screen binding & coordinate offset calculation
            var winMon = cloudWin.monitor;
            var targetScreen = (typeof winMon === "number" && winMon >= 0 && winMon < Quickshell.screens.length)
              ? Quickshell.screens[winMon]
              : Quickshell.screens[0];
            if (root.screen !== targetScreen) {
              root.screen = targetScreen;
            }

            var screenX = (targetScreen && typeof targetScreen.x === "number") ? targetScreen.x : 0;
            var screenY = (targetScreen && typeof targetScreen.y === "number") ? targetScreen.y : 0;
            var relX = cloudWin.at[0] - screenX;
            var relY = cloudWin.at[1] - screenY;

            // Place in bottom-right corner of the cloud window
            root.badgeX = relX + cloudWin.size[0] - badge.width - 24;
            root.badgeY = relY + cloudWin.size[1] - badge.height - 24;

            // Dynamically detect cloud provider and brand styling
            var title = cloudWin.title || "";
            var titleLower = title.toLowerCase();

            if (titleLower.includes("google") || titleLower.includes("gcp") || title.includes("35.254.203.25")) {
              root.providerLabel = "GOOGLE CLOUD";
              root.providerLetter = "G";
              root.providerColor = "#4285f4";
            } else if (titleLower.includes("hetzner") || title.includes("100.77.43.44") || title.includes("167.233.151.104")) {
              root.providerLabel = "HETZNER CLOUD";
              root.providerLetter = "H";
              root.providerColor = "#d50c2d";
            } else if (titleLower.includes("aws") || titleLower.includes("amazon")) {
              root.providerLabel = "AMAZON AWS";
              root.providerLetter = "A";
              root.providerColor = "#ff9900";
            } else if (titleLower.includes("digitalocean")) {
              root.providerLabel = "DIGITALOCEAN";
              root.providerLetter = "D";
              root.providerColor = "#0080ff";
            } else if (titleLower.includes("vultr")) {
              root.providerLabel = "VULTR CLOUD";
              root.providerLetter = "V";
              root.providerColor = "#007bfc";
            } else if (titleLower.includes("linode") || titleLower.includes("akamai")) {
              root.providerLabel = "LINODE CLOUD";
              root.providerLetter = "L";
              root.providerColor = "#00a95c";
            } else if (titleLower.includes("scaleway")) {
              root.providerLabel = "SCALEWAY";
              root.providerLetter = "S";
              root.providerColor = "#4f0599";
            } else if (titleLower.includes("home") || titleLower.includes("workstation")) {
              root.providerLabel = "HOME WORKSTATION";
              root.providerLetter = "⌂";
              root.providerColor = "#10b981";
            } else {
              var match = title.match(/\[☁\s*([^\]]+)\]/);
              root.providerLabel = match ? (match[1].toUpperCase() + " CLOUD") : "CLOUD COMPANION";
              root.providerLetter = match ? match[1].charAt(0).toUpperCase() : "☁";
              root.providerColor = "#38bdf8";
            }
          } else {
            root.hasCloudWindow = false;
          }
        } catch(e) {}
      }
    }
  }

  // Debounce timer for Hyprland window events to avoid spamming process checks
  Timer {
    id: hyprDebounceTimer
    interval: 150
    repeat: false
    onTriggered: {
      if (!proc.running) proc.running = true;
    }
  }

  // Hyprland Socket2 real-time event stream for instantaneous response (<5ms)
  Process {
    id: hyprEvents
    command: ["sh", "-c", "sig=$(ls -1 /run/user/$(id -u)/hypr/ 2>/dev/null | head -n 1); [ -n \"$sig\" ] && exec nc -U /run/user/$(id -u)/hypr/$sig/.socket2.sock 2>/dev/null || true"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        var evt = String(data || "");
        if (evt.indexOf("activewindow") !== -1 || evt.indexOf("movewindow") !== -1 || evt.indexOf("openwindow") !== -1 || evt.indexOf("closewindow") !== -1 || evt.indexOf("workspace") !== -1) {
          hyprDebounceTimer.restart();
        }
      }
    }
  }

  Component.onCompleted: {
    proc.running = true;
  }

  Rectangle {
    id: badge
    visible: root.hasCloudWindow
    x: root.badgeX
    y: root.badgeY
    width: badgeRow.implicitWidth + 24
    height: 28
    radius: 14
    color: "#ea10080a"
    border.color: root.providerColor
    border.width: 1.5

    // Smooth hover-dodge: when mouse approaches or hovers, badge fades and vanishes
    opacity: badgeHover.containsMouse ? 0.0 : 1.0
    scale: badgeHover.containsMouse ? 0.85 : 1.0

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }
    Behavior on scale {
      NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }
    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    MouseArea {
      id: badgeHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    Row {
      id: badgeRow
      anchors.centerIn: parent
      spacing: 8

      Rectangle {
        width: 15
        height: 15
        radius: 3
        color: root.providerColor
        anchors.verticalCenter: parent.verticalCenter
        Text {
          anchors.centerIn: parent
          text: root.providerLetter
          font.bold: true
          font.pixelSize: 9
          font.family: "monospace"
          color: "#ffffff"
        }
      }

      Text {
        text: root.providerLabel
        font.bold: true
        font.pixelSize: 10
        font.letterSpacing: 0.8
        color: "#ffffff"
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: 6
        height: 6
        radius: 3
        color: "#22c55e"
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
