import QtQuick
import Quickshell
import Quickshell.Io

// Есть ли окно в фокусе niri (event-stream, без опроса). Сервис виджетов: services.focus
Scope {
    id: root

    property bool active: false
    property var focusedId: null
    readonly property bool focused: active && focusedId !== null

    function handle(e) {
        if (e.WindowFocusChanged) {
            focusedId = e.WindowFocusChanged.id;
        } else if (e.WindowsChanged) {
            focusedId = e.WindowsChanged.windows.find(w => w.is_focused)?.id ?? null;
        } else if (e.WindowOpenedOrChanged) {
            const w = e.WindowOpenedOrChanged.window;
            if (w.is_focused)
                focusedId = w.id;
            else if (focusedId === w.id)
                focusedId = null;
        } else if (e.WindowClosed && e.WindowClosed.id === focusedId) {
            focusedId = null;
        }
    }

    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: root.active
        onRunningChanged: if (!running) root.focusedId = null
        stdout: SplitParser {
            onRead: data => {
                try { root.handle(JSON.parse(data)); } catch (e) {}
            }
        }
    }
}
