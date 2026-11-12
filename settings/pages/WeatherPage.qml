pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Погода»: Config.options.weather
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var weather: Config.options.weather

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Погода"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Прогноз на дни вперёд"
        description: "Сколько дней показывать в прогнозе"

        SettingSlider {
            from: 1
            to: 7
            stepSize: 1
            value: page.weather.days
            formatValue: v => Math.round(v) + " дн."
            onMoved: value => page.weather.days = Math.round(value)
        }
    }

    SettingRow {
        title: "Почасовой прогноз"
        description: "Температура и погода по часам на сутки"

        SettingSwitch {
            checked: page.weather.hourly
            onToggled: checked => page.weather.hourly = checked
        }
    }

    SettingRow {
        title: "Динамический фон"
        description: "Фон карточки меняется по времени суток и погоде"

        SettingSwitch {
            checked: page.weather.dynamicBackground
            onToggled: checked => page.weather.dynamicBackground = checked
        }
    }

    SettingRow {
        title: "Фон на всё окно"
        description: "Динамический фон под всем окном, а не только под текущей погодой"
        shown: page.weather.dynamicBackground
        child: true

        SettingSwitch {
            checked: page.weather.fullBackground
            onToggled: checked => page.weather.fullBackground = checked
        }
    }

    SettingRow {
        title: "Блюр фона карточек"
        description: "Прозрачные карточки размывают динамический фон под собой"
        shown: page.weather.dynamicBackground && page.weather.fullBackground
        depth: 2

        SettingSwitch {
            checked: page.weather.blur
            onToggled: checked => page.weather.blur = checked
        }
    }

    SettingRow {
        title: "Обводка карточек"
        description: "Тонкая светлая рамка у полупрозрачных карточек"
        shown: page.weather.dynamicBackground && page.weather.fullBackground && page.weather.blur
        depth: 3

        SettingSwitch {
            checked: page.weather.borders
            onToggled: checked => page.weather.borders = checked
        }
    }

    SettingRow {
        title: "Капли дождя"
        description: "Капли на стекле окна во время дождя: стекают и преломляют фон"
        shown: page.weather.dynamicBackground && page.weather.fullBackground
        depth: 2

        SettingSwitch {
            checked: page.weather.raindrops
            onToggled: checked => page.weather.raindrops = checked
        }
    }

    SettingRow {
        title: "Слой капель"
        description: "Под карточками или поверх всего окна — тогда капли преломляют и текст"
        shown: page.weather.dynamicBackground && page.weather.fullBackground && page.weather.raindrops
        depth: 3
        z: raindropsLayer.expanded ? 1 : 0

        SettingDropdown {
            id: raindropsLayer
            readonly property var labels: ({ under: "Под карточками", over: "Поверх всего" })
            model: ["Под карточками", "Поверх всего"]
            popupHeight: Tokens.scaled(100)
            currentValue: labels[page.weather.raindropsLayer] ?? "Под карточками"
            onActivated: value => page.weather.raindropsLayer = value === "Поверх всего" ? "over" : "under"
        }
    }

    SettingRow {
        title: "Дождь как из ведра!"
        description: "Очень много стекающих капель при любой погоде"
        shown: page.weather.dynamicBackground && page.weather.fullBackground && page.weather.raindrops
        depth: 3

        SettingSwitch {
            checked: page.weather.downpour
            onToggled: checked => page.weather.downpour = checked
        }
    }

    SettingRow {
        title: "Стиль значков погоды"
        description: "Цветные — разноцветные градиенты, Material You — цвета палитры"
        z: iconStyle.expanded ? 1 : 0

        SettingDropdown {
            id: iconStyle
            readonly property var labels: ({ colored: "Цветные", material: "Material You" })
            model: ["Цветные", "Material You"]
            popupHeight: Tokens.scaled(100)
            currentValue: labels[page.weather.iconStyle] ?? "Material You"
            onActivated: value => page.weather.iconStyle = value === "Цветные" ? "colored" : "material"
        }
    }

    SettingRow {
        title: "Увеличить масштаб"
        description: "Крупнее окно, текст и значки (×1.25)"

        SettingSwitch {
            checked: page.weather.zoom
            onToggled: checked => page.weather.zoom = checked
        }
    }

    SettingRow {
        title: "Автоопределение местоположения"
        description: "Определять город по IP-адресу"

        SettingSwitch {
            checked: page.weather.autoLocation
            onToggled: checked => page.weather.autoLocation = checked
        }
    }

    SettingRow {
        title: "Город"
        description: "Для прогноза без автоопределения"
        shown: !page.weather.autoLocation
        child: true

        SettingTextField {
            value: page.weather.city
            placeholder: "Москва"
            onEdited: text => page.weather.city = text.trim()
        }
    }

    SettingRow {
        title: "Период обновления"
        description: "Как часто запрашивать погоду"

        SettingSlider {
            from: 10
            to: 180
            stepSize: 10
            value: page.weather.refreshInterval
            formatValue: v => Math.round(v) + " мин"
            onMoved: value => page.weather.refreshInterval = Math.round(value)
        }
    }
}
