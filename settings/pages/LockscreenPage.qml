pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Лок-скрин»: Config.options.lockscreen
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var lock: Config.options.lockscreen

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Лок-скрин"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Лок-скрин"
        description: "Блокировка экрана: qs ipc call lockscreen lock"

        SettingSwitch {
            checked: page.lock.enabled
            onToggled: checked => page.lock.enabled = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Блокировка при бездействии"
        description: "Блокировать экран, если нет ввода"

        SettingSwitch {
            checked: page.lock.idleLock
            onToggled: checked => page.lock.idleLock = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled && page.lock.idleLock
        child: true
        title: "Время бездействия"
        description: "Через сколько минут без ввода блокировать экран"

        SettingSlider {
            value: page.lock.idleTimeout
            from: 1
            to: 60
            stepSize: 1
            formatValue: v => Math.round(v) + " мин"
            onMoved: value => page.lock.idleTimeout = Math.round(value)
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Требовать пароль"
        description: "Выкл — разблокировка любой клавишей"

        SettingSwitch {
            checked: page.lock.requirePassword
            onToggled: checked => page.lock.requirePassword = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled && page.lock.requirePassword
        child: true
        title: "Свой пароль"
        description: "Вкл — свой пароль лок-скрина, выкл — пароль пользователя"

        SettingSwitch {
            checked: page.lock.customPasswordEnabled
            onToggled: checked => page.lock.customPasswordEnabled = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled && page.lock.requirePassword && page.lock.customPasswordEnabled
        child: true
        depth: 2
        title: "Пароль лок-скрина"
        description: page.lock.customPassword === "" ? "Не задан: разблокировка по Enter" : "Хранится в settings.json открытым текстом"

        SettingTextField {
            value: page.lock.customPassword
            placeholder: "Не задан"
            password: true
            onEdited: text => page.lock.customPassword = text
        }
    }

    SettingRow {
        shown: page.lock.enabled && page.lock.requirePassword
        child: true
        title: "Показывать пароль"
        description: "Символы пароля видны при вводе"

        SettingSwitch {
            checked: page.lock.showPassword
            onToggled: checked => page.lock.showPassword = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled && page.lock.requirePassword && !page.lock.showPassword
        child: true
        title: "Размер точек"
        description: "Диаметр точек при вводе пароля"

        SettingSlider {
            value: page.lock.dotSize
            from: 4
            to: 32
            stepSize: 1
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.lock.dotSize = Math.round(value)
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Анимация"
        description: "Плавная блокировка и разблокировка"

        SettingSwitch {
            checked: page.lock.animation
            onToggled: checked => page.lock.animation = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Виджеты"
        description: "Виджеты рабочего стола и лок-скрина; редактор — тот же бинд виджетов"

        SettingSwitch {
            checked: page.lock.widgets
            onToggled: checked => page.lock.widgets = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Скриншот как фон"
        description: "Рабочий стол в момент блокировки"

        SettingSwitch {
            checked: page.lock.screenshotBackground
            onToggled: checked => {
                if (checked)
                    page.lock.wallpaperBackground = false;
                page.lock.screenshotBackground = checked;
            }
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Обои как фон"
        description: "Текущие обои, включая видео"

        SettingSwitch {
            checked: page.lock.wallpaperBackground
            onToggled: checked => {
                if (checked)
                    page.lock.screenshotBackground = false;
                page.lock.wallpaperBackground = checked;
            }
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Размытие фона"
        description: "Размывать фон лок-скрина"

        SettingSwitch {
            checked: page.lock.blur
            onToggled: checked => page.lock.blur = checked
        }
    }

    SettingRow {
        shown: page.lock.enabled
        title: "Скрывать уведомления"
        description: "Не показывать всплывающие уведомления на лок-скрине"

        SettingSwitch {
            checked: page.lock.hideNotifications
            onToggled: checked => page.lock.hideNotifications = checked
        }
    }
}
