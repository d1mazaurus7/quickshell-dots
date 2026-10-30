pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../../theme" as Theme
import "../../shell/theme"
import "../../components/animations" as Anim

// Кнопка с именем подключённого Bluetooth-устройства и выпадающим окном
// с действиями "Disconnect" / "Forget device".
// Использование в bar:
//   import "../modules/bluetooth" as Bluetooth
//   Bluetooth.Bluetooth {}
Item {
    id: root

    // Локальные параметры оформления (как в Tray).
    property real barHeight: 40
    property real vMargin: 6
    property int buttonPaddingH: 12
    readonly property int buttonHeight: Math.max(0, barHeight - vMargin * 2)
    property int buttonRadius: Tokens.radius(8)
    readonly property int buttonFontSize: Math.round(buttonHeight * 0.43)
    property int menuWidth: 320
    property int menuRadius: Tokens.radius(16)
    property int menuPadding: 12
    property int menuSpacing: 12
    property int actionHeight: 36
    property int actionRadius: Tokens.radius(12)
    property int actionFontSize: 13
    // Радиус вогнутых скруглений ("ушей") в месте стыка окна с баром.
    property int earRadius: Tokens.radius(16)
    // Радиус нижних углов бара: уши не должны заходить на них.
    property int barRadius: Tokens.radius(20)
    property string fontFamily: "JetBrains Mono"
    property int animDuration: 220
    property int hoverDuration: 120

    // Первое подключённое устройство или null.
    readonly property var device: Bluetooth.devices.values.find(d => d.connected) ?? null

    property bool open: false

    implicitWidth: button.implicitWidth
    implicitHeight: buttonHeight

    onDeviceChanged: if (!device) open = false

    function toggle() {
        if (!device || (!open && dropdown.recentlyDismissed()))
            return;
        open = !open;
    }

    component ActionButton: Rectangle {
        id: action

        required property string text
        property bool danger: false
        signal clicked()

        implicitHeight: root.actionHeight
        radius: root.actionRadius
        color: area.pressed ? (danger ? Theme.Palette.error : Theme.Palette.secondary_container)
             : area.containsMouse ? (danger ? Theme.Palette.error_container : Theme.Palette.surface_bright)
             : Theme.Palette.surface_container_highest

        Behavior on color { ColorAnimation { duration: root.hoverDuration; easing.type: Easing.OutCubic } }

        Text {
            anchors.centerIn: parent
            text: action.text
            color: area.pressed ? (action.danger ? Theme.Palette.on_error : Theme.Palette.on_secondary_container)
                 : area.containsMouse && action.danger ? Theme.Palette.on_error_container
                 : Theme.Palette.on_surface
            font.family: root.fontFamily
            font.pixelSize: root.actionFontSize

            Behavior on color { ColorAnimation { duration: root.hoverDuration } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }

    Rectangle {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: label.implicitWidth + root.buttonPaddingH * 2
        height: root.buttonHeight
        radius: root.buttonRadius
        color: buttonArea.pressed && root.device ? Theme.Palette.secondary_container
             : (buttonArea.containsMouse && root.device) || root.open ? Theme.Palette.surface_bright
             : Theme.Palette.surface_container_highest

        Behavior on color { ColorAnimation { duration: root.hoverDuration; easing.type: Easing.OutCubic } }
        Behavior on implicitWidth { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.device ? (root.device.name || root.device.deviceName || root.device.address) : "No connection"
            color: !root.device ? Theme.Palette.on_surface_variant
                 : buttonArea.pressed ? Theme.Palette.on_secondary_container
                 : root.open ? Theme.Palette.primary
                 : Theme.Palette.on_surface
            font.family: root.fontFamily
            font.pixelSize: root.buttonFontSize

            Behavior on color { ColorAnimation { duration: root.hoverDuration } }
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.device ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.toggle()
        }
    }

    Anim.BarDropdown {
        id: dropdown
        anchorItem: button
        open: root.open
        contentWidth: root.menuWidth
        padding: root.menuPadding
        radius: root.menuRadius
        earRadius: root.earRadius
        barRadius: root.barRadius
        animDuration: root.animDuration
        onDismissed: root.open = false

        RowLayout {
            width: parent.width
            spacing: root.menuSpacing

            ActionButton {
                Layout.fillWidth: true
                text: "Disconnect"
                onClicked: {
                    root.device?.disconnect();
                    root.open = false;
                }
            }

            ActionButton {
                Layout.fillWidth: true
                text: "Forget device"
                danger: true
                onClicked: {
                    root.device?.forget();
                    root.open = false;
                }
            }
        }
    }
}
