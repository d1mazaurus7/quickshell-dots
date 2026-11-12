import QtQuick

// Холст, накапливающий штрихи: каждый отрезок дорисовывается поверх уже нарисованного
Canvas {
    id: canvas

    property var queue: []
    // Все отрезки с номером штриха — для отмены
    property var history: []
    // Следующая отрисовка — с нуля по history
    property bool redrawAll: false
    // Штрихи рисуются только внутри этой области (пустая — без ограничения)
    property rect clipRect: Qt.rect(0, 0, 0, 0)

    // erase: стирает уже нарисованное (destination-out)
    function addSegment(x0: real, y0: real, x1: real, y1: real, width: real, color: color, erase: bool, stroke: int): void {
        const s = { x0: x0, y0: y0, x1: x1, y1: y1, width: width, color: color, erase: erase, stroke: stroke,
                    clip: Qt.rect(clipRect.x, clipRect.y, clipRect.width, clipRect.height) };
        history.push(s);
        queue.push(s);
        requestPaint();
    }

    function removeStroke(stroke: int): void {
        const kept = history.filter(s => s.stroke !== stroke);
        if (kept.length === history.length)
            return;
        history = kept;
        redrawAll = true;
        requestPaint();
    }

    onPaint: {
        const ctx = getContext("2d");
        if (redrawAll) {
            ctx.globalCompositeOperation = "source-over";
            ctx.clearRect(0, 0, width, height);
            queue = history.slice();
            redrawAll = false;
        }
        for (const s of queue) {
            ctx.save();
            if (s.clip.width > 0 && s.clip.height > 0) {
                ctx.beginPath();
                ctx.rect(s.clip.x, s.clip.y, s.clip.width, s.clip.height);
                ctx.clip();
            }
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
            ctx.restore();
        }
        queue = [];
    }
}
