pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../shell/config"
import "../../shell/theme"
import "../controls"
import "../../Bar/news/NewsTopics.js" as Topics

// Раздел «Новости»: Config.options.news
ColumnLayout {
    id: page

    readonly property var colors: Tokens.colors
    readonly property var news: Config.options.news

    // Включить/выключить готовую тему; порядок — как в NewsTopics.js
    function setTopic(id: string, enabled: bool): void {
        const current = page.news.topics.slice();
        page.news.topics = Topics.list.map(t => t.id).filter(t => t === id ? enabled : current.includes(t));
    }

    spacing: Tokens.spacingMediumV

    Text {
        Layout.bottomMargin: Tokens.spacingMediumV
        text: "Новости"
        color: page.colors.on_surface
        font.family: Tokens.fontLarge.family
        font.pixelSize: Tokens.fontLarge.pixelSize + Tokens.scaled(4)
    }

    Text {
        Layout.topMargin: Tokens.spacingSmallV
        text: "Темы Google Новостей"
        color: page.colors.on_surface_variant
        font: Tokens.fontMedium
    }

    Repeater {
        model: Topics.list

        SettingRow {
            id: topicRow
            required property var modelData
            title: modelData.title

            SettingSwitch {
                checked: page.news.topics.includes(topicRow.modelData.id)
                onToggled: checked => page.setTopic(topicRow.modelData.id, checked)
            }
        }
    }

    SettingStringList {
        title: "Свои темы"
        description: "Поисковые запросы Google Новостей, каждый — отдельная тема"
        placeholder: "Например, Linux"
        values: page.news.queries
        onEdited: values => page.news.queries = values
    }

    SettingStringList {
        title: "Свои ленты"
        description: "Адреса RSS или Atom; название берётся из ленты"
        placeholder: "https://habr.com/ru/rss/articles/"
        values: page.news.feeds
        onEdited: values => page.news.feeds = values
    }

    Text {
        Layout.topMargin: Tokens.spacingMediumV
        text: "Окно"
        color: page.colors.on_surface_variant
        font: Tokens.fontMedium
    }

    SettingRow {
        // Раскрытый список рисуется поверх следующих пунктов
        z: sideDropdown.expanded ? 1 : 0
        title: "Появление"
        description: "С какой стороны экрана выезжает окно"

        SettingDropdown {
            id: sideDropdown
            model: ["Справа", "Слева"]
            popupHeight: Tokens.scaled(96)
            currentValue: page.news.side === "left" ? "Слева" : "Справа"
            onActivated: value => page.news.side = value === "Слева" ? "left" : "right"
        }
    }

    SettingRow {
        title: "Ширина"
        description: "Ширина окна новостей"

        SettingSlider {
            from: 300
            to: 800
            stepSize: 10
            value: page.news.width
            formatValue: v => Math.round(v) + " px"
            onMoved: value => page.news.width = Math.round(value)
        }
    }

    SettingRow {
        title: "Высота"
        description: "Доля высоты экрана"

        SettingSlider {
            from: 0.4
            to: 1
            stepSize: 0.05
            value: page.news.heightRatio
            formatValue: v => Math.round(v * 100) + "%"
            onMoved: value => page.news.heightRatio = value
        }
    }

    SettingRow {
        title: "Обновление"
        description: "Как часто обновлять ленту, пока окно открыто"

        SettingSlider {
            from: 5
            to: 120
            stepSize: 5
            value: page.news.refreshInterval
            formatValue: v => Math.round(v) + " мин"
            onMoved: value => page.news.refreshInterval = Math.round(value)
        }
    }

    SettingRow {
        title: "Новостей с темы"
        description: "Сколько новостей брать из каждой темы или ленты"

        SettingSlider {
            from: 5
            to: 50
            stepSize: 5
            value: page.news.maxItems
            formatValue: v => String(Math.round(v))
            onMoved: value => page.news.maxItems = Math.round(value)
        }
    }
}
