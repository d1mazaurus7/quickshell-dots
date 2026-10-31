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
    // Показ/скрытие с разворачиванием вниз (вместо visible)
    property bool shown: true

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
    Layout.leftMargin: child ? Tokens.spacingLarge * 2 : 0
    // Пока пункт свёрнут, съедаем spacing родительского ColumnLayout — без скачка в конце
    Layout.topMargin: -(1 - reveal) * (parent?.spacing ?? 0)
    implicitHeight: fullHeight * reveal
    visible: reveal > 0
    opacity: reveal
    // Обрезка только на время разворачивания — иначе обрезается выпадающий список
    clip: reveal < 1
    radius: Tokens.radiusLarge
    color: colors.surface_container

    ColumnLayout {
        id: texts
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.leftMargin: Tokens.spacingLarge
        anchors.rightMargin: Tokens.spacingLarge
        y: (row.fullHeight - height) / 2
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: row.title
            color: row.colors.on_surface
            font: Tokens.fontMedium
            elide: Text.ElideRight
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
