pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../shell/theme"
import "../../settings/controls"

// Карточка приложения: иконка (или первая буква) с названием и слайдер громкости
Rectangle {
    id: card

    required property var node

    readonly property var colors: Tokens.colors
    readonly property var props: node.properties ?? {}
    readonly property string appName: props["application.name"] || node.description || node.name || "?"
    readonly property string iconName: props["application.icon-name"] || props["application.process.binary"] || appName.toLowerCase()

    function setVolume(value: real): void {
        if (node.audio)
            node.audio.volume = value;
    }

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + Tokens.spacingMediumV * 2
    radius: Tokens.radiusMedium
    color: colors.surface_container

    ColumnLayout {
        id: column
        x: Tokens.spacingMedium
        y: Tokens.spacingMediumV
        width: parent.width - Tokens.spacingMedium * 2
        spacing: Tokens.spacingMediumV

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Tokens.scaled(36)
            radius: Tokens.radiusMedium
            color: card.colors.surface_container_highest

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Tokens.spacingMedium
                anchors.rightMargin: Tokens.spacingMedium
                spacing: Tokens.spacingMedium

                Item {
                    implicitWidth: Tokens.scaled(22)
                    implicitHeight: implicitWidth

                    Image {
                        id: icon
                        anchors.fill: parent
                        // check = true: без иконки — пустая строка, а не заглушка
                        source: Quickshell.iconPath(card.iconName, true)
                        sourceSize.width: width
                        sourceSize.height: height
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: !icon.visible
                        radius: width / 2
                        color: card.colors.primary_container

                        Text {
                            anchors.centerIn: parent
                            text: card.appName.charAt(0).toUpperCase()
                            color: card.colors.on_primary_container
                            font: Tokens.fontSmall
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: card.appName
                    elide: Text.ElideRight
                    color: card.colors.on_surface
                    font: Tokens.fontMedium
                }
            }
        }

        SettingSlider {
            // Ширина подписи значения и отступ — как в SettingSlider
            sliderWidth: column.width - Tokens.scaled(48) - Tokens.spacingMedium
            from: 0
            to: 1
            stepSize: 0.05
            value: card.node.audio?.volume ?? 0
            formatValue: v => Math.round(v * 100) + "%"
            onDragged: value => card.setVolume(value)
            onMoved: value => card.setVolume(value)
        }
    }
}
