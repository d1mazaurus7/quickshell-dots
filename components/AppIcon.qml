import QtQuick
import Quickshell
import "../shell/theme"

// Иконка приложения: имя из темы или путь к файлу.
// letterFallback — первая буква названия вместо отсутствующей иконки
Item {
    id: root

    property string icon
    property string name
    property bool letterFallback: true
    property int size: Tokens.scaled(28)

    readonly property var colors: Tokens.colors
    readonly property string themeName: icon.replace(/\.(png|svg|xpm|ico)$/i, "")
    // iconPath(…, true) возвращает "", если иконки нет в теме
    readonly property string source: icon === "" ? ""
        : icon.startsWith("/") ? "file://" + icon
        : letterFallback ? Quickshell.iconPath(themeName, true)
        : "image://icon/" + themeName
    readonly property bool missing: source === "" || img.status === Image.Error

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size, root.size)
        fillMode: Image.PreserveAspectFit
        visible: !root.missing
        asynchronous: true
        cache: true
        mipmap: true
    }

    Rectangle {
        anchors.fill: parent
        visible: root.missing && root.letterFallback && root.name !== ""
        radius: width / 2
        color: root.colors.secondary_container

        Text {
            anchors.centerIn: parent
            text: root.name.charAt(0).toUpperCase()
            color: root.colors.on_secondary_container
            font.family: Tokens.fontMedium.family
            font.pixelSize: Math.round(root.size * 0.5)
            font.bold: true
        }
    }
}
