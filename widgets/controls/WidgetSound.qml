pragma Singleton
import Quickshell
import "../../shell/config"

// Звук нажатия из Config.options.sound.clickSound (общий выключатель interactionSounds)
Singleton {
    function click(): void {
        if (Config.options.sound.interactionSounds)
            Quickshell.execDetached(["pw-play", Quickshell.shellPath("assets/sounds/" + Config.options.sound.clickSound)]);
    }
}
