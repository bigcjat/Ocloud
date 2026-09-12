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
  readonly property color dangerColor: "#ef4444"

  readonly property string ocloudBin: {
    var home = Quickshell.env("HOME") || "/home/bigcjat";
    return home + "/.local/bin/ocloud";
  }

  // Reactive state
  property string apiToken: ""
  property var serversList: []
  property var primaryServer: serversList.length > 0 ? serversList[0] : null
  property int activeVmCount: {
    var cnt = 0;
    for (var i = 0; i < serversList.length; i++) {
      if (serversList[i].status === "running") cnt++;
    }
    return cnt;
  }

  property bool storageMounted: false
  property bool vmMounted: false
  property bool storageBusy: false
  property bool vmBusy: false
  property bool powerBusy: false
  property bool showVmConsent: false

  property real storageUsedGb: 0.0
  property real storageTotalGb: 1000.0
  property real storagePercent: 0.0
  property string fastestRegion: "Nuremberg"
  property int fastestPingMs: 24

  function refreshAll() {
    mountCheckProc.running = true;
    storageInfoProc.running = true;

    if (!root.apiToken || root.apiToken === "") {
      vaultProc.running = true;
      return;
    }

    Hetzner.fetchServers(root.apiToken, function(servers) {
      root.serversList = servers;
    }, function(err) {
      console.log("Hetzner API error: " + err);
    });
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
    root.vmBusy = true;
    mountVmProc.running = true;
  }

  function unmountVmDrive() {
    root.vmBusy = true;
    unmountVmProc.running = true;
  }

  function openFolder(folderPath) {
    Quickshell.execDetached(["xdg-open", folderPath]);
  }

  // Mount detection: checks system mount table directly
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

  // Storage quota inspection via ocloud storage status
  Process {
    id: storageInfoProc
    command: [root.ocloudBin, "storage", "status"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text);
          if (data && data.storage_box) {
            var sb = data.storage_box;
            if (sb.total_bytes > 0) {
              root.storageTotalGb = Math.round(sb.total_bytes / (1024 * 1024 * 1024));
              root.storageUsedGb = Number((sb.used_bytes / (1024 * 1024 * 1024)).toFixed(1));
              root.storagePercent = sb.used_percent;
            }
          }
        } catch (e) {}
      }
    }
  }

  // Storage mount process
  Process {
    id: mountStorageProc
    command: [root.ocloudBin, "storage", "mount"]
    running: false
    onExited: function(exitCode, exitStatus) {
      root.storageBusy = false;
      root.refreshAll();
      openFolder(Quickshell.env("HOME") + "/Cloud");
    }
  }

  // Storage unmount process
  Process {
    id: unmountStorageProc
    command: [root.ocloudBin, "storage", "unmount"]
    running: false
    onExited: function(exitCode, exitStatus) {
      root.storageBusy = false;
      root.refreshAll();
    }
  }

  // VM ephemeral drive mount process
  Process {
    id: mountVmProc
    command: [root.ocloudBin, "vm", "mount", "--yes"]
    running: false
    onExited: function(exitCode, exitStatus) {
      root.vmBusy = false;
      root.refreshAll();
      openFolder(Quickshell.env("HOME") + "/Companion-VM");
    }
  }

  // VM ephemeral drive unmount process
  Process {
    id: unmountVmProc
    command: [root.ocloudBin, "vm", "unmount"]
    running: false
    onExited: function(exitCode, exitStatus) {
      root.vmBusy = false;
      root.refreshAll();
    }
  }

  // Load API token from Vault
  Process {
    id: vaultProc
    command: [root.ocloudBin, "vault", "get", "api_token"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var tok = text.trim();
        if (tok && tok !== "") {
          root.apiToken = tok;
          root.refreshAll();
        } else {
          legacyConfigProc.running = true;
        }
      }
    }
  }

  Process {
    id: legacyConfigProc
    command: ["cat", Quickshell.env("HOME") + "/.config/omarchy/hetzner.json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var cfg = JSON.parse(text);
          if (cfg && cfg.api_token) {
            root.apiToken = cfg.api_token;
            root.refreshAll();
          }
        } catch (e) {}
      }
    }
  }

  // Periodic refresh timer
  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshAll()
  }

  // IPC handler so omarchy-shell and other tools can trigger panel
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

  // Top Bar Icon
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

  // The Popup KeyboardPanel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refreshAll()
        else if (t === "m" || t === "M") {
          if (root.storageMounted) root.unmountStorage();
          else root.mountStorage();
        }
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
            meta: (root.storageMounted ? "Storage Connected" : "Storage Disconnected") + (root.activeVmCount > 0 ? " · " + root.activeVmCount + " VM Active" : " · VM Offline")
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

          PanelSeparator {
            foreground: root.foreground
          }

          // SECTION 1: STORAGE BOX (PERMANENT RAID)
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "PERMANENT CLOUD DRIVE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: storageInnerCol.implicitHeight + Style.space(24)

              Column {
                id: storageInnerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                // Header row: Icon, Name, and Capacity badge
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "󰋊"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    color: root.foreground
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    spacing: Style.space(1)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                      text: "Hetzner Storage Box"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }
                    Text {
                      text: "Permanent RAID Array · Auto-snapshots"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].width - parent.children[1].width - capacityBadge.width - parent.spacing * 2)
                    height: 1
                  }

                  BorderSurface {
                    id: capacityBadge
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: capText.implicitWidth + Style.space(12)
                    implicitHeight: capText.implicitHeight + Style.space(6)
                    radius: Style.cornerRadius
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    borderSpec: Border.none()

                    Text {
                      id: capText
                      anchors.centerIn: parent
                      text: root.storageTotalGb + " GB"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.accentColor
                    }
                  }
                }

                // Storage usage bar
                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  Row {
                    width: parent.width
                    Text {
                      text: "Usage"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                    Item {
                      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth)
                      height: 1
                    }
                    Text {
                      text: root.storageUsedGb + " GB / " + root.storageTotalGb + " GB (" + root.storagePercent + "%)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.foreground
                    }
                  }

                  Rectangle {
                    width: parent.width
                    height: Style.space(6)
                    radius: Style.space(3)
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                    Rectangle {
                      height: parent.height
                      radius: Style.space(3)
                      width: Math.min(parent.width, Math.max(4, parent.width * (Math.max(0.01, root.storagePercent) / 100.0)))
                      color: root.accentColor
                    }
                  }
                }

                // Status row
                Row {
                  width: parent.width
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
                    text: root.storageMounted ? "Mounted at ~/Cloud" : "Drive Disconnected"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: root.storageMounted
                    color: root.storageMounted ? root.successColor : root.dim
                  }
                }

                // Action Buttons
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  // If mounted: Show "Open in Files" and "Unmount"
                  Button {
                    visible: root.storageMounted
                    width: (parent.width - Style.space(8)) * 0.65
                    text: "Open in Files"
                    iconText: "📂"
                    bordered: true
                    accent: root.accentColor
                    fontFamily: root.fontFamily
                    onClicked: root.openFolder(Quickshell.env("HOME") + "/Cloud")
                  }

                  Button {
                    visible: root.storageMounted
                    width: (parent.width - Style.space(8)) * 0.35
                    text: root.storageBusy ? "Ejecting..." : "Unmount"
                    iconText: "⏏"
                    bordered: true
                    enabled: !root.storageBusy
                    fontFamily: root.fontFamily
                    onClicked: root.unmountStorage()
                  }

                  // If unmounted: Prominent Mount button
                  Button {
                    visible: !root.storageMounted
                    width: parent.width
                    text: root.storageBusy ? "Mounting..." : "Mount Storage Drive"
                    iconText: root.storageBusy ? "⏳" : "󰋊"
                    iconSpinning: root.storageBusy
                    bordered: true
                    accent: root.accentColor
                    enabled: !root.storageBusy
                    fontFamily: root.fontFamily
                    onClicked: root.mountStorage()
                  }
                }
              }
            }
          }

          PanelSeparator {
            foreground: root.foreground
          }

          // SECTION 2: CLOUD COMPUTE (VPS)
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "CLOUD COMPUTE (VPS)"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: vpsInnerCol.implicitHeight + Style.space(24)

              Column {
                id: vpsInnerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(12)
                spacing: Style.space(10)

                // Header row: Icon, VM name, Status pill
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "󰒋"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.heading
                    color: root.foreground
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    spacing: Style.space(1)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                      text: root.primaryServer ? root.primaryServer.name : "omarchy-companion"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      color: root.foreground
                    }
                    Text {
                      text: root.primaryServer
                        ? ((root.primaryServer.server_type ? root.primaryServer.server_type.name : "cx23") + " · 2 vCPU 4GB · " + (root.primaryServer.datacenter ? root.primaryServer.datacenter.description : "Nuremberg"))
                        : "cx23 · 2 vCPU · 4 GB RAM"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      color: root.dim
                    }
                  }

                  Item {
                    width: Math.max(0, parent.width - parent.children[0].width - parent.children[1].width - statusPill.width - parent.spacing * 2)
                    height: 1
                  }

                  BorderSurface {
                    id: statusPill
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: statusPillText.implicitWidth + Style.space(12)
                    implicitHeight: statusPillText.implicitHeight + Style.space(6)
                    radius: Style.cornerRadius
                    color: (root.primaryServer && root.primaryServer.status === "running") ? Qt.rgba(0.06, 0.72, 0.5, 0.15) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    borderSpec: Border.none()

                    Text {
                      id: statusPillText
                      anchors.centerIn: parent
                      text: (root.primaryServer && root.primaryServer.status === "running") ? "● RUNNING" : "○ STOPPED"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: (root.primaryServer && root.primaryServer.status === "running") ? root.successColor : root.dim
                    }
                  }
                }

                // Ephemeral VM Disk row
                Column {
                  width: parent.width
                  spacing: Style.space(4)

                  Row {
                    width: parent.width
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
                      text: root.vmMounted ? "Temporary VM Disk Mounted at ~/Companion-VM" : "Temporary VM Disk (Scratch Space)"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: root.vmMounted
                      color: root.vmMounted ? root.warningColor : root.dim
                    }
                  }

                  Text {
                    visible: root.vmMounted
                    text: "Files saved here are cleared when the VM is powered off."
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    color: root.dim
                  }

                  // VM Mount action buttons
                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Button {
                      visible: root.vmMounted
                      width: (parent.width - Style.space(8)) * 0.65
                      text: "Open VM Files"
                      iconText: "📂"
                      bordered: true
                      fontFamily: root.fontFamily
                      onClicked: root.openFolder(Quickshell.env("HOME") + "/Companion-VM")
                    }

                    Button {
                      visible: root.vmMounted
                      width: (parent.width - Style.space(8)) * 0.35
                      text: root.vmBusy ? "Ejecting..." : "Unmount"
                      iconText: "⏏"
                      bordered: true
                      enabled: !root.vmBusy
                      fontFamily: root.fontFamily
                      onClicked: root.unmountVmDrive()
                    }

                    Button {
                      visible: !root.vmMounted && !root.showVmConsent
                      width: parent.width
                      text: "Mount Temporary VM Disk"
                      iconText: "⚡"
                      bordered: true
                      enabled: !root.vmBusy && root.primaryServer && root.primaryServer.status === "running"
                      fontFamily: root.fontFamily
                      onClicked: root.showVmConsent = true
                    }
                  }

                  // Ephemeral disk consent banner
                  BorderSurface {
                    visible: root.showVmConsent
                    width: parent.width
                    radius: Style.cornerRadius
                    color: Qt.rgba(0.96, 0.62, 0.04, 0.1)
                    borderSpec: Border.controlSpec("normal", root.warningColor, root.warningColor)
                    padding: Style.space(10)

                    Column {
                      width: parent.width
                      spacing: Style.space(6)

                      Text {
                        text: "Notice: Temporary Disk"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.warningColor
                      }

                      Text {
                        width: parent.width
                        text: "This drive mounts the VM root filesystem. Files are deleted when the VM powers off."
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        color: root.foreground
                        wrapMode: Text.WordWrap
                      }

                      Row {
                        width: parent.width
                        spacing: Style.space(8)

                        Button {
                          width: (parent.width - Style.space(8)) * 0.5
                          text: "Cancel"
                          bordered: true
                          fontFamily: root.fontFamily
                          onClicked: root.showVmConsent = false
                        }

                        Button {
                          width: (parent.width - Style.space(8)) * 0.5
                          text: root.vmBusy ? "Mounting..." : "Mount Disk"
                          iconText: root.vmBusy ? "⏳" : "⚡"
                          iconSpinning: root.vmBusy
                          bordered: true
                          accent: root.warningColor
                          fontFamily: root.fontFamily
                          onClicked: root.mountVmDrive()
                        }
                      }
                    }
                  }
                }

                // VPS Quick Actions: Arcade, Terminal, Power
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Button {
                    width: (parent.width - Style.space(16)) / 3
                    text: "Arcade"
                    iconText: "🎮"
                    bordered: true
                    accent: root.accentColor
                    enabled: !!root.primaryServer && root.primaryServer.status === "running"
                    fontFamily: root.fontFamily
                    onClicked: {
                      Quickshell.execDetached(["foot", "-e", root.ocloudBin, "vm", "app", "arcade"]);
                    }
                  }

                  Button {
                    width: (parent.width - Style.space(16)) / 3
                    text: "Terminal"
                    iconText: ">_"
                    bordered: true
                    enabled: !!root.primaryServer && !!root.primaryServer.public_net
                    fontFamily: root.fontFamily
                    onClicked: {
                      if (root.primaryServer && root.primaryServer.public_net && root.primaryServer.public_net.ipv4) {
                        var ip = root.primaryServer.public_net.ipv4.ip;
                        var sname = root.primaryServer.name || "companion";
                        Quickshell.execDetached([
                          "foot",
                          "-T", "Cloud Terminal [" + sname + " · " + ip + "]",
                          "-e", "ssh", "-i", Quickshell.env("HOME") + "/.ssh/id_ed25519", "-o", "StrictHostKeyChecking=no", "-t", "root@" + ip
                        ]);
                      }
                    }
                  }

                  Button {
                    width: (parent.width - Style.space(16)) / 3
                    text: (root.primaryServer && root.primaryServer.status === "running") ? "Power Off" : "Power On"
                    iconText: "⏻"
                    bordered: true
                    enabled: !!root.primaryServer && !root.powerBusy
                    fontFamily: root.fontFamily
                    onClicked: {
                      if (root.primaryServer) {
                        root.powerBusy = true;
                        if (root.primaryServer.status === "running") {
                          Hetzner.powerOff(root.apiToken, root.primaryServer.id, function() {
                            root.powerBusy = false;
                            root.refreshAll();
                          });
                        } else {
                          Hetzner.powerOn(root.apiToken, root.primaryServer.id, function() {
                            root.powerBusy = false;
                            root.refreshAll();
                          });
                        }
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

          // SECTION 3: DATACENTER LATENCY & MANAGER
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "NETWORK & SETTINGS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            BorderSurface {
              width: parent.width
              radius: Style.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              implicitHeight: pingInnerRow.implicitHeight + Style.space(20)

              Row {
                id: pingInnerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Text {
                  text: "🌐"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: "Lowest Datacenter Ping"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  color: root.dim
                  anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                  width: Math.max(0, parent.width - parent.children[0].width - parent.children[1].implicitWidth - pingPill.implicitWidth - parent.spacing * 2)
                  height: 1
                }

                BorderSurface {
                  id: pingPill
                  anchors.verticalCenter: parent.verticalCenter
                  implicitWidth: pingPillText.implicitWidth + Style.space(10)
                  implicitHeight: pingPillText.implicitHeight + Style.space(4)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  borderSpec: Border.none()

                  Text {
                    id: pingPillText
                    anchors.centerIn: parent
                    text: "🟢 " + root.fastestRegion + " (" + root.fastestPingMs + "ms)"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    color: root.foreground
                  }
                }
              }
            }

            Button {
              width: parent.width
              text: "Open Full Cloud Manager"
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
}
