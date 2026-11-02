.pragma library

// Видимые BarDropdown в порядке показа. Qt делает новый popup с захватом
// ввода дочерним к последнему видимому, поэтому его позицию нужно задавать
// относительно этого popup'а, а не бара.
// Переменные JS-библиотеки из QML только читаются — доступ через функции.
var stack = [];

function push(dropdown) {
    remove(dropdown);
    stack.push(dropdown);
}

function remove(dropdown) {
    const i = stack.indexOf(dropdown);
    if (i !== -1)
        stack.splice(i, 1);
}

function top() {
    return stack.length > 0 ? stack[stack.length - 1] : null;
}

// Закрыть все открытые окна (например, перед оверлеем скриншота:
// popup с захватом ввода перехватывает указатель)
function dismissAll() {
    const all = stack.slice();
    for (let i = all.length - 1; i >= 0; i--) {
        if (all[i].open) {
            all[i].dismissedAt = Date.now();
            all[i].dismissed();
        }
    }
}
