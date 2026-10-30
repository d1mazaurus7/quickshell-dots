import QtQuick
import "../../shell/theme"

// Текст, который не помещается по ширине, прокручивается по кругу по оси X
Item {
    id: root

    property string text: ""
    property color color
    property font font
    property int gap: Tokens.scaled(48)
    // Скорость прокрутки, px/с
    property real speed: 40
    property int pause: 1800

    readonly property bool overflow: label.implicitWidth > width

    implicitHeight: label.implicitHeight
    clip: true

    Row {
        id: strip
        spacing: root.gap

        Text {
            id: label
            text: root.text
            color: root.color
            font: root.font
            onTextChanged: {
                strip.x = 0;
                if (scroll.running) scroll.restart();
            }
        }
        // Копия для бесшовного повтора
        Text {
            visible: root.overflow
            text: root.text
            color: root.color
            font: root.font
        }
    }

    SequentialAnimation {
        id: scroll
        running: root.overflow && root.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running) strip.x = 0

        PauseAnimation { duration: root.pause }
        NumberAnimation {
            target: strip
            property: "x"
            from: 0
            to: -(label.implicitWidth + root.gap)
            duration: (label.implicitWidth + root.gap) / root.speed * 1000
        }
    }
}
