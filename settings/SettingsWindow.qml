pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shell/theme"
import "pages" as Pages
import "../services/updater"

// Окно настроек: оверлей поверх всех окон, панель по центру экрана
PanelWindow {
    id: root

    property bool open: false

    readonly property var colors: Tokens.colors
    // Разделы: заголовок + страница
    readonly property var sections: [
        { title: "Шрифт", page: fontPage },
        { title: "Интерфейс", page: interfacePage },
        { title: "Бар", page: barPage },
        { title: "Время", page: timePage },
        { title: "Секундомер", page: stopwatchPage },
        { title: "Музыкальный плеер", page: musicPlayerPage },
        { title: "Рабочие столы", page: workspacesPage },
        { title: "Звук", page: soundPage },
        { title: "Уведомления", page: notificationsPage },
        { title: "Центр уведомлений", page: notiCenterPage },
        { title: "Скриншоты", page: screenshotPage },
        { title: "Ассистент", page: assistantPage },
        { title: "Оболочка", page: shellPage },
        { title: "О системе", page: aboutPage }
    ]
    readonly property var filteredSections: sections.filter(s =>
        s.title.toLowerCase().includes(search.text.trim().toLowerCase()))
    property string currentTitle: sections[0].title
    readonly property var currentSection: sections.find(s => s.title === currentTitle)
    readonly property int currentIndex: filteredSections.findIndex(s => s.title === currentTitle)

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
    Component { id: aboutPage; Pages.AboutPage {} }
    Component { id: shellPage; Pages.ShellPage { updater: shellUpdater } }

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

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(Tokens.scaled(1000), parent.width - 64)
        height: Math.min(Tokens.scaled(640), parent.height - 64)
        radius: Tokens.radiusLarge
        color: root.colors.surface
        border.width: Tokens.borderWidth
        border.color: root.colors.outline_variant
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

        // Клики по панели не доходят до затемнения
        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacingLarge
            anchors.rightMargin: Tokens.spacingLarge
            anchors.topMargin: Tokens.spacingLargeV
            anchors.bottomMargin: Tokens.spacingLargeV
            spacing: Tokens.spacingLarge

            // Слева: заголовок, поиск, разделы
            ColumnLayout {
                // Фиксированная ширина: fillWidth дочерних элементов
                // иначе растягивает колонку на всё окно
                Layout.fillWidth: false
                Layout.preferredWidth: Tokens.scaled(240)
                Layout.maximumWidth: Tokens.scaled(240)
                Layout.fillHeight: true
                spacing: Tokens.spacingMediumV

                Text {
                    Layout.leftMargin: Tokens.spacingMedium
                    text: "Настройки"
                    color: root.colors.on_surface
                    font.family: Tokens.fontLarge.family
                    font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
                }

                // Поиск по разделам
                Rectangle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Tokens.spacingMediumV
                    implicitHeight: search.implicitHeight + Tokens.spacingMediumV * 2
                    radius: height / 2
                    color: root.colors.surface_container_highest
                    border.width: search.activeFocus ? 1 : 0
                    border.color: root.colors.primary

                    TextInput {
                        id: search
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacingLarge
                        anchors.rightMargin: Tokens.spacingLarge
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: root.colors.on_surface
                        selectionColor: root.colors.primary
                        selectedTextColor: root.colors.on_primary
                        font: Tokens.fontMedium

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !search.text
                            text: "Поиск..."
                            color: root.colors.on_surface_variant
                            font: Tokens.fontMedium
                        }
                    }
                }

                // Список разделов: фоны пунктов, под текстом — общее выделение,
                // которое переезжает с пункта на пункт; прокручивается, если не помещается
                Flickable {
                    id: sectionList

                    readonly property real itemHeight: Tokens.scaled(48)
                    readonly property real step: itemHeight + Tokens.spacingMediumV
                    readonly property int current: root.currentIndex

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: Math.max(0, root.filteredSections.length * step - Tokens.spacingMediumV)

                    // Выбранный пункт всегда в видимой области; прокрутка синхронна
                    // с переездом выделения, иначе оно дёргается
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

                    Repeater {
                        model: root.filteredSections

                        Rectangle {
                            id: item
                            required property var modelData
                            required property int index

                            y: index * sectionList.step
                            width: sectionList.width
                            height: sectionList.itemHeight
                            radius: Tokens.radiusLarge
                            color: area.pressed ? root.colors.surface_container_highest
                                 : area.containsMouse ? root.colors.surface_container_high
                                 : root.colors.surface_container
                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTitle = item.modelData.title
                            }
                        }
                    }

                    Rectangle {
                        y: root.currentIndex * sectionList.step
                        width: sectionList.width
                        height: sectionList.itemHeight
                        visible: root.currentIndex >= 0
                        radius: Tokens.radiusLarge
                        color: root.colors.secondary_container
                        Behavior on y { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                    }

                    Repeater {
                        model: root.filteredSections

                        Text {
                            id: label
                            required property var modelData
                            required property int index

                            x: Tokens.spacingLarge
                            y: index * sectionList.step + (sectionList.itemHeight - height) / 2
                            text: label.modelData.title
                            color: root.currentIndex === label.index ? root.colors.on_secondary_container : root.colors.on_surface
                            font: Tokens.fontMedium
                            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                        }
                    }
                }
            }

            // Разделитель
            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: root.colors.outline_variant
            }

            // Справа: настройки раздела
            Flickable {
                id: content
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: page.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    id: scrollBar
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: scrollBar.pressed ? root.colors.primary : root.colors.outline
                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
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
                            target: page; property: "y"; from: Tokens.spacingMediumV; to: 0
                            duration: Tokens.animationMedium; easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
