pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Переключатель вкладок: квадратные кнопки, выбранная скругляется в круг,
// выделение перетекает к ней. tabs: [{ id, icon }], current — id выбранной
Item {
    id: root

    property var tabs: []
    property string current
    property int size: Tokens.scaled(22)

    signal selected(string id)

    readonly property var colors: Tokens.colors
    readonly property int activeIndex: tabs.findIndex(t => t.id === current)
    readonly property Item activeItem: repeater.count > 0 && activeIndex >= 0 ? repeater.itemAt(activeIndex) : null

    implicitWidth: row.implicitWidth
    implicitHeight: size

    Row {
        id: row
        spacing: Tokens.spacingSmall

        Repeater {
            id: repeater
            model: root.tabs

            Rectangle {
                id: tab
                required property var modelData
                readonly property bool active: root.current === modelData.id

                width: root.size
                height: root.size
                radius: active ? height / 2 : Tokens.radius(Tokens.scaled(6))
                color: root.colors.surface_container_highest
                scale: tabArea.pressed ? 0.9 : 1
                Behavior on radius { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.colors.on_surface
                    opacity: tabArea.pressed ? 0.12 : tabArea.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                }

                MouseArea {
                    id: tabArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: WidgetSound.click()
                    onClicked: if (!tab.active) root.selected(tab.modelData.id)
                }
            }
        }
    }

    // Выделение над кнопками: переплывает к выбранной
    Rectangle {
        visible: root.activeItem !== null
        x: root.activeItem?.x ?? 0
        width: root.size
        height: root.size
        radius: height / 2
        color: root.colors.primary
        scale: root.activeItem?.scale ?? 1
        Behavior on x { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
    }

    // Значки поверх выделения
    Row {
        spacing: row.spacing
        enabled: false

        Repeater {
            model: root.tabs

            Text {
                required property var modelData
                width: root.size
                height: root.size
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData.icon
                color: root.current === modelData.id ? root.colors.on_primary : root.colors.on_surface_variant
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(root.size * 0.62)
                Behavior on color { ColorAnimation { duration: Tokens.animationSlow } }
            }
        }
    }
}
