import QtQuick
import "../../shell/theme"

// Заливка снизу до level (0..1) с волной на кромке; волна колышется постоянно
Item {
    id: root

    property real level: 0
    property color color: Tokens.colors.primary
    property color backColor: Qt.alpha(Tokens.colors.primary, 0.4)
    readonly property real surfaceY: height * (1 - shownLevel)

    property real shownLevel: level
    property real phase: 0
    readonly property real amplitude: Tokens.scaled(4)

    Behavior on shownLevel { NumberAnimation { duration: Tokens.animationSlow * 3; easing.type: Easing.OutCubic } }

    FrameAnimation {
        running: root.visible
        onTriggered: {
            root.phase = (root.phase + frameTime * 1.6) % (Math.PI * 200);
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        // Растеризация в отдельном потоке: главный поток только записывает команды
        renderStrategy: Canvas.Threaded

        function wave(ctx, offset, lift, color) {
            const base = root.surfaceY - lift;
            const a = root.amplitude;
            const k = 2 * Math.PI / Math.max(1, width * 0.9);
            const ph = root.phase + offset;
            ctx.beginPath();
            ctx.moveTo(0, height);
            for (let x = 0; x <= width; x += 2) {
                const y = base + a * Math.sin(x * k + ph) + a * 0.4 * Math.sin(x * k * 1.7 - ph * 1.3);
                ctx.lineTo(x, y);
            }
            ctx.lineTo(width, height);
            ctx.closePath();
            ctx.fillStyle = color;
            ctx.fill();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            wave(ctx, Math.PI * 0.8, root.amplitude * 0.8, root.backColor.toString());
            wave(ctx, 0, 0, root.color.toString());
        }
    }
}
