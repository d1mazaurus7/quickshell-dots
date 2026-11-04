import QtQuick
import "../shell/config"
import "../shell/theme"

// Экземпляры виджетов (Config.options.widgets.items) и состояние редактора.
// Все записи в настройки виджетов — только через функции этого объекта
QtObject {
    id: root

    readonly property WidgetRegistry registry: WidgetRegistry {}
    readonly property var cfg: Config.options.widgets
    readonly property var items: cfg.items
    // uid — модель окон: строки сохраняют окна при переприсваивании items
    readonly property var uids: items.map(i => i.uid)
    // Модель окон с порядком наложения: сначала виджеты с settings.lower («на слой ниже»).
    // Внутри слоя niri кладёт позже созданную поверхность выше, поэтому нижние создаются первыми.
    // Ключ = uid + "#" + список нижних: при смене списка все окна пересоздаются в новом порядке
    readonly property var windowKeys: {
        const lowered = uids.filter(u => settingsOf(u).lower === true);
        const sig = lowered.join(",");
        return lowered.concat(uids.filter(u => !lowered.includes(u))).map(u => u + "#" + sig);
    }
    readonly property var byUid: {
        const m = {};
        for (const i of items)
            m[i.uid] = i;
        return m;
    }

    // Общие сервисы оболочки для виджетов, объявивших property var services
    property var services: ({})

    // Редактор
    property bool editing: false
    // Монитор, на котором открыт редактор
    property string editorOutput: ""
    property string selectedUid: ""
    property bool moveMode: false
    property bool settingsOpen: false
    property bool addOpen: false
    readonly property var selected: byUid[selectedUid] ?? null
    // Шаг сетки при движении слайдера; 0 — из настроек
    property real gridLive: 0

    // Геометрия во время перетаскивания или движения слайдера — в файл не пишется
    property string previewUid: ""
    property real previewX: 0
    property real previewY: 0
    property real previewWidth: 0
    property real previewHeight: 0

    onEditingChanged: {
        if (editing)
            return;
        moveMode = false;
        settingsOpen = false;
        addOpen = false;
        selectedUid = "";
        previewUid = "";
    }
    onSelectedUidChanged: {
        if (selectedUid !== "")
            return;
        moveMode = false;
        settingsOpen = false;
    }

    function geometry(uid: string): var {
        const i = byUid[uid];
        if (previewUid === uid)
            return { x: previewX, y: previewY, width: previewWidth, height: previewHeight };
        return i ? { x: i.x, y: i.y, width: i.width, height: i.height } : { x: 0, y: 0, width: 0, height: 0 };
    }

    // Настройки экземпляра с дефолтами типа
    function settingsOf(uid: string): var {
        const i = byUid[uid];
        const t = i ? registry.find(i.type) : null;
        return Object.assign({}, t?.defaults ?? {}, i?.settings ?? {});
    }

    function startPreview(uid: string): void {
        const g = geometry(uid);
        previewX = g.x;
        previewY = g.y;
        previewWidth = g.width;
        previewHeight = g.height;
        previewUid = uid;
    }

    function update(uid: string, patch: var): void {
        Config.options.widgets.items = items.map(i => i.uid === uid ? Object.assign({}, i, patch) : i);
    }

    function commitPreview(): void {
        if (previewUid === "")
            return;
        update(previewUid, {
            x: Math.round(previewX), y: Math.round(previewY),
            width: Math.round(previewWidth), height: Math.round(previewHeight)
        });
        previewUid = "";
    }

    function setSetting(uid: string, key: string, value: var): void {
        const i = byUid[uid];
        if (!i)
            return;
        const s = Object.assign({}, i.settings ?? {});
        s[key] = value;
        update(uid, { settings: s });
    }

    // Новый виджет по центру экрана редактора
    function add(type: string, screenWidth: real, screenHeight: real): void {
        const t = registry.find(type);
        if (!t)
            return;
        const w = Tokens.scaled(t.width);
        const h = Tokens.scaled(t.height);
        const uid = type + "-" + Date.now().toString(36);
        Config.options.widgets.items = items.concat([{
            uid: uid, type: type, screen: editorOutput,
            x: Math.round((screenWidth - w) / 2), y: Math.round((screenHeight - h) / 2),
            width: w, height: h,
            settings: {}
        }]);
        addOpen = false;
        selectedUid = uid;
    }

    function remove(uid: string): void {
        if (selectedUid === uid)
            selectedUid = "";
        Config.options.widgets.items = items.filter(i => i.uid !== uid);
    }
}
