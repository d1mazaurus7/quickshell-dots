pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../shell/theme"
import "../controls"
import "../../Bar/music_equalizer" as Music

// Виджет плеера: обложка, трек и исполнитель, время, таймлайн, gif.
// Клик по обложке — пауза/воспроизведение. Текст песни и эквалайзер — отдельные страницы
Item {
    id: root

    property var settings: ({})
    property var services: ({})
    property bool editing: false

    readonly property var colors: Tokens.colors

    // Последний игравший плеер — чтобы после паузы виджет не перескакивал на другой
    property MprisPlayer lastActive: null
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        return list.find(p => p.isPlaying)
            ?? (list.includes(lastActive) ? lastActive : null)
            ?? list[0] ?? null;
    }
    readonly property bool playing: player?.isPlaying ?? false
    onPlayerChanged: if (playing) lastActive = player
    onPlayingChanged: if (playing) lastActive = player

    readonly property int pad: Tokens.scaled(16)
    // Размер шрифтов растёт вместе с высотой виджета
    readonly property real fontScale: Math.max(0.8, height / Tokens.scaled(150))
    readonly property bool hasLength: player !== null && player.lengthSupported && player.length > 0
    readonly property bool showGif: settings.danceGifEnabled === true && settings.danceGif !== ""

    // Страницы: плеер всегда, текст и эквалайзер — по настройкам
    readonly property var pages: [{ id: "player", icon: "music_note" }]
        .concat(settings.lyrics === true ? [{ id: "lyrics", icon: "lyrics" }] : [])
        .concat(settings.equalizer === true ? [{ id: "equalizer", icon: "equalizer" }] : [])
    property string selectedPage: "player"
    readonly property string page: pages.some(p => p.id === selectedPage) ? selectedPage : "player"

    function formatTime(sec) {
        const t = Math.max(0, Math.floor(sec));
        const s = t % 60;
        return Math.floor(t / 60) + ":" + (s < 10 ? "0" : "") + s;
    }

    function fontSize(delta: int): int {
        return Math.round(Tokens.scaled(Tokens.typography.size + delta) * fontScale);
    }

    // position в MPRIS не обновляется сам — перечитываем, пока трек играет
    Timer {
        // На странице текста чаще — чтобы строки переключались вовремя
        interval: root.page === "lyrics" ? 150 : 500
        repeat: true
        running: root.visible && root.playing && (root.player?.positionSupported ?? false)
        onTriggered: root.player.positionChanged()
    }

    Music.TrackPosition {
        id: trackPos
        player: root.player
    }

    Music.CavaSource {
        id: cava
        active: root.settings.cava === true && root.visible && root.playing && root.page === "player"
    }

    Music.LyricsState {
        id: lyricsState
        player: root.player
        active: root.settings.lyrics === true
        position: trackPos.position
    }

    WidgetCard {
        anchors.fill: parent

        // Фон: обложка, размытая по настройке
        Image {
            id: art
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: art
            visible: root.settings.coverBackground === true && art.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: root.settings.backgroundBlur === true
            blur: 1.0
            blurMax: 64
            saturation: 0.2
        }
        Rectangle {
            anchors.fill: parent
            color: root.colors.surface
            opacity: root.settings.coverBackground === true && art.status === Image.Ready ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
        }

        // Спектр cava по нижнему краю: волна — во всю ширину карточки, полосы — в отступах
        CavaSpectrum {
            readonly property int inset: root.settings.cavaStyle === "bars" ? root.pad : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: inset
            height: parent.height * 0.5
            values: cava.values
            active: cava.active
            style: root.settings.cavaStyle
        }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: root.pad

            // Переключатель страниц у правого края
            Column {
                id: tabs
                readonly property int size: Math.min(Tokens.scaled(28), Math.floor((content.height - spacing * 2) / 3))
                visible: root.pages.length > 1
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacingSmallV

                Repeater {
                    model: root.pages

                    IconButton {
                        required property var modelData
                        size: tabs.size
                        icon: modelData.icon
                        checked: root.page === modelData.id
                        onClicked: root.selectedPage = modelData.id
                    }
                }
            }

            Item {
                id: pageArea
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: tabs.visible ? tabs.left : parent.right
                anchors.rightMargin: tabs.visible ? root.pad : 0

                WidgetPage {
                    active: root.page === "lyrics"
                    WidgetLyrics {
                        anchors.fill: parent
                        lyrics: lyricsState
                        player: root.player
                        settings: root.settings
                    }
                }

                WidgetPage {
                    active: root.page === "equalizer"
                    WidgetEqualizer {
                        anchors.fill: parent
                        equalizer: root.services.equalizer ?? null
                    }
                }

                WidgetPage {
                    id: playerPage
                    active: root.page === "player"

                    readonly property int gap: Tokens.scaled(4)
                    readonly property int coverSize: Math.max(0, height - timeline.height - gap)

                    ClippingRectangle {
                        id: cover
                        width: playerPage.coverSize
                        height: playerPage.coverSize
                        radius: Tokens.radius(Math.round(playerPage.coverSize * 0.18))
                        color: root.colors.surface_variant
                        scale: coverArea.pressed ? 0.95 : 1
                        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: playerPage.coverSize * 2
                            sourceSize.height: playerPage.coverSize * 2
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !root.player?.trackArtUrl
                            text: "music_note"
                            color: root.colors.on_surface_variant
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Math.round(playerPage.coverSize * 0.4)
                        }

                        // Пауза/воспроизведение при наведении
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.alpha(root.colors.surface, 0.55)
                            opacity: coverArea.containsMouse && root.player !== null ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

                            Text {
                                anchors.centerIn: parent
                                text: root.playing ? "pause" : "play_arrow"
                                color: root.colors.on_surface
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: Math.round(playerPage.coverSize * 0.45)
                            }
                        }

                        MouseArea {
                            id: coverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.player?.canTogglePlaying ?? false
                            cursorShape: Qt.PointingHandCursor
                            onPressed: WidgetSound.click()
                            onClicked: root.player.togglePlaying()
                        }
                    }

                    Item {
                        id: info
                        anchors.left: cover.right
                        anchors.leftMargin: root.pad
                        anchors.right: gif.visible ? gif.left : parent.right
                        anchors.rightMargin: gif.visible ? root.pad : 0
                        height: playerPage.coverSize

                        Column {
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -time.height / 2

                            Music.MarqueeText {
                                width: parent.width
                                text: root.player ? (root.player.trackTitle || "Без названия") : "Ничего не играет"
                                color: root.colors.on_surface
                                font.family: Tokens.typography.family
                                font.pixelSize: root.fontSize(6)
                                font.weight: Font.Medium
                            }
                            Music.MarqueeText {
                                width: parent.width
                                visible: root.settings.showArtist === true && root.player !== null
                                text: root.player?.trackArtist || "Неизвестный исполнитель"
                                color: root.colors.on_surface_variant
                                font.family: Tokens.typography.family
                                font.pixelSize: root.fontSize(1)
                            }
                        }

                        Text {
                            id: time
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            visible: root.settings.showTime === true && root.hasLength
                            text: root.hasLength ? root.formatTime(trackPos.position) + " / " + root.formatTime(root.player.length) : ""
                            color: root.colors.on_surface_variant
                            font.family: Tokens.typography.family
                            font.pixelSize: root.fontSize(-1)
                            font.features: { "tnum": 1 }
                        }
                    }

                    AnimatedImage {
                        id: gif
                        anchors.right: parent.right
                        visible: root.showGif
                        width: playerPage.coverSize
                        height: playerPage.coverSize
                        source: root.showGif ? Qt.resolvedUrl("../../assets/gifs/dance/" + root.settings.danceGif) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        playing: root.visible && playerPage.visible
                    }

                    // Линия таймлайна совпадает с краями содержимого: ручка заходит в отступ
                    Music.WaveSlider {
                        id: timeline
                        x: -knobSize / 2
                        anchors.bottom: parent.bottom
                        width: parent.width + knobSize
                        height: Tokens.scaled(24)
                        playing: root.playing
                        wavy: root.settings.wavyTimeline === true
                        style: root.settings.timelineStyle
                        seekable: root.hasLength && root.player.canSeek
                        value: root.hasLength ? trackPos.position / root.player.length : 0
                        onSeekRequested: v => root.player.position = v * root.player.length
                    }
                }
            }
        }
    }
}
