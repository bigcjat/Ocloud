import QtQuick
import QtQuick.Effects

Item {
  id: root
  property string source: ""
  property color color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"

  implicitWidth: 20
  implicitHeight: 20

  Image {
    id: rawIcon
    anchors.fill: parent
    source: {
      if (!root.source) return "";
      if (root.source.indexOf(":") >= 0) return root.source;
      if (root.source.indexOf("icons/") === 0) return Qt.resolvedUrl("../" + root.source);
      return Qt.resolvedUrl(root.source);
    }
    sourceSize.width: Math.max(48, root.width * 2)
    sourceSize.height: Math.max(48, root.height * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    visible: false
  }

  MultiEffect {
    anchors.fill: parent
    source: rawIcon
    brightness: 1.0
    colorization: 1.0
    colorizationColor: root.color
  }
}
