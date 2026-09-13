import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
  id: modal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.75)
  z: 1000

  signal nodeAdded()

  function openModal() {
    nodeNameField.text = "";
    nodeHostField.text = "";
    userField.text = "root";
    portField.text = "22";
    homeCheck.checked = false;
    modal.visible = true;
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block click-through
  }

  Rectangle {
    width: Math.min(480, parent.width - 20)
    implicitHeight: modalCol.implicitHeight + 36
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 12
    color: cardBg
    border.color: borderSubtle
    border.width: 1
    anchors.centerIn: parent

    ColumnLayout {
      id: modalCol
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 24
      spacing: 16

      // Title
      RowLayout {
        spacing: 10
        Image {
          width: 22
          height: 22
          source: Qt.resolvedUrl("../icons/server.svg")
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
        ColumnLayout {
          spacing: 2
          Text {
            text: "Register Custom or Home Node"
            font.pixelSize: 16
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Add bare-metal auction servers, GPU rigs, or your Home Workstation"
            font.pixelSize: 12
            color: textMuted
          }
        }
      }

      // Name
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Friendly Display Name"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: nodeNameField
          Layout.fillWidth: true
          placeholderText: "e.g. Home Desktop RTX 4090, Hetzner Auction AX41"
          color: textPrimary
          placeholderTextColor: textMuted
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // Host / IP
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Hostname or Tailscale / Public IPv4"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: nodeHostField
          Layout.fillWidth: true
          placeholderText: "100.x.y.z or 192.168.1.50 or domain.com"
          color: textPrimary
          placeholderTextColor: textMuted
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // User & Port
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "SSH User"; font.pixelSize: 11; font.bold: true; color: textSecondary }
          TextField {
            id: userField
            text: "root"
            Layout.fillWidth: true
            color: textPrimary
            background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
          }
        }

        ColumnLayout {
          Layout.preferredWidth: 100
          spacing: 4
          Text { text: "SSH Port"; font.pixelSize: 11; font.bold: true; color: textSecondary }
          TextField {
            id: portField
            text: "22"
            Layout.fillWidth: true
            color: textPrimary
            background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
          }
        }
      }

      // Home Workstation Checkbox
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        CheckBox {
          id: homeCheck
        }
        RowLayout {
          spacing: 6
          Image {
            width: 16
            height: 16
            source: Qt.resolvedUrl("../icons/device-workstation.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
          }
          ColumnLayout {
            spacing: 1
            Text {
              text: "Mark as Home Workstation / Rig"
              font.pixelSize: 12
              font.bold: true
              color: homeGreen
            }
            Text {
              text: "Enables Home Green styling and local low-latency routing"
              font.pixelSize: 10
              color: textMuted
            }
          }
        }
      }

      // Actions
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        AppButton {
          Layout.fillWidth: true
          text: "Cancel"
          variant: "secondary"
          onClicked: modal.visible = false
        }

        AppButton {
          id: addBtn
          Layout.fillWidth: true
          text: "Add to Fleet"
          variant: "primary"
          iconSource: "icons/server.svg"
          onClicked: {
            var name = nodeNameField.text.trim();
            var host = nodeHostField.text.trim();
            if (!name) {
              nodeNameField.forceActiveFocus();
              return;
            }
            if (!host) {
              nodeHostField.forceActiveFocus();
              return;
            }
            modal.visible = false;
            ocloud.addCustomNode(
              name,
              host,
              homeCheck.checked,
              userField.text.trim() || "root",
              parseInt(portField.text.trim(), 10) || 22
            );
            modal.nodeAdded();
          }
        }
      }
    }
  }
}
