import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../shell/config"

// Сервер уведомлений и общее состояние: один экземпляр на оболочку.
Scope {
    id: root

    readonly property var cfg: Config.options.notiCenter
    // Не беспокоить: уведомления копятся в центре, но не всплывают.
    property bool dnd: false
    // Центр уведомлений открыт: новые не всплывают, а сразу видны в нём.
    property bool centerOpen: false
    // Все уведомления и всплывающие (роль nid), новые сверху.
    readonly property ListModel history: ListModel {}
    readonly property ListModel popups: ListModel {}
    property var byId: ({})

    function find(id: int): var {
        return byId[id] ?? null;
    }

    function indexIn(model: ListModel, id: int): int {
        for (let i = 0; i < model.count; i++) {
            if (model.get(i).nid === id)
                return i;
        }
        return -1;
    }

    function removePopup(id: int): void {
        const i = indexIn(popups, id);
        if (i >= 0)
            popups.remove(i);
    }

    // Учёт уведомления: история и очистка при закрытии.
    function adopt(n: var): void {
        if (byId[n.id])
            return;
        byId[n.id] = n;
        n.closed.connect(() => {
            removePopup(n.id);
            const i = indexIn(history, n.id);
            if (i >= 0)
                history.remove(i);
            delete byId[n.id];
        });
        history.insert(0, { nid: n.id });
    }

    // После перезагрузки конфига сервер сохраняет уведомления (keepOnReload).
    Component.onCompleted: {
        for (const n of server.trackedNotifications.values)
            adopt(n);
    }

    function clearAll(): void {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.adopt(n);
            // Звук: root.cfg.sound — пока заглушка.
            // Напоминания (ReminderState.appName) по настройке всплывают и в «Не беспокоить»
            const reminder = n.appName === "Напоминание" && root.cfg.remindersIgnoreDnd;
            if ((root.dnd && !reminder) || root.centerOpen)
                return;
            root.removePopup(n.id);
            root.popups.insert(0, { nid: n.id });
        }
    }
}
