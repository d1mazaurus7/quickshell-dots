import QtQuick
import QtQuick.Controls
import Quickshell
import "../../shell/theme"

// Слайдер времени в карточке текущей погоды в стиле M3 Expressive: толстая дорожка с разрывом
// вокруг ручки-столбика, точка конца; ручка сужается при нажатии. Цвета — под фон карточки.
// Шаг — минута; offset — сдвиг от «сейчас» в минутах (привязка), moved() — пользователь сдвинул ползунок.
// Колесо обрабатывает владелец. Щелчок звучит при переходе через час.
Slider {
    id: slider

    required property Item owner
    property int offset: 0
    property int nowMinutes: 0
    // Сглаженный сдвиг владельца: ручка идёт за ним, пока её не тянут
    property real smoothValue: offset
    readonly property var p: owner
    readonly property color accent: p.dynamic ? p.heroText : p.colors.primary
    property int lastHour: -1
    readonly property int gap: p.px(4)
    readonly property int trackHeight: p.px(12)
    readonly property int innerRadius: p.px(2)

    from: 0
    stepSize: 1
    snapMode: Slider.SnapAlways
    value: offset
    implicitHeight: p.px(32) + topPadding + bottomPadding

    onValueChanged: {
        const hour = Math.floor((nowMinutes + value) / 60);
        if (pressed && lastHour >= 0 && hour !== lastHour)
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]);
        lastHour = hour;
    }
    onPressedChanged: if (!pressed) value = Qt.binding(() => slider.offset)

    background: Item {
        id: track
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: slider.trackHeight

        // Дорожки следуют за (анимированной) ручкой
        readonly property real handleX: slider.handle.x - slider.leftPadding
        readonly property real end: height / 2

        Rectangle {
            width: Math.max(0, track.handleX - slider.gap)
            height: parent.height
            visible: width > 0
            topLeftRadius: track.end
            bottomLeftRadius: track.end
            topRightRadius: slider.innerRadius
            bottomRightRadius: slider.innerRadius
            color: slider.accent
            Behavior on color { ColorAnimation { duration: Tokens.animationSlow } }
        }

        Rectangle {
            id: rest
            x: track.handleX + slider.handle.width + slider.gap
            width: Math.max(0, parent.width - x)
            height: parent.height
            visible: width > 0
            topLeftRadius: slider.innerRadius
            bottomLeftRadius: slider.innerRadius
            topRightRadius: track.end
            bottomRightRadius: track.end
            color: slider.p.alpha(slider.accent, 0.25)
            Behavior on color { ColorAnimation { duration: Tokens.animationSlow } }
        }

        // Точка конца дорожки; прячется, когда ручка подходит к ней
        Rectangle {
            width: slider.p.px(4)
            height: width
            radius: width / 2
            x: parent.width - track.end - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: slider.accent
            scale: rest.width > track.height * 1.5 ? 1 : 0
            Behavior on scale { WeatherSpring {} }
        }
    }

    handle: Rectangle {
        readonly property real position: slider.pressed ? slider.visualPosition
                                         : Math.max(0, Math.min(1, (slider.smoothValue - slider.from) / Math.max(1, slider.to - slider.from)))
        x: slider.leftPadding + position * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: slider.p.px(slider.pressed ? 2 : 4)
        implicitHeight: slider.p.px(slider.pressed || slider.hovered ? 32 : 28)
        radius: width / 2
        color: slider.accent
        Behavior on implicitWidth { WeatherSpring {} }
        Behavior on implicitHeight { WeatherSpring {} }
        Behavior on color { ColorAnimation { duration: Tokens.animationSlow } }
    }
}
