import QtQuick
import "../../shell/theme"

// Текст окна погоды: шрифт интерфейса, плавная смена цвета (фон меняется с погодой).
Text {
    font.family: Tokens.fontMedium.family
    Behavior on color { ColorAnimation { duration: Tokens.animationSlow } }
}
