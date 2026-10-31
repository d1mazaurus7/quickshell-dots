pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Звук»: Config.options.sound
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var sound: Config.options.sound
    // Все звуки из assets/sounds
    readonly property var sounds: [
        "button.wav",
        "click.wav",
        "list.wav",
        "power_off.wav",
        "power_on.wav",
        "sfx.wav",
        "transition_serp.wav",
        "type.wav"
    ]

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Звук"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        z: typeDropdown.expanded ? 1 : 0
        title: "Звук печати"
        description: "Звук при наборе текста в лаунчере"

        SettingDropdown {
            id: typeDropdown
            model: page.sounds
            currentValue: page.sound.typeSound
            searchable: true
            popupHeight: Tokens.scaled(180)
            onActivated: value => page.sound.typeSound = value
        }
    }

    SettingRow {
        z: clickDropdown.expanded ? 1 : 0
        title: "Звук клика"
        description: "Звук нажатия кнопок скриншотов и окна громкости"

        SettingDropdown {
            id: clickDropdown
            model: page.sounds
            currentValue: page.sound.clickSound
            searchable: true
            popupHeight: Tokens.scaled(180)
            onActivated: value => page.sound.clickSound = value
        }
    }

    SettingRow {
        z: notifyDropdown.expanded ? 1 : 0
        title: "Звук уведомления"
        description: "Пока не интегрирован"

        SettingDropdown {
            id: notifyDropdown
            model: page.sounds
            currentValue: page.sound.notificationSound
            searchable: true
            popupHeight: Tokens.scaled(180)
            onActivated: value => page.sound.notificationSound = value
        }
    }

    SettingRow {
        title: "Окно громкости"
        description: "Микшер приложений по клику на модуль звука в баре"

        SettingSwitch {
            checked: page.sound.mixer
            onToggled: checked => page.sound.mixer = checked
        }
    }

    SettingRow {
        child: true
        shown: page.sound.mixer
        title: "Выходы"
        description: "Громкость воспроизводящих приложений"

        SettingSwitch {
            checked: page.sound.mixerOutputs
            onToggled: checked => page.sound.mixerOutputs = checked
        }
    }

    SettingRow {
        child: true
        shown: page.sound.mixer
        title: "Входы"
        description: "Громкость записывающих приложений"

        SettingSwitch {
            checked: page.sound.mixerInputs
            onToggled: checked => page.sound.mixerInputs = checked
        }
    }

    SettingRow {
        child: true
        shown: page.sound.mixer
        title: "Кнопки перезагрузки"
        description: "Перезапуск WirePlumber и EasyEffects"

        SettingSwitch {
            checked: page.sound.mixerRestart
            onToggled: checked => page.sound.mixerRestart = checked
        }
    }
}
