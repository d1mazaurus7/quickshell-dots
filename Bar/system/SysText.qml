import QtQuick
import "../../shell/theme"

// Текст, у которого числа плавно перетекают к новым значениям,
// а не влезающая строка медленно прокручивается по X туда-обратно
Item {
    id: root

    property string text
    property font font: Tokens.fontMedium
    property color color: Tokens.colors.on_surface
    property int horizontalAlignment: Text.AlignLeft
    property bool animateNumbers: true

    readonly property bool overflow: label.implicitWidth > width + 0.5
    readonly property real alignedX: horizontalAlignment === Text.AlignRight ? width - label.implicitWidth
        : horizontalAlignment === Text.AlignHCenter ? (width - label.implicitWidth) / 2 : 0

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight
    clip: overflow

    // Числа: шаблон строки и значения «от»/«до»
    readonly property var numRe: /\d+(?:\.\d+)?/g
    property var skeleton: []
    property var fromN: []
    property var toN: []
    property var decimals: []
    property real t: 1
    property string shown: text

    function build(k: real): string {
        let s = skeleton[0];
        for (let i = 0; i < toN.length; i++)
            s += (fromN[i] + (toN[i] - fromN[i]) * k).toFixed(decimals[i]) + skeleton[i + 1];
        return s;
    }

    onTextChanged: {
        const nums = text.match(numRe) ?? [];
        const skel = text.split(numRe);
        const same = animateNumbers && visible && skel.length === skeleton.length && skel.every((p, i) => p === skeleton[i]);
        if (same) {
            const cur = toN.map((v, i) => fromN[i] + (v - fromN[i]) * t);
            fromN = cur;
        }
        skeleton = skel;
        toN = nums.map(Number);
        decimals = nums.map(n => (n.split(".")[1] ?? "").length);
        if (!same) {
            fromN = toN;
            shown = text;
            return;
        }
        roll.restart();
    }
    onTChanged: if (skeleton.length) shown = build(t)

    NumberAnimation {
        id: roll
        target: root
        property: "t"
        from: 0
        to: 1
        duration: Tokens.animationSlow * 1.6
        easing.type: Easing.OutCubic
        onFinished: root.shown = root.text
    }

    Text {
        id: label
        x: Math.round(root.overflow ? -root.scroll : root.alignedX)
        y: Math.round((root.height - height) / 2)
        text: root.shown
        font: root.font
        color: root.color
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
    }

    // Бегущая строка: пауза — к концу — пауза — обратно; k — доля пути, расстояние берётся на лету
    readonly property real scroll: k * Math.max(0, label.implicitWidth - width)
    property real k: 0
    SequentialAnimation on k {
        running: root.overflow && root.visible
        loops: Animation.Infinite
        onRunningChanged: if (!running) root.k = 0
        PauseAnimation { duration: 1800 }
        NumberAnimation { from: 0; to: 1; duration: 2600; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 1800 }
        NumberAnimation { from: 1; to: 0; duration: 2600; easing.type: Easing.InOutSine }
    }
}
