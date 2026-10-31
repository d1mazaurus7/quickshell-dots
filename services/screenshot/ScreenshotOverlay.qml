import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Полноэкранный оверлей: замороженный кадр экрана, выделение области,
// рисование (кисть, ластик, размытие) и сохранение результата
PanelWindow {
    id: root

    required property var service
    readonly property var cfg: Config.options.screenshot

    // "select" — выделение области, "edit" — область выбрана, доступна панель
    property string phase: "select"
    // Активный инструмент: "" | "brush" | "eraser" | "blur"
    property string tool: ""
    property bool dragging: false
    property bool busy: false

    // Выделенная область в координатах окна
    property real selX: 0
    property real selY: 0
    property real selW: 0
    property real selH: 0
    property real startX: 0
    property real startY: 0
    readonly property bool hasSelection: selW > 0 && selH > 0

    Connections {
        target: root.cfg
        function onEditToolsChanged(): void {
            if (!root.cfg.editTools)
                root.tool = "";
        }
    }

    readonly property int minSelection: Tokens.scaled(8)
    readonly property int brushWidth: Tokens.scaled(4)
    readonly property int eraserWidth: Tokens.scaled(24)
    readonly property int blurWidth: Tokens.scaled(32)

    visible: service.active
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-screenshot"
    WlrLayershell.keyboardFocus: service.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Кадр и холсты из frameLoader (пересоздаются при каждом открытии)
    readonly property var frame: frameLoader.item

    Shortcut {
        sequence: "Escape"
        enabled: root.service.active
        onActivated: root.service.requestClose()
    }

    // Окно, ещё не получившее кадр, закрывается сразу — анимировать нечего
    Connections {
        target: root.service
        function onClosingChanged(): void {
            if (root.service.closing && content.opacity === 0)
                root.service.close();
        }
        // Новое открытие — сброс состояния
        function onActiveChanged(): void {
            if (!root.service.active)
                return;
            root.phase = "select";
            root.tool = "";
            root.dragging = false;
            root.busy = false;
            root.selW = 0;
            root.selH = 0;
        }
    }

    // Отрезок штриха текущим инструментом (координаты окна)
    function stroke(x0: real, y0: real, x1: real, y1: real): void {
        if (!frame)
            return;
        if (tool === "brush") {
            frame.paintCanvas.addSegment(x0, y0, x1, y1, brushWidth, Theme.Palette.primary, false);
        } else if (tool === "blur") {
            frame.blurMask.addSegment(x0, y0, x1, y1, blurWidth, "black", false);
        } else if (tool === "eraser") {
            frame.paintCanvas.addSegment(x0, y0, x1, y1, eraserWidth, "black", true);
            frame.blurMask.addSegment(x0, y0, x1, y1, eraserWidth, "black", true);
        }
    }

    // Рендер выделенной области в PNG с учётом масштаба экрана
    function capture(save: bool, copy: bool): void {
        if (busy || !hasSelection)
            return;
        busy = true;
        const ok = cropView.grabToImage(result => {
            if (result.saveToFile(root.service.tempPath)) {
                root.service.finish(save, copy);
            } else {
                console.warn("screenshot: не удалось записать", root.service.tempPath);
                root.busy = false;
            }
        }, Qt.size(cropView.textureSize.width, cropView.textureSize.height));
        if (!ok)
            busy = false;
    }

    Item {
        id: content
        anchors.fill: parent
        // Окно прозрачно, пока кадр не загружен
        opacity: root.frame && root.frame.shot.status === Image.Ready && !root.service.closing ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

        // Закрытие — после того, как содержимое плавно исчезло
        onOpacityChanged: {
            if (root.service.closing && opacity === 0)
                root.service.close();
        }

        // Снимок экрана со всеми правками. Загружается на время открытия:
        // новый кадр и чистые холсты при каждом снимке
        Loader {
            id: frameLoader
            anchors.fill: parent
            active: root.service.active

            sourceComponent: Item {
                readonly property var shot: shotView
                readonly property var paintCanvas: paintLayer
                readonly property var blurMask: blurLayer

                Image {
                    id: shotView
                    anchors.fill: parent
                    source: "file://" + root.service.framePath
                    // Файл перезаписывается при каждом снимке
                    cache: false
                    asynchronous: true
                }

                // Размытая копия кадра, видимая только там, где прошлась кисть размытия
                MultiEffect {
                    anchors.fill: parent
                    source: shotView
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    maskEnabled: true
                    maskSource: blurLayer
                }

                StrokeCanvas {
                    id: blurLayer
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                }

                StrokeCanvas {
                    id: paintLayer
                    anchors.fill: parent
                }
            }
        }

        // Выделенный фрагмент кадра — источник для сохранения.
        // Совпадает с кадром под ним пиксель в пиксель.
        ShaderEffectSource {
            id: cropView
            x: root.selX
            y: root.selY
            width: Math.max(1, root.selW)
            height: Math.max(1, root.selH)
            visible: root.hasSelection
            sourceItem: frameLoader
            sourceRect: Qt.rect(root.selX, root.selY, width, height)
            textureSize: Qt.size(Math.round(width * root.devicePixelRatio), Math.round(height * root.devicePixelRatio))
        }

        // Затемнение вокруг выделения
        Rectangle {
            x: 0
            y: 0
            width: parent.width
            height: root.hasSelection ? root.selY : parent.height
            color: content.dimColor
        }
        Rectangle {
            visible: root.hasSelection
            x: 0
            y: root.selY + root.selH
            width: parent.width
            height: parent.height - y
            color: content.dimColor
        }
        Rectangle {
            visible: root.hasSelection
            x: 0
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
        readonly property color dimColor: Qt.alpha(Theme.Palette.background, 0.55)

        // Рамка выделения
        Rectangle {
            visible: root.hasSelection
            x: root.selX - border.width
            y: root.selY - border.width
            width: root.selW + border.width * 2
            height: root.selH + border.width * 2
            color: "transparent"
            border.color: Theme.Palette.primary
            border.width: Tokens.scaled(2)
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: !root.busy && !root.service.closing
            cursorShape: root.phase === "select" || root.tool !== "" ? Qt.CrossCursor : Qt.ArrowCursor

            property real lastX: 0
            property real lastY: 0

            onPressed: event => {
                if (root.phase === "select") {
                    root.dragging = true;
                    root.startX = event.x;
                    root.startY = event.y;
                    root.selX = event.x;
                    root.selY = event.y;
                    root.selW = 0;
                    root.selH = 0;
                } else if (root.tool !== "") {
                    lastX = event.x;
                    lastY = event.y;
                    root.stroke(event.x, event.y, event.x, event.y);
                }
            }

            onPositionChanged: event => {
                if (root.dragging) {
                    const x = Math.max(0, Math.min(width, event.x));
                    const y = Math.max(0, Math.min(height, event.y));
                    root.selX = Math.round(Math.min(root.startX, x));
                    root.selY = Math.round(Math.min(root.startY, y));
                    root.selW = Math.round(Math.abs(x - root.startX));
                    root.selH = Math.round(Math.abs(y - root.startY));
                } else if (pressed && root.phase === "edit" && root.tool !== "") {
                    root.stroke(lastX, lastY, event.x, event.y);
                    lastX = event.x;
                    lastY = event.y;
                }
            }

            onReleased: {
                if (!root.dragging)
                    return;
                root.dragging = false;
                if (root.selW >= root.minSelection && root.selH >= root.minSelection) {
                    root.phase = "edit";
                    if (root.cfg.instant)
                        root.capture(true, true);
                } else {
                    root.selW = 0;
                    root.selH = 0;
                }
            }
        }

        // Подсказка до начала выделения
        Rectangle {
            anchors.centerIn: parent
            width: hint.implicitWidth + Tokens.spacingLarge * 2
            height: hint.implicitHeight + Tokens.spacingMediumV * 2
            radius: height / 2
            color: Theme.Palette.surface_container
            opacity: root.phase === "select" && !root.dragging ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

            Text {
                id: hint
                anchors.centerIn: parent
                text: "Выделите область экрана мышью"
                font: Tokens.fontLarge
                color: Theme.Palette.on_surface
            }
        }

        ScreenshotToolbar {
            id: toolbar

            readonly property int gap: Tokens.scaled(12)

            x: Math.max(gap, Math.min(parent.width - width - gap, root.selX + (root.selW - width) / 2))
            // Под областью; если не помещается — над ней; иначе внутри у нижнего края
            y: root.selY + root.selH + gap + height <= parent.height - gap ? root.selY + root.selH + gap
             : root.selY - gap - height >= gap ? root.selY - gap - height
             : root.selY + root.selH - gap - height

            tool: root.tool
            editTools: root.cfg.editTools
            enabled: !root.busy
            opacity: root.phase === "edit" && !root.cfg.instant ? 1 : 0
            scale: root.phase === "edit" && !root.service.closing ? 1 : 0.9
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            onToolSelected: name => root.tool = root.tool === name ? "" : name
            onSaveRequested: root.capture(true, false)
            onCopyRequested: root.capture(false, true)
            onCaptureRequested: root.capture(true, true)
        }
    }
}
