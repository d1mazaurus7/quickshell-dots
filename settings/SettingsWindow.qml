pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shell/theme"
import "pages" as Pages
import "controls"
import "../services/updater"

// Окно настроек: оверлей поверх всех окон, панель по центру экрана
PanelWindow {
    id: root

    property bool open: false

    readonly property var colors: Tokens.colors
    // Разделы: заголовок + иконка Material Symbols + страница
    readonly property var sections: [
        { title: "Шрифт", icon: "text_fields", page: fontPage },
        { title: "Интерфейс", icon: "tune", page: interfacePage },
        { title: "Бар", icon: "toolbar", page: barPage },
        { title: "Время", icon: "schedule", page: timePage },
        { title: "Секундомер", icon: "timer", page: stopwatchPage },
        { title: "Музыкальный плеер", icon: "music_note", page: musicPlayerPage },
        { title: "Рабочие столы", icon: "space_dashboard", page: workspacesPage },
        { title: "Звук", icon: "volume_up", page: soundPage },
        { title: "Уведомления", icon: "notifications", page: notificationsPage },
        { title: "Центр уведомлений", icon: "dashboard", page: notiCenterPage },
        { title: "Скриншоты", icon: "screenshot_monitor", page: screenshotPage },
        { title: "Ассистент", icon: "smart_toy", page: assistantPage },
        { title: "Новости", icon: "newspaper", page: newsPage },
        { title: "Погода", icon: "partly_cloudy_day", page: weatherPage },
        { title: "Управление питанием", icon: "power_settings_new", page: powerMenuPage },
        { title: "Управление производительностью", icon: "speed", page: performanceMenuPage },
        { title: "Лаунчер", icon: "apps", page: launcherPage },
        { title: "Буфер обмена", icon: "content_paste", page: clipboardPage },
        { title: "Обои", icon: "wallpaper", page: wallpaperPage },
        { title: "Безопасность", icon: "shield", page: securityPage },
        { title: "Лок-скрин", icon: "lock", page: lockscreenPage },
        { title: "Оболочка", icon: "terminal", page: shellPage },
        { title: "NixOS", icon: "ac_unit", page: nixosPage },
        { title: "О системе", icon: "info", page: aboutPage }
    ]
    readonly property var filteredSections: sections.filter(s =>
        s.title.toLowerCase().includes(search.text.trim().toLowerCase()))
    property string currentTitle: sections[0].title
    readonly property var currentSection: sections.find(s => s.title === currentTitle)
    readonly property int currentIndex: filteredSections.findIndex(s => s.title === currentTitle)

    // Анимации иконок разделов при выборе. Каналы ключевых кадров:
    // rot, s (масштаб), sx/sy (сплющивание/переворот), x, y, o (прозрачность);
    // top — вращение от верха, swap — другой глиф в начале, parts — иконка из частей
    readonly property var iconFx: ({
        text_fields: { sx: [1, 1.35, 0.85, 1.1, 1], sy: [1, 0.8, 1.15, 0.95, 1] },
        tune: { x: [0, -3, 3, -2, 1, 0], rot: [0, -6, 6, 0] },
        toolbar: { y: [0, -6, 0, -2, 0], sy: [1, 1.15, 0.85, 1.05, 1] },
        schedule: { rot: [0, 360] },
        timer: { rot: [0, -14, 14, -10, 10, -5, 0], top: true },
        music_note: { y: [0, -8, 0, -4, 0], rot: [0, -15, 10, -5, 0] },
        space_dashboard: { sx: [1, 0, -1, 0, 1] },
        volume_up: { x: [0, -1.5, 1.5, -1.5, 1.5, -1, 0], s: [1, 1.15, 1.1, 1] },
        notifications: { rot: [0, 18, -16, 12, -8, 4, 0], top: true },
        dashboard: { sy: [1, 0, 1], rot: [0, 0, 90, 90, 0] },
        screenshot_monitor: { o: [1, 0.15, 1, 1], s: [1, 0.88, 1.12, 1] },
        smart_toy: { rot: [0, -12, 12, -6, 0], y: [0, -3, 0, -2, 0] },
        newspaper: { sx: [1, 0.2, 1], rot: [0, -10, 0], x: [0, 4, 0] },
        partly_cloudy_day: { parts: [
            { glyph: "sunny", size: 15, ox: -4, oy: -4, x: [0, -5, -6, -5, 0], y: [0, -4, -5, -4, 0], rot: [0, 90, 180] },
            { glyph: "cloud", size: 18, ox: 2, oy: 3, x: [0, 4, 5, 4, 0], y: [0, 2, 3, 2, 0] }
        ] },
        power_settings_new: { s: [1, 0.7, 1.25, 1], o: [1, 0.4, 1, 1] },
        speed: { rot: [0, -40, 30, -10, 0] },
        apps: { rot: [0, 90, 180], s: [1, 0.75, 1] },
        content_paste: { y: [0, -10, 2, 0], rot: [0, -10, 6, 0] },
        wallpaper: { s: [1, 1.2, 0.95, 1], rot: [0, 8, -4, 0] },
        shield: { s: [1, 1.25, 1], rot: [0, -12, 12, 0] },
        lock: { swap: "lock_open", swapAt: 0.45, y: [0, -3, -3, 1, 0], s: [1, 1, 1, 1.15, 1] },
        terminal: { o: [1, 0, 1, 0, 1], x: [0, 2, 0] },
        ac_unit: { rot: [0, 180], s: [1, 1.2, 1] },
        info: { y: [0, -7, 0, -3, 0] },
        _default: { s: [1, 1.3, 0.92, 1.05, 1] }
    })

    // Линейная интерполяция по ключевым кадрам
    function frame(frames, t) {
        const n = frames.length - 1;
        const p = Math.max(0, Math.min(n, t * n));
        const i = Math.floor(p);
        return i >= n ? frames[n] : frames[i] + (frames[i + 1] - frames[i]) * (p - i);
    }

    // Переход по разделам стрелками (в пределах отфильтрованного списка)
    function moveSection(delta) {
        const n = filteredSections.length;
        if (n === 0)
            return;
        const i = currentIndex < 0 ? (delta > 0 ? 0 : n - 1)
                : Math.max(0, Math.min(n - 1, currentIndex + delta));
        currentTitle = filteredSections[i].title;
    }

    WlrLayershell.namespace: "qs:settings"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive: Esc работает сразу, без клика по окну
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: open || fade.running

    Component { id: fontPage; Pages.FontPage {} }
    Component { id: interfacePage; Pages.InterfacePage {} }
    Component { id: barPage; Pages.BarPage {} }
    Component { id: timePage; Pages.TimePage {} }
    Component { id: stopwatchPage; Pages.StopwatchPage {} }
    Component { id: musicPlayerPage; Pages.MusicPlayerPage {} }
    Component { id: workspacesPage; Pages.WorkspacesPage {} }
    Component { id: soundPage; Pages.SoundPage {} }
    Component { id: notificationsPage; Pages.NotificationsPage {} }
    Component { id: notiCenterPage; Pages.NotiCenterPage {} }
    Component { id: screenshotPage; Pages.ScreenshotPage {} }
    Component { id: assistantPage; Pages.AssistantPage {} }
    Component { id: newsPage; Pages.NewsPage {} }
    Component { id: weatherPage; Pages.WeatherPage {} }
    Component { id: powerMenuPage; Pages.PowerMenuPage {} }
    Component { id: performanceMenuPage; Pages.PerformanceMenuPage {} }
    Component { id: launcherPage; Pages.LauncherPage {} }
    Component { id: clipboardPage; Pages.ClipboardPage {} }
    Component { id: wallpaperPage; Pages.WallpaperPage {} }
    Component { id: securityPage; Pages.SecurityPage {} }
    Component { id: lockscreenPage; Pages.LockscreenPage {} }
    Component { id: aboutPage; Pages.AboutPage {} }
    Component { id: shellPage; Pages.ShellPage { updater: shellUpdater } }
    Component { id: nixosPage; Pages.NixosPage { updater: nixosUpdater } }

    NixosUpdater {
        id: nixosUpdater
    }

    // Обновление оболочки; после установки окно открывается на разделе «Оболочка»
    Updater {
        id: shellUpdater
        onInstalledOnStart: {
            root.currentTitle = "Оболочка";
            root.open = true;
        }
    }

    onOpenChanged: {
        if (!open && shellUpdater.status === "installed")
            shellUpdater.status = "idle";
        if (!open && nixosUpdater.status === "installed")
            nixosUpdater.status = "idle";
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.open = false
    }

    Shortcut {
        sequence: "Up"
        enabled: root.open
        onActivated: root.moveSection(-1)
    }

    Shortcut {
        sequence: "Down"
        enabled: root.open
        onActivated: root.moveSection(1)
    }

    // Затемнение фона, клик закрывает окно
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.colors.background.r, root.colors.background.g, root.colors.background.b, 0.5)
        opacity: root.open ? 1 : 0
        Behavior on opacity {
            NumberAnimation { id: fade; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }
    }

    // M3: окно — surface_container, слева навигация, справа отдельная панель контента
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(Tokens.scaled(1000), parent.width - 64)
        height: Math.min(Tokens.scaled(640), parent.height - 64)
        radius: Tokens.radiusLarge * 2
        color: root.colors.surface_container
        border.width: Tokens.borderWidth
        border.color: root.colors.outline_variant
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

        // Клики по панели не доходят до затемнения
        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Tokens.spacingMedium
            spacing: Tokens.spacingMedium

            // Слева: заголовок, поиск, разделы
            ColumnLayout {
                // Фиксированная ширина: fillWidth дочерних элементов
                // иначе растягивает колонку на всё окно
                Layout.fillWidth: false
                Layout.preferredWidth: Tokens.scaled(260)
                Layout.maximumWidth: Tokens.scaled(260)
                Layout.fillHeight: true
                Layout.topMargin: Tokens.spacingMediumV
                spacing: Tokens.spacingMediumV

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.spacingLarge
                    spacing: Tokens.spacingSmall

                    Text {
                        Layout.fillWidth: true
                        text: "Настройки"
                        color: root.colors.on_surface
                        font.family: Tokens.fontLarge.family
                        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(6)
                        elide: Text.ElideRight
                    }

                    // Icon button: закрыть
                    Rectangle {
                        implicitWidth: Tokens.scaled(40)
                        implicitHeight: implicitWidth
                        radius: closeArea.pressed ? Tokens.radiusMedium : width / 2
                        color: closeArea.pressed ? Qt.alpha(root.colors.on_surface, 0.10)
                             : closeArea.containsMouse ? Qt.alpha(root.colors.on_surface, 0.08)
                             : "transparent"
                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                        Behavior on radius { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.colors.on_surface_variant
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Tokens.scaled(22)
                            rotation: closeArea.containsMouse ? 90 : 0
                            Behavior on rotation { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.open = false
                        }
                    }
                }

                // Поиск по разделам
                Rectangle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacingSmallV
                    implicitHeight: Tokens.scaled(48)
                    radius: search.activeFocus ? Tokens.radiusLarge : height / 2
                    color: root.colors.surface_container_highest
                    border.width: search.activeFocus ? 2 : 0
                    border.color: root.colors.primary
                    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    // State layer
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: root.colors.on_surface
                        opacity: searchArea.containsMouse && !search.activeFocus ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                    }

                    MouseArea {
                        id: searchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: search.forceActiveFocus()
                    }

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.spacingLarge
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: search.activeFocus ? root.colors.primary : root.colors.on_surface_variant
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.scaled(22)
                        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                    }

                    TextInput {
                        id: search
                        anchors.left: searchIcon.right
                        anchors.right: clearBtn.left
                        anchors.leftMargin: Tokens.spacingMedium
                        anchors.rightMargin: Tokens.spacingSmall
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: root.colors.on_surface
                        selectionColor: root.colors.primary
                        selectedTextColor: root.colors.on_primary
                        font: Tokens.fontMedium

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Поиск..."
                            color: root.colors.on_surface_variant
                            font: Tokens.fontMedium
                            opacity: search.text === "" ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                        }
                    }

                    Rectangle {
                        id: clearBtn
                        readonly property bool shown: search.text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        width: Tokens.scaled(36)
                        height: width
                        radius: width / 2
                        color: clearArea.pressed ? Qt.alpha(root.colors.on_surface, 0.10)
                             : clearArea.containsMouse ? Qt.alpha(root.colors.on_surface, 0.08)
                             : "transparent"
                        opacity: shown ? 1 : 0
                        scale: shown ? 1 : 0.5
                        visible: opacity > 0
                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                        Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.colors.on_surface_variant
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Tokens.scaled(18)
                            rotation: clearArea.containsMouse ? 90 : 0
                            Behavior on rotation { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                search.text = "";
                                search.forceActiveFocus();
                            }
                        }
                    }
                }

                // Navigation drawer: пункты-пилюли, общий индикатор
                // переезжает с пункта на пункт; прокручивается, если не помещается
                Flickable {
                    id: sectionList

                    readonly property real itemHeight: Tokens.scaled(48)
                    readonly property real step: itemHeight + Tokens.spacingSmallV
                    readonly property int current: root.currentIndex

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: Math.max(0, root.filteredSections.length * step - Tokens.spacingSmallV)

                    // Выбранный пункт всегда в видимой области; прокрутка синхронна
                    // с переездом индикатора, иначе он дёргается
                    onCurrentChanged: {
                        if (current < 0)
                            return;
                        const top = current * step;
                        // При быстрых нажатиях считаем от конечной точки текущей прокрутки
                        const base = scrollAnim.running ? scrollAnim.to : contentY;
                        let target = base;
                        if (top < base)
                            target = top;
                        else if (top + itemHeight > base + height)
                            target = top + itemHeight - height;
                        if (target !== contentY) {
                            scrollAnim.to = target;
                            scrollAnim.restart();
                        }
                    }

                    NumberAnimation {
                        id: scrollAnim
                        target: sectionList
                        property: "contentY"
                        duration: Tokens.animationMedium
                        easing.type: Easing.OutCubic
                    }

                    // Active indicator
                    Rectangle {
                        y: root.currentIndex * sectionList.step
                        width: sectionList.width
                        height: sectionList.itemHeight
                        visible: root.currentIndex >= 0
                        radius: height / 2
                        color: root.colors.secondary_container
                        Behavior on y { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                    }

                    Repeater {
                        model: root.filteredSections

                        Item {
                            id: item
                            required property var modelData
                            required property int index
                            readonly property bool active: root.currentIndex === index

                            y: index * sectionList.step
                            width: sectionList.width
                            height: sectionList.itemHeight

                            // State layer
                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: item.active ? root.colors.on_secondary_container : root.colors.on_surface
                                opacity: area.pressed ? 0.10 : area.containsMouse ? 0.08 : 0
                                Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                            }

                            onActiveChanged: if (active) fxAnim.restart()

                            // Обёртка под анимацию выбора, чтобы не конфликтовать с hover/press-масштабом
                            Item {
                                id: navIcon
                                readonly property var fx: root.iconFx[item.modelData.icon] || root.iconFx._default
                                property real t: 1
                                readonly property bool playing: t < 1

                                function ch(frames, def) {
                                    return frames ? root.frame(frames, t) : def;
                                }

                                anchors.left: parent.left
                                anchors.leftMargin: Tokens.spacingLarge
                                anchors.verticalCenter: parent.verticalCenter
                                width: iconGlyph.implicitWidth
                                height: iconGlyph.implicitHeight
                                transformOrigin: fx.top ? Item.Top : Item.Center
                                rotation: ch(fx.rot, 0)
                                scale: ch(fx.s, 1)
                                opacity: ch(fx.o, 1)
                                transform: [
                                    Scale {
                                        origin.x: navIcon.width / 2
                                        origin.y: navIcon.height / 2
                                        xScale: navIcon.ch(navIcon.fx.sx, 1)
                                        yScale: navIcon.ch(navIcon.fx.sy, 1)
                                    },
                                    Translate {
                                        x: navIcon.ch(navIcon.fx.x, 0)
                                        y: navIcon.ch(navIcon.fx.y, 0)
                                    }
                                ]

                                NumberAnimation {
                                    id: fxAnim
                                    target: navIcon
                                    property: "t"
                                    from: 0
                                    to: 1
                                    duration: Tokens.animationSlow * 2
                                    easing.type: Easing.OutSine
                                }

                                // Составная иконка (погода): части расходятся и сходятся
                                Repeater {
                                    model: navIcon.fx.parts || []

                                    Text {
                                        required property var modelData

                                        visible: navIcon.playing
                                        x: (navIcon.width - implicitWidth) / 2 + Tokens.scaled(modelData.ox) + navIcon.ch(modelData.x, 0)
                                        y: (navIcon.height - implicitHeight) / 2 + Tokens.scaled(modelData.oy) + navIcon.ch(modelData.y, 0)
                                        rotation: navIcon.ch(modelData.rot, 0)
                                        text: modelData.glyph
                                        color: iconGlyph.color
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: Tokens.scaled(modelData.size)
                                    }
                                }

                                Text {
                                    id: iconGlyph
                                    text: navIcon.fx.swap && navIcon.t < navIcon.fx.swapAt ? navIcon.fx.swap : item.modelData.icon
                                    opacity: navIcon.fx.parts && navIcon.playing ? 0 : 1
                                    color: item.active ? root.colors.on_secondary_container : root.colors.on_surface_variant
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: Tokens.scaled(22)
                                    scale: area.pressed ? 0.85 : item.active ? 1.1 : 1
                                    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                                    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                                }
                            }

                            Text {
                                anchors.left: navIcon.right
                                anchors.right: parent.right
                                anchors.leftMargin: Tokens.spacingMedium + Tokens.spacingSmall
                                anchors.rightMargin: Tokens.spacingLarge
                                anchors.verticalCenter: parent.verticalCenter
                                text: item.modelData.title
                                elide: Text.ElideRight
                                color: item.active ? root.colors.on_secondary_container : root.colors.on_surface_variant
                                font: Tokens.fontMedium
                                Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                            }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTitle = item.modelData.title
                            }
                        }
                    }
                }
            }

            // Справа: панель контента — отдельная поверхность с M3-фигурами на фоне
            Rectangle {
                id: contentPane
                // Порядковый номер раздела (не зависит от поиска): фигуры поворачиваются при смене раздела
                readonly property int turn: root.sections.indexOf(root.currentSection)

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: panel.radius - Tokens.spacingMedium
                color: root.colors.surface_container_low
                clip: true

                // Размытая копия фона для полупрозрачных карточек (controls/CardBackdrop):
                // карточки берут из неё свой участок. Лежит под чётким слоем и не видна сама
                property Item cardBackdrop: Tokens.appearance.cardBlur ? blurredDecor : null

                MultiEffect {
                    id: blurredDecor
                    anchors.fill: parent
                    visible: Tokens.appearance.cardBlur
                    source: decorLayer
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1
                    blurMax: 32
                }

                Item {
                    id: decorLayer
                    anchors.fill: parent

                    // Фон в слое: размытая копия непрозрачна и закрывает чёткие фигуры под карточками
                    Rectangle {
                        anchors.fill: parent
                        radius: contentPane.radius
                        color: contentPane.color
                    }

                    M3ShapeField {
                        anchors.fill: parent
                        index: contentPane.turn
                        running: root.visible
                    }
                }

                Flickable {
                    id: content
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacingLarge
                    anchors.rightMargin: Tokens.spacingSmall
                    anchors.topMargin: Tokens.spacingLargeV
                    anchors.bottomMargin: Tokens.spacingLargeV
                    clip: true
                    contentHeight: page.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        id: scrollBar
                        contentItem: Rectangle {
                            implicitWidth: scrollBar.hovered || scrollBar.pressed ? 6 : 4
                            radius: width / 2
                            color: scrollBar.pressed ? root.colors.primary : root.colors.outline
                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                            Behavior on implicitWidth { NumberAnimation { duration: Tokens.animationFast } }
                        }
                    }

                    Loader {
                        id: page
                        width: content.width - scrollBar.width - Tokens.spacingMedium
                        sourceComponent: root.currentSection ? root.currentSection.page : null

                        // Новая страница сразу подменяется и плавно проявляется с небольшим сдвигом
                        onSourceComponentChanged: {
                            content.contentY = 0;
                            pageAppear.restart();
                        }

                        ParallelAnimation {
                            id: pageAppear
                            NumberAnimation {
                                target: page; property: "opacity"; from: 0; to: 1
                                duration: Tokens.animationMedium; easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: page; property: "y"; from: Tokens.spacingLargeV; to: 0
                                duration: Tokens.animationSlow; easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
