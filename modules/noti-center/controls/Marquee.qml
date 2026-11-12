import QtQuick
import "../../../shell/theme"

// Текст, который при переполнении плавно ездит влево-вправо.
Item {
    id: mq

    required property real s
    property string text
    property color color
    property int pixelSize: Math.round(13 * s)
    property string family: Tokens.typography.family
    property int weight: Font.Normal
    readonly property real overflow: Math.max(0, label.implicitWidth - width)

    clip: true
    implicitHeight: label.implicitHeight

    onOverflowChanged: restartTimer.restart()
    onTextChanged: restartTimer.restart()

    Text {
        id: label
        text: mq.text
        color: mq.color
        font.family: mq.family
        font.pixelSize: mq.pixelSize
        font.weight: mq.weight
    }

    // Перезапуск после того, как ширина перестала меняться.
    Timer {
        id: restartTimer
        interval: 300
        onTriggered: {
            slide.stop();
            label.x = 0;
            if (mq.overflow > 0 && mq.visible)
                slide.start();
        }
    }

    onVisibleChanged: restartTimer.restart()

    SequentialAnimation {
        id: slide
        loops: Animation.Infinite
        PauseAnimation { duration: 1200 }
        NumberAnimation {
            target: label; property: "x"; to: -mq.overflow
            duration: Math.max(600, mq.overflow * 30 / mq.s); easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 1200 }
        NumberAnimation {
            target: label; property: "x"; to: 0
            duration: Math.max(600, mq.overflow * 30 / mq.s); easing.type: Easing.InOutSine
        }
    }
}
