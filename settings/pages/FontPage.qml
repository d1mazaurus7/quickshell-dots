pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Шрифт»: Config.options.typography
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var typography: Config.options.typography

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Шрифт"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        // Раскрытый список рисуется поверх следующих пунктов
        z: familyDropdown.expanded ? 1 : 0
        title: "Семейство"
        description: "Основной шрифт интерфейса"

        SettingDropdown {
            id: familyDropdown
            model: Qt.fontFamilies()
            currentValue: page.typography.family
            searchable: true
            fontPreview: true
            onActivated: value => page.typography.family = value
        }
    }
}
