-- loader.lua — FortniHub v15.2.4 (fixed)
-- Автопатч one.lua под readonly math + Fluent AddSection

local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua?t=" .. os.time()

print("[FH] Загружаю FortniHub v15.2.4...")
local body = game:HttpGet(url, true)
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua не скачался")
    return
end
print("[FH] Скачано: " .. #body .. " байт")

-- Убираем служебные === в самом начале файла (если есть)
body = body:gsub("^=+%s*\n", "")

-- ============================================================
-- SafeRandom — создаём ОДИН РАЗ в getgenv
-- ============================================================
if not getgenv().safeRandom then
    local orig = math.random
    getgenv().safeRandom = function(a, b)
        if a == nil then return orig() end
        if b == nil then
            if type(a) ~= "number" or a ~= a or a < 1 then a = 1 end
            if a > 2147483647 then a = 2147483647 end
            return orig(math.floor(a))
        end
        a, b = tonumber(a) or 0, tonumber(b) or 0
        if a ~= a then a = 0 end
        if b ~= b then b = 0 end
        if b < a then a, b = b, a end
        if a == b then return a end
        return orig(math.floor(a), math.floor(b))
    end
end
safeRandom = getgenv().safeRandom

-- ============================================================
-- ПАТЧ 1: math.random = function → _G.__patchedRandom
-- (math readonly в Luau, поэтому не трогаем таблицу math)
-- ============================================================
body = body:gsub("math%.random%s*=%s*function", "_G.__patchedRandom = function")
body = body:gsub("string%.random%s*=%s*function", "_G.__patchedStringRandom = function")

-- ============================================================
-- ПАТЧ 2: все ВЫЗОВЫ math.random( → safeRandom(
-- ============================================================
body = body:gsub("math%.random%s*%(", "safeRandom(")

-- ============================================================
-- ПАТЧ 3: FIX Fluent AddSection({Name = "X"}) → AddSection("X")
-- Твоя версия Fluent принимает СТРОКУ, а не таблицу.
-- ============================================================
body = body:gsub(
    'AddSection%s*%(%s*{%s*Name%s*=%s*"([^"]*)"%s*}%s*%)',
    'AddSection("%1")'
)

-- ВАЖНО: LPH shim НЕ патчим! Патч `.-end` ломал компиляцию.

-- ============================================================
-- Компиляция и запуск
-- ============================================================
local fn, err = loadstring(body, "@FortniHub_v15.2.4")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok, err2 = pcall(fn)
if not ok then
    warn("[FH] Runtime упал: " .. tostring(err2))
else
    print("[FH] FortniHub v15.2.4 загружен успешно")
end
