import QtQuick
import Quickshell
import "../../shell/theme"

// M3 переключатель: checked — текущее значение (привязать к Config),
// toggled(checked) — новое значение; в Config пишет страница
Rectangle {
    id: root

    property bool checked

    readonly property var colors: Tokens.colors
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed

    signal toggled(bool checked)

    function toggle() {
        Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/sfx.wav")]);
        toggled(!checked);
    }

    implicitWidth: Tokens.scaled(52)
    implicitHeight: Tokens.scaled(32)
    radius: height / 2
    activeFocusOnTab: true
    color: !enabled ? Qt.alpha(colors.on_surface, 0.12)
         : checked ? colors.primary : colors.surface_container_highest
    border.width: checked ? 0 : 2
    border.color: !enabled ? Qt.alpha(colors.on_surface, 0.12)
                : activeFocus ? colors.primary : colors.outline
    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
    Behavior on border.color { ColorAnimation { duration: Tokens.animationMedium } }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggle();
            event.accepted = true;
        }
    }

    Item {
        id: thumb
        readonly property int size: Tokens.scaled(root.pressed ? 28 : root.checked ? 24 : root.hovered ? 20 : 16)

        anchors.verticalCenter: parent.verticalCenter
        width: root.height
        height: root.height
        x: root.checked ? root.width - width : 0
        Behavior on x { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

        // State layer — ореол вокруг ползунка
        Rectangle {
            anchors.centerIn: parent
            width: Tokens.scaled(40)
            height: width
            radius: width / 2
            color: root.checked ? root.colors.primary : root.colors.on_surface
            opacity: !root.enabled ? 0 : root.pressed ? 0.10 : root.hovered || root.activeFocus ? 0.08 : 0
            scale: root.pressed || root.hovered || root.activeFocus ? 1 : 0.6
            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }

        // Ползунок: растёт при наведении и нажатии
        Rectangle {
            anchors.centerIn: parent
            width: thumb.size
            height: thumb.size
            radius: width / 2
            color: !root.enabled ? (root.checked ? root.colors.surface : Qt.alpha(root.colors.on_surface, 0.38))
                 : root.checked ? (root.hovered || root.pressed ? root.colors.primary_container : root.colors.on_primary)
                 : (root.hovered || root.pressed ? root.colors.on_surface_variant : root.colors.outline)
            Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

            Text {
                anchors.centerIn: parent
                text: "check"
                color: root.enabled ? root.colors.on_primary_container : Qt.alpha(root.colors.on_surface, 0.38)
                font.family: "Material Symbols Rounded"
                font.pixelSize: Tokens.scaled(16)
                opacity: root.checked ? 1 : 0
                scale: root.checked ? 1 : 0.3
                rotation: root.checked ? 0 : -45
                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggle()
    }
}
