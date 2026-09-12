import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
  id: window
  visible: true
  width: 1120
  height: 740
  minimumWidth: 960
  minimumHeight: 640
  title: "Ocloud — Cloud Storage & Compute Manager"
  color: "#080e18"

  // Global Design Tokens
  readonly property color bgDark: "#080e18"
  readonly property color cardBg: "#0f172a"
  readonly property color cardBgAlt: "#131e36"
  readonly property color borderSubtle: "#1e293b"
  readonly property color borderActive: "#334155"
  readonly property color textPrimary: "#f8fafc"
  readonly property color textSecondary: "#94a3b8"
  readonly property color textMuted: "#64748b"
  readonly property color accentSky: "#38bdf8"
  readonly property color accentHover: "#0284c7"
  readonly property color homeGreen: "#10b981"
  readonly property color warningAmber: "#f59e0b"
  readonly property color dangerRed: "#ef4444"

  // Reactive State
  property var statusData: ({})
  property var serverList: []
  property var storageBox: ({})
  property var customStorage: []
  property var backupInfo: ({})
  property string activeTab: (typeof initialTab !== "undefined" && initialTab) ? initialTab : "fleet"

  Shortcut { sequence: "Alt+1"; onActivated: activeTab = "fleet" }
  Shortcut { sequence: "Alt+2"; onActivated: activeTab = "storage" }
  Shortcut { sequence: "Alt+3"; onActivated: activeTab = "apps" }
  Shortcut { sequence: "Alt+4"; onActivated: activeTab = "backups" }
  Shortcut { sequence: "Alt+5"; onActivated: activeTab = "settings" }

  function reloadAll() {
    var raw = ocloud.fetchStatus();
    try {
      var data = JSON.parse(raw);
      statusData = data;
      serverList = data.servers || [];
      storageBox = (data.storage && data.storage.storage_box) || {};
      customStorage = (data.storage && data.storage.custom_storage) || [];
      backupInfo = data.backups || {};
    } catch (e) {
      console.log("Error parsing status data: " + e);
    }
  }

  Component.onCompleted: {
    reloadAll();
  }

  Connections {
    target: ocloud
    function onStatusUpdated(jsonStr) {
      try {
        var data = JSON.parse(jsonStr);
        statusData = data;
        serverList = data.servers || [];
        storageBox = (data.storage && data.storage.storage_box) || {};
        customStorage = (data.storage && data.storage.custom_storage) || [];
        backupInfo = data.backups || {};
      } catch (e) {}
    }
  }

  // Top Titlebar / Header
  header: Rectangle {
    height: 56
    color: "#0b1325"
    border.color: borderSubtle
    border.width: 1

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 20
      anchors.rightMargin: 20
      spacing: 16

      // Brand Logo
      RowLayout {
        spacing: 10
        Rectangle {
          width: 30
          height: 30
          radius: 8
          gradient: Gradient {
            GradientStop { position: 0.0; color: "#0284c7" }
            GradientStop { position: 1.0; color: "#0369a1" }
          }
          Text {
            anchors.centerIn: parent
            text: "☁"
            font.pixelSize: 16
            color: "#ffffff"
          }
        }
        Text {
          text: "Ocloud"
          font.pixelSize: 17
          font.bold: true
          color: textPrimary
        }
        Text {
          text: "Cloud Storage & Compute"
          font.pixelSize: 12
          color: textMuted
        }
      }

      Item { Layout.fillWidth: true }

      // Live Vault Status Badge
      Rectangle {
        height: 28
        width: vaultText.implicitWidth + 24
        radius: 14
        color: "#0e2038"
        border.color: "#1e3a8a"
        border.width: 1

        RowLayout {
          anchors.centerIn: parent
          spacing: 6
          Text { text: "🔐"; font.pixelSize: 11 }
          Text {
            id: vaultText
            text: "Vault Encrypted (AES-256)"
            font.pixelSize: 11
            font.bold: true
            color: accentSky
          }
        }
      }

      // Refresh Button
      Button {
        id: refreshBtn
        text: "↻ Refresh Fleet"
        background: Rectangle {
          radius: 6
          color: refreshBtn.hovered ? "#1e293b" : "#0f172a"
          border.color: borderSubtle
        }
        contentItem: Text {
          text: refreshBtn.text
          color: textPrimary
          font.pixelSize: 12
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        onClicked: reloadAll()
      }
    }
  }

  // Main Container: Sidebar + Content
  RowLayout {
    anchors.fill: parent
    spacing: 0

    // Left Navigation Sidebar
    Rectangle {
      Layout.fillHeight: true
      Layout.preferredWidth: 210
      color: "#070c16"
      border.color: borderSubtle
      border.width: 1

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // Nav Buttons
        Repeater {
          model: [
            { id: "fleet", name: "Compute Fleet", icon: "🌐", count: serverList.length },
            { id: "storage", name: "Storage & Drives", icon: "💾", count: storageBox.mounted ? 1 : 0 },
            { id: "apps", name: "Waypipe Apps", icon: "🎮", count: 3 },
            { id: "backups", name: "Backups", icon: "🔄", count: 0 },
            { id: "settings", name: "Vault & Latency", icon: "⚙️", count: 0 }
          ]

          delegate: Rectangle {
            Layout.fillWidth: true
            height: 44
            radius: 8
            color: activeTab === modelData.id ? "#13233f" : navMouse.containsMouse ? "#0d1527" : "transparent"
            border.color: activeTab === modelData.id ? "#1d4ed8" : "transparent"
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 12
              spacing: 12

              Text {
                text: modelData.icon
                font.pixelSize: 16
              }

              Text {
                text: modelData.name
                font.pixelSize: 13
                font.bold: activeTab === modelData.id
                color: activeTab === modelData.id ? textPrimary : textSecondary
              }

              Item { Layout.fillWidth: true }

              Rectangle {
                visible: modelData.count > 0 && (modelData.id === "fleet" || modelData.id === "storage")
                height: 18
                width: badgeText.implicitWidth + 12
                radius: 9
                color: modelData.id === "fleet" ? "#0284c7" : homeGreen
                Text {
                  id: badgeText
                  anchors.centerIn: parent
                  text: String(modelData.count)
                  font.pixelSize: 10
                  font.bold: true
                  color: "#ffffff"
                }
              }
            }

            MouseArea {
              id: navMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: activeTab = modelData.id
            }
          }
        }

        Item { Layout.fillHeight: true }

        // Host Info Card at Bottom of Sidebar
        Rectangle {
          Layout.fillWidth: true
          height: 64
          radius: 8
          color: cardBg
          border.color: borderSubtle

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2
            RowLayout {
              Text { text: "💻"; font.pixelSize: 12 }
              Text { text: "Local Machine"; font.pixelSize: 11; font.bold: true; color: textPrimary }
            }
            Text {
              text: "Omarchy Linux (aarch64)"
              font.pixelSize: 10
              color: textMuted
            }
          }
        }
      }
    }

    // Right Multi-Tab Content View
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: bgDark

      StackLayout {
        anchors.fill: parent
        currentIndex: {
          if (activeTab === "fleet") return 0;
          if (activeTab === "storage") return 1;
          if (activeTab === "apps") return 2;
          if (activeTab === "backups") return 3;
          if (activeTab === "settings") return 4;
          return 0;
        }

        FleetView { id: fleetView }
        StorageView { id: storageView }
        AppSuiteView { id: appSuiteView }
        BackupView { id: backupView }
        SettingsView { id: settingsView }
      }
    }
  }

  // Global Ephemeral Consent Modal
  EphemeralConsentModal {
    id: consentModal
    onConfirmed: function(serverId) {
      ocloud.mountEphemeralVm(serverId);
    }
  }

  // Global Add Node Modal
  AddNodeModal {
    id: addNodeModal
    onNodeAdded: reloadAll()
  }

  // Global Procure VM Modal
  ProcureModal {
    id: procureModal
    onServerProcured: reloadAll()
  }
}
