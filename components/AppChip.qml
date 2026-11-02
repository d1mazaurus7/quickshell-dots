import QtQuick
import QtQuick.Layouts
import "../shell/theme"

// Чип приложения: иконка, название и кнопка удаления
Rectangle {
    id: root

    property string icon
    property string name

    signal removed()

    readonly property var colors: Tokens.colors

    implicitWidth: row.implicitWidth + Tokens.spacingSmall + Tokens.spacingMedium
    implicitHeight: Tokens.scaled(36)
    radius: height / 2
    color: colors.secondary_container

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacingSmall

        AppIcon {
            icon: root.icon
            name: root.name
            size: Tokens.scaled(24)
        }

        Text {
            text: root.name
            color: root.colors.on_secondary_container
            font: Tokens.fontSmall
        }

        Rectangle {
            implicitWidth: Tokens.scaled(24)
            implicitHeight: Tokens.scaled(24)
            radius: width / 2
            color: removeArea.pressed ? Qt.alpha(root.colors.on_secondary_container, 0.2)
                 : removeArea.containsMouse ? Qt.alpha(root.colors.on_secondary_container, 0.1)
                 : "transparent"
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: root.colors.on_secondary_container
                font: Tokens.fontSmall
            }

            MouseArea {
                id: removeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.removed()
            }
        }
    }
}
