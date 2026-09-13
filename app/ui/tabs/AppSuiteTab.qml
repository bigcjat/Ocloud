import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../modals"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  property string selectedServerId: serverList.length > 0 ? String(serverList[0].id) : ""
  property var appList: []

  function reloadApps() {
    ocloud.fetchAppShortcuts(function(list) {
      if (list && list.length > 0) {
        root.appList = list;
      }
    });
  }

  function requestLaunch(cmd, name) {
    if (!root.selectedServerId) return;
    ocloud.probeApp(root.selectedServerId, cmd, function(res, ok) {
      if (res && res.installed) {
        ocloud.launchApp(root.selectedServerId, cmd);
      } else {
        var srvName = (res && res.serverName) ? res.serverName : targetCombo.currentText;
        installModal.openForApp(name || cmd, cmd, srvName, root.selectedServerId);
      }
    });
  }

  Component.onCompleted: {
    reloadApps();
  }

  Connections {
    target: ocloud
    function onActionCompleted(action, success, msg) {
      if (action === "launchApp") {
        root.reloadApps();
      }
    }
  }

  ScrollView {
    anchors.fill: parent
    anchors.margins: root.isNarrow ? 12 : 20
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 16

      // Unified Header
      AppHeader {
        title: "Waypipe App Suite"
        subtitle: "Stream native Wayland GUI applications from your Cloud VM or Home Workstation"

        RowLayout {
          spacing: 8
          Text {
            text: "Run on:"
            font.pixelSize: 12
            font.bold: true
            color: textSecondary
          }
          AppComboBox {
            id: targetCombo
            implicitHeight: 32
            implicitWidth: 260
            model: serverList.map(function(s) {
              var prov = s.providerName || (s.isHomeWorkstation ? "Home Workstation" : (s.provider ? s.provider.toUpperCase() : "Cloud"));
              return s.name + " [" + prov + "]";
            })
            onCurrentIndexChanged: {
              if (currentIndex >= 0 && currentIndex < serverList.length) {
                root.selectedServerId = String(serverList[currentIndex].id);
              }
            }
          }
        }
      }

      // Window Integration Status Banner
      AppBanner {
        variant: "info"
        iconSource: "icons/shield.svg"
        title: "Native Window Integration Active"
        message: "Remote apps stream with provider-tagged window titles and distinctive glowing Red borders (#d50c2d) across all Cloud VMs (Emerald Green for Home Workstations)."
      }

      // App Cards Grid (Dynamic Built-in + User Shortcuts)
      GridLayout {
        Layout.fillWidth: true
        columns: root.isNarrow ? 1 : (width < 800 ? 2 : 3)
        rowSpacing: 16
        columnSpacing: 16

        Repeater {
          model: appList

          delegate: AppCard {
            Layout.fillWidth: true
            implicitHeight: 185

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 16
              spacing: 10

              RowLayout {
                Layout.fillWidth: true
                Rectangle {
                  width: Math.max(56, tagTxt.implicitWidth + 14)
                  height: 24
                  radius: 6
                  color: modelData.tag === "RECENT" ? "#1e293b" : "#1e1b4b"
                  border.color: modelData.tag === "RECENT" ? "#334155" : "#312e81"
                  Text {
                    id: tagTxt
                    anchors.centerIn: parent
                    text: modelData.tag || "APP"
                    font.pixelSize: 10
                    font.bold: true
                    color: modelData.tag === "RECENT" ? "#38bdf8" : accentSky
                  }
                }
                Item { Layout.fillWidth: true }
                AppBadge {
                  visible: !!modelData.featured || modelData.tag === "RECENT"
                  text: modelData.featured ? "Featured" : "Shortcut"
                  variant: modelData.featured ? "info" : "neutral"
                }
              }

              Text {
                text: modelData.name || modelData.cmd
                font.pixelSize: 15
                font.bold: true
                color: textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: modelData.desc || ("Command: " + modelData.cmd)
                font.pixelSize: 11
                color: textMuted
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }

              Item { Layout.fillHeight: true }

              AppButton {
                text: "Launch " + (modelData.name || modelData.cmd)
                variant: modelData.featured ? "primary" : "secondary"
                iconSource: "icons/terminal.svg"
                onClicked: root.requestLaunch(modelData.cmd, modelData.name)
              }
            }
          }
        }
      }

      // Custom Command Runner Card (Automatically adds executed app as shortcut)
      AppCard {
        Layout.fillWidth: true
        implicitHeight: customAppCol.implicitHeight + 32

        ColumnLayout {
          id: customAppCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 12

          Row {
            spacing: 8
            Image {
              width: 16
              height: 16
              anchors.verticalCenter: parent.verticalCenter
              source: Qt.resolvedUrl("../icons/terminal.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
            Text {
              text: "Run Any Custom Linux App over Waypipe"
              font.pixelSize: 14
              font.bold: true
              color: textPrimary
            }
          }

          Text {
            text: "Execute any GUI application installed on your remote server (e.g. gimp, blender, firefox, kdenlive, foot). Once launched, it will be automatically pinned as a shortcut above."
            font.pixelSize: 11
            color: textMuted
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            AppTextField {
              id: customCmdField
              Layout.fillWidth: true
              implicitHeight: 32
              placeholderText: "e.g. gimp, foot, mpv video.mp4"
            }

            AppButton {
              text: "Stream App"
              iconSource: "icons/terminal.svg"
              variant: "primary"
              enabled: customCmdField.text.trim().length > 0
              onClicked: {
                var cmd = customCmdField.text.trim();
                if (cmd) {
                  root.requestLaunch(cmd, cmd);
                  customCmdField.text = "";
                }
              }
            }
          }
        }
      }
    }
  }

  // Confirmation Modal for Missing Packages
  InstallAppModal {
    id: installModal
    onInstallConfirmed: function(srvId, command, appName) {
      installModal.isInstalling = true;
      installModal.statusMessage = "Installing " + appName + " on " + installModal.targetServerName + "...";
      ocloud.installApp(srvId, command, function(ok, out) {
        installModal.isInstalling = false;
        if (ok) {
          installModal.visible = false;
          ocloud.launchApp(srvId, command);
        } else {
          installModal.statusMessage = "Installation failed: " + (out || "Unknown error");
        }
      });
    }
  }
}
