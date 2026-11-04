import QtQuick
import "../../shell/theme"
import "../controls"
import ".."

// Настройки выбранного виджета: размер, страница настроек типа, удаление
Rectangle {
    id: root

    required property WidgetsState widgets

    readonly property var colors: Tokens.colors
    readonly property var item: widgets.selected
    readonly property var entry: item ? widgets.registry.find(item.type) : null
    readonly property bool open: widgets.settingsOpen && entry !== null
    readonly property int pad: Tokens.spacingLarge
    readonly property var geo: item ? widgets.geometry(item.uid) : null

    // Сохраняем последний виджет, чтобы содержимое не пропадало во время закрытия
    property var shownEntry: null
    onEntryChanged: if (entry) shownEntry = entry

    width: Tokens.scaled(400)
    height: column.implicitHeight + Tokens.spacingLargeV * 2
    radius: Tokens.radius(Tokens.scaled(24))
    color: colors.surface_container
    border.width: Tokens.borderWidth
    border.color: colors.outline_variant

    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    visible: opacity > 0
    transformOrigin: Item.Bottom
    Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    MouseArea { anchors.fill: parent }

    function resize(key: string, value: real, live: bool): void {
        const uid = item?.uid;
        if (!uid)
            return;
        if (widgets.previewUid !== uid)
            widgets.startPreview(uid);
        if (key === "width")
            widgets.previewWidth = value;
        else
            widgets.previewHeight = value;
        if (!live)
            widgets.commitPreview();
    }

    Column {
        id: column
        x: root.pad
        y: Tokens.spacingLargeV
        width: root.width - root.pad * 2
        spacing: Tokens.spacingMediumV

        Row {
            spacing: Tokens.spacingMedium

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.shownEntry?.icon ?? ""
                color: root.colors.primary
                font.family: "Material Symbols Rounded"
                font.pixelSize: Tokens.scaled(22)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.shownEntry?.title ?? ""
                color: root.colors.on_surface
                font.family: Tokens.typography.family
                font.pixelSize: Tokens.scaled(Tokens.typography.size + 4)
                font.weight: Font.Medium
            }
        }

        SliderRow {
            width: parent.width
            text: "Ширина"
            from: Tokens.scaled(root.shownEntry?.minWidth ?? 0)
            to: Tokens.scaled(root.shownEntry?.maxWidth ?? 1)
            value: root.geo?.width ?? 0
            onDragged: v => root.resize("width", v, true)
            onMoved: v => root.resize("width", v, false)
        }

        SliderRow {
            width: parent.width
            text: "Высота"
            from: Tokens.scaled(root.shownEntry?.minHeight ?? 0)
            to: Tokens.scaled(root.shownEntry?.maxHeight ?? 1)
            value: root.geo?.height ?? 0
            onDragged: v => root.resize("height", v, true)
            onMoved: v => root.resize("height", v, false)
        }

        Rectangle {
            width: parent.width
            height: 1
            color: root.colors.outline_variant
        }

        // Длинная страница прокручивается: панель не выше половины экрана
        Flickable {
            width: parent.width
            height: Math.min(page.height, (root.parent?.height ?? 0) * 0.5)
            contentHeight: page.height
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: page
                width: parent.width
                height: item ? item.implicitHeight : 0
                // settings — сразу при создании, иначе привязки страницы видят пустой объект
                function reload(): void {
                    const url = root.shownEntry?.settingsComponent ?? "";
                    if (url === "")
                        setSource("");
                    else
                        setSource(url, { settings: root.item ? root.widgets.settingsOf(root.item.uid) : ({}) });
                }
                Component.onCompleted: reload()
                Connections {
                    target: root
                    function onShownEntryChanged(): void { page.reload(); }
                }
            }
        }
        Binding {
            target: page.item
            property: "settings"
            value: root.item ? root.widgets.settingsOf(root.item.uid) : ({})
            when: page.status === Loader.Ready && root.item !== null
        }
        Connections {
            target: page.item
            ignoreUnknownSignals: true
            function onSettingChanged(key: string, value: var): void {
                if (root.item)
                    root.widgets.setSetting(root.item.uid, key, value);
            }
        }

        Item {
            width: parent.width
            height: deleteButton.height

            TextButton {
                id: deleteButton
                anchors.right: parent.right
                danger: true
                icon: "delete"
                text: "Удалить"
                onClicked: if (root.item) root.widgets.remove(root.item.uid)
            }
        }
    }
}
