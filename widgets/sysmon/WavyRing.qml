import QtQuick
import QtQuick.Shapes
import "../../shell/theme"

// Волнистая «змейка» длиной value (0..1) от окружности, начало — сверху.
// Стоит на месте, волна бежит вдоль неё (фаза)
Item {
    id: root

    property real value: 0
    property real stroke: 4
    property real amplitude: 3
    property color color: Tokens.colors.primary

    property real shown: value
    Behavior on shown { NumberAnimation { duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic } }

    // false — волна замирает (окно «Система» ставит на время сдвига вкладок)
    property bool animate: true
    property real phase: 0
    NumberAnimation on phase {
        running: root.visible && root.animate
        from: 0; to: 2 * Math.PI
        duration: 1600
        loops: Animation.Infinite
    }

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real radius: Math.max(1, Math.min(width, height) / 2 - amplitude - stroke / 2)
    readonly property int waves: Math.max(8, Math.round(2 * Math.PI * radius / (stroke * 5)))
    readonly property real wavelength: 2 * Math.PI * radius / waves

    readonly property var points: {
        const n = Math.ceil(waves * 12 * shown);
        const end = shown * 2 * Math.PI;
        const pts = [];
        for (let i = 0; i <= n; i++) {
            const t = n > 0 ? end * i / n : 0;
            const r = radius + amplitude * Math.sin(waves * t - phase);
            pts.push(Qt.point(cx + r * Math.sin(t), cy - r * Math.cos(t)));
        }
        return pts;
    }

    Shape {
        anchors.fill: parent
        visible: root.shown > 0.002
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.points }
        }
    }
}
