import QtQuick
import QtQuick.Layouts
import "../../shell/theme"

// Карточка новости: источник, время, заголовок. Клик — clicked() (окно открывает ссылку)
Rectangle {
    id: root

    required property var item
    // Текущее время для «N мин назад», мс
    property double now: Date.now()

    signal clicked

    readonly property var colors: Tokens.colors

    function ago(date: double): string {
        if (date <= 0)
            return "";
        const min = Math.max(0, Math.floor((now - date) / 60000));
        if (min < 1)
            return "только что";
        if (min < 60)
            return min + " мин назад";
        if (min < 24 * 60)
            return Math.floor(min / 60) + " ч назад";
        return Qt.formatDateTime(new Date(date), "dd.MM HH:mm");
    }

    implicitHeight: content.implicitHeight + Tokens.spacingMediumV * 2
    radius: Tokens.radiusLarge
    color: area.pressed ? colors.surface_container_highest
         : area.containsMouse ? colors.surface_container_high
         : colors.surface_container
    scale: area.pressed ? 0.98 : 1
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
    Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacingLarge
        anchors.rightMargin: Tokens.spacingLarge
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacingSmallV

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacingSmall

            Text {
                Layout.fillWidth: true
                text: root.item.source
                textFormat: Text.PlainText
                color: root.colors.primary
                font: Tokens.fontSmall
                elide: Text.ElideRight
            }

            Text {
                text: root.ago(root.item.date)
                color: root.colors.on_surface_variant
                font: Tokens.fontSmall
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.item.title
            textFormat: Text.PlainText
            color: root.colors.on_surface
            font: Tokens.fontMedium
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
