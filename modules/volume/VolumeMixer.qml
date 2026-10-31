pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../shell/theme"

// Содержимое окна громкости: выходы, входы, кнопки перезапуска
ColumnLayout {
    id: mixer

    required property VolumeState audio
    property bool showOutputs: true
    property bool showInputs: true
    property bool showRestart: true

    readonly property var colors: Tokens.colors

    spacing: Tokens.spacingMediumV

    component Section: ColumnLayout {
        id: section

        property string title
        property var nodes: []

        Layout.fillWidth: true
        spacing: Tokens.spacingMediumV

        Text {
            text: section.title
            color: mixer.colors.on_surface
            font: Tokens.fontLarge
        }

        Text {
            visible: section.nodes.length === 0
            text: "Нет приложений"
            color: mixer.colors.on_surface_variant
            font: Tokens.fontSmall
        }

        // ScriptModel сохраняет делегаты при обновлении списка — перетаскиваемый слайдер не пересоздаётся
        Repeater {
            model: ScriptModel { values: section.nodes }
            AppVolumeCard {
                required property var modelData
                node: modelData
            }
        }
    }

    Section {
        visible: mixer.showOutputs
        title: "Выходы:"
        nodes: mixer.audio.outputs
    }

    Section {
        Layout.topMargin: Tokens.spacingMediumV
        visible: mixer.showInputs
        title: "Входы:"
        nodes: mixer.audio.inputs
    }

    // Нажатая кнопка расширяется и теснит соседнюю
    Item {
        id: actions

        readonly property real half: (width - Tokens.spacingMedium) / 2
        readonly property real grow: Tokens.scaled(24)
        property real shift: restartAudio.pressed ? grow : restartEasyEffects.pressed ? -grow : 0
        Behavior on shift { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacingLargeV
        visible: mixer.showRestart
        implicitHeight: Tokens.scaled(36)

        MixerButton {
            id: restartAudio
            width: actions.half + actions.shift
            height: parent.height
            text: "Перезагрузить звуковое ядро"
            onClicked: mixer.audio.restartAudio()
        }

        MixerButton {
            id: restartEasyEffects
            anchors.right: parent.right
            width: actions.half - actions.shift
            height: parent.height
            text: "Перезагрузить EasyEffects"
            onClicked: mixer.audio.restartEasyEffects()
        }
    }
}
