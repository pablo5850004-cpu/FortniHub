local BASE  = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local FILES = { "one" }

print("========== FORTNIHUB DIAG ==========")
print("BASE =", BASE)

for _, name in ipairs(FILES) do
    local url = BASE .. name .. ".lua"
    print("----- ФАЙЛ: " .. name .. " -----")
    print("URL  =", url)

    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if not ok then
        warn("  [X] HttpGet упал:", res)
    else
        print("  [OK] HttpGet вернул:", type(res), "len =", type(res) == "string" and #res or "n/a")

        if type(res) == "string" then
            print("  --- ПЕРВЫЕ 300 СИМВОЛОВ ОТВЕТА ---")
            print(res:sub(1, 300))
            print("  --- КОНЕЦ ОТРЫВКА ---")

            if #res < 32 then
                warn("  [X] Ответ СЛИШКОМ КОРОТКИЙ. Это и есть твоя пустая строка.")
            else
                local head = res:sub(1, 200):lower()
                if head:find("<!doctype") or head:find("<html") or head:find("not found") or head:find("404") then
                    warn("  [X] Это HTML/404. Файла нет, репа приватная, или ветка не main.")
                else
                    local fn, cerr = loadstring(res, "@" .. name)
                    if type(fn) ~= "function" then
                        warn("  [X] loadstring вернул не функцию:", cerr)
                    else
                        print("  [OK] Компиляция прошла. Запускаю...")
                        local rok, rerr = pcall(fn)
                        if not rok then
                            warn("  [X] Ошибка выполнения:", rerr)
                        else
                            print("  [OK] " .. name .. ".lua выполнен")
                        end
                    end
                end
            end
        end
    end
    print("------------------------------------")
    task.wait(0.05)
end

print("========== END DIAG ==========")
