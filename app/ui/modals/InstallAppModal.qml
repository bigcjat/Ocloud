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

  property string appName: ""
  property string appCmd: ""
  property string targetServerName: ""
  property string targetServerId: ""
  property bool isInstalling: false
  property string statusMessage: ""

  signal installConfirmed(string serverId, string command, string name)

  function openForApp(name, cmd, serverName, serverId) {
    appName = name;
    appCmd = cmd;
    targetServerName = serverName;
    targetServerId = serverId;
    isInstalling = false;
    statusMessage = "";
    modal.visible = true;
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block click-through
  }

  Rectangle {
    id: modalDialog
    width: Math.min(520, parent.width - 40)
    implicitHeight: modalCol.implicitHeight + 48
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 12
    color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#1e2233"
    border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#3b4261"
    border.width: 1
    anchors.centerIn: parent

    ColumnLayout {
      id: modalCol
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 24
      spacing: 16

      // Header Row
      RowLayout {
        spacing: 12
        Rectangle {
          width: 44
          height: 44
          radius: 10
          color: "#1e1b4b"
          border.color: "#4338ca"
          border.width: 1
          Image {
            anchors.centerIn: parent
            width: 24
            height: 24
            source: Qt.resolvedUrl("../icons/terminal.svg")
            fillMode: Image.PreserveAspectFit
          }
        }

        ColumnLayout {
          spacing: 2
          Text {
            text: "Install " + modal.appName + "?"
            font.pixelSize: 18
            font.bold: true
            color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
          }
          Text {
            text: "Package Missing on " + modal.targetServerName
            font.pixelSize: 12
            color: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#7aa2f7"
          }
        }
      }

      // Description
      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "<b>" + modal.appName + "</b> (<code>" + modal.appCmd + "</code>) is not currently installed on <b>" + modal.targetServerName + "</b>.<br><br>Would you like Ocloud to install it via the remote package manager and automatically stream the window to your desktop once installed?"
        font.pixelSize: 13
        lineHeight: 1.3
        textFormat: Text.RichText
        color: (typeof theme !== "undefined" && theme.textSecondary) ? theme.textSecondary : "#a9b1d6"
      }

      // Status / Progress Message
      Rectangle {
        visible: modal.statusMessage.length > 0 || modal.isInstalling
        Layout.fillWidth: true
        implicitHeight: 42
        radius: 8
        color: modal.statusMessage.indexOf("failed") >= 0 ? "#451a03" : "#0f172a"
        border.color: modal.statusMessage.indexOf("failed") >= 0 ? "#b45309" : "#3b82f6"
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10

          BusyIndicator {
            visible: modal.isInstalling
            running: modal.isInstalling
            implicitWidth: 20
            implicitHeight: 20
          }

          Text {
            Layout.fillWidth: true
            text: modal.statusMessage.length > 0 ? modal.statusMessage : "Installing package via remote package manager..."
            font.pixelSize: 12
            color: modal.statusMessage.indexOf("failed") >= 0 ? "#fbbf24" : "#60a5fa"
            elide: Text.ElideRight
          }
        }
      }

      Item { height: 4 }

      // Action Buttons
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Item { Layout.fillWidth: true }

        AppButton {
          text: "Cancel"
          variant: "secondary"
          enabled: !modal.isInstalling
          onClicked: modal.visible = false
        }

        AppButton {
          text: modal.isInstalling ? "Installing..." : "Install & Launch"
          variant: "primary"
          iconSource: "icons/plus.svg"
          enabled: !modal.isInstalling
          onClicked: modal.installConfirmed(modal.targetServerId, modal.appCmd, modal.appName)
        }
      }
    }
  }
}
