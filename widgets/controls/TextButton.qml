import QtQuick
import "../../shell/theme"

// Кнопка-пилюля со значком и подписью; danger — цвета ошибки
Rectangle {
    id: root

    property string icon
    property string text
    property bool danger: false

    signal clicked()

    readonly property var colors: Tokens.colors
    readonly property color contentColor: danger ? colors.on_error_container : colors.on_secondary_container

    implicitWidth: row.implicitWidth + Tokens.spacingLarge * 2
    implicitHeight: Tokens.scaled(36)
    radius: height / 2
    color: danger ? colors.error_container : colors.secondary_container
    scale: area.pressed ? 0.96 : 1

    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.contentColor
        opacity: area.pressed ? 0.12 : area.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacingSmall

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            color: root.contentColor
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(18)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.contentColor
            font: Tokens.fontMedium
        }
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
