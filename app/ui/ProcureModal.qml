import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: modal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.75)
  z: 1000

  signal serverProcured()

  function openModal() {
    nameField.text = "runner-" + Math.floor(Math.random() * 1000);
    modal.visible = true;
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block click-through
  }

  Rectangle {
    width: 480
    height: modalCol.implicitHeight + 48
    radius: 16
    color: cardBg
    border.color: borderSubtle
    border.width: 1
    anchors.centerIn: parent

    ColumnLayout {
      id: modalCol
      anchors.fill: parent
      anchors.margins: 24
      spacing: 16

      // Title
      RowLayout {
        spacing: 10
        Text { text: "🚀"; font.pixelSize: 22 }
        ColumnLayout {
          spacing: 2
          Text {
            text: "Procure Cloud VM"
            font.pixelSize: 16
            font.bold: true
            color: textPrimary
          }
          Text {
            text: "Instantly launch an ultra-fast companion node"
            font.pixelSize: 12
            color: textMuted
          }
        }
      }

      // Server Name
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Server Hostname"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        TextField {
          id: nameField
          Layout.fillWidth: true
          color: textPrimary
          background: Rectangle { radius: 6; color: "#080e18"; border.color: borderSubtle }
        }
      }

      // Server Type
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Instance Type"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        ComboBox {
          id: typeCombo
          Layout.fillWidth: true
          model: ["cx23 (Intel 2 vCPU / 4 GB RAM · €3.79/mo)", "cax11 (Ampere ARM 2 vCPU / 4 GB RAM · €3.29/mo)", "cpx21 (AMD 3 vCPU / 4 GB RAM · €6.90/mo)"]
        }
      }

      // Location (with ping note)
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Datacenter Location"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        ComboBox {
          id: locCombo
          Layout.fillWidth: true
          model: [
            "nbg1 (Nuremberg, Germany 🇩🇪 - Low Latency)",
            "fsn1 (Falkenstein, Germany 🇩🇪)",
            "hel1 (Helsinki, Finland 🇫🇮)",
            "sin (Singapore 🇸🇬)",
            "ash (Ashburn, VA, USA 🇺🇸)",
            "hil (Hillsboro, OR, USA 🇺🇸)"
          ]
        }
      }

      // Auto-Tailscale
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        CheckBox { id: tsCheck; checked: true }
        Text {
          text: "Auto-join Tailscale mesh network on boot"
          font.pixelSize: 11
          color: textPrimary
        }
      }

      // Actions
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Button {
          text: "Cancel"
          Layout.fillWidth: true
          background: Rectangle { radius: 6; color: "#1e293b" }
          contentItem: Text {
            text: "Cancel"
            color: textPrimary
            font.bold: true
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: modal.visible = false
        }

        Button {
          id: deployBtn
          text: "Deploy Instance"
          Layout.fillWidth: true
          background: Rectangle {
            radius: 6
            color: deployBtn.hovered ? "#0284c7" : "#0369a1"
          }
          contentItem: Text {
            text: deployBtn.text
            color: "#ffffff"
            font.bold: true
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          onClicked: {
            modal.visible = false;
            var srvTypes = ["cx23", "cax11", "cpx21"];
            var locs = ["nbg1", "fsn1", "hel1", "sin", "ash", "hil"];
            var chosenType = srvTypes[typeCombo.currentIndex] || "cx23";
            var chosenLoc = locs[locCombo.currentIndex] || "nbg1";
            ocloud.procureServer(nameField.text.trim(), chosenType, chosenLoc, tsCheck.checked ? "auto" : "");
            modal.serverProcured();
          }
        }
      }
    }
  }
}
