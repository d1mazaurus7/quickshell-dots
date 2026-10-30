pragma Singleton
import QtQuick
import "../../theme" as Theme

QtObject {
    // Общие настройки для всех FlowHighlight
    property color highlightColor: Theme.Palette.primary
    property color selectedTextColor: Theme.Palette.on_primary_container
    property real animationDuration: 200 // в миллисекундах
    property real highlightRadius: 10
    property real highlightOpacity: 0.3
    property real selectedScale: 1.0
    property bool smoothScroll: true
    property int highlightZOrder: 10

    // Обновление настроек анимации
    function updateSettings(color, duration, radius, opacity, scale, zOrder) {
        if (color !== undefined) highlightColor = color
        if (duration !== undefined) animationDuration = duration
        if (radius !== undefined) highlightRadius = radius
        if (opacity !== undefined) highlightOpacity = opacity
        if (scale !== undefined) selectedScale = scale
        if (zOrder !== undefined) highlightZOrder = zOrder
    }
}
