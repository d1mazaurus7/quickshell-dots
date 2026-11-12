import QtQuick
import "../../../theme" as Theme

// Кнопка-иконка MD3. round: круг ↔ скруглённый квадрат при checked
// (переключатель MD3 expressive). При нажатии углы слегка сжимаются.
Item {
    id: btn

    required property real s
    property string icon
    property bool checked: false
    // Перечеркнуть иконку (анимированно)
    property bool slashed: false
    // Сдвигать иконку при нажатии в эту сторону (1 — вправо, -1 — влево, 0 — нет)
    property int slideOnClick: 0
    property bool round: false
    // false — только индикатор, без нажатий
    property bool interactive: true
    property color color: checked ? Theme.Palette.secondary : Theme.Palette.surface_container_highest
    property color contentColor: checked ? Theme.Palette.on_secondary : Theme.Palette.on_surface
    property real iconSize: Math.min(width, height) * 0.44

    readonly property bool pressed: area.pressed
    readonly property bool hovered: area.containsMouse
    readonly property real side: Math.min(width, height)
    property real radius: pressed ? side * 0.22 : round && !checked ? side / 2 : side * 0.3

    signal clicked()

    implicitWidth: 44 * s
    implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0.5

    Behavior on radius { Emphasized {} }

    Rectangle {
        anchors.fill: parent
        radius: btn.radius
        color: btn.color
        Behavior on color { SmoothColor {} }

        StateLayer {
            radius: parent.radius
            color: btn.contentColor
            hovered: btn.hovered
            pressed: btn.pressed
        }
    }

    Icon {
        id: glyph
        anchors.centerIn: parent
        text: btn.icon
        color: btn.contentColor
        slashed: btn.slashed
        slashGap: btn.color
        size: btn.iconSize
        Behavior on color { SmoothColor {} }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: btn.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (btn.slideOnClick !== 0)
                glyph.slide(btn.slideOnClick);
            btn.clicked();
        }
    }
}
