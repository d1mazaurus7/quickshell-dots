import QtQuick
import "../../shell/theme"
import "../../settings/controls" as SettingControls

// Строка настройки: подпись и слайдер из settings/controls/SettingSlider.qml.
// moved — по отпусканию (писать в настройки), dragged — каждое изменение (живой предпросмотр)
Item {
    id: root

    property string text
    property real from: 0
    property real to: 1
    property real stepSize: 1
    property real value
    property var formatValue: v => Math.round(v).toString()
    property real sliderWidth: Tokens.scaled(160)

    signal moved(real value)
    signal dragged(real value)

    implicitWidth: label.implicitWidth + slider.implicitWidth + Tokens.spacingLarge
    implicitHeight: Math.max(label.implicitHeight, slider.implicitHeight)

    Text {
        id: label
        anchors.left: parent.left
        anchors.right: slider.left
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        elide: Text.ElideRight
        color: Tokens.colors.on_surface
        font: Tokens.fontMedium
    }

    SettingControls.SettingSlider {
        id: slider
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        formatValue: root.formatValue
        sliderWidth: root.sliderWidth
        onMoved: v => root.moved(v)
        onDragged: v => root.dragged(v)
    }
}
