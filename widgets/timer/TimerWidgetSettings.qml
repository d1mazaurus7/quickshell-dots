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
        text: "Прозрачный фон"
        checked: root.settings.transparentBackground === true
        onToggled: c => root.settingChanged("transparentBackground", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.transparentBackground === true

        ToggleRow {
            width: parent.width
            text: "Обводка кнопок"
            checked: root.settings.outline === true
            onToggled: c => root.settingChanged("outline", c)
        }
        ToggleRow {
            width: parent.width
            text: "Блюр фона"
            checked: root.settings.backgroundBlur === true
            onToggled: c => root.settingChanged("backgroundBlur", c)
        }
    }
    ToggleRow {
        width: parent.width
        text: "Белый текст"
        checked: root.settings.whiteText === true
        onToggled: c => root.settingChanged("whiteText", c)
    }
    ToggleRow {
        width: parent.width
        text: "Плавная смена цифр"
        checked: root.settings.smoothChange === true
        onToggled: c => root.settingChanged("smoothChange", c)
    }
    ToggleRow {
        width: parent.width
        text: "Мигающий разделитель"
        checked: root.settings.blinkSeparator === true
        onToggled: c => root.settingChanged("blinkSeparator", c)
    }
    ToggleRow {
        width: parent.width
        text: "Секунды"
        checked: root.settings.showSeconds === true
        onToggled: c => root.settingChanged("showSeconds", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.showSeconds === true

        ToggleRow {
            width: parent.width
            text: "Миллисекунды"
            checked: root.settings.showMilliseconds === true
            onToggled: c => root.settingChanged("showMilliseconds", c)
        }
    }
}
