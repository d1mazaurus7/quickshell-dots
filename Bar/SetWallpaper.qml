import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../theme" as Theme
import "../shell/theme"
import "../components/animations" as Flow
import "../shell/config"

Item {
    id: wallpaperPicker

    // Экран и высота бара, под нижней кромкой которого выезжает окно
    property var screen: null
    property real barHeight: 0

    property bool open: false

    // Секретные обои: passwordMode — показан ввод пароля, secret — открыта секретная папка
    property bool passwordMode: false
    property bool secret: false

    function toggleSecret(): void {
        if (secret || passwordMode) {
            passwordMode = false;
            secret = false;
        } else {
            passwordInput.text = "";
            passwordMode = true;
        }
    }

    function tryPassword(): void {
        const password = Config.options.wallpaper.password;
        if (password.length > 0 && passwordInput.text === password) {
            secret = true;
            passwordMode = false;
        } else {
            passwordInput.text = "";
            shake.restart();
        }
    }

    onSecretChanged: {
        wallpaperGrid.model = [];
        loadWallpapers();
        wallpaperGrid.currentIndex = 0;
    }

    onPasswordModeChanged: {
        if (passwordMode)
            passwordInput.forceActiveFocus();
        else
            wallpaperGrid.forceActiveFocus();
    }

    function toggle(): void {
        open = !open;
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            wallpaperPicker.toggle();
        }

        function show(): void {
            wallpaperPicker.open = true;
        }

        function hide(): void {
            wallpaperPicker.open = false;
        }
    }

    onOpenChanged: {
        if (open) {
            passwordMode = false;
            if (secret)
                secret = false;
            else
                loadWallpapers();
            wallpaperGrid.currentIndex = 0;
            wallpaperGrid.forceActiveFocus();
        }
    }

    // Команда задаётся в момент запуска: привязка к secret не успевала обновиться до старта
    function loadWallpapers(): void {
        const dir = Quickshell.env("HOME") + (secret ? "/Pictures/.secret_wallpapers/" : "/Pictures/Wallpapers/");
        loadWallpapersProcess.running = false;
        loadWallpapersProcess.command = ["sh", "-c", "find \"$1\" -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \\) | sort", "sh", dir];
        loadWallpapersProcess.running = true;
    }

    // Процесс загрузки списка обоев
    Process {
        id: loadWallpapersProcess

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split('\n');
                var wallpapers = [];

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line.length > 0) {
                        wallpapers.push(line);
                    }
                }

                wallpaperGrid.model = wallpapers;
            }
        }
    }

    // Процесс смены обоев через niri
    Process {
        id: setWallpaperProcess
        property string wallpaperPath: ""

        command: ["set-wallpaper", wallpaperPath]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Обои успешно изменены");
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    console.error("Ошибка смены обоев:", this.text);
                }
            }
        }

        onExited: (code, status) => {
            wallpaperPicker.open = false;
        }
    }

    function setWallpaper(path: string): void {
        setWallpaperProcess.wallpaperPath = path;
        setWallpaperProcess.running = true;
        transitionSoundTimer.restart();
    }

    // Звук смены обоев с небольшой задержкой, чтобы совпасть с переходом
    Timer {
        id: transitionSoundTimer
        interval: 150
        onTriggered: Quickshell.execDetached(["pw-play", Quickshell.shellDir + "/assets/sounds/transition_serp.wav"])
    }

    // Выбранный путь обоев
    property string selectedWallpaper: ""

    // Привязка выбранного пути к текущему элементу
    Binding on selectedWallpaper {
        when: wallpaperGrid.currentItem !== null
        value: wallpaperGrid.currentItem ? wallpaperGrid.currentItem.wallpaperPath : ""
    }

    // Layer-shell окно вместо popup: открывается по IPC и получает клавиатуру
    PanelWindow {
        id: window

        screen: wallpaperPicker.screen

        WlrLayershell.namespace: "qs:wallpaper"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: wallpaperPicker.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Окно остаётся видимым, пока идёт анимация закрытия
        visible: wallpaperPicker.open || dropdown.revealHeight > 0

        // Клик вне окна закрывает его
        MouseArea {
            anchors.fill: parent
            onClicked: wallpaperPicker.open = false
        }

        // Выезжающее из бара тело с вогнутыми скруглениями у стыка
        Item {
            id: dropdown

            readonly property int contentWidth: 800
            readonly property int padding: 12
            readonly property int radius: Tokens.radius(16)
            readonly property int earRadius: Tokens.radius(16)
            readonly property int animDuration: 220

            readonly property real fullHeight: body.childrenRect.height + padding * 2
            property real revealHeight: wallpaperPicker.open ? fullHeight : 0

            Behavior on revealHeight { NumberAnimation { duration: dropdown.animDuration; easing.type: Easing.OutCubic } }

            x: (parent.width - width) / 2
            y: wallpaperPicker.barHeight
            width: contentWidth + earRadius * 2
            height: revealHeight

            // Фон цвета бара: вогнутые скругления сверху, обычные углы снизу
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: bg

                    readonly property real w: dropdown.width
                    readonly property real h: dropdown.revealHeight
                    readonly property real er: dropdown.earRadius
                    readonly property real erY: Math.min(er, h / 2)
                    readonly property real br: dropdown.radius
                    readonly property real brY: Math.min(br, h / 2)

                    strokeWidth: -1
                    fillColor: Theme.Palette.background

                    startX: 0; startY: 0
                    PathLine { x: bg.w; y: 0 }
                    PathArc { x: bg.w - bg.er; y: bg.erY; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
                    PathLine { x: bg.w - bg.er; y: bg.h - bg.brY }
                    PathArc { x: bg.w - bg.er - bg.br; y: bg.h; radiusX: bg.br; radiusY: bg.brY }
                    PathLine { x: bg.er + bg.br; y: bg.h }
                    PathArc { x: bg.er; y: bg.h - bg.brY; radiusX: bg.br; radiusY: bg.brY }
                    PathLine { x: bg.er; y: bg.erY }
                    PathArc { x: 0; y: 0; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
                }
            }

            Item {
                x: dropdown.earRadius
                width: dropdown.contentWidth
                height: dropdown.revealHeight
                clip: true

                // Клики внутри окна не закрывают его
                MouseArea {
                    anchors.fill: parent
                }

                Item {
                    id: body
                    x: dropdown.padding
                    y: dropdown.padding
                    width: parent.width - dropdown.padding * 2
                    height: childrenRect.height

                    ColumnLayout {
                        width: parent.width
                        spacing: 12

                        // Заголовок
                        Rectangle {
                            id: header
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            color: Theme.Palette.surface_container
                            radius: Tokens.radius(12)

                            Text {
                                anchors.centerIn: parent
                                text: wallpaperPicker.secret ? "Секретные обои" : "Выбор обоев"
                                color: Theme.Palette.on_surface
                                font.family: "JetBrains Mono"
                                font.pointSize: 13
                                font.bold: true
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 404

                            Item {
                                id: gridLayer
                                anchors.fill: parent
                                opacity: wallpaperPicker.passwordMode ? 0 : 1
                                scale: wallpaperPicker.passwordMode ? 0.96 : 1
                                visible: opacity > 0

                                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                            // Сетка с обоями
                            GridView {
                                id: wallpaperGrid
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: scrollbar.left
                                anchors.rightMargin: 6
                                anchors.bottom: parent.bottom

                                readonly property real preferredCellWidth: 160
                                readonly property int columns: Math.max(1, Math.floor(width / preferredCellWidth))
                                cellWidth: columns > 0 ? width / columns : preferredCellWidth
                                cellHeight: 110

                                clip: true
                                model: []

                                delegate: Item {
                                    width: wallpaperGrid.cellWidth
                                    height: wallpaperGrid.cellHeight

                                    property string wallpaperPath: modelData

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        color: delegateMouseArea.containsMouse
                                               ? Theme.Palette.surface_container_high
                                               : Theme.Palette.surface_container
                                        radius: Tokens.radius(10)

                                        // Предпросмотр
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            source: "file://" + modelData
                                            sourceSize.width: width
                                            sourceSize.height: height
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            mipmap: true
                                        }

                                        MouseArea {
                                            id: delegateMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: {
                                                wallpaperGrid.currentIndex = index;
                                                wallpaperPicker.selectedWallpaper = modelData;
                                            }

                                            onDoubleClicked: {
                                                wallpaperGrid.currentIndex = index;
                                                wallpaperPicker.selectedWallpaper = modelData;
                                                wallpaperPicker.setWallpaper(modelData);
                                            }
                                        }
                                    }
                                }

                                highlight: Flow.FlowHighlight {
                                    view: wallpaperGrid
                                    highlightColor: "transparent"
                                    highlightOpacity: 1.0
                                    selectedScale: 1.0
                                    highlightRadius: 10
                                    border.width: 2
                                    border.color: Theme.Palette.primary
                                }

                                focus: true

                                // Звук листания: один раз на нажатие, автоповтор при удержании — без звука.
                                // Событие не принимаем, чтобы навигацию обработал сам GridView
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_S && (event.modifiers & Qt.AltModifier)) {
                                        event.accepted = true;
                                        wallpaperPicker.toggleSecret();
                                        return;
                                    }
                                    if (event.isAutoRepeat || count === 0)
                                        return;
                                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                                            || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                        Quickshell.execDetached(["pw-play", Quickshell.shellDir + "/assets/sounds/sfx.wav"]);
                                    }
                                }

                                Keys.onReturnPressed: {
                                    if (wallpaperPicker.selectedWallpaper.length > 0) {
                                        wallpaperPicker.setWallpaper(wallpaperPicker.selectedWallpaper);
                                    }
                                }

                                Keys.onEscapePressed: {
                                    wallpaperPicker.open = false;
                                }
                            }

                            // Скроллбар
                            Rectangle {
                                id: scrollbar
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: 6
                                color: "transparent"
                                radius: Tokens.radius(3)

                                Rectangle {
                                    id: scrollHandle
                                    x: 0
                                    width: parent.width
                                    radius: Tokens.radius(3)
                                    color: Theme.Palette.on_surface
                                    opacity: scrollMouseArea.containsMouse ? 0.5 : 0.3

                                    readonly property real contentHeight: wallpaperGrid.contentHeight
                                    readonly property real viewHeight: wallpaperGrid.height
                                    readonly property real ratio: viewHeight / contentHeight
                                    readonly property real handleHeight: Math.max(24, viewHeight * ratio)
                                    height: contentHeight > viewHeight ? handleHeight : 0

                                    y: contentHeight > viewHeight
                                       ? (wallpaperGrid.contentY / (contentHeight - viewHeight)) * (viewHeight - handleHeight)
                                       : 0

                                    Behavior on opacity {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }

                                    MouseArea {
                                        id: scrollMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true

                                        property real pressY: 0
                                        property real pressContentY: 0

                                        onPressed: (mouse) => {
                                            pressY = mouse.y;
                                            pressContentY = wallpaperGrid.contentY;
                                        }

                                        onPositionChanged: (mouse) => {
                                            if (pressed) {
                                                var delta = mouse.y - pressY;
                                                var scrollRatio = (scrollHandle.contentHeight - scrollHandle.viewHeight)
                                                                   / (scrollHandle.viewHeight - scrollHandle.handleHeight);
                                                wallpaperGrid.contentY = Math.max(
                                                    0,
                                                    Math.min(
                                                        scrollHandle.contentHeight - scrollHandle.viewHeight,
                                                        pressContentY + delta * scrollRatio
                                                    )
                                                );
                                            }
                                        }
                                    }
                                }
                            }
                            }

                            // Ввод пароля секретных обоев
                            Item {
                                id: passwordLayer
                                anchors.fill: parent
                                opacity: wallpaperPicker.passwordMode ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                                Column {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: wallpaperPicker.passwordMode ? 0 : Tokens.spacingMedium
                                    spacing: Tokens.spacingLargeV

                                    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "ах ты шалунишка, ну заходи!"
                                        color: Theme.Palette.on_surface
                                        font: Tokens.fontLarge
                                    }

                                    Rectangle {
                                        id: passwordField
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: Tokens.scaled(280)
                                        height: passwordInput.implicitHeight + Tokens.spacingMediumV * 2
                                        radius: Tokens.radiusMedium
                                        color: passwordArea.containsMouse && !passwordInput.activeFocus
                                               ? Theme.Palette.surface_container_highest
                                               : Theme.Palette.surface_container_high
                                        border.width: passwordInput.activeFocus ? 2 : 1
                                        border.color: shake.running ? Theme.Palette.error
                                                    : passwordInput.activeFocus ? Theme.Palette.primary
                                                    : Theme.Palette.outline_variant

                                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                                        Behavior on border.color { ColorAnimation { duration: Tokens.animationFast } }

                                        transform: Translate { id: shakeShift }

                                        SequentialAnimation {
                                            id: shake
                                            NumberAnimation { target: shakeShift; property: "x"; to: -8; duration: 50; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: shakeShift; property: "x"; to: 6; duration: 80; easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: shakeShift; property: "x"; to: -3; duration: 70; easing.type: Easing.InOutQuad }
                                            NumberAnimation { target: shakeShift; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
                                        }

                                        MouseArea {
                                            id: passwordArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.IBeamCursor
                                            onClicked: passwordInput.forceActiveFocus()
                                        }

                                        TextInput {
                                            id: passwordInput
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.leftMargin: Tokens.spacingMedium
                                            anchors.rightMargin: Tokens.spacingMedium
                                            anchors.verticalCenter: parent.verticalCenter
                                            echoMode: TextInput.Password
                                            horizontalAlignment: TextInput.AlignHCenter
                                            color: Theme.Palette.on_surface
                                            selectionColor: Theme.Palette.primary
                                            selectedTextColor: Theme.Palette.on_primary
                                            font: Tokens.fontMedium
                                            clip: true

                                            onAccepted: wallpaperPicker.tryPassword()

                                            Keys.onPressed: (event) => {
                                                if (event.key === Qt.Key_S && (event.modifiers & Qt.AltModifier)) {
                                                    event.accepted = true;
                                                    wallpaperPicker.toggleSecret();
                                                } else if (event.key === Qt.Key_Escape) {
                                                    event.accepted = true;
                                                    wallpaperPicker.passwordMode = false;
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
        }
    }
}
