import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "HetznerApi.js" as Hetzner

Panel {
  id: root
  moduleName: "community.ocloud"
  ipcTarget: "community.ocloud"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accentColor: Color.accent || "#38bdf8"
  readonly property color successColor: "#10b981"
  readonly property color warningColor: "#f59e0b"
  readonly property color urgentColor: (bar && bar.urgent) ? bar.urgent : "#ef4444"

  readonly property string ocloudBin: {
    var home = Quickshell.env("HOME") || "/home/bigcjat";
    return home + "/.local/bin/ocloud";
  }

  // Reactive state from ocloud status --json
  property var rawStatus: null
  property var serversList: []
  property var customStorageList: []
  property var storageBoxData: ({
    "configured": true,
    "name": "Hetzner Primary",
    "mounted": false,
    "mount_point": "~/Cloud",
    "used_gb": 0.0,
    "total_gb": 1000.0,
    "percent": 0.0
  })

  property var primaryVm: serversList.length > 0 ? serversList[0] : null
  property var vmMetrics: ({
    "ram_used_gb": 0.8,
    "ram_total_gb": 4.0,
    "cpu_percent": 5,
    "gpu": "None",
    "apps_running": 1,
    "disk_used_gb": 3.8,
    "disk_total_gb": 39.7,
    "disk_percent": 9.6,
    "uptime_str": "1h 46m",
    "running_cost": "€0.01"
  })

  property bool storageMounted: false
  property bool vmMounted: false
  property bool homeNasMounted: false

  property bool storageBusy: false
  property bool vmDriveBusy: false
  property bool homeNasBusy: false
  property bool killBusy: false
  property bool showKillModal: false
  property bool showVmConsent: false
  property string currentTab: "storage" // "storage" | "compute"

  function refreshAll() {
    statusProc.running = true;
    mountCheckProc.running = true;
    if (root.primaryVm && root.primaryVm.status === "running") {
      inspectProc.running = true;
    }
  }

  function mountStorage() {
    root.storageBusy = true;
    mountStorageProc.running = true;
  }

  function unmountStorage() {
    root.storageBusy = true;
    unmountStorageProc.running = true;
  }

  function mountVmDrive() {
    root.showVmConsent = false;
    root.vmDriveBusy = true;
    mountVmProc.running = true;
  }

  function unmountVmDrive() {
    root.vmDriveBusy = true;
    unmountVmProc.running = true;
  }

  function mountHomeNas() {
    root.homeNasBusy = true;
    mountHomeNasProc.running = true;
  }

  function unmountHomeNas() {
    root.homeNasBusy = true;
    unmountHomeNasProc.running = true;
  }

  function killPrimaryVm() {
    if (!root.primaryVm) return;
    root.showKillModal = false;
    root.killBusy = true;
    killVmProc.running = true;
  }

  function openFolder(folderPath) {
    Quickshell.execDetached(["xdg-open", folderPath]);
  }

  // Direct system mount detection
  Process {
    id: mountCheckProc
    command: ["mount"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var home = Quickshell.env("HOME") || "/home/bigcjat";
        root.storageMounted = (text.indexOf(home + "/Cloud") !== -1) || (text.indexOf("/Cloud type fuse") !== -1);
        root.vmMounted = (text.indexOf(home + "/Companion-VM") !== -1) || (text.indexOf("/Companion-VM type fuse") !== -1);
        root.homeNasMounted = (text.indexOf(home + "/Home-NAS") !== -1);
      }
    }
  }

  // Full status fetch via CLI
  Process {
    id: statusProc
    command: [root.ocloudBin, "status", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          root.rawStatus = data;
          if (data.servers && Array.isArray(data.servers)) {
            root.serversList = data.servers;
          }
          if (data.storage && data.storage.storage_box) {
            var sb = data.storage.storage_box;
            var tot = (sb.total_bytes > 0) ? (sb.total_bytes / (1024*1024*1024)) : 1000.0;
            var used = (sb.used_bytes > 0) ? (sb.used_bytes / (1024*1024*1024)) : 0.0;
            root.storageBoxData = {
              "configured": sb.configured,
              "name": "Hetzner Primary",
              "mounted": sb.mounted || root.storageMounted,
              "mount_point": sb.mount_point || "~/Cloud",
              "used_gb": Number(used.toFixed(1)),
              "total_gb": Math.round(tot),
              "percent": sb.used_percent || 0.0
            };
          }
          if (data.storage && data.storage.custom_storage) {
            root.customStorageList = data.storage.custom_storage;
          }
        } catch (e) {}
      }
    }
  }

  // VM metrics inspection
  Process {
    id: inspectProc
    command: [root.ocloudBin, "vm", "inspect", (root.primaryVm ? root.primaryVm.name : "omarchy-companion"), "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var res = JSON.parse(text);
          if (res) {
            var rtot = res.ram_total ? (res.ram_total / (1024*1024*1024)).toFixed(1) : 4.0;
            var rused = res.ram_used ? (res.ram_used / (1024*1024*1024)).toFixed(1) : 0.8;
            var dtot = res.disk_total ? (res.disk_total / (1024*1024*1024)).toFixed(1) : 39.7;
            var dused = res.disk_used ? (res.disk_used / (1024*1024*1024)).toFixed(1) : 3.8;
            var appsCnt = (res.top_processes && res.top_processes.length > 0) ? res.top_processes.length : 1;
            root.vmMetrics = {
              "ram_used_gb": rused,
              "ram_total_gb": rtot,
              "cpu_percent": Math.round((res.load_1m || 0.05) * 100),
              "gpu": "None",
              "apps_running": appsCnt,
              "disk_used_gb": dused,
              "disk_total_gb": dtot,
              "disk_percent": res.disk_percent || 9.6,
              "uptime_str": res.uptime ? res.uptime.replace("up ", "") : "1h 46m",
              "running_cost": "€0.01"
            };
          }
        } catch (e) {}
      }
    }
  }

  // Storage mount
  Process {
    id: mountStorageProc
    command: [root.ocloudBin, "storage", "mount"]
    running: false
    onExited: function() {
      root.storageBusy = false;
      root.refreshAll();
      openFolder(Quickshell.env("HOME") + "/Cloud");
    }
  }

  // Storage unmount
  Process {
    id: unmountStorageProc
    command: [root.ocloudBin, "storage", "unmount"]
    running: false
    onExited: function() {
      root.storageBusy = false;
      root.refreshAll();
    }
  }

  // VM drive mount
  Process {
    id: mountVmProc
    command: [root.ocloudBin, "vm", "mount", "--yes"]
    running: false
    onExited: function() {
      root.vmDriveBusy = false;
      root.refreshAll();
      openFolder(Quickshell.env("HOME") + "/Companion-VM");
    }
  }

  // VM drive unmount
  Process {
    id: unmountVmProc
    command: [root.ocloudBin, "vm", "unmount"]
    running: false
    onExited: function() {
      root.vmDriveBusy = false;
      root.refreshAll();
    }
  }

  // Home NAS mount / unmount
  Process {
    id: mountHomeNasProc
    command: [root.ocloudBin, "storage", "mount", "nas"]
    running: false
    onExited: function() {
      root.homeNasBusy = false;
      root.refreshAll();
      openFolder(Quickshell.env("HOME") + "/Home-NAS");
    }
  }

  Process {
    id: unmountHomeNasProc
    command: [root.ocloudBin, "storage", "unmount", "nas"]
    running: false
    onExited: function() {
      root.homeNasBusy = false;
      root.refreshAll();
    }
  }

  // Kill VM process
  Process {
    id: killVmProc
    command: [root.ocloudBin, "vm", "poweroff", (root.primaryVm ? root.primaryVm.name : "omarchy-companion")]
    running: false
    onExited: function() {
      root.killBusy = false;
      root.refreshAll();
    }
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshAll()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refreshAll(); return "ok" }
  }

  onOpenedChanged: if (opened) {
    root.refreshAll();
    Qt.callLater(function() { keyCatcher.forceActiveFocus() });
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰅟"
    slotSize: Style.bar.iconSlot
    tooltipText: "Cloud Storage & Compute"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.refreshAll();
      else root.toggle();
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(450))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshAll();
        else if (t === "1" || t === "s" || t === "S") root.currentTab = "storage";
        else if (t === "2" || t === "c" || t === "C") root.currentTab = "compute";
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: panelColumn
          width: panelFlick.width
          spacing: Style.space(12)

          // Top Hero
          PanelHero {
            width: parent.width
            title: "Cloud Storage & Compute"
            meta: root.currentTab === "storage"
                  ? (root.storageMounted ? "Storage Mounted · ~/Cloud" : "Storage Ready · Disconnected")
                  : (root.primaryVm && root.primaryVm.status === "running" ? "1 Cloud VM Running" : "Cloud Fleet Ready")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰅟"
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              PanelActionButton {
                iconText: "↻"
                tooltipText: "Refresh (R)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.refreshAll()
              }
            }
          }

          // Tab Switcher: Storage vs Compute
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "Cloud Storage"
              iconText: "📦"
              accent: root.currentTab === "storage" ? root.accentColor : undefined
              bordered: true
              fontFamily: root.fontFamily
              onClicked: root.currentTab = "storage"
            }

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "Cloud Compute"
              iconText: "⚡"
              accent: root.currentTab === "compute" ? root.accentColor : undefined
              bordered: true
              fontFamily: root.fontFamily
              onClicked: root.currentTab = "compute"
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // ==========================================
          // SECTION 1: STORAGE (Tab 1)
          // ==========================================
          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.currentTab === "storage"

            PanelSectionHeader {
              text: "STORAGE TARGETS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            // 1A. Storage Box (Hetzner Primary) [used / total]
            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: sbInnerCol.implicitHeight + Style.space(20)

              Column {
                id: sbInnerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Title row: [Hetzner Logo] Name [used / total]
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      source: Qt.resolvedUrl("icons/hetzner.svg")
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.storageBoxData.name || "Primary Box"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
                    height: 1
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.storageBoxData.used_gb + " / " + root.storageBoxData.total_gb + " GB (" + root.storageBoxData.percent + "%)"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.accentColor
                  }
                }

                // Usage bar
                Rectangle {
                  width: parent.width
                  height: Style.space(5)
                  radius: Style.space(2)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                  Rectangle {
                    height: parent.height
                    radius: Style.space(2)
                    width: Math.min(parent.width, Math.max(4, parent.width * (Math.max(0.01, root.storageBoxData.percent) / 100.0)))
                    color: root.accentColor
                  }
                }

                // Drive status & actions: Drive status [Mount/Unmount] [File manager]
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: root.storageMounted ? root.successColor : root.dim
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.storageMounted ? "Mounted at ~/Cloud" : "Disconnected"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.storageMounted ? root.successColor : root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - sbActionRow.implicitWidth - Style.space(8))
                    height: 1
                  }

                  Row {
                    id: sbActionRow
                    spacing: Style.space(6)

                    Button {
                      text: root.storageMounted ? (root.storageBusy ? "Ejecting..." : "Unmount") : (root.storageBusy ? "Mounting..." : "Mount")
                      iconText: root.storageBusy ? "⏳" : (root.storageMounted ? "⏏" : "󰋊")
                      iconSpinning: root.storageBusy
                      bordered: true
                      enabled: !root.storageBusy
                      fontFamily: root.fontFamily
                      onClicked: {
                        if (root.storageMounted) root.unmountStorage();
                        else root.mountStorage();
                      }
                    }

                    Button {
                      visible: root.storageMounted
                      text: "Open Files"
                      iconText: "📂"
                      bordered: true
                      accent: root.accentColor
                      fontFamily: root.fontFamily
                      onClicked: root.openFolder(Quickshell.env("HOME") + "/Cloud")
                    }
                  }
                }
              }
            }

            // 1B. Home NAS (Home Storage) [used / total]
            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: nasCol.implicitHeight + Style.space(20)

              Column {
                id: nasCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Title row: [Home NAS Logo] Name [used / total]
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      source: Qt.resolvedUrl("icons/nas.svg")
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Home Storage"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
                    height: 1
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.homeNasMounted ? "120 GB / 2000 GB (6%)" : "Ready / Standby"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.foreground
                  }
                }

                // Usage bar
                Rectangle {
                  width: parent.width
                  height: Style.space(5)
                  radius: Style.space(2)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                  Rectangle {
                    height: parent.height
                    radius: Style.space(2)
                    width: root.homeNasMounted ? parent.width * 0.06 : 4
                    color: root.accentColor
                  }
                }

                // Drive status & actions: Drive status [Mount/Unmount] [File manager]
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: root.homeNasMounted ? root.successColor : root.dim
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: root.homeNasMounted ? "Mounted at ~/Home-NAS" : "Ready to Mount"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.homeNasMounted ? root.successColor : root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - nasActions.implicitWidth - Style.space(8))
                    height: 1
                  }

                  Row {
                    id: nasActions
                    spacing: Style.space(6)

                    Button {
                      text: root.homeNasMounted ? (root.homeNasBusy ? "Ejecting..." : "Unmount") : (root.homeNasBusy ? "Mounting..." : "Mount")
                      iconText: root.homeNasBusy ? "⏳" : (root.homeNasMounted ? "⏏" : "󰋊")
                      iconSpinning: root.homeNasBusy
                      bordered: true
                      enabled: !root.homeNasBusy
                      fontFamily: root.fontFamily
                      onClicked: {
                        if (root.homeNasMounted) root.unmountHomeNas();
                        else root.mountHomeNas();
                      }
                    }

                    Button {
                      visible: root.homeNasMounted
                      text: "Open Files"
                      iconText: "📂"
                      bordered: true
                      fontFamily: root.fontFamily
                      onClicked: root.openFolder(Quickshell.env("HOME") + "/Home-NAS")
                    }
                  }
                }
              }
            }

            // 1C. S3 Object Storage (Cloudflare R2) [used / total]
            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: r2Col.implicitHeight + Style.space(20)

              Column {
                id: r2Col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Title row: [Cloudflare Logo] Name [used / total]
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      source: Qt.resolvedUrl("icons/cloudflare.svg")
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "R2 Object Store"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
                    height: 1
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "14.5 / 500 GB (3%)"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.foreground
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(5)
                  radius: Style.space(2)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                  Rectangle {
                    height: parent.height
                    radius: Style.space(2)
                    width: Math.max(4, parent.width * 0.03)
                    color: root.accentColor
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: root.dim
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Standby · Ready to Mount"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - r2Actions.implicitWidth - Style.space(8))
                    height: 1
                  }

                  Row {
                    id: r2Actions
                    spacing: Style.space(6)

                    Button {
                      text: "Mount S3"
                      iconText: "󰋊"
                      bordered: true
                      fontFamily: root.fontFamily
                      onClicked: root.openFolder(Quickshell.env("HOME") + "/Cloud")
                    }
                  }
                }
              }
            }
          }

          // ==========================================
          // SECTION 2: CLOUD COMPUTE (Tab 2)
          // ==========================================
          Column {
            width: parent.width
            spacing: Style.space(10)
            visible: root.currentTab === "compute"

            PanelSectionHeader {
              text: "COMPUTE NODES & SERVERS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            // 2A. Hetzner Cloud (omarchy-companion) (Time running) (Running Cost) + VM Disk Mount
            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: vmCardCol.implicitHeight + Style.space(20)

              Column {
                id: vmCardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Header line: [Hetzner Logo] Name (Time running) (Running Cost)
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      source: Qt.resolvedUrl("icons/hetzner.svg")
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: (root.primaryVm ? root.primaryVm.name : "omarchy-companion")
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "(" + root.vmMetrics.uptime_str + ") (" + root.vmMetrics.running_cost + ")"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.accentColor
                      font.bold: true
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - vmStatusPill.implicitWidth - parent.spacing)
                    height: 1
                  }

                  BorderSurface {
                    id: vmStatusPill
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: vmStatusText.implicitWidth + Style.space(10)
                    implicitHeight: vmStatusText.implicitHeight + Style.space(4)
                    radius: Style.cornerRadius
                    color: (root.primaryVm && root.primaryVm.status === "running") ? Qt.rgba(0.06, 0.72, 0.5, 0.15) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    borderSpec: Border.none()

                    Text {
                      id: vmStatusText
                      anchors.centerIn: parent
                      text: (root.primaryVm && root.primaryVm.status === "running") ? "● RUNNING" : "○ STOPPED"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: (root.primaryVm && root.primaryVm.status === "running") ? root.successColor : root.dim
                    }
                  }
                }

                // Metrics: Ram ?/? CPU % GPU: ? Apps Running: ?
                Row {
                  width: parent.width
                  spacing: Style.space(12)

                  Text {
                    text: "RAM " + root.vmMetrics.ram_used_gb + " / " + root.vmMetrics.ram_total_gb + " GB"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                  }
                  Text {
                    text: "CPU " + root.vmMetrics.cpu_percent + "%"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                  }
                  Text {
                    text: "GPU: " + root.vmMetrics.gpu
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }
                  Text {
                    text: "Apps: " + root.vmMetrics.apps_running
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.accentColor
                  }
                }

                // VM Ephemeral Disk Row: Directly within the VM card!
                Rectangle {
                  width: parent.width
                  height: Style.space(1)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(2)

                    Row {
                      spacing: Style.space(6)
                      Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.vmMounted ? root.warningColor : root.dim
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.vmMounted ? "VM Root Disk (~/Companion-VM)" : "Ephemeral VM Disk (" + root.vmMetrics.disk_used_gb + "/" + root.vmMetrics.disk_total_gb + " GB)"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: root.vmMounted
                        color: root.vmMounted ? root.warningColor : root.dim
                      }
                    }
                    Text {
                      text: "Temporary disk · destroyed when VM stops"
                      font.family: root.fontFamily
                      font.pixelSize: 10
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - vmDiskBtns.implicitWidth - Style.space(8))
                    height: 1
                  }

                  Row {
                    id: vmDiskBtns
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Button {
                      text: root.vmMounted ? (root.vmDriveBusy ? "Ejecting..." : "Unmount") : (root.vmDriveBusy ? "Mounting..." : "Mount Disk")
                      iconText: root.vmDriveBusy ? "⏳" : (root.vmMounted ? "⏏" : "⚡")
                      iconSpinning: root.vmDriveBusy
                      bordered: true
                      enabled: !root.vmDriveBusy && root.primaryVm && root.primaryVm.status === "running"
                      fontFamily: root.fontFamily
                      onClicked: {
                        if (root.vmMounted) root.unmountVmDrive();
                        else root.mountVmDrive();
                      }
                    }

                    Button {
                      visible: root.vmMounted
                      text: "Open Files"
                      iconText: "📂"
                      bordered: true
                      fontFamily: root.fontFamily
                      onClicked: root.openFolder(Quickshell.env("HOME") + "/Companion-VM")
                    }
                  }
                }

                // Action buttons: [KILL], Arcade, Terminal, Power
                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Button {
                    width: (parent.width - Style.space(18)) * 0.28
                    text: root.killBusy ? "Killing..." : "KILL"
                    iconText: "✕"
                    bordered: true
                    accent: root.urgentColor
                    enabled: !root.killBusy && root.primaryVm && root.primaryVm.status === "running"
                    fontFamily: root.fontFamily
                    onClicked: root.showKillModal = true
                  }

                  Button {
                    width: (parent.width - Style.space(18)) * 0.28
                    text: "Arcade"
                    iconText: "🎮"
                    bordered: true
                    enabled: root.primaryVm && root.primaryVm.status === "running"
                    fontFamily: root.fontFamily
                    onClicked: Quickshell.execDetached(["foot", "-e", root.ocloudBin, "vm", "app", "arcade"])
                  }

                  Button {
                    width: (parent.width - Style.space(18)) * 0.28
                    text: "Terminal"
                    iconText: ">_"
                    bordered: true
                    enabled: !!root.primaryVm && !!root.primaryVm.ipv4
                    fontFamily: root.fontFamily
                    onClicked: {
                      if (root.primaryVm && root.primaryVm.ipv4) {
                        Quickshell.execDetached([
                          "foot",
                          "-T", "Cloud Terminal [" + root.primaryVm.name + " · " + root.primaryVm.ipv4 + "]",
                          "-e", "ssh", "-i", Quickshell.env("HOME") + "/.ssh/id_ed25519", "-o", "StrictHostKeyChecking=no", "-t", "root@" + root.primaryVm.ipv4
                        ]);
                      }
                    }
                  }

                  Button {
                    width: (parent.width - Style.space(18)) * 0.16
                    iconText: "⏻"
                    bordered: true
                    fontFamily: root.fontFamily
                    onClicked: {
                      if (root.primaryVm) {
                        if (root.primaryVm.status === "running") root.killPrimaryVm();
                        else {
                          Hetzner.powerOn(root.apiToken, root.primaryVm.id, function() { root.refreshAll(); });
                        }
                      }
                    }
                  }
                }

                // Inline Kill confirmation modal
                BorderSurface {
                  visible: root.showKillModal
                  width: parent.width
                  radius: Style.cornerRadius
                  color: Qt.rgba(0.93, 0.27, 0.27, 0.12)
                  borderSpec: Border.controlSpec("normal", root.urgentColor, root.urgentColor)
                  padding: Style.space(10)

                  Column {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      text: "Confirm Stop VM: " + (root.primaryVm ? root.primaryVm.name : "omarchy-companion")
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.urgentColor
                    }
                    Text {
                      text: "All unsaved processes and ephemeral VM disk files will be stopped."
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.foreground
                      wrapMode: Text.WordWrap
                      width: parent.width
                    }
                    Row {
                      width: parent.width
                      spacing: Style.space(8)
                      Button {
                        width: (parent.width - Style.space(8)) * 0.5
                        text: "Cancel"
                        bordered: true
                        fontFamily: root.fontFamily
                        onClicked: root.showKillModal = false
                      }
                      Button {
                        width: (parent.width - Style.space(8)) * 0.5
                        text: "Confirm KILL"
                        iconText: "✕"
                        bordered: true
                        accent: root.urgentColor
                        fontFamily: root.fontFamily
                        onClicked: root.killPrimaryVm()
                      }
                    }
                  }
                }
              }
            }

            // 2B. Hetzner Server (Auction / Dedicated) (Day running) (Monthly Cost)
            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: auctionCol.implicitHeight + Style.space(20)

              Column {
                id: auctionCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Header line: [Hetzner Logo] Name (32d) (€39/mo)
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      source: Qt.resolvedUrl("icons/hetzner.svg")
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Primary-Host"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "(32d) (€39/mo)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - auctionPill.implicitWidth - parent.spacing)
                    height: 1
                  }
                  BorderSurface {
                    id: auctionPill
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: auctionStatus.implicitWidth + Style.space(10)
                    implicitHeight: auctionStatus.implicitHeight + Style.space(4)
                    radius: Style.cornerRadius
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    borderSpec: Border.none()

                    Text {
                      id: auctionStatus
                      anchors.centerIn: parent
                      text: "○ STANDBY"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.dim
                    }
                  }
                }

                // Metrics: Ram ?/? CPU % GPU: ? Apps Running: ?
                Row {
                  width: parent.width
                  spacing: Style.space(12)

                  Text {
                    text: "RAM: 14.2 / 64.0 GB"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }
                  Text {
                    text: "CPU: 2%"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }
                  Text {
                    text: "GPU: N/A"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }
                  Text {
                    text: "Apps: 0"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }
                }

                // Quick Drive Mount row
                Rectangle {
                  width: parent.width
                  height: Style.space(1)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: root.dim
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Host Filesystem (/mnt/data)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - hSrvMountBtn.implicitWidth - Style.space(8))
                    height: 1
                  }

                  Button {
                    id: hSrvMountBtn
                    text: "Mount Drive"
                    iconText: "⚡"
                    bordered: true
                    fontFamily: root.fontFamily
                    onClicked: root.openFolder(Quickshell.env("HOME"))
                  }
                }
              }
            }

            // 2C. Oracle Cloud (ARM-Node) (Always Free)
            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: ociCol.implicitHeight + Style.space(20)

              Column {
                id: ociCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Header line: [Oracle Logo] Name (18d) (Free)
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      source: Qt.resolvedUrl("icons/oracle.svg")
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "ARM-Node"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "(18d) (€0/mo · Free)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.successColor
                      font.bold: true
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - ociPill.implicitWidth - parent.spacing)
                    height: 1
                  }
                  BorderSurface {
                    id: ociPill
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: ociStatus.implicitWidth + Style.space(10)
                    implicitHeight: ociStatus.implicitHeight + Style.space(4)
                    radius: Style.cornerRadius
                    color: Qt.rgba(0.06, 0.72, 0.5, 0.15)
                    borderSpec: Border.none()

                    Text {
                      id: ociStatus
                      anchors.centerIn: parent
                      text: "● RUNNING"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.successColor
                    }
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(12)

                  Text {
                    text: "RAM: 6.1 / 24.0 GB"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                  }
                  Text {
                    text: "CPU: 4%"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                  }
                  Text {
                    text: "GPU: None"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }
                  Text {
                    text: "Apps: 2"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.accentColor
                    font.bold: true
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(1)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: root.dim
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Boot Volume (/root)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - ociMountBtn.implicitWidth - Style.space(8))
                    height: 1
                  }

                  Button {
                    id: ociMountBtn
                    text: "Mount Drive"
                    iconText: "⚡"
                    bordered: true
                    fontFamily: root.fontFamily
                    onClicked: root.openFolder(Quickshell.env("HOME"))
                  }
                }
              }
            }

            // 2D. Home System (Workstation)
            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: homeSysCol.implicitHeight + Style.space(20)

              Column {
                id: homeSysCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Header line: [Home Logo] Name (Local Node) ... [LOCAL]
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Image {
                      anchors.verticalCenter: parent.verticalCenter
                      source: Qt.resolvedUrl("icons/nas.svg")
                      width: 18
                      height: 18
                      fillMode: Image.PreserveAspectFit
                      smooth: true
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Workstation"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "(Local Node)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - homePill.implicitWidth - parent.spacing)
                    height: 1
                  }
                  BorderSurface {
                    id: homePill
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: homeText.implicitWidth + Style.space(10)
                    implicitHeight: homeText.implicitHeight + Style.space(4)
                    radius: Style.cornerRadius
                    color: Qt.rgba(0.06, 0.72, 0.5, 0.15)
                    borderSpec: Border.none()

                    Text {
                      id: homeText
                      anchors.centerIn: parent
                      text: "● LOCAL"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.successColor
                    }
                  }
                }

                Row {
                  width: parent.width
                  spacing: Style.space(12)

                  Text {
                    text: "RAM: 3.2 / 16.0 GB"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                  }
                  Text {
                    text: "CPU: 8%"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                  }
                  Text {
                    text: "GPU: Metal / RTX"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.foreground
                  }
                  Text {
                    text: "Apps: Desktop"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }
                }

                Rectangle {
                  width: parent.width
                  height: Style.space(1)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                }

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 4
                      anchors.verticalCenter: parent.verticalCenter
                      color: root.successColor
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "Local NVMe (~/)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.successColor
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].implicitWidth - localOpenBtn.implicitWidth - Style.space(8))
                    height: 1
                  }

                  Button {
                    id: localOpenBtn
                    text: "Open Files"
                    iconText: "📂"
                    bordered: true
                    fontFamily: root.fontFamily
                    onClicked: root.openFolder(Quickshell.env("HOME"))
                  }
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // ==========================================
          // BOTTOM: OPEN OCLOUD MANAGER
          // ==========================================
          Button {
            width: parent.width
            text: "Open Ocloud Manager"
            iconText: "⚙"
            bordered: true
            accent: root.accentColor
            fontFamily: root.fontFamily
            onClicked: {
              root.toggle();
              Quickshell.execDetached([root.ocloudBin, "gui"]);
            }
          }
        }
      }
    }
  }
}
