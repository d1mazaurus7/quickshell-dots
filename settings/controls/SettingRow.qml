import QtQuick
import QtQuick.Layouts
import "../../shell/theme"

// Пункт настроек: название и описание слева, элемент управления справа
Rectangle {
    id: row

    property string title
    property string description
    // Зависимый пункт: сдвинут вправо под родительским
    property bool child: false
    // Уровень вложенности: каждый уровень сдвигает пункт вправо
    property int depth: child ? 1 : 0
    // Показ/скрытие с разворачиванием вниз (вместо visible)
    property bool shown: true
    // Предупреждение: название цвета error, справа от него иконка alertIcon (Material Symbols)
    property bool alert: false
    property string alertIcon: ""

    property real reveal: shown ? 1 : 0
    // Закрытие — с ускорением к концу (M3 emphasized accelerate): без медленного хвоста,
    // где высота менялась бы меньше чем на пиксель за кадр
    Behavior on reveal {
        id: revealBehavior
        NumberAnimation {
            duration: Tokens.animationMedium
            easing.type: revealBehavior.targetValue > 0 ? Easing.OutCubic : Easing.BezierSpline
            easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
        }
    }
    readonly property real fullHeight: Math.max(texts.implicitHeight, slot.implicitHeight) + Tokens.spacingLargeV * 2
    default property alias control: slot.data

    readonly property var colors: Tokens.colors

    Layout.fillWidth: true
    Layout.leftMargin: depth * Tokens.spacingLarge * 2
    // Пока пункт свёрнут, съедаем spacing родительского ColumnLayout — без скачка в конце
    Layout.topMargin: -(1 - reveal) * (parent?.spacing ?? 0)
    implicitHeight: fullHeight * reveal
    visible: reveal > 0
    opacity: reveal
    // Обрезка только на время разворачивания — иначе обрезается выпадающий список
    clip: reveal < 1
    radius: Tokens.radiusLarge
    // При cardBlur — прозрачная, фон даёт CardBackdrop (размытие + тонировка);
    // вне окна настроек — просто полупрозрачная
    color: backdrop.active ? "transparent"
         : Tokens.appearance.cardBlur ? Qt.alpha(colors.surface_container, 0.45) : colors.surface_container
    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }

    CardBackdrop { id: backdrop }

    ColumnLayout {
        id: texts
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.leftMargin: Tokens.spacingLarge
        anchors.rightMargin: Tokens.spacingLarge
        y: (row.fullHeight - height) / 2
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.maximumWidth: texts.width - alertBox.width
                text: row.title
                color: row.alert ? row.colors.error : row.colors.on_surface
                font: Tokens.fontMedium
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            }

            // Ширина сворачивается вместе с прозрачностью — без скачка текста
            Item {
                id: alertBox
                property real reveal: row.alert && row.alertIcon !== "" ? 1 : 0
                Behavior on reveal { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

                Layout.preferredWidth: (alertGlyph.implicitWidth + Tokens.spacingSmall) * reveal
                Layout.preferredHeight: alertGlyph.implicitHeight
                visible: reveal > 0
                opacity: reveal
                clip: true

                Text {
                    id: alertGlyph
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.alertIcon
                    color: row.colors.error
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Tokens.fontMedium.pixelSize + Tokens.scaled(2)
                }
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            visible: row.description !== ""
            text: row.description
            color: row.colors.on_surface_variant
            font: Tokens.fontSmall
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: Tokens.spacingLarge
        y: (row.fullHeight - height) / 2
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }
}
