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
        width: parent.width
        text: "Вкладка занятого ресурса"
        checked: root.settings.usageTab === true
        onToggled: c => root.settingChanged("usageTab", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.usageTab === true

        ToggleRow {
            width: parent.width
            text: "Волна"
            checked: root.settings.showWave === true
            onToggled: c => root.settingChanged("showWave", c)
        }
        ToggleRow {
            width: parent.width
            text: "Занято"
            checked: root.settings.showUsed === true
            onToggled: c => root.settingChanged("showUsed", c)
        }
        ToggleRow {
            width: parent.width
            text: "Свободно"
            checked: root.settings.showFree === true
            onToggled: c => root.settingChanged("showFree", c)
        }
    }

    ToggleRow {
        width: parent.width
        text: "Вкладка графика"
        checked: root.settings.graphTab === true
        onToggled: c => root.settingChanged("graphTab", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.graphTab === true

        DropdownRow {
            width: parent.width
            text: "Промежуток"
            options: [
                { value: 30, label: "30 секунд" },
                { value: 60, label: "1 минута" },
                { value: 120, label: "2 минуты" },
                { value: 300, label: "5 минут" },
                { value: 600, label: "10 минут" }
            ]
            value: root.settings.graphSpan
            onSelected: v => root.settingChanged("graphSpan", v)
        }
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
