local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local FILES = { "one", "two" }

local function fetch(url)
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(body) == "string" and #body > 32 then
        local head = body:sub(1, 200):lower()
        if not (head:find("<!doctype") or head:find("<html") or head:find("not found")) then
            return body
        end
    end
    return nil
end

for _, name in ipairs(FILES) do
    local url = BASE .. name .. ".lua"
    local body = fetch(url)
    if not body then
        warn("[FH] не удалось загрузить " .. name .. ".lua: " .. url)
    else
        local fn, err = loadstring(body, "@" .. name)
        if type(fn) ~= "function" then
            warn("[FH] ошибка компиляции " .. name .. ".lua: " .. tostring(err))
        else
            local ok2, err2 = pcall(fn)
            if not ok2 then
                warn("[FH] ошибка выполнения " .. name .. ".lua: " .. tostring(err2))
            else
                print("[FH] " .. name .. ".lua выполнен")
            end
        end
    end
    task.wait(0.1)
end
