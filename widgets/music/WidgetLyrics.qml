pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import "../../shell/theme"
import "../../Bar/music_equalizer" as Music

// Текст песни в виджете: текущая строка держится по центру. Параметры — из настроек экземпляра
Item {
    id: root

    required property Music.LyricsState lyrics
    property MprisPlayer player: null
    property var settings: ({})

    readonly property var colors: Tokens.colors
    readonly property int align: settings.lyricsAlign === "left" ? Text.AlignLeft
        : settings.lyricsAlign === "right" ? Text.AlignRight : Text.AlignHCenter

    // После ручной прокрутки не возвращаем вид к текущей строке какое-то время
    property bool following: true

    ListView {
        id: view
        anchors.fill: parent
        visible: root.lyrics.status === "ready"
        clip: true
        interactive: root.settings.lyricsScroll === true
        model: root.lyrics.lines
        currentIndex: root.lyrics.currentIndex
        spacing: Tokens.scaled(2)
        topMargin: height / 2
        bottomMargin: height / 2
        boundsBehavior: Flickable.StopAtBounds

        highlight: Item {}
        highlightRangeMode: root.following && root.lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - Tokens.scaled(16)
        preferredHighlightEnd: height / 2 + Tokens.scaled(16)
        highlightMoveDuration: Tokens.animationSlow
        highlightMoveVelocity: -1

        onModelChanged: positionViewAtBeginning()
        onMovementStarted: {
            root.following = false;
            resume.restart();
        }

        delegate: Text {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: index === view.currentIndex
            readonly property bool seekable: root.lyrics.synced && root.player !== null && root.player.canSeek && root.settings.lyricsSeek === true

            width: view.width
            topPadding: Tokens.scaled(3)
            bottomPadding: Tokens.scaled(3)
            text: modelData.text
            wrapMode: Text.Wrap
            horizontalAlignment: root.align
            transformOrigin: root.align === Text.AlignLeft ? Item.Left : root.align === Text.AlignRight ? Item.Right : Item.Center
            color: current || lineArea.containsMouse ? root.colors.on_surface : root.colors.on_surface_variant
            opacity: !root.lyrics.synced || current ? 1 : lineArea.containsMouse ? 0.85 : 0.5
            scale: current ? 1.05 : lineArea.pressed ? 0.97 : 1
            font.family: Tokens.typography.family
            font.pixelSize: Tokens.scaled(root.settings.lyricsFontSize)
            font.weight: Font.Medium

            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
            Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

            MouseArea {
                id: lineArea
                anchors.fill: parent
                enabled: line.seekable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.player.position = line.modelData.time;
                    root.following = true;
                }
            }
        }
    }

    Timer {
        id: resume
        interval: 3000
        onTriggered: root.following = true
    }

    // Загрузка, нет текста, ошибка
    Row {
        anchors.centerIn: parent
        visible: !view.visible
        spacing: Tokens.spacingMedium

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ({
                loading: "hourglass_empty",
                instrumental: "piano",
                error: "cloud_off"
            })[root.lyrics.status] ?? "lyrics"
            color: root.colors.on_surface_variant
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(24)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ({
                idle: "Ничего не играет",
                loading: "Ищем текст…",
                instrumental: "Инструментальная композиция",
                notfound: "Текст не найден",
                error: "Не удалось загрузить текст"
            })[root.lyrics.status] ?? ""
            color: root.colors.on_surface_variant
            font: Tokens.fontMedium
        }
    }
}
