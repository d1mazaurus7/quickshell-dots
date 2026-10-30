pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Интерфейс»: Config.options.appearance
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var appearance: Config.options.appearance
    readonly property var snow: Config.options.snow

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Интерфейс"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Масштаб"
        description: "Размеры элементов, шрифтов и отступов"

        SettingSlider {
            from: 0.5
            to: 2
            stepSize: 0.05
            value: page.appearance.scale
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.appearance.scale = value
        }
    }

    SettingRow {
        title: "Горизонтальный отступ"
        description: "Отступы между элементами и от края окна по горизонтали"

        SettingSlider {
            from: 0
            to: 3
            stepSize: 0.1
            value: page.appearance.spacingHorizontal
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.appearance.spacingHorizontal = value
        }
    }

    SettingRow {
        title: "Вертикальный отступ"
        description: "Отступы между элементами и от края окна по вертикали"

        SettingSlider {
            from: 0
            to: 3
            stepSize: 0.1
            value: page.appearance.spacingVertical
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.appearance.spacingVertical = value
        }
    }

    SettingRow {
        title: "Скругление"
        description: "Масштаб скругления углов всех элементов"

        SettingSlider {
            from: 0
            to: 2
            stepSize: 0.05
            value: page.appearance.radiusScale
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.appearance.radiusScale = value
        }
    }

    SettingRow {
        title: "Обводка"
        description: "Рамка вокруг панелей и полей"

        SettingSwitch {
            checked: page.appearance.borders
            onToggled: checked => page.appearance.borders = checked
        }
    }

    Text {
        Layout.topMargin: Tokens.spacingLargeV
        text: "Снег"
        color: page.colors.on_surface
        font: Tokens.fontLarge
    }

    SettingRow {
        title: "Снегопад"
        description: "Снег и сугроб на рабочем столе"

        SettingSwitch {
            checked: page.snow.enabled
            onToggled: checked => page.snow.enabled = checked
        }
    }

    SettingRow {
        title: "Интенсивность"
        description: "Количество снежинок и скорость накопления"

        SettingSlider {
            from: 0.2
            to: 2
            stepSize: 0.1
            value: page.snow.intensity
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.snow.intensity = value
        }
    }

    SettingRow {
        title: "Скорость"
        description: "Скорость падения снежинок"

        SettingSlider {
            from: 0.3
            to: 3
            stepSize: 0.1
            value: page.snow.speed
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.snow.speed = value
        }
    }

    SettingRow {
        title: "Высота сугроба"
        description: "Максимальная высота сугроба"

        SettingSlider {
            from: 20
            to: 150
            stepSize: 5
            value: page.snow.driftHeight
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.snow.driftHeight = Math.round(value)
        }
    }

    SettingRow {
        title: "Прятать сугроб под окнами"
        description: "Скрывать нижний сугроб, когда на экране только тайловые окна"

        SettingSwitch {
            checked: page.snow.hideGroundWithTiled
            onToggled: checked => page.snow.hideGroundWithTiled = checked
        }
    }

    SettingRow {
        title: "Снег на окнах"
        description: "Снежные шапки на плавающих окнах"

        SettingSwitch {
            checked: page.snow.windowDrifts
            onToggled: checked => page.snow.windowDrifts = checked
        }
    }

    SettingRow {
        title: "Высота шапки"
        description: "Максимальная высота снега на окнах"

        SettingSlider {
            from: 5
            to: 80
            stepSize: 5
            value: page.snow.windowDriftHeight
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.snow.windowDriftHeight = Math.round(value)
        }
    }

    SettingRow {
        title: "Скругление шапки"
        description: "Насколько плавно снег спадает к краям окна"

        SettingSlider {
            from: 0
            to: 1
            stepSize: 0.05
            value: page.snow.capRounding
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.snow.capRounding = value
        }
    }

    SettingRow {
        title: "Стряхивание"
        description: "Сколько снега падает с окна при перемещении"

        SettingSlider {
            from: 0
            to: 1
            stepSize: 0.05
            value: page.snow.shakeOff
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.snow.shakeOff = value
        }
    }

    SettingRow {
        title: "Расчистка"
        description: "Расчищать сугроб зажатой левой кнопкой мыши"

        SettingSwitch {
            checked: page.snow.sweep
            onToggled: checked => page.snow.sweep = checked
        }
    }
}
