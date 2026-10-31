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

    function formatTime(sec) {
        const t = Math.max(0, Math.floor(sec));
        const s = t % 60;
        return Math.floor(t / 60) + ":" + (s < 10 ? "0" : "") + s;
    }

    contentWidth: Tokens.scaled(680)
    padding: Tokens.scaled(10)

    // position в MPRIS не обновляется сам — перечитываем, пока окно открыто и трек играет
    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }

    TrackPosition {
        id: trackPos
        player: root.player
    }

    ClippingRectangle {
        id: card
        width: parent.width
        height: layout.implicitHeight + root.inner * 2
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
            active: root.cfg.cava && root.visible && (root.player?.isPlaying ?? false)
        }
        CavaRing {
            visible: root.cfg.cava
            x: root.inner + root.ringRoom + root.coverSize / 2 - width / 2
            y: root.inner + root.ringRoom + root.coverSize / 2 - height / 2
            values: cava.values
            active: cava.active
            coverSize: root.coverSize
            gap: Tokens.scaled(3)
            amplitude: root.coverSize * 0.2
        }

        Column {
            id: layout
            x: root.inner
            y: root.inner
            width: parent.width - root.inner * 2
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

            // Полосы эквалайзера
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.cfg.equalizer
                spacing: Tokens.scaled(14)

                Repeater {
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
                    columns: 4
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
                                onClicked: root.equalizer.loadPreset(chip.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
