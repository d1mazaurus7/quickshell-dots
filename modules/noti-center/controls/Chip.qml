import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"
import "Icons.js" as Icons

// Ассист-чип MD3: иконка, подпись, «+» справа.
Rectangle {
    id: chip

    required property real s
    property string icon
    property string text

    signal clicked()

    height: 36 * s
    width: row.implicitWidth + 24 * s
    radius: area.pressed ? 8 * s : 12 * s
    color: Theme.Palette.surface_container_high
    border.width: 1
    border.color: Theme.Palette.outline_variant
    Behavior on radius { Emphasized {} }

    StateLayer {
        radius: chip.radius
        color: Theme.Palette.on_surface
        hovered: area.containsMouse
        pressed: area.pressed
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8 * chip.s

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.icon
            size: 18 * chip.s
            color: Theme.Palette.primary
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: chip.text
            color: Theme.Palette.on_surface
            font.family: Tokens.typography.family
            font.pixelSize: Math.round(12 * chip.s)
        }
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.plus
            size: 16 * chip.s
            color: Theme.Palette.on_surface_variant
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
