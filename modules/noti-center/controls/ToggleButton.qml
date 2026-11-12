import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"

// Кнопка-переключатель MD3 expressive с иконкой и подписью: выключена — пилюля,
// включена — скруглённый прямоугольник цвета primary. Выключенная иконка
// перечёркивается (slashOff), при нажатии иконка сжимается и отскакивает.
Item {
    id: toggle

    required property real s
    property string icon
    property string label
    property bool checked
    // Перечёркивать иконку в выключенном состоянии
    property bool slashOff: true
    signal clicked()

    readonly property color bgColor: checked ? Theme.Palette.primary : Theme.Palette.surface_container_high
    readonly property color fgColor: checked ? Theme.Palette.on_primary : Theme.Palette.on_surface

    implicitHeight: 48 * s

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: area.pressed ? height * 0.2 : toggle.checked ? height * 0.32 : height / 2
        color: toggle.bgColor
        Behavior on radius { Emphasized {} }
        Behavior on color { SmoothColor {} }

        StateLayer {
            radius: bg.radius
            color: toggle.fgColor
            hovered: area.containsMouse
            pressed: area.pressed
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 8 * toggle.s

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: toggle.icon
            size: 20 * toggle.s
            slashed: toggle.slashOff && !toggle.checked
            slashGap: toggle.bgColor
            color: toggle.fgColor
            scale: area.pressed ? 0.75 : 1
            Behavior on color { SmoothColor {} }
            Behavior on scale { Emphasized { duration: Tokens.animationMedium; easing.overshoot: 2.5 } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: toggle.label
            color: toggle.fgColor
            font.family: Tokens.typography.family
            font.pixelSize: Math.round(13 * toggle.s)
            font.weight: Font.Medium
            Behavior on color { SmoothColor {} }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.clicked()
    }
}
