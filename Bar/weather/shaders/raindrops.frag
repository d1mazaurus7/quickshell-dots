#version 440

// Капли дождя на стекле поверх неба окна погоды. Всё процедурно, один проход; вне капель прозрачно.
// Слои:
//  - мелкие и крупные капли: разного размера и формы (овалы, «слёзы»); сидят на стекле,
//    пока их не вберёт стекающая капля, на высохшем следе садятся снова;
//  - «бусы»: вертикальные цепочки мелких капель — следы стёкших раньше капель;
//  - стекающие капли: в каждом столбце по очереди (чем сильнее дождь, тем чаще и быстрее);
//    каплевидная голова движется рывками и неравномерно, путь почти прямой с плавным уводом;
//    за ней — струйка, выше распадается на бусины и подсыхает; по пути вбирает остальные капли;
//  - едва заметные струи дождя за стеклом.
// Внутри капли фон преломляется (перевёрнуто, сильнее у крупных; при lens = 1 — как лупа), край темнее,
// снизу внутри — светлая каустика, сверху — блик.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float unit;
    float time;
    float staticAmount;
    float slideAmount;
    float dropSize;
    float streaks;
    float topRadius;
    float bottomRadius;
    float lens;        // 0 — капля на стекле перед далёким небом (перевёрнутое изображение),
                       // 1 — капля на поверхности (лупа с искажением и радужной каймой)
};

layout(binding = 1) uniform sampler2D source;

float hash1(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec4 hash4(vec2 p) {
    vec4 q = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
    q += dot(q, q.wzxy + 33.33);
    return fract((q.xxyz + q.yzzw) * q.zywx);
}

float vnoise(float x) {
    float i = floor(x);
    float f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash1(i), hash1(i + 1.0), f);
}

// Лучшая капля под пикселем: (v.x, v.y, покрытие, радиус в пикселях)
vec4 best = vec4(0.0);

// Капля: d — смещение от центра, r — радиус; выше центра капля длиннее (elong) и уже (taper)
void drop(vec2 d, float r, float sx, float elong, float taper, float alpha, float scale) {
    if (alpha <= 0.0 || r <= 0.0)
        return;
    vec2 q = d / r;
    q.x /= sx;
    if (q.y < 0.0) {
        q.y /= elong;
        q.x *= 1.0 + taper * -q.y;
    }
    float len = length(q);
    if (len >= 1.0)
        return;
    float rpx = r * scale;
    float m = smoothstep(1.0, 1.0 - 1.6 / max(rpx, 1.0), len) * alpha;
    if (m > best.z)
        best = vec4(q, m, rpx);
}

// Стекающие капли: столбцы шириной colW со сдвигом shift; layerSeed различает слои
const float colW = 0.62;

float pathX(float col, float y, float seed, float shift) {
    return (col + 0.5) * colW + shift + (seed - 0.5) * 0.35 * colW
           + 0.22 * colW * (vnoise(y * 0.7 + seed * 91.0) - 0.5) + 0.06 * colW * (vnoise(y * 3.1 + seed * 17.0) - 0.5);
}

// Голова капли в столбце: (y, радиус, длина следа, 1) или нули, пока столбец ждёт.
// Цикл столбца: проход головы через всё окно и пауза; amount сокращает паузу и ускоряет капли
vec4 head(float col, float layerSeed, float amount, out float seed, out bool solid) {
    vec4 h = hash4(vec2(col, layerSeed));
    seed = h.y;
    solid = h.w < 0.3;
    if (amount <= 0.0)
        return vec4(0.0);
    float span = itemSize.y / (100.0 * unit * dropSize);
    float trail = 2.0 + 4.0 * h.x;
    float dist = span + trail + 0.8;
    float speed = (0.7 + 0.8 * h.z) * (0.6 + 0.9 * amount);
    float run = dist / speed;
    float period = run * (1.0 + (1.0 - amount) * (0.6 + 2.5 * h.x));
    float cyc = time / period + h.w * 7.0;
    float ph = fract(cyc) * period / run;
    if (ph >= 1.0)
        return vec4(0.0);
    // Неравномерное движение без явного периода: монотонно, но то почти стоит, то срывается
    float k1 = 3.0 + floor(h.z * 3.0);
    float k2 = 7.3 + 3.0 * h.y;
    float s = ph - 0.62 * sin(6.2831853 * k1 * ph) / (6.2831853 * k1)
                 - 0.3 * sin(6.2831853 * k2 * ph + h.w * 6.0) / (6.2831853 * k2);
    float y = -0.4 + s * dist;
    float r = 0.075 + 0.05 * hash1(floor(cyc) * 1.3 + col);
    return vec4(y, r, trail, 1.0);
}

// Вобрана ли точка стекающей каплей (1 — да); к концу высыхания следа — снова свободна
float wipeAt(vec2 c, float layerSeed, float amount, float shift) {
    float col = floor((c.x - shift) / colW);
    float seed;
    bool solid;
    vec4 hd = head(col, layerSeed, amount, seed, solid);
    if (hd.w == 0.0)
        return 0.0;
    float above = hd.x - c.y;
    if (above < -hd.y * 0.6 || above > hd.z)
        return 0.0;
    float dx = abs(c.x - pathX(col, c.y, seed, shift));
    if (dx > hd.y * 1.5)
        return 0.0;
    return 1.0 - smoothstep(0.75, 1.0, above / hd.z);
}

float wipe(vec2 c) {
    float w = max(wipeAt(c, 3.0, slideAmount, 0.0), wipeAt(c, 11.0, (slideAmount - 0.45) * 1.8, colW * 0.5));
    if (slideAmount > 1.0)
        w = max(w, wipeAt(c, 19.0, (slideAmount - 1.0) * 2.0, colW * 0.25));
    return w;
}

void slideLayer(vec2 p, float layerSeed, float amount, float shift, float scale) {
    float col = floor((p.x - shift) / colW);
    float seed;
    bool solid;
    vec4 hd = head(col, layerSeed, amount, seed, solid);
    if (hd.w == 0.0)
        return;
    float r = hd.y;
    float hx = pathX(col, hd.x, seed, shift);
    // Голова: круглая снизу, вытянутая и сужающаяся кверху
    drop(p - vec2(hx, hd.x), r, 1.0, 1.6, 0.45, 1.0, scale);

    float above = hd.x - p.y;
    if (above <= r * 0.5 || above > hd.z)
        return;
    float f = above / hd.z;
    float px = pathX(col, p.y, seed, shift);
    float dx = p.x - px;
    float dry = 1.0 - smoothstep(0.75, 1.0, f);
    // Струйка у головы (у сплошных — по всей длине), сужается кверху
    float streamEnd = solid ? 1.0 : 0.3;
    if (f < streamEnd) {
        float w = r * (solid ? 0.55 : 0.5) * (1.0 - 0.55 * f / streamEnd);
        if (abs(dx) < w) {
            float rpx = w * scale;
            float m = smoothstep(w, w - 1.6 / scale, abs(dx)) * dry;
            if (m > best.z)
                best = vec4(dx / w, 0.0, m, rpx);
        }
    }
    // Бусины выше струйки: разного размера и шага
    if (!solid && f > 0.18) {
        float cell = 0.11;
        float cy = floor(p.y / cell);
        vec4 hb = hash4(vec2(cy, col * 7.0 + layerSeed));
        if (hb.x < 0.65) {
            float by = (cy + 0.5 + (hb.y - 0.5) * 0.4) * cell;
            float bx = pathX(col, by, seed, shift) + (hb.z - 0.5) * 0.02;
            float rb = r * (0.18 + 0.32 * hb.w) * (1.0 - 0.5 * f);
            drop(p - vec2(bx, by), rb, 0.9, 1.3 + hb.z, 0.3, dry, scale);
        }
    }
}

// Капли сетки: cell — размер ячейки, rmin..rmax — радиусы (много мелких, мало крупных)
void scatterLayer(vec2 p, float cell, float rmin, float rmax, float amount, float seed, float scale) {
    vec2 id = floor(p / cell);
    vec4 g = hash4(id * 1.37 + seed);
    if (g.x >= amount)
        return;
    vec2 c = (id + 0.5 + (g.yz - 0.5) * 0.5) * cell;
    float size = g.w * g.w * g.w;
    // Вобранная стекающей каплей не видна, на высохшем следе нарастает снова
    float r = mix(rmin, rmax, size) * (1.0 - wipe(c));
    float n = 0.0;
    float elong = 1.0 + 0.9 * hash1(g.y * 31.0 + n) * size + 0.3 * g.z;
    float tq = hash1(g.z * 17.0 + n);
    float taper = 0.6 * tq * tq * tq;
    float sx = 0.85 + 0.25 * g.y;
    drop(p - c, r, sx, elong, taper, 1.0, scale);
}

// «Бусы»: вертикальные цепочки мелких капель вдоль старых следов
void beadLayer(vec2 p, float scale) {
    const float bw = 0.24;
    float col = floor(p.x / bw);
    vec4 h = hash4(vec2(col, 41.0));
    if (h.x >= staticAmount * 0.8)
        return;
    float cell = 0.07 + 0.08 * h.y;
    float cy = floor(p.y / cell);
    vec4 g = hash4(vec2(cy, col));
    if (g.x >= 0.55)
        return;
    float y = (cy + 0.5 + (g.y - 0.5) * 0.5) * cell;
    float x = (col + 0.5) * bw + (h.z - 0.5) * 0.12 + 0.05 * (vnoise(y * 1.3 + h.w * 40.0) - 0.5) + (g.z - 0.5) * 0.012;
    float r = mix(0.018, 0.05, g.w * g.w) * (1.0 - wipe(vec2(x, y)));
    drop(p - vec2(x, y), r, 0.8, 1.3 + 0.8 * g.z, 0.15, 1.0, scale);
}

// Струи дождя за стеклом: смазанные движением штрихи в столбцах с лёгким наклоном.
// cellW — шаг столбцов, len — длина штриха, speed — скорость, всё в пикселях масштаба
float rainLayer(vec2 px, float cellW, float len, float speed, float width, float density, float seed) {
    vec2 q = px / unit;
    q.x += q.y * 0.1;
    float col = floor(q.x / cellW);
    vec4 h = hash4(vec2(col, seed));
    if (h.x > density)
        return 0.0;
    float cx = (col + 0.2 + 0.6 * h.y) * cellW;
    float w = width * (0.7 + 0.6 * h.z);
    float line = 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.8, abs(q.x - cx));
    if (line <= 0.0)
        return 0.0;
    float l = len * (0.6 + 0.8 * h.w);
    float period = l * (1.6 + 2.5 * h.z);
    float yy = q.y - time * speed * (0.8 + 0.4 * h.w) + h.y * 300.0;
    float seg = fract(yy / period) * period;
    // Штрих с мягкими концами, ярче к нижнему концу
    float a = smoothstep(0.0, l * 0.5, seg) * (1.0 - smoothstep(l * 0.85, l, seg));
    return a * line * (0.6 + 0.4 * h.z);
}

float insideWindow(vec2 px) {
    float r = px.y < itemSize.y * 0.5 ? topRadius : bottomRadius;
    vec2 c = clamp(px, vec2(r), itemSize - vec2(r));
    return clamp(r + 0.5 - length(px - c), 0.0, 1.0);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    float scale = 100.0 * unit * dropSize;
    vec2 p = px / scale;

    if (staticAmount > 0.0) {
        scatterLayer(p, 0.17, 0.02, 0.06, staticAmount, 1.0, scale);
        scatterLayer(p, 0.5, 0.05, 0.15, staticAmount * 0.75, 7.0, scale);
        beadLayer(p, scale);
    }
    if (slideAmount > 0.0) {
        slideLayer(p, 3.0, slideAmount, 0.0, scale);
        if (slideAmount > 0.45)
            slideLayer(p, 11.0, (slideAmount - 0.45) * 1.8, colW * 0.5, scale);
        // Выше 1 — «как из ведра»: третий слой стекающих капель
        if (slideAmount > 1.0)
            slideLayer(p, 19.0, (slideAmount - 1.0) * 2.0, colW * 0.25, scale);
    }

    float win = insideWindow(px);
    float m = best.z * win;

    float st = 0.0;
    if (streaks > 0.0) {
        // Дальние — тонкие и частые, ближние — длиннее, толще и быстрее
        st = 0.45 * rainLayer(px, 9.0, 34.0, 700.0, 1.0, 0.55, 5.0)
           + 0.8 * rainLayer(px, 23.0, 80.0, 1300.0, 1.6, 0.4, 9.0);
        st = min(st, 1.0) * streaks * win;
    }

    if (m <= 0.001 && st <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 v = best.xy;
    float len = length(v);
    float d2 = min(dot(v, v), 1.0);
    vec3 col;
    if (lens < 0.5) {
        // Перевёрнутое изображение из области вокруг капли, у крупных — шире
        vec2 off = -v * best.w * 2.2 / itemSize;
        col = texture(source, clamp(qt_TexCoord0 + off, vec2(0.001), vec2(0.999))).rgb;
        col = mix(col, vec3(dot(col, vec3(0.333))), 0.15) * 1.08;
    } else {
        // Лупа: к центру увеличение, к краю сильнее (бочка); каналы чуть расходятся у края
        vec2 off = -v * best.w * (0.55 - 0.3 * d2) / itemSize;
        vec2 ca = -v * best.w * 0.06 * d2 / itemSize;
        vec2 uv = qt_TexCoord0 + off;
        col.r = texture(source, clamp(uv - ca, vec2(0.001), vec2(0.999))).r;
        col.g = texture(source, clamp(uv, vec2(0.001), vec2(0.999))).g;
        col.b = texture(source, clamp(uv + ca, vec2(0.001), vec2(0.999))).b;
        col *= 1.04;
    }
    // Край темнее (полное отражение), сильнее сверху
    float edge = smoothstep(0.62, 1.0, len);
    col *= 1.0 - edge * (0.5 + 0.15 * smoothstep(0.0, -1.0, v.y));
    // Каустика: едва заметная тонкая полоска света у нижнего края внутри
    col += vec3(0.07) * smoothstep(0.55, 0.95, v.y) * smoothstep(0.78, 0.92, len) * smoothstep(1.0, 0.94, len);
    // Блик сверху-слева, у мелких капель меньше
    float spec = smoothstep(0.22, 0.0, length(v - vec2(-0.3, -0.5)));
    col += vec3(0.85) * spec * smoothstep(1.5, 4.0, best.w);

    vec4 drp = vec4(col, 1.0) * m;
    vec4 streak = vec4(vec3(st), st);
    fragColor = (drp + streak * (1.0 - drp.a)) * qt_Opacity;
}
