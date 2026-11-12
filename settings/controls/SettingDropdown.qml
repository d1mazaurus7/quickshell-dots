pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/theme"

// M3 выпадающее меню. Список раскрывается поверх соседних пунктов:
// у родительского пункта нужно поднимать z, пока expanded.
// Клавиатура: ↑/↓/Enter/Space — открыть; в меню ↑/↓, PgUp/PgDn, Enter — выбор, Esc — закрыть.
FocusScope {
    id: root

    property var model: []
    property string currentValue
    // Поле фильтра в списке
    property bool searchable: false
    // Отрисовывать каждый пункт его же шрифтом (для выбора шрифта)
    property bool fontPreview: false
    property int popupHeight: Tokens.scaled(280)
    property bool expanded: false

    signal activated(string value)

    readonly property var colors: Tokens.colors
    readonly property var filteredModel: model.filter(v =>
        v.toLowerCase().includes(filter.text.trim().toLowerCase()))

    implicitWidth: Tokens.scaled(280)
    implicitHeight: field.implicitHeight
    activeFocusOnTab: true

    function move(step) {
        const count = filteredModel.length;
        if (count === 0)
            return;
        list.currentIndex = Math.max(0, Math.min(count - 1, list.currentIndex + step));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    function choose(value) {
        activated(value);
        expanded = false;
    }

    function handleKey(event) {
        const k = event.key;
        if (!expanded) {
            if (k === Qt.Key_Up || k === Qt.Key_Down || k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                expanded = true;
                event.accepted = true;
            }
            return;
        }
        switch (k) {
        case Qt.Key_Down: move(1); break;
        case Qt.Key_Up: move(-1); break;
        case Qt.Key_PageDown: move(5); break;
        case Qt.Key_PageUp: move(-5); break;
        case Qt.Key_Home: if (searchable) return; move(-filteredModel.length); break;
        case Qt.Key_End: if (searchable) return; move(filteredModel.length); break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (list.currentIndex >= 0 && list.currentIndex < filteredModel.length)
                choose(filteredModel[list.currentIndex]);
            break;
        case Qt.Key_Escape: expanded = false; break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab: expanded = false; return;
        default: return;
        }
        event.accepted = true;
    }

    Keys.onPressed: event => handleKey(event)
    onActiveFocusChanged: if (!activeFocus) expanded = false

    onExpandedChanged: {
        if (expanded) {
            filter.text = "";
            if (searchable)
                filter.forceActiveFocus();
            list.currentIndex = Math.max(0, filteredModel.indexOf(currentValue));
            list.positionViewAtIndex(list.currentIndex, ListView.Center);
        } else if (filter.activeFocus) {
            // Возвращаем фокус полю, чтобы стрелки продолжали работать
            filter.focus = false;
            root.forceActiveFocus();
        }
    }

    // Поле с текущим значением
    Rectangle {
        id: field
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: Tokens.scaled(44)
        // Пилюля → скруглённый прямоугольник при раскрытии
        radius: root.expanded ? Tokens.radiusLarge : height / 2
        color: root.colors.surface_container_high
        // Кольцо фокуса с клавиатуры
        border.width: root.activeFocus ? Math.max(2, Tokens.borderWidth) : Tokens.borderWidth
        border.color: root.expanded || root.activeFocus ? root.colors.primary : root.colors.outline_variant
        scale: fieldArea.pressed ? 0.98 : 1
        Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: Tokens.animationMedium } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        // State layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.colors.on_surface
            opacity: fieldArea.pressed ? 0.10 : fieldArea.containsMouse ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
        }

        Text {
            anchors.left: parent.left
            anchors.right: arrow.left
            anchors.leftMargin: Tokens.spacingLarge
            anchors.rightMargin: Tokens.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.currentValue
            color: root.colors.on_surface
            font.family: root.fontPreview ? root.currentValue : Tokens.fontMedium.family
            font.pixelSize: Tokens.fontMedium.pixelSize
        }

        Text {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: Tokens.spacingMedium + Tokens.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            text: "keyboard_arrow_down"
            color: root.expanded ? root.colors.primary : root.colors.on_surface_variant
            font.family: "Material Symbols Rounded"
            font.pixelSize: Tokens.scaled(22)
            rotation: root.expanded ? 180 : 0
            scale: fieldArea.containsMouse && !fieldArea.pressed ? 1.12 : 1
            Behavior on rotation { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
            Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
        }

        MouseArea {
            id: fieldArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.forceActiveFocus();
                root.expanded = !root.expanded;
            }
        }
    }

    // Раскрывающееся меню
    Rectangle {
        id: popup
        anchors.left: parent.left
        anchors.right: parent.right
        y: field.height + Tokens.spacingSmallV
        // По содержимому, но не выше popupHeight — без пустого места у коротких списков
        height: Math.min(root.popupHeight, popupContent.implicitHeight + Tokens.spacingSmallV * 2)
        radius: Tokens.radiusLarge
        // Светлее фона и поля, чтобы меню не сливалось
        color: root.colors.surface_container_highest
        border.width: Tokens.borderWidth
        border.color: root.colors.outline_variant
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        // Раскрытие сверху вниз
        transform: Scale {
            yScale: root.expanded ? 1 : 0.85
            Behavior on yScale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast; easing.type: Easing.OutCubic } }

        // Клики не проходят сквозь меню
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: popupContent
            anchors.fill: parent
            anchors.leftMargin: Tokens.spacingSmall
            anchors.rightMargin: Tokens.spacingSmall
            anchors.topMargin: Tokens.spacingSmallV
            anchors.bottomMargin: Tokens.spacingSmallV
            spacing: Tokens.spacingSmallV

            // Поиск: пилюля с иконкой и кнопкой очистки
            Rectangle {
                Layout.fillWidth: true
                visible: root.searchable
                implicitHeight: Tokens.scaled(40)
                // Концентрично углам меню
                radius: Math.max(0, popup.radius - Tokens.spacingSmall)
                color: Qt.alpha(root.colors.on_surface, 0.08)

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.spacingMedium + Tokens.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    color: filter.activeFocus ? root.colors.primary : root.colors.on_surface_variant
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: Tokens.scaled(20)
                    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                }

                TextInput {
                    id: filter
                    anchors.left: searchIcon.right
                    anchors.right: clearBtn.left
                    anchors.leftMargin: Tokens.spacingMedium
                    anchors.rightMargin: Tokens.spacingSmall
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: root.colors.on_surface
                    selectionColor: root.colors.primary
                    selectedTextColor: root.colors.on_primary
                    font: Tokens.fontMedium
                    Keys.onPressed: event => root.handleKey(event)
                    onTextChanged: list.currentIndex = 0

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !filter.text
                        text: "Поиск..."
                        color: root.colors.on_surface_variant
                        font: Tokens.fontMedium
                    }
                }

                Rectangle {
                    id: clearBtn
                    readonly property bool shown: filter.text !== ""
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.scaled(32)
                    height: width
                    radius: width / 2
                    color: clearArea.pressed ? Qt.alpha(root.colors.on_surface, 0.10)
                         : clearArea.containsMouse ? Qt.alpha(root.colors.on_surface, 0.08)
                         : "transparent"
                    opacity: shown ? 1 : 0
                    scale: shown ? 1 : 0.5
                    visible: opacity > 0
                    Behavior on color { ColorAnimation { duration: Tokens.animationFast } }
                    Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                    Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        color: root.colors.on_surface_variant
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.scaled(18)
                        rotation: clearArea.containsMouse ? 90 : 0
                        Behavior on rotation { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            filter.text = "";
                            filter.forceActiveFocus();
                        }
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: contentHeight
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredModel

                delegate: Rectangle {
                    id: option
                    required property string modelData
                    required property int index
                    readonly property bool selected: root.currentValue === modelData
                    readonly property bool current: ListView.isCurrentItem

                    width: list.width
                    implicitHeight: Tokens.scaled(44)
                    radius: selected ? height / 2 : Tokens.radiusMedium
                    color: selected ? root.colors.secondary_container : "transparent"
                    Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                    Behavior on radius { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                    // State layer
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: option.selected ? root.colors.on_secondary_container : root.colors.on_surface
                        opacity: optionArea.pressed ? 0.10 : option.current ? 0.08 : 0
                        Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                    }

                    Item {
                        id: checkSlot
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.spacingMedium + Tokens.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        width: option.selected ? checkIcon.implicitWidth + Tokens.spacingMedium : 0
                        height: checkIcon.implicitHeight
                        clip: true
                        Behavior on width { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }

                        Text {
                            id: checkIcon
                            anchors.verticalCenter: parent.verticalCenter
                            text: "check"
                            color: root.colors.on_secondary_container
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Tokens.scaled(18)
                            opacity: option.selected ? 1 : 0
                            scale: option.selected ? 1 : 0.4
                            Behavior on opacity { NumberAnimation { duration: Tokens.animationFast } }
                            Behavior on scale { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutBack } }
                        }
                    }

                    Text {
                        anchors.left: checkSlot.right
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.spacingLarge
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: option.modelData
                        color: option.selected ? root.colors.on_secondary_container : root.colors.on_surface
                        font.family: root.fontPreview ? option.modelData : Tokens.fontMedium.family
                        font.pixelSize: Tokens.fontMedium.pixelSize
                        Behavior on color { ColorAnimation { duration: Tokens.animationMedium } }
                    }

                    MouseArea {
                        id: optionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: list.currentIndex = option.index
                        onClicked: root.choose(option.modelData)
                    }
                }
            }
        }
    }
}
