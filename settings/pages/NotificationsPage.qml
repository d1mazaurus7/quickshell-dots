pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Уведомления»: Config.options.notiCenter
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var noti: Config.options.notiCenter
    readonly property var directions: ({ both: "В обе стороны", right: "Вправо", left: "Влево" })

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Уведомления"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        z: sideDropdown.expanded ? 1 : 0
        title: "Появление"
        description: "С какой стороны экрана всплывают уведомления"

        SettingDropdown {
            id: sideDropdown
            model: ["Справа", "Слева"]
            popupHeight: Tokens.scaled(96)
            currentValue: page.noti.popupSide === "left" ? "Слева" : "Справа"
            onActivated: value => page.noti.popupSide = value === "Слева" ? "left" : "right"
        }
    }

    SettingRow {
        title: "Смахивание"
        description: "Убирать уведомление перетаскиванием мышью"

        SettingSwitch {
            checked: page.noti.swipe
            onToggled: checked => page.noti.swipe = checked
        }
    }

    SettingRow {
        z: dirDropdown.expanded ? 1 : 0
        shown: page.noti.swipe
        child: true
        title: "Направление"
        description: "В какую сторону можно смахнуть"

        SettingDropdown {
            id: dirDropdown
            model: ["В обе стороны", "Вправо", "Влево"]
            popupHeight: Tokens.scaled(136)
            currentValue: page.directions[page.noti.swipeDirection] ?? "В обе стороны"
            onActivated: value => page.noti.swipeDirection = Object.keys(page.directions).find(k => page.directions[k] === value)
        }
    }

    SettingRow {
        title: "Звук уведомлений"
        description: "Звук при новом уведомлении (пока не работает)"

        SettingSwitch {
            checked: page.noti.sound
            onToggled: checked => page.noti.sound = checked
        }
    }
}
