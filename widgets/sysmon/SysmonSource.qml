import QtQuick
import Quickshell.Io

// Потребление одного ресурса: kind — "disk" | "ram" | "cpu" | "gpu".
// fraction — занятая доля 0..1, used/free — байты (disk, ram) или проценты (cpu, gpu).
// history — последние значения fraction для графика
Item {
    id: root

    property string kind: "cpu"
    property int interval: 1000
    property int historyLength: 60

    property real fraction: 0
    property real used: 0
    property real free: 0
    property bool ready: false
    property var history: []

    signal sampled()

    function push(f: real): void {
        fraction = Math.max(0, Math.min(1, f));
        ready = true;
        const h = history.concat([fraction]);
        const n = historyLength + 2;
        // Недостающее начало заполняем самым старым значением — график сразу на всю ширину
        history = h.length > n ? h.slice(h.length - n) : new Array(n - h.length).fill(h[0]).concat(h);
        sampled();
    }

    function percent(f: real): void {
        used = Math.round(f * 100);
        free = 100 - used;
        push(f);
    }

    Timer {
        interval: root.interval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (root.kind === "disk")
                df.running = true;
            else if (root.kind === "gpu" && gpuFile.path !== "")
                gpuFile.reload();
            else if (root.kind === "ram")
                memFile.reload();
            else if (root.kind === "cpu")
                statFile.reload();
        }
    }

    // CPU: доля не-idle времени между двумя чтениями /proc/stat
    property var lastCpu: null
    FileView {
        id: statFile
        path: root.kind === "cpu" ? "/proc/stat" : ""
        printErrors: false
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = p[3] + (p[4] ?? 0);
            const total = p.reduce((a, b) => a + b, 0);
            const prev = root.lastCpu;
            root.lastCpu = { idle, total };
            if (prev && total > prev.total)
                root.percent(1 - (idle - prev.idle) / (total - prev.total));
        }
    }

    FileView {
        id: memFile
        path: root.kind === "ram" ? "/proc/meminfo" : ""
        printErrors: false
        onLoaded: {
            const kb = key => Number((text().match(new RegExp("^" + key + ":\\s+(\\d+)", "m")) ?? [0, 0])[1]) * 1024;
            const total = kb("MemTotal");
            const avail = kb("MemAvailable");
            if (total <= 0)
                return;
            root.used = total - avail;
            root.free = avail;
            root.push(root.used / total);
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=size,used,avail", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                if (p.length < 3 || !(p[0] > 0))
                    return;
                root.used = p[1];
                root.free = p[2];
                root.push(p[1] / (p[1] + p[2]));
            }
        }
    }

    // GPU: gpu_busy_percent первой карты, где он есть (amdgpu)
    Process {
        running: root.kind === "gpu"
        command: ["sh", "-c", "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && echo \"$f\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: gpuFile.path = text.trim()
        }
    }
    FileView {
        id: gpuFile
        path: ""
        printErrors: false
        onLoaded: root.percent(Number(text().trim()) / 100)
    }
}
