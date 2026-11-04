import QtQuick
import Quickshell.Widgets
import "../../shell/theme"

// Подложка виджета: скруглённая карточка, обрезающая содержимое
ClippingRectangle {
    radius: Tokens.radius(Tokens.scaled(20))
    color: Tokens.colors.surface_container
}
