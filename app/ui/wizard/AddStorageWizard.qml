import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../components"

Rectangle {
  id: modal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.75)
  z: 1500

  signal storageAdded()

  property string stepName: "providers" // "providers", "methods", "config"
  property var selectedPlatform: null
  property var selectedMethod: null
  property bool isTesting: false
  property string testMessage: ""
  property bool testSuccess: false
  property bool showSecret: false
  property string searchQuery: ""

  readonly property bool hasMethods: !!(modal.selectedPlatform && modal.selectedPlatform.methods && modal.selectedPlatform.methods.length > 0)
  readonly property var activePlatformOrMethod: modal.selectedMethod || modal.selectedPlatform
  readonly property bool isOAuth: !!(modal.activePlatformOrMethod && (modal.activePlatformOrMethod.authType === "oauth" || modal.activePlatformOrMethod.type === "oauth"))
  readonly property bool isDirectLogin: !!(modal.activePlatformOrMethod && (modal.activePlatformOrMethod.authType === "credentials" || modal.activePlatformOrMethod.id === "protondrive"))
  readonly property bool isS3: !!(modal.activePlatformOrMethod && (modal.activePlatformOrMethod.authType === "s3" || modal.activePlatformOrMethod.rcloneType === "s3" || modal.activePlatformOrMethod.type === "s3"))
  readonly property bool isWebdav: !!(modal.activePlatformOrMethod && (modal.activePlatformOrMethod.authType === "webdav" || modal.activePlatformOrMethod.rcloneType === "webdav"))

  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#ffffff"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#888888"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color borderCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333"
  readonly property color cardColor: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#1e2233"
  readonly property color cardAltColor: (typeof theme !== "undefined" && theme.cardBgAlt) ? theme.cardBgAlt : "#13141c"
  readonly property color windowBg: (typeof theme !== "undefined" && theme.background) ? theme.background : "#1a1b26"

  property var platforms: []

  function loadPlatforms(force) {
    try {
      var raw = ocloud.fetchStoragePlugins(force);
      if (raw && raw.length > 2) {
        var list = JSON.parse(raw);
        if (list && list.length > 0) {
          platforms = list;
          return;
        }
      }
    } catch (e) {}
    platforms = [];
  }

  Connections {
    target: ocloud
    function onStoragePluginsUpdated(json) {
      if (json && json.length > 2) {
        try {
          var list = JSON.parse(json);
          if (list && list.length > 0) modal.platforms = list;
        } catch(e) {}
      }
    }
  }

  Component.onCompleted: {
    loadPlatforms(false);
  }

  function openModal(initialPlatform) {
    loadPlatforms(true);
    stepName = "providers";
    searchQuery = "";
    selectedPlatform = null;
    selectedMethod = null;
    isTesting = false;
    testMessage = "";
    testSuccess = false;
    showSecret = false;

    nameField.text = "";
    endpointField.text = "";
    bucketField.text = "";
    keyField.text = "";
    secretField.text = "";
    twofaField.text = "";
    mailboxPassField.text = "";
    mountPointField.text = "~/Storage";
    modal.visible = true;

    if (initialPlatform) {
      var p = platforms.find(function(item) {
        return item.id === initialPlatform.toLowerCase();
      });
      if (p) selectPlatform(p);
    }
  }

  function selectPlatform(p) {
    selectedPlatform = p;
    testMessage = "";
    testSuccess = false;

    if (p.methods && p.methods.length > 0) {
      stepName = "methods";
    } else {
      applyPlatformDefaults(p);
      stepName = "config";
    }
  }

  function selectMethod(m) {
    selectedMethod = m;
    applyPlatformDefaults(m);
    stepName = "config";
  }

  function applyPlatformDefaults(target) {
    nameField.text = target.defaultRemoteName || target.defaultName || target.name || "Storage";
    mountPointField.text = target.defaultMount || (selectedPlatform ? selectedPlatform.defaultMount || "~/Storage" : "~/Storage");

    if (target.fields) {
      var epField = target.fields.find(function(f) { return f.key === "endpoint"; });
      if (epField && epField.default) endpointField.text = epField.default;
      else if (target.endpointPlaceholder && target.endpointPlaceholder.indexOf("http") === 0) endpointField.text = target.endpointPlaceholder;
      else endpointField.text = "";
    } else {
      endpointField.text = "";
    }

    bucketField.text = "";
    keyField.text = "";
    secretField.text = "";
    twofaField.text = "";
    mailboxPassField.text = "";
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block modal background clicks
  }

  // ========================================================
  // COMPACT & RESPONSIVE ASSISTANT DIALOG (1/2 and 1/4 View)
  // ========================================================
  Rectangle {
    id: assistantWindow
    width: Math.min(parent.width - 24, 600)
    height: Math.min(parent.height - 24, 520)
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.min(theme.cornerRadius, 6) : 4
    color: modal.windowBg
    border.color: modal.borderCol
    border.width: 1
    anchors.centerIn: parent
    clip: true

    ColumnLayout {
      anchors.fill: parent
      spacing: 0

      // ====================================================
      // DIALOG HEADER (Title + Back + Close)
      // ====================================================
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 48
        color: modal.cardAltColor
        border.color: modal.borderCol
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 14
          anchors.rightMargin: 14
          spacing: 10

          // Back Button (if on steps after providers)
          Rectangle {
            visible: modal.stepName !== "providers"
            implicitWidth: 26
            implicitHeight: 26
            radius: 2
            color: backMouse.containsMouse ? modal.borderCol : "transparent"

            Text {
              anchors.centerIn: parent
              text: "←"
              font.pixelSize: 14
              font.bold: true
              color: modal.textColor
            }

            MouseArea {
              id: backMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (modal.stepName === "config" && modal.hasMethods) {
                  modal.stepName = "methods";
                } else {
                  modal.stepName = "providers";
                  modal.selectedPlatform = null;
                  modal.selectedMethod = null;
                }
              }
            }
          }

          ThemeIcon {
            visible: !!modal.selectedPlatform && modal.stepName !== "providers"
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            Layout.alignment: Qt.AlignVCenter
            source: (modal.selectedPlatform && modal.selectedPlatform.iconDataUri && modal.selectedPlatform.iconDataUri.length > 0)
              ? modal.selectedPlatform.iconDataUri
              : (modal.selectedPlatform ? Qt.resolvedUrl(modal.selectedPlatform.iconSvg || "../icons/cloud.svg") : "")
            color: modal.accentColor
          }

          Text {
            Layout.fillWidth: true
            text: modal.stepName === "providers" ? "Add Storage Provider" :
                  modal.stepName === "methods" ? (modal.selectedPlatform ? modal.selectedPlatform.name : "Select Connection Method") :
                  ("Connect " + (modal.selectedMethod ? modal.selectedMethod.name : (modal.selectedPlatform ? modal.selectedPlatform.name : "Storage")))
            font.family: modal.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: modal.textColor
            elide: Text.ElideRight
          }

          // Close Button ✕
          Rectangle {
            implicitWidth: 26
            implicitHeight: 26
            radius: 2
            color: closeMouse.containsMouse ? modal.borderCol : "transparent"

            Text {
              anchors.centerIn: parent
              text: "✕"
              font.pixelSize: 12
              color: closeMouse.containsMouse ? modal.accentColor : modal.mutedColor
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: modal.visible = false
            }
          }
        }
      }

      // ====================================================
      // STEP 1: SELECT PROVIDER LIST / GRID
      // ====================================================
      ColumnLayout {
        visible: modal.stepName === "providers"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 14
        spacing: 12

        // Filter / Search Input
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 32
          radius: 2
          color: modal.cardAltColor
          border.color: searchInput.activeFocus ? modal.accentColor : modal.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              text: "⌕"
              font.pixelSize: 14
              color: modal.mutedColor
            }

            TextInput {
              id: searchInput
              Layout.fillWidth: true
              font.family: modal.appFontFamily
              font.pixelSize: 12
              color: modal.textColor
              text: modal.searchQuery
              onTextChanged: modal.searchQuery = text.trim().toLowerCase()
              clip: true

              Text {
                text: "Search storage providers (S3, Mega, Koofr, Filen, Box, Wasabi...)"
                font.family: modal.appFontFamily
                font.pixelSize: 11
                color: modal.mutedColor
                visible: !searchInput.text && !searchInput.activeFocus
              }
            }
          }
        }

        // Providers Scroll Grid
        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentWidth: availableWidth

          Grid {
            width: parent.width
            columns: parent.width > 420 ? 2 : 1
            columnSpacing: 8
            rowSpacing: 8

            readonly property var filteredList: modal.platforms.filter(function(p) {
              if (!modal.searchQuery) return true;
              return p.name.toLowerCase().includes(modal.searchQuery) ||
                     p.id.toLowerCase().includes(modal.searchQuery) ||
                     (p.tagline && p.tagline.toLowerCase().includes(modal.searchQuery));
            })

            Repeater {
              model: parent.filteredList

              delegate: Rectangle {
                width: parent.width > 420 ? Math.floor((parent.width - 8) / 2) : parent.width
                implicitHeight: 52
                radius: 2
                color: tileMouse.containsMouse ? modal.cardAltColor : modal.cardColor
                border.color: tileMouse.containsMouse ? modal.accentColor : modal.borderCol
                border.width: 1

                MouseArea {
                  id: tileMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: modal.selectPlatform(modelData)
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 12
                  spacing: 10

                  // Monochrome Icon (Theme-reactive)
                  ThemeIcon {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    source: (modelData.iconDataUri && modelData.iconDataUri.length > 0)
                      ? modelData.iconDataUri
                      : Qt.resolvedUrl(modelData.iconSvg || "../icons/cloud.svg")
                    color: tileMouse.containsMouse ? modal.accentColor : modal.textColor
                  }

                  // Provider Name (Zero badges)
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                      text: modelData.name
                      font.family: modal.appFontFamily
                      font.pixelSize: 12
                      font.bold: true
                      color: tileMouse.containsMouse ? modal.accentColor : modal.textColor
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      text: modelData.category === "personal" ? "Personal Cloud" : "Object Storage"
                      font.family: modal.appFontFamily
                      font.pixelSize: 9
                      color: modal.mutedColor
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  Text {
                    text: "→"
                    font.pixelSize: 12
                    color: tileMouse.containsMouse ? modal.accentColor : modal.mutedColor
                  }
                }
              }
            }
          }
        }
      }

      // ====================================================
      // STEP 1.5: METHOD SELECTION (MEGA, pCloud, etc.)
      // ====================================================
      ColumnLayout {
        visible: modal.stepName === "methods"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 16
        spacing: 12

        Text {
          text: "CHOOSE CONNECTION METHOD"
          font.family: modal.appFontFamily
          font.pixelSize: 11
          font.bold: true
          font.letterSpacing: 1
          color: modal.mutedColor
        }

        Repeater {
          model: (modal.selectedPlatform && modal.selectedPlatform.methods) ? modal.selectedPlatform.methods : []

          delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: 56
            radius: 2
            color: mMouse.containsMouse ? modal.cardAltColor : modal.cardColor
            border.color: mMouse.containsMouse ? modal.accentColor : modal.borderCol
            border.width: 1

            MouseArea {
              id: mMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: modal.selectMethod(modelData)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 14
              anchors.rightMargin: 14
              spacing: 12

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                  text: modelData.name
                  font.family: modal.appFontFamily
                  font.pixelSize: 12
                  font.bold: true
                  color: mMouse.containsMouse ? modal.accentColor : modal.textColor
                }

                Text {
                  text: modelData.description || ""
                  font.family: modal.appFontFamily
                  font.pixelSize: 10
                  color: modal.mutedColor
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              Text {
                text: "Select →"
                font.family: modal.appFontFamily
                font.pixelSize: 11
                color: mMouse.containsMouse ? modal.accentColor : modal.mutedColor
              }
            }
          }
        }

        Item { Layout.fillHeight: true }
      }

      // ====================================================
      // STEP 2: CREDENTIALS & MOUNT CONFIGURATION
      // ====================================================
      ColumnLayout {
        visible: modal.stepName === "config"
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 16
        spacing: 10

        ScrollView {
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          contentWidth: availableWidth

          ColumnLayout {
            width: parent.width
            spacing: 10

            // Instructions text (short & direct)
            Text {
              visible: !!modal.selectedPlatform && !!modal.selectedPlatform.step1Desc
              text: modal.selectedPlatform ? modal.selectedPlatform.step1Desc : ""
              font.family: modal.appFontFamily
              font.pixelSize: 11
              color: modal.mutedColor
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            // OAuth Info Prompt
            Rectangle {
              visible: modal.isOAuth
              Layout.fillWidth: true
              implicitHeight: oauthMsg.implicitHeight + 20
              radius: 2
              color: modal.cardAltColor
              border.color: modal.borderCol
              border.width: 1

              Text {
                id: oauthMsg
                anchors.fill: parent
                anchors.margins: 10
                text: "OAuth 2.0 Web Authentication:\nClicking 'Mount Drive' will open your browser to authorize Ocloud."
                font.family: modal.appFontFamily
                font.pixelSize: 11
                color: modal.textColor
                wrapMode: Text.WordWrap
              }
            }

            // Endpoint URL Field (S3 / WebDAV)
            ColumnLayout {
              visible: modal.isS3 || modal.isWebdav
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: (modal.selectedPlatform && modal.selectedPlatform.endpointLabel) ? modal.selectedPlatform.endpointLabel : "Endpoint URL"
                font.family: modal.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: modal.mutedColor
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 2
                color: modal.cardAltColor
                border.color: endpointField.activeFocus ? modal.accentColor : modal.borderCol
                border.width: 1

                TextInput {
                  id: endpointField
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: modal.appFontFamily
                  font.pixelSize: 11
                  color: modal.textColor
                  clip: true
                }
              }
            }

            // Bucket Name Field (S3)
            ColumnLayout {
              visible: modal.isS3
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: "Bucket Name (Optional, leave empty for all)"
                font.family: modal.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: modal.mutedColor
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 2
                color: modal.cardAltColor
                border.color: bucketField.activeFocus ? modal.accentColor : modal.borderCol
                border.width: 1

                TextInput {
                  id: bucketField
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: modal.appFontFamily
                  font.pixelSize: 11
                  color: modal.textColor
                  clip: true
                }
              }
            }

            // Access Key / Username Field
            ColumnLayout {
              visible: !modal.isOAuth
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: (modal.selectedPlatform && modal.selectedPlatform.keyLabel)
                  ? modal.selectedPlatform.keyLabel
                  : (modal.isS3 ? "Access Key ID" : "Account Email / Username")
                font.family: modal.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: modal.mutedColor
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 2
                color: modal.cardAltColor
                border.color: keyField.activeFocus ? modal.accentColor : modal.borderCol
                border.width: 1

                TextInput {
                  id: keyField
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: modal.appFontFamily
                  font.pixelSize: 11
                  color: modal.textColor
                  clip: true
                }
              }
            }

            // Secret Key / Password Field
            ColumnLayout {
              visible: !modal.isOAuth
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: (modal.selectedPlatform && modal.selectedPlatform.secretLabel)
                  ? modal.selectedPlatform.secretLabel
                  : (modal.isS3 ? "Secret Access Key" : "Account Password / App Password")
                font.family: modal.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: modal.mutedColor
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 2
                color: modal.cardAltColor
                border.color: secretField.activeFocus ? modal.accentColor : modal.borderCol
                border.width: 1

                TextInput {
                  id: secretField
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 30
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: modal.appFontFamily
                  font.pixelSize: 11
                  color: modal.textColor
                  echoMode: modal.showSecret ? TextInput.Normal : TextInput.Password
                  clip: true
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: 8
                  anchors.verticalCenter: parent.verticalCenter
                  text: modal.showSecret ? "Hide" : "Show"
                  font.family: modal.appFontFamily
                  font.pixelSize: 10
                  color: modal.mutedColor

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modal.showSecret = !modal.showSecret
                  }
                }
              }
            }

            // 2FA / OTP Field (Optional, for Filen/Proton)
            ColumnLayout {
              visible: modal.selectedPlatform && (modal.selectedPlatform.id === "filen" || modal.selectedPlatform.id === "protondrive")
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: "2FA / TOTP Code (Optional)"
                font.family: modal.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: modal.mutedColor
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 2
                color: modal.cardAltColor
                border.color: twofaField.activeFocus ? modal.accentColor : modal.borderCol
                border.width: 1

                TextInput {
                  id: twofaField
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: modal.appFontFamily
                  font.pixelSize: 11
                  color: modal.textColor
                  clip: true
                }
              }
            }

            // Mount Location Field
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3

              Text {
                text: "Mount Folder Location"
                font.family: modal.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: modal.mutedColor
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 2
                color: modal.cardAltColor
                border.color: mountPointField.activeFocus ? modal.accentColor : modal.borderCol
                border.width: 1

                TextInput {
                  id: mountPointField
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  verticalAlignment: TextInput.AlignVCenter
                  font.family: modal.appFontFamily
                  font.pixelSize: 11
                  color: modal.textColor
                  clip: true
                }
              }
            }

            // Hidden nameField for internal identifier
            TextInput {
              id: nameField
              visible: false
            }
            TextInput {
              id: mailboxPassField
              visible: false
            }

            // Status / Error message display
            Text {
              visible: modal.testMessage.length > 0
              text: modal.testMessage
              font.family: modal.appFontFamily
              font.pixelSize: 11
              color: modal.testSuccess
                ? ((typeof theme !== "undefined" && theme.green) ? theme.green : modal.accentColor)
                : ((typeof theme !== "undefined" && theme.red) ? theme.red : "#ff5555")
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }

        // Action Buttons Row (100% Theme Colors)
        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Rectangle {
            implicitWidth: cancelText.implicitWidth + 20
            implicitHeight: 32
            radius: 2
            color: cancelMouse.containsMouse ? modal.borderCol : "transparent"
            border.color: modal.borderCol
            border.width: 1

            Text {
              id: cancelText
              anchors.centerIn: parent
              text: "Cancel"
              font.family: modal.appFontFamily
              font.pixelSize: 11
              font.bold: true
              color: modal.textColor
            }

            MouseArea {
              id: cancelMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: modal.visible = false
            }
          }

          Item { Layout.fillWidth: true }

          // Mount Button
          Rectangle {
            implicitWidth: mountText.implicitWidth + 24
            implicitHeight: 32
            radius: 2
            color: modal.isTesting
              ? modal.borderCol
              : (mountMouse.containsMouse ? Qt.darker(modal.accentColor, 1.2) : modal.accentColor)

            Text {
              id: mountText
              anchors.centerIn: parent
              text: modal.isTesting ? "Mounting..." : "Mount Drive →"
              font.family: modal.appFontFamily
              font.pixelSize: 11
              font.bold: true
              color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
            }

            MouseArea {
              id: mountMouse
              anchors.fill: parent
              enabled: !modal.isTesting
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: modal.executeMount()
            }
          }
        }
      }
    }
  }

  // ========================================================
  // MOUNT DISPATCH LOGIC (PRESERVED & VERIFIED)
  // ========================================================
  function executeMount() {
    modal.isTesting = true;
    modal.testMessage = "Verifying credentials and mounting drive...";

    var platform = modal.selectedPlatform;
    var method = modal.selectedMethod;
    var sName = nameField.text.trim() || (method ? method.defaultRemoteName : (platform ? platform.defaultRemoteName : "Storage"));
    var mPath = mountPointField.text.trim() || (method ? method.defaultMount : (platform ? platform.defaultMount : "~/Storage"));
    var rType = method ? (method.rcloneType || method.authType) : (platform ? (platform.rcloneType || platform.authType) : "");
    var aType = method ? method.authType : (platform ? platform.authType : "");

    function handleResult(ok, msg) {
      modal.isTesting = false;
      if (ok) {
        modal.testSuccess = true;
        modal.testMessage = "Drive successfully mounted!";
        modal.storageAdded();
        modal.visible = false;
      } else {
        modal.testSuccess = false;
        modal.testMessage = "Mount Failed: " + (msg || "Unknown error verifying mount point");
      }
    }

    if (modal.isOAuth) {
      var remoteName = (method && method.defaultRemoteName) ? method.defaultRemoteName : platform.defaultRemoteName;
      ocloud.mountCloudAccount(remoteName, mPath, handleResult);
    } else if (rType === "protondrive" || (platform && platform.id === "protondrive")) {
      ocloud.addProtonDriveStorage(sName, keyField.text.trim(), secretField.text.trim(), twofaField.text.trim(), mailboxPassField.text.trim(), mPath, handleResult);
    } else if (rType === "mega" || (method && method.rcloneType === "mega") || (platform && platform.id === "mega" && rType === "mega")) {
      ocloud.addMegaStorage(sName, keyField.text.trim(), secretField.text.trim(), mPath, handleResult);
    } else if (rType === "koofr" || (method && method.rcloneType === "koofr") || (platform && platform.id === "koofr")) {
      ocloud.addKoofrStorage(sName, keyField.text.trim(), secretField.text.trim(), mPath, handleResult);
    } else if (rType === "filen" || (method && method.rcloneType === "filen") || (platform && platform.id === "filen")) {
      ocloud.addFilenStorage(sName, keyField.text.trim(), secretField.text.trim(), twofaField.text.trim(), mPath, handleResult);
    } else if (aType === "webdav" || rType === "webdav") {
      var vendor = (method && method.vendor) ? method.vendor : (platform ? platform.vendor || "" : "");
      ocloud.addWebdavStorage(sName, endpointField.text.trim(), keyField.text.trim(), secretField.text.trim(), vendor, mPath, handleResult);
    } else if (aType === "s3" || (platform && platform.type === "s3")) {
      ocloud.addS3Storage(sName, endpointField.text.trim(), bucketField.text.trim(), keyField.text.trim(), secretField.text.trim(), mPath, handleResult);
    } else if (aType === "sftp" || (platform && platform.type === "sftp")) {
      ocloud.addSftpStorage(sName, endpointField.text.trim(), keyField.text.trim(), secretField.text.trim(), mPath, handleResult);
    } else {
      modal.isTesting = false;
      modal.testMessage = "Unknown storage provider configuration";
    }
  }
}
