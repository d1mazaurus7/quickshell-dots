pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/theme"

// Символ часов в ячейке фиксированного размера: смена значения — slide снизу вверх с затуханием.
// region — Region по форме символа из masks (для размытия под текстом)
Item {
    id: root

    property string value
    property font font
    property color color
    property real capHeight: 0
    property bool animated: true
    property var masks: ({})

    property string current: ""
    property string previous: ""
    property real progress: 1

    readonly property real baseY: Math.round(height / 2 + capHeight / 2 - currentText.baselineOffset)
    readonly property real shift: height * 0.7

    property var maskRegions: []
    readonly property Region region: Region {
        regions: root.maskRegions
    }
    function collectMask(): void {
        const list = [];
        for (let i = 0; i < maskRepeater.count; i++) {
            const it = maskRepeater.itemAt(i);
            if (it)
                list.push(it.region);
        }
        maskRegions = list;
    }

    clip: true

    Component.onCompleted: current = value
    onValueChanged: {
        if (value === current)
            return;
        previous = current;
        current = value;
        if (animated)
            anim.restart();
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Tokens.animationSlow * 1.5
        easing.type: Easing.OutCubic
    }

    Text {
        x: Math.round((root.width - implicitWidth) / 2)
        y: root.baseY - root.progress * root.shift
        opacity: 1 - root.progress
        visible: root.progress < 1
        text: root.previous
        font: root.font
        color: root.color
    }

    Text {
        id: currentText
        x: Math.round((root.width - implicitWidth) / 2)
        y: root.baseY + (1 - root.progress) * root.shift
        opacity: root.progress
        text: root.current
        font: root.font
        color: root.color

        // Полосы маски движутся вместе с символом
        Repeater {
            id: maskRepeater
            model: root.masks[root.current] ?? []
            onItemAdded: Qt.callLater(root.collectMask)
            onItemRemoved: Qt.callLater(root.collectMask)

            Item {
                id: strip
                required property var modelData
                x: modelData.x
                y: Math.round(currentText.baselineOffset) + modelData.y
                width: modelData.w
                height: modelData.h
                readonly property Region region: Region { item: strip }
            }
        }
    }
}
