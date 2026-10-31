import QtQuick
import "../../shell/theme"

// Сообщение чата: свои справа, ответы и ошибки слева; появляется со сдвигом снизу
Item {
    id: root

    required property string sender
    required property string content
    property real maxWidth: width * 0.8
    property bool animate: true
    property font textFont: Tokens.fontMedium
    property font smallFont: Tokens.fontSmall

    readonly property var colors: Tokens.colors
    readonly property bool mine: sender === "user"
    readonly property int padH: Tokens.spacingMedium + Tokens.spacingSmall
    readonly property int padV: Tokens.spacingMediumV

    implicitHeight: box.height
    Component.onCompleted: {
        if (animate) {
            opacity = 0;
            appear.start();
        }
    }

    ParallelAnimation {
        id: appear
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
        NumberAnimation { target: shift; property: "y"; from: Tokens.spacingLargeV; to: 0; duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
        NumberAnimation { target: box; property: "scale"; from: 0.94; to: 1; duration: Tokens.animationSlow; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: box

        x: root.mine ? root.width - width : root.sender === "info" ? (root.width - width) / 2 : 0
        width: label.width + root.padH * 2
        height: label.height + root.padV * 2
        transformOrigin: root.mine ? Item.BottomRight : Item.BottomLeft
        transform: Translate { id: shift }

        radius: Tokens.radiusLarge
        bottomRightRadius: root.mine ? Tokens.radiusSmall : Tokens.radiusLarge
        bottomLeftRadius: root.mine ? Tokens.radiusLarge : Tokens.radiusSmall
        color: root.mine ? root.colors.primary_container
             : root.sender === "error" ? root.colors.error_container
             : root.sender === "info" ? root.colors.surface_container
             : root.colors.surface_container_high

        Text {
            id: label
            x: root.padH
            y: root.padV
            width: Math.min(implicitWidth, root.maxWidth - root.padH * 2)
            text: root.content
            textFormat: root.sender === "assistant" ? Text.MarkdownText : Text.PlainText
            wrapMode: Text.Wrap
            font: root.sender === "info" ? root.smallFont : root.textFont
            color: root.sender === "info" ? root.colors.on_surface_variant
                 : root.mine ? root.colors.on_primary_container
                 : root.sender === "error" ? root.colors.on_error_container
                 : root.colors.on_surface
            linkColor: root.colors.primary
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
    }
}
