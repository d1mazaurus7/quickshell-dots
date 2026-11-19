pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/config"
import "../../shell/theme"
import "../../components/animations" as Anim

// Громкость в баре: колесо мыши меняет громкость, клик открывает окно микшера.
// Использование в bar:
//   import "../modules/volume" as Volume
//   Volume.Volume { barHeight: barWindow.implicitHeight }
Item {
    id: root

    property real barHeight: 40
    property real vMargin: 6
    readonly property int buttonHeight: Math.max(0, barHeight - vMargin * 2)
    readonly property int buttonFontSize: Math.round(buttonHeight * 0.43)
    // Шаг громкости на одно деление колеса
    property real wheelStep: 0.05

    readonly property var colors: Tokens.colors
    readonly property var cfg: Config.options.sound
    readonly property bool mixerEnabled: cfg.mixer

    property bool open: false

    implicitWidth: button.implicitWidth
    implicitHeight: buttonHeight

    onMixerEnabledChanged: if (!mixerEnabled) open = false

    function toggle() {
        if (!mixerEnabled || (!open && dropdown.recentlyDismissed()))
            return;
        open = !open;
    }

    VolumeState { id: volumeState }

    // Ширина под «100%», чтобы кнопка не дёргалась при смене значения
    TextMetrics {
        id: metrics
        font.family: Tokens.fontMedium.family
        font.pixelSize: root.buttonFontSize
        text: "100%"
    }

    readonly property int percent: Math.round(volumeState.volume * 100)
    readonly property string iconName: volumeState.muted ? "volume_off"
                                     : percent === 0 ? "volume_mute"
                                     : percent < 50 ? "volume_down"
                                     : "volume_up"
    readonly property int iconSize: Math.round(buttonHeight * 0.6)
    readonly property color contentColor: volumeState.muted ? colors.on_surface_variant
                                        : area.pressed ? colors.on_secondary_container
                                        : open ? colors.primary
                                        : colors.on_surface
    // Плавный счётчик процентов
    property real shownPercent: percent
    Behavior on shownPercent { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

    Rectangle {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.iconSize + Tokens.spacingSmall + metrics.width + Tokens.spacingLarge * 2
        height: root.buttonHeight
        // Открытый микшер — кнопка скругляется до пилюли
        radius: root.open ? height / 2 : Tokens.radius(8)
        color: area.pressed ? root.colors.secondary_container
             : area.containsMouse || root.open ? root.colors.surface_bright
             : root.colors.surface_container_highest
        Behavior on color { ColorAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

        Item {
            id: iconBox
            anchors.left: parent.left
            anchors.leftMargin: Tokens.spacingLarge
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize
            scale: area.pressed ? 0.88 : area.containsMouse ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }

            Item {
                id: icon
                property string name: root.iconName
                anchors.fill: parent

                // Контурный и залитый слои: заливка при открытом микшере — их перекрёстное затухание
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
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                    }
                }

                // Смена значка: старый сжимается и гаснет, новый проявляется
                Behavior on name {
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: icon; property: "scale"; to: 0.6; duration: Tokens.animationFast / 2; easing.type: Easing.InCubic }
                            NumberAnimation { target: icon; property: "opacity"; to: 0; duration: Tokens.animationFast / 2 }
                        }
                        PropertyAction {}
                        ParallelAnimation {
                            NumberAnimation { target: icon; property: "scale"; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutBack }
                            NumberAnimation { target: icon; property: "opacity"; to: 1; duration: Tokens.animationFast }
                        }
                    }
                }
            }
        }

        Text {
            id: label
            anchors.left: iconBox.right
            anchors.leftMargin: Tokens.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            width: metrics.width
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(root.shownPercent) + "%"
            color: root.contentColor
            opacity: volumeState.muted ? 0.7 : 1
            font.family: Tokens.fontMedium.family
            font.pixelSize: root.buttonFontSize
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.mixerEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    volumeState.toggleMute();
                else
                    root.toggle();
            }
            onWheel: wheel => {
                if (wheel.angleDelta.y !== 0)
                    volumeState.setVolume(volumeState.volume + (wheel.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep));
            }
        }
    }

    Anim.BarDropdown {
        id: dropdown
        anchorItem: button
        open: root.open
        contentWidth: Tokens.scaled(420)
        padding: Tokens.spacingLarge
        onDismissed: root.open = false

        VolumeMixer {
            width: parent.width
            audio: volumeState
            showOutputs: root.cfg.mixerOutputs
            showInputs: root.cfg.mixerInputs
            showRestart: root.cfg.mixerRestart
        }
    }
}
