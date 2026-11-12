# noti-center/controls

Переиспользуемые компоненты центра уведомлений в стиле Material You (MD3 expressive).
Цвета — только `theme/Palette.qml` (matugen), длительности — `shell/theme/Tokens.qml`.

Подключение из файла в `noti-center/`: `import "controls"`, из `noti-center/widgets/`: `import "../controls"`.
Иконки: `import "controls/Icons.js" as Icons` (глифы MDI из JetBrainsMono Nerd Font).
Шрифт текста — `Tokens.typography.family` (настройка «Шрифт» оболочки); Nerd Font — только для глифов (`Icon`).

Все размерные компоненты принимают `required property real s` — масштаб центра (`ctx.s`).
Внутри размеры задаются как `N * s`.

## Анимации

| Файл | Что это | Использование |
|---|---|---|
| `Smooth.qml` | NumberAnimation, `Tokens.animationMedium`, OutCubic | `Behavior on x { Smooth {} }`, `Smooth { duration: 120 }` |
| `SmoothColor.qml` | ColorAnimation, `Tokens.animationFast` | `Behavior on color { SmoothColor {} }` |
| `Emphasized.qml` | OutBack с лёгким перелётом, `Tokens.animationSlow` | морфинг формы, перестановка виджетов |

## Компоненты

| Файл | Назначение | Основные свойства / сигналы |
|---|---|---|
| `Icon.qml` | Глиф-иконка, центрируется по границам глифа (`TextMetrics`). Смена `text` анимируется (уход с поворотом → приход с перелётом); `slashed` — анимированное перечёркивание | `text`, `size`, `color`, `slashed`, `slashGap` (цвет фона под чертой); `slide(dir)` — уход глифа в сторону и возврат с другой |
| `StateLayer.qml` | Слой hover 8% / pressed 12% | `hovered`, `pressed`, `color`, радиусы как у Rectangle |
| `IconButton.qml` | Кнопка-иконка; углы сжимаются при нажатии | `icon`, `slashed`, `slideOnClick` (сдвиг иконки при нажатии: 1/-1), `checked`, `round` (круг ↔ квадрат при checked), `interactive`, `color`, `contentColor`; `clicked()` |
| `SplitTile.qml` | Плитка из двух сегментов: вкл/выкл + меню | `icon`, `slashed`, `title`, `subtitle`, `active`, `expandable`, `menuSlideOnClick` (сдвиг иконки меню при нажатии: 1/-1); `toggled()`, `expand()` (кнопка меню или ПКМ). Уже 120·s — только иконка; `subtitle` виден только у плитки высотой ≥ 96·s |
| `M3Slider.qml` | Ползунок: дорожки, узкая ручка, точка-упор | `value` 0..1, `available`, `trackHeight`, `activeColor`, `inactiveColor`; `moved(v)`, `scrolled()` |
| `SliderTile.qml` | `IconButton` + `M3Slider` | `icon`, `slashed`, `checked` (приглушает дорожку), `buttonInteractive`, `value`, `available`; `moved(v)`, `toggled()`, `scrolled()` |
| `WavyProgress.qml` | Волновой прогресс MD3E: волна бежит при `playing`, при паузе выпрямляется; путь строится раз на ширину, анимируется только сдвиг | `value`, `playing`, `interactive`, `amplitude`, `wavelength`, `activeColor`, `inactiveColor`; `seek(v)` на отпускании, `pressed`, `dragValue` |
| `Segmented.qml` | Группа соединённых кнопок MD3E, одиночный выбор: выбранная — пилюля, нажатая расширяется и сжимает углы, иконка подпрыгивает | `options` `[{ value, label, icon? }]`, `current`; `picked(value)` |
| `ToggleButton.qml` | Кнопка-переключатель MD3E с подписью: пилюля ↔ скруглённый прямоугольник, выключенная иконка перечёркнута, при нажатии иконка отскакивает | `icon`, `label`, `checked`, `slashOff`; `clicked()` |
| `PageSection.qml` | Раздел внутренней страницы: подпись + содержимое на всю ширину | `title` |
| `Chip.qml` | Ассист-чип с «+» | `icon`, `text`; `clicked()` |
| `Marquee.qml` | Текст, прокручивающийся при переполнении | `text`, `color`, `pixelSize`, `family` (по умолчанию шрифт оболочки), `weight` |
| `ResizeHandle.qml` | Ручка масштабирования, видна только при наведении | `cursor`, `dot`, `vertical`; `moved(area, mouse)`, `released()` |
| `WidgetGrid.qml` | Сетка виджетов и редактор | см. `../widgets/EDITOR_README.md` |

## Правила

- Состояние «выключено» — базовая иконка + `slashed: true`, а не отдельный глиф `-off`:
  так перечёркивание анимируется. Разные состояния одной кнопки — смена `icon`
  (анимируется сама).

- Новые цвета — только из `Theme.Palette`, без хардкода.
- Интерактивный элемент = фон + `StateLayer` + `MouseArea` (`hoverEnabled`, `cursorShape`).
- Анимировать только то, что меняется; `Behavior` на постоянно меняющихся при перетаскивании
  значениях отключать (`enabled: !area.pressed`).
- Компоненты не знают о системных сервисах: состояние приходит свойствами, действия уходят сигналами.
