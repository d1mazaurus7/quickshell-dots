import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../theme" as Theme
import "theme"
import "../Bar" as Bar
import "../modules/tray" as Tray
import "../modules/bluetooth" as Bluetooth
import "../modules/workspaces"
import "../modules/music_player" as MusicPlayer
import "../modules/noti-center" as NotiCenter
import "../Bar/music_equalizer" as MusicEqualizer
import "../settings" as Settings
import "../modules/snow" as Snow
import "../modules/time" as Time
import "../Bar/stopwatch" as Stopwatch
import "../services/screenshot" as Screenshot

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

            // Пока плеер виден (включая анимацию закрытия), бар держит клавиатуру — иначе Esc
            // не доходит до плеера, а ранний сброс фокуса снимает захват и окно пропадает рывком
            WlrLayershell.keyboardFocus: musicEqualizer.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Shortcut {
                sequence: "Escape"
                enabled: musicEqualizer.open
                onActivated: musicEqualizer.open = false
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

            // Время: центр бара, не зависит от ширины боковых блоков
            Time.Time { anchors.centerIn: barBackground }

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

            // Окно плеера с эквалайзером под модулем музыки
            MusicEqualizer.MusicEqualizer {
                id: musicEqualizer
                anchorItem: musicModule
                player: musicModule.player
                equalizer: equalizerState
                onDismissed: open = false
            }

            // IPC: открыть/закрыть плеер на мониторе в фокусе, на остальных — закрыть
            Connections {
                target: playerIpc
                function onRequested(action: string, output: string): void {
                    if (output !== barWindow.modelData.name)
                        musicEqualizer.open = false;
                    else
                        musicEqualizer.open = action === "toggle" ? !musicEqualizer.open : action === "open";
                }
            }

            // Содержимое панели (блоки слева, посередине и справа)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(10 * Tokens.spacingScaleH)
                // Модули расталкиваются влево, освобождая место под центр уведомлений
                anchors.rightMargin: Math.round(10 * Tokens.spacingScaleH) + notiCenter.reserve
                
                // Блок слева
                RowLayout {
                    Layout.alignment: Qt.AlignLeft
                    Workspaces {
                        output: barWindow.modelData.name
                        barHeight: barWindow.implicitHeight
                    }
                    // Раскладка клавиатуры
                    // Интернет
                    MusicPlayer.MusicPlayerModule {
                        id: musicModule
                        size: barWindow.implicitHeight - Tokens.scaled(8)
                        onOpenRequested: {
                            if (!musicEqualizer.recentlyDismissed())
                                musicEqualizer.open = !musicEqualizer.open;
                        }
                    }
                    // Секундомер: виден, пока запущен или на паузе
                    Stopwatch.StopwatchWidget {
                        stopwatch: stopwatchWindow
                        barHeight: barWindow.implicitHeight
                    }

                    // Звук
                    // Мониторинг системы (CPU, RAM)
                    // Уведомления
                }
                
                // Блок посередине
                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    // Активное окно
                    // Время, дата — по центру бара (ниже, вне RowLayout)
                    // Погода
                }
                
                // Блок справа
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Tray.Tray { barHeight: barWindow.implicitHeight }
                    Bluetooth.Bluetooth { barHeight: barWindow.implicitHeight }
                }
            }
        }
    }
}
