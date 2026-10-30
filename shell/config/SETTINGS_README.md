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
| `snow`       | `enabled`, `sweep`, `hideGroundWithTiled`, `windowDrifts` (bool), `intensity`, `speed`, `capRounding`, `shakeOff` (real), `driftHeight`, `windowDriftHeight` (int, лог. px) |

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
