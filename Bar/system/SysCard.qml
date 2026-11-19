import QtQuick
import "../../shell/theme"

// Карточка раздела: заголовок с иконкой и слот содержимого
Rectangle {
    id: root

    property string icon
    property string title
    property string note
    default property alias content: slot.data
    readonly property var colors: Tokens.colors
    readonly property bool hovered: hover.hovered

    radius: Tokens.radius(24)
    color: Qt.alpha(hovered ? colors.surface_container_high : colors.surface_container, 0.92)
    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

    HoverHandler { id: hover }

    Row {
        id: head
        x: Tokens.spacingLarge
        y: Tokens.spacingLargeV
        height: Tokens.scaled(28)
        spacing: Tokens.spacingMedium

        Rectangle {
            width: parent.height
            height: parent.height
            radius: height / 2
            color: root.colors.primary_container

            SysIcon {
                anchors.centerIn: parent
                icon: root.icon
                size: Tokens.scaled(16)
                filled: root.hovered
                hovered: root.hovered
                color: root.colors.on_primary_container
            }
        }

        SysText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.family: Tokens.fontLarge.family
            font.pixelSize: Tokens.fontLarge.pixelSize
            font.weight: Font.DemiBold
            color: root.colors.on_surface
        }
    }

    SysText {
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacingLarge
        anchors.verticalCenter: head.verticalCenter
        text: root.note
        font: Tokens.fontSmall
        color: root.colors.on_surface_variant
    }

    Item {
        id: slot
        anchors.fill: parent
        anchors.topMargin: head.y + head.height + Tokens.spacingMediumV
        anchors.leftMargin: Tokens.spacingLarge
        anchors.rightMargin: Tokens.spacingLarge
        anchors.bottomMargin: Tokens.spacingLargeV
    }
}
