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
  readonly property color cardBg: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#111111"

  property var recentBackups: (backupInfo && backupInfo.recent) || []
  property var scheduleConfig: (backupInfo && backupInfo.schedule) || ({})
  property var cloudAccountsList: []

  function reloadCloudList() {
    try {
      cloudAccountsList = JSON.parse(ocloud.fetchCloudAccounts() || "[]");
    } catch(e) {
      cloudAccountsList = [];
    }
  }

  Component.onCompleted: {
    reloadCloudList();
  }

  Connections {
    target: ocloud
    function onCloudAccountsUpdated(jsonStr) {
      try {
        cloudAccountsList = JSON.parse(jsonStr);
      } catch(e) {
        cloudAccountsList = [];
      }
    }
  }

  readonly property var destinationList: {
    var list = [];
    if (storageBox && storageBox.configured) {
      list.push({ id: "storagebox", name: "Hetzner Storage Box (" + (storageBox.mount_point || "~/Cloud") + ")" });
    }
    for (var i = 0; i < cloudAccountsList.length; i++) {
      var a = cloudAccountsList[i];
      if (a.type !== "smb" && a.name !== "storagebox") {
        list.push({ id: a.name, name: (a.providerName || a.name) + " (" + a.mountPath + ")" });
      }
    }
    if (list.length === 0) {
      list.push({ id: "storagebox", name: "Hetzner Storage Box (~/Cloud)" });
    }
    return list;
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
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "AUTOMATED BACKUPS & SNAPSHOTS"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            letterSpacing: 1.2
          }

          Text {
            text: (scheduleConfig.enabled ? ("Active · " + (scheduleConfig.interval || "daily")) : "Schedule paused")
              + " · " + root.recentBackups.length + " recorded snapshots"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        // Take Snapshot Button
        Rectangle {
          implicitWidth: snapText.implicitWidth + 16
          implicitHeight: 24
          radius: 2
          color: snapMouse.containsMouse ? root.accentColor : "transparent"
          border.color: root.accentColor
          border.width: 1

          Text {
            id: snapText
            anchors.centerIn: parent
            text: "+ Take Snapshot Now"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: snapMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
              : root.accentColor
          }

          MouseArea {
            id: snapMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var targetDest = destinationList[destCombo.currentIndex] ? destinationList[destCombo.currentIndex].id : "storagebox";
              ocloud.runBackup(srcField.text.trim(), targetDest);
            }
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
      // SCHEDULE CONFIGURATION
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: schedCol.implicitHeight + 20
        radius: 2
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          id: schedCol
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
              width: 6
              height: 6
              radius: 3
              color: enableSwitch.checked
                ? ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
                : root.mutedColor
            }

            Text {
              text: "SCHEDULE CONFIGURATION"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.mutedColor
              letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "AUTOMATION:"
              font.family: root.appFontFamily
              font.pixelSize: 9
              font.bold: true
              color: root.mutedColor
            }

            AppSwitch {
              id: enableSwitch
              checked: scheduleConfig.enabled || false
              onToggled: {
                var targetDest = destinationList[destCombo.currentIndex] ? destinationList[destCombo.currentIndex].id : "storagebox";
                ocloud.setBackupSchedule(checked, intervalCombo.currentValue, srcField.text.trim(), targetDest);
              }
            }
          }

          // Source folder row
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
              text: "SOURCE DIRECTORY"
              font.family: root.appFontFamily
              font.pixelSize: 9
              font.bold: true
              color: root.mutedColor
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              TextField {
                id: srcField
                Layout.fillWidth: true
                implicitHeight: 24
                font.family: root.appFontFamily
                font.pixelSize: 11
                text: (scheduleConfig && scheduleConfig.source) || "~"
                placeholderText: "Enter directory (e.g. ~/Projects)"
                color: root.textColor
                background: Rectangle {
                  color: "transparent"
                  border.color: root.borderCol
                  border.width: 1
                  radius: 2
                }
              }

              Repeater {
                model: ["~", "~/Projects", "~/Documents"]
                delegate: Rectangle {
                  implicitWidth: pText.implicitWidth + 10
                  implicitHeight: 24
                  radius: 2
                  color: pMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: root.borderCol
                  border.width: 1

                  Text {
                    id: pText
                    anchors.centerIn: parent
                    text: modelData
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    color: root.textColor
                  }

                  MouseArea {
                    id: pMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: srcField.text = modelData
                  }
                }
              }
            }
          }

          // Target Destination & Frequency row
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: "DESTINATION DRIVE"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }

              AppComboBox {
                id: destCombo
                Layout.fillWidth: true
                implicitHeight: 24
                model: destinationList.map(function(d) { return d.name; })
                currentIndex: {
                  var savedDest = (scheduleConfig && scheduleConfig.destination) || "storagebox";
                  for (var i = 0; i < destinationList.length; i++) {
                    if (destinationList[i].id === savedDest || destinationList[i].name.toLowerCase().includes(savedDest.toLowerCase())) {
                      return i;
                    }
                  }
                  return 0;
                }
              }
            }

            ColumnLayout {
              implicitWidth: 120
              spacing: 3

              Text {
                text: "FREQUENCY"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }

              AppComboBox {
                id: intervalCombo
                implicitHeight: 24
                implicitWidth: 120
                model: ["daily", "hourly", "weekly"]
                currentIndex: {
                  if (scheduleConfig.interval === "hourly") return 1;
                  if (scheduleConfig.interval === "weekly") return 2;
                  return 0;
                }
                onCurrentValueChanged: {
                  var targetDest = destinationList[destCombo.currentIndex] ? destinationList[destCombo.currentIndex].id : "storagebox";
                  ocloud.setBackupSchedule(enableSwitch.checked, currentValue, srcField.text.trim(), targetDest);
                }
              }
            }

            Rectangle {
              Layout.alignment: Qt.AlignBottom
              implicitWidth: saveText.implicitWidth + 14
              implicitHeight: 24
              radius: 2
              color: saveMouse.containsMouse ? root.accentColor : "transparent"
              border.color: root.accentColor
              border.width: 1

              Text {
                id: saveText
                anchors.centerIn: parent
                text: "Save"
                font.family: root.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: saveMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                  : root.accentColor
              }

              MouseArea {
                id: saveMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var targetDest = destinationList[destCombo.currentIndex] ? destinationList[destCombo.currentIndex].id : "storagebox";
                  ocloud.setBackupSchedule(enableSwitch.checked, intervalCombo.currentValue, srcField.text.trim(), targetDest);
                }
              }
            }
          }
        }
      }

      // =========================================================
      // RECENT SNAPSHOT HISTORY
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "SNAPSHOT HISTORY"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            letterSpacing: 1.2
          }
          Item { Layout.fillWidth: true }
          Text {
            text: root.recentBackups.length + " entries in ledger"
            font.family: root.appFontFamily
            font.pixelSize: 10
            color: root.mutedColor
          }
        }

        // Empty state
        Rectangle {
          visible: root.recentBackups.length === 0
          Layout.fillWidth: true
          height: 44
          radius: 2
          color: "transparent"
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            Text {
              Layout.fillWidth: true
              text: "No manual or automated snapshots recorded in the ledger yet."
              font.family: root.appFontFamily
              font.pixelSize: 11
              color: root.mutedColor
            }
          }
        }

        // Single-column snapshot rows
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 6
          visible: root.recentBackups.length > 0

          Repeater {
            model: root.recentBackups

            delegate: Rectangle {
              Layout.fillWidth: true
              implicitHeight: 36
              radius: 2
              color: snapRowMouse.containsMouse
                ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : root.cardBg)
                : root.cardBg
              border.color: snapRowMouse.containsMouse ? root.accentColor : root.borderCol
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                // Status dot
                Rectangle {
                  width: 6
                  height: 6
                  radius: 3
                  color: modelData.status === "success"
                    ? ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
                    : ((typeof theme !== "undefined" && theme.danger) ? theme.danger : "#f7768e")
                }

                Text {
                  text: modelData.id
                  font.family: root.appFontFamily
                  font.pixelSize: 11
                  font.bold: true
                  color: root.textColor
                }

                Text {
                  text: modelData.timestamp
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: (modelData.bytes_transferred || "0 B") + " (" + (modelData.duration_seconds || 0) + "s)"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.accentColor
                }

                Text {
                  text: (modelData.status || "success").toUpperCase()
                  font.family: root.appFontFamily
                  font.pixelSize: 9
                  font.bold: true
                  color: modelData.status === "success"
                    ? ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
                    : root.mutedColor
                }
              }

              MouseArea {
                id: snapRowMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }
            }
          }
        }
      }

      // =========================================================
      // DISASTER RECOVERY SPECS (COMPACT ROW)
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: drCol.implicitHeight + 16
        radius: 2
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          id: drCol
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6

          Text {
            text: "DISASTER RECOVERY & INTEGRITY"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            letterSpacing: 1.2
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "ENCRYPTION"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              Text { text: "AES-256 via Vault"; font.family: root.appFontFamily; font.pixelSize: 11; color: root.textColor }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "RETENTION"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              Text { text: "7 daily, 4 weekly"; font.family: root.appFontFamily; font.pixelSize: 11; color: root.textColor }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "INTEGRITY"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              Text { text: "SHA-256 ledger verified"; font.family: root.appFontFamily; font.pixelSize: 11; color: root.textColor }
            }
          }
        }
      }
    }
  }
}
