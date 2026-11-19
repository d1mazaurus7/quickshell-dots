pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// M3-сегменты одинаковой ширины; индикатор тянется краями с разной скоростью
Item {
    id: root

    property var model: []
    property int current: 0
    property int segmentWidth: Tokens.scaled(112)
    property int segmentHeight: Tokens.scaled(40)
    property int pad: Tokens.scaled(4)
    property font font: Tokens.fontMedium
    readonly property var colors: Tokens.colors

    signal selected(int index)

    implicitWidth: model.length * segmentWidth + pad * 2
    implicitHeight: segmentHeight + pad * 2

    // Ведущий край индикатора движется быстрее, догоняющий — медленнее
    property real segL: current * segmentWidth
    property real segR: (current + 1) * segmentWidth

    Behavior on segL {
        id: behL
        NumberAnimation { duration: behL.targetValue > root.segL ? Tokens.animationSlow * 1.6 : Tokens.animationSlow; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }
    Behavior on segR {
        id: behR
        NumberAnimation { duration: behR.targetValue > root.segR ? Tokens.animationSlow : Tokens.animationSlow * 1.6; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.colors.surface_container_high
    }

    Rectangle {
        x: root.pad + root.segL
        y: root.pad
        width: root.segR - root.segL
        height: root.segmentHeight
        radius: height / 2
        color: root.colors.secondary_container
    }

    Row {
        x: root.pad
        y: root.pad

        Repeater {
            model: root.model

            Item {
                id: seg
                required property var modelData
                required property int index
                readonly property bool active: index === root.current

                width: root.segmentWidth
                height: root.segmentHeight

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.colors.on_surface
                    opacity: area.pressed ? 0.12 : area.containsMouse && !seg.active ? 0.08 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: Tokens.spacingSmall
                    scale: area.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }

                    SysIcon {
                        id: segIcon
                        visible: (seg.modelData.icon ?? "") !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        icon: seg.active ? (seg.modelData.activeIcon ?? seg.modelData.icon ?? "") : (seg.modelData.icon ?? "")
                        size: Math.round(root.segmentHeight * 0.5)
                        filled: seg.active
                        hovered: area.containsMouse
                        color: seg.active ? root.colors.on_secondary_container : root.colors.on_surface_variant
                    }

                    SysText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, root.segmentWidth - Tokens.spacingMedium * 2 - (segIcon.visible ? segIcon.width + Tokens.spacingSmall : 0))
                        text: seg.modelData.label ?? ""
                        font.family: root.font.family
                        font.pixelSize: root.font.pixelSize
                        font.weight: seg.active ? Font.DemiBold : Font.Normal
                        color: seg.active ? root.colors.on_secondary_container : root.colors.on_surface_variant
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(seg.index)
                }
            }
        }
    }
}
