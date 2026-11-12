import QtQuick
import "../../shell/config"
import "controls"
import "controls/Icons.js" as Icons

// Страница настроек скриншотов (те же параметры, что в настройках оболочки)
Column {
    id: page

    required property var ctx
    readonly property real s: ctx.s
    readonly property var cfg: Config.options.screenshot

    spacing: 16 * s

    function toggle(key: string): void {
        ctx.play("click");
        cfg[key] = !cfg[key];
    }

    PageSection {
        s: page.s
        title: "После выделения"
        Segmented {
            width: parent.width
            s: page.s
            options: [
                { value: false, label: "Панель", icon: Icons.edit },
                { value: true, label: "Сразу снимок", icon: Icons.flash }
            ]
            current: page.cfg.instant
            onPicked: v => {
                page.ctx.play("click");
                page.cfg.instant = v;
            }
        }
    }

    PageSection {
        s: page.s
        title: "Параметры"
        Row {
            width: parent.width
            spacing: 8 * page.s
            readonly property real cellWidth: (width - spacing * 2) / 3

            ToggleButton {
                width: parent.cellWidth
                s: page.s
                icon: Icons.brush
                label: "Правка"
                checked: page.cfg.editTools
                // Инструменты есть только на панели
                enabled: !page.cfg.instant
                opacity: enabled ? 1 : 0.5
                Behavior on opacity { Smooth {} }
                onClicked: page.toggle("editTools")
            }
            ToggleButton {
                width: parent.cellWidth
                s: page.s
                icon: Icons.volume
                label: "Звук"
                checked: page.cfg.sound
                onClicked: page.toggle("sound")
            }
            ToggleButton {
                width: parent.cellWidth
                s: page.s
                icon: Icons.bell
                label: "Уведомление"
                checked: page.cfg.notify
                onClicked: page.toggle("notify")
            }
        }
    }
}
