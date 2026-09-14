import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Button {
  id: root
  // Variants: "primary", "secondary", "success", "danger"
  property string variant: "secondary"
  property string iconSource: ""
  property int customWidth: 0
  property bool loading: false

  implicitHeight: 32
  implicitWidth: {
    if (customWidth > 0) return customWidth;
    var w = 0;
    if (root.iconSource !== "" || root.loading) w += 16;
    if ((root.iconSource !== "" || root.loading) && root.text !== "") w += 8;
    if (root.text !== "") w += textMeasure.implicitWidth;
    return Math.max(w + 24, 64);
  }

  // System Theme colors resolution
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color successColor: (typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : "#22c55e"
  readonly property color dangerColor: (typeof theme !== "undefined" && theme.dangerRed) ? theme.dangerRed : "#ef4444"
  readonly property color baseCardBg: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#1e2233"
  readonly property color borderSubtleCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#475569"
  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"

  readonly property color contentColor: {
    if (variant === "danger") {
      return "#ffffff";
    }
    if (variant === "primary" || variant === "success") {
      return "#ffffff";
    }
    return (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#f8fafc";
  }

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

  // Background styling matching OS theme with high contrast
  background: Rectangle {
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
    border.width: 1
    clip: true

    color: {
      if (variant === "primary") {
        return root.down ? "#1d4ed8" : (root.hovered ? "#2563eb" : "#1e40af");
      }
      if (variant === "success") {
        // High contrast deep emerald green
        return root.down ? "#14532d" : (root.hovered ? "#166534" : "#15803d");
      }
      if (variant === "danger") {
        return root.down ? "#7f1d1d" : (root.hovered ? "#991b1b" : "#b91c1c");
      }
      // secondary
      return root.down ? Qt.darker(root.baseCardBg, 1.15) : (root.hovered ? Qt.lighter(root.baseCardBg, 1.25) : root.baseCardBg);
    }

    border.color: {
      if (variant === "primary") {
        return root.hovered ? "#93c5fd" : "#3b82f6";
      }
      if (variant === "success") {
        return root.hovered ? "#86efac" : "#22c55e";
      }
      if (variant === "danger") {
        return root.hovered ? "#fca5a5" : "#ef4444";
      }
      // secondary
      return root.hovered ? root.accentColor : root.borderSubtleCol;
    }

    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on border.color { ColorAnimation { duration: 100 } }
  }

  // Content Item: Centered, high contrast icon and text
  contentItem: Item {
    anchors.fill: parent

    RowLayout {
      anchors.centerIn: parent
      spacing: 6

      // Rotating spinner if loading
      Item {
        visible: root.loading
        Layout.preferredWidth: 14
        Layout.preferredHeight: 14
        Layout.alignment: Qt.AlignVCenter

        Image {
          id: spinnerImg
          anchors.fill: parent
          source: Qt.resolvedUrl("../icons/refresh.svg")
          fillMode: Image.PreserveAspectFit
          visible: false
        }

        MultiEffect {
          anchors.fill: parent
          source: spinnerImg
          colorization: 1.0
          colorizationColor: root.contentColor
        }

        NumberAnimation on rotation {
          from: 0
          to: 360
          duration: 900
          loops: Animation.Infinite
          running: root.loading
        }
      }

      // Static Button Icon (if not loading)
      Item {
        visible: !root.loading && root.iconSource !== ""
        Layout.preferredWidth: 14
        Layout.preferredHeight: 14
        Layout.alignment: Qt.AlignVCenter

        Image {
          id: rawIcon
          anchors.fill: parent
          source: root.iconSource ? (root.iconSource.indexOf("/") !== -1 && !root.iconSource.startsWith("../") && !root.iconSource.startsWith("/") && !root.iconSource.startsWith("file:") ? Qt.resolvedUrl("../" + root.iconSource) : Qt.resolvedUrl(root.iconSource)) : ""
          fillMode: Image.PreserveAspectFit
          visible: false
        }

        MultiEffect {
          anchors.fill: parent
          source: rawIcon
          colorization: 1.0
          colorizationColor: root.contentColor
        }
      }

      Text {
        visible: root.text !== ""
        Layout.alignment: Qt.AlignVCenter
        text: root.text
        font.family: root.appFontFamily
        font.pixelSize: 11
        font.weight: Font.Bold
        color: root.contentColor
        verticalAlignment: Text.AlignVCenter
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: root.loading ? Qt.WaitCursor : Qt.PointingHandCursor
    acceptedButtons: Qt.NoButton
    enabled: !root.loading
  }
}

