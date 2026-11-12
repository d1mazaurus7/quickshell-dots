.pragma library

const list = [
    { id: "WORLD", title: "Мир" },
    { id: "NATION", title: "Движуха (Ладим Ладимыч)" },
    { id: "BUSINESS", title: "Бизнес" },
    { id: "TECHNOLOGY", title: "Технологии" },
    { id: "SCIENCE", title: "Наука" },
    { id: "HEALTH", title: "Здоровье" },
    { id: "SPORTS", title: "Спорт" },
    { id: "ENTERTAINMENT", title: "Развлечения" }
];

const base = "https://news.google.com/rss";
const locale = "hl=ru&gl=RU&ceid=RU:ru";

function title(id) {
    const t = list.find(t => t.id === id);
    return t ? t.title : "";
}

function topicUrl(id) {
    return base + "/headlines/section/topic/" + id + "?" + locale;
}

function queryUrl(query) {
    return base + "/search?q=" + encodeURIComponent(query) + "&" + locale;
}
