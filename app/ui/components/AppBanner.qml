import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root
  Layout.fillWidth: true
  radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 8

  // Variants: "info", "warning", "success"
  property string variant: "info"
  property string iconSource: "icons/shield.svg"
  property string title: ""
  property string message: ""
  default property alias content: rightAction.data

  readonly property color successCol: (typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : "#9ece6a"
  readonly property color infoCol: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color warningCol: (typeof theme !== "undefined" && theme.warningAmber) ? theme.warningAmber : "#e0af68"

  readonly property color activeColor: {
    if (variant === "warning") return warningCol;
    if (variant === "success") return successCol;
    return infoCol;
  }

  color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.12)
  border.color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.4)
  border.width: 1

  implicitHeight: isNarrow ? (bannerCol.implicitHeight + 24) : Math.max(bannerRow.implicitHeight + 24, 60)
  readonly property bool isNarrow: width < 480

  // Standard Wide / Half Layout
  RowLayout {
    id: bannerRow
    visible: !root.isNarrow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 14
    anchors.rightMargin: 14
    spacing: 12

    Rectangle {
      Layout.preferredWidth: 32
      Layout.preferredHeight: 32
      Layout.alignment: Qt.AlignVCenter
      radius: 6
      color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.22)
      border.color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.6)

      Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: root.iconSource ? (root.iconSource.indexOf("/") !== -1 && !root.iconSource.startsWith("../") && !root.iconSource.startsWith("/") && !root.iconSource.startsWith("file:") ? Qt.resolvedUrl("../" + root.iconSource) : Qt.resolvedUrl(root.iconSource)) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 2

      Text {
        visible: root.title !== ""
        text: root.title
        font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
        font.pixelSize: 12
        font.bold: true
        color: root.activeColor
      }

      Text {
        text: root.message
        font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
        font.pixelSize: 11
        color: (typeof theme !== "undefined" && theme.textSecondary) ? theme.textSecondary : "#a9b1d6"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    RowLayout {
      id: rightAction
      Layout.alignment: Qt.AlignVCenter
      Layout.fillWidth: false
      spacing: 8
    }
  }

  // Quarter / Narrow Layout
  ColumnLayout {
    id: bannerCol
    visible: root.isNarrow
    anchors.fill: parent
    anchors.margins: 12
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26
        radius: 5
        color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.22)

        Image {
          anchors.centerIn: parent
          width: 14
          height: 14
          source: root.iconSource ? (root.iconSource.indexOf("/") !== -1 && !root.iconSource.startsWith("../") && !root.iconSource.startsWith("/") && !root.iconSource.startsWith("file:") ? Qt.resolvedUrl("../" + root.iconSource) : Qt.resolvedUrl(root.iconSource)) : ""
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
      }

      Text {
        visible: root.title !== ""
        text: root.title
        font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
        font.pixelSize: 11
        font.bold: true
        color: root.activeColor
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
    }

    Text {
      text: root.message
      font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
      font.pixelSize: 10
      color: (typeof theme !== "undefined" && theme.textSecondary) ? theme.textSecondary : "#a9b1d6"
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }
  }
}
