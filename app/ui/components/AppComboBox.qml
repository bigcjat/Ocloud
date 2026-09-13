import QtQuick
import QtQuick.Controls

ComboBox {
  id: root

  implicitHeight: 32
  implicitWidth: 200
  padding: 0

  font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  font.pixelSize: 11
  font.bold: true

  background: Rectangle {
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
    color: root.hovered ? ((typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#24283b") : ((typeof theme !== "undefined" && theme.cardBgAlt) ? theme.cardBgAlt : "#13141c")
    border.color: root.activeFocus || root.popup.visible ? ((typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7") : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868")
    border.width: 1
  }

  contentItem: Text {
    leftPadding: 10
    rightPadding: 26
    text: root.displayText
    font: root.font
    color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  indicator: Canvas {
    id: canvas
    x: root.width - width - 10
    y: (root.height - height) / 2
    width: 8
    height: 5
    onPaint: {
      var ctx = getContext("2d");
      ctx.reset();
      ctx.moveTo(0, 0);
      ctx.lineTo(width, 0);
      ctx.lineTo(width / 2, height);
      ctx.closePath();
      ctx.fillStyle = (typeof theme !== "undefined" && theme.textSecondary) ? theme.textSecondary : "#a9b1d6";
      ctx.fill();
    }
  }

  popup: Popup {
    y: root.height + 4
    width: root.width
    implicitHeight: Math.min(contentItem.implicitHeight + 8, 200)
    padding: 4

    contentItem: ListView {
      clip: true
      implicitHeight: contentHeight
      model: root.popup.visible ? root.delegateModel : null
      currentIndex: root.highlightedIndex
      ScrollIndicator.vertical: ScrollIndicator { }
    }

    background: Rectangle {
      radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
      color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#24283b"
      border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868"
      border.width: 1
    }
  }

  delegate: ItemDelegate {
    width: root.width - 8
    height: 28

    contentItem: Text {
      text: modelData
      color: highlighted ? ((typeof theme !== "undefined" && !theme.isDark) ? "#ffffff" : "#0e0e14") : ((typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5")
      font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
      font.pixelSize: 11
      font.bold: root.currentIndex === index
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    background: Rectangle {
      radius: 4
      color: highlighted ? ((typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7") : "transparent"
    }
  }
}
