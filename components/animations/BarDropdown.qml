pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/bar"
import "BarDropdownStack.js" as DropdownStack

// Окно, "выплывающее" из нижней кромки бара под элементом anchorItem.
// Сверху вогнутые скругления ("уши") плавно переходят в бар.
// Подробности и пример: README.md рядом.
PopupWindow {
    id: root

    // Элемент бара, под которым центрируется окно.
    required property Item anchorItem
    // Открыто ли окно; управляется владельцем.
    property bool open: false

    property int contentWidth: 320
    property int padding: 12
    property int radius: Tokens.radius(16)
    // Радиус вогнутых скруглений в месте стыка с баром.
    property int earRadius: Tokens.radius(16)
    // Радиус нижних углов бара: уши не должны заходить на них.
    property int barRadius: BarStyle.radius
    // Окно срастается с заливкой бара «ушами»; без заливки (модульный стиль) —
    // отдельная плашка со скруглёнными углами и отступом от бара.
    property bool attached: BarStyle.filled
    readonly property int ear: attached ? earRadius : 0
    readonly property int topRadius: attached ? 0 : radius
    readonly property int gap: attached ? 0 : BarStyle.popupGap
    property color fillColor: Theme.Palette.background
    property int animDuration: 220
    // Прижать окно к правому краю бара: правого «уха» нет, правая кромка
    // продолжает край бара (нижний правый угол бара владелец делает прямым).
    property bool alignRight: false
    readonly property int rightEar: alignRight ? 0 : ear
    // Окно постоянного размера (0 — по содержимому): смена ширины и высоты
    // открытого окна анимируется фигурой без ресайза самого окна.
    property int maxContentWidth: 0
    property int maxHeight: 0
    readonly property real windowContentWidth: Math.max(contentWidth, maxContentWidth)
    // Видимая ширина: плавно догоняет contentWidth (только при maxContentWidth).
    property real shownWidth: contentWidth
    Behavior on shownWidth {
        enabled: root.maxContentWidth > 0 && root.visible
        NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic }
    }
    // Фигура прижата к правому краю окна, если оно шире видимой части.
    readonly property real shapeX: windowContentWidth - shownWidth

    // Содержимое кладётся сюда; дочерним элементам — width: parent.width.
    default property alias content: body.data

    // Окно закрыто композитором (клик вне него). Владелец должен сбросить open.
    signal dismissed()

    // Момент последнего dismissed(): клик по кнопке, который закрыл окно
    // (клик вне его), не должен тут же открыть его снова.
    property double dismissedAt: 0
    function recentlyDismissed(): bool {
        return Date.now() - dismissedAt < 200;
    }

    readonly property real fullHeight: body.childrenRect.height + padding * 2
    property real revealHeight: open ? fullHeight : 0

    Behavior on revealHeight { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

    // Окно остаётся видимым, пока идёт анимация закрытия.
    visible: open || revealHeight > 0
    grabFocus: true
    color: "transparent"
    implicitWidth: windowContentWidth + ear + rightEar
    implicitHeight: Math.max(maxHeight, fullHeight)
    // Ввод только в видимой фигуре: клик по прозрачной части закрывает окно.
    mask: Region { item: maskItem }

    // Верх окна совпадает с нижней кромкой бара, тело — под anchorItem,
    // но не ближе к краю бара, чем его нижнее скругление.
    anchor.window: anchorItem.QsWindow.window
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.rect.width: 1
    anchor.rect.height: 1
    // Левый верхний угол окна в координатах бара.
    property real originX: 0
    property real originY: 0
    // Dropdown, к которому Qt прикрепил это окно (null — к бару).
    property var nestParent: null

    anchor.onAnchoring: {
        const win = root.anchorItem.QsWindow.window;
        const pos = root.anchorItem.QsWindow.itemPosition(root.anchorItem);
        const minX = root.barRadius + root.ear;
        const maxX = win.width - minX - root.windowContentWidth;
        const bodyX = root.alignRight ? win.width - root.windowContentWidth
            : Math.max(minX, Math.min(maxX, pos.x + root.anchorItem.width / 2 - root.windowContentWidth / 2));
        root.originX = bodyX - root.ear;
        root.originY = win.height + root.gap;

        // Окно ещё не показано — оно будет создано дочерним к верхнему
        // видимому dropdown'у; запоминаем его на всё время показа.
        if (!root.visible) {
            const top = DropdownStack.top();
            root.nestParent = top && top !== root && top.anchor.window === root.anchor.window ? top : null;
        }

        const p = root.nestParent;
        root.anchor.rect.x = p ? root.originX - p.originX : root.originX;
        root.anchor.rect.y = (p ? root.originY - p.originY : root.originY) - 1;
    }

    // Esc закрывает окно так же, как клик вне его — с анимацией сворачивания.
    // Клавиши приходят во всплывающее окно (пока у родителя есть клавиатура),
    // Shortcut здесь не срабатывает — ловим через Keys на элементе с фокусом.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: if (root.open) root.dismissed()
    }

    // Размер изменился у открытого окна (например, из настроек) — пересчитать позицию.
    onImplicitWidthChanged: if (visible) anchor.updateAnchor()
    onImplicitHeightChanged: if (visible) anchor.updateAnchor()

    Component.onDestruction: {
        if (visible)
            BarStyle.openPopups -= 1;
        DropdownStack.remove(root);
    }

    onVisibleChanged: {
        BarStyle.openPopups += visible ? 1 : -1;
        if (visible) {
            DropdownStack.push(root);
        } else {
            DropdownStack.remove(root);
            nestParent = null;
        }
        if (!visible && open) {
            dismissedAt = Date.now();
            dismissed();
        }
    }

    // Фон цвета бара: вогнутые скругления сверху, обычные углы снизу.
    // Пока окно раскрывается, вертикальные радиусы сжимаются вместе с высотой.
    Item {
        id: maskItem
        x: root.shapeX
        width: root.shownWidth + root.ear + root.rightEar
        height: root.revealHeight
    }

    Shape {
        x: root.shapeX
        width: root.shownWidth + root.ear + root.rightEar
        height: parent.height
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: bg

            readonly property real w: root.shownWidth + root.ear + root.rightEar
            readonly property real h: root.revealHeight
            readonly property real er: root.ear
            readonly property real erY: Math.min(er, h / 2)
            readonly property real rer: root.rightEar
            readonly property real rerY: Math.min(rer, h / 2)
            readonly property real br: root.radius
            readonly property real brY: Math.min(br, h / 2)
            // Верхние углы: у прикреплённого окна вместо них «уши»
            readonly property real tr: root.topRadius
            readonly property real trY: Math.min(tr, h / 2)

            strokeWidth: -1
            fillColor: root.fillColor

            // Дуги нулевого радиуса (ухо или верхний угол, которых нет) вырождаются в точку
            startX: bg.tr; startY: 0
            PathLine { x: bg.w - bg.tr; y: 0 }
            PathArc { x: bg.w; y: bg.trY; radiusX: bg.tr; radiusY: bg.trY }
            PathArc { x: bg.w - bg.rer; y: bg.trY + bg.rerY; radiusX: bg.rer; radiusY: bg.rerY; direction: PathArc.Counterclockwise }
            PathLine { x: bg.w - bg.rer; y: bg.h - bg.brY }
            PathArc { x: bg.w - bg.rer - bg.br; y: bg.h; radiusX: bg.br; radiusY: bg.brY }
            PathLine { x: bg.er + bg.br; y: bg.h }
            PathArc { x: bg.er; y: bg.h - bg.brY; radiusX: bg.br; radiusY: bg.brY }
            PathLine { x: bg.er; y: bg.erY + bg.trY }
            PathArc { x: 0; y: bg.trY; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
            PathArc { x: bg.tr; y: 0; radiusX: bg.tr; radiusY: bg.trY }
        }
    }

    Item {
        x: root.shapeX + root.ear
        width: root.shownWidth
        height: root.revealHeight
        clip: true

        // Пока видимая ширина догоняет новую, содержимое прижато к правому краю.
        Item {
            id: body
            x: root.padding + root.shownWidth - root.contentWidth
            y: root.padding
            width: parent.width - root.padding * 2
            height: childrenRect.height
        }
    }
}
