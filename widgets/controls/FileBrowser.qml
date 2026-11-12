pragma ComponentBehavior: Bound
import QtQuick
import Qt.labs.folderlistmodel
import "../../shell/theme"

// Обзор файловой системы: папки и файлы по nameFilters, превью картинок (у видео — значок).
// folder — стартовая папка (путь), value — выбранный путь, selected(path) — выбор файла
Column {
    id: root

    property string folder
    property var nameFilters: []
    property var videoSuffixes: []
    property string value
    property int columns: 4
    property int rows: 3

    signal selected(string path)

    readonly property var colors: Tokens.colors
    property string path: folder
    readonly property real cell: (width - Tokens.spacingSmall * (columns - 1)) / columns

    spacing: Tokens.spacingSmall

    FolderListModel {
        id: files
        folder: "file://" + root.path
        nameFilters: root.nameFilters
        showDirsFirst: true
        showDotAndDotDot: false
        sortCaseSensitive: false
        caseSensitive: false
    }

    Row {
        width: parent.width
        spacing: Tokens.spacingSmall

        IconButton {
            id: up
            icon: "arrow_upward"
            size: Tokens.scaled(32)
            enabled: root.path !== "/"
            onClicked: root.path = root.path.slice(0, root.path.lastIndexOf("/")) || "/"
        }
        Text {
            width: parent.width - up.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            text: root.path
            color: root.colors.on_surface_variant
            font: Tokens.fontSmall
            elide: Text.ElideLeft
        }
    }

    GridView {
        id: grid
        width: parent.width + Tokens.spacingSmall
        height: root.rows * cellHeight
        clip: true
        cellWidth: root.cell + Tokens.spacingSmall
        cellHeight: cellWidth
        boundsBehavior: Flickable.StopAtBounds
        model: files

        delegate: Rectangle {
            id: tile
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            readonly property bool active: root.value === filePath
            // fileSuffix — всё после первой точки, поэтому расширение берётся по последней
            readonly property bool video: root.videoSuffixes.includes(fileName.slice(fileName.lastIndexOf(".") + 1).toLowerCase())

            width: root.cell
            height: root.cell
            radius: Tokens.radiusMedium
            color: root.colors.surface_container_high
            border.width: active ? Tokens.scaled(2) : Tokens.borderWidth
            border.color: active ? root.colors.primary : root.colors.outline_variant
            clip: true
            scale: area.pressed ? 0.95 : 1
            Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: Tokens.animationFast } }

            Image {
                anchors.fill: parent
                anchors.margins: tile.border.width
                visible: status === Image.Ready
                source: tile.fileIsDir || tile.video ? "" : "file://" + tile.filePath.split("/").map(encodeURIComponent).join("/")
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                asynchronous: true
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - Tokens.spacingSmall * 2
                visible: tile.fileIsDir || tile.video

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.fileIsDir ? "folder" : "movie"
                    color: tile.fileIsDir ? root.colors.primary : root.colors.on_surface_variant
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Math.round(root.cell * 0.4)
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.fileName
                    color: root.colors.on_surface_variant
                    font: Tokens.fontSmall
                    elide: Text.ElideMiddle
                }
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
                onClicked: {
                    if (tile.fileIsDir)
                        root.path = tile.filePath;
                    else
                        root.selected(tile.filePath);
                }
            }
        }
    }
}
