pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "WeatherCodes.js" as Codes

// Содержимое окна погоды (сверху вниз): текущая погода, почасовой прогноз, карточки дней.
// Карточка дня по нажатию раскрывает прогноз на этот день с шагом 3 часа.
Item {
    id: panel

    // Отступ окна вокруг панели и радиусы окна: фон на всё окно заходит под отступ
    property int bleed: 0
    property int topRadius: 0
    property int bottomRadius: 0
    // Видимая высота окна (анимация раскрытия) и полная высота окна — небо не тянется за содержимым
    property real revealHeight: height + bleed * 2
    property real skyHeight: height + bleed * 2
    // Окно открыто: фоновая анимация значка текущей погоды
    property bool active: false

    readonly property var colors: Tokens.colors
    readonly property var cfg: Config.options.weather
    readonly property var w: WeatherState
    readonly property var cur: w.current

    readonly property real zoom: cfg.zoom ? 1.25 : 1
    function px(v: real): int { return Math.round(Tokens.scaled(v) * zoom); }
    function sp(v: int): int { return Math.round(v * zoom); }
    function alpha(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a); }
    readonly property int fontS: Math.round(Tokens.fontSmall.pixelSize * zoom)
    readonly property int fontM: Math.round(Tokens.fontMedium.pixelSize * zoom)
    readonly property int fontL: Math.round(Tokens.fontLarge.pixelSize * zoom)
    readonly property int cardRadius: Math.round(Tokens.radiusLarge * zoom)
    // Внутренние углы и зазор элементов в группе (M3 Expressive)
    readonly property int innerRadius: Math.round(Tokens.radiusSmall * zoom)
    readonly property int groupGap: Math.max(2, sp(2))
    readonly property int blurScale: 4
    readonly property int hourRadius: Math.round(Tokens.radiusMedium * 1.5 * zoom)

    // Небо по погоде и времени суток, у восхода/заката — тёплый оттенок; слегка тонировано палитрой
    readonly property bool dynamic: cfg.dynamicBackground && w.ready
    readonly property bool fullSky: dynamic && cfg.fullBackground
    readonly property bool glass: fullSky && cfg.blur
    readonly property bool glassBorders: glass && cfg.borders
    readonly property bool coloredIcons: cfg.iconStyle === "colored"
    // Время сегодняшнего дня: слайдер задаёт сдвиг от «сейчас» в минутах (minuteOffset),
    // всё в карточке и на небе следует за плавно догоняющим его smoothOffset
    // Шкала — все часы почасового прогноза (сутки вперёд); abs — минуты от полуночи сегодня,
    // после полуночи больше 1440
    readonly property var timeline: w.hourly.map(h => Object.assign({ abs: h.minutes + (h.date !== w.hourly[0].date ? 1440 : 0) }, h))
    readonly property int nowMinutes: timeline.length > 0 ? timeline[0].abs : 0
    readonly property int maxOffset: timeline.length > 1 ? timeline[timeline.length - 1].abs - nowMinutes : 0
    // Час шкалы, ближайший к выбранному времени
    readonly property int timeIndex: {
        const t = nowMinutes + minuteOffset;
        let best = 0;
        for (let i = 1; i < timeline.length; i++)
            if (Math.abs(timeline[i].abs - t) < Math.abs(timeline[best].abs - t))
                best = i;
        return best;
    }
    property int minuteOffset: 0
    property real smoothOffset: minuteOffset
    // Сглаженное время подхватывает новую цель без рывка (колесо, клик, слайдер)
    Behavior on smoothOffset { SmoothedAnimation { velocity: -1; duration: Tokens.animationSlow * 1.5 } }
    // Колесо и тачпад листают время: щелчок колеса — 20 минут, дробные шаги тачпада копятся
    property real wheelRest: 0
    function scrollTime(minutes: real) {
        wheelRest += minutes;
        const whole = Math.trunc(wheelRest);
        wheelRest -= whole;
        minuteOffset = Math.max(0, Math.min(maxOffset, minuteOffset + whole));
    }
    readonly property real time: nowMinutes + smoothOffset

    // Погода на момент time: числа — линейно между соседними часами, код и день/ночь — по ближайшему часу
    readonly property var shown: {
        const hs = timeline;
        if (hs.length === 0)
            return cur;
        let i = 0;
        while (i < hs.length - 1 && hs[i + 1].abs <= time)
            i++;
        const a = hs[i], b = hs[Math.min(i + 1, hs.length - 1)];
        const f = b.abs > a.abs ? Math.max(0, Math.min(1, (time - a.abs) / (b.abs - a.abs))) : 0;
        const near = f < 0.5 ? a : b;
        const lerp = (x, y) => x + (y - x) * f;
        const m = Math.round(time);
        return {
            time: Math.round(smoothOffset) === 0 ? "Сейчас"
                : String(Math.floor(m / 60) % 24).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0"),
            temp: lerp(a.temp, b.temp), feels: lerp(a.feels, b.feels), humidity: Math.round(lerp(a.humidity, b.humidity)),
            precip: a.precip, wind: lerp(a.wind, b.wind), windDir: near.windDir, code: near.code, isDay: near.isDay
        };
    }

    readonly property int code: w.ready ? shown.code : 0
    readonly property string kind: Codes.kind(code)
    readonly property real rainPower: Codes.rain(code)
    // Капли на стекле: включены ли, поверх ли всего окна; параметры — по силе дождя
    readonly property bool drops: fullSky && cfg.raindrops
    readonly property bool dropsOver: drops && cfg.raindropsLayer === "over"
    // «Дождь как из ведра!» — капли при любой погоде и сильнее ливня (третий слой стекающих)
    readonly property real dropPower: drops && cfg.downpour ? 1.5 : rainPower
    readonly property real dropStatic: dropPower > 0 ? Math.min(0.95, 0.3 + 0.55 * dropPower) : 0
    readonly property real dropSlide: dropPower > 0 ? 0.1 + 0.9 * dropPower : 0
    readonly property real dropScale: 0.8 + 0.5 * Math.min(1, dropPower)
    readonly property bool isDay: w.ready ? shown.isDay : true

    function clamp01(v: real): real { return Math.max(0, Math.min(1, v)); }
    function mix(a: color, b: color, f: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.a + (b.a - a.a) * f);
    }
    // Светлота неба 0..1: плавный переход за полчаса до и после восхода/заката
    // Время суток выбранного момента (после полуночи — восход и закат как сегодня)
    readonly property real dayTime: time % 1440
    readonly property real daylight: w.ready ? clamp01(Math.min((dayTime - w.sunriseMin + 30) / 60, (w.sunsetMin + 30 - dayTime) / 60)) : 1
    readonly property real twilight: Math.max(0, 1 - Math.min(Math.abs(dayTime - w.sunriseMin), Math.abs(dayTime - w.sunsetMin)) / 60)
    readonly property var dayPair: Codes.sky(code, true)
    readonly property var nightPair: Codes.sky(code, false)
    // Ход солнца (0 — восход, 1 — закат) и луны (0 — закат, 1 — восход)
    readonly property real sunProgress: (dayTime - w.sunriseMin) / Math.max(1, w.sunsetMin - w.sunriseMin)
    readonly property real moonProgress: ((dayTime - w.sunsetMin + 1440) % 1440) / Math.max(1, 1440 - (w.sunsetMin - w.sunriseMin))
    // Фаза луны (0 — новолуние, 0.5 — полнолуние) на дату выбранного момента; по дате, чтобы
    // фигура луны перестраивалась не чаще раза в сутки
    readonly property int dayShift: Math.floor(time / 1440)
    readonly property real moonPhase: {
        const d = new Date(w.hourly[0]?.date ?? Date.now());
        const jd = d.getTime() / 86400000 + 2440587.5 + 0.5 + dayShift;
        const p = ((jd - 2451550.1) / 29.530588853) % 1;
        return Math.round((p < 0 ? p + 1 : p) * 100) / 100;
    }
    // Ночью палитра почти не подмешивается: небо остаётся тёмным
    readonly property real tintAmount: 0.05 + 0.1 * daylight
    function skyColor(c: color, warm: real): color {
        const tinted = Qt.tint(c, Qt.rgba(1, 0.55, 0.3, 0.45 * warm));
        return Qt.tint(tinted, alpha(colors.primary, tintAmount));
    }
    readonly property color skyTop: skyColor(mix(nightPair[0], dayPair[0], daylight), twilight)
    readonly property color skyBottom: skyColor(mix(nightPair[1], dayPair[1], daylight), twilight * 0.6)

    readonly property color white: "white"
    // Карточка текущей погоды: своё небо, палитра или прозрачная поверх неба окна
    readonly property color heroTop: fullSky ? "transparent" : dynamic ? skyTop : colors.primary_container
    readonly property color heroBottom: fullSky ? "transparent" : dynamic ? skyBottom : colors.primary_container
    readonly property color heroText: dynamic ? white : colors.on_primary_container
    // Остальные карточки
    readonly property color cardText: glass ? white : colors.on_surface
    readonly property color cardTextDim: glass ? alpha(white, 0.75) : colors.on_surface_variant

    readonly property var days: w.daily.slice(0, cfg.days)
    readonly property real weekMin: Math.min(...days.map(d => d.min))
    readonly property real weekMax: Math.max(...days.map(d => d.max))
    // Раскрытая карточка дня, -1 — нет
    property int expanded: -1

    implicitHeight: content.implicitHeight

    // Сцена: небо и содержимое окна; при каплях поверх всего с неё снимается текстура для преломления
    Item {
        id: scene
        anchors.fill: parent

        // Небо на всё окно (с отступом окна), высотой с видимую часть окна; градиент и рисунок —
        // по полной высоте окна, поэтому при раскрытии карточек ничего не сдвигается.
        // Размытая копия (blurredSky) видна только сквозь «стеклянные» карточки.
        Item {
            x: -panel.bleed
            y: -panel.bleed
            width: panel.width + panel.bleed * 2
            height: Math.max(0, panel.revealHeight)
            opacity: panel.fullSky ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

            Rectangle {
                id: skyMask
                anchors.fill: parent
                topLeftRadius: panel.topRadius
                topRightRadius: panel.topRadius
                bottomLeftRadius: panel.bottomRadius
                bottomRightRadius: panel.bottomRadius
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                id: blurredSky
                // Размытие в 1/blurScale разрешения: размытая картинка гладкая, а пикселей в 16 раз меньше;
                // карточки берут из неё свои участки с поправкой на масштаб
                width: parent.width / panel.blurScale
                height: parent.height / panel.blurScale
                visible: panel.glass
                source: sky
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64 / panel.blurScale
            }

            Item {
                id: sky
                anchors.fill: parent
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: skyMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(parent.height, panel.skyHeight)
                    gradient: Gradient {
                        GradientStop { position: 0; color: panel.skyTop; Behavior on color { ColorAnimation { duration: Tokens.animationSlow } } }
                        GradientStop { position: 1; color: panel.skyBottom; Behavior on color { ColorAnimation { duration: Tokens.animationSlow } } }
                    }
                }

                // Звёзды: медленно плывут вместе со временем
                Repeater {
                    model: 18
                    Rectangle {
                        required property int index
                        x: ((index * 137 % 100) / 100 * sky.width + panel.time * panel.px(100) / 100 * 0.15) % sky.width
                        y: (index * 71 % 100) / 100 * panel.skyHeight * 0.5
                        width: panel.px(index % 3 === 0 ? 3 : 2)
                        height: width
                        radius: width / 2
                        color: panel.white
                        opacity: panel.code <= 1 ? 0.7 * (1 - panel.daylight) : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow } }
                    }
                }

                // Солнце и луна идут по дуге от левого края к правому; луна приглушена, чтобы текст на ней читался
                WeatherOrb {
                    width: panel.px(110)
                    color: "#ffd66b"
                    unit: panel.px(100) / 100
                    areaWidth: sky.width
                    progress: panel.sunProgress
                    // Сквозь сплошную облачность и туман солнце едва просвечивает
                    opacity: (panel.code <= 2 ? 0.8 : panel.kind === "cloudy" || panel.kind === "fog" ? 0.22 : 0) * panel.daylight
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow } }
                }

                WeatherOrb {
                    width: panel.px(76)
                    color: "#b9c1d0"
                    unit: panel.px(100) / 100
                    areaWidth: sky.width
                    progress: panel.moonProgress
                    phase: panel.moonPhase
                    opacity: (panel.code <= 2 ? 0.6 : panel.kind === "cloudy" || panel.kind === "fog" ? 0.15 : 0) * (1 - panel.daylight)
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow } }
                }

                // Туман: светлая дымка снизу
                Rectangle {
                    width: parent.width
                    height: Math.max(parent.height, panel.skyHeight)
                    opacity: panel.kind === "fog" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow * 2 } }
                    gradient: Gradient {
                        GradientStop { position: 0.2; color: "transparent" }
                        GradientStop { position: 1; color: panel.alpha(panel.white, 0.22 + 0.12 * panel.daylight) }
                    }
                }
            }

            // Подвижный слой неба: облака и осадки. Он вне размываемого неба (sky), поэтому движение
            // не пересчитывает размытие и копии под «стеклянными» карточками — карточки его закрывают.
            // Обрезан прямоугольником без скруглённых углов окна (дешевле маски).
            Item {
                id: weatherLayer
                y: panel.topRadius
                width: parent.width
                height: Math.max(0, parent.height - panel.topRadius - panel.bottomRadius)
                clip: true
                readonly property bool run: panel.active && panel.fullSky
                readonly property real unit: panel.px(100) / 100
                readonly property real areaHeight: panel.skyHeight

                // Облака: при переменной облачности часть, при пасмурной погоде, осадках и тумане — все;
                // две полосы с разной скоростью дают параллакс
                Item {
                    y: -weatherLayer.y
                    width: parent.width
                    height: weatherLayer.areaHeight
                    opacity: panel.code < 2 ? 0 : (panel.kind === "fog" ? 0.22 : 0.14) + 0.31 * panel.daylight
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow * 2 } }
                    readonly property color tone: panel.kind === "rain" || panel.kind === "storm" ? "#b9c3cf" : panel.white
                    readonly property bool many: panel.code > 2

                    WeatherCloudLayer {
                        anchors.fill: parent
                        unit: weatherLayer.unit
                        tone: parent.tone
                        duration: 140000
                        // Перемотка времени гонит облака, как ветер в ускоренной съёмке
                        shift: panel.smoothOffset * weatherLayer.unit * 0.5
                        running: weatherLayer.run && parent.visible
                        visibleCount: parent.many ? 6 : 3
                        clouds: [{ x: 0.1, y: 0.06, s: 0.8 }, { x: 0.62, y: 0.34, s: 0.7 }, { x: 0.3, y: 0.58, s: 0.9 },
                                 { x: 0.8, y: 0.1, s: 0.6 }, { x: 0.45, y: 0.2, s: 0.75 }, { x: 0.05, y: 0.82, s: 0.8 }]
                    }
                    WeatherCloudLayer {
                        anchors.fill: parent
                        unit: weatherLayer.unit
                        tone: parent.tone
                        duration: 80000
                        // Перемотка времени гонит облака, как ветер в ускоренной съёмке
                        shift: panel.smoothOffset * weatherLayer.unit * 1.1
                        running: weatherLayer.run && parent.visible
                        visibleCount: parent.many ? 6 : 3
                        clouds: [{ x: 0.05, y: 0.03, s: 1.2 }, { x: 0.15, y: 0.3, s: 1.4 }, { x: 0.55, y: 0.8, s: 1.3 },
                                 { x: 0.5, y: 0.12, s: 0.9 }, { x: 0.6, y: 0.45, s: 1.1 }, { x: 0.02, y: 0.65, s: 1.0 }]
                    }
                }
            }

            // Капли на стекле во время дождя: чем сильнее (морось → дождь → ливень, гроза), тем больше
            // капель, чаще и крупнее стекают и ярче струи за стеклом
            WeatherRainGlass {
                anchors.fill: parent
                skySource: sky
                unit: weatherLayer.unit
                topRadius: panel.topRadius
                bottomRadius: panel.bottomRadius
                // Струи дождя за стеклом — всегда здесь; капли — если включены и не поверх всего
                staticAmount: panel.drops && !panel.dropsOver ? panel.dropStatic : 0
                slideAmount: panel.drops && !panel.dropsOver ? panel.dropSlide : 0
                dropSize: panel.dropScale
                streaks: panel.dropPower > 0 ? 0.12 + 0.55 * Math.min(1.2, panel.dropPower) : 0
                visible: staticAmount > 0.01 || slideAmount > 0.01 || streaks > 0.01
                running: panel.active && panel.fullSky
            }
        }

        ColumnLayout {
            id: content
            width: parent.width
            spacing: panel.sp(Tokens.spacingMediumV)

            // Текущая погода
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: hero.implicitHeight + panel.sp(Tokens.spacingLargeV) * 2
                radius: Math.round(panel.cardRadius * 1.5)

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    enabled: panel.maxOffset > 0
                    onWheel: event => panel.scrollTime(-(event.angleDelta.y || event.angleDelta.x) / 120 * 20)
                }
                gradient: Gradient {
                    GradientStop { position: 0; color: panel.heroTop; Behavior on color { ColorAnimation { duration: Tokens.animationSlow } } }
                    GradientStop { position: 1; color: panel.heroBottom; Behavior on color { ColorAnimation { duration: Tokens.animationSlow } } }
                }

                ColumnLayout {
                    id: hero
                    anchors.fill: parent
                    anchors.leftMargin: panel.sp(Tokens.spacingLarge)
                    anchors.rightMargin: panel.sp(Tokens.spacingLarge)
                    anchors.topMargin: panel.sp(Tokens.spacingLargeV)
                    anchors.bottomMargin: panel.sp(Tokens.spacingLargeV)
                    spacing: panel.sp(Tokens.spacingSmallV)

                    RowLayout {
                        spacing: panel.sp(Tokens.spacingSmall)
                        layer.enabled: panel.fullSky
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35; shadowBlur: 0.5; shadowVerticalOffset: 1 }
                        WeatherIcon {
                            id: locationIcon
                            text: "location_on"
                            color: panel.heroText
                            font.pixelSize: panel.px(16)
                            filled: true
                            Connections {
                                target: panel.w
                                function onCityChanged() { locationIcon.pop(); }
                            }
                        }
                        WeatherText {
                            color: panel.heroText
                            font.pixelSize: panel.fontM
                            Layout.fillWidth: true
                            text: panel.w.city || "—"
                            elide: Text.ElideRight
                        }

                        // Обновление: во время загрузки кнопка выключена, значок вращается
                        WeatherIconButton {
                            implicitWidth: panel.px(32)
                            implicitHeight: implicitWidth
                            icon: "refresh"
                            iconSize: panel.px(18)
                            color: panel.heroText
                            enabled: !panel.w.loading
                            spinning: panel.w.loading
                            onClicked: panel.w.refresh()
                        }
                    }

                    RowLayout {
                        spacing: panel.sp(Tokens.spacingMedium)
                        // Значок вне слоя с тенью: его анимация не перерисовывает тень
                        WeatherGlyph {
                            name: panel.w.ready ? Codes.icon(panel.shown.code, panel.shown.isDay) : "cloud"
                            night: !panel.isDay
                            colored: panel.coloredIcons
                            tint: panel.heroText
                            size: panel.px(56)
                            enabled: panel.w.ready
                            active: panel.active
                            hovered: heroGlyphHover.hovered
                            HoverHandler { id: heroGlyphHover }
                        }

                        RowLayout {
                        Layout.fillWidth: true
                        spacing: panel.sp(Tokens.spacingMedium)
                        // Тень под текстом: светлый текст читается и на солнце/луне
                        layer.enabled: panel.fullSky
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35; shadowBlur: 0.5; shadowVerticalOffset: 1 }
                        WeatherText {
                            color: panel.heroText
                            text: panel.w.ready ? Codes.temp(panel.shown.temp) : "--°"
                            font.pixelSize: panel.px(56)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: panel.sp(Tokens.spacingSmallV)
                            WeatherText {
                                color: panel.heroText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: panel.w.error || (panel.w.ready ? Codes.describe(panel.shown.code) : "Загрузка…")
                                font.pixelSize: panel.fontL
                                wrapMode: Text.WordWrap
                            }
                            WeatherText {
                                color: panel.heroText
                                Layout.fillWidth: true
                                visible: panel.w.ready
                                horizontalAlignment: Text.AlignRight
                                text: panel.w.ready ? "Ощущается как " + Codes.temp(panel.shown.feels) : ""
                                opacity: 0.8
                                font.pixelSize: panel.fontS
                            }
                            WeatherText {
                                color: panel.heroText
                                Layout.fillWidth: true
                                visible: panel.w.ready && panel.days.length > 0
                                horizontalAlignment: Text.AlignRight
                                text: visible ? Codes.temp(panel.days[0].min) + " … " + Codes.temp(panel.days[0].max) : ""
                                opacity: 0.8
                                font.pixelSize: panel.fontS
                            }
                        }
                        }
                    }

                    // Время выбранного момента: карточка показывает прогноз на выбранный час
                    RowLayout {
                        Layout.topMargin: panel.sp(Tokens.spacingSmallV)
                        visible: panel.maxOffset > 0
                        spacing: panel.sp(Tokens.spacingMedium)

                        // Выбран не текущий час — кнопка включена и возвращает слайдер к «сейчас»
                        WeatherIconButton {
                            implicitWidth: panel.px(32)
                            implicitHeight: implicitWidth
                            icon: checked ? "history" : "schedule"
                            iconSize: panel.px(18)
                            color: panel.heroText
                            containerColor: panel.alpha(panel.heroText, 0.2)
                            checked: panel.minuteOffset !== 0
                            enabled: checked
                            onClicked: panel.minuteOffset = 0
                        }
                        WeatherTimeSlider {
                            Layout.fillWidth: true
                            owner: panel
                            nowMinutes: panel.nowMinutes
                            to: Math.max(1, panel.maxOffset)
                            offset: panel.minuteOffset
                            smoothValue: panel.smoothOffset
                            onMoved: panel.minuteOffset = Math.round(value)
                        }
                        WeatherText {
                            Layout.preferredWidth: panel.px(56)
                            horizontalAlignment: Text.AlignRight
                            text: panel.shown.time ?? ""
                            color: panel.heroText
                            font.pixelSize: panel.fontM
                        }
                    }

                    // Группа показателей: внутренние углы малые, крайние — большие
                    RowLayout {
                        Layout.topMargin: panel.sp(Tokens.spacingMediumV)
                        visible: panel.w.ready
                        spacing: panel.groupGap
                        WeatherStat {
                            owner: panel
                            blurSource: blurredSky
                            rightRadius: panel.innerRadius
                            icon: "air"
                            text: panel.w.ready ? Codes.decimal(panel.shown.wind) + " м/с " + Codes.direction(panel.shown.windDir) : ""
                        }
                        WeatherStat {
                            owner: panel; blurSource: blurredSky; leftRadius: panel.innerRadius; rightRadius: panel.innerRadius
                            icon: "humidity_percentage"; text: panel.w.ready ? panel.shown.humidity + "%" : ""
                        }
                        WeatherStat {
                            owner: panel; blurSource: blurredSky; leftRadius: panel.innerRadius; rightRadius: panel.innerRadius
                            icon: "umbrella"; text: panel.w.ready ? Codes.decimal(panel.shown.precip) + " мм" : ""
                        }
                        WeatherStat {
                            owner: panel; blurSource: blurredSky; leftRadius: panel.innerRadius; rightRadius: panel.innerRadius
                            icon: "wb_twilight"; text: panel.w.sunrise
                        }
                        WeatherStat { owner: panel; blurSource: blurredSky; leftRadius: panel.innerRadius; icon: "bedtime"; text: panel.w.sunset }
                    }
                }
            }

            // Почасовой прогноз на сутки
            WeatherCard {
                Layout.fillWidth: true
                owner: panel
                blurSource: blurredSky
                visible: panel.cfg.hourly

                ListView {
                    id: hours
                    width: parent.width
                    height: panel.px(84)
                    orientation: ListView.Horizontal
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: panel.w.hourly

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const d = event.angleDelta.y || event.angleDelta.x;
                            hours.contentX = Math.max(0, Math.min(hours.contentWidth - hours.width, hours.contentX - d));
                        }
                    }

                    // Выбранный слайдером час: выделение пружинисто переезжает между часами
                    currentIndex: Math.min(count - 1, panel.timeIndex)
                    highlightFollowsCurrentItem: false
                    highlight: Rectangle {
                        readonly property Item item: hours.currentItem
                        x: item ? item.x + (item.width - width) / 2 : 0
                        y: panel.px(2)
                        width: panel.px(56)
                        height: hours.height - panel.px(4)
                        radius: panel.hourRadius
                        color: panel.glass ? panel.alpha(panel.white, 0.18) : panel.colors.secondary_container
                        Behavior on x { WeatherSpring {} }
                        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                    }

                    delegate: Item {
                        id: hour
                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem
                        readonly property color textColor: current && !panel.glass ? panel.colors.on_secondary_container : panel.cardText
                        // Час выбирается нажатием: слайдер и погода плавно переходят к ним
                        readonly property int offset: (panel.timeline[hour.index]?.abs ?? 0) - panel.nowMinutes
                        readonly property bool selectable: offset >= 0 && offset <= panel.maxOffset
                        width: panel.px(60)
                        height: hours.height

                        MouseArea {
                            id: hourArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: hour.selectable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (hour.selectable) panel.minuteOffset = hour.offset
                        }

                        // Слой состояния (только у выбираемых часов); при нажатии углы скругляются сильнее
                        Rectangle {
                            anchors.centerIn: parent
                            width: panel.px(56)
                            height: parent.height - panel.px(4)
                            property real r: hour.selectable && hourArea.pressed ? panel.cardRadius : panel.hourRadius
                            Behavior on r { WeatherSpring {} }
                            radius: r
                            color: hour.textColor
                            opacity: !hour.selectable ? 0 : hourArea.pressed ? 0.12 : hourArea.containsMouse ? 0.08 : 0
                            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: panel.sp(Tokens.spacingSmallV)

                            WeatherText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hour.modelData.time
                                color: hour.current && !panel.glass ? panel.colors.on_secondary_container : panel.cardTextDim
                                font.pixelSize: panel.fontS
                            }
                            WeatherGlyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: Codes.icon(hour.modelData.code, hour.modelData.isDay)
                                night: !hour.modelData.isDay
                                colored: panel.coloredIcons
                                tint: Codes.kind(hour.modelData.code) === "clear" && hour.modelData.isDay && !panel.glass && !hour.current
                                      ? panel.colors.tertiary : hour.textColor
                                size: panel.px(24)
                                hovered: hourArea.containsMouse
                            }
                            WeatherText {
                                color: hour.textColor
                                font.pixelSize: panel.fontM
                                font.weight: hour.current ? Font.DemiBold : Font.Normal
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Codes.temp(hour.modelData.temp)
                            }
                        }
                    }
                }
            }

            // Карточки дней
            // Группа карточек дней (M3 Expressive): внутренние углы малые; раскрытая карточка
            // отделяется от соседей и скругляется целиком, соседние углы тоже скругляются
            ColumnLayout {
                Layout.fillWidth: true
                spacing: panel.groupGap

                Repeater {
                    model: panel.days

                    WeatherCard {
                        id: day
                        required property var modelData
                        required property int index
                        readonly property bool open: panel.expanded === index
                        readonly property bool first: index === 0
                        readonly property bool last: index === panel.days.length - 1
                        property real detach: open ? panel.sp(Tokens.spacingSmallV) : 0
                        Behavior on detach { WeatherSpring {} }

                        Layout.fillWidth: true
                        Layout.topMargin: first ? 0 : detach
                        Layout.bottomMargin: last ? 0 : detach
                        owner: panel
                        blurSource: blurredSky
                        interactive: true
                        topRadius: first || open || panel.expanded === index - 1 ? panel.cardRadius : panel.innerRadius
                        bottomRadius: last || open || panel.expanded === index + 1 ? panel.cardRadius : panel.innerRadius
                        onClicked: panel.expanded = open ? -1 : index

                        ColumnLayout {
                            width: parent.width
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                implicitHeight: panel.px(40)
                                spacing: panel.sp(Tokens.spacingMedium)

                                Column {
                                    Layout.preferredWidth: panel.px(84)
                                    WeatherText { color: panel.cardText; font.pixelSize: panel.fontM; text: day.index === 0 ? "Сегодня" : Codes.weekday(day.modelData.date) }
                                    WeatherText {
                                        text: Codes.dateLabel(day.modelData.date)
                                        color: panel.cardTextDim
                                        font.pixelSize: panel.fontS
                                    }
                                }
                                WeatherGlyph {
                                    Layout.preferredWidth: panel.px(28)
                                    name: Codes.icon(day.modelData.code, true)
                                    colored: panel.coloredIcons
                                    tint: Codes.kind(day.modelData.code) === "clear" && !panel.glass ? panel.colors.tertiary : panel.cardText
                                    size: panel.px(24)
                                    hovered: day.hovered
                                }
                                WeatherText {
                                    font.pixelSize: panel.fontM
                                    Layout.preferredWidth: panel.px(36)
                                    horizontalAlignment: Text.AlignRight
                                    text: Codes.temp(day.modelData.min)
                                    color: panel.cardTextDim
                                }

                                // Диапазон дня на шкале недели
                                Rectangle {
                                    id: track
                                    Layout.fillWidth: true
                                    implicitHeight: panel.px(6)
                                    radius: height / 2
                                    color: panel.glass ? panel.alpha(panel.white, 0.2) : panel.colors.surface_container_highest

                                    readonly property real range: Math.max(1, panel.weekMax - panel.weekMin)
                                    Rectangle {
                                        x: (day.modelData.min - panel.weekMin) / track.range * track.width
                                        width: Math.max(height, (day.modelData.max - day.modelData.min) / track.range * track.width)
                                        height: parent.height
                                        radius: parent.radius
                                        gradient: Gradient {
                                            orientation: Gradient.Horizontal
                                            GradientStop { position: 0; color: panel.colors.primary }
                                            GradientStop { position: 1; color: panel.colors.tertiary }
                                        }
                                        Behavior on x { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                                        Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                                    }
                                }

                                WeatherText {
                                    color: panel.cardText
                                    font.pixelSize: panel.fontM
                                    Layout.preferredWidth: panel.px(36)
                                    text: Codes.temp(day.modelData.max)
                                }
                                WeatherText {
                                    Layout.preferredWidth: panel.px(56)
                                    horizontalAlignment: Text.AlignRight
                                    text: day.modelData.precip >= 0.1 ? Codes.decimal(day.modelData.precip) + " мм" : ""
                                    color: panel.cardTextDim
                                    font.pixelSize: panel.fontS
                                }
                                // Индикатор раскрытия: состояния следуют за карточкой
                                WeatherIconButton {
                                    implicitWidth: panel.px(28)
                                    implicitHeight: implicitWidth
                                    clickable: false
                                    hovered: day.hovered
                                    pressed: day.pressed
                                    checked: day.open
                                    icon: "expand_more"
                                    iconSize: panel.px(20)
                                    iconRotation: day.open ? 180 : 0
                                    color: panel.cardTextDim
                                    checkedColor: panel.glass ? panel.white : panel.colors.on_secondary_container
                                    containerColor: panel.glass ? panel.alpha(panel.white, 0.2) : panel.colors.secondary_container
                                }
                            }

                            // Прогноз на день с шагом 3 часа
                            // Высота округляется до пикселя: текст ниже не «дрожит» на дробных координатах
                            Item {
                                id: dayHoursBox
                                property real reveal: day.open ? 1 : 0
                                Behavior on reveal { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutCubic } }

                                Layout.fillWidth: true
                                implicitHeight: Math.round(dayHoursBox.reveal * (dayHours.implicitHeight + panel.sp(Tokens.spacingMediumV)))
                                clip: true
                                opacity: dayHoursBox.reveal

                                // Создаётся только на время раскрытия: свёрнутые дни не держат значки и текст
                                Loader {
                                    id: dayHours
                                    y: panel.sp(Tokens.spacingMediumV)
                                    width: parent.width
                                    active: dayHoursBox.reveal > 0
                                    sourceComponent: RowLayout {
                                    spacing: 0

                                    Repeater {
                                        model: day.modelData.hours

                                        Column {
                                            id: slot
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: panel.sp(Tokens.spacingSmallV)

                                            HoverHandler { id: slotHover }

                                            WeatherText {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: slot.modelData.time
                                                color: panel.cardTextDim
                                                font.pixelSize: panel.fontS
                                            }
                                            WeatherGlyph {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                name: Codes.icon(slot.modelData.code, slot.modelData.isDay)
                                                night: !slot.modelData.isDay
                                                colored: panel.coloredIcons
                                                tint: Codes.kind(slot.modelData.code) === "clear" && slot.modelData.isDay && !panel.glass
                                                      ? panel.colors.tertiary : panel.cardText
                                                size: panel.px(22)
                                                hovered: slotHover.hovered
                                            }
                                            WeatherText {
                                                color: panel.cardText
                                                font.pixelSize: panel.fontM
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: Codes.temp(slot.modelData.temp)
                                            }
                                        }
                                    }
                                }
                                }
                            }
                        }
                    }
                }
            }

            WeatherText {
                Layout.alignment: Qt.AlignRight
                text: "Данные Open-Meteo"
                color: panel.fullSky ? panel.alpha(panel.white, 0.7) : panel.colors.on_surface_variant
                font.pixelSize: panel.fontS
                opacity: 0.8
            }
        }
    }

    // Капли поверх всего окна: преломляют снимок сцены (небо, карточки, текст) как лупа.
    // Снимок обновляется вместе со сценой и только пока капли видны
    ShaderEffectSource {
        id: sceneTexture
        sourceItem: overDrops.visible ? scene : null
        sourceRect: Qt.rect(-panel.bleed, -panel.bleed, overDrops.width, overDrops.height)
        visible: false
    }

    WeatherRainGlass {
        id: overDrops
        x: -panel.bleed
        y: -panel.bleed
        width: panel.width + panel.bleed * 2
        height: Math.max(0, panel.revealHeight)
        skySource: sceneTexture
        unit: panel.px(100) / 100
        topRadius: panel.topRadius
        bottomRadius: panel.bottomRadius
        lens: 1
        staticAmount: panel.dropsOver ? panel.dropStatic : 0
        slideAmount: panel.dropsOver ? panel.dropSlide : 0
        dropSize: panel.dropScale
        visible: staticAmount > 0.01 || slideAmount > 0.01
        running: panel.active && panel.fullSky
    }
}
