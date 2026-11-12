import QtQuick
import "../../shell/theme"
import "../../shell/config"
import "controls"
import "controls/Icons.js" as Icons

// Страница настроек записи экрана (те же параметры, что у панели записи).
// Варианты разрешения и FPS — по текущему режиму монитора (обновляется при открытии).
Column {
    id: page

    required property var ctx
    readonly property real s: ctx.s
    readonly property var rec: ctx.recorderService
    readonly property var cfg: Config.options.recorder
    readonly property var resOptions: rec ? rec.resolutionOptions(rec.modeWidth, rec.modeHeight) : []

    spacing: 16 * s

    function refresh(): void {
        if (rec)
            rec.probe();
    }

    PageSection {
        s: page.s
        title: "Режим"
        Segmented {
            width: parent.width
            s: page.s
            options: [
                { value: false, label: "Область", icon: Icons.cropFree },
                { value: true, label: "Весь экран", icon: Icons.fullscreen }
            ]
            current: page.cfg.fullscreen
            onPicked: v => {
                page.ctx.play("click");
                page.cfg.fullscreen = v;
            }
        }
    }

    PageSection {
        s: page.s
        title: "Разрешение"
        Segmented {
            width: parent.width
            s: page.s
            options: page.resOptions
            // Сохранённое разрешение больше источника — исходное
            current: page.resOptions.some(o => o.value === page.cfg.resolution) ? page.cfg.resolution : 0
            onPicked: v => {
                page.ctx.play("click");
                page.cfg.resolution = v;
            }
        }
    }

    PageSection {
        s: page.s
        title: "Частота кадров"
        Segmented {
            width: parent.width
            s: page.s
            options: page.rec ? page.rec.fpsOptions : []
            current: page.rec ? page.rec.fps : page.cfg.fps
            onPicked: v => {
                page.ctx.play("click");
                page.cfg.fps = v;
            }
        }
    }

    PageSection {
        s: page.s
        title: "Звук"
        Row {
            width: parent.width
            spacing: 8 * page.s

            ToggleButton {
                width: (parent.width - parent.spacing) / 2
                s: page.s
                icon: Icons.volume
                label: "Система"
                checked: page.cfg.systemAudio
                onClicked: {
                    page.ctx.play("click");
                    page.cfg.systemAudio = !page.cfg.systemAudio;
                }
            }
            ToggleButton {
                width: (parent.width - parent.spacing) / 2
                s: page.s
                icon: Icons.mic
                label: "Микрофон"
                checked: page.cfg.microphone
                onClicked: {
                    page.ctx.play("click");
                    page.cfg.microphone = !page.cfg.microphone;
                }
            }
        }
    }
}
