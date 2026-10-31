import QtQuick
import "../../shell/theme"

// Однострочное поле ввода: value — текущее значение (привязать к Config),
// edited(text) — после паузы в наборе или по окончании ввода; в Config пишет страница
Rectangle {
    id: root

    property string value
    property string placeholder
    // Скрывать ввод (ключи, пароли)
    property bool password: false

    signal edited(string text)

    readonly property var colors: Tokens.colors

    implicitWidth: Tokens.scaled(280)
    implicitHeight: input.implicitHeight + Tokens.spacingMediumV * 2
    radius: Tokens.radiusMedium
    color: area.containsMouse && !input.activeFocus ? colors.surface_container_highest : colors.surface_container_high
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

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacingMedium
        anchors.rightMargin: Tokens.spacingMedium
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        echoMode: root.password && !activeFocus ? TextInput.Password : TextInput.Normal
        color: root.colors.on_surface
        selectionColor: root.colors.primary
        selectedTextColor: root.colors.on_primary
        font: Tokens.fontMedium
        clip: true
        selectByMouse: true
        onTextEdited: debounce.restart()
        onEditingFinished: root.commit()

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
