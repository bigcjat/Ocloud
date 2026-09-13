import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
  id: root
  Layout.fillWidth: true
  radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 8
  color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : (typeof window !== "undefined" && window.cardBg ? window.cardBg : "#1f2335")
  border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : (typeof window !== "undefined" && window.borderSubtle ? window.borderSubtle : "#292e42")
  border.width: 1
}
