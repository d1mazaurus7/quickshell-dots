# Размытие под окнами Shell

Окно Shell просит у niri размытие своей области по протоколу `ext-background-effect-v1`
(`BackgroundEffect.blurRegion` из `Quickshell.Wayland`). niri размывает то, что реально под
окном, а не только обои, благодаря правилу в `~/.config/niri/config/layer-rules.kdl`
(подключён в `config.kdl`; не в `layout.kdl` — его перезаписывает matugen):

```kdl
layer-rule {
    match namespace="^qs:"
    background-effect {
        xray false
    }
}
```

## Общие части

| Что | Где |
|-----|-----|
| `Tokens.surfaceOpacity` — непрозрачность фона окон с размытием | `shell/theme/Tokens.qml` ← `appearance.surfaceOpacity` |
| `Tokens.blurEnabled` — запрашивать ли размытие (`appearance.blur > 0`) | `shell/theme/Tokens.qml` |
| Сила размытия (общая для niri) → `~/.config/niri/config/blur.kdl` | `services/niri/NiriBlur.qml` |
| Окно бара и сбор регионов | `shell/Shell.qml` (`barBlurRegion`) |
| Подложки модулей в стиле `modular` | `shell/bar/BarSection.qml` |

Настройки — «Интерфейс → Прозрачность / Блюр».

## Как работает Region (проверено по исходникам Quickshell, `src/core/region.cpp`)

- `item` переводится в **координаты окна** (`mapToScene`). У вложенных регионов координаты
  тоже оконные, а не относительно родителя.
- Регион пересчитывается **только** при изменении `x`, `y`, `width`, `height` самого `item`.
  Он не замечает сдвиг предков, `scale`, `visible` и `opacity`.
- Скрытый `item` (`visible: false`) по-прежнему размывается — регион надо обнулять самому.
- Вложенные `Region` объединяются (`Intersection.Combine` по умолчанию). `regions` можно
  привязать к JS-массиву регионов.
- Ручной пересчёт — `region.changed()`. Достаточно вызвать его у корневого региона окна:
  при сборке все вложенные регионы заново берут текущие координаты.

## Перевод модуля бара

1. В корневом элементе модуля добавить:
   ```qml
   // Подложка модуля полупрозрачная, под ней размытие (BLUR_README.md)
   readonly property bool blurBehind: true
   ```
   `BarSection` сам сделает подложку модуля полупрозрачной и добавит её в регион размытия бара
   (это работает в стиле `modular`; в сплошных стилях размывается весь фон бара).
2. Свои непрозрачные фоны внутри модуля заменить на
   `Qt.alpha(<цвет из палитры>, Tokens.surfaceOpacity)` или убрать.
3. Если у модуля есть своё окно (выпадающее, плеер и т.п.) — перевести его как окно (ниже).

Переведено: `modules/time`, `components/animations/BarDropdown.qml` (все выпадающие окна на его основе),
`Bar/SetWallpaper.qml` (размывается всё, кроме превью обоев).

## Перевод окна

```qml
import Quickshell
import Quickshell.Wayland
import "../../shell/theme"     // путь к Tokens от файла окна

PanelWindow {
    color: "transparent"
    // Имя обязательно с префиксом qs: — иначе niri оставит xray (размоются обои)
    WlrLayershell.namespace: "qs:<имя>"

    // Размытие под фоном окна (BLUR_README.md)
    BackgroundEffect.blurRegion: Tokens.blurEnabled ? blurRegion : null
    Region {
        id: blurRegion
        item: background.visible ? background : null
        radius: background.radius          // или topLeftRadius/... по углам фона
    }

    Rectangle {
        id: background
        color: Qt.alpha(Theme.Palette.background, Tokens.surfaceOpacity)
        radius: Tokens.radiusLarge
    }
}
```

- `color` окна должен быть `"transparent"` с самого создания: окно, созданное непрозрачным,
  потом прозрачным не станет (или задать `surfaceFormat.opaque: false`).
- Несколько видимых поверхностей в одном окне — корневой `Region` без `item` и вложенные
  регионы на каждую поверхность: `regions: [a, b]`.
- Не переводить: `qs:snow`, `quickshell-screenshot`.

## Окна и модули с анимациями

Главное правило: **регион привязывается к элементу, который сам анимируется**, или после
каждого шага анимации вызывается `changed()`.

| Анимация | Что делать |
|----------|-----------|
| Двигается/растёт сам фон (`x`, `y`, `width`, `height` фона) | Ничего — регион следит сам |
| Двигается контейнер, а фон внутри него | `item:` — сам контейнер, если он совпадает с фоном; иначе `Connections { target: контейнер; function onYChanged() { region.changed(); } }` (так сделано для `barContent` и блоков бара в `Shell.qml`) |
| `scale` (появление «из точки») | `onScaleChanged: region.changed()` у анимируемого элемента — `mapToScene` учитывает масштаб, но сигнала нет |
| `opacity` (затухание) | Регион не тускнеет вместе с содержимым: размытый прямоугольник останется на месте, пока окно гаснет. Обнулять регион в начале закрытия: `item: root.shown ? background : null` (при открытии — сразу) |
| `visible: false` / `Loader` выгружен | `item: background.visible ? background : null` |
| Обрезка через `clip` у родителя (выезд из-за края) | Регион не обрезается `clip`-ом: привязать регион к обрезающему элементу или вычесть лишнее `Region { intersection: Intersection.Intersect ... }` |
| Меняются скругления (переход в панель без углов) | Привязать `radius`/`*Radius` региона к радиусам фона — пересчитается само |

Пересчёт дешёвый: Quickshell отправляет регион один раз за polish окна, не на каждый кадр.
Дороже — сам режим без xray в niri: он перерисовывает размытие при каждом изменении
содержимого под окном.

## Ограничения niri (26.04)

- Режим без xray экспериментальный: размытие пропадает во время анимаций открытия/закрытия
  окон и при перетаскивании тайлового окна.
- Сила размытия одна на весь niri (`blur { offset }`), отдельные окна её не задают.
- Подповерхности (subsurface) не размываются — только само окно и xdg-popup.

## Проверка

- `niri msg layers` — у окна должен быть namespace `qs:<имя>`.
- `qs log -t 30` — без ошибок после перезагрузки.
- Визуально: открыть браузер под окном → под ним размытый браузер, а не обои; проиграть
  анимации открытия/закрытия/автоскрытия — размытие идёт за фоном, без «хвостов».
