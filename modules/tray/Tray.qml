pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../theme" as Theme
import "../../shell/theme"
import "../../components/animations" as Anim

// Кнопка "Tray" с выпадающим списком элементов SystemTray.
// Использование в bar:
//   import "../modules/tray" as Tray
//   Tray.Tray {}
Item {
    id: root

    // Локальные параметры оформления
    // Кнопка оформлена как кнопки внутри меню (TrayItem: stop*).
    // Высота бара; кнопка вписывается в неё с отступом vMargin
    property real barHeight: 40
    property real vMargin: 6
    property int buttonPaddingH: 12
    readonly property int buttonHeight: Math.max(0, barHeight - vMargin * 2)
    property int buttonRadius: Tokens.radius(8)
    readonly property int buttonFontSize: Math.round(buttonHeight * 0.43)
    // Иконки-предпросмотр запущенных программ справа от "Tray".
    readonly property int previewIconSize: Math.round(buttonHeight * 0.57)
    property int previewSpacing: 6
    property int menuWidth: 320
    property int menuMaxHeight: 420
    property int menuRadius: Tokens.radius(16)
    property int menuPadding: 12
    property int menuSpacing: 6
    // Радиус вогнутых скруглений ("ушей") в месте стыка окна с баром.
    property int earRadius: Tokens.radius(16)
    property string fontFamily: "JetBrains Mono"
    property int titleFontSize: 14
    property int emptyFontSize: 12
    property int animDuration: 220
    property int hoverDuration: 120

    property bool open: false

    implicitWidth: button.implicitWidth
    implicitHeight: buttonHeight

    function toggle() {
        if (!open && dropdown.recentlyDismissed())
            return;
        open = !open;
    }

    // Завершает процесс элемента трея: имя сервиса находится через
    // StatusNotifierWatcher по совпадению Id, PID — через org.freedesktop.DBus.
    // Если совпадений нет или их несколько, kill не выполняется.
    function stopItem(itemId) {
        stopProc.exec(["sh", "-c", stopScript, "sh", itemId]);
    }

    readonly property string stopScript: `
target="$1"
pids=""
for e in $(busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems | cut -d" " -f3-); do
  e=\${e#\\"}; e=\${e%\\"}
  case "$e" in */*) name=\${e%%/*}; path=/\${e#*/} ;; *) name=$e; path=/StatusNotifierItem ;; esac
  id=$(busctl --user get-property "$name" "$path" org.kde.StatusNotifierItem Id 2>/dev/null) || continue
  [ "$id" = "s \\"$target\\"" ] || continue
  pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$name" | cut -d" " -f2)
  case " $pids " in *" $pid "*) ;; *) pids="$pids $pid" ;; esac
done
set -- $pids
[ $# -eq 1 ] || { echo "tray: \\"$target\\": PID не найден или неоднозначен ($#)" >&2; exit 1; }
kill -TERM "$1"
`

    Process {
        id: stopProc
        stderr: StdioCollector {
            onStreamFinished: if (text.length > 0) console.warn(text.trim())
        }
    }

    Rectangle {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: buttonRow.implicitWidth + root.buttonPaddingH * 2
        height: root.buttonHeight
        radius: root.buttonRadius
        color: buttonArea.pressed ? Theme.Palette.secondary_container
             : (buttonArea.containsMouse || root.open) ? Theme.Palette.surface_bright
             : Theme.Palette.surface_container_highest

        Behavior on color { ColorAnimation { duration: root.hoverDuration; easing.type: Easing.OutCubic } }
        Behavior on implicitWidth { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            spacing: root.previewSpacing

            Text {
                id: label
                text: "Tray"
                color: buttonArea.pressed ? Theme.Palette.on_secondary_container
                     : root.open ? Theme.Palette.primary
                     : Theme.Palette.on_surface
                font.family: root.fontFamily
                font.pixelSize: root.buttonFontSize

                Behavior on color { ColorAnimation { duration: root.hoverDuration } }
            }

            Repeater {
                model: SystemTray.items

                IconImage {
                    required property var modelData
                    implicitSize: root.previewIconSize
                    source: modelData.icon
                }
            }
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }

    Anim.BarDropdown {
        id: dropdown
        anchorItem: button
        open: root.open
        contentWidth: root.menuWidth
        padding: root.menuPadding
        radius: root.menuRadius
        earRadius: root.earRadius
        animDuration: root.animDuration
        onDismissed: root.open = false

        Flickable {
            width: parent.width
            height: Math.min(content.implicitHeight, root.menuMaxHeight - root.menuPadding * 2)
            contentHeight: content.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: content
                width: parent.width
                spacing: root.menuSpacing

                Text {
                    text: "Active programs"
                    color: Theme.Palette.on_surface
                    font.family: root.fontFamily
                    font.pixelSize: root.titleFontSize
                    font.bold: true
                    Layout.bottomMargin: root.menuSpacing
                }

                Text {
                    visible: SystemTray.items.values.length === 0
                    text: "Нет элементов"
                    color: Theme.Palette.on_surface_variant
                    font.family: root.fontFamily
                    font.pixelSize: root.emptyFontSize
                }

                Repeater {
                    model: SystemTray.items

                    TrayItem {
                        required property var modelData
                        Layout.fillWidth: true
                        item: modelData
                        onStopRequested: root.stopItem(modelData.id)
                    }
                }
            }
        }
    }
}
