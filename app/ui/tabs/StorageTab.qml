import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  property var rootCapacities: ({})
  property var cloudAccounts: []
  property var mountedShares: []

  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color borderCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333"

  function refreshCapacities() {
    try {
      var raw = ocloud.getDriveCapacities();
      rootCapacities = JSON.parse(raw || "{}");
    } catch (e) {}
  }

  function reloadCloudAccounts() {
    try {
      cloudAccounts = JSON.parse(ocloud.fetchCloudAccounts() || "[]");
    } catch (e) {
      cloudAccounts = [];
    }
  }

  function reloadMountedShares() {
    try {
      mountedShares = JSON.parse(ocloud.getNetworkShares() || "[]");
    } catch (e) {
      mountedShares = [];
    }
  }

  Component.onCompleted: {
    refreshCapacities();
    reloadCloudAccounts();
    reloadMountedShares();
  }

  onVisibleChanged: {
    if (visible) {
      root.refreshCapacities();
      root.reloadCloudAccounts();
      root.reloadMountedShares();
    }
  }

  Connections {
    target: ocloud
    function onCloudAccountsUpdated(jsonStr) {
      try {
        root.cloudAccounts = JSON.parse(jsonStr);
      } catch(e) {
        root.cloudAccounts = [];
      }
    }
    function onNetworkSharesUpdated(jsonStr) {
      try {
        root.mountedShares = JSON.parse(jsonStr);
      } catch(e) {
        root.mountedShares = [];
      }
    }
  }

  ScrollView {
    id: storageScroll
    anchors.fill: parent
    anchors.margins: 16
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 12

      // =========================================================
      // STORAGE HEADER
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "STORAGE & DRIVES"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            letterSpacing: 1.2
          }

          Text {
            text: (1 + root.cloudAccounts.length + root.mountedShares.length) + " storage volumes available"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        // Refresh Disks Button
        Rectangle {
          implicitWidth: refText.implicitWidth + 14
          implicitHeight: 24
          radius: 2
          color: refMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: refMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          Text {
            id: refText
            anchors.centerIn: parent
            text: "Refresh"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: refMouse.containsMouse ? root.accentColor : root.textColor
          }

          MouseArea {
            id: refMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.refreshCapacities();
              root.reloadCloudAccounts();
              root.reloadMountedShares();
              ocloud.listComputeServers();
            }
          }
        }

        // Add Cloud Storage Button
        Rectangle {
          implicitWidth: addText.implicitWidth + 16
          implicitHeight: 24
          radius: 2
          color: addMouse.containsMouse ? root.accentColor : "transparent"
          border.color: root.accentColor
          border.width: 1

          Text {
            id: addText
            anchors.centerIn: parent
            text: "+ Add Storage"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: addMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
              : root.accentColor
          }

          MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: activeTab = "accounts"
          }
        }
      }

      // Thin separator hairline
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.borderCol
      }

      // =========================================================
      // 1. LOCAL SYSTEM STORAGE DISK
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          text: "LOCAL STORAGE"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.mutedColor
        }

        NativeDriveCard {
          driveName: "System Volume"
          driveType: "Internal NVMe Storage (/)"
          iconSource: "icons/hard-drive.svg"
          mountPath: "/"
          capacityText: {
            var rootData = rootCapacities["/"];
            if (rootData && rootData.free && rootData.total) {
              var freeGb = (rootData.free / (1024*1024*1024)).toFixed(1);
              var totalGb = (rootData.total / (1024*1024*1024)).toFixed(1);
              return freeGb + " GB free of " + totalGb + " GB";
            }
            return "Internal Drive";
          }
          usedPercent: {
            var rootData = rootCapacities["/"];
            if (rootData && rootData.used_percent) {
              return rootData.used_percent / 100.0;
            }
            return 0.35;
          }
          isMounted: true
          showDisconnect: false
          showSettings: false
          onOpenClicked: ocloud.openCloudFolder("/")
        }
      }

      // =========================================================
      // 2. CONNECTED CLOUD DRIVES
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.cloudAccounts.length > 0

        Text {
          text: "CONNECTED CLOUD DRIVES (" + root.cloudAccounts.length + ")"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.mutedColor
        }

        Repeater {
          model: root.cloudAccounts

          delegate: NativeDriveCard {
            driveName: modelData.providerName || modelData.name
            driveType: modelData.type || "Cloud Storage"
            iconSource: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : (modelData.iconSvg || "icons/cloud.svg")
            mountPath: modelData.mountPath || ""
            capacityText: modelData.accountDetail || "Mounted Remote"
            isMounted: true
            showDisconnect: true
            showSettings: false
            onOpenClicked: {
              if (modelData.mountPath) {
                ocloud.openCloudFolder(modelData.mountPath);
              } else {
                ocloud.openCloudFolder(modelData.name);
              }
            }
            onUnmountClicked: {
              if (modelData.name) {
                ocloud.disconnectCloudAccount(modelData.name);
              }
            }
            onDisconnectClicked: {
              if (modelData.name) {
                ocloud.disconnectCloudAccount(modelData.name);
              }
            }
          }
        }
      }

      // =========================================================
      // 3. MOUNTED NETWORK SHARES
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.mountedShares.length > 0

        Text {
          text: "NETWORK SHARES (" + root.mountedShares.length + ")"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.mutedColor
        }

        Repeater {
          model: root.mountedShares

          delegate: NativeDriveCard {
            driveName: modelData.name || "Network Share"
            driveType: (modelData.protocol || "SMB") + " · " + (modelData.host || "")
            iconSource: "icons/network.svg"
            mountPath: modelData.mountPath || ""
            capacityText: "Active Share"
            isMounted: true
            showDisconnect: true
            showSettings: false
            onOpenClicked: {
              if (modelData.mountPath) {
                ocloud.openCloudFolder(modelData.mountPath);
              }
            }
            onUnmountClicked: {
              if (modelData.name) {
                ocloud.unmountNetworkShare(modelData.name);
              }
            }
            onDisconnectClicked: {
              if (modelData.name) {
                ocloud.unmountNetworkShare(modelData.name);
              }
            }
          }
        }
      }
    }
  }
}
