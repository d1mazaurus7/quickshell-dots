pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../shell/config"
import "../../shell/theme"
import "../../widgets" as Widgets
import "../../widgets/editor" as Editor
import "../../widgets/lock" as LockWidgets

// Поверхность блокировки одного монитора: фон, виджеты рабочего стола и лок-скрина,
// поле пароля, уведомления, редактор виджетов
WlSessionLockSurface {
    id: root

    required property LockState lock
    required property Widgets.WidgetsState widgets
    required property var notifications

    readonly property var cfg: Config.options.lockscreen
    readonly property bool editing: widgets.editing && screenName !== "" && widgets.editorOutput === screenName
    readonly property bool hasPasswordWidget: cfg.widgets && widgets.items.some(i => i.type === "lockPassword")
    // Скриншот — сам рабочий стол: анимируется только размытие, без затухания фона
    // screen приходит не сразу после создания поверхности
    readonly property string screenName: screen?.name ?? ""
    readonly property string backgroundSource: screenName === "" ? ""
        : cfg.screenshotBackground && lock.stamp !== "" ? lock.shotPath(screenName)
        : cfg.wallpaperBackground ? lock.wallpaperPath : ""
    readonly property bool screenshot: cfg.screenshotBackground && lock.stamp !== ""

    color: Tokens.colors.surface

    // 0 → 1 при блокировке, 1 → 0 при разблокировке
    property real reveal: 0
    Behavior on reveal {
        enabled: root.cfg.animation
        NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
    }
    Component.onCompleted: reveal = Qt.binding(() => root.lock.unlocking ? 0 : 1)

    function screenOf(name: string): var {
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    function handleKey(event: var): void {
        root.lock.activity();
        if (root.editing) {
            if (event.key === Qt.Key_Escape) {
                root.widgets.editing = false;
                event.accepted = true;
            }
            return;
        }
        event.accepted = true;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            root.lock.submit();
        else if (event.key === Qt.Key_Escape)
            root.lock.clear();
        else if (event.key === Qt.Key_Backspace && (event.modifiers & Qt.ControlModifier))
            root.lock.clear();
        else if (event.key === Qt.Key_Backspace)
            root.lock.backspace();
        else if (event.text !== "" && event.text.charCodeAt(0) >= 32)
            root.lock.typeText(event.text);
        else if (!root.cfg.requirePassword)
            root.lock.unlock();
        else
            event.accepted = false;
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.handleKey(event)

        // Движение мыши — активность (не чаще раза в 250 мс); не мешает наведению на виджеты
        HoverHandler {
            property real last: 0
            onPointChanged: {
                const now = Date.now();
                if (now - last < 250)
                    return;
                last = now;
                root.lock.activity();
            }
        }

        LockBackground {
            id: background
            anchors.fill: parent
            source: root.backgroundSource
            video: root.screenshot ? "" : root.lock.wallpaperVideo
            blur: root.cfg.blur
            reveal: root.reveal
            opacity: root.screenshot ? 1 : root.reveal
        }

        Item {
            id: layer
            anchors.fill: parent
            opacity: root.reveal
            scale: 0.97 + 0.03 * root.reveal
            visible: root.cfg.widgets

            Repeater {
                // Только виджеты этого монитора; ScriptModel сохраняет делегаты при переприсваивании items
                model: ScriptModel {
                    values: root.cfg.widgets ? root.widgets.windowKeys.filter(k => {
                        const i = root.widgets.byUid[k.split("#")[0]];
                        return i && root.screenOf(i.screen) === root.screen;
                    }) : []
                }

                Item {
                    id: slot

                    required property string modelData
                    readonly property string uid: modelData.split("#")[0]
                    readonly property var item: root.widgets.byUid[uid] ?? null
                    readonly property var geo: root.widgets.geometry(uid)

                    visible: item !== null
                    x: Math.round(geo.x)
                    y: Math.round(geo.y)
                    width: Math.max(1, Math.round(geo.width))
                    height: Math.max(1, Math.round(geo.height))

                    // Размытие под blurItem виджета; blurShape (Region) здесь не поддерживается
                    ClippingRectangle {
                        id: patch
                        readonly property Item target: host.blurItem
                        readonly property point pos: {
                            // Пересчёт при изменении геометрии виджета или самого blurItem
                            const deps = [slot.width, slot.height, target?.x, target?.y, target?.width, target?.height];
                            return target && deps ? target.mapToItem(slot, 0, 0) : Qt.point(0, 0);
                        }
                        visible: target !== null && target.visible && background.ready
                        x: pos.x
                        y: pos.y
                        width: target?.width ?? 0
                        height: target?.height ?? 0
                        radius: target?.radius ?? 0
                        color: "transparent"

                        ShaderEffectSource {
                            anchors.fill: parent
                            sourceItem: background.blurSource
                            sourceRect: Qt.rect(slot.x + patch.x, slot.y + patch.y, patch.width, patch.height)
                        }
                    }

                    Widgets.WidgetHost {
                        id: host
                        anchors.fill: parent
                        uid: slot.uid
                        widgets: root.widgets
                    }
                }
            }
        }

        // Поле пароля, если виджета нет: появляется при вводе
        LockWidgets.LockPasswordField {
            readonly property bool shown: !root.hasPasswordWidget && root.cfg.requirePassword
                && (root.lock.input !== "" || root.lock.busy || root.lock.failed)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: shown ? 0 : Tokens.spacingMediumV
            lock: root.lock
            settings: root.widgets.find("lockPassword")?.defaults ?? ({})
            opacity: shown ? root.reveal : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }

        Loader {
            active: !root.cfg.hideNotifications && root.screen === Quickshell.screens[0]
            anchors.top: parent.top
            anchors.topMargin: Tokens.spacingMediumV
            anchors.right: parent.right
            anchors.left: parent.left
            opacity: root.reveal

            sourceComponent: Item {
                LockNotifications {
                    anchors.right: side === "right" ? parent.right : undefined
                    anchors.left: side === "left" ? parent.left : undefined
                    notifications: root.notifications
                }
            }
        }

        // Редактор набора лок-скрина: создаётся только на время редактирования
        Loader {
            id: editor
            anchors.fill: parent
            property real shown: root.editing ? 1 : 0
            Behavior on shown { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            active: shown > 0
            opacity: shown
            enabled: root.editing

            sourceComponent: Editor.EditorContent {
                widgets: root.widgets
                editorScreen: root.screen
            }
        }
    }
}
