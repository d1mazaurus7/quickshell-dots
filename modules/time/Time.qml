import QtQuick
import Quickshell
import "../../shell/config"
import "../../shell/theme"

// Время в баре: Config.options.time
Text {
    id: root

    readonly property var cfg: Config.options.time
    readonly property string format: [
        cfg.showWeekday ? (cfg.shortWeekday ? "ddd" : "dddd") : "",
        cfg.showDate ? "dd.MM" : "",
        cfg.showSeconds ? "hh:mm:ss" : "hh:mm"
    ].filter(s => s !== "").join("  ")

    text: Qt.locale().toString(clock.date, format)
    color: Tokens.colors.on_surface
    font: Tokens.fontMedium

    SystemClock {
        id: clock
        precision: root.cfg.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
