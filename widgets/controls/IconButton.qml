import QtQuick
import "../../shell/theme"

// Квадратная кнопка со значком Material Symbols; checked — скругляется до пилюли
Rectangle {
    id: root

    property string icon
    property bool checked: false
    property int size: Tokens.scaled(44)

    signal clicked()

    readonly property var colors: Tokens.colors

    implicitWidth: size
    implicitHeight: size
    radius: checked ? height / 2 : Tokens.radius(Tokens.scaled(12))
    color: checked ? colors.primary : colors.surface_container_highest
    opacity: enabled ? 1 : 0.38
    scale: area.pressed ? 0.94 : 1

    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

    // Слой состояния hover/pressed
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.checked ? root.colors.on_primary : root.colors.on_surface
        opacity: area.pressed ? 0.12 : area.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        color: root.checked ? root.colors.on_primary : root.colors.on_surface
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.round(root.size * 0.5)
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: WidgetSound.click()
        onClicked: root.clicked()
    }
}
