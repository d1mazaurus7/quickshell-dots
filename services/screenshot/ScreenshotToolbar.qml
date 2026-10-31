import QtQuick
import Quickshell
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Панель под выделенной областью:
// [скачать] [копировать] (снимок) [кисть] [ластик] [размытие]
Rectangle {
    id: root

    // Активный инструмент: "" | "brush" | "eraser" | "blur"
    property string tool: ""
    // Показывать кисть, ластик и размытие
    property bool editTools: true

    signal toolSelected(string name)
    signal saveRequested()
    signal copyRequested()
    signal captureRequested()

    readonly property int buttonSize: Tokens.scaled(36)
    readonly property int captureSize: Tokens.scaled(44)
    readonly property int padding: Tokens.scaled(8)

    function playClick(): void {
        Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.clickSound)]);
    }

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: row.implicitHeight + padding * 2
    radius: Tokens.radiusLarge
    color: Theme.Palette.surface_container
    border.color: Theme.Palette.outline_variant
    border.width: Tokens.borderWidth

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.spacingSmall

        ToolButton {
            icon: "download"
            onClicked: root.saveRequested()
        }
        ToolButton {
            icon: "content_copy"
            onClicked: root.copyRequested()
        }

        // Снимок: и в буфер, и в файл
        Item {
            width: root.captureSize + Tokens.spacingMedium * 2
            height: root.captureSize

            Rectangle {
                anchors.centerIn: parent
                width: root.captureSize
                height: width
                radius: width / 2
                color: captureArea.pressed ? Theme.Palette.primary_fixed_dim
                     : captureArea.containsMouse ? Theme.Palette.primary_fixed
                     : Theme.Palette.primary
                scale: captureArea.pressed ? 0.92 : 1

                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                // Внутреннее кольцо, как у кнопки затвора
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Tokens.scaled(4)
                    radius: width / 2
                    color: "transparent"
                    border.color: Theme.Palette.on_primary
                    border.width: Tokens.scaled(2)
                }

                MouseArea {
                    id: captureArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.playClick();
                        root.captureRequested();
                    }
                }
            }
        }

        ToolButton {
            icon: "brush"
            visible: root.editTools
            checked: root.tool === "brush"
            onClicked: root.toolSelected("brush")
        }
        ToolButton {
            icon: "ink_eraser"
            visible: root.editTools
            checked: root.tool === "eraser"
            onClicked: root.toolSelected("eraser")
        }
        ToolButton {
            icon: "blur_on"
            visible: root.editTools
            checked: root.tool === "blur"
            onClicked: root.toolSelected("blur")
        }
    }

    component ToolButton: Rectangle {
        id: button

        property string icon
        property bool checked: false
        signal clicked()

        anchors.verticalCenter: parent.verticalCenter
        width: root.buttonSize
        height: root.buttonSize
        radius: Tokens.radiusMedium
        color: checked ? Theme.Palette.primary_container
             : area.pressed ? Theme.Palette.surface_bright
             : area.containsMouse ? Theme.Palette.surface_container_highest
             : Theme.Palette.surface_container_high
        scale: area.pressed ? 0.94 : 1

        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: button.icon
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(20)
            color: button.checked ? Theme.Palette.on_primary_container : Theme.Palette.on_surface_variant

            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.playClick();
                button.clicked();
            }
        }
    }
}
