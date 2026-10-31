import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Состояние звука: устройство вывода по умолчанию, потоки приложений, перезапуск служб
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    // Набор потоков зависит только от добавления/удаления узлов (isStream постоянен),
    // иначе трекер перепривязывает узлы на каждое изменение properties
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream)
    // Без pw-play: его потоки — звуки интерфейса, появляются и исчезают на каждый щелчок
    readonly property var apps: streams.filter(n => n.audio && n.properties["application.name"] !== "pw-play")
    readonly property var outputs: apps.filter(n => n.properties["media.class"] === "Stream/Output/Audio")
    readonly property var inputs: apps.filter(n => n.properties["media.class"] === "Stream/Input/Audio")

    function setVolume(value: real): void {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, value));
    }

    // Только WirePlumber: перезапуск PipeWire рвёт соединение приложений и оболочки,
    // а Quickshell к нему не переподключается
    function restartAudio(): void {
        Quickshell.execDetached(["systemctl", "--user", "restart", "wireplumber"]);
    }

    function restartEasyEffects(): void {
        Quickshell.execDetached(["sh", "-c", "easyeffects -q; sleep 1; easyeffects -w"]);
    }

    // Без трекера у узлов не заполняются данные audio
    PwObjectTracker {
        objects: [root.sink, ...root.streams].filter(n => n)
    }
}
