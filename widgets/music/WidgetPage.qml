import QtQuick
import "../../shell/theme"

// Страница виджета плеера: плавно появляется со сдвигом, неактивная скрыта
Item {
    property bool active: false

    width: parent.width
    height: parent.height
    x: active ? 0 : Tokens.scaled(16)
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on x { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
}
