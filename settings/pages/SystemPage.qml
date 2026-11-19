pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Система»: Config.options.system
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var sys: Config.options.system
    readonly property var ranges: [60, 300, 900, 1800, 3600]
    readonly property var rangeNames: ["1 мин", "5 мин", "15 мин", "30 мин", "1 час"]

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Система"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Период опроса"
        description: "Как часто обновляются датчики"

        SettingSlider {
            from: 500
            to: 5000
            stepSize: 250
            value: page.sys.interval
            formatValue: v => (v / 1000).toFixed(2) + " с"
            onMoved: value => page.sys.interval = Math.round(value)
        }
    }

    SettingRow {
        title: "Отрезок графиков"
        description: "Меняется и в самом окне"

        SettingSlider {
            from: 0
            to: 4
            stepSize: 1
            value: Math.max(0, page.ranges.indexOf(page.sys.range))
            formatValue: v => page.rangeNames[Math.round(v)]
            onMoved: value => page.sys.range = page.ranges[Math.round(value)]
        }
    }

    SettingRow {
        title: "История в фоне"
        description: "Копить графики, пока окно закрыто"

        SettingSwitch {
            checked: page.sys.backgroundHistory
            onToggled: checked => page.sys.backgroundHistory = checked
        }
    }

    SettingRow {
        title: "Фигуры на фоне"

        SettingSwitch {
            checked: page.sys.shapes
            onToggled: checked => page.sys.shapes = checked
        }
    }

    SettingRow {
        title: "Затемнение экрана"

        SettingSwitch {
            checked: page.sys.scrim
            onToggled: checked => page.sys.scrim = checked
        }
    }

    SettingRow {
        title: "Сглаженные графики"

        SettingSwitch {
            checked: page.sys.smoothGraphs
            onToggled: checked => page.sys.smoothGraphs = checked
        }
    }

    SettingRow {
        title: "Подсказка на графике"
        description: "Значения под курсором"

        SettingSwitch {
            checked: page.sys.graphTooltip
            onToggled: checked => page.sys.graphTooltip = checked
        }
    }

    SettingRow {
        title: "Ширина окна"

        SettingSlider {
            from: 900
            to: 1800
            stepSize: 10
            value: page.sys.width
            formatValue: v => Math.round(v)
            onMoved: value => page.sys.width = Math.round(value)
        }
    }

    SettingRow {
        title: "Высота окна"

        SettingSlider {
            from: 640
            to: 1200
            stepSize: 10
            value: page.sys.height
            formatValue: v => Math.round(v)
            onMoved: value => page.sys.height = Math.round(value)
        }
    }
}
