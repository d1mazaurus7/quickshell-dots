import QtQuick
import "../../../shell/config"
import "../controls"
import "../controls/Icons.js" as Icons

// Скриншот: выделение области после закрытия центра; меню — настройки снимков
SplitTile {
    id: w

    required property var ctx
    readonly property var shot: ctx.screenshotService

    s: ctx.s
    active: false
    icon: Icons.camera
    menuSlideOnClick: 1
    title: "Скриншот"
    subtitle: Config.options.screenshot.instant ? "Сразу после выделения" : "С панелью действий"
    onToggled: {
        if (!shot)
            return;
        ctx.play("click");
        // Кадр снимается после закрытия центра, чтобы он не попал на снимок
        ctx.runHidden(() => w.shot.capture());
    }
    onExpand: {
        ctx.play("list");
        ctx.page = "screenshot";
    }
}
