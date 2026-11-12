import QtQuick
import "../../shell/theme"

// Подсветка текущего элемента ListView/GridView.
// Использование: highlight: FlowHighlight { view: myList }
Rectangle {
    id: root

    property var view: null
    property color highlightColor: FlowHighlightAnimation.highlightColor
    property color selectedTextColor: FlowHighlightAnimation.selectedTextColor
    property real animationDuration: FlowHighlightAnimation.animationDuration
    property real highlightRadius: FlowHighlightAnimation.highlightRadius
    property real highlightOpacity: FlowHighlightAnimation.highlightOpacity
    property real selectedScale: FlowHighlightAnimation.selectedScale
    property bool smoothScroll: FlowHighlightAnimation.smoothScroll
    property int highlightZOrder: FlowHighlightAnimation.highlightZOrder

    readonly property var _item: view ? view.currentItem : null

    property rect _from: Qt.rect(0, 0, 0, 0)
    property rect _target: Qt.rect(0, 0, 0, 0)
    property real _progress: 1
    property bool _placed: false

    color: highlightColor
    radius: Tokens.radius(highlightRadius)
    opacity: _item ? highlightOpacity : 0
    scale: _item ? selectedScale : 1
    transformOrigin: Item.Center
    z: highlightZOrder

    Behavior on opacity {
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }

    function _lerp(a, b, t) {
        return a + (b - a) * t
    }

    function _lead(p) {
        return 1 - Math.pow(1 - p, 3)
    }

    function _trail(p) {
        return p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2
    }

    // Анимация считается в координатах окна просмотра: цель берётся с учётом
    // конечной позиции прокрутки, а к результату добавляется текущий contentY.
    // Благодаря этому выделение не «отскакивает», когда список прокручивается
    // у границы: оно стоит на месте, а содержимое едет под ним. Передняя грань
    // обгоняет заднюю — выделение «перетекает». На дальних прыжках (например,
    // с конца списка в начало) растяжение отключается.
    function _update() {
        var cx = view ? view.contentX : 0
        var cy = view ? view.contentY : 0
        var endY = scrollAnim.running ? scrollAnim.to : cy
        var f = _from
        var t = Qt.rect(_target.x - cx, _target.y - endY, _target.width, _target.height)
        var p = _progress

        var dx = (t.x + t.width / 2) - (f.x + f.width / 2)
        var dy = (t.y + t.height / 2) - (f.y + f.height / 2)
        var stretchX = Math.abs(dx) <= 3 * t.width
        var stretchY = Math.abs(dy) <= 3 * t.height

        var lead = _lead(p)
        var trail = _trail(p)

        var right = dx >= 0
        var down = dy >= 0

        var l = _lerp(f.x, t.x, stretchX && right ? trail : lead)
        var r = _lerp(f.x + f.width, t.x + t.width, stretchX && !right ? trail : lead)
        var top = _lerp(f.y, t.y, stretchY && down ? trail : lead)
        var bottom = _lerp(f.y + f.height, t.y + t.height, stretchY && !down ? trail : lead)

        var maxW = 2 * t.width
        var maxH = 2 * t.height
        if (r - l > maxW) {
            if (right) l = r - maxW
            else r = l + maxW
        }
        if (bottom - top > maxH) {
            if (down) top = bottom - maxH
            else bottom = top + maxH
        }

        x = l + cx
        y = top + cy
        width = Math.max(0, r - l)
        height = Math.max(0, bottom - top)
    }

    function _ensureVisible() {
        if (!smoothScroll || !view || !_item || view.contentY === undefined)
            return

        var it = _item
        var minY = view.originY
        var maxY = Math.max(minY, view.originY + view.contentHeight - view.height)
        var base = scrollAnim.running ? scrollAnim.to : view.contentY
        var to = base

        if (it.y < base)
            to = it.y
        else if (it.y + it.height > base + view.height)
            to = it.y + it.height - view.height

        to = Math.max(minY, Math.min(maxY, to))
        if (to === base)
            return

        scrollAnim.stop()
        scrollAnim.from = view.contentY
        scrollAnim.to = to
        scrollAnim.start()
    }

    function _syncTarget() {
        var it = _item
        if (!it)
            return

        var t = _target
        if (t.x === it.x && t.y === it.y && t.width === it.width && t.height === it.height)
            return

        _target = Qt.rect(it.x, it.y, it.width, it.height)
        _ensureVisible()
        _update()
    }

    function _retarget() {
        var it = _item
        if (!it)
            return

        var t = Qt.rect(it.x, it.y, it.width, it.height)
        var cx = view ? view.contentX : 0
        var cy = view ? view.contentY : 0
        flowAnim.stop()

        if (!_placed) {
            _placed = true
            _from = Qt.rect(t.x - cx, t.y - cy, t.width, t.height)
            _target = t
            _progress = 1
        } else {
            _from = Qt.rect(x - cx, y - cy, width, height)
            _target = t
            _progress = 0
            flowAnim.start()
        }

        _ensureVisible()
        _update()
    }

    on_ItemChanged: _retarget()
    on_ProgressChanged: _update()

    Connections {
        target: root._item
        function onXChanged() { root._syncTarget() }
        function onYChanged() { root._syncTarget() }
        function onWidthChanged() { root._syncTarget() }
        function onHeightChanged() { root._syncTarget() }
    }

    Connections {
        target: root.view
        function onContentXChanged() { root._update() }
        function onContentYChanged() { root._update() }
    }

    NumberAnimation {
        id: flowAnim
        target: root
        property: "_progress"
        from: 0
        to: 1
        duration: root.animationDuration
        easing.type: Easing.Linear
    }

    NumberAnimation {
        id: scrollAnim
        target: root.view
        property: "contentY"
        duration: root.animationDuration
        easing.type: Easing.OutCubic
    }

    Component.onCompleted: {
        if (view)
            view.highlightFollowsCurrentItem = false
        _retarget()
    }
}
