pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../shell/config"
import "../../shell/theme"
import "../../settings/controls"

// Окно «Система» поверх всех окон (overlay-слой).
// IPC: qs ipc call system toggle|open|close|tab <cpu|gpu|ram|disk> — открывается на мониторе в фокусе Niri
PanelWindow {
    id: root

    required property var sys
    property bool open: false

    readonly property var cfg: Config.options.system
    readonly property var colors: Tokens.colors
    readonly property var tabs: [
        { label: "CPU", icon: "memory" },
        { label: "GPU", icon: "developer_board" },
        { label: "RAM", icon: "memory_alt" },
        { label: "Disk", icon: "hard_drive" }
    ]
    readonly property var ranges: [60, 300, 900, 1800, 3600]
    // Вкладка сохраняется в настройки при закрытии, не на каждое переключение
    property int tab: Math.max(0, Math.min(3, cfg.tab))
    property real tabPos: tab
    Behavior on tabPos { NumberAnimation { duration: Tokens.animationSlow * 1.5; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }

    property real progress: open ? 1 : 0
    // M3: вход — emphasized decelerate, выход — короткий emphasized accelerate
    Behavior on progress { NumberAnimation { duration: root.open ? Tokens.animationSlow * 1.3 : Tokens.animationMedium; easing.type: Easing.BezierSpline; easing.bezierCurve: root.open ? [0.05, 0.7, 0.1, 1, 1, 1] : [0.3, 0, 0.8, 0.15, 1, 1] } }

    WlrLayershell.namespace: "qs:system"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    visible: open || progress > 0
    mask: Region { item: open ? fullMask : null }

    Binding {
        target: root.sys
        property: "procs"
        value: root.visible && root.tab === 2
    }

    function setTab(i: int): void {
        tab = (i + 4) % 4;
    }
    onOpenChanged: if (!open && cfg.tab !== tab) cfg.tab = tab

    property string pendingAction: ""
    function withFocusedOutput(action: string): void {
        pendingAction = action;
        focusedOutput.running = true;
    }

    IpcHandler {
        target: "system"

        function toggle(): void { root.withFocusedOutput("toggle"); }
        function open(): void { root.withFocusedOutput("open"); }
        function close(): void { root.open = false; }
        function tab(name: string): void {
            const i = ["cpu", "gpu", "ram", "disk"].indexOf(name.toLowerCase());
            if (i >= 0)
                root.setTab(i);
            root.withFocusedOutput("open");
        }
    }

    Process {
        id: focusedOutput
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.pendingAction === "toggle" && root.open) {
                    root.open = false;
                    return;
                }
                try {
                    const out = JSON.parse(text);
                    if (!root.visible && out && out.name)
                        for (let i = 0; i < Quickshell.screens.length; i++)
                            if (Quickshell.screens[i].name === out.name)
                                root.screen = Quickshell.screens[i];
                } catch (e) {
                    console.warn("system ipc: не удалось разобрать focused-output:", e);
                }
                root.open = true;
            }
        }
    }

    Item { id: fullMask; anchors.fill: parent }

    // Затемнение; клик мимо окна закрывает
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.cfg.scrim ? root.progress * 0.4 : 0
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.open = false
    }

    Shortcut { sequence: "Escape"; enabled: root.open; onActivated: root.open = false }
    Shortcut { sequences: ["Right", "Tab"]; enabled: root.open; onActivated: root.setTab(root.tab + 1) }
    Shortcut { sequences: ["Left", "Backtab"]; enabled: root.open; onActivated: root.setTab(root.tab - 1) }
    Repeater {
        model: 4
        Item {
            required property int index
            Shortcut { sequence: String(parent.index + 1); enabled: root.open; onActivated: root.setTab(parent.index) }
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - root.progress) * Tokens.scaled(24)
        width: Math.min(Tokens.scaled(root.cfg.width), root.width - Tokens.spacingLarge * 4)
        height: Math.min(Tokens.scaled(root.cfg.height), root.height - Tokens.spacingLargeV * 4)
        radius: Tokens.radius(32)
        color: root.colors.surface
        opacity: root.progress
        scale: 0.94 + 0.06 * root.progress
        clip: true
        // Во время анимации окно рисуется одной текстурой: без просвечивания слоёв
        layer.enabled: root.progress > 0 && root.progress < 1
        layer.smooth: true

        // Клики внутри окна не закрывают его
        MouseArea { anchors.fill: parent }

        M3ShapeField {
            anchors.fill: parent
            visible: root.cfg.shapes
            index: root.tab
            running: root.visible && root.cfg.shapes
        }

        // Шапка: заголовок слева, вкладки по центру, период и закрытие справа
        Item {
            id: header
            x: Tokens.spacingLarge * 1.5
            y: Tokens.spacingLargeV * 1.25
            width: parent.width - x * 2
            height: Tokens.scaled(48)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacingMedium

                Rectangle {
                    id: badge
                    width: Tokens.scaled(44)
                    height: width
                    radius: badgeHover.hovered ? Tokens.radius(14) : width / 2
                    color: root.colors.primary_container
                    Behavior on radius { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutBack } }
                    HoverHandler { id: badgeHover }

                    SysIcon {
                        anchors.centerIn: parent
                        icon: "monitor_heart"
                        size: Tokens.scaled(24)
                        filled: badgeHover.hovered
                        hovered: badgeHover.hovered
                        color: root.colors.on_primary_container
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "Система"
                        font.family: Tokens.fontLarge.family
                        font.pixelSize: Tokens.scaled(22)
                        font.weight: Font.DemiBold
                        color: root.colors.on_surface
                    }
                    Text {
                        text: (root.sys.info.host ?? "") + " · в работе " + root.sys.duration(root.sys.uptime)
                        font: Tokens.fontSmall
                        color: root.colors.on_surface_variant
                    }
                }
            }

            SysTabs {
                anchors.centerIn: parent
                model: root.tabs
                current: root.tab
                onSelected: i => root.setTab(i)
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacingMedium

                SysTabs {
                    anchors.verticalCenter: parent.verticalCenter
                    model: [{ label: "1м" }, { label: "5м" }, { label: "15м" }, { label: "30м" }, { label: "1ч" }]
                    segmentWidth: Tokens.scaled(44)
                    segmentHeight: Tokens.scaled(32)
                    font: Tokens.fontSmall
                    current: Math.max(0, root.ranges.indexOf(root.cfg.range))
                    onSelected: i => root.cfg.range = root.ranges[i]
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.scaled(40)
                    height: width
                    radius: width / 2
                    color: closeArea.pressed ? root.colors.error_container : closeArea.containsMouse ? root.colors.surface_container_highest : root.colors.surface_container_high
                    scale: closeArea.pressed ? 0.9 : 1
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }

                    SysIcon {
                        anchors.centerIn: parent
                        icon: "close"
                        size: Tokens.scaled(20)
                        hovered: closeArea.containsMouse
                        color: closeArea.pressed ? root.colors.on_error_container : root.colors.on_surface
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.open = false
                    }
                }
            }
        }

        Item {
            id: body
            clip: true
            anchors.fill: parent
            anchors.topMargin: header.y + header.height + Tokens.spacingLargeV * 1.25
            anchors.leftMargin: header.x
            anchors.rightMargin: header.x
            anchors.bottomMargin: header.x

            // Вкладки создаются заранее (асинхронно), чтобы открытие не тормозило;
            // пока окно скрыто, анимации и графики в них стоят
            Loader {
                anchors.fill: parent
                asynchronous: true
                visible: root.visible
                sourceComponent: Item {
                    CpuPage { width: parent.width; height: parent.height; sys: root.sys; index: 0; pos: root.tabPos }
                    GpuPage { width: parent.width; height: parent.height; sys: root.sys; index: 1; pos: root.tabPos }
                    RamPage { width: parent.width; height: parent.height; sys: root.sys; index: 2; pos: root.tabPos }
                    DiskPage { width: parent.width; height: parent.height; sys: root.sys; index: 3; pos: root.tabPos }
                }
            }
        }
    }
}
