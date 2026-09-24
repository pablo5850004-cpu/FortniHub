-- ============================================================
-- FortniHub :: loader.lua v14.0.0
-- Загружает части скрипта по очереди.
-- При разделении на новые файлы — просто добавь их имя в FILES.
-- ============================================================

local BASE  = "https://raw.githubusercontent.com/Pabo5850004-cpu/FortniHub/main/"
local FILES = { "one", "two" }  -- three, four, ... добавляй по мере роста

for _, name in ipairs(FILES) do
    local url = BASE .. name .. ".lua"
    local ok, err = pcall(function()
        loadstring(game:HttpGet(url))()
    end)
    if not ok then
        warn("[FortniHub] Ошибка загрузки " .. name .. ".lua: " .. tostring(err))
    else
        print("[FortniHub] " .. name .. ".lua загружен")
    end
    task.wait(0.05)
end
