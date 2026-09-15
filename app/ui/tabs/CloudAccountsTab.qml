import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  property var cloudAccounts: []
  property var storagePlugins: []

  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#ffffff"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#888888"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color borderCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333"

  function reloadPlugins() {
    try {
      var raw = ocloud.fetchStoragePlugins(true);
      if (raw && raw.length > 2) {
        storagePlugins = JSON.parse(raw);
      }
    } catch (e) {
      storagePlugins = [];
    }
  }

  Connections {
    target: ocloud
    function onStoragePluginsUpdated(json) {
      if (json && json.length > 2) {
        try {
          storagePlugins = JSON.parse(json);
        } catch(e) {}
      }
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
    if (typeof reloadComputeServers === "function") {
      reloadComputeServers();
    } else {
      ocloud.listComputeServers();
    }
  }

  Component.onCompleted: {
    reloadAccounts();
  }

  onVisibleChanged: {
    if (visible) {
      reloadAccounts();
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
    function onActionCompleted(action, success, msg) {
      if (action && (action.indexOf("mount") >= 0 || action.indexOf("disconnect") >= 0 || action.indexOf("server") >= 0)) {
        root.reloadAccounts();
      }
    }
  }

  readonly property var activeAccounts: cloudAccounts.filter(function(a) { return a.type !== "smb"; })

  ScrollView {
    anchors.fill: parent
    anchors.margins: 16
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 16

      // =========================================================
      // 1. COMPUTE FLEET SECTION
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          spacing: 2

          Text {
            text: "COMPUTE FLEET"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            color: root.mutedColor
          }

          Text {
            text: (serverList && serverList.length === 1) ? "1 active node" : ((serverList ? serverList.length : 0) + " active nodes")
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        Item { Layout.fillWidth: true }

        // Procure VM Button
        Rectangle {
          implicitWidth: procText.implicitWidth + 16
          implicitHeight: 28
          radius: 2
          color: procMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: procMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          Text {
            id: procText
            anchors.centerIn: parent
            text: "+ Procure VM"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            color: procMouse.containsMouse ? root.accentColor : root.textColor
          }

          MouseArea {
            id: procMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: procureModal.openModal()
          }
        }

        // Add Node Button (Theme Accent button)
        Rectangle {
          implicitWidth: addNodeText.implicitWidth + 18
          implicitHeight: 28
          radius: 2
          color: addNodeMouse.containsMouse
            ? Qt.darker(root.accentColor, 1.2)
            : root.accentColor

          Text {
            id: addNodeText
            anchors.centerIn: parent
            text: "+ Add Node"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
          }

          MouseArea {
            id: addNodeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: addNodeModal.openModal()
          }
        }
      }

      // Thin separator hairline
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.borderCol
      }

      // Compute Fleet Cards (Responsive 2-column Grid)
      GridLayout {
        Layout.fillWidth: true
        columns: root.width > 800 ? 2 : 1
        columnSpacing: 10
        rowSpacing: 8
        visible: serverList && serverList.length > 0

        Repeater {
          model: serverList

          delegate: Rectangle {
            id: serverItem
            Layout.fillWidth: true
            implicitHeight: 52
            radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.min(theme.cornerRadius, 4) : 4
            color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
            border.color: itemMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.borderActive) ? theme.borderActive : root.accentColor)
              : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : root.borderCol)
            border.width: 1

            MouseArea {
              id: itemMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 10
              spacing: 10

              // 6px Flea Status Dot
              Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                Layout.alignment: Qt.AlignVCenter
                color: modelData.status === "running"
                  ? ((typeof theme !== "undefined" && theme.green) ? theme.green : root.accentColor)
                  : (modelData.status === "starting" ? ((typeof theme !== "undefined" && theme.yellow) ? theme.yellow : "#e0af68") : root.mutedColor)
              }

              // Brand / Node Vector Icon
              ThemeIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                source: modelData.isHomeWorkstation ? "icons/device-workstation.svg" : ((modelData.providerIcon && modelData.providerIcon.length > 0) ? modelData.providerIcon : "icons/server.svg")
                color: itemMouse.containsMouse ? root.accentColor : root.textColor
              }

              // Node Name & Details
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                  spacing: 6
                  Text {
                    text: modelData.name
                    font.family: root.appFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: root.textColor
                    elide: Text.ElideRight
                  }

                  Text {
                    text: "· " + (modelData.status === "running" ? "online" : modelData.status)
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    color: modelData.status === "running"
                      ? ((typeof theme !== "undefined" && theme.green) ? theme.green : root.accentColor)
                      : root.mutedColor
                  }
                }

                Text {
                  text: (modelData.ipv4 || "No IP") + " · Tailscale: " + (modelData.tailscale_ip || modelData.tailscaleIp || "none") + " · " + (modelData.provider || "cloud").toUpperCase()
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              // Action Toolbar
              RowLayout {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                spacing: 4

                // SSH Button
                Rectangle {
                  implicitWidth: sshText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: sshMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: sshMouse.containsMouse ? root.accentColor : root.borderCol
                  border.width: 1

                  Text {
                    id: sshText
                    anchors.centerIn: parent
                    text: "SSH"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: sshMouse.containsMouse ? root.accentColor : root.textColor
                  }

                  MouseArea {
                    id: sshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ocloud.openTerminal(modelData.name, modelData.tailscale_ip || modelData.ipv4, modelData.user || "root")
                  }
                }

                // Mount/Unmount Button
                Rectangle {
                  visible: modelData.status === "running"
                  implicitWidth: mntText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: mntMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: mntMouse.containsMouse ? root.accentColor : root.borderCol
                  border.width: 1

                  Text {
                    id: mntText
                    anchors.centerIn: parent
                    text: modelData.is_drive_mounted ? "Unmount" : "Mount"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: mntMouse.containsMouse ? root.accentColor : root.textColor
                  }

                  MouseArea {
                    id: mntMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.is_drive_mounted) {
                        ocloud.unmountEphemeralVm();
                      } else {
                        consentModal.openForServer(modelData.name, String(modelData.id));
                      }
                    }
                  }
                }

                // Top / Activity Button
                Rectangle {
                  implicitWidth: topText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: topMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: topMouse.containsMouse ? root.accentColor : root.borderCol
                  border.width: 1

                  Text {
                    id: topText
                    anchors.centerIn: parent
                    text: "Top"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: topMouse.containsMouse ? root.accentColor : root.textColor
                  }

                  MouseArea {
                    id: topMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: taskManagerModal.openForServer(modelData)
                  }
                }

                // Power Button (Off/On)
                Rectangle {
                  enabled: modelData.status !== "starting" && modelData.status !== "stopping"
                  implicitWidth: pwrText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: pwrMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: pwrMouse.containsMouse ? root.accentColor : root.borderCol
                  border.width: 1

                  Text {
                    id: pwrText
                    anchors.centerIn: parent
                    text: modelData.status === "running" ? "Off" : "On"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: pwrMouse.containsMouse ? root.accentColor : root.mutedColor
                  }

                  MouseArea {
                    id: pwrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var act = modelData.status === "running" ? "stop" : "start";
                      ocloud.serverAction(act, String(modelData.id));
                    }
                  }
                }

                // Delete Button
                Rectangle {
                  implicitWidth: delText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: delMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: delMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                    : root.borderCol
                  border.width: 1

                  Text {
                    id: delText
                    anchors.centerIn: parent
                    text: "Delete"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: delMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                      : root.mutedColor
                  }

                  MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.provider === "custom") {
                        ocloud.removeNode(String(modelData.id));
                      } else {
                        ocloud.serverAction("delete", String(modelData.id));
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // Empty State for Compute Fleet
      Rectangle {
        visible: !serverList || serverList.length === 0
        Layout.fillWidth: true
        implicitHeight: 90
        radius: 4
        color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No Compute Nodes in Fleet"
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Click \"+ Procure VM\" or \"+ Add Node\" above to provision cloud machines."
            font.family: root.appFontFamily
            font.pixelSize: 11
            color: root.mutedColor
          }
        }
      }

      Item {
        Layout.preferredHeight: 8
      }

      // =========================================================
      // 2. CLOUD & LOCAL STORAGE SECTION
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          spacing: 2

          Text {
            text: "STORAGE & DRIVES"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            color: root.mutedColor
          }

          Text {
            text: (1 + root.activeAccounts.length) === 1 ? "1 storage volume connected" : ((1 + root.activeAccounts.length) + " storage volumes connected")
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        Item { Layout.fillWidth: true }

        // Refresh Action
        Rectangle {
          implicitWidth: refreshText.implicitWidth + 16
          implicitHeight: 28
          radius: 2
          color: refMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: refMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          Text {
            id: refreshText
            anchors.centerIn: parent
            text: "Refresh"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            color: refMouse.containsMouse ? root.accentColor : root.textColor
          }

          MouseArea {
            id: refMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.reloadAccounts()
          }
        }

        // Add Storage Action (Theme-accented button)
        Rectangle {
          implicitWidth: addText.implicitWidth + 20
          implicitHeight: 28
          radius: 2
          color: addMouse.containsMouse
            ? Qt.darker(root.accentColor, 1.2)
            : root.accentColor

          Text {
            id: addText
            anchors.centerIn: parent
            text: "+ Add Storage"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
          }

          MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: addStorageModal.openModal()
          }
        }
      }

      // Thin separator hairline
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.borderCol
      }

      // Storage Drives Grid (Local storage + Connected Cloud Accounts)
      GridLayout {
        Layout.fillWidth: true
        columns: root.width > 800 ? 2 : 1
        columnSpacing: 10
        rowSpacing: 8

        // Local Storage System Volume Card
        AccountCard {
          Layout.fillWidth: true
          accountName: "System Volume"
          accountType: "Internal NVMe Storage"
          iconSource: "icons/hard-drive.svg"
          userDetail: "/ · Primary Host Storage"
          authMethod: ""
          isConnected: true
          mountPath: "/"
          onOpenClicked: ocloud.openCloudFolder("/")
        }

        // Connected Cloud Drive Cards
        Repeater {
          model: root.activeAccounts

          delegate: AccountCard {
            Layout.fillWidth: true
            accountName: modelData.providerName || modelData.name
            accountType: (modelData.type === "drive" || modelData.type === "onedrive" || modelData.type === "dropbox") ? "Personal Cloud" : "Object Storage"
            iconSource: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : (modelData.iconSvg || "icons/cloud.svg")
            userDetail: (modelData.mountPath ? modelData.mountPath : "") + (modelData.accountDetail ? (" · " + modelData.accountDetail) : "")
            authMethod: ""
            isConnected: true
            mountPath: modelData.mountPath || ""
            onDisconnectClicked: {
              if (modelData.name) {
                ocloud.disconnectCloudAccount(modelData.name);
              }
            }
          }
        }
      }

      Item {
        Layout.preferredHeight: 8
      }

      // =========================================================
      // ADVANCED CLI CARD (100% Theme Colors)
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: rcloneRow.implicitHeight + 20
        radius: 4
        color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
        border.color: root.borderCol
        border.width: 1

        RowLayout {
          id: rcloneRow
          anchors.fill: parent
          anchors.margins: 12
          spacing: 12

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: "Rclone Advanced Storage CLI"
              font.family: root.appFontFamily
              font.pixelSize: 12
              font.bold: true
              color: root.textColor
            }

            Text {
              text: "Manage raw remotes, encryption filters, and chunking directly"
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: root.mutedColor
            }
          }

          Rectangle {
            implicitWidth: rcText.implicitWidth + 14
            implicitHeight: 24
            radius: 2
            color: rcMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
              : "transparent"
            border.color: rcMouse.containsMouse ? root.accentColor : root.borderCol
            border.width: 1

            Text {
              id: rcText
              anchors.centerIn: parent
              text: "Launch CLI"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: rcMouse.containsMouse ? root.accentColor : root.textColor
            }

            MouseArea {
              id: rcMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: ocloud.launchRcloneConfig()
            }
          }
        }
      }
    }
  }
}
