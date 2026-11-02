pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Лаунчер»: Config.options.launcher
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var launcher: Config.options.launcher
    // Название нового тега: без "#" и пробелов, в нижнем регистре
    property string newTag: ""
    readonly property string tagName: newTag.replace(/^#+/, "").replace(/\s+/g, "").toLowerCase()
    readonly property bool tagValid: tagName !== "" && !launcher.tags.some(t => t.name === tagName)

    function addTag() {
        tagField.commit();
        if (!tagValid)
            return;
        launcher.tags = launcher.tags.concat([{ name: tagName, apps: [] }]);
        newTag = "";
    }

    function setTagApps(index, apps) {
        const tags = launcher.tags.slice();
        tags[index] = { name: tags[index].name, apps: apps };
        launcher.tags = tags;
    }

    function removeTag(index) {
        launcher.tags = launcher.tags.filter((t, i) => i !== index);
    }

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Лаунчер"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        z: positionDropdown.expanded ? 1 : 0
        title: "Открытие"
        description: "Край экрана, от которого выезжает лаунчер"

        SettingDropdown {
            id: positionDropdown
            readonly property var positions: [
                { value: "top", title: "Сверху" },
                { value: "bottom", title: "Снизу" },
                { value: "left", title: "Слева" },
                { value: "right", title: "Справа" }
            ]
            model: positions.map(p => p.title)
            popupHeight: Tokens.scaled(176)
            currentValue: (positions.find(p => p.value === page.launcher.position) ?? positions[1]).title
            onActivated: value => page.launcher.position = positions.find(p => p.title === value).value
        }
    }

    SettingRow {
        title: "Иконки программ"

        SettingSwitch {
            checked: page.launcher.showIcons
            onToggled: checked => page.launcher.showIcons = checked
        }
    }

    SettingRow {
        shown: page.launcher.showIcons
        child: true
        title: "Буква вместо иконки"
        description: "Первая буква названия, если иконка недоступна"

        SettingSwitch {
            checked: page.launcher.letterIcons
            onToggled: checked => page.launcher.letterIcons = checked
        }
    }

    SettingRow {
        title: "Описания программ"

        SettingSwitch {
            checked: page.launcher.showDescriptions
            onToggled: checked => page.launcher.showDescriptions = checked
        }
    }

    SettingAppList {
        title: "Закреплённые программы"
        description: "Показываются в начале списка"
        apps: page.launcher.pinnedApps
        onEdited: apps => page.launcher.pinnedApps = apps
    }

    SettingAppList {
        title: "Скрытые программы"
        description: "Не показываются в лаунчере"
        apps: page.launcher.hiddenApps
        onEdited: apps => page.launcher.hiddenApps = apps
    }

    SettingRow {
        title: "Добавить тег"
        description: "Поиск программ по тегу: #games, #video"

        Row {
            spacing: Tokens.spacingMedium

            SettingTextField {
                id: tagField
                implicitWidth: Tokens.scaled(200)
                value: page.newTag
                placeholder: "#тег"
                onEdited: text => page.newTag = text
            }

            SettingButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Добавить"
                opacity: page.tagValid ? 1 : 0.5
                onClicked: page.addTag()
            }
        }
    }

    SettingRow {
        title: "Кнопки тегов"
        description: "Под строкой поиска в лаунчере"

        SettingSwitch {
            checked: page.launcher.showTagButtons
            onToggled: checked => page.launcher.showTagButtons = checked
        }
    }

    Repeater {
        model: page.launcher.tags

        SettingAppList {
            id: tagList
            required property var modelData
            required property int index

            title: "#" + modelData.name
            description: "Программы с этим тегом"
            apps: modelData.apps
            removable: true
            onEdited: apps => page.setTagApps(tagList.index, apps)
            onRemoveRequested: page.removeTag(tagList.index)
        }
    }

    SettingRow {
        title: "Команда «>»"
        description: "Запуск команды в терминале"

        SettingSwitch {
            checked: page.launcher.commandShell
            onToggled: checked => page.launcher.commandShell = checked
        }
    }

    SettingRow {
        title: "Команда «/emoji»"
        description: "Поиск эмоджи"

        SettingSwitch {
            checked: page.launcher.commandEmoji
            onToggled: checked => page.launcher.commandEmoji = checked
        }
    }

    SettingRow {
        title: "Команда «/web»"
        description: "Поиск в интернете"

        SettingSwitch {
            checked: page.launcher.commandWeb
            onToggled: checked => page.launcher.commandWeb = checked
        }
    }
}
