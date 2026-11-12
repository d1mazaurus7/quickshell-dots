.pragma library

// Расширения видеофайлов (остальное — картинки)
const videoSuffixes = ["mp4", "webm", "mkv", "mov", "avi", "m4v", "ogv"];

// Шаблоны формы: n — вершин, inner — радиус внутренних вершин (1 — без них), rot — поворот, градусы
const polygons = {
    star: { n: 5, inner: 0.5, rot: -90 },
    cookie: { n: 12, inner: 0.84, rot: -90 },
    flower: { n: 8, inner: 0.68, rot: -90 },
    clover: { n: 4, inner: 0.42, rot: -45 },
    burst: { n: 10, inner: 0.78, rot: -90 },
    triangle: { n: 3, inner: 1, rot: -90 },
    diamond: { n: 4, inner: 1, rot: -90 },
    pentagon: { n: 5, inner: 1, rot: -90 },
    hexagon: { n: 6, inner: 1, rot: 0 }
};

const options = [
    { value: "rect", label: "Прямоугольник" },
    { value: "circle", label: "Круг" },
    { value: "cookie", label: "Material You" },
    { value: "flower", label: "Цветок" },
    { value: "clover", label: "Клевер" },
    { value: "burst", label: "Солнце" },
    { value: "star", label: "Звезда" },
    { value: "triangle", label: "Треугольник" },
    { value: "diamond", label: "Ромб" },
    { value: "pentagon", label: "Пятиугольник" },
    { value: "hexagon", label: "Шестиугольник" }
];

// SVG-путь фигуры на всё окно w×h; circle — эллипс. Углы многоугольников скругляются
// квадратичными кривыми, rounding 1 — точки среза сходятся в серединах рёбер (гладкий контур)
function path(name, w, h, rounding) {
    if (w <= 0 || h <= 0)
        return "";
    const rx = w / 2, ry = h / 2;
    const f = n => n.toFixed(2);
    if (name === "circle")
        return "M 0 " + f(ry) + " A " + f(rx) + " " + f(ry) + " 0 1 0 " + f(w) + " " + f(ry)
            + " A " + f(rx) + " " + f(ry) + " 0 1 0 0 " + f(ry) + " Z";
    const p = polygons[name];
    if (!p)
        return "";
    const count = p.inner < 1 ? p.n * 2 : p.n;
    const step = Math.PI * 2 / count;
    const rot = p.rot * Math.PI / 180;
    const v = [];
    for (let i = 0; i < count; i++) {
        const k = (p.inner < 1 && i % 2) ? p.inner : 1;
        v.push([rx + rx * k * Math.cos(rot + step * i), ry + ry * k * Math.sin(rot + step * i)]);
    }
    const t = Math.max(0, Math.min(1, rounding)) * 0.5;
    let d = "";
    for (let i = 0; i < count; i++) {
        const a = v[(i + count - 1) % count], b = v[i], e = v[(i + 1) % count];
        const s = [b[0] + (a[0] - b[0]) * t, b[1] + (a[1] - b[1]) * t];
        const q = [b[0] + (e[0] - b[0]) * t, b[1] + (e[1] - b[1]) * t];
        d += (i ? " L " : "M ") + f(s[0]) + " " + f(s[1])
            + " Q " + f(b[0]) + " " + f(b[1]) + " " + f(q[0]) + " " + f(q[1]);
    }
    return d + " Z";
}
