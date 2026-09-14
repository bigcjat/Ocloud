import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../modals"

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

  property string selectedServerId: serverList.length > 0 ? String(serverList[0].id) : ""
  property string streamingEngine: "xpra"
  property bool streamingAudio: true
  property bool isSessionAttached: false
  property string activeSessionDisplay: ""
  property string activeCategory: "All"
  property string searchQuery: ""

  property var appList: []
  property var installedAppMap: ({})
  property int serverRamMb: 0
  property int serverCores: 0
  property bool isProbingAll: false

  function probeAll() {
    if (!root.selectedServerId) return;
    root.isProbingAll = true;
    ocloud.probeAllApps(root.selectedServerId, function(res, ok) {
      root.isProbingAll = false;
      if (ok && res && res.success) {
        root.installedAppMap = res.apps || {};
        root.serverRamMb = res.ramMb || 0;
        root.serverCores = res.cores || 0;
      }
    });
  }

  readonly property var categories: [
    "All",
    "Work & Office",
    "Communication",
    "Creative & Media",
    "Dev & Web"
  ]

  readonly property var engineOptions: [
    { id: "xpra", name: "Xpra Seamless" },
    { id: "waypipe", name: "Waypipe Direct" }
  ]

  readonly property var filteredApps: {
    var q = searchQuery.toLowerCase().trim();
    var cat = activeCategory;
    return appList.filter(function(app) {
      var matchCat = (cat === "All") || (app.category === cat);
      var matchQuery = !q ||
        (app.name && app.name.toLowerCase().includes(q)) ||
        (app.desc && app.desc.toLowerCase().includes(q)) ||
        (app.cmd && app.cmd.toLowerCase().includes(q)) ||
        (app.tag && app.tag.toLowerCase().includes(q));
      return matchCat && matchQuery;
    });
  }

  function checkActiveSessions() {
    if (!root.selectedServerId) return;
    ocloud.fetchAppSessions(root.selectedServerId, function(out, ok) {
      if (ok && out && /LIVE.*:[0-9]+|:[0-9]+.*LIVE|session at :[0-9]+/i.test(out)) {
        var match = out.match(/:[0-9]+/);
        root.activeSessionDisplay = match ? match[0] : ":100";
        ocloud.checkAppAttached(function(attached) {
          root.isSessionAttached = attached;
        });
      } else {
        if (root.isSessionAttached) {
          root.isSessionAttached = false;
          ocloud.detachAppSession();
        }
        root.activeSessionDisplay = "";
        root.isSessionAttached = false;
      }
    });
  }

  function reloadApps() {
    ocloud.fetchAppShortcuts(function(list) {
      if (list && list.length > 0) {
        root.appList = list;
      }
    });
    checkActiveSessions();
    probeAll();
  }

  function requestLaunch(cmd, name, minRamMb) {
    if (!root.selectedServerId) return;
    var isInstalled = Boolean(root.installedAppMap[cmd] || root.installedAppMap[cmd.toLowerCase()]);
    if (isInstalled) {
      ocloud.launchApp(root.selectedServerId, cmd, root.streamingEngine, root.streamingAudio);
      return;
    }
    ocloud.probeApp(root.selectedServerId, cmd, function(res, ok) {
      if (res && res.installed) {
        var map = Object.assign({}, root.installedAppMap);
        map[cmd] = true;
        root.installedAppMap = map;
        ocloud.launchApp(root.selectedServerId, cmd, root.streamingEngine, root.streamingAudio);
      } else {
        var srvName = (res && res.serverName) ? res.serverName : targetCombo.currentText;
        installModal.openForApp(name || cmd, cmd, srvName, root.selectedServerId, minRamMb || 0, root.serverRamMb);
      }
    });
  }

  onVisibleChanged: {
    if (visible) {
      checkActiveSessions();
    }
  }

  Component.onCompleted: {
    ocloud.getStreamingEngine(function(eng) {
      if (eng) {
        root.streamingEngine = eng;
        for (var i = 0; i < engineOptions.length; i++) {
          if (engineOptions[i].id === eng) {
            engineCombo.currentIndex = i;
            break;
          }
        }
      }
    });
    ocloud.getStreamingAudio(function(aud) {
      root.streamingAudio = aud;
    });
    reloadApps();
  }

  Timer {
    interval: 20000
    running: root.visible && Boolean(root.selectedServerId)
    repeat: true
    onTriggered: root.checkActiveSessions()
  }

  Connections {
    target: ocloud
    function onActionCompleted(action, success, msg) {
      if (action === "launchApp" || action === "attachAppSession" || action === "detachAppSession" || action === "stopAppSession") {
        root.reloadApps();
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
          spacing: 2

          Text {
            text: "CLOUD APP SUITE"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            font.letterSpacing: 1.2
          }

          Text {
            text: root.filteredApps.length + " streaming apps · " + (root.activeSessionDisplay ? ("Session " + root.activeSessionDisplay + " live") : "Ready")
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        Item { Layout.fillWidth: true }

        // Audio Toggle Button
        Rectangle {
          implicitWidth: audioText.implicitWidth + 14
          implicitHeight: 24
          radius: 2
          color: audioMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: root.streamingAudio ? root.accentColor : root.borderCol
          border.width: 1

          Text {
            id: audioText
            anchors.centerIn: parent
            text: root.streamingAudio ? "Audio: ON" : "Audio: OFF"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.streamingAudio ? root.accentColor : root.mutedColor
          }

          MouseArea {
            id: audioMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.streamingAudio = !root.streamingAudio;
              ocloud.setStreamingAudio(root.streamingAudio);
            }
          }
        }
      }

      // Thin separator
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: root.borderCol
      }

      // =========================================================
      // ACTIVE SESSION BAR (IF RUNNING)
      // =========================================================
      Rectangle {
        visible: root.activeSessionDisplay.length > 0
        Layout.fillWidth: true
        implicitHeight: 36
        radius: 2
        color: root.cardBg
        border.color: root.accentColor
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
            color: root.isSessionAttached
              ? ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
              : root.accentColor
          }

          Text {
            Layout.fillWidth: true
            text: root.isSessionAttached
              ? ("Session " + root.activeSessionDisplay + " is active on local display")
              : ("Session " + root.activeSessionDisplay + " is running 24/7 in background")
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            color: root.textColor
          }

          Rectangle {
            visible: !root.isSessionAttached
            implicitWidth: attText.implicitWidth + 12
            implicitHeight: 22
            radius: 2
            color: attMouse.containsMouse ? root.accentColor : "transparent"
            border.color: root.accentColor
            border.width: 1

            Text {
              id: attText
              anchors.centerIn: parent
              text: "Re-attach"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: attMouse.containsMouse
                ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                : root.accentColor
            }

            MouseArea {
              id: attMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: ocloud.attachAppSession(root.selectedServerId, root.activeSessionDisplay, root.streamingAudio)
            }
          }

          Rectangle {
            visible: root.isSessionAttached
            implicitWidth: detText.implicitWidth + 12
            implicitHeight: 22
            radius: 2
            color: "transparent"
            border.color: root.borderCol
            border.width: 1

            Text {
              id: detText
              anchors.centerIn: parent
              text: "Detach"
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: root.textColor
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: ocloud.detachAppSession(function() { root.checkActiveSessions(); })
            }
          }

          Rectangle {
            implicitWidth: termText.implicitWidth + 12
            implicitHeight: 22
            radius: 2
            color: "transparent"
            border.color: root.borderCol
            border.width: 1

            Text {
              id: termText
              anchors.centerIn: parent
              text: "Terminate"
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: root.mutedColor
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: ocloud.stopAppSession(root.selectedServerId, root.activeSessionDisplay, function() { root.checkActiveSessions(); })
            }
          }
        }
      }

      // =========================================================
      // CONTROLS & SEARCH BAR
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Host selector
        RowLayout {
          spacing: 4
          Text {
            text: "HOST:"
            font.family: root.appFontFamily
            font.pixelSize: 9
            font.bold: true
            color: root.mutedColor
          }
          AppComboBox {
            id: targetCombo
            implicitHeight: 24
            implicitWidth: 150
            model: serverList.map(function(s) { return s.name; })
            onCurrentIndexChanged: {
              if (currentIndex >= 0 && currentIndex < serverList.length) {
                root.selectedServerId = String(serverList[currentIndex].id);
                root.checkActiveSessions();
                root.probeAll();
              }
            }
          }
        }

        // Engine selector
        RowLayout {
          spacing: 4
          Text {
            text: "ENGINE:"
            font.family: root.appFontFamily
            font.pixelSize: 9
            font.bold: true
            color: root.mutedColor
          }
          AppComboBox {
            id: engineCombo
            implicitHeight: 24
            implicitWidth: 130
            model: root.engineOptions.map(function(e) { return e.name; })
            onCurrentIndexChanged: {
              if (currentIndex >= 0 && currentIndex < root.engineOptions.length) {
                root.streamingEngine = root.engineOptions[currentIndex].id;
                ocloud.setStreamingEngine(root.streamingEngine);
              }
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Live Search Input
        TextField {
          id: searchBox
          implicitWidth: 140
          implicitHeight: 24
          font.family: root.appFontFamily
          font.pixelSize: 10
          placeholderText: "Search apps..."
          color: root.textColor
          background: Rectangle {
            color: "transparent"
            border.color: root.borderCol
            border.width: 1
            radius: 2
          }
          onTextChanged: root.searchQuery = text
        }
      }

      // Category filters row
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: root.categories
          delegate: Rectangle {
            implicitHeight: 22
            implicitWidth: catLabel.implicitWidth + 12
            radius: 2
            color: root.activeCategory === modelData
              ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
              : "transparent"
            border.color: root.activeCategory === modelData ? root.accentColor : root.borderCol
            border.width: 1

            Text {
              id: catLabel
              anchors.centerIn: parent
              text: modelData
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: root.activeCategory === modelData
              color: root.activeCategory === modelData ? root.accentColor : root.mutedColor
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeCategory = modelData
            }
          }
        }
      }

      // =========================================================
      // APPLICATIONS LIST (SINGLE-COLUMN DESKTOP ROWS)
      // =========================================================
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: root.filteredApps

          delegate: Rectangle {
            id: appRow
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 2
            color: rowMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : root.cardBg)
              : root.cardBg
            border.color: rowMouse.containsMouse ? root.accentColor : root.borderCol
            border.width: 1

            readonly property bool isInstalled: Boolean(root.installedAppMap[modelData.cmd] || root.installedAppMap[modelData.cmd.toLowerCase()] || root.installedAppMap[modelData.id])

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8

              // Status dot (green = installed/ready, muted = install on demand)
              Rectangle {
                width: 6
                height: 6
                radius: 3
                color: appRow.isInstalled
                  ? ((typeof theme !== "undefined" && theme.success) ? theme.success : "#9ece6a")
                  : root.mutedColor
              }

              // Terminal icon or generic icon
              ThemeIcon {
                width: 14
                height: 14
                source: "icons/terminal.svg"
                color: root.textColor
              }

              // App Name
              Text {
                text: modelData.name || modelData.cmd
                font.family: root.appFontFamily
                font.pixelSize: 11
                font.bold: true
                color: root.textColor
                Layout.preferredWidth: 110
                elide: Text.ElideRight
              }

              // Category / Description
              Text {
                Layout.fillWidth: true
                text: modelData.desc || ("Command: " + modelData.cmd)
                font.family: root.appFontFamily
                font.pixelSize: 10
                color: root.mutedColor
                elide: Text.ElideRight
              }

              // Launch Button
              Rectangle {
                implicitWidth: launchText.implicitWidth + 14
                implicitHeight: 22
                radius: 2
                color: launchMouse.containsMouse ? root.accentColor : "transparent"
                border.color: root.accentColor
                border.width: 1

                Text {
                  id: launchText
                  anchors.centerIn: parent
                  text: appRow.isInstalled ? "Launch" : "Install & Run"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: launchMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                    : root.accentColor
                }

                MouseArea {
                  id: launchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.requestLaunch(modelData.cmd, modelData.name, modelData.minRamMb || 0)
                }
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }
          }
        }
      }

      // Empty State
      Rectangle {
        visible: root.filteredApps.length === 0
        Layout.fillWidth: true
        height: 44
        radius: 2
        color: "transparent"
        border.color: root.borderCol
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 8
          Text {
            Layout.fillWidth: true
            text: "No applications found matching search filter."
            font.family: root.appFontFamily
            font.pixelSize: 11
            color: root.mutedColor
          }
        }
      }

      // =========================================================
      // CUSTOM COMMAND RUNNER
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 34
        radius: 2
        color: root.cardBg
        border.color: root.borderCol
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 8

          ThemeIcon {
            width: 12
            height: 12
            source: "icons/terminal.svg"
            color: root.mutedColor
          }

          TextField {
            id: customCmdField
            Layout.fillWidth: true
            implicitHeight: 24
            font.family: root.appFontFamily
            font.pixelSize: 11
            placeholderText: "Run custom command (e.g. mpv, foot, htop)..."
            color: root.textColor
            background: Rectangle { color: "transparent" }
            onAccepted: {
              var cmd = text.trim();
              if (cmd) {
                root.requestLaunch(cmd, cmd);
                text = "";
              }
            }
          }

          Rectangle {
            implicitWidth: runText.implicitWidth + 14
            implicitHeight: 22
            radius: 2
            color: runMouse.containsMouse ? root.accentColor : "transparent"
            border.color: root.accentColor
            border.width: 1
            enabled: customCmdField.text.trim().length > 0
            opacity: enabled ? 1.0 : 0.4

            Text {
              id: runText
              anchors.centerIn: parent
              text: "Run"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: runMouse.containsMouse
                ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
                : root.accentColor
            }

            MouseArea {
              id: runMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
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
      installModal.appendLog(">>> Initializing installation of " + appName + " on " + installModal.targetServerName + "...");
      ocloud.installAppStreaming(srvId, command, function(line) {
        installModal.appendLog(line);
      }, function(ok, out) {
        installModal.isInstalling = false;
        if (ok) {
          installModal.appendLog("✔ Installation succeeded! Launching " + appName + "...");
          var map = Object.assign({}, root.installedAppMap);
          map[command] = true;
          root.installedAppMap = map;
          root.probeAll();
          installModal.visible = false;
          ocloud.launchApp(srvId, command, root.streamingEngine, root.streamingAudio);
        } else {
          installModal.statusMessage = "Installation failed: " + (out || "Unknown error");
          installModal.appendLog("✖ Error: " + (out || "Installation failed"));
        }
      });
    }
  }
}
