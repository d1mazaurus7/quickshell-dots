pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Настройки оболочки: ~/.config/quickshell/settings.json.
// Значения по умолчанию задаются в свойствах адаптера —
// отсутствующие в файле ключи получают дефолт.
Singleton {
    id: root

    // Доступ к настройкам: Config.options.<секция>.<ключ>
    readonly property alias options: adapter
    // true после первой успешной загрузки (или создания) файла
    property bool ready: false

    FileView {
        path: Quickshell.shellPath("settings.json")
        watchChanges: true
        // Правка файла извне — перечитываем
        onFileChanged: reload()
        // Изменение свойства из оболочки — сохраняем в файл
        onAdapterUpdated: writeAdapter()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            // Первый запуск: создаём файл с дефолтами
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.ready = true;
        }

        JsonAdapter {
            id: adapter

            // Версия схемы для будущих миграций
            property int version: 2

            property JsonObject appearance: JsonObject {
                // Общий масштаб размеров интерфейса
                property real scale: 1.0
                // Масштаб отступов по горизонтали и вертикали
                property real spacingHorizontal: 1.0
                property real spacingVertical: 1.0
                property real radiusScale: 1.0
                property real animationScale: 1.0
                // Обводка вокруг панелей и полей
                property bool borders: true
            }

            property JsonObject typography: JsonObject {
                property string family: "Sans Serif"
                // Базовый размер; small/large в Tokens — ±2px
                property int size: 12
            }

            property JsonObject snow: JsonObject {
                property bool enabled: false
                // Множитель числа снежинок и скорости накопления
                property real intensity: 1.0
                // Множитель скорости падения
                property real speed: 1.0
                // Максимальная высота сугроба, лог. px
                property int driftHeight: 60
                // Расчистка сугроба ЛКМ
                property bool sweep: true
                // Прятать нижний сугроб, если на экране только тайловые окна
                property bool hideGroundWithTiled: true
                // Снежные шапки на плавающих окнах
                property bool windowDrifts: true
                // Максимальная высота шапки, лог. px
                property int windowDriftHeight: 30
                // Скругление краёв шапки, 0..1
                property real capRounding: 0.6
                // Доля снега, стряхиваемая при перетаскивании окна, 0..1
                property real shakeOff: 0.7
            }
        }
    }
}
