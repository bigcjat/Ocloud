import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Rectangle {
  id: taskManagerModal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.80)
  z: 2000

  property var serverData: ({})
  property var telemetry: null
  property bool isLoading: false
  property string errorMessage: ""

  function openForServer(srv) {
    serverData = srv;
    telemetry = null;
    errorMessage = "";
    taskManagerModal.visible = true;
    refreshData();
  }

  function refreshData() {
    if (!serverData || !serverData.id) return;
    isLoading = true;
    errorMessage = "";
    ocloud.inspectMachineAsync(String(serverData.id));
  }

  Connections {
    target: ocloud
    function onInspectFinished(srvId, jsonStr) {
      if (serverData && String(serverData.id) === String(srvId)) {
        isLoading = false;
        try {
          var parsed = JSON.parse(jsonStr);
          if (parsed && (parsed.ram_total || parsed.load_1m !== undefined)) {
            telemetry = parsed;
            errorMessage = "";
          } else if (parsed && parsed.error) {
            telemetry = null;
            errorMessage = parsed.error;
          } else {
            telemetry = null;
            errorMessage = "Telemetry unreachable";
          }
        } catch (e) {
          telemetry = null;
          errorMessage = "Failed to parse telemetry";
        }
      }
    }
  }

  function killProc(pid) {
    if (!serverData || !serverData.id) return;
    ocloud.killProcess(String(serverData.id), String(pid));
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block background clicks
  }

  // Main Card
  Rectangle {
    width: Math.min(parent.width - 16, 880)
    height: Math.min(parent.height - 16, 680)
    anchors.centerIn: parent
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 12
    color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#0b1220"
    border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#1e293b"
    border.width: 1
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: parent.width < 500 ? 12 : 20
      spacing: parent.width < 500 ? 10 : 16

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
            source: serverData.isHomeWorkstation ? Qt.resolvedUrl("../icons/device-workstation.svg") : ((serverData.providerIcon && serverData.providerIcon.length > 0) ? serverData.providerIcon : Qt.resolvedUrl("../icons/server.svg"))
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
            text: "Host: " + (serverData.ipv4 || "No IP") + " · Provider: " + (serverData.provider || "hetzner").toUpperCase() + " · Uptime: " + ((telemetry && telemetry.uptime) ? telemetry.uptime : (isLoading ? "Connecting..." : "N/A"))
            font.pixelSize: 12
            color: "#94a3b8"
          }
        }

        Item { Layout.fillWidth: true }

        AppButton {
          text: "Refresh"
          variant: "secondary"
          onClicked: refreshData()
        }

        AppButton {
          text: "Close"
          variant: "secondary"
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
                text: (telemetry && telemetry.load_1m !== undefined) ? ("1m: " + telemetry.load_1m + " · 5m: " + telemetry.load_5m) : (isLoading ? "Reading..." : "--")
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
                width: (telemetry && telemetry.load_1m !== undefined) ? Math.min(parent.width, Math.max(0, parent.width * (parseFloat(telemetry.load_1m) / 2.0))) : 0
                color: "#38bdf8"
              }
            }
            Text {
              text: (telemetry && telemetry.load_1m !== undefined) ? ("Load: " + telemetry.load_1m + " avg") : (isLoading ? "Fetching CPU load..." : (errorMessage ? "Unavailable" : "--"))
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
                text: (telemetry && telemetry.ram_percent !== undefined) ? (telemetry.ram_percent + "%") : "--%"
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
                width: (telemetry && telemetry.ram_percent !== undefined) ? Math.min(parent.width, Math.max(0, parent.width * (telemetry.ram_percent / 100.0))) : 0
                color: "#10b981"
              }
            }
            Text {
              text: (telemetry && telemetry.ram_total) ? ((telemetry.ram_used / 1073741824).toFixed(1) + " GB / " + (telemetry.ram_total / 1073741824).toFixed(1) + " GB") : (isLoading ? "Measuring memory..." : "--")
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
                text: (telemetry && telemetry.disk_percent !== undefined) ? (telemetry.disk_percent + "%") : "--%"
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
                width: (telemetry && telemetry.disk_percent !== undefined) ? Math.min(parent.width, Math.max(0, parent.width * (telemetry.disk_percent / 100.0))) : 0
                color: "#f59e0b"
              }
            }
            Text {
              text: (telemetry && telemetry.disk_total) ? ((telemetry.disk_used / 1073741824).toFixed(1) + " GB / " + (telemetry.disk_total / 1073741824).toFixed(1) + " GB") : (isLoading ? "Measuring disk..." : "--")
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

        AppButton {
          text: serverData.is_drive_mounted ? "Unmount Drive" : "Mount Drive"
          variant: "secondary"
          onClicked: {
            if (serverData.is_drive_mounted) {
              ocloud.unmountEphemeralVm();
              serverData.is_drive_mounted = false;
            } else {
              taskManagerModal.visible = false;
              consentModal.openForServer(serverData.name, String(serverData.id));
            }
          }
        }

        AppButton {
          text: "SSH Terminal"
          variant: "secondary"
          onClicked: ocloud.openTerminal(serverData.name, serverData.ipv4, serverData.user || "root")
        }

        Item { Layout.fillWidth: true }

        AppButton {
          text: "Reboot"
          variant: "secondary"
          onClicked: ocloud.serverAction("reboot", String(serverData.id))
        }

        AppButton {
          text: "Stop Server"
          variant: "danger"
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
          text: ((telemetry && telemetry.top_processes) ? telemetry.top_processes.length : 0) + " processes monitored"
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
              spacing: 12
              Text { text: "PID"; Layout.preferredWidth: 64; Layout.minimumWidth: 64; Layout.maximumWidth: 64; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "% CPU"; Layout.preferredWidth: 64; Layout.minimumWidth: 64; Layout.maximumWidth: 64; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "% MEM"; Layout.preferredWidth: 64; Layout.minimumWidth: 64; Layout.maximumWidth: 64; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "COMMAND / PROCESS NAME"; Layout.fillWidth: true; font.pixelSize: 10; font.bold: true; color: "#94a3b8" }
              Text { text: "ACTION"; Layout.preferredWidth: 64; Layout.minimumWidth: 64; Layout.maximumWidth: 64; font.pixelSize: 10; font.bold: true; color: "#94a3b8"; horizontalAlignment: Text.AlignRight }
            }
          }

          // Table Rows
          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: (telemetry && telemetry.top_processes) ? telemetry.top_processes : []
            clip: true
            delegate: Rectangle {
              width: parent.width
              height: 38
              color: index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.02)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                  text: modelData.pid || "-"
                  Layout.preferredWidth: 64
                  Layout.minimumWidth: 64
                  Layout.maximumWidth: 64
                  font.pixelSize: 11
                  color: "#64748b"
                  font.family: "monospace"
                }

                Text {
                  text: (modelData.cpu || "0.0") + "%"
                  Layout.preferredWidth: 64
                  Layout.minimumWidth: 64
                  Layout.maximumWidth: 64
                  font.pixelSize: 11
                  font.bold: true
                  color: parseFloat(modelData.cpu || 0) > 10 ? "#ef4444" : "#f8fafc"
                }

                Text {
                  text: (modelData.mem || "0.0") + "%"
                  Layout.preferredWidth: 64
                  Layout.minimumWidth: 64
                  Layout.maximumWidth: 64
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
                  id: killProcBtn
                  Layout.preferredWidth: 64
                  Layout.minimumWidth: 64
                  Layout.maximumWidth: 64
                  implicitHeight: 24
                  background: Rectangle {
                    radius: 4
                    color: killProcBtn.hovered ? "#451216" : "#2a1215"
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
