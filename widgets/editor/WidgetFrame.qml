pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/theme"
import "../controls"
import ".."

// Рамка виджета в редакторе: выбор по клику, перетаскивание в режиме перемещения;
// у типов с resizable — ресайз за края, с flippable — кнопки отражения flipH/flipV
Item {
    id: root

    required property string uid
    required property WidgetsState widgets
    required property var editorScreen

    readonly property var item: widgets.byUid[uid] ?? null
    readonly property var entry: item ? widgets.find(item.type) : null
    readonly property var geo: widgets.geometry(uid)
    readonly property bool selected: widgets.selectedUid === uid
    readonly property bool movable: selected && widgets.moveMode
    readonly property bool resizable: selected && entry?.resizable === true
    readonly property var settings: item ? widgets.settingsOf(uid) : ({})
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

    // Кнопки отражения над правым краем выбранного виджета
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.top
        anchors.bottomMargin: Tokens.scaled(10)
        spacing: Tokens.spacingSmall
        opacity: root.selected && root.entry?.flippable === true ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }

        IconButton {
            size: Tokens.scaled(26)
            icon: "swap_horiz"
            checked: root.settings.flipH === true
            onClicked: root.widgets.setSetting(root.uid, "flipH", !checked)
        }
        IconButton {
            size: Tokens.scaled(26)
            icon: "swap_vert"
            checked: root.settings.flipV === true
            onClicked: root.widgets.setSetting(root.uid, "flipV", !checked)
        }
    }

    // Ручки ресайза: hx/hy — сторона по оси (-1 левая/верхняя, 1 правая/нижняя, 0 — нет)
    Repeater {
        model: [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]]

        MouseArea {
            id: handle

            required property var modelData
            readonly property int hx: modelData[0]
            readonly property int hy: modelData[1]
            readonly property real thick: Tokens.scaled(14)
            property var start: null

            visible: root.resizable
            x: hx < 0 ? -thick / 2 : hx > 0 ? root.width - thick / 2 : thick / 2
            y: hy < 0 ? -thick / 2 : hy > 0 ? root.height - thick / 2 : thick / 2
            width: hx === 0 ? root.width - thick : thick
            height: hy === 0 ? root.height - thick : thick
            hoverEnabled: true
            preventStealing: true
            cursorShape: hx === 0 ? Qt.SizeVerCursor : hy === 0 ? Qt.SizeHorCursor
                : hx === hy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

            Rectangle {
                anchors.centerIn: parent
                width: handle.hx === 0 ? Tokens.scaled(32) : Tokens.scaled(8)
                height: handle.hy === 0 ? Tokens.scaled(32) : Tokens.scaled(8)
                radius: Math.min(width, height) / 2
                color: root.colors.primary
                opacity: handle.pressed || handle.containsMouse ? 1 : 0
                scale: handle.pressed ? 1.2 : 1
                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
            }

            onPressed: mouse => {
                const p = mapToItem(root.parent, mouse.x, mouse.y);
                start = { px: p.x, py: p.y, x: root.x, y: root.y, w: root.width, h: root.height };
                root.widgets.startPreview(root.uid);
            }
            onPositionChanged: mouse => {
                if (!start)
                    return;
                const p = mapToItem(root.parent, mouse.x, mouse.y);
                const s = start;
                const grid = root.widgets.cfg.grid;
                const g = root.widgets.cfg.gridSize;
                const snap = v => grid ? Math.round(v / g) * g : v;
                const minW = Tokens.scaled(root.entry.minWidth);
                const minH = Tokens.scaled(root.entry.minHeight);
                let l = s.x, t = s.y, r = s.x + s.w, b = s.y + s.h;
                if (hx < 0)
                    l = Math.max(0, Math.min(r - minW, snap(s.x + p.x - s.px)));
                else if (hx > 0)
                    r = Math.min(root.parent.width, Math.max(l + minW, snap(r + p.x - s.px)));
                if (hy < 0)
                    t = Math.max(0, Math.min(b - minH, snap(s.y + p.y - s.py)));
                else if (hy > 0)
                    b = Math.min(root.parent.height, Math.max(t + minH, snap(b + p.y - s.py)));
                root.widgets.previewX = l;
                root.widgets.previewY = t;
                root.widgets.previewWidth = r - l;
                root.widgets.previewHeight = b - t;
            }
            onReleased: {
                start = null;
                root.widgets.commitPreview();
            }
            onCanceled: {
                start = null;
                root.widgets.commitPreview();
            }
        }
    }
}
