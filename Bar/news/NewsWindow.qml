pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../shell/config"
import "../../shell/theme"

// Лента новостей: панель выезжает от левого или правого края экрана (news.side).
// Сверху — фильтр по темам, ниже — прокручиваемый список; клик открывает ссылку в браузере.
PanelWindow {
    id: root

    required property NewsState news
    property bool open: false

    readonly property var cfg: Config.options.news
    readonly property var colors: Tokens.colors
    readonly property bool rightSide: cfg.side === "right"

    readonly property int panelWidth: Tokens.scaled(cfg.width)
    readonly property int padding: Tokens.spacingMedium + Tokens.spacingSmall
    readonly property int panelHeight: (height - Tokens.spacingMediumV * 2) * cfg.heightRatio

    // Ключ выбранной темы ("" — все); пропавшая из настроек тема сбрасывается
    property string filter: ""
    readonly property var topics: [{ key: "", title: "Все" }].concat(news.topics)
    onTopicsChanged: if (!topics.some(t => t.key === filter)) filter = ""
    readonly property var shownItems: filter === "" ? news.items : news.items.filter(i => i.topic === filter)

    // «N мин назад» обновляется раз в минуту, пока окно открыто
    property double now: Date.now()
    Timer {
        interval: 60000
        repeat: true
        running: root.open
        onTriggered: root.now = Date.now()
    }
    onOpenChanged: if (open) now = Date.now()

    // Доля выезда: 0 — скрыто, 1 — открыто
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

    visible: open || reveal > 0
    color: "transparent"
    implicitWidth: panelWidth + Tokens.spacingMedium * 2

    anchors {
        top: true
        bottom: true
        left: !root.rightSide
        right: root.rightSide
    }

    WlrLayershell.namespace: "qs:news"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Под баром: окно уважает его зону, свою не резервирует
    exclusionMode: ExclusionMode.Normal

    mask: Region { item: panel }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.open = false
    }

    Rectangle {
        id: panel

        // Сдвиг за край экрана при закрытии
        readonly property real hidden: (1 - root.reveal) * (root.panelWidth + Tokens.spacingMedium)

        x: root.rightSide ? Tokens.spacingMedium + hidden : Tokens.spacingMedium - hidden
        y: (root.height - height) / 2
        width: root.panelWidth
        height: root.panelHeight
        opacity: root.reveal
        radius: Tokens.radius(24)
        color: root.colors.background
        border.width: Tokens.borderWidth
        border.color: root.colors.outline_variant
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.padding
            spacing: Tokens.spacingMediumV

            // Шапка: заголовок, время обновления, кнопка обновления
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacingMedium

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.spacingSmall
                    spacing: 0

                    Text {
                        text: "Новости"
                        color: root.colors.on_surface
                        font.family: Tokens.fontLarge.family
                        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(6)
                    }

                    Text {
                        visible: root.news.lastUpdate > 0
                        text: "Обновлено в " + Qt.formatDateTime(new Date(root.news.lastUpdate), "HH:mm")
                        color: root.colors.on_surface_variant
                        font: Tokens.fontSmall
                    }
                }

                Rectangle {
                    implicitWidth: Tokens.scaled(40)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: refreshArea.pressed ? root.colors.surface_container_highest
                         : refreshArea.containsMouse ? root.colors.surface_container_high
                         : root.colors.surface_container
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        color: root.colors.on_surface
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.scaled(22)

                        // Вращение, пока идёт загрузка; останавливается в исходном положении
                        RotationAnimation on rotation {
                            running: root.news.loading
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
                        onClicked: root.news.refresh()
                    }
                }
            }

            // Фильтр по темам
            ListView {
                id: chips
                Layout.fillWidth: true
                implicitHeight: Tokens.scaled(34)
                visible: root.news.topics.length > 1
                orientation: ListView.Horizontal
                spacing: Tokens.spacingSmall
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.topics

                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool selected: root.filter === modelData.key

                    implicitWidth: chipText.implicitWidth + Tokens.spacingLarge * 2
                    height: chips.height
                    radius: height / 2
                    color: selected ? root.colors.secondary_container
                         : chipArea.pressed ? root.colors.surface_container_highest
                         : chipArea.containsMouse ? root.colors.surface_container_high
                         : root.colors.surface_container
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData.title
                        textFormat: Text.PlainText
                        color: chip.selected ? root.colors.on_secondary_container : root.colors.on_surface
                        font: Tokens.fontSmall
                    }

                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.filter = chip.modelData.key
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacingSmallV
                boundsBehavior: Flickable.StopAtBounds
                model: root.shownItems
                onModelChanged: positionViewAtBeginning()

                delegate: NewsCard {
                    required property var modelData
                    width: list.width
                    item: modelData
                    now: root.now
                    onClicked: Qt.openUrlExternally(modelData.link)
                }

                // Пустой список: загрузка, ошибка, нет тем или нет новостей
                Text {
                    anchors.centerIn: parent
                    width: parent.width - Tokens.spacingLarge * 2
                    opacity: list.count === 0 ? 1 : 0
                    visible: opacity > 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.news.sources.length === 0 ? "Выбери темы: Настройки → Новости"
                        : root.news.loading ? "Загрузка…"
                        : root.news.error !== "" ? root.news.error
                        : "Новостей нет"
                    color: root.news.error !== "" && !root.news.loading ? root.colors.error : root.colors.on_surface_variant
                    font: Tokens.fontMedium
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
                }
            }
        }
    }
}
