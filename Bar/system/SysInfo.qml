pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Список «параметр: значение» с иконками, прокручивается при нехватке места.
// Строки не пересоздаются при обновлении значений
Flickable {
    id: root

    property var rows: []
    property int rowHeight: Tokens.scaled(30)
    readonly property var colors: Tokens.colors

    contentHeight: col.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        width: root.width

        Repeater {
            model: root.rows.length

            Item {
                id: line
                required property int index
                readonly property var row: root.rows[index] ?? {}

                width: root.width
                height: root.rowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.radius(10)
                    color: root.colors.on_surface
                    opacity: hover.hovered ? 0.06 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                }

                HoverHandler { id: hover }

                SysIcon {
                    id: ico
                    x: Tokens.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.scaled(22)
                    icon: line.row.icon ?? ""
                    size: Tokens.scaled(17)
                    filled: hover.hovered
                    hovered: hover.hovered
                    color: hover.hovered ? root.colors.primary : root.colors.on_surface_variant
                }

                SysText {
                    id: key
                    anchors.left: ico.right
                    anchors.leftMargin: Tokens.spacingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    text: line.row.label ?? ""
                    font: Tokens.fontMedium
                    color: root.colors.on_surface_variant
                }

                SysText {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - key.x - key.implicitWidth - Tokens.spacingLarge)
                    horizontalAlignment: Text.AlignRight
                    text: line.row.value ?? ""
                    font.family: Tokens.fontMedium.family
                    font.pixelSize: Tokens.fontMedium.pixelSize
                    font.weight: Font.Medium
                    color: root.colors.on_surface
                }
            }
        }
    }
}
