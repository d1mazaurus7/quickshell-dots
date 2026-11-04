pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../../shell/theme"

// Карточка окна погоды: непрозрачная (палитра) или «стекло» — размытое небо окна под ней.
// owner — WeatherPanel (цвета, масштаб, режим), blurSource — размытая копия неба в координатах панели со сдвигом owner.bleed.
Item {
    id: card

    required property Item owner
    required property Item blurSource
    property bool interactive: false
    default property alias content: inner.data

    signal clicked()

    readonly property var p: owner
    readonly property bool glass: p.glass

    // Положение относительно панели; чтение x/y предков делает привязку живой
    readonly property point origin: {
        let x = 0, y = 0;
        for (let it = card; it && it !== card.owner; it = it.parent) {
            x += it.x;
            y += it.y;
        }
        return Qt.point(x, y);
    }

    implicitHeight: inner.height + p.sp(Tokens.spacingMediumV) * 2

    Rectangle {
        anchors.fill: parent
        radius: card.p.cardRadius
        color: card.p.colors.surface_container
        opacity: card.glass ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        radius: card.p.cardRadius
        visible: false
        layer.enabled: true
    }

    Item {
        anchors.fill: parent
        visible: card.glass
        layer.enabled: card.glass
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: card.glass ? card.blurSource : null
            // Размытое небо видно только сквозь карточки
            hideSource: true
            sourceRect: Qt.rect(card.origin.x + card.p.bleed, card.origin.y + card.p.bleed, card.width, card.height)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: card.p.cardRadius
        color: area.pressed ? card.p.alpha(card.p.cardText, 0.14)
             : area.containsMouse ? card.p.alpha(card.p.cardText, 0.08)
             : card.glass ? card.p.alpha(card.p.white, 0.10) : "transparent"
        border.width: card.p.glassBorders ? 1 : 0
        border.color: card.p.alpha(card.p.white, 0.18)
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: card.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.clicked()
    }

    Item {
        id: inner
        x: card.p.sp(Tokens.spacingLarge)
        y: card.p.sp(Tokens.spacingMediumV)
        width: card.width - x * 2
        height: childrenRect.height
    }
}
