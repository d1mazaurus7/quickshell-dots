import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../../shell/theme"
import "../../shell/config"

// Всплывающие уведомления в верхнем углу экрана: выезжают из его края.
PanelWindow {
    id: root

    required property var notifications
    readonly property string side: Config.options.notiCenter.popupSide === "left" ? "left" : "right"
    readonly property real s: Tokens.scale
    readonly property real ear: 10 * s
    readonly property var swipeGroup: QtObject {
        property int activeIndex: -1
        property real offset: 0
        property bool detached: false
    }

    screen: Quickshell.screens[0]
    visible: notifications.popups.count > 0
    color: "transparent"
    WlrLayershell.namespace: "message-card"
    WlrLayershell.layer: WlrLayer.Overlay
    // Учитывает зону бара: окно встаёт под ним.
    exclusionMode: ExclusionMode.Normal

    anchors {
        top: true
        right: root.side === "right"
        left: root.side === "left"
    }
    margins.top: Tokens.spacingMediumV

    implicitWidth: Math.round(380 * s)
    implicitHeight: Math.max(1, column.height + ear * 2)
    mask: Region { item: column }

    // Открылся центр уведомлений — всплывающие плавно уезжают, они уже в нём.
    Connections {
        target: root.notifications
        function onCenterOpenChanged(): void {
            if (!root.notifications.centerOpen)
                return;
            for (let i = 0; i < popupRepeater.count; i++)
                popupRepeater.itemAt(i).hide();
        }
    }

    Column {
        id: column
        y: root.ear
        width: parent.width
        spacing: root.ear * 2 + Tokens.spacingSmallV

        move: Transition {
            NumberAnimation { properties: "y"; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
        }

        Repeater {
            id: popupRepeater
            model: root.notifications.popups

            NotificationCard {
                required property int nid
                required property int index
                group: root.swipeGroup
                listIndex: index
                notification: root.notifications.find(nid)
                s: root.s
                edge: root.side
                earRadius: root.ear
                timeout: !notification || notification.urgency === NotificationUrgency.Critical ? 0
                    : notification.expireTimeout > 0 ? notification.expireTimeout * 1000 : 5000
                onFinished: root.notifications.removePopup(nid)
            }
        }
    }
}
