import QtQuick
import Quickshell
import Quickshell.Io

// Окна и рабочие столы niri из event-stream — только геометрия для снега
Scope {
    id: root

    property bool active: false
    property var windows: ({})
    property var workspaces: ({})
    // Растёт при любом изменении окон или рабочих столов
    property int revision: 0

    // Видимые окна выхода в лог. px выхода: [{ id, floating, x, y, w, h }]
    function visibleOn(output) {
        const res = [];
        for (const id in windows) {
            const w = windows[id];
            const ws = workspaces[w.workspace_id];
            const pos = w.layout.tile_pos_in_workspace_view;
            if (!ws || !ws.is_active || ws.output !== output || !pos)
                continue;
            res.push({ id: w.id, floating: w.is_floating, x: pos[0], y: pos[1], w: w.layout.tile_size[0], h: w.layout.tile_size[1] });
        }
        return res;
    }

    // Есть ли тайловые окна на активном рабочем столе выхода (даже без координат)
    function hasTiledOn(output) {
        for (const id in windows) {
            const w = windows[id];
            const ws = workspaces[w.workspace_id];
            if (!w.is_floating && ws && ws.is_active && ws.output === output)
                return true;
        }
        return false;
    }

    // Окно с последней известной позицией, сейчас не видимое на выходе:
    // "dragging" — перетаскивается (niri не сообщает позицию), "hidden" — на неактивном
    // рабочем столе этого выхода, "other" — на другом выходе, "gone" — закрыто или не плавающее
    function stateOf(id, output) {
        const w = windows[id];
        if (!w || !w.is_floating)
            return "gone";
        if (w.workspace_id === null || w.workspace_id === undefined)
            return "dragging";
        const ws = workspaces[w.workspace_id];
        return ws && ws.output === output ? "hidden" : "other";
    }

    function handle(e) {
        if (e.WorkspacesChanged) {
            const m = {};
            for (const ws of e.WorkspacesChanged.workspaces)
                m[ws.id] = ws;
            workspaces = m;
        } else if (e.WorkspaceActivated) {
            const a = workspaces[e.WorkspaceActivated.id];
            if (!a)
                return;
            for (const id in workspaces)
                if (workspaces[id].output === a.output)
                    workspaces[id].is_active = false;
            a.is_active = true;
        } else if (e.WindowsChanged) {
            const m = {};
            for (const w of e.WindowsChanged.windows)
                m[w.id] = w;
            windows = m;
        } else if (e.WindowOpenedOrChanged) {
            const w = e.WindowOpenedOrChanged.window;
            windows[w.id] = w;
        } else if (e.WindowClosed) {
            delete windows[e.WindowClosed.id];
        } else if (e.WindowLayoutsChanged) {
            for (const [id, layout] of e.WindowLayoutsChanged.changes)
                if (windows[id])
                    windows[id].layout = layout;
        } else {
            return;
        }
        revision++;
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: root.active
        stdout: SplitParser {
            onRead: data => {
                try { root.handle(JSON.parse(data)); } catch (e) {}
            }
        }
    }
}
