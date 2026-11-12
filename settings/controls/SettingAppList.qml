pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../shell/theme"
import "../../components" as Components

// Пункт настроек со списком приложений. «Изменить» раскрывает список всех приложений
// с отметками, «Применить» сохраняет выбор, удаление — также крестиком на чипе.
// apps — id desktop-файлов (привязать к Config), edited(apps) — новый список;
// removable — кнопка «Удалить» самого пункта (removeRequested)
Rectangle {
    id: root

    property string title
    property string description
    property var apps: []
    property bool removable: false

    signal edited(var apps)
    signal removeRequested()

    property bool editing: false
    // Чипы выбранных приложений свёрнуты, пока не нажато «Показать»
    property bool showApps: false
    // Выбор, пока список открыт; в Config попадает только по «Применить»
    property var draft: []

    readonly property var colors: Tokens.colors
    readonly property var entries: DesktopEntries.applications.values
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var filteredEntries: entries.filter(e =>
        e.name.toLowerCase().includes(filter.text.trim().toLowerCase()))

    function toggle(id) {
        draft = draft.includes(id) ? draft.filter(a => a !== id) : draft.concat([id]);
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + Tokens.spacingLargeV * 2
    radius: Tokens.radiusLarge
    // При cardBlur — прозрачная, фон даёт CardBackdrop (размытие + тонировка);
    // вне окна настроек — просто полупрозрачная
    color: backdrop.active ? "transparent"
         : Tokens.appearance.cardBlur ? Qt.alpha(colors.surface_container, 0.45) : colors.surface_container
    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

    CardBackdrop { id: backdrop }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Tokens.spacingLarge
        anchors.rightMargin: Tokens.spacingLarge
        anchors.topMargin: Tokens.spacingLargeV
        spacing: Tokens.spacingMediumV

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacingMedium

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.colors.on_surface
                    font: Tokens.fontMedium
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.description !== ""
                    text: root.description
                    color: root.colors.on_surface_variant
                    font: Tokens.fontSmall
                    wrapMode: Text.Wrap
                }
            }

            SettingButton {
                visible: !root.editing && root.apps.length > 0
                variant: "outlined"
                icon: root.showApps ? "expand_less" : "expand_more"
                text: root.showApps ? "Свернуть" : "Показать (" + root.apps.length + ")"
                onClicked: root.showApps = !root.showApps
            }

            SettingButton {
                visible: !root.editing
                icon: "edit"
                text: "Изменить"
                onClicked: {
                    root.draft = root.apps.slice();
                    filter.text = "";
                    root.editing = true;
                }
            }

            SettingButton {
                visible: root.editing
                variant: "text"
                text: "Отмена"
                onClicked: root.editing = false
            }

            SettingButton {
                visible: root.editing
                variant: "filled"
                icon: "check"
                text: "Применить"
                onClicked: {
                    root.edited(root.draft);
                    root.editing = false;
                }
            }

            SettingButton {
                visible: root.removable && !root.editing
                variant: "outlined"
                icon: "delete"
                text: "Удалить"
                onClicked: root.removeRequested()
            }
        }

        // Чипы выбранных приложений: раскрываются вниз
        Item {
            Layout.fillWidth: true
            readonly property bool open: !root.editing && root.showApps && root.apps.length > 0
            implicitHeight: open ? chips.implicitHeight : 0
            opacity: open ? 1 : 0
            visible: implicitHeight > 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }

            Flow {
                id: chips
                width: parent.width
                spacing: Tokens.spacingSmall

                Repeater {
                    model: root.apps

                    Components.AppChip {
                        id: chip
                        required property string modelData
                        readonly property var entry: DesktopEntries.byId(modelData)

                        name: entry ? entry.name : modelData
                        icon: entry ? entry.icon : ""
                        onRemoved: root.edited(root.apps.filter(id => id !== chip.modelData))
                    }
                }
            }
        }

        // Список выбора: раскрывается вниз
        Item {
            Layout.fillWidth: true
            implicitHeight: root.editing ? editor.implicitHeight : 0
            opacity: root.editing ? 1 : 0
            visible: implicitHeight > 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }

            ColumnLayout {
                id: editor
                width: parent.width
                spacing: Tokens.spacingSmallV

                // M3 поиск: иконка, поле, кнопка очистки
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.scaled(44)
                    radius: filter.activeFocus ? Tokens.radiusLarge : height / 2
                    color: root.colors.surface_container_highest
                    border.width: filter.activeFocus ? 2 : 0
                    border.color: root.colors.primary
                    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    // State layer
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: root.colors.on_surface
                        opacity: searchArea.containsMouse && !filter.activeFocus ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                    }

                    MouseArea {
                        id: searchArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: filter.forceActiveFocus()
                    }

                    Text {
                        id: searchIcon
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.spacingLarge
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: filter.activeFocus ? root.colors.primary : root.colors.on_surface_variant
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.scaled(20)
                        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                    }

                    TextInput {
                        id: filter
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
                            opacity: filter.text === "" ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                        }
                    }

                    Rectangle {
                        id: clearBtn
                        readonly property bool shown: filter.text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        width: Tokens.scaled(32)
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
                                filter.text = "";
                                filter.forceActiveFocus();
                            }
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Tokens.scaled(320)
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.filteredEntries

                    delegate: Components.AppSelectItem {
                        id: item
                        required property var modelData

                        width: list.width
                        name: modelData.name
                        icon: modelData.icon
                        selected: root.draft.includes(modelData.id)
                        onClicked: root.toggle(item.modelData.id)
                    }
                }
            }
        }
    }
}
