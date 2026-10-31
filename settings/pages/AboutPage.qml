pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../shell/theme"

// Раздел «О системе»: только чтение, данные собираются при открытии страницы
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors

    property var info: ({})
    property string monitors: ""
    // Аптайм на момент чтения + секунды, прошедшие с него
    property real uptimeBase: 0
    property real readAt: Date.now()
    property real now: Date.now()

    function gib(bytes) {
        return (bytes / 1073741824).toFixed(1) + " ГиБ";
    }

    function formatUptime(sec) {
        const d = Math.floor(sec / 86400);
        const h = Math.floor(sec % 86400 / 3600);
        const m = Math.floor(sec % 3600 / 60);
        return (d > 0 ? d + " д " : "") + (d > 0 || h > 0 ? h + " ч " : "") + m + " мин";
    }

    // Карточка: подпись и значение; длинное значение медленно прокручивается
    component InfoCard: Rectangle {
        id: card

        property string title
        property string value

        Layout.fillWidth: true
        implicitHeight: cardText.implicitHeight + Tokens.spacingLargeV * 2
        radius: Tokens.radiusLarge
        color: Tokens.colors.surface_container

        ColumnLayout {
            id: cardText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Tokens.spacingLarge
            anchors.rightMargin: Tokens.spacingLarge
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: card.title
                color: Tokens.colors.on_surface_variant
                font: Tokens.fontMedium
                elide: Text.ElideRight
            }

            Item {
                id: viewport
                readonly property real overflow: Math.max(0, valueText.implicitWidth - width)

                Layout.fillWidth: true
                implicitHeight: valueText.implicitHeight
                clip: true

                Text {
                    id: valueText
                    text: card.value
                    color: Tokens.colors.on_surface
                    font: Tokens.fontLarge
                }

                SequentialAnimation {
                    running: viewport.overflow > 0
                    loops: Animation.Infinite
                    onStopped: valueText.x = 0

                    PauseAnimation { duration: 1500 }
                    NumberAnimation {
                        target: valueText; property: "x"; to: -viewport.overflow
                        duration: viewport.overflow * 25; easing.type: Easing.InOutSine
                    }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation {
                        target: valueText; property: "x"; to: 0
                        duration: viewport.overflow * 25; easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    spacing: Tokens.spacingMediumV

    Process {
        running: true
        command: ["sh", "-c", `
            . /etc/os-release
            echo "distro=$NAME"
            echo "version=$VERSION"
            echo "kernel=$(uname -s)"
            echo "kernelVersion=$(uname -r)"
            echo "uptime=$(cut -d' ' -f1 /proc/uptime)"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
            echo "ram=$(awk '/MemTotal/{print $2 * 1024}' /proc/meminfo)"
            echo "disk=$(df -B1 --output=used,size / | tail -1)"
            ids=$(ls /nix/store/*-hwdata-*/share/hwdata/pci.ids 2>/dev/null | head -1)
            for d in /sys/class/drm/card*/device; do
                [ -f "$d/vendor" ] || continue
                v=$(sed 's/0x//' "$d/vendor"); p=$(sed 's/0x//' "$d/device")
                case $v in 1002) vn=AMD;; 10de) vn=NVIDIA;; 8086) vn=Intel;; *) vn=$v;; esac
                n=""
                [ -n "$ids" ] && n=$(awk -v v="$v" -v p="$p" 'index($0, v" ") == 1 { f = 1; next } f && /^[^\\t#]/ { exit } f && index($0, "\\t"p" ") == 1 { sub(/^\\t[0-9a-f]+ +/, ""); print; exit }' "$ids")
                echo "gpu=$vn \${n:-$p}"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0)
                        continue;
                    const k = line.slice(0, i);
                    const v = line.slice(i + 1);
                    // Несколько видеокарт — через запятую
                    r[k] = r[k] ? r[k] + ", " + v : v;
                }
                page.uptimeBase = parseFloat(r.uptime) || 0;
                page.readAt = Date.now();
                page.now = page.readAt;
                page.info = r;
            }
        }
    }

    Process {
        running: true
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outs = Object.values(JSON.parse(text));
                    page.monitors = outs.map(o => {
                        const mode = o.current_mode !== null ? o.modes[o.current_mode] : null;
                        return `${o.make} ${o.model}` + (mode
                            ? ` · ${mode.width}×${mode.height} @ ${Math.round(mode.refresh_rate / 1000)} Гц` : "");
                    }).join(", ");
                } catch (e) {
                    page.monitors = "";
                }
            }
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: page.now = Date.now()
    }

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "О системе"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    // Логотип тёмный — на светлой inverse-поверхности он читается
    Rectangle {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.spacingLargeV
        implicitHeight: Tokens.scaled(180)
        radius: Tokens.radiusLarge
        color: page.colors.inverse_surface

        Image {
            anchors.fill: parent
            anchors.margins: Tokens.spacingLarge
            source: Qt.resolvedUrl("../../assets/img/nixos-logo-3404681654.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacingLarge

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spacingMediumV

            Text {
                Layout.leftMargin: Tokens.spacingMedium
                text: "ОС"
                color: page.colors.on_surface_variant
                font: Tokens.fontMedium
            }

            InfoCard { title: "Дистрибутив"; value: page.info.distro ?? "…" }
            InfoCard { title: "Версия ОС"; value: page.info.version ?? "…" }
            InfoCard { title: "Ядро"; value: page.info.kernel ?? "…" }
            InfoCard { title: "Версия ядра"; value: page.info.kernelVersion ?? "…" }
            InfoCard {
                title: "Время активности системы"
                value: page.info.uptime
                    ? page.formatUptime(page.uptimeBase + (page.now - page.readAt) / 1000) : "…"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: Tokens.spacingMediumV

            Text {
                Layout.leftMargin: Tokens.spacingMedium
                text: "ПК"
                color: page.colors.on_surface_variant
                font: Tokens.fontMedium
            }

            InfoCard { title: "Видеокарта"; value: page.info.gpu ?? "…" }
            InfoCard { title: "Процессор"; value: page.info.cpu ?? "…" }
            InfoCard {
                title: "Оперативная память"
                value: page.info.ram ? page.gib(Number(page.info.ram)) : "…"
            }
            InfoCard {
                title: "Занято / всего на диске"
                value: {
                    const d = (page.info.disk ?? "").trim().split(/\s+/);
                    return d.length === 2 ? `${page.gib(Number(d[0]))} / ${page.gib(Number(d[1]))}` : "…";
                }
            }
            InfoCard { title: "Монитор"; value: page.monitors || "…" }
        }
    }
}
