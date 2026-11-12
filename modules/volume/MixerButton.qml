import QtQuick
import Quickshell
import "../../shell/config"
import "../../shell/theme"

// Кнопка микшера: звук нажатия из Config.options.sound.clickSound
Rectangle {
    id: root

    property string text
    readonly property alias pressed: area.pressed
    readonly property var colors: Tokens.colors

    signal clicked()

    radius: Tokens.radiusMedium
    color: area.pressed ? colors.secondary_container
         : area.containsMouse ? colors.surface_bright
         : colors.surface_container_highest
    Behavior on color { ColorAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

    Text {
        anchors.fill: parent
        anchors.leftMargin: Tokens.spacingMedium
        anchors.rightMargin: Tokens.spacingMedium
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.text
        elide: Text.ElideRight
        color: area.pressed ? root.colors.on_secondary_container : root.colors.on_surface
        font: Tokens.fontSmall
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: if (Config.options.sound.interactionSounds)
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.clickSound)])
        onClicked: root.clicked()
    }
}
