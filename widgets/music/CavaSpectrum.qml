pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
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
    // шаг ~4 px, высоты — по той же кривой, что рисует волна, с точностью до пикселя
    readonly property int waveColumns: Math.max(1, Math.min(1024, Math.ceil(width / 4)))
    readonly property real regionStep: 1
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
    // Высоты столбцов под волной: кривая как у волны (квадратичные Безье через середины
    // соседних точек), для центра каждого столбца решается x(t) = x и берётся y(t).
    // Вызывается каждый кадр, поэтому без выделения памяти и обращений к QML в цикле:
    // столбцы и их прошлые высоты хранятся в JS-массивах, Region меняются только при изменении
    property var waveRegionList: []
    property var regionHeights: []
    property string regionKey: ""
    function updateWaveHeights(): void {
        if (!shapeEnabled || style !== "wave")
            return;
        const regs = waveRegionList;
        const cols = regs.length;
        if (cols === 0)
            return;
        const lv = levels;
        const n = lv.length;
        const w = width;
        const h = height;
        const origin = mapToItem(null, 0, 0);
        const colW = w / cols;
        const cw = Math.ceil(colW);
        // Положение и ширина столбцов меняются только вместе с геометрией
        const key = origin.x + ":" + origin.y + ":" + w + ":" + h + ":" + cols + ":" + flipH + ":" + flipV;
        const geo = key !== regionKey;
        if (geo) {
            regionKey = key;
            regionHeights = new Array(cols).fill(-1);
        }
        const last = regionHeights;
        const step = regionStep;
        const amp = h * 0.9;
        // Текущий сегмент: начало S, контрольная точка C, конец E
        let k = 0;
        let sx = 0, sy = h, cx = 0, cy = h, ex = 0, ey = h;
        const valid = n >= 2 && w > 0;
        if (valid) {
            cx = 0.5 / n * w;
            cy = h - lv[0] * amp;
            ex = (cx + 1.5 / n * w) / 2;
            ey = (cy + h - lv[1] * amp) / 2;
        }
        for (let c = 0; c < cols; c++) {
            let y = h;
            if (valid) {
                const x = (c + 0.5) * colW;
                while (k < n && x > ex) {
                    k++;
                    sx = ex;
                    sy = ey;
                    if (k < n) {
                        cx = (k + 0.5) / n * w;
                        cy = h - lv[k] * amp;
                        const nx = k + 1 < n ? (k + 1.5) / n * w : w;
                        const ny = k + 1 < n ? h - lv[k + 1] * amp : h;
                        ex = (cx + nx) / 2;
                        ey = (cy + ny) / 2;
                    }
                }
                if (k < n) {
                    const a = sx - 2 * cx + ex;
                    const b = 2 * (cx - sx);
                    const cc = sx - x;
                    let t = Math.abs(a) < 1e-6 ? -cc / b : (-b + Math.sqrt(Math.max(0, b * b - 4 * a * cc))) / (2 * a);
                    t = Math.max(0, Math.min(1, t));
                    const u = 1 - t;
                    y = u * u * sy + 2 * u * t * cy + t * t * ey;
                }
            }
            const v = Math.round(Math.max(0, h - y) / step) * step;
            if (!geo && last[c] === v)
                continue;
            last[c] = v;
            const r = regs[c];
            if (geo) {
                const base = c * colW;
                r.x = Math.floor(origin.x + (flipH ? w - base - cw : base));
                r.width = cw;
            }
            r.y = Math.floor(origin.y + (flipV ? 0 : h - v));
            r.height = v;
        }
    }
    onFlipHChanged: updateWaveHeights()
    onFlipVChanged: updateWaveHeights()
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
            let moved = n !== prev.length;
            for (let i = 0; i < n; i++) {
                const cur = prev[i] ?? 0;
                const t = target[i] ?? 0;
                const k = t > cur ? 0.55 : 0.12;
                next.push(cur + (t - cur) * Math.min(1, k * frameTime * 60));
                sum += next[i];
                if (Math.abs(next[i] - cur) > 1e-4)
                    moved = true;
            }
            // Уровни замерли (тишина или ровный сигнал) — кадр не перерисовывается
            if (!moved) {
                root.energy = 0;
                return;
            }
            root.levels = next;
            root.energy = n > 0 ? sum / n : 0;
            if (root.style === "wave") {
                root.updateWavePath();
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

    // Волна: края сходят к нулю — плавно выходит из нижней кромки. Рисуется на GPU
    // (Shape), без растеризации всей площади на процессоре каждый кадр
    property string wavePath: ""
    function updateWavePath(): void {
        const lv = levels;
        const n = lv.length;
        const w = width;
        const h = height;
        if (n < 2 || w <= 0) {
            wavePath = "";
            return;
        }
        const f = v => v.toFixed(2);
        let px = 0.5 / n * w;
        let py = h - lv[0] * h * 0.9;
        let d = "M 0 " + f(h);
        for (let i = 1; i <= n; i++) {
            const nx = i < n ? (i + 0.5) / n * w : w;
            const ny = i < n ? h - lv[i] * h * 0.9 : h;
            d += " Q " + f(px) + " " + f(py) + " " + f((px + nx) / 2) + " " + f((py + ny) / 2);
            px = nx;
            py = ny;
        }
        wavePath = d + " L " + f(w) + " " + f(h) + " Z";
    }

    Shape {
        id: wave
        transform: flip
        anchors.fill: parent
        visible: root.style === "wave"
        preferredRendererType: Shape.CurveRenderer
        onVisibleChanged: if (visible) root.updateWavePath()
        onWidthChanged: root.updateWavePath()
        onHeightChanged: root.updateWavePath()

        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                x1: 0; y1: 0
                x2: 0; y2: wave.height
                GradientStop { position: 0; color: Qt.alpha(root.color, root.waveTopOpacity) }
                GradientStop { position: 1; color: Qt.alpha(root.color, root.waveBottomOpacity) }
            }
            PathSvg { path: root.wavePath }
        }
    }
    // Фигуры для размытия под полосами: копии полос
    Repeater {
        id: shapes
        model: root.shapeEnabled && root.visible && root.style === "bars" ? bars.count : 0
        onItemAdded: Qt.callLater(root.collectRegions)
        onItemRemoved: Qt.callLater(root.collectRegions)

        Item {
            id: shapeItem
            required property int index
            readonly property Region region: Region {
                item: shapeItem
                radius: Math.floor(shapeItem.width / 2)
            }

            readonly property real baseX: index * (bars.barWidth + bars.spacing)
            x: root.flipH ? root.width - baseX - width : baseX
            width: bars.barWidth
            height: root.barHeight(index, bars.barWidth)
            y: root.flipV ? 0 : root.height - height
        }
    }

    // Столбцы размытия под волной (координаты задаёт updateWaveHeights)
    Instantiator {
        id: waveRegions
        model: root.shapeEnabled && root.visible && root.style === "wave" ? root.waveColumns : 0
        onObjectAdded: Qt.callLater(root.collectRegions)
        onObjectRemoved: Qt.callLater(root.collectRegions)

        Region {}
    }

    // Группы столбцов: Quickshell объединяет дочерние Region по одному, и каждое объединение
    // проходит всю уже собранную область. Столбцы сначала сливаются в небольшие группы,
    // затем группы — между собой: форма та же, объединений по большой области в 16 раз меньше
    readonly property int groupSize: 16
    Instantiator {
        id: waveGroups
        model: waveRegions.count > 0 ? Math.ceil(waveRegions.count / root.groupSize) : 0
        onObjectAdded: Qt.callLater(root.collectRegions)
        onObjectRemoved: Qt.callLater(root.collectRegions)

        Region {}
    }

    function collectRegions(): void {
        const list = [];
        for (let i = 0; i < shapes.count; i++) {
            const item = shapes.itemAt(i);
            if (item)
                list.push(item.region);
        }
        const regs = [];
        for (let i = 0; i < waveRegions.count; i++) {
            const r = waveRegions.objectAt(i);
            if (r)
                regs.push(r);
        }
        waveRegionList = regs;
        regionKey = "";
        for (let g = 0; g < waveGroups.count; g++) {
            const group = waveGroups.objectAt(g);
            if (!group)
                continue;
            const cols = [];
            const end = Math.min(waveRegions.count, (g + 1) * groupSize);
            for (let i = g * groupSize; i < end; i++) {
                const r = waveRegions.objectAt(i);
                if (r)
                    cols.push(r);
            }
            group.regions = cols;
            list.push(group);
        }
        shapeRegions = list;
        updateWaveHeights();
    }
}
