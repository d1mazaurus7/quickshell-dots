pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../shell/config"

// Погода из Open-Meteo. Местоположение — по IP (ip-api.com) или геокодером Open-Meteo по Config.options.weather.city.
// Обновляется по таймеру refreshInterval и при смене местоположения в настройках.
Singleton {
    id: root

    readonly property var cfg: Config.options.weather

    property string city: ""
    property bool loading: false
    property bool ready: false
    property string error: ""
    // { temp, feels, humidity, precip, code, wind, windDir, isDay }
    property var current: ({})
    // [{ time, date, minutes, temp, feels, humidity, precip, code, wind, windDir, isDay }], от текущего часа на сутки вперёд
    property var hourly: []
    // [{ date, code, min, max, precip, hours: [{ time, temp, code, isDay }] с шагом 3 ч }], 7 дней начиная с сегодня
    property var daily: []
    property string sunrise: ""
    property string sunset: ""
    // Восход и закат сегодня, минуты от полуночи — для подкраски неба
    property int sunriseMin: 0
    property int sunsetMin: 0

    property int generation: 0

    // Имя монитора, на котором открыто окно погоды ("" — закрыто); пишут модуль и IPC
    property string openOutput: ""

    function refresh() {
        if (!Config.ready)
            return;
        generation++;
        loading = true;
        error = "";
        if (cfg.autoLocation) {
            request("http://ip-api.com/json/?lang=ru&fields=status,city,lat,lon", r => {
                if (r.status !== "success")
                    return fail("Не удалось определить местоположение");
                load(r.city, r.lat, r.lon);
            });
        } else if (cfg.city.trim() === "") {
            fail("Укажите город в настройках");
        } else {
            request("https://geocoding-api.open-meteo.com/v1/search?count=1&language=ru&name="
                    + encodeURIComponent(cfg.city.trim()), r => {
                const place = r.results?.[0];
                if (!place)
                    return fail("Город не найден");
                load(place.name, place.latitude, place.longitude);
            });
        }
    }

    function request(url, done) {
        const gen = generation;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || gen !== root.generation)
                return;
            if (xhr.status !== 200)
                return root.fail("Нет соединения");
            let data;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {
                return root.fail("Некорректный ответ сервера");
            }
            done(data);
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function fail(message) {
        loading = false;
        error = message;
    }

    function load(name, lat, lon) {
        city = name;
        request("https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
                + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,"
                + "weather_code,wind_speed_10m,wind_direction_10m,is_day"
                + "&hourly=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,"
                + "weather_code,wind_speed_10m,wind_direction_10m,is_day"
                + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,sunrise,sunset"
                + "&timezone=auto&wind_speed_unit=ms&forecast_days=7", parse);
    }

    function minutes(iso) {
        return Number(iso.slice(11, 13)) * 60 + Number(iso.slice(14, 16));
    }

    function parse(r) {
        const c = r.current, h = r.hourly, d = r.daily;
        current = {
            temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m,
            precip: c.precipitation, code: c.weather_code, wind: c.wind_speed_10m,
            windDir: c.wind_direction_10m, isDay: c.is_day === 1
        };

        const hour = c.time.slice(0, 13);
        const start = Math.max(0, h.time.findIndex(t => t.slice(0, 13) === hour));
        const hours = [{
            time: "Сейчас", date: c.time.slice(0, 10), minutes: minutes(c.time), temp: c.temperature_2m,
            feels: c.apparent_temperature, humidity: c.relative_humidity_2m, precip: c.precipitation,
            code: c.weather_code, wind: c.wind_speed_10m, windDir: c.wind_direction_10m, isDay: c.is_day === 1
        }];
        for (let i = start + 1; i < Math.min(h.time.length, start + 25); i++)
            hours.push({
                time: h.time[i].slice(11, 16), date: h.time[i].slice(0, 10), minutes: minutes(h.time[i]),
                temp: h.temperature_2m[i], feels: h.apparent_temperature[i], humidity: h.relative_humidity_2m[i],
                precip: h.precipitation[i], code: h.weather_code[i], wind: h.wind_speed_10m[i],
                windDir: h.wind_direction_10m[i], isDay: h.is_day[i] === 1
            });
        hourly = hours;

        const byDate = {};
        for (let i = 0; i < h.time.length; i++) {
            if (Number(h.time[i].slice(11, 13)) % 3 !== 0)
                continue;
            const date = h.time[i].slice(0, 10);
            if (!byDate[date])
                byDate[date] = [];
            byDate[date].push({ time: h.time[i].slice(11, 16), temp: h.temperature_2m[i], code: h.weather_code[i], isDay: h.is_day[i] === 1 });
        }

        const days = [];
        for (let i = 0; i < d.time.length; i++)
            days.push({ date: d.time[i], code: d.weather_code[i], min: d.temperature_2m_min[i],
                        max: d.temperature_2m_max[i], precip: d.precipitation_sum[i], hours: byDate[d.time[i]] || [] });
        daily = days;

        sunrise = d.sunrise[0].slice(11, 16);
        sunset = d.sunset[0].slice(11, 16);
        sunriseMin = minutes(d.sunrise[0]);
        sunsetMin = minutes(d.sunset[0]);

        loading = false;
        ready = true;
    }

    Timer {
        running: Config.ready
        repeat: true
        triggeredOnStart: true
        interval: root.cfg.refreshInterval * 60000
        onTriggered: root.refresh()
    }

    Connections {
        target: root.cfg
        function onAutoLocationChanged() { root.refresh(); }
        function onCityChanged() { root.refresh(); }
    }
}
