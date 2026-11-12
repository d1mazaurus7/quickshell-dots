# Виджеты рабочего стола (для агентов)

## Структура

```
widgets/
  Widgets.qml               — корень: состояние, IPC, окна виджетов, редактор (подключён в shell/Shell.qml)
  WidgetsState.qml          — экземпляры (Config.options.widgets.items) и состояние редактора; все записи — здесь
  WidgetRegistry.qml        — список типов виджетов
  WidgetsIpc.qml            — qs ipc call widgets toggle|open|close
  WidgetWindow.qml          — PanelWindow одного экземпляра (слой Bottom, позиция через margins)
  WindowFocus.qml           — есть ли окно в фокусе niri (event-stream), сервис services.focus
  WidgetHost.qml            — загрузка компонента экземпляра и привязки settings/services/editing (окно и лок-скрин)
  editor/                   — редактор: EditorWindow, EditorToolbar, WidgetSettingsPanel, WidgetFrame, GridOverlay, Expander
  controls/                 — переиспользуемые элементы (см. ниже)
  music/                    — виджет «Музыкальный плеер»
  cava/                     — виджет «Визуализатор» (спектр cava)
  clock/                    — виджет «Часы» (ClockGlyph — символ со slide-сменой)
  sysmon/                   — виджеты потребления: диск, RAM, CPU, GPU (один компонент, ресурс — settings.kind)
  timer/                    — виджет «Таймер» (TimerDrum — барабан выбора времени, цифры — clock/ClockGlyph)
  media/                    — виджет «Медиа»: фото/gif/видео из любого файла, шаблоны формы (MediaShapes.js)
  lock/                     — виджеты только лок-скрина: «Пользователь», «Поле пароля» (LockPasswordField)
```

- Каждый экземпляр — отдельное окно `WidgetWindow` (`WlrLayer.Bottom`, `ExclusionMode.Ignore`,
  namespace `qs:widget`): ввод получает только область виджета.
- Редактор — полноэкранное окно `WlrLayer.Overlay` (namespace `qs:widget-editor`) на мониторе в фокусе Niri.
  Виджеты под ним видны, рамки `WidgetFrame` повторяют их геометрию. Esc — закрыть.
- Окна создаются `Variants` по `WidgetsState.uids` (строки): при изменении `items` окна не пересоздаются.

## Редактор

Бинд в Niri (конфиг Niri правит пользователь):

```kdl
Mod+W { spawn "qs" "ipc" "call" "widgets" "toggle"; }
```

Кнопки панели: `add` — список типов (раскрывается, раздвигая кнопки), `edit` — режим перемещения
выбранного виджета, `settings` — панель настроек выбранного виджета (размер, настройки типа, удаление),
`grid_on` — сетка и слайдер её шага. При включённой сетке перемещение прилипает к её шагу.

## Лок-скрин

Отдельный набор экземпляров (`widgets.lockItems`) со своими позициями и настройками: второй
`WidgetsState { lockSet: true }` в `Widgets.qml` (`Widgets.lockStore`). `Bar/lockscreen` рисует его
через `WidgetHost` на поверхностях ext-session-lock — любой тип виджета работает там без изменений.
Редактор — тот же IPC `widgets`: при блокировке он открывает редактор набора лок-скрина
(`EditorContent` внутри поверхности). В Niri бинду нужен `allow-when-locked=true`, иначе он заблокирован.
Размытие на лок-скрине — общая размытая копия фона под `blurItem`; `blurShape` не поддерживается.
Поля реестра: `lockOnly: true` — тип только набора лок-скрина, `single: true` — не больше одного экземпляра.
Сервис `services.lock` — `LockState` (ввод пароля), только у набора лок-скрина.
Типы набора и поиск — `WidgetsState.types` / `find(type)`, а не `registry` напрямую.

## Контракт компонента виджета

Файл `widgets/<name>/<Name>Widget.qml`, корень — `Item` (размер задаёт окно, `anchors.fill`):

```qml
Item {
    id: root
    // Настройки экземпляра с дефолтами типа (из WidgetRegistry.defaults)
    property var settings: ({})
    // true, пока открыт редактор (ввод в это время перехватывает редактор)
    property bool editing: false
    // Необязательно: общие сервисы оболочки (WidgetsState.services), сейчас { equalizer, focus }.
    // Передаются только виджетам, объявившим это свойство
    property var services: ({})
    // Необязательно: Item (со свойством radius), под которым окно размывает фон; null — без размытия
    property Item blurItem: null
    // Необязательно: своя Region размытия (например, по форме фигур); если не null — важнее blurItem
    property Region blurShape: null
}
```

Локальные типы виджета (страницы, части) — рядом в `widgets/<name>/`.

- Виджет **не пишет** в `Config` и не знает о `WidgetsState`.
- Вёрстка должна подстраиваться под любой размер в пределах `min/max` из реестра.
- Подложка — `WidgetCard` из `controls/`. Цвета — `Tokens.colors`, шрифт — `Tokens.typography.family`
  / `Tokens.font*`, отступы, скругления, длительности — `Tokens.*`.
- Системное состояние (MPRIS, процессы) — существующие сервисы/компоненты проекта, не копии.
- Звук нажатия — `WidgetSound.click()` в `onPressed`.

## Добавление нового типа

1. Создать `widgets/<name>/<Name>Widget.qml` по контракту выше и добавить
   `import "<name>" as ...` в `WidgetRegistry.qml`. Каталог загружается только по URL,
   без импорта сканер Quickshell его не видит — локальные типы дают «X is not a type».
2. При наличии настроек — `widgets/<name>/<Name>WidgetSettings.qml` (см. WIDGETS_SETTINGS_README.md).
3. Добавить запись в `WidgetRegistry.types`:

```qml
{
    type: "clock",                       // уникальный id, хранится в items[].type
    title: "Часы",                       // подпись в списке добавления и панели настроек
    icon: "schedule",                    // Material Symbols Rounded
    component: Qt.resolvedUrl("clock/ClockWidget.qml"),
    settingsComponent: Qt.resolvedUrl("clock/ClockWidgetSettings.qml"),  // "" — без страницы
    width: 200, height: 100,             // размер нового экземпляра, лог. px до Tokens.scaled
    minWidth: 120, maxWidth: 400,        // пределы слайдеров размера
    minHeight: 80, maxHeight: 240,
    resizable: true,                     // необязательно: края тянутся мышью в редакторе (WidgetFrame)
    flippable: true,                     // необязательно: кнопки отражения над рамкой, пишут flipH/flipV
    defaults: { showSeconds: false }     // дефолты настроек экземпляра
}
```

Больше ничего регистрировать не нужно: список добавления, окна и панель настроек берут данные из реестра.
Переименование `type` ломает сохранённые экземпляры — не переименовывать.

## controls/

Модуль с `qmldir` — новый файл нужно добавить в `controls/qmldir`, иначе он не импортируется.
Импорт: `import "../controls"` (из `widgets/<name>/`).

| Компонент     | Назначение |
|---------------|------------|
| `WidgetSound` | singleton, `click()` — звук `Config.options.sound.clickSound` при `interactionSounds` |
| `WidgetCard`  | скруглённая подложка виджета, обрезает содержимое (`ClippingRectangle`) |
| `IconButton`  | квадратная кнопка со значком; `icon`, `checked` (морфинг в пилюлю), `enabled`, `size`, `clicked()` |
| `TextButton`  | пилюля со значком и подписью; `icon`, `text`, `danger`, `clicked()` |
| `ToggleRow`   | подпись + переключатель; `text`, `checked`, `toggled(bool)` |
| `ChoiceRow`   | подпись + сегментированный выбор с перетекающим выделением; `text`, `options: [{ value, label }]`, `value`, `selected(value)` |
| `DropdownRow` | подпись + выпадающий список (вид `SettingDropdown`), раскрывается внутри строки и раздвигает соседей; `text`, `options: [{ value, label }]`, `value`, `fieldWidth`, `expanded`, `selected(value)` |
| `ChildGroup`  | дочерние настройки с отступом и линией слева; `shown: false` плавно сворачивает группу; дети — в теле, `width: parent.width` |
| `ImagePicker` | сетка превью файлов папки (`FolderListModel`); `folder`, `nameFilters`, `value` (имя файла), `columns`, `selected(name)` |
| `FileBrowser` | обзор ФС (`FolderListModel` в `GridView`): папки, превью картинок, значок у видео; `folder` (путь), `nameFilters`, `videoSuffixes`, `value` (путь), `columns`, `rows`, `selected(path)` |
| `TabSwitch`   | вкладки-значки: выбранная скругляется в круг, выделение перетекает; `tabs: [{ id, icon }]`, `current`, `size`, `selected(id)` |
| `SliderRow`   | подпись + `settings/controls/SettingSlider.qml`; `text`, `from`, `to`, `stepSize`, `value`, `formatValue`, `sliderWidth`, `moved(v)` (по отпусканию), `dragged(v)` (живое) |

У всех кнопок есть hover/pressed и звук нажатия. Новые общие элементы класть сюда же,
не дублировать их внутри виджетов.

## Проверка

```sh
L=$(dirname $(dirname $(ls -d /nix/store/*qtdeclarative*/bin/qmllint | head -1)))
Q=$(dirname $(dirname $(readlink -f $(which quickshell))))/lib/qt-6/qml
$L/bin/qmllint -I "$Q" -I $L/lib/qt-6/qml widgets/*.qml widgets/*/*.qml
```

Шум линтера: `PanelWindow is not creatable`, `margins`, члены `JsonObject` из `Config` — ложные.
Рабочая оболочка перечитывает файлы сама: ошибки смотреть в `qs log`, IPC — `qs ipc show`.
