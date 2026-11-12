import QtQuick
import "../../shell/theme"
import "../controls"
import "../../settings/controls" as SettingsControls

Column {
    id: root

    property var settings: ({})
    signal settingChanged(string key, var value)

    spacing: Tokens.spacingMediumV

    ToggleRow {
        width: parent.width
        text: "Фото"
        checked: root.settings.showPhoto === true
        onToggled: c => root.settingChanged("showPhoto", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.showPhoto === true

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
            text: "Размер фото"
            from: 0.3; to: 1; stepSize: 0.05
            formatValue: v => Math.round(v * 100) + "%"
            value: root.settings.photoSize
            onMoved: v => root.settingChanged("photoSize", v)
        }
        SliderRow {
            width: parent.width
            text: "Непрозрачность"
            from: 0.2; to: 1; stepSize: 0.05
            formatValue: v => Math.round(v * 100) + "%"
            value: root.settings.photoOpacity
            onMoved: v => root.settingChanged("photoOpacity", v)
        }
        SliderRow {
            width: parent.width
            text: "Обводка"
            from: 0; to: 10; stepSize: 1
            formatValue: v => Math.round(v) + " px"
            value: root.settings.borderWidth
            onMoved: v => root.settingChanged("borderWidth", Math.round(v))
        }
        ChoiceRow {
            width: parent.width
            visible: root.settings.borderWidth > 0
            text: "Цвет обводки"
            options: [{ value: "primary", label: "Акцент" }, { value: "outline", label: "Контур" }, { value: "white", label: "Белый" }]
            value: root.settings.borderColor
            onSelected: v => root.settingChanged("borderColor", v)
        }
        ToggleRow {
            width: parent.width
            text: "Тень"
            checked: root.settings.shadow === true
            onToggled: c => root.settingChanged("shadow", c)
        }
        ImagePicker {
            width: parent.width
            folder: Qt.resolvedUrl("../../assets/photos")
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
            value: root.settings.photo
            onSelected: name => root.settingChanged("photo", name)
        }
    }
    ToggleRow {
        width: parent.width
        text: "Показывать ник"
        checked: root.settings.showName === true
        onToggled: c => root.settingChanged("showName", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.showName === true

        ChoiceRow {
            width: parent.width
            text: "Ник"
            options: [{ value: "user", label: "Системный" }, { value: "custom", label: "Свой" }]
            value: root.settings.nameSource
            onSelected: v => root.settingChanged("nameSource", v)
        }
        SettingsControls.SettingTextField {
            width: parent.width
            visible: root.settings.nameSource === "custom"
            value: root.settings.customName
            placeholder: "Свой ник"
            onEdited: text => root.settingChanged("customName", text)
        }
        SliderRow {
            width: parent.width
            text: "Размер ника"
            from: 10; to: 64; stepSize: 1
            formatValue: v => Math.round(v) + " px"
            value: root.settings.nameSize
            onMoved: v => root.settingChanged("nameSize", Math.round(v))
        }
        ToggleRow {
            width: parent.width
            text: "Жирный"
            checked: root.settings.nameBold === true
            onToggled: c => root.settingChanged("nameBold", c)
        }
    }
    Text {
        width: parent.width
        text: "Подпись под ником (%u — ник, пусто — нет)"
        color: Tokens.colors.on_surface_variant
        font: Tokens.fontSmall
    }
    SettingsControls.SettingTextField {
        width: parent.width
        value: root.settings.subtitle
        placeholder: "Например: С возвращением, %u"
        onEdited: text => root.settingChanged("subtitle", text)
    }
    ChoiceRow {
        width: parent.width
        text: "Текст"
        options: [{ value: "below", label: "Под фото" }, { value: "above", label: "Над фото" }]
        value: root.settings.namePosition
        onSelected: v => root.settingChanged("namePosition", v)
    }
    SliderRow {
        width: parent.width
        text: "Отступ текста"
        from: 0; to: 48; stepSize: 1
        formatValue: v => Math.round(v) + " px"
        value: root.settings.nameGap
        onMoved: v => root.settingChanged("nameGap", Math.round(v))
    }
    ToggleRow {
        width: parent.width
        text: "Белый текст"
        checked: root.settings.whiteText === true
        onToggled: c => root.settingChanged("whiteText", c)
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
