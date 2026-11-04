pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../shell/theme"

// Плашка показателя в карточке текущей погоды: значок и значение. owner — WeatherPanel.
// В режиме «стекла» размывает небо под собой, как WeatherCard.
Item {
    id: stat

    required property Item owner
    required property Item blurSource
    required property string icon
    required property string text
    readonly property var p: owner
    readonly property bool glass: p.glass
    readonly property int radius: Math.round(Tokens.radiusMedium * p.zoom)

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

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: stat.radius
        visible: false
        layer.enabled: true
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
            sourceRect: Qt.rect(stat.origin.x + stat.p.bleed, stat.origin.y + stat.p.bleed, stat.width, stat.height)
            hideSource: true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: stat.radius
        color: stat.glass ? stat.p.alpha(stat.p.white, 0.10) : stat.p.alpha(stat.p.heroText, 0.14)
        border.width: stat.p.glassBorders ? 1 : 0
        border.color: stat.p.alpha(stat.p.white, 0.18)
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
    }

    Column {
        id: statCol
        anchors.centerIn: parent
        spacing: stat.p.sp(Tokens.spacingSmallV)

        WeatherIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: stat.icon
            color: stat.p.alpha(stat.p.heroText, 0.8)
            font.pixelSize: stat.p.px(18)
        }
        WeatherText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: stat.text
            color: stat.p.heroText
            font.pixelSize: stat.p.fontS
        }
    }
}
