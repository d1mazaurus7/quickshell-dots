import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Аудиоустройства: выбор вывода/ввода по умолчанию и отключение микрофона
Scope {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
    readonly property var sinks: devices.filter(n => n.isSink)
    readonly property var sources: devices.filter(n => !n.isSink)

    function label(node: PwNode): string {
        return node ? (node.description || node.nickname || node.name) : "";
    }

    function setSink(name: string): void {
        const node = sinks.find(n => label(n) === name);
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(name: string): void {
        const node = sources.find(n => label(n) === name);
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    function setMicMuted(value: bool): void {
        if (source?.audio)
            source.audio.muted = value;
    }

    // Без трекера у узла не заполняются данные audio
    PwObjectTracker {
        objects: [root.source].filter(n => n)
    }
}
