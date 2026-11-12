import QtQuick
import "../../../shell/theme"

// Плавная смена цвета: Behavior on color { SmoothColor {} }
ColorAnimation {
    duration: Tokens.animationFast
    easing.type: Easing.OutCubic
}
