pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../../shell/config"
import "../../shell/theme"

// Заставка при включении снега: полотно выезжает, надпись прыгает по буквам, полотно уезжает
PanelWindow {
    id: root

    required property var modelData
    signal finished

    readonly property var colors: Tokens.colors
    readonly property var parts: ["Let it snow, ", "let it snow, ", "let it snow!!!"]
    // Пауза между частями, в «буквах»
    readonly property int partGap: 14
    // Длительность прыжка одной буквы, в «буквах»
    readonly property real letterSpan: 6
    readonly property int letterStep: 40
    readonly property real fontSize: Math.round(Math.min(height * 0.085, width / 24))
    // Насколько волны выступают за край полотна
    readonly property real waveReach: Math.round(width * 0.12)
    // Сплошной запас полотна за краем экрана: перелёт пружины не открывает волны
    readonly property real edgePad: Math.round(width * 0.07)
    readonly property real travel: width + edgePad + waveReach * 2
    readonly property int slideDuration: 2200
    readonly property real totalUnits: partStart(parts.length - 1) + parts[parts.length - 1].length + letterSpan
    // Сколько «букв» уже показано: общий драйвер для всех букв
    property real progress: 0
    // Бегущая фаза волн
    property real flow: 0
    // Моменты появления букв (без пробелов), в «буквах»
    readonly property var letterStarts: {
        const res = [];
        for (let i = 0; i < parts.length; i++) {
            const st = partStart(i);
            for (let j = 0; j < parts[i].length; j++)
                if (parts[i][j] !== " ")
                    res.push(st + j);
        }
        return res;
    }
    property int nextLetter: 0
    // Звук один на все экраны
    readonly property bool playsSound: modelData === Quickshell.screens[0] && Config.options.sound.interactionSounds

    onProgressChanged: {
        let hit = false;
        while (nextLetter < letterStarts.length && progress >= letterStarts[nextLetter]) {
            nextLetter++;
            hit = true;
        }
        if (hit && playsSound)
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/list.wav")]);
    }

    NumberAnimation on flow {
        from: 0
        to: 2 * Math.PI
        duration: 2500
        loops: Animation.Infinite
    }

    function partStart(index) {
        let n = 0;
        for (let i = 0; i < index; i++)
            n += parts[i].length + partGap;
        return n;
    }

    // Волнистый слой полотна: правый край вниз, левый вверх
    component WaveLayer: Shape {
        id: wave

        property color fill
        property real extent
        property real amp
        property real wavelength
        property real phase
        // Скорость бега волны, оборотов фазы за цикл flow
        property int speed: 1

        function edge(y) {
            const a = 2 * Math.PI * y / wavelength + phase - root.flow * speed;
            return root.edgePad + extent + amp * (0.7 * Math.sin(a) + 0.3 * Math.sin(2 * a + 1));
        }

        readonly property var points: {
            const w = sheet.width, h = sheet.height, n = 64, pts = [];
            for (let i = 0; i <= n; i++) {
                const y = h * i / n;
                pts.push(Qt.point(w + edge(y), y));
            }
            for (let i = n; i >= 0; i--) {
                const y = h * i / n;
                pts.push(Qt.point(-edge(y + wavelength * 0.37), y));
            }
            return pts;
        }

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: wave.fill
            strokeColor: "transparent"
            PathPolyline { path: wave.points }
        }
    }

    // Material You «печенька»: круг с волнистым контуром, медленно вращается
    component Cookie: Shape {
        id: cookie

        property color fill
        property int lobes: 9
        property real depth: 0.07
        property int period: 60000

        readonly property var points: {
            const r = width / 2, n = 180, pts = [];
            for (let i = 0; i <= n; i++) {
                const t = 2 * Math.PI * i / n;
                const k = r * (1 - depth + depth * Math.cos(lobes * t));
                pts.push(Qt.point(r + k * Math.cos(t), r + k * Math.sin(t)));
            }
            return pts;
        }

        height: width
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: cookie.fill
            strokeColor: "transparent"
            PathPolyline { path: cookie.points }
        }

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: cookie.period
            loops: Animation.Infinite
        }
    }

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs:snow-intro"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Item {
        id: sheet

        width: root.width
        height: root.height
        x: -root.travel

        WaveLayer {
            fill: root.colors.tertiary
            extent: root.waveReach * 1.3
            amp: root.waveReach * 0.35
            wavelength: sheet.height * 0.9
            phase: 0.4
        }
        WaveLayer {
            fill: root.colors.secondary
            extent: root.waveReach * 0.85
            amp: root.waveReach * 0.3
            wavelength: sheet.height * 0.75
            phase: 2.1
            speed: 2
        }
        WaveLayer {
            fill: root.colors.primary
            extent: root.waveReach * 0.5
            amp: root.waveReach * 0.25
            wavelength: sheet.height * 0.6
            phase: 3.6
            speed: 1
        }
        WaveLayer {
            fill: root.colors.surface_container
            extent: root.waveReach * 0.18
            amp: root.waveReach * 0.18
            wavelength: sheet.height * 0.5
            phase: 5
            speed: 2
        }

        // Фон: крупные M3-фигуры; обрезка по сплошной части полотна
        Item {
            x: -root.edgePad
            width: parent.width + root.edgePad * 2
            height: parent.height
            clip: true
            opacity: 0.6

            Item {
                x: root.edgePad
                width: sheet.width
                height: sheet.height

                Cookie {
                    width: sheet.height * 0.55
                    x: -width * 0.25
                    y: -width * 0.3
                    fill: root.colors.surface_container_highest
                }
                Cookie {
                    width: sheet.height * 0.42
                    x: sheet.width - width * 0.7
                    y: sheet.height - width * 0.75
                    fill: root.colors.surface_container_highest
                    lobes: 4
                    depth: 0.16
                    period: 80000
                }
                Cookie {
                    width: sheet.height * 0.22
                    x: sheet.width * 0.72
                    y: sheet.height * 0.08
                    fill: root.colors.surface_container_highest
                    lobes: 6
                    depth: 0.1
                    period: 45000
                }
                Cookie {
                    width: sheet.height * 0.16
                    x: sheet.width * 0.14
                    y: sheet.height * 0.74
                    fill: root.colors.surface_container_highest
                    lobes: 12
                    depth: 0.05
                    period: 50000
                }
            }
        }

        Row {
            anchors.centerIn: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.colors.primary
                shadowBlur: 1
                shadowOpacity: 0.9
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
                blurMax: 40
            }

            Repeater {
                model: root.parts

                Row {
                    id: part

                    required property string modelData
                    required property int index
                    readonly property int start: root.partStart(index)
                    readonly property int snowAt: modelData.indexOf("snow")

                    Repeater {
                        model: part.modelData.split("")

                        Text {
                            id: letter

                            required property string modelData
                            required property int index
                            // Локальная фаза прыжка 0..1
                            readonly property real t: Math.max(0, Math.min(1, (root.progress - part.start - index) / root.letterSpan))

                            text: modelData
                            width: modelData === " " ? root.fontSize * 0.28 : implicitWidth
                            color: modelData === "!" || index >= part.snowAt && index < part.snowAt + 4 ? root.colors.primary : root.colors.on_surface
                            font.family: Tokens.fontLarge.family
                            font.pixelSize: root.fontSize
                            font.weight: Font.DemiBold
                            opacity: Math.min(1, t * 4)
                            // Два затухающих прыжка
                            transform: Translate {
                                y: letter.t > 0 && letter.t < 1 ? -root.fontSize * 0.45 * Math.abs(Math.sin(2 * Math.PI * letter.t)) * Math.pow(1 - letter.t, 1.4) : 0
                            }
                        }
                    }
                }
            }
        }
    }

    // Запуск после получения размера окна: иначе from/to считаются от нулевой ширины
    SequentialAnimation {
        running: root.width > 0 && root.height > 0

        NumberAnimation {
            target: sheet
            property: "x"
            from: -root.travel
            to: 0
            duration: root.slideDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.8
        }
        NumberAnimation {
            target: root
            property: "progress"
            from: 0
            to: root.totalUnits
            duration: root.totalUnits * root.letterStep
        }
        PauseAnimation {
            duration: 1600
        }
        NumberAnimation {
            target: sheet
            property: "x"
            to: root.travel
            duration: root.slideDuration
            easing.type: Easing.InBack
            easing.overshoot: 0.8
        }
        ScriptAction {
            script: root.finished()
        }
    }
}
