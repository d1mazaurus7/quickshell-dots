import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"

// Ручка масштабирования на краю виджета: таблетка (или точка в углу),
// при наведении и нажатии растёт. moved — курсор в координатах ручки.
Item {
    id: handle

    required property real s
    property int cursor: Qt.SizeHorCursor
    property bool dot: false
    readonly property bool pressed: area.pressed
    // Ориентация таблетки: вертикальная — для правого края
    property bool vertical: width < height

    signal moved(Item area, var mouse)
    signal released()

    Rectangle {
        readonly property real grow: area.pressed ? 1.25 : area.containsMouse ? 1.12 : 0.6
        anchors.centerIn: parent
        // Видна только при наведении и перетаскивании
        opacity: area.pressed || area.containsMouse ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { Smooth { duration: Tokens.animationFast } }
        width: (handle.dot ? handle.width * 0.6 : handle.vertical ? 4 * handle.s : handle.width) * grow
        height: (handle.dot ? handle.width * 0.6 : handle.vertical ? handle.height : 4 * handle.s) * grow
        radius: Math.min(width, height) / 2
        color: area.pressed ? Theme.Palette.primary : Theme.Palette.on_surface_variant
        Behavior on width { Smooth { duration: 120 } }
        Behavior on height { Smooth { duration: 120 } }
        Behavior on color { SmoothColor {} }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -4 * handle.s
        hoverEnabled: true
        preventStealing: true
        cursorShape: handle.cursor
        onPositionChanged: mouse => { if (pressed) handle.moved(area, mouse); }
        onReleased: handle.released()
        onCanceled: handle.released()
    }
}
