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
| `lockItems` | var | экземпляры лок-скрина, формат как у `items`; пишет только `WidgetsState { lockSet: true }` |
| `lockDefaultsAdded` | bool | набор лок-скрина по умолчанию уже добавлен (`WidgetsState.seedLock`) |

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
| `blurFree`  | bool | `false` | фон карточки прозрачный с размытием, цветом только занятое |
| `showUsed`  | bool | `true` | занятое количество |
| `showFree`  | bool | `true` | свободное количество |
| `graphTab`  | bool | `true` | вкладка графика |
| `graphSpan` | int  | `60`   | промежуток графика, с |
| `interval`  | int  | `1000` | частота обновления, мс |

## Визуализатор (`cavaVisualizer`)

Края тянутся мышью в редакторе (`resizable`), отражение — кнопками над рамкой (`flippable`).

| Ключ    | Тип    | Дефолт   | Смысл |
|---------|--------|----------|-------|
| `background`   | bool | `true`  | фон карточки; выкл — карточка полностью прозрачная, без размытия |
| `blur`  | bool   | `true`   | при включённом фоне: карточка прозрачная с размытием; выкл — фон `surface_container` |
| `behindBlur`   | bool | `false` | без фона: размытие под самими волнами/палочками (Region по форме спектра) |
| `colorless` | bool | `false`  | при `behindBlur`: фигуры не закрашены, видно только размытие |
| `glow`  | bool   | `false`  | свечение вокруг волн/палочек, независимо от фона |
| `style` | string | `"wave"` | `wave` — соединённая волна, `bars` — палочки |
| `barCount` | int | `24`     | количество палочек (`bars`), уровни cava интерполируются |
| `flipH` | bool   | `false`  | отражение по горизонтали |
| `flipV` | bool   | `false`  | отражение по вертикали |
| `lower` | bool   | `false`  | под другими виджетами: окно создаётся раньше остальных (`WidgetsState.windowKeys`) |

## Часы (`clock`)

Края тянутся мышью в редакторе (`resizable`), шрифт подгоняется под окно.

| Ключ             | Тип    | Дефолт     | Смысл |
|------------------|--------|------------|-------|
| `layout`         | string | `"full"`   | `full` — «11:25», `vertical` — часы и минуты столбцом |
| `align`          | string | `"center"` | `left` / `center` / `right` |
| `showSeconds`    | bool   | `false`    | секунды |
| `blinkSeparator` | bool   | `false`    | при секундах: «:» плавно мигает |
| `textBlur`       | bool   | `false`    | «стеклянный» текст: полупрозрачный, размытие по форме символов (маски из Canvas, Region-полосы); только без `background` |
| `whiteText`      | bool   | `false`    | белый текст вместо `primary` |
| `background`     | bool   | `false`    | фон карточки `surface_container` |
| `backgroundBlur` | bool   | `false`    | при фоне: карточка прозрачная с размытием (важнее `textBlur`) |

## Таймер (`timer`)

Время выбирается барабанами (`TimerDrum`, по образцу `modules/noti-center/TimeDrum.qml`),
по истечении играет первый звук из `assets/sounds/timer/` (`pw-play`). Края тянутся мышью.

| Ключ                    | Тип  | Дефолт  | Смысл |
|-------------------------|------|---------|-------|
| `transparentBackground` | bool | `false` | фон карточки, барабанов и кнопок прозрачный, видны только текст и значки |
| `outline`               | bool | `true`  | при прозрачном фоне: мягкая белая обводка кнопок и барабанов |
| `backgroundBlur`        | bool | `false` | при прозрачном фоне: размытие под всей карточкой (`blurItem`), затемнение `surface_container` 25% как у `sysmon` |
| `whiteText`             | bool | `false` | белые цифры отсчёта и выбранные числа барабанов вместо `primary` |
| `smoothChange`          | bool | `true`  | цифры сменяются slide: вниз при отсчёте, вверх при «заново» |
| `blinkSeparator`        | bool | `false` | «:» плавно мигает во время отсчёта |
| `showSeconds`           | bool | `true`  | секунды; выкл — «ЧЧ:ММ» с округлением вверх |
| `showMilliseconds`      | bool | `false` | при секундах: сотые после точки, без slide |

## Медиа (`media`)

Фото, gif/webp (`AnimatedImage`) или видео (`QtMultimedia`, без звука, по кругу) из любого файла.
Края тянутся мышью. `rect` и `circle` — `ClippingRectangle`, остальные шаблоны — маска `MultiEffect`
по `Shape` (путь из `MediaShapes.js`) на всё окно; `circle` в неквадратном окне — эллипс (маска).

Видео и gif на паузе, пока окно niri в фокусе (`services.focus`, только набор рабочего стола).
ПКМ по видео — таймлайн (`Music.WaveSlider`) с паузой; кнопка воспроизведения переопределяет паузу
по фокусу до следующей смены фокуса.

| Ключ     | Тип    | Дефолт   | Смысл |
|----------|--------|----------|-------|
| `source` | string | `""`     | абсолютный путь к файлу |
| `shape`  | string | `"rect"` | `rect` / `circle` / `cookie` (Material You) / `flower` / `clover` / `burst` / `star` / `triangle` / `diamond` / `pentagon` / `hexagon` |
| `radius` | real   | `0.15`   | закругление 0–1: у `rect` доля половины меньшей стороны, у многоугольников — сглаживание углов |

## Пользователь (`lockUser`, только лок-скрин)

| Ключ        | Тип    | Дефолт     | Смысл |
|-------------|--------|------------|-------|
| `photo`     | string | `""`       | имя файла из `assets/photos`; `""` — первый файл папки |
| `shape`     | string | `"circle"` | `circle` / `rounded` |
| `showName`  | bool   | `true`     | имя пользователя (`$USER`) под фото |
| `whiteText` | bool   | `false`    | белое имя вместо `on_surface` |

## Поле пароля (`lockPassword`, только лок-скрин, single)

Настроек нет. Нет экземпляра (или виджеты лок-скрина выключены) — при вводе по центру появляется то же поле.
