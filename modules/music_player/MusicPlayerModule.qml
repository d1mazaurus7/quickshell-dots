import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import "../../theme" as Theme
import "../../shell/theme"
import "../../Bar/music_equalizer"

// Музыкальный плеер для бара: обложка, трек/исполнитель, время, кнопки управления
Rectangle {
    id: root

    // Высота модуля — задаётся из бара, все размеры ниже считаются от неё
    property int size: 48

    readonly property int padding: Math.round(size * 0.125)
    readonly property int gap: Math.round(size * 0.25)
    readonly property int coverSize: size - padding * 2
    readonly property int textWidth: Math.round(size * 4.2)
    readonly property int btnSize: Math.round(size * 0.67)
    readonly property int btnGrow: Math.round(btnSize * 0.3)
    property int animFast: 150
    property int animSlow: 260
    property int animExpand: 520
    property int animShrink: 220
    property string fontFamily: "JetBrainsMono Nerd Font"

    // Последний игравший плеер — чтобы после паузы управление не перескакивало на другой
    property MprisPlayer lastActive: null

    // Играющий плеер в приоритете, затем последний игравший, иначе первый доступный
    readonly property MprisPlayer player: {
        const list = Mpris.players.values;
        return list.find(p => p.isPlaying)
            ?? (list.includes(lastActive) ? lastActive : null)
            ?? list[0] ?? null;
    }
    readonly property bool playerPlaying: player?.isPlaying ?? false

    function rememberActive() {
        if (playerPlaying) lastActive = player;
    }
    onPlayerChanged: rememberActive()
    onPlayerPlayingChanged: rememberActive()

    function formatTime(sec) {
        const t = Math.max(0, Math.floor(sec));
        const s = t % 60;
        return Math.floor(t / 60) + ":" + (s < 10 ? "0" : "") + s;
    }

    visible: player !== null
    implicitWidth: content.implicitWidth + padding * 2
    implicitHeight: size
    radius: Tokens.radius(size * 0.3)
    color: Theme.Palette.surface_container_high

    // position в MPRIS не обновляется сам — перечитываем, пока трек играет
    Timer {
        interval: 1000
        repeat: true
        running: root.player !== null && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }

    TrackPosition {
        id: trackPos
        player: root.player
    }

    // Клик по модулю (вне кнопок) — открыть окно плеера
    signal openRequested()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openRequested()
    }

    // Звук клика: каждый запуск — отдельный процесс, проигрывается один раз и не обрывает предыдущий
    Process {
        id: clickSound
        command: ["pw-play", Quickshell.shellPath("assets/sounds/click.wav")]
    }

    Row {
        id: content
        x: root.padding
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap

        // Обложка
        ClippingRectangle {
            width: root.coverSize
            height: root.coverSize
            radius: Tokens.radius(root.coverSize * 0.28)
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
        }

        // Название и исполнитель
        Column {
            width: root.textWidth
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: root.player?.trackTitle || "Без названия"
                color: Theme.Palette.on_surface
                font.family: root.fontFamily
                font.pixelSize: Math.round(root.size * 0.29)
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.player?.trackArtist || "Неизвестный исполнитель"
                color: Theme.Palette.on_surface_variant
                font.family: root.fontFamily
                font.pixelSize: Math.round(root.size * 0.25)
                elide: Text.ElideRight
            }
        }

        // Текущее время / длительность
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
            text: root.player ? root.formatTime(trackPos.position) + " / " + root.formatTime(root.player.length) : ""
            color: Theme.Palette.on_surface_variant
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.size * 0.25)
            font.features: { "tnum": 1 }
        }

        // Кнопки: нажатая расширяется, соседние сужаются.
        // Общая ширина группы постоянна — кнопки не выходят за края модуля даже при overshoot.
        Row {
            id: buttons
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            property int pressedIndex: -1
            property bool anyPressed: false

            // Степень расширения каждой кнопки (0 — обычная, 1 — расширенная)
            property real g0: pressedIndex === 0 ? 1 : 0
            property real g1: pressedIndex === 1 ? 1 : 0
            property real g2: pressedIndex === 2 ? 1 : 0
            Behavior on g0 { NumberAnimation { duration: buttons.pressedIndex === 0 ? root.animExpand : root.animShrink; easing.type: buttons.pressedIndex === 0 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 2.2 } }
            Behavior on g1 { NumberAnimation { duration: buttons.pressedIndex === 1 ? root.animExpand : root.animShrink; easing.type: buttons.pressedIndex === 1 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 2.2 } }
            Behavior on g2 { NumberAnimation { duration: buttons.pressedIndex === 2 ? root.animExpand : root.animShrink; easing.type: buttons.pressedIndex === 2 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 2.2 } }

            function grow(i) { return i === 0 ? g0 : i === 1 ? g1 : g2; }
            // Ширина: своё расширение минус доля расширения соседей (средняя отдаёт поровну двум крайним)
            function widthOf(i) {
                let w = root.btnSize + root.btnGrow * grow(i);
                if (i === 1) w -= root.btnGrow * (g0 + g2);
                else w -= root.btnGrow * g1 / 2;
                return w;
            }

            // Минимальное время в расширенном состоянии: короткий клик проигрывает анимацию
            Timer {
                id: pressHold
                interval: root.animExpand * 0.7
                onTriggered: if (!buttons.anyPressed) buttons.pressedIndex = -1
            }

            Repeater {
                model: [
                    { icon: "skip_previous", primary: false },
                    { icon: root.player?.isPlaying ? "pause" : "play_arrow", primary: true },
                    { icon: "skip_next", primary: false }
                ]

                Rectangle {
                    id: btn
                    required property var modelData
                    required property int index

                    readonly property bool enabledAction: root.player !== null && (
                        index === 0 ? root.player.canGoPrevious
                        : index === 1 ? root.player.canTogglePlaying
                        : root.player.canGoNext)
                    readonly property color baseColor: modelData.primary ? Theme.Palette.primary : Theme.Palette.secondary_container
                    readonly property color hoverColor: modelData.primary ? Theme.Palette.primary_fixed : Theme.Palette.surface_bright

                    width: buttons.widthOf(index)
                    height: root.btnSize
                    radius: Tokens.radius(height * (0.34 - 0.1 * Math.min(1, buttons.grow(index))))
                    color: area.containsMouse && enabledAction ? hoverColor : baseColor
                    opacity: enabledAction ? 1 : 0.4

                    Behavior on color { ColorAnimation { duration: root.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData.icon
                        color: btn.modelData.primary ? Theme.Palette.on_primary : Theme.Palette.on_secondary_container
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Math.round(root.btnSize * 0.69)
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: btn.enabledAction
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            buttons.anyPressed = true;
                            buttons.pressedIndex = btn.index;
                            pressHold.restart();
                        }
                        onReleased: {
                            buttons.anyPressed = false;
                            if (!pressHold.running) buttons.pressedIndex = -1;
                        }
                        onCanceled: {
                            buttons.anyPressed = false;
                            if (!pressHold.running) buttons.pressedIndex = -1;
                        }
                        onClicked: {
                            clickSound.startDetached();
                            if (btn.index === 0) root.player.previous();
                            else if (btn.index === 1) root.player.togglePlaying();
                            else root.player.next();
                        }
                    }
                }
            }
        }
    }

    Behavior on implicitWidth { NumberAnimation { duration: root.animSlow; easing.type: Easing.OutCubic } }
}
