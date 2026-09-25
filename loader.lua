-- loader.lua — FortniHub v15.2.2 (auto-patch)
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua?t=" .. os.time()

local body = game:HttpGet(url, true)
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua не скачался")
    return
end

-- Убираем служебные разделители ==== в начале если есть
body = body:gsub("^=+%s*\n", "")

-- === ПАТЧ A: определяем safeRandom в getgenv ===
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

-- === ПАТЧ B: заменяем присваивание в math.random (readonly) ===
-- math.random = function(...)  →  _G.__patched = function(...)
body = body:gsub("math%.random%s*=%s*function", "_G.__patchedRandom = function")

-- === ПАТЧ C: заменяем все ВЫЗОВЫ math.random( на safeRandom( ===
body = body:gsub("math%.random%s*%(", "safeRandom(")

-- === ПАТЧ D: то же самое для string если где-то будет ===
body = body:gsub("string%.random%s*=%s*function", "_G.__patchedStringRandom = function")

-- === ПАТЧ E: оборачиваем LPH-шим в pcall (некоторые экзекуторы readonly) ===
-- Находим блок "if not LPH_OBFUSCATED then ... end" и оборачиваем в pcall
body = body:gsub("(if not LPH_OBFUSCATED then.-end)", "pcall(function() %1 end)")

print("[FH] one.lua скачан: " .. #body .. " байт")

local fn, err = loadstring(body, "@one")
if type(fn) ~= "function" then
    warn("[FH] one.lua не скомпилировался: " .. tostring(err))
    return
end

local ok, err2 = pcall(fn)
if not ok then
    warn("[FH] one.lua упал: " .. tostring(err2))
else
    print("[FH] one.lua выполнен успешно")
end
