pragma ComponentBehavior: Bound
import QtQuick
import "../../shell/theme"
import ".."

// Содержимое редактора: сетка, рамки виджетов, панели. Окно рабочего стола или лок-скрин
Item {
    id: content

    required property WidgetsState widgets
    // Экран, виджеты которого редактируются
    required property var editorScreen

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Tokens.colors.background, 0.2)
    }

    // Клик по пустому месту снимает выделение
    MouseArea {
        anchors.fill: parent
        onClicked: {
            content.widgets.selectedUid = "";
            content.widgets.addOpen = false;
        }
    }

    GridOverlay {
        anchors.fill: parent
        step: content.widgets.gridLive > 0 ? content.widgets.gridLive : content.widgets.cfg.gridSize
        opacity: content.widgets.cfg.grid ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Tokens.animationMedium; easing.type: Easing.OutCubic } }
    }

    Repeater {
        model: content.widgets.uids

        WidgetFrame {
            required property string modelData
            uid: modelData
            widgets: content.widgets
            editorScreen: content.editorScreen
        }
    }

    WidgetSettingsPanel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: toolbar.top
        anchors.bottomMargin: Tokens.spacingMediumV
        widgets: content.widgets
    }

    EditorToolbar {
        id: toolbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.spacingLargeV * 2
        widgets: content.widgets
        onAddRequested: type => content.widgets.add(type, content.width, content.height)
    }
}
