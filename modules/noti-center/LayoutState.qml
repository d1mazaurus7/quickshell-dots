import QtQuick
import "../../shell/config"
import "widgets/Registry.js" as Registry

// Раскладка виджетов центра: ListModel ⇄ Config.options.notiCenter.layout.
// Модель меняется на месте (move/setProperty), поэтому виджеты не пересоздаются.
QtObject {
    id: st

    // undefined, пока settings.json не прочитан: раскладка не строится сначала по умолчанию
    readonly property var saved: Config.ready ? Config.options.notiCenter.layout : undefined
    readonly property ListModel model: ListModel {}

    function serialize(): var {
        const out = [];
        for (let i = 0; i < model.count; i++) {
            const it = model.get(i);
            out.push({ type: it.type, w: it.w, h: it.h });
        }
        return out;
    }

    function load(): void {
        if (!Config.ready)
            return;
        // Прочитанный из settings.json список приходит не JS-массивом
        // (Array.isArray === false), поэтому проверяется length
        const cur = Config.options.notiCenter.layout;
        const src = cur && cur.length !== undefined ? cur : Registry.defaults;
        const list = [];
        for (let i = 0; i < src.length; i++) {
            const it = src[i];
            const sp = Registry.find(it.type);
            if (!sp || list.some(l => l.type === it.type))
                continue;
            list.push({
                type: it.type,
                w: Math.max(sp.minW, Math.min(sp.maxW, it.w ?? sp.w)),
                h: Math.max(sp.minH, Math.min(sp.maxH, it.h ?? sp.h))
            });
        }
        if (JSON.stringify(list) === JSON.stringify(serialize()))
            return;
        model.clear();
        for (const l of list)
            model.append(l);
    }

    function save(): void {
        Config.options.notiCenter.layout = serialize();
    }

    onSavedChanged: load()
    Component.onCompleted: load()
}
