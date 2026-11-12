pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import Quickshell
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/bar"

// Островок записи под правым краем бара: выезжает, пока курсор над этой
// частью бара или над самим островком. Без захвата ввода (не BarDropdown):
// всплывающее окно с grab нельзя вложить в окно без grab.
PopupWindow {
    id: root

    required property var service
    required property var barWindow
    // Курсор над зоной бара (отслеживает владелец)
    property bool zoneHovered: false
    // Например, открыт центр уведомлений у того же края
    property bool blocked: false

    readonly property bool pointer: zoneHovered || islandHover.hovered
    readonly property bool shown: service.recording && !blocked && (pointer || hideDelay.running)

    readonly property bool attached: BarStyle.filled
    readonly property int ear: attached ? Tokens.radius(16) : 0
    readonly property int radius: Tokens.radius(16)
    readonly property int gap: attached ? 0 : BarStyle.popupGap
    readonly property int padding: Tokens.scaled(8)
    readonly property int bodyWidth: row.implicitWidth + padding * 2
    readonly property real fullHeight: row.implicitHeight + padding * 2

    // Свёрнутый островок во время записи — узкая полоска-подсказка
    readonly property int peek: Tokens.scaled(6)
    readonly property bool hinted: service.recording && !blocked
    property real revealHeight: shown ? fullHeight : hinted ? peek : 0
    // 0 — полоска, 1 — островок раскрыт
    readonly property real progress: Math.max(0, Math.min(1, (revealHeight - peek) / (fullHeight - peek)))
    readonly property bool expanded: revealHeight > peek
    Behavior on revealHeight { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

    // Переход курсора с бара на островок не должен его схлопывать
    onPointerChanged: if (!pointer) hideDelay.restart()
    Timer { id: hideDelay; interval: 250 }

    visible: revealHeight > 0
    color: "transparent"
    implicitWidth: bodyWidth + ear
    implicitHeight: fullHeight
    mask: Region { item: maskItem }

    anchor.window: barWindow
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.rect.x: barWindow.width - implicitWidth
    anchor.rect.y: barWindow.height + gap - 1
    anchor.rect.width: 1
    anchor.rect.height: 1
    onImplicitWidthChanged: if (visible) anchor.updateAnchor()

    // Пока островок раскрыт, автоскрытие не прячет бар (полоска не держит)
    onExpandedChanged: BarStyle.openPopups += expanded ? 1 : -1
    Component.onDestruction: if (expanded) BarStyle.openPopups -= 1

    Item {
        id: maskItem
        width: parent.width
        height: root.revealHeight
    }

    // Наведение считается на родителе всего содержимого: HoverHandler соседнего
    // элемента теряет hover, когда курсор над кнопкой (её MouseArea принимает hover)
    Item {
        anchors.fill: parent
        HoverHandler { id: islandHover }

        // Фон цвета бара: левое вогнутое «ухо», правый край продолжает бар
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                id: bg

                readonly property real w: root.width
                readonly property real h: root.revealHeight
                readonly property real er: root.ear
                readonly property real erY: Math.min(er, h / 2)
                readonly property real br: root.radius
                readonly property real brY: Math.min(br, h / 2)
                readonly property real tr: root.attached ? 0 : root.radius
                readonly property real trY: Math.min(tr, h / 2)

                strokeWidth: -1
                fillColor: Theme.Palette.background

                startX: bg.tr; startY: 0
                PathLine { x: bg.w - bg.tr; y: 0 }
                PathArc { x: bg.w; y: bg.trY; radiusX: bg.tr; radiusY: bg.trY }
                PathLine { x: bg.w; y: bg.h - bg.brY }
                PathArc { x: bg.w - bg.br; y: bg.h; radiusX: bg.br; radiusY: bg.brY }
                PathLine { x: bg.er + bg.br; y: bg.h }
                PathArc { x: bg.er; y: bg.h - bg.brY; radiusX: bg.br; radiusY: bg.brY }
                PathLine { x: bg.er; y: bg.erY + bg.trY }
                PathArc { x: 0; y: bg.trY; radiusX: bg.er; radiusY: bg.erY; direction: PathArc.Counterclockwise }
                PathArc { x: bg.tr; y: 0; radiusX: bg.tr; radiusY: bg.trY }
            }
        }

        // Полоска-подсказка: мигает в такт таймеру, на паузе приглушена
        Rectangle {
            x: root.ear + (root.bodyWidth - width) / 2
            y: (root.peek - height) / 2
            width: Math.round(root.bodyWidth * 0.4)
            height: Tokens.scaled(3)
            radius: height / 2
            color: root.service.paused ? Theme.Palette.on_surface_variant : Theme.Palette.error
            property real blink: root.service.paused || root.service.elapsed % 2 === 0 ? 1 : 0.45
            opacity: (1 - root.progress) * blink
            visible: opacity > 0

            Behavior on blink { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutSine } }
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        }

        // Содержимое выезжает из-под бара вместе с фоном
        Item {
            x: root.ear
            width: root.bodyWidth
            height: root.revealHeight
            clip: true

            Row {
                id: row
                x: root.padding
                y: root.revealHeight - root.fullHeight + root.padding
                spacing: Tokens.spacingMedium
                opacity: root.progress

                Item {
                    width: Tokens.spacingSmall
                    height: Tokens.scaled(36)
                }

                // Мигает раз в секунду: короткая анимация без постоянной перерисовки
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.scaled(10)
                    height: width
                    radius: root.service.paused ? Tokens.scaled(2) : width / 2
                    color: root.service.paused ? Theme.Palette.on_surface_variant : Theme.Palette.error
                    opacity: root.service.paused || root.service.elapsed % 2 === 0 ? 1 : 0.35

                    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutSine } }
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.service.formatTime(root.service.elapsed)
                    font.family: Tokens.fontMedium.family
                    font.pixelSize: Tokens.fontMedium.pixelSize
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    color: root.service.paused ? Theme.Palette.on_surface_variant : Theme.Palette.on_surface

                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                }

                Item {
                    width: Tokens.spacingSmall
                    height: 1
                }

                RecButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.service.paused ? "play_arrow" : "pause"
                    checked: root.service.paused
                    onClicked: root.service.togglePause()
                }

                RecButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "stop"
                    baseColor: Theme.Palette.error_container
                    iconColor: Theme.Palette.on_error_container
                    onClicked: root.service.stop()
                }
            }
        }
    }
}
