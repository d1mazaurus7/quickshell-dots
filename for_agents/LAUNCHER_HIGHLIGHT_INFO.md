# Информация о выделении в лаунчере

## Реализация

Используется кастомный механизм `highlight` компонента `ListView` с плавными анимациями перемещения и масштабирования.

## Основные параметры

### ListView
- `highlightFollowsCurrentItem: false` — ручное управление позицией выделения
- `clip: false` — позволяет выделению немного выходить за границы при масштабировании

### Компонент highlight
```qml
highlight: Item {
    width: appList.width
    height: 48
    y: appList.currentItem ? appList.currentItem.y : 0
    
    Behavior on y {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
    
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 8
        height: parent.height
        color: Theme.Palette.primary
        opacity: 0.3
        radius: 10
        scale: 1.04
        transformOrigin: Item.Center
        
        Behavior on scale {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }
}
```

### Анимации
1. **Перемещение (Y)**: `NumberAnimation` 250 мс с `Easing.OutCubic`
2. **Масштабирование**: постоянное увеличение до 1.04 с плавной анимацией 250 мс
3. **Скругление**: `radius: 10` для закругленных углов

**Важно**: 
- Позиция Y привязана к `currentItem.y`, анимация через `Behavior on y`
- Rectangle находится внутри Item для корректного масштабирования
- `width: parent.width - 8` — небольшие отступы по краям
- `scale: 1.04` — выделенный элемент немного увеличен
- Без throttling — плавное переключение даже при удержании клавиши

## Поведение

1. **Навигация клавишами**: При нажатии Up/Down выделение плавно перемещается по оси Y к новому элементу
2. **Прокрутка списка**: Используется `positionViewAtIndex(currentIndex, ListView.Contain)` для плавной прокрутки
3. **Клик мышью**: Выделение мгновенно устанавливается на кликнутый элемент
4. **Hover**: Элементы подсвечиваются цветом `Theme.Palette.surface_container_high` при наведении

## Отличия от предыдущей реализации

- ✅ Нет размытия и blur-эффектов
- ✅ Монотонный цвет выделения (`Theme.Palette.primary` с opacity 0.3)
- ✅ Выделение перемещается целиком, а не пересоздается
- ✅ Плавное перетекание по оси Y
- ✅ Фокус остается на текущем элементе, список прокручивается при необходимости

## Удаленные компоненты

- FlowHighlightAnimation — не используется
- FlowHighlight — не используется
- Все вызовы `createFlowHighlight()` — удалены
