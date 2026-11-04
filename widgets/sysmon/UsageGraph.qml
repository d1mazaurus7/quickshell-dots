pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// График доли 0..1: values — история, новая точка въезжает справа
// плавной прокруткой за interval мс. Сетка: уровни 25/50/75%, время — доли span секунд
Item {
    id: root

    property var values: []
    property int count: 60
    property int interval: 1000
    property int span: 60
    property color color: Tokens.colors.primary
    readonly property color gridColor: Qt.alpha(Tokens.colors.outline_variant, 0.6)
    readonly property int markSize: Tokens.scaled(Tokens.typography.size - 4)

    property real shift: 1
    readonly property real lineWidth: Tokens.scaled(3)
    property real step: width / Math.max(1, count - 1)
    Behavior on step { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

    onValuesChanged: {
        scroll.stop();
        shift = 0;
        scroll.duration = interval;
        scroll.start();
    }
    onShiftChanged: if (visible) canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()
    onStepChanged: canvas.requestPaint()

    function ago(sec: real): string {
        if (sec < 60)
            return "−" + Math.round(sec) + " с";
        const m = sec / 60;
        return "−" + (Number.isInteger(m) ? m : m.toFixed(1)) + " мин";
    }

    NumberAnimation {
        id: scroll
        target: root
        property: "shift"
        from: 0
        to: 1
    }

    // Область графика: под ней подписи времени
    Item {
        id: plot
        anchors.fill: parent
        anchors.bottomMargin: times.height + Tokens.spacingSmallV

        Repeater {
            model: [0.25, 0.5, 0.75]

            Item {
                id: level
                required property real modelData
                width: plot.width
                y: root.lineWidth + (1 - modelData) * (plot.height - root.lineWidth * 2)

                Rectangle {
                    width: parent.width
                    height: 1
                    color: root.gridColor
                }
                Text {
                    anchors.bottom: parent.top
                    x: Tokens.spacingSmall
                    text: Math.round(level.modelData * 100) + "%"
                    color: Tokens.colors.on_surface_variant
                    font.family: Tokens.typography.family
                    font.pixelSize: root.markSize
                }
            }
        }

        Repeater {
            model: [0.25, 0.5, 0.75]

            Rectangle {
                required property real modelData
                x: Math.round(plot.width * modelData)
                width: 1
                height: plot.height
                color: root.gridColor
            }
        }
    }

    Item {
        id: times
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Tokens.spacingSmall
        anchors.rightMargin: Tokens.spacingSmall
        height: nowMark.implicitHeight

        Text {
            text: root.ago(root.span)
            color: Tokens.colors.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: root.markSize
        }
        Text {
            x: Math.round(parent.width / 2 - width / 2)
            text: root.ago(root.span / 2)
            color: Tokens.colors.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: root.markSize
        }
        Text {
            id: nowMark
            anchors.right: parent.right
            text: "сейчас"
            color: Tokens.colors.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: root.markSize
        }
    }

    Canvas {
        id: canvas
        anchors.fill: plot
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const v = root.values;
            const n = v.length;
            if (n < 2)
                return;

            const pad = root.lineWidth;
            const h = height - pad * 2;
            const pts = [];
            for (let i = 0; i < n; i++)
                pts.push([width + (i - n + 2 - root.shift) * root.step, pad + (1 - v[i]) * h]);

            // Сглаживание: квадратичные кривые через середины отрезков
            const trace = () => {
                ctx.moveTo(pts[0][0], pts[0][1]);
                for (let i = 1; i < n - 1; i++)
                    ctx.quadraticCurveTo(pts[i][0], pts[i][1], (pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2);
                ctx.lineTo(pts[n - 1][0], pts[n - 1][1]);
            };

            ctx.beginPath();
            trace();
            ctx.lineTo(pts[n - 1][0], height);
            ctx.lineTo(pts[0][0], height);
            ctx.closePath();
            const grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, Qt.alpha(root.color, 0.3).toString());
            grad.addColorStop(1, Qt.alpha(root.color, 0.02).toString());
            ctx.fillStyle = grad;
            ctx.fill();

            ctx.beginPath();
            trace();
            ctx.lineWidth = root.lineWidth;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.strokeStyle = root.color.toString();
            ctx.stroke();
        }
    }
}
