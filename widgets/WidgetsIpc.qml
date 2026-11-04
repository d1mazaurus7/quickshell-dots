import QtQuick
import Quickshell.Io

// IPC редактора виджетов: qs ipc call widgets toggle|open|close
// Редактор открывается на мониторе в фокусе Niri
Item {
    id: root

    // action: "toggle" | "open" | "close"; output — имя монитора в фокусе ("" для close)
    signal requested(string action, string output)

    property string pendingAction: ""

    function withFocusedOutput(action: string): void {
        pendingAction = action;
        focusedOutput.running = true;
    }

    IpcHandler {
        target: "widgets"

        function toggle(): void { root.withFocusedOutput("toggle"); }
        function open(): void { root.withFocusedOutput("open"); }
        function close(): void { root.requested("close", ""); }
    }

    Process {
        id: focusedOutput
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const out = JSON.parse(text);
                    if (out && out.name)
                        root.requested(root.pendingAction, out.name);
                } catch (e) {
                    console.warn("widgets ipc: не удалось разобрать focused-output:", e);
                }
            }
        }
    }
}
