import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "HetznerApi.js" as Hetzner

Panel {
  id: root
  moduleName: "community.ocloud"
  ipcTarget: "community.ocloud"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color accentColor: Color.accent || "#38bdf8"
  readonly property color successColor: "#10b981"
  readonly property color warningColor: "#f59e0b"

  // In-memory reactive state
  property string apiToken: ""
  property var serversList: []
  property var primaryServer: serversList.length > 0 ? serversList[0] : null
  property int activeVmCount: {
    var cnt = 0;
    for (var i = 0; i < serversList.length; i++) {
      if (serversList[i].status === "running") cnt++;
    }
    return cnt;
  }

  property var storageData: ({
    "configured": true,
    "mounted": false,
    "used_percent": 0.0,
    "mount_point": "~/Cloud"
  })

  property bool showProcureView: false
  property string newVmType: "cx23"
  property string newVmLocation: "nbg1"
  property int refreshInterval: 30

  function refreshAll() {
    if (!root.apiToken || root.apiToken === "") {
      configProc.running = true;
      return;
    }

    Hetzner.fetchServers(root.apiToken, function(servers) {
      root.serversList = servers;
    }, function(err) {
      console.log("Ocloud Hetzner API error: " + err);
    });

    mountCheckProc.running = true;
  }

  Process {
    id: configProc
    command: ["cat", Quickshell.env("HOME") + "/.config/omarchy/hetzner.json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var cfg = JSON.parse(text);
          if (cfg && cfg.api_token) {
            root.apiToken = cfg.api_token;
            root.refreshAll();
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: mountCheckProc
    command: ["mount"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var isMnt = text.indexOf("/Cloud") !== -1;
        root.storageData.mounted = isMnt;
      }
    }
  }

  Timer {
    interval: root.refreshInterval * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshAll()
  }

  // The Bar Icon Button
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰅟"
    slotSize: Style.bar.iconSlot
    tooltipText: "Ocloud Companion"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refreshAll();
      else root.toggle();
    }
  }

  // The Popup KeyboardPanel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight, Style.space(560))

    ColumnLayout {
      id: contentCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(12)

        // Header
        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "☁ Ocloud Companion"
            font.pixelSize: 15
            font.bold: true
            color: root.foreground
          }
          Item { Layout.fillWidth: true }
          Button {
            text: "↻"
            onClicked: root.refreshAll()
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
              text: root.storageData.configured ? "1.0 TB (0.0% used)" : "Not Configured"
              color: root.storageData.configured ? root.accentColor : root.dim
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
              width: Math.min(parent.width, Math.max(4, parent.width * (root.storageData.used_percent / 100.0)))
              color: root.accentColor
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Text {
              text: root.storageData.mounted ? "● Mounted at ~/Cloud" : "○ Drive unmounted"
              font.pixelSize: 11
              color: root.storageData.mounted ? root.successColor : root.dim
            }
            Item { Layout.fillWidth: true }
            Button {
              text: root.storageData.mounted ? "Unmount" : "Mount Drive"
              onClicked: {
                if (root.storageData.mounted) {
                  execProc.command = ["umount", Quickshell.env("HOME") + "/Cloud"];
                } else {
                  execProc.command = ["ocloud", "storage", "mount"];
                }
                execProc.running = true;
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
              text: root.activeVmCount > 0 ? "● " + root.activeVmCount + " RUNNING" : "○ OFFLINE"
              font.pixelSize: 11
              font.bold: true
              color: root.activeVmCount > 0 ? root.successColor : root.dim
            }
          }

          Text {
            text: root.primaryServer ? (root.primaryServer.name + " (" + (root.primaryServer.server_type ? root.primaryServer.server_type.name : "cx23") + " · " + (root.primaryServer.public_net && root.primaryServer.public_net.ipv4 ? root.primaryServer.public_net.ipv4.ip : "no IP") + ")") : "No active companion servers"
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
              enabled: !!root.primaryServer
              onClicked: {
                if (root.primaryServer && root.primaryServer.public_net && root.primaryServer.public_net.ipv4) {
                  Quickshell.execDetached(["foot", "-e", "ssh", "-i", Quickshell.env("HOME") + "/.ssh/id_ed25519", "-o", "StrictHostKeyChecking=no", "root@" + root.primaryServer.public_net.ipv4.ip]);
                }
              }
            }
            Button {
              text: "🎮 Launch App"
              Layout.fillWidth: true
              enabled: !!root.primaryServer && root.primaryServer.status === "running"
              onClicked: {
                if (root.primaryServer && root.primaryServer.public_net && root.primaryServer.public_net.ipv4) {
                  var ip = root.primaryServer.public_net.ipv4.ip;
                  Quickshell.execDetached(["foot", "-e", "ocloud", "vm", "app", "devilutionx"]);
                }
              }
            }
            Button {
              text: (root.primaryServer && root.primaryServer.status === "running") ? "Power Off" : "Power On"
              Layout.fillWidth: true
              enabled: !!root.primaryServer
              onClicked: {
                if (root.primaryServer) {
                  if (root.primaryServer.status === "running") {
                    Hetzner.powerOff(root.apiToken, root.primaryServer.id, function() {
                      root.refreshAll();
                    });
                  } else {
                    Hetzner.powerOn(root.apiToken, root.primaryServer.id, function() {
                      root.refreshAll();
                    });
                  }
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
                if (currentIndex === 0) root.newVmType = "cx23";
                else if (currentIndex === 1) root.newVmType = "cax11";
                else if (currentIndex === 2) root.newVmType = "cpx21";
              }
            }
          }

          Button {
            text: "🚀 Deploy Server in Nuremberg (nbg1)"
            Layout.fillWidth: true
            onClicked: {
              var srvName = "omarchy-" + Math.floor(Math.random() * 1000);
              Hetzner.createServer(root.apiToken, srvName, root.newVmType, root.newVmLocation, "ubuntu-24.04", ["omarchy-laptop"], null, function(newServer) {
                root.showProcureView = false;
                root.refreshAll();
              }, function(err) {
                console.log("Procure error: " + err);
              });
            }
          }
        }
      }
    }

  Process {
    id: execProc
    running: false
    onExited: root.refreshAll()
  }
}
