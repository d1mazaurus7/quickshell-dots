import QtQuick
import "../../shell/theme"

// Фон из M3-фигур («печеньки» и искры), которые постоянно крутятся.
// При смене index текущий набор уезжает крутясь, новый въезжает с другой стороны;
// расстановка выбирается из presets по index и отражается по осям.
// Использование: M3ShapeField { anchors.fill: parent; index: n; running: window.visible }
Item {
    id: field

    // Номер состояния (раздел, страница); смена запускает переход
    property int index: 0
    // Вращение только пока виден хост (окно), иначе анимации стоят
    property bool running: true
    property var palette: Tokens.colors

    // Наборы фигур: rx/ry — центр в долях области, size — px до масштаба, period — оборот в мс,
    // color — роль палитры. Крупные фигуры выходят только за прямые края, не за углы
    property var presets: [
        [
            { lobes: 9, depth: 0.14, size: 340, rx: 1.0, ry: 0.62, color: "primary", alpha: 0.07, period: 120000 },
            { lobes: 12, depth: 0.1, size: 150, rx: 0.62, ry: 0.86, color: "tertiary", alpha: 0.08, period: 80000, reverse: true },
            { sparkle: true, size: 40, rx: 0.9, ry: 0.12, color: "primary", alpha: 0.3, period: 24000 },
            { sparkle: true, size: 24, rx: 0.45, ry: 0.92, color: "tertiary", alpha: 0.35, period: 18000, reverse: true }
        ],
        [
            { lobes: 6, depth: 0.22, size: 320, rx: 0.72, ry: 1.02, color: "tertiary", alpha: 0.07, period: 110000, reverse: true },
            { lobes: 4, depth: 0.2, size: 130, rx: 0.95, ry: 0.32, color: "primary", alpha: 0.08, period: 70000 },
            { sparkle: true, size: 36, rx: 0.42, ry: 0.8, color: "secondary", alpha: 0.35, period: 22000 },
            { sparkle: true, size: 22, rx: 0.84, ry: 0.56, color: "primary", alpha: 0.3, period: 16000, reverse: true }
        ],
        [
            { lobes: 16, depth: 0.06, size: 300, rx: 1.02, ry: 0.42, color: "secondary", alpha: 0.08, period: 140000 },
            { lobes: 7, depth: 0.14, size: 160, rx: 0.56, ry: 0.9, color: "primary", alpha: 0.07, period: 90000, reverse: true },
            { sparkle: true, size: 44, rx: 0.8, ry: 0.84, color: "tertiary", alpha: 0.3, period: 26000 },
            { sparkle: true, size: 20, rx: 0.92, ry: 0.1, color: "primary", alpha: 0.35, period: 15000, reverse: true }
        ]
    ]

    // Два набора по очереди: при смене index старый уезжает, новый въезжает
    property bool flip: false

    Component.onCompleted: {
        setA.preset = index;
        setA.opacity = 1;
    }
    onIndexChanged: {
        const out = flip ? setB : setA;
        const inn = flip ? setA : setB;
        // Сторона въезда и отражение расстановки меняются от состояния к состоянию
        const dirs = [[0, 1], [1, 0], [0, -1], [-1, 0]];
        const d = dirs[(index * 3 + 1) % 4];
        inn.preset = index;
        inn.mirrorX = index % 2 === 1;
        inn.mirrorY = Math.floor(index / 2) % 2 === 1;
        out.leave(d[0], d[1]);
        inn.enter(d[0], d[1]);
        flip = !flip;
    }

    ShapeSet { id: setA; presets: field.presets; palette: field.palette; windowVisible: field.running }
    ShapeSet { id: setB; presets: field.presets; palette: field.palette; windowVisible: field.running }

    component ShapeSet: Item {
        id: set
        property int preset
        property bool mirrorX: false
        property bool mirrorY: false
        property real spin: 0
        // Данные снаружи: inline-компонент не опирается на id окна
        property var presets: []
        property var palette
        property bool windowVisible: false
        readonly property bool live: windowVisible && opacity > 0
        readonly property real shift: Tokens.scaled(90)

        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        opacity: 0

        // dx, dy — направление движения (-1/0/1)
        function enter(dx, dy) {
            leaveAnim.stop();
            enterX.from = -dx * shift;
            enterY.from = -dy * shift;
            enterSpin.from = -90 * (dx + dy || 1);
            enterAnim.restart();
        }
        function leave(dx, dy) {
            enterAnim.stop();
            leaveX.to = dx * shift;
            leaveY.to = dy * shift;
            leaveSpin.to = spin + 120 * (dx + dy || 1);
            leaveAnim.restart();
        }

        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: set; property: "opacity"; from: 0; to: 1; duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic }
            NumberAnimation { id: enterX; target: set; property: "x"; to: 0; duration: Tokens.animationSlow * 3; easing.type: Easing.OutCubic }
            NumberAnimation { id: enterY; target: set; property: "y"; to: 0; duration: Tokens.animationSlow * 3; easing.type: Easing.OutCubic }
            NumberAnimation { target: set; property: "scale"; from: 0.85; to: 1; duration: Tokens.animationSlow * 3; easing.type: Easing.OutCubic }
            NumberAnimation { id: enterSpin; target: set; property: "spin"; to: 0; duration: Tokens.animationSlow * 4; easing.type: Easing.OutCubic }
        }

        ParallelAnimation {
            id: leaveAnim
            NumberAnimation { target: set; property: "opacity"; to: 0; duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic }
            NumberAnimation { id: leaveX; target: set; property: "x"; duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic }
            NumberAnimation { id: leaveY; target: set; property: "y"; duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic }
            NumberAnimation { target: set; property: "scale"; to: 1.1; duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic }
            NumberAnimation { id: leaveSpin; target: set; property: "spin"; duration: Tokens.animationSlow * 2; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: set.presets.length ? set.presets[set.preset % set.presets.length] : []

            M3Shape {
                required property var modelData

                size: Tokens.scaled(modelData.size)
                x: set.width * (set.mirrorX ? 1 - modelData.rx : modelData.rx) - size / 2
                y: set.height * (set.mirrorY ? 1 - modelData.ry : modelData.ry) - size / 2
                lobes: modelData.lobes || 0
                depth: modelData.depth || 0
                sparkle: modelData.sparkle === true
                fill: Qt.alpha(set.palette[modelData.color], modelData.alpha)
                period: modelData.period
                reverse: modelData.reverse === true
                active: set.live
                spin: set.spin
            }
        }
    }
}
