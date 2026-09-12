import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  Layout.fillWidth: true
  Layout.fillHeight: true

  property var pingResults: []
  property bool probing: false

  function runProber() {
    probing = true;
    var raw = ocloud.fetchPing();
    try {
      pingResults = JSON.parse(raw);
    } catch (e) {
      console.log("Ping error: " + e);
    }
    probing = false;
  }

  ScrollView {
    anchors.fill: parent
    anchors.margins: 24
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
      width: parent.width
      spacing: 24

      // Header
      ColumnLayout {
        spacing: 2
        Text {
          text: "Vault & Latency Prober"
          font.pixelSize: 22
          font.bold: true
          color: textPrimary
        }
        Text {
          text: "Hardware-derived AES-256-GCM credentials vault and live datacenter latency prober"
          font.pixelSize: 13
          color: textSecondary
        }
      }

      // Vault Credentials Card
      Rectangle {
        Layout.fillWidth: true
        height: vaultCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle

        ColumnLayout {
          id: vaultCol
          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#0c4a6e"
              Text { anchors.centerIn: parent; text: "🔐"; font.pixelSize: 16 }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Ocloud Credentials Vault"
                font.pixelSize: 16
                font.bold: true
                color: textPrimary
              }
              Text {
                text: "Encrypted at rest at ~/.config/omarchy/vault.enc (AES-256-GCM, chmod 600)"
                font.pixelSize: 11
                color: textMuted
              }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
              height: 24
              width: 90
              radius: 6
              color: "#064e3b"
              Text {
                anchors.centerIn: parent
                text: "LOCKED 600"
                font.pixelSize: 10
                font.bold: true
                color: homeGreen
              }
            }
          }

          // Hetzner Token Field
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { text: "Hetzner Cloud API Token"; font.pixelSize: 11; font.bold: true; color: textSecondary }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              TextField {
                id: tokenField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "Enter your Hetzner Cloud API token"
                color: textPrimary
                placeholderTextColor: textMuted
                background: Rectangle {
                  radius: 6
                  color: "#080e18"
                  border.color: borderSubtle
                }
              }
              Button {
                text: "Save to Vault"
                onClicked: {
                  if (tokenField.text.trim()) {
                    ocloud.setVaultSecret("api_token", tokenField.text.trim());
                    tokenField.text = "";
                  }
                }
              }
            }
          }

          // Tailscale Key Field
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text { text: "Tailscale Reusable Auth Key (Optional for auto-join)"; font.pixelSize: 11; font.bold: true; color: textSecondary }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              TextField {
                id: tsField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "tskey-auth-..."
                color: textPrimary
                placeholderTextColor: textMuted
                background: Rectangle {
                  radius: 6
                  color: "#080e18"
                  border.color: borderSubtle
                }
              }
              Button {
                text: "Save to Vault"
                onClicked: {
                  if (tsField.text.trim()) {
                    ocloud.setVaultSecret("tailscale_auth_key", tsField.text.trim());
                    tsField.text = "";
                  }
                }
              }
            }
          }
        }
      }

      // Latency Prober Card
      Rectangle {
        Layout.fillWidth: true
        height: probeCol.implicitHeight + 40
        radius: 12
        color: cardBg
        border.color: borderSubtle

        ColumnLayout {
          id: probeCol
          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: 32
              height: 32
              radius: 8
              color: "#1e1b4b"
              Text { anchors.centerIn: parent; text: "🌐"; font.pixelSize: 16 }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Global Datacenter Latency Prober"
                font.pixelSize: 16
                font.bold: true
                color: textPrimary
              }
              Text {
                text: "Tests concurrent TCP handshakes to find the optimal deployment region"
                font.pixelSize: 11
                color: textMuted
              }
            }
            Item { Layout.fillWidth: true }
            Button {
              id: probeBtn
              text: probing ? "Probing..." : "⚡ Run Latency Test"
              enabled: !probing
              background: Rectangle {
                radius: 6
                color: probeBtn.hovered ? "#0284c7" : "#0369a1"
              }
              contentItem: Text {
                text: probeBtn.text
                color: "#ffffff"
                font.pixelSize: 11
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              onClicked: runProber()
            }
          }

          Text {
            visible: pingResults.length === 0 && !probing
            text: "Click 'Run Latency Test' to probe all global regions and automatically rank them by ping."
            font.pixelSize: 12
            color: textMuted
          }

          // Latency Results Table
          Repeater {
            model: pingResults

            delegate: Rectangle {
              Layout.fillWidth: true
              height: 48
              radius: 8
              color: index === 0 ? "#081b26" : "#080e18"
              border.color: index === 0 ? "#0284c7" : borderSubtle

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 16

                Text {
                  text: "#" + (index + 1)
                  font.pixelSize: 12
                  font.bold: true
                  color: index === 0 ? accentSky : textMuted
                }

                Text {
                  text: modelData.flag + " " + modelData.name
                  font.pixelSize: 13
                  font.bold: true
                  color: textPrimary
                }

                Rectangle {
                  height: 18
                  width: 50
                  radius: 4
                  color: "#1e293b"
                  Text {
                    anchors.centerIn: parent
                    text: modelData.id
                    font.pixelSize: 10
                    font.bold: true
                    color: textSecondary
                  }
                }

                Item { Layout.fillWidth: true }

                Text {
                  text: modelData.optimalFor || ""
                  font.pixelSize: 11
                  color: textMuted
                }

                Rectangle {
                  height: 22
                  width: pingBadgeText.implicitWidth + 16
                  radius: 6
                  color: modelData.quality === "great" ? "#064e3b" : modelData.quality === "good" ? "#451a03" : "#3b0d0d"
                  Text {
                    id: pingBadgeText
                    anchors.centerIn: parent
                    text: (modelData.qualityBadge || "") + " " + (modelData.pingDisplay || "Timeout")
                    font.pixelSize: 11
                    font.bold: true
                    color: modelData.quality === "great" ? homeGreen : modelData.quality === "good" ? warningAmber : dangerRed
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
