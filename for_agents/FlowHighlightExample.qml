import QtQuick
import QtQuick.Controls
import "theme" as Theme

Rectangle {
    id: root
    color: Theme.Palette.background
    width: 400
    height: 300

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: 20
        anchors.bottomMargin: 40
        model: 20
        focus: true

        highlight: FlowHighlight { view: listView }

        delegate: Item {
            width: listView.width
            height: 40

            Text {
                anchors.centerIn: parent
                text: "Элемент " + (index + 1)
                color: Theme.Palette.text
            }

            MouseArea {
                anchors.fill: parent
                onClicked: listView.currentIndex = index
            }
        }

        Keys.onUpPressed: currentIndex = currentIndex > 0 ? currentIndex - 1 : count - 1
        Keys.onDownPressed: currentIndex = currentIndex < count - 1 ? currentIndex + 1 : 0
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10
        text: "Стрелки вверх/вниз или клик по элементу"
        color: Theme.Palette.subtext
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
        spacing: 5

        Text {
            text: "Скорость:"
            color: Theme.Palette.subtext
            anchors.verticalCenter: parent.verticalCenter
        }

        Slider {
            id: durationSlider
            from: 50
            to: 500
            value: 200
            width: 100
            onValueChanged: FlowHighlightAnimation.updateSettings(undefined, value)
        }
    }
}
