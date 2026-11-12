pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Поле пароля лок-скрина: только отображение, ввод собирает поверхность блокировки в lock.input.
// lock — LockState (Bar/lockscreen), settings — настройки виджета lockPassword (с дефолтами реестра)
Rectangle {
    id: root

    property var lock: null
    property var settings: ({})

    readonly property var colors: Tokens.colors
    readonly property var cfg: Config.options.lockscreen
    readonly property string input: lock?.input ?? ""
    readonly property bool failed: lock?.failed ?? false
    readonly property bool busy: lock?.busy ?? false
    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string style: settings.style
    readonly property color textColor: settings.whiteText === true ? "#ffffff" : colors.on_surface
    readonly property color hintColor: settings.whiteText === true ? Qt.alpha("#ffffff", 0.7) : colors.on_surface_variant
    readonly property bool centered: settings.align === "center"

    function format(text: string, fallback: string): string {
        return (text || fallback).replace(/%u/g, user);
    }

    implicitWidth: Tokens.scaled(320)
    implicitHeight: Tokens.scaled(56)
    radius: Math.min(width, height) / 2 * settings.radius
    color: style === "filled" ? colors.surface_container_high
        : style === "glass" ? Qt.alpha(colors.surface_container_high, settings.glassOpacity)
        : "transparent"
    border.width: Tokens.scaled(settings.borderWidth)
    border.color: failed ? colors.error
        : input !== "" || busy ? colors.primary
        : style === "glass" ? Qt.alpha(textColor, 0.25) : colors.outline_variant
    Behavior on border.color { ColorAnimation { duration: Tokens.animationFast } }
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

    // Неверный пароль — короткое покачивание
    property real shake: 0
    transform: Translate { x: root.shake }
    onFailedChanged: if (failed && root.settings.shake === true) shakeAnim.restart()
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shake"; to: Tokens.scaled(8); duration: Tokens.animationFast / 2 }
        NumberAnimation { target: root; property: "shake"; to: -Tokens.scaled(8); duration: Tokens.animationFast }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: Tokens.animationFast / 2; easing.type: Easing.OutCubic }
    }

    Text {
        id: lockIcon
        anchors.left: parent.left
        anchors.leftMargin: Math.round(root.height * 0.3)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.settings.showIcon === true
        width: visible ? implicitWidth : 0
        text: root.failed ? "error" : "lock"
        color: root.failed ? root.colors.error : root.hintColor
        font.family: "Material Symbols Rounded"
        font.pixelSize: Math.round(root.height * 0.42)
        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    }

    Item {
        id: field
        anchors.left: lockIcon.right
        anchors.right: submit.visible ? submit.left : parent.right
        anchors.leftMargin: lockIcon.visible ? Tokens.spacingMedium : Math.round(root.height * 0.35)
        anchors.rightMargin: submit.visible ? Tokens.spacingMedium : Math.round(root.height * 0.35)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        readonly property bool hint: root.input === "" || !root.cfg.requirePassword || root.busy
        readonly property bool dots: !hint && !root.cfg.showPassword
        readonly property int textSize: Math.round(root.height * root.settings.textSize)

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !field.dots && (!field.hint || root.failed || root.busy || root.settings.showHint === true)
            horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
            text: !root.cfg.requirePassword ? root.format(root.settings.anyKeyText, "Нажмите любую клавишу")
                : root.busy ? "Проверка…"
                : root.input === "" ? (root.failed ? root.format(root.settings.failText, "Неверный пароль")
                                                   : root.format(root.settings.placeholder, "Введите пароль"))
                : root.input
            color: field.hint ? (root.failed ? root.colors.error : root.hintColor) : root.textColor
            font.family: Tokens.typography.family
            font.pixelSize: field.textSize
            font.bold: root.settings.boldText === true
            elide: field.hint ? Text.ElideRight : Text.ElideLeft
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        }

        // Точки пароля: при переполнении видны последние
        Row {
            id: dotRow
            readonly property int dot: Tokens.scaled(root.cfg.dotSize)
            anchors.verticalCenter: parent.verticalCenter
            x: width > parent.width ? parent.width - width : root.centered ? (parent.width - width) / 2 : 0
            visible: field.dots
            spacing: Math.round(dot * 0.6)

            Repeater {
                model: field.dots ? root.input.length : 0

                Rectangle {
                    required property int index
                    width: dotRow.dot
                    height: dotRow.dot
                    radius: root.settings.dotShape === "square" ? Tokens.scaled(2) : width / 2
                    color: root.textColor
                    // Появляется только новая точка
                    Component.onCompleted: if (index === root.input.length - 1) popIn.start()
                    NumberAnimation on scale {
                        id: popIn
                        running: false
                        from: 0.3
                        to: 1
                        duration: Tokens.animationFast
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }

    IconButton {
        id: submit
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.height * 0.12)
        anchors.verticalCenter: parent.verticalCenter
        visible: root.settings.showButton === true
        size: Math.round(root.height * 0.76)
        checked: true
        icon: root.busy ? "hourglass_top" : "arrow_forward"
        enabled: !root.busy && root.lock !== null
        onClicked: root.lock.submit()
    }
}
