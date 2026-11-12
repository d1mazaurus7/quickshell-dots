import QtQuick
import QtQuick.Controls
import Quickshell
import "../../shell/theme"

// Слайдер M3: value — текущее значение (привязать к Config),
// moved(value) — по отпусканию, чтобы не писать файл на каждый пиксель
Row {
    id: root

    property real from: 0
    property real to: 1
    property real stepSize: 0.1
    property real value
    // Подпись значения справа
    property var formatValue: v => v.toFixed(1)
    // Ширина полосы слайдера (без подписи)
    property real sliderWidth: Tokens.scaled(200)

    readonly property var colors: Tokens.colors

    signal moved(real value)
    // Каждое изменение при перетаскивании — для живой регулировки
    signal dragged(real value)

    spacing: Tokens.spacingMedium

    Slider {
        id: slider

        readonly property real trackHeight: Tokens.scaled(16)
        readonly property real handleSlot: Tokens.scaled(4)
        readonly property real handleGap: Tokens.scaled(6)
        readonly property real handleMaxHeight: Tokens.scaled(36)
        // Сглаженная позиция: шаги не «прыгают»
        property real pos: visualPosition
        readonly property real handleCenter: handleSlot / 2 + pos * (availableWidth - handleSlot)

        property color activeColor: enabled ? root.colors.primary : Qt.alpha(root.colors.on_surface, 0.38)
        property color inactiveColor: enabled ? root.colors.secondary_container : Qt.alpha(root.colors.on_surface, 0.12)

        Behavior on pos { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on activeColor { ColorAnimation { duration: Tokens.animationFast } }
        Behavior on inactiveColor { ColorAnimation { duration: Tokens.animationFast } }

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.sliderWidth
        // Высота по наибольшей ручке: рост ручки при hover/pressed не меняет высоту
        implicitHeight: handleMaxHeight + topPadding + bottomPadding
        from: root.from
        to: root.to
        stepSize: root.stepSize
        snapMode: Slider.SnapAlways
        value: root.value

        // Щелчок на каждом шаге при перетаскивании
        onValueChanged: {
            if (!pressed)
                return;
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]);
            root.dragged(value);
        }

        onPressedChanged: {
            if (pressed)
                return;
            wheelCommit.stop();
            root.moved(value);
            value = Qt.binding(() => root.value);
        }

        // Колесо мыши над слайдером: шаг = stepSize
        wheelEnabled: true
        onMoved: {
            if (pressed)
                return;
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]);
            root.dragged(value);
            wheelCommit.restart();
        }

        // Запись по окончании прокрутки, а не на каждый щелчок колеса
        Timer {
            id: wheelCommit
            interval: 300
            onTriggered: {
                root.moved(slider.value);
                slider.value = Qt.binding(() => root.value);
            }
        }

        background: Item {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: slider.trackHeight

            // Активная часть
            Rectangle {
                width: Math.max(0, slider.handleCenter - slider.handleSlot / 2 - slider.handleGap)
                height: parent.height
                topLeftRadius: height / 2
                bottomLeftRadius: height / 2
                topRightRadius: Tokens.scaled(2)
                bottomRightRadius: Tokens.scaled(2)
                color: slider.activeColor
            }

            // Неактивная часть
            Rectangle {
                id: inactiveTrack
                x: Math.min(parent.width, slider.handleCenter + slider.handleSlot / 2 + slider.handleGap)
                width: parent.width - x
                height: parent.height
                topLeftRadius: Tokens.scaled(2)
                bottomLeftRadius: Tokens.scaled(2)
                topRightRadius: height / 2
                bottomRightRadius: height / 2
                color: slider.inactiveColor

                // Stop indicator
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.scaled(4)
                    width: Tokens.scaled(4)
                    height: width
                    radius: width / 2
                    color: slider.activeColor
                    opacity: inactiveTrack.width > Tokens.scaled(12) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                }
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.handleCenter - width / 2
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            // M3: ручка сужается при нажатии, чуть вытягивается при hover
            implicitWidth: Tokens.scaled(slider.pressed ? 2 : 4)
            implicitHeight: slider.pressed || slider.hovered ? slider.handleMaxHeight : Tokens.scaled(32)
            radius: width / 2
            color: slider.activeColor
            Behavior on implicitWidth { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.scaled(48)
        horizontalAlignment: Text.AlignRight
        text: root.formatValue(slider.value)
        color: root.colors.on_surface_variant
        opacity: root.enabled ? 1 : 0.38
        font: Tokens.fontMedium
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
    }
}
