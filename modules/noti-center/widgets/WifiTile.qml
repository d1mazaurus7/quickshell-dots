import QtQuick
import Quickshell.Networking
import "../controls"
import "../controls/Icons.js" as Icons

// Wi-Fi (или подключённый Ethernet); меню — страница сетей
SplitTile {
    required property var ctx
    readonly property var wired: ctx.wiredDevice

    s: ctx.s
    active: !!wired || Networking.wifiEnabled
    icon: wired ? Icons.ethernet : Icons.wifi
    slashed: !wired && !Networking.wifiEnabled
    title: wired ? "Ethernet" : "Wi-Fi"
    subtitle: wired
        ? (wired.network ? wired.network.name : wired.name) + (wired.linkSpeed > 0 ? " · " + wired.linkSpeed + " Мбит/с" : "")
        : !Networking.wifiEnabled ? "Выключен"
        : ctx.wifiNetwork ? ctx.wifiNetwork.name : "Не подключено"
    onToggled: {
        Networking.wifiEnabled = !Networking.wifiEnabled;
        ctx.play(Networking.wifiEnabled ? "power_on" : "power_off");
    }
    onExpand: {
        ctx.play("list");
        ctx.page = "wifi";
    }
}
