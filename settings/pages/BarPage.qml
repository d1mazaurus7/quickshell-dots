pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../../shell/bar"
import "../controls"

// Раздел «Бар»: Config.options.bar — стиль, автоскрытие и расстановка модулей
// по блокам перетаскиванием
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

    SettingRow {
        // Раскрытый список рисуется поверх следующих пунктов
        z: styleDropdown.expanded ? 1 : 0
        title: "Стиль"
        description: "Форма и положение бара"

        SettingDropdown {
            id: styleDropdown
            readonly property var styles: [
                { value: "attached", title: "Прилипающий к верху" },
                { value: "full", title: "Обычный" },
                { value: "floating", title: "Плавающий" },
                { value: "modular", title: "Модульный" }
            ]
            model: styles.map(s => s.title)
            popupHeight: Tokens.scaled(176)
            currentValue: (styles.find(s => s.value === page.bar.style) ?? styles[0]).title
            onActivated: value => page.bar.style = styles.find(s => s.title === value).value
        }
    }

    SettingRow {
        shown: page.bar.style === "floating"
        child: true
        title: "Отступ сверху"

        SettingSlider {
            value: page.bar.floatingMarginTop
            from: 0
            to: 40
            stepSize: 1
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.bar.floatingMarginTop = Math.round(value)
        }
    }

    SettingRow {
        shown: page.bar.style === "floating"
        child: true
        title: "Отступ по бокам"

        SettingSlider {
            value: page.bar.floatingMarginSide
            from: 0
            to: 200
            stepSize: 1
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.bar.floatingMarginSide = Math.round(value)
        }
    }

    SettingRow {
        title: "Автоскрытие"
        description: "Бар выезжает при наведении курсора и прячется, когда курсор уходит"

        SettingSwitch {
            checked: page.bar.autoHide
            onToggled: checked => page.bar.autoHide = checked
        }
    }

    SettingRow {
        shown: page.bar.autoHide
        child: true
        title: "Задержка скрытия"
        description: "Через сколько бар прячется после ухода курсора"

        SettingSlider {
            value: page.bar.autoHideDelay
            from: 0
            to: 3000
            stepSize: 100
            formatValue: v => (Math.round(v) / 1000).toFixed(1) + " с"
            onMoved: value => page.bar.autoHideDelay = Math.round(value)
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacingMediumV
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
