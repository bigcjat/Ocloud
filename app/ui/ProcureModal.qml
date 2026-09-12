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
        Image {
          width: 24
          height: 24
          source: Qt.resolvedUrl("icons/server.svg")
          fillMode: Image.PreserveAspectFit
          smooth: true
        }
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

      // Cloud Provider Selection
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Cloud Provider (API)"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Image {
            width: 28
            height: 28
            source: providerCombo.currentIndex === 0 ? Qt.resolvedUrl("icons/hetzner.svg") : (providerCombo.currentIndex === 1 ? Qt.resolvedUrl("icons/aws.svg") : (providerCombo.currentIndex === 2 ? Qt.resolvedUrl("icons/oracle.svg") : (providerCombo.currentIndex === 3 ? Qt.resolvedUrl("icons/digitalocean.svg") : Qt.resolvedUrl("icons/vultr.svg"))))
            fillMode: Image.PreserveAspectFit
            smooth: true
          }
          ComboBox {
            id: providerCombo
            Layout.fillWidth: true
            model: [
              "Hetzner Cloud (Standard & ARM)",
              "Amazon Web Services (AWS Lightsail)",
              "Oracle Cloud (OCI Always-Free)",
              "DigitalOcean Droplets",
              "Vultr Compute"
            ]
          onCurrentIndexChanged: {
            if (currentIndex === 0) { // Hetzner
              typeCombo.model = ["cx23 (Intel 2 vCPU / 4 GB RAM · €3.79/mo)", "cax11 (Ampere ARM 2 vCPU / 4 GB RAM · €3.29/mo)", "cpx21 (AMD 3 vCPU / 4 GB RAM · €6.90/mo)"];
              locCombo.model = ["nbg1 (Nuremberg, Germany [EU])", "fsn1 (Falkenstein, Germany [EU])", "hel1 (Helsinki, Finland [EU])", "ash (Ashburn, VA, USA [US])", "hil (Hillsboro, OR, USA [US])"];
            } else if (currentIndex === 1) { // AWS
              typeCombo.model = ["nano (1 vCPU / 512 MB · $3.50/mo)", "micro (1 vCPU / 1 GB · $5.00/mo)", "small (2 vCPU / 2 GB · $10.00/mo)"];
              locCombo.model = ["us-east-1 (N. Virginia [US])", "us-west-2 (Oregon [US])", "eu-central-1 (Frankfurt [EU])", "ap-northeast-1 (Tokyo [JP])"];
            } else if (currentIndex === 2) { // Oracle
              typeCombo.model = ["VM.Standard.A1.Flex (4 OCPU / 24 GB RAM · €0 Always Free)", "VM.Standard.E2.1.Micro (1 OCPU / 1 GB RAM · €0 Free)"];
              locCombo.model = ["eu-frankfurt-1 (Germany [EU])", "us-ashburn-1 (USA [US])", "ap-tokyo-1 (Japan [JP])"];
            } else if (currentIndex === 3) { // DigitalOcean
              typeCombo.model = ["s-1vcpu-1gb (Basic · $6.00/mo)", "s-1vcpu-2gb (Basic · $12.00/mo)", "s-2vcpu-4gb (Basic · $24.00/mo)"];
              locCombo.model = ["nyc1 (New York [US])", "sfo3 (San Francisco [US])", "fra1 (Frankfurt [EU])", "sgp1 (Singapore [AP])"];
            } else { // Vultr
              typeCombo.model = ["vc2-1c-1gb (Regular · $5.00/mo)", "vc2-1c-2gb (Regular · $10.00/mo)", "vc2-2c-4gb (High Perf · $24.00/mo)"];
              locCombo.model = ["ewr (New Jersey [US])", "ord (Chicago [US])", "fra (Frankfurt [EU])", "nrt (Tokyo [JP])"];
            }
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

      // OS Template Distribution Selector
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "OS Distribution Template"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Image {
            width: 22
            height: 22
            source: osCombo.currentIndex === 0 ? Qt.resolvedUrl("icons/alpine.svg") : (osCombo.currentIndex === 1 ? Qt.resolvedUrl("icons/arch.svg") : Qt.resolvedUrl("icons/server.svg"))
            fillMode: Image.PreserveAspectFit
            smooth: true
          }
          ComboBox {
            id: osCombo
            Layout.fillWidth: true
            model: [
              "Alpine Linux 3.20 (Ultra-minimal 130MB · Fastest boot)",
              "Arch Linux (Rolling release · Latest kernel & pacman)",
              "Ubuntu Minimal 24.04 LTS (Standard Debian/Ubuntu ecosystem)"
            ]
          }
        }
      }

      // Server Type
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Instance Spec / Tier"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        ComboBox {
          id: typeCombo
          Layout.fillWidth: true
          model: ["cx23 (Intel 2 vCPU / 4 GB RAM · €3.79/mo)", "cax11 (Ampere ARM 2 vCPU / 4 GB RAM · €3.29/mo)", "cpx21 (AMD 3 vCPU / 4 GB RAM · €6.90/mo)"]
        }
      }

      // Location
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Text { text: "Datacenter Region"; font.pixelSize: 11; font.bold: true; color: textSecondary }
        ComboBox {
          id: locCombo
          Layout.fillWidth: true
          model: [
            "nbg1 (Nuremberg, Germany [EU] - Lowest Latency)",
            "fsn1 (Falkenstein, Germany [EU])",
            "hel1 (Helsinki, Finland [EU])",
            "sin (Singapore [AP])",
            "ash (Ashburn, VA, USA [US])",
            "hil (Hillsboro, OR, USA [US])"
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
          text: "󰐊 Deploy Instance"
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
            var chosenOs = osCombo.currentIndex === 0 ? "alpine" : (osCombo.currentIndex === 1 ? "arch" : "ubuntu");
            ocloud.procureServer(nameField.text.trim(), chosenType, chosenLoc, tsCheck.checked ? "auto" : "", chosenOs);
            modal.serverProcured();
          }
        }
      }
    }
  }
}
