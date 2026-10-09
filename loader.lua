-- ============================================================
-- loader.lua — FortniHub (один файл)
-- ============================================================
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url  = BASE .. "one.lua"

print("[FH] FortniHub loader запускается...")

local ok, body = pcall(function() return game:HttpGet(url) end)
if not ok or type(body) ~= "string" or #body < 100 then
    warn("[FH] Не скачал one.lua: "..tostring(body))
    return
end

print("[FH] one.lua скачан, "..#body.." байт")
body = body:gsub("^=+%s*\n", "")

local fn, err = loadstring(body, "@FortniHub")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: "..tostring(err))
    return
end

local ok2, err2 = pcall(fn)
if not ok2 then
    warn("[FH] Runtime упал: "..tostring(err2))
else
    print("[FH] FortniHub загружен.")
end
