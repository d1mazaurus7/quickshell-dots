import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"

// Каркас вкладки: 4 плитки, график, две равные карточки снизу
Item {
    id: page

    required property var sys
    // Номер вкладки и анимированная позиция ленты вкладок
    property int index: 0
    property real pos: 0
    readonly property bool current: Math.round(pos) === index
    readonly property var cfg: Config.options.system
    readonly property var colors: Tokens.colors
    readonly property int gap: Tokens.spacingLarge

    // Пик и среднее серии за видимый отрезок графика
    function window_(key: string): var {
        const a = sys.history[key] ?? [];
        return sys.count >= 0 ? a.slice(Math.max(0, a.length - graph.samples)) : [];
    }
    function peak(key: string): real {
        return Math.max(0, ...window_(key));
    }
    function avg(key: string): real {
        const w = window_(key);
        return w.length ? w.reduce((x, y) => x + y, 0) / w.length : 0;
    }

    default property alias tiles: tileRow.data
    property alias graph: graph
    property alias leftPane: leftCard
    property alias rightPane: rightCard

    // Лента: вкладки стоят рядом и плавно сдвигаются вбок, без наложения
    x: (index - pos) * (width + gap * 2)
    visible: Math.abs(index - pos) < 0.999
    enabled: current

    // Во время сдвига вкладка едет готовой текстурой, а покадровые волны колец стоят:
    // иначе пересчёт и перетриангуляция Shape каждый кадр не дают держать частоту монитора
    readonly property bool sliding: pos !== Math.round(pos)
    layer.enabled: sliding
    layer.smooth: true
    onSlidingChanged: {
        for (const t of tileRow.children)
            if (t.animate !== undefined)
                t.animate = !sliding;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: page.gap

        RowLayout {
            id: tileRow
            Layout.fillWidth: true
            spacing: page.gap
        }

        SysGraph {
            id: graph
            Layout.fillWidth: true
            Layout.fillHeight: true
            sys: page.sys
            live: page.visible
            range: page.cfg.range
            smoothLines: page.cfg.smoothGraphs
            tooltip: page.cfg.graphTooltip
        }

        RowLayout {
            readonly property int h: Math.round((page.height - Tokens.scaled(140) - page.gap * 2) * 0.5)
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: h
            Layout.maximumHeight: h
            spacing: page.gap

            SysCard {
                id: leftCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
            }
            SysCard {
                id: rightCard
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
            }
        }
    }
}
