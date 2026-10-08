-- ============================================================
-- one.lua — FortniHub MM2 v21.0 RC — ЧАСТЬ 1/2
-- Rewritten from scratch by Steve
-- ============================================================
-- ЧТО СДЕЛАНО В PART 1/2:
--   [✓] Исправлен баг сериализации: Enum.KeyCode больше не падает на строках
--   [✓] Ватермарка удалена ВООБЩЕ (ни HUD-версии, ни отдельной)
--   [✓] Бэктрек 1.0 — единый кольцевой буфер, синхрон с пингом
--   [✓] Бэктрек 2.0 (бывш. Client Ghost) — в разделе Визуал рядом с 1.0
--   [✓] Эмоции — работают как АНИМАЦИИ (Looped=false, Priority=Movement)
--   [✓] Убраны: строка поиска эмоций, поиск эмодзи, кнопка "Список эмоций"
--   [✓] Старые звуки (SHITARO: mc bow, neverlose, rust) удалены
--   [✓] Звуки заменены на KITI-набор
--   [✓] Game Sounds блок удалён полностью
--   [✓] Advanced AutoFarm удалён — остался только FarmV3
--   [✓] UI Sounds работают на каждом toggle
--   [✓] Модель оружия удалена (и SpecialMesh, и GetObjects версия)
--   [✓] График скорости переписан, работает через проверку Drawing API
--   [✓] Скайбокс: Toggle + Dropdown (ОДИН выбор), свой ID удалён
--   [✓] Плейлист — заглушка
--   [✓] Aura 2.0 — базовый блок (расширение в Part 2/2)
--   [✓] Loader-совместимость: safeRandom, защита от кривых данных
-- ============================================================

-- ============================================================
-- WAIT: Если Part 1 запускается через loader, rander уже поднят
-- ============================================================
if not game then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
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
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local VERSION = "21.0.0 RC"
local CREDITS = "HOTI & Ve315 — fixes: Steve"

-- ============================================================
-- SAFE RANDOM (совместим с loader.lua)
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
local srand = getgenv().safeRandom
getgenv().FH_Part = 1

-- ============================================================
-- КЭШ ПЕРСОНАЖА
-- ============================================================
local Cache = {hrp=nil, hum=nil, t=0}
local function refreshChar()
    if tick() - Cache.t < 0.5 then return end
    Cache.t = tick()
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
getgenv().getHRP = getHRP
getgenv().getHum = getHum

-- ============================================================
-- БЕЗОПАСНАЯ ОБРАБОТКА ENUM (главный фикс ошибки)
-- "ForceField is not a valid member of Enum.KeyCode"
-- ============================================================
local function safeEnum(enumType, name)
    if type(enumType) ~= "table" or type(name) ~= "string" then return nil end
    local ok, val = pcall(function() return enumType[name] end)
    if ok and val then return val end
    return nil
end
local function isKeyCodeString(str)
    if type(str) ~= "string" then return false end
    return safeEnum(Enum.KeyCode, str) ~= nil
end

-- ============================================================
-- ROUND DATA
-- ============================================================
local roundCache = {mod=nil, t=0}
local function getRoundData()
    if roundCache.mod and tick() - roundCache.t < 0.5 then
        return roundCache.mod.PlayerData
    end
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
    end)
    if ok and type(m) == "table" then
        roundCache.mod = m
        roundCache.t = tick()
        return m.PlayerData
    end
    return nil
end
getgenv().getRoundData = getRoundData

local function getRoleFromData(p)
    if not p then return "lobby" end
    local data = getRoundData()
    if type(data) == "table" then
        local d = data[p.Name]
        if d and not d.Dead then
            if d.Role == "Murderer" then return "murderer" end
            if d.Role == "Sheriff" then return "sheriff" end
            if d.Role == "Hero" then return "hero" end
            return "innocent"
        end
    end
    local c = p.Character
    if c then
        local bp = p:FindFirstChild("Backpack")
        if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then
            return "murderer"
        end
        if c:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then
            return "sheriff"
        end
    end
    return "innocent"
end
getgenv().getRoleFromData = getRoleFromData

-- ============================================================
-- CONNECTIONS
-- ============================================================
local Connections = {}
local function AddConn(name, conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name] = conn
end

-- ============================================================
-- FLUENT UI
-- ============================================================
local Fluent
do
    print("[FH] Загружаю Fluent UI...")
    local urls = {
        "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/src/init.lua",
        "https://cdn.jsdelivr.net/gh/dawid-scripts/Fluent@main/src/init.lua",
        "https://raw.githack.com/dawid-scripts/Fluent/main/src/init.lua",
    }
    local body
    for _, u in ipairs(urls) do
        local ok, b = pcall(function() return game:HttpGet(u, true) end)
        if ok and type(b) == "string" and #b > 1000 and not b:find("<html") then
            body = b
            break
        end
    end
    if not body then
        warn("[FH] Не удалось загрузить Fluent UI")
        return
    end
    local fn = loadstring(body, "@Fluent")
    Fluent = fn and fn()
    if type(Fluent) ~= "table" then
        warn("[FH] Fluent не таблица")
        return
    end
    print("[FH] Fluent загружен")
end

-- ============================================================
-- АДАПТЕР ВКЛАДОК
-- ============================================================
local function adaptTab(tab)
    if not tab then return tab end
    for _, name in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput","AddButton","AddLabel","AddKeybind","AddColorpicker","AddColorPicker"}) do
        local orig = tab[name]
        if type(orig) == "function" and not rawget(tab, "__" .. name) then
            rawset(tab, "__" .. name, true)
            tab[name] = function(self, ...)
                local r = orig(self, ...)
                if type(r) == "table" and r.Option == nil then r.Option = r end
                return r
            end
        end
    end
    if type(tab.AddColorpicker) == "function" and type(tab.AddColorPicker) ~= "function" then
        tab.AddColorPicker = tab.AddColorpicker
    end
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

local Window, Options
do
    Window = Fluent:CreateWindow({
        Title = "FortniHub MM2",
        SubTitle = "v" .. VERSION .. " — " .. CREDITS,
        TabWidth = 130,
        Size = UDim2.fromOffset(440, 320),
        Theme = "Darker",
        MinimizeKey = Enum.KeyCode.P,
    })
    Options = Fluent.Options
    getgenv().FH_Window = Window
    getgenv().Options = Options
    local origAddTab = Window.AddTab
    Window.AddTab = function(self, ...)
        local tab = origAddTab(self, ...)
        return adaptTab(tab)
    end
end

local Tabs = {}
getgenv().FH_Tabs = Tabs
Tabs.Combat     = Window:AddTab({Title="Бой"})
Tabs.Movement   = Window:AddTab({Title="Движение"})
Tabs.Binds      = Window:AddTab({Title="Бинды"})
Tabs.Visual     = Window:AddTab({Title="Визуал"})
Tabs.Effects    = Window:AddTab({Title="Эффекты"})
Tabs.Farm       = Window:AddTab({Title="Фарм"})
Tabs.Animations = Window:AddTab({Title="Анимации"})
Tabs.Utility    = Window:AddTab({Title="Утилиты"})
Tabs.Troll      = Window:AddTab({Title="Троллинг"})
Tabs.Settings   = Window:AddTab({Title="Настройки"})

-- ============================================================
-- РЕЕСТР OnChanged (для конфигов и биндов)
-- ============================================================
local OnChangedRegistry = {}
getgenv().FH_OnChangedRegistry = OnChangedRegistry
local function registerOnChanged(name, cb) OnChangedRegistry[name] = cb end
local function fireRegistered(name, value)
    local cb = OnChangedRegistry[name]
    if cb then pcall(cb, value) end
end
getgenv().FH_RegisterOnChanged = registerOnChanged
getgenv().FH_FireRegistered = fireRegistered

local function addOpt(container, method, name, opts, callback)
    local ok, opt = pcall(function() return container[method](container, name, opts) end)
    if not ok or not opt then
        warn("[FH] Не удалось создать опцию: " .. tostring(name))
        return nil
    end
    if callback then
        pcall(function() opt:OnChanged(callback) end)
        registerOnChanged(name, callback)
    end
    return opt
end
getgenv().FH_AddOpt = addOpt

-- ============================================================
-- NOTIFY
-- ============================================================
local lastNotify = {}
local function Notify(title, content, dur)
    local k = tostring(title) .. "|" .. tostring(content)
    if lastNotify[k] and (tick() - lastNotify[k]) < 0.5 then return end
    lastNotify[k] = tick()
    pcall(function()
        Fluent:Notify({Title=title, Content=content, Duration=dur or 3})
    end)
end
getgenv().FH_Notify = Notify

task.spawn(function()
    task.wait(1.0)
    Notify("FortniHub", "v" .. VERSION .. " — Release Candidate", 6)
    task.wait(1.5)
    Notify("FortniHub", "Создано HOTI & Ve315, фиксы: Steve", 6)
end)

-- ============================================================
-- UI SOUNDS
-- ============================================================
local UI_SOUND_IDS = {
    ["Enable 1"]     = "rbxassetid://100772509583336",
    ["Sparkle"]      = "rbxassetid://110241936966089",
    ["Laser Click"]  = "rbxassetid://18913006341",
    ["Enable 2"]     = "rbxassetid://84626036868067",
    ["Notify"]       = "rbxassetid://103421304020039",
}
local UISoundCfg = {
    Enabled = true,
    EnableSound = "Enable 1",
    DisableSound = "Enable 1",
}
getgenv().FH_UISoundCfg = UISoundCfg

local function playUISound(which)
    if not UISoundCfg.Enabled then return end
    local name = UISoundCfg[which]
    if not name then return end
    local id = UI_SOUND_IDS[name]
    if not id then return end
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = 0.55
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 4)
    end)
end
getgenv().FH_PlayUISound = playUISound

-- ============================================================
-- HUD (без ватермарки)
-- ============================================================
local HUDGui, FPSLabel, PingLabel, Pill
do
    pcall(function()
        for _, name in ipairs({"FH_HUD_v18","FH_HUD","FH_HUD_v19","FH_HUD_v20","FH_HUD_v21","FH_HUD_v22","FH_HUD_v23"}) do
            local old = CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
        end
        for _, name in ipairs({"FH_Watermark_v21","FH_Watermark","FH_Watermark_v22"}) do
            local old = CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)

    HUDGui = Instance.new("ScreenGui")
    HUDGui.Name = "FH_HUD_v23"
    HUDGui.ResetOnSpawn = false
    HUDGui.IgnoreGuiInset = true
    HUDGui.DisplayOrder = 500
    HUDGui.Parent = CoreGui

    Pill = Instance.new("Frame")
    Pill.Name = "Pill"
    Pill.AnchorPoint = Vector2.new(0.5, 0)
    Pill.Position = UDim2.new(0.5, 0, 0, 12)
    Pill.Size = UDim2.fromOffset(400, 40)
    Pill.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    Pill.BorderSizePixel = 0
    Pill.Active = true
    Pill.Parent = HUDGui
    Instance.new("UICorner", Pill).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", Pill)
    stroke.Color = Color3.fromRGB(138, 92, 246)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    local grad = Instance.new("UIGradient", Pill)
    grad.Rotation = 45
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40,30,60)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20,20,28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40,30,60)),
    })

    local dragging, dragStart, posStart, dragMoved = false, nil, nil, false
    local TAP = 6
    local function toggleMenu()
        local w = getgenv().FH_Window
        if w and type(w.Toggle) == "function" then
            local ok = pcall(function() w:Toggle() end)
            if ok then return end
        end
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.P, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.P, false, game)
        end)
    end
    Pill.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragMoved = false
            dragStart = i.Position; posStart = Pill.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - dragStart
            if math.abs(d.X) > TAP or math.abs(d.Y) > TAP then dragMoved = true end
            if dragMoved then
                Pill.Position = UDim2.new(
                    posStart.X.Scale, posStart.X.Offset + d.X,
                    posStart.Y.Scale, posStart.Y.Offset + d.Y)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1
        and i.UserInputType ~= Enum.UserInputType.Touch then return end
        if not dragging then return end
        local wasTap = not dragMoved
        dragging = false
        if wasTap then toggleMenu() end
    end)

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

    local s1 = seg(8, 130)
    local logo = Instance.new("TextLabel")
    logo.BackgroundTransparency = 1
    logo.Size = UDim2.fromOffset(120, 40)
    logo.Position = UDim2.fromOffset(12, 0)
    logo.Font = Enum.Font.GothamBold
    logo.Text = "FH"
    logo.TextSize = 20
    logo.TextColor3 = Color3.fromRGB(178, 152, 255)
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = s1
    div(142)

    local s2 = seg(146, 120)
    local fpsIcon = Instance.new("TextLabel")
    fpsIcon.BackgroundTransparency = 1
    fpsIcon.Size = UDim2.fromOffset(40, 40)
    fpsIcon.Position = UDim2.fromOffset(6, 0)
    fpsIcon.Font = Enum.Font.GothamBold
    fpsIcon.Text = "FPS"
    fpsIcon.TextSize = 13
    fpsIcon.TextColor3 = Color3.fromRGB(140, 140, 160)
    fpsIcon.TextXAlignment = Enum.TextXAlignment.Left
    fpsIcon.Parent = s2
    FPSLabel = Instance.new("TextLabel")
    FPSLabel.BackgroundTransparency = 1
    FPSLabel.Size = UDim2.fromOffset(60, 40)
    FPSLabel.Position = UDim2.fromOffset(46, 0)
    FPSLabel.Font = Enum.Font.GothamBold
    FPSLabel.Text = "60"
    FPSLabel.TextSize = 15
    FPSLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
    FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
    FPSLabel.Parent = s2
    div(270)

    local s3 = seg(274, 110)
    local pingIcon = Instance.new("TextLabel")
    pingIcon.BackgroundTransparency = 1
    pingIcon.Size = UDim2.fromOffset(30, 40)
    pingIcon.Position = UDim2.fromOffset(6, 0)
    pingIcon.Font = Enum.Font.GothamBold
    pingIcon.Text = "ms"
    pingIcon.TextSize = 13
    pingIcon.TextColor3 = Color3.fromRGB(140, 140, 160)
    pingIcon.TextXAlignment = Enum.TextXAlignment.Left
    pingIcon.Parent = s3
    PingLabel = Instance.new("TextLabel")
    PingLabel.BackgroundTransparency = 1
    PingLabel.Size = UDim2.fromOffset(60, 40)
    PingLabel.Position = UDim2.fromOffset(36, 0)
    PingLabel.Font = Enum.Font.GothamBold
    PingLabel.Text = "0"
    PingLabel.TextSize = 15
    PingLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
    PingLabel.TextXAlignment = Enum.TextXAlignment.Left
    PingLabel.Parent = s3

    local fc, lastSec = 0, os.clock()
    AddConn("HUD_FPS", RunService.Heartbeat:Connect(function()
        fc = fc + 1
        local now = os.clock()
        if now - lastSec >= 1 then
            local cur = fc; fc = 0; lastSec = now
            local c = cur < 30 and Color3.fromRGB(255,80,80)
                or (cur < 60 and Color3.fromRGB(255,200,80) or Color3.fromRGB(80,240,120))
            if FPSLabel and FPSLabel.Parent then
                FPSLabel.Text = tostring(cur)
                FPSLabel.TextColor3 = c
            end
        end
    end))

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
        if ok and PingLabel and PingLabel.Parent then
            local c = p < 60 and Color3.fromRGB(80,240,120)
                or (p < 120 and Color3.fromRGB(255,200,80) or Color3.fromRGB(255,80,80))
            PingLabel.Text = tostring(p)
            PingLabel.TextColor3 = c
        end
    end))
end

-- ============================================================
-- BACKTRACK 1.0 — синхронизированный с пингом
-- ============================================================
local BacktrackCore = {}
do
    local BTCAP = 256
    local hist = table.create(BTCAP)
    for i = 1, BTCAP do hist[i] = {0, CFrame.identity} end
    local first, count = 1, 0
    local ping, pingAt = 0.15, 0
    local model, partsMap = nil, {}
    local enabled = false
    local trackCol = Color3.fromRGB(255, 60, 60)
    local usePing = true
    local manualDelay = 0.15
    local hbConn

    local function kill()
        if model then pcall(function() model:Destroy() end) model = nil end
        partsMap = {}
        first, count = 1, 0
    end

    local function build()
        kill()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        char.Archivable = true
        local ok, m = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not m then return end
        local origParts = {}
        for _, o in ipairs(char:GetDescendants()) do
            if o:IsA("BasePart") then origParts[#origParts+1] = o end
        end
        local ci = 0
        for _, o in ipairs(m:GetDescendants()) do
            if o:IsA("Script") or o:IsA("LocalScript") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("BasePart") then
                o.Anchored = true
                o.CanCollide = false
                o.CanQuery = false
                o.CastShadow = false
                if o.Name == "HumanoidRootPart" then
                    o.Transparency = 1
                else
                    o.Material = Enum.Material.ForceField
                    o.Color = trackCol
                    o.Transparency = 0
                end
                ci = ci + 1
                if origParts[ci] then
                    partsMap[#partsMap+1] = {clone = o, orig = origParts[ci]}
                end
            end
        end
        local h = m:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:Destroy() end) end
        m.Parent = Workspace
        model = m
    end

    local function tickBt()
        if not enabled then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not model then build() if not model then return end end
        if not model.Parent then model.Parent = Workspace end

        local now = os.clock()
        local cf = hrp.CFrame
        if count < BTCAP then count = count + 1
        else first = first % BTCAP + 1 end
        local slot = hist[(first + count - 2) % BTCAP + 1]
        slot[1], slot[2] = now, cf

        if now - pingAt >= 0.25 then
            pingAt = now
            local ok, v = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            end)
            ping = math.clamp((ok and v) or 0.15, 0.03, 0.6)
        end

        local delay = usePing and ping or manualDelay
        local target = now - delay
        local tcf = cf
        for k = count, 1, -1 do
            local s = hist[(first + k - 2) % BTCAP + 1]
            if s[1] <= target then tcf = s[2]; break end
        end

        local inv = hrp.CFrame:Inverse()
        for i = 1, #partsMap do
            local p = partsMap[i]
            if p.clone and p.clone.Parent and p.orig and p.orig.Parent then
                p.clone.CFrame = tcf * (inv * p.orig.CFrame)
            end
        end
    end

    function BacktrackCore.setEnabled(v)
        enabled = v
        if v then
            if not hbConn then hbConn = RunService.Heartbeat:Connect(tickBt) end
            if not model then build() end
        else
            kill()
        end
    end
    function BacktrackCore.setColor(c)
        trackCol = c
        if model then
            for _, p in ipairs(model:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    p.Color = c
                end
            end
        end
    end
    function BacktrackCore.setUsePing(v) usePing = v end
    function BacktrackCore.setManualDelay(v) manualDelay = tonumber(v) or 0.15 end

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if enabled then build() end
    end)
end
getgenv().FH_BacktrackCore = BacktrackCore

-- ============================================================
-- BACKTRACK 2.0 (бывш. Client Ghost) — расширенный
-- ============================================================
local Backtrack2Core = {}
do
    local folder = Workspace:FindFirstChild("FH_BacktrackFolder")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "FH_BacktrackFolder"
        folder.Parent = Workspace
    end
    local ghostModel, ghostPairs, lastChar = nil, {}, nil
    local active = false
    local cfg = {
        Transparency = 50,
        Color = Color3.fromRGB(255, 100, 100),
        NoTexture = false,
        UsePing = true,
        ManualDelay = 0.15,
    }
    local history = {}

    local function cleanup()
        if ghostModel then pcall(function() ghostModel:Destroy() end) end
        ghostModel, ghostPairs, lastChar = nil, {}, nil
    end
    local function paint()
        if not ghostModel then return end
        local tr = cfg.Transparency / 100
        pcall(function()
            local bc = ghostModel:FindFirstChildOfClass("BodyColors")
            if bc then bc:Destroy() end
        end)
        for _, pair in ipairs(ghostPairs) do
            local g = pair.ghost
            pcall(function()
                if g:IsA("BasePart") then
                    g.Transparency = tr
                    g.Color = cfg.Color
                    if cfg.NoTexture then
                        g.Material = Enum.Material.SmoothPlastic
                        if g:IsA("MeshPart") then g.TextureID = "" end
                    end
                end
            end)
        end
    end
    local function build(char)
        cleanup()
        lastChar = char
        char.Archivable = true
        local ok, clone = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not clone then return end
        ghostModel = clone
        ghostModel.Name = "FH_BacktrackV2"
        ghostModel.Parent = folder
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
        local hrp = clone:FindFirstChild("HumanoidRootPart")
        if hrp then hrp:Destroy() end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanQuery = false
                d.CanTouch = false
                d.Massless = true
            end
        end
        ghostPairs = {}
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                local g
                if d.Parent == char then
                    g = clone:FindFirstChild(d.Name)
                elseif d.Parent and d.Parent:IsA("Accessory") then
                    local acc = clone:FindFirstChild(d.Parent.Name)
                    if acc then g = acc:FindFirstChild(d.Name) end
                end
                if g and g:IsA("BasePart") then
                    ghostPairs[#ghostPairs+1] = {real = d, ghost = g}
                end
            end
        end
        paint()
    end

    RunService.RenderStepped:Connect(function()
        if not active then
            if ghostModel then cleanup() end
            return
        end
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            if ghostModel then cleanup() end
            return
        end
        if lastChar ~= char then build(char) end
        if not ghostModel or ghostModel.Parent ~= folder then return end

        local snap = {t = tick(), parts = {}}
        for _, pair in ipairs(ghostPairs) do
            snap.parts[pair.real] = pair.real.CFrame
        end
        history[#history+1] = snap
        local cutoff = tick() - 2
        while #history > 0 and history[1].t < cutoff do
            table.remove(history, 1)
        end

        local wantTime
        if cfg.UsePing then
            local ping = 0
            pcall(function()
                ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            wantTime = tick() - math.clamp(ping / 1000, 0.02, 0.5)
        else
            wantTime = tick() - math.clamp(cfg.ManualDelay, 0, 1)
        end

        local chosen
        for i = #history, 1, -1 do
            if history[i].t <= wantTime then chosen = history[i]; break end
        end
        if not chosen and #history > 0 then chosen = history[1] end
        if chosen then
            for _, pair in ipairs(ghostPairs) do
                if chosen.parts[pair.real] then
                    pair.ghost.CFrame = chosen.parts[pair.real]
                end
            end
        end
    end)

    function Backtrack2Core.setEnabled(v)
        active = v
        if not v then cleanup() end
    end
    function Backtrack2Core.setTransparency(v) cfg.Transparency = tonumber(v) or 50; paint() end
    function Backtrack2Core.setColor(c) cfg.Color = c; paint() end
    function Backtrack2Core.setNoTexture(v) cfg.NoTexture = v; paint() end
    function Backtrack2Core.setUsePing(v) cfg.UsePing = v end
    function Backtrack2Core.setManualDelay(v) cfg.ManualDelay = tonumber(v) or 0.15 end
end
getgenv().FH_Backtrack2Core = Backtrack2Core

-- UI Бэктрек
do
    local btSec = Tabs.Visual:AddSection({Name="Бэктрек 1.0"})
    addOpt(btSec, "AddToggle", "BacktrackOn", {Title="Включить", Default=false}, function(v)
        BacktrackCore.setEnabled(v)
    end)
    addOpt(btSec, "AddColorPicker", "BacktrackCol", {Title="Цвет", Default=Color3.fromRGB(255,60,60)}, function(c)
        BacktrackCore.setColor(c)
    end)
    addOpt(btSec, "AddToggle", "BacktrackUsePing", {Title="Задержка по пингу", Default=true}, function(v)
        BacktrackCore.setUsePing(v)
    end)
    addOpt(btSec, "AddSlider", "BacktrackManualDelay", {Title="Ручная задержка (сек)", Min=0.02, Max=0.6, Default=0.15, Rounding=2}, function(v)
        BacktrackCore.setManualDelay(v)
    end)

    local bt2Sec = Tabs.Visual:AddSection({Name="Бэктрек 2.0"})
    addOpt(bt2Sec, "AddToggle", "Backtrack2On", {Title="Включить", Default=false}, function(v)
        Backtrack2Core.setEnabled(v)
    end)
    addOpt(bt2Sec, "AddSlider", "Backtrack2Transparency", {Title="Прозрачность (%)", Min=0, Max=100, Default=50, Rounding=0}, function(v)
        Backtrack2Core.setTransparency(v)
    end)
    addOpt(bt2Sec, "AddColorPicker", "Backtrack2Color", {Title="Цвет", Default=Color3.fromRGB(255,100,100)}, function(c)
        Backtrack2Core.setColor(c)
    end)
    addOpt(bt2Sec, "AddToggle", "Backtrack2NoTexture", {Title="Убрать текстуры", Default=false}, function(v)
        Backtrack2Core.setNoTexture(v)
    end)
    addOpt(bt2Sec, "AddToggle", "Backtrack2UsePing", {Title="Задержка по пингу", Default=true}, function(v)
        Backtrack2Core.setUsePing(v)
    end)
    addOpt(bt2Sec, "AddSlider", "Backtrack2ManualDelay", {Title="Ручная задержка (сек)", Min=0.02, Max=0.6, Default=0.15, Rounding=2}, function(v)
        Backtrack2Core.setManualDelay(v)
    end)
end

-- ============================================================
-- ЭМОЦИИ → АНИМАЦИИ
-- Убраны: строка поиска, поиск эмодзи, кнопка списка.
-- Priority = Movement, Looped = false. Играются ПОВЕРХ ходьбы.
-- ============================================================
do
    local EMOTE_LIST = {
        ["Default Dance"]      = 80877772569772,
        ["Floss Dance"]        = 5917570207,
        ["Griddy"]             = 116065653184749,
        ["Macarena"]           = 91274761264433,
        ["Kazotsky"]           = 97629500912487,
        ["Gangnam Style"]      = 77205409178702,
        ["Miku Dance"]         = 117734400993750,
        ["Slickback"]          = 103789826265487,
        ["Torture Dance"]      = 116099356619436,
        ["Nyan Nyan!"]         = 73796726960568,
        ["Dio Pose"]           = 76736978166708,
        ["Teto Dance"]         = 93031502567721,
        ["Michael Myers"]      = 88229016850146,
        ["Family Guy"]         = 78459263478161,
        ["SpongeBob Shuffle"]  = 107899954696611,
        ["Helicopter"]         = 84555218084038,
        ["Conga"]              = 97547955535086,
        ["Plug Walk"]          = 100359724990859,
        ["Billy Bounce"]       = 126516908191316,
        ["Kawaii Groove"]      = 77152953688098,
        ["Absolute Cinema"]    = 97258018304125,
        ["Flopping Fish"]      = 133142324349281,
        ["Cute Jump"]          = 80556794144838,
        ["Around Town"]        = 3576747102,
        ["Fashionable"]        = 3576745472,
        ["Swish"]              = 3821527813,
        ["Idol"]               = 4102317848,
        ["Sneaky"]             = 3576754235,
        ["Robot"]              = 3576721660,
        ["Twirl"]              = 3716633898,
        ["Bodybuilder"]        = 3994130516,
        ["Shuffle"]            = 4391208058,
        ["Dorky Dance"]        = 4212499637,
        ["Break Dance"]        = 5915773992,
        ["Zombie"]             = 4212496830,
        ["Cha Cha"]            = 6865013133,
        ["Rock On"]            = 5915782672,
        ["Hero Landing"]       = 5104377791,
        ["Victory Dance"]      = 15506503658,
        ["Monkey"]             = 3716636630,
        ["Salute"]             = 3360689775,
        ["Superhero Reveal"]   = 3696759798,
        ["Hype Dance"]         = 3696757129,
        ["Take The L"]         = 123159156696507,
        ["Belly Dancing"]      = 131939729732240,
        ["Rambunctious"]       = 134311528115559,
        ["Ballin"]             = 96293409369770,
        ["Skibidi"]            = 124828909173982,
        ["Virtual Insanity"]   = 83261816934732,
        ["Club Penguin"]       = 98099211500155,
        ["Push-Up"]            = 117922227854118,
        ["Split"]              = 98522218962476,
        ["HeadBanging"]        = 87447252507832,
        ["Jumpstyle"]          = 99563839802389,
        ["Paranoid"]           = 123407922818447,
        ["Smeeze"]             = 131683926643291,
        ["Slenderman"]         = 81926508907412,
        ["RONALDO"]            = 97547486465713,
        ["Electro Shuffle"]    = 96426537876059,
        ["Foreign Shuffle"]    = 101507732056031,
        ["Squidward Yell"]     = 109244554368414,
        ["Mewing / Mogging"]   = 135493514352956,
        ["Golden Freddy"]      = 122463450997235,
        ["Lethal Dance"]       = 77108921633993,
        ["At Ease"]            = 76993139936388,
        ["Barrel"]             = 84511772437190,
        ["Honored One"]        = 121643381580730,
        ["Sukuna"]             = 91839607010745,
        ["Do that thang"]      = 113772829398170,
        ["Squat?"]             = 95441477641149,
        ["Nya Anime Dance"]    = 126647057611522,
        ["Samba"]              = 6869813008,
        ["Sandwich Dance"]     = 4390121879,
        ["Swag Walk"]          = 10478377385,
        ["Vroom Vroom"]        = 18526410572,
        ["Jersey Joe"]         = 134149640725489,
        ["Wally West"]         = 133948663586698,
        ["Doodle Dance"]       = 107091254142209,
        ["Fishin"]             = 3994129128,
        ["Tree"]               = 4049634387,
        ["Godlike"]            = 3823158750,
        ["Dizzy"]              = 3934986896,
        ["Fancy Feet"]         = 3934988903,
        ["Top Rock"]           = 3570535774,
        ["Louder"]             = 3576751796,
        ["Jacks"]              = 3570649048,
        ["Air Dance"]          = 4646302011,
        ["Line Dance"]         = 4049646104,
        ["Baby Dance"]         = 4272484885,
        ["Dolphin Dance"]      = 5938365243,
        ["Wanna play?"]        = 16646438742,
        ["Side to Side"]       = 3762641826,
        ["Keeping Time"]       = 4646306072,
        ["Tantrum"]            = 5104374556,
        ["Fishing"]            = 3994129128,
        ["Get Out"]            = 3934984583,
        ["Greatest"]           = 3762654854,
        ["Jumping Wave"]       = 4940602656,
        ["Haha"]               = 4102315500,
        ["Agree"]              = 4849487550,
        ["Disagree"]           = 4849495710,
        ["Happy"]              = 4849499887,
        ["Bored"]              = 5230661597,
        ["High Wave"]          = 5915776835,
        ["Cower"]              = 4940597758,
        ["Shy"]                = 3576717965,
        ["Curtsy"]             = 4646306583,
        ["Celebrate"]          = 3994127840,
        ["Confused"]           = 4940592718,
        ["Beckon"]             = 5230615437,
        ["Sad"]                = 4849502101,
        ["Chicken Dance"]      = 4849493309,
        ["Sandwich Dance 2"]   = 4390121879,
        ["Stadium"]            = 3360686498,
        ["Bunny Hop"]          = 4646296016,
        ["Heisman Pose"]       = 3696763549,
        ["Point2"]             = 3576823880,
        ["Tilt"]               = 3360692915,
        ["Applaud"]            = 5915779043,
        ["Hello"]              = 3576686446,
        ["Vans Ollie"]         = 18305539673,
        ["Shrug"]              = 3576968026,
    }

    local emoteNames = {}
    for name in pairs(EMOTE_LIST) do emoteNames[#emoteNames+1] = name end
    table.sort(emoteNames, function(a, b) return a:lower() < b:lower() end)

    local sec = Tabs.Animations:AddSection({Name="Эмоции-анимации"})
    local currentTrack, currentAnim, currentId
    local drop = sec:AddDropdown("FHBigEmotePick", {
        Title = "Выбрать анимацию",
        Values = emoteNames,
        Default = emoteNames[1] or "Default Dance",
    })

    local function stopCurrent()
        if currentTrack then
            pcall(function() currentTrack:Stop() end)
            currentTrack = nil
        end
        if currentAnim then
            pcall(function() currentAnim:Destroy() end)
            currentAnim = nil
        end
        currentId = nil
    end

    local function playEmoteByName(name)
        local id = EMOTE_LIST[name]
        if not id then return end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then Notify("FH", "Персонаж не загружен", 2) return end
        stopCurrent()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. tostring(id)
        local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
        if ok and track then
            -- ВАЖНО: как АНИМАЦИЯ, а не эмоция
            track.Priority = Enum.AnimationPriority.Movement
            track.Looped = false
            track:Play(0.1)
            currentTrack = track
            currentAnim = anim
            currentId = id
            Notify("FH", "Анимация: " .. name, 2)
            track.Stopped:Connect(function()
                if currentTrack == track then
                    pcall(function() anim:Destroy() end)
                    currentTrack = nil
                    currentAnim = nil
                    currentId = nil
                end
            end)
        else
            anim:Destroy()
            Notify("FH", "Не удалось: " .. name, 2)
        end
    end

    sec:AddButton({Title="Запустить", Callback=function()
        local v = drop.Value
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" then playEmoteByName(v) end
    end})
    sec:AddButton({Title="Остановить", Callback=function()
        stopCurrent()
        Notify("FH", "Остановлено", 2)
    end})

    getgenv().FH_PlayEmote = playEmoteByName
end

-- ============================================================
-- ЗВУКИ (KITI-набор, старые SHITARO удалены)
-- ============================================================
local SoundKit = {}
do
    SoundKit.List = {
        "Default","Rust Headshot","Neverlose","Sparkle","Skeet",
        "Bubble","Bameware","Money","Notif","Shutter",
        "TF2 Critical","TF2 Hitsound","Bow Hit","OSU","OneNN",
        "Bell","Fatality","Bonk","Minecraft","Gamesense",
        "Weeb","Beep","Ding","Among Us","UwU",
        "Blood SFX","Blood Burst","LazerBeam","WindowsXPError",
        "Cod","Blood Impact","Pick",
    }
    SoundKit.Ids = {
        ["Default"]        = "rbxassetid://330595293",
        ["Rust Headshot"]  = "rbxassetid://138750331387064",
        ["Neverlose"]      = "rbxassetid://110168723447153",
        ["Sparkle"]        = "rbxassetid://110241936966089",
        ["Skeet"]          = "rbxassetid://5633695679",
        ["Bubble"]         = "rbxassetid://6534947588",
        ["Bameware"]       = "rbxassetid://3124331820",
        ["Money"]          = "rbxassetid://13956013041",
        ["Notif"]          = "rbxassetid://6696469190",
        ["Shutter"]        = "rbxassetid://10066921516",
        ["TF2 Critical"]   = "rbxassetid://296102734",
        ["TF2 Hitsound"]   = "rbxassetid://3455144981",
        ["Bow Hit"]        = "rbxassetid://1053296915",
        ["OSU"]            = "rbxassetid://7147454322",
        ["OneNN"]          = "rbxassetid://7349055654",
        ["Bell"]           = "rbxassetid://6534947240",
        ["Fatality"]       = "rbxassetid://6534947869",
        ["Bonk"]           = "rbxassetid://5766898159",
        ["Minecraft"]      = "rbxassetid://5869422451",
        ["Gamesense"]      = "rbxassetid://4817809188",
        ["Weeb"]           = "rbxassetid://6442965016",
        ["Beep"]           = "rbxassetid://8177256015",
        ["Ding"]           = "rbxassetid://7149516994",
        ["Among Us"]       = "rbxassetid://5700183626",
        ["UwU"]            = "rbxassetid://8679659744",
        ["Blood SFX"]      = "rbxassetid://8164951181",
        ["Blood Burst"]    = "rbxassetid://3781479909",
        ["LazerBeam"]      = "rbxassetid://130791043",
        ["WindowsXPError"] = "rbxassetid://160715357",
        ["Cod"]            = "rbxassetid://160432334",
        ["Blood Impact"]   = "rbxassetid://8164951181",
        ["Pick"]           = "rbxassetid://1347140027",
    }
    SoundKit.Cfg = {
        sheriffKill  = {on=false, name="Rust Headshot", volume=1},
        murderKill   = {on=false, name="Skeet", volume=1},
        sheriffShoot = {on=false, name="Sparkle", volume=0.6},
    }

    function SoundKit.play(name, volume)
        local id = SoundKit.Ids[name]
        if not id then return end
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = volume or 1
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 8)
        end)
    end

    local lastSnd = {sheriffKill=0, murderKill=0, sheriffShoot=0}
    local function getMyRole()
        local d = getRoundData()
        return d and d[LocalPlayer.Name] and d[LocalPlayer.Name].Role or nil
    end
    local hooked = {}
    local function hookPlayerDeath(pl)
        if not pl or hooked[pl] then return end
        hooked[pl] = true
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 8)
            if not hum then return end
            hum.Died:Connect(function()
                local myRole = getMyRole()
                local d = getRoundData()
                if type(d) ~= "table" then return end
                local deadInfo = d[pl.Name]
                if not deadInfo then return end
                local deadRole = deadInfo.Role
                local murdererAlive
                for nm, info in pairs(d) do
                    if type(info) == "table" and info.Role == "Murderer" and not info.Dead then
                        murdererAlive = nm
                        break
                    end
                end
                if deadRole == "Murderer" and (myRole == "Sheriff" or myRole == "Hero") and SoundKit.Cfg.sheriffKill.on then
                    local now = os.clock()
                    if now - lastSnd.sheriffKill >= 0.15 then
                        lastSnd.sheriffKill = now
                        SoundKit.play(SoundKit.Cfg.sheriffKill.name, SoundKit.Cfg.sheriffKill.volume)
                    end
                end
                if deadRole ~= "Murderer" and murdererAlive and SoundKit.Cfg.murderKill.on then
                    local now = os.clock()
                    if now - lastSnd.murderKill >= 0.15 then
                        lastSnd.murderKill = now
                        SoundKit.play(SoundKit.Cfg.murderKill.name, SoundKit.Cfg.murderKill.volume)
                    end
                end
            end)
        end
        if pl.Character then task.spawn(onChar, pl.Character) end
        pl.CharacterAdded:Connect(onChar)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookPlayerDeath(p) end
    Players.PlayerAdded:Connect(hookPlayerDeath)
    Players.PlayerRemoving:Connect(function(p) hooked[p] = nil end)

    task.spawn(function()
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices", 10)
                :WaitForChild("WeaponService", 10)
                :WaitForChild("GunFired", 10)
        end)
        if ok and remote then
            remote.OnClientEvent:Connect(function(tool)
                if not SoundKit.Cfg.sheriffShoot.on then return end
                local myRole = getMyRole()
                if not (myRole == "Sheriff" or myRole == "Hero") then return end
                local char = LocalPlayer.Character
                if not char then return end
                if typeof(tool) == "Instance" and tool:IsDescendantOf(char) then
                    local now = os.clock()
                    if now - lastSnd.sheriffShoot >= 0.05 then
                        lastSnd.sheriffShoot = now
                        SoundKit.play(SoundKit.Cfg.sheriffShoot.name, SoundKit.Cfg.sheriffShoot.volume)
                    end
                end
            end)
        end
    end)
end
getgenv().FH_SoundKit = SoundKit

do
    local sndSec = Tabs.Utility:AddSection({Name="Звуки игровых событий"})
    addOpt(sndSec, "AddToggle", "SndSheriffKill", {Title="Мы убили убийцу", Default=false}, function(v)
        SoundKit.Cfg.sheriffKill.on = v
    end)
    addOpt(sndSec, "AddDropdown", "SndSheriffKillName", {Title="  Звук", Values=SoundKit.List, Default="Rust Headshot"}, function(v)
        SoundKit.Cfg.sheriffKill.name = v
    end)
    addOpt(sndSec, "AddSlider", "SndSheriffKillVol", {Title="  Громкость", Min=0.1, Max=5, Default=1, Rounding=1}, function(v)
        SoundKit.Cfg.sheriffKill.volume = tonumber(v) or 1
    end)
    sndSec:AddButton({Title="  Прослушать", Callback=function()
        SoundKit.play(SoundKit.Cfg.sheriffKill.name, SoundKit.Cfg.sheriffKill.volume)
    end})

    addOpt(sndSec, "AddToggle", "SndMurderKill", {Title="Убийца кого-то убил", Default=false}, function(v)
        SoundKit.Cfg.murderKill.on = v
    end)
    addOpt(sndSec, "AddDropdown", "SndMurderKillName", {Title="  Звук", Values=SoundKit.List, Default="Skeet"}, function(v)
        SoundKit.Cfg.murderKill.name = v
    end)
    addOpt(sndSec, "AddSlider", "SndMurderKillVol", {Title="  Громкость", Min=0.1, Max=5, Default=1, Rounding=1}, function(v)
        SoundKit.Cfg.murderKill.volume = tonumber(v) or 1
    end)
    sndSec:AddButton({Title="  Прослушать", Callback=function()
        SoundKit.play(SoundKit.Cfg.murderKill.name, SoundKit.Cfg.murderKill.volume)
    end})

    addOpt(sndSec, "AddToggle", "SndSheriffShoot", {Title="Наш выстрел", Default=false}, function(v)
        SoundKit.Cfg.sheriffShoot.on = v
    end)
    addOpt(sndSec, "AddDropdown", "SndSheriffShootName", {Title="  Звук", Values=SoundKit.List, Default="Sparkle"}, function(v)
        SoundKit.Cfg.sheriffShoot.name = v
    end)
    addOpt(sndSec, "AddSlider", "SndSheriffShootVol", {Title="  Громкость", Min=0.1, Max=5, Default=0.6, Rounding=1}, function(v)
        SoundKit.Cfg.sheriffShoot.volume = tonumber(v) or 0.6
    end)
    sndSec:AddButton({Title="  Прослушать", Callback=function()
        SoundKit.play(SoundKit.Cfg.sheriffShoot.name, SoundKit.Cfg.sheriffShoot.volume)
    end})
end

-- ============================================================
-- UI SOUNDS вкладка
-- ============================================================
do
    local sec = Tabs.Utility:AddSection({Name="Звуки интерфейса"})
    addOpt(sec, "AddToggle", "FH_UISoundsOn", {Title="Включить", Default=true}, function(v)
        UISoundCfg.Enabled = v
    end)
    addOpt(sec, "AddDropdown", "FH_UISoundEnable", {Title="Звук включения", Values={"Enable 1","Sparkle","Laser Click","Enable 2","Notify"}, Default="Enable 1"}, function(v)
        UISoundCfg.EnableSound = v
        playUISound("EnableSound")
    end)
    addOpt(sec, "AddDropdown", "FH_UISoundDisable", {Title="Звук выключения", Values={"Enable 1","Sparkle","Laser Click","Enable 2","Notify"}, Default="Enable 1"}, function(v)
        UISoundCfg.DisableSound = v
        playUISound("DisableSound")
    end)
    sec:AddButton({Title="Тест вкл", Callback=function() playUISound("EnableSound") end})
    sec:AddButton({Title="Тест выкл", Callback=function() playUISound("DisableSound") end})

    -- Хук на каждое изменение любого toggle
    task.spawn(function()
        task.wait(1.2)
        for name, opt in pairs(Options) do
            if type(opt) == "table" and opt.OnChanged then
                local isBool = false
                pcall(function()
                    if opt.Type == "Toggle" or type(opt.Value) == "boolean" then
                        isBool = true
                    end
                end)
                if isBool then
                    local hooked = false
                    pcall(function()
                        opt:OnChanged(function(v)
                            if v then playUISound("EnableSound")
                            else playUISound("DisableSound") end
                        end)
                        hooked = true
                    end)
                end
            end
        end
    end)
end

-- ============================================================
-- ГРАФИК СКОРОСТИ (рабочая версия)
-- ============================================================
do
    local mgOn, mgCol = false, Color3.fromRGB(242, 242, 242)
    local mgWidth, mgHeight, mgOffset = 280, 72, 180
    local mgLines, mgShadows = {}, {}
    local mgCurrent
    local mgHist, mgAccum, mgSmooth = {}, 0, 0
    local mgSpan, mgStep = 2.8, 1/45
    local mgConn

    local function speed()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return 0 end
        local v = r.AssemblyLinearVelocity
        return Vector3.new(v.X, 0, v.Z).Magnitude
    end
    local function refSpeed()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        return math.max(1, (h and h.WalkSpeed) or 16)
    end

    local function mgClear()
        if mgConn then pcall(function() mgConn:Disconnect() end); mgConn = nil end
        if mgCurrent then pcall(function() mgCurrent:Remove() end); mgCurrent = nil end
        for i = 1, #mgLines do
            pcall(function() mgLines[i]:Remove() end)
            pcall(function() mgShadows[i]:Remove() end)
        end
        mgLines, mgShadows, mgHist = {}, {}, {}
        mgAccum = 0
    end

    local function ensureDrawings(count)
        while #mgLines < count do
            local s = Drawing.new("Line")
            s.Color = Color3.new(0, 0, 0)
            s.Thickness = 3
            s.Transparency = 0.4
            s.Visible = false
            mgShadows[#mgShadows+1] = s
            local l = Drawing.new("Line")
            l.Color = mgCol
            l.Thickness = 1.5
            l.Transparency = 1
            l.Visible = false
            mgLines[#mgLines+1] = l
        end
    end

    local function mgStart()
        mgClear()
        if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then
            Notify("FH", "Drawing API недоступен", 3)
            return
        end
        mgSmooth = speed()
        local now = os.clock()
        local cnt = math.ceil(mgSpan / mgStep)
        ensureDrawings(cnt + 4)
        for i = 0, cnt do
            mgHist[#mgHist+1] = {t = now - mgSpan + i * mgStep, v = mgSmooth}
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
            local raw = speed()
            mgSmooth = mgSmooth + (raw - mgSmooth) * (1 - math.exp(-dt * 18))
            mgAccum = mgAccum + dt
            local now2 = os.clock()
            if mgAccum >= mgStep then
                mgAccum = mgAccum % mgStep
                mgHist[#mgHist+1] = {t = now2, v = mgSmooth}
                local cutoff = now2 - mgSpan
                while #mgHist > 2 and mgHist[2].t < cutoff do
                    table.remove(mgHist, 1)
                end
            end

            local vp = Camera.ViewportSize
            local w = math.min(mgWidth, math.max(120, vp.X - 48))
            local h = math.min(mgHeight, math.max(36, vp.Y - 32))
            local left = math.floor(vp.X * 0.5 - w * 0.5)
            local center = math.clamp(math.floor(vp.Y * 0.5 + mgOffset), h * 0.5 + 8, vp.Y - h * 0.5 - 8)
            local ref = refSpeed()
            local startT = now2 - mgSpan
            local count = #mgHist

            ensureDrawings(count + 4)

            for i = 1, count - 1 do
                local a, b = mgHist[i], mgHist[i+1]
                local ap = math.clamp((a.t - startT) / mgSpan, 0, 1)
                local bp = math.clamp((b.t - startT) / mgSpan, 0, 1)
                local fade = math.clamp(math.min((ap + bp) * 6, (2 - ap - bp) * 5), 0, 1)
                local ay = center - (math.clamp(a.v / ref - 1, -1, 1)) * h * 0.44
                local by = center - (math.clamp(b.v / ref - 1, -1, 1)) * h * 0.44
                if mgLines[i] then
                    mgLines[i].From = Vector2.new(left + ap * w, ay)
                    mgLines[i].To = Vector2.new(left + bp * w, by)
                    mgLines[i].Transparency = fade
                    mgLines[i].Visible = fade > 0.02
                    mgLines[i].Color = mgCol
                    mgShadows[i].From = Vector2.new(left + ap * w, ay)
                    mgShadows[i].To = Vector2.new(left + bp * w, by)
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
            end
            mgCurrent.Text = tostring(math.floor(mgSmooth + 0.5))
            mgCurrent.Position = Vector2.new(left + w + 5, center - 7)
            mgCurrent.Color = mgCol
            mgCurrent.Visible = true
        end)
    end

    local sec = Tabs.Visual:AddSection({Name="График скорости"})
    addOpt(sec, "AddToggle", "MovGraphOn", {Title="Включить", Default=false}, function(v)
        mgOn = v
        if v then mgStart() else mgClear() end
    end)
    addOpt(sec, "AddColorPicker", "MovGraphCol", {Title="Цвет", Default=Color3.fromRGB(242,242,242)}, function(c)
        mgCol = c
        for i = 1, #mgLines do mgLines[i].Color = c end
    end)
    addOpt(sec, "AddSlider", "MovGraphW", {Title="Ширина", Min=180, Max=420, Default=280, Rounding=0}, function(v)
        mgWidth = tonumber(v) or 280
    end)
    addOpt(sec, "AddSlider", "MovGraphH", {Title="Высота", Min=40, Max=120, Default=72, Rounding=0}, function(v)
        mgHeight = tonumber(v) or 72
    end)
    addOpt(sec, "AddSlider", "MovGraphY", {Title="Смещение Y", Min=-200, Max=400, Default=180, Rounding=0}, function(v)
        mgOffset = tonumber(v) or 180
    end)
end

-- ============================================================
-- СКАЙБОКС — только Toggle + Dropdown (один выбор)
-- Свой Skybox ID удалён полностью
-- ============================================================
do
    local skyboxEnabled = false
    local currentSkyName = nil
    local origSky, origSkyParent = nil, nil

    local SKYBOXES = {
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
        ["Red Night"] = {
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

    local function clearSky()
        local s = Lighting:FindFirstChild("FH_CustomSky")
        if s then s:Destroy() end
    end
    local function applySky(name)
        if not origSky then
            local existing = Lighting:FindFirstChildOfClass("Sky")
            if existing and existing.Name ~= "FH_CustomSky" then
                origSky = existing
                origSkyParent = existing.Parent
                pcall(function() existing.Parent = nil end)
            end
        end
        clearSky()
        local data = SKYBOXES[name]
        if not data then return end
        local sky = Instance.new("Sky")
        sky.Name = "FH_CustomSky"
        for k, v in pairs(data) do
            pcall(function() sky[k] = v end)
        end
        sky.Parent = Lighting
        currentSkyName = name
    end
    local function restoreSky()
        clearSky()
        if origSky then
            pcall(function() origSky.Parent = origSkyParent or Lighting end)
            origSky, origSkyParent = nil, nil
        end
        currentSkyName = nil
    end

    local sec = Tabs.Effects:AddSection({Name="Скайбокс"})
    addOpt(sec, "AddToggle", "SkyOn", {Title="Включить скайбокс", Default=false}, function(v)
        skyboxEnabled = v
        if v then
            local cur = Options.SkyName and Options.SkyName.Value or "Jungle"
            applySky(cur)
        else
            restoreSky()
        end
    end)
    addOpt(sec, "AddDropdown", "SkyName", {
        Title = "Выбор неба",
        Values = {"Jungle","Blossom","Red Night","Purple","Foggy"},
        Default = "Jungle",
    }, function(v)
        if skyboxEnabled then applySky(v) end
    end)
end

-- ============================================================
-- ПЛЕЙЛИСТ (заглушка)
-- ============================================================
do
    local sec = Tabs.Utility:AddSection({Name="Плейлист"})
    addOpt(sec, "AddDropdown", "FHPlaylistPick", {
        Title = "Трек",
        Values = {"(плейлист в разработке)"},
        Default = "(плейлист в разработке)",
    }, function() end)
    sec:AddButton({Title="Играть", Callback=function()
        Notify("FH", "Плейлист в разработке", 2)
    end})
    sec:AddButton({Title="Стоп", Callback=function()
        Notify("FH", "Плейлист в разработке", 2)
    end})
end

-- ============================================================
-- AURA 2.0 — базовая часть (расширение в Part 2/2)
-- ============================================================
local AuraCore = {}
do
    local auraIds = {
        angel     = "97658130917593",
        starlight = "134645216613107",
        heavenly  = "139300897520961",
        ribbon    = "132069507632161",
        sakura    = "81755778619404",
        wind      = "80694081850877",
        flow      = "119913533725648",
        star      = "73754563740680",
    }
    local cache, parts, conn = {}, {}, nil
    local curType, curCol = "angel", Color3.fromRGB(133, 220, 255)

    local function loadModel(name)
        if cache[name] then return cache[name] end
        local id = auraIds[name]
        if not id then return nil end
        local ok, objs = pcall(game.GetObjects, game, "rbxassetid://" .. id)
        if ok and objs and objs[1] then
            cache[name] = objs[1]
            return objs[1]
        end
    end
    local function colorModel(m, c)
        local seq = ColorSequence.new(c)
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("PointLight") then d.Color = c
            elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
                d.Color = seq
            end
        end
    end
    local function clear()
        for i = #parts, 1, -1 do
            pcall(function() parts[i]:Destroy() end)
            parts[i] = nil
        end
    end
    local function apply()
        clear()
        local c = LocalPlayer.Character
        if not c then return end
        local src = loadModel(curType)
        if not src then return end
        colorModel(src, curCol)
        local clone = src:Clone()
        for _, part in ipairs(clone:GetChildren()) do
            local tgt = c:FindFirstChild(part.Name)
            if tgt and tgt:IsA("BasePart") then
                for _, child in ipairs(part:GetChildren()) do
                    child.Parent = tgt
                    parts[#parts+1] = child
                end
            end
        end
        clone:Destroy()
    end
    local function start()
        if conn then return end
        conn = LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if AuraCore.isEnabled() then apply() end
        end)
        task.spawn(apply)
    end
    local function stop()
        if conn then pcall(function() conn:Disconnect() end); conn = nil end
        clear()
    end

    function AuraCore.setEnabled(v) if v then start() else stop() end end
    function AuraCore.setType(t) curType = t; if conn then task.spawn(apply) end end
    function AuraCore.setColor(c)
        curCol = c
        for _, m in pairs(cache) do colorModel(m, c) end
        if conn then task.spawn(apply) end
    end
    function AuraCore.isEnabled() return conn ~= nil end
end
getgenv().FH_AuraCore = AuraCore

do
    local sec = Tabs.Effects:AddSection({Name="Aura 2.0"})
    addOpt(sec, "AddToggle", "AuraOn", {Title="Включить ауру", Default=false}, function(v)
        AuraCore.setEnabled(v)
    end)
    addOpt(sec, "AddDropdown", "AuraType", {
        Title = "Тип",
        Values = {"angel","starlight","heavenly","ribbon","sakura","wind","flow","star"},
        Default = "angel",
    }, function(v)
        AuraCore.setType(v)
    end)
    addOpt(sec, "AddColorPicker", "AuraCol", {Title="Цвет", Default=Color3.fromRGB(133,220,255)}, function(c)
        AuraCore.setColor(c)
    end)
end

-- ============================================================
-- НАСТРОЙКИ + КОНФИГИ (с фиксом Enum.KeyCode)
-- ============================================================
do
    local tS = Tabs.Settings
    local setSec = tS:AddSection({Name="Основные"})
    addOpt(setSec, "AddToggle", "ShowHUD", {Title="Показывать HUD", Default=true}, function(v)
        if HUDGui then HUDGui.Enabled = v end
    end)
    addOpt(setSec, "AddSlider", "FPSCap", {Title="Лимит FPS (0 - без)", Min=0, Max=9999, Default=0, Rounding=0}, function(v)
        pcall(function() if setfpscap then setfpscap(tonumber(v) or 0) end end)
    end)
    setSec:AddButton({Title="Переподключиться", Callback=function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end})
    setSec:AddButton({Title="Сменить сервер", Callback=function()
        pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
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
    addOpt(setSec, "AddToggle", "AntiAFK", {Title="Anti-AFK", Default=true}, function() end)
    AddConn("AntiAFK", LocalPlayer.Idled:Connect(function()
        if Options.AntiAFK and Options.AntiAFK.Value then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0,0), Camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), Camera.CFrame)
            end)
        end
    end))
    setSec:AddButton({Title="Выгрузить скрипт", Callback=function()
        for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
        Connections = {}
        if HUDGui then HUDGui:Destroy() end
        if Window then pcall(function() Window:Destroy() end) end
        Notify("FH", "Скрипт выгружен", 3)
    end})

    -- ============================================================
    -- КОНФИГИ
    -- ============================================================
    local cfgSec = tS:AddSection({Name="Конфиги"})
    local CONFIG_DIR = "FortniHub_Configs/"
    local CONFIG_EXT = ".txt"

    local function ensureDir()
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return false end
        local ok, has = pcall(isfolder, CONFIG_DIR)
        if not ok then return false end
        if has then return true end
        return pcall(makefolder, CONFIG_DIR) == true
    end
    local function listConfigs()
        local out = {}
        if type(listfiles) ~= "function" then return out end
        if not ensureDir() then return out end
        local ok, files = pcall(listfiles, CONFIG_DIR)
        if not ok or type(files) ~= "table" then return out end
        for _, f in ipairs(files) do
            local name = string.match(f, "([^/\\]+)" .. CONFIG_EXT .. "$")
            if name then out[#out+1] = name end
        end
        return out
    end

    -- ФИКС: безопасная сериализация строк
    local function serialize(v)
        if typeof(v) == "Color3" then
            return string.format("C:%.6f,%.6f,%.6f", v.R, v.G, v.B)
        end
        if typeof(v) == "EnumItem" then
            if v.EnumType == Enum.KeyCode then return "K:" .. v.Name end
            return "E:" .. tostring(v.EnumType) .. "|" .. v.Name
        end
        local t = type(v)
        if t == "number" then return "N:" .. tostring(v) end
        if t == "boolean" then return "B:" .. tostring(v) end
        if t == "string" then
            -- ГЛАВНЫЙ ФИКС: проверяем через safeEnum, а не напрямую
            if isKeyCodeString(v) then return "K:" .. v end
            v = v:gsub("\n", "\\n"):gsub("\t", "\\t")
            return "S:" .. v
        end
        if t == "table" then
            local isArr = true
            for k in pairs(v) do if type(k) ~= "number" then isArr = false; break end end
            if isArr then
                local p = {}
                for i = 1, #v do p[#p+1] = tostring(v[i]) end
                return "L:" .. table.concat(p, ",")
            else
                local p = {}
                for k, val in pairs(v) do p[#p+1] = tostring(k) .. "=" .. tostring(val) end
                return "D:" .. table.concat(p, ";")
            end
        end
        return nil
    end

    -- ФИКС: безопасная десериализация
    local function deserialize(s)
        local prefix, rest = string.match(s, "^(%a):(.*)$")
        if not prefix then return nil end
        if prefix == "K" then
            return safeEnum(Enum.KeyCode, rest)
        end
        if prefix == "C" then
            local r, g, b = string.match(rest, "([^,]+),([^,]+),([^,]+)")
            if r and g and b then
                return Color3.new(tonumber(r), tonumber(g), tonumber(b))
            end
            return nil
        end
        if prefix == "E" then
            local et, name = string.match(rest, "^([^|]+)|(.+)$")
            if et and name then
                local E = Enum[et]
                if E then return safeEnum(E, name) end
            end
            return nil
        end
        if prefix == "N" then return tonumber(rest) end
        if prefix == "B" then return rest == "true" end
        if prefix == "S" then
            return rest:gsub("\\n", "\n"):gsub("\\t", "\t")
        end
        if prefix == "L" then
            local out = {}
            for piece in string.gmatch(rest, "[^,]+") do
                local n = tonumber(piece)
                if n then out[#out+1] = n else out[#out+1] = piece end
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
        if type(writefile) ~= "function" then Notify("FH", "Нет writefile", 4); return false end
        if not ensureDir() then Notify("FH", "Не создал папку", 4); return false end
        local lines = {"-- FortniHub Config: " .. tostring(name), "-- " .. os.date("%Y-%m-%d %H:%M:%S")}
        for optionName, option in pairs(Options) do
            if option and option.Value ~= nil then
                local ser = serialize(option.Value)
                if ser then lines[#lines+1] = optionName .. "\t" .. ser end
            end
        end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        local ok = pcall(writefile, path, table.concat(lines, "\n"))
        if ok then Notify("FH", "Сохранено: " .. name, 3); return true end
        Notify("FH", "Ошибка сохранения", 3)
        return false
    end

    local function loadConfig(name)
        if type(readfile) ~= "function" then Notify("FH", "Нет readfile", 4); return false end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        local ok, data = pcall(readfile, path)
        if not ok or type(data) ~= "string" then Notify("FH", "Ошибка чтения", 3); return false end
        local loaded, bindLoaded = 0, 0
        local BS = getgenv().FH_BindState
        for line in string.gmatch(data, "[^\r\n]+") do
            if line:sub(1, 2) ~= "--" then
                local key, ser = string.match(line, "^([^\t]+)\t(.+)$")
                if key and ser then
                    if key:sub(1, 9) == "BIND_KEY_" then
                        local id = key:sub(10)
                        local enumVal
                        if ser:sub(1, 2) == "K:" then
                            enumVal = safeEnum(Enum.KeyCode, ser:sub(3))
                        elseif ser:sub(1, 2) == "E:" then
                            local raw = ser:sub(3)
                            local et, kn = string.match(raw, "^([^|]+)|(.+)$")
                            if et and kn then
                                local E = Enum[et]
                                if E then enumVal = safeEnum(E, kn) end
                            end
                        elseif ser:sub(1, 2) == "S:" then
                            enumVal = safeEnum(Enum.KeyCode, ser:sub(3))
                        end
                        if enumVal then
                            pcall(function()
                                if Options[key] and Options[key].SetValue then
                                    Options[key]:SetValue(enumVal)
                                end
                            end)
                            if BS and BS[id] then BS[id].key = enumVal end
                            bindLoaded = bindLoaded + 1
                        else
                            pcall(function()
                                if Options[key] and Options[key].SetValue then
                                    Options[key]:SetValue(Enum.KeyCode.Unknown)
                                end
                            end)
                            if BS and BS[id] then BS[id].key = nil end
                        end
                        loaded = loaded + 1
                    else
                        local val = deserialize(ser)
                        if val ~= nil and Options[key] and Options[key].SetValue then
                            pcall(function() Options[key]:SetValue(val) end)
                            fireRegistered(key, val)
                            loaded = loaded + 1
                        end
                    end
                end
            end
        end
        Notify("FH", "Загружено: " .. name .. " (" .. loaded .. ", биндов: " .. bindLoaded .. ")", 4)
        return true
    end

    local function deleteConfig(name)
        if type(delfile) ~= "function" then Notify("FH", "Нет delfile", 4); return false end
        local ok = pcall(delfile, CONFIG_DIR .. name .. CONFIG_EXT)
        if ok then Notify("FH", "Удалено: " .. name, 2); return true end
        return false
    end

    local curList = listConfigs()
    if #curList == 0 then curList = {"(нет конфигов)"} end
    local drop = cfgSec:AddDropdown("ConfigPick", {
        Title = "Выбрать конфиг", Values = curList, Default = curList[1],
    })
    local function refreshList()
        local list = listConfigs()
        if #list == 0 then list = {"(нет конфигов)"} end
        pcall(function()
            drop:SetValues(list)
            if drop.Generate then drop:Generate() end
        end)
    end

    cfgSec:AddInput("ConfigName", {Title="Имя конфига", Default="my_config"})
    cfgSec:AddButton({Title="Сохранить", Callback=function()
        local name = Options.ConfigName and Options.ConfigName.Value or "my_config"
        if type(name) ~= "string" or name == "" then Notify("FH", "Введи имя", 3); return end
        if saveConfig(name) then refreshList() end
    end})
    cfgSec:AddButton({Title="Загрузить", Callback=function()
        local name = Options.ConfigPick and Options.ConfigPick.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3); return
        end
        loadConfig(name)
    end})
    cfgSec:AddButton({Title="Удалить", Callback=function()
        local name = Options.ConfigPick and Options.ConfigPick.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3); return
        end
        if deleteConfig(name) then refreshList() end
    end})
    cfgSec:AddButton({Title="Обновить список", Callback=refreshList})

    if HUDGui then HUDGui.Enabled = true end
end

-- ============================================================
-- БИНДЫ (использует FH_BindState)
-- ============================================================
do
    local tB = Tabs.Binds
    local BIND_LIST = {
        {id="SilentEnabled",   title="Тихий выстрел",       cat="Бой",       opt="SilentEnabled"},
        {id="KAOn",            title="Килл Аура",           cat="Бой",       opt="KAOn"},
        {id="SpeedToggle",     title="Скорость",            cat="Движение",  opt="SpeedToggle"},
        {id="Noclip",          title="Noclip",              cat="Движение",  opt="Noclip"},
        {id="FlyToggle",       title="Полёт",               cat="Движение",  opt="FlyToggle"},
        {id="BhopOn",          title="Банихоп",             cat="Движение",  opt="BhopOn"},
        {id="BacktrackOn",     title="Бэктрек 1.0",         cat="Визуал",    opt="BacktrackOn"},
        {id="Backtrack2On",    title="Бэктрек 2.0",         cat="Визуал",    opt="Backtrack2On"},
        {id="AuraOn",          title="Aura 2.0",            cat="Эффекты",   opt="AuraOn"},
        {id="ToolFling",       title="Отброс",              cat="Троллинг",  opt="ToolFling"},
    }
    local BindState = {}
    for _, e in ipairs(BIND_LIST) do
        BindState[e.id] = {key=nil, touchOn=false, btn=nil, def=e}
    end
    getgenv().FH_BindState = BindState

    local touchGui = Instance.new("ScreenGui")
    touchGui.Name = "FH_TouchBinds_v23"
    touchGui.ResetOnSpawn = false
    touchGui.IgnoreGuiInset = true
    touchGui.DisplayOrder = 400
    pcall(function() touchGui.Parent = (gethui and gethui()) or CoreGui end)
    if not touchGui.Parent then touchGui.Parent = CoreGui end

    local function fireBind(id)
        local st = BindState[id]
        if not st then return end
        local opt = Options[st.def.opt]
        if opt and opt.Value ~= nil then
            opt:SetValue(not opt.Value)
            Notify("FH", st.def.title .. ": " .. tostring(opt.Value), 1.2)
        end
    end

    local function centerSpawn()
        local vp = Camera.ViewportSize or Vector2.new(1280, 720)
        return vp.X * 0.5 - 75, vp.Y * 0.5 - 17
    end

    local function makeTouchButton(id)
        local st = BindState[id]
        if not st or st.btn then return end
        local btn = Instance.new("TextButton")
        btn.Name = "FH_BTN_" .. id
        btn.Size = UDim2.fromOffset(150, 34)
        local sx, sy = centerSpawn()
        btn.Position = UDim2.fromOffset(sx, sy)
        btn.BackgroundColor3 = Color3.fromRGB(28, 22, 42)
        btn.BorderSizePixel = 0
        btn.Text = st.def.title
        btn.TextColor3 = Color3.fromRGB(235, 225, 255)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.Active = true
        btn.ZIndex = 3
        btn.Parent = touchGui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(138, 92, 246)
        stroke.Thickness = 1
        stroke.Transparency = 0.35
        local dragging, dragStart, posStart, moved = false, nil, nil, false
        btn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true; moved = false
                dragStart = i.Position; posStart = btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - dragStart
                if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
                if moved then
                    btn.Position = UDim2.new(
                        posStart.X.Scale, posStart.X.Offset + d.X,
                        posStart.Y.Scale, posStart.Y.Offset + d.Y)
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1
            and i.UserInputType ~= Enum.UserInputType.Touch then return end
            if not dragging then return end
            local wasTap = not moved
            dragging = false
            if wasTap then fireBind(id) end
        end)
        st.btn = btn
    end
    local function killTouchButton(id)
        local st = BindState[id]
        if not st then return end
        if st.btn then pcall(function() st.btn:Destroy() end); st.btn = nil end
    end

    local listSec = tB:AddSection({Name="Модули"})
    local currentCat = nil
    for _, def in ipairs(BIND_LIST) do
        if def.cat ~= currentCat then
            currentCat = def.cat
            pcall(function()
                listSec:AddButton({Title="— " .. currentCat .. " —", Callback=function() end})
            end)
        end
        local st = BindState[def.id]
        local kb = listSec:AddKeybind("BIND_KEY_" .. def.id, {Title=def.title, Default="Unknown"})
        if kb then
            kb:OnChanged(function(k)
                if typeof(k) == "EnumItem" then
                    st.key = k
                    Notify("FH", "Бинд: " .. def.title .. " > " .. tostring(k), 2)
                else
                    st.key = nil
                end
            end)
        end
        registerOnChanged("BIND_KEY_" .. def.id, function(k)
            if typeof(k) == "EnumItem" then st.key = k else st.key = nil end
        end)
        addOpt(listSec, "AddToggle", "BIND_TCH_" .. def.id, {
            Title = "  Кнопка: " .. def.title, Default = false,
        }, function(v)
            st.touchOn = v
            if v then makeTouchButton(def.id) else killTouchButton(def.id) end
        end)
    end
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        for id, st in pairs(BindState) do
            if st.key and input.KeyCode == st.key then fireBind(id) end
        end
    end)

    local setSec = tB:AddSection({Name="Управление биндами"})
    setSec:AddButton({Title="Сбросить все бинды", Callback=function()
        local count = 0
        for id, st in pairs(BindState) do
            st.key = nil
            if Options["BIND_KEY_" .. id] then
                pcall(function() Options["BIND_KEY_" .. id]:SetValue(Enum.KeyCode.Unknown) end)
                count = count + 1
            end
        end
        Notify("FH", "Сброшено биндов: " .. count, 2)
    end})
    setSec:AddButton({Title="Удалить все кнопки", Callback=function()
        for id, st in pairs(BindState) do
            st.touchOn = false
            if Options["BIND_TCH_" .. id] then
                pcall(function() Options["BIND_TCH_" .. id]:SetValue(false) end)
            end
            killTouchButton(id)
        end
        Notify("FH", "Все кнопки удалены", 2)
    end})
end

-- ============================================================
-- ФИНАЛ PART 1/2
-- ============================================================
pcall(function() Window:SelectTab(1) end)
print("[FH] ============================================")
print("[FH] Part 1/2 loaded — FortniHub v" .. VERSION)
print("[FH] Fixed: Enum.KeyCode bug, watermark, emotes, sounds, backtrack, aura")
print("[FH] Removed: GameSounds, weapon model, custom skybox ID, AdvFarm")
print("[FH] Added: Backtrack 2.0 (Client Ghost), Playlist stub")
print("[FH] ============================================")
getgenv().FH_Part1Loaded = true
-- ============================================================
-- one.lua — FortniHub MM2 v21.0 RC — ЧАСТЬ 2/2
-- Combat / Movement / ESP / Farm / Troll / Utility
-- ============================================================
-- ЧТО В PART 2/2:
--   Silent Aim, KillAura, AutoGrab
--   Movement (Speed, Fly, Noclip, Bhop, Spinbot, InfJump, Freeze)
--   ESP (Box, Name, Dist, Skeleton, Chams, Arrows)
--   Tracer, WorldFX, MurderFX
--   FarmV3 (единственный фарм — AdvFarm удалён)
--   Troll (TP-tool, Fake Death, Teleport)
--   Utility (Invis, Anti-fling, Anti-void, VoteBoost, WaterProt, FadeDisabler, AntiCoin)
--   TradeHelper, VoteDuper
--   Beam Effects
--   Aura 2.0 (доп. часть)
--   Anti-Aim, Player Panel, Language, Jump Circle, RTX
-- ============================================================

if not getgenv().FH_Part1Loaded then
    warn("[FH] Part 1/2 не загружена — Part 2/2 пропущена.")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Tabs = getgenv().FH_Tabs
local Options = getgenv().Options
local Window = getgenv().FH_Window
local Notify = getgenv().FH_Notify
local addOpt = getgenv().FH_AddOpt
local registerOnChanged = getgenv().FH_RegisterOnChanged
local fireRegistered = getgenv().FH_FireRegistered
local getHRP = getgenv().getHRP
local getHum = getgenv().getHum
local getRoundData = getgenv().getRoundData
local getRoleFromData = getgenv().getRoleFromData
local playUISound = getgenv().FH_PlayUISound

if not Tabs or not Options or not Window or not Notify then
    warn("[FH] Нужные переменные не найдены — Part 2/2 пропущена.")
    return
end

-- ============================================================
-- 1. SILENT AIM
-- ============================================================
do
    local SS = {
        enabled=false, predict=true, auto_on=false, auto_delay=0,
        am_sheriff=false, fire_gap=0, last_shot=0,
    }
    getgenv().SILENT_S = SS

    local rs = ReplicatedStorage
    local target_player, target_char, target_part, target_hum
    local last_fire_stamp = 0
    local weapon_service, orig_mouse, orig_screen, hook_mouse, hook_screen
    local snap_t, snap_p = table.create(48, 0), table.create(48, Vector3.zero)
    local snap_n, snap_i = 0, 0
    local EC = {ping=0, seen=false, step=0, step_seen=false}

    local function holds(c, n) return c ~= nil and c:FindFirstChild(n) ~= nil end
    local function lp_has_gun()
        return holds(LocalPlayer.Character, "Gun") or holds(LocalPlayer:FindFirstChildOfClass("Backpack"), "Gun")
    end

    local function refresh_target()
        local found
        local data = getRoundData()
        if type(data) == "table" then
            local me = data[LocalPlayer.Name]
            SS.am_sheriff = (me ~= nil and (me.Role == "Sheriff" or me.Role == "Hero")) or lp_has_gun()
            for name, d in pairs(data) do
                if type(d) == "table" and d.Role == "Murderer" and not d.Dead then
                    found = Players:FindFirstChild(name); break
                end
            end
        else
            SS.am_sheriff = lp_has_gun()
        end
        if not found then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and holds(plr.Character, "Knife") then
                    found = plr; break
                end
            end
        end
        if found ~= target_player then
            target_player = found
            target_char, target_part, target_hum = nil, nil, nil
        end
        if not found then return end
        local char = found.Character
        if char ~= target_char then
            target_char = char; target_part, target_hum = nil, nil
        end
        if not char then return end
        if not target_part or not target_part.Parent then
            target_part = char:FindFirstChild("HumanoidRootPart")
                or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
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
    local ignore_base, ignore_work = {}, {}

    local function refresh_ignore()
        table.clear(ignore_base)
        local char = LocalPlayer.Character
        if char then ignore_base[1] = char end
        local ok, tagged = pcall(function() return CollectionService:GetTagged("WeaponPassthrough") end)
        if ok and type(tagged) == "table" then
            for k = 1, #tagged do ignore_base[#ignore_base+1] = tagged[k] end
        end
    end

    local function trace(origin, direction)
        refresh_ignore()
        table.clear(ignore_work)
        for k = 1, #ignore_base do ignore_work[k] = ignore_base[k] end
        ray_params.FilterDescendantsInstances = ignore_work
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

    local function snap_push(now, pos)
        snap_i = snap_i % 48 + 1
        snap_t[snap_i] = now
        snap_p[snap_i] = pos
        if snap_n < 48 then snap_n = snap_n + 1 end
    end
    local function snap_get(k)
        local idx = (snap_i - k - 1) % 48 + 1
        return snap_t[idx], snap_p[idx]
    end

    local TR = {part=nil, pos=nil, time=0, vel=Vector3.zero, ready=false, last_fresh=Vector3.zero}

    local function track(now)
        local part = target_part
        if not part or not part.Parent then return end
        if part ~= TR.part or not TR.pos then
            TR.part, TR.pos, TR.time = part, part.Position, now
            snap_n, snap_i = 0, 0
            snap_push(now, part.Position)
            TR.ready = false
            return
        end
        local dt = now - TR.time
        if dt <= 0 or dt > 0.75 then return end
        snap_push(now, part.Position)
        if snap_n >= 3 then
            local t0, p0 = snap_get(0)
            local t2, p2 = snap_get(2)
            local dtt = t0 - t2
            if dtt > 0 then
                TR.vel = (p0 - p2) / dtt
                TR.ready = true
            end
        end
        TR.pos, TR.time = part.Position, now
    end

    local function sample_ping()
        local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000 end)
        if ok and v and v == v then
            EC.ping = math.clamp(v, 0, 1)
            EC.seen = true
        end
    end

    local function predict_offset()
        if not SS.predict or not TR.ready then return Vector3.zero end
        local horizon = EC.seen and EC.ping or 0.1
        return Vector3.new(TR.vel.X, 0, TR.vel.Z) * horizon
    end

    local hit_names = {"HumanoidRootPart","UpperTorso","Torso","LowerTorso","Head"}
    local function pick_point(origin)
        local char = target_char
        if not char then return nil end
        local off = predict_offset()
        for _, n in ipairs(hit_names) do
            local p = char:FindFirstChild(n)
            if p and p:IsA("BasePart") then
                local pt = p.Position + off
                if not origin then return pt end
                local d = pt - origin
                local res = trace(origin, d)
                if not res or (res.Instance and res.Instance:IsDescendantOf(char)) then
                    return pt
                end
            end
        end
        return nil
    end

    local function get_weapon_service()
        if weapon_service then return weapon_service end
        local ok, m = pcall(function()
            return require(rs:WaitForChild("ClientServices"):WaitForChild("WeaponService"))
        end)
        if ok and type(m) == "table" then weapon_service = m end
        return weapon_service
    end

    local function install_hooks()
        local m = get_weapon_service()
        if not m then return end
        if not hook_mouse then
            hook_mouse = function(self, ...)
                sample_ping()
                if SS.enabled and SS.am_sheriff and target_alive() then
                    local cf = origin_cframe()
                    local aim = pick_point(cf and cf.Position)
                    if aim then return CFrame.new(aim) end
                end
                return orig_mouse(self, ...)
            end
            hook_screen = function(self, x, y, ...)
                sample_ping()
                if SS.enabled and SS.am_sheriff and target_alive() then
                    local cf = origin_cframe()
                    local aim = pick_point(cf and cf.Position)
                    if aim then return CFrame.new(aim) end
                end
                return orig_screen(self, x, y, ...)
            end
        end
        pcall(function() setreadonly(m, false) end)
        if type(m.GetMouseTargetCFrame) == "function" and m.GetMouseTargetCFrame ~= hook_mouse then
            orig_mouse = m.GetMouseTargetCFrame
            pcall(function() m.GetMouseTargetCFrame = hook_mouse end)
        end
        if type(m.GetTargetPosition) == "function" and m.GetTargetPosition ~= hook_screen then
            orig_screen = m.GetTargetPosition
            pcall(function() m.GetTargetPosition = hook_screen end)
        end
    end

    local function get_gun()
        local c = LocalPlayer.Character
        if c then
            local g = c:FindFirstChild("Gun")
            if g then return g, true end
        end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            local g = bp:FindFirstChild("Gun")
            if g then return g, false end
        end
        return nil, false
    end

    local function auto_step(now)
        if not SS.auto_on or not SS.enabled or not SS.am_sheriff or not target_alive() then return end
        local gun, equipped = get_gun()
        if not gun then return end
        if not equipped then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(gun) end) end
            return
        end
        if now - math.max(last_fire_stamp, SS.last_shot) < SS.auto_delay then return end
        local cf = origin_cframe()
        if not cf then return end
        local aim = pick_point(cf.Position)
        if not aim then return end
        local remote = gun:FindFirstChild("Shoot")
        if remote and remote:IsA("RemoteEvent") then
            pcall(function() remote:FireServer(cf, CFrame.new(aim)) end)
            SS.last_shot = now
        end
    end

    local next_role = 0
    local conn = RunService.Heartbeat:Connect(function()
        if not SS.enabled then return end
        local now = os.clock()
        if now >= next_role then
            next_role = now + 0.2
            refresh_target()
        end
        sample_ping()
        track(now)
        pcall(install_hooks)
        auto_step(now)
    end)
    getgenv().FH_SilentConn = conn

    local sec = Tabs.Combat:AddSection({Name="Тихий выстрел"})
    addOpt(sec, "AddToggle", "SilentEnabled", {Title="Включить", Default=false}, function(v)
        SS.enabled = v
        if v then
            task.spawn(function() pcall(install_hooks); pcall(refresh_target) end)
        end
        Notify("FH", "Silent " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)
    addOpt(sec, "AddToggle", "SilentPredict", {Title="Предсказание", Default=true}, function(v)
        SS.predict = v
    end)
    addOpt(sec, "AddToggle", "SilentAuto", {Title="Авто-выстрел", Default=false}, function(v)
        SS.auto_on = v
    end)
    addOpt(sec, "AddSlider", "SilentAutoDelay", {
        Title="Задержка авто", Default=0, Min=0, Max=600, Rounding=0,
    }, function(v) SS.auto_delay = (tonumber(v) or 0) / 1000 end)
end

-- ============================================================
-- 2. KILL AURA
-- ============================================================
do
    local kaV1 = {on=false, dist=30, lastHit=0}
    local kaV2 = {on=false, dist=30, lastHit=0}
    local version = "v2"

    local function hitLoop(state)
        if not state.on then return end
        if tick() - state.lastHit < 0.05 then return end
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
            if p ~= LocalPlayer and p.Character then
                local th = p.Character:FindFirstChildOfClass("Humanoid")
                local tp = p.Character:FindFirstChild("HumanoidRootPart")
                if th and th.Health > 0 and tp
                and (tp.Position - my.Position).Magnitude <= state.dist then
                    victims[#victims+1] = tp
                end
            end
        end
        if #victims > 0 then
            pcall(function() stabbed:FireServer() end)
            for _, v in ipairs(victims) do
                pcall(function() touched:FireServer(v) end)
            end
            state.lastHit = tick()
        end
    end

    RunService.Heartbeat:Connect(function() pcall(hitLoop, kaV1) end)
    RunService.Heartbeat:Connect(function() pcall(hitLoop, kaV2) end)

    local sec = Tabs.Combat:AddSection({Name="Килл Аура"})
    addOpt(sec, "AddDropdown", "KAVersion", {Title="Версия", Values={"v1","v2"}, Default="v2"}, function(v)
        version = v
        kaV1.on = false
        kaV2.on = false
        if Options.KAOn and Options.KAOn.Value then
            kaV1.on = v == "v1"
            kaV2.on = v == "v2"
        end
    end)
    addOpt(sec, "AddToggle", "KAOn", {Title="Включить", Default=false}, function(v)
        kaV1.on = v and version == "v1"
        kaV2.on = v and version == "v2"
    end)
    addOpt(sec, "AddSlider", "KADist", {Title="Радиус", Min=5, Max=60, Default=30, Rounding=0}, function(v)
        local n = tonumber(v) or 30
        kaV1.dist = n; kaV2.dist = n
    end)
end

-- ============================================================
-- 3. AUTO GRAB GUN
-- ============================================================
do
    local enabled, isGrabbing = false, false
    local gunCache = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "GunDrop" then gunCache[v] = true end
    end
    Workspace.DescendantAdded:Connect(function(v)
        if v.Name == "GunDrop" then gunCache[v] = true end
    end)
    Workspace.DescendantRemoving:Connect(function(v)
        if v.Name == "GunDrop" then gunCache[v] = nil end
    end)

    local function nearestGun(my)
        local best, bd = nil, math.huge
        for gun in pairs(gunCache) do
            if gun.Parent and gun:IsA("BasePart") then
                local d = (gun.Position - my.Position).Magnitude
                if d < bd then bd = d; best = gun end
            end
        end
        return best
    end

    RunService.Heartbeat:Connect(function()
        if not enabled or isGrabbing then return end
        if getgenv().FH_INVIS_ACTIVE then return end
        if getRoleFromData(LocalPlayer) == "murderer" then return end
        local char = LocalPlayer.Character
        if not char then return end
        if char:FindFirstChild("Gun") then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp and bp:FindFirstChild("Gun") then return end
        local my = char:FindFirstChild("HumanoidRootPart")
        if not my then return end
        local gun = nearestGun(my)
        if not gun then return end
        isGrabbing = true
        task.spawn(function()
            local rp = my.CFrame
            for i = 1, 3 do
                if my and my.Parent then my.CFrame = gun.CFrame end
                task.wait(0.04)
                pcall(function()
                    firetouchinterest(my, gun, 0)
                    task.wait(0.02)
                    firetouchinterest(my, gun, 1)
                end)
                local c = LocalPlayer.Character
                if c and c:FindFirstChild("Gun") then break end
                local b = LocalPlayer:FindFirstChildOfClass("Backpack")
                if b and b:FindFirstChild("Gun") then break end
            end
            if my and my.Parent then
                my.CFrame = rp
                my.AssemblyLinearVelocity = Vector3.zero
                my.AssemblyAngularVelocity = Vector3.zero
            end
            isGrabbing = false
        end)
    end)

    local sec = Tabs.Combat:AddSection({Name="Авто-подбор пистолета"})
    addOpt(sec, "AddToggle", "AutoGrabGun", {Title="Включить", Default=false}, function(v)
        enabled = v
    end)
end

-- ============================================================
-- 4. MOVEMENT
-- ============================================================
do
    local tM = Tabs.Movement
    local S = {frozen=false, freezeUpKey=Enum.KeyCode.Space, freezeDownKey=Enum.KeyCode.LeftAlt}

    local mvSec = tM:AddSection({Name="Основное"})
    addOpt(mvSec, "AddToggle", "SpeedToggle", {Title="Скорость", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "SpeedValue", {Title="Скорость ходьбы", Min=16, Max=500, Default=32, Rounding=0}, function() end)
    addOpt(mvSec, "AddToggle", "Noclip", {Title="Noclip", Default=false}, function() end)
    addOpt(mvSec, "AddToggle", "Spinbot", {Title="Spinbot", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "SpinSpeed", {Title="Скорость кручения", Min=1, Max=50, Default=8, Rounding=0}, function() end)
    addOpt(mvSec, "AddToggle", "InfJump", {Title="Бесконечный прыжок", Default=false}, function() end)
    addOpt(mvSec, "AddToggle", "JumpPowerToggle", {Title="Своя сила прыжка", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "JumpPowerVal", {Title="Сила прыжка", Min=50, Max=500, Default=100, Rounding=0}, function() end)
    addOpt(mvSec, "AddToggle", "FlyToggle", {Title="Полёт", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "FlySpeed", {Title="Скорость полёта", Min=20, Max=500, Default=60, Rounding=0}, function() end)
    addOpt(mvSec, "AddToggle", "BhopOn", {Title="Банихоп", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "BhopPower", {Title="Сила банихопа", Min=10, Max=150, Default=40, Rounding=0}, function() end)

    local flyGrav = Workspace.Gravity
    local function flyOff()
        Workspace.Gravity = flyGrav
        local hum = getHum()
        if hum then pcall(function() hum.PlatformStand = false end) end
        local hrp = getHRP()
        if hrp then
            local bv = hrp:FindFirstChild("FH_FlyBV")
            if bv then bv:Destroy() end
        end
    end
    registerOnChanged("FlyToggle", function(v)
        if v then flyGrav = Workspace.Gravity; Workspace.Gravity = 0
        else flyOff() end
    end)

    RunService.Heartbeat:Connect(function()
        local hum = getHum()
        if not hum then return end
        if Options.SpeedToggle and Options.SpeedToggle.Value then
            hum.WalkSpeed = (Options.SpeedValue and tonumber(Options.SpeedValue.Value)) or 32
        end
        if Options.JumpPowerToggle and Options.JumpPowerToggle.Value then
            hum.UseJumpPower = true
            local jp = (Options.JumpPowerVal and tonumber(Options.JumpPowerVal.Value)) or 100
            if hum.JumpPower ~= jp then hum.JumpPower = jp end
        end
        if Options.Spinbot and Options.Spinbot.Value then
            local hrp = getHRP()
            if hrp then
                local s = (Options.SpinSpeed and tonumber(Options.SpinSpeed.Value)) or 8
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(s), 0)
            end
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
                local sp = (Options.FreezeSpeed and tonumber(Options.FreezeSpeed.Value)) or 60
                local dir = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(S.freezeUpKey) then dir = dir + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(S.freezeDownKey) then dir = dir - Vector3.new(0,1,0) end
                local bv = hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero end
            end
        else
            local hrp = getHRP()
            if hrp then
                local bv = hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv:Destroy() end
            end
        end
    end)

    RunService.Stepped:Connect(function()
        if Options.Noclip and Options.Noclip.Value then
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end
    end)

    UserInputService.JumpRequest:Connect(function()
        if Options.InfJump and Options.InfJump.Value then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end)

    RunService.RenderStepped:Connect(function()
        if not (Options.FlyToggle and Options.FlyToggle.Value) then return end
        local hrp, hum = getHRP(), getHum()
        if not hrp or not hum then return end
        hum.PlatformStand = true
        local sp = (Options.FlySpeed and tonumber(Options.FlySpeed.Value)) or 60
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
        hrp.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero
    end)

    -- Bhop
    local bhopPower, wasJumping, isBoosting, bhopSpeed = 40, false, false, 0
    registerOnChanged("BhopPower", function(v) bhopPower = tonumber(v) or 40 end)
    RunService.Heartbeat:Connect(function()
        if not (Options.BhopOn and Options.BhopOn.Value) then
            wasJumping, isBoosting, bhopSpeed = false, false, 0
            return
        end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local st = hum:GetState()
        local jumping = st == Enum.HumanoidStateType.Jumping
        local airborne = jumping or st == Enum.HumanoidStateType.Freefall
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
                    dir = dir.Magnitude > 0 and dir.Unit or Vector3.zero
                end
            end
            if dir.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X*bhopSpeed, v.Y, dir.Z*bhopSpeed)
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
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X*sp, v.Y, dir.Z*sp)
            end
        end
        if not airborne then
            isBoosting = false
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then hum.Jump = true
            else bhopSpeed = 0 end
        end
        wasJumping = jumping
    end)

    -- Freeze section
    local freezeSec = tM:AddSection({Name="Заморозка"})
    addOpt(freezeSec, "AddToggle", "FreezeToggle", {Title="Включить", Default=false}, function(v) S.frozen = v end)
    addOpt(freezeSec, "AddSlider", "FreezeSpeed", {Title="Скорость", Min=20, Max=300, Default=60, Rounding=0}, function() end)
    local fUp = freezeSec:AddKeybind("FreezeUpKey", {Title="Кнопка ВВЕРХ", Default="Space"})
    if fUp then
        fUp:OnChanged(function(k) if typeof(k) == "EnumItem" then S.freezeUpKey = k end end)
    end
    local fDown = freezeSec:AddKeybind("FreezeDownKey", {Title="Кнопка ВНИЗ", Default="LeftAlt"})
    if fDown then
        fDown:OnChanged(function(k) if typeof(k) == "EnumItem" then S.freezeDownKey = k end end)
    end
end

-- ============================================================
-- 5. ESP
-- ============================================================
do
    local espState = {
        enabled=false, box=false, boxCol={Color3.fromRGB(255,255,255),1},
        name=false, nameCol={Color3.new(1,1,1),1},
        dist=false, distCol={Color3.fromRGB(220,220,220),1},
        skel=false, skelCol={Color3.new(1,1,1),1},
        chams=false,
        chamsFMur={Color3.fromRGB(255,60,60),0.55}, chamsOMur={Color3.fromRGB(255,60,60),0.15},
        chamsFInno={Color3.new(1,1,1),0.55}, chamsOInno={Color3.new(1,1,1),0.15},
        chamsFShf={Color3.fromRGB(0,153,255),0.55}, chamsOShf={Color3.fromRGB(0,153,255),0.15},
        chamsFHero={Color3.fromRGB(255,215,0),0.55}, chamsOHero={Color3.fromRGB(255,215,0),0.15},
        arrows=false, arrowMur=Color3.fromRGB(255,60,60), arrowInno=Color3.new(1,1,1),
        arrowShf=Color3.fromRGB(0,153,255), arrowHero=Color3.fromRGB(255,215,0),
        arrowSize=42, arrowDist=260, maxDist=500, allowLocal=false,
    }
    local drawCache = {}
    local chamsFolder = Instance.new("Folder")
    chamsFolder.Name = "FH_Chams"
    chamsFolder.Parent = Workspace

    local function classifyRole(p)
        local r = getRoleFromData(p)
        if r == "murderer" then return "Mur" end
        if r == "sheriff" then return "Shf" end
        if r == "hero" then return "Hero" end
        return "Inno"
    end
    local function roleColor(role)
        if role == "Mur" then return Color3.fromRGB(255,60,60) end
        if role == "Shf" then return Color3.fromRGB(0,153,255) end
        if role == "Hero" then return Color3.fromRGB(255,215,0) end
        return Color3.new(1,1,1)
    end
    local function getDraw(p)
        local d = drawCache[p]
        if d then return d end
        d = {box={}, name=nil, dist=nil, skel={}, arrow=nil}
        drawCache[p] = d
        return d
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
    local function dispose(e)
        for _, d in pairs(e.box) do pcall(function() d:Remove() end) end
        if e.name then pcall(function() e.name:Remove() end) end
        if e.dist then pcall(function() e.dist:Remove() end) end
        for _, d in pairs(e.skel) do pcall(function() d:Remove() end) end
        if e.arrow then pcall(function() e.arrow:Remove() end) end
    end
    local chams = {}
    local function killCham(p)
        local h = chams[p]
        if h then pcall(function() h:Destroy() end); chams[p] = nil end
    end
    local function ensureCham(p, char)
        local h = chams[p]
        if h and h.Parent and h.Adornee == char then return h end
        if h then pcall(function() h:Destroy() end) end
        h = Instance.new("Highlight")
        h.Name = "FH_" .. p.Name
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = char
        h.Parent = chamsFolder
        chams[p] = h
        return h
    end

    RunService.RenderStepped:Connect(function()
        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer and not espState.allowLocal then
                killCham(p)
            else
                local char = p.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart")
                    or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
                local head = char and char:FindFirstChild("Head")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and hrp and head and hum and hum.Health > 0 then
                    seen[p] = true
                    local role = classifyRole(p)
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    local fade = math.clamp(1 - dist / espState.maxDist, 0.15, 1)
                    if espState.enabled then
                        local headPos = head.Position + Vector3.new(0, head.Size.Y*0.5, 0)
                        local footPos = hrp.Position - Vector3.new(0, hrp.Size.Y*0.5 + (hum.HipHeight or 0), 0)
                        local hsp, hon = Camera:WorldToViewportPoint(headPos)
                        local fsp, fon = Camera:WorldToViewportPoint(footPos)
                        if hon or fon then
                            local e = getDraw(p)
                            if espState.box then
                                local w = math.max(40, (hsp.Y - fsp.Y) * 0.5)
                                local cx = (hsp.X + fsp.X) * 0.5
                                local l, r = cx - w, cx + w
                                local top, bot = hsp.Y, fsp.Y
                                local lines = {{l,top,r,top},{r,top,r,bot},{r,bot,l,bot},{l,bot,l,top}}
                                for i, ln in ipairs(lines) do
                                    local line = ensureBox(e, i)
                                    line.From = Vector2.new(ln[1], ln[2])
                                    line.To = Vector2.new(ln[3], ln[4])
                                    line.Color = espState.boxCol[1]
                                    line.Transparency = (espState.boxCol[2] or 1) * fade
                                    line.Visible = true
                                end
                                for i = 5, #e.box do e.box[i].Visible = false end
                            else
                                for _, ln in pairs(e.box) do ln.Visible = false end
                            end
                            if espState.name then
                                if not e.name then
                                    e.name = Drawing.new("Text")
                                    e.name.Size = 13; e.name.Center = true; e.name.Outline = true
                                end
                                e.name.Text = p.Name
                                e.name.Position = Vector2.new((hsp.X + fsp.X)*0.5, hsp.Y - 18)
                                e.name.Color = espState.nameCol[1]
                                e.name.Transparency = (espState.nameCol[2] or 1) * fade
                                e.name.Visible = true
                            elseif e.name then e.name.Visible = false end
                            if espState.dist then
                                if not e.dist then
                                    e.dist = Drawing.new("Text")
                                    e.dist.Size = 12; e.dist.Center = true; e.dist.Outline = true
                                end
                                e.dist.Text = string.format("%d studs", math.floor(dist))
                                e.dist.Position = Vector2.new((hsp.X + fsp.X)*0.5, fsp.Y + 4)
                                e.dist.Color = espState.distCol[1]
                                e.dist.Transparency = (espState.distCol[2] or 1) * fade
                                e.dist.Visible = true
                            elseif e.dist then e.dist.Visible = false end
                            if espState.skel then
                                local bones = {
                                    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
                                    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},
                                    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},
                                    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},
                                    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},
                                }
                                for i, b in ipairs(bones) do
                                    local p1 = char:FindFirstChild(b[1])
                                    local p2 = char:FindFirstChild(b[2])
                                    if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                                        local s1, o1 = Camera:WorldToViewportPoint(p1.Position)
                                        local s2, o2 = Camera:WorldToViewportPoint(p2.Position)
                                        if not e.skel[i] then
                                            local dr = Drawing.new("Line")
                                            dr.Thickness = 1; dr.Transparency = 1
                                            e.skel[i] = dr
                                        end
                                        local dr = e.skel[i]
                                        if o1 and o2 then
                                            dr.From = Vector2.new(s1.X, s1.Y)
                                            dr.To = Vector2.new(s2.X, s2.Y)
                                            dr.Color = espState.skelCol[1]
                                            dr.Transparency = (espState.skelCol[2] or 1) * fade
                                            dr.Visible = true
                                        else dr.Visible = false end
                                    elseif e.skel[i] then e.skel[i].Visible = false end
                                end
                            else
                                for _, dr in pairs(e.skel) do dr.Visible = false end
                            end
                            if espState.arrows then
                                local vp = Camera.ViewportSize
                                local onScreen = hsp.X >= 0 and hsp.X <= vp.X and hsp.Y >= 0 and hsp.Y <= vp.Y
                                if onScreen then
                                    if e.arrow then e.arrow.Visible = false end
                                else
                                    if not e.arrow then
                                        e.arrow = Drawing.new("Triangle")
                                        e.arrow.Filled = true
                                    end
                                    local cx, cy = vp.X*0.5, vp.Y*0.5
                                    local dir = Vector2.new(hsp.X - cx, hsp.Y - cy)
                                    if dir.Magnitude < 0.01 then dir = Vector2.new(0, 1) end
                                    dir = dir.Unit
                                    local px = cx + dir.X * espState.arrowDist
                                    local py = cy + dir.Y * espState.arrowDist
                                    local sz = espState.arrowSize
                                    local perp = Vector2.new(-dir.Y, dir.X)
                                    e.arrow.PointA = Vector2.new(px + dir.X*sz*0.5, py + dir.Y*sz*0.5)
                                    e.arrow.PointB = Vector2.new(px - dir.X*sz*0.5 + perp.X*sz*0.5, py - dir.Y*sz*0.5 + perp.Y*sz*0.5)
                                    e.arrow.PointC = Vector2.new(px - dir.X*sz*0.5 - perp.X*sz*0.5, py - dir.Y*sz*0.5 - perp.Y*sz*0.5)
                                    e.arrow.Color = role == "Mur" and espState.arrowMur
                                        or (role == "Shf" and espState.arrowShf
                                        or (role == "Hero" and espState.arrowHero or espState.arrowInno))
                                    e.arrow.Transparency = fade
                                    e.arrow.Visible = true
                                end
                            elseif e.arrow then e.arrow.Visible = false end
                        end
                    else
                        local e = drawCache[p]
                        if e then
                            for _, ln in pairs(e.box) do ln.Visible = false end
                            if e.name then e.name.Visible = false end
                            if e.dist then e.dist.Visible = false end
                            for _, dr in pairs(e.skel) do dr.Visible = false end
                            if e.arrow then e.arrow.Visible = false end
                        end
                    end
                    if espState.chams then
                        local h = ensureCham(p, char)
                        local fill = espState["chamsF"..role] or espState.chamsFInno
                        local outl = espState["chamsO"..role] or espState.chamsOInno
                        h.FillColor = fill[1]; h.FillTransparency = fill[2]
                        h.OutlineColor = outl[1]; h.OutlineTransparency = outl[2]
                    else killCham(p) end
                else
                    local e = drawCache[p]
                    if e then
                        for _, ln in pairs(e.box) do ln.Visible = false end
                        if e.name then e.name.Visible = false end
                        if e.dist then e.dist.Visible = false end
                        for _, dr in pairs(e.skel) do dr.Visible = false end
                        if e.arrow then e.arrow.Visible = false end
                    end
                    killCham(p)
                end
            end
        end
        for p, e in pairs(drawCache) do
            if not seen[p] then
                dispose(e)
                drawCache[p] = nil
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(p) killCham(p) end)

    local espSec = Tabs.Visual:AddSection({Name="ESP Игроков"})
    addOpt(espSec, "AddToggle", "ESPOn", {Title="Включить ESP", Default=false}, function(v)
        espState.enabled = v
        if not v then
            for _, e in pairs(drawCache) do dispose(e) end
            drawCache = {}
        end
    end)
    addOpt(espSec, "AddToggle", "ESPBox", {Title="Рамка", Default=false}, function(v) espState.box = v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxCol", {Title="Цвет рамки", Default=Color3.new(1,1,1)}, function(c) espState.boxCol[1] = c end)
    addOpt(espSec, "AddToggle", "ESPName", {Title="Имя", Default=false}, function(v) espState.name = v end)
    addOpt(espSec, "AddColorPicker", "ESPNameCol", {Title="Цвет имени", Default=Color3.new(1,1,1)}, function(c) espState.nameCol[1] = c end)
    addOpt(espSec, "AddToggle", "ESPDist", {Title="Дистанция", Default=false}, function(v) espState.dist = v end)
    addOpt(espSec, "AddColorPicker", "ESPDistCol", {Title="Цвет дистанции", Default=Color3.fromRGB(220,220,220)}, function(c) espState.distCol[1] = c end)
    addOpt(espSec, "AddToggle", "ESPSkel", {Title="Скелет", Default=false}, function(v) espState.skel = v end)
    addOpt(espSec, "AddColorPicker", "ESPSkelCol", {Title="Цвет скелета", Default=Color3.new(1,1,1)}, function(c) espState.skelCol[1] = c end)
    addOpt(espSec, "AddToggle", "ESPChams", {Title="Свечение", Default=false}, function(v) espState.chams = v end)

    local function chamsPair(prefix, role, defFill, defOut)
        addOpt(espSec, "AddColorPicker", "ChamsF"..prefix, {Title=role.." заливка", Default=defFill}, function(c)
            espState["chamsF"..prefix][1] = c
        end)
        addOpt(espSec, "AddSlider", "ChamsFA"..prefix, {Title=role.." прозр", Min=0, Max=1, Default=0.55, Rounding=2}, function(v)
            espState["chamsF"..prefix][2] = tonumber(v) or 0.55
        end)
        addOpt(espSec, "AddColorPicker", "ChamsO"..prefix, {Title=role.." обводка", Default=defOut}, function(c)
            espState["chamsO"..prefix][1] = c
        end)
        addOpt(espSec, "AddSlider", "ChamsOA"..prefix, {Title=role.." прозр обводки", Min=0, Max=1, Default=0.15, Rounding=2}, function(v)
            espState["chamsO"..prefix][2] = tonumber(v) or 0.15
        end)
    end
    chamsPair("Mur", "Убийца", Color3.fromRGB(255,60,60), Color3.fromRGB(255,120,120))
    chamsPair("Inno", "Мирный", Color3.new(1,1,1), Color3.new(1,1,1))
    chamsPair("Shf", "Шериф", Color3.fromRGB(0,153,255), Color3.fromRGB(120,200,255))
    chamsPair("Hero", "Герой", Color3.fromRGB(255,215,0), Color3.fromRGB(255,240,140))

    addOpt(espSec, "AddToggle", "ESPArrows", {Title="Стрелки", Default=false}, function(v) espState.arrows = v end)
    addOpt(espSec, "AddColorPicker", "ESPArrMur", {Title="Убийца", Default=Color3.fromRGB(255,60,60)}, function(c) espState.arrowMur = c end)
    addOpt(espSec, "AddColorPicker", "ESPArrInno", {Title="Мирный", Default=Color3.new(1,1,1)}, function(c) espState.arrowInno = c end)
    addOpt(espSec, "AddColorPicker", "ESPArrShf", {Title="Шериф", Default=Color3.fromRGB(0,153,255)}, function(c) espState.arrowShf = c end)
    addOpt(espSec, "AddColorPicker", "ESPArrHero", {Title="Герой", Default=Color3.fromRGB(255,215,0)}, function(c) espState.arrowHero = c end)
    addOpt(espSec, "AddSlider", "ESPArrSz", {Title="Размер стрелок", Min=16, Max=96, Default=42, Rounding=0}, function(v) espState.arrowSize = tonumber(v) or 42 end)
    addOpt(espSec, "AddSlider", "ESPArrDist", {Title="Дистанция стрелок", Min=40, Max=520, Default=260, Rounding=0}, function(v) espState.arrowDist = tonumber(v) or 260 end)
    addOpt(espSec, "AddSlider", "ESPMaxDist", {Title="Макс дистанция ESP", Min=50, Max=1000, Default=500, Rounding=0}, function(v) espState.maxDist = tonumber(v) or 500 end)
    addOpt(espSec, "AddToggle", "ESPAllowLocal", {Title="Показывать себя", Default=false}, function(v) espState.allowLocal = v end)
end

-- ============================================================
-- 6. TRACER
-- ============================================================
do
    local tracerOn, tracerCol, tracerDur = false, Color3.fromRGB(133, 220, 255), 1

    local function makePoint(pos, life)
        local pt = Instance.new("Part")
        pt.Transparency = 1; pt.Anchored = true
        pt.CanCollide = false; pt.CanQuery = false
        pt.Size = Vector3.new(1, 1, 1)
        pt.CFrame = CFrame.new(pos)
        Instance.new("Attachment", pt)
        pt.Parent = Workspace
        Debris:AddItem(pt, life)
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
        beam.Width0 = 0.25; beam.Width1 = 0.25
        beam.LightEmission = 3; beam.LightInfluence = 0
        beam.Brightness = 2.5
        beam.Texture = "rbxassetid://12781800668"
        beam.Color = ColorSequence.new(tracerCol)
        beam.Transparency = NumberSequence.new(0.1)
        beam.Attachment0 = p1:FindFirstChildOfClass("Attachment")
        beam.Attachment1 = p2:FindFirstChildOfClass("Attachment")
        beam.Parent = p1
        task.delay(tracerDur, function()
            if beam.Parent then
                TweenService:Create(beam, TweenInfo.new(0.2), {Width0=0, Width1=0}):Play()
            end
        end)
    end

    task.spawn(function()
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices")
                :WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if ok and remote then
            remote.OnClientEvent:Connect(function(gun, sv, ev)
                if not tracerOn then return end
                local c = LocalPlayer.Character
                if not c then return end
                if not (typeof(gun) == "Instance" and gun:IsDescendantOf(c)) then return end
                createTracer(sv, ev)
            end)
        end
    end)

    local sec = Tabs.Effects:AddSection({Name="Трассер пули"})
    addOpt(sec, "AddToggle", "TracerOn", {Title="Включить", Default=false}, function(v) tracerOn = v end)
    addOpt(sec, "AddColorPicker", "TracerCol", {Title="Цвет", Default=Color3.fromRGB(133,220,255)}, function(c) tracerCol = c end)
    addOpt(sec, "AddSlider", "TracerDur", {Title="Длительность", Min=0.1, Max=5, Default=1, Rounding=1}, function(v) tracerDur = tonumber(v) or 1 end)
end

-- ============================================================
-- 7. WORLD EFFECTS (Snow / Sakura)
-- ============================================================
do
    local fxOn, fxType, fxCol, fxRate = false, "Snow", Color3.fromRGB(150,200,255), 250
    local fxPart, fxEmit, fxConn

    local function style()
        local e = fxEmit
        if not e then return end
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.LightInfluence = 0; e.LightEmission = 0.4
        e.EmissionDirection = Enum.NormalId.Bottom
        e.Rate = fxRate
        e.Color = ColorSequence.new(fxCol)
        if fxType == "Snow" then
            e.Lifetime = NumberRange.new(4, 6)
            e.Speed = NumberRange.new(6, 12)
            e.Acceleration = Vector3.new(2, -6, 1)
            e.SpreadAngle = Vector2.new(35, 35)
            e.Size = NumberSequence.new(0.55)
        else
            e.Lifetime = NumberRange.new(5, 7)
            e.Speed = NumberRange.new(5, 10)
            e.Acceleration = Vector3.new(4, -5, 2)
            e.SpreadAngle = Vector2.new(40, 40)
            e.Size = NumberSequence.new(0.5)
        end
    end
    local function stop()
        if fxConn then pcall(function() fxConn:Disconnect() end); fxConn = nil end
        if fxPart then pcall(function() fxPart:Destroy() end); fxPart = nil end
        fxEmit = nil
    end
    local function start()
        stop()
        fxPart = Instance.new("Part")
        fxPart.Name = "FH_WORLD_FX"
        fxPart.Anchored = true
        fxPart.CanCollide = false
        fxPart.CanQuery = false
        fxPart.Transparency = 1
        fxPart.Size = Vector3.new(260, 140, 260)
        fxPart.Parent = Workspace
        fxEmit = Instance.new("ParticleEmitter")
        fxEmit.Parent = fxPart
        style()
        fxConn = RunService.RenderStepped:Connect(function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local cf = cam.CFrame
            local d = cf.LookVector
            local flat = Vector3.new(d.X, 0, d.Z)
            if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) else flat = flat.Unit end
            fxPart.CFrame = CFrame.new(cf.Position + flat*57 + Vector3.new(0, 44, 0))
        end)
    end

    local sec = Tabs.Effects:AddSection({Name="Эффекты мира"})
    addOpt(sec, "AddToggle", "FXOn", {Title="Включить", Default=false}, function(v)
        fxOn = v
        if v then start() else stop() end
    end)
    addOpt(sec, "AddDropdown", "FXType", {Title="Тип", Values={"Снег","Сакура"}, Default="Снег"}, function(v)
        fxType = (v == "Сакура") and "Sakura" or "Snow"
        if fxOn then style() end
    end)
    addOpt(sec, "AddColorPicker", "FXCol", {Title="Цвет", Default=Color3.fromRGB(150,200,255)}, function(c)
        fxCol = c
        if fxEmit then fxEmit.Color = ColorSequence.new(c) end
    end)
    addOpt(sec, "AddSlider", "FXRate", {Title="Интенсивность", Min=20, Max=900, Default=250, Rounding=1}, function(v)
        fxRate = tonumber(v) or 250
        if fxEmit then style() end
    end)
end

-- ============================================================
-- 8. FARM V3 (единственный фарм)
-- ============================================================
do
    local active, mode, speed = false, "Basic", 23
    local ncCache = {}
    local farmTarget
    local coinsDone, sawCoins = false, false
    local wasDown, downRefY = false, nil
    local lastTouch = 0
    local DOWN_DEPTH, DOWN_RISE_XZ = 14, 4

    local function hrp()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function canFarm()
        local char = LocalPlayer.Character
        local h = char and char:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return false end
        local d = getRoundData()
        if type(d) == "table" then
            local me = d[LocalPlayer.Name]
            if not me or not me.Role or me.Dead then return false end
        end
        return true
    end
    local function bagsFull()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
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
    local function resetProgress()
        coinsDone, sawCoins, farmTarget = false, false, nil
    end
    task.spawn(function()
        local ok, r = pcall(function()
            return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("CoinsStarted", 15)
        end)
        if ok and r then r.OnClientEvent:Connect(resetProgress) end
    end)
    LocalPlayer.CharacterAdded:Connect(resetProgress)

    local function coinOK(v)
        return v and v.Parent and v:IsA("BasePart")
            and not v:GetAttribute("Collected") and not v:GetAttribute("Delete")
    end
    local function coinList()
        local out = {}
        for _, v in ipairs(CollectionService:GetTagged("CoinVisual")) do
            if coinOK(v) then out[#out+1] = v end
        end
        return out
    end
    local function nearest(pos, list)
        local b, bd = nil, math.huge
        for _, v in ipairs(list) do
            local d = (v.Position - pos).Magnitude
            if d < bd then bd = d; b = v end
        end
        return b
    end
    local function setNoclip(on)
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if on then
            if not c then return end
            if h then pcall(function() h.PlatformStand = true end) end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    if ncCache[p] == nil then ncCache[p] = p.CanCollide end
                    p.CanCollide = false
                end
            end
        else
            if h then pcall(function() h.PlatformStand = false end) end
            for p, v in pairs(ncCache) do
                if p and p.Parent then pcall(function() p.CanCollide = v end) end
            end
            ncCache = {}
        end
    end
    local function fireTouch(coin)
        if type(firetouchinterest) ~= "function" then return end
        if not coin or not coin.Parent then return end
        local now = os.clock()
        if now - lastTouch < 0.05 then return end
        lastTouch = now
        local my = hrp()
        if not my then return end
        pcall(firetouchinterest, my, coin, 0)
        pcall(firetouchinterest, my, coin, 1)
    end
    local function farmMove(my, dest, dt)
        local dir = dest - my.Position
        local dist = dir.Magnitude
        local np = dest
        if dist > 0.1 then
            np = my.Position + dir.Unit * math.min(speed * dt, dist)
        end
        local cf = CFrame.new(np)
        if mode == "Down" then
            cf = cf * CFrame.Angles(-math.pi*0.5, 0, 0)
            wasDown = true
        end
        pcall(function()
            my.CFrame = cf
            my.AssemblyLinearVelocity = Vector3.zero
            my.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    local upParams = RaycastParams.new()
    upParams.FilterType = Enum.RaycastFilterType.Exclude
    upParams.IgnoreWater = true
    local function returnToSurface()
        local my = hrp()
        if not my then return end
        upParams.FilterDescendantsInstances = {LocalPlayer.Character}
        local res = Workspace:Raycast(my.Position, Vector3.new(0, 400, 0), upParams)
        local y = res and (res.Position.Y + 5) or (downRefY and downRefY + 5 or nil)
        if not y then return end
        pcall(function()
            my.CFrame = CFrame.new(my.Position.X, y, my.Position.Z)
            my.AssemblyLinearVelocity = Vector3.zero
            my.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    local function farmRelease()
        if wasDown then
            wasDown = false
            returnToSurface()
        end
        setNoclip(false)
    end
    local function fireFullAction()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.Health = 0 end) end
    end

    RunService.Stepped:Connect(function(_, dt)
        if not active then return end
        if not canFarm() then
            farmTarget = nil; wasDown = false
            setNoclip(false)
            return
        end
        local my = hrp()
        if not my then return end
        local list = coinList()
        if sawCoins and bagsFull() then
            farmRelease()
            if not coinsDone then
                coinsDone = true
                fireFullAction()
            end
            return
        end
        if #list > 0 then
            sawCoins = true
            if coinsDone then coinsDone = false end
            if not (farmTarget and farmTarget.Parent and coinOK(farmTarget)) then
                farmTarget = nearest(my.Position, list)
            end
            if farmTarget then
                setNoclip(true)
                local cpos = farmTarget.Position
                downRefY = cpos.Y
                local dest = cpos
                if mode == "Down" then
                    local xz = Vector3.new(my.Position.X - cpos.X, 0, my.Position.Z - cpos.Z).Magnitude
                    if xz <= DOWN_RISE_XZ then
                        fireTouch(farmTarget)
                    else
                        dest = Vector3.new(cpos.X, cpos.Y - DOWN_DEPTH, cpos.Z)
                    end
                elseif (cpos - my.Position).Magnitude <= 6 then
                    fireTouch(farmTarget)
                end
                farmMove(my, dest, dt)
            end
        else
            farmTarget = nil
            farmRelease()
            if sawCoins and not coinsDone then
                coinsDone = true
                fireFullAction()
            end
        end
    end)

    local sec = Tabs.Farm:AddSection({Name="Автофарм"})
    addOpt(sec, "AddToggle", "FarmV3On", {Title="Включить автофарм", Default=false}, function(v)
        active = v
        if not v then farmRelease() end
        resetProgress()
    end)
    addOpt(sec, "AddDropdown", "FarmV3Mode", {Title="Тип", Values={"Basic","Down"}, Default="Basic"}, function(v)
        mode = v or "Basic"
        farmTarget = nil
        if mode == "Basic" and wasDown then
            wasDown = false
            returnToSurface()
        end
    end)
    addOpt(sec, "AddSlider", "FarmV3Speed", {Title="Скорость", Min=5, Max=60, Default=23, Rounding=1}, function(v)
        speed = tonumber(v) or 23
    end)
end

-- ============================================================
-- 9. UTILITY — Invis, Anti, Boost
-- ============================================================
do
    -- НЕВИДИМОСТЬ
    local invis = {active=false, realCF=nil, hbConn=nil, bindName="FH_InvisClient",
        savedLTM={}, savedDecals={}, savedFallen=nil}
    local HIDDEN_CF = CFrame.new(0, -50000, 0)
    getgenv().FH_INVIS_ACTIVE = false

    local function restoreParts()
        local char = LocalPlayer.Character
        if char then
            for p, v in pairs(invis.savedLTM) do
                if p and p.Parent then pcall(function() p.LocalTransparencyModifier = v end) end
            end
            for d, v in pairs(invis.savedDecals) do
                if d and d.Parent then pcall(function() d.Transparency = v end) end
            end
        end
        invis.savedLTM, invis.savedDecals = {}, {}
    end
    local function invisBegin()
        if invis.active then return end
        local char = LocalPlayer.Character
        if not char then Notify("FH", "Персонаж не загружен", 2); return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        invis.savedLTM, invis.savedDecals = {}, {}
        invis.realCF = hrp.CFrame
        invis.active = true
        getgenv().FH_INVIS_ACTIVE = true
        invis.savedFallen = Workspace.FallenPartsDestroyHeight
        pcall(function() Workspace.FallenPartsDestroyHeight = -9e9 end)
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                invis.savedLTM[p] = p.LocalTransparencyModifier
                p.LocalTransparencyModifier = 0.5
            elseif p:IsA("Decal") or p:IsA("Texture") then
                invis.savedDecals[p] = p.Transparency
                p.Transparency = 0.5
            end
        end
        invis.hbConn = RunService.Heartbeat:Connect(function()
            if not invis.active then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            invis.realCF = h.CFrame
            h.CFrame = HIDDEN_CF
        end)
        RunService:BindToRenderStep(invis.bindName, Enum.RenderPriority.Camera.Value - 1, function()
            if not invis.active then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if h and invis.realCF then h.CFrame = invis.realCF end
        end)
        Notify("FH", "Невидимость ВКЛ", 2)
    end
    local function invisEnd()
        if not invis.active then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local finalCF = invis.realCF
        invis.active = false
        getgenv().FH_INVIS_ACTIVE = false
        if invis.hbConn then pcall(function() invis.hbConn:Disconnect() end); invis.hbConn = nil end
        pcall(function() RunService:UnbindFromRenderStep(invis.bindName) end)
        if hrp and finalCF then
            pcall(function()
                hrp.CFrame = finalCF
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        restoreParts()
        if invis.savedFallen ~= nil then
            pcall(function() Workspace.FallenPartsDestroyHeight = invis.savedFallen end)
            invis.savedFallen = nil
        end
        Notify("FH", "Невидимость ВЫКЛ", 2)
    end

    local invisSec = Tabs.Utility:AddSection({Name="Невидимость"})
    addOpt(invisSec, "AddToggle", "InvisOn", {Title="Включить", Default=false}, function(v)
        if v then invisBegin() else invisEnd() end
    end)

    -- АНТИ
    local antiSec = Tabs.Utility:AddSection({Name="Анти"})
    local antiFlingOn = false
    local flingCache, flingReg = {}, {}
    RunService.Stepped:Connect(function()
        if not antiFlingOn then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not flingReg[p.Character] then
                flingReg[p.Character] = {}
                for _, d in ipairs(p.Character:GetDescendants()) do
                    if d:IsA("BasePart") then
                        if flingCache[d] == nil then flingCache[d] = d.CanCollide end
                        flingReg[p.Character][d] = true
                        pcall(function() d.CanCollide = false end)
                    end
                end
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
    end)
    addOpt(antiSec, "AddToggle", "AntiFling", {Title="Анти-отброс", Default=false}, function(v)
        antiFlingOn = v
        if not v then
            for _, model in pairs(flingReg) do
                for part in pairs(model) do
                    if part.Parent and flingCache[part] ~= nil then
                        pcall(function() part.CanCollide = flingCache[part] end)
                    end
                end
            end
            flingReg, flingCache = {}, {}
        end
    end)

    local antiVoidOn = false
    local voidOrig = Workspace.FallenPartsDestroyHeight
    RunService.Heartbeat:Connect(function()
        pcall(function()
            Workspace.FallenPartsDestroyHeight = antiVoidOn and -9e9 or voidOrig
        end)
    end)
    addOpt(antiSec, "AddToggle", "AntiVoid", {Title="Анти-падение", Default=false}, function(v)
        antiVoidOn = v
    end)

    -- БУСТ ГОЛОСОВ
    local mvSec = Tabs.Utility:AddSection({Name="Буст голосов"})
    local mvCap = 10
    local function dupeVote(times)
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local savedCF = hrp.CFrame
        task.spawn(function()
            for i = 1, times do
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    pcall(function() h.Health = 0 end)
                end
                local waited = 0
                local lastChar = c
                while waited < 5 do
                    task.wait(0.02)
                    waited = waited + 0.02
                    local nc = LocalPlayer.Character
                    if nc and nc ~= lastChar then
                        local nh = nc:FindFirstChildOfClass("Humanoid")
                        local nhrp = nc:FindFirstChild("HumanoidRootPart")
                        if nh and nh.Health > 0 and nhrp then
                            pcall(function() nhrp.CFrame = savedCF end)
                            break
                        end
                    end
                end
                task.wait(0.5)
            end
            Notify("FH", "Буст завершён", 3)
        end)
    end
    addOpt(mvSec, "AddSlider", "MVDupeCap", {Title="Кол-во", Min=1, Max=15, Default=10, Rounding=0}, function(v)
        mvCap = tonumber(v) or 10
    end)
    mvSec:AddButton({Title="Буст голосов", Callback=function()
        dupeVote(math.clamp(math.floor(mvCap), 1, 15))
    end})

    -- WATER PROTECTION
    local offWater = false
    local modWater = {}
    local function isWater(inst)
        if not inst then return false end
        local n = inst.Name:lower()
        return n:find("water") or n:find("river") or n:find("ocean")
    end
    addOpt(antiSec, "AddToggle", "WaterProtOn", {Title="Защита от воды", Default=false}, function(v)
        offWater = v
        if v then
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("BasePart") then
                    local p = d
                    while p and p ~= Workspace do
                        if isWater(p) then
                            if modWater[d] == nil then modWater[d] = d.CanTouch end
                            d.CanTouch = false
                            break
                        end
                        p = p.Parent
                    end
                end
            end
        else
            for part, ct in pairs(modWater) do
                if part and part.Parent then pcall(function() part.CanTouch = ct end) end
            end
            modWater = {}
        end
    end)

    -- FADE DISABLER
    local fadeNames = {CameraFade=true, Fade=true, SpawnFade=true, DeathFade=true}
    local fadeTracked = {}
    addOpt(antiSec, "AddToggle", "FadeDisablerOn", {Title="Убрать чёрный экран", Default=false}, function(v)
        if v then
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if not pg then return end
            local function handle(obj)
                if not obj or not obj:IsDescendantOf(game) then return end
                if fadeNames[obj.Name] then
                    if not fadeTracked[obj] then fadeTracked[obj] = obj.Parent end
                    pcall(function() obj.Visible = false end)
                end
            end
            for _, d in ipairs(pg:GetDescendants()) do handle(d) end
            pg.DescendantAdded:Connect(handle)
        else
            for obj, parent in pairs(fadeTracked) do
                if obj and obj.Parent then pcall(function() obj.Visible = true end) end
            end
            fadeTracked = {}
        end
    end)
end

-- ============================================================
-- 10. TROLL — TP-tool, Fake Death, Teleport
-- ============================================================
do
    -- TP-тул
    local tpOn, tpTool, tpActConn = false, nil, nil
    local function giveTpTool()
        if not tpOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("tp")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("tp")
        end
        if existing then tpTool = existing; return end
        tpTool = Instance.new("Tool")
        tpTool.Name = "tp"
        tpTool.RequiresHandle = false
        tpTool.CanBeDropped = false
        tpTool.Parent = bp
        tpActConn = tpTool.Activated:Connect(function()
            local hrp = getHRP()
            local m = LocalPlayer:GetMouse()
            if not hrp or not m.Hit then return end
            hrp.CFrame = CFrame.new(m.Hit.X, m.Hit.Y + 3, m.Hit.Z)
        end)
    end
    local function removeTpTool()
        if tpActConn then pcall(function() tpActConn:Disconnect() end); tpActConn = nil end
        if tpTool then pcall(function() tpTool:Destroy() end); tpTool = nil end
    end
    local sec = Tabs.Troll:AddSection({Name="Инструменты"})
    addOpt(sec, "AddToggle", "ToolTP", {Title="ТП-тул", Default=false}, function(v)
        tpOn = v
        if v then giveTpTool() else removeTpTool() end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if tpOn then giveTpTool() end
    end)

    -- Фейк-смерть
    local fdSec = Tabs.Troll:AddSection({Name="Фейк-смерть"})
    local track1, track2
    local function playFd(id, slot)
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. tostring(id)
        local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            pcall(function() track:Play() end)
            if slot == 1 then track1 = track else track2 = track end
            Notify("FH", "Фейк-смерть " .. slot, 2)
        end
    end
    fdSec:AddButton({Title="Фейк-смерть 1", Callback=function() playFd("132384701706046", 1) end})
    fdSec:AddButton({Title="Фейк-смерть 2", Callback=function() playFd("125032357496729", 2) end})
    fdSec:AddButton({Title="Остановить", Callback=function()
        if track1 then pcall(function() track1:Stop() end); track1 = nil end
        if track2 then pcall(function() track2:Stop() end); track2 = nil end
    end})

    -- Телепорт
    local function inLobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby" or p.Name == "Lobby" then return true end
            p = p.Parent
        end
        return false
    end
    local tpBtn = Tabs.Troll:AddSection({Name="Телепорт"})
    tpBtn:AddButton({Title="ТП в лобби", Callback=function()
        local hrp = getHRP()
        if not hrp then return end
        local lobby = Workspace:FindFirstChild("RegularLobby") or Workspace:FindFirstChild("Lobby")
        if not lobby then return end
        local locs = {}
        for _, o in ipairs(lobby:GetDescendants()) do
            if o:IsA("SpawnLocation") then locs[#locs+1] = o end
        end
        if #locs > 0 then
            local s = locs[math.random(1, #locs)]
            hrp.CFrame = s.CFrame + Vector3.new(0, 3, 0)
        end
    end})
    tpBtn:AddButton({Title="ТП на карту", Callback=function()
        local hrp = getHRP()
        if not hrp then return end
        local spawns = {}
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("SpawnLocation") and not inLobby(o) then spawns[#spawns+1] = o end
        end
        if #spawns > 0 then
            local s = spawns[math.random(1, #spawns)]
            hrp.CFrame = s.CFrame + Vector3.new(0, 5, 0)
        end
    end})
end

-- ============================================================
-- 11. TRADE HELPER
-- ============================================================
do
    local TH = {TradeValues={}, On=false, Loaded=false}
    getgenv().TH = TH

    local function normKey(s)
        if not s then return "" end
        return s:lower():gsub("[%s%_'%.-]", "")
    end
    local function addValue(name, value)
        if not name or not value then return end
        local clean = name:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$")
        if not clean or #clean <= 1 then return end
        TH.TradeValues[clean] = value
        TH.TradeValues[normKey(clean)] = value
    end
    local function fetch(url)
        local proxies = {
            "https://api.codetabs.com/v1/proxy?quest=" .. url,
            "https://corsproxy.io/?" .. url,
            url,
        }
        for _, u in ipairs(proxies) do
            local body, done
            task.spawn(function()
                local ok, r = pcall(function() return game:HttpGet(u, true) end)
                if ok and type(r) == "string" and #r > 300 then body = r end
                done = true
            end)
            local t0 = tick()
            while not done and tick() - t0 < 3 do task.wait(0.1) end
            if body then return body end
        end
    end
    local function parseValues(html)
        html = html:gsub("[\r\n]", " ")
        for block in html:gmatch("<div%s+class=stackable>(.-)</div>") do
            local valStr = block:match("Value:%s*([%d,]+)")
            if valStr then
                local num = tonumber((valStr:gsub(",", "")))
                local name = block:match("<b>([^<]+)</b>")
                if name and num then addValue(name, num) end
            end
        end
    end
    local function lookup(name)
        if not name then return 0 end
        return TH.TradeValues[name] or TH.TradeValues[normKey(name)] or 0
    end
    local function scanTradeGui()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("GuiObject") and d:FindFirstChild("ItemName") and d:FindFirstChild("Container") then
                local nf = d:FindFirstChild("ItemName")
                local lbl = nf and nf:FindFirstChild("Label")
                if lbl and lbl.Text ~= "" and lbl.Text ~= "Loading..." then
                    local val = lookup(lbl.Text)
                    if val > 0 then
                        local cont = d:FindFirstChild("Container") or d
                        local old = cont:FindFirstChild("FH_ValueLabel")
                        if old then old:Destroy() end
                        local l = Instance.new("TextLabel")
                        l.Name = "FH_ValueLabel"
                        l.Size = UDim2.new(0.96, 0, 0, 16)
                        l.Position = UDim2.new(0.02, 0, 1, -18)
                        l.BackgroundColor3 = Color3.new(0, 0, 0)
                        l.BackgroundTransparency = 0.25
                        l.Text = "$" .. tostring(val)
                        l.TextColor3 = Color3.fromRGB(255, 215, 0)
                        l.TextScaled = true
                        l.Font = Enum.Font.GothamBold
                        l.ZIndex = 1000
                        l.Parent = cont
                    end
                end
            end
        end
    end
    local function loadValues()
        if TH.Loaded then return end
        TH.Loaded = true
        local urls = {
            "https://mm2values.com/?p=godly",
            "https://mm2values.com/?p=chroma",
            "https://mm2values.com/?p=ancient",
            "https://mm2values.com/?p=unique",
            "https://mm2values.com/?p=legend",
        }
        for _, u in ipairs(urls) do
            task.spawn(function()
                local html = fetch(u)
                if html then parseValues(html) end
            end)
        end
        task.delay(6, function() Notify("FH", "Trade Values загружены", 2) end)
    end

    local sec = Tabs.Visual:AddSection({Name="Trade Helper"})
    addOpt(sec, "AddToggle", "THOn", {Title="Trade Helper (MM2 Values)", Default=false}, function(v)
        if v then
            TH.On = true
            loadValues()
            task.spawn(function()
                while TH.On do
                    task.wait(0.5)
                    pcall(scanTradeGui)
                end
            end)
            Notify("FH", "Trade Helper ВКЛ", 2)
        else
            TH.On = false
            Notify("FH", "Trade Helper ВЫКЛ", 2)
        end
    end)
    sec:AddButton({Title="Обновить значения", Callback=function()
        TH.Loaded = false
        TH.TradeValues = {}
        loadValues()
        Notify("FH", "Обновляю значения...", 3)
    end})
end

-- ============================================================
-- 12. VOTE DUPER
-- ============================================================
do
    local selectedPad, padRefs, padNames = nil, {}, {}
    local enabled = false
    local delay = 0.38
    local thread, counter = nil, 0

    local function safeText(obj)
        if obj and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
            return tostring(obj.Text or "")
        end
        return ""
    end
    local function getMapName(pad)
        if not pad then return "" end
        local v = pad:FindFirstChild("VoteInfoGui", true)
        if v then v = v:FindFirstChild("MapName", true) end
        return safeText(v)
    end
    local function collectPads()
        local lobby = Workspace:FindFirstChild("RegularLobby") or Workspace:FindFirstChild("Lobby")
        if not lobby then return {} end
        local out = {}
        for _, nm in ipairs({"VotePad1","VotePad2","VotePad3"}) do
            local o = lobby:FindFirstChild(nm)
            if o and o:FindFirstChild("Pad", true) then out[#out+1] = o end
        end
        return out
    end
    local function getPadCF()
        if not selectedPad then return nil end
        local pad = selectedPad:FindFirstChild("Pad", true)
        if pad and pad:IsA("BasePart") then return pad.CFrame end
    end
    local function loop()
        local myToken = counter
        while enabled and counter == myToken do
            local cf = getPadCF()
            if cf then
                local char = LocalPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    pcall(function() char:PivotTo(cf * CFrame.new(0, 1.5, 0)) end)
                    task.wait(delay)
                    if enabled and counter == myToken and hum and hum.Health > 0 then
                        hum.Health = 0
                        task.wait(0.5)
                    end
                else
                    task.wait(0.3)
                end
            else
                task.wait(0.3)
            end
        end
        if counter == myToken then thread = nil end
    end
    local function start()
        if thread then return end
        counter = counter + 1
        thread = task.spawn(loop)
    end
    local function stop()
        enabled = false
        counter = counter + 1
        if thread then pcall(task.cancel, thread); thread = nil end
    end

    local sec = Tabs.Troll:AddSection({Name="Vote Duper"})
    addOpt(sec, "AddToggle", "THVoteDuper", {Title="Vote Duper", Default=false}, function(v)
        enabled = v
        if v then start() else stop() end
    end)
    addOpt(sec, "AddSlider", "THDupeDelay", {Title="Задержка на пэде", Min=0.1, Max=1.5, Default=0.38, Rounding=2}, function(v)
        delay = tonumber(v) or 0.38
    end)
    local function refresh()
        padRefs = collectPads()
        padNames = {}
        for i, p in ipairs(padRefs) do
            local n = getMapName(p)
            padNames[i] = n ~= "" and n or ("Pad " .. i)
        end
        if #padNames == 0 then padNames = {"(нет пэдов)"} end
        local drop = Options.THPadPick
        if drop then pcall(function() drop:SetValues(padNames); drop:Generate() end) end
    end
    addOpt(sec, "AddDropdown", "THPadPick", {Title="Пэд", Values={"Pad 1","Pad 2","Pad 3"}, Default="Pad 1"}, function(v)
        for i, name in ipairs(padNames) do
            if name == v then selectedPad = padRefs[i]; return end
        end
    end)
    sec:AddButton({Title="Обновить список", Callback=refresh})
    refresh()
end

-- ============================================================
-- 13. BEAM EFFECTS
-- ============================================================
do
    local BeamCfg = {Type="Default", Color=Color3.fromRGB(0, 240, 255)}
    getgenv().FH_BeamCfg = BeamCfg

    local function bc() return BeamCfg.Color or Color3.fromRGB(0, 240, 255) end
    local function cyl(p1, p2, th)
        local len = (p2 - p1).Magnitude
        if len < 1 then return end
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = bc()
        part.Shape = Enum.PartType.Cylinder
        part.Size = Vector3.new(len, th, th)
        part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -len/2) * CFrame.Angles(0, math.pi/2, 0)
        part.Parent = workspace.Terrain
        TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
            Size = Vector3.new(len, 0, 0), Transparency = 1
        }):Play()
        task.delay(0.25, function() part:Destroy() end)
    end
    local function processBeam(beam)
        if not beam:IsA("Beam") then return end
        if BeamCfg.Type == "Default" then return end
        local a0, a1 = beam.Attachment0, beam.Attachment1
        if not a0 or not a1 then return end
        local p1, p2 = a0.WorldPosition, a1.WorldPosition
        local t = BeamCfg.Type
        if t == "Neon Fat" then
            beam.Width0 = 1.8; beam.Width1 = 1.2
            beam.Color = ColorSequence.new(bc())
            cyl(p1, p2, 1.0)
        elseif t == "Nuke" then
            beam.Width0 = 1.4; beam.Width1 = 0.8
            cyl(p1, p2, 0.8)
        elseif t == "Rainbow RGB" then
            beam.Width0 = 1.8; beam.Width1 = 1.2
            beam.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
                ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
            })
            cyl(p1, p2, 1.0)
        end
    end

    Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Beam") and BeamCfg.Type ~= "Default" then
            task.wait()
            pcall(processBeam, d)
        end
    end)

    local sec = Tabs.Effects:AddSection({Name="Beam Effects"})
    addOpt(sec, "AddDropdown", "FHBeamType", {
        Title="Тип луча",
        Values={"Default","Neon Fat","Nuke","Rainbow RGB"},
        Default="Default",
    }, function(v) BeamCfg.Type = v or "Default" end)
    addOpt(sec, "AddColorPicker", "FHBeamColor", {Title="Цвет", Default=Color3.fromRGB(0,240,255)}, function(c)
        BeamCfg.Color = c
    end)
end

-- ============================================================
-- 14. AURA 2.0 — расширение
-- ============================================================
do
    local sec = Tabs.Effects:AddSection({Name="Aura 2.0 (доп.)"})
    local extras = {
        {"Midnight Blues", "12002206611"},
        {"Rainbow Effect", "8509695714"},
        {"Red Shield", "14598330167"},
        {"Crimson King", "11955208820"},
        {"Daemon of Cards", "10373359918"},
    }
    local activeExtra, extraParts = nil, {}
    local function clearExtra()
        for _, p in ipairs(extraParts) do pcall(function() p:Destroy() end) end
        extraParts = {}
        activeExtra = nil
    end
    local function applyExtra(name, id)
        if activeExtra == name then
            clearExtra()
            Notify("FH", name .. " выключена", 2)
            return
        end
        clearExtra()
        local ok, objs = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(id))
        end)
        if not ok or type(objs) ~= "table" or #objs == 0 then
            Notify("FH", "Не удалось: " .. name, 3)
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if not torso then return end
        local model = objs[1]
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Highlight") then
                local cl = d:Clone()
                cl.Parent = torso
                extraParts[#extraParts+1] = cl
            end
        end
        model:Destroy()
        activeExtra = name
        Notify("FH", name .. " включена", 2)
    end
    for _, e in ipairs(extras) do
        sec:AddButton({Title=e[1], Callback=function() applyExtra(e[1], e[2]) end})
    end
    sec:AddButton({Title="Очистить", Callback=function() clearExtra() end})
end

-- ============================================================
-- 15. ANTI-AIM
-- ============================================================
do
    local enabled = false
    local token = 0
    local savedCollide, stepConn = {}, nil
    local function getRoot(char)
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.RootPart then return hum.RootPart end
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    end
    local function stop()
        enabled = false
        token = token + 1
        if stepConn then pcall(function() stepConn:Disconnect() end); stepConn = nil end
        local char = LocalPlayer.Character
        if char then
            for part, ct in pairs(savedCollide) do
                if part and part.Parent then pcall(function() part.CanCollide = ct end) end
            end
        end
        savedCollide = {}
    end
    local function start()
        stop()
        enabled = true
        token = token + 1
        local myToken = token
        stepConn = RunService.Stepped:Connect(function()
            if not enabled or token ~= myToken then return end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if not c or not c.Parent or not h or h.Health <= 0 then
                stop(); return
            end
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("BasePart") then
                    if savedCollide[d] == nil then savedCollide[d] = d.CanCollide end
                    d.CanCollide = false
                end
            end
        end)
        task.spawn(function()
            local wobble = 0.1
            while enabled and token == myToken do
                RunService.Heartbeat:Wait()
                if not enabled or token ~= myToken then break end
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local root = getRoot(c)
                if c and c.Parent and h and h.Health > 0 and root and root.Parent then
                    local oldVel = root.Velocity
                    root.Velocity = oldVel * 10000 + Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    if enabled and c.Parent and h.Health > 0 and root.Parent then
                        root.Velocity = oldVel
                    end
                    RunService.Stepped:Wait()
                    if enabled and c.Parent and h.Health > 0 and root.Parent then
                        root.Velocity = oldVel + Vector3.new(0, wobble, 0)
                        wobble = wobble * -1
                    end
                end
            end
        end)
    end
    local sec = Tabs.Utility:AddSection({Name="Anti-Aim"})
    addOpt(sec, "AddToggle", "FHAntiAimOn", {Title="Анти-аим", Default=false}, function(v)
        if v then start() else stop() end
    end)
end

-- ============================================================
-- 16. PLAYER PANEL
-- ============================================================
do
    local gui = Instance.new("ScreenGui")
    gui.Name = "FH_PlayerListPanel"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 450
    gui.Enabled = false
    pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not gui.Parent then gui.Parent = CoreGui end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(440, 380)
    frame.Position = UDim2.new(0.5, -220, 0.5, -190)
    frame.BackgroundColor3 = Color3.fromRGB(16, 12, 9)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(138, 92, 246)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.4

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 24)
    title.Position = UDim2.fromOffset(12, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "Player List"
    title.TextColor3 = Color3.fromRGB(245, 242, 238)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(22, 22)
    closeBtn.Position = UDim2.new(1, -30, 0, 7)
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    closeBtn.TextSize = 12
    closeBtn.Parent = frame
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

    local search = Instance.new("TextBox")
    search.Size = UDim2.new(1, -24, 0, 28)
    search.Position = UDim2.new(0, 12, 0, 36)
    search.BackgroundColor3 = Color3.fromRGB(15, 13, 11)
    search.BorderSizePixel = 0
    search.ClearTextOnFocus = false
    search.Font = Enum.Font.Gotham
    search.PlaceholderText = "Поиск игроков..."
    search.PlaceholderColor3 = Color3.fromRGB(150, 145, 140)
    search.Text = ""
    search.TextColor3 = Color3.fromRGB(245, 242, 238)
    search.TextSize = 13
    search.TextXAlignment = Enum.TextXAlignment.Left
    search.Parent = frame
    Instance.new("UICorner", search).CornerRadius = UDim.new(0, 6)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Position = UDim2.new(0, 12, 0, 72)
    scroll.Size = UDim2.new(1, -24, 1, -84)
    scroll.BackgroundColor3 = Color3.fromRGB(10, 9, 8)
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(138, 92, 246)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.Parent = frame
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 7)
    local grid = Instance.new("UIGridLayout", scroll)
    grid.CellPadding = UDim2.new(0, 7, 0, 7)
    grid.CellSize = UDim2.new(0.5, -4, 0, 72)
    grid.SortOrder = Enum.SortOrder.LayoutOrder

    getgenv().FH_SelectedPlayer = nil

    local function refresh()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local q = string.lower(search.Text or "")
        local order = 0
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local dn = string.lower(pl.DisplayName or "")
                local nm = string.lower(pl.Name or "")
                if q == "" or dn:find(q, 1, true) or nm:find(q, 1, true) then
                    order = order + 1
                    local btn = Instance.new("TextButton")
                    btn.LayoutOrder = order
                    btn.BackgroundColor3 = Color3.fromRGB(15, 13, 11)
                    btn.BorderSizePixel = 0
                    btn.Text = ""
                    btn.Parent = scroll
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, -12, 1, -6)
                    lbl.Position = UDim2.new(0, 6, 0, 3)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.Gotham
                    lbl.Text = pl.DisplayName ~= pl.Name and pl.DisplayName or pl.Name
                    lbl.TextColor3 = Color3.fromRGB(245, 242, 238)
                    lbl.TextSize = 12
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = btn
                    btn.Activated:Connect(function()
                        getgenv().FH_SelectedPlayer = pl
                        Notify("FH", "Выбран: " .. pl.Name, 1.5)
                    end)
                end
            end
        end
    end
    search:GetPropertyChangedSignal("Text"):Connect(refresh)
    Players.PlayerAdded:Connect(refresh)
    Players.PlayerRemoving:Connect(refresh)
    refresh()

    local sec = Tabs.Troll:AddSection({Name="Player List Panel"})
    addOpt(sec, "AddToggle", "FHPlayerPanelOn", {Title="Открыть", Default=false}, function(v)
        gui.Enabled = v
        if v then refresh() end
    end)
    sec:AddButton({Title="ТП к выбранному", Callback=function()
        local pl = getgenv().FH_SelectedPlayer
        if not pl or not pl.Character then return end
        local hrp = getHRP()
        if not hrp then return end
        local t = pl.Character:FindFirstChild("HumanoidRootPart")
        if t then hrp.CFrame = t.CFrame + Vector3.new(0, 5, 0) end
    end})
    sec:AddButton({Title="ТП игрока к себе", Callback=function()
        local pl = getgenv().FH_SelectedPlayer
        if not pl or not pl.Character then return end
        local hrp = getHRP()
        if not hrp then return end
        local t = pl.Character:FindFirstChild("HumanoidRootPart")
        if t then t.CFrame = hrp.CFrame + Vector3.new(0, 3, 0) end
    end})
end

-- ============================================================
-- 17. LANGUAGE
-- ============================================================
do
    local cur = "EN"
    getgenv().FH_CurrentLang = cur
    local sec = Tabs.Settings:AddSection({Name="Language"})
    addOpt(sec, "AddDropdown", "FH_Lang", {Title="Язык интерфейса", Values={"EN","RU"}, Default="EN"}, function(v)
        cur = v or "EN"
        getgenv().FH_CurrentLang = cur
        Notify("FH", "Язык: " .. cur, 2)
    end)
end

-- ============================================================
-- 18. JUMP CIRCLE
-- ============================================================
do
    local settings = getgenv().FH_JumpCircleSettings or {enabled=false, color=Color3.fromRGB(255, 105, 180)}
    getgenv().FH_JumpCircleSettings = settings
    local image = "rbxassetid://133238425773760"
    local conn
    local function spawnCircle(pos)
        if not settings.enabled then return end
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Size = Vector3.new(0.5, 0.05, 0.5)
        part.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0))
        part.Transparency = 1
        part.Parent = Workspace
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.AlwaysOnTop = true
        sg.LightInfluence = 0
        sg.PixelsPerStud = 100
        sg.Parent = part
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = image
        img.ImageColor3 = settings.color
        img.Parent = sg
        local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(part, info, {Size = Vector3.new(7, 0.05, 7)}):Play()
        TweenService:Create(img, info, {ImageTransparency = 1}):Play()
        Debris:AddItem(part, 0.9)
    end
    local function bind(char)
        if conn then conn:Disconnect(); conn = nil end
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        conn = hum.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Jumping and settings.enabled then
                spawnCircle(hrp.Position - Vector3.new(0, 2.8, 0))
            end
        end)
    end
    LocalPlayer.CharacterAdded:Connect(bind)
    if LocalPlayer.Character then bind(LocalPlayer.Character) end

    local sec = Tabs.Visual:AddSection({Name="Jump Circle"})
    addOpt(sec, "AddToggle", "FH_JumpCircleOn", {Title="Круг при прыжке", Default=false}, function(v)
        settings.enabled = v
        if v and LocalPlayer.Character then bind(LocalPlayer.Character) end
    end)
    addOpt(sec, "AddColorPicker", "FH_JumpCircleCol", {Title="Цвет", Default=Color3.fromRGB(255,105,180)}, function(c)
        settings.color = c
    end)
end

-- ============================================================
-- 19. RTX
-- ============================================================
do
    local rtxOn = false
    local saved, savedChildren, addedFx = {}, {}, {}
    local function enable()
        if rtxOn then return end
        rtxOn = true
        local props = {"Ambient","Brightness","ColorShift_Bottom","ColorShift_Top",
            "EnvironmentDiffuseScale","EnvironmentSpecularScale","GlobalShadows",
            "OutdoorAmbient","ShadowSoftness","ClockTime","ExposureCompensation"}
        for _, p in ipairs(props) do
            pcall(function() saved[p] = Lighting[p] end)
        end
        for _, ch in ipairs(Lighting:GetChildren()) do
            if ch:IsA("PostEffect") or ch:IsA("Sky") or ch:IsA("Atmosphere") then
                ch.Parent = nil
                table.insert(savedChildren, ch)
            end
        end
        local bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.35; bloom.Size = 20; bloom.Threshold = 0.85
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Brightness = 0.05; cc.Contrast = 0.25; cc.Saturation = 0.15
        cc.TintColor = Color3.fromRGB(255, 245, 230)
        local sr = Instance.new("SunRaysEffect")
        sr.Intensity = 0.12; sr.Spread = 0.8
        local sky = Instance.new("Sky")
        sky.SkyboxBk = "http://www.roblox.com/asset/?id=151165214"
        sky.SkyboxDn = "http://www.roblox.com/asset/?id=151165197"
        sky.SkyboxFt = "http://www.roblox.com/asset/?id=151165224"
        sky.SkyboxLf = "http://www.roblox.com/asset/?id=151165191"
        sky.SkyboxRt = "http://www.roblox.com/asset/?id=151165206"
        sky.SkyboxUp = "http://www.roblox.com/asset/?id=151165227"
        local atm = Instance.new("Atmosphere")
        atm.Density = 0.3; atm.Offset = 0.25
        atm.Color = Color3.fromRGB(199, 175, 166)
        atm.Decay = Color3.fromRGB(44, 39, 33)
        atm.Glare = 0.35; atm.Haze = 1.2
        addedFx = {bloom, cc, sr, sky, atm}
        for _, fx in ipairs(addedFx) do fx.Parent = Lighting end
        pcall(function() Lighting.Technology = Enum.Technology.Future end)
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 100)
        Lighting.ShadowSoftness = 0.15
        Lighting.ClockTime = 14
        Lighting.ExposureCompensation = 0.1
    end
    local function disable()
        if not rtxOn then return end
        rtxOn = false
        for _, fx in ipairs(addedFx) do pcall(function() fx:Destroy() end) end
        addedFx = {}
        for _, ch in ipairs(savedChildren) do pcall(function() ch.Parent = Lighting end) end
        savedChildren = {}
        for k, v in pairs(saved) do pcall(function() Lighting[k] = v end) end
        saved = {}
    end
    local sec = Tabs.Effects:AddSection({Name="RTX Shader"})
    addOpt(sec, "AddToggle", "FH_RTXOn", {Title="Включить RTX", Default=false}, function(v)
        if v then enable() else disable() end
    end)
end

-- ============================================================
-- ФИНАЛ PART 2/2
-- ============================================================
pcall(function() Window:SelectTab(1) end)
print("[FH] ============================================")
print("[FH] Part 2/2 loaded — FortniHub v21.0.0 RC")
print("[FH] Combat: Silent, KillAura, AutoGrab")
print("[FH] Movement: Speed, Fly, Noclip, Bhop, Spinbot, Freeze")
print("[FH] Visual: ESP, Tracer, Backtrack 1.0/2.0, JumpCircle, PlayerPanel")
print("[FH] Effects: WorldFX, BeamFX, Aura 2.0 (доп.), RTX, Skybox")
print("[FH] Farm: FarmV3 (единственный)")
print("[FH] Troll: TP-tool, FakeDeath, Teleport, VoteDuper")
print("[FH] Utility: Invis, Anti-Fling, Anti-Void, WaterProt, FadeDisabler, Boost")
print("[FH] Extra: TradeHelper, Language, Anti-Aim")
print("[FH] ============================================")
getgenv().FH_Part2Loaded = true
