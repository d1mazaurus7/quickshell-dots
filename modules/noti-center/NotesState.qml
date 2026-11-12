import QtQuick
import Quickshell
import Quickshell.Io

// Заметки календаря: { "yyyy-MM-dd": { text, edited (мс) } } в data-каталоге оболочки.
// Файл отслеживается, поэтому экземпляры на разных экранах видят одни данные.
Item {
    id: root

    property var notes: ({})

    function key(date: date): string {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    function get(date: date): var {
        return notes[key(date)] ?? null;
    }

    // Пустой текст удаляет заметку
    function save(date: date, text: string): void {
        const next = Object.assign({}, notes);
        if (text.trim() === "")
            delete next[key(date)];
        else
            next[key(date)] = { text: text, edited: Date.now() };
        notes = next;
        file.setText(JSON.stringify(notes, null, 2));
    }

    FileView {
        id: file
        path: Quickshell.dataPath("notes.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.notes = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn("notes.json:", e);
            }
        }
    }
}
