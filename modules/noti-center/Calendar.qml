pragma ComponentBehavior: Bound
import QtQuick
import "../../theme" as Theme
import "../../shell/theme"

// Календарь в стиле Material 3 date picker: заголовок с выбранной датой,
// переключатель месяц/список месяцев, стрелки и сетка дней.
Rectangle {
    id: cal

    required property real s
    // Текущая дата (от SystemClock владельца)
    required property date today
    // Сторона стрелок переключения месяца: "right" | "left"
    property string arrowsSide: "right"
    // Сдвиг отображаемого месяца относительно текущего
    property int offset: 0
    // Заметки по датам "yyyy-MM-dd" (NotesState.notes): у таких дней точка
    property var notes: ({})
    // Выбранный день (null — сегодня)
    property var selected: null
    // Режим выбора месяца вместо сетки дней
    property bool monthView: false

    signal stepped()
    signal dayClicked(date date)

    readonly property real pad: 12 * s
    readonly property real gap: 6 * s
    readonly property real cell: (width - pad * 2) / 7
    readonly property real rowH: Math.min(cell, 44 * s)
    readonly property real dot: rowH - 4 * s
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property date shown: selected ?? today
    // Сколько дней предыдущего месяца в первой строке
    readonly property int lead: (month.getDay() - Qt.locale().firstDayOfWeek + 7) % 7

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function cap(str: string): string {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    function goTo(newOffset: int): void {
        if (newOffset === offset)
            return;
        slide.from = newOffset > offset ? 12 * s : -12 * s;
        offset = newOffset;
        shift.restart();
        stepped();
    }

    implicitHeight: content.height + pad * 2
    radius: 16 * s
    color: Theme.Palette.surface_container

    // Круглая иконка-кнопка: hover-слой, сдвиг/увеличение иконки, disabled 38%
    component RoundIcon: Item {
        id: btn
        property string glyph
        // Направление сдвига иконки при hover (0 — увеличение)
        property int nudge: 0
        signal clicked()

        width: 36 * cal.s
        height: width
        opacity: enabled ? 1 : 0.38
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.Palette.on_surface
            opacity: area.pressed ? 0.12 : area.containsMouse ? 0.08 : 0
            scale: area.pressed ? 0.9 : 1
            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        }

        // Позиция через x: transform внутри inline-компонента ломает загрузку типа
        Text {
            x: (parent.width - width) / 2 + (area.containsMouse ? btn.nudge * 2 * cal.s : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: btn.glyph
            color: Theme.Palette.on_surface_variant
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(20 * cal.s)
            scale: area.pressed ? 0.85 : area.containsMouse && btn.nudge === 0 ? 1.12 : 1
            Behavior on x { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutBack } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: btn.clicked()
        }
    }

    // Текст, который при смене значения уходит вверх и появляется снизу
    component FadeText: Item {
        id: ft
        property string text
        property alias color: label.color
        property alias font: label.font
        property real lift: 0

        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight
        width: implicitWidth
        height: implicitHeight

        Text {
            id: label
            y: ft.lift
            font.family: Tokens.typography.family
        }

        // Старый текст уходит вверх, новый подменяется в середине и выходит снизу
        onTextChanged: if (label.text !== "") swap.restart()
        Component.onCompleted: label.text = text

        SequentialAnimation {
            id: swap
            ParallelAnimation {
                NumberAnimation { target: label; property: "opacity"; to: 0; duration: Tokens.animationFast / 2; easing.type: Easing.InCubic }
                NumberAnimation { target: ft; property: "lift"; to: -6 * cal.s; duration: Tokens.animationFast / 2; easing.type: Easing.InCubic }
            }
            ScriptAction { script: { label.text = ft.text; ft.lift = 6 * cal.s; } }
            ParallelAnimation {
                NumberAnimation { target: label; property: "opacity"; to: 1; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
                NumberAnimation { target: ft; property: "lift"; to: 0; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
            }
        }
    }

    Column {
        id: content
        x: cal.pad
        y: cal.pad
        width: cal.width - cal.pad * 2
        spacing: cal.gap

        // Выбранная дата и кнопка «сегодня»
        Item {
            width: parent.width
            height: headline.y + headline.height + 4 * cal.s

            Text {
                x: 4 * cal.s
                text: "Выбранная дата"
                color: Theme.Palette.on_surface_variant
                font.family: Tokens.typography.family
                font.pixelSize: Math.round(12 * cal.s)
                font.weight: Font.Medium
            }

            FadeText {
                id: headline
                x: 4 * cal.s
                y: 22 * cal.s
                text: cal.cap(Qt.locale().toString(cal.shown, "ddd, d MMMM"))
                color: Theme.Palette.on_surface
                font.pixelSize: Math.round(26 * cal.s)
            }

            RoundIcon {
                anchors.right: parent.right
                anchors.verticalCenter: headline.verticalCenter
                glyph: "󰃶"
                enabled: cal.offset !== 0 || cal.selected !== null || cal.monthView
                onClicked: {
                    cal.selected = null;
                    cal.monthView = false;
                    cal.goTo(0);
                }
            }
        }

        Rectangle {
            x: -cal.pad
            width: cal.width
            height: Math.max(1, cal.s)
            color: Theme.Palette.outline_variant
        }

        // Месяц с переключателем вида и стрелки
        Item {
            width: parent.width
            height: 36 * cal.s

            // Позиции через x: смена якорей на лету оставляет старый якорь
            Rectangle {
                id: monthBtn
                anchors.verticalCenter: parent.verticalCenter
                x: cal.arrowsSide === "right" ? 0 : parent.width - width
                width: monthRow.width + 20 * cal.s
                height: 32 * cal.s
                radius: height / 2
                color: Theme.Palette.on_surface
                opacity: monthArea.pressed ? 0.12 : monthArea.containsMouse ? 0.08 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            }

            Row {
                id: monthRow
                anchors.verticalCenter: parent.verticalCenter
                x: monthBtn.x + 10 * cal.s
                spacing: 4 * cal.s

                FadeText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: cal.cap(Qt.locale().standaloneMonthName(cal.month.getMonth())) + " " + cal.month.getFullYear()
                    color: Theme.Palette.on_surface_variant
                    font.pixelSize: Math.round(14 * cal.s)
                    font.weight: Font.Medium
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍝"
                    color: Theme.Palette.on_surface_variant
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(18 * cal.s)
                    rotation: cal.monthView ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                id: monthArea
                anchors.fill: monthBtn
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    cal.monthView = !cal.monthView;
                    cal.stepped();
                }
            }

            // В режиме месяцев стрелки листают годы
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: cal.arrowsSide === "right" ? parent.width - width : 0
                spacing: 2 * cal.s

                Repeater {
                    model: [-1, 1]
                    RoundIcon {
                        required property int modelData
                        glyph: modelData < 0 ? "󰅁" : "󰅂"
                        nudge: modelData
                        onClicked: cal.goTo(cal.offset + modelData * (cal.monthView ? 12 : 1))
                    }
                }
            }
        }

        // Сетка дней и список месяцев друг над другом, переключение — crossfade
        Item {
            width: parent.width
            height: weekdays.height + cal.gap + days.height
            clip: true

            Item {
                id: grid
                width: parent.width
                height: parent.height

                ParallelAnimation {
                    id: shift
                    NumberAnimation { id: slide; target: grid; property: "x"; to: 0; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
                    NumberAnimation { target: grid; property: "opacity"; from: 0.4; to: 1; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
                }

                Column {
                    width: parent.width
                    spacing: cal.gap
                    opacity: cal.monthView ? 0 : 1
                    scale: cal.monthView ? 0.96 : 1
                    visible: opacity > 0
                    enabled: !cal.monthView
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    Row {
                        id: weekdays
                        Repeater {
                            model: 7
                            Text {
                                required property int index
                                width: cal.cell
                                horizontalAlignment: Text.AlignHCenter
                                text: cal.cap(Qt.locale().dayName((Qt.locale().firstDayOfWeek + index) % 7, Locale.ShortFormat))
                                color: Theme.Palette.on_surface
                                font.family: Tokens.typography.family
                                font.pixelSize: Math.round(13 * cal.s)
                            }
                        }
                    }

                    Grid {
                        id: days
                        columns: 7

                        Repeater {
                            model: 42
                            Item {
                                id: day
                                required property int index
                                readonly property date date: new Date(cal.month.getFullYear(), cal.month.getMonth(), 1 - cal.lead + index)
                                readonly property bool inMonth: date.getMonth() === cal.month.getMonth()
                                readonly property bool isToday: cal.sameDay(date, cal.today)
                                readonly property bool isSelected: cal.sameDay(date, cal.shown)

                                width: cal.cell
                                height: cal.rowH
                                // Grid пропускает невидимые элементы, поэтому скрываем через opacity
                                opacity: inMonth ? 1 : 0
                                enabled: inMonth

                                Item {
                                    anchors.centerIn: parent
                                    width: cal.dot
                                    height: cal.dot
                                    scale: dayArea.pressed ? 0.88 : 1
                                    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutBack } }

                                    // Обводка сегодняшнего дня
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: Math.max(1, cal.s)
                                        border.color: Theme.Palette.primary
                                        opacity: day.isToday && !day.isSelected ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                                    }

                                    // Заливка выбранного дня
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: Theme.Palette.primary
                                        opacity: day.isSelected ? 1 : 0
                                        scale: day.isSelected ? 1 : 0.4
                                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                                    }

                                    // Слой hover / pressed
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: day.isSelected ? Theme.Palette.on_primary : Theme.Palette.on_surface
                                        opacity: dayArea.pressed ? 0.12 : dayArea.containsMouse ? 0.08 : 0
                                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: day.date.getDate()
                                        color: day.isSelected ? Theme.Palette.on_primary
                                            : day.isToday ? Theme.Palette.primary
                                            : Theme.Palette.on_surface
                                        font.family: Tokens.typography.family
                                        font.pixelSize: Math.round(14 * cal.s)
                                        font.weight: day.isSelected || day.isToday ? Font.Medium : Font.Normal
                                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                                    }

                                    // Точка под числом — на дату есть заметка
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 5 * cal.s
                                        width: 4 * cal.s
                                        height: width
                                        radius: width / 2
                                        color: day.isSelected ? Theme.Palette.on_primary : Theme.Palette.primary
                                        opacity: !!cal.notes[Qt.formatDate(day.date, "yyyy-MM-dd")] ? 1 : 0
                                        scale: opacity
                                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
                                    }
                                }

                                MouseArea {
                                    id: dayArea
                                    anchors.centerIn: parent
                                    width: cal.dot
                                    height: cal.dot
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        cal.selected = day.isToday ? null : day.date;
                                        cal.dayClicked(day.date);
                                    }
                                }
                            }
                        }
                    }
                }

                // Список месяцев года
                Grid {
                    id: months
                    readonly property real itemW: (width - cal.gap * 2) / 3
                    readonly property real itemH: Math.min((height - cal.gap * 3) / 4, 40 * cal.s)
                    width: parent.width
                    height: parent.height
                    columns: 3
                    spacing: cal.gap
                    topPadding: (height - itemH * 4 - cal.gap * 3) / 2
                    opacity: cal.monthView ? 1 : 0
                    scale: cal.monthView ? 1 : 1.04
                    visible: opacity > 0
                    enabled: cal.monthView
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: 12
                        Item {
                            id: mon
                            required property int index
                            readonly property bool current: index === cal.month.getMonth()
                            readonly property bool isNow: index === cal.today.getMonth() && cal.month.getFullYear() === cal.today.getFullYear()

                            width: months.itemW
                            height: months.itemH

                            Item {
                                anchors.fill: parent
                                scale: monArea.pressed ? 0.94 : 1
                                Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutBack } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: "transparent"
                                    border.width: Math.max(1, cal.s)
                                    border.color: Theme.Palette.primary
                                    opacity: mon.isNow && !mon.current ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Theme.Palette.primary
                                    opacity: mon.current ? 1 : 0
                                    scale: mon.current ? 1 : 0.6
                                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: mon.current ? Theme.Palette.on_primary : Theme.Palette.on_surface
                                    opacity: monArea.pressed ? 0.12 : monArea.containsMouse ? 0.08 : 0
                                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: cal.cap(Qt.locale().standaloneMonthName(mon.index, Locale.ShortFormat))
                                    color: mon.current ? Theme.Palette.on_primary
                                        : mon.isNow ? Theme.Palette.primary
                                        : Theme.Palette.on_surface
                                    font.family: Tokens.typography.family
                                    font.pixelSize: Math.round(14 * cal.s)
                                    font.weight: Font.Medium
                                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                                }
                            }

                            MouseArea {
                                id: monArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cal.monthView = false;
                                    cal.goTo((cal.month.getFullYear() - cal.today.getFullYear()) * 12 + mon.index - cal.today.getMonth());
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
