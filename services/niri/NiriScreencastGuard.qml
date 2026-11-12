import QtQuick
import Quickshell
import Quickshell.Io
import "../../shell/config"

// Защита от записи экрана: блок правил block-out-from в niri/config/layer-rules.kdl
// между метками; остальное содержимое файла не трогаем. Файл подключается в config.kdl
Scope {
    id: root

    readonly property var cfg: Config.options.security
    readonly property string niriDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/niri"
    readonly property string include: 'include "config/layer-rules.kdl"'
    readonly property string beginMark: "// >>> quickshell: security"
    readonly property string endMark: "// <<< quickshell: security"

    property bool rulesRead: false
    property bool configRead: false

    // app-id окна: id desktop-файла и StartupWMClass (на Wayland бывает любой из них)
    readonly property var appIds: {
        const entries = DesktopEntries.applications.values;
        const ids = [];
        for (const id of cfg.protectedApps) {
            ids.push(id);
            const entry = entries.find(e => e.id === id);
            if (entry && entry.startupClass && !ids.includes(entry.startupClass))
                ids.push(entry.startupClass);
        }
        return ids;
    }

    readonly property string block: {
        let out = beginMark + "\n";
        if (cfg.hidePopups)
            out += 'layer-rule {\n    match namespace="^message-card$"\n    block-out-from "screen-capture"\n}\n';
        if (appIds.length > 0) {
            out += "window-rule {\n";
            for (const id of appIds)
                out += '    match app-id=r#"^' + id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + '$"#\n';
            out += '    block-out-from "screen-capture"\n}\n';
        }
        return out + endMark + "\n";
    }

    onBlockChanged: writeTimer.restart()
    onRulesReadChanged: writeTimer.restart()
    onConfigReadChanged: writeTimer.restart()

    // С задержкой: niri перезагружает конфиг на каждую запись файла
    Timer {
        id: writeTimer
        interval: 200
        onTriggered: {
            if (!Config.ready || !root.rulesRead || !root.configRead)
                return;
            const current = rules.loaded ? rules.text() : "";
            const start = current.indexOf(root.beginMark);
            const end = current.indexOf(root.endMark);
            let next;
            if (start >= 0 && end > start) {
                const after = current.indexOf("\n", end);
                next = current.slice(0, start) + root.block + (after >= 0 ? current.slice(after + 1) : "");
            } else {
                next = current + (current && !current.endsWith("\n") ? "\n" : "") + root.block;
            }
            if (next !== current)
                rules.setText(next);

            // Файл правил уже создан — подключаем его, если ещё нет
            if (niriConfig.loaded) {
                const text = niriConfig.text();
                if (!text.split("\n").some(l => l.trim() === root.include))
                    niriConfig.setText(text + (text && !text.endsWith("\n") ? "\n" : "") + root.include + "\n");
            }
        }
    }

    FileView {
        id: rules
        path: root.niriDir + "/config/layer-rules.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.rulesRead = true
        // Нет файла — создадим при записи
        onLoadFailed: root.rulesRead = true
    }

    FileView {
        id: niriConfig
        path: root.niriDir + "/config.kdl"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.configRead = true
        onLoadFailed: root.configRead = true
    }
}
