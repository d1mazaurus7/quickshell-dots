import QtQuick
// Импорт каталогов типов: иначе Quickshell не сканирует их и локальные типы недоступны
import "cava" as CavaWidget
import "clock" as ClockWidget
import "music" as MusicWidget
import "sysmon" as SysmonWidget
import "timer" as TimerWidget
import "lock" as LockWidget
import "media" as MediaWidget

// Доступные типы виджетов. Размеры — лог. px до масштабирования (Tokens.scaled).
// defaults — настройки нового экземпляра; отсутствующие у экземпляра ключи берутся отсюда
QtObject {
    id: root

    // Дефолты виджетов потребления; kind — ресурс, не меняется
    readonly property var sysmonDefaults: ({
        showWave: true,
        blurFree: false,
        showUsed: true,
        showFree: true,
        usageTab: true,
        graphTab: true,
        graphSpan: 60,
        interval: 1000
    })

    function sysmon(type: string, kind: string, title: string, icon: string): var {
        return {
            type: type,
            title: title,
            icon: icon,
            component: Qt.resolvedUrl("sysmon/SysmonWidget.qml"),
            settingsComponent: Qt.resolvedUrl("sysmon/SysmonWidgetSettings.qml"),
            width: 130, height: 170,
            minWidth: 100, maxWidth: 320,
            minHeight: 120, maxHeight: 400,
            defaults: Object.assign({ kind: kind }, sysmonDefaults)
        };
    }

    readonly property var types: [
        {
            type: "musicPlayer",
            title: "Музыкальный плеер",
            icon: "music_note",
            component: Qt.resolvedUrl("music/MusicPlayerWidget.qml"),
            settingsComponent: Qt.resolvedUrl("music/MusicPlayerWidgetSettings.qml"),
            width: 400, height: 150,
            minWidth: 280, maxWidth: 720,
            minHeight: 120, maxHeight: 360,
            defaults: {
                showArtist: true,
                showTime: true,
                timelineStyle: "material",
                wavyTimeline: true,
                coverBackground: true,
                backgroundBlur: true,
                cava: false,
                cavaStyle: "wave",
                danceGifEnabled: false,
                danceGif: "",
                equalizer: false,
                lyrics: false,
                lyricsFontSize: 15,
                lyricsAlign: "center",
                lyricsScroll: true,
                lyricsSeek: true
            }
        },
        {
            type: "cavaVisualizer",
            title: "Визуализатор",
            icon: "graphic_eq",
            component: Qt.resolvedUrl("cava/CavaWidget.qml"),
            settingsComponent: Qt.resolvedUrl("cava/CavaWidgetSettings.qml"),
            width: 360, height: 120,
            minWidth: 40, maxWidth: 3840,
            minHeight: 24, maxHeight: 2160,
            // Края тянутся мышью в редакторе; кнопки отражения пишут flipH/flipV
            resizable: true,
            flippable: true,
            defaults: { background: true, blur: true, behindBlur: false, colorless: false, glow: false, style: "wave", barCount: 24, flipH: false, flipV: false, lower: false }
        },
        {
            type: "clock",
            title: "Часы",
            icon: "schedule",
            component: Qt.resolvedUrl("clock/ClockWidget.qml"),
            settingsComponent: Qt.resolvedUrl("clock/ClockWidgetSettings.qml"),
            width: 260, height: 110,
            minWidth: 40, maxWidth: 3840,
            minHeight: 24, maxHeight: 2160,
            resizable: true,
            defaults: { layout: "full", align: "center", showSeconds: false, blinkSeparator: false, textBlur: false, whiteText: false, background: false, backgroundBlur: false }
        },
        {
            type: "timer",
            title: "Таймер",
            icon: "timer",
            component: Qt.resolvedUrl("timer/TimerWidget.qml"),
            settingsComponent: Qt.resolvedUrl("timer/TimerWidgetSettings.qml"),
            width: 300, height: 260,
            minWidth: 160, maxWidth: 800,
            minHeight: 140, maxHeight: 700,
            resizable: true,
            defaults: { transparentBackground: false, outline: true, backgroundBlur: false, whiteText: false, smoothChange: true, blinkSeparator: false, showSeconds: true, showMilliseconds: false }
        },
        {
            type: "media",
            title: "Медиа",
            icon: "photo_library",
            component: Qt.resolvedUrl("media/MediaWidget.qml"),
            settingsComponent: Qt.resolvedUrl("media/MediaWidgetSettings.qml"),
            width: 240, height: 240,
            minWidth: 40, maxWidth: 3840,
            minHeight: 40, maxHeight: 2160,
            resizable: true,
            defaults: { source: "", shape: "rect", radius: 0.15 }
        },
        root.sysmon("sysDisk", "disk", "Диск", "hard_drive"),
        root.sysmon("sysRam", "ram", "RAM", "memory_alt"),
        root.sysmon("sysCpu", "cpu", "CPU", "memory"),
        root.sysmon("sysGpu", "gpu", "GPU", "developer_board"),
        // Только лок-скрин (lockOnly); single — не больше одного экземпляра
        {
            type: "lockUser",
            title: "Пользователь",
            icon: "account_circle",
            lockOnly: true,
            component: Qt.resolvedUrl("lock/LockUserWidget.qml"),
            settingsComponent: Qt.resolvedUrl("lock/LockUserWidgetSettings.qml"),
            width: 160, height: 200,
            minWidth: 80, maxWidth: 480,
            minHeight: 80, maxHeight: 560,
            resizable: true,
            defaults: {
                showPhoto: true, photo: "", radius: 1, photoSize: 1, photoOpacity: 1,
                borderWidth: 0, borderColor: "primary", shadow: false,
                showName: true, nameSource: "user", customName: "", nameSize: 22, nameBold: false,
                subtitle: "", namePosition: "below", nameGap: 12, whiteText: false,
                hideOnIdle: false, idleDelay: 10
            }
        },
        {
            type: "lockPassword",
            title: "Поле пароля",
            icon: "password",
            lockOnly: true,
            single: true,
            component: Qt.resolvedUrl("lock/LockPasswordWidget.qml"),
            settingsComponent: Qt.resolvedUrl("lock/LockPasswordWidgetSettings.qml"),
            width: 320, height: 56,
            minWidth: 200, maxWidth: 720,
            minHeight: 40, maxHeight: 120,
            resizable: true,
            defaults: {
                style: "filled", glassOpacity: 0.35, radius: 1, borderWidth: 2, opacity: 1,
                showIcon: true, showButton: true, showHint: true,
                placeholder: "", anyKeyText: "", failText: "",
                align: "left", textSize: 0.32, boldText: false, whiteText: false,
                dotShape: "circle", shake: true,
                hideOnIdle: false, idleDelay: 10
            }
        }
    ]

    function find(type: string): var {
        return types.find(t => t.type === type) ?? null;
    }
}
