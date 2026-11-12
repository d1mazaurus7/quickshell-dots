import QtQuick
import "../../../shell/theme"

// Иконка-глиф (см. Icons.js). Центрируется по фактическим границам глифа.
// Смена text анимируется (старый глиф уходит с поворотом, новый приходит с перелётом).
// slashed — анимированное перечёркивание «\» (выключено); slashGap — цвет фона под
// чертой, чтобы черта отделялась от глифа зазором, как в MDI-иконках «-off».
Item {
    id: icon

    property string text
    property color color: "transparent"
    property real size: 20
    property bool slashed: false
    property color slashGap: "transparent"

    property string shown
    property bool ready: false
    readonly property real stroke: Math.max(1.5, size * 0.09)

    implicitWidth: Math.round(size)
    implicitHeight: Math.round(size)
    // Глиф не выходит за свой квадрат при сдвиге
    clip: nudge.running

    // Сдвиг глифа в сторону dir (1 — вправо, -1 — влево) с возвратом с другой стороны
    function slide(dir: int): void {
        nudge.dir = dir;
        nudge.restart();
    }

    onTextChanged: {
        if (!ready)
            shown = text;
        else if (text !== shown)
            swap.restart();
    }
    Component.onCompleted: {
        shown = text;
        ready = true;
    }

    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: label; property: "scale"; to: 0.4; duration: Tokens.animationFast * 0.6; easing.type: Easing.InCubic }
            NumberAnimation { target: label; property: "opacity"; to: 0; duration: Tokens.animationFast * 0.6; easing.type: Easing.InCubic }
            NumberAnimation { target: label; property: "rotation"; to: -45; duration: Tokens.animationFast * 0.6; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { icon.shown = icon.text; label.rotation = 45; } }
        ParallelAnimation {
            NumberAnimation { target: label; property: "scale"; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: label; property: "opacity"; to: 1; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
            NumberAnimation { target: label; property: "rotation"; to: 0; duration: Tokens.animationMedium; easing.type: Easing.OutBack }
        }
    }

    SequentialAnimation {
        id: nudge
        property int dir: 1
        ParallelAnimation {
            NumberAnimation { target: offset; property: "x"; to: nudge.dir * icon.width; duration: Tokens.animationFast * 0.7; easing.type: Easing.InCubic }
            NumberAnimation { target: label; property: "opacity"; to: 0; duration: Tokens.animationFast * 0.7; easing.type: Easing.InCubic }
        }
        PropertyAction { target: offset; property: "x"; value: -nudge.dir * icon.width }
        ParallelAnimation {
            NumberAnimation { target: offset; property: "x"; to: 0; duration: Tokens.animationMedium; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            NumberAnimation { target: label; property: "opacity"; to: 1; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
        }
    }

    TextMetrics {
        id: tm
        font: label.font
        text: icon.shown
    }

    Text {
        id: label
        readonly property rect box: tm.tightBoundingRect
        x: Math.round((icon.width - box.width) / 2 - box.x)
        y: Math.round((icon.height - box.height) / 2 - box.y - baselineOffset)
        transformOrigin: Item.Center
        transform: Translate { id: offset }
        text: icon.shown
        color: icon.color
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: Math.round(icon.size)
    }

    // Перечёркивание: черта прорастает из верхнего левого угла
    Item {
        id: slash
        property real progress: icon.slashed ? 1 : 0
        Behavior on progress { Smooth { duration: Tokens.animationMedium } }

        anchors.centerIn: parent
        width: icon.stroke * 3
        height: icon.size * 1.05
        rotation: -45
        visible: progress > 0

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.height * slash.progress
            radius: width / 2
            color: icon.slashGap
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: icon.stroke
            height: parent.height * slash.progress
            radius: width / 2
            color: icon.color
        }
    }
}
