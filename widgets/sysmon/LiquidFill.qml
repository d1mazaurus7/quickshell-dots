import QtQuick
import QtQuick.Shapes
import "../../shell/theme"

// Заливка снизу до level (0..1) с волной на поверхности; phase и wavelength —
// общие со змейкой, чтобы волны совпадали по виду и движению
Shape {
    id: root

    property real level: 0
    property real phase: 0
    property real amplitude: 3
    property real wavelength: 20
    property color color: Tokens.colors.primary_container

    property real shown: level
    Behavior on shown { NumberAnimation { duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic } }

    visible: shown > 0.002
    preferredRendererType: Shape.CurveRenderer

    readonly property var points: {
        const y0 = height * (1 - shown);
        const k = 2 * Math.PI / Math.max(1, wavelength);
        const step = Math.max(2, wavelength / 12);
        const pts = [];
        for (let x = 0; x < width + step; x += step) {
            const px = Math.min(x, width);
            pts.push(Qt.point(px, y0 + amplitude * Math.sin(px * k + phase)));
        }
        pts.push(Qt.point(width, height), Qt.point(0, height), pts[0]);
        return pts;
    }

    ShapePath {
        strokeColor: "transparent"
        fillColor: root.color
        PathPolyline { path: root.points }
    }
}
