import QtQuick
import "../../shell/theme"

// Квадратная сетка на весь экран, шаг step в лог. px
Canvas {
    id: root

    property real step: 40
    property color lineColor: Qt.alpha(Tokens.colors.on_surface, 0.12)

    onStepChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (step < 2)
            return;
        ctx.strokeStyle = lineColor.toString();
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let x = step; x < width; x += step) {
            ctx.moveTo(Math.round(x) + 0.5, 0);
            ctx.lineTo(Math.round(x) + 0.5, height);
        }
        for (let y = step; y < height; y += step) {
            ctx.moveTo(0, Math.round(y) + 0.5);
            ctx.lineTo(width, Math.round(y) + 0.5);
        }
        ctx.stroke();
    }
}
