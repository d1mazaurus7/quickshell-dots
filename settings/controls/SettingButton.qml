import QtQuick
import Quickshell
import "../../shell/theme"

// Кнопка действия: text — подпись, clicked() — действие выполняет страница
Rectangle {
    id: root

    property string text
    property string icon: ""

    readonly property var colors: Tokens.colors

    signal clicked

    implicitWidth: content.implicitWidth + Tokens.spacingLarge * 2
    implicitHeight: Tokens.scaled(36)
    radius: height / 2
    color: area.pressed ? colors.surface_container_highest
         : area.containsMouse ? colors.surface_container_high
         : colors.secondary_container
    scale: area.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Tokens.spacingSmall

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.colors.on_secondary_container
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(18)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.colors.on_secondary_container
            font: Tokens.fontMedium
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/sfx.wav")]);
            root.clicked();
        }
    }
}
