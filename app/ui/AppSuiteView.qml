import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  anchors.fill: parent

  property string selectedServerId: serverList.length > 0 ? String(serverList[0].id) : ""

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
            text: "Waypipe App Suite"
            font.pixelSize: 22
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Stream native Wayland GUI applications from your Cloud VM or Home Workstation"
            font.pixelSize: 13
            color: textSecondary
          }
        }

        Item { Layout.fillWidth: true }

        // Host Target Selector
        RowLayout {
          spacing: 8
          Text { text: "Run on:"; font.pixelSize: 12; font.bold: true; color: textSecondary }
          ComboBox {
            id: targetCombo
            model: serverList.map(function(s) {
              return s.name + (s.isHomeWorkstation ? " [🏠 Home]" : " [☁ Cloud]");
            })
            onCurrentIndexChanged: {
              if (currentIndex >= 0 && currentIndex < serverList.length) {
                root.selectedServerId = String(serverList[currentIndex].id);
              }
            }
          }
        }
      }

      // Zero-Injection Window Branding Notice Card
      Rectangle {
        Layout.fillWidth: true
        height: 64
        radius: 10
        color: "#0a1329"
        border.color: "#1e3a8a"

        RowLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 12
          Text { text: "🛡️"; font.pixelSize: 20 }
          ColumnLayout {
            spacing: 2
            Text {
              text: "Zero-Injection Sovereign Branding Active"
              font.pixelSize: 12
              font.bold: true
              color: accentSky
            }
            Text {
              text: "Remote apps run cleanly with Waypipe title prefixing, Hyprland red borders (#d50c2d), and a non-intrusive bottom-right badge."
              font.pixelSize: 11
              color: textSecondary
            }
          }
        }
      }

      // App Cards Grid
      GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 16
        columnSpacing: 16

        // 1. Omarchy Arcade
        Rectangle {
          Layout.fillWidth: true
          height: 180
          radius: 12
          color: cardBg
          border.color: borderSubtle

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
              Layout.fillWidth: true
              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: "#1e1b4b"
                Text { anchors.centerIn: parent; text: "🕹"; font.pixelSize: 18 }
              }
              Item { Layout.fillWidth: true }
              Rectangle {
                height: 20
                width: 70
                radius: 4
                color: "#0284c7"
                Text { anchors.centerIn: parent; text: "FEATURED"; font.pixelSize: 9; font.bold: true; color: "#ffffff" }
              }
            }

            Text {
              text: "Omarchy Arcade"
              font.pixelSize: 16
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

            Button {
              id: launchArcadeBtn
              text: "🚀 Launch Arcade"
              Layout.fillWidth: true
              background: Rectangle {
                radius: 6
                gradient: Gradient {
                  GradientStop { position: 0.0; color: launchArcadeBtn.hovered ? "#0284c7" : "#0369a1" }
                  GradientStop { position: 1.0; color: launchArcadeBtn.hovered ? "#0369a1" : "#075985" }
                }
              }
              contentItem: Text {
                text: launchArcadeBtn.text
                color: "#ffffff"
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: ocloud.launchApp(root.selectedServerId, "arcade")
            }
          }
        }

        // 2. 2048 Game
        Rectangle {
          Layout.fillWidth: true
          height: 180
          radius: 12
          color: cardBg
          border.color: borderSubtle

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: "#3b1d06"
                Text { anchors.centerIn: parent; text: "🔢"; font.pixelSize: 18 }
              }
              Item { Layout.fillWidth: true }
            }

            Text {
              text: "2048 QML"
              font.pixelSize: 16
              font.bold: true
              color: textPrimary
            }

            Text {
              text: "Smooth 60 FPS hardware accelerated sliding tile puzzle running directly on remote GPU/CPU."
              font.pixelSize: 11
              color: textMuted
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            Button {
              id: launch2048Btn
              text: "Launch 2048"
              Layout.fillWidth: true
              background: Rectangle {
                radius: 6
                color: launch2048Btn.hovered ? "#1e293b" : "#0f172a"
                border.color: borderSubtle
              }
              contentItem: Text {
                text: launch2048Btn.text
                color: textPrimary
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: ocloud.launchApp(root.selectedServerId, "2048")
            }
          }
        }

        // 3. Minesweeper Game
        Rectangle {
          Layout.fillWidth: true
          height: 180
          radius: 12
          color: cardBg
          border.color: borderSubtle

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
              Rectangle {
                width: 36
                height: 36
                radius: 8
                color: "#1c1917"
                Text { anchors.centerIn: parent; text: "💣"; font.pixelSize: 18 }
              }
              Item { Layout.fillWidth: true }
            }

            Text {
              text: "Minesweeper"
              font.pixelSize: 16
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

            Button {
              id: launchMinesBtn
              text: "Launch Minesweeper"
              Layout.fillWidth: true
              background: Rectangle {
                radius: 6
                color: launchMinesBtn.hovered ? "#1e293b" : "#0f172a"
                border.color: borderSubtle
              }
              contentItem: Text {
                text: launchMinesBtn.text
                color: textPrimary
                font.pixelSize: 12
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: ocloud.launchApp(root.selectedServerId, "minesweeper")
            }
          }
        }
      }

      // Custom Command Runner Card
      Rectangle {
        Layout.fillWidth: true
        height: customAppCol.implicitHeight + 36
        radius: 12
        color: cardBg
        border.color: borderSubtle

        ColumnLayout {
          id: customAppCol
          anchors.fill: parent
          anchors.margins: 18
          spacing: 12

          Text {
            text: "⚡ Run Any Custom Linux App over Waypipe"
            font.pixelSize: 14
            font.bold: true
            color: textPrimary
          }

          Text {
            text: "Execute any GUI application installed on your remote server (e.g. gimp, blender, firefox, kdenlive, foot)"
            font.pixelSize: 11
            color: textMuted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TextField {
              id: customCmdField
              Layout.fillWidth: true
              placeholderText: "e.g. gimp, foot, mpv video.mp4"
              color: textPrimary
              placeholderTextColor: textMuted
              background: Rectangle {
                radius: 6
                color: "#080e18"
                border.color: borderSubtle
              }
            }

            Button {
              text: "Stream App"
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
