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
  property int minRamMb: 0
  property int serverRamMb: 0
  property bool isInstalling: false
  property string statusMessage: ""
  property string logText: ""
  property int elapsedSeconds: 0

  signal installConfirmed(string serverId, string command, string name)

  function openForApp(name, cmd, serverName, serverId, reqRam, srvRam) {
    appName = name || "";
    appCmd = cmd || "";
    targetServerName = serverName || "Cloud Server";
    targetServerId = serverId || "";
    minRamMb = reqRam || 0;
    serverRamMb = srvRam || 0;
    isInstalling = false;
    statusMessage = "";
    logText = "";
    elapsedSeconds = 0;
    modal.visible = true;
  }

  function appendLog(line) {
    logText += line + "\n";
    Qt.callLater(() => {
      if (terminalFlick) {
        terminalFlick.contentY = Math.max(0, terminalText.implicitHeight - terminalFlick.height);
      }
    });
  }

  function formatTime(secs) {
    var m = Math.floor(secs / 60);
    var s = secs % 60;
    return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
  }

  Timer {
    id: elapsedTimer
    interval: 1000
    repeat: true
    running: modal.isInstalling
    onTriggered: modal.elapsedSeconds++
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block click-through
  }

  Rectangle {
    id: modalDialog
    width: Math.min(600, parent.width - 40)
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
      spacing: 14

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

      // Memory Feasibility Warning (if node RAM < app minimum requirement)
      Rectangle {
        visible: modal.minRamMb > 0 && modal.serverRamMb > 0 && modal.serverRamMb < modal.minRamMb
        Layout.fillWidth: true
        implicitHeight: warnRow.implicitHeight + 16
        radius: 8
        color: "#451a03"
        border.color: "#d97706"
        border.width: 1

        RowLayout {
          id: warnRow
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          Text {
            text: "⚠️"
            font.pixelSize: 18
            Layout.alignment: Qt.AlignTop
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
              text: "Hardware Feasibility Notice"
              font.bold: true
              font.pixelSize: 12
              color: "#fef3c7"
            }
            Text {
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              text: "<b>" + modal.appName + "</b> recommends at least <b>" + modal.minRamMb + " MB</b> of RAM. This server currently has <b>" + modal.serverRamMb + " MB</b>. Ocloud will configure a 4GB disk swapfile to prevent out-of-memory errors."
              font.pixelSize: 11
              color: "#fde68a"
            }
          }
        }
      }

      // Description
      Text {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: "<b>" + modal.appName + "</b> (<font color=\"#38bdf8\"><code>" + modal.appCmd + "</code></font>) is not yet installed on <b>" + modal.targetServerName + "</b>.<br>Ocloud will install the verified package and dependencies directly on the remote host and automatically stream the window."
        font.pixelSize: 13
        lineHeight: 1.3
        textFormat: Text.RichText
        color: (typeof theme !== "undefined" && theme.textSecondary) ? theme.textSecondary : "#a9b1d6"
      }

      // Status / Progress Message
      Rectangle {
        visible: modal.statusMessage.length > 0 || modal.isInstalling
        Layout.fillWidth: true
        implicitHeight: 38
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
            implicitWidth: 18
            implicitHeight: 18
          }

          Text {
            Layout.fillWidth: true
            text: modal.statusMessage.length > 0 ? modal.statusMessage : "Installing via remote package manager..."
            font.pixelSize: 12
            color: modal.statusMessage.indexOf("failed") >= 0 ? "#fbbf24" : "#60a5fa"
            elide: Text.ElideRight
          }

          Text {
            visible: modal.isInstalling
            text: modal.formatTime(modal.elapsedSeconds)
            font.pixelSize: 11
            font.family: "Monospace"
            font.bold: true
            color: "#94a3b8"
          }
        }
      }

      // Live Terminal Output Drawer
      Rectangle {
        visible: modal.isInstalling || modal.logText.length > 0
        Layout.fillWidth: true
        implicitHeight: 160
        radius: 8
        color: "#0a0e1a"
        border.color: "#1e293b"
        border.width: 1
        clip: true

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          // Terminal titlebar
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 24
            color: "#111827"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10

              Row {
                spacing: 5
                Rectangle { width: 8; height: 8; radius: 4; color: "#ef4444" }
                Rectangle { width: 8; height: 8; radius: 4; color: "#f59e0b" }
                Rectangle { width: 8; height: 8; radius: 4; color: "#10b981" }
              }

              Item { width: 8 }

              Text {
                text: "REMOTE PACKAGE MANAGER OUTPUT"
                font.pixelSize: 9
                font.bold: true
                color: "#64748b"
              }

              Item { Layout.fillWidth: true }

              Text {
                text: "LIVE STDOUT"
                font.pixelSize: 9
                font.bold: true
                color: modal.isInstalling ? "#38bdf8" : "#64748b"
              }
            }
          }

          // Monospace output viewport
          Flickable {
            id: terminalFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: terminalText.implicitWidth
            contentHeight: terminalText.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick

            TextEdit {
              id: terminalText
              width: terminalFlick.width - 20
              text: modal.logText.length > 0 ? modal.logText : "Connecting to host...\n"
              readOnly: true
              selectByMouse: true
              font.family: "Monospace"
              font.pixelSize: 11
              color: "#38bdf8"
              wrapMode: TextEdit.WrapAnywhere
              leftPadding: 10
              topPadding: 8
              rightPadding: 10
              bottomPadding: 8
            }
          }
        }
      }

      Item { height: 2 }

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
