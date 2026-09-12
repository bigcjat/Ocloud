import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  ScrollView {
    anchors.fill: parent
    anchors.margins: 24
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 20

      // Section Header
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          spacing: 2
          Text {
            text: "Compute Fleet"
            font.pixelSize: 22
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Manage Hetzner Cloud VMs, Home Workstations, and Bare Metal Nodes"
            font.pixelSize: 13
            color: textSecondary
          }
        }

        Item { Layout.fillWidth: true }

        Button {
          id: addNodeBtn
          text: "+ Add Home / Bare-Metal"
          background: Rectangle {
            radius: 8
            color: addNodeBtn.hovered ? "#1e293b" : "#0f172a"
            border.color: borderSubtle
          }
          contentItem: Text {
            text: addNodeBtn.text
            color: textPrimary
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: addNodeModal.openModal()
        }

        Button {
          id: procureBtn
          text: "+ Procure Cloud VM"
          background: Rectangle {
            radius: 8
            gradient: Gradient {
              GradientStop { position: 0.0; color: procureBtn.hovered ? "#0284c7" : "#0369a1" }
              GradientStop { position: 1.0; color: procureBtn.hovered ? "#0369a1" : "#075985" }
            }
          }
          contentItem: Text {
            text: procureBtn.text
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: procureModal.openModal()
        }
      }

      // Empty State
      Rectangle {
        visible: serverList.length === 0
        Layout.fillWidth: true
        height: 180
        radius: 12
        color: cardBg
        border.color: borderSubtle

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 12
          Image {
            width: 36
            height: 36
            source: Qt.resolvedUrl("icons/server.svg")
            fillMode: Image.PreserveAspectFit
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "No Compute Nodes in Fleet"
            font.pixelSize: 16
            font.bold: true
            color: textPrimary
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "Deploy a high-speed Hetzner Cloud VM or register your Home Workstation"
            font.pixelSize: 12
            color: textMuted
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Server Cards List
      Repeater {
        model: serverList

        delegate: Rectangle {
          Layout.fillWidth: true
          height: cardCol.implicitHeight + 36
          radius: 12
          color: modelData.isHomeWorkstation ? "#0a1715" : cardBg
          border.color: modelData.isHomeWorkstation ? "#065f46" : borderSubtle
          border.width: 1

          ColumnLayout {
            id: cardCol
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Top Row: Badges, Title, Status
            RowLayout {
              Layout.fillWidth: true
              spacing: 12

              // Provider Brand Logo
              Image {
                width: 22
                height: 22
                source: modelData.isHomeWorkstation ? Qt.resolvedUrl("icons/nas.svg") : (modelData.provider === "oracle" ? Qt.resolvedUrl("icons/oracle.svg") : (modelData.provider === "aws" ? Qt.resolvedUrl("icons/aws.svg") : (modelData.provider === "digitalocean" ? Qt.resolvedUrl("icons/digitalocean.svg") : (modelData.provider === "vultr" ? Qt.resolvedUrl("icons/vultr.svg") : Qt.resolvedUrl("icons/hetzner.svg")))))
                fillMode: Image.PreserveAspectFit
                smooth: true
              }

              Text {
                text: modelData.name
                font.pixelSize: 16
                font.bold: true
                color: textPrimary
              }

              Text {
                text: "(" + (modelData.type || "server") + " · " + (modelData.location || "cloud") + ")"
                font.pixelSize: 12
                color: textMuted
              }

              Item { Layout.fillWidth: true }

              // Live Status Dot
              Rectangle {
                width: 10
                height: 10
                radius: 5
                color: modelData.status === "running" ? homeGreen : dangerRed
              }

              Text {
                text: modelData.status === "running" ? "ONLINE" : "STOPPED"
                font.pixelSize: 11
                font.bold: true
                color: modelData.status === "running" ? homeGreen : dangerRed
              }
            }

            // Middle Row: Specs, IP, Network
            RowLayout {
              Layout.fillWidth: true
              spacing: 24

              ColumnLayout {
                spacing: 2
                Text { text: "IPv4 ADDRESS"; font.pixelSize: 10; font.bold: true; color: textMuted }
                Text { text: modelData.ipv4 || "No IP assigned"; font.pixelSize: 12; font.bold: true; color: textPrimary }
              }

              ColumnLayout {
                spacing: 2
                Text { text: "PROVIDER / BACKEND"; font.pixelSize: 10; font.bold: true; color: textMuted }
                Text { text: (modelData.provider || "hetzner").toUpperCase(); font.pixelSize: 12; color: textSecondary }
              }

              ColumnLayout {
                spacing: 2
                Text { text: "NODE ID"; font.pixelSize: 10; font.bold: true; color: textMuted }
                Text { text: String(modelData.id); font.pixelSize: 12; color: textSecondary }
              }

              Item { Layout.fillWidth: true }
            }

            // Divider
            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: borderSubtle
            }

            // Bottom Row: Action Toolbar
            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Button {
                id: tmBtn
                text: "󰄛 Task Manager"
                background: Rectangle {
                  radius: 6
                  color: tmBtn.hovered ? "#0284c7" : "#0369a1"
                }
                contentItem: Text {
                  text: tmBtn.text
                  color: "#ffffff"
                  font.pixelSize: 11
                  font.bold: true
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                onClicked: taskManagerModal.openForServer(modelData)
              }

              Button {
                id: termBtn
                text: "󰆍 SSH Terminal"
                background: Rectangle {
                  radius: 6
                  color: termBtn.hovered ? "#1e293b" : "#0f172a"
                  border.color: borderSubtle
                }
                contentItem: Text {
                  text: termBtn.text
                  color: textPrimary
                  font.pixelSize: 11
                  font.bold: true
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                onClicked: ocloud.openTerminal(modelData.name, modelData.ipv4)
              }

              Button {
                id: mountVmBtn
                text: "󰋊 Mount Drive"
                enabled: modelData.status === "running"
                background: Rectangle {
                  radius: 6
                  color: mountVmBtn.hovered ? "#332200" : "#1e170a"
                  border.color: warningAmber
                }
                contentItem: Text {
                  text: mountVmBtn.text
                  color: warningAmber
                  font.pixelSize: 11
                  font.bold: true
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                onClicked: consentModal.openForServer(modelData.name, String(modelData.id))
              }

              Item { Layout.fillWidth: true }

              Button {
                id: pwrBtn
                text: modelData.status === "running" ? "󰐥 Power Off" : "󰐥 Power On"
                background: Rectangle {
                  radius: 6
                  color: pwrBtn.hovered ? "#1e293b" : "#0f172a"
                  border.color: borderSubtle
                }
                contentItem: Text {
                  text: pwrBtn.text
                  color: modelData.status === "running" ? dangerRed : homeGreen
                  font.pixelSize: 11
                  font.bold: true
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                  var act = modelData.status === "running" ? "stop" : "start";
                  ocloud.serverAction(act, String(modelData.id));
                }
              }

              Button {
                id: rebootBtn
                text: "󰑐 Reboot"
                enabled: modelData.status === "running"
                background: Rectangle {
                  radius: 6
                  color: rebootBtn.hovered ? "#1e293b" : "#0f172a"
                  border.color: borderSubtle
                }
                contentItem: Text {
                  text: rebootBtn.text
                  color: textSecondary
                  font.pixelSize: 11
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                onClicked: ocloud.serverAction("reboot", String(modelData.id))
              }

              Button {
                id: delBtn
                text: "󰅙 Delete"
                background: Rectangle {
                  radius: 6
                  color: delBtn.hovered ? "#3b0d0d" : "#1e0f0f"
                  border.color: "#7f1d1d"
                }
                contentItem: Text {
                  text: delBtn.text
                  color: dangerRed
                  font.pixelSize: 11
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
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
