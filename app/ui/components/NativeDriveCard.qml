import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root
  Layout.fillWidth: true
  radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 8
  color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#24283b"
  border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868"
  border.width: 1

  property string driveName: "Drive"
  property string driveType: "Local"
  property string iconSource: "icons/hard-drive.svg"
  property string mountPath: ""
  property string capacityText: ""
  property real usedPercent: -1 // 0.0 to 1.0, or -1 if unknown
  property string statusVariant: "success"
  property string statusText: "Mounted"
  property bool isConnected: true
  property bool isMounted: true
  property bool autoMount: false
  property bool showAutoMount: false
  property bool showDisconnect: false
  property bool showSettings: true

  signal openClicked()
  signal unmountClicked()
  signal settingsClicked()
  signal connectClicked()
  signal mountClicked()
  signal disconnectClicked()
  signal autoMountToggled(bool enabled)

  readonly property bool isNarrow: width < 480

  implicitHeight: cardContent.implicitHeight + 24

  ColumnLayout {
    id: cardContent
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: root.isNarrow ? 10 : 14
    spacing: root.isNarrow ? 8 : 12

    // Top Row: Icon + Info + Capacity
    RowLayout {
      Layout.fillWidth: true
      spacing: root.isNarrow ? 10 : 12

      // Drive Icon Container
      Rectangle {
        Layout.preferredWidth: root.isNarrow ? 36 : 44
        Layout.preferredHeight: root.isNarrow ? 36 : 44
        radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
        color: (typeof theme !== "undefined" && theme.cardBgAlt) ? theme.cardBgAlt : "#13141c"
        border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868"

        Image {
          anchors.centerIn: parent
          width: root.isNarrow ? 22 : 28
          height: root.isNarrow ? 22 : 28
          source: {
            if (!root.iconSource) return Qt.resolvedUrl("../icons/cloud.svg");
            if (root.iconSource.indexOf("data:") === 0) return root.iconSource;
            if (root.iconSource.indexOf("<svg") === 0) {
              return "data:image/svg+xml;utf8," + encodeURIComponent(root.iconSource);
            }
            if (root.iconSource.indexOf("icons/") === 0) return Qt.resolvedUrl("../" + root.iconSource);
            if (root.iconSource.indexOf(":") >= 0) return root.iconSource;
            return Qt.resolvedUrl(root.iconSource);
          }
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
      }

      // Drive Details
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          spacing: 6
          Layout.fillWidth: true

          Text {
            text: root.driveName
            font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
            font.pixelSize: root.isNarrow ? 13 : 14
            font.bold: true
            color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
            elide: Text.ElideRight
            Layout.maximumWidth: root.isNarrow ? 140 : 260
          }

          AppBadge {
            variant: root.statusVariant
            text: root.statusText
          }

          AppBadge {
            visible: root.showAutoMount && root.autoMount
            variant: "info"
            text: "Auto-Mount"
          }
        }

        Text {
          text: root.mountPath ? ("Mount: " + root.mountPath) : root.driveType
          font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
          font.pixelSize: 10
          color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        // In narrow mode, capacity displays directly under the path
        Text {
          visible: root.isNarrow
          text: root.capacityText || (root.isMounted ? "Active Volume" : "Ready to Mount")
          font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
          font.pixelSize: 10
          font.bold: true
          color: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
        }
      }

      // Capacity Info (Visible on wide / half screens)
      ColumnLayout {
        visible: !root.isNarrow
        spacing: 2
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        Text {
          text: root.capacityText || (root.isMounted ? "Active Volume" : (root.isConnected ? "Ready to Mount" : "Not Linked"))
          font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
          font.pixelSize: 12
          font.bold: true
          color: root.isMounted ? ((typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5") : ((typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89")
          horizontalAlignment: Text.AlignRight
          Layout.alignment: Qt.AlignRight
        }

        Text {
          text: root.usedPercent >= 0 ? (Math.round(root.usedPercent * 100) + "% used") : ""
          visible: root.usedPercent >= 0
          font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
          font.pixelSize: 10
          color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
          horizontalAlignment: Text.AlignRight
          Layout.alignment: Qt.AlignRight
        }
      }
    }

    // Capacity Gauge Bar
    Rectangle {
      Layout.fillWidth: true
      height: 4
      radius: 2
      color: (typeof theme !== "undefined" && theme.cardBgAlt) ? theme.cardBgAlt : "#13141c"
      visible: root.isMounted && root.usedPercent >= 0

      Rectangle {
        height: parent.height
        radius: 2
        width: Math.max(4, parent.width * Math.min(1.0, Math.max(0.0, root.usedPercent)))
        color: root.usedPercent > 0.9 ? ((typeof theme !== "undefined" && theme.dangerRed) ? theme.dangerRed : "#f7768e") : ((typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7")
      }
    }

    // Actions Footer: Flow wrapping handles 1/4 layout perfectly!
    Flow {
      Layout.fillWidth: true
      spacing: 6
      layoutDirection: root.isNarrow ? Qt.LeftToRight : Qt.RightToLeft

      // Settings
      AppButton {
        visible: root.showSettings
        text: root.isNarrow ? "Settings" : "Storage Settings..."
        variant: "secondary"
        onClicked: root.settingsClicked()
      }

      // Unmount
      AppButton {
        visible: root.isMounted && root.mountPath !== "/" && root.driveType.indexOf("Internal") < 0
        text: "Unmount"
        iconSource: "icons/eject.svg"
        variant: "danger"
        onClicked: root.unmountClicked()
      }

      // Open Folder
      AppButton {
        visible: root.isMounted && !!root.mountPath
        text: "Open Folder"
        iconSource: "icons/external-link.svg"
        variant: "secondary"
        onClicked: root.openClicked()
      }

      // Auto-mount Toggle
      AppButton {
        visible: root.showAutoMount && root.isConnected
        text: root.autoMount ? (root.isNarrow ? "Auto: ON" : "Auto-Mount: ON") : (root.isNarrow ? "Auto: OFF" : "Auto-Mount: OFF")
        variant: root.autoMount ? "primary" : "secondary"
        onClicked: root.autoMountToggled(!root.autoMount)
      }

      // Mount Drive
      AppButton {
        visible: root.isConnected && !root.isMounted
        text: "Mount Drive"
        iconSource: "icons/hard-drive.svg"
        variant: "success"
        onClicked: root.mountClicked()
      }

      // Disconnect
      AppButton {
        visible: !root.isMounted && root.showDisconnect
        text: "Disconnect"
        variant: "secondary"
        onClicked: root.disconnectClicked()
      }

      // Connect
      AppButton {
        visible: !root.isConnected
        text: "Connect Account"
        iconSource: "icons/plus.svg"
        variant: "primary"
        onClicked: root.connectClicked()
      }
    }
  }
}
