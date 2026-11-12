pragma Singleton
import QtQuick
import Quickshell
import "../theme"
import "../../modules/tray" as Tray
import "../../modules/bluetooth" as Bluetooth
import "../../modules/workspaces" as Workspaces
import "../../modules/music_player" as MusicPlayer
import "../../modules/time" as Time
import "../../modules/volume" as Volume
import "../../Bar/stopwatch" as Stopwatch
import "../../Bar/news" as News
import "../../Bar/weather" as Weather

// Реестр модулей бара: id (ключ в Config.options.bar), название для настроек, компонент.
// Новый модуль — импорт, Component и строка в list.
// Компонент получает required property bar — окно бара (Shell.qml):
// barHeight, modelData (экран), stopwatch, musicModule, toggleMusicPlayer(), news (окно новостей), toggleNews().
Singleton {
    id: root

    readonly property var list: [
        { id: "workspaces", title: "Рабочие столы", component: workspaces },
        { id: "musicPlayer", title: "Музыкальный плеер", component: musicPlayer },
        { id: "stopwatch", title: "Секундомер", component: stopwatch },
        { id: "volume", title: "Звук", component: volume },
        { id: "time", title: "Время", component: time },
        { id: "tray", title: "Трей", component: tray },
        { id: "bluetooth", title: "Bluetooth", component: bluetooth },
        { id: "news", title: "Новости", component: news },
        { id: "weather", title: "Погода", component: weather }
    ]

    function find(id) {
        return list.find(m => m.id === id) ?? null;
    }

    Component {
        id: workspaces
        Workspaces.Workspaces {
            required property var bar
            output: bar.modelData.name
            barHeight: bar.barHeight
        }
    }

    Component {
        id: musicPlayer
        MusicPlayer.MusicPlayerModule {
            id: music
            required property var bar
            size: bar.barHeight - Tokens.scaled(8)
            onOpenRequested: bar.toggleMusicPlayer()
            // Окно плеера в баре открывается под этим модулем
            Component.onCompleted: bar.musicModule = music
            Component.onDestruction: if (bar.musicModule === music) bar.musicModule = null
        }
    }

    Component {
        id: stopwatch
        // Виден, пока секундомер запущен или на паузе
        Stopwatch.StopwatchWidget {
            required property var bar
            stopwatch: bar.stopwatch
            barHeight: bar.barHeight
        }
    }

    Component {
        id: volume
        Volume.Volume {
            required property var bar
            barHeight: bar.barHeight
        }
    }

    Component {
        id: time
        Time.Time {
            required property var bar
        }
    }

    Component {
        id: tray
        Tray.Tray {
            required property var bar
            barHeight: bar.barHeight
        }
    }

    Component {
        id: bluetooth
        Bluetooth.Bluetooth {
            required property var bar
            barHeight: bar.barHeight
        }
    }

    Component {
        id: news
        News.NewsModule {
            required property var bar
            barHeight: bar.barHeight
            active: bar.news.open
            onOpenRequested: bar.toggleNews()
        }
    }

    Component {
        id: weather
        Weather.WeatherModule {
            required property var bar
            output: bar.modelData.name
            barHeight: bar.barHeight
        }
    }
}
