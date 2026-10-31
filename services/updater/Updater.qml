import QtQuick
import Quickshell
import Quickshell.Io

// Обновление оболочки из GitHub: клон во временную папку → перенос файлов
// в shellDir → перезагрузка (сама по watchFiles) → после неё «установлено»
Item {
    id: root

    readonly property string repoUrl: "https://github.com/d1mazaurus7/quickshell-dots.git"
    readonly property string sourceDir: Quickshell.cachePath("update-source")
    // Метка «обновление только что установлено»: время записи, переживает перезагрузку
    readonly property string marker: Quickshell.statePath("update-installed")

    // idle | checking | installing | installed | failed
    property string status: "idle"
    readonly property bool busy: status === "checking" || status === "installing"

    // Оболочка перезагрузилась после установки обновления
    signal installedOnStart

    function start() {
        if (busy)
            return;
        status = "checking";
        checkDelay.restart();
    }

    Timer {
        id: checkDelay
        interval: 2000
        onTriggered: {
            root.status = "installing";
            clone.running = true;
        }
    }

    // Клон не трогает конфиг, поэтому живёт как обычный Process
    Process {
        id: clone
        command: ["sh", "-c", 'rm -rf "$2" && git clone --depth 1 --quiet "$1" "$2"', "sh", root.repoUrl, root.sourceDir]
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn(text.trim())
        }
        onExited: code => {
            if (code !== 0) {
                root.status = "failed";
                return;
            }
            // Перенос — отдельным процессом: копирование файлов вызовет перезагрузку,
            // а обычный Process при ней убивается
            Quickshell.execDetached(["sh", "-c",
                'rm -rf "$1/.git" && mkdir -p "$(dirname "$3")" && date +%s > "$3" && cp -a "$1/." "$2/"; rm -rf "$1"',
                "sh", root.sourceDir, Quickshell.shellDir, root.marker]);
        }
    }

    // При старте: свежая метка → показать результат. Удаляется с задержкой,
    // чтобы повторная перезагрузка от копирования тоже её увидела
    Process {
        running: true
        command: ["cat", root.marker]
        stdout: StdioCollector {
            onStreamFinished: {
                const written = parseInt(text);
                if (isNaN(written) || Date.now() / 1000 - written > 120)
                    return;
                root.status = "installed";
                root.installedOnStart();
                cleanup.start();
            }
        }
    }

    Timer {
        id: cleanup
        interval: 5000
        onTriggered: Quickshell.execDetached(["rm", "-f", root.marker])
    }
}
