import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
// Отдельно: имя Flow занято импортом анимаций
import QtQuick as QQ
import QtQuick.Layouts
import "../theme" as Theme
import "../shell/config"
import "../shell/theme"
import "../components/animations" as Flow
import "../components" as Components
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

    readonly property var cfg: Config.options.launcher

    visible: open || slideAnim.running

    onOpenChanged: {
        if (open) {
            searchField.text = "";
            appList.positionViewAtBeginning();
            appList.currentIndex = 0;
            searchField.forceActiveFocus();
            slideAnim.from = 0;
            slideAnim.to = panel.extent;
            slideAnim.restart();
        } else {
            slideAnim.from = panel.extent;
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
    property bool commandMode: cfg.commandShell && searchField.text.length > 0 && searchField.text.charAt(0) === ">"

    // Команда без префикса ">"
    property string commandText: commandMode ? searchField.text.substring(1).trim() : ""

    // Система тегов: активен когда текст начинается с "/"
    property bool tagMode: tagCommands.length > 0 && searchField.text.length > 0 && searchField.text.charAt(0) === "/"

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
    property bool emojiMode: tagMode && cfg.commandEmoji && currentTag === "emoji"
    property bool webMode: tagMode && cfg.commandWeb && currentTag === "web"

    // Поисковые системы для /web
    readonly property var webEngines: [
        { name: "Google", url: "https://www.google.com/search?q=" },
        { name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" }
    ]

    function openWebSearch(engine): void {
        if (tagQuery.length === 0) return;
        Qt.openUrlExternally(engine.url + encodeURIComponent(tagQuery));
        closeLauncher();
    }

    // Список тег-команд для автодополнения
    readonly property var tagCommands: [
        { tag: "emoji", description: "Поиск эмоджи", enabled: cfg.commandEmoji },
        { tag: "web", description: "Поиск в интернете", enabled: cfg.commandWeb }
    ].filter(t => t.enabled)

    readonly property string placeholder: {
        var hints = [];
        if (cfg.commandShell) hints.push("> команда");
        if (cfg.commandEmoji) hints.push("/emoji эмоджи");
        if (cfg.commandWeb) hints.push("/web поиск");
        if (cfg.tags.length > 0) hints.push("#тег");
        return "Поиск приложений..." + (hints.length > 0 ? " (" + hints.join(", ") + ")" : "");
    }

    // Пользовательские теги программ: текст начинается с "#"
    property bool appTagMode: cfg.tags.length > 0 && searchField.text.length > 0 && searchField.text.charAt(0) === "#"

    // Режим автодополнения: после "/" или "#", ещё без пробела (тег ещё печатается)
    property bool tagSuggestMode: (tagMode || appTagMode) && searchField.text.substring(1).indexOf(" ") === -1

    // Отфильтрованные предложения по текущему тегу
    property var tagSuggestions: {
        if (!tagSuggestMode) return [];
        var prefix = searchField.text.substring(1).toLowerCase();
        var source = appTagMode
            ? cfg.tags.map(t => ({ prefix: "#", tag: t.name, description: "Программ: " + t.apps.length }))
            : tagCommands.map(c => ({ prefix: "/", tag: c.tag, description: c.description }));
        var result = [];
        for (var i = 0; i < source.length; i++) {
            if (prefix === "" || source[i].tag.toLowerCase().indexOf(prefix) === 0)
                result.push(source[i]);
        }
        return result;
    }

    function openAppTag(name): void {
        searchField.text = "#" + name + " ";
        searchField.cursorPosition = searchField.text.length;
        searchField.forceActiveFocus();
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

            // Насколько панель выдвинута от края экрана
            readonly property real extent: launcher.cfg.position === "left" || launcher.cfg.position === "right" ? width : height
            property real offset: 0

            x: launcher.cfg.position === "left" ? offset - width
             : launcher.cfg.position === "right" ? parent.width - offset
             : (parent.width - width) / 2
            y: launcher.cfg.position === "top" ? offset - height
             : launcher.cfg.position === "bottom" ? parent.height - offset
             : (parent.height - height) / 2

            clip: true

            // Выходит за край экрана, чтобы скругление было только у свободных углов
            Rectangle {
                anchors.fill: parent
                anchors.topMargin: launcher.cfg.position === "top" ? -16 : 0
                anchors.bottomMargin: launcher.cfg.position === "bottom" ? -16 : 0
                anchors.leftMargin: launcher.cfg.position === "left" ? -16 : 0
                anchors.rightMargin: launcher.cfg.position === "right" ? -16 : 0
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
                            if (launcher.webMode) {
                                webList.currentIndex = webList.currentIndex > 0 ? webList.currentIndex - 1 : webList.count - 1;
                            } else if (launcher.tagSuggestMode) {
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
                            if (launcher.webMode) {
                                webList.currentIndex = webList.currentIndex < webList.count - 1 ? webList.currentIndex + 1 : 0;
                            } else if (launcher.tagSuggestMode) {
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
                            } else if (launcher.webMode) {
                                if (webList.currentItem)
                                    launcher.openWebSearch(webList.currentItem.modelData);
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
                            if (launcher.tagSuggestMode && !launcher.webMode && tagList.count > 0)
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
                            text: launcher.placeholder
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

                // Кнопки пользовательских тегов
                QQ.Flow {
                    Layout.fillWidth: true
                    visible: launcher.cfg.showTagButtons && launcher.cfg.tags.length > 0
                    spacing: 6

                    Repeater {
                        model: launcher.cfg.tags

                        MouseArea {
                            id: tagButton
                            required property var modelData
                            readonly property bool active: launcher.appTagMode && !launcher.tagSuggestMode
                                && searchField.text.substring(1).split(" ")[0] === modelData.name

                            width: tagButtonText.implicitWidth + 24
                            height: 28
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: active ? searchField.text = "" : launcher.openAppTag(modelData.name)

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: tagButton.active ? Theme.Palette.secondary_container
                                     : tagButton.containsPress ? Theme.Palette.surface_container_highest
                                     : tagButton.containsMouse ? Theme.Palette.surface_container_high
                                     : Theme.Palette.surface_container
                                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                            }

                            Text {
                                id: tagButtonText
                                anchors.centerIn: parent
                                text: "#" + tagButton.modelData.name
                                color: tagButton.active ? Theme.Palette.on_secondary_container : Theme.Palette.on_surface_variant
                                font.family: "JetBrains Mono"
                                font.pointSize: 10
                            }
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
                    visible: launcher.tagSuggestMode && !launcher.webMode && count > 0

                    highlight: Flow.FlowHighlight {
                        view: tagList
                    }

                    model: launcher.tagSuggestions

                    onModelChanged: currentIndex = 0

                    function completeCurrent(): void {
                        if (currentIndex >= 0 && currentItem) {
                            searchField.text = currentItem.modelData.prefix + currentItem.modelData.tag + " ";
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
                                    text: tagDelegate.modelData.prefix + tagDelegate.modelData.tag
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

                // Web-поиск ("/web <запрос>")
                ListView {
                    id: webList
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    spacing: 4
                    visible: launcher.webMode

                    highlight: Flow.FlowHighlight {
                        view: webList
                    }

                    model: launcher.webMode ? launcher.webEngines : []

                    onModelChanged: currentIndex = 0

                    delegate: MouseArea {
                        id: webDelegate
                        x: 4
                        width: webList.width - 8
                        height: 48

                        required property var modelData
                        required property int index

                        hoverEnabled: true

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius(10)
                            color: webDelegate.ListView.isCurrentItem
                                   ? "transparent"
                                   : (webDelegate.containsPress || webDelegate.containsMouse
                                      ? Theme.Palette.surface_container_high
                                      : Theme.Palette.surface_container)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    color: webDelegate.ListView.isCurrentItem
                                           ? Flow.FlowHighlightAnimation.selectedTextColor
                                           : Theme.Palette.primary
                                    font.family: "JetBrains Mono"
                                    font.pointSize: 11
                                    font.bold: true
                                    text: webDelegate.modelData.name
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: launcher.tagQuery.length > 0 ? launcher.tagQuery : "Введите запрос..."
                                    color: webDelegate.ListView.isCurrentItem
                                           ? Flow.FlowHighlightAnimation.selectedTextColor
                                           : Theme.Palette.on_surface_variant
                                    font.family: "JetBrains Mono"
                                    font.pointSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        onClicked: {
                            webList.currentIndex = index;
                            launcher.openWebSearch(modelData);
                        }

                        onContainsMouseChanged: {
                            if (containsMouse) webList.currentIndex = index;
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
                    visible: !launcher.commandMode && !launcher.emojiMode && !launcher.webMode && !launcher.tagSuggestMode

                    highlight: Flow.FlowHighlight {
                        view: appList
                    }

                    model: {
                        if (launcher.commandMode || launcher.emojiMode || launcher.webMode) return [];
                        var query = searchField.text.toLowerCase();
                        // "#тег запрос": только программы тега, включая скрытые
                        var tagApps = null;
                        if (launcher.appTagMode) {
                            var rest = query.substring(1);
                            var sp = rest.indexOf(" ");
                            var tagName = sp === -1 ? rest : rest.substring(0, sp);
                            query = sp === -1 ? "" : rest.substring(sp + 1).trim();
                            var tag = launcher.cfg.tags.find(t => t.name === tagName);
                            tagApps = tag ? Array.from(tag.apps) : [];
                        }
                        var result = [];
                        var hidden = launcher.cfg.hiddenApps;
                        var pinned = launcher.cfg.pinnedApps;
                        var entries = DesktopEntries.applications.values;
                        for (var i = 0; i < entries.length; i++) {
                            var e = entries[i];
                            if (!tagApps && hidden.includes(e.id)) continue;
                            if (tagApps && !tagApps.includes(e.id)) continue;
                            if (query === "" ||
                                e.name.toLowerCase().indexOf(query) !== -1 ||
                                (e.comment && e.comment.toLowerCase().indexOf(query) !== -1)) {
                                result.push(e);
                            }
                        }
                        // Закреплённые — в начале, в порядке закрепления
                        result.sort(function(a, b) {
                            var pa = pinned.indexOf(a.id), pb = pinned.indexOf(b.id);
                            if (pa !== pb) {
                                if (pa === -1) return 1;
                                if (pb === -1) return -1;
                                return pa - pb;
                            }
                            return a.name.localeCompare(b.name);
                        });
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

                                Components.AppIcon {
                                    size: 28
                                    icon: entry.icon || ""
                                    name: entry.name
                                    letterFallback: launcher.cfg.letterIcons
                                    visible: launcher.cfg.showIcons && (!missing || letterFallback)

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
                                        visible: launcher.cfg.showDescriptions && text !== ""
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
                property: "offset"
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }
}
