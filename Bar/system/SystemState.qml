import QtQuick
import Quickshell
import Quickshell.Io

// Метрики системы и их история. Сбор — один долгоживущий bash-цикл (sysstat.sh), пока active;
// разделы и накопители (df, lsblk) — только пока detailed
Item {
    id: root

    property bool active: false
    property bool detailed: false
    property int interval: 1000
    // Ёмкость истории — час при любом периоде
    readonly property int capacity: Math.ceil(3600000 / interval) + 2

    property var info: ({})
    property var drives: []
    property var filesystems: []

    property real cpu: 0
    property real cpuUser: 0
    property real cpuSys: 0
    property real cpuIo: 0
    property var cores: []
    property var freqs: []
    property real freq: 0
    property var load: [0, 0, 0]
    property string tasks: ""
    property real uptime: 0
    property var temps: ({})
    property var gpu: ({})
    property var mem: ({})
    property var io: ({})
    property real ioRead: 0
    property real ioWrite: 0
    property real ioPeak: 1

    property var history: ({})
    // Номер последнего отсчёта: по нему графики сдвигаются без пересчёта индексов
    property int count: 0
    signal sampled()

    readonly property real cpuTemp: temps.cpu_Tctl ?? temps.cpu_Package_id_0 ?? 0
    readonly property real ramTemp: {
        let s = 0, n = 0;
        for (const k in temps)
            if (k.startsWith("ram")) { s += temps[k]; n++; }
        return n ? s / n : 0;
    }
    readonly property real diskTemp: {
        let m = 0;
        for (const k in temps)
            if (k.startsWith("nvme")) m = Math.max(m, temps[k]);
        return m;
    }


    // Форматирование
    function bytes(b: real): string {
        const u = ["Б", "КБ", "МБ", "ГБ", "ТБ"];
        let i = 0;
        while (Math.abs(b) >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (i && b < 10 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }
    function rate(b: real): string { return bytes(b) + "/с"; }
    function duration(s: real): string {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + " д " : "") + (d || h ? h + " ч " : "") + m + " мин";
    }
    function ghz(mhz: real): string { return (mhz / 1000).toFixed(2) + " ГГц"; }

    function kv(rest: string): var {
        const o = {};
        for (const p of rest.split(" ")) {
            const e = p.indexOf("=");
            if (e > 0)
                o[p.slice(0, e)] = p.slice(e + 1);
        }
        return o;
    }

    function push(key: string, v: real): void {
        let a = history[key];
        if (!a)
            a = history[key] = [];
        a.push(v);
        if (a.length > capacity)
            a.splice(0, a.length - capacity);
    }

    property var pInfo: ({})
    property var pStat: ({})
    property var pDisk: null
    property double pDiskTime: 0
    property var nCores: []

    function parse(line: string): void {
        const sp = line.indexOf(" ");
        const tag = sp < 0 ? line : line.slice(0, sp);
        const rest = sp < 0 ? "" : line.slice(sp + 1);
        switch (tag) {
        case "I": {
            const s = rest.indexOf(" ");
            if (s > 0)
                pInfo[rest.slice(0, s)] = rest.slice(s + 1);
            break;
        }
        case "IE":
            info = Object.assign({}, pInfo);
            break;
        case "S": {
            const p = rest.split(" ");
            const name = p[0];
            const n = p.slice(1, 9).map(Number);
            const total = n.reduce((a, b) => a + b, 0);
            const prev = pStat[name];
            pStat[name] = n.concat([total]);
            if (!prev || total <= prev[8])
                break;
            const dt = total - prev[8];
            const d = i => n[i] - prev[i];
            const busy = 1 - (d(3) + d(4)) / dt;
            if (name === "cpu") {
                cpu = busy;
                cpuUser = (d(0) + d(1)) / dt;
                cpuSys = (d(2) + d(5) + d(6)) / dt;
                cpuIo = d(4) / dt;
            } else {
                nCores[Number(name.slice(3))] = busy;
            }
            break;
        }
        case "F": {
            const f = rest.split(" ").map(v => Number(v) / 1000);
            freqs = f;
            freq = f.length ? f.reduce((a, b) => a + b, 0) / f.length : 0;
            break;
        }
        case "M": {
            const m = kv(rest);
            const k = key => Number(m[key] ?? 0) * 1024;
            const total = k("MemTotal"), avail = k("MemAvailable");
            mem = {
                total, avail,
                used: total - avail,
                cached: k("Cached") + k("SReclaimable"),
                buffers: k("Buffers"),
                shmem: k("Shmem"),
                dirty: k("Dirty"),
                swapTotal: k("SwapTotal"),
                swapUsed: k("SwapTotal") - k("SwapFree"),
                swapCached: k("SwapCached")
            };
            break;
        }
        case "L": {
            const p = rest.split(" ");
            load = [Number(p[0]), Number(p[1]), Number(p[2])];
            tasks = p[3];
            uptime = Number(p[4]);
            break;
        }
        case "T": {
            const m = kv(rest), t = {};
            for (const key in m)
                if (m[key] !== "")
                    t[key] = Number(m[key]) / 1000;
            temps = t;
            break;
        }
        case "G": {
            const m = kv(rest);
            gpu = {
                busy: Number(m.busy ?? 0) / 100,
                vram: Number(m.vram ?? 0),
                gtt: Number(m.gtt ?? 0),
                sclk: Number(m.sclk ?? 0) / 1e6,
                mclk: Number(m.mclk ?? 0) / 1e6,
                fan: Number(m.fan ?? 0),
                power: Number(m.power ?? 0) / 1e6,
                vdd: Number(m.vdd ?? 0)
            };
            break;
        }
        case "D": {
            const m = kv(rest), now = Date.now();
            const cur = {}, out = {};
            let r = 0, w = 0;
            for (const name in m) {
                const s = m[name].split(",").map(Number);
                cur[name] = s;
                if (pDisk && pDisk[name]) {
                    const dt = (now - pDiskTime) / 1000;
                    const rr = Math.max(0, (s[0] - pDisk[name][0]) * 512 / dt);
                    const ww = Math.max(0, (s[1] - pDisk[name][1]) * 512 / dt);
                    out[name] = { r: rr, w: ww };
                    r += rr; w += ww;
                }
            }
            pDisk = cur;
            pDiskTime = now;
            io = out;
            ioRead = r;
            ioWrite = w;
            break;
        }
        case "E":
            commit();
            break;
        }
    }

    function commit(): void {
        cores = nCores.slice();
        const g = gpu, m = mem;
        push("cpu", cpu * 100);
        push("cpuUser", cpuUser * 100);
        push("cpuSys", cpuSys * 100);
        push("cpuIo", cpuIo * 100);
        push("cpuTemp", cpuTemp);
        push("cpuFreq", freq);
        push("gpu", (g.busy ?? 0) * 100);
        push("gpuEdge", temps.gpu_edge ?? 0);
        push("gpuHot", temps.gpu_junction ?? 0);
        push("gpuMemT", temps.gpu_mem ?? 0);
        push("vram", info.vramTotal ? (g.vram ?? 0) / Number(info.vramTotal) * 100 : 0);
        push("gpuPower", g.power ?? 0);
        push("ram", m.total ? m.used / m.total * 100 : 0);
        push("cache", m.total ? (m.cached + m.buffers) / m.total * 100 : 0);
        push("swap", m.swapTotal ? m.swapUsed / m.swapTotal * 100 : 0);
        push("ramTemp", ramTemp);
        push("diskR", ioRead);
        push("diskW", ioWrite);
        push("diskTemp", diskTemp);
        ioPeak = Math.max(ioPeak * 0.995, ioRead, ioWrite, 1048576);
        count++;
        sampled();
    }

    Process {
        id: collector
        running: root.active
        command: ["bash", Quickshell.shellPath("Bar/system/sysstat.sh"), String(root.interval)]
        stdout: SplitParser { onRead: line => root.parse(line) }
        onRunningChanged: if (!running) { root.pStat = {}; root.pDisk = null; }
    }

    // Перезапуск цикла при смене периода
    onIntervalChanged: {
        history = {};
        count = 0;
        if (collector.running) {
            collector.running = false;
            collector.running = Qt.binding(() => root.active);
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.detailed
        triggeredOnStart: true
        onTriggered: { df.running = true; lsblk.running = true; }
    }

    // Процессы по памяти (группировка по имени) и оболочка с дочерними процессами — пока procs
    property bool procs: false
    property var apps: []
    property real shellRss: 0
    property int shellProcs: 0

    Timer {
        interval: 3000
        repeat: true
        running: root.procs
        triggeredOnStart: true
        onTriggered: ps.running = true
    }

    Process {
        id: ps
        command: ["ps", "-eo", "pid=,ppid=,rss=,comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const kids = {};
                let shell = -1;
                for (const l of text.split("\n")) {
                    const m = l.trim().match(/^(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/);
                    if (!m)
                        continue;
                    const pr = { pid: +m[1], ppid: +m[2], rss: +m[3] * 1024, name: m[4].replace(/^\./, "").replace(/-wra(p(p(e(d)?)?)?)?$/, "") };
                    list.push(pr);
                    (kids[pr.ppid] = kids[pr.ppid] ?? []).push(pr);
                    if (shell < 0 && pr.name === "quickshell")
                        shell = pr.pid;
                }
                const inShell = {};
                let rss = 0, n = 0;
                const stack = shell >= 0 ? [shell] : [];
                while (stack.length) {
                    const pid = stack.pop();
                    inShell[pid] = true;
                    for (const c of kids[pid] ?? [])
                        stack.push(c.pid);
                }
                const groups = {};
                for (const pr of list) {
                    if (inShell[pr.pid]) {
                        rss += pr.rss;
                        n++;
                        continue;
                    }
                    if (pr.rss <= 0)
                        continue;
                    const g = groups[pr.name] = groups[pr.name] ?? { name: pr.name, rss: 0, count: 0 };
                    g.rss += pr.rss;
                    g.count++;
                }
                root.shellRss = rss;
                root.shellProcs = n;
                root.apps = Object.values(groups).sort((x, y) => y.rss - x.rss).slice(0, 15);
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=source,fstype,size,used,target", "-x", "tmpfs", "-x", "devtmpfs",
            "-x", "efivarfs", "-x", "overlay", "-x", "squashfs", "-x", "ramfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                for (const l of text.trim().split("\n").slice(1)) {
                    const p = l.trim().split(/\s+/);
                    if (p.length < 5 || !p[0].startsWith("/dev/"))
                        continue;
                    const fs = { source: p[0], type: p[1], size: Number(p[2]), used: Number(p[3]), target: p.slice(4).join(" ") };
                    if (!seen[fs.source] || fs.target.length < seen[fs.source].target.length)
                        seen[fs.source] = fs;
                }
                root.filesystems = Object.values(seen).sort((a, b) => a.target.localeCompare(b.target));
            }
        }
    }

    Process {
        id: lsblk
        command: ["lsblk", "-J", "-d", "-b", "-o", "NAME,MODEL,SIZE,ROTA,TRAN"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.drives = JSON.parse(text).blockdevices.filter(d => !d.name.startsWith("loop") && !d.name.startsWith("zram"));
                } catch (e) {
                    console.warn("system: lsblk:", e);
                }
            }
        }
    }
}
