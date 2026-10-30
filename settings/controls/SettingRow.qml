import QtQuick
import QtQuick.Layouts
import "../../shell/theme"

// Пункт настроек: название и описание слева, элемент управления справа
Rectangle {
    id: row

    property string title
    property string description
    default property alias control: slot.data

    readonly property var colors: Tokens.colors

    Layout.fillWidth: true
    implicitHeight: Math.max(texts.implicitHeight, slot.implicitHeight) + Tokens.spacingLargeV * 2
    radius: Tokens.radiusLarge
    color: colors.surface_container

    ColumnLayout {
        id: texts
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.leftMargin: Tokens.spacingLarge
        anchors.rightMargin: Tokens.spacingLarge
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: row.title
            color: row.colors.on_surface
            font: Tokens.fontMedium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: row.description !== ""
            text: row.description
            color: row.colors.on_surface_variant
            font: Tokens.fontSmall
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacingLarge
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
