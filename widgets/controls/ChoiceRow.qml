pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Строка настройки: подпись и сегментированный выбор с перетекающим выделением.
// options: [{ value, label }], value — текущее значение
Item {
    id: root

    property string text
    property var options: []
    property var value

    signal selected(var value)

    readonly property var colors: Tokens.colors
    readonly property int activeIndex: options.findIndex(o => o.value === value)
    readonly property Item activeItem: repeater.count > 0 && activeIndex >= 0 ? repeater.itemAt(activeIndex) : null

    implicitWidth: label.implicitWidth + segments.width + Tokens.spacingLarge
    implicitHeight: Math.max(label.implicitHeight, segments.height)

    Text {
        id: label
        anchors.left: parent.left
        anchors.right: segments.left
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        elide: Text.ElideRight
        color: root.colors.on_surface
        font: Tokens.fontMedium
    }

    Rectangle {
        id: segments
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: row.implicitWidth
        height: Tokens.scaled(32)
        radius: height / 2
        color: "transparent"
        border.width: Math.max(1, Tokens.borderWidth)
        border.color: root.colors.outline_variant

        // Выделение переезжает к выбранному сегменту и подстраивается под его ширину
        Rectangle {
            visible: root.activeItem !== null
            x: root.activeItem?.x ?? 0
            width: root.activeItem?.width ?? 0
            height: parent.height
            radius: height / 2
            color: root.colors.secondary_container
            Behavior on x { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }

        Row {
            id: row
            height: parent.height

            Repeater {
                id: repeater
                model: root.options

                Item {
                    id: seg
                    required property var modelData
                    required property int index
                    readonly property bool active: root.activeIndex === index

                    width: segLabel.implicitWidth + Tokens.spacingLarge * 2
                    height: row.height

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.colors.on_surface
                        opacity: segArea.pressed ? 0.12 : segArea.containsMouse ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                    }

                    Text {
                        id: segLabel
                        anchors.centerIn: parent
                        text: seg.modelData.label
                        color: seg.active ? root.colors.on_secondary_container : root.colors.on_surface_variant
                        font: Tokens.fontSmall
                        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                    }

                    MouseArea {
                        id: segArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: WidgetSound.click()
                        onClicked: if (!seg.active) root.selected(seg.modelData.value)
                    }
                }
            }
        }
    }
}
