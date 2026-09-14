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
      // HEADER BAR
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "CONNECTED STORAGE"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1
            color: root.mutedColor
          }

          Text {
            text: root.activeAccounts.length === 1 ? "1 cloud drive mounted" : (root.activeAccounts.length + " cloud drives mounted")
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

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

      // =========================================================
      // CONNECTED ACCOUNTS LIST (ONLY CONNECTED SERVICES)
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.activeAccounts.length > 0

        Repeater {
          model: root.activeAccounts

          delegate: AccountCard {
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

      // =========================================================
      // EMPTY STATE (WHEN ZERO CONNECTED SERVICES)
      // =========================================================
      Rectangle {
        visible: root.activeAccounts.length === 0
        Layout.fillWidth: true
        implicitHeight: 120
        radius: 4
        color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 8

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No Cloud Storage Connected"
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Click \"+ Add Storage\" above to connect your personal cloud drives or S3 buckets."
            font.family: root.appFontFamily
            font.pixelSize: 11
            color: root.mutedColor
          }
        }
      }

      Item {
        Layout.preferredHeight: 12
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
