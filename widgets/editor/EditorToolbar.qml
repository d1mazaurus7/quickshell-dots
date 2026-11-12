pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"
import "../../shell/config"
import "../../settings/controls" as SettingControls
import "../controls"
import ".."

// Панель редактора: добавить, переместить, настроить, сетка
Rectangle {
    id: root

    required property WidgetsState widgets

    signal addRequested(string type)

    readonly property var colors: Tokens.colors
    readonly property int pad: Tokens.scaled(8)
    readonly property bool hasSelection: widgets.selected !== null

    width: row.implicitWidth + pad * 2
    height: row.implicitHeight + pad * 2
    radius: Tokens.radius(Tokens.scaled(12) + pad)
    color: colors.surface_container
    border.width: Tokens.borderWidth
    border.color: colors.outline_variant

    // Клики по подложке не снимают выделение
    MouseArea { anchors.fill: parent }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacingSmall

        IconButton {
            icon: "add"
            checked: root.widgets.addOpen
            onClicked: root.widgets.addOpen = !root.widgets.addOpen
        }

        Expander {
            anchors.verticalCenter: parent.verticalCenter
            open: root.widgets.addOpen

            Repeater {
                model: root.widgets.addableTypes

                TextButton {
                    required property var modelData
                    icon: modelData.icon
                    text: modelData.title
                    onClicked: root.addRequested(modelData.type)
                }
            }
        }

        IconButton {
            icon: "edit"
            enabled: root.hasSelection
            checked: root.widgets.moveMode
            onClicked: root.widgets.moveMode = !root.widgets.moveMode
        }

        IconButton {
            icon: "settings"
            enabled: root.hasSelection
            checked: root.widgets.settingsOpen
            onClicked: root.widgets.settingsOpen = !root.widgets.settingsOpen
        }

        IconButton {
            icon: "grid_on"
            checked: root.widgets.cfg.grid
            onClicked: Config.options.widgets.grid = !root.widgets.cfg.grid
        }

        Expander {
            anchors.verticalCenter: parent.verticalCenter
            open: root.widgets.cfg.grid

            Item { width: Tokens.spacingSmall; height: 1 }

            SettingControls.SettingSlider {
                anchors.verticalCenter: parent.verticalCenter
                from: 10
                to: 160
                stepSize: 5
                value: root.widgets.cfg.gridSize
                sliderWidth: Tokens.scaled(140)
                formatValue: v => Math.round(v) + " px"
                onDragged: v => root.widgets.gridLive = v
                onMoved: v => {
                    Config.options.widgets.gridSize = Math.round(v);
                    root.widgets.gridLive = 0;
                }
            }
        }
    }
}
