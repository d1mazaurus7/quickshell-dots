import QtQuick
import "../../shell/theme"

// Многострочное поле ввода: value — текущее значение (привязать к Config),
// edited(text) — после паузы в наборе или по окончании ввода; в Config пишет страница
Rectangle {
    id: root

    property string value
    property string placeholder

    signal edited(string text)

    readonly property var colors: Tokens.colors

    implicitHeight: Tokens.scaled(160)
    radius: Tokens.radiusLarge
    color: area.containsMouse && !input.activeFocus ? colors.surface_container_high : colors.surface_container
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? colors.primary : colors.outline_variant
    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }

    onValueChanged: if (input.text !== value) input.text = value

    function commit(): void {
        debounce.stop();
        if (input.text !== value)
            edited(input.text);
    }

    Timer {
        id: debounce
        interval: 600
        onTriggered: root.commit()
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Tokens.spacingMedium
        contentHeight: input.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        TextEdit {
            id: input
            width: flick.width
            text: root.value
            color: root.colors.on_surface
            selectionColor: root.colors.primary
            selectedTextColor: root.colors.on_primary
            font: Tokens.fontMedium
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            onTextChanged: if (activeFocus) debounce.restart()
            onEditingFinished: root.commit()
            // Курсор не уходит за видимую область при наборе
            onCursorRectangleChanged: {
                if (cursorRectangle.y < flick.contentY)
                    flick.contentY = cursorRectangle.y;
                else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                    flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height;
            }

            Text {
                anchors.fill: parent
                visible: input.text === ""
                text: root.placeholder
                color: root.colors.on_surface_variant
                font: Tokens.fontMedium
                wrapMode: Text.Wrap
            }
        }
    }
}
