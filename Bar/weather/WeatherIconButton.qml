import QtQuick
import "../../shell/theme"

// Кнопка-значок Material 3. Слой состояния (hover/pressed); при нажатии и во включённом
// состоянии (checked) фигура морфится из круга в скруглённый квадрат, значок заливается.
// clickable: false — только индикатор, hovered/pressed задаёт владелец. spinning — вращение
// (при остановке доворачивает оборот). Выключенная (enabled: false) — приглушена.
Item {
    id: btn

    property string icon
    property real iconSize: 20
    property color color: "white"
    property color checkedColor: color
    property color containerColor: "transparent"
    property bool checked: false
    property bool clickable: true
    property bool hovered: area.containsMouse
    property bool pressed: area.pressed
    property bool spinning: false
    property real iconRotation: 0

    signal clicked()

    readonly property color content: checked ? checkedColor : color
    readonly property real round: Math.min(width, height) / 2

    Rectangle {
        id: container
        anchors.fill: parent
        property real shape: btn.pressed ? 0.5 : btn.checked ? 0.6 : 1
        Behavior on shape { WeatherSpring {} }
        radius: btn.round * shape
        color: btn.containerColor
        opacity: (btn.checked ? 1 : 0) * (btn.enabled ? 1 : 0.38)
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    }

    // Слой состояния M3: 8% при наведении, 12% при нажатии
    Rectangle {
        anchors.fill: parent
        radius: container.radius
        color: btn.content
        opacity: !btn.enabled ? 0 : btn.pressed ? 0.12 : btn.hovered ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
    }

    Item {
        id: spinner
        anchors.fill: parent

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            alwaysRunToEnd: true
            running: btn.spinning && Tokens.animationSlow > 0
        }

        WeatherIcon {
            id: glyph
            anchors.centerIn: parent
            text: btn.icon
            color: btn.content
            font.pixelSize: btn.iconSize
            filled: btn.checked || btn.pressed
            hovered: btn.hovered && btn.enabled
            pressed: btn.pressed
            rotation: btn.iconRotation
            Behavior on rotation { WeatherSpring {} }
            Behavior on color { ColorAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: btn.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            glyph.pop();
            btn.clicked();
        }
    }
}
