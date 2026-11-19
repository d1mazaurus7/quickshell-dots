pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Вкладка Disk
SysPage {
    id: p

    readonly property var root_: sys.filesystems.find(f => f.target === "/") ?? null
    readonly property var rateFmt: v => sys.rate(v)

    SysTile {
        icon: "download"
        title: "Чтение"
        label: "Read"
        value: p.sys.rate(p.sys.ioRead).split(" ")[0]
        sub: p.sys.rate(p.sys.ioRead).split(" ")[1] ?? ""
        progress: p.sys.ioRead / p.sys.ioPeak
        details: [
            { icon: "trending_up", text: "пик " + p.sys.rate(p.sys.ioPeak) },
            { icon: "functions", text: "среднее " + p.sys.rate(p.avg("diskR")) }
        ]
    }
    SysTile {
        icon: "upload"
        title: "Запись"
        label: "Write"
        value: p.sys.rate(p.sys.ioWrite).split(" ")[0]
        sub: p.sys.rate(p.sys.ioWrite).split(" ")[1] ?? ""
        progress: p.sys.ioWrite / p.sys.ioPeak
        details: [
            { icon: "trending_up", text: "пик " + p.sys.rate(p.sys.ioPeak) },
            { icon: "functions", text: "среднее " + p.sys.rate(p.avg("diskW")) }
        ]
    }
    SysTile {
        icon: "folder_open"
        title: "Корневой раздел"
        label: "Disk"
        value: Math.round(progress * 100) + "%"
        sub: p.root_ ? p.sys.bytes(p.root_.used) : ""
        progress: p.root_ ? p.root_.used / p.root_.size : 0
        warn: progress > 0.9
        details: [
            { icon: "storage", text: p.root_ ? "всего " + p.sys.bytes(p.root_.size) : "—" },
            { icon: "check_box_outline_blank", text: p.root_ ? "свободно " + p.sys.bytes(p.root_.size - p.root_.used) : "—" }
        ]
    }
    SysTile {
        icon: "thermostat"
        title: "Температура"
        label: "NVMe"
        value: p.sys.diskTemp > 0 ? Math.round(p.sys.diskTemp) + "°" : "—"
        sub: "из 85 °C"
        progress: p.sys.diskTemp / 85
        warn: p.sys.diskTemp >= 70
        details: [
            { icon: "hard_disk", text: "самый горячий" },
            { icon: "trending_up", text: "пик за период " + Math.round(p.peak("diskTemp")) + " °C" }
        ]
    }

    graph.icon: "monitoring"
    graph.title: "Ввод-вывод"
    graph.axisFmt: f => p.sys.rate(f)
    graph.series: [
        { key: "diskR", label: "Чтение", icon: "download", color: p.colors.primary, max: 0, fmt: p.rateFmt },
        { key: "diskW", label: "Запись", icon: "upload", color: p.colors.tertiary, max: 0, fmt: p.rateFmt }
    ]

    leftPane.icon: "hard_drive"
    leftPane.title: "Накопители"
    leftPane.note: p.sys.drives.length + " шт."
    leftPane.content: Flickable {
        id: drives
        anchors.fill: parent
        contentHeight: driveCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: driveCol
            width: drives.width
            spacing: Tokens.spacingSmallV

            Repeater {
                model: p.sys.drives.length

                Rectangle {
                    id: drive
                    required property int index
                    readonly property var d: p.sys.drives[index] ?? {}
                    readonly property var rw: p.sys.io[d.name] ?? { r: 0, w: 0 }
                    readonly property real temp: p.sys.temps[String(d.name ?? "").replace(/n\d+$/, "")] ?? 0
                    readonly property bool hot: hover.hovered

                    width: driveCol.width
                    height: Tokens.scaled(54)
                    radius: Tokens.radius(16)
                    color: hot ? p.colors.surface_container_highest : Qt.alpha(p.colors.surface_container_highest, 0.5)
                    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

                    HoverHandler { id: hover }

                    Rectangle {
                        id: badge
                        x: Tokens.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        width: Tokens.scaled(36)
                        height: width
                        radius: drive.hot ? Tokens.radius(12) : width / 2
                        color: p.colors.secondary_container
                        Behavior on radius { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

                        SysIcon {
                            anchors.centerIn: parent
                            icon: drive.d.rota ? "hard_drive" : "hard_disk"
                            size: Tokens.scaled(20)
                            filled: drive.hot
                            hovered: drive.hot
                            color: p.colors.on_secondary_container
                        }
                    }

                    Column {
                        anchors.left: badge.right
                        anchors.leftMargin: Tokens.spacingMedium
                        anchors.right: rates.left
                        anchors.rightMargin: Tokens.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: (drive.d.model ?? drive.d.name ?? "").trim()
                            font: Tokens.fontMedium
                            color: p.colors.on_surface
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: [drive.d.name, p.sys.bytes(drive.d.size ?? 0), String(drive.d.tran ?? "").toUpperCase(),
                                drive.temp > 0 ? Math.round(drive.temp) + " °C" : ""].filter(s => s).join(" · ")
                            font: Tokens.fontSmall
                            color: p.colors.on_surface_variant
                        }
                    }

                    Column {
                        id: rates
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.right: parent.right
                            text: "↓ " + p.sys.rate(drive.rw.r)
                            font: Tokens.fontSmall
                            color: drive.rw.r > 0 ? p.colors.primary : p.colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                        }
                        Text {
                            anchors.right: parent.right
                            text: "↑ " + p.sys.rate(drive.rw.w)
                            font: Tokens.fontSmall
                            color: drive.rw.w > 0 ? p.colors.tertiary : p.colors.on_surface_variant
                            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                        }
                    }
                }
            }
        }
    }

    rightPane.icon: "folder"
    rightPane.title: "Разделы"
    rightPane.note: p.sys.filesystems.length + " шт."
    rightPane.content: Flickable {
        id: fsList
        anchors.fill: parent
        contentHeight: fsCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: fsCol
            width: fsList.width
            spacing: Tokens.spacingSmallV

            Repeater {
                model: p.sys.filesystems.length
                SysBar {
                    required property int index
                    readonly property var fs: p.sys.filesystems[index] ?? { size: 1, used: 0 }
                    width: fsCol.width
                    icon: fs.target === "/" ? "home_storage" : fs.target === "/boot" ? "power_settings_new" : "folder"
                    label: (fs.target ?? "") + " · " + (fs.type ?? "") + " · " + String(fs.source ?? "").replace("/dev/", "")
                    value: p.sys.bytes(fs.used) + " / " + p.sys.bytes(fs.size)
                    progress: fs.size > 0 ? fs.used / fs.size : 0
                    warn: progress > 0.9
                }
            }
        }
    }
}
