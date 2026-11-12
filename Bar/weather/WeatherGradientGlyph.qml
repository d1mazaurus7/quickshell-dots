import QtQuick
import QtQuick.Effects

// Часть цветного значка погоды: фигура WeatherShape, закрашенная вертикальным градиентом from → to.
Item {
    id: g

    property string part: "cloud"
    property real size: 24
    property color from: "white"
    property color to: "white"

    width: size
    height: size

    WeatherShape {
        id: shape
        part: g.part
        size: g.size
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    Rectangle {
        id: fill
        anchors.fill: shape
        visible: false
        gradient: Gradient {
            GradientStop { position: 0.1; color: g.from }
            GradientStop { position: 0.95; color: g.to }
        }
    }

    MultiEffect {
        anchors.fill: shape
        source: fill
        maskEnabled: true
        maskSource: shape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
