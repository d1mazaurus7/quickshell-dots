.pragma library
.import "../controls/Icons.js" as Icons

// Каталог виджетов центра (см. README.md).
// w, h — размер по умолчанию в ячейках сетки (4 колонки);
// minW..maxW, minH..maxH — пределы масштабирования в редакторе.
var widgets = [
    { type: "volume", title: "Громкость", icon: Icons.volume, source: "VolumeSlider.qml",
      w: 2, h: 1, minW: 2, maxW: 4, minH: 1, maxH: 1 },
    { type: "mic", title: "Микрофон", icon: Icons.mic, source: "MicSlider.qml",
      w: 2, h: 1, minW: 2, maxW: 4, minH: 1, maxH: 1 },
    { type: "brightness", title: "Яркость", icon: Icons.brightness, source: "BrightnessSlider.qml",
      w: 4, h: 1, minW: 2, maxW: 4, minH: 1, maxH: 1 },
    { type: "wifi", title: "Wi-Fi", icon: Icons.wifi, source: "WifiTile.qml",
      w: 2, h: 1, minW: 1, maxW: 4, minH: 1, maxH: 2 },
    { type: "bluetooth", title: "Bluetooth", icon: Icons.bluetooth, source: "BluetoothTile.qml",
      w: 2, h: 1, minW: 1, maxW: 4, minH: 1, maxH: 2 },
    { type: "dnd", title: "Не беспокоить", icon: Icons.dnd, source: "DndTile.qml",
      w: 2, h: 1, minW: 1, maxW: 4, minH: 1, maxH: 2 },
    { type: "recorder", title: "Запись", icon: Icons.record, source: "RecordTile.qml",
      w: 2, h: 1, minW: 1, maxW: 4, minH: 1, maxH: 2 },
    { type: "screenshot", title: "Скриншот", icon: Icons.camera, source: "ScreenshotTile.qml",
      w: 2, h: 1, minW: 1, maxW: 4, minH: 1, maxH: 2 },
    { type: "clock", title: "Часы", icon: Icons.clock, source: "ClockWidget.qml",
      w: 4, h: 1, minW: 2, maxW: 4, minH: 1, maxH: 2 },
    { type: "media", title: "Плеер", icon: Icons.music, source: "MediaPlayer.qml",
      w: 4, h: 3, minW: 3, maxW: 4, minH: 3, maxH: 4 }
];

// Раскладка, пока пользователь её не менял
var defaults = [
    { type: "volume", w: 2, h: 1 },
    { type: "mic", w: 2, h: 1 },
    { type: "wifi", w: 2, h: 1 },
    { type: "bluetooth", w: 2, h: 1 },
    { type: "dnd", w: 2, h: 1 },
    { type: "brightness", w: 2, h: 1 },
    { type: "media", w: 4, h: 3 }
];

function find(type) {
    for (var i = 0; i < widgets.length; i++)
        if (widgets[i].type === type)
            return widgets[i];
    return null;
}
