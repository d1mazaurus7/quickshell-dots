import QtQuick
import "../../shell/theme"

// Иконка Material Symbols: контурный и залитый варианты плавно сменяют друг друга
// (промежуточные значения оси FILL дают дыры в глифах), пружинка при наведении и смене значка
Item {
    id: root

    property string icon
    property real size: Tokens.scaled(20)
    property bool filled: false
    property bool hovered: false
    property real hoverScale: 1.15
    property color color: Tokens.colors.on_surface
    property real bump: 1

    implicitWidth: size
    implicitHeight: size
    scale: hovered ? hoverScale : 1

    transform: Scale {
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.bump
        yScale: root.bump
    }

    Behavior on color { ColorAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    onIconChanged: pop.restart()

    NumberAnimation {
        id: pop
        target: root
        property: "bump"
        from: 0.55
        to: 1
        duration: Tokens.animationSlow * 1.5
        easing.type: Easing.OutBack
        easing.overshoot: 2.6
    }

    // 0 — контур, 1 — заливка
    Repeater {
        model: 2

        Text {
            required property int index
            readonly property real target: root.filled === (index === 1) ? 1 : 0

            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            text: root.icon
            color: root.color
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.size
            font.variableAxes: ({ "FILL": index })
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: target
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
        }
    }
}
