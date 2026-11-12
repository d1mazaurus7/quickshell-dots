pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Управление питанием»: Config.options.powerMenu
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var power: Config.options.powerMenu

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Управление питанием"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Время удержания"
        description: "Сколько держать кнопку, пока она не заполнится"

        SettingSlider {
            from: 300
            to: 3000
            stepSize: 100
            value: page.power.holdTime
            formatValue: v => (v / 1000).toFixed(1) + " с"
            onMoved: value => page.power.holdTime = Math.round(value)
        }
    }

    SettingRow {
        title: "Выключение"

        SettingSwitch {
            checked: page.power.showPoweroff
            onToggled: checked => page.power.showPoweroff = checked
        }
    }

    SettingRow {
        title: "Перезагрузка"

        SettingSwitch {
            checked: page.power.showReboot
            onToggled: checked => page.power.showReboot = checked
        }
    }

    SettingRow {
        title: "Сон"

        SettingSwitch {
            checked: page.power.showSleep
            onToggled: checked => page.power.showSleep = checked
        }
    }

    SettingRow {
        title: "Выход из сессии"

        SettingSwitch {
            checked: page.power.showExit
            onToggled: checked => page.power.showExit = checked
        }
    }

    SettingRow {
        title: "Ширина окна"

        SettingSlider {
            from: 200
            to: 900
            stepSize: 10
            value: page.power.width
            formatValue: v => Math.round(v)
            onMoved: value => page.power.width = Math.round(value)
        }
    }

    SettingRow {
        title: "Высота окна"

        SettingSlider {
            from: 80
            to: 300
            stepSize: 10
            value: page.power.height
            formatValue: v => Math.round(v)
            onMoved: value => page.power.height = Math.round(value)
        }
    }

    SettingRow {
        title: "Подписи кнопок"
        description: "Название действия под кнопкой"

        SettingSwitch {
            checked: page.power.labels
            onToggled: checked => page.power.labels = checked
        }
    }
}
