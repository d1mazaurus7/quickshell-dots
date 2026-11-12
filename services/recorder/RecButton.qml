import QtQuick
import Quickshell
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Кнопка-иконка M3E: при нажатии скругление уменьшается (смена формы)
Rectangle {
    id: button

    property string icon
    property bool checked: false
    property color baseColor: Theme.Palette.surface_container_high
    property color checkedColor: Theme.Palette.primary_container
    property color iconColor: checked ? Theme.Palette.on_primary_container : Theme.Palette.on_surface_variant
    signal clicked()

    implicitWidth: Tokens.scaled(36)
    implicitHeight: Tokens.scaled(36)
    radius: area.pressed ? Tokens.radiusMedium : checked ? Tokens.radiusLarge : height / 2
    color: area.pressed ? Qt.darker(checked ? checkedColor : baseColor, 1.12)
         : area.containsMouse ? Qt.lighter(checked ? checkedColor : baseColor, 1.12)
         : checked ? checkedColor : baseColor
    scale: area.pressed ? 0.94 : 1

    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

    RecIcon {
        anchors.centerIn: parent
        icon: button.icon
        color: button.iconColor
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Config.options.sound.interactionSounds)
                Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.clickSound)]);
            button.clicked();
        }
    }
}
