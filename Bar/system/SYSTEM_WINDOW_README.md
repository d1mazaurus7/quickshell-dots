# Окно «Система»

Оверлей с метриками CPU / GPU / RAM / Disk: плитки, графики истории, характеристики, датчики, процессы.

## Запуск

- IPC: `qs ipc call system toggle | open | close | tab <cpu|gpu|ram|disk>`.
  Открывается на мониторе в фокусе (`niri msg --json focused-output`).
- Бинд в niri (конфиг niri агент сам не меняет):
  `Mod+Shift+S { spawn "qs" "ipc" "call" "system" "toggle"; }`
- Клавиши в окне: `Esc` — закрыть, `1–4` — вкладка, `←/→`, `Tab/Shift+Tab` — соседняя вкладка.
  Клик по затемнению закрывает окно.

## Файлы

| Файл | Роль |
|---|---|
| `SystemState.qml` | Только данные: парсинг, история, `df`, `lsblk`, `ps`. Без визуала |
| `sysstat.sh` | Долгоживущий сборщик. Одна строка на метрику, тик заканчивается строкой `E` |
| `SystemWindow.qml` | `PanelWindow` в слое Overlay, IPC, шапка, лента вкладок, анимация открытия |
| `SysPage.qml` | Каркас вкладки: ряд из 4 `SysTile`, `SysGraph`, две `SysCard` (`leftPane` / `rightPane`) |
| `CpuPage` / `GpuPage` / `RamPage` / `DiskPage` | Содержимое вкладок |
| `SysTile.qml` | Круг (`WavyRing` + `LiquidFill` из `widgets/sysmon`) и подробности справа |
| `SysGraph.qml` | Canvas-график, чипы серий, подсказка при наведении |
| `SysText.qml` | Текст: числа плавно перетекают, не влезающая строка прокручивается по X |
| `SysIcon.qml` | Значок Material Symbols: контур и заливка сменяются прозрачностью |
| `SysTabs` / `SysChip` / `SysBar` / `SysInfo` / `SysCard` | Сегменты, filter chip, строка с полосой, список «параметр: значение», карточка |
| `settings/pages/SystemPage.qml` | Страница настроек |

Подключение — `shell/Shell.qml`: `SystemState` (`active`, `detailed`, `interval`) и `SystemWindow { sys: systemState }`.

## Настройки — `Config.options.system`

Ключи: `width`, `height` (лог. px), `interval` (мс опроса), `range` (с: 60/300/900/1800/3600),
`backgroundHistory`, `shapes`, `scrim`, `smoothGraphs`, `graphTooltip`, `tab`.
`tab` записывается только при закрытии окна, а не на каждое переключение
(частые записи конфликтуют с перечитыванием `settings.json`).

## Данные

- `sysstat.sh <ms>` сначала печатает статичные `I <ключ> <значение>` и `IE`.
  Потом на каждый тик: `S` (/proc/stat), `F` (частоты), `M` (meminfo), `L` (loadavg + uptime),
  `T` (hwmon: `cpu_*`, `gpu_*`, `ramN`, `nvmeN`, `wifi`), `G` (amdgpu), `D` (diskstats), `E`.
- В цикле только builtins: `read`, `rd()` через `REPLY`, пауза — `read -t` из `<(:)`.
  Не добавляй `$(...)`, `cat`, `sleep` — это fork на каждый тик.
- История — `sys.history[key]`, обычные массивы на час (`capacity`), `sys.count` — номер последнего отсчёта.
  Массивы меняются на месте, поэтому привязки должны читать `sys.count` (пример — `SysPage.window_()`)
  или слушать сигнал `sampled()`.
- Ключи истории: `cpu cpuUser cpuSys cpuIo cpuTemp cpuFreq gpu gpuEdge gpuHot gpuMemT vram gpuPower
  ram cache swap ramTemp diskR diskW diskTemp`.
- Смена `interval` сбрасывает историю и перезапускает сборщик.
- `detailed` (окно видно) — `df` и `lsblk` раз в 30 с. `procs` (видна вкладка RAM) — `ps` раз в 3 с.
  Оболочка = процесс `quickshell` и все его потомки по ppid. Остальное группируется по имени,
  `.x-wrapped` из NixOS обрезается.
- GPU читается только через amdgpu sysfs. NVIDIA / Intel не поддерживаются, поля останутся пустыми.
  Имени GPU нет (нет `lspci` / `pci.ids`), показывается PCI ID.

## Оптимизация

- Сборщик работает, пока `active` = окно видно ИЛИ `backgroundHistory`.
- Вкладки создаются заранее (`Loader { asynchronous: true }`), чтобы открытие не тормозило.
  При скрытом окне `visible: false`: анимации колец, графики и бегущие строки стоят.
- Видна только текущая вкладка (и соседняя во время сдвига). График перерисовывается раз на отсчёт,
  а между отсчётами сдвигается анимацией `x` холста, без перерисовки. Отсчёты собираются в корзины
  по абсолютному номеру (не больше точки на 3 px).
- Монитор 180 Гц. На время сдвига вкладок (`SysPage.sliding`) страница едет готовой текстурой (`layer.enabled`),
  а волны колец стоят (`SysTile.animate` → `WavyRing.animate`). Покадровый пересчёт точек `WavyRing`/`LiquidFill`
  и перетриангуляция Shape (CurveRenderer) — самое дорогое в окне. Новые покадровые анимации тоже глуши через `sliding`.
- Значения, которые часто меняются, идут в Repeater через `model: rows.length` и `rows[index]`,
  чтобы делегаты не пересоздавались каждый тик.

## Подводные камни (уже наступали)

- Свойства с именами `left`, `right`, `top`, `smooth` конфликтуют с FINAL-свойствами Item
  («Cannot override FINAL property»). Отсюда `segL/segR`, `leftPane/rightPane`, `topRss`, `smoothLines`.
- Слоты карточек задаются как `leftPane.content: Item { anchors.fill: parent }`.
  Внутри RowLayout дочерний `Layout.fillHeight` распространяется на сам layout,
  поэтому нижнему ряду явно стоит `Layout.fillHeight: false` и `maximumHeight`.
- Промежуточные значения оси `FILL` у Material Symbols дают дыры в глифах. Не анимируй `font.variableAxes`,
  используй `SysIcon` (два слоя 0/1).
- Текст внутри `ClippingRectangle` (текстура) и на дробных координатах выглядит мыльным.
  Текст кладётся поверх клипа, а позиции округляются (`Math.round`), как в `SysTile` и `SysText`.
- Бегущая строка в `SysText` анимирует долю `k`, а расстояние берётся на лету.
  Если зашить `to` в анимацию, при старте с нулевой шириной текст уезжает за край.
- Анимации на значениях из `Behavior` с `targetValue` (индикатор `SysTabs`) — не присваивай им значения
  императивно, иначе ломается начальная позиция.
- Inline `component` внутри не-корневого контекста здесь не взлетел («is not a type»). Используй Repeater или отдельный файл.
- `clip: true` режет прямоугольно, и у скруглённых блоков вылезают углы. Заливку делай как в ячейках потоков
  (`CpuPage`): Item с `clip` по высоте уровня, внутри Rectangle на всю ячейку с тем же `radius`.
  `ClippingRectangle` не подходит для текста (мылит).
- Вращения по hover пользователь просил убрать. Не возвращай.

## Стиль

Цвета — только `Tokens.colors` (matugen), размеры — `Tokens.scaled` / `Tokens.radius`, длительности — `Tokens.animation*`.
Кривые M3: emphasized decelerate `[0.05, 0.7, 0.1, 1]` — вход, emphasized accelerate `[0.3, 0, 0.8, 0.15]` — выход,
`[0.2, 0, 0, 1]` — сдвиг вкладок. Фон окна — `M3ShapeField` из `settings/controls`.

## Проверка

- Ошибки после правки: `qs log | grep -A6 Reloading` (оболочка перезагружается сама; при ошибке остаётся старая версия).
- Визуально: `qs ipc call system tab gpu` и `grim -o <output> shot.png`.
  Снимок делай через 2–3 с после команды: раньше попадёт середина анимации.
- Сборщик отдельно: `timeout 3 bash Bar/system/sysstat.sh 1000`.
