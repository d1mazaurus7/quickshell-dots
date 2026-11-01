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
import "../Bar/assistant" as Assistant
import "../Bar/osd" as Osd

Item {
    id: shellRoot
    // Экран, на котором открыт центр уведомлений ("" — закрыт)
    property string notiCenterOutput: ""

    // Окно настроек: одно на всю оболочку
    Settings.SettingsWindow { id: settingsWindow }
    Settings.SettingsIpc { window: settingsWindow }
    MusicEqualizer.MusicPlayerIpc { id: playerIpc }
    // Секундомер: qs ipc call stopwatch toggle
    Stopwatch.Stopwatch { id: stopwatchWindow }
    // Скриншоты: qs ipc call screenshot capture
    Screenshot.Screenshot {}
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
    // Окно Bar для каждого экрана
    Variants {
        model: Quickshell.screens
        
        PanelWindow {
            id: barWindow
            required property var modelData
            
            // Настройки окна
            implicitHeight: Tokens.scaled(56)
            color: "transparent"
            
            // Привязка к экрану
            screen: modelData

            // Контекст для модулей бара (shell/bar/BarModules.qml)
            readonly property var stopwatch: stopwatchWindow
            // Модуль музыки, если он размещён в баре; под ним открывается окно плеера
            property Item musicModule: null
            readonly property var musicEqualizer: musicEqualizerLoader.item

            function toggleMusicPlayer() {
                if (musicEqualizer && !musicEqualizer.recentlyDismissed())
                    musicEqualizer.open = !musicEqualizer.open;
            }

            // Пока плеер виден (включая анимацию закрытия), бар держит клавиатуру — иначе Esc
            // не доходит до плеера, а ранний сброс фокуса снимает захват и окно пропадает рывком
            WlrLayershell.keyboardFocus: musicEqualizer?.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
                left: Math.round(20 * Tokens.spacingScaleH)
                right: Math.round(20 * Tokens.spacingScaleH)
            }
            
            // Фон панели
            Rectangle {
                id: barBackground
                radius: Tokens.radius(20)
                topLeftRadius: 0
                topRightRadius: 0
                // Под открытым центром уведомлений бар переходит в панель без скругления
                bottomRightRadius: notiCenter.shown ? 0 : Tokens.radius(20)
                width: parent.width
                height: parent.height
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
                barHeight: barWindow.implicitHeight
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
