import QtQuick
import "../../theme" as Theme
import "../../shell/theme"

// Вертикальный ползунок полосы эквалайзера: заливка идёт от 0 дБ к текущему значению
Item {
    id: root

    property real value: 0
    property real from: -12
    property real to: 12
    property real step: 0.5
    property string label: ""

    signal moved(real value)

    // Отображаемое значение: при смене пресета плавно доезжает, при перетаскивании — без задержки
    property real shown: value
    Behavior on shown {
        enabled: !area.pressed
        NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
    }

    readonly property real knobSize: Tokens.scaled(18)
    readonly property real trackTop: valueText.height + Tokens.spacingSmallV + knobSize / 2
    readonly property real trackHeight: height - trackTop - labelText.height - Tokens.spacingSmallV - knobSize / 2
    function yOf(v: real): real {
        return trackTop + (to - v) / (to - from) * trackHeight;
    }

    implicitWidth: Tokens.scaled(40)
    implicitHeight: Tokens.scaled(220)

    Text {
        id: valueText
        anchors.horizontalCenter: parent.horizontalCenter
        text: (root.value > 0 ? "+" : "") + root.value.toFixed(1)
        color: area.pressed ? Theme.Palette.primary : Theme.Palette.on_surface_variant
        font.family: Tokens.typography.family
        font.pixelSize: Tokens.scaled(11)
        font.features: { "tnum": 1 }
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    // Дорожка
    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.trackTop
        width: Tokens.scaled(6)
        height: root.trackHeight
        radius: width / 2
        color: Theme.Palette.on_surface
        opacity: 0.18
    }

    // Заливка от нулевой отметки
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(root.yOf(0), root.yOf(root.shown))
        width: track.width
        height: Math.abs(root.yOf(0) - root.yOf(root.shown))
        radius: width / 2
        color: Theme.Palette.primary
    }

    // Ручка
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.yOf(root.shown) - height / 2
        width: root.knobSize
        height: root.knobSize
        radius: height / 2
        color: area.containsMouse || area.pressed ? Theme.Palette.primary_fixed : Theme.Palette.primary
        scale: area.pressed ? 1.25 : area.containsMouse ? 1.1 : 1
        border.width: Tokens.scaled(3)
        border.color: Theme.Palette.on_primary

        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    Text {
        id: labelText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.label
        color: Theme.Palette.on_surface_variant
        font.family: Tokens.typography.family
        font.pixelSize: Tokens.scaled(11)
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function update(my: real) {
            const t = Math.max(0, Math.min(1, (my - root.trackTop) / root.trackHeight));
            const v = Math.round((root.to - t * (root.to - root.from)) / root.step) * root.step;
            if (v !== root.value) root.moved(v);
        }
        onPressed: mouse => update(mouse.y)
        onPositionChanged: mouse => { if (pressed) update(mouse.y); }
        // Двойной клик — сброс полосы в 0
        onDoubleClicked: root.moved(0)
    }
}
