pragma ComponentBehavior: Bound
import QtQuick

// Значок погоды. name — имя из WeatherCodes.icon().
// colored: false — Material You (глиф шрифта цветом tint), true — цветной: фигуры с градиентами,
// у переменной облачности светило за облаком, у осадков облако и осадки своими цветами.
Item {
    id: root

    property string name: "cloud"
    property real size: 24
    property color tint: "white"
    property bool colored: false
    property bool night: false

    // Части цветного значка: [{ part, from, to, x, y, scale }], координаты — доли size
    readonly property var parts: {
        const sun = ["#ffe082", "#ff9800"];
        const moon = ["#fff4c9", "#b9a6ff"];
        const cloud = night ? ["#e4e9f1", "#8b9ab0"] : ["#ffffff", "#b6c6dc"];
        const p = (part, c, x, y, scale) => ({ part: part, from: c[0], to: c[1], x: x ?? 0, y: y ?? 0, scale: scale ?? 1 });
        switch (name) {
        case "sunny": return [p("sun", sun)];
        case "clear_night": return [p("moon", moon)];
        case "partly_cloudy_day": return [p("sun", sun, 0, 0, 0.7), p("cloud", cloud, 0.16, 0.2, 0.84)];
        case "partly_cloudy_night": return [p("moon", moon, 0, 0, 0.7), p("cloud", cloud, 0.16, 0.2, 0.84)];
        case "foggy": return [p("cloudTop", ["#f1f3f7", "#aab5c4"]), p("fog", ["#e6eaf0", "#9aa6b6"])];
        case "rainy": return [p("cloudTop", ["#f1f4f8", "#a3b3c8"]), p("drops", ["#8fdcff", "#2f74e0"])];
        case "weather_snowy": return [p("cloudTop", ["#ffffff", "#b9cde0"]), p("flakes", ["#ffffff", "#7fd0ff"])];
        case "thunderstorm": return [p("cloudTop", ["#d3d7e6", "#6f7592"]), p("bolt", ["#fff176", "#ff9800"])];
        }
        return [p("cloud", cloud)];
    }

    implicitWidth: size
    implicitHeight: size

    Text {
        anchors.centerIn: parent
        visible: !root.colored
        text: root.name
        color: root.tint
        font.family: "Material Symbols Rounded"
        font.pixelSize: root.size
        Behavior on color { ColorAnimation { duration: 300 } }
    }

    Repeater {
        model: root.colored ? root.parts : []
        WeatherGradientGlyph {
            id: piece
            required property var modelData
            x: root.size * piece.modelData.x
            y: root.size * piece.modelData.y
            size: root.size * piece.modelData.scale
            part: piece.modelData.part
            from: piece.modelData.from
            to: piece.modelData.to
        }
    }
}
