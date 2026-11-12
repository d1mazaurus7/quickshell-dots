import QtQuick
import "../controls"
import "../controls/Icons.js" as Icons

// Режим «Не беспокоить»
SplitTile {
    required property var ctx

    s: ctx.s
    expandable: false
    active: ctx.notifications.dnd
    icon: Icons.bell
    slashed: active
    title: "Не беспокоить"
    subtitle: active ? "Включено" : "Выключено"
    onToggled: {
        ctx.notifications.dnd = !ctx.notifications.dnd;
        ctx.play(ctx.notifications.dnd ? "power_on" : "power_off");
    }
}
