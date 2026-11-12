import QtQuick
import QtMultimedia

// Видео без звука по кругу; грузится Loader'ом только для видеофайлов.
// allowed — играть ли сейчас (решает виджет)
Video {
    property bool allowed: true

    loops: MediaPlayer.Infinite
    muted: true
    fillMode: VideoOutput.PreserveAspectCrop
    // Новый файл запускается сразу, без перезагрузки оболочки
    onSourceChanged: if (allowed && source.toString() !== "") play()
    onAllowedChanged: allowed ? play() : pause()
}
