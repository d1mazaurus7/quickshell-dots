pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Вкладка CPU
SysPage {
    id: p

    readonly property var info: sys.info
    readonly property int threads: Number(info.threads ?? sys.cores.length)
    readonly property real maxMhz: Number(info.maxFreq ?? 0) / 1000
    readonly property real minMhz: Number(info.minFreq ?? 0) / 1000
    readonly property var pct: v => v.toFixed(1) + "%"

    function cache(i: int): string {
        const c = info["cache" + i];
        if (!c)
            return "—";
        const parts = c.split(" "), s = parts[2] ?? "";
        const b = Number(s.replace(/[KMG]$/, "")) * ({ K: 1024, M: 1048576, G: 1073741824 }[s.slice(-1)] ?? 1);
        return sys.bytes(b);
    }

    SysTile {
        icon: "memory"
        title: "Загрузка"
        label: "CPU"
        value: Math.round(p.sys.cpu * 100) + "%"
        sub: "I/O " + (p.sys.cpuIo * 100).toFixed(1) + "%"
        progress: p.sys.cpu
        warn: p.sys.cpu > 0.9
        details: [
            { icon: "person", text: "польз. " + (p.sys.cpuUser * 100).toFixed(1) + "%" },
            { icon: "settings", text: "ядро " + (p.sys.cpuSys * 100).toFixed(1) + "%" }
        ]
    }
    SysTile {
        icon: "thermostat"
        title: "Температура"
        label: "Tctl"
        value: Math.round(p.sys.cpuTemp) + "°"
        sub: "из 95 °C"
        progress: p.sys.cpuTemp / 95
        warn: p.sys.cpuTemp >= 85
        details: [
            { icon: "device_thermostat", text: p.sys.temps.cpu_Tccd1 !== undefined ? "CCD1 " + p.sys.temps.cpu_Tccd1.toFixed(1) + " °C" : "CCD —" },
            { icon: "trending_up", text: "пик за период " + Math.round(p.peak("cpuTemp")) + " °C" }
        ]
    }
    SysTile {
        icon: "bolt"
        title: "Частота"
        label: "GHz"
        value: (p.sys.freq / 1000).toFixed(2)
        sub: "средняя"
        progress: p.maxMhz > 0 ? p.sys.freq / p.maxMhz : 0
        details: [
            { icon: "arrow_upward", text: "пик " + (Math.max(0, ...p.sys.freqs) / 1000).toFixed(2) + " ГГц" },
            { icon: "speed", text: "макс. " + (p.maxMhz / 1000).toFixed(2) + " ГГц" }
        ]
    }
    SysTile {
        icon: "trending_up"
        title: "Средняя нагрузка"
        label: "Load"
        value: p.sys.load[0].toFixed(2)
        sub: "1 мин"
        progress: p.threads > 0 ? p.sys.load[0] / p.threads : 0
        warn: p.sys.load[0] > p.threads
        details: [
            { icon: "timer", text: "5 мин " + p.sys.load[1].toFixed(2) },
            { icon: "hourglass_bottom", text: "15 мин " + p.sys.load[2].toFixed(2) }
        ]
    }

    graph.icon: "monitoring"
    graph.title: "Процессор"
    graph.series: [
        { key: "cpu", label: "Общая", icon: "memory", color: p.colors.primary, max: 100, fmt: p.pct },
        { key: "cpuUser", label: "Польз.", icon: "person", color: p.colors.tertiary, max: 100, fmt: p.pct },
        { key: "cpuSys", label: "Ядро", icon: "settings", color: p.colors.secondary, max: 100, fmt: p.pct },
        { key: "cpuIo", label: "I/O", icon: "hourglass_top", color: p.colors.error, max: 100, fmt: p.pct },
        { key: "cpuTemp", label: "°C", icon: "thermostat", color: p.colors.on_surface_variant, max: 100, fmt: v => Math.round(v) + " °C" }
    ]

    leftPane.icon: "info"
    leftPane.title: "Характеристики"
    leftPane.note: p.info.host ?? ""
    leftPane.content: SysInfo {
        anchors.fill: parent
        rows: [
            { icon: "developer_board", label: "Модель", value: p.info.cpuModel ?? "—" },
            { icon: "grid_view", label: "Ядра / потоки", value: (p.info.cpuCores ?? "—") + " / " + p.threads },
            { icon: "speed", label: "Частота", value: (p.minMhz / 1000).toFixed(2) + " – " + (p.maxMhz / 1000).toFixed(2) + " ГГц" },
            { icon: "rocket_launch", label: "Буст", value: p.info.boost === "1" ? "включён" : p.info.boost === "0" ? "выключен" : "—" },
            { icon: "layers", label: "Кэш L1d / L1i", value: p.cache(0) + " / " + p.cache(1) },
            { icon: "stacks", label: "Кэш L2 / L3", value: p.cache(2) + " / " + p.cache(3) },
            { icon: "tune", label: "Драйвер частоты", value: p.info.freqDriver || "—" },
            { icon: "eco", label: "Губернатор / EPP", value: (p.info.governor || "—") + (p.info.epp ? " / " + p.info.epp : "") },
            { icon: "account_tree", label: "Процессы", value: p.sys.tasks.replace("/", " активн. из ") },
            { icon: "terminal", label: "Ядро Linux", value: p.info.kernel ?? "—" },
            { icon: "schedule", label: "Аптайм", value: p.sys.duration(p.sys.uptime) }
        ]
    }

    rightPane.icon: "view_module"
    rightPane.title: "Потоки"
    rightPane.note: p.threads + " шт."
    rightPane.content: Grid {
        id: grid
        anchors.fill: parent
        readonly property int cols: p.threads <= 12 ? Math.max(1, Math.ceil(p.threads / 2)) : 8
        readonly property int rowsN: Math.max(1, Math.ceil(p.threads / cols))
        columns: cols
        spacing: Tokens.spacingMedium

        Repeater {
            model: p.threads

            Rectangle {
                id: cell
                required property int index
                readonly property real use: p.sys.cores[index] ?? 0
                readonly property real mhz: p.sys.freqs[index] ?? 0
                readonly property bool hot: hover.hovered

                property real shown: use
                Behavior on shown { NumberAnimation { duration: Tokens.animationSlow * 2.5; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }

                width: Math.floor((grid.width - grid.spacing * (grid.cols - 1)) / grid.cols)
                height: Math.floor((grid.height - grid.spacing * (grid.rowsN - 1)) / grid.rowsN)
                radius: Tokens.radius(16)
                color: p.colors.surface_container_highest
                scale: hot ? 1.05 : 1
                z: hot ? 1 : 0
                Behavior on scale { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutBack } }

                HoverHandler { id: hover }

                // Заливка: прямой срез сверху, скруглённые углы снизу повторяют ячейку
                Item {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * cell.shown
                    clip: true

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: cell.width
                        height: cell.height
                        radius: cell.radius
                        color: cell.use > 0.9 ? p.colors.error : p.colors.primary
                        opacity: cell.hot ? 0.55 : 0.35
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
                        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                    }
                }

                Text {
                    x: Tokens.spacingMedium
                    y: Tokens.spacingSmallV
                    text: "#" + cell.index
                    font: Tokens.fontSmall
                    color: p.colors.on_surface_variant
                }

                SysIcon {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacingSmall
                    y: Tokens.spacingSmallV
                    icon: cell.use > 0.5 ? "local_fire_department" : "memory"
                    size: Tokens.scaled(14)
                    filled: cell.hot
                    hovered: cell.hot
                    color: cell.use > 0.5 ? p.colors.tertiary : p.colors.on_surface_variant
                }

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Tokens.scaled(4)
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Math.round(cell.use * 100) + "%"
                        font.family: Tokens.fontLarge.family
                        font.pixelSize: Tokens.fontLarge.pixelSize
                        font.weight: Font.DemiBold
                        color: p.colors.on_surface
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (cell.mhz / 1000).toFixed(2) + " ГГц"
                        font: Tokens.fontSmall
                        color: p.colors.on_surface_variant
                    }
                }
            }
        }
    }
}
