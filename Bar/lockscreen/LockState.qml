import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../../shell/config"
import "../../shell/theme"

// Состояние лок-скрина: блокировка, ввод и проверка пароля, скриншоты фона, бездействие.
// IPC: qs ipc call lockscreen lock|unlock
Scope {
    id: root

    readonly property var cfg: Config.options.lockscreen

    // Экран заблокирован (поверхности ext-session-lock существуют)
    property bool locked: false
    // Идёт анимация разблокировки
    property bool unlocking: false
    // Набранный пароль; собирает поверхность блокировки
    property string input: ""
    property bool busy: false
    property bool failed: false

    // Метка скриншотов текущей блокировки ("" — скриншотов нет)
    property string stamp: ""
    property bool capturing: false
    readonly property string shotDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    // Текущие обои (set-wallpaper): ссылка на картинку или первый кадр видео и путь к исходному файлу
    readonly property string wallpaperPath: Quickshell.env("HOME") + "/.cache/current_wallpaper_link"
    // Видео-обои на момент блокировки; "" — картинка
    property string wallpaperVideo: ""

    property string pending: ""

    // Ввод на лок-скрине (клавиши, мышь): виджеты с hideOnIdle показываются снова
    signal activity()

    function shotPath(output: string): string {
        return stamp === "" ? "" : shotDir + "/qs-lock-" + output + "-" + stamp + ".ppm";
    }

    function lock(): void {
        if (!cfg.enabled || locked || capturing)
            return;
        if (!cfg.screenshotBackground) {
            start("");
            return;
        }
        // Кадр снимается до блокировки: после неё на мониторе уже лок-скрин
        capturing = true;
        shot.stamp = Date.now().toString(36);
        shot.command = ["sh", "-c",
            "d=$1; s=$2; shift 2; for o in \"$@\"; do grim -t ppm -o \"$o\" \"$d/qs-lock-$o-$s.ppm\" & done; wait",
            "sh", shotDir, shot.stamp].concat(Quickshell.screens.map(s => s.name));
        shot.running = true;
        shotTimeout.restart();
    }

    function finishCapture(s: string): void {
        if (!capturing)
            return;
        capturing = false;
        shotTimeout.stop();
        start(s);
    }

    function start(s: string): void {
        stamp = s;
        // Файл обоев читается только при блокировке
        if (cfg.wallpaperBackground && !cfg.screenshotBackground) {
            wallpaperFile.reload();
            const path = wallpaperFile.text().trim();
            wallpaperVideo = /\.(mp4|webm|mkv|mov|avi|m4v)$/i.test(path) ? path : "";
        } else {
            wallpaperVideo = "";
        }
        input = "";
        busy = false;
        failed = false;
        unlocking = false;
        locked = true;
    }

    function unlock(): void {
        if (!locked || unlocking)
            return;
        if (pam.active)
            pam.abort();
        busy = false;
        if (cfg.animation) {
            unlocking = true;
            unlockDelay.restart();
        } else {
            finishUnlock();
        }
    }

    function finishUnlock(): void {
        locked = false;
        unlocking = false;
        input = "";
        pending = "";
        if (stamp !== "")
            Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/qs-lock-*-\"$2\".ppm", "sh", shotDir, stamp]);
        stamp = "";
    }

    // Ввод с клавиатуры поверхности блокировки
    function typeText(text: string): void {
        if (!locked || unlocking)
            return;
        if (!cfg.requirePassword) {
            unlock();
            return;
        }
        if (busy)
            return;
        failed = false;
        input += text;
    }

    function backspace(): void {
        if (!busy)
            input = input.slice(0, -1);
    }

    function clear(): void {
        if (!busy)
            input = "";
    }

    function submit(): void {
        if (!locked || unlocking)
            return;
        if (!cfg.requirePassword) {
            unlock();
            return;
        }
        if (busy)
            return;
        if (cfg.customPasswordEnabled) {
            if (input === cfg.customPassword)
                unlock();
            else
                fail();
            return;
        }
        pending = input;
        busy = true;
        if (!pam.start())
            fail();
    }

    function fail(): void {
        busy = false;
        pending = "";
        input = "";
        failed = true;
        failReset.restart();
    }

    FileView {
        id: wallpaperFile
        path: Quickshell.env("HOME") + "/.cache/current_wallpaper"
        preload: false
        blockLoading: true
    }

    Process {
        id: shot
        property string stamp: ""
        onExited: code => root.finishCapture(code === 0 ? stamp : "")
    }
    Timer {
        id: shotTimeout
        interval: 1500
        onTriggered: root.finishCapture("")
    }
    Timer {
        id: unlockDelay
        interval: Tokens.animationSlow
        onTriggered: root.finishUnlock()
    }
    Timer {
        id: failReset
        interval: 2500
        onTriggered: root.failed = false
    }

    // Пароль пользователя: конфигурация PAM по умолчанию (login)
    PamContext {
        id: pam
        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.pending);
        }
        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success)
                root.unlock();
            else
                root.fail();
        }
        onError: root.fail()
    }

    IdleMonitor {
        id: idle
        enabled: root.cfg.enabled && root.cfg.idleLock
        timeout: root.cfg.idleTimeout * 60
        respectInhibitors: true
        onIsIdleChanged: if (idle.isIdle) root.lock()
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void { root.lock(); }
        // Аварийная разблокировка (например, с другого TTY)
        function unlock(): void { root.unlock(); }
    }
}
