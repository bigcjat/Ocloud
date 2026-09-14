import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
  id: root
  Layout.fillWidth: true
  radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.min(theme.cornerRadius, 4) : 4
  color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
  border.color: cardMouse.containsMouse
    ? ((typeof theme !== "undefined" && theme.borderActive) ? theme.borderActive : theme.borderSubtle)
    : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "transparent")
  border.width: 1

  property string accountName: "Cloud Account"
  property string accountType: "Personal Cloud"
  property string iconSource: "icons/cloud.svg"
  property string userDetail: "Signed In"
  property string authMethod: "OAuth 2.0"
  property bool isConnected: true
  property string mountPath: ""

  signal connectClicked()
  signal disconnectClicked()
  signal openClicked()

  readonly property bool isNarrow: width < 420
  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#ffffff"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#888888"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color dotColor: root.isConnected
    ? ((typeof theme !== "undefined" && theme.green) ? theme.green : accentColor)
    : ((typeof theme !== "undefined" && theme.muted) ? theme.muted : "#555555")

  implicitHeight: cardContent.implicitHeight + 16

  MouseArea {
    id: cardMouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }

  RowLayout {
    id: cardContent
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 12
    spacing: 12

    // Status Dot (Flea-style 6px indicator)
    Rectangle {
      Layout.preferredWidth: 6
      Layout.preferredHeight: 6
      Layout.alignment: Qt.AlignVCenter
      color: root.dotColor
    }

    // Theme-Reactive Monochrome Brand Icon
    Item {
      Layout.preferredWidth: 22
      Layout.preferredHeight: 22
      Layout.alignment: Qt.AlignVCenter

      Image {
        id: rawIcon
        anchors.fill: parent
        source: {
          if (root.iconSource.indexOf(":") >= 0) return root.iconSource;
          if (root.iconSource.indexOf("icons/") === 0) return Qt.resolvedUrl("../" + root.iconSource);
          return Qt.resolvedUrl(root.iconSource);
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
      }

      MultiEffect {
        anchors.fill: parent
        source: rawIcon
        colorization: 1.0
        colorizationColor: cardMouse.containsMouse ? root.accentColor : root.textColor
      }
    }

    // Account Name and Path (Zero badges, pure typography)
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      Text {
        text: root.accountName
        font.family: root.appFontFamily
        font.pixelSize: 13
        font.bold: true
        color: root.textColor
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        text: root.userDetail || root.accountType
        font.family: root.appFontFamily
        font.pixelSize: 10
        color: root.mutedColor
        elide: Text.ElideRight
        Layout.fillWidth: true
      }
    }

    // Restrained Desktop Action Buttons (Theme Colors)
    RowLayout {
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
      spacing: 6

      // Open in File Manager button (if connected)
      Rectangle {
        visible: root.isConnected
        implicitWidth: openText.implicitWidth + 14
        implicitHeight: 24
        radius: 2
        color: openMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
          : "transparent"
        border.color: openMouse.containsMouse ? root.accentColor : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333")
        border.width: 1

        Text {
          id: openText
          anchors.centerIn: parent
          text: "Open"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: openMouse.containsMouse ? root.accentColor : root.textColor
        }

        MouseArea {
          id: openMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.mountPath && root.mountPath.length > 0) {
              ocloud.openCloudFolder(root.mountPath);
            } else {
              ocloud.openCloudFolder(root.accountName);
            }
          }
        }
      }

      // Disconnect button
      Rectangle {
        visible: root.isConnected
        implicitWidth: discText.implicitWidth + 14
        implicitHeight: 24
        radius: 2
        color: discMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
          : "transparent"
        border.color: discMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
          : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333")
        border.width: 1

        Text {
          id: discText
          anchors.centerIn: parent
          text: "Disconnect"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: discMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
            : root.mutedColor
        }

        MouseArea {
          id: discMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.disconnectClicked()
        }
      }

      // Connect button (when not connected)
      Rectangle {
        visible: !root.isConnected
        implicitWidth: connText.implicitWidth + 14
        implicitHeight: 24
        radius: 2
        color: connMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
          : "transparent"
        border.color: connMouse.containsMouse ? root.accentColor : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333")
        border.width: 1

        Text {
          id: connText
          anchors.centerIn: parent
          text: "+ Connect"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: connMouse.containsMouse ? root.accentColor : root.textColor
        }

        MouseArea {
          id: connMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.connectClicked()
        }
      }
    }
  }
}
