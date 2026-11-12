import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"

// Ползунок MD3 expressive: активная дорожка, узкая ручка с зазорами,
// неактивная дорожка с точкой-упором. При нажатии ручка сужается.
Item {
    id: sl

    required property real s
    property real value: 0
    property bool available: true
    property real trackHeight: height - 10 * s
    property color activeColor: Theme.Palette.primary
    property color inactiveColor: Theme.Palette.secondary_container

    readonly property bool pressed: area.pressed
    property real handleW: pressed ? 2 * s : 4 * s
    readonly property real gapW: 5 * s
    readonly property real outer: Math.min(trackHeight * 0.32, 24 * s)
    readonly property real inner: 3 * s
    // Отображаемое значение: при перетаскивании без задержки
    property real shown: value
    readonly property real hx: handleW / 2 + (width - handleW) * shown

    signal moved(real v)
    signal scrolled()

    opacity: available ? 1 : 0.5

    Behavior on shown {
        enabled: !area.pressed
        Smooth { duration: Tokens.animationFast }
    }
    Behavior on handleW { Smooth { duration: 120 } }

    function emitAt(x: real): void {
        moved(Math.max(0, Math.min(1, (x - handleW / 2) / (width - handleW))));
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, sl.hx - sl.handleW / 2 - sl.gapW)
        height: sl.trackHeight
        visible: width > 0
        topLeftRadius: Math.min(sl.outer, width / 2)
        bottomLeftRadius: topLeftRadius
        topRightRadius: Math.min(sl.inner, width / 2)
        bottomRightRadius: topRightRadius
        color: sl.activeColor
        Behavior on color { SmoothColor {} }
    }

    Rectangle {
        id: rest
        anchors.verticalCenter: parent.verticalCenter
        x: sl.hx + sl.handleW / 2 + sl.gapW
        width: Math.max(0, sl.width - x)
        height: sl.trackHeight
        visible: width > 0
        topLeftRadius: Math.min(sl.inner, width / 2)
        bottomLeftRadius: topLeftRadius
        topRightRadius: Math.min(sl.outer, width / 2)
        bottomRightRadius: topRightRadius
        color: sl.inactiveColor

        // Точка-упор в конце дорожки
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: sl.outer - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 4 * sl.s
            height: width
            radius: width / 2
            visible: rest.width > sl.outer * 2
            color: sl.activeColor
        }
    }

    Rectangle {
        x: sl.hx - sl.handleW / 2
        width: sl.handleW
        height: parent.height
        radius: width / 2
        color: sl.activeColor
        Behavior on color { SmoothColor {} }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: sl.available
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => sl.emitAt(mouse.x)
        onPositionChanged: mouse => { if (pressed) sl.emitAt(mouse.x); }
        onWheel: wheel => {
            sl.moved(Math.max(0, Math.min(1, sl.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))));
            sl.scrolled();
        }
    }
}
