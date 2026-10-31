pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/theme"

// Раздел «Оболочка»: обновление из репозитория удержанием кнопки
ColumnLayout {
    id: page

    required property var updater

    readonly property var colors: Tokens.colors
    readonly property int holdDuration: 4000
    readonly property string statusText: ({
            checking: "Проверка на обновления...",
            installing: "Установка обновлений",
            installed: "Обновление установлено!",
            failed: "Не удалось загрузить обновление"
        })[updater.status] ?? ""
    readonly property bool buttonShown: updater.status === "idle" || updater.status === "failed"

    spacing: Tokens.spacingMediumV

    Item {
        Layout.preferredHeight: Tokens.scaled(72)
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "VALTRYNX'S SHELL"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.scaled(52)
        font.letterSpacing: Tokens.scaled(2)
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: "github: d1mazaurus7"
        color: page.colors.on_surface_variant
        font: Tokens.fontMedium
    }

    Item {
        Layout.preferredHeight: Tokens.scaled(72)
    }

    // Место кнопки: кнопка и надпись статуса сменяют друг друга
    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: Tokens.scaled(560)
        implicitHeight: Tokens.scaled(64)

        Item {
            id: button

            // Заполнение 0..1; волна выходит за край, поэтому при 1 кнопка закрыта полностью
            property real progress: 0
            property real phase: 0
            readonly property real amplitude: Tokens.scaled(7)

            anchors.fill: parent
            opacity: page.buttonShown ? 1 : 0
            scale: page.buttonShown ? 1 : 0.96
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

            onProgressChanged: wave.requestPaint()
            onPhaseChanged: wave.requestPaint()

            Rectangle {
                anchors.fill: parent
                radius: Tokens.radiusLarge
                color: area.pressed ? page.colors.surface_container_highest
                     : area.containsMouse ? page.colors.surface_container_high
                     : page.colors.surface_container
                Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
            }

            // Заливка с волнистым краем: задняя волна прозрачнее и сдвинута по фазе
            Canvas {
                id: wave
                anchors.fill: parent
                visible: button.progress > 0

                function fill(ctx, color, edge, phase) {
                    const a = button.amplitude;
                    const k = 2 * Math.PI / height;
                    ctx.fillStyle = color;
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    for (let y = 0; y <= height; y += 2)
                        ctx.lineTo(edge + a * (0.6 * Math.sin(y * k + phase)
                                             + 0.4 * Math.sin(y * k * 2.5 - phase * 3)), y);
                    ctx.lineTo(0, height);
                    ctx.closePath();
                    ctx.fill();
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.beginPath();
                    ctx.roundedRect(0, 0, width, height, Tokens.radiusLarge, Tokens.radiusLarge);
                    ctx.clip();
                    const edge = button.progress * (width + button.amplitude * 2) - button.amplitude;
                    fill(ctx, Qt.alpha(page.colors.primary, 0.25), edge + button.amplitude, button.phase + Math.PI / 2);
                    fill(ctx, page.colors.secondary_container, edge, button.phase);
                    bubbles(ctx, edge);
                }

                // Пузырьки поднимаются у края заливки; скорости кратны фазе — цикл без скачков
                function bubbles(ctx, edge) {
                    const seeds = [0.05, 0.42, 0.77, 0.21, 0.63, 0.9, 0.34, 0.55];
                    const t = button.phase / (2 * Math.PI);
                    ctx.fillStyle = Qt.alpha(page.colors.primary, 0.35);
                    for (let i = 0; i < seeds.length; i++) {
                        const seed = seeds[i];
                        const r = Tokens.scaled(2 + seed * 3);
                        const y = height + r - ((t * (1 + i % 3) + seed) % 1) * (height + r * 2);
                        const x = edge - Tokens.scaled(6 + seed * 38) + Tokens.scaled(3) * Math.sin(button.phase * 2 + i);
                        if (x - r <= 0)
                            continue;
                        ctx.beginPath();
                        ctx.arc(x, y, r, 0, 2 * Math.PI);
                        ctx.fill();
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: "ПРОВЕРИТЬ НА ОБНОВЛЕНИЯ"
                color: page.colors.on_surface
                font.family: Tokens.fontLarge.family
                font.pixelSize: Tokens.fontLarge.pixelSize
                font.letterSpacing: Tokens.scaled(1)
            }

            // Волна бежит, пока есть заливка
            NumberAnimation on phase {
                running: button.progress > 0 && button.visible
                from: 0
                to: 2 * Math.PI
                duration: 1400
                loops: Animation.Infinite
            }

            NumberAnimation {
                id: holdAnim
                target: button
                property: "progress"
                to: 1
                duration: (1 - button.progress) * page.holdDuration
                easing.type: Easing.InOutSine
                onFinished: if (button.progress >= 1) page.updater.start()
            }

            NumberAnimation {
                id: drainAnim
                target: button
                property: "progress"
                to: 0
                duration: Tokens.animationSlow
                easing.type: Easing.OutCubic
            }

            MouseArea {
                id: area
                anchors.fill: parent
                enabled: page.buttonShown
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: {
                    drainAnim.stop();
                    holdAnim.restart();
                }
                onReleased: {
                    if (button.progress >= 1)
                        return;
                    holdAnim.stop();
                    drainAnim.restart();
                }
                onCanceled: {
                    holdAnim.stop();
                    drainAnim.restart();
                }
            }

            // Кнопка вернулась (ошибка) — снова пустая
            Connections {
                target: page.updater
                function onStatusChanged() {
                    if (page.buttonShown)
                        button.progress = 0;
                }
            }
        }

        Item {
            anchors.fill: parent
            opacity: page.buttonShown ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

            Text {
                id: status
                anchors.centerIn: parent
                text: page.statusText
                color: page.colors.on_surface
                font.family: Tokens.fontLarge.family
                font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)

                // Смена надписи: короткое затухание и проявление
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: status; property: "opacity"; to: 0; duration: Tokens.animationFast }
                        PropertyAction {}
                        NumberAnimation { target: status; property: "opacity"; to: 1; duration: Tokens.animationMedium; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }

    // Ошибка загрузки — под вернувшейся кнопкой
    Text {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacingMediumV
        opacity: page.updater.status === "failed" ? 1 : 0
        text: page.statusText
        color: page.colors.error
        font: Tokens.fontMedium
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium } }
    }
}
