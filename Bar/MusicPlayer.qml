import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../theme" as Theme
import "../shell/theme"

PanelWindow {
    id: root

    property bool opened: false

    property var activePlayer: null

    readonly property var player: activePlayer

    readonly property bool playing: player
        ? player.playbackState === MprisPlaybackState.Playing
        : false

    function findBestPlayer() {
        const players = Mpris.players.values;
        if (players.length === 0) {
            activePlayer = null;
            return;
        }
        let playing = null;
        let paused = null;
        for (const p of players) {
            if (p.playbackState === MprisPlaybackState.Playing) {
                playing = p;
            } else if (p.playbackState === MprisPlaybackState.Paused && !paused) {
                paused = p;
            }
        }
        if (playing) {
            activePlayer = playing;
        } else if (paused) {
            activePlayer = paused;
        } else if (!activePlayer || !players.includes(activePlayer)) {
            activePlayer = players[0];
        }
    }

    property real currentPosition: 0

    readonly property real trackLength: player && player.length > 0
        ? player.length
        : 0

    readonly property real progress: trackLength > 0
        ? Math.max(0, Math.min(1, currentPosition / trackLength))
        : 0

    readonly property color backgroundColor: Theme.Palette.bgAlt
    readonly property color textColor: Theme.Palette.text
    readonly property color secondaryColor: Theme.Palette.subtext
    readonly property color accentColor: Theme.Palette.accent
    readonly property color buttonColor: Theme.Palette.bg2
    readonly property color buttonHoverColor: Theme.Palette.close

    color: "transparent"
    exclusiveZone: 0

    visible: opened || slideAnimation.running

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 0
    }

    height: 192

    function updatePosition() {
        currentPosition = player ? Math.max(0, player.position) : 0;
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(total / 60);
        const remaining = total % 60;

        return minutes + ":" + (remaining < 10 ? "0" : "") + remaining;
    }

    onPlayerChanged: updatePosition()

    onOpenedChanged: {
        if (opened)
            updatePosition();
    }

    Connections {
        target: Mpris.players
        function onValuesChanged() { root.findBestPlayer(); }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.findBestPlayer()
    }

    // Вызов из бинда: qs ipc call music toggle
    IpcHandler {
        target: "music"

        function toggle(): void {
            root.opened = !root.opened;
        }

        function show(): void {
            root.opened = true;
        }

        function hide(): void {
            root.opened = false;
        }
    }

    // position у MPRIS нужно периодически перечитывать.
    Timer {
        interval: 500
        running: root.visible && root.player !== null
        repeat: true
        triggeredOnStart: true

        onTriggered: root.updatePosition()
    }

    Item {
        anchors.fill: parent
        clip: true

        Rectangle {
            id: card

            width: 480
            height: 140

            x: (parent.width - width) / 2

            y: root.opened ? 52 : -height

            radius: Tokens.radius(20)
            color: root.backgroundColor
            border.width: Tokens.borderWidth
            border.color: Theme.Palette.border

            Behavior on y {
                NumberAnimation {
                    id: slideAnimation
                    duration: 260
                    easing.type: Easing.InOutCubic
                }
            }

            property string rawArtUrl: root.player && root.player.trackArtUrl
                ? (root.player.trackArtUrl.startsWith("file://") || root.player.trackArtUrl.startsWith("http")
                    ? root.player.trackArtUrl
                    : "file://" + root.player.trackArtUrl)
                : ""

            property bool artShowingA: true

            property bool hasArt: (artImgA.status === Image.Ready && artImgA.opacity > 0)
                || (artImgB.status === Image.Ready && artImgB.opacity > 0)

            onRawArtUrlChanged: {
                if (rawArtUrl === "") {
                    artImgA.source = "";
                    artImgB.source = "";
                    artDebounce.pendingUrl = "";
                    artDebounce.stop();
                    return;
                }
                if (artImgA.source === "" && artImgB.source === "") {
                    artImgA.source = rawArtUrl;
                    card.artShowingA = true;
                } else {
                    artDebounce.pendingUrl = rawArtUrl;
                    artDebounce.restart();
                }
            }

            Timer {
                id: artDebounce
                interval: 800
                property string pendingUrl: ""
                onTriggered: {
                    if (pendingUrl === "") return;
                    if (card.artShowingA) {
                        artImgB.source = pendingUrl;
                    } else {
                        artImgA.source = pendingUrl;
                    }
                    pendingUrl = "";
                }
            }

            Rectangle {
                id: cardMask
                anchors.fill: parent
                radius: parent.radius
                visible: false
                layer.enabled: true
            }

            Item {
                id: cardFill
                anchors.fill: parent
                visible: card.hasArt
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: cardMask
                }

                Image {
                    id: artImgA
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 32
                        blur: 1.0
                    }
                    opacity: card.artShowingA && status === Image.Ready ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 500; easing.type: Easing.InOutCubic }
                    }
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            card.artShowingA = true;
                            artDebounce.stop();
                        } else if (status === Image.Error) {
                            source = "";
                        }
                    }
                }

                Image {
                    id: artImgB
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 32
                        blur: 1.0
                    }
                    opacity: !card.artShowingA && status === Image.Ready ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 500; easing.type: Easing.InOutCubic }
                    }
                    onStatusChanged: {
                        if (status === Image.Ready) {
                            card.artShowingA = false;
                            artDebounce.stop();
                        } else if (status === Image.Error) {
                            source = "";
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.alpha(root.backgroundColor, 0.55)
                }
            }

            property string rawTitle: root.player
                ? (root.player.trackTitle || "Без названия")
                : "Нет активного плеера"

            property string rawArtist: root.player
                ? (root.player.trackArtist || "Неизвестный исполнитель")
                : "Запусти музыку в MPRIS-плеере"

            property string displayedTitle: rawTitle
            property string displayedArtist: rawArtist

            onRawTitleChanged: {
                if (rawTitle === displayedTitle) {
                    titleDebounce.stop();
                } else {
                    titleDebounce.restart();
                }
            }

            onRawArtistChanged: {
                if (rawArtist === displayedArtist) {
                    artistDebounce.stop();
                } else {
                    artistDebounce.restart();
                }
            }

            Timer {
                id: titleDebounce
                interval: 400
                onTriggered: card.displayedTitle = card.rawTitle
            }

            Timer {
                id: artistDebounce
                interval: 400
                onTriggered: card.displayedArtist = card.rawArtist
            }

            Text {
                id: titleText

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 18
                    leftMargin: 20
                    rightMargin: 20
                }

                text: card.displayedTitle

                color: root.textColor
                font.family: "JetBrains Mono"
                font.pixelSize: 17
                font.bold: true

                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                id: artistText

                anchors {
                    top: titleText.bottom
                    left: titleText.left
                    right: titleText.right
                    topMargin: 5
                }

                text: card.displayedArtist

                color: root.secondaryColor
                font.family: "JetBrains Mono"
                font.pixelSize: 13

                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Кнопки управления справа.
            Row {
                id: controls

                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: 20
                    bottomMargin: 18
                }

                spacing: 6

                Repeater {
                    model: 3

                    delegate: Rectangle {
                        id: controlButton

                        required property int index

                        readonly property string icon: {
                            if (index === 0) return "";
                            if (index === 2) return "";
                            return root.playing ? "" : "";
                        }

                        readonly property bool available: {
                            if (!root.player)
                                return false;

                            if (index === 0)
                                return root.player.canGoPrevious;

                            if (index === 2)
                                return root.player.canGoNext;

                            return root.player.canTogglePlaying;
                        }

                        width: 34
                        height: 34
                        radius: Tokens.radius(buttonMouse.pressed && available ? 17 : 10)

                        Behavior on radius {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.InOutCubic
                            }
                        }

                        opacity: available ? 0.80 : 0.25

                        color: buttonMouse.containsMouse && available
                            ? Theme.Palette.surface_container_highest
                            : Theme.Palette.surface_container_high

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: controlButton.icon
                            color: root.textColor
                            font.family: "JetBrains Mono"

                            font.pixelSize: controlButton.index === 1
                                ? 14
                                : 22
                        }

                        MouseArea {
                            id: buttonMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: controlButton.available
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (!root.player)
                                    return;

                                if (controlButton.index === 0)
                                    root.player.previous();
                                else if (controlButton.index === 1)
                                    root.player.togglePlaying();
                                else
                                    root.player.next();
                            }
                        }
                        }
                    }


                }

            // Прогресс слева от кнопок.
            Item {
                id: progressArea

                anchors {
                    left: parent.left
                    right: controls.left
                    bottom: controls.bottom
                    leftMargin: 20
                    rightMargin: 18
                }

                height: 34

                Rectangle {
                    id: progressTrack

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 3
                    }

                    height: 6
                    radius: Tokens.radius(3)
                    color: Theme.Palette.outline

                    Canvas {
                        id: waveCanvas

                        anchors {
                            left: parent.left
                            bottom: parent.bottom
                        }

                        property real targetWidth: Math.max(0, parent.width * root.progress)
                        width: targetWidth
                        height: parent.height + waveAmplitude * 2

                        Behavior on width {
                            SmoothedAnimation { duration: 400 }
                        }

                        property real wavePhase: 0
                        readonly property real waveAmplitude: 4.0
                        readonly property real waveFrequency: 0.10

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();

                            const w = width;
                            const h = height;
                            const amp = waveAmplitude;
                            const trackH = parent.height;
                            const baseY = trackH;

                            if (w < 1) return;

                            const grad = ctx.createLinearGradient(0, 0, w, 0);
                            grad.addColorStop(0, root.accentColor.toString());
                            grad.addColorStop(1, Qt.alpha(root.accentColor, 0.3).toString());

                            ctx.beginPath();
                            ctx.moveTo(0, h);
                            for (let x = 0; x <= w; x += 1) {
                                const y = baseY + Math.sin(x * waveFrequency + wavePhase) * amp;
                                ctx.lineTo(x, y);
                            }
                            ctx.lineTo(w, h);
                            ctx.closePath();
                            ctx.fillStyle = grad;
                            ctx.fill();

                            const whiteAmp = amp * 0.6;
                            const whiteFreq = waveFrequency * 1.3;
                            const whitePhase = wavePhase * 0.8 + 1.5;

                            const whiteGrad = ctx.createLinearGradient(0, 0, w, 0);
                            whiteGrad.addColorStop(0, Qt.rgba(1, 1, 1, 0.35).toString());
                            whiteGrad.addColorStop(1, Qt.rgba(1, 1, 1, 0.08).toString());

                            ctx.beginPath();
                            ctx.moveTo(0, h);
                            for (let x = 0; x <= w; x += 1) {
                                const y = baseY + Math.sin(x * whiteFreq + whitePhase) * whiteAmp;
                                ctx.lineTo(x, y);
                            }
                            ctx.lineTo(w, h);
                            ctx.closePath();
                            ctx.fillStyle = whiteGrad;
                            ctx.fill();
                        }

                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        Timer {
                            id: waveTimer
                            interval: 33
                            running: root.visible && root.playing
                            repeat: true
                            onTriggered: {
                                waveCanvas.wavePhase += 0.12;
                                waveCanvas.requestPaint();
                            }
                        }
                    }
                }

                MouseArea {
                    id: seekArea

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }

                    height: 14

                    enabled: root.player
                        ? root.player.canSeek && root.trackLength > 0
                        : false

                    cursorShape: enabled
                        ? Qt.PointingHandCursor
                        : Qt.ArrowCursor

                    property bool dragging: false

                    onPressed: mouse => {
                        dragging = true;
                        const fraction = Math.max(0, Math.min(1, mouse.x / width));
                        root.player.position = fraction * root.trackLength;
                        root.updatePosition();
                    }

                    onPositionChanged: mouse => {
                        if (!dragging) return;
                        const fraction = Math.max(0, Math.min(1, mouse.x / width));
                        root.player.position = fraction * root.trackLength;
                        root.updatePosition();
                    }

                    onReleased: {
                        dragging = false;
                    }
                }

                Canvas {
                    id: progressDot

                    readonly property real dotR: 5
                    readonly property real dotX: progressTrack.width * root.progress

                    x: dotX - dotR
                    y: progressTrack.y + (progressTrack.height / 2) - dotR
                    width: dotR * 2
                    height: dotR * 2

                    Behavior on x {
                        SmoothedAnimation { duration: 400 }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const r = dotR;
                        const cx = r;
                        const cy = r;

                        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                        grad.addColorStop(0, "#ffffff");
                        grad.addColorStop(1, root.accentColor.toString());
                        ctx.fillStyle = grad;

                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, Math.PI * 2);
                        ctx.closePath();
                        ctx.fill();
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }

                Text {
                    anchors {
                        left: parent.left
                        bottom: parent.bottom
                    }

                    text: root.formatTime(root.currentPosition)
                    color: root.secondaryColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                }

                Text {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }

                    text: root.formatTime(root.trackLength)
                    color: root.secondaryColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                }
            }
        }
    }
}
