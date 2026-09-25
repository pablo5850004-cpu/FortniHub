-- ============================================================
-- loader.lua — FortniHub v16 FINAL
-- Чистый лоадер: скачивает one.lua, патчит Fluent, запускает.
-- ============================================================

local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url  = BASE .. "one.lua"

print("[FH] FortniHub loader запускается...")

-- ============================================================
-- 1. Скачивание one.lua
-- ============================================================
local ok_http, body = pcall(function() return game:HttpGet(url) end)
if not ok_http then
    warn("[FH] HttpGet упал: " .. tostring(body))
    return
end
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua пустой или короткий. size=" .. tostring(type(body) == "string" and #body or "nil"))
    return
end
print("[FH] one.lua скачан, размер: " .. #body .. " байт")

-- убираем ведущие "=" от lua-формата
body = body:gsub("^=+%s*\n", "")

-- ============================================================
-- 2. SafeRandom (на случай если one.lua его вызывает)
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
-- 3. INJECT — только Fluent patch + диагностика
--    (silent bind и AWP теперь живут в one.lua, дублей нет)
-- ============================================================
local INJECT = [[

-- ⚡ FortniHub inject (Fluent patch + diag)
do
    -- ============ FLUENT MONKEY-PATCH ============
    if type(Fluent) == "table" and type(Fluent.CreateWindow) == "function" then
        local origCreate = Fluent.CreateWindow
        Fluent.CreateWindow = function(self, ...)
            local win = origCreate(self, ...)
            if not win then return win end

            local origAddTab = win.AddTab
            win.AddTab = function(w, ...)
                local tab = origAddTab(w, ...)
                if not tab then return tab end

                local function hook(container)
                    if type(container) ~= "table" then return end
                    for _, name in ipairs({
                        "AddToggle","AddSlider","AddDropdown","AddInput","AddButton",
                        "AddLabel","AddKeybind","AddColorpicker","AddColorPicker"
                    }) do
                        local orig = container[name]
                        if type(orig) == "function" and not container["__hk_"..name] then
                            container["__hk_"..name] = true
                            container[name] = function(c, ...)
                                local r = orig(c, ...)
                                if type(r) == "table" and r.Option == nil then r.Option = r end
                                return r
                            end
                        end
                    end

                    if type(container.AddColorpicker) == "function"
                        and type(container.AddColorPicker) ~= "function" then
                        container.AddColorPicker = container.AddColorpicker
                    end

                    if type(container.AddSection) == "function" and not container.__hk_AS then
                        container.__hk_AS = true
                        local origAS = container.AddSection
                        container.AddSection = function(c, a)
                            if type(a) == "table" then a = a.Name or a.name or "section" end
                            if a == nil then a = "section" end
                            local sec = origAS(c, a)
                            if sec then
                                if sec.Option == nil then sec.Option = sec end
                                hook(sec)
                            end
                            return sec
                        end
                    end
                end

                hook(tab)
                return tab
            end
            return win
        end
        print("[FH] Fluent patch применён")
    end

    -- ============ COIN DIAG ============
    task.spawn(function()
        task.wait(3)
        local ok, coins = pcall(function()
            return CollectionService:GetTagged("CoinVisual")
        end)
        if ok and type(coins) == "table" then
            print("[FH] CoinVisual найдено: " .. #coins .. " шт.")
        else
            warn("[FH] CoinVisual тег не работает в этой версии MM2!")
        end
    end)
end

]]

-- ============================================================
-- 4. Вставляем INJECT после строки про Fluent
-- ============================================================
local injected = false
body = body:gsub('(print%s*%(%s*"[^"]*Fluent загружен[^"]*"%s*%)%s*\n)', function(m)
    injected = true
    return m .. INJECT
end, 1)

if not injected then
    warn("[FH] Точка инжекта не найдена — INJECT в конец (Fluent patch всё равно сработает)")
    body = body .. "\n" .. INJECT
else
    print("[FH] INJECT вставлен после Fluent")
end

-- ============================================================
-- 5. Компиляция + диагностика
-- ============================================================
print("[FH] Компилирую " .. #body .. " байт...")
local fn, err = loadstring(body, "@FortniHub_v16")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))

    -- автодиагностика строки
    local lineNum = tonumber(string.match(tostring(err), ":(%d+):"))
    if lineNum then
        local lines = {}
        for line in (body .. "\n"):gmatch("([^\r\n]*)\r?\n") do
            lines[#lines + 1] = line
        end
        print("[FH] === Контекст вокруг строки " .. lineNum .. " ===")
        for n = math.max(1, lineNum - 5), math.min(#lines, lineNum + 5) do
            local mark = (n == lineNum) and ">>>" or "   "
            print(string.format("[FH] %s %5d | %s", mark, n, lines[n]))
        end
        print("[FH] === Конец контекста ===")
    end
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok_run, run_err = pcall(fn)
if not ok_run then
    warn("[FH] Runtime упал: " .. tostring(run_err))
else
    print("[FH] FortniHub загружен успешно!")
end
