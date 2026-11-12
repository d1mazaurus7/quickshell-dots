import QtQuick
import Quickshell.Widgets
import "../../shell/theme"

// Размытый фон под полупрозрачной карточкой. Источник — свойство cardBackdrop
// у ближайшего предка (панель контента окна настроек); берётся только участок под карточкой.
// Класть первым ребёнком карточки: z = -1, поверх цвета карточки, под содержимым
ClippingRectangle {
    id: root

    readonly property Item card: parent
    readonly property Item host: {
        for (let p = card ? card.parent : null; p; p = p.parent)
            if (p.cardBackdrop !== undefined)
                return p;
        return null;
    }
    readonly property Item source: host ? host.cardBackdrop : null
    readonly property bool active: Tokens.appearance.cardBlur && source !== null
    // Позиция карточки в координатах host; пересчитывается при прокрутке и раскладке
    readonly property point offset: {
        if (!active)
            return Qt.point(0, 0);
        let x = 0, y = 0;
        for (let p = card; p && p !== host; p = p.parent) {
            x += p.x;
            y += p.y;
        }
        return Qt.point(x, y);
    }

    anchors.fill: parent
    z: -1
    radius: card ? card.radius : 0
    color: "transparent"
    visible: active

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: root.source
        sourceRect: Qt.rect(root.offset.x, root.offset.y, width, height)
        live: root.active
    }

    // Тонировка поверх размытия
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Tokens.colors.surface_container, 0.45)
    }
}
