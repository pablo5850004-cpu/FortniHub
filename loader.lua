-- ============================================================
-- loader.lua — точка входа
-- Запускается через loadstring(game:HttpGet("..." ))()
-- ============================================================

local BASE_URL = "local BASE_URL = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/""

-- Глобальная таблица для shared state
getgenv().FH = getgenv().FH or {}
local FH = getgenv().FH

FH.VERSION = "1.0.0"
FH.BASE_URL = BASE_URL
FH.Modules = {}
FH.Connections = {}

-- ============================================================
-- Загрузчик модулей
-- ============================================================
local cache = {}

local function LoadModule(path)
    if cache[path] then return cache[path] end

    local url = BASE_URL .. path .. ".lua"
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)

    if not ok then
        warn("[FH] Ошибка загрузки " .. path .. ": " .. tostring(result))
        return nil
    end

    cache[path] = result
    print("[FH] Загружено: " .. path)
    return result
end

-- ============================================================
-- Подгрузка библиотек
-- ============================================================
LoadModule("lib/utils")
LoadModule("lib/ui")

-- ============================================================
-- Подгрузка модулей
-- ============================================================
LoadModule("modules/combat")
LoadModule("modules/movement")
LoadModule("modules/visual")
LoadModule("modules/autofarm")

-- ============================================================
-- Финализация
-- ============================================================
if FH.Notify then
    FH.Notify("FortniHub", "Загружено v" .. FH.VERSION, 4)
end

print("[FH] Loader завершён. Версия: " .. FH.VERSION)
