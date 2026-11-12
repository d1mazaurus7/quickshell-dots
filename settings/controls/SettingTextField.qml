import QtQuick
import "../../shell/theme"

// M3 поле ввода: value — текущее значение (привязать к Config),
// edited(text) — после паузы в наборе или по окончании ввода; в Config пишет страница
Rectangle {
    id: root

    property string value
    property string placeholder
    // Скрывать ввод (ключи, пароли)
    property bool password: false

    signal edited(string text)
    // Enter в поле
    signal accepted(string text)

    readonly property var colors: Tokens.colors
    readonly property bool focused: input.activeFocus

    implicitWidth: Tokens.scaled(280)
    implicitHeight: Math.max(Tokens.scaled(44), input.implicitHeight + Tokens.spacingMediumV * 2)
    // Пилюля → скруглённый прямоугольник в фокусе
    radius: focused ? Tokens.radiusLarge : height / 2
    color: colors.surface_container_high
    border.width: focused ? 2 : Tokens.borderWidth
    border.color: focused ? colors.primary : colors.outline_variant
    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: Tokens.animationMedium } }

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

    // State layer (в фокусе hover не нужен)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.colors.on_surface
        opacity: area.containsMouse && !root.focused ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
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
        anchors.leftMargin: Tokens.spacingLarge
        anchors.rightMargin: Tokens.spacingLarge
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
        onAccepted: root.accepted(text)

        // Курсор цвета primary, мягко мигает
        cursorDelegate: Rectangle {
            width: 2
            color: root.colors.primary
            visible: input.cursorVisible
            SequentialAnimation on opacity {
                running: input.cursorVisible
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0; duration: Tokens.animationSlow; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 200 }
                NumberAnimation { to: 1; duration: Tokens.animationSlow; easing.type: Easing.InOutQuad }
                PauseAnimation { duration: 300 }
            }
        }

        Text {
            width: parent.width
            height: parent.height
            text: root.placeholder
            color: root.colors.on_surface_variant
            font: Tokens.fontMedium
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            // Плавно уезжает вправо и гаснет при вводе
            opacity: input.text === "" ? 1 : 0
            visible: opacity > 0
            x: input.text === "" ? 0 : Tokens.spacingMedium
            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
            Behavior on x { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }
    }
}
