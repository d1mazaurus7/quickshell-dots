import QtQuick
import "../../shell/theme"

// Пружинистый переход фигур и масштаба (M3 Expressive): лёгкий перелёт и мягкая остановка.
NumberAnimation {
    duration: Tokens.animationSlow
    easing.type: Easing.OutBack
    easing.overshoot: 1.4
}
