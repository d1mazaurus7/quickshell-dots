# components/animations

## BarDropdown

Выпадающее окно, которое «выплывает» из нижней кромки бара под элементом
и соединяется с баром вогнутыми скруглениями («ушами»). Это `PopupWindow`
с анимированной высотой и фоном цвета бара (`Theme.Palette.background`).

Пример: `modules/bluetooth/Bluetooth.qml`.

### Подключение

```qml
import "../../components/animations" as Anim   // путь относительно файла модуля

Item {
    id: root
    property bool open: false

    function toggle() {
        // Клик по кнопке, который закрыл окно (клик вне его), не открывает его снова.
        if (!open && dropdown.recentlyDismissed())
            return;
        open = !open;
    }

    Rectangle {
        id: button              // элемент в баре
        MouseArea { anchors.fill: parent; onClicked: root.toggle() }
    }

    Anim.BarDropdown {
        id: dropdown
        anchorItem: button
        open: root.open
        onDismissed: root.open = false   // обязательно

        // Содержимое: любые элементы, ширина — parent.width,
        // высота берётся из их implicitHeight/height.
        ColumnLayout {
            width: parent.width
            Text { text: "Hello" }
        }
    }
}
```

### Свойства

| Свойство        | По умолчанию                 | Назначение                                        |
|-----------------|------------------------------|---------------------------------------------------|
| `anchorItem`    | — (обязательное)             | Элемент бара, под которым центрируется окно       |
| `open`          | `false`                      | Открыто ли окно (держит владелец)                 |
| `contentWidth`  | `320`                        | Ширина тела окна без «ушей»                       |
| `padding`       | `12`                         | Внутренний отступ вокруг содержимого              |
| `radius`        | `16`                         | Радиус нижних углов                               |
| `earRadius`     | `16`                         | Радиус вогнутых скруглений у стыка с баром        |
| `barRadius`     | `BarStyle.radius`            | Радиус нижних углов бара (окно не заходит на них) |
| `attached`      | `BarStyle.filled`            | `true` — окно срастается с баром «ушами»; `false` (модульный стиль) — отдельная плашка со скруглёнными углами на `BarStyle.popupGap` ниже бара; `ear` — фактический радиус ушей |
| `fillColor`     | `Theme.Palette.background`   | Цвет фона; должен совпадать с цветом бара         |
| `animDuration`  | `220`                        | Длительность раскрытия/закрытия, мс               |
| `alignRight`    | `false`                      | Прижать к правому краю бара, без правого «уха»    |

Сигнал `dismissed()` — окно закрыто композитором (клик вне окна).
Метод `recentlyDismissed()` — `true` в течение 200 мс после `dismissed()`.

### Правила

- Владелец хранит `open` сам и сбрасывает его в `onDismissed`;
  не присваивайте `dropdown.open` напрямую, иначе привязка сломается.
- Содержимое кладётся прямо внутрь `BarDropdown`, без обёрток.
  Задавайте ему `width: parent.width`, а не anchors.fill: высоту окно
  считает по содержимому (`childrenRect`).
- Окно считается по нижней кромке окна бара, поэтому `anchorItem` должен
  лежать в `PanelWindow` бара, прижатом к верху экрана.
- Цвета только из `Theme.Palette`, без захардкоженных значений.
