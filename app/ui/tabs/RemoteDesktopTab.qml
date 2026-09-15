import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color borderCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333"
  readonly property color cardBg: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#111111"

  property var machines: []
  property int selectedMachineIndex: {
    var envIdx = Quickshell.env("OCLOUD_DESKTOP_INDEX");
    if (envIdx !== null && envIdx !== undefined && envIdx !== "") return parseInt(envIdx);
    return 0;
  }
  readonly property var currentMachine: (machines && machines.length > selectedMachineIndex) ? machines[selectedMachineIndex] : null

  property bool isScanning: false
  property string usernameInput: ""
  property string passwordInput: ""
  property bool showPassword: false
  property bool saveToVault: true
  property string statusMessage: ""
  property bool statusIsError: false

  function refreshFleet() {
    isScanning = true;
    statusMessage = "";
    if (ocloud.fetchDesktopNodes) {
      ocloud.fetchDesktopNodes(function(ok, out) {
        isScanning = false;
      });
    }
  }

  function launchDesktop() {
    if (!currentMachine) return;
    statusMessage = "Connecting to " + currentMachine.name + "...";
    statusIsError = false;

    if (ocloud.launchDesktopBreakout) {
      ocloud.launchDesktopBreakout(currentMachine.id, usernameInput, passwordInput, function(ok, out) {
        try {
          var res = JSON.parse(out);
          if (res && !res.ok && res.error === "no_viewer") {
            statusMessage = "Viewer missing: " + (res.installHint || "sudo pacman -S freerdp tigervnc");
            statusIsError = true;
            if (ocloud.showToast) ocloud.showToast("Viewer missing: " + (res.installHint || "sudo pacman -S freerdp tigervnc"));
            return;
          }
        } catch (e) {}

        if (ok) {
          statusMessage = "Launched native Wayland desktop session for " + currentMachine.name + "!";
          statusIsError = false;
          if (saveToVault && ocloud.saveDesktopCredentials) {
            ocloud.saveDesktopCredentials(currentMachine.id, usernameInput, passwordInput);
          }
        } else {
          statusMessage = "Launch failed: " + out;
          statusIsError = true;
        }
      });
    }
  }

  function launchTerminal() {
    if (!currentMachine) return;
    statusMessage = "Spawning native foot terminal for " + currentMachine.name + "...";
    statusIsError = false;

    if (ocloud.launchDesktopTerminal) {
      ocloud.launchDesktopTerminal(currentMachine.id, usernameInput, function(ok, out) {
        if (ok) {
          statusMessage = "Terminal window tiled in Hyprland!";
          statusIsError = false;
        } else {
          statusMessage = "Terminal launch failed: " + out;
          statusIsError = true;
        }
      });
    }
  }

  function saveCredentialsNow() {
    if (!currentMachine) return;
    if (ocloud.saveDesktopCredentials) {
      ocloud.saveDesktopCredentials(currentMachine.id, usernameInput, passwordInput, function(ok) {
        if (ocloud.showToast) ocloud.showToast("Credentials saved to Vault for " + currentMachine.name);
        statusMessage = "Credentials saved securely to ~/.config/ocloud/vault.json";
        statusIsError = false;
      });
    }
  }

  function installViewersNow() {
    statusMessage = "Opening terminal to install FreeRDP & TigerVNC...";
    statusIsError = false;
    if (ocloud.installLocalViewers) {
      ocloud.installLocalViewers(function(ok, out) {
        if (ok) {
          statusMessage = "Terminal opened. Complete installation in foot, then refresh fleet.";
          statusIsError = false;
        } else {
          statusMessage = "Failed to launch installer: " + out;
          statusIsError = true;
        }
      });
    }
  }

  function bootstrapNodeDesktop() {
    if (!currentMachine) return;
    statusMessage = "Configuring Remote Desktop on " + currentMachine.name + " over SSH...";
    statusIsError = false;
    if (ocloud.bootstrapRemoteDesktop) {
      ocloud.bootstrapRemoteDesktop(currentMachine.id, function(ok, out) {
        if (ok) {
          statusMessage = "Remote Desktop setup complete on " + currentMachine.name + "! Port 3389 active.";
          statusIsError = false;
          refreshFleet();
        } else {
          statusMessage = "Setup failed on " + currentMachine.name + ": " + out;
          statusIsError = true;
        }
      });
    }
  }

  Connections {
    target: ocloud
    function onDesktopNodesUpdated(jsonStr) {
      try {
        var parsed = JSON.parse(jsonStr) || [];
        machines = parsed;
        if (selectedMachineIndex >= machines.length) selectedMachineIndex = 0;
        if (currentMachine && currentMachine.savedUser) {
          usernameInput = currentMachine.savedUser;
        }
      } catch (e) {
        machines = [];
      }
    }
  }

  Component.onCompleted: {
    refreshFleet();
  }

  onCurrentMachineChanged: {
    statusMessage = "";
    statusIsError = false;
    if (currentMachine && currentMachine.savedUser) {
      usernameInput = currentMachine.savedUser;
    } else {
      usernameInput = "";
    }
    passwordInput = "";
  }

  RowLayout {
    anchors.fill: parent
    spacing: 0

    // =========================================================
    // LEFT PANE: MACHINE SELECTOR (Responsive width: 220-250px)
    // =========================================================
    Rectangle {
      id: leftPane
      Layout.preferredWidth: root.width < 850 ? 210 : 250
      Layout.fillHeight: true
      color: Qt.rgba(root.cardBg.r, root.cardBg.g, root.cardBg.b, 0.5)
      border.color: root.borderCol
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 52
          color: "transparent"
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                text: "MACHINES"
                font.family: root.appFontFamily
                font.pixelSize: 11
                font.bold: true
                color: root.textColor
                font.letterSpacing: 1.0
              }

              Text {
                text: machines.length + " devices"
                font.family: root.appFontFamily
                font.pixelSize: 9
                color: root.mutedColor
              }
            }

            Rectangle {
              Layout.preferredWidth: 26
              Layout.preferredHeight: 26
              radius: 4
              color: scanMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2) : "transparent"
              border.color: root.borderCol
              border.width: 1

              ThemeIcon {
                anchors.centerIn: parent
                width: 13
                height: 13
                source: "icons/refresh.svg"
                color: root.isScanning ? root.accentColor : root.mutedColor
                RotationAnimation on rotation {
                  running: root.isScanning
                  loops: Animation.Infinite
                  from: 0
                  to: 360
                  duration: 800
                }
              }

              MouseArea {
                id: scanMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refreshFleet()
              }
            }
          }
        }

        // Machines Scrollable List
        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: availableWidth
          clip: true

          ListView {
            id: machineListView
            width: parent.width
            model: root.machines
            spacing: 3

            delegate: Rectangle {
              width: machineListView.width - 8
              x: 4
              height: 58
              radius: 4

              readonly property bool isSelected: root.selectedMachineIndex === index

              color: isSelected
                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
                : mMouse.containsMouse
                  ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05)
                  : "transparent"

              border.color: isSelected ? root.accentColor : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                // Platform Icon
                Rectangle {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30
                  radius: 4
                  color: isSelected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05)

                  ThemeIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: {
                      var osType = (modelData.os || "").toLowerCase();
                      if (osType === "macos") return "icons/apple.svg";
                      if (osType === "windows") return "icons/device-desktop.svg";
                      if (modelData.name && modelData.name.indexOf("companion") !== -1) return "icons/archlinux.svg";
                      if (modelData.name && modelData.name.indexOf("runner") !== -1) return "icons/debian.svg";
                      return "icons/server.svg";
                    }
                    color: isSelected ? root.accentColor : root.textColor
                  }
                }

                // Details
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Rectangle {
                      width: 5
                      height: 5
                      radius: 2.5
                      color: modelData.online ? "#10b981" : "#565f89"
                    }

                    Text {
                      Layout.fillWidth: true
                      text: modelData.name || "Unknown"
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      font.bold: true
                      color: isSelected ? "#ffffff" : root.textColor
                      elide: Text.ElideRight
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                      Layout.fillWidth: true
                      text: modelData.tailscaleIp || modelData.ipv4 || "No IP"
                      font.family: root.appFontFamily
                      font.pixelSize: 8
                      color: root.mutedColor
                      elide: Text.ElideRight
                    }

                    // Protocol badge
                    Rectangle {
                      implicitWidth: protoBadge.implicitWidth + 6
                      implicitHeight: 14
                      radius: 2
                      color: modelData.portOpen ? Qt.rgba(0.06, 0.72, 0.5, 0.15) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05)
                      border.color: modelData.portOpen ? "#10b981" : root.borderCol
                      border.width: 1

                      Text {
                        id: protoBadge
                        anchors.centerIn: parent
                        text: (modelData.detectedProtocol ? modelData.detectedProtocol.toUpperCase() : "SSH")
                        font.family: root.appFontFamily
                        font.pixelSize: 7
                        font.bold: true
                        color: modelData.portOpen ? "#10b981" : root.mutedColor
                      }
                    }
                  }
                }
              }

              MouseArea {
                id: mMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectedMachineIndex = index;
                }
              }
            }
          }
        }
      }
    }

    // =========================================================
    // RIGHT PANE: MACHINE CONTROL DECK (Responsive)
    // =========================================================
    Rectangle {
      id: rightPane
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: "#08080c"

      readonly property bool isNarrow: rightPane.width < 560

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. TOP HEADER DECK
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: headerRow.implicitHeight + 20
          color: Qt.rgba(root.cardBg.r, root.cardBg.g, root.cardBg.b, 0.8)
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            // Machine Emblem
            Rectangle {
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              radius: 6
              color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
              border.color: root.accentColor
              border.width: 1

              ThemeIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: {
                  if (!root.currentMachine) return "icons/server.svg";
                  var osType = (root.currentMachine.os || "").toLowerCase();
                  if (osType === "macos") return "icons/apple.svg";
                  if (osType === "windows") return "icons/device-desktop.svg";
                  if (root.currentMachine.name && root.currentMachine.name.indexOf("companion") !== -1) return "icons/archlinux.svg";
                  if (root.currentMachine.name && root.currentMachine.name.indexOf("runner") !== -1) return "icons/debian.svg";
                  return "icons/server.svg";
                }
                color: root.accentColor
              }
            }

            // Title & IP Badges
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3

              RowLayout {
                spacing: 8

                Text {
                  text: root.currentMachine ? root.currentMachine.name : "Select Machine"
                  font.family: root.appFontFamily
                  font.pixelSize: rightPane.isNarrow ? 14 : 16
                  font.bold: true
                  color: "#ffffff"
                  elide: Text.ElideRight
                }

                // Online badge
                Rectangle {
                  implicitWidth: onTxt.implicitWidth + 8
                  implicitHeight: 18
                  radius: 3
                  color: (root.currentMachine && root.currentMachine.online) ? Qt.rgba(0.06, 0.72, 0.5, 0.2) : Qt.rgba(0.9, 0.2, 0.2, 0.2)
                  border.color: (root.currentMachine && root.currentMachine.online) ? "#10b981" : "#ef4444"
                  border.width: 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 3
                    Rectangle {
                      width: 4
                      height: 4
                      radius: 2
                      color: (root.currentMachine && root.currentMachine.online) ? "#10b981" : "#ef4444"
                    }
                    Text {
                      id: onTxt
                      text: (root.currentMachine && root.currentMachine.online) ? "ONLINE" : "OFFLINE"
                      font.family: root.appFontFamily
                      font.pixelSize: 8
                      font.bold: true
                      color: (root.currentMachine && root.currentMachine.online) ? "#10b981" : "#ef4444"
                    }
                  }
                }
              }

              RowLayout {
                spacing: 6

                Text {
                  text: root.currentMachine ? (root.currentMachine.tailscaleIp || root.currentMachine.ipv4 || "No IP") : ""
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.accentColor
                  font.bold: true
                }

                Text { text: "•"; color: root.mutedColor; font.pixelSize: 9 }

                Text {
                  text: (root.currentMachine ? (root.currentMachine.providerName || root.currentMachine.os || "Linux") : "")
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  color: root.mutedColor
                }

                Text {
                  text: "• 🔒 WireGuard"
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  color: "#10b981"
                }
              }
            }

            // Copy IP button
            Rectangle {
              implicitWidth: copyText.implicitWidth + 16
              implicitHeight: 28
              radius: 4
              color: copyMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1) : "transparent"
              border.color: root.borderCol
              border.width: 1

              RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Text { text: "📋"; font.pixelSize: 10 }
                Text {
                  id: copyText
                  text: "Copy IP"
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  color: root.textColor
                }
              }

              MouseArea {
                id: copyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.currentMachine && root.currentMachine.tailscaleIp) {
                    if (ocloud.copyToClipboard) ocloud.copyToClipboard(root.currentMachine.tailscaleIp);
                    if (ocloud.showToast) ocloud.showToast("Copied " + root.currentMachine.tailscaleIp + " to clipboard");
                  }
                }
              }
            }
          }
        }

        // Status Banner
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          visible: root.statusMessage.length > 0
          color: root.statusIsError ? Qt.rgba(0.9, 0.2, 0.2, 0.2) : Qt.rgba(0.06, 0.72, 0.5, 0.2)
          border.color: root.statusIsError ? "#ef4444" : "#10b981"
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            Text {
              text: root.statusIsError ? "▲" : "✔"
              color: root.statusIsError ? "#ef4444" : "#10b981"
              font.bold: true
              font.pixelSize: 11
            }

            Text {
              Layout.fillWidth: true
              text: root.statusMessage
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: root.statusIsError ? "#fca5a5" : "#6ee7b7"
              elide: Text.ElideRight
            }

            Rectangle {
              implicitWidth: 16
              implicitHeight: 16
              radius: 8
              color: "transparent"
              Text { anchors.centerIn: parent; text: "✕"; color: root.mutedColor; font.pixelSize: 9 }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.statusMessage = ""
              }
            }
          }
        }

        // 2. MAIN SCROLLABLE CONTROL DECK
        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: availableWidth
          clip: true

          ColumnLayout {
            width: parent.width - 32
            x: 16
            spacing: 16

            Item { height: 4 }

            // =========================================================
            // ACTION CARDS
            // =========================================================
            Text {
              text: "CONNECT"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.mutedColor
              font.letterSpacing: 1.0
            }

            // CARD A: NATIVE WAYLAND REMOTE DESKTOP
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: cardACol.implicitHeight + 24
              radius: 6
              color: Qt.rgba(root.cardBg.r, root.cardBg.g, root.cardBg.b, 0.7)
              border.color: root.borderCol
              border.width: 1

              ColumnLayout {
                id: cardACol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 4
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                    ThemeIcon {
                      anchors.centerIn: parent
                      width: 16
                      height: 16
                      source: "icons/device-desktop.svg"
                      color: root.accentColor
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                      text: "Native Remote Desktop"
                      font.family: root.appFontFamily
                      font.pixelSize: 12
                      font.bold: true
                      color: "#ffffff"
                    }

                    Text {
                      text: (root.currentMachine && root.currentMachine.os === "macos")
                        ? "Apple Screen Sharing over VNC (Port 5900)"
                        : "Native Remote Desktop Protocol (Port 3389)"
                      font.family: root.appFontFamily
                      font.pixelSize: 9
                      color: root.mutedColor
                      elide: Text.ElideRight
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: "Spawns a hardware-accelerated 60 FPS Wayland window that tiles directly into Hyprland beside Ocloud."
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  color: root.textColor
                  wrapMode: Text.WordWrap
                }

                // 1-Click Remote Setup Banner if port is closed
                Rectangle {
                  Layout.fillWidth: true
                  visible: (root.currentMachine && !root.currentMachine.portOpen && root.currentMachine.os !== "macos")
                  implicitHeight: bstrapCol.implicitHeight + 16
                  radius: 4
                  color: Qt.rgba(0.95, 0.6, 0.1, 0.12)
                  border.color: "#f59e0b"
                  border.width: 1

                  ColumnLayout {
                    id: bstrapCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                      spacing: 6
                      Text { text: "⚠️"; font.pixelSize: 11 }
                      Text {
                        text: "Remote Desktop port is not running on this server."
                        font.family: root.appFontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: "#fbbf24"
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: "Ocloud has SSH access to this node. Click below to automatically install and start XRDP over SSH with 0 manual typing."
                      font.family: root.appFontFamily
                      font.pixelSize: 9
                      color: root.textColor
                      wrapMode: Text.WordWrap
                    }

                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 32
                      radius: 4
                      color: bstrapMouse.containsMouse ? Qt.darker("#f59e0b", 1.2) : "#f59e0b"

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "⚡"; font.pixelSize: 11 }
                        Text {
                          text: "1-Click Auto-Configure Remote Desktop (SSH)"
                          font.family: root.appFontFamily
                          font.pixelSize: 10
                          font.bold: true
                          color: "#000000"
                        }
                      }

                      MouseArea {
                        id: bstrapMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bootstrapNodeDesktop()
                      }
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 34
                  radius: 4
                  color: rdBtnMouse.containsMouse ? Qt.darker(root.accentColor, 1.2) : root.accentColor

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    ThemeIcon {
                      Layout.preferredWidth: 13
                      Layout.preferredHeight: 13
                      source: "icons/external-link.svg"
                      color: "#ffffff"
                    }
                    Text {
                      text: "Launch in Hyprland"
                      font.family: root.appFontFamily
                      font.pixelSize: 11
                      font.bold: true
                      color: "#ffffff"
                    }
                  }

                  MouseArea {
                    id: rdBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchDesktop()
                  }
                }
              }
            }

            // CARD B: NATIVE WAYLAND SSH TERMINAL (foot)
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: cardBCol.implicitHeight + 24
              radius: 6
              color: Qt.rgba(root.cardBg.r, root.cardBg.g, root.cardBg.b, 0.7)
              border.color: root.borderCol
              border.width: 1

              ColumnLayout {
                id: cardBCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 10

                  Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 4
                    color: Qt.rgba(0.06, 0.72, 0.5, 0.2)
                    ThemeIcon {
                      anchors.centerIn: parent
                      width: 16
                      height: 16
                      source: "icons/terminal.svg"
                      color: "#10b981"
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                      text: "Native Wayland Terminal"
                      font.family: root.appFontFamily
                      font.pixelSize: 12
                      font.bold: true
                      color: "#ffffff"
                    }

                    Text {
                      text: "Direct SSH over WireGuard (Port 22)"
                      font.family: root.appFontFamily
                      font.pixelSize: 9
                      color: root.mutedColor
                      elide: Text.ElideRight
                    }
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: "Instantly tiles a native GPU-accelerated foot terminal session connected to this node."
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  color: root.textColor
                  wrapMode: Text.WordWrap
                }

                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 34
                  radius: 4
                  color: termBtnMouse.containsMouse ? "#059669" : "#10b981"

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "💻"; font.pixelSize: 11 }
                    Text {
                      text: "Launch Terminal (foot)"
                      font.family: root.appFontFamily
                      font.pixelSize: 11
                      font.bold: true
                      color: "#ffffff"
                    }
                  }

                  MouseArea {
                    id: termBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchTerminal()
                  }
                }
              }
            }

            // =========================================================
            // HARDWARE / ARCH LINUX VIEWER STATUS BANNER
            // =========================================================
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: viewerCol.implicitHeight + 20
              radius: 6
              color: (root.currentMachine && root.currentMachine.viewer)
                ? Qt.rgba(0.06, 0.72, 0.5, 0.08)
                : Qt.rgba(0.95, 0.6, 0.1, 0.08)
              border.color: (root.currentMachine && root.currentMachine.viewer) ? "#10b981" : "#f59e0b"
              border.width: 1

              ColumnLayout {
                id: viewerCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  Text {
                    text: (root.currentMachine && root.currentMachine.viewer) ? "✔" : "ℹ"
                    color: (root.currentMachine && root.currentMachine.viewer) ? "#10b981" : "#f59e0b"
                    font.bold: true
                    font.pixelSize: 11
                  }

                  Text {
                    Layout.fillWidth: true
                    text: (root.currentMachine && root.currentMachine.viewer)
                      ? "Native Wayland Client Detected: " + root.currentMachine.viewer
                      : "Native Wayland viewer not installed yet on host"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: (root.currentMachine && root.currentMachine.viewer) ? "#10b981" : "#f59e0b"
                    elide: Text.ElideRight
                  }
                }

                Text {
                  Layout.fillWidth: true
                  visible: !(root.currentMachine && root.currentMachine.viewer)
                  text: "For instant Hyprland window tiling with true 60 FPS, install FreeRDP & TigerVNC on your Omarchy host:"
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  color: root.textColor
                  wrapMode: Text.WordWrap
                }

                RowLayout {
                  Layout.fillWidth: true
                  visible: !(root.currentMachine && root.currentMachine.viewer)
                  spacing: 8

                  // 1-Click Install Button
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 4
                    color: instBtnMouse.containsMouse ? "#0284c7" : "#0ea5e9"

                    RowLayout {
                      anchors.centerIn: parent
                      spacing: 6
                      Text { text: "⚡"; font.pixelSize: 10 }
                      Text {
                        text: "1-Click Install Viewers (foot)"
                        font.family: root.appFontFamily
                        font.pixelSize: 10
                        font.bold: true
                        color: "#ffffff"
                      }
                    }

                    MouseArea {
                      id: instBtnMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.installViewersNow()
                    }
                  }

                  // Copy command button
                  Rectangle {
                    implicitWidth: 60
                    Layout.preferredHeight: 30
                    radius: 4
                    color: copyPkgMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.2) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1)
                    border.color: root.borderCol
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "Copy"
                      font.family: root.appFontFamily
                      font.pixelSize: 9
                      color: root.textColor
                    }

                    MouseArea {
                      id: copyPkgMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (ocloud.copyToClipboard) ocloud.copyToClipboard("sudo pacman -S --needed freerdp tigervnc");
                        if (ocloud.showToast) ocloud.showToast("Command copied: sudo pacman -S --needed freerdp tigervnc");
                      }
                    }
                  }
                }
              }
            }

            // =========================================================
            // CREDENTIALS
            // =========================================================
            Text {
              text: "CREDENTIALS"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.mutedColor
              font.letterSpacing: 1.0
            }

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: vaultCol.implicitHeight + 24
              radius: 6
              color: Qt.rgba(root.cardBg.r, root.cardBg.g, root.cardBg.b, 0.7)
              border.color: root.borderCol
              border.width: 1

              ColumnLayout {
                id: vaultCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  ThemeIcon {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    source: "icons/lock.svg"
                    color: root.accentColor
                  }

                  Text {
                    text: "Encrypted Node Credentials"
                    font.family: root.appFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                    text: "vault.json"
                    font.family: root.appFontFamily
                    font.pixelSize: 8
                    color: root.mutedColor
                  }
                }

                // Inputs Grid
                GridLayout {
                  Layout.fillWidth: true
                  columns: rightPane.isNarrow ? 1 : 2
                  columnSpacing: 10
                  rowSpacing: 8

                  // Username Input
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                      text: "Username"
                      font.family: root.appFontFamily
                      font.pixelSize: 9
                      color: root.mutedColor
                    }

                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 32
                      radius: 4
                      color: "#050508"
                      border.color: uInput.activeFocus ? root.accentColor : root.borderCol
                      border.width: 1

                      TextInput {
                        id: uInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.usernameInput
                        font.family: root.appFontFamily
                        font.pixelSize: 10
                        color: root.textColor
                        selectByMouse: true
                        onTextChanged: root.usernameInput = text
                      }
                    }
                  }

                  // Password Input
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                      text: "Password / Key"
                      font.family: root.appFontFamily
                      font.pixelSize: 9
                      color: root.mutedColor
                    }

                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 32
                      radius: 4
                      color: "#050508"
                      border.color: pInput.activeFocus ? root.accentColor : root.borderCol
                      border.width: 1

                      RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 4

                        TextInput {
                          id: pInput
                          Layout.fillWidth: true
                          verticalAlignment: TextInput.AlignVCenter
                          text: root.passwordInput
                          echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                          font.family: root.appFontFamily
                          font.pixelSize: 10
                          color: root.textColor
                          selectByMouse: true
                          onTextChanged: root.passwordInput = text
                        }

                        Text {
                          text: root.showPassword ? "👁" : "🔒"
                          font.pixelSize: 10
                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showPassword = !root.showPassword
                          }
                        }
                      }
                    }
                  }
                }

                // Save button
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: 32
                  radius: 4
                  color: saveMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.15) : "transparent"
                  border.color: root.accentColor
                  border.width: 1

                  Text {
                    id: saveBtnTxt
                    anchors.centerIn: parent
                    text: "Save Credentials to Vault"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: root.accentColor
                  }

                  MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveCredentialsNow()
                  }
                }
              }
            }

            // =========================================================
            // ZERO-INSTALL SETUP GUIDE
            // =========================================================
            Text {
              text: "TARGET ZERO-INSTALL SETUP"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.mutedColor
              font.letterSpacing: 1.0
            }

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: guideCol.implicitHeight + 24
              radius: 6
              color: Qt.rgba(root.cardBg.r, root.cardBg.g, root.cardBg.b, 0.7)
              border.color: root.borderCol
              border.width: 1

              ColumnLayout {
                id: guideCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                Text {
                  text: (root.currentMachine && root.currentMachine.os === "macos")
                    ? "macOS Screen Sharing"
                    : ((root.currentMachine && root.currentMachine.os === "windows")
                      ? "Windows Remote Desktop"
                      : "Linux Headless / GUI")
                  font.family: root.appFontFamily
                  font.pixelSize: 11
                  font.bold: true
                  color: "#ffffff"
                }

                Text {
                  Layout.fillWidth: true
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  color: root.textColor
                  wrapMode: Text.WordWrap
                  lineHeight: 1.3
                  text: {
                    if (!root.currentMachine) return "";
                    var osType = (root.currentMachine.os || "").toLowerCase();
                    if (osType === "macos") {
                      return "1. On Mac: Open 'System Settings > General > Sharing'.\n" +
                             "2. Toggle 'Screen Sharing' to ON.\n" +
                             "3. Click (i) info button to ensure your account is allowed.\n" +
                             "4. Port 5900 is automatically open across your Tailnet.";
                    }
                    if (osType === "windows") {
                      return "1. On Windows: Open 'Settings > System > Remote Desktop'.\n" +
                             "2. Toggle 'Enable Remote Desktop' to ON.\n" +
                             "3. Port 3389 is automatically open across your Tailnet.";
                    }
                    return "1. Terminal: Click 'Launch Terminal (foot)' to tile immediately.\n" +
                           "2. GNOME: 'Settings > Sharing > Remote Desktop' enable RDP.\n" +
                           "3. All access is encrypted over your Tailscale WireGuard IP.";
                  }
                }
              }
            }

            Item { height: 16 }
          }
        }
      }
    }
  }
}
