pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "../../theme" as Theme
import "../../shell/theme"
import "../../components/animations" as Anim

// Кнопка со значком и именем подключённого Bluetooth-устройства и выпадающим окном
// с действиями «Отключить» / «Забыть устройство».
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
    property string fontFamily: "JetBrains Mono"
    property int animDuration: 220
    property int hoverDuration: 120
    property int iconSpacing: 6
    // Предел ширины имени устройства; что не влезло — прокручивается.
    property int labelMaxWidth: 96
    property int marqueePause: 1500
    property int marqueeMsPerPx: 35

    // Первое подключённое устройство или null.
    readonly property var device: Bluetooth.devices.values.find(d => d.connected) ?? null

    readonly property bool adapterEnabled: Bluetooth.defaultAdapter?.enabled ?? false

    // Значок Material Symbols по типу устройства (BluetoothDevice.icon — системное имя значка).
    readonly property string iconName: {
        if (!device)
            return adapterEnabled ? "bluetooth" : "bluetooth_disabled";
        const type = device.icon ?? "";
        if (type.includes("headset")) return "headset_mic";
        if (type.includes("headphone")) return "headphones";
        if (type.includes("audio")) return "speaker";
        if (type.includes("keyboard")) return "keyboard";
        if (type.includes("mouse")) return "mouse";
        if (type.includes("gaming")) return "sports_esports";
        if (type.includes("phone")) return "smartphone";
        if (type.includes("computer")) return "computer";
        return "bluetooth_connected";
    }
    readonly property int iconSize: Math.round(buttonHeight * 0.6)
    readonly property color contentColor: !device ? Theme.Palette.on_surface_variant
                                        : buttonArea.pressed ? Theme.Palette.on_secondary_container
                                        : open ? Theme.Palette.primary
                                        : Theme.Palette.on_surface

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
        implicitWidth: root.iconSize + root.iconSpacing + labelBox.width + root.buttonPaddingH * 2
        height: root.buttonHeight
        // Открытое меню — кнопка скругляется до пилюли
        radius: root.open ? height / 2 : root.buttonRadius
        color: buttonArea.pressed && root.device ? Theme.Palette.secondary_container
             : (buttonArea.containsMouse && root.device) || root.open ? Theme.Palette.surface_bright
             : Theme.Palette.surface_container_highest

        Behavior on color { ColorAnimation { duration: root.hoverDuration; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }
        Behavior on implicitWidth { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }

        Item {
            id: iconBox
            anchors.left: parent.left
            anchors.leftMargin: root.buttonPaddingH
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize
            scale: buttonArea.pressed ? 0.88 : buttonArea.containsMouse ? 1.1 : 1
            // Выключенный адаптер — значок приглушён
            opacity: root.adapterEnabled ? 1 : 0.6
            Behavior on scale { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: root.hoverDuration } }

            Item {
                id: icon
                property string name: root.iconName
                anchors.fill: parent

                // Контурный и залитый слои: заливка при открытом меню — их перекрёстное затухание
                Repeater {
                    model: 2
                    Text {
                        required property int index
                        anchors.centerIn: parent
                        text: icon.name
                        color: root.contentColor
                        opacity: (index === 1) === root.open ? 1 : 0
                        visible: opacity > 0
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: root.iconSize
                        font.variableAxes: ({ "FILL": index })
                        Behavior on opacity { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: root.hoverDuration } }
                    }
                }

                // Смена значка: старый сжимается и гаснет, новый проявляется
                Behavior on name {
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: icon; property: "scale"; to: 0.6; duration: root.hoverDuration / 2; easing.type: Easing.InCubic }
                            NumberAnimation { target: icon; property: "opacity"; to: 0; duration: root.hoverDuration / 2 }
                        }
                        PropertyAction {}
                        ParallelAnimation {
                            NumberAnimation { target: icon; property: "scale"; to: 1; duration: root.animDuration; easing.type: Easing.OutBack }
                            NumberAnimation { target: icon; property: "opacity"; to: 1; duration: root.hoverDuration }
                        }
                    }
                }
            }
        }

        // Окно для имени: длинное имя прокручивается по горизонтали
        Item {
            id: labelBox
            anchors.left: iconBox.right
            anchors.leftMargin: root.iconSpacing
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(label.implicitWidth, root.labelMaxWidth)
            height: label.implicitHeight
            clip: label.overflow > 0

            Text {
                id: label
                // Насколько текст шире окна (по целевой ширине, без учёта анимации)
                readonly property real overflow: Math.max(0, implicitWidth - root.labelMaxWidth)
                text: root.device ? (root.device.name || root.device.deviceName || root.device.address) : "Нет подключения"
                color: root.contentColor
                font.family: root.fontFamily
                font.pixelSize: root.buttonFontSize

                onOverflowChanged: if (marquee.running) marquee.restart()

                Behavior on color { ColorAnimation { duration: root.hoverDuration } }

                SequentialAnimation {
                    id: marquee
                    running: label.overflow > 0
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) label.x = 0

                    PauseAnimation { duration: root.marqueePause }
                    NumberAnimation { target: label; property: "x"; to: -label.overflow; duration: label.overflow * root.marqueeMsPerPx; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: root.marqueePause }
                    NumberAnimation { target: label; property: "x"; to: 0; duration: label.overflow * root.marqueeMsPerPx; easing.type: Easing.InOutSine }
                }
            }
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
        animDuration: root.animDuration
        onDismissed: root.open = false

        RowLayout {
            width: parent.width
            spacing: root.menuSpacing

            ActionButton {
                Layout.fillWidth: true
                text: "Отключить"
                onClicked: {
                    root.device?.disconnect();
                    root.open = false;
                }
            }

            ActionButton {
                Layout.fillWidth: true
                text: "Забыть устройство"
                danger: true
                onClicked: {
                    root.device?.forget();
                    root.open = false;
                }
            }
        }
    }
}
