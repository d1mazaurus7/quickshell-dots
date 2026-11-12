pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Qt.labs.folderlistmodel
import "../../shell/theme"

// Виджет лок-скрина «Пользователь» (lockOnly): фото из assets/photos, ник и подпись
Item {
    id: root

    property var settings: ({})
    property bool editing: false
    property var services: ({})

    readonly property var colors: Tokens.colors
    readonly property url folder: Qt.resolvedUrl("../../assets/photos")
    // Фото не выбрано — первое из папки
    readonly property string photo: settings.photo !== "" ? settings.photo
        : photos.count > 0 ? photos.get(0, "fileName") : ""
    readonly property string nick: settings.nameSource === "custom" && settings.customName !== ""
        ? settings.customName : (Quickshell.env("USER") ?? "")
    readonly property color textColor: settings.whiteText === true ? "#ffffff" : colors.on_surface
    readonly property bool showText: settings.showName === true || settings.subtitle !== ""
    readonly property bool above: settings.namePosition === "above"
    readonly property int gap: Tokens.scaled(settings.nameGap)
    readonly property real textHeight: showText ? (above ? topText.height : bottomText.height) + gap : 0
    readonly property real side: Math.max(0, Math.min(width, height - textHeight) * settings.photoSize)

    // Ник и подпись
    component NameBlock: Column {
        width: root.width
        visible: root.showText
        spacing: Tokens.scaled(2)

        Text {
            width: parent.width
            visible: root.settings.showName === true
            horizontalAlignment: Text.AlignHCenter
            text: root.nick
            color: root.textColor
            font.family: Tokens.typography.family
            font.pixelSize: Tokens.scaled(root.settings.nameSize)
            font.bold: root.settings.nameBold === true
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: root.settings.subtitle !== ""
            horizontalAlignment: Text.AlignHCenter
            text: root.settings.subtitle.replace(/%u/g, root.nick)
            color: root.settings.whiteText === true ? Qt.alpha("#ffffff", 0.75) : root.colors.on_surface_variant
            font.family: Tokens.typography.family
            font.pixelSize: Math.round(Tokens.scaled(root.settings.nameSize) * 0.6)
            elide: Text.ElideRight
        }
    }

    LockIdle {
        id: idle
        lock: root.services.lock ?? null
        active: root.settings.hideOnIdle === true
        delay: root.settings.idleDelay
        hold: root.editing
    }

    FolderListModel {
        id: photos
        folder: root.folder
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
    }

    Column {
        anchors.centerIn: parent
        spacing: root.gap
        opacity: idle.shown ? 1 : 0
        scale: idle.shown ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Tokens.animationSlow; easing.type: Easing.OutCubic } }

        NameBlock {
            id: topText
            visible: root.showText && root.above
        }

        ClippingRectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.side
            height: root.side
            visible: root.settings.showPhoto === true
            radius: width / 2 * root.settings.radius
            color: root.colors.surface_container_high
            opacity: root.settings.photoOpacity
            border.width: Tokens.scaled(root.settings.borderWidth)
            border.color: root.settings.borderColor === "white" ? "#ffffff"
                : root.settings.borderColor === "outline" ? root.colors.outline : root.colors.primary
            layer.enabled: root.settings.shadow === true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.colors.shadow
                shadowBlur: 0.8
                shadowVerticalOffset: Tokens.scaled(4)
            }

            Text {
                anchors.centerIn: parent
                visible: image.status !== Image.Ready
                text: "person"
                color: root.colors.on_surface_variant
                font.family: "Material Symbols Rounded"
                font.pixelSize: Math.round(parent.width * 0.55)
            }
            Image {
                id: image
                anchors.fill: parent
                source: root.photo !== "" ? root.folder + "/" + root.photo : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: width
                sourceSize.height: height
                asynchronous: true
            }
        }

        NameBlock {
            id: bottomText
            visible: root.showText && !root.above
        }
    }
}
