pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Вкладка GPU (amdgpu: gpu_busy_percent, hwmon)
SysPage {
    id: p

    readonly property var info: sys.info
    readonly property var g: sys.gpu
    readonly property var t: sys.temps
    readonly property real vramTotal: Number(info.vramTotal ?? 0)
    readonly property real gttTotal: Number(info.gttTotal ?? 0)
    readonly property real cap: Number(info.powerCap ?? 0) / 1e6
    readonly property real fanMax: Number(info.fanMax ?? 0)
    readonly property real sclkMax: Number(info.sclkMax ?? 0)
    readonly property real mclkMax: Number(info.mclkMax ?? 0)
    readonly property real hot: t.gpu_junction ?? t.gpu_edge ?? 0
    readonly property var pct: v => v.toFixed(1) + "%"
    readonly property var deg: v => Math.round(v) + " °C"

    SysTile {
        icon: "developer_board"
        title: "Загрузка"
        label: "GPU"
        value: Math.round((p.g.busy ?? 0) * 100) + "%"
        sub: Math.round(p.g.sclk ?? 0) + " МГц"
        progress: p.g.busy ?? 0
        details: [
            { icon: "speed", text: "ядро " + Math.round(p.g.sclk ?? 0) + " МГц" },
            { icon: "memory", text: "память " + Math.round(p.g.mclk ?? 0) + " МГц" }
        ]
    }
    SysTile {
        icon: "thermostat"
        title: "Температура"
        label: "Hotspot"
        value: Math.round(p.hot) + "°"
        sub: "из 110 °C"
        progress: p.hot / 110
        warn: p.hot >= 95
        details: [
            { icon: "device_thermostat", text: "край " + Math.round(p.t.gpu_edge ?? 0) + " °C" },
            { icon: "memory_alt", text: "память " + Math.round(p.t.gpu_mem ?? 0) + " °C" }
        ]
    }
    SysTile {
        icon: "memory_alt"
        title: "Видеопамять"
        label: "VRAM"
        value: Math.round(progress * 100) + "%"
        sub: p.sys.bytes(p.g.vram ?? 0)
        progress: p.vramTotal > 0 ? (p.g.vram ?? 0) / p.vramTotal : 0
        warn: progress > 0.92
        details: [
            { icon: "storage", text: "всего " + p.sys.bytes(p.vramTotal) },
            { icon: "swap_horiz", text: "GTT " + p.sys.bytes(p.g.gtt ?? 0) }
        ]
    }
    SysTile {
        icon: "electric_bolt"
        title: "Мощность"
        label: "Power"
        value: Math.round(p.g.power ?? 0) + " W"
        sub: Math.round(progress * 100) + "% лимита"
        progress: p.cap > 0 ? (p.g.power ?? 0) / p.cap : 0
        details: [
            { icon: "power", text: p.cap > 0 ? "лимит " + Math.round(p.cap) + " Вт" : "лимит —" },
            { icon: (p.g.fan ?? 0) > 0 ? "mode_fan" : "mode_fan_off", text: (p.g.fan ?? 0) > 0 ? p.g.fan + " об/мин" : "вентилятор стоит" }
        ]
    }

    graph.icon: "monitoring"
    graph.title: "Видеокарта"
    graph.series: [
        { key: "gpu", label: "Загрузка", icon: "developer_board", color: p.colors.primary, max: 100, fmt: p.pct },
        { key: "vram", label: "VRAM", icon: "memory_alt", color: p.colors.tertiary, max: 100, fmt: p.pct },
        { key: "gpuPower", label: "Вт", icon: "electric_bolt", color: p.colors.secondary, max: p.cap > 0 ? p.cap : 300, fmt: v => Math.round(v) + " Вт" },
        { key: "gpuHot", label: "Hotspot", icon: "local_fire_department", color: p.colors.error, max: 110, fmt: p.deg },
        { key: "gpuEdge", label: "Край", icon: "thermostat", color: p.colors.on_surface_variant, max: 110, fmt: p.deg }
    ]

    leftPane.icon: "info"
    leftPane.title: "Характеристики"
    leftPane.note: p.info.gpuDriver ?? ""
    leftPane.content: SysInfo {
        anchors.fill: parent
        rows: [
            { icon: "videogame_asset", label: "Устройство", value: p.info.gpuId ? "PCI " + p.info.gpuId : "—" },
            { icon: "extension", label: "Драйвер", value: p.info.gpuDriver ?? "—" },
            { icon: "integration_instructions", label: "VBIOS", value: p.info.vbios || "—" },
            { icon: "cable", label: "PCIe", value: p.info.pcie || "—" },
            { icon: "memory_alt", label: "Видеопамять", value: p.sys.bytes(p.vramTotal) + (p.info.vramVendor ? " · " + p.info.vramVendor : "") },
            { icon: "swap_horiz", label: "GTT", value: p.sys.bytes(p.g.gtt ?? 0) + " / " + p.sys.bytes(p.gttTotal) },
            { icon: "speed", label: "Макс. частоты", value: p.sclkMax + " / " + p.mclkMax + " МГц" },
            { icon: "power", label: "Лимит мощности", value: p.cap > 0 ? Math.round(p.cap) + " Вт" : "—" },
            { icon: "mode_fan", label: "Макс. обороты", value: p.fanMax > 0 ? p.fanMax + " об/мин" : "—" }
        ]
    }

    rightPane.icon: "sensors"
    rightPane.title: "Датчики"
    rightPane.content: Grid {
        id: grid
        anchors.fill: parent
        columns: 2
        columnSpacing: Tokens.spacingLarge
        rowSpacing: Math.max(0, (height - Tokens.scaled(42) * 3) / 2)
        readonly property real cellW: (width - columnSpacing) / 2

        SysBar {
            width: grid.cellW
            icon: "speed"; label: "Частота ядра"
            value: Math.round(p.g.sclk ?? 0) + " МГц"
            progress: p.sclkMax > 0 ? (p.g.sclk ?? 0) / p.sclkMax : 0
        }
        SysBar {
            width: grid.cellW
            icon: "memory"; label: "Частота памяти"
            value: Math.round(p.g.mclk ?? 0) + " МГц"
            progress: p.mclkMax > 0 ? (p.g.mclk ?? 0) / p.mclkMax : 0
        }
        SysBar {
            width: grid.cellW
            icon: (p.g.fan ?? 0) > 0 ? "mode_fan" : "mode_fan_off"; label: "Вентилятор"
            value: (p.g.fan ?? 0) > 0 ? p.g.fan + " об/мин" : "стоит"
            progress: p.fanMax > 0 ? (p.g.fan ?? 0) / p.fanMax : 0
        }
        SysBar {
            width: grid.cellW
            icon: "battery_charging_full"; label: "Напряжение"
            value: (p.g.vdd ?? 0) + " мВ"
            progress: (p.g.vdd ?? 0) / 1200
        }
        SysBar {
            width: grid.cellW
            icon: "device_thermostat"; label: "Память"
            value: Math.round(p.t.gpu_mem ?? 0) + " °C"
            progress: (p.t.gpu_mem ?? 0) / 110
            warn: (p.t.gpu_mem ?? 0) >= 100
        }
        SysBar {
            width: grid.cellW
            icon: "swap_horiz"; label: "GTT"
            value: p.sys.bytes(p.g.gtt ?? 0)
            progress: p.gttTotal > 0 ? (p.g.gtt ?? 0) / p.gttTotal : 0
        }
    }
}
