# Окно настроек: инструкция для агентов

Перед добавлением настроек прочитай [SETTINGS_README.md](../shell/config/SETTINGS_README.md) —
там схема `Config`, правила дефолтов и записи. Каждый новый пункт в окне должен сразу
читать и писать `Config.options.<секция>.<ключ>`; не делай пунктов «без настройки».

## Структура

```
settings/
  SettingsWindow.qml      # PanelWindow-оверлей, панель по центру: разделы слева, страница справа
  SettingsIpc.qml         # IpcHandler "settings": toggle | open | close (свойство window.open)
  controls/
    SettingRow.qml        # пункт: title + description слева, элемент управления справа
    SettingDropdown.qml   # выпадающий список строк (поиск, превью шрифтов)
    SettingSlider.qml     # слайдер: value, from/to/stepSize, formatValue, moved(value) по отпусканию
    SettingSwitch.qml     # переключатель: checked, toggled(checked)
  pages/
    FontPage.qml          # раздел «Шрифт» — образец страницы
    InterfacePage.qml     # раздел «Интерфейс»: масштаб, отступы, скругление, обводка
```

- Экземпляр окна и IPC создаются один раз в `shell/Shell.qml`.
- Открытие: `qs ipc call settings toggle`. Закрытие: Esc, клик по затемнению, IPC.
- Окно: `WlrLayer.Overlay`, `ExclusionMode.Ignore`, клавиатура `Exclusive` только пока `open`.
- Видимость: `visible: open || fade.running` — окно скрывается после анимации затемнения.

## Добавить раздел

1. Создай `settings/pages/<Name>Page.qml` по образцу `FontPage.qml`:

```qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var bar: Config.options.bar   // своя секция Config

    spacing: Tokens.spacingMedium

    // Заголовок раздела
    Text {
        Layout.bottomMargin: Tokens.spacingMedium
        text: "Бар"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + 4
    }

    SettingRow {
        title: "Высота"
        description: "Высота панели в пикселях"
        // элемент управления — дочерний элемент SettingRow
    }
}
```

2. Зарегистрируй страницу в `SettingsWindow.qml`:

```qml
readonly property var sections: [
    { title: "Шрифт", page: fontPage },
    { title: "Бар", page: barPage }
]

Component { id: barPage; Pages.BarPage {} }
```

Порядок в массиве = порядок в списке слева. `title` участвует в поиске по разделам.

3. Если нужной секции/ключа в `Config` нет — добавь по [SETTINGS_README.md](../shell/config/SETTINGS_README.md#добавление-новой-секции).

Правила страницы:
- Корень — `ColumnLayout` без фиксированной ширины: её задаёт `Loader` в окне.
- Высота — implicit (окно прокручивает страницу через `Flickable`).
- Используй `id`-квалифицированный доступ (`page.colors`, `row.modelData`) —
  в файлах стоит `pragma ComponentBehavior: Bound`.

## Добавить пункт настройки

Пункт, который показывается только при включённом другом, ставь сразу под родителем,
скрывай через `shown: …` (плавно разворачивается, в отличие от `visible`) и помечай
`child: true` — он сдвигается вправо.

`SettingRow` — контейнер; элемент управления кладётся внутрь как дочерний:

```qml
SettingRow {
    title: "Семейство"
    description: "Основной шрифт интерфейса"

    SettingDropdown {
        model: Qt.fontFamilies()
        currentValue: page.typography.family          // чтение — привязкой
        searchable: true
        onActivated: value => page.typography.family = value   // запись — присваиванием
    }
}
```

### SettingDropdown

| Свойство / сигнал    | Назначение                                         |
|----------------------|----------------------------------------------------|
| `model`              | массив строк                                       |
| `currentValue`       | текущее значение (привязать к `Config`)            |
| `searchable`         | поле фильтра в списке                              |
| `fontPreview`        | пункты рисуются своим шрифтом                      |
| `popupHeight`        | высота списка, по умолчанию 280                    |
| `expanded`           | список раскрыт                                     |
| `activated(value)`   | выбран пункт — здесь писать в `Config`             |

Список раскрывается поверх следующих пунктов, поэтому у `SettingRow` поднимай `z`:

```qml
SettingRow {
    z: dropdown.expanded ? 1 : 0
    SettingDropdown { id: dropdown; ... }
}
```

Ограничение: раскрытый список не увеличивает высоту страницы и обрезается `Flickable`,
если пункт у нижнего края. Выпадающие списки ставь не последними или уменьши `popupHeight`.

### Новый элемент управления

Если нужен переключатель, слайдер, числовое поле и т.п. — создай его в `settings/controls/`
(`SettingSwitch.qml`, `SettingSlider.qml`, …), а не внутри страницы, если он понадобится
больше чем в одном месте. Требования:

- API как у dropdown: `value`/`currentValue` на вход, сигнал на изменение; в `Config`
  пишет страница, а не контрол.
- Частые изменения (слайдер) — сигнал по отпусканию (`onPressedChanged`) или debounce,
  чтобы не перезаписывать `settings.json` на каждый пиксель.
- Цвета только `Tokens.colors.*` (Palette/matugen), размеры/шрифты/длительности — `Tokens.*`.
- Состояния hover и pressed (см. ниже).

## Визуал и анимации

Цвета (Material роли из `Palette`):

| Элемент                      | Цвет                                                         |
|------------------------------|--------------------------------------------------------------|
| фон панели                   | `surface`, рамка `outline_variant`                           |
| карточка / пункт             | `surface_container`                                          |
| hover / pressed              | `surface_container_high` / `surface_container_highest`       |
| выбранный элемент            | `secondary_container`, текст `on_secondary_container`        |
| фокус / активная рамка       | `primary`                                                    |
| основной / вторичный текст   | `on_surface` / `on_surface_variant`                          |

Шаблон интерактивного элемента:

```qml
Rectangle {
    color: area.pressed ? colors.surface_container_highest
         : area.containsMouse ? colors.surface_container_high
         : colors.surface_container
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ...
    }
}
```

Анимации — короткие и мягкие, без задержки реакции:
- цвет, hover, поворот стрелок — `Tokens.animationFast`;
- появление окна/панелей — `Tokens.animationMedium`, `Easing.OutCubic`;
- появление выпадающих элементов — opacity + небольшой сдвиг `y`
  (`Tokens.spacingMedium`), `visible: opacity > 0`.

Длительности не хардкодить: они масштабируются `appearance.animationScale` через `Tokens`.

## Подводные камни

- В `RowLayout` колонка, чьи дети имеют `Layout.fillWidth`, сама начинает растягиваться.
  Для колонок фиксированной ширины ставь `Layout.fillWidth: false` + `Layout.maximumWidth`.
- Esc обрабатывает только `Shortcut` окна и закрывает окно целиком (даже из поиска dropdown).
  Не добавляй свои `Keys.onEscapePressed` в контролах.
- Окно само использует `Tokens`, поэтому меняется вместе с настройками шрифта/отступов —
  проверяй, что вёрстка не ломается на крайних значениях.

## Проверка

- `qmllint` изменённых файлов (команда — в SETTINGS_README.md). Предупреждение
  «PanelWindow is not creatable» ложное.
- Ручная: `qs ipc call settings toggle` → раздел виден в списке и в поиске → изменение
  пункта сразу применяется и записывается в `~/.config/quickshell/settings.json`.
