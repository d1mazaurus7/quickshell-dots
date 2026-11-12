pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Рабочие столы»: Config.options.workspaces
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var workspaces: Config.options.workspaces

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Рабочие столы"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Нумерация рабочих столов"
        description: "Номер стола в каждой ячейке бара"

        SettingSwitch {
            checked: page.workspaces.showNumbers
            onToggled: checked => page.workspaces.showNumbers = checked
        }
    }

    SettingRow {
        title: "Прятать пустые рабочие столы"
        description: "Не показывать столы, на которых нет окон"

        SettingSwitch {
            checked: page.workspaces.hideEmpty
            onToggled: checked => page.workspaces.hideEmpty = checked
        }
    }

    SettingRow {
        shown: !page.workspaces.hideEmpty
        child: true
        title: "Максимальное кол-во видимых рабочих столов"
        description: "Бар дополняется ячейками до этого количества, активный всегда виден"

        SettingSlider {
            value: page.workspaces.maxVisible
            from: 2
            to: 12
            stepSize: 1
            formatValue: v => String(Math.round(v))
            onMoved: value => page.workspaces.maxVisible = Math.round(value)
        }
    }

    SettingRow {
        // Раскрытый список рисуется поверх следующих пунктов
        z: styleDropdown.expanded ? 1 : 0
        title: "Стиль"
        description: "Форма ячеек рабочих столов"

        SettingDropdown {
            id: styleDropdown
            model: ["Круги", "Квадраты"]
            popupHeight: Tokens.scaled(96)
            currentValue: page.workspaces.style === "squares" ? "Квадраты" : "Круги"
            onActivated: value => page.workspaces.style = value === "Квадраты" ? "squares" : "circles"
        }
    }
}
