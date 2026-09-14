import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

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
    anchors.margins: root.isNarrow ? 12 : 20
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 20

      // Section Header
      AppHeader {
        title: "Network Shares (SMB / CIFS)"
        subtitle: "Discover, browse, and mount shared folders from Macs, Windows PCs, and home NAS devices"

        RowLayout {
          spacing: 8

          AppButton {
            text: root.isScanning ? "Scanning..." : "Scan Network"
            iconSource: "icons/refresh.svg"
            variant: "secondary"
            enabled: !root.isScanning
            onClicked: root.startScan()
          }

          AppButton {
            text: "Connect to Server..."
            iconSource: "icons/plus.svg"
            variant: "primary"
            onClicked: smbConnectModal.openModal("", "", "")
          }
        }
      }

      // Banner: How Network Sharing Works in Omarchy
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: bannerCol.implicitHeight + 24
        radius: 12
        color: "#0a1529"
        border.color: "#182a4a"
        border.width: 1

        RowLayout {
          id: bannerCol
          anchors.fill: parent
          anchors.margins: 14
          spacing: 14

          Rectangle {
            Layout.preferredWidth: 38
            Layout.preferredHeight: 38
            radius: 8
            color: "#142542"
            Image {
              anchors.centerIn: parent
              width: 20
              height: 20
              source: Qt.resolvedUrl("../icons/network.svg")
              fillMode: Image.PreserveAspectFit
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
              text: "Local & Tailscale Network File Sharing"
              font.pixelSize: 13
              font.bold: true
              color: "#38bdf8"
            }
            Text {
              text: "Connect to shared folders on your Mac, Windows PC, or NAS directly over your Wi-Fi or Tailscale network. Mounts appear in your file manager as local folders."
              font.pixelSize: 11
              color: "#94a3b8"
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }
      }

      // ==========================================
      // ACTIVE MOUNTED SHARES SECTION
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        visible: root.mountedShares.length > 0

        Text {
          text: "Mounted Network Shares (" + root.mountedShares.length + ")"
          font.pixelSize: 15
          font.bold: true
          color: "#f8fafc"
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

      // ==========================================
      // DISCOVERED COMPUTERS & SERVERS
      // ==========================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 12

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Discovered Computers & Servers"
            font.pixelSize: 15
            font.bold: true
            color: "#f8fafc"
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.isScanning ? "Searching network..." : (root.discoveredDevices.length + " devices found")
            font.pixelSize: 11
            color: "#94a3b8"
          }
        }

        // Scanning indicator if empty
        Rectangle {
          Layout.fillWidth: true
          height: 90
          radius: 12
          color: "#0f172a"
          border.color: "#1e293b"
          visible: root.discoveredDevices.length === 0

          ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            Text {
              text: root.isScanning ? "Scanning local subnet & Tailscale for file shares..." : "No SMB shares detected automatically"
              font.pixelSize: 13
              font.bold: true
              color: "#94a3b8"
              horizontalAlignment: Text.AlignHCenter
            }
            Text {
              text: root.isScanning ? "Checking mDNS, Bonjour, and SMB ports" : "Click 'Connect to Server...' to enter your computer's IP address directly"
              font.pixelSize: 11
              color: "#64748b"
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }

        Item {
          Layout.fillWidth: true
          implicitHeight: devGrid.height
          visible: root.discoveredDevices.length > 0

          Grid {
            id: devGrid
            width: parent.width
            columns: 2
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
              model: root.discoveredDevices
              delegate: Rectangle {
                width: Math.max(100, Math.floor((devGrid.width - 14) / 2))
                height: 104
                radius: 12
                color: "#0f172a"
                border.color: "#1e293b"

              // Card contents
              Item {
                anchors.fill: parent
                anchors.margins: 14

                // Device Icon
                Rectangle {
                  id: devIconRect
                  anchors.left: parent.left
                  anchors.top: parent.top
                  width: 40
                  height: 40
                  radius: 8
                  color: "#141e30"
                  border.color: "#1e293b"

                  Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: modelData.isMac ? Qt.resolvedUrl("../icons/monitor.svg") : Qt.resolvedUrl("../icons/server.svg")
                    fillMode: Image.PreserveAspectFit
                  }
                }

                // Connect Button (PINNED TO RIGHT EDGE)
                AppButton {
                  id: connBtn
                  anchors.right: parent.right
                  anchors.top: parent.top
                  text: "Connect"
                  variant: "primary"
                  onClicked: smbConnectModal.openModal(modelData.host, modelData.name || "", modelData.defaultShare || "")
                }

                // Middle Text & Badge (Between Icon and Connect Button)
                ColumnLayout {
                  anchors.left: devIconRect.right
                  anchors.leftMargin: 12
                  anchors.right: connBtn.left
                  anchors.rightMargin: 12
                  anchors.top: parent.top
                  spacing: 3

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                      text: modelData.name || modelData.host
                      font.pixelSize: 14
                      font.bold: true
                      color: "#f8fafc"
                      elide: Text.ElideRight
                      Layout.maximumWidth: 150
                    }

                    AppBadge {
                      variant: modelData.isOnline ? "success" : "neutral"
                      text: modelData.os || "SMB"
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: "IP: " + modelData.host + (modelData.shareHint ? (" • " + modelData.shareHint) : "")
                    font.pixelSize: 11
                    color: "#94a3b8"
                    elide: Text.ElideRight
                  }
                }

                // Bottom Status Bar
                RowLayout {
                  anchors.left: parent.left
                  anchors.bottom: parent.bottom
                  spacing: 6

                  Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: modelData.isOnline ? "#22c55e" : "#94a3b8"
                  }

                  Text {
                    text: modelData.isOnline ? "SMB Service Detected (Port 445 Open)" : "Peer online via Tailscale / LAN"
                    font.pixelSize: 10
                    color: modelData.isOnline ? "#22c55e" : "#94a3b8"
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

  // ==========================================
  // SMB CONNECT MODAL
  // ==========================================
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
      width: Math.min(parent.width - 48, 500)
      implicitHeight: smbModalCol.implicitHeight + 48
      radius: 16
      color: "#0b1325"
      border.color: "#1e293b"
      anchors.centerIn: parent

      ColumnLayout {
        id: smbModalCol
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Image {
            width: 24
            height: 24
            source: Qt.resolvedUrl("../icons/network.svg")
            fillMode: Image.PreserveAspectFit
          }
          ColumnLayout {
            spacing: 2
            Text {
              text: "Connect to Network Share"
              font.pixelSize: 16
              font.bold: true
              color: "#f8fafc"
            }
            Text {
              text: "Mount a shared folder over SMB / CIFS into ~/NetworkShares"
              font.pixelSize: 11
              color: "#94a3b8"
            }
          }
          Item { Layout.fillWidth: true }
          AppButton {
            text: "✕"
            variant: "secondary"
            onClicked: smbConnectModal.visible = false
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 10

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "Server IP or Hostname"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
            TextField {
              id: smbHostField
              Layout.fillWidth: true
              placeholderText: "e.g. 192.168.1.100 or chriss-macbook-air"
              color: "#f8fafc"
              background: Rectangle { color: "#0f172a"; border.color: "#1e293b"; radius: 6 }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "Share Folder Name"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
            TextField {
              id: smbShareField
              Layout.fillWidth: true
              placeholderText: "e.g. Shared, Public, or Mac-Drive"
              color: "#f8fafc"
              background: Rectangle { color: "#0f172a"; border.color: "#1e293b"; radius: 6 }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "Username"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
              TextField {
                id: smbUserField
                Layout.fillWidth: true
                placeholderText: "Computer username"
                color: "#f8fafc"
                background: Rectangle { color: "#0f172a"; border.color: "#1e293b"; radius: 6 }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "Password"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
              TextField {
                id: smbPassField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Login password"
                color: "#f8fafc"
                background: Rectangle { color: "#0f172a"; border.color: "#1e293b"; radius: 6 }
              }
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: "Mount Name"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
            TextField {
              id: smbNameField
              Layout.fillWidth: true
              placeholderText: "e.g. mac-share"
              color: "#38bdf8"
              background: Rectangle { color: "#0f172a"; border.color: "#1e293b"; radius: 6 }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Item { Layout.fillWidth: true }
          AppButton {
            text: "Cancel"
            variant: "secondary"
            onClicked: smbConnectModal.visible = false
          }
          AppButton {
            text: "Connect & Mount"
            variant: "primary"
            enabled: smbHostField.text.trim().length > 0 && smbShareField.text.trim().length > 0
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
