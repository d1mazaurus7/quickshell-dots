import QtQuick
import "../../shell/theme"

// Плавно раскрывающийся по ширине блок панели инструментов
Item {
    id: root

    property bool open: false
    default property alias content: inner.data

    width: open ? inner.implicitWidth : 0
    height: inner.implicitHeight
    visible: width > 0
    clip: true
    Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    Row {
        id: inner
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacingSmall
        opacity: root.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    }
}
