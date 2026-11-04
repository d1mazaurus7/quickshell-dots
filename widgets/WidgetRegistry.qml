import QtQuick
// Импорт каталогов типов: иначе Quickshell не сканирует их и локальные типы недоступны
import "music" as MusicWidget
import "sysmon" as SysmonWidget

// Доступные типы виджетов. Размеры — лог. px до масштабирования (Tokens.scaled).
// defaults — настройки нового экземпляра; отсутствующие у экземпляра ключи берутся отсюда
QtObject {
    id: root

    // Дефолты виджетов потребления; kind — ресурс, не меняется
    readonly property var sysmonDefaults: ({
        showWave: true,
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
        root.sysmon("sysDisk", "disk", "Диск", "hard_drive"),
        root.sysmon("sysRam", "ram", "RAM", "memory_alt"),
        root.sysmon("sysCpu", "cpu", "CPU", "memory"),
        root.sysmon("sysGpu", "gpu", "GPU", "developer_board")
    ]

    function find(type: string): var {
        return types.find(t => t.type === type) ?? null;
    }
}
