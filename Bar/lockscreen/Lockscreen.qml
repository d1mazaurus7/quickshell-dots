import QtQuick
import Quickshell
import Quickshell.Wayland

// Лок-скрин (ext-session-lock): поверхность на каждом мониторе.
// Состояние — LockState, виджеты и редактор — общие с рабочим столом (widgets/)
Scope {
    id: root

    required property LockState lock
    // Набор виджетов лок-скрина (Widgets.lockStore)
    required property var widgets
    required property var notifications

    // Виджеты лок-скрина по умолчанию — при первой блокировке
    Connections {
        target: root.lock
        function onLockedChanged(): void {
            if (root.lock.locked)
                root.widgets.seedLock(Quickshell.screens[0]);
        }
    }

    WlSessionLock {
        locked: root.lock.locked

        LockSurface {
            lock: root.lock
            widgets: root.widgets
            notifications: root.notifications
        }
    }
}
