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
      spacing: 24

      // Header
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          spacing: 2
          Text {
            text: "Storage & Drives"
            font.pixelSize: 22
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Permanent RAID Storage Boxes, temporary VM root filesystems, S3 buckets, and local storage"
            font.pixelSize: 13
            color: textSecondary
          }
        }

        Item { Layout.fillWidth: true }

        Button {
          id: addStorageBtn
          text: "+ Add Storage Device"
          background: Rectangle {
            radius: 8
            color: addStorageBtn.hovered ? "#0284c7" : "#0369a1"
          }
          contentItem: Text {
            text: addStorageBtn.text
            color: "#ffffff"
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: addStorageModal.openModal()
        }
      }

      // 1. Permanent Storage Box Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: sbCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle
        border.width: 1

        ColumnLayout {
          id: sbCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Image {
              width: 32
              height: 32
              source: Qt.resolvedUrl("icons/hetzner.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Hetzner Storage Box (Permanent RAID)"
                font.pixelSize: 16
                font.bold: true
                color: textPrimary
              }
              Text {
                text: storageBox.configured ? (storageBox.username + "@" + storageBox.host) : "Not configured in Vault"
                font.pixelSize: 11
                color: textMuted
              }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
              Layout.preferredWidth: sbStatusRow.implicitWidth + 24
              Layout.preferredHeight: 26
              radius: 6
              color: storageBox.mounted ? "#064e3b" : "#1e293b"
              Row {
                id: sbStatusRow
                anchors.centerIn: parent
                spacing: 6
                Text { text: storageBox.mounted ? "●" : "○"; font.pixelSize: 10; color: storageBox.mounted ? homeGreen : textMuted }
                Text {
                  id: sbStatusText
                  text: storageBox.mounted ? "Mounted at ~/Cloud" : "Not Mounted"
                  font.pixelSize: 11
                  font.bold: true
                  color: storageBox.mounted ? homeGreen : textMuted
                }
              }
            }
          }

          // Quota Bar
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "Capacity Usage"
                font.pixelSize: 11
                font.bold: true
                color: textSecondary
              }
              Item { Layout.fillWidth: true }
              Text {
                text: storageBox.configured ? (Math.round((storageBox.used_bytes || 0) / (1024*1024*1024)) + " GB / " + Math.round((storageBox.total_bytes || 1073741824000) / (1024*1024*1024)) + " GB (" + (storageBox.used_percent || 0) + "%)") : "0 GB / 1000 GB"
                font.pixelSize: 11
                color: accentSky
                font.bold: true
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 8
              radius: 4
              color: "#1e293b"

              Rectangle {
                height: parent.height
                radius: 4
                width: Math.min(parent.width, Math.max(6, parent.width * ((storageBox.used_percent || 0.1) / 100.0)))
                gradient: Gradient {
                  GradientStop { position: 0.0; color: accentSky }
                  GradientStop { position: 1.0; color: "#0284c7" }
                }
              }
            }
          }

          // Actions
          RowLayout {
            Layout.fillWidth: true
            Text {
              text: "Encrypted via Vault · Static rclone v1.75.1 FUSE mount · Zero data loss on reboot"
              font.pixelSize: 11
              color: textMuted
            }
            Item { Layout.fillWidth: true }
            Button {
              id: sbMountBtn
              implicitWidth: sbMountRow.implicitWidth + 24
              implicitHeight: 32
              background: Rectangle {
                radius: 6
                color: storageBox.mounted ? (sbMountBtn.hovered ? "#334155" : "#1e293b") : (sbMountBtn.hovered ? "#0284c7" : "#0369a1")
              }
              contentItem: Row {
                id: sbMountRow
                anchors.centerIn: parent
                spacing: 8
                Text {
                  text: storageBox.mounted ? "󰅟" : "󰋊"
                  font.pixelSize: 13
                  color: "#ffffff"
                }
                Text {
                  text: storageBox.mounted ? "Unmount Storage Box" : "Mount to ~/Cloud"
                  color: "#ffffff"
                  font.pixelSize: 11
                  font.bold: true
                }
              }
              onClicked: {
                if (storageBox.mounted) ocloud.unmountStorageBox();
                else ocloud.mountStorageBox();
              }
            }
          }
        }
      }

      // 2. Ephemeral Compute Drives Section (With loud Safety Warning!)
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: ephCol.implicitHeight + 40
        radius: 12
        color: "#181206"
        border.color: "#78350f"
        border.width: 1

        ColumnLayout {
          id: ephCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 20
          spacing: 14

          RowLayout {
            Layout.fillWidth: true
            Image {
              width: 32
              height: 32
              source: Qt.resolvedUrl("icons/hetzner.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Ephemeral Compute Storage"
                font.pixelSize: 16
                font.bold: true
                color: warningAmber
              }
              Text {
                text: "Direct SFTP FUSE mount to companion VM root filesystem (/root -> ~/Companion-VM)"
                font.pixelSize: 11
                color: textSecondary
              }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
              height: 24
              width: 120
              radius: 6
              color: "#451a03"
              border.color: warningAmber
              RowLayout {
                anchors.centerIn: parent
                spacing: 4
                Image {
                  width: 12
                  height: 12
                  source: Qt.resolvedUrl("icons/alert-triangle.svg")
                  fillMode: Image.PreserveAspectFit
                }
                Text {
                  text: "EPHEMERAL"
                  font.pixelSize: 10
                  font.bold: true
                  color: warningAmber
                }
              }
            }
          }

          // Safety Alert Banner
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: warnRow.implicitHeight + 20
            implicitHeight: warnRow.implicitHeight + 20
            radius: 8
            color: "#291804"
            border.color: "#78350f"

            RowLayout {
              id: warnRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 10
              spacing: 10
              Image {
                width: 18
                height: 18
                source: Qt.resolvedUrl("icons/alert-triangle.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
              Text {
                text: "DATA-LOSS WARNING: Files created on companion VMs are stored on ephemeral local NVMe disks. When you power off or terminate the VM, ALL DATA IS WIPED. Do not use for long-term storage!"
                font.pixelSize: 11
                color: "#fde68a"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
              }
            }
          }

          // Active VM Rows
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
              model: serverList.filter(function(s) { return s.status === "running"; })

              delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: 8
                color: "#1c1407"
                border.color: "#78350f"

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 14
                  anchors.rightMargin: 14
                  spacing: 12

                  Image {
                    width: 16
                    height: 16
                    source: Qt.resolvedUrl("icons/server.svg")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                  }
                  Text {
                    text: modelData.name + " (" + modelData.ipv4 + ")"
                    font.pixelSize: 13
                    font.bold: true
                    color: textPrimary
                  }
                  Item { Layout.fillWidth: true }

                  Button {
                    id: ephMountBtn
                    implicitWidth: ephMountRow.implicitWidth + 24
                    implicitHeight: 32
                    background: Rectangle {
                      radius: 6
                      color: modelData.is_drive_mounted ? (ephMountBtn.hovered ? "#3b1114" : "#240d10") : (ephMountBtn.hovered ? "#451a03" : "#291804")
                      border.color: modelData.is_drive_mounted ? dangerRed : warningAmber
                    }
                    contentItem: Row {
                      id: ephMountRow
                      anchors.centerIn: parent
                      spacing: 8
                      Text {
                        text: modelData.is_drive_mounted ? "󰅟" : "󰋊"
                        font.pixelSize: 13
                        color: modelData.is_drive_mounted ? dangerRed : warningAmber
                      }
                      Text {
                        text: modelData.is_drive_mounted ? "Unmount Ephemeral Drive" : "Mount Ephemeral Drive"
                        color: modelData.is_drive_mounted ? dangerRed : warningAmber
                        font.pixelSize: 11
                        font.bold: true
                      }
                    }
                    onClicked: {
                      if (modelData.is_drive_mounted) {
                        ocloud.unmountEphemeralVm();
                      } else {
                        consentModal.openForServer(modelData.name, String(modelData.id));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // 3. Custom Storage / Home NAS Section
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: customCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle
        border.width: 1

        ColumnLayout {
          id: customCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Image {
              width: 32
              height: 32
              source: Qt.resolvedUrl("icons/nas.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Home NAS & Tailscale Storage Arrays"
                font.pixelSize: 16
                font.bold: true
                color: textPrimary
              }
              Text {
                text: "Mount your private home storage arrays, TrueNAS, or Synology boxes over Tailscale"
                font.pixelSize: 11
                color: textMuted
              }
            }
            Item { Layout.fillWidth: true }
          }

          Text {
            visible: customStorage.length === 0
            text: "No custom home storage arrays configured. Add your Home NAS or Tailscale SFTP target in Settings."
            font.pixelSize: 12
            color: textMuted
          }

          Repeater {
            model: customStorage

            delegate: Rectangle {
              Layout.fillWidth: true
              implicitHeight: 48
              radius: 8
              color: "#0f172a"
              border.color: borderSubtle

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Image {
                  width: 16
                  height: 16
                  source: Qt.resolvedUrl("icons/hard-drive.svg")
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                }
                Text { text: modelData.name + " (" + modelData.host + ")"; font.pixelSize: 12; font.bold: true; color: textPrimary }
                Item { Layout.fillWidth: true }
                Button {
                  implicitWidth: 80
                  implicitHeight: 28
                  text: modelData.mounted ? "Unmount" : "Mount"
                  onClicked: {
                    if (modelData.mounted) ocloud.unmountStorageTarget(modelData.id);
                    else ocloud.mountStorageTarget(modelData.id);
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
