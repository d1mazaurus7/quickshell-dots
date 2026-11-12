import QtQuick
import Quickshell
import Quickshell.Io
import "../../shell/config"
import "../../components/animations/BarDropdownStack.js" as DropdownStack

// Сервис скриншотов: qs ipc call screenshot capture|close
// Оверлей выделения открывается на мониторе в фокусе Niri.
Scope {
    id: root

    readonly property var cfg: Config.options.screenshot

    property bool active: false
    // Оверлей плавно скрывается, затем вызывает close()
    property bool closing: false
    // Имя монитора, на котором открыт оверлей
    property string output: ""

    // PNG сначала пишется во временный файл, затем копируется/сохраняется
    readonly property string tempPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-screenshot.png"
    // Замороженный кадр монитора от grim. ScreencopyView на Niri не используется:
    // его wlr-screencopy роняет Qt Wayland (quickshell#1202).
    // PPM без сжатия: кодирование PNG в grim занимало секунды
    readonly property string framePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-screenshot-frame.ppm"
    readonly property string saveDir: (Quickshell.env("XDG_PICTURES_DIR") || Quickshell.env("HOME") + "/Pictures") + "/Screenshots"

    function screenByName(name: string): var {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name)
                return Quickshell.screens[i];
        }
        return null;
    }

    function requestClose(): void {
        if (active)
            closing = true;
    }

    // output не сбрасывается: окно оверлея живёт постоянно, а смена screen
    // на null пересоздаёт его — это роняло Qt Wayland
    function close(): void {
        active = false;
        closing = false;
    }

    // Вызывается оверлеем, когда снимок записан в tempPath
    function finish(save: bool, copy: bool): void {
        const path = saveDir + "/screenshot-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".png";
        if (save)
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp "$1" "$2"', "sh", tempPath, path]);
        if (copy)
            Quickshell.execDetached(["sh", "-c", 'wl-copy -t image/png < "$1"', "sh", tempPath]);
        if (cfg.sound && cfg.soundFile !== "")
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/screenshot/" + cfg.soundFile)]);
        if (cfg.notify) {
            const body = save ? "Скриншот экрана сделан. Сохранено в " + path
                              : "Скриншот экрана скопирован в буфер обмена";
            Quickshell.execDetached(["notify-send", "Скриншоты", body]);
        }
        requestClose();
    }

    // Кадр монитора в фокусе и оверлей выделения
    function capture(): void {
        if (!active && !grabFrame.running && !focusedOutput.running)
            focusedOutput.running = true;
    }

    IpcHandler {
        target: "screenshot"

        function capture(): void { root.capture(); }
        function close(): void { root.requestClose(); }
    }

    Process {
        id: focusedOutput
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const out = JSON.parse(text);
                    if (out && out.name && root.screenByName(out.name)) {
                        root.output = out.name;
                        grabFrame.running = true;
                    }
                } catch (e) {
                    console.warn("screenshot: не удалось разобрать focused-output:", e);
                }
            }
        }
    }

    // Оверлей открывается, когда кадр уже записан
    Process {
        id: grabFrame
        command: ["grim", "-t", "ppm", "-o", root.output, root.framePath]
        onExited: code => {
            if (code === 0) {
                // Панели шелла остаются на кадре, но закрываются,
                // чтобы их захват ввода не мешал выделению
                DropdownStack.dismissAll();
                root.active = true;
            } else
                console.warn("screenshot: grim завершился с кодом", code);
        }
    }

    // Окно не уничтожается между снимками, только скрывается (как окно настроек)
    ScreenshotOverlay {
        service: root
        screen: root.screenByName(root.output) ?? Quickshell.screens[0]
    }
}
