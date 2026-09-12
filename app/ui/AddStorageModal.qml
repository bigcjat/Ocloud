import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: modal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.75)
  z: 1500

  signal storageAdded()

  function openModal() {
    storageNameField.text = "";
    mountPointField.text = "~/Storage";
    hostField.text = "";
    userField.text = "";
    secretField.text = "";
    modal.visible = true;
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block background click
  }

  Rectangle {
    width: 500
    height: modalCol.implicitHeight + 48
    radius: 16
    color: cardBg
    border.color: borderSubtle
    border.width: 1
    anchors.centerIn: parent

    ColumnLayout {
      id: modalCol
      anchors.fill: parent
      anchors.margins: 24
      spacing: 16

      // Header
      RowLayout {
        spacing: 10
        Image {
          width: 24
          height: 24
          source: Qt.resolvedUrl("icons/hard-drive.svg")
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
        ColumnLayout {
          spacing: 2
          Text {
            text: "Setup Managed Storage Device"
            font.pixelSize: 16
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Mount RAID storage boxes, S3 buckets, or local home NAS"
            font.pixelSize: 12
            color: textMuted
          }
        }
      }

      // Storage Provider Type
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Storage Provider Type"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Image {
            width: 28
            height: 28
            source: providerTypeCombo.currentIndex === 0 ? Qt.resolvedUrl("icons/hetzner.svg") : (providerTypeCombo.currentIndex === 1 ? Qt.resolvedUrl("icons/cloudflare.svg") : (providerTypeCombo.currentIndex === 2 ? Qt.resolvedUrl("icons/nas.svg") : (providerTypeCombo.currentIndex === 4 ? Qt.resolvedUrl("icons/gcp.svg") : Qt.resolvedUrl("icons/hetzner.svg"))))
            fillMode: Image.PreserveAspectFit
            smooth: true
          }
          ComboBox {
            id: providerTypeCombo
            Layout.fillWidth: true
            model: [
              "Hetzner Storage Box (WebDAV / SFTP RAID)",
              "S3 Object Store (AWS S3 / Cloudflare R2 / B2)",
              "Home NAS (SMB / NFS Network Share)",
              "Nextcloud / ownCloud (WebDAV)",
              "Google Drive",
              "Dropbox"
            ]
          onCurrentIndexChanged: {
            if (currentIndex === 0) { // Hetzner Box
              mountPointField.text = "~/Cloud";
              hostLabel.text = "Host (e.g. u123456.your-storagebox.de)";
              userLabel.text = "Storage Box Username (e.g. u123456)";
              secretLabel.text = "Storage Box Password";
            } else if (currentIndex === 1) { // S3 / R2
              mountPointField.text = "~/S3-Storage";
              hostLabel.text = "S3 Endpoint URL (e.g. https://<id>.r2.cloudflarestorage.com)";
              userLabel.text = "Access Key ID / Bucket";
              secretLabel.text = "Secret Access Key";
            } else if (currentIndex === 2) { // Home NAS
              mountPointField.text = "~/Home-NAS";
              hostLabel.text = "NAS IP Address or Hostname (e.g. 192.168.1.100)";
              userLabel.text = "Share Name / Username";
              secretLabel.text = "Password (Optional)";
            } else if (currentIndex === 3) { // Nextcloud
              mountPointField.text = "~/Nextcloud";
              hostLabel.text = "Nextcloud URL (e.g. https://cloud.example.com)";
              userLabel.text = "Username";
              secretLabel.text = "App Password";
            } else { // GDrive / Dropbox
              mountPointField.text = currentIndex === 4 ? "~/Google-Drive" : "~/Dropbox";
              hostLabel.text = "Account Email / Account Identifier";
              userLabel.text = "Client ID / App Key (Optional)";
              secretLabel.text = "Auth Token / Secret";
            }
          }
        }
      }

      // Display Name
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Device Name"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: storageNameField
          Layout.fillWidth: true
          placeholderText: "e.g. Primary Storage Box, Home Synology NAS"
          color: textPrimary
          placeholderTextColor: textMuted
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // Local Mount Point
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Local Mount Point"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: mountPointField
          Layout.fillWidth: true
          text: "~/Cloud"
          color: textPrimary
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // Host / Endpoint
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { id: hostLabel; text: "Host (e.g. u123456.your-storagebox.de)"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: hostField
          Layout.fillWidth: true
          color: textPrimary
          placeholderTextColor: textMuted
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // User / Access Key
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { id: userLabel; text: "Storage Box Username (e.g. u123456)"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: userField
          Layout.fillWidth: true
          color: textPrimary
          placeholderTextColor: textMuted
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // Secret / Password
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { id: secretLabel; text: "Storage Box Password"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: secretField
          Layout.fillWidth: true
          echoMode: TextInput.Password
          color: textPrimary
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // Actions
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Button {
          Layout.fillWidth: true
          text: "Cancel"
          background: Rectangle { radius: 6; color: "#1e293b" }
          contentItem: Text { text: "Cancel"; color: textSecondary; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
          onClicked: modal.visible = false
        }

        Button {
          Layout.fillWidth: true
          text: "󰐊 Save & Setup Target"
          background: Rectangle {
            radius: 6
            color: "#0284c7"
          }
          contentItem: Text { text: "󰐊 Save & Setup Target"; color: "#ffffff"; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter }
          onClicked: {
            if (storageNameField.text.trim()) {
              if (ocloud.setVaultSecret) {
                ocloud.setVaultSecret("storage_" + storageNameField.text.trim(), hostField.text.trim());
              }
              modal.storageAdded();
              modal.visible = false;
            }
          }
        }
      }
    }
  }
}
