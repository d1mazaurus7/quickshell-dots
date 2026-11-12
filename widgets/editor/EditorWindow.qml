pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../shell/theme"
import ".."

// Редактор виджетов поверх рабочего стола: сетка, рамки виджетов, панель инструментов
PanelWindow {
    id: root

    required property WidgetsState widgets

    readonly property bool open: widgets.editing
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    screen: Quickshell.screens.find(s => s.name === root.widgets.editorOutput) ?? Quickshell.screens[0]
    visible: open || reveal > 0
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs:widget-editor"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.widgets.editing = false
    }

    EditorContent {
        anchors.fill: parent
        opacity: root.reveal
        enabled: root.open
        widgets: root.widgets
        editorScreen: root.screen
    }
}
