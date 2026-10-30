pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../theme" as Theme
import "../../shell/theme"

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
    // Радиус нижних углов бара: уши не должны заходить на них.
    property int barRadius: Tokens.radius(20)
    property string fontFamily: "JetBrains Mono"
    property int titleFontSize: 14
    property int emptyFontSize: 12
    property int animDuration: 220
    property int hoverDuration: 120

    property bool open: false
    // Момент последнего закрытия попапа композитором: клик по кнопке,
    // который закрыл попап (клик вне его), не должен открывать его снова.
    property double closedAt: 0

    implicitWidth: button.implicitWidth
    implicitHeight: buttonHeight

    function toggle() {
        if (!open && Date.now() - closedAt < 200)
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

    PopupWindow {
        id: popup

        // Окно остаётся видимым, пока идёт анимация закрытия.
        visible: root.open || menu.revealHeight > 0
        grabFocus: true
        color: "transparent"
        implicitWidth: root.menuWidth + root.earRadius * 2
        implicitHeight: menu.fullHeight

        // Верх попапа совпадает с нижней кромкой бара, тело — под кнопкой,
        // но не ближе к краю бара, чем его нижнее скругление.
        anchor.window: root.QsWindow.window
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.onAnchoring: {
            const win = root.QsWindow.window;
            const pos = root.QsWindow.itemPosition(button);
            const minX = root.barRadius + root.earRadius;
            const maxX = win.width - minX - root.menuWidth;
            const bodyX = Math.max(minX, Math.min(maxX, pos.x + button.width / 2 - root.menuWidth / 2));
            popup.anchor.rect.x = bodyX - root.earRadius;
            popup.anchor.rect.y = win.height - 1;
        }

        // Закрытие композитором (клик вне попапа).
        onVisibleChanged: {
            if (!visible && root.open) {
                root.open = false;
                root.closedAt = Date.now();
            }
        }

        Item {
            id: menu

            readonly property real fullHeight: Math.min(content.implicitHeight + root.menuPadding * 2, root.menuMaxHeight)
            property real revealHeight: root.open ? fullHeight : 0

            width: parent.width
            height: parent.height

            Behavior on revealHeight { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

            // Фон цвета бара: вогнутые скругления сверху переходят в бар,
            // снизу — обычные углы. Пока окно раскрывается, вертикальные
            // радиусы сжимаются вместе с высотой.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: bg

                    readonly property real w: menu.width
                    readonly property real h: menu.revealHeight
                    readonly property real er: root.earRadius
                    readonly property real erY: Math.min(er, h / 2)
                    readonly property real br: root.menuRadius
                    readonly property real brY: Math.min(br, h / 2)

                    strokeWidth: -1
                    fillColor: Theme.Palette.background

                    startX: 0; startY: 0
                    PathLine { x: bg.w; y: 0 }
                    PathArc { x: bg.w - bg.er; y: bg.erY; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
                    PathLine { x: bg.w - bg.er; y: bg.h - bg.brY }
                    PathArc { x: bg.w - bg.er - bg.br; y: bg.h; radiusX: bg.br; radiusY: bg.brY }
                    PathLine { x: bg.er + bg.br; y: bg.h }
                    PathArc { x: bg.er; y: bg.h - bg.brY; radiusX: bg.br; radiusY: bg.brY }
                    PathLine { x: bg.er; y: bg.erY }
                    PathArc { x: 0; y: 0; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
                }
            }

            Item {
                x: root.earRadius
                width: root.menuWidth
                height: menu.revealHeight
                clip: true

                Flickable {
                    width: parent.width - root.menuPadding * 2
                    height: menu.fullHeight - root.menuPadding * 2
                    x: root.menuPadding
                    y: root.menuPadding
                    contentHeight: content.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

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
    }
}
