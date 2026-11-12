import QtQuick
import Quickshell.Io

// IPC окна настроек: qs ipc call settings toggle|open|close
IpcHandler {
    id: root
    required property var window

    target: "settings"

    function toggle(): void {
        root.window.open = !root.window.open;
    }

    function open(): void {
        root.window.open = true;
    }

    function close(): void {
        root.window.open = false;
    }
}
