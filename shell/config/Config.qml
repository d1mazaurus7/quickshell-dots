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
                // Высота панели — доля доступной высоты экрана, 0.4..1
                property real heightRatio: 1.0
                property bool showClock: true
                property bool showSeconds: true
                property bool showDate: true
                property bool showWeekday: true
                property bool showWifi: true
                property bool showBluetooth: true
                property bool showDnd: true
                property bool showBrightness: true
                property bool showVolume: true
                // Максимум строк текста в карточке уведомления
                property int bodyLines: 4
                // Кнопки действий в уведомлениях
                property bool showActions: true
                // Звуки нажатий в центре
                property bool uiSounds: true
            }

            property JsonObject sound: JsonObject {
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
        }
    }
}
