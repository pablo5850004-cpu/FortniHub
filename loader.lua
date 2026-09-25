-- loader.lua — FortniHub v15.4 FINAL
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua?t=" .. os.time()

print("[FH] FortniHub v15.4 запускается...")
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
-- Fluent API: AddColorPicker → AddColorpicker
-- ============================================================
body = body:gsub("AddColorPicker", "AddColorpicker")

-- ============================================================
-- AddSection({Name = X}) → AddSection(X) — простой патч БЕЗ регексп-капчи
-- ============================================================
body = body:gsub('AddSection%s*%({%s*Name%s*=%s*([^}]+)})', 'AddSection(%1)')

-- ============================================================
-- ПЕРЕВОДЫ только Title = "..." (НЕ трогаем другие строки!)
-- ============================================================
local TR = {
    ["ESP Engine v15.2"]="ESP игроков",["Box"]="Рамка",["Box Color"]="Цвет рамки",
    ["Box Alpha"]="Прозрачность",["Box Type"]="Тип рамки",["Box Gradient"]="Градиент",
    ["Box Fill"]="Заливка",["Fill Color"]="Цвет заливки",["Fill Alpha"]="Прозр. заливки",
    ["Grad 1"]="Градиент 1",["Grad 2"]="Градиент 2",["Name"]="Имя",
    ["Name Color"]="Цвет имени",["Distance"]="Дистанция",["Distance Color"]="Цвет дистанции",
    ["Avatar"]="Аватар",["Skeleton"]="Скелет",["Skeleton Color"]="Цвет скелета",
    ["Glow Chams"]="Свечение",["Material Chams"]="Материал-чамсы",["Mat Type"]="Тип материала",
    ["Murder"]="Убийца",["Inno"]="Мирный",["Sheriff"]="Шериф",
    ["Murder Fill"]="Убийца заливка",["Murder Outline"]="Убийца обводка",
    ["Inno Fill"]="Мирный заливка",["Inno Outline"]="Мирный обводка",
    ["Sheriff Fill"]="Шериф заливка",["Sheriff Outline"]="Шериф обводка",
    ["Flags (roles)"]="Метки ролей",["Off-screen Arrows"]="Стрелки к игрокам",
    ["Arrow Size"]="Размер стрелок",["Arrow Dist"]="Дистанция стрелок",
    ["Allow Local"]="Показывать себя",["Bullet Tracer"]="Трассер пули",
    ["Color"]="Цвет",["Duration"]="Длительность",["World Aura"]="Аура игрока",
    ["Type"]="Тип",["World Effects"]="Эффекты мира",["Rate"]="Интенсивность",
    ["Shaders"]="Шейдеры",["Preset"]="Пресет",["Custom Fog"]="Свой туман",
    ["Start"]="Начало",["End"]="Конец",["Custom Ambient"]="Свой ambient",
    ["Ambient Color"]="Цвет ambient",["Exposure"]="Экспозиция",["Value"]="Значение",
    ["Skybox"]="Небо",["Custom Crosshair"]="Свой прицел",["Gap"]="Зазор",
    ["Length"]="Длина",["Thickness"]="Толщина",["Rotation"]="Вращение",
    ["Outline"]="Обводка",["Murder Death Effect"]="Эффект убийцы при смерти",
    ["Clone"]="Клон",["Clone Color"]="Цвет клона",["Clone Duration"]="Длит. клона",
    ["Particle"]="Частицы",["Particle Color"]="Цвет частиц",
    ["Neverlose Emitter"]="Neverlose emitter",["Emitter Color"]="Цвет emitter",
    ["Emitter Duration"]="Длит. emitter",["China Hat"]="Китайская шляпа",
    ["Hat Color"]="Цвет шляпы",["Backtrack"]="Бэктрек",["Landing Circle"]="Круг падения",
    ["Transparency"]="Прозрачность",["Movement Graph"]="График скорости",
    ["Graph Color"]="Цвет графика",["Width"]="Ширина",["Height"]="Высота",
    ["Y Offset"]="Смещение по Y",["Self Chams"]="Чамсы на себе",
    ["Tool Chams"]="Чамсы оружия",["TP Tool"]="ТП-тул",["Fling Tool"]="Тул отброса",
    ["Fling Bypass Velocity"]="Обход velocity",["Auto-Fling Murder"]="Авто-отброс убийцы",
    ["Auto-Fling Sheriff"]="Авто-отброс шерифа",["TP to Lobby"]="ТП в лобби",
    ["TP to Map"]="ТП на карту",["Fly v2"]="Полёт v2",["Speed"]="Скорость",
    ["Up"]="Вверх",["Down"]="Вниз",["Up Key"]="Кнопка вверх",["Down Key"]="Кнопка вниз",
    ["Bhop v2"]="Банихоп v2",["Power"]="Сила",["Strafe"]="Стрейф",
    ["Auto Strafe"]="Авто-стрейф",["Wallhop"]="Отскок от стен",
    ["Pixel Surf"]="Пиксель-сёрф",["Surf Speed"]="Скорость серфа",
    ["Anti-Fling"]="Анти-отброс",["Anti-Void"]="Анти-падение",
    ["Anti-Trap"]="Анти-ловушка",["Anti-Coin (remove coins)"]="Удаление монет",
    ["Anti-Fade (no death black)"]="Убрать чёрный экран",["Notify"]="Уведомления",
    ["Miss"]="Промахи",["Kill Murder"]="Убил убийцу",["Roles"]="Роли",
    ["Sheriff Kill Sound"]="Звук убийства Шерифа",["Murder Kill Sound"]="Звук убийства Маньяка",
    ["Sound"]="Звук",["Volume"]="Громкость",["Emote"]="Эмоция",
    ["Stop Emote"]="Стоп эмоция",["Auto Vote"]="Авто-голосование",
    ["Dupe (multi-vote)"]="Мульти-голос",["Max Dupe"]="Макс. голосов",
    ["Priority Maps"]="Приоритет карт",["Unload All (cleanup)"]="Выгрузить всё",
    ["Silent Aim v15.1"]="Тихий выстрел v15.1",["Prediction"]="Предсказание",
    ["Force Shoot (wallbang)"]="Стрельба через стены",["Standoff (studs)"]="Дистанция (studs)",
    ["Auto Shoot"]="Авто-выстрел",["Auto Delay (ms)"]="Задержка (ms)",
    ["Kill Aura"]="Килл Аура",["Radius"]="Радиус",["Auto Grab Gun"]="Авто-подбор пистолета",
    ["Speed Hack"]="Скорость",["Walk Speed"]="Скорость ходьбы",["Fly"]="Полёт",
    ["Fly Speed"]="Скорость полёта",["Speed Glitch"]="Спидглитч",
    ["Glitch Speed"]="Скорость глитча",["Bunny Hop"]="Банихоп",
    ["Max Speed"]="Макс. скорость",["Accel Time"]="Разгон",["Noclip"]="Noclip",
    ["Spinbot"]="Спинбот",["Spin Speed"]="Скорость вращения",
    ["Infinite Jump"]="Беск. прыжок",["Jump Power"]="Сила прыжка",
    ["Custom Jump Power"]="Своя сила прыжка",["Wall Bounce"]="Отскок от стен",
    ["Wall Force"]="Сила отскока",["Freeze"]="Заморозка",["Freeze Speed"]="Скор. заморозки",
    ["AutoFarm v2 (legit)"]="Автофарм v2",["Farm Speed"]="Скорость фарма",
    ["Avoid Murderer"]="Избегать маньяка",["Auto Kill at 40"]="Авто-килл при 40",
    ["Player ESP"]="ESP игроков",["Name ESP"]="ESP имён",
    ["Distance ESP"]="ESP дистанции",["Gun ESP"]="ESP пистолета",
    ["Coin ESP"]="ESP монет",["Fullbright"]="Полная яркость",
    ["FOV"]="Угол обзора",["FPS Cap"]="Лимит FPS",["Spam Message"]="Текст спама",
    ["Spam Chat"]="Спам в чат",["Troll Egor"]="Супер-медленный",
    ["Troll Lag"]="Фейк-лаги",["TP Lobby"]="ТП в лобби",["TP Map"]="ТП на карту",
    ["TP Murderer"]="ТП к убийце",["TP Sheriff"]="ТП к шерифу",
    ["Vote Boost"]="Буст голосования",["Invisible"]="Невидимость",
    ["Anti AFK"]="Анти-AFK",["Rejoin"]="Переподключиться",
    ["Server Hop"]="Сменить сервер",["Select Modules"]="Выбрать модули",
    ["Freeze Buttons"]="Заморозить кнопки",["Show Shoot Button"]="Кнопка выстрела",
    ["Clear All"]="Очистить всё",["Module"]="Модуль",["Set Bind"]="Поставить бинд",
    ["Clear Binds"]="Очистить бинды",["Notify Toggles"]="Уведомления",
    ["Show HUD"]="Показывать HUD",["Coord Mode"]="Координаты",
    ["Unload Script"]="Выгрузить скрипт",["Kill Sheriff"]="Убить Шерифа",
    ["Suicide"]="Умереть",["AutoFarm v2"]="Автофарм v2",["Type"]="Тип",
    ["AWP Replace"]="Замена на AWP",["Silent Bind"]="Тихий выстрел (биндим клавишей)",
    ["Silent Bind (клавиша)"]="Кнопка тихого выстрела",
}

body = body:gsub('Title%s*=%s*"([^"]*)"', function(s)
    return 'Title = "' .. (TR[s] or s) .. '"'
end)

-- ============================================================
-- FLUENT API PATCH (monkey-patch, не трогает исходник)
-- ============================================================
local PATCH = [[

do
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
                    -- .Option = self для всех Add*
                    for _, name in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput","AddButton","AddLabel","AddKeybind","AddColorpicker"}) do
                        local orig = container[name]
                        if type(orig) == "function" and not container["__hk_" .. name] then
                            container["__hk_" .. name] = true
                            container[name] = function(c, ...)
                                local r = orig(c, ...)
                                if type(r) == "table" and r.Option == nil then r.Option = r end
                                return r
                            end
                        end
                    end
                    -- AddSection
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
        print("[FH] Fluent API patch v15.4 применён")
    end
end

]]

local injected = false
body = body:gsub('(logInfo%("Fluent загружен"%)%s*\n)', function(m)
    injected = true
    return m .. PATCH
end, 1)

if not injected then warn("[FH] Не нашёл точку инжекта Fluent patch") end

-- ============================================================
-- Compile + Run
-- ============================================================
local fn, err = loadstring(body, "@FortniHub_v15.4")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok, err2 = pcall(fn)
if not ok then
    warn("[FH] Runtime упал: " .. tostring(err2))
else
    print("[FH] FortniHub v15.4 загружен успешно!")
end
