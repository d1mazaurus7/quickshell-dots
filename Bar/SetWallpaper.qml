import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
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

    // Кнопка предпросмотра: тональная или заполненная, со слоем состояния hover/pressed
    component PreviewButton: Rectangle {
        id: button
        property string text
        property bool filled: false
        signal clicked()

        readonly property color contentColor: filled ? Theme.Palette.on_primary : Theme.Palette.on_secondary_container

        width: label.implicitWidth + 48
        height: 44
        radius: height / 2
        color: filled ? Theme.Palette.primary : Theme.Palette.secondary_container

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: button.contentColor
            opacity: buttonArea.pressed ? 0.12 : buttonArea.containsMouse ? 0.08 : 0

            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.contentColor
            font.family: "JetBrains Mono"
            font.pointSize: 11
            font.bold: true
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // Вкладки: 0 — локальные, 1 — Wallhaven, 2 — видео
    property int tab: 0

    // Состояние выдачи Wallhaven
    property string query: ""
    property int whPage: 0
    property int whLastPage: 1
    property string whSeed: ""
    property bool whLoading: false
    property int whRequest: 0
    property string downloadingUrl: ""

    // Направление слайда при смене вкладки
    property int lastTab: 0
    property int slideDir: 1

    // Предпросмотр: элемент модели и прямоугольник карточки, из которого разворачивается изображение
    property bool previewOpen: false
    property int previewIndex: -1
    property string previewPath: ""
    property string previewThumb: ""
    property string previewSource: ""
    property rect previewFrom: Qt.rect(0, 0, 0, 0)

    function openPreview(): void {
        const item = wallpaperGrid.currentItem;
        if (!item)
            return;
        const data = wallpapersModel.get(wallpaperGrid.currentIndex);
        previewIndex = wallpaperGrid.currentIndex;
        previewPath = data.path;
        previewThumb = data.preview;
        previewSource = data.remote ? data.path : tab === 2 ? data.preview : "file://" + data.path;
        const p = item.mapToItem(previewLayer, 8, 8);
        previewFrom = Qt.rect(p.x, p.y, item.width - 16, item.height - 16);
        previewOpen = true;
    }

    onPreviewOpenChanged: {
        previewLayer.setView(1, 0, 0);
        if (previewOpen)
            previewLayer.forceActiveFocus();
        else
            wallpaperGrid.forceActiveFocus();
    }

    readonly property string wallpapersDir: Quickshell.env("HOME") + "/Pictures/Wallpapers/"

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
        if (tab !== 1) {
            loadWallpapers();
            wallpaperGrid.currentIndex = 0;
        }
    }

    onTabChanged: {
        slideDir = tab > lastTab ? 1 : -1;
        lastTab = tab;
        tabSlide.restart();
        loadWallpapers();
        wallpaperGrid.currentIndex = 0;
        wallpaperGrid.forceActiveFocus();
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
        if (!open)
            previewOpen = false;
        if (open) {
            passwordMode = false;
            if (secret)
                secret = false;
            else if (tab !== 1 || wallpapersModel.count === 0)
                loadWallpapers();
            wallpaperGrid.currentIndex = 0;
            wallpaperGrid.forceActiveFocus();
        }
    }

    // Команда задаётся в момент запуска: привязка к secret не успевала обновиться до старта
    function loadWallpapers(): void {
        loadWallpapersProcess.running = false;
        wallpapersModel.clear();
        whRequest++;
        whLoading = false;

        if (tab === 1) {
            whPage = 0;
            whLastPage = 1;
            whSeed = "";
            loadWallhaven();
            return;
        }

        const dir = Quickshell.env("HOME") + (secret ? "/Pictures/.secret_wallpapers/" : "/Pictures/Wallpapers/");
        loadWallpapersProcess.tab = tab;
        if (tab === 2) {
            // Превью видео — кадр через mpv, кэшируется по md5 пути
            const thumbs = Quickshell.env("HOME") + "/.cache/quickshell/wallpaper-frames";
            loadWallpapersProcess.command = ["sh", "-c",
                "mkdir -p \"$2\"; find \"$1\" -type f \\( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.m4v' \\) | sort | "
                + "while IFS= read -r f; do t=\"$2/$(printf %s \"$f\" | md5sum | cut -d' ' -f1).png\"; "
                + "[ -f \"$t\" ] || mpv --no-config --really-quiet --no-audio --start=10% --frames=1 --vf=scale=1920:-2 -o \"$t\" \"$f\" >/dev/null 2>&1 </dev/null; "
                + "printf '%s\\t%s\\n' \"$f\" \"$t\"; done", "sh", dir, thumbs];
        } else {
            loadWallpapersProcess.command = ["sh", "-c", "find \"$1\" -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \\) | sort", "sh", dir];
        }
        loadWallpapersProcess.running = true;
    }

    // Следующая страница Wallhaven: без запроса — случайные, с запросом — по релевантности
    function loadWallhaven(): void {
        if (whLoading || whPage >= whLastPage)
            return;
        const req = whRequest;
        whLoading = true;

        let url = "https://wallhaven.cc/api/v1/search?purity=100&categories=111&page=" + (whPage + 1);
        url += query.length > 0 ? "&sorting=relevance&q=" + encodeURIComponent(query) : "&sorting=random";
        if (whSeed.length > 0)
            url += "&seed=" + whSeed;

        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || req !== whRequest)
                return;
            whLoading = false;
            if (xhr.status !== 200) {
                console.error("Wallhaven:", xhr.status, xhr.statusText);
                whRetry.restart();
                return;
            }
            const res = JSON.parse(xhr.responseText);
            whPage = Number(res.meta.current_page);
            whLastPage = Number(res.meta.last_page);
            whSeed = res.meta.seed || "";
            for (const w of res.data)
                wallpapersModel.append({ path: w.path, preview: w.thumbs.small, remote: true });
        };
        xhr.open("GET", url);
        xhr.send();
    }

    // Повтор после ошибки (например, лимит 45 запросов в минуту)
    Timer {
        id: whRetry
        interval: 3000
        onTriggered: {
            if (wallpaperPicker.tab === 1)
                wallpaperPicker.loadWallhaven();
        }
    }

    // Догружаем, пока до конца ленты меньше двух рядов
    function checkMore(): void {
        if (tab === 1 && wallpaperGrid.contentY + wallpaperGrid.height > wallpaperGrid.contentHeight - wallpaperGrid.cellHeight * 2)
            loadWallhaven();
    }

    function search(text: string): void {
        query = text.trim();
        loadWallpapers();
        wallpaperGrid.currentIndex = 0;
        wallpaperGrid.forceActiveFocus();
    }

    ListModel {
        id: wallpapersModel
    }

    // Процесс загрузки списка обоев
    Process {
        id: loadWallpapersProcess
        property int tab: 0

        stdout: StdioCollector {
            onStreamFinished: {
                if (loadWallpapersProcess.tab !== wallpaperPicker.tab)
                    return;
                const lines = this.text.split('\n');
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].trim().split('\t');
                    if (parts[0].length > 0)
                        wallpapersModel.append({ path: parts[0], preview: "file://" + (parts[1] || parts[0]), remote: false });
                }
            }
        }
    }

    // Скачивание обоев с Wallhaven в папку локальных обоев
    Process {
        id: downloadProcess
        property string target: ""

        onExited: (code, status) => {
            wallpaperPicker.downloadingUrl = "";
            if (code === 0)
                wallpaperPicker.setWallpaper(target);
            else
                console.error("Ошибка загрузки обоев:", code);
        }
    }

    function download(url: string): void {
        if (downloadProcess.running)
            return;
        downloadingUrl = url;
        downloadProcess.target = wallpapersDir + url.split("/").pop();
        downloadProcess.command = ["sh", "-c", "[ -f \"$2\" ] || { curl -fsSL -o \"$2.part\" \"$1\" && mv \"$2.part\" \"$2\"; }", "sh", url, downloadProcess.target];
        downloadProcess.running = true;
    }

    function activate(index: int): void {
        if (index < 0 || index >= wallpapersModel.count)
            return;
        const item = wallpapersModel.get(index);
        if (item.remote)
            download(item.path);
        else
            setWallpaper(item.path);
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
        visible: wallpaperPicker.open || dropdown.revealHeight > 0 || previewLayer.visible

        // Клик вне окна закрывает его
        MouseArea {
            anchors.fill: parent
            onClicked: wallpaperPicker.open = false
        }

        // Предпросмотр: изображение разворачивается из карточки почти на весь экран
        Item {
            id: previewLayer
            anchors.fill: parent
            z: 1
            visible: progress > 0
            focus: wallpaperPicker.previewOpen

            property real progress: wallpaperPicker.previewOpen ? 1 : 0
            Behavior on progress { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

            onVisibleChanged: {
                if (!visible) {
                    wallpaperPicker.previewSource = "";
                    wallpaperPicker.previewThumb = "";
                }
            }

            // Масштаб и сдвиг: target* — конечные значения, zoom/pan — анимированные
            property real targetZoom: 1
            property real targetPanX: 0
            property real targetPanY: 0
            property real zoom: targetZoom
            property real panX: targetPanX
            property real panY: targetPanY

            Behavior on zoom { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
            Behavior on panX { enabled: !previewDrag.pressed; NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
            Behavior on panY { enabled: !previewDrag.pressed; NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

            function setView(z: real, px: real, py: real): void {
                const mx = toW * (z - 1) / 2;
                const my = toH * (z - 1) / 2;
                targetZoom = z;
                targetPanX = Math.max(-mx, Math.min(mx, px));
                targetPanY = Math.max(-my, Math.min(my, py));
            }

            // Точка под курсором остаётся на месте
            function zoomAt(x: real, y: real, delta: real): void {
                if (delta === 0)
                    return;
                const z = Math.max(1, Math.min(8, targetZoom * (delta > 0 ? 1.25 : 0.8)));
                const k = z / targetZoom;
                const cx = x - toW / 2;
                const cy = y - toH / 2;
                setView(z, cx - (cx - targetPanX) * k, cy - (cy - targetPanY) * k);
            }

            readonly property real aspect: fullImage.status === Image.Ready ? fullImage.implicitWidth / fullImage.implicitHeight
                                         : thumbImage.status === Image.Ready ? thumbImage.implicitWidth / thumbImage.implicitHeight
                                         : 16 / 9
            readonly property int controlsSpace: 76
            readonly property real toW: Math.min(width * 0.9, (height * 0.92 - controlsSpace) * aspect)
            readonly property real toH: toW / aspect
            readonly property real toX: (width - toW) / 2
            readonly property real toY: (height - controlsSpace - toH) / 2

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Space) {
                    event.accepted = true;
                    if (!event.isAutoRepeat)
                        wallpaperPicker.previewOpen = false;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    event.accepted = true;
                    wallpaperPicker.activate(wallpaperPicker.previewIndex);
                }
            }

            // Затемнение фона
            Rectangle {
                anchors.fill: parent
                color: Theme.Palette.surface_container_lowest
                opacity: 0.8 * previewLayer.progress
            }

            MouseArea {
                anchors.fill: parent
                onClicked: wallpaperPicker.previewOpen = false
            }

            Item {
                id: previewFrame
                readonly property real p: previewLayer.progress
                readonly property rect from: wallpaperPicker.previewFrom

                x: from.x + (previewLayer.toX - from.x) * p
                y: from.y + (previewLayer.toY - from.y) * p
                width: from.width + (previewLayer.toW - from.width) * p
                height: from.height + (previewLayer.toH - from.height) * p
                clip: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Item {
                    width: previewFrame.width * previewLayer.zoom
                    height: previewFrame.height * previewLayer.zoom
                    x: (previewFrame.width - width) / 2 + previewLayer.panX
                    y: (previewFrame.height - height) / 2 + previewLayer.panY

                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        source: wallpaperPicker.previewThumb
                        sourceSize.width: 320
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Image {
                        id: fullImage
                        anchors.fill: parent
                        source: wallpaperPicker.previewSource
                        sourceSize.width: previewLayer.width * 2
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        mipmap: true
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    id: previewDrag
                    anchors.fill: parent
                    cursorShape: previewLayer.targetZoom > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

                    property real lastX: 0
                    property real lastY: 0

                    onPressed: (mouse) => {
                        lastX = mouse.x;
                        lastY = mouse.y;
                    }
                    onPositionChanged: (mouse) => {
                        if (!pressed)
                            return;
                        previewLayer.setView(previewLayer.targetZoom, previewLayer.targetPanX + mouse.x - lastX, previewLayer.targetPanY + mouse.y - lastY);
                        lastX = mouse.x;
                        lastY = mouse.y;
                    }
                    onDoubleClicked: previewLayer.setView(1, 0, 0)
                    onWheel: (wheel) => previewLayer.zoomAt(wheel.x, wheel.y, wheel.angleDelta.y)
                }
            }

            Rectangle {
                id: previewMask
                width: previewFrame.width
                height: previewFrame.height
                radius: Tokens.radius(6 + 10 * previewFrame.p)
                visible: false
                layer.enabled: true
            }

            // Загрузка полного изображения
            Text {
                anchors.centerIn: previewFrame
                text: "Загрузка…"
                color: Theme.Palette.on_surface
                font: Tokens.fontMedium
                opacity: fullImage.status === Image.Loading ? previewLayer.progress : 0

                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: previewLayer.toY + previewLayer.toH + 20 + (1 - previewLayer.progress) * 16
                spacing: 12
                opacity: previewLayer.progress

                PreviewButton {
                    text: "Назад"
                    onClicked: wallpaperPicker.previewOpen = false
                }

                PreviewButton {
                    text: wallpaperPicker.downloadingUrl.length > 0 && wallpaperPicker.downloadingUrl === wallpaperPicker.previewPath
                          ? "Загрузка…" : "Установить обои"
                    filled: true
                    onClicked: wallpaperPicker.activate(wallpaperPicker.previewIndex)
                }
            }
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

                        // Вкладки
                        Rectangle {
                            id: header
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            color: Theme.Palette.surface_container
                            radius: Tokens.radius(12)

                            // Выделение активной вкладки переезжает к новой
                            Rectangle {
                                readonly property real tabWidth: (header.width - 6 * 4) / 3
                                x: 6 + wallpaperPicker.tab * (tabWidth + 6)
                                y: 6
                                width: tabWidth
                                height: header.height - 12
                                radius: Tokens.radius(8)
                                color: Theme.Palette.secondary_container

                                Behavior on x { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                Repeater {
                                    model: [wallpaperPicker.secret ? "Секретные" : "Локальные", "Интернет", "Видео"]

                                    delegate: Rectangle {
                                        required property string modelData
                                        required property int index
                                        readonly property bool active: wallpaperPicker.tab === index

                                        width: (parent.width - parent.spacing * 2) / 3
                                        height: parent.height
                                        radius: Tokens.radius(8)
                                        color: active ? "transparent"
                                             : tabArea.pressed ? Theme.Palette.surface_container_highest
                                             : tabArea.containsMouse ? Theme.Palette.surface_container_high
                                             : "transparent"

                                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: active ? Theme.Palette.on_secondary_container : Theme.Palette.on_surface_variant
                                            font.family: "JetBrains Mono"
                                            font.pointSize: 12
                                            font.bold: true

                                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                                        }

                                        MouseArea {
                                            id: tabArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                wallpaperPicker.passwordMode = false;
                                                wallpaperPicker.tab = index;
                                            }
                                        }
                                    }
                                }
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

                            // Поиск Wallhaven, выезжает только на вкладке «Интернет»
                            Item {
                                id: searchBar
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: wallpaperPicker.tab === 1 ? 48 : 0
                                opacity: wallpaperPicker.tab === 1 ? 1 : 0
                                visible: opacity > 0
                                clip: true

                                Behavior on height { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 40
                                    radius: Tokens.radiusMedium
                                    color: searchArea.containsMouse && !searchInput.activeFocus
                                           ? Theme.Palette.surface_container_highest
                                           : Theme.Palette.surface_container_high
                                    border.width: searchInput.activeFocus ? 2 : 1
                                    border.color: searchInput.activeFocus ? Theme.Palette.primary : Theme.Palette.outline_variant

                                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                                    Behavior on border.color { ColorAnimation { duration: Tokens.animationFast } }

                                    MouseArea {
                                        id: searchArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.IBeamCursor
                                        onClicked: searchInput.forceActiveFocus()
                                    }

                                    Text {
                                        anchors.fill: searchInput
                                        verticalAlignment: Text.AlignVCenter
                                        text: "Поиск на Wallhaven…"
                                        color: Theme.Palette.on_surface_variant
                                        font: Tokens.fontMedium
                                        visible: searchInput.text.length === 0
                                    }

                                    TextInput {
                                        id: searchInput
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: Tokens.spacingLarge
                                        anchors.rightMargin: Tokens.spacingLarge
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Theme.Palette.on_surface
                                        selectionColor: Theme.Palette.primary
                                        selectedTextColor: Theme.Palette.on_primary
                                        font: Tokens.fontMedium
                                        clip: true

                                        onAccepted: wallpaperPicker.search(text)

                                        Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Down) {
                                                event.accepted = true;
                                                wallpaperGrid.forceActiveFocus();
                                            }
                                        }
                                    }
                                }
                            }

                            // Сетка с обоями
                            GridView {
                                id: wallpaperGrid
                                anchors.top: searchBar.bottom
                                anchors.left: parent.left
                                anchors.right: scrollbar.left
                                anchors.rightMargin: 6
                                anchors.bottom: parent.bottom

                                readonly property real preferredCellWidth: 160
                                readonly property int columns: Math.max(1, Math.floor(width / preferredCellWidth))
                                cellWidth: columns > 0 ? width / columns : preferredCellWidth
                                cellHeight: 110

                                clip: true
                                model: wallpapersModel

                                // Подгрузка следующей страницы Wallhaven у конца списка
                                onContentYChanged: if (count > 0) wallpaperPicker.checkMore()
                                onContentHeightChanged: if (count > 0) wallpaperPicker.checkMore()

                                transform: Translate { id: slideShift }

                                // Пока есть следующие страницы, в конце ленты — «Загрузка…»
                                footer: Item {
                                    width: wallpaperGrid.width
                                    height: wallpaperPicker.tab === 1 && wallpaperGrid.count > 0
                                            && wallpaperPicker.whPage < wallpaperPicker.whLastPage ? 56 : 0
                                    visible: height > 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Загрузка…"
                                        color: Theme.Palette.on_surface_variant
                                        font: Tokens.fontMedium
                                    }
                                }

                                delegate: Item {
                                    required property int index
                                    required property string path
                                    required property string preview

                                    width: wallpaperGrid.cellWidth
                                    height: wallpaperGrid.cellHeight

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
                                            source: preview
                                            sourceSize.width: width
                                            sourceSize.height: height
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            mipmap: true
                                        }

                                        // Индикатор скачивания
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: Theme.Palette.surface_container
                                            opacity: wallpaperPicker.downloadingUrl === path ? 0.8 : 0
                                            visible: opacity > 0

                                            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Загрузка…"
                                                color: Theme.Palette.on_surface
                                                font: Tokens.fontMedium
                                            }
                                        }

                                        MouseArea {
                                            id: delegateMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true

                                            onClicked: wallpaperGrid.currentIndex = index

                                            onDoubleClicked: {
                                                wallpaperGrid.currentIndex = index;
                                                wallpaperPicker.activate(index);
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
                                    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                        event.accepted = true;
                                        wallpaperPicker.tab = (wallpaperPicker.tab + (event.key === Qt.Key_Tab ? 1 : 2)) % 3;
                                        return;
                                    }
                                    if (event.key === Qt.Key_Space) {
                                        event.accepted = true;
                                        if (!event.isAutoRepeat && count > 0)
                                            wallpaperPicker.openPreview();
                                        return;
                                    }
                                    if (event.key === Qt.Key_Slash && wallpaperPicker.tab === 1) {
                                        event.accepted = true;
                                        searchInput.forceActiveFocus();
                                        return;
                                    }
                                    if (event.isAutoRepeat || count === 0)
                                        return;
                                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                                            || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                                        Quickshell.execDetached(["pw-play", Quickshell.shellDir + "/assets/sounds/sfx.wav"]);
                                    }
                                }

                                Keys.onReturnPressed: wallpaperPicker.activate(currentIndex)

                                Keys.onEscapePressed: {
                                    wallpaperPicker.open = false;
                                }
                            }

                            // Слайд содержимого при смене вкладки
                            ParallelAnimation {
                                id: tabSlide
                                NumberAnimation { target: slideShift; property: "x"; from: wallpaperPicker.slideDir * 48; to: 0; duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
                                NumberAnimation { target: wallpaperGrid; property: "opacity"; from: 0; to: 1; duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
                            }

                            // Пустой список или загрузка
                            Text {
                                anchors.centerIn: wallpaperGrid
                                transform: Translate { x: slideShift.x }
                                text: wallpaperPicker.whLoading || loadWallpapersProcess.running ? "Загрузка…" : "Ничего не найдено"
                                color: Theme.Palette.on_surface_variant
                                font: Tokens.fontMedium
                                opacity: wallpaperGrid.count === 0 ? 1 : 0
                                visible: opacity > 0

                                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                            }

                            // Скроллбар
                            Rectangle {
                                id: scrollbar
                                anchors.top: searchBar.bottom
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
