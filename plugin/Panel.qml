import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "community.ocloud"
  ipcTarget: "community.ocloud"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color accentColor: Color.accent || "#38bdf8"
  readonly property color successColor: "#10b981"
  readonly property color warningColor: "#f59e0b"

  property var statusData: ({
    "storage": {
      "configured": false,
      "mounted": false,
      "used_percent": 0.0,
      "used_bytes": 0,
      "total_bytes": 0,
      "mount_point": "~/Cloud"
    },
    "compute": {
      "active_count": 0,
      "total_count": 0,
      "primary_server": null,
      "servers": []
    }
  })

  property bool showProcureView: false
  property string newVmType: "cx23"
  property string newVmLocation: "nbg1"

  property string ocloudBin: pluginSettings && pluginSettings.ocloudBinPath ? pluginSettings.ocloudBinPath : "ocloud"
  property int refreshInterval: pluginSettings && pluginSettings.refreshIntervalSec ? pluginSettings.refreshIntervalSec : 60

  function refreshStatus() {
    statusProc.running = true
  }

  Process {
    id: statusProc
    command: [ocloudBin, "status", "--json"]
    running: false
    stdout: StdioCollector {
      onCollected: {
        try {
          var parsed = JSON.parse(text)
          if (parsed) root.statusData = parsed
        } catch (e) {
          console.log("Hetzner JSON parse error: " + e)
        }
      }
    }
  }

  Timer {
    interval: root.refreshInterval * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  // Panel Content Card
  contentItem: Rectangle {
    implicitWidth: 400
    implicitHeight: root.showProcureView ? 480 : 380
    color: root.surface
    radius: 12
    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)
    border.width: 1

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 18
      spacing: 12

      // Header
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "☁ Hetzner Cloud Companion"
          font.pixelSize: 15
          font.bold: true
          color: root.foreground
        }
        Item { Layout.fillWidth: true }
        Button {
          text: "↻"
          flat: true
          onClicked: root.refreshStatus()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
      }

      // Storage Box Section
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Storage Box"
            font.bold: true
            font.pixelSize: 13
            color: root.foreground
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.statusData.storage.configured ? (root.statusData.storage.used_percent + "% (1.0 TB)") : "Not Configured"
            color: root.statusData.storage.configured ? root.accentColor : root.dim
            font.pixelSize: 12
          }
        }

        // Progress bar
        Rectangle {
          Layout.fillWidth: true
          height: 6
          radius: 3
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Rectangle {
            height: parent.height
            radius: 3
            width: Math.min(parent.width, Math.max(0, parent.width * (root.statusData.storage.used_percent / 100.0)))
            color: root.accentColor
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: root.statusData.storage.mounted ? "● Mounted at " + root.statusData.storage.mount_point : "○ Drive unmounted"
            font.pixelSize: 11
            color: root.statusData.storage.mounted ? root.successColor : root.dim
          }
          Item { Layout.fillWidth: true }
          Button {
            text: root.statusData.storage.mounted ? "Unmount" : "Mount Drive"
            font.pixelSize: 11
            onClicked: {
              var cmd = root.statusData.storage.mounted ? "unmount" : "mount"
              actionProc.command = [root.ocloudBin, "storage", cmd]
              actionProc.running = true
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
      }

      // Compute (VM) Section
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Cloud Compute (VM)"
            font.bold: true
            font.pixelSize: 13
            color: root.foreground
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.statusData.compute.active_count > 0 ? "● RUNNING" : "○ OFFLINE"
            font.pixelSize: 11
            font.bold: true
            color: root.statusData.compute.active_count > 0 ? root.successColor : root.dim
          }
        }

        Text {
          text: root.statusData.compute.primary_server ? (root.statusData.compute.primary_server.name + " (" + root.statusData.compute.primary_server.type + " · " + root.statusData.compute.primary_server.ipv4 + ")") : "No active companion servers"
          font.pixelSize: 12
          color: root.dim
        }

        // Action Buttons
        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          Button {
            text: ">_ Terminal"
            Layout.fillWidth: true
            enabled: !!root.statusData.compute.primary_server
            onClicked: {
              if (root.statusData.compute.primary_server) {
                actionProc.command = ["alacritty", "-e", root.ocloudBin, "vm", "ssh", String(root.statusData.compute.primary_server.id)]
                actionProc.running = true
              }
            }
          }
          Button {
            text: "🎮 Launch App"
            Layout.fillWidth: true
            enabled: !!root.statusData.compute.primary_server && root.statusData.compute.active_count > 0
            onClicked: {
              if (root.statusData.compute.primary_server) {
                actionProc.command = [root.ocloudBin, "vm", "app", String(root.statusData.compute.primary_server.id), "xeyes"]
                actionProc.running = true
              }
            }
          }
          Button {
            text: root.statusData.compute.active_count > 0 ? "Power Off" : "Power On"
            Layout.fillWidth: true
            enabled: !!root.statusData.compute.primary_server
            onClicked: {
              if (root.statusData.compute.primary_server) {
                var action = root.statusData.compute.active_count > 0 ? "stop" : "start"
                actionProc.command = [root.ocloudBin, "vm", action, String(root.statusData.compute.primary_server.id)]
                actionProc.running = true
              }
            }
          }
        }
      }

      // Procurement section toggle
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
      }

      RowLayout {
        Layout.fillWidth: true
        Button {
          text: root.showProcureView ? "Cancel" : "+ Procure New Cloud VM"
          Layout.fillWidth: true
          flat: true
          onClicked: root.showProcureView = !root.showProcureView
        }
      }

      // Inline Procurement Form
      ColumnLayout {
        Layout.fillWidth: true
        visible: root.showProcureView
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          Text { text: "Server Type:"; color: root.foreground; font.pixelSize: 11 }
          Item { Layout.fillWidth: true }
          ComboBox {
            model: ["cx23 (Intel 2c/4GB · €4/mo)", "cax11 (ARM 2c/4GB · €3.80/mo)", "cpx21 (AMD 3c/4GB · €7/mo)"]
            onCurrentIndexChanged: {
              if (currentIndex === 0) root.newVmType = "cx23"
              else if (currentIndex === 1) root.newVmType = "cax11"
              else if (currentIndex === 2) root.newVmType = "cpx21"
            }
          }
        }

        Button {
          text: "🚀 Deploy Server in Nuremberg (nbg1)"
          Layout.fillWidth: true
          onClicked: {
            var srvName = "omarchy-" + Math.floor(Math.random() * 1000)
            actionProc.command = [root.ocloudBin, "vm", "create", srvName, "--type", root.newVmType, "--location", root.newVmLocation]
            actionProc.running = true
            root.showProcureView = false
          }
        }
      }
    }
  }

  Process {
    id: actionProc
    running: false
    onExited: root.refreshStatus()
  }
}
