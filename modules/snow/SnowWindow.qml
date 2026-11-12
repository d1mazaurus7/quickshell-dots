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
    readonly property real fallSpeed: 60 * cfg.speed
    readonly property real fallSeconds: Math.max(1, height / fallSpeed)
    // Ветер, лог. px/с, и снос снежинки за время падения (не больше двух ширин экрана)
    readonly property real windSpeed: cfg.wind ? 80 * cfg.windStrength : 0
    readonly property real windShift: Math.max(-2 * width, Math.min(2 * width, windSpeed * fallSeconds))
    // Полоса снегопада расширена против ветра, чтобы снег покрывал весь экран
    readonly property real emitWidth: width + Math.abs(windShift)
    readonly property int maxFlakes: Math.min(6000, Math.round(250 * cfg.intensity * emitWidth * height / (1920 * 1080)))
    // Ускорение свободного падения выбитого снега, лог. px/с²
    readonly property real debrisGravity: 900
    // Площадь сугроба на один смахнутый ком, лог. px²
    readonly property real debrisArea: 60
    // Быстрый снег отскакивает от сугробов и низа экрана
    readonly property bool bouncing: fallSpeed >= 200
    // Запас над сугробом для отскочивших снежинок, лог. px
    readonly property int bounceMargin: 100
    property bool groundVisible: true
    readonly property real bounceShare: Math.min(1, cfg.bounceAmount)
    readonly property real bounceExtra: Math.max(0, cfg.bounceAmount - 1)
    // Видимые сугробы массивом — для физики частиц без перебора ключей объекта
    property var surfaces: []

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
    // Сглаженная скорость щётки, лог. px/с (sweepVy — вверх)
    property real sweepVx: 0
    property real sweepVy: 0

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

    // Предел роста бесконечного сугроба: до верха экрана
    function limitFor(d) {
        return d.key === "ground" ? height : Math.max(0, d.y);
    }

    // Высота полосы сугроба: потолок обычного сугроба или текущая высота бесконечного (шаг 40 px)
    function extentOf(d) {
        if (!cfg.infiniteDrifts)
            return capFor(d.key);
        return Math.min(limitFor(d), Math.ceil((Math.max(...d.heights) + 1) / 40) * 40);
    }

    function updateExtents() {
        let changed = false;
        for (const key in drifts) {
            const d = drifts[key];
            const e = extentOf(d);
            if (e !== d.extent) {
                d.extent = e;
                changed = true;
            }
        }
        if (changed) {
            geometryRevision++;
            rebuildMask();
        }
    }

    // Высота сугроба в точке x (координаты сугроба)
    function heightAt(d, x) {
        const h = d.heights;
        if (h.length < 2)
            return h[0] ?? 0;
        const u = Math.max(0, Math.min(h.length - 1, x / d.cellWidth));
        const i = Math.min(h.length - 2, Math.floor(u));
        return h[i] + (h[i + 1] - h[i]) * (u - i);
    }

    // Ближайшая поверхность под точкой среди сугробов ds: верх сугроба или низ экрана (bottom)
    function surfaceAt(ds, bottom, x, y) {
        let s = bottom;
        for (let j = 0; j < ds.length; j++) {
            const d = ds[j];
            const lx = x - d.x;
            if (lx < 0 || lx > d.width)
                continue;
            const top = d.y - heightAt(d, lx);
            if (top >= y - 2 && top < s)
                s = top;
        }
        return s;
    }

    // Столкновение быстрых снежинок с одним сугробом d (null — низ экрана):
    // удар — отскок, повторное касание — снежинка ложится в сугроб.
    // Отскочившая получает ускорение ay и дальше падает без JS
    function collideFlakes(list, dt, d) {
        const slow = fallSpeed * 0.6;
        const k = Math.min(0.5, 0.2 + (fallSpeed - 200) / 600);
        const share = bounceShare;
        const extra = bounceExtra;
        const g = debrisGravity;
        for (const p of list) {
            const vy = p.vy;
            // Взлетает после отскока
            if (vy <= 0)
                continue;
            const x = p.x;
            const y = p.y;
            let s = height;
            if (d) {
                const lx = x - d.x;
                if (lx < 0 || lx > d.width)
                    continue;
                s = d.y - heightAt(d, lx);
                // Уже внутри снега
                if (s < y - 2)
                    continue;
            }
            if (y + vy * dt < s)
                continue;
            const bounced = vy < slow;
            // Брызги: сверх 1 — дробная часть с вероятностью
            const n = bounced ? 0 : Math.floor(extra + Math.random());
            if (n > 0)
                splash.burst(n, x, s);
            if (bounced || Math.random() >= share) {
                p.discard();
            } else {
                const up = Math.min(slow * 0.85, vy * k * (0.7 + 0.6 * Math.random()));
                p.y = s;
                p.vy = -up;
                p.ay = g;
                p.vx += (Math.random() - 0.5) * up * 0.8;
            }
            p.update = true;
        }
    }

    // Физика выбитого снега: падение, сопротивление воздуха, ветер;
    // при ударе о поверхность — слабый отскок, затем скольжение с трением.
    // Лежащий ком не перезаписывается — его данные не отправляются на GPU заново
    function affectDebris(list, dt) {
        const drag = Math.min(1, 1.2 * dt);
        const friction = Math.max(0, 1 - 6 * dt);
        const ds = surfaces;
        const bottom = height;
        const wind = windSpeed;
        const g = debrisGravity;
        for (const p of list) {
            const x = p.x;
            const y = p.y;
            const vx = p.vx;
            const vy = p.vy;
            const s = surfaceAt(ds, bottom, x, y);
            if (y >= s - 0.5 && vy >= 0) {
                if (vy > 250) {
                    p.y = s;
                    p.vy = -vy * 0.2;
                    p.vx = vx * 0.6;
                } else if (vy === 0 && Math.abs(vx) < 0.001 && Math.abs(y - s) < 0.5) {
                    continue;
                } else {
                    // Лежит или скользит по поверхности, повторяя её рельеф
                    p.y = s;
                    p.vy = 0;
                    p.vx = Math.abs(vx) < 15 ? 0 : vx * friction;
                }
            } else {
                p.vx = vx + (wind - vx) * drag;
                const nvy = vy + g * dt;
                // Касание в этом кадре: встать на поверхность, скорость удара сохранить для отскока
                if (y + nvy * dt >= s)
                    p.y = s;
                p.vy = nvy;
            }
            p.update = true;
        }
    }

    // Профиль сугроба; у шапок на окнах края скруглены (четверть окружности)
    function makeDrift(key, x, y, w, start) {
        const n = Math.min(320, Math.ceil(w / 12) + 1);
        const cap = capFor(key);
        const cell = w / Math.max(1, n - 1);
        const round = key === "ground" ? 0 : cap * 2.5 * cfg.capRounding;
        const d = { key: key, x: x, y: y, width: w, cellWidth: cell, heights: [], caps: [], shape: [], extent: cap, full: false, dirty: true, visible: true };
        for (let i = 0; i < n; i++) {
            const e = Math.min(i, n - 1 - i) * cell;
            const t = round > 0 && e < round ? 1 - e / round : 0;
            // Профиль 0..1: у бесконечного сугроба задаёт скорость роста по ширине
            d.shape.push((0.75 + 0.25 * Math.random()) * Math.sqrt(1 - t * t));
            d.caps.push(cap * d.shape[i]);
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
        debrisDirection.xVariation = 70;
        debrisDirection.yVariation = 60;
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
        groundVisible = next.ground.visible;
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
                    d.full = false;
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
        for (const key in next)
            next[key].extent = extentOf(next[key]);
        floatingRects = floating;
        surfaces = Object.keys(next).map(key => next[key]).filter(d => d.visible);
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
                const h = d.extent + brushRadius;
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
        const inf = cfg.infiniteDrifts;
        let any = false;
        for (const key in drifts) {
            const d = drifts[key];
            if (d.full || !d.visible)
                continue;
            const h = d.heights;
            const n = h.length;
            const step = capFor(key) * k;
            const limit = inf ? limitFor(d) : 0;
            let changed = false;
            let clipped = false;
            let delta = 0;
            for (let i = 0; i < n; i++) {
                const c = inf ? limit : d.caps[i];
                const old = h[i];
                if (old >= c) {
                    // Окно поднялось выше — срезать до предела
                    if (old > c) {
                        h[i] = c;
                        changed = true;
                        clipped = true;
                    }
                    continue;
                }
                const l = h[Math.max(0, i - 1)];
                const r = h[Math.min(n - 1, i + 1)];
                h[i] = Math.min(c, old * 0.8 + (l + r) * 0.1 + step * (0.5 + Math.random()) * (inf ? d.shape[i] : 1));
                delta = Math.max(delta, Math.abs(h[i] - old));
                changed = true;
            }
            d.full = !changed;
            // Перерисовка, когда рост накопился хотя бы до полпикселя, и в конце роста
            d.pending = (d.pending ?? 0) + delta;
            if (clipped || d.pending >= 0.5 || (d.full && d.pending > 0)) {
                d.dirty = true;
                d.pending = 0;
            }
            any = any || changed;
        }
        growing = any;
        if (any)
            scheduleRepaint();
        // Во время расчистки полоса не сжимается — жест не теряет ввод
        if (inf && any && !sweepDrift)
            updateExtents();
    }

    // Вернуть сугробы к потолку после выключения бесконечных
    function clampDrifts() {
        for (const key in drifts) {
            const d = drifts[key];
            for (let i = 0; i < d.heights.length; i++)
                d.heights[i] = Math.min(d.heights[i], d.caps[i]);
            d.full = false;
            d.dirty = true;
        }
        growing = true;
        updateExtents();
        scheduleRepaint();
    }

    // Срез сугроба круглой щёткой вдоль отрезка (координаты сугроба); возвращает убранный объём
    // cuts[i] — высота ячейки до среза
    function carve(d, x0, h0, x1, h1, cuts) {
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
                if (!(i in cuts))
                    cuts[i] = h[i];
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
        sweepVx = 0;
        sweepVy = 0;
    }

    function sweepTo(x, ph) {
        const d = sweepDrift;
        const now = Date.now();
        const dt = Math.max(1, now - lastTime);
        // События мыши приходят неравномерно — скорость сглаживается
        const a = Math.min(1, dt / 40);
        sweepVx += (Math.max(-3000, Math.min(3000, (x - lastX) / dt * 1000)) - sweepVx) * a;
        sweepVy += (Math.max(-2000, Math.min(2000, (ph - lastH) / dt * 1000)) - sweepVy) * a;
        const cuts = {};
        const removed = carve(d, lastX, lastH, x, ph, cuts);
        if (removed > 0) {
            d.full = false;
            d.dirty = true;
            growing = true;
            scheduleRepaint();
            // Срезанный снег не исчезает: каждая ячейка рассыпается комьями на своём месте
            // и летит по направлению движения щётки: медленно — осыпается рядом, резко — разлетается
            const vx = sweepVx;
            const speed = Math.hypot(sweepVx, sweepVy);
            debrisDirection.x = vx * 0.85;
            debrisDirection.y = -Math.min(900, 40 + Math.abs(vx) * 0.25 + Math.max(0, sweepVy) * 0.8);
            debrisDirection.xVariation = 30 + speed * 0.3;
            debrisDirection.yVariation = 30 + speed * 0.2;
            const w = d.cellWidth;
            // Эмиттер шириной в ячейку: burst() рассыпает комья по её ширине,
            // поэтому срез выбрасывается слоями по 6 px, а не по одному кому
            debris.width = w;
            const amount = cfg.sweepAmount;
            for (const key in cuts) {
                const i = Number(key);
                const top = cuts[key];
                const bottom = d.heights[i];
                const layers = Math.max(1, Math.ceil((top - bottom) / 6));
                const layerH = (top - bottom) / layers;
                const per = layerH * w / debrisArea * amount;
                const left = d.x + (i - 0.5) * w;
                for (let j = 0; j < layers; j++) {
                    const n = Math.floor(per + Math.random());
                    if (n > 0)
                        debris.burst(n, left, d.y - bottom - (j + Math.random()) * layerH);
                }
            }
        }
        lastX = x;
        lastH = ph;
        lastTime = now;
    }

    function endSweep() {
        sweepDrift = null;
        updateExtents();
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
        function onInfiniteDriftsChanged() {
            if (root.cfg.infiniteDrifts) {
                root.growing = true;
                for (const key in root.drifts)
                    root.drifts[key].full = false;
            } else {
                root.clampDrifts();
            }
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
        groups: ["flakes"]
        source: "flake.svg"
        color: "white"
        alpha: 0.85
        alphaVariation: 0.15
    }

    // Смахнутый снег — поверх сугробов
    ImageParticle {
        z: 1
        system: particles
        groups: ["debris"]
        source: "flake.svg"
        color: "white"
        alpha: 0.9
        alphaVariation: 0.1
    }

    // Снегопад
    Emitter {
        system: particles
        group: "flakes"
        anchors.top: parent.top
        x: Math.min(0, -root.windShift)
        width: root.emitWidth
        height: 1
        emitRate: root.maxFlakes / root.fallSeconds
        // С отскоком снежинка живёт до касания сугроба или низа экрана
        maximumEmitted: Math.round(root.maxFlakes * (root.bouncing ? 1.4 : 1))
        lifeSpan: root.fallSeconds * (root.bouncing ? 1500 : 1000)
        lifeSpanVariation: 400
        size: 6
        sizeVariation: 3
        velocity: PointDirection {
            x: root.windSpeed
            y: root.fallSpeed
            yVariation: root.fallSpeed * 0.25
            // Порывы: разброс растёт с силой ветра
            xVariation: 8 + Math.abs(root.windSpeed) * 0.2
        }
    }

    // Покачивание
    Wander {
        system: particles
        groups: ["flakes"]
        x: Math.min(0, -root.windShift)
        width: root.emitWidth
        height: parent.height
        xVariance: 25
        pace: 30
    }

    // Выбитый снег: только burst(). burst() ставит частицу в случайную точку прямоугольника
    // размером с эмиттер от (x, y): высота 1, ширина — ячейка сугроба (задаётся при расчистке)
    Emitter {
        id: debris
        system: particles
        group: "debris"
        width: 12
        height: 1
        enabled: false
        maximumEmitted: Math.round(1500 * root.cfg.sweepAmount)
        lifeSpan: root.cfg.sweepLifetime * 1000
        lifeSpanVariation: root.cfg.sweepLifetime * 250
        size: 7
        sizeVariation: 3
        velocity: PointDirection {
            id: debrisDirection
            xVariation: 70
            yVariation: 60
        }
    }

    // Брызги отскока: короткоживущие комья с той же физикой. Размер 1×1 — как у debris
    Emitter {
        id: splash
        system: particles
        group: "debris"
        width: 1
        height: 1
        enabled: false
        maximumEmitted: Math.max(1, Math.round(Math.min(20000, root.maxFlakes * (root.cfg.bounceAmount - 1))))
        lifeSpan: 700
        lifeSpanVariation: 300
        size: 4
        sizeVariation: 2
        velocity: PointDirection {
            x: root.windSpeed * 0.5
            y: -root.fallSpeed * 0.35
            xVariation: 60 + root.fallSpeed * 0.15
            yVariation: root.fallSpeed * 0.15
        }
    }

    // Область шире экрана: подброшенный вверх снег тоже под действием физики
    Affector {
        system: particles
        groups: ["debris"]
        x: -parent.width
        y: -parent.height
        width: parent.width * 3
        height: parent.height * 2
        onAffectParticles: (list, dt) => root.affectDebris(list, dt)
    }

    // Отскок от низа экрана, когда нижнего сугроба нет
    Affector {
        system: particles
        groups: ["flakes"]
        enabled: root.bouncing && !root.groundVisible
        y: parent.height - root.bounceMargin
        width: parent.width
        height: root.bounceMargin
        onAffectParticles: (list, dt) => root.collideFlakes(list, dt, null)
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
            readonly property int extent: {
                root.geometryRevision;
                return drift ? drift.extent : 0;
            }

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
            height: extent + root.brushRadius
            visible: opacity > 0
            opacity: {
                root.geometryRevision;
                return drift && drift.visible ? 1 : 0;
            }

            Behavior on opacity {
                NumberAnimation { duration: Tokens.animationMedium }
            }

            // Отскок от сугроба: только в полосе над ним, чтобы не проверять все снежинки
            Affector {
                system: particles
                groups: ["flakes"]
                enabled: root.bouncing && slot.drift !== null && slot.opacity === 1
                y: -root.bounceMargin
                width: parent.width
                height: parent.height + root.bounceMargin
                onAffectParticles: (list, dt) => root.collideFlakes(list, dt, slot.drift)
            }

            Canvas {
                id: canvas
                anchors.bottom: parent.bottom
                width: parent.width
                height: slot.extent + 2
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
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
