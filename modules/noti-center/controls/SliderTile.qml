import QtQuick
import "../../../theme" as Theme

// Кнопка-переключатель + ползунок (громкость, микрофон, яркость).
// checked — состояние кнопки (например, звук выключен): дорожка приглушается.
Item {
    id: st

    required property real s
    property string icon
    property bool checked: false
    property bool slashed: false
    property bool buttonInteractive: true
    property alias value: slider.value
    property alias available: slider.available
    readonly property real trackHeight: height - 10 * s
    // Видимая форма для обводки редактора (WidgetGrid)
    readonly property real editInsetV: (height - trackHeight) / 2
    readonly property real editRadius: trackHeight / 2

    signal moved(real v)
    signal toggled()
    signal scrolled()

    IconButton {
        id: btn
        s: st.s
        anchors.verticalCenter: parent.verticalCenter
        width: st.trackHeight
        height: st.trackHeight
        round: true
        icon: st.icon
        checked: st.checked
        slashed: st.slashed
        interactive: st.buttonInteractive
        onClicked: st.toggled()
    }

    M3Slider {
        id: slider
        s: st.s
        anchors.left: btn.right
        anchors.leftMargin: 10 * st.s
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        trackHeight: st.trackHeight
        activeColor: st.checked ? Theme.Palette.outline : Theme.Palette.primary
        onMoved: v => st.moved(v)
        onScrolled: st.scrolled()
    }
}
