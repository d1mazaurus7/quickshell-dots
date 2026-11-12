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
import "controls"
import "controls/Icons.js" as Icons
import "widgets/Registry.js" as Registry

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
    // Сервис записи экрана (services/recorder/Recorder.qml)
    property var recorderService: null
    // Сервис скриншотов (services/screenshot/Screenshot.qml)
    property var screenshotService: null

    readonly property var cfg: Config.options.notiCenter
    property int panelWidth: cfg.width
    // Масштаб всех размеров (не зависит от ширины панели)
    readonly property real s: cfg.scale

    signal openOutputRequested(string name)

    readonly property bool open: openOutput !== "" && openOutput === screen.name
    // Место в баре под панель (вместе с левым «ухом»).
    readonly property real fullReserve: dropdown.contentWidth + dropdown.ear
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

    // Закрыть центр и выполнить fn, когда панель скроется (чтобы не попала в кадр)
    property var afterHide: null
    function runHidden(fn: var): void {
        afterHide = fn;
        openOutputRequested("");
    }
    onShownChanged: {
        if (shown || !afterHide)
            return;
        const fn = afterHide;
        afterHide = null;
        fn();
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
        else {
            page = "";
            editing = false;
        }
        // Центр открыт снова до скрытия — действие отменяется
        if (open)
            afterHide = null;
    }

    // Режим редактирования виджетов
    property bool editing: false
    // Каталог виджетов с полными путями
    readonly property var catalog: Registry.widgets.map(w => Object.assign({ url: Qt.resolvedUrl("widgets/" + w.source) }, w))

    LayoutState { id: layout }

    // ---- Состояние: Wi-Fi ----

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wifiOn: !!wifiDevice && Networking.wifiEnabled
    // Подключённый Ethernet (приоритетнее Wi-Fi в плитке)
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.nmManaged && d.connected) ?? null
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
    readonly property date now: clock.date

    // Внутренняя страница (заглушка): "", "wifi", "bluetooth", "recorder", "screenshot" или "note".
    property string page: ""
    // Дата открытой заметки календаря
    property date noteDate: new Date()

    NotesState { id: noteStore }
    ReminderState {
        id: reminderStore
        // Уведомления отправляет один экземпляр
        scheduler: root.ipcEnabled
        dnd: root.notifications.dnd
    }

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

                // Кнопки: настройки и редактор виджетов
                Item {
                    width: parent.width
                    height: 44 * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.editing ? 1 : 0
                        visible: opacity > 0
                        text: "Виджеты"
                        color: Theme.Palette.on_surface
                        font.family: Tokens.typography.family
                        font.pixelSize: Math.round(16 * root.s)
                        Behavior on opacity { Smooth {} }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8 * root.s

                        IconButton {
                            s: root.s
                            icon: Icons.settings
                            color: Theme.Palette.surface_container_high
                            onClicked: {
                                root.play("click");
                                Quickshell.execDetached(["qs", "ipc", "call", "settings", "open"]);
                                root.openOutputRequested("");
                            }
                        }

                        IconButton {
                            s: root.s
                            icon: root.editing ? Icons.check : Icons.edit
                            checked: root.editing
                            color: checked ? Theme.Palette.primary : Theme.Palette.surface_container_high
                            contentColor: checked ? Theme.Palette.on_primary : Theme.Palette.on_surface
                            onClicked: {
                                root.play("click");
                                root.editing = !root.editing;
                            }
                        }
                    }
                }

                WidgetGrid {
                    width: parent.width
                    s: root.s
                    model: layout.model
                    catalog: root.catalog
                    ctx: root
                    rowHeight: root.cfg.widgetHeight * root.s
                    editing: root.editing
                    onEdited: layout.save()
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
                anchors.bottom: calendarSlot.top

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
                    font.family: Tokens.typography.family
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
                    font.family: Tokens.typography.family
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
                    // Пока карточку смахивают, список не перехватывает вертикальное движение курсора.
                    interactive: notiArea.swipeGroup.activeIndex < 0

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

            // Календарь под уведомлениями: при выключении плавно сворачивается
            Item {
                id: calendarSlot
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.cfg.showCalendar ? calendar.implicitHeight + 16 * root.s : 0
                opacity: root.cfg.showCalendar ? 1 : 0
                visible: height > 0
                clip: true
                Behavior on height { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                Calendar {
                    id: calendar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    s: root.s
                    today: clock.date
                    arrowsSide: root.cfg.calendarArrows
                    notes: noteStore.notes
                    onStepped: root.play("click")
                    onDayClicked: date => {
                        root.play("click");
                        root.noteDate = date;
                        root.page = "note";
                    }

                    // При закрытии панели возвращаемся к текущему месяцу
                    Connections {
                        target: root
                        function onOpenChanged() {
                            if (!root.open)
                                calendar.offset = 0;
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
                            font.family: Tokens.typography.family
                            font.pixelSize: Math.round(22 * root.s)
                        }

                        MouseArea {
                            id: backArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: root.play("click")
                            onClicked: {
                                if (subPage.shown === "note")
                                    notePage.back();
                                else
                                    root.page = "";
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: subPage.shown === "wifi" ? "Wi-Fi"
                            : subPage.shown === "note" ? root.noteDate.toLocaleDateString(Qt.locale(), "d MMMM yyyy")
                            : subPage.shown === "recorder" ? "Запись"
                            : subPage.shown === "screenshot" ? "Скриншот"
                            : "Bluetooth"
                        color: Theme.Palette.on_surface
                        font.family: Tokens.typography.family
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
                        font.family: Tokens.typography.family
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
                                font.family: Tokens.typography.family
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
                                font.family: Tokens.typography.family
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
                        font.family: Tokens.typography.family
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
                                font.family: Tokens.typography.family
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
                                font.family: Tokens.typography.family
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
                // Настройки записи экрана
                Loader {
                    id: recorderPage
                    anchors.top: subHeader.bottom
                    anchors.topMargin: 16 * root.s
                    anchors.left: parent.left
                    anchors.right: parent.right
                    active: subPage.shown === "recorder"
                    visible: active
                    sourceComponent: RecorderPage { ctx: root }
                    onLoaded: item.refresh()
                }

                // Настройки скриншотов
                Loader {
                    anchors.top: subHeader.bottom
                    anchors.topMargin: 16 * root.s
                    anchors.left: parent.left
                    anchors.right: parent.right
                    active: subPage.shown === "screenshot"
                    visible: active
                    sourceComponent: ScreenshotPage { ctx: root }
                }

                // День календаря: выбор (напоминание / заметка), затем экран выбранного.
                // Экраны (ModePane) сменяются плавно: прозрачность и небольшой сдвиг.
                Item {
                    id: notePage
                    anchors.top: subHeader.bottom
                    anchors.topMargin: 16 * root.s
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: subPage.shown === "note"

                    readonly property var note: noteStore.notes[noteStore.key(root.noteDate)] ?? null
                    readonly property var dayReminders: reminderStore.forDay(root.noteDate)
                    // "menu" | "view" | "edit" | "reminder" (текст) | "time" (время напоминания)
                    property string mode: "menu"
                    readonly property bool editing: mode === "edit"

                    function remind(): void {
                        reminderEditor.text = "";
                        mode = "reminder";
                        reminderEditor.forceActiveFocus();
                    }

                    // Барабаны прокручиваются к текущему времени
                    function pickTime(): void {
                        reminderEditor.focus = false;
                        const now = new Date();
                        hourDrum.value = now.getHours();
                        minuteDrum.value = now.getMinutes();
                        secondDrum.value = 0;
                        mode = "time";
                    }

                    function dueDate(): date {
                        return new Date(root.noteDate.getFullYear(), root.noteDate.getMonth(), root.noteDate.getDate(),
                            hourDrum.value, minuteDrum.value, secondDrum.value);
                    }

                    function edit(): void {
                        editor.text = note ? note.text : "";
                        mode = "edit";
                        editor.cursorPosition = editor.length;
                        editor.forceActiveFocus();
                    }

                    function openNote(): void {
                        if (note)
                            mode = "view";
                        else
                            edit();
                    }

                    // Шаг назад внутри страницы; из меню — закрыть страницу
                    function back(): void {
                        editor.focus = false;
                        reminderEditor.focus = false;
                        if (mode === "menu")
                            root.page = "";
                        else if (mode === "time") {
                            mode = "reminder";
                            reminderEditor.forceActiveFocus();
                        } else
                            mode = "menu";
                    }

                    Connections {
                        target: root
                        function onPageChanged() {
                            if (root.page === "note")
                                notePage.mode = "menu";
                        }
                    }

                    // Выбор действия для дня
                    ModePane {
                        active: notePage.mode === "menu"
                        s: root.s

                    Column {
                        width: parent.width
                        spacing: 10 * root.s

                        Repeater {
                            model: [
                                { action: "reminder", icon: "󰂚", title: "Добавить напоминание",
                                  subtitle: notePage.dayReminders.length > 0
                                      ? notePage.dayReminders.map(r => Qt.formatTime(new Date(r.due), "HH:mm:ss")).join(", ")
                                      : "Уведомление в выбранное время" },
                                { action: "note", icon: "󰏫", title: notePage.note ? "Заметка" : "Добавить заметку",
                                  subtitle: notePage.note ? "Открыть заметку на этот день" : "Текст на этот день" }
                            ].filter(c => c.action !== "reminder" || root.cfg.reminders)

                            Rectangle {
                                id: choice
                                required property var modelData
                                width: parent.width
                                height: 64 * root.s
                                radius: 16 * root.s
                                color: choiceArea.pressed ? Theme.Palette.surface_container_highest
                                    : choiceArea.containsMouse ? Theme.Palette.surface_container_high
                                    : Theme.Palette.surface_container
                                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                                Rectangle {
                                    id: choiceIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 40 * root.s
                                    height: width
                                    radius: 12 * root.s
                                    color: Theme.Palette.secondary_container

                                    Text {
                                        anchors.centerIn: parent
                                        text: choice.modelData.icon
                                        color: Theme.Palette.on_secondary_container
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Math.round(20 * root.s)
                                    }
                                }

                                Column {
                                    anchors.left: choiceIcon.right
                                    anchors.leftMargin: 12 * root.s
                                    anchors.right: parent.right
                                    anchors.rightMargin: 12 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2 * root.s

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: choice.modelData.title
                                        color: Theme.Palette.on_surface
                                        font.family: Tokens.typography.family
                                        font.pixelSize: Math.round(14 * root.s)
                                    }
                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: choice.modelData.subtitle
                                        color: Theme.Palette.on_surface_variant
                                        font.family: Tokens.typography.family
                                        font.pixelSize: Math.round(11 * root.s)
                                    }
                                }

                                MouseArea {
                                    id: choiceArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: root.play("click")
                                    onClicked: {
                                        if (choice.modelData.action === "reminder")
                                            notePage.remind();
                                        else
                                            notePage.openNote();
                                    }
                                }
                            }
                        }
                    }
                    }

                    // Напоминание: текст
                    ModePane {
                        active: notePage.mode === "reminder"
                        s: root.s

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: reminderActions.top
                            anchors.bottomMargin: 12 * root.s
                            radius: 16 * root.s
                            color: Theme.Palette.surface_container
                            border.width: reminderEditor.activeFocus ? 1 : 0
                            border.color: Theme.Palette.primary

                            Flickable {
                                id: reminderFlick
                                anchors.fill: parent
                                anchors.margins: 14 * root.s
                                clip: true
                                contentHeight: reminderEditor.height
                                boundsBehavior: Flickable.StopAtBounds

                                TextEdit {
                                    id: reminderEditor
                                    width: reminderFlick.width
                                    height: Math.max(implicitHeight, reminderFlick.height)
                                    wrapMode: TextEdit.Wrap
                                    color: Theme.Palette.on_surface
                                    selectionColor: Theme.Palette.primary
                                    selectedTextColor: Theme.Palette.on_primary
                                    font.family: Tokens.typography.family
                                    font.pixelSize: Math.round(13 * root.s)
                                    onCursorRectangleChanged: {
                                        const r = cursorRectangle;
                                        if (reminderFlick.contentY > r.y)
                                            reminderFlick.contentY = r.y;
                                        else if (reminderFlick.contentY + reminderFlick.height < r.y + r.height)
                                            reminderFlick.contentY = r.y + r.height - reminderFlick.height;
                                    }
                                    onTextChanged: if (activeFocus && Config.options.sound.interactionSounds)
                                        Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.typeSound)])

                                    Text {
                                        visible: reminderEditor.text === ""
                                        text: "О чём напомнить"
                                        color: Theme.Palette.on_surface_variant
                                        font: reminderEditor.font
                                    }
                                }
                            }
                        }

                        ActionRow {
                            id: reminderActions
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            s: root.s
                            width: 200 * root.s
                            labels: ["Отмена", "Записать"]
                            onActivated: index => {
                                if (index === 1 && reminderEditor.text.trim() !== "")
                                    notePage.pickTime();
                                else if (index === 0)
                                    notePage.back();
                            }
                        }
                    }

                    // Напоминание: время на барабанах
                    ModePane {
                        active: notePage.mode === "time"
                        s: root.s

                        Column {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -reminderApply.height
                            spacing: 18 * root.s

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Время напоминания"
                                color: Theme.Palette.on_surface
                                font.family: Tokens.typography.family
                                font.pixelSize: Math.round(16 * root.s)
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 14 * root.s

                                // Щелчок на каждое число; при подстановке времени в pickTime() тихо
                                TimeDrum { id: hourDrum; s: root.s; count: 24; onTicked: if (notePage.mode === "time") root.play("button") }
                                TimeDrum { id: minuteDrum; s: root.s; count: 60; onTicked: if (notePage.mode === "time") root.play("button") }
                                TimeDrum { id: secondDrum; s: root.s; count: 60; onTicked: if (notePage.mode === "time") root.play("button") }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                // Привязка к clock.date: отсчёт обновляется каждую секунду
                                readonly property real secondsLeft: notePage.mode === "time"
                                    ? Math.ceil((notePage.dueDate() - clock.date) / 1000) : 0
                                text: {
                                    if (secondsLeft <= 0)
                                        return "Время прошло — напомню сразу";
                                    const parts = [];
                                    // На сегодня — без дней
                                    if (root.noteDate.toDateString() !== clock.date.toDateString())
                                        parts.push(Math.floor(secondsLeft / 86400) + " дн");
                                    parts.push(Math.floor(secondsLeft % 86400 / 3600) + " ч",
                                        Math.floor(secondsLeft % 3600 / 60) + " мин",
                                        secondsLeft % 60 + " сек");
                                    return "Через " + parts.join(", ");
                                }
                                color: Theme.Palette.on_surface_variant
                                font.family: Tokens.typography.family
                                font.pixelSize: Math.round(11 * root.s)
                            }
                        }

                        ActionRow {
                            id: reminderApply
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            s: root.s
                            width: 200 * root.s
                            labels: ["Назад", "Применить"]
                            onActivated: index => {
                                if (index === 0) {
                                    notePage.back();
                                    return;
                                }
                                reminderStore.add(notePage.dueDate(), reminderEditor.text.trim());
                                notePage.mode = "menu";
                            }
                        }
                    }

                    // Заметка: просмотр или редактирование
                    ModePane {
                        active: notePage.mode === "view" || notePage.mode === "edit"
                        s: root.s

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: edited.top
                            anchors.bottomMargin: 10 * root.s
                            radius: 16 * root.s
                            color: Theme.Palette.surface_container
                            border.width: editor.activeFocus ? 1 : 0
                            border.color: Theme.Palette.primary

                            Flickable {
                                id: noteFlick
                                anchors.fill: parent
                                anchors.margins: 14 * root.s
                                clip: true
                                contentHeight: notePage.editing ? editor.height : viewText.height
                                boundsBehavior: Flickable.StopAtBounds

                                // Каретка не уходит за видимую область
                                function ensureVisible(r: rect): void {
                                    if (contentY > r.y)
                                        contentY = r.y;
                                    else if (contentY + height < r.y + r.height)
                                        contentY = r.y + r.height - height;
                                }

                                Text {
                                    id: viewText
                                    width: noteFlick.width
                                    visible: !notePage.editing
                                    text: notePage.note ? notePage.note.text : ""
                                    wrapMode: Text.Wrap
                                    color: Theme.Palette.on_surface
                                    font.family: Tokens.typography.family
                                    font.pixelSize: Math.round(13 * root.s)
                                }

                                TextEdit {
                                    id: editor
                                    width: noteFlick.width
                                    height: Math.max(implicitHeight, noteFlick.height)
                                    visible: notePage.editing
                                    wrapMode: TextEdit.Wrap
                                    color: Theme.Palette.on_surface
                                    selectionColor: Theme.Palette.primary
                                    selectedTextColor: Theme.Palette.on_primary
                                    font.family: Tokens.typography.family
                                    font.pixelSize: Math.round(13 * root.s)
                                    onCursorRectangleChanged: noteFlick.ensureVisible(cursorRectangle)
                                    // Звук печати только от ввода, не от подстановки текста
                                    onTextChanged: if (activeFocus && Config.options.sound.interactionSounds)
                                        Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.typeSound)])

                                    Text {
                                        visible: editor.text === ""
                                        text: "Текст заметки"
                                        color: Theme.Palette.on_surface_variant
                                        font: editor.font
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                visible: !notePage.editing
                                cursorShape: Qt.IBeamCursor
                                onDoubleClicked: notePage.edit()
                            }
                        }

                        Text {
                            id: edited
                            anchors.left: parent.left
                            anchors.bottom: noteActions.top
                            anchors.bottomMargin: 12 * root.s
                            text: notePage.note
                                ? "Изменено " + new Date(notePage.note.edited).toLocaleString(Qt.locale(), "d MMMM yyyy, HH:mm")
                                : "Новая заметка"
                            color: Theme.Palette.on_surface_variant
                            font.family: Tokens.typography.family
                            font.pixelSize: Math.round(11 * root.s)
                        }

                        ActionRow {
                            id: noteActions
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            s: root.s
                            width: (notePage.editing ? 200 : 110) * root.s
                            labels: notePage.editing ? ["Отмена", "Записать"] : ["Изменить"]
                            onActivated: index => {
                                if (!notePage.editing) {
                                    notePage.edit();
                                    return;
                                }
                                editor.focus = false;
                                if (index === 1)
                                    noteStore.save(root.noteDate, editor.text);
                                // Пустая заметка удалена, новая отменена — назад к выбору
                                notePage.mode = notePage.note ? "view" : "menu";
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Компоненты ----

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
                        font.family: Tokens.typography.family
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
                font.family: Tokens.typography.family
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
                    font.family: Tokens.typography.family
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
                    font.family: Tokens.typography.family
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
                    font.family: Tokens.typography.family
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
}
