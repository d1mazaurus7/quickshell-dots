pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import "../../shell/theme"
import "../controls"
import "../../Bar/music_equalizer" as Music
import "MediaShapes.js" as Shapes

// Виджет «Медиа»: фото, gif или видео из любого файла, обрезанные по шаблону формы
Item {
    id: root

    property var settings: ({})
    property bool editing: false
    property var services: ({})

    readonly property var colors: Tokens.colors
    readonly property string path: settings.source
    readonly property string ext: path.slice(path.lastIndexOf(".") + 1).toLowerCase()
    readonly property bool isVideo: Shapes.videoSuffixes.includes(ext)
    readonly property bool isAnimated: ext === "gif" || ext === "webp"
    readonly property url url: path === "" ? "" : "file://" + path.split("/").map(encodeURIComponent).join("/")

    readonly property string shape: settings.shape
    // Фигура на всё окно; квадратный круг — дешёвый ClippingRectangle, остальное — маска
    readonly property bool polygon: shape !== "rect" && !(shape === "circle" && width === height)
    // Меньшая сторона: скругление прямоугольника, круг, значок-заглушка
    readonly property real side: Math.min(width, height)
    readonly property bool loaded: isVideo ? video.status === Loader.Ready
        : media.item !== null && media.item.status === Image.Ready

    readonly property var player: video.item
    // 1 — MediaPlayer.PlayingState (QtMultimedia здесь не импортируется)
    readonly property bool playing: player !== null && player.playbackState === 1
    // Пауза, пока окно niri в фокусе; кнопка таймлайна переопределяет до смены фокуса
    readonly property bool windowFocused: services.focus?.focused ?? false
    property bool userPaused: false
    property bool forced: false
    readonly property bool shouldPlay: !userPaused && (!windowFocused || forced)
    onWindowFocusedChanged: forced = false
    // Таймлайн по ПКМ, только у видео
    property bool controls: false
    onIsVideoChanged: controls = false
    onEditingChanged: controls = false

    function time(ms: real): string {
        const s = Math.floor(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60;
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
    }

    // Прямоугольник и квадратный круг: дешёвая обрезка ClippingRectangle
    ClippingRectangle {
        id: frame
        anchors.fill: parent
        visible: !root.polygon
        radius: root.shape === "circle" ? root.side / 2 : root.side / 2 * root.settings.radius
        color: "transparent"
    }

    // Фигуры: маска через layer.effect на видимом содержимом. Источник с visible: false
    // (MultiEffect.source, скрытый ClippingRectangle) не обновляет кадры видео
    Item {
        id: content
        parent: root.polygon ? root : frame.contentItem
        width: root.width
        height: root.height
        // При переносе в root элемент встаёт последним — держим его под таймлайном
        z: -1
        layer.enabled: root.polygon
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
            autoPaddingEnabled: false
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.loaded
            color: root.colors.surface_container_high
        }

        Text {
            anchors.centerIn: parent
            visible: !root.loaded
            text: root.path === "" ? "add_photo_alternate" : "broken_image"
            color: root.colors.on_surface_variant
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.round(root.side * 0.35)
        }

        Loader {
            id: media
            anchors.fill: parent
            active: root.path !== "" && !root.isVideo
            sourceComponent: root.isAnimated ? animated : still
        }

        // QtMultimedia подгружается только для видео
        Loader {
            id: video
            anchors.fill: parent
            active: root.path !== "" && root.isVideo
            source: Qt.resolvedUrl("MediaVideo.qml")
            onLoaded: {
                item.allowed = Qt.binding(() => root.shouldPlay);
                item.source = Qt.binding(() => root.url);
            }
        }
    }

    Component {
        id: still
        Image {
            // Шаг 128 px: при изменении размера картинка не перечитывается на каждый пиксель
            source: root.url
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Math.ceil(width / 128) * 128
            sourceSize.height: Math.ceil(height / 128) * 128
            asynchronous: true
            retainWhileLoading: true
        }
    }

    Component {
        id: animated
        AnimatedImage {
            source: root.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            playing: root.shouldPlay
        }
    }

    // Маска шаблона: рисуется в текстуру один раз при смене формы/размера
    Shape {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.polygon
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: "white"
            PathSvg { path: root.polygon ? Shapes.path(root.shape, root.width, root.height, root.settings.radius) : "" }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.isVideo && root.player !== null && !root.editing
        acceptedButtons: Qt.RightButton
        onPressed: WidgetSound.click()
        onClicked: root.controls = !root.controls
    }

    // Прячется через 4 с без наведения
    Timer {
        interval: 4000
        running: root.controls && !hover.hovered
        onTriggered: root.controls = false
    }

    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.spacingSmall
        height: Tokens.scaled(40)
        radius: height / 2
        color: Qt.alpha(root.colors.surface_container, 0.88)
        opacity: root.controls ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            y: root.controls ? 0 : Tokens.scaled(8)
            Behavior on y { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        // Плеер может пропасть, пока таймлайн гаснет
        readonly property bool live: visible && root.player !== null

        HoverHandler { id: hover }

        IconButton {
            id: playButton
            anchors.left: parent.left
            anchors.leftMargin: Tokens.scaled(4)
            anchors.verticalCenter: parent.verticalCenter
            size: Tokens.scaled(32)
            icon: root.playing ? "pause" : "play_arrow"
            onClicked: {
                root.userPaused = root.shouldPlay;
                root.forced = !root.userPaused;
            }
        }

        // Позиция читается только пока таймлайн виден
        Music.WaveSlider {
            anchors.left: playButton.right
            anchors.right: timeText.visible ? timeText.left : parent.right
            anchors.leftMargin: Tokens.spacingSmall
            anchors.rightMargin: Tokens.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            height: Tokens.scaled(24)
            style: "material"
            playing: root.playing
            seekable: bar.live && root.player.seekable
            value: bar.live && root.player.duration > 0 ? root.player.position / root.player.duration : 0
            onSeekRequested: v => root.player.seek(v * root.player.duration)
        }

        Text {
            id: timeText
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.width > Tokens.scaled(220)
            text: bar.live ? root.time(root.player.position) + " / " + root.time(root.player.duration) : ""
            color: root.colors.on_surface
            font: Tokens.fontSmall
        }
    }
}
