pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../shell/theme"

// Плашка показателя в карточке текущей погоды: значок и значение. owner — WeatherPanel.
// Плашки стоят группой: leftRadius/rightRadius — скругления краёв (крайние — большие).
// При наведении углы пружинисто скругляются, значок заливается и увеличивается.
// В режиме «стекла» размывает небо под собой, как WeatherCard.
Item {
    id: stat

    required property Item owner
    required property Item blurSource
    required property string icon
    required property string text
    property real leftRadius: big
    property real rightRadius: big
    readonly property var p: owner
    readonly property bool glass: p.glass
    readonly property real big: Math.round(Tokens.radiusLarge * p.zoom)
    readonly property bool hovered: hover.hovered

    property real lr: hovered ? big : leftRadius
    property real rr: hovered ? big : rightRadius
    Behavior on lr { WeatherSpring {} }
    Behavior on rr { WeatherSpring {} }

    // Положение относительно панели; чтение x/y предков делает привязку живой
    readonly property point origin: {
        let x = 0, y = 0;
        for (let it = stat; it && it !== stat.owner; it = it.parent) {
            x += it.x;
            y += it.y;
        }
        return Qt.point(x, y);
    }

    Layout.fillWidth: true
    implicitHeight: statCol.implicitHeight + p.sp(Tokens.spacingMediumV) * 2

    HoverHandler { id: hover }

    Rectangle {
        id: mask
        anchors.fill: parent
        topLeftRadius: stat.lr
        bottomLeftRadius: stat.lr
        topRightRadius: stat.rr
        bottomRightRadius: stat.rr
        visible: false
        layer.enabled: stat.glass
    }

    Item {
        anchors.fill: parent
        visible: stat.glass
        layer.enabled: stat.glass
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: stat.glass ? stat.blurSource : null
            // Размытое небо уменьшено в p.blurScale раз
            sourceRect: Qt.rect((stat.origin.x + stat.p.bleed) / stat.p.blurScale, (stat.origin.y + stat.p.bleed) / stat.p.blurScale,
                                stat.width / stat.p.blurScale, stat.height / stat.p.blurScale)
            hideSource: true
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: stat.lr
        bottomLeftRadius: stat.lr
        topRightRadius: stat.rr
        bottomRightRadius: stat.rr
        color: stat.glass ? stat.p.alpha(stat.p.white, stat.hovered ? 0.18 : 0.10)
                          : stat.p.alpha(stat.p.heroText, stat.hovered ? 0.22 : 0.14)
        border.width: stat.p.glassBorders ? 1 : 0
        border.color: stat.p.alpha(stat.p.white, 0.18)
        Behavior on color { ColorAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
    }

    Column {
        id: statCol
        anchors.centerIn: parent
        spacing: stat.p.sp(Tokens.spacingSmallV)

        WeatherIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: stat.icon
            color: stat.p.alpha(stat.p.heroText, stat.hovered ? 1 : 0.8)
            font.pixelSize: stat.p.px(18)
            filled: stat.hovered
            hovered: stat.hovered
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        }
        WeatherText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: stat.text
            color: stat.p.heroText
            font.pixelSize: stat.p.fontS
        }
    }
}
