import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color borderCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333"

  property var activeContainers: []
  property bool deploying: false

  readonly property var workloadTemplates: [
    { id: "postgres", name: "PostgreSQL 16", desc: "Relational database with persistent NVMe storage", icon: "icons/database.svg" },
    { id: "redis", name: "Redis Cache", desc: "In-memory cache & pub/sub message broker", icon: "icons/bolt.svg" },
    { id: "nginx", name: "Nginx Ingress", desc: "Reverse proxy & automated TLS termination", icon: "icons/world.svg" },
    { id: "ollama", name: "Ollama AI Engine", desc: "Local LLM inference & embeddings server", icon: "icons/cpu.svg" }
  ]

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
    anchors.margins: 16
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 12

      // =========================================================
      // HEADER
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          spacing: 2

          Text {
            text: "WORKLOADS & DOCKER"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            font.letterSpacing: 1.2
          }

          Text {
            text: root.activeContainers.length + " active containers"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        Item { Layout.fillWidth: true }

        // Offload Container Button
        Rectangle {
          implicitWidth: offText.implicitWidth + 16
          implicitHeight: 24
          radius: 2
          color: offMouse.containsMouse ? root.accentColor : "transparent"
          border.color: root.accentColor
          border.width: 1

          Text {
            id: offText
            anchors.centerIn: parent
            text: "+ Offload Container"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: offMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
              : root.accentColor
          }

          MouseArea {
            id: offMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: offloadModal.openModal()
          }
        }
      }

      // Thin separator
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.borderCol
      }

      // =========================================================
      // EMPTY STATE
      // =========================================================
      Rectangle {
        visible: root.activeContainers.length === 0
        Layout.fillWidth: true
        implicitHeight: 110
        radius: 4
        color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No Containers Running"
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Click \"+ Offload Container\" or select a template below to deploy workloads."
            font.family: root.appFontFamily
            font.pixelSize: 11
            color: root.mutedColor
          }
        }
      }

      // =========================================================
      // ACTIVE CONTAINERS LIST (RESPONSIVE 2-COLUMN GRID)
      // =========================================================
      GridLayout {
        visible: root.activeContainers.length > 0
        Layout.fillWidth: true
        columns: root.width > 800 ? 2 : 1
        columnSpacing: 10
        rowSpacing: 8

        Repeater {
          model: root.activeContainers

          delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            radius: 4
            color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
            border.color: cMouse.containsMouse ? root.accentColor : root.borderCol
            border.width: 1

            MouseArea {
              id: cMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }

            // Left details row
            RowLayout {
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.right: actionRow.left
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10

              Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                Layout.alignment: Qt.AlignVCenter
                color: (modelData.status || "").toLowerCase().indexOf("up") >= 0 || (modelData.status || "").toLowerCase().indexOf("run") >= 0
                  ? ((typeof theme !== "undefined" && theme.green) ? theme.green : root.accentColor)
                  : root.mutedColor
              }

              ThemeIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                source: "icons/docker.svg"
                color: cMouse.containsMouse ? root.accentColor : root.textColor
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                  spacing: 6
                  Text {
                    text: modelData.name || modelData.id || "container"
                    font.family: root.appFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: root.textColor
                    elide: Text.ElideRight
                  }

                  Text {
                    text: "· " + (modelData.status || "running")
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    color: root.mutedColor
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: (modelData.image || "image") + (modelData.ports ? (" · " + modelData.ports) : "")
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                  elide: Text.ElideRight
                }
              }
            }

            // Action Buttons: Pinned flush right!
            RowLayout {
              id: actionRow
              anchors.right: parent.right
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6

              // Exec Shell
              Rectangle {
                implicitWidth: shText.implicitWidth + 12
                implicitHeight: 24
                radius: 2
                color: shMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                  : "transparent"
                border.color: shMouse.containsMouse ? root.accentColor : root.borderCol
                border.width: 1

                Text {
                  id: shText
                  anchors.centerIn: parent
                  text: "Shell"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: shMouse.containsMouse ? root.accentColor : root.textColor
                }

                MouseArea {
                  id: shMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var ip = (serverList && serverList.length > 0) ? (serverList[0].tailscale_ip || serverList[0].ipv4) : "";
                    ocloud.openTerminal(modelData.name, ip);
                  }
                }
              }

              // Stop Container
              Rectangle {
                implicitWidth: stpText.implicitWidth + 12
                implicitHeight: 24
                radius: 2
                color: stpMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                  : "transparent"
                border.color: stpMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                  : root.borderCol
                border.width: 1

                Text {
                  id: stpText
                  anchors.centerIn: parent
                  text: "Stop"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: stpMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                    : root.mutedColor
                }

                MouseArea {
                  id: stpMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
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

      Item { Layout.preferredHeight: 4 }

      // =========================================================
      // 1-CLICK WORKLOAD TEMPLATES (RESPONSIVE 2-COLUMN GRID)
      // =========================================================
      Text {
        text: "WORKLOAD TEMPLATES"
        font.family: root.appFontFamily
        font.pixelSize: 10
        font.bold: true
        color: root.mutedColor
        font.letterSpacing: 1.2
      }

      GridLayout {
        Layout.fillWidth: true
        columns: root.width > 800 ? 2 : 1
        columnSpacing: 10
        rowSpacing: 8

        Repeater {
          model: root.workloadTemplates

          delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: 52
            radius: 4
            color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
            border.color: tMouse.containsMouse ? root.accentColor : root.borderCol
            border.width: 1

            MouseArea {
              id: tMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }

            // Left icon
            ThemeIcon {
              id: tIcon
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              width: 18
              height: 18
              source: modelData.icon
              color: tMouse.containsMouse ? root.accentColor : root.textColor
            }

            // Right Deploy Button: Pinned flush to right edge
            Rectangle {
              id: tBtn
              anchors.right: parent.right
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: tBtnText.implicitWidth + 16
              implicitHeight: 24
              radius: 2
              color: tBtnMouse.containsMouse
                ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                : "transparent"
              border.color: tBtnMouse.containsMouse ? root.accentColor : root.borderCol
              border.width: 1

              Text {
                id: tBtnText
                anchors.centerIn: parent
                text: "Deploy"
                font.family: root.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: tBtnMouse.containsMouse ? root.accentColor : root.textColor
              }

              MouseArea {
                id: tBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: offloadModal.openModal()
              }
            }

            // Center Text Block: bounded strictly between icon and button
            ColumnLayout {
              anchors.left: tIcon.right
              anchors.leftMargin: 10
              anchors.right: tBtn.left
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Text {
                Layout.fillWidth: true
                text: modelData.name
                font.family: root.appFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.textColor
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: modelData.desc
                font.family: root.appFontFamily
                font.pixelSize: 10
                color: root.mutedColor
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }

  // =========================================================
  // OFFLOAD TO CLOUD MODAL (Fluid & Tiling-Optimized)
  // =========================================================
  Rectangle {
    id: offloadModal
    visible: false
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.6)
    z: 2000

    function openModal() {
      offloadModal.visible = true;
    }

    MouseArea { anchors.fill: parent; onClicked: {} }

    Rectangle {
      width: Math.min(parent.width - 24, 460)
      implicitHeight: offloadCol.implicitHeight + 32
      radius: 4
      color: (typeof theme !== "undefined" && theme.darkBackground) ? theme.darkBackground : "#13141c"
      border.color: root.accentColor
      border.width: 1
      anchors.centerIn: parent

      ColumnLayout {
        id: offloadCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Offload Docker Container"
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "✕"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.mutedColor
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: offloadModal.visible = false
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.borderCol }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "CONTAINER IMAGE"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.mutedColor }
          AppTextField {
            id: imgField
            Layout.fillWidth: true
            placeholderText: "e.g. postgres:16-alpine or redis:alpine"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "CONTAINER NAME"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.mutedColor }
          AppTextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "e.g. my-postgres"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "PORT MAPPINGS"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.mutedColor }
          AppTextField {
            id: portField
            Layout.fillWidth: true
            placeholderText: "e.g. 5432:5432"
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Layout.topMargin: 4

          Item { Layout.fillWidth: true }

          Rectangle {
            implicitWidth: cnclText.implicitWidth + 14
            implicitHeight: 24
            radius: 2
            color: "transparent"
            border.color: root.borderCol
            border.width: 1
            Text { id: cnclText; anchors.centerIn: parent; text: "Cancel"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.textColor }
            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: offloadModal.visible = false }
          }

          Rectangle {
            implicitWidth: runText.implicitWidth + 14
            implicitHeight: 24
            radius: 2
            color: root.accentColor
            Text {
              id: runText
              anchors.centerIn: parent
              text: root.deploying ? "Deploying..." : "Launch Container"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !root.deploying && imgField.text.trim() !== ""
              onClicked: {
                root.deploying = true;
                var srvId = (serverList && serverList.length > 0) ? String(serverList[0].id) : "";
                if (srvId && ocloud.deployDockerContainer) {
                  ocloud.deployDockerContainer(srvId, imgField.text.trim(), nameField.text.trim(), portField.text.trim(), function(ok, msg) {
                    root.deploying = false;
                    if (ok) {
                      offloadModal.visible = false;
                      imgField.text = "";
                      nameField.text = "";
                      portField.text = "";
                    }
                  });
                } else {
                  root.deploying = false;
                }
              }
            }
          }
        }
      }
    }
  }
}
