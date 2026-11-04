pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/theme"

// Спектр cava у нижнего края виджета: "wave" — сплошная сглаженная волна, "bars" — полосы.
// Уровни сглаживаются: быстрый подъём под бит, мягкий спад
Item {
    id: root

    property var values: []
    property bool active: false
    property string style: "wave"
    property color color: Tokens.colors.primary
    // Непрозрачность полос и градиента волны (сверху / у нижней кромки)
    property real barOpacity: 0.22
    property real waveTopOpacity: 0.32
    property real waveBottomOpacity: 0.04

    // Количество полос (уровни cava растягиваются интерполяцией)
    property int barCount: 24
    // Невидимые копии фигур с Region для размытия под ними (shapeRegions)
    property bool shapeEnabled: false
    // Волна для размытия приближается узкими столбцами (Region — только прямоугольники):
    // шаг ~4 px, высоты — по той же кривой, что рисует Canvas (waveHeights, раз в кадр)
    readonly property int waveColumns: Math.max(1, Math.min(1024, Math.ceil(width / 4)))
    property var waveHeights: []
    property var shapeRegions: []
    // Отражение рисунка по осям. Фигуры размытия отражаются расчётом координат, а не
    // трансформацией: Region строится по mapToScene и с отрицательным размером пустеет
    property bool flipH: false
    property bool flipV: false

    // Общая трансформация отражения для полос и волны
    Scale {
        id: flip
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: root.flipH ? -1 : 1
        yScale: root.flipV ? -1 : 1
    }

    property var levels: []

    // Уровень в точке t (0..1) по полосам cava — линейная интерполяция
    function levelAt(t: real): real {
        const lv = levels;
        const n = lv.length;
        if (n === 0)
            return 0;
        const p = Math.max(0, Math.min(n - 1, t * n - 0.5));
        const i = Math.floor(p);
        const a = lv[i] ?? 0;
        const b = lv[Math.min(n - 1, i + 1)] ?? 0;
        return a + (b - a) * (p - i);
    }
    // Высоты столбцов под волной: кривая как у Canvas (квадратичные Безье через середины
    // соседних точек), для центра каждого столбца решается x(t) = x и берётся y(t)
    function updateWaveHeights(): void {
        if (!shapeEnabled || style !== "wave")
            return;
        const lv = levels;
        const n = lv.length;
        const w = width;
        const h = height;
        const cols = waveColumns;
        const out = new Array(cols).fill(0);
        if (n >= 2 && w > 0) {
            const pts = [[0, h]];
            for (let i = 0; i < n; i++)
                pts.push([(i + 0.5) / n * w, h - lv[i] * h * 0.9]);
            pts.push([w, h]);
            // Сегменты [S, C, E]; после последнего — прямая до (w, h)
            const segs = [];
            let start = [0, h];
            for (let i = 1; i < pts.length - 1; i++) {
                const end = [(pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2];
                segs.push([start, pts[i], end]);
                start = end;
            }
            let k = 0;
            const step = w / cols;
            for (let c = 0; c < cols; c++) {
                const x = (c + 0.5) * step;
                while (k < segs.length && x > segs[k][2][0])
                    k++;
                let y = h;
                if (k < segs.length) {
                    const [S, C, E] = segs[k];
                    const a = S[0] - 2 * C[0] + E[0];
                    const b = 2 * (C[0] - S[0]);
                    const cc = S[0] - x;
                    let t = Math.abs(a) < 1e-6 ? -cc / b : (-b + Math.sqrt(Math.max(0, b * b - 4 * a * cc))) / (2 * a);
                    t = Math.max(0, Math.min(1, t));
                    y = (1 - t) * (1 - t) * S[1] + 2 * (1 - t) * t * C[1] + t * t * E[1];
                }
                out[c] = Math.max(0, h - y);
            }
        }
        waveHeights = out;
    }
    onWidthChanged: updateWaveHeights()
    onHeightChanged: updateWaveHeights()
    onShapeEnabledChanged: updateWaveHeights()
    onStyleChanged: updateWaveHeights()
    function barHeight(index: int, barWidth: real): real {
        return Math.max(barWidth, levelAt((index + 0.5) / bars.count) * bars.height);
    }
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
            if (root.style === "wave") {
                canvas.requestPaint();
                root.updateWaveHeights();
            }
        }
    }

    Row {
        id: bars
        transform: flip
        readonly property int count: Math.max(1, root.barCount)
        readonly property real barWidth: Math.max(1, (width - spacing * (count - 1)) / count)
        anchors.fill: parent
        visible: root.style === "bars"
        spacing: Tokens.scaled(3)

        Repeater {
            model: bars.count

            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: bars.barWidth
                height: root.barHeight(index, width)
                radius: width / 2
                color: Qt.alpha(root.color, root.barOpacity)
            }
        }
    }

    Canvas {
        id: canvas
        transform: flip
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
            grad.addColorStop(0, Qt.alpha(root.color, root.waveTopOpacity).toString());
            grad.addColorStop(1, Qt.alpha(root.color, root.waveBottomOpacity).toString());
            ctx.fillStyle = grad;
            ctx.fill();
        }
    }
    // Фигуры для размытия под спектром: копии полос или столбцы под волной
    Repeater {
        id: shapes
        model: root.shapeEnabled && root.visible ? (root.style === "bars" ? bars.count : root.waveColumns) : 0
        onItemAdded: Qt.callLater(root.collectRegions)
        onItemRemoved: Qt.callLater(root.collectRegions)

        Item {
            id: shapeItem
            required property int index
            readonly property bool isBar: root.style === "bars"
            readonly property real columnWidth: root.width / root.waveColumns
            readonly property Region region: Region {
                item: shapeItem
                radius: shapeItem.isBar ? Math.floor(shapeItem.width / 2) : 0
            }

            readonly property real baseX: isBar ? index * (bars.barWidth + bars.spacing) : index * columnWidth
            x: root.flipH ? root.width - baseX - width : baseX
            width: isBar ? bars.barWidth : Math.ceil(columnWidth)
            height: isBar ? root.barHeight(index, bars.barWidth) : (root.waveHeights[index] ?? 0)
            y: root.flipV ? 0 : root.height - height
        }
    }

    function collectRegions(): void {
        const list = [];
        for (let i = 0; i < shapes.count; i++) {
            const item = shapes.itemAt(i);
            if (item)
                list.push(item.region);
        }
        shapeRegions = list;
    }
}
