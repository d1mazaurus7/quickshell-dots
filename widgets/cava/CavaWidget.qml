pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../../shell/theme"
import "../controls"
import "../music" as MusicWidget
import "../../Bar/music_equalizer" as Music

// Визуализатор звука cava: волна или полосы на всю карточку, отражение по осям
Item {
    id: root

    property var settings: ({})
    property bool editing: false
    // Без фона карточка полностью прозрачна; размытие тогда — только под самими волнами/палочками
    readonly property bool background: settings.background === true
    readonly property Item blurItem: background && settings.blur === true ? card : null
    readonly property bool shapeBlur: !background && settings.behindBlur === true
    // Бесцветный: фигуры не закрашены, видно только размытие под ними
    readonly property bool colorless: shapeBlur && settings.colorless === true
    // Область размытия по форме спектра (WidgetWindow предпочитает её blurItem)
    readonly property Region blurShape: shapeBlur ? shapeRegion : null

    Region {
        id: shapeRegion
        regions: spectrum.shapeRegions
    }

    readonly property var colors: Tokens.colors

    Music.CavaSource {
        id: cava
        active: root.visible
    }

    WidgetCard {
        id: card
        anchors.fill: parent
        color: !root.background || root.blurItem ? "transparent" : root.colors.surface_container
        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

        MusicWidget.CavaSpectrum {
            id: spectrum
            anchors.fill: parent
            anchors.margins: root.settings.style === "bars" ? Tokens.spacingMedium : 0
            values: cava.values
            active: cava.active
            style: root.settings.style
            barOpacity: root.colorless ? 0 : 0.85
            waveTopOpacity: root.colorless ? 0 : 0.85
            waveBottomOpacity: root.colorless ? 0 : 0.25
            barCount: root.settings.barCount
            shapeEnabled: root.shapeBlur
            // Свечение: размытая тень цвета спектра вокруг фигур
            layer.enabled: root.settings.glow === true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.colors.primary
                shadowBlur: 1.0
                blurMax: 32
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
            flipH: root.settings.flipH === true
            flipV: root.settings.flipV === true
        }
    }
}
