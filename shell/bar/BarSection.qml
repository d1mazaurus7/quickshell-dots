import QtQuick
import QtQuick.Layouts
import "../../theme" as Theme
import "../theme"
import "."

// Блок бара: модули из списка id в заданном порядке.
// Модули создаются прямо в RowLayout, чтобы скрытые (visible: false) не занимали места.
Item {
    id: section

    // Окно бара, передаётся модулям
    required property var bar
    // id модулей из BarModules
    property list<string> ids: []
    // Своя подложка у каждого модуля (модульный стиль)
    readonly property bool pills: !BarStyle.filled
    readonly property int pillPadding: Tokens.spacingMedium

    implicitWidth: row.implicitWidth + row.x * 2
    implicitHeight: row.implicitHeight

    // Подложки рисуются отдельным слоем под модулями: обёртка вокруг модуля
    // ломала бы его самоскрытие через visible
    Item {
        id: pillLayer
        anchors.fill: parent
    }

    RowLayout {
        id: row
        x: section.pills ? section.pillPadding : 0
        spacing: section.pills ? section.pillPadding * 2 + Tokens.spacingMedium : 5
    }

    Component {
        id: pillComponent

        Rectangle {
            required property Item target
            readonly property int pillHeight: BarStyle.barHeight - Tokens.spacingSmallV * 2

            visible: section.pills && target.visible
            x: row.x + target.x - section.pillPadding
            y: row.y + target.y + target.height / 2 - pillHeight / 2
            width: target.width + section.pillPadding * 2
            height: pillHeight
            radius: Tokens.radius(16)
            color: Theme.Palette.background
        }
    }

    Instantiator {
        model: section.ids

        // Смена ids пересоздаёт все модули по порядку — порядок в RowLayout совпадает
        QtObject {
            required property string modelData
            property Item item: null
            property Item pill: null

            Component.onCompleted: {
                const entry = BarModules.find(modelData);
                if (!entry)
                    return;
                item = entry.component.createObject(row, { bar: section.bar });
                if (item)
                    pill = pillComponent.createObject(pillLayer, { target: item });
            }
            Component.onDestruction: {
                pill?.destroy();
                item?.destroy();
            }
        }
    }
}
