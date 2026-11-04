import QtQuick
import "../../shell/theme"
import "../controls"

Column {
    id: root

    property var settings: ({})
    signal settingChanged(string key, var value)

    spacing: Tokens.spacingMediumV

    ChoiceRow {
        width: parent.width
        text: "Вид"
        options: [{ value: "full", label: "Полный" }, { value: "vertical", label: "Вертикальный" }]
        value: root.settings.layout
        onSelected: v => root.settingChanged("layout", v)
    }
    ChoiceRow {
        width: parent.width
        text: "Смещение"
        options: [{ value: "left", label: "Слева" }, { value: "center", label: "Центр" }, { value: "right", label: "Справа" }]
        value: root.settings.align
        onSelected: v => root.settingChanged("align", v)
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
            text: "Мелькающий разделитель"
            checked: root.settings.blinkSeparator === true
            onToggled: c => root.settingChanged("blinkSeparator", c)
        }
    }
    ToggleRow {
        width: parent.width
        text: "Блюр текста"
        checked: root.settings.textBlur === true
        onToggled: c => root.settingChanged("textBlur", c)
    }
    ToggleRow {
        width: parent.width
        text: "Белый текст"
        checked: root.settings.whiteText === true
        onToggled: c => root.settingChanged("whiteText", c)
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
            text: "Блюр фона"
            checked: root.settings.backgroundBlur === true
            onToggled: c => root.settingChanged("backgroundBlur", c)
        }
    }
}
