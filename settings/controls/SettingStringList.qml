pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../shell/theme"

// Пункт настроек со списком строк: чипы с удалением и поле добавления (Enter или «Добавить»).
// values — текущий список (привязать к Config), edited(values) — новый список; в Config пишет страница
Rectangle {
    id: root

    property string title
    property string description
    property var values: []
    property string placeholder

    signal edited(var values)

    readonly property var colors: Tokens.colors

    function add(): void {
        const value = input.text.trim();
        if (value !== "" && !values.includes(value))
            edited(values.concat([value]));
        input.text = "";
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

        Flow {
            Layout.fillWidth: true
            visible: root.values.length > 0
            spacing: Tokens.spacingSmall

            Repeater {
                model: root.values

                Rectangle {
                    id: chip
                    required property string modelData

                    width: Math.min(chipRow.implicitWidth + Tokens.spacingLarge + Tokens.spacingSmall, content.width)
                    height: Tokens.scaled(32)
                    radius: height / 2
                    color: root.colors.secondary_container

                    RowLayout {
                        id: chipRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Tokens.spacingLarge
                        anchors.rightMargin: Tokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacingSmall

                        Text {
                            Layout.fillWidth: true
                            text: chip.modelData
                            textFormat: Text.PlainText
                            color: root.colors.on_secondary_container
                            font: Tokens.fontSmall
                            elide: Text.ElideMiddle
                        }

                        // Удалить
                        Rectangle {
                            implicitWidth: Tokens.scaled(24)
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: removeArea.pressed ? Qt.alpha(root.colors.on_secondary_container, 0.24)
                                 : removeArea.containsMouse ? Qt.alpha(root.colors.on_secondary_container, 0.12)
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                color: root.colors.on_secondary_container
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: Tokens.scaled(16)
                            }

                            MouseArea {
                                id: removeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/sfx.wav")]);
                                    root.edited(root.values.filter(v => v !== chip.modelData));
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacingMedium

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: input.implicitHeight + Tokens.spacingMediumV * 2
                radius: height / 2
                color: inputArea.containsMouse && !input.activeFocus ? root.colors.surface_container_highest : root.colors.surface_container_high
                border.width: input.activeFocus ? 2 : 1
                border.color: input.activeFocus ? root.colors.primary : root.colors.outline_variant
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
                    clip: true
                    color: root.colors.on_surface
                    selectionColor: root.colors.primary
                    selectedTextColor: root.colors.on_primary
                    font: Tokens.fontMedium
                    selectByMouse: true
                    Keys.onReturnPressed: root.add()
                    Keys.onEnterPressed: root.add()

                    Text {
                        anchors.fill: parent
                        visible: input.text === ""
                        text: root.placeholder
                        color: root.colors.on_surface_variant
                        font: Tokens.fontMedium
                        elide: Text.ElideRight
                    }
                }
            }

            SettingButton {
                text: "Добавить"
                icon: "add"
                onClicked: root.add()
            }
        }
    }
}
