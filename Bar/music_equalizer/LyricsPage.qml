pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Страница с текстом песни: текущая строка подсвечена и держится по центру
Item {
    id: root

    required property LyricsState lyrics
    property MprisPlayer player: null

    readonly property var cfg: Config.options.musicPlayer

    // После ручной прокрутки не возвращаем вид к текущей строке какое-то время
    property bool following: true

    ListView {
        id: view
        anchors.fill: parent
        visible: root.lyrics.status === "ready"
        clip: true
        interactive: root.cfg.lyricsScroll
        model: root.lyrics.lines
        currentIndex: root.lyrics.currentIndex
        spacing: Tokens.scaled(6)
        topMargin: height / 2
        bottomMargin: height / 2
        boundsBehavior: Flickable.StopAtBounds

        highlight: Item {}
        highlightRangeMode: root.following && root.lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height / 2 - Tokens.scaled(24)
        preferredHighlightEnd: height / 2 + Tokens.scaled(24)
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
            readonly property bool seekable: root.lyrics.synced && root.player !== null && root.player.canSeek && root.cfg.lyricsSeek

            width: view.width
            topPadding: Tokens.scaled(4)
            bottomPadding: Tokens.scaled(4)
            text: modelData.text
            wrapMode: Text.Wrap
            horizontalAlignment: root.cfg.lyricsAlign === "left" ? Text.AlignLeft : root.cfg.lyricsAlign === "right" ? Text.AlignRight : Text.AlignHCenter
            transformOrigin: root.cfg.lyricsAlign === "left" ? Item.Left : root.cfg.lyricsAlign === "right" ? Item.Right : Item.Center
            color: current || lineArea.containsMouse ? Theme.Palette.on_surface : Theme.Palette.on_surface_variant
            opacity: !root.lyrics.synced || current ? 1 : lineArea.containsMouse ? 0.85 : 0.5
            scale: current ? 1.06 : lineArea.pressed ? 0.97 : 1
            font.family: Tokens.typography.family
            font.pixelSize: Tokens.scaled(root.cfg.lyricsFontSize)
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
    Column {
        anchors.centerIn: parent
        visible: !view.visible
        spacing: Tokens.scaled(8)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({
                loading: "hourglass_empty",
                instrumental: "piano",
                error: "cloud_off"
            })[root.lyrics.status] ?? "lyrics"
            color: Theme.Palette.on_surface_variant
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(40)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({
                idle: "Ничего не играет",
                loading: "Ищем текст…",
                instrumental: "Инструментальная композиция",
                notfound: "Текст не найден",
                error: "Не удалось загрузить текст"
            })[root.lyrics.status] ?? ""
            color: Theme.Palette.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Tokens.scaled(15)
        }
    }
}
