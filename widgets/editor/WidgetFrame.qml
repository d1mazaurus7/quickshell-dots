import QtQuick
import Quickshell
import "../../shell/theme"
import ".."

// Рамка виджета в редакторе: выбор по клику, перетаскивание в режиме перемещения
Item {
    id: root

    required property string uid
    required property WidgetsState widgets
    required property var editorScreen

    readonly property var item: widgets.byUid[uid] ?? null
    readonly property var entry: item ? widgets.registry.find(item.type) : null
    readonly property var geo: widgets.geometry(uid)
    readonly property bool selected: widgets.selectedUid === uid
    readonly property bool movable: selected && widgets.moveMode
    readonly property var colors: Tokens.colors

    visible: entry !== null
        && (Quickshell.screens.find(s => s.name === item.screen) ?? Quickshell.screens[0]) === editorScreen
    x: geo.x
    y: geo.y
    width: geo.width
    height: geo.height

    Rectangle {
        anchors.fill: parent
        anchors.margins: -Tokens.scaled(4)
        radius: Tokens.radius(Tokens.scaled(24))
        color: Qt.alpha(root.colors.primary, area.pressed && root.movable ? 0.12 : area.containsMouse ? 0.06 : 0)
        border.width: Tokens.scaled(2)
        border.color: root.selected ? root.colors.primary : Qt.alpha(root.colors.on_surface, area.containsMouse ? 0.6 : 0.3)
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        Behavior on border.color { ColorAnimation { duration: Tokens.animationFast } }
    }

    // Название над выбранным виджетом
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.scaled(10)
        width: titleRow.implicitWidth + Tokens.spacingMedium * 2
        height: Tokens.scaled(26)
        radius: height / 2
        color: root.colors.primary
        opacity: root.selected ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

        Row {
            id: titleRow
            anchors.centerIn: parent
            spacing: Tokens.spacingSmall

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.movable ? "open_with" : root.entry?.icon ?? ""
                color: root.colors.on_primary
                font.family: "Material Symbols Rounded"
                font.pixelSize: Tokens.scaled(16)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.entry?.title ?? ""
                color: root.colors.on_primary
                font: Tokens.fontSmall
            }
        }
    }

    MouseArea {
        id: area

        property real offsetX: 0
        property real offsetY: 0
        property bool dragging: false

        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.movable ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor

        onPressed: mouse => {
            root.widgets.addOpen = false;
            if (!root.selected) {
                root.widgets.selectedUid = root.uid;
                return;
            }
            if (!root.movable)
                return;
            const p = mapToItem(root.parent, mouse.x, mouse.y);
            offsetX = p.x - root.x;
            offsetY = p.y - root.y;
            root.widgets.startPreview(root.uid);
            dragging = true;
        }
        onPositionChanged: mouse => {
            if (!dragging)
                return;
            const p = mapToItem(root.parent, mouse.x, mouse.y);
            let nx = p.x - offsetX;
            let ny = p.y - offsetY;
            if (root.widgets.cfg.grid) {
                const s = root.widgets.cfg.gridSize;
                nx = Math.round(nx / s) * s;
                ny = Math.round(ny / s) * s;
            }
            root.widgets.previewX = Math.max(0, Math.min(root.parent.width - root.width, nx));
            root.widgets.previewY = Math.max(0, Math.min(root.parent.height - root.height, ny));
        }
        onReleased: {
            if (!dragging)
                return;
            dragging = false;
            root.widgets.commitPreview();
        }
        onCanceled: {
            dragging = false;
            root.widgets.commitPreview();
        }
    }
}
