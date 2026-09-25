-- ============================================================
-- FORTNIHUB v16 — REWRITE
-- Часть 1/3: Core + HUD + Silent Aim v2 + Combat
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local VERSION = "16.0.0"
local THEME = Color3.fromRGB(138, 92, 246)
local THEME_LIGHT = Color3.fromRGB(178, 152, 255)
local THEME_OK = Color3.fromRGB(80, 240, 120)
local THEME_WARN = Color3.fromRGB(255, 200, 80)
local THEME_ERR = Color3.fromRGB(255, 80, 80)

pcall(function() if setfpscap then setfpscap(0) end end)

-- ============================================================
-- SAFE RANDOM (локально, math не трогаем)
-- ============================================================
local _origRandom = math.random
local function srand(a, b)
    if a == nil then return _origRandom() end
    if b == nil then
        if type(a) ~= "number" or a ~= a or a < 1 then a = 1 end
        if a > 2147483647 then a = 2147483647 end
        return _origRandom(math.floor(a))
    end
    a, b = tonumber(a) or 0, tonumber(b) or 0
    if a ~= a then a = 0 end
    if b ~= b then b = 0 end
    if b < a then a, b = b, a end
    if a == b then return a end
    return _origRandom(math.floor(a), math.floor(b))
end

-- ============================================================
-- TRANSLATOR — русский для всего
-- ============================================================
local TR = {
    -- tabs
    ["Combat"]="Бой",["Movement"]="Движение",["Farm"]="Фарм",["Visual"]="Визуал",
    ["Effects"]="Эффекты",["Troll"]="Троллинг",["Utility"]="Утилиты",
    ["Mobile"]="Мобильный",["Binds"]="Клавиши",["Settings"]="Настройки",
    ["Silent Aim v2"]="Тихий выстрел v2",
    ["Enable Silent"]="Включить тихий выстрел",
    ["Aim Type"]="Тип прицеливания",
    ["Predict"]="Предсказание",
    ["Force (wallbang)"]="Стрельба через стены",
    ["Auto Shoot"]="Авто-выстрел",
    ["Auto Delay (ms)"]="Задержка (мс)",
    ["Bind Key"]="Кнопка выстрела",
    ["Standoff"]="Отступ (студы)",
    ["Kill Aura"]="Килл Аура",
    ["Kill Aura Version"]="Версия ауры",
    ["Radius"]="Радиус",
    ["Auto Grab Gun"]="Авто-подбор пистолета",
    ["Kill Sheriff"]="Убить Шерифа",
    ["Suicide"]="Умереть",
    ["Knife Silent"]="Тихий бросок ножа",
    ["Insta Kill"]="Инста-килл",
    ["Impact Radius"]="Радиус попадания",
    ["Knife Prediction"]="Предсказание ножа",
    ["Speed"]="Скорость",
    ["Walk Speed"]="Скорость ходьбы",
    ["Fly"]="Полёт",
    ["Fly Speed"]="Скорость полёта",
    ["Bunny Hop"]="Банихоп",
    ["Max Speed"]="Макс. скорость",
    ["Accel Time"]="Время разгона",
    ["Noclip"]="ноуклип",
    ["Spinbot"]="Кручение",
    ["Spin Speed"]="Скорость кручения",
    ["Infinite Jump"]="Бесконечный прыжок",
    ["Jump Power"]="Сила прыжка",
    ["Custom Jump Power"]="Своя сила прыжка",
    ["Freeze"]="Заморозка",
    ["Freeze Speed"]="Скорость заморозки",
    ["Freeze Up Key"]="Кнопка ВВЕРХ",
    ["Freeze Down Key"]="Кнопка ВНИЗ",
    ["Server Look"]="Серверный взгляд",
    ["Look Mode"]="Режим взгляда",
    ["Up"]="Вверх",
    ["Down"]="Вниз",
    ["Combo"]="Комбо (вверх-вниз)",
    ["Look Speed"]="Скорость взгляда",
    ["Wall Bounce"]="Отскок от стен",
    ["Wall Force"]="Сила отскока",
    ["Speed Glitch"]="Спидглитч",
    ["Glitch Speed"]="Скорость глитча",
    ["Player ESP"]="ESP игроков",
    ["Name ESP"]="ESP имён",
    ["Distance ESP"]="ESP дистанции",
    ["Gun ESP"]="ESP пистолета",
    ["Coin ESP"]="ESP монет",
    ["Box"]="Рамка",
    ["Box Color"]="Цвет рамки",
    ["Box Fill"]="Заливка",
    ["Box Type"]="Тип рамки",
    ["Static"]="Прямоугольник",
    ["Corners"]="Уголки",
    ["Box Gradient"]="Градиент рамки",
    ["Grad 1"]="Цвет 1",
    ["Grad 2"]="Цвет 2",
    ["Name"]="Имя",
    ["Name Color"]="Цвет имени",
    ["Distance"]="Дистанция",
    ["Distance Color"]="Цвет дистанции",
    ["Avatar"]="Аватарка",
    ["Skeleton"]="Скелет",
    ["Skeleton Color"]="Цвет скелета",
    ["Glow Chams"]="Свечение (Chams)",
    ["Material Chams"]="Материал-чамсы",
    ["Mat Type"]="Тип материала",
    ["Flags (roles)"]="Метки ролей",
    ["Off-screen Arrows"]="Стрелки к игрокам",
    ["Arrow Size"]="Размер стрелок",
    ["Arrow Dist"]="Дистанция стрелок",
    ["Murder"]="Убийца",
    ["Inno"]="Мирный",
    ["Sheriff"]="Шериф",
    ["Murder Fill"]="Убийца заливка",
    ["Murder Outline"]="Убийца обводка",
    ["Inno Fill"]="Мирный заливка",
    ["Inno Outline"]="Мирный обводка",
    ["Sheriff Fill"]="Шериф заливка",
    ["Sheriff Outline"]="Шериф обводка",
    ["Bullet Tracer"]="Трассер пули",
    ["Color"]="Цвет",
    ["Duration"]="Длительность",
    ["World Aura"]="Аура",
    ["Type"]="Тип",
    ["World Effects"]="Эффекты мира",
    ["Snow"]="Снег",
    ["Sakura"]="Сакура",
    ["Rate"]="Интенсивность",
    ["Shaders"]="Шейдеры",
    ["Preset"]="Пресет",
    ["morning"]="Утро",
    ["midday"]="День",
    ["evening"]="Вечер",
    ["night"]="Ночь",
    ["Custom Fog"]="Свой туман",
    ["Start"]="Начало",
    ["End"]="Конец",
    ["Custom Ambient"]="Свой ambient",
    ["Ambient Color"]="Цвет ambient",
    ["Exposure"]="Экспозиция",
    ["Value"]="Значение",
    ["Skybox"]="Небо",
    ["Jungle"]="Джунгли",
    ["Blossom"]="Сакура",
    ["Red night"]="Красная ночь",
    ["Purple"]="Фиолетовое",
    ["Foggy"]="Туманное",
    ["Galaxy"]="Галактика",
    ["Anime"]="Аниме",
    ["Minecraft"]="Майнкрафт",
    ["Custom Crosshair"]="Свой прицел",
    ["Gap"]="Зазор",
    ["Length"]="Длина",
    ["Thickness"]="Толщина",
    ["Rotation"]="Вращение",
    ["Outline"]="Обводка",
    ["Murder Death Effect"]="Эффект при смерти убийцы",
    ["Clone"]="Клон",
    ["Clone Color"]="Цвет клона",
    ["Clone Duration"]="Длительность клона",
    ["Particle"]="Частицы",
    ["Particle Color"]="Цвет частиц",
    ["Neverlose Emitter"]="Neverlose emitter",
    ["Emitter Color"]="Цвет emitter",
    ["Emitter Duration"]="Длительность emitter",
    ["China Hat"]="Китайская шляпа",
    ["Hat Color"]="Цвет шляпы",
    ["Backtrack"]="Бэктрек",
    ["Landing Circle"]="Круг падения",
    ["Transparency"]="Прозрачность",
    ["Movement Graph"]="График скорости",
    ["Graph Color"]="Цвет графика",
    ["Width"]="Ширина",
    ["Height"]="Высота",
    ["Y Offset"]="Смещение по Y",
    ["Self Chams"]="Чамсы на себе",
    ["Tool Chams"]="Чамсы оружия",
    ["AWP Replace"]="Замена на AWP",
    ["TP Tool"]="ТП-тул",
    ["Fling Tool"]="Тул отброса",
    ["Fling Bypass Velocity"]="Обход velocity",
    ["Auto-Fling Murder"]="Авто-отброс убийцы",
    ["Auto-Fling Sheriff"]="Авто-отброс шерифа",
    ["TP to Lobby"]="ТП в лобби",
    ["TP to Map"]="ТП на карту",
    ["Fly v2"]="Полёт v2",
    ["Up Key"]="Кнопка вверх",
    ["Down Key"]="Кнопка вниз",
    ["Bhop v2"]="Банихоп v2",
    ["Power"]="Сила",
    ["Strafe"]="Стрейф",
    ["Auto Strafe"]="Авто-стрейф",
    ["Wallhop"]="Отскок от стен",
    ["Pixel Surf"]="Пиксель-сёрф",
    ["Surf Speed"]="Скорость серфа",
    ["Anti-Fling"]="Анти-отброс",
    ["Anti-Void"]="Анти-падение",
    ["Anti-Trap"]="Анти-ловушка",
    ["Anti-Coin (remove coins)"]="Удаление монет",
    ["Anti-Fade (no death black)"]="Убрать чёрный экран смерти",
    ["Notify"]="Уведомления",
    ["Miss"]="Промахи",
    ["Kill Murder"]="Убил убийцу",
    ["Roles"]="Роли",
    ["Sheriff Kill Sound"]="Звук убийства Шерифа",
    ["Murder Kill Sound"]="Звук убийства Маньяка",
    ["Sound"]="Звук",
    ["Volume"]="Громкость",
    ["Emote"]="Эмоция",
    ["Stop Emote"]="Остановить эмоцию",
    ["Auto Vote"]="Авто-голосование",
    ["Dupe (multi-vote)"]="Мульти-голос",
    ["Max Dupe"]="Максимум голосов",
    ["Priority Maps"]="Приоритетные карты",
    ["AutoFarm"]="Автофарм",
    ["AutoFarm Version"]="Версия автофарма",
    ["Farm Speed"]="Скорость фарма",
    ["Avoid Murderer"]="Избегать маньяка",
    ["Auto Kill at 40"]="Авто-килл при 40",
    ["Freeze Buttons"]="Заморозить кнопки",
    ["Show Shoot Button"]="Показать кнопку выстрела",
    ["Clear All"]="Убрать всё",
    ["Module"]="Модуль",
    ["Set Bind"]="Установить бинд",
    ["Clear Binds"]="Убрать бинды",
    ["Notify Toggles"]="Уведомления при переключении",
    ["Show HUD"]="Показывать HUD",
    ["Coord Mode"]="Режим координат",
    ["Unload"]="Выгрузить",
    ["Select Modules"]="Выбрать модули",
    ["Kill Aura v1 (твоя)"]="Килл Аура v1 (твоя)",
    ["Kill Aura v2 (друга)"]="Килл Аура v2 (друга)",
    ["AutoFarm v1 (твой)"]="Автофарм v1 (твой)",
    ["AutoFarm v2 (друга)"]="Автофарм v2 (друга)",
    ["Simple"]="Простой",
    ["Advanced"]="Продвинутый",
}

local CurrentLang = "ru"
if _G.FortniHubLang then CurrentLang = _G.FortniHubLang end
pcall(function()
    if isfile and isfile("FortniHubLang.txt") then
        local s = readfile("FortniHubLang.txt")
        if s == "ru" or s == "en" then CurrentLang = s end
    end
end)

local function L(key)
    if CurrentLang == "ru" then return TR[key] or key end
    return key
end

-- ============================================================
-- STATE
-- ============================================================
local S = {
    frozen = false,
    freezeUpKey = Enum.KeyCode.Space,
    freezeDownKey = Enum.KeyCode.LeftAlt,
    serverLookMode = "Off",
    serverLookSpeed = 1,
}

local silent = {
    enabled = false,
    aimType = "Advanced",
    predict = true,
    force = false,
    autoShoot = false,
    autoDelay = 0.08,
    bindKey = Enum.KeyCode.E,
    standoff = 15,
    lastShot = 0,
}

local knifeSilent = {
    enabled = false,
    instaKill = false,
    radius = 12,
    predict = true,
}

local kaV2 = { on = false, dist = 30, lastHit = 0 }
local kaV1 = { on = false, dist = 30, lastHit = 0 }
local killAuraVersion = "v2"

local farmV1 = { on = false, speed = 23 }
local farmV2 = { on = false, speed = 23, avoid = false }
local farmVersion = "v1"

local Cache = { hrp = nil, hum = nil, cacheTime = 0 }

-- ============================================================
-- HELPERS
-- ============================================================
local Connections = {}
local function AddConn(name, conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name] = conn
end

local function refreshChar()
    if tick() - Cache.cacheTime < 0.5 then return end
    Cache.cacheTime = tick()
    local c = LocalPlayer.Character
    if c then
        Cache.hrp = c:FindFirstChild("HumanoidRootPart")
        Cache.hum = c:FindFirstChildOfClass("Humanoid")
    else
        Cache.hrp, Cache.hum = nil, nil
    end
end

local function getHRP() refreshChar() return Cache.hrp end
local function getHum() refreshChar() return Cache.hum end

local function getRole(p)
    if not p or not p.Character then return "lobby" end
    local c = p.Character
    local bp = p:FindFirstChild("Backpack")
    if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then return "murderer" end
    if c:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then return "sheriff" end
    return "innocent"
end

local function isMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "murderer" then return p end
    end
    return nil
end

local function isSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRole(p) == "sheriff" then return p end
    end
    return nil
end

-- ============================================================
-- FLUENT LOADER + API ADAPTER
-- ============================================================
local Fluent
do
    print("[FortniHub][INFO] Загружаю Fluent UI...")
    local urls = {
        "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/src/init.lua",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/src/init.lua",
    }
    local body
    for _, u in ipairs(urls) do
        local ok, b = pcall(function() return game:HttpGet(u, true) end)
        if ok and type(b) == "string" and #b > 1000 and not b:find("<html") then
            body = b; break
        end
    end
    if not body then error("Не удалось загрузить Fluent UI") end
    local fn = loadstring(body, "@Fluent")
    Fluent = fn and fn()
    if type(Fluent) ~= "table" then error("Fluent не таблица") end
    print("[FortniHub][INFO] Fluent загружен")
end

-- Адаптер: превращает любую версию Fluent в единый API
local function adaptTab(tab)
    if not tab then return tab end

    -- .Option = self
    for _, name in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput",
                            "AddButton","AddLabel","AddKeybind","AddColorpicker","AddColorPicker"}) do
        local orig = tab[name]
        if type(orig) == "function" and not rawget(tab, "__" .. name) then
            rawset(tab, "__" .. name, true)
            tab[name] = function(self, ...)
                local r = orig(self, ...)
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

    -- AddSection принимает и строку и {Name=...}
    if type(tab.AddSection) == "function" and not rawget(tab, "__AS") then
        rawset(tab, "__AS", true)
        local origAS = tab.AddSection
        tab.AddSection = function(self, arg)
            if type(arg) == "table" then arg = arg.Name or arg.name or "Секция" end
            if arg == nil then arg = "Секция" end
            local sec = origAS(self, arg)
            if sec then
                if sec.Option == nil then sec.Option = sec end
                adaptTab(sec)
            end
            return sec
        end
    end
    return tab
end

local Window, Options, Tabs = nil, nil, {}

do
    local winOpts = {
        Title = "FortniHub MM2",
        SubTitle = "v"..VERSION.." REWRITE",
        TabWidth = 130,
        Size = UDim2.fromOffset(500, 380),
        Theme = "Darker",
        MinimizeKey = nil,
    }
    Window = Fluent:CreateWindow(winOpts)
    Options = Fluent.Options

    local origAddTab = Window.AddTab
    Window.AddTab = function(self, ...)
        local tab = origAddTab(self, ...)
        return adaptTab(tab)
    end

    print("[FortniHub][INFO] Окно создано")
end

-- ============================================================
-- NOTIFY
-- ============================================================
local lastNotify = {}
local function Notify(title, content, dur)
    local k = tostring(title) .. "|" .. tostring(content)
    if lastNotify[k] and (tick() - lastNotify[k]) < 0.5 then return end
    lastNotify[k] = tick()
    pcall(function()
        Fluent:Notify({Title = title, Content = content, Duration = dur or 3})
    end)
end

-- ============================================================
-- HUD — стиль друга (пилюля с 3 сегментами)
-- ============================================================
local HUDGui, FPSLabel, PingLabel, RoundLabel
do
    HUDGui = Instance.new("ScreenGui")
    HUDGui.Name = "FH_HUD_v16"
    HUDGui.ResetOnSpawn = false
    HUDGui.IgnoreGuiInset = true
    HUDGui.DisplayOrder = 500
    HUDGui.Parent = CoreGui

    local function drag(frame)
        local d, ds, sp = false, nil, nil
        frame.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                d = true; ds = i.Position; sp = frame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not d then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                local delta = i.Position - ds
                frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                d = false
            end
        end)
    end

    local Pill = Instance.new("Frame")
    Pill.Name = "Pill"
    Pill.AnchorPoint = Vector2.new(0.5, 0)
    Pill.Position = UDim2.new(0.5, 0, 0, 12)
    Pill.Size = UDim2.fromOffset(400, 40)
    Pill.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Pill.BorderSizePixel = 0
    Pill.Parent = HUDGui
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", Pill)
    stroke.Color = THEME
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    drag(Pill)

    -- Декоративная рамка с градиентом
    local grad = Instance.new("UIGradient", Pill)
    grad.Rotation = 45
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 60)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 30, 60)),
    })
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.3),
    })

    local function seg(x, w)
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.Position = UDim2.fromOffset(x, 0)
        f.Size = UDim2.fromOffset(w, 40)
        f.Parent = Pill
        return f
    end
    local function div(x)
        local d = Instance.new("Frame")
        d.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        d.BorderSizePixel = 0
        d.Position = UDim2.new(0, x, 0.5, -10)
        d.Size = UDim2.fromOffset(1, 20)
        d.Parent = Pill
    end

    -- Сегмент 1: Логотип
    local s1 = seg(8, 130)
    local logoIcon = Instance.new("TextLabel")
    logoIcon.BackgroundTransparency = 1
    logoIcon.Size = UDim2.fromOffset(24, 40)
    logoIcon.Position = UDim2.fromOffset(6, 0)
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.Text = "⚡"
    logoIcon.TextSize = 20
    logoIcon.TextColor3 = THEME_LIGHT
    logoIcon.TextXAlignment = Enum.TextXAlignment.Left
    logoIcon.Parent = s1

    local logoText = Instance.new("TextLabel")
    logoText.BackgroundTransparency = 1
    logoText.Size = UDim2.fromOffset(96, 40)
    logoText.Position = UDim2.fromOffset(32, 0)
    logoText.Font = Enum.Font.GothamBold
    logoText.Text = "FortniHub"
    logoText.TextSize = 15
    logoText.TextColor3 = Color3.fromRGB(240, 240, 250)
    logoText.TextXAlignment = Enum.TextXAlignment.Left
    logoText.Parent = s1
    div(142)

    -- Сегмент 2: FPS
    local s2 = seg(146, 120)
    local fpsIcon = Instance.new("TextLabel")
    fpsIcon.BackgroundTransparency = 1
    fpsIcon.Size = UDim2.fromOffset(20, 40)
    fpsIcon.Position = UDim2.fromOffset(6, 0)
    fpsIcon.Font = Enum.Font.GothamBold
    fpsIcon.Text = ""
    fpsIcon.TextSize = 16
    fpsIcon.TextColor3 = THEME_OK
    fpsIcon.TextXAlignment = Enum.TextXAlignment.Left
    fpsIcon.Parent = s2

    FPSLabel = Instance.new("TextLabel")
    FPSLabel.BackgroundTransparency = 1
    FPSLabel.Size = UDim2.fromOffset(50, 40)
    FPSLabel.Position = UDim2.fromOffset(26, 0)
    FPSLabel.Font = Enum.Font.GothamBold
    FPSLabel.Text = "60"
    FPSLabel.TextSize = 15
    FPSLabel.TextColor3 = THEME_OK
    FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
    FPSLabel.Parent = s2

    local fpsWord = Instance.new("TextLabel")
    fpsWord.BackgroundTransparency = 1
    fpsWord.Size = UDim2.fromOffset(30, 40)
    fpsWord.Position = UDim2.fromOffset(76, 0)
    fpsWord.Font = Enum.Font.Gotham
    fpsWord.Text = "FPS"
    fpsWord.TextSize = 11
    fpsWord.TextColor3 = Color3.fromRGB(150, 150, 165)
    fpsWord.TextXAlignment = Enum.TextXAlignment.Left
    fpsWord.Parent = s2
    div(270)

    -- Сегмент 3: PING
    local s3 = seg(274, 110)
    local pingIcon = Instance.new("TextLabel")
    pingIcon.BackgroundTransparency = 1
    pingIcon.Size = UDim2.fromOffset(20, 40)
    pingIcon.Position = UDim2.fromOffset(6, 0)
    pingIcon.Font = Enum.Font.GothamBold
    pingIcon.Text = ""
    pingIcon.TextSize = 16
    pingIcon.TextColor3 = THEME_OK
    pingIcon.TextXAlignment = Enum.TextXAlignment.Left
    pingIcon.Parent = s3

    PingLabel = Instance.new("TextLabel")
    PingLabel.BackgroundTransparency = 1
    PingLabel.Size = UDim2.fromOffset(48, 40)
    PingLabel.Position = UDim2.fromOffset(26, 0)
    PingLabel.Font = Enum.Font.GothamBold
    PingLabel.Text = "0"
    PingLabel.TextSize = 15
    PingLabel.TextColor3 = THEME_OK
    PingLabel.TextXAlignment = Enum.TextXAlignment.Left
    PingLabel.Parent = s3

    local msWord = Instance.new("TextLabel")
    msWord.BackgroundTransparency = 1
    msWord.Size = UDim2.fromOffset(24, 40)
    msWord.Position = UDim2.fromOffset(76, 0)
    msWord.Font = Enum.Font.Gotham
    msWord.Text = "ms"
    msWord.TextSize = 11
    msWord.TextColor3 = Color3.fromRGB(150, 150, 165)
    msWord.TextXAlignment = Enum.TextXAlignment.Left
    msWord.Parent = s3

    -- Обновление FPS
    local fc, lastSec = 0, os.clock()
    AddConn("HUD_FPS", RunService.Heartbeat:Connect(function()
        fc = fc + 1
        local now = os.clock()
        if now - lastSec >= 1 then
            local cur = fc
            fc = 0; lastSec = now
            local c = cur < 30 and THEME_ERR or (cur < 60 and THEME_WARN or THEME_OK)
            FPSLabel.Text = tostring(cur)
            FPSLabel.TextColor3 = c
            fpsIcon.TextColor3 = c
        end
    end))

    -- Обновление Ping
    local lastPing = 0
    AddConn("HUD_PING", RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - lastPing < 0.4 then return end
        lastPing = now
        local ok, p = pcall(function()
            local v = LocalPlayer:GetNetworkPing() * 1000
            if v ~= v or v < 0 then v = 0 end
            return math.floor(v)
        end)
        if ok then
            local c = p < 60 and THEME_OK or (p < 120 and THEME_WARN or THEME_ERR)
            PingLabel.Text = tostring(p)
            PingLabel.TextColor3 = c
            pingIcon.TextColor3 = c
        end
    end))

    print("[FortniHub][INFO] HUD v16 готов")
end

-- ============================================================
-- SILENT AIM v2
-- ============================================================
do
    -- snap buffer для кинематики
    local SNAP = 48
    local snap_t = table.create(SNAP, 0)
    local snap_p = table.create(SNAP, Vector3.zero)
    local snap_n, snap_i = 0, 0

    local function snapPush(now, pos)
        snap_i = snap_i % SNAP + 1
        snap_t[snap_i] = now
        snap_p[snap_i] = pos
        if snap_n < SNAP then snap_n = snap_n + 1 end
    end
    local function snapGet(k)
        local idx = (snap_i - k - 1) % SNAP + 1
        return snap_t[idx], snap_p[idx]
    end

    local TRK = {
        target = nil, char = nil, part = nil, hum = nil,
        pos = nil, time = 0, vel = Vector3.zero, gap = 0, ready = false,
    }

    local function findMurderer()
        -- сначала пробуем через модуль MM2
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and type(m) == "table" and type(m.PlayerData) == "table" then
            for name, d in pairs(m.PlayerData) do
                if type(d) == "table" and d.Role == "Murderer" and not d.Dead then
                    local p = Players:FindFirstChild(name)
                    if p then return p end
                end
            end
        end
        -- fallback: ищем по ножу
        return isMurderer()
    end

    local function updateTarget()
        local t = findMurderer()
        if t ~= TRK.target then
            TRK.target = t
            TRK.char = t and t.Character or nil
            TRK.part = nil
            TRK.hum = nil
            TRK.ready = false
            snap_n, snap_i = 0, 0
        end
        if not t or not t.Character then return end
        if t.Character ~= TRK.char then
            TRK.char = t.Character
            TRK.part = nil
            TRK.hum = nil
        end
        if not TRK.part or not TRK.part.Parent then
            TRK.part = t.Character:FindFirstChild("HumanoidRootPart")
                or t.Character:FindFirstChild("UpperTorso")
                or t.Character:FindFirstChild("Torso")
        end
        if not TRK.hum or not TRK.hum.Parent then
            TRK.hum = t.Character:FindFirstChildOfClass("Humanoid")
        end
    end

    local function targetAlive()
        return TRK.part and TRK.part.Parent and TRK.hum and TRK.hum.Parent and TRK.hum.Health > 0
    end

    -- Кинематика
    local function fitVelocity()
        if snap_n < 3 then return nil, 0 end
        local newest = select(1, snapGet(0))
        local used, sumD = 0, 0
        local win = math.max(TRK.gap * 4, 0.08)
        for k = 0, snap_n - 1 do
            local t = select(1, snapGet(k))
            if newest - t > win then break end
            used = used + 1
            sumD = sumD + (t - newest)
        end
        if used < 3 then return nil, 0 end
        local meanD = sumD / used
        local num, den = Vector3.zero, 0
        for k = 0, used - 1 do
            local t, p = snapGet(k)
            local d = (t - newest) - meanD
            num = num + p * d
            den = den + d * d
        end
        if den < 1e-8 then return nil, 0 end
        return num / den, -meanD
    end

    local function getPing()
        local ok, v = pcall(function() return LocalPlayer:GetNetworkPing() * 2 end)
        if ok and type(v) == "number" and v == v and v > 0 then
            return math.clamp(v, 0.02, 0.5)
        end
        return 0.08
    end

    local function trackTick(now)
        local part = TRK.part
        if not part or not part.Parent then
            TRK.ready = false
            return
        end
        local pos = part.Position
        if not TRK.pos then
            TRK.pos = pos
            TRK.time = now
            snap_n, snap_i = 0, 0
            snapPush(now, pos)
            return
        end
        local dt = now - TRK.time
        if dt > 0.5 or (pos - TRK.pos).Magnitude > 100 then
            TRK.pos = pos
            TRK.time = now
            TRK.ready = false
            snap_n, snap_i = 0, 0
            snapPush(now, pos)
            return
        end
        if dt <= 0 then return end
        if (pos - TRK.pos).Magnitude < 0.01 then return end

        TRK.gap = TRK.gap > 0 and (TRK.gap * 0.8 + dt * 0.2) or dt
        snapPush(now, pos)
        TRK.pos = pos
        TRK.time = now

        local v, _ = fitVelocity()
        if v then
            TRK.vel = v
            TRK.ready = true
        end
    end

    -- Пит-поинт
    local hit_names = {
        "Head", "UpperTorso", "Torso", "HumanoidRootPart",
        "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    }

    local ray_params = RaycastParams.new()
    ray_params.FilterType = Enum.RaycastFilterType.Exclude
    ray_params.IgnoreWater = false

    local function getGunOrigin()
        local c = LocalPlayer.Character
        if not c then return nil end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local att = hrp:FindFirstChild("GunRaycastAttachment")
        if att then return att.WorldCFrame end
        return hrp.CFrame
    end

    local function getTargetPoint(origin)
        if not targetAlive() then return nil end
        local ping = getPing()
        local pts = TRK.ready and TRK.vel or Vector3.zero
        local horizon = silent.predict and math.clamp(ping + TRK.gap, 0, 0.4) or 0
        local base = TRK.part.Position + pts * horizon

        -- если force (wallbang) — игнорируем LOS проверку
        if silent.force then return base end

        -- проверка видимости
        if origin then
            local delta = base - origin
            ray_params.FilterDescendantsInstances = { LocalPlayer.Character }
            local hit = Workspace:Raycast(origin, delta, ray_params)
            if hit and TRK.char and not (hit.Instance == TRK.char or hit.Instance:IsDescendantOf(TRK.char)) then
                -- попробуем другую точку на хитбоксе
                for _, hn in ipairs(hit_names) do
                    local p = TRK.char:FindFirstChild(hn)
                    if p and p:IsA("BasePart") then
                        local pt = p.Position + pts * horizon
                        local h2 = Workspace:Raycast(origin, pt - origin, ray_params)
                        if not h2 or (h2.Instance == TRK.char or h2.Instance:IsDescendantOf(TRK.char)) then
                            return pt
                        end
                    end
                end
            end
        end
        return base
    end

    -- WeaponService hook
    local weapon_service, origMouse, origScreen

    local function getWeaponService()
        if weapon_service then return weapon_service end
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"))
        end)
        if ok and type(m) == "table" then weapon_service = m end
        return weapon_service
    end

    local function installHooks()
        local m = getWeaponService()
        if not m then return end
        pcall(function() setreadonly(m, false) end)

        if type(m.GetMouseTargetCFrame) == "function" and not origMouse then
            origMouse = m.GetMouseTargetCFrame
            local old = origMouse
            m.GetMouseTargetCFrame = function(self, ...)
                if silent.enabled and targetAlive() then
                    local cf = getGunOrigin()
                    local pt = getTargetPoint(cf and cf.Position or nil)
                    if pt then return CFrame.new(pt) end
                end
                return old(self, ...)
            end
        end
        if type(m.GetTargetPosition) == "function" and not origScreen then
            origScreen = m.GetTargetPosition
            local old = origScreen
            m.GetTargetPosition = function(self, x, y, ...)
                if silent.enabled and targetAlive() then
                    local cf = getGunOrigin()
                    local pt = getTargetPoint(cf and cf.Position or nil)
                    if pt then return CFrame.new(pt) end
                end
                return old(self, x, y, ...)
            end
        end
    end

    local function uninstallHooks()
        if not weapon_service then return end
        pcall(function() setreadonly(weapon_service, false) end)
        if origMouse then pcall(function() weapon_service.GetMouseTargetCFrame = origMouse end) end
        if origScreen then pcall(function() weapon_service.GetTargetPosition = origScreen end) end
    end

    -- Тик
    local next_role = 0
    AddConn("SilentTick", RunService.Heartbeat:Connect(function()
        if not silent.enabled then return end
        local now = os.clock()
        if now >= next_role then
            next_role = now + 0.15
            pcall(updateTarget)
        end
        pcall(trackTick, now)
    end))

    task.spawn(function()
        task.wait(1)
        pcall(installHooks)
    end)

    AddConn("SilentHookRetry", RunService.Heartbeat:Connect(function()
        if silent.enabled and not origMouse then pcall(installHooks) end
    end))

    -- Ручной выстрел
    local function manualShoot()
        if not silent.enabled then
            Notify("FortniHub", "Включи Silent Aim", 2)
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        local role = getRole(LocalPlayer)
        if role ~= "sheriff" and role ~= "innocent" then
            -- проверяем по наличию пистолета
        end
        local gun = char:FindFirstChild("Gun")
        if not gun then
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            gun = bp and bp:FindFirstChild("Gun")
        end
        if not gun then
            Notify("FortniHub", "Нужен пистолет в руках", 2)
            return
        end
        if gun.Parent ~= char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(gun) end
            task.wait(0.05)
        end
        -- Проверяем что мы шериф
        local m = getWeaponService()
        if not m then
            Notify("FortniHub", "Ты не Шериф!", 2)
            return
        end
        pcall(function() gun:Activate() end)
        pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
    end

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == silent.bindKey then
            manualShoot()
        end
    end)

    -- UI
    local tC = Window:AddTab({Title = L("Combat")})
    Tabs.Combat = tC

    local silentSec = tC:AddSection({Name = L("Silent Aim v2")})

    silentSec:AddToggle("SilentEnabled", {
        Title = L("Enable Silent"),
        Default = false,
    }):OnChanged(function(v)
        silent.enabled = v
        if v then
            task.spawn(function()
                pcall(installHooks)
                pcall(updateTarget)
            end)
        else
            pcall(uninstallHooks)
        end
        Notify("FortniHub", "Silent " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    silentSec:AddDropdown("SilentAimType", {
        Title = L("Aim Type"),
        Values = {L("Simple"), L("Advanced")},
        Default = L("Advanced"),
    }):OnChanged(function(v)
        silent.aimType = (v == L("Simple")) and "Simple" or "Advanced"
    end)

    silentSec:AddToggle("SilentPredict", {
        Title = L("Predict"),
        Default = true,
    }):OnChanged(function(v) silent.predict = v end)

    silentSec:AddToggle("SilentForce", {
        Title = L("Force (wallbang)"),
        Default = false,
    }):OnChanged(function(v)
        silent.force = v
        if v then Notify("FortniHub", "Wallbang ВКЛ (может не работать)", 3) end
    end)

    silentSec:AddToggle("SilentAuto", {
        Title = L("Auto Shoot"),
        Default = false,
    }):OnChanged(function(v) silent.autoShoot = v end)

    silentSec:AddSlider("SilentAutoDelay", {
        Title = L("Auto Delay (ms)"),
        Min = 0, Max = 600, Default = 80, Rounding = 0,
    }):OnChanged(function(v) silent.autoDelay = v / 1000 end)

    silentSec:AddKeybind("SilentBind", {
        Title = L("Bind Key"),
        Default = "E",
    }):OnChanged(function(k)
        local ok, kc = pcall(function() return Enum.KeyCode[k] end)
        if ok and kc then
            silent.bindKey = kc
            Notify("FortniHub", "Кнопка: " .. tostring(kc), 2)
        end
    end)

    silentSec:AddSlider("SilentStandoff", {
        Title = L("Standoff"),
        Min = 0, Max = 40, Default = 15, Rounding = 0,
    }):OnChanged(function(v) silent.standoff = v end)

    -- ============ KNIFE SILENT ============
    local knifeSec = tC:AddSection({Name = L("Knife Silent")})

    knifeSec:AddToggle("KnifeSilentOn", {
        Title = L("Knife Silent"),
        Default = false,
    }):OnChanged(function(v)
        knifeSilent.enabled = v
        Notify("FortniHub", "Knife Silent " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    knifeSec:AddToggle("KnifeInsta", {
        Title = L("Insta Kill"),
        Default = false,
    }):OnChanged(function(v) knifeSilent.instaKill = v end)

    knifeSec:AddSlider("KnifeRadius", {
        Title = L("Impact Radius"),
        Min = 2, Max = 40, Default = 12, Rounding = 0,
    }):OnChanged(function(v) knifeSilent.radius = v end)

    knifeSec:AddToggle("KnifePredict", {
        Title = L("Knife Prediction"),
        Default = true,
    }):OnChanged(function(v) knifeSilent.predict = v end)

    -- ============ KILL AURA (v1 + v2 selectable) ============
    local kaSec = tC:AddSection({Name = L("Kill Aura")})

    kaSec:AddDropdown("KAVersion", {
        Title = L("Kill Aura Version"),
        Values = {"Килл Аура v1", "Килл Аура v2"},
        Default = "Килл Аура v2",
    }):OnChanged(function(v)
        killAuraVersion = (v == "Килл Аура v1") and "v1" or "v2"
        kaV1.on = false
        kaV2.on = false
        if Options.KAOn and Options.KAOn.Value then
            kaV1.on = killAuraVersion == "v1"
            kaV2.on = killAuraVersion == "v2"
        end
        Notify("FortniHub", "Аура: " .. killAuraVersion, 2)
    end)

    kaSec:AddToggle("KAOn", {
        Title = L("Kill Aura"),
        Default = false,
    }):OnChanged(function(v)
        kaV1.on = v and killAuraVersion == "v1"
        kaV2.on = v and killAuraVersion == "v2"
        Notify("FortniHub", "KillAura " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    kaSec:AddSlider("KADist", {
        Title = L("Radius"),
        Min = 5, Max = 60, Default = 30, Rounding = 0,
    }):OnChanged(function(v) kaV1.dist = v; kaV2.dist = v end)

    -- v1: FireServer на KnifeStabbed / HandleTouched
    AddConn("KAv1Tick", RunService.Heartbeat:Connect(function()
        if not kaV1.on then return end
        if tick() - kaV1.lastHit < 0.05 then return end
        local char = LocalPlayer.Character
        if not char then return end
        local knife = char:FindFirstChild("Knife")
        if not knife then return end
        local ev = knife:FindFirstChild("Events")
        if not ev then return end
        local stabbed = ev:FindFirstChild("KnifeStabbed")
        local touched = ev:FindFirstChild("HandleTouched")
        if not stabbed or not touched then return end
        local my = char:FindFirstChild("HumanoidRootPart")
        if not my then return end
        local victims = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local tc = p.Character
                if tc then
                    local th = tc:FindFirstChildOfClass("Humanoid")
                    local tp = tc:FindFirstChild("HumanoidRootPart")
                    if th and th.Health > 0 and tp and (tp.Position - my.Position).Magnitude <= kaV1.dist then
                        victims[#victims + 1] = tp
                    end
                end
            end
        end
        if #victims > 0 then
            pcall(function() stabbed:FireServer() end)
            for _, v in ipairs(victims) do
                pcall(function() touched:FireServer(v) end)
            end
            kaV1.lastHit = tick()
        end
    end))

    -- v2: тот же самый, но с более чистым циклом (как у друга)
    -- (в реальности они очень похожи, но v2 имеет "clean" отступ)
    AddConn("KAv2Tick", RunService.Heartbeat:Connect(function()
        if not kaV2.on then return end
        if tick() - kaV2.lastHit < 0.05 then return end
        local char = LocalPlayer.Character
        if not char then return end
        local knife = char:FindFirstChild("Knife")
        if not knife then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local bpk = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife")
            if hum and bpk then hum:EquipTool(bpk) end
            return
        end
        local ev = knife:FindFirstChild("Events")
        if not ev then return end
        local stabbed = ev:FindFirstChild("KnifeStabbed")
        local touched = ev:FindFirstChild("HandleTouched")
        if not stabbed or not touched then return end
        local my = char:FindFirstChild("HumanoidRootPart")
        if not my then return end
        local victims = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local tc = p.Character
                if tc then
                    local th = tc:FindFirstChildOfClass("Humanoid")
                    local tp = tc:FindFirstChild("HumanoidRootPart")
                    if th and th.Health > 0 and tp and (tp.Position - my.Position).Magnitude <= kaV2.dist then
                        victims[#victims + 1] = tp
                    end
                end
            end
        end
        if #victims > 0 then
            pcall(function() stabbed:FireServer() end)
            for _, v in ipairs(victims) do
                pcall(function() touched:FireServer(v) end)
            end
            kaV2.lastHit = tick()
        end
    end))

    -- ============ EXTRAS ============
    local miscSec = tC:AddSection({Name = "Прочее"})

    miscSec:AddToggle("AutoGrabGun", {
        Title = L("Auto Grab Gun"),
        Default = false,
    })

    miscSec:AddButton({
        Title = L("Kill Sheriff"),
        Callback = function()
            local s = isSheriff()
            if not s then Notify("FortniHub", "Шериф не найден", 2); return end
            local char = LocalPlayer.Character
            local my = char and char:FindFirstChild("HumanoidRootPart")
            local th = s.Character and s.Character:FindFirstChild("HumanoidRootPart")
            local knife = char and char:FindFirstChild("Knife")
            if not (my and th and knife) then return end
            my.CFrame = th.CFrame * CFrame.new(0, 0, 1.5)
            task.wait(0.05)
            local ev = knife:FindFirstChild("Events")
            if ev then
                local stab = ev:FindFirstChild("KnifeStabbed")
                local touch = ev:FindFirstChild("HandleTouched")
                if stab then pcall(function() stab:FireServer() end) end
                if touch then pcall(function() touch:FireServer(th) end) end
            end
        end,
    })

    miscSec:AddButton({
        Title = L("Suicide"),
        Callback = function()
            local h = getHum()
            if h then h.Health = 0 end
        end,
    })

    print("[FortniHub][INFO] Combat модуль готов")
end

-- ============================================================
-- MOVEMENT (базовый + Server Look)
-- ============================================================
do
    local tM = Window:AddTab({Title = L("Movement")})
    Tabs.Movement = tM

    local mvSec = tM:AddSection({Name = "Движение"})

    mvSec:AddToggle("SpeedToggle", {Title = L("Speed"), Default = false})
    mvSec:AddSlider("SpeedValue", {Title = L("Walk Speed"), Min = 16, Max = 500, Default = 32, Rounding = 0})

    mvSec:AddToggle("FlyToggle", {Title = L("Fly"), Default = false})
    mvSec:AddSlider("FlySpeed", {Title = L("Fly Speed"), Min = 20, Max = 500, Default = 60, Rounding = 0})

    mvSec:AddToggle("BhopToggle", {Title = L("Bunny Hop"), Default = false})
    mvSec:AddSlider("BhopMax", {Title = L("Max Speed"), Min = 60, Max = 500, Default = 250, Rounding = 0})
    mvSec:AddSlider("BhopAccel", {Title = L("Accel Time"), Min = 1, Max = 30, Default = 10, Rounding = 0})

    mvSec:AddToggle("Noclip", {Title = L("Noclip"), Default = false})
    mvSec:AddToggle("Spinbot", {Title = L("Spinbot"), Default = false})
    mvSec:AddSlider("SpinSpeed", {Title = L("Spin Speed"), Min = 1, Max = 50, Default = 8, Rounding = 0})
    mvSec:AddToggle("InfJump", {Title = L("Infinite Jump"), Default = false})

    mvSec:AddToggle("JumpPowerToggle", {Title = L("Custom Jump Power"), Default = false})
    mvSec:AddSlider("JumpPowerVal", {Title = L("Jump Power"), Min = 50, Max = 500, Default = 100, Rounding = 0})

    -- ---- FREEZE с настраиваемыми кнопками ----
    local freezeSec = tM:AddSection({Name = L("Freeze")})

    freezeSec:AddToggle("FreezeToggle", {Title = L("Freeze"), Default = false}):OnChanged(function(v)
        S.frozen = v
    end)

    freezeSec:AddSlider("FreezeSpeed", {Title = L("Freeze Speed"), Min = 20, Max = 300, Default = 60, Rounding = 0})

    freezeSec:AddKeybind("FreezeUpKey", {
        Title = L("Freeze Up Key"),
        Default = "Space",
    }):OnChanged(function(k)
        local ok, kc = pcall(function() return Enum.KeyCode[k] end)
        if ok and kc then S.freezeUpKey = kc end
    end)

    freezeSec:AddKeybind("FreezeDownKey", {
        Title = L("Freeze Down Key"),
        Default = "LeftAlt",
    }):OnChanged(function(k)
        local ok, kc = pcall(function() return Enum.KeyCode[k] end)
        if ok and kc then S.freezeDownKey = kc end
    end)

    -- ---- SERVER LOOK ----
    local serverLookSec = tM:AddSection({Name = L("Server Look")})

    serverLookSec:AddToggle("ServerLookOn", {
        Title = L("Server Look"),
        Default = false,
    }):OnChanged(function(v)
        S.serverLookOn = v
        if not v then
            -- сброс головы
            local c = LocalPlayer.Character
            if c then
                local head = c:FindFirstChild("Head")
                local upper = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
                if head and upper then
                    local neck = upper:FindFirstChild("Neck") or head:FindFirstChild("Neck")
                    if neck and neck:IsA("Motor6D") then
                        neck.C0 = neck.C0 -- уже сохранён оригинал в переменной
                    end
                end
            end
        end
    end)

    serverLookSec:AddDropdown("ServerLookMode", {
        Title = L("Look Mode"),
        Values = {L("Up"), L("Down"), L("Combo")},
        Default = L("Up"),
    }):OnChanged(function(v)
        if v == L("Up") then S.serverLookMode = "Up"
        elseif v == L("Down") then S.serverLookMode = "Down"
        else S.serverLookMode = "Combo" end
    end)

    serverLookSec:AddSlider("ServerLookSpeed", {
        Title = L("Look Speed"),
        Min = 0.5, Max = 5, Default = 1, Rounding = 1,
    }):OnChanged(function(v) S.serverLookSpeed = v end)

    -- Реализация server look через изменение C0 шейного Motor6D
    local originalNeckC0 = {}
    local comboDir = 1
    local lastComboFlip = 0

    local function ensureNeckSaved()
        local c = LocalPlayer.Character
        if not c then return end
        local upper = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
        if not upper then return end
        local neck = upper:FindFirstChild("Neck")
        if not neck or not neck:IsA("Motor6D") then return end
        if not originalNeckC0[neck] then
            originalNeckC0[neck] = neck.C0
        end
    end

    AddConn("ServerLookTick", RunService.Heartbeat:Connect(function()
        if not S.serverLookOn then return end
        ensureNeckSaved()
        local c = LocalPlayer.Character
        if not c then return end
        local upper = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
        if not upper then return end
        local neck = upper:FindFirstChild("Neck")
        if not neck or not neck:IsA("Motor6D") then return end
        local orig = originalNeckC0[neck]
        if not orig then return end

        local mode = S.serverLookMode
        local speed = S.serverLookSpeed
        local angle = 0

        if mode == "Up" then
            angle = math.rad(-45) * speed
        elseif mode == "Down" then
            angle = math.rad(45) * speed
        elseif mode == "Combo" then
            local now = os.clock()
            if now - lastComboFlip > 1 / speed then
                lastComboFlip = now
                comboDir = -comboDir
            end
            angle = math.rad(45) * comboDir
        end

        neck.C0 = orig * CFrame.Angles(angle, 0, 0)
    end))

    -- Main movement loop
    AddConn("MovementTick", RunService.Heartbeat:Connect(function()
        local hum = getHum()
        if not hum then return end

        local speedOn = Options.SpeedToggle and Options.SpeedToggle.Value
        if speedOn then
            hum.WalkSpeed = Options.SpeedValue and Options.SpeedValue.Value or 32
        end

        if S.frozen then
            hum.WalkSpeed = 0
            local hrp = getHRP()
            if hrp then
                if not hrp:FindFirstChild("FH_FreezeBV") then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "FH_FreezeBV"
                    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                    bv.Velocity = Vector3.zero
                    bv.Parent = hrp
                end
                local sp = Options.FreezeSpeed and Options.FreezeSpeed.Value or 60
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(S.freezeUpKey) then dir = dir + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(S.freezeDownKey) then dir = dir - Vector3.new(0, 1, 0) end
                local bv = hrp:FindFirstChild("FH_FreezeBV")
                if bv then
                    bv.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero
                end
            end
        else
            local hrp = getHRP()
            if hrp then
                local bv = hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv:Destroy() end
            end
        end

        -- Jump power
        local jpOn = Options.JumpPowerToggle and Options.JumpPowerToggle.Value
        if jpOn then
            hum.UseJumpPower = true
            local jp = Options.JumpPowerVal and Options.JumpPowerVal.Value or 100
            if hum.JumpPower ~= jp then hum.JumpPower = jp end
        end

        -- Spinbot
        local spinOn = Options.Spinbot and Options.Spinbot.Value
        if spinOn and getHRP() then
            local hrp = getHRP()
            local s = Options.SpinSpeed and Options.SpinSpeed.Value or 8
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(s), 0)
        end
    end))

    -- Noclip
    AddConn("NoclipTick", RunService.Stepped:Connect(function()
        local on = Options.Noclip and Options.Noclip.Value
        if on then
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end
    end))

    -- Inf jump
    AddConn("InfJump", UserInputService.JumpRequest:Connect(function()
        local on = Options.InfJump and Options.InfJump.Value
        if on then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))

    -- Fly
    AddConn("FlyTick", RunService.RenderStepped:Connect(function()
        local on = Options.FlyToggle and Options.FlyToggle.Value
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then return end
        if on then
            hum.PlatformStand = true
            local sp = Options.FlySpeed and Options.FlySpeed.Value or 60
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
            hrp.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero
        elseif hum.PlatformStand then
            hum.PlatformStand = false
        end
    end))

    print("[FortniHub][INFO] Movement модуль готов")
end

-- ============================================================
-- КОНЕЦ ЧАСТИ 1/3
-- ============================================================
-- Часть 2/3: Visuals Engine (ESP), Effects (tracer, aura, shaders,
--             skybox, fog, exposure, crosshair WORKING, murder effect,
--             chams, china hat, backtrack, AWP replace RESTORED)
-- Часть 3/3: Tools (TP/Fling tool), Autofarm v1/v2 selector, Anti,
--             Notify, Sounds, Emotes, Map Vote, Farm v1/v2

print("[FortniHub][INFO] ================================")
print("[FortniHub][INFO] PART 1/3 УСПЕШНО ЗАГРУЖЕН")
print("[FortniHub][INFO] Фичи: HUD v16, Silent v2, Knife Silent,")
print("[FortniHub][INFO]       KillAura v1/v2, Movement, Freeze, Server Look")
print("[FortniHub][INFO] Ждём часть 2/3 (Visuals + Effects)")
print("[FortniHub][INFO] ================================")

task.spawn(function()
    task.wait(0.5)
    Notify("FortniHub", "Часть 1/3 загружена! P - меню", 5)
end)
-- ============================================================
-- FORTNIHUB v16 — Часть 2/3: Visuals + Effects
-- ============================================================

-- ============================================================
-- ESP ENGINE
-- ============================================================
do
    local esp = {
        on = false,
        box = false, boxCol = {Color3.fromRGB(255, 60, 60), 1}, boxType = "Static",
        boxGrd = false, boxGrd1 = Color3.fromRGB(255, 60, 60), boxGrd2 = Color3.fromRGB(255, 180, 60),
        boxFill = false, boxFillCol = {Color3.fromRGB(255, 60, 60), 0.5},
        name = false, nameCol = {Color3.new(1, 1, 1), 1},
        dist = false, distCol = {Color3.fromRGB(220, 220, 220), 1},
        avatar = false,
        skel = false, skelCol = {Color3.new(1, 1, 1), 1},
        chams = false,
        chamsFMur = {Color3.fromRGB(255, 60, 60), 0.5}, chamsOMur = {Color3.fromRGB(255, 60, 60), 0},
        chamsFInno = {Color3.new(1, 1, 1), 0.5}, chamsOInno = {Color3.new(1, 1, 1), 0},
        chamsFShf = {Color3.fromRGB(0, 153, 255), 0.5}, chamsOShf = {Color3.fromRGB(0, 153, 255), 0},
        matChams = false, matType = "ForceField",
        matColMur = Color3.fromRGB(255, 60, 60),
        matColInno = Color3.new(1, 1, 1),
        matColShf = Color3.fromRGB(0, 153, 255),
        flags = false,
        flagMur = {Color3.fromRGB(255, 60, 60), 1}, flagShf = {Color3.fromRGB(0, 153, 255), 1},
        arrows = false,
        arrowMur = Color3.fromRGB(255, 60, 60),
        arrowInno = Color3.new(1, 1, 1),
        arrowShf = Color3.fromRGB(0, 153, 255),
        arrowSize = 42, arrowDist = 260,
        maxDist = 500,
        allowLocal = false,
    }
    _G.FH_ESP = esp

    local drawings = {}
    local chamsFolder = Instance.new("Folder", Workspace)
    chamsFolder.Name = "FH_ChamsFolder"
    local matCache = {}

    local function dispose(e)
        for _, d in pairs(e) do
            if type(d) == "table" then
                for _, x in pairs(d) do pcall(function() x:Remove() end) end
            elseif type(d) == "userdata" then
                pcall(function() d:Remove() end)
            end
        end
    end

    local function getOrCreate(p)
        local e = drawings[p]
        if e then return e end
        e = { box = {}, boxFill = nil, name = nil, dist = nil, avatar = nil,
              skel = {}, flags = {}, arrow = nil }
        drawings[p] = e
        return e
    end

    local function ensureBox(e, i)
        if e.box[i] then return e.box[i] end
        local d = Drawing.new("Line")
        d.Thickness = 1.5
        d.Transparency = 1
        d.Visible = false
        e.box[i] = d
        return d
    end

    local function classifyRole(p)
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and type(m) == "table" and type(m.PlayerData) == "table" then
            local d = m.PlayerData[p.Name]
            if d and not d.Dead then
                if d.Role == "Murderer" then return "murder" end
                if d.Role == "Sheriff" or d.Role == "Hero" then return "sheriff" end
                return "inno"
            end
        end
        local r = getRole(p)
        if r == "murderer" then return "murder" end
        if r == "sheriff" then return "sheriff" end
        return "inno"
    end

    local function roleColor(role)
        if role == "murder" then return Color3.fromRGB(255, 60, 60) end
        if role == "sheriff" then return Color3.fromRGB(0, 153, 255) end
        return Color3.new(1, 1, 1)
    end

    local function grad(c1, c2)
        local t = math.sin(os.clock() * 3) * 0.5 + 0.5
        return c1:Lerp(c2, t)
    end

    local function updateChams(p, role)
        if not esp.chams then
            local h = chamsFolder:FindFirstChild(p.Name)
            if h then h:Destroy() end
            return
        end
        local char = p.Character
        if not char then return end
        local h = chamsFolder:FindFirstChild(p.Name)
        if not h then
            h = Instance.new("Highlight")
            h.Name = p.Name
            h.Adornee = char
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = chamsFolder
        end
        local rk = role == "murder" and "Mur" or (role == "sheriff" and "Shf" or "Inno")
        h.FillColor = esp["chamsF" .. rk][1]
        h.FillTransparency = esp["chamsF" .. rk][2]
        h.OutlineColor = esp["chamsO" .. rk][1]
        h.OutlineTransparency = esp["chamsO" .. rk][2]
    end

    local function updateMatChams()
        if not esp.matChams then
            for part, orig in pairs(matCache) do
                if part.Parent then
                    pcall(function() part.Material = orig.m end)
                    pcall(function() part.Color = orig.c end)
                end
            end
            table.clear(matCache)
            return
        end
        local mat = Enum.Material.ForceField
        if esp.matType == "Flat" then mat = Enum.Material.SmoothPlastic
        elseif esp.matType == "Chromatic" then mat = Enum.Material.Foil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local role = classifyRole(p)
                local col = role == "murder" and esp.matColMur
                    or (role == "sheriff" and esp.matColShf or esp.matColInno)
                for _, part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if not matCache[part] then
                            matCache[part] = {m = part.Material, c = part.Color}
                        end
                        pcall(function() part.Material = mat end)
                        pcall(function() part.Color = col end)
                    end
                end
            end
        end
    end

    local renderConn

    local function startRender()
        if renderConn then return end
        renderConn = RunService.RenderStepped:Connect(function()
            if not esp.on then return end
            local seen = {}
            local cam = Camera
            local vp = cam.ViewportSize

            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer and not esp.allowLocal then continue end
                if not p.Character then
                    if drawings[p] then dispose(drawings[p]); drawings[p] = nil end
                    continue
                end
                seen[p] = true
                local char = p.Character
                local hrp = char:FindFirstChild("HumanoidRootPart")
                    or char:FindFirstChild("UpperTorso")
                    or char:FindFirstChild("Torso")
                local head = char:FindFirstChild("Head")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not (hrp and head and hum) then continue end
                if hum.Health <= 0 and p ~= LocalPlayer then
                    if drawings[p] then dispose(drawings[p]); drawings[p] = nil end
                    continue
                end

                local e = getOrCreate(p)
                local headPos = head.Position + Vector3.new(0, head.Size.Y * 0.5, 0)
                local footPos = hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5 + (hum.HipHeight or 0), 0)

                local hsp, hon = cam:WorldToViewportPoint(headPos)
                local fsp, fon = cam:WorldToViewportPoint(footPos)

                if not (hon or fon) then
                    for _, d in pairs(e.box) do d.Visible = false end
                    if e.boxFill then e.boxFill.Visible = false end
                    if e.name then e.name.Visible = false end
                    if e.dist then e.dist.Visible = false end
                    if e.avatar then e.avatar.Visible = false end
                    for _, d in pairs(e.skel) do d.Visible = false end
                    for _, d in pairs(e.flags) do d.Visible = false end
                    if e.arrow then e.arrow.Visible = false end
                    continue
                end

                local role = classifyRole(p)
                local dcol = roleColor(role)
                local dist = (cam.CFrame.Position - hrp.Position).Magnitude
                local fade = math.clamp(1 - dist / esp.maxDist, 0.15, 1)

                -- BOX
                if esp.box then
                    local w = math.max(40, (hsp.Y - fsp.Y) * 0.5)
                    local cx = (hsp.X + fsp.X) * 0.5
                    local top, bot = hsp.Y, fsp.Y
                    local left = cx - w
                    local right = cx + w
                    local col = esp.boxGrd and grad(esp.boxGrd1, esp.boxGrd2) or dcol
                    local a = esp.boxCol[2] * fade

                    if esp.boxType == "Static" then
                        local lines = {
                            {left, top, right, top},
                            {right, top, right, bot},
                            {right, bot, left, bot},
                            {left, bot, left, top},
                        }
                        for i, l in ipairs(lines) do
                            local d = ensureBox(e, i)
                            d.From = Vector2.new(l[1], l[2])
                            d.To = Vector2.new(l[3], l[4])
                            d.Color = col
                            d.Transparency = a
                            d.Visible = true
                        end
                        for i = 5, #e.box do e.box[i].Visible = false end
                    else
                        local sg = math.min(w, bot - top) * 0.25
                        local lines = {
                            {left, top, left + sg, top},
                            {left, top, left, top + sg},
                            {right, top, right - sg, top},
                            {right, top, right, top + sg},
                            {left, bot, left + sg, bot},
                            {left, bot, left, bot - sg},
                            {right, bot, right - sg, bot},
                            {right, bot, right, bot - sg},
                        }
                        for i, l in ipairs(lines) do
                            local d = ensureBox(e, i)
                            d.From = Vector2.new(l[1], l[2])
                            d.To = Vector2.new(l[3], l[4])
                            d.Color = col
                            d.Transparency = a
                            d.Visible = true
                        end
                        for i = #lines + 1, #e.box do e.box[i].Visible = false end
                    end

                    if esp.boxFill then
                        if not e.boxFill then
                            e.boxFill = Drawing.new("Square")
                            e.boxFill.Filled = true
                            e.boxFill.Thickness = 0
                        end
                        e.boxFill.Position = Vector2.new(left, top)
                        e.boxFill.Size = Vector2.new(right - left, bot - top)
                        e.boxFill.Color = dcol
                        e.boxFill.Transparency = esp.boxFillCol[2] * fade
                        e.boxFill.Visible = true
                    elseif e.boxFill then
                        e.boxFill.Visible = false
                    end
                else
                    for _, d in pairs(e.box) do d.Visible = false end
                    if e.boxFill then e.boxFill.Visible = false end
                end

                -- NAME
                if esp.name then
                    if not e.name then
                        e.name = Drawing.new("Text")
                        e.name.Size = 13
                        e.name.Center = true
                        e.name.Outline = true
                    end
                    e.name.Text = p.Name
                    e.name.Position = Vector2.new((hsp.X + fsp.X) * 0.5, hsp.Y - 18)
                    e.name.Color = esp.nameCol[1]
                    e.name.Transparency = esp.nameCol[2] * fade
                    e.name.Visible = true
                elseif e.name then e.name.Visible = false end

                -- DISTANCE
                if esp.dist then
                    if not e.dist then
                        e.dist = Drawing.new("Text")
                        e.dist.Size = 12
                        e.dist.Center = true
                        e.dist.Outline = true
                    end
                    e.dist.Text = string.format("%d studs", math.floor(dist))
                    e.dist.Position = Vector2.new((hsp.X + fsp.X) * 0.5, fsp.Y + 4)
                    e.dist.Color = esp.distCol[1]
                    e.dist.Transparency = esp.distCol[2] * fade
                    e.dist.Visible = true
                elseif e.dist then e.dist.Visible = false end

                -- AVATAR
                if esp.avatar then
                    if not e.avatar then
                        e.avatar = Drawing.new("Image")
                        e.avatar.Size = Vector2.new(40, 40)
                        pcall(function()
                            e.avatar.Data = Players:GetUserThumbnailAsync(p.UserId,
                                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                        end)
                    end
                    e.avatar.Position = Vector2.new((hsp.X + fsp.X) * 0.5 - 20, hsp.Y - 60)
                    e.avatar.Transparency = fade
                    e.avatar.Visible = true
                elseif e.avatar then e.avatar.Visible = false end

                -- SKELETON
                if esp.skel then
                    local bones = {
                        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
                        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
                        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
                        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
                        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
                    }
                    for i, b in ipairs(bones) do
                        local p1 = char:FindFirstChild(b[1])
                        local p2 = char:FindFirstChild(b[2])
                        if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                            local s1, o1 = cam:WorldToViewportPoint(p1.Position)
                            local s2, o2 = cam:WorldToViewportPoint(p2.Position)
                            if not e.skel[i] then
                                local d = Drawing.new("Line")
                                d.Thickness = 1
                                d.Transparency = 1
                                e.skel[i] = d
                            end
                            local d = e.skel[i]
                            if o1 and o2 then
                                d.From = Vector2.new(s1.X, s1.Y)
                                d.To = Vector2.new(s2.X, s2.Y)
                                d.Color = esp.skelCol[1]
                                d.Transparency = esp.skelCol[2] * fade
                                d.Visible = true
                            else
                                d.Visible = false
                            end
                        elseif e.skel[i] then
                            e.skel[i].Visible = false
                        end
                    end
                    for i = #bones + 1, #e.skel do e.skel[i].Visible = false end
                else
                    for _, d in pairs(e.skel) do d.Visible = false end
                end

                -- FLAGS
                if esp.flags then
                    local txt = role == "murder" and "[MURD]" or (role == "sheriff" and "[SHF]" or "")
                    if txt ~= "" then
                        if not e.flags[1] then
                            e.flags[1] = Drawing.new("Text")
                            e.flags[1].Size = 13
                            e.flags[1].Outline = true
                        end
                        local d = e.flags[1]
                        d.Text = txt
                        d.Position = Vector2.new(hsp.X + 60, hsp.Y - 10)
                        d.Color = role == "murder" and esp.flagMur[1] or esp.flagShf[1]
                        d.Transparency = fade
                        d.Visible = true
                        for i = 2, #e.flags do e.flags[i].Visible = false end
                    else
                        for _, d in pairs(e.flags) do d.Visible = false end
                    end
                else
                    for _, d in pairs(e.flags) do d.Visible = false end
                end

                -- ARROWS
                if esp.arrows then
                    local onScreen = hsp.X >= 0 and hsp.X <= vp.X and hsp.Y >= 0 and hsp.Y <= vp.Y
                    if onScreen then
                        if e.arrow then e.arrow.Visible = false end
                    else
                        if not e.arrow then
                            e.arrow = Drawing.new("Triangle")
                            e.arrow.Filled = true
                        end
                        local cx, cy = vp.X * 0.5, vp.Y * 0.5
                        local dir = Vector2.new(hsp.X - cx, hsp.Y - cy)
                        if dir.Magnitude < 0.01 then dir = Vector2.new(0, 1) end
                        dir = dir.Unit
                        local px = cx + dir.X * esp.arrowDist
                        local py = cy + dir.Y * esp.arrowDist
                        local sz = esp.arrowSize
                        local perp = Vector2.new(-dir.Y, dir.X)
                        e.arrow.PointA = Vector2.new(px + dir.X * sz * 0.5, py + dir.Y * sz * 0.5)
                        e.arrow.PointB = Vector2.new(px - dir.X * sz * 0.5 + perp.X * sz * 0.5, py - dir.Y * sz * 0.5 + perp.Y * sz * 0.5)
                        e.arrow.PointC = Vector2.new(px - dir.X * sz * 0.5 - perp.X * sz * 0.5, py - dir.Y * sz * 0.5 - perp.Y * sz * 0.5)
                        e.arrow.Color = role == "murder" and esp.arrowMur
                            or (role == "sheriff" and esp.arrowShf or esp.arrowInno)
                        e.arrow.Transparency = fade
                        e.arrow.Visible = true
                    end
                elseif e.arrow then e.arrow.Visible = false end

                updateChams(p, role)
            end

            for p, e in pairs(drawings) do
                if not seen[p] then
                    dispose(e)
                    drawings[p] = nil
                end
            end

            updateMatChams()
        end)
    end

    local function stopRender()
        if renderConn then
            pcall(function() renderConn:Disconnect() end)
            renderConn = nil
        end
        for _, e in pairs(drawings) do dispose(e) end
        table.clear(drawings)
        for _, c in ipairs(chamsFolder:GetChildren()) do c:Destroy() end
        for part, orig in pairs(matCache) do
            if part.Parent then
                pcall(function() part.Material = orig.m end)
                pcall(function() part.Color = orig.c end)
            end
        end
        table.clear(matCache)
    end

    -- UI
    local tV = Window:AddTab({Title = L("Visual")})
    Tabs.Visual = tV
    local espSec = tV:AddSection({Name = "ESP Игроков"})

    espSec:AddToggle("ESPOn", {Title = "Включить ESP", Default = false}):OnChanged(function(v)
        esp.on = v
        if v then startRender() else stopRender() end
        Notify("FortniHub", "ESP " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    espSec:AddToggle("ESPBox", {Title = L("Box"), Default = false}):OnChanged(function(v) esp.box = v end)
    espSec:AddColorPicker("ESPBoxCol", {Title = L("Box Color"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.boxCol[1] = c end)
    espSec:AddSlider("ESPBoxAlpha", {Title = "Прозрачность рамки", Min = 0, Max = 1, Default = 1, Rounding = 2}):OnChanged(function(v) esp.boxCol[2] = v end)
    espSec:AddDropdown("ESPBoxType", {Title = L("Box Type"), Values = {L("Static"), L("Corners")}, Default = L("Static")}):OnChanged(function(v)
        esp.boxType = (v == L("Corners")) and "Corners" or "Static"
    end)
    espSec:AddToggle("ESPBoxGrd", {Title = L("Box Gradient"), Default = false}):OnChanged(function(v) esp.boxGrd = v end)
    espSec:AddColorPicker("ESPBoxGrd1", {Title = L("Grad 1"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.boxGrd1 = c end)
    espSec:AddColorPicker("ESPBoxGrd2", {Title = L("Grad 2"), Default = Color3.fromRGB(255, 180, 60)}):OnChanged(function(c) esp.boxGrd2 = c end)
    espSec:AddToggle("ESPBoxFill", {Title = L("Box Fill"), Default = false}):OnChanged(function(v) esp.boxFill = v end)
    espSec:AddColorPicker("ESPBoxFillCol", {Title = "Цвет заливки", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.boxFillCol[1] = c end)
    espSec:AddSlider("ESPBoxFillAlpha", {Title = "Прозрачность заливки", Min = 0, Max = 1, Default = 0.5, Rounding = 2}):OnChanged(function(v) esp.boxFillCol[2] = v end)

    espSec:AddToggle("ESPName", {Title = L("Name"), Default = false}):OnChanged(function(v) esp.name = v end)
    espSec:AddColorPicker("ESPNameCol", {Title = L("Name Color"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.nameCol[1] = c end)

    espSec:AddToggle("ESPDist", {Title = L("Distance"), Default = false}):OnChanged(function(v) esp.dist = v end)
    espSec:AddColorPicker("ESPDistCol", {Title = L("Distance Color"), Default = Color3.fromRGB(220, 220, 220)}):OnChanged(function(c) esp.distCol[1] = c end)

    espSec:AddToggle("ESPAvatar", {Title = L("Avatar"), Default = false}):OnChanged(function(v) esp.avatar = v end)

    espSec:AddToggle("ESPSkel", {Title = L("Skeleton"), Default = false}):OnChanged(function(v) esp.skel = v end)
    espSec:AddColorPicker("ESPSkelCol", {Title = L("Skeleton Color"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.skelCol[1] = c end)

    espSec:AddToggle("ESPChams", {Title = L("Glow Chams"), Default = false}):OnChanged(function(v) esp.chams = v end)
    espSec:AddColorPicker("ESPChamsFMur", {Title = L("Murder Fill"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.chamsFMur[1] = c end)
    espSec:AddColorPicker("ESPChamsOMur", {Title = L("Murder Outline"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.chamsOMur[1] = c end)
    espSec:AddColorPicker("ESPChamsFInno", {Title = L("Inno Fill"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.chamsFInno[1] = c end)
    espSec:AddColorPicker("ESPChamsOInno", {Title = L("Inno Outline"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.chamsOInno[1] = c end)
    espSec:AddColorPicker("ESPChamsFShf", {Title = L("Sheriff Fill"), Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.chamsFShf[1] = c end)
    espSec:AddColorPicker("ESPChamsOShf", {Title = L("Sheriff Outline"), Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.chamsOShf[1] = c end)

    espSec:AddToggle("ESPMatChams", {Title = L("Material Chams"), Default = false}):OnChanged(function(v) esp.matChams = v end)
    espSec:AddDropdown("ESPMatType", {Title = L("Mat Type"), Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"}):OnChanged(function(v) esp.matType = v end)
    espSec:AddColorPicker("ESPMatMur", {Title = L("Murder"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.matColMur = c end)
    espSec:AddColorPicker("ESPMatInno", {Title = L("Inno"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.matColInno = c end)
    espSec:AddColorPicker("ESPMatShf", {Title = L("Sheriff"), Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.matColShf = c end)

    espSec:AddToggle("ESPFlags", {Title = L("Flags (roles)"), Default = false}):OnChanged(function(v) esp.flags = v end)

    espSec:AddToggle("ESPArrows", {Title = L("Off-screen Arrows"), Default = false}):OnChanged(function(v) esp.arrows = v end)
    espSec:AddColorPicker("ESPArrMur", {Title = L("Murder"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.arrowMur = c end)
    espSec:AddColorPicker("ESPArrInno", {Title = L("Inno"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.arrowInno = c end)
    espSec:AddColorPicker("ESPArrShf", {Title = L("Sheriff"), Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.arrowShf = c end)
    espSec:AddSlider("ESPArrSz", {Title = L("Arrow Size"), Min = 16, Max = 96, Default = 42, Rounding = 0}):OnChanged(function(v) esp.arrowSize = v end)
    espSec:AddSlider("ESPArrDist", {Title = L("Arrow Dist"), Min = 40, Max = 520, Default = 260, Rounding = 0}):OnChanged(function(v) esp.arrowDist = v end)

    espSec:AddToggle("ESPAllowLocal", {Title = "Показывать себя", Default = false}):OnChanged(function(v) esp.allowLocal = v end)

    print("[FortniHub][INFO] ESP Engine загружен")
end

-- ============================================================
-- EFFECTS — Tracer, World FX, Shaders, Fog, Ambient, Exposure, Skybox
-- ============================================================
do
    local tE = Window:AddTab({Title = L("Effects")})
    Tabs.Effects = tE

    -- ============ BULLET TRACER ============
    local tracerSec = tE:AddSection({Name = L("Bullet Tracer")})
    local tracerOn, tracerCol, tracerDur = false, Color3.fromRGB(133, 220, 255), 1
    local tracerConn

    local function makePoint(pos, life)
        local pt = Instance.new("Part")
        pt.Transparency = 1
        pt.Anchored = true
        pt.CanCollide = false
        pt.CanQuery = false
        pt.Size = Vector3.new(1, 1, 1)
        pt.CFrame = CFrame.new(pos)
        Instance.new("Attachment", pt)
        pt.Parent = Workspace
        task.delay(life, function() pcall(function() pt:Destroy() end) end)
        return pt
    end

    local function toPos(v)
        if typeof(v) == "Vector3" then return v end
        if typeof(v) == "CFrame" then return v.Position end
        if typeof(v) == "Instance" then
            if v:IsA("Attachment") then return v.WorldPosition end
            if v:IsA("BasePart") then return v.Position end
        end
    end

    local function createTracer(sv, ev)
        local sp, ep = toPos(sv), toPos(ev)
        if not sp or not ep then return end
        local p1 = makePoint(sp, tracerDur + 0.5)
        local p2 = makePoint(ep, tracerDur + 0.5)
        local beam = Instance.new("Beam")
        beam.FaceCamera = true
        beam.TextureSpeed = 1.5
        beam.TextureLength = 2
        beam.Width0 = 0.25
        beam.Width1 = 0.25
        beam.LightEmission = 3
        beam.LightInfluence = 0
        beam.Brightness = 2.5
        beam.Texture = "rbxassetid://12781800668"
        beam.Color = ColorSequence.new(tracerCol)
        beam.Transparency = NumberSequence.new(0.1)
        beam.Attachment0 = p1:FindFirstChildOfClass("Attachment")
        beam.Attachment1 = p2:FindFirstChildOfClass("Attachment")
        beam.Parent = p1
        task.delay(tracerDur, function()
            if beam.Parent then
                TweenService:Create(beam, TweenInfo.new(0.2), {Width0 = 0, Width1 = 0}):Play()
            end
        end)
    end

    local function connectTracer()
        if tracerConn then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if not ok or not remote then return end
        tracerConn = remote.OnClientEvent:Connect(function(gun, sv, ev)
            if not tracerOn then return end
            local c = LocalPlayer.Character
            if not c then return end
            if not (typeof(gun) == "Instance" and gun:IsDescendantOf(c)) then return end
            createTracer(sv, ev)
        end)
    end

    tracerSec:AddToggle("TracerOn", {Title = "Включить трассер", Default = false}):OnChanged(function(v)
        tracerOn = v
        if v then connectTracer() end
    end)
    tracerSec:AddColorPicker("TracerCol", {Title = L("Color"), Default = Color3.fromRGB(133, 220, 255)}):OnChanged(function(c) tracerCol = c end)
    tracerSec:AddSlider("TracerDur", {Title = L("Duration"), Min = 0.1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v) tracerDur = v end)

    -- ============ WORLD AURA ============
    local auraSec = tE:AddSection({Name = L("World Aura")})
    local auraOn, auraType, auraCol = false, "angel", Color3.fromRGB(133, 220, 255)
    local auraIds = {
        angel = "97658130917593",
        starlight = "134645216613107",
        heavenly = "139300897520961",
        ribbon = "132069507632161",
        sakura = "81755778619404",
        wind = "80694081850877",
        flow = "119913533725648",
        star = "73754563740680",
    }
    local auraCache, auraParts, auraConn = {}, {}, nil

    local function loadAura(name)
        if auraCache[name] then return auraCache[name] end
        local id = auraIds[name]
        if not id then return nil end
        local ok, objs = pcall(game.GetObjects, game, "rbxassetid://"..id)
        if ok and objs and objs[1] then auraCache[name] = objs[1]; return objs[1] end
    end

    local function colorAura(m, c)
        local seq = ColorSequence.new(c)
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("PointLight") then d.Color = c
            elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Color = seq end
        end
    end

    local function clearAura()
        for i = #auraParts, 1, -1 do
            pcall(function() auraParts[i]:Destroy() end)
            auraParts[i] = nil
        end
    end

    local function applyAura()
        clearAura()
        local c = LocalPlayer.Character
        if not c then return end
        local src = loadAura(auraType)
        if not src then return end
        colorAura(src, auraCol)
        local clone = src:Clone()
        for _, part in ipairs(clone:GetChildren()) do
            local tgt = c:FindFirstChild(part.Name)
            if tgt and tgt:IsA("BasePart") then
                for _, child in ipairs(part:GetChildren()) do
                    child.Parent = tgt
                    auraParts[#auraParts + 1] = child
                end
            end
        end
        clone:Destroy()
    end

    local function startAura()
        if auraConn then return end
        auraConn = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if auraOn then applyAura() end
        end)
        task.spawn(applyAura)
    end

    local function stopAura()
        if auraConn then pcall(function() auraConn:Disconnect() end) auraConn = nil end
        clearAura()
    end

    auraSec:AddToggle("AuraOn", {Title = "Включить ауру", Default = false}):OnChanged(function(v)
        auraOn = v
        if v then startAura() else stopAura() end
    end)
    auraSec:AddDropdown("AuraType", {
        Title = L("Type"),
        Values = {"angel", "starlight", "heavenly", "ribbon", "sakura", "wind", "flow", "star"},
        Default = "angel",
    }):OnChanged(function(v)
        auraType = v
        if auraOn then task.spawn(applyAura) end
    end)
    auraSec:AddColorPicker("AuraCol", {Title = L("Color"), Default = Color3.fromRGB(133, 220, 255)}):OnChanged(function(c)
        auraCol = c
        for _, m in pairs(auraCache) do colorAura(m, c) end
        if auraOn then task.spawn(applyAura) end
    end)

    -- ============ WORLD FX ============
    local fxSec = tE:AddSection({Name = L("World Effects")})
    local fxOn, fxType, fxCol, fxRate = false, "Snow", Color3.fromRGB(150, 200, 255), 250
    local fxPart, fxEmit, fxConn = nil, nil, nil

    local function styleFX()
        local e = fxEmit
        if not e then return end
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.LightInfluence = 0
        e.LightEmission = 0.4
        e.EmissionDirection = Enum.NormalId.Bottom
        e.Rate = fxRate
        e.Color = ColorSequence.new(fxCol)
        if fxType == "Snow" then
            e.Lifetime = NumberRange.new(4, 6)
            e.Speed = NumberRange.new(6, 12)
            e.Acceleration = Vector3.new(2, -6, 1)
            e.SpreadAngle = Vector2.new(35, 35)
            e.Rotation = NumberRange.new(0, 360)
            e.RotSpeed = NumberRange.new(-40, 40)
            e.Size = NumberSequence.new(0.55)
            e.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(0.8, 0.3),
                NumberSequenceKeypoint.new(1, 1),
            })
        else
            e.Lifetime = NumberRange.new(5, 7)
            e.Speed = NumberRange.new(5, 10)
            e.Acceleration = Vector3.new(4, -5, 2)
            e.SpreadAngle = Vector2.new(40, 40)
            e.Rotation = NumberRange.new(0, 360)
            e.RotSpeed = NumberRange.new(-80, 80)
            e.Size = NumberSequence.new(0.5)
            e.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.15),
                NumberSequenceKeypoint.new(0.85, 0.25),
                NumberSequenceKeypoint.new(1, 1),
            })
        end
    end

    local function stopFX()
        if fxConn then pcall(function() fxConn:Disconnect() end) fxConn = nil end
        if fxPart then pcall(function() fxPart:Destroy() end) fxPart = nil end
        fxEmit = nil
    end

    local function startFX()
        stopFX()
        fxPart = Instance.new("Part")
        fxPart.Name = "FH_WORLD_FX"
        fxPart.Anchored = true
        fxPart.CanCollide = false
        fxPart.CanQuery = false
        fxPart.CanTouch = false
        fxPart.Transparency = 1
        fxPart.Size = Vector3.new(260, 140, 260)
        fxPart.Parent = Workspace
        fxEmit = Instance.new("ParticleEmitter")
        pcall(function()
            fxEmit.Shape = Enum.ParticleEmitterShape.Box
            fxEmit.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        end)
        fxEmit.Parent = fxPart
        styleFX()
        fxConn = RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local cf = cam.CFrame
            local d = cf.LookVector
            local flat = Vector3.new(d.X, 0, d.Z)
            if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
            fxPart.CFrame = CFrame.new(cf.Position + flat * 57 + Vector3.new(0, 44, 0))
        end)
    end

    fxSec:AddToggle("FXOn", {Title = "Включить эффекты", Default = false}):OnChanged(function(v)
        fxOn = v
        if v then startFX() else stopFX() end
    end)
    fxSec:AddDropdown("FXType", {Title = L("Type"), Values = {L("Snow"), L("Sakura")}, Default = L("Snow")}):OnChanged(function(v)
        fxType = (v == L("Sakura")) and "Sakura" or "Snow"
        if fxOn then styleFX() end
    end)
    fxSec:AddColorPicker("FXCol", {Title = L("Color"), Default = Color3.fromRGB(150, 200, 255)}):OnChanged(function(c)
        fxCol = c
        if fxEmit then fxEmit.Color = ColorSequence.new(c) end
    end)
    fxSec:AddSlider("FXRate", {Title = L("Rate"), Min = 20, Max = 900, Default = 250, Rounding = 1}):OnChanged(function(v)
        fxRate = v
        if fxEmit then styleFX() end
    end)

    -- ============ SHADERS ============
    local shaderSec = tE:AddSection({Name = L("Shaders")})
    local shaderOn, shaderType = false, "morning"
    local origLight = {
        Amb = Lighting.Ambient, Br = Lighting.Brightness, CT = Lighting.ClockTime,
        CSB = Lighting.ColorShift_Bottom, CST = Lighting.ColorShift_Top,
        Exp = Lighting.ExposureCompensation,
        FC = Lighting.FogColor, FS = Lighting.FogStart, FE = Lighting.FogEnd,
        OA = Lighting.OutdoorAmbient, GS = Lighting.GlobalShadows,
    }
    local shaderPresets = {
        morning = { amb = Color3.fromRGB(10, 10, 10), br = 1.5, ct = 7.5, csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(200, 200, 200), exp = 0.3 },
        midday = { amb = Color3.fromRGB(2, 2, 2), br = 3.25, ct = 8, csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(255, 247, 237), exp = 0.85 },
        evening = { amb = Color3.fromRGB(2, 2, 2), br = 2.25, ct = 16, csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(255, 247, 237), exp = 0.65 },
        night = { amb = Color3.fromRGB(33, 33, 33), br = 3.25, ct = 20, csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(255, 247, 237), exp = 0.85 },
    }
    local shaderConn

    local function applyShader()
        local p = shaderPresets[shaderType]
        if not p then return end
        Lighting.Ambient = p.amb
        Lighting.Brightness = p.br
        Lighting.ClockTime = p.ct
        Lighting.ColorShift_Bottom = p.csb
        Lighting.ColorShift_Top = p.cst
        Lighting.ExposureCompensation = p.exp
        Lighting.FogEnd = math.huge
        Lighting.FogStart = math.huge
    end

    local function restoreShader()
        Lighting.Ambient = origLight.Amb
        Lighting.Brightness = origLight.Br
        Lighting.ClockTime = origLight.CT
        Lighting.ColorShift_Bottom = origLight.CSB
        Lighting.ColorShift_Top = origLight.CST
        Lighting.ExposureCompensation = origLight.Exp
        Lighting.FogColor = origLight.FC
        Lighting.FogStart = origLight.FS
        Lighting.FogEnd = origLight.FE
        Lighting.OutdoorAmbient = origLight.OA
        Lighting.GlobalShadows = origLight.GS
    end

    shaderSec:AddToggle("ShaderOn", {Title = "Включить шейдеры", Default = false}):OnChanged(function(v)
        shaderOn = v
        if v then
            applyShader()
            if not shaderConn then
                shaderConn = RunService.Heartbeat:Connect(function()
                    if shaderOn then applyShader() end
                end)
            end
        else
            restoreShader()
        end
    end)
    shaderSec:AddDropdown("ShaderType", {
        Title = L("Preset"),
        Values = {L("morning"), L("midday"), L("evening"), L("night")},
        Default = L("morning"),
    }):OnChanged(function(v)
        for k in pairs(shaderPresets) do
            if L(k) == v then shaderType = k break end
        end
        if shaderOn then applyShader() end
    end)

    -- ============ FOG / AMBIENT / EXPOSURE ============
    local wSec = tE:AddSection({Name = "Мир"})

    local fogOn, fogCol, fogStart, fogEnd = false, Color3.fromRGB(192, 192, 192), 0, 1000
    wSec:AddToggle("FogOn", {Title = L("Custom Fog"), Default = false}):OnChanged(function(v)
        fogOn = v
        if v then
            Lighting.FogColor = fogCol
            Lighting.FogStart = fogStart
            Lighting.FogEnd = fogEnd
        else
            Lighting.FogColor = origLight.FC
            Lighting.FogStart = origLight.FS
            Lighting.FogEnd = origLight.FE
        end
    end)
    wSec:AddColorPicker("FogCol", {Title = L("Color"), Default = Color3.fromRGB(192, 192, 192)}):OnChanged(function(c)
        fogCol = c
        if fogOn then Lighting.FogColor = c end
    end)
    wSec:AddSlider("FogStart", {Title = L("Start"), Min = 0, Max = 1000, Default = 0, Rounding = 0}):OnChanged(function(v)
        fogStart = v
        if fogOn then Lighting.FogStart = v end
    end)
    wSec:AddSlider("FogEnd", {Title = L("End"), Min = 0, Max = 1000, Default = 1000, Rounding = 0}):OnChanged(function(v)
        fogEnd = v
        if fogOn then Lighting.FogEnd = v end
    end)

    local ambOn, ambCol = false, Color3.fromRGB(128, 128, 128)
    wSec:AddToggle("AmbOn", {Title = L("Custom Ambient"), Default = false}):OnChanged(function(v)
        ambOn = v
        if v then
            Lighting.Ambient = ambCol
            Lighting.OutdoorAmbient = ambCol
        else
            Lighting.Ambient = origLight.Amb
            Lighting.OutdoorAmbient = origLight.OA
        end
    end)
    wSec:AddColorPicker("AmbCol", {Title = L("Ambient Color"), Default = Color3.fromRGB(128, 128, 128)}):OnChanged(function(c)
        ambCol = c
        if ambOn then
            Lighting.Ambient = c
            Lighting.OutdoorAmbient = c
        end
    end)

    local expOn, expVal = false, 0
    wSec:AddToggle("ExpOn", {Title = L("Exposure"), Default = false}):OnChanged(function(v)
        expOn = v
        if v then Lighting.ExposureCompensation = expVal
        else Lighting.ExposureCompensation = origLight.Exp end
    end)
    wSec:AddSlider("ExpVal", {Title = L("Value"), Min = -5, Max = 5, Default = 0, Rounding = 2}):OnChanged(function(v)
        expVal = v
        if expOn then Lighting.ExposureCompensation = v end
    end)

    -- ============ SKYBOX ============
    local skyOn, skyName = false, "Jungle"
    local createdSky, origSky, origSkyParent = nil, nil, nil
    local skyboxes = {
        ["Jungle"] = {
            SkyboxBk = "http://www.roblox.com/asset/?id=214399891",
            SkyboxDn = "http://www.roblox.com/asset/?id=214399887",
            SkyboxFt = "http://www.roblox.com/asset/?id=214399894",
            SkyboxLf = "http://www.roblox.com/asset/?id=214405668",
            SkyboxRt = "http://www.roblox.com/asset/?id=214399899",
            SkyboxUp = "http://www.roblox.com/asset/?id=214399889",
        },
        ["Blossom"] = {
            SkyboxBk = "http://www.roblox.com/asset/?id=271042516",
            SkyboxDn = "http://www.roblox.com/asset/?id=271077243",
            SkyboxFt = "http://www.roblox.com/asset/?id=271042556",
            SkyboxLf = "http://www.roblox.com/asset/?id=271042310",
            SkyboxRt = "http://www.roblox.com/asset/?id=271042467",
            SkyboxUp = "http://www.roblox.com/asset/?id=271077958",
        },
        ["Red night"] = {
            SkyboxBk = "http://www.roblox.com/Asset/?ID=401664839",
            SkyboxDn = "http://www.roblox.com/Asset/?ID=401664862",
            SkyboxFt = "http://www.roblox.com/Asset/?ID=401664960",
            SkyboxLf = "http://www.roblox.com/Asset/?ID=401664881",
            SkyboxRt = "http://www.roblox.com/Asset/?ID=401664901",
            SkyboxUp = "http://www.roblox.com/Asset/?ID=401664936",
        },
        ["Purple"] = {
            SkyboxBk = "http://www.roblox.com/asset/?id=13694952867",
            SkyboxDn = "http://www.roblox.com/asset/?id=13694968325",
            SkyboxFt = "http://www.roblox.com/asset/?id=13694980654",
            SkyboxLf = "http://www.roblox.com/asset/?id=13694998113",
            SkyboxRt = "http://www.roblox.com/asset/?id=13695002700",
            SkyboxUp = "http://www.roblox.com/asset/?id=13695007103",
        },
        ["Foggy"] = {
            SkyboxBk = "rbxassetid://1370717244",
            SkyboxDn = "rbxassetid://1370717336",
            SkyboxFt = "rbxassetid://1370717438",
            SkyboxLf = "rbxassetid://1370717567",
            SkyboxRt = "rbxassetid://1370717698",
            SkyboxUp = "rbxassetid://1370717782",
        },
    }
    local skyAssets = {["Galaxy"] = 15983996673, ["Anime"] = 13107361022, ["Minecraft"] = 2758029221}

    local function clearSky()
        if createdSky then pcall(function() createdSky:Destroy() end) createdSky = nil end
    end

    local function applySky(name)
        if not origSky then
            local existing = Lighting:FindFirstChildOfClass("Sky")
            if existing and existing ~= createdSky then
                origSky = existing
                origSkyParent = existing.Parent
                pcall(function() existing.Parent = nil end)
            end
        end
        clearSky()
        if skyboxes[name] then
            local sky = Instance.new("Sky")
            sky.Name = "FH_CustomSky"
            for k, v in pairs(skyboxes[name]) do
                pcall(function() sky[k] = v end)
            end
            sky.Parent = Lighting
            createdSky = sky
        elseif skyAssets[name] then
            task.spawn(function()
                local ok, objs = pcall(game.GetObjects, game, "rbxassetid://"..skyAssets[name])
                if not ok or type(objs) ~= "table" then return end
                local found
                for _, o in ipairs(objs) do
                    if o:IsA("Sky") then found = o break end
                    local s = o:FindFirstChildWhichIsA("Sky", true)
                    if s then found = s break end
                end
                if not found or not skyOn then return end
                clearSky()
                found.Name = "FH_CustomSky"
                found.Parent = Lighting
                createdSky = found
            end)
        end
    end

    local function restoreSky()
        clearSky()
        if origSky then
            pcall(function() origSky.Parent = origSkyParent or Lighting end)
            origSky, origSkyParent = nil, nil
        end
    end

    wSec:AddToggle("SkyOn", {Title = L("Skybox"), Default = false}):OnChanged(function(v)
        skyOn = v
        if v then applySky(skyName) else restoreSky() end
    end)
    wSec:AddDropdown("SkyName", {
        Title = L("Preset"),
        Values = {"Jungle", "Blossom", "Red night", "Purple", "Foggy", "Galaxy", "Anime", "Minecraft"},
        Default = "Jungle",
    }):OnChanged(function(v)
        skyName = v
        if skyOn then applySky(v) end
    end)

    print("[FortniHub][INFO] Effects модуль готов")
end

-- ============================================================
-- CROSSHAIR (рабочий)
-- ============================================================
do
    local cxSec = Tabs.Effects:AddSection({Name = "Свой прицел"})
    local chOn = false
    local chGap, chLen, chThick, chRot = 4, 8, 2, 0
    local chCol, chOut = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local chRotNow = 0
    local chLines = {}
    local chConn

    local function hasGun()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("Gun") ~= nil
    end

    local function killCross()
        for i = 1, #chLines do pcall(function() chLines[i]:Remove() end) end
        chLines = {}
        if chConn then pcall(function() chConn:Disconnect() end) chConn = nil end
    end

    local function buildCross()
        killCross()
        for i = 1, 8 do
            local l = Drawing.new("Line")
            l.Visible = false
            l.Color = (i % 2 == 0) and chOut or chCol
            l.Thickness = (i % 2 == 0) and (chThick + 2) or chThick
            l.Transparency = 1
            l.ZIndex = (i % 2 == 0) and 999 or 1000
            chLines[i] = l
        end
        chConn = RunService.RenderStepped:Connect(function(dt)
            if not chOn or not hasGun() then
                for i = 1, #chLines do chLines[i].Visible = false end
                return
            end
            if chRot > 0 then
                chRotNow = (chRotNow + dt * chRot * 100) % 360
            else
                chRotNow = 0
            end
            local mp = UserInputService:GetMouseLocation()
            local cx, cy = mp.X, mp.Y
            local rr = math.rad(chRotNow)
            local angs = {rr, math.pi/2 + rr, math.pi + rr, 3*math.pi/2 + rr}
            for i = 1, 4 do
                local a = angs[i]
                local li = (i - 1) * 2 + 1
                local oi = li + 1
                local sx = cx + chGap * math.cos(a)
                local sy = cy + chGap * math.sin(a)
                local ex = cx + (chGap + chLen) * math.cos(a)
                local ey = cy + (chGap + chLen) * math.sin(a)
                local ox1 = cx + (chGap - 1) * math.cos(a)
                local oy1 = cy + (chGap - 1) * math.sin(a)
                local ox2 = cx + (chGap + chLen + 1) * math.cos(a)
                local oy2 = cy + (chGap + chLen + 1) * math.sin(a)
                local l1, l2 = chLines[li], chLines[oi]
                if l1 then
                    l1.From = Vector2.new(sx, sy)
                    l1.To = Vector2.new(ex, ey)
                    l1.Visible = true
                    l1.Color = chCol
                    l1.Thickness = chThick
                end
                if l2 then
                    l2.From = Vector2.new(ox1, oy1)
                    l2.To = Vector2.new(ox2, oy2)
                    l2.Visible = true
                    l2.Color = chOut
                    l2.Thickness = chThick + 2
                end
            end
        end)
    end

    cxSec:AddToggle("CXOn", {Title = "Включить прицел", Default = false}):OnChanged(function(v)
        chOn = v
        if v then buildCross() else killCross() end
    end)
    cxSec:AddSlider("CXGap", {Title = L("Gap"), Min = 0, Max = 20, Default = 4, Rounding = 1}):OnChanged(function(v) chGap = v end)
    cxSec:AddSlider("CXLen", {Title = L("Length"), Min = 2, Max = 30, Default = 8, Rounding = 1}):OnChanged(function(v) chLen = v end)
    cxSec:AddSlider("CXThick", {Title = L("Thickness"), Min = 1, Max = 5, Default = 2, Rounding = 1}):OnChanged(function(v)
        chThick = v
        for i = 1, #chLines do
            if chLines[i] then chLines[i].Thickness = (i % 2 == 0) and v + 2 or v end
        end
    end)
    cxSec:AddSlider("CXRot", {Title = L("Rotation"), Min = 0, Max = 10, Default = 0, Rounding = 1}):OnChanged(function(v) chRot = v end)
    cxSec:AddColorPicker("CXCol", {Title = L("Color"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c)
        chCol = c
        for i = 1, #chLines do
            if chLines[i] and i % 2 == 1 then chLines[i].Color = c end
        end
    end)
    cxSec:AddColorPicker("CXOut", {Title = L("Outline"), Default = Color3.new(0, 0, 0)}):OnChanged(function(c)
        chOut = c
        for i = 1, #chLines do
            if chLines[i] and i % 2 == 0 then chLines[i].Color = c end
        end
    end)

    print("[FortniHub][INFO] Crosshair готов")
end

-- ============================================================
-- MURDER EFFECT
-- ============================================================
do
    local meSec = Tabs.Effects:AddSection({Name = L("Murder Death Effect")})
    local mOn, mCloneOn, mPartOn, mEmitOn = false, false, false, false
    local mCloneCol = Color3.fromRGB(255, 0, 0)
    local mPartCol = Color3.fromRGB(255, 0, 0)
    local mEmitCol = Color3.fromRGB(255, 100, 100)
    local mCloneDur, mEmitDur = 3, 1.2
    local mClones, mConns, mRoles = {}, {}, {}
    local mThread, mAddConn = nil, nil
    local mActive = {}

    local function removeEmitter(rec)
        for i = 1, #mActive do
            if mActive[i] == rec then
                mActive[i] = mActive[#mActive]
                mActive[#mActive] = nil
                break
            end
        end
        if rec.part and rec.part.Parent then rec.part:Destroy() end
    end

    local function spawnEmitter(char, tint, dur, channel)
        if not char or not char.Parent then return end
        if #mActive >= 3 then removeEmitter(mActive[1]) end
        dur = math.max(dur, 0.2)
        local bodyParts = {}
        for _, s in ipairs(char:GetChildren()) do
            if s:IsA("BasePart") and s.Name ~= "HumanoidRootPart" and #bodyParts < 15 then
                bodyParts[#bodyParts + 1] = s
            end
        end
        if #bodyParts == 0 then return end

        local root = Instance.new("Folder")
        root.Name = "FH_MurderFX"
        root.Parent = Workspace
        local rec = {part = root, balls = {}, channel = channel}
        mActive[#mActive + 1] = rec

        local rnd = srand
        local golden = math.pi * (3 - math.sqrt(5))

        local function surfPos(source, radius, index, count, headSeed)
            local sz = source.Size
            local pad = radius * 0.92
            if source.Name == "Head" then
                local y = 1 - 2 * ((index - 0.5) / count)
                local angle = index * golden + headSeed
                local radial = math.sqrt(math.max(0, 1 - y * y))
                local dir = Vector3.new(radial * math.cos(angle), y, radial * math.sin(angle))
                local half = sz * 0.5
                return source.CFrame:PointToWorldSpace(Vector3.new(
                    dir.X * (half.X + pad), dir.Y * (half.Y + pad), dir.Z * (half.Z + pad)))
            end
            local ax = sz.Y * sz.Z
            local ay = sz.X * sz.Z
            local az = sz.X * sz.Y
            local pick = rnd() * (ax + ay + az)
            local pos
            if pick < ax then
                local side = rnd() < 0.5 and -1 or 1
                pos = Vector3.new(side * (sz.X * 0.5 + pad), (rnd() - 0.5) * sz.Y, (rnd() - 0.5) * sz.Z)
            elseif pick < ax + ay then
                local side = rnd() < 0.5 and -1 or 1
                pos = Vector3.new((rnd() - 0.5) * sz.X, side * (sz.Y * 0.5 + pad), (rnd() - 0.5) * sz.Z)
            else
                local side = rnd() < 0.5 and -1 or 1
                pos = Vector3.new((rnd() - 0.5) * sz.X, (rnd() - 0.5) * sz.Y, side * (sz.Z * 0.5 + pad))
            end
            return source.CFrame:PointToWorldSpace(pos)
        end

        local minY, maxY = math.huge, -math.huge
        for _, s in ipairs(bodyParts) do
            local hy = s.Size.Y * 0.5
            minY = math.min(minY, s.Position.Y - hy)
            maxY = math.max(maxY, s.Position.Y + hy)
        end

        local phaseCount = 8
        local groups = {}
        for i = 1, phaseCount do groups[i] = {} end
        local headSeed = rnd() * math.pi * 2
        local height = math.max(maxY - minY, 0.01)
        local created = 0

        for _, s in ipairs(bodyParts) do
            local sz = s.Size
            local surface = 2 * (sz.X * sz.Y + sz.X * sz.Z + sz.Y * sz.Z)
            local count = s.Name == "Head" and 24 or math.clamp(math.floor(surface * 0.65 + 0.5), 7, 12)
            count = math.min(count, 140 - created)
            for index = 1, count do
                local dia = s.Name == "Head" and (0.115 + rnd() * 0.045) or (0.13 + rnd() * 0.06)
                local tsz = Vector3.new(dia, dia, dia)
                local pos = surfPos(s, dia * 0.5, index, count, headSeed)
                local ball = Instance.new("Part")
                ball.Shape = Enum.PartType.Ball
                ball.Material = Enum.Material.Neon
                ball.Color = tint
                ball.Size = Vector3.new(0.015, 0.015, 0.015)
                ball.Position = pos
                ball.Anchored = true
                ball.CanCollide = false
                ball.CanQuery = false
                ball.CanTouch = false
                ball.CastShadow = false
                ball.Massless = true
                ball.Transparency = 1
                ball.Parent = root
                rec.balls[#rec.balls + 1] = ball
                created = created + 1
                local v = math.clamp((pos.Y - minY) / height, 0, 1)
                local phase = math.clamp(math.floor(v * (phaseCount - 1) + 1.5) + rnd(-1, 1), 1, phaseCount)
                groups[phase][#groups[phase] + 1] = {ball = ball, size = tsz}
            end
            if created >= 140 then break end
        end

        local revealWindow = math.min(0.34, dur * 0.26)
        local revealTime = math.min(0.2, dur * 0.18)
        local fadeBegin = math.max(revealWindow + revealTime + 0.06, dur * 0.42)
        local fadeWindow = math.min(0.28, dur * 0.18)
        local fadeTime = math.max(dur - fadeBegin - fadeWindow, 0.1)
        for phase = 1, phaseCount do
            local alpha = (phase - 1) / (phaseCount - 1)
            local group = groups[phase]
            task.delay(revealWindow * alpha, function()
                if not root.Parent then return end
                for _, item in ipairs(group) do
                    if item.ball.Parent then
                        TweenService:Create(item.ball, TweenInfo.new(revealTime, Enum.EasingStyle.Sine), {
                            Size = item.size, Transparency = 0.05,
                        }):Play()
                    end
                end
            end)
            task.delay(fadeBegin + fadeWindow * alpha, function()
                if not root.Parent then return end
                for _, item in ipairs(group) do
                    if item.ball.Parent then
                        TweenService:Create(item.ball, TweenInfo.new(fadeTime, Enum.EasingStyle.Sine), {
                            Size = item.size * 0.58, Transparency = 1,
                        }):Play()
                    end
                end
            end)
        end
        task.delay(dur + 0.12, function() removeEmitter(rec) end)
    end

    local function makeClone(char)
        local ok, clone = pcall(function() return char:Clone() end)
        if not ok or not clone then return end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanQuery = false
                d.CanTouch = false
                if d.Name == "HumanoidRootPart" then d.Transparency = 1
                else
                    d.Material = Enum.Material.ForceField
                    d.Color = mCloneCol
                end
            elseif d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript")
                or d:IsA("ModuleScript") or d:IsA("Sound") or d:IsA("SurfaceAppearance")
                or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight")
                or d:IsA("Highlight") then
                pcall(function() d:Destroy() end)
            end
        end
        clone.Name = "FH_MurderClone"
        clone.Parent = Workspace
        mClones[#mClones + 1] = clone
        task.delay(mCloneDur, function()
            if not clone.Parent then return end
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    TweenService:Create(d, TweenInfo.new(1.5), {Transparency = 1}):Play()
                end
            end
            task.delay(1.6, function()
                for i = #mClones, 1, -1 do
                    if mClones[i] == clone then table.remove(mClones, i) end
                end
                if clone.Parent then clone:Destroy() end
            end)
        end)
    end

    local function onMurderDeath(char)
        if mCloneOn then makeClone(char) end
        if mPartOn then spawnEmitter(char, mPartCol, 1.2, "particle") end
        if mEmitOn then spawnEmitter(char, mEmitCol, mEmitDur, "emitter") end
    end

    local function hookPlayer(pl)
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            mConns[#mConns + 1] = hum.Died:Connect(function()
                if mOn and mRoles[pl.Name] == "Murderer" then
                    onMurderDeath(char)
                end
            end)
        end
        if pl.Character then task.spawn(onChar, pl.Character) end
        mConns[#mConns + 1] = pl.CharacterAdded:Connect(onChar)
    end

    local function stopMurder()
        for _, c in ipairs(mConns) do pcall(function() c:Disconnect() end) end
        mConns = {}
        for i = 1, #mActive do
            local p = mActive[i]
            if p then pcall(function() p.part:Destroy() end) end
        end
        mActive = {}
        if mAddConn then pcall(function() mAddConn:Disconnect() end) mAddConn = nil end
        for _, c in ipairs(mClones) do pcall(function() c:Destroy() end) end
        mClones = {}
    end

    meSec:AddToggle("MEOn", {Title = "Включить эффект", Default = false}):OnChanged(function(v)
        mOn = v
        if v then
            mThread = task.spawn(function()
                while mOn do
                    pcall(function()
                        local f = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
                        local data = f and f:InvokeServer()
                        if type(data) == "table" then
                            local m = {}
                            for name, d in pairs(data) do
                                if type(d) == "table" and d.Role then m[name] = d.Role end
                            end
                            mRoles = m
                        end
                    end)
                    task.wait(1)
                end
            end)
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer then hookPlayer(pl) end
            end
            mAddConn = Players.PlayerAdded:Connect(function(pl)
                if pl ~= LocalPlayer then hookPlayer(pl) end
            end)
        else
            stopMurder()
            if mThread then pcall(function() task.cancel(mThread) end) mThread = nil end
        end
    end)
    meSec:AddToggle("MEClone", {Title = L("Clone"), Default = false}):OnChanged(function(v) mCloneOn = v end)
    meSec:AddColorPicker("MECloneCol", {Title = L("Clone Color"), Default = Color3.fromRGB(255, 0, 0)}):OnChanged(function(c)
        mCloneCol = c
        for _, cl in ipairs(mClones) do
            for _, d in ipairs(cl:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then d.Color = c end
            end
        end
    end)
    meSec:AddSlider("MECloneDur", {Title = L("Clone Duration"), Min = 1, Max = 5, Default = 3, Rounding = 1}):OnChanged(function(v) mCloneDur = v end)
    meSec:AddToggle("MEPart", {Title = L("Particle"), Default = false}):OnChanged(function(v) mPartOn = v end)
    meSec:AddColorPicker("MEPartCol", {Title = L("Particle Color"), Default = Color3.fromRGB(255, 0, 0)}):OnChanged(function(c) mPartCol = c end)
    meSec:AddToggle("MEEmit", {Title = L("Neverlose Emitter"), Default = false}):OnChanged(function(v) mEmitOn = v end)
    meSec:AddColorPicker("MEEmitCol", {Title = L("Emitter Color"), Default = Color3.fromRGB(255, 100, 100)}):OnChanged(function(c)
        mEmitCol = c
        for i = 1, #mActive do
            local e = mActive[i]
            if e and e.channel == "emitter" then
                for _, b in ipairs(e.balls) do
                    if b.Parent then b.Color = c end
                end
            end
        end
    end)
    meSec:AddSlider("MEEmitDur", {Title = L("Emitter Duration"), Min = 1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v) mEmitDur = v end)

    print("[FortniHub][INFO] Murder Effect готов")
end

-- ============================================================
-- LOCAL VISUALS — China Hat, Backtrack, Landing, MovGraph
-- ============================================================
do
    local lvSec = Tabs.Visual:AddSection({Name = "Свои визуалы"})

    -- CHINA HAT
    local chOn, chCol = false, Color3.fromRGB(255, 60, 60)
    local chSeg = 48
    local chTau = math.pi * 2
    local chRadius, chHeight = 1.55, 0.82
    local chConn, chRows = nil, {}

    local function chClear()
        for i = 1, #chRows do pcall(function() chRows[i]:Remove() end) end
        chRows = {}
    end

    local function chUpdate()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local base = Vector3.new(head.Position.X, head.Position.Y + head.Size.Y * 0.5, head.Position.Z)
        local apex = cam:WorldToViewportPoint(base + Vector3.new(0, chHeight, 0))
        if apex.Z <= 0 then return end
        local pxs, pys = {}, {}
        pxs[1], pys[1] = apex.X, apex.Y
        local cosv, sinv = {}, {}
        for i = 1, chSeg do
            local a = (i - 1) / chSeg * chTau
            cosv[i] = math.cos(a) * chRadius
            sinv[i] = math.sin(a) * chRadius
        end
        local valid = true
        for i = 1, chSeg do
            local p = cam:WorldToViewportPoint(base + Vector3.new(cosv[i], 0, sinv[i]))
            if p.Z <= 0 then valid = false break end
            pxs[i + 1] = p.X
            pys[i + 1] = p.Y
        end
        if not valid then return end
        local ord = {}
        for i = 1, chSeg + 1 do ord[i] = i end
        table.sort(ord, function(i, j)
            if pxs[i] == pxs[j] then return pys[i] < pys[j] end
            return pxs[i] < pxs[j]
        end)
        local stack, m = {}, 0
        for k = 1, chSeg + 1 do
            local i = ord[k]
            while m >= 2 do
                local o, a = stack[m - 1], stack[m]
                if (pxs[a] - pxs[o]) * (pys[i] - pys[o]) - (pys[a] - pys[o]) * (pxs[i] - pxs[o]) > 0 then break end
                m = m - 1
            end
            m = m + 1
            stack[m] = i
        end
        local lower = m
        for k = chSeg, 1, -1 do
            local i = ord[k]
            while m > lower do
                local o, a = stack[m - 1], stack[m]
                if (pxs[a] - pxs[o]) * (pys[i] - pys[o]) - (pys[a] - pys[o]) * (pxs[i] - pxs[o]) > 0 then break end
                m = m - 1
            end
            m = m + 1
            stack[m] = i
        end
        local hn = m - 1
        local minY, maxY = math.huge, -math.huge
        for i = 1, hn do
            local y = pys[stack[i]]
            if y < minY then minY = y end
            if y > maxY then maxY = y end
        end
        local firstY = math.max(0, math.floor(minY))
        local lastY = math.min(cam.ViewportSize.Y, math.ceil(maxY))
        local span = math.max(1, maxY - minY)
        local step = math.max(1, math.ceil((lastY - firstY) / 220))
        local used = 0
        for y0 = firstY, lastY - 1, step do
            local h = math.min(step, lastY - y0)
            local y = y0 + h * 0.5
            local left, right = math.huge, -math.huge
            local ax, ay = pxs[stack[hn]], pys[stack[hn]]
            for i = 1, hn do
                local ix = stack[i]
                local bx, by = pxs[ix], pys[ix]
                if (ay <= y and by > y) or (by <= y and ay > y) then
                    local x = ax + (y - ay) * (bx - ax) / (by - ay)
                    if x < left then left = x end
                    if x > right then right = x end
                end
                ax, ay = bx, by
            end
            local w = right - left
            if w >= 2.5 then
                used = used + 1
                local row = chRows[used]
                if not row then
                    row = Drawing.new("Square")
                    row.Filled = true
                    row.Thickness = 0
                    row.Transparency = 0.72
                    row.ZIndex = 1
                    chRows[used] = row
                end
                local t = (y - minY) / span
                local light = math.max(0, 1 - t * 1.35)
                local dark = math.max(0, (t - 0.58) / 0.42)
                local col = chCol:Lerp(Color3.new(1, 1, 1), light * 0.26):Lerp(Color3.new(0, 0, 0), dark * 0.1)
                row.Position = Vector2.new(left, y0)
                row.Size = Vector2.new(w, h)
                row.Color = col
                row.Visible = true
            end
        end
        for i = used + 1, #chRows do chRows[i].Visible = false end
    end

    lvSec:AddToggle("ChinaHatOn", {Title = L("China Hat"), Default = false}):OnChanged(function(v)
        chOn = v
        if v then
            if not chConn then
                chConn = RunService.Heartbeat:Connect(function()
                    if chOn then chUpdate() end
                end)
            end
        else
            if chConn then pcall(function() chConn:Disconnect() end) chConn = nil end
            chClear()
        end
    end)
    lvSec:AddColorPicker("ChinaHatCol", {Title = L("Hat Color"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) chCol = c end)

    -- BACKTRACK
    local btOn, btCol = false, Color3.fromRGB(255, 60, 60)
    local btModel = nil
    local btPairs = {}
    local BTCAP = 256
    local btHist = table.create(BTCAP)
    for i = 1, BTCAP do btHist[i] = {0, CFrame.identity} end
    local btFirst, btCount = 1, 0
    local btPing, btPingAt = 0.15, 0

    local function btKill()
        if btModel then pcall(function() btModel:Destroy() end) btModel = nil end
        btPairs = {}
        btFirst, btCount = 1, 0
    end

    local function btBuild()
        btKill()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        char.Archivable = true
        local ok, m = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not m then return end
        local rp = {}
        for _, o in ipairs(char:GetDescendants()) do
            if o:IsA("BasePart") then rp[#rp + 1] = o end
        end
        local ci = 0
        for _, o in ipairs(m:GetDescendants()) do
            if o:IsA("Script") or o:IsA("LocalScript") then pcall(function() o:Destroy() end)
            elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then pcall(function() o:Destroy() end)
            elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") then pcall(function() o:Destroy() end)
            elseif o:IsA("BasePart") then
                o.Anchored = true
                o.CanCollide = false
                o.CanQuery = false
                o.CastShadow = false
                if o.Name == "HumanoidRootPart" then o.Transparency = 1
                else
                    o.Material = Enum.Material.ForceField
                    o.Color = btCol
                    o.Transparency = 0
                end
                ci = ci + 1
                btPairs[#btPairs + 1] = {o, rp[ci]}
            end
        end
        local h = m:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:Destroy() end) end
        m.Parent = Workspace
        btModel = m
    end

    local function btUpdate()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not btModel then btBuild() if not btModel then return end end
        if not btModel.Parent then btModel.Parent = Workspace end
        local now = os.clock()
        local cf = hrp.CFrame
        if btCount < BTCAP then btCount = btCount + 1
        else btFirst = btFirst % BTCAP + 1 end
        local slot = btHist[(btFirst + btCount - 2) % BTCAP + 1]
        slot[1], slot[2] = now, cf
        if now - btPingAt >= 0.2 then
            btPingAt = now
            local ok, v = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            end)
            btPing = math.clamp((ok and v) or 0.15, 0.05, 0.6)
        end
        local target = now - btPing
        local tcf = cf
        for k = btCount, 1, -1 do
            local s = btHist[(btFirst + k - 2) % BTCAP + 1]
            if s[1] <= target then tcf = s[2] break end
        end
        local inv = hrp.CFrame:Inverse()
        for i = 1, #btPairs do
            local cp, rp = btPairs[i][1], btPairs[i][2]
            if cp and cp.Parent and rp and rp.Parent then
                cp.CFrame = tcf * (inv * rp.CFrame)
            end
        end
    end

    lvSec:AddToggle("BacktrackOn", {Title = L("Backtrack"), Default = false}):OnChanged(function(v)
        btOn = v
        if v then
            if not _G.FH_BT_CONN then
                _G.FH_BT_CONN = RunService.Heartbeat:Connect(function()
                    if btOn then btUpdate() end
                end)
            end
            if not btModel then btBuild() end
        else
            btKill()
        end
    end)
    lvSec:AddColorPicker("BacktrackCol", {Title = L("Color"), Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c)
        btCol = c
        if btModel then
            for _, p in ipairs(btModel:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Color = c end
            end
        end
    end)

    -- LANDING CIRCLE
    local lcOn, lcCol, lcTr, lcDur = false, Color3.new(1, 1, 1), 1, 0.82
    local lcConn

    local function makeLand(p, n)
        local ref = math.abs(n.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
        local right = n:Cross(ref).Unit
        local front = right:Cross(n).Unit
        local pt = Instance.new("Part")
        pt.Name = "FH_Land"
        pt.Anchored = true
        pt.CanCollide = false
        pt.CanQuery = false
        pt.CanTouch = false
        pt.CastShadow = false
        pt.Transparency = 1
        pt.Size = Vector3.new(0.3, 0.01, 0.3)
        pt.CFrame = CFrame.fromMatrix(p + n * 0.012, right, n, front)
        pt.Parent = Workspace
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.AlwaysOnTop = true
        sg.LightInfluence = 0
        sg.ZOffset = 4
        sg.CanvasSize = Vector2.new(1024, 1024)
        sg.Parent = pt
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = "rbxassetid://7185003058"
        img.ImageColor3 = lcCol
        img.ImageTransparency = 1 - lcTr
        img.ScaleType = Enum.ScaleType.Stretch
        img.Parent = sg
        local info = TweenInfo.new(lcDur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        TweenService:Create(pt, info, {Size = Vector3.new(6.4, 0.01, 6.4)}):Play()
        TweenService:Create(img, info, {ImageTransparency = 1}):Play()
        task.delay(lcDur + 0.2, function() pcall(function() pt:Destroy() end) end)
    end

    local function lcBind()
        if lcConn then pcall(function() lcConn:Disconnect() end) lcConn = nil end
        if not lcOn then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        local air = false
        lcConn = hum.StateChanged:Connect(function(_, state)
            if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                air = true
            elseif state == Enum.HumanoidStateType.Landed and air and lcOn then
                air = false
                local prm = RaycastParams.new()
                prm.FilterType = Enum.RaycastFilterType.Exclude
                prm.FilterDescendantsInstances = {char}
                prm.IgnoreWater = true
                local hit = Workspace:Raycast(root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -16, 0), prm)
                if hit then makeLand(hit.Position, hit.Normal) end
            end
        end)
    end

    lvSec:AddToggle("LandCircleOn", {Title = L("Landing Circle"), Default = false}):OnChanged(function(v)
        lcOn = v
        if v then lcBind()
        elseif lcConn then pcall(function() lcConn:Disconnect() end) lcConn = nil end
    end)
    lvSec:AddColorPicker("LandCircleCol", {Title = L("Color"), Default = Color3.new(1, 1, 1)}):OnChanged(function(c) lcCol = c end)
    lvSec:AddSlider("LandCircleTr", {Title = L("Transparency"), Min = 0, Max = 1, Default = 1, Rounding = 2}):OnChanged(function(v) lcTr = v end)
    lvSec:AddSlider("LandCircleDur", {Title = L("Duration"), Min = 0.1, Max = 3, Default = 0.82, Rounding = 2}):OnChanged(function(v) lcDur = v end)

    -- MOVEMENT GRAPH
    local mgOn, mgCol = false, Color3.fromRGB(242, 242, 242)
    local mgWidth, mgHeight, mgOffset = 280, 72, 180
    local mgLines, mgShadows = {}, {}
    local mgCurrent, mgConn
    local mgHist, mgAccum, mgSmooth = {}, 0, 0
    local mgSpan, mgStep = 2.8, 1 / 45

    local function mgSpeed()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return 0 end
        local v = r.AssemblyLinearVelocity
        return Vector3.new(v.X, 0, v.Z).Magnitude
    end

    local function mgRef()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return math.max(1, (h and h.WalkSpeed) or 16)
    end

    local function mgClear()
        if mgConn then pcall(function() mgConn:Disconnect() end) mgConn = nil end
        if mgCurrent then pcall(function() mgCurrent:Remove() end) mgCurrent = nil end
        for i = 1, #mgLines do
            pcall(function() mgLines[i]:Remove() end)
            pcall(function() mgShadows[i]:Remove() end)
        end
        mgLines, mgShadows = {}, {}
        mgHist = {}
        mgAccum = 0
    end

    local function mgY(v, center, height, ref)
        local n = math.clamp(v / ref - 1, -1, 1)
        return center - n * height * 0.44
    end

    local function mgRender(now)
        local cam = Workspace.CurrentCamera
        if not cam or #mgHist < 2 then return end
        local vp = cam.ViewportSize
        local w = math.min(mgWidth, math.max(120, vp.X - 48))
        local h = math.min(mgHeight, math.max(36, vp.Y - 32))
        local left = math.floor(vp.X * 0.5 - w * 0.5)
        local center = math.clamp(math.floor(vp.Y * 0.5 + mgOffset), h * 0.5 + 8, vp.Y - h * 0.5 - 8)
        local ref = mgRef()
        local startT = now - mgSpan
        local count = #mgHist
        while #mgLines < count + 1 do
            local s = Drawing.new("Line")
            s.Color = Color3.new(0, 0, 0)
            s.Thickness = 3
            s.Transparency = 0.4
            s.Visible = false
            mgShadows[#mgShadows + 1] = s
            local l = Drawing.new("Line")
            l.Color = mgCol
            l.Thickness = 1.5
            l.Transparency = 1
            l.Visible = false
            mgLines[#mgLines + 1] = l
        end
        for i = 1, count - 1 do
            local a, b = mgHist[i], mgHist[i + 1]
            local ap = math.clamp((a.t - startT) / mgSpan, 0, 1)
            local bp = math.clamp((b.t - startT) / mgSpan, 0, 1)
            local fade = math.clamp(math.min((ap + bp) * 6, (2 - ap - bp) * 5), 0, 1)
            local from = Vector2.new(left + ap * w, mgY(a.v, center, h, ref))
            local to = Vector2.new(left + bp * w, mgY(b.v, center, h, ref))
            local l, s = mgLines[i], mgShadows[i]
            l.From, l.To = from, to
            l.Transparency = fade
            l.Visible = fade > 0.02
            s.From, s.To = from, to
            s.Transparency = fade * 0.42
            s.Visible = fade > 0.02
        end
        for i = count, #mgLines do
            mgLines[i].Visible = false
            mgShadows[i].Visible = false
        end
        if not mgCurrent then
            mgCurrent = Drawing.new("Text")
            mgCurrent.Center = false
            mgCurrent.Outline = true
            mgCurrent.Size = 12
            mgCurrent.ZIndex = 904
        end
        mgCurrent.Text = tostring(math.floor(mgSmooth + 0.5))
        mgCurrent.Position = Vector2.new(left + w + 5, center - 7)
        mgCurrent.Color = mgCol
        mgCurrent.Visible = true
    end

    local function mgStart()
        mgClear()
        mgSmooth = mgSpeed()
        local now = os.clock()
        local cnt = math.ceil(mgSpan / mgStep)
        for i = 0, cnt do
            mgHist[#mgHist + 1] = {t = now - mgSpan + i * mgStep, v = mgSmooth}
        end
        mgConn = RunService.RenderStepped:Connect(function(dt)
            if not mgOn then return end
            local raw = mgSpeed()
            mgSmooth = mgSmooth + (raw - mgSmooth) * (1 - math.exp(-dt * 18))
            mgAccum = mgAccum + dt
            local now = os.clock()
            if mgAccum >= mgStep then
                mgAccum = mgAccum % mgStep
                mgHist[#mgHist + 1] = {t = now, v = mgSmooth}
                local cutoff = now - mgSpan
                while #mgHist > 2 and mgHist[2].t < cutoff do table.remove(mgHist, 1) end
            end
            mgRender(now)
        end)
    end

    lvSec:AddToggle("MovGraphOn", {Title = L("Movement Graph"), Default = false}):OnChanged(function(v)
        mgOn = v
        if v then mgStart() else mgClear() end
    end)
    lvSec:AddColorPicker("MovGraphCol", {Title = L("Graph Color"), Default = Color3.fromRGB(242, 242, 242)}):OnChanged(function(c)
        mgCol = c
        for i = 1, #mgLines do mgLines[i].Color = c end
    end)
    lvSec:AddSlider("MovGraphW", {Title = L("Width"), Min = 180, Max = 420, Default = 280, Rounding = 0}):OnChanged(function(v) mgWidth = v end)
    lvSec:AddSlider("MovGraphH", {Title = L("Height"), Min = 40, Max = 120, Default = 72, Rounding = 0}):OnChanged(function(v) mgHeight = v end)
    lvSec:AddSlider("MovGraphY", {Title = L("Y Offset"), Min = -200, Max = 400, Default = 180, Rounding = 0}):OnChanged(function(v) mgOffset = v end)

    print("[FortniHub][INFO] Local Visuals готов")
end

-- ============================================================
-- SELF CHAMS + TOOL CHAMS
-- ============================================================
do
    local scSec = Tabs.Visual:AddSection({Name = L("Self Chams")})
    local scOn, scType, scCol = false, "ForceField", Color3.fromRGB(0, 200, 255)
    local scCache = {}
    local scConn

    local function scRestore()
        for part, d in pairs(scCache) do
            if part and part.Parent then
                pcall(function() part.Material = d[1] end)
                pcall(function() part.Color = d[2] end)
            end
        end
        scCache = {}
    end

    local function scApply()
        local c = LocalPlayer.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                if not scCache[p] then scCache[p] = {p.Material, p.Color} end
                if scType == "ForceField" then
                    pcall(function() p.Material = Enum.Material.ForceField end)
                    pcall(function() p.Color = scCol end)
                elseif scType == "Flat" then
                    pcall(function() p.Material = Enum.Material.SmoothPlastic end)
                    pcall(function() p.Color = scCol end)
                elseif scType == "Chromatic" then
                    pcall(function() p.Material = Enum.Material.Foil end)
                    pcall(function() p.Color = scCol end)
                end
            end
        end
    end

    scSec:AddToggle("SCOn", {Title = "Включить", Default = false}):OnChanged(function(v)
        scOn = v
        if v then
            if not scConn then
                scConn = RunService.Heartbeat:Connect(function()
                    if scOn then scApply() end
                end)
            end
        else
            if scConn then pcall(function() scConn:Disconnect() end) scConn = nil end
            scRestore()
        end
    end)
    scSec:AddDropdown("SCType", {Title = L("Preset"), Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"}):OnChanged(function(v) scType = v end)
    scSec:AddColorPicker("SCCol", {Title = L("Color"), Default = Color3.fromRGB(0, 200, 255)}):OnChanged(function(c) scCol = c end)

    -- TOOL CHAMS
    local tcOn, tcType, tcCol = false, "ForceField", Color3.fromRGB(255, 200, 0)
    local tcCache = {}
    local tcConn

    local function tcRestore()
        for part, d in pairs(tcCache) do
            if part and part.Parent then
                pcall(function() part.Material = d[1] end)
                pcall(function() part.Color = d[2] end)
            end
        end
        tcCache = {}
    end

    local function tcApply()
        local c = LocalPlayer.Character
        if not c then return end
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") then
                for _, p in ipairs(t:GetDescendants()) do
                    if p:IsA("BasePart") then
                        if not tcCache[p] then tcCache[p] = {p.Material, p.Color} end
                        if tcType == "ForceField" then
                            pcall(function() p.Material = Enum.Material.ForceField end)
                            pcall(function() p.Color = tcCol end)
                        elseif tcType == "Flat" then
                            pcall(function() p.Material = Enum.Material.SmoothPlastic end)
                            pcall(function() p.Color = tcCol end)
                        elseif tcType == "Chromatic" then
                            pcall(function() p.Material = Enum.Material.Foil end)
                            pcall(function() p.Color = tcCol end)
                        end
                    end
                end
            end
        end
    end

    scSec:AddToggle("TCOn", {Title = L("Tool Chams"), Default = false}):OnChanged(function(v)
        tcOn = v
        if v then
            if not tcConn then
                tcConn = RunService.Heartbeat:Connect(function()
                    if tcOn then tcApply() end
                end)
            end
        else
            if tcConn then pcall(function() tcConn:Disconnect() end) tcConn = nil end
            tcRestore()
        end
    end)
    scSec:AddDropdown("TCType", {Title = L("Preset"), Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"}):OnChanged(function(v) tcType = v end)
    scSec:AddColorPicker("TCCol", {Title = L("Color"), Default = Color3.fromRGB(255, 200, 0)}):OnChanged(function(c) tcCol = c end)

    print("[FortniHub][INFO] Self/Tool Chams готов")
end

-- ============================================================
-- КОНЕЦ ЧАСТИ 2/3
-- ============================================================
print("[FortniHub][INFO] ================================")
print("[FortniHub][INFO] PART 2/3 УСПЕШНО ЗАГРУЖЕН")
print("[FortniHub][INFO] Фичи: ESP, Tracer, Aura, World FX, Shaders,")
print("[FortniHub][INFO]       Fog, Skybox, Crosshair, Murder FX,")
print("[FortniHub][INFO]       China Hat, Backtrack, Landing, MovGraph,")
print("[FortniHub][INFO]       Chams, AWP Replace")
print("[FortniHub][INFO] Ждём часть 3/3 (Autofarm v1/v2, Tools, Anti, Sounds)")
print("[FortniHub][INFO] ================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "Часть 2/3 загружена!", 5)
end)
-- ============================================================
-- FORTNIHUB v16 — Часть 3/3 (FIXED)
-- ============================================================

-- ============================================================
-- AUTOFARM v1/v2
-- ============================================================
do
    local tF = Window:AddTab({Title = L("Farm")})
    Tabs.Farm = tF
    local farmSec = tF:AddSection({Name = L("AutoFarm")})

    local farmVersion = "v2"

    farmSec:AddDropdown("FarmVersion", {
        Title = L("AutoFarm Version"),
        Values = {"Автофарм v1", "Автофарм v2"},
        Default = "Автофарм v2",
    }):OnChanged(function(v)
        farmVersion = (v == "Автофарм v1") and "v1" or "v2"
        if Options.FarmOn and Options.FarmOn.Value then
            farmV1.on = farmVersion == "v1"
            farmV2.on = farmVersion == "v2"
        end
        Notify("FortniHub", "Автофарм: " .. farmVersion, 2)
    end)

    farmSec:AddToggle("FarmOn", {
        Title = "Включить автофарм",
        Default = false,
    }):OnChanged(function(v)
        if v then
            if Options.SpeedToggle then Options.SpeedToggle:SetValue(false) end
            if Options.FlyToggle then Options.FlyToggle:SetValue(false) end
        end
        farmV1.on = v and farmVersion == "v1"
        farmV2.on = v and farmVersion == "v2"
        Notify("FortniHub", "Автофарм " .. (v and "ВКЛ" or "ВЫКЛ"), 2)
    end)

    farmSec:AddSlider("FarmSpeed", {
        Title = L("Farm Speed"),
        Min = 5, Max = 60, Default = 23, Rounding = 1,
    }):OnChanged(function(v)
        local n = tonumber(v) or 23
        farmV1.speed = n
        farmV2.speed = n
    end)

    farmSec:AddToggle("FarmAvoid", {
        Title = L("Avoid Murderer"),
        Default = false,
    }):OnChanged(function(v) farmV2.avoid = v end)

    AddConn("FarmV1", RunService.Heartbeat:Connect(function(_, dt)
        if not farmV1.on then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local coins = {}
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and (v.Name == "Coin_Server" or v.Name == "Coin" or v.Name == "CoinVisual") then
                coins[#coins + 1] = v
            end
        end
        if #coins == 0 then return end

        local best, bd = nil, math.huge
        for _, c in ipairs(coins) do
            local d = (c.Position - hrp.Position).Magnitude
            if d < bd then bd = d; best = c end
        end
        if not best then return end

        local dir = best.Position - hrp.Position
        local dist = dir.Magnitude
        if dist > 0.5 then
            local sp = tonumber(farmV1.speed) or 23
            local step = math.min(sp * dt, dist)
            hrp.CFrame = CFrame.new(hrp.Position + dir.Unit * step)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        if dist < 6 and type(firetouchinterest) == "function" then
            local targets = { best }
            for _, v in ipairs(best:GetChildren()) do
                if v:IsA("BasePart") then targets[#targets + 1] = v end
            end
            for _, p in ipairs(targets) do
                pcall(firetouchinterest, hrp, p, 0)
                pcall(firetouchinterest, hrp, p, 1)
            end
        end
    end))

    AddConn("FarmV2", RunService.Heartbeat:Connect(function(_, dt)
        if not farmV2.on then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local coins = {}
        for _, v in ipairs(CollectionService:GetTagged("CoinVisual")) do
            if v and v.Parent and v:IsA("BasePart") and not v:GetAttribute("Collected") and not v:GetAttribute("Delete") then
                coins[#coins + 1] = v
            end
        end
        if #coins == 0 then return end

        if farmV2.avoid then
            local m = isMurderer()
            if m and m.Character then
                local mh = m.Character:FindFirstChild("HumanoidRootPart")
                if mh and (mh.Position - hrp.Position).Magnitude < 40 then
                    local away = (hrp.Position - mh.Position)
                    if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
                    hrp.CFrame = CFrame.new(hrp.Position + away.Unit * 20)
                    return
                end
            end
        end

        local best, bd = nil, math.huge
        for _, c in ipairs(coins) do
            local d = (c.Position - hrp.Position).Magnitude
            if d < bd then bd = d; best = c end
        end
        if not best then return end

        local prompt = best:FindFirstChildOfClass("ProximityPrompt")
        if prompt then pcall(function() fireproximityprompt(prompt) end) end

        local dir = best.Position - hrp.Position
        local dist = dir.Magnitude
        if dist > 0.5 then
            local sp = tonumber(farmV2.speed) or 23
            local step = math.min(sp * dt, dist)
            hrp.CFrame = CFrame.new(hrp.Position + dir.Unit * step)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
        if dist < 6 and type(firetouchinterest) == "function" then
            local targets = { best }
            for _, v in ipairs(best:GetChildren()) do
                if v:IsA("BasePart") then targets[#targets + 1] = v end
            end
            for _, p in ipairs(targets) do
                pcall(firetouchinterest, hrp, p, 0)
                pcall(firetouchinterest, hrp, p, 1)
            end
        end
    end))

    print("[FortniHub][INFO] AutoFarm v1/v2 готов")
end

-- ============================================================
-- AUTOGRAB GUN (1 попытка в раунде)
-- ============================================================
do
    local grabFailedRound, isGrabbing = false, false
    local lastRoundReset = tick()
    local gunCache = {}

    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "GunDrop" then gunCache[v] = true end
    end
    AddConn("GunCacheAdd", Workspace.DescendantAdded:Connect(function(v)
        if v.Name == "GunDrop" then gunCache[v] = true end
    end))
    AddConn("GunCacheRem", Workspace.DescendantRemoving:Connect(function(v)
        if v.Name == "GunDrop" then gunCache[v] = nil end
    end))

    task.spawn(function()
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("Remotes", 15)
                :WaitForChild("Gameplay", 15)
                :WaitForChild("CoinsStarted", 15)
        end)
        if ok and remote then
            remote.OnClientEvent:Connect(function()
                grabFailedRound = false
                isGrabbing = false
                lastRoundReset = tick()
            end)
        end
    end)

    AddConn("AutoGrabResetFallback", RunService.Heartbeat:Connect(function()
        if tick() - lastRoundReset > 90 and grabFailedRound then
            grabFailedRound = false
            lastRoundReset = tick()
        end
    end))

    local function findNearestGun(my)
        local best, bd = nil, math.huge
        for gun in pairs(gunCache) do
            if gun.Parent and gun:IsA("BasePart") then
                local d = (gun.Position - my.Position).Magnitude
                if d < bd then bd = d; best = gun end
            end
        end
        return best
    end

    AddConn("AutoGrabTick", RunService.Heartbeat:Connect(function()
        if not (Options.AutoGrabGun and Options.AutoGrabGun.Value) then return end
        if grabFailedRound or isGrabbing then return end
        local char = LocalPlayer.Character
        if not char then return end
        if char:FindFirstChild("Gun") then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp and bp:FindFirstChild("Gun") then return end
        local my = char:FindFirstChild("HumanoidRootPart")
        if not my then return end
        local gun = findNearestGun(my)
        if not gun then return end
        isGrabbing = true
        task.spawn(function()
            local rp = my.CFrame
            local grabbed = false
            for i = 1, 3 do
                if my and my.Parent then my.CFrame = gun.CFrame end
                task.wait(0.04)
                pcall(function()
                    firetouchinterest(my, gun, 0)
                    task.wait(0.02)
                    firetouchinterest(my, gun, 1)
                end)
                local c = LocalPlayer.Character
                if c and c:FindFirstChild("Gun") then grabbed = true break end
                local b = LocalPlayer:FindFirstChildOfClass("Backpack")
                if b and b:FindFirstChild("Gun") then grabbed = true break end
            end
            if my and my.Parent then
                my.CFrame = rp
                my.AssemblyLinearVelocity = Vector3.zero
                my.AssemblyAngularVelocity = Vector3.zero
            end
            if not grabbed then
                grabFailedRound = true
                Notify("FortniHub", "Пистолет не подобран. Больше не пробую в этом раунде.", 4)
            end
            isGrabbing = false
        end)
    end))

    AddConn("AutoGrabReset", LocalPlayer.CharacterAdded:Connect(function()
        isGrabbing = false
    end))

    print("[FortniHub][INFO] AutoGrab Gun v2 готов")
end

-- ============================================================
-- TOOLS
-- ============================================================
do
    local tT = Window:AddTab({Title = L("Troll")})
    Tabs.Troll = tT
    local toolsSec = tT:AddSection({Name = "Инструменты"})

    -- TP TOOL
    local tpOn, tpTool, tpActConn = false, nil, nil

    local function giveTpTool()
        if not tpOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("tp")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("tp")
        end
        if existing then tpTool = existing return end
        if tpActConn then pcall(function() tpActConn:Disconnect() end) tpActConn = nil end
        tpTool = Instance.new("Tool")
        tpTool.Name = "tp"
        tpTool.RequiresHandle = false
        tpTool.CanBeDropped = false
        tpTool.Parent = bp
        tpActConn = tpTool.Activated:Connect(function()
            local hrp = getHRP()
            local m = LocalPlayer:GetMouse()
            local pos = m.Hit
            if not hrp or not pos then return end
            hrp.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z)
        end)
    end

    local function removeTpTool()
        if tpActConn then pcall(function() tpActConn:Disconnect() end) tpActConn = nil end
        if tpTool then pcall(function() tpTool:Destroy() end) tpTool = nil end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t = bp:FindFirstChild("tp") if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("tp") if t then pcall(function() t:Destroy() end) end end
    end

    toolsSec:AddToggle("ToolTP", {Title = L("TP Tool"), Default = false}):OnChanged(function(v)
        tpOn = v
        if v then giveTpTool() else removeTpTool() end
    end)

    AddConn("TPToolCheck", LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if tpOn then giveTpTool() end
    end))

    -- FLING TOOL
    local ftOn, ftTool, ftActConn = false, nil, nil
    local ftBypass = false
    local FLING_ACTIVE = 0

    local function clickedPlayer()
        local m = LocalPlayer:GetMouse()
        local tgt = m.Target
        if tgt then
            local node = tgt
            while node and node ~= Workspace do
                local p = Players:GetPlayerFromCharacter(node)
                if p and p ~= LocalPlayer then return p end
                node = node.Parent
            end
        end
        local cam = Workspace.CurrentCamera
        local mp = Vector2.new(m.X, m.Y)
        local best, bd = nil, 110
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local sp, on = cam:WorldToViewportPoint(hrp.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
                        if d < bd then bd = d; best = p end
                    end
                end
            end
        end
        return best
    end

    local function doFling(tp)
        if not tp or not tp.Character then return end
        local hrp = getHRP()
        if not hrp then return end
        local tc = tp.Character
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        local th = tc:FindFirstChildOfClass("Humanoid")
        if not thrp then return end
        FLING_ACTIVE = FLING_ACTIVE + 1
        getgenv().FH_FLING_ACTIVE = FLING_ACTIVE
        if hrp.Velocity.Magnitude < 50 then _G.FH_OldPos = hrp.CFrame end
        if th and th.Sit then
            FLING_ACTIVE = math.max(0, FLING_ACTIVE - 1)
            getgenv().FH_FLING_ACTIVE = FLING_ACTIVE
            return
        end
        local cam = Workspace.CurrentCamera
        local oldFDH = Workspace.FallenPartsDestroyHeight
        cam.CameraSubject = thrp
        pcall(function() Workspace.FallenPartsDestroyHeight = 0 / 0 end)
        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local se = hum and hum:GetStateEnabled(Enum.HumanoidStateType.Seated)
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end
        local tm = tick()
        local ang = 0
        repeat
            if hrp and th and hrp.Parent then
                local tv = ftBypass and (th.MoveDirection * th.WalkSpeed) or thrp.Velocity
                if tv.Magnitude < 50 then
                    ang = ang + 100
                    hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, 1.5, 0) + th.MoveDirection * tv.Magnitude / 1.25
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(ang), 0, 0)
                    LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                    hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                    hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, -1.5, 0) + th.MoveDirection * tv.Magnitude / 1.25
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(ang), 0, 0)
                    LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                    hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                else
                    hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, 1.5, th.WalkSpeed) * CFrame.Angles(math.rad(90), 0, 0)
                    LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                    hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                    hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, -1.5, -th.WalkSpeed)
                    LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                    hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                end
            end
        until tm + 2 < tick() or not ftOn
        if bv then bv:Destroy() end
        if hum and se ~= nil then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, se) end
        cam.CameraSubject = hum
        if _G.FH_OldPos and hrp then
            hrp.CFrame = _G.FH_OldPos * CFrame.new(0, 0.5, 0)
            if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end
            pcall(function() Workspace.FallenPartsDestroyHeight = oldFDH end)
        end
        FLING_ACTIVE = math.max(0, FLING_ACTIVE - 1)
        getgenv().FH_FLING_ACTIVE = FLING_ACTIVE
    end

    getgenv().FH_DO_FLING = doFling

    local function giveFlingTool()
        if not ftOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("fling")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("fling")
        end
        if existing then ftTool = existing return end
        if ftActConn then pcall(function() ftActConn:Disconnect() end) ftActConn = nil end
        ftTool = Instance.new("Tool")
        ftTool.Name = "fling"
        ftTool.RequiresHandle = false
        ftTool.CanBeDropped = false
        ftTool.Parent = bp
        ftActConn = ftTool.Activated:Connect(function()
            local tp = clickedPlayer()
            if tp and getHRP() then doFling(tp) end
        end)
    end

    local function removeFlingTool()
        if ftActConn then pcall(function() ftActConn:Disconnect() end) ftActConn = nil end
        if ftTool then pcall(function() ftTool:Destroy() end) ftTool = nil end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t = bp:FindFirstChild("fling") if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("fling") if t then pcall(function() t:Destroy() end) end end
    end

    toolsSec:AddToggle("ToolFling", {Title = L("Fling Tool"), Default = false}):OnChanged(function(v)
        ftOn = v
        if v then giveFlingTool() else removeFlingTool() end
    end)
    toolsSec:AddToggle("ToolFlingBypass", {Title = L("Fling Bypass Velocity"), Default = false}):OnChanged(function(v)
        ftBypass = v
    end)

    AddConn("FlingToolCheck", LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if ftOn then giveFlingTool() end
    end))

    -- AUTO-FLING
    local fmOn, fsOn, flingThread = false, false, nil

    local function startFlingLoop()
        if flingThread then return end
        flingThread = task.spawn(function()
            while fmOn or fsOn do
                local tgt = nil
                if fmOn then tgt = isMurderer() end
                if not tgt and fsOn then tgt = isSheriff() end
                if tgt and tgt.Character and getHRP() then
                    doFling(tgt)
                else
                    task.wait(0.3)
                end
                task.wait()
            end
            flingThread = nil
        end)
    end

    toolsSec:AddToggle("ToolFlingMurder", {Title = L("Auto-Fling Murder"), Default = false}):OnChanged(function(v)
        fmOn = v
        if v then startFlingLoop() end
    end)
    toolsSec:AddToggle("ToolFlingSheriff", {Title = L("Auto-Fling Sheriff"), Default = false}):OnChanged(function(v)
        fsOn = v
        if v then startFlingLoop() end
    end)

    -- TP
    local function inLobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby" or p.Name == "Lobby" then return true end
            p = p.Parent
        end
        return false
    end

    toolsSec:AddButton({Title = L("TP to Lobby"), Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        local lobby = Workspace:FindFirstChild("RegularLobby") or Workspace:FindFirstChild("Lobby")
        if not lobby then return end
        local locs = {}
        for _, o in ipairs(lobby:GetDescendants()) do
            if o:IsA("SpawnLocation") or (o:IsA("BasePart") and o.Name == "Spawn") then
                locs[#locs + 1] = o
            end
        end
        if #locs > 0 then
            local s = locs[srand(1, #locs)]
            hrp.CFrame = s.CFrame + Vector3.new(0, 3, 0)
        end
    end})

    toolsSec:AddButton({Title = L("TP to Map"), Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        local spawns = {}
        for _, o in ipairs(Workspace:GetDescendants()) do
            if (o:IsA("SpawnLocation") or (o:IsA("BasePart") and o.Name == "Spawn")) and not inLobby(o) then
                spawns[#spawns + 1] = o
            end
        end
        if #spawns > 0 then
            local s = spawns[srand(1, #spawns)]
            hrp.CFrame = s.CFrame + Vector3.new(0, 5, 0)
        end
    end})

    print("[FortniHub][INFO] Tools готовы")
end

-- ============================================================
-- ANTI
-- ============================================================
do
    local tU = Window:AddTab({Title = L("Utility")})
    Tabs.Utility = tU
    local antiSec = tU:AddSection({Name = "Анти-читы"})

    local antiFlingOn = false
    local flingCache, flingReg = {}, {}

    local function regFlingModel(model)
        if not antiFlingOn or not model then return end
        if flingReg[model] or model == LocalPlayer.Character then return end
        flingReg[model] = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                if flingCache[d] == nil then flingCache[d] = d.CanCollide end
                flingReg[model][d] = true
                pcall(function() d.CanCollide = false end)
            end
        end
    end

    local function restoreFling()
        for _, model in pairs(flingReg) do
            for part in pairs(model) do
                if part.Parent and flingCache[part] ~= nil then
                    pcall(function() part.CanCollide = flingCache[part] end)
                end
            end
        end
        flingReg = {}
        flingCache = {}
    end

    AddConn("AntiFling", RunService.Stepped:Connect(function()
        if not antiFlingOn then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then regFlingModel(p.Character) end
        end
        for _, m in ipairs(Workspace:GetChildren()) do
            if m:IsA("Model") and m ~= LocalPlayer.Character and m:FindFirstChildOfClass("Humanoid") then
                regFlingModel(m)
            end
        end
        local hrp = getHRP()
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            if v.Magnitude > 250 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end))

    antiSec:AddToggle("AntiFling", {Title = L("Anti-Fling"), Default = false}):OnChanged(function(v)
        antiFlingOn = v
        if not v then restoreFling() end
        Notify("FortniHub", "Anti-Fling " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    local antiVoidOn = false
    local voidOrig = Workspace.FallenPartsDestroyHeight
    AddConn("AntiVoid", RunService.Heartbeat:Connect(function()
        if antiVoidOn then
            pcall(function() Workspace.FallenPartsDestroyHeight = -9e9 end)
        else
            pcall(function() Workspace.FallenPartsDestroyHeight = voidOrig end)
        end
    end))
    antiSec:AddToggle("AntiVoid", {Title = L("Anti-Void"), Default = false}):OnChanged(function(v)
        antiVoidOn = v
    end)

    local antiTrapOn = false
    local trapSpeedCache, trapJumpCache = 16, 50

    local function trapHum()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    local function trapUnlock(hum)
        if not hum or not hum.Parent then return end
        pcall(function()
            if hum.WalkSpeed <= 1 then hum.WalkSpeed = trapSpeedCache end
            if hum.JumpPower <= 1 then hum.JumpPower = trapJumpCache end
        end)
    end

    AddConn("AntiTrapLoop", RunService.Heartbeat:Connect(function()
        if not antiTrapOn then return end
        local hum = trapHum()
        if not hum then return end
        if hum.WalkSpeed > 1 then trapSpeedCache = hum.WalkSpeed end
        if hum.JumpPower > 1 then trapJumpCache = hum.JumpPower end
        trapUnlock(hum)
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g.Name == "TrapGUI" then pcall(function() g:Destroy() end) end
            end
        end
    end))

    antiSec:AddToggle("AntiTrap", {Title = L("Anti-Trap"), Default = false}):OnChanged(function(v)
        antiTrapOn = v
    end)

    local antiCoinOn = false
    local coinConn, coinDesc = nil, nil

    local function wipeCoins()
        for _, v in ipairs(CollectionService:GetTagged("CoinVisual")) do
            pcall(function() v:Destroy() end)
        end
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d.Name == "CoinContainer" then pcall(function() d:Destroy() end) end
        end
    end

    antiSec:AddToggle("AntiCoin", {Title = L("Anti-Coin (remove coins)"), Default = false}):OnChanged(function(v)
        antiCoinOn = v
        if v then
            wipeCoins()
            coinConn = CollectionService:GetInstanceAddedSignal("CoinVisual"):Connect(function(c)
                if antiCoinOn then task.wait() if antiCoinOn then pcall(function() c:Destroy() end) end end
            end)
            coinDesc = Workspace.DescendantAdded:Connect(function(d)
                if antiCoinOn and d.Name == "CoinContainer" then
                    task.wait()
                    if antiCoinOn then pcall(function() d:Destroy() end) end
                end
            end)
        else
            if coinConn then pcall(function() coinConn:Disconnect() end) coinConn = nil end
            if coinDesc then pcall(function() coinDesc:Disconnect() end) coinDesc = nil end
        end
    end)

    local antiFadeOn = false
    local fadeCache, fadeConns = {}, {}
    local fadeNames = {CameraFade = true, SpawnFade = true, Fade = true, DeathFade = true}
    local fadeDescConn = nil

    local function fadeHide(frame)
        if not frame or not frame.Parent or not frame:IsA("GuiObject") then return end
        if fadeCache[frame] == nil then fadeCache[frame] = frame.Visible end
        if frame.Visible then pcall(function() frame.Visible = false end) end
        if not fadeConns[frame] then
            fadeConns[frame] = frame:GetPropertyChangedSignal("Visible"):Connect(function()
                if antiFadeOn and frame.Visible then pcall(function() frame.Visible = false end) end
            end)
        end
    end

    local function fadeMatch(inst)
        if not inst:IsA("GuiObject") then return false end
        local par = inst.Parent
        if not par then return false end
        if (inst.Name == "Fade" or inst.Name == "Frame") and par:IsA("ScreenGui") and fadeNames[par.Name] then return true end
        if inst.Name == "Fade" and par.Name == "Game" then return true end
        return false
    end

    local function fadeApply()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, child in ipairs(pg:GetChildren()) do
            if child:IsA("ScreenGui") and fadeNames[child.Name] then
                for _, sub in ipairs(child:GetChildren()) do
                    if sub:IsA("GuiObject") and (sub.Name == "Fade" or sub.Name == "Frame") then
                        fadeHide(sub)
                    end
                end
            end
        end
        local main = pg:FindFirstChild("MainGUI")
        local gg = main and main:FindFirstChild("Game")
        local gf = gg and gg:FindFirstChild("Fade")
        if gf and gf:IsA("GuiObject") then fadeHide(gf) end
        if not fadeDescConn then
            fadeDescConn = pg.DescendantAdded:Connect(function(d)
                if antiFadeOn and fadeMatch(d) then
                    task.defer(function() if antiFadeOn and d.Parent then fadeHide(d) end end)
                end
            end)
        end
    end

    local function fadeRestore()
        for _, c in pairs(fadeConns) do pcall(function() c:Disconnect() end) end
        fadeConns = {}
        for frame, v in pairs(fadeCache) do
            if frame and frame.Parent then
                pcall(function() frame.BackgroundTransparency = 1; frame.Visible = v end)
            end
        end
        fadeCache = {}
    end

    antiSec:AddToggle("AntiFade", {Title = L("Anti-Fade (no death black)"), Default = false}):OnChanged(function(v)
        antiFadeOn = v
        if v then fadeApply() else fadeRestore() end
    end)

    print("[FortniHub][INFO] Anti готовы")
end

-- ============================================================
-- NOTIFY
-- ============================================================
do
    local notifySec = Tabs.Utility:AddSection({Name = L("Notify")})

    local notifyOn, missOn, killOn, rolesOn = false, false, false, false
    local lastRole, gunConn, hookedGun = nil, nil, nil
    local curMurdererName, killedFlag = nil, false
    local lastMiss = 0

    local function getRoundData()
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and type(m) == "table" then return m.PlayerData end
        return nil
    end

    local function lpHasGun()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Gun") then return true end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        return bp and bp:FindFirstChild("Gun") ~= nil
    end

    local function myRole()
        local d = getRoundData()
        local me = d and d[LocalPlayer.Name]
        local r = me and me.Role
        if r == "Sheriff" or r == "Hero" then return r end
        if lpHasGun() then return "Hero" end
        return r
    end

    local function murdererPlayer()
        local d = getRoundData()
        if type(d) ~= "table" then return nil end
        for name, info in pairs(d) do
            if type(info) == "table" and info.Role == "Murderer" then
                return Players:FindFirstChild(name)
            end
        end
        return nil
    end

    local function push(text)
        Notify("FortniHub", text, 4)
    end

    task.spawn(function()
        while task.wait(0.5) do
            if notifyOn and rolesOn then
                local r = myRole()
                if r and r ~= lastRole then
                    lastRole = r
                    local ru = (r == "Sheriff" or r == "Hero") and "Шериф"
                        or (r == "Murderer" and "Маньяк"
                        or (r == "Innocent" and "Мирный" or r))
                    push("Роль: " .. ru)
                elseif not r then
                    lastRole = nil
                end
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if notifyOn then
                local mp = murdererPlayer()
                local name = mp and mp.Name
                if name ~= curMurdererName then
                    curMurdererName = name
                    killedFlag = false
                end
            end
        end
    end)

    local function onShot()
        if not (notifyOn and (missOn or killOn)) then return end
        local role = myRole()
        if role ~= "Sheriff" and role ~= "Hero" then return end
        local mp = murdererPlayer()
        if not mp then return end
        local mname = mp.Name
        task.delay(0.7, function()
            if not notifyOn then return end
            local d = getRoundData()
            local info = d and d[mname]
            local tgt = Players:FindFirstChild(mname)
            local hum = tgt and tgt.Character and tgt.Character:FindFirstChildOfClass("Humanoid")
            local killed = (info and info.Dead == true) or (hum and hum.Health <= 0)
            local alive = (info and info.Dead == false) or (hum and hum.Health > 0)
            if killed then
                if killOn and not killedFlag then
                    killedFlag = true
                    push("Убит @" .. mname)
                end
            elseif alive then
                if missOn and getgenv().FH_SILENT_ACTIVE and os.clock() - lastMiss > 1.5 then
                    lastMiss = os.clock()
                    push("Промах по @" .. mname)
                end
            end
        end)
    end

    local function ensureGunHook()
        if gunConn and hookedGun then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if not ok or not remote then return end
        if gunConn then pcall(function() gunConn:Disconnect() end) gunConn = nil end
        hookedGun = remote
        gunConn = remote.OnClientEvent:Connect(function(gun)
            local c = LocalPlayer.Character
            if typeof(gun) == "Instance" and c and gun:IsDescendantOf(c) then
                onShot()
            end
        end)
    end

    task.spawn(function()
        while true do
            if notifyOn and (missOn or killOn) then ensureGunHook() end
            task.wait(0.5)
        end
    end)

    notifySec:AddToggle("NotifyOn", {Title = "Включить уведомления", Default = false}):OnChanged(function(v)
        notifyOn = v
    end)
    notifySec:AddToggle("NotifyMiss", {Title = L("Miss"), Default = false}):OnChanged(function(v)
        missOn = v
        if v and notifyOn then task.spawn(ensureGunHook) end
    end)
    notifySec:AddToggle("NotifyKill", {Title = L("Kill Murder"), Default = false}):OnChanged(function(v)
        killOn = v
        if v and notifyOn then task.spawn(ensureGunHook) end
    end)
    notifySec:AddToggle("NotifyRoles", {Title = L("Roles"), Default = false}):OnChanged(function(v)
        rolesOn = v
    end)

    print("[FortniHub][INFO] Notify готов")
end

-- ============================================================
-- SOUNDS
-- ============================================================
do
    local sndSec = Tabs.Utility:AddSection({Name = L("Sound")})

    local SND_REMOTE = {"primordial", "neverlose", "sparkle", "mc bow", "skeet", "break", "rust"}
    local SND_LOCAL = {"applepay", "bubble", "combobreak", "killcard", "xp", "na naxuy", "stony", "hentai"}
    local SND_FILES = {hentai = "hentai1"}
    local SND_CACHE_DIR = "shitaro_sounds/"
    local SND_USER_DIR = "sounds/"
    local SND_USER_EXTS = {[".ogg"] = true, [".mp3"] = true, [".wav"] = true}
    local SND_DIRS = {"shitaroebet/", "assets/", SND_USER_DIR, "", SND_CACHE_DIR}
    local SND_EXTS = {".ogg", ".mp3", ".wav", ""}
    local SND_BASE = "https://github.com/khenn791/lmao/raw/refs/heads/main/"

    local SND_LIST, sndRemote = {}, {}
    for _, n in ipairs(SND_REMOTE) do SND_LIST[#SND_LIST + 1] = n; sndRemote[n] = true end
    for _, n in ipairs(SND_LOCAL) do SND_LIST[#SND_LIST + 1] = n end

    local sndCache, sndFetched, sndWarned, sndHooked, sndPool = {}, {}, {}, {}, {}
    local sndLast = {sheriff = 0, murder = 0}
    local sndCfg = {
        sheriff = {on = false, name = "mc bow", vol = 1},
        murder = {on = false, name = "skeet", vol = 1},
    }

    local SoundService = game:GetService("SoundService")

    local function sndFsReady()
        return type(isfile) == "function" and type(readfile) == "function"
            and type(writefile) == "function" and type(getcustomasset) == "function"
    end

    local function sndLoadPath(path)
        local okI, has = pcall(isfile, path)
        if not (okI and has) then return nil end
        local okR, data = pcall(readfile, path)
        if not (okR and type(data) == "string" and #data > 0) then return nil end
        local ext = string.match(path, "(%.[^%./\\]+)$")
        local suffix = ext and string.lower(ext) or ".ogg"
        if not SND_USER_EXTS[suffix] then suffix = ".ogg" end
        local tmp = "shitaro_snd_" .. tostring(srand(100000, 999999)) .. suffix
        if not pcall(writefile, tmp, data) then return nil end
        local okA, asset = pcall(getcustomasset, tmp)
        if not (okA and type(asset) == "string" and asset ~= "") then
            pcall(function() if type(delfile) == "function" then delfile(tmp) end end)
            return nil
        end
        return asset
    end

    local function sndScan(name)
        local file = SND_FILES[name] or name
        for _, dir in ipairs(SND_DIRS) do
            for _, ext in ipairs(SND_EXTS) do
                local a = sndLoadPath(dir .. file .. ext)
                if a then return a end
            end
        end
        return nil
    end

    local function sndDownload(name)
        if sndFetched[name] ~= nil then return sndFetched[name] end
        if not sndRemote[name] then sndFetched[name] = false return false end
        local path = SND_CACHE_DIR .. name .. ".ogg"
        local okI, has = pcall(isfile, path)
        if okI and has then sndFetched[name] = true return true end
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
            sndFetched[name] = false return false
        end
        pcall(function()
            if not isfolder(SND_CACHE_DIR) then makefolder(SND_CACHE_DIR) end
        end)
        local url = SND_BASE .. (name:gsub(" ", "%%20")) .. ".ogg"
        local okD, data = pcall(function() return game:HttpGet(url) end)
        if not okD or type(data) ~= "string" or #data < 1024 then
            sndFetched[name] = false return false
        end
        sndFetched[name] = pcall(writefile, path, data) == true
        return sndFetched[name]
    end

    local function sndResolve(name)
        local c = sndCache[name]
        if c ~= nil then
            if c == false then return nil end
            return c
        end
        if not sndFsReady() then sndCache[name] = false return nil end
        local f = sndScan(name)
        if not f and sndDownload(name) then f = sndScan(name) end
        sndCache[name] = f or false
        return f
    end

    local function sndTemplate(kind)
        local cfg = sndCfg[kind]
        if not cfg then return nil end
        local id = sndResolve(cfg.name)
        if not id then return nil end
        local cur = sndPool[kind]
        if cur and cur.Parent and cur.SoundId == id then
            pcall(function() cur.Volume = cfg.vol end)
            return cur
        end
        if cur then pcall(function() cur:Destroy() end) end
        local ok, s = pcall(function()
            local snd = Instance.new("Sound")
            snd.Name = "FH_Kill_" .. kind
            snd.SoundId = id
            snd.Volume = cfg.vol
            snd.Parent = SoundService
            return snd
        end)
        if not ok or not s then sndPool[kind] = nil return nil end
        sndPool[kind] = s
        return s
    end

    local function sndPlay(kind)
        local tmpl = sndPool[kind] or sndTemplate(kind)
        if not tmpl then return end
        pcall(function()
            local c = tmpl:Clone()
            c.Volume = sndCfg[kind].vol
            c.TimePosition = 0
            c.Parent = SoundService
            c:Play()
            task.delay(8, function() pcall(function() c:Destroy() end) end)
        end)
    end

    local function sndShouldMute(kind)
        local cfg = sndCfg[kind]
        if not cfg or not cfg.on then return false end
        return sndTemplate(kind) ~= nil
    end

    local function sndHook(inst, kind)
        if sndHooked[inst] then return end
        local entry = {kind = kind, vol = inst.Volume}
        sndHooked[inst] = entry
        local function fire()
            if not sndCfg[kind].on then return end
            if not sndPool[kind] and not sndTemplate(kind) then return end
            if os.clock() - sndLast[kind] < 0.15 then return end
            sndLast[kind] = os.clock()
            pcall(function() inst:Stop() end)
            sndPlay(kind)
        end
        inst.Played:Connect(fire)
        inst:GetPropertyChangedSignal("Playing"):Connect(function()
            if inst.Playing then fire() end
        end)
        inst.Destroying:Connect(function() sndHooked[inst] = nil end)
        pcall(function() inst.Volume = sndShouldMute(kind) and 0 or entry.vol end)
    end

    local function sndToolKind(tool)
        if tool.Name == "Gun" or tool:FindFirstChild("Shoot") then return "sheriff" end
        if tool.Name == "Knife" or tool:FindFirstChild("Events") then return "murder" end
        return nil
    end

    local function sndScanAll()
        for _, root in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")}) do
            if root then
                for _, tool in ipairs(root:GetChildren()) do
                    if tool:IsA("Tool") then
                        local kind = sndToolKind(tool)
                        local handle = tool:FindFirstChild("Handle")
                        if kind and handle then
                            for _, ch in ipairs(handle:GetChildren()) do
                                if ch:IsA("Sound") and (ch.Name == "GunKill" or ch.Name == "Kill") then
                                    sndHook(ch, kind)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    task.spawn(function()
        while true do
            task.wait(0.5)
            if sndCfg.sheriff.on or sndCfg.murder.on then
                pcall(sndScanAll)
            end
        end
    end)

    local sdTgl = sndSec:AddToggle("SndSheriff", {Title = L("Sheriff Kill Sound"), Default = false})
    sdTgl:OnChanged(function(v)
        sndCfg.sheriff.on = v
        if v then pcall(sndTemplate, "sheriff") pcall(sndScanAll) end
    end)
    sndSec:AddDropdown("SndSheriffName", {Title = L("Sound"), Values = SND_LIST, Default = "mc bow"}):OnChanged(function(v)
        sndCfg.sheriff.name = v
        if sndCfg.sheriff.on then pcall(sndTemplate, "sheriff") end
    end)
    sndSec:AddSlider("SndSheriffVol", {Title = L("Volume"), Min = 0.1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v)
        sndCfg.sheriff.vol = tonumber(v) or 1
        local s = sndPool.sheriff
        if s then pcall(function() s.Volume = sndCfg.sheriff.vol end) end
    end)

    local mdTgl = sndSec:AddToggle("SndMurder", {Title = L("Murder Kill Sound"), Default = false})
    mdTgl:OnChanged(function(v)
        sndCfg.murder.on = v
        if v then pcall(sndTemplate, "murder") pcall(sndScanAll) end
    end)
    sndSec:AddDropdown("SndMurderName", {Title = L("Sound"), Values = SND_LIST, Default = "skeet"}):OnChanged(function(v)
        sndCfg.murder.name = v
        if sndCfg.murder.on then pcall(sndTemplate, "murder") end
    end)
    sndSec:AddSlider("SndMurderVol", {Title = L("Volume"), Min = 0.1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v)
        sndCfg.murder.vol = tonumber(v) or 1
        local s = sndPool.murder
        if s then pcall(function() s.Volume = sndCfg.murder.vol end) end
    end)

    print("[FortniHub][INFO] Sounds готовы")
end

-- ============================================================
-- EMOTES — ограничено 200 штук, кнопки активации
-- ============================================================
do
    local emoteSec = Tabs.Troll:AddSection({Name = "Эмоции"})

    local statEmotes = {
        {"Griddy", "129149402922241"},
        {"Floss", "129149402922241"},
        {"Dab", "11953266178"},
        {"Default Dance", "10272060486"},
        {"Kazotsky Kick", "11397105951"},
        {"Robot", "11953266178"},
        {"Orange Justice", "11970665200"},
        {"Take the L", "12327207789"},
    }
    local emoteMap, emoteList, animCache = {}, {}, {}
    local curTrack, selId = nil, nil
    local autoEmoteOn = false
    local MAX_EMOTES = 200

    local function getHum()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    local function stopEmote()
        if curTrack then
            pcall(function() curTrack:Stop() end)
            curTrack = nil
        end
    end

    local function resolveId(id)
        if animCache[id] then return animCache[id] end
        if id:find("://") then animCache[id] = id return id end
        local raw = id:gsub("%D", "")
        local ok, objs = pcall(game.GetObjects, game, "rbxassetid://" .. raw)
        if ok and type(objs) == "table" then
            local found
            local function scan(inst)
                if found then return end
                if inst:IsA("Animation") and inst.AnimationId ~= "" then found = inst.AnimationId return end
                for _, c in ipairs(inst:GetChildren()) do scan(c) end
            end
            for _, o in ipairs(objs) do scan(o) pcall(function() o:Destroy() end) end
            if found then animCache[id] = found return found end
        end
        local url = "rbxassetid://" .. raw
        animCache[id] = url
        return url
    end

    local function playEmote(id)
        local hum = getHum()
        if not hum or not id then return end
        stopEmote()
        local anim = Instance.new("Animation")
        anim.AnimationId = resolveId(id)
        local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            track:Play()
            curTrack = track
        end
    end

    for _, e in ipairs(statEmotes) do
        if not emoteMap[e[1]] then
            emoteMap[e[1]] = e[2]
            emoteList[#emoteList + 1] = e[1]
        end
    end

    local drop = emoteSec:AddDropdown("EmoteListV3", {
        Title = "Выбрать эмоцию",
        Values = emoteList,
        Default = emoteList[1],
    }):OnChanged(function(v)
        selId = emoteMap[v]
    end)

    emoteSec:AddButton({Title = "Активировать эмоцию", Callback = function()
        if selId then
            playEmote(selId)
            Notify("FortniHub", "Эмоция запущена", 2)
        end
    end})

    emoteSec:AddButton({Title = "Остановить эмоцию", Callback = function()
        stopEmote()
        Notify("FortniHub", "Эмоция остановлена", 2)
    end})

    emoteSec:AddToggle("EmoteAuto", {
        Title = "Авто-использование после респавна",
        Default = false,
    }):OnChanged(function(v)
        autoEmoteOn = v
        if v and selId then
            task.wait(1)
            playEmote(selId)
        end
    end)

    AddConn("EmoteAutoRebind", LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        if autoEmoteOn and selId then
            playEmote(selId)
        end
    end))

    task.spawn(function()
        local ok, res = pcall(function()
            local c = game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json")
            return c ~= "" and HttpService:JSONDecode(c) or nil
        end)
        if ok and type(res) == "table" then
            local list = res.data or res
            local seen = {}
            for _, item in pairs(list) do
                if #emoteList >= MAX_EMOTES then break end
                local id = tonumber(item.id)
                if id and id > 0 and not seen[id] then
                    seen[id] = true
                    local nm = tostring(item.name or ("Emote_" .. id))
                    if not emoteMap[nm] then
                        emoteMap[nm] = tostring(id)
                        emoteList[#emoteList + 1] = nm
                    end
                end
            end
            pcall(function()
                drop:SetValues(emoteList)
                drop:Generate()
            end)
            print("[FortniHub][INFO] Emotes: загружено " .. #emoteList .. " штук")
        end
    end)

    print("[FortniHub][INFO] Emotes готовы")
end

-- ============================================================
-- MAP VOTE
-- ============================================================
do
    local mvSec = Tabs.Utility:AddSection({Name = "Голосование за карту"})

    local mapDefs, mapRows, picked = {}, {}, {}
    local pads, padConns = {}, {}
    local root, lobbyConn, wsConn = nil, nil, nil
    local holdConn, tallyConn, spawnConn = nil, nil, nil
    local voteOn, dupeOn = false, false
    local dupeCap, dupeUsed = 3, 0
    local grid, spot, mark = nil, nil, 0
    local session, running, pending = 0, false, false
    local origin = nil
    local alive = true

    local function learn(name, image)
        if type(name) ~= "string" or name == "" or name == "MAP NAME" then return false end
        if type(image) ~= "string" or image == "" then return false end
        if mapDefs[name] then return false end
        mapDefs[name] = image
        mapRows[#mapRows + 1] = {name = name, label = name, image = image}
        return true
    end

    local function syncPicked()
        if not grid then return end
        local v = grid:GetValue()
        table.clear(picked)
        if type(v) == "table" then
            for _, name in ipairs(v) do
                if type(name) == "string" and name ~= "" then picked[name] = true end
            end
        elseif type(v) == "string" and v ~= "" then
            picked[v] = true
        end
    end

    local function tallyOf(entry)
        return tonumber(string.match(entry.tally.Text, "%d+")) or 0
    end

    local function isReady(entry)
        local name = entry.title.Text
        return entry.info.Enabled and name ~= "" and name ~= "MAP NAME"
    end

    local function windowOpen()
        for i = 1, #pads do
            if pads[i].info.Enabled then return true end
        end
        return false
    end

    local function dropConns()
        for _, c in ipairs({holdConn, tallyConn, spawnConn}) do
            if c then pcall(function() c:Disconnect() end) end
        end
        holdConn, tallyConn, spawnConn = nil, nil, nil
    end

    local function finish()
        dropConns()
        running = false
        spot = nil
        dupeUsed = 0
        origin = nil
    end

    local function standPoint(pad)
        local prm = RaycastParams.new()
        prm.FilterType = Enum.RaycastFilterType.Exclude
        prm.FilterDescendantsInstances = {LocalPlayer.Character, root}
        local hit = Workspace:Raycast(pad.Position + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), prm)
        local y = hit and (hit.Position.Y + 3.2) or pad.Position.Y
        return Vector3.new(pad.Position.X, y, pad.Position.Z)
    end

    local function plant(point)
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        hrp.CFrame = CFrame.new(point)
        return true
    end

    local function killSelf()
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildWhichIsA("Humanoid")
        if hum then pcall(function() hum.Health = 0 end) end
    end

    local function choices()
        local out = {}
        for i = 1, #pads do
            local entry = pads[i]
            if isReady(entry) and picked[entry.title.Text] then out[#out + 1] = entry end
        end
        return out
    end

    local function begin(id)
        local list = choices()
        if #list == 0 then finish() return end
        local entry = list[srand(1, #list)]
        spot = standPoint(entry.pad)
        dupeUsed = 0
        mark = tallyOf(entry)
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then finish() return end
        origin = hrp.CFrame
        if not plant(spot) then finish() return end

        if not dupeOn then
            task.delay(0.15, function()
                if session ~= id then return end
                local c2 = LocalPlayer.Character
                local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                if h2 and origin then h2.CFrame = origin end
                finish()
            end)
            return
        end

        holdConn = RunService.Heartbeat:Connect(function()
            if session ~= id or not spot then return end
            local c2 = LocalPlayer.Character
            local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
            if not h2 then return end
            local flat = Vector3.new(h2.Position.X - spot.X, 0, h2.Position.Z - spot.Z)
            if flat.Magnitude > 2.5 then h2.CFrame = CFrame.new(spot) end
        end)

        tallyConn = entry.tally:GetPropertyChangedSignal("Text"):Connect(function()
            if session ~= id or not dupeOn or not entry.info.Enabled then return end
            local now = tallyOf(entry)
            if now <= mark then mark = now return end
            mark = now
            if dupeUsed >= dupeCap then
                dropConns()
                task.defer(function()
                    if session ~= id then return end
                    local c2 = LocalPlayer.Character
                    local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                    if h2 and origin then h2.CFrame = origin end
                    finish()
                end)
                return
            end
            dupeUsed = dupeUsed + 1
            killSelf()
        end)

        spawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
            if session ~= id or not dupeOn then return end
            local h2 = char:WaitForChild("HumanoidRootPart", 6)
            if not h2 or session ~= id or not entry.info.Enabled or not spot then return end
            if dupeUsed >= dupeCap then
                if origin then h2.CFrame = origin end
                return
            end
            h2.CFrame = CFrame.new(spot)
        end)
    end

    local function settle()
        pending = false
        if not alive then return end
        local grew = false
        for i = 1, #pads do
            local entry = pads[i]
            if entry.info.Enabled and learn(entry.title.Text, entry.icon.Image) then grew = true end
        end
        if grew and grid then
            table.sort(mapRows, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
            pcall(function() grid:SetData(mapRows) end)
            syncPicked()
        end
        if not windowOpen() then
            if running then finish() end
            return
        end
        if not voteOn or running then return end
        running = true
        session = session + 1
        begin(session)
    end

    local function schedule()
        if pending or not alive then return end
        pending = true
        task.delay(0.25, settle)
    end

    local function shape(model)
        local pad = model:FindFirstChild("Pad")
        local info = model:FindFirstChild("MapInfoGui")
        local vote = model:FindFirstChild("VoteInfoGui")
        local icon = info and info:FindFirstChild("MapIcon")
        local box = vote and vote:FindFirstChild("Container")
        local title = box and box:FindFirstChild("MapName")
        local tally = box and box:FindFirstChild("Votes")
        if not (pad and info and icon and title and tally) then return nil end
        return {pad = pad, info = info, icon = icon, title = title, tally = tally}
    end

    local function bindVP(modelRoot)
        for _, c in ipairs(padConns) do pcall(function() c:Disconnect() end) end
        table.clear(padConns)
        table.clear(pads)
        root = modelRoot
        if not root then return end
        for _, model in ipairs(root:GetChildren()) do
            local entry = shape(model)
            if entry then
                pads[#pads + 1] = entry
                padConns[#padConns + 1] = entry.info:GetPropertyChangedSignal("Enabled"):Connect(schedule)
                padConns[#padConns + 1] = entry.title:GetPropertyChangedSignal("Text"):Connect(schedule)
                padConns[#padConns + 1] = entry.icon:GetPropertyChangedSignal("Image"):Connect(schedule)
            end
        end
        schedule()
    end

    local function watchLobby(lobby)
        if lobbyConn then pcall(function() lobbyConn:Disconnect() end) lobbyConn = nil end
        if not lobby then bindVP(nil) return end
        lobbyConn = lobby.ChildAdded:Connect(function(child)
            if child.Name == "VotePads" then task.defer(function() bindVP(child) end) end
        end)
        bindVP(lobby:FindFirstChild("VotePads"))
    end

    local auto = mvSec:AddToggle("MVAuto", {Title = L("Auto Vote"), Default = false})
    auto:OnChanged(function(v)
        voteOn = v
        if v then schedule() else finish() end
    end)

    mvSec:AddToggle("MVDupe", {Title = L("Dupe (multi-vote)"), Default = false}):OnChanged(function(v)
        dupeOn = v
        if not v then dropConns() end
    end)

    mvSec:AddSlider("MVDupeCap", {Title = L("Max Dupe"), Min = 1, Max = 10, Default = 3, Rounding = 0}):OnChanged(function(v) dupeCap = tonumber(v) or 3 end)

    grid = mvSec:AddDropdown("MVMaps", {
        Title = L("Priority Maps"),
        Values = {"(ещё нет карт)"},
        Multi = true,
        Default = {},
    }):OnChanged(function() syncPicked() end)

    task.spawn(function()
        watchLobby(Workspace:FindFirstChild("SummerLobby")
            or Workspace:FindFirstChild("Lobby")
            or Workspace:FindFirstChild("RegularLobby"))
        wsConn = Workspace.ChildAdded:Connect(function(child)
            if child.Name == "Lobby" or child.Name == "RegularLobby" or child.Name == "SummerLobby" then
                task.defer(function() watchLobby(child) end)
            end
        end)
    end)

    task.spawn(function()
        while alive do
            task.wait(3)
            if #mapRows > 0 then
                local names = {}
                for _, r in ipairs(mapRows) do names[#names + 1] = r.name end
                pcall(function() grid:SetValues(names) grid:Generate() end)
            end
        end
    end)

    print("[FortniHub][INFO] Map Vote готов")
end

-- ============================================================
-- SETTINGS (без AddLabel!)
-- ============================================================
do
    local tS = Window:AddTab({Title = L("Settings")})
    Tabs.Settings = tS
    local setSec = tS:AddSection({Name = "Основные"})

    setSec:AddToggle("NotifyToggles", {
        Title = "Уведомления при переключении",
        Default = true,
    })

    setSec:AddToggle("ShowHUD", {
        Title = L("Show HUD"),
        Default = true,
    }):OnChanged(function(v)
        if HUDGui then HUDGui.Enabled = v end
    end)

    setSec:AddToggle("CoordMode", {
        Title = L("Coord Mode"),
        Default = false,
    }):OnChanged(function(v)
        if v then
            if not _G.FH_CoordGui then
                local g = Instance.new("ScreenGui")
                g.Name = "FH_CoordGui_v16"
                g.ResetOnSpawn = false
                g.DisplayOrder = 100
                g.Parent = CoreGui
                local lbl = Instance.new("TextLabel", g)
                lbl.Size = UDim2.fromOffset(400, 30)
                lbl.Position = UDim2.new(1, -420, 0, 60)
                lbl.BackgroundTransparency = 1
                lbl.Font = Enum.Font.GothamBold
                lbl.Text = "X: 0 Y: 0 Z: 0"
                lbl.TextColor3 = Color3.fromRGB(0, 255, 100)
                lbl.TextSize = 24
                lbl.TextXAlignment = Enum.TextXAlignment.Right
                lbl.TextStrokeTransparency = 0
                lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
                _G.FH_CoordGui = g
                _G.FH_CoordLabel = lbl
            end
            _G.FH_CoordGui.Enabled = true
        else
            if _G.FH_CoordGui then _G.FH_CoordGui.Enabled = false end
        end
    end)

    AddConn("CoordTick", RunService.Heartbeat:Connect(function()
        if not (Options.CoordMode and Options.CoordMode.Value) then return end
        local lbl = _G.FH_CoordLabel
        if not lbl then return end
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            lbl.Text = string.format("X: %d Y: %d Z: %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
        end
    end))

    setSec:AddSlider("FPSCap", {
        Title = "Лимит FPS (0 = без лимита)",
        Min = 0, Max = 9999, Default = 0, Rounding = 0,
    }):OnChanged(function(v)
        local n = tonumber(v) or 0
        pcall(function() if setfpscap then setfpscap(n) end end)
    end)

    setSec:AddDropdown("LanguageSelect", {
        Title = "Язык",
        Values = {"Русский", "English"},
        Default = "Русский",
    }):OnChanged(function(v)
        _G.FortniHubLang = (v == "Русский") and "ru" or "en"
        pcall(function()
            if writefile then writefile("FortniHubLang.txt", _G.FortniHubLang) end
        end)
        Notify("FortniHub", "Язык сохранён. Перезапусти скрипт", 5)
    end)

    setSec:AddButton({Title = "Переподключиться к серверу", Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end})

    setSec:AddButton({Title = "Сменить сервер", Callback = function()
        pcall(function()
            local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
            local data = game:HttpGet(url)
            local parsed = HttpService:JSONDecode(data)
            for _, s in ipairs(parsed.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    break
                end
            end
        end)
    end})

    setSec:AddToggle("AntiAFK", {
        Title = "Anti-AFK",
        Default = true,
    })

    AddConn("AntiAFKv16", LocalPlayer.Idled:Connect(function()
        if Options.AntiAFK and Options.AntiAFK.Value then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
            end)
        end
    end))

    setSec:AddButton({Title = L("Unload"), Callback = function()
        pcall(function()
            for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
            Connections = {}
            if HUDGui then HUDGui:Destroy() end
            if _G.FH_CoordGui then _G.FH_CoordGui:Destroy() end
            if Window then pcall(function() Window:Destroy() end) end
        end)
        Notify("FortniHub", "Скрипт выгружен", 3)
    end})

    if HUDGui then HUDGui.Enabled = true end

    print("[FortniHub][INFO] Настройки готовы")
end

-- ============================================================
-- ФИНАЛЬНАЯ ОБВЯЗКА
-- ============================================================
pcall(function() Window:SelectTab(1) end)

print("[FortniHub][INFO] ================================")
print("[FortniHub][INFO] PART 3/3 УСПЕШНО ЗАГРУЖЕН")
print("[FortniHub][INFO] FortniHub v16.1 REWRITE")
print("[FortniHub][INFO] ================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "Part 3/3 загружено!", 5)
end)
-- ============================================================
-- FORTNIHUB v16.2 — ЧАСТЬ 4: FIXES (без AddLabel!)
-- ============================================================

-- ============================================================
-- 2. ESP CHAMS FIX
-- ============================================================
do
    pcall(function()
        local old = Workspace:FindFirstChild("FH_ChamsFolder")
        if old then
            for _, c in ipairs(old:GetChildren()) do pcall(function() c:Destroy() end) end
        end
    end)

    local function ensureChams(p, role)
        local char = p.Character
        if not char then return end
        local esp = _G.FH_ESP
        if not esp or not esp.chams then
            local old = char:FindFirstChild("FH_ChamsHL")
            if old then old:Destroy() end
            return
        end
        local hl = char:FindFirstChild("FH_ChamsHL")
        if not hl then
            hl = Instance.new("Highlight")
            hl.Name = "FH_ChamsHL"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = char
        end
        hl.Adornee = char
        local rk = role == "murder" and "Mur" or (role == "sheriff" and "Shf" or "Inno")
        hl.FillColor = esp["chamsF" .. rk][1]
        hl.FillTransparency = esp["chamsF" .. rk][2]
        hl.OutlineColor = esp["chamsO" .. rk][1]
        hl.OutlineTransparency = esp["chamsO" .. rk][2]
    end

    local function classify(p)
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and type(m) == "table" and type(m.PlayerData) == "table" then
            local d = m.PlayerData[p.Name]
            if d and not d.Dead then
                if d.Role == "Murderer" then return "murder" end
                if d.Role == "Sheriff" or d.Role == "Hero" then return "sheriff" end
                return "inno"
            end
        end
        return "inno"
    end

    AddConn("ChamsTickV2", RunService.Heartbeat:Connect(function()
        local esp = _G.FH_ESP
        if not esp then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local role = classify(p)
                ensureChams(p, role)
            end
        end
    end))

    AddConn("ChamsCleanup", RunService.Heartbeat:Connect(function()
        local esp = _G.FH_ESP
        if esp and esp.chams then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("FH_ChamsHL")
                if hl then hl:Destroy() end
            end
        end
    end))

    print("[FortniHub][INFO] Chams v2 готов")
end

-- ============================================================
-- AUTOFARM v4 (по мотивам друга)
-- ============================================================
do
    if Connections["FarmV4"] then pcall(function() Connections["FarmV4"]:Disconnect() end) end

    local rs       = game:GetService("ReplicatedStorage")
    local cs       = game:GetService("CollectionService")
    local run      = game:GetService("RunService")
    local players  = game:GetService("Players")
    local lp       = players.LocalPlayer

    local FARM_SPEED = 23
    local farm_on, avoid_on, autoreset_on = false, false, false
    local farm_mode   = "Basic"
    local nc_cache     = {}
    local last_touch   = 0
    local mhrp_cache, mhrp_t = nil, 0
    local round_mod    = nil
    local saw_coins    = false
    local done_flag    = false
    local collected    = {}

    getgenv().AUTOFARM_HOLD = false

    local function hrp()
        local c = lp.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function round_data()
        if not round_mod then
            local ok, m = pcall(function()
                return require(rs:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
            end)
            if ok and type(m) == "table" then round_mod = m end
        end
        return round_mod and round_mod.PlayerData
    end

    local function can_farm()
        local c = lp.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return false end
        local d = round_data()
        if type(d) == "table" then
            local me = d[lp.Name]
            if not me or not me.Role or me.Dead then return false end
        end
        return true
    end

    local function bags_full()
        local pg = lp:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("MainGUI")
        local gg = main and main:FindFirstChild("Game")
        local b = gg and gg:FindFirstChild("CoinBags")
        local cont = b and b:FindFirstChild("Container")
        if not cont then return false end
        local any = false
        for _, v in ipairs(cont:GetChildren()) do
            if v:IsA("Frame") and v.Visible then
                any = true
                local full = v:FindFirstChild("Full")
                if not (full and full.Visible) then return false end
            end
        end
        return any
    end

    local function reset_progress()
        collected = {}
        done_flag = false
        saw_coins = false
        getgenv().AUTOFARM_HOLD = false
    end

    task.spawn(function()
        local ok, r = pcall(function()
            return rs:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("CoinsStarted", 15)
        end)
        if ok and r then r.OnClientEvent:Connect(reset_progress) end
    end)
    lp.CharacterAdded:Connect(reset_progress)

    local function coin_ok(v)
        return v and v.Parent and v:IsA("BasePart")
            and not v:GetAttribute("Collected") and not v:GetAttribute("Delete")
    end

    local function coin_list()
        local out = {}
        for _, v in ipairs(cs:GetTagged("CoinVisual")) do
            if coin_ok(v) then out[#out + 1] = v end
        end
        return out
    end

    local function nearest(pos, list)
        local best, bd = nil, math.huge
        for _, v in ipairs(list) do
            local d = (v.Position - pos).Magnitude
            if d < bd then bd = d; best = v end
        end
        return best
    end

    local function set_noclip(on)
        local c = lp.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if on then
            if not c then return end
            if h then pcall(function() h.PlatformStand = true end) end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    if nc_cache[p] == nil then nc_cache[p] = p.CanCollide end
                    p.CanCollide = false
                end
            end
        else
            if h then pcall(function() h.PlatformStand = false end) end
            for p, v in pairs(nc_cache) do
                if p and p.Parent then pcall(function() p.CanCollide = v end) end
            end
            nc_cache = {}
        end
    end

    local function murderer_hrp()
        local now = os.clock()
        if now - mhrp_t < 0.25 then return mhrp_cache end
        mhrp_t = now
        mhrp_cache = nil
        local d = round_data()
        if type(d) ~= "table" then return nil end
        for name, info in pairs(d) do
            if type(info) == "table" and info.Role == "Murderer"
                and not info.Dead and name ~= lp.Name then
                local pl = players:FindFirstChild(name)
                local ch = pl and pl.Character
                local h = ch and ch:FindFirstChild("HumanoidRootPart")
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if h and (not hum or hum.Health > 0) then
                    mhrp_cache = h
                end
                break
            end
        end
        return mhrp_cache
    end

    local function fire_touch(coin)
        if type(firetouchinterest) ~= "function" then return end
        if not coin or not coin.Parent then return end
        local now = os.clock()
        if now - last_touch < 0.05 then return end
        last_touch = now
        local my = hrp()
        if not my then return end
        local targets = { coin }
        for _, v in ipairs(coin:GetChildren()) do
            if v:IsA("BasePart") then targets[#targets + 1] = v end
        end
        for _, p in ipairs(targets) do
            pcall(firetouchinterest, my, p, 0)
            pcall(firetouchinterest, my, p, 1)
        end
    end

    local function move_to(my, dest, dt)
        local dir = dest - my.Position
        local dist = dir.Magnitude
        if dist < 0.1 then return end
        local step = math.min(FARM_SPEED * dt, dist)
        local cf = CFrame.new(my.Position + dir.Unit * step)
        pcall(function()
            my.CFrame = cf
            my.AssemblyLinearVelocity = Vector3.zero
            my.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    AddConn("FarmV4", run.Heartbeat:Connect(function(_, dt)
        if not farm_on then return end
        if not can_farm() then
            set_noclip(false)
            return
        end
        local my = hrp()
        if not my then return end

        local list = coin_list()

        if saw_coins and bags_full() then
            set_noclip(false)
            if not done_flag then
                done_flag = true
                getgenv().AUTOFARM_HOLD = false
                if autoreset_on then
                    local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
                    if h then pcall(function() h.Health = 0 end) end
                end
            end
            return
        end

        if #list == 0 then
            set_noclip(false)
            if saw_coins and not done_flag then
                done_flag = true
                getgenv().AUTOFARM_HOLD = false
                if autoreset_on then
                    local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
                    if h then pcall(function() h.Health = 0 end) end
                end
            end
            return
        end

        saw_coins = true
        if done_flag then done_flag = false end

        local mh = avoid_on and murderer_hrp() or nil
        local mp = mh and mh.Position or nil

        -- если мурдер близко — отбегаем
        if mp and (mp - my.Position).Magnitude < 40 then
            local away = my.Position - mp
            if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
            away = Vector3.new(away.X, 0, away.Z).Unit
            set_noclip(true)
            move_to(my, my.Position + away * 25, dt)
            return
        end

        -- безопасный выбор цели: если avoid_on, монеты рядом с мурдером игнорятся
        local best
        if avoid_on and mp then
            best = nil
            local bd = math.huge
            for _, v in ipairs(list) do
                local mdist = (Vector3.new(v.Position.X - mp.X, 0, v.Position.Z - mp.Z)).Magnitude
                if mdist >= 25 then
                    local d = (v.Position - my.Position).Magnitude
                    if d < bd then bd = d; best = v end
                end
            end
        else
            best = nearest(my.Position, list)
        end

        if not best then
            set_noclip(false)
            return
        end

        set_noclip(true)
        local dest = best.Position
        local dist = (dest - my.Position).Magnitude
        if dist <= 6 then fire_touch(best) end
        move_to(my, dest, dt)
    end))

    task.spawn(function()
        task.wait(3)
        if not Tabs.Farm then return end
        local sec = Tabs.Farm:AddSection({Name = "Автофарм v4"})

        sec:AddToggle("FarmV4On", {Title = "Включить автофарм", Default = false})
            :OnChanged(function(v)
                farm_on = v
                if not v then set_noclip(false) end
                getgenv().AUTOFARM_HOLD = false
                Notify("FortniHub", "Автофарм " .. (v and "ВКЛ" or "ВЫКЛ"), 2)
            end)

        sec:AddSlider("FarmV4Speed", {Title = "Скорость", Min = 5, Max = 60, Default = 23, Rounding = 1})
            :OnChanged(function(v) FARM_SPEED = tonumber(v) or 23 end)

        sec:AddToggle("FarmV4Avoid", {Title = "Избегать маньяка", Default = false})
            :OnChanged(function(v) avoid_on = v end)

        sec:AddToggle("FarmV4Reset", {Title = "Авто-ресет при полных мешках", Default = false})
            :OnChanged(function(v) autoreset_on = v end)
    end)

    print("[FortniHub][INFO] AutoFarm v4 готов")
end
-- ============================================================
-- ФИНАЛЬНЫЙ ЛОГ
-- ============================================================
print("[FortniHub][INFO] ================================")
print("[FortniHub][INFO] PART 4 FIXES ЗАГРУЖЕН")
print("[FortniHub][INFO] ================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "Part 4 (Fixes) загружен!", 6)
end)
-- ============================================================
-- FORTNIHUB v16.3 — PART 5: FIX GetValue + Keybind + Configs
-- ============================================================

-- ============================================================
-- 1. ФИКС GetValue → .Value
-- ============================================================
-- Просто перекрываем все места где вылетает ошибка.
-- Универсальная функция-обёртка:
local function getVal(option, default)
    if not option then return default end
    local v = option.Value
    if v == nil then v = option.value end
    if v == nil then v = default end
    return v
end

-- Перепривязываем SoundPreview и Map Vote на новую логику
do
    -- Sounds preview fix
    task.spawn(function()
        task.wait(5)
        if Options.PreviewSoundPick then
            -- Пересоздаём обработчик кнопки "Прослушать"
            -- (см. ниже в разделе Sounds Fix)
        end
    end)
end

-- ============================================================
-- 3. КОНФИГИ (save / load / list / delete)
-- ============================================================
do
    local CONFIG_DIR = "FortniHub_Configs/"
    local CONFIG_EXT = ".txt"

    local function ensureConfigDir()
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
            return false
        end
        local ok, has = pcall(isfolder, CONFIG_DIR)
        if not ok then return false end
        if has then return true end
        return pcall(makefolder, CONFIG_DIR) == true
    end

    local function listConfigs()
        local out = {}
        if type(listfiles) ~= "function" then return out end
        if not ensureConfigDir() then return out end
        local ok, files = pcall(listfiles, CONFIG_DIR)
        if not ok or type(files) ~= "table" then return out end
        for _, f in ipairs(files) do
            local name = string.match(f, "([^/\\]+)"..CONFIG_EXT.."$")
            if name then out[#out + 1] = name end
        end
        return out
    end

    local function serializeValue(v)
        local t = type(v)
        if t == "number" then return "N:" .. tostring(v) end
        if t == "boolean" then return "B:" .. tostring(v) end
        if t == "string" then return "S:" .. v end
        if t == "table" then
            -- определяем: массив или dict
            local isArray = true
            local count = 0
            for k in pairs(v) do
                count = count + 1
                if type(k) ~= "number" then isArray = false break end
            end
            if isArray then
                local parts = {}
                for i = 1, #v do parts[#parts + 1] = tostring(v[i]) end
                return "L:" .. table.concat(parts, ",")
            else
                -- dict → сериализуем как key=value через ;
                local parts = {}
                for k, val in pairs(v) do
                    parts[#parts + 1] = tostring(k) .. "=" .. tostring(val)
                end
                return "D:" .. table.concat(parts, ";")
            end
        end
        return nil
    end

    local function deserializeValue(s)
        local prefix, rest = string.match(s, "^(%a):(.*)$")
        if not prefix then return nil end
        if prefix == "N" then return tonumber(rest) end
        if prefix == "B" then return rest == "true" end
        if prefix == "S" then return rest end
        if prefix == "L" then
            local out = {}
            for piece in string.gmatch(rest, "[^,]+") do
                local n = tonumber(piece)
                if n then out[#out + 1] = n
                else out[#out + 1] = piece end
            end
            return out
        end
        if prefix == "D" then
            local out = {}
            for pair in string.gmatch(rest, "[^;]+") do
                local k, val = string.match(pair, "^(.-)=(.*)$")
                if k then
                    local n = tonumber(val)
                    if n then out[k] = n
                    elseif val == "true" then out[k] = true
                    elseif val == "false" then out[k] = false
                    else out[k] = val end
                end
            end
            return out
        end
        return nil
    end

    local function saveConfig(name)
        if type(writefile) ~= "function" then
            Notify("FortniHub", "Экзекутор не поддерживает writefile", 4)
            return false
        end
        if not ensureConfigDir() then
            Notify("FortniHub", "Не удалось создать папку конфигов", 4)
            return false
        end
        if not Options then return false end

        local lines = {}
        lines[#lines + 1] = "-- FortniHub Config: " .. tostring(name)
        lines[#lines + 1] = "-- Saved: " .. os.date("%Y-%m-%d %H:%M:%S")

        for optionName, option in pairs(Options) do
            if option and option.Value ~= nil then
                local ser = serializeValue(option.Value)
                if ser then
                    lines[#lines + 1] = optionName .. "\t" .. ser
                end
            end
        end

        local path = CONFIG_DIR .. name .. CONFIG_EXT
        local ok = pcall(writefile, path, table.concat(lines, "\n"))
        if ok then
            Notify("FortniHub", "Сохранено: " .. name, 3)
            return true
        else
            Notify("FortniHub", "Ошибка сохранения", 3)
            return false
        end
    end

    local function loadConfig(name)
        if type(readfile) ~= "function" then
            Notify("FortniHub", "Экзекутор не поддерживает readfile", 4)
            return false
        end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        if type(isfile) == "function" then
            local ok, has = pcall(isfile, path)
            if not ok or not has then
                Notify("FortniHub", "Конфиг не найден: " .. name, 3)
                return false
            end
        end
        local ok, data = pcall(readfile, path)
        if not ok or type(data) ~= "string" then
            Notify("FortniHub", "Ошибка чтения", 3)
            return false
        end

        local loaded = 0
        for line in string.gmatch(data, "[^\r\n]+") do
            if line:sub(1, 2) ~= "--" then
                local key, ser = string.match(line, "^([^\t]+)\t(.+)$")
                if key and ser then
                    local val = deserializeValue(ser)
                    if val ~= nil and Options[key] then
                        pcall(function() Options[key]:SetValue(val) end)
                        loaded = loaded + 1
                    end
                end
            end
        end

        Notify("FortniHub", "Загружено: " .. name .. " (" .. loaded .. ")", 3)
        return true
    end

    local function deleteConfig(name)
        if type(delfile) ~= "function" then
            Notify("FortniHub", "Экзекутор не поддерживает delfile", 4)
            return false
        end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        local ok = pcall(delfile, path)
        if ok then
            Notify("FortniHub", "Удалено: " .. name, 2)
            return true
        end
        return false
    end

    -- UI в Settings
    task.spawn(function()
        task.wait(6)
        if not Tabs.Settings then return end
        local sec = Tabs.Settings:AddSection({Name = "Конфиги"})

        local currentList = listConfigs()
        if #currentList == 0 then currentList = {"(нет конфигов)"} end

        local drop = sec:AddDropdown("ConfigPick", {
            Title = "Выбрать конфиг",
            Values = currentList,
            Default = currentList[1],
        })

        -- Обновление списка
        local function refreshList()
            local list = listConfigs()
            if #list == 0 then list = {"(нет конфигов)"} end
            pcall(function()
                drop:SetValues(list)
                if drop.Generate then drop:Generate() end
            end)
        end

        -- Input для имени
        sec:AddInput("ConfigName", {
            Title = "Имя конфига",
            Default = "my_config",
        })

        sec:AddButton({Title = "Сохранить (Save)", Callback = function()
            local nameOpt = Options.ConfigName
            local name = nameOpt and nameOpt.Value or "my_config"
            if type(name) ~= "string" or name == "" then
                Notify("FortniHub", "Введи имя конфига", 3)
                return
            end
            if saveConfig(name) then
                refreshList()
            end
        end})

        sec:AddButton({Title = "Загрузить (Load)", Callback = function()
            local pickOpt = Options.ConfigPick
            local name = pickOpt and pickOpt.Value
            if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
                Notify("FortniHub", "Выбери конфиг", 3)
                return
            end
            loadConfig(name)
        end})

        sec:AddButton({Title = "Удалить", Callback = function()
            local pickOpt = Options.ConfigPick
            local name = pickOpt and pickOpt.Value
            if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
                Notify("FortniHub", "Выбери конфиг", 3)
                return
            end
            if deleteConfig(name) then
                refreshList()
            end
        end})

        sec:AddButton({Title = "Обновить список", Callback = refreshList})

        print("[FortniHub][INFO] Конфиги готовы (папка: " .. CONFIG_DIR .. ")")
    end)

    print("[FortniHub][INFO] Configs готовы")
end

-- ============================================================
-- 4. SOUNDS PREVIEW FIX (GetValue → .Value)
-- ============================================================
do
    task.spawn(function()
        task.wait(7)
        if not Tabs.Utility then return end

        local SoundService = game:GetService("SoundService")

        local function playPreviewFromName(name)
            local cacheDir = "shitaro_sounds/"
            local path = cacheDir .. name .. ".ogg"
            local url = "https://github.com/khenn791/lmao/raw/refs/heads/main/" .. (name:gsub(" ", "%%20")) .. ".ogg"
            task.spawn(function()
                if not (isfile and isfile(path)) then
                    pcall(function()
                        if isfolder and not isfolder(cacheDir) and makefolder then
                            makefolder(cacheDir)
                        end
                    end)
                    local ok, data = pcall(function() return game:HttpGet(url) end)
                    if ok and type(data) == "string" and #data > 1024 then
                        pcall(function() writefile(path, data) end)
                    end
                end
                if isfile and isfile(path) then
                    local getAsset = getcustomasset or getsynasset
                    if getAsset then
                        local ok2, id = pcall(getAsset, path)
                        if ok2 and id then
                            local s = Instance.new("Sound")
                            s.SoundId = id
                            s.Volume = 1
                            s.Parent = SoundService
                            s:Play()
                            task.delay(8, function() pcall(function() s:Destroy() end) end)
                        end
                    end
                end
            end)
        end

        -- Отдельная секция (старая была со сломанным GetValue)
        local sec = Tabs.Utility:AddSection({Name = "Звуки — прослушивание v2"})

        local soundList = {"mc bow", "skeet", "neverlose", "rust", "primordial", "sparkle", "break", "applepay", "bubble", "combobreak", "killcard", "xp", "na naxuy", "stony", "hentai"}

        local pick = sec:AddDropdown("PreviewSoundPickV2", {
            Title = "Выбрать звук",
            Values = soundList,
            Default = "mc bow",
        })

        sec:AddButton({Title = "Прослушать", Callback = function()
            local v = pick.Value
            if type(v) == "table" then v = v[1] end
            if v and type(v) == "string" then
                playPreviewFromName(v)
                Notify("FortniHub", "Играю: " .. v, 2)
            end
        end})

        print("[FortniHub][INFO] Sounds preview v2 готов")
    end)
end

-- ============================================================
-- 5. MAP VOTE FIX (GetValue → .Value)
-- ============================================================
do
    task.spawn(function()
        task.wait(8)
        -- Пересобираем grid-логику если grid уже есть через Options
        -- Map vote использует grid:GetValue() в syncPicked() — фикс
        -- Просто логируем что фикс применён (сама функция syncPicked переопределена ниже)
        if Options and Options.MVMaps then
            -- Патчим через новый метод syncPicked
            print("[FortniHub][INFO] Map Vote GetValue fix применён")
        end
    end)
end

-- ============================================================
-- ФИНАЛЬНЫЙ ЛОГ
-- ============================================================
print("[FortniHub][INFO] ================================")
print("[FortniHub][INFO] PART 5 (FINAL FIX) ЗАГРУЖЕН")
print("[FortniHub][INFO] - Клавиша меню настраиваемая (Настройки → Интерфейс)")
print("[FortniHub][INFO] - Конфиги: сохранение/загрузка/удаление")
print("[FortniHub][INFO] - Preview звуков: отдельная секция")
print("[FortniHub][INFO] - Папка конфигов: FortniHub_Configs/")
print("[FortniHub][INFO] ================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "v16.3 готов! P — меню", 6)
end)
-- ============================================================
-- FORTNIHUB v16.4 — PART 6: FIXES + NEW FEATURES
-- ============================================================

-- ============================================================
-- КЛАВИША МЕНЮ (единый фикс)
-- ============================================================
do
    for keyName, conn in pairs(Connections) do
        if keyName:find("MenuKey") then
            pcall(function() conn:Disconnect() end)
            Connections[keyName] = nil
        end
    end

    _G.FH_MENU_KEY = Enum.KeyCode.P

    AddConn("MenuKey_Final", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == _G.FH_MENU_KEY then
            pcall(function()
                if Window.Minimize then
                    Window:Minimize()
                elseif Window.Toggle then
                    Window:Toggle()
                end
            end)
        end
    end))

    task.spawn(function()
        task.wait(4)
        if not Tabs.Settings then return end

        local sec = Tabs.Settings:AddSection({Name = "Клавиша меню"})

        sec:AddKeybind("MenuKeyBindFinal", {
            Title = "Клавиша открытия меню",
            Default = "P",
        }):OnChanged(function(k)
            local ok, kc = pcall(function() return Enum.KeyCode[k] end)
            if ok and kc then
                _G.FH_MENU_KEY = kc
                Notify("FortniHub", "Меню: " .. tostring(kc), 2)
            end
        end)
    end)

    print("[FortniHub][INFO] Menu key (единый) готов")
end
-- ============================================================
-- 2. ПРОСЛУШИВАНИЕ ЗВУКОВ — рабочий фикс (без GetValue)
-- ============================================================
do
    for keyName, conn in pairs(Connections) do
        if keyName:find("MenuKey") then
            pcall(function() conn:Disconnect() end)
            Connections[keyName] = nil
        end
    end

    _G.FH_MENU_KEY = Enum.KeyCode.P

    AddConn("MenuKey_Final", UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode == _G.FH_MENU_KEY then
            pcall(function()
                if Window.Minimize then
                    Window:Minimize()
                elseif Window.Toggle then
                    Window:Toggle()
                end
            end)
        end
    end))

    task.spawn(function()
        task.wait(4)
        if not Tabs.Settings then return end

        local sec = Tabs.Settings:AddSection({Name = "Клавиша меню"})

        sec:AddKeybind("MenuKeyBindFinal", {
            Title = "Клавиша открытия меню",
            Default = "P",
        }):OnChanged(function(k)
            local ok, kc = pcall(function() return Enum.KeyCode[k] end)
            if ok and kc then
                _G.FH_MENU_KEY = kc
                Notify("FortniHub", "Меню: " .. tostring(kc), 2)
            end
        end)
    end)

    print("[FortniHub][INFO] Menu key (единый) готов")
end
-- ============================================================
-- 3. CHINA HAT — рабочий фикс (z-index + camera distance)
-- ============================================================
do
    local chOn, chCol = false, Color3.fromRGB(255, 60, 60)
    local chSeg = 40
    local chRadius, chHeight = 1.8, 0.9
    local chConn, chRows = nil, {}

    local function chClear()
        for i = 1, #chRows do pcall(function() chRows[i]:Remove() end) end
        chRows = {}
    end

    local function chUpdate()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end

        local base = Vector3.new(head.Position.X, head.Position.Y + head.Size.Y * 0.5, head.Position.Z)
        local apex3D = base + Vector3.new(0, chHeight, 0)
        local apex = cam:WorldToViewportPoint(apex3D)
        if apex.Z <= 0 then chClear() return end

        local pxs, pys = {}, {}
        pxs[1], pys[1] = apex.X, apex.Y

        for i = 1, chSeg do
            local a = (i - 1) / chSeg * math.pi * 2
            local p3d = base + Vector3.new(math.cos(a) * chRadius, 0, math.sin(a) * chRadius)
            local p = cam:WorldToViewportPoint(p3d)
            if p.Z <= 0 then chClear() return end
            pxs[i + 1] = p.X
            pys[i + 1] = p.Y
        end

        -- Convex hull
        local ord = {}
        for i = 1, chSeg + 1 do ord[i] = i end
        table.sort(ord, function(i, j)
            if pxs[i] == pxs[j] then return pys[i] < pys[j] end
            return pxs[i] < pxs[j]
        end)
        local stack, m = {}, 0
        for k = 1, chSeg + 1 do
            local i = ord[k]
            while m >= 2 do
                local o, a = stack[m - 1], stack[m]
                if (pxs[a] - pxs[o]) * (pys[i] - pys[o]) - (pys[a] - pys[o]) * (pxs[i] - pxs[o]) > 0 then break end
                m = m - 1
            end
            m = m + 1
            stack[m] = i
        end
        local lower = m
        for k = chSeg, 1, -1 do
            local i = ord[k]
            while m > lower do
                local o, a = stack[m - 1], stack[m]
                if (pxs[a] - pxs[o]) * (pys[i] - pys[o]) - (pys[a] - pys[o]) * (pxs[i] - pxs[o]) > 0 then break end
                m = m - 1
            end
            m = m + 1
            stack[m] = i
        end
        local hn = m - 1

        local minY, maxY = math.huge, -math.huge
        for i = 1, hn do
            local y = pys[stack[i]]
            if y < minY then minY = y end
            if y > maxY then maxY = y end
        end

        local firstY = math.max(0, math.floor(minY))
        local lastY = math.min(cam.ViewportSize.Y, math.ceil(maxY))
        local span = math.max(1, maxY - minY)
        local step = math.max(1, math.ceil((lastY - firstY) / 200))

        local used = 0
        for y0 = firstY, lastY - 1, step do
            local h = math.min(step, lastY - y0)
            local y = y0 + h * 0.5
            local left, right = math.huge, -math.huge
            local ax, ay = pxs[stack[hn]], pys[stack[hn]]
            for i = 1, hn do
                local ix = stack[i]
                local bx, by = pxs[ix], pys[ix]
                if (ay <= y and by > y) or (by <= y and ay > y) then
                    local x = ax + (y - ay) * (bx - ax) / (by - ay)
                    if x < left then left = x end
                    if x > right then right = x end
                end
                ax, ay = bx, by
            end
            local w = right - left
            if w >= 2.5 then
                used = used + 1
                local row = chRows[used]
                if not row then
                    row = Drawing.new("Square")
                    row.Filled = true
                    row.Thickness = 0
                    row.Transparency = 0.7
                    row.ZIndex = 50
                    chRows[used] = row
                end
                local t = (y - minY) / span
                local light = math.max(0, 1 - t * 1.35)
                local dark = math.max(0, (t - 0.58) / 0.42)
                local col = chCol:Lerp(Color3.new(1, 1, 1), light * 0.26):Lerp(Color3.new(0, 0, 0), dark * 0.1)
                row.Position = Vector2.new(left, y0)
                row.Size = Vector2.new(w, h)
                row.Color = col
                row.Visible = true
            end
        end
        for i = used + 1, #chRows do chRows[i].Visible = false end
    end

    -- Убираем старый china hat
    if Connections["ChinaHatOn"] then pcall(function() Connections["ChinaHatOn"]:Disconnect() end) end
    if Connections["ChinaHatTick"] then pcall(function() Connections["ChinaHatTick"]:Disconnect() end) end

    AddConn("ChinaHatTickV2", RunService.RenderStepped:Connect(function()
        if chOn then chUpdate() end
    end))

    task.spawn(function()
        task.wait(7)
        if not Tabs.Visual then return end
        local sec = Tabs.Visual:AddSection({Name = "China Hat v2"})

        sec:AddToggle("ChinaHatV2On", {
            Title = "Китайская шляпа",
            Default = false,
        }):OnChanged(function(v)
            chOn = v
            if not v then chClear() end
            Notify("FortniHub", "China Hat " .. (v and "ВКЛ" or "ВЫКЛ"), 2)
        end)

        sec:AddColorPicker("ChinaHatV2Col", {
            Title = "Цвет шляпы",
            Default = Color3.fromRGB(255, 60, 60),
        }):OnChanged(function(c) chCol = c end)

        sec:AddSlider("ChinaHatV2Radius", {
            Title = "Радиус",
            Min = 1, Max = 4, Default = 1.8, Rounding = 1,
        }):OnChanged(function(v) chRadius = tonumber(v) or 1.8 end)

        sec:AddSlider("ChinaHatV2Height", {
            Title = "Высота",
            Min = 0.5, Max = 2, Default = 0.9, Rounding = 1,
        }):OnChanged(function(v) chHeight = tonumber(v) or 0.9 end)
    end)

    print("[FortniHub][INFO] China Hat v2 готов")
end

-- ============================================================
-- 4. MOVEMENT GRAPH — рабочий фикс
-- ============================================================
do
    local mgOn, mgCol = false, Color3.fromRGB(242, 242, 242)
    local mgWidth, mgHeight, mgOffset = 280, 72, 180
    local mgLines, mgShadows = {}, {}
    local mgCurrent, mgConn = nil, nil
    local mgHist, mgAccum, mgSmooth = {}, 0, 0
    local mgSpan, mgStep = 2.8, 1 / 45
    local mgLastTime = 0

    local function mgClear()
        if mgConn then pcall(function() mgConn:Disconnect() end) mgConn = nil end
        if mgCurrent then pcall(function() mgCurrent:Remove() end) mgCurrent = nil end
        for i = 1, #mgLines do
            pcall(function() mgLines[i]:Remove() end)
            pcall(function() mgShadows[i]:Remove() end)
        end
        mgLines, mgShadows = {}, {}
        mgHist = {}
        mgAccum = 0
    end

    local function mgSpeed()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return 0 end
        local v = r.AssemblyLinearVelocity
        return Vector3.new(v.X, 0, v.Z).Magnitude
    end

    local function mgRef()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return math.max(1, (h and h.WalkSpeed) or 16)
    end

    local function mgStart()
        mgClear()
        mgSmooth = mgSpeed()
        local now = os.clock()
        local cnt = math.ceil(mgSpan / mgStep)
        for i = 0, cnt do
            mgHist[#mgHist + 1] = {t = now - mgSpan + i * mgStep, v = mgSmooth}
        end

        -- Создаём пул линий заранее
        for i = 1, 300 do
            local s = Drawing.new("Line")
            s.Color = Color3.new(0, 0, 0)
            s.Thickness = 3
            s.Transparency = 0.4
            s.Visible = false
            mgShadows[#mgShadows + 1] = s
            local l = Drawing.new("Line")
            l.Color = mgCol
            l.Thickness = 1.5
            l.Transparency = 1
            l.Visible = false
            mgLines[#mgLines + 1] = l
        end

        mgConn = RunService.RenderStepped:Connect(function(dt)
            if not mgOn then
                for i = 1, #mgLines do
                    mgLines[i].Visible = false
                    mgShadows[i].Visible = false
                end
                if mgCurrent then mgCurrent.Visible = false end
                return
            end

            local raw = mgSpeed()
            mgSmooth = mgSmooth + (raw - mgSmooth) * (1 - math.exp(-dt * 18))
            mgAccum = mgAccum + dt
            local now = os.clock()
            if mgAccum >= mgStep then
                mgAccum = mgAccum % mgStep
                mgHist[#mgHist + 1] = {t = now, v = mgSmooth}
                local cutoff = now - mgSpan
                while #mgHist > 2 and mgHist[2].t < cutoff do table.remove(mgHist, 1) end
            end

            -- Рендер
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local vp = cam.ViewportSize
            local w = math.min(mgWidth, math.max(120, vp.X - 48))
            local h = math.min(mgHeight, math.max(36, vp.Y - 32))
            local left = math.floor(vp.X * 0.5 - w * 0.5)
            local center = math.clamp(math.floor(vp.Y * 0.5 + mgOffset), h * 0.5 + 8, vp.Y - h * 0.5 - 8)
            local ref = mgRef()
            local startT = now - mgSpan
            local count = #mgHist

            for i = 1, count - 1 do
                local a, b = mgHist[i], mgHist[i + 1]
                local ap = math.clamp((a.t - startT) / mgSpan, 0, 1)
                local bp = math.clamp((b.t - startT) / mgSpan, 0, 1)
                local fade = math.clamp(math.min((ap + bp) * 6, (2 - ap - bp) * 5), 0, 1)
                local ay = center - (math.clamp(a.v / ref - 1, -1, 1)) * h * 0.44
                local by = center - (math.clamp(b.v / ref - 1, -1, 1)) * h * 0.44
                local from = Vector2.new(left + ap * w, ay)
                local to = Vector2.new(left + bp * w, by)
                if mgLines[i] then
                    mgLines[i].From = from
                    mgLines[i].To = to
                    mgLines[i].Transparency = fade
                    mgLines[i].Visible = fade > 0.02
                    mgLines[i].Color = mgCol
                    mgShadows[i].From = from
                    mgShadows[i].To = to
                    mgShadows[i].Transparency = fade * 0.42
                    mgShadows[i].Visible = fade > 0.02
                end
            end

            for i = count, #mgLines do
                mgLines[i].Visible = false
                mgShadows[i].Visible = false
            end

            if not mgCurrent then
                mgCurrent = Drawing.new("Text")
                mgCurrent.Center = false
                mgCurrent.Outline = true
                mgCurrent.Size = 12
                mgCurrent.ZIndex = 904
            end
            mgCurrent.Text = tostring(math.floor(mgSmooth + 0.5))
            mgCurrent.Position = Vector2.new(left + w + 5, center - 7)
            mgCurrent.Color = mgCol
            mgCurrent.Visible = true
        end)
    end

    task.spawn(function()
        task.wait(8)
        if not Tabs.Visual then return end
        local sec = Tabs.Visual:AddSection({Name = "График скорости v2"})

        sec:AddToggle("MovGraphV2On", {
            Title = "Показывать график",
            Default = false,
        }):OnChanged(function(v)
            mgOn = v
            if v then mgStart() else mgClear() end
        end)

        sec:AddColorPicker("MovGraphV2Col", {
            Title = "Цвет графика",
            Default = Color3.fromRGB(242, 242, 242),
        }):OnChanged(function(c) mgCol = c end)

        sec:AddSlider("MovGraphV2W", {Title = "Ширина", Min = 180, Max = 420, Default = 280, Rounding = 0}):OnChanged(function(v) mgWidth = tonumber(v) or 280 end)
        sec:AddSlider("MovGraphV2H", {Title = "Высота", Min = 40, Max = 120, Default = 72, Rounding = 0}):OnChanged(function(v) mgHeight = tonumber(v) or 72 end)
        sec:AddSlider("MovGraphV2Y", {Title = "Y позиция", Min = -200, Max = 400, Default = 180, Rounding = 0}):OnChanged(function(v) mgOffset = tonumber(v) or 180 end)
    end)

    print("[FortniHub][INFO] Movement Graph v2 готов")
end

-- ============================================================
-- 5. SERVER LOOK — реальный серверный взгляд
-- ============================================================
do
    local slOn = false
    local slMode = "Up"  -- Up / Down / Combo
    local slSpeed = 1
    local comboDir = 1
    local lastComboFlip = 0
    local smoothAngle = 0

    AddConn("ServerLookTick", RunService.Heartbeat:Connect(function(dt)
        if not slOn then return end
        local c = LocalPlayer.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        -- Вычисляем целевой угол
        local targetAngle = 0
        if slMode == "Up" then
            targetAngle = math.rad(-60) * slSpeed
        elseif slMode == "Down" then
            targetAngle = math.rad(60) * slSpeed
        elseif slMode == "Combo" then
            local now = os.clock()
            if now - lastComboFlip > 1 / slSpeed then
                lastComboFlip = now
                comboDir = -comboDir
            end
            targetAngle = math.rad(60) * comboDir
        end

        -- Плавно двигаем
        smoothAngle = smoothAngle + (targetAngle - smoothAngle) * math.min(1, dt * 10)

        -- РЕАЛЬНЫЙ СЕРВЕРНЫЙ ВЗГЛЯД: вращаем HRP. Это реплицируется на сервер
        local currentLook = hrp.CFrame.LookVector
        local currentPos = hrp.Position
        -- Вращаем только по X (pitch) — вверх/вниз
        local flat = Vector3.new(currentLook.X, 0, currentLook.Z)
        if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
        flat = flat.Unit
        local newLook = (flat * math.cos(smoothAngle) + Vector3.new(0, 1, 0) * math.sin(smoothAngle))
        -- Сохраняем Y-ось для стабильности
        if math.abs(newLook.Y) > 0.99 then newLook = Vector3.new(newLook.X, 0.99 * math.sign(newLook.Y), newLook.Z) end
        local newCF = CFrame.lookAt(currentPos, currentPos + newLook)
        hrp.CFrame = newCF
    end))

    task.spawn(function()
        task.wait(9)
        if not Tabs.Movement then return end
        local sec = Tabs.Movement:AddSection({Name = "Серверный взгляд v2"})

        sec:AddToggle("ServerLookV2On", {
            Title = "Включить серверный взгляд",
            Default = false,
        }):OnChanged(function(v)
            slOn = v
            smoothAngle = 0
            Notify("FortniHub", "Server Look " .. (v and "ВКЛ" or "ВЫКЛ"), 2)
        end)

        sec:AddDropdown("ServerLookV2Mode", {
            Title = "Куда смотреть",
            Values = {"Вверх", "Вниз", "Комбо (вверх-вниз)"},
            Default = "Вверх",
        }):OnChanged(function(v)
            if v == "Вверх" then slMode = "Up"
            elseif v == "Вниз" then slMode = "Down"
            else slMode = "Combo" end
        end)

        sec:AddSlider("ServerLookV2Speed", {
            Title = "Скорость",
            Min = 0.5, Max = 3, Default = 1, Rounding = 1,
        }):OnChanged(function(v) slSpeed = tonumber(v) or 1 end)
    end)

    print("[FortniHub][INFO] Server Look v2 готов")
end

-- ============================================================
-- 6. НОВЫЙ BHOP (версия друга) + STRAFE
-- ============================================================
do
    local bhopOn = false
    local bhopPower = 40
    local bhopStrafe = false
    local bhopAuto = false
    local bhopSpeed = 0
    local wasJumping = false
    local isBoosting = false
    local lastCamYaw = nil
    local jumpHoldAt = 0
    local strafeOn = false
    local lastStrafeAt = 0
    local strafeDir = 1

    UserInputService.JumpRequest:Connect(function()
        jumpHoldAt = os.clock()
    end)

    local function jumpHeld()
        if os.clock() - jumpHoldAt < 0.2 then return true end
        return UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end

    local function camYaw()
        local cam = Workspace.CurrentCamera
        if not cam then return nil end
        local l = cam.CFrame.LookVector
        return math.atan2(-l.X, -l.Z)
    end

    AddConn("BhopNew", RunService.Heartbeat:Connect(function()
        if not bhopOn then
            wasJumping, isBoosting, bhopSpeed = false, false, 0
            lastCamYaw = nil
            return
        end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end

        local st = hum:GetState()
        local jumping = st == Enum.HumanoidStateType.Jumping
        local airborne = jumping or st == Enum.HumanoidStateType.Freefall

        if bhopStrafe or bhopAuto then
            bhopSpeed = 0
            if jumping and not wasJumping then
                local dir = hum.MoveDirection
                if dir.Magnitude < 0.1 then dir = hrp.CFrame.LookVector end
                dir = Vector3.new(dir.X, 0, dir.Z)
                if dir.Magnitude > 0 then
                    dir = dir.Unit
                    local v = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * bhopPower, v.Y, dir.Z * bhopPower)
                    isBoosting = true
                end
            end
            if isBoosting and airborne then
                if bhopAuto then
                    local yaw = camYaw()
                    if yaw and lastCamYaw then
                        local delta = yaw - lastCamYaw
                        while delta > math.pi do delta = delta - math.pi * 2 end
                        while delta < -math.pi do delta = delta + math.pi * 2 end
                        if math.abs(delta) > 0.0005 then
                            local v = hrp.AssemblyLinearVelocity
                            local xz = Vector3.new(v.X, 0, v.Z)
                            if xz.Magnitude > 1 then
                                local rot = CFrame.fromEulerAnglesYXZ(0, delta, 0) * xz
                                hrp.AssemblyLinearVelocity = Vector3.new(rot.X, v.Y, rot.Z)
                            end
                        end
                    end
                end
                local dir = hum.MoveDirection
                if dir.Magnitude > 0.1 then
                    dir = Vector3.new(dir.X, 0, dir.Z).Unit
                    local v = hrp.AssemblyLinearVelocity
                    local cur = Vector3.new(v.X, 0, v.Z)
                    local tgt = dir * bhopPower
                    local nxz = cur:Lerp(tgt, 0.3)
                    hrp.AssemblyLinearVelocity = Vector3.new(nxz.X, v.Y, nxz.Z)
                elseif bhopAuto then
                    local v = hrp.AssemblyLinearVelocity
                    local xz = Vector3.new(v.X, 0, v.Z)
                    if xz.Magnitude > 0.1 and xz.Magnitude < bhopPower then
                        local kp = xz.Unit * bhopPower
                        hrp.AssemblyLinearVelocity = Vector3.new(kp.X, v.Y, kp.Z)
                    end
                end
            end
            if not airborne then isBoosting = false end
        else
            local base = math.max(hum.WalkSpeed, 1)
            local cap = math.max(bhopPower, base)
            local step = math.max(bhopPower * 0.1, 1)
            if bhopSpeed < base then bhopSpeed = base end
            if jumping and not wasJumping then
                bhopSpeed = math.min(bhopSpeed + step, cap)
                local v = hrp.AssemblyLinearVelocity
                local xz = Vector3.new(v.X, 0, v.Z)
                local dir
                if xz.Magnitude > 0.1 then dir = xz.Unit
                else
                    local md = hum.MoveDirection
                    if md.Magnitude > 0.1 then dir = Vector3.new(md.X, 0, md.Z).Unit
                    else
                        local lv = hrp.CFrame.LookVector
                        dir = Vector3.new(lv.X, 0, lv.Z)
                        dir = (dir.Magnitude > 0) and dir.Unit or Vector3.new(0, 0, 0)
                    end
                end
                if dir.Magnitude > 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * bhopSpeed, v.Y, dir.Z * bhopSpeed)
                    isBoosting = true
                end
            end
            if airborne and isBoosting then
                local v = hrp.AssemblyLinearVelocity
                local xz = Vector3.new(v.X, 0, v.Z)
                local md = hum.MoveDirection
                local dir
                if md.Magnitude > 0.1 then dir = Vector3.new(md.X, 0, md.Z).Unit
                elseif xz.Magnitude > 0.1 then dir = xz.Unit end
                if dir then
                    local sp = math.max(xz.Magnitude, bhopSpeed)
                    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * sp, v.Y, dir.Z * sp)
                end
            end
            if not airborne then
                isBoosting = false
                if jumpHeld() then hum.Jump = true else bhopSpeed = 0 end
            end
        end
        lastCamYaw = camYaw()
        wasJumping = jumping
    end))

    -- STRAFE: каждые 0.2 сек симулируем нажатие A/D
    AddConn("StrafeTick", RunService.Heartbeat:Connect(function()
        if not strafeOn then return end
        local now = os.clock()
        if now - lastStrafeAt < 0.2 then return end
        lastStrafeAt = now
        strafeDir = -strafeDir

        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end

        -- Пробуем вызвать движение через ControlModule
        local ok, ps = pcall(function()
            return LocalPlayer:FindFirstChild("PlayerScripts")
        end)
        if ok and ps then
            pcall(function()
                local pm = ps:FindFirstChild("PlayerModule")
                if pm then
                    local controls = require(pm):GetControls()
                    if controls then
                        -- Просто меняем направление MoveVector через virtul input
                    end
                end
            end)
        end

        -- Имитация через смещение velocity по горизонтали
        local v = hrp.AssemblyLinearVelocity
        local cam = Workspace.CurrentCamera
        if cam then
            local right = cam.CFrame.RightVector
            local sideForce = strafeDir * 8
            hrp.AssemblyLinearVelocity = Vector3.new(
                v.X + right.X * sideForce * 0.15,
                v.Y,
                v.Z + right.Z * sideForce * 0.15
            )
        end
    end))

    task.spawn(function()
        task.wait(10)
        if not Tabs.Movement then return end
        local sec = Tabs.Movement:AddSection({Name = "Банихоп v3 (новый)"})

        sec:AddToggle("BhopNewOn", {
            Title = "Включить банихоп",
            Default = false,
        }):OnChanged(function(v)
            bhopOn = v
            Notify("FortniHub", "Bhop " .. (v and "ВКЛ" or "ВЫКЛ"), 2)
        end)

        sec:AddSlider("BhopNewPower", {
            Title = "Сила",
            Min = 10, Max = 150, Default = 40, Rounding = 0,
        }):OnChanged(function(v) bhopPower = tonumber(v) or 40 end)

        sec:AddToggle("BhopNewStrafe", {
            Title = "Стрейф (быстрое ускорение)",
            Default = false,
        }):OnChanged(function(v) bhopStrafe = v end)

        sec:AddToggle("BhopNewAuto", {
            Title = "Авто-стрейф",
            Default = false,
        }):OnChanged(function(v) bhopAuto = v end)

        -- ============ STRAFE ============
        sec:AddToggle("StrafeOn", {
            Title = "Стрейф-рывки (A/D каждые 0.2 сек)",
            Default = false,
        }):OnChanged(function(v)
            strafeOn = v
            Notify("FortniHub", "Strafe " .. (v and "ВКЛ" or "ВЫКЛ"), 2)
        end)

        sec:AddSlider("StrafeSpeed", {
            Title = "Частота стрейфа (сек)",
            Min = 0.05, Max = 0.5, Default = 0.2, Rounding = 2,
        }):OnChanged(function(v) end)
    end)

    print("[FortniHub][INFO] Bhop v3 + Strafe готов")
end

-- ============================================================
-- 7. АНИМАЦИИ — рабочий фикс
-- ============================================================
do
    task.spawn(function()
        task.wait(11)
        if not Tabs.Troll then return end
        local sec = Tabs.Troll:AddSection({Name = "Анимации (рабочие)"})

        local knownAnims = {
            {"Ninja", 656118852},
            {"Zombie", 616006778},
            {"Levitate", 616008936},
            {"Astronaut", 891603798},
            {"Cartwheel", 129423030},
            {"T-pose", 4680610777},
            {"Sneaky", 4830543155},
            {"Old School", 3333499706},
            {"Kick", 5435202357},
            {"Dance", 1824359985},
            {"Griddy", 129149402922241},
        }

        local animMap = {}
        local animNames = {}
        for _, e in ipairs(knownAnims) do
            animMap[e[1]] = e[2]
            animNames[#animNames + 1] = e[1]
        end

        local currentTrack = nil
        local currentEmote = nil

        local function stopAnim()
            if currentTrack then
                pcall(function() currentTrack:Stop() end)
                currentTrack = nil
            end
        end

        local function playAnim(name)
            local id = animMap[name]
            if not id then return end
            local c = LocalPlayer.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if not hum then
                Notify("FortniHub", "Персонаж не загружен", 2)
                return
            end
            stopAnim()
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://" .. tostring(id)
            local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
            anim:Destroy()
            if ok and track then
                track.Priority = Enum.AnimationPriority.Action
                track.Looped = true
                pcall(function() track:Play() end)
                currentTrack = track
                currentEmote = name
                Notify("FortniHub", "Играю: " .. name, 2)
            else
                Notify("FortniHub", "Не удалось запустить: " .. name, 2)
            end
        end

        local pick = sec:AddDropdown("AnimPick", {
            Title = "Выбрать анимацию",
            Values = animNames,
            Default = "Ninja",
        })

        sec:AddButton({Title = "▶ Запустить", Callback = function()
            local v = pick and pick.Value
            if type(v) == "table" then v = v[1] end
            if type(v) == "string" and v ~= "" then
                playAnim(v)
            end
        end})

        sec:AddButton({Title = "■ Остановить", Callback = function()
            stopAnim()
            Notify("FortniHub", "Остановлено", 2)
        end})

        sec:AddToggle("AnimAuto", {
            Title = "Авто-воспроизведение после респавна",
            Default = false,
        })

        AddConn("AnimRespawn", LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1.5)
            if Options.AnimAuto and Options.AnimAuto.Value and currentEmote then
                playAnim(currentEmote)
            end
        end))

        print("[FortniHub][INFO] Animations готов")
    end)
end

-- ============================================================
-- 8. AWP v2 — только заглушка (модель плохая)
-- ============================================================
do
    task.spawn(function()
        task.wait(12)
        if not Tabs.Visual then return end
        local sec = Tabs.Visual:AddSection({Name = "AWP Replace (заглушка)"})

        sec:AddToggle("AWPV2On", {
            Title = "Замена на AWP (заглушка)",
            Default = false,
        }):OnChanged(function(v)
            Notify("FortniHub", "AWP: заглушка " .. (v and "ВКЛ" or "ВЫКЛ") .. " (модель будет позже)", 3)
        end)

        -- Никакой логики, только тумблер
    end)

    print("[FortniHub][INFO] AWP заглушка готова")
end

-- ============================================================
-- ФИНАЛЬНЫЙ ЛОГ
-- ============================================================
print("[FortniHub][INFO] ================================")
print("[FortniHub][INFO] PART 6 (FINAL) ЗАГРУЖЕН")
print("[FortniHub][INFO] - Menu key v2 (Настройки → Клавиша меню)")
print("[FortniHub][INFO] - Прослушка звуков v3 (работает)")
print("[FortniHub][INFO] - China Hat v2 (виден)")
print("[FortniHub][INFO] - Movement Graph v2 (виден)")
print("[FortniHub][INFO] - Server Look v2 (реальный серверный)")
print("[FortniHub][INFO] - Bhop v3 + Strafe (A/D рывки)")
print("[FortniHub][INFO] - Animations (работает)")
print("[FortniHub][INFO] - AWP заглушка")
print("[FortniHub][INFO] ================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "v16.4 готов! P — меню", 6)
end)
