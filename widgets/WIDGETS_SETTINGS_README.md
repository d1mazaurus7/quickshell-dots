# Настройки виджетов (для агентов)

Настройки виджетов редактируются **только в редакторе виджетов** (`widgets/editor/WidgetSettingsPanel.qml`),
не в окне `settings/`. Глобальные настройки оболочки — `shell/config/SETTINGS_README.md`.

## Хранение

`Config.options.widgets` в `settings.json`:

| Ключ       | Тип | Смысл |
|------------|-----|-------|
| `items`    | var | `[{ uid, type, screen, x, y, width, height, settings }]` — экземпляры |
| `grid`     | bool | сетка редактора включена |
| `gridSize` | int | шаг сетки, лог. px |

- `x`, `y` — от левого верхнего угла экрана `screen` (имя монитора), `width`/`height` — px окна.
- `settings` — только изменённые пользователем ключи экземпляра. Дефолты типа лежат
  в `WidgetRegistry.types[].defaults` и подмешиваются `WidgetsState.settingsOf(uid)`.
  Поэтому **у каждого экземпляра свои настройки**, независимые от других виджетов и от модулей бара.
- Новый ключ = новое поле в `defaults`; старые экземпляры получат его автоматически.
  Не дублируй дефолт в виджете (`?? true`) — `settings` уже содержит все ключи из `defaults`.

## Запись

Только через `WidgetsState`:

- `setSetting(uid, key, value)` — настройка экземпляра;
- `update(uid, patch)` — поля экземпляра;
- `startPreview(uid)` + `previewX/Y/Width/Height` + `commitPreview()` — геометрия
  при перетаскивании/слайдере: живой предпросмотр без записи файла, запись по отпусканию;
- `add(type, w, h)`, `remove(uid)`.

`items` переприсваивается целиком (мутация на месте не сохранится). Пиши по отпусканию
(`moved`, `onReleased`), а не на каждый пиксель.

## Страница настроек типа

Файл `widgets/<name>/<Name>WidgetSettings.qml`, путь — в `settingsComponent` реестра.
Панель задаёт ширину, ставит `settings` и слушает `settingChanged`:

```qml
import QtQuick
import "../../shell/theme"
import "../controls"

Column {
    id: root

    property var settings: ({})
    signal settingChanged(string key, var value)

    spacing: Tokens.spacingMediumV

    ToggleRow {
        width: parent.width
        text: "Секунды"
        checked: root.settings.showSeconds === true
        onToggled: c => root.settingChanged("showSeconds", c)
    }
    ChoiceRow {
        width: parent.width
        text: "Формат"
        options: [{ value: "24", label: "24 ч" }, { value: "12", label: "12 ч" }]
        value: root.settings.format
        onSelected: v => root.settingChanged("format", v)
    }
    SliderRow {
        width: parent.width
        text: "Прозрачность"
        from: 0; to: 1; stepSize: 0.05
        formatValue: v => Math.round(v * 100) + "%"
        value: root.settings.opacity
        onMoved: v => root.settingChanged("opacity", v)
    }
}
```

- Страница не пишет в `Config` сама — только `settingChanged`.
- Размер (ширина/высота) и удаление панель рисует сама — на странице их не повторять.
- Длинная страница прокручивается внутри панели (не выше половины экрана).
- Элементы — из `widgets/controls/` (см. WIDGETS_README.md). Зависимые настройки
  кладутся в `ChildGroup { shown: <родитель включён> }` сразу под родителем:
  у них отступ, при выключении родителя они прячутся.
- Выбор из 2–3 коротких вариантов — `ChoiceRow`, из большего числа или длинных подписей — `DropdownRow`.

## Музыкальный плеер (`musicPlayer`)

| Ключ              | Тип    | Дефолт       | Смысл |
|-------------------|--------|--------------|-------|
| `showArtist`      | bool   | `true`       | строка исполнителя |
| `showTime`        | bool   | `true`       | «позиция / длина» над таймлайном |
| `timelineStyle`   | string | `"material"` | `material` — волнистая линия, `wave` — залитые волны |
| `wavyTimeline`    | bool   | `true`       | волны идут при воспроизведении; выкл — ровная линия |
| `coverBackground` | bool   | `true`       | обложка на фоне карточки |
| `backgroundBlur`  | bool   | `true`       | размытие фоновой обложки |
| `cava`            | bool   | `false`      | спектр cava по нижнему краю |
| `cavaStyle`       | string | `"wave"`     | `wave` — сплошная волна, `bars` — полосы |
| `danceGifEnabled` | bool   | `false`      | gif справа на странице плеера |
| `danceGif`        | string | `""`         | имя файла из `assets/gifs/dance` |
| `equalizer`       | bool   | `false`      | страница эквалайзера (общий `EqualizerState` через `services`) |
| `lyrics`          | bool   | `false`      | страница текста песни |
| `lyricsFontSize`  | int    | `15`         | размер строк, px до масштабирования |
| `lyricsAlign`     | string | `"center"`   | `left` / `center` / `right` |
| `lyricsScroll`    | bool   | `true`       | ручная прокрутка текста |
| `lyricsSeek`      | bool   | `true`       | клик по строке — перемотка |

Независимы от `Config.options.musicPlayer` (окно плеера в баре).

## Потребление ресурсов (`sysDisk`, `sysRam`, `sysCpu`, `sysGpu`)

Один компонент и одна страница настроек на четыре типа, настройки у каждого экземпляра свои.
`kind` (`disk`/`ram`/`cpu`/`gpu`) — ресурс, задан в дефолтах типа, не меняется.

| Ключ        | Тип  | Дефолт | Смысл |
|-------------|------|--------|-------|
| `usageTab`  | bool | `true` | вкладка занятого ресурса |
| `showWave`  | bool | `true` | заливка с волной |
| `showUsed`  | bool | `true` | занятое количество |
| `showFree`  | bool | `true` | свободное количество |
| `graphTab`  | bool | `true` | вкладка графика |
| `graphSpan` | int  | `60`   | промежуток графика, с |
| `interval`  | int  | `1000` | частота обновления, мс |
