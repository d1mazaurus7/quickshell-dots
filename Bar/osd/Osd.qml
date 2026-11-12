pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../shell/theme"

// Всплывающее окно громкости и Caps/Num Lock внизу каждого экрана.
// Использование: Osd.Osd {} (import "../Bar/osd" as Osd)
Scope {
    id: root

    property bool shown: false

    // Смена текста в стиле M3E: уход (fade + scale/сдвиг), подмена, возврат с пружиной.
    // Анимируется одно свойство t, остальное — его функции.
    component SwapText: Text {
        id: st
        property string value
        property real minScale: 1
        property real shift: 0
        property real t: 1
        opacity: t
        scale: minScale + (1 - minScale) * t
        transform: Translate { y: (1 - st.t) * st.shift }
        Component.onCompleted: text = value
        onValueChanged: if (text !== value) swap.restart()

        SequentialAnimation {
            id: swap
            NumberAnimation { target: st; property: "t"; to: 0; duration: Tokens.animationFast * 0.6; easing.type: Easing.InCubic }
            ScriptAction { script: st.text = st.value }
            NumberAnimation { target: st; property: "t"; to: 1; duration: Tokens.animationSlow; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        }
    }

    OsdState {
        id: osdState
        onTriggered: {
            root.shown = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window
            required property var modelData

            readonly property var colors: Tokens.colors
            readonly property bool isVolume: osdState.kind === "volume"
            // Слайдер только у громкости и только пока звук есть
            readonly property bool showSlider: isVolume && !osdState.muted && osdState.volume > 0

            screen: modelData
            WlrLayershell.namespace: "qs:osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // Окно не перехватывает мышь
            mask: Region {}
            visible: root.shown || card.opacity > 0

            anchors.bottom: true
            margins { bottom: Tokens.scaled(64) }
            implicitWidth: card.width
            implicitHeight: card.height + Tokens.spacingMediumV

            Rectangle {
                id: card
                width: Tokens.scaled(340)
                height: Tokens.scaled(56)
                radius: height / 2
                color: window.colors.surface_container

                // Одна анимация вместо трёх: opacity, y и scale — линейные функции от progress
                property real progress: root.shown ? 1 : 0
                Behavior on progress { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                opacity: progress
                y: (1 - progress) * Tokens.spacingMediumV
                scale: 0.94 + 0.06 * progress

                readonly property real pad: Tokens.scaled(8)

                // Круглая иконка слева
                Rectangle {
                    id: iconBox
                    x: card.pad
                    anchors.verticalCenter: parent.verticalCenter
                    width: card.height - card.pad * 2
                    height: width
                    radius: width / 2
                    color: window.colors.surface_container_highest

                    SwapText {
                        anchors.centerIn: parent
                        minScale: 0.4
                        value: window.isVolume
                            ? (!window.showSlider ? "volume_off" : osdState.volume < 0.5 ? "volume_down" : "volume_up")
                            : (osdState.kind === "caps" ? "keyboard_capslock" : "dialpad")
                        color: window.colors.on_surface
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.scaled(22)
                    }
                }

                // Без слайдера — подпись по центру оставшейся области
                Item {
                    readonly property real areaX: iconBox.x + iconBox.width
                    x: areaX + (card.width - areaX - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: label.width
                    height: label.height
                    opacity: window.showSlider ? 0 : 1
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    SwapText {
                        id: label
                        shift: Tokens.scaled(8)
                        value: window.isVolume ? "Звук: выкл"
                            : (osdState.kind === "caps" ? "Caps lock: " : "Num lock: ")
                                + ((osdState.kind === "caps" ? osdState.capsLock : osdState.numLock) ? "вкл" : "выкл")
                        color: window.colors.on_surface
                        font: Tokens.fontMedium
                    }
                }

                // M3 слайдер: активная часть | ручка | неактивная часть с точкой-стопом
                Item {
                    id: track
                    x: iconBox.x + iconBox.width + Tokens.spacingMedium
                    width: card.width - x - card.pad * 2
                    height: iconBox.height
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: window.showSlider ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    readonly property real outerR: Tokens.radius(12)
                    readonly property real innerR: Tokens.scaled(3)
                    readonly property real gap: Tokens.scaled(5)
                    readonly property real handleW: Tokens.scaled(4)
                    // Ширина активной части; анимируется одно свойство
                    property real fill: (width - handleW - gap * 2) * Math.min(1, osdState.volume)
                    Behavior on fill { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

                    Rectangle {
                        width: track.fill
                        height: parent.height
                        visible: width > 0.5
                        color: window.colors.primary
                        topLeftRadius: Math.min(track.outerR, width / 2)
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: Math.min(track.innerR, width / 2)
                        bottomRightRadius: topRightRadius
                    }

                    Rectangle {
                        x: track.fill + track.gap
                        anchors.verticalCenter: parent.verticalCenter
                        width: track.handleW
                        height: parent.height + Tokens.scaled(8)
                        radius: width / 2
                        color: window.colors.primary
                    }

                    Rectangle {
                        id: inactive
                        x: track.fill + track.handleW + track.gap * 2
                        width: parent.width - x
                        height: parent.height
                        visible: width > 0.5
                        color: window.colors.secondary_container
                        topLeftRadius: Math.min(track.innerR, width / 2)
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: Math.min(track.outerR, width / 2)
                        bottomRightRadius: topRightRadius

                        // Точка-стоп в конце дорожки
                        Rectangle {
                            readonly property real size: Tokens.scaled(4)
                            x: parent.width - track.outerR / 2 - size / 2 - Tokens.scaled(4)
                            anchors.verticalCenter: parent.verticalCenter
                            width: size
                            height: size
                            radius: size / 2
                            color: window.colors.primary
                            visible: x > 0
                        }
                    }
                }
            }
        }
    }
}
