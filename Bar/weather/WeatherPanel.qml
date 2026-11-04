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

    // Небо по погоде и времени суток, у восхода/заката — тёплый оттенок; слегка тонировано палитрой
    readonly property bool dynamic: cfg.dynamicBackground && w.ready
    readonly property bool fullSky: dynamic && cfg.fullBackground
    readonly property bool glass: fullSky && cfg.blur
    readonly property bool glassBorders: glass && cfg.borders
    readonly property bool coloredIcons: cfg.iconStyle === "colored"
    // Время сегодняшнего дня: слайдер задаёт сдвиг от «сейчас» в минутах (minuteOffset),
    // всё в карточке и на небе следует за плавно догоняющим его smoothOffset
    readonly property var todayHours: w.hourly.filter(h => h.date === w.hourly[0]?.date)
    readonly property int nowMinutes: todayHours.length > 0 ? todayHours[0].minutes : 0
    readonly property int maxOffset: todayHours.length > 1 ? todayHours[todayHours.length - 1].minutes - nowMinutes : 0
    property int minuteOffset: 0
    property real smoothOffset: minuteOffset
    Behavior on smoothOffset { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
    readonly property real time: nowMinutes + smoothOffset

    // Погода на момент time: числа — линейно между соседними часами, код и день/ночь — по ближайшему часу
    readonly property var shown: {
        const hs = todayHours;
        if (hs.length === 0)
            return cur;
        let i = 0;
        while (i < hs.length - 1 && hs[i + 1].minutes <= time)
            i++;
        const a = hs[i], b = hs[Math.min(i + 1, hs.length - 1)];
        const f = b.minutes > a.minutes ? Math.max(0, Math.min(1, (time - a.minutes) / (b.minutes - a.minutes))) : 0;
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
    readonly property bool isDay: w.ready ? shown.isDay : true

    function clamp01(v: real): real { return Math.max(0, Math.min(1, v)); }
    function mix(a: color, b: color, f: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, a.a + (b.a - a.a) * f);
    }
    // Светлота неба 0..1: плавный переход за полчаса до и после восхода/заката
    readonly property real daylight: w.ready ? clamp01(Math.min((time - w.sunriseMin + 30) / 60, (w.sunsetMin + 30 - time) / 60)) : 1
    readonly property real twilight: Math.max(0, 1 - Math.min(Math.abs(time - w.sunriseMin), Math.abs(time - w.sunsetMin)) / 60)
    readonly property var dayPair: Codes.sky(code, true)
    readonly property var nightPair: Codes.sky(code, false)
    // Ход солнца (0 — восход, 1 — закат) и луны (0 — закат, 1 — восход)
    readonly property real sunProgress: (time - w.sunriseMin) / Math.max(1, w.sunsetMin - w.sunriseMin)
    readonly property real moonProgress: ((time - w.sunsetMin + 1440) % 1440) / Math.max(1, 1440 - (w.sunsetMin - w.sunriseMin))
    function skyColor(c: color, warm: real): color {
        const tinted = Qt.tint(c, Qt.rgba(1, 0.55, 0.3, 0.45 * warm));
        return Qt.tint(tinted, alpha(colors.primary, 0.15));
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
            anchors.fill: parent
            visible: panel.glass
            source: sky
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
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
                opacity: panel.code <= 2 ? 0.8 * panel.daylight : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow } }
            }

            WeatherOrb {
                width: panel.px(76)
                color: "#b9c1d0"
                unit: panel.px(100) / 100
                areaWidth: sky.width
                progress: panel.moonProgress
                opacity: panel.code <= 2 ? 0.5 * (1 - panel.daylight) : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow } }
            }

            // Облака
            Repeater {
                model: [{ x: 0.05, y: 0.03, s: 1.2 }, { x: 0.5, y: 0.12, s: 0.9 }, { x: 0.15, y: 0.3, s: 1.4 },
                        { x: 0.6, y: 0.45, s: 1.1 }, { x: 0.02, y: 0.65, s: 1.0 }, { x: 0.55, y: 0.8, s: 1.3 }]
                WeatherCloud {
                    id: cloud
                    required property var modelData
                    unit: panel.px(100) / 100
                    // Дрейф по ветру со временем, уходят за край и возвращаются с другой стороны
                    x: (cloud.modelData.x * sky.width + panel.time * panel.px(100) / 100 * 0.6 * cloud.modelData.s)
                       % (sky.width + width) - width
                    y: cloud.modelData.y * panel.skyHeight
                    size: cloud.modelData.s
                    tone: panel.kind === "rain" || panel.kind === "storm" ? "#b9c3cf" : panel.white
                    opacity: panel.code < 2 ? 0 : 0.14 + 0.31 * panel.daylight
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow } }
                }
            }
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
            radius: panel.cardRadius
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
                    WeatherIcon { text: "location_on"; color: panel.heroText; font.pixelSize: panel.px(16) }
                    WeatherText {
                        color: panel.heroText
                        font.pixelSize: panel.fontM
                        Layout.fillWidth: true
                        text: panel.w.city || "—"
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: panel.px(28)
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: refreshArea.pressed ? panel.alpha(panel.heroText, 0.28)
                             : refreshArea.containsMouse ? panel.alpha(panel.heroText, 0.16)
                             : "transparent"
                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                        WeatherIcon {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: "refresh"
                            color: panel.heroText
                            font.pixelSize: panel.px(18)
                            RotationAnimation on rotation {
                                running: panel.w.loading
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 900
                                onRunningChanged: if (!running) refreshIcon.rotation = 0
                            }
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.w.refresh()
                        }
                    }
                }

                RowLayout {
                    spacing: panel.sp(Tokens.spacingMedium)
                    // Тень под текстом: светлый текст читается и на солнце/луне
                    layer.enabled: panel.fullSky
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35; shadowBlur: 0.5; shadowVerticalOffset: 1 }
                    WeatherGlyph {
                        name: panel.w.ready ? Codes.icon(panel.shown.code, panel.shown.isDay) : "cloud"
                        night: !panel.isDay
                        colored: panel.coloredIcons
                        tint: panel.heroText
                        size: panel.px(56)
                    }
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

                // Время сегодняшнего дня: карточка показывает прогноз на выбранный час
                RowLayout {
                    Layout.topMargin: panel.sp(Tokens.spacingSmallV)
                    visible: panel.maxOffset > 0
                    spacing: panel.sp(Tokens.spacingMedium)

                    WeatherIcon {
                        text: "schedule"
                        color: panel.alpha(panel.heroText, 0.8)
                        font.pixelSize: panel.px(18)
                    }
                    WeatherTimeSlider {
                        Layout.fillWidth: true
                        owner: panel
                        nowMinutes: panel.nowMinutes
                        to: Math.max(1, panel.maxOffset)
                        offset: panel.minuteOffset
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

                RowLayout {
                    Layout.topMargin: panel.sp(Tokens.spacingMediumV)
                    visible: panel.w.ready
                    spacing: panel.sp(Tokens.spacingMedium)
                    WeatherStat {
                        owner: panel
                        blurSource: blurredSky
                        icon: "air"
                        text: panel.w.ready ? Codes.decimal(panel.shown.wind) + " м/с " + Codes.direction(panel.shown.windDir) : ""
                    }
                    WeatherStat { owner: panel; blurSource: blurredSky; icon: "humidity_percentage"; text: panel.w.ready ? panel.shown.humidity + "%" : "" }
                    WeatherStat { owner: panel; blurSource: blurredSky; icon: "umbrella"; text: panel.w.ready ? Codes.decimal(panel.shown.precip) + " мм" : "" }
                    WeatherStat { owner: panel; blurSource: blurredSky; icon: "wb_twilight"; text: panel.w.sunrise }
                    WeatherStat { owner: panel; blurSource: blurredSky; icon: "bedtime"; text: panel.w.sunset }
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

                delegate: Column {
                    id: hour
                    required property var modelData
                    width: panel.px(60)
                    anchors.verticalCenter: parent?.verticalCenter
                    spacing: panel.sp(Tokens.spacingSmallV)

                    WeatherText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hour.modelData.time
                        color: panel.cardTextDim
                        font.pixelSize: panel.fontS
                    }
                    WeatherGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Codes.icon(hour.modelData.code, hour.modelData.isDay)
                        night: !hour.modelData.isDay
                        colored: panel.coloredIcons
                        tint: Codes.kind(hour.modelData.code) === "clear" && hour.modelData.isDay && !panel.glass
                              ? panel.colors.tertiary : panel.cardText
                        size: panel.px(24)
                    }
                    WeatherText {
                        color: panel.cardText
                        font.pixelSize: panel.fontM
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Codes.temp(hour.modelData.temp)
                    }
                }
            }
        }

        // Карточки дней
        Repeater {
            model: panel.days

            WeatherCard {
                id: day
                required property var modelData
                required property int index
                readonly property bool open: panel.expanded === index

                Layout.fillWidth: true
                owner: panel
                blurSource: blurredSky
                interactive: true
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
                        WeatherIcon {
                            font.pixelSize: panel.px(20)
                            text: "expand_more"
                            color: panel.cardTextDim
                            rotation: day.open ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
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

                        RowLayout {
                            id: dayHours
                            y: panel.sp(Tokens.spacingMediumV)
                            width: parent.width
                            spacing: 0

                            Repeater {
                                model: day.modelData.hours

                                Column {
                                    id: slot
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: panel.sp(Tokens.spacingSmallV)

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

        WeatherText {
            Layout.alignment: Qt.AlignRight
            text: "Данные Open-Meteo"
            color: panel.fullSky ? panel.alpha(panel.white, 0.7) : panel.colors.on_surface_variant
            font.pixelSize: panel.fontS
            opacity: 0.8
        }
    }
}
