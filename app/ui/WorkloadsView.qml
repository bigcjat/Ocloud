import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  property var activeContainers: [
    {
      "id": "c-voicevox",
      "name": "voicevox-engine",
      "image": "voicevox/voicevox_engine:cpu-latest",
      "node": "Hetzner Cloud (omarchy-companion)",
      "status": "running",
      "ports": "50021:50021",
      "cpu": "2.4%",
      "mem": "420 MB",
      "uptime": "1h 46m"
    },
    {
      "id": "c-arcade",
      "name": "waypipe-arcade",
      "image": "omarchy/retro-arcade:latest",
      "node": "Hetzner Cloud (omarchy-companion)",
      "status": "running",
      "ports": "4713:4713 (Waypipe)",
      "cpu": "1.1%",
      "mem": "180 MB",
      "uptime": "1h 12m"
    },
    {
      "id": "c-postgres",
      "name": "postgres-prod",
      "image": "postgres:16-alpine",
      "node": "Hetzner Server (Primary-Host)",
      "status": "running",
      "ports": "5432:5432",
      "cpu": "0.3%",
      "mem": "95 MB",
      "uptime": "32d"
    }
  ]

  property bool deploying: false

  ScrollView {
    anchors.fill: parent
    anchors.margins: 24
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 24

      // Header
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          spacing: 2
          Text {
            text: "Workloads & Docker Containers"
            font.pixelSize: 22
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Deploy local containers to high-speed Alpine or Arch Linux cloud instances in seconds"
            font.pixelSize: 13
            color: textSecondary
          }
        }

        Item { Layout.fillWidth: true }

        Button {
          id: offloadBtn
          text: "󰐊 Offload Container to Cloud"
          background: Rectangle {
            radius: 8
            gradient: Gradient {
              GradientStop { position: 0.0; color: offloadBtn.hovered ? "#0284c7" : "#0369a1" }
              GradientStop { position: 1.0; color: offloadBtn.hovered ? "#0369a1" : "#075985" }
            }
          }
          contentItem: Text {
            text: offloadBtn.text
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: offloadModal.openModal()
        }
      }

      // Quick Deploy Card (Alpine / Arch 1-Click Container Host)
      Rectangle {
        Layout.fillWidth: true
        height: deployCol.implicitHeight + 36
        radius: 12
        color: "#0a171f"
        border.color: "#0284c7"
        border.width: 1

        ColumnLayout {
          id: deployCol
          anchors.fill: parent
          anchors.margins: 18
          spacing: 12

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#0c4a6e"
              Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: Qt.resolvedUrl("icons/docker.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Instant Ephemeral Container Host"
                font.pixelSize: 15
                font.bold: true
                color: textPrimary
              }
              Text {
                text: "Spins up an ultralight Alpine or Arch Linux VPS on Hetzner, pipes your local Docker project, and connects via Tailscale"
                font.pixelSize: 11
                color: textSecondary
              }
            }
            Item { Layout.fillWidth: true }
            Button {
              text: "Launch 1-Click Runner"
              background: Rectangle { radius: 6; color: "#0284c7" }
              contentItem: Text { text: "Launch 1-Click Runner"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
              onClicked: offloadModal.openModal()
            }
          }
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
          text: activeContainers.length + " running containers across cluster"
          font.pixelSize: 11
          color: textMuted
        }
      }

      // Container Cards List
      Repeater {
        model: activeContainers

        delegate: Rectangle {
          Layout.fillWidth: true
          height: cCol.implicitHeight + 32
          radius: 10
          color: cardBg
          border.color: borderSubtle
          border.width: 1

          ColumnLayout {
            id: cCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
              Layout.fillWidth: true
              spacing: 12

              Rectangle {
                width: 28
                height: 28
                radius: 6
                color: "#1e293b"
                Text { anchors.centerIn: parent; text: "🐳"; font.pixelSize: 14 }
              }

              ColumnLayout {
                spacing: 2
                RowLayout {
                  spacing: 8
                  Text {
                    text: modelData.name
                    font.pixelSize: 15
                    font.bold: true
                    color: textPrimary
                  }
                  Rectangle {
                    height: 18
                    width: cStatus.implicitWidth + 10
                    radius: 4
                    color: Qt.rgba(0.06, 0.72, 0.5, 0.15)
                    Text {
                      id: cStatus
                      anchors.centerIn: parent
                      text: "RUNNING"
                      font.pixelSize: 9
                      font.bold: true
                      color: homeGreen
                    }
                  }
                }
                Text {
                  text: modelData.image
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
                  Text { text: "NODE"; font.pixelSize: 9; font.bold: true; color: textMuted }
                  Text { text: modelData.node; font.pixelSize: 11; color: textSecondary }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "PORTS"; font.pixelSize: 9; font.bold: true; color: textMuted }
                  Text { text: modelData.ports; font.pixelSize: 11; font.family: "monospace"; color: accentSky }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "CPU"; font.pixelSize: 9; font.bold: true; color: textMuted }
                  Text { text: modelData.cpu; font.pixelSize: 11; font.bold: true; color: textPrimary }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "MEM"; font.pixelSize: 9; font.bold: true; color: textMuted }
                  Text { text: modelData.mem; font.pixelSize: 11; color: textSecondary }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "UPTIME"; font.pixelSize: 9; font.bold: true; color: textMuted }
                  Text { text: modelData.uptime; font.pixelSize: 11; color: textMuted }
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

              Button {
                text: "📋 View Logs"
                background: Rectangle { radius: 6; color: "#1e293b" }
                contentItem: Text { text: "📋 View Logs"; color: textPrimary; font.pixelSize: 11; font.bold: true }
              }

              Button {
                text: ">_ Exec Shell"
                background: Rectangle { radius: 6; color: "#1e293b" }
                contentItem: Text { text: "󰆍 Exec Shell"; color: accentSky; font.pixelSize: 11; font.bold: true }
                onClicked: ocloud.openTerminal(modelData.name, "116.203.42.18")
              }

              Item { Layout.fillWidth: true }

              Button {
                text: "󰑐 Restart"
                background: Rectangle { radius: 6; color: "#1e293b" }
                contentItem: Text { text: "󰑐 Restart"; color: textSecondary; font.pixelSize: 11 }
              }

              Button {
                text: "󰅙 Stop"
                background: Rectangle { radius: 6; color: "#3b0d0d"; border.color: "#7f1d1d" }
                contentItem: Text { text: "󰅙 Stop"; color: dangerRed; font.pixelSize: 11; font.bold: true }
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
      height: offloadCol.implicitHeight + 48
      radius: 16
      color: "#0b1220"
      border.color: "#1e293b"
      border.width: 1
      anchors.centerIn: parent

      ColumnLayout {
        id: offloadCol
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        RowLayout {
          spacing: 10
          Image {
            width: 22
            height: 22
            source: Qt.resolvedUrl("icons/docker.svg")
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
          TextField {
            id: localPathField
            Layout.fillWidth: true
            text: "~/Projects/my-service"
            color: "#f8fafc"
            background: Rectangle { radius: 6; color: "#080e18"; border.color: "#1e293b" }
          }
        }

        // Host OS
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "Cloud Host Operating System"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
          ComboBox {
            id: osCombo
            Layout.fillWidth: true
            model: [
              "🏔 Alpine Linux (Ultra-lightweight · 5s boot · Docker Native)",
              "🏹 Arch Linux (Rolling release · latest kernel & packages)",
              "🐧 Ubuntu 24.04 LTS (Standard Docker Engine)"
            ]
          }
        }

        // VPS Tier
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "Compute Spec"; font.pixelSize: 11; font.bold: true; color: "#94a3b8" }
          ComboBox {
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

          Button {
            Layout.fillWidth: true
            text: "Cancel"
            background: Rectangle { radius: 6; color: "#1e293b" }
            contentItem: Text { text: "Cancel"; color: "#94a3b8"; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
            onClicked: offloadModal.visible = false
          }

          Button {
            Layout.fillWidth: true
            text: "󰐊 Deploy & Run Workload"
            background: Rectangle { radius: 6; color: "#0284c7" }
            contentItem: Text { text: "󰐊 Deploy & Run Workload"; color: "#ffffff"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter }
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
