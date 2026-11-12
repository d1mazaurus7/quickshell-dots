import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"

// Время, дата, день недели (настройки — notiCenter.showSeconds/showDate/showWeekday)
Rectangle {
    id: w

    required property var ctx
    readonly property real s: ctx.s
    readonly property var cfg: ctx.cfg
    readonly property int timeSize: Math.round(Math.min(height * (cfg.showDate ? 0.5 : 0.62), 64 * s))

    radius: Math.min(height * 0.32, 24 * s)
    color: Theme.Palette.surface_container_high

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 16 * w.s
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: Qt.formatDateTime(w.ctx.now, w.cfg.showSeconds ? "HH:mm:ss" : "HH:mm")
            color: Theme.Palette.on_surface
            font.family: Tokens.typography.family
            font.pixelSize: w.timeSize
            font.weight: Font.Light
            font.features: { "tnum": 1 }
        }
        Text {
            visible: w.cfg.showDate
            text: w.ctx.now.toLocaleDateString(Qt.locale(), "d MMMM yyyy")
            color: Theme.Palette.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Math.max(Math.round(10 * w.s), Math.round(w.timeSize * 0.32))
        }
    }

    Text {
        visible: w.cfg.showWeekday
        anchors.right: parent.right
        anchors.rightMargin: 16 * w.s
        anchors.verticalCenter: parent.verticalCenter
        text: w.ctx.now.toLocaleDateString(Qt.locale(), "ddd")
        color: Theme.Palette.primary
        font.family: Tokens.typography.family
        font.pixelSize: Math.round(16 * w.s)
    }
}
