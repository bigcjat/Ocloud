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
          spacing: 2

          Text {
            text: "AUTOMATED BACKUPS & SNAPSHOTS"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            font.letterSpacing: 1.2
          }

          Text {
            text: (scheduleConfig.enabled ? ("Active · " + (scheduleConfig.interval || "daily")) : "Schedule paused")
              + " · " + root.recentBackups.length + " recorded snapshots"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        Item { Layout.fillWidth: true }

        // Take Snapshot Button: Pinned flush right
        Rectangle {
          implicitWidth: snapText.implicitWidth + 16
          implicitHeight: 28
          radius: 2
          color: snapMouse.containsMouse
            ? Qt.darker(root.accentColor, 1.2)
            : root.accentColor

          Text {
            id: snapText
            anchors.centerIn: parent
            text: "+ Take Snapshot Now"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
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
      // TOP SUMMARY METRICS (3 INDUSTRIAL TILES)
      // =========================================================
      GridLayout {
        Layout.fillWidth: true
        columns: root.width > 750 ? 3 : 1
        columnSpacing: 10
        rowSpacing: 8

        // Card 1: Automation Status
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 56
          radius: 4
          color: root.cardBg
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
              Layout.preferredWidth: 6
              Layout.preferredHeight: 6
              Layout.alignment: Qt.AlignVCenter
              color: enableSwitch.checked
                ? ((typeof theme !== "undefined" && theme.green) ? theme.green : root.accentColor)
                : root.mutedColor
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text {
                text: "AUTOMATION ENGINE"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }
              Text {
                text: enableSwitch.checked ? ("Enabled · " + (scheduleConfig.interval || "daily")) : "Paused"
                font.family: root.appFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.textColor
              }
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
        }

        // Card 2: Destination Volume
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 56
          radius: 4
          color: root.cardBg
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            ThemeIcon {
              Layout.preferredWidth: 18
              Layout.preferredHeight: 18
              Layout.alignment: Qt.AlignVCenter
              source: "icons/hard-drive.svg"
              color: root.accentColor
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text {
                text: "TARGET VOLUME"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }
              Text {
                text: destinationList[destCombo.currentIndex] ? destinationList[destCombo.currentIndex].name : "Storage Box"
                font.family: root.appFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.textColor
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
          }
        }

        // Card 3: Integrity & Encryption
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 56
          radius: 4
          color: root.cardBg
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            ThemeIcon {
              Layout.preferredWidth: 18
              Layout.preferredHeight: 18
              Layout.alignment: Qt.AlignVCenter
              source: "icons/shield.svg"
              color: (typeof theme !== "undefined" && theme.green) ? theme.green : root.accentColor
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text {
                text: "INTEGRITY & VAULT"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }
              Text {
                text: "AES-256 · SHA-256 Ledger"
                font.family: root.appFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.textColor
              }
            }
          }
        }
      }

      // =========================================================
      // MAIN WORKSPACE: 2-COLUMN RESPONSIVE LAYOUT
      // =========================================================
      GridLayout {
        Layout.fillWidth: true
        columns: root.width > 900 ? 2 : 1
        columnSpacing: 10
        rowSpacing: 10

        // =======================================================
        // LEFT COLUMN: SCHEDULE & REPOSITORY CONFIGURATION
        // =======================================================
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          implicitHeight: schedInnerCol.implicitHeight + 24
          radius: 4
          color: root.cardBg
          border.color: root.borderCol
          border.width: 1

          ColumnLayout {
            id: schedInnerCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: "CONFIGURATION & PARAMETERS"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.mutedColor
              font.letterSpacing: 1.2
            }

            // Source Directory
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4

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
                  implicitHeight: 26
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
                    implicitHeight: 26
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

            // Destination volume
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4

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
                implicitHeight: 26
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

            // Frequency
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4

              Text {
                text: "AUTOMATION FREQUENCY"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }

              AppComboBox {
                id: intervalCombo
                Layout.fillWidth: true
                implicitHeight: 26
                model: ["daily", "hourly", "weekly"]
                currentIndex: {
                  if (scheduleConfig.interval === "hourly") return 1;
                  if (scheduleConfig.interval === "weekly") return 2;
                  return 0;
                }
              }
            }

            // Retention & Integrity Specs
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 4

              Text {
                text: "RETENTION POLICY"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }

              Text {
                text: "Keeps 7 daily and 4 weekly snapshots. Automatic pruning on destination volume."
                font.family: root.appFontFamily
                font.pixelSize: 10
                color: root.mutedColor
              }
            }

            Item { Layout.fillHeight: true }

            // Save configuration button: Pinned flush right
            RowLayout {
              Layout.fillWidth: true
              Item { Layout.fillWidth: true }

              Rectangle {
                implicitWidth: saveText.implicitWidth + 18
                implicitHeight: 26
                radius: 2
                color: saveMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                  : "transparent"
                border.color: saveMouse.containsMouse ? root.accentColor : root.borderCol
                border.width: 1

                Text {
                  id: saveText
                  anchors.centerIn: parent
                  text: "Save Schedule"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: saveMouse.containsMouse ? root.accentColor : root.textColor
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

        // =======================================================
        // RIGHT COLUMN: SNAPSHOT LEDGER HISTORY
        // =======================================================
        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          implicitHeight: Math.max(schedInnerCol.implicitHeight + 24, snapListCol.implicitHeight + 24)
          radius: 4
          color: root.cardBg
          border.color: root.borderCol
          border.width: 1

          ColumnLayout {
            id: snapListCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "SNAPSHOT HISTORY LEDGER"
                font.family: root.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: root.mutedColor
                font.letterSpacing: 1.2
              }
              Item { Layout.fillWidth: true }
              Text {
                text: root.recentBackups.length + " entries"
                font.family: root.appFontFamily
                font.pixelSize: 10
                color: root.mutedColor
              }
            }

            // Empty state
            Rectangle {
              visible: root.recentBackups.length === 0
              Layout.fillWidth: true
              Layout.fillHeight: true
              implicitHeight: 120
              radius: 2
              color: "transparent"
              border.color: root.borderCol
              border.width: 1

              ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: "No Snapshots in Ledger"
                  font.family: root.appFontFamily
                  font.pixelSize: 12
                  font.bold: true
                  color: root.textColor
                }
                Text {
                  Layout.alignment: Qt.AlignHCenter
                  text: "Click \"+ Take Snapshot Now\" to generate your first backup."
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                }
              }
            }

            // Snapshot ledger rows
            Repeater {
              model: root.recentBackups

              delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 2
                color: snapRowMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                  : "transparent"
                border.color: snapRowMouse.containsMouse ? root.accentColor : root.borderCol
                border.width: 1

                MouseArea {
                  id: snapRowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.NoButton
                }

                // Left details: status dot + snapshot id + metadata
                RowLayout {
                  anchors.left: parent.left
                  anchors.leftMargin: 10
                  anchors.right: snapActionRow.left
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 8

                  Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: modelData.status === "success"
                      ? ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
                      : ((typeof theme !== "undefined" && theme.danger) ? theme.danger : "#f7768e")
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                      Layout.fillWidth: true
                      text: modelData.id || "snapshot"
                      font.family: root.appFontFamily
                      font.pixelSize: 11
                      font.bold: true
                      color: root.textColor
                      elide: Text.ElideRight
                    }

                    Text {
                      Layout.fillWidth: true
                      text: (modelData.timestamp || "Recent") + " · " + (modelData.bytes_transferred || "0 B")
                      font.family: root.appFontFamily
                      font.pixelSize: 9
                      color: root.mutedColor
                      elide: Text.ElideRight
                    }
                  }
                }

                // Action buttons: Pinned flush right!
                RowLayout {
                  id: snapActionRow
                  anchors.right: parent.right
                  anchors.rightMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 6

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
              }
            }
          }
        }
      }
    }
  }
}
