pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"
import "../../components/animations" as Anim

// Окно плеера с эквалайзером, выплывающее из бара под модулем музыки
Anim.BarDropdown {
    id: root

    property MprisPlayer player: null
    required property EqualizerState equalizer

    readonly property int inner: Tokens.scaled(20)
    // Место вокруг обложки под визуализатор
    readonly property int ringRoom: Tokens.scaled(22)
    readonly property int coverSize: Tokens.scaled(132)
    readonly property var cfg: Config.options.musicPlayer
    // 0 — плеер, 1 — текст песни
    property int page: 0
    // Плавно идёт от 0 к 1 при смене страницы
    property real pageShift: page
    readonly property bool lyricsOn: cfg.lyrics
    onLyricsOnChanged: if (!lyricsOn) page = 0
    // Повтор после сетевой ошибки — при открытии окна
    onVisibleChanged: if (visible) lyricsState.refresh()
    Behavior on pageShift { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    function formatTime(sec) {
        const t = Math.max(0, Math.floor(sec));
        const s = t % 60;
        return Math.floor(t / 60) + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property bool showGif: cfg.danceGifEnabled && cfg.danceGif !== ""
    readonly property int gifWidth: Tokens.scaled(150)

    contentWidth: Tokens.scaled(680) + (showGif ? gifWidth + Tokens.scaled(14) : 0)
    padding: Tokens.scaled(10)

    // position в MPRIS не обновляется сам — перечитываем, пока окно открыто и трек играет
    Timer {
        // На странице текста чаще — чтобы строки переключались вовремя
        interval: root.page === 1 ? 150 : 500
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }

    TrackPosition {
        id: trackPos
        player: root.player
    }

    LyricsState {
        id: lyricsState
        player: root.player
        active: root.lyricsOn
        position: trackPos.position
    }

    ClippingRectangle {
        id: card
        width: parent.width
        height: pages.y + pages.height + root.inner
        radius: Tokens.radius(18)
        color: Theme.Palette.surface_container

        // Фон: обложка, размытая при cfg.backgroundBlur
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
            visible: root.cfg.coverBackground && art.status === Image.Ready
            autoPaddingEnabled: false
            blurEnabled: root.cfg.backgroundBlur
            blur: 1.0
            blurMax: 64
            saturation: 0.2
        }
        // Затемнение для читаемости
        Rectangle {
            anchors.fill: parent
            color: Theme.Palette.surface
            opacity: root.cfg.coverBackground && art.status === Image.Ready ? 0.6 : 0
        }

        // Спектр вокруг обложки — под обложкой и текстом
        CavaSource {
            id: cava
            active: root.cfg.cava && root.visible && root.page === 0 && (root.player?.isPlaying ?? false)
        }
        CavaRing {
            visible: root.cfg.cava && opacity > 0
            opacity: layout.opacity
            x: pages.x + layout.x + root.ringRoom + root.coverSize / 2 - width / 2
            y: pages.y + root.ringRoom + root.coverSize / 2 - height / 2
            values: cava.values
            active: cava.active
            coverSize: root.coverSize
            gap: Tokens.scaled(3)
            amplitude: root.coverSize * 0.2
        }

        // Вкладки «Плеер / Текст»
        Rectangle {
            id: tabs
            readonly property int pad: Tokens.scaled(3)

            visible: root.lyricsOn

            x: (parent.width - width) / 2
            y: root.inner
            width: Tokens.scaled(280)
            height: Tokens.scaled(36)
            radius: height / 2
            color: Theme.Palette.surface_container_high

            Rectangle {
                x: tabs.pad + root.pageShift * tabs.width / 2
                y: tabs.pad
                width: tabs.width / 2 - tabs.pad * 2
                height: tabs.height - tabs.pad * 2
                radius: height / 2
                color: Theme.Palette.primary
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { icon: "music_note", label: "Плеер" },
                        { icon: "lyrics", label: "Текст" }
                    ]

                    Item {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool active: root.page === index

                        width: tabs.width / 2
                        height: tabs.height

                        // Слой состояния hover/pressed
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: tabs.pad
                            radius: height / 2
                            color: Theme.Palette.on_surface
                            opacity: tab.active ? 0 : tabArea.pressed ? 0.12 : tabArea.containsMouse ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Tokens.scaled(6)
                            scale: tabArea.pressed ? 0.96 : 1
                            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.icon
                                color: tab.active ? Theme.Palette.on_primary : Theme.Palette.on_surface_variant
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: Tokens.scaled(18)
                                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.label
                                color: tab.active ? Theme.Palette.on_primary : Theme.Palette.on_surface_variant
                                font.family: Tokens.typography.family
                                font.pixelSize: Tokens.scaled(14)
                                font.weight: Font.Medium
                                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                            }
                        }

                        MouseArea {
                            id: tabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = tab.index
                        }
                    }
                }
            }
        }

        // Страницы: высота всегда по странице плеера, чтобы окно не меняло размер
        Item {
            id: pages
            x: root.inner
            y: root.lyricsOn ? tabs.y + tabs.height + Tokens.scaled(14) : root.inner
            width: parent.width - root.inner * 2
            height: layout.implicitHeight

            LyricsPage {
                width: parent.width
                height: parent.height
                x: (1 - root.pageShift) * Tokens.scaled(40)
                opacity: root.pageShift
                visible: opacity > 0
                lyrics: lyricsState
                player: root.player
                active: root.visible
            }

            Column {
                id: layout
                x: -root.pageShift * Tokens.scaled(40)
                width: parent.width
                opacity: 1 - root.pageShift
                visible: opacity > 0
                spacing: Tokens.scaled(18)

                // Обложка, трек, кнопки, таймлайн
                Row {
                    width: parent.width
                    topPadding: root.ringRoom
                    leftPadding: root.ringRoom
                    spacing: Tokens.scaled(20) + root.ringRoom

                    ClippingRectangle {
                        width: root.coverSize
                        height: root.coverSize
                        radius: Tokens.radius(20)
                        color: Theme.Palette.surface_variant

                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: root.coverSize * 2
                            sourceSize.height: root.coverSize * 2
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !root.player?.trackArtUrl
                            text: "music_note"
                            color: Theme.Palette.on_surface_variant
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Math.round(root.coverSize * 0.4)
                        }
                    }

                    Column {
                        width: parent.width - parent.leftPadding - root.coverSize - parent.spacing
                        height: root.coverSize

                        Item {
                            width: parent.width
                            height: titles.height

                            Column {
                                id: titles
                                width: parent.width - controls.width - Tokens.scaled(12)

                                MarqueeText {
                                    width: parent.width
                                    text: root.player?.trackTitle || "Без названия"
                                    color: Theme.Palette.on_surface
                                    font.family: Tokens.typography.family
                                    font.pixelSize: Tokens.scaled(26)
                                    font.weight: Font.Medium
                                }
                                MarqueeText {
                                    width: parent.width
                                    visible: root.cfg.showArtist
                                    text: root.player?.trackArtist || "Неизвестный исполнитель"
                                    color: Theme.Palette.on_surface_variant
                                    font.family: Tokens.typography.family
                                    font.pixelSize: Tokens.scaled(16)
                                }
                            }

                            ControlButtons {
                                id: controls
                                anchors.right: parent.right
                                anchors.top: parent.top
                                player: root.player
                            }
                        }

                        Item {
                            width: 1
                            height: parent.height - titles.height - time.height - wave.height
                        }

                        Text {
                            id: time
                            anchors.right: parent.right
                            visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
                            text: root.player ? root.formatTime(trackPos.position) + " / " + root.formatTime(root.player.length) : ""
                            color: Theme.Palette.on_surface_variant
                            font.family: Tokens.typography.family
                            font.pixelSize: Tokens.scaled(13)
                            font.features: { "tnum": 1 }
                        }

                        WaveSlider {
                            id: wave
                            width: parent.width
                            playing: root.player?.isPlaying ?? false
                            wavy: root.cfg.wavyTimeline
                            style: root.cfg.timelineStyle
                            seekable: root.player !== null && root.player.canSeek && root.player.length > 0
                            value: root.player && root.player.length > 0 ? trackPos.position / root.player.length : 0
                            onSeekRequested: v => root.player.position = v * root.player.length
                        }
                    }
                }

                // Полосы эквалайзера и gif справа (gif — и без эквалайзера)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.cfg.equalizer || root.showGif
                    spacing: Tokens.scaled(14)

                    Item {
                        visible: root.cfg.equalizer
                        width: eqBands.implicitWidth
                        height: eqBands.implicitHeight

                        Row {
                            id: eqBands
                            spacing: Tokens.scaled(14)

                            Repeater {
                                id: eqRepeater
                                model: root.equalizer.frequencies

                                EqSlider {
                                    required property int modelData
                                    required property int index
                                    value: root.equalizer.gains[index]
                                    from: root.equalizer.minGain
                                    to: root.equalizer.maxGain
                                    label: modelData >= 1000 ? (modelData / 1000) + "k" : String(modelData)
                                    onMoved: v => root.equalizer.setGain(index, v)
                                }
                            }
                        }

                        LightningArc {
                            id: lightning
                            anchors.fill: parent
                            anchors.margins: -Tokens.scaled(24)
                            sliders: eqRepeater
                            step: Tokens.animationFast / 2.5
                        }
                    }

                    AnimatedImage {
                        visible: root.showGif
                        width: root.gifWidth
                        height: eqBands.height
                        source: root.showGif ? Qt.resolvedUrl("../../assets/gifs/dance/" + root.cfg.danceGif) : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        playing: root.visible
                    }
                }

                // Пресеты
                Column {
                    width: parent.width
                    visible: root.cfg.equalizer
                    spacing: Tokens.scaled(10)

                    Text {
                        text: "Предустановки"
                        color: Theme.Palette.on_surface_variant
                        font.family: Tokens.typography.family
                        font.pixelSize: Tokens.scaled(14)
                    }

                    Grid {
                        id: presetGrid
                        width: parent.width
                        columns: 5
                        spacing: Tokens.scaled(10)

                        Repeater {
                            model: root.equalizer.presets

                            Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool active: root.equalizer.activePreset === modelData.name

                                width: (presetGrid.width - presetGrid.spacing * (presetGrid.columns - 1)) / presetGrid.columns
                                height: Tokens.scaled(40)
                                radius: Tokens.radius(active ? 20 : 12)
                                color: active ? Theme.Palette.primary
                                    : chipArea.pressed ? Theme.Palette.surface_bright
                                    : chipArea.containsMouse ? Theme.Palette.surface_container_highest
                                    : Theme.Palette.surface_container_high
                                scale: chipArea.pressed ? 0.96 : 1

                                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                                Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                                Text {
                                    anchors.centerIn: parent
                                    text: chip.modelData.name
                                    color: chip.active ? Theme.Palette.on_primary : Theme.Palette.on_surface
                                    font.family: Tokens.typography.family
                                    font.pixelSize: Tokens.scaled(15)
                                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                                }

                                MouseArea {
                                    id: chipArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // Разряд идёт по полосам слева направо, каждая поднимается при его касании
                                        for (let i = 0; i < eqRepeater.count; i++)
                                            eqRepeater.itemAt(i)?.charge(Math.round(i * lightning.step));
                                        lightning.strike();
                                        root.equalizer.loadPreset(chip.modelData);
                                        Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/swoosh.wav")]);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
