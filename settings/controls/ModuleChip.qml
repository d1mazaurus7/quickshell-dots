import QtQuick
import "../../shell/theme"

// Блок модуля, который можно зажать и перетащить в ModuleDropZone.
// Сам элемент — место в раскладке; при перетаскивании блок переносится в dragLayer.
Item {
    id: root

    property string moduleId
    property string title
    // Слой поверх страницы, где блок летит за курсором (без обрезки контейнерами)
    property Item dragLayer
    readonly property bool dragging: area.drag.active

    readonly property var colors: Tokens.colors

    implicitWidth: Math.max(Tokens.scaled(120), label.implicitWidth + Tokens.spacingLarge * 2)
    implicitHeight: label.implicitHeight + Tokens.spacingMediumV * 2

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: chip
        onReleased: chip.Drag.drop()

        Rectangle {
            id: chip
            width: root.width
            height: root.height
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            radius: Tokens.radiusMedium
            color: root.dragging ? root.colors.primary_container
                 : area.pressed ? root.colors.surface_container_highest
                 : area.containsMouse ? root.colors.surface_container_high
                 : root.colors.surface_bright
            border.width: Tokens.borderWidth
            border.color: root.colors.outline_variant
            scale: root.dragging ? 1.05 : 1
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            Drag.active: root.dragging
            Drag.source: root
            Drag.keys: ["barModule"]
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            Text {
                id: label
                anchors.centerIn: parent
                text: root.title
                color: root.dragging ? root.colors.on_primary_container : root.colors.on_surface
                font: Tokens.fontMedium
            }

            states: State {
                when: root.dragging
                ParentChange { target: chip; parent: root.dragLayer }
                AnchorChanges {
                    target: chip
                    anchors.horizontalCenter: undefined
                    anchors.verticalCenter: undefined
                }
            }
        }
    }
}
