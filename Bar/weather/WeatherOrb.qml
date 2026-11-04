import QtQuick

// Солнце или луна на небе окна погоды: идёт по дуге слева направо, progress 0..1 — от восхода до заката светила.
Rectangle {
    id: orb

    property real progress: 0
    property real unit: 1
    property real areaWidth: 0

    readonly property real p: Math.max(-0.1, Math.min(1.1, progress))
    readonly property real arcTop: 16 * unit
    readonly property real arcBottom: 190 * unit

    height: width
    radius: width / 2
    x: 10 * unit + p * (areaWidth - width - 20 * unit)
    y: arcBottom - (arcBottom - arcTop) * Math.sin(Math.PI * Math.max(0, Math.min(1, p)))

    // Ореол
    Rectangle {
        z: -1
        anchors.centerIn: parent
        width: parent.width * 1.7
        height: width
        radius: width / 2
        color: orb.color
        opacity: 0.18
    }
}
