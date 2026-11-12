import QtQuick
import Quickshell
import Quickshell.Io
import "Presets.js" as PresetList

// Состояние эквалайзера и связь с EasyEffects.
// Полосы записываются в отдельный пресет EasyEffects, который затем загружается через CLI
// (easyeffects -l). Остальные пресеты пользователя не трогаются.
Item {
    id: root

    readonly property var frequencies: [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property real minGain: -12
    readonly property real maxGain: 12
    readonly property var presets: PresetList.presets
    readonly property string presetName: "quickshell_eq"

    property var gains: frequencies.map(() => 0)
    // Полосы пресета «Свой» — последняя ручная настройка
    property var customGains: frequencies.map(() => 0)
    // Имя выбранного пресета; "" — ручная настройка
    property string activePreset: ""

    function setGain(index: int, value: real) {
        const g = gains.slice();
        g[index] = Math.max(minGain, Math.min(maxGain, value));
        gains = g;
        customGains = g;
        activePreset = matchPreset(g);
        applyTimer.restart();
        customTimer.restart();
    }

    function loadPreset(preset: var) {
        gains = (preset.custom ? customGains : preset.gains).slice();
        activePreset = preset.name;
        applyTimer.restart();
    }

    function matchPreset(g: var): string {
        const same = a => a.every((v, i) => v === g[i]);
        const p = presets.find(p => p.custom ? same(customGains) : same(p.gains));
        return p ? p.name : "";
    }

    function presetJson(): string {
        const band = i => ({
            type: "Bell", mode: "RLC (BT)", slope: "x1",
            solo: false, mute: false,
            gain: gains[i], frequency: frequencies[i], q: 1.41, width: 4.0
        });
        const bands = {};
        frequencies.forEach((f, i) => bands["band" + i] = band(i));
        return JSON.stringify({
            output: {
                blocklist: [],
                plugins_order: ["equalizer#0"],
                "equalizer#0": {
                    balance: 0.0,
                    bypass: false,
                    // Запас по громкости, чтобы подъём полос не давал клиппинг
                    "input-gain": -Math.max(0, ...gains),
                    "output-gain": 0.0,
                    mode: "IIR",
                    "num-bands": frequencies.length,
                    "split-channels": false,
                    "pitch-left": 0.0,
                    "pitch-right": 0.0,
                    left: bands,
                    right: bands
                }
            }
        }, null, 4);
    }

    // Применение с задержкой: при перетаскивании ползунка не запускаем процесс на каждый пиксель
    Timer {
        id: applyTimer
        interval: 200
        onTriggered: presetFile.setText(root.presetJson())
    }

    Timer {
        id: customTimer
        interval: 500
        onTriggered: customFile.setText(JSON.stringify(root.customGains))
    }

    FileView {
        id: customFile
        path: Quickshell.statePath("equalizer_custom.json")
        printErrors: false
        onLoaded: {
            try {
                const g = JSON.parse(text());
                if (Array.isArray(g) && g.length === root.frequencies.length) {
                    root.customGains = g;
                    root.activePreset = root.matchPreset(root.gains);
                }
            } catch (e) {}
        }
    }

    FileView {
        id: presetFile
        property bool restored: false

        path: Quickshell.env("HOME") + "/.local/share/easyeffects/output/" + root.presetName + ".json"
        printErrors: false
        // Восстанавливаем полосы из ранее сохранённого пресета один раз при запуске
        onLoaded: {
            if (restored) return;
            restored = true;
            try {
                const left = JSON.parse(text()).output["equalizer#0"].left;
                const g = root.frequencies.map((f, i) => left["band" + i]?.gain ?? 0);
                root.gains = g;
                root.activePreset = root.matchPreset(g);
            } catch (e) {}
        }
        onLoadFailed: restored = true
        onSaved: loadProc.startDetached()
    }

    Process {
        id: loadProc
        command: ["easyeffects", "-l", root.presetName]
    }
}
