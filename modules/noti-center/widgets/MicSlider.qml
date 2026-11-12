import QtQuick
import Quickshell.Services.Pipewire
import "../controls"
import "../controls/Icons.js" as Icons

// Чувствительность микрофона по умолчанию; кнопка — выключить микрофон
SliderTile {
    id: w

    required property var ctx
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var audio: source ? source.audio : null

    s: ctx.s
    checked: !!audio && audio.muted
    icon: Icons.mic
    slashed: checked
    available: !!audio
    value: audio ? Math.min(1, audio.volume) : 0
    onMoved: v => w.audio.volume = v
    onScrolled: ctx.play("button")
    onToggled: {
        if (!audio)
            return;
        audio.muted = !audio.muted;
        ctx.play("click");
    }

    PwObjectTracker { objects: w.source ? [w.source] : [] }
}
