import QtQuick

// Слой состояний MD3: hover 8%, pressed 12% цвета содержимого.
// Скругления задаются как у Rectangle (radius / topLeftRadius …).
Rectangle {
    property bool hovered
    property bool pressed

    anchors.fill: parent
    opacity: pressed ? 0.12 : hovered ? 0.08 : 0
    Behavior on opacity { Smooth { duration: 120 } }
}
