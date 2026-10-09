-- ============================================================
-- loader.lua — FortniHub v20.2 BETA
-- Грузит ровно два файла: one.lua + part2.lua
-- ============================================================
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local FILES = {"one.lua", "part2.lua"}

print("[FH] FortniHub loader запускается...")

for _, name in ipairs(FILES) do
    local url = BASE .. name
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" or #body < 100 then
        warn("[FH] Не скачал "..name..": "..tostring(body))
    else
        print("[FH] "..name.." скачан, "..#body.." байт")
        body = body:gsub("^=+%s*\n", "")
        local fn, err = loadstring(body, "@"..name)
        if type(fn) ~= "function" then
            warn("[FH] Компиляция "..name.." упала: "..tostring(err))
        else
            local ok2, err2 = pcall(fn)
            if not ok2 then
                warn("[FH] Runtime "..name.." упал: "..tostring(err2))
            else
                print("[FH] "..name.." загружен успешно")
            end
        end
    end
end

print("[FH] FortniHub загружен.")
