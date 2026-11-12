pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../../theme" as Theme
import "../../shell/theme"
import "../../shell/config"

// Страница с текстом песни: текущая строка подсвечена и держится у верхнего края
Item {
    id: root

    required property LyricsState lyrics
    property MprisPlayer player: null

    readonly property var cfg: Config.options.musicPlayer
    // Окно с текстом открыто (задаёт владелец); вместе с видимостью страницы — показывается ли текст.
    // Пока текст не виден, покадровые эффекты стоят: волна по буквам, аура, копия букв для свечения
    property bool active: true
    readonly property bool live: active && visible

    // После ручной прокрутки не возвращаем вид к текущей строке какое-то время
    property bool following: true

    ListView {
        id: view
        anchors.fill: parent
        visible: root.lyrics.status === "ready"
        clip: true
        interactive: root.cfg.lyricsScroll
        model: root.lyrics.lines
        currentIndex: root.lyrics.currentIndex
        spacing: Tokens.scaled(6)
        topMargin: Tokens.scaled(8)
        bottomMargin: height / 2
        boundsBehavior: Flickable.StopAtBounds

        highlight: Item {}
        highlightRangeMode: root.following && root.lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: Tokens.scaled(48)
        preferredHighlightEnd: Tokens.scaled(96)
        highlightMoveDuration: Tokens.animationSlow
        highlightMoveVelocity: -1

        onModelChanged: positionViewAtBeginning()
        onMovementStarted: {
            root.following = false;
            resume.restart();
        }

        delegate: Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: index === view.currentIndex
            readonly property bool seekable: root.lyrics.synced && root.player !== null && root.player.canSeek && root.cfg.lyricsSeek
            readonly property real currentScale: root.cfg.lyricsHighlight ? 1.15 : 1.06
            // Отдельные буквы рисуются, если включён хотя бы один эффект
            readonly property bool fx: current && (root.cfg.lyricsHighlight || root.cfg.lyricsBounce || root.cfg.lyricsGlow || root.cfg.lyricsAura)
            readonly property bool effects: root.cfg.lyricsGlow || root.cfg.lyricsAura
            // Плавный переход между обычным текстом и буквами с эффектами
            property real fxOpacity: fx ? 1 : 0
            Behavior on fxOpacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutQuad } }
            readonly property bool fxShown: fxOpacity > 0
            // Размытие растёт с удалением от текущей строки
            property real blurAmount: !root.cfg.lyricsBlur || !root.lyrics.synced || current ? 0
                : Math.min(1, 0.35 + Math.abs(index - view.currentIndex) * 0.15)
            Behavior on blurAmount { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutQuad } }
            readonly property int align: root.cfg.lyricsAlign === "left" ? Text.AlignLeft : root.cfg.lyricsAlign === "right" ? Text.AlignRight : Text.AlignHCenter

            // Буквы без пробелов с позицией в строке — для прыжков
            readonly property var chars: {
                const out = [];
                let pos = 0;
                for (const c of Array.from(modelData.text)) {
                    if (c.trim() !== "") out.push({ c: c, pos: pos });
                    pos += c.length;
                }
                return out;
            }
            // Волна проходит строку за время до следующей строки
            readonly property real duration: {
                const next = root.lyrics.lines[index + 1];
                return next ? Math.max(0.6, Math.min(8, next.time - modelData.time)) * 1000 : 3000;
            }
            property real wave: -4

            width: view.width
            height: label.implicitHeight + Tokens.scaled(8) + (current ? label.implicitHeight * (currentScale - 1) : 0)

            Behavior on height { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutQuad } }

            onCurrentChanged: {
                if (current) {
                    waveAnim.restart();
                } else {
                    // Волна плавно уходит со строки, пока буквы гаснут
                    waveAnim.stop();
                    waveOut.restart();
                }
            }
            Component.onCompleted: if (current) waveAnim.restart()

            NumberAnimation {
                id: waveOut
                paused: running && !root.live
                target: line
                property: "wave"
                to: line.chars.length + 4
                duration: Tokens.animationSlow
            }

            NumberAnimation {
                id: waveAnim
                paused: running && !root.live
                target: line
                property: "wave"
                from: -2
                to: line.chars.length + 2
                duration: line.duration
            }

            Item {
                id: body
                anchors.verticalCenter: parent.verticalCenter
                // Ширина с запасом, чтобы увеличенная строка не выходила за края
                width: parent.width / line.currentScale
                height: label.implicitHeight
                x: line.align === Text.AlignLeft ? 0 : line.align === Text.AlignRight ? parent.width - width : (parent.width - width) / 2
                transformOrigin: line.align === Text.AlignLeft ? Item.Left : line.align === Text.AlignRight ? Item.Right : Item.Center
                opacity: !root.lyrics.synced || line.current ? 1 : lineArea.containsMouse ? 0.85 : 0.5
                scale: line.current ? line.currentScale : lineArea.pressed ? 0.97 : 1

                Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutQuad } }
                Behavior on scale { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.InOutQuad } }

                TextEdit {
                    id: label
                    width: parent.width
                    readOnly: true
                    activeFocusOnPress: false
                    textFormat: TextEdit.PlainText
                    renderType: TextEdit.QtRendering
                    text: line.modelData.text
                    wrapMode: TextEdit.Wrap
                    horizontalAlignment: line.align
                    // У текущей строки рисуются отдельные буквы поверх
                    opacity: 1 - line.fxOpacity
                    color: line.current || lineArea.containsMouse ? Theme.Palette.on_surface : Theme.Palette.on_surface_variant
                    font.family: Tokens.typography.family
                    font.pixelSize: Tokens.scaled(root.cfg.lyricsFontSize)
                    font.weight: Font.Medium

                    layer.enabled: line.blurAmount > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: line.blurAmount
                        blurMax: 24
                    }
                }

                Item {
                    id: fxLayer
                    anchors.fill: parent
                    visible: line.fxShown
                    opacity: line.fxOpacity

                Item {
                    id: glyphs
                    anchors.fill: parent
                    // Буквы рисуются напрямую поверх эффектов — без слоя, чтобы оставались чёткими
                    z: 1

                    Repeater {
                        model: line.fxShown ? line.chars : []

                        Text {
                            required property var modelData
                            required property int index
                            readonly property rect r: label.width, label.text, label.positionToRectangle(modelData.pos)
                            readonly property real d: index - line.wave

                            x: r.x
                            y: r.y - (root.cfg.lyricsBounce ? Tokens.scaled(6) * Math.exp(-d * d / 8) : 0)
                            text: modelData.c
                            color: root.cfg.lyricsHighlight ? "white" : Theme.Palette.on_surface
                            font: label.font
                            renderType: Text.QtRendering
                        }
                    }
                }

                // Копия букв для эффектов
                ShaderEffectSource {
                    id: glyphSource
                    anchors.fill: glyphs
                    sourceItem: glyphs
                    visible: false
                    live: line.fxShown && line.effects && root.live
                    smooth: true
                    // Разрешение экрана с учётом увеличения строки: эффекты — размытые копии,
                    // лишние пиксели в них не видны, а размывать приходится каждый кадр
                    textureSize: Qt.size(Math.ceil(width * line.currentScale * Screen.devicePixelRatio), Math.ceil(height * line.currentScale * Screen.devicePixelRatio))
                }

                // Аура: размытая цветная копия букв, мягко «дышит»
                MultiEffect {
                    id: aura
                    anchors.fill: glyphs
                    source: glyphSource
                    visible: root.cfg.lyricsAura
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    colorization: 1
                    colorizationColor: Theme.Palette.primary
                    brightness: 0.3
                    scale: 1.03
                    opacity: 0.7

                    SequentialAnimation on opacity {
                        running: aura.visible && root.live
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 1200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.55; duration: 1200; easing.type: Easing.InOutSine }
                    }
                }

                // Буквы со свечением
                MultiEffect {
                    anchors.fill: glyphs
                    source: glyphSource
                    visible: root.cfg.lyricsGlow
                    shadowEnabled: true
                    shadowColor: root.cfg.lyricsHighlight ? "white" : Theme.Palette.primary_fixed
                    shadowBlur: 0.6
                    shadowOpacity: 0.9
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
                }
            }

            MouseArea {
                id: lineArea
                anchors.fill: parent
                enabled: line.seekable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.player.position = line.modelData.time;
                    root.following = true;
                }
            }
        }
    }

    Timer {
        id: resume
        interval: 3000
        onTriggered: root.following = true
    }

    // Загрузка, нет текста, ошибка
    Column {
        anchors.centerIn: parent
        visible: !view.visible
        spacing: Tokens.scaled(8)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({
                loading: "hourglass_empty",
                instrumental: "piano",
                error: "cloud_off"
            })[root.lyrics.status] ?? "lyrics"
            color: Theme.Palette.on_surface_variant
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(40)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({
                idle: "Ничего не играет",
                loading: "Ищем текст…",
                instrumental: "Инструментальная композиция",
                notfound: "Текст не найден",
                error: "Не удалось загрузить текст"
            })[root.lyrics.status] ?? ""
            color: Theme.Palette.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Tokens.scaled(15)
        }
    }
}
