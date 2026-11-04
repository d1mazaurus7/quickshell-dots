import QtQuick
import "../../shell/theme"

// Строка настройки: подпись и переключатель Material.
// Ручка перетекает к другому краю, растягиваясь на ходу
Item {
    id: root

    property string text
    property bool checked: false

    signal toggled(bool checked)

    readonly property var colors: Tokens.colors

    implicitWidth: label.implicitWidth + track.width + Tokens.spacingLarge
    implicitHeight: Math.max(label.implicitHeight, track.height)

    onCheckedChanged: stretchAnim.restart()

    Text {
        id: label
        anchors.left: parent.left
        anchors.right: track.left
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        elide: Text.ElideRight
        color: root.colors.on_surface
        font: Tokens.fontMedium
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.scaled(44)
        height: Tokens.scaled(26)
        radius: height / 2
        color: root.checked ? root.colors.primary : root.colors.surface_container_highest
        border.width: Math.max(1, Tokens.scaled(2))
        border.color: root.checked ? root.colors.primary : root.colors.outline
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
        Behavior on border.color { ColorAnimation { duration: Tokens.animationMedium } }

        Rectangle {
            id: thumb
            readonly property int full: track.height - Tokens.scaled(8)
            property int knob: area.pressed ? full + Tokens.scaled(2) : root.checked ? full : Math.round(full * 0.65)
            property real stretch: 0
            property real center: root.checked ? track.width - track.height / 2 : track.height / 2

            x: center - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: knob + stretch
            height: knob
            radius: height / 2
            color: root.checked ? root.colors.on_primary : root.colors.outline
            Behavior on center { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on knob { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
        }
    }

    SequentialAnimation {
        id: stretchAnim
        NumberAnimation {
            target: thumb
            property: "stretch"
            to: Tokens.scaled(6)
            duration: Tokens.animationMedium / 2
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: thumb
            property: "stretch"
            to: 0
            duration: Tokens.animationMedium
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: WidgetSound.click()
        onClicked: root.toggled(!root.checked)
    }
}
