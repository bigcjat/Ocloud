import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  anchors.fill: parent

  ScrollView {
    anchors.fill: parent
    anchors.margins: 24
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 24

      // Header
      ColumnLayout {
        spacing: 2
        Text {
          text: "Storage & Drives"
          font.pixelSize: 22
          font.bold: true
          color: textPrimary
        }
        Text {
          text: "Permanent sovereign Storage Boxes, Ephemeral VM root filesystems, and Home NAS"
          font.pixelSize: 13
          color: textSecondary
        }
      }

      // 1. Permanent Storage Box Card
      Rectangle {
        Layout.fillWidth: true
        height: sbCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle
        border.width: 1

        ColumnLayout {
          id: sbCol
          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#0c4a6e"
              Text { anchors.centerIn: parent; text: "📦"; font.pixelSize: 16 }
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
              height: 24
              width: sbStatusText.implicitWidth + 16
              radius: 6
              color: storageBox.mounted ? "#064e3b" : "#1e293b"
              RowLayout {
                anchors.centerIn: parent
                spacing: 4
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
              text: storageBox.mounted ? "Unmount Storage Box" : "Mount to ~/Cloud"
              background: Rectangle {
                radius: 6
                color: storageBox.mounted ? (sbMountBtn.hovered ? "#334155" : "#1e293b") : (sbMountBtn.hovered ? "#0284c7" : "#0369a1")
              }
              contentItem: Text {
                text: sbMountBtn.text
                color: "#ffffff"
                font.pixelSize: 11
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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
        height: ephCol.implicitHeight + 40
        radius: 12
        color: "#181206"
        border.color: "#78350f"
        border.width: 1

        ColumnLayout {
          id: ephCol
          anchors.fill: parent
          anchors.margins: 20
          spacing: 14

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#451a03"
              Text { anchors.centerIn: parent; text: "⚡"; font.pixelSize: 16 }
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
              Text {
                anchors.centerIn: parent
                text: "⚠️ HIGH RISK"
                font.pixelSize: 10
                font.bold: true
                color: warningAmber
              }
            }
          }

          // Safety Alert Banner
          Rectangle {
            Layout.fillWidth: true
            height: 48
            radius: 8
            color: "#291804"
            border.color: "#78350f"

            RowLayout {
              anchors.fill: parent
              anchors.margins: 12
              spacing: 10
              Text { text: "⚠️"; font.pixelSize: 16 }
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
          Repeater {
            model: serverList.filter(function(s) { return s.status === "running"; })

            delegate: Rectangle {
              Layout.fillWidth: true
              height: 52
              radius: 8
              color: "#1c1407"
              border.color: "#78350f"

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text { text: "🖥"; font.pixelSize: 14 }
                Text {
                  text: modelData.name + " (" + modelData.ipv4 + ")"
                  font.pixelSize: 13
                  font.bold: true
                  color: textPrimary
                }
                Item { Layout.fillWidth: true }

                Button {
                  id: ephMountBtn
                  text: "Mount Ephemeral Drive"
                  background: Rectangle {
                    radius: 6
                    color: ephMountBtn.hovered ? "#451a03" : "#291804"
                    border.color: warningAmber
                  }
                  contentItem: Text {
                    text: ephMountBtn.text
                    color: warningAmber
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                  onClicked: consentModal.openForServer(modelData.name, String(modelData.id))
                }
              }
            }
          }
        }
      }

      // 3. Custom Storage / Home NAS Section
      Rectangle {
        Layout.fillWidth: true
        height: customCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle
        border.width: 1

        ColumnLayout {
          id: customCol
          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#064e3b"
              Text { anchors.centerIn: parent; text: "🏠"; font.pixelSize: 16 }
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
              height: 48
              radius: 8
              color: "#0f172a"
              border.color: borderSubtle

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Text { text: "📁"; font.pixelSize: 14 }
                Text { text: modelData.name + " (" + modelData.host + ")"; font.pixelSize: 12; font.bold: true; color: textPrimary }
                Item { Layout.fillWidth: true }
                Button {
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
