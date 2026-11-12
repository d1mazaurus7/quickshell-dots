import QtQuick
import "../controls"
import "../controls/Icons.js" as Icons

// Яркость монитора (ddcutil, состояние в NotiCenter)
SliderTile {
    required property var ctx

    s: ctx.s
    icon: Icons.brightness
    buttonInteractive: false
    available: ctx.brightnessAvailable
    value: ctx.brightness
    onMoved: v => ctx.setBrightness(v)
    onScrolled: ctx.play("button")
}
