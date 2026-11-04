pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/config"
import "../../shell/theme"
import "../../theme" as Theme
import "../../components/animations" as Anim
import "WeatherCodes.js" as Codes

// Кнопка погоды в баре: значок и температура; по нажатию — окно прогноза (BarDropdown).
Item {
    id: root

    property real barHeight: 40
    // Имя монитора бара; окно открыто, если WeatherState.openOutput совпадает с ним
    property string output: ""
    readonly property bool open: output !== "" && w.openOutput === output

    readonly property var colors: Tokens.colors
    readonly property var w: WeatherState
    readonly property int buttonHeight: Math.max(0, barHeight - Tokens.scaled(6) * 2)

    // Закрытое окно сбрасывает выбранный час
    onOpenChanged: if (!open) panel.minuteOffset = 0

    implicitWidth: button.width
    implicitHeight: buttonHeight

    function toggle() {
        if (!open && dropdown.recentlyDismissed())
            return;
        w.openOutput = open ? "" : output;
    }

    Component.onDestruction: if (open) w.openOutput = ""

    Rectangle {
        id: button
        anchors.verticalCenter: parent.verticalCenter
        width: content.implicitWidth + Tokens.spacingMedium * 2
        height: root.buttonHeight
        radius: Tokens.radiusMedium
        color: area.pressed ? root.colors.secondary_container
             : area.containsMouse || root.open ? root.colors.surface_bright
             : root.colors.surface_container_highest
        Behavior on color { ColorAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: Tokens.spacingSmall

            readonly property color textColor: area.pressed ? root.colors.on_secondary_container
                                             : root.open ? root.colors.primary
                                             : root.colors.on_surface

            WeatherGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: root.w.ready ? Codes.icon(root.w.current.code, root.w.current.isDay) : "cloud"
                night: root.w.ready && !root.w.current.isDay
                colored: Config.options.weather.iconStyle === "colored"
                tint: content.textColor
                size: Tokens.scaled(20)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.w.ready ? Codes.temp(root.w.current.temp) : "--°"
                color: content.textColor
                font: Tokens.fontMedium
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle()
        }
    }

    Anim.BarDropdown {
        id: dropdown
        anchorItem: button
        open: root.open
        contentWidth: Math.round(Tokens.scaled(520) * panel.zoom)
        padding: Tokens.spacingMedium
        radius: Tokens.radiusLarge
        animDuration: Tokens.animationMedium
        // Окно постоянной высоты (до низа экрана): раскрытие карточек не меняет размер окна,
        // а его фигура следует за содержимым без своей анимации — без дрожания
        maxHeight: Math.max(0, (root.QsWindow.window?.screen?.height ?? 0) - root.barHeight - Tokens.scaled(16))
        animateResize: false
        // С фоном на всё окно «уши» окрашены верхом неба
        fillColor: panel.fullSky ? panel.skyTop : Theme.Palette.background
        Behavior on fillColor { ColorAnimation { duration: Tokens.animationSlow } }
        onDismissed: if (root.open) root.w.openOutput = ""

        WeatherPanel {
            id: panel
            width: parent.width
            bleed: dropdown.padding
            topRadius: dropdown.topRadius
            bottomRadius: dropdown.radius
            revealHeight: dropdown.revealHeight
            skyHeight: dropdown.implicitHeight
        }
    }
}
