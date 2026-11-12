import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../shell/config"

// История чата, её сохранение в Bar/assistant/history и запросы к OpenRouter (chat/completions)
QtObject {
    id: root

    readonly property var cfg: Config.options.assistant
    // sender: "user" | "assistant" | "error" | "info"
    readonly property ListModel messages: ListModel {}
    property bool typing: false
    // Результат последней проверки /reload: "" — не проверялось, "ok" | "error"
    property string status: ""
    property var request: null

    readonly property var commands: [
        { name: cfg.clearCommand, description: "Новый чат" },
        { name: cfg.loadCommand, description: "Загрузить чат из истории" },
        { name: cfg.reloadCommand, description: "Проверить ключ и модель" }
    ]
    // Запрошен список сохранённых чатов (команда загрузки)
    signal historyRequested()

    // Файл текущего чата ("" — ещё не сохранялся); новые сверху
    readonly property string historyDir: Quickshell.shellPath("Bar/assistant/history")
    property string chatFile: ""
    readonly property FolderListModel historyFiles: FolderListModel {
        folder: "file://" + root.historyDir
        nameFilters: ["*.json"]
        showDirs: false
        sortField: FolderListModel.Time
    }
    readonly property FileView writer: FileView {
        preload: false
        blockWrites: true
        printErrors: false
    }
    readonly property FileView reader: FileView {
        blockLoading: true
    }

    // Смена ключа или модели сбрасывает результат проверки
    readonly property string connection: cfg.apiKey + "|" + cfg.model
    onConnectionChanged: status = ""

    // Возвращает false, если текст не принят (пусто или ждём ответ)
    function send(text: string): bool {
        text = text.trim();
        if (text === cfg.clearCommand) {
            clear();
            return true;
        }
        if (text === cfg.reloadCommand) {
            reload();
            return true;
        }
        if (text === cfg.loadCommand) {
            historyRequested();
            return true;
        }
        if (text === "" || typing)
            return false;
        messages.append({ sender: "user", content: text });
        save();

        if (cfg.apiKey === "") {
            messages.append({ sender: "error", content: "Не задан ключ API: Настройки → Ассистент" });
            return true;
        }

        const history = [];
        if (cfg.systemPrompt.trim() !== "")
            history.push({ role: "system", content: cfg.systemPrompt });
        for (let i = 0; i < messages.count; i++) {
            const m = messages.get(i);
            if (m.sender === "user" || m.sender === "assistant")
                history.push({ role: m.sender, content: m.content });
        }

        typing = true;
        const xhr = new XMLHttpRequest();
        request = xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || request !== xhr)
                return;
            typing = false;
            request = null;
            let reply = "";
            let error = "";
            try {
                const data = JSON.parse(xhr.responseText);
                if (data.error)
                    error = data.error.message || JSON.stringify(data.error);
                else
                    reply = data.choices[0].message.content.trim();
            } catch (e) {
                error = xhr.status ? "HTTP " + xhr.status : "Нет соединения";
            }
            if (error !== "")
                messages.append({ sender: "error", content: error });
            else {
                messages.append({ sender: "assistant", content: reply });
                save();
            }
        };
        xhr.open("POST", "https://openrouter.ai/api/v1/chat/completions");
        xhr.setRequestHeader("Authorization", "Bearer " + cfg.apiKey);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.send(JSON.stringify({
            model: cfg.model,
            messages: history,
            temperature: cfg.temperature,
            max_tokens: cfg.maxTokens
        }));
        return true;
    }

    // Новый чат: история и незавершённый запрос сбрасываются
    function clear(): void {
        if (request) {
            const xhr = request;
            request = null;
            xhr.abort();
        }
        typing = false;
        messages.clear();
        chatFile = "";
    }

    // Сохраняет реплики текущего чата; имя файла — время начала и первое сообщение
    function save(): void {
        const list = [];
        for (let i = 0; i < messages.count; i++) {
            const m = messages.get(i);
            if (m.sender === "user" || m.sender === "assistant")
                list.push({ sender: m.sender, content: m.content });
        }
        if (list.length === 0)
            return;
        if (chatFile === "") {
            const title = list[0].content.replace(/[\/\s]+/g, " ").trim().slice(0, 40);
            chatFile = historyDir + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + " " + title + ".json";
        }
        writer.path = chatFile;
        writer.setText(JSON.stringify({ messages: list }, null, 2));
    }

    function load(path: string): void {
        clear();
        // Сброс пути: повторная загрузка того же файла читает его заново
        reader.path = "";
        reader.path = path;
        try {
            for (const m of JSON.parse(reader.text()).messages)
                messages.append({ sender: m.sender, content: m.content });
            chatFile = path;
        } catch (e) {
            messages.append({ sender: "error", content: "Не удалось загрузить чат" });
        }
    }

    // Проверка ключа (GET /key) и наличия модели (GET /models)
    function reload(): void {
        if (cfg.apiKey === "") {
            status = "error";
            messages.append({ sender: "error", content: "Не задан ключ API: Настройки → Ассистент" });
            return;
        }
        get("https://openrouter.ai/api/v1/key", (keyData, keyError) => {
            if (keyError !== "") {
                status = "error";
                messages.append({ sender: "error", content: "Ключ API: " + keyError });
                return;
            }
            get("https://openrouter.ai/api/v1/models", (modelsData, modelsError) => {
                if (modelsError !== "") {
                    status = "error";
                    messages.append({ sender: "error", content: "Список моделей: " + modelsError });
                } else if (!modelsData.data.some(m => m.id === cfg.model)) {
                    status = "error";
                    messages.append({ sender: "error", content: "Модель не найдена: " + cfg.model });
                } else {
                    status = "ok";
                    messages.append({ sender: "info", content: "Подключено · " + cfg.model });
                }
            });
        });
    }

    function get(url: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            try {
                const data = JSON.parse(xhr.responseText);
                if (data.error)
                    done(null, data.error.message || JSON.stringify(data.error));
                else
                    done(data, "");
            } catch (e) {
                done(null, xhr.status ? "HTTP " + xhr.status : "Нет соединения");
            }
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("Authorization", "Bearer " + cfg.apiKey);
        xhr.send();
    }
}
