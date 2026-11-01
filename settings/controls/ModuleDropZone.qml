pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/theme"

// Ячейка для блоков модулей: принимает ModuleChip и сообщает,
// на какую позицию его отпустили (порядок блоков = порядок модулей)
ColumnLayout {
    id: root

    // Подпись над ячейкой ("" — без подписи)
    property string title
    // Блоки: [{ id, title }]
    property var modules: []
    property Item dragLayer
    property real minHeight: Tokens.scaled(120)
    // Порядок важен: показывать метку места вставки
    property bool ordered: true

    signal dropped(string moduleId, int index)

    readonly property var colors: Tokens.colors
    // Позиция вставки под курсором, -1 — курсора над ячейкой нет
    property int insertIndex: -1

    spacing: Tokens.spacingMediumV

    // Сколько блоков стоит перед точкой p (сам перетаскиваемый блок не считается)
    function indexAt(p, source) {
        let n = 0;
        for (let i = 0; i < chips.count; i++) {
            const c = chips.itemAt(i);
            if (!c || c === source)
                continue;
            const before = c.y + c.height <= p.y
                || (p.y >= c.y && c.x + c.width / 2 < p.x);
            if (before)
                n++;
        }
        return n;
    }

    Text {
        visible: root.title !== ""
        Layout.leftMargin: Tokens.spacingSmall
        text: root.title
        color: root.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(2)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Math.max(root.minHeight, flow.implicitHeight + Tokens.spacingLargeV * 2)
        radius: Tokens.radiusLarge
        color: drop.containsDrag ? root.colors.surface_container_high : root.colors.surface_container
        border.width: drop.containsDrag ? 2 : Tokens.borderWidth
        border.color: drop.containsDrag ? root.colors.primary : root.colors.outline_variant
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

        Flow {
            id: flow
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacingLarge
            anchors.rightMargin: Tokens.spacingLarge
            anchors.topMargin: Tokens.spacingLargeV
            anchors.bottomMargin: Tokens.spacingLargeV
            spacing: Tokens.spacingMedium

            move: Transition {
                NumberAnimation { properties: "x,y"; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
            }

            Repeater {
                id: chips
                model: root.modules

                ModuleChip {
                    required property var modelData
                    moduleId: modelData.id
                    title: modelData.title
                    dragLayer: root.dragLayer
                }
            }
        }

        // Метка места вставки
        Rectangle {
            readonly property Item target: root.insertIndex >= 0 ? root.chipAfter(root.insertIndex) : null
            readonly property Item last: root.chipAfter(-1)
            visible: root.ordered && drop.containsDrag && root.insertIndex >= 0 && (target !== null || last !== null)
            width: 2
            radius: 1
            height: (target ?? last)?.height ?? 0
            x: flow.x + (target ? target.x - flow.spacing / 2 : (last ? last.x + last.width + flow.spacing / 2 : 0)) - 1
            y: flow.y + ((target ?? last)?.y ?? 0)
            color: root.colors.primary
        }

        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["barModule"]

            onPositionChanged: d => root.insertIndex = root.indexAt(mapToItem(flow, d.x, d.y), d.source)
            onExited: root.insertIndex = -1
            onDropped: d => {
                const index = root.indexAt(mapToItem(flow, d.x, d.y), d.source);
                root.insertIndex = -1;
                d.accept();
                root.dropped(d.source.moduleId, index);
            }
        }
    }

    // Блок, перед которым встаёт перетаскиваемый (index), или последний (-1); источник пропускается
    function chipAfter(index) {
        const source = drop.drag.source;
        let n = 0;
        let last = null;
        for (let i = 0; i < chips.count; i++) {
            const c = chips.itemAt(i);
            if (!c || c === source)
                continue;
            if (n === index)
                return c;
            last = c;
            n++;
        }
        return index < 0 ? last : null;
    }
}
