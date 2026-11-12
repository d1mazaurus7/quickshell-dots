import QtQuick
import "../../shell/theme"

// Иконка Material Symbols: смена глифа — сжатие, замена, пружинистое появление
Text {
    id: root

    property string icon

    font.family: "Material Symbols Rounded"
    font.pixelSize: Tokens.scaled(20)
    Component.onCompleted: text = icon

    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

    onIconChanged: if (text !== "") swap.restart()

    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: root; property: "scale"; to: 0.4; duration: Tokens.animationFast / 2; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "opacity"; to: 0; duration: Tokens.animationFast / 2 }
        }
        PropertyAction { target: root; property: "text"; value: root.icon }
        PropertyAction { target: root; property: "rotation"; value: -60 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "scale"; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "rotation"; to: 0; duration: Tokens.animationMedium; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "opacity"; to: 1; duration: Tokens.animationFast }
        }
    }
}
