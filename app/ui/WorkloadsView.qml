import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

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
          implicitWidth: offloadRow.implicitWidth + 24
          implicitHeight: 34
          background: Rectangle {
            radius: 8
            gradient: Gradient {
              GradientStop { position: 0.0; color: offloadBtn.hovered ? "#0284c7" : "#0369a1" }
              GradientStop { position: 1.0; color: offloadBtn.hovered ? "#0369a1" : "#075985" }
            }
          }
          contentItem: Row {
            id: offloadRow
            anchors.centerIn: parent
            spacing: 8
            Text { text: "󰐊"; font.pixelSize: 13; color: "#ffffff" }
            Text {
              text: "Offload Container to Cloud"
              color: "#ffffff"
              font.pixelSize: 12
              font.bold: true
            }
          }
          onClicked: offloadModal.openModal()
        }
      }

      // Quick Deploy Card (Alpine / Arch 1-Click Container Host)
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: deployCol.implicitHeight + 36
        radius: 12
        color: "#0a171f"
        border.color: "#0284c7"
        border.width: 1

        ColumnLayout {
          id: deployCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
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
              implicitWidth: launchRow.implicitWidth + 20
              implicitHeight: 32
              background: Rectangle { radius: 6; color: "#0284c7" }
              contentItem: Row {
                id: launchRow
                anchors.centerIn: parent
                spacing: 8
                Text { text: "󰐊"; font.pixelSize: 12; color: "#ffffff" }
                Text { text: "Launch 1-Click Runner"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
              }
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
          text: activeContainers.length + " running containers detected"
          font.pixelSize: 11
          color: textMuted
        }
      }

      // Empty State when no containers are running
      Rectangle {
        visible: activeContainers.length === 0
        Layout.fillWidth: true
        implicitHeight: emptyCol.implicitHeight + 48
        radius: 10
        color: cardBg
        border.color: borderSubtle
        border.width: 1

        ColumnLayout {
          id: emptyCol
          anchors.centerIn: parent
          spacing: 10

          Image {
            Layout.alignment: Qt.AlignHCenter
            width: 36
            height: 36
            source: Qt.resolvedUrl("icons/docker.svg")
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
            text: "Launch a container using 'Offload Container' or deploy a workload to your companion VM."
            font.pixelSize: 12
            color: textMuted
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

          delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: cCol.implicitHeight + 32
            radius: 10
            color: cardBg
            border.color: borderSubtle
            border.width: 1

            ColumnLayout {
              id: cCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
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
                  Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: Qt.resolvedUrl("icons/docker.svg")
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
                    Rectangle {
                      height: 18
                      width: cStatus.implicitWidth + 10
                      radius: 4
                      color: Qt.rgba(0.06, 0.72, 0.5, 0.15)
                      Text {
                        id: cStatus
                        anchors.centerIn: parent
                        text: (modelData.status || "RUNNING").toUpperCase()
                        font.pixelSize: 9
                        font.bold: true
                        color: homeGreen
                      }
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

                Button {
                  implicitWidth: shellRow.implicitWidth + 20
                  implicitHeight: 28
                  background: Rectangle { radius: 6; color: "#1e293b" }
                  contentItem: Row {
                    id: shellRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "󰆍"; font.pixelSize: 12; color: accentSky }
                    Text { text: "Exec Shell"; color: accentSky; font.pixelSize: 11; font.bold: true }
                  }
                  onClicked: {
                    var ip = (serverList && serverList.length > 0) ? serverList[0].ipv4 : "";
                    ocloud.openTerminal(modelData.name, ip);
                  }
                }

                Item { Layout.fillWidth: true }

                Button {
                  implicitWidth: stopRow.implicitWidth + 20
                  implicitHeight: 28
                  background: Rectangle { radius: 6; color: "#3b0d0d"; border.color: "#7f1d1d" }
                  contentItem: Row {
                    id: stopRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "󰅙"; font.pixelSize: 12; color: dangerRed }
                    Text { text: "Stop"; color: dangerRed; font.pixelSize: 11; font.bold: true }
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
      radius: 16
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
            implicitHeight: 36
            text: "Cancel"
            background: Rectangle { radius: 6; color: "#1e293b" }
            contentItem: Text { text: "Cancel"; color: "#94a3b8"; font.pixelSize: 11; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            onClicked: offloadModal.visible = false
          }

          Button {
            Layout.fillWidth: true
            implicitHeight: 36
            background: Rectangle { radius: 6; color: "#0284c7" }
            contentItem: Row {
              anchors.centerIn: parent
              spacing: 8
              Text { text: "󰐊"; font.pixelSize: 13; color: "#ffffff" }
              Text {
                text: "Deploy & Run Workload"
                color: "#ffffff"
                font.pixelSize: 11
                font.bold: true
              }
            }
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
