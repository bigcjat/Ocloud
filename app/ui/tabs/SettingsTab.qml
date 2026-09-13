import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 520

  property var fileManagers: []
  property string selectedFileManager: "default"
  property string customCommand: ""
  property bool probeEnabled: true
  property int probeTimeout: 2
  property string statusMessage: ""
  property bool statusIsError: false
  property bool hasTailscaleKey: false
  property int tailscaleDaysSince: -1
  property bool tailscaleExpiringSoon: false

  function reloadTailscaleInfo() {
    ocloud.getVaultKeyInfo("tailscale_auth_key", function(info, ok) {
      if (ok && info) {
        hasTailscaleKey = !!info.hasKey;
        tailscaleDaysSince = (typeof info.daysSince === "number") ? info.daysSince : -1;
        tailscaleExpiringSoon = !!info.isExpiringSoon;
      }
    });
  }

  function loadSettings() {
    try {
      var rawFMs = ocloud.getAvailableFileManagers();
      fileManagers = JSON.parse(rawFMs);
    } catch (e) {
      console.log("Error loading file managers: " + e);
    }

    try {
      var rawSettings = ocloud.fetchSettings();
      var settings = JSON.parse(rawSettings);
      selectedFileManager = settings.fileManager || "default";
      customCommand = settings.customFileManagerCmd || "";
      probeEnabled = (typeof settings.probeMountsBeforeOpen !== "undefined") ? settings.probeMountsBeforeOpen : true;
      probeTimeout = settings.probeTimeoutSeconds || 2;
    } catch (e) {
      console.log("Error loading settings: " + e);
    }
  }

  function saveAllSettings() {
    var payload = {
      fileManager: selectedFileManager,
      customFileManagerCmd: customCommand,
      probeMountsBeforeOpen: probeEnabled,
      probeTimeoutSeconds: probeTimeout
    };
    ocloud.saveSettings(JSON.stringify(payload));
  }

  Component.onCompleted: {
    loadSettings();
    reloadTailscaleInfo();
  }

  Connections {
    target: ocloud
    function onSettingsUpdated(jsonStr) {
      try {
        var settings = JSON.parse(jsonStr);
        if (settings.fileManager) selectedFileManager = settings.fileManager;
        if (settings.customFileManagerCmd !== undefined) customCommand = settings.customFileManagerCmd;
        if (typeof settings.probeMountsBeforeOpen !== "undefined") probeEnabled = settings.probeMountsBeforeOpen;
        if (settings.probeTimeoutSeconds !== undefined) probeTimeout = settings.probeTimeoutSeconds;
      } catch(e) {}
    }
    function onActionCompleted(action, success, msg) {
      if (action === "saveSettings" || action === "testLaunchFileManager") {
        statusMessage = msg;
        statusIsError = !success;
      }
      if (action === "setVaultSecret") {
        reloadTailscaleInfo();
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
      spacing: 20

      // Unified Header
      AppHeader {
        title: "Settings & System Preferences"
        subtitle: "Default file manager integration, credentials vault, and live datacenter latency prober"
      }

      // Status Feedback Banner
      AppBanner {
        visible: statusMessage !== ""
        Layout.fillWidth: true
        title: statusIsError ? "Notice" : "Success"
        message: statusMessage
        variant: statusIsError ? "warning" : "success"
        iconSource: "icons/activity.svg"
      }

      // 1. File Manager & Desktop Integration Card
      AppCard {
        Layout.fillWidth: true
        implicitHeight: fmCol.implicitHeight + 32

        ColumnLayout {
          id: fmCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 16

          // Header
          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#0f766e"
              Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: Qt.resolvedUrl("../icons/hard-drive.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Default File Manager"
                font.pixelSize: 15
                font.bold: true
                color: textPrimary
              }
              Text {
                text: "Select which application handles mounted cloud drives, storage boxes, and folders"
                font.pixelSize: 11
                color: textMuted
              }
            }
            Item { Layout.fillWidth: true }
            AppBadge {
              text: selectedFileManager === "default" ? "OS Default" : selectedFileManager.toUpperCase()
              variant: selectedFileManager === "flea" ? "success" : "info"
            }
          }

          // File Manager Option Cards
          GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            Repeater {
              model: fileManagers

              delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                radius: 8
                color: selectedFileManager === modelData.id ? "#13233f" : (fmOptMouse.containsMouse ? "#0f172a" : "#0a101d")
                border.color: selectedFileManager === modelData.id ? "#0284c7" : (fmOptMouse.containsMouse ? "#334155" : borderSubtle)
                border.width: selectedFileManager === modelData.id ? 2 : 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 14
                  anchors.rightMargin: 14
                  spacing: 12

                  // Radio selection indicator
                  Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"
                    border.color: selectedFileManager === modelData.id ? "#38bdf8" : "#475569"
                    border.width: 2

                    Rectangle {
                      anchors.centerIn: parent
                      width: 8
                      height: 8
                      radius: 4
                      color: "#38bdf8"
                      visible: selectedFileManager === modelData.id
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                      spacing: 8
                      Text {
                        text: modelData.name
                        font.pixelSize: 13
                        font.bold: true
                        color: textPrimary
                      }

                      AppBadge {
                        visible: !!modelData.badge
                        text: modelData.badge || ""
                        variant: modelData.id === "flea" ? "success" : (modelData.id === "default" ? "info" : "neutral")
                      }

                      AppBadge {
                        visible: !modelData.available && modelData.id !== "custom"
                        text: "Not Installed"
                        variant: "danger"
                      }
                    }

                    Text {
                      text: modelData.desc || ""
                      font.pixelSize: 10
                      color: textMuted
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }
                }

                MouseArea {
                  id: fmOptMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    selectedFileManager = modelData.id;
                    saveAllSettings();
                  }
                }
              }
            }
          }

          // Custom Command Field (visible if custom selected)
          ColumnLayout {
            Layout.fillWidth: true
            visible: selectedFileManager === "custom"
            spacing: 4

            Text {
              text: "Custom Executable / Command"
              font.pixelSize: 11
              font.bold: true
              color: textSecondary
            }

            AppTextField {
              id: customCmdField
              Layout.fillWidth: true
              implicitHeight: 34
              text: customCommand
              placeholderText: "e.g. ghostty -e yazi, thunar, or pcmanfm"
              onTextChanged: customCommand = text
            }
          }

          // Drive Safety Pre-flight Probe Row
          Rectangle {
            Layout.fillWidth: true
            height: 52
            radius: 8
            color: "#081424"
            border.color: borderSubtle

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 12

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                  text: "Drive Safety Pre-flight Probe (Recommended)"
                  font.pixelSize: 12
                  font.bold: true
                  color: textPrimary
                }
                Text {
                  text: "Performs a 2-second timeout probe before opening drives to protect against file manager freezes on stalled networks"
                  font.pixelSize: 10
                  color: textMuted
                }
              }

              AppSwitch {
                checked: probeEnabled
                onToggled: probeEnabled = checked
              }
            }
          }

          // Action Buttons Row
          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            AppButton {
              text: "Save File Manager Preference"
              variant: "primary"
              onClicked: saveAllSettings()
            }

            AppButton {
              text: "Test Launch File Manager"
              variant: "secondary"
              onClicked: {
                ocloud.testLaunchFileManager(selectedFileManager, customCommand);
              }
            }

            Item { Layout.fillWidth: true }
          }
        }
      }

      // 2. Vault Credentials Card
      AppCard {
        Layout.fillWidth: true
        implicitHeight: vaultCol.implicitHeight + 32

        ColumnLayout {
          id: vaultCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#0c4a6e"
              Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: Qt.resolvedUrl("../icons/shield.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Ocloud Credentials Vault"
                font.pixelSize: 15
                font.bold: true
                color: textPrimary
              }
              Text {
                text: "Encrypted at rest at ~/.config/omarchy/vault.enc (AES-256-GCM, chmod 600)"
                font.pixelSize: 11
                color: textMuted
              }
            }
            Item { Layout.fillWidth: true }
            AppBadge {
              text: "Locked 600"
              variant: "success"
            }
          }


          // Tailscale Key Field
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "Tailscale Reusable Auth Key (Optional for auto-join)"
                font.pixelSize: 11
                font.bold: true
                color: textSecondary
              }
              Item { Layout.fillWidth: true }
              AppBadge {
                visible: hasTailscaleKey
                text: tailscaleDaysSince >= 0 ? (tailscaleDaysSince === 0 ? "Added today (90d max)" : ("Added " + tailscaleDaysSince + "d ago (90d max)")) : "Stored in Vault"
                variant: tailscaleExpiringSoon ? "warning" : "success"
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              AppTextField {
                id: tsField
                Layout.fillWidth: true
                implicitHeight: 34
                echoMode: TextInput.Password
                placeholderText: hasTailscaleKey ? "••••••••••••••••••••••••" : "tskey-auth-..."
              }
              AppButton {
                text: "Save to Vault"
                variant: "primary"
                onClicked: {
                  if (tsField.text.trim()) {
                    ocloud.setVaultSecret("tailscale_auth_key", tsField.text.trim());
                    tsField.text = "";
                    root.reloadTailscaleInfo();
                  }
                }
              }
              AppButton {
                visible: hasTailscaleKey
                text: "Clear"
                variant: "danger"
                onClicked: {
                  ocloud.setVaultSecret("tailscale_auth_key", "");
                  tsField.text = "";
                  root.reloadTailscaleInfo();
                }
              }
            }
          }
        }
      }

      // 4. System & Architecture Diagnostics
      AppCard {
        Layout.fillWidth: true
        implicitHeight: diagCol.implicitHeight + 32

        ColumnLayout {
          id: diagCol
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: 16
          spacing: 14

          Text {
            text: "System & Architecture Diagnostics"
            font.pixelSize: 15
            font.bold: true
            color: textPrimary
          }

          GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 20

            ColumnLayout {
              spacing: 2
              Text { text: "CLIENT ARCHITECTURE"; font.pixelSize: 10; font.bold: true; color: textMuted }
              Text { text: "Apple Silicon (aarch64)"; font.pixelSize: 12; font.bold: true; color: textPrimary }
            }

            ColumnLayout {
              spacing: 2
              Text { text: "DESKTOP COMPOSITOR"; font.pixelSize: 10; font.bold: true; color: textMuted }
              Text { text: "Hyprland Wayland"; font.pixelSize: 12; color: textPrimary }
            }

            ColumnLayout {
              spacing: 2
              Text { text: "ENCRYPTION ENGINE"; font.pixelSize: 10; font.bold: true; color: textMuted }
              Text { text: "AES-256-GCM / PBKDF2"; font.pixelSize: 12; color: textPrimary }
            }

            ColumnLayout {
              spacing: 2
              Text { text: "DEFAULT FILE MANAGER"; font.pixelSize: 10; font.bold: true; color: textMuted }
              Text { text: selectedFileManager.toUpperCase(); font.pixelSize: 12; font.bold: true; color: accentSky }
            }
          }
        }
      }
    }
  }
}
