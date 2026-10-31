pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Секундомер»: Config.options.stopwatch
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var stopwatch: Config.options.stopwatch

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Секундомер"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        // Раскрытый список рисуется поверх следующих пунктов
        z: sideDropdown.expanded ? 1 : 0
        title: "Появление"
        description: "С какой стороны экрана выезжает окно"

        SettingDropdown {
            id: sideDropdown
            model: ["Справа", "Слева"]
            popupHeight: Tokens.scaled(96)
            currentValue: page.stopwatch.side === "left" ? "Слева" : "Справа"
            onActivated: value => page.stopwatch.side = value === "Слева" ? "left" : "right"
        }
    }

    SettingRow {
        title: "Виджет в баре"
        description: "Показывать кнопку в баре, пока секундомер запущен"

        SettingSwitch {
            checked: page.stopwatch.barWidget
            onToggled: checked => page.stopwatch.barWidget = checked
        }
    }

    SettingRow {
        visible: page.stopwatch.barWidget
        title: "Мигающий значок"
        description: "Значок плавно мигает, пока секундомер идёт"

        SettingSwitch {
            checked: page.stopwatch.blinkIcon
            onToggled: checked => page.stopwatch.blinkIcon = checked
        }
    }

    SettingRow {
        visible: page.stopwatch.barWidget
        title: "Значок"
        description: "Любой символ или эмодзи; пусто — без значка"

        Rectangle {
            implicitWidth: Tokens.scaled(96)
            implicitHeight: iconInput.implicitHeight + Tokens.spacingMediumV * 2
            radius: height / 2
            color: page.colors.surface_container_highest
            border.width: iconInput.activeFocus ? 1 : 0
            border.color: page.colors.primary

            TextInput {
                id: iconInput
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacingLarge
                anchors.rightMargin: Tokens.spacingLarge
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                clip: true
                text: page.stopwatch.icon
                color: page.colors.on_surface
                selectionColor: page.colors.primary
                selectedTextColor: page.colors.on_primary
                font: Tokens.fontMedium
                // Пишем в файл с задержкой, а не на каждый символ
                onTextEdited: iconSave.restart()
                onEditingFinished: iconSave.triggered()
            }

            Timer {
                id: iconSave
                interval: 400
                onTriggered: {
                    stop();
                    if (page.stopwatch.icon !== iconInput.text)
                        page.stopwatch.icon = iconInput.text;
                }
            }
        }
    }
}
