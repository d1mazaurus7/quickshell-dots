import QtQuick
import "../../../theme" as Theme
import "../../../shell/theme"

// Раздел внутренней страницы: подпись и содержимое под ней (на всю ширину)
Column {
    id: section

    required property real s
    property string title

    width: parent ? parent.width : 0
    spacing: 8 * s

    Text {
        text: section.title
        color: Theme.Palette.on_surface_variant
        font.family: Tokens.typography.family
        font.pixelSize: Math.round(13 * section.s)
    }
}
