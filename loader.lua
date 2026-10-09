-- ============================================================
-- loader.lua — FortniHub v20.2 BETA
-- ============================================================

local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url  = BASE .. "one.lua"

print("[FH] FortniHub loader запускается...")

local ok_http, body = pcall(function() return game:HttpGet(url) end)
if not ok_http then warn("[FH] HttpGet упал: "..tostring(body)) return end
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua пустой. size="..tostring(type(body)=="string" and #body or "nil")) return
end
print("[FH] one.lua скачан, размер: "..#body.." байт")
body = body:gsub("^=+%s*\n", "")

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

print("[FH] Компилирую "..#body.." байт...")
local fn, err = loadstring(body, "@FortniHub_v20")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: "..tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok_run, run_err = pcall(fn)
if not ok_run then
    warn("[FH] Runtime упал: "..tostring(run_err))
else
    print("[FH] FortniHub загружен успешно!")
end
