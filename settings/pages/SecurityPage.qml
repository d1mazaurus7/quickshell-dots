pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Безопасность»: Config.options.security
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var security: Config.options.security

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Безопасность"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Всплывающие уведомления"
        description: "Скрывать при записи экрана и на скриншотах"

        SettingSwitch {
            checked: page.security.hidePopups
            onToggled: checked => page.security.hidePopups = checked
        }
    }

    SettingAppList {
        title: "Защищённые программы"
        description: "Окна скрываются при записи экрана и на скриншотах"
        apps: page.security.protectedApps
        onEdited: apps => page.security.protectedApps = apps
    }
}
