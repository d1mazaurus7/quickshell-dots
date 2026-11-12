import QtQuick
import QtMultimedia

// Видео-обои на фоне лок-скрина. Грузится через Loader: без QtMultimedia остаётся первый кадр
Video {
    autoPlay: true
    loops: MediaPlayer.Infinite
    muted: true
    fillMode: VideoOutput.PreserveAspectCrop
}
