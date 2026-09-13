import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
  id: root
  // Variants: "primary", "secondary", "success", "danger"
  property string variant: "secondary"
  property string iconSource: ""
  property int customWidth: 0

  implicitHeight: 32
  implicitWidth: {
    if (customWidth > 0) return customWidth;
    var w = 0;
    if (root.iconSource !== "") w += 16;
    if (root.iconSource !== "" && root.text !== "") w += 8;
    if (root.text !== "") w += textMeasure.implicitWidth;
    return Math.max(w + 24, 64);
  }

  // System Theme colors resolution
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color successColor: (typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : "#9ece6a"
  readonly property color dangerColor: (typeof theme !== "undefined" && theme.dangerRed) ? theme.dangerRed : "#f7768e"
  readonly property color baseCardBg: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#24283b"
  readonly property color borderSubtleCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868"
  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"

  // Hidden item for precise text measurement without layout anomalies
  Text {
    id: textMeasure
    visible: false
    text: root.text
    font.family: root.appFontFamily
    font.pixelSize: 11
    font.weight: Font.DemiBold
  }

  scale: root.down ? 0.98 : 1.0
  Behavior on scale { NumberAnimation { duration: 60 } }

  // Background styling matching OS theme
  background: Rectangle {
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
    border.width: 1
    clip: true

    color: {
      if (variant === "primary") {
        return root.down ? "#1d4ed8" : (root.hovered ? "#3b82f6" : "#2563eb");
      }
      if (variant === "success") {
        return root.down ? "#15803d" : (root.hovered ? "#16a34a" : "#22c55e");
      }
      if (variant === "danger") {
        var isDk = (typeof theme !== "undefined") ? theme.isDark : true;
        var alpha = root.down ? (isDk ? 0.32 : 0.36) : (root.hovered ? (isDk ? 0.22 : 0.26) : (isDk ? 0.12 : 0.16));
        return Qt.rgba(root.dangerColor.r, root.dangerColor.g, root.dangerColor.b, alpha);
      }
      // secondary
      return root.down ? Qt.darker(root.baseCardBg, 1.15) : (root.hovered ? Qt.lighter(root.baseCardBg, 1.18) : root.baseCardBg);
    }

    border.color: {
      if (variant === "primary") {
        return root.hovered ? "#93c5fd" : "#3b82f6";
      }
      if (variant === "success") {
        return root.hovered ? Qt.lighter(root.successColor, 1.25) : root.successColor;
      }
      if (variant === "danger") {
        return root.hovered ? root.dangerColor : Qt.rgba(root.dangerColor.r, root.dangerColor.g, root.dangerColor.b, 0.45);
      }
      // secondary
      return root.hovered ? root.accentColor : root.borderSubtleCol;
    }

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }
  }

  // Content Item: Always centered, zero drift, zero clip
  contentItem: Item {
    anchors.fill: parent

    RowLayout {
      anchors.centerIn: parent
      spacing: 6

      Image {
        visible: root.iconSource !== ""
        Layout.preferredWidth: 14
        Layout.preferredHeight: 14
        Layout.alignment: Qt.AlignVCenter
        source: root.iconSource ? (root.iconSource.indexOf("/") !== -1 && !root.iconSource.startsWith("../") && !root.iconSource.startsWith("/") && !root.iconSource.startsWith("file:") ? Qt.resolvedUrl("../" + root.iconSource) : Qt.resolvedUrl(root.iconSource)) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
      }

      Text {
        visible: root.text !== ""
        Layout.alignment: Qt.AlignVCenter
        text: root.text
        font.family: root.appFontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: {
          if (variant === "danger") {
            return root.hovered ? ((typeof theme !== "undefined" && theme.isDark) ? Qt.lighter(root.dangerColor, 1.15) : Qt.darker(root.dangerColor, 1.15)) : root.dangerColor;
          }
          if (variant === "primary" || variant === "success") {
            return "#ffffff";
          }
          return (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#f8fafc";
        }
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.NoButton
  }
}
