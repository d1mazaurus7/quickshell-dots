import QtQuick
import "../../shell/theme"

// Значок Material Symbols для окна погоды.
// filled — плавная заливка (ось FILL), hovered/pressed — пружинистый масштаб,
// pop() и смена значка — короткий отклик; выключенный (enabled: false) — приглушён.
Text {
    id: icon

    property bool filled: false
    property bool hovered: false
    property bool pressed: false
    property real fill: filled ? 1 : 0
    Behavior on fill { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    function pop() { popAnim.restart(); }
    onTextChanged: pop()

    font.family: "Material Symbols Rounded"
    font.variableAxes: ({ "FILL": icon.fill })
    opacity: enabled ? 1 : 0.38
    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    transform: Scale {
        origin.x: icon.width / 2
        origin.y: icon.height / 2
        xScale: icon.pressed ? 0.88 : icon.hovered ? 1.15 : 1
        yScale: xScale
        Behavior on xScale { WeatherSpring {} }
    }

    SequentialAnimation {
        id: popAnim
        ScaleAnimator { target: icon; to: 0.7; duration: Tokens.animationFast / 2; easing.type: Easing.InCubic }
        ScaleAnimator { target: icon; to: 1; duration: Tokens.animationSlow; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }
}
