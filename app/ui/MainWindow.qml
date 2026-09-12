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
  property bool isBusy: false
  property string busyMessage: ""

  Shortcut { sequence: "Alt+1"; onActivated: activeTab = "fleet" }
  Shortcut { sequence: "Alt+2"; onActivated: activeTab = "workloads" }
  Shortcut { sequence: "Alt+3"; onActivated: activeTab = "storage" }
  Shortcut { sequence: "Alt+4"; onActivated: activeTab = "apps" }
  Shortcut { sequence: "Alt+5"; onActivated: activeTab = "backups" }
  Shortcut { sequence: "Alt+6"; onActivated: activeTab = "settings" }

  function reloadAll() {
    ocloud.refreshStatusAsync();
  }

  Component.onCompleted: {
    var raw = ocloud.fetchStatus();
    try {
      var data = JSON.parse(raw);
      statusData = data;
      serverList = data.servers || [];
      storageBox = (data.storage && data.storage.storage_box) || {};
      customStorage = (data.storage && data.storage.custom_storage) || [];
      backupInfo = data.backups || {};
    } catch (e) {}

    if (typeof openModalOnStart !== "undefined" && openModalOnStart === "taskManager") {
      var srv = (serverList && serverList.length > 0) ? serverList[0] : { name: "omarchy-companion", ipv4: "167.233.151.104", provider: "hetzner", status: "running", id: 165572435 };
      taskManagerModal.openForServer(srv);
    } else if (typeof openModalOnStart !== "undefined" && openModalOnStart === "procure") {
      procureModal.openModal();
    }
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
    function onBusyChanged(busy, text) {
      window.isBusy = busy;
      window.busyMessage = text;
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
          Image {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: Qt.resolvedUrl("icons/server.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
          }
        }
        Text {
          text: "Ocloud"
          font.pixelSize: 17
          font.bold: true
          color: textPrimary
        }
        Text {
          text: "Personal Cloud Hypervisor"
          font.pixelSize: 12
          color: textMuted
        }
      }

      // Live Busy Indicator Pill
      Rectangle {
        visible: window.isBusy
        height: 28
        width: busyRow.implicitWidth + 20
        radius: 14
        color: Qt.rgba(0.02, 0.52, 0.78, 0.25)
        border.color: accentSky
        border.width: 1

        Row {
          id: busyRow
          anchors.centerIn: parent
          spacing: 8
          Text {
            text: "󰑐"
            font.pixelSize: 13
            color: accentSky
            RotationAnimator on rotation {
              from: 0
              to: 360
              duration: 900
              loops: Animation.Infinite
              running: window.isBusy
            }
          }
          Text {
            text: window.busyMessage || "Processing..."
            font.pixelSize: 11
            font.bold: true
            color: "#f8fafc"
          }
        }
      }

      Item { Layout.fillWidth: true }

      // Hypervisor Cluster Overview Telemetry
      RowLayout {
        spacing: 8
        Rectangle {
          height: 28
          width: coresText.implicitWidth + 20
          radius: 14
          color: "#0f172a"
          border.color: "#1e293b"
          Text {
            id: coresText
            anchors.centerIn: parent
            text: "CPU 12 Cores (14% Load)"
            font.pixelSize: 11
            color: "#38bdf8"
            font.bold: true
          }
        }
        Rectangle {
          height: 28
          width: ramText.implicitWidth + 20
          radius: 14
          color: "#0f172a"
          border.color: "#1e293b"
          Text {
            id: ramText
            anchors.centerIn: parent
            text: "RAM 24.3 / 88 GB"
            font.pixelSize: 11
            color: "#10b981"
            font.bold: true
          }
        }
        Rectangle {
          height: 28
          width: poolText.implicitWidth + 20
          radius: 14
          color: "#0f172a"
          border.color: "#1e293b"
          Text {
            id: poolText
            anchors.centerIn: parent
            text: "POOL 1.1 / 3.0 TB"
            font.pixelSize: 11
            color: "#f59e0b"
            font.bold: true
          }
        }
      }

      // Refresh Button
      Button {
        id: refreshBtn
        enabled: !window.isBusy
        implicitWidth: refreshRow.implicitWidth + 24
        implicitHeight: 32
        background: Rectangle {
          radius: 6
          color: refreshBtn.hovered ? "#1e293b" : "#0f172a"
          border.color: borderSubtle
        }
        contentItem: Row {
          id: refreshRow
          anchors.centerIn: parent
          spacing: 8
          Text {
            text: "󰑐"
            font.pixelSize: 13
            color: textPrimary
          }
          Text {
            text: "Refresh Fleet"
            color: textPrimary
            font.pixelSize: 12
            font.bold: true
          }
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
      Layout.preferredWidth: 220
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
            { id: "fleet", name: "Compute Nodes", iconSvg: "icons/server.svg", count: serverList.length },
            { id: "workloads", name: "Workloads & Docker", iconSvg: "icons/box.svg", count: 3 },
            { id: "storage", name: "Storage Pools", iconSvg: "icons/hard-drive.svg", count: storageBox.mounted ? 1 : 0 },
            { id: "apps", name: "App Streaming", iconSvg: "icons/terminal.svg", count: 3 },
            { id: "backups", name: "Automated Backups", iconSvg: "icons/archive.svg", count: 0 },
            { id: "settings", name: "Vault & Plugins", iconSvg: "icons/shield.svg", count: 0 }
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

              Image {
                width: 18
                height: 18
                source: Qt.resolvedUrl(modelData.iconSvg)
                fillMode: Image.PreserveAspectFit
                smooth: true
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
              spacing: 6
              Image {
                width: 14
                height: 14
                source: Qt.resolvedUrl("icons/nas.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
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
          if (activeTab === "workloads") return 1;
          if (activeTab === "storage") return 2;
          if (activeTab === "apps") return 3;
          if (activeTab === "backups") return 4;
          if (activeTab === "settings") return 5;
          return 0;
        }

        FleetView { id: fleetView }
        WorkloadsView { id: workloadsView }
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

  // Global Machine Task Manager Modal
  MachineTaskManagerModal {
    id: taskManagerModal
  }

  // Global Add Storage Modal
  AddStorageModal {
    id: addStorageModal
    onStorageAdded: reloadAll()
  }
}
