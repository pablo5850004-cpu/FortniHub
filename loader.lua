local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua"
local body = game:HttpGet(url, true)
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua не скачался")
    return
end
local fn = loadstring(body, "@one")
if type(fn) ~= "function" then
    warn("[FH] one.lua не скомпилировался")
    return
end
local ok, err = pcall(fn)
if not ok then
    warn("[FH] one.lua упал: " .. tostring(err))
else
    print("[FH] one.lua выполнен")
end
