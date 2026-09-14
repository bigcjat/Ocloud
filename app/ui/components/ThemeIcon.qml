import QtQuick
import QtQuick.Effects

Item {
  id: root
  property string source: ""
  property color color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"

  implicitWidth: 20
  implicitHeight: 20

  Rectangle {
    id: fillRect
    anchors.fill: parent
    color: root.color
    visible: false
  }

  Image {
    id: maskImage
    anchors.fill: parent
    source: {
      if (!root.source) return "";
      if (root.source.indexOf(":") >= 0) return root.source;
      if (root.source.indexOf("icons/") === 0) return Qt.resolvedUrl("../" + root.source);
      return Qt.resolvedUrl(root.source);
    }
    sourceSize.width: Math.max(64, root.width * 2)
    sourceSize.height: Math.max(64, root.height * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    visible: false
  }

  MultiEffect {
    anchors.fill: parent
    source: fillRect
    maskEnabled: true
    maskSource: maskImage
    visible: root.source.length > 0 && maskImage.status === Image.Ready
  }
}

