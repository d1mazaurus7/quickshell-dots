import QtQuick
import "../../../shell/config"
import "../controls"
import "../controls/Icons.js" as Icons

// Запись экрана: старт/стоп; меню — страница настроек записи
SplitTile {
    id: w

    required property var ctx
    readonly property var rec: ctx.recorderService
    readonly property bool recording: !!rec && rec.recording

    s: ctx.s
    active: recording
    icon: recording ? Icons.stop : Icons.record
    menuSlideOnClick: 1
    title: recording ? rec.formatTime(rec.elapsed) + (rec.paused ? " · пауза" : "") : "Запись"
    subtitle: recording ? "Идёт запись"
        : (Config.options.recorder.fullscreen ? "Весь экран" : "Область") + " · " + (rec ? rec.fps : Config.options.recorder.fps) + " fps"
    onToggled: {
        if (!rec)
            return;
        if (recording) {
            rec.stop();
            ctx.play("power_off");
            return;
        }
        ctx.play("power_on");
        // Запись стартует после закрытия центра, чтобы он не попал в кадр
        ctx.runHidden(() => w.rec.record());
    }
    onExpand: {
        ctx.play("list");
        ctx.page = "recorder";
    }
}
