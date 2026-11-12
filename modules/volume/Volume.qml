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

    Rectangle {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Math.max(label.implicitWidth, metrics.width) + Tokens.spacingLarge * 2
        height: root.buttonHeight
        radius: Tokens.radius(8)
        color: area.pressed ? root.colors.secondary_container
             : area.containsMouse || root.open ? root.colors.surface_bright
             : root.colors.surface_container_highest
        Behavior on color { ColorAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        Text {
            id: label
            anchors.centerIn: parent
            text: Math.round(volumeState.volume * 100) + "%"
            color: volumeState.muted ? root.colors.on_surface_variant
                 : area.pressed ? root.colors.on_secondary_container
                 : root.open ? root.colors.primary
                 : root.colors.on_surface
            font.family: Tokens.fontMedium.family
            font.pixelSize: root.buttonFontSize
            Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.mixerEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.toggle()
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
