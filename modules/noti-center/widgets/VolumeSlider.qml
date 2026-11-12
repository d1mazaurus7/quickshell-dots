import QtQuick
import "../controls"
import "../controls/Icons.js" as Icons

// Громкость устройства вывода; кнопка — выключить звук
SliderTile {
    id: w

    required property var ctx
    readonly property var audio: ctx.sink ? ctx.sink.audio : null

    s: ctx.s
    checked: !!audio && audio.muted
    icon: Icons.volume
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
}
