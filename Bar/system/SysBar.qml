import QtQuick
import "../../shell/theme"

// Строка с иконкой, подписью, значением и полосой заполнения
Item {
    id: root

    property string icon
    property string label
    property string value
    property real progress: 0
    property bool warn: false
    property color accent: warn ? colors.error : colors.primary
    readonly property var colors: Tokens.colors
    readonly property bool hovered: hover.hovered

    property real shown: Math.max(0, Math.min(1, progress))
    Behavior on shown { NumberAnimation { duration: Tokens.animationSlow * 2; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] } }

    implicitHeight: Tokens.scaled(42)

    HoverHandler { id: hover }

    SysIcon {
        id: ico
        anchors.left: parent.left
        anchors.top: parent.top
        width: Tokens.scaled(22)
        icon: root.icon
        size: Tokens.scaled(17)
        filled: root.hovered || root.warn
        hovered: root.hovered
        color: root.hovered || root.warn ? root.accent : root.colors.on_surface_variant
    }

    SysText {
        anchors.left: ico.right
        anchors.leftMargin: Tokens.spacingMedium
        anchors.right: val.left
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: ico.verticalCenter
        text: root.label
        font: Tokens.fontMedium
        color: root.colors.on_surface_variant
    }

    SysText {
        id: val
        anchors.right: parent.right
        anchors.verticalCenter: ico.verticalCenter
        text: root.value
        font.family: Tokens.fontMedium.family
        font.pixelSize: Tokens.fontMedium.pixelSize
        font.weight: Font.Medium
        color: root.warn ? root.colors.error : root.colors.on_surface
    }

    Rectangle {
        id: track
        anchors.left: ico.right
        anchors.leftMargin: Tokens.spacingMedium
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.scaled(4)
        height: root.hovered ? Tokens.scaled(8) : Tokens.scaled(6)
        radius: height / 2
        color: Qt.alpha(root.accent, 0.16)
        Behavior on height { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

        Rectangle {
            width: Math.max(track.height, track.width * root.shown)
            height: parent.height
            radius: height / 2
            color: root.accent
            opacity: root.shown > 0.002 ? 1 : 0
            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
        }
    }
}
