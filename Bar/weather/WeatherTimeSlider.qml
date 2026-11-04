import QtQuick
import QtQuick.Controls
import Quickshell
import "../../shell/theme"

// Слайдер времени в карточке текущей погоды, по виду как SettingSlider; цвета — под фон карточки.
// Шаг — минута; offset — сдвиг от «сейчас» в минутах (привязка), moved() — пользователь сдвинул ползунок.
// Колесо — по 15 минут. Щелчок звучит при переходе через час.
Slider {
    id: slider

    required property Item owner
    property int offset: 0
    property int nowMinutes: 0
    readonly property var p: owner
    readonly property color accent: p.dynamic ? p.heroText : p.colors.primary
    property int lastHour: -1

    from: 0
    stepSize: 1
    snapMode: Slider.SnapAlways
    value: offset
    implicitHeight: p.px(20) + topPadding + bottomPadding

    onValueChanged: {
        const hour = Math.floor((nowMinutes + value) / 60);
        if (pressed && lastHour >= 0 && hour !== lastHour)
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]);
        lastHour = hour;
    }
    onPressedChanged: if (!pressed) value = Qt.binding(() => slider.offset)

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = event.angleDelta.y || event.angleDelta.x;
            if (d === 0)
                return;
            slider.value = Math.max(slider.from, Math.min(slider.to, slider.offset + (d > 0 ? -15 : 15)));
            slider.moved();
            slider.value = Qt.binding(() => slider.offset);
        }
    }

    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: slider.p.px(4)
        radius: height / 2
        color: slider.p.alpha(slider.accent, 0.25)

        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: slider.accent
        }
    }

    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        implicitWidth: slider.p.px(slider.pressed ? 20 : slider.hovered ? 18 : 16)
        implicitHeight: implicitWidth
        radius: width / 2
        color: slider.accent
        Behavior on implicitWidth { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on x { enabled: !slider.pressed; NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
    }
}
