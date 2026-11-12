pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/theme"

// Барабан выбора числа 0..count-1 (по образцу modules/noti-center/TimeDrum.qml):
// стрелки сверху и снизу, колесо мыши, числа уходят с поворотом в перспективе.
// s — масштаб от базового размера 96×192
Column {
    id: drum

    required property real s
    required property int count
    property alias value: view.currentIndex
    property string label
    // Прозрачный фон ячейки и стрелок; outline — мягкая белая обводка
    property bool transparent: false
    property bool outline: false
    // Цвет выбранного числа
    property color textColor: Tokens.colors.primary

    readonly property color outlineColor: Qt.alpha("#ffffff", 0.45)
    readonly property int outlineWidth: transparent && outline ? Math.max(1, Math.round(1.5 * s)) : 0

    spacing: 8 * s

    function step(delta: int): void {
        if (delta > 0)
            view.incrementCurrentIndex();
        else
            view.decrementCurrentIndex();
    }

    Arrow { icon: "keyboard_arrow_up"; delta: 1 }

    Rectangle {
        id: box
        width: 96 * drum.s
        height: 112 * drum.s
        radius: Tokens.radius(22 * drum.s)
        color: drum.transparent ? "transparent" : Tokens.colors.surface_container_high
        border.width: drum.outlineWidth
        border.color: drum.outlineColor
        clip: true
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

        PathView {
            id: view
            anchors.fill: parent
            model: drum.count
            pathItemCount: 3
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: Tokens.animationMedium
            snapMode: PathView.SnapToItem
            readonly property real gap: height * 0.85
            // Щелчок на каждом шаге, как у слайдеров (settings/controls/SettingSlider.qml)
            onCurrentIndexChanged: Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")])

            path: Path {
                startX: view.width / 2
                startY: view.height / 2 - view.gap * 1.5
                PathAttribute { name: "itemScale"; value: 0.6 }
                PathAttribute { name: "itemOpacity"; value: 0 }
                PathAttribute { name: "itemAngle"; value: 85 }
                PathLine { x: view.width / 2; y: view.height / 2 }
                PathAttribute { name: "itemScale"; value: 1 }
                PathAttribute { name: "itemOpacity"; value: 1 }
                PathAttribute { name: "itemAngle"; value: 0 }
                PathLine { x: view.width / 2; y: view.height / 2 + view.gap * 1.5 }
                PathAttribute { name: "itemScale"; value: 0.6 }
                PathAttribute { name: "itemOpacity"; value: 0 }
                PathAttribute { name: "itemAngle"; value: -85 }
            }

            delegate: Text {
                id: num
                required property int index
                readonly property real angle: PathView.itemAngle ?? 0

                text: String(index).padStart(2, "0")
                scale: PathView.itemScale ?? 1
                opacity: PathView.itemOpacity ?? 1
                color: PathView.isCurrentItem ? drum.textColor : Tokens.colors.on_surface
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                font.family: Tokens.typography.family
                font.pixelSize: Math.max(8, Math.round(44 * drum.s))
                font.weight: Font.Medium
                transform: Rotation {
                    origin.x: num.width / 2
                    origin.y: num.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: num.angle
                }
            }
        }

        // Подпись единицы под числом
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6 * drum.s
            text: drum.label
            color: Tokens.colors.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Math.max(6, Math.round(12 * drum.s))
        }

        // Колесо: шаг на каждые 120 единиц (тачпад шлёт мелкие порции)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            property real acc: 0
            onWheel: wheel => {
                acc += wheel.angleDelta.y;
                while (Math.abs(acc) >= 120) {
                    drum.step(acc > 0 ? 1 : -1);
                    acc -= acc > 0 ? 120 : -120;
                }
            }
        }
    }

    Arrow { icon: "keyboard_arrow_down"; delta: -1 }

    component Arrow: Rectangle {
        id: arrow
        property string icon
        property int delta

        anchors.horizontalCenter: parent.horizontalCenter
        width: 40 * drum.s
        height: 32 * drum.s
        radius: Tokens.radius(10 * drum.s)
        color: drum.transparent ? "transparent"
            : area.pressed ? Tokens.colors.surface_container_highest
            : area.containsMouse ? Tokens.colors.surface_container_high
            : Tokens.colors.surface_container
        border.width: drum.outlineWidth
        border.color: drum.outlineColor
        scale: area.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        // hover/pressed на прозрачном фоне
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: drum.transparent
            color: Tokens.colors.on_surface
            opacity: area.pressed ? 0.12 : area.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
        }

        Text {
            anchors.centerIn: parent
            text: arrow.icon
            color: Tokens.colors.on_surface
            font.family: "Material Symbols Rounded"
            font.pixelSize: Math.max(8, Math.round(22 * drum.s))
        }

        // Удержание листает непрерывно
        Timer {
            id: repeat
            interval: 110
            repeat: true
            onTriggered: drum.step(arrow.delta)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: drum.step(arrow.delta)
            onPressAndHold: repeat.start()
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }
    }
}
