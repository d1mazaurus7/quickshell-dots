pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Сплошная белая фигура части значка погоды — маска для градиента (WeatherGradientGlyph).
// part: sun | moon | cloud | cloudTop (облако выше, под ним осадки) | drops | flakes | fog | bolt
Item {
    id: root

    property string part: "cloud"
    property real size: 24
    readonly property real s: size

    width: size
    height: size

    // Солнце: диск и 8 лучей
    Item {
        anchors.fill: parent
        visible: root.part === "sun"

        Rectangle {
            anchors.centerIn: parent
            width: root.s * 0.46
            height: width
            radius: width / 2
        }
        Repeater {
            model: 8
            Item {
                required property int index
                anchors.fill: parent
                rotation: index * 45
                Rectangle {
                    width: root.s * 0.09
                    height: root.s * 0.15
                    radius: width / 2
                    x: (root.s - width) / 2
                    y: root.s * 0.03
                }
            }
        }
    }

    // Луна: серп из двух дуг
    Shape {
        anchors.fill: parent
        visible: root.part === "moon"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            readonly property real cx: root.s * 0.5
            readonly property real cy: root.s * 0.5
            readonly property real r: root.s * 0.4
            strokeWidth: -1
            fillColor: "white"
            startX: cx + r * 0.5
            startY: cy - r * 0.866
            PathArc {
                x: root.s * 0.5 + root.s * 0.4 * 0.5
                y: root.s * 0.5 + root.s * 0.4 * 0.866
                radiusX: root.s * 0.4
                radiusY: root.s * 0.4
                useLargeArc: true
                direction: PathArc.Counterclockwise
            }
            PathArc {
                x: root.s * 0.5 + root.s * 0.4 * 0.5
                y: root.s * 0.5 - root.s * 0.4 * 0.866
                radiusX: root.s * 0.42
                radiusY: root.s * 0.42
                direction: PathArc.Clockwise
            }
        }
    }

    // Облако из кругов на скруглённом основании
    Item {
        anchors.fill: parent
        visible: root.part === "cloud" || root.part === "cloudTop"
        y: root.part === "cloudTop" ? -root.s * 0.14 : 0

        Rectangle { x: root.s * 0.08; y: root.s * 0.48; width: root.s * 0.84; height: root.s * 0.32; radius: height / 2 }
        Rectangle { x: root.s * 0.12; y: root.s * 0.36; width: root.s * 0.38; height: width; radius: width / 2 }
        Rectangle { x: root.s * 0.3; y: root.s * 0.16; width: root.s * 0.5; height: width; radius: width / 2 }
        Rectangle { x: root.s * 0.55; y: root.s * 0.32; width: root.s * 0.38; height: width; radius: width / 2 }
    }

    // Капли дождя
    Repeater {
        model: root.part === "drops" ? [0.28, 0.47, 0.66] : []
        Rectangle {
            required property real modelData
            x: root.s * modelData
            y: root.s * 0.7
            width: root.s * 0.08
            height: root.s * 0.22
            radius: width / 2
            rotation: 20
        }
    }

    // Снежинки
    Repeater {
        model: root.part === "flakes" ? [[0.26, 0.74], [0.45, 0.84], [0.64, 0.74]] : []
        Rectangle {
            required property var modelData
            x: root.s * modelData[0]
            y: root.s * modelData[1]
            width: root.s * 0.12
            height: width
            radius: width / 2
        }
    }

    // Туман
    Repeater {
        model: root.part === "fog" ? [[0.1, 0.76, 0.62], [0.28, 0.9, 0.62]] : []
        Rectangle {
            required property var modelData
            x: root.s * modelData[0]
            y: root.s * modelData[1]
            width: root.s * modelData[2]
            height: root.s * 0.08
            radius: height / 2
        }
    }

    // Молния
    Shape {
        anchors.fill: parent
        visible: root.part === "bolt"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: "white"
            startX: root.s * 0.54; startY: root.s * 0.56
            PathLine { x: root.s * 0.36; y: root.s * 0.82 }
            PathLine { x: root.s * 0.5; y: root.s * 0.82 }
            PathLine { x: root.s * 0.42; y: root.s * 1.0 }
            PathLine { x: root.s * 0.68; y: root.s * 0.7 }
            PathLine { x: root.s * 0.54; y: root.s * 0.7 }
            PathLine { x: root.s * 0.62; y: root.s * 0.56 }
            PathLine { x: root.s * 0.54; y: root.s * 0.56 }
        }
    }
}
