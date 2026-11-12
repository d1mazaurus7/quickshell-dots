import QtQuick
import QtQuick.Shapes
import "../../../theme" as Theme

// Волновой индикатор прогресса MD3 expressive: активная часть — бегущая волна
// (при паузе плавно выпрямляется), ручка с зазорами, неактивная — прямая дорожка.
// Волна строится один раз на ширину и только сдвигается — путь каждый кадр не пересчитывается.
Item {
    id: wp

    required property real s
    property real value: 0
    property bool playing: false
    property bool interactive: true
    property color activeColor: Theme.Palette.primary
    property color inactiveColor: Theme.Palette.secondary_container
    property real stroke: Math.max(2, Math.round(4 * s))
    property real wavelength: 32 * s
    property real amplitude: playing ? 3 * s : 0

    readonly property bool pressed: area.pressed
    property real dragValue: 0
    readonly property real shown: pressed ? dragValue : Math.max(0, Math.min(1, value))
    property real handleW: pressed ? 3 * s : 5 * s
    readonly property real gapW: 5 * s
    readonly property real hx: handleW / 2 + (width - handleW) * shown
    readonly property real activeW: Math.max(0, hx - handleW / 2 - gapW)
    readonly property real center: height / 2

    // Отпустили ручку — перемотать (0..1)
    signal seek(real v)

    implicitHeight: 24 * s

    Behavior on amplitude { Smooth {} }
    Behavior on handleW { Smooth { duration: 120 } }

    // Смещение волны по y в точке x пути (квадратичные полуволны, как в wavePath)
    function waveY(x: real): real {
        const h = wavelength / 2;
        const k = Math.floor(x / h);
        const u = (x - k * h) / h;
        return center + (k % 2 === 0 ? -1 : 1) * 4 * amplitude * u * (1 - u);
    }

    readonly property string wavePath: {
        const h = wavelength / 2;
        const end = width + wavelength;
        let d = "M 0 " + center;
        let up = true;
        for (let x = 0; x < end; x += h) {
            d += " Q " + (x + h / 2) + " " + (center + (up ? -2 : 2) * amplitude) + " " + (x + h) + " " + center;
            up = !up;
        }
        return d;
    }

    Item {
        id: activeClip
        width: wp.activeW
        height: parent.height
        clip: true
        visible: width > 0

        Shape {
            id: wave
            property real phase: 0
            x: -phase
            width: wp.width + wp.wavelength
            height: parent.height
            preferredRendererType: Shape.CurveRenderer

            NumberAnimation on phase {
                from: 0
                to: wp.wavelength
                duration: 1800
                loops: Animation.Infinite
                running: wp.playing && wp.visible
            }

            ShapePath {
                strokeColor: wp.activeColor
                strokeWidth: wp.stroke
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: wp.wavePath }
            }
        }
    }

    // Скруглённые концы волны (обрезка клипом даёт плоский срез)
    Rectangle {
        visible: activeClip.visible
        x: -width / 2
        y: wp.waveY(wave.phase) - height / 2
        width: wp.stroke
        height: width
        radius: width / 2
        color: wp.activeColor
    }
    Rectangle {
        visible: activeClip.visible
        x: wp.activeW - width / 2
        y: wp.waveY(wp.activeW + wave.phase) - height / 2
        width: wp.stroke
        height: width
        radius: width / 2
        color: wp.activeColor
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: wp.hx + wp.handleW / 2 + wp.gapW
        width: Math.max(0, wp.width - x)
        height: wp.stroke
        radius: height / 2
        visible: width > 0
        color: wp.inactiveColor
    }

    Rectangle {
        x: wp.hx - wp.handleW / 2
        anchors.verticalCenter: parent.verticalCenter
        width: wp.handleW
        height: parent.height
        radius: width / 2
        color: wp.activeColor
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: wp.interactive
        hoverEnabled: true
        preventStealing: true
        cursorShape: wp.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        function at(x: real): real {
            return Math.max(0, Math.min(1, (x - wp.handleW / 2) / (wp.width - wp.handleW)));
        }
        onPressed: mouse => wp.dragValue = at(mouse.x)
        onPositionChanged: mouse => { if (pressed) wp.dragValue = at(mouse.x); }
        onReleased: wp.seek(wp.dragValue)
    }
}
