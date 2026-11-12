import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../../../theme" as Theme
import "../../../shell/theme"
import "../controls"
import "../controls/Icons.js" as Icons

// Музыкальный плеер MPRIS: обложка, название, исполнитель, плеер-источник,
// волновой прогресс с перемоткой, кнопки и повтор.
Rectangle {
    id: w

    required property var ctx
    readonly property real s: ctx.s

    // Плеер, выбранный вручную (dbusName); иначе — играющий или первый
    property string chosen: ""
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.dbusName === chosen)
        ?? players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: !!player && player.isPlaying
    readonly property real length: player && player.lengthSupported ? player.length : 0
    property real position: 0

    // Показанный трек: меняется посередине анимации смены
    property string shownTitle
    property string shownArtist
    property string shownArt
    // Анимация смены: направление (1 — вперёд, -1 — назад), ось (плеер — по вертикали)
    property int dir: 1
    property bool vertical: false
    property real shift: 0
    property real fade: 1
    property bool ready: false
    property bool menuOpen: false

    // Пропорции карточки
    readonly property real pad: 14 * s
    readonly property real gap: 8 * s
    readonly property real buttonH: 40 * s
    readonly property real timeH: 16 * s
    readonly property real progressH: 22 * s
    readonly property real artSize: Math.max(40 * s, Math.min(
        height - 2 * pad - buttonH - timeH - progressH - 2 * gap, width * 0.3))

    radius: Math.min(28 * s, height * 0.14)
    color: Theme.Palette.surface_container_high

    function apply(): void {
        shownTitle = player ? (player.trackTitle || "Без названия") : "Ничего не играет";
        shownArtist = player ? player.trackArtist : "";
        shownArt = player && player.trackArtUrl ? player.trackArtUrl : "";
    }

    function animateChange(vert: bool): void {
        vertical = vert;
        swap.restart();
    }

    function sync(): void {
        position = player && player.positionSupported ? player.position : 0;
    }

    function fmt(sec: real): string {
        const t = Math.max(0, Math.floor(sec));
        const m = Math.floor(t / 60);
        const ss = t % 60;
        return m + ":" + (ss < 10 ? "0" : "") + ss;
    }

    function choose(p: var): void {
        menuOpen = false;
        ctx.play("click");
        chosen = p.dbusName;
    }

    function cycleLoop(): void {
        if (!player || !player.loopSupported)
            return;
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
            : player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track
            : MprisLoopState.None;
        ctx.play("click");
    }

    onPlayerChanged: {
        sync();
        if (ready) {
            dir = 1;
            animateChange(true);
        } else {
            apply();
        }
    }
    Component.onCompleted: {
        apply();
        ready = true;
    }

    // Уход старого трека → подстановка → приход нового с лёгким перелётом
    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: w; property: "fade"; to: 0; duration: Tokens.animationFast; easing.type: Easing.InCubic }
            NumberAnimation { target: w; property: "shift"; to: -w.dir * 18 * w.s; duration: Tokens.animationFast; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                w.apply();
                w.shift = w.dir * 18 * w.s;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: w; property: "fade"; to: 1; duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
            NumberAnimation { target: w; property: "shift"; to: 0; duration: Tokens.animationSlow; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }
        ScriptAction {
            script: {
                w.dir = 1;
                // Обложка могла прийти позже названия
                w.shownArt = w.player && w.player.trackArtUrl ? w.player.trackArtUrl : "";
            }
        }
    }

    // Название и исполнитель приходят отдельными сигналами — собираем в одну смену
    Timer {
        id: trackDebounce
        interval: 80
        onTriggered: w.animateChange(false)
    }

    // Позиция MPRIS не реактивна: опрос раз в секунду, только пока играет и центр открыт
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: w.playing && w.ctx.open
        onTriggered: w.sync()
    }

    Connections {
        target: w.ctx
        function onOpenChanged() {
            w.sync();
            w.menuOpen = false;
        }
        function onEditingChanged() { w.menuOpen = false; }
    }

    Connections {
        target: w.player
        function onPositionChanged() { w.sync(); }
        function onTrackTitleChanged() {
            w.sync();
            trackDebounce.restart();
        }
        function onTrackArtistChanged() { trackDebounce.restart(); }
        function onTrackArtUrlChanged() {
            if (!swap.running && !trackDebounce.running)
                w.shownArt = w.player.trackArtUrl || "";
        }
    }

    // Обложка
    ClippingRectangle {
        id: art
        x: w.pad
        y: w.pad
        width: w.artSize
        height: w.artSize
        radius: width * 0.22
        color: Theme.Palette.surface_container_highest
        opacity: 0.3 + 0.7 * w.fade
        scale: 0.9 + 0.1 * w.fade
        transform: Translate {
            x: w.vertical ? 0 : w.shift * 0.5
            y: w.vertical ? w.shift * 0.5 : 0
        }

        Icon {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: Icons.music
            size: art.width * 0.38
            color: Theme.Palette.on_surface_variant
        }

        Image {
            id: cover
            anchors.fill: parent
            source: w.shownArt
            sourceSize.width: Math.round(art.width * 2)
            sourceSize.height: Math.round(art.height * 2)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity { Smooth {} }
        }
    }

    // Источник: иконка ноты, приложение, имя; справа — смена плеера
    Row {
        id: source
        anchors.top: parent.top
        anchors.topMargin: w.pad
        anchors.right: parent.right
        anchors.rightMargin: w.pad
        height: 26 * w.s
        spacing: 2 * w.s
        visible: !!w.player

        Rectangle {
            width: sourceRow.implicitWidth + 16 * w.s
            height: parent.height
            topLeftRadius: height / 2
            bottomLeftRadius: height / 2
            topRightRadius: 4 * w.s
            bottomRightRadius: 4 * w.s
            color: Theme.Palette.secondary_container

            Row {
                id: sourceRow
                anchors.centerIn: parent
                spacing: 5 * w.s

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.music
                    size: 13 * w.s
                    color: Theme.Palette.on_secondary_container
                }
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property string path: w.player && w.player.desktopEntry
                        ? Quickshell.iconPath(w.player.desktopEntry, true) : ""
                    visible: path !== ""
                    source: path
                    implicitSize: Math.round(15 * w.s)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: w.player ? w.player.identity : ""
                    color: Theme.Palette.on_secondary_container
                    font.family: Tokens.typography.family
                    font.pixelSize: Math.round(11 * w.s)
                }
            }
        }

        Rectangle {
            width: 22 * w.s
            height: parent.height
            topLeftRadius: 4 * w.s
            bottomLeftRadius: 4 * w.s
            topRightRadius: height / 2
            bottomRightRadius: height / 2
            color: w.menuOpen ? Theme.Palette.primary : Theme.Palette.secondary_container
            Behavior on color { SmoothColor {} }

            StateLayer {
                topLeftRadius: parent.topLeftRadius
                bottomLeftRadius: parent.bottomLeftRadius
                topRightRadius: parent.topRightRadius
                bottomRightRadius: parent.bottomRightRadius
                color: w.menuOpen ? Theme.Palette.on_primary : Theme.Palette.on_secondary_container
                hovered: switchArea.containsMouse
                pressed: switchArea.pressed
            }

            Icon {
                anchors.centerIn: parent
                text: Icons.chevronDown
                size: 14 * w.s
                color: w.menuOpen ? Theme.Palette.on_primary : Theme.Palette.on_secondary_container
                rotation: w.menuOpen ? 180 : 0
                Behavior on rotation { Emphasized {} }
            }

            MouseArea {
                id: switchArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    w.ctx.play("click");
                    w.menuOpen = !w.menuOpen;
                }
            }
        }
    }

    // Название и исполнитель
    Column {
        anchors.left: art.right
        anchors.leftMargin: 14 * w.s
        anchors.right: parent.right
        anchors.rightMargin: w.pad
        anchors.top: source.bottom
        anchors.topMargin: Math.max(4 * w.s, (art.height - source.height - height) / 2 - 4 * w.s)
        spacing: 2 * w.s
        opacity: w.fade
        transform: Translate {
            x: w.vertical ? 0 : w.shift
            y: w.vertical ? w.shift : 0
        }

        Marquee {
            s: w.s
            width: parent.width
            text: w.shownTitle
            color: Theme.Palette.on_surface
            family: Tokens.typography.family
            weight: Font.Medium
            pixelSize: Math.round(20 * w.s)
        }
        Marquee {
            s: w.s
            width: parent.width
            visible: text !== ""
            text: w.shownArtist
            color: Theme.Palette.on_surface_variant
            family: Tokens.typography.family
            pixelSize: Math.round(13 * w.s)
        }
    }

    // Время
    Item {
        id: times
        x: w.pad
        y: art.y + art.height + w.gap
        width: w.width - 2 * w.pad
        height: w.timeH

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 4 * w.s
            anchors.verticalCenter: parent.verticalCenter
            text: w.fmt(progress.pressed ? progress.dragValue * w.length : w.position)
            color: Theme.Palette.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Math.round(11 * w.s)
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 4 * w.s
            anchors.verticalCenter: parent.verticalCenter
            text: w.length > 0 ? w.fmt(w.length) : "--:--"
            color: Theme.Palette.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Math.round(11 * w.s)
            font.features: { "tnum": 1 }
        }
    }

    WavyProgress {
        id: progress
        s: w.s
        x: w.pad
        y: times.y + times.height
        width: w.width - 2 * w.pad
        height: w.progressH
        value: w.length > 0 ? w.position / w.length : 0
        playing: w.playing && w.ctx.open
        interactive: !!w.player && w.player.canSeek && w.length > 0
        onSeek: v => {
            w.player.position = v * w.length;
            w.position = v * w.length;
        }
    }

    // Кнопки: группа «назад / пуск / вперёд» и повтор
    Row {
        id: controls
        x: w.pad
        y: w.height - w.pad - w.buttonH
        height: w.buttonH
        spacing: 3 * w.s

        // Нажатая кнопка группы чуть шире, соседи уже (MD3 expressive)
        property int down: prev.pressed ? 0 : playBtn.pressed ? 1 : next.pressed ? 2 : -1
        function grow(i: int): real {
            return down < 0 ? 1 : down === i ? 1.12 : 0.94;
        }

        IconButton {
            id: prev
            s: w.s
            width: w.buttonH * 1.2 * controls.grow(0)
            height: w.buttonH
            icon: Icons.previous
            slideOnClick: -1
            enabled: !!w.player && w.player.canGoPrevious
            color: Theme.Palette.secondary_container
            contentColor: Theme.Palette.on_secondary_container
            onClicked: {
                w.dir = -1;
                w.player.previous();
                w.ctx.play("click");
            }
            Behavior on width { Emphasized {} }
        }

        // Пауза — скруглённый квадрат, остановлено — таблетка
        IconButton {
            id: playBtn
            s: w.s
            width: w.buttonH * 1.9 * controls.grow(1)
            height: w.buttonH
            round: true
            checked: w.playing
            icon: w.playing ? Icons.pause : Icons.play
            enabled: !!w.player && w.player.canTogglePlaying
            color: Theme.Palette.primary
            contentColor: Theme.Palette.on_primary
            onClicked: { w.player.togglePlaying(); w.ctx.play("click"); }
            Behavior on width { Emphasized {} }
        }

        IconButton {
            id: next
            s: w.s
            width: w.buttonH * 1.2 * controls.grow(2)
            height: w.buttonH
            icon: Icons.next
            slideOnClick: 1
            enabled: !!w.player && w.player.canGoNext
            color: Theme.Palette.secondary_container
            contentColor: Theme.Palette.on_secondary_container
            onClicked: { w.player.next(); w.ctx.play("click"); }
            Behavior on width { Emphasized {} }
        }
    }

    IconButton {
        s: w.s
        anchors.left: controls.left
        anchors.leftMargin: w.buttonH * 4.3 + 6 * w.s + 14 * w.s
        y: controls.y
        width: w.buttonH
        height: w.buttonH
        readonly property int loop: w.player && w.player.loopSupported ? w.player.loopState : MprisLoopState.None
        checked: loop !== MprisLoopState.None
        icon: loop === MprisLoopState.Track ? Icons.repeatOnce : Icons.repeat
        slashed: loop === MprisLoopState.None
        enabled: !!w.player && w.player.loopSupported
        color: checked ? Theme.Palette.tertiary_container : Theme.Palette.surface_container_highest
        contentColor: checked ? Theme.Palette.on_tertiary_container : Theme.Palette.on_surface
        onClicked: w.cycleLoop()
    }

    // Закрытие списка щелчком мимо
    MouseArea {
        anchors.fill: parent
        z: 5
        visible: w.menuOpen
        onClicked: w.menuOpen = false
    }

    // Список источников: все плееры MPRIS
    Rectangle {
        id: menu
        z: 6
        anchors.top: source.bottom
        anchors.topMargin: 6 * w.s
        anchors.right: source.right
        width: Math.min(w.width - 2 * w.pad, 210 * w.s)
        height: Math.min(list.height + 12 * w.s, w.height - y - 8 * w.s)
        radius: 16 * w.s
        color: Theme.Palette.surface_container_highest
        clip: true
        transformOrigin: Item.TopRight
        scale: w.menuOpen ? 1 : 0.85
        opacity: w.menuOpen ? 1 : 0
        visible: opacity > 0
        Behavior on scale { Emphasized {} }
        Behavior on opacity { Smooth { duration: Tokens.animationFast } }

        Flickable {
            anchors.fill: parent
            anchors.margins: 6 * w.s
            contentHeight: list.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: parent.width
                spacing: 2 * w.s

                Repeater {
                    model: Mpris.players

                    Rectangle {
                        id: entry
                        required property var modelData
                        readonly property bool current: modelData === w.player
                        readonly property string iconPath: modelData.desktopEntry
                            ? Quickshell.iconPath(modelData.desktopEntry, true) : ""

                        width: list.width
                        height: 36 * w.s
                        radius: 10 * w.s
                        color: current ? Theme.Palette.secondary_container : "transparent"
                        Behavior on color { SmoothColor {} }

                        StateLayer {
                            radius: entry.radius
                            color: Theme.Palette.on_surface
                            hovered: entryArea.containsMouse
                            pressed: entryArea.pressed
                        }

                        Item {
                            id: entryIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * w.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18 * w.s
                            height: width

                            IconImage {
                                anchors.fill: parent
                                visible: entry.iconPath !== ""
                                source: entry.iconPath
                            }
                            Icon {
                                anchors.fill: parent
                                visible: entry.iconPath === ""
                                text: Icons.music
                                size: 15 * w.s
                                color: Theme.Palette.on_surface_variant
                            }
                        }

                        Text {
                            anchors.left: entryIcon.right
                            anchors.leftMargin: 10 * w.s
                            anchors.right: check.left
                            anchors.rightMargin: 6 * w.s
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: entry.modelData.identity + (entry.modelData.isPlaying ? " · играет" : "")
                            color: entry.current ? Theme.Palette.on_secondary_container : Theme.Palette.on_surface
                            font.family: Tokens.typography.family
                            font.pixelSize: Math.round(12 * w.s)
                        }

                        Icon {
                            id: check
                            anchors.right: parent.right
                            anchors.rightMargin: 10 * w.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.check
                            size: 16 * w.s
                            color: Theme.Palette.on_secondary_container
                            opacity: entry.current ? 1 : 0
                            Behavior on opacity { Smooth { duration: Tokens.animationFast } }
                        }

                        MouseArea {
                            id: entryArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: w.choose(entry.modelData)
                        }
                    }
                }

                Text {
                    visible: Mpris.players.values.length === 0
                    text: "Нет плееров"
                    color: Theme.Palette.on_surface_variant
                    font.family: Tokens.typography.family
                    font.pixelSize: Math.round(12 * w.s)
                    leftPadding: 10 * w.s
                }
            }
        }
    }
}
