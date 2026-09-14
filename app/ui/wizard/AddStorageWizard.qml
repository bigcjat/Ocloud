import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
  id: modal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.78)
  z: 1500

  signal storageAdded()

  property string stepName: "providers" // "providers", "method", "walkthrough", "credentials", "mount"
  readonly property int currentStep: stepName === "providers" ? 1 : (stepName === "method" ? 2 : (stepName === "walkthrough" ? (hasMethods ? 3 : 2) : (stepName === "credentials" ? (hasMethods ? 4 : 3) : (hasMethods ? 5 : 4))))
  property var selectedPlatform: null
  property var selectedMethod: null
  property bool isTesting: false
  property string testMessage: ""
  property bool testSuccess: false
  property bool showSecret: false

  readonly property bool hasMethods: !!(modal.selectedPlatform && modal.selectedPlatform.methods && modal.selectedPlatform.methods.length > 0)
  readonly property var activePlatformOrMethod: modal.selectedMethod || modal.selectedPlatform
  readonly property bool isOAuth: !!(modal.activePlatformOrMethod && (modal.activePlatformOrMethod.authType === "oauth" || modal.activePlatformOrMethod.type === "oauth"))
  readonly property bool isApp: !!(modal.activePlatformOrMethod && (modal.activePlatformOrMethod.authType === "app" || modal.activePlatformOrMethod.type === "app"))
  readonly property bool isDirectLogin: !!(modal.activePlatformOrMethod && (modal.activePlatformOrMethod.authType === "credentials" || modal.activePlatformOrMethod.id === "protondrive"))

  property var platforms: []

  function getActiveStepDesc(stepNum) {
    if (selectedMethod && selectedMethod.instructions && selectedMethod.instructions["step" + stepNum]) {
      return selectedMethod.instructions["step" + stepNum];
    }
    if (selectedPlatform) {
      if (selectedPlatform["step" + stepNum + "Desc"]) return selectedPlatform["step" + stepNum + "Desc"];
      if (selectedPlatform.instructions && selectedPlatform.instructions["step" + stepNum]) return selectedPlatform.instructions["step" + stepNum];
    }
    return "";
  }

  function getActiveBreadcrumb() {
    if (selectedMethod && selectedMethod.instructions && selectedMethod.instructions.navBreadcrumb) {
      return selectedMethod.instructions.navBreadcrumb;
    }
    if (selectedPlatform) {
      if (selectedPlatform.navBreadcrumb) return selectedPlatform.navBreadcrumb;
      if (selectedPlatform.instructions && selectedPlatform.instructions.navBreadcrumb) return selectedPlatform.instructions.navBreadcrumb;
    }
    return "";
  }

  function getActiveField(key) {
    if (selectedMethod && selectedMethod.fields) {
      for (var i = 0; i < selectedMethod.fields.length; i++) {
        if (selectedMethod.fields[i].key === key) return selectedMethod.fields[i];
      }
    }
    if (selectedPlatform && selectedPlatform.fields) {
      for (var j = 0; j < selectedPlatform.fields.length; j++) {
        if (selectedPlatform.fields[j].key === key) return selectedPlatform.fields[j];
      }
    }
    return null;
  }

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
    mountPointField.text = "~/R2";
    modal.visible = true;

    if (initialPlatform) {
      var parts = initialPlatform.split(':');
      var target = parts[0].toLowerCase();
      var desiredMethod = parts[1] || "";
      var desiredStep = parts[2] || "";
      var p = platforms.find(function(item) {
        return item.id === target ||
               item.id.replace('_', '-') === target ||
               item.id.replace('-', '_') === target ||
               (item.name && item.name.toLowerCase() === target);
      });
      if (p) {
        selectPlatform(p);
        if (desiredMethod && p.methods) {
          var m = p.methods.find(function(mItem) { return mItem.id === desiredMethod; });
          if (m) selectMethod(m);
        }
        if (desiredStep) {
          stepName = desiredStep;
        }
      }
    }
  }

  function selectPlatform(p) {
    selectedPlatform = p;
    if (p.methods && p.methods.length > 0) {
      selectMethod(p.methods[0]);
      stepName = "method";
    } else if (p.authType === "credentials" || p.id === "protondrive") {
      selectedMethod = null;
      nameField.text = p.defaultName || p.name;
      mountPointField.text = p.defaultMount || "~/Storage";
      endpointField.text = "";
      bucketField.text = "";
      keyField.text = "";
      secretField.text = "";
      twofaField.text = "";
      mailboxPassField.text = "";
      stepName = "credentials";
    } else {
      selectedMethod = null;
      nameField.text = p.defaultName || p.name;
      mountPointField.text = p.defaultMount || "~/Storage";
      endpointField.text = (p.endpointPlaceholder && p.endpointPlaceholder.indexOf("http") === 0) ? p.endpointPlaceholder : "";
      bucketField.text = "";
      keyField.text = "";
      secretField.text = "";
      twofaField.text = "";
      mailboxPassField.text = "";
      stepName = "walkthrough";
    }
    testMessage = "";
    testSuccess = false;
  }

  function selectMethod(m) {
    selectedMethod = m;
    nameField.text = m.defaultRemoteName || (selectedPlatform ? selectedPlatform.defaultName || selectedPlatform.name : "Storage");
    mountPointField.text = m.defaultMount || (selectedPlatform ? selectedPlatform.defaultMount || "~/Storage" : "~/Storage");
    endpointField.text = (m.fields && m.fields[0] && m.fields[0].default) ? m.fields[0].default : "";
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
  // MAIN SETUP ASSISTANT DIALOG (Apple / macOS Grade)
  // ========================================================
  Rectangle {
    id: assistantWindow
    width: Math.min(parent.width - 16, 900)
    height: Math.min(parent.height - 16, 620)
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 12
    color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#080e1a"
    border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#1e293b"
    border.width: 1.5
    anchors.centerIn: parent
    clip: true

    RowLayout {
      anchors.fill: parent
      spacing: 0

      // ====================================================
      // LEFT SIDEBAR: PROGRESS & CONTEXT (Responsive)
      // ====================================================
      Rectangle {
        visible: parent.width >= 560
        Layout.fillHeight: true
        Layout.preferredWidth: parent.width < 750 ? 56 : 230
        color: "#060a14"
        border.color: "#151d2d"
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          // Header: Setup Assistant Emblem
          RowLayout {
            spacing: 12

            Rectangle {
              Layout.preferredWidth: 38
              Layout.preferredHeight: 38
              radius: 10
              gradient: Gradient {
                GradientStop { position: 0.0; color: "#0284c7" }
                GradientStop { position: 1.0; color: "#0369a1" }
              }

              Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: Qt.resolvedUrl("../icons/cloud.svg")
                fillMode: Image.PreserveAspectFit
              }
            }

            ColumnLayout {
              spacing: 1
              Text {
                text: "Setup Assistant"
                font.pixelSize: 14
                font.bold: true
                color: "#f8fafc"
              }
              Text {
                text: "Add Storage Device"
                font.pixelSize: 11
                color: "#64748b"
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#151d2d"
          }

          // Vertical Progress Stepper with Line
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Connected Vertical Line
            Rectangle {
              x: 15
              y: 18
              width: 2
              height: 180
              color: "#1e293b"
            }

            ColumnLayout {
              anchors.fill: parent
              spacing: 20

              // Step 1: Storage Provider
              RowLayout {
                spacing: 12
                Rectangle {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30
                  radius: 15
                  color: modal.stepName === "providers" ? "#0284c7" : "#10b981"
                  border.color: modal.stepName === "providers" ? "#38bdf8" : "#10b981"
                  border.width: modal.stepName === "providers" ? 2 : 1

                  Text {
                    anchors.centerIn: parent
                    text: modal.stepName !== "providers" ? "✓" : "1"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#ffffff"
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text {
                    text: "Storage Provider"
                    font.pixelSize: 12
                    font.bold: modal.stepName === "providers"
                    color: modal.stepName === "providers" ? "#38bdf8" : "#f8fafc"
                  }
                  Text {
                    text: modal.selectedPlatform ? modal.selectedPlatform.name : "Choose cloud provider"
                    font.pixelSize: 10
                    color: modal.stepName === "providers" ? "#94a3b8" : "#475569"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                  }
                }
              }

              // Step 2 (Conditional): Connection Method
              RowLayout {
                spacing: 12
                visible: modal.hasMethods
                Rectangle {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30
                  radius: 15
                  color: modal.stepName === "method" ? "#0284c7" : (modal.stepName !== "providers" && modal.stepName !== "method" ? "#10b981" : "#0d1526")
                  border.color: modal.stepName === "method" ? "#38bdf8" : (modal.stepName !== "providers" && modal.stepName !== "method" ? "#10b981" : "#1e293b")
                  border.width: modal.stepName === "method" ? 2 : 1

                  Text {
                    anchors.centerIn: parent
                    text: (modal.stepName !== "providers" && modal.stepName !== "method") ? "✓" : "2"
                    font.pixelSize: 12
                    font.bold: true
                    color: (modal.stepName !== "providers") ? "#ffffff" : "#64748b"
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text {
                    text: "Connection Method"
                    font.pixelSize: 12
                    font.bold: modal.stepName === "method"
                    color: modal.stepName === "method" ? "#38bdf8" : ((modal.stepName !== "providers" && modal.stepName !== "method") ? "#f8fafc" : "#64748b")
                  }
                  Text {
                    text: modal.selectedMethod ? modal.selectedMethod.name : "Choose method"
                    font.pixelSize: 10
                    color: modal.stepName === "method" ? "#94a3b8" : "#475569"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 140
                  }
                }
              }

              // Step 3 (or 2): Account Setup / Authorization
              RowLayout {
                spacing: 12
                visible: !modal.isDirectLogin
                Rectangle {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30
                  radius: 15
                  color: modal.stepName === "walkthrough" ? "#0284c7" : (modal.stepName === "credentials" || modal.stepName === "mount" ? "#10b981" : "#0d1526")
                  border.color: modal.stepName === "walkthrough" ? "#38bdf8" : (modal.stepName === "credentials" || modal.stepName === "mount" ? "#10b981" : "#1e293b")
                  border.width: modal.stepName === "walkthrough" ? 2 : 1

                  Text {
                    anchors.centerIn: parent
                    text: (modal.stepName === "credentials" || modal.stepName === "mount") ? "✓" : (modal.hasMethods ? "3" : "2")
                    font.pixelSize: 12
                    font.bold: true
                    color: (modal.stepName === "walkthrough" || modal.stepName === "credentials" || modal.stepName === "mount") ? "#ffffff" : "#64748b"
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text {
                    text: modal.isOAuth ? "Account Sign-In" : (modal.isApp ? "Client Setup" : "Walkthrough")
                    font.pixelSize: 12
                    font.bold: modal.stepName === "walkthrough"
                    color: modal.stepName === "walkthrough" ? "#38bdf8" : (modal.stepName === "credentials" || modal.stepName === "mount" ? "#f8fafc" : "#64748b")
                  }
                  Text {
                    text: modal.isOAuth ? "Browser authorization" : (modal.isApp ? "Desktop instructions" : "Guided credentials")
                    font.pixelSize: 10
                    color: modal.stepName === "walkthrough" ? "#94a3b8" : "#475569"
                  }
                }
              }

              // Step 4 (or 3/2): Enter Credentials (only if not OAuth and not App)
              RowLayout {
                spacing: 12
                visible: !modal.isOAuth && !modal.isApp
                Rectangle {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30
                  radius: 15
                  color: modal.stepName === "credentials" ? "#0284c7" : (modal.stepName === "mount" ? "#10b981" : "#0d1526")
                  border.color: modal.stepName === "credentials" ? "#38bdf8" : (modal.stepName === "mount" ? "#10b981" : "#1e293b")
                  border.width: modal.stepName === "credentials" ? 2 : 1

                  Text {
                    anchors.centerIn: parent
                    text: modal.stepName === "mount" ? "✓" : (modal.isDirectLogin ? "2" : (modal.hasMethods ? "4" : "3"))
                    font.pixelSize: 12
                    font.bold: true
                    color: (modal.stepName === "credentials" || modal.stepName === "mount") ? "#ffffff" : "#64748b"
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text {
                    text: modal.isDirectLogin ? "Account Sign-In" : "Enter Credentials"
                    font.pixelSize: 12
                    font.bold: modal.stepName === "credentials"
                    color: modal.stepName === "credentials" ? "#38bdf8" : (modal.stepName === "mount" ? "#f8fafc" : "#64748b")
                  }
                  Text {
                    text: modal.isDirectLogin ? "Proton login & 2FA" : "Local encryption"
                    font.pixelSize: 10
                    color: modal.stepName === "credentials" ? "#94a3b8" : "#475569"
                  }
                }
              }

              // Final Step: Drive & Mount
              RowLayout {
                spacing: 12
                Rectangle {
                  Layout.preferredWidth: 30
                  Layout.preferredHeight: 30
                  radius: 15
                  color: modal.stepName === "mount" ? "#0284c7" : "#0d1526"
                  border.color: modal.stepName === "mount" ? "#38bdf8" : "#1e293b"
                  border.width: modal.stepName === "mount" ? 2 : 1

                  Text {
                    anchors.centerIn: parent
                    text: modal.isDirectLogin ? "3" : (modal.hasMethods ? (modal.isOAuth || modal.isApp ? "4" : "5") : (modal.isOAuth || modal.isApp ? "3" : "4"))
                    font.pixelSize: 12
                    font.bold: true
                    color: modal.stepName === "mount" ? "#ffffff" : "#64748b"
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text {
                    text: "Drive & Mount"
                    font.pixelSize: 12
                    font.bold: modal.stepName === "mount"
                    color: modal.stepName === "mount" ? "#38bdf8" : "#64748b"
                  }
                  Text {
                    text: "Local destination folder"
                    font.pixelSize: 10
                    color: modal.stepName === "mount" ? "#94a3b8" : "#475569"
                  }
                }
              }

              Item { Layout.fillHeight: true }
            }
          }

          // Bottom Native Drive Helper Tip
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: tipCol.implicitHeight + 20
            radius: 10
            color: "#0a1322"
            border.color: "#18263e"

            ColumnLayout {
              id: tipCol
              anchors.fill: parent
              anchors.margins: 12
              spacing: 4

              RowLayout {
                spacing: 6
                Text { text: "💡"; font.pixelSize: 12 }
                Text {
                  text: "Native File System"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#38bdf8"
                }
              }
              Text {
                Layout.fillWidth: true
                text: "Drives appear directly in your file manager. Drag and drop files just like a physical local disk."
                font.pixelSize: 10
                color: "#64748b"
                wrapMode: Text.WordWrap
              }
            }
          }
        }
      }

      // ====================================================
      // RIGHT WORKSPACE: DYNAMIC CONTENT PANEL (550px)
      // ====================================================
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredWidth: 0
        Layout.fillHeight: true
        color: "transparent"

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 24
          spacing: 16

          // Workspace Header
          RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Provider Icon when selected
            Rectangle {
              visible: modal.stepName !== "providers" && !!modal.selectedPlatform
              Layout.preferredWidth: 36
              Layout.preferredHeight: 36
              radius: 9
              color: "#0e1828"
              border.color: modal.selectedPlatform ? (modal.selectedPlatform.brandColor || "#0284c7") : "#1e293b"

              Image {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: (modal.selectedPlatform && modal.selectedPlatform.iconDataUri && modal.selectedPlatform.iconDataUri.length > 0) ? modal.selectedPlatform.iconDataUri : (modal.selectedPlatform ? Qt.resolvedUrl(modal.selectedPlatform.iconSvg || "../icons/cloud.svg") : "")
                fillMode: Image.PreserveAspectFit
              }
            }

            ColumnLayout {
              spacing: 2
              Text {
                text: modal.stepName === "providers" ? "Select Storage Provider" :
                      modal.stepName === "method" ? ("Connect to " + (modal.selectedPlatform ? modal.selectedPlatform.name : "Storage")) :
                      modal.stepName === "walkthrough" ? ("Setup " + (modal.selectedPlatform ? modal.selectedPlatform.name : "")) :
                      modal.stepName === "credentials" ? (modal.isDirectLogin ? ("Sign In to " + (modal.selectedPlatform ? modal.selectedPlatform.name : "Account")) : "Authentication & Credentials") :
                      "Drive Preview & Confirmation"
                font.pixelSize: 17
                font.bold: true
                color: "#f8fafc"
              }
              Text {
                text: modal.stepName === "providers" ? "Choose cloud object storage or personal sync account to mount" :
                      modal.stepName === "method" ? "Choose how you'd like to connect. Different methods support different regions & protocols." :
                      modal.stepName === "walkthrough" ? (modal.isOAuth ? "Authorize Ocloud via standard browser sign-in" : (modal.isApp ? "Official desktop client setup instructions" : "Follow this 60-second walkthrough to get your access credentials")) :
                      modal.stepName === "credentials" ? (modal.isDirectLogin ? "Enter your Proton username, password, and optional 2FA code to mount your drive via rclone." : "Enter your keys to securely connect to your storage bucket") :
                      "Review drive name and choose where files will mount on your system"
                font.pixelSize: 12
                color: "#94a3b8"
              }
            }

            Item { Layout.fillWidth: true }

            // Close Button
            Rectangle {
              width: 28
              height: 28
              radius: 14
              color: closeMouse.containsMouse ? "#1e293b" : "transparent"

              Text {
                anchors.centerIn: parent
                text: "✕"
                font.pixelSize: 13
                color: "#94a3b8"
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

          // Horizontal Divider
          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#151d2d"
          }

          // ==============================================
          // STEP 1: SELECT PROVIDER TILES
          // ==============================================
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: modal.stepName === "providers"

            ScrollView {
              anchors.fill: parent
              clip: true
              contentWidth: availableWidth
              ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

              ColumnLayout {
                width: parent.width
                spacing: 12

                Text {
                  text: "PERSONAL CLOUD (SIGN IN WITH ACCOUNT)"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#64748b"
                }

                // Personal Cloud 2-column Grid (OAuth)
                Grid {
                  Layout.fillWidth: true
                  columns: 2
                  columnSpacing: 12
                  rowSpacing: 12

                  Repeater {
                    model: modal.platforms.filter(p => p.category === "personal")
                    delegate: Rectangle {
                      width: Math.floor((assistantWindow.width - 230 - 48 - 12) / 2)
                      height: 84
                      radius: 10
                      color: pMouse.containsMouse ? "#111c30" : "#0c1322"
                      border.color: pMouse.containsMouse ? (modelData.brandColor || "#38bdf8") : "#1b253b"
                      border.width: 1

                      MouseArea {
                        id: pMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modal.selectPlatform(modelData)
                      }

                      RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // Brand Icon
                        Rectangle {
                          Layout.preferredWidth: 38
                          Layout.preferredHeight: 38
                          radius: 8
                          color: "#070c18"
                          border.color: "#1e293b"

                          Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : Qt.resolvedUrl(modelData.iconSvg || "../icons/cloud.svg")
                            fillMode: Image.PreserveAspectFit
                          }
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 3

                          Text {
                            text: modelData.name
                            font.pixelSize: 13
                            font.bold: true
                            color: "#f8fafc"
                          }

                          RowLayout {
                            spacing: 4
                            Rectangle {
                              height: 16
                              radius: 8
                              color: Qt.rgba(0.02, 0.52, 0.78, 0.2)
                              border.color: modelData.badgeColor || "#0284c7"
                              border.width: 1
                              width: bText.implicitWidth + 8

                              Text {
                                id: bText
                                anchors.centerIn: parent
                                text: modelData.badge || "OAuth"
                                font.pixelSize: 9
                                font.bold: true
                                color: modelData.badgeColor || "#38bdf8"
                              }
                            }
                          }

                          Text {
                            text: modelData.tagline
                            font.pixelSize: 10
                            color: "#94a3b8"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            maximumLineCount: 2
                            elide: Text.ElideRight
                          }
                        }

                        Text {
                          text: "›"
                          font.pixelSize: 18
                          font.bold: true
                          color: pMouse.containsMouse ? "#38bdf8" : "#475569"
                        }
                      }
                    }
                  }
                }

                Item { height: 4 }

                Text {
                  text: "CLOUD OBJECT STORAGE & BUCKETS (API KEYS)"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#64748b"
                }

                // Cloud Object Storage 2-column Grid
                Grid {
                  Layout.fillWidth: true
                  columns: 2
                  columnSpacing: 12
                  rowSpacing: 12

                  Repeater {
                    model: modal.platforms.filter(p => p.category === "cloud")
                    delegate: Rectangle {
                      width: Math.floor((assistantWindow.width - 230 - 48 - 12) / 2)
                      height: 84
                      radius: 10
                      color: pMouse2.containsMouse ? "#111c30" : "#0c1322"
                      border.color: pMouse2.containsMouse ? (modelData.brandColor || "#38bdf8") : "#1b253b"
                      border.width: 1

                      MouseArea {
                        id: pMouse2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modal.selectPlatform(modelData)
                      }

                      RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                          Layout.preferredWidth: 38
                          Layout.preferredHeight: 38
                          radius: 8
                          color: "#070c18"
                          border.color: "#1e293b"

                          Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : Qt.resolvedUrl(modelData.iconSvg || "../icons/cloud.svg")
                            fillMode: Image.PreserveAspectFit
                          }
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 3

                          Text {
                            text: modelData.name
                            font.pixelSize: 13
                            font.bold: true
                            color: "#f8fafc"
                          }

                          RowLayout {
                            spacing: 4
                            Rectangle {
                              height: 16
                              radius: 8
                              color: Qt.rgba(0.06, 0.72, 0.5, 0.2)
                              border.color: modelData.badgeColor || "#10b981"
                              border.width: 1
                              width: bText2.implicitWidth + 8

                              Text {
                                id: bText2
                                anchors.centerIn: parent
                                text: modelData.badge || "S3"
                                font.pixelSize: 9
                                font.bold: true
                                color: modelData.badgeColor || "#34d399"
                              }
                            }
                          }

                          Text {
                            text: modelData.tagline
                            font.pixelSize: 10
                            color: "#94a3b8"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            maximumLineCount: 2
                            elide: Text.ElideRight
                          }
                        }

                        Text {
                          text: "›"
                          font.pixelSize: 18
                          font.bold: true
                          color: pMouse2.containsMouse ? "#38bdf8" : "#475569"
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // ==============================================
          // STEP 2 (DEDICATED): CHOOSE CONNECTION METHOD
          // ==============================================
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: modal.stepName === "method" && !!modal.selectedPlatform

            ColumnLayout {
              anchors.fill: parent
              spacing: 14

              // Intro Header Banner
              Rectangle {
                Layout.fillWidth: true
                implicitHeight: methodBannerRow.implicitHeight + 20
                radius: 10
                color: "#081324"
                border.color: "#182b48"

                RowLayout {
                  id: methodBannerRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: 12
                  anchors.rightMargin: 12
                  spacing: 12

                  Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: "#0284c7"
                    Image {
                      anchors.centerIn: parent
                      width: 18
                      height: 18
                      source: "../icons/bolt.svg"
                      sourceSize: Qt.size(18, 18)
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    spacing: 2
                    Text {
                      text: "Multiple Connection Protocols Available"
                      font.pixelSize: 13
                      font.bold: true
                      color: "#f8fafc"
                    }
                    Text {
                      text: "Select how you would like Omarchy to integrate with " + (modal.selectedPlatform ? modal.selectedPlatform.name : "this provider") + ". Each method is tailored for specific regional data centers and security preferences."
                      font.pixelSize: 11
                      color: "#94a3b8"
                      wrapMode: Text.WordWrap
                      Layout.fillWidth: true
                    }
                  }
                }
              }

              // The Connection Method Cards List
              ScrollView {
                id: methodScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                  width: methodScroll.availableWidth
                  spacing: 10

                  Repeater {
                    model: (modal.selectedPlatform && modal.selectedPlatform.methods) ? modal.selectedPlatform.methods : []

                    delegate: Rectangle {
                      id: methodCard
                      Layout.fillWidth: true
                      implicitHeight: methodCardCol.implicitHeight + 16
                      radius: 8
                      color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? "#0d2242" : (methodMouse.containsMouse ? "#0a182c" : "#07101e")
                      border.color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? (modelData.badgeColor || "#0284c7") : (methodMouse.containsMouse ? "#334155" : "#182234")
                      border.width: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? 2 : 1

                      MouseArea {
                        id: methodMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          modal.selectMethod(modelData);
                        }
                        onDoubleClicked: {
                          modal.selectMethod(modelData);
                          modal.stepName = "walkthrough";
                        }
                      }

                      RowLayout {
                        id: methodCardCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12

                        // Protocol Badge / Icon
                        Rectangle {
                          Layout.preferredWidth: 44
                          Layout.preferredHeight: 44
                          radius: 10
                          color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? Qt.rgba(0.02, 0.52, 0.78, 0.3) : "#0f1c30"
                          border.color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? (modelData.badgeColor || "#0284c7") : "#1e2d42"

                          Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: modelData.authType === "oauth" ? "../icons/key.svg" : (modelData.authType === "webdav" ? "../icons/world.svg" : "../icons/device-desktop.svg")
                            sourceSize: Qt.size(22, 22)
                          }
                        }

                        // Method Name & Detailed Description
                        ColumnLayout {
                          Layout.fillWidth: true
                          Layout.preferredWidth: 0
                          spacing: 4

                          RowLayout {
                            spacing: 8
                            Text {
                              text: modelData.name
                              font.pixelSize: 13
                              font.bold: true
                              color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? "#ffffff" : "#e2e8f0"
                            }

                            Rectangle {
                              visible: !!modelData.badge
                              implicitWidth: bText.implicitWidth + 10
                              implicitHeight: 18
                              radius: 4
                              color: Qt.rgba(0.05, 0.25, 0.45, 0.6)
                              border.color: modelData.badgeColor || "#38bdf8"
                              border.width: 1

                              Text {
                                id: bText
                                anchors.centerIn: parent
                                text: modelData.badge || ""
                                font.pixelSize: 9
                                font.bold: true
                                color: modelData.badgeColor || "#38bdf8"
                              }
                            }
                          }

                          Text {
                            text: modelData.description || ""
                            font.pixelSize: 11
                            color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? "#93c5fd" : "#94a3b8"
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                          }

                          // Tech Spec / Regional Endpoint Info Pill
                          RowLayout {
                            spacing: 8
                            visible: !!modelData.extraArgs || !!modelData.fields || !!modelData.authType

                            Text {
                              text: {
                                if (modelData.id === "oauth_us") return "Server: api.pcloud.com · US / Global Data Center · One-Click OAuth";
                                if (modelData.id === "oauth_eu") return "Server: eapi.pcloud.com · European Union Data Center (GDPR) · One-Click OAuth";
                                if (modelData.id === "webdav") return "Protocol: Encrypted HTTPS WebDAV · Direct Email & Password · Port 443";
                                if (modelData.id === "linux_app") return "Package: Official Linux AppImage / pcloudcc · Native System Tray Client";
                                return "Protocol: " + (modelData.authType ? modelData.authType.toUpperCase() : "");
                              }
                              font.pixelSize: 10
                              color: "#64748b"
                            }
                          }
                        }

                        // Radio Button Selection Indicator
                        Rectangle {
                          Layout.preferredWidth: 22
                          Layout.preferredHeight: 22
                          radius: 11
                          color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? "#0284c7" : "#07101e"
                          border.color: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? "#38bdf8" : "#334155"
                          border.width: (modal.selectedMethod && modal.selectedMethod.id === modelData.id) ? 2 : 1

                          Text {
                            anchors.centerIn: parent
                            text: "✓"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                            visible: (modal.selectedMethod && modal.selectedMethod.id === modelData.id)
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Regional Guidance Tip Callout
              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: "💡"; font.pixelSize: 12 }
                Text {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 0
                  text: "Tip: pCloud separates US and EU account databases. If your account was registered in Europe or you log into my.pcloud.com with EU selected, choose the European Union option to prevent invalid authorization errors."
                  font.pixelSize: 10
                  color: "#64748b"
                  wrapMode: Text.WordWrap
                }
              }
            }
          }

          // ==============================================
          // STEP 3: GUIDED API KEYS / SIGN-IN WALKTHROUGH
          // ==============================================
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: modal.stepName === "walkthrough" && !!modal.selectedPlatform

            ColumnLayout {
              anchors.fill: parent
              spacing: 12

              // Selected Method Banner (if platform has multiple methods)
              Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 8
                color: "#081324"
                border.color: "#182b48"
                visible: modal.hasMethods && !!modal.selectedMethod

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 12
                  spacing: 8

                  Text { text: "Selected Method:"; font.pixelSize: 11; color: "#64748b" }
                  Text {
                    text: modal.selectedMethod ? modal.selectedMethod.name : ""
                    font.pixelSize: 11
                    font.bold: true
                    color: "#38bdf8"
                  }
                  Rectangle {
                    visible: !!(modal.selectedMethod && modal.selectedMethod.badge)
                    implicitWidth: selBTxt.implicitWidth + 8
                    implicitHeight: 16
                    radius: 3
                    color: Qt.rgba(0.05, 0.25, 0.45, 0.6)
                    border.color: (modal.selectedMethod && modal.selectedMethod.badgeColor) ? modal.selectedMethod.badgeColor : "#38bdf8"
                    border.width: 0.8
                    Text {
                      id: selBTxt
                      anchors.centerIn: parent
                      text: modal.selectedMethod ? (modal.selectedMethod.badge || "") : ""
                      font.pixelSize: 8
                      font.bold: true
                      color: (modal.selectedMethod && modal.selectedMethod.badgeColor) ? modal.selectedMethod.badgeColor : "#38bdf8"
                    }
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                    text: "Change Method ↻"
                    font.pixelSize: 10
                    font.bold: true
                    color: changeMouse.containsMouse ? "#38bdf8" : "#94a3b8"

                    MouseArea {
                      id: changeMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: modal.stepName = "method"
                    }
                  }
                }
              }

              // Action Hero Card with External Browser Button
              Rectangle {
                Layout.fillWidth: true
                height: 68
                radius: 10
                color: "#0d1b32"
                border.color: modal.selectedPlatform ? (modal.selectedPlatform.brandColor || "#0284c7") : "#0284c7"
                border.width: 1
                clip: true

                Item {
                  anchors.fill: parent
                  anchors.margins: 12

                  Rectangle {
                    id: heroIconRect
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    radius: 8
                    color: "#081324"

                    Image {
                      anchors.centerIn: parent
                      width: 20
                      height: 20
                      source: (modal.selectedPlatform && modal.selectedPlatform.iconDataUri && modal.selectedPlatform.iconDataUri.length > 0) ? modal.selectedPlatform.iconDataUri : (modal.selectedPlatform ? Qt.resolvedUrl(modal.selectedPlatform.iconSvg || "../icons/cloud.svg") : "")
                      fillMode: Image.PreserveAspectFit
                    }
                  }

                  AppButton {
                    id: heroActionBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!(modal.selectedPlatform && (modal.isOAuth || modal.isApp || modal.selectedPlatform.dashboardUrl || (modal.selectedMethod && modal.selectedMethod.dashboardUrl)))
                    text: {
                      if (modal.selectedMethod && modal.selectedMethod.actionButtonText) return modal.selectedMethod.actionButtonText;
                      if (modal.isOAuth) return "Sign In ↗";
                      if (modal.isApp) return "Download Client ↗";
                      if (modal.selectedPlatform && modal.selectedPlatform.dashboardUrl) return "Open Settings ↗";
                      return "Open Console ↗";
                    }
                    variant: "primary"
                    onClicked: {
                      if (modal.isOAuth) {
                        var pType = (modal.selectedMethod && modal.selectedMethod.rcloneType) ? modal.selectedMethod.rcloneType : modal.selectedPlatform.rcloneType;
                        var rName = (modal.selectedMethod && modal.selectedMethod.defaultRemoteName) ? modal.selectedMethod.defaultRemoteName : modal.selectedPlatform.defaultRemoteName;
                        var eArgs = (modal.selectedMethod && modal.selectedMethod.extraArgs) ? modal.selectedMethod.extraArgs : "";
                        ocloud.connectCloudAccount(pType, rName, eArgs);
                      } else if (modal.isApp) {
                        Qt.openUrlExternally((modal.selectedMethod && modal.selectedMethod.dashboardUrl) ? modal.selectedMethod.dashboardUrl : modal.selectedPlatform.dashboardUrl);
                      } else if (modal.selectedMethod && modal.selectedMethod.authType === "webdav") {
                        modal.stepName = "credentials";
                      } else if (modal.selectedPlatform && modal.selectedPlatform.dashboardUrl) {
                        Qt.openUrlExternally(modal.selectedPlatform.dashboardUrl);
                      }
                    }
                  }

                  ColumnLayout {
                    anchors.left: heroIconRect.right
                    anchors.leftMargin: 12
                    anchors.right: heroActionBtn.visible ? heroActionBtn.left : parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                      Layout.fillWidth: true
                      text: modal.isOAuth ?
                            ("Sign in to " + (modal.selectedMethod ? modal.selectedMethod.name : modal.selectedPlatform.name)) :
                            (modal.isApp ?
                            ("Install " + (modal.selectedMethod ? modal.selectedMethod.name : modal.selectedPlatform.name)) :
                            (modal.selectedPlatform && modal.selectedPlatform.dashboardUrl ?
                            ("Configure " + (modal.selectedMethod ? modal.selectedMethod.name : modal.selectedPlatform.name)) :
                            "Cloud Storage Setup"))
                      font.pixelSize: 13
                      font.bold: true
                      color: "#ffffff"
                      elide: Text.ElideRight
                    }
                    Text {
                      Layout.fillWidth: true
                      text: (modal.selectedMethod && modal.selectedMethod.description) ?
                            modal.selectedMethod.description :
                            (modal.isOAuth ?
                            "Click Sign In to authenticate via browser. Credentials are saved locally." :
                            (modal.selectedPlatform && modal.selectedPlatform.dashboardUrl ?
                            "Click to open settings in your browser to view or create your access key." :
                            "Configure your API keys and storage credentials."))
                      font.pixelSize: 10
                      color: "#93c5fd"
                      elide: Text.ElideRight
                    }
                  }
                }
              }

              // 3-Step Visual Guide Cards
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Step 1 Card: Navigate / Login
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: s1Row.implicitHeight + 16
                  radius: 8
                  color: "#0a1120"
                  border.color: "#182234"

                  RowLayout {
                    id: s1Row
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      radius: 12
                      color: "#0284c7"
                      Text { anchors.centerIn: parent; text: "1"; font.pixelSize: 11; font.bold: true; color: "#ffffff" }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.preferredWidth: 0
                      spacing: 3
                      Text {
                        text: modal.isOAuth ? "Browser Authorization" : (modal.isApp ? "Download & Install Client" : "Navigate to Account / API Settings")
                        font.pixelSize: 12
                        font.bold: true
                        color: "#f8fafc"
                      }
                      Text {
                        text: modal.getActiveStepDesc(1)
                        font.pixelSize: 11
                        color: "#94a3b8"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                      }
                      Rectangle {
                        height: 20
                        radius: 4
                        color: "#060b16"
                        border.color: "#1e293b"
                        width: bcText.implicitWidth + 12
                        visible: modal.getActiveBreadcrumb().length > 0

                        Text {
                          id: bcText
                          anchors.centerIn: parent
                          text: modal.getActiveBreadcrumb()
                          font.pixelSize: 9
                          color: "#38bdf8"
                        }
                      }
                    }
                  }
                }

                // Step 2 Card: Permissions / Approve
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: s2Row.implicitHeight + 16
                  radius: 8
                  color: "#0a1120"
                  border.color: "#182234"

                  RowLayout {
                    id: s2Row
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      radius: 12
                      color: "#0284c7"
                      Text { anchors.centerIn: parent; text: "2"; font.pixelSize: 11; font.bold: true; color: "#ffffff" }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.preferredWidth: 0
                      spacing: 3
                      Text {
                        text: modal.isOAuth ? "Grant File Permissions" : (modal.isApp ? "Permissions & Setup" : ((modal.selectedPlatform && (modal.selectedPlatform.authType === "webdav" || modal.selectedPlatform.rcloneType === "webdav")) || (modal.selectedMethod && modal.selectedMethod.authType === "webdav") ? "WebDAV Access & Credentials" : "Create Token & Assign Permissions"))
                        font.pixelSize: 12
                        font.bold: true
                        color: "#f8fafc"
                      }
                      Text {
                        text: modal.getActiveStepDesc(2)
                        font.pixelSize: 11
                        color: "#94a3b8"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                      }
                    }
                  }
                }

                // Step 3 Card: What to Copy / Local Storage
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: s3Row.implicitHeight + 16
                  radius: 8
                  color: "#0a1120"
                  border.color: "#182234"

                  RowLayout {
                    id: s3Row
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                      Layout.preferredWidth: 24
                      Layout.preferredHeight: 24
                      radius: 12
                      color: "#0284c7"
                      Text { anchors.centerIn: parent; text: "3"; font.pixelSize: 11; font.bold: true; color: "#ffffff" }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.preferredWidth: 0
                      spacing: 3
                      Text {
                        text: modal.isOAuth ? "Automated Native Mount" : (modal.isApp ? "Launch Virtual Drive" : "Enter Credentials in Step 3")
                        font.pixelSize: 12
                        font.bold: true
                        color: "#f8fafc"
                      }
                      Text {
                        text: modal.getActiveStepDesc(3)
                        font.pixelSize: 11
                        color: "#94a3b8"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                      }
                    }
                  }
                }
              }

              Item { Layout.fillHeight: true }

              // Privacy & Local Security Callout
              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Image {
                  width: 14
                  height: 14
                  source: "../icons/lock.svg"
                  sourceSize: Qt.size(14, 14)
                }
                Text {
                  Layout.fillWidth: true
                  Layout.preferredWidth: 0
                  text: "Credentials are encrypted exclusively on this machine in ~/.config/rclone and never pass through any Ocloud cloud servers."
                  font.pixelSize: 10
                  color: "#64748b"
                  wrapMode: Text.WordWrap
                }
              }
            }
          }

          // ==============================================
          // STEP 3: ENTER CREDENTIALS FORM
          // ==============================================
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: modal.stepName === "credentials" && !!modal.selectedPlatform

            ScrollView {
              id: credScroll
              anchors.fill: parent
              clip: true
              contentWidth: availableWidth
              ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

              ColumnLayout {
                width: credScroll.availableWidth
                spacing: 12

                // Endpoint Field
                ColumnLayout {
                  id: endpointCol
                  Layout.fillWidth: true
                  spacing: 4
                  readonly property var fld: modal.getActiveField("endpoint")
                  visible: !!fld || !!(modal.selectedPlatform && (modal.selectedPlatform.endpointLabel || modal.selectedPlatform.authType === "s3" || modal.selectedPlatform.authType === "webdav" || modal.selectedPlatform.rcloneType === "webdav"))

                  RowLayout {
                    spacing: 6
                    Image {
                      width: 14
                      height: 14
                      source: "../icons/world.svg"
                      sourceSize: Qt.size(14, 14)
                    }
                    Text {
                      text: endpointCol.fld ? endpointCol.fld.label : (modal.selectedPlatform && modal.selectedPlatform.endpointLabel ? modal.selectedPlatform.endpointLabel : "Endpoint URL")
                      font.pixelSize: 12
                      font.bold: true
                      color: "#f8fafc"
                    }
                  }

                  TextField {
                    id: endpointField
                    Layout.fillWidth: true
                    height: 38
                    placeholderText: endpointCol.fld ? endpointCol.fld.placeholder : (modal.selectedPlatform && modal.selectedPlatform.endpointPlaceholder ? modal.selectedPlatform.endpointPlaceholder : "")
                    placeholderTextColor: "#475569"
                    color: "#38bdf8"
                    font.pixelSize: 12
                    background: Rectangle {
                      color: "#0b1424"
                      border.color: endpointField.activeFocus ? "#38bdf8" : "#1e293b"
                      border.width: 1
                      radius: 6
                    }
                  }

                  Text {
                    text: endpointCol.fld ? (endpointCol.fld.helper || "") : (modal.selectedPlatform && modal.selectedPlatform.endpointHelper ? modal.selectedPlatform.endpointHelper : "")
                    font.pixelSize: 10
                    color: "#64748b"
                    visible: text.length > 0
                  }
                }

                // Bucket Name Field
                ColumnLayout {
                  id: bucketCol
                  Layout.fillWidth: true
                  spacing: 4
                  readonly property var fld: modal.getActiveField("bucket")
                  visible: !!fld || !!(modal.selectedPlatform && (modal.selectedPlatform.bucketLabel || modal.selectedPlatform.authType === "s3"))

                  RowLayout {
                    spacing: 6
                    Image {
                      width: 14
                      height: 14
                      source: "../icons/folder.svg"
                      sourceSize: Qt.size(14, 14)
                    }
                    Text {
                      text: bucketCol.fld ? bucketCol.fld.label : (modal.selectedPlatform && modal.selectedPlatform.bucketLabel ? modal.selectedPlatform.bucketLabel : "Bucket Name")
                      font.pixelSize: 12
                      font.bold: true
                      color: "#f8fafc"
                    }
                  }

                  TextField {
                    id: bucketField
                    Layout.fillWidth: true
                    height: 38
                    placeholderText: bucketCol.fld ? bucketCol.fld.placeholder : (modal.selectedPlatform && modal.selectedPlatform.bucketPlaceholder ? modal.selectedPlatform.bucketPlaceholder : "")
                    placeholderTextColor: "#475569"
                    color: "#f8fafc"
                    font.pixelSize: 12
                    background: Rectangle {
                      color: "#0b1424"
                      border.color: bucketField.activeFocus ? "#38bdf8" : "#1e293b"
                      border.width: 1
                      radius: 6
                    }
                  }

                  Text {
                    text: bucketCol.fld ? (bucketCol.fld.helper || "") : (modal.selectedPlatform && modal.selectedPlatform.bucketHelper ? modal.selectedPlatform.bucketHelper : "")
                    font.pixelSize: 10
                    color: "#64748b"
                    visible: text.length > 0
                  }
                }

                // Access Key / Username Field
                ColumnLayout {
                  id: keyCol
                  Layout.fillWidth: true
                  spacing: 4
                  readonly property var fld: modal.getActiveField("username") || modal.getActiveField("key")

                  RowLayout {
                    spacing: 6
                    Image {
                      width: 14
                      height: 14
                      source: (keyCol.fld && keyCol.fld.key === "username") ? "../icons/user.svg" : "../icons/key.svg"
                      sourceSize: Qt.size(14, 14)
                    }
                    Text {
                      text: keyCol.fld ? keyCol.fld.label : (modal.selectedPlatform && modal.selectedPlatform.keyLabel ? modal.selectedPlatform.keyLabel : "Access Key ID")
                      font.pixelSize: 12
                      font.bold: true
                      color: "#f8fafc"
                    }
                  }

                  TextField {
                    id: keyField
                    Layout.fillWidth: true
                    height: 38
                    placeholderText: keyCol.fld ? keyCol.fld.placeholder : (modal.selectedPlatform && modal.selectedPlatform.keyPlaceholder ? modal.selectedPlatform.keyPlaceholder : "Paste Access Key ID")
                    placeholderTextColor: "#475569"
                    color: "#f8fafc"
                    font.pixelSize: 12
                    background: Rectangle {
                      color: "#0b1424"
                      border.color: keyField.activeFocus ? "#38bdf8" : "#1e293b"
                      border.width: 1
                      radius: 6
                    }
                  }

                  Text {
                    text: keyCol.fld ? (keyCol.fld.helper || "") : ""
                    font.pixelSize: 10
                    color: "#64748b"
                    visible: text.length > 0
                  }
                }

                // Secret Access Key / Password Field with Show/Hide Toggle
                ColumnLayout {
                  id: secretCol
                  Layout.fillWidth: true
                  spacing: 4
                  readonly property var fld: modal.getActiveField("password") || modal.getActiveField("secret")

                  RowLayout {
                    spacing: 6
                    Image {
                      width: 14
                      height: 14
                      source: "../icons/lock.svg"
                      sourceSize: Qt.size(14, 14)
                    }
                    Text {
                      text: secretCol.fld ? secretCol.fld.label : (modal.selectedPlatform && modal.selectedPlatform.secretLabel ? modal.selectedPlatform.secretLabel : "Secret Access Key")
                      font.pixelSize: 12
                      font.bold: true
                      color: "#f8fafc"
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 6
                    color: "#0b1424"
                    border.color: secretField.activeFocus ? "#38bdf8" : "#1e293b"
                    border.width: 1

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: 10
                      anchors.rightMargin: 8
                      spacing: 8

                      TextField {
                        id: secretField
                        Layout.fillWidth: true
                        echoMode: modal.showSecret ? TextInput.Normal : TextInput.Password
                        placeholderText: secretCol.fld ? secretCol.fld.placeholder : (modal.selectedPlatform && modal.selectedPlatform.secretPlaceholder ? modal.selectedPlatform.secretPlaceholder : "Paste Secret Key")
                        placeholderTextColor: "#475569"
                        color: "#f8fafc"
                        font.pixelSize: 12
                        background: Rectangle { color: "transparent" }
                      }

                      Rectangle {
                        width: 58
                        height: 24
                        radius: 4
                        color: eyeMouse.containsMouse ? "#1e293b" : "#141d2d"

                        Text {
                          anchors.centerIn: parent
                          text: modal.showSecret ? "Hide" : "Show"
                          font.pixelSize: 10
                          font.bold: true
                          color: "#94a3b8"
                        }

                        MouseArea {
                          id: eyeMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: modal.showSecret = !modal.showSecret
                        }
                      }
                    }
                  }

                  Text {
                    text: secretCol.fld ? (secretCol.fld.helper || "") : ""
                    font.pixelSize: 10
                    color: "#64748b"
                    visible: text.length > 0
                  }
                }

                // Third-party disclosure notice (e.g. Proton Drive requirement)
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: disclosureText.implicitHeight + 16
                  radius: 6
                  color: Qt.rgba(109/255, 74/255, 255/255, 0.12)
                  border.color: Qt.rgba(109/255, 74/255, 255/255, 0.35)
                  border.width: 1
                  visible: !!(modal.selectedPlatform && modal.selectedPlatform.disclosure)

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8
                    Image {
                      width: 14
                      height: 14
                      source: "../icons/info-circle.svg"
                      sourceSize: Qt.size(14, 14)
                    }
                    Text {
                      id: disclosureText
                      Layout.fillWidth: true
                      text: modal.selectedPlatform && modal.selectedPlatform.disclosure ? modal.selectedPlatform.disclosure : ""
                      font.pixelSize: 11
                      color: "#c4b5fd"
                      wrapMode: Text.WordWrap
                    }
                  }
                }

                // 2FA / OTP Field
                ColumnLayout {
                  id: twofaCol
                  Layout.fillWidth: true
                  spacing: 4
                  readonly property var fld: modal.getActiveField("twofa")
                  visible: !!fld

                  RowLayout {
                    spacing: 6
                    Image {
                      width: 14
                      height: 14
                      source: "../icons/shield-lock.svg"
                      sourceSize: Qt.size(14, 14)
                    }
                    Text {
                      text: twofaCol.fld ? twofaCol.fld.label : "2FA Code / OTP Secret (Optional)"
                      font.pixelSize: 12
                      font.bold: true
                      color: "#f8fafc"
                    }
                  }

                  TextField {
                    id: twofaField
                    Layout.fillWidth: true
                    height: 38
                    placeholderText: twofaCol.fld ? twofaCol.fld.placeholder : "123456 or OTP Secret"
                    placeholderTextColor: "#475569"
                    color: "#f8fafc"
                    font.pixelSize: 12
                    background: Rectangle {
                      color: "#0b1424"
                      border.color: twofaField.activeFocus ? "#38bdf8" : "#1e293b"
                      border.width: 1
                      radius: 6
                    }
                  }

                  Text {
                    text: twofaCol.fld ? (twofaCol.fld.helper || "") : ""
                    font.pixelSize: 10
                    color: "#64748b"
                    visible: text.length > 0
                  }
                }

                // Mailbox Password Field (Optional)
                ColumnLayout {
                  id: mailboxPassCol
                  Layout.fillWidth: true
                  spacing: 4
                  readonly property var fld: modal.getActiveField("mailbox_password")
                  visible: !!fld

                  RowLayout {
                    spacing: 6
                    Image {
                      width: 14
                      height: 14
                      source: "../icons/lock.svg"
                      sourceSize: Qt.size(14, 14)
                    }
                    Text {
                      text: mailboxPassCol.fld ? mailboxPassCol.fld.label : "Mailbox Password (Optional)"
                      font.pixelSize: 12
                      font.bold: true
                      color: "#f8fafc"
                    }
                  }

                  TextField {
                    id: mailboxPassField
                    Layout.fillWidth: true
                    height: 38
                    echoMode: TextInput.Password
                    placeholderText: mailboxPassCol.fld ? mailboxPassCol.fld.placeholder : "Only for two-password mode"
                    placeholderTextColor: "#475569"
                    color: "#f8fafc"
                    font.pixelSize: 12
                    background: Rectangle {
                      color: "#0b1424"
                      border.color: mailboxPassField.activeFocus ? "#38bdf8" : "#1e293b"
                      border.width: 1
                      radius: 6
                    }
                  }

                  Text {
                    text: mailboxPassCol.fld ? (mailboxPassCol.fld.helper || "") : ""
                    font.pixelSize: 10
                    color: "#64748b"
                    visible: text.length > 0
                  }
                }
              }
            }
          }

          // ==============================================
          // STEP 4: DRIVE PREVIEW & FINALIZE
          // ==============================================
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: modal.stepName === "mount" && !!modal.selectedPlatform

            ColumnLayout {
              anchors.fill: parent
              spacing: 14

              // macOS-Grade Native Drive Preview Card
              Rectangle {
                Layout.fillWidth: true
                height: 100
                radius: 12
                color: "#0a1324"
                border.color: "#0284c7"
                border.width: 1.5

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 16
                  spacing: 16

                  // Big Drive Icon with Provider Badge Overlay
                  Item {
                    Layout.preferredWidth: 54
                    Layout.preferredHeight: 54

                    Image {
                      anchors.centerIn: parent
                      width: 48
                      height: 48
                      source: Qt.resolvedUrl("../icons/cloud.svg")
                      fillMode: Image.PreserveAspectFit
                    }

                    Rectangle {
                      anchors.right: parent.right
                      anchors.bottom: parent.bottom
                      width: 20
                      height: 20
                      radius: 10
                      color: "#060b14"
                      border.color: modal.selectedPlatform ? (modal.selectedPlatform.brandColor || "#0284c7") : "#1e293b"

                      Image {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        source: (modal.selectedPlatform && modal.selectedPlatform.iconDataUri && modal.selectedPlatform.iconDataUri.length > 0) ? modal.selectedPlatform.iconDataUri : (modal.selectedPlatform ? Qt.resolvedUrl(modal.selectedPlatform.iconSvg || "../icons/cloud.svg") : "")
                        fillMode: Image.PreserveAspectFit
                      }
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                      spacing: 8
                      Text {
                        text: nameField.text.trim() || (modal.selectedMethod ? modal.selectedMethod.name : (modal.selectedPlatform ? modal.selectedPlatform.name : "Cloud Drive"))
                        font.pixelSize: 15
                        font.bold: true
                        color: "#f8fafc"
                      }
                      AppBadge {
                        variant: "success"
                        text: "Ready to Mount"
                      }
                    }

                    Text {
                      text: "Mounted Destination: " + (mountPointField.text.trim() || "~/Storage")
                      font.pixelSize: 11
                      font.bold: true
                      color: "#38bdf8"
                    }

                    Text {
                      text: "Files appear inside Linux File Manager as standard native folders."
                      font.pixelSize: 10
                      color: "#94a3b8"
                    }
                  }
                }
              }

              // Drive Display Name Setting
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                  text: "Drive Display Name in Omarchy:"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#94a3b8"
                }

                TextField {
                  id: nameField
                  Layout.fillWidth: true
                  height: 38
                  color: "#f8fafc"
                  font.pixelSize: 12
                  background: Rectangle {
                    color: "#0b1424"
                    border.color: nameField.activeFocus ? "#38bdf8" : "#1e293b"
                    border.width: 1
                    radius: 6
                  }
                }
              }

              // Mount Folder Setting with Preset Chips
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                  text: "Local Mount Folder:"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#94a3b8"
                }

                TextField {
                  id: mountPointField
                  Layout.fillWidth: true
                  height: 38
                  text: "~/R2"
                  color: "#38bdf8"
                  font.pixelSize: 12
                  background: Rectangle {
                    color: "#0b1424"
                    border.color: mountPointField.activeFocus ? "#38bdf8" : "#1e293b"
                    border.width: 1
                    radius: 6
                  }
                }

                RowLayout {
                  spacing: 6
                  Text { text: "Quick Presets:"; font.pixelSize: 10; color: "#64748b" }

                  Repeater {
                    model: {
                      var dMount = (modal.selectedMethod && modal.selectedMethod.defaultMount) ? modal.selectedMethod.defaultMount : (modal.selectedPlatform && modal.selectedPlatform.defaultMount ? modal.selectedPlatform.defaultMount : "~/Storage");
                      var dName = (modal.selectedMethod && modal.selectedMethod.defaultRemoteName) ? modal.selectedMethod.defaultRemoteName : (modal.selectedPlatform ? (modal.selectedPlatform.defaultRemoteName || modal.selectedPlatform.name) : "Drive");
                      return [dMount, "~/Cloud/" + dName.replace(/\s+/g, ""), "~/Backups", "~/Storage"];
                    }
                    delegate: Rectangle {
                      height: 22
                      radius: 4
                      color: chipMouse.containsMouse ? "#1e293b" : "#0f172a"
                      border.color: mountPointField.text === modelData ? "#38bdf8" : "#1e293b"
                      border.width: 1
                      width: cText.implicitWidth + 12

                      Text {
                        id: cText
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 10
                        color: mountPointField.text === modelData ? "#38bdf8" : "#94a3b8"
                      }

                      MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mountPointField.text = modelData
                      }
                    }
                  }
                }
              }

              Item { Layout.fillHeight: true }

              // Live Status / Error Message
              Text {
                visible: modal.testMessage.length > 0
                text: modal.testMessage
                font.pixelSize: 11
                font.bold: true
                color: modal.testSuccess ? "#22c55e" : "#ef4444"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
              }
            }
          }

          // ==============================================
          // BOTTOM FOOTER NAVIGATION BUTTONS
          // ==============================================
          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Back Button
            AppButton {
              visible: modal.stepName !== "providers"
              text: (modal.stepName === "method" || (!modal.hasMethods && modal.stepName === "walkthrough") || (modal.isDirectLogin && modal.stepName === "credentials")) ? "← Choose Provider" : (modal.stepName === "walkthrough" && modal.hasMethods ? "← Choose Method" : "← Back")
              variant: "secondary"
              onClicked: {
                if (modal.stepName === "method") {
                  modal.stepName = "providers";
                } else if (modal.stepName === "walkthrough") {
                  if (modal.hasMethods) {
                    modal.stepName = "method";
                  } else {
                    modal.stepName = "providers";
                  }
                } else if (modal.stepName === "credentials") {
                  if (modal.isDirectLogin) {
                    modal.stepName = "providers";
                  } else {
                    modal.stepName = "walkthrough";
                  }
                } else if (modal.stepName === "mount") {
                  if (modal.isOAuth || modal.isApp) {
                    modal.stepName = "walkthrough";
                  } else {
                    modal.stepName = "credentials";
                  }
                }
              }
            }

            Item { Layout.fillWidth: true }

            // Next Button on Method selection
            AppButton {
              visible: modal.stepName === "method"
              text: "Continue to Setup →"
              variant: "primary"
              onClicked: {
                modal.stepName = "walkthrough";
              }
            }

            // Next Button on Walkthrough
            AppButton {
              visible: modal.stepName === "walkthrough"
              text: modal.isOAuth ? "Continue to Mount Location →" : (modal.isApp ? "Open Download Page ↗" : (((modal.selectedPlatform && (modal.selectedPlatform.authType === "webdav" || modal.selectedPlatform.rcloneType === "webdav")) || (modal.selectedMethod && modal.selectedMethod.authType === "webdav")) ? "Continue to Login →" : "I Have My Keys, Continue →"))
              variant: "primary"
              onClicked: {
                if (modal.isOAuth) {
                  modal.stepName = "mount";
                } else if (modal.isApp) {
                  Qt.openUrlExternally((modal.selectedMethod && modal.selectedMethod.dashboardUrl) ? modal.selectedMethod.dashboardUrl : modal.selectedPlatform.dashboardUrl);
                } else {
                  modal.stepName = "credentials";
                }
              }
            }

            // Next Button on Credentials
            AppButton {
              visible: modal.stepName === "credentials"
              text: modal.isDirectLogin ? "Continue to Mount Location →" : (((modal.selectedPlatform && (modal.selectedPlatform.authType === "webdav" || modal.selectedPlatform.rcloneType === "webdav")) || (modal.selectedMethod && modal.selectedMethod.authType === "webdav")) ? "Continue to Mount Location →" : "Continue to Drive Setup →")
              variant: "primary"
              enabled: keyField.text.trim().length > 0 && secretField.text.trim().length > 0
              onClicked: modal.stepName = "mount"
            }

            // Mount Button on Mount screen
            AppButton {
              visible: modal.stepName === "mount"
              text: modal.isTesting ? "Configuring & Mounting..." : "Mount Drive & Open Files"
              variant: "success"
              loading: modal.isTesting
              enabled: !modal.isTesting
              onClicked: {
                modal.isTesting = true;
                modal.testMessage = "Configuring rclone and verifying mount...";
                modal.testSuccess = false;

                var platform = modal.selectedPlatform;
                var method = modal.selectedMethod;
                var sName = nameField.text.trim() || (method && method.defaultRemoteName ? method.defaultRemoteName : (platform ? platform.defaultName : "Storage"));
                var mPath = mountPointField.text.trim() || (method && method.defaultMount ? method.defaultMount : (platform ? platform.defaultMount : "~/Storage"));
                var rType = (method && method.rcloneType) ? method.rcloneType : (platform ? platform.rcloneType : "");
                var aType = (method && method.authType) ? method.authType : (platform ? platform.authType : "");

                function handleResult(ok, msg) {
                  modal.isTesting = false;
                  if (ok) {
                    modal.testSuccess = true;
                    modal.testMessage = "Drive successfully verified and mounted!";
                    ocloud.openCloudFolder(mPath);
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
          }
        }
      }
    }
  }
}
