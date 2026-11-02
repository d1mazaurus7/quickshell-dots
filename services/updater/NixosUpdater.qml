import QtQuick
import Quickshell
import Quickshell.Io

// Обновление NixOS: в терминале клон приватного репозитория → install.sh.
// Терминал запускается отдельно от оболочки (install.sh может её перезагрузить),
// результат приходит через файл: "running" или код выхода
Item {
    id: root

    readonly property string repoUrl: "https://github.com/d1mazaurus7/nixos-config.git"
    readonly property string sourceDir: Quickshell.cachePath("nixos-update-source")
    readonly property string resultFile: Quickshell.statePath("nixos-update-result")

    // Установленная конфигурация: version — первая строка, вторая — стабильность
    property string version: ""
    property string stability: ""
    property string changelog: ""

    // idle | checking | installing | installed | failed
    property string status: "idle"
    readonly property bool busy: status === "checking" || status === "installing"

    function start() {
        if (busy)
            return;
        status = "checking";
        checkDelay.restart();
    }

    // Команда в терминале; read держит окно открытым, чтобы был виден вывод
    function runInTerminal(command) {
        Quickshell.execDetached(["foot", "-e", "zsh", "-ic", command + '; echo; read "?Enter — закрыть"']);
    }

    Timer {
        id: checkDelay
        interval: 2000
        onTriggered: {
            root.status = "installing";
            Quickshell.execDetached(["sh", "-c",
                'mkdir -p "$(dirname "$3")"; foot -e sh -c \'echo running > "$3"; rm -rf "$2" && git clone --depth 1 "$1" "$2" && cd "$2" && bash ./install.sh; c=$?; echo $c > "$3"; rm -rf "$2"; echo; [ $c -eq 0 ] && echo "Обновление установлено" || echo "Ошибка: код $c"; echo "Enter — закрыть"; read _\' sh "$1" "$2" "$3"; grep -q running "$3" && echo 1 > "$3"',
                "sh", root.repoUrl, root.sourceDir, root.resultFile]);
        }
    }

    FileView {
        id: versionFile
        path: "/etc/nixos/version"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const lines = text().split("\n");
            root.version = (lines[0] ?? "").trim();
            root.stability = (lines[1] ?? "").trim();
        }
        onLoadFailed: {
            root.version = "";
            root.stability = "";
        }
    }

    FileView {
        id: changelogFile
        path: "/etc/nixos/CHANGELOGS.md"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.changelog = text()
        onLoadFailed: root.changelog = ""
    }

    FileView {
        id: result
        path: root.resultFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const value = text().trim();
            if (value === "running")
                root.status = "installing";
            else if (root.status === "installing" && value !== "") {
                root.status = value === "0" ? "installed" : "failed";
                // Файлов могло не быть до установки — тогда они не отслеживались
                versionFile.reload();
                changelogFile.reload();
            }
        }
    }
}
