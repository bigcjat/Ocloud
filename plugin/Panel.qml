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

  property string selectedServerId: ""
  property var primaryVm: {
    if (serversList && serversList.length > 0) {
      if (selectedServerId !== "") {
        for (var k = 0; k < serversList.length; k++) {
          if (String(serversList[k].id) === String(selectedServerId) || serversList[k].name === selectedServerId) {
            return serversList[k];
          }
        }
      }
      for (var i = 0; i < serversList.length; i++) {
        if (serversList[i].status === "running") return serversList[i];
      }
      return serversList[0];
    }
    if (rawStatus && rawStatus.servers && rawStatus.servers.length > 0) {
      return rawStatus.servers[0];
    }
    return null;
  }

  readonly property int runningVmCount: {
    if (!root.serversList || !Array.isArray(root.serversList)) return 0;
    var count = 0;
    for (var i = 0; i < root.serversList.length; i++) {
      if (root.serversList[i].status === "running") count++;
    }
    return count;
  }
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

  property var cloudAccountsList: []
  property bool storageMounted: false
  property bool vmMounted: false

  property bool storageBusy: false
  property bool vmDriveBusy: false
  property bool storageActionBusy: false
  property string activeStorageName: ""
  property bool killBusy: false
  property bool showKillModal: false
  property string currentTab: "storage" // "storage" | "compute"

  function switchToStorage() {
    root.currentTab = "storage";
  }

  function switchToCompute() {
    root.currentTab = "compute";
  }

  property var ocloudSettings: ({
    "fileManager": "default",
    "customFileManagerCmd": ""
  })

  function calculateRunningCost(vm) {
    if (!vm || vm.status !== "running") return "€0.00";
    var createdTime = vm.created ? new Date(vm.created).getTime() : Date.now();
    var now = Date.now();
    var elapsedMs = Math.max(0, now - createdTime);
    var elapsedHours = elapsedMs / (1000.0 * 60.0 * 60.0);

    var isGcp = (vm.provider === "gcp");
    var sym = vm.currencySymbol || (isGcp ? "$" : "€");
    var hourly = (typeof vm.priceHourly === "number") ? vm.priceHourly : (isGcp ? 0.0084 : 0.0058);
    var monthlyMax = (typeof vm.priceMonthly === "number") ? vm.priceMonthly : (isGcp ? 6.11 : 3.65);

    var accrued = Math.min(elapsedHours * hourly, monthlyMax);
    if (accrued < 0.005) {
      return sym + "0.00";
    }
    return sym + accrued.toFixed(2);
  }

  function calculateUptimeStr(vm) {
    if (!vm || vm.status !== "running") return "Stopped";
    var createdTime = vm.created ? new Date(vm.created).getTime() : Date.now();
    var now = Date.now();
    var elapsedMs = Math.max(0, now - createdTime);
    var totalMinutes = Math.floor(elapsedMs / (1000 * 60));
    var days = Math.floor(totalMinutes / (60 * 24));
    var hours = Math.floor((totalMinutes % (60 * 24)) / 60);
    var mins = totalMinutes % 60;

    if (days > 0) return days + "d " + hours + "h " + mins + "m";
    if (hours > 0) return hours + "h " + mins + "m";
    return mins + "m";
  }

  function refreshAll() {
    statusProc.running = true;
    mountCheckProc.running = true;
    ocloudSettingsFile.reload();
    if (root.primaryVm && root.primaryVm.status === "running") {
      inspectProc.running = true;
    }
  }

  function toggleMountCloudAccount(name, isMounted, mountPath) {
    if (root.storageActionBusy) return;
    root.storageActionBusy = true;
    root.activeStorageName = name;
    if (isMounted) {
      dynamicStorageActionProc.targetFolderToOpen = "";
      dynamicStorageActionProc.command = [root.ocloudBin, "storage", "unmount", name];
    } else {
      dynamicStorageActionProc.targetFolderToOpen = mountPath || "";
      dynamicStorageActionProc.command = [root.ocloudBin, "storage", "mount", name];
    }
    dynamicStorageActionProc.running = true;
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
    root.vmDriveBusy = true;
    mountVmProc.running = true;
  }

  function unmountVmDrive() {
    root.vmDriveBusy = true;
    unmountVmProc.running = true;
  }

  function killPrimaryVm() {
    if (!root.primaryVm) return;
    root.showKillModal = false;
    root.killBusy = true;
    killVmProc.running = true;
  }

  function resolveFileManagerCmd(folderPath) {
    var home = Quickshell.env("HOME") || "/home/bigcjat";
    var p = folderPath;
    if (p && p.indexOf("~/") === 0) p = home + p.substring(1);

    var fm = (root.ocloudSettings && root.ocloudSettings.fileManager) ? root.ocloudSettings.fileManager : "default";
    var custom = (root.ocloudSettings && root.ocloudSettings.customFileManagerCmd) ? root.ocloudSettings.customFileManagerCmd.trim() : "";

    if (fm === "flea") {
      return [home + "/.local/bin/flea", p];
    } else if (fm === "nautilus") {
      return ["nautilus", "--new-window", p];
    } else if (fm === "thunar") {
      return ["thunar", p];
    } else if (fm === "dolphin") {
      return ["dolphin", p];
    } else if (fm === "custom" && custom.length > 0) {
      var parts = custom.split(/\s+/);
      parts.push(p);
      return parts;
    }
    return [root.ocloudBin, "storage", "open", p];
  }

  function openFolder(folderPath) {
    if (!folderPath) return;
    var cmd = resolveFileManagerCmd(folderPath);
    Quickshell.execDetached(cmd);
  }

  // Reactive settings watcher from ~/.config/ocloud/settings.json
  FileView {
    id: ocloudSettingsFile
    path: Quickshell.env("HOME") + "/.config/ocloud/settings.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var cfg = JSON.parse(text());
        if (cfg) root.ocloudSettings = cfg;
      } catch(e) {}
    }
    onFileChanged: reload()
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
          if (data.storage && Array.isArray(data.storage.cloud_accounts)) {
            root.cloudAccountsList = data.storage.cloud_accounts;
          } else {
            root.cloudAccountsList = [];
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

  // Dynamic storage action runner (mount / unmount any cloud remote)
  Process {
    id: dynamicStorageActionProc
    command: []
    running: false
    property string targetFolderToOpen: ""
    onExited: function() {
      root.storageActionBusy = false;
      root.refreshAll();
      if (targetFolderToOpen !== "") {
        root.openFolder(targetFolderToOpen);
        targetFolderToOpen = "";
      }
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
    function showStorage(): string { root.currentTab = "storage"; return "storage" }
    function showCompute(): string { root.currentTab = "compute"; return "compute" }
    function openFolder(path: string): string { root.openFolder(path); return "ok" }
    function getFileManager(): string { return (root.ocloudSettings && root.ocloudSettings.fileManager) || "default" }
  }

  onOpenedChanged: if (opened) {
    root.refreshAll();
    Qt.callLater(function() { keyCatcher.forceActiveFocus() });
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.iconSlot
    tooltipText: "Cloud Storage & Compute"
    iconComponent: Component {
      Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: Qt.resolvedUrl("icons/ocloud-bar.svg")
        fillMode: Image.PreserveAspectFit
      }
    }
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
                  : (root.runningVmCount > 0 ? (root.runningVmCount + (root.runningVmCount === 1 ? " Cloud VM Running" : " Cloud VMs Running")) : "Cloud Fleet Ready")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Image {
                anchors.centerIn: parent
                width: 24
                height: 24
                source: Qt.resolvedUrl("icons/ocloud.svg")
                fillMode: Image.PreserveAspectFit
              }
            }
            trailingControl: Component {
              PanelActionButton {
                tooltipText: "Refresh (R)"
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.refreshAll()
                Image {
                  anchors.centerIn: parent
                  width: 14
                  height: 14
                  source: Qt.resolvedUrl("icons/refresh.svg")
                  fillMode: Image.PreserveAspectFit
                }
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
              accent: root.currentTab === "storage" ? root.accentColor : "transparent"
              bordered: true
              fontFamily: root.fontFamily
              onClicked: root.currentTab = "storage"
            }

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "Cloud Compute"
              accent: root.currentTab === "compute" ? root.accentColor : "transparent"
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

            // Dynamic list of Cloud Accounts (Storage Box, R2, Google Drive, OneDrive, Dropbox, pCloud, etc.)
            Repeater {
              model: root.cloudAccountsList

              BorderSurface {
                required property var modelData
                required property int index

                width: parent.width
                radius: Style.cornerRadius
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                implicitHeight: cardInnerCol.implicitHeight + Style.space(20)

                Column {
                  id: cardInnerCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(8)

                  // Title row: [Provider Icon] Provider / Remote Name [Status / Tagline]
                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : Qt.resolvedUrl("icons/cloud.svg")
                        width: 18
                        height: 18
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.providerName || modelData.name
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
                      text: modelData.isMounted ? "Mounted" : (modelData.accountDetail || "Ready")
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: modelData.isMounted
                      color: modelData.isMounted ? root.successColor : root.dim
                    }
                  }

                  // Storage box specific usage bar if it's the hetzner storage box
                  Rectangle {
                    visible: (modelData.name === "storagebox" || modelData.providerId === "hetzner_storage_box") && root.storageBoxData.percent > 0
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

                  // Drive status & actions: Status path [Mount / Unmount] [Open Files]
                  Item {
                    width: parent.width
                    implicitHeight: Math.max(statusRow.implicitHeight, actionRow.implicitHeight)

                    Row {
                      id: statusRow
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)
                      Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.isMounted ? root.successColor : root.dim
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.isMounted ? ("Mounted at " + (modelData.mountPath || "~/Cloud")) : (modelData.mountPath ? ("Target: " + modelData.mountPath) : "Disconnected")
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        color: modelData.isMounted ? root.successColor : root.dim
                      }
                    }

                    Row {
                      id: actionRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Button {
                        property bool isThisBusy: root.storageActionBusy && root.activeStorageName === modelData.name
                        text: isThisBusy ? (modelData.isMounted ? "Unmounting..." : "Mounting...") : (modelData.isMounted ? "Unmount" : "Mount")
                        bordered: true
                        enabled: !root.storageActionBusy
                        fontFamily: root.fontFamily
                        onClicked: root.toggleMountCloudAccount(modelData.name, modelData.isMounted, modelData.mountPath)
                      }

                      Button {
                        visible: modelData.isMounted
                        text: "Open Files"
                        bordered: true
                        accent: root.accentColor
                        fontFamily: root.fontFamily
                        onClicked: root.openFolder(modelData.mountPath)
                      }
                    }
                  }
                }
              }
            }

            // Fallback when no accounts configured
            BorderSurface {
              visible: !root.cloudAccountsList || root.cloudAccountsList.length === 0
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: emptyCol.implicitHeight + Style.space(24)

              Column {
                id: emptyCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(8)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "No Cloud Storage Accounts Configured"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                  color: root.foreground
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "Configure Storage Box, Cloudflare R2, Google Drive, OneDrive, or pCloud via Ocloud."
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.dim
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

            Repeater {
              model: root.serversList || []

              delegate: BorderSurface {
                width: parent.width
                radius: Style.cornerRadius
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                implicitHeight: srvCol.implicitHeight + Style.space(20)

                Column {
                  id: srvCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(8)

                  // 1. Header line: [Provider Logo] Name (Uptime) (Running Cost) [Status Pill]
                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Row {
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Image {
                        anchors.verticalCenter: parent.verticalCenter
                        source: (modelData.providerIcon && modelData.providerIcon.length > 0)
                          ? modelData.providerIcon
                          : (modelData.isHomeWorkstation ? Qt.resolvedUrl("icons/device-workstation.svg") : Qt.resolvedUrl("icons/server.svg"))
                        width: 18
                        height: 18
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name || "Server"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                        color: root.foreground
                      }

                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "(" + root.calculateUptimeStr(modelData) + ") (" + root.calculateRunningCost(modelData) + ")"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        color: root.accentColor
                        font.bold: true
                      }
                    }

                    Item {
                      width: Math.max(0, parent.width - parent.children[0].implicitWidth - srvStatusPill.implicitWidth - parent.spacing)
                      height: 1
                    }

                    BorderSurface {
                      id: srvStatusPill
                      anchors.verticalCenter: parent.verticalCenter
                      implicitWidth: srvStatusText.implicitWidth + Style.space(10)
                      implicitHeight: srvStatusText.implicitHeight + Style.space(4)
                      radius: Style.cornerRadius
                      color: modelData.status === "running" ? Qt.rgba(0.06, 0.72, 0.5, 0.15) : (modelData.status === "starting" ? Qt.rgba(0.9, 0.6, 0.1, 0.15) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06))
                      borderSpec: Border.none()

                      Text {
                        id: srvStatusText
                        anchors.centerIn: parent
                        text: modelData.status === "running" ? "● RUNNING" : (modelData.status === "starting" ? "◌ STARTING" : "○ STOPPED")
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: modelData.status === "running" ? root.successColor : (modelData.status === "starting" ? "#fbbf24" : root.dim)
                      }
                    }
                  }

                  // 2. Network Row: Both Public IP and Tailscale IP
                  Row {
                    width: parent.width
                    spacing: Style.space(14)

                    Text {
                      text: "Public IP: " + (modelData.ipv4 || "None")
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.foreground
                    }
                    Text {
                      text: "Tailscale: " + (modelData.tailscale_ip || modelData.tailscaleIp || "Not connected")
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: !!(modelData.tailscale_ip || modelData.tailscaleIp)
                      color: (modelData.tailscale_ip || modelData.tailscaleIp) ? "#38bdf8" : root.dim
                    }
                    Text {
                      text: "Type: " + (modelData.type || "bare-metal")
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  // 3. VM Ephemeral Disk Row
                  Rectangle {
                    width: parent.width
                    height: Style.space(1)
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                  }

                  Item {
                    width: parent.width
                    implicitHeight: Math.max(diskStatusRow.implicitHeight, diskBtnsRow.implicitHeight)

                    Row {
                      id: diskStatusRow
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData.is_drive_mounted ? root.warningColor : root.dim
                      }
                      Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.is_drive_mounted
                          ? "VM Disk Mounted (~/Companion-VM)"
                          : "Ephemeral VM Disk · destroyed on stop"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: modelData.is_drive_mounted
                        color: modelData.is_drive_mounted ? root.warningColor : root.dim
                      }
                    }

                    Row {
                      id: diskBtnsRow
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(6)

                      Button {
                        text: modelData.is_drive_mounted ? "Unmount" : "Mount Disk"
                        bordered: true
                        enabled: modelData.status === "running"
                        fontFamily: root.fontFamily
                        onClicked: {
                          if (modelData.is_drive_mounted) {
                            Quickshell.execDetached([root.ocloudBin, "vm", "unmount"]);
                          } else {
                            Quickshell.execDetached([root.ocloudBin, "vm", "mount", modelData.name, "--yes"]);
                          }
                          root.refreshAll();
                        }
                      }

                      Button {
                        visible: modelData.is_drive_mounted
                        text: "Open Files"
                        bordered: true
                        fontFamily: root.fontFamily
                        onClicked: root.openFolder(Quickshell.env("HOME") + "/Companion-VM")
                      }
                    }
                  }

                  // 4. Action buttons: [KILL], [SSH Terminal], [Stop / Start]
                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Button {
                      width: (parent.width - Style.space(16)) * 0.28
                      text: "KILL"
                      bordered: true
                      accent: root.urgentColor
                      enabled: modelData.status === "running"
                      fontFamily: root.fontFamily
                      onClicked: {
                        Quickshell.execDetached([root.ocloudBin, "vm", "poweroff", modelData.name]);
                        root.refreshAll();
                      }
                    }

                    Button {
                      width: (parent.width - Style.space(16)) * 0.52
                      text: "SSH Terminal"
                      bordered: true
                      enabled: !!(modelData.ipv4 || modelData.tailscale_ip) && modelData.ipv4 !== "no IP"
                      fontFamily: root.fontFamily
                      onClicked: {
                        var targetIp = modelData.tailscale_ip || modelData.ipv4;
                        Quickshell.execDetached([
                          "foot",
                          "-T", ("Cloud Terminal [" + modelData.name + " · " + targetIp + "]"),
                          "-e", "ssh", "-i", Quickshell.env("HOME") + "/.ssh/id_ed25519", "-o", "StrictHostKeyChecking=accept-new", "-t", (modelData.user ? (modelData.user + "@") : "root@") + targetIp
                        ]);
                      }
                    }

                    Button {
                      width: (parent.width - Style.space(16)) * 0.20
                      text: (modelData.status === "running") ? "Stop" : "Start"
                      bordered: true
                      fontFamily: root.fontFamily
                      onClicked: {
                        if (modelData.status === "running") {
                          Quickshell.execDetached([root.ocloudBin, "vm", "stop", String(modelData.id)]);
                        } else {
                          Quickshell.execDetached([root.ocloudBin, "vm", "start", String(modelData.id)]);
                        }
                        root.refreshAll();
                      }
                    }
                  }
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // ==========================================
          // BOTTOM: OPEN PERSONAL CLOUD MANAGER
          // ==========================================
          Button {
            width: parent.width
            text: "Open Personal Cloud Manager"
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
