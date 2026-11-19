pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Widgets
import "../../shell/theme"

// Потребление ресурса (settings.kind): круг с названием и процентом,
// вокруг — волнистое кольцо длиной в долю занятого
Item {
    id: root

    property var settings: ({})
    property bool editing: false

    readonly property var colors: Tokens.colors
    readonly property string kind: settings.kind ?? "cpu"
    readonly property var titles: ({ disk: "DISK", ram: "RAM", cpu: "CPU", gpu: "GPU" })
    readonly property real size: Math.min(width, height)
    readonly property bool showAmount: settings.showUsed === true && (kind === "ram" || kind === "disk")

    function format(v: real): string {
        const gb = v / 1073741824;
        if (gb >= 1000)
            return (gb / 1024).toFixed(2) + " TB";
        return (gb >= 100 ? gb.toFixed(0) : gb.toFixed(1)) + " GB";
    }

    SysmonSource {
        id: source
        kind: root.kind
        interval: root.settings.interval
    }

    WavyRing {
        id: ring
        anchors.centerIn: parent
        width: root.size
        height: root.size
        stroke: Math.max(2, root.size * 0.035)
        amplitude: root.size * 0.022
        value: source.fraction
    }

    ClippingRectangle {
        id: face
        anchors.centerIn: parent
        width: root.size * 0.74
        height: width
        radius: width / 2
        color: root.colors.surface_container_high

        LiquidFill {
            anchors.fill: parent
            level: source.fraction
            phase: ring.phase
            amplitude: ring.amplitude
            wavelength: ring.wavelength
        }

        Column {
            anchors.centerIn: parent
            z: 1
            spacing: Math.round(root.size * 0.02)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.titles[root.kind] ?? ""
                color: root.colors.on_surface_variant
                font.family: Tokens.typography.family
                font.pixelSize: Math.max(Tokens.scaled(10), Math.round(face.width * 0.13))
                font.weight: Font.Medium
                font.letterSpacing: face.width * 0.0065
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: source.ready ? Math.round(source.fraction * 100) + "%" : "—"
                color: root.colors.on_surface
                font.family: Tokens.typography.family
                font.pixelSize: Math.max(Tokens.scaled(12), Math.round(face.width * 0.24))
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showAmount && source.ready
                text: root.format(source.used)
                color: root.colors.on_surface_variant
                font.family: Tokens.typography.family
                font.pixelSize: Math.max(Tokens.scaled(9), Math.round(face.width * 0.1))
                font.features: { "tnum": 1 }
            }
        }
    }
}
