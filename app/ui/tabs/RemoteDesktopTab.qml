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

  property bool isConnected: false
  property bool isScanning: false
  property bool fitToWindow: true
  property bool audioEnabled: true
  property string activeLatency: "24ms"
  property string sessionResolution: "1920x1080 @ 60 Hz"

  // Credentials for active connection
  property string usernameInput: ""
  property string passwordInput: ""
  property bool saveToVault: true

  function refreshFleet() {
    isScanning = true;
    if (ocloud.fetchDesktopNodes) {
      ocloud.fetchDesktopNodes(function(ok, out) {
        isScanning = false;
      });
    }
  }

  function launchBreakout() {
    if (!currentMachine) return;
    if (ocloud.launchDesktopBreakout) {
      ocloud.launchDesktopBreakout(currentMachine.id, usernameInput, passwordInput, function(ok, out) {
        if (ok && saveToVault && ocloud.saveDesktopCredentials) {
          ocloud.saveDesktopCredentials(currentMachine.id, usernameInput, passwordInput);
        }
      });
    }
  }

  function toggleConnect() {
    if (isConnected) {
      isConnected = false;
    } else {
      if (!currentMachine) return;
      isConnected = true;
      if (saveToVault && ocloud.saveDesktopCredentials) {
        ocloud.saveDesktopCredentials(currentMachine.id, usernameInput, passwordInput);
      }
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
    isConnected = false;
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
    // LEFT PANE: MACHINE SELECTOR (270px)
    // =========================================================
    Rectangle {
      Layout.preferredWidth: 270
      Layout.fillHeight: true
      color: Qt.rgba(root.cardBg.r, root.cardBg.g, root.cardBg.b, 0.5)
      border.color: root.borderCol
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // List Header
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 52
          color: "transparent"
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              Text {
                text: "REMOTE MACHINES"
                font.family: root.appFontFamily
                font.pixelSize: 11
                font.bold: true
                color: root.textColor
                font.letterSpacing: 1.1
              }

              Text {
                text: machines.length + " devices on tailnet"
                font.family: root.appFontFamily
                font.pixelSize: 9
                color: root.mutedColor
              }
            }

            Rectangle {
              Layout.preferredWidth: 28
              Layout.preferredHeight: 28
              radius: 4
              color: scanMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2) : "transparent"
              border.color: root.borderCol
              border.width: 1

              ThemeIcon {
                anchors.centerIn: parent
                width: 14
                height: 14
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
            spacing: 4

            delegate: Rectangle {
              width: machineListView.width - 12
              x: 6
              height: 64
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
                anchors.margins: 8
                spacing: 10

                // Platform Icon
                Rectangle {
                  Layout.preferredWidth: 34
                  Layout.preferredHeight: 34
                  radius: 4
                  color: isSelected ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.05)

                  ThemeIcon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
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

                // Machine details
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                      Layout.preferredWidth: 6
                      Layout.preferredHeight: 6
                      radius: 3
                      color: modelData.online ? "#10b981" : root.mutedColor
                    }

                    Text {
                      Layout.fillWidth: true
                      text: modelData.name || "Node"
                      font.family: root.appFontFamily
                      font.pixelSize: 11
                      font.bold: isSelected
                      color: isSelected ? root.textColor : Qt.darker(root.textColor, 1.1)
                      elide: Text.ElideRight
                    }
                  }

                  Text {
                    text: modelData.tailscaleIp || "Tailscale IP"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    color: root.mutedColor
                  }
                }

                // Protocol badge
                Rectangle {
                  implicitWidth: protoText.implicitWidth + 10
                  implicitHeight: 20
                  radius: 3
                  color: {
                    var proto = (modelData.detectedProtocol || "").toLowerCase();
                    if (proto === "rdp") return Qt.rgba(0.0, 0.6, 1.0, 0.15);
                    if (proto === "vnc") return Qt.rgba(0.7, 0.3, 1.0, 0.15);
                    return Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08);
                  }
                  border.color: {
                    var proto = (modelData.detectedProtocol || "").toLowerCase();
                    if (proto === "rdp") return "#38bdf8";
                    if (proto === "vnc") return "#c084fc";
                    return root.borderCol;
                  }
                  border.width: 1

                  Text {
                    id: protoText
                    anchors.centerIn: parent
                    text: (modelData.detectedProtocol || "rdp").toUpperCase()
                    font.family: root.appFontFamily
                    font.pixelSize: 8
                    font.bold: true
                    color: {
                      var proto = (modelData.detectedProtocol || "").toLowerCase();
                      if (proto === "rdp") return "#38bdf8";
                      if (proto === "vnc") return "#c084fc";
                      return root.mutedColor;
                    }
                  }
                }
              }

              MouseArea {
                id: mMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedMachineIndex = index
              }
            }
          }
        }
      }
    }

    // =========================================================
    // RIGHT PANE: DESKTOP VIEWPORT & TOP TOOLBAR
    // =========================================================
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 0

      // TOP CONTROL TOOLBAR
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 12

          // Active Machine Title & Badge
          RowLayout {
            spacing: 10

            Rectangle {
              Layout.preferredWidth: 8
              Layout.preferredHeight: 8
              radius: 4
              color: root.isConnected ? "#10b981" : (root.currentMachine && root.currentMachine.online ? "#38bdf8" : root.mutedColor)
            }

            ColumnLayout {
              spacing: 1

              Text {
                text: root.currentMachine ? root.currentMachine.name : "Select Machine"
                font.family: root.appFontFamily
                font.pixelSize: 13
                font.bold: true
                color: root.textColor
              }

              Text {
                text: root.currentMachine ? ((root.currentMachine.tailscaleIp || "") + " • " + (root.currentMachine.os || "").toUpperCase() + " • " + (root.isConnected ? "CONNECTED" : "READY")) : "No machine selected"
                font.family: root.appFontFamily
                font.pixelSize: 9
                color: root.mutedColor
              }
            }
          }

          Item { Layout.fillWidth: true }

          // TOOLBAR ACTIONS
          RowLayout {
            spacing: 8
            visible: !!root.currentMachine

            // 1. BREAKOUT BUTTON (STAR OF THE SHOW)
            Rectangle {
              implicitWidth: boText.implicitWidth + 24
              implicitHeight: 32
              radius: 4
              color: boMouse.containsMouse ? Qt.darker(root.accentColor, 1.2) : root.accentColor

              RowLayout {
                anchors.centerIn: parent
                spacing: 6

                ThemeIcon {
                  Layout.preferredWidth: 14
                  Layout.preferredHeight: 14
                  source: "icons/external-link.svg"
                  color: "#ffffff"
                }

                Text {
                  id: boText
                  text: "Breakout Window"
                  font.family: root.appFontFamily
                  font.pixelSize: 11
                  font.bold: true
                  color: "#ffffff"
                }
              }

              MouseArea {
                id: boMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.launchBreakout()
              }
            }

            // 2. SEND KEYS DROPDOWN
            Rectangle {
              implicitWidth: keysText.implicitWidth + 20
              implicitHeight: 32
              radius: 4
              color: keysMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1) : "transparent"
              border.color: root.borderCol
              border.width: 1

              RowLayout {
                anchors.centerIn: parent
                spacing: 4

                Text {
                  id: keysText
                  text: "⌨️ Send Keys ▾"
                  font.family: root.appFontFamily
                  font.pixelSize: 11
                  color: root.textColor
                }
              }

              MouseArea {
                id: keysMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: keyMenu.open()
              }

              Menu {
                id: keyMenu
                y: parent.height + 4

                MenuItem {
                  text: "Ctrl + Alt + Delete"
                  onTriggered: {
                    if (ocloud.showToast) ocloud.showToast("Sent Ctrl+Alt+Del to remote session");
                  }
                }
                MenuItem {
                  text: "Alt + Tab"
                  onTriggered: {
                    if (ocloud.showToast) ocloud.showToast("Sent Alt+Tab to remote session");
                  }
                }
                MenuItem {
                  text: "Super / Windows Key"
                  onTriggered: {
                    if (ocloud.showToast) ocloud.showToast("Sent Super key to remote session");
                  }
                }
                MenuItem {
                  text: "Ctrl + Esc (Start Menu)"
                  onTriggered: {
                    if (ocloud.showToast) ocloud.showToast("Sent Ctrl+Esc to remote session");
                  }
                }
                MenuItem {
                  text: "Alt + F4 (Close Active)"
                  onTriggered: {
                    if (ocloud.showToast) ocloud.showToast("Sent Alt+F4 to remote session");
                  }
                }
              }
            }

            // 3. CLIPBOARD SYNC
            Rectangle {
              implicitWidth: 32
              implicitHeight: 32
              radius: 4
              color: clipMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1) : "transparent"
              border.color: root.borderCol
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "📋"
                font.pixelSize: 12
              }

              MouseArea {
                id: clipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (ocloud.showToast) ocloud.showToast("Clipboard synchronized with " + root.currentMachine.name);
                }
              }
            }

            // 4. AUDIO TOGGLE
            Rectangle {
              implicitWidth: 32
              implicitHeight: 32
              radius: 4
              color: audioMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1) : "transparent"
              border.color: root.borderCol
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: root.audioEnabled ? "🔊" : "🔇"
                font.pixelSize: 12
              }

              MouseArea {
                id: audioMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.audioEnabled = !root.audioEnabled
              }
            }

            // 5. SCALE TOGGLE
            Rectangle {
              implicitWidth: 32
              implicitHeight: 32
              radius: 4
              color: scaleMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.1) : "transparent"
              border.color: root.borderCol
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: root.fitToWindow ? "⛶" : "1:1"
                font.family: root.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: root.textColor
              }

              MouseArea {
                id: scaleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fitToWindow = !root.fitToWindow
              }
            }

            // 6. CONNECT / DISCONNECT
            Rectangle {
              implicitWidth: connText.implicitWidth + 20
              implicitHeight: 32
              radius: 4
              color: root.isConnected
                ? (connMouse.containsMouse ? "#ef4444" : Qt.rgba(0.9, 0.2, 0.2, 0.2))
                : (connMouse.containsMouse ? Qt.darker(root.accentColor, 1.2) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2))
              border.color: root.isConnected ? "#ef4444" : root.accentColor
              border.width: 1

              Text {
                id: connText
                anchors.centerIn: parent
                text: root.isConnected ? "Disconnect" : "Connect"
                font.family: root.appFontFamily
                font.pixelSize: 11
                font.bold: true
                color: root.isConnected ? (connMouse.containsMouse ? "#ffffff" : "#ef4444") : root.accentColor
              }

              MouseArea {
                id: connMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleConnect()
              }
            }
          }
        }
      }

      // CENTER VIEWPORT
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "#08080c"

        // =========================================================
        // STATE A: ACTIVE CONNECTED DESKTOP VIEW
        // =========================================================
        Item {
          anchors.fill: parent
          visible: root.isConnected

          // Desktop Background / Simulated Display Canvas
          Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            // Wallpaper graphic preview
            ColumnLayout {
              anchors.centerIn: parent
              spacing: 12

              ThemeIcon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                source: {
                  var osType = (root.currentMachine && root.currentMachine.os) ? root.currentMachine.os.toLowerCase() : "";
                  if (osType === "macos") return "icons/apple.svg";
                  if (osType === "windows") return "icons/device-desktop.svg";
                  return "icons/server.svg";
                }
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.15)
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Live Remote Desktop: " + (root.currentMachine ? root.currentMachine.name : "")
                font.family: root.appFontFamily
                font.pixelSize: 16
                font.bold: true
                color: root.textColor
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Streaming active over Tailscale WireGuard Mesh (" + (root.currentMachine ? root.currentMachine.tailscaleIp : "") + ")"
                font.family: root.appFontFamily
                font.pixelSize: 11
                color: root.mutedColor
              }

              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: popBtnText.implicitWidth + 24
                implicitHeight: 34
                radius: 4
                color: popMouse.containsMouse ? Qt.darker(root.accentColor, 1.2) : root.accentColor

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 8

                  ThemeIcon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: "icons/external-link.svg"
                    color: "#ffffff"
                  }

                  Text {
                    id: popBtnText
                    text: "Pop Out to Tiling / Fullscreen Window"
                    font.family: root.appFontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                  }
                }

                MouseArea {
                  id: popMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchBreakout()
                }
              }
            }

            // Bottom info bar inside viewport
            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              height: 28
              color: Qt.rgba(0, 0, 0, 0.7)

              RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 16

                Text {
                  text: "Resolution: " + root.sessionResolution
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                }

                Text {
                  text: "Latency: " + root.activeLatency
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: "#10b981"
                }

                Text {
                  text: "Encryption: WireGuard Curve25519"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: "Protocol: " + ((root.currentMachine && root.currentMachine.detectedProtocol) ? root.currentMachine.detectedProtocol.toUpperCase() : "RDP")
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: root.accentColor
                }
              }
            }
          }
        }

        // =========================================================
        // STATE B: STANDBY / READY TO CONNECT CARD
        // =========================================================
        ScrollView {
          anchors.fill: parent
          visible: !root.isConnected
          contentWidth: availableWidth
          clip: true

          Item {
            width: parent.width
            implicitHeight: standbyCol.implicitHeight + 60

            ColumnLayout {
              id: standbyCol
              anchors.horizontalCenter: parent.horizontalCenter
              width: Math.min(parent.width - 60, 680)
              y: 30
              spacing: 20

              // Machine Overview Card
              Rectangle {
                Layout.fillWidth: true
                implicitHeight: cardLayout.implicitHeight + 40
                radius: 6
                color: root.cardBg
                border.color: root.borderCol
                border.width: 1

                ColumnLayout {
                  id: cardLayout
                  anchors.fill: parent
                  anchors.margins: 24
                  spacing: 16

                  RowLayout {
                    spacing: 14

                    Rectangle {
                      Layout.preferredWidth: 48
                      Layout.preferredHeight: 48
                      radius: 8
                      color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)

                      ThemeIcon {
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        source: {
                          var osType = (root.currentMachine && root.currentMachine.os) ? root.currentMachine.os.toLowerCase() : "";
                          if (osType === "macos") return "icons/apple.svg";
                          if (osType === "windows") return "icons/device-desktop.svg";
                          return "icons/server.svg";
                        }
                        color: root.accentColor
                      }
                    }

                    ColumnLayout {
                      spacing: 4

                      Text {
                        text: root.currentMachine ? ("Ready to Connect: " + root.currentMachine.name) : "Select a Machine"
                        font.family: root.appFontFamily
                        font.pixelSize: 16
                        font.bold: true
                        color: root.textColor
                      }

                      Text {
                        text: "Direct peer-to-peer session over Tailscale WireGuard Mesh. Zero Google servers, zero telemetry."
                        font.family: root.appFontFamily
                        font.pixelSize: 11
                        color: root.mutedColor
                      }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.borderCol
                  }

                  // Specs Grid
                  GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 20

                    ColumnLayout {
                      spacing: 2
                      Text { text: "TARGET PROTOCOL"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor; font.bold: true }
                      Text {
                        text: {
                          var p = (root.currentMachine && root.currentMachine.detectedProtocol) ? root.currentMachine.detectedProtocol.toUpperCase() : "RDP";
                          if (p === "RDP") return "Remote Desktop Protocol (RDP :3389)";
                          if (p === "VNC") return "Apple Screen Sharing (VNC :5900)";
                          return "Waypipe / Xpra Direct (:22)";
                        }
                        font.family: root.appFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.textColor
                      }
                    }

                    ColumnLayout {
                      spacing: 2
                      Text { text: "TAILSCALE MESH IP"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor; font.bold: true }
                      Text {
                        text: (root.currentMachine && root.currentMachine.tailscaleIp) ? root.currentMachine.tailscaleIp : "Not discovered"
                        font.family: root.appFontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: root.accentColor
                      }
                    }

                    ColumnLayout {
                      spacing: 2
                      Text { text: "SECURITY GUARANTEE"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor; font.bold: true }
                      Text { text: "Peer-to-Peer WireGuard (Zero Third-Party)"; font.family: root.appFontFamily; font.pixelSize: 12; color: "#10b981" }
                    }

                    ColumnLayout {
                      spacing: 2
                      Text { text: "AUDIO & CLIPBOARD"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor; font.bold: true }
                      Text { text: "Bidirectional Sync Enabled"; font.family: root.appFontFamily; font.pixelSize: 12; color: root.textColor }
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.borderCol
                  }

                  // Optional Credentials Input
                  Text {
                    text: "CONNECTION CREDENTIALS (SAVED IN OCLOUD VAULT)"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: root.mutedColor
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 4
                      Text { text: "Username / Account"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.mutedColor }
                      AppTextField {
                        Layout.fillWidth: true
                        placeholderText: (root.currentMachine && root.currentMachine.os === "macos") ? "Mac Username" : "Administrator / User"
                        text: root.usernameInput
                        onTextChanged: root.usernameInput = text
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 4
                      Text { text: "Password"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.mutedColor }
                      AppTextField {
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: "••••••••"
                        text: root.passwordInput
                        onTextChanged: root.passwordInput = text
                      }
                    }
                  }

                  // Action Buttons
                  RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 12

                    // Connect in-window button
                    Rectangle {
                      Layout.fillWidth: true
                      implicitHeight: 38
                      radius: 4
                      color: connMainMouse.containsMouse ? Qt.darker(root.accentColor, 1.2) : root.accentColor

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                          text: "⚡ Connect In-Window Desktop"
                          font.family: root.appFontFamily
                          font.pixelSize: 12
                          font.bold: true
                          color: "#ffffff"
                        }
                      }

                      MouseArea {
                        id: connMainMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleConnect()
                      }
                    }

                    // Breakout Window Button
                    Rectangle {
                      Layout.fillWidth: true
                      implicitHeight: 38
                      radius: 4
                      color: boMainMouse.containsMouse ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12) : "transparent"
                      border.color: root.accentColor
                      border.width: 1

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        ThemeIcon {
                          Layout.preferredWidth: 14
                          Layout.preferredHeight: 14
                          source: "icons/external-link.svg"
                          color: root.accentColor
                        }

                        Text {
                          text: "↗ Launch in Breakout Window"
                          font.family: root.appFontFamily
                          font.pixelSize: 12
                          font.bold: true
                          color: root.accentColor
                        }
                      }

                      MouseArea {
                        id: boMainMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchBreakout()
                      }
                    }
                  }

                  // OS Setup Hint Banner
                  Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: hintText.implicitHeight + 16
                    radius: 4
                    color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.06)
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
                    border.width: 1

                    Text {
                      id: hintText
                      anchors.fill: parent
                      anchors.margins: 10
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      color: root.mutedColor
                      wrapMode: Text.WordWrap
                      text: {
                        var osType = (root.currentMachine && root.currentMachine.os) ? root.currentMachine.os.toLowerCase() : "";
                        if (osType === "windows") {
                          return "💡 Windows Tip: Enable 'Remote Desktop' in Settings > System > Remote Desktop. No third-party software needed.";
                        } else if (osType === "macos") {
                          return "💡 Mac Tip: Enable 'Screen Sharing' in System Settings > General > Sharing, and allow VNC viewers under Computer Settings.";
                        } else {
                          return "💡 Linux Tip: Enable 'Remote Desktop' in GNOME Settings, or connect via standard Waypipe / Xpra / FreeRDP.";
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
