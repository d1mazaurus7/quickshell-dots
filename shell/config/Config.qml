pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Настройки оболочки: ~/.config/quickshell/settings.json.
// Значения по умолчанию задаются в свойствах адаптера —
// отсутствующие в файле ключи получают дефолт.
Singleton {
    id: root

    // Доступ к настройкам: Config.options.<секция>.<ключ>
    readonly property alias options: adapter
    // true после первой успешной загрузки (или создания) файла
    property bool ready: false

    // Изменения из оболочки собираются и пишутся одной записью
    Timer {
        id: saveTimer
        interval: 100
        onTriggered: {
            file.lastWrite = Date.now();
            file.writeAdapter();
        }
    }

    FileView {
        id: file
        // Момент последней своей записи: её же событие изменения не перечитываем,
        // иначе запоздавшее чтение старого файла откатывает свежие изменения
        property double lastWrite: 0

        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        // Правка файла извне — перечитываем
        onFileChanged: {
            console.log("NCDBG fileChanged sinceWrite", Date.now() - lastWrite, "timer", saveTimer.running, "w", adapter.notiCenter.width);
            if (Date.now() - lastWrite > 500 && !saveTimer.running)
                reload();
        }
        // Изменение свойства из оболочки — сохраняем в файл
        onAdapterUpdated: { console.log("NCDBG adapterUpdated w", adapter.notiCenter.width); saveTimer.restart(); }
        onSaved: { console.log("NCDBG saved w", adapter.notiCenter.width); lastWrite = Date.now(); }
        onLoaded: { console.log("NCDBG loaded w", adapter.notiCenter.width); root.ready = true; }
        onLoadFailed: error => {
            // Первый запуск: создаём файл с дефолтами
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.ready = true;
        }

        JsonAdapter {
            id: adapter

            // Версия схемы для будущих миграций
            property int version: 2

            property JsonObject appearance: JsonObject {
                // Общий масштаб размеров интерфейса
                property real scale: 1.0
                // Масштаб отступов по горизонтали и вертикали
                property real spacingHorizontal: 1.0
                property real spacingVertical: 1.0
                property real radiusScale: 1.0
                property real animationScale: 1.0
                // Обводка вокруг панелей и полей
                property bool borders: true
                // Полупрозрачные карточки настроек с размытием фона под ними
                property bool cardBlur: false
                // Непрозрачность фона окон с размытием (0..1)
                property real surfaceOpacity: 0.6
                // Сила размытия под окнами (offset блока blur в niri); 0 — без размытия
                property real blur: 3
            }

            property JsonObject typography: JsonObject {
                property string family: "Sans Serif"
                // Базовый размер; small/large в Tokens — ±2px
                property int size: 12
            }

            property JsonObject snow: JsonObject {
                property bool enabled: false
                // Множитель числа снежинок и скорости накопления
                property real intensity: 1.0
                // Множитель скорости падения
                property real speed: 1.0
                // Максимальная высота сугроба, лог. px
                property int driftHeight: 60
                // Расчистка сугроба ЛКМ
                property bool sweep: true
                // Прятать нижний сугроб, если на экране только тайловые окна
                property bool hideGroundWithTiled: true
                // Снежные шапки на плавающих окнах
                property bool windowDrifts: true
                // Максимальная высота шапки, лог. px
                property int windowDriftHeight: 30
                // Скругление краёв шапки, 0..1
                property real capRounding: 0.6
                // Доля снега, стряхиваемая при перетаскивании окна, 0..1
                property real shakeOff: 0.7
                // Сугробы растут без потолка: до верха экрана
                property bool infiniteDrifts: false
                // Сколько лежит расчищенный и стряхнутый снег, с
                property real sweepLifetime: 2.0
                // Множитель числа комьев при расчистке
                property real sweepAmount: 1.0
                // Отскок быстрого снега: до 1 — доля отскакивающих снежинок,
                // сверх 1 — дополнительные брызги на каждый удар
                property real bounceAmount: 1.0
                // Ветер: снег идёт наискосок
                property bool wind: false
                // Сила и направление ветра: < 0 — влево, > 0 — вправо
                property real windStrength: 1.0
            }

            property JsonObject bar: JsonObject {
                // Модули в блоках бара по порядку: id из shell/bar/BarModules.qml.
                // Модуль, которого нет ни в одном блоке, скрыт
                property list<string> left: ["workspaces", "musicPlayer", "stopwatch", "volume"]
                property list<string> center: ["time"]
                property list<string> right: ["tray", "bluetooth"]
                // Стиль: "attached" — прилипает к верху | "full" — во всю ширину без скруглений |
                // "floating" — плавающий | "modular" — только подложки модулей
                property string style: "attached"
                // Отступы плавающего бара, лог. px
                property int floatingMarginTop: 8
                property int floatingMarginSide: 20
                // Прятать бар, пока курсор не над ним (место под бар остаётся)
                property bool autoHide: false
                // Через сколько бар прячется после ухода курсора, мс
                property int autoHideDelay: 300
            }

            property JsonObject time: JsonObject {
                property bool showSeconds: false
                property bool showDate: false
                property bool showWeekday: false
                // Сокращённое название дня: пн, вт, ...
                property bool shortWeekday: true
            }

            property JsonObject stopwatch: JsonObject {
                // Сторона экрана: "right" | "left"
                property string side: "right"
                // Кнопка в баре, пока секундомер запущен или на паузе
                property bool barWidget: true
                // Мигание значка в кнопке, пока секундомер идёт
                property bool blinkIcon: true
                // Значок в кнопке (любой символ/эмодзи, пусто — без значка)
                property string icon: "⏳"
            }

            property JsonObject musicPlayer: JsonObject {
                // Спектр cava вокруг обложки
                property bool cava: true
                // Обложка трека на фоне окна плеера
                property bool coverBackground: true
                property bool backgroundBlur: true
                // Бегущие волны на таймлайне; выкл — ровная полоса
                property bool wavyTimeline: true
                // Вид таймлайна: "wave" — залитые волны | "material" — одна волнистая линия
                property string timelineStyle: "wave"
                property bool showArtist: true
                // Полосы эквалайзера и пресеты
                property bool equalizer: true
                // Gif справа от эквалайзера: имя файла из assets/gifs/dance, "" — без gif
                property string danceGif: ""
                property bool danceGifEnabled: true
                // Вкладка «Текст» с текстом песни
                property bool lyrics: true
                // Размер строк текста, px до масштабирования
                property int lyricsFontSize: 19
                // Выравнивание строк: "left" | "center" | "right"
                property string lyricsAlign: "center"
                // Ручная прокрутка текста
                property bool lyricsScroll: true
                // Клик по строке — перемотка к ней
                property bool lyricsSeek: true
                // Текущая строка: белая и крупнее
                property bool lyricsHighlight: true
                // Буквы текущей строки прыгают волной
                property bool lyricsBounce: true
                // Свечение букв текущей строки
                property bool lyricsGlow: true
                // Цветная аура вокруг текущей строки
                property bool lyricsAura: true
                // Размытие всех строк, кроме текущей
                property bool lyricsBlur: false
            }

            property JsonObject workspaces: JsonObject {
                // Номер рабочего стола в каждой ячейке
                property bool showNumbers: false
                // Скрывать рабочие столы без окон
                property bool hideEmpty: true
                // Сколько ячеек показывать; недостающие добираются пустыми, активный всегда виден
                property int maxVisible: 8
                // Стиль ячеек: "circles" — круги, активный пилюля | "squares" — квадраты с закруглением
                property string style: "circles"
            }

            property JsonObject notiCenter: JsonObject {
                // Сторона экрана для всплывающих уведомлений: "right" | "left"
                property string popupSide: "right"
                // Звук нового уведомления (пока заглушка)
                property bool sound: true
                // Смахивание уведомлений мышью
                property bool swipe: true
                // Направление смахивания: "both" | "right" | "left"
                property string swipeDirection: "both"
                // Ширина панели центра, лог. px
                property int width: 460
                // Масштаб всех размеров содержимого центра
                property real scale: 1.15
                // Высота строки сетки виджетов до масштаба, лог. px
                property int widgetHeight: 56
                // Высота панели — доля доступной высоты экрана, 0.4..1
                property real heightRatio: 1.0
                // Виджеты центра: [{ type, w, h }] (modules/noti-center/widgets);
                // null — раскладка по умолчанию. Пишет редактор (LayoutState.qml)
                property var layout: null
                // Настройки виджета «Часы»
                property bool showSeconds: true
                property bool showDate: true
                property bool showWeekday: true
                // Максимум строк текста в карточке уведомления
                property int bodyLines: 4
                // Кнопки действий в уведомлениях
                property bool showActions: true
                // Звуки нажатий в центре
                property bool uiSounds: true
                // Календарь под уведомлениями
                property bool showCalendar: true
                // Сторона стрелок переключения месяца: "right" | "left"
                property string calendarArrows: "right"
                // Напоминания на датах календаря
                property bool reminders: true
                // Всплывать и в режиме «Не беспокоить»
                property bool remindersIgnoreDnd: false
                // Период повтора, с
                property int reminderInterval: 300
                // Повторять, пока не нажато «Остановить»; иначе — один раз
                property bool reminderRequireStop: true
                // Звук (имя файла из assets/sounds/notes, "" — без звука)
                property string reminderSound: ""
            }

            property JsonObject sound: JsonObject {
                // Звуки взаимодействия: печать, клик, окно громкости
                property bool interactionSounds: true
                // Звук печати в лаунчере (имя файла из assets/sounds)
                property string typeSound: "type.wav"
                // Звук клика (кнопки скриншотов и окна громкости)
                property string clickSound: "click.wav"
                // Звук уведомления (пока не интегрирован)
                property string notificationSound: "button.wav"
                // Звук окна громкости и Caps/Num Lock
                property string osdSound: "click.wav"
                // Окно громкости по клику на модуль в баре и его разделы
                property bool mixer: true
                property bool mixerOutputs: true
                property bool mixerInputs: true
                property bool mixerRestart: true
            }

            property JsonObject screenshot: JsonObject {
                // Уведомление после снимка
                property bool notify: true
                // Кисть, ластик и размытие на панели
                property bool editTools: true
                // Снимок сразу после выделения, без панели
                property bool instant: false
                // Звук снимка (файл из assets/sounds/screenshot)
                property bool sound: false
                property string soundFile: ""
            }

            property JsonObject recorder: JsonObject {
                // Пресет gpu-screen-recorder: medium | high | very_high | ultra
                property string quality: "ultra"
                // Высота видео (0 — исходное разрешение)
                property int resolution: 0
                // Запуск из центра уведомлений: весь монитор сразу (иначе — выбор области)
                property bool fullscreen: false
                // Не выше частоты монитора
                property int fps: 60
                property bool systemAudio: true
                property bool microphone: false
                // Уведомление после сохранения записи
                property bool notify: true
            }

            property JsonObject powerMenu: JsonObject {
                // Время удержания кнопки до срабатывания, мс
                property int holdTime: 1200
                property bool showPoweroff: true
                property bool showReboot: true
                property bool showSleep: true
                property bool showExit: true
                // Размер содержимого окна, лог. px
                property int width: 420
                property int height: 140
                // Подписи под кнопками
                property bool labels: false
            }

            property JsonObject performanceMenu: JsonObject {
                // Время удержания кнопки до срабатывания, мс
                property int holdTime: 600
                property bool showPowerSaver: true
                property bool showBalanced: true
                property bool showPerformance: true
                // Размер содержимого окна, лог. px
                property int width: 460
                property int height: 140
                // Подписи под кнопками
                property bool labels: true
            }

            property JsonObject launcher: JsonObject {
                // Край экрана, от которого выезжает лаунчер: "top" | "bottom" | "left" | "right"
                property string position: "bottom"
                property bool showIcons: true
                property bool showDescriptions: true
                // Первая буква названия вместо недоступной иконки
                property bool letterIcons: true
                // id desktop-файлов; закреплённые — в начале списка, по порядку
                property list<string> pinnedApps: []
                property list<string> hiddenApps: []
                // Пользовательские теги для поиска "#тег": [{ name, apps: [id desktop-файлов] }]
                property var tags: []
                // Кнопки тегов под строкой поиска
                property bool showTagButtons: true
                // Команды: ">" — запуск в терминале, "/emoji", "/web"
                property bool commandShell: true
                property bool commandEmoji: true
                property bool commandWeb: true
            }

            property JsonObject clipboard: JsonObject {
                // Максимум записей в истории
                property int maxItems: 100
                property bool images: true
                // Хранить историю между сессиями
                property bool persist: true
                // Ссылки на скопированные файлы (text/uri-list)
                property bool documents: true
                // Размер окна, лог. px
                property int width: 600
                property int height: 500
                // Записей на одной странице списка
                property int pageItems: 8
            }

            property JsonObject assistant: JsonObject {
                // Имя и подпись в шапке чата
                property string name: "Ассистент"
                property string description: "ИИ-помощник"
                // Аватар (файл из assets/img/avatars, "" — нет)
                property string avatar: ""
                property string systemPrompt: ""
                // Ключ OpenRouter
                property string apiKey: ""
                property string model: "qwen/qwen-2.5-7b-instruct"
                property real temperature: 0.7
                property int maxTokens: 1024
                // Край экрана, от которого выезжает окно: "left" | "right"
                property string side: "left"
                // Ширина окна, лог. px
                property int width: 420
                // Высота окна — доля доступной высоты экрана, 0.4..1
                property real heightRatio: 1.0
                // Базовый размер текста в окне, px
                property int fontSize: 12
                // Команды чата
                property string clearCommand: "/clear"
                property string reloadCommand: "/reload"
                property string loadCommand: "/load"
            }

            property JsonObject news: JsonObject {
                // Готовые темы Google News (id из Bar/news/NewsTopics.js), менять присваиванием
                property list<string> topics: ["WORLD", "TECHNOLOGY"]
                // Свои темы — поисковые запросы Google News, менять присваиванием
                property list<string> queries: []
                // URL своих RSS/Atom-лент, менять присваиванием
                property list<string> feeds: []
                // Период обновления, пока окно открыто, мин
                property int refreshInterval: 30
                // Новостей с одной темы или ленты
                property int maxItems: 20
                // Край экрана, от которого выезжает окно: "left" | "right"
                property string side: "right"
                // Ширина окна, лог. px
                property int width: 420
                // Высота окна — доля доступной высоты экрана, 0.4..1
                property real heightRatio: 1.0
            }

            property JsonObject weather: JsonObject {
                // Дней в прогнозе, 1..7
                property int days: 7
                // Показывать почасовой прогноз
                property bool hourly: true
                // Фон карточки по времени суток и погоде; выкл — цвета палитры
                property bool dynamicBackground: true
                // Динамический фон на всё окно, а не только на карточку текущей погоды
                property bool fullBackground: false
                // Полупрозрачные карточки с размытием динамического фона (при fullBackground)
                property bool blur: false
                // Обводка полупрозрачных карточек (при blur)
                property bool borders: true
                // Капли дождя на стекле окна во время дождя (при fullBackground)
                property bool raindrops: true
                // Слой капель: "under" — под карточками и текстом, "over" — поверх всего окна
                property string raindropsLayer: "under"
                // «Дождь как из ведра!»: очень много стекающих капель при любой погоде (при raindrops)
                property bool downpour: false
                // Стиль значков погоды: "material" (цвета палитры) | "colored" (цветные градиенты)
                property string iconStyle: "material"
                // Увеличенный масштаб окна (×1.25)
                property bool zoom: false
                // Местоположение по IP; выкл — по city
                property bool autoLocation: true
                // Город для прогноза при выключенном автоопределении
                property string city: ""
                // Период обновления, мин
                property int refreshInterval: 30
            }

            property JsonObject wallpaper: JsonObject {
                // Пароль секретных обоев (~/Pictures/.secret_wallpapers), "" — вход закрыт
                property string password: ""
            }

            property JsonObject widgets: JsonObject {
                // Экземпляры виджетов: [{ uid, type, screen, x, y, width, height, settings }].
                // Пишет только редактор (widgets/WidgetsState.qml), менять присваиванием
                property var items: []
                // Сетка редактора и её шаг, лог. px
                property bool grid: false
                property int gridSize: 40
                // Отдельный набор виджетов лок-скрина, формат как у items
                property var lockItems: []
                // Набор лок-скрина по умолчанию уже добавлен (WidgetsState.seedLock)
                property bool lockDefaultsAdded: false
            }

            property JsonObject lockscreen: JsonObject {
                property bool enabled: true
                // Блокировка после бездействия, мин
                property bool idleLock: false
                property int idleTimeout: 10
                // Выкл — разблокировка любой клавишей
                property bool requirePassword: true
                // Свой пароль вместо пароля пользователя (PAM)
                property bool customPasswordEnabled: false
                property string customPassword: ""
                property bool showPassword: false
                // Диаметр точек пароля, лог. px
                property int dotSize: 12
                property bool animation: true
                property bool widgets: true
                // Фон: скриншот рабочего стола важнее обоев; оба выкл — цвет surface
                property bool screenshotBackground: true
                property bool wallpaperBackground: false
                property bool blur: true
                property bool hideNotifications: true
            }

            property JsonObject security: JsonObject {
                // Скрывать всплывающие уведомления (слой message-card) от записи экрана
                property bool hidePopups: false
                // id desktop-файлов, окна которых скрываются от записи экрана
                property list<string> protectedApps: []
            }
        }
    }
}
