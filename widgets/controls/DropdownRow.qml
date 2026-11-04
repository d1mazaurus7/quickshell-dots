pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Строка настройки: подпись и выпадающий список (вид — settings/controls/SettingDropdown.qml).
// Список раскрывается внутри строки и раздвигает соседей — не обрезается прокруткой панели.
// options: [{ value, label }], value — текущее значение
Item {
    id: root

    property string text
    property var options: []
    property var value
    property bool expanded: false
    property int fieldWidth: Tokens.scaled(170)

    signal selected(var value)

    readonly property var colors: Tokens.colors
    readonly property var current: options.find(o => o.value === value) ?? null
    readonly property int gap: Tokens.spacingSmallV
    property real reveal: expanded ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    implicitWidth: label.implicitWidth + fieldWidth + Tokens.spacingLarge
    implicitHeight: field.height + (popup.height + gap) * reveal
    clip: true

    Text {
        id: label
        anchors.left: parent.left
        anchors.right: field.left
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: field.verticalCenter
        text: root.text
        elide: Text.ElideRight
        color: root.colors.on_surface
        font: Tokens.fontMedium
    }

    Rectangle {
        id: field
        anchors.right: parent.right
        width: root.fieldWidth
        height: Tokens.scaled(36)
        radius: Tokens.radiusMedium
        color: fieldArea.pressed ? root.colors.surface_container_highest
             : fieldArea.containsMouse ? root.colors.surface_container_high
             : root.colors.surface_container_low
        border.width: Tokens.borderWidth
        border.color: root.expanded ? root.colors.primary : root.colors.outline_variant
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Tokens.animationFast } }

        Text {
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.leftMargin: Tokens.spacingMedium
            anchors.rightMargin: Tokens.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.current?.label ?? ""
            color: root.colors.on_surface
            font: Tokens.fontMedium
        }

        Text {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            color: root.colors.on_surface_variant
            font: Tokens.fontLarge
            rotation: root.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            id: fieldArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: WidgetSound.click()
            onClicked: root.expanded = !root.expanded
        }
    }

    Rectangle {
        id: popup
        anchors.right: parent.right
        y: field.height + root.gap - Tokens.spacingMediumV * (1 - root.reveal)
        width: root.fieldWidth
        height: list.implicitHeight + Tokens.spacingSmallV * 2
        radius: Tokens.radiusMedium
        color: root.colors.surface_container_high
        border.width: Tokens.borderWidth
        border.color: root.colors.outline_variant
        opacity: root.reveal
        visible: opacity > 0

        Column {
            id: list
            x: Tokens.spacingSmall
            y: Tokens.spacingSmallV
            width: parent.width - Tokens.spacingSmall * 2
            spacing: 2

            Repeater {
                model: root.options

                Rectangle {
                    id: option
                    required property var modelData
                    readonly property bool active: root.value === modelData.value

                    width: list.width
                    height: Tokens.scaled(32)
                    radius: Tokens.radiusSmall
                    color: active ? root.colors.secondary_container
                         : optionArea.containsMouse ? root.colors.surface_container_highest
                         : "transparent"
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Tokens.spacingMedium
                        anchors.rightMargin: Tokens.spacingMedium
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: option.modelData.label
                        color: option.active ? root.colors.on_secondary_container : root.colors.on_surface
                        font: Tokens.fontMedium
                    }

                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: WidgetSound.click()
                        onClicked: {
                            if (!option.active)
                                root.selected(option.modelData.value);
                            root.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
