import QtQuick
import Quickshell
import Quickshell.Io
import "../../theme" as Theme
import "../../shell/theme"

// Кнопка с защитой от случайного нажатия: срабатывает, только если её удерживать,
// пока она не заполнится «жидкостью» с волной на поверхности
Item {
    id: root

    property string icon
    property string label
    property bool showLabel: false
    property int holdTime: 1000
    property int size: Tokens.scaled(64)

    readonly property var colors: Theme.Palette
    property real progress: 0
    property real phase: 0
    property bool done: false

    // Кнопка заполнилась — владелец выполняет действие
    signal activated()

    // Сброс после закрытия окна
    function reset(): void {
        fill.stop();
        drain.stop();
        done = false;
        progress = 0;
    }

    function press(): void {
        if (done)
            return;
        drain.stop();
        // Длительность — по оставшейся части, чтобы скорость заполнения была постоянной
        fill.duration = Math.max(1, holdTime * (1 - progress));
        fill.restart();
    }

    function release(): void {
        if (done)
            return;
        fill.stop();
        drain.restart();
    }

    implicitWidth: size
    implicitHeight: column.implicitHeight

    NumberAnimation {
        id: fill
        target: root
        property: "progress"
        to: 1
        onFinished: {
            if (root.progress < 1)
                return;
            root.done = true;
            root.activated();
        }
    }

    NumberAnimation {
        id: drain
        target: root
        property: "progress"
        to: 0
        duration: Tokens.animationMedium
        easing.type: Easing.OutCubic
    }

    NumberAnimation on phase {
        from: 0
        to: Math.PI * 2
        duration: 1200
        loops: Animation.Infinite
        running: root.progress > 0 && root.visible
    }

    // Звук заряда, перезапускается по кругу, пока кнопка зажата
    Process {
        id: charge
        command: ["pw-play", Quickshell.shellPath("assets/sounds/charge_loop.wav")]
        running: fill.running
        onExited: if (fill.running) running = true
    }

    Column {
        id: column
        spacing: Tokens.spacingSmallV

        Item {
            width: root.size
            height: root.size
            scale: area.pressed && !root.done ? 0.96 : 1
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radiusLarge
                color: area.pressed ? root.colors.surface_container_highest
                     : area.containsMouse ? root.colors.surface_container_high
                     : root.colors.surface_container
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            }

            Canvas {
                id: liquid
                anchors.fill: parent

                readonly property real level: height * (1 - root.progress)
                // Волна стихает у пустой и полной кнопки
                readonly property real amp: Tokens.scaled(4) * Math.min(1, Math.sin(Math.PI * root.progress) * 3)

                onLevelChanged: requestPaint()
                onAmpChanged: requestPaint()
                Connections {
                    target: root
                    function onPhaseChanged(): void { liquid.requestPaint(); }
                }

                function wave(ctx, shift: real, alpha: real): void {
                    const c = root.colors.primary;
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, alpha);
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (let x = 0; x <= width; x += 2)
                        ctx.lineTo(x, level + amp * Math.sin(x / width * Math.PI * 3 + root.phase + shift));
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fill();
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (root.progress <= 0)
                        return;
                    ctx.beginPath();
                    ctx.roundedRect(0, 0, width, height, Tokens.radiusLarge, Tokens.radiusLarge);
                    ctx.clip();
                    wave(ctx, Math.PI, 0.45);
                    wave(ctx, 0, 1);
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.colors.on_surface
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(root.size * 0.42)
            }

            // Значок над жидкостью — контрастным цветом
            Item {
                y: liquid.level
                width: parent.width
                height: parent.height - y
                clip: true

                Text {
                    x: (parent.width - width) / 2
                    y: (root.size - height) / 2 - parent.y
                    text: root.icon
                    color: root.colors.on_primary
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Math.round(root.size * 0.42)
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: root.press()
                onReleased: root.release()
                onCanceled: root.release()
            }
        }

        Text {
            width: root.size
            visible: root.showLabel
            horizontalAlignment: Text.AlignHCenter
            text: root.label
            color: root.colors.on_surface_variant
            font: Tokens.fontSmall
            elide: Text.ElideRight
        }
    }
}
