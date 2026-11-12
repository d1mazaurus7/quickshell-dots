import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Прозрачный оверлей поверх живого экрана: выбор области или всего монитора
PanelWindow {
    id: root

    required property var service
    readonly property var cfg: Config.options.recorder

    property bool fullscreen: false
    property bool dragging: false
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property real startX: 0
    property real startY: 0
    property rect prevSel: Qt.rect(0, 0, 0, 0)
    property bool prevFullscreen: false
    readonly property bool hasSelection: selW > 0 && selH > 0
    readonly property int minSelection: Tokens.scaled(16)

    visible: service.active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-recorder-select"
    WlrLayershell.keyboardFocus: service.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function begin(): void {
        if (!hasSelection || service.closing)
            return;
        service.start(fullscreen ? null : Qt.rect(screen.x + selX, screen.y + selY, selW, selH));
    }

    // Варианты разрешения пересчитываются по завершении выделения, а не на каждом движении
    property var resOptions: []
    function updateResolutions(): void {
        const s = service.outputScale;
        resOptions = hasSelection && !fullscreen ? service.resolutionOptions(selW * s, selH * s)
                                                 : service.resolutionOptions(service.modeWidth, service.modeHeight);
    }

    function setFullscreen(on: bool): void {
        fullscreen = on;
        selX = 0;
        selY = 0;
        selW = on ? width : 0;
        selH = on ? height : 0;
        updateResolutions();
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.service.active
        onActivated: root.service.requestClose()
    }
    Shortcut {
        sequences: ["Return", "Enter", "Space"]
        enabled: root.service.active && !root.dragging
        onActivated: root.begin()
    }

    Connections {
        target: root.service
        function onClosingChanged(): void {
            if (root.service.closing && content.opacity === 0)
                root.service.close();
        }
        function onActiveChanged(): void {
            if (root.service.active)
                root.setFullscreen(false);
        }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.service.active && !root.service.closing ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

        onOpacityChanged: {
            if (root.service.closing && opacity === 0)
                root.service.close();
        }

        readonly property color dimColor: Qt.alpha(Theme.Palette.background, 0.55)

        // Затемнение вокруг выделения
        Rectangle {
            width: parent.width
            height: root.hasSelection ? root.selY : parent.height
            color: content.dimColor
        }
        Rectangle {
            visible: root.hasSelection
            y: root.selY + root.selH
            width: parent.width
            height: parent.height - y
            color: content.dimColor
        }
        Rectangle {
            visible: root.hasSelection
            y: root.selY
            width: root.selX
            height: root.selH
            color: content.dimColor
        }
        Rectangle {
            visible: root.hasSelection
            x: root.selX + root.selW
            y: root.selY
            width: parent.width - x
            height: root.selH
            color: content.dimColor
        }

        Rectangle {
            visible: root.hasSelection && !root.fullscreen
            x: root.selX - border.width
            y: root.selY - border.width
            width: root.selW + border.width * 2
            height: root.selH + border.width * 2
            color: "transparent"
            border.color: Theme.Palette.error
            border.width: Tokens.scaled(2)
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.service.closing
            cursorShape: Qt.CrossCursor

            onPressed: event => {
                root.prevSel = root.hasSelection ? Qt.rect(root.selX, root.selY, root.selW, root.selH) : Qt.rect(0, 0, 0, 0);
                root.prevFullscreen = root.fullscreen;
                root.fullscreen = false;
                root.dragging = true;
                root.startX = event.x;
                root.startY = event.y;
                root.selX = event.x;
                root.selY = event.y;
                root.selW = 0;
                root.selH = 0;
            }
            onPositionChanged: event => {
                if (!root.dragging)
                    return;
                const x = Math.max(0, Math.min(width, event.x));
                const y = Math.max(0, Math.min(height, event.y));
                root.selX = Math.round(Math.min(root.startX, x));
                root.selY = Math.round(Math.min(root.startY, y));
                root.selW = Math.round(Math.abs(x - root.startX));
                root.selH = Math.round(Math.abs(y - root.startY));
            }
            onReleased: {
                root.dragging = false;
                if (root.selW >= root.minSelection && root.selH >= root.minSelection) {
                    root.updateResolutions();
                    return;
                }
                // Слишком малое выделение — вернуть прошлое
                root.selX = root.prevSel.x;
                root.selY = root.prevSel.y;
                root.selW = root.prevSel.width;
                root.selH = root.prevSel.height;
                root.fullscreen = root.prevFullscreen;
                root.updateResolutions();
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: hint.implicitWidth + Tokens.spacingLarge * 2
            height: hint.implicitHeight + Tokens.spacingMediumV * 2
            radius: height / 2
            color: Theme.Palette.surface_container
            opacity: !root.hasSelection && !root.dragging ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

            Text {
                id: hint
                anchors.centerIn: parent
                text: "Выделите область или выберите весь экран"
                font: Tokens.fontLarge
                color: Theme.Palette.on_surface
            }
        }

        RecorderToolbar {
            readonly property int gap: Tokens.scaled(12)

            // Без выделения — внизу по центру; иначе под областью, над ней или внутри
            x: root.hasSelection ? Math.max(gap, Math.min(parent.width - width - gap, root.selX + (root.selW - width) / 2))
                                 : (parent.width - width) / 2
            y: !root.hasSelection ? parent.height - height - gap * 4
             : root.selY + root.selH + gap + height <= parent.height - gap ? root.selY + root.selH + gap
             : root.selY - gap - height >= gap ? root.selY - gap - height
             : root.selY + root.selH - gap * 4 - height

            fullscreen: root.fullscreen
            resolutionOptions: root.resOptions
            resolution: root.cfg.resolution
            fps: root.service.fps
            fpsOptions: root.service.fpsOptions
            systemAudio: root.cfg.systemAudio
            microphone: root.cfg.microphone

            opacity: root.dragging ? 0 : 1
            scale: root.service.closing ? 0.9 : 1
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            onModePicked: on => root.setFullscreen(on)
            onResolutionPicked: r => root.cfg.resolution = r
            onFpsPicked: f => root.cfg.fps = f
            onSystemAudioToggled: root.cfg.systemAudio = !root.cfg.systemAudio
            onMicrophoneToggled: root.cfg.microphone = !root.cfg.microphone
            onRecordRequested: {
                if (root.hasSelection)
                    root.begin();
                else
                    root.service.start(null);
            }
        }
    }
}
