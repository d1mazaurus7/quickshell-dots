import QtQuick
import "../../shell/theme"

// M3-фигура: «печенька» с lobes волнами или четырёхлучевая искра (sparkle).
// Рисуется один раз (перерисовка только при смене fill); постоянное вращение —
// на render-потоке (Animator), пока active; spin — дополнительный поворот
Item {
    id: shape
    property int size
    property int lobes: 8
    property real depth: 0.12
    property bool sparkle: false
    property color fill
    property int period: 60000
    property bool reverse: false
    property bool active: false
    property real spin: 0

    width: size
    height: size
    rotation: spin * (sparkle ? 2 : 0.7) * (reverse ? -1 : 1)

    onFillChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        RotationAnimator on rotation {
            from: shape.reverse ? 360 : 0
            to: shape.reverse ? 0 : 360
            // В 3 раза быстрее базового периода из пресета
            duration: shape.period / 3
            loops: Animation.Infinite
            running: shape.active
        }

        // Искры мягко мерцают
        SequentialAnimation on scale {
            running: shape.active && shape.sparkle
            loops: Animation.Infinite
            NumberAnimation { to: 1.25; duration: shape.period / 6; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.85; duration: shape.period / 6; easing.type: Easing.InOutSine }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.fillStyle = shape.fill;
            const c = width / 2;
            ctx.beginPath();
            if (shape.sparkle) {
                // Вогнутые грани: контрольная точка у центра
                for (let k = 0; k <= 4; k++) {
                    const a = k * Math.PI / 2;
                    const px = c + c * Math.cos(a), py = c + c * Math.sin(a);
                    if (k === 0) {
                        ctx.moveTo(px, py);
                    } else {
                        const m = a - Math.PI / 4;
                        ctx.quadraticCurveTo(c + c * 0.15 * Math.cos(m), c + c * 0.15 * Math.sin(m), px, py);
                    }
                }
            } else {
                const steps = 180;
                for (let i = 0; i <= steps; i++) {
                    const th = i / steps * Math.PI * 2;
                    const rr = c * (1 - shape.depth + shape.depth * (0.5 + 0.5 * Math.cos(shape.lobes * th)));
                    const px = c + rr * Math.cos(th), py = c + rr * Math.sin(th);
                    if (i === 0)
                        ctx.moveTo(px, py);
                    else
                        ctx.lineTo(px, py);
                }
            }
            ctx.closePath();
            ctx.fill();
        }
    }
}
