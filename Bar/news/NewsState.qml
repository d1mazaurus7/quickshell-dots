import QtQuick
import "../../shell/config"
import "NewsTopics.js" as Topics

// Новости из RSS/Atom: темы и запросы Google News + свои ленты (Config.options.news).
// Загружает только пока active (окно открыто): при открытии, если данные устарели,
// и по таймеру refreshInterval. У RSS нет событий — без редкого опроса не обойтись.
Item {
    id: root

    readonly property var cfg: Config.options.news
    // Окно открыто
    property bool active: false

    // Источники: { key, title, url }
    readonly property var sources: {
        const list = [];
        for (let i = 0; i < cfg.topics.length; i++) {
            const id = cfg.topics[i];
            if (Topics.title(id) !== "")
                list.push({ key: "topic:" + id, title: Topics.title(id), url: Topics.topicUrl(id) });
        }
        for (let i = 0; i < cfg.queries.length; i++)
            list.push({ key: "query:" + cfg.queries[i], title: cfg.queries[i], url: Topics.queryUrl(cfg.queries[i]) });
        for (let i = 0; i < cfg.feeds.length; i++) {
            const url = cfg.feeds[i];
            list.push({ key: "feed:" + url, title: hostOf(url), url: url });
        }
        return list;
    }
    // Источники для показа: у своей ленты — название из её <title> после загрузки
    // (отдельно от sources, чтобы смена названия не запускала загрузку заново)
    readonly property var topics: sources.map(s => ({ key: s.key, title: feedTitles[s.url] ?? s.title }))

    // Новости всех источников: { title, link, source, topic (key источника), date (мс) },
    // без повторов по ссылке, новые сверху
    property var items: []
    property bool loading: false
    // Текст ошибки, если не загрузился ни один источник
    property string error: ""
    // Время последней загрузки, мс (0 — данных нет или источники изменились)
    property double lastUpdate: 0

    property var feedTitles: ({})
    // Номер текущей загрузки: ответы старых загрузок отбрасываются
    property int generation: 0

    function hostOf(url: string): string {
        const m = url.match(/^\w+:\/\/([^\/?#]+)/);
        return m ? m[1].replace(/^www\./, "") : url;
    }

    function refresh(): void {
        const list = sources;
        const gen = ++generation;
        if (list.length === 0) {
            items = [];
            error = "";
            loading = false;
            lastUpdate = Date.now();
            return;
        }
        loading = true;
        const results = [];
        let pending = list.length;
        let lastError = "";
        for (const source of list) {
            const xhr = new XMLHttpRequest();
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE || gen !== generation)
                    return;
                const feed = xhr.status === 200 ? parse(xhr.responseXML, source.key) : null;
                if (feed) {
                    results.push(...feed.items);
                    if (source.key.startsWith("feed:") && feed.title !== "" && feedTitles[source.url] !== feed.title) {
                        const titles = Object.assign({}, feedTitles);
                        titles[source.url] = feed.title;
                        feedTitles = titles;
                    }
                } else {
                    lastError = xhr.status === 0 ? "Нет соединения"
                        : xhr.status === 200 ? "Не удалось разобрать ленту"
                        : "HTTP " + xhr.status;
                }
                if (--pending === 0)
                    finish(results, lastError, results.length === 0);
            };
            xhr.open("GET", source.url);
            // responseXML заполняется только для XML-типов; часть лент отдаёт text/html
            xhr.overrideMimeType("text/xml");
            xhr.send();
        }
    }

    function finish(results: var, lastError: string, failed: bool): void {
        const seen = {};
        items = results
            .filter(i => i.link !== "" && !seen[i.link] && (seen[i.link] = true))
            .sort((a, b) => b.date - a.date);
        error = failed ? lastError : "";
        loading = false;
        lastUpdate = Date.now();
    }

    // Текст элемента: текстовые и CDATA-узлы
    function textOf(node: var): string {
        if (!node)
            return "";
        let s = "";
        const nodes = node.childNodes;
        for (let i = 0; i < nodes.length; i++)
            if (nodes[i].nodeType === 3 || nodes[i].nodeType === 4)
                s += nodes[i].nodeValue;
        return s.trim();
    }

    function elements(node: var, name: string): var {
        const list = [];
        const nodes = node.childNodes;
        for (let i = 0; i < nodes.length; i++)
            if (nodes[i].nodeType === 1 && nodes[i].nodeName === name)
                list.push(nodes[i]);
        return list;
    }

    function child(node: var, name: string): var {
        return elements(node, name)[0] ?? null;
    }

    function attr(node: var, name: string): string {
        const attrs = node.attributes;
        for (let i = 0; i < attrs.length; i++)
            if (attrs[i].name === name)
                return attrs[i].value;
        return "";
    }

    // RSS 2.0 (rss/channel/item) или Atom (feed/entry) → { title, items }
    function parse(doc: var, key: string): var {
        const rootNode = doc ? doc.documentElement : null;
        if (!rootNode)
            return null;
        const atom = rootNode.nodeName === "feed";
        const channel = atom ? rootNode : child(rootNode, "channel");
        if (!channel)
            return null;
        const feedTitle = textOf(child(channel, "title"));
        const list = [];
        for (const node of elements(channel, atom ? "entry" : "item")) {
            let link = "";
            if (atom) {
                for (const l of elements(node, "link"))
                    if (attr(l, "rel") === "" || attr(l, "rel") === "alternate") {
                        link = attr(l, "href");
                        break;
                    }
            } else {
                link = textOf(child(node, "link"));
            }
            // Google News: источник в <source>, а заголовок кончается на " - Источник"
            const source = textOf(child(node, "source")) || feedTitle;
            let title = textOf(child(node, "title"));
            if (source !== "" && title.endsWith(" - " + source))
                title = title.slice(0, -(source.length + 3));
            const dateText = textOf(child(node, atom ? "updated" : "pubDate")) || textOf(child(node, "published"));
            list.push({ title: title, link: link, source: source, topic: key, date: Date.parse(dateText) || 0 });
            if (list.length >= cfg.maxItems)
                break;
        }
        return { title: feedTitle, items: list };
    }

    // Источники изменились: в открытом окне — загрузить заново (с паузой на серию правок),
    // в закрытом — пометить данные устаревшими
    onSourcesChanged: {
        lastUpdate = 0;
        if (active)
            sourcesDebounce.restart();
    }
    onActiveChanged: {
        if (active && Date.now() - lastUpdate > cfg.refreshInterval * 60000)
            refresh();
    }

    Timer {
        id: sourcesDebounce
        interval: 500
        onTriggered: root.refresh()
    }

    Timer {
        interval: root.cfg.refreshInterval * 60000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
