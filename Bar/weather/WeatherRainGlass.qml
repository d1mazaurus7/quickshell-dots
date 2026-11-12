import QtQuick
import "../../shell/theme"

// Капли дождя на стекле окна погоды (шейдер shaders/raindrops.frag): капли разной формы и размера,
// цепочки капель от старых следов, стекающие капли со струйкой; капли преломляют небо
// под собой; за стеклом — струи дождя.
// Один проход шейдера на кадр; source — слой неба того же размера. Время идёт, только пока running.
// Параметры осадков меняются плавно.
ShaderEffect {
    id: glass

    property Item skySource
    property bool running: false
    property real unit: 1
    property real topRadius: 0
    property real bottomRadius: 0

    property real staticAmount: 0
    property real slideAmount: 0
    property real dropSize: 1
    property real streaks: 0
    // 0 — капли на стекле перед небом (перевёрнутое изображение), 1 — поверх содержимого (лупа)
    property real lens: 0
    Behavior on staticAmount { NumberAnimation { duration: Tokens.animationSlow * 3 } }
    Behavior on slideAmount { NumberAnimation { duration: Tokens.animationSlow * 3 } }
    Behavior on dropSize { NumberAnimation { duration: Tokens.animationSlow * 3 } }
    Behavior on streaks { NumberAnimation { duration: Tokens.animationSlow * 3 } }

    readonly property var source: skySource
    readonly property size itemSize: Qt.size(width, height)
    property real time: 0

    NumberAnimation on time {
        from: 0
        to: 3600
        duration: 3600000
        loops: Animation.Infinite
        running: glass.running && glass.visible
    }

    // Версия в имени файла: Qt кеширует шейдер по пути, и без новой версии запущенная оболочка
    // может показывать прежний вариант. Сборка: qsb --glsl "100 es,120,150" --hlsl 50 --msl 12
    // -o shaders/raindrops-vN.qsb shaders/raindrops.frag
    fragmentShader: Qt.resolvedUrl("shaders/raindrops-v6.qsb")
}
