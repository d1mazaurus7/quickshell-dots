import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"
import "Icons.js" as Icons

// Сетка виджетов центра и её редактор (см. widgets/EDITOR_README.md).
// model — ListModel с ролями type, w, h (размер в ячейках); порядок модели = порядок чтения.
Item {
    id: grid

    required property real s
    required property ListModel model
    // Каталог: [{ type, title, icon, url, w, h, minW, maxW, minH, maxH }]
    required property var catalog
    // Передаётся каждому виджету как required property ctx
    property var ctx
    property bool editing: false
    property int columns: 4
    property real rowHeight: 56 * s
    property real gap: 12 * s

    // Раскладку изменил пользователь — пора сохранить
    signal edited()

    readonly property real cellW: (width - gap * (columns - 1)) / columns
    readonly property real stepX: cellW + gap
    readonly property real stepY: rowHeight + gap
    // Позиции в ячейках по индексу модели: [{ c, r, w, h }]
    property var rects: []
    property int rows: 0
    readonly property real gridHeight: rows > 0 ? rows * stepY - gap : 0
    // Виджеты каталога, которых нет в сетке
    property var missing: []
    // Виджет, с которым только что поменялись местами: не меняемся обратно,
    // пока курсор не покинет его (иначе виджеты разной ширины «дрожат»)
    property string blocked: ""

    implicitHeight: gridHeight + (editing ? tray.y - gridHeight + tray.height : 0)

    function spec(type: string): var {
        return catalog.find(c => c.type === type) ?? null;
    }

    function clamp(v: int, lo: int, hi: int): int {
        return Math.max(lo, Math.min(hi, v));
    }

    // Последовательная упаковка: каждый виджет — в первое свободное место после предыдущего
    function relayout(): void {
        const occ = [];
        const out = [];
        const used = {};
        let r0 = 0, c0 = 0, total = 0;
        const free = (r, c, w, h) => {
            for (let y = r; y < r + h; y++)
                for (let x = c; x < c + w; x++)
                    if (occ[y] && occ[y][x])
                        return false;
            return true;
        };
        for (let i = 0; i < model.count; i++) {
            const it = model.get(i);
            const w = clamp(it.w, 1, columns), h = Math.max(1, it.h);
            used[it.type] = true;
            let r = r0, c = c0;
            for (;;) {
                if (c + w > columns) {
                    c = 0;
                    r++;
                } else if (free(r, c, w, h)) {
                    break;
                } else {
                    c++;
                }
            }
            for (let y = r; y < r + h; y++) {
                occ[y] = occ[y] || [];
                for (let x = c; x < c + w; x++)
                    occ[y][x] = true;
            }
            out.push({ c: c, r: r, w: w, h: h });
            r0 = r;
            c0 = c + w;
            total = Math.max(total, r + h);
        }
        rects = out;
        rows = total;
        const miss = catalog.filter(c => !used[c.type]);
        if (miss.map(m => m.type).join() !== missing.map(m => m.type).join())
            missing = miss;
    }

    function contains(rc: var, p: point): bool {
        return p.x >= rc.c * stepX && p.x < (rc.c + rc.w) * stepX
            && p.y >= rc.r * stepY && p.y < (rc.r + rc.h) * stepY;
    }

    function indexOf(type: string): int {
        for (let i = 0; i < model.count; i++)
            if (model.get(i).type === type)
                return i;
        return -1;
    }

    // Перетаскивание: p — курсор в координатах сетки
    function dragTo(from: int, p: point): void {
        if (blocked !== "") {
            const b = indexOf(blocked);
            if (b < 0 || !contains(rects[b], p))
                blocked = "";
        }
        let target = -1;
        for (let i = 0; i < rects.length; i++) {
            if (i !== from && contains(rects[i], p)) {
                target = i;
                break;
            }
        }
        // За последним виджетом — в конец
        if (target < 0) {
            const last = rects[rects.length - 1];
            if (!last || from === model.count - 1)
                return;
            const after = p.y >= (last.r + last.h) * stepY
                || (p.y >= last.r * stepY && p.x >= (last.c + last.w) * stepX);
            if (!after)
                return;
            target = model.count - 1;
        }
        const t = model.get(target).type;
        if (t === blocked)
            return;
        blocked = t;
        model.move(from, target, 1);
    }

    function resizeTo(index: int, w: int, h: int): void {
        const it = model.get(index);
        const sp = spec(it.type);
        if (!sp)
            return;
        w = clamp(w, sp.minW, Math.min(sp.maxW, columns));
        h = clamp(h, sp.minH, sp.maxH);
        if (w !== it.w)
            model.setProperty(index, "w", w);
        if (h !== it.h)
            model.setProperty(index, "h", h);
    }

    function add(type: string): void {
        const sp = spec(type);
        if (!sp || indexOf(type) >= 0)
            return;
        model.append({ type: type, w: sp.w, h: sp.h });
        edited();
    }

    function remove(index: int): void {
        model.remove(index, 1);
        edited();
    }

    Connections {
        target: grid.model
        function onRowsInserted() { grid.relayout(); }
        function onRowsRemoved() { grid.relayout(); }
        function onRowsMoved() { grid.relayout(); }
        function onDataChanged() { grid.relayout(); }
        function onModelReset() { grid.relayout(); }
    }
    onColumnsChanged: relayout()
    onCatalogChanged: relayout()
    onEditingChanged: blocked = ""
    Component.onCompleted: relayout()

    Repeater {
        model: grid.model

        Item {
            id: cell

            required property int index
            required property string type
            readonly property var rc: grid.rects[index] ?? null
            readonly property var sp: grid.spec(type)
            readonly property real homeX: rc ? rc.c * grid.stepX : 0
            readonly property real homeY: rc ? rc.r * grid.stepY : 0
            readonly property real radius: Math.min(height * 0.32, 24 * grid.s)
            property bool dragging: false
            property bool resizing: false
            property real dragX
            property real dragY
            // Анимации включаются после первого размещения: новый виджет не «прилетает» из угла
            property bool settled: false

            visible: rc !== null
            x: dragging ? dragX : homeX
            y: dragging ? dragY : homeY
            z: dragging || resizing ? 10 : 0
            width: rc ? rc.w * grid.stepX - grid.gap : 0
            height: rc ? rc.h * grid.stepY - grid.gap : 0
            scale: dragging ? 1.04 : grid.editing ? 0.96 : 1

            Behavior on x { enabled: cell.settled && !cell.dragging; Emphasized {} }
            Behavior on y { enabled: cell.settled && !cell.dragging; Emphasized {} }
            Behavior on width { enabled: cell.settled; Smooth {} }
            Behavior on height { enabled: cell.settled; Smooth {} }
            Behavior on scale { Emphasized {} }

            Timer {
                running: cell.rc !== null && !cell.settled
                interval: 0
                onTriggered: cell.settled = true
            }

            Loader {
                id: content
                anchors.fill: parent
                // В редакторе виджеты не реагируют на мышь
                enabled: !grid.editing
                Component.onCompleted: if (cell.sp) setSource(cell.sp.url, { ctx: grid.ctx })
            }

            // Рамка редактора: перенос, края для масштабирования, удаление
            Loader {
                anchors.fill: parent
                opacity: grid.editing ? 1 : 0
                active: grid.editing || opacity > 0
                Behavior on opacity { Smooth {} }

                sourceComponent: Item {
                    id: frame
                    readonly property bool canW: !!cell.sp && cell.sp.minW !== Math.min(cell.sp.maxW, grid.columns)
                    readonly property bool canH: !!cell.sp && cell.sp.minH !== cell.sp.maxH
                    readonly property real hs: 14 * grid.s

                    // Начало перетаскивания края: курсор → размер в ячейках
                    function resizeAt(area: Item, mouse: var, horizontal: bool, vertical: bool): void {
                        const p = area.mapToItem(grid, mouse.x, mouse.y);
                        grid.resizeTo(cell.index,
                            horizontal ? Math.round((p.x - cell.homeX + grid.gap) / grid.stepX) : cell.rc.w,
                            vertical ? Math.round((p.y - cell.homeY + grid.gap) / grid.stepY) : cell.rc.h);
                    }

                    // Видимая форма виджета: виджет может сообщить отступ по вертикали
                    // (editInsetV) и скругление (editRadius), чтобы обводка шла ровно
                    readonly property real insetV: content.item && content.item.editInsetV !== undefined ? content.item.editInsetV : 0
                    readonly property real shapeRadius: content.item && content.item.editRadius !== undefined ? content.item.editRadius : cell.radius
                    readonly property int bw: Math.max(1, Math.round(2 * grid.s))
                    readonly property int pad: Math.max(2, Math.round(3 * grid.s))
                    readonly property real out: pad + bw
                    // Точка на дуге правого скругления под 45° (для крестика и угловой ручки)
                    readonly property real arc: (outline.radius - bw / 2) * 0.2929 + bw / 2

                    Rectangle {
                        id: outline
                        x: -frame.out
                        y: frame.insetV - frame.out
                        width: frame.width + 2 * frame.out
                        height: frame.height - 2 * frame.insetV + 2 * frame.out
                        radius: Math.min(frame.shapeRadius + frame.out, height / 2)
                        color: cell.dragging ? Qt.rgba(Theme.Palette.primary.r, Theme.Palette.primary.g, Theme.Palette.primary.b, 0.08) : "transparent"
                        border.width: frame.bw
                        border.color: cell.dragging || cell.resizing ? Theme.Palette.primary : Theme.Palette.outline
                        Behavior on border.color { SmoothColor {} }
                    }

                    MouseArea {
                        id: moveArea
                        property point off

                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: cell.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: mouse => {
                            const p = mapToItem(grid, mouse.x, mouse.y);
                            off = Qt.point(p.x - cell.x, p.y - cell.y);
                            cell.dragX = cell.x;
                            cell.dragY = cell.y;
                            grid.blocked = "";
                            cell.dragging = true;
                        }
                        onPositionChanged: mouse => {
                            if (!cell.dragging)
                                return;
                            const p = mapToItem(grid, mouse.x, mouse.y);
                            cell.dragX = Math.max(-grid.gap, Math.min(grid.width - cell.width + grid.gap, p.x - off.x));
                            cell.dragY = Math.max(-grid.gap, Math.min(grid.gridHeight - cell.height + grid.gap, p.y - off.y));
                            grid.dragTo(cell.index, p);
                        }
                        onReleased: finish()
                        onCanceled: finish()

                        function finish(): void {
                            if (!cell.dragging)
                                return;
                            cell.dragging = false;
                            grid.edited();
                        }
                    }

                    // Правый край
                    ResizeHandle {
                        s: grid.s
                        visible: frame.canW
                        x: outline.x + outline.width - frame.bw / 2 - width / 2
                        y: outline.y + (outline.height - height) / 2
                        width: frame.hs
                        height: Math.max(20 * grid.s, Math.min(outline.height - 2 * outline.radius, 28 * grid.s))
                        vertical: true
                        cursor: Qt.SizeHorCursor
                        onMoved: (area, mouse) => frame.resizeAt(area, mouse, true, false)
                        onPressedChanged: cell.resizing = pressed
                        onReleased: grid.edited()
                    }

                    // Нижний край
                    ResizeHandle {
                        s: grid.s
                        visible: frame.canH
                        x: outline.x + (outline.width - width) / 2
                        y: outline.y + outline.height - frame.bw / 2 - height / 2
                        width: Math.max(20 * grid.s, Math.min(outline.width - 2 * outline.radius, 28 * grid.s))
                        vertical: false
                        height: frame.hs
                        cursor: Qt.SizeVerCursor
                        onMoved: (area, mouse) => frame.resizeAt(area, mouse, false, true)
                        onPressedChanged: cell.resizing = pressed
                        onReleased: grid.edited()
                    }

                    // Угол
                    ResizeHandle {
                        s: grid.s
                        visible: frame.canW && frame.canH
                        x: outline.x + outline.width - frame.arc - width / 2
                        y: outline.y + outline.height - frame.arc - height / 2
                        width: frame.hs * 1.3
                        height: width
                        dot: true
                        cursor: Qt.SizeFDiagCursor
                        onMoved: (area, mouse) => frame.resizeAt(area, mouse, true, true)
                        onPressedChanged: cell.resizing = pressed
                        onReleased: grid.edited()
                    }

                    IconButton {
                        s: grid.s
                        x: outline.x + outline.width - frame.arc - width / 2
                        y: outline.y + frame.arc - height / 2
                        width: 22 * grid.s
                        height: width
                        round: true
                        icon: Icons.close
                        iconSize: width * 0.6
                        color: Theme.Palette.tertiary
                        contentColor: Theme.Palette.on_tertiary
                        onClicked: grid.remove(cell.index)
                    }
                }
            }
        }
    }

    // Лоток редактора: подсказка и виджеты для добавления
    Column {
        id: tray
        y: grid.gridHeight + (grid.gridHeight > 0 ? grid.gap * 1.5 : 0)
        width: parent.width
        spacing: 10 * grid.s
        opacity: grid.editing ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Smooth {} }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: grid.missing.length > 0
                ? "Перетаскивайте виджеты, тяните за края для размера. Добавить:"
                : "Перетаскивайте виджеты, тяните за края для размера."
            color: Theme.Palette.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Math.round(11 * grid.s)
        }

        Flow {
            width: parent.width
            spacing: 8 * grid.s

            Repeater {
                model: grid.missing

                Chip {
                    required property var modelData
                    s: grid.s
                    icon: modelData.icon
                    text: modelData.title
                    onClicked: grid.add(modelData.type)
                }
            }
        }
    }
}
