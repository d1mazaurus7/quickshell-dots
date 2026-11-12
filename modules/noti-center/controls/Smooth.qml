import QtQuick
import "../../../shell/theme"

// Стандартная плавная анимация чисел: Behavior on x { Smooth {} }
NumberAnimation {
    duration: Tokens.animationMedium
    easing.type: Easing.OutCubic
}
