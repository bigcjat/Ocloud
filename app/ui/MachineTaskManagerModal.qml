import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: taskManagerModal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.80)
  z: 2000

  property var serverData: ({})
  property var telemetry: ({
    "load_1m": "0.15",
    "load_5m": "0.08",
    "ram_used": 858993459,
    "ram_total": 4294967296,
    "ram_percent": 20.0,
    "disk_used": 4080218931,
    "disk_total": 42626072576,
    "disk_percent": 9.6,
    "uptime": "1h 46m",
    "top_processes": [
      { "pid": "1042", "cpu": "1.8", "mem": "3.4", "cmd": "waypipe --server" },
      { "pid": "1180", "cpu": "0.5", "mem": "1.2", "cmd": "systemd-journald" },
      { "pid": "2051", "cpu": "0.0", "mem": "0.8", "cmd": "sshd: root@pts/0" },
      { "pid": "2204", "cpu": "0.0", "mem": "0.4", "cmd": "tailscaled" },
      { "pid": "2890", "cpu": "0.2", "mem": "1.1", "cmd": "node /usr/local/bin/server" }
    ]
  })
  property bool isLoading: false

  function openForServer(srv) {
    serverData = srv;
    taskManagerModal.visible = true;
    refreshData();
  }

  function refreshData() {
    if (!serverData || !serverData.id) return;
    isLoading = true;
    // Call backend inspect
    var raw = ocloud.inspectMachine ? ocloud.inspectMachine(String(serverData.id)) : "";
    if (raw) {
      try {
        var parsed = JSON.parse(raw);
        if (parsed && parsed.ram_total) {
          telemetry = parsed;
        }
      } catch (e) {}
    }
    isLoading = false;
  }

  function killProc(pid) {
    if (!serverData || !serverData.id) return;
    if (ocloud.killProcess) {
      ocloud.killProcess(String(serverData.id), String(pid));
      refreshData();
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block background clicks
  }

  // Main Card
  Rectangle {
    width: Math.min(parent.width - 64, 880)
    height: Math.min(parent.height - 64, 680)
    anchors.centerIn: parent
    radius: 16
    color: "#0b1220"
    border.color: "#1e293b"
    border.width: 1
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 24
      spacing: 16

      // Modal Header
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
          width: 40
          height: 40
          radius: 10
          color: serverData.isHomeWorkstation ? "#064e3b" : "#0c4a6e"
          Image {
            anchors.centerIn: parent
            width: 22
            height: 22
            source: serverData.isHomeWorkstation ? Qt.resolvedUrl("icons/nas.svg") : (serverData.provider === "oracle" ? Qt.resolvedUrl("icons/oracle.svg") : (serverData.provider === "aws" ? Qt.resolvedUrl("icons/aws.svg") : Qt.resolvedUrl("icons/hetzner.svg")))
            fillMode: Image.PreserveAspectFit
            smooth: true
          }
        }

        ColumnLayout {
          spacing: 2
          RowLayout {
            spacing: 8
            Text {
              text: (serverData.name || "Server") + " — Task Manager"
              font.pixelSize: 18
              font.bold: true
              color: "#f8fafc"
            }
            Rectangle {
              height: 20
              width: tmStatusText.implicitWidth + 12
              radius: 5
              color: serverData.status === "running" ? Qt.rgba(0.06, 0.72, 0.5, 0.2) : Qt.rgba(0.9, 0.2, 0.2, 0.2)
              Text {
                id: tmStatusText
                anchors.centerIn: parent
                text: serverData.status === "running" ? "● ONLINE" : "○ STOPPED"
                font.pixelSize: 10
                font.bold: true
                color: serverData.status === "running" ? "#10b981" : "#ef4444"
              }
            }
          }
          Text {
            text: "Host: " + (serverData.ipv4 || "No IP") + " · Provider: " + (serverData.provider || "hetzner").toUpperCase() + " · Uptime: " + (telemetry.uptime || "unknown")
            font.pixelSize: 12
            color: "#94a3b8"
          }
        }

        Item { Layout.fillWidth: true }

        Button {
          text: "󰑐 Refresh"
          background: Rectangle { radius: 6; color: "#1e293b" }
          contentItem: Text { text: "󰑐 Refresh"; color: "#f8fafc"; font.pixelSize: 11; font.bold: true }
          onClicked: refreshData()
        }

        Button {
          text: "󰅙 Close"
          background: Rectangle { radius: 6; color: "#1e293b" }
          contentItem: Text { text: "󰅙 Close"; color: "#94a3b8"; font.pixelSize: 11; font.bold: true }
          onClicked: taskManagerModal.visible = false
        }
      }

      // Live Hardware Gauges Grid
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        // CPU Metric Box
        Rectangle {
          Layout.fillWidth: true
          height: 84
          radius: 10
          color: "#0f172a"
          border.color: "#1e293b"
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            RowLayout {
              Text { text: "CPU LOAD"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
              Item { Layout.fillWidth: true }
              Text {
                text: "1m: " + (telemetry.load_1m || "0.1") + " · 5m: " + (telemetry.load_5m || "0.0")
                font.pixelSize: 10
                color: "#38bdf8"
                font.bold: true
              }
            }
            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#1e293b"
              Rectangle {
                height: parent.height
                radius: 3
                width: Math.min(parent.width, Math.max(6, parent.width * (parseFloat(telemetry.load_1m || 0.1) / 2.0)))
                color: "#38bdf8"
              }
            }
            Text {
              text: "Load: " + (telemetry.load_1m || "0.1") + " avg"
              font.pixelSize: 11
              color: "#f8fafc"
              font.bold: true
            }
          }
        }

        // RAM Metric Box
        Rectangle {
          Layout.fillWidth: true
          height: 84
          radius: 10
          color: "#0f172a"
          border.color: "#1e293b"
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            RowLayout {
              Text { text: "MEMORY (RAM)"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
              Item { Layout.fillWidth: true }
              Text {
                text: (telemetry.ram_percent || 20) + "%"
                font.pixelSize: 10
                color: "#10b981"
                font.bold: true
              }
            }
            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#1e293b"
              Rectangle {
                height: parent.height
                radius: 3
                width: Math.min(parent.width, Math.max(6, parent.width * ((telemetry.ram_percent || 20) / 100.0)))
                color: "#10b981"
              }
            }
            Text {
              text: (Math.round((telemetry.ram_used || 800000000) / 1048576) / 1024).toFixed(1) + " GB / " + (Math.round((telemetry.ram_total || 4294967296) / 1048576) / 1024).toFixed(1) + " GB"
              font.pixelSize: 11
              color: "#f8fafc"
              font.bold: true
            }
          }
        }

        // Disk Metric Box
        Rectangle {
          Layout.fillWidth: true
          height: 84
          radius: 10
          color: "#0f172a"
          border.color: "#1e293b"
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            RowLayout {
              Text { text: "DISK STORAGE"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
              Item { Layout.fillWidth: true }
              Text {
                text: (telemetry.disk_percent || 10) + "%"
                font.pixelSize: 10
                color: "#f59e0b"
                font.bold: true
              }
            }
            Rectangle {
              Layout.fillWidth: true
              height: 6
              radius: 3
              color: "#1e293b"
              Rectangle {
                height: parent.height
                radius: 3
                width: Math.min(parent.width, Math.max(6, parent.width * ((telemetry.disk_percent || 10) / 100.0)))
                color: "#f59e0b"
              }
            }
            Text {
              text: (Math.round((telemetry.disk_used || 4000000000) / 1048576) / 1024).toFixed(1) + " GB / " + (Math.round((telemetry.disk_total || 40000000000) / 1048576) / 1024).toFixed(1) + " GB"
              font.pixelSize: 11
              color: "#f8fafc"
              font.bold: true
            }
          }
        }

        // GPU / Accelerators Box
        Rectangle {
          Layout.fillWidth: true
          height: 84
          radius: 10
          color: "#0f172a"
          border.color: "#1e293b"
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            RowLayout {
              Text { text: "GRAPHICS / GPU"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
              Item { Layout.fillWidth: true }
              Text { text: "READY"; font.pixelSize: 10; color: "#a855f7"; font.bold: true }
            }
            Text {
              text: serverData.isHomeWorkstation ? "Apple Silicon Metal / Discrete" : "Virtual 3D / Waypipe LLVM"
              font.pixelSize: 12
              color: "#f8fafc"
              font.bold: true
            }
            Text {
              text: "Wayland Hardware Accelerated"
              font.pixelSize: 10
              color: "#64748b"
            }
          }
        }
      }

      // Quick Toolbar for Machine
      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Button {
          text: "󰋊 Mount Drive"
          background: Rectangle { radius: 6; color: "#1e293b"; border.color: "#334155" }
          contentItem: Text { text: "󰋊 Mount Drive"; color: "#f59e0b"; font.pixelSize: 11; font.bold: true }
          onClicked: {
            taskManagerModal.visible = false;
            consentModal.openForServer(serverData.name, String(serverData.id));
          }
        }

        Button {
          text: "󰆍 SSH Terminal"
          background: Rectangle { radius: 6; color: "#1e293b"; border.color: "#334155" }
          contentItem: Text { text: "󰆍 SSH Terminal"; color: "#38bdf8"; font.pixelSize: 11; font.bold: true }
          onClicked: ocloud.openTerminal(serverData.name, serverData.ipv4)
        }

        Item { Layout.fillWidth: true }

        Button {
          text: "󰑐 Reboot Node"
          background: Rectangle { radius: 6; color: "#1e293b" }
          contentItem: Text { text: "󰑐 Reboot"; color: "#94a3b8"; font.pixelSize: 11 }
          onClicked: ocloud.serverAction("reboot", String(serverData.id))
        }

        Button {
          text: "󰅙 Kill / Power Off"
          background: Rectangle { radius: 6; color: "#3b0d0d"; border.color: "#7f1d1d" }
          contentItem: Text { text: "󰅙 Stop Server"; color: "#ef4444"; font.pixelSize: 11; font.bold: true }
          onClicked: {
            ocloud.serverAction("stop", String(serverData.id));
            taskManagerModal.visible = false;
          }
        }
      }

      // Section Header: Active Processes
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Active Processes & Apps Running"
          font.pixelSize: 13
          font.bold: true
          color: "#f8fafc"
        }
        Item { Layout.fillWidth: true }
        Text {
          text: (telemetry.top_processes ? telemetry.top_processes.length : 0) + " processes monitored"
          font.pixelSize: 11
          color: "#64748b"
        }
      }

      // Process Table
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 10
        color: "#0f172a"
        border.color: "#1e293b"
        clip: true

        ColumnLayout {
          anchors.fill: parent
          spacing: 0

          // Table Header
          Rectangle {
            Layout.fillWidth: true
            height: 32
            color: "#131e36"
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              Text { text: "PID"; width: 60; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "% CPU"; width: 70; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "% MEM"; width: 70; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "COMMAND / PROCESS NAME"; Layout.fillWidth: true; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "ACTION"; width: 70; font.pixelSize: 10; font.bold: true; color: "#94a3b8"; horizontalAlignment: Text.AlignRight }
            }
          }

          // Table Rows
          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: telemetry.top_processes || []
            clip: true
            delegate: Rectangle {
              width: parent.width
              height: 38
              color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Text {
                  text: modelData.pid || "-"
                  width: 60
                  font.pixelSize: 11
                  color: "#64748b"
                  font.family: "monospace"
                }

                Text {
                  text: (modelData.cpu || "0.0") + "%"
                  width: 70
                  font.pixelSize: 11
                  font.bold: true
                  color: parseFloat(modelData.cpu || 0) > 10 ? "#ef4444" : "#f8fafc"
                }

                Text {
                  text: (modelData.mem || "0.0") + "%"
                  width: 70
                  font.pixelSize: 11
                  color: "#94a3b8"
                }

                Text {
                  text: modelData.cmd || "unknown"
                  Layout.fillWidth: true
                  font.pixelSize: 11
                  color: "#f8fafc"
                  elide: Text.ElideRight
                  font.family: "monospace"
                }

                Button {
                  text: "Kill"
                  width: 54
                  height: 24
                  background: Rectangle {
                    radius: 4
                    color: "#2a1215"
                    border.color: "#7f1d1d"
                  }
                  contentItem: Text {
                    text: "Kill"
                    color: "#ef4444"
                    font.pixelSize: 10
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                  }
                  onClicked: killProc(modelData.pid)
                }
              }
            }
          }
        }
      }
    }
  }
}
