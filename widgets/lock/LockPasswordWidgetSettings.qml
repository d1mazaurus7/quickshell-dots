import QtQuick
import "../../shell/theme"
import "../controls"
import "../../settings/controls" as SettingsControls

Column {
    id: root

    property var settings: ({})
    signal settingChanged(string key, var value)

    spacing: Tokens.spacingMediumV

    ChoiceRow {
        width: parent.width
        text: "Фон"
        options: [{ value: "filled", label: "Заливка" }, { value: "outline", label: "Контур" }, { value: "glass", label: "Стекло" }]
        value: root.settings.style
        onSelected: v => root.settingChanged("style", v)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.style === "glass"

        SliderRow {
            width: parent.width
            text: "Плотность стекла"
            from: 0; to: 1; stepSize: 0.05
            formatValue: v => Math.round(v * 100) + "%"
            value: root.settings.glassOpacity
            onMoved: v => root.settingChanged("glassOpacity", v)
        }
    }
    SliderRow {
        width: parent.width
        text: "Закругление"
        from: 0; to: 1; stepSize: 0.05
        formatValue: v => Math.round(v * 100) + "%"
        value: root.settings.radius
        onMoved: v => root.settingChanged("radius", v)
    }
    SliderRow {
        width: parent.width
        text: "Обводка"
        from: 0; to: 6; stepSize: 1
        formatValue: v => Math.round(v) + " px"
        value: root.settings.borderWidth
        onMoved: v => root.settingChanged("borderWidth", Math.round(v))
    }
    SliderRow {
        width: parent.width
        text: "Прозрачность"
        from: 0.2; to: 1; stepSize: 0.05
        formatValue: v => Math.round(v * 100) + "%"
        value: root.settings.opacity
        onMoved: v => root.settingChanged("opacity", v)
    }
    ToggleRow {
        width: parent.width
        text: "Значок замка"
        checked: root.settings.showIcon === true
        onToggled: c => root.settingChanged("showIcon", c)
    }
    ToggleRow {
        width: parent.width
        text: "Кнопка входа"
        checked: root.settings.showButton === true
        onToggled: c => root.settingChanged("showButton", c)
    }
    ToggleRow {
        width: parent.width
        text: "Текст внутри"
        checked: root.settings.showHint === true
        onToggled: c => root.settingChanged("showHint", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.showHint === true

        Text {
            width: parent.width
            text: "Подсказка (%u — имя пользователя)"
            color: Tokens.colors.on_surface_variant
            font: Tokens.fontSmall
        }
        SettingsControls.SettingTextField {
            width: parent.width
            value: root.settings.placeholder
            placeholder: "Введите пароль"
            onEdited: text => root.settingChanged("placeholder", text)
        }
        Text {
            width: parent.width
            text: "Текст без пароля"
            color: Tokens.colors.on_surface_variant
            font: Tokens.fontSmall
        }
        SettingsControls.SettingTextField {
            width: parent.width
            value: root.settings.anyKeyText
            placeholder: "Нажмите любую клавишу"
            onEdited: text => root.settingChanged("anyKeyText", text)
        }
    }
    Text {
        width: parent.width
        text: "Текст ошибки"
        color: Tokens.colors.on_surface_variant
        font: Tokens.fontSmall
    }
    SettingsControls.SettingTextField {
        width: parent.width
        value: root.settings.failText
        placeholder: "Неверный пароль"
        onEdited: text => root.settingChanged("failText", text)
    }
    ChoiceRow {
        width: parent.width
        text: "Выравнивание"
        options: [{ value: "left", label: "Слева" }, { value: "center", label: "Центр" }]
        value: root.settings.align
        onSelected: v => root.settingChanged("align", v)
    }
    SliderRow {
        width: parent.width
        text: "Размер текста"
        from: 0.2; to: 0.6; stepSize: 0.02
        formatValue: v => Math.round(v * 100) + "%"
        value: root.settings.textSize
        onMoved: v => root.settingChanged("textSize", v)
    }
    ToggleRow {
        width: parent.width
        text: "Жирный текст"
        checked: root.settings.boldText === true
        onToggled: c => root.settingChanged("boldText", c)
    }
    ToggleRow {
        width: parent.width
        text: "Белый текст"
        checked: root.settings.whiteText === true
        onToggled: c => root.settingChanged("whiteText", c)
    }
    ChoiceRow {
        width: parent.width
        text: "Точки"
        options: [{ value: "circle", label: "Круглые" }, { value: "square", label: "Квадратные" }]
        value: root.settings.dotShape
        onSelected: v => root.settingChanged("dotShape", v)
    }
    ToggleRow {
        width: parent.width
        text: "Встряхивание при ошибке"
        checked: root.settings.shake === true
        onToggled: c => root.settingChanged("shake", c)
    }
    ToggleRow {
        width: parent.width
        text: "Скрывать при бездействии"
        checked: root.settings.hideOnIdle === true
        onToggled: c => root.settingChanged("hideOnIdle", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.hideOnIdle === true

        SliderRow {
            width: parent.width
            text: "Через"
            from: 2; to: 120; stepSize: 1
            formatValue: v => Math.round(v) + " с"
            value: root.settings.idleDelay
            onMoved: v => root.settingChanged("idleDelay", Math.round(v))
        }
    }
}
