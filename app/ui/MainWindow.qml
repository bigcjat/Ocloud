import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "components"
import "tabs"
import "wizard"
import "modals"

FloatingWindow {
  id: window
  visible: true
  implicitWidth: {
    var tw = Quickshell.env("OCLOUD_TEST_WIDTH");
    return tw ? parseInt(tw) : 1120;
  }
  implicitHeight: {
    var th = Quickshell.env("OCLOUD_TEST_HEIGHT");
    return th ? parseInt(th) : 740;
  }
  minimumSize: Qt.size(340, 360)
  title: "Ocloud — Cloud Storage & Compute Manager"
  color: theme.background

  // Live System Theme Provider matching Omarchy OS colors and typography
  Theme {
    id: theme
  }

  // Pure QML/JS Asynchronous Backend
  OcloudBackend {
    id: ocloud
  }

  // Global Design Tokens bound to the OS theme
  readonly property color bgDark: theme.bgDark
  readonly property color cardBg: theme.cardBg
  readonly property color cardBgAlt: theme.cardBgAlt
  readonly property color borderSubtle: theme.borderSubtle
  readonly property color borderActive: theme.borderActive
  readonly property color textPrimary: theme.textPrimary
  readonly property color textSecondary: theme.textSecondary
  readonly property color textMuted: theme.textMuted
  readonly property color accentSky: theme.accentSky
  readonly property color accentHover: theme.accentHover
  readonly property color homeGreen: theme.homeGreen
  readonly property color warningAmber: theme.warningAmber
  readonly property color dangerRed: theme.dangerRed
  readonly property string systemFont: theme.fontFamily

  // Responsive layout tiers for Omarchy / Hyprland tiling
  readonly property bool isQuarter: width < 580 || height < 480
  readonly property bool isHalf: width >= 580 && width < 980 && !isQuarter
  readonly property bool isFull: width >= 980 && !isQuarter

  // Reactive State
  property var statusData: ({})
  property var serverList: []
  property var storageBox: ({})
  property var r2Storage: ({})
  property var customStorage: []
  property var backupInfo: ({})
  property int cloudAccountsCount: 0
  property int mountedDrivesCount: 1
  property int networkSharesCount: 0
  property string activeTab: {
    var envTab = Quickshell.env("OCLOUD_TAB");
    if (envTab) return envTab;
    if (typeof initialTab !== "undefined" && initialTab) return initialTab;
    return "accounts";
  }
  property bool isBusy: false
  property string busyMessage: ""

  readonly property var tabModel: [
    { id: "fleet", name: "Compute Nodes", shortName: "Fleet", iconSvg: "icons/server.svg", count: serverList.length },
    { id: "workloads", name: "Workloads & Docker", shortName: "Docker", iconSvg: "icons/box.svg", count: 0 },
    { id: "storage", name: "Storage & Drives", shortName: "Storage", iconSvg: "icons/hard-drive.svg", count: mountedDrivesCount },
    { id: "accounts", name: "Cloud Accounts", shortName: "Accounts", iconSvg: "icons/user-circle.svg", count: cloudAccountsCount },
    { id: "shares", name: "Network Shares", shortName: "Shares", iconSvg: "icons/network.svg", count: networkSharesCount },
    { id: "apps", name: "App Streaming", shortName: "Apps", iconSvg: "icons/terminal.svg", count: 0 },
    { id: "backups", name: "Automated Backups", shortName: "Backups", iconSvg: "icons/archive.svg", count: 0 },
    { id: "settings", name: "Settings & Preferences", shortName: "Settings", iconSvg: "icons/settings.svg", count: 0 }
  ]

  function getActiveTabName() {
    for (var i = 0; i < tabModel.length; i++) {
      if (tabModel[i].id === activeTab) return tabModel[i].name;
    }
    return "Ocloud";
  }

  function calculateTotalFleetCost() {
    if (!serverList || serverList.length === 0) return "";
    var totalHourly = 0;
    var totalMonthly = 0;
    var symbol = "€";
    for (var i = 0; i < serverList.length; i++) {
      var s = serverList[i];
      if (s.status === "running" || !s.status) {
        var isGcp = (s.provider === "gcp");
        var h = (typeof s.priceHourly === "number") ? s.priceHourly : (s.pricing_hourly || (isGcp ? 0.0084 : 0.0058));
        var m = (typeof s.priceMonthly === "number") ? s.priceMonthly : (s.pricing_monthly || (isGcp ? 6.11 : 3.65));
        totalHourly += Number(h) || 0;
        totalMonthly += Number(m) || 0;
        if (s.currencySymbol) symbol = s.currencySymbol;
      }
    }
    if (totalHourly <= 0) return "";
    return symbol + totalHourly.toFixed(4) + " / hr (" + symbol + totalMonthly.toFixed(2) + " / mo)";
  }

  Shortcut { sequence: "Alt+1"; onActivated: activeTab = "fleet" }
  Shortcut { sequence: "Alt+2"; onActivated: activeTab = "workloads" }
  Shortcut { sequence: "Alt+3"; onActivated: activeTab = "storage" }
  Shortcut { sequence: "Alt+4"; onActivated: activeTab = "accounts" }
  Shortcut { sequence: "Alt+5"; onActivated: activeTab = "shares" }
  Shortcut { sequence: "Alt+6"; onActivated: activeTab = "apps" }
  Shortcut { sequence: "Alt+7"; onActivated: activeTab = "backups" }
  Shortcut { sequence: "Alt+8"; onActivated: activeTab = "settings" }

  function reloadAll() {
    ocloud.refreshStatusAsync();
  }

  Component.onCompleted: {
    var raw = ocloud.fetchStatus();
    try {
      var data = JSON.parse(raw);
      statusData = data;
      serverList = data.servers || [];
      storageBox = (data.storage && data.storage.storage_box) || {};
      r2Storage = (data.storage && data.storage.r2_storage) || {};
      customStorage = (data.storage && data.storage.custom_storage) || [];
      backupInfo = data.backups || {};
    } catch (e) {}

    try {
      var rawAccs = ocloud.fetchCloudAccounts();
      var accsInit = JSON.parse(rawAccs);
      cloudAccountsCount = accsInit.filter(function(a) { return a.type !== "smb"; }).length;
      var mountedClouds = accsInit.filter(function(a) { return a.isMounted; }).length;
      mountedDrivesCount = mountedClouds + networkSharesCount;
    } catch (e) {}

    var startModal = Quickshell.env("OCLOUD_MODAL") || (typeof openModalOnStart !== "undefined" ? openModalOnStart : "");
    if (startModal === "taskManager") {
      var srv = (serverList && serverList.length > 0) ? serverList[0] : null;
      if (srv) taskManagerModal.openForServer(srv);
    } else if (startModal === "procure") {
      procureModal.openModal(1);
    } else if (startModal === "procure-step2") {
      procureModal.openModal(2);
    } else if (startModal === "procure-step2-dedicated") {
      procureModal.openModal(2);
      procureModal.filterTenancy = "dedicated";
    } else if (startModal === "procure-step2-arm") {
      procureModal.openModal(2);
      procureModal.filterArch = "arm";
    } else if (startModal === "procure-step3") {
      procureModal.openModal(3);
    } else if (startModal === "procure-step4") {
      procureModal.openModal(4);
    } else if (startModal === "procure-step5") {
      procureModal.openModal(5);
    } else if (startModal === "procure-step6") {
      procureModal.openModal(6);
    } else if (startModal === "consent") {
      var srv2 = (serverList && serverList.length > 0) ? serverList[0] : null;
      if (srv2) consentModal.openForServer(srv2.name, String(srv2.id));
    } else if (startModal === "storage") {
      addStorageModal.openModal();
    } else if (startModal && startModal.indexOf("storage-") === 0) {
      var sParts = startModal.substring(8).split(":");
      addStorageModal.openModal(sParts[0]);
      if (sParts.length > 1) {
        addStorageModal.stepName = sParts[1];
      }
    }
  }

  property string toastMessage: ""
  property bool toastIsError: false
  property bool toastVisible: false

  Timer {
    id: toastTimer
    interval: 5000
    onTriggered: window.toastVisible = false
  }

  function showToast(message, isError) {
    toastMessage = message;
    toastIsError = isError;
    toastVisible = true;
    toastTimer.restart();
  }

  Connections {
    target: ocloud
    function onActionCompleted(action, success, msg) {
      if (msg && action !== "setBackupSchedule" && action !== "refresh") {
        window.showToast(msg, !success);
      }
    }
    function onStatusUpdated(jsonStr) {
      try {
        var data = JSON.parse(jsonStr);
        statusData = data;
        serverList = data.servers || [];
        storageBox = (data.storage && data.storage.storage_box) || {};
        r2Storage = (data.storage && data.storage.r2_storage) || {};
        customStorage = (data.storage && data.storage.custom_storage) || [];
        backupInfo = data.backups || {};

        var startModal = Quickshell.env("OCLOUD_MODAL") || (typeof openModalOnStart !== "undefined" ? openModalOnStart : "");
        if (startModal === "taskManager" && !taskManagerModal.visible) {
          var srv = (serverList && serverList.length > 0) ? serverList[0] : null;
          if (srv) taskManagerModal.openForServer(srv);
        } else if (startModal === "consent" && !consentModal.visible) {
          var srv2 = (serverList && serverList.length > 0) ? serverList[0] : null;
          if (srv2) consentModal.openForServer(srv2.name, String(srv2.id));
        }
      } catch (e) {}
    }
    function onBusyChanged(busy, text) {
      window.isBusy = busy;
      window.busyMessage = text;
    }
    function onCloudAccountsUpdated(jsonStr) {
      try {
        var accs = JSON.parse(jsonStr);
        cloudAccountsCount = accs.filter(function(a) { return a.type !== "smb"; }).length;
        var mountedClouds = accs.filter(function(a) { return a.isMounted; }).length;
        mountedDrivesCount = mountedClouds + networkSharesCount;
      } catch (e) {}
    }
  }

  // Master Column Layout: Top Header + Main Body (Sidebar & Content) + Quarter Bottom Nav
  ColumnLayout {
    anchors.fill: parent
    spacing: 0

    // Top Titlebar / Header: Matches OS Theme & Adapts Height
    Rectangle {
      id: headerBar
      Layout.fillWidth: true
      Layout.preferredHeight: window.isQuarter ? 42 : (window.isHalf ? 48 : 56)
      color: theme.headerBg
      border.color: theme.borderSubtle
      border.width: 1

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: window.isQuarter ? 10 : 16
        anchors.rightMargin: window.isQuarter ? 10 : 16
        spacing: window.isQuarter ? 8 : 14

        // Brand Logo
        RowLayout {
          spacing: 8
          Rectangle {
            width: window.isQuarter ? 24 : 28
            height: window.isQuarter ? 24 : 28
            radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
            color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.15)
            border.color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.35)
            border.width: 1

            Image {
              anchors.centerIn: parent
              width: window.isQuarter ? 16 : 18
              height: window.isQuarter ? 16 : 18
              source: Qt.resolvedUrl("icons/ocloud.svg")
              fillMode: Image.PreserveAspectFit
              smooth: true
            }
          }

          Text {
            text: "Ocloud"
            font.family: theme.fontFamily
            font.pixelSize: window.isQuarter ? 13 : 15
            font.bold: true
            color: theme.textPrimary
          }

          Text {
            visible: window.isFull
            text: "Personal Cloud Manager"
            font.family: theme.fontFamily
            font.pixelSize: 11
            color: theme.textMuted
          }

          Text {
            visible: window.isQuarter
            text: "· " + getActiveTabName()
            font.family: theme.fontFamily
            font.pixelSize: 11
            font.bold: true
            color: theme.accentSky
            elide: Text.ElideRight
            Layout.maximumWidth: 120
          }
        }

        // Live Busy Indicator Pill
        Rectangle {
          visible: window.isBusy
          height: window.isQuarter ? 22 : 26
          width: window.isQuarter ? 22 : (busyRow.implicitWidth + 16)
          radius: height / 2
          color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.2)
          border.color: theme.accentSky
          border.width: 1

          Row {
            id: busyRow
            anchors.centerIn: parent
            spacing: 6
            Canvas {
              width: 12
              height: 12
              anchors.verticalCenter: parent.verticalCenter
              onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 2;
                ctx.strokeStyle = theme.accentSky;
                ctx.beginPath();
                ctx.arc(6, 6, 4, 0, 1.5 * Math.PI);
                ctx.stroke();
              }
              RotationAnimator on rotation {
                from: 0
                to: 360
                duration: 800
                loops: Animation.Infinite
                running: window.isBusy
              }
            }
            Text {
              visible: !window.isQuarter
              text: window.busyMessage || "Working..."
              font.family: theme.fontFamily
              font.pixelSize: 10
              font.bold: true
              color: theme.textPrimary
            }
          }
        }

        Item { Layout.fillWidth: true }

        // Status Indicators (Quiet, theme-reactive, no chunky badges)
        RowLayout {
          visible: !window.isQuarter
          spacing: 12

          RowLayout {
            spacing: 6
            Rectangle {
              width: 6; height: 6; radius: 3
              color: serverList.length > 0
                ? ((typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : "#9ece6a")
                : theme.textMuted
            }
            Text {
              text: serverList.length + (serverList.length === 1 ? (window.isHalf ? " Node" : " Node Online") : (window.isHalf ? " Nodes" : " Nodes Online"))
              font.family: theme.fontFamily
              font.pixelSize: 11
              color: theme.textSecondary
            }
          }

          RowLayout {
            visible: serverList.length > 0 && !!calculateTotalFleetCost()
            spacing: 6
            Rectangle {
              width: 6; height: 6; radius: 3
              color: theme.accent
            }
            Text {
              text: calculateTotalFleetCost()
              font.family: theme.fontFamily
              font.pixelSize: 11
              color: theme.textSecondary
            }
          }

          RowLayout {
            visible: !!(storageBox && storageBox.configured) && window.isFull
            spacing: 6
            Rectangle {
              width: 6; height: 6; radius: 3
              color: (storageBox && storageBox.mounted)
                ? ((typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : "#9ece6a")
                : theme.textMuted
            }
            Text {
              text: (storageBox && storageBox.mounted) ? "Storage Box Mounted" : "Storage Box Offline"
              font.family: theme.fontFamily
              font.pixelSize: 11
              color: theme.textSecondary
            }
          }
        }
      }
    }

    // Main Body: Left Sidebar (Full/Half) + Content
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 0

      // Left Navigation Sidebar: Adapts between Full (210px) and Half (56px rail); Hidden in Quarter
      Rectangle {
        id: navSidebar
        visible: !window.isQuarter
        Layout.fillHeight: true
        Layout.preferredWidth: window.isHalf ? 56 : 210
        color: theme.sidebarBg
        border.color: theme.borderSubtle
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: window.isHalf ? 6 : 10
          spacing: 4

          // Nav Items
          Repeater {
            model: window.tabModel

            delegate: Rectangle {
              Layout.fillWidth: true
              height: window.isHalf ? 40 : 42
              radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
              color: activeTab === modelData.id ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.18) : navMouse.containsMouse ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.08) : "transparent"
              border.color: activeTab === modelData.id ? theme.accent : "transparent"
              border.width: 1

              // Full View: Icon + Full Label + Right Badge
              RowLayout {
                visible: !window.isHalf
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: badgeRect.visible ? badgeRect.left : parent.right
                anchors.rightMargin: badgeRect.visible ? 6 : 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Image {
                  width: 16
                  height: 16
                  source: Qt.resolvedUrl(modelData.iconSvg)
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.name
                  font.family: theme.fontFamily
                  font.pixelSize: 11
                  font.bold: activeTab === modelData.id
                  color: activeTab === modelData.id ? theme.textPrimary : theme.textSecondary
                  elide: Text.ElideRight
                }
              }

              // Pinned Count (Full view) - Clean quiet muted text, no chunky light-on-light pill
              Text {
                id: badgeText
                visible: !window.isHalf && modelData.count > 0 && (modelData.id === "fleet" || modelData.id === "storage" || modelData.id === "accounts" || modelData.id === "shares")
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: String(modelData.count)
                font.family: theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                color: activeTab === modelData.id ? theme.accent : theme.textMuted
              }

              // Half View: Centered Icon + Dot Badge
              Item {
                visible: window.isHalf
                anchors.fill: parent

                Image {
                  anchors.centerIn: parent
                  width: 18
                  height: 18
                  source: Qt.resolvedUrl(modelData.iconSvg)
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                }

                // Dot badge for rail mode
                Rectangle {
                  visible: modelData.count > 0 && (modelData.id === "fleet" || modelData.id === "storage" || modelData.id === "accounts" || modelData.id === "shares")
                  anchors.top: parent.top
                  anchors.right: parent.right
                  anchors.topMargin: 6
                  anchors.rightMargin: 6
                  width: 6
                  height: 6
                  radius: 3
                  color: theme.accentSky
                }
              }

              MouseArea {
                id: navMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: activeTab = modelData.id
              }

              ToolTip.visible: navMouse.containsMouse && window.isHalf
              ToolTip.text: modelData.name
              ToolTip.delay: 300
            }
          }

          Item { Layout.fillHeight: true }

          // Bottom Host Machine Card (Full view)
          Rectangle {
            visible: !window.isHalf
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            implicitHeight: 48
            radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
            color: theme.cardBgAlt
            border.color: theme.borderSubtle

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 8

              Image {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                source: Qt.resolvedUrl("icons/device-desktop.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                  text: "Local Host"
                  font.family: theme.fontFamily
                  font.pixelSize: 10
                  font.bold: true
                  color: theme.textPrimary
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  text: "Omarchy Linux"
                  font.family: theme.fontFamily
                  font.pixelSize: 9
                  color: theme.textMuted
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }
        }
      }

      // Right Multi-Tab Content View
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: theme.background

        StackLayout {
          anchors.fill: parent
          currentIndex: {
            if (activeTab === "fleet") return 0;
            if (activeTab === "workloads") return 1;
            if (activeTab === "storage") return 2;
            if (activeTab === "accounts") return 3;
            if (activeTab === "shares") return 4;
            if (activeTab === "apps") return 5;
            if (activeTab === "backups") return 6;
            if (activeTab === "settings") return 7;
            return 0;
          }

          FleetTab { id: fleetView }
          WorkloadsTab { id: workloadsView }
          StorageTab { id: storageView }
          CloudAccountsTab { id: cloudAccountsView }
          NetworkSharesTab { id: networkSharesView }
          AppSuiteTab { id: appSuiteView }
          BackupTab { id: backupView }
          SettingsTab { id: settingsView }
        }
      }
    }

    // Bottom Navigation Bar (Quarter 1/4 layout only): Gives 100% width to content!
    Rectangle {
      id: bottomNavBar
      visible: window.isQuarter
      Layout.fillWidth: true
      Layout.preferredHeight: 44
      color: theme.sidebarBg
      border.color: theme.borderSubtle
      border.width: 1

      RowLayout {
        anchors.fill: parent
        spacing: 2

        Repeater {
          model: window.tabModel

          delegate: Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: activeTab === modelData.id ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.22) : bNavMouse.containsMouse ? Qt.rgba(theme.foreground.r, theme.foreground.g, theme.foreground.b, 0.08) : "transparent"

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2

              Image {
                Layout.alignment: Qt.AlignHCenter
                width: 16
                height: 16
                source: Qt.resolvedUrl(modelData.iconSvg)
                fillMode: Image.PreserveAspectFit
                smooth: true
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: modelData.shortName
                font.family: theme.fontFamily
                font.pixelSize: 8
                font.bold: activeTab === modelData.id
                color: activeTab === modelData.id ? theme.accentSky : theme.textMuted
              }
            }

            // Top active accent bar
            Rectangle {
              visible: activeTab === modelData.id
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              height: 2
              color: theme.accentSky
            }

            MouseArea {
              id: bNavMouse
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: activeTab = modelData.id
            }
          }
        }
      }
    }
  }

  // Global Ephemeral Consent Modal
  EphemeralConsentModal {
    id: consentModal
    onConfirmed: function(serverId) {
      ocloud.mountEphemeralVm(serverId);
    }
  }

  // Global Add Node Modal
  AddNodeModal {
    id: addNodeModal
  }

  // Global Procure VM Wizard
  ProcureWizard {
    id: procureModal
  }

  // Global Machine Task Manager Modal
  MachineTaskManagerModal {
    id: taskManagerModal
  }

  // Global Add Storage Wizard
  AddStorageWizard {
    id: addStorageModal
  }

  // Global Floating Notification Toast
  Rectangle {
    id: toastOverlay
    visible: window.toastVisible
    opacity: window.toastVisible ? 1.0 : 0.0
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: window.isQuarter ? 8 : 16
    z: 99999
    width: Math.min(window.width - 24, Math.max(260, toastRow.implicitWidth + 32))
    height: Math.max(46, toastRow.implicitHeight + 16)
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 8
    color: window.toastIsError ? Qt.rgba(theme.dangerRed.r, theme.dangerRed.g, theme.dangerRed.b, 0.95) : Qt.rgba(theme.cardBg.r, theme.cardBg.g, theme.cardBg.b, 0.95)
    border.color: window.toastIsError ? theme.dangerRed : theme.homeGreen
    border.width: 1

    Behavior on opacity { NumberAnimation { duration: 180 } }

    RowLayout {
      id: toastRow
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 10

      Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 5
        color: window.toastIsError ? Qt.rgba(1, 0, 0, 0.25) : Qt.rgba(theme.homeGreen.r, theme.homeGreen.g, theme.homeGreen.b, 0.25)

        Image {
          anchors.centerIn: parent
          width: 14
          height: 14
          source: Qt.resolvedUrl(window.toastIsError ? "icons/alert-triangle.svg" : "icons/shield.svg")
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
      }

      Text {
        Layout.fillWidth: true
        text: window.toastMessage
        color: "#ffffff"
        font.family: theme.fontFamily
        font.pixelSize: 11
        font.bold: true
        wrapMode: Text.WordWrap
      }

      Rectangle {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        radius: 9
        color: toastCloseMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"

        Text {
          anchors.centerIn: parent
          text: "✕"
          color: "#ffffff"
          font.pixelSize: 10
          font.bold: true
        }

        MouseArea {
          id: toastCloseMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: window.toastVisible = false
        }
      }
    }
  }
}
