pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Скриншоты»: Config.options.screenshot
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var screenshot: Config.options.screenshot
    // Звуки из assets/sounds/screenshot
    readonly property var sounds: {
        const list = [];
        for (let i = 0; i < soundFiles.count; i++)
            list.push(soundFiles.get(i, "fileName"));
        return list;
    }

    spacing: Tokens.spacingMediumV

    FolderListModel {
        id: soundFiles
        folder: "file://" + Quickshell.shellPath("assets/sounds/screenshot")
        nameFilters: ["*.wav", "*.ogg", "*.flac"]
        showDirs: false
    }

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Скриншоты"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Сообщение после скриншота"
        description: "Уведомление с путём к сохранённому файлу"

        SettingSwitch {
            checked: page.screenshot.notify
            onToggled: checked => page.screenshot.notify = checked
        }
    }

    SettingRow {
        title: "Инструменты редактирования"
        description: "Кисть, ластик и размытие на панели"

        SettingSwitch {
            checked: page.screenshot.editTools
            onToggled: checked => page.screenshot.editTools = checked
        }
    }

    SettingRow {
        title: "Без редактирования"
        description: "Снимок области сразу после выделения: в файл и в буфер"

        SettingSwitch {
            checked: page.screenshot.instant
            onToggled: checked => page.screenshot.instant = checked
        }
    }

    SettingRow {
        title: "Звук скриншота"
        description: "Проигрывать звук после снимка"

        SettingSwitch {
            checked: page.screenshot.sound
            onToggled: checked => page.screenshot.sound = checked
        }
    }

    SettingRow {
        z: soundDropdown.expanded ? 1 : 0
        shown: page.screenshot.sound
        child: true
        title: "Выбрать звук скриншота"
        description: page.sounds.length > 0 ? "Файлы из assets/sounds/screenshot"
                                            : "Папка assets/sounds/screenshot пуста"

        SettingDropdown {
            id: soundDropdown
            model: page.sounds
            currentValue: page.screenshot.soundFile
            popupHeight: Tokens.scaled(180)
            onActivated: value => page.screenshot.soundFile = value
        }
    }
}
