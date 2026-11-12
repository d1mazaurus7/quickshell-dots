import QtQuick
import "../../theme" as Theme
import "../../shell/theme"

// Визуализация спектра вокруг обложки: замкнутая сглаженная волна,
// которая повторяет форму скруглённого квадрата обложки.
// Полосы зеркалятся слева и справа, низкие частоты — сверху.
Item {
    id: root

    property var values: []
    property bool active: false
    // Сторона обложки, зазор до неё в тишине и максимальный выброс на пике
    property real coverSize: 120
    property real gap: 4
    property real amplitude: 30
    // Степень «квадратности» контура: 2 — круг, больше — ближе к квадрату
    property real squareness: 5

    // Сглаженные уровни: быстрый подъём под бит, мягкий спад
    property var levels: []
    property real energy: 0

    width: coverSize + (gap + amplitude * 1.5) * 2
    height: width
    opacity: active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

    FrameAnimation {
        running: root.visible && (root.active || root.energy > 0.001)
        onTriggered: {
            const target = root.values;
            const n = target.length;
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
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        property color accent: Theme.Palette.primary
        property color light: Theme.Palette.on_surface

        // Уровень в произвольной точке контура: полосы зеркалятся, между ними — плавная интерполяция
        function levelAt(levels, t) {
            const n = levels.length;
            const pos = (t < 0.5 ? t * 2 : (1 - t) * 2) * n - 0.5;
            const i = Math.max(0, Math.min(n - 1, Math.floor(pos)));
            const j = Math.min(n - 1, i + 1);
            const f = Math.max(0, Math.min(1, pos - i));
            const s = (1 - Math.cos(f * Math.PI)) / 2;
            return levels[i] * (1 - s) + levels[j] * s;
        }

        // Расстояние от центра до контура скруглённого квадрата (суперэллипс) по направлению угла
        function edge(a) {
            const n = root.squareness;
            const c = Math.pow(Math.abs(Math.cos(a)), n) + Math.pow(Math.abs(Math.sin(a)), n);
            return root.coverSize / 2 / Math.pow(c, 1 / n);
        }

        // Замкнутая кривая через середины соседних точек — без углов
        function blob(ctx, levels, offset, amp, shift) {
            const pts = [];
            const count = 160;
            for (let i = 0; i < count; i++) {
                const t = (i + 0.5) / count;
                const a = -Math.PI / 2 + t * Math.PI * 2;
                const v = levelAt(levels, (t + shift) % 1);
                const r = edge(a) + offset + v * amp;
                pts.push([width / 2 + Math.cos(a) * r, height / 2 + Math.sin(a) * r]);
            }
            const mid = (p, q) => [(p[0] + q[0]) / 2, (p[1] + q[1]) / 2];
            const start = mid(pts[count - 1], pts[0]);
            ctx.beginPath();
            ctx.moveTo(start[0], start[1]);
            for (let i = 0; i < count; i++) {
                const m = mid(pts[i], pts[(i + 1) % count]);
                ctx.quadraticCurveTo(pts[i][0], pts[i][1], m[0], m[1]);
            }
            ctx.closePath();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const lv = root.levels;
            if (lv.length < 2) return;

            // Низкие частоты чуть раздувают всю волну — пульсация под бит
            const bass = ((lv[0] ?? 0) + (lv[1] ?? 0) + (lv[2] ?? 0)) / 3;
            const offset = root.gap + bass * root.amplitude * 0.25;

            // Светлая волна позади — шире и мягче, со сдвигом по кругу
            blob(ctx, lv, offset, root.amplitude * 1.2, 0.5 / lv.length);
            ctx.fillStyle = Qt.alpha(light, 0.14).toString();
            ctx.fill();

            // Акцентная волна
            const grad = ctx.createRadialGradient(width / 2, height / 2, root.coverSize / 2,
                                                  width / 2, height / 2, width / 2);
            grad.addColorStop(0, Qt.alpha(accent, 0.55).toString());
            grad.addColorStop(1, Qt.alpha(accent, 0.15).toString());
            blob(ctx, lv, offset, root.amplitude, 0);
            ctx.fillStyle = grad;
            ctx.fill();
        }
    }
}
