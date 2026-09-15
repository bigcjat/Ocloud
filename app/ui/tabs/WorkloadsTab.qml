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

  property int selectedServerIndex: 0
  readonly property var currentServer: (serverList && serverList.length > selectedServerIndex) ? serverList[selectedServerIndex] : null

  property var activeContainers: []
  property var workloadPlugins: []
  property bool nodeDockerInstalled: true
  property bool nodeDockerRunning: true
  property string nodeDockerVersion: ""
  property bool deploying: false

  function refreshCurrentServer() {
    if (!currentServer) return;
    var srvId = String(currentServer.id);
    if (ocloud.checkNodeDocker) ocloud.checkNodeDocker(srvId);
    if (ocloud.fetchDockerContainers) ocloud.fetchDockerContainers(srvId);
    if (ocloud.fetchWorkloadPlugins) ocloud.fetchWorkloadPlugins();
  }

  Connections {
    target: ocloud
    function onDockerContainersUpdated(jsonStr) {
      try {
        activeContainers = JSON.parse(jsonStr) || [];
      } catch (e) {
        activeContainers = [];
      }
    }
    function onWorkloadPluginsUpdated(jsonStr) {
      try {
        workloadPlugins = JSON.parse(jsonStr) || [];
      } catch (e) {
        workloadPlugins = [];
      }
    }
    function onNodeDockerStatusUpdated(srvId, installed, running, ver) {
      if (currentServer && String(currentServer.id) === String(srvId)) {
        nodeDockerInstalled = installed;
        nodeDockerRunning = running;
        nodeDockerVersion = ver;
      }
    }
    function onActionCompleted(action, success, msg) {
      if (action === "bootstrapDocker" || action === "deployContainer" || action === "containerAction") {
        refreshCurrentServer();
      }
    }
  }

  Component.onCompleted: {
    refreshCurrentServer();
  }

  onCurrentServerChanged: {
    refreshCurrentServer();
  }

  ScrollView {
    anchors.fill: parent
    anchors.margins: 16
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 14

      // =========================================================
      // HEADER & NODE SELECTOR
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
          spacing: 2

          Text {
            text: "WORKLOADS & DOCKER"
            font.family: root.appFontFamily
            font.pixelSize: 10
            font.bold: true
            color: root.mutedColor
            font.letterSpacing: 1.2
          }

          Text {
            text: currentServer
              ? (currentServer.name + " (" + (currentServer.provider || "").toUpperCase() + ") · " + root.activeContainers.length + " containers")
              : (root.activeContainers.length + " active containers")
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.textColor
          }
        }

        Item { Layout.fillWidth: true }

        // Refresh Button
        Rectangle {
          implicitWidth: 28
          implicitHeight: 28
          radius: 2
          color: refMouse.containsMouse
            ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
            : "transparent"
          border.color: refMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          ThemeIcon {
            anchors.centerIn: parent
            width: 14
            height: 14
            source: "icons/refresh.svg"
            color: refMouse.containsMouse ? root.accentColor : root.textColor
          }

          MouseArea {
            id: refMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refreshCurrentServer()
          }
        }

        // Offload Container Button
        Rectangle {
          implicitWidth: offText.implicitWidth + 16
          implicitHeight: 28
          radius: 2
          color: offMouse.containsMouse ? root.accentColor : "transparent"
          border.color: root.accentColor
          border.width: 1

          Text {
            id: offText
            anchors.centerIn: parent
            text: "+ Offload Container"
            font.family: root.appFontFamily
            font.pixelSize: 11
            font.bold: true
            color: offMouse.containsMouse
              ? ((typeof theme !== "undefined" && theme.background) ? theme.background : "#000000")
              : root.accentColor
          }

          MouseArea {
            id: offMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              deployModal.targetPlugin = null;
              deployModal.imgText = "";
              deployModal.nameText = "";
              deployModal.portsText = "";
              deployModal.openModal();
            }
          }
        }
      }

      // =========================================================
      // TARGET NODE SWITCHER PILLS
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: serverList && serverList.length > 1

        Text {
          text: "TARGET NODE:"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.mutedColor
          Layout.alignment: Qt.AlignVCenter
          Layout.rightMargin: 4
        }

        Repeater {
          model: serverList

          delegate: Rectangle {
            implicitWidth: srvPillCol.implicitWidth + 16
            implicitHeight: 26
            radius: 3
            color: root.selectedServerIndex === index
              ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
              : (pillMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.05) : "transparent")
            border.color: root.selectedServerIndex === index ? root.accentColor : root.borderCol
            border.width: 1

            RowLayout {
              id: srvPillCol
              anchors.centerIn: parent
              spacing: 6

              Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                color: (modelData.status === "running" || !modelData.status)
                  ? ((typeof theme !== "undefined" && theme.green) ? theme.green : "#10b981")
                  : root.mutedColor
              }

              Text {
                text: modelData.name + " (" + (modelData.provider || "").toUpperCase() + ")"
                font.family: root.appFontFamily
                font.pixelSize: 11
                font.bold: root.selectedServerIndex === index
                color: root.selectedServerIndex === index ? root.accentColor : root.textColor
              }
            }

            MouseArea {
              id: pillMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.selectedServerIndex = index
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
      // DOCKER ENGINE BOOTSTRAP BANNER (IF DOCKER NOT RUNNING)
      // =========================================================
      Rectangle {
        visible: currentServer && !root.nodeDockerRunning
        Layout.fillWidth: true
        implicitHeight: bootRow.implicitHeight + 20
        radius: 4
        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.08)
        border.color: root.accentColor
        border.width: 1

        RowLayout {
          id: bootRow
          anchors.fill: parent
          anchors.margins: 12
          spacing: 12

          ThemeIcon {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            source: "icons/docker.svg"
            color: root.accentColor
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: "Docker Daemon Not Running on " + (currentServer ? currentServer.name : "Target Node")
              font.family: root.appFontFamily
              font.pixelSize: 12
              font.bold: true
              color: root.textColor
            }

            Text {
              text: "Bootstrap the official Docker engine and Compose plugin in 1-click over SSH."
              font.family: root.appFontFamily
              font.pixelSize: 10
              color: root.mutedColor
            }
          }

          Rectangle {
            implicitWidth: bootBtnText.implicitWidth + 16
            implicitHeight: 26
            radius: 2
            color: bootMouse.containsMouse ? Qt.darker(root.accentColor, 1.2) : root.accentColor

            Text {
              id: bootBtnText
              anchors.centerIn: parent
              text: "⚡ 1-Click Install Docker"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
            }

            MouseArea {
              id: bootMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (currentServer && ocloud.bootstrapNodeDocker) {
                  ocloud.bootstrapNodeDocker(String(currentServer.id));
                }
              }
            }
          }
        }
      }

      // =========================================================
      // ACTIVE CONTAINERS LIST (RESPONSIVE 2-COLUMN GRID)
      // =========================================================
      Text {
        text: "ACTIVE CONTAINERS (" + root.activeContainers.length + ")"
        font.family: root.appFontFamily
        font.pixelSize: 10
        font.bold: true
        color: root.mutedColor
        font.letterSpacing: 1.2
      }

      // Empty State
      Rectangle {
        visible: root.activeContainers.length === 0
        Layout.fillWidth: true
        implicitHeight: 90
        radius: 4
        color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
        border.color: root.borderCol
        border.width: 1

        ColumnLayout {
          anchors.centerIn: parent
          spacing: 6

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "No Containers Running on " + (currentServer ? currentServer.name : "Node")
            font.family: root.appFontFamily
            font.pixelSize: 12
            font.bold: true
            color: root.textColor
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Click \"+ Offload Container\" or select one of the 1-click templates below."
            font.family: root.appFontFamily
            font.pixelSize: 10
            color: root.mutedColor
          }
        }
      }

      GridLayout {
        visible: root.activeContainers.length > 0
        Layout.fillWidth: true
        columns: root.width > 800 ? 2 : 1
        columnSpacing: 10
        rowSpacing: 8

        Repeater {
          model: root.activeContainers

          delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: cLayout.implicitHeight + 20
            radius: 4
            color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
            border.color: cMouse.containsMouse ? root.accentColor : root.borderCol
            border.width: 1

            MouseArea {
              id: cMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }

            RowLayout {
              id: cLayout
              anchors.fill: parent
              anchors.margins: 10
              spacing: 10

              Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                Layout.alignment: Qt.AlignVCenter
                color: (modelData.status || "").toLowerCase().indexOf("up") >= 0 || (modelData.status || "").toLowerCase().indexOf("run") >= 0
                  ? ((typeof theme !== "undefined" && theme.green) ? theme.green : "#10b981")
                  : root.mutedColor
              }

              ThemeIcon {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                Layout.alignment: Qt.AlignVCenter
                source: "icons/docker.svg"
                color: cMouse.containsMouse ? root.accentColor : root.textColor
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                  spacing: 6
                  Text {
                    text: modelData.name || modelData.id || "container"
                    font.family: root.appFontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: root.textColor
                    elide: Text.ElideRight
                  }

                  Text {
                    text: "· " + (modelData.status || "running")
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    color: root.mutedColor
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: (modelData.image || "image") + (modelData.ports ? (" · " + modelData.ports) : "")
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  color: root.mutedColor
                  elide: Text.ElideRight
                }

                // Tailscale Mesh URL link if available
                RowLayout {
                  visible: modelData.urls && modelData.urls.length > 0
                  spacing: 4

                  Text {
                    text: "Mesh:"
                    font.family: root.appFontFamily
                    font.pixelSize: 9
                    font.bold: true
                    color: root.accentColor
                  }

                  Text {
                    text: (modelData.urls && modelData.urls[0]) ? modelData.urls[0].tailscaleUrl : ""
                    font.family: root.appFontFamily
                    font.pixelSize: 9
                    color: (typeof theme !== "undefined" && theme.accentSky) ? theme.accentSky : root.accentColor
                    font.underline: true
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: Qt.openUrlExternally(parent.text)
                    }
                  }
                }
              }

              // Action Buttons
              RowLayout {
                spacing: 6
                Layout.alignment: Qt.AlignVCenter

                // Open Web UI (If URLs exist)
                Rectangle {
                  visible: modelData.urls && modelData.urls.length > 0
                  implicitWidth: openBtnText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
                  border.color: root.accentColor
                  border.width: 1

                  Text {
                    id: openBtnText
                    anchors.centerIn: parent
                    text: "Open"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: root.accentColor
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.urls && modelData.urls.length > 0) {
                        Qt.openUrlExternally(modelData.urls[0].tailscaleUrl);
                      }
                    }
                  }
                }

                // Exec Shell
                Rectangle {
                  implicitWidth: shText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: shMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: shMouse.containsMouse ? root.accentColor : root.borderCol
                  border.width: 1

                  Text {
                    id: shText
                    anchors.centerIn: parent
                    text: "Shell"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: shMouse.containsMouse ? root.accentColor : root.textColor
                  }

                  MouseArea {
                    id: shMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (currentServer && ocloud.openContainerShell) {
                        var ip = currentServer.tailscale_ip || currentServer.ipv4;
                        ocloud.openContainerShell(currentServer.name, ip, modelData.name);
                      }
                    }
                  }
                }

                // Restart Container
                Rectangle {
                  implicitWidth: rstText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: rstMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: rstMouse.containsMouse ? root.accentColor : root.borderCol
                  border.width: 1

                  Text {
                    id: rstText
                    anchors.centerIn: parent
                    text: "Restart"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: rstMouse.containsMouse ? root.accentColor : root.textColor
                  }

                  MouseArea {
                    id: rstMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (currentServer && ocloud.containerAction) {
                        ocloud.containerAction(String(currentServer.id), modelData.id, "restart");
                      }
                    }
                  }
                }

                // Stop Container
                Rectangle {
                  implicitWidth: stpText.implicitWidth + 12
                  implicitHeight: 24
                  radius: 2
                  color: stpMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                    : "transparent"
                  border.color: stpMouse.containsMouse
                    ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                    : root.borderCol
                  border.width: 1

                  Text {
                    id: stpText
                    anchors.centerIn: parent
                    text: "Stop"
                    font.family: root.appFontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: stpMouse.containsMouse
                      ? ((typeof theme !== "undefined" && theme.red) ? theme.red : root.accentColor)
                      : root.mutedColor
                  }

                  MouseArea {
                    id: stpMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (currentServer && ocloud.containerAction) {
                        ocloud.containerAction(String(currentServer.id), modelData.id, "stop");
                      }
                    }
                  }
                }

                // Delete Container (Trash)
                Rectangle {
                  implicitWidth: 24
                  implicitHeight: 24
                  radius: 2
                  color: delMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.15) : "transparent"
                  border.color: delMouse.containsMouse ? "#f7768e" : root.borderCol
                  border.width: 1

                  ThemeIcon {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    source: "icons/trash.svg"
                    color: delMouse.containsMouse ? "#f7768e" : root.mutedColor
                  }

                  MouseArea {
                    id: delMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      consentModal.prompt(
                        "Delete Container",
                        "Are you sure you want to delete and force-remove container '" + modelData.name + "' on " + currentServer.name + "?",
                        function() {
                          ocloud.containerAction(String(currentServer.id), modelData.id, "delete");
                        }
                      );
                    }
                  }
                }
              }
            }
          }
        }
      }

      Item { Layout.preferredHeight: 6 }

      // =========================================================
      // WORKLOAD PLUGINS & TEMPLATES GRID
      // =========================================================
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "WORKLOAD TEMPLATES (" + root.workloadPlugins.length + " AVAILABLE)"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.mutedColor
          font.letterSpacing: 1.2
        }
        Item { Layout.fillWidth: true }
      }

      GridLayout {
        Layout.fillWidth: true
        columns: root.width > 900 ? 3 : (root.width > 600 ? 2 : 1)
        columnSpacing: 10
        rowSpacing: 8

        // Curated & Custom Plugins
        Repeater {
          model: root.workloadPlugins

          delegate: Rectangle {
            Layout.fillWidth: true
            implicitHeight: 68
            radius: 4
            color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
            border.color: tMouse.containsMouse ? root.accentColor : root.borderCol
            border.width: 1

            MouseArea {
              id: tMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.NoButton
            }

            // Left icon
            ThemeIcon {
              id: tIcon
              anchors.left: parent.left
              anchors.leftMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              width: 22
              height: 22
              source: modelData.iconSvg ? ("data:image/svg+xml;utf8," + encodeURIComponent(modelData.iconSvg)) : "icons/docker.svg"
              color: tMouse.containsMouse ? root.accentColor : root.textColor
            }

            // Right Deploy Button
            Rectangle {
              id: tBtn
              anchors.right: parent.right
              anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: tBtnText.implicitWidth + 14
              implicitHeight: 24
              radius: 2
              color: tBtnMouse.containsMouse
                ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
                : "transparent"
              border.color: tBtnMouse.containsMouse ? root.accentColor : root.borderCol
              border.width: 1

              Text {
                id: tBtnText
                anchors.centerIn: parent
                text: "Deploy"
                font.family: root.appFontFamily
                font.pixelSize: 10
                font.bold: true
                color: tBtnMouse.containsMouse ? root.accentColor : root.textColor
              }

              MouseArea {
                id: tBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  deployModal.targetPlugin = modelData;
                  deployModal.imgText = (modelData.workload && modelData.workload.image) || "";
                  deployModal.nameText = modelData.id || "";
                  deployModal.portsText = (modelData.workload && modelData.workload.ports) ? modelData.workload.ports.join(", ") : "";
                  deployModal.openModal();
                }
              }
            }

            // Center details
            ColumnLayout {
              anchors.left: tIcon.right
              anchors.leftMargin: 10
              anchors.right: tBtn.left
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              RowLayout {
                spacing: 6
                Text {
                  text: modelData.name
                  font.family: root.appFontFamily
                  font.pixelSize: 11
                  font.bold: true
                  color: root.textColor
                  elide: Text.ElideRight
                }

                Rectangle {
                  visible: !!modelData.badge
                  implicitWidth: bText.implicitWidth + 6
                  implicitHeight: 14
                  radius: 2
                  color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)
                  Text {
                    id: bText
                    anchors.centerIn: parent
                    text: modelData.badge || ""
                    font.family: root.appFontFamily
                    font.pixelSize: 8
                    font.bold: true
                    color: root.accentColor
                  }
                }
              }

              Text {
                Layout.fillWidth: true
                text: modelData.description || ""
                font.family: root.appFontFamily
                font.pixelSize: 9
                color: root.mutedColor
                elide: Text.ElideRight
              }
            }
          }
        }

        // "+ Add Custom Template" Card
        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 68
          radius: 4
          color: addTmplMouse.containsMouse ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.08) : "transparent"
          border.color: addTmplMouse.containsMouse ? root.accentColor : root.borderCol
          border.width: 1

          RowLayout {
            anchors.centerIn: parent
            spacing: 8

            ThemeIcon {
              width: 16
              height: 16
              source: "icons/plus.svg"
              color: addTmplMouse.containsMouse ? root.accentColor : root.mutedColor
            }

            Text {
              text: "+ Add Custom Template"
              font.family: root.appFontFamily
              font.pixelSize: 11
              font.bold: true
              color: addTmplMouse.containsMouse ? root.accentColor : root.textColor
            }
          }

          MouseArea {
            id: addTmplMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: customTmplModal.openModal()
          }
        }
      }
    }
  }

  // =========================================================
  // DEPLOY TO CLOUD MODAL
  // =========================================================
  Rectangle {
    id: deployModal
    visible: false
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.65)
    z: 2000

    property var targetPlugin: null
    property string imgText: ""
    property string nameText: ""
    property string portsText: ""
    property bool useTailscaleMesh: true

    function openModal() {
      imgField.text = imgText;
      nameField.text = nameText;
      portField.text = portsText;
      useTailscaleMesh = true;
      deployModal.visible = true;
    }

    MouseArea { anchors.fill: parent; onClicked: {} }

    Rectangle {
      width: Math.min(parent.width - 24, 480)
      implicitHeight: deployCol.implicitHeight + 32
      radius: 4
      color: (typeof theme !== "undefined" && theme.darkBackground) ? theme.darkBackground : "#13141c"
      border.color: root.accentColor
      border.width: 1
      anchors.centerIn: parent

      ColumnLayout {
        id: deployCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: deployModal.targetPlugin ? ("Deploy " + deployModal.targetPlugin.name) : "Offload Docker Container"
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "✕"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.mutedColor
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: deployModal.visible = false
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.borderCol }

        Text {
          text: "TARGET HOST: " + (currentServer ? (currentServer.name + " (" + (currentServer.tailscale_ip || currentServer.ipv4) + ")") : "No Server Selected")
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.accentColor
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "CONTAINER IMAGE"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: imgField
            Layout.fillWidth: true
            placeholderText: "e.g. postgres:16-alpine or redis:alpine"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "CONTAINER NAME"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: "e.g. my-app"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "PORT MAPPINGS"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: portField
            Layout.fillWidth: true
            placeholderText: "e.g. 5432:5432 or 8080:80"
          }
        }

        // Tailscale Mesh Binding Option
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text { text: "NETWORK EXPOSURE"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: tsOptCol.implicitHeight + 12
            radius: 3
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.08)
            border.color: deployModal.useTailscaleMesh ? root.accentColor : root.borderCol

            RowLayout {
              id: tsOptCol
              anchors.fill: parent
              anchors.margins: 6
              spacing: 8

              Rectangle {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                radius: 7
                color: deployModal.useTailscaleMesh ? root.accentColor : "transparent"
                border.color: root.accentColor
                border.width: 1
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Private Tailscale Mesh Binding (Recommended)"
                  font.family: root.appFontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: root.textColor
                }
                Text {
                  text: "Zero exposure to public internet. Accessible only from your authenticated mesh devices."
                  font.family: root.appFontFamily
                  font.pixelSize: 8
                  color: root.mutedColor
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: deployModal.useTailscaleMesh = !deployModal.useTailscaleMesh
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Layout.topMargin: 4

          Item { Layout.fillWidth: true }

          Rectangle {
            implicitWidth: cnclText.implicitWidth + 14
            implicitHeight: 26
            radius: 2
            color: "transparent"
            border.color: root.borderCol
            border.width: 1
            Text { id: cnclText; anchors.centerIn: parent; text: "Cancel"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.textColor }
            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deployModal.visible = false }
          }

          Rectangle {
            implicitWidth: runText.implicitWidth + 16
            implicitHeight: 26
            radius: 2
            color: root.accentColor
            Text {
              id: runText
              anchors.centerIn: parent
              text: root.deploying ? "Deploying..." : "Launch Container"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: !root.deploying && imgField.text.trim() !== "" && !!currentServer
              onClicked: {
                root.deploying = true;
                var srvId = String(currentServer.id);
                var config = {
                  image: imgField.text.trim(),
                  name: nameField.text.trim(),
                  ports: portField.text.trim(),
                  tailscale: deployModal.useTailscaleMesh
                };
                if (deployModal.targetPlugin && deployModal.targetPlugin.workload) {
                  var pW = deployModal.targetPlugin.workload;
                  if (pW.volumes) config.volumes = pW.volumes.join(",");
                  if (pW.env) config.env = pW.env;
                }
                ocloud.deployDockerContainer(srvId, config, function(ok, out) {
                  root.deploying = false;
                  if (ok) {
                    deployModal.visible = false;
                  }
                });
              }
            }
          }
        }
      }
    }
  }

  // =========================================================
  // CUSTOM TEMPLATE CREATOR MODAL
  // =========================================================
  Rectangle {
    id: customTmplModal
    visible: false
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.65)
    z: 2000

    function openModal() {
      tNameField.text = "";
      tIdField.text = "";
      tDescField.text = "";
      tImgField.text = "";
      tPortsField.text = "";
      customTmplModal.visible = true;
    }

    MouseArea { anchors.fill: parent; onClicked: {} }

    Rectangle {
      width: Math.min(parent.width - 24, 460)
      implicitHeight: tmplCol.implicitHeight + 32
      radius: 4
      color: (typeof theme !== "undefined" && theme.darkBackground) ? theme.darkBackground : "#13141c"
      border.color: root.accentColor
      border.width: 1
      anchors.centerIn: parent

      ColumnLayout {
        id: tmplCol
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "Create Custom Workload Template"
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
          }
          Item { Layout.fillWidth: true }
          Text {
            text: "✕"
            font.family: root.appFontFamily
            font.pixelSize: 12
            color: root.mutedColor
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: customTmplModal.visible = false
            }
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.borderCol }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "TEMPLATE NAME"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: tNameField
            Layout.fillWidth: true
            placeholderText: "e.g. Ghost Blog"
            onTextChanged: {
              if (!tIdField.focus) {
                tIdField.text = text.toLowerCase().replace(/[^a-z0-9]/g, "_");
              }
            }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "TEMPLATE ID (SLUG)"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: tIdField
            Layout.fillWidth: true
            placeholderText: "e.g. ghost_blog"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "DOCKER IMAGE TAG"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: tImgField
            Layout.fillWidth: true
            placeholderText: "e.g. ghost:alpine"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "DEFAULT PORTS"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: tPortsField
            Layout.fillWidth: true
            placeholderText: "e.g. 2368:2368"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text { text: "SHORT DESCRIPTION"; font.family: root.appFontFamily; font.pixelSize: 9; color: root.mutedColor }
          AppTextField {
            id: tDescField
            Layout.fillWidth: true
            placeholderText: "e.g. Headless CMS and newsletter engine"
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Layout.topMargin: 4

          Item { Layout.fillWidth: true }

          Rectangle {
            implicitWidth: cTmplCancel.implicitWidth + 14
            implicitHeight: 26
            radius: 2
            color: "transparent"
            border.color: root.borderCol
            border.width: 1
            Text { id: cTmplCancel; anchors.centerIn: parent; text: "Cancel"; font.family: root.appFontFamily; font.pixelSize: 10; color: root.textColor }
            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: customTmplModal.visible = false }
          }

          Rectangle {
            implicitWidth: cTmplSave.implicitWidth + 16
            implicitHeight: 26
            radius: 2
            color: root.accentColor
            Text {
              id: cTmplSave
              anchors.centerIn: parent
              text: "Save Template"
              font.family: root.appFontFamily
              font.pixelSize: 10
              font.bold: true
              color: (typeof theme !== "undefined" && theme.background) ? theme.background : "#000000"
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: tNameField.text.trim() !== "" && tImgField.text.trim() !== ""
              onClicked: {
                var ports = tPortsField.text.trim() ? tPortsField.text.trim().split(",").map(function(s){ return s.trim(); }) : [];
                var manifest = {
                  id: tIdField.text.trim(),
                  name: tNameField.text.trim(),
                  category: "workload",
                  badge: "Custom",
                  description: tDescField.text.trim(),
                  workload: {
                    image: tImgField.text.trim(),
                    ports: ports
                  }
                };
                ocloud.saveCustomWorkload(manifest, function(ok, out) {
                  customTmplModal.visible = false;
                });
              }
            }
          }
        }
      }
    }
  }
}
