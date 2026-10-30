pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../shell/theme"
import "pages" as Pages

// Окно настроек: оверлей поверх всех окон, панель по центру экрана
PanelWindow {
    id: root

    property bool open: false

    readonly property var colors: Tokens.colors
    // Разделы: заголовок + страница
    readonly property var sections: [
        { title: "Шрифт", page: fontPage },
        { title: "Интерфейс", page: interfacePage }
    ]
    readonly property var filteredSections: sections.filter(s =>
        s.title.toLowerCase().includes(search.text.trim().toLowerCase()))
    property string currentTitle: sections[0].title
    readonly property var currentSection: sections.find(s => s.title === currentTitle)

    WlrLayershell.namespace: "qs:settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.open = false
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

                Repeater {
                    model: root.filteredSections

                    Rectangle {
                        id: item
                        required property var modelData
                        readonly property bool selected: root.currentTitle === item.modelData.title

                        Layout.fillWidth: true
                        implicitHeight: Tokens.scaled(48)
                        radius: Tokens.radiusLarge
                        color: selected ? root.colors.secondary_container
                             : area.pressed ? root.colors.surface_container_highest
                             : area.containsMouse ? root.colors.surface_container_high
                             : root.colors.surface_container
                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.spacingLarge
                            text: item.modelData.title
                            color: item.selected ? root.colors.on_secondary_container : root.colors.on_surface
                            font: Tokens.fontMedium
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

                Item { Layout.fillHeight: true }
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
                }
            }
        }
    }
}
