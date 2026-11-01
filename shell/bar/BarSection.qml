import QtQuick
import QtQuick.Layouts
import "."

// Блок бара: модули из списка id в заданном порядке.
// Модули создаются прямо в RowLayout, чтобы скрытые (visible: false) не занимали места.
RowLayout {
    id: section

    // Окно бара, передаётся модулям
    required property var bar
    // id модулей из BarModules
    property list<string> ids: []

    Instantiator {
        model: section.ids

        // Смена ids пересоздаёт все модули по порядку — порядок в RowLayout совпадает
        QtObject {
            required property string modelData
            property Item item: null

            Component.onCompleted: {
                const entry = BarModules.find(modelData);
                if (entry)
                    item = entry.component.createObject(section, { bar: section.bar });
            }
            Component.onDestruction: item?.destroy()
        }
    }
}
