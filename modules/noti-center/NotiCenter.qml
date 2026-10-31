import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"
import "../../components/animations" as Anim

// Центр уведомлений: панель справа почти на всю высоту экрана.
// Сам элемент кладётся в бар у правого края; его ширина (reserve)
// анимируется при открытии, бар сдвигает модули влево на эту ширину.
// Открытием управляет владелец через openOutput / openOutputRequested,
// чтобы на всех экранах было одно общее состояние.
Item {
    id: root

    required property ShellScreen screen
    property int barHeight: 56
    // Имя экрана, на котором центр открыт ("" — закрыт). Держит владелец.
    property string openOutput: ""
    // IPC "noti-center" регистрирует только один экземпляр.
    property bool ipcEnabled: false
    // Общее состояние уведомлений (NotificationState).
    required property var notifications

    readonly property var cfg: Config.options.notiCenter
    property int panelWidth: cfg.width
    // Масштаб всех размеров относительно базового макета шириной 380.
    readonly property real s: panelWidth / 380

    signal openOutputRequested(string name)

    readonly property bool open: openOutput !== "" && openOutput === screen.name
    // Место в баре под панель (вместе с левым «ухом»).
    readonly property real fullReserve: dropdown.contentWidth + dropdown.earRadius
    // Панель видна (в т.ч. во время анимации закрытия): бар убирает нижний правый угол.
    readonly property bool shown: dropdown.visible
    property real reserve: open ? fullReserve : 0

    Behavior on reserve { NumberAnimation { duration: dropdown.animDuration; easing.type: Easing.OutCubic } }

    implicitWidth: reserve

    // ---- Управление ----

    function toggle(): void {
        if (openOutput !== "") {
            openOutputRequested("");
            return;
        }
        focusedOutput.running = true;
    }

    function play(sound: string): void {
        if (!cfg.uiSounds)
            return;
        Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + sound + ".wav")]);
    }

    Loader {
        active: root.ipcEnabled
        sourceComponent: IpcHandler {
            target: "noti-center"
            function toggle(): void { root.toggle(); }
        }
    }

    Process {
        id: focusedOutput
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const out = JSON.parse(text);
                    if (out && out.name)
                        root.openOutputRequested(out.name);
                } catch (e) {
                    console.warn("noti-center: не удалось разобрать focused-output:", e);
                }
            }
        }
    }

    onOpenChanged: {
        if (open)
            brightnessGet.running = true;
        else
            page = "";
    }

    // ---- Состояние: Wi-Fi ----

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wifiOn: !!wifiDevice && Networking.wifiEnabled
    readonly property int wifiOthersCount: wifiDevice ? wifiDevice.networks.values.filter(n => !n.connected && n.name !== "").length : 0

    // ---- Состояние: Bluetooth ----

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevice: btAdapter ? (btAdapter.devices.values.find(d => d.connected) ?? null) : null
    readonly property bool btOn: !!btAdapter && btAdapter.enabled
    readonly property int btOthersCount: btAdapter ? btAdapter.devices.values.filter(d => !d.connected).length : 0

    // ---- Состояние: звук ----

    readonly property PwNode sink: Pipewire.defaultAudioSink

    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    // ---- Состояние: яркость (ddcutil, VCP 0x10) ----

    property real brightness: 0
    property int brightnessMax: 100
    property bool brightnessAvailable: false
    property int brightnessTarget: -1

    function setBrightness(v: real): void {
        brightness = v;
        brightnessTarget = Math.round(v * brightnessMax);
        brightnessDebounce.restart();
    }

    function applyBrightness(): void {
        if (brightnessSet.running || brightnessTarget < 0)
            return;
        brightnessSet.command = ["ddcutil", "setvcp", "10", String(brightnessTarget)];
        brightnessTarget = -1;
        brightnessSet.running = true;
    }

    Process {
        id: brightnessGet
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Формат: "VCP 10 C <текущее> <максимум>"
                const m = text.match(/VCP 10 C (\d+) (\d+)/);
                root.brightnessAvailable = !!m;
                if (m && root.brightnessTarget < 0 && !brightnessSet.running) {
                    root.brightnessMax = Number(m[2]) || 100;
                    root.brightness = Number(m[1]) / root.brightnessMax;
                }
            }
        }
    }

    Process {
        id: brightnessSet
        onExited: root.applyBrightness()
    }

    Timer {
        id: brightnessDebounce
        interval: 200
        onTriggered: root.applyBrightness()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Внутренняя страница (заглушка): "", "wifi" или "bluetooth".
    property string page: ""

    // ---- Окно ----

    Anim.BarDropdown {
        id: dropdown
        anchorItem: root
        open: root.open
        contentWidth: root.panelWidth
        // Не меньше максимума из настроек: ширина и высота меняются плавно, без ресайза окна
        maxContentWidth: 640
        maxHeight: root.screen.height - root.barHeight
        padding: 16 * root.s
        alignRight: true
        onDismissed: if (root.open) root.openOutputRequested("")

        Item {
            id: panel
            width: parent.width
            height: (root.screen.height - root.barHeight - dropdown.padding * 2 - 24 * root.s) * root.cfg.heightRatio

            Column {
                id: quick
                width: parent.width
                spacing: 12 * root.s

                // Включение/выключение блоков в настройках — без рывков
                move: Transition {
                    NumberAnimation { properties: "y"; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
                }
                add: Transition {
                    NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
                }

                // Время, дата, день недели
                Item {
                    width: parent.width
                    height: timeCol.height
                    visible: root.cfg.showClock

                    Column {
                        id: timeCol
                        Text {
                            text: Qt.formatDateTime(clock.date, root.cfg.showSeconds ? "HH:mm:ss" : "HH:mm")
                            color: Theme.Palette.on_surface
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Math.round(40 * root.s)
                            font.weight: Font.Light
                        }
                        Text {
                            visible: root.cfg.showDate
                            text: clock.date.toLocaleDateString(Qt.locale(), "d MMMM yyyy")
                            color: Theme.Palette.on_surface_variant
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Math.round(12 * root.s)
                        }
                    }

                    Text {
                        visible: root.cfg.showWeekday
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 8 * root.s
                        text: clock.date.toLocaleDateString(Qt.locale(), "ddd")
                        color: Theme.Palette.on_surface
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(16 * root.s)
                    }
                }

                // Wi-Fi и Bluetooth: нажатая плитка расширяется, соседняя сжимается,
                // сумма ширин постоянна, поэтому за пределы окна они не выходят.
                Item {
                    id: tiles
                    width: parent.width
                    height: 56 * root.s
                    visible: root.cfg.showWifi || root.cfg.showBluetooth

                    readonly property real gap: 10 * root.s
                    readonly property real base: (width - gap) / 2
                    readonly property real grow: 28 * root.s
                    readonly property string pressedTile: wifiTile.down ? "wifi" : btTile.down ? "bluetooth" : ""

                    function tileWidth(name: string): real {
                        // Одна плитка — на всю ширину
                        if (!root.cfg.showWifi || !root.cfg.showBluetooth)
                            return width;
                        if (pressedTile === "")
                            return base;
                        return pressedTile === name ? base + grow : base - grow;
                    }

                    Tile {
                        id: wifiTile
                        visible: root.cfg.showWifi
                        s: root.s
                        width: tiles.tileWidth("wifi")
                        title: "Wi-Fi"
                        active: Networking.wifiEnabled
                        subtitle: !Networking.wifiEnabled ? "Выключен"
                            : root.wifiNetwork ? root.wifiNetwork.name : "Не подключено"
                        onToggled: {
                            Networking.wifiEnabled = !Networking.wifiEnabled;
                            root.play(Networking.wifiEnabled ? "power_on" : "power_off");
                        }
                        onExpand: {
                            root.play("list");
                            root.page = "wifi";
                        }
                    }

                    Tile {
                        id: btTile
                        visible: root.cfg.showBluetooth
                        s: root.s
                        anchors.right: parent.right
                        width: tiles.tileWidth("bluetooth")
                        title: "Bluetooth"
                        active: !!root.btAdapter && root.btAdapter.enabled
                        subtitle: !root.btAdapter ? "Нет адаптера"
                            : !root.btAdapter.enabled ? "Выключен"
                            : root.btDevice ? root.btDevice.name : "Не подключено"
                        onToggled: {
                            if (!root.btAdapter)
                                return;
                            root.btAdapter.enabled = !root.btAdapter.enabled;
                            root.play(root.btAdapter.enabled ? "power_on" : "power_off");
                        }
                        onExpand: {
                            root.play("list");
                            root.page = "bluetooth";
                        }
                    }
                }

                Tile {
                    s: root.s
                    width: parent.width
                    height: 56 * root.s
                    visible: root.cfg.showDnd
                    expandable: false
                    title: "Не беспокоить"
                    active: root.notifications.dnd
                    subtitle: active ? "Включено" : "Выключено"
                    onToggled: {
                        root.notifications.dnd = !root.notifications.dnd;
                        root.play(root.notifications.dnd ? "power_on" : "power_off");
                    }
                }

                Pill {
                    s: root.s
                    width: parent.width
                    visible: root.cfg.showBrightness
                    label: "Яркость"
                    available: root.brightnessAvailable
                    value: root.brightness
                    onMoved: v => root.setBrightness(v)
                    onScrolled: root.play("button")
                }

                Pill {
                    s: root.s
                    width: parent.width
                    visible: root.cfg.showVolume
                    label: root.sink && root.sink.audio && root.sink.audio.muted ? "Громкость (без звука)" : "Громкость"
                    available: !!(root.sink && root.sink.audio)
                    value: available ? Math.min(1, root.sink.audio.volume) : 0
                    onMoved: v => root.sink.audio.volume = v
                    onScrolled: root.play("button")
                }
            }

            // Уведомления: заголовок, очистка, список
            Item {
                id: notiArea
                // Список плавно следует за высотой блока быстрых настроек
                property real quickHeight: quick.height
                Behavior on quickHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                anchors.top: parent.top
                anchors.topMargin: quickHeight + 20 * root.s
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                readonly property int count: root.notifications.history.count
                readonly property var swipeGroup: QtObject {
                    property int activeIndex: -1
                    property real offset: 0
                    property bool detached: false
                }

                Text {
                    anchors.verticalCenter: clearBtn.verticalCenter
                    text: "Уведомления"
                    color: Theme.Palette.on_surface
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(16 * root.s)
                }

                Rectangle {
                    id: clearBtn
                    anchors.right: parent.right
                    width: 36 * root.s
                    height: width
                    radius: height / 2
                    opacity: notiArea.count > 0 ? 1 : 0
                    visible: opacity > 0
                    color: clearArea.pressed ? Theme.Palette.surface_container_highest
                        : clearArea.containsMouse ? Theme.Palette.surface_container_high
                        : Theme.Palette.surface_container
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: "󰆴"
                        color: Theme.Palette.on_surface
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(18 * root.s)
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: root.play("click")
                        onClicked: root.notifications.clearAll()
                    }
                }

                Text {
                    anchors.centerIn: notiFlick
                    visible: notiArea.count === 0
                    text: "Здесь пусто. Возвращайся позже"
                    color: Theme.Palette.on_surface_variant
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(13 * root.s)
                }

                Flickable {
                    id: notiFlick
                    anchors.top: clearBtn.bottom
                    anchors.topMargin: 12 * root.s
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    clip: true
                    contentHeight: notiList.height
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: notiList
                        width: parent.width
                        spacing: 10 * root.s

                        move: Transition {
                            NumberAnimation { properties: "y"; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
                        }
                        add: Transition {
                            NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
                        }

                        Repeater {
                            model: root.notifications.history
                            NotificationCard {
                                required property int nid
                                required property int index
                                notification: root.notifications.find(nid)
                                s: root.s
                                group: notiArea.swipeGroup
                                listIndex: index
                            }
                        }
                    }
                }
            }

            // Заглушка внутреннего окна Wi-Fi / Bluetooth
            Rectangle {
                id: subPage
                anchors.fill: parent
                color: Theme.Palette.background
                visible: opacity > 0
                opacity: root.page !== "" ? 1 : 0
                scale: root.page !== "" ? 1 : 0.97
                // Последняя открытая страница: заголовок не пропадает во время закрытия.
                property string shown: ""

                Connections {
                    target: root
                    function onPageChanged() {
                        if (root.page !== "")
                            subPage.shown = root.page;
                        // Поиск устройств не оставляем включённым после ухода со страницы.
                        if (root.page !== "bluetooth" && root.btAdapter && root.btAdapter.discovering)
                            root.btAdapter.discovering = false;
                        if (root.page !== "wifi" && root.wifiDevice && root.wifiDevice.scannerEnabled)
                            root.wifiDevice.scannerEnabled = false;
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Row {
                    id: subHeader
                    spacing: 8 * root.s

                    Rectangle {
                        width: 36 * root.s
                        height: width
                        radius: height / 2
                        color: backArea.pressed ? Theme.Palette.surface_container_highest
                            : backArea.containsMouse ? Theme.Palette.surface_container_high
                            : Theme.Palette.surface_container
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "‹"
                            color: Theme.Palette.on_surface
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Math.round(22 * root.s)
                        }

                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.play("click")
                            onClicked: root.page = ""
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: subPage.shown === "wifi" ? "Wi-Fi" : "Bluetooth"
                        color: Theme.Palette.on_surface
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(18 * root.s)
                    }
                }

                // Wi-Fi: текущая сеть, сохранённые, остальные, кнопка поиска.
                Item {
                    anchors.top: subHeader.bottom
                    anchors.topMargin: 16 * root.s
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: subPage.shown === "wifi"

                    Text {
                        visible: !root.wifiOn
                        text: !root.wifiDevice ? "Нет Wi-Fi адаптера" : "Wi-Fi выключен"
                        color: Theme.Palette.on_surface_variant
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(13 * root.s)
                    }

                    Flickable {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: wifiRescan.top
                        anchors.bottomMargin: 12 * root.s
                        visible: root.wifiOn
                        clip: true
                        contentHeight: wifiList.height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: wifiList
                            width: parent.width
                            spacing: 10 * root.s

                            Repeater {
                                model: root.wifiDevice ? root.wifiDevice.networks : null
                                NetworkCard { s: root.s; visible: modelData.connected }
                            }

                            Text {
                                topPadding: 6 * root.s
                                text: "Другие сети"
                                color: Theme.Palette.on_surface
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Math.round(16 * root.s)
                            }

                            // Сначала сохранённые, затем остальные; сети без имени не показываем.
                            Repeater {
                                model: root.wifiDevice ? root.wifiDevice.networks : null
                                NetworkCard { s: root.s; visible: !modelData.connected && modelData.known && modelData.name !== "" }
                            }

                            Repeater {
                                model: root.wifiDevice ? root.wifiDevice.networks : null
                                NetworkCard { s: root.s; visible: !modelData.connected && !modelData.known && modelData.name !== "" }
                            }

                            Text {
                                visible: root.wifiOthersCount === 0
                                text: root.wifiDevice && root.wifiDevice.scannerEnabled ? "Поиск сетей…" : "Нет сетей"
                                color: Theme.Palette.on_surface_variant
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Math.round(12 * root.s)
                            }
                        }
                    }

                    ActionRow {
                        id: wifiRescan
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        s: root.s
                        width: 150 * root.s
                        enabled: root.wifiOn
                        labels: [root.wifiDevice && root.wifiDevice.scannerEnabled ? "Остановить поиск" : "Обновить"]
                        onActivated: root.wifiDevice.scannerEnabled = !root.wifiDevice.scannerEnabled
                    }
                }

                // Bluetooth: подключённые устройства, остальные, кнопка поиска.
                Item {
                    anchors.top: subHeader.bottom
                    anchors.topMargin: 16 * root.s
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: subPage.shown === "bluetooth"

                    Text {
                        visible: !root.btOn
                        text: !root.btAdapter ? "Нет адаптера" : "Bluetooth выключен"
                        color: Theme.Palette.on_surface_variant
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(13 * root.s)
                    }

                    Flickable {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: rescan.top
                        anchors.bottomMargin: 12 * root.s
                        visible: root.btOn
                        clip: true
                        contentHeight: btList.height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: btList
                            width: parent.width
                            spacing: 10 * root.s

                            Repeater {
                                model: root.btAdapter ? root.btAdapter.devices : null
                                DeviceCard { s: root.s; visible: modelData.connected }
                            }

                            Text {
                                topPadding: 6 * root.s
                                text: "Другие устройства"
                                color: Theme.Palette.on_surface
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Math.round(16 * root.s)
                            }

                            // Сначала сопряжённые, затем найденные поиском.
                            Repeater {
                                model: root.btAdapter ? root.btAdapter.devices : null
                                DeviceCard { s: root.s; visible: !modelData.connected && (modelData.paired || modelData.bonded) }
                            }

                            Repeater {
                                model: root.btAdapter ? root.btAdapter.devices : null
                                DeviceCard { s: root.s; visible: !modelData.connected && !modelData.paired && !modelData.bonded }
                            }

                            Text {
                                visible: root.btOthersCount === 0
                                text: root.btAdapter && root.btAdapter.discovering ? "Поиск устройств…" : "Нет устройств"
                                color: Theme.Palette.on_surface_variant
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Math.round(12 * root.s)
                            }
                        }
                    }

                    ActionRow {
                        id: rescan
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        s: root.s
                        width: 150 * root.s
                        enabled: root.btOn
                        labels: [root.btAdapter && root.btAdapter.discovering ? "Остановить поиск" : "Обновить"]
                        onActivated: root.btAdapter.discovering = !root.btAdapter.discovering
                    }
                }
            }
        }
    }

    // ---- Компоненты ----

    // Текст, который при переполнении плавно ездит влево-вправо.
    component Marquee: Item {
        id: mq
        required property real s
        property string text
        property color color
        property int pixelSize: Math.round(13 * s)
        readonly property real overflow: Math.max(0, label.implicitWidth - width)

        clip: true
        implicitHeight: label.implicitHeight

        onOverflowChanged: restartTimer.restart()
        onTextChanged: restartTimer.restart()

        Text {
            id: label
            text: mq.text
            color: mq.color
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: mq.pixelSize
        }

        // Перезапуск после того, как ширина перестала меняться.
        Timer {
            id: restartTimer
            interval: 300
            onTriggered: {
                slide.stop();
                label.x = 0;
                if (mq.overflow > 0)
                    slide.start();
            }
        }

        SequentialAnimation {
            id: slide
            loops: Animation.Infinite
            PauseAnimation { duration: 1200 }
            NumberAnimation {
                target: label; property: "x"; to: -mq.overflow
                duration: Math.max(600, mq.overflow * 30 / mq.s); easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 1200 }
            NumberAnimation {
                target: label; property: "x"; to: 0
                duration: Math.max(600, mq.overflow * 30 / mq.s); easing.type: Easing.InOutSine
            }
        }
    }

    // Плитка: основная часть — вкл/выкл, справа — кнопка разворота.
    component Tile: Item {
        id: tile
        required property real s
        property string title
        property string subtitle
        property bool active
        // Кнопка разворота справа
        property bool expandable: true
        readonly property bool down: mainArea.pressed || arrowArea.pressed
        readonly property color onColor: active ? Theme.Palette.on_primary : Theme.Palette.on_surface

        signal toggled()
        signal expand()

        height: parent.height

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius(16) * tile.s
            color: tile.active ? Theme.Palette.primary : Theme.Palette.surface_container_high
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: arrow.left

            Rectangle {
                anchors.fill: parent
                topLeftRadius: Tokens.radius(16) * tile.s
                bottomLeftRadius: Tokens.radius(16) * tile.s
                topRightRadius: tile.expandable ? 0 : Tokens.radius(16) * tile.s
                bottomRightRadius: tile.expandable ? 0 : Tokens.radius(16) * tile.s
                color: tile.onColor
                opacity: mainArea.pressed ? 0.12 : mainArea.containsMouse ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 14 * tile.s
                anchors.rightMargin: 8 * tile.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * tile.s

                Marquee {
                    s: tile.s
                    width: parent.width
                    text: tile.title
                    color: tile.onColor
                    pixelSize: Math.round(14 * tile.s)
                }
                Marquee {
                    s: tile.s
                    width: parent.width
                    text: tile.subtitle
                    color: tile.onColor
                    pixelSize: Math.round(11 * tile.s)
                    opacity: 0.8
                }
            }

            MouseArea {
                id: mainArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.toggled()
            }
        }

        Item {
            id: arrow
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: tile.expandable ? 40 * tile.s : 0
            visible: tile.expandable

            Rectangle {
                anchors.fill: parent
                topRightRadius: Tokens.radius(16) * tile.s
                bottomRightRadius: Tokens.radius(16) * tile.s
                color: tile.onColor
                opacity: arrowArea.pressed ? 0.24 : arrowArea.containsMouse ? 0.18 : 0.12
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: "›"
                color: tile.onColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(20 * tile.s)
            }

            MouseArea {
                id: arrowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tile.expand()
            }
        }
    }

    // Ряд кнопок: нажатая расширяется, соседние сжимаются (сумма ширин постоянна).
    component ActionRow: Item {
        id: actionRow
        required property real s
        property var labels: []
        property int pressedIndex: -1
        readonly property real gap: 8 * s
        readonly property real grow: 12 * s
        readonly property real base: labels.length > 0 ? (width - gap * (labels.length - 1)) / labels.length : 0

        signal activated(int index)

        height: 30 * s
        opacity: enabled ? 1 : 0.5

        function buttonWidth(i: int): real {
            if (pressedIndex < 0)
                return base;
            if (i === pressedIndex)
                return base + grow;
            return base - grow / Math.max(1, labels.length - 1);
        }

        Row {
            spacing: actionRow.gap

            Repeater {
                model: actionRow.labels

                Item {
                    id: btn
                    required property int index
                    required property string modelData
                    width: actionRow.buttonWidth(index)
                    height: actionRow.height

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.Palette.secondary_container
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Theme.Palette.on_secondary_container
                        opacity: btnArea.pressed ? 0.12 : btnArea.containsMouse ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 8 * actionRow.s
                        anchors.rightMargin: 8 * actionRow.s
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: btn.modelData
                        color: Theme.Palette.on_secondary_container
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(12 * actionRow.s)
                    }

                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressedChanged: {
                            if (pressed)
                                actionRow.pressedIndex = btn.index;
                            else if (actionRow.pressedIndex === btn.index)
                                actionRow.pressedIndex = -1;
                        }
                        // id root из inline-компонента недоступен — тот же вызов, что в root.play().
                        onPressed: if (Config.options.notiCenter.uiSounds) Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/click.wav")])
                        onClicked: actionRow.activated(btn.index)
                    }
                }
            }
        }
    }

    // Карточка Bluetooth-устройства: имя, состояние и действия.
    component DeviceCard: Rectangle {
        id: card
        required property var modelData
        required property real s
        readonly property var device: modelData
        readonly property bool known: device.paired || device.bonded

        width: parent ? parent.width : 0
        height: 64 * s
        radius: Tokens.radius(16) * s
        color: Theme.Palette.surface_container_high

        Column {
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.leftMargin: 14 * card.s
            anchors.rightMargin: 10 * card.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * card.s

            Marquee {
                s: card.s
                width: parent.width
                text: card.device.name || card.device.address
                color: Theme.Palette.on_surface
                pixelSize: Math.round(14 * card.s)
            }
            Text {
                text: card.device.pairing ? "Сопряжение…"
                    : card.device.state === BluetoothDeviceState.Connecting ? "Подключение…"
                    : card.device.state === BluetoothDeviceState.Disconnecting ? "Отключение…"
                    : card.device.connected ? (card.device.batteryAvailable
                        ? "Подключено · " + Math.round(card.device.battery * 100) + "%" : "Подключено")
                    : card.known ? "Сопряжено" : "Новое устройство"
                color: Theme.Palette.on_surface_variant
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(11 * card.s)
            }
        }

        ActionRow {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 12 * card.s
            anchors.verticalCenter: parent.verticalCenter
            s: card.s
            width: (labels.length > 1 ? 180 : 96) * card.s
            labels: card.device.pairing ? ["Отмена"]
                : card.device.connected ? ["Отключить", "Забыть"]
                : card.known ? ["Подключить", "Забыть"]
                : ["Сопрячь"]
            onActivated: index => {
                const d = card.device;
                if (d.pairing)
                    d.cancelPair();
                else if (index === 1)
                    d.forget();
                else if (d.connected)
                    d.disconnect();
                else if (card.known)
                    d.connect();
                else
                    d.pair();
            }
        }
    }

    // Карточка Wi-Fi сети: имя, состояние, действия; при необходимости — поле пароля.
    component NetworkCard: Rectangle {
        id: card
        required property var modelData
        required property real s
        readonly property var network: modelData
        readonly property bool open: network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe
        // Сети, к которым можно подключиться по паролю (connectWithPsk).
        readonly property bool needsPsk: network.security === WifiSecurityType.WpaPsk
            || network.security === WifiSecurityType.Wpa2Psk
            || network.security === WifiSecurityType.Sae
        property bool askPsk: false
        property string error: ""

        width: parent ? parent.width : 0
        height: (askPsk ? 108 : 64) * s
        radius: Tokens.radius(16) * s
        color: Theme.Palette.surface_container_high
        clip: true

        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        function connectNow(): void {
            error = "";
            if (network.known || !needsPsk)
                network.connect();
            else
                askPsk = true;
        }

        function submit(): void {
            if (psk.text === "")
                return;
            error = "";
            network.connectWithPsk(psk.text);
            askPsk = false;
        }

        onAskPskChanged: {
            if (askPsk)
                psk.forceActiveFocus();
            else
                psk.text = "";
        }

        Connections {
            target: card.network
            function onConnectionFailed(reason) {
                if (reason === ConnectionFailReason.NoSecrets && card.needsPsk) {
                    card.error = "Нужен пароль";
                    card.askPsk = true;
                } else {
                    card.error = "Не удалось подключиться";
                }
            }
            function onConnectedChanged() {
                if (card.network.connected) {
                    card.error = "";
                    card.askPsk = false;
                }
            }
        }

        Item {
            id: cardHead
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 64 * card.s

            Column {
                anchors.left: parent.left
                anchors.right: netActions.left
                anchors.leftMargin: 14 * card.s
                anchors.rightMargin: 10 * card.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * card.s

                Marquee {
                    s: card.s
                    width: parent.width
                    text: card.network.name
                    color: Theme.Palette.on_surface
                    pixelSize: Math.round(14 * card.s)
                }
                Text {
                    text: card.network.state === ConnectionState.Connecting ? "Подключение…"
                        : card.network.state === ConnectionState.Disconnecting ? "Отключение…"
                        : card.error !== "" ? card.error
                        : (card.network.connected ? "Подключено"
                            : card.network.known ? "Сохранена"
                            : card.open ? "Открытая" : "Защищённая")
                            + " · " + Math.round(card.network.signalStrength * 100) + "%"
                    color: card.error !== "" ? Theme.Palette.error : Theme.Palette.on_surface_variant
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(11 * card.s)
                }
            }

            ActionRow {
                id: netActions
                anchors.right: parent.right
                anchors.rightMargin: 12 * card.s
                anchors.verticalCenter: parent.verticalCenter
                s: card.s
                width: (labels.length > 1 ? 180 : 96) * card.s
                labels: card.network.connected ? ["Отключить", "Забыть"]
                    : card.network.known ? ["Подключить", "Забыть"]
                    : ["Подключить"]
                onActivated: index => {
                    if (index === 1)
                        card.network.forget();
                    else if (card.network.connected)
                        card.network.disconnect();
                    else
                        card.connectNow();
                }
            }
        }

        // Поле пароля
        Item {
            anchors.top: cardHead.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12 * card.s
            anchors.rightMargin: 12 * card.s
            height: 30 * card.s
            opacity: card.askPsk ? 1 : 0
            visible: opacity > 0

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: pskActions.left
                anchors.rightMargin: 8 * card.s
                height: parent.height
                radius: height / 2
                color: Theme.Palette.surface_container_highest
                border.width: psk.activeFocus ? 1 : 0
                border.color: Theme.Palette.primary

                TextInput {
                    id: psk
                    anchors.fill: parent
                    anchors.leftMargin: 12 * card.s
                    anchors.rightMargin: 12 * card.s
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    clip: true
                    color: Theme.Palette.on_surface
                    selectionColor: Theme.Palette.primary
                    selectedTextColor: Theme.Palette.on_primary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(12 * card.s)
                    onAccepted: card.submit()
                    Keys.onEscapePressed: card.askPsk = false
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * card.s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: psk.text === ""
                    text: "Пароль"
                    color: Theme.Palette.on_surface_variant
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(12 * card.s)
                }
            }

            ActionRow {
                id: pskActions
                anchors.right: parent.right
                s: card.s
                width: 150 * card.s
                labels: ["Отмена", "Ввод"]
                onActivated: index => {
                    if (index === 0)
                        card.askPsk = false;
                    else
                        card.submit();
                }
            }
        }
    }

    // Ползунок-«таблетка» с подписью и процентом.
    component Pill: Item {
        id: pill
        required property real s
        property string label
        property real value: 0
        property bool available: true

        signal moved(real v)
        signal scrolled()

        height: 30 * s
        opacity: available ? 1 : 0.5

        function emitAt(x: real): void {
            pill.moved(Math.max(0, Math.min(1, x / width)));
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.Palette.surface_container_high
        }

        Rectangle {
            height: parent.height
            width: height + (parent.width - height) * pill.value
            radius: height / 2
            color: Theme.Palette.primary_container
            Behavior on width {
                enabled: !area.pressed
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.Palette.on_surface
            opacity: area.pressed ? 0.12 : area.containsMouse ? 0.06 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12 * pill.s
            anchors.verticalCenter: parent.verticalCenter
            text: pill.label
            color: Theme.Palette.on_primary_container
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(13 * pill.s)
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12 * pill.s
            anchors.verticalCenter: parent.verticalCenter
            text: pill.available ? Math.round(pill.value * 100) + "%" : "—"
            color: Theme.Palette.on_surface_variant
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(12 * pill.s)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            enabled: pill.available
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => pill.emitAt(mouse.x)
            onPositionChanged: mouse => { if (pressed) pill.emitAt(mouse.x); }
            onWheel: wheel => {
                pill.moved(Math.max(0, Math.min(1, pill.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))));
                pill.scrolled();
            }
        }
    }
}
