pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Список над полем ввода: команды или сохранённые чаты.
// items — массив { title, detail }; picked(index) — выбор кликом.
Rectangle {
    id: root

    property var items: []
    property int currentIndex: 0
    property bool shown: false
    property string emptyText
    property int maxRows: 6
    property font textFont: Tokens.fontMedium
    property font smallFont: Tokens.fontSmall

    signal picked(int index)

    readonly property var colors: Tokens.colors
    readonly property int rowHeight: Math.round(textFont.pixelSize * 1.4) + Tokens.spacingMediumV * 2
    readonly property int rows: Math.max(1, Math.min(items.length, maxRows))

    implicitHeight: shown ? rows * rowHeight + Tokens.spacingSmallV * 2 : 0
    opacity: shown ? 1 : 0
    visible: implicitHeight > 0
    radius: Tokens.radiusLarge
    color: colors.surface_container_high
    clip: true
    Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

    onCurrentIndexChanged: list.positionViewAtIndex(currentIndex, ListView.Contain)

    Text {
        anchors.centerIn: parent
        visible: root.items.length === 0
        text: root.emptyText
        color: root.colors.on_surface_variant
        font: root.smallFont
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Tokens.spacingSmall
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.items

        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool selected: index === root.currentIndex

            width: list.width
            height: root.rowHeight
            radius: Tokens.radiusMedium
            color: area.pressed ? root.colors.surface_container_highest
                 : row.selected ? root.colors.secondary_container
                 : area.containsMouse ? root.colors.surface_container_highest
                 : "transparent"
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

            Text {
                anchors.left: parent.left
                anchors.right: detail.left
                anchors.leftMargin: Tokens.spacingMedium
                anchors.rightMargin: Tokens.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.title
                color: row.selected ? root.colors.on_secondary_container : root.colors.on_surface
                font: root.textFont
                elide: Text.ElideRight
            }

            Text {
                id: detail
                anchors.right: parent.right
                anchors.rightMargin: Tokens.spacingMedium
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.detail
                color: row.selected ? root.colors.on_secondary_container : root.colors.on_surface_variant
                font: root.smallFont
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.currentIndex = row.index
                onClicked: root.picked(row.index)
            }
        }
    }
}
