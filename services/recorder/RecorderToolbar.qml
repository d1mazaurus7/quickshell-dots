import QtQuick
import Quickshell
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Панель записи: [область|экран] [разрешение] [FPS] [звук] [микрофон] (запись)
Rectangle {
    id: root

    property bool fullscreen: false
    property int resolution: 0
    property var resolutionOptions: []
    property int fps: 60
    property var fpsOptions: []
    property bool systemAudio: true
    property bool microphone: false

    signal modePicked(bool fullscreen)
    signal resolutionPicked(int resolution)
    signal fpsPicked(int fps)
    signal systemAudioToggled()
    signal microphoneToggled()
    signal recordRequested()

    readonly property int itemHeight: Tokens.scaled(36)
    readonly property int recordSize: Tokens.scaled(44)
    readonly property int padding: Tokens.scaled(8)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: row.implicitHeight + padding * 2
    radius: Tokens.radiusLarge
    color: Theme.Palette.surface_container
    border.color: Theme.Palette.outline_variant
    border.width: Tokens.borderWidth

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacingMedium

        Segments {
            iconLabels: true
            options: [{ value: false, label: "crop_free" }, { value: true, label: "fullscreen" }]
            current: root.fullscreen
            onPicked: v => root.modePicked(v)
        }

        Segments {
            options: root.resolutionOptions
            // Сохранённое разрешение больше источника — исходное
            current: root.resolutionOptions.some(o => o.value === root.resolution) ? root.resolution : 0
            onPicked: v => root.resolutionPicked(v)
        }

        Segments {
            options: root.fpsOptions
            current: root.fps
            suffix: "fps"
            onPicked: v => root.fpsPicked(v)
        }

        RecButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.systemAudio ? "volume_up" : "volume_off"
            checked: root.systemAudio
            onClicked: root.systemAudioToggled()
        }
        RecButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.microphone ? "mic" : "mic_off"
            checked: root.microphone
            onClicked: root.microphoneToggled()
        }

        // Кнопка записи: круг, внутренняя точка при наведении становится квадратом
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.recordSize
            height: width
            radius: recArea.pressed ? Tokens.radiusLarge : width / 2
            color: recArea.containsMouse ? Theme.Palette.error_container : Theme.Palette.error
            scale: recArea.pressed ? 0.92 : 1

            Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.centerIn: parent
                width: recArea.containsMouse ? parent.width * 0.36 : parent.width * 0.42
                height: width
                radius: recArea.containsMouse ? Tokens.radiusSmall : width / 2
                color: recArea.containsMouse ? Theme.Palette.on_error_container : Theme.Palette.on_error

                Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            }

            MouseArea {
                id: recArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.recordRequested()
            }
        }
    }

    // Группа соединённых кнопок M3E со скользящим индикатором выбора
    component Segments: Rectangle {
        id: seg

        property var options: []
        property var current
        property bool iconLabels: false
        property string suffix: ""
        signal picked(var value)

        readonly property int index: options.findIndex(o => o.value === current)
        readonly property int inset: Tokens.scaled(3)

        anchors.verticalCenter: parent.verticalCenter
        width: segRow.implicitWidth + inset * 2
        height: root.itemHeight
        radius: height / 2
        color: Theme.Palette.surface_container_high

        Rectangle {
            readonly property Item target: rep.count > 0 && seg.index >= 0 ? rep.itemAt(seg.index) : null
            x: target ? segRow.x + target.x : 0
            y: seg.inset
            width: target ? target.width : 0
            height: seg.height - seg.inset * 2
            radius: height / 2
            color: Theme.Palette.primary

            Behavior on x { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }

        Row {
            id: segRow
            x: seg.inset
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                id: rep
                model: seg.options

                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === seg.index

                    width: Math.max(seg.height - seg.inset * 2, label.implicitWidth + Tokens.spacingLarge)
                    height: seg.height - seg.inset * 2

                    // Слой состояния hover/pressed
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.Palette.on_surface
                        opacity: cell.selected ? 0 : cellArea.pressed ? 0.12 : cellArea.containsMouse ? 0.08 : 0

                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: cell.modelData.label + (seg.suffix !== "" && cell.selected ? " " + seg.suffix : "")
                        font.family: seg.iconLabels ? "Material Symbols Rounded" : Tokens.fontMedium.family
                        font.pixelSize: seg.iconLabels ? Tokens.scaled(20) : Tokens.fontMedium.pixelSize
                        font.weight: cell.selected ? Font.DemiBold : Font.Normal
                        color: cell.selected ? Theme.Palette.on_primary : Theme.Palette.on_surface_variant
                        scale: cellArea.pressed ? 0.9 : 1

                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!cell.selected) seg.picked(cell.modelData.value)
                    }
                }
            }
        }
    }
}
