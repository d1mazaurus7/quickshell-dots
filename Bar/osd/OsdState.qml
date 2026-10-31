import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../shell/config"

// Состояние OSD: громкость устройства вывода и Caps/Num Lock.
// triggered() — значение изменилось пользователем, окно нужно показать.
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    property bool capsLock: false
    property bool numLock: false

    // Что показать: "volume" | "caps" | "num"
    property string kind: "volume"
    // Время последнего звука, мс: колесо мыши шлёт изменения пачкой
    property double lastSound: 0

    signal triggered()

    function trigger(newKind: string): void {
        kind = newKind;
        triggered();
        const now = Date.now();
        if (now - lastSound < 60)
            return;
        lastSound = now;
        Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.osdSound)]);
    }

    // Без трекера у узла не заполняются данные audio
    PwObjectTracker { objects: [root.sink].filter(n => n) }

    // Смена устройства или первое заполнение audio — не пользовательское изменение
    onSinkChanged: settle.restart()
    Timer { id: settle; interval: 500; running: true }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged(): void { if (!settle.running) root.trigger("volume"); }
        function onMutedChanged(): void { if (!settle.running) root.trigger("volume"); }
    }

    // Niri не сообщает состояние Lock-клавиш: читаем светодиоды клавиатур в sysfs.
    // Скрипт без внешних команд в цикле, печатает "caps num" только при изменении;
    // ожидание — read с таймаутом на пустом канале вместо sleep.
    Process {
        running: true
        command: ["bash", "-c", `
            exec 3<> <(:)
            last=
            while :; do
                c=0; n=0
                for f in /sys/class/leds/*::capslock/brightness; do read -r v < "$f" 2>/dev/null && [ "$v" != 0 ] && c=1; done
                for f in /sys/class/leds/*::numlock/brightness; do read -r v < "$f" 2>/dev/null && [ "$v" != 0 ] && n=1; done
                [ "$c $n" != "$last" ] && { last="$c $n"; echo "$last"; }
                read -t 0.15 -u 3
            done`]
        stdout: SplitParser {
            property bool first: true
            onRead: line => {
                const [caps, num] = line.split(" ").map(v => v === "1");
                const capsChanged = caps !== root.capsLock;
                const numChanged = num !== root.numLock;
                root.capsLock = caps;
                root.numLock = num;
                // Первая строка — начальное состояние
                if (first) {
                    first = false;
                    return;
                }
                if (capsChanged)
                    root.trigger("caps");
                else if (numChanged)
                    root.trigger("num");
            }
        }
    }
}
