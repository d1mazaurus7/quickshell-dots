import QtQuick
import "../shell/theme"

// Строка выбора приложения: иконка, название и отметка; clicked() — переключить выбор
Rectangle {
    id: root

    property string icon
    property string name
    property bool selected: false

    signal clicked()

    readonly property var colors: Tokens.colors

    implicitHeight: Tokens.scaled(44)
    radius: Tokens.radiusMedium
    color: area.pressed ? colors.surface_container_highest
         : area.containsMouse ? colors.surface_container_high
         : "transparent"
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

    AppIcon {
        id: appIcon
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        icon: root.icon
        name: root.name
        size: Tokens.scaled(28)
    }

    Text {
        anchors.left: appIcon.right
        anchors.right: check.left
        anchors.leftMargin: Tokens.spacingMedium
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        text: root.name
        color: root.colors.on_surface
        font: Tokens.fontMedium
        elide: Text.ElideRight
    }

    // Отметка выбора в стиле Material checkbox
    Rectangle {
        id: check
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.scaled(20)
        height: width
        radius: Tokens.radiusSmall
        color: root.selected ? root.colors.primary : "transparent"
        border.width: root.selected ? 0 : 2
        border.color: root.colors.outline
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: root.colors.on_primary
            font: Tokens.fontSmall
            scale: root.selected ? 1 : 0
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
