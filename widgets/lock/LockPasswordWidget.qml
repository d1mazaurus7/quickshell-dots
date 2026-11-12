import QtQuick
import "../../shell/theme"

// Виджет лок-скрина «Поле пароля» (lockOnly, single). Ввод — в LockState через services.lock
Item {
    id: root

    property var settings: ({})
    property bool editing: false
    property var services: ({})
    // Стекло: размытие фона под полем
    property Item blurItem: settings.style === "glass" ? field : null

    readonly property var lock: services.lock ?? null

    LockIdle {
        id: idle
        lock: root.lock
        active: root.settings.hideOnIdle === true
        delay: root.settings.idleDelay
        hold: root.editing || (root.lock !== null && (root.lock.input !== "" || root.lock.busy || root.lock.failed))
    }

    LockPasswordField {
        id: field
        anchors.fill: parent
        lock: root.lock
        settings: root.settings
        opacity: idle.shown ? root.settings.opacity : 0
        scale: idle.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
    }
}
