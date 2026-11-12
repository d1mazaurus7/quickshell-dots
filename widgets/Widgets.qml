pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "editor"
import "../shell/config"

// Корень виджетов рабочего стола: окно на каждый экземпляр и редактор
Scope {
    id: root

    // Общее состояние эквалайзера оболочки (Bar/music_equalizer/EqualizerState.qml)
    property var equalizer: null
    // Состояние лок-скрина (Bar/lockscreen/LockState.qml): куда направлять редактор, сервис lockOnly-виджетов
    property var lock: null
    readonly property bool locked: lock?.locked ?? false
    // Отдельный набор виджетов лок-скрина (widgets.lockItems), рисует Bar/lockscreen
    readonly property alias lockStore: lockState

    WidgetsState {
        id: widgetsState
        services: ({ equalizer: root.equalizer, focus: windowFocus })
    }
    // Фокус окон niri: видео в виджетах «Медиа» на паузе, пока окно в фокусе.
    // event-stream запущен, только пока такие виджеты есть
    WindowFocus {
        id: windowFocus
        active: (Config.options.widgets.items ?? []).some(i => i.type === "media")
    }
    WidgetsState {
        id: lockState
        lockSet: true
        services: ({ equalizer: root.equalizer, lock: root.lock })
    }

    // Смена блокировки закрывает оба редактора
    onLockedChanged: {
        widgetsState.editing = false;
        lockState.editing = false;
    }

    // Один бинд: на лок-скрине — редактор его набора, иначе — рабочего стола
    WidgetsIpc {
        onRequested: (action, output) => {
            const target = root.locked ? lockState : widgetsState;
            if (action === "close" || (action === "toggle" && target.editing)) {
                target.editing = false;
                return;
            }
            if (root.locked && !Config.options.lockscreen.widgets)
                return;
            target.editorOutput = output;
            target.editing = true;
        }
    }

    Variants {
        model: widgetsState.windowKeys

        WidgetWindow {
            required property string modelData
            uid: modelData.split("#")[0]
            widgets: widgetsState
        }
    }

    EditorWindow {
        widgets: widgetsState
    }
}
