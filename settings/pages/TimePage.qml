pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Время»: Config.options.time
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var time: Config.options.time

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Время"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Секунды"
        description: "Показывать секунды"

        SettingSwitch {
            checked: page.time.showSeconds
            onToggled: checked => page.time.showSeconds = checked
        }
    }

    SettingRow {
        title: "Дата"
        description: "Показывать число и месяц"

        SettingSwitch {
            checked: page.time.showDate
            onToggled: checked => page.time.showDate = checked
        }
    }

    SettingRow {
        title: "День недели"
        description: "Показывать день недели"

        SettingSwitch {
            checked: page.time.showWeekday
            onToggled: checked => page.time.showWeekday = checked
        }
    }

    SettingRow {
        visible: page.time.showWeekday
        title: "Сокращённый день недели"
        description: "пн, вт, ср вместо полного названия"

        SettingSwitch {
            checked: page.time.shortWeekday
            onToggled: checked => page.time.shortWeekday = checked
        }
    }
}
