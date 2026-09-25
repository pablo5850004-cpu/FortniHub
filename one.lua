-- ============================================================
-- FORTNIHUB v15.0.0 — MM2 FULL EXPLOIT HUB — by HOTI
-- 10 TABS version — register-limit safe
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
local TextChatService = game:GetService("TextChatService")
local VirtualUser = game:GetService("VirtualUser")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local THEME = Color3.fromRGB(138, 92, 246)
local THEME_LIGHT = Color3.fromRGB(178, 152, 255)
local THEME_OK = Color3.fromRGB(80, 240, 120)
local THEME_WARN = Color3.fromRGB(255, 200, 80)
local THEME_ERR = Color3.fromRGB(255, 80, 80)
local VERSION = "15.0.0"

pcall(function() if setfpscap then setfpscap(0) end end)

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
    quiet_shot_aim_mode="Режим аима",
    quiet_shot_aim_simple="Simple", quiet_shot_aim_advanced="Advanced",
    silent_aim="Silent Aim", silent_aim_mode="Режим Silent Aim",
    silent_aim_v1="v1 (FireServer)", silent_aim_v2="v2 (Hook)",
    auto_shoot="Авто-выстрел", auto_shoot_delay="Задержка (мс)",
    knife_silent="Silent Throw", knife_insta="Insta Kill",
    knife_radius="Радиус", knife_lead="Лид (%)",
    knife_air="Лифт (%)", knife_offset="Оффсет (мс)",
    kill_aura_v1="KillAura v1", kill_aura_v2="KillAura v2",
    kill_aura_version="Версия KillAura",
    autofarm_version="Версия автофарма", autofarm_v1="v1", autofarm_v2="v2 (Down)",
    farm_down_depth="Глубина Down",
    backtrack="Backtrack", backtrack_color="Цвет бэктрека",
    tracer="Bullet Tracer", tracer_color="Цвет трассера", tracer_duration="Длительность",
    sound_replacer="Звук убийства", sound_sheriff="Шериф", sound_murder="Маньяк",
    sound_volume="Громкость",
    anti_fling="Anti-Fling", anti_void="Anti-Void", anti_trap="Anti-Trap",
    tp_tool="TP Tool", fling_tool="Fling Tool", fling_bypass="Bypass Velocity",
    fake_pos="Fake Position", fake_pos_x="Разброс X", fake_pos_y="Разброс Y", fake_pos_z="Разброс Z",
    china_hat="China Hat", china_hat_color="Цвет China Hat",
    self_chams="Self Chams", self_chams_color="Цвет Self Chams",
    mov_graph="Movement Graph", mov_graph_color="Цвет графика",
    mov_graph_width="Ширина", mov_graph_height="Высота", mov_graph_y="Y",
    off_arrows="Стрелки к игрокам", off_arrows_size="Размер стрелок",
    off_arrows_dist="Дистанция стрелок",
    mat_chams="Material Chams", mat_chams_type="Тип Chams",
    crosshair="Кастомный прицел", crosshair_gap="Зазор", crosshair_len="Длина",
    crosshair_thick="Толщина", crosshair_color="Цвет", crosshair_outline="Обводка",
    crosshair_rotate="Вращение",
    shader="Шейдеры", shader_preset="Пресет шейдера",
    time_changer="Время суток", time_value="Время",
    custom_fog="Туман", fog_color="Цвет тумана", fog_start="Начало", fog_end="Конец",
    world_fx="Мир. эффекты", world_fx_type="Тип", world_fx_color="Цвет", world_fx_rate="Интенсивность",
    world_aura="Аура", world_aura_type="Тип ауры", world_aura_color="Цвет ауры",
    land_circle="Круг падения", land_circle_color="Цвет", land_circle_dur="Длительность",
    fling_mode="Режим", fling_target="Игрок", fling_range="Дальность", fling_on="Fling ON",
    fling_once="Fling раз", fling_none="Нет таргета",
}
local L_en = {}
for k in pairs(L_ru) do L_en[k] = k end
local CurrentLang = "ru"
if _G.FortniHubLang then CurrentLang = _G.FortniHubLang end
pcall(function()
    if isfile and isfile("FortniHubLang.txt") then
        local s = readfile("FortniHubLang.txt")
        if s=="ru" or s=="en" then CurrentLang=s; _G.FortniHubLang=s end
    end
end)
local function L(key)
    if CurrentLang=="ru" then return L_ru[key] or L_en[key] or key end
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
    if r=="murderer" then return Color3.fromRGB(255,60,60) end
    if r=="sheriff" then return Color3.fromRGB(60,140,255) end
    if r=="lobby" then return Color3.fromRGB(180,180,180) end
    return Color3.fromRGB(60,220,100)
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
            if t:match("^%d+%s*мин%s*%d+%s*сек$") then return t end
        end
    end
    return "--:--"
end

local function MakeDraggable(gui, cond)
    local d, ds, sp = false, nil, nil
    gui.InputBegan:Connect(function(i)
        if cond and not cond() then return end
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            d=true; ds=i.Position; sp=gui.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not d then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local delta = i.Position-ds
            gui.Position = UDim2.new(sp.X.Scale, sp.X.Offset+delta.X, sp.Y.Scale, sp.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then d=false end
    end)
end

local function GetContainers()
    local list = {CoreGui}
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h and h~=CoreGui then table.insert(list, h) end
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
                        local t = txt:lower():gsub("%s+","")
                        for _, kw in ipairs(keywords) do
                            local kk = kw:lower():gsub("%s+","")
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
-- CLEANUP old GUIs
-- ============================================================
do
    local MY = { FH_MobileUI=true, FH_TopHUDGui=true, FH_OpenScriptGui=true, FH_CoordGui=true, FortniHubLoadingGui=true, Fluent=true, FH_BindPopup=true }
    for _, parent in ipairs(GetContainers()) do
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name
                local kill = MY[n] or false
                if n=="ScreenGui" or n=="Fluent" then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("TextLabel") and string.find(tostring(d.Text or ""), "FortniHub") then kill=true; break end
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
    F.Size = UDim2.fromOffset(400,200); F.Position = UDim2.new(0.5,-200,0.5,-100)
    F.BackgroundColor3 = Color3.fromRGB(20,20,20); F.BorderSizePixel = 0; F.Parent = Lg
    Instance.new("UICorner", F).CornerRadius = UDim.new(0,10)
    local st = Instance.new("UIStroke", F); st.Color = THEME; st.Thickness = 2
    local T = Instance.new("TextLabel", F)
    T.Size = UDim2.new(1,0,0,30); T.Position = UDim2.new(0,0,0,25)
    T.BackgroundTransparency = 1; T.Font = Enum.Font.GothamBold
    T.Text = "FortniHub v"..VERSION; T.TextColor3 = Color3.new(1,1,1); T.TextSize = 22
    local T2 = Instance.new("TextLabel", F)
    T2.Size = UDim2.new(1,0,0,20); T2.Position = UDim2.new(0,0,0,52)
    T2.BackgroundTransparency = 1; T2.Font = Enum.Font.Gotham
    T2.Text = "by HOTI"; T2.TextColor3 = THEME_LIGHT; T2.TextSize = 14
    local T3 = Instance.new("TextLabel", F)
    T3.Size = UDim2.new(1,0,0,18); T3.Position = UDim2.new(0,0,0,76)
    T3.BackgroundTransparency = 1; T3.Font = Enum.Font.Gotham
    T3.Text = "Загрузка..."; T3.TextColor3 = Color3.fromRGB(180,180,200); T3.TextSize = 12
    local BG = Instance.new("Frame", F)
    BG.Size = UDim2.new(0.8,0,0,16); BG.Position = UDim2.new(0.1,0,0.72,0)
    BG.BackgroundColor3 = Color3.fromRGB(35,35,35); BG.BorderSizePixel = 0
    Instance.new("UICorner", BG).CornerRadius = UDim.new(0,8)
    local Bf = Instance.new("Frame", BG)
    Bf.Size = UDim2.new(0,0,1,0); Bf.BackgroundColor3 = THEME; Bf.BorderSizePixel = 0
    Instance.new("UICorner", Bf).CornerRadius = UDim.new(0,8)
    local t0 = os.clock()
    while os.clock()-t0 < 1.2 do
        local a = (os.clock()-t0)/1.2
        Bf.Size = UDim2.new(a,0,1,0)
        T3.Text = "Загрузка "..math.floor(a*100).."%"
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
        logWarn("HttpGet fail: "..tostring(name))
        return nil
    end
    local head = body:sub(1, 200):lower()
    if head:find("<!doctype") or head:find("<html") or head:find("not found") then
        logWarn("HTML/404: "..tostring(name))
        return nil
    end
    return body
end
local function safeLoadstring(body, name)
    if type(body) ~= "string" or #body == 0 then return nil end
    local fn, err = loadstring(body, "@"..tostring(name))
    if type(fn) ~= "function" then
        logWarn("Loadstring: "..tostring(name)..": "..tostring(err))
        return nil
    end
    return fn
end
local function safeRun(fn, name)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn)
    if not ok then
        logWarn("Run "..tostring(name)..": "..tostring(res))
        return nil
    end
    return res
end

-- ============================================================
-- TOUCH-FLING
-- ============================================================
do
    logInfo("Загружаю Touch-Fling...")
    local body = safeHttpGet("https://rawscripts.net/raw/Universal-Script-Touch-fling-script-22447", "TouchFling")
    local fn = body and safeLoadstring(body, "TouchFling")
    if fn then
        local res = safeRun(fn, "TouchFling")
        if res ~= nil then S.touchFling = true; logInfo("Touch-Fling загружен") end
    else
        logWarn("Touch-Fling недоступен — пропускаю")
    end
end

-- ============================================================
-- INVISIBLE
-- ============================================================
do
    logInfo("Загружаю Invisible...")
    local body = safeHttpGet("https://rawscripts.net/raw/Universal-Script-Invisible-script-20557", "Invisible")
    local fn = body and safeLoadstring(body, "Invisible")
    if fn then
        safeRun(fn, "Invisible")
        logInfo("Invisible загружен")
    else
        logWarn("Invisible недоступен — пропускаю")
    end
end
task.wait(0.5)

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
    if lastNotify[k] and (tick()-lastNotify[k]) < 0.6 then return end
    lastNotify[k] = tick()
    pcall(function()
        if Fluent and Fluent.Notify then
            Fluent:Notify({Title=t, Content=c, Duration=d or 3})
        end
    end)
end

-- ============================================================
-- HUD
-- ============================================================
do
    TopHUDGui = Instance.new("ScreenGui")
    TopHUDGui.Name = "FH_TopHUDGui"; TopHUDGui.ResetOnSpawn = false
    TopHUDGui.Enabled = false; TopHUDGui.Parent = CoreGui
    local F = Instance.new("Frame")
    F.Size = UDim2.fromOffset(520,38); F.Position = UDim2.new(0.5,-260,0,12)
    F.BackgroundColor3 = Color3.fromRGB(18,16,28); F.BackgroundTransparency = 0.05
    F.BorderSizePixel = 0; F.Active = true; F.Parent = TopHUDGui
    Instance.new("UICorner", F).CornerRadius = UDim.new(1,0)
    local st = Instance.new("UIStroke", F); st.Color = THEME; st.Thickness = 1.5; st.Transparency = 0.3
    MakeDraggable(F)
    local function mk(parent, sz, pos, txt, col, ts, font)
        local l = Instance.new("TextLabel", parent)
        l.Size = sz; l.Position = pos; l.BackgroundTransparency = 1
        l.Font = font or Enum.Font.GothamMedium; l.Text = txt; l.TextColor3 = col; l.TextSize = ts
        l.TextXAlignment = Enum.TextXAlignment.Center
        return l
    end
    mk(F, UDim2.fromOffset(60,38), UDim2.fromOffset(4,0), "FH", THEME, 18, Enum.Font.GothamBlack)
    FPSLabel = mk(F, UDim2.fromOffset(120,38), UDim2.fromOffset(64,0), "FPS 60", Color3.fromRGB(220,220,240), 13)
    PingLabel = mk(F, UDim2.fromOffset(110,38), UDim2.fromOffset(184,0), "PING 0ms", Color3.fromRGB(220,220,240), 13)
    RoundLabel = mk(F, UDim2.fromOffset(120,38), UDim2.fromOffset(294,0), L("round_time").." --:--", THEME_LIGHT, 13, Enum.Font.GothamBold)
    mk(F, UDim2.fromOffset(50,38), UDim2.fromOffset(464,0), "v"..VERSION, THEME_LIGHT, 11, Enum.Font.GothamBold)
end

-- ============================================================
-- COORD GUI
-- ============================================================
do
    CoordGui = Instance.new("ScreenGui")
    CoordGui.Name = "FH_CoordGui"; CoordGui.ResetOnSpawn = false
    CoordGui.Enabled = false; CoordGui.DisplayOrder = 100; CoordGui.Parent = CoreGui
    CoordLabel = Instance.new("TextLabel", CoordGui)
    CoordLabel.Size = UDim2.fromOffset(400,30); CoordLabel.Position = UDim2.new(1,-420,0,60)
    CoordLabel.BackgroundTransparency = 1; CoordLabel.Font = Enum.Font.GothamBold
    CoordLabel.Text = "X: 0 Y: 0 Z: 0"; CoordLabel.TextColor3 = Color3.fromRGB(0,255,100)
    CoordLabel.TextSize = 24; CoordLabel.TextXAlignment = Enum.TextXAlignment.Right
    CoordLabel.TextStrokeTransparency = 0; CoordLabel.TextStrokeColor3 = Color3.new(0,0,0)
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
    TouchFlyFrame.Size = UDim2.fromOffset(180,120); TouchFlyFrame.Position = UDim2.new(0.7,0,0.6,0)
    TouchFlyFrame.BackgroundTransparency = 0.6; TouchFlyFrame.BackgroundColor3 = Color3.new(0,0,0)
    TouchFlyFrame.Visible = false; TouchFlyFrame.Parent = MobUI
    local function mkFlyBtn(name, text, px, py, sx, sy)
        local b = Instance.new("TextButton")
        b.Name = name; b.Text = text; b.Size = UDim2.new(sx,0,sy,0); b.Position = UDim2.new(px,0,py,0)
        b.BackgroundColor3 = Color3.fromRGB(40,40,40); b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamBold; b.Parent = TouchFlyFrame
        b.MouseButton1Down:Connect(function() flyKeys[name]=true end)
        b.MouseButton1Up:Connect(function() flyKeys[name]=false end)
        b.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
                flyKeys[name]=false
            end
        end)
    end
    mkFlyBtn("W","W",0.35,0.05,0.3,0.28)
    mkFlyBtn("S","S",0.35,0.65,0.3,0.28)
    mkFlyBtn("A","A",0.02,0.35,0.3,0.28)
    mkFlyBtn("D","D",0.68,0.35,0.3,0.28)
    mkFlyBtn("UP","^",0.02,0.05,0.28,0.28)
    mkFlyBtn("DOWN","v",0.68,0.65,0.28,0.28)
    MakeDraggable(TouchFlyFrame)

    local ShootBtn = Instance.new("TextButton")
    ShootBtn.Name = "FH_ShootBtn"; ShootBtn.Size = UDim2.fromOffset(68,68)
    ShootBtn.Position = UDim2.new(1,-84,1,-160)
    ShootBtn.BackgroundColor3 = Color3.fromRGB(180,40,40); ShootBtn.BackgroundTransparency = 0.15
    ShootBtn.Text = L("shoot_btn"); ShootBtn.TextColor3 = Color3.new(1,1,1)
    ShootBtn.Font = Enum.Font.GothamBlack; ShootBtn.TextSize = 13
    ShootBtn.Active = true; ShootBtn.Visible = false; ShootBtn.Parent = MobUI
    Instance.new("UICorner", ShootBtn).CornerRadius = UDim.new(1,0)
    local st = Instance.new("UIStroke", ShootBtn); st.Color = THEME; st.Thickness = 2
    MakeDraggable(ShootBtn)
    ShootBtnRef = ShootBtn
end

-- ============================================================
-- OPEN BAR
-- ============================================================
local OpenScriptGui, OpenBar, OpenBtn
do
    OpenScriptGui = Instance.new("ScreenGui")
    OpenScriptGui.Name = "FH_OpenScriptGui"; OpenScriptGui.ResetOnSpawn = false
    OpenScriptGui.DisplayOrder = 999; OpenScriptGui.Parent = CoreGui
    OpenBar = Instance.new("Frame")
    OpenBar.Size = UDim2.fromOffset(260,46); OpenBar.Position = UDim2.new(0.5,-130,0,20)
    OpenBar.BackgroundColor3 = Color3.fromRGB(15,15,18); OpenBar.BorderSizePixel = 0; OpenBar.Parent = OpenScriptGui
    Instance.new("UICorner", OpenBar).CornerRadius = UDim.new(1,0)
    local ob = Instance.new("UIStroke", OpenBar); ob.Color = THEME; ob.Thickness = 2
    local MI = Instance.new("TextLabel", OpenBar)
    MI.Size = UDim2.fromOffset(40,46); MI.Position = UDim2.fromOffset(12,0)
    MI.BackgroundTransparency = 1; MI.Text = "="; MI.TextColor3 = THEME
    MI.TextSize = 26; MI.Font = Enum.Font.GothamBold
    local DV = Instance.new("Frame", OpenBar)
    DV.Size = UDim2.fromOffset(1,26); DV.Position = UDim2.new(0,55,0.5,-13)
    DV.BackgroundColor3 = Color3.fromRGB(90,90,90); DV.BorderSizePixel = 0
    local FI = Instance.new("TextLabel", OpenBar)
    FI.Size = UDim2.fromOffset(40,46); FI.Position = UDim2.fromOffset(62,0)
    FI.BackgroundTransparency = 1; FI.Text = "FH"; FI.TextColor3 = THEME
    FI.TextSize = 18; FI.Font = Enum.Font.GothamBlack
    OpenBtn = Instance.new("TextButton", OpenBar)
    OpenBtn.Size = UDim2.new(1,-115,1,0); OpenBtn.Position = UDim2.fromOffset(105,0)
    OpenBtn.BackgroundTransparency = 1; OpenBtn.Text = "Open Script"
    OpenBtn.TextColor3 = Color3.new(1,1,1); OpenBtn.TextSize = 17
    OpenBtn.Font = Enum.Font.GothamBold; OpenBtn.TextXAlignment = Enum.TextXAlignment.Left
    MakeDraggable(OpenBar)
end

-- ============================================================
-- CACHE GUNS / COINS
-- ============================================================
for _, v in ipairs(Workspace:GetDescendants()) do
    if v.Name=="GunDrop" then table.insert(Cache.guns, v) end
    if v.Name=="Coin_Server" or v.Name=="Coin" then table.insert(Cache.coins, v) end
end
AddConn("CacheAdd", Workspace.DescendantAdded:Connect(function(v)
    if v.Name=="GunDrop" then table.insert(Cache.guns, v) end
    if v.Name=="Coin_Server" or v.Name=="Coin" then table.insert(Cache.coins, v) end
end))
AddConn("CacheRem", Workspace.DescendantRemoving:Connect(function(v)
    if v.Name=="GunDrop" then local i=table.find(Cache.guns,v); if i then table.remove(Cache.guns,i) end end
    if v.Name=="Coin_Server" or v.Name=="Coin" then local i=table.find(Cache.coins,v); if i then table.remove(Cache.coins,i) end end
end))

-- ============================================================
-- CREATE TOUCH BUTTON
-- ============================================================
local CreateTouchButton
do
    CreateTouchButton = function(modName)
        if MobileButtons[modName] then return end
        if modName == "ShootBtn" then
            local btn = Instance.new("TextButton")
            btn.Name = "TouchBtn_ShootBtn"; btn.Size = UDim2.fromOffset(100,100)
            btn.Position = UDim2.new(1,-120,1,-200)
            btn.BackgroundColor3 = Color3.fromRGB(180,40,40); btn.BackgroundTransparency = 0.15
            btn.Text = "SHOOT"; btn.TextColor3 = Color3.new(1,1,1)
            btn.Font = Enum.Font.GothamBlack; btn.TextSize = 15; btn.Active = true; btn.Parent = MobUI
            Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
            local st = Instance.new("UIStroke", btn); st.Color = THEME; st.Thickness = 2.5
            MakeDraggable(btn, function() return not S.mobileLocked end)
            btn.MouseButton1Click:Connect(function() if DoQuietShot then DoQuietShot() end end)
            MobileButtons[modName] = btn
            return
        end
        local opt = Options[modName]; if not opt then return end
        local btn = Instance.new("TextButton")
        btn.Name = "TouchBtn_"..modName; btn.Size = UDim2.fromOffset(130,45)
        btn.Position = UDim2.new(0.5,-65+math.random(-30,30),0.5,-22+math.random(-30,30))
        btn.BackgroundColor3 = opt.Value and Color3.fromRGB(0,150,80) or Color3.fromRGB(30,30,30)
        btn.Text = modName; btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 13; btn.Active = true; btn.Parent = MobUI
        local st = Instance.new("UIStroke", btn); st.Color = THEME; st.Thickness = 2
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)
        MakeDraggable(btn, function() return not S.mobileLocked end)
        opt:OnChanged(function(v)
            if MobileButtons[modName] then
                btn.BackgroundColor3 = v and Color3.fromRGB(0,150,80) or Color3.fromRGB(30,30,30)
            end
        end)
        local tap = 0
        btn.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then tap=tick() end
        end)
        btn.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
                if tick()-tap > 0.6 then
                    if not S.mobileLocked then btn:Destroy(); MobileButtons[modName]=nil end
                else
                    if modName ~= "QuietShot" and Options[modName] then
                        Options[modName]:SetValue(not Options[modName].Value)
                    end
                end
            end
        end)
        MobileButtons[modName] = btn
    end
end

-- ============================================================
-- QUIET SHOT
-- ============================================================
local QuietAim = { tracks = {}, RING = 16, lastShot = 0 }
local function QuietGetTrack(p)
    local t = QuietAim.tracks[p]
    if not t then
        t = { samples={}, n=0, i=0, vel=Vector3.zero, ready=false, lastPos=nil, lastTime=0 }
        QuietAim.tracks[p] = t
    end
    return t
end
local function QuietPushSample(t, pos, now)
    t.i = t.i % QuietAim.RING + 1
    t.samples[t.i] = { t = now, p = pos }
    if t.n < QuietAim.RING then t.n = t.n + 1 end
end
local function QuietGetSample(t, k)
    local idx = (t.i - k - 1) % QuietAim.RING + 1
    local s = t.samples[idx]
    if not s then return nil, nil end
    return s.t, s.p
end
local function QuietFitVel(t)
    if t.n < 3 then return nil end
    local newestT = select(1, QuietGetSample(t, 0))
    if not newestT then return nil end
    local used, sumD = 0, 0
    for k = 0, t.n-1 do
        local st = select(1, QuietGetSample(t, k))
        if not st then break end
        local d = st - newestT
        if d < -0.25 then break end
        used = used+1; sumD = sumD + d
    end
    if used < 3 then return nil end
    local meanD = sumD/used
    local num, den = Vector3.zero, 0
    for k = 0, used-1 do
        local st, sp = QuietGetSample(t, k)
        if not st or not sp then break end
        local d = (st-newestT)-meanD
        num = num + sp*d
        den = den + d*d
    end
    if den < 1e-8 then return nil end
    return num/den
end
local function QuietUpdateTrack(p, now)
    if not p or not p.Character then return end
    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local t = QuietGetTrack(p)
    local pos = hrp.Position
    if t.lastPos then
        local d = (pos - t.lastPos).Magnitude
        if d > 0.005 then
            QuietPushSample(t, pos, now)
            local v = QuietFitVel(t)
            if v then t.vel = v; t.ready = true end
        end
    end
    t.lastPos = pos; t.lastTime = now
end
local function QuietSimple(sp)
    local my = GetHRP()
    if my then
        local flat = Vector3.new(sp.X, my.Position.Y, sp.Z)
        if (flat-my.Position).Magnitude > 0.1 then
            pcall(function() my.CFrame = CFrame.new(my.Position, flat) end)
        end
    end
    pcall(function() Camera.CFrame = CFrame.new(Camera.CFrame.Position, sp) end)
end
local function QuietAdvanced(target, thrp)
    local t = QuietAim.tracks[target]
    local my = GetHRP()
    if not my then return thrp.Position end
    local ping = 0
    pcall(function() ping = LocalPlayer:GetNetworkPing()*2 end)
    if ping <= 0 then ping = 0.05 end
    ping = math.clamp(ping, 0.02, 0.35)
    local age = 0
    if t and t.lastTime then age = math.clamp(os.clock()-t.lastTime, 0, 0.15) end
    local lead = ping + age
    local base = thrp.Position
    local vel = (t and t.ready and t.vel) or thrp.AssemblyLinearVelocity
    local velH = Vector3.new(vel.X, 0, vel.Z)
    local targetPos = base + velH * lead
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        local stt = hum:GetState()
        if (stt==Enum.HumanoidStateType.Jumping or stt==Enum.HumanoidStateType.Freefall) and math.abs(vel.Y) > 0.5 then
            local g = workspace.Gravity
            targetPos = Vector3.new(targetPos.X, base.Y + vel.Y*lead - 0.5*g*lead*lead, targetPos.Z)
        end
    end
    local origin = my.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local hit = workspace:Raycast(origin, targetPos-origin, params)
    if hit then
        local inst = hit.Instance
        local tc = target.Character
        if not (tc and (inst==tc or inst:IsDescendantOf(tc))) then
            targetPos = base + velH*lead
        end
    end
    local flat = Vector3.new(targetPos.X, my.Position.Y, targetPos.Z)
    if (flat-my.Position).Magnitude > 0.1 then
        pcall(function() my.CFrame = CFrame.new(my.Position, flat) end)
    end
    pcall(function() Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos) end)
    return targetPos
end
local DoQuietShot
do
    DoQuietShot = function()
        task.spawn(function()
            local now = os.clock()
            if now - QuietAim.lastShot < 0.08 then return end
            QuietAim.lastShot = now
            local char = LocalPlayer.Character; if not char then return end
            local gun = char:FindFirstChild("Gun")
            if not gun and LocalPlayer.Backpack then gun = LocalPlayer.Backpack:FindFirstChild("Gun") end
            if not gun then Notify(L("notify_title"), L("not_sheriff"), 2); return end
            if gun.Parent ~= char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(gun) end
                task.wait(0.05)
            end
            local target = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and GetRole(p)=="murderer" then target = p; break end
            end
            if not target then return end
            local thrp = GetHRP(target); if not thrp then return end
            local mode = _G.FH_QuietShotAimMode or "simple"
            local sp
            if mode == "advanced" then
                sp = QuietAdvanced(target, thrp)
            else
                sp = thrp.Position
                local predEn = Options.QuietShotPredict and Options.QuietShotPredict.Value
                local predStr = Options.QuietShotPredictVal and Options.QuietShotPredictVal.Value or 1
                if predEn and thrp.Velocity.Magnitude > 3 then
                    local my = GetHRP()
                    if my and thrp.Velocity.Y > -20 then
                        local velXZ = Vector3.new(thrp.Velocity.X, 0, thrp.Velocity.Z)
                        local dist = (thrp.Position-my.Position).Magnitude
                        sp = thrp.Position + velXZ * (dist/300) * predStr
                    end
                end
                QuietSimple(sp)
            end
            local shootRemote = ReplicatedStorage:FindFirstChild("ShootGun", true)
            if not shootRemote then
                for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                    if v:IsA("RemoteEvent") and string.find(v.Name, "Shoot") then shootRemote = v; break end
                end
            end
            if shootRemote then
                pcall(function() shootRemote:FireServer(sp) end)
                pcall(function() shootRemote:FireServer(sp, sp) end)
            end
            pcall(function() gun:Activate() end)
        end)
    end
end

AddConn("QuietTrack", RunService.Heartbeat:Connect(function()
    if not Options.QuietShot or not Options.QuietShot.Value then return end
    if (_G.FH_QuietShotAimMode or "simple") ~= "advanced" then return end
    local now = os.clock()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and GetRole(p)=="murderer" then QuietUpdateTrack(p, now) end
    end
end))

-- ============================================================
-- WINDOW
-- ============================================================
do
    local winOpts = {
        Title = "FortniHub MM2",
        SubTitle = "v"..VERSION.." by HOTI",
        TabWidth = 110,
        Size = UDim2.fromOffset(440,320),
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
    F.Size = UDim2.fromOffset(300,120); F.Position = UDim2.new(0.5,-150,0.4,-60)
    F.BackgroundColor3 = Color3.fromRGB(20,18,28); F.BorderSizePixel = 0; F.Active = true; F.Parent = BindPopupGui
    Instance.new("UICorner", F).CornerRadius = UDim.new(0,12)
    local st = Instance.new("UIStroke", F); st.Color = THEME; st.Thickness = 2
    MakeDraggable(F)
    local T = Instance.new("TextLabel", F)
    T.Size = UDim2.new(1,0,0,26); T.Position = UDim2.fromOffset(0,10)
    T.BackgroundTransparency = 1; T.Font = Enum.Font.GothamBold; T.TextSize = 15
    T.TextColor3 = THEME_LIGHT; T.Text = L("bind_popup_title")
    local M = Instance.new("TextLabel", F)
    M.Size = UDim2.new(1,0,0,22); M.Position = UDim2.fromOffset(0,38)
    M.BackgroundTransparency = 1; M.Font = Enum.Font.GothamBold; M.TextSize = 14
    M.TextColor3 = Color3.new(1,1,1); M.Text = ""
    local H = Instance.new("TextLabel", F)
    H.Size = UDim2.new(1,0,0,20); H.Position = UDim2.fromOffset(0,62)
    H.BackgroundTransparency = 1; H.Font = Enum.Font.Gotham; H.TextSize = 12
    H.TextColor3 = Color3.fromRGB(180,180,200); H.Text = L("bind_popup_hint")
    local C = Instance.new("TextButton", F)
    C.Size = UDim2.fromOffset(80,22); C.Position = UDim2.new(1,-88,1,-28)
    C.BackgroundColor3 = Color3.fromRGB(40,40,45); C.Text = L("bind_popup_close")
    C.TextColor3 = Color3.fromRGB(255,100,100); C.Font = Enum.Font.GothamBold; C.TextSize = 12
    Instance.new("UICorner", C).CornerRadius = UDim.new(0,6)

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
        if pk == keyName and (tick()-pt) < 2 then
            BindList[keyName] = nil
            BindKeyCache[modName] = nil
            BindTimeCache[modName] = nil
            Notify(L("notify_title"), L("bind_reset")..modName, 3)
        else
            if pk and pk~=keyName then BindList[pk] = nil end
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
            local kn = "Mouse"..input.UserInputType.Name:gsub("MouseButton","")
            TryApply(S.bindPopupTarget, kn)
            HideBindPopup()
        end
    end)
end

-- ============================================================
-- AWP MODEL
-- ============================================================
local AWP_SCALE = 1.0
local AWP_ROT = Vector3.new(90, 0, 0)
local COL = {
    BODY = Color3.fromRGB(58,74,42), BODY_D = Color3.fromRGB(40,52,30),
    METAL = Color3.fromRGB(28,28,30), METAL_L = Color3.fromRGB(48,48,50),
    METAL_D = Color3.fromRGB(15,15,16), RUB = Color3.fromRGB(15,15,15),
    GLASS = Color3.fromRGB(40,90,110), NEON = Color3.fromRGB(70,220,255),
}
local rad = math.rad
local PART_DEFS = {
    {"MuzzleBrake_Body", Vector3.new(0.14,0.085,0.085), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0,-1.48)*CFrame.Angles(0,rad(90),0)},
    {"MuzzleBrake_VentTop", Vector3.new(0.022,0.022,0.022), COL.METAL_D, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,0.034,-1.46)},
    {"MuzzleBrake_VentBottom", Vector3.new(0.022,0.022,0.022), COL.METAL_D, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,-0.034,-1.46)},
    {"MuzzleBrake_VentLeft", Vector3.new(0.022,0.022,0.022), COL.METAL_D, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(-0.034,0,-1.44)},
    {"MuzzleBrake_VentRight", Vector3.new(0.022,0.022,0.022), COL.METAL_D, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0.034,0,-1.44)},
    {"Barrel_Main", Vector3.new(0.80,0.05,0.05), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0,-1.03)*CFrame.Angles(0,rad(90),0)},
    {"Barrel_Flute1", Vector3.new(0.02,0.02,0.70), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(0.020,0,-1.03)},
    {"Barrel_Flute2", Vector3.new(0.02,0.02,0.70), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(-0.010,0.017,-1.03)},
    {"Barrel_Flute3", Vector3.new(0.02,0.02,0.70), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(-0.010,-0.017,-1.03)},
    {"Chamber_Transition", Vector3.new(0.18,0.08,0.08), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0,-0.56)*CFrame.Angles(0,rad(90),0)},
    {"Receiver_Body", Vector3.new(0.13,0.15,0.46), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,0,-0.26)},
    {"Receiver_ChamferL", Vector3.new(0.03,0.03,0.44), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(-0.06,0.065,-0.26)*CFrame.Angles(0,0,rad(45))},
    {"Receiver_ChamferR", Vector3.new(0.03,0.03,0.44), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0.06,0.065,-0.26)*CFrame.Angles(0,0,rad(-45))},
    {"Receiver_EjectionPort", Vector3.new(0.02,0.05,0.12), COL.METAL_D, Enum.Material.Metal, nil, CFrame.new(0.063,0.02,-0.20)},
    {"Receiver_Magwell", Vector3.new(0.09,0.10,0.12), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,-0.115,-0.34)},
    {"Receiver_RailRidge1", Vector3.new(0.10,0.02,0.03), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(0,0.08,-0.42)},
    {"Receiver_RailRidge2", Vector3.new(0.10,0.02,0.03), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(0,0.08,-0.32)},
    {"Receiver_RailRidge3", Vector3.new(0.10,0.02,0.03), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(0,0.08,-0.22)},
    {"Receiver_RailRidge4", Vector3.new(0.10,0.02,0.03), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(0,0.08,-0.12)},
    {"Receiver_ScrewTop1", Vector3.new(0.02,0.02,0.02), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0.06,0.05,-0.40)},
    {"Receiver_ScrewTop2", Vector3.new(0.02,0.02,0.02), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(-0.06,0.05,-0.15)},
    {"Bolt_Body", Vector3.new(0.14,0.05,0.05), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.09,-0.02)*CFrame.Angles(0,rad(90),0)},
    {"Bolt_HandleShaft", Vector3.new(0.10,0.02,0.02), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0.07,0.075,0.03)*CFrame.Angles(0,0,rad(-20))},
    {"Bolt_HandleKnob", Vector3.new(0.032,0.032,0.032), COL.METAL, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0.135,0.055,0.045)},
    {"TriggerGuard_Front", Vector3.new(0.02,0.09,0.02), COL.METAL, Enum.Material.Metal, nil, CFrame.new(0,-0.115,-0.01)},
    {"TriggerGuard_Bottom", Vector3.new(0.02,0.02,0.11), COL.METAL, Enum.Material.Metal, nil, CFrame.new(0,-0.155,0.045)},
    {"TriggerGuard_Rear", Vector3.new(0.02,0.09,0.02), COL.METAL, Enum.Material.Metal, nil, CFrame.new(0,-0.115,0.10)},
    {"Trigger", Vector3.new(0.02,0.04,0.02), COL.METAL_D, Enum.Material.Metal, nil, CFrame.new(0,-0.10,0.02)*CFrame.Angles(rad(10),0,0)},
    {"Mag_Body", Vector3.new(0.055,0.20,0.032), COL.METAL, Enum.Material.Metal, nil, CFrame.new(0,-0.26,-0.34)},
    {"Mag_Baseplate", Vector3.new(0.06,0.02,0.036), COL.METAL_D, Enum.Material.Metal, nil, CFrame.new(0,-0.365,-0.34)},
    {"Mag_RibFront", Vector3.new(0.02,0.18,0.02), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(0,-0.26,-0.356)},
    {"Mag_RibRear", Vector3.new(0.02,0.18,0.02), COL.METAL_L, Enum.Material.Metal, nil, CFrame.new(0,-0.26,-0.324)},
    {"Mag_ReleaseButton", Vector3.new(0.02,0.02,0.02), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0.063,-0.10,-0.34)},
    {"Mag_WitnessHole", Vector3.new(0.02,0.02,0.02), COL.METAL_D, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0.022,-0.20,-0.34)},
    {"Forend_Top", Vector3.new(0.13,0.02,0.89), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,0.055,-0.915)},
    {"Forend_Bottom", Vector3.new(0.13,0.02,0.89), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,-0.055,-0.915)},
    {"Forend_Left", Vector3.new(0.02,0.11,0.89), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(-0.055,0,-0.915)},
    {"Forend_Right", Vector3.new(0.02,0.11,0.89), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0.055,0,-0.915)},
    {"Forend_FrontCap", Vector3.new(0.02,0.14,0.14), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0,-1.355)*CFrame.Angles(0,rad(90),0)},
    {"Forend_MLOK_L1", Vector3.new(0.02,0.03,0.05), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(-0.062,0,-0.70)},
    {"Forend_MLOK_L2", Vector3.new(0.02,0.03,0.05), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(-0.062,0,-1.05)},
    {"Forend_MLOK_R1", Vector3.new(0.02,0.03,0.05), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(0.062,0,-0.70)},
    {"Forend_MLOK_R2", Vector3.new(0.02,0.03,0.05), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(0.062,0,-1.05)},
    {"Bipod_Mount", Vector3.new(0.05,0.03,0.06), COL.METAL, Enum.Material.Metal, nil, CFrame.new(0,-0.078,-1.20)},
    {"Bipod_Hinge", Vector3.new(0.03,0.022,0.022), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,-0.10,-1.20)},
    {"Bipod_LegL", Vector3.new(0.20,0.02,0.02), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(-0.05,-0.19,-1.15)*CFrame.Angles(rad(10),0,rad(110))},
    {"Bipod_LegL_Foot", Vector3.new(0.028,0.028,0.028), COL.RUB, Enum.Material.Rubber, Enum.PartType.Ball, CFrame.new(-0.12,-0.28,-1.08)},
    {"Bipod_LegR", Vector3.new(0.20,0.02,0.02), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0.05,-0.19,-1.15)*CFrame.Angles(rad(10),0,rad(70))},
    {"Bipod_LegR_Foot", Vector3.new(0.028,0.028,0.028), COL.RUB, Enum.Material.Rubber, Enum.PartType.Ball, CFrame.new(0.12,-0.28,-1.08)},
    {"Swivel_Front", Vector3.new(0.03,0.03,0.02), COL.METAL, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,-0.07,-1.05)},
    {"Swivel_Rear", Vector3.new(0.03,0.03,0.02), COL.METAL, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,-0.07,0.60)},
    {"Stock_Main", Vector3.new(0.11,0.14,0.75), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,0,0.325)},
    {"Stock_CheekRiser", Vector3.new(0.07,0.045,0.40), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,0.088,0.20)},
    {"Stock_CheekRiser_Screw", Vector3.new(0.02,0.02,0.02), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0.03,0.088,0.20)},
    {"Stock_ThumbPanel", Vector3.new(0.02,0.06,0.16), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(0.05,-0.01,0.40)},
    {"Stock_RibL", Vector3.new(0.02,0.02,0.22), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(-0.052,0,0.55)},
    {"Stock_RibR", Vector3.new(0.02,0.02,0.22), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(0.052,0,0.55)},
    {"Stock_Spacer", Vector3.new(0.10,0.13,0.05), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,0,0.705)},
    {"Stock_Buttpad", Vector3.new(0.11,0.15,0.06), COL.RUB, Enum.Material.Rubber, nil, CFrame.new(0,0,0.74)},
    {"Grip_Main", Vector3.new(0.075,0.17,0.06), COL.BODY, Enum.Material.SmoothPlastic, nil, CFrame.new(0,-0.15,0.06)*CFrame.Angles(rad(-14),0,0)},
    {"Grip_FingerGroove1", Vector3.new(0.06,0.02,0.02), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(0,-0.17,0.03)},
    {"Grip_FingerGroove2", Vector3.new(0.06,0.02,0.02), COL.BODY_D, Enum.Material.SmoothPlastic, nil, CFrame.new(0,-0.20,0.035)},
    {"Grip_TexturePanel", Vector3.new(0.02,0.10,0.045), COL.RUB, Enum.Material.Rubber, nil, CFrame.new(0.036,-0.15,0.065)},
    {"Scope_Tube", Vector3.new(0.55,0.045,0.045), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.20,-0.18)*CFrame.Angles(0,rad(90),0)},
    {"Scope_ObjectiveBell", Vector3.new(0.09,0.065,0.065), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.20,-0.49)*CFrame.Angles(0,rad(90),0)},
    {"Scope_ObjectiveLens", Vector3.new(0.02,0.058,0.058), COL.GLASS, Enum.Material.Glass, Enum.PartType.Cylinder, CFrame.new(0,0.20,-0.54)*CFrame.Angles(0,rad(90),0)},
    {"Scope_OcularBell", Vector3.new(0.08,0.055,0.055), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.20,0.13)*CFrame.Angles(0,rad(90),0)},
    {"Scope_OcularLens", Vector3.new(0.02,0.048,0.048), COL.GLASS, Enum.Material.Glass, Enum.PartType.Cylinder, CFrame.new(0,0.20,0.175)*CFrame.Angles(0,rad(90),0)},
    {"Scope_RingFront", Vector3.new(0.025,0.07,0.07), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.20,-0.30)*CFrame.Angles(0,rad(90),0)},
    {"Scope_RingRear", Vector3.new(0.025,0.07,0.07), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.20,-0.02)*CFrame.Angles(0,rad(90),0)},
    {"Scope_TurretElevation", Vector3.new(0.05,0.03,0.03), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.235,-0.10)*CFrame.Angles(0,0,rad(90))},
    {"Scope_TurretElevation_Cap", Vector3.new(0.034,0.034,0.034), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,0.262,-0.10)},
    {"Scope_TurretWindage", Vector3.new(0.045,0.028,0.028), COL.METAL, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0.04,0.20,-0.02)},
    {"Scope_TurretWindage_Cap", Vector3.new(0.032,0.032,0.032), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0.064,0.20,-0.02)},
    {"Scope_Sunshade", Vector3.new(0.03,0.075,0.075), COL.METAL_D, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.new(0,0.20,-0.555)*CFrame.Angles(0,rad(90),0)},
    {"Fastener_StockJunction", Vector3.new(0.02,0.02,0.02), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,0.05,-0.02)},
    {"Fastener_GripTop", Vector3.new(0.02,0.02,0.02), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,-0.07,0.06)},
    {"Fastener_ForendRear", Vector3.new(0.02,0.02,0.02), COL.METAL_L, Enum.Material.Metal, Enum.PartType.Ball, CFrame.new(0,0.05,-0.48)},
    {"Accent_TopStripe", Vector3.new(0.02,0.02,0.35), COL.NEON, Enum.Material.Neon, nil, CFrame.new(0,0.076,-0.10)},
    {"Accent_MagStripe", Vector3.new(0.02,0.16,0.02), COL.NEON, Enum.Material.Neon, nil, CFrame.new(0,-0.26,-0.358)},
}

local function clearAWP()
    for _, e in ipairs(S.awpEntries) do
        if e.part and e.part.Parent then pcall(function() e.part:Destroy() end) end
    end
    S.awpEntries = {}
end
local function buildAWP(handle)
    if not handle or handle:GetAttribute("FH_AWP") then return end
    S.awpHandleOrig = handle.Transparency
    handle.Transparency = 1
    local modelCF = CFrame.new(0,0,0)*CFrame.Angles(rad(AWP_ROT.X),rad(AWP_ROT.Y),rad(AWP_ROT.Z))
    local tool = handle.Parent
    if not tool then return end
    for _, d in ipairs(PART_DEFS) do
        local p = Instance.new("Part")
        p.Name = d[1]; p.Size = d[2]*AWP_SCALE; p.Color = d[3]
        p.Material = d[4]; if d[5] then p.Shape = d[5] end
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
        p.Massless = true; p.CastShadow = true
        p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
        local offsetCF = modelCF * CFrame.new(d[6].Position*AWP_SCALE) * (d[6]-d[6].Position)
        p.CFrame = handle.CFrame * offsetCF
        p.Parent = tool
        S.awpEntries[#S.awpEntries+1] = { part=p, handle=handle, offset=offsetCF }
    end
    handle:SetAttribute("FH_AWP", true)
end
local function restoreAWP(handle)
    if not handle or not handle:GetAttribute("FH_AWP") then return end
    if S.awpHandleOrig ~= nil then
        pcall(function() handle.Transparency = S.awpHandleOrig end)
    end
    clearAWP()
    handle:SetAttribute("FH_AWP", false)
end
AddConn("AWPRender", RunService.RenderStepped:Connect(function()
    if #S.awpEntries == 0 then return end
    if not Options.AWPReplace or not Options.AWPReplace.Value then
        clearAWP(); return
    end
    for i = #S.awpEntries, 1, -1 do
        local e = S.awpEntries[i]
        if not e.part or not e.part.Parent or not e.handle or not e.handle.Parent then
            if e.part and e.part.Parent then pcall(function() e.part:Destroy() end) end
            table.remove(S.awpEntries, i)
        else
            e.part.CFrame = e.handle.CFrame * e.offset
        end
    end
end))
AddConn("AWPDetect", RunService.Heartbeat:Connect(function()
    if not Options.AWPReplace or not Options.AWPReplace.Value then
        if #S.awpEntries > 0 then clearAWP() end
        return
    end
    local char = LocalPlayer.Character
    if char then
        local gun = char:FindFirstChild("Gun")
        if gun then
            local h = gun:FindFirstChild("Handle")
            if h and not h:GetAttribute("FH_AWP") then buildAWP(h) end
        end
    end
    local bp = LocalPlayer.Backpack
    if bp then
        local gun = bp:FindFirstChild("Gun")
        if gun then
            local h = gun:FindFirstChild("Handle")
            if h and not h:GetAttribute("FH_AWP") then buildAWP(h) end
        end
    end
end))

-- ============================================================
-- CREATE ALL MODULES (10 TABS)
-- ============================================================
local function CreateAllModules()
    -- === 10 TABS ===
    local tC = Window:AddTab({Title=L("tab_combat")})
    local tM = Window:AddTab({Title=L("tab_movement")})
    local tF = Window:AddTab({Title=L("tab_farm")})
    local tV = Window:AddTab({Title=L("tab_visual")})
    local tE = Window:AddTab({Title=L("tab_effects")})
    local tTr = Window:AddTab({Title=L("tab_troll")})       -- сюда TP и Fling
    local tU = Window:AddTab({Title=L("tab_utility")})
    local tMo = Window:AddTab({Title=L("tab_mobile")})
    local tK = Window:AddTab({Title=L("tab_binds")})
    local tS = Window:AddTab({Title=L("tab_settings")})

    Tabs.Combat=tC; Tabs.Movement=tM; Tabs.AutoFarm=tF; Tabs.Visual=tV
    Tabs.Effects=tE; Tabs.Troll=tTr; Tabs.Utility=tU
    Tabs.Mobile=tMo; Tabs.Keybinds=tK; Tabs.Settings=tS

    local function NT(name, state)
        if Options.NotifyToggles and Options.NotifyToggles.Value then
            Notify(L("notify_title"), name.." "..(state and "ON" or "OFF"), 1.5)
        end
    end
    local function Reg(mn, t) ModuleNameToTitle[mn] = t end

    -- ============ COMBAT ============
    Reg("QuietShot",L("quiet_shot")); Reg("QuietShotPredict",L("quiet_shot_predict"))
    Reg("QuietShotPredictVal",L("quiet_shot_predict_val")); Reg("KillAura",L("kill_aura"))
    Reg("KillAuraRadius",L("radius")); Reg("AutoGrabGun",L("auto_grab_gun"))

    tC:AddToggle("QuietShot",{Title=L("quiet_shot"),Default=false}):OnChanged(function(v) NT(L("quiet_shot"),v) end)
    tC:AddToggle("QuietShotPredict",{Title=L("quiet_shot_predict"),Default=true})
    tC:AddSlider("QuietShotPredictVal",{Title=L("quiet_shot_predict_val"),Min=0,Max=5,Default=1,Rounding=1})
    tC:AddDropdown("QuietShotAimMode",{Title=L("quiet_shot_aim_mode"),Values={L("quiet_shot_aim_simple"),L("quiet_shot_aim_advanced")},Default=L("quiet_shot_aim_simple")}):OnChanged(function(v)
        _G.FH_QuietShotAimMode = (v==L("quiet_shot_aim_advanced")) and "advanced" or "simple"
    end)
    tC:AddKeybind("QuietShotBind",{Title=L("quiet_shot_bind"),Default="E",Callback=function(v)
        local k = Enum.KeyCode.E; pcall(function() k = Enum.KeyCode[v] end); S.quietShotBind = k
    end})
    tC:AddToggle("KillAura",{Title=L("kill_aura"),Default=false}):OnChanged(function(v) NT(L("kill_aura"),v) end)
    tC:AddSlider("KillAuraRadius",{Title=L("radius"),Min=5,Max=100,Default=25,Rounding=0})
    tC:AddToggle("AutoGrabGun",{Title=L("auto_grab_gun"),Default=false}):OnChanged(function(v)
        NT(L("auto_grab_gun"),v); if v then S.grabFailed=false end
    end)
    tC:AddButton({Title=L("kill_sheriff"),Callback=function()
        if GetRole(LocalPlayer)~="murderer" then Notify(L("notify_title"),L("not_murderer"),2); return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and GetRole(p)=="sheriff" then
                task.spawn(function()
                    local char = LocalPlayer.Character; local tChar = p.Character
                    if not char or not tChar then return end
                    local my = char:FindFirstChild("HumanoidRootPart"); local th = tChar:FindFirstChild("HumanoidRootPart")
                    local knife = char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
                    if not (my and th and knife) then return end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and knife.Parent~=char then hum:EquipTool(knife); task.wait(0.05) end
                    local orig = my.CFrame
                    my.CFrame = th.CFrame*CFrame.new(0,0,1.5); task.wait(0.1)
                    pcall(function() VirtualUser:ClickButton1(Vector2.new(0,0)) end)
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
    tC:AddButton({Title=L("suicide"),Callback=function()
        local c = LocalPlayer.Character
        if c then local h = c:FindFirstChild("Humanoid"); if h then h.Health = 0 end end
    end})

    -- ============ MOVEMENT ============
    Reg("SpeedToggle",L("speed_hack")); Reg("SpeedValue",L("walk_speed"))
    Reg("FlyToggle",L("fly")); Reg("FlySpeed",L("fly_speed"))
    Reg("SpeedGlitch",L("speed_glitch")); Reg("GlitchSpeed",L("glitch_speed"))
    Reg("BunnyHop",L("bunny_hop")); Reg("BunnyMaxSpeed",L("max_speed")); Reg("BunnyAccelTime",L("accel_time"))
    Reg("Noclip",L("noclip")); Reg("Spinbot",L("spinbot")); Reg("SpinbotSpeed",L("spin_speed"))
    Reg("InfJump",L("inf_jump")); Reg("JumpPowerVal",L("jump_power")); Reg("JumpPowerToggle",L("jump_power_custom"))
    Reg("WallBounce",L("wall_bounce")); Reg("WallBounceForce",L("wall_force"))
    Reg("FreezeToggle",L("freeze")); Reg("FreezeSpeed",L("freeze_speed"))

    tM:AddToggle("SpeedToggle",{Title=L("speed_hack"),Default=false}):OnChanged(function(v) NT(L("speed_hack"),v) end)
    tM:AddSlider("SpeedValue",{Title=L("walk_speed"),Min=16,Max=500,Default=32,Rounding=0})
    tM:AddToggle("FlyToggle",{Title=L("fly"),Default=false}):OnChanged(function(v)
        NT(L("fly"),v)
        TouchFlyFrame.Visible = v and UserInputService.TouchEnabled
        local hum = GetHum(); if hum then hum.PlatformStand = v end
    end)
    tM:AddSlider("FlySpeed",{Title=L("fly_speed"),Min=20,Max=500,Default=60,Rounding=0})
    tM:AddToggle("SpeedGlitch",{Title=L("speed_glitch"),Default=false}):OnChanged(function(v)
        NT(L("speed_glitch"),v); S.sgActive = false
        if not v then local h=GetHum(); if h then h.WalkSpeed=16 end end
    end)
    tM:AddSlider("GlitchSpeed",{Title=L("glitch_speed"),Min=40,Max=500,Default=120,Rounding=0})
    tM:AddToggle("BunnyHop",{Title=L("bunny_hop"),Default=false}):OnChanged(function(v)
        NT(L("bunny_hop"),v); if not v then local h=GetHum(); if h then h.WalkSpeed=16 end end
    end)
    tM:AddSlider("BunnyMaxSpeed",{Title=L("max_speed"),Min=60,Max=500,Default=250,Rounding=0})
    tM:AddSlider("BunnyAccelTime",{Title=L("accel_time"),Min=1,Max=30,Default=10,Rounding=0})
    tM:AddToggle("Noclip",{Title=L("noclip"),Default=false}):OnChanged(function(v) NT(L("noclip"),v) end)
    tM:AddToggle("Spinbot",{Title=L("spinbot"),Default=false}):OnChanged(function(v) NT(L("spinbot"),v) end)
    tM:AddSlider("SpinbotSpeed",{Title=L("spin_speed"),Min=1,Max=50,Default=8,Rounding=0})
    tM:AddToggle("InfJump",{Title=L("inf_jump"),Default=false}):OnChanged(function(v) NT(L("inf_jump"),v) end)
    tM:AddSlider("JumpPowerVal",{Title=L("jump_power"),Min=50,Max=500,Default=100,Rounding=0})
    tM:AddToggle("JumpPowerToggle",{Title=L("jump_power_custom"),Default=false}):OnChanged(function(v)
        NT(L("jump_power_custom"),v); S.customJumpPower = v
        local hum = GetHum()
        if hum then
            hum.UseJumpPower = true
            if v then hum.JumpPower = Options.JumpPowerVal and Options.JumpPowerVal.Value or 100
            else hum.JumpPower = 50 end
        end
    end)
    tM:AddToggle("WallBounce",{Title=L("wall_bounce"),Default=false}):OnChanged(function(v)
        NT(L("wall_bounce"),v); S.wallBounce = v
    end)
    tM:AddSlider("WallBounceForce",{Title=L("wall_force"),Min=50,Max=500,Default=150,Rounding=0})
    tM:AddToggle("FreezeToggle",{Title=L("freeze"),Default=false}):OnChanged(function(v)
        S.isFrozen = v
        if not v then
            local hrp = GetHRP()
            if hrp then local bv = hrp:FindFirstChild("FH_FreezeBV"); if bv then bv:Destroy() end end
        end
        Notify(L("notify_title"), v and L("freeze_on") or L("freeze_off"), 2)
    end)
    tM:AddSlider("FreezeSpeed",{Title=L("freeze_speed"),Min=20,Max=300,Default=60,Rounding=0})

    -- ============ AUTOFARM ============
    Reg("AutoFarmCoins",L("autofarm")); Reg("AutoFarmSpeed",L("farm_speed"))
    Reg("AvoidMurderer",L("avoid_murderer")); Reg("AutoKillAuraAt40",L("auto_kill_aura")); Reg("AutoCollect",L("autocollect"))

    tF:AddDropdown("AutoFarmVersion",{Title=L("autofarm_version"),Values={L("autofarm_v1"),L("autofarm_v2")},Default=L("autofarm_v1")}):OnChanged(function(v)
        S.farmV2 = (v==L("autofarm_v2"))
    end)
    tF:AddSlider("FarmDownDepth",{Title=L("farm_down_depth"),Min=5,Max=40,Default=14,Rounding=0}):OnChanged(function(v) S.farmDownDepth=v end)
    tF:AddToggle("AutoFarmCoins",{Title=L("autofarm"),Default=false}):OnChanged(function(v)
        NT(L("autofarm"),v)
        if v then
            for _,n in ipairs({"KillAura","AutoGrabGun","QuietShot","SpeedToggle","SpeedGlitch","BunnyHop","Spinbot","FlyToggle","Noclip","InfJump","FreezeToggle"}) do
                if Options[n] then S.farmBlocked[n] = Options[n].Value; if Options[n].Value then Options[n]:SetValue(false) end end
            end
            S.farmLastCoinTime = tick()
        else
            for n,was in pairs(S.farmBlocked) do if Options[n] and was then Options[n]:SetValue(true) end end
            S.farmBlocked = {}
        end
    end)
    tF:AddSlider("AutoFarmSpeed",{Title=L("farm_speed"),Min=1,Max=60,Default=8,Rounding=1})
    tF:AddToggle("AvoidMurderer",{Title=L("avoid_murderer"),Default=false}):OnChanged(function(v)
        S.farmAvoidMurderer = v; NT(L("avoid_murderer"),v)
    end)
    tF:AddToggle("AutoKillAuraAt40",{Title=L("auto_kill_aura"),Default=false}):OnChanged(function(v)
        S.farmAutoKill = v; NT(L("auto_kill_aura"),v)
    end)
    tF:AddToggle("AutoCollect",{Title=L("autocollect"),Default=false}):OnChanged(function(v) NT(L("autocollect"),v) end)

    -- ============ VISUAL ============
    Reg("PlayerESP",L("player_esp")); Reg("NameESP",L("name_esp")); Reg("DistESP",L("dist_esp"))
    Reg("GunESP",L("gun_esp")); Reg("CoinESP",L("coin_esp")); Reg("Fullbright",L("fullbright"))
    Reg("FOVEnabled",L("fov")); Reg("FOVValue",L("fov")); Reg("StretchEnabled",L("stretch")); Reg("StretchValue",L("stretch"))
    Reg("FPSCap",L("fps_cap")); Reg("AWPReplace",L("awp_replace"))

    tV:AddToggle("PlayerESP",{Title=L("player_esp"),Default=false}):OnChanged(function(v) NT(L("player_esp"),v) end)
    tV:AddToggle("NameESP",{Title=L("name_esp"),Default=false})
    tV:AddToggle("DistESP",{Title=L("dist_esp"),Default=false})
    tV:AddToggle("GunESP",{Title=L("gun_esp"),Default=false})
    tV:AddToggle("CoinESP",{Title=L("coin_esp"),Default=false})
    tV:AddToggle("Fullbright",{Title=L("fullbright"),Default=false}):OnChanged(function(v)
        NT(L("fullbright"),v)
        if v then Lighting.Ambient = Color3.fromRGB(255,255,255); Lighting.Brightness = 2
        else Lighting.Ambient = OriginalLighting.Ambient; Lighting.Brightness = OriginalLighting.Brightness end
    end)
    tV:AddToggle("FOVEnabled",{Title=L("fov"),Default=false}):OnChanged(function(v)
        NT(L("fov"),v); if not v then Camera.FieldOfView = OriginalLighting.FOV end
    end)
    tV:AddSlider("FOVValue",{Title=L("fov"),Min=30,Max=140,Default=70,Rounding=0})
    tV:AddToggle("StretchEnabled",{Title=L("stretch"),Default=false}):OnChanged(function(v)
        NT(L("stretch"),v)
        if not v then
            pcall(function() Camera:SetAspectRatio(1) end)
            if sethiddenproperty then pcall(function() sethiddenproperty(Camera,"AspectRatio",1) end) end
        else
            local val = (Options.StretchValue and Options.StretchValue.Value or 15)/10
            pcall(function() Camera:SetAspectRatio(val) end)
        end
    end)
    tV:AddSlider("StretchValue",{Title=L("stretch"),Min=5,Max=40,Default=15,Rounding=1})
    tV:AddSlider("FPSCap",{Title=L("fps_cap"),Min=0,Max=9999,Default=0,Rounding=0}):OnChanged(function(v)
        S.fpsCap = v; pcall(function() if setfpscap then setfpscap(v) end end)
    end)
    tV:AddToggle("AWPReplace",{Title=L("awp_replace"),Default=false}):OnChanged(function(v)
        NT(L("awp_replace"),v)
        if not v then
            local function fh(c) if not c then return nil end local g=c:FindFirstChild("Gun"); if g then return g:FindFirstChild("Handle") end return nil end
            restoreAWP(fh(LocalPlayer.Character)); restoreAWP(fh(LocalPlayer.Backpack))
        end
    end)

    -- ============ TROLL (с TP и Fling) ============
    Reg("SpamChat",L("spam_chat")); Reg("TrollEgor",L("troll_egor")); Reg("TrollLag",L("troll_lag"))
    Reg("TPPlayerSelect",L("tp_player")); Reg("FlingToggle","Fling")

    tTr:AddInput("ChatInput",{Title=L("spam_message"),Default="FortniHub v"..VERSION})
    tTr:AddToggle("SpamChat",{Title=L("spam_chat"),Default=false})
    tTr:AddToggle("TrollEgor",{Title=L("troll_egor"),Default=false}):OnChanged(function(v) NT(L("troll_egor"),v) end)
    tTr:AddToggle("TrollLag",{Title=L("troll_lag"),Default=false}):OnChanged(function(v) NT(L("troll_lag"),v) end)

    -- Teleport подсекция
    local function TPTo(pos) local hrp = GetHRP(); if hrp then hrp.CFrame = CFrame.new(pos) end end
    tTr:AddButton({Title=L("tp_lobby"),Callback=function() TPTo(Vector3.new(110,138,-12)) end})
    tTr:AddButton({Title=L("tp_map"),Callback=function()
        for _,mn in ipairs({"Map","CurrentMap","Normal"}) do
            local m = Workspace:FindFirstChild(mn)
            if m then
                local sp = m:FindFirstChildWhichIsA("SpawnLocation",true)
                if sp then TPTo(sp.Position+Vector3.new(0,3,0)); return end
                local sp2 = m:FindFirstChild("Spawn",true) or m:FindFirstChild("SpawnPoint",true)
                if sp2 and sp2:IsA("BasePart") then TPTo(sp2.Position+Vector3.new(0,5,0)); return end
            end
        end
    end})
    tTr:AddButton({Title=L("tp_murderer"),Callback=function()
        for _,p in ipairs(Players:GetPlayers()) do
            if GetRole(p)=="murderer" then local hrp = GetHRP(p); if hrp then TPTo(hrp.Position+Vector3.new(0,3,0)); break end end
        end
    end})
    tTr:AddButton({Title=L("tp_sheriff"),Callback=function()
        for _,p in ipairs(Players:GetPlayers()) do
            if GetRole(p)=="sheriff" then local hrp = GetHRP(p); if hrp then TPTo(hrp.Position+Vector3.new(0,3,0)); break end end
        end
    end})
    local tpV = {}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then table.insert(tpV, p.Name) end end
    tTr:AddDropdown("TPPlayerSelect",{Title=L("tp_player"),Values=tpV,Default=tpV[1] or ""})
    tTr:AddButton({Title=L("go"),Callback=function()
        local n = Options.TPPlayerSelect and Options.TPPlayerSelect.Value
        if not n then return end
        local t = Players:FindFirstChild(n)
        if t and t.Character then local hrp = GetHRP(t); if hrp then TPTo(hrp.Position+Vector3.new(0,3,0)) end end
    end})
    AddConn("TPAdd", Players.PlayerAdded:Connect(function(p)
        if Options.TPPlayerSelect then pcall(function() Options.TPPlayerSelect:Add(p.Name) end) end
    end))
    AddConn("TPRem", Players.PlayerRemoving:Connect(function(p)
        if Options.TPPlayerSelect then pcall(function() Options.TPPlayerSelect:Remove(p.Name) end) end
    end))

    -- Fling подсекция (в Troll)
    tTr:AddDropdown("FlingMode",{Title=L("fling_mode"),Values={"Murderer","Sheriff","Specific","All"},Default="Murderer"}):OnChanged(function(v)
        if _G.FH_SetFlingMode then _G.FH_SetFlingMode(v) end
    end)
    tTr:AddDropdown("FlingTarget",{Title=L("fling_target"),Values=(function() local l={} for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then l[#l+1]=p.Name end end return l end)(),Default=nil}):OnChanged(function(v)
        if _G.FH_SetFlingTarget then _G.FH_SetFlingTarget(v) end
    end)
    tTr:AddSlider("FlingRange",{Title=L("fling_range"),Min=20,Max=2000,Default=500,Rounding=0}):OnChanged(function(v)
        if _G.FH_SetFlingRange then _G.FH_SetFlingRange(v) end
    end)
    tTr:AddToggle("FlingToggle",{Title=L("fling_on"),Default=false}):OnChanged(function(v)
        if _G.FH_SetFlingOn then _G.FH_SetFlingOn(v) end
        Notify(L("notify_title"), "Fling "..(v and "ON" or "OFF"), 1.5)
    end)
    tTr:AddButton({Title=L("fling_once"),Callback=function()
        if _G.FH_FlingOnce then _G.FH_FlingOnce() end
    end})

    -- ============ UTILITY ============
    Reg("AntiFling",L("anti_fling")); Reg("AntiVoid",L("anti_void")); Reg("AntiTrap",L("anti_trap"))
    Reg("FakePos",L("fake_pos")); Reg("TPTool",L("tp_tool")); Reg("FlingTool",L("fling_tool"))
    Reg("SoundReplacer",L("sound_replacer")); Reg("Invis",L("invis"))

    tU:AddButton({Title=L("vote_boost"),Callback=function()
        if S.voteRunning then Notify(L("notify_title"),L("vote_running"),2); return end
        S.voteRunning = true
        task.spawn(function()
            local my = GetHRP(); if not my then S.voteRunning=false; return end
            local orig = my.CFrame
            for i=1,5 do
                local c = LocalPlayer.Character
                if c then local h = c:FindFirstChild("Humanoid"); if h then h.Health=0 end end
                LocalPlayer.CharacterAdded:Wait(); task.wait(0.5)
                local n = GetHRP(); local tries = 0
                while not n and tries<20 do task.wait(0.1); n=GetHRP(); tries=tries+1 end
                if n then task.wait(0.1); n.CFrame = orig; task.wait(0.3) end
            end
            Notify(L("notify_title"),L("vote_done"),3); S.voteRunning=false
        end)
    end})
    tU:AddToggle("Invis",{Title=L("invis"),Default=false}):OnChanged(function(v)
        task.spawn(function()
            local ok = ClickExternalButton({"invisible","invis","невид"})
            if ok then Notify(L("notify_title"), v and L("invis_on") or L("invis_off"), 2)
            else Notify(L("notify_title"),L("invis_nf"),3) end
        end)
    end)
    tU:AddToggle("AntiAFK",{Title=L("anti_afk"),Default=true})
    tU:AddButton({Title=L("rejoin"),Callback=function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end})
    tU:AddButton({Title=L("server_hop"),Callback=function()
        pcall(function()
            local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
            local data = game:HttpGet(url); local parsed = HttpService:JSONDecode(data)
            for _,s in ipairs(parsed.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer); break
                end
            end
        end)
    end})
    tU:AddToggle("AntiFling",{Title=L("anti_fling"),Default=false}):OnChanged(function(v) if _G.FH_SetAntiFling then _G.FH_SetAntiFling(v) end end)
    tU:AddToggle("AntiVoid",{Title=L("anti_void"),Default=false}):OnChanged(function(v) if _G.FH_SetAntiVoid then _G.FH_SetAntiVoid(v) end end)
    tU:AddToggle("AntiTrap",{Title=L("anti_trap"),Default=false}):OnChanged(function(v) if _G.FH_SetAntiTrap then _G.FH_SetAntiTrap(v) end end)
    tU:AddToggle("FakePos",{Title=L("fake_pos"),Default=false}):OnChanged(function(v) if _G.FH_SetFakePos then _G.FH_SetFakePos(v) end end)
    tU:AddSlider("FakePosX",{Title=L("fake_pos_x"),Min=1,Max=9,Default=9,Rounding=0}):OnChanged(function(v) if _G.FH_SetFakeX then _G.FH_SetFakeX(v) end end)
    tU:AddSlider("FakePosY",{Title=L("fake_pos_y"),Min=1,Max=9,Default=9,Rounding=0}):OnChanged(function(v) if _G.FH_SetFakeY then _G.FH_SetFakeY(v) end end)
    tU:AddSlider("FakePosZ",{Title=L("fake_pos_z"),Min=1,Max=9,Default=9,Rounding=0}):OnChanged(function(v) if _G.FH_SetFakeZ then _G.FH_SetFakeZ(v) end end)
    tU:AddToggle("TPTool",{Title=L("tp_tool"),Default=false}):OnChanged(function(v) if _G.FH_SetTPTool then _G.FH_SetTPTool(v) end end)
    tU:AddToggle("FlingTool",{Title=L("fling_tool"),Default=false}):OnChanged(function(v) if _G.FH_SetFlingTool then _G.FH_SetFlingTool(v) end end)
    tU:AddToggle("FlingBypass",{Title=L("fling_bypass"),Default=false}):OnChanged(function(v) if _G.FH_SetFlingBypass then _G.FH_SetFlingBypass(v) end end)
    tU:AddToggle("SoundReplacer",{Title=L("sound_replacer"),Default=false}):OnChanged(function(v) if _G.FH_SetSndOn then _G.FH_SetSndOn(v) end end)
    tU:AddDropdown("SoundSheriff",{Title=L("sound_sheriff"),Values={"mc bow","neverlose","rust","primordial","sparkle","break"},Default="mc bow"}):OnChanged(function(v) if _G.FH_SetSndShf then _G.FH_SetSndShf(v) end end)
    tU:AddDropdown("SoundMurder",{Title=L("sound_murder"),Values={"skeet","neverlose","rust","primordial","sparkle","break"},Default="skeet"}):OnChanged(function(v) if _G.FH_SetSndMur then _G.FH_SetSndMur(v) end end)
    tU:AddSlider("SoundVol",{Title=L("sound_volume"),Min=0.1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) if _G.FH_SetSndVol then _G.FH_SetSndVol(v) end end)

    -- ============ MOBILE ============
    local mobVals = {"ShootBtn","SpeedToggle","SpeedGlitch","BunnyHop","Spinbot","FlyToggle","Noclip","FreezeToggle","WallBounce","AutoFarmCoins","PlayerESP","NameESP","DistESP","GunESP","CoinESP","KillAura","AutoGrabGun","Invis","QuietShot","InfJump","JumpPowerToggle"}
    tMo:AddDropdown("TouchModulesDropdown",{Title=L("select_modules_multi"),Values=mobVals,Multi=true,Default={}})
    tMo:AddToggle("LockButtons",{Title=L("freeze_buttons"),Default=false}):OnChanged(function(v)
        S.mobileLocked = v; Notify(L("notify_title"), "Заморозка "..(v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)
    tMo:AddToggle("ShowShootBtn",{Title=L("show_shoot_btn"),Default=false}):OnChanged(function(v)
        if ShootBtnRef then ShootBtnRef.Visible = v end
        Notify(L("notify_title"), L("show_shoot_btn").." "..(v and "ON" or "OFF"), 1.5)
    end)
    tMo:AddButton({Title=L("create_selected"),Callback=function()
        local val = Options.TouchModulesDropdown and Options.TouchModulesDropdown.Value
        if not val then Notify(L("notify_title"),L("nothing_selected"),2); return end
        for mn,sel in pairs(val) do
            if sel and not MobileButtons[mn] then CreateTouchButton(mn) end
        end
    end})
    tMo:AddButton({Title=L("clear_all"),Callback=function()
        if S.mobileLocked then Notify(L("notify_title"),L("freeze_first"),2); return end
        for _,f in pairs(MobileButtons) do if f then f:Destroy() end end
        MobileButtons = {}
    end})

    -- ============ KEYBINDS ============
    local bindV = {"SpeedToggle","SpeedGlitch","BunnyHop","Spinbot","FlyToggle","Noclip","FreezeToggle","WallBounce","AutoFarmCoins","PlayerESP","NameESP","DistESP","GunESP","CoinESP","KillAura","AutoGrabGun","Invis","InfJump","JumpPowerToggle","AWPReplace","SilentAim","KnifeSilent","Backtrack","Tracer","ChinaHat","SelfChams","OffArrows","MatChams","Crosshair"}
    tK:AddDropdown("BindSelect",{Title=L("module"),Values=bindV,Default="SpeedToggle"})
    tK:AddButton({Title=L("set_bind"),Callback=function()
        local m = Options.BindSelect and Options.BindSelect.Value
        if not m then return end
        ShowBindPopup(m, ModuleNameToTitle[m] or m)
    end})
    tK:AddButton({Title=L("clear_binds"),Callback=function()
        for k in pairs(BindList) do BindList[k]=nil end
        for k in pairs(BindKeyCache) do BindKeyCache[k]=nil end
        for k in pairs(BindTimeCache) do BindTimeCache[k]=nil end
        Notify(L("notify_title"),L("binds_cleared"),2)
    end})

    -- ============ SETTINGS ============
    tS:AddToggle("NotifyToggles",{Title=L("notify_toggles"),Default=true})
    tS:AddToggle("ShowHUD",{Title=L("show_hud"),Default=false}):OnChanged(function(v) TopHUDGui.Enabled=v end)
    tS:AddToggle("CoordMode",{Title=L("coord_mode"),Default=false}):OnChanged(function(v)
        CoordGui.Enabled = v
    end)
    local ld = (CurrentLang=="ru") and "Russian" or "English"
    tS:AddDropdown("LanguageSelect",{Title=L("language"),Values={"English","Russian"},Default=ld}):OnChanged(function(v)
        local nl = (v=="Russian") and "ru" or "en"
        if nl == CurrentLang then return end
        CurrentLang = nl; _G.FortniHubLang = nl
        if writefile then pcall(function() writefile("FortniHubLang.txt", nl) end) end
        Notify(L("notify_title"),L("lang_saved"),5)
    end)
    tS:AddButton({Title=L("unload"),Callback=function()
        pcall(function()
            for _,c in pairs(Connections) do c:Disconnect() end
            Connections = {}
            if TopHUDGui then TopHUDGui:Destroy() end
            if MobUI then MobUI:Destroy() end
            if ESPFolder then ESPFolder:Destroy() end
            if OpenScriptGui then OpenScriptGui:Destroy() end
            if CoordGui then CoordGui:Destroy() end
            if BindPopupGui then BindPopupGui:Destroy() end
            Lighting.Ambient = OriginalLighting.Ambient
            Lighting.Brightness = OriginalLighting.Brightness
            Camera.FieldOfView = OriginalLighting.FOV
            for _,d in pairs(Cache.nameESP) do pcall(function() d:Remove() end) end
            for _,d in pairs(Cache.distESP) do pcall(function() d:Remove() end) end
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

    -- ============ EFFECTS TAB ============
    Reg("OffArrows",L("off_arrows")); Reg("MatChams",L("mat_chams")); Reg("Crosshair",L("crosshair"))
    Reg("Shader",L("shader")); Reg("Backtrack",L("backtrack")); Reg("Tracer",L("tracer"))
    Reg("ChinaHat",L("china_hat")); Reg("SelfChams",L("self_chams")); Reg("MovGraph",L("mov_graph"))

    tE:AddToggle("Backtrack",{Title=L("backtrack"),Default=false}):OnChanged(function(v) if _G.FH_SetBt then _G.FH_SetBt(v) end end)
    tE:AddColorPicker("BtColor",{Title=L("backtrack_color"),Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) if _G.FH_SetBtCol then _G.FH_SetBtCol(c) end end)
    tE:AddToggle("Tracer",{Title=L("tracer"),Default=false}):OnChanged(function(v) if _G.FH_SetTrc then _G.FH_SetTrc(v) end end)
    tE:AddColorPicker("TracerColor",{Title=L("tracer_color"),Default=Color3.fromRGB(133,220,255)}):OnChanged(function(c) if _G.FH_SetTrcCol then _G.FH_SetTrcCol(c) end end)
    tE:AddSlider("TracerDur",{Title=L("tracer_duration"),Min=0.1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) if _G.FH_SetTrcDur then _G.FH_SetTrcDur(v) end end)
    tE:AddToggle("ChinaHat",{Title=L("china_hat"),Default=false}):OnChanged(function(v) if _G.FH_SetChina then _G.FH_SetChina(v) end end)
    tE:AddColorPicker("ChinaHatColor",{Title=L("china_hat_color"),Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) if _G.FH_SetChinaCol then _G.FH_SetChinaCol(c) end end)
    tE:AddToggle("SelfChams",{Title=L("self_chams"),Default=false}):OnChanged(function(v) if _G.FH_SetSelfCh then _G.FH_SetSelfCh(v) end end)
    tE:AddColorPicker("SelfChamsColor",{Title=L("self_chams_color"),Default=Color3.fromRGB(120,60,255)}):OnChanged(function(c) if _G.FH_SetSelfChCol then _G.FH_SetSelfChCol(c) end end)
    tE:AddToggle("MovGraph",{Title=L("mov_graph"),Default=false}):OnChanged(function(v) if _G.FH_SetMov then _G.FH_SetMov(v) end end)
    tE:AddColorPicker("MovGraphColor",{Title=L("mov_graph_color"),Default=Color3.fromRGB(242,242,242)}):OnChanged(function(c) if _G.FH_SetMovCol then _G.FH_SetMovCol(c) end end)
    tE:AddSlider("MovGraphWidth",{Title=L("mov_graph_width"),Min=180,Max=420,Default=280,Rounding=0}):OnChanged(function(v) if _G.FH_SetMovW then _G.FH_SetMovW(v) end end)
    tE:AddSlider("MovGraphHeight",{Title=L("mov_graph_height"),Min=40,Max=120,Default=72,Rounding=0}):OnChanged(function(v) if _G.FH_SetMovH then _G.FH_SetMovH(v) end end)
    tE:AddSlider("MovGraphY",{Title=L("mov_graph_y"),Min=-200,Max=400,Default=180,Rounding=0}):OnChanged(function(v) if _G.FH_SetMovY then _G.FH_SetMovY(v) end end)
    tE:AddToggle("OffArrows",{Title=L("off_arrows"),Default=false}):OnChanged(function(v) if _G.FH_SetArr then _G.FH_SetArr(v) end end)
    tE:AddSlider("OffArrowsSize",{Title=L("off_arrows_size"),Min=16,Max=96,Default=42,Rounding=0}):OnChanged(function(v) if _G.FH_SetArrSz then _G.FH_SetArrSz(v) end end)
    tE:AddSlider("OffArrowsDist",{Title=L("off_arrows_dist"),Min=40,Max=520,Default=260,Rounding=0}):OnChanged(function(v) if _G.FH_SetArrDst then _G.FH_SetArrDst(v) end end)
    tE:AddColorPicker("ArrMur",{Title="Маньяк",Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) if _G.FH_SetArrCM then _G.FH_SetArrCM(c) end end)
    tE:AddColorPicker("ArrShf",{Title="Шериф",Default=Color3.fromRGB(60,140,255)}):OnChanged(function(c) if _G.FH_SetArrCS then _G.FH_SetArrCS(c) end end)
    tE:AddColorPicker("ArrInno",{Title="Невиновный",Default=Color3.fromRGB(255,255,255)}):OnChanged(function(c) if _G.FH_SetArrCI then _G.FH_SetArrCI(c) end end)
    tE:AddToggle("MatChams",{Title=L("mat_chams"),Default=false}):OnChanged(function(v) if _G.FH_SetMat then _G.FH_SetMat(v) end end)
    tE:AddDropdown("MatType",{Title=L("mat_chams_type"),Values={"ForceField","Flat","Chromatic"},Default="ForceField"}):OnChanged(function(v) if _G.FH_SetMatType then _G.FH_SetMatType(v) end end)
    tE:AddToggle("Crosshair",{Title=L("crosshair"),Default=false}):OnChanged(function(v) if _G.FH_SetCH then _G.FH_SetCH(v) end end)
    tE:AddSlider("ChGap",{Title=L("crosshair_gap"),Min=0,Max=20,Default=4,Rounding=1}):OnChanged(function(v) if _G.FH_SetCHG then _G.FH_SetCHG(v) end end)
    tE:AddSlider("ChLen",{Title=L("crosshair_len"),Min=2,Max=30,Default=8,Rounding=1}):OnChanged(function(v) if _G.FH_SetCHL then _G.FH_SetCHL(v) end end)
    tE:AddSlider("ChThick",{Title=L("crosshair_thick"),Min=1,Max=5,Default=2,Rounding=1}):OnChanged(function(v) if _G.FH_SetCHT then _G.FH_SetCHT(v) end end)
    tE:AddSlider("ChRot",{Title=L("crosshair_rotate"),Min=0,Max=10,Default=0,Rounding=1}):OnChanged(function(v) if _G.FH_SetCHR then _G.FH_SetCHR(v) end end)
    tE:AddColorPicker("ChCol",{Title=L("crosshair_color"),Default=Color3.fromRGB(255,255,255)}):OnChanged(function(c) if _G.FH_SetCHC then _G.FH_SetCHC(c) end end)
    tE:AddColorPicker("ChOut",{Title=L("crosshair_outline"),Default=Color3.fromRGB(0,0,0)}):OnChanged(function(c) if _G.FH_SetCHO then _G.FH_SetCHO(c) end end)
    tE:AddToggle("Shader",{Title=L("shader"),Default=false}):OnChanged(function(v) if _G.FH_SetShd then _G.FH_SetShd(v) end end)
    tE:AddDropdown("ShaderType",{Title=L("shader_preset"),Values={"morning","midday","evening","night"},Default="morning"}):OnChanged(function(v) if _G.FH_SetShdT then _G.FH_SetShdT(v) end end)
    tE:AddToggle("TimeChanger",{Title=L("time_changer"),Default=false}):OnChanged(function(v) if _G.FH_SetTime then _G.FH_SetTime(v) end end)
    tE:AddSlider("TimeValue",{Title=L("time_value"),Min=0,Max=24,Default=12,Rounding=1}):OnChanged(function(v) if _G.FH_SetTimeVal then _G.FH_SetTimeVal(v) end end)
    tE:AddToggle("CustomFog",{Title=L("custom_fog"),Default=false}):OnChanged(function(v) if _G.FH_SetFog then _G.FH_SetFog(v) end end)
    tE:AddColorPicker("FogColor",{Title=L("fog_color"),Default=Color3.fromRGB(192,192,192)}):OnChanged(function(c) if _G.FH_SetFogCol then _G.FH_SetFogCol(c) end end)
    tE:AddSlider("FogStart",{Title=L("fog_start"),Min=0,Max=1000,Default=0,Rounding=1}):OnChanged(function(v) if _G.FH_SetFogS then _G.FH_SetFogS(v) end end)
    tE:AddSlider("FogEnd",{Title=L("fog_end"),Min=0,Max=1000,Default=1000,Rounding=1}):OnChanged(function(v) if _G.FH_SetFogE then _G.FH_SetFogE(v) end end)
    tE:AddToggle("WorldFX",{Title=L("world_fx"),Default=false}):OnChanged(function(v) if _G.FH_SetFX then _G.FH_SetFX(v) end end)
    tE:AddDropdown("WorldFXType",{Title=L("world_fx_type"),Values={"Snow","Sakura"},Default="Snow"}):OnChanged(function(v) if _G.FH_SetFXT then _G.FH_SetFXT(v) end end)
    tE:AddColorPicker("WorldFXColor",{Title=L("world_fx_color"),Default=Color3.fromRGB(150,200,255)}):OnChanged(function(c) if _G.FH_SetFXC then _G.FH_SetFXC(c) end end)
    tE:AddSlider("WorldFXRate",{Title=L("world_fx_rate"),Min=20,Max=900,Default=250,Rounding=1}):OnChanged(function(v) if _G.FH_SetFXR then _G.FH_SetFXR(v) end end)
    tE:AddToggle("WorldAura",{Title=L("world_aura"),Default=false}):OnChanged(function(v) if _G.FH_SetAura then _G.FH_SetAura(v) end end)
    tE:AddDropdown("WorldAuraType",{Title=L("world_aura_type"),Values={"angel","starlight","heavenly","ribbon","sakura","wind","flow","star"},Default="angel"}):OnChanged(function(v) if _G.FH_SetAuraT then _G.FH_SetAuraT(v) end end)
    tE:AddColorPicker("WorldAuraColor",{Title=L("world_aura_color"),Default=Color3.fromRGB(133,220,255)}):OnChanged(function(c) if _G.FH_SetAuraC then _G.FH_SetAuraC(c) end end)
    tE:AddToggle("LandCircle",{Title=L("land_circle"),Default=false}):OnChanged(function(v) if _G.FH_SetLand then _G.FH_SetLand(v) end end)
    tE:AddColorPicker("LandColor",{Title=L("land_circle_color"),Default=Color3.fromRGB(255,255,255)}):OnChanged(function(c) if _G.FH_SetLandC then _G.FH_SetLandC(c) end end)
    tE:AddSlider("LandTransp",{Title="Прозрачность",Min=0,Max=1,Default=1,Rounding=2}):OnChanged(function(v) if _G.FH_SetLandT then _G.FH_SetLandT(v) end end)
    tE:AddSlider("LandDur",{Title=L("land_circle_dur"),Min=0.1,Max=3,Default=0.82,Rounding=2}):OnChanged(function(v) if _G.FH_SetLandD then _G.FH_SetLandD(v) end end)
end

local mOk, mErr = pcall(CreateAllModules)
if not mOk then logErr("Ошибка создания модулей: "..tostring(mErr)) else logInfo("Модули созданы") end

-- ============================================================
-- КОНЕЦ ЧАСТИ 1. Дальше идёт Часть 2 (Main Loop, ESP, AutoFarm,
-- Binds, CharAdded + ADDON с обработчиками событий _G.FH_*).
-- ============================================================
-- ============================================================
-- MAIN LOOP
-- ============================================================
local lastHUD, lastESP, lastItemESP = 0, 0, 0
local fpsC, lastFPS, curFPS = 0, os.clock(), 60

AddConn("MainLoop", RunService.Heartbeat:Connect(function()
    RefreshCharCache()
    local now = os.clock()

    if now - lastHUD > 0.5 then
        lastHUD = now
        if TopHUDGui.Enabled then
            PingLabel.Text = string.format("PING %dms", math.floor(LocalPlayer:GetNetworkPing()*1000))
            RoundLabel.Text = L("round_time").." "..GetRoundTime()
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
                    bv.Name = "FH_FreezeBV"; bv.MaxForce = Vector3.new(1e5,1e5,1e5)
                    bv.Velocity = Vector3.zero; bv.Parent = hrp
                end
                local speed = Options.FreezeSpeed and Options.FreezeSpeed.Value or 60
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) or flyKeys.W then dir = dir + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) or flyKeys.S then dir = dir - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) or flyKeys.A then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) or flyKeys.D then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyKeys.UP then dir = dir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or flyKeys.DOWN then dir = dir - Vector3.new(0,1,0) end
                local bv = hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv.Velocity = dir.Magnitude > 0 and dir.Unit*speed or Vector3.zero end
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
            if st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.Freefall then
                S.sgActive = true; S.lastMoveTime = tick(); hum.WalkSpeed = gs
            elseif st==Enum.HumanoidStateType.Landed or st==Enum.HumanoidStateType.Running or st==Enum.HumanoidStateType.RunningNoPhysics then
                if hum.MoveDirection.Magnitude > 0.1 then
                    S.sgActive = true; S.lastMoveTime = tick(); hum.WalkSpeed = gs
                elseif tick()-S.lastMoveTime > 0.2 and S.sgActive then
                    hum.WalkSpeed = 16; S.sgActive = false
                end
            end
        end
        if Options.BunnyHop and Options.BunnyHop.Value then
            local maxS = Options.BunnyMaxSpeed and Options.BunnyMaxSpeed.Value or 250
            local acc = Options.BunnyAccelTime and Options.BunnyAccelTime.Value or 10
            if hum.MoveDirection.Magnitude > 0.1 then
                _G.BunnySpeed = math.min((_G.BunnySpeed or 16)+(maxS/acc)*0.02, maxS)
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

    if Options.KillAura and Options.KillAura.Value then
        local n2 = tick()
        if n2 - (_G.LastKaHit or 0) > 0.25 then
            local my = Cache.localHRP
            if my and LocalPlayer.Character then
                local knife = LocalPlayer.Character:FindFirstChild("Knife")
                if knife then
                    local r = Options.KillAuraRadius and Options.KillAuraRadius.Value or 25
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer then
                            local thrp = GetHRP(p)
                            if thrp and (thrp.Position-my.Position).Magnitude <= r then
                                my.CFrame = thrp.CFrame*CFrame.new(0,0,1.5)
                                pcall(function() VirtualUser:ClickButton1(Vector2.new(0,0)) end)
                                pcall(function()
                                    local s = knife:FindFirstChild("Stab") or knife:FindFirstChild("Slash") or knife:FindFirstChild("Hit")
                                    if s then
                                        if s:IsA("RemoteEvent") then s:FireServer()
                                        elseif s:IsA("RemoteFunction") then s:InvokeServer() end
                                    end
                                end)
                                _G.LastKaHit = n2; break
                            end
                        end
                    end
                end
            end
        end
    end

    if Options.AutoGrabGun and Options.AutoGrabGun.Value and not S.grabFailed and not S.isGrabbing then
        local char = LocalPlayer.Character
        local my = char and char:FindFirstChild("HumanoidRootPart")
        if my and not char:FindFirstChild("Gun") and not (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun")) then
            local closest, minD = nil, math.huge
            for _, gun in ipairs(Cache.guns) do
                if gun and gun.Parent and gun:IsA("BasePart") then
                    local d = (gun.Position-my.Position).Magnitude
                    if d < minD then minD = d; closest = gun end
                end
            end
            if closest then
                S.isGrabbing = true
                task.spawn(function()
                    local rp = my.CFrame
                    local tp = closest:IsA("BasePart") and closest or closest:FindFirstChildWhichIsA("BasePart")
                    if tp then
                        local grabbed = false
                        for i=1,3 do
                            if my and my.Parent then my.CFrame = tp.CFrame end
                            task.wait(0.05)
                            pcall(function() firetouchinterest(my, tp, 0); task.wait(0.02); firetouchinterest(my, tp, 1) end)
                            if LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun") then grabbed=true; break end
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun") then grabbed=true; break end
                        end
                        if my and my.Parent then
                            my.CFrame = rp
                            my.AssemblyLinearVelocity = Vector3.new(0,0,0)
                            my.AssemblyAngularVelocity = Vector3.new(0,0,0)
                        end
                        if not grabbed then S.grabFailed = true; Notify(L("notify_title"),L("grab_fail"),3) end
                    end
                    S.isGrabbing = false
                end)
            end
        end
    end

    if Options.AutoCollect and Options.AutoCollect.Value then
        local my = Cache.localHRP
        if my then
            for _, coin in ipairs(Cache.coins) do
                if coin and coin.Parent and coin:IsA("BasePart") and (coin.Position-my.Position).Magnitude < 5 then
                    pcall(function() firetouchinterest(my, coin, 0); firetouchinterest(my, coin, 1) end)
                end
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
                    hl.FillTransparency = 0.5; hl.OutlineColor = Color3.new(1,1,1)
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
                    hl.Name = "FH_GunHL"; hl.Adornee = gun; hl.FillColor = Color3.fromRGB(255,255,0); hl.Parent = gun
                end
            end
        else
            for _, gun in ipairs(Cache.guns) do
                if gun and gun.Parent then local hl = gun:FindFirstChild("FH_GunHL"); if hl then hl:Destroy() end end
            end
        end
        if Options.CoinESP and Options.CoinESP.Value then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name=="Coin_Server" or obj.Name=="Coin") then
                    if not obj:FindFirstChild("FH_CoinHL") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "FH_CoinHL"; hl.Adornee = obj
                        hl.FillColor = Color3.fromRGB(255,215,0); hl.OutlineColor = Color3.new(1,1,1)
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
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyKeys.UP then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or flyKeys.DOWN then dir = dir - Vector3.new(0,1,0) end
            hrp.Velocity = dir.Magnitude > 0 and dir.Unit*sp or Vector3.zero
        end
    else
        if Cache.localHum and Cache.localHum.PlatformStand then Cache.localHum.PlatformStand = false end
    end

    if CoordGui.Enabled and Cache.localHRP then
        local p = Cache.localHRP.Position
        CoordLabel.Text = string.format("X: %d Y: %d Z: %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z))
    end

    fpsC = fpsC + 1
    if now - lastFPS >= 1 then
        curFPS = fpsC; fpsC = 0; lastFPS = now
        if TopHUDGui.Enabled then
            local fc = THEME_OK
            if curFPS < 60 then fc = THEME_WARN end
            if curFPS < 30 then fc = THEME_ERR end
            FPSLabel.Text = string.format("FPS %d", curFPS); FPSLabel.TextColor3 = fc
        end
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
                local hp = hrp.Position + Vector3.new(0,3,0)
                local sp, on = Camera:WorldToViewportPoint(hp)
                if Options.NameESP and Options.NameESP.Value then
                    if not Cache.nameESP[p] then
                        local d = Drawing.new("Text"); d.Size=14; d.Center=true; d.Outline=true; d.Color=Color3.new(1,1,1); Cache.nameESP[p]=d
                    end
                    local d = Cache.nameESP[p]
                    if on then d.Position=Vector2.new(sp.X,sp.Y-20); d.Text=p.Name; d.Visible=true else d.Visible=false end
                end
                if Options.DistESP and Options.DistESP.Value then
                    if not Cache.distESP[p] then
                        local d = Drawing.new("Text"); d.Size=12; d.Center=true; d.Outline=true; d.Color=Color3.fromRGB(200,200,200); Cache.distESP[p]=d
                    end
                    local d = Cache.distESP[p]
                    if on then d.Position=Vector2.new(sp.X,sp.Y+5); d.Text=math.floor((Camera.CFrame.Position-hrp.Position).Magnitude).."m"; d.Visible=true else d.Visible=false end
                end
            end
        end
    end
end))
AddConn("TextESPRem", Players.PlayerRemoving:Connect(function(p)
    if Cache.nameESP[p] then Cache.nameESP[p]:Remove(); Cache.nameESP[p]=nil end
    if Cache.distESP[p] then Cache.distESP[p]:Remove(); Cache.distESP[p]=nil end
    local hl = ESPFolder:FindFirstChild("ESP_"..p.Name); if hl then hl:Destroy() end
end))

-- ============================================================
-- AUTOFARM
-- ============================================================
local function collectAllCoins()
    if #Cache.coins > 0 then
        local l = {}
        for _,c in ipairs(Cache.coins) do if c and c.Parent and c:IsA("BasePart") then table.insert(l, c) end end
        if #l > 0 then return l end
    end
    local l = {}
    for _,o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and (o.Name=="Coin_Server" or o.Name=="Coin" or string.find(o.Name:lower(),"coin")) then
            table.insert(l, o)
        end
    end
    return l
end
local function stopFarm()
    S.farmRunning = false; S.farmAnchored = false
    local hrp = GetHRP(); if hrp then hrp.Anchored = false end
    S.recentlyTouched = {}; S.farmLastCoinTime = 0
    S.farmTimeoutStart = tick(); S.farmLastCoinCount = 0
end
local function startFarm()
    if S.farmRunning then return end
    S.farmRunning = true; S.farmTimeoutStart = tick()
    S.farmLastCoinCount = GetCoinCount()
    task.spawn(function()
        while Options.AutoFarmCoins and Options.AutoFarmCoins.Value do
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(0.15)
            else
                local cur = GetCoinCount()
                if cur > S.farmLastCoinCount then S.farmLastCoinCount = cur; S.farmTimeoutStart = tick() end
                if tick() - S.farmTimeoutStart > 20 then
                    Notify(L("notify_title"), L("farm_restart"), 3)
                    stopFarm(); task.wait(0.5)
                    if Options.AutoFarmCoins and Options.AutoFarmCoins.Value then S.farmRunning = false; startFarm() end
                    return
                end
                if cur >= 40 then
                    if S.farmAnchored then hrp.Anchored = false; S.farmAnchored = false end
                    if S.farmAutoKill and GetRole(LocalPlayer)=="murderer" then
                        local m = nil
                        for _,p in ipairs(Players:GetPlayers()) do
                            if p~=LocalPlayer and GetRole(p)=="murderer" then m = p; break end
                        end
                        if m then
                            local thrp = GetHRP(m)
                            if thrp and (thrp.Position-hrp.Position).Magnitude <= 25 then
                                hrp.CFrame = thrp.CFrame*CFrame.new(0,0,1.5); task.wait(0.1)
                                local knife = char:FindFirstChild("Knife")
                                if knife then
                                    pcall(function() knife:Activate() end)
                                    pcall(function() VirtualUser:ClickButton1(Vector2.new(0,0)) end)
                                end
                                task.wait(0.15)
                            end
                        end
                    end
                    Notify(L("notify_title"), L("farm_full"), 3); task.wait(0.8)
                end
                if not (Options.AutoFarmCoins and Options.AutoFarmCoins.Value) then break end
                if not S.farmAnchored then hrp.Anchored = true; S.farmAnchored = true end
                for _,p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
                if S.farmAvoidMurderer then
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p~=LocalPlayer and GetRole(p)=="murderer" then
                            local thrp = GetHRP(p)
                            if thrp and (thrp.Position-hrp.Position).Magnitude < 10 then
                                local ad = hrp.Position - thrp.Position
                                if ad.Magnitude < 0.1 then ad = Vector3.new(0,0,1) end
                                hrp.CFrame = CFrame.new(hrp.Position + ad.Unit*30); task.wait(0.15); break
                            end
                        end
                    end
                end
                local now = tick()
                for coin, t in pairs(S.recentlyTouched) do
                    if now - t > 6 or not coin.Parent then S.recentlyTouched[coin] = nil end
                end
                local coins = collectAllCoins()
                if #coins == 0 then task.wait(0.2)
                else
                    local allMarked = true
                    for _,c in ipairs(coins) do if not S.recentlyTouched[c] then allMarked = false; break end end
                    if allMarked then S.recentlyTouched = {} end
                    local closest, minDist = nil, math.huge
                    for _,c in ipairs(coins) do
                        if c.Parent and not S.recentlyTouched[c] then
                            local d = (hrp.Position-c.Position).Magnitude
                            if d < minDist then minDist = d; closest = c end
                        end
                    end
                    if closest and closest.Parent then
                        local sp = hrp.Position; local ep = closest.Position
                        if S.farmV2 then
                            ep = Vector3.new(ep.X, ep.Y - S.farmDownDepth, ep.Z)
                        end
                        local sv = Options.AutoFarmSpeed and Options.AutoFarmSpeed.Value or 8
                        local dist = (ep-sp).Magnitude
                        local steps = math.clamp(math.floor(dist/(sv*0.03)), 3, 50)
                        for i=1,steps do
                            if not hrp.Parent or not closest.Parent then break end
                            if not (Options.AutoFarmCoins and Options.AutoFarmCoins.Value) then break end
                            pcall(function() hrp.CFrame = CFrame.new(sp:Lerp(ep, i/steps)) end)
                            task.wait(0.015)
                        end
                        if hrp.Parent and closest.Parent then
                            pcall(function() hrp.CFrame = CFrame.new(ep) end); task.wait(0.03)
                            for _=1,5 do
                                if not closest.Parent then break end
                                pcall(function()
                                    firetouchinterest(hrp, closest, 0); task.wait(0.01); firetouchinterest(hrp, closest, 1)
                                end)
                                task.wait(0.04)
                            end
                            S.recentlyTouched[closest] = tick(); task.wait(0.05)
                        end
                        if S.farmAnchored then hrp.Anchored = false; S.farmAnchored = false end
                        for _,p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = true end
                        end
                        task.wait(0.03)
                    else task.wait(0.15) end
                end
            end
        end
        if S.farmAnchored then
            local hrp = GetHRP(); if hrp then hrp.Anchored = false end
            S.farmAnchored = false
        end
        S.recentlyTouched = {}; S.farmRunning = false
    end)
end
AddConn("FarmCheck", RunService.Heartbeat:Connect(function()
    if Options.AutoFarmCoins and Options.AutoFarmCoins.Value then
        if not S.farmRunning then startFarm() end
    else
        if S.farmRunning then stopFarm() end
    end
end))

-- ============================================================
-- SPAM / ANTIAFK / LAG / INFJUMP / WALLBOUNCE
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
        VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
    end
end))
AddConn("LagLoop", RunService.RenderStepped:Connect(function()
    if not Options.TrollLag or not Options.TrollLag.Value then return end
    for i=1,5000 do local _ = math.noise(i, i*0.5) end
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
    for _,d in ipairs(dirs) do
        local res = Workspace:Raycast(hrp.Position, d*3, params)
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
    if Options.QuietShot and Options.QuietShot.Value and input.KeyCode == S.quietShotBind then
        if DoQuietShot then DoQuietShot() end; return
    end
    local keyName = nil
    if input.UserInputType == Enum.UserInputType.Keyboard then keyName = input.KeyCode.Name
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
        keyName = "Mouse"..input.UserInputType.Name:gsub("MouseButton","")
    end
    if keyName then
        local target = BindList[keyName]
        if target and Options[target] then Options[target]:SetValue(not Options[target].Value) end
    end
end))
if ShootBtnRef then
    ShootBtnRef.MouseButton1Click:Connect(function() if DoQuietShot then DoQuietShot() end end)
end
AddConn("MenuKey", UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.P then pcall(function() Window:Minimize() end) end
end))
if OpenBtn then OpenBtn.MouseButton1Click:Connect(function() pcall(function() Window:Minimize() end) end) end

AddConn("CharAdded", LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum = char:WaitForChild("Humanoid", 5)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    S.grabFailed = false; S.recentlyTouched = {}; S.farmAnchored = false
    S.farmTimeoutStart = tick(); S.isFrozen = false; S.charCacheTime = 0
    if hrp then
        hrp.Anchored = false
        for _, n in ipairs({"FH_FreezeBV","FH_FlyBV","FH_HidePosition"}) do
            local o = hrp:FindFirstChild(n); if o then o:Destroy() end
        end
    end
    if Options.SpeedToggle and Options.SpeedToggle.Value and hum then
        hum.WalkSpeed = Options.SpeedValue and Options.SpeedValue.Value or 32
    end
    if Options.Noclip and Options.Noclip.Value then
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end))

pcall(function() Window:SelectTab(1) end)

-- ============================================================
-- ADDON — backends
-- ============================================================
local A = {
    silentMode="v2", silentOn=false, autoShoot=false, autoDelay=0,
    origMT=nil, origTP=nil, weaponSvc=nil, lastFire=0,
    knifeSilent=false, knifeInsta=false, knifeRadius=12, knifeLead=1.0, knifeAir=0.35, knifeOffset=0,
    knifeTrackers={}, knifeOrigAim=nil,
    kaV2=false, kaV2Dist=30,
    btOn=false, btColor=Color3.fromRGB(255,60,60), btModel=nil, btHist={}, btCap=256, btFirst=1, btCount=0, btPairs={},
    tracerOn=false, tracerColor=Color3.fromRGB(133,220,255), tracerDur=1, tracerConn=nil,
    sndOn=false, sndShf="mc bow", sndMur="skeet", sndVol=1, sndHooked={}, sndPool={}, sndLast={s=0,m=0},
    antiFling=false, antiVoid=false, antiTrap=false, antiCache={},
    antiVoidOrig=workspace.FallenPartsDestroyHeight, antiSpd=16, antiJmp=50,
    tpOn=false, flingToolOn=false, flingBypass=false, tpObj=nil, flingObj=nil,
    fakeOn=false, fakeX=9e9, fakeY=9e9, fakeZ=9e9, fakeCF=CFrame.identity, fakeHooked={}, fakeActive=false,
    chinaOn=false, chinaCol=Color3.fromRGB(255,60,60), chinaParts={},
    selfChams=false, selfChamsCol=Color3.fromRGB(120,60,255), selfChamsCache={},
    movOn=false, movCol=Color3.fromRGB(242,242,242), movW=280, movH=72, movY=180,
    movLines={}, movShadow={}, movText=nil, movHist={},
    flingOn=false, flingMode="murderer", flingTarget="", flingCD=0, flingRange=500, flingActive=0,
    arrowsOn=false, arrowsCM=Color3.fromRGB(255,60,60), arrowsCS=Color3.fromRGB(60,140,255), arrowsCI=Color3.fromRGB(255,255,255),
    arrowsSize=42, arrowsDist=260, arrowsPool={},
    matChams=false, matType="ForceField", matCache={},
    chOn=false, chGap=4, chLen=8, chThick=2, chCol=Color3.fromRGB(255,255,255), chOut=Color3.fromRGB(0,0,0), chRot=0,
    chLines={}, chConn=nil, chRotNow=0,
    shaderOn=false, shaderType="morning",
    timeOn=false, timeVal=12,
    fogOn=false, fogCol=Color3.fromRGB(192,192,192), fogStart=0, fogEnd=1000,
    fxOn=false, fxType="Snow", fxCol=Color3.fromRGB(150,200,255), fxRate=250, fxPart=nil, fxEmit=nil, fxConn=nil,
    auraOn=false, auraType="angel", auraCol=Color3.fromRGB(133,220,255), auraParts={}, auraCache={},
    landOn=false, landCol=Color3.fromRGB(255,255,255), landTr=1, landDur=0.82, landConn=nil,
}
local auraIds = {angel="97658130917593",starlight="134645216613107",heavenly="139300897520961",ribbon="132069507632161",sakura="81755778619404",wind="80694081850877",flow="119913533725648",star="73754563740680"}
local origLight = {Amb=Lighting.Ambient,Br=Lighting.Brightness,CT=Lighting.ClockTime,CSB=Lighting.ColorShift_Bottom,CST=Lighting.ColorShift_Top,Exp=Lighting.ExposureCompensation,FC=Lighting.FogColor,FS=Lighting.FogStart,FE=Lighting.FogEnd}

local function GetRound()
    local ok, m = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient")) end)
    if ok and type(m)=="table" then return m.PlayerData end
end
local function AmMurderer()
    local d = GetRound(); if type(d)~="table" then return false end
    local me = d[LocalPlayer.Name]
    return me and me.Role=="Murderer" and not me.Dead
end
local function AmSheriff()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Gun") then return true end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild("Gun") then return true end
    local d = GetRound()
    if type(d)=="table" then local me = d[LocalPlayer.Name]; return me and (me.Role=="Sheriff" or me.Role=="Hero") end
    return false
end
local function GetGun()
    local c=LocalPlayer.Character; if c then local g=c:FindFirstChild("Gun"); if g then return g,true end end
    local bp=LocalPlayer:FindFirstChildOfClass("Backpack"); if bp then local g=bp:FindFirstChild("Gun"); if g then return g,false end end
    return nil,false
end
local function GetKnife()
    local c=LocalPlayer.Character; if c then local k=c:FindFirstChild("Knife"); if k then return k,true end end
    local bp=LocalPlayer:FindFirstChildOfClass("Backpack"); if bp then local k=bp:FindFirstChild("Knife"); if k then return k,false end end
    return nil,false
end
local function FindMur()
    local d = GetRound()
    if type(d)=="table" then
        for n,i in pairs(d) do
            if type(i)=="table" and i.Role=="Murderer" and not i.Dead then
                local p = Players:FindFirstChild(n); if p and p~=LocalPlayer then return p end
            end
        end
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Knife") then return p end
    end
end
local function FindShf()
    local d = GetRound()
    if type(d)=="table" then
        for n,i in pairs(d) do
            if type(i)=="table" and not i.Dead and (i.Role=="Sheriff" or i.Role=="Hero") then
                local p = Players:FindFirstChild(n); if p and p~=LocalPlayer then return p end
            end
        end
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
end

-- SILENT AIM
local function InstallSilent()
    if A.silentMode~="v2" then return end
    local ok, m = pcall(function() return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService")) end)
    if not ok or type(m)~="table" then return end
    A.weaponSvc = m
    if type(m.GetMouseTargetCFrame)=="function" and not A.origMT then
        A.origMT = m.GetMouseTargetCFrame
        local o = A.origMT
        pcall(function() setreadonly(m,false) end)
        pcall(function()
            m.GetMouseTargetCFrame = function(self,...)
                if not A.silentOn then return o(self,...) end
                local t = FindMur(); if not t or not t.Character then return o(self,...) end
                local thrp = t.Character:FindFirstChild("HumanoidRootPart"); if not thrp then return o(self,...) end
                local ping=0; pcall(function() ping=LocalPlayer:GetNetworkPing()*2 end)
                ping = math.clamp(ping,0.02,0.35)
                local v = thrp.AssemblyLinearVelocity
                return CFrame.new(thrp.Position + Vector3.new(v.X,0,v.Z)*ping)
            end
        end)
    end
    if type(m.GetTargetPosition)=="function" and not A.origTP then
        A.origTP = m.GetTargetPosition
        local o = A.origTP
        pcall(function()
            m.GetTargetPosition = function(self,x,y,...)
                if not A.silentOn then return o(self,x,y,...) end
                local t = FindMur(); if not t or not t.Character then return o(self,x,y,...) end
                local thrp = t.Character:FindFirstChild("HumanoidRootPart"); if not thrp then return o(self,x,y,...) end
                local ping=0; pcall(function() ping=LocalPlayer:GetNetworkPing()*2 end)
                ping = math.clamp(ping,0.02,0.35)
                local v = thrp.AssemblyLinearVelocity
                return CFrame.new(thrp.Position + Vector3.new(v.X,0,v.Z)*ping)
            end
        end)
    end
end
local function UninstallSilent()
    local m = A.weaponSvc; if not m then return end
    pcall(function() setreadonly(m,false) end)
    if A.origMT then pcall(function() m.GetMouseTargetCFrame = A.origMT end) end
    if A.origTP then pcall(function() m.GetTargetPosition = A.origTP end) end
end
AddConn("AutoShoot", RunService.Heartbeat:Connect(function()
    if not A.autoShoot or not AmSheriff() then return end
    local t = FindMur(); if not t then return end
    local gun, eq = GetGun(); if not gun then return end
    local now = os.clock()
    if now - A.lastFire < math.max(0, A.autoDelay/1000) then return end
    if not eq then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(gun) end) end
        return
    end
    local thrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart"); if not thrp then return end
    local rem = gun:FindFirstChild("Shoot")
    if rem and rem:IsA("RemoteEvent") then
        local o = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if o then pcall(function() rem:FireServer(o.CFrame, CFrame.new(thrp.Position)) end); A.lastFire = now end
    end
end))

-- KNIFE
local function KnifeTrack(p, now)
    if not p or not p.Character then return end
    local hrp = p.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local t = A.knifeTrackers[p]
    if not t then t={s={},n=0,i=0,vel=Vector3.zero,lp=nil,lt=now}; A.knifeTrackers[p]=t end
    local pos = hrp.Position
    if t.lp and (pos-t.lp).Magnitude > 0.005 then
        t.i = t.i%16+1; t.s[t.i]={t=now,p=pos}
        if t.n<16 then t.n=t.n+1 end
        if t.n>=3 then
            local nw = t.s[t.i].t; local used,sum=0,0
            for k=0,t.n-1 do
                local idx=(t.i-k-1)%16+1; local s=t.s[idx]
                if not s or nw-s.t>0.25 then break end
                used=used+1; sum=sum+(s.t-nw)
            end
            if used>=3 then
                local md=sum/used; local num,den=Vector3.zero,0
                for k=0,used-1 do
                    local idx=(t.i-k-1)%16+1; local s=t.s[idx]; if not s then break end
                    local dd=(s.t-nw)-md; num=num+s.p*dd; den=den+dd*dd
                end
                if den>1e-8 then t.vel=num/den end
            end
        end
    end
    t.lp, t.lt = pos, now
    return t, hrp
end
local function KnifeResolve()
    local c = LocalPlayer.Character; if not c or not c:FindFirstChild("Knife") then return end
    local my = c:FindFirstChild("HumanoidRootPart"); if not my then return end
    local best, bd = nil, math.huge; local now = os.clock()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local t,hrp = KnifeTrack(p, now)
            if hrp then
                local d = (hrp.Position-my.Position).Magnitude
                if d<bd then bd=d; best={p=p,hrp=hrp,t=t} end
            end
        end
    end
    if not best then return end
    local base = best.hrp.Position
    local vel = best.t and best.t.vel or best.hrp.AssemblyLinearVelocity
    local lead = A.knifeLead + A.knifeOffset
    local aim = base + Vector3.new(vel.X,0,vel.Z)*lead
    local hum = best.p.Character and best.p.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        local st = hum:GetState()
        if st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.Freefall then
            local g = workspace.Gravity
            aim = Vector3.new(aim.X, base.Y+vel.Y*lead-0.5*g*lead*lead+A.knifeAir, aim.Z)
        end
    end
    return aim
end
AddConn("KnifeHook", RunService.Heartbeat:Connect(function()
    if not A.knifeSilent then return end
    local m = A.weaponSvc
    if not m then
        local ok,mm = pcall(function() return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService")) end)
        if ok then m=mm; A.weaponSvc=m end
    end
    if not m then return end
    if not A.knifeOrigAim then A.knifeOrigAim = m.GetMouseTargetCFrame end
    local o = A.knifeOrigAim
    local has = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife")
    if not has then
        if m.GetMouseTargetCFrame~=o and o then pcall(function() setreadonly(m,false); m.GetMouseTargetCFrame=o end) end
        return
    end
    pcall(function() setreadonly(m,false) end)
    pcall(function()
        m.GetMouseTargetCFrame = function(self,...)
            if A.knifeSilent then local aim=KnifeResolve(); if aim then return CFrame.new(aim) end end
            if o then return o(self,...) end
        end
    end)
end))
AddConn("KnifeInsta", RunService.Heartbeat:Connect(function()
    if not A.knifeInsta or not AmMurderer() then return end
    local k,eq = GetKnife(); if not k or not eq then return end
    local my = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not my then return end
    local ev = k:FindFirstChild("Events"); if not ev then return end
    local stab = ev:FindFirstChild("KnifeStabbed"); local touch = ev:FindFirstChild("HandleTouched")
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local thrp = p.Character:FindFirstChild("HumanoidRootPart")
            if thrp and (thrp.Position-my.Position).Magnitude<=A.knifeRadius then
                if stab then pcall(function() stab:FireServer() end) end
                if touch then pcall(function() touch:FireServer(thrp) end) end
                break
            end
        end
    end
end))

-- KILL AURA V2
AddConn("KAv2", RunService.Heartbeat:Connect(function()
    if not A.kaV2 or not AmMurderer() then return end
    local c = LocalPlayer.Character; if not c then return end
    local k = c:FindFirstChild("Knife"); if not k then return end
    local ev = k:FindFirstChild("Events"); if not ev then return end
    local stab = ev:FindFirstChild("KnifeStabbed"); local touch = ev:FindFirstChild("HandleTouched")
    if not stab or not touch then return end
    local my = c:FindFirstChild("HumanoidRootPart"); if not my then return end
    local v = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local thrp = p.Character:FindFirstChild("HumanoidRootPart")
            if thrp and (thrp.Position-my.Position).Magnitude<=A.kaV2Dist then v[#v+1]=thrp end
        end
    end
    if #v>0 then
        pcall(function() stab:FireServer() end)
        for _,x in ipairs(v) do pcall(function() touch:FireServer(x) end) end
    end
end))

-- BACKTRACK
local function BtKill()
    if A.btModel then pcall(function() A.btModel:Destroy() end) A.btModel=nil end
    A.btFirst, A.btCount = 1, 0
end
local function BtBuild()
    BtKill()
    local c = LocalPlayer.Character; if not c then return end
    c.Archivable = true
    local ok, m = pcall(function() return c:Clone() end)
    c.Archivable = false
    if not ok or not m then return end
    local rp = {}; for _,o in c:GetDescendants() do if o:IsA("BasePart") then rp[#rp+1]=o end end
    local ci = 0; A.btPairs = {}
    for _,o in m:GetDescendants() do
        if o:IsA("Script") or o:IsA("LocalScript") then pcall(function() o:Destroy() end)
        elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then pcall(function() o:Destroy() end)
        elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") then pcall(function() o:Destroy() end)
        elseif o:IsA("BasePart") then
            o.Anchored=true; o.CanCollide=false; o.CanQuery=false; o.CastShadow=false
            if o.Name=="HumanoidRootPart" then o.Transparency=1
            else o.Material=Enum.Material.ForceField; o.Color=A.btColor; o.Transparency=0 end
            ci=ci+1; A.btPairs[#A.btPairs+1]={o, rp[ci]}
        end
    end
    local h = m:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h:Destroy() end) end
    m.Parent = workspace; A.btModel = m
end
AddConn("Bt", RunService.Heartbeat:Connect(function()
    if not A.btOn then if A.btModel then BtKill() end return end
    local c = LocalPlayer.Character; local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    if not A.btModel then BtBuild(); if not A.btModel then return end end
    if not A.btModel.Parent then A.btModel.Parent = workspace end
    local now = os.clock(); local base = hrp.CFrame
    if A.btCount < A.btCap then A.btCount = A.btCount+1
    else A.btFirst = A.btFirst%A.btCap+1 end
    A.btHist[(A.btFirst+A.btCount-2)%A.btCap+1] = {now, base}
    local ping = 0.15; pcall(function() ping = math.clamp(LocalPlayer:GetNetworkPing()*2, 0.05, 0.6) end)
    local tg = now - ping; local cf = base
    for k=A.btCount,1,-1 do
        local s = A.btHist[(A.btFirst+k-2)%A.btCap+1]
        if s and s[1]<=tg then cf=s[2]; break end
    end
    local inv = hrp.CFrame:Inverse()
    for i=1,#A.btPairs do
        local cp, rp2 = A.btPairs[i][1], A.btPairs[i][2]
        if cp and cp.Parent and rp2 and rp2.Parent then cp.CFrame = cf*(inv*rp2.CFrame) end
    end
end))

-- TRACER
AddConn("Tracer", RunService.Heartbeat:Connect(function()
    if not A.tracerOn or A.tracerConn then return end
    local ok, rem = pcall(function() return ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"):WaitForChild("GunFired") end)
    if not ok or not rem then return end
    A.tracerConn = rem.OnClientEvent:Connect(function(gun, sv, ev)
        if not A.tracerOn then return end
        local c = LocalPlayer.Character
        if not c or not (typeof(gun)=="Instance" and gun:IsDescendantOf(c)) then return end
        local sp = typeof(sv)=="Vector3" and sv or (typeof(sv)=="CFrame" and sv.Position or nil)
        local ep = typeof(ev)=="Vector3" and ev or (typeof(ev)=="CFrame" and ev.Position or nil)
        if not sp or not ep then return end
        local p1 = Instance.new("Part"); p1.Transparency=1; p1.Anchored=true; p1.CanCollide=false; p1.CanQuery=false
        p1.Size=Vector3.new(1,1,1); p1.CFrame=CFrame.new(sp); Instance.new("Attachment",p1); p1.Parent=workspace
        local p2 = Instance.new("Part"); p2.Transparency=1; p2.Anchored=true; p2.CanCollide=false; p2.CanQuery=false
        p2.Size=Vector3.new(1,1,1); p2.CFrame=CFrame.new(ep); Instance.new("Attachment",p2); p2.Parent=workspace
        local b = Instance.new("Beam")
        b.FaceCamera=true; b.Width0=0.25; b.Width1=0.25; b.LightEmission=3; b.LightInfluence=0; b.Brightness=2.5
        b.Texture="rbxassetid://12781800668"; b.TextureSpeed=1.5
        b.Color=ColorSequence.new(A.tracerColor); b.Transparency=NumberSequence.new(0.1)
        b.Attachment0=p1:FindFirstChildOfClass("Attachment"); b.Attachment1=p2:FindFirstChildOfClass("Attachment")
        b.Parent=p1
        task.delay(A.tracerDur, function() pcall(function() TweenService:Create(b,TweenInfo.new(0.2),{Width0=0,Width1=0}):Play() end) end)
        task.delay(A.tracerDur+0.5, function() pcall(function() p1:Destroy() end); pcall(function() p2:Destroy() end) end)
    end)
end))

-- CHINA HAT
local function ChinaKill()
    for _,p in ipairs(A.chinaParts) do if p and p.Parent then pcall(function() p:Destroy() end) end end
    A.chinaParts = {}
end
AddConn("China", RunService.Heartbeat:Connect(function()
    if not A.chinaOn then if #A.chinaParts>0 then ChinaKill() end return end
    local c = LocalPlayer.Character; local h = c and c:FindFirstChild("Head")
    if not h or not h:IsA("BasePart") then return end
    if #A.chinaParts==0 then
        local seg, r, hh = 12, 0.9, 0.3
        for i=1,seg do
            local a1 = (i-1)/seg*math.pi*2
            local a2 = i/seg*math.pi*2
            local mid = (a1+a2)/2
            local x1,z1 = math.cos(a1)*r, math.sin(a1)*r
            local x2,z2 = math.cos(a2)*r, math.sin(a2)*r
            local p = Instance.new("WedgePart")
            p.Anchored=false; p.CanCollide=false; p.CanQuery=false; p.Massless=true
            p.Color=A.chinaCol; p.Material=Enum.Material.SmoothPlastic
            p.Size=Vector3.new(r*0.35, 0.1, hh)
            p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
            p.Parent=h
            local ctr = Vector3.new((x1+x2)/2*0.5, h.Size.Y*0.5+0.3, (z1+z2)/2*0.5)
            p.CFrame = h.CFrame*CFrame.new(ctr)*CFrame.Angles(0, mid, math.rad(-10))
            local wc = Instance.new("WeldConstraint"); wc.Part0=h; wc.Part1=p; wc.Parent=p
            table.insert(A.chinaParts, p)
        end
    else
        for _,p in ipairs(A.chinaParts) do
            if p.Parent and p.Color~=A.chinaCol then p.Color=A.chinaCol end
        end
    end
end))

-- SELF CHAMS
local function SelfChamsKill()
    for pt, old in pairs(A.selfChamsCache) do
        if pt and pt.Parent then pcall(function() pt.Material=old.m; pt.Color=old.c end) end
    end
    A.selfChamsCache = {}
end
AddConn("SelfChams", RunService.Heartbeat:Connect(function()
    if not A.selfChams then if next(A.selfChamsCache) then SelfChamsKill() end return end
    local c = LocalPlayer.Character; if not c then return end
    for _,p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
            if not A.selfChamsCache[p] then A.selfChamsCache[p]={m=p.Material,c=p.Color} end
            if p.Material~=Enum.Material.ForceField then pcall(function() p.Material=Enum.Material.ForceField end) end
            if p.Color~=A.selfChamsCol then pcall(function() p.Color=A.selfChamsCol end) end
        end
    end
end))

-- MOVEMENT GRAPH
local function MovKill()
    for i=1,#A.movLines do pcall(function() A.movLines[i]:Remove() end) end
    for i=1,#A.movShadow do pcall(function() A.movShadow[i]:Remove() end) end
    if A.movText then pcall(function() A.movText:Remove() end) end
    A.movLines={}; A.movShadow={}; A.movText=nil; A.movHist={}
end
AddConn("MovGraph", RunService.RenderStepped:Connect(function()
    if not A.movOn then return end
    local c = LocalPlayer.Character; local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local v = hrp.AssemblyLinearVelocity; local sp = math.sqrt(v.X*v.X+v.Z*v.Z)
    local now = os.clock()
    table.insert(A.movHist, {t=now, v=sp})
    while #A.movHist>200 do table.remove(A.movHist,1) end
    while #A.movHist>0 and now-A.movHist[1].t>3 do table.remove(A.movHist,1) end
    local vp = Camera.ViewportSize
    local x0 = vp.X*0.5-A.movW*0.5
    local y0 = vp.Y*0.5+A.movY-A.movH*0.5
    local maxS = 30
    for _,s in ipairs(A.movHist) do if s.v>maxS then maxS=s.v end end
    maxS = math.max(maxS, 20)
    if not A.movText then A.movText = Drawing.new("Text"); A.movText.Size=14; A.movText.Outline=true end
    A.movText.Text = string.format("%d", math.floor(sp+0.5))
    A.movText.Position = Vector2.new(x0+A.movW+6, y0+A.movH*0.5-8)
    A.movText.Color = A.movCol; A.movText.Visible = true
    if #A.movLines==0 then
        for i=1,200 do
            local sh = Drawing.new("Line"); sh.Color=Color3.new(0,0,0); sh.Thickness=3; sh.Transparency=0.4; sh.Visible=false
            table.insert(A.movShadow, sh)
            local ln = Drawing.new("Line"); ln.Color=A.movCol; ln.Thickness=1.5; ln.Transparency=1; ln.Visible=false
            table.insert(A.movLines, ln)
        end
    end
    for i=1,#A.movLines do
        if i<#A.movHist then
            local a,b = A.movHist[i], A.movHist[i+1]
            local ax = x0+(a.t-(now-3))/3*A.movW
            local ay = y0+A.movH-(a.v/maxS)*A.movH
            local bx = x0+(b.t-(now-3))/3*A.movW
            local by = y0+A.movH-(b.v/maxS)*A.movH
            local ln = A.movLines[i]; local sh = A.movShadow[i]
            ln.From=Vector2.new(ax,ay); ln.To=Vector2.new(bx,by)
            sh.From=ln.From; sh.To=ln.To
            ln.Color=A.movCol; ln.Visible=true; sh.Visible=true
        else A.movLines[i].Visible=false; A.movShadow[i].Visible=false end
    end
end))

-- SOUND REPLACER
do
    local BASE="https://github.com/khenn791/lmao/raw/refs/heads/main/"
    local CACHE="shitaro_sounds/"
    local REM={["mc bow"]=true,["skeet"]=true,["neverlose"]=true,["rust"]=true,["primordial"]=true,["sparkle"]=true,["break"]=true}
    local function pull(n)
        if A.sndPool[n] then return A.sndPool[n] end
        if not REM[n] then return end
        if type(isfile)~="function" or type(writefile)~="function" then return end
        if type(isfolder)~="function" or type(makefolder)~="function" then return end
        pcall(function() if not isfolder(CACHE) then makefolder(CACHE) end end)
        local path = CACHE..n..".ogg"
        if not isfile(path) then
            local url = BASE..(string.gsub(n," ","%%20"))..".ogg"
            local ok,data = pcall(function() return game:HttpGet(url) end)
            if not ok or type(data)~="string" or #data<1024 then return end
            if not pcall(writefile, path, data) then return end
        end
        local cust = getcustomasset or getsynasset
        if type(cust)~="function" then return end
        local ok,id = pcall(cust, path)
        if not ok or type(id)~="string" then return end
        A.sndPool[n]=id; return id
    end
    local function play(kind)
        if not A.sndOn then return end
        local n = kind=="s" and A.sndShf or A.sndMur
        local id = pull(n); if not id then return end
        local now = os.clock()
        if now-(A.sndLast[kind] or 0)<0.15 then return end
        A.sndLast[kind]=now
        local SS = game:GetService("SoundService")
        local s = Instance.new("Sound"); s.SoundId=id; s.Volume=A.sndVol; s.Parent=SS
        s:Play()
        task.delay(8, function() pcall(function() s:Destroy() end) end)
    end
    local function hook(inst,k)
        if A.sndHooked[inst] then return end
        A.sndHooked[inst]=true
        inst.Played:Connect(function() play(k) end)
        inst:GetPropertyChangedSignal("Playing"):Connect(function() if inst.Playing then play(k) end end)
    end
    AddConn("SoundScan", RunService.Heartbeat:Connect(function()
        if not A.sndOn then return end
        local function scan(cont)
            if not cont then return end
            for _,t in ipairs(cont:GetChildren()) do
                if t:IsA("Tool") then
                    local k = t.Name=="Gun" and "s" or (t.Name=="Knife" and "m" or nil)
                    if k then
                        local h = t:FindFirstChild("Handle")
                        if h then
                            for _,c in ipairs(h:GetChildren()) do
                                if c:IsA("Sound") and (c.Name=="GunKill" or c.Name=="Kill") then hook(c,k) end
                            end
                        end
                    end
                end
            end
        end
        scan(LocalPlayer.Character); scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    end))
end

-- ANTI
AddConn("AntiVoid", RunService.Heartbeat:Connect(function()
    if A.antiVoid then pcall(function() workspace.FallenPartsDestroyHeight=-9e9 end)
    else pcall(function() workspace.FallenPartsDestroyHeight=A.antiVoidOrig end) end
end))
AddConn("AntiFling", RunService.Stepped:Connect(function()
    if not A.antiFling then
        for c,e in pairs(A.antiCache) do
            for p,v in pairs(e) do if p and p.Parent then pcall(function() p.CanCollide=v end) end end
        end
        A.antiCache={}
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then local v=hrp.AssemblyLinearVelocity; if v.Magnitude>250 then hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end end
        return
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local c = p.Character
            local e = A.antiCache[c]; if not e then e={}; A.antiCache[c]=e end
            for _,pt in ipairs(c:GetDescendants()) do
                if pt:IsA("BasePart") then
                    if e[pt]==nil then e[pt]=pt.CanCollide end
                    if pt.CanCollide then pt.CanCollide=false end
                end
            end
        end
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then local v=hrp.AssemblyLinearVelocity; if v.Magnitude>250 then hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end end
end))
AddConn("AntiTrap", RunService.Heartbeat:Connect(function()
    if not A.antiTrap then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
    if hum.WalkSpeed<=1 then hum.WalkSpeed=A.antiSpd else A.antiSpd=hum.WalkSpeed end
    if hum.JumpPower<=1 then hum.JumpPower=A.antiJmp else A.antiJmp=hum.JumpPower end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then for _,g in ipairs(pg:GetChildren()) do if g.Name=="TrapGUI" then pcall(function() g:Destroy() end) end end end
end))

-- TOOLS
local function giveTP()
    if not A.tpOn then return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack"); if not bp then return end
    if bp:FindFirstChild("tp") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("tp")) then return end
    local t = Instance.new("Tool"); t.Name="tp"; t.RequiresHandle=false; t.CanBeDropped=false
    t.Parent=bp; A.tpObj=t
    t.Activated:Connect(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local m = LocalPlayer:GetMouse(); local h = m.Hit
        if h then hrp.CFrame = CFrame.new(h.X, h.Y+3, h.Z) end
    end)
end
local function rmTP()
    if A.tpObj then pcall(function() A.tpObj:Destroy() end) A.tpObj=nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local t=bp:FindFirstChild("tp"); if t then pcall(function() t:Destroy() end) end end
    if LocalPlayer.Character then local t=LocalPlayer.Character:FindFirstChild("tp"); if t then pcall(function() t:Destroy() end) end end
end
local function giveFlingTool()
    if not A.flingToolOn then return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack"); if not bp then return end
    if bp:FindFirstChild("fling") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("fling")) then return end
    local t = Instance.new("Tool"); t.Name="fling"; t.RequiresHandle=false; t.CanBeDropped=false
    t.Parent=bp; A.flingObj=t
    t.Activated:Connect(function()
        local m = LocalPlayer:GetMouse(); local tgt = m.Target
        local found
        if tgt then
            local node = tgt
            while node and node~=workspace do
                local p = Players:GetPlayerFromCharacter(node)
                if p and p~=LocalPlayer then found=p; break end
                node = node.Parent
            end
        end
        if not found then return end
        local my = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local thrp = found.Character and found.Character:FindFirstChild("HumanoidRootPart")
        if not my or not thrp then return end
        A.flingActive = (A.flingActive or 0)+1
        local orig = my.CFrame; local t0 = tick()
        task.spawn(function()
            repeat
                if my and my.Parent and thrp and thrp.Parent then
                    my.CFrame = CFrame.new(thrp.Position)*CFrame.Angles(math.rad(math.random(0,360)), math.rad(math.random(0,360)), math.rad(math.random(0,360)))
                    my.AssemblyLinearVelocity = Vector3.new(9e7,9e7,9e7)
                    my.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                end
                task.wait()
            until tick()-t0>2
            if my and my.Parent then
                pcall(function() my.CFrame=orig end)
                my.AssemblyLinearVelocity = Vector3.zero
                my.AssemblyAngularVelocity = Vector3.zero
            end
            A.flingActive = math.max(0, (A.flingActive or 1)-1)
        end)
    end)
end
local function rmFlingTool()
    if A.flingObj then pcall(function() A.flingObj:Destroy() end) A.flingObj=nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local t=bp:FindFirstChild("fling"); if t then pcall(function() t:Destroy() end) end end
    if LocalPlayer.Character then local t=LocalPlayer.Character:FindFirstChild("fling"); if t then pcall(function() t:Destroy() end) end end
end
AddConn("Tools", RunService.Heartbeat:Connect(function()
    if A.tpOn then giveTP() end
    if A.flingToolOn then giveFlingTool() end
end))

-- FAKE POS
do
    local hooked = {}
    local function hook(hrp)
        if hooked[hrp] then return end
        hooked[hrp] = true
        local mt = getrawmetatable(hrp); if not mt then return end
        local oi, on = mt.__index, mt.__newindex
        A.fakeHooked[hrp] = {mt=mt}
        local nm = {}; for k,v in pairs(mt) do nm[k]=v end
        nm.__index = newcclosure(function(self,key)
            if not checkcaller() and key=="CFrame" and A.fakeActive then return A.fakeCF end
            return oi(self,key)
        end)
        nm.__newindex = newcclosure(function(self,key,value)
            if not checkcaller() and A.fakeActive and (key=="CFrame" or key=="Position") then return end
            return on(self,key,value)
        end)
        pcall(function() setrawmetatable(hrp, nm) end)
    end
    AddConn("Fake", RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character; local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        if A.fakeOn then
            if not A.fakeActive then
                A.fakeActive = true; A.fakeCF = hrp.CFrame
                hook(hrp)
                for _,p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then pcall(function() p.LocalTransparencyModifier=0.6 end) end
                end
            end
            A.fakeCF = hrp.CFrame
            local old = hrp.CFrame
            local fake = CFrame.new(math.random(-A.fakeX,A.fakeX), -math.random(0,A.fakeY), math.random(-A.fakeZ,A.fakeZ))
            pcall(function() sethiddenproperty(hrp,"NetworkIsSleeping",false) end)
            hrp.CFrame = fake
            RunService.RenderStepped:Wait()
            hrp.CFrame = old
        else
            if A.fakeActive then
                A.fakeActive = false
                for _,p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function() p.LocalTransparencyModifier=0 end) end
                end
                for t,d in pairs(A.fakeHooked) do if d.mt then pcall(function() setrawmetatable(t,d.mt) end) end end
                A.fakeHooked = {}
            end
        end
    end))
end

-- FLING (для вызова из Troll таба через _G)
local function DoFling(target)
    if not target or not target.Character then return end
    local c = LocalPlayer.Character
    local my = c and c:FindFirstChild("HumanoidRootPart")
    local thrp = target.Character:FindFirstChild("HumanoidRootPart")
    local th = target.Character:FindFirstChildOfClass("Humanoid")
    if not my or not thrp or not th then return end
    if th.Health<=0 or th.Sit then return end
    A.flingActive = (A.flingActive or 0)+1
    local orig = my.CFrame; local t0 = tick()
    task.spawn(function()
        repeat
            if my and my.Parent and thrp and thrp.Parent then
                local v = A.flingBypass and th.MoveDirection*th.WalkSpeed or thrp.AssemblyLinearVelocity
                if v.Magnitude<50 then
                    for _=1,4 do
                        my.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(math.random(0,360)),0,0)
                        my.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                        my.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                        task.wait()
                        my.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,-1.5,0)
                        my.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                        my.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                        task.wait()
                    end
                else
                    my.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,1.5,th.WalkSpeed)*CFrame.Angles(math.rad(90),0,0)
                    my.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                    my.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                    task.wait()
                    my.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,-1.5,-th.WalkSpeed)
                    my.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                    my.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                    task.wait()
                end
            end
        until tick()-t0>2 or not A.flingOn
        if my and my.Parent then
            pcall(function() my.CFrame=orig end)
            my.AssemblyLinearVelocity = Vector3.zero
            my.AssemblyAngularVelocity = Vector3.zero
        end
        A.flingActive = math.max(0, (A.flingActive or 1)-1)
    end)
end
local function GetFlingTargets()
    local out = {}
    if A.flingMode=="specific" then
        local p = A.flingTarget~="" and Players:FindFirstChild(A.flingTarget)
        if p and p~=LocalPlayer then out[1]=p end
    elseif A.flingMode=="murderer" then local m=FindMur(); if m then out[1]=m end
    elseif A.flingMode=="sheriff" then local s=FindShf(); if s then out[1]=s end
    elseif A.flingMode=="all" then
        for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then out[#out+1]=p end end
    end
    return out
end
AddConn("FlingLoop", RunService.Heartbeat:Connect(function()
    if not A.flingOn then return end
    if A.flingActive>0 then return end
    if tick()<A.flingCD then return end
    local tgs = GetFlingTargets(); if #tgs==0 then return end
    local my = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not my then return end
    for _,t in ipairs(tgs) do
        local thrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
        if thrp and (thrp.Position-my.Position).Magnitude<=A.flingRange then
            DoFling(t); A.flingCD = tick()+0.5; break
        end
    end
end))

-- OFF-SCREEN ARROWS
local function arrowSlot(i)
    if A.arrowsPool[i] then return A.arrowsPool[i] end
    local t = Drawing.new("Triangle"); t.Filled=true; t.Thickness=1; t.Transparency=1; t.Visible=false
    A.arrowsPool[i]=t; return t
end
AddConn("Arrows", RunService.RenderStepped:Connect(function()
    if not A.arrowsOn then
        for _,t in pairs(A.arrowsPool) do pcall(function() t.Visible=false end) end
        return
    end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X*0.5, vp.Y*0.5
    local idx = 0
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                idx = idx+1
                local ar = arrowSlot(idx)
                if on and sp.X>0 and sp.X<vp.X and sp.Y>0 and sp.Y<vp.Y then
                    ar.Visible = false
                else
                    local dir = Vector2.new(sp.X-cx, sp.Y-cy)
                    if dir.Magnitude<0.01 then dir=Vector2.new(0,1) end
                    dir = dir.Unit
                    local px = cx+dir.X*A.arrowsDist
                    local py = cy+dir.Y*A.arrowsDist
                    local sz = A.arrowsSize
                    local perp = Vector2.new(-dir.Y, dir.X)
                    local tip = Vector2.new(px+dir.X*sz*0.5, py+dir.Y*sz*0.5)
                    local l = Vector2.new(px-dir.X*sz*0.5+perp.X*sz*0.5, py-dir.Y*sz*0.5+perp.Y*sz*0.5)
                    local r = Vector2.new(px-dir.X*sz*0.5-perp.X*sz*0.5, py-dir.Y*sz*0.5-perp.Y*sz*0.5)
                    ar.PointA=tip; ar.PointB=l; ar.PointC=r
                    local role = GetRole(p)
                    local col = A.arrowsCI
                    if role=="murderer" then col=A.arrowsCM elseif role=="sheriff" then col=A.arrowsCS end
                    ar.Color = col; ar.Visible = true
                end
            end
        end
    end
    for i=idx+1,#A.arrowsPool do pcall(function() A.arrowsPool[i].Visible=false end) end
end))

-- MATERIAL CHAMS
local function MatKill()
    for c,e in pairs(A.matCache) do
        for pt,old in pairs(e) do
            if pt and pt.Parent then pcall(function() pt.Material=old end) end
        end
    end
    A.matCache = {}
end
AddConn("MatChams", RunService.Heartbeat:Connect(function()
    if not A.matChams then if next(A.matCache) then MatKill() end return end
    local mat = Enum.Material.ForceField
    if A.matType=="Flat" then mat=Enum.Material.SmoothPlastic elseif A.matType=="Chromatic" then mat=Enum.Material.Foil end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local c = p.Character
            local e = A.matCache[c]; if not e then e={}; A.matCache[c]=e end
            for _,pt in ipairs(c:GetDescendants()) do
                if pt:IsA("BasePart") then
                    if not e[pt] then e[pt]=pt.Material end
                    if pt.Material~=mat then pcall(function() pt.Material=mat end) end
                end
            end
        end
    end
end))

-- CROSSHAIR
local function CrossKill()
    for i=1,#A.chLines do pcall(function() A.chLines[i]:Remove() end) end
    A.chLines={}
    if A.chConn then pcall(function() A.chConn:Disconnect() end) A.chConn=nil end
end
local function CrossBuild()
    CrossKill()
    for i=1,8 do
        local ln = Drawing.new("Line"); ln.Visible=false
        ln.Color = (i%2==0) and A.chOut or A.chCol
        ln.Thickness = (i%2==0) and (A.chThick+2) or A.chThick
        ln.Transparency = 1; ln.ZIndex = (i%2==0) and 999 or 1000
        A.chLines[i] = ln
    end
    A.chConn = RunService.RenderStepped:Connect(function(dt)
        if not A.chOn then
            for i=1,#A.chLines do A.chLines[i].Visible=false end
            return
        end
        local gun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
        if not gun then for i=1,#A.chLines do A.chLines[i].Visible=false end; return end
        if A.chRot>0 then A.chRotNow = (A.chRotNow+dt*A.chRot*100)%360
        else A.chRotNow = 0 end
        local mp = UserInputService:GetMouseLocation()
        local cx,cy = mp.X, mp.Y
        local rr = math.rad(A.chRotNow)
        local ang = {rr, math.pi/2+rr, math.pi+rr, 3*math.pi/2+rr}
        for i=1,4 do
            local a = ang[i]
            local li = (i-1)*2+1; local oi = li+1
            local sx = cx+A.chGap*math.cos(a); local sy = cy+A.chGap*math.sin(a)
            local ex = cx+(A.chGap+A.chLen)*math.cos(a); local ey = cy+(A.chGap+A.chLen)*math.sin(a)
            local ox1 = cx+(A.chGap-1)*math.cos(a); local oy1 = cy+(A.chGap-1)*math.sin(a)
            local ox2 = cx+(A.chGap+A.chLen+1)*math.cos(a); local oy2 = cy+(A.chGap+A.chLen+1)*math.sin(a)
            local l1, l2 = A.chLines[li], A.chLines[oi]
            if l1 then l1.From=Vector2.new(sx,sy); l1.To=Vector2.new(ex,ey); l1.Visible=true; l1.Color=A.chCol; l1.Thickness=A.chThick end
            if l2 then l2.From=Vector2.new(ox1,oy1); l2.To=Vector2.new(ox2,oy2); l2.Visible=true; l2.Color=A.chOut; l2.Thickness=A.chThick+2 end
        end
    end)
end

-- SHADERS
local shaderP = {
    morning={amb=Color3.fromRGB(10,10,10), br=1.5, ct=7.5, csb=Color3.fromRGB(0,0,0), cst=Color3.fromRGB(200,200,200), exp=0.3},
    midday={amb=Color3.fromRGB(2,2,2), br=3.25, ct=8, csb=Color3.fromRGB(0,0,0), cst=Color3.fromRGB(255,247,237), exp=0.85},
    evening={amb=Color3.fromRGB(2,2,2), br=2.25, ct=16, csb=Color3.fromRGB(0,0,0), cst=Color3.fromRGB(255,247,237), exp=0.65},
    night={amb=Color3.fromRGB(33,33,33), br=3.25, ct=20, csb=Color3.fromRGB(0,0,0), cst=Color3.fromRGB(255,247,237), exp=0.85},
}
local function ApplyShader()
    if not A.shaderOn then return end
    local p = shaderP[A.shaderType] or shaderP.morning
    Lighting.Ambient=p.amb; Lighting.Brightness=p.br; Lighting.ClockTime=p.ct
    Lighting.ColorShift_Bottom=p.csb; Lighting.ColorShift_Top=p.cst
    Lighting.ExposureCompensation=p.exp
end
local function RestoreShader()
    Lighting.Ambient=origLight.Amb; Lighting.Brightness=origLight.Br; Lighting.ClockTime=origLight.CT
    Lighting.ColorShift_Bottom=origLight.CSB; Lighting.ColorShift_Top=origLight.CST
    Lighting.ExposureCompensation=origLight.Exp
end
AddConn("Shader", RunService.Heartbeat:Connect(function() if A.shaderOn then ApplyShader() end end))

-- TIME / FOG
AddConn("Time", RunService.Heartbeat:Connect(function()
    if A.timeOn and Lighting.ClockTime~=A.timeVal then Lighting.ClockTime=A.timeVal end
end))
AddConn("Fog", RunService.Heartbeat:Connect(function()
    if A.fogOn then
        if Lighting.FogColor~=A.fogCol then Lighting.FogColor=A.fogCol end
        if Lighting.FogStart~=A.fogStart then Lighting.FogStart=A.fogStart end
        if Lighting.FogEnd~=A.fogEnd then Lighting.FogEnd=A.fogEnd end
    end
end))

-- WORLD FX
local function FXStop()
    if A.fxConn then pcall(function() A.fxConn:Disconnect() end) A.fxConn=nil end
    if A.fxPart then pcall(function() A.fxPart:Destroy() end) A.fxPart=nil end
    A.fxEmit = nil
end
local function FXStyle()
    local e = A.fxEmit; if not e then return end
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.LightInfluence=0; e.LightEmission=0.4; e.Drag=0
    e.EmissionDirection = Enum.NormalId.Bottom
    e.Rate = A.fxRate; e.Color = ColorSequence.new(A.fxCol)
    if A.fxType=="Snow" then
        e.Lifetime=NumberRange.new(4,6); e.Speed=NumberRange.new(6,12)
        e.Acceleration=Vector3.new(2,-6,1); e.SpreadAngle=Vector2.new(35,35)
        e.Rotation=NumberRange.new(0,360); e.RotSpeed=NumberRange.new(-40,40)
        e.Size=NumberSequence.new(0.55)
        e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(0.8,0.3),NumberSequenceKeypoint.new(1,1)})
    else
        e.Lifetime=NumberRange.new(5,7); e.Speed=NumberRange.new(5,10)
        e.Acceleration=Vector3.new(4,-5,2); e.SpreadAngle=Vector2.new(40,40)
        e.Rotation=NumberRange.new(0,360); e.RotSpeed=NumberRange.new(-80,80)
        e.Size=NumberSequence.new(0.5)
        e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(0.85,0.25),NumberSequenceKeypoint.new(1,1)})
    end
end
local function FXStart()
    FXStop()
    local p = Instance.new("Part")
    p.Name="FH_FX"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
    p.Transparency=1; p.Size=Vector3.new(260,140,260); p.Parent=workspace
    A.fxPart = p
    local e = Instance.new("ParticleEmitter")
    pcall(function() e.Shape=Enum.ParticleEmitterShape.Box; e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume end)
    e.Parent=p; A.fxEmit=e; FXStyle()
    A.fxConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera; if not cam then return end
        local cf = cam.CFrame; local d = cf.LookVector
        local flat = Vector3.new(d.X,0,d.Z)
        if flat.Magnitude<0.05 then flat=Vector3.new(0,0,-1) else flat=flat.Unit end
        p.CFrame = CFrame.new(cf.Position + flat*57 + Vector3.new(0,44,0))
    end)
end
AddConn("FXCheck", RunService.Heartbeat:Connect(function()
    if A.fxOn and not A.fxPart then FXStart() end
    if not A.fxOn and A.fxPart then FXStop() end
end))

-- WORLD AURA
local function AuraKill()
    for i=#A.auraParts,1,-1 do pcall(function() A.auraParts[i]:Destroy() end); A.auraParts[i]=nil end
end
local function AuraLoad(n)
    if A.auraCache[n] then return A.auraCache[n] end
    local id = auraIds[n]; if not id then return end
    local ok, objs = pcall(game.GetObjects, game, "rbxassetid://"..id)
    if ok and objs and objs[1] then A.auraCache[n]=objs[1]; return objs[1] end
end
local function AuraApply()
    AuraKill()
    local c = LocalPlayer.Character; if not c then return end
    local src = AuraLoad(A.auraType); if not src then return end
    local seq = ColorSequence.new(A.auraCol)
    for _, d in ipairs(src:GetDescendants()) do
        if d:IsA("PointLight") then d.Color=A.auraCol
        elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Color=seq end
    end
    local cl = src:Clone()
    for _, pt in ipairs(cl:GetChildren()) do
        local tgt = c:FindFirstChild(pt.Name)
        if tgt and tgt:IsA("BasePart") then
            for _, ch in ipairs(pt:GetChildren()) do
                ch.Parent = tgt; A.auraParts[#A.auraParts+1]=ch
            end
        end
    end
    cl:Destroy()
end
AddConn("AuraChk", RunService.Heartbeat:Connect(function()
    if not A.auraOn then if #A.auraParts>0 then AuraKill() end return end
    local c = LocalPlayer.Character; if not c then return end
    local f = A.auraParts[1]
    if not f or not f.Parent then AuraApply() end
end))

-- LANDING CIRCLE
local function MakeLand(p, n)
    local ref = math.abs(n.Y)>0.98 and Vector3.xAxis or Vector3.yAxis
    local right = n:Cross(ref).Unit
    local front = right:Cross(n).Unit
    local pt = Instance.new("Part")
    pt.Name="FH_Land"; pt.Anchored=true; pt.CanCollide=false; pt.CanQuery=false; pt.CanTouch=false
    pt.CastShadow=false; pt.Transparency=1; pt.Size=Vector3.new(0.3,0.01,0.3)
    pt.CFrame = CFrame.fromMatrix(p + n*0.012, right, n, front)
    pt.Parent = workspace
    local sg = Instance.new("SurfaceGui")
    sg.Face=Enum.NormalId.Top; sg.AlwaysOnTop=true; sg.LightInfluence=0; sg.ZOffset=4; sg.CanvasSize=Vector2.new(1024,1024); sg.Parent=pt
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency=1; img.Size=UDim2.fromScale(1,1)
    img.Image="rbxassetid://7185003058"; img.ImageColor3=A.landCol
    img.ImageTransparency=1-A.landTr; img.ScaleType=Enum.ScaleType.Stretch; img.Parent=sg
    local info = TweenInfo.new(A.landDur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(pt, info, {Size=Vector3.new(6.4,0.01,6.4)}):Play()
    TweenService:Create(img, info, {ImageTransparency=1}):Play()
    game:GetService("Debris"):AddItem(pt, A.landDur+0.2)
end
AddConn("LandChk", RunService.Heartbeat:Connect(function()
    if not A.landOn then
        if A.landConn then pcall(function() A.landConn:Disconnect() end) A.landConn=nil end
        return
    end
    if A.landConn then return end
    local c = LocalPlayer.Character; local hum = c and c:FindFirstChildOfClass("Humanoid"); local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    local air = false
    A.landConn = hum.StateChanged:Connect(function(_, st)
        if st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.Freefall then air=true
        elseif st==Enum.HumanoidStateType.Landed and air then
            air = false
            local prm = RaycastParams.new()
            prm.FilterType = Enum.RaycastFilterType.Exclude
            prm.FilterDescendantsInstances = {c}; prm.IgnoreWater = true
            local hit = workspace:Raycast(hrp.Position+Vector3.new(0,1,0), Vector3.new(0,-16,0), prm)
            if hit then MakeLand(hit.Position, hit.Normal) end
        end
    end)
end))

-- ============================================================
-- _G.FH_* ГЛОБАЛЫ (обработчики для UI из Части 1)
-- ============================================================
_G.FH_SetSilentMode = function(v)
    A.silentMode = (v==L("silent_aim_v1")) and "v1" or "v2"
    if A.silentMode=="v1" then UninstallSilent() else InstallSilent() end
end
_G.FH_SetSilentOn = function(v)
    A.silentOn = v; if v and A.silentMode=="v2" then InstallSilent() end
end
_G.FH_SetAutoShoot = function(v) A.autoShoot = v end
_G.FH_SetAutoDelay = function(v) A.autoDelay = v end
_G.FH_SetKnifeSilent = function(v) A.knifeSilent = v end
_G.FH_SetKnifeLead = function(v) A.knifeLead = v/100 end
_G.FH_SetKnifeAir = function(v) A.knifeAir = v/100 end
_G.FH_SetKnifeOffset = function(v) A.knifeOffset = v/1000 end
_G.FH_SetKnifeInsta = function(v) A.knifeInsta = v end
_G.FH_SetKnifeRadius = function(v) A.knifeRadius = v end
_G.FH_SetKAver = function(v)
    if v==L("kill_aura_v2") then A.kaV2=true; if Options.KillAura then Options.KillAura:SetValue(false) end
    else A.kaV2=false end
end
_G.FH_SetBt = function(v) A.btOn = v; if not v then BtKill() end end
_G.FH_SetBtCol = function(c) A.btColor = c end
_G.FH_SetTrc = function(v) A.tracerOn = v end
_G.FH_SetTrcCol = function(c) A.tracerColor = c end
_G.FH_SetTrcDur = function(v) A.tracerDur = v end
_G.FH_SetChina = function(v) A.chinaOn = v; if not v then ChinaKill() end end
_G.FH_SetChinaCol = function(c) A.chinaCol = c end
_G.FH_SetSelfCh = function(v) A.selfChams = v; if not v then SelfChamsKill() end end
_G.FH_SetSelfChCol = function(c) A.selfChamsCol = c end
_G.FH_SetMov = function(v) A.movOn = v; if not v then MovKill() end end
_G.FH_SetMovCol = function(c) A.movCol = c end
_G.FH_SetMovW = function(v) A.movW = v end
_G.FH_SetMovH = function(v) A.movH = v end
_G.FH_SetMovY = function(v) A.movY = v end
_G.FH_SetArr = function(v) A.arrowsOn = v end
_G.FH_SetArrSz = function(v) A.arrowsSize = v end
_G.FH_SetArrDst = function(v) A.arrowsDist = v end
_G.FH_SetArrCM = function(c) A.arrowsCM = c end
_G.FH_SetArrCS = function(c) A.arrowsCS = c end
_G.FH_SetArrCI = function(c) A.arrowsCI = c end
_G.FH_SetMat = function(v) A.matChams = v; if not v then MatKill() end end
_G.FH_SetMatType = function(v) A.matType = v end
_G.FH_SetCH = function(v) A.chOn = v; if v then CrossBuild() else CrossKill() end end
_G.FH_SetCHG = function(v) A.chGap = v end
_G.FH_SetCHL = function(v) A.chLen = v end
_G.FH_SetCHT = function(v) A.chThick = v end
_G.FH_SetCHR = function(v) A.chRot = v end
_G.FH_SetCHC = function(c) A.chCol = c end
_G.FH_SetCHO = function(c) A.chOut = c end
_G.FH_SetShd = function(v) A.shaderOn = v; if not v then RestoreShader() end end
_G.FH_SetShdT = function(v) A.shaderType = v end
_G.FH_SetTime = function(v) A.timeOn = v; if not v then Lighting.ClockTime=origLight.CT end end
_G.FH_SetTimeVal = function(v) A.timeVal = v end
_G.FH_SetFog = function(v)
    A.fogOn = v
    if not v then Lighting.FogColor=origLight.FC; Lighting.FogStart=origLight.FS; Lighting.FogEnd=origLight.FE end
end
_G.FH_SetFogCol = function(c) A.fogCol = c end
_G.FH_SetFogS = function(v) A.fogStart = v end
_G.FH_SetFogE = function(v) A.fogEnd = v end
_G.FH_SetFX = function(v) A.fxOn = v end
_G.FH_SetFXT = function(v) A.fxType = v; if A.fxEmit then FXStyle() end end
_G.FH_SetFXC = function(c) A.fxCol = c; if A.fxEmit then A.fxEmit.Color=ColorSequence.new(c) end end
_G.FH_SetFXR = function(v) A.fxRate = v; if A.fxEmit then FXStyle() end end
_G.FH_SetAura = function(v) A.auraOn = v; if not v then AuraKill() end end
_G.FH_SetAuraT = function(v) A.auraType = v; if A.auraOn then AuraApply() end end
_G.FH_SetAuraC = function(c)
    A.auraCol = c
    if A.auraOn then
        for _,m in pairs(A.auraCache) do
            local seq = ColorSequence.new(c)
            for _,d in ipairs(m:GetDescendants()) do
                if d:IsA("PointLight") then d.Color=c
                elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Color=seq end
            end
        end
        AuraApply()
    end
end
_G.FH_SetLand = function(v) A.landOn = v end
_G.FH_SetLandC = function(c) A.landCol = c end
_G.FH_SetLandT = function(v) A.landTr = v end
_G.FH_SetLandD = function(v) A.landDur = v end
_G.FH_SetAntiFling = function(v) A.antiFling = v end
_G.FH_SetAntiVoid = function(v) A.antiVoid = v end
_G.FH_SetAntiTrap = function(v) A.antiTrap = v end
_G.FH_SetFakePos = function(v) A.fakeOn = v end
_G.FH_SetFakeX = function(v) A.fakeX = v*1e9 end
_G.FH_SetFakeY = function(v) A.fakeY = v*1e9 end
_G.FH_SetFakeZ = function(v) A.fakeZ = v*1e9 end
_G.FH_SetTPTool = function(v) A.tpOn = v; if not v then rmTP() end end
_G.FH_SetFlingTool = function(v) A.flingToolOn = v; if not v then rmFlingTool() end end
_G.FH_SetFlingBypass = function(v) A.flingBypass = v end
_G.FH_SetSndOn = function(v) A.sndOn = v end
_G.FH_SetSndShf = function(v) A.sndShf = v end
_G.FH_SetSndMur = function(v) A.sndMur = v end
_G.FH_SetSndVol = function(v) A.sndVol = v end

_G.FH_SetFlingMode = function(v)
    if v=="Murderer" then A.flingMode="murderer"
    elseif v=="Sheriff" then A.flingMode="sheriff"
    elseif v=="Specific" then A.flingMode="specific"
    elseif v=="All" then A.flingMode="all" end
end
_G.FH_SetFlingTarget = function(v)
    if type(v)=="table" then v=v[1] end
    A.flingTarget = v or ""
end
_G.FH_SetFlingRange = function(v) A.flingRange = v end
_G.FH_SetFlingOn = function(v) A.flingOn = v end
_G.FH_FlingOnce = function()
    local t = GetFlingTargets()
    if #t==0 then Notify(L("notify_title"),L("fling_none"),2); return end
    DoFling(t[1]); Notify(L("notify_title"), "Fling: "..t[1].Name, 2)
end

-- refresh player list for FlingTarget dropdown
AddConn("FlingAdd", Players.PlayerAdded:Connect(function()
    task.wait(1)
    if not Options.FlingTarget then return end
    local l = {}; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then l[#l+1]=p.Name end end
    table.sort(l)
    pcall(function() Options.FlingTarget:SetValues(l); Options.FlingTarget:Generate() end)
end))
AddConn("FlingRem", Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    if not Options.FlingTarget then return end
    local l = {}; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then l[#l+1]=p.Name end end
    table.sort(l)
    pcall(function() Options.FlingTarget:SetValues(l); Options.FlingTarget:Generate() end)
end))

-- ============================================================
-- LAUNCH
-- ============================================================
task.spawn(function()
    task.wait(0.5)
    Notify(L("notify_title"), L("loaded"), 6)
end)

logInfo("Addon backends загружены")
logInfo("Скрипт полностью загружен — ЗАПУЩЕН УСПЕШНО")
