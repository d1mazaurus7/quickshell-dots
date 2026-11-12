pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../../shell/theme"

// Карточка окна погоды: непрозрачная (палитра) или «стекло» — размытое небо окна под ней.
// owner — WeatherPanel (цвета, масштаб, режим), blurSource — размытая копия неба в координатах панели со сдвигом owner.bleed.
// topRadius/bottomRadius — скругления углов (карточки в группе); при нажатии углы пружинисто
// скругляются до полного (M3 Expressive), смена скруглений тоже анимирована.
Item {
    id: card

    required property Item owner
    required property Item blurSource
    property bool interactive: false
    property real topRadius: p.cardRadius
    property real bottomRadius: p.cardRadius
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    default property alias content: inner.data

    signal clicked()

    readonly property var p: owner
    readonly property bool glass: p.glass

    property real tr: pressed ? Math.max(topRadius, p.cardRadius) : topRadius
    property real br: pressed ? Math.max(bottomRadius, p.cardRadius) : bottomRadius
    Behavior on tr { WeatherSpring {} }
    Behavior on br { WeatherSpring {} }

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
        topLeftRadius: card.tr
        topRightRadius: card.tr
        bottomLeftRadius: card.br
        bottomRightRadius: card.br
        color: card.p.colors.surface_container
        opacity: card.glass ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
    }

    Rectangle {
        id: mask
        anchors.fill: parent
        topLeftRadius: card.tr
        topRightRadius: card.tr
        bottomLeftRadius: card.br
        bottomRightRadius: card.br
        visible: false
        layer.enabled: card.glass
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
            // Размытое небо уменьшено в p.blurScale раз
            sourceRect: Qt.rect((card.origin.x + card.p.bleed) / card.p.blurScale, (card.origin.y + card.p.bleed) / card.p.blurScale,
                                card.width / card.p.blurScale, card.height / card.p.blurScale)
        }
    }

    // Подложка «стекла» и слой состояния M3 (8% наведение, 12% нажатие)
    Rectangle {
        anchors.fill: parent
        topLeftRadius: card.tr
        topRightRadius: card.tr
        bottomLeftRadius: card.br
        bottomRightRadius: card.br
        color: card.glass ? card.p.alpha(card.p.white, 0.10) : "transparent"
        border.width: card.p.glassBorders ? 1 : 0
        border.color: card.p.alpha(card.p.white, 0.18)
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: card.tr
        topRightRadius: card.tr
        bottomLeftRadius: card.br
        bottomRightRadius: card.br
        color: card.p.cardText
        opacity: card.pressed ? 0.12 : card.hovered ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
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
