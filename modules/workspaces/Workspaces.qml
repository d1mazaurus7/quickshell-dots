import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme" as Theme
import "../../shell/config"
import "../../shell/theme"

// Рабочие столы Niri: активный выделен, остальные — точки. Настройки — Config.options.workspaces.
Rectangle {
    id: root

    // Имя выхода (monitor) для фильтрации; пусто — выход с фокусом
    property string output: ""

    // Настройки: Config.options.workspaces
    readonly property var cfg: Config.options.workspaces

    // Высота бара; модуль вписывается в неё с отступом vMargin
    property real barHeight: 40
    property real vMargin: 6
    readonly property int dotSize: Math.round(height * 0.43)
    // Стиль ячеек: "circles" — круги, активный пилюля | "squares" — квадраты с закруглением
    readonly property bool squareStyle: cfg.style === "squares"
    // В стиле квадратов активная ячейка не шире остальных
    readonly property int activeWidth: squareStyle ? dotSize : Math.round(dotSize * 8 / 3)
    readonly property int cellRadius: Math.round(dotSize * 0.3)
    readonly property int padding: Math.round((height - dotSize) / 2)
    property int gap: 8
    property int animFast: 180
    property int animSlow: 360

    // Номер рабочего стола в каждой ячейке
    readonly property bool showNumbers: cfg.showNumbers
    // Скрывать рабочие столы без окон
    readonly property bool hideEmpty: cfg.hideEmpty
    // Лимит видимых столов; активный остаётся видимым
    readonly property int maxVisible: cfg.maxVisible
    onHideEmptyChanged: rebuild()
    onMaxVisibleChanged: rebuild()
    onSquareStyleChanged: rebuild()

    property var workspaces: []
    property var windows: ({})
    property var shown: []
    property int activeIndex: -1

    readonly property string targetOutput: {
        if (output !== "") return output;
        const f = workspaces.find(w => w.is_focused);
        return f ? f.output : "";
    }

    implicitWidth: shown.length > 0
        ? padding * 2 + shown.length * dotSize + (shown.length - 1) * gap + (activeIndex >= 0 ? activeWidth - dotSize : 0)
        : 0
    implicitHeight: Math.max(0, barHeight - vMargin * 2)
    visible: shown.length > 0
    radius: height / 2
    color: Theme.Palette.surface_container_high

    function slotX(i) {
        return padding + i * (dotSize + gap) + (activeIndex >= 0 && i > activeIndex ? activeWidth - dotSize : 0);
    }

    function rebuild() {
        const busy = {};
        for (const k in windows) busy[windows[k]] = true;
        let list = workspaces
            .filter(w => w.output === targetOutput
                && (hideEmpty ? (busy[w.id] || w.is_active) : true))
            .sort((a, b) => a.idx - b.idx)
            .map(w => ({ id: w.id, idx: w.idx, output: w.output }));
        const act = workspaces.find(w => w.output === targetOutput && w.is_active);
        // Лимит видимых: обрезаем по наименьшим idx, активный остаётся видимым
        if (list.length > maxVisible) {
            list = list.slice(0, maxVisible);
            if (act && !list.some(w => w.id === act.id))
                list[maxVisible - 1] = { id: act.id, idx: act.idx, output: act.output };
        }
        // При показе пустых добираем ячейки до maxVisible даже без реальных столов.
        // id отрицательный — реальных id Niri не существует; клик по такой ячейке
        // фокусит стол по номеру (Niri сам ограничит индекс последним существующим)
        if (!hideEmpty && targetOutput !== "" && list.length < maxVisible) {
            for (let idx = 1; list.length < maxVisible; idx++)
                if (!list.some(w => w.idx === idx))
                    list.push({ id: -idx, idx: idx, output: targetOutput });
            list.sort((a, b) => a.idx - b.idx);
        }
        if (JSON.stringify(list) !== JSON.stringify(shown)) shown = list;
        activeIndex = act ? shown.findIndex(w => w.id === act.id) : -1;
        syncIndicator();
    }

    // Пилюля перетекает: ведущий край быстрее, хвост догоняет
    property real indL: 0
    property real indR: 0
    property bool stretchRight: true
    property bool ready: false

    function syncIndicator() {
        if (activeIndex < 0) return;
        const l = slotX(activeIndex);
        stretchRight = l > indL;
        indL = l;
        indR = l + activeWidth;
        ready = true;
    }

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id;
            const focused = ev.WorkspaceActivated.focused;
            const t = workspaces.find(w => w.id === id);
            if (!t) return;
            workspaces = workspaces.map(w => Object.assign({}, w, {
                is_active: w.output === t.output ? w.id === id : w.is_active,
                is_focused: focused ? w.id === id : w.is_focused
            }));
        } else if (ev.WindowsChanged) {
            const m = {};
            for (const w of ev.WindowsChanged.windows) m[w.id] = w.workspace_id;
            windows = m;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const m = Object.assign({}, windows);
            m[w.id] = w.workspace_id;
            windows = m;
        } else if (ev.WindowClosed) {
            const m = Object.assign({}, windows);
            delete m[ev.WindowClosed.id];
            windows = m;
        } else {
            return;
        }
        rebuild();
    }

    function activate(ws) {
        // focus-monitor переносит курсор в центр выхода — вызываем только при смене монитора
        const f = workspaces.find(w => w.is_focused);
        if (!f || f.output === ws.output) {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(ws.idx)]);
            return;
        }
        Quickshell.execDetached(["sh", "-c",
            'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"',
            "sh", ws.output, String(ws.idx)]);
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try { root.handle(JSON.parse(data)); } catch (e) {}
            }
        }
    }

    Repeater {
        model: root.shown

        Rectangle {
            id: dot
            required property var modelData
            required property int index
            readonly property bool active: index === root.activeIndex

            x: root.slotX(index)
            y: root.padding
            width: active ? root.activeWidth : root.dotSize
            height: root.dotSize
            radius: root.squareStyle ? root.cellRadius : height / 2
            color: area.containsMouse && !active ? Theme.Palette.on_secondary_container : Theme.Palette.secondary
            scale: area.pressed ? 0.85 : 1

            Behavior on x { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: root.animFast } }
            Behavior on scale { NumberAnimation { duration: root.animFast; easing.type: Easing.OutCubic } }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (!dot.active) root.activate(dot.modelData)
            }

            // Номер стола; на активном рисуется поверх индикатора отдельным текстом
            Text {
                anchors.centerIn: parent
                visible: root.showNumbers && !dot.active
                text: dot.modelData.idx
                color: area.containsMouse ? Theme.Palette.secondary : Theme.Palette.on_secondary_container
                font: Tokens.fontSmall
            }
        }
    }

    Rectangle {
        id: indicator
        visible: root.activeIndex >= 0
        x: root.indL
        y: root.padding
        width: root.indR - root.indL
        height: root.dotSize
        radius: root.squareStyle ? root.cellRadius : height / 2
        color: Theme.Palette.primary

        // Номер активного стола поверх пилюли/квадрата
        Text {
            anchors.centerIn: parent
            visible: root.showNumbers && root.activeIndex >= 0
            text: root.activeIndex >= 0 && root.shown[root.activeIndex] ? root.shown[root.activeIndex].idx : ""
            color: Theme.Palette.on_primary
            font: Tokens.fontSmall
        }
    }

    Behavior on indL {
        enabled: root.ready
        NumberAnimation { duration: root.stretchRight ? root.animSlow : root.animFast; easing.type: Easing.OutCubic }
    }
    Behavior on indR {
        enabled: root.ready
        NumberAnimation { duration: root.stretchRight ? root.animFast : root.animSlow; easing.type: Easing.OutCubic }
    }
    Behavior on implicitWidth { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
}
