pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../theme" as Theme
import "../../shell/config"
import "../../shell/theme"

// Секундомер, выезжающий из боковой кромки экрана.
// IPC: qs ipc call stopwatch toggle|open|close
PanelWindow {
    id: root

    property bool open: false
    readonly property bool onRight: Config.options.stopwatch.side === "right"

    // Состояние секундомера
    property bool running: false
    property double accumulated: 0
    property double startedAt: 0
    property double now: Date.now()
    property var laps: []
    // Номер последнего круга и время его отметки: удаление круга их не меняет
    property int lapCount: 0
    property double lastLapTotal: 0
    // Индекс зажатой кнопки (-1 — нет)
    property int pressedButton: -1
    readonly property double elapsed: accumulated + (running ? now - startedAt : 0)

    function toggleRun(): void {
        now = Date.now();
        if (running) {
            accumulated += now - startedAt;
            running = false;
        } else {
            startedAt = now;
            running = true;
        }
    }

    function reset(): void {
        running = false;
        accumulated = 0;
        laps = [];
        lapCount = 0;
        lastLapTotal = 0;
    }

    function lap(): void {
        if (elapsed <= 0)
            return;
        now = Date.now();
        lapCount += 1;
        laps = [{ number: lapCount, total: elapsed, split: elapsed - lastLapTotal }].concat(laps);
        lastLapTotal = elapsed;
    }

    function removeLap(index: int): void {
        laps = laps.filter((_, i) => i !== index);
    }

    function pad(n: int): string {
        return n < 10 ? "0" + n : "" + n;
    }

    function format(ms: real): string {
        const s = Math.floor(ms / 1000);
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        return (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(s % 60);
    }

    function centis(ms: real): string {
        return "." + pad(Math.floor(ms / 10) % 100);
    }

    // Геометрия
    readonly property var colors: Theme.Palette
    readonly property int contentWidth: Tokens.scaled(320)
    readonly property int contentHeight: Tokens.scaled(420)
    readonly property int padding: Tokens.spacingLarge
    readonly property int radius: Tokens.radius(16)
    readonly property int earRadius: Tokens.radius(28)
    property real revealWidth: open ? contentWidth : 0

    Behavior on revealWidth { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    WlrLayershell.namespace: "qs:stopwatch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors.left: !onRight
    anchors.right: onRight

    implicitWidth: contentWidth
    implicitHeight: contentHeight + earRadius * 2
    visible: open || revealWidth > 0

    IpcHandler {
        target: "stopwatch"

        function toggle(): void { root.open = !root.open; }
        function open(): void { root.open = true; }
        function close(): void { root.open = false; }
    }

    // Тишина держит аудиовыход активным, пока окно открыто:
    // иначе выход засыпает и короткий звук клика теряется
    Process {
        running: root.visible
        command: ["pw-play", "--raw", "--rate", "48000", "--channels", "2", "--format", "s16", "/dev/zero"]
    }

    Timer {
        interval: 30
        repeat: true
        running: root.running && root.visible
        onTriggered: root.now = Date.now()
    }

    Shortcut {
        sequence: "Space"
        enabled: root.open
        onActivated: root.toggleRun()
    }

    Shortcut {
        sequence: "Ctrl+C"
        enabled: root.open
        onActivated: root.reset()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.open = false
    }

    // Фон: вогнутые «уши» у кромки экрана, скруглённые углы снаружи.
    // Нарисован для левой стороны, для правой отражается.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.x: root.width / 2; xScale: root.onRight ? -1 : 1 }

        ShapePath {
            id: bg

            readonly property real w: root.revealWidth
            readonly property real h: root.height
            readonly property real er: root.earRadius
            readonly property real erX: Math.min(er, w / 2)
            readonly property real br: root.radius
            readonly property real brX: Math.min(br, w / 2)

            strokeWidth: -1
            fillColor: root.colors.background

            startX: 0; startY: 0
            PathArc { x: bg.erX; y: bg.er; radiusX: bg.erX; radiusY: bg.er; direction: PathArc.Counterclockwise }
            PathLine { x: bg.w - bg.brX; y: bg.er }
            PathArc { x: bg.w; y: bg.er + bg.br; radiusX: bg.brX; radiusY: bg.br }
            PathLine { x: bg.w; y: bg.h - bg.er - bg.br }
            PathArc { x: bg.w - bg.brX; y: bg.h - bg.er; radiusX: bg.brX; radiusY: bg.br }
            PathLine { x: bg.erX; y: bg.h - bg.er }
            PathArc { x: 0; y: bg.h; radiusX: bg.erX; radiusY: bg.er; direction: PathArc.Counterclockwise }
        }
    }

    // Содержимое стоит на месте и открывается вместе с фоном
    Item {
        id: reveal
        x: root.onRight ? root.width - root.revealWidth : 0
        y: root.earRadius
        width: root.revealWidth
        height: root.contentHeight
        clip: true

        ColumnLayout {
            x: root.padding - reveal.x
            y: root.padding
            width: root.contentWidth - root.padding * 2
            height: root.contentHeight - root.padding * 2
            spacing: Tokens.spacingMediumV

            Text {
                text: "Секундомер"
                color: root.colors.on_surface
                font: Tokens.fontLarge
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Row {
                    id: timeRow
                    anchors.centerIn: parent

                    Text {
                        id: mainTime
                        text: root.format(root.elapsed)
                        color: root.colors.on_surface
                        font.family: Tokens.fontLarge.family
                        font.pixelSize: Tokens.scaled(64)
                    }

                    Text {
                        anchors.baseline: mainTime.baseline
                        text: root.centis(root.elapsed)
                        color: root.colors.on_surface_variant
                        font.family: Tokens.fontLarge.family
                        font.pixelSize: Tokens.scaled(28)
                    }
                }

                // Круги, новые сверху
                ListView {
                    anchors.top: timeRow.bottom
                    anchors.topMargin: Tokens.spacingMediumV
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    clip: true
                    spacing: Tokens.spacingSmallV
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.laps

                    delegate: Item {
                        id: lapItem
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        implicitHeight: Tokens.scaled(36)

                        // Свайп в сторону больше трети ширины удаляет круг
                        Rectangle {
                            id: lapCard
                            width: parent.width
                            height: parent.height
                            radius: Tokens.radiusMedium
                            color: swipe.pressed ? root.colors.surface_container_high : root.colors.surface_container
                            opacity: 1 - Math.min(1, Math.abs(x) / width)
                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                            NumberAnimation {
                                id: settle
                                target: lapCard
                                property: "x"
                                duration: Tokens.animationFast
                                easing.type: Easing.OutCubic
                                onFinished: {
                                    if (Math.abs(lapCard.x) >= lapCard.width)
                                        root.removeLap(lapItem.index);
                                }
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.spacingMedium
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Круг " + lapItem.modelData.number
                                color: root.colors.on_surface_variant
                                font: Tokens.fontMedium
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.spacingMedium
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+" + root.format(lapItem.modelData.split) + root.centis(lapItem.modelData.split)
                                      + "   " + root.format(lapItem.modelData.total) + root.centis(lapItem.modelData.total)
                                color: root.colors.on_surface
                                font: Tokens.fontMedium
                            }
                        }

                        MouseArea {
                            id: swipe
                            anchors.fill: parent
                            preventStealing: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            drag.target: lapCard
                            drag.axis: Drag.XAxis
                            drag.minimumX: -lapCard.width
                            drag.maximumX: lapCard.width
                            drag.threshold: Tokens.scaled(4)
                            onReleased: {
                                const x = lapCard.x;
                                settle.to = Math.abs(x) > lapCard.width / 3 ? (x > 0 ? lapCard.width : -lapCard.width) : 0;
                                settle.start();
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacingLarge

                StopwatchButton { index: 0; icon: "↺"; onClicked: root.reset() }
                StopwatchButton {
                    index: 1
                    icon: root.running ? "❚❚" : "▶"
                    primary: true
                    onClicked: root.toggleRun()
                }
                StopwatchButton {
                    index: 2
                    icon: "⚑"
                    enabled: root.running
                    onClicked: root.lap()
                }
            }
        }
    }

    component StopwatchButton: Rectangle {
        id: button
        property int index
        property string icon
        property bool primary: false
        signal clicked()

        // Зажатая кнопка расширяется, соседние сжимаются
        implicitWidth: Tokens.scaled(72 + (root.pressedButton === index ? 16 : root.pressedButton >= 0 ? -8 : 0))
        implicitHeight: Tokens.scaled(56)
        Behavior on implicitWidth { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        radius: Tokens.radiusLarge
        opacity: enabled ? 1 : 0.4
        color: primary
            ? (area.pressed ? root.colors.primary_fixed_dim : area.containsMouse ? root.colors.primary_fixed : root.colors.primary)
            : (area.pressed ? root.colors.surface_bright : area.containsMouse ? root.colors.surface_container_highest : root.colors.surface_container_high)
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.primary ? root.colors.on_primary : root.colors.on_surface
            font.family: Tokens.fontLarge.family
            font.pixelSize: Tokens.scaled(22)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                root.pressedButton = button.index;
                Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]);
            }
            onReleased: root.pressedButton = -1
            onCanceled: root.pressedButton = -1
            onClicked: button.clicked()
        }
    }
}
