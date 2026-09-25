-- loader.lua — FortniHub v15.2.6 (Fluent text-patch)
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua?t=" .. os.time()

print("[FH] FortniHub v15.2.6 запускается...")
local body = game:HttpGet(url, true)
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua не скачался")
    return
end

-- Убираем === в начале
body = body:gsub("^=+%s*\n", "")

-- SafeRandom
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

-- Патчи math.random
body = body:gsub("math%.random%s*=%s*function", "_G.__patchedRandom = function")
body = body:gsub("string%.random%s*=%s*function", "_G.__patchedStringRandom = function")
body = body:gsub("math%.random%s*%(", "safeRandom(")

-- ============================================================
-- ПРЯМОЙ ТЕКСТОВЫЙ ФИКС Fluent API
-- ============================================================

-- 1. AddColorPicker → AddColorpicker (в твоём Fluent маленькая p)
body = body:gsub("AddColorPicker", "AddColorpicker")

-- 2. AddSection({Name = "abc"}) → AddSection("abc")
body = body:gsub(
    'AddSection%s*%(?{%s*Name%s*=%s*"([^"]*)"%s*}%s*%)',
    'AddSection("%1")'
)

-- 3. AddSection({Name = "abc" .. var}) → AddSection("abc" .. var)
body = body:gsub(
    'AddSection%s*%(?{%s*Name%s*=%s*"([^"]*)"%s*%.%.%s*([^}]+?)%s*}%s*%)',
    'AddSection("%1" .. %2)'
)

-- 4. AddSection({Name = <любое_выражение>}) — страховка:
--    если осталось, заменяем на AddSection("section") чтобы не крашить
body = body:gsub(
    'AddSection%s*%(?{%s*Name%s*=%s*[^}]-%s*}%s*%)',
    'AddSection("section")'
)

-- ============================================================
-- Компиляция
-- ============================================================
local fn, err = loadstring(body, "@FortniHub_v15.2.6")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok, err2 = pcall(fn)
if not ok then
    warn("[FH] Runtime упал: " .. tostring(err2))
else
    print("[FH] FortniHub v15.2.6 загружен успешно")
end
