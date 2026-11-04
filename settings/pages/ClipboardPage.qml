pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Буфер обмена»: Config.options.clipboard
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var cb: Config.options.clipboard

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Буфер обмена"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Количество записей"
        description: "Сколько последних копирований хранить"

        SettingSlider {
            from: 10
            to: 500
            stepSize: 10
            value: page.cb.maxItems
            formatValue: v => Math.round(v)
            onMoved: value => page.cb.maxItems = Math.round(value)
        }
    }

    SettingRow {
        title: "Картинки"
        description: "Сохранять скопированные изображения"

        SettingSwitch {
            checked: page.cb.images
            onToggled: checked => page.cb.images = checked
        }
    }

    SettingRow {
        title: "Запоминать между сессиями"
        description: "Историю видно после перезапуска оболочки"

        SettingSwitch {
            checked: page.cb.persist
            onToggled: checked => page.cb.persist = checked
        }
    }

    SettingRow {
        title: "Документы"
        description: "Хранить ссылки на скопированные файлы"

        SettingSwitch {
            checked: page.cb.documents
            onToggled: checked => page.cb.documents = checked
        }
    }

    SettingRow {
        title: "Ширина окна"

        SettingSlider {
            from: 300
            to: 1400
            stepSize: 10
            value: page.cb.width
            formatValue: v => Math.round(v)
            onMoved: value => page.cb.width = Math.round(value)
        }
    }

    SettingRow {
        title: "Высота окна"

        SettingSlider {
            from: 200
            to: 1000
            stepSize: 10
            value: page.cb.height
            formatValue: v => Math.round(v)
            onMoved: value => page.cb.height = Math.round(value)
        }
    }

    SettingRow {
        title: "Записей на странице"
        description: "Сколько записей видно без прокрутки"

        SettingSlider {
            from: 3
            to: 15
            stepSize: 1
            value: page.cb.pageItems
            formatValue: v => Math.round(v)
            onMoved: value => page.cb.pageItems = Math.round(value)
        }
    }
}
