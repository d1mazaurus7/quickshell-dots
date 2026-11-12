# noti-center/widgets

Виджеты сетки быстрых настроек центра уведомлений. Сетка — 4 колонки, высота строки `notiCenter.widgetHeight · s` (по умолчанию 56).
Раскладка (порядок и размеры) хранится в `Config.options.notiCenter.layout`
и меняется редактором (`EDITOR_README.md`).

## Как добавить виджет

1. Создать `widgets/MyWidget.qml`. Корень заполняет ячейку целиком (размер задаёт сетка),
   обязательно `required property var ctx`:

   ```qml
   import QtQuick
   import "../controls"
   import "../controls/Icons.js" as Icons

   SplitTile {
       required property var ctx

       s: ctx.s
       icon: Icons.bell
       title: "Мой виджет"
       active: false
       onToggled: ctx.play("click")
   }
   ```

2. Добавить запись в `widgets/Registry.js` → `widgets`:

   ```js
   { type: "my", title: "Мой виджет", icon: Icons.bell, source: "MyWidget.qml",
     w: 2, h: 1, minW: 1, maxW: 4, minH: 1, maxH: 2 },
   ```

   - `type` — уникальный ключ (сохраняется в конфиг, не переименовывать).
   - `w`, `h` — размер при добавлении, в ячейках; `minW..maxW`, `minH..maxH` — пределы
     редактора. Равные min и max — ручка этого края не показывается.
   - Новый глиф — в `controls/Icons.js` (код MDI `\u{f0xxx}`, проверить наличие в шрифте:
     `fc-list ":charset=f0xxx" family | grep JetBrainsMono`).

3. По желанию — добавить в `defaults` (раскладка до первого редактирования).

Больше ничего не нужно: виджет появится в лотке «Добавить» редактора.

## Контекст `ctx`

`ctx` — экземпляр `NotiCenter.qml`. Доступно:

| Свойство / функция | Что это |
|---|---|
| `s` | масштаб размеров (`notiCenter.scale`, от ширины не зависит) |
| `cfg` | `Config.options.notiCenter` |
| `now` | текущее время (`SystemClock`, секунды) |
| `play(name)` | звук интерфейса из `assets/sounds` (учитывает `uiSounds`) |
| `page` | открыть внутреннюю страницу: `"wifi"`, `"bluetooth"`, `"recorder"`, `"screenshot"` |
| `open`, `shown` | центр открыт / виден (`shown` — с учётом анимации закрытия) |
| `openOutputRequested("")` | закрыть центр |
| `runHidden(fn)` | закрыть центр и вызвать `fn` после его скрытия (захват экрана без панели) |
| `recorderService` | сервис записи экрана (`services/recorder/Recorder.qml`) |
| `screenshotService` | сервис скриншотов (`services/screenshot/Screenshot.qml`, `capture()`) |
| `notifications` | `NotificationState` (`dnd`, `history`, …) |
| `sink` | `PwNode` устройства вывода (уже отслеживается) |
| `wifiDevice`, `wifiNetwork`, `wiredDevice` | Networking |
| `btAdapter`, `btDevice` | Bluetooth |
| `brightness`, `brightnessAvailable`, `setBrightness(v)` | яркость (ddcutil) |

Собственное системное состояние виджет держит сам (пример — `MicSlider.qml`
с `Pipewire.defaultAudioSource` и `PwObjectTracker`). Общее для нескольких виджетов —
в `NotiCenter.qml`.

## Правила

- Визуал — из `../controls`; новый переиспользуемый элемент сначала добавить туда.
- Виджет должен выглядеть корректно на всех размерах из `min*..max*`
  (ориентир — `width`/`height`, как `SplitTile.compact`).
- В режиме редактора сетка отключает мышь у виджета сама — обрабатывать не нужно.
- Обводка редактора идёт на одинаковом расстоянии от виджета. Если видимая форма
  меньше ячейки или скруглена иначе, чем `min(height·0.32, 24·s)`, объявить в корне:
  `readonly property real editInsetV` (отступ сверху и снизу) и
  `readonly property real editRadius` (скругление). Пример — `controls/SliderTile.qml`.
- Без таймеров-поллинга: события сервисов Quickshell.

## Существующие виджеты

| type | Файл | Размеры |
|---|---|---|
| `volume` | `VolumeSlider.qml` | 2–4 × 1 |
| `mic` | `MicSlider.qml` | 2–4 × 1 |
| `brightness` | `BrightnessSlider.qml` | 2–4 × 1 |
| `wifi` | `WifiTile.qml` | 1–4 × 1–2 |
| `bluetooth` | `BluetoothTile.qml` | 1–4 × 1–2 |
| `dnd` | `DndTile.qml` | 1–4 × 1–2 |
| `recorder` | `RecordTile.qml` (запись экрана, меню — настройки) | 1–4 × 1–2 |
| `screenshot` | `ScreenshotTile.qml` (снимок области, меню — настройки) | 1–4 × 1–2 |
| `clock` | `ClockWidget.qml` | 2–4 × 1–2 |
| `media` | `MediaPlayer.qml` (MPRIS) | 3–4 × 3–4 |
