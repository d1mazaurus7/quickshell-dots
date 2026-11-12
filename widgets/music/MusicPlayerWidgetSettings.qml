import QtQuick
import Quickshell
import "../../shell/theme"
import "../controls"

// Настройки экземпляра виджета плеера (открываются в редакторе)
Column {
    id: root

    property var settings: ({})

    signal settingChanged(string key, var value)

    readonly property var colors: Tokens.colors

    spacing: Tokens.spacingMediumV

    component Header: Text {
        topPadding: Tokens.spacingSmallV
        color: Tokens.colors.primary
        font: Tokens.fontSmall
    }

    Header { text: "Оформление" }
    ToggleRow {
        width: parent.width
        text: "Cava-визуализатор"
        checked: root.settings.cava === true
        onToggled: c => root.settingChanged("cava", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.cava === true

        ChoiceRow {
            width: parent.width
            text: "Вид"
            options: [
                { value: "wave", label: "Волна" },
                { value: "bars", label: "Полосы" }
            ]
            value: root.settings.cavaStyle
            onSelected: v => root.settingChanged("cavaStyle", v)
        }
    }
    ToggleRow {
        width: parent.width
        text: "Обложка на фоне"
        checked: root.settings.coverBackground === true
        onToggled: c => root.settingChanged("coverBackground", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.coverBackground === true

        ToggleRow {
            width: parent.width
            text: "Размытие фона"
            checked: root.settings.backgroundBlur === true
            onToggled: c => root.settingChanged("backgroundBlur", c)
        }
    }
    ToggleRow {
        width: parent.width
        text: "Gif справа"
        checked: root.settings.danceGifEnabled === true
        onToggled: c => root.settingChanged("danceGifEnabled", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.danceGifEnabled === true

        ImagePicker {
            width: parent.width
            folder: Qt.resolvedUrl("../../assets/gifs/dance")
            value: root.settings.danceGif
            onSelected: name => root.settingChanged("danceGif", name)
        }
    }

    Header { text: "Трек" }
    ToggleRow {
        width: parent.width
        text: "Исполнитель"
        checked: root.settings.showArtist === true
        onToggled: c => root.settingChanged("showArtist", c)
    }
    ToggleRow {
        width: parent.width
        text: "Время трека"
        checked: root.settings.showTime === true
        onToggled: c => root.settingChanged("showTime", c)
    }
    ToggleRow {
        width: parent.width
        text: "Волнистый таймлайн"
        checked: root.settings.wavyTimeline === true
        onToggled: c => root.settingChanged("wavyTimeline", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.wavyTimeline === true

        DropdownRow {
            width: parent.width
            text: "Стиль таймлайна"
            options: [
                { value: "wave", label: "Волны" },
                { value: "material", label: "Material You" }
            ]
            value: root.settings.timelineStyle
            onSelected: v => root.settingChanged("timelineStyle", v)
        }
    }

    Header { text: "Страницы" }
    ToggleRow {
        width: parent.width
        text: "Эквалайзер"
        checked: root.settings.equalizer === true
        onToggled: c => root.settingChanged("equalizer", c)
    }
    ToggleRow {
        width: parent.width
        text: "Текст песни"
        checked: root.settings.lyrics === true
        onToggled: c => root.settingChanged("lyrics", c)
    }
    ChildGroup {
        width: parent.width
        shown: root.settings.lyrics === true

        SliderRow {
            width: parent.width
            text: "Размер текста"
            from: 10
            to: 28
            sliderWidth: Tokens.scaled(130)
            value: root.settings.lyricsFontSize
            formatValue: v => Math.round(v) + " px"
            onMoved: v => root.settingChanged("lyricsFontSize", Math.round(v))
        }
        DropdownRow {
            width: parent.width
            text: "Выравнивание"
            options: [
                { value: "left", label: "Слева" },
                { value: "center", label: "По центру" },
                { value: "right", label: "Справа" }
            ]
            value: root.settings.lyricsAlign
            onSelected: v => root.settingChanged("lyricsAlign", v)
        }
        ToggleRow {
            width: parent.width
            text: "Прокрутка"
            checked: root.settings.lyricsScroll === true
            onToggled: c => root.settingChanged("lyricsScroll", c)
        }
        ToggleRow {
            width: parent.width
            text: "Перемотка по строке"
            checked: root.settings.lyricsSeek === true
            onToggled: c => root.settingChanged("lyricsSeek", c)
        }
        Item {
            width: parent.width
            height: cacheButton.height

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Кэш текстов"
                color: root.colors.on_surface
                font: Tokens.fontMedium
            }
            TextButton {
                id: cacheButton
                anchors.right: parent.right
                icon: "delete"
                text: "Очистить"
                onClicked: Quickshell.execDetached(["sh", "-c", 'rm -f -- "$0"/*.json',
                    (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/quickshell/lyrics"])
            }
        }
    }
}
