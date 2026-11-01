import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris

// Позиция трека с поправкой: при смене трека Quickshell запрашивает Position один раз,
// а mpd-mpris ещё ~1 с отдаёт конец прошлого трека и потом не сообщает об изменении.
// Перечитываем Position по DBus несколько раз и держим разницу, пока позиция
// не сделает скачок (перемотка, пауза).
Item {
    id: root

    property MprisPlayer player: null
    readonly property real position: player ? Math.max(0, player.position + correction) : 0

    property real correction: 0
    property real anchor: NaN

    // Задержки перечитывания после смены трека, мс (от предыдущего запроса)
    readonly property var steps: [300, 900, 1500]
    property int step: 0

    function resync() {
        step = 0;
        refetch.interval = steps[0];
        refetch.restart();
    }

    onPlayerChanged: {
        correction = 0;
        anchor = NaN;
        resync();
    }
    // Окно могло открыться посреди трека с уже сбитой позицией
    Component.onCompleted: resync()

    Connections {
        target: root.player

        function onPostTrackChanged() {
            root.correction = 0;
            root.resync();
        }

        // При линейном ходе (raw - now) постоянно, на паузе постоянно raw;
        // иначе Quickshell получил новую позицию — поправка больше не нужна
        function onPositionChanged() {
            const raw = root.player.position;
            const a = root.player.isPlaying ? raw - Date.now() / 1000 : raw;
            if (Math.abs(a - root.anchor) > 1)
                root.correction = 0;
            root.anchor = a;
        }
    }

    Timer {
        id: refetch
        interval: 300
        onTriggered: {
            if (root.player && root.player.positionSupported)
                query.running = true;
            if (++root.step < root.steps.length) {
                interval = root.steps[root.step];
                restart();
            }
        }
    }

    Process {
        id: query
        command: ["busctl", "--user", "get-property", root.player?.dbusName ?? "",
            "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Position"]
        // Вывод: "x <микросекунды>"
        stdout: StdioCollector {
            onStreamFinished: {
                const us = Number(text.trim().split(/\s+/)[1]);
                if (!root.player || isNaN(us)) return;
                root.correction = us / 1e6 - root.player.position;
                root.anchor = NaN;
                root.player.positionChanged();
            }
        }
    }
}
