pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "editor"

// Корень виджетов рабочего стола: окно на каждый экземпляр и редактор
Scope {
    id: root

    // Общее состояние эквалайзера оболочки (Bar/music_equalizer/EqualizerState.qml)
    property var equalizer: null

    WidgetsState {
        id: widgetsState
        services: ({ equalizer: root.equalizer })
    }

    WidgetsIpc {
        onRequested: (action, output) => {
            if (action === "close" || (action === "toggle" && widgetsState.editing)) {
                widgetsState.editing = false;
                return;
            }
            widgetsState.editorOutput = output;
            widgetsState.editing = true;
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
