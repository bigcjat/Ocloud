import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  ScrollView {
    anchors.fill: parent
    anchors.margins: root.isNarrow ? 12 : 20
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: root.isNarrow ? 14 : 20

      // Section Header
      AppHeader {
        title: "Compute Fleet"
        subtitle: "Manage Google Cloud & Hetzner VMs, Home Workstations, and Bare Metal Nodes"

        AppButton {
          text: root.isNarrow ? "Procure" : "Procure Cloud VM"
          iconSource: "icons/server.svg"
          variant: "primary"
          onClicked: procureModal.openModal()
        }

        AppButton {
          text: root.isNarrow ? "Add Node" : "Add Home Node"
          iconSource: "icons/plus.svg"
          variant: "secondary"
          onClicked: addNodeModal.openModal()
        }
      }

      // Empty State
      AppCard {
        visible: serverList.length === 0
        implicitHeight: 200

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 10
          Image {
            width: 36
            height: 36
            source: Qt.resolvedUrl("../icons/server.svg")
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignHCenter
            smooth: true
          }
          Text {
            text: "No Compute Nodes in Fleet"
            font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
            font.pixelSize: 14
            font.bold: true
            color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : textPrimary
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "Deploy a high-speed Google Cloud or Hetzner VM, or register your Home Workstation"
            font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
            font.pixelSize: 11
            color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : textMuted
            Layout.alignment: Qt.AlignHCenter
          }

          RowLayout {
            spacing: 12
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6

            AppButton {
              text: "Procure Cloud VM"
              iconSource: "icons/server.svg"
              variant: "primary"
              onClicked: procureModal.openModal()
            }

            AppButton {
              text: "Add Home Node"
              iconSource: "icons/plus.svg"
              variant: "secondary"
              onClicked: addNodeModal.openModal()
            }
          }
        }
      }

      // Server Cards List
      Repeater {
        model: serverList

        delegate: AppCard {
          implicitHeight: cardCol.implicitHeight + (root.isNarrow ? 24 : 32)

          ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: root.isNarrow ? 12 : 16
            spacing: root.isNarrow ? 10 : 14

            // Top Row: Badges, Title, Status
            RowLayout {
              Layout.fillWidth: true
              spacing: 10

              // Provider Brand Logo
              Image {
                width: 20
                height: 20
                source: modelData.isHomeWorkstation ? Qt.resolvedUrl("../icons/device-workstation.svg") : ((modelData.providerIcon && modelData.providerIcon.length > 0) ? modelData.providerIcon : Qt.resolvedUrl("../icons/server.svg"))
                fillMode: Image.PreserveAspectFit
                smooth: true
              }

              Text {
                text: modelData.name
                font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
                font.pixelSize: root.isNarrow ? 13 : 15
                font.bold: true
                color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : textPrimary
                elide: Text.ElideRight
                Layout.maximumWidth: root.isNarrow ? 140 : 260
              }

              Text {
                visible: !root.isNarrow
                text: "(" + (modelData.type || "server") + " · " + (modelData.location || "cloud") + ")"
                font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
                font.pixelSize: 11
                color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : textMuted
              }

              Item { Layout.fillWidth: true }

              // Standardized Live Status Pill
              AppBadge {
                variant: modelData.status === "running" ? "success" : (modelData.status === "starting" ? "warning" : "danger")
                text: modelData.status === "running" ? "ONLINE" : (modelData.status === "starting" ? "STARTING..." : "STOPPED")
              }
            }

            // Middle: Specs, IP, Network (Flow for responsive wrap)
            Flow {
              Layout.fillWidth: true
              spacing: root.isNarrow ? 12 : 24

              ColumnLayout {
                spacing: 2
                Text { text: "PUBLIC IP"; font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"; font.pixelSize: 9; font.bold: true; color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : textMuted }
                Text {
                  text: (modelData.ipv4 && modelData.ipv4 !== "no IP" && modelData.ipv4 !== "No IP assigned")
                    ? modelData.ipv4
                    : (modelData.status === "starting" ? "Assigning IP..." : "No IP assigned")
                  font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
                  font.pixelSize: 11
                  font.bold: true
                  color: (modelData.status === "starting" && (!modelData.ipv4 || modelData.ipv4 === "no IP")) ? "#fbbf24" : ((typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : textPrimary)
                }
              }

              ColumnLayout {
                spacing: 2
                Text { text: "TAILSCALE IP"; font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"; font.pixelSize: 9; font.bold: true; color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : textMuted }
                Text {
                  text: (modelData.tailscale_ip || modelData.tailscaleIp) ? (modelData.tailscale_ip || modelData.tailscaleIp) : "Not connected"
                  font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
                  font.pixelSize: 11
                  font.bold: !!(modelData.tailscale_ip || modelData.tailscaleIp)
                  color: (modelData.tailscale_ip || modelData.tailscaleIp) ? "#38bdf8" : ((typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : textMuted)
                }
              }

              ColumnLayout {
                spacing: 2
                Text { text: "PROVIDER"; font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"; font.pixelSize: 9; font.bold: true; color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : textMuted }
                Text { text: (modelData.provider || "hetzner").toUpperCase(); font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"; font.pixelSize: 11; color: (typeof theme !== "undefined" && theme.textSecondary) ? theme.textSecondary : textSecondary }
              }

              ColumnLayout {
                spacing: 2
                Text { text: "NODE ID"; font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"; font.pixelSize: 9; font.bold: true; color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : textMuted }
                Text { text: String(modelData.id); font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"; font.pixelSize: 11; color: (typeof theme !== "undefined" && theme.textSecondary) ? theme.textSecondary : textSecondary }
              }
            }

            // Divider
            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : borderSubtle
            }

            // Bottom Row: Action Toolbar with Flow wrapping
            Flow {
              Layout.fillWidth: true
              spacing: 6

              AppButton {
                text: "Task Manager"
                iconSource: "icons/activity.svg"
                variant: "secondary"
                onClicked: taskManagerModal.openForServer(modelData)
              }

              AppButton {
                text: "SSH Terminal"
                iconSource: "icons/terminal.svg"
                variant: "secondary"
                onClicked: ocloud.openTerminal(modelData.name, modelData.tailscale_ip || modelData.ipv4, modelData.user || "root")
              }

              AppButton {
                enabled: modelData.status === "running"
                text: modelData.is_drive_mounted ? "Unmount Drive" : "Mount Drive"
                iconSource: modelData.is_drive_mounted ? "icons/eject.svg" : "icons/hard-drive.svg"
                variant: modelData.is_drive_mounted ? "danger" : "secondary"
                onClicked: {
                  if (modelData.is_drive_mounted) {
                    ocloud.unmountEphemeralVm();
                  } else {
                    consentModal.openForServer(modelData.name, String(modelData.id));
                  }
                }
              }

              AppButton {
                enabled: modelData.status !== "starting" && modelData.status !== "stopping"
                text: modelData.status === "running" ? "Power Off" : (modelData.status === "starting" ? "Starting..." : "Power On")
                variant: modelData.status === "running" ? "secondary" : "success"
                onClicked: {
                  var act = modelData.status === "running" ? "stop" : "start";
                  ocloud.serverAction(act, String(modelData.id));
                }
              }

              AppButton {
                enabled: modelData.status === "running"
                text: "Reboot"
                iconSource: "icons/refresh.svg"
                variant: "secondary"
                onClicked: ocloud.serverAction("reboot", String(modelData.id))
              }

              AppButton {
                text: "Delete"
                iconSource: "icons/trash.svg"
                variant: "danger"
                onClicked: {
                  if (modelData.provider === "custom") {
                    ocloud.removeNode(String(modelData.id));
                  } else {
                    ocloud.serverAction("delete", String(modelData.id));
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
