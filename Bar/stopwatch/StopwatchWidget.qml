import QtQuick
import "../../shell/config"
import "../../shell/theme"

// Кнопка секундомера в баре: видна, пока секундомер запущен или на паузе.
// Нажатие открывает/закрывает окно секундомера.
// Использование: StopwatchWidget { stopwatch: <Stopwatch>; barHeight: ... }
Item {
    id: root

    required property var stopwatch
    property real barHeight: 40

    readonly property var cfg: Config.options.stopwatch
    readonly property var colors: Tokens.colors
    readonly property int buttonHeight: Math.max(0, barHeight - Tokens.scaled(6) * 2)

    // Своё «сейчас»: таймер окна тикает, только пока окно видно
    property double now: Date.now()
    readonly property double elapsed: stopwatch.accumulated + (stopwatch.running ? now - stopwatch.startedAt : 0)

    visible: cfg.barWidget && (stopwatch.running || stopwatch.accumulated > 0)
    implicitWidth: button.implicitWidth
    implicitHeight: buttonHeight

    Timer {
        interval: 200
        repeat: true
        running: root.visible && root.stopwatch.running
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Rectangle {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: row.implicitWidth + Tokens.spacingLarge * 2
        height: root.buttonHeight
        radius: Tokens.radiusMedium
        color: area.pressed ? root.colors.secondary_container
             : area.containsMouse || root.stopwatch.open ? root.colors.surface_bright
             : root.colors.surface_container_highest
        Behavior on color { ColorAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.spacingSmall

            Text {
                id: icon
                visible: root.cfg.icon !== ""
                text: root.cfg.icon
                color: label.color
                font: Tokens.fontMedium
                opacity: 1

                // Плавное мигание, пока секундомер идёт
                SequentialAnimation on opacity {
                    running: root.visible && root.cfg.blinkIcon && root.stopwatch.running
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) icon.opacity = 1
                    NumberAnimation { to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                id: label
                text: root.stopwatch.format(root.elapsed)
                color: area.pressed ? root.colors.on_secondary_container
                     : root.stopwatch.open ? root.colors.primary
                     : root.colors.on_surface
                font: Tokens.fontMedium
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stopwatch.open = !root.stopwatch.open
        }
    }
}
