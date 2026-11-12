import QtQuick

// Скрытие lock-виджета при бездействии: delay с без ввода — shown = false, любая активность показывает снова
Item {
    id: root

    // LockState: сигнал activity() при нажатии клавиш и движении мыши
    property var lock: null
    property bool active: false
    property real delay: 10
    // Не прятать (идёт ввод, ошибка, открыт редактор)
    property bool hold: false

    property bool idle: false
    readonly property bool shown: !active || hold || !idle

    onHoldChanged: if (hold) idle = false

    Timer {
        id: timer
        interval: root.delay * 1000
        running: root.active && !root.hold && !root.idle
        onTriggered: root.idle = true
    }

    Connections {
        target: root.lock
        function onActivity(): void {
            root.idle = false;
            timer.restart();
        }
    }
}
