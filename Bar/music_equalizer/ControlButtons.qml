import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../theme" as Theme
import "../../shell/theme"

// Кнопки назад / пауза / вперёд: нажатая расширяется, соседние сужаются.
// Общая ширина группы постоянна.
Row {
    id: buttons

    property MprisPlayer player: null

    // Значки кнопок (Material Symbols Rounded)
    property string iconPrevious: "skip_previous"
    property string iconPlay: "play_arrow"
    property string iconPause: "pause"
    property string iconNext: "skip_next"
    property int btnSize: Tokens.scaled(40)
    readonly property int btnGrow: Math.round(btnSize * 0.3)
    property int animExpand: 520
    property int animShrink: 220

    spacing: Tokens.scaled(4)

    property int pressedIndex: -1
    property bool anyPressed: false

    // Степень расширения каждой кнопки (0 — обычная, 1 — расширенная)
    property real g0: pressedIndex === 0 ? 1 : 0
    property real g1: pressedIndex === 1 ? 1 : 0
    property real g2: pressedIndex === 2 ? 1 : 0
    Behavior on g0 { NumberAnimation { duration: buttons.pressedIndex === 0 ? buttons.animExpand : buttons.animShrink; easing.type: buttons.pressedIndex === 0 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 2.2 } }
    Behavior on g1 { NumberAnimation { duration: buttons.pressedIndex === 1 ? buttons.animExpand : buttons.animShrink; easing.type: buttons.pressedIndex === 1 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 2.2 } }
    Behavior on g2 { NumberAnimation { duration: buttons.pressedIndex === 2 ? buttons.animExpand : buttons.animShrink; easing.type: buttons.pressedIndex === 2 ? Easing.OutBack : Easing.OutCubic; easing.overshoot: 2.2 } }

    function grow(i) { return i === 0 ? g0 : i === 1 ? g1 : g2; }
    // Ширина: своё расширение минус доля расширения соседей (средняя отдаёт поровну двум крайним)
    function widthOf(i) {
        let w = btnSize + btnGrow * grow(i);
        if (i === 1) w -= btnGrow * (g0 + g2);
        else w -= btnGrow * g1 / 2;
        return w;
    }

    // Минимальное время в расширенном состоянии: короткий клик проигрывает анимацию
    Timer {
        id: pressHold
        interval: buttons.animExpand * 0.7
        onTriggered: if (!buttons.anyPressed) buttons.pressedIndex = -1
    }

    Process {
        id: clickSound
        command: ["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]
    }

    Repeater {
        model: [
            { icon: buttons.iconPrevious, primary: false },
            { icon: buttons.player?.isPlaying ? buttons.iconPause : buttons.iconPlay, primary: true },
            { icon: buttons.iconNext, primary: false }
        ]

        Rectangle {
            id: btn
            required property var modelData
            required property int index

            readonly property bool enabledAction: buttons.player !== null && (
                index === 0 ? buttons.player.canGoPrevious
                : index === 1 ? buttons.player.canTogglePlaying
                : buttons.player.canGoNext)
            readonly property color baseColor: modelData.primary ? Theme.Palette.primary : Theme.Palette.secondary_container
            readonly property color hoverColor: modelData.primary ? Theme.Palette.primary_fixed : Theme.Palette.surface_bright

            width: buttons.widthOf(index)
            height: buttons.btnSize
            radius: Tokens.radius(height * (0.34 - 0.1 * Math.min(1, buttons.grow(index))))
            color: area.containsMouse && enabledAction ? hoverColor : baseColor
            opacity: enabledAction ? 1 : 0.4

            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

            Text {
                anchors.centerIn: parent
                text: btn.modelData.icon
                color: btn.modelData.primary ? Theme.Palette.on_primary : Theme.Palette.on_secondary_container
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(buttons.btnSize * 0.62)
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                enabled: btn.enabledAction
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    clickSound.startDetached();
                    buttons.anyPressed = true;
                    buttons.pressedIndex = btn.index;
                    pressHold.restart();
                }
                onReleased: {
                    buttons.anyPressed = false;
                    if (!pressHold.running) buttons.pressedIndex = -1;
                }
                onCanceled: {
                    buttons.anyPressed = false;
                    if (!pressHold.running) buttons.pressedIndex = -1;
                }
                onClicked: {
                    if (btn.index === 0) buttons.player.previous();
                    else if (btn.index === 1) buttons.player.togglePlaying();
                    else buttons.player.next();
                }
            }
        }
    }
}
