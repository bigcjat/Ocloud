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

  ScrollView {
    anchors.fill: parent
    anchors.margins: 16
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 12

      // =========================================================
      // FLEET HEADER
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "COMPUTE FLEET"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            font.letterSpacing: 1.2
          }

          Text {
            text: serverList.length + " active nodes"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        // Procure VM Button
        Rectangle {
          implicitWidth: procText.implicitWidth + 16
          implicitHeight: 24
          radius: 2
          color: procMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: procMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          Text {
            id: procText
            anchors.centerIn: parent
            text: "+ Procure VM"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: procMouse.containsMouse ? root.accentColor : root.textColor
          }

          MouseArea {
            id: procMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: procureModal.openModal()
          }
        }

        // Add Node Button
        Rectangle {
          implicitWidth: addText.implicitWidth + 16
          implicitHeight: 24
          radius: 2
          color: addMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: addMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          Text {
            id: addText
            anchors.centerIn: parent
            text: "+ Add Node"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: addMouse.containsMouse ? root.accentColor : root.textColor
          }

          MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: addNodeModal.openModal()
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
        visible: serverList.length === 0
        Layout.fillWidth: true
        implicitHeight: 120
        radius: 4
        color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No Compute Nodes in Fleet"
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Click \"+ Procure VM\" or \"+ Add Node\" above to connect machines."
            font.family: root.appFontFamily
            font.pixelSize: 11
            color: root.mutedColor
          }
        }
      }

      // =========================================================
      // SERVER CARDS LIST (Flea-style, 100% Theme Colors)
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: serverList.length > 0

        Repeater {
          model: serverList

          delegate: Rectangle {
            id: serverItem
            Layout.fillWidth: true
            implicitHeight: itemCol.implicitHeight + 20
            radius: 4
            color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
            border.color: itemMouse.containsMouse ? root.accentColor : root.borderCol
            border.width: 1

            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }

            ColumnLayout {
              id: itemCol
              anchors.fill: parent
              anchors.margins: 12
              spacing: 8

              // Top Row: Status Dot, Icon, Title, Specs
              RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // 6px Flea Status Dot
                Rectangle {
                  Layout.preferredWidth: 6
                  Layout.preferredHeight: 6
                  Layout.alignment: Qt.AlignVCenter
                  color: modelData.status === "running"
                    ? ((typeof theme !== "undefined" && theme.green) ? theme.green : root.accentColor)
                    : (modelData.status === "starting" ? ((typeof theme !== "undefined" && theme.yellow) ? theme.yellow : "#e0af68") : root.mutedColor)
                }

                // Brand / Node Vector Icon
                ThemeIcon {
                  Layout.preferredWidth: 20
                  Layout.preferredHeight: 20
                  Layout.alignment: Qt.AlignVCenter
                  source: modelData.isHomeWorkstation ? "icons/device-workstation.svg" : ((modelData.providerIcon && modelData.providerIcon.length > 0) ? modelData.providerIcon : "icons/server.svg")
                  color: itemMouse.containsMouse ? root.accentColor : root.textColor
                }

                // Node Name & Type
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  RowLayout {
                    spacing: 6
                    Text {
                      text: modelData.name
                      font.family: root.appFontFamily
                      font.pixelSize: 13
                      font.bold: true
                      color: root.textColor
                      elide: Text.ElideRight
                    }

                    Text {
                      text: "· " + (modelData.status === "running" ? "online" : modelData.status)
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      color: modelData.status === "running"
                        ? ((typeof theme !== "undefined" && theme.green) ? theme.green : root.accentColor)
                        : root.mutedColor
                    }
                  }

                  Text {
                    text: (modelData.ipv4 || "No IP") + " · Tailscale: " + (modelData.tailscale_ip || modelData.tailscaleIp || "none") + " · " + (modelData.provider || "cloud").toUpperCase()
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    color: root.mutedColor
                    elide: Text.ElideRight
                  }
                }

                // Compact Desktop Action Toolbar
                RowLayout {
                  Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                  spacing: 6

                  // SSH Button
                  Rectangle {
                    implicitWidth: sshText.implicitWidth + 12
                    implicitHeight: 22
                    radius: 2
                    color: sshMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                      : "transparent"
                    border.color: sshMouse.containsMouse ? root.accentColor : root.borderCol
                    border.width: 1

                    Text {
                      id: sshText
                      anchors.centerIn: parent
                      text: "SSH"
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      font.bold: true
                      color: sshMouse.containsMouse ? root.accentColor : root.textColor
                    }

                    MouseArea {
                      id: sshMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: ocloud.openTerminal(modelData.name, modelData.tailscale_ip || modelData.ipv4, modelData.user || "root")
                    }
                  }

                  // Mount/Unmount Button
                  Rectangle {
                    visible: modelData.status === "running"
                    implicitWidth: mntText.implicitWidth + 12
                    implicitHeight: 22
                    radius: 2
                    color: mntMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                      : "transparent"
                    border.color: mntMouse.containsMouse ? root.accentColor : root.borderCol
                    border.width: 1

                    Text {
                      id: mntText
                      anchors.centerIn: parent
                      text: modelData.is_drive_mounted ? "Unmount" : "Mount"
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      font.bold: true
                      color: mntMouse.containsMouse ? root.accentColor : root.textColor
                    }

                    MouseArea {
                      id: mntMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        if (modelData.is_drive_mounted) {
                          ocloud.unmountEphemeralVm();
                        } else {
                          consentModal.openForServer(modelData.name, String(modelData.id));
                        }
                      }
                    }
                  }

                  // Top / Activity Button
                  Rectangle {
                    implicitWidth: topText.implicitWidth + 12
                    implicitHeight: 22
                    radius: 2
                    color: topMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                      : "transparent"
                    border.color: topMouse.containsMouse ? root.accentColor : root.borderCol
                    border.width: 1

                    Text {
                      id: topText
                      anchors.centerIn: parent
                      text: "Top"
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      font.bold: true
                      color: topMouse.containsMouse ? root.accentColor : root.textColor
                    }

                    MouseArea {
                      id: topMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: taskManagerModal.openForServer(modelData)
                    }
                  }

                  // Power Button
                  Rectangle {
                    enabled: modelData.status !== "starting" && modelData.status !== "stopping"
                    implicitWidth: pwrText.implicitWidth + 12
                    implicitHeight: 22
                    radius: 2
                    color: pwrMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                      : "transparent"
                    border.color: pwrMouse.containsMouse ? root.accentColor : root.borderCol
                    border.width: 1

                    Text {
                      id: pwrText
                      anchors.centerIn: parent
                      text: modelData.status === "running" ? "Off" : "On"
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      font.bold: true
                      color: pwrMouse.containsMouse ? root.accentColor : root.mutedColor
                    }

                    MouseArea {
                      id: pwrMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var act = modelData.status === "running" ? "stop" : "start";
                        ocloud.serverAction(act, String(modelData.id));
                      }
                    }
                  }

                  // Delete Button
                  Rectangle {
                    implicitWidth: delText.implicitWidth + 12
                    implicitHeight: 22
                    radius: 2
                    color: delMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                      : "transparent"
                    border.color: delMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                      : root.borderCol
                    border.width: 1

                    Text {
                      id: delText
                      anchors.centerIn: parent
                      text: "Delete"
                      font.family: root.appFontFamily
                      font.pixelSize: 10
                      font.bold: true
                      color: delMouse.containsMouse
                        ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                        : root.mutedColor
                    }

                    MouseArea {
                      id: delMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
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
    }
  }
}
