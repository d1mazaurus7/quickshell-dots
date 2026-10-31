import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Карточка уведомления: иконка, приложение, текст, кнопки действий.
// Смахивается перетаскиванием с зажатой ЛКМ (по настройкам notiCenter):
// упирается в край окна и «втягивается» в него, соседи немного тянутся следом.
Item {
    id: card

    required property var notification
    property real s: 1
    // Всплывающая карточка: край экрана "right" | "left", из которого она выезжает; "" — в центре.
    property string edge: ""
    property real earRadius: 10 * s
    // Автоскрытие всплывающей карточки, мс; 0 — не скрывать.
    property int timeout: 0
    // Общее состояние смахивания списка: { activeIndex, offset, detached }.
    property var group: null
    property int listIndex: -1

    readonly property var cfg: Config.options.notiCenter
    readonly property bool canRight: cfg.swipe && cfg.swipeDirection !== "left"
    readonly property bool canLeft: cfg.swipe && cfg.swipeDirection !== "right"
    readonly property var buttons: notification ? notification.actions.filter(a => a.identifier !== "default") : []
    readonly property var defaultAction: notification ? (notification.actions.find(a => a.identifier === "default") ?? null) : null
    readonly property string iconSource: {
        const n = notification;
        if (!n)
            return "";
        if (n.image !== "")
            return n.image;
        const icon = n.appIcon !== "" ? n.appIcon : (DesktopEntries.byId(n.desktopEntry)?.icon ?? "");
        if (icon === "")
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        return icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
    }

    property real reveal: edge === "" ? 1 : 0
    property real collapse: 1
    property real dx: 0
    property real dragBase: 0
    // Сосед смахиваемой карточки тянется за ней, пока не «отлипнет».
    readonly property bool attached: !!group && group.activeIndex >= 0 && !group.detached
        && Math.abs(group.activeIndex - listIndex) === 1
    readonly property real pullTarget: attached ? group.offset * 0.25 : 0
    property real pull: 0
    onPullTargetChanged: {
        if (attached) {
            unstick.stop();
            pull = pullTarget;
        } else if (pull !== 0) {
            unstick.restart();
        }
    }

    // Итоговый сдвиг: на столько карточка вдавлена в край окна.
    readonly property real v: Math.max(-width, Math.min(width, dx + pull))
    readonly property real r: Tokens.radius(16) * s
    // Скругление со стороны края сглаживается — карточка прилипает к нему.
    readonly property real stickR: r * Math.max(0, 1 - Math.abs(v) / (16 * s))

    // Всплывающая карточка спрятана — владелец убирает её из списка.
    signal finished()

    width: parent ? parent.width : 0
    height: bg.height * collapse

    function swipeOut(dir: int): void {
        swipeAnim.to = dir * width;
        swipeAnim.start();
    }

    function hide(): void {
        if (!swipeAnim.running && !hideAnim.running)
            hideAnim.start();
    }

    function track(t: real): void {
        dx = Math.max(canLeft ? -width : 0, Math.min(canRight ? width : 0, dragBase + t));
        if (!group)
            return;
        group.activeIndex = listIndex;
        group.offset = dx;
        if (Math.abs(dx) > width * 0.2)
            group.detached = true;
    }

    function release(): void {
        if (group && group.activeIndex === listIndex)
            group.activeIndex = -1;
        if (Math.abs(dx) > width * 0.35)
            swipeOut(dx > 0 ? 1 : -1);
        else if (dx !== 0)
            snapBack.start();
    }

    Component.onCompleted: if (edge !== "") showAnim.start()
    Component.onDestruction: if (group && group.activeIndex === listIndex) group.activeIndex = -1

    NumberAnimation {
        id: unstick
        target: card; property: "pull"; to: 0
        duration: Tokens.animationSlow * 2; easing.type: Easing.OutElastic
        easing.amplitude: 1; easing.period: 0.45
    }

    NumberAnimation {
        id: showAnim
        target: card; property: "reveal"; to: 1
        duration: Tokens.animationSlow; easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: snapBack
        target: card; property: "dx"; to: 0
        duration: Tokens.animationMedium; easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: swipeAnim
        property real to: 0
        NumberAnimation { target: card; property: "dx"; to: swipeAnim.to; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "collapse"; to: 0; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
        ScriptAction { script: card.notification.dismiss() }
    }

    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: card; property: "reveal"; to: 0; duration: Tokens.animationSlow; easing.type: Easing.InCubic }
        NumberAnimation { target: card; property: "collapse"; to: 0; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
        ScriptAction { script: card.finished() }
    }

    Timer {
        interval: card.timeout
        running: card.timeout > 0 && card.reveal === 1 && !hover.hovered && !drag.active
        onTriggered: card.hide()
    }

    Item {
        id: content
        width: card.width
        height: bg.height
        x: (card.edge === "right" ? 1 : card.edge === "left" ? -1 : 0) * (1 - card.reveal) * card.width
        opacity: (1 - Math.abs(card.v) / card.width * 0.6) * (card.edge === "" ? 1 : 0.4 + 0.6 * card.reveal)

        HoverHandler { id: hover }

        // Отпускание и отмена захвата оба снимают active — карточка не зависает.
        DragHandler {
            id: drag
            target: null
            yAxis.enabled: false
            enabled: card.canLeft || card.canRight
            dragThreshold: 6 * card.s
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            cursorShape: Qt.ClosedHandCursor
            onActiveChanged: {
                if (active) {
                    snapBack.stop();
                    card.dragBase = card.dx;
                    if (card.group)
                        card.group.detached = false;
                } else {
                    card.release();
                }
            }
            onActiveTranslationChanged: if (active && !swipeAnim.running) card.track(activeTranslation.x)
        }

        TapHandler {
            enabled: !!card.defaultAction
            cursorShape: Qt.PointingHandCursor
            onTapped: card.defaultAction.invoke()
        }

        // Тело карточки: сжимается со стороны смахивания, содержимое уезжает в край.
        Rectangle {
            id: bg
            x: Math.max(0, card.v)
            width: card.width - Math.abs(card.v)
            height: Math.max(col.implicitHeight, 40 * card.s) + 14 * card.s * 2
            clip: true
            topRightRadius: card.edge === "right" ? 0 : card.v > 0 ? card.stickR : card.r
            bottomRightRadius: topRightRadius
            topLeftRadius: card.edge === "left" ? 0 : card.v < 0 ? card.stickR : card.r
            bottomLeftRadius: topLeftRadius
            color: card.edge !== "" ? Theme.Palette.background : Theme.Palette.surface_container_high

            Rectangle {
                anchors.fill: parent
                topLeftRadius: bg.topLeftRadius
                topRightRadius: bg.topRightRadius
                bottomLeftRadius: bg.bottomLeftRadius
                bottomRightRadius: bg.bottomRightRadius
                color: Theme.Palette.on_surface
                opacity: drag.active ? 0.08 : hover.hovered ? 0.04 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            }

            Item {
                x: card.v - bg.x
                width: card.width
                height: parent.height

                // Иконка приложения; без неё — первая буква названия.
                Rectangle {
                    id: iconBox
                    x: 14 * card.s
                    y: 14 * card.s
                    width: 40 * card.s
                    height: width
                    radius: Tokens.radius(12) * card.s
                    color: Theme.Palette.secondary_container
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: icon.status !== Image.Ready
                        text: card.notification ? (card.notification.appName || "?").charAt(0).toUpperCase() : ""
                        color: Theme.Palette.on_secondary_container
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(18 * card.s)
                    }

                    Image {
                        id: icon
                        anchors.fill: parent
                        source: card.iconSource
                        sourceSize.width: width * 2
                        sourceSize.height: height * 2
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    id: col
                    anchors.left: iconBox.right
                    anchors.leftMargin: 12 * card.s
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * card.s
                    y: 14 * card.s
                    spacing: 3 * card.s

                    Text {
                        width: parent.width
                        text: card.notification ? card.notification.appName || "Уведомление" : ""
                        elide: Text.ElideRight
                        color: Theme.Palette.on_surface_variant
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(11 * card.s)
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: card.notification ? card.notification.summary : ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.Palette.on_surface
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(14 * card.s)
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: card.notification ? card.notification.body : ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: card.cfg.bodyLines
                        elide: Text.ElideRight
                        color: Theme.Palette.on_surface_variant
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.round(12 * card.s)
                    }

                    Flow {
                        width: parent.width
                        visible: card.cfg.showActions && card.buttons.length > 0
                        topPadding: 6 * card.s
                        spacing: 6 * card.s

                        Repeater {
                            model: card.buttons

                            Rectangle {
                                id: btn
                                required property var modelData
                                width: label.implicitWidth + 24 * card.s
                                height: 28 * card.s
                                radius: height / 2
                                color: Theme.Palette.secondary_container

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Theme.Palette.on_secondary_container
                                    opacity: btnArea.pressed ? 0.12 : btnArea.containsMouse ? 0.08 : 0
                                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                                }

                                Text {
                                    id: label
                                    anchors.centerIn: parent
                                    text: btn.modelData.text
                                    color: Theme.Palette.on_secondary_container
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Math.round(12 * card.s)
                                }

                                MouseArea {
                                    id: btnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: btn.modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Вогнутые скругления у края экрана — карточка «вырастает» из рамки монитора.
        Item {
            anchors.fill: bg
            visible: card.edge !== ""
            opacity: 1 - Math.min(1, Math.max(0, card.edge === "right" ? -card.v : card.v) / (card.earRadius * 2))
            transform: Scale { origin.x: bg.width / 2; xScale: card.edge === "left" ? -1 : 1 }

            Shape {
                x: bg.width - card.earRadius
                y: -card.earRadius
                width: card.earRadius
                height: card.earRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: bg.color
                    startX: card.earRadius; startY: 0
                    PathLine { x: card.earRadius; y: card.earRadius }
                    PathLine { x: 0; y: card.earRadius }
                    PathArc { x: card.earRadius; y: 0; radiusX: card.earRadius; radiusY: card.earRadius; direction: PathArc.Counterclockwise }
                }
            }

            Shape {
                x: bg.width - card.earRadius
                y: bg.height
                width: card.earRadius
                height: card.earRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: bg.color
                    startX: card.earRadius; startY: card.earRadius
                    PathLine { x: card.earRadius; y: 0 }
                    PathLine { x: 0; y: 0 }
                    PathArc { x: card.earRadius; y: card.earRadius; radiusX: card.earRadius; radiusY: card.earRadius }
                }
            }
        }
    }
}
