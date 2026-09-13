import QtQuick
import QtQuick.Controls

Switch {
  id: root

  implicitWidth: 42
  implicitHeight: 24
  padding: 0

  indicator: Rectangle {
    implicitWidth: 42
    implicitHeight: 24
    radius: 12
    color: root.checked ? "#0284c7" : "#1e293b"
    border.color: root.checked ? "#38bdf8" : "#334155"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
      x: root.checked ? parent.width - width - 3 : 3
      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18
      radius: 9
      color: "#ffffff"

      Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }
  }
}
