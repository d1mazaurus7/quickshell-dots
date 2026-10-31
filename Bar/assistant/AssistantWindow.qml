pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme" as Theme
import "../../shell/config"
import "../../shell/theme"

// Окно чата: выезжает от левого или правого края экрана (assistant.side).
// У края вогнутые скругления ("уши") плавно переходят в рамку экрана.
PanelWindow {
    id: root

    required property AssistantState chat
    property bool open: false

    readonly property var cfg: Config.options.assistant
    readonly property var colors: Tokens.colors
    readonly property bool rightSide: cfg.side === "right"

    readonly property int panelWidth: Tokens.scaled(cfg.width)
    // Шрифты окна: базовый размер из assistant.fontSize
    readonly property font fontSmall: Qt.font({ family: Tokens.fontMedium.family, pixelSize: Tokens.scaled(cfg.fontSize - 2) })
    readonly property font fontMedium: Qt.font({ family: Tokens.fontMedium.family, pixelSize: Tokens.scaled(cfg.fontSize) })
    readonly property int padding: Tokens.spacingMedium + Tokens.spacingSmall
    readonly property int earRadius: Tokens.radius(24)
    readonly property int cornerRadius: Tokens.radius(24)
    // Тело окна по вертикали; уши — над и под ним
    // по центру экрана, высота — доля доступной (assistant.heightRatio)
    readonly property real bodyHeight: (height - (Tokens.spacingMediumV + earRadius) * 2) * cfg.heightRatio
    readonly property real bodyTop: (height - bodyHeight) / 2
    readonly property real bodyBottom: bodyTop + bodyHeight

    // Видимая ширина: от края экрана к panelWidth
    property real reveal: open ? panelWidth : 0
    Behavior on reveal { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

    visible: open || reveal > 0
    color: "transparent"
    implicitWidth: panelWidth

    anchors {
        top: true
        bottom: true
        left: !root.rightSide
        right: root.rightSide
    }

    WlrLayershell.namespace: "qs:assistant"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // Под баром: окно уважает его зону, свою не резервирует
    exclusionMode: ExclusionMode.Normal

    mask: Region { item: maskItem }

    onOpenChanged: {
        historyMode = false;
        if (open)
            Qt.callLater(() => input.forceActiveFocus());
    }

    // Список сохранённых чатов над полем ввода; текст поля — фильтр
    property bool historyMode: false
    readonly property var historyItems: {
        const files = chat.historyFiles;
        const filter = input.text.trim().toLowerCase();
        const list = [];
        for (let i = 0; i < files.count; i++) {
            // Имя файла: "yyyy-MM-dd_HH-mm-ss <первое сообщение>"
            const title = files.get(i, "fileBaseName").slice(20);
            if (title.toLowerCase().includes(filter))
                list.push({
                    title: title,
                    detail: Qt.formatDateTime(files.get(i, "fileModified"), "dd.MM.yy HH:mm"),
                    path: files.get(i, "filePath")
                });
        }
        return list;
    }
    // Автодополнение: текст начинается с "/" и ещё без пробела
    readonly property var commandItems: input.text.startsWith("/") && !input.text.includes(" ")
        ? chat.commands.filter(c => c.name.startsWith(input.text)).map(c => ({ title: c.name, detail: c.description }))
        : []
    readonly property bool popupOpen: historyMode || commandItems.length > 0
    readonly property var popupItems: historyMode ? historyItems : commandItems
    onPopupItemsChanged: suggestions.currentIndex = 0

    Connections {
        target: root.chat
        function onHistoryRequested(): void { root.historyMode = true; }
    }

    function pick(index: int): void {
        const item = popupItems[index];
        if (!item)
            return;
        if (historyMode) {
            historyMode = false;
            input.text = "";
            chat.load(item.path);
        } else {
            input.text = item.title;
            sendMessage();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open && !root.popupOpen
        onActivated: root.open = false
    }

    // Звук печати как в лаунчере
    Process {
        id: typeSound
        command: ["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.typeSound)]
    }

    function sendMessage(): void {
        if (chat.send(input.text))
            input.text = "";
    }

    Item {
        id: maskItem
        x: root.rightSide ? root.width - root.reveal : 0
        y: root.bodyTop - root.earRadius
        width: root.reveal
        height: root.bodyBottom - root.bodyTop + root.earRadius * 2
    }

    // Фон: вогнутые уши у края экрана, обычные углы с внутренней стороны.
    // Нарисован для левого края и зеркалится для правого.
    Shape {
        anchors.fill: parent
        visible: root.reveal > 0.5
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.x: root.width / 2; xScale: root.rightSide ? -1 : 1 }

        ShapePath {
            id: bg

            readonly property real w: root.reveal
            readonly property real top: root.bodyTop
            readonly property real bottom: root.bodyBottom
            readonly property real er: root.earRadius
            readonly property real erX: Math.min(er, w / 2)
            readonly property real br: root.cornerRadius
            readonly property real brX: Math.min(br, w / 2)

            strokeWidth: -1
            fillColor: Theme.Palette.background

            startX: 0; startY: bg.top - bg.er
            PathArc { x: bg.erX; y: bg.top; radiusX: bg.erX; radiusY: bg.er; direction: PathArc.Counterclockwise }
            PathLine { x: bg.w - bg.brX; y: bg.top }
            PathArc { x: bg.w; y: bg.top + bg.br; radiusX: bg.brX; radiusY: bg.br }
            PathLine { x: bg.w; y: bg.bottom - bg.br }
            PathArc { x: bg.w - bg.brX; y: bg.bottom; radiusX: bg.brX; radiusY: bg.br }
            PathLine { x: bg.erX; y: bg.bottom }
            PathArc { x: 0; y: bg.bottom + bg.er; radiusX: bg.erX; radiusY: bg.er; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: bg.top - bg.er }
        }
    }

    // Видимая часть тела; содержимое выезжает вместе с ним
    Item {
        x: root.rightSide ? root.width - root.reveal : 0
        y: root.bodyTop
        width: root.reveal
        height: root.bodyBottom - root.bodyTop
        clip: true

        ColumnLayout {
            x: (root.rightSide ? 0 : root.reveal - root.panelWidth) + root.padding
            y: root.padding
            width: root.panelWidth - root.padding * 2
            height: parent.height - root.padding * 2
            opacity: root.reveal / root.panelWidth
            spacing: Tokens.spacingMediumV

            // Шапка: аватар, имя, описание
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Tokens.scaled(72)
                radius: Tokens.radiusLarge
                color: root.colors.surface_container_high

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.spacingMedium
                    anchors.rightMargin: Tokens.spacingLarge
                    spacing: Tokens.spacingMedium

                    Item {
                        implicitWidth: Tokens.scaled(54)
                        implicitHeight: implicitWidth

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.colors.secondary_container

                            Text {
                                anchors.centerIn: parent
                                visible: root.cfg.avatar === ""
                                text: root.cfg.name.charAt(0).toUpperCase()
                                color: root.colors.on_secondary_container
                                font.family: Tokens.fontLarge.family
                                font.pixelSize: Tokens.scaled(24)
                            }

                            Image {
                                anchors.fill: parent
                                visible: root.cfg.avatar !== ""
                                source: visible ? "file://" + Quickshell.shellPath("assets/img/avatars/" + root.cfg.avatar) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        // Статус: в сети, если задан ключ
                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: Tokens.scaled(14)
                            height: width
                            radius: width / 2
                            color: root.cfg.apiKey !== "" && root.chat.status !== "error" ? Theme.Palette.ok : root.colors.error
                            border.width: Tokens.scaled(2)
                            border.color: root.colors.surface_container_high
                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.cfg.name
                            color: root.colors.on_surface
                            font.family: root.fontMedium.family
                            font.pixelSize: root.fontMedium.pixelSize + Tokens.scaled(8)
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.cfg.description
                            color: root.colors.on_surface_variant
                            font: root.fontSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacingMediumV
                boundsBehavior: Flickable.StopAtBounds
                // Сколько сообщений уже показано: пересозданные при прокрутке не анимируются
                property int shown: 0
                model: root.chat.messages
                onCountChanged: Qt.callLater(() => { positionViewAtEnd(); shown = count; })
                onHeightChanged: positionViewAtEnd()

                delegate: MessageBubble {
                    required property int index
                    width: list.width
                    textFont: root.fontMedium
                    smallFont: root.fontSmall
                    animate: index >= list.shown
                }

                Text {
                    anchors.centerIn: parent
                    opacity: list.count === 0 ? 1 : 0
                    visible: opacity > 0
                    text: "Начни диалог с " + root.cfg.name
                    color: root.colors.on_surface_variant
                    font: root.fontMedium
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
                }
            }

            // "Печатает…": плавно разворачивается, пока ждём ответ
            Item {
                Layout.fillWidth: true
                implicitHeight: root.chat.typing ? typingRow.implicitHeight : 0
                opacity: root.chat.typing ? 1 : 0
                visible: opacity > 0
                Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }

                Row {
                    id: typingRow
                    x: Tokens.spacingSmall
                    spacing: Tokens.spacingSmall

                    Repeater {
                        model: 3

                        Rectangle {
                            id: dot
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: Tokens.scaled(5)
                            height: width
                            radius: width / 2
                            color: root.colors.on_surface_variant
                            opacity: 0.3

                            SequentialAnimation on opacity {
                                running: root.chat.typing
                                loops: Animation.Infinite
                                PauseAnimation { duration: dot.index * 150 }
                                NumberAnimation { to: 1; duration: 300; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.3; duration: 300; easing.type: Easing.InOutSine }
                                PauseAnimation { duration: (2 - dot.index) * 150 }
                            }
                        }
                    }

                    Text {
                        text: "Печатает"
                        color: root.colors.on_surface_variant
                        font: root.fontSmall
                    }
                }
            }

            SuggestionList {
                id: suggestions
                Layout.fillWidth: true
                shown: root.popupOpen
                items: root.popupItems
                emptyText: input.text.trim() === "" ? "История пуста" : "Ничего не найдено"
                textFont: root.fontMedium
                smallFont: root.fontSmall
                onPicked: index => root.pick(index)
            }

            // Поле ввода и кнопка отправки
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacingMedium

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.scaled(42)
                    radius: height / 2
                    color: inputArea.containsMouse && !input.activeFocus ? root.colors.surface_container_highest : root.colors.surface_container_high
                    border.width: input.activeFocus ? 2 : 0
                    border.color: root.colors.primary
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                    MouseArea {
                        id: inputArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: input.forceActiveFocus()
                    }

                    TextInput {
                        id: input
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Tokens.spacingLarge
                        anchors.rightMargin: Tokens.spacingLarge
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.colors.on_surface
                        selectionColor: root.colors.primary
                        selectedTextColor: root.colors.on_primary
                        font: root.fontMedium
                        clip: true
                        selectByMouse: true
                        onTextEdited: typeSound.running = true

                        Keys.onReturnPressed: root.popupOpen ? root.pick(suggestions.currentIndex) : root.sendMessage()
                        Keys.onEnterPressed: root.popupOpen ? root.pick(suggestions.currentIndex) : root.sendMessage()
                        Keys.onUpPressed: event => {
                            event.accepted = root.popupOpen;
                            if (root.popupOpen && suggestions.currentIndex > 0)
                                suggestions.currentIndex--;
                        }
                        Keys.onDownPressed: event => {
                            event.accepted = root.popupOpen;
                            if (root.popupOpen && suggestions.currentIndex < root.popupItems.length - 1)
                                suggestions.currentIndex++;
                        }
                        Keys.onTabPressed: {
                            if (root.commandItems.length > 0)
                                input.text = root.commandItems[suggestions.currentIndex].title;
                        }
                        Keys.onEscapePressed: {
                            root.historyMode = false;
                            input.text = "";
                        }

                        Text {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: root.historyMode ? "Поиск чата" : "Напиши " + root.cfg.name
                            color: root.colors.on_surface_variant
                            font: root.fontMedium
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    id: sendButton
                    readonly property bool ready: input.text.trim() !== ""

                    implicitWidth: Tokens.scaled(42)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: !ready ? root.colors.surface_container_high
                         : sendArea.pressed ? root.colors.primary_fixed_dim
                         : sendArea.containsMouse ? root.colors.primary_fixed
                         : root.colors.primary
                    scale: sendArea.pressed && ready ? 0.9 : 1
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        // nf-md-send
                        text: String.fromCodePoint(0xF048A)
                        color: sendButton.ready ? root.colors.on_primary : root.colors.on_surface_variant
                        font.family: Tokens.fontMedium.family
                        font.pixelSize: Tokens.scaled(20)
                    }

                    MouseArea {
                        id: sendArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: sendButton.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.sendMessage()
                    }
                }
            }
        }
    }
}
