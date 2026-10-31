import QtQuick

// Холст, накапливающий штрихи: каждый отрезок дорисовывается поверх уже нарисованного
Canvas {
    id: canvas

    property var queue: []

    // erase: стирает уже нарисованное (destination-out)
    function addSegment(x0: real, y0: real, x1: real, y1: real, width: real, color: color, erase: bool): void {
        queue.push({ x0: x0, y0: y0, x1: x1, y1: y1, width: width, color: color, erase: erase });
        requestPaint();
    }

    onPaint: {
        const ctx = getContext("2d");
        for (const s of queue) {
            ctx.globalCompositeOperation = s.erase ? "destination-out" : "source-over";
            ctx.strokeStyle = s.color;
            ctx.fillStyle = s.color;
            ctx.lineWidth = s.width;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            if (s.x0 === s.x1 && s.y0 === s.y1) {
                // Одиночный клик — точка
                ctx.arc(s.x0, s.y0, s.width / 2, 0, Math.PI * 2);
                ctx.fill();
            } else {
                ctx.moveTo(s.x0, s.y0);
                ctx.lineTo(s.x1, s.y1);
                ctx.stroke();
            }
        }
        queue = [];
    }
}
