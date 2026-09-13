import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  property string selectedServerId: serverList.length > 0 ? String(serverList[0].id) : ""

  ScrollView {
    anchors.fill: parent
    anchors.margins: root.isNarrow ? 12 : 20
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 16

      // Unified Header
      AppHeader {
        title: "Waypipe App Suite"
        subtitle: "Stream native Wayland GUI applications from your Cloud VM or Home Workstation"

        RowLayout {
          spacing: 8
          Text {
            text: "Run on:"
            font.pixelSize: 12
            font.bold: true
            color: textSecondary
          }
          AppComboBox {
            id: targetCombo
            implicitHeight: 32
            implicitWidth: 240
            model: serverList.map(function(s) {
              return s.name + (s.isHomeWorkstation ? " [Home]" : " [Cloud]");
            })
            onCurrentIndexChanged: {
              if (currentIndex >= 0 && currentIndex < serverList.length) {
                root.selectedServerId = String(serverList[currentIndex].id);
              }
            }
          }
        }
      }

      // Window Integration Status Banner
      AppBanner {
        variant: "info"
        iconSource: "icons/shield.svg"
        title: "Native Window Integration Active"
        message: "Remote apps run cleanly with Waypipe title prefixing, Hyprland red borders (#d50c2d), and a non-intrusive bottom-right badge."
      }

      // App Cards Grid
      GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 16
        columnSpacing: 16

        // 1. Omarchy Arcade
        AppCard {
          Layout.fillWidth: true
          implicitHeight: 180

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
              Layout.fillWidth: true
              Rectangle {
                width: 56
                height: 24
                radius: 6
                color: "#1e1b4b"
                border.color: "#312e81"
                Text {
                  anchors.centerIn: parent
                  text: "ARCADE"
                  font.pixelSize: 10
                  font.bold: true
                  color: accentSky
                }
              }
              Item { Layout.fillWidth: true }
              AppBadge {
                text: "Featured"
                variant: "info"
              }
            }

            Text {
              text: "Omarchy Arcade"
              font.pixelSize: 15
              font.bold: true
              color: textPrimary
            }

            Text {
              text: "Full QML arcade launcher hosting 2048, Minesweeper, and retro arcade titles."
              font.pixelSize: 11
              color: textMuted
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            AppButton {
              text: "Launch Arcade"
              variant: "primary"
              onClicked: ocloud.launchApp(root.selectedServerId, "arcade")
            }
          }
        }

        // 2. 2048 Game
        AppCard {
          Layout.fillWidth: true
          implicitHeight: 180

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
              Layout.fillWidth: true
              Rectangle {
                width: 44
                height: 24
                radius: 6
                color: "#451a03"
                border.color: "#78350f"
                Text {
                  anchors.centerIn: parent
                  text: "2048"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#f59e0b"
                }
              }
              Item { Layout.fillWidth: true }
            }

            Text {
              text: "2048 QML"
              font.pixelSize: 15
              font.bold: true
              color: textPrimary
            }

            Text {
              text: "Smooth 60 FPS hardware accelerated sliding tile puzzle running directly on remote host."
              font.pixelSize: 11
              color: textMuted
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            AppButton {
              text: "Launch 2048"
              variant: "primary"
              onClicked: ocloud.launchApp(root.selectedServerId, "2048")
            }
          }
        }

        // 3. Minesweeper Game
        AppCard {
          Layout.fillWidth: true
          implicitHeight: 180

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            RowLayout {
              Layout.fillWidth: true
              Rectangle {
                width: 52
                height: 24
                radius: 6
                color: "#450a0a"
                border.color: "#7f1d1d"
                Text {
                  anchors.centerIn: parent
                  text: "MINES"
                  font.pixelSize: 10
                  font.bold: true
                  color: dangerRed
                }
              }
              Item { Layout.fillWidth: true }
            }

            Text {
              text: "Minesweeper"
              font.pixelSize: 15
              font.bold: true
              color: textPrimary
            }

            Text {
              text: "Classic logic grid sweeper running in pure QML with low-latency Waypipe forwarding."
              font.pixelSize: 11
              color: textMuted
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            AppButton {
              text: "Launch Minesweeper"
              variant: "primary"
              onClicked: ocloud.launchApp(root.selectedServerId, "minesweeper")
            }
          }
        }
      }

      // Custom Command Runner Card
      AppCard {
        Layout.fillWidth: true
        implicitHeight: customAppCol.implicitHeight + 32

        ColumnLayout {
          id: customAppCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 12

          Row {
            spacing: 8
            Image {
              width: 16
              height: 16
              anchors.verticalCenter: parent.verticalCenter
              source: Qt.resolvedUrl("../icons/terminal.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
            Text {
              text: "Run Any Custom Linux App over Waypipe"
              font.pixelSize: 14
              font.bold: true
              color: textPrimary
            }
          }

          Text {
            text: "Execute any GUI application installed on your remote server (e.g. gimp, blender, firefox, kdenlive, foot)"
            font.pixelSize: 11
            color: textMuted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            AppTextField {
              id: customCmdField
              Layout.fillWidth: true
              implicitHeight: 32
              placeholderText: "e.g. gimp, foot, mpv video.mp4"
            }

            AppButton {
              text: "Stream App"
              variant: "primary"
              onClicked: {
                if (customCmdField.text.trim()) {
                  ocloud.launchApp(root.selectedServerId, customCmdField.text.trim());
                }
              }
            }
          }
        }
      }
    }
  }
}
