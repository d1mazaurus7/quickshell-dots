import QtQuick
import Quickshell
import Quickshell.Wayland

// Окно одного экземпляра виджета на нижнем слое (над обоями, под окнами)
PanelWindow {
    id: root

    required property string uid
    required property WidgetsState widgets

    readonly property var item: widgets.byUid[uid] ?? null
    readonly property var entry: item ? widgets.find(item.type) : null
    readonly property var geo: widgets.geometry(uid)

    screen: Quickshell.screens.find(s => s.name === root.item?.screen) ?? Quickshell.screens[0]
    visible: entry !== null
    color: "transparent"

    anchors {
        top: true
        left: true
    }
    margins {
        left: Math.round(geo.x)
        top: Math.round(geo.y)
    }
    implicitWidth: Math.max(1, Math.round(geo.width))
    implicitHeight: Math.max(1, Math.round(geo.height))

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "qs:widget"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Размытие под виджетом (ext-background-effect-v1): область — host.blurShape (своя Region
    // виджета, например по форме спектра) или host.blurItem со скруглением
    BackgroundEffect.blurRegion: host.blurShape ?? (host.blurItem ? blurRegion : null)
    Region {
        id: blurRegion
        item: host.blurItem
        radius: host.blurItem?.radius ?? 0
    }

    WidgetHost {
        id: host
        anchors.fill: parent
        uid: root.uid
        widgets: root.widgets
    }
}
