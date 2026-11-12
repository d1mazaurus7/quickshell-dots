.pragma library

// Коды погоды WMO (Open-Meteo): описание, значок Material Symbols, цвета неба.

function describe(code) {
    switch (code) {
    case 0: return "Ясно";
    case 1: return "Преимущественно ясно";
    case 2: return "Переменная облачность";
    case 3: return "Пасмурно";
    case 45: case 48: return "Туман";
    case 51: case 53: case 55: return "Морось";
    case 56: case 57: return "Ледяная морось";
    case 61: return "Небольшой дождь";
    case 63: return "Дождь";
    case 65: return "Сильный дождь";
    case 66: case 67: return "Ледяной дождь";
    case 71: return "Небольшой снег";
    case 73: return "Снег";
    case 75: return "Сильный снег";
    case 77: return "Снежная крупа";
    case 80: case 81: return "Ливень";
    case 82: return "Сильный ливень";
    case 85: case 86: return "Снегопад";
    case 95: return "Гроза";
    case 96: case 99: return "Гроза с градом";
    }
    return "—";
}

// clear | cloudy | fog | rain | snow | storm
function kind(code) {
    if (code <= 1) return "clear";
    if (code <= 3) return "cloudy";
    if (code === 45 || code === 48) return "fog";
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
    if (code >= 95) return "storm";
    return "rain";
}

// Сила дождя для капель на стекле 0..1 (0 — без дождя): морось < дождь < ливень, гроза — почти максимум
const rainPower = {
    51: 0.12, 53: 0.18, 55: 0.25, 56: 0.18, 57: 0.25,
    61: 0.35, 63: 0.5, 65: 0.7, 66: 0.4, 67: 0.65,
    80: 0.6, 81: 0.8, 82: 1.0,
    95: 0.85, 96: 0.9, 99: 0.95
};

function rain(code) {
    return rainPower[code] ?? 0;
}

function icon(code, isDay) {
    switch (kind(code)) {
    case "clear": return code === 0 ? (isDay ? "sunny" : "clear_night")
                                    : (isDay ? "partly_cloudy_day" : "partly_cloudy_night");
    case "cloudy": return code === 2 ? (isDay ? "partly_cloudy_day" : "partly_cloudy_night") : "cloud";
    case "fog": return "foggy";
    case "snow": return "weather_snowy";
    case "storm": return "thunderstorm";
    }
    return "rainy";
}

// Цвета неба [верх, низ] по типу погоды; phase: day | night (рассвет/закат подкрашивает карточка)
const skies = {
    day: {
        clear: ["#4f8fd6", "#2c66ad"], cloudy: ["#6c86a4", "#465d7a"], fog: ["#86929f", "#5e6976"],
        rain: ["#4d6276", "#304255"], snow: ["#8aa3bf", "#5d7c9c"], storm: ["#3c4355", "#222736"]
    },
    night: {
        clear: ["#111a36", "#050915"], cloudy: ["#1a2030", "#090c14"], fog: ["#242931", "#0f1217"],
        rain: ["#151b26", "#070a10"], snow: ["#232c40", "#0e121c"], storm: ["#101119", "#040408"]
    }
};

function sky(code, isDay) {
    return skies[isDay ? "day" : "night"][kind(code)];
}

const weekdays = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];

function weekday(isoDate) {
    const p = isoDate.split("-");
    return weekdays[new Date(+p[0], +p[1] - 1, +p[2]).getDay()];
}

const months = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"];

function dateLabel(isoDate) {
    const p = isoDate.split("-");
    return +p[2] + " " + months[+p[1] - 1];
}

const directions = ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"];

function direction(deg) {
    return directions[Math.round(deg / 45) % 8];
}

function temp(v) {
    return Math.round(v) + "°";
}

function decimal(v) {
    return (Math.round(v * 10) / 10).toString().replace(".", ",");
}
