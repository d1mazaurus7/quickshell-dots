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
    color: colors.surface_container

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
                text: root.showApps ? "Свернуть" : "Показать (" + root.apps.length + ")"
                onClicked: root.showApps = !root.showApps
            }

            SettingButton {
                visible: !root.editing
                text: "Изменить"
                onClicked: {
                    root.draft = root.apps.slice();
                    filter.text = "";
                    root.editing = true;
                }
            }

            SettingButton {
                visible: root.editing
                text: "Отмена"
                onClicked: root.editing = false
            }

            SettingButton {
                visible: root.editing
                text: "Применить"
                onClicked: {
                    root.edited(root.draft);
                    root.editing = false;
                }
            }

            SettingButton {
                visible: root.removable && !root.editing
                text: "Удалить"
                onClicked: root.removeRequested()
            }
        }

        // Чипы выбранных приложений: раскрываются вниз
        Item {
            Layout.fillWidth: true
            implicitHeight: !root.editing && root.showApps && root.apps.length > 0 ? chips.implicitHeight : 0
            visible: implicitHeight > 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

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
            visible: implicitHeight > 0
            clip: true
            Behavior on implicitHeight { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: editor
                width: parent.width
                spacing: Tokens.spacingSmallV

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: filter.implicitHeight + Tokens.spacingMediumV * 2
                    radius: height / 2
                    color: root.colors.surface_container_highest
                    border.width: filter.activeFocus ? 1 : 0
                    border.color: root.colors.primary

                    TextInput {
                        id: filter
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
                            visible: !filter.text
                            text: "Поиск..."
                            color: root.colors.on_surface_variant
                            font: Tokens.fontMedium
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
