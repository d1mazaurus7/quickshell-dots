pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/config"

// Снег на каждом экране. Выключен — окон нет, event-stream остановлен
Scope {
    id: root

    readonly property bool enabled: Config.options.snow.enabled
    // Заставка только при включении из настроек, не при загрузке конфига
    property bool introPlaying: false

    onEnabledChanged: introPlaying = enabled && Config.ready

    NiriWindows {
        id: niriWindows
        active: root.enabled
    }

    Variants {
        model: root.enabled && !root.introPlaying ? Quickshell.screens : []

        SnowWindow {
            niri: niriWindows
        }
    }

    Variants {
        model: root.introPlaying ? Quickshell.screens : []

        SnowIntro {
            onFinished: root.introPlaying = false
        }
    }
}
