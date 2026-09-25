-- loader.lua — FortniHub v15.3 ULTIMATE
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua?t=" .. os.time()

print("[FH] FortniHub v15.3 запускается...")
local body = game:HttpGet(url, true)
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua не скачался")
    return
end

body = body:gsub("^=+%s*\n", "")

-- ============================================================
-- SAFE RANDOM
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
body = body:gsub("math%.random%s*=%s*function", "_G.__patchedRandom = function")
body = body:gsub("string%.random%s*=%s*function", "_G.__patchedStringRandom = function")
body = body:gsub("math%.random%s*%(", "safeRandom(")

-- ============================================================
-- FLUENT API FIX
-- ============================================================
body = body:gsub("AddColorPicker", "AddColorpicker")
body = body:gsub(
    'AddSection%s*%(?{%s*Name%s*=%s*"([^"]*)"%s*%}%s*%)',
    'AddSection("%1")'
)
body = body:gsub(
    'AddSection%s*%(?{%s*Name%s*=%s*[^}]-%s*}%s*%)',
    'AddSection("section")'
)

-- ============================================================
-- РУССКИЙ ЯЗЫК — переводим английские названия
-- ============================================================
local TRANSLATIONS = {
    -- Effects section
    ['"ESP Engine v15.2"'] = '"ESP Игроков"',
    ['"Box"'] = '"Рамка (бокс)"',
    ['"Box Color"'] = '"Цвет рамки"',
    ['"Box Alpha"'] = '"Прозрачность рамки"',
    ['"Box Type"'] = '"Тип рамки"',
    ['"Box Gradient"'] = '"Градиент рамки"',
    ['"Box Fill"'] = '"Заливка рамки"',
    ['"Fill Color"'] = '"Цвет заливки"',
    ['"Fill Alpha"'] = '"Прозрачность заливки"',
    ['"Grad 1"'] = '"Градиент 1"',
    ['"Grad 2"'] = '"Градиент 2"',
    ['"Name"'] = '"Имя"',
    ['"Name Color"'] = '"Цвет имени"',
    ['"Distance"'] = '"Дистанция"',
    ['"Distance Color"'] = '"Цвет дистанции"',
    ['"Avatar"'] = '"Аватарка"',
    ['"Skeleton"'] = '"Скелет"',
    ['"Skeleton Color"'] = '"Цвет скелета"',
    ['"Glow Chams"'] = '"Свечение (Chams)"',
    ['"Murder Fill"'] = '"Убийца заливка"',
    ['"Murder Outline"'] = '"Убийца обводка"',
    ['"Inno Fill"'] = '"Мирный заливка"',
    ['"Inno Outline"'] = '"Мирный обводка"',
    ['"Sheriff Fill"'] = '"Шериф заливка"',
    ['"Sheriff Outline"'] = '"Шериф обводка"',
    ['"Material Chams"'] = '"Материал-чамсы"',
    ['"Mat Type"'] = '"Тип материала"',
    ['"Murder"'] = '"Убийца"',
    ['"Inno"'] = '"Мирный"',
    ['"Sheriff"'] = '"Шериф"',
    ['"Flags (roles)"'] = '"Метки ролей"',
    ['"Off-screen Arrows"'] = '"Стрелки к игрокам"',
    ['"Arrow Size"'] = '"Размер стрелок"',
    ['"Arrow Dist"'] = '"Дистанция стрелок"',
    ['"Allow Local"'] = '"Показывать себя"',

    -- Effects main
    ['"Bullet Tracer"'] = '"Трассер пули"',
    ['"Color"'] = '"Цвет"',
    ['"Duration"'] = '"Длительность"',
    ['"World Aura"'] = '"Аура игрока"',
    ['"Type"'] = '"Тип"',
    ['"World Effects"'] = '"Эффекты мира"',
    ['"Rate"'] = '"Интенсивность"',
    ['"Shaders"'] = '"Шейдеры"',
    ['"Preset"'] = '"Пресет"',
    ['"Custom Fog"'] = '"Свой туман"',
    ['"Start"'] = '"Начало"',
    ['"End"'] = '"Конец"',
    ['"Custom Ambient"'] = '"Свой ambient"',
    ['"Ambient Color"'] = '"Цвет ambient"',
    ['"Exposure"'] = '"Экспозиция"',
    ['"Value"'] = '"Значение"',
    ['"Skybox"'] = '"Скайбокс (небо)"',

    -- Crosshair
    ['"Custom Crosshair"'] = '"Свой прицел"',
    ['"Gap"'] = '"Зазор"',
    ['"Length"'] = '"Длина"',
    ['"Thickness"'] = '"Толщина"',
    ['"Rotation"'] = '"Вращение"',
    ['"Outline"'] = '"Обводка"',

    -- Murder Effect
    ['"Murder Death Effect"'] = '"Эффект убийцы при смерти"',
    ['"Clone"'] = '"Клон"',
    ['"Clone Color"'] = '"Цвет клона"',
    ['"Clone Duration"'] = '"Длительность клона"',
    ['"Particle"'] = '"Частицы"',
    ['"Particle Color"'] = '"Цвет частиц"',
    ['"Neverlose Emitter"'] = '"Emitter (никогда не проигрывает)"',
    ['"Emitter Color"'] = '"Цвет emitter"',
    ['"Emitter Duration"'] = '"Длительность emitter"',

    -- Local visuals
    ['"China Hat"'] = '"Китайская шляпа"',
    ['"Hat Color"'] = '"Цвет шляпы"',
    ['"Backtrack"'] = '"Бэктрек"',
    ['"Landing Circle"'] = '"Круг падения"',
    ['"Transparency"'] = '"Прозрачность"',
    ['"Movement Graph"'] = '"График скорости"',
    ['"Graph Color"'] = '"Цвет графика"',
    ['"Width"'] = '"Ширина"',
    ['"Height"'] = '"Высота"',
    ['"Y Offset"'] = '"Смещение по Y"',

    -- Self chams
    ['"Self Chams"'] = '"Чамсы на себе"',
    ['"Tool Chams"'] = '"Чамсы оружия"',

    -- Tools
    ['"TP Tool"'] = '"ТП-тул (телепорт)"',
    ['"Fling Tool"'] = '"Тул для отброса"',
    ['"Fling Bypass Velocity"'] = '"Обход velocity при отбросе"',
    ['"Auto-Fling Murder"'] = '"Авто-отброс убийцы"',
    ['"Auto-Fling Sheriff"'] = '"Авто-отброс шерифа"',
    ['"TP to Lobby"'] = '"ТП в лобби"',
    ['"TP to Map"'] = '"ТП на карту"',

    -- Movement v2
    ['"Fly v2"'] = '"Полёт v2"',
    ['"Speed"'] = '"Скорость"',
    ['"Up"'] = '"Вверх"',
    ['"Down"'] = '"Вниз"',
    ['"Up Key"'] = '"Кнопка вверх"',
    ['"Down Key"'] = '"Кнопка вниз"',
    ['"Bhop v2"'] = '"Банихоп v2"',
    ['"Power"'] = '"Сила"',
    ['"Strafe"'] = '"Стрейф"',
    ['"Auto Strafe"'] = '"Авто-стрейф"',
    ['"Wallhop"'] = '"Отскок от стен"',
    ['"Pixel Surf"'] = '"Пиксель-сёрф"',
    ['"Surf Speed"'] = '"Скорость серфа"',

    -- Anti
    ['"Anti-Fling"'] = '"Анти-отброс"',
    ['"Anti-Void"'] = '"Анти-падение"',
    ['"Anti-Trap"'] = '"Анти-ловушка"',
    ['"Anti-Coin (remove coins)"'] = '"Удаление монет"',
    ['"Anti-Fade (no death black)"'] = '"Убрать чёрный экран смерти"',

    -- Notify
    ['"Notify"'] = '"Уведомления"',
    ['"Miss"'] = '"Промахи"',
    ['"Kill Murder"'] = '"Убил убийцу"',
    ['"Roles"'] = '"Роли"',

    -- Sounds
    ['"Sheriff Kill Sound"'] = '"Звук убийства Шерифа"',
    ['"Murder Kill Sound"'] = '"Звук убийства Маньяка"',
    ['"Sound"'] = '"Звук"',
    ['"Volume"'] = '"Громкость"',

    -- Emotes
    ['"Emote"'] = '"Эмоция"',
    ['"Stop Emote"'] = '"Остановить эмоцию"',

    -- Map Vote
    ['"Auto Vote"'] = '"Авто-голосование"',
    ['"Dupe (multi-vote)"'] = '"Мульти-голос"',
    ['"Max Dupe"'] = '"Максимум голосов"',
    ['"Priority Maps"'] = '"Приоритетные карты"',

    -- Settings
    ['"Unload All (cleanup)"'] = '"Выгрузить всё"',
}

for from, to in pairs(TRANSLATIONS) do
    body = body:gsub(from:gsub("%%", "%%%%"), to)
end

-- ============================================================
-- INJECT FLUENT API PATCH (запускается ПОСЛЕ Fluent загружен)
-- ============================================================
local FLUENT_PATCH = [[

-- ⚡ Fluent API patch v15.3
do
    if type(Fluent) == "table" and type(Fluent.CreateWindow) == "function" then
        local _origCreate = Fluent.CreateWindow
        Fluent.CreateWindow = function(self, ...)
            local win = _origCreate(self, ...)
            if type(win) == "table" then
                local _origAddTab = win.AddTab
                win.AddTab = function(w, ...)
                    local tab = _origAddTab(w, ...)
                    if tab then
                        -- AddSection: строка или таблица
                        if type(tab.AddSection) == "function" then
                            local _origAS = tab.AddSection
                            tab.AddSection = function(t, arg)
                                if type(arg) == "table" then
                                    arg = arg.Name or arg.name or "section"
                                end
                                if arg == nil then arg = "section" end
                                local sec = _origAS(t, arg)
                                -- .Option на section → сама section
                                if type(sec) == "table" and sec.Option == nil then
                                    sec.Option = sec
                                end
                                -- Патчим методы самой section
                                if type(sec) == "table" then
                                    for _, mName in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput","AddButton","AddLabel","AddParagraph"}) do
                                        local orig = sec[mName]
                                        if type(orig) == "function" then
                                            sec[mName] = function(s, a, b, ...)
                                                local r = orig(s, a, b, ...)
                                                -- .Option на toggle/slider → сам элемент
                                                if type(r) == "table" and r.Option == nil then
                                                    r.Option = r
                                                end
                                                return r
                                            end
                                        end
                                    end
                                    -- AddColorpicker alias
                                    if type(sec.AddColorpicker) == "function" and type(sec.AddColorPicker) ~= "function" then
                                        sec.AddColorPicker = sec.AddColorpicker
                                    end
                                end
                                return sec
                            end
                        end
                        -- Патчим сам tab
                        for _, mName in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput","AddButton","AddLabel","AddParagraph"}) do
                            local orig = tab[mName]
                            if type(orig) == "function" then
                                tab[mName] = function(t, a, b, ...)
                                    local r = orig(t, a, b, ...)
                                    if type(r) == "table" and r.Option == nil then
                                        r.Option = r
                                    end
                                    return r
                                end
                            end
                        end
                        if type(tab.AddColorpicker) == "function" and type(tab.AddColorPicker) ~= "function" then
                            tab.AddColorPicker = tab.AddColorpicker
                        end
                    end
                    return tab
                end
            end
            return win
        end
        print("[FH] Fluent API patch v15.3 применён")
    end
end

]]

local injected = false
body = body:gsub(
    '(logInfo%("Fluent загружен"%)%s*\n)',
    function(m) injected = true; return m .. FLUENT_PATCH end,
    1
)
if not injected then warn("[FH] Не нашёл точку инжекта Fluent patch") end

-- ============================================================
-- INJECT SILENT AIM BIND (вставляем в конец Part 1/3)
-- ============================================================
local SILENT_BIND_PATCH = [[

-- ⚡ Silent Aim Bind (кнопка E по умолчанию)
do
    _G.FH_SILENT_BIND = Enum.KeyCode.E

    task.spawn(function()
        task.wait(2)
        if Tabs and Tabs.Combat then
            pcall(function()
                local sec = Tabs.Combat:AddSection("silent_bind")
                sec:AddLabel("Нажми кнопку чтобы выстрелить в маньяка:", false)
                sec:AddKeybind("SilentAimBind", {
                    Title = "Кнопка тихого выстрела",
                    Default = "E",
                }):OnChanged(function(k)
                    local ok, kc = pcall(function() return Enum.KeyCode[k] end)
                    if ok and kc then
                        _G.FH_SILENT_BIND = kc
                        print("[FH] Bind изменён на: " .. tostring(kc))
                    end
                end)
            end)
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode ~= _G.FH_SILENT_BIND then return end
        if not (SILENT and SILENT.enabled) then
            Notify("FortniHub", "Включи Silent Aim v15.1 в Бой", 2)
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
        if not gun then
            Notify("FortniHub", "Нет пистолета в руках", 1.5)
            return
        end
        pcall(function() gun:Activate() end)
        pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
    end)

    print("[FH] Silent Aim Bind система готова (E по умолчанию)")
end

]]

-- Инжект после "PART 1/3 УСПЕШНО ЗАГРУЖЕН" — но проще после task.spawn Notify в Part 1
local injected2 = false
body = body:gsub(
    '(Notify%(L%("notify_title"%), "Part 1/3 загружено! P %- меню", 6%)%s*\nend%)',
    function(m) injected2 = true; return m .. SILENT_BIND_PATCH end,
    1
)
if not injected2 then warn("[FH] Не нашёл точку инжекта Silent Bind") end

-- ============================================================
-- INJECT AWP REPLACE (секция) в конец Part 2/3
-- ============================================================
local AWP_PATCH = [[

-- ⚡ AWP Replace (замена оружия на AWP)
do
    task.spawn(function()
        task.wait(2)
        if not Tabs or not Tabs.Visual then return end
        local sec = Tabs.Visual:AddSection("awp_replace")

        local awp_on = false
        local entries = {}

        local function clear_awp()
            for i = #entries, 1, -1 do
                pcall(function() entries[i]:Destroy() end)
                entries[i] = nil
            end
        end

        local function build_awp(handle)
            if not handle or handle:GetAttribute("FH_AWP") then return end
            handle:SetAttribute("FH_AWP", true)
            local origTrans = handle.Transparency
            handle.Transparency = 1

            local tool = handle.Parent
            if not tool then return end

            -- простая модель: длинный ствол + приклад + прицел
            local function part(name, size, color, offsetCF)
                local p = Instance.new("Part")
                p.Name = name
                p.Size = size
                p.Color = color
                p.Material = Enum.Material.Metal
                p.Anchored = true
                p.CanCollide = false
                p.CanQuery = false
                p.CanTouch = false
                p.Massless = true
                p.Parent = tool
                p.CFrame = handle.CFrame * offsetCF
                return p
            end

            local body = part("FH_AWP_Body", Vector3.new(0.12, 0.16, 1.2),
                Color3.fromRGB(50, 60, 40), CFrame.new(0, 0, -0.4))
            local barrel = part("FH_AWP_Barrel", Vector3.new(0.06, 0.06, 1.0),
                Color3.fromRGB(25, 25, 28), CFrame.new(0, 0, -1.5))
            local scope = part("FH_AWP_Scope", Vector3.new(0.06, 0.06, 0.5),
                Color3.fromRGB(25, 25, 28), CFrame.new(0, 0.15, -0.3))
            local stock = part("FH_AWP_Stock", Vector3.new(0.1, 0.14, 0.6),
                Color3.fromRGB(50, 60, 40), CFrame.new(0, 0, 0.55))

            local orig = {body, barrel, scope, stock, handle = handle, origTrans = origTrans}
            entries[#entries + 1] = body
            entries[#entries + 1] = barrel
            entries[#entries + 1] = scope
            entries[#entries + 1] = stock

            -- апдейт позиций каждый кадр
            task.spawn(function()
                while awp_on and handle.Parent do
                    if body.Parent then body.CFrame = handle.CFrame * CFrame.new(0, 0, -0.4) end
                    if barrel.Parent then barrel.CFrame = handle.CFrame * CFrame.new(0, 0, -1.5) end
                    if scope.Parent then scope.CFrame = handle.CFrame * CFrame.new(0, 0.15, -0.3) end
                    if stock.Parent then stock.CFrame = handle.CFrame * CFrame.new(0, 0, 0.55) end
                    task.wait()
                end
            end)
        end

        sec:AddToggle("AWP_Replace", {Title = "Замена оружия на AWP", Default = false}):OnChanged(function(v)
            awp_on = v
            if v then
                -- ищем Gun
                local char = LocalPlayer.Character
                local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                for _, root in ipairs({char, bp}) do
                    if root then
                        local g = root:FindFirstChild("Gun")
                        if g then
                            local h = g:FindFirstChild("Handle")
                            if h then build_awp(h) end
                        end
                    end
                end
            else
                clear_awp()
            end
        end)

        -- проверяем появление Gun каждые 0.5 сек
        task.spawn(function()
            while true do
                task.wait(0.5)
                if awp_on then
                    local char = LocalPlayer.Character
                    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                    for _, root in ipairs({char, bp}) do
                        if root then
                            local g = root:FindFirstChild("Gun")
                            if g then
                                local h = g:FindFirstChild("Handle")
                                if h and not h:GetAttribute("FH_AWP") then build_awp(h) end
                            end
                        end
                    end
                end
            end
        end)
    end)
end

]]

local injected3 = false
body = body:gsub(
    '(logInfo%("Self Chams %+ Tool Chams загружены"%)%s*\n)',
    function(m) injected3 = true; return m .. AWP_PATCH end,
    1
)
if not injected3 then warn("[FH] Не нашёл точку инжекта AWP") end

-- ============================================================
-- INJECT AUTOFARM DEBUG (в конце)
-- ============================================================
local FARM_DEBUG = [[

-- ⚡ AutoFarm Debug
do
    task.spawn(function()
        task.wait(3)
        local ok, coins = pcall(function() return CollectionService:GetTagged("CoinVisual") end)
        if ok and type(coins) == "table" then
            print("[FH] CoinVisual найден: " .. #coins .. " шт. AutoFarm v2 должен работать.")
        else
            warn("[FH] CollectionService:GetTagged('CoinVisual') не работает! Автофарм не будет находить монеты.")
            warn("[FH] Возможно в этой версии MM2 тэг называется иначе. Проверь атрибут монет в Workspace.")
        end
    end)
end

]]

body = body .. FARM_DEBUG

-- ============================================================
-- Компиляция и запуск
-- ============================================================
local fn, err = loadstring(body, "@FortniHub_v15.3")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok, err2 = pcall(fn)
if not ok then
    warn("[FH] Runtime упал: " .. tostring(err2))
else
    print("[FH] FortniHub v15.3 загружен успешно!")
end
