import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import "../theme" as Theme
import "../shell/theme"

// Main PanelWindow
PanelWindow {
    implicitHeight: 50
    color: "transparent"
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        left: 20
        right: 20
    }
    Rectangle {
        id: barBackground
        radius: Tokens.radius(20)
        topLeftRadius: 0
        topRightRadius: 0
        width: parent.width
        height: parent.height
        color: Theme.Palette.background
    }
}
