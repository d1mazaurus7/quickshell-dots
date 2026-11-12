pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"
import "../controls"
import "../../Bar/music_equalizer" as Music

// Эквалайзер в виджете: полосы на всю ширину, пресеты столбцом справа.
// equalizer — общее состояние оболочки (WidgetsState.services.equalizer)
Item {
    id: root

    property var equalizer: null

    readonly property var colors: Tokens.colors

    Text {
        anchors.centerIn: parent
        visible: root.equalizer === null
        text: "Эквалайзер недоступен"
        color: root.colors.on_surface_variant
        font: Tokens.fontMedium
    }

    Row {
        id: bands
        visible: root.equalizer !== null
        anchors.left: parent.left
        anchors.right: presets.visible ? presets.left : parent.right
        anchors.rightMargin: presets.visible ? Tokens.spacingMedium : 0
        height: parent.height
        spacing: Tokens.scaled(2)

        Repeater {
            model: root.equalizer?.frequencies ?? []

            Music.EqSlider {
                required property int modelData
                required property int index
                width: (bands.width - bands.spacing * 9) / 10
                height: bands.height
                value: root.equalizer.gains[index]
                from: root.equalizer.minGain
                to: root.equalizer.maxGain
                label: modelData >= 1000 ? (modelData / 1000) + "k" : String(modelData)
                onMoved: v => root.equalizer.setGain(index, v)
            }
        }
    }

    ListView {
        id: presets
        visible: root.equalizer !== null && count > 0
        anchors.right: parent.right
        width: Tokens.scaled(88)
        height: parent.height
        clip: true
        spacing: Tokens.spacingSmallV
        boundsBehavior: Flickable.StopAtBounds
        model: root.equalizer?.presets ?? []

        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool active: root.equalizer.activePreset === modelData.name

            width: presets.width
            height: Tokens.scaled(30)
            radius: Tokens.radius(active ? height / 2 : Tokens.scaled(10))
            color: active ? root.colors.primary : root.colors.surface_container_high
            scale: chipArea.pressed ? 0.96 : 1

            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: chip.active ? root.colors.on_primary : root.colors.on_surface
                opacity: chipArea.pressed ? 0.12 : chipArea.containsMouse ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - Tokens.spacingMedium * 2
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: chip.modelData.name
                color: chip.active ? root.colors.on_primary : root.colors.on_surface
                font: Tokens.fontSmall
            }

            MouseArea {
                id: chipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: WidgetSound.click()
                onClicked: root.equalizer.loadPreset(chip.modelData)
            }
        }
    }
}
