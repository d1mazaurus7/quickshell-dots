import QtQuick
import "../../theme" as Theme
import "../../shell/theme"

// Молния, перескакивающая между ручками ползунков эквалайзера
Canvas {
    id: root

    property var sliders: null
    property real step: 60
    property real head: -1
    property real fade: 0

    readonly property int count: sliders ? sliders.count : 0

    function strike() {
        run.stop();
        run.start();
    }

    function knob(i: int): point {
        const s = sliders.itemAt(i);
        return s ? s.mapToItem(root, s.width / 2, s.yOf(s.shown)) : Qt.point(0, 0);
    }

    // Ломаная между двумя точками со случайными изломами
    function bolt(ctx, a, b, seed: real) {
        const dx = b.x - a.x, dy = b.y - a.y;
        const len = Math.hypot(dx, dy);
        if (len < 1) return;
        const nx = -dy / len, ny = dx / len;
        const parts = Math.max(3, Math.round(len / 7));
        const amp = Math.min(Tokens.scaled(9), len / 4);
        let r = seed * 9973 + 1;
        const rand = () => (r = (r * 16807) % 2147483647) / 2147483647;
        ctx.moveTo(a.x, a.y);
        for (let k = 1; k < parts; k++) {
            const t = k / parts, o = (rand() * 2 - 1) * amp;
            ctx.lineTo(a.x + dx * t + nx * o, a.y + dy * t + ny * o);
        }
        ctx.lineTo(b.x, b.y);
    }

    renderStrategy: Canvas.Threaded
    visible: head >= 0

    onHeadChanged: requestPaint()
    onFadeChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (head < 0 || fade <= 0 || count < 2) return;

        const pts = [];
        for (let i = 0; i < count; i++) pts.push(knob(i));
        const last = Math.floor(head);
        const frac = head - last;
        const tip = last + 1 < count
            ? Qt.point(pts[last].x + (pts[last + 1].x - pts[last].x) * frac, pts[last].y + (pts[last + 1].y - pts[last].y) * frac)
            : pts[last];

        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        // Весь пройденный путь остаётся до конца: широкое свечение, акцентный край, белое ядро
        // Свечение — широкие полупрозрачные обводки вместо дорогого shadowBlur
        const layers = [
            { color: Theme.Palette.primary, width: Tokens.scaled(18), alpha: 0.15 },
            { color: Theme.Palette.primary, width: Tokens.scaled(11), alpha: 0.3 },
            { color: Theme.Palette.primary_fixed, width: Tokens.scaled(5), alpha: 1 },
            { color: "white", width: Tokens.scaled(2), alpha: 1 }
        ];
        const path = [];
        for (let i = 0; i <= last; i++)
            path.push([pts[i], i === last ? tip : pts[i + 1]]);
        const seeds = path.map(() => Math.random());
        for (const l of layers) {
            ctx.strokeStyle = l.color;
            ctx.lineWidth = l.width;
            ctx.globalAlpha = fade * l.alpha;
            ctx.beginPath();
            path.forEach((seg, k) => bolt(ctx, seg[0], seg[1], seeds[k]));
            ctx.stroke();
        }

        // Яркая головка разряда
        const dot = (color, r, a) => {
            ctx.globalAlpha = fade * a;
            ctx.fillStyle = color;
            ctx.beginPath();
            ctx.arc(tip.x, tip.y, r, 0, Math.PI * 2);
            ctx.fill();
        };
        dot(Theme.Palette.primary, Tokens.scaled(14), 0.2);
        dot(Theme.Palette.primary_fixed, Tokens.scaled(8), 0.5);
        dot("white", Tokens.scaled(4.5), 1);
    }

    SequentialAnimation {
        id: run
        ScriptAction { script: { root.fade = 1; root.head = 0; } }
        NumberAnimation {
            target: root; property: "head"
            from: 0; to: Math.max(0, root.count - 1)
            duration: root.step * Math.max(0, root.count - 1)
        }
        NumberAnimation { target: root; property: "fade"; to: 0; duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
        ScriptAction { script: root.head = -1 }
    }
}
