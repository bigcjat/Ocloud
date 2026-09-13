import QtQuick
import QtQuick.Controls

TextField {
  id: root

  implicitHeight: 32
  font.family: (typeof theme !== "undefined" && theme.fontFamily) ? theme.fontFamily : "monospace"
  font.pixelSize: 11
  color: (typeof theme !== "undefined" && theme.textPrimary) ? theme.textPrimary : "#c0caf5"
  placeholderTextColor: (typeof theme !== "undefined" && theme.textMuted) ? theme.textMuted : "#565f89"
  leftPadding: 10
  rightPadding: 10

  background: Rectangle {
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? Math.max(4, theme.cornerRadius - 2) : 6
    color: (typeof theme !== "undefined" && theme.cardBgAlt) ? theme.cardBgAlt : "#13141c"
    border.color: root.activeFocus ? ((typeof theme !== "undefined" && theme.accent) ? theme.accent : "#7aa2f7") : ((typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#414868")
    border.width: 1
  }
}
