import QtQuick
import "../controls"
import "../controls/Icons.js" as Icons

// Bluetooth; меню — страница устройств
SplitTile {
    required property var ctx
    readonly property var adapter: ctx.btAdapter

    s: ctx.s
    active: !!adapter && adapter.enabled
    icon: Icons.bluetooth
    slashed: !active
    title: "Bluetooth"
    subtitle: !adapter ? "Нет адаптера"
        : !adapter.enabled ? "Выключен"
        : ctx.btDevice ? ctx.btDevice.name : "Не подключено"
    onToggled: {
        if (!adapter)
            return;
        adapter.enabled = !adapter.enabled;
        ctx.play(adapter.enabled ? "power_on" : "power_off");
    }
    onExpand: {
        ctx.play("list");
        ctx.page = "bluetooth";
    }
}
