pragma ComponentBehavior: Bound
import QtQuick
import "../../theme" as Theme
import "../../shell/theme"

// Календарь месяца: заголовок со стрелками, дни недели и сетка 6×7.
// Дни соседних месяцев приглушены, сегодняшний день выделен.
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

    signal stepped()
    signal dayClicked(date date)

    readonly property real pad: 12 * s
    readonly property real gap: 6 * s
    readonly property real cell: (width - pad * 2 - gap * 6) / 7
    // Насколько расширяется нажатый день
    readonly property real grow: 12 * s
    property int pressedIndex: -1
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    // Сколько дней предыдущего месяца в первой строке
    readonly property int lead: (month.getDay() - Qt.locale().firstDayOfWeek + 7) % 7

    function step(delta: int): void {
        offset += delta;
        slide.from = delta > 0 ? 12 * s : -12 * s;
        shift.restart();
        stepped();
    }

    implicitHeight: content.height + pad * 2
    radius: 16 * s
    color: Theme.Palette.surface_container

    Column {
        id: content
        x: cal.pad
        y: cal.pad
        width: cal.width - cal.pad * 2
        spacing: cal.gap

        // Название месяца и стрелки
        Item {
            width: parent.width
            height: 32 * cal.s

            // Позиции через x: смена якорей на лету оставляет старый якорь
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: cal.arrowsSide === "right" ? 4 * cal.s : parent.width - width - 4 * cal.s
                text: {
                    const name = Qt.locale().standaloneMonthName(cal.month.getMonth());
                    return name.charAt(0).toUpperCase() + name.slice(1) + " " + cal.month.getFullYear();
                }
                color: Theme.Palette.on_surface
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(15 * cal.s)
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: cal.arrowsSide === "right" ? parent.width - width : 0
                spacing: cal.gap

                Arrow { glyph: "󰅁"; onClicked: cal.step(-1) }
                Arrow { glyph: "󰅂"; onClicked: cal.step(1) }
            }
        }

        // Дни недели
        Row {
            spacing: cal.gap

            Repeater {
                model: 7
                Text {
                    required property int index
                    width: cal.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((Qt.locale().firstDayOfWeek + index) % 7, Locale.ShortFormat)
                    color: Theme.Palette.on_surface_variant
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(11 * cal.s)
                }
            }
        }

        // Сетка дней: строки по 7. Нажатый день расширяется, соседи в строке
        // сжимаются на ту же сумму, поэтому ширина строки постоянна.
        Column {
            id: grid
            spacing: cal.gap

            ParallelAnimation {
                id: shift
                NumberAnimation { id: slide; target: grid; property: "x"; to: 0; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
                NumberAnimation { target: grid; property: "opacity"; from: 0.4; to: 1; duration: Tokens.animationFast; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: 6
                Row {
                    id: week
                    required property int index
                    spacing: cal.gap

                    Repeater {
                        model: 7
                        Rectangle {
                            id: day
                            required property int index
                            readonly property int cellIndex: week.index * 7 + index
                            readonly property bool pressed: cal.pressedIndex === cellIndex
                            readonly property bool rowPressed: Math.floor(cal.pressedIndex / 7) === week.index
                            readonly property date date: new Date(cal.month.getFullYear(), cal.month.getMonth(), 1 - cal.lead + cellIndex)
                            readonly property bool inMonth: date.getMonth() === cal.month.getMonth()
                            readonly property bool isToday: date.getFullYear() === cal.today.getFullYear()
                                && date.getMonth() === cal.today.getMonth()
                                && date.getDate() === cal.today.getDate()

                            width: pressed ? cal.cell + cal.grow
                                : rowPressed ? cal.cell - cal.grow / 6
                                : cal.cell
                            height: cal.cell
                            radius: 10 * cal.s
                            color: isToday ? Theme.Palette.primary
                                : inMonth ? Theme.Palette.surface_container_high
                                : Theme.Palette.surface_container_low
                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                            Behavior on width {
                                NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                            }

                            // Слой hover / pressed
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: day.isToday ? Theme.Palette.on_primary : Theme.Palette.on_surface
                                opacity: day.pressed ? 0.12 : dayArea.containsMouse ? 0.06 : 0
                                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: day.date.getDate()
                                color: day.isToday ? Theme.Palette.on_primary
                                    : day.inMonth ? Theme.Palette.on_surface
                                    : Theme.Palette.on_surface_variant
                                opacity: day.inMonth || day.isToday ? 1 : 0.5
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Math.round(13 * cal.s)
                                font.weight: day.isToday ? Font.Bold : Font.Normal
                            }

                            // Точка под числом — на дату есть заметка
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6 * cal.s
                                width: 4 * cal.s
                                height: width
                                radius: width / 2
                                color: day.isToday ? Theme.Palette.on_primary : Theme.Palette.primary
                                opacity: !!cal.notes[Qt.formatDate(day.date, "yyyy-MM-dd")] ? 1 : 0
                                scale: opacity
                                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: cal.pressedIndex = day.cellIndex
                                onReleased: cal.pressedIndex = -1
                                onCanceled: cal.pressedIndex = -1
                                onClicked: cal.dayClicked(day.date)
                            }
                        }
                    }
                }
            }
        }
    }

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        signal clicked()

        width: 32 * cal.s
        height: width
        radius: 8 * cal.s
        color: area.pressed ? Theme.Palette.surface_container_highest
            : area.containsMouse ? Theme.Palette.surface_container_high
            : Theme.Palette.surface_container_low
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            color: Theme.Palette.on_surface
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(18 * cal.s)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }
}
