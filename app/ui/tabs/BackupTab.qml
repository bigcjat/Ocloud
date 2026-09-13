import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  property var recentBackups: (backupInfo && backupInfo.recent) || []
  property var scheduleConfig: (backupInfo && backupInfo.schedule) || ({})

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
        title: "Automated Backups"
        subtitle: "Incremental snapshots to Storage Box, Home NAS, or S3 with automated scheduling"

        AppButton {
          text: "Take Snapshot Now"
          iconSource: "icons/archive.svg"
          variant: "primary"
          onClicked: ocloud.runBackup()
        }
      }

      // Schedule Configuration Card
      AppCard {
        Layout.fillWidth: true
        implicitHeight: schedCol.implicitHeight + 32

        ColumnLayout {
          id: schedCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
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
                source: Qt.resolvedUrl("../icons/archive.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Automated Snapshot Schedule"
                font.pixelSize: 15
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

            AppSwitch {
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

            Text {
              text: "Snapshot Frequency:"
              font.pixelSize: 12
              color: textSecondary
            }

            AppComboBox {
              id: intervalCombo
              implicitHeight: 32
              implicitWidth: 160
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
      AppCard {
        Layout.fillWidth: true
        implicitHeight: histCol.implicitHeight + 32

        ColumnLayout {
          id: histCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 14

          Text {
            text: "Recent Snapshot History"
            font.pixelSize: 15
            font.bold: true
            color: textPrimary
          }

          ColumnLayout {
            visible: recentBackups.length === 0
            spacing: 12

            Text {
              text: "No manual or automated snapshots recorded in the ledger yet."
              font.pixelSize: 12
              color: textSecondary
            }

            RowLayout {
              spacing: 28
              ColumnLayout {
                spacing: 2
                Text { text: "TARGET DESTINATION"; font.pixelSize: 10; font.bold: true; color: textMuted }
                Text { text: (storageBox && storageBox.mount_point) ? storageBox.mount_point : "~/Cloud"; font.pixelSize: 12; color: accentSky }
              }
              ColumnLayout {
                spacing: 2
                Text { text: "ENCRYPTION"; font.pixelSize: 10; font.bold: true; color: textMuted }
                Text { text: "AES-256 via Vault"; font.pixelSize: 12; color: textPrimary }
              }
              ColumnLayout {
                spacing: 2
                Text { text: "RETENTION POLICY"; font.pixelSize: 10; font.bold: true; color: textMuted }
                Text { text: "Last 7 daily, 4 weekly snapshots"; font.pixelSize: 12; color: textPrimary }
              }
            }
          }

          Repeater {
            model: recentBackups

            delegate: Rectangle {
              Layout.fillWidth: true
              height: 48
              radius: 6
              color: "#080e18"
              border.color: borderSubtle

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 16

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

                AppBadge {
                  text: (modelData.status || "success").toUpperCase()
                  variant: modelData.status === "success" ? "success" : "danger"
                }
              }
            }
          }
        }
      }

      // Disaster Recovery Policy Card
      AppCard {
        Layout.fillWidth: true
        implicitHeight: drCol.implicitHeight + 32

        ColumnLayout {
          id: drCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 12

          Text {
            text: "Disaster Recovery & Redundancy"
            font.pixelSize: 15
            font.bold: true
            color: textPrimary
          }

          GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 16

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4
              Text { text: "Point-in-Time Rollback"; font.pixelSize: 12; font.bold: true; color: textPrimary }
              Text { text: "Mount any snapshot directly as a read-only filesystem to inspect or restore specific folders."; font.pixelSize: 11; color: textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4
              Text { text: "Zero-Knowledge Encryption"; font.pixelSize: 12; font.bold: true; color: textPrimary }
              Text { text: "Files are encrypted at rest with hardware-derived keys before being transmitted to the Storage Box."; font.pixelSize: 11; color: textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4
              Text { text: "Integrity Verification"; font.pixelSize: 12; font.bold: true; color: textPrimary }
              Text { text: "SHA-256 block hashes are recorded in the local ledger to guarantee tamper-proof restores."; font.pixelSize: 11; color: textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            }
          }
        }
      }
    }
  }
}
