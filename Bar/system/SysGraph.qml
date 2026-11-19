pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// График истории за range секунд. Серии: { key, label, icon, color, max, fmt }; max 0 — общий авто-масштаб.
// Перерисовка раз на отсчёт; между отсчётами холст плавно сдвигается без перерисовки
Rectangle {
    id: root

    required property var sys
    property string icon
    property string title
    property var series: []
    property int range: 300
    property bool live: visible
    property bool smoothLines: true
    property bool tooltip: true
    property var axisFmt: f => Math.round(f * 100) + "%"
    property var off: ({})
    readonly property var colors: Tokens.colors

    readonly property int samples: Math.max(2, Math.round(range * 1000 / sys.interval) + 1)
    readonly property real step: plot.width / (samples - 1)
    property real autoMax: 1

    radius: Tokens.radius(24)
    color: Qt.alpha(colors.surface_container, 0.92)

    function shown(s: var): bool {
        return !off[s.key];
    }

    function refresh(): void {
        if (!live)
            return;
        canvas.requestPaint();
        slide.restart();
        if (hoverArea.containsMouse)
            hoverArea.update();
    }

    Connections {
        target: root.sys
        function onSampled(): void { root.refresh(); }
    }
    onLiveChanged: if (live) canvas.requestPaint()
    onRangeChanged: canvas.requestPaint()
    onOffChanged: canvas.requestPaint()
    onSmoothLinesChanged: canvas.requestPaint()
    onColorsChanged: canvas.requestPaint()

    // Заголовок и переключатели серий
    Row {
        id: head
        x: Tokens.spacingLarge
        y: Tokens.spacingLargeV
        height: Tokens.scaled(30)
        spacing: Tokens.spacingMedium

        Rectangle {
            width: Tokens.scaled(28)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            color: root.colors.primary_container
            SysIcon {
                anchors.centerIn: parent
                icon: root.icon
                size: Tokens.scaled(16)
                filled: hoverArea.containsMouse
                hovered: hoverArea.containsMouse
                color: root.colors.on_primary_container
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            font.family: Tokens.fontLarge.family
            font.pixelSize: Tokens.fontLarge.pixelSize
            font.weight: Font.DemiBold
            color: root.colors.on_surface
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacingLarge
        anchors.verticalCenter: head.verticalCenter
        spacing: Tokens.spacingSmall
        layoutDirection: Qt.RightToLeft

        Repeater {
            model: root.series
            SysChip {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                accent: modelData.color
                checked: root.shown(modelData)
                onToggled: {
                    const o = Object.assign({}, root.off);
                    o[modelData.key] = !o[modelData.key];
                    root.off = o;
                }
            }
        }
    }

    // Ось Y
    Column {
        id: axis
        anchors.left: parent.left
        anchors.leftMargin: Tokens.spacingLarge
        y: plot.y - Tokens.scaled(7)
        width: Tokens.scaled(52)
        spacing: 0
        Repeater {
            model: 5
            Text {
                required property int index
                width: axis.width
                height: plot.height / 4
                text: root.axisFmt(root.autoMax * (1 - index / 4))
                font: Tokens.fontSmall
                color: root.colors.on_surface_variant
                opacity: 0.8
            }
        }
    }

    Item {
        id: plot
        anchors.left: axis.right
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.bottom: xAxis.top
        anchors.leftMargin: Tokens.spacingSmall
        anchors.rightMargin: Tokens.spacingLarge
        anchors.topMargin: Tokens.spacingLargeV
        anchors.bottomMargin: Tokens.spacingSmallV
        clip: true
        onWidthChanged: canvas.requestPaint()
        onHeightChanged: canvas.requestPaint()

        Repeater {
            model: 5
            Rectangle {
                required property int index
                y: Math.round(index * (plot.height - 1) / 4)
                width: plot.width
                height: 1
                color: root.colors.outline_variant
                opacity: index === 4 ? 0.8 : 0.35
            }
        }

        Canvas {
            id: canvas
            property real offset: 0
            x: -root.step + offset
            width: plot.width + root.step
            height: plot.height
            renderStrategy: Canvas.Cooperative

            NumberAnimation on offset {
                id: slide
                running: false
                from: root.step
                to: 0
                duration: root.sys.interval
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const h = root.sys.history, cnt = root.sys.count, n = root.samples + 1;
                const W = width, H = height, sx = root.step;
                if (cnt < 2 || W <= 0 || H <= 0)
                    return;
                // Не больше точки на 3 px: отсчёты группируются по абсолютному номеру, корзины стабильны
                const k = Math.max(1, Math.ceil(n / (W / 3)));
                const lines = [];
                let amax = 0;
                for (const s of root.series) {
                    const a = h[s.key];
                    if (!root.shown(s) || !a || a.length < 2)
                        continue;
                    const len = a.length, first = Math.max(0, len - n - k);
                    const pts = [];
                    let sum = 0, num = 0, absSum = 0, bucket = -1;
                    for (let i = len - 1; i >= first; i--) {
                        const abs = cnt - len + i, b = Math.floor(abs / k);
                        if (b !== bucket && num) {
                            pts.push([absSum / num, sum / num]);
                            sum = num = absSum = 0;
                        }
                        bucket = b;
                        sum += a[i]; absSum += abs; num++;
                    }
                    if (num)
                        pts.push([absSum / num, sum / num]);
                    if (!(s.max > 0))
                        for (const p of pts) amax = Math.max(amax, p[1]);
                    lines.push({ s, pts });
                }
                const auto = amax > 0 ? amax * 1.15 : 1;
                root.autoMax = root.series.some(s => !(s.max > 0)) ? auto : 1;
                const lw = Math.max(1.5, Tokens.scaled(2));
                ctx.lineWidth = lw;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                for (const { s, pts } of lines) {
                    const mx = s.max > 0 ? s.max : auto;
                    const P = pts.map(p => [W - (cnt - 1 - p[0]) * sx, H - lw - Math.max(0, Math.min(1, p[1] / mx)) * (H - lw * 2)]);
                    ctx.beginPath();
                    ctx.moveTo(P[0][0], P[0][1]);
                    for (let i = 1; i < P.length; i++) {
                        if (root.smoothLines && i < P.length - 1)
                            ctx.quadraticCurveTo(P[i][0], P[i][1], (P[i][0] + P[i + 1][0]) / 2, (P[i][1] + P[i + 1][1]) / 2);
                        else
                            ctx.lineTo(P[i][0], P[i][1]);
                    }
                    ctx.strokeStyle = s.color;
                    ctx.stroke();
                    ctx.lineTo(P[P.length - 1][0], H);
                    ctx.lineTo(P[0][0], H);
                    ctx.closePath();
                    const g = ctx.createLinearGradient(0, 0, 0, H);
                    g.addColorStop(0, Qt.alpha(s.color, 0.22));
                    g.addColorStop(1, Qt.alpha(s.color, 0));
                    ctx.fillStyle = g;
                    ctx.fill();
                }
            }
        }

        // Наведение: линия и подсказка со значениями
        Rectangle {
            id: cursor
            visible: root.tooltip && hoverArea.containsMouse && hoverArea.values.length > 0
            x: Math.round(hoverArea.mouseX)
            width: 1
            height: plot.height
            color: root.colors.on_surface_variant
            opacity: 0.6
        }

        Rectangle {
            id: tip
            visible: cursor.visible
            readonly property bool flip: hoverArea.mouseX + width + Tokens.spacingLarge > plot.width
            x: flip ? hoverArea.mouseX - width - Tokens.spacingMedium : hoverArea.mouseX + Tokens.spacingMedium
            y: Tokens.spacingSmallV
            width: tipCol.implicitWidth + Tokens.spacingMedium * 2
            height: tipCol.implicitHeight + Tokens.spacingSmallV * 2
            radius: Tokens.radius(12)
            color: root.colors.inverse_surface
            Behavior on x { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            Column {
                id: tipCol
                anchors.centerIn: parent
                spacing: Tokens.scaled(2)
                Text {
                    text: hoverArea.ago
                    font: Tokens.fontSmall
                    color: Qt.alpha(root.colors.inverse_on_surface, 0.7)
                }
                Repeater {
                    model: hoverArea.values
                    Row {
                        required property var modelData
                        spacing: Tokens.spacingSmall
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Tokens.scaled(8); height: width; radius: width / 2
                            color: modelData.color
                        }
                        Text {
                            text: modelData.label + ": " + modelData.text
                            font: Tokens.fontSmall
                            color: root.colors.inverse_on_surface
                        }
                    }
                }
            }
        }

        MouseArea {
            id: hoverArea
            property var values: []
            property string ago: ""
            anchors.fill: parent
            hoverEnabled: root.tooltip
            acceptedButtons: Qt.NoButton

            function update(): void {
                const h = root.sys.history, cnt = root.sys.count;
                const back = Math.round((plot.width - mouseX) / root.step);
                const abs = cnt - 1 - back;
                const out = [];
                for (const s of root.series) {
                    const a = h[s.key];
                    if (!root.shown(s) || !a)
                        continue;
                    const i = a.length - 1 - back;
                    if (i >= 0 && abs >= 0)
                        out.push({ label: s.label, color: s.color, text: s.fmt(a[i]) });
                }
                values = out;
                const sec = Math.round(back * root.sys.interval / 1000);
                ago = sec <= 0 ? "сейчас" : sec < 60 ? sec + " с назад" : Math.floor(sec / 60) + " мин " + (sec % 60) + " с назад";
            }
            onPositionChanged: update()
        }
    }

    Item {
        id: xAxis
        anchors.left: plot.left
        anchors.right: plot.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.spacingMediumV
        height: Tokens.scaled(16)

        Repeater {
            model: 5
            Text {
                required property int index
                readonly property int sec: Math.round(root.range * (1 - index / 4))
                x: index * xAxis.width / 4 - (index === 0 ? 0 : index === 4 ? width : width / 2)
                text: sec === 0 ? "сейчас" : sec < 60 ? "−" + sec + " с" : "−" + +(sec / 60).toFixed(1) + " мин"
                font: Tokens.fontSmall
                color: root.colors.on_surface_variant
                opacity: 0.8
            }
        }
    }
}
