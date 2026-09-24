-- ============================================================
-- FORTNIHUB v14.2.0 — MM2 FULL EXPLOIT HUB — by HOTI
-- AWP v3 (anchor + CFrame update)
-- Localization full
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

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local THEME = Color3.fromRGB(138, 92, 246)
local THEME_LIGHT = Color3.fromRGB(178, 152, 255)
local THEME_OK = Color3.fromRGB(80, 240, 120)
local THEME_WARN = Color3.fromRGB(255, 200, 80)
local THEME_ERR = Color3.fromRGB(255, 80, 80)
local VERSION = "14.2.0"

local AWP_ROTATION = Vector3.new(90, 0, 0)
local AWP_OFFSET   = Vector3.new(0, 0, 0)
local AWP_SCALE    = 1.0

pcall(function() if setfpscap then setfpscap(0) end end)

local MY_GUI_NAMES = {
    ["FH_MobileUI"]=true, ["FH_TopHUDGui"]=true, ["FH_OpenScriptGui"]=true,
    ["FH_CoordGui"]=true, ["FortniHubLoadingGui"]=true,
    ["Fluent"]=true, ["FH_BindPopup"]=true,
}
local function CleanupOldGuis()
    local parents = {CoreGui}
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h and h ~= CoreGui then table.insert(parents, h) end
    end
    for _, parent in ipairs(parents) do
        for _, gui in ipairs(parent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local n = gui.Name
                local shouldDestroy = MY_GUI_NAMES[n] or false
                if n == "ScreenGui" or n == "Fluent" then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("TextLabel") and string.find(tostring(d.Text or ""), "FortniHub") then
                            shouldDestroy = true; break
                        end
                    end
                end
                if shouldDestroy then pcall(function() gui:Destroy() end) end
            end
        end
    end
end
CleanupOldGuis()
task.wait(0.3)

local CurrentLang = "ru"
if _G.FortniHubLang then CurrentLang = _G.FortniHubLang end
if readfile and isfile then
    pcall(function()
        if isfile("FortniHubLang.txt") then
            local s = readfile("FortniHubLang.txt")
            if s == "ru" or s == "en" then CurrentLang = s; _G.FortniHubLang = s end
        end
    end)
end

local L_ru = {
    tab_combat="Бой", tab_movement="Движение", tab_farm="Автофарм", tab_visual="Визуал",
    tab_tp="Телепорт", tab_troll="Троллинг", tab_utility="Утилиты",
    tab_mobile="Мобильный", tab_binds="Клавиши", tab_settings="Настройки",
    kill_aura="Килл Аура", radius="Радиус", auto_grab_gun="Авто-подбор пистолета",
    speed_hack="Скорость", walk_speed="Скорость ходьбы", fly="Полёт", fly_speed="Скорость полёта",
    speed_glitch="Спидглитч", glitch_speed="Скорость глитча",
    bunny_hop="Банихоп", max_speed="Макс. скорость", accel_time="Время разгона (сек)",
    noclip="Noclip", spinbot="Спинбот", spin_speed="Скорость вращения",
    inf_jump="Бесконечный прыжок", jump_power="Сила прыжка",
    freeze="Заморозка (с движением)", freeze_speed="Скорость полёта (Freeze)",
    wall_bounce="Отскок от стен", wall_force="Сила отскока",
    autofarm="Автофарм", farm_speed="Скорость фарма",
    avoid_murderer="Избегать маньяка", auto_kill_aura="Авто-килл-аура при 40",
    autocollect="Автосбор рядом", player_esp="ESP игроков", name_esp="ESP имён",
    dist_esp="ESP дистанции", gun_esp="ESP пистолета", coin_esp="ESP монет",
    fullbright="Fullbright", fov="FOV", stretch="Aspect",
    fps_cap="Лимит FPS", tp_lobby="ТП в Лобби", tp_map="ТП на Карту",
    tp_murderer="ТП к Убийце", tp_sheriff="ТП к Шерифу", tp_player="ТП к игроку",
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
    quiet_shot_aim_simple="Simple (текущий)",
    quiet_shot_aim_advanced="Advanced (ping + velocity)",

    -- addon
    silent_aim="Silent Aim (хук)", silent_aim_v1="v1 (FireServer)", silent_aim_v2="v2 (Hook)",
    silent_aim_mode="Режим Silent Aim", auto_shoot="Авто-выстрел", auto_shoot_delay="Задержка (мс)",
    force_shoot="Force Shoot (стены)", force_stand_off="Отступ (студы)",
    knife_silent="Silent Throw", knife_insta="Insta Kill", knife_radius="Радиус попадания",
    knife_lead="Лид (%)", knife_air="Лифт в воздухе (%)", knife_offset="Оффсет (мс)",
    knife_speed="Скорость полёта", knife_pred="Предикт ножа",
    kill_aura_v1="KillAura v1 (старая)", kill_aura_v2="KillAura v2 (KnifeStabbed)",
    kill_aura_version="Версия KillAura",
    autofarm_version="Версия автофарма", autofarm_v1="v1 (обычный)", autofarm_v2="v2 (Down режим)",
    farm_down_depth="Глубина Down (студы)",
    backtrack="Backtrack", backtrack_color="Цвет бэктрека",
    tracer="Bullet Tracer", tracer_color="Цвет трассера", tracer_duration="Длительность",
    sound_replacer="Звук убийства", sound_sheriff="Убийство шерифом",
    sound_murder="Убийство маньяком", sound_volume="Громкость",
    anti_fling="Anti-Fling", anti_void="Anti-Void", anti_trap="Anti-Trap",
    tp_tool="TP Tool", fling_tool="Fling Tool", fling_bypass="Fling Bypass",
    fake_pos="Fake Position", fake_pos_x="Разброс X", fake_pos_y="Разброс Y", fake_pos_z="Разброс Z",
    china_hat="China Hat", china_hat_color="Цвет China Hat",
    self_chams="Self Chams", self_chams_color="Цвет Self Chams",
    mov_graph="Movement Graph", mov_graph_color="Цвет графика",
    mov_graph_width="Ширина", mov_graph_height="Высота", mov_graph_y="Y",

    -- новые визуалы
    off_arrows="Стрелки к игрокам", off_arrows_size="Размер стрелок", off_arrows_dist="Дистанция стрелок",
    mat_chams="Material Chams", mat_chams_type="Тип Chams", mat_chams_vis="Видимый цвет", mat_chams_occ="За стеной",
    crosshair="Кастомный прицел", crosshair_hide="Скрыть игровой",
    crosshair_gap="Зазор", crosshair_len="Длина", crosshair_thick="Толщина", crosshair_color="Цвет прицела",
    crosshair_outline="Обводка прицела", crosshair_rotate="Скорость вращения",
    shader="Шейдеры", shader_preset="Пресет шейдера",
    time_changer="Время суток", time_value="Время",
    custom_fog="Туман", fog_color="Цвет тумана", fog_start="Начало", fog_end="Конец",
    world_fx="Мир. эффекты", world_fx_type="Тип", world_fx_color="Цвет", world_fx_rate="Интенсивность",
    world_aura="Аура", world_aura_type="Тип ауры", world_aura_color="Цвет ауры",
    land_circle="Круг падения", land_circle_color="Цвет круга", land_circle_dur="Длительность",
}
local L_en = {}
for k, _ in pairs(L_ru) do L_en[k] = k end
local function L(key)
    if CurrentLang == "ru" then return L_ru[key] or L_en[key] or key end
    return L_en[key] or key
end

local Connections = {}
local MobileButtons = {}
local CachedGuns = {}
local CachedCoins = {}
local NameESPDrawing = {}
local DistESPDrawing = {}
local flyKeys = {W=false,A=false,S=false,D=false,UP=false,DOWN=false}
local BindList = {}
local BindKeyCache = {}
local BindTimeCache = {}
local QuietShotBind = Enum.KeyCode.E
local Window, Options, Tabs = nil, nil, {}
local CoordMode = false
local VoteRunning = false
local FarmBlockedStates = {}
local FarmLastCoinTime = 0
local FarmAvoidMurderer = false
local FarmAutoKillAura = false
local IsFrozen = false
local FarmRunning = false
local FarmAnchored = false
local FarmLastPos = nil
local FarmStuck = 0
local RecentlyTouchedCoins = {}
local FarmTimeoutStart = tick()
local FarmLastCoinCount = 0
local SgActive = false
local LastMoveTime = 0
local WallBounceEnabled = false
local FPSCap = 0
local CustomJumpPower = false
local MobileButtonsLocked = false
local AWPCreatedParts = {}
local OriginalHandleTransparency = nil
local ModuleNameToTitle = {}
local BindPopupActive = false
local BindPopupTarget = nil
local CachedLocalHRP = nil
local CachedLocalHum = nil
local CharCacheTime = 0
local GrabFailedThisRound = false
local IsGrabbing = false
local TouchFlingLoaded = false
local ShootButtonRef = nil

local OriginalLighting = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    FOV = Camera.FieldOfView,
}

local function logInfo(msg) print("[FortniHub][INFO] " .. tostring(msg)) end
local function logWarn(msg) print("[FortniHub][WARN] " .. tostring(msg)) end
local function logErr(msg) print("[FortniHub][ERR] " .. tostring(msg)) end
logInfo("Скрипт запущен, версия " .. VERSION)

local function AddConnection(name, conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name] = conn
end

local function RefreshCharCache()
    if tick() - CharCacheTime < 0.5 then return end
    CharCacheTime = tick()
    if LocalPlayer.Character then
        CachedLocalHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        CachedLocalHum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    else
        CachedLocalHRP = nil; CachedLocalHum = nil
    end
end

local function GetHRP(p)
    if p and p ~= LocalPlayer then
        if p.Character then return p.Character:FindFirstChild("HumanoidRootPart") end
        return nil
    end
    RefreshCharCache(); return CachedLocalHRP
end
local function GetHum() RefreshCharCache(); return CachedLocalHum end

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
local function GetRoleText(r)
    if r=="murderer" then return L("role_murderer") end
    if r=="sheriff" then return L("role_sheriff") end
    if r=="lobby" then return L("role_lobby") end
    return L("role_innocent")
end
local function GetRoleColor(r)
    if r=="murderer" then return Color3.fromRGB(255,60,60) end
    if r=="sheriff" then return Color3.fromRGB(60,140,255) end
    if r=="lobby" then return Color3.fromRGB(180,180,180) end
    return Color3.fromRGB(60,220,100)
end

local function GetCoinCountSafe()
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
    local d,ds,sp = false,nil,nil
    gui.InputBegan:Connect(function(i)
        if cond and not cond() then return end
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            d=true; ds=i.Position; sp=gui.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not d then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local delta=i.Position-ds
            gui.Position=UDim2.new(sp.X.Scale,sp.X.Offset+delta.X,sp.Y.Scale,sp.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then d=false end
    end)
end

local function GetContainers()
    local list={CoreGui}
    if gethui then local ok,h=pcall(gethui); if ok and h and h~=CoreGui then table.insert(list,h) end end
    pcall(function() if LocalPlayer.PlayerGui then table.insert(list,LocalPlayer.PlayerGui) end end)
    return list
end
local function ClickExternalButton(keywords)
    for _,cont in ipairs(GetContainers()) do
        for _,gui in ipairs(cont:GetChildren()) do
            if gui:IsA("ScreenGui") and not MY_GUI_NAMES[gui.Name] then
                for _,d in ipairs(gui:GetDescendants()) do
                    if d:IsA("TextButton") then
                        local txt=""; pcall(function() txt=tostring(d.Text or "") end)
                        local t=txt:lower():gsub("%s+","")
                        for _,kw in ipairs(keywords) do
                            local kk=kw:lower():gsub("%s+","")
                            if t==kk or t:find(kk) then
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

-- LOADING
local LoadingGui=Instance.new("ScreenGui")
LoadingGui.Name="FortniHubLoadingGui"; LoadingGui.ResetOnSpawn=false; LoadingGui.Parent=CoreGui
local LF=Instance.new("Frame"); LF.Size=UDim2.fromOffset(400,200); LF.Position=UDim2.new(0.5,-200,0.5,-100)
LF.BackgroundColor3=Color3.fromRGB(20,20,20); LF.BorderSizePixel=0; LF.Parent=LoadingGui
Instance.new("UICorner",LF).CornerRadius=UDim.new(0,10)
local LFS=Instance.new("UIStroke",LF); LFS.Color=THEME; LFS.Thickness=2
local LFT=Instance.new("TextLabel",LF); LFT.Size=UDim2.new(1,0,0,30); LFT.Position=UDim2.new(0,0,0,25)
LFT.BackgroundTransparency=1; LFT.Font=Enum.Font.GothamBold; LFT.Text="FortniHub v"..VERSION
LFT.TextColor3=Color3.new(1,1,1); LFT.TextSize=22
local LFL=Instance.new("TextLabel",LF); LFL.Size=UDim2.new(1,0,0,20); LFL.Position=UDim2.new(0,0,0,52)
LFL.BackgroundTransparency=1; LFL.Font=Enum.Font.Gotham; LFL.Text="by HOTI"
LFL.TextColor3=THEME_LIGHT; LFL.TextSize=14
local LSS=Instance.new("TextLabel",LF); LSS.Size=UDim2.new(1,0,0,18); LSS.Position=UDim2.new(0,0,0,76)
LSS.BackgroundTransparency=1; LSS.Font=Enum.Font.Gotham; LSS.Text="Загрузка..."
LSS.TextColor3=Color3.fromRGB(180,180,200); LSS.TextSize=12
local LBG=Instance.new("Frame",LF); LBG.Size=UDim2.new(0.8,0,0,16); LBG.Position=UDim2.new(0.1,0,0.72,0)
LBG.BackgroundColor3=Color3.fromRGB(35,35,35); LBG.BorderSizePixel=0
Instance.new("UICorner",LBG).CornerRadius=UDim.new(0,8)
local LBF=Instance.new("Frame",LBG); LBF.Size=UDim2.new(0,0,1,0); LBF.BackgroundColor3=THEME; LBF.BorderSizePixel=0
Instance.new("UICorner",LBF).CornerRadius=UDim.new(0,8)
local tt0=os.clock()
while os.clock()-tt0<1.2 do
    local a=(os.clock()-tt0)/1.2
    LBF.Size=UDim2.new(a,0,1,0)
    LSS.Text="Загрузка "..math.floor(a*100).."%"
    task.wait()
end
task.wait(0.1); LoadingGui:Destroy()

-- SAFE LOADER
local function safeHttpGet(url, name)
    if type(url) ~= "string" or url == "" then return nil end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not ok then return nil end
    if type(body) ~= "string" then return nil end
    if #body < 32 then return nil end
    local head = body:sub(1, 200):lower()
    if head:find("<!doctype") or head:find("<html") or head:find("not found") then return nil end
    return body
end
local function safeLoadstring(body, name)
    if type(body) ~= "string" or #body == 0 then return nil end
    local fn, err = loadstring(body, "@" .. tostring(name))
    if type(fn) ~= "function" then
        logWarn("safeLoadstring "..tostring(name)..": "..tostring(err))
        return nil
    end
    return fn
end
local function safeRun(fn, name)
    if type(fn) ~= "function" then return nil end
    local ok, res = pcall(fn)
    if not ok then
        logWarn("safeRun "..tostring(name)..": "..tostring(res))
        return nil
    end
    return res
end

logInfo("Загружаю Fluent UI...")
local Fluent, SaveManager, InterfaceManager
local fluentUrls = {
    "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/src/init.lua",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/src/init.lua",
}
local fluentBody = nil
for _, url in ipairs(fluentUrls) do
    local body = safeHttpGet(url, "Fluent")
    if body and safeLoadstring(body, "Fluent") then fluentBody = body; break end
end
if not fluentBody then logErr("Не удалось загрузить Fluent UI!"); return end
Fluent = safeRun(safeLoadstring(fluentBody, "Fluent"), "Fluent")
if type(Fluent) ~= "table" then logErr("Fluent не таблица"); return end
logInfo("Fluent загружен")

do
    local body = safeHttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua", "SaveManager")
    local fn = body and safeLoadstring(body, "SaveManager")
    if fn then SaveManager = safeRun(fn, "SaveManager") end
end
do
    local body = safeHttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua", "InterfaceManager")
    local fn = body and safeLoadstring(body, "InterfaceManager")
    if fn then InterfaceManager = safeRun(fn, "InterfaceManager") end
end

local lastNotify={}
local function Notify(t,c,d)
    local k=tostring(t).."|"..tostring(c)
    if lastNotify[k] and (tick()-lastNotify[k])<0.6 then return end
    lastNotify[k]=tick()
    pcall(function()
        if Fluent and Fluent.Notify then Fluent:Notify({Title=t,Content=c,Duration=d or 3}) end
    end)
end

-- HUD
local TopHUDGui=Instance.new("ScreenGui")
TopHUDGui.Name="FH_TopHUDGui"; TopHUDGui.ResetOnSpawn=false; TopHUDGui.Enabled=false; TopHUDGui.Parent=CoreGui
local HUDF=Instance.new("Frame"); HUDF.Size=UDim2.fromOffset(520,38); HUDF.Position=UDim2.new(0.5,-260,0,12)
HUDF.BackgroundColor3=Color3.fromRGB(18,16,28); HUDF.BackgroundTransparency=0.05; HUDF.BorderSizePixel=0; HUDF.Active=true; HUDF.Parent=TopHUDGui
Instance.new("UICorner",HUDF).CornerRadius=UDim.new(1,0)
local HSD=Instance.new("UIStroke",HUDF); HSD.Color=THEME; HSD.Thickness=1.5; HSD.Transparency=0.3
MakeDraggable(HUDF)
local function mkLabel(parent,sz,pos,txt,col,ts,font)
    local l=Instance.new("TextLabel",parent)
    l.Size=sz; l.Position=pos; l.BackgroundTransparency=1
    l.Font=font or Enum.Font.GothamMedium; l.Text=txt; l.TextColor3=col; l.TextSize=ts
    l.TextXAlignment=Enum.TextXAlignment.Center
    return l
end
local HUDLogo=mkLabel(HUDF,UDim2.fromOffset(60,38),UDim2.fromOffset(4,0),"FH",THEME,18,Enum.Font.GothamBlack)
local FPSLabel=mkLabel(HUDF,UDim2.fromOffset(120,38),UDim2.fromOffset(64,0),"FPS 60",Color3.fromRGB(220,220,240),13)
local PingLabel=mkLabel(HUDF,UDim2.fromOffset(110,38),UDim2.fromOffset(184,0),"PING 0ms",Color3.fromRGB(220,220,240),13)
local RoundLabel=mkLabel(HUDF,UDim2.fromOffset(120,38),UDim2.fromOffset(294,0),L("round_time").." --:--",THEME_LIGHT,13,Enum.Font.GothamBold)
local ExecLabel=mkLabel(HUDF,UDim2.fromOffset(50,38),UDim2.fromOffset(464,0),"v"..VERSION,THEME_LIGHT,11,Enum.Font.GothamBold)

local CoordGui=Instance.new("ScreenGui")
CoordGui.Name="FH_CoordGui"; CoordGui.ResetOnSpawn=false; CoordGui.Enabled=false; CoordGui.DisplayOrder=100; CoordGui.Parent=CoreGui
local CoordLabel=Instance.new("TextLabel",CoordGui)
CoordLabel.Size=UDim2.fromOffset(400,30); CoordLabel.Position=UDim2.new(1,-420,0,60)
CoordLabel.BackgroundTransparency=1; CoordLabel.Font=Enum.Font.GothamBold
CoordLabel.Text="X: 0 Y: 0 Z: 0"; CoordLabel.TextColor3=Color3.fromRGB(0,255,100); CoordLabel.TextSize=24
CoordLabel.TextXAlignment=Enum.TextXAlignment.Right; CoordLabel.TextStrokeTransparency=0
CoordLabel.TextStrokeColor3=Color3.new(0,0,0)

local ESPFolder=Instance.new("Folder",CoreGui); ESPFolder.Name="FH_ESPFolder"

-- MOBILE
local MobileUI=Instance.new("ScreenGui")
MobileUI.Name="FH_MobileUI"; MobileUI.ResetOnSpawn=false; MobileUI.Parent=CoreGui
local TouchFlyFrame=Instance.new("Frame")
TouchFlyFrame.Size=UDim2.fromOffset(180,120); TouchFlyFrame.Position=UDim2.new(0.7,0,0.6,0)
TouchFlyFrame.BackgroundTransparency=0.6; TouchFlyFrame.BackgroundColor3=Color3.new(0,0,0); TouchFlyFrame.Visible=false
TouchFlyFrame.Parent=MobileUI
local function CreateFlyBtn(name,text,px,py,sx,sy)
    local b=Instance.new("TextButton")
    b.Name=name; b.Text=text; b.Size=UDim2.new(sx,0,sy,0); b.Position=UDim2.new(px,0,py,0)
    b.BackgroundColor3=Color3.fromRGB(40,40,40); b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold
    b.Parent=TouchFlyFrame
    b.MouseButton1Down:Connect(function() flyKeys[name]=true end)
    b.MouseButton1Up:Connect(function() flyKeys[name]=false end)
    b.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            flyKeys[name]=false
        end
    end)
end
CreateFlyBtn("W","W",0.35,0.05,0.3,0.28)
CreateFlyBtn("S","S",0.35,0.65,0.3,0.28)
CreateFlyBtn("A","A",0.02,0.35,0.3,0.28)
CreateFlyBtn("D","D",0.68,0.35,0.3,0.28)
CreateFlyBtn("UP","^",0.02,0.05,0.28,0.28)
CreateFlyBtn("DOWN","v",0.68,0.65,0.28,0.28)
MakeDraggable(TouchFlyFrame)

local ShootBtn=Instance.new("TextButton")
ShootBtn.Name="FH_ShootBtn"
ShootBtn.Size=UDim2.fromOffset(68,68)
ShootBtn.Position=UDim2.new(1,-84,1,-160)
ShootBtn.BackgroundColor3=Color3.fromRGB(180,40,40)
ShootBtn.BackgroundTransparency=0.15
ShootBtn.Text=L("shoot_btn")
ShootBtn.TextColor3=Color3.new(1,1,1)
ShootBtn.Font=Enum.Font.GothamBlack
ShootBtn.TextSize=13
ShootBtn.Active=true
ShootBtn.Visible=false
ShootBtn.Parent=MobileUI
Instance.new("UICorner",ShootBtn).CornerRadius=UDim.new(1,0)
local SBStroke=Instance.new("UIStroke",ShootBtn)
SBStroke.Color=THEME; SBStroke.Thickness=2
MakeDraggable(ShootBtn)
ShootButtonRef=ShootBtn

local OpenScriptGui=Instance.new("ScreenGui")
OpenScriptGui.Name="FH_OpenScriptGui"; OpenScriptGui.ResetOnSpawn=false; OpenScriptGui.DisplayOrder=999; OpenScriptGui.Parent=CoreGui
local OpenBar=Instance.new("Frame")
OpenBar.Size=UDim2.fromOffset(260,46); OpenBar.Position=UDim2.new(0.5,-130,0,20)
OpenBar.BackgroundColor3=Color3.fromRGB(15,15,18); OpenBar.BorderSizePixel=0; OpenBar.Parent=OpenScriptGui
Instance.new("UICorner",OpenBar).CornerRadius=UDim.new(1,0)
local OBS=Instance.new("UIStroke",OpenBar); OBS.Color=THEME; OBS.Thickness=2
local MI=Instance.new("TextLabel",OpenBar); MI.Size=UDim2.fromOffset(40,46); MI.Position=UDim2.fromOffset(12,0)
MI.BackgroundTransparency=1; MI.Text="="; MI.TextColor3=THEME; MI.TextSize=26; MI.Font=Enum.Font.GothamBold
local DV=Instance.new("Frame",OpenBar); DV.Size=UDim2.fromOffset(1,26); DV.Position=UDim2.new(0,55,0.5,-13)
DV.BackgroundColor3=Color3.fromRGB(90,90,90); DV.BorderSizePixel=0
local FI=Instance.new("TextLabel",OpenBar); FI.Size=UDim2.fromOffset(40,46); FI.Position=UDim2.fromOffset(62,0)
FI.BackgroundTransparency=1; FI.Text="FH"; FI.TextColor3=THEME; FI.TextSize=18; FI.Font=Enum.Font.GothamBlack
local OpenBtn=Instance.new("TextButton",OpenBar)
OpenBtn.Size=UDim2.new(1,-115,1,0); OpenBtn.Position=UDim2.fromOffset(105,0)
OpenBtn.BackgroundTransparency=1; OpenBtn.Text="Open Script"; OpenBtn.TextColor3=Color3.new(1,1,1)
OpenBtn.TextSize=17; OpenBtn.Font=Enum.Font.GothamBold; OpenBtn.TextXAlignment=Enum.TextXAlignment.Left
MakeDraggable(OpenBar)

for _,v in ipairs(Workspace:GetDescendants()) do
    if v.Name=="GunDrop" then table.insert(CachedGuns,v) end
    if v.Name=="Coin_Server" or v.Name=="Coin" then table.insert(CachedCoins,v) end
end
AddConnection("CacheAdded",Workspace.DescendantAdded:Connect(function(v)
    if v.Name=="GunDrop" then table.insert(CachedGuns,v) end
    if v.Name=="Coin_Server" or v.Name=="Coin" then table.insert(CachedCoins,v) end
end))
AddConnection("CacheRemoved",Workspace.DescendantRemoving:Connect(function(v)
    if v.Name=="GunDrop" then local i=table.find(CachedGuns,v); if i then table.remove(CachedGuns,i) end end
    if v.Name=="Coin_Server" or v.Name=="Coin" then local i=table.find(CachedCoins,v); if i then table.remove(CachedCoins,i) end end
end))

local function CreateTouchButton(modName)
    if MobileButtons[modName] then return end
    if modName == "ShootBtn" then
        local btn=Instance.new("TextButton")
        btn.Name="TouchBtn_ShootBtn"
        btn.Size=UDim2.fromOffset(100,100)
        btn.Position=UDim2.new(1,-120,1,-200)
        btn.BackgroundColor3=Color3.fromRGB(180,40,40)
        btn.BackgroundTransparency=0.15
        btn.Text="SHOOT"
        btn.TextColor3=Color3.new(1,1,1)
        btn.Font=Enum.Font.GothamBlack
        btn.TextSize=15
        btn.Active=true
        btn.Parent=MobileUI
        Instance.new("UICorner",btn).CornerRadius=UDim.new(1,0)
        local st=Instance.new("UIStroke",btn); st.Color=THEME; st.Thickness=2.5
        MakeDraggable(btn,function() return not MobileButtonsLocked end)
        btn.MouseButton1Click:Connect(function() DoQuietShot() end)
        MobileButtons[modName]=btn
        return
    end
    local opt=Options[modName]; if not opt then return end
    local btn=Instance.new("TextButton")
    btn.Name="TouchBtn_"..modName
    btn.Size=UDim2.fromOffset(130,45)
    btn.Position=UDim2.new(0.5,-65+math.random(-30,30),0.5,-22+math.random(-30,30))
    btn.BackgroundColor3=opt.Value and Color3.fromRGB(0,150,80) or Color3.fromRGB(30,30,30)
    btn.Text=modName; btn.TextColor3=Color3.new(1,1,1); btn.Font=Enum.Font.GothamBold; btn.TextSize=13
    btn.Active=true; btn.Parent=MobileUI
    local st=Instance.new("UIStroke",btn); st.Color=THEME; st.Thickness=2
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    MakeDraggable(btn,function() return not MobileButtonsLocked end)
    opt:OnChanged(function(v)
        if MobileButtons[modName] then
            btn.BackgroundColor3=v and Color3.fromRGB(0,150,80) or Color3.fromRGB(30,30,30)
        end
    end)
    local tap=0
    btn.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then tap=tick() end
    end)
    btn.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
            if tick()-tap>0.6 then
                if not MobileButtonsLocked then btn:Destroy(); MobileButtons[modName]=nil end
            else
                if modName~="QuietShot" and Options[modName] then
                    Options[modName]:SetValue(not Options[modName].Value)
                end
            end
        end
    end)
    MobileButtons[modName]=btn
end

local function TeleportAndKill(tp)
    local char=LocalPlayer.Character; local tChar=tp.Character
    if not char or not tChar then return false end
    local myHRP=char:FindFirstChild("HumanoidRootPart"); local tHRP=tChar:FindFirstChild("HumanoidRootPart")
    local knife=char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
    if not (myHRP and tHRP and knife) then return false end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum and knife.Parent~=char then hum:EquipTool(knife); task.wait(0.05) end
    local orig=myHRP.CFrame
    myHRP.CFrame=tHRP.CFrame*CFrame.new(0,0,1.5)
    task.wait(0.1)
    pcall(function() VirtualUser:ClickButton1(Vector2.new(0,0)) end)
    pcall(function()
        local s=knife:FindFirstChild("Stab") or knife:FindFirstChild("Slash") or knife:FindFirstChild("Hit")
        if s then
            if s:IsA("RemoteEvent") then s:FireServer()
            elseif s:IsA("RemoteFunction") then s:InvokeServer() end
        end
    end)
    task.wait(0.15)
    if myHRP and myHRP.Parent then myHRP.CFrame=orig end
    return true
end

-- QUIET SHOT
local QuietAim = { tracks = {}, RING = 16, lastShot = 0 }
local function QuietGetTrack(p)
    local t = QuietAim.tracks[p]
    if not t then
        t = { samples = {}, n = 0, i = 0, vel = Vector3.zero, ready = false, lastPos = nil, lastTime = 0, gap = 0.05 }
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
local function QuietFitVelocity(t)
    if t.n < 3 then return nil, nil end
    local newestT = select(1, QuietGetSample(t, 0))
    if not newestT then return nil, nil end
    local used, sumD = 0, 0
    for k = 0, t.n - 1 do
        local st = select(1, QuietGetSample(t, k))
        if not st then break end
        local d = st - newestT
        if d < -0.25 then break end
        used = used + 1
        sumD = sumD + d
    end
    if used < 3 then return nil, nil end
    local meanD = sumD / used
    local num, den = Vector3.zero, 0
    for k = 0, used - 1 do
        local st, sp = QuietGetSample(t, k)
        if not st or not sp then break end
        local d = (st - newestT) - meanD
        num = num + sp * d
        den = den + d * d
    end
    if den < 1e-8 then return nil, nil end
    return num / den, -meanD
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
            t.gap = t.gap * 0.8 + (now - t.lastTime) * 0.2
            QuietPushSample(t, pos, now)
            local v = QuietFitVelocity(t)
            if v then t.vel = v; t.ready = true end
        end
    end
    t.lastPos = pos
    t.lastTime = now
end
local function QuietShot_Simple(shootPos)
    local myHRP = GetHRP()
    if myHRP then
        local flat = Vector3.new(shootPos.X, myHRP.Position.Y, shootPos.Z)
        if (flat - myHRP.Position).Magnitude > 0.1 then
            pcall(function() myHRP.CFrame = CFrame.new(myHRP.Position, flat) end)
        end
    end
    pcall(function() Camera.CFrame = CFrame.new(Camera.CFrame.Position, shootPos) end)
end
local function QuietShot_Advanced(target, thrp)
    local t = QuietAim.tracks[target]
    local myHRP = GetHRP()
    if not myHRP then return thrp.Position end
    local ping = 0
    pcall(function() ping = LocalPlayer:GetNetworkPing() * 2 end)
    if ping <= 0 then ping = 0.05 end
    ping = math.clamp(ping, 0.02, 0.35)
    local age = 0
    if t and t.lastTime then age = math.clamp(os.clock() - t.lastTime, 0, 0.15) end
    local lead = ping + age
    local base = thrp.Position
    local vel = (t and t.ready and t.vel) or thrp.AssemblyLinearVelocity
    local velH = Vector3.new(vel.X, 0, vel.Z)
    local targetPos = base + velH * lead
    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    local inAir = false
    if hum then
        local st = hum:GetState()
        inAir = (st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall)
    end
    if inAir and math.abs(vel.Y) > 0.5 then
        local g = workspace.Gravity
        targetPos = Vector3.new(targetPos.X, base.Y + vel.Y * lead - 0.5 * g * lead * lead, targetPos.Z)
    end
    local origin = myHRP.Position
    local dir = targetPos - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local hit = workspace:Raycast(origin, dir, params)
    if hit then
        local inst = hit.Instance
        local tc = target.Character
        if not (tc and (inst == tc or inst:IsDescendantOf(tc))) then
            targetPos = base + velH * lead
        end
    end
    local flat = Vector3.new(targetPos.X, myHRP.Position.Y, targetPos.Z)
    if (flat - myHRP.Position).Magnitude > 0.1 then
        pcall(function() myHRP.CFrame = CFrame.new(myHRP.Position, flat) end)
    end
    pcall(function() Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos) end)
    return targetPos
end
local function DoQuietShot()
    task.spawn(function()
        local now = os.clock()
        if now - QuietAim.lastShot < 0.08 then return end
        QuietAim.lastShot = now
        local char = LocalPlayer.Character
        if not char then return end
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
            if p ~= LocalPlayer and GetRole(p) == "murderer" then target = p; break end
        end
        if not target then return end
        local thrp = GetHRP(target)
        if not thrp then return end
        local mode = _G.FH_QuietShotAimMode or "simple"
        local shootPos
        if mode == "advanced" then
            shootPos = QuietShot_Advanced(target, thrp)
        else
            shootPos = thrp.Position
            local predEn = true
            if Options.QuietShotPredict then predEn = Options.QuietShotPredict.Value end
            local predStr = 1
            if Options.QuietShotPredictVal then predStr = Options.QuietShotPredictVal.Value end
            if predEn and thrp.Velocity.Magnitude > 3 then
                local myHRP = GetHRP()
                if myHRP then
                    local velXZ = Vector3.new(thrp.Velocity.X, 0, thrp.Velocity.Z)
                    if thrp.Velocity.Y > -20 then
                        local dist = (thrp.Position - myHRP.Position).Magnitude
                        local timeToHit = dist / 300
                        shootPos = thrp.Position + velXZ * timeToHit * predStr
                    end
                end
            end
            QuietShot_Simple(shootPos)
        end
        local shootRemote = ReplicatedStorage:FindFirstChild("ShootGun", true)
        if not shootRemote then
            for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
                if v:IsA("RemoteEvent") and string.find(v.Name, "Shoot") then shootRemote = v; break end
            end
        end
        if shootRemote then
            pcall(function() shootRemote:FireServer(shootPos) end)
            pcall(function() shootRemote:FireServer(shootPos, shootPos) end)
        end
        pcall(function() gun:Activate() end)
    end)
end
AddConnection("QuietTrackLoop", RunService.Heartbeat:Connect(function()
    if not Options.QuietShot or not Options.QuietShot.Value then return end
    if (_G.FH_QuietShotAimMode or "simple") ~= "advanced" then return end
    local now = os.clock()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and GetRole(p) == "murderer" then QuietUpdateTrack(p, now) end
    end
end))

-- WINDOW
local winOpts={
    Title="FortniHub MM2",
    SubTitle="v"..VERSION.." by HOTI",
    TabWidth=110,
    Size=UDim2.fromOffset(440,320),
    Theme="Darker",
    MinimizeKey=Enum.KeyCode.RightControl,
}
local wOk,wErr=pcall(function() Window=Fluent:CreateWindow(winOpts) end)
if not wOk or not Window then logErr("Ошибка создания окна: "..tostring(wErr)); return end
Options=Fluent.Options
logInfo("Окно Fluent создано")
if SaveManager then pcall(function() SaveManager:SetLibrary(Fluent); SaveManager:SetFolder("FortniHub/MM2") end) end
if InterfaceManager then pcall(function() InterfaceManager:SetLibrary(Fluent); InterfaceManager:SetFolder("FortniHub/MM2") end) end
task.wait(0.3)

-- BIND POPUP
local BindPopupGui=Instance.new("ScreenGui")
BindPopupGui.Name="FH_BindPopup"; BindPopupGui.ResetOnSpawn=false; BindPopupGui.Enabled=false
BindPopupGui.DisplayOrder=1000; BindPopupGui.Parent=CoreGui
local BPF=Instance.new("Frame")
BPF.Size=UDim2.fromOffset(300,120); BPF.Position=UDim2.new(0.5,-150,0.4,-60)
BPF.BackgroundColor3=Color3.fromRGB(20,18,28); BPF.BorderSizePixel=0; BPF.Active=true; BPF.Parent=BindPopupGui
Instance.new("UICorner",BPF).CornerRadius=UDim.new(0,12)
local BPS=Instance.new("UIStroke",BPF); BPS.Color=THEME; BPS.Thickness=2
MakeDraggable(BPF)
local BPT=Instance.new("TextLabel",BPF)
BPT.Size=UDim2.new(1,0,0,26); BPT.Position=UDim2.fromOffset(0,10)
BPT.BackgroundTransparency=1; BPT.Font=Enum.Font.GothamBold; BPT.TextSize=15
BPT.TextColor3=THEME_LIGHT; BPT.Text=L("bind_popup_title")
local BPM=Instance.new("TextLabel",BPF)
BPM.Size=UDim2.new(1,0,0,22); BPM.Position=UDim2.fromOffset(0,38)
BPM.BackgroundTransparency=1; BPM.Font=Enum.Font.GothamBold; BPM.TextSize=14
BPM.TextColor3=Color3.new(1,1,1); BPM.Text=""
local BPH=Instance.new("TextLabel",BPF)
BPH.Size=UDim2.new(1,0,0,20); BPH.Position=UDim2.fromOffset(0,62)
BPH.BackgroundTransparency=1; BPH.Font=Enum.Font.Gotham; BPH.TextSize=12
BPH.TextColor3=Color3.fromRGB(180,180,200); BPH.Text=L("bind_popup_hint")
local BPC=Instance.new("TextButton",BPF)
BPC.Size=UDim2.fromOffset(80,22); BPC.Position=UDim2.new(1,-88,1,-28)
BPC.BackgroundColor3=Color3.fromRGB(40,40,45); BPC.Text=L("bind_popup_close")
BPC.TextColor3=Color3.fromRGB(255,100,100); BPC.Font=Enum.Font.GothamBold; BPC.TextSize=12
Instance.new("UICorner",BPC).CornerRadius=UDim.new(0,6)
local function ShowBindPopup(modName,modTitle)
    BindPopupTarget=modName; BindPopupActive=true
    BPM.Text=modTitle.."  →  "..modName
    BindPopupGui.Enabled=true
end
local function HideBindPopup()
    BindPopupActive=false; BindPopupTarget=nil; BindPopupGui.Enabled=false
end
BPC.MouseButton1Click:Connect(HideBindPopup)
local function TryApplyBind(modName,keyName)
    if not modName or not keyName then return end
    local pk=BindKeyCache[modName]; local pt=BindTimeCache[modName] or 0
    if pk==keyName and (tick()-pt)<2 then
        BindList[keyName]=nil; BindKeyCache[modName]=nil; BindTimeCache[modName]=nil
        Notify(L("notify_title"),L("bind_reset")..modName,3)
    else
        if pk and pk~=keyName then BindList[pk]=nil end
        BindList[keyName]=modName; BindKeyCache[modName]=keyName; BindTimeCache[modName]=tick()
        Notify(L("notify_title"),L("bind_set")..keyName.." → "..modName,3)
    end
end
UserInputService.InputBegan:Connect(function(input,gpe)
    if not BindPopupActive then return end
    if input.UserInputType==Enum.UserInputType.Keyboard then
        if input.KeyCode==Enum.KeyCode.Escape then HideBindPopup(); return end
        TryApplyBind(BindPopupTarget,input.KeyCode.Name); HideBindPopup()
    elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.MouseButton3 then
        local kn="Mouse"..input.UserInputType.Name:gsub("MouseButton","")
        TryApplyBind(BindPopupTarget,kn); HideBindPopup()
    end
end)
local function FindModuleUnderMouse(mp)
    local gs={}; pcall(function() gs=LocalPlayer:GetMouse():GetGuiObjectsAtPosition(mp.X,mp.Y) end)
    if #gs==0 then return nil,nil end
    local t2m={}
    for mn,t in pairs(ModuleNameToTitle) do if t and t~="" then t2m[t]=mn end end
    for _,obj in ipairs(gs) do
        local node=obj
        for _=1,4 do
            if not node then break end
            for _,ch in ipairs(node:GetDescendants()) do
                if ch:IsA("TextLabel") then
                    local txt=tostring(ch.Text or "")
                    local mn=t2m[txt]
                    if mn then return mn,txt end
                end
            end
            node=node.Parent
        end
    end
    return nil,nil
end
UserInputService.InputBegan:Connect(function(input,gpe)
    if BindPopupActive then return end
    if input.UserInputType==Enum.UserInputType.MouseButton3 then
        local mp=UserInputService:GetMouseLocation()
        local mn,mt=FindModuleUnderMouse(mp)
        if mn then ShowBindPopup(mn,mt) end
    end
end)

-- ============================================================
-- AWP MODEL v3 — anchor + CFrame update
-- ============================================================
local COL_BODY       = Color3.fromRGB(58, 74, 42)
local COL_BODY_DARK  = Color3.fromRGB(40, 52, 30)
local COL_METAL      = Color3.fromRGB(28, 28, 30)
local COL_METAL_LT   = Color3.fromRGB(48, 48, 50)
local COL_METAL_DARK = Color3.fromRGB(15, 15, 16)
local COL_RUBBER     = Color3.fromRGB(15, 15, 15)
local COL_GLASS      = Color3.fromRGB(40, 90, 110)
local COL_NEON       = Color3.fromRGB(70, 220, 255)
local rad = math.rad

local PART_DEFS = {
    {name="MuzzleBrake_Body", size=Vector3.new(0.14,0.085,0.085), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0,-1.48)*CFrame.Angles(0,rad(90),0)},
    {name="MuzzleBrake_VentTop", size=Vector3.new(0.022,0.022,0.022), color=COL_METAL_DARK, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,0.034,-1.46)},
    {name="MuzzleBrake_VentBottom", size=Vector3.new(0.022,0.022,0.022), color=COL_METAL_DARK, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,-0.034,-1.46)},
    {name="MuzzleBrake_VentLeft", size=Vector3.new(0.022,0.022,0.022), color=COL_METAL_DARK, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(-0.034,0,-1.44)},
    {name="MuzzleBrake_VentRight", size=Vector3.new(0.022,0.022,0.022), color=COL_METAL_DARK, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0.034,0,-1.44)},
    {name="Barrel_Main", size=Vector3.new(0.80,0.05,0.05), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0,-1.03)*CFrame.Angles(0,rad(90),0)},
    {name="Barrel_Flute1", size=Vector3.new(0.02,0.02,0.70), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(0.020,0,-1.03)},
    {name="Barrel_Flute2", size=Vector3.new(0.02,0.02,0.70), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(-0.010,0.017,-1.03)},
    {name="Barrel_Flute3", size=Vector3.new(0.02,0.02,0.70), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(-0.010,-0.017,-1.03)},
    {name="Chamber_Transition", size=Vector3.new(0.18,0.08,0.08), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0,-0.56)*CFrame.Angles(0,rad(90),0)},
    {name="Receiver_Body", size=Vector3.new(0.13,0.15,0.46), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,0,-0.26)},
    {name="Receiver_ChamferL", size=Vector3.new(0.03,0.03,0.44), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(-0.06,0.065,-0.26)*CFrame.Angles(0,0,rad(45))},
    {name="Receiver_ChamferR", size=Vector3.new(0.03,0.03,0.44), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0.06,0.065,-0.26)*CFrame.Angles(0,0,rad(-45))},
    {name="Receiver_EjectionPort", size=Vector3.new(0.02,0.05,0.12), color=COL_METAL_DARK, material=Enum.Material.Metal, cframe=CFrame.new(0.063,0.02,-0.20)},
    {name="Receiver_Magwell", size=Vector3.new(0.09,0.10,0.12), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,-0.115,-0.34)},
    {name="Receiver_RailRidge1", size=Vector3.new(0.10,0.02,0.03), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(0,0.08,-0.42)},
    {name="Receiver_RailRidge2", size=Vector3.new(0.10,0.02,0.03), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(0,0.08,-0.32)},
    {name="Receiver_RailRidge3", size=Vector3.new(0.10,0.02,0.03), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(0,0.08,-0.22)},
    {name="Receiver_RailRidge4", size=Vector3.new(0.10,0.02,0.03), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(0,0.08,-0.12)},
    {name="Receiver_ScrewTop1", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0.06,0.05,-0.40)},
    {name="Receiver_ScrewTop2", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(-0.06,0.05,-0.15)},
    {name="Bolt_Body", size=Vector3.new(0.14,0.05,0.05), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.09,-0.02)*CFrame.Angles(0,rad(90),0)},
    {name="Bolt_HandleShaft", size=Vector3.new(0.10,0.02,0.02), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0.07,0.075,0.03)*CFrame.Angles(0,0,rad(-20))},
    {name="Bolt_HandleKnob", size=Vector3.new(0.032,0.032,0.032), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0.135,0.055,0.045)},
    {name="TriggerGuard_Front", size=Vector3.new(0.02,0.09,0.02), color=COL_METAL, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.115,-0.01)},
    {name="TriggerGuard_Bottom", size=Vector3.new(0.02,0.02,0.11), color=COL_METAL, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.155,0.045)},
    {name="TriggerGuard_Rear", size=Vector3.new(0.02,0.09,0.02), color=COL_METAL, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.115,0.10)},
    {name="Trigger", size=Vector3.new(0.02,0.04,0.02), color=COL_METAL_DARK, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.10,0.02)*CFrame.Angles(rad(10),0,0)},
    {name="Mag_Body", size=Vector3.new(0.055,0.20,0.032), color=COL_METAL, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.26,-0.34)},
    {name="Mag_Baseplate", size=Vector3.new(0.06,0.02,0.036), color=COL_METAL_DARK, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.365,-0.34)},
    {name="Mag_RibFront", size=Vector3.new(0.02,0.18,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.26,-0.356)},
    {name="Mag_RibRear", size=Vector3.new(0.02,0.18,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.26,-0.324)},
    {name="Mag_ReleaseButton", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0.063,-0.10,-0.34)},
    {name="Mag_WitnessHole", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_DARK, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0.022,-0.20,-0.34)},
    {name="Forend_Top", size=Vector3.new(0.13,0.02,0.89), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,0.055,-0.915)},
    {name="Forend_Bottom", size=Vector3.new(0.13,0.02,0.89), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,-0.055,-0.915)},
    {name="Forend_Left", size=Vector3.new(0.02,0.11,0.89), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(-0.055,0,-0.915)},
    {name="Forend_Right", size=Vector3.new(0.02,0.11,0.89), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0.055,0,-0.915)},
    {name="Forend_FrontCap", size=Vector3.new(0.02,0.14,0.14), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0,-1.355)*CFrame.Angles(0,rad(90),0)},
    {name="Forend_MLOK_L1", size=Vector3.new(0.02,0.03,0.05), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(-0.062,0,-0.70)},
    {name="Forend_MLOK_L2", size=Vector3.new(0.02,0.03,0.05), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(-0.062,0,-1.05)},
    {name="Forend_MLOK_R1", size=Vector3.new(0.02,0.03,0.05), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0.062,0,-0.70)},
    {name="Forend_MLOK_R2", size=Vector3.new(0.02,0.03,0.05), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0.062,0,-1.05)},
    {name="Bipod_Mount", size=Vector3.new(0.05,0.03,0.06), color=COL_METAL, material=Enum.Material.Metal, cframe=CFrame.new(0,-0.078,-1.20)},
    {name="Bipod_Hinge", size=Vector3.new(0.03,0.022,0.022), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,-0.10,-1.20)},
    {name="Bipod_LegL", size=Vector3.new(0.20,0.02,0.02), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(-0.05,-0.19,-1.15)*CFrame.Angles(rad(10),0,rad(110))},
    {name="Bipod_LegL_Foot", size=Vector3.new(0.028,0.028,0.028), color=COL_RUBBER, material=Enum.Material.Rubber, shape=Enum.PartType.Ball, cframe=CFrame.new(-0.12,-0.28,-1.08)},
    {name="Bipod_LegR", size=Vector3.new(0.20,0.02,0.02), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0.05,-0.19,-1.15)*CFrame.Angles(rad(10),0,rad(70))},
    {name="Bipod_LegR_Foot", size=Vector3.new(0.028,0.028,0.028), color=COL_RUBBER, material=Enum.Material.Rubber, shape=Enum.PartType.Ball, cframe=CFrame.new(0.12,-0.28,-1.08)},
    {name="Swivel_Front", size=Vector3.new(0.03,0.03,0.02), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,-0.07,-1.05)},
    {name="Swivel_Rear", size=Vector3.new(0.03,0.03,0.02), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,-0.07,0.60)},
    {name="Stock_Main", size=Vector3.new(0.11,0.14,0.75), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,0,0.325)},
    {name="Stock_CheekRiser", size=Vector3.new(0.07,0.045,0.40), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,0.088,0.20)},
    {name="Stock_CheekRiser_Screw", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0.03,0.088,0.20)},
    {name="Stock_ThumbPanel", size=Vector3.new(0.02,0.06,0.16), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0.05,-0.01,0.40)},
    {name="Stock_RibL", size=Vector3.new(0.02,0.02,0.22), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(-0.052,0,0.55)},
    {name="Stock_RibR", size=Vector3.new(0.02,0.02,0.22), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0.052,0,0.55)},
    {name="Stock_Spacer", size=Vector3.new(0.10,0.13,0.05), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,0,0.705)},
    {name="Stock_Buttpad", size=Vector3.new(0.11,0.15,0.06), color=COL_RUBBER, material=Enum.Material.Rubber, cframe=CFrame.new(0,0,0.74)},
    {name="Grip_Main", size=Vector3.new(0.075,0.17,0.06), color=COL_BODY, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,-0.15,0.06)*CFrame.Angles(rad(-14),0,0)},
    {name="Grip_FingerGroove1", size=Vector3.new(0.06,0.02,0.02), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,-0.17,0.03)},
    {name="Grip_FingerGroove2", size=Vector3.new(0.06,0.02,0.02), color=COL_BODY_DARK, material=Enum.Material.SmoothPlastic, cframe=CFrame.new(0,-0.20,0.035)},
    {name="Grip_TexturePanel", size=Vector3.new(0.02,0.10,0.045), color=COL_RUBBER, material=Enum.Material.Rubber, cframe=CFrame.new(0.036,-0.15,0.065)},
    {name="Scope_Tube", size=Vector3.new(0.55,0.045,0.045), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.20,-0.18)*CFrame.Angles(0,rad(90),0)},
    {name="Scope_ObjectiveBell", size=Vector3.new(0.09,0.065,0.065), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.20,-0.49)*CFrame.Angles(0,rad(90),0)},
    {name="Scope_ObjectiveLens", size=Vector3.new(0.02,0.058,0.058), color=COL_GLASS, material=Enum.Material.Glass, shape=Enum.PartType.Cylinder, transparency=0.35, cframe=CFrame.new(0,0.20,-0.54)*CFrame.Angles(0,rad(90),0)},
    {name="Scope_OcularBell", size=Vector3.new(0.08,0.055,0.055), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.20,0.13)*CFrame.Angles(0,rad(90),0)},
    {name="Scope_OcularLens", size=Vector3.new(0.02,0.048,0.048), color=COL_GLASS, material=Enum.Material.Glass, shape=Enum.PartType.Cylinder, transparency=0.35, cframe=CFrame.new(0,0.20,0.175)*CFrame.Angles(0,rad(90),0)},
    {name="Scope_RingFront", size=Vector3.new(0.025,0.07,0.07), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.20,-0.30)*CFrame.Angles(0,rad(90),0)},
    {name="Scope_RingRear", size=Vector3.new(0.025,0.07,0.07), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.20,-0.02)*CFrame.Angles(0,rad(90),0)},
    {name="Scope_TurretElevation", size=Vector3.new(0.05,0.03,0.03), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.235,-0.10)*CFrame.Angles(0,0,rad(90))},
    {name="Scope_TurretElevation_Cap", size=Vector3.new(0.034,0.034,0.034), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,0.262,-0.10)},
    {name="Scope_TurretWindage", size=Vector3.new(0.045,0.028,0.028), color=COL_METAL, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0.04,0.20,-0.02)},
    {name="Scope_TurretWindage_Cap", size=Vector3.new(0.032,0.032,0.032), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0.064,0.20,-0.02)},
    {name="Scope_Sunshade", size=Vector3.new(0.03,0.075,0.075), color=COL_METAL_DARK, material=Enum.Material.Metal, shape=Enum.PartType.Cylinder, cframe=CFrame.new(0,0.20,-0.555)*CFrame.Angles(0,rad(90),0)},
    {name="Fastener_StockJunction", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,0.05,-0.02)},
    {name="Fastener_GripTop", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,-0.07,0.06)},
    {name="Fastener_ForendRear", size=Vector3.new(0.02,0.02,0.02), color=COL_METAL_LT, material=Enum.Material.Metal, shape=Enum.PartType.Ball, cframe=CFrame.new(0,0.05,-0.48)},
    {name="Accent_TopStripe", size=Vector3.new(0.02,0.02,0.35), color=COL_NEON, material=Enum.Material.Neon, cframe=CFrame.new(0,0.076,-0.10)},
    {name="Accent_MagStripe", size=Vector3.new(0.02,0.16,0.02), color=COL_NEON, material=Enum.Material.Neon, cframe=CFrame.new(0,-0.26,-0.358)},
}

local AWPEntries = {}
OriginalHandleTransparency = nil

local function createAWPPart(name,size,color,material,shape,transparency)
    local p=Instance.new("Part")
    p.Name=name; p.Size=size*AWP_SCALE; p.Color=color
    p.Material=material or Enum.Material.SmoothPlastic
    if shape then p.Shape=shape end
    p.Transparency=transparency or 0
    p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
    p.Massless=true; p.CastShadow=true
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    return p
end

local function clearAWPParts()
    for _, entry in ipairs(AWPEntries) do
        if entry.part and entry.part.Parent then
            pcall(function() entry.part:Destroy() end)
        end
    end
    AWPEntries = {}
end

local function buildAWPModel(handle)
    if not handle then return end
    if handle:GetAttribute("FH_AWPApplied") then return end
    OriginalHandleTransparency = handle.Transparency
    handle.Transparency = 1
    local MODEL_CFRAME = CFrame.new(AWP_OFFSET) * CFrame.Angles(rad(AWP_ROTATION.X), rad(AWP_ROTATION.Y), rad(AWP_ROTATION.Z))
    local tool = handle.Parent
    if not tool then return end
    for _, def in ipairs(PART_DEFS) do
        local part = createAWPPart(def.name, def.size, def.color, def.material, def.shape, def.transparency)
        local localPos = def.cframe.Position * AWP_SCALE
        local localRot = def.cframe - def.cframe.Position
        local offsetCF = MODEL_CFRAME * CFrame.new(localPos) * localRot
        part.CFrame = handle.CFrame * offsetCF
        part.Anchored = true
        part.Parent = tool
        AWPEntries[#AWPEntries+1] = { part = part, handle = handle, offset = offsetCF }
    end
    handle:SetAttribute("FH_AWPApplied", true)
end

local function RestoreAWP(handle)
    if not handle then return end
    if not handle:GetAttribute("FH_AWPApplied") then return end
    if OriginalHandleTransparency ~= nil then
        pcall(function() handle.Transparency = OriginalHandleTransparency end)
    end
    clearAWPParts()
    handle:SetAttribute("FH_AWPApplied", false)
end

AddConnection("AWPLoopRender", RunService.RenderStepped:Connect(function()
    if #AWPEntries == 0 then return end
    if not Options.AWPReplace or not Options.AWPReplace.Value then
        clearAWPParts()
        return
    end
    for i = #AWPEntries, 1, -1 do
        local entry = AWPEntries[i]
        local part = entry.part
        local handle = entry.handle
        if not part or not part.Parent or not handle or not handle.Parent then
            if part and part.Parent then pcall(function() part:Destroy() end) end
            table.remove(AWPEntries, i)
        else
            part.CFrame = handle.CFrame * entry.offset
        end
    end
end))

AddConnection("AWPDetect", RunService.Heartbeat:Connect(function()
    if not Options.AWPReplace or not Options.AWPReplace.Value then
        if #AWPEntries > 0 then clearAWPParts() end
        return
    end
    local char = LocalPlayer.Character
    if char then
        local gun = char:FindFirstChild("Gun")
        if gun then
            local h = gun:FindFirstChild("Handle")
            if h and not h:GetAttribute("FH_AWPApplied") then buildAWPModel(h) end
        end
    end
    local bp = LocalPlayer.Backpack
    if bp then
        local gun = bp:FindFirstChild("Gun")
        if gun then
            local h = gun:FindFirstChild("Handle")
            if h and not h:GetAttribute("FH_AWPApplied") then buildAWPModel(h) end
        end
    end
end))

local CombatModuleNames={"KillAura","AutoGrabGun","QuietShot"}
local MovementModuleNames={"SpeedToggle","SpeedGlitch","BunnyHop","Spinbot","FlyToggle","Noclip","InfJump","FreezeToggle"}
local function BlockModulesForFarm()
    FarmBlockedStates={}
    for _,n in ipairs(CombatModuleNames) do
        if Options[n] then
            FarmBlockedStates[n]=Options[n].Value
            if Options[n].Value then Options[n]:SetValue(false) end
        end
    end
    for _,n in ipairs(MovementModuleNames) do
        if Options[n] then
            FarmBlockedStates[n]=Options[n].Value
            if Options[n].Value then Options[n]:SetValue(false) end
        end
    end
end
local function UnblockModulesFromFarm()
    for n,wasOn in pairs(FarmBlockedStates) do
        if Options[n] and wasOn then Options[n]:SetValue(true) end
    end
    FarmBlockedStates={}
end
local function ApplyStretch()
    if not Options.StretchEnabled or not Options.StretchEnabled.Value then return end
    local v=(Options.StretchValue and Options.StretchValue.Value or 15)/10
    local cam=Workspace.CurrentCamera; if not cam then return end
    pcall(function() cam:SetAspectRatio(v) end)
    if sethiddenproperty then pcall(function() sethiddenproperty(cam,"AspectRatio",v) end) end
    if setscriptable then pcall(function() setscriptable(cam,"AspectRatio",true); cam.AspectRatio=v end) end
    pcall(function() cam.CFrame=cam.CFrame end)
end
pcall(function()
    RunService:BindToRenderStep("FH_Stretch",Enum.RenderPriority.Camera.Value-5,ApplyStretch)
end)

-- ============================================================
-- MODULES
-- ============================================================
local function CreateAllModules()
    local tabCombat=Window:AddTab({Title=L("tab_combat")})
    local tabMovement=Window:AddTab({Title=L("tab_movement")})
    local tabAutoFarm=Window:AddTab({Title=L("tab_farm")})
    local tabVisual=Window:AddTab({Title=L("tab_visual")})
    local tabTeleport=Window:AddTab({Title=L("tab_tp")})
    local tabTroll=Window:AddTab({Title=L("tab_troll")})
    local tabUtility=Window:AddTab({Title=L("tab_utility")})
    local tabMobile=Window:AddTab({Title=L("tab_mobile")})
    local tabKeybinds=Window:AddTab({Title=L("tab_binds")})
    local tabSettings=Window:AddTab({Title=L("tab_settings")})
    Tabs.Combat=tabCombat; Tabs.Movement=tabMovement; Tabs.AutoFarm=tabAutoFarm
    Tabs.Visual=tabVisual; Tabs.Teleport=tabTeleport; Tabs.Troll=tabTroll
    Tabs.Utility=tabUtility; Tabs.Mobile=tabMobile
    Tabs.Keybinds=tabKeybinds; Tabs.Settings=tabSettings

    local function OnToggleNotify(name,state)
        if Options.NotifyToggles and Options.NotifyToggles.Value then
            Notify(L("notify_title"),name.." "..(state and "ON" or "OFF"),1.5)
        end
    end
    local function Reg(mn,t) ModuleNameToTitle[mn]=t end

    Reg("QuietShot",L("quiet_shot")); Reg("QuietShotPredict",L("quiet_shot_predict"))
    Reg("QuietShotPredictVal",L("quiet_shot_predict_val")); Reg("KillAura",L("kill_aura"))
    Reg("KillAuraRadius",L("radius")); Reg("AutoGrabGun",L("auto_grab_gun"))
    Reg("QuietShotAimMode",L("quiet_shot_aim_mode"))

    tabCombat:AddToggle("QuietShot",{Title=L("quiet_shot"),Default=false}):OnChanged(function(v) OnToggleNotify(L("quiet_shot"),v) end)
    tabCombat:AddToggle("QuietShotPredict",{Title=L("quiet_shot_predict"),Default=true})
    tabCombat:AddSlider("QuietShotPredictVal",{Title=L("quiet_shot_predict_val"),Min=0,Max=5,Default=1,Rounding=1})
    tabCombat:AddDropdown("QuietShotAimMode",{
        Title=L("quiet_shot_aim_mode"),
        Values={L("quiet_shot_aim_simple"), L("quiet_shot_aim_advanced")},
        Default=L("quiet_shot_aim_simple"),
        Multi=false
    }):OnChanged(function(v)
        _G.FH_QuietShotAimMode = (v == L("quiet_shot_aim_advanced")) and "advanced" or "simple"
    end)
    tabCombat:AddKeybind("QuietShotBind",{Title=L("quiet_shot_bind"),Default="E",Callback=function(v)
        local k=Enum.KeyCode.E; pcall(function() k=Enum.KeyCode[v] end); QuietShotBind=k
    end})
    tabCombat:AddToggle("KillAura",{Title=L("kill_aura"),Default=false}):OnChanged(function(v) OnToggleNotify(L("kill_aura"),v) end)
    tabCombat:AddSlider("KillAuraRadius",{Title=L("radius"),Min=5,Max=100,Default=25,Rounding=0})
    tabCombat:AddToggle("AutoGrabGun",{Title=L("auto_grab_gun"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("auto_grab_gun"),v)
        if v then GrabFailedThisRound=false end
    end)
    tabCombat:AddButton({Title=L("kill_sheriff"),Callback=function()
        if GetRole(LocalPlayer)~="murderer" then Notify(L("notify_title"),L("not_murderer"),2); return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and GetRole(p)=="sheriff" then
                task.spawn(function() TeleportAndKill(p); Notify(L("notify_title"),L("kill_done")..p.Name,2) end)
                break
            end
        end
    end})
    tabCombat:AddButton({Title=L("suicide"),Callback=function()
        local c=LocalPlayer.Character
        if c then local h=c:FindFirstChild("Humanoid"); if h then h.Health=0 end end
    end})

    Reg("SpeedToggle",L("speed_hack")); Reg("SpeedValue",L("walk_speed"))
    Reg("FlyToggle",L("fly")); Reg("FlySpeed",L("fly_speed"))
    Reg("SpeedGlitch",L("speed_glitch")); Reg("GlitchSpeed",L("glitch_speed"))
    Reg("BunnyHop",L("bunny_hop")); Reg("BunnyMaxSpeed",L("max_speed")); Reg("BunnyAccelTime",L("accel_time"))
    Reg("Noclip",L("noclip")); Reg("Spinbot",L("spinbot")); Reg("SpinbotSpeed",L("spin_speed"))
    Reg("InfJump",L("inf_jump")); Reg("JumpPowerVal",L("jump_power")); Reg("JumpPowerToggle",L("jump_power_custom"))
    Reg("WallBounce",L("wall_bounce")); Reg("WallBounceForce",L("wall_force"))
    Reg("FreezeToggle",L("freeze")); Reg("FreezeSpeed",L("freeze_speed"))

    tabMovement:AddToggle("SpeedToggle",{Title=L("speed_hack"),Default=false}):OnChanged(function(v) OnToggleNotify(L("speed_hack"),v) end)
    tabMovement:AddSlider("SpeedValue",{Title=L("walk_speed"),Min=16,Max=500,Default=32,Rounding=0})
    tabMovement:AddToggle("FlyToggle",{Title=L("fly"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("fly"),v)
        TouchFlyFrame.Visible=v and UserInputService.TouchEnabled
        local hum=GetHum(); if hum then hum.PlatformStand=v end
    end)
    tabMovement:AddSlider("FlySpeed",{Title=L("fly_speed"),Min=20,Max=500,Default=60,Rounding=0})
    tabMovement:AddToggle("SpeedGlitch",{Title=L("speed_glitch"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("speed_glitch"),v); SgActive=false
        if not v then local h=GetHum(); if h then h.WalkSpeed=16 end end
    end)
    tabMovement:AddSlider("GlitchSpeed",{Title=L("glitch_speed"),Min=40,Max=500,Default=120,Rounding=0})
    tabMovement:AddToggle("BunnyHop",{Title=L("bunny_hop"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("bunny_hop"),v)
        if not v then local h=GetHum(); if h then h.WalkSpeed=16 end end
    end)
    tabMovement:AddSlider("BunnyMaxSpeed",{Title=L("max_speed"),Min=60,Max=500,Default=250,Rounding=0})
    tabMovement:AddSlider("BunnyAccelTime",{Title=L("accel_time"),Min=1,Max=30,Default=10,Rounding=0})
    tabMovement:AddToggle("Noclip",{Title=L("noclip"),Default=false}):OnChanged(function(v) OnToggleNotify(L("noclip"),v) end)
    tabMovement:AddToggle("Spinbot",{Title=L("spinbot"),Default=false}):OnChanged(function(v) OnToggleNotify(L("spinbot"),v) end)
    tabMovement:AddSlider("SpinbotSpeed",{Title=L("spin_speed"),Min=1,Max=50,Default=8,Rounding=0})
    tabMovement:AddToggle("InfJump",{Title=L("inf_jump"),Default=false}):OnChanged(function(v) OnToggleNotify(L("inf_jump"),v) end)
    tabMovement:AddSlider("JumpPowerVal",{Title=L("jump_power"),Min=50,Max=500,Default=100,Rounding=0})
    tabMovement:AddToggle("JumpPowerToggle",{Title=L("jump_power_custom"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("jump_power_custom"),v); CustomJumpPower=v
        local hum=GetHum()
        if hum then
            hum.UseJumpPower=true
            if v then hum.JumpPower=Options.JumpPowerVal and Options.JumpPowerVal.Value or 100
            else hum.JumpPower=50 end
        end
    end)
    tabMovement:AddToggle("WallBounce",{Title=L("wall_bounce"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("wall_bounce"),v); WallBounceEnabled=v
    end)
    tabMovement:AddSlider("WallBounceForce",{Title=L("wall_force"),Min=50,Max=500,Default=150,Rounding=0})
    tabMovement:AddToggle("FreezeToggle",{Title=L("freeze"),Default=false}):OnChanged(function(v)
        IsFrozen=v
        if not v then
            local hrp=GetHRP()
            if hrp then local bv=hrp:FindFirstChild("FH_FreezeBV"); if bv then bv:Destroy() end end
        end
        Notify(L("notify_title"),v and L("freeze_on") or L("freeze_off"),2)
    end)
    tabMovement:AddSlider("FreezeSpeed",{Title=L("freeze_speed"),Min=20,Max=300,Default=60,Rounding=0})

    Reg("AutoFarmCoins",L("autofarm")); Reg("AutoFarmSpeed",L("farm_speed"))
    Reg("AvoidMurderer",L("avoid_murderer")); Reg("AutoKillAuraAt40",L("auto_kill_aura")); Reg("AutoCollect",L("autocollect"))

    tabAutoFarm:AddToggle("AutoFarmCoins",{Title=L("autofarm"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("autofarm"),v)
        if v then BlockModulesForFarm(); FarmLastCoinTime=tick() else UnblockModulesFromFarm() end
    end)
    tabAutoFarm:AddSlider("AutoFarmSpeed",{Title=L("farm_speed"),Min=1,Max=60,Default=8,Rounding=1})
    tabAutoFarm:AddToggle("AvoidMurderer",{Title=L("avoid_murderer"),Default=false}):OnChanged(function(v)
        FarmAvoidMurderer=v; OnToggleNotify(L("avoid_murderer"),v)
    end)
    tabAutoFarm:AddToggle("AutoKillAuraAt40",{Title=L("auto_kill_aura"),Default=false}):OnChanged(function(v)
        FarmAutoKillAura=v; OnToggleNotify(L("auto_kill_aura"),v)
    end)
    tabAutoFarm:AddToggle("AutoCollect",{Title=L("autocollect"),Default=false}):OnChanged(function(v) OnToggleNotify(L("autocollect"),v) end)

    Reg("PlayerESP",L("player_esp")); Reg("NameESP",L("name_esp")); Reg("DistESP",L("dist_esp"))
    Reg("GunESP",L("gun_esp")); Reg("CoinESP",L("coin_esp")); Reg("Fullbright",L("fullbright"))
    Reg("FOVEnabled",L("fov")); Reg("FOVValue",L("fov")); Reg("StretchEnabled",L("stretch")); Reg("StretchValue",L("stretch"))
    Reg("FPSCap",L("fps_cap")); Reg("AWPReplace",L("awp_replace"))

    tabVisual:AddToggle("PlayerESP",{Title=L("player_esp"),Default=false}):OnChanged(function(v) OnToggleNotify(L("player_esp"),v) end)
    tabVisual:AddToggle("NameESP",{Title=L("name_esp"),Default=false})
    tabVisual:AddToggle("DistESP",{Title=L("dist_esp"),Default=false})
    tabVisual:AddToggle("GunESP",{Title=L("gun_esp"),Default=false})
    tabVisual:AddToggle("CoinESP",{Title=L("coin_esp"),Default=false})
    tabVisual:AddToggle("Fullbright",{Title=L("fullbright"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("fullbright"),v)
        if v then
            Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.Brightness=2
        else
            Lighting.Ambient=OriginalLighting.Ambient; Lighting.Brightness=OriginalLighting.Brightness
        end
    end)
    tabVisual:AddToggle("FOVEnabled",{Title=L("fov"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("fov"),v)
        if not v then Camera.FieldOfView=OriginalLighting.FOV end
    end)
    tabVisual:AddSlider("FOVValue",{Title=L("fov"),Min=30,Max=140,Default=70,Rounding=0})
    tabVisual:AddToggle("StretchEnabled",{Title=L("stretch"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("stretch"),v)
        if not v then
            pcall(function() Camera:SetAspectRatio(1) end)
            if sethiddenproperty then pcall(function() sethiddenproperty(Camera,"AspectRatio",1) end) end
        else ApplyStretch() end
    end)
    tabVisual:AddSlider("StretchValue",{Title=L("stretch"),Min=5,Max=40,Default=15,Rounding=1,Callback=function() ApplyStretch() end})
    tabVisual:AddSlider("FPSCap",{Title=L("fps_cap"),Min=0,Max=9999,Default=0,Rounding=0,Callback=function(v)
        FPSCap=v; pcall(function() if setfpscap then setfpscap(v) end end)
    end})
    tabVisual:AddToggle("AWPReplace",{Title=L("awp_replace"),Default=false}):OnChanged(function(v)
        OnToggleNotify(L("awp_replace"),v)
        if not v then
            local function fh(c)
                if not c then return nil end
                local g=c:FindFirstChild("Gun"); if g then return g:FindFirstChild("Handle") end
                return nil
            end
            RestoreAWP(fh(LocalPlayer.Character)); RestoreAWP(fh(LocalPlayer.Backpack))
        end
    end)

    local function TPToPos(pos)
        local hrp=GetHRP(); if hrp then hrp.CFrame=CFrame.new(pos) end
    end
    tabTeleport:AddButton({Title=L("tp_lobby"),Callback=function() TPToPos(Vector3.new(110,138,-12)) end})
    tabTeleport:AddButton({Title=L("tp_map"),Callback=function()
        local names={"Map","CurrentMap","Normal"}
        for _,mn in ipairs(names) do
            local m=Workspace:FindFirstChild(mn)
            if m then
                local sp=m:FindFirstChildWhichIsA("SpawnLocation",true)
                if sp then TPToPos(sp.Position+Vector3.new(0,3,0)); return end
                local sp2=m:FindFirstChild("Spawn",true) or m:FindFirstChild("SpawnPoint",true)
                if sp2 and sp2:IsA("BasePart") then TPToPos(sp2.Position+Vector3.new(0,5,0)); return end
                local part=m:FindFirstChildWhichIsA("BasePart",true)
                if part then TPToPos(part.Position+Vector3.new(0,8,0)); return end
            end
        end
    end})
    tabTeleport:AddButton({Title=L("tp_murderer"),Callback=function()
        for _,p in ipairs(Players:GetPlayers()) do
            if GetRole(p)=="murderer" then
                local hrp=GetHRP(p); if hrp then TPToPos(hrp.Position+Vector3.new(0,3,0)); break end
            end
        end
    end})
    tabTeleport:AddButton({Title=L("tp_sheriff"),Callback=function()
        for _,p in ipairs(Players:GetPlayers()) do
            if GetRole(p)=="sheriff" then
                local hrp=GetHRP(p); if hrp then TPToPos(hrp.Position+Vector3.new(0,3,0)); break end
            end
        end
    end})
    local tpV={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then table.insert(tpV,p.Name) end end
    tabTeleport:AddDropdown("TPPlayerSelect",{Title=L("tp_player"),Values=tpV,Default=tpV[1] or ""})
    tabTeleport:AddButton({Title=L("go"),Callback=function()
        local n=Options.TPPlayerSelect and Options.TPPlayerSelect.Value
        if not n then return end
        local t=Players:FindFirstChild(n)
        if t and t.Character then
            local hrp=GetHRP(t); if hrp then TPToPos(hrp.Position+Vector3.new(0,3,0)) end
        end
    end})
    AddConnection("TPAdd",Players.PlayerAdded:Connect(function(p)
        if Options.TPPlayerSelect then pcall(function() Options.TPPlayerSelect:Add(p.Name) end) end
    end))
    AddConnection("TPRem",Players.PlayerRemoving:Connect(function(p)
        if Options.TPPlayerSelect then pcall(function() Options.TPPlayerSelect:Remove(p.Name) end) end
    end))

    tabTroll:AddInput("ChatInput",{Title=L("spam_message"),Default="FortniHub v"..VERSION})
    tabTroll:AddToggle("SpamChat",{Title=L("spam_chat"),Default=false})
    tabTroll:AddToggle("TrollEgor",{Title=L("troll_egor"),Default=false}):OnChanged(function(v) OnToggleNotify(L("troll_egor"),v) end)
    tabTroll:AddToggle("TrollLag",{Title=L("troll_lag"),Default=false}):OnChanged(function(v) OnToggleNotify(L("troll_lag"),v) end)

    tabUtility:AddButton({Title=L("vote_boost"),Callback=function()
        if VoteRunning then Notify(L("notify_title"),L("vote_running"),2); return end
        VoteRunning=true
        task.spawn(function()
            local myHRP=GetHRP(); if not myHRP then VoteRunning=false; return end
            local orig=myHRP.CFrame
            for i=1,5 do
                local c=LocalPlayer.Character
                if c then local h=c:FindFirstChild("Humanoid"); if h then h.Health=0 end end
                LocalPlayer.CharacterAdded:Wait(); task.wait(0.5)
                local n=GetHRP(); local tries=0
                while not n and tries<20 do task.wait(0.1); n=GetHRP(); tries=tries+1 end
                if n then task.wait(0.1); n.CFrame=orig; task.wait(0.3) end
            end
            Notify(L("notify_title"),L("vote_done"),3); VoteRunning=false
        end)
    end})
    tabUtility:AddToggle("Invis",{Title=L("invis"),Default=false}):OnChanged(function(v)
        task.spawn(function()
            local ok=ClickExternalButton({"invisible","invis","невид"})
            if ok then Notify(L("notify_title"),v and L("invis_on") or L("invis_off"),2)
            else Notify(L("notify_title"),L("invis_nf"),3) end
        end)
    end)
    tabUtility:AddToggle("AntiAFK",{Title=L("anti_afk"),Default=true})
    tabUtility:AddButton({Title=L("rejoin"),Callback=function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer)
    end})
    tabUtility:AddButton({Title=L("server_hop"),Callback=function()
        pcall(function()
            local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
            local data=game:HttpGet(url); local parsed=HttpService:JSONDecode(data)
            for _,s in ipairs(parsed.data) do
                if s.playing<s.maxPlayers and s.id~=game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer); break
                end
            end
        end)
    end})

    local mobileValues={
        "ShootBtn","SpeedToggle","SpeedGlitch","BunnyHop","Spinbot","FlyToggle",
        "Noclip","FreezeToggle","WallBounce","AutoFarmCoins",
        "PlayerESP","NameESP","DistESP","GunESP","CoinESP",
        "KillAura","AutoGrabGun","Invis","QuietShot","InfJump","JumpPowerToggle",
    }
    tabMobile:AddDropdown("TouchModulesDropdown",{Title=L("select_modules_multi"),Values=mobileValues,Multi=true,Default={}})
    tabMobile:AddToggle("LockButtons",{Title=L("freeze_buttons"),Default=false}):OnChanged(function(v)
        MobileButtonsLocked=v
        Notify(L("notify_title"),"Заморозка "..(v and "ВКЛ" or "ВЫКЛ"),1.5)
    end)
    tabMobile:AddToggle("ShowShootBtn",{Title=L("show_shoot_btn"),Default=false}):OnChanged(function(v)
        if ShootButtonRef then ShootButtonRef.Visible=v end
        Notify(L("notify_title"),L("show_shoot_btn").." "..(v and "ON" or "OFF"),1.5)
    end)
    tabMobile:AddButton({Title=L("create_selected"),Callback=function()
        local val=Options.TouchModulesDropdown and Options.TouchModulesDropdown.Value
        if not val then Notify(L("notify_title"),L("nothing_selected"),2); return end
        for mn,sel in pairs(val) do
            if sel and not MobileButtons[mn] then CreateTouchButton(mn) end
        end
    end})
    tabMobile:AddButton({Title=L("clear_all"),Callback=function()
        if MobileButtonsLocked then Notify(L("notify_title"),L("freeze_first"),2); return end
        for _,f in pairs(MobileButtons) do if f then f:Destroy() end end
        MobileButtons={}
    end})

    local bindValues={
        "SpeedToggle","SpeedGlitch","BunnyHop","Spinbot","FlyToggle",
        "Noclip","FreezeToggle","WallBounce","AutoFarmCoins",
        "PlayerESP","NameESP","DistESP","GunESP","CoinESP",
        "KillAura","AutoGrabGun","Invis","InfJump","JumpPowerToggle","AWPReplace",
    }
    tabKeybinds:AddDropdown("BindSelect",{Title=L("module"),Values=bindValues,Default="SpeedToggle"})
    tabKeybinds:AddButton({Title=L("set_bind"),Callback=function()
        local m=Options.BindSelect and Options.BindSelect.Value
        if not m then return end
        ShowBindPopup(m,ModuleNameToTitle[m] or m)
    end})
    tabKeybinds:AddButton({Title=L("clear_binds"),Callback=function()
        for k,_ in pairs(BindList) do BindList[k]=nil end
        for k,_ in pairs(BindKeyCache) do BindKeyCache[k]=nil end
        for k,_ in pairs(BindTimeCache) do BindTimeCache[k]=nil end
        Notify(L("notify_title"),L("binds_cleared"),2)
    end})

    tabSettings:AddToggle("NotifyToggles",{Title=L("notify_toggles"),Default=true})
    tabSettings:AddToggle("ShowHUD",{Title=L("show_hud"),Default=false}):OnChanged(function(v) TopHUDGui.Enabled=v end)
    tabSettings:AddToggle("CoordMode",{Title=L("coord_mode"),Default=false}):OnChanged(function(v)
        CoordMode=v; CoordGui.Enabled=v
    end)
    local ld=(CurrentLang=="ru") and "Russian" or "English"
    tabSettings:AddDropdown("LanguageSelect",{Title=L("language"),Values={"English","Russian"},Default=ld}):OnChanged(function(v)
        local nl=(v=="Russian") and "ru" or "en"
        if nl==CurrentLang then return end
        CurrentLang=nl; _G.FortniHubLang=nl
        if writefile then pcall(function() writefile("FortniHubLang.txt",nl) end) end
        Notify(L("notify_title"),L("lang_saved"),5)
    end)
    tabSettings:AddButton({Title=L("unload"),Callback=function()
        pcall(function()
            for _,c in pairs(Connections) do c:Disconnect() end
            Connections={}
            if TopHUDGui then TopHUDGui:Destroy() end
            if MobileUI then MobileUI:Destroy() end
            if ESPFolder then ESPFolder:Destroy() end
            if OpenScriptGui then OpenScriptGui:Destroy() end
            if CoordGui then CoordGui:Destroy() end
            if BindPopupGui then BindPopupGui:Destroy() end
            Lighting.Ambient=OriginalLighting.Ambient
            Lighting.Brightness=OriginalLighting.Brightness
            Camera.FieldOfView=OriginalLighting.FOV
            pcall(function() Camera:SetAspectRatio(1) end)
            pcall(function() if setfpscap then setfpscap(60) end end)
            for _,d in pairs(NameESPDrawing) do pcall(function() d:Remove() end) end
            for _,d in pairs(DistESPDrawing) do pcall(function() d:Remove() end) end
            local hrp=GetHRP()
            if hrp then
                for _,n in ipairs({"FH_FlyBV","FH_HidePosition","FH_FreezeBV"}) do
                    local c=hrp:FindFirstChild(n); if c then c:Destroy() end
                end
                hrp.Anchored=false
            end
            local hum=GetHum(); if hum then hum.PlatformStand=false end
            task.wait(0.3)
            if Window then Window:Destroy() end
        end)
    end})

    if InterfaceManager then pcall(function() InterfaceManager:BuildInterfaceSection(tabSettings) end) end
    if SaveManager then
        pcall(function() SaveManager:BuildConfigSection(tabSettings) end)
        pcall(function() SaveManager:LoadAutoloadConfig() end)
    end
end

local mOk,mErr=pcall(CreateAllModules)
if not mOk then logErr("Ошибка создания модулей: "..tostring(mErr)) else logInfo("Модули созданы") end

-- MAIN LOOP
local lastESP=0; local lastItemESP=0; local lastHUD=0
local fpsC=0; local lastFPS=os.clock(); local curFPS=60

AddConnection("MainLoop",RunService.Heartbeat:Connect(function()
    RefreshCharCache()
    local now=os.clock()
    if now-lastHUD>0.5 then
        lastHUD=now
        if TopHUDGui.Enabled then
            PingLabel.Text=string.format("PING %dms",math.floor(LocalPlayer:GetNetworkPing()*1000))
            RoundLabel.Text=L("round_time").." "..GetRoundTime()
        end
    end
    local hum=CachedLocalHum
    if hum then
        if Options.SpeedToggle and Options.SpeedToggle.Value then
            hum.WalkSpeed=Options.SpeedValue and Options.SpeedValue.Value or 32
        end
        if IsFrozen then
            hum.WalkSpeed=0
            local hrp=CachedLocalHRP
            if hrp then
                if not hrp:FindFirstChild("FH_FreezeBV") then
                    local bv=Instance.new("BodyVelocity")
                    bv.Name="FH_FreezeBV"; bv.MaxForce=Vector3.new(1e5,1e5,1e5)
                    bv.Velocity=Vector3.zero; bv.Parent=hrp
                end
                local speed=Options.FreezeSpeed and Options.FreezeSpeed.Value or 60
                local dir=Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) or flyKeys.W then dir=dir+Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) or flyKeys.S then dir=dir-Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) or flyKeys.A then dir=dir+Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) or flyKeys.D then dir=dir+Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyKeys.UP then dir=dir+Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or flyKeys.DOWN then dir=dir-Vector3.new(0,1,0) end
                local bv=hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv.Velocity=dir.Magnitude>0 and dir.Unit*speed or Vector3.zero end
            end
        else
            if CachedLocalHRP then
                local bv=CachedLocalHRP:FindFirstChild("FH_FreezeBV"); if bv then bv:Destroy() end
            end
        end
        if CustomJumpPower then
            hum.UseJumpPower=true
            local jp=Options.JumpPowerVal and Options.JumpPowerVal.Value or 100
            if hum.JumpPower~=jp then hum.JumpPower=jp end
        end
        if Options.SpeedGlitch and Options.SpeedGlitch.Value then
            local gs=Options.GlitchSpeed and Options.GlitchSpeed.Value or 120
            local st=hum:GetState()
            if st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.Freefall then
                SgActive=true; LastMoveTime=tick(); hum.WalkSpeed=gs
            elseif st==Enum.HumanoidStateType.Landed or st==Enum.HumanoidStateType.Running or st==Enum.HumanoidStateType.RunningNoPhysics then
                if hum.MoveDirection.Magnitude>0.1 then
                    SgActive=true; LastMoveTime=tick(); hum.WalkSpeed=gs
                elseif tick()-LastMoveTime>0.2 and SgActive then
                    hum.WalkSpeed=16; SgActive=false
                end
            end
        end
        if Options.BunnyHop and Options.BunnyHop.Value then
            local maxS=Options.BunnyMaxSpeed and Options.BunnyMaxSpeed.Value or 250
            local acc=Options.BunnyAccelTime and Options.BunnyAccelTime.Value or 10
            if hum.MoveDirection.Magnitude>0.1 then
                _G.BunnySpeed=math.min((_G.BunnySpeed or 16)+(maxS/acc)*0.02,maxS)
            else _G.BunnySpeed=16 end
            hum.WalkSpeed=_G.BunnySpeed
        end
        if Options.Spinbot and Options.Spinbot.Value and CachedLocalHRP then
            local s=Options.SpinbotSpeed and Options.SpinbotSpeed.Value or 8
            CachedLocalHRP.CFrame=CachedLocalHRP.CFrame*CFrame.Angles(0,math.rad(s),0)
        end
        if Options.TrollEgor and Options.TrollEgor.Value then hum.WalkSpeed=0.5 end
    end
    if Options.Noclip and Options.Noclip.Value and LocalPlayer.Character then
        for _,v in ipairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide=false end
        end
    end
    if Options.FOVEnabled and Options.FOVEnabled.Value then
        local t=Options.FOVValue and Options.FOVValue.Value or 70
        if Camera.FieldOfView~=t then Camera.FieldOfView=t end
    end
    if Options.FPSCap then
        local v=Options.FPSCap.Value
        if v~=FPSCap then FPSCap=v; pcall(function() if setfpscap then setfpscap(v) end end) end
    end
    if Options.KillAura and Options.KillAura.Value then
        local n2=tick()
        if n2-(_G.LastKaHit or 0)>0.25 then
            local myHRP=CachedLocalHRP
            if myHRP and LocalPlayer.Character then
                local knife=LocalPlayer.Character:FindFirstChild("Knife")
                if knife then
                    local r=Options.KillAuraRadius and Options.KillAuraRadius.Value or 25
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p~=LocalPlayer then
                            local thrp=GetHRP(p)
                            if thrp and (thrp.Position-myHRP.Position).Magnitude<=r then
                                myHRP.CFrame=thrp.CFrame*CFrame.new(0,0,1.5)
                                pcall(function() VirtualUser:ClickButton1(Vector2.new(0,0)) end)
                                pcall(function()
                                    local s=knife:FindFirstChild("Stab") or knife:FindFirstChild("Slash") or knife:FindFirstChild("Hit")
                                    if s then
                                        if s:IsA("RemoteEvent") then s:FireServer()
                                        elseif s:IsA("RemoteFunction") then s:InvokeServer() end
                                    end
                                end)
                                _G.LastKaHit=n2; break
                            end
                        end
                    end
                end
            end
        end
    end
    if Options.AutoGrabGun and Options.AutoGrabGun.Value and not GrabFailedThisRound and not IsGrabbing then
        local char=LocalPlayer.Character
        local myHRP=char and char:FindFirstChild("HumanoidRootPart")
        if myHRP and not char:FindFirstChild("Gun")
            and not (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun")) then
            local closest,minD=nil,math.huge
            for _,gun in ipairs(CachedGuns) do
                if gun and gun.Parent and gun:IsA("BasePart") then
                    local d=(gun.Position-myHRP.Position).Magnitude
                    if d<minD then minD=d; closest=gun end
                end
            end
            if closest then
                IsGrabbing=true
                task.spawn(function()
                    local rp=myHRP.CFrame
                    local tp=closest:IsA("BasePart") and closest or closest:FindFirstChildWhichIsA("BasePart")
                    if tp then
                        local grabbed=false
                        for i=1,3 do
                            if myHRP and myHRP.Parent then myHRP.CFrame=tp.CFrame end
                            task.wait(0.05)
                            pcall(function()
                                firetouchinterest(myHRP,tp,0); task.wait(0.02); firetouchinterest(myHRP,tp,1)
                            end)
                            if LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun") then grabbed=true; break end
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun") then grabbed=true; break end
                        end
                        if myHRP and myHRP.Parent then
                            myHRP.CFrame=rp
                            myHRP.AssemblyLinearVelocity=Vector3.new(0,0,0)
                            myHRP.AssemblyAngularVelocity=Vector3.new(0,0,0)
                        end
                        if not grabbed then
                            GrabFailedThisRound=true
                            Notify(L("notify_title"),L("grab_fail"),3)
                        end
                    end
                    IsGrabbing=false
                end)
            end
        end
    end
    if Options.AutoCollect and Options.AutoCollect.Value then
        local myHRP=CachedLocalHRP
        if myHRP then
            for _,coin in ipairs(CachedCoins) do
                if coin and coin.Parent and coin:IsA("BasePart") and (coin.Position-myHRP.Position).Magnitude<5 then
                    pcall(function()
                        firetouchinterest(myHRP,coin,0); firetouchinterest(myHRP,coin,1)
                    end)
                end
            end
        end
    end
    if now-lastESP>0.2 then
        lastESP=now
        if Options.PlayerESP and Options.PlayerESP.Value then
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and p.Character then
                    local hlN="ESP_"..p.Name
                    local hl=ESPFolder:FindFirstChild(hlN)
                    if not hl then hl=Instance.new("Highlight") end
                    hl.Name=hlN; hl.Adornee=p.Character
                    hl.FillColor=GetRoleColor(GetRole(p))
                    hl.FillTransparency=0.5; hl.OutlineColor=Color3.new(1,1,1)
                    hl.Parent=ESPFolder
                end
            end
        else ESPFolder:ClearAllChildren() end
    end
    if now-lastItemESP>1.5 then
        lastItemESP=now
        if Options.GunESP and Options.GunESP.Value then
            for _,gun in ipairs(CachedGuns) do
                if gun and gun.Parent and not gun:FindFirstChild("FH_GunHL") then
                    local hl=Instance.new("Highlight")
                    hl.Name="FH_GunHL"; hl.Adornee=gun; hl.FillColor=Color3.fromRGB(255,255,0); hl.Parent=gun
                end
            end
        else
            for _,gun in ipairs(CachedGuns) do
                if gun and gun.Parent then
                    local hl=gun:FindFirstChild("FH_GunHL"); if hl then hl:Destroy() end
                end
            end
        end
        if Options.CoinESP and Options.CoinESP.Value then
            for _,obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name=="Coin_Server" or obj.Name=="Coin") then
                    if not obj:FindFirstChild("FH_CoinHL") then
                        local hl=Instance.new("Highlight")
                        hl.Name="FH_CoinHL"; hl.Adornee=obj
                        hl.FillColor=Color3.fromRGB(255,215,0); hl.OutlineColor=Color3.new(1,1,1)
                        hl.FillTransparency=0.4; hl.Parent=obj
                    end
                end
            end
        else
            for _,obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local hl=obj:FindFirstChild("FH_CoinHL"); if hl then hl:Destroy() end
                end
            end
        end
    end
    if Options.FlyToggle and Options.FlyToggle.Value then
        local hrp=CachedLocalHRP; local h2=CachedLocalHum
        if hrp and h2 then
            h2.PlatformStand=true
            local sp=Options.FlySpeed and Options.FlySpeed.Value or 60
            local dir=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) or flyKeys.W then dir=dir+Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) or flyKeys.S then dir=dir-Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or flyKeys.A then dir=dir-Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) or flyKeys.D then dir=dir+Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or flyKeys.UP then dir=dir+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or flyKeys.DOWN then dir=dir-Vector3.new(0,1,0) end
            hrp.Velocity=dir.Magnitude>0 and dir.Unit*sp or Vector3.zero
        end
    else
        if CachedLocalHum and CachedLocalHum.PlatformStand then CachedLocalHum.PlatformStand=false end
    end
    if CoordMode and CachedLocalHRP then
        local p=CachedLocalHRP.Position
        CoordLabel.Text=string.format("X: %d Y: %d Z: %d",math.floor(p.X),math.floor(p.Y),math.floor(p.Z))
    end
    fpsC=fpsC+1
    if now-lastFPS>=1 then
        curFPS=fpsC; fpsC=0; lastFPS=now
        if TopHUDGui.Enabled then
            local fc=THEME_OK
            if curFPS<60 then fc=THEME_WARN end
            if curFPS<30 then fc=THEME_ERR end
            FPSLabel.Text=string.format("FPS %d",curFPS); FPSLabel.TextColor3=fc
        end
    end
end))

AddConnection("TextESPLoop",RunService.RenderStepped:Connect(function()
    if not (Options.NameESP and Options.NameESP.Value) and not (Options.DistESP and Options.DistESP.Value) then
        for p,d in pairs(NameESPDrawing) do pcall(function() d:Remove() end) end
        for p,d in pairs(DistESPDrawing) do pcall(function() d:Remove() end) end
        NameESPDrawing={}; DistESPDrawing={}; return
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local hrp=p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local hp=hrp.Position+Vector3.new(0,3,0)
                local sp,on=Camera:WorldToViewportPoint(hp)
                if Options.NameESP and Options.NameESP.Value then
                    if not NameESPDrawing[p] then
                        local d=Drawing.new("Text"); d.Size=14; d.Center=true; d.Outline=true; d.Color=Color3.new(1,1,1); NameESPDrawing[p]=d
                    end
                    local d=NameESPDrawing[p]
                    if on then d.Position=Vector2.new(sp.X,sp.Y-20); d.Text=p.Name; d.Visible=true else d.Visible=false end
                end
                if Options.DistESP and Options.DistESP.Value then
                    if not DistESPDrawing[p] then
                        local d=Drawing.new("Text"); d.Size=12; d.Center=true; d.Outline=true; d.Color=Color3.fromRGB(200,200,200); DistESPDrawing[p]=d
                    end
                    local d=DistESPDrawing[p]
                    if on then d.Position=Vector2.new(sp.X,sp.Y+5); d.Text=math.floor((Camera.CFrame.Position-hrp.Position).Magnitude).."m"; d.Visible=true else d.Visible=false end
                end
            end
        end
    end
end))

AddConnection("TextESPRem",Players.PlayerRemoving:Connect(function(p)
    if NameESPDrawing[p] then NameESPDrawing[p]:Remove(); NameESPDrawing[p]=nil end
    if DistESPDrawing[p] then DistESPDrawing[p]:Remove(); DistESPDrawing[p]=nil end
    local hl=ESPFolder:FindFirstChild("ESP_"..p.Name); if hl then hl:Destroy() end
end))

local function StopFarm()
    FarmRunning=false; FarmAnchored=false
    local hrp=GetHRP(); if hrp then hrp.Anchored=false end
    RecentlyTouchedCoins={}; FarmLastCoinTime=0; FarmTimeoutStart=tick(); FarmLastCoinCount=0
    FarmLastPos = nil
    FarmStuck = 0
end
local function CollectAllCoins()
    if #CachedCoins>0 then
        local l={}
        for _,c in ipairs(CachedCoins) do if c and c.Parent and c:IsA("BasePart") then table.insert(l,c) end end
        if #l>0 then return l end
    end
    local l={}
    for _,o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and (o.Name=="Coin_Server" or o.Name=="Coin" or string.find(o.Name:lower(),"coin")) then
            table.insert(l,o)
        end
    end
    return l
end
local function StartFarm()
    if FarmRunning then return end
    FarmRunning=true; FarmTimeoutStart=tick(); FarmLastCoinCount=GetCoinCountSafe()
    task.spawn(function()
        while Options.AutoFarmCoins and Options.AutoFarmCoins.Value do
            local char=LocalPlayer.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then task.wait(0.15) else
                local cur=GetCoinCountSafe()
                if cur>FarmLastCoinCount then FarmLastCoinCount=cur; FarmTimeoutStart=tick() end
                if tick()-FarmTimeoutStart>20 then
                    Notify(L("notify_title"),L("farm_restart"),3)
                    StopFarm(); task.wait(0.5)
                    if Options.AutoFarmCoins and Options.AutoFarmCoins.Value then FarmRunning=false; StartFarm() end
                    return
                end
                if cur>=40 then
                    if FarmAnchored then hrp.Anchored=false; FarmAnchored=false end
                    if FarmAutoKillAura and GetRole(LocalPlayer)=="murderer" then
                        local m=nil
                        for _,p in ipairs(Players:GetPlayers()) do
                            if p~=LocalPlayer and GetRole(p)=="murderer" then m=p; break end
                        end
                        if m then
                            local thrp=GetHRP(m)
                            if thrp and (thrp.Position-hrp.Position).Magnitude<=25 then
                                hrp.CFrame=thrp.CFrame*CFrame.new(0,0,1.5); task.wait(0.1)
                                local knife=char:FindFirstChild("Knife")
                                if knife then
                                    pcall(function() knife:Activate() end)
                                    pcall(function() VirtualUser:ClickButton1(Vector2.new(0,0)) end)
                                end
                                task.wait(0.15)
                            end
                        end
                    end
                    Notify(L("notify_title"),L("farm_full"),3); task.wait(0.8)
                end
                if not (Options.AutoFarmCoins and Options.AutoFarmCoins.Value) then break end
                if not FarmAnchored then hrp.Anchored=true; FarmAnchored=true end
                for _,p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide=false end
                end
                if FarmAvoidMurderer then
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p~=LocalPlayer and GetRole(p)=="murderer" then
                            local thrp=GetHRP(p)
                            if thrp and (thrp.Position-hrp.Position).Magnitude<10 then
                                local ad=(hrp.Position-thrp.Position)
                                if ad.Magnitude<0.1 then ad=Vector3.new(0,0,1) end
                                hrp.CFrame=CFrame.new(hrp.Position+ad.Unit*30); task.wait(0.15); break
                            end
                        end
                    end
                end
                local now=tick()
                for coin,t in pairs(RecentlyTouchedCoins) do
                    if now-t>6 or not coin.Parent then RecentlyTouchedCoins[coin]=nil end
                end
                local coins=CollectAllCoins()
                if #coins==0 then task.wait(0.2) else
                    local allMarked=true
                    for _,c in ipairs(coins) do
                        if not RecentlyTouchedCoins[c] then allMarked=false; break end
                    end
                    if allMarked then RecentlyTouchedCoins={} end
                    local closest,minDist=nil,math.huge
                    for _,c in ipairs(coins) do
                        if c.Parent and not RecentlyTouchedCoins[c] then
                            local d=(hrp.Position-c.Position).Magnitude
                            if d<minDist then minDist=d; closest=c end
                        end
                    end
                    if closest and closest.Parent then
                        local sp=hrp.Position; local ep=closest.Position
                        local sv=Options.AutoFarmSpeed and Options.AutoFarmSpeed.Value or 8
                        local dist=(ep-sp).Magnitude
                        local steps=math.clamp(math.floor(dist/(sv*0.03)),3,50)
                        for i=1,steps do
                            if not hrp.Parent or not closest.Parent then break end
                            if not (Options.AutoFarmCoins and Options.AutoFarmCoins.Value) then break end
                            local a=i/steps
                            pcall(function() hrp.CFrame=CFrame.new(sp:Lerp(ep,a)) end)
                            task.wait(0.015)
                        end
                        if hrp.Parent and closest.Parent then
                            pcall(function() hrp.CFrame=CFrame.new(ep) end); task.wait(0.03)
                            for _=1,5 do
                                if not closest.Parent then break end
                                pcall(function()
                                    firetouchinterest(hrp,closest,0); task.wait(0.01); firetouchinterest(hrp,closest,1)
                                end)
                                task.wait(0.04)
                            end
                            RecentlyTouchedCoins[closest]=tick(); task.wait(0.05)
                        end
                        if FarmAnchored then hrp.Anchored=false; FarmAnchored=false end
                        for _,p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide=true end
                        end
                        task.wait(0.03)
                    else task.wait(0.15) end
                end
            end
        end
        if FarmAnchored then
            local hrp=GetHRP(); if hrp then hrp.Anchored=false end
            FarmAnchored=false
        end
        RecentlyTouchedCoins={}; FarmRunning=false
    end)
end
AddConnection("FarmCheck",RunService.Heartbeat:Connect(function()
    if Options.AutoFarmCoins and Options.AutoFarmCoins.Value then
        if not FarmRunning then StartFarm() end
    else
        if FarmRunning then StopFarm() end
    end
end))

AddConnection("SpamLoop",task.spawn(function()
    while task.wait(10) do
        if Options.SpamChat and Options.SpamChat.Value then
            local msg=Options.ChatInput and Options.ChatInput.Value or "FortniHub"
            if TextChatService and TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
                local ch=TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                if ch then ch:SendAsync(msg) end
            else
                local r=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if r then r.SayMessageRequest:FireServer(msg,"All") end
            end
        end
    end
end))

AddConnection("AntiAFK",LocalPlayer.Idled:Connect(function()
    if Options.AntiAFK and Options.AntiAFK.Value then
        VirtualUser:Button2Down(Vector2.new(0,0),Workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0),Workspace.CurrentCamera.CFrame)
    end
end))

AddConnection("LagLoop",RunService.RenderStepped:Connect(function()
    if not Options.TrollLag or not Options.TrollLag.Value then return end
    for i=1,5000 do local _=math.noise(i,i*0.5) end
end))

AddConnection("IJLoop",UserInputService.JumpRequest:Connect(function()
    if Options.InfJump and Options.InfJump.Value then
        local hum=GetHum(); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

AddConnection("WBJump",UserInputService.JumpRequest:Connect(function()
    if not WallBounceEnabled then return end
    local char=LocalPlayer.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local params=RaycastParams.new()
    params.FilterDescendantsInstances={char}; params.FilterType=Enum.RaycastFilterType.Exclude
    local dirs={hrp.CFrame.LookVector,-hrp.CFrame.LookVector,hrp.CFrame.RightVector,-hrp.CFrame.RightVector}
    for _,d in ipairs(dirs) do
        local res=Workspace:Raycast(hrp.Position,d*3,params)
        if res then
            local force=Options.WallBounceForce and Options.WallBounceForce.Value or 150
            hrp.AssemblyLinearVelocity=Vector3.new(hrp.Velocity.X,force,hrp.Velocity.Z)
            break
        end
    end
end))

AddConnection("BindHandler",UserInputService.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if BindPopupActive then return end
    if Options.QuietShot and Options.QuietShot.Value and input.KeyCode==QuietShotBind then
        DoQuietShot(); return
    end
    local keyName=nil
    if input.UserInputType==Enum.UserInputType.Keyboard then keyName=input.KeyCode.Name
    elseif input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.MouseButton2 or input.UserInputType==Enum.UserInputType.MouseButton3 then
        keyName="Mouse"..input.UserInputType.Name:gsub("MouseButton","")
    end
    if keyName then
        local target=BindList[keyName]
        if target and Options[target] then Options[target]:SetValue(not Options[target].Value) end
    end
end))

ShootBtn.MouseButton1Click:Connect(function() DoQuietShot() end)

AddConnection("MenuKey",UserInputService.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.KeyCode==Enum.KeyCode.P then
        pcall(function() Window:Minimize() end)
    end
end))
OpenBtn.MouseButton1Click:Connect(function() pcall(function() Window:Minimize() end) end)

AddConnection("CharAdded",LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local hum=char:WaitForChild("Humanoid",5)
    local hrp=char:WaitForChild("HumanoidRootPart",5)
    GrabFailedThisRound=false; RecentlyTouchedCoins={}; FarmAnchored=false
    FarmTimeoutStart=tick(); IsFrozen=false; AWPCreatedParts={}; CharCacheTime=0
    FarmLastPos = nil; FarmStuck = 0
    if hrp then
        hrp.Anchored=false
        for _,n in ipairs({"FH_FreezeBV","FH_FlyBV","FH_HidePosition"}) do
            local o=hrp:FindFirstChild(n); if o then o:Destroy() end
        end
    end
    if Options.SpeedToggle and Options.SpeedToggle.Value and hum then
        hum.WalkSpeed=Options.SpeedValue and Options.SpeedValue.Value or 32
    end
    if Options.Noclip and Options.Noclip.Value then
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end
end))

pcall(function() Window:SelectTab(1) end)

task.spawn(function()
    task.wait(0.5)
    Notify(L("notify_title"),L("loaded"),6)
end)

-- ============================================================
-- EXPOSE GLOBALS + АВТО-ЗАГРУЗКА two.lua
-- ============================================================
local _GENV = (getgenv and getgenv()) or _G
_GENV.FH = {
    Options = Options, Window = Window, Tabs = Tabs,
    Notify = Notify, GetRole = GetRole, GetRoleColor = GetRoleColor,
    GetHRP = GetHRP, GetHum = GetHum, L = L,
    AddConnection = AddConnection, Connections = Connections,
    LocalPlayer = LocalPlayer, Players = Players,
    RunService = RunService, UserInputService = UserInputService,
    ReplicatedStorage = ReplicatedStorage, VirtualUser = VirtualUser,
    Workspace = Workspace, CoreGui = CoreGui, Camera = Camera,
    THEME = THEME, VERSION = VERSION,
    ModuleNameToTitle = ModuleNameToTitle,
    logInfo = logInfo, logWarn = logWarn, logErr = logErr,
    safeHttpGet = safeHttpGet, safeLoadstring = safeLoadstring, safeRun = safeRun,
    MobileUI = MobileUI, Lighting = Lighting,
}
_G.FH = _GENV.FH

logInfo("Глобалы экспортированы")

task.spawn(function()
    local url = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/two.lua"
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if not ok or type(body) ~= "string" or #body < 100 then
        logWarn("two.lua не скачался")
        return
    end
    local fn, err = loadstring(body, "@two")
    if type(fn) ~= "function" then
        logWarn("two.lua не скомпилировался: " .. tostring(err))
        return
    end
    local ok2, err2 = pcall(fn)
    if not ok2 then
        logWarn("two.lua упал: " .. tostring(err2))
    else
        logInfo("two.lua загружен из контекста one.lua")
    end
end)

logInfo("Скрипт полностью загружен")
