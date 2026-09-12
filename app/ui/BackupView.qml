import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  property var recentBackups: (backupInfo && backupInfo.recent) || []
  property var scheduleConfig: (backupInfo && backupInfo.schedule) || ({})

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
            text: "Automated Backups"
            font.pixelSize: 22
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Incremental snapshots to Storage Box, Home NAS, or S3 with automated scheduling"
            font.pixelSize: 13
            color: textSecondary
          }
        }

        Item { Layout.fillWidth: true }

        Button {
          id: runNowBtn
          implicitWidth: runNowRow.implicitWidth + 24
          implicitHeight: 34
          background: Rectangle {
            radius: 8
            gradient: Gradient {
              GradientStop { position: 0.0; color: runNowBtn.hovered ? "#059669" : "#047857" }
              GradientStop { position: 1.0; color: runNowBtn.hovered ? "#047857" : "#065f46" }
            }
          }
          contentItem: Row {
            id: runNowRow
            anchors.centerIn: parent
            spacing: 8
            Text { text: "󰑐"; font.pixelSize: 13; color: "#ffffff" }
            Text {
              text: "Take Snapshot Now"
              color: "#ffffff"
              font.pixelSize: 12
              font.bold: true
            }
          }
          onClicked: ocloud.runBackup()
        }
      }

      // Schedule Configuration Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: schedCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle

        ColumnLayout {
          id: schedCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#064e3b"
              Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: Qt.resolvedUrl("icons/archive.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Automated Snapshot Schedule"
                font.pixelSize: 16
                font.bold: true
                color: textPrimary
              }
              Text {
                text: "Snapshots exclude temporary files, cache dirs, and node_modules"
                font.pixelSize: 11
                color: textMuted
              }
            }
            Item { Layout.fillWidth: true }

            Switch {
              id: enableSwitch
              checked: scheduleConfig.enabled || false
              onToggled: {
                ocloud.setBackupSchedule(checked, intervalCombo.currentValue);
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text { text: "Snapshot Frequency:"; font.pixelSize: 12; color: textSecondary }

            ComboBox {
              id: intervalCombo
              model: ["daily", "hourly", "weekly"]
              currentIndex: {
                if (scheduleConfig.interval === "hourly") return 1;
                if (scheduleConfig.interval === "weekly") return 2;
                return 0;
              }
              onCurrentValueChanged: {
                ocloud.setBackupSchedule(enableSwitch.checked, currentValue);
              }
            }

            Text {
              text: "Default: Daily at 03:00 AM"
              font.pixelSize: 11
              color: textMuted
            }
          }
        }
      }

      // History Timeline Table Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: histCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle

        ColumnLayout {
          id: histCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 20
          spacing: 14

          Text {
            text: "Recent Snapshot History"
            font.pixelSize: 16
            font.bold: true
            color: textPrimary
          }

          Text {
            visible: recentBackups.length === 0
            text: "No backups recorded yet. Click 'Take Snapshot Now' to initiate the first snapshot."
            font.pixelSize: 12
            color: textMuted
          }

          Repeater {
            model: recentBackups

            delegate: Rectangle {
              Layout.fillWidth: true
              height: 48
              radius: 8
              color: "#080e18"
              border.color: borderSubtle

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 16

                Rectangle {
                  width: 8
                  height: 8
                  radius: 4
                  color: modelData.status === "success" ? homeGreen : dangerRed
                }

                Text {
                  text: modelData.id
                  font.pixelSize: 12
                  font.bold: true
                  color: textPrimary
                }

                Text {
                  text: modelData.timestamp
                  font.pixelSize: 11
                  color: textMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: (modelData.bytes_transferred || "0 B") + " (" + (modelData.duration_seconds || 0) + "s)"
                  font.pixelSize: 11
                  color: accentSky
                }

                Text {
                  text: (modelData.status || "success").toUpperCase()
                  font.pixelSize: 10
                  font.bold: true
                  color: modelData.status === "success" ? homeGreen : dangerRed
                }
              }
            }
          }
        }
      }
    }
  }
}
