pragma Singleton
import QtQuick
import Quickshell
import "../config"
import "../theme"

// Геометрия бара по стилю из Config.options.bar.style:
// "attached" — прилипает к верху, скруглены нижние углы;
// "full" — во всю ширину, без скруглений;
// "floating" — отступы сверху и по бокам, скруглены все углы;
// "modular" — без общей заливки, у каждого модуля своя подложка.
Singleton {
    id: root

    readonly property var cfg: Config.options.bar
    readonly property string style: cfg.style

    // Высота самого бара (без отступа сверху)
    readonly property int barHeight: Tokens.scaled(56)
    // У бара есть общая заливка: выпадающие окна срастаются с ней «ушами»
    readonly property bool filled: style !== "modular"
    // Скругление углов бара
    readonly property int radius: style === "full" ? 0 : Tokens.radius(20)
    readonly property bool roundTop: style === "floating"
    readonly property int marginTop: style === "floating" ? Tokens.scaled(cfg.floatingMarginTop) : 0
    readonly property int marginSide: style === "full" ? 0
        : style === "floating" ? Tokens.scaled(cfg.floatingMarginSide)
        : Math.round(20 * Tokens.spacingScaleH)
    // Отступ выпадающего окна от бара, когда «ушей» нет
    readonly property int popupGap: Tokens.spacingMediumV

    // Открытые выпадающие окна (BarDropdown): пока они есть, автоскрытие бар не прячет
    property int openPopups: 0
}
