import QtQuick
import "../../shell/theme"

// Дочерние настройки: отступ и линия слева от родителя.
// shown: false — группа плавно сворачивается
Item {
    id: root

    property bool shown: true
    default property alias content: column.data
    property alias spacing: column.spacing

    readonly property int indent: Tokens.spacingLarge

    implicitHeight: shown ? column.implicitHeight : 0
    height: implicitHeight
    opacity: shown ? 1 : 0
    visible: height > 0
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    Rectangle {
        x: Math.round(root.indent / 2) - 1
        width: Math.max(1, Tokens.scaled(2))
        height: column.implicitHeight
        radius: width / 2
        color: Tokens.colors.outline_variant
    }

    Column {
        id: column
        x: root.indent
        width: root.width - root.indent
        spacing: Tokens.spacingMediumV
    }
}
