import QtQuick
import Quickshell
import "../../shell/theme"
import "../controls"
import "../../settings/controls" as SettingsControls
import "MediaShapes.js" as Shapes

Column {
    id: root

    property var settings: ({})
    signal settingChanged(string key, var value)

    readonly property string source: settings.source
    readonly property string home: Quickshell.env("HOME") ?? "/"

    // «~» → $HOME, без завершающего «/»
    function expand(text: string): string {
        const t = text.trim().replace(/^~(?=\/|$)/, home);
        return t.length > 1 ? t.replace(/\/+$/, "") : t;
    }
    function isMedia(path: string): bool {
        const ext = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
        return ["png", "jpg", "jpeg", "webp", "bmp", "svg", "gif"].includes(ext) || Shapes.videoSuffixes.includes(ext);
    }

    spacing: Tokens.spacingMediumV

    DropdownRow {
        width: parent.width
        text: "Шаблон"
        options: Shapes.options
        value: root.settings.shape
        onSelected: v => root.settingChanged("shape", v)
    }
    SliderRow {
        width: parent.width
        visible: root.settings.shape !== "circle"
        text: "Закругление"
        from: 0; to: 1; stepSize: 0.05
        formatValue: v => Math.round(v * 100) + "%"
        value: root.settings.radius
        onMoved: v => root.settingChanged("radius", v)
    }
    SettingsControls.SettingTextField {
        width: parent.width
        value: root.source
        placeholder: "Путь к фото, gif или видео"
        // Файл — источник; папка по Enter открывается в обзоре ниже
        onEdited: text => {
            const path = root.expand(text);
            if (path === "" || root.isMedia(path))
                root.settingChanged("source", path);
        }
        onAccepted: text => {
            const path = root.expand(text);
            if (path !== "" && !root.isMedia(path))
                browser.path = path;
        }
    }
    FileBrowser {
        id: browser
        width: parent.width
        folder: root.source !== "" ? root.source.slice(0, root.source.lastIndexOf("/")) || "/"
            : root.home
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.svg", "*.gif"]
            .concat(Shapes.videoSuffixes.map(s => "*." + s))
        videoSuffixes: Shapes.videoSuffixes
        value: root.source
        onSelected: path => root.settingChanged("source", path)
    }
}
