pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/theme"
import "../controls"

// Часы: строка «11:25» или столбец «11 / 25»; размер шрифта подгоняется под окно
Item {
    id: root

    property var settings: ({})
    property bool editing: false

    readonly property bool background: settings.background === true
    readonly property Item blurItem: background && settings.backgroundBlur === true ? card : null
    readonly property bool textBlur: settings.textBlur === true && !background
    readonly property Region blurShape: textBlur ? shapeRegion : null

    readonly property bool vertical: settings.layout === "vertical"
    readonly property bool seconds: settings.showSeconds === true
    readonly property bool blink: seconds && settings.blinkSeparator === true

    function pad(n: int): string {
        return n < 10 ? "0" + n : String(n);
    }
    readonly property var groups: seconds
        ? [pad(clock.hours), pad(clock.minutes), pad(clock.seconds)]
        : [pad(clock.hours), pad(clock.minutes)]

    SystemClock {
        id: clock
        precision: root.seconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // Метрики на базовом размере 100 px: из них считается масштаб под окно
    readonly property font baseFont: Qt.font({ family: Tokens.typography.family, pixelSize: 100 })
    FontMetrics {
        id: baseMetrics
        font: root.baseFont
    }
    // Вызовы методов FontMetrics не следят за font: зависимость задаётся через baseMetrics.font
    readonly property real baseDigitW: baseMetrics.font, Math.max(...("0123456789".split("").map(c => baseMetrics.advanceWidth(c))))
    readonly property real baseSepW: baseMetrics.font, baseMetrics.advanceWidth(":")
    readonly property real baseCapH: baseMetrics.font, baseMetrics.tightBoundingRect("0").height
    readonly property real baseSlotH: baseCapH * 1.3

    readonly property int count: groups.length
    readonly property real contentBaseW: vertical ? 2 * baseDigitW : count * 2 * baseDigitW + (count - 1) * baseSepW
    readonly property real contentBaseH: vertical ? count * baseSlotH : baseSlotH
    readonly property real fit: Math.max(0.08, Math.min(
        (width - 2 * Tokens.spacingMedium) / Math.max(1, contentBaseW),
        (height - 2 * Tokens.spacingMedium) / Math.max(1, contentBaseH)))

    readonly property font clockFont: Qt.font({ family: Tokens.typography.family, pixelSize: Math.max(8, Math.floor(100 * fit)) })
    readonly property real digitW: baseDigitW * fit
    readonly property real sepW: baseSepW * fit
    readonly property real slotH: baseSlotH * fit
    readonly property real capH: baseCapH * fit
    // «Стеклянный» текст: полупрозрачная заливка поверх размытия по форме символов
    readonly property bool glass: settings.textBlur === true
    readonly property color baseColor: settings.whiteText === true ? "#ffffff" : Tokens.colors.primary
    readonly property color textColor: glass ? Qt.alpha(baseColor, 0.22) : baseColor

    // Маски символов для размытия по их форме: { "0": [{ x, y, w, h }], ... },
    // x — от начала символа, y — от базовой линии
    property var masks: ({})
    Canvas {
        id: maskCanvas
        width: Math.ceil(Math.max(root.digitW, root.sepW))
        height: Math.ceil(root.slotH)
        readonly property int px: root.clockFont.pixelSize
        onPxChanged: if (root.textBlur) requestPaint()
        Connections {
            target: root
            function onTextBlurChanged() { if (root.textBlur) maskCanvas.requestPaint(); }
        }
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            if (!ctx || w < 1 || h < 1)
                return;
            ctx.font = px + "px \"" + Tokens.typography.family + "\"";
            ctx.textBaseline = "alphabetic";
            ctx.fillStyle = "#ffffff";
            const by = Math.round(h / 2 + root.capH / 2);
            // getImageData работает в физических пикселях: масштаб — по пробному квадрату 10×10
            ctx.clearRect(0, 0, w, h);
            ctx.fillRect(0, 0, 10, 10);
            const probe = ctx.getImageData(0, 0, 40, 1).data;
            let pw = 0;
            while (pw < 40 && probe[pw * 4 + 3] > 0)
                pw++;
            const scale = Math.max(1, pw) / 10;
            const out = {};
            for (const c of "0123456789:") {
                ctx.clearRect(0, 0, w, h);
                const dx = Math.round((w - ctx.measureText(c).width) / 2);
                ctx.fillText(c, dx, by);
                const img = ctx.getImageData(0, 0, Math.ceil(w * scale), Math.ceil(h * scale));
                const d = img.data;
                const iw = img.width, ih = img.height;
                const k = iw / w;
                const band = Math.max(2, Math.round(ih / 48));
                const tol = Math.max(1, Math.round(1.5 * k));
                const rects = [];
                let open = [];
                for (let y = 0; y < ih; y += band) {
                    const bh = Math.min(band, ih - y);
                    const next = [];
                    let start = -1;
                    for (let x = 0; x <= iw; x++) {
                        // Столбец полосы закрашен, если закрашена хотя бы половина его пикселей
                        let hit = 0;
                        for (let yy = y; x < iw && yy < y + bh; yy++)
                            if (d[(yy * iw + x) * 4 + 3] > 110)
                                hit++;
                        const on = hit * 2 >= bh && hit > 0;
                        if (on && start < 0) {
                            start = x;
                        } else if (!on && start >= 0) {
                            // Полоса продолжает прямоугольник предыдущей, если почти совпадает
                            // Склейка с допуском ~1.5 px: меньше полос — меньше стыков в размытии
                            let r = open.find(o => o.y + o.h === y && Math.abs(o.x - start) <= tol && Math.abs(o.x + o.w - x) <= tol);
                            if (r) {
                                const right = Math.max(r.x + r.w, x);
                                r.x = Math.min(r.x, start);
                                r.w = right - r.x;
                                r.h += bh;
                            } else {
                                r = { x: start, y: y, w: x - start, h: bh };
                                rects.push(r);
                            }
                            next.push(r);
                            start = -1;
                        }
                    }
                    open = next;
                }
                // Целые логические пиксели: без дробных стыков
                out[c] = rects.map(r => {
                    const x0 = Math.round(r.x / k - dx), x1 = Math.round((r.x + r.w) / k - dx);
                    const y0 = Math.round(r.y / k - by), y1 = Math.round((r.y + r.h) / k - by);
                    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
                }).filter(r => r.w > 0 && r.h > 0);
            }
            ctx.clearRect(0, 0, w, h);
            root.masks = out;
        }
    }

    Region {
        id: shapeRegion
        regions: root.glyphRegions
    }
    property var glyphRegions: []
    function collectRegions(): void {
        const list = [];
        for (let i = 0; i < groupsRepeater.count; i++) {
            const row = groupsRepeater.itemAt(i);
            if (!row)
                continue;
            for (const g of row.children)
                if (g.visible && g.region)
                    list.push(g.region);
        }
        glyphRegions = list;
    }
    onVerticalChanged: Qt.callLater(collectRegions)

    WidgetCard {
        id: card
        anchors.fill: parent
        color: !root.background || root.blurItem ? "transparent" : Tokens.colors.surface_container
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

        Grid {
            id: grid
            columns: root.vertical ? 1 : root.count
            horizontalItemAlignment: root.settings.align === "left" ? Grid.AlignLeft
                : root.settings.align === "right" ? Grid.AlignRight : Grid.AlignHCenter
            anchors.verticalCenter: parent.verticalCenter
            x: root.settings.align === "left" ? Tokens.spacingMedium
                : root.settings.align === "right" ? parent.width - width - Tokens.spacingMedium
                : (parent.width - width) / 2

            Repeater {
                id: groupsRepeater
                model: root.count
                onItemAdded: Qt.callLater(root.collectRegions)
                onItemRemoved: Qt.callLater(root.collectRegions)

                Row {
                    id: group
                    required property int index
                    readonly property string text: root.groups[index] ?? "00"

                    ClockGlyph {
                        id: sep
                        visible: !root.vertical && group.index > 0
                        width: root.sepW
                        height: root.slotH
                        value: ":"
                        font: root.clockFont
                        color: root.textColor
                        capHeight: root.capH
                        masks: root.textBlur ? root.masks : ({})
                        animated: false

                        SequentialAnimation on opacity {
                            running: root.blink
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { from: 1; to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.2; to: 1; duration: 500; easing.type: Easing.InOutSine }
                        }
                    }
                    Repeater {
                        model: 2

                        ClockGlyph {
                            required property int index
                            width: root.digitW
                            height: root.slotH
                            value: group.text.charAt(index)
                            font: root.clockFont
                            color: root.textColor
                            capHeight: root.capH
                            masks: root.textBlur ? root.masks : ({})
                        }
                    }
                }
            }
        }
    }
}
