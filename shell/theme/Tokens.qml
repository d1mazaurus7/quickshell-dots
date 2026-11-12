pragma Singleton
import QtQuick
import "../../theme" as Theme
import "../config"

QtObject {
    readonly property var appearance: Config.options.appearance
    readonly property var typography: Config.options.typography

    // Цвета из Palette
    readonly property var colors: Theme.Palette

    // Общий масштаб интерфейса
    readonly property real scale: appearance.scale
    // Размер в пикселях с учётом масштаба
    function scaled(base: real): int {
        return Math.round(base * scale);
    }

    // Отступы по горизонтали
    readonly property real spacingScaleH: scale * appearance.spacingHorizontal
    readonly property int spacingSmall: Math.round(4 * spacingScaleH)
    readonly property int spacingMedium: Math.round(8 * spacingScaleH)
    readonly property int spacingLarge: Math.round(16 * spacingScaleH)

    // Отступы по вертикали
    readonly property real spacingScaleV: scale * appearance.spacingVertical
    readonly property int spacingSmallV: Math.round(4 * spacingScaleV)
    readonly property int spacingMediumV: Math.round(8 * spacingScaleV)
    readonly property int spacingLargeV: Math.round(16 * spacingScaleV)

    // Скругления
    readonly property int radiusSmall: Math.round(4 * scale * appearance.radiusScale)
    readonly property int radiusMedium: Math.round(8 * scale * appearance.radiusScale)
    readonly property int radiusLarge: Math.round(16 * scale * appearance.radiusScale)
    // Произвольное скругление модуля с учётом radiusScale (без scale:
    // размеры модулей и так масштабируются через высоту бара)
    function radius(base: real): int {
        return Math.round(base * appearance.radiusScale);
    }

    // Непрозрачность фона окон с размытием под ними
    readonly property real surfaceOpacity: appearance.surfaceOpacity
    // Запрашивать ли размытие у компositора
    readonly property bool blurEnabled: appearance.blur > 0

    // Обводка
    readonly property int borderWidth: appearance.borders ? 1 : 0

    // Шрифт
    readonly property font fontSmall: Qt.font({ family: typography.family, pixelSize: scaled(typography.size - 2) })
    readonly property font fontMedium: Qt.font({ family: typography.family, pixelSize: scaled(typography.size) })
    readonly property font fontLarge: Qt.font({ family: typography.family, pixelSize: scaled(typography.size + 2) })

    // Длительности анимаций (в миллисекундах)
    readonly property int animationFast: Math.round(150 * appearance.animationScale)
    readonly property int animationMedium: Math.round(200 * appearance.animationScale)
    readonly property int animationSlow: Math.round(300 * appearance.animationScale)
}
