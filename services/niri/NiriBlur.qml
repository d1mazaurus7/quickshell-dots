import QtQuick
import Quickshell
import Quickshell.Io
import "../../shell/config"

// Сила размытия задаётся только конфигом niri: пишем блок blur в отдельный файл,
// подключённый через include в config.kdl; niri перечитывает его сам
Scope {
    id: root

    readonly property real offset: Config.options.appearance.blur

    onOffsetChanged: writeTimer.restart()
    Component.onCompleted: writeTimer.restart()

    // С задержкой: niri перезагружает конфиг на каждую запись файла
    Timer {
        id: writeTimer
        interval: 200
        // При 0 Shell просто не запрашивает размытие, блок не трогаем
        onTriggered: if (root.offset > 0)
            file.setText("blur {\n    offset " + root.offset + "\n}\n")
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/niri/config/blur.kdl"
        printErrors: false
    }
}
