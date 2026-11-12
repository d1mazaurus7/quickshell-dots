pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../shell/theme"
import "../controls"
import "../clock"

// Таймер: выбор времени барабанами (часы, минуты, секунды), обратный отсчёт и звонок
// из assets/sounds/timer (первый найденный файл). Кнопки: старт/пауза, заново, стоп
Item {
    id: root

    property var settings: ({})
    property bool editing: false

    readonly property bool transparent: settings.transparentBackground === true
    readonly property bool outline: transparent && settings.outline === true
    // При прозрачном фоне: окно размывает всё под карточкой
    readonly property Item blurItem: transparent && settings.backgroundBlur === true ? card : null
    readonly property color textColor: settings.whiteText === true ? "#ffffff" : Tokens.colors.primary
    readonly property bool seconds: settings.showSeconds === true
    readonly property bool millis: seconds && settings.showMilliseconds === true

    // idle — выбор времени, running, paused, finished — время вышло (звонок)
    property string phase: "idle"
    // Заданное время и остаток, мс
    property real setMs: 0
    property real remaining: 0
    property real endAt: 0
    // Направление slide: -1 — отсчёт вниз, 1 — время увеличилось (заново)
    property int direction: -1

    readonly property real pickedMs: (hoursDrum.value * 3600 + minutesDrum.value * 60 + secondsDrum.value) * 1000

    function start(): void {
        if (phase === "idle") {
            if (pickedMs <= 0)
                return;
            setMs = pickedMs;
            direction = -1;
            remaining = setMs;
        }
        endAt = Date.now() + remaining;
        phase = "running";
    }
    function pause(): void {
        tick();
        if (phase === "running")
            phase = "paused";
    }
    function restart(): void {
        ring.running = false;
        direction = 1;
        remaining = setMs;
        endAt = Date.now() + remaining;
        if (phase === "finished")
            phase = "paused";
    }
    function stop(): void {
        ring.running = false;
        phase = "idle";
    }
    function tick(): void {
        const left = Math.max(0, endAt - Date.now());
        direction = -1;
        remaining = left;
        if (left <= 0) {
            phase = "finished";
            const file = sounds.count > 0 ? sounds.get(0, "fileName") : "";
            if (file !== "") {
                ring.command = ["pw-play", Quickshell.shellPath("assets/sounds/timer/" + file)];
                ring.running = true;
            }
        }
    }

    Timer {
        interval: root.millis ? 16 : 100
        repeat: true
        running: root.phase === "running"
        onTriggered: root.tick()
    }

    FolderListModel {
        id: sounds
        folder: Qt.resolvedUrl("../../assets/sounds/timer")
        nameFilters: ["*.wav", "*.ogg", "*.oga", "*.flac", "*.mp3"]
        showDirs: false
    }
    Process {
        id: ring
    }

    // Отображение остатка: без секунд — «ЧЧ:ММ» с округлением вверх,
    // с секундами — «ММ:СС» (часы — если заданы), миллисекунды — сотые после точки
    function pad(n: int): string {
        return n < 10 ? "0" + n : String(n);
    }
    readonly property var groups: {
        if (!seconds) {
            const min = Math.ceil(remaining / 60000);
            return [pad(Math.floor(min / 60)), pad(min % 60)];
        }
        const sec = millis ? Math.floor(remaining / 1000) : Math.ceil(remaining / 1000);
        const list = [pad(Math.floor(sec / 60) % 60), pad(sec % 60)];
        if (setMs >= 3600000)
            list.unshift(pad(Math.floor(sec / 3600)));
        return list;
    }
    readonly property string centis: pad(Math.floor(remaining % 1000 / 10))

    // Метрики на базовом размере 100 px: из них считается масштаб под область
    readonly property real msScale: 0.55
    readonly property font baseFont: Qt.font({ family: Tokens.typography.family, pixelSize: 100 })
    FontMetrics {
        id: baseMetrics
        font: root.baseFont
    }
    readonly property real baseDigitW: baseMetrics.font, Math.max(...("0123456789".split("").map(c => baseMetrics.advanceWidth(c))))
    readonly property real baseSepW: baseMetrics.font, baseMetrics.advanceWidth(":")
    readonly property real baseDotW: baseMetrics.font, baseMetrics.advanceWidth(".")
    readonly property real baseCapH: baseMetrics.font, baseMetrics.tightBoundingRect("0").height
    readonly property real baseSlotH: baseCapH * 1.3

    readonly property int count: groups.length
    readonly property real contentBaseW: count * 2 * baseDigitW + (count - 1) * baseSepW
        + (millis ? (baseDotW + 2 * baseDigitW) * msScale : 0)
    readonly property real fit: Math.max(0.08, Math.min(
        content.width / Math.max(1, contentBaseW),
        content.height / Math.max(1, baseSlotH)))

    readonly property font timeFont: Qt.font({ family: Tokens.typography.family, pixelSize: Math.max(8, Math.floor(100 * fit)) })
    readonly property font msFont: Qt.font({ family: Tokens.typography.family, pixelSize: Math.max(6, Math.floor(100 * fit * msScale)) })
    readonly property real slotH: baseSlotH * fit
    readonly property real capH: baseCapH * fit

    readonly property int btnSize: Math.max(16, Math.min(Tokens.scaled(44), height * 0.24,
        (width - 2 * Tokens.spacingMedium - 2 * Tokens.spacingSmall) / 3))

    WidgetCard {
        id: card
        anchors.fill: parent
        // Блюр — с лёгким затемнением, как у виджетов потребления (SysmonWidget)
        color: root.blurItem ? Qt.alpha(Tokens.colors.surface_container, 0.25)
            : root.transparent ? "transparent" : Tokens.colors.surface_container
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

        Item {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: buttons.top
            anchors.margins: Tokens.spacingMedium

            // Выбор времени
            Row {
                id: picker
                // Базовый размер ряда: 3 барабана по 96 и 2 промежутка по 12, высота 192
                readonly property real s: Math.max(0.1, Math.min(content.width / 312, content.height / 192))
                anchors.centerIn: parent
                spacing: 12 * s
                opacity: root.phase === "idle" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                TimerDrum {
                    id: hoursDrum
                    s: picker.s
                    count: 24
                    label: "ч"
                    textColor: root.textColor
                    transparent: root.transparent
                    outline: root.outline
                }
                TimerDrum {
                    id: minutesDrum
                    s: picker.s
                    count: 60
                    label: "мин"
                    textColor: root.textColor
                    transparent: root.transparent
                    outline: root.outline
                }
                TimerDrum {
                    id: secondsDrum
                    s: picker.s
                    count: 60
                    label: "с"
                    textColor: root.textColor
                    transparent: root.transparent
                    outline: root.outline
                }
            }

            // Оставшееся время
            Row {
                id: display
                anchors.centerIn: parent
                opacity: root.phase === "idle" ? 0 : 1
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                // Время вышло — цифры мягко пульсируют
                SequentialAnimation on scale {
                    running: root.phase === "finished"
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { from: 1; to: 1.06; duration: 400; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.06; to: 1; duration: 400; easing.type: Easing.InOutSine }
                }

                Repeater {
                    model: root.count

                    Row {
                        id: group
                        required property int index
                        readonly property string text: root.groups[index] ?? "00"

                        ClockGlyph {
                            visible: group.index > 0
                            width: root.baseSepW * root.fit
                            height: root.slotH
                            value: ":"
                            font: root.timeFont
                            color: root.textColor
                            capHeight: root.capH
                            animated: false

                            SequentialAnimation on opacity {
                                running: root.settings.blinkSeparator === true && root.phase === "running"
                                loops: Animation.Infinite
                                alwaysRunToEnd: true
                                NumberAnimation { from: 1; to: 0.2; duration: 500; easing.type: Easing.InOutSine }
                                NumberAnimation { from: 0.2; to: 1; duration: 500; easing.type: Easing.InOutSine }
                            }
                        }
                        Repeater {
                            model: 2

                            ClockGlyph {
                                required property int index
                                width: root.baseDigitW * root.fit
                                height: root.slotH
                                value: group.text.charAt(index)
                                font: root.timeFont
                                color: root.textColor
                                capHeight: root.capH
                                animated: root.settings.smoothChange === true
                                direction: root.direction
                            }
                        }
                    }
                }

                // Сотые: меньший шрифт на общей базовой линии, без slide (меняются каждый кадр)
                ClockGlyph {
                    visible: root.millis
                    width: root.baseDotW * root.fit * root.msScale
                    height: root.slotH
                    value: "."
                    font: root.msFont
                    color: root.textColor
                    capHeight: root.capH
                    animated: false
                }
                Repeater {
                    model: root.millis ? 2 : 0

                    ClockGlyph {
                        required property int index
                        width: root.baseDigitW * root.fit * root.msScale
                        height: root.slotH
                        value: root.centis.charAt(index)
                        font: root.msFont
                        color: root.textColor
                        capHeight: root.capH
                        animated: false
                    }
                }
            }
        }

        Row {
            id: buttons
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.spacingMediumV
            spacing: Tokens.spacingSmall

            Btn {
                icon: root.phase === "running" ? "pause" : "play_arrow"
                checked: !root.transparent
                enabled: root.phase === "idle" ? root.pickedMs > 0 : root.phase !== "finished"
                onClicked: root.phase === "running" ? root.pause() : root.start()
            }
            Btn {
                icon: "restart_alt"
                enabled: root.phase !== "idle"
                onClicked: root.restart()
            }
            Btn {
                icon: "stop"
                enabled: root.phase !== "idle"
                onClicked: root.stop()
            }
        }
    }

    // Кнопка: при прозрачном фоне — без заливки, с мягкой белой обводкой (если включена)
    component Btn: IconButton {
        size: root.btnSize
        color: root.transparent ? "transparent" : checked ? Tokens.colors.primary : Tokens.colors.surface_container_highest
        border.width: root.outline ? Math.max(1, Tokens.scaled(1.5)) : 0
        border.color: Qt.alpha("#ffffff", 0.45)
    }
}
