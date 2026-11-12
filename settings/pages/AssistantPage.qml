pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Ассистент»: Config.options.assistant
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var assistant: Config.options.assistant
    // Картинки из assets/img/avatars
    readonly property var avatars: {
        const list = [];
        for (let i = 0; i < avatarFiles.count; i++)
            list.push(avatarFiles.get(i, "fileName"));
        return list;
    }

    // Шаблоны промптов и модели: имя файла без .txt → содержимое
    property var templates: ({})
    property var models: ({})
    readonly property var templateNames: page.txtNames(templateFiles)
    readonly property var modelNames: page.txtNames(modelFiles)
    readonly property string currentTemplate: templateNames.find(n => (templates[n] ?? "").trim() === assistant.systemPrompt.trim()) ?? ""
    readonly property string currentModel: modelNames.find(n => models[n] === assistant.model) ?? ""

    function txtNames(files: FolderListModel): var {
        const list = [];
        for (let i = 0; i < files.count; i++)
            list.push(files.get(i, "fileName").replace(/\.txt$/, ""));
        return list;
    }

    spacing: Tokens.spacingMediumV

    FolderListModel {
        id: templateFiles
        folder: "file://" + Quickshell.shellPath("Bar/assistant/templates")
        nameFilters: ["*.txt"]
        showDirs: false
    }

    FolderListModel {
        id: modelFiles
        folder: "file://" + Quickshell.shellPath("Bar/assistant/models")
        nameFilters: ["*.txt"]
        showDirs: false
    }

    Instantiator {
        model: templateFiles
        delegate: FileView {
            required property string fileName
            required property string filePath
            path: filePath
            watchChanges: true
            onFileChanged: reload()
            onLoaded: page.templates = Object.assign({}, page.templates, { [fileName.replace(/\.txt$/, "")]: text() })
        }
    }

    Instantiator {
        model: modelFiles
        delegate: FileView {
            required property string fileName
            required property string filePath
            path: filePath
            watchChanges: true
            onFileChanged: reload()
            onLoaded: page.models = Object.assign({}, page.models, { [fileName.replace(/\.txt$/, "")]: text().trim() })
        }
    }

    FolderListModel {
        id: avatarFiles
        folder: "file://" + Quickshell.shellPath("assets/img/avatars")
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif"]
        showDirs: false
    }

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Ассистент"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Имя"
        description: "Имя ассистента в шапке чата"

        SettingTextField {
            value: page.assistant.name
            placeholder: "Ассистент"
            onEdited: text => page.assistant.name = text
        }
    }

    SettingRow {
        title: "Описание"
        description: "Подпись под именем"

        SettingTextField {
            value: page.assistant.description
            onEdited: text => page.assistant.description = text
        }
    }

    SettingRow {
        z: avatarDropdown.expanded ? 1 : 0
        title: "Аватар"
        description: "Файл из assets/img/avatars"

        Row {
            spacing: Tokens.spacingMedium

            ClippingRectangle {
                width: avatarDropdown.height
                height: width
                radius: width / 2
                color: page.colors.surface_container_highest

                Image {
                    anchors.fill: parent
                    visible: page.assistant.avatar !== ""
                    source: visible ? "file://" + Quickshell.shellPath("assets/img/avatars/" + page.assistant.avatar) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            SettingDropdown {
                id: avatarDropdown
                model: ["Нет"].concat(page.avatars)
                popupHeight: Tokens.scaled(220)
                currentValue: page.assistant.avatar === "" ? "Нет" : page.assistant.avatar
                onActivated: value => page.assistant.avatar = value === "Нет" ? "" : value
            }
        }
    }

    SettingRow {
        z: sideDropdown.expanded ? 1 : 0
        title: "Сторона"
        description: "Край экрана, от которого открывается окно"

        SettingDropdown {
            id: sideDropdown
            model: ["Слева", "Справа"]
            popupHeight: Tokens.scaled(96)
            currentValue: page.assistant.side === "right" ? "Справа" : "Слева"
            onActivated: value => page.assistant.side = value === "Справа" ? "right" : "left"
        }
    }

    SettingRow {
        title: "Ширина"
        description: "Ширина окна чата"

        SettingSlider {
            from: 300
            to: 800
            stepSize: 10
            value: page.assistant.width
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.assistant.width = Math.round(value)
        }
    }

    SettingRow {
        title: "Высота"
        description: "Доля высоты экрана под баром"

        SettingSlider {
            from: 0.4
            to: 1
            stepSize: 0.05
            value: page.assistant.heightRatio
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.assistant.heightRatio = value
        }
    }

    SettingRow {
        title: "Размер текста"
        description: "Текст сообщений, поля ввода и шапки"

        SettingSlider {
            from: 9
            to: 24
            stepSize: 1
            value: page.assistant.fontSize
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.assistant.fontSize = Math.round(value)
        }
    }

    SettingRow {
        z: templateDropdown.expanded ? 1 : 0
        title: "Шаблон промпта"
        description: "Файл из Bar/assistant/templates, текст заменяет системный промпт"

        SettingDropdown {
            id: templateDropdown
            model: page.templateNames
            popupHeight: Tokens.scaled(220)
            currentValue: page.currentTemplate
            onActivated: value => page.assistant.systemPrompt = page.templates[value] ?? ""
        }
    }

    // Системный промпт: поле на всю ширину
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: promptColumn.implicitHeight + Tokens.spacingLargeV * 2
        radius: Tokens.radiusLarge
        color: page.colors.surface_container

        ColumnLayout {
            id: promptColumn
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacingLarge
            anchors.rightMargin: Tokens.spacingLarge
            anchors.topMargin: Tokens.spacingLargeV
            anchors.bottomMargin: Tokens.spacingLargeV
            spacing: 2

            Text {
                text: "Системный промпт"
                color: page.colors.on_surface
                font: Tokens.fontMedium
            }

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacingMediumV
                text: "Инструкция, которую модель получает перед диалогом"
                color: page.colors.on_surface_variant
                font: Tokens.fontSmall
                wrapMode: Text.Wrap
            }

            SettingTextArea {
                Layout.fillWidth: true
                Layout.preferredHeight: Tokens.scaled(200)
                value: page.assistant.systemPrompt
                placeholder: "Ты — дружелюбный помощник…"
                onEdited: text => page.assistant.systemPrompt = text
            }
        }
    }

    Text {
        Layout.topMargin: Tokens.spacingMediumV
        text: "Модель"
        color: page.colors.on_surface
        font: Tokens.fontLarge
    }

    SettingRow {
        title: "Ключ API"
        description: "Ключ OpenRouter, хранится в settings.json"

        SettingTextField {
            value: page.assistant.apiKey
            placeholder: "sk-or-…"
            password: true
            onEdited: text => page.assistant.apiKey = text.trim()
        }
    }

    SettingRow {
        z: modelDropdown.expanded ? 1 : 0
        title: "Список моделей"
        description: "Файл из Bar/assistant/models с тегом модели"

        SettingDropdown {
            id: modelDropdown
            model: page.modelNames
            popupHeight: Tokens.scaled(220)
            searchable: true
            currentValue: page.currentModel
            onActivated: value => {
                if (page.models[value])
                    page.assistant.model = page.models[value];
            }
        }
    }

    SettingRow {
        title: "Модель"
        description: "Идентификатор модели OpenRouter"

        SettingTextField {
            value: page.assistant.model
            placeholder: "qwen/qwen-2.5-7b-instruct"
            onEdited: text => page.assistant.model = text.trim()
        }
    }

    SettingRow {
        title: "Температура"
        description: "Выше — ответы разнообразнее, ниже — точнее"

        SettingSlider {
            from: 0
            to: 2
            stepSize: 0.1
            value: page.assistant.temperature
            onMoved: value => page.assistant.temperature = value
        }
    }

    SettingRow {
        title: "Максимум токенов"
        description: "Ограничение длины ответа"

        SettingSlider {
            from: 128
            to: 4096
            stepSize: 128
            value: page.assistant.maxTokens
            formatValue: v => Math.round(v).toString()
            onMoved: value => page.assistant.maxTokens = Math.round(value)
        }
    }

    Text {
        Layout.topMargin: Tokens.spacingMediumV
        text: "Команды"
        color: page.colors.on_surface
        font: Tokens.fontLarge
    }

    SettingRow {
        title: "Новый чат"
        description: "Очищает историю и отменяет ожидаемый ответ"

        SettingTextField {
            value: page.assistant.clearCommand
            placeholder: "/clear"
            onEdited: text => page.assistant.clearCommand = text.trim()
        }
    }

    SettingRow {
        title: "Обновить подключение"
        description: "Проверяет ключ API и наличие модели в OpenRouter"

        SettingTextField {
            value: page.assistant.reloadCommand
            placeholder: "/reload"
            onEdited: text => page.assistant.reloadCommand = text.trim()
        }
    }

    SettingRow {
        title: "История чатов"
        description: "Список сохранённых чатов из Bar/assistant/history"

        SettingTextField {
            value: page.assistant.loadCommand
            placeholder: "/load"
            onEdited: text => page.assistant.loadCommand = text.trim()
        }
    }
}
