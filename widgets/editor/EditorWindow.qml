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

    Item {
        id: content
        anchors.fill: parent
        opacity: root.reveal
        enabled: root.open

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Tokens.colors.background, 0.2)
        }

        // Клик по пустому месту снимает выделение
        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.widgets.selectedUid = "";
                root.widgets.addOpen = false;
            }
        }

        GridOverlay {
            anchors.fill: parent
            step: root.widgets.gridLive > 0 ? root.widgets.gridLive : root.widgets.cfg.gridSize
            opacity: root.widgets.cfg.grid ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }

        Repeater {
            model: root.widgets.uids

            WidgetFrame {
                required property string modelData
                uid: modelData
                widgets: root.widgets
                editorScreen: root.screen
            }
        }

        WidgetSettingsPanel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: toolbar.top
            anchors.bottomMargin: Tokens.spacingMediumV
            widgets: root.widgets
        }

        EditorToolbar {
            id: toolbar
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.spacingLargeV * 2
            widgets: root.widgets
            onAddRequested: type => root.widgets.add(type, content.width, content.height)
        }
    }
}
