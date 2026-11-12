import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Текст песни для текущего трека: кэш на диске, иначе LRCLIB (lrclib.net).
// Синхронизированный текст (LRC) разбирается в строки с временем начала.
Item {
    id: root

    property MprisPlayer player: null
    // Загрузка при смене трека, даже при закрытом окне — к открытию текст уже готов
    property bool active: false
    // Позиция трека, сек
    property real position: 0

    // [{ time, text }]; у несинхронизированного текста time = -1
    property var lines: []
    property bool synced: false
    // "idle" | "loading" | "ready" | "instrumental" | "notfound" | "error"
    property string status: "idle"
    readonly property int currentIndex: synced ? indexAt(position) : -1

    // Строка подсвечивается чуть раньше: на слух текст всё равно чуть запаздывает
    readonly property real lead: 0.15
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/lyrics"
    readonly property string api: "https://lrclib.net/api"

    property string key: ""

    function indexAt(pos: real): int {
        let lo = 0, hi = lines.length - 1, res = -1;
        const t = pos + lead;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].time <= t) {
                res = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return res;
    }

    function parseLrc(src: string): var {
        const out = [];
        let offset = 0;
        const tag = /^\s*\[(\d+):(\d+(?:\.\d+)?)\]/;
        for (const raw of src.split(/\r?\n/)) {
            const o = raw.match(/^\s*\[offset:\s*([+-]?\d+)\s*\]/i);
            if (o) {
                offset = Number(o[1]) / 1000;
                continue;
            }
            const times = [];
            let rest = raw, m;
            while ((m = rest.match(tag))) {
                times.push(Number(m[1]) * 60 + Number(m[2]));
                rest = rest.slice(m[0].length);
            }
            const text = rest.trim() || "♪";
            for (const t of times)
                out.push({ time: Math.max(0, t - offset), text: text });
        }
        return out.sort((a, b) => a.time - b.time);
    }

    function parsePlain(src: string): var {
        return src.split(/\r?\n/).map(s => ({ time: -1, text: s.trim() }));
    }

    // data: { synced, plain, instrumental } — тот же формат лежит в кэше
    function apply(data: var) {
        const s = data.synced ? parseLrc(data.synced) : [];
        if (s.length > 0) {
            lines = s;
            synced = true;
            status = "ready";
        } else if (data.plain) {
            lines = parsePlain(data.plain);
            synced = false;
            status = "ready";
        } else {
            lines = [];
            synced = false;
            status = data.instrumental ? "instrumental" : "notfound";
        }
    }

    function makeKey(): string {
        if (!player || !player.trackTitle) return "";
        const raw = (player.trackArtist || "") + " - " + player.trackTitle + " - " + Math.round(player.length > 0 ? player.length : 0);
        return raw.replace(/[\/\\:*?"<>|\x00-\x1f]/g, "_").slice(0, 150);
    }

    function refresh() {
        if (!active) return;
        const k = makeKey();
        // Повторная попытка после сетевой ошибки — при следующем открытии окна
        if (k === key && status === "error") {
            status = "loading";
            fetchOnline();
            return;
        }
        if (k === key) return;
        key = k;
        cancel();
        lines = [];
        synced = false;
        if (k === "") {
            status = "idle";
            cacheFile.path = "";
            return;
        }
        status = "loading";
        cacheFile.path = cacheDir + "/" + k + ".json";
    }

    // Текущая загрузка; устаревшие ответы отбрасываются по несовпадению
    property int fetchToken: 0
    property var xhrs: []

    // Временный сбой (503/429/сеть) — один повтор
    function request(url: string, token: int, cb: var, retried = false) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || token !== fetchToken) return;
            const code = xhr.status;
            if ((code === 0 || code === 429 || code >= 500) && !retried) {
                retry.queue.push(() => { if (token === fetchToken) request(url, token, cb, true); });
                retry.restart();
                return;
            }
            cb(code, xhr.responseText);
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("Lrclib-Client", "quickshell");
        xhr.send();
        xhrs.push(xhr);
    }

    function cancel() {
        fetchToken++;
        const list = xhrs;
        xhrs = [];
        retry.queue = [];
        deadline.stop();
        for (const x of list) x.abort();
    }

    // Записи с одной-двумя строками в LRCLIB встречаются как мусор — такие пропускаем
    function usable(rec: var): bool {
        if (!rec) return false;
        if (rec.instrumental) return true;
        const n = s => s ? s.split("\n").filter(l => l.trim() !== "").length : 0;
        return n(rec.syncedLyrics) >= 3 || n(rec.plainLyrics) >= 3;
    }

    function cleanTitle(s: string): string {
        return s
            .replace(/\s*[\(\[【][^\)\]】]*\b(official|video|audio|lyrics?|visuali[sz]er|mv|m\/v|hd|4k|explicit|clip|live|remaster(ed)?)\b[^\)\]】]*[\)\]】]/gi, "")
            .replace(/\s*[\(\[]?\s*\b(feat|ft|featuring)\b\.?\s[^\)\]]*[\)\]]?/gi, "")
            .replace(/\s+[-–—]\s+(\d{4}\s+)?(remaster(ed)?|live|radio edit|mono|stereo|single version|album version)\b.*$/i, "")
            .replace(/\s+/g, " ").trim();
    }

    function cleanArtist(s: string): string {
        return s
            .replace(/\s*-\s*topic$/i, "")
            .replace(/vevo$/i, "")
            .replace(/\s*\b(feat|ft|featuring)\b\.?\s.*$/i, "")
            .replace(/^@/, "")
            .trim();
    }

    // Запасные запросы q=: «Исполнитель - Песня» в названии, исполнитель + название, только название
    function fallbackQueries(artist: string, title: string): var {
        const out = [];
        const split = title.match(/^(.+?)\s+[-–—]\s+(.+)$/);
        if (split) out.push(split[1] + " " + split[2]);
        if (artist) out.push(artist + " " + title);
        out.push(title);
        return out.filter((q, i) => q.trim() !== "" && out.indexOf(q) === i);
    }

    // strict: только записи с близкой длительностью (поиск без исполнителя)
    function pick(code: int, body: string, len: real, strict = false): var {
        let list = [];
        if (code === 200)
            try { list = JSON.parse(body).filter(usable); } catch (e) {}
        const near = r => len === 0 || Math.abs(r.duration - len) <= 3;
        if (strict) list = list.filter(near);
        return list.find(r => r.syncedLyrics && near(r))
            ?? list.find(r => r.syncedLyrics)
            ?? list.find(near)
            ?? list[0]
            ?? null;
    }

    // /get и /search идут параллельно; если оба пусто — запасные q-запросы по очереди
    function fetchOnline() {
        cancel();
        const token = fetchToken;
        const p = player;
        const len = p.length > 0 ? p.length : 0;
        const artist = cleanArtist(p.trackArtist || "");
        const title = cleanTitle(p.trackTitle) || p.trackTitle;
        const q = "artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(title);
        const fallbacks = fallbackQueries(artist, title);
        const bad = code => code !== 200 && code !== 404;

        let got = len > 0 ? undefined : null;
        let found = undefined;
        let failed = false;
        let done = false;

        const finish = rec => {
            done = true;
            deadline.stop();
            const data = {
                synced: rec?.syncedLyrics ?? "",
                plain: rec?.plainLyrics ?? "",
                instrumental: rec?.instrumental ?? false
            };
            apply(data);
            cacheFile.setText(JSON.stringify(data));
        };

        const next = () => {
            const s = fallbacks.shift();
            if (s === undefined) {
                // Не кэшируем: при сетевой ошибке попробуем снова при следующем открытии
                if (failed) {
                    deadline.stop();
                    status = "error";
                } else {
                    finish(null);
                }
                return;
            }
            request(api + "/search?q=" + encodeURIComponent(s), token, (code, body) => {
                failed = failed || bad(code);
                const r = pick(code, body, len, s === title && artist !== "");
                if (r) finish(r);
                else next();
            });
        };

        const decide = () => {
            if (done) return;
            if (usable(got)) return finish(got);
            if (got === undefined || found === undefined) return;
            if (found) return finish(found);
            next();
        };

        deadline.restart();
        if (len > 0) {
            const album = p.trackAlbum ? "&album_name=" + encodeURIComponent(p.trackAlbum) : "";
            request(api + "/get?" + q + album + "&duration=" + Math.round(len), token, (code, body) => {
                failed = failed || bad(code);
                got = null;
                if (code === 200)
                    try { got = JSON.parse(body); } catch (e) {}
                decide();
            });
        }
        request(api + "/search?" + q, token, (code, body) => {
            failed = failed || bad(code);
            found = pick(code, body, len);
            decide();
        });
    }

    onActiveChanged: refresh()
    onPlayerChanged: debounce.restart()

    Connections {
        target: root.player

        function onPostTrackChanged() { debounce.restart(); }
        function onTrackTitleChanged() { debounce.restart(); }
        function onLengthChanged() { debounce.restart(); }
    }

    // Метаданные приходят частями — ждём, пока они устоятся
    Timer {
        id: debounce
        interval: 150
        onTriggered: root.refresh()
    }

    Timer {
        id: retry
        property var queue: []
        interval: 700
        onTriggered: {
            const q = queue;
            queue = [];
            for (const f of q) f();
        }
    }

    // Общий лимит на загрузку, чтобы «Ищем текст…» не висел
    Timer {
        id: deadline
        interval: 8000
        onTriggered: if (root.status === "loading") {
            root.cancel();
            root.status = "error";
        }
    }

    FileView {
        id: cacheFile
        printErrors: false
        onLoaded: {
            if (path !== root.cacheDir + "/" + root.key + ".json") return;
            try {
                root.apply(JSON.parse(text()));
            } catch (e) {
                root.fetchOnline();
            }
        }
        onLoadFailed: if (root.key !== "") root.fetchOnline()
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.cacheDir]
    }

    Component.onCompleted: mkdir.startDetached()
}
