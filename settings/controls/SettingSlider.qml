import QtQuick
import QtQuick.Controls
import Quickshell
import "../../shell/theme"

// Слайдер: value — текущее значение (привязать к Config),
// moved(value) — по отпусканию, чтобы не писать файл на каждый пиксель
Row {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property real value
    // Подпись значения справа
    property var formatValue: v => v.toFixed(1)

    readonly property var colors: Tokens.colors

    signal moved(real value)

    spacing: Tokens.spacingMedium

    Slider {
        id: slider
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Tokens.scaled(200)
        from: root.from
        to: root.to
        stepSize: root.stepSize
        snapMode: Slider.SnapAlways
        value: root.value

        // Щелчок на каждом шаге при перетаскивании
        onValueChanged: {
            if (pressed)
                Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]);
        }

        onPressedChanged: {
            if (pressed)
                return;
            root.moved(value);
            value = Qt.binding(() => root.value);
        }

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: Tokens.scaled(4)
            radius: height / 2
            color: root.colors.surface_container_highest

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.colors.primary
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: Tokens.scaled(slider.pressed ? 20 : slider.hovered ? 18 : 16)
            implicitHeight: implicitWidth
            radius: width / 2
            color: root.colors.primary
            Behavior on implicitWidth { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.scaled(48)
        horizontalAlignment: Text.AlignRight
        text: root.formatValue(slider.value)
        color: root.colors.on_surface_variant
        font: Tokens.fontMedium
    }
}
