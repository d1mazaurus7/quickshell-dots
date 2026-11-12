pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"

// Полоса облаков неба: набор облаков на ширину области, повторённый трижды. Облака рисуются один
// раз (слои со сглаживанием — дробный сдвиг без ступенек), кадр стоит только сдвига полосы.
// Сдвиг: постоянный дрейф (phase) плюс shift — смещение от перемотки времени, в пикселях.
// clouds — [{ x, y, s }] (x, y — доли области); первые visibleCount видны.
Item {
    id: layer

    property var clouds: []
    property int visibleCount: clouds.length
    property real unit: 1
    property real areaHeight: height
    property color tone: "white"
    // Время прохода облаков на ширину области
    property int duration: 90000
    property bool running: false
    property real shift: 0

    readonly property real k: Tokens.animationSlow / 300
    property real phase: 0

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: layer.duration
        loops: Animation.Infinite
        running: layer.running && layer.k > 0
    }

    Item {
        id: strip
        width: layer.width * 3
        height: layer.height
        // Видна средняя треть полосы; хвосты облаков берутся из соседних копий
        readonly property real offset: layer.width > 0 ? ((layer.phase * layer.width + layer.shift) % layer.width + layer.width) % layer.width : 0
        x: -layer.width * 2 + offset

        Repeater {
            model: layer.clouds.length * 3
            WeatherCloud {
                id: cloud
                required property int index
                readonly property int i: index % layer.clouds.length
                readonly property var c: layer.clouds[i]
                unit: layer.unit
                size: c.s
                x: c.x * layer.width + Math.floor(index / layer.clouds.length) * layer.width
                y: c.y * layer.areaHeight
                tone: layer.tone
                opacity: i < layer.visibleCount ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow * 2 } }
            }
        }
    }
}
