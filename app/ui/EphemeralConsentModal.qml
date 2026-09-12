import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: modal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.75)
  z: 1000

  property string targetServerName: ""
  property string targetServerId: ""
  signal confirmed(string serverId)

  function openForServer(name, id) {
    targetServerName = name;
    targetServerId = id;
    ackCheck.checked = false;
    modal.visible = true;
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block click-through
  }

  Rectangle {
    width: 520
    height: modalCol.implicitHeight + 48
    radius: 16
    color: "#181206"
    border.color: warningAmber
    border.width: 2
    anchors.centerIn: parent

    ColumnLayout {
      id: modalCol
      anchors.fill: parent
      anchors.margins: 24
      spacing: 16

      // Warning Header
      RowLayout {
        spacing: 12
        Rectangle {
          width: 40
          height: 40
          radius: 10
          color: "#451a03"
          Text { anchors.centerIn: parent; text: "⚠️"; font.pixelSize: 20 }
        }
        ColumnLayout {
          spacing: 2
          Text {
            text: "MANDATORY SAFETY CONSENT"
            font.pixelSize: 15
            font.bold: true
            color: warningAmber
          }
          Text {
            text: "Ephemeral Compute Drive Mount"
            font.pixelSize: 12
            color: textSecondary
          }
        }
      }

      // Warning Content Box
      Rectangle {
        Layout.fillWidth: true
        height: warnText.implicitHeight + 24
        radius: 8
        color: "#291804"
        border.color: "#78350f"

        Text {
          id: warnText
          anchors.fill: parent
          anchors.margins: 12
          text: "You are about to mount the EPHEMERAL root filesystem of server '" + modal.targetServerName + "' to ~/Companion-VM.\n\n" +
                "THIS IS NOT A STORAGE BOX!\n\n" +
                "The storage is hosted on the cloud VM's local ephemeral virtual disk. When this VM powers off, reboots, or is destroyed, ALL FILES SAVED ON THIS DRIVE WILL BE PERMANENTLY ERASED.\n\n" +
                "For permanent data storage, use your 1.0 TB Storage Box at ~/Cloud instead."
          font.pixelSize: 11
          color: "#fde68a"
          wrapMode: Text.WordWrap
        }
      }

      // Checkbox
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        CheckBox {
          id: ackCheck
        }
        Text {
          text: "I understand that any files saved here will be wiped upon VM shutdown."
          font.pixelSize: 11
          font.bold: true
          color: textPrimary
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }

      // Buttons
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Button {
          text: "Cancel"
          Layout.fillWidth: true
          background: Rectangle {
            radius: 6
            color: "#1e293b"
          }
          contentItem: Text {
            text: "Cancel"
            color: textPrimary
            font.bold: true
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: modal.visible = false
        }

        Button {
          id: agreeBtn
          text: "I Understand, Mount Drive"
          enabled: ackCheck.checked
          Layout.fillWidth: true
          background: Rectangle {
            radius: 6
            color: agreeBtn.enabled ? (agreeBtn.hovered ? "#b45309" : warningAmber) : "#332200"
          }
          contentItem: Text {
            text: agreeBtn.text
            color: agreeBtn.enabled ? "#000000" : textMuted
            font.bold: true
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: {
            modal.visible = false;
            modal.confirmed(modal.targetServerId);
          }
        }
      }
    }
  }
}
