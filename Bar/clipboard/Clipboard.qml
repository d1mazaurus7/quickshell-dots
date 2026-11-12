import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../../theme" as Theme
import "../../shell/config"
import "../../shell/theme"
import "../../components/animations" as Flow

// Буфер обмена: qs ipc call clipboard toggle
PanelWindow {
    id: clipboard

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            clipboard.open = !clipboard.open;
        }
    }

    ClipboardState { id: history }

    WlrLayershell.namespace: "qs:clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property bool open: false

    readonly property var cfg: Config.options.clipboard

    visible: open || slideAnim.running

    onOpenChanged: {
        if (open) {
            searchField.text = "";
            list.positionViewAtBeginning();
            list.currentIndex = 0;
            searchField.forceActiveFocus();
            slideAnim.from = 0;
            slideAnim.to = panel.height;
        } else {
            slideAnim.from = panel.height;
            slideAnim.to = 0;
        }
        slideAnim.restart();
    }

    function copyCurrent(): void {
        if (list.currentItem) {
            history.copy(list.currentItem.entry);
            open = false;
        }
    }

    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: panel

            width: clipboard.cfg.width
            height: clipboard.cfg.height

            property real offset: 0

            x: (parent.width - width) / 2
            // Вне анимации следует за высотой из настроек
            y: parent.height - (slideAnim.running ? offset : clipboard.open ? height : 0)

            clip: true

            // Выходит за нижний край, чтобы скругление было только у верхних углов
            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: -16
                color: Theme.Palette.background
                radius: Tokens.radius(16)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: Theme.Palette.surface_container
                        radius: Tokens.radius(12)

                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            anchors.margins: 10
                            anchors.rightMargin: text.length > 0 ? clearBtn.width + 26 : 10
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.Palette.on_surface
                            font.family: Tokens.fontMedium.family
                            font.pixelSize: Tokens.fontMedium.pixelSize
                            clip: true

                            Keys.onUpPressed: {
                                if (list.count > 0)
                                    list.currentIndex = list.currentIndex > 0 ? list.currentIndex - 1 : list.count - 1;
                            }
                            Keys.onDownPressed: {
                                if (list.count > 0)
                                    list.currentIndex = list.currentIndex < list.count - 1 ? list.currentIndex + 1 : 0;
                            }
                            Keys.onReturnPressed: clipboard.copyCurrent()
                            Keys.onEscapePressed: clipboard.open = false
                            Keys.onPressed: event => {
                                // Shift+Delete — удалить запись
                                if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier) && list.currentItem) {
                                    history.remove(list.currentItem.entry);
                                    event.accepted = true;
                                }
                            }

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                color: Theme.Palette.on_surface_variant
                                font: searchField.font
                                text: "Поиск в буфере обмена..."
                                visible: !searchField.text && !searchField.activeFocus
                            }
                        }

                        // Кнопка очистки строки поиска
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
                                color: clearBtn.containsMouse || clearBtn.containsPress
                                       ? Theme.Palette.surface_container_highest
                                       : Theme.Palette.surface_container_high
                                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Отчистить"
                                color: Theme.Palette.on_surface_variant
                                font: Tokens.fontSmall
                            }

                            onClicked: {
                                searchField.text = "";
                                searchField.forceActiveFocus();
                            }
                        }
                    }

                    // Очистка всей истории
                    MouseArea {
                        id: wipeBtn
                        Layout.preferredHeight: 40
                        Layout.preferredWidth: wipeText.implicitWidth + 24
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: history.entries.length > 0

                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.radius(12)
                            opacity: wipeBtn.enabled ? 1 : 0.5
                            color: wipeBtn.containsPress ? Theme.Palette.surface_container_highest
                                 : wipeBtn.containsMouse ? Theme.Palette.surface_container_high
                                 : Theme.Palette.surface_container
                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                        }

                        Text {
                            id: wipeText
                            anchors.centerIn: parent
                            text: "Очистить историю"
                            color: Theme.Palette.on_surface_variant
                            font: Tokens.fontSmall
                        }

                        onClicked: {
                            history.clear();
                            searchField.forceActiveFocus();
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: history.entries.length === 0 ? "Буфер обмена пуст" : "Ничего не найдено"
                        color: Theme.Palette.on_surface_variant
                        font: Tokens.fontMedium
                    }

                    ListView {
                        id: list
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        spacing: 4
                        clip: false

                        readonly property real itemHeight: Math.max(32,
                            (height - spacing * (clipboard.cfg.pageItems - 1)) / clipboard.cfg.pageItems)

                        highlight: Flow.FlowHighlight {
                            view: list
                        }

                        model: {
                            const query = searchField.text.toLowerCase();
                            return history.entries.filter(e => query === ""
                                || (e.text ?? "").toLowerCase().indexOf(query) !== -1
                                || (e.paths ?? []).some(p => p.toLowerCase().indexOf(query) !== -1));
                        }

                        delegate: MouseArea {
                            id: item
                            x: 4
                            width: list.width - 8
                            height: list.itemHeight

                            required property var modelData
                            required property int index
                            readonly property var entry: modelData
                            readonly property bool current: ListView.isCurrentItem
                            readonly property color textColor: current
                                ? Flow.FlowHighlightAnimation.selectedTextColor
                                : Theme.Palette.on_surface

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            Rectangle {
                                anchors.fill: parent
                                radius: Tokens.radius(10)
                                color: item.current ? "transparent"
                                     : item.containsPress ? Theme.Palette.surface_container_highest
                                     : item.containsMouse ? Theme.Palette.surface_container_high
                                     : Theme.Palette.surface_container

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    Image {
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: height * 1.6
                                        visible: item.entry.kind === "image"
                                        source: visible ? "file://" + item.entry.path : ""
                                        fillMode: Image.PreserveAspectFit
                                        horizontalAlignment: Image.AlignLeft
                                        asynchronous: true
                                        sourceSize.height: height
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        verticalAlignment: Text.AlignVCenter
                                        text: item.entry.kind === "image" ? "Изображение"
                                            : item.entry.kind === "file" ? item.entry.paths.join("\n")
                                            : item.entry.text
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WrapAnywhere
                                        elide: Text.ElideRight
                                        color: item.entry.kind === "text" ? item.textColor
                                             : item.current ? item.textColor : Theme.Palette.on_surface_variant
                                        font: Tokens.fontMedium
                                    }
                                }
                            }

                            onClicked: {
                                list.currentIndex = index;
                                clipboard.copyCurrent();
                            }
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
