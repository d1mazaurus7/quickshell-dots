import QtQuick
import "../../shell/theme"

// Кнопка ленты новостей в баре: нажатие — openRequested() (окно открывает Shell.qml).
// Использование: NewsModule { barHeight: ...; active: <окно открыто> }
Item {
    id: root

    property real barHeight: 40
    // Окно новостей открыто — значок подсвечен
    property bool active: false

    signal openRequested

    readonly property var colors: Tokens.colors
    readonly property int buttonHeight: Math.max(0, barHeight - Tokens.scaled(6) * 2)

    implicitWidth: button.width
    implicitHeight: buttonHeight

    Rectangle {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        width: icon.implicitWidth + Tokens.spacingMedium * 2
        height: root.buttonHeight
        radius: Tokens.radiusMedium
        color: area.pressed ? root.colors.secondary_container
             : area.containsMouse || root.active ? root.colors.surface_bright
             : root.colors.surface_container_highest
        Behavior on color { ColorAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        Text {
            id: icon
            anchors.centerIn: parent
            text: "newspaper"
            color: area.pressed ? root.colors.on_secondary_container
                 : root.active ? root.colors.primary
                 : root.colors.on_surface
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(20)
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openRequested()
        }
    }
}
