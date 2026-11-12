pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Обои»: Config.options.wallpaper
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var wallpaper: Config.options.wallpaper

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Обои"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Пароль для обоев"
        description: "Вход в секретные обои по Alt+S в окне выбора"

        SettingTextField {
            value: page.wallpaper.password
            placeholder: "Не задан"
            password: true
            onEdited: text => page.wallpaper.password = text
        }
    }
}
