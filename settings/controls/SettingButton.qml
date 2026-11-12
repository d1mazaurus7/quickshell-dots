import QtQuick
import Quickshell
import "../../shell/theme"

// M3 кнопка. variant: "filled" | "tonal" | "outlined" | "text"; checkable/checked — toggle-режим
Rectangle {
    id: root

    property string text
    property string icon: ""
    property string variant: "tonal"
    property bool checkable: false
    property bool checked: false

    readonly property var colors: Tokens.colors
    readonly property bool selected: checkable && checked
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    readonly property string shownIcon: icon !== "" ? icon : selected ? "check" : ""

    readonly property color containerColor: {
        if (!enabled)
            return variant === "outlined" || variant === "text" ? "transparent" : Qt.alpha(colors.on_surface, 0.12);
        switch (variant) {
        case "filled":
            return checkable && !checked ? colors.surface_container : colors.primary;
        case "outlined":
            return selected ? colors.inverse_surface : "transparent";
        case "text":
            return "transparent";
        default:
            return selected ? colors.secondary : colors.secondary_container;
        }
    }
    readonly property color contentColor: {
        if (!enabled)
            return Qt.alpha(colors.on_surface, 0.38);
        switch (variant) {
        case "filled":
            return checkable && !checked ? colors.on_surface_variant : colors.on_primary;
        case "outlined":
            return selected ? colors.inverse_on_surface : colors.on_surface_variant;
        case "text":
            return colors.primary;
        default:
            return selected ? colors.on_secondary : colors.on_secondary_container;
        }
    }

    signal clicked
    signal toggled(bool checked)

    implicitWidth: content.implicitWidth + Tokens.spacingLarge * 2
    implicitHeight: Tokens.scaled(36)
    // Форма: круглая → квадратнее при выборе → ещё квадратнее при нажатии
    radius: pressed ? height * 0.2 : selected ? height * 0.3 : height / 2
    color: containerColor
    border.width: variant === "outlined" && !selected ? 1 : 0
    border.color: enabled ? colors.outline_variant : Qt.alpha(colors.on_surface, 0.12)
    scale: pressed ? 0.96 : 1

    Behavior on implicitWidth { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

    // State layer: hover 8%, pressed 10%
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.contentColor
        opacity: !root.enabled ? 0 : root.pressed ? 0.10 : root.hovered ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
    }

    Row {
        id: content
        anchors.centerIn: parent

        Item {
            id: iconSlot
            readonly property bool shown: root.shownIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            width: shown ? iconText.implicitWidth + Tokens.spacingSmall : 0
            height: iconText.implicitHeight
            clip: true
            Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

            Text {
                id: iconText
                anchors.verticalCenter: parent.verticalCenter
                text: root.shownIcon
                color: root.contentColor
                font.family: "Material Symbols Rounded"
                font.pixelSize: Tokens.scaled(18)
                opacity: iconSlot.shown ? 1 : 0
                scale: !iconSlot.shown ? 0.4 : root.pressed ? 0.9 : root.hovered ? 1.1 : 1
                rotation: root.hovered && root.enabled && !root.pressed ? -8 : 0
                Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                Behavior on rotation { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.contentColor
            font: Tokens.fontMedium
            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/sfx.wav")]);
            if (root.checkable) {
                root.checked = !root.checked;
                root.toggled(root.checked);
            }
            root.clicked();
        }
    }
}
