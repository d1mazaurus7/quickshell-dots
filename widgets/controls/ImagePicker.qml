pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import "../../shell/theme"

// Сетка превью файлов из папки (gif анимируются при наведении и у выбранного).
// value — имя выбранного файла, selected(name) — выбор
Item {
    id: root

    property url folder
    property var nameFilters: ["*.gif"]
    property string value
    property int columns: 4

    signal selected(string name)

    readonly property var colors: Tokens.colors
    readonly property real cell: (width - grid.spacing * (columns - 1)) / columns

    implicitHeight: grid.implicitHeight

    FolderListModel {
        id: files
        folder: root.folder
        nameFilters: root.nameFilters
        showDirs: false
    }

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: Tokens.spacingSmall

        Repeater {
            model: files

            Rectangle {
                id: tile
                required property string fileName
                required property url fileUrl
                readonly property bool active: root.value === fileName

                width: root.cell
                height: root.cell
                radius: Tokens.radiusMedium
                color: root.colors.surface_container_high
                border.width: active ? Tokens.scaled(2) : Tokens.borderWidth
                border.color: active ? root.colors.primary : root.colors.outline_variant
                scale: area.pressed ? 0.95 : 1
                Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
                Behavior on border.color { ColorAnimation { duration: Tokens.animationFast } }

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacingSmall
                    source: tile.fileUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    playing: area.containsMouse || tile.active
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.colors.on_surface
                    opacity: area.pressed ? 0.12 : area.containsMouse ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: WidgetSound.click()
                    onClicked: root.selected(tile.fileName)
                }
            }
        }
    }
}
