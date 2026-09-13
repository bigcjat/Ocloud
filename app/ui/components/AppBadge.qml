import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root
  // Variants: "success", "info", "warning", "danger", "neutral"
  property string variant: "neutral"
  property string text: ""
  property bool showDot: true

  readonly property color successCol: (typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : "#9ece6a"
  readonly property color infoCol: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color warningCol: (typeof theme !== "undefined" && theme.warningAmber) ? theme.warningAmber : "#e0af68"
  readonly property color dangerCol: (typeof theme !== "undefined" && theme.dangerRed) ? theme.dangerRed : "#f7768e"
  readonly property color neutralCol: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"

  readonly property color activeColor: {
    if (variant === "success") return successCol;
    if (variant === "info") return infoCol;
    if (variant === "warning") return warningCol;
    if (variant === "danger") return dangerCol;
    return neutralCol;
  }

  height: 22
  implicitHeight: 22
  implicitWidth: badgeRow.implicitWidth + 14
  radius: 5
  color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.15)
  border.color: Qt.rgba(activeColor.r, activeColor.g, activeColor.b, 0.5)
  border.width: 1

  Row {
    id: badgeRow
    anchors.centerIn: parent
    spacing: 5

    Rectangle {
      visible: root.showDot
      anchors.verticalCenter: parent.verticalCenter
      width: 5
      height: 5
      radius: 2.5
      color: root.activeColor
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
      font.pixelSize: 10
      font.bold: true
      color: root.activeColor
    }
  }
}
