import QtQuick
import Quickshell
import "../../shell/theme"

// Переключатель в стиле Material: checked — текущее значение (привязать к Config),
// toggled(checked) — новое значение; в Config пишет страница
Rectangle {
    id: root

    property bool checked

    readonly property var colors: Tokens.colors

    signal toggled(bool checked)

    implicitWidth: Tokens.scaled(52)
    implicitHeight: Tokens.scaled(32)
    radius: height / 2
    color: checked ? colors.primary : colors.surface_container_highest
    border.width: checked ? 0 : 2
    border.color: colors.outline
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

    // Ползунок: растёт при наведении и нажатии
    Rectangle {
        // Не readonly: на свойство навешан Behavior
        property int size: Tokens.scaled(area.pressed ? 28 : root.checked ? 24 : area.containsMouse ? 20 : 16)

        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - (root.height - width) / 2 : (root.height - width) / 2
        width: size
        height: size
        radius: size / 2
        color: root.checked ? root.colors.on_primary : root.colors.outline
        Behavior on x { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on size { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/sfx.wav")]);
            root.toggled(!root.checked);
        }
    }
}
