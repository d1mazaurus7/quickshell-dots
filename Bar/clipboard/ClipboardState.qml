import QtQuick
import Quickshell
import Quickshell.Io
import "../../shell/config"

// История буфера обмена: wl-paste --watch → захват текста, картинок и ссылок на файлы.
// Запись: { kind: "text" | "image" | "file", text, path, mime, paths, time }
Item {
    id: root

    readonly property var cfg: Config.options.clipboard
    readonly property string imageDir: Quickshell.statePath("clipboard")

    property var entries: []
    property bool loaded: false

    function keyOf(e): string {
        return e.kind === "image" ? "i:" + e.path
             : e.kind === "file" ? "f:" + e.paths.join("\n")
             : "t:" + e.text;
    }

    function add(entry): void {
        const k = keyOf(entry);
        const next = [entry].concat(entries.filter(e => keyOf(e) !== k));
        const removed = next.splice(Math.max(1, cfg.maxItems));
        setEntries(next, removed);
    }

    function remove(entry): void {
        const k = keyOf(entry);
        setEntries(entries.filter(e => keyOf(e) !== k), entries.filter(e => keyOf(e) === k));
    }

    function clear(): void {
        setEntries([], []);
        Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/*", "sh", imageDir]);
    }

    function setEntries(next, removed): void {
        entries = next;
        const used = next.filter(e => e.kind === "image").map(e => e.path);
        const files = removed.filter(e => e.kind === "image" && !used.includes(e.path)).map(e => e.path);
        if (files.length > 0)
            Quickshell.execDetached(["rm", "-f", "--"].concat(files));
        save();
    }

    function save(): void {
        if (loaded)
            store.setText(JSON.stringify(cfg.persist ? entries : []));
    }

    function copy(entry): void {
        if (entry.kind === "text")
            Quickshell.execDetached(["wl-copy", "--", entry.text]);
        else if (entry.kind === "image")
            Quickshell.execDetached(["sh", "-c", "wl-copy -t \"$2\" < \"$1\"", "sh", entry.path, entry.mime]);
        else {
            const uris = entry.paths.map(p => "file://" + encodeURI(p)).join("\r\n");
            Quickshell.execDetached(["sh", "-c",
                "u=$1; shift; for f; do [ -e \"$f\" ] || { notify-send \"Такого документа уже нет\"; exit 1; }; done; "
                + "printf '%s' \"$u\" | wl-copy -t text/uri-list",
                "sh", uris].concat(entry.paths));
        }
    }

    function parse(out: string): void {
        const nl = out.indexOf("\n");
        if (nl < 0) return;
        const kind = out.substring(0, nl);
        const body = out.substring(nl + 1);
        const time = Date.now();
        if (kind === "text") {
            if (body.trim() !== "") add({ kind: "text", text: body, time: time });
        } else if (kind === "image") {
            const [mime, path] = body.trim().split("\n");
            add({ kind: "image", mime: mime, path: path, text: "", time: time });
        } else if (kind === "files") {
            const paths = body.split(/\r?\n/)
                .filter(l => l.startsWith("file://"))
                .map(l => decodeURIComponent(l.substring(7)));
            if (paths.length > 0)
                add({ kind: "file", paths: paths, text: paths.map(p => p.split("/").pop()).join(", "), time: time });
        }
    }

    Connections {
        target: root.cfg
        function onPersistChanged(): void { root.save(); }
        function onMaxItemsChanged(): void {
            if (root.entries.length > root.cfg.maxItems)
                root.setEntries(root.entries.slice(0, root.cfg.maxItems), root.entries.slice(root.cfg.maxItems));
        }
    }

    FileView {
        id: store
        path: Quickshell.statePath("clipboard.json")
        printErrors: false
        onLoaded: {
            try {
                if (root.cfg.persist) root.entries = JSON.parse(text()) ?? [];
            } catch (e) {
                console.warn("clipboard.json:", e);
            }
            root.finishLoad();
        }
        onLoadFailed: root.finishLoad()
    }

    function finishLoad(): void {
        if (loaded) return;
        loaded = true;
        if (!cfg.persist) clear();
        watcher.running = true;
    }

    // Событие на каждую смену буфера; секретные (менеджеры паролей) и пустые пропускаются
    Process {
        id: watcher
        command: ["wl-paste", "--watch", "sh", "-c", "cat >/dev/null; echo \"${CLIPBOARD_STATE:-data}\""]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "data") return;
                if (capture.running) capture.pending = true;
                else capture.start();
            }
        }
    }

    Process {
        id: capture
        property bool pending: false

        function start(): void {
            command = ["sh", "-c", root.captureScript, "sh",
                       root.cfg.documents ? "1" : "0", root.cfg.images ? "1" : "0", root.imageDir];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: {
            if (pending) {
                pending = false;
                start();
            }
        }
    }

    // $1 — документы, $2 — картинки, $3 — каталог картинок
    readonly property string captureScript: "
types=$(wl-paste --list-types 2>/dev/null) || exit 0
if [ \"$1\" = 1 ] && printf '%s\\n' \"$types\" | grep -qx 'text/uri-list'; then
  printf 'files\\n'; wl-paste -n -t text/uri-list; exit 0
fi
img=$(printf '%s\\n' \"$types\" | grep -m1 '^image/')
if [ \"$2\" = 1 ] && [ -n \"$img\" ]; then
  mkdir -p \"$3\"; tmp=\"$3/.tmp\"
  wl-paste -t \"$img\" > \"$tmp\" || exit 0
  ext=${img#image/}; ext=${ext%%[;+]*}
  f=\"$3/$(sha1sum \"$tmp\" | cut -c1-16).$ext\"
  mv \"$tmp\" \"$f\"; printf 'image\\n%s\\n%s\\n' \"$img\" \"$f\"; exit 0
fi
if printf '%s\\n' \"$types\" | grep -qE '^(text/|UTF8_STRING|STRING|TEXT)'; then
  printf 'text\\n'; wl-paste -n -t text
fi
"

}
