import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root
  Layout.fillWidth: true
  radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 8
  color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#24283b"
  border.color: isConnected ? ((typeof theme !== "undefined" && theme.accent) ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.4) : "#3b82f6") : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868")
  border.width: 1

  property string accountName: "Cloud Account"
  property string accountType: "Personal Cloud"
  property string iconSource: "icons/cloud.svg"
  property string userDetail: "Signed In"
  property string authMethod: "OAuth 2.0"
  property bool isConnected: true
  property string statusText: isConnected ? "Connected" : "Not Linked"
  property string statusVariant: isConnected ? "success" : "neutral"

  signal connectClicked()
  signal disconnectClicked()

  readonly property bool isNarrow: width < 480

  implicitHeight: cardContent.implicitHeight + (root.isNarrow ? 20 : 24)

  ColumnLayout {
    id: cardContent
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: root.isNarrow ? 10 : 14
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      spacing: root.isNarrow ? 10 : 12

      // Service Brand Icon Container
      Rectangle {
        Layout.preferredWidth: root.isNarrow ? 36 : 42
        Layout.preferredHeight: root.isNarrow ? 36 : 42
        radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
        color: (typeof theme !== "undefined" && theme.cardBgAlt) ? theme.cardBgAlt : "#13141c"
        border.color: root.isConnected ? ((typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7") : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868")
        border.width: 1

        Image {
          anchors.centerIn: parent
          width: root.isNarrow ? 22 : 26
          height: root.isNarrow ? 22 : 26
          source: {
            if (root.iconSource.indexOf(":") >= 0) return root.iconSource;
            if (root.iconSource.indexOf("icons/") === 0) return Qt.resolvedUrl("../" + root.iconSource);
            return Qt.resolvedUrl(root.iconSource);
          }
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
      }

      // Account Info
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          spacing: 6
          Layout.fillWidth: true

          Text {
            text: root.accountName
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
            visible: !root.isNarrow
            variant: "neutral"
            text: root.authMethod
          }
        }

        Text {
          text: root.userDetail || root.accountType
          font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
          font.pixelSize: 10
          color: root.isConnected ? ((typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7") : ((typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89")
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      // Wide layout: Action button pinned to the right
      RowLayout {
        visible: !root.isNarrow
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        spacing: 8

        AppButton {
          visible: !root.isConnected
          text: "+ Connect Account"
          variant: "primary"
          iconSource: "icons/plus.svg"
          onClicked: root.connectClicked()
        }

        AppButton {
          visible: root.isConnected
          text: "Disconnect"
          variant: "secondary"
          onClicked: root.disconnectClicked()
        }
      }
    }

    // Narrow/Quarter layout: Action button displayed below
    RowLayout {
      visible: root.isNarrow
      Layout.fillWidth: true
      spacing: 6

      Item { Layout.fillWidth: true }

      AppButton {
        visible: !root.isConnected
        text: "+ Connect"
        variant: "primary"
        iconSource: "icons/plus.svg"
        onClicked: root.connectClicked()
      }

      AppButton {
        visible: root.isConnected
        text: "Disconnect"
        variant: "secondary"
        onClicked: root.disconnectClicked()
      }
    }
  }
}
