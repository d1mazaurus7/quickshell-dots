import QtQuick
import Quickshell
import Quickshell.Io
import "../../shell/config"
import "../../components/animations/BarDropdownStack.js" as DropdownStack

// Сервис записи экрана через gpu-screen-recorder:
// qs ipc call recorder toggle|start|stop|pause
Scope {
    id: root

    readonly property var cfg: Config.options.recorder

    // Оверлей выбора области
    property bool active: false
    property bool closing: false
    property string output: ""
    // Текущий режим монитора из Niri: частота ограничивает FPS, размер — разрешение
    property int refreshRate: 60
    property int modeWidth: 1920
    property int modeHeight: 1080
    property real outputScale: 1

    readonly property var fpsOptions: {
        const list = [30, 60, 120].filter(f => f < refreshRate);
        list.push(refreshRate);
        return list.map(f => ({ value: f, label: String(f) }));
    }
    readonly property int fps: Math.min(cfg.fps, refreshRate)

    readonly property bool recording: proc.running
    property bool paused: false
    // Секунды записи без пауз
    property int elapsed: 0
    property real base: 0
    property real segStart: 0

    // Команда запускается после закрытия оверлея, чтобы он не попал в кадр
    property var pending: null
    property string path: ""

    readonly property string saveDir: Quickshell.env("XDG_VIDEOS_DIR") || Quickshell.env("HOME") + "/Videos"

    function screenByName(name: string): var {
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === name)
                return Quickshell.screens[i];
        }
        return null;
    }

    function formatTime(sec: int): string {
        const h = Math.floor(sec / 3600), m = Math.floor(sec / 60) % 60, s = sec % 60;
        const mm = (h > 0 && m < 10 ? "0" : "") + m;
        return (h > 0 ? h + ":" : "") + mm + ":" + (s < 10 ? "0" : "") + s;
    }

    // Размер видео: высота limit (0 — исходный), ширина по пропорциям, чётные значения
    function targetSize(w: real, h: real, limit: int): size {
        const k = limit > 0 && limit < h ? limit / h : 1;
        return Qt.size(Math.round(w * k / 2) * 2, Math.round(h * k / 2) * 2);
    }

    // Исходное разрешение и до двух стандартных меньше него
    function resolutionOptions(w: real, h: real): var {
        const list = [0].concat([2160, 1440, 1080, 720].filter(l => l < h - 1).slice(0, 2));
        return list.map(l => {
            const t = targetSize(w, h, l);
            return { value: l, label: t.width + "×" + t.height };
        });
    }

    // Что сделать после запроса монитора: "open" — оверлей выбора,
    // "full" — сразу запись всего монитора, "probe" — только обновить режим монитора
    property string intent: "open"

    function query(kind: string): void {
        if (active || recording || focusedOutput.running)
            return;
        intent = kind;
        focusedOutput.running = true;
    }

    function open(): void { query("open"); }
    function probe(): void { query("probe"); }
    // Запуск с сохранёнными настройками (центр уведомлений): весь экран или выбор области
    function record(): void { query(cfg.fullscreen ? "full" : "open"); }

    function requestClose(): void {
        if (active)
            closing = true;
    }

    function close(): void {
        active = false;
        closing = false;
        if (pending) {
            proc.command = pending;
            pending = null;
            proc.running = true;
        }
    }

    // region — Qt.rect в глобальных логических координатах или null (весь монитор)
    function start(region: var): void {
        path = saveDir + "/recording-" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
        const cmd = ["gpu-screen-recorder", "-f", String(fps), "-q", cfg.quality, "-o", path];
        const srcW = region ? region.width * outputScale : modeWidth;
        const srcH = region ? region.height * outputScale : modeHeight;
        if (cfg.resolution > 0 && cfg.resolution < srcH - 1) {
            const t = targetSize(srcW, srcH, cfg.resolution);
            cmd.push("-s", t.width + "x" + t.height);
        }
        if (region) {
            // Кодеки требуют чётных размеров
            const w = Math.floor(region.width / 2) * 2, h = Math.floor(region.height / 2) * 2;
            cmd.push("-w", "region", "-region", w + "x" + h + "+" + Math.round(region.x) + "+" + Math.round(region.y));
        } else {
            cmd.push("-w", output);
        }
        const audio = [];
        if (cfg.systemAudio)
            audio.push("default_output");
        if (cfg.microphone)
            audio.push("default_input");
        if (audio.length > 0)
            cmd.push("-a", audio.join("|"));
        pending = cmd;
        requestClose();
    }

    function stop(): void {
        if (recording)
            proc.signal(2); // SIGINT — остановка с сохранением
    }

    function togglePause(): void {
        if (!recording)
            return;
        proc.signal(12); // SIGUSR2 — пауза/продолжение
        if (paused) {
            segStart = Date.now();
        } else {
            base += Date.now() - segStart;
            elapsed = Math.floor(base / 1000);
        }
        paused = !paused;
    }

    IpcHandler {
        target: "recorder"

        function start(): void { root.open(); }
        function stop(): void { root.stop(); }
        function pause(): void { root.togglePause(); }
        function toggle(): void {
            if (root.recording)
                root.stop();
            else if (root.active)
                root.requestClose();
            else
                root.open();
        }
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
                        const mode = out.modes?.[out.current_mode];
                        if (mode) {
                            root.refreshRate = Math.max(1, Math.round(mode.refresh_rate / 1000));
                            root.modeWidth = mode.width;
                            root.modeHeight = mode.height;
                        }
                        root.outputScale = out.logical?.scale ?? 1;
                        if (root.intent === "full") {
                            root.start(null);
                            root.close();
                        } else if (root.intent === "open") {
                            DropdownStack.dismissAll();
                            root.active = true;
                        }
                    }
                } catch (e) {
                    console.warn("recorder: не удалось разобрать focused-output:", e);
                }
            }
        }
    }

    Process {
        id: proc
        stderr: StdioCollector { id: errOut }

        onStarted: {
            root.paused = false;
            root.base = 0;
            root.elapsed = 0;
            root.segStart = Date.now();
        }
        onExited: code => {
            root.paused = false;
            if (code === 0) {
                if (root.cfg.notify)
                    Quickshell.execDetached(["notify-send", "Запись экрана", "Сохранено в " + root.path]);
            } else {
                console.warn("recorder: gpu-screen-recorder завершился с кодом", code, errOut.text);
                Quickshell.execDetached(["notify-send", "-u", "critical", "Запись экрана",
                                         "Ошибка записи (код " + code + ")\n" + errOut.text.trim().slice(-300)]);
            }
        }
    }

    // Обновляется только во время записи; elapsed меняется раз в секунду
    Timer {
        interval: 500
        repeat: true
        running: root.recording && !root.paused
        onTriggered: root.elapsed = Math.floor((root.base + Date.now() - root.segStart) / 1000)
    }

    RecorderOverlay {
        service: root
        screen: root.screenByName(root.output) ?? Quickshell.screens[0]
    }
}
