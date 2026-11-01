pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../../shell/bar"
import "../controls"

// Раздел «Бар»: Config.options.bar — расстановка модулей по блокам перетаскиванием
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var bar: Config.options.bar
    readonly property var sides: ["left", "center", "right"]

    // Блоки модулей по id из конфига; неизвестные id пропускаются
    function modulesOf(ids) {
        return Array.from(ids).map(id => BarModules.find(id)).filter(m => m !== null);
    }

    readonly property var placed: [...bar.left, ...bar.center, ...bar.right]
    readonly property var pool: BarModules.list.filter(m => !placed.includes(m.id))

    // Переносит модуль в блок side на позицию index; side "pool" — убрать с бара
    function move(id, side, index) {
        for (const s of sides) {
            const ids = Array.from(bar[s]).filter(x => x !== id);
            if (s === side)
                ids.splice(index, 0, id);
            // Неизменённые блоки не трогаем — иначе бар пересоздаёт их модули
            if (ids.join("\n") !== Array.from(bar[s]).join("\n"))
                bar[s] = ids;
        }
    }

    spacing: Tokens.spacingLargeV

    Text {
        text: "Бар"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: -Tokens.spacingMediumV
        text: "Перетащите модуль в блок бара; порядок в блоке — порядок на баре. Верните модуль в список, чтобы убрать его с бара"
        color: page.colors.on_surface_variant
        font: Tokens.fontSmall
        wrapMode: Text.Wrap
    }

    // Неразмещённые модули
    ModuleDropZone {
        Layout.fillWidth: true
        modules: page.pool
        ordered: false
        minHeight: Tokens.scaled(180)
        dragLayer: dragLayer
        onDropped: id => page.move(id, "pool", 0)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacingLarge

        Repeater {
            model: [
                { side: "left", title: "Слева" },
                { side: "center", title: "Посередине" },
                { side: "right", title: "Справа" }
            ]

            ModuleDropZone {
                required property var modelData
                Layout.fillWidth: true
                // Равная ширина независимо от содержимого
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                title: modelData.title
                modules: page.modulesOf(page.bar[modelData.side])
                minHeight: Tokens.scaled(150)
                dragLayer: dragLayer
                onDropped: (id, index) => page.move(id, modelData.side, index)
            }
        }
    }

    // Слой для перетаскиваемого блока поверх всей страницы
    Item {
        id: dragLayer
        Layout.preferredHeight: 0
        Layout.topMargin: -page.spacing
        Layout.fillWidth: true
        z: 1
    }
}
