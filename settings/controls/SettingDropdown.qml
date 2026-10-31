pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/theme"

// Выпадающий список строк. Список раскрывается поверх соседних пунктов:
// у родительского пункта нужно поднимать z, пока expanded.
Item {
    id: root

    property var model: []
    property string currentValue
    // Поле фильтра в списке
    property bool searchable: false
    // Отрисовывать каждый пункт его же шрифтом (для выбора шрифта)
    property bool fontPreview: false
    property int popupHeight: Tokens.scaled(280)
    property bool expanded: false

    signal activated(string value)

    readonly property var colors: Tokens.colors
    readonly property var filteredModel: model.filter(v =>
        v.toLowerCase().includes(filter.text.trim().toLowerCase()))

    implicitWidth: Tokens.scaled(280)
    implicitHeight: field.implicitHeight

    onExpandedChanged: {
        if (expanded) {
            filter.text = "";
            if (searchable)
                filter.forceActiveFocus();
            list.positionViewAtIndex(Math.max(0, filteredModel.indexOf(currentValue)), ListView.Center);
        }
    }

    // Поле с текущим значением
    Rectangle {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: Tokens.scaled(40)
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
            text: root.currentValue
            color: root.colors.on_surface
            font.family: root.fontPreview ? root.currentValue : Tokens.fontMedium.family
            font.pixelSize: Tokens.fontMedium.pixelSize
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
            onClicked: root.expanded = !root.expanded
        }
    }

    // Раскрывающийся список
    Rectangle {
        id: popup
        anchors.left: parent.left
        anchors.right: parent.right
        y: field.height + Tokens.spacingSmallV + (root.expanded ? 0 : -Tokens.spacingMediumV)
        // По содержимому, но не выше popupHeight — без пустого места у коротких списков
        height: Math.min(root.popupHeight, popupContent.implicitHeight + Tokens.spacingSmallV * 2)
        radius: Tokens.radiusMedium
        color: root.colors.surface_container_high
        border.width: Tokens.borderWidth
        border.color: root.colors.outline_variant
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        // Клики не проходят сквозь список
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: popupContent
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacingSmall
            anchors.rightMargin: Tokens.spacingSmall
            anchors.topMargin: Tokens.spacingSmallV
            anchors.bottomMargin: Tokens.spacingSmallV
            spacing: Tokens.spacingSmallV

            Rectangle {
                Layout.fillWidth: true
                visible: root.searchable
                implicitHeight: filter.implicitHeight + Tokens.spacingMediumV * 2
                radius: Tokens.radiusSmall
                color: root.colors.surface_container_highest

                TextInput {
                    id: filter
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacingMedium
                    anchors.rightMargin: Tokens.spacingMedium
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: root.colors.on_surface
                    selectionColor: root.colors.primary
                    selectedTextColor: root.colors.on_primary
                    font: Tokens.fontMedium

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !filter.text
                        text: "Поиск..."
                        color: root.colors.on_surface_variant
                        font: Tokens.fontMedium
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredModel

                delegate: Rectangle {
                    id: option
                    required property string modelData
                    readonly property bool selected: root.currentValue === modelData

                    width: list.width
                    implicitHeight: Tokens.scaled(36)
                    radius: Tokens.radiusSmall
                    color: selected ? root.colors.secondary_container
                         : optionArea.pressed ? root.colors.surface_container_highest
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
                        text: option.modelData
                        color: option.selected ? root.colors.on_secondary_container : root.colors.on_surface
                        font.family: root.fontPreview ? option.modelData : Tokens.fontMedium.family
                        font.pixelSize: Tokens.fontMedium.pixelSize
                    }

                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.activated(option.modelData);
                            root.expanded = false;
                        }
                    }
                }
            }
        }
    }
}
