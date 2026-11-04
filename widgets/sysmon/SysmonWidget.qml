pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"
import "../controls"

// Потребление ресурса (settings.kind): вкладка волны — занятая доля заливкой с волной,
// занятое и свободное количество; вкладка графика — история за settings.graphSpan секунд
Item {
    id: root

    property var settings: ({})
    property bool editing: false

    readonly property var colors: Tokens.colors
    readonly property string kind: settings.kind ?? "cpu"
    readonly property var titles: ({ disk: "Диск", ram: "RAM", cpu: "CPU", gpu: "GPU" })
    readonly property int pad: Tokens.scaled(12)
    readonly property int valueSize: Math.round(Math.max(Tokens.scaled(12), Math.min(width * 0.14, height * 0.11)))

    // Вкладки по настройкам; обе выключены — остаётся волна
    readonly property var pages: (settings.usageTab === true || settings.graphTab !== true ? [{ id: "usage", icon: "water" }] : [])
        .concat(settings.graphTab === true ? [{ id: "graph", icon: "show_chart" }] : [])
    property string selectedPage: "usage"
    readonly property string page: pages.some(p => p.id === selectedPage) ? selectedPage : pages[0].id
    readonly property int pageIndex: pages.findIndex(p => p.id === page)

    function format(v: real): string {
        if (kind === "cpu" || kind === "gpu")
            return Math.round(v) + "%";
        const gb = v / 1073741824;
        if (gb >= 1000)
            return (gb / 1024).toFixed(2) + " TB";
        return (gb >= 100 ? gb.toFixed(0) : gb.toFixed(1)) + " GB";
    }

    SysmonSource {
        id: source
        kind: root.kind
        interval: root.settings.interval
        historyLength: graph.count
    }

    WidgetCard {
        anchors.fill: parent

        // Страницы на всю карточку, смена — слайдом в сторону выбранной
        Item {
            id: pagesArea
            anchors.fill: parent

            Item {
                id: usagePage
                readonly property int index: root.pages.findIndex(p => p.id === "usage")
                width: parent.width
                height: parent.height
                visible: index >= 0 && Math.abs(x) < width
                x: (index - root.pageIndex) * width
                Behavior on x { NumberAnimation { duration: Tokens.animationSlow * 2; easing.type: Easing.OutQuart } }

                WaveFill {
                    id: wave
                    anchors.fill: parent
                    visible: root.settings.showWave === true
                    level: source.fraction
                }

                // Верхняя зона — свободно, нижняя (заливка) — занято; подпись по центру своей зоны
                readonly property real edge: wave.visible ? wave.surfaceY : height / 2
                readonly property real zoneTop: header.height + root.pad

                Text {
                    id: freeText
                    visible: root.settings.showFree === true && source.ready
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    y: Math.max(usagePage.zoneTop, Math.min(usagePage.height - root.pad - height, (usagePage.zoneTop + usagePage.edge - height) / 2))
                    text: root.format(source.free)
                    color: root.colors.on_surface
                    font.family: Tokens.typography.family
                    font.pixelSize: root.valueSize
                    font.features: { "tnum": 1 }
                }

                Text {
                    visible: root.settings.showUsed === true && source.ready
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    y: Math.max(usagePage.zoneTop, Math.min(usagePage.height - root.pad - height, (usagePage.edge + usagePage.height - height) / 2))
                    text: root.format(source.used)
                    color: wave.visible ? root.colors.on_primary : root.colors.on_surface
                    font.family: Tokens.typography.family
                    font.pixelSize: root.valueSize
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }

            Item {
                readonly property int index: root.pages.findIndex(p => p.id === "graph")
                width: parent.width
                height: parent.height
                visible: index >= 0 && Math.abs(x) < width
                x: (index - root.pageIndex) * width
                Behavior on x { NumberAnimation { duration: Tokens.animationSlow * 2; easing.type: Easing.OutQuart } }

                UsageGraph {
                    id: graph
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.top: parent.top
                    anchors.topMargin: header.height + root.pad
                    anchors.bottomMargin: root.pad
                    count: Math.max(2, Math.ceil(root.settings.graphSpan * 1000 / root.settings.interval) + 1)
                    interval: root.settings.interval
                    span: root.settings.graphSpan
                    values: source.history
                }
            }
        }

        // Заголовок и вкладки поверх страниц
        Item {
            id: header
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.pad
            height: tabs.height

            Text {
                anchors.left: parent.left
                anchors.right: tabs.left
                anchors.rightMargin: Tokens.spacingSmall
                anchors.verticalCenter: parent.verticalCenter
                text: root.titles[root.kind] ?? ""
                elide: Text.ElideRight
                color: root.colors.on_surface
                font.family: Tokens.typography.family
                font.pixelSize: Tokens.scaled(Tokens.typography.size)
                font.weight: Font.Medium
            }

            TabSwitch {
                id: tabs
                anchors.right: parent.right
                visible: root.pages.length > 1
                tabs: root.pages
                current: root.page
                onSelected: id => root.selectedPage = id
            }
        }
    }
}
