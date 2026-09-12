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
  readonly property color dangerColor: "#ef4444"

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
  property bool showConsentModal: false
  property string newVmType: "cx23"
  property string newVmLocation: "nbg1"
  property int refreshInterval: 30

  function refreshAll() {
    if (!root.apiToken || root.apiToken === "") {
      vaultProc.running = true;
      return;
    }

    Hetzner.fetchServers(root.apiToken, function(servers) {
      root.serversList = servers;
    }, function(err) {
      console.log("Ocloud Hetzner API error: " + err);
    });

    mountCheckProc.running = true;
  }

  // Load API token from Ocloud encrypted vault
  Process {
    id: vaultProc
    command: ["ocloud", "vault", "get", "api_token"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var tok = text.trim();
        if (tok && tok !== "") {
          root.apiToken = tok;
          root.refreshAll();
        } else {
          legacyConfigProc.running = true;
        }
      }
    }
  }

  Process {
    id: legacyConfigProc
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

  property bool vmDriveMounted: false

  Process {
    id: mountCheckProc
    command: ["mount"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.storageData.mounted = text.indexOf("/Cloud ") !== -1 || text.indexOf("/Cloud\n") !== -1;
        root.vmDriveMounted = text.indexOf("/Companion-VM") !== -1;
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
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight, Style.space(600))

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

      // Storage Box Section (Permanent RAID)
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Storage Box (Permanent)"
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
                execProc.command = ["ocloud", "storage", "unmount"];
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
        spacing: 8

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

        // VM Ephemeral Drive Row
        RowLayout {
          Layout.fillWidth: true
          ColumnLayout {
            spacing: 1
            Text {
              text: root.vmDriveMounted ? "⚡ Mounted at ~/Companion-VM" : "○ VM Drive unmounted"
              font.pixelSize: 11
              font.bold: root.vmDriveMounted
              color: root.vmDriveMounted ? root.warningColor : root.dim
            }
            Text {
              text: root.vmDriveMounted ? "⚠️ Ephemeral: destroyed on VM shutdown" : "Direct access to companion root"
              font.pixelSize: 10
              color: root.vmDriveMounted ? root.warningColor : root.dim
            }
          }
          Item { Layout.fillWidth: true }
          Button {
            text: root.vmDriveMounted ? "Unmount VM" : "Mount Drive"
            enabled: (root.primaryServer && root.primaryServer.status === "running") || root.vmDriveMounted
            onClicked: {
              if (root.vmDriveMounted) {
                execProc.command = ["ocloud", "vm", "unmount"];
                execProc.running = true;
              } else {
                root.showConsentModal = true;
              }
            }
          }
        }

        // Ephemeral Safety Consent Banner in Popup
        Rectangle {
          Layout.fillWidth: true
          visible: root.showConsentModal
          height: consentCol.implicitHeight + 16
          radius: 8
          color: "#291804"
          border.color: root.warningColor

          ColumnLayout {
            id: consentCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Text {
              text: "⚠️ DATA-LOSS SAFETY WARNING"
              font.pixelSize: 11
              font.bold: true
              color: root.warningColor
            }
            Text {
              text: "This drive is hosted on the ephemeral local disk of VM. When the VM powers off, ALL FILES WILL BE LOST."
              font.pixelSize: 10
              color: "#fde68a"
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
            RowLayout {
              Layout.fillWidth: true
              Button {
                text: "Cancel"
                onClicked: root.showConsentModal = false
              }
              Item { Layout.fillWidth: true }
              Button {
                text: "I Understand, Mount"
                onClicked: {
                  root.showConsentModal = false;
                  execProc.command = ["ocloud", "vm", "mount", "--yes"];
                  execProc.running = true;
                }
              }
            }
          }
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
                var serverName = root.primaryServer.name || "companion";
                var ip = root.primaryServer.public_net.ipv4.ip;
                Quickshell.execDetached([
                  "foot",
                  "-T", "☁ Ocloud Companion [" + serverName + " · " + ip + "]",
                  "-o", "colors-dark.background=080e18",
                  "-o", "colors-dark.foreground=e2e8f0",
                  "-o", "colors-dark.regular4=38bdf8",
                  "-e", "ssh", "-i", Quickshell.env("HOME") + "/.ssh/id_ed25519", "-o", "StrictHostKeyChecking=no", "-t", "root@" + ip
                ]);
              }
            }
          }
          Button {
            text: "🎮 Launch App"
            Layout.fillWidth: true
            enabled: !!root.primaryServer && root.primaryServer.status === "running"
            onClicked: {
              if (root.primaryServer && root.primaryServer.public_net && root.primaryServer.public_net.ipv4) {
                Quickshell.execDetached(["foot", "-e", "ocloud", "vm", "app", "arcade"]);
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

      // App Manager Link
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)
      }

      Button {
        id: desktopAppBtn
        text: "🖥 Open Ocloud Desktop Manager"
        Layout.fillWidth: true
        onClicked: {
          root.toggle();
          Quickshell.execDetached(["ocloud", "gui"]);
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
