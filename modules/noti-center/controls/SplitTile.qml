import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"
import "Icons.js" as Icons

// Плитка MD3 из двух соединённых сегментов: слева иконка и подпись (вкл/выкл),
// справа кнопка меню (expand). Узкая плитка — только иконка, меню по ПКМ.
Item {
    id: tile

    required property real s
    property string icon
    property string title
    property string subtitle
    property bool active
    // Перечеркнуть иконку (анимированно), например «выключено»
    property bool slashed: false
    property bool expandable: true
    // Сдвигать иконку меню при нажатии в эту сторону (1 — вправо, -1 — влево, 0 — нет)
    property int menuSlideOnClick: 0

    readonly property bool compact: width < 120 * s
    // Подпись под названием — только у высокой плитки, как в референсе
    readonly property bool showSubtitle: subtitle !== "" && height >= 96 * s
    readonly property bool showMenu: expandable && !compact
    readonly property real outer: Math.min(height * 0.32, 24 * s)
    readonly property real inner: 4 * s
    readonly property color bgColor: active ? Theme.Palette.primary : Theme.Palette.surface_container_high
    readonly property color fgColor: active ? Theme.Palette.on_primary : Theme.Palette.on_surface

    signal toggled()
    signal expand()

    Rectangle {
        id: main
        // Сжатие внешних углов при нажатии
        property real k: mainArea.pressed ? 0.6 : 1
        Behavior on k { Emphasized {} }

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: tile.showMenu ? menu.left : parent.right
        anchors.rightMargin: tile.showMenu ? 3 * tile.s : 0
        topLeftRadius: tile.outer * k
        bottomLeftRadius: tile.outer * k
        topRightRadius: tile.showMenu ? tile.inner : tile.outer * k
        bottomRightRadius: tile.showMenu ? tile.inner : tile.outer * k
        color: tile.bgColor
        Behavior on color { SmoothColor {} }

        StateLayer {
            topLeftRadius: main.topLeftRadius
            bottomLeftRadius: main.bottomLeftRadius
            topRightRadius: main.topRightRadius
            bottomRightRadius: main.bottomRightRadius
            color: tile.fgColor
            hovered: mainArea.containsMouse
            pressed: mainArea.pressed
        }

        Rectangle {
            id: iconBox
            readonly property real side: Math.round(Math.min(main.height * 0.62, 40 * tile.s))
            x: tile.compact ? (main.width - width) / 2 : (main.height - width) / 2.4
            anchors.verticalCenter: parent.verticalCenter
            width: side
            height: side
            radius: side * 0.3
            color: tile.active ? "transparent" : Theme.Palette.secondary_container
            Behavior on color { SmoothColor {} }

            Icon {
                anchors.centerIn: parent
                text: tile.icon
                slashed: tile.slashed
                slashGap: tile.active ? tile.bgColor : iconBox.color
                size: iconBox.side * 0.55
                color: tile.active ? tile.fgColor : Theme.Palette.on_secondary_container
                Behavior on color { SmoothColor {} }
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: 8 * tile.s
            anchors.right: parent.right
            anchors.rightMargin: 6 * tile.s
            anchors.verticalCenter: parent.verticalCenter
            visible: !tile.compact
            spacing: 2 * tile.s

            Marquee {
                s: tile.s
                width: parent.width
                text: tile.title
                color: tile.fgColor
                family: Tokens.typography.family
                weight: Font.Medium
                pixelSize: Math.round(Math.min(13 * tile.s, tile.height * 0.25))
            }
            Marquee {
                s: tile.s
                width: parent.width
                visible: tile.showSubtitle
                text: tile.subtitle
                color: tile.fgColor
                family: Tokens.typography.family
                pixelSize: Math.round(11 * tile.s)
                opacity: 0.8
            }
        }

        MouseArea {
            id: mainArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (tile.expandable)
                        tile.expand();
                } else {
                    tile.toggled();
                }
            }
        }
    }

    Rectangle {
        id: menu
        property real k: menuArea.pressed ? 0.6 : 1
        Behavior on k { Emphasized {} }

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.round(Math.min(tile.height, 64 * tile.s) * 0.72)
        visible: tile.showMenu
        topLeftRadius: tile.inner
        bottomLeftRadius: tile.inner
        topRightRadius: tile.outer * k
        bottomRightRadius: tile.outer * k
        color: tile.bgColor
        Behavior on color { SmoothColor {} }

        StateLayer {
            topLeftRadius: menu.topLeftRadius
            bottomLeftRadius: menu.bottomLeftRadius
            topRightRadius: menu.topRightRadius
            bottomRightRadius: menu.bottomRightRadius
            color: tile.fgColor
            hovered: menuArea.containsMouse
            pressed: menuArea.pressed
        }

        Icon {
            id: menuIcon
            anchors.centerIn: parent
            text: Icons.menu
            size: 20 * tile.s
            color: tile.fgColor
            Behavior on color { SmoothColor {} }
        }

        MouseArea {
            id: menuArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (tile.menuSlideOnClick !== 0)
                    menuIcon.slide(tile.menuSlideOnClick);
                tile.expand();
            }
        }
    }
}
