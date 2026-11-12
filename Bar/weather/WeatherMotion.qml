import QtQuick
import "../../shell/theme"

// Обёртка (части) значка погоды с фоновой анимацией на render-потоке.
// motion: pulse | rock | drift | driftBack | fall | float | flicker | spin; amp — размер значка.
// Анимация создаётся при первом запуске (у значков, которые ни разу не ожили, её нет);
// при остановке цикл доигрывается до положения покоя (alwaysRunToEnd).
Item {
    id: m

    property string motion: ""
    property bool running: false
    property real amp: 24
    // Длительности следуют общей шкале анимаций; при выключенных анимациях циклы не запускаются
    readonly property real k: Tokens.animationSlow / 300
    readonly property bool on: running && k > 0 && motion !== ""
    readonly property real drift: amp * (motion === "driftBack" ? -0.06 : 0.06)

    property Animation anim: null

    function ensure() {
        if (!on || anim)
            return;
        const c = { pulse: pulse, rock: rock, drift: driftC, driftBack: driftC, fall: fall,
                    float: floatC, flicker: flicker, spin: spin }[motion];
        if (c)
            anim = c.createObject(m);
    }
    onOnChanged: ensure()
    onMotionChanged: {
        if (anim) {
            anim.destroy();
            anim = null;
            x = 0; y = 0; scale = 1; rotation = 0; opacity = 1;
        }
        ensure();
    }

    Component {
        id: pulse
        SequentialAnimation {
            running: m.on
            loops: Animation.Infinite
            alwaysRunToEnd: true
            ScaleAnimator { target: m; from: 1; to: 1.08; duration: 1200 * m.k; easing.type: Easing.InOutSine }
            ScaleAnimator { target: m; from: 1.08; to: 1; duration: 1200 * m.k; easing.type: Easing.InOutSine }
        }
    }

    Component {
        id: rock
        SequentialAnimation {
            running: m.on
            loops: Animation.Infinite
            alwaysRunToEnd: true
            RotationAnimator { target: m; from: 0; to: 10; duration: 700 * m.k; easing.type: Easing.InOutSine }
            RotationAnimator { target: m; from: 10; to: -10; duration: 1400 * m.k; easing.type: Easing.InOutSine }
            RotationAnimator { target: m; from: -10; to: 0; duration: 700 * m.k; easing.type: Easing.InOutSine }
        }
    }

    Component {
        id: driftC
        SequentialAnimation {
            running: m.on
            loops: Animation.Infinite
            alwaysRunToEnd: true
            XAnimator { target: m; from: 0; to: m.drift; duration: 1300 * m.k; easing.type: Easing.InOutSine }
            XAnimator { target: m; from: m.drift; to: 0; duration: 1300 * m.k; easing.type: Easing.InOutSine }
        }
    }

    Component {
        id: floatC
        SequentialAnimation {
            running: m.on
            loops: Animation.Infinite
            alwaysRunToEnd: true
            YAnimator { target: m; from: 0; to: -m.amp * 0.06; duration: 900 * m.k; easing.type: Easing.InOutSine }
            YAnimator { target: m; from: -m.amp * 0.06; to: 0; duration: 900 * m.k; easing.type: Easing.InOutSine }
        }
    }

    // Капли: падают, тают и снова появляются чуть выше
    Component {
        id: fall
        SequentialAnimation {
            running: m.on
            loops: Animation.Infinite
            alwaysRunToEnd: true
            ParallelAnimation {
                YAnimator { target: m; from: 0; to: m.amp * 0.08; duration: 800 * m.k; easing.type: Easing.InQuad }
                OpacityAnimator { target: m; from: 1; to: 0.2; duration: 800 * m.k; easing.type: Easing.InQuad }
            }
            ParallelAnimation {
                YAnimator { target: m; from: -m.amp * 0.04; to: 0; duration: 300 * m.k; easing.type: Easing.OutQuad }
                OpacityAnimator { target: m; from: 0.2; to: 1; duration: 300 * m.k; easing.type: Easing.OutQuad }
            }
        }
    }

    // Молния: редкие короткие вспышки
    Component {
        id: flicker
        SequentialAnimation {
            running: m.on
            loops: Animation.Infinite
            alwaysRunToEnd: true
            PauseAnimation { duration: 1400 * m.k }
            OpacityAnimator { target: m; to: 0.25; duration: 70 * m.k }
            OpacityAnimator { target: m; to: 1; duration: 70 * m.k }
            OpacityAnimator { target: m; to: 0.4; duration: 70 * m.k }
            OpacityAnimator { target: m; to: 1; duration: 120 * m.k }
        }
    }

    // Глиф солнца симметричен через 45°: оборот на 45° незаметно зацикливается
    Component {
        id: spin
        RotationAnimator {
            target: m
            from: 0
            to: 45
            duration: 3000 * m.k
            loops: Animation.Infinite
            alwaysRunToEnd: true
            running: m.on
        }
    }
}
