import QtQuick
import Quickshell
import Quickshell.Io

// Спектр звука от cava: values — уровни полос 0..1, обновляются каждый кадр cava.
// cava запущен, только пока active.
Item {
    id: root

    property bool active: false
    property var values: []

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellPath("Bar/music_equalizer/cava.conf")]
        stdout: SplitParser {
            onRead: data => root.values = data.split(";").filter(s => s.length > 0).map(s => Number(s) / 1000)
        }
        onRunningChanged: if (!running) root.values = []
    }
}
