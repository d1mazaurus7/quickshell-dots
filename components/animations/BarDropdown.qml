pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import "../../theme" as Theme
import "../../shell/theme"

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
    property int barRadius: Tokens.radius(20)
    property color fillColor: Theme.Palette.background
    property int animDuration: 220
    // Прижать окно к правому краю бара: правого «уха» нет, правая кромка
    // продолжает край бара (нижний правый угол бара владелец делает прямым).
    property bool alignRight: false
    readonly property int rightEar: alignRight ? 0 : earRadius

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
    implicitWidth: contentWidth + earRadius + rightEar
    implicitHeight: fullHeight

    // Верх окна совпадает с нижней кромкой бара, тело — под anchorItem,
    // но не ближе к краю бара, чем его нижнее скругление.
    anchor.window: anchorItem.QsWindow.window
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.onAnchoring: {
        const win = root.anchorItem.QsWindow.window;
        const pos = root.anchorItem.QsWindow.itemPosition(root.anchorItem);
        const minX = root.barRadius + root.earRadius;
        const maxX = win.width - minX - root.contentWidth;
        const bodyX = root.alignRight ? win.width - root.contentWidth
            : Math.max(minX, Math.min(maxX, pos.x + root.anchorItem.width / 2 - root.contentWidth / 2));
        root.anchor.rect.x = bodyX - root.earRadius;
        root.anchor.rect.y = win.height - 1;
    }

    onVisibleChanged: {
        if (!visible && open) {
            dismissedAt = Date.now();
            dismissed();
        }
    }

    // Фон цвета бара: вогнутые скругления сверху, обычные углы снизу.
    // Пока окно раскрывается, вертикальные радиусы сжимаются вместе с высотой.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: bg

            readonly property real w: root.width
            readonly property real h: root.revealHeight
            readonly property real er: root.earRadius
            readonly property real erY: Math.min(er, h / 2)
            readonly property real rer: root.rightEar
            readonly property real rerY: Math.min(rer, h / 2)
            readonly property real br: root.radius
            readonly property real brY: Math.min(br, h / 2)

            strokeWidth: -1
            fillColor: root.fillColor

            startX: 0; startY: 0
            PathLine { x: bg.w; y: 0 }
            PathArc { x: bg.w - bg.rer; y: bg.rerY; radiusX: bg.rer; radiusY: bg.rerY; direction: PathArc.Counterclockwise }
            PathLine { x: bg.w - bg.rer; y: bg.h - bg.brY }
            PathArc { x: bg.w - bg.rer - bg.br; y: bg.h; radiusX: bg.br; radiusY: bg.brY }
            PathLine { x: bg.er + bg.br; y: bg.h }
            PathArc { x: bg.er; y: bg.h - bg.brY; radiusX: bg.br; radiusY: bg.brY }
            PathLine { x: bg.er; y: bg.erY }
            PathArc { x: 0; y: 0; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
        }
    }

    Item {
        x: root.earRadius
        width: root.contentWidth
        height: root.revealHeight
        clip: true

        Item {
            id: body
            x: root.padding
            y: root.padding
            width: parent.width - root.padding * 2
            height: childrenRect.height
        }
    }
}
