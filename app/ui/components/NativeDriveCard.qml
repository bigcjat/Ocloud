import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root
  Layout.fillWidth: true
  implicitHeight: (root.isMounted && root.usedPercent >= 0) ? 50 : 46
  radius: 2
  color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "transparent"
  border.color: driveMouse.containsMouse
    ? ((typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7")
    : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333")
  border.width: 1

  property string driveName: "Drive"
  property string driveType: "Local"
  property string iconSource: "icons/hard-drive.svg"
  property string mountPath: ""
  property string capacityText: ""
  property real usedPercent: -1 // 0.0 to 1.0, or -1 if unknown
  property string statusVariant: "success"
  property string statusText: "Mounted"
  property bool isConnected: true
  property bool isMounted: true
  property bool autoMount: false
  property bool showAutoMount: false
  property bool showDisconnect: false
  property bool showSettings: true

  property bool isBusy: false
  property string busyAction: ""
  property string lastError: ""

  readonly property string appFontFamily: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  readonly property color textColor: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
  readonly property color mutedColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
  readonly property color accentColor: (typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7"
  readonly property color borderCol: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#333333"

  Connections {
    target: (typeof ocloud !== "undefined") ? ocloud : null
    function onActionCompleted(action, success, msg) {
      if (action === "mountCloudAccount" || action === "unmountCloudAccount" || action === "mountStorageBox" || action === "unmountStorageBox") {
        root.isBusy = false;
        root.busyAction = "";
        if (!success) {
          root.lastError = msg || "Operation failed";
        } else {
          root.lastError = "";
        }
      }
    }
  }

  signal mountClicked()
  signal unmountClicked()
  signal openClicked()
  signal settingsClicked()
  signal disconnectClicked()
  signal autoMountToggled(bool enabled)

  MouseArea {
    id: driveMouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }

  Item {
    id: cardInner
    anchors.fill: parent
    anchors.margins: 10

    // =========================================================
    // RIGHT ACTION TOOLBAR (PINNED TO ABSOLUTE RIGHT EDGE)
    // =========================================================
    RowLayout {
      id: actionRow
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      // Open in File Manager
      Rectangle {
        visible: root.isMounted
        implicitWidth: openText.implicitWidth + 14
        implicitHeight: 24
        radius: 2
        color: openMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
          : "transparent"
        border.color: openMouse.containsMouse ? root.accentColor : root.borderCol
        border.width: 1

        Text {
          id: openText
          anchors.centerIn: parent
          text: "Open"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: openMouse.containsMouse ? root.accentColor : root.textColor
        }

        MouseArea {
          id: openMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openClicked()
        }
      }

      // Mount Drive Button
      Rectangle {
        visible: !root.isMounted && root.isConnected
        implicitWidth: mntText.implicitWidth + 14
        implicitHeight: 24
        radius: 2
        color: mntMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
          : "transparent"
        border.color: mntMouse.containsMouse ? root.accentColor : root.borderCol
        border.width: 1

        Text {
          id: mntText
          anchors.centerIn: parent
          text: (root.isBusy && root.busyAction === "mounting") ? "Mounting..." : "Mount"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: mntMouse.containsMouse ? root.accentColor : root.textColor
        }

        MouseArea {
          id: mntMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: !root.isBusy
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.isBusy = true;
            root.busyAction = "mounting";
            root.lastError = "";
            root.mountClicked();
          }
        }
      }

      // Unmount / Disconnect Button
      Rectangle {
        visible: root.isMounted && root.mountPath !== "/" && root.driveType.indexOf("Internal") < 0
        implicitWidth: unmText.implicitWidth + 14
        implicitHeight: 24
        radius: 2
        color: unmMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
          : "transparent"
        border.color: unmMouse.containsMouse ? root.accentColor : root.borderCol
        border.width: 1

        Text {
          id: unmText
          anchors.centerIn: parent
          text: (root.isBusy && root.busyAction === "unmounting")
            ? "Unmounting..."
            : (root.showDisconnect ? "Disconnect" : "Unmount")
          font.family: root.appFontFamily
          font.pixelSize: 11
          font.bold: true
          color: unmMouse.containsMouse ? root.accentColor : root.textColor
        }

        MouseArea {
          id: unmMouse
          anchors.fill: parent
          hoverEnabled: true
          enabled: !root.isBusy
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.isBusy = true;
            root.busyAction = "unmounting";
            root.lastError = "";
            if (root.showDisconnect) {
              root.disconnectClicked();
            } else {
              root.unmountClicked();
            }
          }
        }
      }

      // Auto-Mount Toggle Button
      Rectangle {
        visible: root.showAutoMount && root.isConnected
        implicitWidth: autoText.implicitWidth + 14
        implicitHeight: 24
        radius: 2
        color: autoMouse.containsMouse
          ? ((typeof theme !== "undefined" && theme.selection) ? theme.selection : "transparent")
          : "transparent"
        border.color: autoMouse.containsMouse ? root.accentColor : root.borderCol
        border.width: 1

        Text {
          id: autoText
          anchors.centerIn: parent
          text: root.autoMount ? "Auto: ON" : "Auto: OFF"
          font.family: root.appFontFamily
          font.pixelSize: 10
          font.bold: true
          color: root.autoMount
            ? ((typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : root.accentColor)
            : root.mutedColor
        }

        MouseArea {
          id: autoMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.autoMountToggled(!root.autoMount)
        }
      }
    }

    // =========================================================
    // LEFT INFO GROUP (ANCHORED FROM LEFT TO ACTION ROW)
    // =========================================================
    RowLayout {
      anchors.left: parent.left
      anchors.right: actionRow.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10

      // 6px Flea Status Dot
      Rectangle {
        Layout.preferredWidth: 6
        Layout.preferredHeight: 6
        Layout.alignment: Qt.AlignVCenter
        radius: 3
        color: root.isMounted
          ? ((typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : root.accentColor)
          : root.mutedColor
      }

      // Drive ThemeIcon (Razor sharp)
      ThemeIcon {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        Layout.alignment: Qt.AlignVCenter
        source: root.iconSource
        color: driveMouse.containsMouse ? root.accentColor : root.textColor
      }

      // Details: Title + Mount/Capacity
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Text {
            text: root.driveName
            font.family: root.appFontFamily
            font.pixelSize: 13
            font.bold: true
            color: root.textColor
            elide: Text.ElideRight
          }

          Text {
            text: "· " + (root.isMounted ? "mounted" : "unmounted")
            font.family: root.appFontFamily
            font.pixelSize: 11
            color: root.isMounted
              ? ((typeof theme !== "undefined" && theme.homeGreen) ? theme.homeGreen : root.accentColor)
              : root.mutedColor
          }

          Item { Layout.fillWidth: true }
        }

        Text {
          Layout.fillWidth: true
          text: (root.mountPath ? root.mountPath : root.driveType) + (root.capacityText ? (" · " + root.capacityText) : "")
          font.family: root.appFontFamily
          font.pixelSize: 11
          color: root.mutedColor
          elide: Text.ElideRight
        }
      }
    }

    // =========================================================
    // 2PX GAUGE HAIRLINE (PINNED TO BOTTOM OF CARD)
    // =========================================================
    Rectangle {
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -4
      anchors.left: parent.left
      anchors.right: parent.right
      height: 2
      radius: 1
      color: root.borderCol
      visible: root.isMounted && root.usedPercent >= 0

      Rectangle {
        height: parent.height
        radius: 1
        width: Math.max(2, parent.width * Math.min(1.0, Math.max(0.0, root.usedPercent)))
        color: root.usedPercent > 0.9
          ? ((typeof theme !== "undefined" && theme.dangerRed) ? theme.dangerRed : root.accentColor)
          : root.accentColor
      }
    }
  }
}
