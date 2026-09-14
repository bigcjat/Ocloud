import QtQuick
import Quickshell
import "ui"
import "ui/components"

ShellRoot {
  id: shellRoot

  MainWindow {
    id: mainWindow
  }

  CloudWindowBadge {
    id: cloudBadge
  }
}
