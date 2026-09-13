import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  Layout.fillWidth: true
  implicitWidth: parent ? parent.width : 400

  property string title: ""
  property string subtitle: ""
  default property alias content: actionRow.data

  readonly property bool isNarrow: width < 600

  implicitHeight: gridLayout.implicitHeight

  GridLayout {
    id: gridLayout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    columns: root.isNarrow ? 1 : 2
    rowSpacing: 8
    columnSpacing: 16

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
      spacing: 2

      Text {
        text: root.title
        font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
        font.pixelSize: root.isNarrow ? 15 : 17
        font.bold: true
        color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
        Layout.fillWidth: true
      }

      Text {
        visible: root.subtitle !== ""
        text: root.subtitle
        font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
        font.pixelSize: root.isNarrow ? 10 : 11
        color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    RowLayout {
      id: actionRow
      spacing: 8
      Layout.alignment: root.isNarrow ? (Qt.AlignLeft | Qt.AlignVCenter) : (Qt.AlignRight | Qt.AlignVCenter)
    }
  }
}
