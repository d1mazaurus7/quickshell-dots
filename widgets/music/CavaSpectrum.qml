pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Спектр cava у нижнего края виджета: "wave" — сплошная сглаженная волна, "bars" — полосы.
// Уровни сглаживаются: быстрый подъём под бит, мягкий спад
Item {
    id: root

    property var values: []
    property bool active: false
    property string style: "wave"
    property color color: Tokens.colors.primary

    property var levels: []
    property real energy: 0

    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

    FrameAnimation {
        running: root.visible && (root.active || root.energy > 0.001)
        onTriggered: {
            const target = root.values;
            const n = Math.max(target.length, root.levels.length);
            const prev = root.levels;
            const next = [];
            let sum = 0;
            for (let i = 0; i < n; i++) {
                const cur = prev[i] ?? 0;
                const t = target[i] ?? 0;
                const k = t > cur ? 0.55 : 0.12;
                next.push(cur + (t - cur) * Math.min(1, k * frameTime * 60));
                sum += next[i];
            }
            root.levels = next;
            root.energy = n > 0 ? sum / n : 0;
            if (root.style === "wave")
                canvas.requestPaint();
        }
    }

    Row {
        id: bars
        readonly property int count: 24
        anchors.fill: parent
        visible: root.style === "bars"
        spacing: Tokens.scaled(3)

        Repeater {
            model: bars.count

            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: (bars.width - bars.spacing * (bars.count - 1)) / bars.count
                height: Math.max(width, (root.levels[index] ?? 0) * bars.height)
                radius: width / 2
                color: Qt.alpha(root.color, 0.22)
            }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: root.style === "wave"
        onVisibleChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const lv = root.levels;
            if (lv.length < 2)
                return;

            // Края сходят к нулю — волна плавно выходит из нижней кромки
            const pts = [[0, height]];
            const n = lv.length;
            for (let i = 0; i < n; i++) {
                const x = (i + 0.5) / n * width;
                pts.push([x, height - lv[i] * height * 0.9]);
            }
            pts.push([width, height]);

            const mid = (p, q) => [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];
            ctx.beginPath();
            ctx.moveTo(0, height);
            for (let i = 1; i < pts.length - 1; i++) {
                const m = mid(pts[i], pts[i + 1]);
                ctx.quadraticCurveTo(pts[i][0], pts[i][1], m[0], m[1]);
            }
            ctx.lineTo(width, height);
            ctx.closePath();

            const grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, Qt.alpha(root.color, 0.32).toString());
            grad.addColorStop(1, Qt.alpha(root.color, 0.04).toString());
            ctx.fillStyle = grad;
            ctx.fill();
        }
    }
}
