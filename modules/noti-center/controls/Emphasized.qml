import QtQuick
import "../../../shell/theme"

// Выразительное движение с лёгким перелётом (MD3 expressive):
// перестановка и масштабирование виджетов, морфинг формы.
NumberAnimation {
    duration: Tokens.animationSlow
    easing.type: Easing.OutBack
    easing.overshoot: 1.1
}
