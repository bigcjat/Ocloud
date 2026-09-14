import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../modals"

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  readonly property bool isNarrow: width < 580

  property string selectedServerId: serverList.length > 0 ? String(serverList[0].id) : ""
  property string streamingEngine: "xpra"
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
    { id: "xpra", name: "⚡ Xpra Seamless (Persistent & Smooth · Recommended)" },
    { id: "waypipe", name: "🪟 Waypipe Direct (Original · Pure Wayland)" }
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

  function getMonogram(app) {
    if (!app || !app.name) return "APP";
    var map = {
      "firefox": "FF",
      "code": "VS",
      "tradingview": "TV",
      "slack": "SLK",
      "teams": "TMS",
      "thunderbird": "TB",
      "zoom": "ZM",
      "mattermost": "MM",
      "obs": "OBS",
      "handbrake": "HB",
      "blender": "3D",
      "gimp": "GMP",
      "discord": "DIS",
      "telegram": "TG",
      "signal": "SIG",
      "arcade": "ARC",
      "foot": "TERM",
      "mpv": "MPV"
    };
    return map[app.id] || app.name.substring(0, 3).toUpperCase();
  }

  function getCategoryColor(cat) {
    if (cat === "Work & Office") return "#818cf8";
    if (cat === "Communication") return "#34d399";
    if (cat === "Creative & Media") return "#fbbf24";
    if (cat === "Dev & Web") return "#38bdf8";
    return accentSky;
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
        // If the client thought it was attached, but the cloud machine has no live session,
        // cleanly reap any lingering local xpra/opus viewer processes to save CPU/battery.
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
      ocloud.launchApp(root.selectedServerId, cmd, root.streamingEngine);
      return;
    }
    ocloud.probeApp(root.selectedServerId, cmd, function(res, ok) {
      if (res && res.installed) {
        var map = Object.assign({}, root.installedAppMap);
        map[cmd] = true;
        root.installedAppMap = map;
        ocloud.launchApp(root.selectedServerId, cmd, root.streamingEngine);
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
    anchors.margins: root.isNarrow ? 12 : 20
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 14

      // Header with Server & Engine Selectors
      AppHeader {
        title: "Cloud App Suite"
        subtitle: "Stream sovereign desktop applications with 24/7 cloud persistence"

        RowLayout {
          spacing: 10

          RowLayout {
            spacing: 6
            Text {
              text: "Run on:"
              font.pixelSize: 11
              font.bold: true
              color: textSecondary
            }
            AppComboBox {
              id: targetCombo
              implicitHeight: 30
              implicitWidth: 200
              model: serverList.map(function(s) {
                var prov = s.providerName || (s.isHomeWorkstation ? "Home Workstation" : (s.provider ? s.provider.toUpperCase() : "Cloud"));
                return s.name + " [" + prov + "]";
              })
              onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex < serverList.length) {
                  root.selectedServerId = String(serverList[currentIndex].id);
                  root.checkActiveSessions();
                  root.probeAll();
                }
              }
            }
          }

          RowLayout {
            spacing: 6
            Text {
              text: "Engine:"
              font.pixelSize: 11
              font.bold: true
              color: textSecondary
            }
            AppComboBox {
              id: engineCombo
              implicitHeight: 30
              implicitWidth: 240
              model: root.engineOptions.map(function(e) { return e.name; })
              onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex < root.engineOptions.length) {
                  root.streamingEngine = root.engineOptions[currentIndex].id;
                  ocloud.setStreamingEngine(root.streamingEngine);
                }
              }
            }
          }
        }
      }

      // Sleek Active Session Ribbon (Visible ONLY when a session exists)
      Rectangle {
        visible: root.activeSessionDisplay.length > 0
        Layout.fillWidth: true
        implicitHeight: 48
        radius: 8
        color: root.isSessionAttached ? "#1e293b" : "#064e3b"
        border.color: root.isSessionAttached ? "#3b82f6" : "#10b981"
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 12

          Rectangle {
            width: 8
            height: 8
            radius: 4
            color: root.isSessionAttached ? "#38bdf8" : "#34d399"
          }

          Text {
            text: root.isSessionAttached
              ? "Session " + root.activeSessionDisplay + " is active on desktop"
              : "Session " + root.activeSessionDisplay + " is running 24/7 in background"
            font.pixelSize: 12
            font.bold: true
            color: textPrimary
            Layout.fillWidth: true
          }

          AppButton {
            visible: !root.isSessionAttached
            text: "⚡ Re-attach Window"
            variant: "primary"
            implicitHeight: 28
            onClicked: ocloud.attachAppSession(root.selectedServerId, root.activeSessionDisplay)
          }

          AppButton {
            visible: root.isSessionAttached
            text: "Detach Window"
            variant: "secondary"
            implicitHeight: 28
            onClicked: ocloud.detachAppSession(function() { root.checkActiveSessions(); })
          }

          AppButton {
            text: "Terminate"
            variant: "danger"
            implicitHeight: 28
            onClicked: ocloud.stopAppSession(root.selectedServerId, root.activeSessionDisplay, function() { root.checkActiveSessions(); })
          }
        }
      }

      // Filter Toolbar: Category Pills + Live Search
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // Category Pills
        RowLayout {
          spacing: 6
          Repeater {
            model: root.categories
            delegate: Rectangle {
              id: catPill
              implicitHeight: 28
              implicitWidth: catLabel.implicitWidth + 20
              radius: 14
              color: root.activeCategory === modelData ? accentSky : (hoverArea.containsMouse ? "#1e293b" : "transparent")
              border.color: root.activeCategory === modelData ? accentSky : borderSubtle
              border.width: 1

              Text {
                id: catLabel
                anchors.centerIn: parent
                text: modelData
                font.pixelSize: 11
                font.bold: root.activeCategory === modelData
                color: root.activeCategory === modelData ? "#0f172a" : textSecondary
              }

              MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeCategory = modelData
              }
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Live Search Input
        AppTextField {
          id: searchBox
          implicitWidth: 180
          implicitHeight: 28
          placeholderText: "Search apps..."
          onTextChanged: root.searchQuery = text
        }
      }

      // Apps Grid
      GridLayout {
        Layout.fillWidth: true
        columns: root.isNarrow ? 1 : (width < 820 ? 2 : 3)
        rowSpacing: 12
        columnSpacing: 12

        Repeater {
          model: root.filteredApps

          delegate: AppCard {
            Layout.fillWidth: true
            implicitHeight: 120

            RowLayout {
              anchors.fill: parent
              anchors.margins: 14
              spacing: 12

              // Left: App Monogram Badge
              Rectangle {
                id: iconBox
                width: 44
                height: 44
                radius: 10
                color: "#111827"
                border.color: root.getCategoryColor(modelData.category)
                border.width: 1.5

                Text {
                  anchors.centerIn: parent
                  text: root.getMonogram(modelData)
                  font.pixelSize: 13
                  font.bold: true
                  color: root.getCategoryColor(modelData.category)
                }
              }

              // Center: App Info
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  Text {
                    text: modelData.name || modelData.cmd
                    font.pixelSize: 14
                    font.bold: true
                    color: textPrimary
                    elide: Text.ElideRight
                  }

                  Rectangle {
                    implicitHeight: 18
                    implicitWidth: tagText.implicitWidth + 10
                    radius: 4
                    color: "#1e1b4b"
                    border.color: "#312e81"
                    Text {
                      id: tagText
                      anchors.centerIn: parent
                      text: modelData.tag || "APP"
                      font.pixelSize: 9
                      font.bold: true
                      color: root.getCategoryColor(modelData.category)
                    }
                  }

                  // Pre-flight status badge: Ready vs Available
                  Rectangle {
                    property bool isReady: Boolean(root.installedAppMap[modelData.id] || root.installedAppMap[modelData.cmd])
                    implicitHeight: 18
                    implicitWidth: badgeInnerRow.implicitWidth + 10
                    radius: 4
                    color: isReady ? "#052e16" : "#1e293b"
                    border.color: isReady ? "#16a34a" : "#334155"
                    border.width: 1

                    Row {
                      id: badgeInnerRow
                      anchors.centerIn: parent
                      spacing: 4
                      Rectangle {
                        width: 6; height: 6; radius: 3
                        color: parent.parent.isReady ? "#22c55e" : "#94a3b8"
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Text {
                        text: parent.parent.isReady ? "Ready" : "Available"
                        font.pixelSize: 9
                        font.bold: true
                        color: parent.parent.isReady ? "#4ade80" : "#94a3b8"
                      }
                    }
                  }

                  Item { Layout.fillWidth: true }
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
              }

              // Right: Launch Button
              AppButton {
                text: "Launch"
                variant: "primary"
                implicitHeight: 32
                implicitWidth: 80
                iconSource: "icons/terminal.svg"
                onClicked: root.requestLaunch(modelData.cmd, modelData.name, modelData.minRamMb || 0)
              }
            }
          }
        }
      }

      // Empty State if search matches nothing
      Rectangle {
        visible: root.filteredApps.length === 0
        Layout.fillWidth: true
        implicitHeight: 100
        color: "transparent"
        border.color: borderSubtle
        border.width: 1
        radius: 8

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6
          Text {
            text: "No applications found matching '" + root.searchQuery + "'"
            color: textSecondary
            font.pixelSize: 13
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
          }
          Text {
            text: "Use the command runner below to launch any custom binary."
            color: textMuted
            font.pixelSize: 11
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Sleek Custom Command Runner
      AppCard {
        Layout.fillWidth: true
        implicitHeight: 52

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 16
          anchors.rightMargin: 16
          spacing: 12

          Image {
            width: 16
            height: 16
            source: Qt.resolvedUrl("../icons/terminal.svg")
            fillMode: Image.PreserveAspectFit
          }

          AppTextField {
            id: customCmdField
            Layout.fillWidth: true
            implicitHeight: 32
            placeholderText: "Run any custom Linux application (e.g. foot, mpv, htop, krita)..."
            onAccepted: {
              var cmd = text.trim();
              if (cmd) {
                root.requestLaunch(cmd, cmd);
                text = "";
              }
            }
          }

          AppButton {
            text: "Launch Custom"
            variant: "primary"
            implicitHeight: 32
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
          ocloud.launchApp(srvId, command, root.streamingEngine);
        } else {
          installModal.statusMessage = "Installation failed: " + (out || "Unknown error");
          installModal.appendLog("✖ Error: " + (out || "Installation failed"));
        }
      });
    }
  }
}
