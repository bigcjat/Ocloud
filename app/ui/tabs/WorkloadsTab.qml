import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  property var activeContainers: []
  property bool deploying: false

  Connections {
    target: ocloud
    function onDockerContainersUpdated(jsonStr) {
      try {
        activeContainers = JSON.parse(jsonStr) || [];
      } catch (e) {
        activeContainers = [];
      }
    }
  }

  Component.onCompleted: {
    var srvId = (serverList && serverList.length > 0) ? String(serverList[0].id) : "";
    if (srvId && ocloud.fetchDockerContainers) {
      ocloud.fetchDockerContainers(srvId);
    }
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
        title: "Workloads & Docker"
        subtitle: "Deploy local containers to high-speed cloud instances in seconds"

        AppButton {
          text: "Offload Container"
          iconSource: "icons/plus.svg"
          variant: "primary"
          onClicked: offloadModal.openModal()
        }
      }

      // Quick Deploy Banner (Alpine / Arch 1-Click Container Host)
      AppBanner {
        variant: "info"
        iconSource: "icons/box.svg"
        title: "Instant Ephemeral Container Host"
        message: "Spins up an ultralight Alpine or Arch Linux VPS on Hetzner, pipes your local Docker project, and connects via Tailscale"

        AppButton {
          text: "Launch 1-Click Runner"
          iconSource: "icons/terminal.svg"
          variant: "primary"
          onClicked: offloadModal.openModal()
        }
      }

      // Containers Table Header
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Active Container Fleet"
          font.pixelSize: 15
          font.bold: true
          color: textPrimary
        }
        Item { Layout.fillWidth: true }
        Text {
          text: activeContainers.length + " running containers detected"
          font.pixelSize: 11
          color: textMuted
        }
      }

      // Empty State when no containers are running
      AppCard {
        visible: activeContainers.length === 0
        implicitHeight: emptyCol.implicitHeight + 48

        ColumnLayout {
          id: emptyCol
          anchors.centerIn: parent
          spacing: 12

          Image {
            Layout.alignment: Qt.AlignHCenter
            width: 36
            height: 36
            source: Qt.resolvedUrl("../icons/box.svg")
            fillMode: Image.PreserveAspectFit
            opacity: 0.6
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No Docker Containers Running"
            font.pixelSize: 14
            font.bold: true
            color: textPrimary
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Launch a container using 'Offload Container' or inspect your companion VM processes."
            font.pixelSize: 12
            color: textMuted
          }

          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            AppButton {
              text: "+ Offload Container"
              variant: "primary"
              onClicked: offloadModal.openModal()
            }

            AppButton {
              text: "Inspect Companion VM"
              variant: "secondary"
              onClicked: {
                var srv = (serverList && serverList.length > 0) ? serverList[0] : null;
                if (srv) taskManagerModal.openForServer(srv);
              }
            }
          }
        }
      }

      // Container Cards List (Real Docker data only)
      ColumnLayout {
        visible: activeContainers.length > 0
        Layout.fillWidth: true
        spacing: 12

        Repeater {
          model: activeContainers

          delegate: AppCard {
            implicitHeight: cCol.implicitHeight + 32

            ColumnLayout {
              id: cCol
              anchors.fill: parent
              anchors.margins: 16
              spacing: 12

              RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                  width: 32
                  height: 32
                  radius: 6
                  color: "#1e293b"
                  Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: Qt.resolvedUrl("../icons/box.svg")
                    fillMode: Image.PreserveAspectFit
                  }
                }

                ColumnLayout {
                  spacing: 2
                  RowLayout {
                    spacing: 8
                    Text {
                      text: modelData.name || modelData.id || "container"
                      font.pixelSize: 15
                      font.bold: true
                      color: textPrimary
                    }
                    AppBadge {
                      variant: "success"
                      text: (modelData.status || "RUNNING").toUpperCase()
                    }
                  }
                  Text {
                    text: modelData.image || "unknown"
                    font.pixelSize: 11
                    color: textMuted
                    font.family: "monospace"
                  }
                }

                Item { Layout.fillWidth: true }

                // Telemetry Pills
                RowLayout {
                  spacing: 16
                  ColumnLayout {
                    spacing: 1
                    Text { text: "PORTS"; font.pixelSize: 9; font.bold: true; color: textMuted }
                    Text { text: modelData.ports || "none"; font.pixelSize: 11; font.family: "monospace"; color: accentSky }
                  }
                  ColumnLayout {
                    spacing: 1
                    Text { text: "STATUS"; font.pixelSize: 9; font.bold: true; color: textMuted }
                    Text { text: modelData.status || "running"; font.pixelSize: 11; color: textSecondary }
                  }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 1
                color: borderSubtle
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                AppButton {
                  text: "Exec Shell"
                  variant: "secondary"
                  onClicked: {
                    var ip = (serverList && serverList.length > 0) ? (serverList[0].tailscale_ip || serverList[0].ipv4) : "";
                    ocloud.openTerminal(modelData.name, ip);
                  }
                }

                Item { Layout.fillWidth: true }

                AppButton {
                  text: "Stop"
                  variant: "danger"
                  onClicked: {
                    var srvId = (serverList && serverList.length > 0) ? String(serverList[0].id) : "";
                    if (srvId && ocloud.containerAction) {
                      ocloud.containerAction(srvId, modelData.id, "stop");
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Quick-Launch Workload Stacks Card
      AppCard {
        Layout.fillWidth: true
        implicitHeight: stackCol.implicitHeight + 32

        ColumnLayout {
          id: stackCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 14

          Text {
            text: "1-Click Workload Templates"
            font.pixelSize: 15
            font.bold: true
            color: textPrimary
          }

          GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 14

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Math.max(124, pgCol.implicitHeight + 24)
              radius: 8
              color: "#080e18"
              border.color: borderSubtle

              ColumnLayout {
                id: pgCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                Text { text: "PostgreSQL 16"; font.pixelSize: 13; font.bold: true; color: textPrimary }
                Text { text: "Relational database with persistent volume mounted to Storage Box"; font.pixelSize: 11; color: textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
                RowLayout {
                  Layout.fillWidth: true
                  Item { Layout.fillWidth: true }
                  AppButton { text: "Deploy DB"; variant: "secondary"; onClicked: offloadModal.openModal() }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Math.max(124, redisCol.implicitHeight + 24)
              radius: 8
              color: "#080e18"
              border.color: borderSubtle

              ColumnLayout {
                id: redisCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                Text { text: "Redis Cache"; font.pixelSize: 13; font.bold: true; color: textPrimary }
                Text { text: "Ultra-fast in-memory cache and pub/sub message queue"; font.pixelSize: 11; color: textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
                RowLayout {
                  Layout.fillWidth: true
                  Item { Layout.fillWidth: true }
                  AppButton { text: "Deploy Cache"; variant: "secondary"; onClicked: offloadModal.openModal() }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              implicitHeight: Math.max(124, nginxCol.implicitHeight + 24)
              radius: 8
              color: "#080e18"
              border.color: borderSubtle

              ColumnLayout {
                id: nginxCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6
                Text { text: "Nginx Ingress"; font.pixelSize: 13; font.bold: true; color: textPrimary }
                Text { text: "Reverse proxy and TLS certificate automation for remote services"; font.pixelSize: 11; color: textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
                RowLayout {
                  Layout.fillWidth: true
                  Item { Layout.fillWidth: true }
                  AppButton { text: "Deploy Ingress"; variant: "secondary"; onClicked: offloadModal.openModal() }
                }
              }
            }
          }
        }
      }
    }
  }

  // Offload to Cloud Modal
  Rectangle {
    id: offloadModal
    visible: false
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.8)
    z: 2000

    function openModal() {
      offloadModal.visible = true;
    }

    MouseArea { anchors.fill: parent; onClicked: {} }

    Rectangle {
      width: 520
      implicitHeight: offloadCol.implicitHeight + 48
      radius: 12
      color: "#0b1220"
      border.color: "#1e293b"
      border.width: 1
      anchors.centerIn: parent

      ColumnLayout {
        id: offloadCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 24
        spacing: 16

        RowLayout {
          spacing: 10
          Image {
            width: 22
            height: 22
            source: Qt.resolvedUrl("../icons/box.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
          }
          ColumnLayout {
            spacing: 2
            Text {
              text: "Deploy Local Container to Cloud VPS"
              font.pixelSize: 16
              font.bold: true
              color: "#f8fafc"
            }
            Text {
              text: "Instant offload to an ephemeral Hetzner instance"
              font.pixelSize: 11
              color: "#94a3b8"
            }
          }
        }

        // Project / Container source
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "Local Folder Path / Compose File"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
          AppTextField {
            id: localPathField
            Layout.fillWidth: true
            text: "~/Projects/my-service"
          }
        }

        // Host OS
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "Cloud Host Operating System"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
          AppComboBox {
            id: osCombo
            Layout.fillWidth: true
            model: [
              "Alpine Linux 3.20 (Ultra-lightweight · 5s boot · Docker Native)",
              "Arch Linux (Rolling release · latest kernel & packages)",
              "Ubuntu 24.04 LTS (Standard Docker Engine)"
            ]
          }
        }

        // VPS Tier
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "Compute Spec"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
          AppComboBox {
            id: vpsTierCombo
            Layout.fillWidth: true
            model: [
              "cx23 (Intel 2 vCPU / 4 GB RAM · €0.006/hr)",
              "cax11 (Ampere ARM 2 vCPU / 4 GB RAM · €0.005/hr)",
              "cpx31 (AMD 4 vCPU / 8 GB RAM · €0.02/hr)"
            ]
          }
        }

        // Tailscale auto-mesh
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          CheckBox { id: tsOffloadCheck; checked: true }
          Text {
            text: "Auto-join private Tailscale mesh (private container access)"
            font.pixelSize: 11
            color: "#f8fafc"
          }
        }

        // Action buttons
        RowLayout {
          Layout.fillWidth: true
          spacing: 12

          AppButton {
            Layout.fillWidth: true
            text: "Cancel"
            variant: "secondary"
            onClicked: offloadModal.visible = false
          }

          AppButton {
            Layout.fillWidth: true
            text: "Deploy & Run Workload"
            variant: "primary"
            onClicked: {
              offloadModal.visible = false;
              if (ocloud.procureServer) {
                ocloud.procureServer("runner-alpine", "cx23", "nbg1", "tskey-auto");
              }
            }
          }
        }
      }
    }
  }
}
