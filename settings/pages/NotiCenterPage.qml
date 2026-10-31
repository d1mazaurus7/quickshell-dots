pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Центр уведомлений»: Config.options.notiCenter (панель и её содержимое)
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var nc: Config.options.notiCenter

    spacing: Tokens.spacingMediumV

    component Subtitle: Text {
        Layout.topMargin: Tokens.spacingLargeV
        color: Tokens.colors.on_surface
        font: Tokens.fontLarge
    }

    component Toggle: SettingRow {
        id: toggle
        required property string key

        SettingSwitch {
            checked: Config.options.notiCenter[toggle.key]
            onToggled: checked => Config.options.notiCenter[toggle.key] = checked
        }
    }

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Центр уведомлений"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    Subtitle { Layout.topMargin: 0; text: "Панель" }

    SettingRow {
        title: "Ширина"
        description: "Ширина панели в пикселях"

        SettingSlider {
            from: 360
            to: 640
            stepSize: 10
            value: page.nc.width
            formatValue: v => Math.round(v) + " px"
            onMoved: value => { console.log("NCDBG slider moved", value); page.nc.width = Math.round(value); }
            onValueChanged: console.log("NCDBG slider value", value)
        }
    }

    SettingRow {
        title: "Высота"
        description: "Доля доступной высоты экрана"

        SettingSlider {
            from: 0.4
            to: 1
            stepSize: 0.05
            value: page.nc.heightRatio
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.nc.heightRatio = value
        }
    }

    Toggle {
        key: "uiSounds"
        title: "Звуки нажатий"
        description: "Щелчки при нажатии кнопок и плиток"
    }

    Subtitle { text: "Часы" }

    Toggle {
        key: "showClock"
        title: "Время"
        description: "Часы в верхней части панели"
    }

    Toggle {
        key: "showSeconds"
        shown: page.nc.showClock
        child: true
        title: "Секунды"
        description: "Показывать секунды"
    }

    Toggle {
        key: "showDate"
        shown: page.nc.showClock
        child: true
        title: "Дата"
        description: "Число, месяц и год под временем"
    }

    Toggle {
        key: "showWeekday"
        shown: page.nc.showClock
        child: true
        title: "День недели"
        description: "Сокращённый день недели справа"
    }

    Subtitle { text: "Быстрые настройки" }

    Toggle {
        key: "showWifi"
        title: "Wi-Fi"
        description: "Плитка Wi-Fi со списком сетей"
    }

    Toggle {
        key: "showBluetooth"
        title: "Bluetooth"
        description: "Плитка Bluetooth со списком устройств"
    }

    Toggle {
        key: "showDnd"
        title: "Не беспокоить"
        description: "Плитка режима «Не беспокоить»"
    }

    Toggle {
        key: "showBrightness"
        title: "Яркость"
        description: "Ползунок яркости монитора (ddcutil)"
    }

    Toggle {
        key: "showVolume"
        title: "Громкость"
        description: "Ползунок громкости звука"
    }

    Subtitle { text: "Карточки уведомлений" }

    SettingRow {
        title: "Строк текста"
        description: "Сколько строк текста показывать в карточке"

        SettingSlider {
            from: 1
            to: 10
            stepSize: 1
            value: page.nc.bodyLines
            formatValue: v => Math.round(v)
            onMoved: value => page.nc.bodyLines = Math.round(value)
        }
    }

    Toggle {
        key: "showActions"
        title: "Кнопки действий"
        description: "Кнопки из уведомлений, например «Пометить прочитанным»"
    }
}
