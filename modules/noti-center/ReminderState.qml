import QtQuick
import Quickshell
import Quickshell.Io
import "../../shell/config"

// Напоминания: [{ id, due (мс), text, last (мс, 0 — ещё не было) }] в data-каталоге оболочки.
// Файл отслеживается, поэтому экземпляры на разных экранах видят одни данные.
// Срабатывают только в экземпляре с scheduler: true — иначе уведомления дублируются.
Item {
    id: root

    readonly property var cfg: Config.options.notiCenter
    // Этот экземпляр отправляет уведомления
    property bool scheduler: false
    // Не беспокоить (NotificationState.dnd): без звука, если не разрешено в настройках
    property bool dnd: false
    // Имя приложения уведомления: по нему NotificationState узнаёт напоминание
    readonly property string appName: "Напоминание"

    property var reminders: []

    function add(due: date, text: string): void {
        write(reminders.concat([{ id: Date.now(), due: due.getTime(), text: text, last: 0 }]));
    }

    function remove(id: real): void {
        write(reminders.filter(r => r.id !== id));
    }

    // Напоминания на день, по времени
    function forDay(day: date): var {
        return reminders.filter(r => {
            const d = new Date(r.due);
            return d.getFullYear() === day.getFullYear() && d.getMonth() === day.getMonth() && d.getDate() === day.getDate();
        }).sort((a, b) => a.due - b.due);
    }

    function write(list: var): void {
        reminders = list;
        file.setText(JSON.stringify(list, null, 2));
    }

    function nextFire(r: var): real {
        return r.last > 0 ? r.last + cfg.reminderInterval * 1000 : r.due;
    }

    // Отправить подошедшие напоминания и завести таймер до следующего.
    // Таймер не дольше минуты: монотонные часы стоят во сне, после пробуждения
    // напоминание не опоздает больше чем на минуту.
    function schedule(): void {
        tick.stop();
        if (!scheduler || !cfg.showCalendar || !cfg.reminders)
            return;
        const now = Date.now();
        let next = Infinity;
        let list = reminders;
        let changed = false;
        for (const r of reminders) {
            if (nextFire(r) > now + 500) {
                next = Math.min(next, nextFire(r));
                continue;
            }
            fire(r);
            changed = true;
            // Без «Остановить» напоминание одноразовое
            list = cfg.reminderRequireStop
                ? list.map(x => x.id === r.id ? Object.assign({}, x, { last: now }) : x)
                : list.filter(x => x.id !== r.id);
            if (cfg.reminderRequireStop)
                next = Math.min(next, now + cfg.reminderInterval * 1000);
        }
        if (changed)
            write(list);
        if (next !== Infinity) {
            tick.interval = Math.max(1, Math.min(60000, next - now));
            tick.start();
        }
    }

    function fire(r: var): void {
        const args = ["notify-send", "-a", appName];
        if (cfg.reminderRequireStop)
            args.push("-p", "-A", "stop=Остановить");
        if (replaceIds[r.id])
            args.push("-r", String(replaceIds[r.id]));
        args.push("Напоминание", r.text);
        notifyProc.createObject(root, { rid: r.id, command: args });

        if (cfg.reminderSound !== "" && (!dnd || cfg.remindersIgnoreDnd))
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/notes/" + cfg.reminderSound)]);
    }

    // id уведомления напоминания: повтор заменяет прежнее, а не копится в истории
    property var replaceIds: ({})

    // notify-send с -p печатает id, с -A ждёт и печатает имя нажатого действия
    Component {
        id: notifyProc
        Process {
            id: proc
            property real rid
            stdout: SplitParser {
                onRead: line => {
                    if (line === "stop")
                        root.remove(proc.rid);
                    else if (/^\d+$/.test(line))
                        root.replaceIds[proc.rid] = Number(line);
                }
            }
            onExited: destroy()
            Component.onCompleted: running = true
        }
    }

    Timer {
        id: tick
        onTriggered: root.schedule()
    }

    onRemindersChanged: schedule()
    onSchedulerChanged: schedule()

    Connections {
        target: root.cfg
        function onRemindersChanged() { root.schedule(); }
        function onShowCalendarChanged() { root.schedule(); }
        function onReminderIntervalChanged() { root.schedule(); }
    }

    FileView {
        id: file
        path: Quickshell.dataPath("reminders.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.reminders = JSON.parse(text()) ?? [];
            } catch (e) {
                console.warn("reminders.json:", e);
            }
        }
    }
}
