import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme" as Theme
import "theme"
import "config"
import "bar"
import "../Bar" as Bar
import "../modules/noti-center" as NotiCenter
import "../Bar/music_equalizer" as MusicEqualizer
import "../settings" as Settings
import "../modules/snow" as Snow
import "../Bar/stopwatch" as Stopwatch
import "../services/screenshot" as Screenshot
import "../services/niri" as Niri
import "../Bar/assistant" as Assistant
import "../Bar/news" as News
import "../Bar/weather" as Weather
import "../Bar/osd" as Osd
import "../Bar/power" as Power
import "../Bar/performance" as Performance
import "../Bar/clipboard" as Clipboard
import "../widgets" as Widgets

Item {
    id: shellRoot
    // Экран, на котором открыт центр уведомлений ("" — закрыт)
    property string notiCenterOutput: ""

    // Окно настроек: одно на всю оболочку
    Settings.SettingsWindow { id: settingsWindow }
    Settings.SettingsIpc { window: settingsWindow }
    // Буфер обмена: qs ipc call clipboard toggle
    Clipboard.Clipboard {}
    MusicEqualizer.MusicPlayerIpc { id: playerIpc }
    // Секундомер: qs ipc call stopwatch toggle
    Stopwatch.Stopwatch { id: stopwatchWindow }
    // Скриншоты: qs ipc call screenshot capture
    Screenshot.Screenshot {}
    // Защита от записи экрана: правила в niri/config/layer-rules.kdl
    Niri.NiriScreencastGuard {}
    // Чат с ИИ: qs ipc call assistant toggle
    Assistant.AssistantState { id: assistantState }
    Assistant.AssistantWindow { id: assistantWindow; chat: assistantState }
    Assistant.AssistantIpc {
        onRequested: (action, output) => {
            if (action === "close" || (action === "toggle" && assistantWindow.open)) {
                assistantWindow.open = false;
                return;
            }
            // Монитор меняется только у скрытого окна
            if (!assistantWindow.visible) {
                for (let i = 0; i < Quickshell.screens.length; i++)
                    if (Quickshell.screens[i].name === output)
                        assistantWindow.screen = Quickshell.screens[i];
            }
            assistantWindow.open = true;
        }
    }
    // Лента новостей: qs ipc call news toggle; грузит новости, только пока окно открыто
    News.NewsState { id: newsState; active: newsWindow.open }
    News.NewsWindow { id: newsWindow; news: newsState }
    News.NewsIpc {
        onRequested: (action, output) => {
            if (action === "close" || (action === "toggle" && newsWindow.open)) {
                newsWindow.open = false;
                return;
            }
            // Монитор меняется только у скрытого окна
            if (!newsWindow.visible) {
                for (let i = 0; i < Quickshell.screens.length; i++)
                    if (Quickshell.screens[i].name === output)
                        newsWindow.screen = Quickshell.screens[i];
            }
            newsWindow.open = true;
        }
    }
    // Погода: qs ipc call weather toggle|open|close|refresh
    Weather.WeatherIpc {}
    // Эквалайзер EasyEffects: одно состояние на все экраны
    MusicEqualizer.EqualizerState { id: equalizerState }
    // Сервер уведомлений и всплывающие уведомления
    NotiCenter.NotificationState {
        id: notificationState
        centerOpen: shellRoot.notiCenterOutput !== ""
    }
    NotiCenter.NotificationPopups { notifications: notificationState }
    // Снег на рабочем столе (по настройке)
    Snow.Snow {}
    // Окно громкости и Caps/Num Lock
    Osd.Osd {}
    // Меню питания: qs ipc call power toggle
    Power.PowerMenu {}
    // Профили производительности: qs ipc call performance toggle
    Performance.PerformanceMenu {}
    // Виджеты рабочего стола: qs ipc call widgets toggle
    Widgets.Widgets { equalizer: equalizerState }
    // Окно Bar для каждого экрана
    Variants {
        model: Quickshell.screens
        
        PanelWindow {
            id: barWindow
            required property var modelData
            
            // Настройки окна: отступ сверху плавающего бара входит в окно —
            // выпадающие окна крепятся к нижней кромке, наведение на отступ показывает бар
            readonly property int barHeight: BarStyle.barHeight
            implicitHeight: barHeight + BarStyle.marginTop
            color: "transparent"
            WlrLayershell.namespace: "qs:bar"

            // Привязка к экрану
            screen: modelData

            // Автоскрытие: бар выезжает при наведении и не прячется, пока открыто выпадающее окно
            readonly property bool revealed: !BarStyle.cfg.autoHide || barHover.hovered
                || BarStyle.openPopups > 0 || notiCenter.shown || hideDelay.running
            Timer {
                id: hideDelay
                interval: BarStyle.cfg.autoHideDelay
            }
            Connections {
                target: barHover
                function onHoveredChanged(): void {
                    if (!barHover.hovered)
                        hideDelay.restart();
                }
            }

            // Контекст для модулей бара (shell/bar/BarModules.qml)
            readonly property var stopwatch: stopwatchWindow
            // Модуль музыки, если он размещён в баре; под ним открывается окно плеера
            property Item musicModule: null
            readonly property var musicEqualizer: musicEqualizerLoader.item

            function toggleMusicPlayer() {
                if (musicEqualizer && !musicEqualizer.recentlyDismissed())
                    musicEqualizer.open = !musicEqualizer.open;
            }

            // Лента новостей открывается на экране этого бара
            readonly property var news: newsWindow
            function toggleNews() {
                if (!newsWindow.visible)
                    newsWindow.screen = modelData;
                newsWindow.open = !newsWindow.open;
            }

            // Пока плеер виден (включая анимацию закрытия), бар держит клавиатуру — иначе Esc
            // не доходит до плеера, а ранний сброс фокуса снимает захват и окно пропадает рывком.
            // То же для центра уведомлений: без этого поля ввода в нём не получают клавиши
            WlrLayershell.keyboardFocus: musicEqualizer?.visible || notiCenter.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                enabled: barWindow.musicEqualizer?.open ?? false
                onActivated: barWindow.musicEqualizer.open = false
            }
            
            anchors {
                top: true
                left: true
                right: true
            }
            
            margins {
                left: BarStyle.marginSide
                right: BarStyle.marginSide
            }

            // Наведение отслеживается на всём окне, в т.ч. пока бар спрятан
            Item {
                anchors.fill: parent
                HoverHandler { id: barHover }
            }

            // Бар целиком; при автоскрытии уезжает вверх
            Item {
                id: barContent
                width: parent.width
                height: barWindow.barHeight
                y: BarStyle.marginTop + (barWindow.revealed ? 0 : -(barWindow.barHeight + BarStyle.marginTop))
                opacity: barWindow.revealed ? 1 : 0
                Behavior on y { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                // Фон панели (в модульном стиле — только подложки модулей)
                Rectangle {
                    id: barBackground
                    visible: BarStyle.filled
                    radius: BarStyle.radius
                    topLeftRadius: BarStyle.roundTop ? BarStyle.radius : 0
                    topRightRadius: BarStyle.roundTop ? BarStyle.radius : 0
                    // Под открытым центром уведомлений бар переходит в панель без скругления
                    bottomRightRadius: notiCenter.shown ? 0 : BarStyle.radius
                    width: parent.width
                    height: parent.height
                    // Однотонный фон без размытия
                    color: Theme.Palette.background
                }

                // Окно для выбора обоев: только на первом экране, чтобы IPC "wallpaper" был один
                Loader {
                    active: barWindow.modelData === Quickshell.screens[0]
                    sourceComponent: Bar.SetWallpaper {
                        screen: barWindow.modelData
                        barHeight: barWindow.implicitHeight
                    }
                }

                // Центр уведомлений: якорь у правого края бара
                NotiCenter.NotiCenter {
                    id: notiCenter
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    screen: barWindow.modelData
                    // Без «ушей» панель отделена от бара отступом
                    barHeight: barWindow.implicitHeight + (BarStyle.filled ? 0 : BarStyle.popupGap)
                    openOutput: shellRoot.notiCenterOutput
                    ipcEnabled: barWindow.modelData === Quickshell.screens[0]
                    notifications: notificationState
                    onOpenOutputRequested: name => shellRoot.notiCenterOutput = name
                }

                // Окно плеера с эквалайзером под модулем музыки (только пока модуль в баре)
                Loader {
                    id: musicEqualizerLoader
                    active: barWindow.musicModule !== null
                    sourceComponent: MusicEqualizer.MusicEqualizer {
                        anchorItem: barWindow.musicModule
                        player: barWindow.musicModule?.player ?? null
                        equalizer: equalizerState
                        onDismissed: open = false
                    }
                }

                // IPC: открыть/закрыть плеер на мониторе в фокусе, на остальных — закрыть
                Connections {
                    target: playerIpc
                    function onRequested(action: string, output: string): void {
                        const musicEqualizer = barWindow.musicEqualizer;
                        if (!musicEqualizer)
                            return;
                        if (output !== barWindow.modelData.name)
                            musicEqualizer.open = false;
                        else
                            musicEqualizer.open = action === "toggle" ? !musicEqualizer.open : action === "open";
                    }
                }

                // Содержимое панели: блоки слева, посередине и справа (Config.options.bar)
                BarSection {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Math.round(10 * Tokens.spacingScaleH)
                    bar: barWindow
                    ids: Config.options.bar.left
                }

                // Центр бара, не зависит от ширины боковых блоков
                BarSection {
                    anchors.centerIn: barBackground
                    bar: barWindow
                    ids: Config.options.bar.center
                }

                BarSection {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    // Модули расталкиваются влево, освобождая место под центр уведомлений
                    anchors.rightMargin: Math.round(10 * Tokens.spacingScaleH) + notiCenter.reserve
                    bar: barWindow
                    ids: Config.options.bar.right
                }
            }
        }
    }
}
