import QtQuick
import "../../shell/theme"

// M3 filter chip: включение серии графика; иконка сменяется на галочку
Rectangle {
    id: root

    property string icon
    property string label
    property color accent: colors.primary
    property bool checked: true
    readonly property var colors: Tokens.colors

    signal toggled()

    implicitWidth: row.implicitWidth + Tokens.spacingMedium * 2 + Tokens.scaled(4)
    implicitHeight: Tokens.scaled(30)
    radius: Tokens.radius(10)
    color: checked ? Qt.alpha(accent, area.containsMouse ? 0.26 : 0.18) : (area.containsMouse ? Qt.alpha(colors.on_surface, 0.08) : "transparent")
    border.width: checked ? 0 : 1
    border.color: colors.outline_variant
    scale: area.pressed ? 0.94 : 1
    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacingSmall

        SysIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.checked ? "check" : root.icon
            size: Tokens.scaled(16)
            filled: root.checked
            hovered: area.containsMouse
            color: root.checked ? root.accent : root.colors.on_surface_variant
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font: Tokens.fontSmall
            color: root.checked ? root.colors.on_surface : root.colors.on_surface_variant
            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
