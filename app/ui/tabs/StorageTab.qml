import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  property var rootCapacities: ({})
  property var cloudAccounts: []
  property var mountedShares: []

  function refreshCapacities() {
    try {
      var raw = ocloud.getDriveCapacities();
      rootCapacities = JSON.parse(raw || "{}");
    } catch (e) {}
  }

  function reloadCloudAccounts() {
    try {
      cloudAccounts = JSON.parse(ocloud.fetchCloudAccounts() || "[]");
    } catch (e) {
      cloudAccounts = [];
    }
  }

  function reloadMountedShares() {
    try {
      mountedShares = JSON.parse(ocloud.getNetworkShares() || "[]");
    } catch (e) {
      mountedShares = [];
    }
  }

  Component.onCompleted: {
    refreshCapacities();
    reloadCloudAccounts();
    reloadMountedShares();
  }

  onVisibleChanged: {
    if (visible) {
      root.refreshCapacities();
      root.reloadCloudAccounts();
      root.reloadMountedShares();
    }
  }

  Connections {
    target: ocloud
    function onCloudAccountsUpdated(jsonStr) {
      try {
        root.cloudAccounts = JSON.parse(jsonStr);
      } catch(e) {
        root.cloudAccounts = [];
      }
    }
    function onNetworkSharesUpdated(jsonStr) {
      try {
        root.mountedShares = JSON.parse(jsonStr);
      } catch(e) {
        root.mountedShares = [];
      }
    }
  }

  function getRemoteByName(nameStr) {
    for (var i = 0; i < cloudAccounts.length; i++) {
      if (cloudAccounts[i].name === nameStr || cloudAccounts[i].type === nameStr) {
        return cloudAccounts[i];
      }
    }
    return null;
  }

  ScrollView {
    id: storageScroll
    anchors.fill: parent
    anchors.margins: root.isNarrow ? 12 : 20
    contentWidth: availableWidth
    clip: true

    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
      contentItem: Rectangle {
        implicitWidth: 6
        radius: 3
        color: parent.pressed ? "#60a5fa" : parent.hovered ? "#3b82f6" : "#334155"
      }
    }

    ColumnLayout {
      width: parent.width
      spacing: 20

      // Section Header
      AppHeader {
        title: "Storage & Drives"
        subtitle: "Overview of all active connected disks, mounted cloud drives, and network shares"

        RowLayout {
          spacing: 10

          AppButton {
            text: "Add Cloud Storage"
            iconSource: "icons/plus.svg"
            variant: "primary"
            onClicked: activeTab = "accounts"
          }

          AppButton {
            text: "Refresh Disks"
            iconSource: "icons/refresh.svg"
            variant: "secondary"
            onClicked: {
              root.refreshCapacities();
              root.reloadCloudAccounts();
              root.reloadMountedShares();
              ocloud.listComputeServers();
            }
          }
        }
      }

      // =========================================================
      // 1. LOCAL SYSTEM STORAGE DISK
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
          text: "INTERNAL STORAGE DISK"
          font.pixelSize: 11
          font.bold: true
          color: "#94a3b8"
        }

        NativeDriveCard {
          driveName: "Omarchy System HD"
          driveType: "Internal NVMe Storage (/)"
          iconSource: "icons/hard-drive.svg"
          mountPath: "/"
          capacityText: {
            var rootData = rootCapacities["/"];
            if (rootData && rootData.free && rootData.total) {
              var freeGb = (rootData.free / (1024*1024*1024)).toFixed(2);
              var totalGb = (rootData.total / (1024*1024*1024)).toFixed(2);
              return freeGb + " GB available of " + totalGb + " GB";
            }
            return "Local Storage Volume";
          }
          usedPercent: {
            var rootData = rootCapacities["/"];
            if (rootData && rootData.used_percent) {
              return rootData.used_percent / 100.0;
            }
            return 0.35;
          }
          isMounted: true
          statusVariant: "success"
          statusText: "System Volume"
          showDisconnect: false
          showSettings: false
          onOpenClicked: ocloud.openCloudFolder("/")
        }
      }

      // =========================================================
      // 2. CONNECTED CLOUD DRIVES
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
          text: "CONNECTED CLOUD DRIVES"
          font.pixelSize: 11
          font.bold: true
          color: "#94a3b8"
        }

        // Hetzner Storage Box Drive
        NativeDriveCard {
          id: hetznerCard
          property var sbRemote: {
            var list = root.cloudAccounts;
            for (var i = 0; i < list.length; i++) {
              if (list[i].name === "storagebox" || list[i].type === "storagebox" || list[i].providerId === "hetzner_storage_box") {
                return list[i];
              }
            }
            return null;
          }
          driveName: "Hetzner Storage Box"
          driveType: "Persistent Cloud RAID Storage"
          iconSource: (sbRemote && sbRemote.iconDataUri && sbRemote.iconDataUri.length > 0) ? sbRemote.iconDataUri : (storageBox.iconDataUri || "icons/cloud.svg")
          mountPath: storageBox.mount_point || "~/Cloud"
          capacityText: storageBox.configured ? (Math.round((storageBox.used_bytes || 0) / (1024*1024*1024)) + " GB / " + Math.round((storageBox.total_bytes || 1073741824000) / (1024*1024*1024)) + " GB") : "1000 GB RAID"
          usedPercent: storageBox.used_percent ? (storageBox.used_percent / 100.0) : 0.01
          isMounted: storageBox.mounted || (sbRemote && sbRemote.isMounted)
          autoMount: !!(sbRemote && sbRemote.autoMount)
          showAutoMount: true
          statusVariant: (storageBox.mounted || (sbRemote && sbRemote.isMounted)) ? "success" : "neutral"
          statusText: (storageBox.mounted || (sbRemote && sbRemote.isMounted)) ? "Mounted" : "Offline"
          showDisconnect: false
          showSettings: false
          onOpenClicked: ocloud.openCloudFolder(storageBox.mount_point || "~/Cloud")
          onUnmountClicked: ocloud.unmountStorageBox()
          onMountClicked: ocloud.mountStorageBox()
          onAutoMountToggled: ocloud.toggleAutoMount("storagebox")
        }

        // Google Drive
        NativeDriveCard {
          id: gdriveDriveCard
          property var remote: { var l = root.cloudAccounts; return getRemoteByName("gdrive"); }
          visible: !!remote
          driveName: "Google Drive"
          driveType: "Virtual Cloud Drive (FUSE)"
          iconSource: (remote && remote.iconDataUri && remote.iconDataUri.length > 0) ? remote.iconDataUri : "icons/cloud.svg"
          mountPath: remote ? remote.mountPath : "~/GoogleDrive"
          capacityText: remote && remote.isMounted ? "Online & Synced" : "Ready to Mount"
          isMounted: !!remote && remote.isMounted
          autoMount: !!(remote && remote.autoMount)
          showAutoMount: !!remote
          statusVariant: remote && remote.isMounted ? "success" : "neutral"
          statusText: remote && remote.isMounted ? "Mounted" : "Not Mounted"
          showDisconnect: false
          showSettings: false
          onOpenClicked: if (remote) ocloud.openCloudFolder(remote.mountPath)
          onUnmountClicked: if (remote) ocloud.unmountCloudAccount(remote.mountPath)
          onMountClicked: if (remote) ocloud.mountCloudAccount(remote.name, remote.mountPath)
          onAutoMountToggled: if (remote) ocloud.toggleAutoMount(remote.name)
        }

        // Microsoft OneDrive
        NativeDriveCard {
          id: onedriveDriveCard
          property var remote: { var l = root.cloudAccounts; return getRemoteByName("onedrive"); }
          visible: !!remote
          driveName: "Microsoft OneDrive"
          driveType: "Virtual Cloud Drive (FUSE)"
          iconSource: (remote && remote.iconDataUri && remote.iconDataUri.length > 0) ? remote.iconDataUri : "icons/cloud.svg"
          mountPath: remote ? remote.mountPath : "~/OneDrive"
          capacityText: remote && remote.isMounted ? "Online & Synced" : "Ready to Mount"
          isMounted: !!remote && remote.isMounted
          autoMount: !!(remote && remote.autoMount)
          showAutoMount: !!remote
          statusVariant: remote && remote.isMounted ? "success" : "neutral"
          statusText: remote && remote.isMounted ? "Mounted" : "Not Mounted"
          showDisconnect: false
          showSettings: false
          onOpenClicked: if (remote) ocloud.openCloudFolder(remote.mountPath)
          onUnmountClicked: if (remote) ocloud.unmountCloudAccount(remote.mountPath)
          onMountClicked: if (remote) ocloud.mountCloudAccount(remote.name, remote.mountPath)
          onAutoMountToggled: if (remote) ocloud.toggleAutoMount(remote.name)
        }

        // Dropbox
        NativeDriveCard {
          id: dropboxDriveCard
          property var remote: { var l = root.cloudAccounts; return getRemoteByName("dropbox"); }
          visible: !!remote
          driveName: "Dropbox"
          driveType: "Virtual Cloud Drive (FUSE)"
          iconSource: (remote && remote.iconDataUri && remote.iconDataUri.length > 0) ? remote.iconDataUri : "icons/cloud.svg"
          mountPath: remote ? remote.mountPath : "~/Dropbox"
          capacityText: remote && remote.isMounted ? "Online & Synced" : "Ready to Mount"
          isMounted: !!remote && remote.isMounted
          autoMount: !!(remote && remote.autoMount)
          showAutoMount: !!remote
          statusVariant: remote && remote.isMounted ? "success" : "neutral"
          statusText: remote && remote.isMounted ? "Mounted" : "Not Mounted"
          showDisconnect: false
          showSettings: false
          onOpenClicked: if (remote) ocloud.openCloudFolder(remote.mountPath)
          onUnmountClicked: if (remote) ocloud.unmountCloudAccount(remote.mountPath)
          onMountClicked: if (remote) ocloud.mountCloudAccount(remote.name, remote.mountPath)
          onAutoMountToggled: if (remote) ocloud.toggleAutoMount(remote.name)
        }

        // Cloudflare R2
        NativeDriveCard {
          id: r2DriveCard
          property var remote: getRemoteByName("r2-ocloud") || getRemoteByName("r2")
          visible: (r2Storage && !!r2Storage.configured) || !!remote
          driveName: "Cloudflare R2"
          driveType: "Object Storage Drive"
          iconSource: (remote && remote.iconDataUri && remote.iconDataUri.length > 0) ? remote.iconDataUri : "icons/cloud.svg"
          mountPath: "~/R2"
          capacityText: "Active S3 Bucket"
          isMounted: (r2Storage && r2Storage.mounted) || (remote && remote.isMounted)
          autoMount: !!(remote && remote.autoMount)
          showAutoMount: !!remote
          statusVariant: ((r2Storage && r2Storage.mounted) || (remote && remote.isMounted)) ? "success" : "neutral"
          statusText: ((r2Storage && r2Storage.mounted) || (remote && remote.isMounted)) ? "Mounted" : "Not Mounted"
          showDisconnect: false
          showSettings: false
          onOpenClicked: ocloud.openCloudFolder("~/R2")
          onUnmountClicked: ocloud.unmountCloudAccount("~/R2")
          onMountClicked: ocloud.mountCloudAccount(remote ? remote.name : "r2-ocloud", "~/R2")
          onAutoMountToggled: if (remote) ocloud.toggleAutoMount(remote.name)
        }

        // Custom S3 / SFTP Remotes
        Repeater {
          model: cloudAccounts.filter(function(a) {
            return a.type !== "drive" && a.type !== "onedrive" && a.type !== "dropbox" &&
                   a.type !== "storagebox" && a.name !== "storagebox" &&
                   a.name !== "r2-ocloud" && a.name !== "r2" && a.type !== "smb";
          })

          delegate: NativeDriveCard {
            driveName: modelData.providerName || modelData.name
            driveType: "Cloud Remote (" + (modelData.type || "S3").toUpperCase() + ")"
            iconSource: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : (modelData.iconSvg || "icons/cloud.svg")
            mountPath: modelData.mountPath
            capacityText: modelData.isMounted ? "Mounted Volume" : "Offline"
            isMounted: modelData.isMounted
            autoMount: !!modelData.autoMount
            showAutoMount: true
            statusVariant: modelData.isMounted ? "success" : "neutral"
            statusText: modelData.isMounted ? "Mounted" : "Not Mounted"
            showDisconnect: true
            showSettings: false
            onOpenClicked: ocloud.openCloudFolder(modelData.mountPath)
            onUnmountClicked: ocloud.unmountCloudAccount(modelData.mountPath)
            onMountClicked: ocloud.mountCloudAccount(modelData.name, modelData.mountPath)
            onDisconnectClicked: ocloud.disconnectCloudAccount(modelData.name)
            onAutoMountToggled: ocloud.toggleAutoMount(modelData.name)
          }
        }
      }

      // =========================================================
      // 3. CONNECTED NETWORK SHARES (SMB)
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
          text: "CONNECTED NETWORK SHARES (SMB / CIFS)"
          font.pixelSize: 11
          font.bold: true
          color: "#94a3b8"
        }

        // Mounted SMB Shares Repeater
        Repeater {
          model: mountedShares.filter(function(s) { return s.isMounted; })

          delegate: NativeDriveCard {
            driveName: modelData.name
            driveType: "Network Shared Folder"
            iconSource: "icons/network.svg"
            mountPath: modelData.mountPath
            capacityText: "Active Network Share"
            isMounted: true
            statusVariant: "success"
            statusText: "Mounted"
            showDisconnect: false
            showSettings: false
            onOpenClicked: ocloud.openCloudFolder(modelData.mountPath)
            onUnmountClicked: ocloud.unmountCloudAccount(modelData.mountPath)
          }
        }

        // Quick Link Card if no SMB shares are mounted
        AppCard {
          visible: mountedShares.filter(function(s) { return s.isMounted; }).length === 0
          implicitHeight: smbEmptyRow.implicitHeight + 24

          RowLayout {
            id: smbEmptyRow
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            Rectangle {
              Layout.preferredWidth: 36
              Layout.preferredHeight: 36
              radius: 8
              color: "#0b1329"
              border.color: "#1e293b"
              Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: Qt.resolvedUrl("../icons/network.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text {
                text: "No Network Shares Currently Mounted"
                font.pixelSize: 13
                font.bold: true
                color: "#e2e8f0"
              }
              Text {
                text: "Discover and mount shared folders from Macs, Windows PCs, or NAS servers on your local network"
                font.pixelSize: 11
                color: "#94a3b8"
              }
            }

            AppButton {
              text: "Browse Network Shares"
              iconSource: "icons/network.svg"
              variant: "secondary"
              onClicked: activeTab = "shares"
            }
          }
        }
      }

      // =========================================================
      // 4. EPHEMERAL COMPUTE STORAGE
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: serverList && serverList.some(function(s) { return s.is_drive_mounted; })

        Text {
          text: "EPHEMERAL COMPUTE STORAGE"
          font.pixelSize: 11
          font.bold: true
          color: "#ef4444"
        }

        Repeater {
          model: serverList.filter(function(s) { return s.is_drive_mounted; })

          delegate: NativeDriveCard {
            driveName: modelData.name + " (Ephemeral VM Drive)"
            driveType: "Temporary Compute NVMe Scratch"
            iconSource: "icons/server.svg"
            mountPath: "~/Cloud-" + modelData.name
            capacityText: "Data destroyed on reboot"
            isMounted: true
            statusVariant: "danger"
            statusText: "Ephemeral"
            showDisconnect: false
            showSettings: false
            onOpenClicked: ocloud.openCloudFolder("~/Cloud-" + modelData.name)
            onUnmountClicked: ocloud.unmountCloudAccount("~/Cloud-" + modelData.name)
          }
        }
      }

      // Bottom breathing room
      Item {
        Layout.preferredHeight: 40
        Layout.fillWidth: true
      }
    }
  }
}
