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

    // Отображаемое значение: плавно доезжает, при перетаскивании — без задержки
    property real shown: value
    Behavior on shown {
        enabled: !area.pressed && !root.charging
        NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
    }
    onValueChanged: if (!charging) shown = value

    // «Разряд» при смене пресета: вспышка точки и подъём к новому значению после задержки
    property bool charging: false
    property real glow: 0
    function charge(delay: int) {
        surge.stop();
        charging = true;
        chargeTimer.interval = delay;
        chargeTimer.restart();
    }
    function stopCharge() {
        chargeTimer.stop();
        surge.stop();
        glow = 0;
        charging = false;
    }
    Timer {
        id: chargeTimer
        onTriggered: {
            rise.to = root.value;
            surge.start();
        }
    }
    ParallelAnimation {
        id: surge
        NumberAnimation {
            id: rise
            target: root; property: "shown"
            duration: Tokens.animationSlow * 1.5
            easing.type: Easing.OutBack; easing.overshoot: 1.4
        }
        SequentialAnimation {
            NumberAnimation { target: root; property: "glow"; to: 1; duration: Tokens.animationFast / 2; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "glow"; to: 0; duration: Tokens.animationSlow * 1.5; easing.type: Easing.OutCubic }
        }
        onFinished: {
            root.charging = false;
            root.shown = root.value;
        }
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

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.Palette.primary_fixed
            opacity: root.glow
        }
    }

    // Искра вокруг ручки
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.yOf(root.shown) - height / 2
        width: root.knobSize * (1 + root.glow * 1.4)
        height: width
        radius: width / 2
        color: Theme.Palette.primary
        opacity: root.glow * 0.45
        visible: root.glow > 0
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
        onPressed: mouse => {
            root.stopCharge();
            update(mouse.y);
        }
        onPositionChanged: mouse => { if (pressed) update(mouse.y); }
        // Двойной клик — сброс полосы в 0
        onDoubleClicked: root.moved(0)
    }
}
