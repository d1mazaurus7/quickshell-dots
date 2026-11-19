import QtQuick
import "../../shell/theme"
import "../controls"

// Настройки виджета потребления (диск, RAM, CPU, GPU)
Column {
    id: root

    property var settings: ({})
    signal settingChanged(string key, var value)

    spacing: Tokens.spacingMediumV

    ToggleRow {
        visible: root.settings.kind === "ram" || root.settings.kind === "disk"
        width: parent.width
        text: "Занятый объём"
        checked: root.settings.showUsed === true
        onToggled: c => root.settingChanged("showUsed", c)
    }

    SliderRow {
        width: parent.width
        text: "Обновление"
        from: 250; to: 5000; stepSize: 250
        formatValue: v => (v / 1000).toFixed(2).replace(/\.?0+$/, "") + " с"
        value: root.settings.interval
        onMoved: v => root.settingChanged("interval", Math.round(v))
    }
}
