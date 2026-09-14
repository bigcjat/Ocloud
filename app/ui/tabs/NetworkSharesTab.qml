import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

  property var mountedShares: []
  property var discoveredDevices: []
  property bool isScanning: false
  property string selectedShare: ""

  function refreshShares() {
    try {
      mountedShares = JSON.parse(ocloud.getNetworkShares());
    } catch (e) {
      mountedShares = [];
    }
  }

  function startScan() {
    isScanning = true;
    ocloud.scanNetworkSharesAsync();
  }

  Connections {
    target: ocloud
    function onNetworkSharesScanned(jsonStr) {
      try {
        discoveredDevices = JSON.parse(jsonStr);
      } catch (e) {
        discoveredDevices = [];
      }
      isScanning = false;
    }
    function onNetworkSharesUpdated(jsonStr) {
      try {
        mountedShares = JSON.parse(jsonStr);
      } catch (e) {
        mountedShares = [];
      }
    }
  }

  Component.onCompleted: {
    refreshShares();
    startScan();
  }

  ScrollView {
    anchors.fill: parent
    anchors.margins: 16
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 12

      // =========================================================
      // HEADER
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "NETWORK SHARES (SMB / CIFS)"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            letterSpacing: 1.2
          }

          Text {
            text: root.mountedShares.length + " active mounts · " + root.discoveredDevices.length + " discovered"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        // Scan Network Button
        Rectangle {
          implicitWidth: scanText.implicitWidth + 16
          implicitHeight: 24
          radius: 2
          color: scanMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: scanMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          Text {
            id: scanText
            anchors.centerIn: parent
            text: root.isScanning ? "Scanning..." : "Scan Network"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: scanMouse.containsMouse ? root.accentColor : root.textColor
          }

          MouseArea {
            id: scanMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root.isScanning
            onClicked: root.startScan()
          }
        }

        // Connect to Server Button
        Rectangle {
          implicitWidth: connText.implicitWidth + 16
          implicitHeight: 24
          radius: 2
          color: connMouse.containsMouse ? root.accentColor : "transparent"
          border.color: root.accentColor
          border.width: 1

          Text {
            id: connText
            anchors.centerIn: parent
            text: "+ Connect to Server"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: connMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
              : root.accentColor
          }

          MouseArea {
            id: connMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: smbConnectModal.openModal("", "", "")
          }
        }
      }

      // Thin separator
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.borderCol
      }

      // =========================================================
      // MOUNTED SHARES (IF ANY)
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.mountedShares.length > 0

        Text {
          text: "MOUNTED SHARES"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.mutedColor
          letterSpacing: 1.2
        }

        Repeater {
          model: root.mountedShares
          delegate: NativeDriveCard {
            driveName: modelData.name || "Network Share"
            driveType: "Network"
            iconSource: "icons/network.svg"
            mountPath: modelData.mountPath || "~/NetworkShare"
            capacityText: modelData.capacityText || "Active SMB Mount"
            usedPercent: modelData.usedPercent !== undefined ? modelData.usedPercent : -1
            isMounted: true
            statusVariant: "success"
            statusText: "Connected"
            onOpenClicked: ocloud.openCloudFolder(mountPath)
            onUnmountClicked: ocloud.unmountCloudAccount(mountPath)
            onSettingsClicked: ocloud.openCloudFolder(mountPath)
          }
        }
      }

      // =========================================================
      // DISCOVERED COMPUTERS & SERVERS
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "DISCOVERED DEVICES"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            letterSpacing: 1.2
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.isScanning ? "Scanning local network & Tailscale..." : (root.discoveredDevices.length + " detected")
            font.family: root.appFontFamily
            font.pixelSize: 10
            color: root.mutedColor
          }
        }

        // Empty state
        Rectangle {
          Layout.fillWidth: true
          height: 50
          radius: 2
          color: "transparent"
          border.color: root.borderCol
          border.width: 1
          visible: root.discoveredDevices.length === 0

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Rectangle {
              width: 6
              height: 6
              radius: 3
              color: root.isScanning ? root.accentColor : root.mutedColor
            }

            Text {
              Layout.fillWidth: true
              text: root.isScanning
                ? "Scanning local subnet & Tailscale for active SMB shares..."
                : "No network shares detected automatically on local network."
              font.family: root.appFontFamily
              font.pixelSize: 11
              color: root.mutedColor
            }

            Rectangle {
              visible: !root.isScanning
              implicitWidth: manConnText.implicitWidth + 12
              implicitHeight: 22
              radius: 2
              color: manConnMouse.containsMouse ? root.accentColor : "transparent"
              border.color: root.accentColor
              border.width: 1

              Text {
                id: manConnText
                anchors.centerIn: parent
                text: "Connect Manually"
                font.family: root.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: manConnMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                  : root.accentColor
              }

              MouseArea {
                id: manConnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: smbConnectModal.openModal("", "", "")
              }
            }
          }
        }

        // Single-column Discovered Device Rows
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: root.discoveredDevices.length > 0

          Repeater {
            model: root.discoveredDevices
            delegate: Rectangle {
              Layout.fillWidth: true
              implicitHeight: 38
              radius: 2
              color: devMouse.containsMouse
                ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : root.cardBg)
                : root.cardBg
              border.color: devMouse.containsMouse ? root.accentColor : root.borderCol
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Status dot
                Rectangle {
                  width: 6
                  height: 6
                  radius: 3
                  color: modelData.isOnline
                    ? ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
                    : root.mutedColor
                }

                // Sharp Theme Icon
                ThemeIcon {
                  width: 14
                  height: 14
                  source: modelData.isMac ? "icons/monitor.svg" : "icons/server.svg"
                  color: root.textColor
                }

                // Name & Host
                Text {
                  text: modelData.name || modelData.host
                  font.family: root.appFontFamily
                  font.pixelSize: 11
                  font.bold: true
                  color: root.textColor
                  elide: Text.ElideRight
                  Layout.maximumWidth: 160
                }

                // IP / Share detail
                Text {
                  Layout.fillWidth: true
                  text: modelData.host + (modelData.shareHint ? (" · " + modelData.shareHint) : "")
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                  elide: Text.ElideRight
                }

                // Connect Action
                Rectangle {
                  implicitWidth: btnText.implicitWidth + 14
                  implicitHeight: 22
                  radius: 2
                  color: btnMouse.containsMouse ? root.accentColor : "transparent"
                  border.color: root.accentColor
                  border.width: 1

                  Text {
                    id: btnText
                    anchors.centerIn: parent
                    text: "Connect"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: btnMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                      : root.accentColor
                  }

                  MouseArea {
                    id: btnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: smbConnectModal.openModal(modelData.host, modelData.name || "", modelData.defaultShare || "")
                  }
                }
              }

              MouseArea {
                id: devMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }
            }
          }
        }
      }
    }
  }

  // =========================================================
  // SMB CONNECT MODAL
  // =========================================================
  Rectangle {
    id: smbConnectModal
    visible: false
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.75)
    z: 2000

    property string targetHost: ""
    property string targetName: ""

    function openModal(host, name, defaultShare) {
      targetHost = host;
      targetName = name;
      smbHostField.text = host || "";
      smbShareField.text = defaultShare || "Shared";
      smbUserField.text = "";
      smbPassField.text = "";
      smbNameField.text = name ? (name.toLowerCase().replace(/[^a-z0-9]/g, "-") + "-share") : "network-share";
      smbConnectModal.visible = true;
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }

    Rectangle {
      width: Math.min(parent.width - 24, 440)
      implicitHeight: smbModalCol.implicitHeight + 28
      radius: 2
      color: root.cardBg
      border.color: root.borderCol
      border.width: 1
      anchors.centerIn: parent

      ColumnLayout {
        id: smbModalCol
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          ThemeIcon {
            width: 14
            height: 14
            source: "icons/network.svg"
            color: root.textColor
          }

          Text {
            text: "CONNECT TO NETWORK SHARE"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.textColor
            letterSpacing: 1.2
          }

          Item { Layout.fillWidth: true }

          Rectangle {
            width: 20
            height: 20
            radius: 2
            color: "transparent"
            border.color: closeMouse.containsMouse ? root.accentColor : root.borderCol

            Text {
              anchors.centerIn: parent
              text: "✕"
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: closeMouse.containsMouse ? root.accentColor : root.mutedColor
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: smbConnectModal.visible = false
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: root.borderCol
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 8

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text { text: "SERVER IP OR HOSTNAME"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
            TextField {
              id: smbHostField
              Layout.fillWidth: true
              implicitHeight: 26
              font.family: root.appFontFamily
              font.pixelSize: 11
              placeholderText: "e.g. 192.168.1.100"
              color: root.textColor
              background: Rectangle { color: "transparent"; border.color: root.borderCol; radius: 2 }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text { text: "SHARE FOLDER NAME"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
            TextField {
              id: smbShareField
              Layout.fillWidth: true
              implicitHeight: 26
              font.family: root.appFontFamily
              font.pixelSize: 11
              placeholderText: "e.g. Shared, Public, or Mac-Drive"
              color: root.textColor
              background: Rectangle { color: "transparent"; border.color: root.borderCol; radius: 2 }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3
              Text { text: "USERNAME"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              TextField {
                id: smbUserField
                Layout.fillWidth: true
                implicitHeight: 26
                font.family: root.appFontFamily
                font.pixelSize: 11
                placeholderText: "Username"
                color: root.textColor
                background: Rectangle { color: "transparent"; border.color: root.borderCol; radius: 2 }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3
              Text { text: "PASSWORD"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              TextField {
                id: smbPassField
                Layout.fillWidth: true
                implicitHeight: 26
                echoMode: TextInput.Password
                font.family: root.appFontFamily
                font.pixelSize: 11
                placeholderText: "Password"
                color: root.textColor
                background: Rectangle { color: "transparent"; border.color: root.borderCol; radius: 2 }
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text { text: "MOUNT IDENTIFIER"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
            TextField {
              id: smbNameField
              Layout.fillWidth: true
              implicitHeight: 26
              font.family: root.appFontFamily
              font.pixelSize: 11
              placeholderText: "e.g. mac-share"
              color: root.accentColor
              background: Rectangle { color: "transparent"; border.color: root.borderCol; radius: 2 }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Item { Layout.fillWidth: true }

          Rectangle {
            implicitWidth: cancelText.implicitWidth + 14
            implicitHeight: 24
            radius: 2
            color: "transparent"
            border.color: root.borderCol

            Text {
              id: cancelText
              anchors.centerIn: parent
              text: "Cancel"
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: root.textColor
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: smbConnectModal.visible = false
            }
          }

          Rectangle {
            implicitWidth: mountText.implicitWidth + 14
            implicitHeight: 24
            radius: 2
            color: mountMouse.containsMouse ? root.accentColor : "transparent"
            border.color: root.accentColor
            enabled: smbHostField.text.trim().length > 0 && smbShareField.text.trim().length > 0
            opacity: enabled ? 1.0 : 0.4

            Text {
              id: mountText
              anchors.centerIn: parent
              text: "Mount Share"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: mountMouse.containsMouse
                ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                : root.accentColor
            }

            MouseArea {
              id: mountMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                ocloud.mountSmbShare(
                  smbHostField.text.trim(),
                  smbShareField.text.trim(),
                  smbUserField.text.trim(),
                  smbPassField.text.trim(),
                  smbNameField.text.trim() || "network-share"
                );
                smbConnectModal.visible = false;
                root.refreshShares();
              }
            }
          }
        }
      }
    }
  }
}
