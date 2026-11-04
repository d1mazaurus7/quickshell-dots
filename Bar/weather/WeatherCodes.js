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
        clear: ["#1f2d52", "#0c1328"], cloudy: ["#2a3245", "#141925"], fog: ["#353b46", "#1a1e26"],
        rain: ["#232c3a", "#10151e"], snow: ["#38445e", "#1b2132"], storm: ["#1b1d2a", "#0a0b13"]
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
