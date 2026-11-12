import QtQuick
import QtQuick.Shapes

// Солнце или луна на небе окна погоды: идёт по дуге слева направо, progress 0..1 — от восхода до заката светила.
// phase — фаза луны 0..1 (0 — новолуние, 0.25 — первая четверть, 0.5 — полнолуние); < 0 — полный диск (солнце).
// Освещённая часть: полуокружность и терминатор (полуэллипс); фигура строится только при смене фазы.
Item {
    id: orb

    property color color: "white"
    property real progress: 0
    property real unit: 1
    property real areaWidth: 0
    property real phase: -1

    readonly property bool moon: phase >= 0
    // Освещённая доля диска
    readonly property real lit: moon ? (1 - Math.cos(2 * Math.PI * phase)) / 2 : 1
    readonly property real p: Math.max(-0.1, Math.min(1.1, progress))
    readonly property real arcTop: 16 * unit
    readonly property real arcBottom: 190 * unit

    height: width
    x: 10 * unit + p * (areaWidth - width - 20 * unit)
    y: arcBottom - (arcBottom - arcTop) * Math.sin(Math.PI * Math.max(0, Math.min(1, p)))

    // Ореол: у луны слабее, чем меньше освещённая часть
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 1.7
        height: width
        radius: width / 2
        color: orb.color
        opacity: 0.18 * (orb.moon ? 0.25 + 0.75 * orb.lit : 1)
    }

    // Диск; у луны — едва видная неосвещённая часть
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: orb.color
        opacity: orb.moon ? 0.12 : 1
    }

    Shape {
        anchors.fill: parent
        visible: orb.moon && orb.lit > 0.01
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: litPath
            // Растущая луна освещена справа, убывающая — слева (северное полушарие)
            readonly property bool waxing: orb.phase < 0.5
            // Серп: терминатор выгнут к освещённому краю, иначе — от него
            readonly property bool crescent: orb.lit < 0.5
            readonly property real r: orb.width / 2
            strokeWidth: -1
            fillColor: orb.color
            startX: litPath.r
            startY: 0
            // Внешний край: сверху вниз через освещённую сторону
            PathArc {
                x: litPath.r
                y: orb.width
                radiusX: litPath.r
                radiusY: litPath.r
                direction: litPath.waxing ? PathArc.Clockwise : PathArc.Counterclockwise
            }
            // Терминатор: снизу вверх
            PathArc {
                x: litPath.r
                y: 0
                radiusX: Math.max(0.01, litPath.r * Math.abs(Math.cos(2 * Math.PI * orb.phase)))
                radiusY: litPath.r
                direction: litPath.waxing === litPath.crescent ? PathArc.Counterclockwise : PathArc.Clockwise
            }
        }
    }
}
