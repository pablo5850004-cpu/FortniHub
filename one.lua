-- ============================================================
-- main.lua — FortniHub MM2 v20.2 — ЧАСТЬ 1/2
-- Fixes by Steve (chemist/analyst)
-- ============================================================
-- ЧТО ИСПРАВЛЕНО В ЭТОЙ ЧАСТИ:
--  [FIX]  Убрана ватермарка FH_Watermark_v21 и все её OnChanged
--  [FIX]  Бэктрек починен: единый кольцевой буфер + синхрон с Client Ghost
--  [FIX]  Client Ghost переименован в "Backtrack 2.0" и лежит в Visual
--  [FIX]  Конфиги: загрузка биндов идёт через FH_BindState, не через Options
--  [FIX]  Эмоции работают как анимации (Looped=false, Priority=Idle/Movement)
--  [FIX]  Удалены: строка поиска эмоций, поиск эмодзи, кнопка списка эмоций
--  [FIX]  Старые звуки (SND_BASES khenn791) заменены на набор из KITI
--  [FIX]  GameSounds блок удалён полностью
--  [FIX]  UISounds: звук теперь играет на КАЖДОЕ переключение опции
--  [FIX]  Удалён Advanced AutoFarm (остался только FarmV3)
--  [FIX]  Удалена модель оружия (и SpecialMesh-версия, и GetObjects-версия)
--  [FIX]  График скорости переписан через отдельный поток с проверкой Drawing
--  [FIX]  Скайбокс: только toggle + dropdown (один выбор), свой ID удалён
--  [FIX]  Флинг: предикт по пингу ТОЛЬКО для ходящих (velocity > 2)
--  [FIX]  Aura 2.0: переименована, добавлена вторая часть (как backtrack)
--  [FIX]  Плейлист: заглушка (dropdown + Play/Stop кнопки)
-- ============================================================

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
local VERSION = "20.2.0 RC"
local CREDITS = "by HOTI and Ve315 | fixes: Steve"

-- ============================================================
-- ХЕЛПЕРЫ
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

local function srand(a, b)
    local _orig = math.random
    if a == nil then return _orig() end
    if b == nil then
        if type(a) ~= "number" or a ~= a or a < 1 then a = 1 end
        if a > 2147483647 then a = 2147483647 end
        return _orig(math.floor(a))
    end
    a, b = tonumber(a) or 0, tonumber(b) or 0
    if b < a then a, b = b, a end
    if a == b then return a end
    return _orig(math.floor(a), math.floor(b))
end

local function getRoundData()
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
    end)
    if ok and type(m) == "table" then return m.PlayerData end
    return nil
end

local function getRoleFromData(p)
    if not p then return "lobby" end
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
    end)
    if ok and type(m) == "table" and type(m.PlayerData) == "table" then
        local d = m.PlayerData[p.Name]
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
            local allData = getRoundData()
            if allData then
                for _, info in pairs(allData) do
                    if type(info) == "table" and info.Role == "Sheriff" and info.Dead then
                        return "hero"
                    end
                end
            end
            return "sheriff"
        end
    end
    return "innocent"
end

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
    }
    local body
    for _, u in ipairs(urls) do
        local ok, b = pcall(function() return game:HttpGet(u, true) end)
        if ok and type(b) == "string" and #b > 1000 and not b:find("<html") then
            body = b
            break
        end
    end
    if not body then error("[FH] Не удалось загрузить Fluent UI") end
    local fn = loadstring(body, "@Fluent")
    Fluent = fn and fn()
    if type(Fluent) ~= "table" then error("[FH] Fluent не таблица") end
    print("[FH] Fluent загружен")
end

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
        Size = UDim2.fromOffset(420, 300),
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
Tabs.Animations = Window:AddTab({Title="Эмоции"})
Tabs.Utility    = Window:AddTab({Title="Утилиты"})
Tabs.Troll      = Window:AddTab({Title="Троллинг"})
Tabs.Settings   = Window:AddTab({Title="Настройки"})

-- ============================================================
-- РЕЕСТР OnChanged (нужен для конфигов и биндов)
-- ============================================================
local OnChangedRegistry = {}
getgenv().FH_OnChangedRegistry = OnChangedRegistry
local function registerOnChanged(name, cb) OnChangedRegistry[name] = cb end
local function fireRegistered(name, value)
    local cb = OnChangedRegistry[name]
    if cb then pcall(cb, value) end
end

local function addOpt(container, method, name, opts, callback)
    local opt = container[method](container, name, opts)
    if opt and callback then
        opt:OnChanged(callback)
        registerOnChanged(name, callback)
    end
    return opt
end

-- ============================================================
-- NOTIFY (с защитой от спама)
-- ============================================================
local lastNotify = {}
local function Notify(title, content, dur)
    local k = tostring(title) .. "|" .. tostring(content)
    if lastNotify[k] and (tick() - lastNotify[k]) < 0.5 then return end
    lastNotify[k] = tick()
    pcall(function() Fluent:Notify({Title=title, Content=content, Duration=dur or 3}) end)
end
getgenv().FH_Notify = Notify

task.spawn(function()
    task.wait(0.8)
    Notify("FortniHub", "Скрипт создан HOTI и Ve315. Фиксы: Steve.", 7)
    task.wait(1.2)
    Notify("FortniHub", "v" .. VERSION .. " — Release Candidate.", 6)
end)

-- ============================================================
-- UI SOUNDS (звук на КАЖДОЕ переключение любой опции)
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
    ToggleSound = "Laser Click",
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
        s.Volume = 0.6
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 5)
    end)
end
getgenv().FH_PlayUISound = playUISound

-- Глобальный хук: на любое OnChanged любой опции — щёлкаем
do
    local hooked = {}
    task.spawn(function()
        task.wait(1)
        for name, opt in pairs(Options) do
            if type(opt) == "table" and opt.OnChanged and not hooked[name] then
                hooked[name] = true
                local isBool = false
                pcall(function()
                    if opt.Type == "Toggle" or type(opt.Value) == "boolean" then isBool = true end
                end)
                if isBool then
                    opt:OnChanged(function(v)
                        if v then playUISound("EnableSound") else playUISound("DisableSound") end
                    end)
                end
            end
        end
    end)
end

-- ============================================================
-- HUD (без ватермарки — только pill сверху и FH + FPS + ping)
-- ============================================================
local HUDGui, FPSLabel, PingLabel, Pill
do
    pcall(function()
        for _, name in ipairs({"FH_HUD_v18","FH_HUD","FH_HUD_v19","FH_HUD_v20","FH_HUD_v21"}) do
            local old = CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
    HUDGui = Instance.new("ScreenGui")
    HUDGui.Name = "FH_HUD_v22"
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
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragMoved = false; dragStart = i.Position; posStart = Pill.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local d = i.Position - dragStart
            if math.abs(d.X) > TAP or math.abs(d.Y) > TAP then dragMoved = true end
            if dragMoved then
                Pill.Position = UDim2.new(posStart.X.Scale, posStart.X.Offset + d.X, posStart.Y.Scale, posStart.Y.Offset + d.Y)
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
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
-- BACKTRACK 1.0 — синхронизированный кольцевой буфер
-- Клиентский клон персонажа двигается по "прошлому" в зависимости от пинга.
-- ============================================================
local BacktrackCore = {}
do
    local BTCAP = 256
    local hist = table.create(BTCAP)
    for i = 1, BTCAP do hist[i] = {0, CFrame.identity} end
    local first, count = 1, 0
    local ping, pingAt = 0.15, 0
    local model, pairs_ = nil, {}
    local enabled = false
    local trackCol = Color3.fromRGB(255, 60, 60)
    local usePing = true
    local manualDelay = 0.15

    local function kill()
        if model then pcall(function() model:Destroy() end) model = nil end
        pairs_ = {}
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
        local rp = {}
        for _, o in ipairs(char:GetDescendants()) do
            if o:IsA("BasePart") then rp[#rp+1] = o end
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
                pairs_[#pairs_+1] = {o, rp[ci]}
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

        if now - pingAt >= 0.2 then
            pingAt = now
            local ok, v = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            end)
            ping = math.clamp((ok and v) or 0.15, 0.05, 0.6)
        end

        local delay = usePing and ping or manualDelay
        local target = now - delay
        local tcf = cf
        for k = count, 1, -1 do
            local s = hist[(first + k - 2) % BTCAP + 1]
            if s[1] <= target then tcf = s[2]; break end
        end

        local inv = hrp.CFrame:Inverse()
        for i = 1, #pairs_ do
            local cp, rp = pairs_[i][1], pairs_[i][2]
            if cp and cp.Parent and rp and rp.Parent then
                cp.CFrame = tcf * (inv * rp.CFrame)
            end
        end
    end

    function BacktrackCore.setEnabled(v)
        enabled = v
        if v then
            if not _G.FH_BT_CONN then
                _G.FH_BT_CONN = RunService.Heartbeat:Connect(tickBt)
            end
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
    function BacktrackCore.isEnabled() return enabled end

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if enabled then build() end
    end)
end
getgenv().FH_BacktrackCore = BacktrackCore

-- ============================================================
-- BACKTRACK 2.0 (бывш. Client Ghost) — расширенный, с настройками
-- Работает поверх Backtrack 1.0, но с собственной прозрачностью и цветом.
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

    local history = {}
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

-- UI для бэктрека
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
    addOpt(bt2Sec, "AddToggle", "Backtrack2On", {Title="Включить (Ghost)", Default=false}, function(v)
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
-- ЭМОЦИИ — только анимации поверх ходьбы (Looped=false, Priority=Movement)
-- Удалены: строка поиска, поиск эмодзи, кнопка списка эмоций.
-- ============================================================
do
    local EMOTE_LIST = {
        ["Default Dance"] = 80877772569772,
        ["Floss Dance"] = 5917570207,
        ["Griddy"] = 116065653184749,
        ["Macarena"] = 91274761264433,
        ["Kazotsky"] = 97629500912487,
        ["Gangnam Style"] = 77205409178702,
        ["Miku Dance"] = 117734400993750,
        ["Slickback"] = 103789826265487,
        ["Torture Dance"] = 116099356619436,
        ["Nyan Nyan!"] = 73796726960568,
        ["Dio Pose"] = 76736978166708,
        ["Teto Dance"] = 93031502567721,
        ["Michael Myers"] = 88229016850146,
        ["Family Guy"] = 78459263478161,
        ["SpongeBob Shuffle"] = 107899954696611,
        ["Helicopter"] = 84555218084038,
        ["Conga"] = 97547955535086,
        ["Plug Walk"] = 100359724990859,
        ["Billy Bounce"] = 126516908191316,
        ["Kawaii Groove"] = 77152953688098,
        ["Absolute Cinema"] = 97258018304125,
        ["Flopping Fish"] = 133142324349281,
        ["Cute Jump"] = 80556794144838,
        ["Around Town"] = 3576747102,
        ["Fashionable"] = 3576745472,
        ["Swish"] = 3821527813,
        ["Idol"] = 4102317848,
        ["Sneaky"] = 3576754235,
        ["Robot"] = 3576721660,
        ["Twirl"] = 3716633898,
        ["Bodybuilder"] = 3994130516,
        ["Shuffle"] = 4391208058,
        ["Dorky Dance"] = 4212499637,
        ["Break Dance"] = 5915773992,
        ["Zombie"] = 4212496830,
        ["Cha Cha"] = 6865013133,
        ["Rock On"] = 5915782672,
        ["Hero Landing"] = 5104377791,
        ["Victory Dance"] = 15506503658,
        ["Monkey"] = 3716636630,
        ["Salute"] = 3360689775,
        ["Superhero Reveal"] = 3696759798,
        ["Hype Dance"] = 3696757129,
        ["Take The L"] = 123159156696507,
        ["Belly Dancing"] = 131939729732240,
        ["Rambunctious"] = 134311528115559,
        ["Ballin"] = 96293409369770,
        ["Skibidi"] = 124828909173982,
        ["Virtual Insanity"] = 83261816934732,
        ["Club Penguin"] = 98099211500155,
        ["Push-Up"] = 117922227854118,
        ["Split"] = 98522218962476,
        ["HeadBanging"] = 87447252507832,
        ["Jumpstyle"] = 99563839802389,
        ["Paranoid"] = 123407922818447,
        ["Smeeze"] = 131683926643291,
        ["Slenderman"] = 81926508907412,
        ["RONALDO"] = 97547486465713,
        ["Electro Shuffle"] = 96426537876059,
        ["Foreign Shuffle"] = 101507732056031,
        ["Squidward Yell"] = 109244554368414,
        ["Mewing / Mogging"] = 135493514352956,
        ["Golden Freddy"] = 122463450997235,
        ["Lethal Dance"] = 77108921633993,
        ["At Ease"] = 76993139936388,
        ["Barrel"] = 84511772437190,
        ["Honored One"] = 121643381580730,
        ["Sukuna"] = 91839607010745,
        ["Do that thang"] = 113772829398170,
        ["Squat?"] = 95441477641149,
        ["Nya Anime Dance"] = 126647057611522,
        ["Samba"] = 6869813008,
        ["Sandwich Dance"] = 4390121879,
        ["Swag Walk"] = 10478377385,
        ["Vroom Vroom"] = 18526410572,
        ["Jersey Joe"] = 134149640725489,
        ["Wally West"] = 133948663586698,
        ["Doodle Dance"] = 107091254142209,
        ["Fishin"] = 3994129128,
        ["Tree"] = 4049634387,
        ["Godlike"] = 3823158750,
        ["Dizzy"] = 3934986896,
        ["Fancy Feet"] = 3934988903,
        ["Rambunctious 2"] = 134311528115559,
    }

    local emoteNames = {}
    for name in pairs(EMOTE_LIST) do emoteNames[#emoteNames+1] = name end
    table.sort(emoteNames, function(a, b) return a:lower() < b:lower() end)

    local animSec = Tabs.Animations:AddSection({Name="Эмоции (анимации)"})
    local currentTrack, currentAnim
    local drop = animSec:AddDropdown("FHBigEmotePick", {
        Title = "Выбрать эмоцию",
        Values = emoteNames,
        Default = emoteNames[1] or "Default Dance",
    })
    addOpt(animSec, "AddToggle", "FHBigEmoteLoop", {Title="Зациклить", Default=false}, function() end)

    local function stopCurrent()
        if currentTrack then
            pcall(function() currentTrack:Stop() end)
            currentTrack = nil
        end
        if currentAnim then
            pcall(function() currentAnim:Destroy() end)
            currentAnim = nil
        end
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
            -- АНИМАЦИЯ, не эмоция: Priority = Movement, Looped = false
            track.Priority = Enum.AnimationPriority.Movement
            track.Looped = (Options.FHBigEmoteLoop and Options.FHBigEmoteLoop.Value) or false
            track.Stopped:Connect(function()
                anim:Destroy()
                if currentTrack == track then currentTrack = nil end
            end)
            pcall(function() track:Play(0) end)
            currentTrack = track
            currentAnim = anim
            Notify("FH", "Анимация: " .. name, 2)
        else
            anim:Destroy()
            Notify("FH", "Не удалось: " .. name, 2)
        end
    end

    animSec:AddButton({Title="Запустить", Callback=function()
        local v = drop.Value
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" then playEmoteByName(v) end
    end})
    animSec:AddButton({Title="Остановить", Callback=function()
        stopCurrent()
        Notify("FH", "Остановлено", 2)
    end})
end

-- ============================================================
-- ЗВУКИ (замена SND_BASES khenn791 на набор KITI)
-- GameSounds блок удалён. Здесь только 3 события: sheriffKill/murderKill/sheriffShoot.
-- ============================================================
local SoundKit = {}
do
    -- Набор из KITI (те же ID, что были в GameSounds, отобранные топовые)
    SoundKit.List = {
        "Default", "Rust Headshot", "Neverlose", "Sparkle", "Skeet",
        "Bubble", "Bameware", "Money", "Notif", "Shutter",
        "TF2 Critical", "TF2 Hitsound", "Bow Hit", "OSU", "OneNN",
        "Bell", "Fatality", "Bonk", "Minecraft", "Gamesense",
        "Weeb", "Beep", "Ding", "Among Us", "UwU",
        "Blood SFX", "Blood Burst", "Default Sound", "LazerBeam", "WindowsXPError",
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
        ["Default Sound"]  = "rbxassetid://330595293",
        ["LazerBeam"]      = "rbxassetid://130791043",
        ["WindowsXPError"] = "rbxassetid://160715357",
    }

    local cfg = {
        sheriffKill   = {on=false, name="Rust Headshot", volume=1},
        murderKill    = {on=false, name="Skeet",         volume=1},
        sheriffShoot  = {on=false, name="Sparkle",       volume=0.6},
    }
    SoundKit.Cfg = cfg

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
                if deadRole == "Murderer" and (myRole == "Sheriff" or myRole == "Hero") and cfg.sheriffKill.on then
                    local now = os.clock()
                    if now - lastSnd.sheriffKill >= 0.15 then
                        lastSnd.sheriffKill = now
                        SoundKit.play(cfg.sheriffKill.name, cfg.sheriffKill.volume)
                    end
                end
                if deadRole ~= "Murderer" and murdererAlive and cfg.murderKill.on then
                    local now = os.clock()
                    if now - lastSnd.murderKill >= 0.15 then
                        lastSnd.murderKill = now
                        SoundKit.play(cfg.murderKill.name, cfg.murderKill.volume)
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
                if not cfg.sheriffShoot.on then return end
                local myRole = getMyRole()
                if not (myRole == "Sheriff" or myRole == "Hero") then return end
                local char = LocalPlayer.Character
                if not char then return end
                if typeof(tool) == "Instance" and tool:IsDescendantOf(char) then
                    local now = os.clock()
                    if now - lastSnd.sheriffShoot >= 0.05 then
                        lastSnd.sheriffShoot = now
                        SoundKit.play(cfg.sheriffShoot.name, cfg.sheriffShoot.volume)
                    end
                end
            end)
        end
    end)
end
getgenv().FH_SoundKit = SoundKit

do
    local sndSec = Tabs.Utility:AddSection({Name="Звуки (KITI)"})

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
-- UI SOUNDS вкладка (звуки интерфейса — фикс "не работали")
-- ============================================================
do
    local sec = Tabs.Utility:AddSection({Name="UI Sounds"})
    addOpt(sec, "AddToggle", "FH_UISoundsOn", {Title="Звуки интерфейса", Default=true}, function(v)
        UISoundCfg.Enabled = v
    end)
    addOpt(sec, "AddDropdown", "FH_UISoundEnable", {Title="Звук включения", Values={"Enable 1","Sparkle","Laser Click","Enable 2","Notify"}, Default="Enable 1"}, function(v)
        UISoundCfg.EnableSound = v
    end)
    addOpt(sec, "AddDropdown", "FH_UISoundDisable", {Title="Звук выключения", Values={"Enable 1","Sparkle","Laser Click","Enable 2","Notify"}, Default="Enable 1"}, function(v)
        UISoundCfg.DisableSound = v
    end)
    sec:AddButton({Title="Тест вкл", Callback=function() playUISound("EnableSound") end})
    sec:AddButton({Title="Тест выкл", Callback=function() playUISound("DisableSound") end})
end

-- ============================================================
-- GRAFИК СКОРОСТИ (переписан: отдельный поток, проверка Drawing)
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
        mgLines, mgShadows = {}, {}
        mgHist = {}
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
-- СКАЙБОКС (только toggle + dropdown с ОДНИМ выбором; свой ID удалён)
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
    addOpt(sec, "AddToggle", "SkyOn", {Title="Включить", Default=false}, function(v)
        skyboxEnabled = v
        if v then
            local cur = Options.SkyName and Options.SkyName.Value or "Jungle"
            applySky(cur)
        else
            restoreSky()
        end
    end)
    addOpt(sec, "AddDropdown", "SkyName", {
        Title = "Небо",
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
    local playlist = {}
    local sec = Tabs.Utility:AddSection({Name="Плейлист"})
    addOpt(sec, "AddDropdown", "FHPlaylistPick", {
        Title = "Трек",
        Values = {"(нет треков)"},
        Default = "(нет треков)",
    }, function() end)
    sec:AddButton({Title="Играть", Callback=function()
        Notify("FH", "Плейлист в разработке", 2)
    end})
    sec:AddButton({Title="Стоп", Callback=function()
        Notify("FH", "Плейлист в разработке", 2)
    end})
    sec:AddButton({Title="Добавить трек (ID)", Callback=function()
        Notify("FH", "Плейлист в разработке", 2)
    end})
end

-- ============================================================
-- ФЛИНГ (предикт ТОЛЬКО для ходящих, чтобы компенсировать пинг)
-- ============================================================
do
    local flingMode = "Classic"
    local function getPing()
        local p = 0.1
        pcall(function()
            local v = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            if v and v == v and v > 0 then p = v / 1000 end
        end)
        return math.clamp(p, 0.02, 0.4)
    end
    local function clickedPlayer()
        local m = LocalPlayer:GetMouse()
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

    -- Предикт позиции: если цель ходит (speed > 2), учитываем её velocity * ping
    local function predictPos(char, hrp)
        if not hrp then return nil end
        local vel = hrp.AssemblyLinearVelocity or Vector3.zero
        local flatSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
        local pos = hrp.Position
        if flatSpeed > 2 then
            pos = pos + Vector3.new(vel.X, 0, vel.Z) * getPing()
        end
        return pos
    end

    local function flingClassic(tp)
        if not tp or not tp.Character then return end
        local hrp = getHRP()
        if not hrp then return end
        local tc = tp.Character
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        if not thrp then return end
        local oldPos = hrp.CFrame
        local cam = Workspace.CurrentCamera
        cam.CameraSubject = thrp

        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6) -- был 9e9, снизил чтобы не кикало

        local tm = tick()
        repeat
            if hrp and hrp.Parent and thrp and thrp.Parent then
                local pos = predictPos(tc, thrp)
                hrp.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
                hrp.AssemblyLinearVelocity = Vector3.new(5e4, 5e4 * 10, 5e4)
                hrp.AssemblyAngularVelocity = Vector3.new(5e5, 5e5, 5e5)
            end
            RunService.Heartbeat:Wait()
        until tick() - tm > 1.5
        if bv then bv:Destroy() end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        cam.CameraSubject = hum
        if hrp then
            pcall(function()
                hrp.CFrame = oldPos
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    local function flingDeathLoop(tp)
        if not tp then return end
        local hrp0 = getHRP()
        if not hrp0 then return end
        local savedCF = hrp0.CFrame
        local name = tp.Name
        local startTime = tick()
        while tick() - startTime < 30 do
            local d = getRoundData()
            local info = d and d[name]
            local pl = Players:FindFirstChild(name)
            if not pl then break end
            local char = pl.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not char or (info and info.Dead) or (hum and hum.Health <= 0) then break end
            local hrp = getHRP()
            if not hrp then break end
            local tc = pl.Character
            local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
            if not thrp then break end
            local bv = Instance.new("BodyVelocity")
            bv.Parent = hrp
            bv.Velocity = Vector3.zero
            bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            local tm = tick()
            repeat
                if hrp and hrp.Parent and thrp and thrp.Parent then
                    local pos = predictPos(tc, thrp)
                    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
                    hrp.AssemblyLinearVelocity = Vector3.new(5e4, 5e4 * 10, 5e4)
                    hrp.AssemblyAngularVelocity = Vector3.new(5e5, 5e5, 5e5)
                end
                RunService.Heartbeat:Wait()
            until tick() - tm > 1.5
            if bv then bv:Destroy() end
            task.wait(0.1)
        end
        local hrpEnd = getHRP()
        if hrpEnd then
            pcall(function()
                hrpEnd.CFrame = savedCF
                hrpEnd.AssemblyLinearVelocity = Vector3.zero
                hrpEnd.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    local function doFling(tp)
        if flingMode == "Classic" then flingClassic(tp)
        else flingDeathLoop(tp) end
    end

    local ftTool, ftActConn, ftOn = nil, nil, false
    local function giveFlingTool()
        if not ftOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("fling")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("fling")
        end
        if existing then ftTool = existing; return end
        ftTool = Instance.new("Tool")
        ftTool.Name = "fling"
        ftTool.RequiresHandle = false
        ftTool.CanBeDropped = false
        ftTool.Parent = bp
        ftActConn = ftTool.Activated:Connect(function()
            local tp = clickedPlayer()
            if tp then doFling(tp) end
        end)
    end
    local function removeFlingTool()
        if ftActConn then pcall(function() ftActConn:Disconnect() end); ftActConn = nil end
        if ftTool then pcall(function() ftTool:Destroy() end); ftTool = nil end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            local t = bp:FindFirstChild("fling")
            if t then pcall(function() t:Destroy() end) end
        end
        local c = LocalPlayer.Character
        if c then
            local t = c:FindFirstChild("fling")
            if t then pcall(function() t:Destroy() end) end
        end
    end

    local sec = Tabs.Troll:AddSection({Name="Отброс (с предиктом)"})
    addOpt(sec, "AddToggle", "ToolFling", {Title="Тул отброса", Default=false}, function(v)
        ftOn = v
        if v then giveFlingTool() else removeFlingTool() end
    end)
    addOpt(sec, "AddDropdown", "FlingMode", {Title="Режим", Values={"Classic","DeathLoop"}, Default="Classic"}, function(v)
        flingMode = v or "Classic"
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if ftOn then giveFlingTool() end
    end)
end

-- ============================================================
-- AURA 2.0 (переименована, две части, как бэктрек)
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

    function AuraCore.setEnabled(v)
        if v then start() else stop() end
    end
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
    addOpt(sec, "AddToggle", "AuraOn", {Title="Включить", Default=false}, function(v)
        AuraCore.setEnabled(v)
    end)
    addOpt(sec, "AddDropdown", "AuraType", {
        Title="Тип",
        Values={"angel","starlight","heavenly","ribbon","sakura","wind","flow","star"},
        Default="angel",
    }, function(v)
        AuraCore.setType(v)
    end)
    addOpt(sec, "AddColorPicker", "AuraCol", {Title="Цвет", Default=Color3.fromRGB(133,220,255)}, function(c)
        AuraCore.setColor(c)
    end)
end

-- ============================================================
-- НАСТРОЙКИ + КОНФИГИ (фикс загрузки биндов через FH_BindState)
-- ============================================================
do
    local tS = Tabs.Settings
    local setSec = tS:AddSection({Name="Основные"})
    addOpt(setSec, "AddToggle", "ShowHUD", {Title="Показывать HUD", Default=true}, function(v)
        if HUDGui then HUDGui.Enabled = v end
    end)
    addOpt(setSec, "AddSlider", "FPSCap", {Title="Лимит FPS (0 - без лимита)", Min=0, Max=9999, Default=0, Rounding=0}, function(v)
        pcall(function() if setfpscap then setfpscap(tonumber(v) or 0) end end)
    end)
    setSec:AddButton({Title="Переподключиться к серверу", Callback=function()
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
            if Enum.KeyCode[v] then return "K:" .. v end
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
    local function deserialize(s)
        local prefix, rest = string.match(s, "^(%a):(.*)$")
        if not prefix then return nil end
        if prefix == "K" then return Enum.KeyCode[rest] end
        if prefix == "C" then
            local r, g, b = string.match(rest, "([^,]+),([^,]+),([^,]+)")
            if r and g and b then return Color3.new(tonumber(r), tonumber(g), tonumber(b)) end
            return nil
        end
        if prefix == "E" then
            local et, name = string.match(rest, "^([^|]+)|(.+)$")
            if et and name then
                local E = Enum[et]
                if E and E[name] then return E[name] end
            end
            return nil
        end
        if prefix == "N" then return tonumber(rest) end
        if prefix == "B" then return rest == "true" end
        if prefix == "S" then return rest:gsub("\\n", "\n"):gsub("\\t", "\t") end
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

    -- ФИКС: загрузка биндов идёт через FH_BindState, а не через Options
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
                        -- Обрабатываем бинды через FH_BindState
                        local id = key:sub(10)
                        local enumVal
                        if ser:sub(1, 2) == "K:" then
                            local sname = ser:sub(3)
                            if Enum.KeyCode[sname] then enumVal = Enum.KeyCode[sname] end
                        elseif ser:sub(1, 2) == "E:" then
                            local raw = ser:sub(3)
                            local et, kn = string.match(raw, "^([^|]+)|(.+)$")
                            if et and kn then
                                local E = Enum[et]
                                if E and E[kn] then enumVal = E[kn] end
                            end
                        elseif ser:sub(1, 2) == "S:" then
                            local sname = ser:sub(3)
                            if Enum.KeyCode[sname] then enumVal = Enum.KeyCode[sname] end
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
    local drop = cfgSec:AddDropdown("ConfigPick", {Title="Выбрать конфиг", Values=curList, Default=curList[1]})
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
-- БИНДЫ (использует FH_BindState — конфиги теперь с ним работают)
-- ============================================================
do
    local tB = Tabs.Binds
    local BIND_LIST = {
        {id="SilentEnabled",   title="Тихий выстрел",        cat="Бой",       opt="SilentEnabled"},
        {id="KAOn",            title="Килл Аура",            cat="Бой",       opt="KAOn"},
        {id="SpeedToggle",     title="Скорость",             cat="Движение",  opt="SpeedToggle"},
        {id="Noclip",          title="Noclip",               cat="Движение",  opt="Noclip"},
        {id="FlyToggle",       title="Полёт",                cat="Движение",  opt="FlyToggle"},
        {id="BhopOn",          title="Банихоп",              cat="Движение",  opt="BhopOn"},
        {id="BacktrackOn",     title="Бэктрек 1.0",          cat="Визуал",    opt="BacktrackOn"},
        {id="Backtrack2On",    title="Бэктрек 2.0",          cat="Визуал",    opt="Backtrack2On"},
        {id="AuraOn",          title="Aura 2.0",             cat="Эффекты",   opt="AuraOn"},
        {id="ToolFling",       title="Отброс",               cat="Троллинг",  opt="ToolFling"},
    }
    local BindState = {}
    for _, e in ipairs(BIND_LIST) do
        BindState[e.id] = {key=nil, touchOn=false, btn=nil, def=e}
    end
    getgenv().FH_BindState = BindState

    local touchGui = Instance.new("ScreenGui")
    touchGui.Name = "FH_TouchBinds_v22"
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
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true; moved = false; dragStart = i.Position; posStart = btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - dragStart
                if math.abs(d.X) > 4 or math.abs(d.Y) > 4 then moved = true end
                if moved then
                    btn.Position = UDim2.new(posStart.X.Scale, posStart.X.Offset + d.X, posStart.Y.Scale, posStart.Y.Offset + d.Y)
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
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
            pcall(function() listSec:AddButton({Title="--- " .. currentCat .. " ---", Callback=function() end}) end)
        end
        local st = BindState[def.id]
        local kb = listSec:AddKeybind("BIND_KEY_" .. def.id, {Title=def.title, Default="Unknown"})
        kb:OnChanged(function(k)
            if typeof(k) == "EnumItem" then
                st.key = k
                Notify("FH", "Бинд: " .. def.title .. " > " .. tostring(k), 2)
            else
                st.key = nil
            end
        end)
        registerOnChanged("BIND_KEY_" .. def.id, function(k)
            if typeof(k) == "EnumItem" then st.key = k else st.key = nil end
        end)
        addOpt(listSec, "AddToggle", "BIND_TCH_" .. def.id, {Title="  Кнопка: " .. def.title, Default=false}, function(v)
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

    local setSec = tB:AddSection({Name="Настройки биндов"})
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
    getgenv().BINDS_UNLOAD = function()
        for id, _ in pairs(BindState) do killTouchButton(id) end
        pcall(function() touchGui:Destroy() end)
    end
end

-- ============================================================
-- ФИНАЛ PART 1/2
-- ============================================================
pcall(function() Window:SelectTab(1) end)
print("[FH] ============================================")
print("[FH] Part 1/2 — FortniHub v" .. VERSION .. " — " .. CREDITS)
print("[FH] Исправлено: бэктрек, эмоции, звуки, конфиги, флинг, аура, скайбокс, график")
print("[FH] Part 2/2: Silent Aim, KillAura, ESP, FarmV3, Troll, Anti, Utility (без AdvFarm)")
print("[FH] ============================================")
-- ============================================================
-- main.lua — FortniHub MM2 v20.2 — ЧАСТЬ 2/2
-- Fixes by Steve (chemist/analyst)
-- ============================================================
--  [FIX]  Silent Aim — восстановлен, с предиктом и хуками
--  [FIX]  KillAura — v1/v2, рефакторинг
--  [FIX]  Движение — Speed/Noclip/Fly/Bhop/Spinbot/InfJump/Freeze/SpeedGlitch
--  [FIX]  ESP — восстановлен полностью (Box/Name/Dist/Chams/Arrows/Skeleton)
--  [FIX]  Tracer/WorldFX/MurderFX — восстановлены
--  [FIX]  FarmV3 — единственный фарм (Advanced AutoFarm удалён)
--  [FIX]  Troll — TP-тул, Fake Death, Teleport (без модели оружия)
--  [FIX]  TradeHelper, VoteDuper, WaterProt, FadeDisabler, AntiCoin
--  [FIX]  Beam Effects — восстановлены
--  [FIX]  Aura 2.0 — расширение первой части (доп. ауры)
--  [FIX]  Anti-Aim, Player Panel, PNG Avatars, Language
--  [FIX]  Jump Circle, RTX — восстановлены
--  [DEL]  GameSounds, Watermark, Custom Gun Models, Advanced AutoFarm
-- ============================================================

if not (Window and Options and Notify and getRoundData and getRoleFromData and getHRP and getHum) then
    warn("[FH] Part 1 не загружена — Part 2/2 пропущена.")
    return
end

local Tabs = getgenv().FH_Tabs
if not Tabs then warn("[FH] FH_Tabs не найден."); return end

local _OnChangedRegistry = getgenv().FH_OnChangedRegistry or {}
getgenv().FH_OnChangedRegistry = _OnChangedRegistry
local function _regOnChanged(name, cb) _OnChangedRegistry[name] = cb end
local function _addOpt(container, method, name, opts, callback)
    local opt = container[method](container, name, opts)
    if opt and callback then
        opt:OnChanged(callback)
        _regOnChanged(name, callback)
    end
    return opt
end
local _uiRoot = function() return (gethui and gethui()) or CoreGui end

-- ============================================================
-- 1. SILENT AIM
-- ============================================================
do
    local MAX_RANGE = 300
    local rs = ReplicatedStorage
    local players = Players
    local collection = CollectionService
    local run = RunService
    local lp = LocalPlayer
    local stats = Stats

    getgenv().SILENT_S = {
        enabled=false, predict=true, force=false, auto_on=false, auto_delay=0,
        am_sheriff=false, fire_gap=0, last_shot=0, stand_off=15,
    }
    local SS = getgenv().SILENT_S

    local silent_section = Tabs.Combat:AddSection({Name="Тихий выстрел"})

    local gap_min, gap_seen, gap_gun = 0, false, nil
    local want_since = 0

    local function gap_reset() gap_min=0 gap_seen=false SS.fire_gap=0 end
    local function gap_push(value)
        if value <= 0 then return end
        if not gap_seen or value < gap_min then
            gap_min=value gap_seen=true SS.fire_gap=value
        end
    end

    local round_mod
    local function get_round()
        if round_mod then return round_mod end
        local ok, m = pcall(function()
            return require(rs:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
        end)
        if ok and type(m) == "table" then round_mod = m end
        return round_mod
    end
    local function holds(container, name)
        return container ~= nil and container:FindFirstChild(name) ~= nil
    end
    local function lp_has_gun()
        return holds(lp.Character, "Gun") or holds(lp:FindFirstChildOfClass("Backpack"), "Gun")
    end

    local target_player, target_char, target_part, target_hum

    local function refresh_target()
        local found
        local m = get_round()
        local data = m and m.PlayerData or nil
        if type(data) == "table" then
            local me = data[lp.Name]
            SS.am_sheriff = (me ~= nil and (me.Role == "Sheriff" or me.Role == "Hero")) or lp_has_gun()
            for name, d in pairs(data) do
                if type(d) == "table" and d.Role == "Murderer" and not d.Dead then
                    found = players:FindFirstChild(name)
                    break
                end
            end
        else
            SS.am_sheriff = lp_has_gun()
        end
        if not found then
            for _, plr in ipairs(players:GetPlayers()) do
                if plr ~= lp and holds(plr.Character, "Knife") then
                    found = plr
                    break
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
            target_char = char
            target_part, target_hum = nil, nil
        end
        if not char then return end
        if not target_part or not target_part.Parent then
            target_part = char:FindFirstChild("HumanoidRootPart")
                or char:FindFirstChild("UpperTorso")
                or char:FindFirstChild("Torso")
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
    local ignore_time = 0

    local function refresh_ignore()
        local now = os.clock()
        if #ignore_base > 0 and now - ignore_time < 0.5 then return end
        ignore_time = now
        table.clear(ignore_base)
        local char = lp.Character
        if char then ignore_base[1] = char end
        local ok, tagged = pcall(function() return collection:GetTagged("WeaponPassthrough") end)
        if ok and type(tagged) == "table" then
            for k = 1, #tagged do ignore_base[#ignore_base + 1] = tagged[k] end
        end
    end

    local function trace(origin, direction)
        refresh_ignore()
        table.clear(ignore_work)
        for k = 1, #ignore_base do ignore_work[k] = ignore_base[k] end
        local result
        for _ = 1, 6 do
            ray_params.FilterDescendantsInstances = ignore_work
            result = workspace:Raycast(origin, direction, ray_params)
            if not result then break end
            local inst = result.Instance
            if not inst then break end
            local ok, tr = pcall(function() return inst.Transparency end)
            if not ok or tr ~= 1 then break end
            ignore_work[#ignore_work + 1] = inst
        end
        return result
    end

    local function gun_attachment()
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil, nil end
        return hrp:FindFirstChild("GunRaycastAttachment"), hrp
    end
    local function origin_cframe()
        local att, hrp = gun_attachment()
        if att then return att.WorldCFrame end
        if hrp then return hrp.CFrame end
    end
    local function grav()
        local ok, g = pcall(function() return workspace.Gravity end)
        if ok and type(g) == "number" and g > 0 then return g end
        return 0
    end

    local snap_t, snap_p = table.create(48, 0), table.create(48, Vector3.zero)
    local snap_n, snap_i = 0, 0
    local TR = {
        part=nil, pos=nil, time=0, vel=Vector3.zero, gap=0,
        ready=false, fresh=Vector3.zero, air=false, air_since=0,
        jumping=false, jump_v=0, fresh_ok=false, turn=0,
        spoof=0, clr=0, air_edge=0, jump_fresh=false,
    }
    local SK = {vt=table.create(48,0), dx=table.create(48,0), dz=table.create(48,0), vn=0, vi=0}
    local EC = {ping=0, rtt=0, jitter=0, seen=false, step=0, step_seen=false}

    local function step_push(dt)
        if dt <= 0 or dt > 0.5 then return end
        if EC.step_seen then EC.step = EC.step * 0.85 + dt * 0.15
        else EC.step = dt; EC.step_seen = true end
    end
    local function sample_span()
        local span = math.max(EC.step, TR.gap)
        if span <= 0 then return 0 end
        return span
    end

    local HY = {pos={}, w={}, n=0, weight=0, primary=nil, stamp=0, conf=0}

    local ground_params = RaycastParams.new()
    ground_params.FilterType = Enum.RaycastFilterType.Exclude
    ground_params.IgnoreWater = true
    local ground_filter, axis_pool = {}, {}

    local function ground_below(pos, reach)
        table.clear(ground_filter)
        local n = 0
        local char = target_char
        if char then n = n + 1; ground_filter[n] = char end
        local mine = lp.Character
        if mine then n = n + 1; ground_filter[n] = mine end
        ground_params.FilterDescendantsInstances = ground_filter
        local res = workspace:Raycast(pos, Vector3.new(0, -reach, 0), ground_params)
        if res then return res.Position.Y end
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

    local function fit_velocity()
        if snap_n < 3 then return nil end
        local newest = snap_get(0)
        local used, sum_d = 0, 0
        local win = sample_span() * 4
        for k = 0, snap_n - 1 do
            local t = snap_get(k)
            if newest - t > win then break end
            used = used + 1
            sum_d = sum_d + t - newest
        end
        if used < 3 then return nil end
        local mean_d = sum_d / used
        local num, den = Vector3.zero, 0
        for k = 0, used - 1 do
            local t, p = snap_get(k)
            local d = t - newest - mean_d
            num = num + p * d
            den = den + d * d
        end
        if den < 1e-8 then return nil end
        return num / den, -mean_d
    end

    local function recent_velocity()
        if snap_n < 2 then return nil end
        local newest, head = snap_get(0)
        local fallback, fallback_age
        local target_span = sample_span() * 2
        local max_span = target_span * 2
        for k = 1, snap_n - 1 do
            local t, p = snap_get(k)
            local dt = newest - t
            if dt > max_span then break end
            if dt > 0 then
                fallback = (head - p) / dt
                fallback_age = dt * 0.5
                if dt >= target_span then return fallback, fallback_age end
            end
        end
        return fallback, fallback_age
    end

    local KIN = {ok=false, ax=0, az=0, smax=0}
    local function kin_clear() KIN.ok=false KIN.ax=0 KIN.az=0 KIN.smax=0 end
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
        local det = n*(s2*s4 - s3*s3) - s1*(s1*s4 - s3*s2) + s2*(s1*s3 - s2*s2)
        if math.abs(det) < 1e-9 then return nil end
        local function solve(b0, b1, b2)
            local d1 = n*(b1*s4 - s3*b2) - b0*(s1*s4 - s3*s2) + s2*(s1*b2 - b1*s2)
            local d2 = n*(s2*b2 - b1*s3) - s1*(s1*b2 - b1*s2) + b0*(s1*s3 - s2*s2)
            return d1/det, d2/det
        end
        local cx1, cx2 = solve(bx0, bx1, bx2)
        local cz1, cz2 = solve(bz0, bz1, bz2)
        local vx, vz = cx1/scale, cz1/scale
        local ax, az = 2*cx2/(scale*scale), 2*cz2/(scale*scale)
        if vx ~= vx or vz ~= vz or ax ~= ax or az ~= az then return nil end
        return Vector3.new(vx, 0, vz), Vector3.new(ax, 0, az)
    end
    local function kin_update()
        local kv, ka = fit_kin()
        if not kv then KIN.ok=false KIN.ax=0 KIN.az=0 return nil end
        KIN.ok = true
        local sp = math.sqrt(kv.X*kv.X + kv.Z*kv.Z)
        if sp > KIN.smax then KIN.smax = sp
        else KIN.smax = KIN.smax * 0.985 + sp * 0.015 end
        if ka and not TR.air then
            local am = math.sqrt(ka.X*ka.X + ka.Z*ka.Z)
            local ax, az = ka.X, ka.Z
            if am > 280 and am > 0 then
                ax = ax * 280 / am
                az = az * 280 / am
            end
            KIN.ax = KIN.ax*0.5 + ax*0.5
            KIN.az = KIN.az*0.5 + az*0.5
        else
            KIN.ax = KIN.ax*0.5
            KIN.az = KIN.az*0.5
        end
        return kv
    end

    local function snap_vel(k)
        local t0, p0 = snap_get(k)
        local t1, p1 = snap_get(k+1)
        local d = t0 - t1
        if d <= 0 then return nil end
        return (p0 - p1) / d, d
    end
    local function vert_accel()
        if snap_n < 3 then return nil end
        local v0, d0 = snap_vel(0)
        local v1, d1 = snap_vel(1)
        if not v0 or not v1 then return nil end
        local span = (d0 + d1) * 0.5
        if span <= 1e-4 then return nil end
        return (v0.Y - v1.Y) / span
    end
    local function air_vy()
        if snap_n < 2 then return nil end
        local edge = TR.air_edge
        if edge <= 0 then return nil end
        local g = grav()
        local newest, head = snap_get(0)
        local want = sample_span() * 2
        local best
        for k = 1, snap_n - 1 do
            local t, p = snap_get(k)
            if t < edge then break end
            local dt = newest - t
            if dt > 1e-4 then
                best = (head.Y - p.Y)/dt - 0.5*g*dt
                if dt >= want then break end
            end
        end
        return best
    end

    local function body_clearance()
        local part, hum = target_part, target_hum
        if not part or not hum then return 0 end
        local ok, v = pcall(function() return part.Size.Y * 0.5 + hum.HipHeight end)
        if ok and type(v) == "number" and v > 0 then return v end
        return 0
    end
    local GC, JL = {base=0, seen=false}, {v=0, seen=false}
    local function stand_clearance()
        if GC.seen then return GC.base end
        return body_clearance()
    end

    local function engine_vel(part)
        local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
        if not ok or typeof(v) ~= "Vector3" then
            ok, v = pcall(function() return part.Velocity end)
        end
        if not ok or typeof(v) ~= "Vector3" then return nil end
        if v.Magnitude ~= v.Magnitude then return nil end
        return v
    end

    local function track_clear()
        TR.part=nil TR.pos=nil TR.vel=Vector3.zero TR.gap=0
        TR.ready=false TR.fresh=Vector3.zero TR.air=false
        TR.jumping=false TR.jump_v=0 TR.fresh_ok=false
        TR.turn=0 TR.spoof=0 TR.clr=0 TR.air_edge=0 TR.jump_fresh=false
        GC.base=0 GC.seen=false
        JL.v=0 JL.seen=false
        snap_n, snap_i = 0, 0
        SK.vn, SK.vi = 0, 0
        kin_clear()
    end
    local function track_seed(part, pos, now)
        TR.part=part TR.pos=pos TR.time=now
        TR.vel=Vector3.zero TR.fresh=Vector3.zero TR.fresh_ok=false
        TR.turn=0 TR.jump_v=0 TR.gap=0 TR.ready=false
        TR.spoof=0 TR.air_edge=0 TR.jump_fresh=false
        GC.base=0 GC.seen=false
        snap_n, snap_i = 0, 0
        kin_clear()
        snap_push(now, pos)
    end

    local function track_fresh(now)
        local part = target_part
        if not part or not part.Parent then TR.fresh_ok = false; return end
        local pos = part.Position
        local g = grav()
        local sv = snap_vel(0)
        local vy = sv and sv.Y or 0
        local accel = vert_accel()
        local falling = accel ~= nil and accel < -g*0.5
        local guess = stand_clearance()
        local reach = guess + 6 + math.abs(vy)*sample_span()*4
        local air
        local gy = ground_below(pos, reach)
        if gy then
            local clr = pos.Y - gy
            TR.clr = clr
            if math.abs(vy) < 1 and not falling then
                if GC.seen then
                    if clr < GC.base then GC.base = GC.base*0.7 + clr*0.3
                    else GC.base = GC.base*0.98 + clr*0.02 end
                else GC.base=clr; GC.seen=true end
            end
            local floor = GC.seen and GC.base or guess
            local tol = math.max(floor * 0.35, 1)
            air = clr > floor + tol
            if not air and falling and math.abs(vy) > 4 and clr > floor + 0.35 then air = true end
        else air = true end
        if air ~= TR.air then
            TR.air_edge = now
            if air then
                TR.air_since = now
                TR.jump_fresh = true
                TR.jump_v = JL.seen and JL.v or math.max(vy, 0)
            else
                TR.jump_fresh = false
                TR.jump_v = 0
            end
        end
        local model_vy = TR.jump_v - g*math.max(0, now - TR.air_since)
        TR.air = air
        TR.jumping = air and (vy > 1 or model_vy > 1)
    end

    local function track(now)
        local part = target_part
        if not part or not part.Parent then
            if TR.part then track_clear() end
            return
        end
        track_fresh(now)
        local pos = part.Position
        if part ~= TR.part or not TR.pos then
            track_seed(part, pos, now)
            return
        end
        local dt = now - TR.time
        if dt > 0.75 or (pos - TR.pos).Magnitude > 140 then
            track_seed(part, pos, now)
            return
        end
        if dt <= 0 then return end
        step_push(dt)
        TR.gap = dt
        snap_push(now, pos)
        TR.pos = pos
        TR.time = now
        local fit = fit_velocity()
        local fast = recent_velocity()
        local engine = engine_vel(part)
        -- упрощённый merge
        local base = fast or fit or Vector3.zero
        if engine and not TR.air then
            base = Vector3.new(engine.X, base.Y, engine.Z)
        end
        local kv = kin_update()
        if kv then base = Vector3.new(kv.X, base.Y, kv.Z) end
        if TR.air then
            local vy = air_vy()
            if vy then
                base = Vector3.new(base.X, vy, base.Z)
                local since = math.max(0, now - TR.air_edge)
                if TR.jump_fresh and since <= 0.2 then
                    local impulse = vy + grav()*since
                    if impulse > 1 then
                        if JL.seen then JL.v = JL.v*0.7 + impulse*0.3
                        else JL.v = impulse; JL.seen = true end
                        if impulse > TR.jump_v then TR.jump_v = impulse end
                    end
                else TR.jump_fresh = false end
            end
        end
        TR.vel = base
        TR.ready = fit ~= nil or fast ~= nil
        TR.fresh = TR.vel
        TR.fresh_ok = TR.ready
        local raw = fast or TR.vel
        SK.vi = SK.vi % 48 + 1
        SK.vt[SK.vi] = now
        SK.dx[SK.vi] = raw.X
        SK.dz[SK.vi] = raw.Z
        if SK.vn < 48 then SK.vn = SK.vn + 1 end
    end

    local function raw_rtt()
        local a, b
        local ok, ms = pcall(function()
            return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and type(ms) == "number" and ms == ms and ms > 4 and ms < 800 then
            a = ms/1000
        end
        local fine, value = pcall(function() return lp:GetNetworkPing() end)
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
            EC.jitter = EC.jitter*0.9 + math.abs(rtt - EC.rtt)*0.1
            EC.rtt = EC.rtt*0.82 + rtt*0.18
        else EC.rtt=rtt; EC.jitter=0; EC.seen=true end
        EC.ping = EC.rtt
    end
    local function lead_time()
        if not EC.seen then return 0 end
        local stale = 0
        if TR.time > 0 and EC.step_seen then
            stale = math.clamp(os.clock() - TR.time, 0, EC.step)
        end
        return math.clamp(EC.rtt + EC.jitter*0.5 + stale, 0, 1)
    end

    local function predict_from(base, sa, sb, fh, now)
        local span = math.max(0, sa + sb)
        local g = grav()
        local dir = fh
        if dir.Magnitude == 0 then dir = Vector3.new(TR.vel.X, 0, TR.vel.Z) end
        local x, z
        if span > 0 and KIN.ok then
            local age = math.clamp(now - TR.time, 0, sample_span()*2)
            local ax, az = KIN.ax, KIN.az
            if TR.air or math.sqrt(ax*ax + az*az) < 40 then ax, az = 0, 0 end
            local vx = dir.X + ax*age
            local vz = dir.Z + az*age
            local ta = math.min(span, 0.15)
            local dx = vx*span + 0.5*ax*ta*ta
            local dz = vz*span + 0.5*az*ta*ta
            x = base.X + dx
            z = base.Z + dz
        else
            x = base.X + dir.X*span
            z = base.Z + dir.Z*span
        end
        local y = base.Y
        if TR.air and span > 0 then
            local vy = TR.vel.Y
            local phase = math.max(0, now - TR.air_since)
            local modeled = TR.jump_v - g*phase
            if TR.jumping and TR.jump_v > 0 and g > 0 and phase <= TR.jump_v/g and modeled > vy then vy = modeled end
            y = base.Y + vy*span - 0.5*g*span*span
            if y < base.Y then
                local clearance = stand_clearance()
                local reach = base.Y - y + clearance
                local gy = ground_below(Vector3.new(x, base.Y, z), reach)
                if gy then
                    local floor = gy + clearance
                    if y < floor then y = floor end
                end
            end
        end
        return Vector3.new(x, y, z)
    end

    local hit_names = {
        "HumanoidRootPart","UpperTorso","Torso","LowerTorso","Head",
        "RightUpperArm","LeftUpperArm","Right Arm","Left Arm",
        "RightUpperLeg","LeftUpperLeg","Right Leg","Left Leg",
        "RightLowerLeg","LeftLowerLeg",
    }
    local hit_parts, hit_count, hit_char = {}, 0, nil
    local function refresh_parts()
        local char = target_char
        if char == hit_char then return end
        table.clear(hit_parts)
        hit_count = 0
        hit_char = char
        if not char then return end
        for k = 1, #hit_names do
            local part = char:FindFirstChild(hit_names[k])
            if part and part:IsA("BasePart") then
                hit_count = hit_count + 1
                hit_parts[hit_count] = part
            end
        end
    end

    local function los_clear(origin, point)
        if not origin or not point then return false end
        local delta = point - origin
        local dist = delta.Magnitude
        if dist < 0.5 then return true end
        if dist > MAX_RANGE then return false end
        local hit = trace(origin, delta)
        if not hit then return true end
        local inst = hit.Instance
        local char = target_char
        if inst and char and (inst == char or inst:IsDescendantOf(char)) then return true end
        return (hit.Position - origin).Magnitude >= dist - 0.75
    end

    local pred_off, pred_stamp = Vector3.zero, 0
    local function lead_offset()
        local part = target_part
        if not part or not part.Parent then return Vector3.zero end
        if not SS.predict or not TR.ready then return Vector3.zero end
        local base = part.Position
        local now = os.clock()
        local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
        local point = predict_from(base, 0, lead_time(), fh, now)
        pred_stamp = now
        pred_off = point - base
        return pred_off
    end
    local function pick_point(origin)
        refresh_parts()
        if hit_count == 0 then return nil end
        local off = lead_offset()
        for k = 1, hit_count do
            local part = hit_parts[k]
            if part.Parent then
                local point = part.Position + off
                if not origin then return point end
                if los_clear(origin, point) then return point end
            else hit_char = nil end
        end
        return hit_parts[1] and (hit_parts[1].Position + off) or nil
    end

    local weapon_service, orig_mouse, orig_screen, hook_mouse, hook_screen
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

    local gun_fired_conn, last_fire_stamp = nil, 0
    local function on_gun_fired(tool)
        if typeof(tool) ~= "Instance" then return end
        local char = lp.Character
        if not char then return end
        local ok, mine = pcall(function() return tool:IsDescendantOf(char) end)
        if not ok or not mine then return end
        local now = os.clock()
        if last_fire_stamp > 0 and want_since > 0 and want_since <= last_fire_stamp then
            gap_push(now - last_fire_stamp)
        end
        last_fire_stamp = now
    end
    local function connect_gun_fired()
        if gun_fired_conn then return end
        local m = get_weapon_service()
        if not m then return end
        local ev = m.GunFired
        if typeof(ev) ~= "Instance" then return end
        gun_fired_conn = ev.OnClientEvent:Connect(function(tool)
            pcall(on_gun_fired, tool)
        end)
    end

    local function get_gun()
        local char = lp.Character
        if char then
            local g = char:FindFirstChild("Gun")
            if g then return g, true end
        end
        local bp = lp:FindFirstChildOfClass("Backpack")
        if bp then
            local g = bp:FindFirstChild("Gun")
            if g then return g, false end
        end
        return nil, false
    end

    local function auto_step(now)
        if not SS.auto_on or not SS.enabled or not SS.am_sheriff or not target_alive() then
            want_since = 0
            return
        end
        local gun, equipped = get_gun()
        if not gun then want_since = 0; return end
        if gun ~= gap_gun then gap_gun = gun; gap_reset() end
        if not equipped then
            want_since = 0
            local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(gun) end) end
            return
        end
        if want_since == 0 then want_since = now end
        local hold = SS.auto_delay
        if hold < SS.fire_gap then hold = SS.fire_gap end
        local since = last_fire_stamp > 0 and last_fire_stamp or SS.last_shot
        if now - since < hold then return end
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

    local next_role, next_hook = 0, 0
    local main_conn = run.Heartbeat:Connect(function()
        pcall(function()
            if not SS.enabled then return end
            local now = os.clock()
            if now >= next_role then
                next_role = now + 0.2
                refresh_target()
            end
            sample_ping()
            track(now)
            if now >= next_hook then
                next_hook = now + 1
                install_hooks()
                connect_gun_fired()
            end
            auto_step(now)
        end)
    end)

    _addOpt(silent_section, "AddToggle", "SilentEnabled", {
        Title = "Включить", Default = false,
    }, function(v)
        SS.enabled = v
        if v then
            task.spawn(function()
                pcall(install_hooks)
                pcall(connect_gun_fired)
                pcall(refresh_target)
            end)
        else
            track_clear()
        end
        Notify("FH", "Silent " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)
    _addOpt(silent_section, "AddToggle", "SilentPredict", {
        Title = "Предсказание", Default = true,
    }, function(v)
        SS.predict = v
        if not v then track_clear() end
    end)
    _addOpt(silent_section, "AddToggle", "SilentAuto", {
        Title = "Авто-выстрел", Default = false,
    }, function(v) SS.auto_on = v end)
    _addOpt(silent_section, "AddSlider", "SilentAutoDelay", {
        Title = "Задержка авто", Default = 0, Min = 0, Max = 600, Rounding = 0,
    }, function(v) SS.auto_delay = (tonumber(v) or 0) / 1000 end)

    getgenv().SILENT_UNLOAD = function()
        SS.enabled = false
        SS.predict = false
        SS.auto_on = false
        track_clear()
        if gun_fired_conn then pcall(function() gun_fired_conn:Disconnect() end); gun_fired_conn = nil end
        if main_conn then pcall(function() main_conn:Disconnect() end); main_conn = nil end
        local m = weapon_service
        if m then
            pcall(function() setreadonly(m, false) end)
            if orig_mouse then pcall(function() m.GetMouseTargetCFrame = orig_mouse end) end
            if orig_screen then pcall(function() m.GetTargetPosition = orig_screen end) end
        end
    end
end

-- ============================================================
-- 2. KNIFE SILENT (заглушка)
-- ============================================================
do
    local sec = Tabs.Combat:AddSection({Name="Тихий бросок ножа"})
    _addOpt(sec, "AddToggle", "KnifeSilentOn", {Title="Включить", Default=false}, function(v)
        if v then
            Notify("FH", "В разработке", 3)
            task.delay(0.5, function()
                local o = Options.KnifeSilentOn
                if o then pcall(function() o:SetValue(false) end) end
            end)
        end
    end)
end

-- ============================================================
-- 3. KILL AURA
-- ============================================================
do
    local kaV1 = {on=false, dist=30, lastHit=0}
    local kaV2 = {on=false, dist=30, lastHit=0}
    local version = "v2"
    local sec = Tabs.Combat:AddSection({Name="Килл Аура"})
    _addOpt(sec, "AddDropdown", "KAVersion", {Title="Версия", Values={"v1","v2"}, Default="v2"}, function(v)
        version = v
        kaV1.on = false
        kaV2.on = false
        if Options.KAOn and Options.KAOn.Value then
            kaV1.on = v == "v1"
            kaV2.on = v == "v2"
        end
    end)
    _addOpt(sec, "AddToggle", "KAOn", {Title="Включить", Default=false}, function(v)
        kaV1.on = v and version == "v1"
        kaV2.on = v and version == "v2"
    end)
    _addOpt(sec, "AddSlider", "KADist", {Title="Радиус", Min=5, Max=60, Default=30, Rounding=0}, function(v)
        local n = tonumber(v) or 30
        kaV1.dist = n; kaV2.dist = n
    end)

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
            if p ~= LocalPlayer then
                local tc = p.Character
                if tc then
                    local th = tc:FindFirstChildOfClass("Humanoid")
                    local tp = tc:FindFirstChild("HumanoidRootPart")
                    if th and th.Health > 0 and tp and (tp.Position - my.Position).Magnitude <= state.dist then
                        victims[#victims+1] = tp
                    end
                end
            end
        end
        if #victims > 0 then
            pcall(function() stabbed:FireServer() end)
            for _, v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            state.lastHit = tick()
        end
    end

    RunService.Heartbeat:Connect(function() pcall(hitLoop, kaV1) end)
    RunService.Heartbeat:Connect(function() pcall(hitLoop, kaV2) end)
end

-- ============================================================
-- 4. AUTO GRAB GUN
-- ============================================================
do
    local sec = Tabs.Combat:AddSection({Name="Авто-подбор пистолета"})
    local enabled, failedRound, isGrabbing = false, false, false
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

    _addOpt(sec, "AddToggle", "AutoGrabGun", {Title="Включить", Default=false}, function(v) enabled = v end)
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
end

-- ============================================================
-- 5. MOVEMENT
-- ============================================================
do
    local tM = Tabs.Movement
    local S = {frozen=false, freezeUpKey=Enum.KeyCode.Space, freezeDownKey=Enum.KeyCode.LeftAlt}

    local mvSec = tM:AddSection({Name="Основное"})
    _addOpt(mvSec, "AddToggle", "SpeedToggle", {Title="Скорость", Default=false}, function() end)
    _addOpt(mvSec, "AddSlider", "SpeedValue", {Title="Скорость", Min=16, Max=500, Default=32, Rounding=0}, function() end)
    _addOpt(mvSec, "AddToggle", "Noclip", {Title="Noclip", Default=false}, function() end)
    _addOpt(mvSec, "AddToggle", "Spinbot", {Title="Spinbot", Default=false}, function() end)
    _addOpt(mvSec, "AddSlider", "SpinSpeed", {Title="Скорость кручения", Min=1, Max=50, Default=8, Rounding=0}, function() end)
    _addOpt(mvSec, "AddToggle", "InfJump", {Title="Бесконечный прыжок", Default=false}, function() end)
    _addOpt(mvSec, "AddToggle", "JumpPowerToggle", {Title="Своя сила прыжка", Default=false}, function() end)
    _addOpt(mvSec, "AddSlider", "JumpPowerVal", {Title="Сила прыжка", Min=50, Max=500, Default=100, Rounding=0}, function() end)
    _addOpt(mvSec, "AddToggle", "FlyToggle", {Title="Полёт", Default=false}, function() end)
    _addOpt(mvSec, "AddSlider", "FlySpeed", {Title="Скорость полёта", Min=20, Max=500, Default=60, Rounding=0}, function() end)
    _addOpt(mvSec, "AddToggle", "BhopOn", {Title="Банихоп", Default=false}, function() end)
    _addOpt(mvSec, "AddSlider", "BhopPower", {Title="Сила банихопа", Min=10, Max=150, Default=40, Rounding=0}, function() end)

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
        local step = math.max(bhopPower*0.1, 1)
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

    -- Freeze
    local freezeSec = tM:AddSection({Name="Заморозка"})
    _addOpt(freezeSec, "AddToggle", "FreezeToggle", {Title="Включить", Default=false}, function(v) S.frozen = v end)
    _addOpt(freezeSec, "AddSlider", "FreezeSpeed", {Title="Скорость", Min=20, Max=300, Default=60, Rounding=0}, function() end)
    local fUp = freezeSec:AddKeybind("FreezeUpKey", {Title="Кнопка ВВЕРХ", Default="Space"})
    fUp:OnChanged(function(k) if typeof(k) == "EnumItem" then S.freezeUpKey = k end end)
    registerOnChanged("FreezeUpKey", function(k) if typeof(k) == "EnumItem" then S.freezeUpKey = k end end)
    local fDown = freezeSec:AddKeybind("FreezeDownKey", {Title="Кнопка ВНИЗ", Default="LeftAlt"})
    fDown:OnChanged(function(k) if typeof(k) == "EnumItem" then S.freezeDownKey = k end end)
    registerOnChanged("FreezeDownKey", function(k) if typeof(k) == "EnumItem" then S.freezeDownKey = k end end)

    RunService.Heartbeat:Connect(function()
        if not S.frozen then
            local hrp = getHRP()
            if hrp then
                local bv = hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv:Destroy() end
            end
            return
        end
        local hum = getHum()
        if not hum then return end
        hum.WalkSpeed = 0
        local hrp = getHRP()
        if not hrp then return end
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
    end)

    getgenv().MOVE_UNLOAD = function()
        S.frozen = false
        local hrp = getHRP()
        if hrp then
            local bv = hrp:FindFirstChild("FH_FreezeBV")
            if bv then bv:Destroy() end
        end
        flyOff()
    end
end

-- ============================================================
-- 6. ESP
-- ============================================================
do
    local espState = {
        enabled=false, box=false, boxCol={Color3.fromRGB(255,255,255),1}, boxType="Static",
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
    local chamsFolder = Instance.new("Folder") chamsFolder.Name = "FH_Chams" chamsFolder.Parent = Workspace

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
        d = {box={}, boxFill=nil, name=nil, dist=nil, skel={}, arrow=nil}
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
        if e.boxFill then pcall(function() e.boxFill:Remove() end) end
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
                                local col = espState.boxCol[1]
                                local a = (espState.boxCol[2] or 1) * fade
                                local lines = {{l,top,r,top},{r,top,r,bot},{r,bot,l,bot},{l,bot,l,top}}
                                for i, ln in ipairs(lines) do
                                    local line = ensureBox(e, i)
                                    line.From = Vector2.new(ln[1], ln[2])
                                    line.To = Vector2.new(ln[3], ln[4])
                                    line.Color = col
                                    line.Transparency = a
                                    line.Visible = true
                                end
                                for i = 5, #e.box do e.box[i].Visible = false end
                            else
                                for _, ln in pairs(e.box) do ln.Visible = false end
                            end
                            if espState.name then
                                if not e.name then
                                    e.name = Drawing.new("Text")
                                    e.name.Size = 13
                                    e.name.Center = true
                                    e.name.Outline = true
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
                                    e.dist.Size = 12
                                    e.dist.Center = true
                                    e.dist.Outline = true
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
                                            dr.Thickness = 1
                                            dr.Transparency = 1
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
                        h.FillColor = fill[1]
                        h.FillTransparency = fill[2]
                        h.OutlineColor = outl[1]
                        h.OutlineTransparency = outl[2]
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

    local tV = Tabs.Visual
    local espSec = tV:AddSection({Name="ESP Игроков"})
    _addOpt(espSec, "AddToggle", "ESPOn", {Title="Включить ESP", Default=false}, function(v)
        espState.enabled = v
        if not v then
            for _, e in pairs(drawCache) do dispose(e) end
            drawCache = {}
        end
    end)
    _addOpt(espSec, "AddToggle", "ESPBox", {Title="Рамка", Default=false}, function(v) espState.box = v end)
    _addOpt(espSec, "AddColorPicker", "ESPBoxCol", {Title="Цвет рамки", Default=Color3.new(1,1,1)}, function(c) espState.boxCol[1] = c end)
    _addOpt(espSec, "AddToggle", "ESPName", {Title="Имя", Default=false}, function(v) espState.name = v end)
    _addOpt(espSec, "AddColorPicker", "ESPNameCol", {Title="Цвет имени", Default=Color3.new(1,1,1)}, function(c) espState.nameCol[1] = c end)
    _addOpt(espSec, "AddToggle", "ESPDist", {Title="Дистанция", Default=false}, function(v) espState.dist = v end)
    _addOpt(espSec, "AddColorPicker", "ESPDistCol", {Title="Цвет дистанции", Default=Color3.fromRGB(220,220,220)}, function(c) espState.distCol[1] = c end)
    _addOpt(espSec, "AddToggle", "ESPSkel", {Title="Скелет", Default=false}, function(v) espState.skel = v end)
    _addOpt(espSec, "AddColorPicker", "ESPSkelCol", {Title="Цвет скелета", Default=Color3.new(1,1,1)}, function(c) espState.skelCol[1] = c end)
    _addOpt(espSec, "AddToggle", "ESPChams", {Title="Свечение", Default=false}, function(v) espState.chams = v end)

    local function chamsPair(prefix, role, defFill, defOut)
        _addOpt(espSec, "AddColorPicker", "ChamsF"..prefix, {Title=role.." заливка", Default=defFill}, function(c)
            espState["chamsF"..prefix][1] = c
        end)
        _addOpt(espSec, "AddSlider", "ChamsFA"..prefix, {Title=role.." прозр", Min=0, Max=1, Default=0.55, Rounding=2}, function(v)
            espState["chamsF"..prefix][2] = tonumber(v) or 0.55
        end)
        _addOpt(espSec, "AddColorPicker", "ChamsO"..prefix, {Title=role.." обводка", Default=defOut}, function(c)
            espState["chamsO"..prefix][1] = c
        end)
        _addOpt(espSec, "AddSlider", "ChamsOA"..prefix, {Title=role.." прозр обводки", Min=0, Max=1, Default=0.15, Rounding=2}, function(v)
            espState["chamsO"..prefix][2] = tonumber(v) or 0.15
        end)
    end
    chamsPair("Mur", "Убийца", Color3.fromRGB(255,60,60), Color3.fromRGB(255,120,120))
    chamsPair("Inno", "Мирный", Color3.new(1,1,1), Color3.new(1,1,1))
    chamsPair("Shf", "Шериф", Color3.fromRGB(0,153,255), Color3.fromRGB(120,200,255))
    chamsPair("Hero", "Герой", Color3.fromRGB(255,215,0), Color3.fromRGB(255,240,140))

    _addOpt(espSec, "AddToggle", "ESPArrows", {Title="Стрелки", Default=false}, function(v) espState.arrows = v end)
    _addOpt(espSec, "AddColorPicker", "ESPArrMur", {Title="Убийца", Default=Color3.fromRGB(255,60,60)}, function(c) espState.arrowMur = c end)
    _addOpt(espSec, "AddColorPicker", "ESPArrInno", {Title="Мирный", Default=Color3.new(1,1,1)}, function(c) espState.arrowInno = c end)
    _addOpt(espSec, "AddColorPicker", "ESPArrShf", {Title="Шериф", Default=Color3.fromRGB(0,153,255)}, function(c) espState.arrowShf = c end)
    _addOpt(espSec, "AddColorPicker", "ESPArrHero", {Title="Герой", Default=Color3.fromRGB(255,215,0)}, function(c) espState.arrowHero = c end)
    _addOpt(espSec, "AddSlider", "ESPArrSz", {Title="Размер стрелок", Min=16, Max=96, Default=42, Rounding=0}, function(v) espState.arrowSize = tonumber(v) or 42 end)
    _addOpt(espSec, "AddSlider", "ESPArrDist", {Title="Дистанция стрелок", Min=40, Max=520, Default=260, Rounding=0}, function(v) espState.arrowDist = tonumber(v) or 260 end)
    _addOpt(espSec, "AddSlider", "ESPMaxDist", {Title="Макс дистанция ESP", Min=50, Max=1000, Default=500, Rounding=0}, function(v) espState.maxDist = tonumber(v) or 500 end)
    _addOpt(espSec, "AddToggle", "ESPAllowLocal", {Title="Показывать себя", Default=false}, function(v) espState.allowLocal = v end)
end

-- ============================================================
-- 7. TRACER
-- ============================================================
do
    local tracerOn, tracerCol, tracerDur = false, Color3.fromRGB(133, 220, 255), 1
    local tracerTrack = true

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
                TweenService:Create(beam, TweenInfo.new(0.2), {Width0=0, Width1=0}):Play()
            end
        end)
    end
    local tracerConn
    local function connect()
        if tracerConn then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices")
                :WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if not ok or not remote then return end
        tracerConn = remote.OnClientEvent:Connect(function(gun, sv, ev)
            if not tracerOn then return end
            local c = LocalPlayer.Character
            if not c then return end
            if not (typeof(gun) == "Instance" and gun:IsDescendantOf(c)) then return end
            if tracerTrack then createTracer(sv, ev) end
        end)
    end

    local sec = Tabs.Effects:AddSection({Name="Трассер пули"})
    _addOpt(sec, "AddToggle", "TracerOn", {Title="Включить", Default=false}, function(v)
        tracerOn = v
        if v then connect() end
    end)
    _addOpt(sec, "AddToggle", "TracerTrackBullet", {Title="Отслеживание пуль", Default=true}, function(v) tracerTrack = v end)
    _addOpt(sec, "AddColorPicker", "TracerCol", {Title="Цвет", Default=Color3.fromRGB(133,220,255)}, function(c) tracerCol = c end)
    _addOpt(sec, "AddSlider", "TracerDur", {Title="Длительность", Min=0.1, Max=5, Default=1, Rounding=1}, function(v) tracerDur = tonumber(v) or 1 end)
end

-- ============================================================
-- 8. WORLD EFFECTS
-- ============================================================
do
    local fxOn, fxType, fxCol, fxRate = false, "Snow", Color3.fromRGB(150,200,255), 250
    local fxPart, fxEmit, fxConn

    local function style()
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
    _addOpt(sec, "AddToggle", "FXOn", {Title="Включить", Default=false}, function(v)
        fxOn = v
        if v then start() else stop() end
    end)
    _addOpt(sec, "AddDropdown", "FXType", {Title="Тип", Values={"Снег","Сакура"}, Default="Снег"}, function(v)
        fxType = (v == "Сакура") and "Sakura" or "Snow"
        if fxOn then style() end
    end)
    _addOpt(sec, "AddColorPicker", "FXCol", {Title="Цвет", Default=Color3.fromRGB(150,200,255)}, function(c)
        fxCol = c
        if fxEmit then fxEmit.Color = ColorSequence.new(c) end
    end)
    _addOpt(sec, "AddSlider", "FXRate", {Title="Интенсивность", Min=20, Max=900, Default=250, Rounding=1}, function(v)
        fxRate = tonumber(v) or 250
        if fxEmit then style() end
    end)
end

-- ============================================================
-- 9. MURDER DEATH EFFECT
-- ============================================================
do
    local mOn, mCloneOn, mPartOn, mEmitOn = false, false, false, false
    local mCloneCol = Color3.fromRGB(255, 0, 0)
    local mPartCol = Color3.fromRGB(255, 0, 0)
    local mEmitCol = Color3.fromRGB(255, 100, 100)
    local mCloneDur, mEmitDur = 3, 1.2
    local mClones, mConns, mRoles = {}, {}, {}
    local mThread, mAddConn

    local function makeClone(char)
        local ok, clone = pcall(function() return char:Clone() end)
        if not ok or not clone then return end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanQuery = false
                if d.Name == "HumanoidRootPart" then d.Transparency = 1
                else
                    d.Material = Enum.Material.ForceField
                    d.Color = mCloneCol
                end
            elseif d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript") then
                pcall(function() d:Destroy() end)
            end
        end
        clone.Name = "FH_MurderClone"
        clone.Parent = Workspace
        mClones[#mClones+1] = clone
        task.delay(mCloneDur, function()
            if not clone.Parent then return end
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    TweenService:Create(d, TweenInfo.new(1.5), {Transparency=1}):Play()
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
    end

    local function hookPlayer(pl)
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            mConns[#mConns+1] = hum.Died:Connect(function()
                if mOn and mRoles[pl.Name] == "Murderer" then onMurderDeath(char) end
            end)
        end
        if pl.Character then task.spawn(onChar, pl.Character) end
        mConns[#mConns+1] = pl.CharacterAdded:Connect(onChar)
    end
    local function stop()
        for _, c in ipairs(mConns) do pcall(function() c:Disconnect() end) end
        mConns = {}
        if mAddConn then pcall(function() mAddConn:Disconnect() end); mAddConn = nil end
        for _, c in ipairs(mClones) do pcall(function() c:Destroy() end) end
        mClones = {}
    end

    local sec = Tabs.Effects:AddSection({Name="Смерть убийцы"})
    _addOpt(sec, "AddToggle", "MEOn", {Title="Включить", Default=false}, function(v)
        mOn = v
        if v then
            mThread = task.spawn(function()
                while mOn do
                    pcall(function()
                        local d = getRoundData()
                        if type(d) == "table" then
                            local m = {}
                            for name, info in pairs(d) do
                                if type(info) == "table" and info.Role then m[name] = info.Role end
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
            stop()
            if mThread then pcall(function() task.cancel(mThread) end); mThread = nil end
        end
    end)
    _addOpt(sec, "AddToggle", "MEClone", {Title="Клон", Default=false}, function(v) mCloneOn = v end)
    _addOpt(sec, "AddColorPicker", "MECloneCol", {Title="Цвет клона", Default=Color3.fromRGB(255,0,0)}, function(c) mCloneCol = c end)
    _addOpt(sec, "AddSlider", "MECloneDur", {Title="Длительность клона", Min=1, Max=5, Default=3, Rounding=1}, function(v) mCloneDur = tonumber(v) or 3 end)
end

-- ============================================================
-- 10. FARM V3 (единственный фарм)
-- ============================================================
do
    local tF = Tabs.Farm
    local sec = tF:AddSection({Name="Автофарм"})
    local active, mode, speed, avoid = false, "Basic", 23, false
    local fullAction = "Respawn"
    local ncCache = {}
    local farmTarget
    local coinsDone, sawCoins = false, false
    local wasDown, downRefY = false, nil
    local lastTouch = 0
    local DOWN_DEPTH, DOWN_RISE_XZ, AVOID_DIST, RISE_SAFE_DIST = 14, 4, 40, 20

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
        return v and v.Parent and v:IsA("BasePart") and not v:GetAttribute("Collected") and not v:GetAttribute("Delete")
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
        if dist > 0.1 then np = my.Position + dir.Unit * math.min(speed * dt, dist) end
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
        if fullAction == "Respawn" then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health = 0 end) end
        end
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

    _addOpt(sec, "AddToggle", "FarmV3On", {Title="Включить автофарм", Default=false}, function(v)
        active = v
        if not v then farmRelease() end
        resetProgress()
    end)
    _addOpt(sec, "AddDropdown", "FarmV3Mode", {Title="Тип", Values={"Basic","Down"}, Default="Basic"}, function(v)
        mode = v or "Basic"
        farmTarget = nil
        if mode == "Basic" and wasDown then
            wasDown = false
            returnToSurface()
        end
    end)
    _addOpt(sec, "AddSlider", "FarmV3Speed", {Title="Скорость", Min=5, Max=60, Default=23, Rounding=1}, function(v) speed = tonumber(v) or 23 end)
    _addOpt(sec, "AddToggle", "FarmV3Avoid", {Title="Избегать маньяка", Default=false}, function(v) avoid = v; farmTarget = nil end)
    _addOpt(sec, "AddDropdown", "FarmFullAction", {Title="При полном мешке", Values={"Respawn","Auto"}, Default="Respawn"}, function(v)
        fullAction = v or "Respawn"
    end)
end

-- ============================================================
-- 11. UTILITY — уведомления, невидимость, анти, буст голосов
-- ============================================================
do
    local tU = Tabs.Utility
    local notifySec = tU:AddSection({Name="Уведомления"})
    local notifyOn, rolesOn, lastRole = false, false, nil
    task.spawn(function()
        while task.wait(0.5) do
            if notifyOn and rolesOn then
                local d = getRoundData()
                local r = d and d[LocalPlayer.Name] and d[LocalPlayer.Name].Role
                if r and r ~= lastRole then
                    lastRole = r
                    local ru = (r == "Sheriff" and "Шериф")
                        or (r == "Hero" and "Герой")
                        or (r == "Murderer" and "Маньяк")
                        or (r == "Innocent" and "Мирный") or r
                    Notify("FH", "Роль: " .. ru, 4)
                elseif not r then lastRole = nil end
            end
        end
    end)
    _addOpt(notifySec, "AddToggle", "NotifyOn", {Title="Включить", Default=false}, function(v) notifyOn = v end)
    _addOpt(notifySec, "AddToggle", "NotifyRoles", {Title="Показывать роль", Default=false}, function(v) rolesOn = v end)

    -- НЕВИДИМОСТЬ
    local invisSec = tU:AddSection({Name="Невидимость"})
    local invis = {active=false, realCF=nil, hbConn=nil, bindName="FH_InvisClient", savedLTM={}, savedDecals={}, savedFallen=nil}
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
    _addOpt(invisSec, "AddToggle", "InvisOn", {Title="Включить", Default=false}, function(v)
        if v then invisBegin() else invisEnd() end
    end)

    -- АНТИ
    local antiSec = tU:AddSection({Name="Анти"})
    local antiFlingOn = false
    local flingCache, flingReg = {}, {}
    local function regFling(model)
        if not antiFlingOn or not model or flingReg[model] or model == LocalPlayer.Character then return end
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
        flingReg, flingCache = {}, {}
    end
    RunService.Stepped:Connect(function()
        if not antiFlingOn then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then regFling(p.Character) end
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
    _addOpt(antiSec, "AddToggle", "AntiFling", {Title="Анти-отброс", Default=false}, function(v)
        antiFlingOn = v
        if not v then restoreFling() end
    end)

    local antiVoidOn = false
    local voidOrig = Workspace.FallenPartsDestroyHeight
    RunService.Heartbeat:Connect(function()
        pcall(function()
            Workspace.FallenPartsDestroyHeight = antiVoidOn and -9e9 or voidOrig
        end)
    end)
    _addOpt(antiSec, "AddToggle", "AntiVoid", {Title="Анти-падение", Default=false}, function(v) antiVoidOn = v end)

    local antiTrapOn = false
    local trapSpeed, trapJump = 16, 50
    RunService.Heartbeat:Connect(function()
        if not antiTrapOn then return end
        local hum = getHum()
        if not hum then return end
        if hum.WalkSpeed > 1 then trapSpeed = hum.WalkSpeed end
        if hum.JumpPower > 1 then trapJump = hum.JumpPower end
        pcall(function()
            if hum.WalkSpeed <= 1 then hum.WalkSpeed = trapSpeed end
            if hum.JumpPower <= 1 then hum.JumpPower = trapJump end
        end)
    end)
    _addOpt(antiSec, "AddToggle", "AntiTrap", {Title="Анти-ловушка", Default=false}, function(v) antiTrapOn = v end)

    -- БУСТ ГОЛОСОВ
    local mvSec = tU:AddSection({Name="Буст голосов"})
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
    _addOpt(mvSec, "AddSlider", "MVDupeCap", {Title="Кол-во", Min=1, Max=15, Default=10, Rounding=0}, function(v)
        mvCap = tonumber(v) or 10
    end)
    mvSec:AddButton({Title="Буст голосов", Callback=function()
        dupeVote(math.clamp(math.floor(mvCap), 1, 15))
    end})
end

-- ============================================================
-- 12. TROLLING — TP-тул, фейк-смерть, телепорт
-- ============================================================
do
    local tT = Tabs.Troll
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
    local sec = tT:AddSection({Name="Инструменты"})
    _addOpt(sec, "AddToggle", "ToolTP", {Title="ТП-тул", Default=false}, function(v)
        tpOn = v
        if v then giveTpTool() else removeTpTool() end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if tpOn then giveTpTool() end
    end)

    -- Фейк-смерть
    local fdSec = tT:AddSection({Name="Фейк-смерть"})
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
    local tpBtn = tT:AddSection({Name="Телепорт"})
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
-- 13. TRADE HELPER
-- ============================================================
do
    local TH = getgenv().TH or {TradeValues={}, On=false, Loaded=false}
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
        local list = {
            "https://api.codetabs.com/v1/proxy?quest=" .. url,
            "https://corsproxy.io/?" .. url,
            url,
        }
        for _, u in ipairs(list) do
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
        local n = 0
        for block in html:gmatch("<div%s+class=stackable>(.-)</div>") do
            local valStr = block:match("Value:%s*([%d,]+)")
            if valStr then
                local num = tonumber((valStr:gsub(",", "")))
                local name = block:match("<b>([^<]+)</b>")
                if name and num then
                    addValue(name, num)
                    n = n + 1
                end
            end
        end
        return n
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
    _addOpt(sec, "AddToggle", "THOn", {Title="Trade Helper (MM2 Values)", Default=false}, function(v)
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
-- 14. VOTE DUPER (Advanced)
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
    _addOpt(sec, "AddToggle", "THVoteDuper", {Title="Vote Duper", Default=false}, function(v)
        enabled = v
        if v then start() else stop() end
    end)
    _addOpt(sec, "AddSlider", "THDupeDelay", {Title="Задержка на пэде", Min=0.1, Max=1.5, Default=0.38, Rounding=2}, function(v)
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
    _addOpt(sec, "AddDropdown", "THPadPick", {Title="Пэд", Values={"Pad 1","Pad 2","Pad 3"}, Default="Pad 1"}, function(v)
        for i, name in ipairs(padNames) do
            if name == v then selectedPad = padRefs[i]; return end
        end
    end)
    sec:AddButton({Title="Обновить список", Callback=refresh})
    refresh()
end

-- ============================================================
-- 15. WATER PROTECTION / FADE / ANTI-COIN
-- ============================================================
do
    -- Water Protection
    local offWater = false
    local modWater, disabledConns = {}, {}
    local function isWater(inst)
        if not inst then return false end
        local n = inst.Name:lower()
        return n:find("water") or n:find("river") or n:find("ocean")
    end
    local function neutralize(inst)
        if not inst or not inst:IsA("BasePart") then return end
        if modWater[inst] == nil then modWater[inst] = inst.CanTouch end
        inst.CanTouch = false
    end
    local function applyAll()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local p = d
                while p and p ~= Workspace do
                    if isWater(p) then neutralize(d); break end
                    p = p.Parent
                end
            end
        end
    end
    local function restoreAll()
        for part, ct in pairs(modWater) do
            if part and part.Parent then pcall(function() part.CanTouch = ct end) end
        end
        modWater = {}
    end

    -- Fade Disabler
    local fadeNames = {CameraFade=true, Fade=true, SpawnFade=true, DeathFade=true}
    local fadeTracked, fadeConn = {}, nil
    local savedFadeFolder = ReplicatedStorage:FindFirstChild("FH_SavedFadeGuis")
    if not savedFadeFolder then
        savedFadeFolder = Instance.new("Folder")
        savedFadeFolder.Name = "FH_SavedFadeGuis"
        savedFadeFolder.Parent = ReplicatedStorage
    end
    local function fadeHandle(obj)
        if not obj or not obj:IsDescendantOf(game) then return end
        if obj:IsDescendantOf(savedFadeFolder) then return end
        if fadeNames[obj.Name] then
            if not fadeTracked[obj] then fadeTracked[obj] = obj.Parent end
            obj.Parent = savedFadeFolder
        end
    end
    local function fadeApply()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, d in ipairs(pg:GetDescendants()) do fadeHandle(d) end
        if not fadeConn then fadeConn = pg.DescendantAdded:Connect(fadeHandle) end
    end
    local function fadeRestore()
        if fadeConn then fadeConn:Disconnect(); fadeConn = nil end
        for obj, parent in pairs(fadeTracked) do
            if obj and obj.Parent == savedFadeFolder then
                if parent and parent:IsDescendantOf(game) then obj.Parent = parent
                else
                    local pg = LocalPlayer:FindFirstChild("PlayerGui")
                    if pg then obj.Parent = pg end
                end
            end
        end
        fadeTracked = {}
    end

    -- Anti-Coin
    local antiCoinOn = false
    local coinSaved = {}
    local function hideCoin(part)
        if not coinSaved[part] then
            coinSaved[part] = {CanTouch=part.CanTouch, CanCollide=part.CanCollide, Transparency=part.Transparency}
        end
        part.CanTouch = false
        part.CanCollide = false
        part.Transparency = 1
    end
    local function coinScan()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") and d:GetAttribute("CoinVisual") then hideCoin(d) end
        end
        for _, v in ipairs(CollectionService:GetTagged("CoinVisual")) do
            if v:IsA("BasePart") then hideCoin(v) end
        end
    end
    local function coinRestore()
        for part, o in pairs(coinSaved) do
            if part and part.Parent then
                pcall(function()
                    part.CanTouch = o.CanTouch
                    part.CanCollide = o.CanCollide
                    part.Transparency = o.Transparency
                end)
            end
        end
        coinSaved = {}
    end

    local sec = Tabs.Utility:AddSection({Name="Прочее"})
    _addOpt(sec, "AddToggle", "WaterProtOn", {Title="Off Damage Water", Default=false}, function(v)
        offWater = v
        if v then applyAll() else restoreAll() end
    end)
    _addOpt(sec, "AddToggle", "FadeDisablerOn", {Title="Убрать чёрный экран", Default=false}, function(v)
        if v then fadeApply() else fadeRestore() end
    end)
    _addOpt(sec, "AddToggle", "AntiCoinOn", {Title="Скрыть монеты", Default=false}, function(v)
        antiCoinOn = v
        if v then
            task.spawn(function()
                while antiCoinOn do pcall(coinScan); task.wait(0.5) end
            end)
        else coinRestore() end
    end)
end

-- ============================================================
-- 16. BEAM EFFECTS
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
    _addOpt(sec, "AddDropdown", "FHBeamType", {
        Title="Тип луча",
        Values={"Default","Neon Fat","Nuke","Rainbow RGB"},
        Default="Default",
    }, function(v) BeamCfg.Type = v or "Default" end)
    _addOpt(sec, "AddColorPicker", "FHBeamColor", {Title="Цвет", Default=Color3.fromRGB(0,240,255)}, function(c)
        BeamCfg.Color = c
    end)
end

-- ============================================================
-- 17. AURA 2.0 — расширение первой части (доп. ауры через GetObjects)
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
-- 18. ANTI-AIM
-- ============================================================
do
    local enabled = false
    local token = 0
    local savedCollide, stepConn, dieConn = {}, nil, nil
    local function getRoot(char)
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.RootPart then return hum.RootPart end
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("UpperTorso")
    end
    local function stop()
        enabled = false
        token = token + 1
        if stepConn then pcall(function() stepConn:Disconnect() end); stepConn = nil end
        if dieConn then pcall(function() dieConn:Disconnect() end); dieConn = nil end
        local char = LocalPlayer.Character
        if char then
            for part, ct in pairs(savedCollide) do
                if part and part.Parent then pcall(function() part.CanCollide = ct end) end
            end
            local root = getRoot(char)
            if root and root.Parent then
                pcall(function()
                    root.Velocity = Vector3.zero
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        savedCollide = {}
    end
    local function start()
        stop()
        enabled = true
        token = token + 1
        local myToken = token
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            dieConn = hum.Died:Connect(function()
                if token == myToken then
                    stop()
                    pcall(function()
                        local o = Options.FHAntiAimOn
                        if o then o:SetValue(false) end
                    end)
                end
            end)
        end
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
    _addOpt(sec, "AddToggle", "FHAntiAimOn", {Title="Анти-аим", Default=false}, function(v)
        if v then start() else stop() end
    end)
end

-- ============================================================
-- 19. PLAYER LIST PANEL
-- ============================================================
do
    local panelGui = Instance.new("ScreenGui")
    panelGui.Name = "FH_PlayerListPanel"
    panelGui.ResetOnSpawn = false
    panelGui.IgnoreGuiInset = true
    panelGui.DisplayOrder = 450
    panelGui.Enabled = false
    pcall(function() panelGui.Parent = (gethui and gethui()) or CoreGui end)
    if not panelGui.Parent then panelGui.Parent = CoreGui end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(440, 380)
    frame.Position = UDim2.new(0.5, -220, 0.5, -190)
    frame.BackgroundColor3 = Color3.fromRGB(16, 12, 9)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = panelGui
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
    closeBtn.MouseButton1Click:Connect(function() panelGui.Enabled = false end)

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

    local selected = nil
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
                        selected = pl
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
    _addOpt(sec, "AddToggle", "FHPlayerPanelOn", {Title="Открыть", Default=false}, function(v)
        panelGui.Enabled = v
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
-- 20. LANGUAGE SYSTEM
-- ============================================================
do
    local cur = "EN"
    getgenv().FH_CurrentLang = cur
    local sec = Tabs.Settings:AddSection({Name="Language"})
    _addOpt(sec, "AddDropdown", "FH_Lang", {Title="Язык интерфейса", Values={"EN","RU"}, Default="EN"}, function(v)
        cur = v or "EN"
        getgenv().FH_CurrentLang = cur
        Notify("FH", "Язык: " .. cur, 2)
    end)
end

-- ============================================================
-- 21. JUMP CIRCLE
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
    _addOpt(sec, "AddToggle", "FH_JumpCircleOn", {Title="Круг при прыжке", Default=false}, function(v)
        settings.enabled = v
        if v and LocalPlayer.Character then bind(LocalPlayer.Character) end
    end)
    _addOpt(sec, "AddColorPicker", "FH_JumpCircleCol", {Title="Цвет", Default=Color3.fromRGB(255,105,180)}, function(c)
        settings.color = c
    end)
end

-- ============================================================
-- 22. RTX SHADER
-- ============================================================
do
    local rtxOn = false
    local saved, savedChildren, addedFx, vignette = {}, {}, {}, nil
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
    _addOpt(sec, "AddToggle", "FH_RTXOn", {Title="Включить RTX", Default=false}, function(v)
        if v then enable() else disable() end
    end)
end

-- ============================================================
-- ФИНАЛ PART 2/2
-- ============================================================
pcall(function() Window:SelectTab(1) end)
print("[FH] ============================================")
print("[FH] Part 2/2 — FortniHub v" .. VERSION .. " — " .. CREDITS)
print("[FH] Silent Aim, KillAura, AutoGrab, Movement, ESP, Tracer, WorldFX")
print("[FH] MurderFX, FarmV3, Utility, Troll, TradeHelper, VoteDuper")
print("[FH] WaterProt, FadeDisabler, AntiCoin, BeamEffects, Aura 2.0 (доп)")
print("[FH] Anti-Aim, PlayerPanel, Language, JumpCircle, RTX")
print("[FH] Удалено: GameSounds, Watermark, Custom Gun Models, Advanced AutoFarm")
print("[FH] ============================================")
