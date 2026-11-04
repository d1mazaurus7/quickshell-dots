import QtQuick
import Quickshell
import Quickshell.Wayland

// Окно одного экземпляра виджета на нижнем слое (над обоями, под окнами)
PanelWindow {
    id: root

    required property string uid
    required property WidgetsState widgets

    readonly property var item: widgets.byUid[uid] ?? null
    readonly property var entry: item ? widgets.registry.find(item.type) : null
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

    Loader {
        id: loader
        anchors.fill: parent
        // settings — сразу при создании, иначе привязки виджета видят пустой объект
        Component.onCompleted: {
            if (root.entry)
                setSource(root.entry.component, { settings: root.widgets.settingsOf(root.uid) });
        }
        // services нужны не всем виджетам; проверяем один раз, без привязки к самому свойству
        property bool wantsServices: false
        onLoaded: wantsServices = "services" in item
    }
    Binding {
        target: loader.item
        property: "settings"
        value: root.widgets.settingsOf(root.uid)
        when: loader.status === Loader.Ready
    }
    Binding {
        target: loader.item
        property: "services"
        value: root.widgets.services
        when: loader.status === Loader.Ready && loader.wantsServices
    }
    Binding {
        target: loader.item
        property: "editing"
        value: root.widgets.editing
        when: loader.status === Loader.Ready
    }
}
