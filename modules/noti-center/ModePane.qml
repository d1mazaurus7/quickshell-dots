import QtQuick
import "../../shell/theme"

// Экран страницы дня: появляется прозрачностью и небольшим сдвигом снизу
Item {
    id: pane

    required property bool active
    required property real s
    property real shift: active ? 0 : 14 * s

    anchors.fill: parent
    opacity: active ? 1 : 0
    visible: active || opacity > 0
    enabled: active
    transform: Translate { y: pane.shift }
    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on shift { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
}
