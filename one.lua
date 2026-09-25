-- ============================================================
-- FORTNIHUB v15.2 by HOTI x SHITARO
-- REBUILD EDITION — 3-PART RELEASE
-- Part 1/3: Core, UI, HUD v2, Silent Aim v15.1, Knife Silent,
--           KillAura v2, AutoFarm v2, Combat, Movement
-- ============================================================

-- LPH shim (для совместимости с друг-кодом)
if not LPH_OBFUSCATED then
    local a = function() end
    local g = getgenv and getgenv() or _G
    g.LPH_ATTRIBUTES = a
    g.ENCRYPT, g.VM, g.PRESET, g.OPTIMIZE, g.TRANSFORM, g.ERROR_HANDLING = a, a, a, a, a, a
    g.UNROLL, g.INLINE, g.NO_UPVALUES = a, a, a
    g.NONE, g.OPAL, g.ONYX, g.FAST, g.BALANCED, g.SECURE = a, a, a, a, a, a
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local THEME = Color3.fromRGB(138, 92, 246)
local THEME_LIGHT = Color3.fromRGB(178, 152, 255)
local THEME_OK = Color3.fromRGB(80, 240, 120)
local THEME_WARN = Color3.fromRGB(255, 200, 80)
local THEME_ERR = Color3.fromRGB(255, 80, 80)
local VERSION = "15.2.0"

pcall(function() if setfpscap then setfpscap(0) end end)

-- ============================================================
-- SAFE RANDOM — фикс "invalid argument #2 to 'random'"
-- ============================================================
do
    local orig = math.random
    math.random = function(a, b)
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
        local IMAX, IMIN = 2147483647, -2147483648
        if a < IMIN or b > IMAX then
            return a + (b - a) * orig()
        end
        return orig(math.floor(a), math.floor(b))
    end
end

-- ============================================================
-- STATE
-- ============================================================
local S = {
    fpsCap = 0, isFrozen = false, sgActive = false, lastMoveTime = 0,
    wallBounce = false, customJumpPower = false,
    mobileLocked = false, voteRunning = false, touchFling = false,
    farmRunning = false, farmAnchored = false, farmAvoidMurderer = false,
    farmAutoKill = false, farmLastCoinTime = 0, farmTimeoutStart = 0,
    farmLastCoinCount = 0, farmBlocked = {}, farmV2 = false, farmDownDepth = 14,
    recentlyTouched = {},
    quietShotBind = Enum.KeyCode.E,
    awpEntries = {}, awpHandleOrig = nil,
    bindPopupActive = false, bindPopupTarget = nil,
    grabFailed = false, isGrabbing = false, charCacheTime = 0,
}

local Cache = {
    localHRP = nil, localHum = nil,
    guns = {}, coins = {},
    nameESP = {}, distESP = {},
}

local Connections = {}
local MobileButtons = {}
local BindList = {}
local BindKeyCache = {}
local BindTimeCache = {}
local ModuleNameToTitle = {}

local Window, Options, Tabs = nil, nil, {}
local ShootBtnRef = nil
local MobUI, TouchFlyFrame, TopHUDGui, CoordGui, ESPFolder = nil, nil, nil, nil, nil
local FPSLabel, PingLabel, RoundLabel, CoordLabel = nil, nil, nil, nil

local flyKeys = { W=false, A=false, S=false, D=false, UP=false, DOWN=false }

local OriginalLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    FOV = Camera.FieldOfView,
}

-- ============================================================
-- LOCALIZATION
-- ============================================================
local L_ru = {
    tab_combat="Бой", tab_movement="Движение", tab_farm="Автофарм", tab_visual="Визуал",
    tab_effects="Эффекты", tab_troll="Троллинг", tab_utility="Утилиты",
    tab_mobile="Мобильный", tab_binds="Клавиши", tab_settings="Настройки",
    kill_aura="Килл Аура", radius="Радиус", auto_grab_gun="Авто-подбор пистолета",
    speed_hack="Скорость", walk_speed="Скорость ходьбы", fly="Полёт", fly_speed="Скорость полёта",
    speed_glitch="Спидглитч", glitch_speed="Скорость глитча",
    bunny_hop="Банихоп", max_speed="Макс. скорость", accel_time="Время разгона",
    noclip="Noclip", spinbot="Спинбот", spin_speed="Скорость вращения",
    inf_jump="Бесконечный прыжок", jump_power="Сила прыжка",
    freeze="Заморозка", freeze_speed="Скорость (Freeze)",
    wall_bounce="Отскок от стен", wall_force="Сила отскока",
    autofarm="Автофарм", farm_speed="Скорость фарма",
    avoid_murderer="Избегать маньяка", auto_kill_aura="Авто-килл при 40",
    autocollect="Автосбор рядом",
    player_esp="ESP игроков", name_esp="ESP имён", dist_esp="ESP дистанции",
    gun_esp="ESP пистолета", coin_esp="ESP монет",
    fullbright="Fullbright", fov="FOV", stretch="Aspect",
    fps_cap="Лимит FPS",
    tp_lobby="ТП в Лобби", tp_map="ТП на Карту", tp_murderer="ТП к Убийце",
    tp_sheriff="ТП к Шерифу", tp_player="ТП к игроку",
    spam_message="Текст спама", spam_chat="Спам в чат", vote_boost="Мульти-голосование",
    invis="Невидимость", anti_afk="Anti-AFK", rejoin="Переподключиться",
    server_hop="Сменить сервер", select_modules_multi="Выбрать модули",
    freeze_buttons="Заморозить кнопки", create_selected="Создать выбранные",
    clear_all="Очистить всё", module="Модуль", set_bind="Установить бинд",
    clear_binds="Очистить бинды", notify_toggles="Уведомления",
    show_hud="Показывать HUD", coord_mode="Режим координат", language="Язык",
    unload="Выгрузить скрипт", loaded="Загружено! P - меню",
    player_not_found="Игрок не найден", binds_cleared="Бинды удалены",
    nothing_selected="Ничего не выбрано", freeze_first="Разморозь кнопки",
    notify_title="FortniHub", role_murderer="Убийца", role_sheriff="Шериф",
    role_innocent="Невиновный", role_lobby="Лобби",
    lang_saved="Язык сохранён! Перезагрузи скрипт",
    grab_fail="Не удалось подобрать", troll_egor="Супер-медленный",
    troll_lag="Фейк-лаги", quiet_shot="Тихий выстрел",
    quiet_shot_bind="Клавиша", quiet_shot_predict="Предикт",
    quiet_shot_predict_val="Сила предикта", not_sheriff="Ты не Шериф!",
    kill_sheriff="Убить Шерифа", kill_done="Убит: ", not_murderer="Ты не Убийца!",
    invis_on="Невидимость ВКЛ", invis_off="Невидимость ВЫКЛ",
    farm_full="Рюкзак полон!", invis_nf="Кнопка невидимости не найдена",
    vote_running="Голосование уже бустится...", vote_done="Голосование бустнуто!",
    go="ПОЕХАЛИ", farm_restart="Фарм перезапущен",
    freeze_on="Заморозка ВКЛ", freeze_off="Заморозка ВЫКЛ",
    suicide="Умереть", jump_power_custom="Кастомная сила прыжка",
    awp_replace="Замена оружия на AWP", round_time="Раунд",
    bind_popup_title="Бинд модуля",
    bind_popup_hint="Нажми клавишу или кнопку мыши...",
    bind_popup_close="Отмена", bind_set="Бинд установлен: ",
    bind_reset="Бинд сброшен: ", shoot_btn="ВЫСТРЕЛ",
    show_shoot_btn="Показывать кнопку Shoot",
}
local L_en = {}
for k in pairs(L_ru) do L_en[k] = k end
local CurrentLang = "ru"
if _G.FortniHubLang then CurrentLang = _G.FortniHubLang end
pcall(function()
    if isfile and isfile("FortniHubLang.txt") then
        local s = readfile("FortniHubLang.txt")
        if s == "ru" or s == "en" then CurrentLang = s; _G.FortniHubLang = s end
    end
end)
local function L(key)
    if CurrentLang == "ru" then return L_ru[key] or L_en[key] or key end
    return L_en[key] or key
end

-- ============================================================
-- LOGGING
-- ============================================================
local function logInfo(m) print("[FortniHub][INFO] "..tostring(m)) end
local function logWarn(m) print("[FortniHub][WARN] "..tostring(m)) end
local function logErr(m) print("[FortniHub][ERR] "..tostring(m)) end
logInfo("Скрипт запущен, версия "..VERSION)

-- ============================================================
-- HELPERS
-- ============================================================
local function AddConn(name, conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name] = conn
end

local function RefreshCharCache()
    if tick() - S.charCacheTime < 0.5 then return end
    S.charCacheTime = tick()
    if LocalPlayer.Character then
        Cache.localHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        Cache.localHum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    else
        Cache.localHRP = nil; Cache.localHum = nil
    end
end

local function GetHRP(p)
    if p and p ~= LocalPlayer then
        if p.Character then return p.Character:FindFirstChild("HumanoidRootPart") end
        return nil
    end
    RefreshCharCache()
    return Cache.localHRP
end

local function GetHum()
    RefreshCharCache()
    return Cache.localHum
end

local function GetRole(p)
    if not p or not p.Character then return "lobby" end
    local c = p.Character
    local bp = p:FindFirstChild("Backpack")
    if c:FindFirstChild("Knife") then return "murderer" end
    if bp and bp:FindFirstChild("Knife") then return "murderer" end
    if c:FindFirstChild("Gun") then return "sheriff" end
    if bp and bp:FindFirstChild("Gun") then return "sheriff" end
    return "innocent"
end

local function GetRoleColor(r)
    if r == "murderer" then return Color3.fromRGB(255, 60, 60) end
    if r == "sheriff" then return Color3.fromRGB(60, 140, 255) end
    if r == "lobby" then return Color3.fromRGB(180, 180, 180) end
    return Color3.fromRGB(60, 220, 100)
end

local function GetCoinCount()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGUI")
    if not mg then return 0 end
    local g = mg:FindFirstChild("Game")
    local bag = g and g:FindFirstChild("CoinBag")
    local cont = bag and bag:FindFirstChild("Container")
    local amt = cont and cont:FindFirstChild("Amount")
    if amt and amt.Text then
        local t = amt.Text
        if t:lower():find("full") or t:lower():find("max") then return 40 end
        return tonumber(t:match("^(%d+)")) or 0
    end
    return 0
end

local function GetRoundTime()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return "--:--" end
    local scope = pg:FindFirstChild("MainGUI") or pg
    for _, d in ipairs(scope:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text then
            local t = d.Text
            if t:match("^%d+:%d+$") then return t end
            if t:match("^%d+m%s*%d+s$") then return t end
        end
    end
    return "--:--"
end

local function MakeDraggable(gui, cond)
    local d, ds, sp = false, nil, nil
    gui.InputBegan:Connect(function(i)
        if cond and not cond() then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            d = true; ds = i.Position; sp = gui.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not d then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local delta = i.Position - ds
            gui.Position = UDim2.new(sp.X.Scale, sp.X.Offset + delta.X, sp.Y.Scale, sp.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then d = false end
    end)
end

local function GetContainers()
    local list = {CoreGui}
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h and h ~= CoreGui then table.insert(list, h) end
    end
    pcall(function() if LocalPlayer.PlayerGui then table.insert(list, LocalPlayer.PlayerGui) end end)
    return list
end

local function ClickExternalButton(keywords)
    for _, cont in ipairs(GetContainers()) do
        for _, gui in ipairs(cont:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, d in ipairs(gui:GetDescendants()) do
                    if d:IsA("TextButton") then
                        local txt = ""
                        pcall(function() txt = tostring(d.Text or "") end)
                        local t = txt:lower():gsub("%s+", "")
                        for _, kw in ipairs(keywords) do
                            local kk = kw:lower():gsub("%s+", "")
                            if t == kk or t:find(kk) then
                                pcall(function()
                                    if firesignal then firesignal(d.MouseButton1Click) end
                                    if fireclickdetector then fireclickdetector(d) end
                                    d:Activate()
                                end)
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================
-- CLEANUP OLD GUIs
-- ============================================================
do
    local MY = { FH_MobileUI=true, FH_TopHUDGui=true, FH_TopHUDGui_v2=true, FH_OpenScriptGui=true,
                 FH_CoordGui=true, FortniHubLoadingGui=true, Fluent=true, FH_BindPopup=true, FH_ESPFolder=true }
    for _, parent in ipairs(GetContainers()) do
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name
                local kill = MY[n] or false
                if n == "ScreenGui" or n == "Fluent" then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("TextLabel") and string.find(tostring(d.Text or ""), "FortniHub") then kill = true; break end
                    end
                end
                if kill then pcall(function() gui:Destroy() end) end
            end
        end
    end
end
task.wait(0.3)

-- ============================================================
-- LOADING SCREEN
-- ============================================================
do
    local Lg = Instance.new("ScreenGui")
    Lg.Name = "FortniHubLoadingGui"; Lg.ResetOnSpawn = false; Lg.Parent = CoreGui
    local F = Instance.new("Frame")
    F.Size = UDim2.fromOffset(400, 200); F.Position = UDim2.new(0.5, -200, 0.5, -100)
    F.BackgroundColor3 = Color3.fromRGB(20, 20, 20); F.BorderSizePixel = 0; F.Parent = Lg
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 10)
    local st = Instance.new("UIStroke", F); st.Color = THEME; st.Thickness = 2
    local T = Instance.new("TextLabel", F)
    T.Size = UDim2.new(1, 0, 0, 30); T.Position = UDim2.new(0, 0, 0, 25)
    T.BackgroundTransparency = 1; T.Font = Enum.Font.GothamBold
    T.Text = "FortniHub v"..VERSION; T.TextColor3 = Color3.new(1, 1, 1); T.TextSize = 22
    local T2 = Instance.new("TextLabel", F)
    T2.Size = UDim2.new(1, 0, 0, 20); T2.Position = UDim2.new(0, 0, 0, 52)
    T2.BackgroundTransparency = 1; T2.Font = Enum.Font.Gotham
    T2.Text = "REBUILD EDITION by HOTI"; T2.TextColor3 = THEME_LIGHT; T2.TextSize = 14
    local T3 = Instance.new("TextLabel", F)
    T3.Size = UDim2.new(1, 0, 0, 18); T3.Position = UDim2.new(0, 0, 0, 76)
    T3.BackgroundTransparency = 1; T3.Font = Enum.Font.Gotham
    T3.Text = "Загрузка..."; T3.TextColor3 = Color3.fromRGB(180, 180, 200); T3.TextSize = 12
    local BG = Instance.new("Frame", F)
    BG.Size = UDim2.new(0.8, 0, 0, 16); BG.Position = UDim2.new(0.1, 0, 0.72, 0)
    BG.BackgroundColor3 = Color3.fromRGB(35, 35, 35); BG.BorderSizePixel = 0
    Instance.new("UICorner", BG).CornerRadius = UDim.new(0, 8)
    local Bf = Instance.new("Frame", BG)
    Bf.Size = UDim2.new(0, 0, 1, 0); Bf.BackgroundColor3 = THEME; Bf.BorderSizePixel = 0
    Instance.new("UICorner", Bf).CornerRadius = UDim.new(0, 8)
    local t0 = os.clock()
    while os.clock() - t0 < 1.2 do
        local a = (os.clock() - t0) / 1.2
        Bf.Size = UDim2.new(a, 0, 1, 0)
        T3.Text = "Загрузка "..math.floor(a * 100).."%"
        task.wait()
    end
    task.wait(0.1)
    Lg:Destroy()
end

-- ============================================================
-- SAFE HTTP / LOADSTRING / RUN
-- ============================================================
local function safeHttpGet(url, name)
    if type(url) ~= "string" or url == "" then return nil end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not ok or type(body) ~= "string" or #body < 32 then
        logWarn("HttpGet fail: "..tostring(name)); return nil
    end
    local head = body:sub(1, 200):lower()
    if head:find("<!doctype") or head:find("<html") or head:find("not found") then
        logWarn("HTML/404: "..tostring(name)); return nil
    end
    return body
end

local function safeLoadstring(body, name)
    if type(body) ~= "string" or #body == 0 then return nil end
    local fn, err = loadstring(body, "@"..tostring(name))
    if type(fn) ~= "function" then
        logWarn("Loadstring: "..tostring(name)..": "..tostring(err)); return nil
    end
    return fn
end

local function safeRun(fn, name)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn)
    if not ok then
        logWarn("Run "..tostring(name)..": "..tostring(res)); return nil
    end
    return res
end

-- ============================================================
-- FLUENT UI
-- ============================================================
local Fluent, SaveManager, InterfaceManager
do
    logInfo("Загружаю Fluent UI...")
    local urls = {
        "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/src/init.lua",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/src/init.lua",
    }
    local fb
    for _, u in ipairs(urls) do
        local b = safeHttpGet(u, "Fluent")
        if b and safeLoadstring(b, "Fluent") then fb = b; break end
    end
    if not fb then logErr("Не удалось загрузить Fluent UI!"); return end
    Fluent = safeRun(safeLoadstring(fb, "Fluent"), "Fluent")
    if type(Fluent) ~= "table" then logErr("Fluent не таблица"); return end
    logInfo("Fluent загружен")

    local b1 = safeHttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", "SaveManager")
    if b1 then local f = safeLoadstring(b1, "SaveManager"); if f then SaveManager = safeRun(f, "SaveManager") end end
    local b2 = safeHttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", "InterfaceManager")
    if b2 then local f = safeLoadstring(b2, "InterfaceManager"); if f then InterfaceManager = safeRun(f, "InterfaceManager") end end
end

-- ============================================================
-- NOTIFY
-- ============================================================
local lastNotify = {}
local function Notify(t, c, d)
    local k = tostring(t).."|"..tostring(c)
    if lastNotify[k] and (tick() - lastNotify[k]) < 0.6 then return end
    lastNotify[k] = tick()
    pcall(function()
        if Fluent and Fluent.Notify then
            Fluent:Notify({Title = t, Content = c, Duration = d or 3})
        end
    end)
end

-- ============================================================
-- HUD v2 — PILL STYLE (Madium | FPS | Ping)
-- ============================================================
do
    TopHUDGui = Instance.new("ScreenGui")
    TopHUDGui.Name = "FH_TopHUDGui_v2"
    TopHUDGui.ResetOnSpawn = false
    TopHUDGui.IgnoreGuiInset = true
    TopHUDGui.DisplayOrder = 500
    TopHUDGui.Enabled = false
    TopHUDGui.Parent = CoreGui

    local Pill = Instance.new("Frame")
    Pill.Name = "Pill"
    Pill.AnchorPoint = Vector2.new(0.5, 0)
    Pill.Position = UDim2.new(0.5, 0, 0, 12)
    Pill.Size = UDim2.fromOffset(360, 38)
    Pill.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    Pill.BackgroundTransparency = 0.08
    Pill.BorderSizePixel = 0
    Pill.Active = true
    Pill.Parent = TopHUDGui
    MakeDraggable(Pill)
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", Pill)
    stroke.Color = Color3.fromRGB(50, 50, 60); stroke.Thickness = 1; stroke.Transparency = 0.4
    local grad = Instance.new("UIGradient", Pill)
    grad.Rotation = 90
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 22)),
    })
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.6),
        NumberSequenceKeypoint.new(1, 0.92),
    })

    local function makeSegment(xOffset, width)
        local seg = Instance.new("Frame")
        seg.BackgroundTransparency = 1
        seg.Position = UDim2.fromOffset(xOffset, 0)
        seg.Size = UDim2.fromOffset(width, 38)
        seg.Parent = Pill
        return seg
    end
    local function makeDivider(xOffset)
        local d = Instance.new("Frame")
        d.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
        d.BorderSizePixel = 0
        d.Position = UDim2.new(0, xOffset, 0.5, -9)
        d.Size = UDim2.fromOffset(1, 18)
        d.Parent = Pill
    end

    local seg1 = makeSegment(8, 116)
    local logo = Instance.new("TextLabel")
    logo.BackgroundTransparency = 1
    logo.Size = UDim2.fromOffset(20, 38); logo.Position = UDim2.fromOffset(8, 0)
    logo.Font = Enum.Font.GothamBold; logo.Text = "⚙"; logo.TextSize = 16
    logo.TextColor3 = Color3.fromRGB(200, 200, 220); logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = seg1

    local nameLabel = Instance.new("TextLabel")
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.fromOffset(80, 38); nameLabel.Position = UDim2.fromOffset(30, 0)
    nameLabel.Font = Enum.Font.GothamBold; nameLabel.Text = "FortniHub"; nameLabel.TextSize = 14
    nameLabel.TextColor3 = Color3.fromRGB(240, 240, 250); nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = seg1
    makeDivider(128)

    local seg2 = makeSegment(132, 116)
    local fpsIcon = Instance.new("TextLabel")
    fpsIcon.BackgroundTransparency = 1
    fpsIcon.Size = UDim2.fromOffset(20, 38); fpsIcon.Position = UDim2.fromOffset(8, 0)
    fpsIcon.Font = Enum.Font.GothamBold; fpsIcon.Text = "⟳"; fpsIcon.TextSize = 16
    fpsIcon.TextColor3 = Color3.fromRGB(120, 220, 120); fpsIcon.TextXAlignment = Enum.TextXAlignment.Left
    fpsIcon.Parent = seg2

    FPSLabel = Instance.new("TextLabel")
    FPSLabel.BackgroundTransparency = 1
    FPSLabel.Size = UDim2.fromOffset(60, 38); FPSLabel.Position = UDim2.fromOffset(30, 0)
    FPSLabel.Font = Enum.Font.GothamBold; FPSLabel.Text = "60"; FPSLabel.TextSize = 15
    FPSLabel.TextColor3 = Color3.fromRGB(120, 220, 120); FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
    FPSLabel.Parent = seg2

    local fpsWord = Instance.new("TextLabel")
    fpsWord.BackgroundTransparency = 1
    fpsWord.Size = UDim2.fromOffset(30, 38); fpsWord.Position = UDim2.fromOffset(72, 0)
    fpsWord.Font = Enum.Font.Gotham; fpsWord.Text = "FPS"; fpsWord.TextSize = 11
    fpsWord.TextColor3 = Color3.fromRGB(140, 140, 150); fpsWord.TextXAlignment = Enum.TextXAlignment.Left
    fpsWord.Parent = seg2
    makeDivider(250)

    local seg3 = makeSegment(254, 100)
    local pingIcon = Instance.new("TextLabel")
    pingIcon.BackgroundTransparency = 1
    pingIcon.Size = UDim2.fromOffset(20, 38); pingIcon.Position = UDim2.fromOffset(8, 0)
    pingIcon.Font = Enum.Font.GothamBold; pingIcon.Text = "📶"; pingIcon.TextSize = 14
    pingIcon.TextColor3 = Color3.fromRGB(120, 220, 120); pingIcon.TextXAlignment = Enum.TextXAlignment.Left
    pingIcon.Parent = seg3

    PingLabel = Instance.new("TextLabel")
    PingLabel.BackgroundTransparency = 1
    PingLabel.Size = UDim2.fromOffset(46, 38); PingLabel.Position = UDim2.fromOffset(30, 0)
    PingLabel.Font = Enum.Font.GothamBold; PingLabel.Text = "0"; PingLabel.TextSize = 15
    PingLabel.TextColor3 = Color3.fromRGB(120, 220, 120); PingLabel.TextXAlignment = Enum.TextXAlignment.Left
    PingLabel.Parent = seg3

    local msWord = Instance.new("TextLabel")
    msWord.BackgroundTransparency = 1
    msWord.Size = UDim2.fromOffset(24, 38); msWord.Position = UDim2.fromOffset(72, 0)
    msWord.Font = Enum.Font.Gotham; msWord.Text = "ms"; msWord.TextSize = 11
    msWord.TextColor3 = Color3.fromRGB(140, 140, 150); msWord.TextXAlignment = Enum.TextXAlignment.Left
    msWord.Parent = seg3
end

-- ============================================================
-- COORD GUI
-- ============================================================
do
    CoordGui = Instance.new("ScreenGui")
    CoordGui.Name = "FH_CoordGui"; CoordGui.ResetOnSpawn = false
    CoordGui.Enabled = false; CoordGui.DisplayOrder = 100; CoordGui.Parent = CoreGui
    CoordLabel = Instance.new("TextLabel", CoordGui)
    CoordLabel.Size = UDim2.fromOffset(400, 30); CoordLabel.Position = UDim2.new(1, -420, 0, 60)
    CoordLabel.BackgroundTransparency = 1; CoordLabel.Font = Enum.Font.GothamBold
    CoordLabel.Text = "X: 0 Y: 0 Z: 0"; CoordLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    CoordLabel.TextSize = 24; CoordLabel.TextXAlignment = Enum.TextXAlignment.Right
    CoordLabel.TextStrokeTransparency = 0; CoordLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
end

-- ============================================================
-- ESP FOLDER
-- ============================================================
ESPFolder = Instance.new("Folder", CoreGui); ESPFolder.Name = "FH_ESPFolder"

-- ============================================================
-- MOBILE UI
-- ============================================================
do
    MobUI = Instance.new("ScreenGui")
    MobUI.Name = "FH_MobileUI"; MobUI.ResetOnSpawn = false; MobUI.Parent = CoreGui

    TouchFlyFrame = Instance.new("Frame")
    TouchFlyFrame.Size = UDim2.fromOffset(180, 120); TouchFlyFrame.Position = UDim2.new(0.7, 0, 0.6, 0)
    TouchFlyFrame.BackgroundTransparency = 0.6; TouchFlyFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    TouchFlyFrame.Visible = false; TouchFlyFrame.Parent = MobUI
    local function mkFlyBtn(name, text, px, py, sx, sy)
        local b = Instance.new("TextButton")
        b.Name = name; b.Text = text; b.Size = UDim2.new(sx, 0, sy, 0); b.Position = UDim2.new(px, 0, py, 0)
        b.BackgroundColor3 = Color3.fromRGB(40, 40, 40); b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold; b.Parent = TouchFlyFrame
        b.MouseButton1Down:Connect(function() flyKeys[name] = true end)
        b.MouseButton1Up:Connect(function() flyKeys[name] = false end)
        b.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                flyKeys[name] = false
            end
        end)
    end
    mkFlyBtn("W", "W", 0.35, 0.05, 0.3, 0.28)
    mkFlyBtn("S", "S", 0.35, 0.65, 0.3, 0.28)
    mkFlyBtn("A", "A", 0.02, 0.35, 0.3, 0.28)
    mkFlyBtn("D", "D", 0.68, 0.35, 0.3, 0.28)
    mkFlyBtn("UP", "^", 0.02, 0.05, 0.28, 0.28)
    mkFlyBtn("DOWN", "v", 0.68, 0.65, 0.28, 0.28)
    MakeDraggable(TouchFlyFrame)

    local ShootBtn = Instance.new("TextButton")
    ShootBtn.Name = "FH_ShootBtn"; ShootBtn.Size = UDim2.fromOffset(68, 68)
    ShootBtn.Position = UDim2.new(1, -84, 1, -160)
    ShootBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40); ShootBtn.BackgroundTransparency = 0.15
    ShootBtn.Text = L("shoot_btn"); ShootBtn.TextColor3 = Color3.new(1, 1, 1)
    ShootBtn.Font = Enum.Font.GothamBlack; ShootBtn.TextSize = 13
    ShootBtn.Active = true; ShootBtn.Visible = false; ShootBtn.Parent = MobUI
    Instance.new("UICorner", ShootBtn).CornerRadius = UDim.new(1, 0)
    local st = Instance.new("UIStroke", ShootBtn); st.Color = THEME; st.Thickness = 2
    MakeDraggable(ShootBtn)
    ShootBtnRef = ShootBtn
end

-- ============================================================
-- CACHE GUNS / COINS
-- ============================================================
for _, v in ipairs(Workspace:GetDescendants()) do
    if v.Name == "GunDrop" then table.insert(Cache.guns, v) end
    if v.Name == "Coin_Server" or v.Name == "Coin" then table.insert(Cache.coins, v) end
end
AddConn("CacheAdd", Workspace.DescendantAdded:Connect(function(v)
    if v.Name == "GunDrop" then table.insert(Cache.guns, v) end
    if v.Name == "Coin_Server" or v.Name == "Coin" then table.insert(Cache.coins, v) end
end))
AddConn("CacheRem", Workspace.DescendantRemoving:Connect(function(v)
    if v.Name == "GunDrop" then local i = table.find(Cache.guns, v); if i then table.remove(Cache.guns, i) end end
    if v.Name == "Coin_Server" or v.Name == "Coin" then local i = table.find(Cache.coins, v); if i then table.remove(Cache.coins, i) end end
end))

-- ============================================================
-- SILENT AIM v15.1 (заменяет QuietShot)
-- ============================================================
local SILENT = {
    enabled = false,
    predict = true,
    force = false,
    auto_on = false,
    auto_delay = 0.08,
    am_sheriff = false,
    last_shot = 0,
    stand_off = 15,
}
_G.SILENT_AIM_ACTIVE = false
getgenv().SILENT_AIM_ACTIVE = false

do
    local P = { snap = 48, ring = 48, hit_r = 2.1, pad = 2.6, min_span = 5, max_span = 90,
                acc_t = 0.15, acc_max = 280, acc_min = 40, speed_floor = 26 }
    local snap_t = table.create(P.snap, 0)
    local snap_p = table.create(P.snap, Vector3.zero)
    local snap_n, snap_i = 0, 0
    local TR = { part=nil, pos=nil, time=0, vel=Vector3.zero, gap=0, ready=false, fresh=Vector3.zero,
                 air=false, air_since=0, jumping=false, jump_v=0, fresh_ok=false, turn=0, clr=0, air_edge=0 }
    local EC = { rtt=0, jitter=0, seen=false, step=0, step_seen=false, ping=0 }
    local KIN = { ok=false, ax=0, az=0, smax=0 }

    local function snap_push(now, pos)
        snap_i = snap_i % P.snap + 1
        snap_t[snap_i] = now
        snap_p[snap_i] = pos
        if snap_n < P.snap then snap_n = snap_n + 1 end
    end
    local function snap_get(k)
        local idx = (snap_i - k - 1) % P.snap + 1
        return snap_t[idx], snap_p[idx]
    end
    local function sample_span() return math.max(EC.step, TR.gap) end

    local function fit_velocity()
        if snap_n < 3 then return nil end
        local newest = snap_get(0)
        local used, sum_d = 0, 0
        local win = sample_span() * 4
        for k = 0, snap_n - 1 do
            local t = snap_get(k)
            if newest - t > win then break end
            used = used + 1; sum_d = sum_d + (t - newest)
        end
        if used < 3 then return nil end
        local mean_d = sum_d / used
        local num, den = Vector3.zero, 0
        for k = 0, used - 1 do
            local t, p = snap_get(k)
            local d = (t - newest) - mean_d
            num = num + p * d; den = den + d * d
        end
        if den < 1e-8 then return nil end
        return num / den, -mean_d
    end

    local function recent_velocity()
        if snap_n < 2 then return nil end
        local newest, head = snap_get(0)
        local target_span = sample_span() * 2
        local max_span = target_span * 2
        for k = 1, snap_n - 1 do
            local t, p = snap_get(k)
            local dt = newest - t
            if dt > max_span then break end
            if dt > 0 then
                local v = (head - p) / dt
                if dt >= target_span then return v, dt * 0.5 end
            end
        end
        return nil
    end

    local function fit_kin()
        if snap_n < 5 then return nil end
        local t0 = snap_get(0)
        local win = math.max(sample_span() * 5, 0.12)
        local scale = win
        local n, s1, s2, s3, s4 = 0, 0, 0, 0, 0
        local bx0, bx1, bx2 = 0, 0, 0
        local bz0, bz1, bz2 = 0, 0, 0
        for k = 0, snap_n - 1 do
            local t, p = snap_get(k)
            local age = t0 - t
            if age > win then break end
            local u = -age / scale
            local u2 = u * u
            n = n + 1
            s1 = s1 + u; s2 = s2 + u2; s3 = s3 + u2 * u; s4 = s4 + u2 * u2
            bx0 = bx0 + p.X; bx1 = bx1 + p.X * u; bx2 = bx2 + p.X * u2
            bz0 = bz0 + p.Z; bz1 = bz1 + p.Z * u; bz2 = bz2 + p.Z * u2
        end
        if n < 5 then return nil end
        local det = n * (s2 * s4 - s3 * s3) - s1 * (s1 * s4 - s3 * s2) + s2 * (s1 * s3 - s2 * s2)
        if math.abs(det) < 1e-9 then return nil end
        local function solve(b0, b1, b2)
            local d1 = n * (b1 * s4 - s3 * b2) - b0 * (s1 * s4 - s3 * s2) + s2 * (s1 * b2 - b1 * s2)
            local d2 = n * (s2 * b2 - b1 * s3) - s1 * (s1 * b2 - b1 * s2) + b0 * (s1 * s3 - s2 * s2)
            return d1 / det, d2 / det
        end
        local cx1, cx2 = solve(bx0, bx1, bx2)
        local cz1, cz2 = solve(bz0, bz1, bz2)
        if cx1 ~= cx1 or cz1 ~= cz1 then return nil end
        return Vector3.new(cx1 / scale, 0, cz1 / scale), Vector3.new(2 * cx2 / (scale * scale), 0, 2 * cz2 / (scale * scale))
    end

    local function kin_update()
        local kv, ka = fit_kin()
        if not kv then KIN.ok = false; KIN.ax, KIN.az = 0, 0; return nil end
        KIN.ok = true
        local sp = math.sqrt(kv.X * kv.X + kv.Z * kv.Z)
        KIN.smax = (sp > KIN.smax) and sp or (KIN.smax * 0.985 + sp * 0.015)
        if ka and not TR.air then
            local am = math.sqrt(ka.X * ka.X + ka.Z * ka.Z)
            local ax, az = ka.X, ka.Z
            if am > P.acc_max and am > 0 then
                ax = ax * P.acc_max / am; az = az * P.acc_max / am
            end
            KIN.ax = KIN.ax * 0.5 + ax * 0.5
            KIN.az = KIN.az * 0.5 + az * 0.5
        else
            KIN.ax = KIN.ax * 0.5; KIN.az = KIN.az * 0.5
        end
        return kv
    end

    local function grav()
        local ok, g = pcall(function() return workspace.Gravity end)
        if ok and type(g) == "number" and g > 0 then return g end
        return 0
    end

    local target_player, target_char, target_part, target_hum

    local function refresh_target()
        local found = nil
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and type(m) == "table" and type(m.PlayerData) == "table" then
            local me = m.PlayerData[LocalPlayer.Name]
            SILENT.am_sheriff = me ~= nil and (me.Role == "Sheriff" or me.Role == "Hero")
                or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun") ~= nil)
            for name, d in pairs(m.PlayerData) do
                if type(d) == "table" and d.Role == "Murderer" and not d.Dead then
                    found = Players:FindFirstChild(name); break
                end
            end
        end
        if not found then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Knife") then
                    found = plr; break
                end
            end
        end
        if found ~= target_player then
            target_player = found; target_char, target_part, target_hum = nil, nil, nil
        end
        if not found then return end
        local char = found.Character
        if char ~= target_char then target_char = char; target_part, target_hum = nil, nil end
        if not char then return end
        if not target_part or not target_part.Parent then
            target_part = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
        end
        if not target_hum or not target_hum.Parent then
            target_hum = char:FindFirstChildOfClass("Humanoid")
        end
    end

    local function target_alive()
        if not target_part or not target_part.Parent then return false end
        if not target_hum or not target_hum.Parent then return false end
        return target_hum.Health > 0
    end

    local ray_params = RaycastParams.new()
    ray_params.FilterType = Enum.RaycastFilterType.Exclude
    ray_params.IgnoreWater = false

    local function refresh_ignore()
        local list = {}
        local char = LocalPlayer.Character
        if char then list[1] = char end
        ray_params.FilterDescendantsInstances = list
    end

    local function trace(origin, direction)
        refresh_ignore()
        return workspace:Raycast(origin, direction, ray_params)
    end

    local function origin_cframe()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        local att = hrp:FindFirstChild("GunRaycastAttachment")
        if att then return att.WorldCFrame end
        return hrp.CFrame
    end

    local function lead_time()
        if not EC.seen then return 0 end
        local stale = 0
        if TR.time > 0 and EC.step_seen then stale = math.clamp(os.clock() - TR.time, 0, EC.step) end
        return math.clamp(EC.rtt + EC.jitter * 0.5 + stale, 0, 1)
    end

    local function raw_rtt()
        local a, b
        local ok, ms = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(ms) == "number" and ms == ms and ms > 4 and ms < 800 then a = ms / 1000 end
        local fine, value = pcall(function() return LocalPlayer:GetNetworkPing() end)
        if fine and type(value) == "number" and value == value and value > 0 then
            local rtt = value * 2
            if rtt > 0.004 and rtt < 0.8 then b = rtt end
        end
        if a and b then return (a + b) * 0.5 end
        return a or b
    end

    local function sample_ping()
        local rtt = raw_rtt()
        if not rtt or rtt ~= rtt then return end
        rtt = math.clamp(rtt, 0, 1)
        if EC.seen then
            EC.jitter = EC.jitter * 0.9 + math.abs(rtt - EC.rtt) * 0.1
            EC.rtt = EC.rtt * 0.82 + rtt * 0.18
        else
            EC.rtt = rtt; EC.jitter = 0; EC.seen = true
        end
        EC.ping = EC.rtt
    end

    local function predict_from(base, span, fh)
        if span <= 0 then return base end
        local g = grav()
        local dir = fh
        if dir.Magnitude == 0 then dir = Vector3.new(TR.vel.X, 0, TR.vel.Z) end
        local y = base.Y
        if TR.air then
            local vy = TR.vel.Y
            local phase = math.max(0, os.clock() - TR.air_since)
            local modeled = TR.jump_v - g * phase
            if TR.jumping and TR.jump_v > 0 and g > 0 and phase <= TR.jump_v / g and modeled > vy then vy = modeled end
            y = base.Y + vy * span - 0.5 * g * span * span
        end
        return Vector3.new(base.X + dir.X * span, y, base.Z + dir.Z * span)
    end

    local function track(now)
        local part = target_part
        if not part or not part.Parent then
            TR.part, TR.pos, TR.ready = nil, nil, false
            return
        end
        local pos = part.Position
        if part ~= TR.part or not TR.pos then
            TR.part, TR.pos, TR.time = part, pos, now
            TR.vel, TR.ready = Vector3.zero, false
            snap_n, snap_i = 0, 0
            snap_push(now, pos); return
        end
        local dt = now - TR.time
        if dt > 0.75 or (pos - TR.pos).Magnitude > 140 then
            TR.part, TR.pos, TR.time = part, pos, now
            TR.vel, TR.ready = Vector3.zero, false
            snap_n, snap_i = 0, 0
            snap_push(now, pos); return
        end
        if dt <= 0 then return end
        if (pos - TR.pos).Magnitude == 0 then
            if TR.gap > 0 and dt >= TR.gap then TR.vel = Vector3.zero; TR.fresh = Vector3.zero end
            return
        end
        if dt <= 0.5 then
            if EC.step_seen then EC.step = EC.step * 0.85 + dt * 0.15
            else EC.step, EC.step_seen = dt, true end
        end
        TR.gap = dt
        snap_push(now, pos)
        TR.pos, TR.time = pos, now

        local fit = fit_velocity()
        local fast = recent_velocity()
        local kv = kin_update()
        local fresh = fit or fast or Vector3.zero
        if kv then fresh = Vector3.new(kv.X, fresh.Y, kv.Z) end
        TR.vel = fresh
        TR.ready = fit ~= nil or fast ~= nil
        TR.fresh, TR.fresh_ok = TR.vel, TR.ready

        local reach = 6 + math.abs(TR.vel.Y) * sample_span() * 4
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { target_char, LocalPlayer.Character }
        local hit = workspace:Raycast(pos, Vector3.new(0, -reach, 0), params)
        local was_air = TR.air
        TR.air = (hit == nil)
        if was_air ~= TR.air then
            TR.air_edge = now
            if TR.air then TR.air_since = now; TR.jump_v = math.max(TR.vel.Y, 0) end
        end
        TR.jumping = TR.air and TR.vel.Y > 1
    end

    local hit_names = {
        "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "Head",
        "RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm",
        "RightUpperLeg", "LeftUpperLeg", "Right Leg", "Left Leg",
    }

    local function pick_point(origin)
        if not target_char then return nil end
        local span = lead_time()
        local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
        local first = nil
        for _, name in ipairs(hit_names) do
            local part = target_char:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                local point = (SILENT.predict and TR.ready) and predict_from(part.Position, span, fh) or part.Position
                if not first then first = point end
                if origin then
                    local delta = point - origin
                    local dist = delta.Magnitude
                    if dist < 0.5 then return point end
                    local hit = trace(origin, delta)
                    if not hit then return point end
                    local inst = hit.Instance
                    if inst == target_char or (inst and inst:IsDescendantOf(target_char)) then return point end
                    if (hit.Position - origin).Magnitude >= dist - 0.75 then return point end
                else
                    return point
                end
            end
        end
        return first
    end

    local weapon_service, orig_mouse, orig_screen

    local function get_weapon_service()
        if weapon_service then return weapon_service end
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"))
        end)
        if ok and type(m) == "table" then weapon_service = m end
        return weapon_service
    end

    local function install_hooks()
        local m = get_weapon_service()
        if not m then return end
        pcall(function() setreadonly(m, false) end)
        if type(m.GetMouseTargetCFrame) == "function" and not orig_mouse then
            orig_mouse = m.GetMouseTargetCFrame
            local old = orig_mouse
            m.GetMouseTargetCFrame = function(self, ...)
                sample_ping()
                if SILENT.enabled and target_alive() then
                    local cf = origin_cframe()
                    local aim = pick_point(cf and cf.Position or nil)
                    if aim then return CFrame.new(aim) end
                end
                return old(self, ...)
            end
        end
        if type(m.GetTargetPosition) == "function" and not orig_screen then
            orig_screen = m.GetTargetPosition
            local old = orig_screen
            m.GetTargetPosition = function(self, x, y, ...)
                sample_ping()
                if SILENT.enabled and target_alive() then
                    local cf = origin_cframe()
                    local aim = pick_point(cf and cf.Position or nil)
                    if aim then return CFrame.new(aim) end
                end
                return old(self, x, y, ...)
            end
        end
    end

    local function uninstall_hooks()
        if not weapon_service then return end
        pcall(function() setreadonly(weapon_service, false) end)
        if orig_mouse then pcall(function() weapon_service.GetMouseTargetCFrame = orig_mouse end) end
        if orig_screen then pcall(function() weapon_service.GetTargetPosition = orig_screen end) end
    end

    local last_fire = 0
    local function auto_step(now)
        if not SILENT.auto_on or not SILENT.enabled or not SILENT.am_sheriff or not target_alive() then return end
        local char = LocalPlayer.Character
        local gun = char and char:FindFirstChild("Gun")
            or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun"))
        if not gun then return end
        if gun.Parent ~= char then
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(gun) end
            return
        end
        if now - last_fire < SILENT.auto_delay then return end
        local cf = origin_cframe()
        if not cf then return end
        local aim = pick_point(cf.Position)
        if not aim then return end
        local remote = gun:FindFirstChild("Shoot")
        if remote and remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer(cf, CFrame.new(aim)) end)
            last_fire = now
        end
    end

    local next_role = 0
    AddConn("SILENTTick", RunService.Heartbeat:Connect(function()
        if not SILENT.enabled then return end
        local now = os.clock()
        if now >= next_role then next_role = now + 0.2; pcall(refresh_target) end
        pcall(sample_ping)
        pcall(track, now)
        pcall(auto_step, now)
    end))
    task.spawn(function() task.wait(1); pcall(install_hooks) end)
    AddConn("SILENTHookRetry", RunService.Heartbeat:Connect(function()
        if SILENT.enabled and not orig_mouse then pcall(install_hooks) end
    end))
end
getgenv().SILENT_INSTALL_HOOKS = function()
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"))
    end)
    if ok then pcall(function() setreadonly(m, false) end) end
end

-- ============================================================
-- KNIFE SILENT THROW
-- ============================================================
local KNIFE = { silent=false, predict=true, instance_kill=false, range=400,
                lead_scale=1, lead_add=0, air_scale=0.35, throw_speed=96, impact_radius=12 }
do
    local GRAV = workspace.Gravity
    local MAX_HSPEED, MAX_VSPEED = 34, 170
    local SNAP_CAP, FIT_WINDOW = 20, 0.13
    local trackers = {}
    local ground_params = RaycastParams.new()
    ground_params.FilterType = Enum.RaycastFilterType.Exclude
    ground_params.IgnoreWater = true

    local function clamp_vel(v)
        local hm = math.sqrt(v.X * v.X + v.Z * v.Z)
        local hx, hz = v.X, v.Z
        if hm > MAX_HSPEED then local s = MAX_HSPEED / hm; hx, hz = hx * s, hz * s end
        return Vector3.new(hx, math.clamp(v.Y, -MAX_VSPEED, MAX_VSPEED), hz)
    end
    local function engine_vel(part)
        local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
        if ok and typeof(v) == "Vector3" then return clamp_vel(v) end
        return Vector3.zero
    end
    local function merge_vel(fit, lag, eng)
        if not fit then return eng end
        fit = clamp_vel(fit)
        local fh = Vector3.new(fit.X, 0, fit.Z)
        local eh = Vector3.new(eng.X, 0, eng.Z)
        local fm, em = fh.Magnitude, eh.Magnitude
        local h
        if fm < 1 and em < 1 then h = Vector3.zero
        elseif em < 1 then h = fh
        elseif fm < 1 then h = eh
        elseif fh.Unit:Dot(eh.Unit) < 0.25 then h = fh
        else h = eh * 0.75 + fh * 0.25 end
        local y
        if math.abs(eng.Y) > 0.5 then y = eng.Y
        elseif math.abs(fit.Y) > 1 then y = math.clamp(fit.Y - GRAV * (lag or 0), -MAX_VSPEED, MAX_VSPEED)
        else y = 0 end
        return Vector3.new(h.X, y, h.Z)
    end
    local function new_tracker()
        return { t=table.create(SNAP_CAP,0), p=table.create(SNAP_CAP,Vector3.zero), n=0, i=0,
                 part=nil, pos=nil, time=0, vel=Vector3.zero, gap=0.05, jitter=0, ready=false,
                 stab=1, rest_gap=3, rest_ready=false }
    end
    local function snap_push(tr, now, pos)
        tr.i = tr.i % SNAP_CAP + 1
        tr.t[tr.i] = now; tr.p[tr.i] = pos
        if tr.n < SNAP_CAP then tr.n = tr.n + 1 end
    end
    local function snap_get(tr, k)
        local idx = (tr.i - k - 1) % SNAP_CAP + 1
        return tr.t[idx], tr.p[idx]
    end
    local function fit_velocity_tr(tr)
        if tr.n < 3 then return nil end
        local newest = snap_get(tr, 0)
        local used, sum_d = 0, 0
        for k = 0, tr.n - 1 do
            local t = snap_get(tr, k)
            if newest - t > FIT_WINDOW then break end
            used = used + 1; sum_d = sum_d + (t - newest)
        end
        if used < 3 then return nil end
        local mean_d = sum_d / used
        local num, den = Vector3.zero, 0
        for k = 0, used - 1 do
            local t, p = snap_get(tr, k)
            local d = (t - newest) - mean_d
            num = num + p * d; den = den + d * d
        end
        if den < 1e-8 then return nil end
        return num / den, -mean_d
    end
    local function update_tracker(tr, char, part, now)
        local pos = part.Position
        if part ~= tr.part or not tr.pos then
            tr.part, tr.pos, tr.time = part, pos, now
            tr.vel, tr.ready = Vector3.zero, false
            tr.n, tr.i = 0, 0
            snap_push(tr, now, pos); return
        end
        local dt = now - tr.time
        local shift = (pos - tr.pos).Magnitude
        if dt > 0.75 or shift > 140 then
            tr.part, tr.pos, tr.time = part, pos, now
            tr.vel, tr.ready = Vector3.zero, false
            tr.n, tr.i = 0, 0
            snap_push(tr, now, pos); return
        end
        if shift < 0.004 or dt <= 0 then return end
        tr.gap = math.clamp(tr.gap * 0.8 + dt * 0.2, 0.012, 0.25)
        snap_push(tr, now, pos)
        tr.pos, tr.time = pos, now
        local fit, lag = fit_velocity_tr(tr)
        local fresh = merge_vel(fit, lag, engine_vel(part))
        if tr.ready then
            local a = 0.45
            local oh = Vector3.new(tr.vel.X, 0, tr.vel.Z)
            local nh = Vector3.new(fresh.X, 0, fresh.Z)
            if oh.Magnitude > 1 and nh.Magnitude > 1 and oh.Unit:Dot(nh.Unit) < 0.5 then a = 0.85 end
            tr.vel = Vector3.new(
                tr.vel.X + (fresh.X - tr.vel.X) * a,
                math.abs(fresh.Y) > 3 and fresh.Y or (tr.vel.Y + (fresh.Y - tr.vel.Y) * 0.6),
                tr.vel.Z + (fresh.Z - tr.vel.Z) * a
            )
        else
            tr.vel = fresh; tr.ready = true
        end
    end
    local function target_part_of(char)
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
    end
    local function player_alive(plr)
        local char = plr.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        return true
    end
    local function pick_target()
        local my = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not my then return nil, nil, nil end
        local origin = my.Position
        local bc, bp, bt, bd = nil, nil, nil, KNIFE.range
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and player_alive(plr) then
                local char = plr.Character
                local part = target_part_of(char)
                if part then
                    local d = (part.Position - origin).Magnitude
                    if d <= bd then bd = d; bc, bp, bt = char, part, trackers[plr] end
                end
            end
        end
        return bc, bp, bt
    end

    local lead_ping, ping_seen = 0, false
    local function sample_ping_knife()
        local ms = 0
        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(v) == "number" then ms = v end
        local s = math.clamp(ms / 1000, 0, 1)
        if ping_seen then lead_ping = lead_ping * 0.85 + s * 0.15
        else lead_ping, ping_seen = s, true end
    end

    local function throw_aim(tr, char, part, origin)
        local base = part.Position
        local travel, point = 0, base
        for _ = 1, 3 do
            local t = math.clamp(lead_ping * KNIFE.lead_scale + KNIFE.lead_add + travel, 0, 1)
            if tr and tr.ready and KNIFE.predict then
                local vel = tr.vel
                local scale = math.clamp(tr.stab, 0.3, 1) * t
                local ox, oz = vel.X * scale, vel.Z * scale
                local oy = 0
                if math.abs(vel.Y) < 80 then
                    local tv = t * KNIFE.air_scale
                    oy = math.clamp(vel.Y * tv - 0.5 * GRAV * tv * tv, -1.8, 1.8)
                end
                point = Vector3.new(base.X + ox, base.Y + oy, base.Z + oz)
            else
                point = base
            end
            if not origin or KNIFE.throw_speed <= 1 then break end
            travel = math.clamp((point - origin).Magnitude / KNIFE.throw_speed, 0, 0.7)
        end
        return point
    end

    local function get_knife()
        local char = LocalPlayer.Character
        if char then
            local k = char:FindFirstChild("Knife")
            if k then return k, true end
        end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            local k = bp:FindFirstChild("Knife")
            if k then return k, false end
        end
        return nil, false
    end

    local function knife_events()
        local knife = get_knife()
        return knife and knife:FindFirstChild("Events")
    end

    local function direct_kill(part)
        if not part or not part.Parent then return false end
        local ev = knife_events()
        if not ev then return false end
        local stabbed = ev:FindFirstChild("KnifeStabbed")
        local touched = ev:FindFirstChild("HandleTouched")
        if not stabbed or not touched then return false end
        return pcall(function()
            stabbed:FireServer()
            touched:FireServer(part)
        end)
    end

    local pending = nil

    local function resolve_throw_aim()
        if not KNIFE.silent then return nil end
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("Knife") then return nil end
        local tchar, part, tr = pick_target()
        if not part then return nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        local origin = root and root.Position or nil
        local point = throw_aim(tr, tchar, part, origin)
        return CFrame.new(point)
    end
    getgenv().KNIFE_AIM_RESOLVE = resolve_throw_aim

    local next_ping, next_track = 0, 0
    AddConn("KnifeTick", RunService.Heartbeat:Connect(function()
        if not KNIFE.silent then return end
        local now = os.clock()
        if now >= next_ping then
            next_ping = now + 0.25
            pcall(sample_ping_knife)
        end
        if now >= next_track then
            next_track = now + 0.05
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and player_alive(plr) then
                    local char = plr.Character
                    local part = target_part_of(char)
                    if part then
                        local tr = trackers[plr]
                        if not tr then tr = new_tracker() trackers[plr] = tr end
                        update_tracker(tr, char, part, now)
                    end
                end
            end
        end
    end))
end

-- ============================================================
-- KILL AURA v2
-- ============================================================
local KA2 = { on=false, dist=30, last_hit=0 }
AddConn("KAv2Tick", RunService.Heartbeat:Connect(function()
    if not KA2.on then return end
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
    end)
    if not ok or type(m) ~= "table" or type(m.PlayerData) ~= "table" then return end
    local me = m.PlayerData[LocalPlayer.Name]
    if not me or me.Role ~= "Murderer" or me.Dead then return end
    if S.farmRunning then return end
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
    if os.clock() - KA2.last_hit < 0.05 then return end
    local my_root = char:FindFirstChild("HumanoidRootPart")
    if not my_root then return end
    local victims = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local tchar = plr.Character
            if tchar then
                local thum = tchar:FindFirstChildOfClass("Humanoid")
                local tpart = tchar:FindFirstChild("HumanoidRootPart")
                if thum and thum.Health > 0 and tpart then
                    if (tpart.Position - my_root.Position).Magnitude <= KA2.dist then
                        victims[#victims + 1] = tpart
                    end
                end
            end
        end
    end
    if #victims > 0 then
        pcall(function() stabbed:FireServer() end)
        for _, v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
        KA2.last_hit = os.clock()
    end
end))

-- ============================================================
-- AUTOFARM v2 (правильный, через CoinVisual)
-- ============================================================
local FARM2 = { on=false, avoid=false, speed=23, seen=false }
AddConn("FarmV2Tick", RunService.Heartbeat:Connect(function(_, dt)
    if not FARM2.on then return end
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
    FARM2.seen = true
    local best, bd = nil, math.huge
    for _, c in ipairs(coins) do
        local d = (c.Position - hrp.Position).Magnitude
        if d < bd then bd = d; best = c end
    end
    if not best then return end
    if FARM2.avoid then
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and m and m.PlayerData then
            for name, d in pairs(m.PlayerData) do
                if type(d) == "table" and d.Role == "Murderer" and not d.Dead and name ~= LocalPlayer.Name then
                    local p = Players:FindFirstChild(name)
                    local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                    if root and (root.Position - hrp.Position).Magnitude < 40 then
                        local away = (hrp.Position - root.Position)
                        if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
                        hrp.CFrame = CFrame.new(hrp.Position + away.Unit * 20)
                        return
                    end
                end
            end
        end
    end
    local dir = best.Position - hrp.Position
    local dist = dir.Magnitude
    if dist > 0.5 then
        local step = math.min(FARM2.speed * dt, dist)
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

-- ============================================================
-- WINDOW
-- ============================================================
do
    local winOpts = {
        Title = "FortniHub MM2",
        SubTitle = "v"..VERSION.." REBUILD",
        TabWidth = 110,
        Size = UDim2.fromOffset(440, 320),
        Theme = "Darker",
        MinimizeKey = Enum.KeyCode.RightControl,
    }
    local ok, err = pcall(function() Window = Fluent:CreateWindow(winOpts) end)
    if not ok or not Window then logErr("Ошибка окна: "..tostring(err)); return end
    Options = Fluent.Options
    logInfo("Окно Fluent создано")
    if SaveManager then pcall(function() SaveManager:SetLibrary(Fluent); SaveManager:SetFolder("FortniHub/MM2") end) end
    if InterfaceManager then pcall(function() InterfaceManager:SetLibrary(Fluent); InterfaceManager:SetFolder("FortniHub/MM2") end) end
    task.wait(0.3)
end

-- ============================================================
-- BIND POPUP
-- ============================================================
local BindPopupGui, ShowBindPopup, HideBindPopup
do
    BindPopupGui = Instance.new("ScreenGui")
    BindPopupGui.Name = "FH_BindPopup"; BindPopupGui.ResetOnSpawn = false
    BindPopupGui.Enabled = false; BindPopupGui.DisplayOrder = 1000; BindPopupGui.Parent = CoreGui
    local F = Instance.new("Frame")
    F.Size = UDim2.fromOffset(300, 120); F.Position = UDim2.new(0.5, -150, 0.4, -60)
    F.BackgroundColor3 = Color3.fromRGB(20, 18, 28); F.BorderSizePixel = 0; F.Active = true; F.Parent = BindPopupGui
    Instance.new("UICorner", F).CornerRadius = UDim.new(0, 12)
    local st = Instance.new("UIStroke", F); st.Color = THEME; st.Thickness = 2
    MakeDraggable(F)
    local T = Instance.new("TextLabel", F)
    T.Size = UDim2.new(1, 0, 0, 26); T.Position = UDim2.fromOffset(0, 10)
    T.BackgroundTransparency = 1; T.Font = Enum.Font.GothamBold; T.TextSize = 15
    T.TextColor3 = THEME_LIGHT; T.Text = L("bind_popup_title")
    local M = Instance.new("TextLabel", F)
    M.Size = UDim2.new(1, 0, 0, 22); M.Position = UDim2.fromOffset(0, 38)
    M.BackgroundTransparency = 1; M.Font = Enum.Font.GothamBold; M.TextSize = 14
    M.TextColor3 = Color3.new(1, 1, 1); M.Text = ""
    local H = Instance.new("TextLabel", F)
    H.Size = UDim2.new(1, 0, 0, 20); H.Position = UDim2.fromOffset(0, 62)
    H.BackgroundTransparency = 1; H.Font = Enum.Font.Gotham; H.TextSize = 12
    H.TextColor3 = Color3.fromRGB(180, 180, 200); H.Text = L("bind_popup_hint")
    local C = Instance.new("TextButton", F)
    C.Size = UDim2.fromOffset(80, 22); C.Position = UDim2.new(1, -88, 1, -28)
    C.BackgroundColor3 = Color3.fromRGB(40, 40, 45); C.Text = L("bind_popup_close")
    C.TextColor3 = Color3.fromRGB(255, 100, 100); C.Font = Enum.Font.GothamBold; C.TextSize = 12
    Instance.new("UICorner", C).CornerRadius = UDim.new(0, 6)

    ShowBindPopup = function(modName, modTitle)
        S.bindPopupTarget = modName; S.bindPopupActive = true
        M.Text = modTitle.."  →  "..modName
        BindPopupGui.Enabled = true
    end
    HideBindPopup = function()
        S.bindPopupActive = false; S.bindPopupTarget = nil
        BindPopupGui.Enabled = false
    end
    C.MouseButton1Click:Connect(HideBindPopup)

    local function TryApply(modName, keyName)
        if not modName or not keyName then return end
        local pk = BindKeyCache[modName]
        local pt = BindTimeCache[modName] or 0
        if pk == keyName and (tick() - pt) < 2 then
            BindList[keyName] = nil
            BindKeyCache[modName] = nil
            BindTimeCache[modName] = nil
            Notify(L("notify_title"), L("bind_reset")..modName, 3)
        else
            if pk and pk ~= keyName then BindList[pk] = nil end
            BindList[keyName] = modName
            BindKeyCache[modName] = keyName
            BindTimeCache[modName] = tick()
            Notify(L("notify_title"), L("bind_set")..keyName.." → "..modName, 3)
        end
    end

    UserInputService.InputBegan:Connect(function(input, gpe)
        if not S.bindPopupActive then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then HideBindPopup(); return end
            TryApply(S.bindPopupTarget, input.KeyCode.Name)
            HideBindPopup()
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            local kn = "Mouse"..input.UserInputType.Name:gsub("MouseButton", "")
            TryApply(S.bindPopupTarget, kn)
            HideBindPopup()
        end
    end)
end

-- ============================================================
-- CREATE ALL MODULES (10 TABS)
-- ============================================================
local function CreateAllModules()
    local tC = Window:AddTab({Title = L("tab_combat")})
    local tM = Window:AddTab({Title = L("tab_movement")})
    local tF = Window:AddTab({Title = L("tab_farm")})
    local tV = Window:AddTab({Title = L("tab_visual")})
    local tE = Window:AddTab({Title = L("tab_effects")})
    local tTr = Window:AddTab({Title = L("tab_troll")})
    local tU = Window:AddTab({Title = L("tab_utility")})
    local tMo = Window:AddTab({Title = L("tab_mobile")})
    local tK = Window:AddTab({Title = L("tab_binds")})
    local tS = Window:AddTab({Title = L("tab_settings")})

    Tabs.Combat = tC; Tabs.Movement = tM; Tabs.AutoFarm = tF; Tabs.Visual = tV
    Tabs.Effects = tE; Tabs.Troll = tTr; Tabs.Utility = tU
    Tabs.Mobile = tMo; Tabs.Keybinds = tK; Tabs.Settings = tS

    local function NT(name, state)
        if Options.NotifyToggles and Options.NotifyToggles.Value then
            Notify(L("notify_title"), name.." "..(state and "ON" or "OFF"), 1.5)
        end
    end
    local function Reg(mn, t) ModuleNameToTitle[mn] = t end

    -- ============ COMBAT ============
    Reg("SilentAimV151", "Silent Aim v15.1")
    Reg("SilentPredictV151", "Silent Predict")
    Reg("SilentForceV151", "Silent Force")
    Reg("SilentAutoV151", "Silent Auto")
    Reg("KAv2Enabled", L("kill_aura"))
    Reg("KAv2Dist", L("radius"))
    Reg("AutoGrabGun", L("auto_grab_gun"))

    tC:AddToggle("SilentAimV151", {Title = "Silent Aim v15.1", Default = false}):OnChanged(function(v)
        SILENT.enabled = v
        getgenv().SILENT_AIM_ACTIVE = v
        if v and getgenv().SILENT_INSTALL_HOOKS then pcall(getgenv().SILENT_INSTALL_HOOKS) end
        NT("Silent Aim v15.1", v)
    end)
    tC:AddToggle("SilentPredictV151", {Title = "Prediction", Default = true}):OnChanged(function(v) SILENT.predict = v end)
    tC:AddToggle("SilentForceV151", {Title = "Force Shoot (wallbang)", Default = false}):OnChanged(function(v) SILENT.force = v end)
    tC:AddSlider("SilentStandoffV151", {Title = "Standoff (studs)", Min = 0, Max = 40, Default = 15, Rounding = 0}):OnChanged(function(v) SILENT.stand_off = v end)
    tC:AddToggle("SilentAutoV151", {Title = "Auto Shoot", Default = false}):OnChanged(function(v) SILENT.auto_on = v end)
    tC:AddSlider("SilentAutoDelayV151", {Title = "Auto Delay (ms)", Min = 0, Max = 600, Default = 80, Rounding = 0}):OnChanged(function(v) SILENT.auto_delay = v / 1000 end)

    tC:AddToggle("KAv2Enabled", {Title = L("kill_aura") .. " v2", Default = false}):OnChanged(function(v)
        KA2.on = v
        NT(L("kill_aura"), v)
    end)
    tC:AddSlider("KAv2Dist", {Title = L("radius"), Min = 5, Max = 60, Default = 30, Rounding = 0}):OnChanged(function(v) KA2.dist = v end)
    tC:AddToggle("AutoGrabGun", {Title = L("auto_grab_gun"), Default = false}):OnChanged(function(v)
        NT(L("auto_grab_gun"), v); if v then S.grabFailed = false end
    end)
    tC:AddButton({Title = L("kill_sheriff"), Callback = function()
        if GetRole(LocalPlayer) ~= "murderer" then Notify(L("notify_title"), L("not_murderer"), 2); return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and GetRole(p) == "sheriff" then
                task.spawn(function()
                    local char = LocalPlayer.Character; local tChar = p.Character
                    if not char or not tChar then return end
                    local my = char:FindFirstChild("HumanoidRootPart"); local th = tChar:FindFirstChild("HumanoidRootPart")
                    local knife = char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
                    if not (my and th and knife) then return end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and knife.Parent ~= char then hum:EquipTool(knife); task.wait(0.05) end
                    local orig = my.CFrame
                    my.CFrame = th.CFrame * CFrame.new(0, 0, 1.5); task.wait(0.1)
                    pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
                    pcall(function()
                        local s = knife:FindFirstChild("Stab") or knife:FindFirstChild("Slash") or knife:FindFirstChild("Hit")
                        if s then
                            if s:IsA("RemoteEvent") then s:FireServer()
                            elseif s:IsA("RemoteFunction") then s:InvokeServer() end
                        end
                    end)
                    task.wait(0.15)
                    if my and my.Parent then my.CFrame = orig end
                end)
                Notify(L("notify_title"), L("kill_done")..p.Name, 2)
                break
            end
        end
    end})
    tC:AddButton({Title = L("suicide"), Callback = function()
        local c = LocalPlayer.Character
        if c then local h = c:FindFirstChild("Humanoid"); if h then h.Health = 0 end end
    end})

    -- ============ MOVEMENT ============
    tM:AddToggle("SpeedToggle", {Title = L("speed_hack"), Default = false}):OnChanged(function(v) NT(L("speed_hack"), v) end)
    tM:AddSlider("SpeedValue", {Title = L("walk_speed"), Min = 16, Max = 500, Default = 32, Rounding = 0})
    tM:AddToggle("FlyToggle", {Title = L("fly"), Default = false}):OnChanged(function(v)
        NT(L("fly"), v)
        TouchFlyFrame.Visible = v and UserInputService.TouchEnabled
        local hum = GetHum(); if hum then hum.PlatformStand = v end
    end)
    tM:AddSlider("FlySpeed", {Title = L("fly_speed"), Min = 20, Max = 500, Default = 60, Rounding = 0})
    tM:AddToggle("SpeedGlitch", {Title = L("speed_glitch"), Default = false}):OnChanged(function(v)
        NT(L("speed_glitch"), v); S.sgActive = false
        if not v then local h = GetHum(); if h then h.WalkSpeed = 16 end end
    end)
    tM:AddSlider("GlitchSpeed", {Title = L("glitch_speed"), Min = 40, Max = 500, Default = 120, Rounding = 0})
    tM:AddToggle("BunnyHop", {Title = L("bunny_hop"), Default = false}):OnChanged(function(v)
        NT(L("bunny_hop"), v); if not v then local h = GetHum(); if h then h.WalkSpeed = 16 end end
    end)
    tM:AddSlider("BunnyMaxSpeed", {Title = L("max_speed"), Min = 60, Max = 500, Default = 250, Rounding = 0})
    tM:AddSlider("BunnyAccelTime", {Title = L("accel_time"), Min = 1, Max = 30, Default = 10, Rounding = 0})
    tM:AddToggle("Noclip", {Title = L("noclip"), Default = false}):OnChanged(function(v) NT(L("noclip"), v) end)
    tM:AddToggle("Spinbot", {Title = L("spinbot"), Default = false}):OnChanged(function(v) NT(L("spinbot"), v) end)
    tM:AddSlider("SpinbotSpeed", {Title = L("spin_speed"), Min = 1, Max = 50, Default = 8, Rounding = 0})
    tM:AddToggle("InfJump", {Title = L("inf_jump"), Default = false}):OnChanged(function(v) NT(L("inf_jump"), v) end)
    tM:AddSlider("JumpPowerVal", {Title = L("jump_power"), Min = 50, Max = 500, Default = 100, Rounding = 0})
    tM:AddToggle("JumpPowerToggle", {Title = L("jump_power_custom"), Default = false}):OnChanged(function(v)
        NT(L("jump_power_custom"), v); S.customJumpPower = v
        local hum = GetHum()
        if hum then
            hum.UseJumpPower = true
            if v then hum.JumpPower = Options.JumpPowerVal and Options.JumpPowerVal.Value or 100
            else hum.JumpPower = 50 end
        end
    end)
    tM:AddToggle("WallBounce", {Title = L("wall_bounce"), Default = false}):OnChanged(function(v)
        NT(L("wall_bounce"), v); S.wallBounce = v
    end)
    tM:AddSlider("WallBounceForce", {Title = L("wall_force"), Min = 50, Max = 500, Default = 150, Rounding = 0})
    tM:AddToggle("FreezeToggle", {Title = L("freeze"), Default = false}):OnChanged(function(v)
        S.isFrozen = v
        if not v then
            local hrp = GetHRP()
            if hrp then local bv = hrp:FindFirstChild("FH_FreezeBV"); if bv then bv:Destroy() end end
        end
        Notify(L("notify_title"), v and L("freeze_on") or L("freeze_off"), 2)
    end)
    tM:AddSlider("FreezeSpeed", {Title = L("freeze_speed"), Min = 20, Max = 300, Default = 60, Rounding = 0})

    -- ============ AUTOFARM ============
    tF:AddToggle("FarmV2_Enabled", {Title = "AutoFarm v2 (legit)", Default = false}):OnChanged(function(v)
        FARM2.on = v
        NT(L("autofarm"), v)
    end)
    tF:AddSlider("FarmV2_Speed", {Title = L("farm_speed"), Min = 5, Max = 60, Default = 23, Rounding = 1}):OnChanged(function(v) FARM2.speed = v end)
    tF:AddToggle("FarmV2_Avoid", {Title = L("avoid_murderer"), Default = false}):OnChanged(function(v)
        FARM2.avoid = v
        NT(L("avoid_murderer"), v)
    end)
    tF:AddToggle("FarmV2_AutoKill", {Title = L("auto_kill_aura"), Default = false}):OnChanged(function(v)
        S.farmAutoKill = v
        NT(L("auto_kill_aura"), v)
    end)

    -- ============ VISUAL (basic toggles, full engine in part 2) ============
    tV:AddToggle("PlayerESP", {Title = L("player_esp"), Default = false}):OnChanged(function(v) NT(L("player_esp"), v) end)
    tV:AddToggle("NameESP", {Title = L("name_esp"), Default = false})
    tV:AddToggle("DistESP", {Title = L("dist_esp"), Default = false})
    tV:AddToggle("GunESP", {Title = L("gun_esp"), Default = false})
    tV:AddToggle("CoinESP", {Title = L("coin_esp"), Default = false})
    tV:AddToggle("Fullbright", {Title = L("fullbright"), Default = false}):OnChanged(function(v)
        NT(L("fullbright"), v)
        if v then Lighting.Ambient = Color3.fromRGB(255, 255, 255); Lighting.Brightness = 2
        else Lighting.Ambient = OriginalLighting.Ambient; Lighting.Brightness = OriginalLighting.Brightness end
    end)
    tV:AddToggle("FOVEnabled", {Title = L("fov"), Default = false}):OnChanged(function(v)
        NT(L("fov"), v); if not v then Camera.FieldOfView = OriginalLighting.FOV end
    end)
    tV:AddSlider("FOVValue", {Title = L("fov"), Min = 30, Max = 140, Default = 70, Rounding = 0})
    tV:AddSlider("FPSCap", {Title = L("fps_cap"), Min = 0, Max = 9999, Default = 0, Rounding = 0}):OnChanged(function(v)
        S.fpsCap = v; pcall(function() if setfpscap then setfpscap(v) end end)
    end)

    -- ============ TROLL ============
    tTr:AddInput("ChatInput", {Title = L("spam_message"), Default = "FortniHub v"..VERSION})
    tTr:AddToggle("SpamChat", {Title = L("spam_chat"), Default = false})
    tTr:AddToggle("TrollEgor", {Title = L("troll_egor"), Default = false}):OnChanged(function(v) NT(L("troll_egor"), v) end)
    tTr:AddToggle("TrollLag", {Title = L("troll_lag"), Default = false}):OnChanged(function(v) NT(L("troll_lag"), v) end)

    local function TPTo(pos) local hrp = GetHRP(); if hrp then hrp.CFrame = CFrame.new(pos) end end
    tTr:AddButton({Title = L("tp_lobby"), Callback = function() TPTo(Vector3.new(110, 138, -12)) end})
    tTr:AddButton({Title = L("tp_map"), Callback = function()
        for _, mn in ipairs({"Map", "CurrentMap", "Normal"}) do
            local m = Workspace:FindFirstChild(mn)
            if m then
                local sp = m:FindFirstChildWhichIsA("SpawnLocation", true)
                if sp then TPTo(sp.Position + Vector3.new(0, 3, 0)); return end
            end
        end
    end})
    tTr:AddButton({Title = L("tp_murderer"), Callback = function()
        for _, p in ipairs(Players:GetPlayers()) do
            if GetRole(p) == "murderer" then local hrp = GetHRP(p); if hrp then TPTo(hrp.Position + Vector3.new(0, 3, 0)); break end end
        end
    end})
    tTr:AddButton({Title = L("tp_sheriff"), Callback = function()
        for _, p in ipairs(Players:GetPlayers()) do
            if GetRole(p) == "sheriff" then local hrp = GetHRP(p); if hrp then TPTo(hrp.Position + Vector3.new(0, 3, 0)); break end end
        end
    end})

    -- ============ UTILITY ============
    tU:AddButton({Title = L("vote_boost"), Callback = function()
        if S.voteRunning then Notify(L("notify_title"), L("vote_running"), 2); return end
        S.voteRunning = true
        task.spawn(function()
            local my = GetHRP(); if not my then S.voteRunning = false; return end
            local orig = my.CFrame
            for i = 1, 5 do
                local c = LocalPlayer.Character
                if c then local h = c:FindFirstChild("Humanoid"); if h then h.Health = 0 end end
                LocalPlayer.CharacterAdded:Wait(); task.wait(0.5)
                local n = GetHRP(); local tries = 0
                while not n and tries < 20 do task.wait(0.1); n = GetHRP(); tries = tries + 1 end
                if n then task.wait(0.1); n.CFrame = orig; task.wait(0.3) end
            end
            Notify(L("notify_title"), L("vote_done"), 3); S.voteRunning = false
        end)
    end})
    tU:AddToggle("Invis", {Title = L("invis"), Default = false}):OnChanged(function(v)
        task.spawn(function()
            local ok = ClickExternalButton({"invisible", "invis", "невид"})
            if ok then Notify(L("notify_title"), v and L("invis_on") or L("invis_off"), 2)
            else Notify(L("notify_title"), L("invis_nf"), 3) end
        end)
    end)
    tU:AddToggle("AntiAFK", {Title = L("anti_afk"), Default = true})
    tU:AddButton({Title = L("rejoin"), Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end})
    tU:AddButton({Title = L("server_hop"), Callback = function()
        pcall(function()
            local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
            local data = game:HttpGet(url); local parsed = HttpService:JSONDecode(data)
            for _, s in ipairs(parsed.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer); break
                end
            end
        end)
    end})

    -- ============ MOBILE ============
    local mobVals = {"ShootBtn", "SpeedToggle", "SpeedGlitch", "BunnyHop", "Spinbot", "FlyToggle", "Noclip", "FreezeToggle", "WallBounce", "FarmV2_Enabled", "PlayerESP", "NameESP", "DistESP", "GunESP", "CoinESP", "KAv2Enabled", "AutoGrabGun", "Invis", "SilentAimV151", "InfJump", "JumpPowerToggle"}
    tMo:AddDropdown("TouchModulesDropdown", {Title = L("select_modules_multi"), Values = mobVals, Multi = true, Default = {}})
    tMo:AddToggle("LockButtons", {Title = L("freeze_buttons"), Default = false}):OnChanged(function(v)
        S.mobileLocked = v; Notify(L("notify_title"), "Заморозка "..(v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)
    tMo:AddToggle("ShowShootBtn", {Title = L("show_shoot_btn"), Default = false}):OnChanged(function(v)
        if ShootBtnRef then ShootBtnRef.Visible = v end
        Notify(L("notify_title"), L("show_shoot_btn").." "..(v and "ON" or "OFF"), 1.5)
    end)
    tMo:AddButton({Title = L("clear_all"), Callback = function()
        if S.mobileLocked then Notify(L("notify_title"), L("freeze_first"), 2); return end
        for _, f in pairs(MobileButtons) do if f then f:Destroy() end end
        MobileButtons = {}
    end})

    -- ============ KEYBINDS ============
    local bindV = {"SpeedToggle", "SpeedGlitch", "BunnyHop", "Spinbot", "FlyToggle", "Noclip", "FreezeToggle", "WallBounce", "FarmV2_Enabled", "PlayerESP", "NameESP", "DistESP", "GunESP", "CoinESP", "KAv2Enabled", "AutoGrabGun", "Invis", "InfJump", "JumpPowerToggle", "SilentAimV151"}
    tK:AddDropdown("BindSelect", {Title = L("module"), Values = bindV, Default = "SilentAimV151"})
    tK:AddButton({Title = L("set_bind"), Callback = function()
        local m = Options.BindSelect and Options.BindSelect.Value
        if not m then return end
        ShowBindPopup(m, ModuleNameToTitle[m] or m)
    end})
    tK:AddButton({Title = L("clear_binds"), Callback = function()
        for k in pairs(BindList) do BindList[k] = nil end
        for k in pairs(BindKeyCache) do BindKeyCache[k] = nil end
        for k in pairs(BindTimeCache) do BindTimeCache[k] = nil end
        Notify(L("notify_title"), L("binds_cleared"), 2)
    end})

    -- ============ SETTINGS ============
    tS:AddToggle("NotifyToggles", {Title = L("notify_toggles"), Default = true})
    tS:AddToggle("ShowHUD", {Title = L("show_hud"), Default = true}):OnChanged(function(v) TopHUDGui.Enabled = v end)
    tS:AddToggle("CoordMode", {Title = L("coord_mode"), Default = false}):OnChanged(function(v) CoordGui.Enabled = v end)
    tS:AddButton({Title = L("unload"), Callback = function()
        pcall(function()
            for _, c in pairs(Connections) do c:Disconnect() end
            Connections = {}
            if TopHUDGui then TopHUDGui:Destroy() end
            if MobUI then MobUI:Destroy() end
            if ESPFolder then ESPFolder:Destroy() end
            if CoordGui then CoordGui:Destroy() end
            if BindPopupGui then BindPopupGui:Destroy() end
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.Brightness = OriginalLighting.Brightness
            Camera.FieldOfView = OriginalLighting.FOV
            for _, d in pairs(Cache.nameESP) do pcall(function() d:Remove() end) end
            for _, d in pairs(Cache.distESP) do pcall(function() d:Remove() end) end
            local hrp = GetHRP()
            if hrp then hrp.Anchored = false end
            local hum = GetHum(); if hum then hum.PlatformStand = false end
            task.wait(0.3)
            if Window then Window:Destroy() end
        end)
    end})

    if InterfaceManager then pcall(function() InterfaceManager:BuildInterfaceSection(tS) end) end
    if SaveManager then
        pcall(function() SaveManager:BuildConfigSection(tS) end)
        pcall(function() SaveManager:LoadAutoloadConfig() end)
    end
end

local mOk, mErr = pcall(CreateAllModules)
if not mOk then logErr("Ошибка создания модулей: "..tostring(mErr)) else logInfo("Модули созданы") end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local lastHUD, lastESP, lastItemESP = 0, 0, 0

AddConn("MainLoop", RunService.Heartbeat:Connect(function()
    RefreshCharCache()
    local now = os.clock()

    if now - lastHUD > 0.5 then
        lastHUD = now
        if TopHUDGui and TopHUDGui.Enabled then
            RoundLabel = RoundLabel or nil
            if RoundLabel then RoundLabel.Text = L("round_time").." "..GetRoundTime() end
        end
    end

    local hum = Cache.localHum
    if hum then
        if Options.SpeedToggle and Options.SpeedToggle.Value then
            hum.WalkSpeed = Options.SpeedValue and Options.SpeedValue.Value or 32
        end
        if S.isFrozen then
            hum.WalkSpeed = 0
            local hrp = Cache.localHRP
            if hrp then
                if not hrp:FindFirstChild("FH_FreezeBV") then
                    local bv = Instance.new("BodyVelocity")
                    bv.Name = "FH_FreezeBV"; bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                    bv.Velocity = Vector3.zero; bv.Parent = hrp
                end
                local speed = Options.FreezeSpeed and Options.FreezeSpeed.Value or 60
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) or flyKeys.W then dir = dir + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) or flyKeys.S then dir = dir - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) or flyKeys.A then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) or flyKeys.D then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyKeys.UP then dir = dir + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or flyKeys.DOWN then dir = dir - Vector3.new(0, 1, 0) end
                local bv = hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv.Velocity = dir.Magnitude > 0 and dir.Unit * speed or Vector3.zero end
            end
        else
            if Cache.localHRP then
                local bv = Cache.localHRP:FindFirstChild("FH_FreezeBV")
                if bv then bv:Destroy() end
            end
        end
        if S.customJumpPower then
            hum.UseJumpPower = true
            local jp = Options.JumpPowerVal and Options.JumpPowerVal.Value or 100
            if hum.JumpPower ~= jp then hum.JumpPower = jp end
        end
        if Options.SpeedGlitch and Options.SpeedGlitch.Value then
            local gs = Options.GlitchSpeed and Options.GlitchSpeed.Value or 120
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then
                S.sgActive = true; S.lastMoveTime = tick(); hum.WalkSpeed = gs
            elseif st == Enum.HumanoidStateType.Landed or st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.RunningNoPhysics then
                if hum.MoveDirection.Magnitude > 0.1 then
                    S.sgActive = true; S.lastMoveTime = tick(); hum.WalkSpeed = gs
                elseif tick() - S.lastMoveTime > 0.2 and S.sgActive then
                    hum.WalkSpeed = 16; S.sgActive = false
                end
            end
        end
        if Options.BunnyHop and Options.BunnyHop.Value then
            local maxS = Options.BunnyMaxSpeed and Options.BunnyMaxSpeed.Value or 250
            local acc = Options.BunnyAccelTime and Options.BunnyAccelTime.Value or 10
            if hum.MoveDirection.Magnitude > 0.1 then
                _G.BunnySpeed = math.min((_G.BunnySpeed or 16) + (maxS / acc) * 0.02, maxS)
            else _G.BunnySpeed = 16 end
            hum.WalkSpeed = _G.BunnySpeed
        end
        if Options.Spinbot and Options.Spinbot.Value and Cache.localHRP then
            local s = Options.SpinbotSpeed and Options.SpinbotSpeed.Value or 8
            Cache.localHRP.CFrame = Cache.localHRP.CFrame * CFrame.Angles(0, math.rad(s), 0)
        end
        if Options.TrollEgor and Options.TrollEgor.Value then hum.WalkSpeed = 0.5 end
    end

    if Options.Noclip and Options.Noclip.Value and LocalPlayer.Character then
        for _, v in ipairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
    if Options.FOVEnabled and Options.FOVEnabled.Value then
        local t = Options.FOVValue and Options.FOVValue.Value or 70
        if Camera.FieldOfView ~= t then Camera.FieldOfView = t end
    end

    if Options.AutoGrabGun and Options.AutoGrabGun.Value and not S.grabFailed and not S.isGrabbing then
        local char = LocalPlayer.Character
        local my = char and char:FindFirstChild("HumanoidRootPart")
        if my and not char:FindFirstChild("Gun") and not (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun")) then
            local closest, minD = nil, math.huge
            for _, gun in ipairs(Cache.guns) do
                if gun and gun.Parent and gun:IsA("BasePart") then
                    local d = (gun.Position - my.Position).Magnitude
                    if d < minD then minD = d; closest = gun end
                end
            end
            if closest then
                S.isGrabbing = true
                task.spawn(function()
                    local rp = my.CFrame
                    local tp = closest
                    if tp then
                        local grabbed = false
                        for i = 1, 3 do
                            if my and my.Parent then my.CFrame = tp.CFrame end
                            task.wait(0.05)
                            pcall(function() firetouchinterest(my, tp, 0); task.wait(0.02); firetouchinterest(my, tp, 1) end)
                            if LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun") then grabbed = true; break end
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun") then grabbed = true; break end
                        end
                        if my and my.Parent then
                            my.CFrame = rp
                            my.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            my.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end
                        if not grabbed then S.grabFailed = true; Notify(L("notify_title"), L("grab_fail"), 3) end
                    end
                    S.isGrabbing = false
                end)
            end
        end
    end

    if now - lastESP > 0.2 then
        lastESP = now
        if Options.PlayerESP and Options.PlayerESP.Value then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local hlN = "ESP_"..p.Name
                    local hl = ESPFolder:FindFirstChild(hlN)
                    if not hl then hl = Instance.new("Highlight") end
                    hl.Name = hlN; hl.Adornee = p.Character
                    hl.FillColor = GetRoleColor(GetRole(p))
                    hl.FillTransparency = 0.5; hl.OutlineColor = Color3.new(1, 1, 1)
                    hl.Parent = ESPFolder
                end
            end
        else ESPFolder:ClearAllChildren() end
    end

    if now - lastItemESP > 1.5 then
        lastItemESP = now
        if Options.GunESP and Options.GunESP.Value then
            for _, gun in ipairs(Cache.guns) do
                if gun and gun.Parent and not gun:FindFirstChild("FH_GunHL") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "FH_GunHL"; hl.Adornee = gun; hl.FillColor = Color3.fromRGB(255, 255, 0); hl.Parent = gun
                end
            end
        else
            for _, gun in ipairs(Cache.guns) do
                if gun and gun.Parent then local hl = gun:FindFirstChild("FH_GunHL"); if hl then hl:Destroy() end end
            end
        end
        if Options.CoinESP and Options.CoinESP.Value then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name == "Coin_Server" or obj.Name == "Coin") then
                    if not obj:FindFirstChild("FH_CoinHL") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "FH_CoinHL"; hl.Adornee = obj
                        hl.FillColor = Color3.fromRGB(255, 215, 0); hl.OutlineColor = Color3.new(1, 1, 1)
                        hl.FillTransparency = 0.4; hl.Parent = obj
                    end
                end
            end
        else
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then local hl = obj:FindFirstChild("FH_CoinHL"); if hl then hl:Destroy() end end
            end
        end
    end

    if Options.FlyToggle and Options.FlyToggle.Value then
        local hrp, h2 = Cache.localHRP, Cache.localHum
        if hrp and h2 then
            h2.PlatformStand = true
            local sp = Options.FlySpeed and Options.FlySpeed.Value or 60
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) or flyKeys.W then dir = dir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) or flyKeys.S then dir = dir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or flyKeys.A then dir = dir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) or flyKeys.D then dir = dir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyKeys.UP then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or flyKeys.DOWN then dir = dir - Vector3.new(0, 1, 0) end
            hrp.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero
        end
    else
        if Cache.localHum and Cache.localHum.PlatformStand then Cache.localHum.PlatformStand = false end
    end

    if CoordGui.Enabled and Cache.localHRP then
        local p = Cache.localHRP.Position
        CoordLabel.Text = string.format("X: %d Y: %d Z: %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
    end
end))

-- ============================================================
-- TEXT ESP
-- ============================================================
AddConn("TextESP", RunService.RenderStepped:Connect(function()
    if not (Options.NameESP and Options.NameESP.Value) and not (Options.DistESP and Options.DistESP.Value) then
        for p, d in pairs(Cache.nameESP) do pcall(function() d:Remove() end) end
        for p, d in pairs(Cache.distESP) do pcall(function() d:Remove() end) end
        Cache.nameESP = {}; Cache.distESP = {}
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local hp = hrp.Position + Vector3.new(0, 3, 0)
                local sp, on = Camera:WorldToViewportPoint(hp)
                if Options.NameESP and Options.NameESP.Value then
                    if not Cache.nameESP[p] then
                        local d = Drawing.new("Text"); d.Size = 14; d.Center = true; d.Outline = true; d.Color = Color3.new(1, 1, 1); Cache.nameESP[p] = d
                    end
                    local d = Cache.nameESP[p]
                    if on then d.Position = Vector2.new(sp.X, sp.Y - 20); d.Text = p.Name; d.Visible = true else d.Visible = false end
                end
                if Options.DistESP and Options.DistESP.Value then
                    if not Cache.distESP[p] then
                        local d = Drawing.new("Text"); d.Size = 12; d.Center = true; d.Outline = true; d.Color = Color3.fromRGB(200, 200, 200); Cache.distESP[p] = d
                    end
                    local d = Cache.distESP[p]
                    if on then d.Position = Vector2.new(sp.X, sp.Y + 5); d.Text = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude).."m"; d.Visible = true else d.Visible = false end
                end
            end
        end
    end
end))
AddConn("TextESPRem", Players.PlayerRemoving:Connect(function(p)
    if Cache.nameESP[p] then Cache.nameESP[p]:Remove(); Cache.nameESP[p] = nil end
    if Cache.distESP[p] then Cache.distESP[p]:Remove(); Cache.distESP[p] = nil end
    local hl = ESPFolder:FindFirstChild("ESP_"..p.Name); if hl then hl:Destroy() end
end))

-- ============================================================
-- SPAM / ANTI-AFK / INF JUMP / WALLBOUNCE
-- ============================================================
AddConn("SpamLoop", task.spawn(function()
    while task.wait(10) do
        if Options.SpamChat and Options.SpamChat.Value then
            local msg = Options.ChatInput and Options.ChatInput.Value or "FortniHub"
            if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync(msg) end
            else
                local r = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if r then r.SayMessageRequest:FireServer(msg, "All") end
            end
        end
    end
end))
AddConn("AntiAFK", LocalPlayer.Idled:Connect(function()
    if Options.AntiAFK and Options.AntiAFK.Value then
        VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
    end
end))
AddConn("LagLoop", RunService.RenderStepped:Connect(function()
    if not Options.TrollLag or not Options.TrollLag.Value then return end
    for i = 1, 5000 do local _ = math.noise(i, i * 0.5) end
end))
AddConn("IJLoop", UserInputService.JumpRequest:Connect(function()
    if Options.InfJump and Options.InfJump.Value then
        local hum = GetHum(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))
AddConn("WBJump", UserInputService.JumpRequest:Connect(function()
    if not S.wallBounce then return end
    local char = LocalPlayer.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}; params.FilterType = Enum.RaycastFilterType.Exclude
    local dirs = {hrp.CFrame.LookVector, -hrp.CFrame.LookVector, hrp.CFrame.RightVector, -hrp.CFrame.RightVector}
    for _, d in ipairs(dirs) do
        local res = Workspace:Raycast(hrp.Position, d * 3, params)
        if res then
            local force = Options.WallBounceForce and Options.WallBounceForce.Value or 150
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.Velocity.X, force, hrp.Velocity.Z)
            break
        end
    end
end))

-- ============================================================
-- BIND HANDLER
-- ============================================================
AddConn("BindHandler", UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if S.bindPopupActive then return end
    local keyName = nil
    if input.UserInputType == Enum.UserInputType.Keyboard then keyName = input.KeyCode.Name
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
        keyName = "Mouse"..input.UserInputType.Name:gsub("MouseButton", "")
    end
    if keyName then
        local target = BindList[keyName]
        if target and Options[target] then Options[target]:SetValue(not Options[target].Value) end
    end
end))
if ShootBtnRef then
    ShootBtnRef.MouseButton1Click:Connect(function()
        local cf = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if cf then pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end) end
    end)
end
AddConn("MenuKey", UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then pcall(function() Window:Minimize() end) end
end))

AddConn("CharAdded", LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    S.grabFailed = false; S.recentlyTouched = {}; S.farmAnchored = false
    S.farmTimeoutStart = tick(); S.isFrozen = false; S.charCacheTime = 0
    if hrp then
        hrp.Anchored = false
        for _, n in ipairs({"FH_FreezeBV", "FH_FlyBV", "FH_HidePosition"}) do
            local o = hrp:FindFirstChild(n); if o then o:Destroy() end
        end
    end
    if Options.SpeedToggle and Options.SpeedToggle.Value and hum then
        hum.WalkSpeed = Options.SpeedValue and Options.SpeedValue.Value or 32
    end
end))

pcall(function() Window:SelectTab(1) end)

-- ============================================================
-- END OF PART 1/3
-- ============================================================
-- Часть 2/3: Visuals Engine (полный ESP), Effects, World Aura,
--             Shaders, Tracers, Chams, Crosshair, China Hat,
--             Backtrack, Murder Effect, Players Death Effect,
--             World FX, Skybox, Sub-tabs bar
-- Часть 3/3: Tools (TP tool, Fling tool, Model changer, Fake
--             Korblox/Headless), Sounds, Emotes, Animations,
--             Map Vote, Show Values, Anti-Fling/Void/Trap/Coin,
--             Fling Murder/Sheriff, Fly v2, Bhop, Wallhop,
--             Pixel Surf, Notify, Emotes, Emote sniper

logInfo("==============================================")
logInfo("PART 1/3 УСПЕШНО ЗАГРУЖЕН")
logInfo("Фичи: SafeRandom, HUD v2 Pill, Silent Aim v15.1, Knife Silent, KillAura v2, AutoFarm v2")
logInfo("Ожидаю часть 2/3 для Visuals + Effects")
logInfo("==============================================")

task.spawn(function()
    task.wait(0.5)
    Notify(L("notify_title"), "Part 1/3 загружено! P - меню", 6)
end)
-- ============================================================
-- SHITARO-ADDON v15.2 — PART 2/3
-- Visuals Engine + Effects
-- ============================================================
-- Вставлять ПОСЛЕ PART 1/3
-- Зависимости из Part 1: AddConn, Notify, L, GetHRP, GetHum,
-- GetRole, GetRoleColor, MakeDraggable, ESPFolder, Tabs, Options,
-- Window, S, Cache, LocalPlayer, Camera, Lighting, OriginalLighting
-- ============================================================

if _G.SHITARO_ADDON_V152_P2_LOADED then
    logWarn("Addon v15.2 Part 2/3 уже загружен")
    return
end
_G.SHITARO_ADDON_V152_P2_LOADED = true

-- ============================================================
-- SECTION I: SUB-TABS BAR для Fluent
-- ============================================================
-- Создаёт горизонтальный бар переключателей в начале вкладки.
-- Позволяет делать под-разделы "Визуалы | Эффекты" как на скрине.
do
    local SubTabs = {}
    SubTabs.__index = SubTabs

    function SubTabs.new(parentTab, names, defaultIdx)
        local self = setmetatable({}, SubTabs)
        self.tab = parentTab
        self.names = names
        self.sections = {}
        self.active = defaultIdx or 1
        self.buttons = {}

        local holder = parentTab:AddSection({Name = "sub_tabs_holder_" .. tostring(math.random(1, 1e6))})
        self.holder = holder

        local frame = holder.Frame or holder.Container or holder.Instance
        if not frame then
            logWarn("SubTabs: Fluent section frame не найден, fallback")
            return self
        end
        pcall(function()
            frame.BackgroundTransparency = 1
            frame.Size = UDim2.new(0, 0, 0, 0)
            frame.Visible = false
        end)

        local parent = frame.Parent or frame
        local bar = Instance.new("Frame")
        bar.Name = "SubTabBar"
        bar.BackgroundTransparency = 1
        bar.Size = UDim2.new(1, -20, 0, 34)
        bar.Position = UDim2.fromOffset(10, 6)
        bar.Parent = parent
        bar.ZIndex = 5

        local layout = Instance.new("UIListLayout", bar)
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Center

        for i, name in ipairs(names) do
            local btn = Instance.new("TextButton")
            btn.Name = "Sub_" .. name
            btn.LayoutOrder = i
            btn.BackgroundColor3 = i == self.active and Color3.fromRGB(40, 34, 60) or Color3.fromRGB(24, 24, 30)
            btn.BackgroundTransparency = 0
            btn.BorderSizePixel = 0
            btn.AutoButtonColor = false
            btn.Text = name
            btn.TextColor3 = i == self.active and Color3.fromRGB(240, 240, 255) or Color3.fromRGB(150, 150, 165)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 13
            btn.Size = UDim2.fromOffset(120, 30)
            btn.Parent = bar
            Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

            local st = Instance.new("UIStroke", btn)
            st.Color = i == self.active and THEME or Color3.fromRGB(55, 55, 68)
            st.Thickness = 1
            st.Transparency = i == self.active and 0.15 or 0.55

            self.buttons[i] = btn
            btn.MouseButton1Click:Connect(function() self:Switch(i) end)
        end

        self.bar = bar
        return self
    end

    function SubTabs:Switch(idx)
        if idx == self.active then return end
        self.active = idx

        for i, btn in ipairs(self.buttons) do
            local on = i == idx
            TweenService:Create(btn, TweenInfo.new(0.18), {
                BackgroundColor3 = on and Color3.fromRGB(40, 34, 60) or Color3.fromRGB(24, 24, 30),
                TextColor3 = on and Color3.fromRGB(240, 240, 255) or Color3.fromRGB(150, 150, 165),
            }):Play()
            local st = btn:FindFirstChildOfClass("UIStroke")
            if st then
                TweenService:Create(st, TweenInfo.new(0.18), {
                    Color = on and THEME or Color3.fromRGB(55, 55, 68),
                    Transparency = on and 0.15 or 0.55,
                }):Play()
            end
        end

        for nameIdx, list in pairs(self.sections) do
            local show = nameIdx == idx
            for _, sec in ipairs(list) do
                local frame = sec.Frame or sec.Container or sec.Instance
                if frame then
                    pcall(function() frame.Visible = show end)
                end
            end
        end
    end

    function SubTabs:AddSectionTo(nameIdx, cfg)
        local sec = self.tab:AddSection(cfg or {})
        self.sections[nameIdx] = self.sections[nameIdx] or {}
        table.insert(self.sections[nameIdx], sec)
        if nameIdx ~= self.active then
            local frame = sec.Frame or sec.Container or sec.Instance
            if frame then pcall(function() frame.Visible = false end) end
        end
        return sec
    end

    function SubTabs:AddSection(cfg) return self:AddSectionTo(self.active, cfg) end

    _G.FluentSubTabs = SubTabs
    logInfo("SubTabs system ready")
end

-- ============================================================
-- SECTION J: FULL ESP ENGINE (порт из скрипта друга)
-- ============================================================
-- Полный движок: box, name, avatar, skeleton, chams, mat chams,
-- flags, arrows, gun esp, distance. Рисует через Drawing API.
do
    local esp_on = false
    local esp = {
        on = false,
        box = false, box_col = {Color3.new(1, 0, 0), 1}, box_type = "Static",
        box_grd = false, box_grd1 = Color3.new(1, 0, 0), box_grd2 = Color3.new(0, 0, 1),
        box_f = false, box_f_col = {Color3.new(1, 0, 0), 0.5}, box_f_grd = false,
        box_f_grd1 = Color3.new(1, 0, 0), box_f_grd2 = Color3.new(0, 0, 1),
        name = false, n_col = {Color3.new(1, 1, 1), 1}, n_grd = false,
        n_grd1 = Color3.new(1, 1, 1), n_grd2 = Color3.new(1, 0, 0),
        avatar = false,
        dist = false, d_col = {Color3.new(1, 1, 1), 1}, d_grd = false,
        d_grd1 = Color3.new(1, 1, 1), d_grd2 = Color3.new(1, 0, 0),
        skel = false, skel_col = {Color3.new(1, 1, 1), 1},
        chams = false,
        chams_f_mur = {Color3.new(1, 0, 0), 0.5}, chams_o_mur = {Color3.new(1, 0, 0), 0},
        chams_f_inno = {Color3.new(1, 1, 1), 0.5}, chams_o_inno = {Color3.new(1, 1, 1), 0},
        chams_f_shf = {Color3.fromRGB(0, 153, 255), 0.5}, chams_o_shf = {Color3.fromRGB(0, 153, 255), 0},
        mat_chams = false, mat_chams_type = "ForceField",
        mat_col_mur = Color3.new(1, 0, 0), mat_col_inno = Color3.new(1, 1, 1),
        mat_col_shf = Color3.fromRGB(0, 153, 255),
        flags = false,
        flag_mur = {Color3.new(1, 0, 0), 1}, flag_shf = {Color3.fromRGB(0, 153, 255), 1},
        flag_grd_mur = false, flag_grd_mur1 = Color3.new(1, 0, 0), flag_grd_mur2 = Color3.fromRGB(255, 128, 0),
        flag_grd_shf = false, flag_grd_shf1 = Color3.fromRGB(0, 153, 255), flag_grd_shf2 = Color3.fromRGB(0, 255, 255),
        arrows = false,
        off_ar_col_mur = {Color3.fromRGB(255, 60, 60), 1},
        off_ar_col_inno = {Color3.new(1, 1, 1), 1},
        off_ar_col_shf = {Color3.fromRGB(0, 153, 255), 1},
        off_ar_sz = 42, off_ar_dis = 260,
        allow_local = false,
    }
    _G.ESP_STATE = esp

    local drawings = {}
    local maxDist = 500

    local function lerp_color(a, b, t) return a:Lerp(b, math.clamp(t, 0, 1)) end
    local function grad(p, c1, c2)
        return lerp_color(c1, c2, math.sin(p * 3.1416 + os.clock() * 2) * 0.5 + 0.5)
    end

    local function dispose(entry)
        for _, d in pairs(entry) do
            if type(d) == "table" then
                for _, x in pairs(d) do pcall(function() x:Remove() end) end
            elseif typeof(d) == "userdata" or type(d) == "table" then
                pcall(function() d:Remove() end)
            end
        end
    end

    local function clear_all()
        for _, entry in pairs(drawings) do dispose(entry) end
        table.clear(drawings)
    end

    local function get_or_create(player)
        local e = drawings[player]
        if e then return e end
        e = { box = {}, boxF = {}, name = nil, dist = nil, avatar = nil,
              skel = {}, flags = {}, arrow = nil, caches = {} }
        drawings[player] = e
        return e
    end

    local function ensure_box(e, i)
        if e.box[i] then return e.box[i] end
        local d = Drawing.new("Line")
        d.Visible = false
        d.Thickness = 1
        d.Transparency = 1
        e.box[i] = d
        return d
    end

    local function ensure_boxF(e)
        if e.boxF[1] then return e.boxF[1] end
        local d = Drawing.new("Square")
        d.Filled = true
        d.Thickness = 0
        d.Transparency = 1
        d.Visible = false
        e.boxF[1] = d
        return d
    end

    local function ensure_skel(e, i)
        if e.skel[i] then return e.skel[i] end
        local d = Drawing.new("Line")
        d.Visible = false
        d.Thickness = 1
        d.Transparency = 1
        e.skel[i] = d
        return d
    end

    local function ensure_flag(e, i)
        if e.flags[i] then return e.flags[i] end
        local d = Drawing.new("Text")
        d.Size = 13
        d.Center = false
        d.Outline = true
        d.Visible = false
        e.flags[i] = d
        return d
    end

    local function classify_role(player)
        local m, ok = nil, false
        ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and m and m.PlayerData then
            local d = m.PlayerData[player.Name]
            if d and not d.Dead then
                if d.Role == "Murderer" then return "murder" end
                if d.Role == "Sheriff" or d.Role == "Hero" then return "sheriff" end
                return "inno"
            end
        end
        local c = player.Character
        if c then
            if c:FindFirstChild("Knife") then return "murder" end
            if c:FindFirstChild("Gun") then return "sheriff" end
        end
        local bp = player:FindFirstChild("Backpack")
        if bp then
            if bp:FindFirstChild("Knife") then return "murder" end
            if bp:FindFirstChild("Gun") then return "sheriff" end
        end
        return "inno"
    end

    local function role_color(role)
        if role == "murder" then return Color3.fromRGB(255, 60, 60) end
        if role == "sheriff" then return Color3.fromRGB(0, 153, 255) end
        return Color3.new(1, 1, 1)
    end

    -- Chams / highlights
    local chams_folder = Instance.new("Folder", Workspace)
    chams_folder.Name = "FH_ChamsFolder"

    local function update_chams(player, role)
        if not esp.chams then
            local old = chams_folder:FindFirstChild(player.Name)
            if old then old:Destroy() end
            return
        end
        local char = player.Character
        if not char then return end
        local h = chams_folder:FindFirstChild(player.Name)
        if not h then
            h = Instance.new("Highlight")
            h.Name = player.Name
            h.Adornee = char
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = chams_folder
        end
        local role_key = role == "murder" and "mur" or (role == "sheriff" and "shf" or "inno")
        h.FillColor = esp["chams_f_" .. role_key][1]
        h.FillTransparency = esp["chams_f_" .. role_key][2]
        h.OutlineColor = esp["chams_o_" .. role_key][1]
        h.OutlineTransparency = esp["chams_o_" .. role_key][2]
    end

    -- Material chams: меняем материал на ForceField/Flat/Chromatic
    local mat_cache = {}
    local function update_mat_chams()
        if not esp.mat_chams then
            for part, orig in pairs(mat_cache) do
                if part.Parent then
                    pcall(function() part.Material = orig.m end)
                    pcall(function() part.Color = orig.c end)
                end
            end
            table.clear(mat_cache)
            return
        end
        local mat = Enum.Material.ForceField
        if esp.mat_chams_type == "Flat" then mat = Enum.Material.SmoothPlastic
        elseif esp.mat_chams_type == "Chromatic" then mat = Enum.Material.Foil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local role = classify_role(p)
                local col = role == "murder" and esp.mat_col_mur
                    or (role == "sheriff" and esp.mat_col_shf or esp.mat_col_inno)
                for _, part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if not mat_cache[part] then
                            mat_cache[part] = {m = part.Material, c = part.Color}
                        end
                        pcall(function() part.Material = mat end)
                        pcall(function() part.Color = col end)
                    end
                end
            end
        end
    end

    -- Основной цикл отрисовки
    local render_conn
    local function start_render()
        if render_conn then return end
        render_conn = RunService.RenderStepped:Connect(function()
            if not esp.on then return end

            local now_players = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer and not esp.allow_local then continue end
                if not p.Character then
                    if drawings[p] then dispose(drawings[p]) drawings[p] = nil end
                    continue
                end
                now_players[p] = true
                local char = p.Character
                local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
                local head = char:FindFirstChild("Head")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not (hrp and head and hum) then continue end
                if hum.Health <= 0 and p ~= LocalPlayer then
                    if drawings[p] then dispose(drawings[p]) drawings[p] = nil end
                    continue
                end

                local e = get_or_create(p)
                local cam = Camera
                local vp = cam.ViewportSize
                local hrp_pos = hrp.Position
                local head_pos = head.Position + Vector3.new(0, head.Size.Y * 0.5, 0)
                local foot_pos = hrp_pos - Vector3.new(0, hrp.Size.Y * 0.5 + (hum.HipHeight or 0), 0)

                local head_sp, head_on = cam:WorldToViewportPoint(head_pos)
                local foot_sp, foot_on = cam:WorldToViewportPoint(foot_pos)
                if not (head_on or foot_on) then
                    for _, d in pairs(e.box) do d.Visible = false end
                    for _, d in pairs(e.skel) do d.Visible = false end
                    if e.boxF[1] then e.boxF[1].Visible = false end
                    if e.name then e.name.Visible = false end
                    if e.dist then e.dist.Visible = false end
                    if e.avatar then e.avatar.Visible = false end
                    for _, d in pairs(e.flags) do d.Visible = false end
                    if e.arrow then e.arrow.Visible = false end
                    continue
                end

                local role = classify_role(p)
                local dcol = role_color(role)
                local dist = (cam.CFrame.Position - hrp_pos).Magnitude
                local fade = math.clamp(1 - dist / maxDist, 0.15, 1)

                -- BOX
                if esp.box then
                    local tl = Vector2.new(math.min(head_sp.X, foot_sp.X), math.min(head_sp.Y, foot_sp.Y))
                    local br = Vector2.new(math.max(head_sp.X, foot_sp.X), math.max(head_sp.Y, foot_sp.Y))
                    local w = math.max(40, (head_sp.Y - foot_sp.Y) * 0.5)
                    local cx = (head_sp.X + foot_sp.X) * 0.5
                    local top = head_sp.Y
                    local bot = foot_sp.Y
                    local left = cx - w
                    local right = cx + w

                    local col = esp.box_grd and grad(0.5, esp.box_grd1, esp.box_grd2) or dcol
                    local a = esp.box_col[2] * fade

                    if esp.box_type == "Static" then
                        local lines = {
                            {left, top, right, top},
                            {right, top, right, bot},
                            {right, bot, left, bot},
                            {left, bot, left, top},
                        }
                        for i, l in ipairs(lines) do
                            local d = ensure_box(e, i)
                            d.From = Vector2.new(l[1], l[2])
                            d.To = Vector2.new(l[3], l[4])
                            d.Color = col
                            d.Transparency = a
                            d.Thickness = 1.5
                            d.Visible = true
                        end
                        for i = 5, #e.box do e.box[i].Visible = false end
                    else
                        -- Corners
                        local seg = math.min(w, bot - top) * 0.25
                        local lines = {
                            {left, top, left + seg, top},
                            {left, top, left, top + seg},
                            {right, top, right - seg, top},
                            {right, top, right, top + seg},
                            {left, bot, left + seg, bot},
                            {left, bot, left, bot - seg},
                            {right, bot, right - seg, bot},
                            {right, bot, right, bot - seg},
                        }
                        for i, l in ipairs(lines) do
                            local d = ensure_box(e, i)
                            d.From = Vector2.new(l[1], l[2])
                            d.To = Vector2.new(l[3], l[4])
                            d.Color = col
                            d.Transparency = a
                            d.Thickness = 1.5
                            d.Visible = true
                        end
                        for i = #lines + 1, #e.box do e.box[i].Visible = false end
                    end

                    if esp.box_f then
                        local sq = ensure_boxF(e)
                        local fcol = esp.box_f_grd and grad(0.5, esp.box_f_grd1, esp.box_f_grd2) or dcol
                        sq.Position = Vector2.new(left, top)
                        sq.Size = Vector2.new(right - left, bot - top)
                        sq.Color = fcol
                        sq.Transparency = esp.box_f_col[2] * fade
                        sq.Visible = true
                    elseif e.boxF[1] then
                        e.boxF[1].Visible = false
                    end
                else
                    for _, d in pairs(e.box) do d.Visible = false end
                    if e.boxF[1] then e.boxF[1].Visible = false end
                end

                -- NAME
                if esp.name then
                    if not e.name then
                        e.name = Drawing.new("Text")
                        e.name.Size = 13
                        e.name.Center = true
                        e.name.Outline = true
                    end
                    local ncol = esp.n_grd and grad(0.5, esp.n_grd1, esp.n_grd2) or esp.n_col[1]
                    e.name.Text = p.Name
                    e.name.Position = Vector2.new((head_sp.X + foot_sp.X) * 0.5, head_sp.Y - 18)
                    e.name.Color = ncol
                    e.name.Transparency = esp.n_col[2] * fade
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
                    local dcol2 = esp.d_grd and grad(0.5, esp.d_grd1, esp.d_grd2) or esp.d_col[1]
                    e.dist.Text = string.format("%d m", math.floor(dist))
                    e.dist.Position = Vector2.new((head_sp.X + foot_sp.X) * 0.5, foot_sp.Y + 4)
                    e.dist.Color = dcol2
                    e.dist.Transparency = esp.d_col[2] * fade
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
                    e.avatar.Position = Vector2.new((head_sp.X + foot_sp.X) * 0.5 - 20, head_sp.Y - 60)
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
                    local col = esp.skel_col[1]
                    local a = esp.skel_col[2] * fade
                    for i, b in ipairs(bones) do
                        local p1 = char:FindFirstChild(b[1])
                        local p2 = char:FindFirstChild(b[2])
                        if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                            local s1, o1 = cam:WorldToViewportPoint(p1.Position)
                            local s2, o2 = cam:WorldToViewportPoint(p2.Position)
                            local d = ensure_skel(e, i)
                            if o1 and o2 then
                                d.From = Vector2.new(s1.X, s1.Y)
                                d.To = Vector2.new(s2.X, s2.Y)
                                d.Color = col
                                d.Transparency = a
                                d.Thickness = 1
                                d.Visible = true
                            else
                                d.Visible = false
                            end
                        else
                            local d = ensure_skel(e, i)
                            if d then d.Visible = false end
                        end
                    end
                    for i = #bones + 1, #e.skel do e.skel[i].Visible = false end
                else
                    for _, d in pairs(e.skel) do d.Visible = false end
                end

                -- FLAGS (роль)
                if esp.flags then
                    local role_text = role == "murder" and "[MURD]" or (role == "sheriff" and "[SHF]" or "")
                    if role_text ~= "" then
                        local d = ensure_flag(e, 1)
                        local col
                        if role == "murder" then
                            col = esp.flag_grd_mur and grad(0.5, esp.flag_grd_mur1, esp.flag_grd_mur2) or esp.flag_mur[1]
                        else
                            col = esp.flag_grd_shf and grad(0.5, esp.flag_grd_shf1, esp.flag_grd_shf2) or esp.flag_shf[1]
                        end
                        d.Text = role_text
                        d.Position = Vector2.new(head_sp.X + 60, head_sp.Y - 10)
                        d.Color = col
                        d.Transparency = fade
                        d.Visible = true
                        for i = 2, #e.flags do e.flags[i].Visible = false end
                    else
                        for _, d in pairs(e.flags) do d.Visible = false end
                    end
                else
                    for _, d in pairs(e.flags) do d.Visible = false end
                end

                -- ARROWS (offscreen)
                if esp.arrows then
                    local on_screen = (head_sp.X >= 0 and head_sp.X <= vp.X
                        and head_sp.Y >= 0 and head_sp.Y <= vp.Y)
                    if on_screen then
                        if e.arrow then e.arrow.Visible = false end
                    else
                        if not e.arrow then
                            e.arrow = Drawing.new("Triangle")
                            e.arrow.Filled = true
                        end
                        local cx, cy = vp.X * 0.5, vp.Y * 0.5
                        local dir = Vector2.new(head_sp.X - cx, head_sp.Y - cy)
                        if dir.Magnitude < 0.01 then dir = Vector2.new(0, 1) end
                        dir = dir.Unit
                        local px = cx + dir.X * esp.off_ar_dis
                        local py = cy + dir.Y * esp.off_ar_dis
                        local sz = esp.off_ar_sz
                        local perp = Vector2.new(-dir.Y, dir.X)
                        local tip = Vector2.new(px + dir.X * sz * 0.5, py + dir.Y * sz * 0.5)
                        local l = Vector2.new(px - dir.X * sz * 0.5 + perp.X * sz * 0.5, py - dir.Y * sz * 0.5 + perp.Y * sz * 0.5)
                        local r = Vector2.new(px - dir.X * sz * 0.5 - perp.X * sz * 0.5, py - dir.Y * sz * 0.5 - perp.Y * sz * 0.5)
                        e.arrow.PointA = tip
                        e.arrow.PointB = l
                        e.arrow.PointC = r
                        local col
                        if role == "murder" then col = esp.off_ar_col_mur[1]
                        elseif role == "sheriff" then col = esp.off_ar_col_shf[1]
                        else col = esp.off_ar_col_inno[1] end
                        e.arrow.Color = col
                        e.arrow.Transparency = fade
                        e.arrow.Visible = true
                    end
                elseif e.arrow then e.arrow.Visible = false end

                -- CHAMS
                update_chams(p, role)
            end

            -- Убираем умерших/вышедших
            for p, e in pairs(drawings) do
                if not now_players[p] then
                    dispose(e)
                    drawings[p] = nil
                end
            end

            update_mat_chams()
        end)
    end

    local function stop_render()
        if render_conn then
            pcall(function() render_conn:Disconnect() end)
            render_conn = nil
        end
        clear_all()
        for _, c in ipairs(chams_folder:GetChildren()) do c:Destroy() end
        for part, orig in pairs(mat_cache) do
            if part.Parent then
                pcall(function() part.Material = orig.m end)
                pcall(function() part.Color = orig.c end)
            end
        end
        table.clear(mat_cache)
    end

    -- ---- UI ----
    local vs = Tabs.Visual:AddSection({Name = "esp_engine"})

    vs:AddToggle("ESP_Engine_On", {Title = "ESP Engine v15.2", Default = false}):OnChanged(function(v)
        esp.on = v
        if v then start_render() else stop_render() end
        Notify(L("notify_title"), "ESP Engine " .. (v and "ON" or "OFF"), 1.5)
    end)

    local boxTgl = vs:AddToggle("ESP_Box", {Title = "Box", Default = false})
    boxTgl:OnChanged(function(v) esp.box = v end)
    vs:AddColorPicker("ESP_BoxCol", {Title = "Box Color", Default = Color3.new(1, 0, 0)})
        :OnChanged(function(c) esp.box_col[1] = c end)
    vs:AddSlider("ESP_BoxAlpha", {Title = "Box Alpha", Min = 0, Max = 1, Default = 1, Rounding = 2})
        :OnChanged(function(v) esp.box_col[2] = v end)
    vs:AddDropdown("ESP_BoxType", {Title = "Box Type", Values = {"Static", "Corners"}, Default = "Static"})
        :OnChanged(function(v) esp.box_type = v end)
    vs:AddToggle("ESP_BoxGrd", {Title = "Box Gradient", Default = false})
        :OnChanged(function(v) esp.box_grd = v end)
    vs:AddColorPicker("ESP_BoxGrd1", {Title = "Grad 1", Default = Color3.new(1, 0, 0)})
        :OnChanged(function(c) esp.box_grd1 = c end)
    vs:AddColorPicker("ESP_BoxGrd2", {Title = "Grad 2", Default = Color3.new(0, 0, 1)})
        :OnChanged(function(c) esp.box_grd2 = c end)
    vs:AddToggle("ESP_BoxFill", {Title = "Box Fill", Default = false})
        :OnChanged(function(v) esp.box_f = v end)
    vs:AddColorPicker("ESP_BoxFillCol", {Title = "Fill Color", Default = Color3.new(1, 0, 0)})
        :OnChanged(function(c) esp.box_f_col[1] = c end)
    vs:AddSlider("ESP_BoxFillAlpha", {Title = "Fill Alpha", Min = 0, Max = 1, Default = 0.5, Rounding = 2})
        :OnChanged(function(v) esp.box_f_col[2] = v end)

    vs:AddToggle("ESP_Name", {Title = "Name", Default = false}):OnChanged(function(v) esp.name = v end)
    vs:AddColorPicker("ESP_NameCol", {Title = "Name Color", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) esp.n_col[1] = c end)

    vs:AddToggle("ESP_Dist", {Title = "Distance", Default = false}):OnChanged(function(v) esp.dist = v end)
    vs:AddColorPicker("ESP_DistCol", {Title = "Distance Color", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) esp.d_col[1] = c end)

    vs:AddToggle("ESP_Avatar", {Title = "Avatar", Default = false}):OnChanged(function(v) esp.avatar = v end)

    vs:AddToggle("ESP_Skel", {Title = "Skeleton", Default = false}):OnChanged(function(v) esp.skel = v end)
    vs:AddColorPicker("ESP_SkelCol", {Title = "Skeleton Color", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) esp.skel_col[1] = c end)

    local chams_tgl = vs:AddToggle("ESP_Chams", {Title = "Glow Chams", Default = false})
    chams_tgl:OnChanged(function(v) esp.chams = v end)
    vs:AddColorPicker("ESP_ChamsFMur", {Title = "Murder Fill", Default = Color3.new(1, 0, 0)})
        :OnChanged(function(c) esp.chams_f_mur[1] = c end)
    vs:AddColorPicker("ESP_ChamsOMur", {Title = "Murder Outline", Default = Color3.new(1, 0, 0)})
        :OnChanged(function(c) esp.chams_o_mur[1] = c end)
    vs:AddColorPicker("ESP_ChamsFInno", {Title = "Inno Fill", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) esp.chams_f_inno[1] = c end)
    vs:AddColorPicker("ESP_ChamsOInno", {Title = "Inno Outline", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) esp.chams_o_inno[1] = c end)
    vs:AddColorPicker("ESP_ChamsFShf", {Title = "Sheriff Fill", Default = Color3.fromRGB(0, 153, 255)})
        :OnChanged(function(c) esp.chams_f_shf[1] = c end)
    vs:AddColorPicker("ESP_ChamsOShf", {Title = "Sheriff Outline", Default = Color3.fromRGB(0, 153, 255)})
        :OnChanged(function(c) esp.chams_o_shf[1] = c end)

    vs:AddToggle("ESP_MatChams", {Title = "Material Chams", Default = false})
        :OnChanged(function(v) esp.mat_chams = v end)
    vs:AddDropdown("ESP_MatType", {Title = "Mat Type", Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"})
        :OnChanged(function(v) esp.mat_chams_type = v end)
    vs:AddColorPicker("ESP_MatMur", {Title = "Murder", Default = Color3.new(1, 0, 0)})
        :OnChanged(function(c) esp.mat_col_mur = c end)
    vs:AddColorPicker("ESP_MatInno", {Title = "Inno", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) esp.mat_col_inno = c end)
    vs:AddColorPicker("ESP_MatShf", {Title = "Sheriff", Default = Color3.fromRGB(0, 153, 255)})
        :OnChanged(function(c) esp.mat_col_shf = c end)

    vs:AddToggle("ESP_Flags", {Title = "Flags (roles)", Default = false})
        :OnChanged(function(v) esp.flags = v end)

    local arTgl = vs:AddToggle("ESP_Arrows", {Title = "Off-screen Arrows", Default = false})
    arTgl:OnChanged(function(v) esp.arrows = v end)
    vs:AddColorPicker("ESP_ArrMur", {Title = "Murder", Default = Color3.fromRGB(255, 60, 60)})
        :OnChanged(function(c) esp.off_ar_col_mur[1] = c end)
    vs:AddColorPicker("ESP_ArrInno", {Title = "Inno", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) esp.off_ar_col_inno[1] = c end)
    vs:AddColorPicker("ESP_ArrShf", {Title = "Sheriff", Default = Color3.fromRGB(0, 153, 255)})
        :OnChanged(function(c) esp.off_ar_col_shf[1] = c end)
    vs:AddSlider("ESP_ArrSz", {Title = "Arrow Size", Min = 16, Max = 96, Default = 42, Rounding = 0})
        :OnChanged(function(v) esp.off_ar_sz = v end)
    vs:AddSlider("ESP_ArrDis", {Title = "Arrow Dist", Min = 40, Max = 520, Default = 260, Rounding = 0})
        :OnChanged(function(v) esp.off_ar_dis = v end)

    vs:AddToggle("ESP_AllowLocal", {Title = "Allow Local", Default = false})
        :OnChanged(function(v) esp.allow_local = v end)

    logInfo("ESP Engine v15.2 загружен")
end

-- ============================================================
-- SECTION K: EFFECTS — Bullet Tracer, Shaders, World FX, Aura
-- ============================================================
do
    local fx = Tabs.Effects:AddSection({Name = "effects_main"})

    -- ---- BULLET TRACER ----
    local tracer_on = false
    local tracer_col = Color3.fromRGB(133, 220, 255)
    local tracer_dur = 1
    local tracer_conn = nil

    local function make_point(pos, life)
        local p = Instance.new("Part")
        p.Transparency = 1
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.Size = Vector3.new(1, 1, 1)
        p.CFrame = CFrame.new(pos)
        Instance.new("Attachment", p)
        p.Parent = Workspace
        task.delay(life, function() pcall(function() p:Destroy() end) end)
        return p
    end

    local function to_pos(v)
        if typeof(v) == "Vector3" then return v end
        if typeof(v) == "CFrame" then return v.Position end
        if typeof(v) == "Instance" then
            if v:IsA("Attachment") then return v.WorldPosition end
            if v:IsA("BasePart") then return v.Position end
        end
    end

    local function create_tracer(sv, ev)
        local sp = to_pos(sv)
        local ep = to_pos(ev)
        if not sp or not ep then return end
        local p1 = make_point(sp, tracer_dur + 0.5)
        local p2 = make_point(ep, tracer_dur + 0.5)
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
        beam.Color = ColorSequence.new(tracer_col)
        beam.Transparency = NumberSequence.new(0.1)
        beam.Attachment0 = p1:FindFirstChildOfClass("Attachment")
        beam.Attachment1 = p2:FindFirstChildOfClass("Attachment")
        beam.Parent = p1
        task.delay(tracer_dur, function()
            if beam.Parent then
                TweenService:Create(beam, TweenInfo.new(0.2), {Width0 = 0, Width1 = 0}):Play()
            end
        end)
    end

    local function connect_tracer()
        if tracer_conn then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if not ok or not remote then return end
        tracer_conn = remote.OnClientEvent:Connect(function(gun, sv, ev)
            if not tracer_on then return end
            local char = LocalPlayer.Character
            if not char then return end
            if not (typeof(gun) == "Instance" and gun:IsDescendantOf(char)) then return end
            create_tracer(sv, ev)
        end)
    end

    local trTgl = fx:AddToggle("FX_Tracer", {Title = "Bullet Tracer", Default = false})
    trTgl:OnChanged(function(v)
        tracer_on = v
        if v then connect_tracer() end
    end)
    fx:AddColorPicker("FX_TracerCol", {Title = "Color", Default = Color3.fromRGB(133, 220, 255)})
        :OnChanged(function(c) tracer_col = c end)
    fx:AddSlider("FX_TracerDur", {Title = "Duration", Min = 0.1, Max = 5, Default = 1, Rounding = 1})
        :OnChanged(function(v) tracer_dur = v end)

    -- ---- WORLD AURA (angel / starlight / heavenly / ribbon / sakura / wind / flow / star) ----
    local aura_on = false
    local aura_type = "angel"
    local aura_col = Color3.fromRGB(133, 220, 255)
    local aura_ids = {
        angel = "97658130917593",
        starlight = "134645216613107",
        heavenly = "139300897520961",
        ribbon = "132069507632161",
        sakura = "81755778619404",
        wind = "80694081850877",
        flow = "119913533725648",
        star = "73754563740680",
    }
    local aura_cache = {}
    local aura_particles = {}
    local aura_conn = nil

    local function load_aura(name)
        if aura_cache[name] then return aura_cache[name] end
        local id = aura_ids[name]
        if not id then return nil end
        local ok, objs = pcall(game.GetObjects, game, "rbxassetid://"..id)
        if ok and objs and objs[1] then
            aura_cache[name] = objs[1]
            return objs[1]
        end
        return nil
    end

    local function color_aura(m, c)
        local seq = ColorSequence.new(c)
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("PointLight") then d.Color = c
            elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Color = seq end
        end
    end

    local function clear_aura()
        for i = #aura_particles, 1, -1 do
            pcall(function() aura_particles[i]:Destroy() end)
            aura_particles[i] = nil
        end
    end

    local function apply_aura()
        clear_aura()
        local char = LocalPlayer.Character
        if not char then return end
        local src = load_aura(aura_type)
        if not src then return end
        color_aura(src, aura_col)
        local clone = src:Clone()
        for _, part in ipairs(clone:GetChildren()) do
            local target = char:FindFirstChild(part.Name)
            if target and target:IsA("BasePart") then
                for _, child in ipairs(part:GetChildren()) do
                    child.Parent = target
                    aura_particles[#aura_particles + 1] = child
                end
            end
        end
        clone:Destroy()
    end

    local function start_aura()
        if aura_conn then return end
        aura_conn = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if aura_on then apply_aura() end
        end)
        task.spawn(apply_aura)
    end

    local function stop_aura()
        if aura_conn then pcall(function() aura_conn:Disconnect() end) aura_conn = nil end
        clear_aura()
    end

    local auraTgl = fx:AddToggle("FX_Aura", {Title = "World Aura", Default = false})
    auraTgl:OnChanged(function(v)
        aura_on = v
        if v then start_aura() else stop_aura() end
    end)
    fx:AddDropdown("FX_AuraType", {
        Title = "Type",
        Values = {"angel", "starlight", "heavenly", "ribbon", "sakura", "wind", "flow", "star"},
        Default = "angel",
    }):OnChanged(function(v)
        aura_type = v
        if aura_on then task.spawn(apply_aura) end
    end)
    fx:AddColorPicker("FX_AuraCol", {Title = "Color", Default = Color3.fromRGB(133, 220, 255)})
        :OnChanged(function(c)
            aura_col = c
            for _, m in pairs(aura_cache) do color_aura(m, c) end
            if aura_on then task.spawn(apply_aura) end
        end)

    -- ---- WORLD FX (Snow / Sakura) ----
    local fxw_on, fxw_type, fxw_col, fxw_rate = false, "Snow", Color3.fromRGB(150, 200, 255), 250
    local fxw_part, fxw_emit, fxw_conn = nil, nil, nil

    local function style_wfx()
        local e = fxw_emit
        if not e then return end
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.LightInfluence = 0
        e.LightEmission = 0.4
        e.EmissionDirection = Enum.NormalId.Bottom
        e.Rate = fxw_rate
        e.Color = ColorSequence.new(fxw_col)
        if fxw_type == "Snow" then
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

    local function stop_wfx()
        if fxw_conn then pcall(function() fxw_conn:Disconnect() end) fxw_conn = nil end
        if fxw_part then pcall(function() fxw_part:Destroy() end) fxw_part = nil end
        fxw_emit = nil
    end

    local function start_wfx()
        stop_wfx()
        fxw_part = Instance.new("Part")
        fxw_part.Name = "FH_WORLD_FX"
        fxw_part.Anchored = true
        fxw_part.CanCollide = false
        fxw_part.CanQuery = false
        fxw_part.CanTouch = false
        fxw_part.Transparency = 1
        fxw_part.Size = Vector3.new(260, 140, 260)
        fxw_part.Parent = Workspace
        fxw_emit = Instance.new("ParticleEmitter")
        pcall(function()
            fxw_emit.Shape = Enum.ParticleEmitterShape.Box
            fxw_emit.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        end)
        fxw_emit.Parent = fxw_part
        style_wfx()
        fxw_conn = RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local cf = cam.CFrame
            local d = cf.LookVector
            local flat = Vector3.new(d.X, 0, d.Z)
            if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
            fxw_part.CFrame = CFrame.new(cf.Position + flat * 57 + Vector3.new(0, 44, 0))
        end)
    end

    local fxwTgl = fx:AddToggle("FX_World", {Title = "World Effects", Default = false})
    fxwTgl:OnChanged(function(v)
        fxw_on = v
        if v then start_wfx() else stop_wfx() end
    end)
    fx:AddDropdown("FX_WorldType", {Title = "Type", Values = {"Snow", "Sakura"}, Default = "Snow"})
        :OnChanged(function(v)
            fxw_type = v
            if fxw_on then style_wfx() end
        end)
    fx:AddColorPicker("FX_WorldCol", {Title = "Color", Default = Color3.fromRGB(150, 200, 255)})
        :OnChanged(function(c)
            fxw_col = c
            if fxw_emit then fxw_emit.Color = ColorSequence.new(c) end
        end)
    fx:AddSlider("FX_WorldRate", {Title = "Rate", Min = 20, Max = 900, Default = 250, Rounding = 1})
        :OnChanged(function(v)
            fxw_rate = v
            if fxw_emit then style_wfx() end
        end)

    -- ---- SHADERS (morning/midday/evening/night) ----
    local shader_on, shader_type = false, "morning"
    local orig_light = {
        Amb = Lighting.Ambient, Br = Lighting.Brightness, CT = Lighting.ClockTime,
        CSB = Lighting.ColorShift_Bottom, CST = Lighting.ColorShift_Top,
        Exp = Lighting.ExposureCompensation,
        FC = Lighting.FogColor, FS = Lighting.FogStart, FE = Lighting.FogEnd,
        OA = Lighting.OutdoorAmbient, GS = Lighting.GlobalShadows,
    }
    local shader_presets = {
        morning = {
            amb = Color3.fromRGB(10, 10, 10), br = 1.5, ct = 7.5,
            csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(200, 200, 200), exp = 0.3,
        },
        midday = {
            amb = Color3.fromRGB(2, 2, 2), br = 3.25, ct = 8,
            csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(255, 247, 237), exp = 0.85,
        },
        evening = {
            amb = Color3.fromRGB(2, 2, 2), br = 2.25, ct = 16,
            csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(255, 247, 237), exp = 0.65,
        },
        night = {
            amb = Color3.fromRGB(33, 33, 33), br = 3.25, ct = 20,
            csb = Color3.fromRGB(0, 0, 0), cst = Color3.fromRGB(255, 247, 237), exp = 0.85,
        },
    }
    local shader_conn

    local function apply_shader()
        local p = shader_presets[shader_type]
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

    local function restore_shader()
        Lighting.Ambient = orig_light.Amb
        Lighting.Brightness = orig_light.Br
        Lighting.ClockTime = orig_light.CT
        Lighting.ColorShift_Bottom = orig_light.CSB
        Lighting.ColorShift_Top = orig_light.CST
        Lighting.ExposureCompensation = orig_light.Exp
        Lighting.FogColor = orig_light.FC
        Lighting.FogStart = orig_light.FS
        Lighting.FogEnd = orig_light.FE
        Lighting.OutdoorAmbient = orig_light.OA
        Lighting.GlobalShadows = orig_light.GS
    end

    local shTgl = fx:AddToggle("FX_Shader", {Title = "Shaders", Default = false})
    shTgl:OnChanged(function(v)
        shader_on = v
        if v then
            apply_shader()
            if not shader_conn then
                shader_conn = RunService.Heartbeat:Connect(function()
                    if shader_on then apply_shader() end
                end)
            end
        else
            restore_shader()
        end
    end)
    fx:AddDropdown("FX_ShaderType", {Title = "Preset", Values = {"morning", "midday", "evening", "night"}, Default = "morning"})
        :OnChanged(function(v)
            shader_type = v
            if shader_on then apply_shader() end
        end)

    -- ---- CUSTOM FOG ----
    local fog_on, fog_col, fog_start, fog_end = false, Color3.fromRGB(192, 192, 192), 0, 1000
    local fogTgl = fx:AddToggle("FX_Fog", {Title = "Custom Fog", Default = false})
    fogTgl:OnChanged(function(v)
        fog_on = v
        if v then
            Lighting.FogColor = fog_col
            Lighting.FogStart = fog_start
            Lighting.FogEnd = fog_end
        else
            Lighting.FogColor = orig_light.FC
            Lighting.FogStart = orig_light.FS
            Lighting.FogEnd = orig_light.FE
        end
    end)
    fx:AddColorPicker("FX_FogCol", {Title = "Color", Default = Color3.fromRGB(192, 192, 192)})
        :OnChanged(function(c)
            fog_col = c
            if fog_on then Lighting.FogColor = c end
        end)
    fx:AddSlider("FX_FogStart", {Title = "Start", Min = 0, Max = 1000, Default = 0, Rounding = 0})
        :OnChanged(function(v)
            fog_start = v
            if fog_on then Lighting.FogStart = v end
        end)
    fx:AddSlider("FX_FogEnd", {Title = "End", Min = 0, Max = 1000, Default = 1000, Rounding = 0})
        :OnChanged(function(v)
            fog_end = v
            if fog_on then Lighting.FogEnd = v end
        end)

    -- ---- AMBIENT ----
    local amb_on, amb_col = false, Color3.fromRGB(128, 128, 128)
    local ambTgl = fx:AddToggle("FX_Ambient", {Title = "Custom Ambient", Default = false})
    ambTgl:OnChanged(function(v)
        amb_on = v
        if v then
            Lighting.Ambient = amb_col
            Lighting.OutdoorAmbient = amb_col
        else
            Lighting.Ambient = orig_light.Amb
            Lighting.OutdoorAmbient = orig_light.OA
        end
    end)
    fx:AddColorPicker("FX_AmbientCol", {Title = "Ambient Color", Default = Color3.fromRGB(128, 128, 128)})
        :OnChanged(function(c)
            amb_col = c
            if amb_on then
                Lighting.Ambient = c
                Lighting.OutdoorAmbient = c
            end
        end)

    -- ---- EXPOSURE ----
    local exp_on, exp_val = false, 0
    local expTgl = fx:AddToggle("FX_Exposure", {Title = "Exposure", Default = false})
    expTgl:OnChanged(function(v)
        exp_on = v
        if v then Lighting.ExposureCompensation = exp_val
        else Lighting.ExposureCompensation = orig_light.Exp end
    end)
    fx:AddSlider("FX_ExposureVal", {Title = "Value", Min = -5, Max = 5, Default = 0, Rounding = 2})
        :OnChanged(function(v)
            exp_val = v
            if exp_on then Lighting.ExposureCompensation = v end
        end)

    -- ---- SKYBOX ----
    local sky_on, sky_name = false, "Jungle"
    local created_sky, orig_sky, orig_sky_parent = nil, nil, nil
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
    local sky_assets = {
        ["Galaxy"] = 15983996673,
        ["Anime"] = 13107361022,
        ["Minecraft"] = 2758029221,
    }

    local function clear_sky()
        if created_sky then
            pcall(function() created_sky:Destroy() end)
            created_sky = nil
        end
    end

    local function detach_orig_sky()
        if orig_sky then return end
        local existing = Lighting:FindFirstChildOfClass("Sky")
        if existing and existing ~= created_sky then
            orig_sky = existing
            orig_sky_parent = existing.Parent
            pcall(function() existing.Parent = nil end)
        end
    end

    local function apply_sky(name)
        detach_orig_sky()
        clear_sky()
        if skyboxes[name] then
            local sky = Instance.new("Sky")
            sky.Name = "FH_CustomSky"
            for k, v in pairs(skyboxes[name]) do
                pcall(function() sky[k] = v end)
            end
            sky.Parent = Lighting
            created_sky = sky
        elseif sky_assets[name] then
            task.spawn(function()
                local ok, objs = pcall(game.GetObjects, game, "rbxassetid://"..sky_assets[name])
                if not ok or type(objs) ~= "table" then return end
                local found
                for _, o in ipairs(objs) do
                    if o:IsA("Sky") then found = o break end
                    local s = o:FindFirstChildWhichIsA("Sky", true)
                    if s then found = s break end
                end
                if not found or not sky_on then return end
                clear_sky()
                found.Name = "FH_CustomSky"
                found.Parent = Lighting
                created_sky = found
            end)
        end
    end

    local function restore_sky()
        clear_sky()
        if orig_sky then
            pcall(function() orig_sky.Parent = orig_sky_parent or Lighting end)
            orig_sky, orig_sky_parent = nil, nil
        end
    end

    local skyTgl = fx:AddToggle("FX_Skybox", {Title = "Skybox", Default = false})
    skyTgl:OnChanged(function(v)
        sky_on = v
        if v then apply_sky(sky_name) else restore_sky() end
    end)
    fx:AddDropdown("FX_SkyType", {
        Title = "Preset",
        Values = {"Jungle", "Blossom", "Red night", "Purple", "Foggy", "Galaxy", "Anime", "Minecraft"},
        Default = "Jungle",
    }):OnChanged(function(v)
        sky_name = v
        if sky_on then apply_sky(v) end
    end)

    logInfo("Effects main загружены (tracer, aura, world fx, shader, fog, ambient, exposure, skybox)")
end

-- ============================================================
-- SECTION L: CROSSHAIR (для Шерифа)
-- ============================================================
do
    local cx_section = Tabs.Effects:AddSection({Name = "crosshair"})

    local ch_on = false
    local ch_gap, ch_len, ch_thick = 4, 8, 2
    local ch_col, ch_out = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
    local ch_rot = 0
    local ch_rot_now = 0
    local ch_lines = {}
    local ch_conn = nil

    local function has_gun()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("Gun") ~= nil
    end

    local function kill_cross()
        for i = 1, #ch_lines do pcall(function() ch_lines[i]:Remove() end) end
        ch_lines = {}
        if ch_conn then pcall(function() ch_conn:Disconnect() end) ch_conn = nil end
    end

    local function build_cross()
        kill_cross()
        for i = 1, 8 do
            local l = Drawing.new("Line")
            l.Visible = false
            l.Color = (i % 2 == 0) and ch_out or ch_col
            l.Thickness = (i % 2 == 0) and (ch_thick + 2) or ch_thick
            l.Transparency = 1
            l.ZIndex = (i % 2 == 0) and 999 or 1000
            ch_lines[i] = l
        end
        ch_conn = RunService.RenderStepped:Connect(function(dt)
            if not ch_on then
                for i = 1, #ch_lines do ch_lines[i].Visible = false end
                return
            end
            if not has_gun() then
                for i = 1, #ch_lines do ch_lines[i].Visible = false end
                return
            end
            if ch_rot > 0 then
                ch_rot_now = (ch_rot_now + dt * ch_rot * 100) % 360
            else
                ch_rot_now = 0
            end
            local mp = UserInputService:GetMouseLocation()
            local cx, cy = mp.X, mp.Y
            local rr = math.rad(ch_rot_now)
            local angs = {rr, math.pi / 2 + rr, math.pi + rr, 3 * math.pi / 2 + rr}
            for i = 1, 4 do
                local a = angs[i]
                local li = (i - 1) * 2 + 1
                local oi = li + 1
                local sx = cx + ch_gap * math.cos(a)
                local sy = cy + ch_gap * math.sin(a)
                local ex = cx + (ch_gap + ch_len) * math.cos(a)
                local ey = cy + (ch_gap + ch_len) * math.sin(a)
                local ox1 = cx + (ch_gap - 1) * math.cos(a)
                local oy1 = cy + (ch_gap - 1) * math.sin(a)
                local ox2 = cx + (ch_gap + ch_len + 1) * math.cos(a)
                local oy2 = cy + (ch_gap + ch_len + 1) * math.sin(a)
                local l1, l2 = ch_lines[li], ch_lines[oi]
                if l1 then
                    l1.From = Vector2.new(sx, sy)
                    l1.To = Vector2.new(ex, ey)
                    l1.Visible = true
                    l1.Color = ch_col
                    l1.Thickness = ch_thick
                end
                if l2 then
                    l2.From = Vector2.new(ox1, oy1)
                    l2.To = Vector2.new(ox2, oy2)
                    l2.Visible = true
                    l2.Color = ch_out
                    l2.Thickness = ch_thick + 2
                end
            end
        end)
    end

    cx_section:AddToggle("CX_Enabled", {Title = "Custom Crosshair", Default = false}):OnChanged(function(v)
        ch_on = v
        if v then build_cross() else kill_cross() end
    end)
    cx_section:AddSlider("CX_Gap", {Title = "Gap", Min = 0, Max = 20, Default = 4, Rounding = 1})
        :OnChanged(function(v) ch_gap = v end)
    cx_section:AddSlider("CX_Len", {Title = "Length", Min = 2, Max = 30, Default = 8, Rounding = 1})
        :OnChanged(function(v) ch_len = v end)
    cx_section:AddSlider("CX_Thick", {Title = "Thickness", Min = 1, Max = 5, Default = 2, Rounding = 1})
        :OnChanged(function(v)
            ch_thick = v
            for i = 1, #ch_lines do
                if ch_lines[i] then
                    ch_lines[i].Thickness = (i % 2 == 0) and v + 2 or v
                end
            end
        end)
    cx_section:AddSlider("CX_Rot", {Title = "Rotation", Min = 0, Max = 10, Default = 0, Rounding = 1})
        :OnChanged(function(v) ch_rot = v end)
    cx_section:AddColorPicker("CX_Col", {Title = "Color", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c)
            ch_col = c
            for i = 1, #ch_lines do
                if ch_lines[i] and i % 2 == 1 then ch_lines[i].Color = c end
            end
        end)
    cx_section:AddColorPicker("CX_Out", {Title = "Outline", Default = Color3.new(0, 0, 0)})
        :OnChanged(function(c)
            ch_out = c
            for i = 1, #ch_lines do
                if ch_lines[i] and i % 2 == 0 then ch_lines[i].Color = c end
            end
        end)

    logInfo("Crosshair загружен")
end

-- ============================================================
-- SECTION M: MURDER EFFECT + PLAYERS DEATH EFFECT
-- ============================================================
do
    local me_sec = Tabs.Effects:AddSection({Name = "murder_effect"})

    local murderer_on, murderer_clone_on, murderer_particle_on, murderer_emitter_on = false, false, false, false
    local murderer_clone_col = Color3.fromRGB(255, 0, 0)
    local murderer_particle_col = Color3.fromRGB(255, 0, 0)
    local murderer_emitter_col = Color3.fromRGB(255, 100, 100)
    local murderer_clone_dur, murderer_emitter_dur = 3, 1.2
    local murder_clones, murder_death_conns, murder_roles = {}, {}, {}
    local murder_poll_thread, murder_add_conn = nil, nil
    local murder_emitter_active = {}

    local function remove_me_emitter(rec)
        for i = 1, #murder_emitter_active do
            if murder_emitter_active[i] == rec then
                murder_emitter_active[i] = murder_emitter_active[#murder_emitter_active]
                murder_emitter_active[#murder_emitter_active] = nil
                break
            end
        end
        if rec.part and rec.part.Parent then rec.part:Destroy() end
    end

    local function spawn_neverlose_emitter(char, tint, dur, channel)
        if not char or not char.Parent then return end
        if #murder_emitter_active >= 3 then remove_me_emitter(murder_emitter_active[1]) end
        dur = math.max(dur, 0.2)
        local body_parts = {}
        for _, s in ipairs(char:GetChildren()) do
            if s:IsA("BasePart") and s.Name ~= "HumanoidRootPart" and #body_parts < 15 then
                body_parts[#body_parts + 1] = s
            end
        end
        if #body_parts == 0 then return end

        local root = Instance.new("Folder")
        root.Name = "FH_MurderFX"
        root.Parent = Workspace
        local rec = {part = root, balls = {}, channel = channel}
        murder_emitter_active[#murder_emitter_active + 1] = rec

        local rnd = math.random
        local golden = math.pi * (3 - math.sqrt(5))
        local function surf_pos(source, radius, index, count, head_seed)
            local sz = source.Size
            local pad = radius * 0.92
            if source.Name == "Head" then
                local y = 1 - 2 * ((index - 0.5) / count)
                local angle = index * golden + head_seed
                local radial = math.sqrt(math.max(0, 1 - y * y))
                local dir = Vector3.new(radial * math.cos(angle), y, radial * math.sin(angle))
                local half = sz * 0.5
                return source.CFrame:PointToWorldSpace(Vector3.new(
                    dir.X * (half.X + pad), dir.Y * (half.Y + pad), dir.Z * (half.Z + pad)))
            end
            local area_x = sz.Y * sz.Z
            local area_y = sz.X * sz.Z
            local area_z = sz.X * sz.Y
            local pick = rnd() * (area_x + area_y + area_z)
            local pos
            if pick < area_x then
                local side = rnd() < 0.5 and -1 or 1
                pos = Vector3.new(side * (sz.X * 0.5 + pad), (rnd() - 0.5) * sz.Y, (rnd() - 0.5) * sz.Z)
            elseif pick < area_x + area_y then
                local side = rnd() < 0.5 and -1 or 1
                pos = Vector3.new((rnd() - 0.5) * sz.X, side * (sz.Y * 0.5 + pad), (rnd() - 0.5) * sz.Z)
            else
                local side = rnd() < 0.5 and -1 or 1
                pos = Vector3.new((rnd() - 0.5) * sz.X, (rnd() - 0.5) * sz.Y, side * (sz.Z * 0.5 + pad))
            end
            return source.CFrame:PointToWorldSpace(pos)
        end

        local min_y, max_y = math.huge, -math.huge
        for _, s in ipairs(body_parts) do
            local hy = s.Size.Y * 0.5
            min_y = math.min(min_y, s.Position.Y - hy)
            max_y = math.max(max_y, s.Position.Y + hy)
        end

        local phase_count = 8
        local groups = {}
        for i = 1, phase_count do groups[i] = {} end
        local head_seed = rnd() * math.pi * 2
        local height = math.max(max_y - min_y, 0.01)
        local created = 0
        for _, s in ipairs(body_parts) do
            local sz = s.Size
            local surface = 2 * (sz.X * sz.Y + sz.X * sz.Z + sz.Y * sz.Z)
            local count = s.Name == "Head" and 24 or math.clamp(math.floor(surface * 0.65 + 0.5), 7, 12)
            count = math.min(count, 140 - created)
            for index = 1, count do
                local dia = s.Name == "Head" and (0.115 + rnd() * 0.045) or (0.13 + rnd() * 0.06)
                local tsz = Vector3.new(dia, dia, dia)
                local pos = surf_pos(s, dia * 0.5, index, count, head_seed)
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
                local vertical = math.clamp((pos.Y - min_y) / height, 0, 1)
                local phase = math.clamp(math.floor(vertical * (phase_count - 1) + 1.5) + rnd(-1, 1), 1, phase_count)
                groups[phase][#groups[phase] + 1] = {ball = ball, size = tsz}
            end
            if created >= 140 then break end
        end

        local reveal_window = math.min(0.34, dur * 0.26)
        local reveal_time = math.min(0.2, dur * 0.18)
        local fade_begin = math.max(reveal_window + reveal_time + 0.06, dur * 0.42)
        local fade_window = math.min(0.28, dur * 0.18)
        local fade_time = math.max(dur - fade_begin - fade_window, 0.1)
        for phase = 1, phase_count do
            local alpha = (phase - 1) / (phase_count - 1)
            local group = groups[phase]
            task.delay(reveal_window * alpha, function()
                if not root.Parent then return end
                for _, item in ipairs(group) do
                    if item.ball.Parent then
                        TweenService:Create(item.ball, TweenInfo.new(reveal_time, Enum.EasingStyle.Sine), {
                            Size = item.size, Transparency = 0.05,
                        }):Play()
                    end
                end
            end)
            task.delay(fade_begin + fade_window * alpha, function()
                if not root.Parent then return end
                for _, item in ipairs(group) do
                    if item.ball.Parent then
                        TweenService:Create(item.ball, TweenInfo.new(fade_time, Enum.EasingStyle.Sine), {
                            Size = item.size * 0.58, Transparency = 1,
                        }):Play()
                    end
                end
            end)
        end
        task.delay(dur + 0.12, function() remove_me_emitter(rec) end)
    end

    local function make_murder_clone(char)
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
                    d.Color = murderer_clone_col
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
        murder_clones[#murder_clones + 1] = clone
        task.delay(murderer_clone_dur, function()
            if not clone.Parent then return end
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    TweenService:Create(d, TweenInfo.new(1.5), {Transparency = 1}):Play()
                end
            end
            task.delay(1.6, function()
                for i = #murder_clones, 1, -1 do
                    if murder_clones[i] == clone then table.remove(murder_clones, i) end
                end
                if clone.Parent then clone:Destroy() end
            end)
        end)
    end

    local function on_murder_death(char)
        if murderer_clone_on then make_murder_clone(char) end
        if murderer_particle_on then spawn_neverlose_emitter(char, murderer_particle_col, 1.2, "particle") end
        if murderer_emitter_on then spawn_neverlose_emitter(char, murderer_emitter_col, murderer_emitter_dur, "emitter") end
    end

    local function hook_murder_player(pl)
        local function on_char(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            murder_death_conns[#murder_death_conns + 1] = hum.Died:Connect(function()
                if murderer_on and murder_roles[pl.Name] == "Murderer" then
                    on_murder_death(char)
                end
            end)
        end
        if pl.Character then task.spawn(on_char, pl.Character) end
        murder_death_conns[#murder_death_conns + 1] = pl.CharacterAdded:Connect(on_char)
    end

    local function stop_murder_effect()
        for _, c in ipairs(murder_death_conns) do pcall(function() c:Disconnect() end) end
        murder_death_conns = {}
        for i = 1, #murder_emitter_active do
            local p = murder_emitter_active[i]
            if p then pcall(function() p.part:Destroy() end) end
        end
        murder_emitter_active = {}
        if murder_add_conn then pcall(function() murder_add_conn:Disconnect() end) murder_add_conn = nil end
        for _, c in ipairs(murder_clones) do pcall(function() c:Destroy() end) end
        murder_clones = {}
    end

    local me_tgl = me_sec:AddToggle("ME_Enabled", {Title = "Murder Death Effect", Default = false})
    me_tgl:OnChanged(function(v)
        murderer_on = v
        if v then
            murder_poll_thread = task.spawn(function()
                while murderer_on do
                    pcall(function()
                        local f = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
                        local data = f and f:InvokeServer()
                        if type(data) == "table" then
                            local m = {}
                            for name, d in pairs(data) do
                                if type(d) == "table" and d.Role then m[name] = d.Role end
                            end
                            murder_roles = m
                        end
                    end)
                    task.wait(1)
                end
            end)
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LocalPlayer then hook_murder_player(pl) end
            end
            murder_add_conn = Players.PlayerAdded:Connect(function(pl)
                if pl ~= LocalPlayer then hook_murder_player(pl) end
            end)
        else
            stop_murder_effect()
            if murder_poll_thread then pcall(function() task.cancel(murder_poll_thread) end) murder_poll_thread = nil end
        end
    end)
    me_sec:AddToggle("ME_Clone", {Title = "Clone", Default = false})
        :OnChanged(function(v) murderer_clone_on = v end)
    me_sec:AddColorPicker("ME_CloneCol", {Title = "Clone Color", Default = Color3.fromRGB(255, 0, 0)})
        :OnChanged(function(c)
            murderer_clone_col = c
            for _, cl in ipairs(murder_clones) do
                for _, d in ipairs(cl:GetDescendants()) do
                    if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then d.Color = c end
                end
            end
        end)
    me_sec:AddSlider("ME_CloneDur", {Title = "Clone Duration", Min = 1, Max = 5, Default = 3, Rounding = 1})
        :OnChanged(function(v) murderer_clone_dur = v end)
    me_sec:AddToggle("ME_Particle", {Title = "Particle", Default = false})
        :OnChanged(function(v) murderer_particle_on = v end)
    me_sec:AddColorPicker("ME_PartCol", {Title = "Particle Color", Default = Color3.fromRGB(255, 0, 0)})
        :OnChanged(function(c) murderer_particle_col = c end)
    me_sec:AddToggle("ME_Emitter", {Title = "Neverlose Emitter", Default = false})
        :OnChanged(function(v) murderer_emitter_on = v end)
    me_sec:AddColorPicker("ME_EmitCol", {Title = "Emitter Color", Default = Color3.fromRGB(255, 100, 100)})
        :OnChanged(function(c)
            murderer_emitter_col = c
            for i = 1, #murder_emitter_active do
                local e = murder_emitter_active[i]
                if e and e.channel == "emitter" then
                    for _, b in ipairs(e.balls) do
                        if b.Parent then b.Color = c end
                    end
                end
            end
        end)
    me_sec:AddSlider("ME_EmitDur", {Title = "Emitter Duration", Min = 1, Max = 5, Default = 1, Rounding = 1})
        :OnChanged(function(v) murderer_emitter_dur = v end)

    logInfo("Murder Effect загружен")
end

-- ============================================================
-- SECTION N: CHINA HAT + BACKTRACK + LANDING CIRCLE + MOVEMENT GRAPH
-- ============================================================
do
    local ls = Tabs.Visual:AddSection({Name = "local_visuals"})

    -- ---- CHINA HAT ----
    local ch_on, ch_col = false, Color3.fromRGB(255, 60, 60)
    local ch_segments = 48
    local ch_tau = math.pi * 2
    local ch_radius, ch_height = 1.55, 0.82
    local ch_conn = nil
    local ch_rows = {}

    local function ch_clear()
        for i = 1, #ch_rows do pcall(function() ch_rows[i]:Remove() end) end
        ch_rows = {}
    end

    local function ch_update()
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then return end
        local cam = Workspace.CurrentCamera
        if not cam then return end

        local base = Vector3.new(head.Position.X, head.Position.Y + head.Size.Y * 0.5, head.Position.Z)
        local apex = cam:WorldToViewportPoint(base + Vector3.new(0, ch_height, 0))
        if apex.Z <= 0 then return end

        local pts_x, pts_y = {}, {}
        pts_x[1] = apex.X
        pts_y[1] = apex.Y

        local cos_v, sin_v = {}, {}
        for i = 1, ch_segments do
            local a = (i - 1) / ch_segments * ch_tau
            cos_v[i] = math.cos(a) * ch_radius
            sin_v[i] = math.sin(a) * ch_radius
        end

        local valid = true
        for i = 1, ch_segments do
            local p = cam:WorldToViewportPoint(base + Vector3.new(cos_v[i], 0, sin_v[i]))
            if p.Z <= 0 then valid = false break end
            pts_x[i + 1] = p.X
            pts_y[i + 1] = p.Y
        end
        if not valid then return end

        -- convex hull (Andrew monotone)
        local ord = {}
        for i = 1, ch_segments + 1 do ord[i] = i end
        table.sort(ord, function(i, j)
            if pts_x[i] == pts_x[j] then return pts_y[i] < pts_y[j] end
            return pts_x[i] < pts_x[j]
        end)
        local stack, m = {}, 0
        for k = 1, ch_segments + 1 do
            local i = ord[k]
            while m >= 2 do
                local o, a = stack[m - 1], stack[m]
                if (pts_x[a] - pts_x[o]) * (pts_y[i] - pts_y[o]) - (pts_y[a] - pts_y[o]) * (pts_x[i] - pts_x[o]) > 0 then break end
                m = m - 1
            end
            m = m + 1
            stack[m] = i
        end
        local lower = m
        for k = ch_segments, 1, -1 do
            local i = ord[k]
            while m > lower do
                local o, a = stack[m - 1], stack[m]
                if (pts_x[a] - pts_x[o]) * (pts_y[i] - pts_y[o]) - (pts_y[a] - pts_y[o]) * (pts_x[i] - pts_x[o]) > 0 then break end
                m = m - 1
            end
            m = m + 1
            stack[m] = i
        end
        local hn = m - 1

        local minY, maxY = math.huge, -math.huge
        for i = 1, hn do
            local y = pts_y[stack[i]]
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
            local ax, ay = pts_x[stack[hn]], pts_y[stack[hn]]
            for i = 1, hn do
                local ix = stack[i]
                local bx, by = pts_x[ix], pts_y[ix]
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
                local row = ch_rows[used]
                if not row then
                    row = Drawing.new("Square")
                    row.Filled = true
                    row.Thickness = 0
                    row.Transparency = 0.72
                    row.ZIndex = 1
                    ch_rows[used] = row
                end
                local t = (y - minY) / span
                local light = math.max(0, 1 - t * 1.35)
                local dark = math.max(0, (t - 0.58) / 0.42)
                local col = ch_col:Lerp(Color3.new(1, 1, 1), light * 0.26):Lerp(Color3.new(0, 0, 0), dark * 0.1)
                row.Position = Vector2.new(left, y0)
                row.Size = Vector2.new(w, h)
                row.Color = col
                row.Visible = true
            end
        end
        for i = used + 1, #ch_rows do ch_rows[i].Visible = false end
    end

    local chTgl = ls:AddToggle("LV_ChinaHat", {Title = "China Hat", Default = false})
    chTgl:OnChanged(function(v)
        ch_on = v
        if v then
            if not ch_conn then
                ch_conn = RunService.Heartbeat:Connect(function()
                    if ch_on then ch_update() end
                end)
            end
        else
            if ch_conn then pcall(function() ch_conn:Disconnect() end) ch_conn = nil end
            ch_clear()
        end
    end)
    ls:AddColorPicker("LV_ChinaCol", {Title = "Hat Color", Default = Color3.fromRGB(255, 60, 60)})
        :OnChanged(function(c) ch_col = c end)

    -- ---- BACKTRACK ----
    local bt_on = false
    local bt_col = Color3.fromRGB(255, 60, 60)
    local bt_model = nil
    local bt_pairs = {}
    local bt_CAP = 256
    local bt_hist = table.create(bt_CAP)
    for i = 1, bt_CAP do bt_hist[i] = {0, CFrame.identity} end
    local bt_first, bt_count = 1, 0
    local bt_ping, bt_ping_at = 0.15, 0

    local function bt_kill()
        if bt_model then pcall(function() bt_model:Destroy() end) bt_model = nil end
        bt_pairs = {}
        bt_first, bt_count = 1, 0
    end

    local function bt_build()
        bt_kill()
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
                    o.Color = bt_col
                    o.Transparency = 0
                end
                ci = ci + 1
                bt_pairs[#bt_pairs + 1] = {o, rp[ci]}
            end
        end
        local h = m:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:Destroy() end) end
        m.Parent = Workspace
        bt_model = m
    end

    local function bt_update()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not bt_model then bt_build() if not bt_model then return end end
        if not bt_model.Parent then bt_model.Parent = Workspace end

        local now = os.clock()
        local cf = hrp.CFrame
        if bt_count < bt_CAP then bt_count = bt_count + 1
        else bt_first = bt_first % bt_CAP + 1 end
        local slot = bt_hist[(bt_first + bt_count - 2) % bt_CAP + 1]
        slot[1], slot[2] = now, cf

        if now - bt_ping_at >= 0.2 then
            bt_ping_at = now
            local ok, v = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            end)
            bt_ping = math.clamp((ok and v) or 0.15, 0.05, 0.6)
        end

        local target = now - bt_ping
        local targetCF = cf
        for k = bt_count, 1, -1 do
            local s = bt_hist[(bt_first + k - 2) % bt_CAP + 1]
            if s[1] <= target then targetCF = s[2] break end
        end
        local inv = hrp.CFrame:Inverse()
        for i = 1, #bt_pairs do
            local cp, rp = bt_pairs[i][1], bt_pairs[i][2]
            if cp and cp.Parent and rp and rp.Parent then
                cp.CFrame = targetCF * (inv * rp.CFrame)
            end
        end
    end

    local btTgl = ls:AddToggle("LV_Backtrack", {Title = "Backtrack", Default = false})
    btTgl:OnChanged(function(v)
        bt_on = v
        if v then
            if not _G.FH_BT_CONN then
                _G.FH_BT_CONN = RunService.Heartbeat:Connect(function()
                    if bt_on then bt_update() end
                end)
            end
            if not bt_model then bt_build() end
        else
            bt_kill()
        end
    end)
    ls:AddColorPicker("LV_BackCol", {Title = "Color", Default = Color3.fromRGB(255, 60, 60)})
        :OnChanged(function(c)
            bt_col = c
            if bt_model then
                for _, p in ipairs(bt_model:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Color = c end
                end
            end
        end)

    -- ---- LANDING CIRCLE ----
    local lc_on, lc_col, lc_tr, lc_dur = false, Color3.new(1, 1, 1), 1, 0.82
    local lc_conn = nil

    local function make_land(p, n)
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
        img.ImageColor3 = lc_col
        img.ImageTransparency = 1 - lc_tr
        img.ScaleType = Enum.ScaleType.Stretch
        img.Parent = sg
        local info = TweenInfo.new(lc_dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        TweenService:Create(pt, info, {Size = Vector3.new(6.4, 0.01, 6.4)}):Play()
        TweenService:Create(img, info, {ImageTransparency = 1}):Play()
        task.delay(lc_dur + 0.2, function() pcall(function() pt:Destroy() end) end)
    end

    local function lc_bind()
        if lc_conn then pcall(function() lc_conn:Disconnect() end) lc_conn = nil end
        if not lc_on then return end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        local air = false
        lc_conn = hum.StateChanged:Connect(function(_, state)
            if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
                air = true
            elseif state == Enum.HumanoidStateType.Landed and air and lc_on then
                air = false
                local prm = RaycastParams.new()
                prm.FilterType = Enum.RaycastFilterType.Exclude
                prm.FilterDescendantsInstances = {char}
                prm.IgnoreWater = true
                local hit = Workspace:Raycast(root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -16, 0), prm)
                if hit then make_land(hit.Position, hit.Normal) end
            end
        end)
    end

    local lcTgl = ls:AddToggle("LV_LandCircle", {Title = "Landing Circle", Default = false})
    lcTgl:OnChanged(function(v)
        lc_on = v
        if v then lc_bind()
        elseif lc_conn then pcall(function() lc_conn:Disconnect() end) lc_conn = nil end
    end)
    ls:AddColorPicker("LV_LandCol", {Title = "Color", Default = Color3.new(1, 1, 1)})
        :OnChanged(function(c) lc_col = c end)
    ls:AddSlider("LV_LandTr", {Title = "Transparency", Min = 0, Max = 1, Default = 1, Rounding = 2})
        :OnChanged(function(v) lc_tr = v end)
    ls:AddSlider("LV_LandDur", {Title = "Duration", Min = 0.1, Max = 3, Default = 0.82, Rounding = 2})
        :OnChanged(function(v) lc_dur = v end)

    -- ---- MOVEMENT GRAPH ----
    local mg_on, mg_col = false, Color3.fromRGB(242, 242, 242)
    local mg_width, mg_height, mg_offset = 280, 72, 180
    local mg_lines, mg_shadows, mg_labels = {}, {}, {}
    local mg_current, mg_conn = nil, nil
    local mg_hist, mg_accum, mg_smooth = {}, 0, 0
    local mg_span, mg_step = 2.8, 1 / 45

    local function mg_speed()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return 0 end
        local v = r.AssemblyLinearVelocity
        return Vector3.new(v.X, 0, v.Z).Magnitude
    end

    local function mg_ref()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return math.max(1, (h and h.WalkSpeed) or 16)
    end

    local function mg_clear()
        if mg_conn then pcall(function() mg_conn:Disconnect() end) mg_conn = nil end
        if mg_current then pcall(function() mg_current:Remove() end) mg_current = nil end
        for i = 1, #mg_lines do
            pcall(function() mg_lines[i]:Remove() end)
            pcall(function() mg_shadows[i]:Remove() end)
        end
        for i = 1, #mg_labels do pcall(function() mg_labels[i]:Remove() end) end
        mg_lines, mg_shadows, mg_labels = {}, {}, {}
        mg_hist = {}
        mg_accum = 0
    end

    local function mg_y(v, center, height, ref)
        local n = math.clamp(v / ref - 1, -1, 1)
        return center - n * height * 0.44
    end

    local function mg_render(now)
        local cam = Workspace.CurrentCamera
        if not cam or #mg_hist < 2 then return end
        local vp = cam.ViewportSize
        local width = math.min(mg_width, math.max(120, vp.X - 48))
        local height = math.min(mg_height, math.max(36, vp.Y - 32))
        local left = math.floor(vp.X * 0.5 - width * 0.5)
        local center = math.clamp(math.floor(vp.Y * 0.5 + mg_offset), height * 0.5 + 8, vp.Y - height * 0.5 - 8)
        local ref = mg_ref()
        local start_t = now - mg_span
        local count = #mg_hist
        while #mg_lines < count + 1 do
            local s = Drawing.new("Line")
            s.Color = Color3.new(0, 0, 0)
            s.Thickness = 3
            s.Transparency = 0.4
            s.Visible = false
            mg_shadows[#mg_shadows + 1] = s
            local l = Drawing.new("Line")
            l.Color = mg_col
            l.Thickness = 1.5
            l.Transparency = 1
            l.Visible = false
            mg_lines[#mg_lines + 1] = l
        end
        for i = 1, count - 1 do
            local a, b = mg_hist[i], mg_hist[i + 1]
            local ap = math.clamp((a.t - start_t) / mg_span, 0, 1)
            local bp = math.clamp((b.t - start_t) / mg_span, 0, 1)
            local fade = math.clamp(math.min((ap + bp) * 6, (2 - ap - bp) * 5), 0, 1)
            local from = Vector2.new(left + ap * width, mg_y(a.v, center, height, ref))
            local to = Vector2.new(left + bp * width, mg_y(b.v, center, height, ref))
            local l, s = mg_lines[i], mg_shadows[i]
            l.From, l.To = from, to
            l.Transparency = fade
            l.Visible = fade > 0.02
            s.From, s.To = from, to
            s.Transparency = fade * 0.42
            s.Visible = fade > 0.02
        end
        for i = count, #mg_lines do
            mg_lines[i].Visible = false
            mg_shadows[i].Visible = false
        end
        if not mg_current then
            mg_current = Drawing.new("Text")
            mg_current.Center = false
            mg_current.Outline = true
            mg_current.Size = 12
            mg_current.ZIndex = 904
        end
        mg_current.Text = tostring(math.floor(mg_smooth + 0.5))
        mg_current.Position = Vector2.new(left + width + 5, center - 7)
        mg_current.Color = mg_col
        mg_current.Visible = true
    end

    local function mg_start()
        mg_clear()
        mg_smooth = mg_speed()
        local now = os.clock()
        local cnt = math.ceil(mg_span / mg_step)
        for i = 0, cnt do
            mg_hist[#mg_hist + 1] = {t = now - mg_span + i * mg_step, v = mg_smooth}
        end
        mg_conn = RunService.RenderStepped:Connect(function(dt)
            if not mg_on then return end
            local raw = mg_speed()
            mg_smooth = mg_smooth + (raw - mg_smooth) * (1 - math.exp(-dt * 18))
            mg_accum = mg_accum + dt
            local now = os.clock()
            if mg_accum >= mg_step then
                mg_accum = mg_accum % mg_step
                mg_hist[#mg_hist + 1] = {t = now, v = mg_smooth}
                local cutoff = now - mg_span
                while #mg_hist > 2 and mg_hist[2].t < cutoff do table.remove(mg_hist, 1) end
            end
            mg_render(now)
        end)
    end

    local mgTgl = ls:AddToggle("LV_MovGraph", {Title = "Movement Graph", Default = false})
    mgTgl:OnChanged(function(v)
        mg_on = v
        if v then mg_start() else mg_clear() end
    end)
    ls:AddColorPicker("LV_MovCol", {Title = "Graph Color", Default = Color3.fromRGB(242, 242, 242)})
        :OnChanged(function(c)
            mg_col = c
            for i = 1, #mg_lines do mg_lines[i].Color = c end
        end)
    ls:AddSlider("LV_MovW", {Title = "Width", Min = 180, Max = 420, Default = 280, Rounding = 0})
        :OnChanged(function(v) mg_width = v end)
    ls:AddSlider("LV_MovH", {Title = "Height", Min = 40, Max = 120, Default = 72, Rounding = 0})
        :OnChanged(function(v) mg_height = v end)
    ls:AddSlider("LV_MovY", {Title = "Y Offset", Min = -200, Max = 400, Default = 180, Rounding = 0})
        :OnChanged(function(v) mg_offset = v end)

    logInfo("Local visuals (China Hat, Backtrack, Landing, MovGraph) загружены")
end

-- ============================================================
-- SECTION O: SELF CHAMS + TOOL CHAMS
-- ============================================================
do
    local sc_sec = Tabs.Visual:AddSection({Name = "self_chams"})

    local sc_on, sc_type, sc_col = false, "ForceField", Color3.fromRGB(0, 200, 255)
    local sc_cache, sc_surfs = {}, {}
    local sc_conn

    local function sc_restore()
        for part, d in pairs(sc_cache) do
            if part and part.Parent then
                pcall(function() part.Material = d[1] end)
                pcall(function() part.Color = d[2] end)
            end
        end
        sc_cache = {}
        for sa, par in pairs(sc_surfs) do
            if sa and sa.Parent == nil then pcall(function() sa.Parent = par end) end
        end
        sc_surfs = {}
    end

    local function sc_apply()
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                if not sc_cache[p] then
                    sc_cache[p] = {p.Material, p.Color}
                end
                if sc_type == "ForceField" then
                    pcall(function() p.Material = Enum.Material.ForceField end)
                    pcall(function() p.Color = sc_col end)
                elseif sc_type == "Flat" then
                    pcall(function() p.Material = Enum.Material.SmoothPlastic end)
                    pcall(function() p.Color = sc_col end)
                elseif sc_type == "Chromatic" then
                    pcall(function() p.Material = Enum.Material.Foil end)
                    pcall(function() p.Color = sc_col end)
                end
            end
        end
    end

    local scTgl = sc_sec:AddToggle("SC_Enabled", {Title = "Self Chams", Default = false})
    scTgl:OnChanged(function(v)
        sc_on = v
        if v then
            if not sc_conn then
                sc_conn = RunService.Heartbeat:Connect(function()
                    if sc_on then sc_apply() end
                end)
            end
        else
            if sc_conn then pcall(function() sc_conn:Disconnect() end) sc_conn = nil end
            sc_restore()
        end
    end)
    sc_sec:AddDropdown("SC_Type", {Title = "Preset", Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"})
        :OnChanged(function(v) sc_type = v end)
    sc_sec:AddColorPicker("SC_Col", {Title = "Color", Default = Color3.fromRGB(0, 200, 255)})
        :OnChanged(function(c) sc_col = c end)

    -- Tool chams (то же самое, но для инструментов в руках)
    local tc_on, tc_type, tc_col = false, "ForceField", Color3.fromRGB(255, 200, 0)
    local tc_cache = {}
    local tc_conn

    local function tc_restore()
        for part, d in pairs(tc_cache) do
            if part and part.Parent then
                pcall(function() part.Material = d[1] end)
                pcall(function() part.Color = d[2] end)
            end
        end
        tc_cache = {}
    end

    local function tc_apply()
        local char = LocalPlayer.Character
        if not char then return end
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") then
                for _, p in ipairs(t:GetDescendants()) do
                    if p:IsA("BasePart") then
                        if not tc_cache[p] then tc_cache[p] = {p.Material, p.Color} end
                        if tc_type == "ForceField" then
                            pcall(function() p.Material = Enum.Material.ForceField end)
                            pcall(function() p.Color = tc_col end)
                        elseif tc_type == "Flat" then
                            pcall(function() p.Material = Enum.Material.SmoothPlastic end)
                            pcall(function() p.Color = tc_col end)
                        elseif tc_type == "Chromatic" then
                            pcall(function() p.Material = Enum.Material.Foil end)
                            pcall(function() p.Color = tc_col end)
                        end
                    end
                end
            end
        end
    end

    local tcTgl = sc_sec:AddToggle("TC_Enabled", {Title = "Tool Chams", Default = false})
    tcTgl:OnChanged(function(v)
        tc_on = v
        if v then
            if not tc_conn then
                tc_conn = RunService.Heartbeat:Connect(function()
                    if tc_on then tc_apply() end
                end)
            end
        else
            if tc_conn then pcall(function() tc_conn:Disconnect() end) tc_conn = nil end
            tc_restore()
        end
    end)
    sc_sec:AddDropdown("TC_Type", {Title = "Preset", Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"})
        :OnChanged(function(v) tc_type = v end)
    sc_sec:AddColorPicker("TC_Col", {Title = "Color", Default = Color3.fromRGB(255, 200, 0)})
        :OnChanged(function(c) tc_col = c end)

    logInfo("Self Chams + Tool Chams загружены")
end

-- ============================================================
-- SECTION P: UNLOAD HOOKS (для Part 2)
-- ============================================================
getgenv().ADDON_P2_UNLOAD = function()
    -- ESP
    local esp = _G.ESP_STATE
    if esp then esp.on = false end
    -- World aura
    pcall(function()
        local folder = Workspace:FindFirstChild("FH_ChamsFolder")
        if folder then folder:Destroy() end
        local land = Workspace:FindFirstChild("FH_Land")
        if land then land:Destroy() end
        local fx = Workspace:FindFirstChild("FH_WORLD_FX")
        if fx then fx:Destroy() end
        local mc = Workspace:FindFirstChild("FH_MurderClone")
        if mc then mc:Destroy() end
        local mfx = Workspace:FindFirstChild("FH_MurderFX")
        if mfx then mfx:Destroy() end
        local sky = Lighting:FindFirstChild("FH_CustomSky")
        if sky then sky:Destroy() end
        local bt = _G.FH_BT_CONN
        if bt then pcall(function() bt:Disconnect() end) _G.FH_BT_CONN = nil end
    end)
end

logInfo("==============================================")
logInfo("PART 2/3 УСПЕШНО ЗАГРУЖЕН")
logInfo("Фичи: ESP Engine, Tracer, World Aura, World FX, Shaders, Fog, Ambient, Exposure, Skybox")
logInfo("       Crosshair, Murder Effect, China Hat, Backtrack, Landing Circle, MovGraph, Chams")
logInfo("Ожидаю часть 3/3 для Tools + Sounds + Map Vote")
logInfo("==============================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "Part 2/3 загружено! Визуалы + Эффекты готовы", 6)
end)
-- ============================================================
-- SHITARO-ADDON v15.2 — PART 3/3
-- Tools + Sounds + Emotes + Animations + Map Vote + Values
-- Anti-Fling/Void/Trap/Coin/Fade + Fling Murder/Sheriff + Notify
-- ============================================================

if _G.SHITARO_ADDON_V152_P3_LOADED then
    logWarn("Addon v15.2 Part 3/3 уже загружен")
    return
end
_G.SHITARO_ADDON_V152_P3_LOADED = true

-- ============================================================
-- SECTION Q: TP TOOL + FLING TOOL
-- ============================================================
do
    local tools_sec = Tabs.Troll:AddSection({Name = "tools_v152"})

    local function my_hrp()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function tp_root(cf)
        if getgenv().SHITARO_TELEPORT and getgenv().SHITARO_TELEPORT(cf) then return end
        local hrp = my_hrp()
        if hrp then hrp.CFrame = cf end
    end

    -- ---- TP Tool ----
    local tp_on, tp_tool, tp_act_conn, tp_add_conn = false, nil, nil, nil

    local function give_tp_tool()
        if not tp_on then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("tp")
        if not existing and LocalPlayer.Character then existing = LocalPlayer.Character:FindFirstChild("tp") end
        if existing then tp_tool = existing return end
        if tp_act_conn then pcall(function() tp_act_conn:Disconnect() end) tp_act_conn = nil end
        tp_tool = Instance.new("Tool")
        tp_tool.Name = "tp"
        tp_tool.RequiresHandle = false
        tp_tool.CanBeDropped = false
        tp_tool.Parent = bp
        tp_act_conn = tp_tool.Activated:Connect(function()
            local root = my_hrp()
            local m = LocalPlayer:GetMouse()
            local pos = m.Hit
            if not root or not pos then return end
            tp_root(CFrame.new(pos.X, pos.Y + 3, pos.Z))
        end)
    end

    local function remove_tp_tool()
        if tp_act_conn then pcall(function() tp_act_conn:Disconnect() end) tp_act_conn = nil end
        if tp_tool then pcall(function() tp_tool:Destroy() end) tp_tool = nil end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t = bp:FindFirstChild("tp") if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("tp") if t then pcall(function() t:Destroy() end) end end
    end

    tools_sec:AddToggle("Tool_TP", {Title = "TP Tool", Default = false}):OnChanged(function(v)
        tp_on = v
        if v then
            give_tp_tool()
            if not tp_add_conn then
                tp_add_conn = LocalPlayer.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if tp_on then give_tp_tool() end
                end)
            end
        else
            if tp_add_conn then pcall(function() tp_add_conn:Disconnect() end) tp_add_conn = nil end
            remove_tp_tool()
        end
    end)

    -- ---- FLING TOOL ----
    local ft_on, ft_tool, ft_act_conn, ft_add_conn = false, nil, nil, nil
    local ft_bypass_vel = false
    local FLING_ACTIVE = 0

    local function clicked_player()
        local m = LocalPlayer:GetMouse()
        local target = m.Target
        if target then
            local node = target
            while node and node ~= Workspace do
                local p = Players:GetPlayerFromCharacter(node)
                if p and p ~= LocalPlayer then return p end
                node = node.Parent
            end
        end
        local cam = Workspace.CurrentCamera
        local mp = Vector2.new(m.X, m.Y)
        local best, bestd = nil, 110
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Head")
                if hrp then
                    local sp, on = cam:WorldToViewportPoint(hrp.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
                        if d < bestd then bestd = d best = p end
                    end
                end
            end
        end
        return best
    end

    local function do_fling(tp)
        if not tp or not tp.Character then return end
        local hrp = my_hrp()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hrp then return end
        local tc = tp.Character
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        local th = tc:FindFirstChildOfClass("Humanoid")
        if not thrp then return end
        FLING_ACTIVE = FLING_ACTIVE + 1
        getgenv().FLING_ACTIVE = FLING_ACTIVE
        if hrp.Velocity.Magnitude < 50 then _G.FH_OldPos = hrp.CFrame end
        if th and th.Sit then
            FLING_ACTIVE = math.max(0, FLING_ACTIVE - 1)
            getgenv().FLING_ACTIVE = FLING_ACTIVE
            return
        end
        local camera = Workspace.CurrentCamera
        local old_fdh = Workspace.FallenPartsDestroyHeight
        camera.CameraSubject = thrp
        pcall(function() Workspace.FallenPartsDestroyHeight = 0 / 0 end)
        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        local se = hum and hum:GetStateEnabled(Enum.HumanoidStateType.Seated)
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end
        local tm = tick()
        local ang = 0
        repeat
            if hrp and th then
                local tv
                if ft_bypass_vel then tv = th.MoveDirection * th.WalkSpeed
                else tv = thrp.Velocity end
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
        until tm + 2 < tick() or not ft_on
        if bv then bv:Destroy() end
        if hum and se ~= nil then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, se) end
        camera.CameraSubject = hum
        if _G.FH_OldPos and hrp then
            hrp.CFrame = _G.FH_OldPos * CFrame.new(0, 0.5, 0)
            if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end
            pcall(function() Workspace.FallenPartsDestroyHeight = old_fdh end)
        end
        FLING_ACTIVE = math.max(0, FLING_ACTIVE - 1)
        getgenv().FLING_ACTIVE = FLING_ACTIVE
    end

    getgenv().FH_DO_FLING = do_fling

    local function give_fling_tool()
        if not ft_on then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("fling")
        if not existing and LocalPlayer.Character then existing = LocalPlayer.Character:FindFirstChild("fling") end
        if existing then ft_tool = existing return end
        if ft_act_conn then pcall(function() ft_act_conn:Disconnect() end) ft_act_conn = nil end
        ft_tool = Instance.new("Tool")
        ft_tool.Name = "fling"
        ft_tool.RequiresHandle = false
        ft_tool.CanBeDropped = false
        ft_tool.Parent = bp
        ft_act_conn = ft_tool.Activated:Connect(function()
            local tp = clicked_player()
            if tp and my_hrp() then do_fling(tp) end
        end)
    end

    local function remove_fling_tool()
        if ft_act_conn then pcall(function() ft_act_conn:Disconnect() end) ft_act_conn = nil end
        if ft_tool then pcall(function() ft_tool:Destroy() end) ft_tool = nil end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t = bp:FindFirstChild("fling") if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("fling") if t then pcall(function() t:Destroy() end) end end
    end

    local ftt = tools_sec:AddToggle("Tool_Fling", {Title = "Fling Tool", Default = false})
    ftt:OnChanged(function(v)
        ft_on = v
        if v then
            give_fling_tool()
            if not ft_add_conn then
                ft_add_conn = LocalPlayer.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if ft_on then give_fling_tool() end
                end)
            end
        else
            if ft_add_conn then pcall(function() ft_add_conn:Disconnect() end) ft_add_conn = nil end
            remove_fling_tool()
        end
    end)
    tools_sec:AddToggle("Tool_FlingBypass", {Title = "Fling Bypass Velocity", Default = false})
        :OnChanged(function(v) ft_bypass_vel = v end)

    -- ---- FLING MURDER / SHERIFF (auto) ----
    local fm_on, fs_on, fling_thread = false, false, nil
    local fling_round_mod = nil

    local function role_player(role)
        if not fling_round_mod then
            local ok, m = pcall(function()
                return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
            end)
            if ok and type(m) == "table" then fling_round_mod = m end
        end
        local d = fling_round_mod and fling_round_mod.PlayerData
        if type(d) ~= "table" then return nil end
        for name, info in pairs(d) do
            if type(info) == "table" and not info.Dead
                and (info.Role == role or (role == "Sheriff" and info.Role == "Hero")) then
                local p = Players:FindFirstChild(name)
                if p and p ~= LocalPlayer then return p end
            end
        end
        return nil
    end

    local function start_fling_loop()
        if fling_thread then return end
        fling_thread = task.spawn(function()
            while fm_on or fs_on do
                local target = nil
                if fm_on then target = role_player("Murderer") end
                if not target and fs_on then target = role_player("Sheriff") end
                if target and target.Character and my_hrp() then
                    do_fling(target)
                else
                    task.wait(0.3)
                end
                task.wait()
            end
            fling_thread = nil
        end)
    end

    tools_sec:AddToggle("Tool_FlingMurder", {Title = "Auto-Fling Murder", Default = false})
        :OnChanged(function(v) fm_on = v if v then start_fling_loop() end end)
    tools_sec:AddToggle("Tool_FlingSheriff", {Title = "Auto-Fling Sheriff", Default = false})
        :OnChanged(function(v) fs_on = v if v then start_fling_loop() end end)

    -- ---- Teleport to Lobby / Map ----
    local function in_lobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby" or p.Name == "Lobby" then return true end
            p = p.Parent
        end
        return false
    end

    local function teleport_to_map()
        local root = my_hrp()
        if not root then return end
        local spawns = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if (obj:IsA("SpawnLocation") or (obj:IsA("BasePart") and obj.Name == "Spawn")) and not in_lobby(obj) then
                spawns[#spawns + 1] = obj
            end
        end
        if #spawns > 0 then
            local s = spawns[math.random(1, #spawns)]
            tp_root(s.CFrame + Vector3.new(0, 5, 0))
        end
    end

    local function teleport_to_lobby()
        local root = my_hrp()
        if not root then return end
        local lobby = Workspace:FindFirstChild("RegularLobby") or Workspace:FindFirstChild("Lobby")
        if not lobby then return end
        local locs = {}
        for _, obj in ipairs(lobby:GetDescendants()) do
            if obj:IsA("SpawnLocation") or (obj:IsA("BasePart") and obj.Name == "Spawn") then
                locs[#locs + 1] = obj
            end
        end
        if #locs > 0 then
            local s = locs[math.random(1, #locs)]
            tp_root(s.CFrame + Vector3.new(0, 3, 0))
        else
            local ok, pivot = pcall(function() return lobby:GetPivot() end)
            if ok then tp_root(pivot + Vector3.new(0, 5, 0)) end
        end
    end

    tools_sec:AddButton({Title = "TP to Lobby", Callback = teleport_to_lobby})
    tools_sec:AddButton({Title = "TP to Map", Callback = teleport_to_map})

    logInfo("Tools (TP, Fling, Fling Murder/Sheriff) загружены")
end

-- ============================================================
-- SECTION R: MOVEMENT v2 (Fly, Noclip, Bhop, Wallhop, Pixel Surf)
-- ============================================================
do
    local mv_sec = Tabs.Movement:AddSection({Name = "movement_v152"})

    -- ---- FLY v2 ----
    local fly_on, fly_speed = false, 60
    local fly_gravity = Workspace.Gravity
    local fly_up, fly_down = true, true
    local fly_up_kc, fly_down_kc = Enum.KeyCode.Space, Enum.KeyCode.LeftControl
    local jump_hold_t = 0

    UserInputService.JumpRequest:Connect(function()
        jump_hold_t = os.clock()
    end)

    local function get_controls()
        local ok, res = pcall(function()
            local ps = LocalPlayer:FindFirstChild("PlayerScripts")
            local pm = ps and ps:FindFirstChild("PlayerModule")
            if not pm then return nil end
            return require(pm):GetControls()
        end)
        return ok and res or nil
    end

    AddConn("Flyv2Step", RunService.RenderStepped:Connect(function()
        if not fly_on then return end
        local h = GetHRP()
        if not h then return end
        local cam = Workspace.CurrentCamera
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        local c = get_controls()
        if c then
            local ok, mv = pcall(function() return c:GetMoveVector() end)
            if ok and typeof(mv) == "Vector3" and mv.Magnitude > 0.05 then
                dir = dir + cam.CFrame.LookVector * (-mv.Z) + cam.CFrame.RightVector * mv.X
            end
        end
        local jump_held = (os.clock() - jump_hold_t) < 0.2
        if fly_up and (UserInputService:IsKeyDown(fly_up_kc) or jump_held) then dir = dir + Vector3.yAxis end
        if fly_down and UserInputService:IsKeyDown(fly_down_kc) then dir = dir - Vector3.yAxis end
        if dir.Magnitude > 0 then dir = dir.Unit * fly_speed end
        h.AssemblyLinearVelocity = dir
    end))

    local flyTgl = mv_sec:AddToggle("Fly_v2", {Title = "Fly v2", Default = false})
    flyTgl:OnChanged(function(v)
        fly_on = v
        if v then Workspace.Gravity = 0
        else
            Workspace.Gravity = fly_gravity
            local h = GetHRP()
            if h then h.AssemblyLinearVelocity = Vector3.zero end
        end
    end)
    mv_sec:AddSlider("Fly_v2_Speed", {Title = "Speed", Min = 10, Max = 300, Default = 60, Rounding = 0})
        :OnChanged(function(v) fly_speed = v end)
    mv_sec:AddToggle("Fly_v2_Up", {Title = "Up", Default = true}):OnChanged(function(v) fly_up = v end)
    mv_sec:AddToggle("Fly_v2_Down", {Title = "Down", Default = true}):OnChanged(function(v) fly_down = v end)
    mv_sec:AddKeybind("Fly_v2_UpKey", {Title = "Up Key", Default = "Space"})
        :OnChanged(function(k)
            local ok, kc = pcall(function() return Enum.KeyCode[k] end)
            if ok and kc then fly_up_kc = kc end
        end)
    mv_sec:AddKeybind("Fly_v2_DownKey", {Title = "Down Key", Default = "LeftControl"})
        :OnChanged(function(k)
            local ok, kc = pcall(function() return Enum.KeyCode[k] end)
            if ok and kc then fly_down_kc = kc end
        end)

    -- ---- BHOP + AUTO STRAFE ----
    local bhop_on, bhop_power, bhop_strafe, bhop_auto = false, 40, false, false
    local bhop_speed, bhop_was_jumping, bhop_is_boosting, bhop_last_yaw = 0, false, false, nil

    local function cam_yaw()
        local cam = Workspace.CurrentCamera
        if not cam then return nil end
        local look = cam.CFrame.LookVector
        return math.atan2(-look.X, -look.Z)
    end

    local function jump_is_held()
        if (os.clock() - jump_hold_t) < 0.2 then return true end
        return UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end

    AddConn("Bhopv2", RunService.Heartbeat:Connect(function()
        if not bhop_on then
            bhop_was_jumping, bhop_is_boosting, bhop_speed, bhop_last_yaw = false, false, 0, nil
            return
        end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local st = hum:GetState()
        local jumping = st == Enum.HumanoidStateType.Jumping
        local airborne = jumping or st == Enum.HumanoidStateType.Freefall

        if bhop_strafe or bhop_auto then
            bhop_speed = 0
            if jumping and not bhop_was_jumping then
                local dir = hum.MoveDirection
                if dir.Magnitude < 0.1 then dir = hrp.CFrame.LookVector end
                dir = Vector3.new(dir.X, 0, dir.Z)
                if dir.Magnitude > 0 then
                    dir = dir.Unit
                    local v = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * bhop_power, v.Y, dir.Z * bhop_power)
                    bhop_is_boosting = true
                end
            end
            if bhop_is_boosting and airborne then
                if bhop_auto then
                    local yaw = cam_yaw()
                    if yaw and bhop_last_yaw then
                        local delta = yaw - bhop_last_yaw
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
                    local tgt = dir * bhop_power
                    local nxz = cur:Lerp(tgt, 0.3)
                    hrp.AssemblyLinearVelocity = Vector3.new(nxz.X, v.Y, nxz.Z)
                elseif bhop_auto then
                    local v = hrp.AssemblyLinearVelocity
                    local xz = Vector3.new(v.X, 0, v.Z)
                    if xz.Magnitude > 0.1 and xz.Magnitude < bhop_power then
                        local kp = xz.Unit * bhop_power
                        hrp.AssemblyLinearVelocity = Vector3.new(kp.X, v.Y, kp.Z)
                    end
                end
            end
            if not airborne then bhop_is_boosting = false end
        else
            local base = math.max(hum.WalkSpeed, 1)
            local cap = math.max(bhop_power, base)
            local step = math.max(bhop_power * 0.1, 1)
            if bhop_speed < base then bhop_speed = base end
            if jumping and not bhop_was_jumping then
                bhop_speed = math.min(bhop_speed + step, cap)
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
                    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * bhop_speed, v.Y, dir.Z * bhop_speed)
                    bhop_is_boosting = true
                end
            end
            if airborne and bhop_is_boosting then
                local v = hrp.AssemblyLinearVelocity
                local xz = Vector3.new(v.X, 0, v.Z)
                local md = hum.MoveDirection
                local dir
                if md.Magnitude > 0.1 then dir = Vector3.new(md.X, 0, md.Z).Unit
                elseif xz.Magnitude > 0.1 then dir = xz.Unit end
                if dir then
                    local sp = math.max(xz.Magnitude, bhop_speed)
                    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * sp, v.Y, dir.Z * sp)
                end
            end
            if not airborne then
                bhop_is_boosting = false
                if jump_is_held() then hum.Jump = true else bhop_speed = 0 end
            end
        end
        bhop_last_yaw = cam_yaw()
        bhop_was_jumping = jumping
    end))

    local bhopTgl = mv_sec:AddToggle("Bhop_v2", {Title = "Bhop v2", Default = false})
    bhopTgl:OnChanged(function(v) bhop_on = v end)
    mv_sec:AddSlider("Bhop_v2_Power", {Title = "Power", Min = 10, Max = 150, Default = 40, Rounding = 0})
        :OnChanged(function(v) bhop_power = v end)
    mv_sec:AddToggle("Bhop_v2_Strafe", {Title = "Strafe", Default = false})
        :OnChanged(function(v) bhop_strafe = v end)
    mv_sec:AddToggle("Bhop_v2_AutoStrafe", {Title = "Auto Strafe", Default = false})
        :OnChanged(function(v) bhop_auto = v end)

    -- ---- WALLHOP ----
    local wallhop_on = false
    local hop_params = RaycastParams.new()
    hop_params.FilterType = Enum.RaycastFilterType.Exclude
    hop_params.IgnoreWater = true
    local hop_ang = {0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4, 2, -2, 2.6, -2.6, 3.14}
    local hop_scan_t = 0

    local function flat_unit(v)
        local f = Vector3.new(v.X, 0, v.Z)
        if f.Magnitude > 0 then return f.Unit end
        return Vector3.zero
    end

    UserInputService.JumpRequest:Connect(function()
        if not wallhop_on then return end
        if fly_on then return end
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        if hum.FloorMaterial ~= Enum.Material.Air then return end
        local now = os.clock()
        if now - hop_scan_t < 0.1 then return end
        hop_scan_t = now
        local cam = Workspace.CurrentCamera
        local base = flat_unit(hum.MoveDirection)
        if base == Vector3.zero then base = cam and flat_unit(cam.CFrame.LookVector) or Vector3.zero end
        if base == Vector3.zero then return end
        hop_params.FilterDescendantsInstances = {c}
        for i = 1, #hop_ang do
            local c1, s1 = math.cos(hop_ang[i]), math.sin(hop_ang[i])
            local dir = Vector3.new(base.X * c1 + base.Z * s1, 0, base.Z * c1 - base.X * s1) * 3
            local hit = Workspace:Raycast(hrp.Position, dir, hop_params)
            if not hit then hit = Workspace:Raycast(hrp.Position - Vector3.new(0, 2, 0), dir, hop_params) end
            if hit and math.abs(hit.Normal.Y) < 0.5 then
                local n = flat_unit(hit.Normal)
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(v.X + n.X * 3, v.Y, v.Z + n.Z * 3)
                break
            end
        end
    end)
    mv_sec:AddToggle("Wallhop_v2", {Title = "Wallhop", Default = false})
        :OnChanged(function(v) wallhop_on = v end)

    -- ---- PIXEL SURF (упрощённый порт) ----
    local surf_on, surf_speed = false, 34
    local surf_part, surf_conn = nil, nil
    local SURF_LEN, SURF_DEPTH, SURF_THICK = 11, 2.6, 1.6
    local surf_params = RaycastParams.new()
    surf_params.FilterType = Enum.RaycastFilterType.Exclude
    surf_params.IgnoreWater = true

    local function surf_platform()
        if not surf_part then
            local p = Instance.new("Part")
            p.Name = "FH_PixelStep"
            p.Anchored = true
            p.CanCollide = false
            p.CanQuery = false
            p.CanTouch = false
            p.Transparency = 1
            p.Material = Enum.Material.SmoothPlastic
            p.Size = Vector3.new(SURF_LEN, SURF_THICK, SURF_DEPTH)
            surf_part = p
        end
        if surf_part.Parent ~= Workspace then surf_part.Parent = Workspace end
        return surf_part
    end

    local function surf_hide()
        if surf_part and surf_part.Parent then surf_part.Parent = nil end
    end

    local function surf_step(_, dt)
        if not surf_on then return end
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then surf_hide() return end
        local cam = Workspace.CurrentCamera
        local move = flat_unit(hum.MoveDirection)
        local look = cam and flat_unit(cam.CFrame.LookVector) or Vector3.zero
        surf_params.FilterDescendantsInstances = {c, surf_part}
        local base = move.Magnitude > 0 and move or look
        local wall = nil
        for i = 1, #hop_ang do
            local c1, s1 = math.cos(hop_ang[i]), math.sin(hop_ang[i])
            local dir = Vector3.new(base.X * c1 + base.Z * s1, 0, base.Z * c1 - base.X * s1) * 5
            local hit = Workspace:Raycast(hrp.Position, dir, surf_params)
            if hit and math.abs(hit.Normal.Y) < 0.45 then wall = hit break end
        end
        if not wall then surf_hide() return end
        local n = flat_unit(wall.Normal)
        if n == Vector3.zero then return end
        local tangent = flat_unit(n:Cross(Vector3.yAxis))
        if tangent == Vector3.zero then return end
        local feet = hrp.Position.Y - hrp.Size.Y * 0.5 - hum.HipHeight
        local face = wall.Position
        local probe_pos = face + n * 0.5
        local probe = Workspace:Raycast(Vector3.new(probe_pos.X, feet + 3, probe_pos.Z),
            Vector3.new(0, -6, 0), surf_params)
        if not probe or probe.Normal.Y < 0.35 then surf_hide() return end
        local top = probe.Position.Y
        if top < feet - 3 or top > feet + 3 then surf_hide() return end
        local p = surf_platform()
        local center = Vector3.new(probe.Position.X, top - SURF_THICK * 0.5 - 0.02, probe.Position.Z) + n * (SURF_DEPTH * 0.5 - 0.45)
        p.CFrame = CFrame.lookAt(center, center - n)
        p.CanCollide = feet >= top - 0.06
        local along = move:Dot(tangent)
        local sign = along > 0.35 and 1 or (along < -0.35 and -1 or 1)
        local v = hrp.AssemblyLinearVelocity
        local err = top - feet
        local vy
        if err > 0.05 then vy = math.min(err * 14 + 1.5, 34)
        elseif err < -0.4 then vy = math.max(v.Y, err * 8)
        elseif v.Y > 0 then vy = v.Y
        else vy = err * 8 end
        local target_speed = surf_speed * sign
        local cur = v.X * tangent.X + v.Z * tangent.Z
        local blend = 1 - math.exp(-14 * (dt or 0.016))
        local sp = cur + (target_speed - cur) * blend
        local glide = tangent * sp
        hrp.AssemblyLinearVelocity = Vector3.new(glide.X, vy, glide.Z)
    end

    local surfTgl = mv_sec:AddToggle("Surf_v152", {Title = "Pixel Surf", Default = false})
    surfTgl:OnChanged(function(v)
        surf_on = v
        if v then
            if not surf_conn then surf_conn = RunService.Stepped:Connect(surf_step) end
        else
            surf_hide()
        end
    end)
    mv_sec:AddSlider("Surf_v152_Speed", {Title = "Surf Speed", Min = 8, Max = 90, Default = 34, Rounding = 0})
        :OnChanged(function(v) surf_speed = v end)

    logInfo("Movement v2 (Fly, Bhop, Wallhop, Pixel Surf) загружены")
end

-- ============================================================
-- SECTION S: ANTI-FLING / VOID / TRAP / COIN / FADE
-- ============================================================
do
    local anti_sec = Tabs.Utility:AddSection({Name = "anti_v152"})

    -- Anti-Fling: сбрасываем CanCollide других игроков + velocity
    local anti_fling_on = false
    local fling_cache, fling_reg = {}, {}
    local fling_safe_cf, fling_hold_until = nil, 0

    local function register_fling_model(model)
        if not anti_fling_on or not model then return end
        if fling_reg[model] or model == LocalPlayer.Character then return end
        fling_reg[model] = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                if fling_cache[d] == nil then fling_cache[d] = d.CanCollide end
                fling_reg[model][d] = true
                pcall(function() d.CanCollide = false end)
            end
        end
    end

    local function restore_fling()
        for _, model in pairs(fling_reg) do
            for part in pairs(model) do
                if part.Parent and fling_cache[part] ~= nil then
                    pcall(function() part.CanCollide = fling_cache[part] end)
                end
            end
        end
        fling_reg = {}
        fling_cache = {}
    end

    AddConn("AntiFling_v152", RunService.Stepped:Connect(function()
        if not anti_fling_on then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then register_fling_model(p.Character) end
        end
        for _, m in ipairs(Workspace:GetChildren()) do
            if m:IsA("Model") and m ~= LocalPlayer.Character and m:FindFirstChildOfClass("Humanoid") then
                register_fling_model(m)
            end
        end
        local hrp = GetHRP()
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            if v.Magnitude > 250 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end))

    anti_sec:AddToggle("Anti_Fling", {Title = "Anti-Fling", Default = false}):OnChanged(function(v)
        anti_fling_on = v
        if not v then restore_fling() end
        Notify(L("notify_title"), "Anti-Fling " .. (v and "ON" or "OFF"), 1.5)
    end)

    -- Anti-Void: сбрасываем FallenPartsDestroyHeight
    local anti_void_on = false
    local void_orig = Workspace.FallenPartsDestroyHeight
    AddConn("AntiVoid_v152", RunService.Heartbeat:Connect(function()
        if anti_void_on then
            pcall(function() Workspace.FallenPartsDestroyHeight = -9e9 end)
        else
            pcall(function() Workspace.FallenPartsDestroyHeight = void_orig end)
        end
    end))

    anti_sec:AddToggle("Anti_Void", {Title = "Anti-Void", Default = false})
        :OnChanged(function(v) anti_void_on = v end)

    -- Anti-Trap: игнор ловушек маньяка
    local anti_trap_on = false
    local trap_hit_conn = nil
    local trap_lock, trap_hold = 1, 5
    local trap_window, trap_busy = 0, false
    local trap_speed_cache, trap_jump_cache = 16, 50

    local function trap_hum()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    local function trap_kill_gui()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, child in ipairs(pg:GetChildren()) do
            if child.Name == "TrapGUI" then pcall(function() child:Destroy() end) end
        end
    end

    local function trap_unlock(hum)
        if not hum or not hum.Parent then return end
        pcall(function()
            if hum.WalkSpeed <= trap_lock then hum.WalkSpeed = trap_speed_cache end
            if hum.JumpPower <= trap_lock then hum.JumpPower = trap_jump_cache end
        end)
    end

    local function trap_engage()
        if not anti_trap_on then return end
        trap_window = os.clock() + trap_hold
        local hum = trap_hum()
        if hum then
            if hum.WalkSpeed > trap_lock then trap_speed_cache = hum.WalkSpeed end
            if hum.JumpPower > trap_lock then trap_jump_cache = hum.JumpPower end
        end
        trap_kill_gui()
        if trap_busy then return end
        trap_busy = true
        task.spawn(function()
            while anti_trap_on and os.clock() < trap_window do
                trap_unlock(trap_hum())
                trap_kill_gui()
                RunService.Heartbeat:Wait()
            end
            trap_busy = false
        end)
    end

    local function trap_attach()
        if trap_hit_conn then return end
        local ok, remote = pcall(function()
            local sys = ReplicatedStorage:FindFirstChild("TrapSystem")
            return sys and sys:FindFirstChild("TrapHitLocal")
        end)
        if not ok or not remote then return end
        trap_hit_conn = remote.OnClientEvent:Connect(function()
            task.spawn(trap_engage)
        end)
    end

    local function trap_detach()
        if trap_hit_conn then pcall(function() trap_hit_conn:Disconnect() end) trap_hit_conn = nil end
        trap_window = 0
        trap_unlock(trap_hum())
    end

    anti_sec:AddToggle("Anti_Trap", {Title = "Anti-Trap", Default = false}):OnChanged(function(v)
        anti_trap_on = v
        if v then trap_attach() else trap_detach() end
    end)

    -- Anti-Coin: удаляем монеты (анти-кик за переполнение)
    local anti_coin_on = false
    local coin_backup = nil
    local coin_conn, coin_desc = nil, nil

    local function wipe_coins()
        for _, v in ipairs(CollectionService:GetTagged("CoinVisual")) do
            pcall(function() v:Destroy() end)
        end
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d.Name == "CoinContainer" then
                pcall(function()
                    d.Archivable = true
                    coin_backup = {clone = d:Clone(), parent = d.Parent}
                    d:Destroy()
                end)
            end
        end
    end

    local function restore_coins()
        if coin_backup and coin_backup.clone then
            pcall(function() coin_backup.clone.Parent = coin_backup.parent or Workspace end)
            coin_backup = nil
        end
    end

    anti_sec:AddToggle("Anti_Coin", {Title = "Anti-Coin (remove coins)", Default = false}):OnChanged(function(v)
        anti_coin_on = v
        if v then
            wipe_coins()
            coin_conn = CollectionService:GetInstanceAddedSignal("CoinVisual"):Connect(function(c)
                if anti_coin_on then task.wait() if anti_coin_on then c:Destroy() end end
            end)
            coin_desc = Workspace.DescendantAdded:Connect(function(d)
                if anti_coin_on and d.Name == "CoinContainer" then
                    task.wait()
                    if anti_coin_on then pcall(function() d:Destroy() end) end
                end
            end)
        else
            if coin_conn then pcall(function() coin_conn:Disconnect() end) coin_conn = nil end
            if coin_desc then pcall(function() coin_desc:Disconnect() end) coin_desc = nil end
            restore_coins()
        end
    end)

    -- Anti-Fade: убираем чёрный экран смерти
    local anti_fade_on = false
    local fade_cache, fade_conns = {}, {}
    local fade_names = {CameraFade = true, SpawnFade = true, Fade = true, DeathFade = true}
    local fade_desc_conn = nil

    local function fade_hide(frame)
        if not frame or not frame.Parent or not frame:IsA("GuiObject") then return end
        if fade_cache[frame] == nil then fade_cache[frame] = frame.Visible end
        if frame.Visible then pcall(function() frame.Visible = false end) end
        if not fade_conns[frame] then
            fade_conns[frame] = frame:GetPropertyChangedSignal("Visible"):Connect(function()
                if anti_fade_on and frame.Visible then pcall(function() frame.Visible = false end) end
            end)
        end
    end

    local function fade_match(inst)
        if not inst:IsA("GuiObject") then return false end
        local par = inst.Parent
        if not par then return false end
        if (inst.Name == "Fade" or inst.Name == "Frame") and par:IsA("ScreenGui") and fade_names[par.Name] then return true end
        if inst.Name == "Fade" and par.Name == "Game" then return true end
        return false
    end

    local function fade_apply()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, child in ipairs(pg:GetChildren()) do
            if child:IsA("ScreenGui") and fade_names[child.Name] then
                for _, sub in ipairs(child:GetChildren()) do
                    if sub:IsA("GuiObject") and (sub.Name == "Fade" or sub.Name == "Frame") then
                        fade_hide(sub)
                    end
                end
            end
        end
        local main = pg:FindFirstChild("MainGUI")
        local gg = main and main:FindFirstChild("Game")
        local gf = gg and gg:FindFirstChild("Fade")
        if gf and gf:IsA("GuiObject") then fade_hide(gf) end
        if not fade_desc_conn then
            fade_desc_conn = pg.DescendantAdded:Connect(function(d)
                if anti_fade_on and fade_match(d) then
                    task.defer(function() if anti_fade_on and d.Parent then fade_hide(d) end end)
                end
            end)
        end
    end

    local function fade_restore()
        for _, c in pairs(fade_conns) do pcall(function() c:Disconnect() end) end
        fade_conns = {}
        for frame, v in pairs(fade_cache) do
            if frame and frame.Parent then
                pcall(function() frame.BackgroundTransparency = 1 frame.Visible = v end)
            end
        end
        fade_cache = {}
    end

    anti_sec:AddToggle("Anti_Fade", {Title = "Anti-Fade (no death black)", Default = false}):OnChanged(function(v)
        anti_fade_on = v
        if v then fade_apply() else fade_restore() end
    end)

    logInfo("Anti (Fling, Void, Trap, Coin, Fade) загружены")
end

-- ============================================================
-- SECTION T: NOTIFY (miss / kill murder / roles)
-- ============================================================
do
    local notify_sec = Tabs.Utility:AddSection({Name = "notify_v152"})

    local notify_on, miss_on, kill_on, roles_on = false, false, false, false
    local ICON_MISS = "clipboard"
    local ICON_KILL = "crosshair"
    local ICON_ROLE = "user"
    local last_role, gun_conn, hooked_gun = nil, nil, nil
    local cur_murderer_name, killed_flag = nil, false
    local last_miss = 0
    local notify_round_mod = nil

    local function get_data()
        if not notify_round_mod then
            local ok, m = pcall(function()
                return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
            end)
            if ok and type(m) == "table" then notify_round_mod = m end
        end
        return notify_round_mod and notify_round_mod.PlayerData
    end

    local function lp_has_gun()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Gun") then return true end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        return bp and bp:FindFirstChild("Gun") ~= nil
    end

    local function my_role()
        local d = get_data()
        local me = d and d[LocalPlayer.Name]
        local r = me and me.Role
        if r == "Sheriff" or r == "Hero" then return r end
        if lp_has_gun() then return "Hero" end
        return r
    end

    local function murderer_player()
        local d = get_data()
        if type(d) ~= "table" then return nil end
        for name, info in pairs(d) do
            if type(info) == "table" and info.Role == "Murderer" then
                return Players:FindFirstChild(name)
            end
        end
        return nil
    end

    local function push(text, icon)
        pcall(function()
            if Fluent and Fluent.Notify then
                Fluent:Notify({Title = text, Content = "", Duration = 4, Icon = icon})
            else
                Notify(L("notify_title"), text, 4)
            end
        end)
    end

    task.spawn(function()
        while task.wait(0.4) do
            if notify_on and roles_on then
                local r = my_role()
                if r and r ~= last_role then
                    last_role = r
                    push("Роль: " .. tostring(r), ICON_ROLE)
                elseif not r then
                    last_role = nil
                end
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            if notify_on then
                local mp = murderer_player()
                local name = mp and mp.Name
                if name ~= cur_murderer_name then
                    cur_murderer_name = name
                    killed_flag = false
                end
            end
        end
    end)

    local function on_shot()
        if not (notify_on and (miss_on or kill_on)) then return end
        local role = my_role()
        if role ~= "Sheriff" and role ~= "Hero" then return end
        local mp = murderer_player()
        if not mp then return end
        local mname = mp.Name
        task.delay(0.7, function()
            if not notify_on then return end
            local d = get_data()
            local info = d and d[mname]
            local target = Players:FindFirstChild(mname)
            local hum = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
            local killed = (info and info.Dead == true) or (hum and hum.Health <= 0)
            local alive = (info and info.Dead == false) or (hum and hum.Health > 0)
            if killed then
                if kill_on and not killed_flag then
                    killed_flag = true
                    push("Убит @" .. mname, ICON_KILL)
                end
            elseif alive then
                if miss_on and getgenv().SILENT_AIM_ACTIVE and os.clock() - last_miss > 1.5 then
                    last_miss = os.clock()
                    push("Промах по @" .. mname, ICON_MISS)
                end
            end
        end)
    end

    local function ensure_gun_hook()
        if gun_conn and hooked_gun then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if not ok or not remote then return end
        if gun_conn then pcall(function() gun_conn:Disconnect() end) gun_conn = nil end
        hooked_gun = remote
        gun_conn = remote.OnClientEvent:Connect(function(gun)
            local char = LocalPlayer.Character
            if typeof(gun) == "Instance" and char and gun:IsDescendantOf(char) then
                on_shot()
            end
        end)
    end

    task.spawn(function()
        while true do
            if notify_on and (miss_on or kill_on) then ensure_gun_hook() end
            task.wait(0.4)
        end
    end)

    local ntgl = notify_sec:AddToggle("NT_Enabled", {Title = "Notify", Default = false})
    ntgl:OnChanged(function(v)
        notify_on = v
        if v and (miss_on or kill_on) then task.spawn(ensure_gun_hook) end
    end)
    notify_sec:AddToggle("NT_Miss", {Title = "Miss", Default = false}):OnChanged(function(v)
        miss_on = v
        if v and notify_on then task.spawn(ensure_gun_hook) end
    end)
    notify_sec:AddToggle("NT_Kill", {Title = "Kill Murder", Default = false}):OnChanged(function(v)
        kill_on = v
        if v and notify_on then task.spawn(ensure_gun_hook) end
    end)
    notify_sec:AddToggle("NT_Roles", {Title = "Roles", Default = false}):OnChanged(function(v) roles_on = v end)

    logInfo("Notify (miss/kill/roles) загружены")
end

-- ============================================================
-- SECTION U: SOUNDS (kill sounds)
-- ============================================================
do
    local snd_sec = Tabs.Utility:AddSection({Name = "sounds_v152"})

    local snd_cfg = {
        sheriff = {on = false, name = "mc bow", volume = 1},
        murder = {on = false, name = "skeet", volume = 1},
    }

    local SND_REMOTE_LIST = {"primordial", "neverlose", "sparkle", "mc bow", "skeet", "break", "rust"}
    local SND_LOCAL_LIST = {"applepay", "bubble", "combobreak", "killcard", "xp", "na naxuy", "stony", "hentai"}
    local SND_FILES = {hentai = "hentai1"}
    local SND_CACHE_DIR = "shitaro_sounds/"
    local SND_USER_DIR = "sounds/"
    local SND_USER_EXTS = {[".ogg"] = true, [".mp3"] = true, [".wav"] = true}
    local SND_DIRS = {"shitaroebet/", "assets/", "khen_juju/assets/", "khen_juju/custom/", SND_USER_DIR, "", SND_CACHE_DIR}
    local SND_EXTS = {".ogg", ".mp3", ".wav", ""}
    local SND_BASE_URL = "https://github.com/khenn791/lmao/raw/refs/heads/main/"

    local SND_LIST = {}
    local snd_remote = {}
    for _, n in ipairs(SND_REMOTE_LIST) do SND_LIST[#SND_LIST + 1] = n snd_remote[n] = true end
    for _, n in ipairs(SND_LOCAL_LIST) do SND_LIST[#SND_LIST + 1] = n end
    local SND_BASE_COUNT = #SND_LIST

    local snd_user, snd_user_sig = {}, nil
    local snd_cache, snd_source, snd_fetched, snd_warned = {}, {}, {}, {}
    local snd_hooked, snd_pool, snd_tmp = {}, {}, {}
    local snd_alive = true
    local snd_last = {sheriff = 0, murder = 0}

    local function snd_fs_ready()
        return type(isfile) == "function" and type(readfile) == "function"
            and type(writefile) == "function" and type(getcustomasset) == "function"
    end

    local function snd_load_path(path)
        local ok_is, has = pcall(isfile, path)
        if not (ok_is and has) then return nil end
        local ok_rd, data = pcall(readfile, path)
        if not (ok_rd and type(data) == "string" and #data > 0) then return nil end
        local ext = string.match(path, "(%.[^%./\\]+)$")
        local suffix = ext and string.lower(ext) or ".ogg"
        if not SND_USER_EXTS[suffix] then suffix = ".ogg" end
        local tmp = "shitaro_snd_" .. tostring(math.random(100000, 999999)) .. suffix
        if not pcall(writefile, tmp, data) then return nil end
        local ok_as, asset = pcall(getcustomasset, tmp)
        if not (ok_as and type(asset) == "string" and asset ~= "") then
            pcall(function() if type(delfile) == "function" then delfile(tmp) end end)
            return nil
        end
        snd_tmp[#snd_tmp + 1] = tmp
        return asset
    end

    local function snd_scan(name)
        local direct = snd_user[name]
        if direct then
            local asset = snd_load_path(direct)
            if asset then return asset end
        end
        local file = SND_FILES[name] or name
        for _, dir in ipairs(SND_DIRS) do
            for _, ext in ipairs(SND_EXTS) do
                local asset = snd_load_path(dir .. file .. ext)
                if asset then return asset end
            end
        end
        return nil
    end

    local function snd_download(name)
        if snd_fetched[name] ~= nil then return snd_fetched[name] end
        if not snd_remote[name] then snd_fetched[name] = false return false end
        local path = SND_CACHE_DIR .. name .. ".ogg"
        local ok_is, has = pcall(isfile, path)
        if ok_is and has then snd_fetched[name] = true return true end
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
            snd_fetched[name] = false return false
        end
        pcall(function()
            if not isfolder(SND_CACHE_DIR) then makefolder(SND_CACHE_DIR) end
        end)
        local url = SND_BASE_URL .. (string.gsub(name, " ", "%%20")) .. ".ogg"
        local ok_dl, data = pcall(function() return game:HttpGet(url) end)
        if not ok_dl or type(data) ~= "string" or #data < 1024 then
            snd_fetched[name] = false return false
        end
        snd_fetched[name] = pcall(writefile, path, data) == true
        return snd_fetched[name]
    end

    local function snd_resolve(name)
        local cached = snd_cache[name]
        if cached ~= nil then
            if cached == false then return nil end
            return cached
        end
        if not snd_fs_ready() then snd_cache[name] = false return nil end
        local found = snd_scan(name)
        if not found and snd_download(name) then found = snd_scan(name) end
        snd_cache[name] = found or false
        if not found and not snd_warned[name] then
            snd_warned[name] = true
            pcall(function()
                if Fluent and Fluent.Notify then
                    Fluent:Notify({Title = "Sound file '" .. name .. "' not found", Duration = 5})
                end
            end)
        end
        return found
    end

    local SoundService = game:GetService("SoundService")

    local function snd_template(kind)
        local cfg = snd_cfg[kind]
        if not cfg then return nil end
        local id = snd_resolve(cfg.name)
        if not id then
            local old = snd_pool[kind]
            if old then pcall(function() old:Destroy() end) snd_pool[kind] = nil end
            return nil
        end
        local cur = snd_pool[kind]
        if cur and cur.Parent and cur.SoundId == id then
            pcall(function() cur.Volume = cfg.volume end)
            return cur
        end
        if cur then pcall(function() cur:Destroy() end) end
        local ok, s = pcall(function()
            local snd = Instance.new("Sound")
            snd.Name = "FH_KillSound_" .. kind
            snd.SoundId = id
            snd.Volume = cfg.volume
            snd.Looped = false
            snd.Parent = SoundService
            return snd
        end)
        if not ok or not s then snd_pool[kind] = nil return nil end
        snd_pool[kind] = s
        return s
    end

    local function snd_play(kind)
        local template = snd_pool[kind] or snd_template(kind)
        if not template then return false end
        return pcall(function()
            local c = template:Clone()
            c.Volume = snd_cfg[kind].volume
            c.Looped = false
            c.TimePosition = 0
            c.Parent = SoundService
            c:Play()
            task.delay(8, function() pcall(function() c:Destroy() end) end)
        end)
    end

    local function snd_should_mute(kind)
        local cfg = snd_cfg[kind]
        if not cfg or not cfg.on then return false end
        return snd_template(kind) ~= nil
    end

    local function snd_refresh()
        local mute = {sheriff = snd_should_mute("sheriff"), murder = snd_should_mute("murder")}
        for inst, entry in pairs(snd_hooked) do
            if inst.Parent then
                pcall(function()
                    inst.Volume = mute[entry.kind] and 0 or entry.vol
                end)
            end
        end
    end

    local function snd_hook(inst, kind)
        if snd_hooked[inst] then return end
        local entry = {kind = kind, vol = inst.Volume, conns = {}}
        snd_hooked[inst] = entry
        local function fire()
            if not snd_cfg[kind].on then return end
            if not snd_pool[kind] and not snd_template(kind) then return end
            if os.clock() - snd_last[kind] < 0.15 then return end
            snd_last[kind] = os.clock()
            pcall(function() inst:Stop() end)
            snd_play(kind)
        end
        entry.conns[#entry.conns + 1] = inst.Played:Connect(fire)
        entry.conns[#entry.conns + 1] = inst:GetPropertyChangedSignal("Playing"):Connect(function()
            if inst.Playing then fire() end
        end)
        entry.conns[#entry.conns + 1] = inst.Destroying:Connect(function() snd_hooked[inst] = nil end)
        pcall(function() inst.Volume = snd_should_mute(kind) and 0 or entry.vol end)
    end

    local function snd_tool_kind(tool)
        if tool:FindFirstChild("GunClient") or tool:FindFirstChild("Shoot") or tool.Name == "Gun" then
            return "sheriff"
        end
        if tool:FindFirstChild("KnifeClient") or tool:FindFirstChild("Events") or tool.Name == "Knife" then
            return "murder"
        end
        return nil
    end

    local snd_watch_conns = {}
    local snd_watched_char, snd_watched_bp = nil, nil

    local function snd_consider(inst)
        if not inst:IsA("Sound") then return end
        if inst.Name ~= "GunKill" and inst.Name ~= "Kill" then return end
        local handle = inst.Parent
        if not handle or handle.Name ~= "Handle" then return end
        local tool = handle.Parent
        if not tool or not tool:IsA("Tool") then return end
        local kind = snd_tool_kind(tool)
        if kind then snd_hook(inst, kind) end
    end

    local function snd_clear_watch()
        for i = #snd_watch_conns, 1, -1 do
            pcall(function() snd_watch_conns[i]:Disconnect() end)
            snd_watch_conns[i] = nil
        end
        snd_watched_char, snd_watched_bp = nil, nil
    end

    local function snd_watch()
        local char = LocalPlayer.Character
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if char == snd_watched_char and bp == snd_watched_bp then return end
        snd_clear_watch()
        snd_watched_char, snd_watched_bp = char, bp
        if char then snd_watch_conns[#snd_watch_conns + 1] = char.DescendantAdded:Connect(snd_consider) end
        if bp then snd_watch_conns[#snd_watch_conns + 1] = bp.DescendantAdded:Connect(snd_consider) end
    end

    local function snd_scan()
        snd_watch()
        for _, root in ipairs({LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack")}) do
            if root then
                for _, tool in ipairs(root:GetChildren()) do
                    if tool:IsA("Tool") then
                        local kind = snd_tool_kind(tool)
                        local handle = tool:FindFirstChild("Handle")
                        if kind and handle then
                            for _, child in ipairs(handle:GetChildren()) do
                                if child:IsA("Sound") and (child.Name == "GunKill" or child.Name == "Kill") then
                                    snd_hook(child, kind)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local function snd_apply(kind, v)
        snd_cfg[kind].on = v
        if v then
            pcall(snd_template, kind)
            pcall(snd_scan)
            pcall(snd_refresh)
        else
            pcall(snd_refresh)
        end
    end

    task.spawn(function()
        while snd_alive do
            task.wait(0.4)
            if snd_cfg.sheriff.on or snd_cfg.murder.on then
                pcall(snd_scan)
                pcall(snd_refresh)
            end
        end
    end)

    local sd = snd_sec:AddToggle("SND_Sheriff", {Title = "Sheriff Kill Sound", Default = false, Option = true})
    sd:OnChanged(function(v) snd_apply("sheriff", v) end)
    sd.Option:AddDropdown("SND_SheriffName", {Title = "Sound", Values = SND_LIST, Default = "mc bow"})
        :OnChanged(function(v)
            local name = type(v) == "table" and v[1] or v
            snd_cfg.sheriff.name = name
            if snd_cfg.sheriff.on then pcall(snd_template, "sheriff") end
        end)
    sd.Option:AddSlider("SND_SheriffVol", {Title = "Volume", Min = 0.1, Max = 5, Default = 1, Rounding = 1})
        :OnChanged(function(v)
            snd_cfg.sheriff.volume = v
            local s = snd_pool.sheriff
            if s then pcall(function() s.Volume = v end) end
        end)

    local md = snd_sec:AddToggle("SND_Murder", {Title = "Murder Kill Sound", Default = false, Option = true})
    md:OnChanged(function(v) snd_apply("murder", v) end)
    md.Option:AddDropdown("SND_MurderName", {Title = "Sound", Values = SND_LIST, Default = "skeet"})
        :OnChanged(function(v)
            local name = type(v) == "table" and v[1] or v
            snd_cfg.murder.name = name
            if snd_cfg.murder.on then pcall(snd_template, "murder") end
        end)
    md.Option:AddSlider("SND_MurderVol", {Title = "Volume", Min = 0.1, Max = 5, Default = 1, Rounding = 1})
        :OnChanged(function(v)
            snd_cfg.murder.volume = v
            local s = snd_pool.murder
            if s then pcall(function() s.Volume = v end) end
        end)

    logInfo("Sounds (kill sounds) загружены")
end

-- ============================================================
-- SECTION V: EMOTES
-- ============================================================
do
    local emote_page = Tabs.Troll:AddSection({Name = "emotes_v152"})

    local emoteFile = "emotes.json"
    local statEmotes = {{"Griddy", "129149402922241"}}
    local custEmotes, emoteMap, emoteList, animCache = {}, {}, {}, {}
    local allList, allMap = {}, {}
    local curTrack, selId, custRaw, alive = nil, nil, nil, true

    local function parseCustom()
        if not (isfile and isfile(emoteFile)) then
            if custRaw ~= nil then custRaw, custEmotes = nil, {} return true end
            return false
        end
        local ok, raw = pcall(readfile, emoteFile)
        if not ok or raw == custRaw then return false end
        custRaw, custEmotes = raw, {}
        local dok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if dok and type(data) == "table" then
            for k, v in pairs(data) do
                local name, id
                if type(v) == "table" then name, id = tostring(v.name or v[1] or k), tostring(v.id or v[2] or "")
                else name, id = tostring(k), tostring(v) end
                if name ~= "" and id ~= "" then
                    custEmotes[#custEmotes + 1] = {name, id}
                end
            end
        end
        return true
    end

    local function buildList()
        emoteMap, emoteList = {}, {}
        local function add(name, id)
            name = tostring(name)
            if emoteMap[name] then name = name .. " [" .. tostring(id) .. "]" end
            emoteMap[name] = tostring(id)
            emoteList[#emoteList + 1] = {name = name, id = tonumber((tostring(id):gsub("%D", ""))) or id}
        end
        for _, e in ipairs(statEmotes) do add(e[1], e[2]) end
        for _, e in ipairs(custEmotes) do add(e[1], e[2]) end
        for _, e in ipairs(allList) do add(e.name, e.id) end
    end

    parseCustom()
    buildList()

    local function getHum()
        local c = LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end

    local function stopEmote()
        if curTrack then pcall(function() curTrack:Stop() end) curTrack = nil end
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

    local el = emote_page:AddDropdown("EM_List", {Title = "Emote", Values = {"Griddy"}, Default = "Griddy"})
        :OnChanged(function(v)
            local name = type(v) == "table" and v[1] or v
            selId = emoteMap[name]
            if selId then playEmote(selId) else stopEmote() end
        end)
    emote_page:AddButton({Title = "Stop Emote", Callback = stopEmote})

    local function refresh()
        if parseCustom() then
            buildList()
            local names = {}
            for _, e in ipairs(emoteList) do names[#names + 1] = e.name end
            pcall(function() el:SetValues(names) el:Generate() end)
        end
    end

    local function fetchEmotes()
        local ok, res = pcall(function()
            local c = game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json")
            return c ~= "" and HttpService:JSONDecode(c) or nil
        end)
        if ok and type(res) == "table" then
            local list = res.data or res
            local seen = {}
            for _, item in pairs(list) do
                local id = tonumber(item.id)
                if id and id > 0 and not seen[id] then
                    seen[id] = true
                    local nm = tostring(item.name or ("Emote_" .. id))
                    if allMap[nm] then nm = nm .. " [" .. id .. "]" end
                    allMap[nm] = tostring(id)
                    allList[#allList + 1] = {name = nm, id = id}
                end
            end
        end
    end

    task.spawn(function()
        fetchEmotes()
        buildList()
        local names = {}
        for _, e in ipairs(emoteList) do names[#names + 1] = e.name end
        pcall(function() el:SetValues(names) el:Generate() end)
    end)

    logInfo("Emotes загружены (fetching в фоне)")
end

-- ============================================================
-- SECTION W: MAP VOTE (auto vote + dupe)
-- ============================================================
do
    local mv_sec = Tabs.Utility:AddSection({Name = "map_vote_v152"})

    local map_defs, map_rows, picked = {}, {}, {}
    local pads, pad_conns = {}, {}
    local root, lobby_conn, ws_conn = nil, nil, nil
    local hold_conn, tally_conn, spawn_conn = nil, nil, nil
    local vote_on, dupe_on, alive = false, false, true
    local dupe_cap, dupe_used = 3, 0
    local grid, spot, mark = nil, nil, 0
    local session, running, pending = 0, false, false
    local origin = nil

    local function learn(name, image)
        if type(name) ~= "string" or name == "" or name == "MAP NAME" then return false end
        if type(image) ~= "string" or image == "" then return false end
        if map_defs[name] then return false end
        map_defs[name] = image
        map_rows[#map_rows + 1] = {name = name, label = name, image = image}
        return true
    end

    local function sync_picked()
        if not grid then return end
        local v = grid:GetValue()
        table.clear(picked)
        if type(v) == "table" then
            for _, name in ipairs(v) do
                if type(name) == "string" and name ~= "" then picked[name] = true end
            end
        elseif type(v) == "string" and v ~= "" then picked[v] = true end
    end

    local function tally_of(entry)
        return tonumber(string.match(entry.tally.Text, "%d+")) or 0
    end

    local function ready(entry)
        local name = entry.title.Text
        return entry.info.Enabled and name ~= "" and name ~= "MAP NAME"
    end

    local function window_open()
        for i = 1, #pads do
            if pads[i].info.Enabled then return true end
        end
        return false
    end

    local function drop_conns()
        for _, c in ipairs({hold_conn, tally_conn, spawn_conn}) do
            if c then pcall(function() c:Disconnect() end) end
        end
        hold_conn, tally_conn, spawn_conn = nil, nil, nil
    end

    local function finish()
        drop_conns()
        running = false
        spot = nil
        dupe_used = 0
        origin = nil
    end

    local function stand_point(pad)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character, root}
        local hit = Workspace:Raycast(pad.Position + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), params)
        local y = hit and (hit.Position.Y + 3.2) or pad.Position.Y
        return Vector3.new(pad.Position.X, y, pad.Position.Z)
    end

    local function plant(point)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        hrp.CFrame = CFrame.new(point)
        return true
    end

    local function kill_self()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Dead)
            pcall(function() hum.Health = 0 end)
        elseif char then
            pcall(function() char:BreakJoints() end)
        end
    end

    local function choices()
        local out = {}
        for i = 1, #pads do
            local entry = pads[i]
            if ready(entry) and picked[entry.title.Text] then out[#out + 1] = entry end
        end
        return out
    end

    local function begin(id)
        local list = choices()
        if #list == 0 then finish() return end
        local entry = list[math.random(1, #list)]
        spot = stand_point(entry.pad)
        dupe_used = 0
        mark = tally_of(entry)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then finish() return end
        origin = hrp.CFrame
        if not plant(spot) then finish() return end

        if not dupe_on then
            task.delay(0.15, function()
                if session ~= id then return end
                local c2 = LocalPlayer.Character
                local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                if h2 then
                    local hum = c2:FindFirstChildWhichIsA("Humanoid")
                    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
                    h2.CFrame = origin
                    task.delay(0.05, function()
                        local c3 = LocalPlayer.Character
                        local h3 = c3 and c3:FindFirstChildWhichIsA("Humanoid")
                        if h3 then pcall(function() h3:ChangeState(Enum.HumanoidStateType.Running) end) end
                    end)
                end
                finish()
            end)
            return
        end

        hold_conn = RunService.Heartbeat:Connect(function()
            if not alive or session ~= id or not spot then return end
            local c2 = LocalPlayer.Character
            local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
            if not h2 then return end
            local flat = Vector3.new(h2.Position.X - spot.X, 0, h2.Position.Z - spot.Z)
            if flat.Magnitude > 2.5 then h2.CFrame = CFrame.new(spot) end
        end)

        tally_conn = entry.tally:GetPropertyChangedSignal("Text"):Connect(function()
            if session ~= id or not dupe_on or not entry.info.Enabled then return end
            local now = tally_of(entry)
            if now <= mark then mark = now return end
            mark = now
            if dupe_used >= dupe_cap then
                drop_conns()
                task.defer(function()
                    if session ~= id then return end
                    local c2 = LocalPlayer.Character
                    local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                    if h2 and origin then
                        local hum = c2:FindFirstChildWhichIsA("Humanoid")
                        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
                        h2.CFrame = origin
                    end
                    finish()
                end)
                return
            end
            dupe_used = dupe_used + 1
            kill_self()
        end)

        spawn_conn = LocalPlayer.CharacterAdded:Connect(function(char)
            if session ~= id or not dupe_on then return end
            local h2 = char:WaitForChild("HumanoidRootPart", 6)
            if not h2 or session ~= id or not entry.info.Enabled or not spot then return end
            if dupe_used >= dupe_cap then
                if origin then
                    local hum = char:FindFirstChildWhichIsA("Humanoid")
                    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
                    h2.CFrame = origin
                end
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
            table.sort(map_rows, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
            pcall(function() grid:SetData(map_rows) end)
            sync_picked()
        end
        if not window_open() then
            if running then finish() end
            return
        end
        if not vote_on or running then return end
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

    local function bind_vp(model_root)
        for _, c in ipairs(pad_conns) do pcall(function() c:Disconnect() end) end
        table.clear(pad_conns)
        table.clear(pads)
        root = model_root
        if not root then return end
        for _, model in ipairs(root:GetChildren()) do
            local entry = shape(model)
            if entry then
                pads[#pads + 1] = entry
                pad_conns[#pad_conns + 1] = entry.info:GetPropertyChangedSignal("Enabled"):Connect(schedule)
                pad_conns[#pad_conns + 1] = entry.title:GetPropertyChangedSignal("Text"):Connect(schedule)
                pad_conns[#pad_conns + 1] = entry.icon:GetPropertyChangedSignal("Image"):Connect(schedule)
            end
        end
        schedule()
    end

    local function watch_lobby(lobby)
        if lobby_conn then pcall(function() lobby_conn:Disconnect() end) lobby_conn = nil end
        if not lobby then bind_vp(nil) return end
        lobby_conn = lobby.ChildAdded:Connect(function(child)
            if child.Name == "VotePads" then task.defer(function() bind_vp(child) end) end
        end)
        bind_vp(lobby:FindFirstChild("VotePads"))
    end

    local auto = mv_sec:AddToggle("MV_Auto", {Title = "Auto Vote", Default = false, Option = true})
    auto:OnChanged(function(v)
        vote_on = v
        if v then schedule() else finish() end
    end)
    auto.Option:AddToggle("MV_Dupe", {Title = "Dupe (multi-vote)", Default = false})
        :OnChanged(function(v)
            dupe_on = v
            if not v then drop_conns() end
        end)
    auto.Option:AddSlider("MV_DupeCap", {Title = "Max Dupe", Min = 1, Max = 10, Default = 3, Rounding = 0})
        :OnChanged(function(v) dupe_cap = v end)

    grid = mv_sec:AddDropdown("MV_Maps", {Title = "Priority Maps", Values = {"(no maps yet)"}, Multi = true, Default = {}})
        :OnChanged(function() sync_picked() end)

    local function refresh_grid()
        local names = {}
        for _, r in ipairs(map_rows) do names[#names + 1] = r.name end
        if #names == 0 then names = {"(no maps yet)"} end
        pcall(function() grid:SetValues(names) grid:Generate() end)
    end

    task.spawn(function()
        watch_lobby(Workspace:FindFirstChild("SummerLobby") or Workspace:FindFirstChild("Lobby") or Workspace:FindFirstChild("RegularLobby"))
        ws_conn = Workspace.ChildAdded:Connect(function(child)
            if child.Name == "Lobby" or child.Name == "RegularLobby" or child.Name == "SummerLobby" then
                task.defer(function() watch_lobby(child) end)
            end
        end)
    end)

    -- обновляем дропдаун каждые 3 сек
    task.spawn(function()
        while alive do
            task.wait(3)
            if #map_rows > 0 then refresh_grid() end
        end
    end)

    logInfo("Map Vote загружен")
end

-- ============================================================
-- SECTION X: FINAL SETTINGS + UNLOAD + INIT
-- ============================================================
do
    local s = Tabs.Settings

    s:AddButton({Title = "Unload All (cleanup)", Callback = function()
        pcall(function()
            local hooks = {
                "ADDON_P2_UNLOAD",
            }
            for _, k in ipairs(hooks) do
                local f = getgenv()[k]
                if type(f) == "function" then pcall(f) end
            end
            -- Part 1 unload
            for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
            Connections = {}
            if TopHUDGui then pcall(function() TopHUDGui:Destroy() end) end
            if MobUI then pcall(function() MobUI:Destroy() end) end
            if ESPFolder then pcall(function() ESPFolder:Destroy() end) end
            if CoordGui then pcall(function() CoordGui:Destroy() end) end
            if BindPopupGui then pcall(function() BindPopupGui:Destroy() end) end
            if Window then pcall(function() Window:Destroy() end) end
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.Brightness = OriginalLighting.Brightness
            Camera.FieldOfView = OriginalLighting.FOV
        end)
        _G.SHITARO_ADDON_V151_LOADED = nil
        _G.SHITARO_ADDON_V152_P2_LOADED = nil
        _G.SHITARO_ADDON_V152_P3_LOADED = nil
    end})

    s:AddLabel("FortniHub v15.2 REBUILD EDITION", true)
    s:AddLabel("by HOTI x SHITARO", true)
end

-- ============================================================
-- ЗАПУСК: автоматически показываем HUD
-- ============================================================
task.spawn(function()
    task.wait(0.8)
    if TopHUDGui then TopHUDGui.Enabled = true end
    if Options and Options.ShowHUD then pcall(function() Options.ShowHUD:SetValue(true) end) end
end)

-- ============================================================
-- UNLOAD HOOK
-- ============================================================
getgenv().ADDON_P3_UNLOAD = function()
    _G.SHITARO_ADDON_V152_P3_LOADED = nil
    -- Sounds
    pcall(function()
        for _, s in pairs(_G.snd_pool or {}) do pcall(function() s:Destroy() end) end
    end)
end

logInfo("==============================================")
logInfo("PART 3/3 УСПЕШНО ЗАГРУЖЕН")
logInfo("Фичи: Tools (TP/Fling), Movement v2 (Fly/Bhop/Wallhop/Surf),")
logInfo("       Anti (Fling/Void/Trap/Coin/Fade), Notify, Sounds, Emotes, Map Vote")
logInfo("==============================================")
logInfo("FortniHub v15.2 REBUILD — ВСЁ ГОТОВО")
logInfo("Меню: P | Minimize: RightControl")
logInfo("==============================================")

task.spawn(function()
    task.wait(1.5)
    Notify("FortniHub", "v15.2 REBUILD полностью загружен! P - меню", 8)
end)
