pragma ComponentBehavior: Bound
import QtQuick
import "../../theme" as Theme
import "../../shell/theme"

// Барабан выбора числа 0..count-1: стрелки сверху и снизу, колесо мыши и перетаскивание.
// Числа уходят вверх и вниз с поворотом в перспективе, как на вращающемся цилиндре.
Column {
    id: drum

    required property real s
    required property int count
    property alias value: view.currentIndex

    signal ticked()

    spacing: 8 * s

    function step(delta: int): void {
        if (delta > 0)
            view.incrementCurrentIndex();
        else
            view.decrementCurrentIndex();
    }

    Arrow { glyph: "󰅃"; delta: 1 }

    Rectangle {
        id: box
        width: 96 * drum.s
        height: 112 * drum.s
        radius: 22 * drum.s
        color: Theme.Palette.surface_container_high
        clip: true

        PathView {
            id: view
            anchors.fill: parent
            model: drum.count
            // Видно одно число: соседние стоят за краями ячейки и
            // въезжают с поворотом только во время прокрутки
            pathItemCount: 3
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: Tokens.animationMedium
            snapMode: PathView.SnapToItem
            // Расстояние между числами на барабане
            readonly property real gap: height * 0.85
            onCurrentIndexChanged: drum.ticked()

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
                color: PathView.isCurrentItem ? Theme.Palette.primary : Theme.Palette.on_surface
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Math.round(44 * drum.s)
                font.weight: Font.Medium
                transform: Rotation {
                    origin.x: num.width / 2
                    origin.y: num.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: num.angle
                }
            }
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

    Arrow { glyph: "󰅀"; delta: -1 }

    component Arrow: Rectangle {
        id: arrow
        property string glyph
        property int delta

        anchors.horizontalCenter: parent.horizontalCenter
        width: 40 * drum.s
        height: 32 * drum.s
        radius: 10 * drum.s
        color: area.pressed ? Theme.Palette.surface_container_highest
            : area.containsMouse ? Theme.Palette.surface_container_high
            : Theme.Palette.surface_container
        scale: area.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: arrow.glyph
            color: Theme.Palette.on_surface
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(18 * drum.s)
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
