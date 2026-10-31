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
                radius: Tokens.radius(18)
                color: window.colors.surface_container_highest
                border.width: Tokens.borderWidth
                border.color: window.colors.outline_variant

                opacity: root.shown ? 1 : 0
                y: root.shown ? 0 : Tokens.spacingMediumV
                scale: root.shown ? 1 : 0.94
                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                // Без слайдера подпись по центру карточки
                Text {
                    id: label
                    x: window.showSlider ? Tokens.spacingLarge : (card.width - width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: window.isVolume ? (window.showSlider ? Math.round(osdState.volume * 100) + "%" : "Звук: выкл")
                        : (osdState.kind === "caps" ? "Caps lock: " : "Num lock: ")
                            + ((osdState.kind === "caps" ? osdState.capsLock : osdState.numLock) ? "вкл" : "выкл")
                    color: window.colors.on_surface
                    font: Tokens.fontMedium
                    Behavior on x { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
                }

                // Дорожка: заливка до центра ползунка, ползунок крупнее дорожки
                Rectangle {
                    id: track
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Tokens.spacingLarge + Tokens.scaled(48) + Tokens.spacingMedium
                    anchors.rightMargin: Tokens.spacingLarge
                    anchors.verticalCenter: parent.verticalCenter
                    height: Tokens.scaled(20)
                    radius: height / 2
                    color: window.colors.secondary_container
                    opacity: window.showSlider ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    readonly property real knobSize: Tokens.scaled(26)
                    property real knobX: (width - knobSize) * Math.min(1, osdState.volume)
                    Behavior on knobX { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

                    Rectangle {
                        height: parent.height
                        width: track.knobX + track.knobSize / 2
                        radius: parent.radius
                        color: window.colors.primary
                    }

                    Rectangle {
                        x: track.knobX
                        anchors.verticalCenter: parent.verticalCenter
                        width: track.knobSize
                        height: track.knobSize
                        radius: width / 2
                        color: window.colors.primary_container
                    }
                }
            }
        }
    }
}
