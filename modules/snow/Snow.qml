pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/config"

// Снег на каждом экране. Выключен — окон нет, event-stream остановлен
Scope {
    id: root

    readonly property bool enabled: Config.options.snow.enabled

    NiriWindows {
        id: niriWindows
        active: root.enabled
    }

    Variants {
        model: root.enabled ? Quickshell.screens : []

        SnowWindow {
            niri: niriWindows
        }
    }
}
