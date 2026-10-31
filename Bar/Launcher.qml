import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../theme" as Theme
import "../shell/config"
import "../shell/theme"
import "../components/animations" as Flow
import "EmojiData.js" as EmojiData

PanelWindow {
    id: launcher

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            launcher.open = !launcher.open;
        }
    }

    WlrLayershell.namespace: "qs:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property bool open: false

    visible: open || slideAnim.running

    onOpenChanged: {
        if (open) {
            searchField.text = "";
            appList.positionViewAtBeginning();
            appList.currentIndex = 0;
            searchField.forceActiveFocus();
            slideAnim.from = 0;
            slideAnim.to = panel.height;
            slideAnim.restart();
        } else {
            slideAnim.from = panel.height;
            slideAnim.to = 0;
            slideAnim.restart();
        }
    }

    function closeLauncher(): void {
        open = false;
    }

    // Звук печати
    readonly property string typeSoundPath: Qt.resolvedUrl("../assets/sounds/" + Config.options.sound.typeSound).toString().replace(/^file:\/\//, "")

    function playTypeSound(): void {
        if (open) typeSoundProcess.running = true;
    }

    Process {
        id: typeSoundProcess
        command: ["pw-play", launcher.typeSoundPath]
    }

    // Режим команд: активен когда текст начинается с ">"
    property bool commandMode: searchField.text.length > 0 && searchField.text.charAt(0) === ">"

    // Команда без префикса ">"
    property string commandText: commandMode ? searchField.text.substring(1).trim() : ""

    // Система тегов: активен когда текст начинается с "/"
    property bool tagMode: searchField.text.length > 0 && searchField.text.charAt(0) === "/"

    // Текущий тег (часть после "/" до пробела)
    property string currentTag: {
        if (!tagMode) return "";
        var text = searchField.text.substring(1);
        var spaceIdx = text.indexOf(" ");
        return spaceIdx === -1 ? text.trim() : text.substring(0, spaceIdx);
    }

    // Поиск внутри тега (текст после "/tagname ")
    property string tagQuery: {
        if (!tagMode) return "";
        var text = searchField.text.substring(1);
        var spaceIdx = text.indexOf(" ");
        return spaceIdx === -1 ? "" : text.substring(spaceIdx + 1).trim();
    }

    // Поддерживаемые теги
    property bool emojiMode: tagMode && currentTag === "emoji"

    // Список тег-команд для автодополнения
    readonly property var tagCommands: [
        { tag: "emoji", description: "Поиск эмоджи" }
    ]

    // Режим автодополнения: после "/", ещё без пробела (тег ещё печатается)
    property bool tagSuggestMode: tagMode && searchField.text.substring(1).indexOf(" ") === -1

    // Отфильтрованные предложения по текущему тегу
    property var tagSuggestions: {
        if (!tagSuggestMode) return [];
        var prefix = currentTag.toLowerCase();
        var result = [];
        for (var i = 0; i < tagCommands.length; i++) {
            if (prefix === "" || tagCommands[i].tag.toLowerCase().indexOf(prefix) === 0)
                result.push(tagCommands[i]);
        }
        return result;
    }

    // Процесс для запуска команд в foot
    Process {
        id: commandProcess
        property string cmd: ""

        command: ["foot", "-e", "sh", "-c", cmd]

        onExited: (code, status) => {
            console.log("Команда завершена, код:", code);
        }
    }

    // Процесс для копирования в буфер обмена (wl-copy)
    Process {
        id: clipboardProcess
        property string content: ""

        command: ["wl-copy", content]

        onExited: (code, status) => {
            console.log("Скопировано в буфер, код:", code);
        }
    }

    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: panel

            width: 600
            height: 500

            x: (parent.width - width) / 2
            y: parent.height - panel.yOffset

            property real yOffset: height

            clip: true

            Rectangle {
                width: parent.width
                height: parent.height + 16
                color: Theme.Palette.background
                radius: Tokens.radius(16)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: Theme.Palette.surface_container
                    radius: Tokens.radius(12)

                    TextInput {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: 10
                        anchors.leftMargin: {
                            if (launcher.commandMode) return commandIndicator.width + 18;
                            return 10;
                        }
                        anchors.rightMargin: searchField.text.length > 0 ? clearBtn.width + 26 : 10
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.Palette.on_surface
                        font.family: "JetBrains Mono"
                        font.pointSize: 12
                        clip: true

                        Keys.onUpPressed: {
                            if (launcher.tagSuggestMode) {
                                if (tagList.count > 0) {
                                    if (tagList.currentIndex > 0) {
                                        tagList.decrementCurrentIndex();
                                    } else {
                                        tagList.currentIndex = tagList.count - 1;
                                    }
                                }
                            } else if (launcher.emojiMode) {
                                emojiGrid.navigateUp();
                            } else if (appList.count > 0) {
                                if (appList.currentIndex > 0) {
                                    appList.decrementCurrentIndex();
                                } else {
                                    appList.currentIndex = appList.count - 1;
                                }
                            }
                        }

                        Keys.onDownPressed: {
                            if (launcher.tagSuggestMode) {
                                if (tagList.count > 0) {
                                    if (tagList.currentIndex < tagList.count - 1) {
                                        tagList.incrementCurrentIndex();
                                    } else {
                                        tagList.currentIndex = 0;
                                    }
                                }
                            } else if (launcher.emojiMode) {
                                emojiGrid.navigateDown();
                            } else if (appList.count > 0) {
                                if (appList.currentIndex < appList.count - 1) {
                                    appList.incrementCurrentIndex();
                                } else {
                                    appList.currentIndex = 0;
                                }
                            }
                        }

                        Keys.onLeftPressed: {
                            if (launcher.emojiMode) {
                                emojiGrid.navigateLeft();
                            }
                        }

                        Keys.onRightPressed: {
                            if (launcher.emojiMode) {
                                emojiGrid.navigateRight();
                            }
                        }

                        Keys.onReturnPressed: {
                            if (launcher.commandMode) {
                                if (launcher.commandText.length > 0) {
                                    commandProcess.cmd = launcher.commandText;
                                    commandProcess.running = true;
                                    launcher.closeLauncher();
                                }
                            } else if (launcher.tagSuggestMode) {
                                tagList.completeCurrent();
                            } else if (launcher.emojiMode) {
                                emojiGrid.selectCurrent();
                            } else if (appList.currentIndex >= 0 && appList.currentItem) {
                                appList.currentItem.entry.execute();
                                launcher.closeLauncher();
                            }
                        }

                        Keys.onEscapePressed: {
                            launcher.closeLauncher();
                        }

                        Keys.onTabPressed: {
                            if (launcher.tagSuggestMode && tagList.count > 0)
                                tagList.completeCurrent();
                        }

                        Keys.onPressed: (event) => {
                            if (event.text.length > 0 || event.key === Qt.Key_Backspace) {
                                launcher.playTypeSound();
                            }
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.Palette.on_surface_variant
                            font.family: "JetBrains Mono"
                            font.pointSize: 12
                            text: "Поиск приложений... (> команда, /emoji эмоджи)"
                            visible: !searchField.text && !searchField.activeFocus
                        }

                        // Индикатор режима команд
                        Text {
                            id: commandIndicator
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.Palette.primary
                            font.family: "JetBrains Mono"
                            font.pointSize: 12
                            font.bold: true
                            text: "Выполнить команду:"
                            visible: launcher.commandMode
                        }

                        // Индикатор режима тегов
                        Text {
                            id: tagIndicator
                            visible: false
                        }
                    }

                    // Кнопка очистки строки ввода (у правого края)
                    MouseArea {
                        id: clearBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 10
                        width: 100
                        height: 24
                        hoverEnabled: true
                        visible: searchField.text.length > 0
                        cursorShape: Qt.PointingHandCursor

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius(12)
                            color: clearBtn.containsPress
                                   ? Theme.Palette.surface_container_highest
                                   : (clearBtn.containsMouse
                                      ? Theme.Palette.surface_container_highest
                                      : Theme.Palette.surface_container_high)
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Отчистить"
                            color: Theme.Palette.on_surface_variant
                            font.family: "JetBrains Mono"
                            font.pointSize: 10
                        }

                        onClicked: {
                            searchField.text = "";
                            searchField.forceActiveFocus();
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                // Подсказка в режиме команд
                Text {
                    anchors.centerIn: parent
                    color: Theme.Palette.on_surface_variant
                    font.family: "JetBrains Mono"
                    font.pointSize: 11
                    text: launcher.commandText.length === 0
                          ? "Введите команду после > и нажмите Enter"
                          : "↵  Выполнить: " + launcher.commandText
                    visible: launcher.commandMode
                    horizontalAlignment: Text.AlignHCenter
                }

                // GridView эмоджи
                GridView {
                    id: emojiGrid
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    cellWidth: 138
                    cellHeight: 72
                    clip: true
                    visible: launcher.emojiMode

                    highlight: Flow.FlowHighlight {
                        view: emojiGrid
                    }

                    model: {
                        if (!launcher.emojiMode) return [];
                        var query = launcher.tagQuery.toLowerCase();
                        var result = [];
                        var all = EmojiData.emojis;
                        for (var i = 0; i < all.length; i++) {
                            var e = all[i];
                            if (query === "") {
                                result.push(e);
                                continue;
                            }
                            if (e.name.toLowerCase().indexOf(query) !== -1) {
                                result.push(e);
                                continue;
                            }
                            var matched = false;
                            for (var k = 0; k < e.keywords.length; k++) {
                                if (e.keywords[k].toLowerCase().indexOf(query) !== -1) {
                                    matched = true;
                                    break;
                                }
                            }
                            if (matched) result.push(e);
                        }
                        return result;
                    }

                    delegate: MouseArea {
                        id: emojiDelegate
                        width: emojiGrid.cellWidth
                        height: emojiGrid.cellHeight

                        property var emojiData: modelData

                        hoverEnabled: true

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: Tokens.radius(12)
                            color: {
                                if (emojiDelegate.GridView.isCurrentItem) return "transparent";
                                if (emojiDelegate.containsMouse) return Theme.Palette.surface_container_high;
                                return Theme.Palette.surface_container;
                            }

                            Text {
                                text: emojiDelegate.emojiData.emoji
                                font.pointSize: 36
                                anchors.centerIn: parent
                            }
                        }

                        onClicked: {
                            emojiGrid.currentIndex = index;
                            emojiGrid.selectCurrent();
                        }

                        onContainsMouseChanged: {
                            if (containsMouse) {
                                emojiGrid.currentIndex = index;
                            }
                        }
                    }

                    function navigateUp(): void {
                        var cols = Math.floor(width / cellWidth);
                        if (cols <= 0) cols = 1;
                        if (currentIndex >= cols) {
                            currentIndex -= cols;
                        } else {
                            currentIndex = 0;
                        }
                        positionViewAtIndex(currentIndex, GridView.Contain);
                    }

                    function navigateDown(): void {
                        var cols = Math.floor(width / cellWidth);
                        if (cols <= 0) cols = 1;
                        var newIdx = currentIndex + cols;
                        if (newIdx < count) {
                            currentIndex = newIdx;
                        } else {
                            currentIndex = count - 1;
                        }
                        positionViewAtIndex(currentIndex, GridView.Contain);
                    }

                    function navigateLeft(): void {
                        if (currentIndex > 0) {
                            currentIndex--;
                            positionViewAtIndex(currentIndex, GridView.Contain);
                        }
                    }

                    function navigateRight(): void {
                        if (currentIndex < count - 1) {
                            currentIndex++;
                            positionViewAtIndex(currentIndex, GridView.Contain);
                        }
                    }

                    function selectCurrent(): void {
                        if (currentIndex >= 0 && currentItem) {
                            var item = currentItem.emojiData;
                            if (item) {
                                clipboardProcess.content = item.emoji;
                                clipboardProcess.running = true;
                                launcher.closeLauncher();
                            }
                        }
                    }

                    onModelChanged: {
                        currentIndex = 0;
                    }

                    Connections {
                        target: launcher
                        function onOpenChanged(): void {
                            if (launcher.open) {
                                emojiGrid.currentIndex = 0;
                            }
                        }
                    }
                }

                // Автодополнение тег-команд ("/" — список всех)
                ListView {
                    id: tagList
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    spacing: 4
                    visible: launcher.tagSuggestMode && count > 0

                    highlight: Flow.FlowHighlight {
                        view: tagList
                    }

                    model: launcher.tagSuggestions

                    onModelChanged: currentIndex = 0

                    function completeCurrent(): void {
                        if (currentIndex >= 0 && currentItem) {
                            searchField.text = "/" + currentItem.modelData.tag + " ";
                            searchField.cursorPosition = searchField.text.length;
                        }
                    }

                    delegate: MouseArea {
                        id: tagDelegate
                        x: 4
                        width: tagList.width - 8
                        height: 48

                        required property var modelData

                        hoverEnabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius(10)
                            color: tagDelegate.ListView.isCurrentItem
                                   ? "transparent"
                                   : (parent.containsMouse
                                      ? Theme.Palette.surface_container_high
                                      : Theme.Palette.surface_container)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    color: tagDelegate.ListView.isCurrentItem
                                           ? Flow.FlowHighlightAnimation.selectedTextColor
                                           : Theme.Palette.primary
                                    font.family: "JetBrains Mono"
                                    font.pointSize: 11
                                    font.bold: true
                                    text: "/" + tagDelegate.modelData.tag
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: tagDelegate.modelData.description
                                    color: tagDelegate.ListView.isCurrentItem
                                           ? Flow.FlowHighlightAnimation.selectedTextColor
                                           : Theme.Palette.on_surface_variant
                                    font.family: "JetBrains Mono"
                                    font.pointSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        onClicked: {
                            tagList.currentIndex = index;
                            tagList.completeCurrent();
                        }

                        onContainsMouseChanged: {
                            if (containsMouse) tagList.currentIndex = index;
                        }
                    }
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    spacing: 4
                    clip: false
                    visible: !launcher.commandMode && !launcher.emojiMode && !launcher.tagSuggestMode

                    highlight: Flow.FlowHighlight {
                        view: appList
                    }

                    model: {
                        if (launcher.commandMode || launcher.emojiMode) return [];
                        var query = searchField.text.toLowerCase();
                        var result = [];
                        var entries = DesktopEntries.applications.values;
                        for (var i = 0; i < entries.length; i++) {
                            var e = entries[i];
                            if (query === "" ||
                                e.name.toLowerCase().indexOf(query) !== -1 ||
                                (e.comment && e.comment.toLowerCase().indexOf(query) !== -1)) {
                                result.push(e);
                            }
                        }
                        result.sort(function(a, b) { return a.name.localeCompare(b.name); });
                        return result;
                    }

                    delegate: MouseArea {
                        id: delegateItem
                        x: 4
                        width: appList.width - 8
                        height: 48

                        property var entry: modelData

                        hoverEnabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius(10)
                            color: delegateItem.ListView.isCurrentItem
                                   ? "transparent"
                                   : (parent.containsMouse
                                      ? Theme.Palette.surface_container_high
                                      : Theme.Palette.surface_container)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Image {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    property string iconName: entry.icon || ""
                                    source: iconName ? ("image://icon/" + iconName.replace(/\.(png|svg|xpm|ico)$/i, "")) : ""
                                    sourceSize: Qt.size(28, 28)
                                    fillMode: Image.PreserveAspectFit
                                    visible: iconName && status === Image.Ready
                                    asynchronous: true
                                    cache: true
                                    mipmap: true
                                    
                                    // Просто делаем иконку ярче при выделении
                                    opacity: delegateItem.ListView.isCurrentItem ? 1.0 : 0.7
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: entry.name
                                        color: delegateItem.ListView.isCurrentItem
                                               ? Flow.FlowHighlightAnimation.selectedTextColor
                                               : Theme.Palette.on_surface
                                        font.family: "JetBrains Mono"
                                        font.pointSize: 11
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: entry.comment || entry.genericName || ""
                                        color: delegateItem.ListView.isCurrentItem
                                               ? Flow.FlowHighlightAnimation.selectedTextColor
                                               : Theme.Palette.on_surface_variant
                                        font.family: "JetBrains Mono"
                                        font.pointSize: 9
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                }
                            }
                        }

                        onClicked: {
                            appList.currentIndex = index;
                            entry.execute();
                            launcher.closeLauncher();
                        }
                    }

                    Keys.onUpPressed: {
                        if (count > 0) {
                            if (currentIndex > 0) {
                                decrementCurrentIndex();
                            } else {
                                currentIndex = count - 1;
                            }
                        }
                    }

                    Keys.onDownPressed: {
                        if (count > 0) {
                            if (currentIndex < count - 1) {
                                incrementCurrentIndex();
                            } else {
                                currentIndex = 0;
                            }
                        }
                    }

                    Keys.onReturnPressed: {
                        if (currentIndex >= 0 && currentItem) {
                            currentItem.entry.execute();
                            launcher.closeLauncher();
                        }
                    }

                    Keys.onEscapePressed: {
                        launcher.closeLauncher();
                    }
                }
                }
            }

            NumberAnimation {
                id: slideAnim
                target: panel
                property: "yOffset"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }
}
