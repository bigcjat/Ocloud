import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  property var cloudAccounts: []
  property var storagePlugins: []

  function reloadPlugins() {
    try {
      var raw = ocloud.fetchStoragePlugins();
      if (raw && raw.length > 2) {
        storagePlugins = JSON.parse(raw);
      }
    } catch (e) {
      storagePlugins = [];
    }
  }

  function reloadAccounts() {
    var raw = ocloud.fetchCloudAccounts();
    try {
      cloudAccounts = JSON.parse(raw);
    } catch (e) {
      cloudAccounts = [];
    }
    reloadPlugins();
  }

  function isPluginConnected(plugin) {
    if (!cloudAccounts || cloudAccounts.length === 0) return false;
    return cloudAccounts.some(function(acc) {
      return acc.name === plugin.id ||
             acc.name === plugin.defaultRemoteName ||
             (acc.providerId && acc.providerId === plugin.id) ||
             (plugin.id === "google_drive" && (acc.type === "drive" || acc.name === "gdrive")) ||
             (plugin.id === "onedrive" && (acc.type === "onedrive" || acc.name === "onedrive")) ||
             (plugin.id === "dropbox" && (acc.type === "dropbox" || acc.name === "dropbox")) ||
             (plugin.id === "hetzner_storage_box" && (acc.type === "storagebox" || acc.name === "storagebox")) ||
             (plugin.id === "cloudflare_r2" && (acc.name === "r2" || acc.name === "r2-ocloud"));
    });
  }

  Component.onCompleted: {
    reloadAccounts();
    reloadPlugins();
  }

  onVisibleChanged: {
    if (visible) {
      reloadAccounts();
      reloadPlugins();
    }
  }

  Connections {
    target: ocloud
    function onCloudAccountsUpdated(jsonStr) {
      try {
        cloudAccounts = JSON.parse(jsonStr);
      } catch (e) {
        cloudAccounts = [];
      }
    }
  }

  function getRemoteByName(rName) {
    for (var i = 0; i < cloudAccounts.length; i++) {
      if (cloudAccounts[i].name === rName || cloudAccounts[i].type === rName) {
        return cloudAccounts[i];
      }
    }
    return null;
  }

  ScrollView {
    anchors.fill: parent
    anchors.margins: root.isNarrow ? 12 : 20
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 24

      // Section Header
      AppHeader {
        title: "Cloud Accounts"
        subtitle: "Manage your linked cloud storage services, credentials, and accounts"

        RowLayout {
          spacing: 10

          AppButton {
            text: "Refresh"
            iconSource: "icons/refresh.svg"
            variant: "secondary"
            onClicked: reloadAccounts()
          }

          AppButton {
            text: "Add Cloud Storage"
            iconSource: "icons/plus.svg"
            variant: "primary"
            onClicked: addStorageModal.openModal()
          }
        }
      }

      // Security Explainer Banner
      AppBanner {
        variant: "info"
        iconSource: "icons/user-circle.svg"
        title: "Authenticated Cloud Services"
        message: "OAuth tokens, API credentials, and cloud sessions are stored securely on this machine. Click '+ Add Cloud Storage' to connect a new personal cloud or object storage bucket."

        AppBadge {
          variant: "success"
          text: cloudAccounts.filter(function(a) { return a.type !== "smb"; }).length + " Connected"
        }
      }

      // =========================================================
      // SECTION 1: CONNECTED ACCOUNTS
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 12

        Text {
          text: "CONNECTED CLOUD ACCOUNTS (" + cloudAccounts.filter(function(a) { return a.type !== "smb"; }).length + ")"
          font.pixelSize: 11
          font.bold: true
          color: "#94a3b8"
        }

        Repeater {
          model: cloudAccounts.filter(function(a) { return a.type !== "smb"; })

          delegate: AccountCard {
            accountName: modelData.providerName || modelData.name
            accountType: (modelData.type === "drive" || modelData.type === "onedrive" || modelData.type === "dropbox") ? "Personal Cloud" : "Object Storage"
            iconSource: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : (modelData.iconSvg || "icons/cloud.svg")
            userDetail: modelData.accountDetail || "Authenticated Session"
            authMethod: (modelData.type === "drive" || modelData.type === "onedrive" || modelData.type === "dropbox") ? "OAuth 2.0" : (modelData.type === "storagebox" ? "SSH / SFTP" : "API Key")
            isConnected: true
            statusText: "Connected"
            statusVariant: "success"
            onDisconnectClicked: {
              if (modelData.name) {
                ocloud.disconnectCloudAccount(modelData.name);
              }
            }
          }
        }
      }

      // =========================================================
      // SECTION 2: AVAILABLE CLOUD PLATFORMS (TO CONNECT)
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 12

        Text {
          text: "AVAILABLE CLOUD PLATFORMS"
          font.pixelSize: 11
          font.bold: true
          color: "#64748b"
        }

        Repeater {
          model: storagePlugins.filter(function(plugin) {
            return !isPluginConnected(plugin);
          })

          delegate: AccountCard {
            accountName: modelData.name
            accountType: modelData.category === "personal" ? "Personal Cloud" : "Object Storage"
            iconSource: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : (modelData.iconSvg || "icons/cloud.svg")
            userDetail: modelData.tagline || ("Connect " + modelData.name)
            authMethod: modelData.authType === "oauth" ? "OAuth 2.0" : (modelData.authType === "webdav" ? "App Password / WebDAV" : "API Key / S3")
            isConnected: false
            statusText: "Not Linked"
            statusVariant: "neutral"
            onConnectClicked: addStorageModal.openModal(modelData.id)
          }
        }
      }

      // Advanced CLI / Rclone Card
      AppCard {
        implicitHeight: rcloneRow.implicitHeight + 28

        RowLayout {
          id: rcloneRow
          anchors.fill: parent
          anchors.margins: 16
          spacing: 16

          Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 8
            color: "#141e30"
            border.color: "#1e293b"
            Image {
              anchors.centerIn: parent
              width: 22
              height: 22
              source: Qt.resolvedUrl("../icons/terminal.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
              text: "Advanced Cloud Storage CLI"
              font.pixelSize: 14
              font.bold: true
              color: textPrimary
            }
            Text {
              text: "Manage advanced rclone storage remotes, encryption filters, and chunking"
              font.pixelSize: 11
              color: textMuted
            }
          }

          AppButton {
            text: "Rclone Configurator"
            iconSource: "icons/terminal.svg"
            variant: "secondary"
            onClicked: ocloud.launchRcloneConfig()
          }
        }
      }
    }
  }
}
