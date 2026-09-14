import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color borderCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333"
  readonly property color cardBg: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#111111"

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
    anchors.margins: 16
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 12

      // =========================================================
      // HEADER
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          Text {
            text: "SETTINGS & PREFERENCES"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            font.letterSpacing: 1.2
          }

          Text {
            text: "File manager integration · Credentials vault · Client diagnostics"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        // Test Launch Button
        Rectangle {
          implicitWidth: testText.implicitWidth + 14
          implicitHeight: 24
          radius: 2
          color: testMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: root.borderCol
          border.width: 1

          Text {
            id: testText
            anchors.centerIn: parent
            text: "Test File Manager"
            font.family: root.appFontFamily
            font.pixelSize: 10
            color: root.textColor
          }

          MouseArea {
            id: testMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ocloud.testLaunchFileManager(selectedFileManager, customCommand)
          }
        }
      }

      // Thin separator
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.borderCol
      }

      // Status Notification Ribbon
      Rectangle {
        visible: root.statusMessage !== ""
        Layout.fillWidth: true
        implicitHeight: 28
        radius: 2
        color: root.cardBg
        border.color: root.statusIsError
          ? ((typeof theme !== "undefined" && theme.danger) ? theme.danger : "#f7768e")
          : ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 8

          Rectangle {
            width: 6
            height: 6
            radius: 3
            color: root.statusIsError
              ? ((typeof theme !== "undefined" && theme.danger) ? theme.danger : "#f7768e")
              : ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
          }

          Text {
            Layout.fillWidth: true
            text: root.statusMessage
            font.family: root.appFontFamily
            font.pixelSize: 11
            color: root.textColor
          }

          Text {
            text: "✕"
            font.family: root.appFontFamily
            font.pixelSize: 10
            color: root.mutedColor
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.statusMessage = ""
            }
          }
        }
      }

      // =========================================================
      // FILE MANAGER INTEGRATION
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: fmCol.implicitHeight + 20
        radius: 2
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          id: fmCol
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
              width: 6
              height: 6
              radius: 3
              color: root.accentColor
            }

            Text {
              text: "DEFAULT FILE MANAGER"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.mutedColor
            font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "ACTIVE: " + root.selectedFileManager.toUpperCase()
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.accentColor
            }
          }

          // Single column File Manager Radio Rows
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
              model: root.fileManagers

              delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 2
                color: fmMouse.containsMouse
                  ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                  : (root.selectedFileManager === modelData.id
                      ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                      : "transparent")
                border.color: root.selectedFileManager === modelData.id ? root.accentColor : root.borderCol
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 8

                  // Radio dot
                  Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "transparent"
                    border.color: root.selectedFileManager === modelData.id ? root.accentColor : root.mutedColor
                    border.width: 1

                    Rectangle {
                      anchors.centerIn: parent
                      width: 6
                      height: 6
                      radius: 3
                      color: root.accentColor
                      visible: root.selectedFileManager === modelData.id
                    }
                  }

                  Text {
                    text: modelData.name + (modelData.badge ? (" (" + modelData.badge + ")") : "")
                    font.family: root.appFontFamily
                    font.pixelSize: 11
                    font.bold: root.selectedFileManager === modelData.id
                    color: root.selectedFileManager === modelData.id ? root.accentColor : root.textColor
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.desc || ""
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    color: root.mutedColor
                    elide: Text.ElideRight
                  }

                  Text {
                    visible: !modelData.available && modelData.id !== "custom"
                    text: "Not Installed"
                    font.family: root.appFontFamily
                    font.pixelSize: 9
                    color: (typeof theme !== "undefined" && theme.danger) ? theme.danger : "#f7768e"
                  }
                }

                MouseArea {
                  id: fmMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.selectedFileManager = modelData.id;
                    root.saveAllSettings();
                  }
                }
              }
            }
          }

          // Custom Command Field
          ColumnLayout {
            Layout.fillWidth: true
            visible: root.selectedFileManager === "custom"
            spacing: 3

            Text {
              text: "CUSTOM EXECUTABLE / COMMAND"
              font.family: root.appFontFamily
              font.pixelSize: 9
              font.bold: true
              color: root.mutedColor
            }

            TextField {
              id: customCmdField
              Layout.fillWidth: true
              implicitHeight: 24
              font.family: root.appFontFamily
              font.pixelSize: 11
              text: root.customCommand
              placeholderText: "e.g. ghostty -e yazi, thunar, or pcmanfm"
              color: root.textColor
              background: Rectangle {
                color: "transparent"
                border.color: root.borderCol
                border.width: 1
                radius: 2
              }
              onTextChanged: root.customCommand = text
              onEditingFinished: root.saveAllSettings()
            }
          }

          // Pre-flight probe row
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                text: "Drive Safety Pre-flight Probe"
                font.family: root.appFontFamily
                font.pixelSize: 11
                font.bold: true
                color: root.textColor
              }

              Text {
                text: "2-second timeout probe before launching file manager to protect against stalled networks"
                font.family: root.appFontFamily
                font.pixelSize: 10
                color: root.mutedColor
              }
            }

            AppSwitch {
              checked: root.probeEnabled
              onToggled: {
                root.probeEnabled = checked;
                root.saveAllSettings();
              }
            }
          }
        }
      }

      // =========================================================
      // CREDENTIALS VAULT
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: vaultCol.implicitHeight + 20
        radius: 2
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          id: vaultCol
          anchors.fill: parent
          anchors.margins: 10
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
              width: 6
              height: 6
              radius: 3
              color: (typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a"
            }

            Text {
              text: "CREDENTIALS VAULT"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: root.mutedColor
            font.letterSpacing: 1.2
            }

            Item { Layout.fillWidth: true }

            Text {
              text: "~/.config/omarchy/vault.enc (AES-256-GCM · 600)"
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: root.mutedColor
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "TAILSCALE REUSABLE AUTH KEY"
                font.family: root.appFontFamily
                font.pixelSize: 9
                font.bold: true
                color: root.mutedColor
              }
              Item { Layout.fillWidth: true }
              Text {
                visible: root.hasTailscaleKey
                text: root.tailscaleDaysSince >= 0
                  ? (root.tailscaleDaysSince === 0 ? "Key stored today" : ("Stored " + root.tailscaleDaysSince + "d ago"))
                  : "Stored in Vault"
                font.family: root.appFontFamily
                font.pixelSize: 10
                color: root.tailscaleExpiringSoon
                  ? ((typeof theme !== "undefined" && theme.warning) ? theme.warning : "#e0af68")
                  : ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              TextField {
                id: tsField
                Layout.fillWidth: true
                implicitHeight: 24
                echoMode: TextInput.Password
                font.family: root.appFontFamily
                font.pixelSize: 11
                placeholderText: root.hasTailscaleKey ? "••••••••••••••••••••••••" : "tskey-auth-..."
                color: root.textColor
                background: Rectangle {
                  color: "transparent"
                  border.color: root.borderCol
                  border.width: 1
                  radius: 2
                }
              }

              Rectangle {
                implicitWidth: saveKeyText.implicitWidth + 14
                implicitHeight: 24
                radius: 2
                color: saveKeyMouse.containsMouse ? root.accentColor : "transparent"
                border.color: root.accentColor
                border.width: 1

                Text {
                  id: saveKeyText
                  anchors.centerIn: parent
                  text: "Save"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: saveKeyMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                    : root.accentColor
                }

                MouseArea {
                  id: saveKeyMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (tsField.text.trim()) {
                      ocloud.setVaultSecret("tailscale_auth_key", tsField.text.trim());
                      tsField.text = "";
                      root.reloadTailscaleInfo();
                    }
                  }
                }
              }

              Rectangle {
                visible: root.hasTailscaleKey
                implicitWidth: clearKeyText.implicitWidth + 14
                implicitHeight: 24
                radius: 2
                color: "transparent"
                border.color: root.borderCol
                border.width: 1

                Text {
                  id: clearKeyText
                  anchors.centerIn: parent
                  text: "Clear"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
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
      }

      // =========================================================
      // SYSTEM DIAGNOSTICS
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: diagCol.implicitHeight + 16
        radius: 2
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          id: diagCol
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6

          Text {
            text: "SYSTEM DIAGNOSTICS"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            font.letterSpacing: 1.2
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "ARCHITECTURE"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              Text { text: "Apple Silicon (aarch64)"; font.family: root.appFontFamily; font.pixelSize: 11; color: root.textColor }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "COMPOSITOR"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              Text { text: "Hyprland Wayland"; font.family: root.appFontFamily; font.pixelSize: 11; color: root.textColor }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text { text: "SECURITY ENGINE"; font.family: root.appFontFamily; font.pixelSize: 9; font.bold: true; color: root.mutedColor }
              Text { text: "AES-256-GCM / PBKDF2"; font.family: root.appFontFamily; font.pixelSize: 11; color: root.textColor }
            }
          }
        }
      }
    }
  }
}
