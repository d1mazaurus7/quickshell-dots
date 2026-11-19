pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Вкладка RAM
SysPage {
    id: p

    readonly property var m: sys.mem
    readonly property real total: m.total ?? 0
    readonly property real cache: (m.cached ?? 0) + (m.buffers ?? 0)
    readonly property real free: Math.max(0, total - (m.used ?? 0) - cache)
    readonly property int modules: Number(sys.info.ramModules ?? 0)
    readonly property bool hasSwap: (m.swapTotal ?? 0) > 0
    readonly property var pct: v => v.toFixed(1) + "%"

    function part(v: real): real {
        return total > 0 ? v / total : 0;
    }
    function p0(v: var): string {
        return sys.bytes(v ?? 0);
    }
    function percent(v: real): string {
        return Math.round(part(v) * 100) + "%";
    }

    SysTile {
        icon: "memory_alt"
        title: "Использовано"
        label: "RAM"
        value: p.percent(p.m.used ?? 0)
        sub: p.p0(p.m.used)
        progress: p.part(p.m.used ?? 0)
        warn: progress > 0.9
        details: [
            { icon: "storage", text: "всего " + p.p0(p.total) },
            { icon: "dashboard", text: "оболочка " + p.p0(p.sys.shellRss) }
        ]
    }
    SysTile {
        icon: "check_circle"
        title: "Доступно"
        label: "Free"
        value: p.percent(p.m.avail ?? 0)
        sub: p.p0(p.m.avail)
        progress: p.part(p.m.avail ?? 0)
        details: [
            { icon: "check_box_outline_blank", text: "не занято " + p.p0(p.free) },
            { icon: "cached", text: "+ кэш " + p.p0(p.cache) }
        ]
    }
    SysTile {
        icon: "cached"
        title: "Кэш и буферы"
        label: "Cache"
        value: p.percent(p.cache)
        sub: p.p0(p.cache)
        progress: p.part(p.cache)
        details: [
            { icon: "description", text: "страницы " + p.p0(p.m.cached) },
            { icon: "inventory_2", text: "буферы " + p.p0(p.m.buffers) }
        ]
    }
    SysTile {
        icon: "swap_vert"
        title: "Подкачка"
        label: "Swap"
        value: p.hasSwap ? Math.round(p.m.swapUsed / p.m.swapTotal * 100) + "%" : "—"
        sub: p.hasSwap ? p.p0(p.m.swapUsed) : "нет"
        progress: p.hasSwap ? p.m.swapUsed / p.m.swapTotal : 0
        details: [
            { icon: "storage", text: p.hasSwap ? "всего " + p.p0(p.m.swapTotal) : "swap не настроен" },
            { icon: "edit_note", text: "грязные " + p.p0(p.m.dirty) }
        ]
    }

    graph.icon: "monitoring"
    graph.title: "Память"
    graph.series: [
        { key: "ram", label: "Занято", icon: "memory_alt", color: p.colors.primary, max: 100, fmt: p.pct },
        { key: "cache", label: "Кэш", icon: "cached", color: p.colors.tertiary, max: 100, fmt: p.pct },
        { key: "swap", label: "Swap", icon: "swap_vert", color: p.colors.secondary, max: 100, fmt: p.pct },
        { key: "ramTemp", label: "°C", icon: "thermostat", color: p.colors.on_surface_variant, max: 100, fmt: v => v.toFixed(1) + " °C" }
    ]

    leftPane.icon: "donut_large"
    leftPane.title: "Распределение"
    leftPane.note: p.modules > 0 ? p.modules + " мод." : ""
    leftPane.content: Flickable {
        id: dist
        anchors.fill: parent
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: dist.width
            spacing: Tokens.spacingMediumV

            readonly property var parts: [
                { label: "Приложения", value: p.m.used ?? 0, color: p.colors.primary, icon: "apps" },
                { label: "Кэш и буферы", value: p.cache, color: p.colors.tertiary, icon: "cached" },
                { label: "Свободно", value: p.free, color: p.colors.surface_container_highest, icon: "check_box_outline_blank" }
            ]

            // Полоса из частей с зазорами, ширины анимируются
            Row {
                width: parent.width
                height: Tokens.scaled(22)
                spacing: Tokens.scaled(3)

                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        property real w: (col.width - Tokens.scaled(6)) * p.part(col.parts[index].value)
                        Behavior on w { NumberAnimation { duration: Tokens.animationSlow * 2.5; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }
                        width: Math.max(Tokens.scaled(4), w)
                        height: parent.height
                        radius: Tokens.radius(8)
                        color: col.parts[index].color
                    }
                }
            }

            Repeater {
                model: 3
                SysBar {
                    required property int index
                    readonly property var part: col.parts[index]
                    width: col.width
                    icon: part.icon
                    label: part.label
                    value: p.sys.bytes(part.value) + " · " + Math.round(p.part(part.value) * 100) + "%"
                    progress: p.part(part.value)
                    accent: index === 2 ? p.colors.secondary : part.color
                }
            }

            Repeater {
                model: p.modules
                SysBar {
                    required property int index
                    readonly property real temp: p.sys.temps["ram" + index] ?? 0
                    width: col.width
                    icon: "device_thermostat"
                    label: "Модуль " + (index + 1)
                    value: temp.toFixed(1) + " °C"
                    progress: temp / 85
                    warn: temp >= 75
                }
            }

            SysInfo {
                width: col.width
                height: contentHeight
                interactive: false
                rows: [
                    { icon: "memory_alt", label: "Всего", value: p.p0(p.total) },
                    { icon: "share", label: "Общая (shmem)", value: p.p0(p.m.shmem) },
                    { icon: "edit_note", label: "Грязные страницы", value: p.p0(p.m.dirty) },
                    { icon: "swap_vert", label: "Swap", value: p.hasSwap ? p.p0(p.m.swapUsed) + " / " + p.p0(p.m.swapTotal) : "нет" }
                ]
            }
        }
    }

    rightPane.icon: "apps"
    rightPane.title: "Приложения"
    rightPane.note: "по памяти"
    rightPane.content: Flickable {
        id: appList
        anchors.fill: parent
        contentHeight: appCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property real topRss: Math.max(p.sys.shellRss, p.sys.apps.length ? p.sys.apps[0].rss : 1, 1)

        Column {
            id: appCol
            width: appList.width
            spacing: Tokens.spacingSmallV

            // Оболочка закреплена сверху и выделена
            Rectangle {
                width: appCol.width
                height: shellBar.implicitHeight + Tokens.spacingSmallV * 2
                radius: Tokens.radius(14)
                color: Qt.alpha(p.colors.secondary_container, 0.6)

                SysBar {
                    id: shellBar
                    x: Tokens.spacingMedium
                    width: parent.width - Tokens.spacingMedium * 2
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "dashboard"
                    label: "Оболочка (Quickshell) · " + p.sys.shellProcs + " проц."
                    value: p.sys.bytes(p.sys.shellRss)
                    progress: p.sys.shellRss / appList.topRss
                    accent: p.colors.secondary
                }
            }

            Repeater {
                model: p.sys.apps.length
                SysBar {
                    required property int index
                    readonly property var app: p.sys.apps[index] ?? { name: "", rss: 0, count: 0 }
                    width: appCol.width
                    icon: index === 0 ? "local_fire_department" : "deployed_code"
                    label: app.name + (app.count > 1 ? " ×" + app.count : "")
                    value: p.sys.bytes(app.rss) + " · " + (p.part(app.rss) * 100).toFixed(1) + "%"
                    progress: app.rss / appList.topRss
                }
            }
        }
    }
}
