pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"

// Раздел «Музыкальный плеер»: Config.options.musicPlayer
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var player: Config.options.musicPlayer
    // Все gif из assets/gifs/dance
    readonly property var gifs: [
        "Dance Vtuber Sticker.gif",
        "Happy School Girl Sticker by helloangelgirl.gif",
        "Umamusume Uma Sticker.gif",
        "Umamusume Uma Sticker(1).gif",
        "gif.gif"
    ]

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Музыкальный плеер"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    SettingRow {
        title: "Cava-визуализатор"
        description: "Спектр вокруг обложки трека"

        SettingSwitch {
            checked: page.player.cava
            onToggled: checked => page.player.cava = checked
        }
    }

    SettingRow {
        title: "Gif"
        description: "Анимация в окне плеера, справа от эквалайзера"

        SettingSwitch {
            checked: page.player.danceGifEnabled
            onToggled: checked => page.player.danceGifEnabled = checked
        }
    }

    SettingRow {
        z: gifDropdown.expanded ? 1 : 0
        shown: page.player.danceGifEnabled
        child: true
        title: "Выбор gif"
        description: "Файл из assets/gifs/dance"

        Column {
            spacing: Tokens.spacingSmallV

            // Предпросмотр выбранной gif
            Rectangle {
                width: gifDropdown.width
                height: Tokens.scaled(140)
                radius: Tokens.radiusMedium
                color: page.colors.surface_container_low
                border.width: Tokens.borderWidth
                border.color: page.colors.outline_variant

                Text {
                    anchors.centerIn: parent
                    visible: page.player.danceGif === ""
                    text: "Для предпросмотра выберите gif:"
                    color: page.colors.on_surface_variant
                    font: Tokens.fontSmall
                }

                AnimatedImage {
                    anchors.fill: parent
                    anchors.margins: Tokens.spacingSmall
                    visible: page.player.danceGif !== ""
                    source: visible ? Qt.resolvedUrl("../../assets/gifs/dance/" + page.player.danceGif) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    playing: visible
                }
            }

            SettingDropdown {
                id: gifDropdown
                model: page.gifs
                popupHeight: Tokens.scaled(220)
                currentValue: page.player.danceGif
                onActivated: value => page.player.danceGif = value
            }
        }
    }

    SettingRow {
        title: "Обложка на фоне"
        description: "Обложка трека в качестве фона окна плеера"

        SettingSwitch {
            checked: page.player.coverBackground
            onToggled: checked => page.player.coverBackground = checked
        }
    }

    SettingRow {
        shown: page.player.coverBackground
        child: true
        title: "Размытие фона"
        description: "Размывать обложку на фоне"

        SettingSwitch {
            checked: page.player.backgroundBlur
            onToggled: checked => page.player.backgroundBlur = checked
        }
    }

    SettingRow {
        title: "Волнистый таймлайн"
        description: "Бегущие волны на полосе прогресса трека"

        SettingSwitch {
            checked: page.player.wavyTimeline
            onToggled: checked => page.player.wavyTimeline = checked
        }
    }

    SettingRow {
        z: styleDropdown.expanded ? 1 : 0
        shown: page.player.wavyTimeline
        child: true
        title: "Стиль таймлайна"
        description: "Вид полосы прогресса трека"

        SettingDropdown {
            id: styleDropdown
            model: ["Волны", "Material You"]
            popupHeight: Tokens.scaled(96)
            currentValue: page.player.timelineStyle === "material" ? "Material You" : "Волны"
            onActivated: value => page.player.timelineStyle = value === "Material You" ? "material" : "wave"
        }
    }

    SettingRow {
        title: "Исполнитель"
        description: "Показывать исполнителя под названием трека"

        SettingSwitch {
            checked: page.player.showArtist
            onToggled: checked => page.player.showArtist = checked
        }
    }

    SettingRow {
        title: "Эквалайзер"
        description: "Полосы эквалайзера и предустановки в окне плеера"

        SettingSwitch {
            checked: page.player.equalizer
            onToggled: checked => page.player.equalizer = checked
        }
    }
}
