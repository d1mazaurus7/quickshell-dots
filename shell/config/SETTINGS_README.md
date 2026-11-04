# Настройки оболочки: инструкция по интеграции (для агентов)

## Как устроено

- Файл настроек: `~/.config/quickshell/settings.json` (`Quickshell.shellPath("settings.json")`).
- Singleton `Config` (`shell/config/Config.qml`) — единственная точка чтения и записи настроек.
  - `FileView` + `JsonAdapter` (Quickshell.Io).
  - Нет файла → создаётся с дефолтами.
  - Файл изменён извне → перечитывается (`watchChanges` + `reload()`).
  - Свойство изменено из оболочки → файл перезаписывается (`adapterUpdated` → `writeAdapter()`).
- Доступ: `Config.options.<секция>.<ключ>`. Флаг `Config.ready` — файл загружен или создан.
- `Tokens` (`shell/theme/Tokens.qml`) берёт из `Config` отступы, скругления, шрифты
  и длительности анимаций. Цвета — только из `Palette` (matugen), в `Config` их нет.

Текущая схема (`version: 2`):

| Секция       | Ключи                                                  |
|--------------|--------------------------------------------------------|
| `appearance` | `scale`, `spacingHorizontal`, `spacingVertical`, `radiusScale`, `animationScale` (real), `borders` (bool) |
| `typography` | `family` (string), `size` (int, базовый px)            |
| `snow`       | `enabled`, `sweep`, `hideGroundWithTiled`, `windowDrifts`, `infiniteDrifts`, `wind` (bool), `intensity`, `speed`, `capRounding`, `shakeOff` (real), `sweepLifetime` (real, с), `sweepAmount` (real, множитель комьев расчистки), `bounceAmount` (real, 0..1 — доля отскока, > 1 — брызги), `windStrength` (real, -3..3, < 0 — влево), `driftHeight`, `windowDriftHeight` (int, лог. px) |
| `bar`        | `left`, `center`, `right` (list<string>, id модулей из `shell/bar/BarModules.qml` по порядку; модуля нет ни в одном блоке — он скрыт). Менять только присваиванием нового массива; `style` (string: `attached` / `full` / `floating` / `modular`), `floatingMarginTop`, `floatingMarginSide` (int, лог. px), `autoHide` (bool), `autoHideDelay` (int, мс) |
| `time`       | `showSeconds`, `showDate`, `showWeekday`, `shortWeekday` (bool) |
| `stopwatch`  | `side` (string: `right` / `left`), `barWidget`, `blinkIcon` (bool), `icon` (string) |
| `musicPlayer` | `cava`, `coverBackground`, `backgroundBlur`, `wavyTimeline`, `showArtist`, `equalizer` (bool), `timelineStyle` (string: `wave` / `material`), `danceGif` (string, имя файла из `assets/gifs/dance`, `""` — нет), `danceGifEnabled`, `lyrics`, `lyricsScroll`, `lyricsSeek` (bool), `lyricsFontSize` (int, px), `lyricsAlign` (string: `left` / `center` / `right`) |
| `workspaces` | `showNumbers`, `hideEmpty` (bool), `style` (string: `circles` / `squares`) |
| `notiCenter` | `popupSide` (string: `right` / `left`), `sound` (bool, заглушка), `swipe` (bool), `swipeDirection` (string: `both` / `right` / `left`), `width`, `bodyLines` (int), `heightRatio` (real 0.4..1), `showClock`, `showSeconds`, `showDate`, `showWeekday`, `showWifi`, `showBluetooth`, `showDnd`, `showBrightness`, `showVolume`, `showActions`, `uiSounds`, `showCalendar` (bool), `calendarArrows` (string: `right` / `left`), `reminders`, `remindersIgnoreDnd`, `reminderRequireStop` (bool), `reminderInterval` (int, с), `reminderSound` (string, имя файла из `assets/sounds/notes`, `""` — нет) |
| `sound`      | `interactionSounds` (bool, общий выключатель звуков печати/клика/громкости), `typeSound`, `clickSound`, `notificationSound`, `osdSound` (string, имя файла из `assets/sounds`), `mixer`, `mixerOutputs`, `mixerInputs`, `mixerRestart` (bool) |
| `screenshot` | `notify`, `editTools`, `instant`, `sound` (bool), `soundFile` (string, имя файла из `assets/sounds/screenshot`) |
| `powerMenu`  | `holdTime` (int, мс), `showPoweroff`, `showReboot`, `showSleep`, `showExit`, `labels` (bool), `width`, `height` (int, лог. px) |
| `launcher`   | `position` (string: `top` / `bottom` / `left` / `right`), `showIcons`, `showDescriptions`, `letterIcons` (bool), `pinnedApps`, `hiddenApps` (list<string>, id desktop-файлов; менять присваиванием), `tags` (var: `[{ name, apps }]`, теги для поиска `#тег`; менять присваиванием), `showTagButtons` (bool), `commandShell`, `commandEmoji`, `commandWeb` (bool) |
| `assistant`  | `name`, `description`, `systemPrompt`, `apiKey`, `model` (string), `avatar` (string, имя файла из `assets/img/avatars`, `""` — нет), `temperature` (real), `maxTokens` (int), `side` (string: `left` / `right`), `width`, `fontSize` (int), `heightRatio` (real 0.4..1), `clearCommand`, `reloadCommand`, `loadCommand` (string) |
| `wallpaper`  | `password` (string, пароль секретных обоев, `""` — вход закрыт) |
| `widgets`    | `items` (var: `[{ uid, type, screen, x, y, width, height, settings }]`, экземпляры виджетов рабочего стола; пишет только редактор виджетов, см. `widgets/WIDGETS_README.md`), `grid` (bool), `gridSize` (int, лог. px) |
| `security`   | `hidePopups` (bool), `protectedApps` (list<string>, id desktop-файлов; менять присваиванием). Пишутся в `~/.config/niri/config/layer-rules.kdl` (`services/niri/NiriScreencastGuard.qml`) |

## Правила

1. **Не читай `settings.json` напрямую** (свой FileView, Process `cat`, JSON.parse) — только `Config`.
2. **Общие визуальные величины — через `Tokens`**, а не `Config.options.appearance` напрямую:
   `Tokens.spacingMedium`, `Tokens.radiusLarge`, `Tokens.fontMedium`, `Tokens.animationFast`.
   Нестандартное скругление — `Tokens.radius(<px>)`, обводка — `border.width: Tokens.borderWidth`.
   Отступы: `Tokens.spacing*` — по горизонтали, `Tokens.spacing*V` — по вертикали.
   Фиксированный размер — `Tokens.scaled(<px>)` (учитывает `appearance.scale`).
3. **Параметры конкретного модуля** — в собственной секции `Config.options.<module>`.
4. **Дефолт задаётся только в `Config.qml`** — в значении свойства адаптера.
   Не дублируй дефолт в модуле (`?? 56`, `|| "Sans"`): отсутствующий ключ и так получит дефолт.
5. **Используй привязки**, а не однократное копирование значения в `Component.onCompleted` —
   иначе модуль не отреагирует на изменение настроек.
6. **Добавляй ключи только под реальную потребность** модуля, не «на будущее».
7. Цвета, темы, палитры в `Config` не добавлять (см. AGENTS.md → Visual).

## Импорт

Путь относительный от файла модуля до `shell/config`:

```qml
import "../../shell/config"   // из modules/<name>/X.qml
import "../shell/config"      // из Bar/X.qml
import "config"               // из shell/X.qml
import "../config"            // из shell/theme/X.qml
```

`Tokens` аналогично: `import "../../shell/theme"` (singleton `Tokens`).

## Чтение в модуле

```qml
import QtQuick
import "../../shell/config"
import "../../shell/theme"

Item {
    // Сокращение для секции модуля
    readonly property var cfg: Config.options.clock

    implicitHeight: Tokens.spacingLarge * 2

    Text {
        text: Qt.formatDateTime(clock.date, cfg.format)
        font: Tokens.fontMedium
    }

    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
}
```

## Добавление новой секции

В `shell/config/Config.qml`, внутри `JsonAdapter { id: adapter }`:

```qml
property JsonObject clock: JsonObject {
    property string format: "hh:mm"
    property bool showSeconds: false
}
```

- Имя секции = имя модуля в camelCase (`clock`, `workspaces`, `musicPlayer`, `notiCenter`).
- Типы: `bool`, `int`, `real`, `string`, `list<string>` / `var` для массивов,
  вложенный `JsonObject` для подгрупп.
- Добавление ключа с дефолтом совместимо со старым файлом — `version` не меняется.
- Переименование/удаление ключа или смена смысла значения → увеличить `version`
  и добавить миграцию в `Config.qml` (сейчас миграций нет).

## Запись из UI (окно настроек)

```qml
onToggled: Config.options.clock.showSeconds = checked
```

- Каждое присваивание пишет файл. Для слайдеров/частых изменений пиши
  по `onPressedChanged`/`onEditingFinished` или через `Timer`-debounce, а не на каждое движение.
- Массивы и объекты **переприсваивай целиком**; мутация на месте (`push`, `splice`,
  `arr[i] = …`) не генерирует сигнал изменения и не сохранится:
  ```qml
  const l = Config.options.modules.left.slice();
  l.splice(i, 1);
  Config.options.modules.left = l;
  ```
- Модули сами в настройки не пишут — запись только из окна настроек.

## Чек-лист перевода существующего файла

1. Прочитать файл, найти захардкоженные размеры, шрифты, длительности, параметры поведения.
2. Общие величины заменить на `Tokens.*`. Если подходящего токена нет — обсудить
   добавление в `Tokens` (с базой и scale из `Config`), а не вводить ключ в модуль.
3. Специфичные параметры вынести в секцию модуля в `Config.qml` с текущими значениями
   как дефолтами — внешний вид после перевода не должен измениться.
4. Заменить литералы на привязки к `Config.options.<module>.*`.
5. Обновить таблицу схемы в этом файле.
6. Проверить `qmllint` (см. ниже) и, по согласованию, запуском.

## Проверка

```sh
Q=$(dirname $(dirname $(readlink -f $(which quickshell))))/lib/qt-6/qml
qmllint -I "$Q" -I <qtdeclarative>/lib/qt-6/qml <файлы>
```

Предупреждение «Type ... not declared as singleton in qmldir» при линте singleton-файла
напрямую — ложное, `qmldir` их объявляет.

Ручная проверка: удалить `settings.json` → перезапустить оболочку → файл создан;
изменить значение в файле → оболочка подхватила без перезапуска; битый JSON → оболочка
не падает.
