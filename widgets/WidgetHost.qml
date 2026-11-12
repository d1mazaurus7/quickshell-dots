import QtQuick

// Загрузка компонента виджета экземпляра uid и привязка settings/services/editing.
// Общий для окон рабочего стола (WidgetWindow) и лок-скрина
Item {
    id: root

    required property string uid
    required property WidgetsState widgets

    readonly property var item: widgets.byUid[uid] ?? null
    readonly property var entry: item ? widgets.find(item.type) : null
    // Необязательные blurItem / blurShape виджета: что размывать под ним
    readonly property Item blurItem: loader.wantsBlur ? loader.item.blurItem : null
    readonly property var blurShape: loader.wantsShape ? loader.item.blurShape : null

    Loader {
        id: loader
        anchors.fill: parent
        // settings — сразу при создании, иначе привязки виджета видят пустой объект
        Component.onCompleted: {
            if (root.entry)
                setSource(root.entry.component, { settings: root.widgets.settingsOf(root.uid) });
        }
        // Необязательные свойства проверяются один раз, без привязки к самим свойствам
        property bool wantsServices: false
        property bool wantsBlur: false
        property bool wantsShape: false
        onLoaded: {
            wantsServices = "services" in item;
            wantsBlur = "blurItem" in item;
            wantsShape = "blurShape" in item;
        }
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
