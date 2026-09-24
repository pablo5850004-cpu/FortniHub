local BASE  = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local FILES = { "one" }

for _, name in ipairs(FILES) do
    local url = BASE .. name .. ".lua"
    local ok, err = pcall(function()
        -- 1) качаем
        local body = game:HttpGet(url, true)
        if type(body) ~= "string" or #body < 32 then
            error("пустой ответ (" .. tostring(body and #body or "nil") .. " байт). Проверь URL: " .. url)
        end
        -- 2) проверяем, что это не HTML-404
        local head = body:sub(1, 200):lower()
        if head:find("<!doctype") or head:find("<html") or head:find("not found") or head:find("404") then
            error("сервер вернул HTML/404. Файл не существует или репа приватная: " .. url)
        end
        -- 3) компилируем
        local fn, compileErr = loadstring(body, "@" .. name)
        if type(fn) ~= "function" then
            error("синтаксическая ошибка в " .. name .. ".lua: " .. tostring(compileErr))
        end
        -- 4) выполняем
        fn()
    end)
    if not ok then
        warn("[FortniHub] Ошибка загрузки " .. name .. ".lua: " .. tostring(err))
    else
        print("[FortniHub] " .. name .. ".lua загружен")
    end
    task.wait(0.05)
end
