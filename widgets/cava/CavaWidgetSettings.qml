import QtQuick
import "../../shell/theme"
import "../controls"

Column {
    id: root

    property var settings: ({})
    signal settingChanged(string key, var value)

    spacing: Tokens.spacingMediumV

    ToggleRow {
        width: parent.width
        text: "Переместить на слой ниже (под другие виджеты)"
        checked: root.settings.lower === true
        onToggled: c => root.settingChanged("lower", c)
    }
    ToggleRow {
        width: parent.width
        text: "Фон"
        checked: root.settings.background === true
        onToggled: c => root.settingChanged("background", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.background === true

        ToggleRow {
            width: parent.width
            text: "Размытие"
            checked: root.settings.blur === true
            onToggled: c => root.settingChanged("blur", c)
        }
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.background !== true

        ToggleRow {
            width: parent.width
            text: "Размытие под визуализатором"
            checked: root.settings.behindBlur === true
            onToggled: c => root.settingChanged("behindBlur", c)
        }
        ChildGroup {
            width: parent.width
            shown: root.settings.behindBlur === true

            ToggleRow {
                width: parent.width
                text: "Бесцветный визуализатор"
                checked: root.settings.colorless === true
                onToggled: c => root.settingChanged("colorless", c)
            }
        }
    }
    ToggleRow {
        width: parent.width
        text: "Свечение"
        checked: root.settings.glow === true
        onToggled: c => root.settingChanged("glow", c)
    }
    ChoiceRow {
        width: parent.width
        text: "Вид"
        options: [{ value: "wave", label: "Соединённый" }, { value: "bars", label: "Палочки" }]
        value: root.settings.style
        onSelected: v => root.settingChanged("style", v)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.style === "bars"

        SliderRow {
            width: parent.width
            text: "Палочек"
            from: 8; to: 128; stepSize: 1
            value: root.settings.barCount
            onMoved: v => root.settingChanged("barCount", Math.round(v))
        }
    }
}
