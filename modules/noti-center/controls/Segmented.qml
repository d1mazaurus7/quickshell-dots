import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"

// Группа соединённых кнопок MD3 expressive с одиночным выбором.
// Внешние углы группы круглые, внутренние — малые; выбранная кнопка
// морфится в пилюлю, нажатая — расширяется за счёт соседей и сжимает углы.
// Иконка выбранной кнопки «подпрыгивает».
Item {
    id: group

    required property real s
    // [{ value, label, icon? }]
    property var options: []
    property var current
    signal picked(var value)

    readonly property int count: options.length
    readonly property real gap: 2 * s
    readonly property real grow: 10 * s
    readonly property real inner: 6 * s
    readonly property real base: count > 0 ? (width - gap * (count - 1)) / count : 0
    property int pressedIndex: -1

    function buttonWidth(i: int): real {
        if (pressedIndex < 0 || count < 2)
            return base;
        return i === pressedIndex ? base + grow : base - grow / (count - 1);
    }

    implicitHeight: 40 * s

    Row {
        spacing: group.gap

        Repeater {
            model: group.options

            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool selected: modelData.value === group.current
                readonly property bool first: index === 0
                readonly property bool last: index === group.count - 1
                readonly property real full: height / 2
                // Углы: выбранная — пилюля, нажатая — сжатые
                readonly property real outerR: area.pressed ? full * 0.5 : full
                readonly property real innerR: selected ? (area.pressed ? full * 0.5 : full) : group.inner
                readonly property color fg: selected ? Theme.Palette.on_primary : Theme.Palette.on_surface_variant

                width: group.buttonWidth(index)
                height: group.height

                Behavior on width { Smooth {} }

                Rectangle {
                    id: bg
                    anchors.fill: parent
                    topLeftRadius: cell.first ? cell.outerR : cell.innerR
                    bottomLeftRadius: topLeftRadius
                    topRightRadius: cell.last ? cell.outerR : cell.innerR
                    bottomRightRadius: topRightRadius
                    color: cell.selected ? Theme.Palette.primary : Theme.Palette.surface_container_high

                    Behavior on topLeftRadius { Emphasized {} }
                    Behavior on topRightRadius { Emphasized {} }
                    Behavior on color { SmoothColor {} }

                    StateLayer {
                        topLeftRadius: bg.topLeftRadius
                        bottomLeftRadius: bg.bottomLeftRadius
                        topRightRadius: bg.topRightRadius
                        bottomRightRadius: bg.bottomRightRadius
                        color: cell.fg
                        hovered: area.containsMouse
                        pressed: area.pressed
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6 * group.s

                    Icon {
                        id: glyph
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!cell.modelData.icon
                        text: cell.modelData.icon ?? ""
                        size: 18 * group.s
                        color: cell.fg
                        scale: area.pressed ? 0.8 : 1
                        Behavior on color { SmoothColor {} }
                        Behavior on scale { Emphasized { duration: Tokens.animationMedium } }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: cell.modelData.label ?? ""
                        color: cell.fg
                        font.family: Tokens.typography.family
                        font.pixelSize: Math.round(12 * group.s)
                        font.weight: cell.selected ? Font.DemiBold : Font.Normal
                        Behavior on color { SmoothColor {} }
                    }
                }

                // Отскок иконки при выборе
                SequentialAnimation {
                    id: bounce
                    NumberAnimation { target: glyph; property: "rotation"; to: -12; duration: Tokens.animationFast * 0.6; easing.type: Easing.OutCubic }
                    NumberAnimation { target: glyph; property: "rotation"; to: 0; duration: Tokens.animationMedium; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressedChanged: {
                        if (pressed)
                            group.pressedIndex = cell.index;
                        else if (group.pressedIndex === cell.index)
                            group.pressedIndex = -1;
                    }
                    onClicked: {
                        if (cell.selected)
                            return;
                        if (glyph.visible)
                            bounce.restart();
                        group.picked(cell.modelData.value);
                    }
                }
            }
        }
    }
}
