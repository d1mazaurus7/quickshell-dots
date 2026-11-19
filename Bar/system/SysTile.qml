pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../shell/theme"
import "../../widgets/sysmon"

// Плитка показателя: круг с жидкостью и волнистой «змейкой» вокруг,
// справа — заголовок и подробности
Rectangle {
    id: root

    property string icon
    property string title
    property string label
    property string value
    property string sub
    // [{ icon, text }]
    property var details: []
    property real progress: 0
    property bool warn: false
    // Волна кольца и жидкости; на время сдвига вкладок выключается
    property bool animate: true
    readonly property var colors: Tokens.colors
    readonly property color accent: warn ? colors.error : colors.primary
    readonly property bool hovered: hover.hovered
    readonly property int pad: Tokens.spacingMedium

    implicitHeight: Tokens.scaled(140)
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    radius: Tokens.radius(28)
    color: Qt.alpha(hovered ? colors.surface_container_high : colors.surface_container, 0.92)
    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

    HoverHandler { id: hover }

    Item {
        id: gauge
        x: root.pad
        y: Math.round((root.height - height) / 2)
        width: root.height - root.pad * 2
        height: width
        readonly property real size: width

        WavyRing {
            id: ring
            anchors.fill: parent
            stroke: Math.max(2, gauge.size * 0.035)
            amplitude: gauge.size * 0.022
            value: Math.max(0, Math.min(1, root.progress))
            color: root.accent
            animate: root.animate
        }

        ClippingRectangle {
            id: face
            x: Math.round((gauge.width - width) / 2)
            y: x
            width: Math.round(gauge.size * 0.74)
            height: width
            radius: width / 2
            color: root.colors.surface_container_highest

            LiquidFill {
                anchors.fill: parent
                level: Math.max(0, Math.min(1, root.progress))
                phase: ring.phase
                amplitude: ring.amplitude
                wavelength: ring.wavelength
                color: root.warn ? root.colors.error_container : root.colors.primary_container
            }
        }

        // Текст и значок поверх, вне ClippingRectangle (его текстура размывает текст); координаты целые
        Column {
            x: Math.round(face.x + (face.width - width) / 2)
            y: Math.round(face.y + (face.height - height) / 2)
            width: Math.round(face.width * 0.8)
            spacing: 0

            SysIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                icon: root.icon
                size: Math.max(Tokens.scaled(12), Math.round(face.width * 0.16))
                filled: root.hovered || root.warn
                hovered: root.hovered
                color: root.warn ? root.colors.error : root.accent
            }
            SysText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.label.toUpperCase()
                font.family: Tokens.typography.family
                font.pixelSize: Math.max(Tokens.scaled(9), Math.round(face.width * 0.11))
                font.weight: Font.Medium
                color: root.colors.on_surface_variant
            }
            SysText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.value
                font.family: Tokens.typography.family
                font.pixelSize: Math.max(Tokens.scaled(12), Math.round(face.width * 0.2))
                font.weight: Font.DemiBold
                color: root.warn ? root.colors.error : root.colors.on_surface
            }
            SysText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.sub !== ""
                text: root.sub
                font.family: Tokens.typography.family
                font.pixelSize: Math.max(Tokens.scaled(8), Math.round(face.width * 0.095))
                color: root.colors.on_surface_variant
            }
        }
    }

    Column {
        anchors.left: gauge.right
        anchors.leftMargin: Tokens.spacingMedium
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacingLarge
        y: Math.round((root.height - height) / 2)
        spacing: Tokens.spacingSmallV

        Row {
            width: parent.width
            spacing: Tokens.spacingSmall

            Rectangle {
                id: badge
                width: Tokens.scaled(26)
                height: width
                radius: root.hovered ? Tokens.radius(9) : width / 2
                color: root.warn ? root.colors.error_container : root.colors.primary_container
                Behavior on radius { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

                SysIcon {
                    anchors.centerIn: parent
                    icon: root.icon
                    size: Tokens.scaled(16)
                    filled: root.hovered || root.warn
                    hovered: root.hovered
                    color: root.warn ? root.colors.on_error_container : root.colors.on_primary_container
                }
            }

            SysText {
                width: parent.width - badge.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.family: Tokens.fontMedium.family
                font.pixelSize: Tokens.fontMedium.pixelSize
                font.weight: Font.DemiBold
                color: root.colors.on_surface
            }
        }

        Repeater {
            model: root.details.length

            Row {
                id: detail
                required property int index
                readonly property var d: root.details[index] ?? {}
                width: parent.width
                spacing: Tokens.spacingSmall

                SysIcon {
                    id: dIcon
                    width: Tokens.scaled(26)
                    anchors.verticalCenter: parent.verticalCenter
                    icon: detail.d.icon ?? ""
                    size: Tokens.scaled(14)
                    hovered: root.hovered
                    color: root.colors.on_surface_variant
                }
                SysText {
                    width: parent.width - dIcon.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    text: detail.d.text ?? ""
                    font: Tokens.fontSmall
                    color: root.colors.on_surface_variant
                }
            }
        }
    }
}
