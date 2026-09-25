-- loader.lua — FortniHub v15.6 FIXED (REAL-compatible)
-- Исправления: убран 2-й аргумент HttpGet, убран ?t=os.time(),
-- убраны опасные gsub, поправлен доступ к silent, добавлена диагностика.

local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua"

print("[FH] FortniHub v15.6 запускается...")

-- ============================================================
-- 1. Скачивание (БЕЗ второго аргумента — REAL его не любит)
-- ============================================================
local httpOk, body = pcall(function() return game:HttpGet(url) end)
if not httpOk then
    warn("[FH] HttpGet упал: " .. tostring(body))
    return
end
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua пустой или короткий. size=" .. tostring(type(body) == "string" and #body or "nil"))
    return
end
print("[FH] one.lua скачан, размер: " .. #body .. " байт")

-- Убираем ведущий "=" от lua-формата
body = body:gsub("^=+%s*\n", "")

-- ============================================================
-- 2. SafeRandom (на случай, если one.lua его где-то вызывает)
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
-- Дополнительно кладём как upvalue-совместимое имя
getgenv().FH_safeRandom = getgenv().safeRandom

-- ============================================================
-- 3. INJECT (Fluent patch + Silent bind + coin diag)
--    Вставляется ВНУТРЬ one.lua → имеет доступ к local silent / Notify / Tabs
-- ============================================================
local INJECT = [[

-- ⚡ FortniHub v15.6 inject
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
                    for _, name in ipairs({"AddToggle","AddSlider","AddDropdown",
                                            "AddInput","AddButton","AddLabel",
                                            "AddKeybind","AddColorpicker","AddColorPicker"}) do
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
                    if type(container.AddColorpicker) == "function" and type(container.AddColorPicker) ~= "function" then
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
        print("[FH] Fluent patch v15.6 применён")
    end

    -- ============ SILENT AIM BIND ============
    -- ВАЖНО: silent — это local в one.lua. Инжект находится в том же чанке,
    -- поэтому видит его как upvalue. Никаких SILENT (глобал) тут быть не должно.
    _G.FH_SILENT_BIND = Enum.KeyCode.E

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode ~= _G.FH_SILENT_BIND then return end

        -- silent может быть nil если порядок в one.lua изменился — защищаемся
        local sn = (type(silent) == "table") and silent or nil
        if not (sn and sn.enabled) then
            pcall(function()
                if type(Notify) == "function" then
                    Notify("FortniHub", "Включи Silent Aim в Бой", 2)
                end
            end)
            return
        end

        local char = LocalPlayer.Character
        if not char then return end
        local gun = char:FindFirstChild("Gun")
        if not gun then
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            gun = bp and bp:FindFirstChild("Gun")
            if gun then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(gun) end
                task.wait(0.05)
            end
        end
        if not gun then return end
        pcall(function() gun:Activate() end)
        pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
    end)

    -- UI для бинда (мягко, через pcall)
    task.spawn(function()
        task.wait(4)
        if not (Tabs and Tabs.Combat) then return end
        pcall(function()
            local sec = Tabs.Combat:AddSection({Name = "silent_bind"})
            if sec and sec.AddKeybind then
                sec:AddKeybind("SilentBindKey", {
                    Title = "Кнопка тихого выстрела (Silent)",
                    Default = "E",
                }):OnChanged(function(k)
                    local ok, kc = pcall(function() return Enum.KeyCode[k] end)
                    if ok and kc then
                        _G.FH_SILENT_BIND = kc
                        print("[FH] Silent bind: " .. tostring(kc))
                    end
                end)
            end
        end)
    end)

    print("[FH] Silent Aim Bind активен (E)")

    -- ============ AUTOFARM DIAG ============
    task.spawn(function()
        task.wait(3)
        local ok, coins = pcall(function() return CollectionService:GetTagged("CoinVisual") end)
        if ok and type(coins) == "table" then
            print("[FH] CoinVisual найдено: " .. #coins .. " шт.")
        else
            warn("[FH] CoinVisual тег не работает в этой версии MM2!")
        end
    end)
end

]]

-- ============================================================
-- 4. Инжект INJECT в нужное место
-- ============================================================
local injected = false
body = body:gsub('(logInfo%("Fluent загружен"%)%s*\n)', function(m)
    injected = true
    return m .. INJECT
end, 1)

if not injected then
    warn("[FH] Точка инжекта logInfo('Fluent загружен') не найдена — вставляю INJECT в конец файла")
    body = body .. "\n" .. INJECT
    -- Внимание: если инжект в конце, silent/Notify/Tabs будут недоступны как upvalue.
    -- Тогда фичи инжекта (кроме Fluent patch) не заработают. Проверь one.lua.
end

-- ============================================================
-- 5. Компиляция с подробной диагностикой
-- ============================================================
print("[FH] Компилирую " .. #body .. " байт...")
local fn, err = loadstring(body, "@FortniHub_v15.6")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local runOk, runErr = pcall(fn)
if not runOk then
    warn("[FH] Runtime упал: " .. tostring(runErr))
else
    print("[FH] FortniHub v15.6 загружен успешно!")
end 
