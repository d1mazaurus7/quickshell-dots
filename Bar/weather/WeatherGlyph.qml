pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Значок погоды. name — имя из WeatherCodes.icon().
// colored: false — Material You (глиф шрифта цветом tint), true — цветной: фигуры с градиентами,
// у переменной облачности светило за облаком, у осадков облако и осадки своими цветами.
// active — фоновая анимация (светило дышит, облака плывут, осадки падают); hovered — значок
// пружинисто увеличивается и оживает; смена значка и pop() — короткий отклик.
// Выключенный (enabled: false) — приглушён.
Item {
    id: root

    property string name: "cloud"
    property real size: 24
    property color tint: "white"
    property bool colored: false
    property bool night: false
    property bool active: false
    property bool hovered: false
    readonly property bool animating: (active || hovered) && visible

    function pop() { popAnim.restart(); }
    onNameChanged: pop()

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

    // Движение части цветного значка и глифа шрифта целиком
    readonly property var partMotion: ({ sun: "pulse", moon: "rock", cloud: "drift", cloudTop: "drift",
                                         fog: "driftBack", drops: "fall", flakes: "float", bolt: "flicker" })
    readonly property var glyphMotion: ({ sunny: "spin", clear_night: "rock", rainy: "float",
                                          weather_snowy: "float", thunderstorm: "flicker" })

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.38
    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    Item {
        id: body
        anchors.fill: parent
        scale: root.hovered ? 1.15 : 1
        Behavior on scale { WeatherSpring {} }

        Item {
            id: popper
            anchors.fill: parent

            // Без якорей: аниматоры двигают x/y обёртки от нуля
            WeatherMotion {
                width: parent.width
                height: parent.height
                visible: !root.colored
                motion: root.glyphMotion[root.name] ?? "drift"
                amp: root.size
                running: root.animating && !root.colored

                Text {
                    anchors.centerIn: parent
                    text: root.name
                    color: root.tint
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: root.size
                    // Наведённый значок заливается
                    font.variableAxes: ({ "FILL": fillAxis })
                    property real fillAxis: root.hovered ? 1 : 0
                    Behavior on fillAxis { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Tokens.animationSlow } }
                }
            }

            Repeater {
                model: root.colored ? root.parts : []
                Item {
                    id: piece
                    required property var modelData
                    x: root.size * piece.modelData.x
                    y: root.size * piece.modelData.y
                    width: root.size * piece.modelData.scale
                    height: width

                    WeatherMotion {
                        width: piece.width
                        height: piece.height
                        motion: root.partMotion[piece.modelData.part] ?? ""
                        amp: root.size
                        running: root.animating

                        WeatherGradientGlyph {
                            size: piece.width
                            part: piece.modelData.part
                            from: piece.modelData.from
                            to: piece.modelData.to
                        }
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: popAnim
        ScaleAnimator { target: popper; from: 0.6; to: 1; duration: Tokens.animationSlow; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        OpacityAnimator { target: popper; from: 0; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
    }
}
