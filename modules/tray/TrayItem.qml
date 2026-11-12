import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../theme" as Theme
import "../../shell/theme"

// Строка списка трея: иконка, название, описание и кнопка "Остановить".
Rectangle {
    id: root

    required property var item
    signal stopRequested()

    // Локальные параметры оформления
    property int rowPadding: 8
    property int rowRadius: Tokens.radius(12)
    property int iconBoxSize: 36
    property int iconSize: 22
    property int iconRadius: Tokens.radius(10)
    property int nameFontSize: 13
    property int descFontSize: 11
    property int stopFontSize: 12
    property int stopPaddingH: 12
    property int stopHeight: 28
    property int stopRadius: Tokens.radius(8)
    property int hoverDuration: 120
    // Скорость прокрутки длинного названия (px/с) и пауза на краях (мс).
    property int marqueeSpeed: 30
    property int marqueePause: 1500
    property string fontFamily: "JetBrains Mono"

    readonly property string name: item.tooltipTitle || item.title || item.id
    readonly property string description: item.tooltipDescription || ""

    implicitHeight: row.implicitHeight + rowPadding * 2
    radius: rowRadius
    color: rowArea.pressed ? Theme.Palette.surface_container_highest
         : rowArea.containsMouse ? Theme.Palette.surface_container_high
         : Theme.Palette.surface_container_low

    Behavior on color { ColorAnimation { duration: root.hoverDuration; easing.type: Easing.OutCubic } }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.item.activate()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: root.rowPadding
        spacing: root.rowPadding + 4

        Rectangle {
            Layout.preferredWidth: root.iconBoxSize
            Layout.preferredHeight: root.iconBoxSize
            radius: root.iconRadius
            color: Theme.Palette.surface_container_highest

            IconImage {
                anchors.centerIn: parent
                implicitSize: root.iconSize
                source: root.item.icon
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Название, не влезающее в строку, прокручивается по X.
            Item {
                id: nameBox
                Layout.fillWidth: true
                implicitHeight: nameText.implicitHeight
                clip: true

                readonly property real overflow: Math.max(0, nameText.implicitWidth - width)

                Text {
                    id: nameText
                    text: root.name
                    color: Theme.Palette.on_surface
                    font.family: root.fontFamily
                    font.pixelSize: root.nameFontSize
                }

                SequentialAnimation {
                    running: nameBox.overflow > 0
                    loops: Animation.Infinite
                    onStopped: nameText.x = 0

                    PauseAnimation { duration: root.marqueePause }
                    NumberAnimation {
                        target: nameText; property: "x"
                        from: 0; to: -nameBox.overflow
                        duration: nameBox.overflow / root.marqueeSpeed * 1000
                        easing.type: Easing.InOutSine
                    }
                    PauseAnimation { duration: root.marqueePause }
                    NumberAnimation {
                        target: nameText; property: "x"
                        from: -nameBox.overflow; to: 0
                        duration: nameBox.overflow / root.marqueeSpeed * 1000
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.description.length > 0
                text: root.description
                textFormat: Text.PlainText
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                color: Theme.Palette.on_surface_variant
                font.family: root.fontFamily
                font.pixelSize: root.descFontSize
            }
        }

        Rectangle {
            Layout.preferredWidth: stopLabel.implicitWidth + root.stopPaddingH * 2
            Layout.preferredHeight: root.stopHeight
            radius: root.stopRadius
            color: stopArea.pressed ? Theme.Palette.error
                 : stopArea.containsMouse ? Theme.Palette.error_container
                 : Theme.Palette.surface_container_highest

            Behavior on color { ColorAnimation { duration: root.hoverDuration; easing.type: Easing.OutCubic } }

            Text {
                id: stopLabel
                anchors.centerIn: parent
                text: "Остановить"
                color: stopArea.pressed ? Theme.Palette.on_error
                     : stopArea.containsMouse ? Theme.Palette.on_error_container
                     : Theme.Palette.on_surface
                font.family: root.fontFamily
                font.pixelSize: root.stopFontSize
            }

            MouseArea {
                id: stopArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.stopRequested()
            }
        }
    }
}
