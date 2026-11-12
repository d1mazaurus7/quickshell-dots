import QtQuick
import QtQuick.Effects
import "../../shell/theme"

// Фон лок-скрина: картинка (скриншот, обои или первый кадр видео) и видео поверх неё.
// Одно размытие на всё: его показывает фон (blur) и берут виджеты с blurItem (blurSource)
Item {
    id: root

    // Путь к картинке; "" — однотонный surface
    property string source: ""
    // Путь к видео; "" — без видео
    property string video: ""
    property bool blur: false
    // 0..1: проявление размытия и затемнения
    property real reveal: 1
    readonly property Item blurSource: blurred
    readonly property bool ready: image.status === Image.Ready || videoLoader.status === Loader.Ready

    Rectangle {
        anchors.fill: parent
        color: Tokens.colors.surface
    }

    Item {
        id: media
        anchors.fill: parent

        Image {
            id: image
            anchors.fill: parent
            source: root.source !== "" ? "file://" + root.source : ""
            fillMode: Image.PreserveAspectCrop
            // Файлы перезаписываются по тому же пути — кэш не нужен
            cache: false
            sourceSize.width: width
            sourceSize.height: height
        }

        Loader {
            id: videoLoader
            anchors.fill: parent
            active: root.video !== ""
            Component.onCompleted: setSource(Qt.resolvedUrl("LockVideo.qml"), { source: "file://" + root.video })
        }
    }

    // Считается, только пока его кто-то показывает
    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        source: media
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
    }

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: blurred
        visible: root.blur && root.ready && opacity > 0
        opacity: root.reveal
    }

    Rectangle {
        anchors.fill: parent
        color: Tokens.colors.background
        opacity: 0.3 * root.reveal
    }
}
