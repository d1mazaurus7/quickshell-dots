pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Notifications
import "../../shell/config"
import "../../shell/theme"
import "../../modules/noti-center" as NotiCenter

// Всплывающие уведомления на лок-скрине: те же карточки, что у NotificationPopups
Item {
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

    width: Math.round(380 * s)
    height: column.height + ear * 2

    Column {
        id: column
        y: root.ear
        width: parent.width
        spacing: root.ear * 2 + Tokens.spacingSmallV

        move: Transition {
            NumberAnimation { properties: "y"; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.notifications.popups

            NotiCenter.NotificationCard {
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
