pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import "../../theme" as Theme
import "../../shell/config"
import "../../shell/theme"
import "../power"

// Меню профилей производительности (power-profiles-daemon), выезжает из нижней кромки экрана.
// IPC: qs ipc call performance toggle|open|close — открывается на мониторе в фокусе Niri
PanelWindow {
    id: root

    property bool open: false

    readonly property var cfg: Config.options.performanceMenu
    readonly property var colors: Theme.Palette
    readonly property int contentWidth: Tokens.scaled(cfg.width)
    readonly property int contentHeight: Tokens.scaled(cfg.height)
    readonly property int padding: Tokens.spacingLarge
    readonly property int gap: Tokens.spacingLarge
    readonly property int radius: Tokens.radius(16)
    readonly property int ear: Tokens.radius(16)
    property real revealHeight: open ? contentHeight : 0

    Behavior on revealHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    readonly property var actions: [
        { shown: cfg.showPowerSaver, icon: "eco", notifyIcon: "power-profile-power-saver-symbolic", label: "Экономия", profile: PowerProfile.PowerSaver },
        { shown: cfg.showBalanced, icon: "balance", notifyIcon: "power-profile-balanced-symbolic", label: "Обычный", profile: PowerProfile.Balanced },
        { shown: cfg.showPerformance && PowerProfiles.hasPerformanceProfile, icon: "speed", notifyIcon: "power-profile-performance-symbolic", label: "Производительность", profile: PowerProfile.Performance }
    ].filter(a => a.shown)

    // Размер кнопки: все помещаются в ширину, кнопка с подписью — в высоту
    readonly property int labelHeight: cfg.labels ? Math.ceil(labelMetrics.height) + Tokens.spacingSmallV : 0
    readonly property int buttonSize: {
        const n = Math.max(1, actions.length);
        const byWidth = (contentWidth - padding * 2 - gap * (n - 1)) / n;
        const byHeight = contentHeight - padding * 2 - labelHeight;
        return Math.max(0, Math.floor(Math.min(byWidth, byHeight)));
    }

    WlrLayershell.namespace: "qs:performance"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors.bottom: true
    implicitWidth: contentWidth + ear * 2
    implicitHeight: contentHeight
    visible: open || revealHeight > 0
    mask: Region { item: maskItem }

    function apply(profile: int, label: string, icon: string): void {
        open = false;
        PowerProfiles.profile = profile;
        Quickshell.execDetached(["notify-send", "-a", "Quickshell", "-i", icon, "Профиль производительности", label]);
    }

    onVisibleChanged: {
        if (!visible)
            for (let i = 0; i < buttons.count; i++)
                buttons.itemAt(i).reset();
    }

    FontMetrics {
        id: labelMetrics
        font: Tokens.fontSmall
    }

    property string pendingAction: ""

    function withFocusedOutput(action: string): void {
        pendingAction = action;
        focusedOutput.running = true;
    }

    IpcHandler {
        target: "performance"

        function toggle(): void { root.withFocusedOutput("toggle"); }
        function open(): void { root.withFocusedOutput("open"); }
        function close(): void { root.open = false; }
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
                // Монитор меняется только у скрытого окна
                try {
                    const out = JSON.parse(text);
                    if (!root.visible && out && out.name) {
                        for (let i = 0; i < Quickshell.screens.length; i++)
                            if (Quickshell.screens[i].name === out.name)
                                root.screen = Quickshell.screens[i];
                    }
                } catch (e) {
                    console.warn("performance ipc: не удалось разобрать focused-output:", e);
                }
                root.open = true;
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.open = false
    }

    Item {
        id: maskItem
        y: root.height - root.revealHeight
        width: root.width
        height: root.revealHeight
    }

    // Фон: вогнутые «уши» у кромки экрана, скруглённые углы сверху.
    // Нарисован как у BarDropdown и отражён по вертикали.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.y: root.height / 2; yScale: -1 }

        ShapePath {
            id: bg

            readonly property real w: root.width
            readonly property real h: root.revealHeight
            readonly property real er: root.ear
            readonly property real erY: Math.min(er, h / 2)
            readonly property real br: root.radius
            readonly property real brY: Math.min(br, h / 2)

            strokeWidth: -1
            fillColor: root.colors.background

            startX: 0; startY: 0
            PathLine { x: bg.w; y: 0 }
            PathArc { x: bg.w - bg.er; y: bg.erY; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
            PathLine { x: bg.w - bg.er; y: bg.h - bg.brY }
            PathArc { x: bg.w - bg.er - bg.br; y: bg.h; radiusX: bg.br; radiusY: bg.brY }
            PathLine { x: bg.er + bg.br; y: bg.h }
            PathArc { x: bg.er; y: bg.h - bg.brY; radiusX: bg.br; radiusY: bg.brY }
            PathLine { x: bg.er; y: bg.erY }
            PathArc { x: 0; y: 0; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
        }
    }

    // Содержимое стоит на месте и открывается вместе с фоном
    Item {
        id: reveal
        x: root.ear
        y: root.height - root.revealHeight
        width: root.contentWidth
        height: root.revealHeight
        clip: true

        Row {
            x: (root.contentWidth - width) / 2
            y: (root.contentHeight - height) / 2 - reveal.y
            spacing: root.gap

            Repeater {
                id: buttons
                model: root.actions

                PowerButton {
                    required property var modelData

                    icon: modelData.icon
                    label: modelData.label
                    showLabel: root.cfg.labels
                    holdTime: root.cfg.holdTime
                    size: root.buttonSize
                    active: PowerProfiles.profile === modelData.profile
                    onActivated: root.apply(modelData.profile, modelData.label, modelData.notifyIcon)
                }
            }
        }
    }
}
