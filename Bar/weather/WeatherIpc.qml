import QtQuick
import Quickshell.Io

// IPC погоды: qs ipc call weather toggle|open|close|refresh
// Окно открывается под модулем погоды на мониторе в фокусе Niri (если модуль есть на его баре).
Item {
    id: root

    property string pendingAction: ""

    function withFocusedOutput(action: string): void {
        pendingAction = action;
        focusedOutput.running = true;
    }

    IpcHandler {
        target: "weather"

        function toggle(): void { root.withFocusedOutput("toggle"); }
        function open(): void { root.withFocusedOutput("open"); }
        function close(): void { WeatherState.openOutput = ""; }
        function refresh(): void { WeatherState.refresh(); }
    }

    Process {
        id: focusedOutput
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const out = JSON.parse(text);
                    if (!out?.name)
                        return;
                    const opened = WeatherState.openOutput !== "";
                    WeatherState.openOutput = root.pendingAction === "toggle" && opened ? "" : out.name;
                } catch (e) {
                    console.warn("weather ipc: не удалось разобрать focused-output:", e);
                }
            }
        }
    }
}
