import QtQuick
import "../../theme" as Theme
import "../../shell/theme"

// Таймлайн трека: проигранная часть — две бегущие волны (акцентная спереди, светлая позади),
// оставшаяся — ровная дорожка. Перетаскивание ручки перематывает трек.
Item {
    id: root

    // Позиция 0..1
    property real value: 0
    property bool playing: false
    property bool seekable: true
    // false — проигранная часть ровной полосой
    property bool wavy: true
    // "wave" — две залитые волны | "material" — одна волнистая линия в стиле Material You
    property string style: "wave"

    signal seekRequested(real value)

    property real dragValue: 0
    readonly property bool dragging: area.pressed
    readonly property real shown: dragging ? dragValue : Math.max(0, Math.min(1, value))

    // Позиция приходит раз в полсекунды — сглаживаем движение
    property real smooth: shown
    Behavior on smooth {
        enabled: !root.dragging
        NumberAnimation { duration: 500 }
    }

    // Волна затухает на паузе и при перетаскивании
    property real amplitude: wavy && playing && !dragging ? 1 : 0
    Behavior on amplitude { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
    property real phase: 0

    readonly property real knobSize: Tokens.scaled(16)

    implicitHeight: Tokens.scaled(32)

    onSmoothChanged: canvas.requestPaint()
    onAmplitudeChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onStyleChanged: canvas.requestPaint()

    // Фаза растёт по реальному времени кадра, а не по таймеру — волна идёт без рывков
    FrameAnimation {
        running: root.visible && root.amplitude > 0
        onTriggered: {
            root.phase += frameTime * 3.6;
            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        property color accent: Theme.Palette.primary
        property color light: Theme.Palette.on_surface
        onAccentChanged: requestPaint()
        onLightChanged: requestPaint()

        // Залитая волна: гребень колышется у нижнего края дорожки, заливка уходит вниз.
        // По краям амплитуда плавно сходит на нет.
        function wave(ctx, from, to, base, bottom, amp, freq, phase, fill) {
            ctx.beginPath();
            ctx.moveTo(from, bottom);
            for (let x = from; x <= to; x += 1) {
                const env = Math.max(0, Math.min(1, (x - from) / 10, (to - x) / 10));
                ctx.lineTo(x, base + Math.sin(x * freq + phase) * amp * env);
            }
            ctx.lineTo(to, bottom);
            ctx.closePath();
            ctx.fillStyle = fill;
            ctx.fill();
        }

        // Material You: проигранная часть — волнистая линия со скруглёнными концами,
        // оставшаяся — ровная линия той же толщины
        function paintMaterial(ctx) {
            const pad = root.knobSize / 2;
            const lineW = Tokens.scaled(4);
            const mid = height / 2;
            const px = pad + root.smooth * (width - pad * 2);
            const amp = Tokens.scaled(3) * root.amplitude;
            const freq = 2 * Math.PI / Tokens.scaled(32);

            ctx.lineWidth = lineW;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            ctx.strokeStyle = Qt.alpha(light, 0.2).toString();
            ctx.beginPath();
            ctx.moveTo(px, mid);
            ctx.lineTo(width - pad, mid);
            ctx.stroke();

            if (px - pad < 1) return;

            ctx.strokeStyle = accent.toString();
            ctx.beginPath();
            ctx.moveTo(pad, mid);
            for (let x = pad; x <= px; x += 1) {
                const env = Math.max(0, Math.min(1, (x - pad) / 10, (px - x) / 10));
                ctx.lineTo(x, mid + Math.sin(x * freq - root.phase) * amp * env);
            }
            ctx.stroke();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            if (root.style === "material") {
                paintMaterial(ctx);
                return;
            }

            const pad = root.knobSize / 2;
            const trackH = Tokens.scaled(6);
            const top = height / 2 - trackH / 2;
            const px = pad + root.smooth * (width - pad * 2);
            const maxAmp = Tokens.scaled(4);
            const amp = maxAmp * root.amplitude;
            const freq = 0.10;

            // Дорожка
            ctx.fillStyle = Qt.alpha(light, 0.2).toString();
            ctx.beginPath();
            ctx.roundedRect(pad, top, width - pad * 2, trackH, trackH / 2, trackH / 2);
            ctx.fill();

            if (px - pad < 1) return;

            // Низ заливки совпадает с низом дорожки, гребни выходят над её верхним краем
            const base = top;
            const bottom = top + trackH;

            // Акцентная волна
            const grad = ctx.createLinearGradient(pad, 0, px, 0);
            grad.addColorStop(0, accent.toString());
            grad.addColorStop(1, Qt.alpha(accent, 0.3).toString());
            wave(ctx, pad, px, base, bottom, amp, freq, root.phase, grad);

            // Светлая волна поверх — полупрозрачная, с другой частотой и фазой
            const lightGrad = ctx.createLinearGradient(pad, 0, px, 0);
            lightGrad.addColorStop(0, Qt.alpha(light, 0.35).toString());
            lightGrad.addColorStop(1, Qt.alpha(light, 0.08).toString());
            wave(ctx, pad, px, base, bottom, amp * 0.6, freq * 1.3, root.phase * 0.8 + 1.5, lightGrad);
        }
    }

    // Ручка
    Rectangle {
        x: root.knobSize / 2 + root.smooth * (root.width - root.knobSize) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.knobSize
        height: root.knobSize
        radius: height / 2
        visible: root.seekable
        color: area.containsMouse || area.pressed ? Theme.Palette.primary_fixed : Theme.Palette.primary
        scale: area.pressed ? 1.3 : area.containsMouse ? 1.12 : 1

        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.seekable
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function valueAt(mx: real): real {
            return Math.max(0, Math.min(1, (mx - root.knobSize / 2) / (root.width - root.knobSize)));
        }
        onPressed: mouse => root.dragValue = valueAt(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.dragValue = valueAt(mouse.x); }
        onReleased: root.seekRequested(root.dragValue)
    }
}
