pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Particles
import Quickshell
import Quickshell.Wayland
import "../../shell/config"
import "../../shell/theme"

// Снегопад и сугробы одного экрана: внизу экрана и на плавающих окнах.
// Слой Top — поверх окон; клавиатурный фокус не берётся никогда
PanelWindow {
    id: root

    required property var modelData
    required property var niri
    readonly property var cfg: Config.options.snow

    // Лимиты
    readonly property int brushRadius: 40
    readonly property int maxWindowDrifts: 8
    // Свес шапки за края окна
    readonly property int overhang: 4
    readonly property int maxFlakes: Math.min(400, Math.round(250 * cfg.intensity * width * height / (1920 * 1080)))
    readonly property real fallSpeed: 60 * cfg.speed
    readonly property real fallSeconds: Math.max(1, height / fallSpeed)

    // Сугробы по ключу ("ground" или id окна): { x, y — основание, width, cellWidth, heights, caps, full, dirty, visible }
    property var drifts: ({})
    // Ключи сугробов по постоянным слотам: слот 0 — "ground", "" — свободен.
    // Слоты не пересоздаются, поэтому Canvas не мигают при появлении окон
    property var slotKeys: ["ground"]
    property string maskSource: ""
    // Растёт при смене положения сугробов
    property int geometryRevision: 0
    // Расчистка нижнего сугроба: только если на экране нет тайловых окон
    property bool groundInput: true
    property var floatingRects: []
    property bool growing: true
    property var createdMask: null

    // Состояние жеста
    property var sweepDrift: null
    property real lastX: 0
    property real lastH: 0
    property real lastTime: 0
    property real pendingSnow: 0
    property real lastBurst: 0

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs:snow"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Ввод — только полосы сугробов (см. rebuildMask); по умолчанию пустая область
    mask: Region {}

    function capFor(key) {
        return key === "ground" ? cfg.driftHeight : cfg.windowDriftHeight;
    }

    // Профиль сугроба; у шапок на окнах края скруглены (четверть окружности)
    function makeDrift(key, x, y, w, start) {
        const n = Math.min(320, Math.ceil(w / 12) + 1);
        const cap = capFor(key);
        const cell = w / Math.max(1, n - 1);
        const round = key === "ground" ? 0 : cap * 2.5 * cfg.capRounding;
        const d = { key: key, x: x, y: y, width: w, cellWidth: cell, heights: [], caps: [], full: false, dirty: true, visible: true };
        for (let i = 0; i < n; i++) {
            const e = Math.min(i, n - 1 - i) * cell;
            const t = round > 0 && e < round ? 1 - e / round : 0;
            d.caps.push(cap * (0.75 + 0.25 * Math.random()) * Math.sqrt(1 - t * t));
            d.heights.push(d.caps[i] * start);
        }
        return d;
    }

    // Стряхивание: снимает долю снега и выбрасывает её падающими частицами
    function shake(d, fraction, vx) {
        const f = Math.min(1, fraction);
        if (f <= 0)
            return;
        const h = d.heights;
        let removed = 0;
        for (let i = 0; i < h.length; i++) {
            const c = h[i] * f;
            h[i] -= c;
            removed += c;
        }
        d.full = false;
        d.dirty = true;
        growing = true;
        scheduleRepaint();
        const total = Math.min(60, Math.round(removed * d.cellWidth / 150));
        const points = Math.min(12, total);
        if (points === 0)
            return;
        debrisDirection.x = Math.max(-300, Math.min(300, vx));
        debrisDirection.y = -40;
        for (let p = 0; p < points; p++) {
            const i = Math.floor((p + 0.5) / points * h.length);
            debris.burst(Math.ceil(total / points), d.x + i * d.cellWidth, d.y - h[i]);
        }
    }

    // Сугробы по текущей геометрии окон niri
    function syncDrifts(reset) {
        const output = modelData.name;
        const vis = niri.visibleOn(output);
        const floating = vis.filter(v => v.floating);
        const old = reset ? {} : drifts;
        const next = {};
        const g = old.ground;
        next.ground = g && Math.abs(g.width - width) < 1 ? g : makeDrift("ground", 0, height, width, 0.35);
        // Только тайловые окна на экране — по настройке сугроб внизу прячется
        const hasTiled = niri.hasTiledOn(output);
        next.ground.visible = !(cfg.hideGroundWithTiled && hasTiled && floating.length === 0);
        // Под тайловыми окнами нижний сугроб ввод не принимает
        groundInput = !hasTiled;
        if (cfg.windowDrifts) {
            const o = overhang;
            for (const v of floating.slice(0, maxWindowDrifts)) {
                const key = String(v.id);
                const d = old[key];
                if (d && Math.abs(d.width - v.w - 2 * o) < 1) {
                    const dx = v.x - o - d.x;
                    const dy = v.y - d.y;
                    d.x = v.x - o;
                    d.y = v.y;
                    // Перемещение без перетаскивания (клавиатура, IPC): трясём по расстоянию
                    if (d.visible && (dx !== 0 || dy !== 0))
                        shake(d, cfg.shakeOff * Math.hypot(dx, dy) / 300, dx * 0.5);
                    d.visible = true;
                    next[key] = d;
                } else {
                    next[key] = makeDrift(key, v.x - o, v.y, v.w + 2 * o, 0.15);
                }
            }
            // Окна, пропавшие с экрана: снег сохраняется, пока окно живо
            for (const key in old) {
                if (next[key])
                    continue;
                const d = old[key];
                const state = niri.stateOf(Number(key), output);
                if (state === "other")
                    continue;
                if (d.visible && state !== "hidden")
                    shake(d, state === "gone" ? 1 : cfg.shakeOff, 0);
                if (state === "gone")
                    continue;
                d.visible = false;
                next[key] = d;
            }
        }
        drifts = next;
        const slots = [];
        for (let i = 0; i <= maxWindowDrifts; i++)
            slots.push(next[slotKeys[i]] ? slotKeys[i] : "");
        for (const key in next) {
            if (slots.indexOf(key) >= 0)
                continue;
            const free = slots.indexOf("");
            if (free < 0)
                delete next[key];
            else
                slots[free] = key;
        }
        slotKeys = slots;
        floatingRects = floating;
        growing = true;
        geometryRevision++;
        rebuildMask();
        scheduleRepaint();
    }

    // Пересоздать шапки окон (после смены их настроек)
    function resetWindowDrifts() {
        drifts = { ground: drifts.ground };
        syncDrifts(false);
    }

    // Region с дочерними областями: полосы сугробов минус плавающие окна
    function rebuildMask() {
        const parts = [];
        const rect = (x, y, w, h, sub) => `Region { x: ${Math.round(x)}; y: ${Math.round(y)}; width: ${Math.round(w)}; height: ${Math.round(h)}${sub ? "; intersection: Intersection.Subtract" : ""} }`;
        if (cfg.sweep) {
            for (const key in drifts) {
                const d = drifts[key];
                if (!d.visible || (key === "ground" && !groundInput))
                    continue;
                const h = capFor(key) + brushRadius;
                parts.push(rect(d.x, d.y - h, d.width, h, false));
            }
            for (const r of floatingRects)
                parts.push(rect(r.x, r.y, r.w, r.h, true));
        }
        const source = `import Quickshell; Region { ${parts.join(" ")} }`;
        if (source === maskSource)
            return;
        maskSource = source;
        const old = createdMask;
        createdMask = Qt.createQmlObject(source, root);
        mask = createdMask;
        if (old)
            old.destroy();
    }

    function scheduleRepaint() {
        if (!paintTimer.running)
            paintTimer.start();
    }

    // Медленное накопление со сглаживанием соседей
    function accumulate() {
        const k = cfg.intensity * accumTimer.interval / 1000 / 90;
        let any = false;
        for (const key in drifts) {
            const d = drifts[key];
            if (d.full || !d.visible)
                continue;
            const h = d.heights;
            const n = h.length;
            const step = capFor(key) * k;
            let changed = false;
            for (let i = 0; i < n; i++) {
                if (h[i] >= d.caps[i])
                    continue;
                const l = h[Math.max(0, i - 1)];
                const r = h[Math.min(n - 1, i + 1)];
                h[i] = Math.min(d.caps[i], h[i] * 0.8 + (l + r) * 0.1 + step * (0.5 + Math.random()));
                changed = true;
            }
            d.full = !changed;
            d.dirty = d.dirty || changed;
            any = any || changed;
        }
        growing = any;
        if (any)
            scheduleRepaint();
    }

    // Срез сугроба круглой щёткой вдоль отрезка (координаты сугроба); возвращает убранный объём
    function carve(d, x0, h0, x1, h1) {
        const h = d.heights;
        const w = d.cellWidth;
        const r = brushRadius;
        const steps = Math.max(1, Math.ceil(Math.hypot(x1 - x0, h1 - h0) / (w * 0.5)));
        let removed = 0;
        for (let s = 1; s <= steps; s++) {
            const px = x0 + (x1 - x0) * s / steps;
            const ph = h0 + (h1 - h0) * s / steps;
            const i0 = Math.max(0, Math.floor((px - r) / w));
            const i1 = Math.min(h.length - 1, Math.ceil((px + r) / w));
            for (let i = i0; i <= i1; i++) {
                const dx = (i * w - px) / r;
                if (dx * dx >= 1)
                    continue;
                const floor = Math.max(0, ph - r * Math.sqrt(1 - dx * dx));
                if (h[i] <= floor)
                    continue;
                // Мягкий край: у края щётки снимается меньше
                const cut = (h[i] - floor) * (1 - 0.5 * dx * dx);
                h[i] -= cut;
                removed += cut;
            }
        }
        return removed;
    }

    function startSweep(d, x, ph) {
        sweepDrift = d;
        lastX = x;
        lastH = ph;
        lastTime = Date.now();
    }

    function sweepTo(x, ph) {
        const d = sweepDrift;
        const now = Date.now();
        const dt = Math.max(1, now - lastTime);
        const removed = carve(d, lastX, lastH, x, ph);
        if (removed > 0) {
            d.full = false;
            d.dirty = true;
            growing = true;
            scheduleRepaint();
        }
        // Выброс пропорционален реально убранному снегу, с ограничением частоты
        pendingSnow = Math.min(120, pendingSnow + removed);
        const count = Math.min(12, Math.floor(pendingSnow / 6));
        if (count > 0 && now - lastBurst >= 33) {
            const vx = Math.max(-600, Math.min(600, (x - lastX) / dt * 1000));
            const vy = Math.max(-300, Math.min(300, (ph - lastH) / dt * 1000));
            debrisDirection.x = vx * 0.6;
            debrisDirection.y = -Math.min(450, 120 + Math.abs(vx) * 0.3 + Math.max(0, vy) * 0.5);
            debris.burst(count, d.x + x, d.y - Math.min(ph, capFor(d.key)));
            pendingSnow -= count * 6;
            lastBurst = now;
        }
        lastX = x;
        lastH = ph;
        lastTime = now;
    }

    function endSweep() {
        sweepDrift = null;
        pendingSnow = 0;
    }

    onWidthChanged: syncTimer.restart()
    onHeightChanged: syncTimer.restart()
    Component.onCompleted: syncDrifts(true)

    Connections {
        target: root.cfg
        function onDriftHeightChanged() {
            root.syncDrifts(true);
        }
        function onSweepChanged() {
            root.rebuildMask();
        }
        function onHideGroundWithTiledChanged() {
            root.syncDrifts(false);
        }
        function onWindowDriftsChanged() {
            root.syncDrifts(false);
        }
        function onWindowDriftHeightChanged() {
            root.resetWindowDrifts();
        }
        function onCapRoundingChanged() {
            root.resetWindowDrifts();
        }
    }

    Connections {
        target: root.niri
        function onRevisionChanged() {
            if (!syncTimer.running)
                syncTimer.start();
        }
    }

    // Геометрия окон — не чаще 20 раз в секунду
    Timer {
        id: syncTimer
        interval: 50
        onTriggered: root.syncDrifts(false)
    }

    Timer {
        id: accumTimer
        interval: 150
        repeat: true
        running: root.growing
        onTriggered: root.accumulate()
    }

    // Не чаще ~30 перерисовок сугробов в секунду
    Timer {
        id: paintTimer
        interval: 33
        onTriggered: {
            for (let i = 0; i < driftRepeater.count; i++) {
                const slot = driftRepeater.itemAt(i);
                if (slot && slot.drift && slot.drift.dirty) {
                    slot.drift.dirty = false;
                    slot.repaint();
                }
            }
        }
    }

    ParticleSystem {
        id: particles
        anchors.fill: parent
    }

    ImageParticle {
        system: particles
        groups: ["flakes", "debris"]
        source: "flake.svg"
        color: "white"
        alpha: 0.85
        alphaVariation: 0.15
    }

    // Снегопад
    Emitter {
        system: particles
        group: "flakes"
        anchors.top: parent.top
        width: parent.width
        height: 1
        emitRate: root.maxFlakes / root.fallSeconds
        maximumEmitted: root.maxFlakes
        lifeSpan: root.fallSeconds * 1000
        lifeSpanVariation: 400
        size: 6
        sizeVariation: 3
        velocity: PointDirection {
            y: root.fallSpeed
            yVariation: root.fallSpeed * 0.25
            xVariation: 8
        }
    }

    // Покачивание
    Wander {
        system: particles
        groups: ["flakes"]
        anchors.fill: parent
        xVariance: 25
        pace: 30
    }

    // Выбитый снег: только burst()
    Emitter {
        id: debris
        system: particles
        group: "debris"
        anchors.fill: parent
        enabled: false
        maximumEmitted: 150
        lifeSpan: 1100
        lifeSpanVariation: 300
        size: 5
        sizeVariation: 2
        velocity: PointDirection {
            id: debrisDirection
            xVariation: 70
            yVariation: 60
        }
    }

    Gravity {
        system: particles
        groups: ["debris"]
        anchors.fill: parent
        magnitude: 700
        angle: 90
    }

    // Сугробы: силуэт по профилю и полоса расчистки над основанием
    Repeater {
        id: driftRepeater
        model: root.maxWindowDrifts + 1

        Item {
            id: slot

            required property int index
            readonly property string key: root.slotKeys[index] ?? ""
            // Поля сугроба меняются на месте — привязки читают geometryRevision явно
            readonly property var drift: {
                root.geometryRevision;
                return key ? root.drifts[key] ?? null : null;
            }
            readonly property int cap: root.capFor(key)

            function repaint() {
                canvas.requestPaint();
            }

            onKeyChanged: canvas.requestPaint()

            x: {
                root.geometryRevision;
                return drift ? drift.x : 0;
            }
            y: {
                root.geometryRevision;
                return drift ? drift.y - height : 0;
            }
            width: {
                root.geometryRevision;
                return drift ? drift.width : 0;
            }
            height: cap + root.brushRadius
            visible: opacity > 0
            opacity: {
                root.geometryRevision;
                return drift && drift.visible ? 1 : 0;
            }

            Behavior on opacity {
                NumberAnimation { duration: Tokens.animationMedium }
            }

            Canvas {
                id: canvas
                anchors.bottom: parent.bottom
                width: parent.width
                height: slot.cap + 2
                onWidthChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const d = slot.drift;
                    if (!d || d.heights.length < 2)
                        return;
                    const h = d.heights;
                    const w = d.cellWidth;
                    ctx.fillStyle = "white";
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    ctx.lineTo(0, height - h[0]);
                    for (let i = 1; i < h.length; i++)
                        ctx.quadraticCurveTo((i - 1) * w, height - h[i - 1], (i - 0.5) * w, height - (h[i - 1] + h[i]) / 2);
                    ctx.lineTo(width, height - h[h.length - 1]);
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fill();
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.cfg.sweep
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                onPressed: mouse => root.startSweep(slot.drift, mouse.x, slot.height - mouse.y)
                onPositionChanged: mouse => {
                    if (root.sweepDrift === slot.drift)
                        root.sweepTo(mouse.x, slot.height - mouse.y);
                }
                onReleased: root.endSweep()
                onCanceled: root.endSweep()
            }
        }
    }
}
