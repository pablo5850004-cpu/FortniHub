-- ============================================================
-- main.lua — FortniHub MM2 v20.1 FIXED — ЧАСТЬ 1/3
-- Исправления: backtrack, ghost→bt v2, fling predict, watermark/weapon removed
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui           = game:GetService("CoreGui")
local Workspace         = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")
local Stats             = game:GetService("Stats")
local CollectionService = game:GetService("CollectionService")
local SoundService      = game:GetService("SoundService")
local Debris            = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local VERSION = "20.1.1 FIXED"
local CREDITS = "by HOTI and Ve315 (fixed)"

local S = { frozen = false, freezeUpKey = Enum.KeyCode.Space, freezeDownKey = Enum.KeyCode.LeftAlt }
local silent = { enabled = false, predict = true, force = false, standoff = 15, lastShot = 0 }
local knifeSilent = { enabled = false, radius = 20, fov = 120, showFov = true, checkWalls = false, instaKill = true, predict = true }
local kaV1 = { on = false, dist = 30, lastHit = 0 }
local kaV2 = { on = false, dist = 30, lastHit = 0 }
local killAuraVersion = "v2"
local Connections = {}

local function AddConn(name, conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name] = conn
end

local Cache = { hrp = nil, hum = nil, cacheTime = 0 }
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
            if d.Role == "Sheriff"  then return "sheriff"  end
            if d.Role == "Hero"     then return "hero"     end
            return "innocent"
        end
    end
    local c = p.Character
    if c then
        local bp = p:FindFirstChild("Backpack")
        if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then return "murderer" end
        if c:FindFirstChild("Gun")   or (bp and bp:FindFirstChild("Gun"))   then
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

local function isMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRoleFromData(p) == "murderer" then return p end
    end
    return nil
end

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

local OnChangedRegistry = {}
getgenv().FH_OnChangedRegistry = OnChangedRegistry
local function registerOnChanged(name, cb) OnChangedRegistry[name] = cb end
local function fireRegistered(name, value)
    local cb = OnChangedRegistry[name]
    if cb then pcall(cb, value) end
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
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/src/init.lua",
        "https://cdn.jsdelivr.net/gh/dawid-scripts/Fluent@main/src/init.lua",
        "https://raw.githack.com/dawid-scripts/Fluent/main/src/init.lua",
    }
    local body
    for _, u in ipairs(urls) do
        local ok, b = pcall(function() return game:HttpGet(u, true) end)
        if ok and type(b) == "string" and #b > 1000 and not b:find("<html") then
            body = b; break
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

local Window, Options = nil, nil
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
Tabs.Combat     = Window:AddTab({ Title = "Бой" })
Tabs.Movement   = Window:AddTab({ Title = "Движение" })
Tabs.Binds      = Window:AddTab({ Title = "Бинды" })
Tabs.Visual     = Window:AddTab({ Title = "Визуал" })
Tabs.Effects    = Window:AddTab({ Title = "Эффекты" })
Tabs.Farm       = Window:AddTab({ Title = "Фарм" })
Tabs.Animations = Window:AddTab({ Title = "Эмоции" })
Tabs.Utility    = Window:AddTab({ Title = "Утилиты" })
Tabs.Troll      = Window:AddTab({ Title = "Троллинг" })
Tabs.Settings   = Window:AddTab({ Title = "Настройки" })

local function addOpt(container, method, name, opts, callback)
    local opt = container[method](container, name, opts)
    if opt and callback then
        opt:OnChanged(callback)
        registerOnChanged(name, callback)
    end
    return opt
end

local lastNotify = {}
local function Notify(title, content, dur)
    local k = tostring(title) .. "|" .. tostring(content)
    if lastNotify[k] and (tick() - lastNotify[k]) < 0.5 then return end
    lastNotify[k] = tick()
    pcall(function()
        Fluent:Notify({ Title = title, Content = content, Duration = dur or 3 })
    end)
end
getgenv().FH_Notify = Notify

task.spawn(function()
    task.wait(0.8)
    Notify("FortniHub", "Скрипт создан HOTI и Ve315 (fixed).", 7)
    task.wait(1.2)
    Notify("FortniHub", "BETA — возможны баги.", 7)
end)

-- ============================================================
-- HUD (без watermark)
-- ============================================================
local HUDGui, FPSLabel, PingLabel, Pill
do
    pcall(function()
        for _, name in ipairs({"FH_HUD_v18","FH_HUD","FH_HUD_v182","FH_HUD_v1821","FH_HUD_v183","FH_HUD_v184","FH_HUD_v185","FH_HUD_v186","FH_HUD_v19","FH_HUD_v20","FH_Watermark_v21"}) do
            local old = CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
    HUDGui = Instance.new("ScreenGui")
    HUDGui.Name = "FH_HUD_v21"
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
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 60)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 30, 60)),
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
            dragging = true; dragMoved = false
            dragStart = i.Position; posStart = Pill.Position
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
            local c = cur < 30 and Color3.fromRGB(255, 80, 80) or (cur < 60 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 240, 120))
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
            local c = p < 60 and Color3.fromRGB(80, 240, 120) or (p < 120 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 80, 80))
            PingLabel.Text = tostring(p)
            PingLabel.TextColor3 = c
        end
    end))
end

-- ============================================================
-- BACKTRACK 1 (fixed) + BACKTRACK 2 (former Client Ghost, merged)
-- Оба варианта в одной секции "Бэктрек"
-- ============================================================
do
    local btFolder = Workspace:FindFirstChild("FH_BacktrackFolder")
    if not btFolder then
        btFolder = Instance.new("Folder")
        btFolder.Name = "FH_BacktrackFolder"
        btFolder.Parent = Workspace
    end

    -- ====== BACKTRACK V1 (классический — ForceField-клон сзади) ======
    local bt1 = {
        on = false,
        col = Color3.fromRGB(255, 60, 60),
        model = nil,
        pairs = {},
        hist = {},
        histCap = 256,
        ping = 0.15,
        pingAt = 0,
    }
    for i = 1, bt1.histCap do
        bt1.hist[i] = { 0, CFrame.new() }
    end
    local btFirst, btCount = 1, 0

    local function bt1Kill()
        if bt1.model then pcall(function() bt1.model:Destroy() end); bt1.model = nil end
        bt1.pairs = {}
        btFirst, btCount = 1, 0
    end

    local function bt1Build()
        bt1Kill()
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
            if o:IsA("Script") or o:IsA("LocalScript") or o:IsA("ModuleScript") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") or o:IsA("SpotLight") or o:IsA("SurfaceLight") or o:IsA("Highlight") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("BasePart") then
                o.Anchored = true
                o.CanCollide = false
                o.CanQuery = false
                o.CanTouch = false
                o.CastShadow = false
                if o.Name == "HumanoidRootPart" then
                    o.Transparency = 1
                else
                    o.Material = Enum.Material.ForceField
                    o.Color = bt1.col
                    o.Transparency = 0
                end
                ci = ci + 1
                bt1.pairs[#bt1.pairs + 1] = { o, rp[ci] }
            end
        end
        local h = m:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:Destroy() end) end
        m.Parent = btFolder
        bt1.model = m
    end

    local function bt1Update()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not bt1.model then
            bt1Build()
            if not bt1.model then return end
        end
        if not bt1.model.Parent then bt1.model.Parent = btFolder end
        local now = os.clock()
        local cf = hrp.CFrame
        if btCount < bt1.histCap then
            btCount = btCount + 1
        else
            btFirst = btFirst % bt1.histCap + 1
        end
        local slot = bt1.hist[(btFirst + btCount - 2) % bt1.histCap + 1]
        slot[1], slot[2] = now, cf
        if now - bt1.pingAt >= 0.2 then
            bt1.pingAt = now
            local ok, v = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            end)
            bt1.ping = math.clamp((ok and v) or 0.15, 0.05, 0.6)
        end
        local target = now - bt1.ping
        local tcf = cf
        for k = btCount, 1, -1 do
            local s = bt1.hist[(btFirst + k - 2) % bt1.histCap + 1]
            if s[1] <= target then
                tcf = s[2]; break
            end
        end
        local inv = hrp.CFrame:Inverse()
        for i = 1, #bt1.pairs do
            local cp, rp = bt1.pairs[i][1], bt1.pairs[i][2]
            if cp and cp.Parent and rp and rp.Parent then
                cp.CFrame = tcf * (inv * rp.CFrame)
            end
        end
    end

    -- ====== BACKTRACK V2 (ex-Client Ghost) ======
    local bt2 = {
        on = false,
        transparency = 50,
        color = Color3.fromRGB(255, 100, 100),
        noTexture = false,
        btTime = 0.15,
        model = nil,
        pairs = {},
        hist = {},
        lastChar = nil,
    }
    local function bt2Paint()
        if not bt2.model then return end
        local tr = bt2.transparency / 100
        pcall(function()
            local bc = bt2.model:FindFirstChildOfClass("BodyColors")
            if bc then bc:Destroy() end
        end)
        for _, pair in ipairs(bt2.pairs) do
            local g = pair.ghost
            pcall(function()
                if g:IsA("BasePart") then
                    g.Transparency = tr
                    g.Color = bt2.color
                    if bt2.noTexture then
                        g.Material = Enum.Material.SmoothPlastic
                        if g:IsA("MeshPart") then g.TextureID = "" end
                    end
                end
            end)
        end
    end
    local function bt2Cleanup()
        if bt2.model then pcall(function() bt2.model:Destroy() end) end
        bt2.model = nil
        bt2.pairs = {}
        bt2.hist = {}
        bt2.lastChar = nil
    end
    local function bt2Build(char)
        bt2Cleanup()
        bt2.lastChar = char
        char.Archivable = true
        local ok, clone = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not clone then return end
        bt2.model = clone
        bt2.model.Name = "FH_BT2Ghost"
        bt2.model.Parent = btFolder
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
        local hrp = clone:FindFirstChild("HumanoidRootPart")
        if hrp then hrp:Destroy() end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanQuery = false
                d.CanTouch = false
                d.Massless = true
            end
        end
        bt2.pairs = {}
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                local g = nil
                if d.Parent == char then
                    g = clone:FindFirstChild(d.Name)
                elseif d.Parent and d.Parent:IsA("Accessory") then
                    local acc = clone:FindFirstChild(d.Parent.Name)
                    if acc then g = acc:FindFirstChild(d.Name) end
                end
                if g and g:IsA("BasePart") then
                    table.insert(bt2.pairs, { real = d, ghost = g })
                end
            end
        end
        bt2Paint()
    end
    RunService.RenderStepped:Connect(function()
        if not bt2.on then
            if bt2.model then bt2Cleanup() end
            return
        end
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            if bt2.model then bt2Cleanup() end
            return
        end
        if bt2.lastChar ~= char then bt2Build(char) end
        if not bt2.model or bt2.model.Parent ~= btFolder then return end
        local snap = { t = tick(), parts = {} }
        for _, pair in ipairs(bt2.pairs) do
            snap.parts[pair.real] = pair.real.CFrame
        end
        table.insert(bt2.hist, snap)
        local cutoff = tick() - 2
        while #bt2.hist > 0 and bt2.hist[1].t < cutoff do
            table.remove(bt2.hist, 1)
        end
        local ping = 0
        pcall(function()
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        local wantTime = tick() - math.clamp(bt2.btTime or (ping / 1000), 0.02, 0.8)
        local chosen = nil
        for i = #bt2.hist, 1, -1 do
            if bt2.hist[i].t <= wantTime then chosen = bt2.hist[i]; break end
        end
        if not chosen and #bt2.hist > 0 then chosen = bt2.hist[1] end
        if chosen then
            for _, pair in ipairs(bt2.pairs) do
                if chosen.parts[pair.real] then
                    pair.ghost.CFrame = chosen.parts[pair.real]
                end
            end
        end
    end)

    -- ====== UI ======
    local btSec = Tabs.Visual:AddSection({ Name = "Бэктрек" })
    addOpt(btSec, "AddToggle", "BacktrackOn", { Title = "Backtrack v1 (классический)", Default = false }, function(v)
        bt1.on = v
        if v then
            if not bt1.model then bt1Build() end
        else
            bt1Kill()
        end
    end)
    addOpt(btSec, "AddColorPicker", "BacktrackCol", { Title = "Цвет v1", Default = Color3.fromRGB(255, 60, 60) }, function(c)
        bt1.col = c
        if bt1.model then
            for _, p in ipairs(bt1.model:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Color = c end
            end
        end
    end)
    addOpt(btSec, "AddToggle", "FHGhostOn", { Title = "Backtrack v2 (ghost client)", Default = false }, function(v)
        bt2.on = v
        if not v then bt2Cleanup() end
    end)
    addOpt(btSec, "AddSlider", "FHGhostTransparency", { Title = "v2 — Прозрачность (%)", Min = 0, Max = 100, Default = 50, Rounding = 0 }, function(v)
        bt2.transparency = tonumber(v) or 50
        bt2Paint()
    end)
    addOpt(btSec, "AddColorPicker", "FHGhostColor", { Title = "v2 — Цвет", Default = Color3.fromRGB(255, 100, 100) }, function(c)
        bt2.color = c
        bt2Paint()
    end)
    addOpt(btSec, "AddToggle", "FHGhostNoTexture", { Title = "v2 — Убрать текстуры", Default = false }, function(v)
        bt2.noTexture = v
        bt2Paint()
    end)
    addOpt(btSec, "AddSlider", "FHGhostBacktrackTime", { Title = "v2 — Время бэктрека (сек)", Min = 0, Max = 0.8, Default = 0.15, Rounding = 2 }, function(v)
        bt2.btTime = tonumber(v) or 0.15
    end)
end

-- ============================================================
-- SILENT AIM (без изменений, кроме фикса origin)
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
        enabled = false, predict = true, force = false, auto_on = false, auto_delay = 0,
        am_sheriff = false, fire_gap = 0, last_shot = 0, stand_off = 15,
    }
    local SS = getgenv().SILENT_S
    local silent_section = Tabs.Combat:AddSection({ Name = "Тихий выстрел" })

    local gap_min, gap_seen, gap_gun, want_since = 0, false, nil, 0
    local function gap_reset() gap_min = 0; gap_seen = false; SS.fire_gap = 0 end
    local function gap_push(value)
        if value <= 0 then return end
        if not gap_seen or value < gap_min then
            gap_min = value; gap_seen = true; SS.fire_gap = value
        end
    end

    local round_mod = nil
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

    local target_player, target_char, target_part, target_hum = nil, nil, nil, nil
    local function refresh_target()
        local found = nil
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
                    found = plr; break
                end
            end
        end
        if found ~= target_player then
            target_player = found; target_char = nil; target_part = nil; target_hum = nil
        end
        if not found then return end
        local char = found.Character
        if char ~= target_char then
            target_char = char; target_part = nil; target_hum = nil
        end
        if not char then return end
        if not target_part or not target_part.Parent then
            target_part = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
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
    local ignore_base, ignore_work, ignore_time = {}, {}, 0
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
        local result = nil
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
        return nil
    end
    local function grav()
        local ok, g = pcall(function() return workspace.Gravity end)
        if ok and type(g) == "number" and g > 0 then return g end
        return 0
    end

    -- === prediction ===
    local snap_t, snap_p, snap_n, snap_i = table.create(48, 0), table.create(48, Vector3.zero), 0, 0
    local TR = { part=nil, pos=nil, time=0, vel=Vector3.zero, gap=0, ready=false,
                 fresh=Vector3.zero, air=false, air_since=0, jumping=false, jump_v=0,
                 fresh_ok=false, turn=0, spoof=0, clr=0, air_edge=0, jump_fresh=false }
    local EC = { ping=0, rtt=0, jitter=0, seen=false, step=0, step_seen=false }

    local function step_push(dt)
        if dt <= 0 or dt > 0.5 then return end
        if EC.step_seen then EC.step = EC.step * 0.85 + dt * 0.15
        else EC.step = dt; EC.step_seen = true end
    end
    local function sample_span()
        local span = math.max(EC.step, TR.gap)
        return span > 0 and span or 0
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
        local used = 0
        local sum_d = 0
        local win = sample_span() * 4
        for k = 0, snap_n - 1 do
            local t = snap_get(k)
            if newest - t > win then break end
            used = used + 1
            sum_d = sum_d + t - newest
        end
        if used < 3 then return nil end
        local mean_d = sum_d / used
        local num = Vector3.zero
        local den = 0
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
        local fallback, fallback_age = nil, nil
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

    local function raw_rtt()
        local a, b
        local ok, ms = pcall(function()
            return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and type(ms) == "number" and ms == ms and ms > 4 and ms < 800 then a = ms / 1000 end
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
            EC.jitter = EC.jitter * 0.9 + math.abs(rtt - EC.rtt) * 0.1
            EC.rtt = EC.rtt * 0.82 + rtt * 0.18
        else
            EC.rtt = rtt; EC.jitter = 0; EC.seen = true
        end
        EC.ping = EC.rtt
    end
    local function lead_time()
        if not EC.seen then return 0 end
        local stale = 0
        if TR.time > 0 and EC.step_seen then
            stale = math.clamp(os.clock() - TR.time, 0, EC.step)
        end
        return math.clamp(EC.rtt + EC.jitter * 0.5 + stale, 0, 1)
    end
    local function predict_from(base, sa, sb, fh, now)
        local span = math.max(0, sa + sb)
        local g = grav()
        local dir = fh
        if dir.Magnitude == 0 then dir = Vector3.new(TR.vel.X, 0, TR.vel.Z) end
        local x, z
        if span > 0 then
            x = base.X + dir.X * span
            z = base.Z + dir.Z * span
        else
            x, z = base.X, base.Z
        end
        local y = base.Y
        if TR.air and span > 0 then
            local vy = TR.vel.Y
            y = base.Y + vy * span - 0.5 * g * span * span
        end
        return Vector3.new(x, y, z)
    end
    local function track_clear()
        TR.part = nil; TR.pos = nil; TR.vel = Vector3.zero; TR.gap = 0
        TR.ready = false; TR.fresh = Vector3.zero; TR.air = false
        TR.jumping = false; TR.jump_v = 0; TR.fresh_ok = false
        TR.turn = 0; TR.spoof = 0; TR.clr = 0; TR.air_edge = 0; TR.jump_fresh = false
        snap_n, snap_i = 0, 0
    end
    local function track(now)
        local part = target_part
        if not part or not part.Parent then
            if TR.part then track_clear() end
            return
        end
        local pos = part.Position
        if part ~= TR.part or not TR.pos then
            TR.part = part; TR.pos = pos; TR.time = now
            TR.vel = Vector3.zero; TR.fresh = Vector3.zero; TR.ready = false
            snap_n, snap_i = 0, 0
            snap_push(now, pos)
            return
        end
        local dt = now - TR.time
        if dt > 0.75 or (pos - TR.pos).Magnitude > 140 then
            TR.pos = pos; TR.time = now; snap_n, snap_i = 0, 0
            snap_push(now, pos)
            return
        end
        if dt <= 0 then return end
        if (pos - TR.pos).Magnitude == 0 then return end
        step_push(dt)
        TR.gap = dt
        snap_push(now, pos)
        TR.pos = pos
        TR.time = now
        local fit = fit_velocity()
        local fast = recent_velocity()
        TR.vel = fast or fit or Vector3.zero
        TR.ready = fit ~= nil or fast ~= nil
        TR.fresh = TR.vel
        TR.fresh_ok = TR.ready
    end

    local function lead_offset()
        local part = target_part
        if not part or not part.Parent then return Vector3.zero end
        if not SS.predict or not TR.ready or SS.force then return Vector3.zero end
        local base = part.Position
        local now = os.clock()
        local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
        local point = predict_from(base, 0, lead_time(), fh, now)
        return point - base
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
    local function pick_point(origin, strict)
        refresh_parts()
        if hit_count == 0 then return nil end
        local off = lead_offset()
        local first = nil
        for k = 1, hit_count do
            local part = hit_parts[k]
            if not part.Parent then
                hit_char = nil
            else
                local point = part.Position + off
                if not origin then return point end
                if not first then first = point end
                if los_clear(origin, point) then return point end
            end
        end
        if strict then return nil end
        return first
    end

    local force_att, force_saved, force_stamp = nil, nil, 0
    local function restore_origin()
        local att = force_att
        if not att then return end
        local saved = force_saved
        force_att, force_saved = nil, nil
        if saved then
            pcall(function() if att.Parent then att.CFrame = saved end end)
        end
    end
    local function push_origin(cf)
        local att = gun_attachment()
        if not att then return false end
        if force_att and force_att ~= att then restore_origin() end
        if not force_att then
            local ok, saved = pcall(function() return att.CFrame end)
            if not ok or typeof(saved) ~= "CFrame" then return false end
            force_att, force_saved = att, saved
        end
        force_stamp = os.clock()
        local ok = pcall(function() att.WorldCFrame = cf end)
        if not ok then restore_origin(); return false end
        task.defer(restore_origin)
        return true
    end

    local function resolve_force()
        local part = target_part
        if not part or not part.Parent then return nil end
        local live = part.Position
        local vel = TR.fresh
        local dir = vel.Magnitude > 3 and vel.Unit or Vector3.new(0, -1, 0)
        local back = live - dir * 8
        local front = live + dir * 8
        return CFrame.new(back, front), CFrame.new(front)
    end
    local function resolve_shot()
        if not SS.enabled or not SS.am_sheriff or not target_alive() then return nil end
        if SS.force then
            local o, a = resolve_force()
            if o and a then
                if push_origin(o) then return a end
            end
        end
        local cf = origin_cframe()
        local aim = pick_point(cf and cf.Position or nil, false)
        if not aim then return nil end
        return CFrame.new(aim)
    end

    local weapon_service, orig_mouse, orig_screen, hook_mouse, hook_screen = nil, nil, nil, nil, nil
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
                local ok, cf = pcall(resolve_shot)
                if ok and cf then return cf end
                return orig_mouse(self, ...)
            end
            hook_screen = function(self, x, y, ...)
                sample_ping()
                local ok, cf = pcall(resolve_shot)
                if ok and cf then return cf end
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
    local function fire_gun(gun, start_cf, aim_cf)
        if not gun or not start_cf or not aim_cf then return false end
        local remote = gun:FindFirstChild("Shoot")
        if not remote or not remote:IsA("RemoteEvent") then return false end
        return pcall(function() remote:FireServer(start_cf, aim_cf) end)
    end

    local function auto_step(now)
        if not SS.auto_on or not SS.enabled or not SS.am_sheriff or not target_alive() then
            want_since = 0; return
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
        local aim = pick_point(cf.Position, true)
        if not aim then return end
        local aim_cf = CFrame.new(aim)
        if fire_gun(gun, cf, aim_cf) then SS.last_shot = now end
    end

    local watch_conns = {}
    local function clear_watch()
        for k = 1, #watch_conns do pcall(function() watch_conns[k]:Disconnect() end) end
        table.clear(watch_conns)
    end
    local function setup_watch()
        clear_watch()
        local m = get_round()
        if m and m.PlayerDataChanged then
            watch_conns[#watch_conns + 1] = m.PlayerDataChanged.Event:Connect(function()
                pcall(refresh_target)
            end)
        end
        watch_conns[#watch_conns + 1] = lp.CharacterAdded:Connect(function()
            task.wait(0.3)
            pcall(refresh_target)
        end)
    end

    local next_role, next_hook = 0, 0
    local function tick_silent()
        if force_att and os.clock() - force_stamp > 0.05 then restore_origin() end
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
    end
    local main_conn = run.Heartbeat:Connect(function() pcall(tick_silent) end)

    addOpt(silent_section, "AddToggle", "SilentEnabled", { Title = "Включить", Default = false }, function(v)
        SS.enabled = v
        if v then
            task.spawn(function()
                pcall(install_hooks)
                pcall(connect_gun_fired)
                pcall(setup_watch)
                pcall(refresh_target)
            end)
        else
            clear_watch()
            track_clear()
        end
        Notify("FH", "Silent " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)
    addOpt(silent_section, "AddToggle", "SilentPredict", { Title = "Предсказание", Default = true }, function(v)
        SS.predict = v
        if not v then track_clear() end
    end)
    addOpt(silent_section, "AddToggle", "SilentForce", { Title = "Стрельба через стены", Default = false }, function(v)
        SS.force = v
        if v then
            SS.predict = false
            Notify("FH", "Force ВКЛ — предикт выключен", 3)
        else
            restore_origin()
        end
    end)
    addOpt(silent_section, "AddSlider", "SilentStandoff", { Title = "Отступ", Default = 15, Min = 0, Max = 40, Rounding = 0 }, function(v)
        SS.stand_off = tonumber(v) or 15
    end)
    addOpt(silent_section, "AddToggle", "SilentAuto", { Title = "Авто-выстрел", Default = false }, function(v) SS.auto_on = v end)
    addOpt(silent_section, "AddSlider", "SilentAutoDelay", { Title = "Задержка авто", Default = 0, Min = 0, Max = 600, Rounding = 0 }, function(v)
        SS.auto_delay = (tonumber(v) or 0) / 1000
    end)
end

-- ============================================================
-- KNIFE SILENT / KILL AURA / AUTOGUN (без изменений)
-- ============================================================
do
    local knifeSec = Tabs.Combat:AddSection({ Name = "Тихий бросок ножа" })
    addOpt(knifeSec, "AddToggle", "KnifeSilentOn", { Title = "Включить", Default = false }, function(v)
        knifeSilent.enabled = v
        if v then
            Notify("FH", "В разработке", 3)
            task.delay(0.5, function()
                local opt = Options.KnifeSilentOn
                if opt then pcall(function() opt:SetValue(false) end) end
            end)
        end
    end)
end

do
    local tC = Tabs.Combat
    local kaSec = tC:AddSection({ Name = "Килл Аура" })
    addOpt(kaSec, "AddDropdown", "KAVersion", { Title = "Версия", Values = { "v1", "v2" }, Default = "v2" }, function(v)
        killAuraVersion = v
        kaV1.on = false; kaV2.on = false
        if Options.KAOn and Options.KAOn.Value then
            kaV1.on = v == "v1"
            kaV2.on = v == "v2"
        end
    end)
    addOpt(kaSec, "AddToggle", "KAOn", { Title = "Включить", Default = false }, function(v)
        kaV1.on = v and killAuraVersion == "v1"
        kaV2.on = v and killAuraVersion == "v2"
    end)
    addOpt(kaSec, "AddSlider", "KADist", { Title = "Радиус", Min = 5, Max = 60, Default = 30, Rounding = 0 }, function(v)
        local n = tonumber(v) or 30
        kaV1.dist = n; kaV2.dist = n
    end)
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
            for _, v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            kaV1.lastHit = tick()
        end
    end))
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
            for _, v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            kaV2.lastHit = tick()
        end
    end))
end

do
    local tC = Tabs.Combat
    local grabFailedRound, isGrabbing = false, false
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
    local autoGrabEnabled = false
    addOpt(tC, "AddToggle", "AutoGrabGun", { Title = "Авто-подбор пистолета", Default = false }, function(v) autoGrabEnabled = v end)
    AddConn("AutoGrabTick", RunService.Heartbeat:Connect(function()
        if not autoGrabEnabled then return end
        if grabFailedRound or isGrabbing then return end
        if getRoleFromData(LocalPlayer) == "murderer" then return end
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
                if c and c:FindFirstChild("Gun") then grabbed = true; break end
                local b = LocalPlayer:FindFirstChildOfClass("Backpack")
                if b and b:FindFirstChild("Gun") then grabbed = true; break end
            end
            if my and my.Parent then
                my.CFrame = rp
                my.AssemblyLinearVelocity = Vector3.zero
                my.AssemblyAngularVelocity = Vector3.zero
            end
            if not grabbed then
                grabFailedRound = true
                Notify("FH", "Пистолет не подобран.", 4)
            end
            isGrabbing = false
        end)
    end))
    AddConn("AutoGrabReset", LocalPlayer.CharacterAdded:Connect(function() isGrabbing = false end))
end

-- ============================================================
-- ТРОЛЛИНГ: FLING (с предиктом ходящих — фикс пинга)
-- ============================================================
do
    local tT = Tabs.Troll
    local ftOn, ftTool, ftActConn = false, nil, nil
    local flingMode = "Classic"

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

    -- Предикт движения цели для флинга: если цель ходит — берём её скорость и
    -- прижимаем свою HRP к её будущей позиции (примерно через ping секунд).
    local function predictTarget(thrp, hum)
        if not thrp then return thrp.Position end
        local ping = 0
        pcall(function()
            ping = LocalPlayer:GetNetworkPing() * 2
        end)
        ping = math.clamp(ping, 0.02, 0.35)
        local vel = Vector3.zero
        pcall(function()
            vel = thrp.AssemblyLinearVelocity
        end)
        -- Предиктим ТОЛЬКО ходящих (горизонтальная составляющая выше минимума)
        local flatVel = Vector3.new(vel.X, 0, vel.Z)
        if flatVel.Magnitude > 4 then
            return thrp.Position + flatVel * ping
        end
        return thrp.Position
    end

    local function flingClassic(tp)
        if not tp or not tp.Character then return end
        local hrp = getHRP()
        if not hrp then return end
        local tc = tp.Character
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        local thum = tc:FindFirstChildOfClass("Humanoid")
        if not thrp then return end
        local oldPos = hrp.CFrame
        local cam = Workspace.CurrentCamera
        cam.CameraSubject = thrp
        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        local tm = tick()
        repeat
            if hrp and hrp.Parent and thrp and thrp.Parent then
                local predicted = predictTarget(thrp, thum)
                hrp.CFrame = CFrame.new(predicted) * CFrame.new(0, 1.5, 0)
                hrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                hrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
            end
            RunService.Heartbeat:Wait()
        until tick() - tm > 1.5 or not ftOn
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
        local savedVel = hrp0.AssemblyLinearVelocity
        local savedAngVel = hrp0.AssemblyAngularVelocity
        local name = tp.Name
        local startTime = tick()
        while tick() - startTime < 30 do
            if not ftOn then break end
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
            bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            local tm = tick()
            repeat
                if not ftOn then break end
                if hrp and hrp.Parent and thrp and thrp.Parent then
                    local predicted = predictTarget(thrp, hum)
                    hrp.CFrame = CFrame.new(predicted) * CFrame.new(0, 1.5, 0)
                    hrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
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
                hrpEnd.AssemblyLinearVelocity = savedVel
                hrpEnd.AssemblyAngularVelocity = savedAngVel
            end)
        end
    end

    local function doFling(tp)
        if flingMode == "Classic" then flingClassic(tp)
        else flingDeathLoop(tp) end
    end

    local function giveFlingTool()
        if not ftOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("fling")
        if not existing and LocalPlayer.Character then existing = LocalPlayer.Character:FindFirstChild("fling") end
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
        if bp then local t = bp:FindFirstChild("fling"); if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("fling"); if t then pcall(function() t:Destroy() end) end end
    end

    local flingSec = tT:AddSection({ Name = "Отброс" })
    addOpt(flingSec, "AddToggle", "ToolFling", { Title = "Тул отброса (предикт ходящих)", Default = false }, function(v)
        ftOn = v
        if v then giveFlingTool() else removeFlingTool() end
    end)
    addOpt(flingSec, "AddDropdown", "FlingMode", { Title = "Режим", Values = { "Classic", "DeathLoop" }, Default = "Classic" }, function(v)
        flingMode = v or "Classic"
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if ftOn then giveFlingTool() end
    end)
end

pcall(function() Window:SelectTab(1) end)
print("[FH] ============================================")
print("[FH] Part 1/3 — FortniHub v20.1 FIXED — " .. CREDITS)
print("[FH] Backtrack v1+v2 merged, Fling predict, Watermark/WeaponModel removed")
print("[FH] ============================================")
-- ============================================================
-- ЧАСТЬ 2/3 — Movement, Binds, Settings (FIX), Visual (ESP + Skybox), Aura 2.0
-- ============================================================

-- ============================================================
-- ДВИЖЕНИЕ
-- ============================================================
do
    local tM = Tabs.Movement
    local mvSec = tM:AddSection({ Name = "Основное" })
    addOpt(mvSec, "AddToggle", "SpeedToggle", { Title = "Скорость", Default = false }, function() end)
    addOpt(mvSec, "AddSlider", "SpeedValue", { Title = "Скорость ходьбы", Min = 16, Max = 500, Default = 32, Rounding = 0 }, function() end)
    addOpt(mvSec, "AddToggle", "Noclip", { Title = "Noclip", Default = false }, function() end)
    addOpt(mvSec, "AddToggle", "Spinbot", { Title = "Spinbot", Default = false }, function() end)
    addOpt(mvSec, "AddSlider", "SpinSpeed", { Title = "Скорость кручения", Min = 1, Max = 50, Default = 8, Rounding = 0 }, function() end)
    addOpt(mvSec, "AddToggle", "InfJump", { Title = "Бесконечный прыжок", Default = false }, function() end)
    addOpt(mvSec, "AddToggle", "JumpPowerToggle", { Title = "Своя сила прыжка", Default = false }, function() end)
    addOpt(mvSec, "AddSlider", "JumpPowerVal", { Title = "Сила прыжка", Min = 50, Max = 500, Default = 100, Rounding = 0 }, function() end)
    addOpt(mvSec, "AddToggle", "FlyToggle", { Title = "Полёт", Default = false }, function() end)
    addOpt(mvSec, "AddSlider", "FlySpeed", { Title = "Скорость полёта", Min = 20, Max = 500, Default = 60, Rounding = 0 }, function() end)
    addOpt(mvSec, "AddToggle", "BhopOn", { Title = "Банихоп", Default = false }, function() end)
    addOpt(mvSec, "AddSlider", "BhopPower", { Title = "Сила банихопа", Min = 10, Max = 150, Default = 40, Rounding = 0 }, function() end)
    addOpt(mvSec, "AddToggle", "BhopStrafe", { Title = "Стрейф", Default = false }, function() end)

    local bhopOn, bhopPower, bhopStrafe = false, 40, false
    local bhopSpeed, wasJumping, isBoosting = 0, false, false
    registerOnChanged("BhopOn", function(v) bhopOn = v end)
    registerOnChanged("BhopPower", function(v) bhopPower = tonumber(v) or 40 end)
    registerOnChanged("BhopStrafe", function(v) bhopStrafe = v end)

    local jumpHoldAt = 0
    UserInputService.JumpRequest:Connect(function() jumpHoldAt = os.clock() end)
    local function jumpHeld()
        if os.clock() - jumpHoldAt < 0.2 then return true end
        return UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end

    AddConn("BhopTick", RunService.Heartbeat:Connect(function()
        if not bhopOn then
            wasJumping = false; isBoosting = false; bhopSpeed = 0
            return
        end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local st = hum:GetState()
        local jumping = st == Enum.HumanoidStateType.Jumping
        local airborne = jumping or st == Enum.HumanoidStateType.Freefall
        if bhopStrafe then
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
                local dir = hum.MoveDirection
                if dir.Magnitude > 0.1 then
                    dir = Vector3.new(dir.X, 0, dir.Z).Unit
                    local v = hrp.AssemblyLinearVelocity
                    local cur = Vector3.new(v.X, 0, v.Z)
                    local tgt = dir * bhopPower
                    local nxz = cur:Lerp(tgt, 0.3)
                    hrp.AssemblyLinearVelocity = Vector3.new(nxz.X, v.Y, nxz.Z)
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
                        dir = (dir.Magnitude > 0) and dir.Unit or Vector3.zero
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
        wasJumping = jumping
    end))

    local sgOn, sgPower, sgAccel, sgGround = false, 90, 0.6, 16
    addOpt(mvSec, "AddToggle", "SpeedGlitchOn", { Title = "Спидглитч", Default = false }, function(v) sgOn = v end)
    addOpt(mvSec, "AddSlider", "SpeedGlitchPower", { Title = "Скорость в прыжке", Min = 30, Max = 250, Default = 90, Rounding = 0 }, function(v) sgPower = tonumber(v) or 90 end)
    addOpt(mvSec, "AddSlider", "SpeedGlitchAccel", { Title = "Разгон", Min = 0.1, Max = 1, Default = 0.6, Rounding = 2 }, function(v) sgAccel = tonumber(v) or 0.6 end)
    AddConn("SpeedGlitchTick", RunService.Heartbeat:Connect(function()
        if not sgOn then return end
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return end
        local st = h:GetState()
        local air = st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall
        if air then
            local v = hrp.AssemblyLinearVelocity
            local flat = Vector3.new(v.X, 0, v.Z)
            local dir = flat.Magnitude > 0.1 and flat.Unit or (function()
                local lv = hrp.CFrame.LookVector
                return Vector3.new(lv.X, 0, lv.Z).Unit
            end)()
            local cur = flat.Magnitude
            local target = math.max(cur, sgPower)
            local new_mag = cur + (target - cur) * sgAccel
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * new_mag, v.Y, dir.Z * new_mag)
        else
            local v = hrp.AssemblyLinearVelocity
            local flat = Vector3.new(v.X, 0, v.Z)
            if flat.Magnitude > sgGround then
                local dir = flat.Unit
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * sgGround, v.Y, dir.Z * sgGround)
            end
        end
    end))

    local flyGrav = Workspace.Gravity
    local function flyOff()
        Workspace.Gravity = flyGrav
        local hum = getHum()
        if hum then
            pcall(function() hum.PlatformStand = false end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Landed) end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end
        local hrp = getHRP()
        if hrp then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.Velocity = Vector3.zero
            end)
            local bv = hrp:FindFirstChild("FH_FlyBV")
            if bv then bv:Destroy() end
        end
    end
    registerOnChanged("FlyToggle", function(v)
        if v then
            flyGrav = Workspace.Gravity
            Workspace.Gravity = 0
        else
            flyOff()
        end
    end)
    AddConn("FlyTick", RunService.RenderStepped:Connect(function()
        if not (Options.FlyToggle and Options.FlyToggle.Value) then return end
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then return end
        hum.PlatformStand = true
        local sp = (Options.FlySpeed and tonumber(Options.FlySpeed.Value)) or 60
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        hrp.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero
    end))

    AddConn("MovementTick", RunService.Heartbeat:Connect(function()
        local hum = getHum()
        if not hum then return end
        if Options.SpeedToggle and Options.SpeedToggle.Value then
            hum.WalkSpeed = (Options.SpeedValue and tonumber(Options.SpeedValue.Value)) or 32
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
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(S.freezeUpKey) then dir = dir + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(S.freezeDownKey) then dir = dir - Vector3.new(0, 1, 0) end
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
    end))
    AddConn("NoclipTick", RunService.Stepped:Connect(function()
        if Options.Noclip and Options.Noclip.Value then
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end
    end))
    AddConn("InfJump", UserInputService.JumpRequest:Connect(function()
        if Options.InfJump and Options.InfJump.Value then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))

    local freezeSec = tM:AddSection({ Name = "Заморозка" })
    addOpt(freezeSec, "AddToggle", "FreezeToggle", { Title = "Включить", Default = false }, function(v) S.frozen = v end)
    addOpt(freezeSec, "AddSlider", "FreezeSpeed", { Title = "Скорость", Min = 20, Max = 300, Default = 60, Rounding = 0 }, function() end)
    local fUp = freezeSec:AddKeybind("FreezeUpKey", { Title = "Кнопка ВВЕРХ", Default = "Space" })
    fUp:OnChanged(function(k)
        if typeof(k) == "EnumItem" then S.freezeUpKey = k end
    end)
    registerOnChanged("FreezeUpKey", function(k)
        if typeof(k) == "EnumItem" then S.freezeUpKey = k end
    end)
    local fDown = freezeSec:AddKeybind("FreezeDownKey", { Title = "Кнопка ВНИЗ", Default = "LeftAlt" })
    fDown:OnChanged(function(k)
        if typeof(k) == "EnumItem" then S.freezeDownKey = k end
    end)
    registerOnChanged("FreezeDownKey", function(k)
        if typeof(k) == "EnumItem" then S.freezeDownKey = k end
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
-- БИНДЫ
-- ============================================================
do
    local tB = Tabs.Binds
    local BIND_LIST = {
        { id = "SilentEnabled",  title = "Тихий выстрел",         cat = "Бой",       opt = "SilentEnabled" },
        { id = "KAOn",           title = "Килл Аура",              cat = "Бой",       opt = "KAOn" },
        { id = "AutoGrabGun",    title = "Авто-подбор пистолета",  cat = "Бой",       opt = "AutoGrabGun" },
        { id = "SpeedToggle",    title = "Скорость",               cat = "Движение",  opt = "SpeedToggle" },
        { id = "Noclip",         title = "Noclip",                 cat = "Движение",  opt = "Noclip" },
        { id = "Spinbot",        title = "Спинбот",                cat = "Движение",  opt = "Spinbot" },
        { id = "InfJump",        title = "Бесконечный прыжок",     cat = "Движение",  opt = "InfJump" },
        { id = "JumpPowerToggle",title = "Своя сила прыжка",       cat = "Движение",  opt = "JumpPowerToggle" },
        { id = "SpeedGlitchOn",  title = "Спидглитч",              cat = "Движение",  opt = "SpeedGlitchOn" },
        { id = "FlyToggle",      title = "Полёт",                  cat = "Движение",  opt = "FlyToggle" },
        { id = "BhopOn",         title = "Банихоп",                cat = "Движение",  opt = "BhopOn" },
        { id = "FreezeToggle",   title = "Заморозка",              cat = "Движение",  opt = "FreezeToggle" },
        { id = "InvisOn",        title = "Невидимость",            cat = "Другое",    opt = "InvisOn" },
        { id = "BacktrackOn",    title = "Backtrack v1",           cat = "Визуал",    opt = "BacktrackOn" },
        { id = "FHGhostOn",      title = "Backtrack v2 (ghost)",   cat = "Визуал",    opt = "FHGhostOn" },
        { id = "FH_AuraV2On",    title = "Aura 2.0",               cat = "Эффекты",   opt = "FH_AuraV2On" },
        { id = "ToolFling",      title = "Тул отброса",            cat = "Троллинг",  opt = "ToolFling" },
    }
    local BindState = {}
    for _, e in ipairs(BIND_LIST) do
        BindState[e.id] = { key = nil, touchOn = false, btn = nil, def = e }
    end
    getgenv().FH_BindState = BindState

    local touchGui = Instance.new("ScreenGui")
    touchGui.Name = "FH_TouchBinds_v21"
    touchGui.ResetOnSpawn = false
    touchGui.IgnoreGuiInset = true
    touchGui.DisplayOrder = 400
    pcall(function() touchGui.Parent = (gethui and gethui()) or CoreGui end)
    if not touchGui.Parent then touchGui.Parent = CoreGui end
    local buttonsFrozen = false
    getgenv().FH_ButtonsFrozen = false

    local function fireBind(id)
        local st = BindState[id]
        if not st then return end
        local def = st.def
        if def.opt then
            local o = Options[def.opt]
            if o and o.Value ~= nil then
                o:SetValue(not o.Value)
                Notify("FH", def.title .. ": " .. tostring(o.Value), 1.2)
            end
        end
    end

    local function centerSpawn()
        local vp = (Camera and Camera.ViewportSize) or Vector2.new(1280, 720)
        return vp.X * 0.5 - 75, vp.Y * 0.5 - 17
    end

    local function makeTouchButton(id)
        local st = BindState[id]
        if not st or st.btn then return end
        local def = st.def
        local btn = Instance.new("TextButton")
        btn.Name = "FH_BTN_" .. id
        btn.Size = UDim2.fromOffset(150, 34)
        local sx, sy = centerSpawn()
        btn.Position = UDim2.fromOffset(sx, sy)
        btn.BackgroundColor3 = Color3.fromRGB(28, 22, 42)
        btn.BorderSizePixel = 0
        btn.Text = def.title
        btn.TextColor3 = Color3.fromRGB(235, 225, 255)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.AutoButtonColor = true
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
                dragging = true; moved = false
                dragStart = i.Position; posStart = btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if getgenv().FH_ButtonsFrozen then return end
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

    local listSec = tB:AddSection({ Name = "Модули" })
    local currentCat = nil
    for _, def in ipairs(BIND_LIST) do
        if def.cat ~= currentCat then
            currentCat = def.cat
            pcall(function()
                listSec:AddButton({ Title = "--- " .. currentCat .. " ---", Callback = function() end })
            end)
        end
        local st = BindState[def.id]
        local kb = listSec:AddKeybind("BIND_KEY_" .. def.id, { Title = def.title, Default = "Unknown" })
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
        addOpt(listSec, "AddToggle", "BIND_TCH_" .. def.id, { Title = "  Кнопка: " .. def.title, Default = false }, function(v)
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
    local setSec = tB:AddSection({ Name = "Настройки биндов" })
    addOpt(setSec, "AddToggle", "BIND_FREEZE", { Title = "Заморозка кнопок", Default = false }, function(v)
        buttonsFrozen = v
        getgenv().FH_ButtonsFrozen = v
        Notify("FH", v and "Кнопки заморожены" or "Кнопки разморожены", 1.5)
    end)
    setSec:AddButton({ Title = "Сбросить все бинды", Callback = function()
        local count = 0
        for id, st in pairs(BindState) do
            st.key = nil
            if Options["BIND_KEY_" .. id] then
                pcall(function() Options["BIND_KEY_" .. id]:SetValue(Enum.KeyCode.Unknown) end)
                count = count + 1
            end
        end
        Notify("FH", "Сброшено биндов: " .. count, 2)
    end })
    setSec:AddButton({ Title = "Удалить все кнопки", Callback = function()
        for id, st in pairs(BindState) do
            st.touchOn = false
            if Options["BIND_TCH_" .. id] then pcall(function() Options["BIND_TCH_" .. id]:SetValue(false) end) end
            killTouchButton(id)
        end
        Notify("FH", "Все кнопки удалены", 2)
    end })
    getgenv().BINDS_UNLOAD = function()
        for id, st in pairs(BindState) do killTouchButton(id) end
        pcall(function() touchGui:Destroy() end)
    end
end

-- ============================================================
-- НАСТРОЙКИ (ФИКС КОНФИГОВ)
-- ============================================================
do
    local tS = Tabs.Settings
    local setSec = tS:AddSection({ Name = "Основные" })
    addOpt(setSec, "AddToggle", "ShowHUD", { Title = "Показывать HUD", Default = true }, function(v)
        if HUDGui then HUDGui.Enabled = v end
    end)
    addOpt(setSec, "AddSlider", "FPSCap", { Title = "Лимит FPS (0 - без лимита)", Min = 0, Max = 9999, Default = 0, Rounding = 0 }, function(v)
        pcall(function() if setfpscap then setfpscap(tonumber(v) or 0) end end)
    end)
    setSec:AddButton({ Title = "Переподключиться к серверу", Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end })
    setSec:AddButton({ Title = "Сменить сервер", Callback = function()
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
    end })
    addOpt(setSec, "AddToggle", "AntiAFK", { Title = "Anti-AFK", Default = true }, function() end)
    AddConn("AntiAFK", LocalPlayer.Idled:Connect(function()
        if Options.AntiAFK and Options.AntiAFK.Value then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
            end)
        end
    end))
    setSec:AddButton({ Title = "Выгрузить скрипт", Callback = function()
        for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
        Connections = {}
        if HUDGui then HUDGui:Destroy() end
        if Window then pcall(function() Window:Destroy() end) end
        Notify("FH", "Скрипт выгружен", 3)
    end })

    -- ========================================================
    -- КОНФИГИ (ПОЛНОСТЬЮ ПЕРЕПИСАНО)
    -- ========================================================
    local cfgSec = tS:AddSection({ Name = "Конфиги" })
    local CONFIG_DIR = "FortniHub_Configs/"
    local CONFIG_EXT = ".txt"

    local function ensureConfigDir()
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return false end
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
            local name = string.match(f, "([^/\\]+)" .. CONFIG_EXT .. "$")
            if name then out[#out + 1] = name end
        end
        return out
    end

    -- ==== СЕРИАЛИЗАЦИЯ (главный фикс) ====
    local function serializeValue(v)
        local t = typeof(v)
        if t == "Color3" then
            return string.format("C:%.6f,%.6f,%.6f", v.R, v.G, v.B)
        end
        if t == "EnumItem" then
            local ok, name = pcall(function() return v.Name end)
            if not ok then return nil end
            local ok2, enumName = pcall(function() return tostring(v.EnumType) end)
            if not ok2 then return nil end
            return "E:" .. enumName .. "|" .. name
        end
        local lt = type(v)
        if lt == "number" then
            if v ~= v then return nil end
            return "N:" .. tostring(v)
        end
        if lt == "boolean" then
            return "B:" .. tostring(v)
        end
        if lt == "string" then
            -- если это может быть KeyCode - сохраним как K:
            local ok = pcall(function() return Enum.KeyCode[v] end)
            if ok and Enum.KeyCode[v] then
                return "K:" .. v
            end
            local safe = v:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t"):gsub("\r", "\\r")
            return "S:" .. safe
        end
        if lt == "table" then
            local isArray = true
            local count = 0
            for k in pairs(v) do
                count = count + 1
                if type(k) ~= "number" then isArray = false; break end
            end
            if isArray and count == #v then
                local parts = {}
                for i = 1, #v do
                    local ser = serializeValue(v[i])
                    if ser then parts[#parts + 1] = ser end
                end
                return "L:" .. table.concat(parts, ";;")
            else
                local parts = {}
                for k, val in pairs(v) do
                    local ser = serializeValue(val)
                    if ser then
                        parts[#parts + 1] = tostring(k) .. "=" .. ser
                    end
                end
                return "D:" .. table.concat(parts, ";;")
            end
        end
        return nil
    end

    local function deserializeValue(s)
        local prefix, rest = string.match(s, "^(%a):(.*)$")
        if not prefix then return nil end
        if prefix == "K" then
            return Enum.KeyCode[rest]
        end
        if prefix == "C" then
            local r, g, b = string.match(rest, "([^,]+),([^,]+),([^,]+)")
            if r and g and b then
                return Color3.new(tonumber(r) or 0, tonumber(g) or 0, tonumber(b) or 0)
            end
            return nil
        end
        if prefix == "E" then
            local enumType, name = string.match(rest, "^([^|]+)|(.+)$")
            if enumType and name then
                local ok, et = pcall(function() return Enum[enumType] end)
                if ok and et and et[name] then return et[name] end
            end
            return nil
        end
        if prefix == "N" then return tonumber(rest) end
        if prefix == "B" then return rest == "true" end
        if prefix == "S" then
            local safe = rest:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\\t", "\t"):gsub("\\\\", "\\")
            return safe
        end
        if prefix == "L" then
            local out = {}
            for piece in string.gmatch(rest, "([^;]+)") do
                local v = deserializeValue(piece)
                if v ~= nil then out[#out + 1] = v end
            end
            return out
        end
        if prefix == "D" then
            local out = {}
            for pair in string.gmatch(rest, "([^;]+)") do
                local k, val = string.match(pair, "^(.-)=(.+)$")
                if k then
                    local v = deserializeValue(val)
                    if v ~= nil then out[k] = v end
                end
            end
            return out
        end
        return nil
    end

    local function saveConfig(name)
        if type(writefile) ~= "function" then
            Notify("FH", "Нет writefile", 4)
            return false
        end
        if not ensureConfigDir() then
            Notify("FH", "Не создал папку", 4)
            return false
        end
        local lines = { "-- FortniHub Config: " .. tostring(name), "-- " .. os.date("%Y-%m-%d %H:%M:%S") }
        local count = 0
        for optionName, option in pairs(Options) do
            if option and option.Value ~= nil then
                local ok, ser = pcall(serializeValue, option.Value)
                if ok and ser then
                    lines[#lines + 1] = optionName .. "\t" .. ser
                    count = count + 1
                end
            end
        end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        local ok = pcall(writefile, path, table.concat(lines, "\n"))
        if ok then
            Notify("FH", "Сохранено: " .. name .. " (" .. count .. " опций)", 3)
            return true
        end
        Notify("FH", "Ошибка сохранения", 3)
        return false
    end

    local function loadConfig(name)
        if type(readfile) ~= "function" then
            Notify("FH", "Нет readfile", 4)
            return false
        end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        local ok, data = pcall(readfile, path)
        if not ok or type(data) ~= "string" then
            Notify("FH", "Ошибка чтения", 3)
            return false
        end
        local loaded, bindLoaded = 0, 0
        local BS = getgenv().FH_BindState
        for line in string.gmatch(data, "[^\r\n]+") do
            if line:sub(1, 2) ~= "--" then
                local key, ser = string.match(line, "^([^\t]+)\t(.+)$")
                if key and ser then
                    if key:sub(1, 9) == "BIND_KEY_" then
                        local id = key:sub(10)
                        local val = deserializeValue(ser)
                        if val and Options[key] then
                            pcall(function() Options[key]:SetValue(val) end)
                            if BS and BS[id] then BS[id].key = val end
                            bindLoaded = bindLoaded + 1
                        end
                        loaded = loaded + 1
                    else
                        local val = deserializeValue(ser)
                        if val ~= nil and Options[key] then
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
        if type(delfile) ~= "function" then
            Notify("FH", "Нет delfile", 4)
            return false
        end
        local ok = pcall(delfile, CONFIG_DIR .. name .. CONFIG_EXT)
        if ok then
            Notify("FH", "Удалено: " .. name, 2)
            return true
        end
        return false
    end

    local currentList = listConfigs()
    if #currentList == 0 then currentList = { "(нет конфигов)" } end
    local drop = cfgSec:AddDropdown("ConfigPick", { Title = "Выбрать конфиг", Values = currentList, Default = currentList[1] })
    local function refreshList()
        local list = listConfigs()
        if #list == 0 then list = { "(нет конфигов)" } end
        pcall(function()
            drop:SetValues(list)
            if drop.Generate then drop:Generate() end
        end)
    end
    cfgSec:AddInput("ConfigName", { Title = "Имя конфига", Default = "my_config" })
    cfgSec:AddButton({ Title = "Сохранить", Callback = function()
        local nameOpt = Options.ConfigName
        local name = nameOpt and nameOpt.Value or "my_config"
        if type(name) ~= "string" or name == "" then
            Notify("FH", "Введи имя", 3); return
        end
        if saveConfig(name) then refreshList() end
    end })
    cfgSec:AddButton({ Title = "Загрузить", Callback = function()
        local pickOpt = Options.ConfigPick
        local name = pickOpt and pickOpt.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3); return
        end
        loadConfig(name)
    end })
    cfgSec:AddButton({ Title = "Удалить", Callback = function()
        local pickOpt = Options.ConfigPick
        local name = pickOpt and pickOpt.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3); return
        end
        if deleteConfig(name) then refreshList() end
    end })
    cfgSec:AddButton({ Title = "Обновить список", Callback = refreshList })
    if HUDGui then HUDGui.Enabled = true end

    getgenv().FH_SaveConfig = saveConfig
    getgenv().FH_LoadConfig = loadConfig
    getgenv().FH_ListConfigs = listConfigs
end

-- ============================================================
-- ESP И ВИЗУАЛЫ (кроме skybox)
-- ============================================================
do
    local espState = {
        enabled = false, box = false, boxCol = { Color3.fromRGB(255, 255, 255), 1 }, boxType = "Static",
        boxGrd = false, boxGrd1 = Color3.fromRGB(255, 60, 60), boxGrd2 = Color3.fromRGB(255, 180, 60),
        boxFill = false, boxFillCol = { Color3.fromRGB(255, 60, 60), 0.5 },
        name = false, nameCol = { Color3.new(1, 1, 1), 1 }, dist = false, distCol = { Color3.fromRGB(220, 220, 220), 1 },
        avatar = false, skel = false, skelCol = { Color3.new(1, 1, 1), 1 }, chams = false,
        chamsFMur = { Color3.fromRGB(255, 60, 60), 0.55 }, chamsOMur = { Color3.fromRGB(255, 60, 60), 0.15 },
        chamsFInno = { Color3.new(1, 1, 1), 0.55 }, chamsOInno = { Color3.new(1, 1, 1), 0.15 },
        chamsFShf = { Color3.fromRGB(0, 153, 255), 0.55 }, chamsOShf = { Color3.fromRGB(0, 153, 255), 0.15 },
        chamsFHero = { Color3.fromRGB(255, 215, 0), 0.55 }, chamsOHero = { Color3.fromRGB(255, 215, 0), 0.15 },
        matChams = false, matType = "ForceField", matColMur = Color3.fromRGB(255, 60, 60),
        matColInno = Color3.new(1, 1, 1), matColShf = Color3.fromRGB(0, 153, 255), matColHero = Color3.fromRGB(255, 215, 0),
        flags = false, flagMur = { Color3.fromRGB(255, 60, 60), 1 }, flagShf = { Color3.fromRGB(0, 153, 255), 1 }, flagHero = { Color3.fromRGB(255, 215, 0), 1 },
        arrows = false, arrowMur = Color3.fromRGB(255, 60, 60), arrowInno = Color3.new(1, 1, 1),
        arrowShf = Color3.fromRGB(0, 153, 255), arrowHero = Color3.fromRGB(255, 215, 0),
        arrowSize = 42, arrowDist = 260, maxDist = 500, allowLocal = false,
        gunEspOn = false, gunTextOn = false, gunTextCol = Color3.new(1, 1, 1),
        gunHlOn = false, gunHlCol = Color3.new(1, 1, 1),
    }
    _G.FH_ESP = espState
    local drawCache = {}
    local chamsFolder = Instance.new("Folder"); chamsFolder.Name = "FH_Chams"; chamsFolder.Parent = Workspace
    local gunFolder = Instance.new("Folder"); gunFolder.Name = "FH_GunChams"; gunFolder.Parent = Workspace

    local function classifyRole(p)
        local r = getRoleFromData(p)
        if r == "murderer" then return "Mur" end
        if r == "sheriff" then return "Shf" end
        if r == "hero" then return "Hero" end
        return "Inno"
    end
    local function roleColor(role)
        if role == "Mur" then return Color3.fromRGB(255, 60, 60) end
        if role == "Shf" then return Color3.fromRGB(0, 153, 255) end
        if role == "Hero" then return Color3.fromRGB(255, 215, 0) end
        return Color3.new(1, 1, 1)
    end
    local function getDraw(p)
        local d = drawCache[p]
        if d then return d end
        d = { box = {}, boxFill = nil, name = nil, dist = nil, avatar = nil, skel = {}, flags = {}, arrow = nil }
        drawCache[p] = d
        return d
    end
    local function ensureBox(e, i)
        if e.box[i] then return e.box[i] end
        local d = Drawing.new("Line")
        d.Thickness = 1.5; d.Transparency = 1; d.Visible = false
        e.box[i] = d
        return d
    end
    local function grad(c1, c2)
        local t = math.sin(os.clock() * 3) * 0.5 + 0.5
        return c1:Lerp(c2, t)
    end
    local function dispose(e)
        for _, d in pairs(e.box) do pcall(function() d:Remove() end) end
        if e.boxFill then pcall(function() e.boxFill:Remove() end) end
        if e.name then pcall(function() e.name:Remove() end) end
        if e.dist then pcall(function() e.dist:Remove() end) end
        if e.avatar then pcall(function() e.avatar:Remove() end) end
        for _, d in pairs(e.skel) do pcall(function() d:Remove() end) end
        for _, d in pairs(e.flags) do pcall(function() d:Remove() end) end
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

    local matCache = {}
    local function restoreMat()
        for part, o in pairs(matCache) do
            if part.Parent then
                pcall(function() part.Material = o.m end)
                pcall(function() part.Color = o.c end)
            end
        end
        table.clear(matCache)
    end
    local function updateMatChams()
        if not espState.matChams then
            if next(matCache) then restoreMat() end
            return
        end
        local mat = Enum.Material.ForceField
        if espState.matType == "Flat" then mat = Enum.Material.SmoothPlastic
        elseif espState.matType == "Chromatic" then mat = Enum.Material.Foil end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local role = classifyRole(p)
                local col
                if role == "Mur" then col = espState.matColMur
                elseif role == "Shf" then col = espState.matColShf
                elseif role == "Hero" then col = espState.matColHero
                else col = espState.matColInno end
                for _, part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if not matCache[part] then matCache[part] = { m = part.Material, c = part.Color } end
                        pcall(function() part.Material = mat end)
                        pcall(function() part.Color = col end)
                    end
                end
            end
        end
    end

    -- gun esp
    local gunCache, gunCandidates, gunScanAcc = {}, {}, 0
    local function inCharacter(obj)
        local node = obj.Parent
        while node and node ~= Workspace do
            if node:IsA("Model") and Players:GetPlayerFromCharacter(node) then return true end
            node = node.Parent
        end
        return false
    end
    local function renderPart(obj)
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true) end
        return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    local function collectGuns()
        local list = {}
        for obj in pairs(gunCandidates) do
            if obj.Name == "GunDrop" and obj.Parent and not inCharacter(obj) then
                local part = renderPart(obj)
                if part then
                    local adorn = (obj:IsA("BasePart") or obj:IsA("Model")) and obj or part
                    list[#list + 1] = { obj = obj, part = part, adorn = adorn }
                end
            end
        end
        return list
    end
    local function clearGun(obj)
        local e = gunCache[obj]
        if e then
            if e.hl then pcall(function() e.hl:Destroy() end) end
            if e.txt then pcall(function() e.txt:Remove() end) end
            gunCache[obj] = nil
        end
    end
    local function clearGuns()
        for obj in pairs(gunCache) do clearGun(obj) end
    end
    local gunParts = {}
    local function gunRender(dt)
        if not espState.gunEspOn then
            if next(gunCache) then clearGuns() end
            return
        end
        gunScanAcc = gunScanAcc + dt
        if gunScanAcc >= 0.25 then
            gunScanAcc = 0
            gunParts = collectGuns()
            local set = {}
            for _, entry in ipairs(gunParts) do set[entry.obj] = true end
            for obj in pairs(gunCache) do
                if not set[obj] then clearGun(obj) end
            end
        end
        for _, entry in ipairs(gunParts) do
            local obj, part = entry.obj, entry.part
            if obj.Parent and part and part.Parent then
                local e = gunCache[obj]
                if not e then e = {}; gunCache[obj] = e end
                if espState.gunHlOn then
                    if not e.hl then
                        local hl = Instance.new("Highlight")
                        hl.FillTransparency = 1
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = gunFolder
                        e.hl = hl
                    end
                    e.hl.Adornee = entry.adorn
                    e.hl.OutlineColor = espState.gunHlCol
                    e.hl.OutlineTransparency = 0
                    e.hl.Enabled = true
                elseif e.hl then e.hl.Enabled = false end
                if espState.gunTextOn then
                    local sp = Camera:WorldToViewportPoint(part.Position)
                    if not e.txt then
                        local t = Drawing.new("Text")
                        t.Center = true; t.Outline = true; t.Size = 13
                        e.txt = t
                    end
                    if sp.Z > 0 then
                        e.txt.Position = Vector2.new(sp.X, sp.Y)
                        e.txt.Text = "Gun"
                        e.txt.Color = espState.gunTextCol
                        e.txt.Visible = true
                    else
                        e.txt.Visible = false
                    end
                elseif e.txt then e.txt.Visible = false end
            else
                clearGun(obj)
            end
        end
    end

    local function collectCandidates()
        table.clear(gunCandidates)
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "GunDrop" and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool")) then
                gunCandidates[obj] = true
            end
        end
    end
    Workspace.DescendantAdded:Connect(function(obj)
        if obj.Name == "GunDrop" and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool")) then
            gunCandidates[obj] = true
        end
    end)
    Workspace.DescendantRemoving:Connect(function(obj)
        if obj.Name == "GunDrop" then gunCandidates[obj] = nil end
    end)

    RunService.RenderStepped:Connect(function(dt)
        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer and not espState.allowLocal then
                killCham(p)
            else
                local char = p.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
                local head = char and char:FindFirstChild("Head")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if char and hrp and head and hum and hum.Health > 0 then
                    seen[p] = true
                    local role = classifyRole(p)
                    local dcol = roleColor(role)
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    local fade = math.clamp(1 - dist / espState.maxDist, 0.15, 1)
                    if espState.enabled then
                        local headPos = head.Position + Vector3.new(0, head.Size.Y * 0.5, 0)
                        local footPos = hrp.Position - Vector3.new(0, hrp.Size.Y * 0.5 + (hum.HipHeight or 0), 0)
                        local hsp, hon = Camera:WorldToViewportPoint(headPos)
                        local fsp, fon = Camera:WorldToViewportPoint(footPos)
                        if hon or fon then
                            local e = getDraw(p)
                            if espState.box then
                                local w = math.max(40, (hsp.Y - fsp.Y) * 0.5)
                                local cx = (hsp.X + fsp.X) * 0.5
                                local top, bot = hsp.Y, fsp.Y
                                local l, r = cx - w, cx + w
                                local col = espState.boxGrd and grad(espState.boxGrd1, espState.boxGrd2) or espState.boxCol[1]
                                local a = (espState.boxCol[2] or 1) * fade
                                if espState.boxType == "Corners" then
                                    local sg = math.min(w, bot - top) * 0.25
                                    local lines = {
                                        { l, top, l + sg, top }, { l, top, l, top + sg },
                                        { r, top, r - sg, top }, { r, top, r, top + sg },
                                        { l, bot, l + sg, bot }, { l, bot, l, bot - sg },
                                        { r, bot, r - sg, bot }, { r, bot, r, bot - sg },
                                    }
                                    for i, ln in ipairs(lines) do
                                        local line = ensureBox(e, i)
                                        line.From = Vector2.new(ln[1], ln[2])
                                        line.To = Vector2.new(ln[3], ln[4])
                                        line.Color = col
                                        line.Transparency = a
                                        line.Visible = true
                                    end
                                    for i = #lines + 1, #e.box do e.box[i].Visible = false end
                                else
                                    local lines = { { l, top, r, top }, { r, top, r, bot }, { r, bot, l, bot }, { l, bot, l, top } }
                                    for i, ln in ipairs(lines) do
                                        local line = ensureBox(e, i)
                                        line.From = Vector2.new(ln[1], ln[2])
                                        line.To = Vector2.new(ln[3], ln[4])
                                        line.Color = col
                                        line.Transparency = a
                                        line.Visible = true
                                    end
                                    for i = 5, #e.box do e.box[i].Visible = false end
                                end
                                if espState.boxFill then
                                    if not e.boxFill then
                                        e.boxFill = Drawing.new("Square")
                                        e.boxFill.Filled = true
                                        e.boxFill.Thickness = 0
                                    end
                                    e.boxFill.Position = Vector2.new(l, top)
                                    e.boxFill.Size = Vector2.new(r - l, bot - top)
                                    e.boxFill.Color = dcol
                                    e.boxFill.Transparency = (espState.boxFillCol[2] or 0.5) * fade
                                    e.boxFill.Visible = true
                                elseif e.boxFill then e.boxFill.Visible = false end
                            else
                                for _, ln in pairs(e.box) do ln.Visible = false end
                                if e.boxFill then e.boxFill.Visible = false end
                            end
                            if espState.name then
                                if not e.name then
                                    e.name = Drawing.new("Text")
                                    e.name.Size = 13; e.name.Center = true; e.name.Outline = true
                                end
                                e.name.Text = p.Name
                                e.name.Position = Vector2.new((hsp.X + fsp.X) * 0.5, hsp.Y - 18)
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
                                e.dist.Position = Vector2.new((hsp.X + fsp.X) * 0.5, fsp.Y + 4)
                                e.dist.Color = espState.distCol[1]
                                e.dist.Transparency = (espState.distCol[2] or 1) * fade
                                e.dist.Visible = true
                            elseif e.dist then e.dist.Visible = false end
                            if espState.avatar then
                                if not e.avatar then
                                    e.avatar = Drawing.new("Image")
                                    e.avatar.Size = Vector2.new(40, 40)
                                    pcall(function()
                                        local av = getgenv().FH_GetAvatarFor and getgenv().FH_GetAvatarFor(p)
                                        if av then e.avatar.Data = av end
                                    end)
                                end
                                e.avatar.Position = Vector2.new((hsp.X + fsp.X) * 0.5 - 20, hsp.Y - 60)
                                e.avatar.Transparency = fade
                                e.avatar.Visible = true
                            elseif e.avatar then e.avatar.Visible = false end
                            if espState.skel then
                                local bones = {
                                    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
                                    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
                                    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
                                    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
                                    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
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
                                for i = #bones + 1, #e.skel do e.skel[i].Visible = false end
                            else
                                for _, dr in pairs(e.skel) do dr.Visible = false end
                            end
                            if espState.flags then
                                local txt = role == "Mur" and "[MURD]" or (role == "Shf" and "[SHF]" or (role == "Hero" and "[HERO]" or ""))
                                if txt ~= "" then
                                    if not e.flags[1] then
                                        e.flags[1] = Drawing.new("Text")
                                        e.flags[1].Size = 13; e.flags[1].Outline = true
                                    end
                                    local dr = e.flags[1]
                                    dr.Text = txt
                                    dr.Position = Vector2.new(hsp.X + 60, hsp.Y - 10)
                                    dr.Color = role == "Mur" and espState.flagMur[1] or (role == "Hero" and espState.flagHero[1] or espState.flagShf[1])
                                    dr.Transparency = fade
                                    dr.Visible = true
                                else
                                    for _, dr in pairs(e.flags) do dr.Visible = false end
                                end
                            else
                                for _, dr in pairs(e.flags) do dr.Visible = false end
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
                                    local cx, cy = vp.X * 0.5, vp.Y * 0.5
                                    local dir = Vector2.new(hsp.X - cx, hsp.Y - cy)
                                    if dir.Magnitude < 0.01 then dir = Vector2.new(0, 1) end
                                    dir = dir.Unit
                                    local px = cx + dir.X * espState.arrowDist
                                    local py = cy + dir.Y * espState.arrowDist
                                    local sz = espState.arrowSize
                                    local perp = Vector2.new(-dir.Y, dir.X)
                                    e.arrow.PointA = Vector2.new(px + dir.X * sz * 0.5, py + dir.Y * sz * 0.5)
                                    e.arrow.PointB = Vector2.new(px - dir.X * sz * 0.5 + perp.X * sz * 0.5, py - dir.Y * sz * 0.5 + perp.Y * sz * 0.5)
                                    e.arrow.PointC = Vector2.new(px - dir.X * sz * 0.5 - perp.X * sz * 0.5, py - dir.Y * sz * 0.5 - perp.Y * sz * 0.5)
                                    e.arrow.Color = role == "Mur" and espState.arrowMur or (role == "Shf" and espState.arrowShf or (role == "Hero" and espState.arrowHero or espState.arrowInno))
                                    e.arrow.Transparency = fade
                                    e.arrow.Visible = true
                                end
                            elseif e.arrow then e.arrow.Visible = false end
                        end
                    else
                        local e = drawCache[p]
                        if e then
                            for _, ln in pairs(e.box) do ln.Visible = false end
                            if e.boxFill then e.boxFill.Visible = false end
                            if e.name then e.name.Visible = false end
                            if e.dist then e.dist.Visible = false end
                            if e.avatar then e.avatar.Visible = false end
                            for _, dr in pairs(e.skel) do dr.Visible = false end
                            for _, dr in pairs(e.flags) do dr.Visible = false end
                            if e.arrow then e.arrow.Visible = false end
                        end
                    end
                    if espState.chams then
                        local h = ensureCham(p, char)
                        local fill = espState["chamsF" .. role] or espState.chamsFInno
                        local outl = espState["chamsO" .. role] or espState.chamsOInno
                        h.FillColor = fill[1]
                        h.FillTransparency = fill[2]
                        h.OutlineColor = outl[1]
                        h.OutlineTransparency = outl[2]
                    else killCham(p) end
                else
                    local e = drawCache[p]
                    if e then
                        for _, ln in pairs(e.box) do ln.Visible = false end
                        if e.boxFill then e.boxFill.Visible = false end
                        if e.name then e.name.Visible = false end
                        if e.dist then e.dist.Visible = false end
                        if e.avatar then e.avatar.Visible = false end
                        for _, dr in pairs(e.skel) do dr.Visible = false end
                        for _, dr in pairs(e.flags) do dr.Visible = false end
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
        updateMatChams()
        gunRender(dt)
    end)
    Players.PlayerRemoving:Connect(function(p) killCham(p) end)

    local tV = Tabs.Visual
    local espSec = tV:AddSection({ Name = "ESP Игроков" })
    addOpt(espSec, "AddToggle", "ESPOn", { Title = "Включить ESP", Default = false }, function(v)
        espState.enabled = v
        if not v then
            for _, e in pairs(drawCache) do dispose(e) end
            drawCache = {}
        end
    end)
    addOpt(espSec, "AddToggle", "ESPBox", { Title = "Рамка", Default = false }, function(v) espState.box = v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxCol", { Title = "Цвет рамки", Default = Color3.new(1, 1, 1) }, function(c) espState.boxCol[1] = c end)
    addOpt(espSec, "AddSlider", "ESPBoxAlpha", { Title = "Прозрачность рамки", Min = 0, Max = 1, Default = 1, Rounding = 2 }, function(v) espState.boxCol[2] = tonumber(v) or 1 end)
    addOpt(espSec, "AddDropdown", "ESPBoxType", { Title = "Тип рамки", Values = { "Прямоугольник", "Уголки" }, Default = "Прямоугольник" }, function(v) espState.boxType = (v == "Уголки") and "Corners" or "Static" end)
    addOpt(espSec, "AddToggle", "ESPBoxGrd", { Title = "Градиент рамки", Default = false }, function(v) espState.boxGrd = v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxGrd1", { Title = "Цвет 1", Default = Color3.fromRGB(255, 60, 60) }, function(c) espState.boxGrd1 = c end)
    addOpt(espSec, "AddColorPicker", "ESPBoxGrd2", { Title = "Цвет 2", Default = Color3.fromRGB(255, 180, 60) }, function(c) espState.boxGrd2 = c end)
    addOpt(espSec, "AddToggle", "ESPBoxFill", { Title = "Заливка", Default = false }, function(v) espState.boxFill = v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxFillCol", { Title = "Цвет заливки", Default = Color3.fromRGB(255, 60, 60) }, function(c) espState.boxFillCol[1] = c end)
    addOpt(espSec, "AddSlider", "ESPBoxFillAlpha", { Title = "Прозрачность заливки", Min = 0, Max = 1, Default = 0.5, Rounding = 2 }, function(v) espState.boxFillCol[2] = tonumber(v) or 0.5 end)
    addOpt(espSec, "AddToggle", "ESPName", { Title = "Имя", Default = false }, function(v) espState.name = v end)
    addOpt(espSec, "AddColorPicker", "ESPNameCol", { Title = "Цвет имени", Default = Color3.new(1, 1, 1) }, function(c) espState.nameCol[1] = c end)
    addOpt(espSec, "AddToggle", "ESPDist", { Title = "Дистанция", Default = false }, function(v) espState.dist = v end)
    addOpt(espSec, "AddColorPicker", "ESPDistCol", { Title = "Цвет дистанции", Default = Color3.fromRGB(220, 220, 220) }, function(c) espState.distCol[1] = c end)
    addOpt(espSec, "AddToggle", "ESPAvatar", { Title = "Аватарка", Default = false }, function(v) espState.avatar = v end)
    addOpt(espSec, "AddToggle", "ESPSkel", { Title = "Скелет", Default = false }, function(v) espState.skel = v end)
    addOpt(espSec, "AddColorPicker", "ESPSkelCol", { Title = "Цвет скелета", Default = Color3.new(1, 1, 1) }, function(c) espState.skelCol[1] = c end)
    addOpt(espSec, "AddToggle", "ESPChams", { Title = "Свечение", Default = false }, function(v) espState.chams = v end)
    local function chamsPair(prefix, role, defFill, defOut)
        addOpt(espSec, "AddColorPicker", "ChamsF" .. prefix, { Title = role .. " заливка", Default = defFill }, function(c) espState["chamsF" .. prefix][1] = c end)
        addOpt(espSec, "AddSlider", "ChamsFA" .. prefix, { Title = role .. " прозр", Min = 0, Max = 1, Default = 0.55, Rounding = 2 }, function(v) espState["chamsF" .. prefix][2] = tonumber(v) or 0.55 end)
        addOpt(espSec, "AddColorPicker", "ChamsO" .. prefix, { Title = role .. " обводка", Default = defOut }, function(c) espState["chamsO" .. prefix][1] = c end)
        addOpt(espSec, "AddSlider", "ChamsOA" .. prefix, { Title = role .. " прозр обводки", Min = 0, Max = 1, Default = 0.15, Rounding = 2 }, function(v) espState["chamsO" .. prefix][2] = tonumber(v) or 0.15 end)
    end
    chamsPair("Mur", "Убийца", Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 120, 120))
    chamsPair("Inno", "Мирный", Color3.new(1, 1, 1), Color3.new(1, 1, 1))
    chamsPair("Shf", "Шериф", Color3.fromRGB(0, 153, 255), Color3.fromRGB(120, 200, 255))
    chamsPair("Hero", "Герой", Color3.fromRGB(255, 215, 0), Color3.fromRGB(255, 240, 140))
    addOpt(espSec, "AddToggle", "ESPMatChams", { Title = "Материал-чамсы", Default = false }, function(v) espState.matChams = v end)
    addOpt(espSec, "AddDropdown", "ESPMatType", { Title = "Материал", Values = { "ForceField", "Flat", "Chromatic" }, Default = "ForceField" }, function(v) espState.matType = v end)
    addOpt(espSec, "AddColorPicker", "ESPMatMur", { Title = "Убийца", Default = Color3.fromRGB(255, 60, 60) }, function(c) espState.matColMur = c end)
    addOpt(espSec, "AddColorPicker", "ESPMatInno", { Title = "Мирный", Default = Color3.new(1, 1, 1) }, function(c) espState.matColInno = c end)
    addOpt(espSec, "AddColorPicker", "ESPMatShf", { Title = "Шериф", Default = Color3.fromRGB(0, 153, 255) }, function(c) espState.matColShf = c end)
    addOpt(espSec, "AddColorPicker", "ESPMatHero", { Title = "Герой", Default = Color3.fromRGB(255, 215, 0) }, function(c) espState.matColHero = c end)
    addOpt(espSec, "AddToggle", "ESPFlags", { Title = "Метки ролей", Default = false }, function(v) espState.flags = v end)
    addOpt(espSec, "AddToggle", "ESPArrows", { Title = "Стрелки", Default = false }, function(v) espState.arrows = v end)
    addOpt(espSec, "AddColorPicker", "ESPArrMur", { Title = "Убийца", Default = Color3.fromRGB(255, 60, 60) }, function(c) espState.arrowMur = c end)
    addOpt(espSec, "AddColorPicker", "ESPArrInno", { Title = "Мирный", Default = Color3.new(1, 1, 1) }, function(c) espState.arrowInno = c end)
    addOpt(espSec, "AddColorPicker", "ESPArrShf", { Title = "Шериф", Default = Color3.fromRGB(0, 153, 255) }, function(c) espState.arrowShf = c end)
    addOpt(espSec, "AddColorPicker", "ESPArrHero", { Title = "Герой", Default = Color3.fromRGB(255, 215, 0) }, function(c) espState.arrowHero = c end)
    addOpt(espSec, "AddSlider", "ESPArrSz", { Title = "Размер стрелок", Min = 16, Max = 96, Default = 42, Rounding = 0 }, function(v) espState.arrowSize = tonumber(v) or 42 end)
    addOpt(espSec, "AddSlider", "ESPArrDist", { Title = "Дистанция стрелок", Min = 40, Max = 520, Default = 260, Rounding = 0 }, function(v) espState.arrowDist = tonumber(v) or 260 end)
    addOpt(espSec, "AddSlider", "ESPMaxDist", { Title = "Макс дистанция ESP", Min = 50, Max = 1000, Default = 500, Rounding = 0 }, function(v) espState.maxDist = tonumber(v) or 500 end)
    addOpt(espSec, "AddToggle", "ESPAllowLocal", { Title = "Показывать себя", Default = false }, function(v) espState.allowLocal = v end)

    local gunSec = tV:AddSection({ Name = "ESP Пистолета" })
    addOpt(gunSec, "AddToggle", "GunEspOn", { Title = "ESP пистолета", Default = false }, function(v)
        espState.gunEspOn = v
        if v then collectCandidates() else clearGuns() end
    end)
    addOpt(gunSec, "AddToggle", "GunTextOn", { Title = "Текст", Default = false }, function(v) espState.gunTextOn = v end)
    addOpt(gunSec, "AddColorPicker", "GunTextCol", { Title = "Цвет текста", Default = Color3.new(1, 1, 1) }, function(c) espState.gunTextCol = c end)
    addOpt(gunSec, "AddToggle", "GunHlOn", { Title = "Обводка", Default = false }, function(v) espState.gunHlOn = v end)
    addOpt(gunSec, "AddColorPicker", "GunHlCol", { Title = "Цвет обводки", Default = Color3.new(1, 1, 1) }, function(c) espState.gunHlCol = c end)

    -- Camera
    local camSec = tV:AddSection({ Name = "Камера" })
    local ratioOn, ratioValue = false, 100
    local aspectMul = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    RunService:BindToRenderStep("FH_aspect", Enum.RenderPriority.Camera.Value + 1, function()
        if not ratioOn then return end
        local cam = Workspace.CurrentCamera
        if cam then cam.CFrame = cam.CFrame * aspectMul end
    end)
    addOpt(camSec, "AddToggle", "AspectOn", { Title = "Aspect ratio", Default = false }, function(v) ratioOn = v end)
    addOpt(camSec, "AddSlider", "AspectVal", { Title = "Значение", Min = 1, Max = 100, Default = 100, Rounding = 0 }, function(v)
        ratioValue = tonumber(v) or 100
        aspectMul = CFrame.new(0, 0, 0, 1, 0, 0, 0, ratioValue / 100, 0, 0, 0, 1)
    end)
    local fovOn, fovValue, fovOrig = false, 70, nil
    RunService.RenderStepped:Connect(function()
        if not fovOn then return end
        local cam = Workspace.CurrentCamera
        if cam and cam.FieldOfView ~= fovValue then cam.FieldOfView = fovValue end
    end)
    addOpt(camSec, "AddToggle", "FovOn", { Title = "Своё FOV", Default = false }, function(v)
        fovOn = v
        local cam = Workspace.CurrentCamera
        if v then
            if cam then fovOrig = cam.FieldOfView; cam.FieldOfView = fovValue end
        else
            if cam and fovOrig then cam.FieldOfView = fovOrig end
        end
    end)
    addOpt(camSec, "AddSlider", "FovVal", { Title = "FOV", Min = 30, Max = 120, Default = 70, Rounding = 0 }, function(v)
        fovValue = tonumber(v) or 70
        if fovOn then
            local cam = Workspace.CurrentCamera
            if cam then cam.FieldOfView = fovValue end
        end
    end)
end

-- ============================================================
-- СВОИ ВИЗУАЛЫ (ChinaHat, LandCircle, MovGraph — ФИКС)
-- ============================================================
do
    local lvSec = Tabs.Visual:AddSection({ Name = "Свои визуалы" })

    -- ====== CHINA HAT ======
    local chGui = Instance.new("ScreenGui")
    chGui.Name = "FH_ChinaHat_v21"
    chGui.ResetOnSpawn = false
    chGui.IgnoreGuiInset = true
    chGui.DisplayOrder = 999
    chGui.Parent = (gethui and gethui()) or CoreGui
    local holder = Instance.new("Frame")
    holder.Size = UDim2.fromScale(1, 1)
    holder.BackgroundTransparency = 1
    holder.BorderSizePixel = 0
    holder.Parent = chGui
    local chRows = {}
    local chOn, chCol = false, Color3.fromRGB(170, 85, 255)
    local SEG, RAD, HEIGHT, DROP, ALPHA = 36, 1.6, 0.9, 0.02, 0.28
    local MAX_ROWS = 120
    local function chEnsure(n)
        for i = #chRows + 1, n do
            local f = Instance.new("Frame")
            f.BorderSizePixel = 0
            f.BackgroundTransparency = ALPHA
            f.Visible = false
            f.ZIndex = 5
            f.Parent = holder
            chRows[i] = f
        end
    end
    local function chHideAll()
        for _, f in ipairs(chRows) do if f.Visible then f.Visible = false end end
    end
    local function proj(p)
        local sp, on = Camera:WorldToViewportPoint(p)
        if sp.Z <= 0 then return nil, false end
        return Vector2.new(sp.X, sp.Y), true
    end
    local function cross(o, a, b)
        return (a.X - o.X) * (b.Y - o.Y) - (a.Y - o.Y) * (b.X - o.X)
    end
    local function hull(pts)
        table.sort(pts, function(a, b)
            if a.X == b.X then return a.Y < b.Y end
            return a.X < b.X
        end)
        local lo = {}
        for _, p in ipairs(pts) do
            while #lo >= 2 and cross(lo[#lo - 1], lo[#lo], p) <= 0 do table.remove(lo) end
            lo[#lo + 1] = p
        end
        local up = {}
        for i = #pts, 1, -1 do
            local p = pts[i]
            while #up >= 2 and cross(up[#up - 1], up[#up], p) <= 0 do table.remove(up) end
            up[#up + 1] = p
        end
        table.remove(lo); table.remove(up)
        local out = {}
        for _, p in ipairs(lo) do out[#out + 1] = p end
        for _, p in ipairs(up) do out[#out + 1] = p end
        return out
    end
    RunService.RenderStepped:Connect(function()
        if not chOn then chHideAll(); return end
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head then chHideAll(); return end
        local cam = Workspace.CurrentCamera
        if not cam then chHideAll(); return end
        local base = Vector3.new(head.Position.X, head.Position.Y + head.Size.Y * 0.5 - DROP, head.Position.Z)
        local apex2d, ok = proj(base + Vector3.new(0, HEIGHT, 0))
        if not ok then chHideAll(); return end
        local pts = { apex2d }
        for i = 1, SEG do
            local a = (i - 1) / SEG * math.pi * 2
            local p, ok2 = proj(base + Vector3.new(math.cos(a) * RAD, 0, math.sin(a) * RAD))
            if not ok2 then chHideAll(); return end
            pts[#pts + 1] = p
        end
        local h = hull(pts)
        if #h < 3 then chHideAll(); return end
        local minY, maxY = math.huge, -math.huge
        for _, p in ipairs(h) do
            if p.Y < minY then minY = p.Y end
            if p.Y > maxY then maxY = p.Y end
        end
        minY = math.max(0, math.floor(minY))
        maxY = math.min(cam.ViewportSize.Y, math.ceil(maxY))
        if maxY - minY < 2 then chHideAll(); return end
        local span = math.max(1, maxY - minY)
        local step = math.max(1, math.ceil((maxY - minY) / MAX_ROWS))
        chEnsure(MAX_ROWS)
        local used = 0
        for y0 = minY, maxY - 1, step do
            local hh = math.min(step, maxY - y0)
            local y = y0 + hh * 0.5
            local left, right = math.huge, -math.huge
            local ax, ay = h[#h].X, h[#h].Y
            for i = 1, #h do
                local bx, by = h[i].X, h[i].Y
                if (ay <= y and by > y) or (by <= y and ay > y) then
                    local x = ax + (y - ay) * (bx - ax) / (by - ay)
                    if x < left then left = x end
                    if x > right then right = x end
                end
                ax, ay = bx, by
            end
            local w = right - left
            if w >= 2 then
                used = used + 1
                local t = (y - minY) / span
                local light = math.max(0, 1 - t * 1.35)
                local dark = math.max(0, (t - 0.58) / 0.42)
                local col = chCol:Lerp(Color3.new(1, 1, 1), light * 0.26):Lerp(Color3.new(0, 0, 0), dark * 0.12)
                local f = chRows[used]
                f.Position = UDim2.fromOffset(left, y0)
                f.Size = UDim2.fromOffset(w, hh)
                f.BackgroundColor3 = col
                f.Visible = true
            end
        end
        for i = used + 1, #chRows do
            if chRows[i].Visible then chRows[i].Visible = false end
        end
    end)
    addOpt(lvSec, "AddToggle", "ChinaHatOn", { Title = "Китайская шляпа", Default = false }, function(v) chOn = v end)
    addOpt(lvSec, "AddColorPicker", "ChinaHatCol", { Title = "Цвет", Default = Color3.fromRGB(170, 85, 255) }, function(c) chCol = c end)

    -- ====== LAND CIRCLE ======
    local lcOn, lcCol, lcTr, lcDur = false, Color3.new(1, 1, 1), 1, 0.82
    local lcConn
    local function lcHit(char, root)
        local prm = RaycastParams.new()
        prm.FilterType = Enum.RaycastFilterType.Exclude
        prm.FilterDescendantsInstances = { char }
        prm.IgnoreWater = true
        local hit = Workspace:Raycast(root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -16, 0), prm)
        if hit then return hit.Position, hit.Normal end
    end
    local function lcMake(p, n)
        local ref = math.abs(n.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
        local right = n:Cross(ref).Unit
        local front = right:Cross(n).Unit
        local pt = Instance.new("Part")
        pt.Anchored = true; pt.CanCollide = false; pt.CanQuery = false; pt.CanTouch = false; pt.CastShadow = false
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
        TweenService:Create(pt, info, { Size = Vector3.new(6.4, 0.01, 6.4) }):Play()
        TweenService:Create(img, info, { ImageTransparency = 1 }):Play()
        Debris:AddItem(pt, lcDur + 0.2)
    end
    local function lcBind()
        if lcConn then pcall(function() lcConn:Disconnect() end); lcConn = nil end
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
                local p, n = lcHit(char, root)
                if p and n then lcMake(p, n) end
            end
        end)
    end
    addOpt(lvSec, "AddToggle", "LandCircleOn", { Title = "Круг падения", Default = false }, function(v)
        lcOn = v
        if v then lcBind()
        elseif lcConn then pcall(function() lcConn:Disconnect() end); lcConn = nil end
    end)
    addOpt(lvSec, "AddColorPicker", "LandCircleCol", { Title = "Цвет", Default = Color3.new(1, 1, 1) }, function(c) lcCol = c end)
    addOpt(lvSec, "AddSlider", "LandCircleTr", { Title = "Прозрачность", Min = 0, Max = 1, Default = 1, Rounding = 2 }, function(v) lcTr = tonumber(v) or 1 end)
    addOpt(lvSec, "AddSlider", "LandCircleDur", { Title = "Длительность", Min = 0.1, Max = 3, Default = 0.82, Rounding = 2 }, function(v) lcDur = tonumber(v) or 0.82 end)

    -- ====== MOVEMENT GRAPH (ФИКС) ======
    local mgOn, mgCol = false, Color3.fromRGB(242, 242, 242)
    local mgWidth, mgHeight, mgOffset = 280, 72, 180
    local mgLines, mgShadows = {}, {}
    local mgCurrent = nil
    local mgHist, mgAccum, mgSmooth = {}, 0, 0
    local mgSpan, mgStep = 2.8, 1 / 45
    local mgConn = nil

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
    local function mgStart()
        mgClear()
        mgSmooth = mgSpeed()
        local now = os.clock()
        local cnt = math.ceil(mgSpan / mgStep)
        for i = 0, cnt do
            mgHist[#mgHist + 1] = { t = now - mgSpan + i * mgStep, v = mgSmooth }
        end
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
                mgHist[#mgHist + 1] = { t = now, v = mgSmooth }
                local cutoff = now - mgSpan
                while #mgHist > 2 and mgHist[2].t < cutoff do table.remove(mgHist, 1) end
            end
            local vp = Camera.ViewportSize
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
            end
            mgCurrent.Text = tostring(math.floor(mgSmooth + 0.5))
            mgCurrent.Position = Vector2.new(left + w + 5, center - 7)
            mgCurrent.Color = mgCol
            mgCurrent.Visible = true
        end)
    end
    addOpt(lvSec, "AddToggle", "MovGraphOn", { Title = "График скорости", Default = false }, function(v)
        mgOn = v
        if v then mgStart() else mgClear() end
    end)
    addOpt(lvSec, "AddColorPicker", "MovGraphCol", { Title = "Цвет", Default = Color3.fromRGB(242, 242, 242) }, function(c)
        mgCol = c
        for i = 1, #mgLines do mgLines[i].Color = c end
    end)
    addOpt(lvSec, "AddSlider", "MovGraphW", { Title = "Ширина", Min = 180, Max = 420, Default = 280, Rounding = 0 }, function(v) mgWidth = tonumber(v) or 280 end)
    addOpt(lvSec, "AddSlider", "MovGraphH", { Title = "Высота", Min = 40, Max = 120, Default = 72, Rounding = 0 }, function(v) mgHeight = tonumber(v) or 72 end)
    addOpt(lvSec, "AddSlider", "MovGraphY", { Title = "Смещение Y", Min = -200, Max = 400, Default = 180, Rounding = 0 }, function(v) mgOffset = tonumber(v) or 180 end)

    -- ====== CROSSHAIR ======
    local chOn2, chCol2 = false, Color3.new(1, 1, 1)
    local chLines = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 2
        l.Color = chCol2
        l.Visible = false
        chLines[i] = l
    end
    RunService.RenderStepped:Connect(function()
        if not chOn2 then
            for i = 1, #chLines do chLines[i].Visible = false end
            return
        end
        local mp = UserInputService:GetMouseLocation()
        local gap, len = 4, 8
        local cx, cy = mp.X, mp.Y
        local arr = {
            { cx, cy - gap, cx, cy - gap - len },
            { cx, cy + gap, cx, cy + gap + len },
            { cx - gap, cy, cx - gap - len, cy },
            { cx + gap, cy, cx + gap + len, cy },
        }
        for i = 1, 4 do
            local a = arr[i]
            chLines[i].From = Vector2.new(a[1], a[2])
            chLines[i].To = Vector2.new(a[3], a[4])
            chLines[i].Color = chCol2
            chLines[i].Visible = true
        end
    end)
    addOpt(lvSec, "AddToggle", "CrosshairOn", { Title = "Прицел", Default = false }, function(v)
        chOn2 = v
        pcall(function() UserInputService.MouseIconEnabled = not v end)
    end)
    addOpt(lvSec, "AddColorPicker", "CrosshairCol", { Title = "Цвет", Default = Color3.new(1, 1, 1) }, function(c) chCol2 = c end)
end

-- ============================================================
-- SKYBOX MANAGER (НОВЫЙ — toggle + dropdown, без ID)
-- ============================================================
do
    local skyboxEnabled = false
    local currentSkyName = nil
    local createdSky = nil
    local origSky, origSkyParent = nil, nil

    local SKY_PRESETS = {
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
        ["Snow"]      = { id = 4604073339 },
        ["Space"]     = { id = 136402262 },
        ["Asteroid"]  = { id = 295604372 },
    }
    local SKY_NAMES = { "Jungle", "Blossom", "Red night", "Purple", "Foggy", "Snow", "Space", "Asteroid" }

    local function clearSky()
        if createdSky then pcall(function() createdSky:Destroy() end); createdSky = nil end
    end
    local function backupOriginalSky()
        if not origSky then
            local existing = Lighting:FindFirstChildOfClass("Sky")
            if existing and existing ~= createdSky then
                origSky = existing
                origSkyParent = existing.Parent
                pcall(function() existing.Parent = nil end)
            end
        end
    end
    local function applySky(name)
        backupOriginalSky()
        clearSky()
        local preset = SKY_PRESETS[name]
        if not preset then return end
        if preset.id then
            task.spawn(function()
                local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(preset.id)) end)
                if not ok or type(objs) ~= "table" then
                    Notify("FH", "Не удалось загрузить: " .. name, 3)
                    return
                end
                local found
                for _, o in ipairs(objs) do
                    if o:IsA("Sky") then found = o; break end
                    local s = o:FindFirstChildWhichIsA("Sky", true)
                    if s then found = s; break end
                end
                if not found or not skyboxEnabled then return end
                clearSky()
                found.Name = "FH_CustomSky"
                found.Parent = Lighting
                createdSky = found
            end)
        else
            local sky = Instance.new("Sky")
            sky.Name = "FH_CustomSky"
            for k, v in pairs(preset) do pcall(function() sky[k] = v end) end
            sky.Parent = Lighting
            createdSky = sky
        end
    end
    local function restoreSky()
        clearSky()
        if origSky then
            pcall(function() origSky.Parent = origSkyParent or Lighting end)
            origSky, origSkyParent = nil, nil
        end
    end

    local skySec = Tabs.Visual:AddSection({ Name = "Skybox Manager" })
    addOpt(skySec, "AddToggle", "SkyboxToggleOn", { Title = "Включить Skybox", Default = false }, function(v)
        skyboxEnabled = v
        if v then
            applySky(currentSkyName or "Jungle")
        else
            restoreSky()
            Notify("FH", "Skybox выключен", 2)
        end
    end)
    addOpt(skySec, "AddDropdown", "SkyboxPick", { Title = "Выбрать небо", Values = SKY_NAMES, Default = "Jungle" }, function(v)
        currentSkyName = v
        if skyboxEnabled then
            applySky(v)
            Notify("FH", "Skybox: " .. tostring(v), 2)
        end
    end)
    currentSkyName = "Jungle"
end

-- ============================================================
-- AURA 2.0 (по принципу Backtrack v2 — модель-клон с анимациями)
-- ============================================================
do
    local aura2On = false
    local aura2Color = Color3.fromRGB(255, 100, 220)
    local aura2Transparency = 0.5
    local aura2Model = nil
    local aura2Pairs = {}
    local aura2Hist = {}
    local aura2LastChar = nil
    local aura2UpdateConn = nil

    local A2_FOLDER = Workspace:FindFirstChild("FH_Aura2Folder")
    if not A2_FOLDER then
        A2_FOLDER = Instance.new("Folder")
        A2_FOLDER.Name = "FH_Aura2Folder"
        A2_FOLDER.Parent = Workspace
    end

    local function aura2Cleanup()
        if aura2Model then pcall(function() aura2Model:Destroy() end) end
        aura2Model = nil
        aura2Pairs = {}
        aura2Hist = {}
        aura2LastChar = nil
    end
    local function aura2Paint()
        if not aura2Model then return end
        for _, pair in ipairs(aura2Pairs) do
            local g = pair.ghost
            pcall(function()
                if g:IsA("BasePart") then
                    g.Transparency = aura2Transparency
                    g.Material = Enum.Material.Neon
                    g.Color = aura2Color
                    g.CanCollide = false
                    g.CanQuery = false
                    g.CanTouch = false
                    g.Anchored = true
                end
            end)
        end
    end
    local function aura2Build(char)
        aura2Cleanup()
        aura2LastChar = char
        char.Archivable = true
        local ok, clone = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not clone then return end
        aura2Model = clone
        aura2Model.Name = "FH_Aura2Model"
        aura2Model.Parent = A2_FOLDER
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
        local hrp = clone:FindFirstChild("HumanoidRootPart")
        if hrp then hrp:Destroy() end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
                d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanQuery = false
                d.CanTouch = false
                d.Massless = true
            end
        end
        aura2Pairs = {}
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                local g = nil
                if d.Parent == char then
                    g = clone:FindFirstChild(d.Name)
                elseif d.Parent and d.Parent:IsA("Accessory") then
                    local acc = clone:FindFirstChild(d.Parent.Name)
                    if acc then g = acc:FindFirstChild(d.Name) end
                end
                if g and g:IsA("BasePart") then
                    table.insert(aura2Pairs, { real = d, ghost = g })
                end
            end
        end
        aura2Paint()
    end
    RunService.RenderStepped:Connect(function()
        if not aura2On then
            if aura2Model then aura2Cleanup() end
            return
        end
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            if aura2Model then aura2Cleanup() end
            return
        end
        if aura2LastChar ~= char then aura2Build(char) end
        if not aura2Model or aura2Model.Parent ~= A2_FOLDER then return end
        local snap = { t = tick(), parts = {} }
        for _, pair in ipairs(aura2Pairs) do
            snap.parts[pair.real] = pair.real.CFrame
        end
        table.insert(aura2Hist, snap)
        local cutoff = tick() - 2
        while #aura2Hist > 0 and aura2Hist[1].t < cutoff do
            table.remove(aura2Hist, 1)
        end
        local ping = 0
        pcall(function()
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        local wantTime = tick() - math.clamp((ping / 1000) + 0.05, 0.03, 0.4)
        local chosen = nil
        for i = #aura2Hist, 1, -1 do
            if aura2Hist[i].t <= wantTime then chosen = aura2Hist[i]; break end
        end
        if not chosen and #aura2Hist > 0 then chosen = aura2Hist[1] end
        if chosen then
            for _, pair in ipairs(aura2Pairs) do
                if chosen.parts[pair.real] then
                    pair.ghost.CFrame = chosen.parts[pair.real]
                end
            end
        end
    end)

    local auraSec = Tabs.Effects:AddSection({ Name = "Aura 2.0" })
    addOpt(auraSec, "AddToggle", "FH_AuraV2On", { Title = "Включить Aura 2.0", Default = false }, function(v)
        aura2On = v
        if not v then
            aura2Cleanup()
            Notify("FH", "Aura 2.0 ВЫКЛ", 2)
        else
            Notify("FH", "Aura 2.0 ВКЛ", 2)
        end
    end)
    addOpt(auraSec, "AddColorPicker", "FH_AuraV2Col", { Title = "Цвет", Default = Color3.fromRGB(255, 100, 220) }, function(c)
        aura2Color = c
        aura2Paint()
    end)
    addOpt(auraSec, "AddSlider", "FH_AuraV2Alpha", { Title = "Прозрачность", Min = 0, Max = 1, Default = 0.5, Rounding = 2 }, function(v)
        aura2Transparency = tonumber(v) or 0.5
        aura2Paint()
    end)
end

-- ============================================================
-- AVATAR CACHE (для ESP)
-- ============================================================
do
    getgenv().FH_CustomAvatarsEnabled = true
    local avatarUrls = {
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/1.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/2.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/3.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/4.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/5.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/6.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/7.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/8.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/9.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/10.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/11.png",
        "https://raw.githubusercontent.com/Royal-Script-hub/mimka/main/ava/12.png",
    }
    local avatarCache = {}
    local userToUrl = {}
    local folder = "FortniHub_Configs/avatars"
    if type(makefolder) == "function" and type(isfolder) == "function" then
        if not isfolder(folder) then pcall(makefolder, folder) end
    end
    local function resolveLocal(url, idx)
        if avatarCache[url] then return avatarCache[url] end
        if type(getcustomasset) ~= "function" or type(writefile) ~= "function" then
            return url
        end
        local path = folder .. "/avatar_" .. tostring(idx or 1) .. ".png"
        if type(isfile) == "function" and not isfile(path) then
            local ok, data = pcall(function() return game:HttpGet(url) end)
            if ok and type(data) == "string" and #data > 0 then
                pcall(writefile, path, data)
            end
        end
        local okA, asset = pcall(getcustomasset, path)
        if okA and asset then
            avatarCache[url] = asset
            return asset
        end
        return url
    end
    local function getAvatarFor(player)
        if not player then
            return resolveLocal(avatarUrls[math.random(1, #avatarUrls)], math.random(1, #avatarUrls))
        end
        if userToUrl[player.UserId] then
            local idx = nil
            for i, u in ipairs(avatarUrls) do
                if u == userToUrl[player.UserId] then idx = i; break end
            end
            return resolveLocal(userToUrl[player.UserId], idx)
        end
        local used = {}
        for _, u in pairs(userToUrl) do used[u] = true end
        local pool = {}
        for _, u in ipairs(avatarUrls) do
            if not used[u] then table.insert(pool, u) end
        end
        local pick = pool[math.random(1, #pool)] or avatarUrls[math.random(1, #avatarUrls)]
        userToUrl[player.UserId] = pick
        local idx = nil
        for i, u in ipairs(avatarUrls) do if u == pick then idx = i; break end end
        return resolveLocal(pick, idx)
    end
    getgenv().FH_GetAvatarFor = getAvatarFor
end

pcall(function() Window:SelectTab(1) end)
print("[FH] ============================================")
print("[FH] Part 2/3 — Movement, Binds, Settings (FIXED configs)")
print("[FH] ESP, Skybox Manager (new), Aura 2.0 (bt-style), MovGraph fix")
print("[FH] ============================================")
-- ============================================================
-- ЧАСТЬ 3/3 — Effects, Emotes(FIX), Utilities, Troll, Farm, Final
-- ============================================================

-- ============================================================
-- ЭФФЕКТЫ (Tracer, World FX, Murder Death FX)
-- ============================================================
do
    local tE = Tabs.Effects

    -- ====== TRACER ======
    local tracerSec = tE:AddSection({ Name = "Трассер пули" })
    local tracerOn, tracerCol, tracerDur = false, Color3.fromRGB(133, 220, 255), 1
    local tracerTrackBullet = true
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
                TweenService:Create(beam, TweenInfo.new(0.2), { Width0 = 0, Width1 = 0 }):Play()
            end
        end)
    end
    local function createGunTracer()
        local c = LocalPlayer.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local att = hrp:FindFirstChild("GunRaycastAttachment")
        local origin = att and att.WorldPosition or hrp.Position
        local dir = Camera.CFrame.LookVector * 8
        createTracer(origin, origin + dir)
    end
    local tracerConn
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
            if tracerTrackBullet then createTracer(sv, ev) else createGunTracer() end
        end)
    end
    addOpt(tracerSec, "AddToggle", "TracerOn", { Title = "Включить трассер", Default = false }, function(v)
        tracerOn = v
        if v then connectTracer() end
    end)
    addOpt(tracerSec, "AddToggle", "TracerTrackBullet", { Title = "Отслеживание пуль", Default = true }, function(v) tracerTrackBullet = v end)
    addOpt(tracerSec, "AddColorPicker", "TracerCol", { Title = "Цвет", Default = Color3.fromRGB(133, 220, 255) }, function(c) tracerCol = c end)
    addOpt(tracerSec, "AddSlider", "TracerDur", { Title = "Длительность", Min = 0.1, Max = 5, Default = 1, Rounding = 1 }, function(v) tracerDur = tonumber(v) or 1 end)

    -- ====== WORLD FX (Snow / Sakura) ======
    local fxSec = tE:AddSection({ Name = "Эффекты мира" })
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
        if fxConn then pcall(function() fxConn:Disconnect() end); fxConn = nil end
        if fxPart then pcall(function() fxPart:Destroy() end); fxPart = nil end
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
            if flat.Magnitude < 0.05 then
                flat = Vector3.new(0, 0, -1)
            else
                flat = flat.Unit
            end
            fxPart.CFrame = CFrame.new(cf.Position + flat * 57 + Vector3.new(0, 44, 0))
        end)
    end
    addOpt(fxSec, "AddToggle", "FXOn", { Title = "Включить эффекты", Default = false }, function(v)
        fxOn = v
        if v then startFX() else stopFX() end
    end)
    addOpt(fxSec, "AddDropdown", "FXType", { Title = "Тип", Values = { "Снег", "Сакура" }, Default = "Снег" }, function(v)
        fxType = (v == "Сакура") and "Sakura" or "Snow"
        if fxOn then styleFX() end
    end)
    addOpt(fxSec, "AddColorPicker", "FXCol", { Title = "Цвет", Default = Color3.fromRGB(150, 200, 255) }, function(c)
        fxCol = c
        if fxEmit then fxEmit.Color = ColorSequence.new(c) end
    end)
    addOpt(fxSec, "AddSlider", "FXRate", { Title = "Интенсивность", Min = 20, Max = 900, Default = 250, Rounding = 1 }, function(v)
        fxRate = tonumber(v) or 250
        if fxEmit then styleFX() end
    end)

    -- ====== WORLD (Lighting) ======
    local wSec = tE:AddSection({ Name = "Мир" })
    local orig = {
        Amb = Lighting.Ambient, Br = Lighting.Brightness, CT = Lighting.ClockTime,
        CSB = Lighting.ColorShift_Bottom, CST = Lighting.ColorShift_Top,
        Exp = Lighting.ExposureCompensation,
        FC = Lighting.FogColor, FS = Lighting.FogStart, FE = Lighting.FogEnd,
        OA = Lighting.OutdoorAmbient, GS = Lighting.GlobalShadows,
    }
    addOpt(wSec, "AddToggle", "FBOn", { Title = "Fullbright", Default = false }, function(v)
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            Lighting.FogEnd = 100000
        else
            Lighting.Brightness = orig.Br
            Lighting.ClockTime = orig.CT
            Lighting.GlobalShadows = orig.GS
            Lighting.OutdoorAmbient = orig.OA
            Lighting.FogEnd = orig.FE
        end
    end)
    local timeOn, timeVal = false, 12
    addOpt(wSec, "AddToggle", "TimeOn", { Title = "Своё время", Default = false }, function(v)
        timeOn = v
        Lighting.ClockTime = v and timeVal or orig.CT
    end)
    addOpt(wSec, "AddSlider", "TimeVal", { Title = "Час", Min = 0, Max = 24, Default = 12, Rounding = 0 }, function(v)
        timeVal = tonumber(v) or 12
        if timeOn then Lighting.ClockTime = timeVal end
    end)
    local expOn, expVal = false, 0
    addOpt(wSec, "AddToggle", "ExpOn", { Title = "Экспозиция", Default = false }, function(v)
        expOn = v
        Lighting.ExposureCompensation = v and expVal or orig.Exp
    end)
    addOpt(wSec, "AddSlider", "ExpVal", { Title = "Значение", Min = -5, Max = 5, Default = 0, Rounding = 2 }, function(v)
        expVal = tonumber(v) or 0
        if expOn then Lighting.ExposureCompensation = expVal end
    end)
    local fogOn, fogCol, fogStart, fogEnd = false, Color3.fromRGB(192, 192, 192), 0, 1000
    addOpt(wSec, "AddToggle", "FogOn", { Title = "Свой туман", Default = false }, function(v)
        fogOn = v
        if v then
            Lighting.FogColor = fogCol
            Lighting.FogStart = fogStart
            Lighting.FogEnd = fogEnd
        else
            Lighting.FogColor = orig.FC
            Lighting.FogStart = orig.FS
            Lighting.FogEnd = orig.FE
        end
    end)
    addOpt(wSec, "AddColorPicker", "FogCol", { Title = "Цвет тумана", Default = Color3.fromRGB(192, 192, 192) }, function(c)
        fogCol = c
        if fogOn then Lighting.FogColor = c end
    end)
    addOpt(wSec, "AddSlider", "FogStart", { Title = "Начало", Min = 0, Max = 1000, Default = 0, Rounding = 0 }, function(v)
        fogStart = tonumber(v) or 0
        if fogOn then Lighting.FogStart = fogStart end
    end)
    addOpt(wSec, "AddSlider", "FogEnd", { Title = "Конец", Min = 0, Max = 1000, Default = 1000, Rounding = 0 }, function(v)
        fogEnd = tonumber(v) or 1000
        if fogOn then Lighting.FogEnd = fogEnd end
    end)
    local ambOn, ambCol = false, Color3.fromRGB(128, 128, 128)
    addOpt(wSec, "AddToggle", "AmbOn", { Title = "Свой ambient", Default = false }, function(v)
        ambOn = v
        if v then
            Lighting.Ambient = ambCol
            Lighting.OutdoorAmbient = ambCol
        else
            Lighting.Ambient = orig.Amb
            Lighting.OutdoorAmbient = orig.OA
        end
    end)
    addOpt(wSec, "AddColorPicker", "AmbCol", { Title = "Цвет ambient", Default = Color3.fromRGB(128, 128, 128) }, function(c)
        ambCol = c
        if ambOn then
            Lighting.Ambient = c
            Lighting.OutdoorAmbient = c
        end
    end)
    getgenv().EFFECTS_UNLOAD = function()
        tracerOn = false
        if tracerConn then pcall(function() tracerConn:Disconnect() end) end
        stopFX()
        Lighting.Ambient = orig.Amb
        Lighting.Brightness = orig.Br
        Lighting.ClockTime = orig.CT
        Lighting.ColorShift_Bottom = orig.CSB
        Lighting.ColorShift_Top = orig.CST
        Lighting.ExposureCompensation = orig.Exp
        Lighting.FogColor = orig.FC
        Lighting.FogStart = orig.FS
        Lighting.FogEnd = orig.FE
        Lighting.OutdoorAmbient = orig.OA
        Lighting.GlobalShadows = orig.GS
    end

    -- ====== MURDER DEATH FX ======
    local meSec = tE:AddSection({ Name = "Смерть убийцы" })
    local mOn, mCloneOn, mPartOn = false, false, false
    local mCloneCol = Color3.fromRGB(255, 0, 0)
    local mPartCol = Color3.fromRGB(255, 0, 0)
    local mCloneDur = 3
    local mClones, mConns, mRoles = {}, {}, {}
    local mThread = nil
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
    local function spawnEmitter(char, tint, dur)
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
        local rec = { part = root, balls = {} }
        mActive[#mActive + 1] = rec
        local rnd = srand
        for _, s in ipairs(bodyParts) do
            local count = s.Name == "Head" and 12 or 8
            for i = 1, count do
                local dia = 0.12 + rnd() * 0.05
                local pos = s.Position + Vector3.new(
                    (rnd() - 0.5) * s.Size.X,
                    (rnd() - 0.5) * s.Size.Y,
                    (rnd() - 0.5) * s.Size.Z
                )
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
                ball.Transparency = 1
                ball.Parent = root
                rec.balls[#rec.balls + 1] = ball
                local tgt = Vector3.new(dia, dia, dia)
                task.delay(0.1 + rnd() * 0.2, function()
                    if ball.Parent then
                        TweenService:Create(ball, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { Size = tgt, Transparency = 0.05 }):Play()
                    end
                end)
                task.delay(dur * 0.6, function()
                    if ball.Parent then
                        TweenService:Create(ball, TweenInfo.new(dur * 0.4, Enum.EasingStyle.Sine), { Size = tgt * 0.5, Transparency = 1 }):Play()
                    end
                end)
            end
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
                if d.Name == "HumanoidRootPart" then
                    d.Transparency = 1
                else
                    d.Material = Enum.Material.ForceField
                    d.Color = mCloneCol
                end
            elseif d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript")
                or d:IsA("Sound") or d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter")
                or d:IsA("Trail") or d:IsA("Beam") or d:IsA("PointLight") or d:IsA("SpotLight")
                or d:IsA("SurfaceLight") or d:IsA("Highlight") then
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
                    TweenService:Create(d, TweenInfo.new(1.5), { Transparency = 1 }):Play()
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
        if mPartOn then spawnEmitter(char, mPartCol, 1.2) end
    end
    local function hookPlayer(pl)
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            mConns[#mConns + 1] = hum.Died:Connect(function()
                if mOn and mRoles[pl.Name] == "Murderer" then onMurderDeath(char) end
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
        for _, c in ipairs(mClones) do pcall(function() c:Destroy() end) end
        mClones = {}
    end
    addOpt(meSec, "AddToggle", "MEOn", { Title = "Включить эффект", Default = false }, function(v)
        mOn = v
        if v then
            mThread = task.spawn(function()
                while mOn do
                    pcall(function()
                        local data = getRoundData()
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
            Players.PlayerAdded:Connect(function(pl)
                if pl ~= LocalPlayer then hookPlayer(pl) end
            end)
        else
            stopMurder()
            if mThread then pcall(function() task.cancel(mThread) end); mThread = nil end
        end
    end)
    addOpt(meSec, "AddToggle", "MEClone", { Title = "Клон", Default = false }, function(v) mCloneOn = v end)
    addOpt(meSec, "AddColorPicker", "MECloneCol", { Title = "Цвет клона", Default = Color3.fromRGB(255, 0, 0) }, function(c) mCloneCol = c end)
    addOpt(meSec, "AddSlider", "MECloneDur", { Title = "Длительность клона", Min = 1, Max = 5, Default = 3, Rounding = 1 }, function(v) mCloneDur = tonumber(v) or 3 end)
    addOpt(meSec, "AddToggle", "MEPart", { Title = "Частицы", Default = false }, function(v) mPartOn = v end)
    addOpt(meSec, "AddColorPicker", "MEPartCol", { Title = "Цвет частиц", Default = Color3.fromRGB(255, 0, 0) }, function(c)
        mPartCol = c
        for i = 1, #mActive do
            local e = mActive[i]
            if e then
                for _, b in ipairs(e.balls) do
                    if b.Parent then b.Color = c end
                end
            end
        end
    end)
    getgenv().MURDER_UNLOAD = function()
        mOn = false
        stopMurder()
        if mThread then pcall(function() task.cancel(mThread) end); mThread = nil end
    end
end

-- ============================================================
-- ЭМОЦИИ (ФИКС через Animator) + FAVORITES
-- ============================================================
do
    local emoteTab = Tabs.Animations
    local emoteSec = emoteTab:AddSection({ Name = "Эмоции (расширенные)" })

    local EMOTE_LIST = {
        ["Around Town"] = 3576747102, ["Fashionable"] = 3576745472, ["Swish"] = 3821527813,
        ["Top Rock"] = 3570535774, ["Fancy Feet"] = 3934988903, ["Idol"] = 4102317848,
        ["Sneaky"] = 3576754235, ["Robot"] = 3576721660, ["Louder"] = 3576751796,
        ["Twirl"] = 3716633898, ["Bodybuilder"] = 3994130516, ["Jacks"] = 3570649048,
        ["Shuffle"] = 4391208058, ["Dorky Dance"] = 4212499637, ["Dizzy"] = 3934986896,
        ["T"] = 3576719440, ["Air Dance"] = 4646302011, ["TMNT Dance"] = 18665886405,
        ["Line Dance"] = 4049646104, ["Break Dance"] = 5915773992, ["Zombie"] = 4212496830,
        ["Baby Dance"] = 4272484885, ["Cha Cha"] = 6865013133, ["Dolphin Dance"] = 5938365243,
        ["Y"] = 4391211308, ["Wanna play?"] = 16646438742, ["Samba"] = 6869813008,
        ["Side to Side"] = 3762641826, ["Tree"] = 4049634387, ["Godlike"] = 3823158750,
        ["Keeping Time"] = 4646306072, ["Tantrum"] = 5104374556, ["Rock On"] = 5915782672,
        ["Hero Landing"] = 5104377791, ["Fishing"] = 3994129128, ["Floss Dance"] = 5917570207,
        ["Get Out"] = 3934984583, ["Victory Dance"] = 15506503658, ["Monkey"] = 3716636630,
        ["Greatest"] = 3762654854, ["Jumping Wave"] = 4940602656, ["Haha"] = 4102315500,
        ["Agree"] = 4849487550, ["Mini Kong"] = 17000058939, ["Festive Dance"] = 15679955281,
        ["Jumping Cheer"] = 5895009708, ["Sleep"] = 4689362868, ["Disagree"] = 4849495710,
        ["Happy"] = 4849499887, ["Bored"] = 5230661597, ["High Wave"] = 5915776835,
        ["Cower"] = 4940597758, ["Rock n Roll"] = 15506496093, ["Shy"] = 3576717965,
        ["Curtsy"] = 4646306583, ["Celebrate"] = 3994127840, ["Confused"] = 4940592718,
        ["Beckon"] = 5230615437, ["Sad"] = 4849502101, ["Cha-Cha"] = 3696764866,
        ["Chicken Dance"] = 4849493309, ["Sandwich Dance"] = 4390121879, ["Salute"] = 3360689775,
        ["Stadium"] = 3360686498, ["Bunny Hop"] = 4646296016, ["Swag Walk"] = 10478377385,
        ["Superhero Reveal"] = 3696759798, ["Hype Dance"] = 3696757129, ["Heisman Pose"] = 3696763549,
        ["Point2"] = 3576823880, ["Vroom Vroom"] = 18526410572, ["Tilt"] = 3360692915,
        ["Applaud"] = 5915779043, ["Hello"] = 3576686446, ["Vans Ollie"] = 18305539673,
        ["Shrug"] = 3576968026, ["Wally West"] = 133948663586698, ["Take The L"] = 123159156696507,
        ["Belly Dancing"] = 131939729732240, ["CaramellDansen"] = 93105950995997,
        ["Rambunctious"] = 134311528115559, ["Ballin"] = 96293409369770,
        ["Nyan Nyan!"] = 73796726960568, ["Skibidi"] = 124828909173982,
        ["Chronoshift"] = 92600655160976, ["Floating on Clouds"] = 111426928948833,
        ["Jersey Joe"] = 134149640725489, ["Virtual Insanity"] = 83261816934732,
        ["Doodle Dance"] = 107091254142209, ["Club Penguin"] = 98099211500155,
        ["Kazotsky"] = 97629500912487, ["Miku Dance"] = 117734400993750,
        ["Gangnam Style"] = 77205409178702, ["Push-Up"] = 117922227854118,
        ["Split"] = 98522218962476, ["PROXIMA"] = 81390693780805,
        ["HeadBanging"] = 87447252507832, ["Assumptions"] = 127507691649322,
        ["Jumpstyle"] = 99563839802389, ["Flopping Fish"] = 133142324349281,
        ["Fancy Feets"] = 124512151372711, ["Absolute Cinema"] = 97258018304125,
        ["Griddy"] = 116065653184749, ["Paranoid"] = 123407922818447,
        ["Kawaii Groove"] = 77152953688098, ["Smeeze"] = 131683926643291,
        ["Onion"] = 113890289455724, ["Thinking"] = 124584711308900,
        ["Slenderman"] = 81926508907412, ["Macarena"] = 91274761264433,
        ["RONALDO"] = 97547486465713, ["Slickback"] = 103789826265487,
        ["Default Dance"] = 80877772569772, ["Family Guy"] = 78459263478161,
        ["SpongeBob Shuffle"] = 107899954696611, ["Electro Shuffle"] = 96426537876059,
        ["Foreign Shuffle"] = 101507732056031, ["Caipirinha"] = 100165303717371,
        ["Squidward Yell"] = 109244554368414, ["Teto Dance"] = 93031502567721,
        ["Michael Myers"] = 88229016850146, ["Torture Dance"] = 116099356619436,
        ["Mewing / Mogging"] = 135493514352956, ["Cute Jump"] = 80556794144838,
        ["Billy Bounce"] = 126516908191316, ["Dio Pose"] = 76736978166708,
        ["Golden Freddy"] = 122463450997235, ["Lethal Dance"] = 77108921633993,
        ["Plug Walk"] = 100359724990859, ["At Ease"] = 76993139936388,
        ["Conga"] = 97547955535086, ["Barrel"] = 84511772437190,
        ["Helicopter"] = 84555218084038, ["Jersey Joe2"] = 115782117564871,
        ["California Girl"] = 132074413582912, ["Shocked meme"] = 129501229484294,
        ["Car Transformation"] = 96887377943085, ["Insanity"] = 129843344424281,
        ["Honored One"] = 121643381580730, ["Sukuna"] = 91839607010745,
        ["Dropper"] = 130358790702800, ["Be Not Afraid"] = 70635223083942,
        ["Helicopter2"] = 119431985170060, ["Nya Anime Dance"] = 126647057611522,
        ["Do that thang"] = 113773829398170, ["Squat?"] = 95441477641149,
    }

    local emoteNames = {}
    for name in pairs(EMOTE_LIST) do emoteNames[#emoteNames + 1] = name end
    table.sort(emoteNames, function(a, b) return a:lower() < b:lower() end)

    local drop = emoteSec:AddDropdown("FHBigEmotePick", {
        Title = "Выбрать эмоцию",
        Values = emoteNames,
        Default = emoteNames[1] or "Default Dance",
    })

    local currentTrack = nil
    local currentName = nil

    -- ФИКС: получаем Animator и через него играем анимацию
    local function getAnimator(char)
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        return animator
    end

    local function stopCurrent()
        if currentTrack then
            pcall(function() currentTrack:Stop() end)
            currentTrack = nil
        end
        currentName = nil
    end

    local function playEmoteByName(name)
        local id = EMOTE_LIST[name]
        if not id then return end
        local c = LocalPlayer.Character
        if not c then
            Notify("FH", "Персонаж не загружен", 2)
            return
        end
        local animator = getAnimator(c)
        if not animator then
            Notify("FH", "Animator не найден", 2)
            return
        end
        stopCurrent()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. tostring(id)
        local ok, track = pcall(function()
            return animator:LoadAnimation(anim)
        end)
        anim:Destroy()
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            pcall(function() track:Play(0) end)
            currentTrack = track
            currentName = name
            Notify("FH", "Эмоция: " .. name, 2)
        else
            Notify("FH", "Не удалось запустить: " .. name, 2)
        end
    end

    emoteSec:AddButton({ Title = "Запустить эмоцию", Callback = function()
        local v = drop.Value
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" then playEmoteByName(v) end
    end })
    emoteSec:AddButton({ Title = "Остановить эмоцию", Callback = function()
        stopCurrent()
        Notify("FH", "Эмоция остановлена", 2)
    end })

    -- Избранное
    local favorites = {}
    local favFile = "FortniHub_Configs/emote_favorites.txt"
    local function saveFav()
        if type(writefile) ~= "function" then return end
        local lines = {}
        for k in pairs(favorites) do lines[#lines + 1] = k end
        pcall(writefile, favFile, table.concat(lines, "\n"))
    end
    local function loadFav()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
        if not pcall(isfile, favFile) then return end
        local ok, data = pcall(readfile, favFile)
        if not ok or type(data) ~= "string" then return end
        for line in data:gmatch("[^\r\n]+") do
            if line ~= "" then favorites[line] = true end
        end
    end
    loadFav()
    emoteSec:AddButton({ Title = "Добавить/убрать из избранного", Callback = function()
        local v = drop.Value
        if type(v) == "table" then v = v[1] end
        if type(v) ~= "string" or v == "" then return end
        favorites[v] = not favorites[v] or nil
        saveFav()
        Notify("FH", favorites[v] and ("Добавлено: " .. v) or ("Удалено: " .. v), 2)
    end })
    emoteSec:AddButton({ Title = "Показать избранное", Callback = function()
        local list = {}
        for k in pairs(favorites) do list[#list + 1] = k end
        if #list == 0 then
            Notify("FH", "Избранное пусто", 2)
        else
            table.sort(list)
            pcall(function() drop:SetValues(list); drop:Generate() end)
            Notify("FH", "Показано " .. #list .. " избранных", 2)
        end
    end })
    emoteSec:AddButton({ Title = "Показать все эмоции", Callback = function()
        pcall(function() drop:SetValues(emoteNames); drop:Generate() end)
    end })
end

-- ============================================================
-- УТИЛИТЫ (Invis, Anti, UI Sounds, KITI Sounds)
-- ============================================================
do
    local tU = Tabs.Utility

    -- ====== NOTIFY ======
    local notifySec = tU:AddSection({ Name = "Уведомления" })
    local notifyOn, rolesOn = false, false
    local lastRole = nil
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
                elseif not r then
                    lastRole = nil
                end
            end
        end
    end)
    addOpt(notifySec, "AddToggle", "NotifyOn", { Title = "Включить", Default = false }, function(v) notifyOn = v end)
    addOpt(notifySec, "AddToggle", "NotifyRoles", { Title = "Показывать роль", Default = false }, function(v) rolesOn = v end)

    -- ====== INVIS ======
    local invisSec = tU:AddSection({ Name = "Невидимость" })
    local invis = { active = false, realCF = nil, hbConn = nil, bindName = "FH_InvisClient", savedLTM = {}, savedDecals = {}, savedFallenHeight = nil }
    local HIDDEN_CF = CFrame.new(0, -50000, 0)
    getgenv().FH_INVIS_ACTIVE = false
    local function invisRestoreParts()
        local char = LocalPlayer.Character
        if char then
            for p, v in pairs(invis.savedLTM) do
                if p and p.Parent then pcall(function() p.LocalTransparencyModifier = v end) end
            end
            for d, v in pairs(invis.savedDecals) do
                if d and d.Parent then pcall(function() d.Transparency = v end) end
            end
        end
        invis.savedLTM = {}
        invis.savedDecals = {}
    end
    local function invisBegin()
        if invis.active then return end
        local char = LocalPlayer.Character
        if not char then Notify("FH", "Персонаж не загружен", 2); return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then Notify("FH", "Персонаж не загружен", 2); return end
        invis.savedLTM = {}
        invis.savedDecals = {}
        invis.realCF = hrp.CFrame
        invis.active = true
        getgenv().FH_INVIS_ACTIVE = true
        invis.savedFallenHeight = Workspace.FallenPartsDestroyHeight
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
        if invis.hbConn then
            pcall(function() invis.hbConn:Disconnect() end)
            invis.hbConn = nil
        end
        pcall(function() RunService:UnbindFromRenderStep(invis.bindName) end)
        if hrp and finalCF then
            pcall(function()
                hrp.CFrame = finalCF
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        invisRestoreParts()
        if invis.savedFallenHeight ~= nil then
            pcall(function() Workspace.FallenPartsDestroyHeight = invis.savedFallenHeight end)
            invis.savedFallenHeight = nil
        end
        invis.realCF = nil
        Notify("FH", "Невидимость ВЫКЛ", 2)
    end
    addOpt(invisSec, "AddToggle", "InvisOn", { Title = "Включить невидимость", Default = false }, function(v)
        if v then invisBegin() else invisEnd() end
    end)
    getgenv().INVIS_UNLOAD = function()
        if invis.active then invisEnd() end
    end

    -- ====== UI SOUNDS (ФИКС) ======
    local UISoundIds = {
        ["Enable 1"] = "rbxassetid://100772509583336",
        ["Sparkle"] = "rbxassetid://110241936966089",
        ["Laser Click"] = "rbxassetid://18913006341",
        ["Enable 2"] = "rbxassetid://84626036868067",
        ["Notify"] = "rbxassetid://103421304020039",
    }
    local UISndCfg = {
        Enabled = true,
        EnableSound = "Enable 1",
        DisableSound = "Enable 1",
        Volume = 0.8,
    }
    getgenv().FH_UISoundCfg = UISndCfg

    local function playSnd(id, vol)
        if not UISndCfg.Enabled then return end
        if not id then return end
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = vol or UISndCfg.Volume
            s.Parent = SoundService
            s:Play()
            task.delay(5, function()
                pcall(function() s:Destroy() end)
            end)
        end)
    end
    local function playEnable()
        playSnd(UISoundIds[UISndCfg.EnableSound])
    end
    local function playDisable()
        playSnd(UISoundIds[UISndCfg.DisableSound])
    end
    getgenv().FH_PlayUISound = playSnd
    getgenv().FH_PlayEnable = playEnable
    getgenv().FH_PlayDisable = playDisable

    local sndSec = tU:AddSection({ Name = "UI Sounds" })
    addOpt(sndSec, "AddToggle", "FH_UISoundsOn", { Title = "Звуки интерфейса", Default = true }, function(v)
        UISndCfg.Enabled = v
        if v then playEnable() end
    end)
    addOpt(sndSec, "AddDropdown", "FH_UISoundEnable", { Title = "Звук включения", Values = { "Enable 1", "Sparkle", "Laser Click", "Enable 2", "Notify" }, Default = "Enable 1" }, function(v)
        UISndCfg.EnableSound = v or "Enable 1"
        playSnd(UISoundIds[UISndCfg.EnableSound])
    end)
    addOpt(sndSec, "AddDropdown", "FH_UISoundDisable", { Title = "Звук выключения", Values = { "Enable 1", "Sparkle", "Laser Click", "Enable 2", "Notify" }, Default = "Enable 1" }, function(v)
        UISndCfg.DisableSound = v or "Enable 1"
        playSnd(UISoundIds[UISndCfg.DisableSound])
    end)
    addOpt(sndSec, "AddSlider", "FH_UISoundsVolume", { Title = "Громкость", Min = 0.1, Max = 3, Default = 0.8, Rounding = 1 }, function(v)
        UISndCfg.Volume = tonumber(v) or 0.8
    end)
    sndSec:AddButton({ Title = "Проверить звук включения", Callback = function() playEnable() end })
    sndSec:AddButton({ Title = "Проверить звук выключения", Callback = function() playDisable() end })

    -- Подключаем звук на переключение некоторых тогглов
    local UI_SOUND_TRIGGER_OPTS = {
        "ESPOn", "TracerOn", "KAOn", "SilentEnabled", "InvisOn",
        "FH_AuraV2On", "BacktrackOn", "FHGhostOn", "ToolFling",
        "SkyboxToggleOn", "MovGraphOn", "CrosshairOn",
    }
    for _, optName in ipairs(UI_SOUND_TRIGGER_OPTS) do
        task.spawn(function()
            local opt = Options[optName]
            if opt and opt.OnChanged then
                pcall(function()
                    opt:OnChanged(function(v)
                        if v then playEnable() else playDisable() end
                    end)
                end)
            end
        end)
    end

    -- ====== KITI SOUNDS (замена Game Sounds — отсюда) ======
    local KITI_BASES = {
        "https://cdn.jsdelivr.net/gh/khenn791/lmao@main/",
        "https://raw.githack.com/khenn791/lmao/main/",
        "https://github.com/khenn791/lmao/raw/refs/heads/main/",
        "https://raw.githubusercontent.com/khenn791/lmao/main/",
    }
    local KITI_CACHE_DIR = "shitaro_sounds/"
    local KITI_LIST = {
        "primordial", "neverlose", "sparkle", "mc bow", "skeet", "break",
        "rust", "applepay", "bubble", "combobreak", "killcard", "xp",
        "na naxuy", "stony", "hentai",
    }
    local KITI_SND_CFG = {
        sheriffKill = { on = false, name = "mc bow", volume = 1 },
        murderKill  = { on = false, name = "skeet", volume = 1 },
        sheriffShoot = { on = false, name = "sparkle", volume = 0.6 },
    }
    local kSndLast = { sheriffKill = 0, murderKill = 0, sheriffShoot = 0 }

    local function ensureFs()
        return type(isfile) == "function" and type(readfile) == "function"
            and type(writefile) == "function" and type(getcustomasset) == "function"
    end

    local function loadSoundPath(path)
        local okI, has = pcall(isfile, path)
        if not (okI and has) then return nil end
        local okR, data = pcall(readfile, path)
        if not (okR and type(data) == "string" and #data > 0) then return nil end
        local ext = string.match(path, "(%.[^%./\\]+)$") or ".ogg"
        local tmp = "fh_snd_" .. tostring(math.random(100000, 999999)) .. ext
        if not pcall(writefile, tmp, data) then return nil end
        local okA, asset = pcall(getcustomasset, tmp)
        if not (okA and type(asset) == "string" and asset ~= "") then return nil end
        return asset
    end

    local function resolveSound(name)
        local dirs = { "shitaroebet/", "assets/", "", KITI_CACHE_DIR }
        local exts = { ".ogg", ".mp3", ".wav", "" }
        for _, dir in ipairs(dirs) do
            for _, ext in ipairs(exts) do
                local a = loadSoundPath(dir .. name .. ext)
                if a then return a end
            end
        end
        if ensureFs() and type(makefolder) == "function" then
            if not isfolder(KITI_CACHE_DIR) then pcall(makefolder, KITI_CACHE_DIR) end
            local path = KITI_CACHE_DIR .. name .. ".ogg"
            if not isfile(path) then
                local encoded = name:gsub(" ", "%%20")
                for _, base in ipairs(KITI_BASES) do
                    local url = base .. encoded .. ".ogg"
                    local ok, data = pcall(function() return game:HttpGet(url, true) end)
                    if ok and type(data) == "string" and #data > 1024 and not data:find("<html") then
                        pcall(writefile, path, data)
                        if isfile(path) then break end
                    end
                end
            end
            if isfile(path) then
                local okA, a = pcall(getcustomasset, path)
                if okA and a then return a end
            end
        end
        return nil
    end

    local function playKitiSound(name, volume)
        local id = resolveSound(name)
        if not id then
            Notify("FH", "Не нашёл звук: " .. name, 3)
            return
        end
        local s = Instance.new("Sound")
        s.SoundId = id
        s.Volume = volume or 1
        s.Parent = SoundService
        s:Play()
        task.delay(8, function()
            pcall(function() s:Destroy() end)
        end)
    end
    getgenv().FH_PlayKitiSound = playKitiSound

    local function getMyRole()
        local d = getRoundData()
        return d and d[LocalPlayer.Name] and d[LocalPlayer.Name].Role or nil
    end

    local hookedPlayers = {}
    local function hookPlayerDeath(pl)
        if not pl or hookedPlayers[pl] then return end
        hookedPlayers[pl] = true
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 8)
            if not hum then return end
            hum.Died:Connect(function()
                local deadName = pl.Name
                local myRole = getMyRole()
                local d = getRoundData()
                if type(d) ~= "table" then return end
                local deadInfo = d[deadName]
                if not deadInfo then return end
                local deadRole = deadInfo.Role
                local murdererAlive = nil
                for nm, info in pairs(d) do
                    if type(info) == "table" and info.Role == "Murderer" and not info.Dead then
                        murdererAlive = nm
                        break
                    end
                end
                if deadRole == "Murderer" then
                    if (myRole == "Sheriff" or myRole == "Hero") and KITI_SND_CFG.sheriffKill.on then
                        local now = os.clock()
                        if now - kSndLast.sheriffKill >= 0.15 then
                            kSndLast.sheriffKill = now
                            playKitiSound(KITI_SND_CFG.sheriffKill.name, KITI_SND_CFG.sheriffKill.volume)
                        end
                    end
                end
                if deadRole ~= "Murderer" and murdererAlive then
                    if KITI_SND_CFG.murderKill.on then
                        local now = os.clock()
                        if now - kSndLast.murderKill >= 0.15 then
                            kSndLast.murderKill = now
                            playKitiSound(KITI_SND_CFG.murderKill.name, KITI_SND_CFG.murderKill.volume)
                        end
                    end
                end
            end)
        end
        if pl.Character then task.spawn(onChar, pl.Character) end
        pl.CharacterAdded:Connect(onChar)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookPlayerDeath(p) end
    Players.PlayerAdded:Connect(function(p) hookPlayerDeath(p) end)
    Players.PlayerRemoving:Connect(function(p) hookedPlayers[p] = nil end)

    local shootConn = nil
    local function connectSheriffShoot()
        if shootConn then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices", 10):WaitForChild("WeaponService", 10):WaitForChild("GunFired", 10)
        end)
        if not ok or not remote then return end
        shootConn = remote.OnClientEvent:Connect(function(tool)
            if not KITI_SND_CFG.sheriffShoot.on then return end
            local myRole = getMyRole()
            if not (myRole == "Sheriff" or myRole == "Hero") then return end
            local char = LocalPlayer.Character
            if not char then return end
            if typeof(tool) == "Instance" and tool:IsDescendantOf(char) then
                local now = os.clock()
                if now - kSndLast.sheriffShoot >= 0.05 then
                    kSndLast.sheriffShoot = now
                    playKitiSound(KITI_SND_CFG.sheriffShoot.name, KITI_SND_CFG.sheriffShoot.volume)
                end
            end
        end)
    end
    task.spawn(connectSheriffShoot)

    local kSec = tU:AddSection({ Name = "Звуки игры (KITI)" })
    addOpt(kSec, "AddToggle", "SndSheriffKill", { Title = "Мы убили убийцу", Default = false }, function(v)
        KITI_SND_CFG.sheriffKill.on = v
    end)
    addOpt(kSec, "AddDropdown", "SndSheriffKillName", { Title = "  Звук", Values = KITI_LIST, Default = "mc bow" }, function(v)
        KITI_SND_CFG.sheriffKill.name = v
    end)
    addOpt(kSec, "AddSlider", "SndSheriffKillVol", { Title = "  Громкость", Min = 0.1, Max = 5, Default = 1, Rounding = 1 }, function(v)
        KITI_SND_CFG.sheriffKill.volume = tonumber(v) or 1
    end)
    kSec:AddButton({ Title = "  Прослушать", Callback = function()
        playKitiSound(KITI_SND_CFG.sheriffKill.name, KITI_SND_CFG.sheriffKill.volume)
    end })

    addOpt(kSec, "AddToggle", "SndMurderKill", { Title = "Убийца кого-то убил", Default = false }, function(v)
        KITI_SND_CFG.murderKill.on = v
    end)
    addOpt(kSec, "AddDropdown", "SndMurderKillName", { Title = "  Звук", Values = KITI_LIST, Default = "skeet" }, function(v)
        KITI_SND_CFG.murderKill.name = v
    end)
    addOpt(kSec, "AddSlider", "SndMurderKillVol", { Title = "  Громкость", Min = 0.1, Max = 5, Default = 1, Rounding = 1 }, function(v)
        KITI_SND_CFG.murderKill.volume = tonumber(v) or 1
    end)
    kSec:AddButton({ Title = "  Прослушать", Callback = function()
        playKitiSound(KITI_SND_CFG.murderKill.name, KITI_SND_CFG.murderKill.volume)
    end })

    addOpt(kSec, "AddToggle", "SndSheriffShoot", { Title = "Наш выстрел", Default = false }, function(v)
        KITI_SND_CFG.sheriffShoot.on = v
        if v then connectSheriffShoot() end
    end)
    addOpt(kSec, "AddDropdown", "SndSheriffShootName", { Title = "  Звук", Values = KITI_LIST, Default = "sparkle" }, function(v)
        KITI_SND_CFG.sheriffShoot.name = v
    end)
    addOpt(kSec, "AddSlider", "SndSheriffShootVol", { Title = "  Громкость", Min = 0.1, Max = 5, Default = 0.6, Rounding = 1 }, function(v)
        KITI_SND_CFG.sheriffShoot.volume = tonumber(v) or 0.6
    end)
    kSec:AddButton({ Title = "  Прослушать", Callback = function()
        playKitiSound(KITI_SND_CFG.sheriffShoot.name, KITI_SND_CFG.sheriffShoot.volume)
    end })

    -- ====== БУСТ ГОЛОСОВ ======
    local mvSec = tU:AddSection({ Name = "Буст голосов" })
    local mvDupCap = 10
    local function DupeVoteFast(times)
        local char = LocalPlayer.Character
        if not char then Notify("FH", "Персонаж не загружен", 2); return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then Notify("FH", "HRP не найден", 2); return end
        local savedCF = hrp.CFrame
        Notify("FH", "Буст голосов: " .. times .. " раз", 3)
        task.spawn(function()
            for i = 1, times do
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    pcall(function() h.Health = 0 end)
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead) end)
                end
                local waited = 0
                local lastChar = c
                local respawned = false
                while waited < 5 do
                    task.wait(0.02)
                    waited = waited + 0.02
                    local nc = LocalPlayer.Character
                    if nc and nc ~= lastChar then
                        local nh = nc:FindFirstChildOfClass("Humanoid")
                        local nhrp = nc:FindFirstChild("HumanoidRootPart")
                        if nh and nh.Health > 0 and nhrp then
                            pcall(function() nhrp.CFrame = savedCF end)
                            pcall(function() nhrp.AssemblyLinearVelocity = Vector3.zero end)
                            pcall(function() nhrp.AssemblyAngularVelocity = Vector3.zero end)
                            respawned = true
                            break
                        end
                    end
                end
                if respawned then task.wait(0.5) end
            end
            Notify("FH", "Буст завершён", 3)
        end)
    end
    addOpt(mvSec, "AddSlider", "MVDupeCap", { Title = "Кол-во", Min = 1, Max = 15, Default = 10, Rounding = 0 }, function(v)
        mvDupCap = tonumber(v) or 10
    end)
    mvSec:AddButton({ Title = "Буст голосов", Callback = function()
        task.spawn(function()
            DupeVoteFast(math.clamp(math.floor(mvDupCap), 1, 15))
        end)
    end })

    -- ====== АНТИ ======
    local antiSec = tU:AddSection({ Name = "Анти" })
    local antiFlingOn = false
    local flingCache, flingReg = {}, {}
    local function regFling(model)
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
    addOpt(antiSec, "AddToggle", "AntiFling", { Title = "Анти-отброс", Default = false }, function(v)
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
    addOpt(antiSec, "AddToggle", "AntiVoid", { Title = "Анти-падение", Default = false }, function(v) antiVoidOn = v end)
    local antiTrapOn = false
    local trapSpeedCache, trapJumpCache = 16, 50
    RunService.Heartbeat:Connect(function()
        if not antiTrapOn then return end
        local hum = getHum()
        if not hum then return end
        if hum.WalkSpeed > 1 then trapSpeedCache = hum.WalkSpeed end
        if hum.JumpPower > 1 then trapJumpCache = hum.JumpPower end
        pcall(function()
            if hum.WalkSpeed <= 1 then hum.WalkSpeed = trapSpeedCache end
            if hum.JumpPower <= 1 then hum.JumpPower = trapJumpCache end
        end)
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g.Name == "TrapGUI" then pcall(function() g:Destroy() end) end
            end
        end
    end)
    addOpt(antiSec, "AddToggle", "AntiTrap", { Title = "Анти-ловушка", Default = false }, function(v) antiTrapOn = v end)
    local antiFadeOn = false
    local fadeCache, fadeConns = {}, {}
    local fadeNames = { CameraFade = true, SpawnFade = true, Fade = true, DeathFade = true }
    local function fadeHide(frame)
        if not frame or not frame.Parent or not frame:IsA("GuiObject") then return end
        if fadeCache[frame] == nil then fadeCache[frame] = frame.Visible end
        if frame.Visible then pcall(function() frame.Visible = false end) end
        if not fadeConns[frame] then
            fadeConns[frame] = frame:GetPropertyChangedSignal("Visible"):Connect(function()
                if antiFadeOn and frame.Visible then
                    pcall(function() frame.Visible = false end)
                end
            end)
        end
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
    end
    local function fadeRestore()
        for _, c in pairs(fadeConns) do pcall(function() c:Disconnect() end) end
        fadeConns = {}
        for frame, v in pairs(fadeCache) do
            if frame and frame.Parent then pcall(function() frame.Visible = v end) end
        end
        fadeCache = {}
    end
    addOpt(antiSec, "AddToggle", "AntiFade", { Title = "Убрать чёрный экран", Default = false }, function(v)
        antiFadeOn = v
        if v then fadeApply() else fadeRestore() end
    end)
    getgenv().ANTI_UNLOAD = function()
        antiFlingOn, antiVoidOn, antiTrapOn, antiFadeOn = false, false, false, false
        restoreFling()
        fadeRestore()
    end
end

-- ============================================================
-- ТРОЛЛИНГ (TP, FakeDeath, Teleports, PlayerList — заглушка)
-- ============================================================
do
    local tT = Tabs.Troll

    -- ====== TP TOOL ======
    local tpOn, tpTool, tpActConn = false, nil, nil
    local function giveTpTool()
        if not tpOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("tp")
        if not existing and LocalPlayer.Character then existing = LocalPlayer.Character:FindFirstChild("tp") end
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
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t = bp:FindFirstChild("tp"); if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("tp"); if t then pcall(function() t:Destroy() end) end end
    end
    addOpt(tT:AddSection({ Name = "Инструменты" }), "AddToggle", "ToolTP", { Title = "ТП-тул", Default = false }, function(v)
        tpOn = v
        if v then giveTpTool() else removeTpTool() end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if tpOn then giveTpTool() end
    end)

    -- ====== FAKE DEATH ======
    local fdSec = tT:AddSection({ Name = "Фейк-смерть" })
    local FAKE_DEATH_1_ID = "132384701706046"
    local FAKE_DEATH_2_ID = "125032357496729"
    local fdTrack1, fdTrack2 = nil, nil
    local function stopAllFd()
        if fdTrack1 then pcall(function() fdTrack1:Stop() end); fdTrack1 = nil end
        if fdTrack2 then pcall(function() fdTrack2:Stop() end); fdTrack2 = nil end
    end
    local animCache = {}
    local function resolveId(id)
        if animCache[id] then return animCache[id] end
        if type(id) == "number" then id = tostring(id) end
        if id:find("://") then animCache[id] = id; return id end
        local raw = tostring(id):gsub("%D", "")
        if raw == "" then return nil end
        local url = "rbxassetid://" .. raw
        animCache[id] = url
        return url
    end
    local function getAnimator(char)
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        return animator
    end
    local function playFd(id, slot)
        local c = LocalPlayer.Character
        if not c then Notify("FH", "Персонаж не загружен", 2); return end
        local animator = getAnimator(c)
        if not animator then Notify("FH", "Animator не найден", 2); return end
        local resolved = resolveId(id)
        if not resolved then return end
        if slot == 1 and fdTrack1 then pcall(function() fdTrack1:Stop() end); fdTrack1 = nil end
        if slot == 2 and fdTrack2 then pcall(function() fdTrack2:Stop() end); fdTrack2 = nil end
        local anim = Instance.new("Animation")
        anim.AnimationId = resolved
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            pcall(function() track:Play() end)
            if slot == 1 then fdTrack1 = track else fdTrack2 = track end
            Notify("FH", "Фейк-смерть " .. slot, 2)
        else
            Notify("FH", "Не удалось запустить " .. slot, 2)
        end
    end
    fdSec:AddButton({ Title = "Фейк-смерть 1", Callback = function() playFd(FAKE_DEATH_1_ID, 1) end })
    fdSec:AddButton({ Title = "Фейк-смерть 2", Callback = function() playFd(FAKE_DEATH_2_ID, 2) end })
    fdSec:AddButton({ Title = "Остановить", Callback = function()
        stopAllFd()
        Notify("FH", "Остановлено", 2)
    end })

    -- ====== TELEPORTS ======
    local function inLobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby" or p.Name == "Lobby" then return true end
            p = p.Parent
        end
        return false
    end
    local tpBtnSec = tT:AddSection({ Name = "Телепорт" })
    tpBtnSec:AddButton({ Title = "ТП в лобби", Callback = function()
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
            local s = locs[math.random(1, #locs)]
            hrp.CFrame = s.CFrame + Vector3.new(0, 3, 0)
        end
    end })
    tpBtnSec:AddButton({ Title = "ТП на карту", Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        local spawns = {}
        for _, o in ipairs(Workspace:GetDescendants()) do
            if (o:IsA("SpawnLocation") or (o:IsA("BasePart") and o.Name == "Spawn")) and not inLobby(o) then
                spawns[#spawns + 1] = o
            end
        end
        if #spawns > 0 then
            local s = spawns[math.random(1, #spawns)]
            hrp.CFrame = s.CFrame + Vector3.new(0, 5, 0)
        end
    end })

    -- ====== PLAYER LIST (ЗАГЛУШКА) ======
    local plSec = tT:AddSection({ Name = "Player List Panel" })
    getgenv().FH_SelectedPlayer = nil
    addOpt(plSec, "AddToggle", "FHPlayerPanelOn", { Title = "Открыть Player List Panel (заглушка)", Default = false }, function(v)
        if v then
            Notify("FH", "Player List Panel в разработке", 3)
            task.delay(0.4, function()
                local opt = Options.FHPlayerPanelOn
                if opt then pcall(function() opt:SetValue(false) end) end
            end)
        end
    end)
    plSec:AddButton({ Title = "Телепорт к выбранному (заглушка)", Callback = function()
        Notify("FH", "Функция в разработке", 2)
    end })
    plSec:AddButton({ Title = "Телепорт игрока к себе (заглушка)", Callback = function()
        Notify("FH", "Функция в разработке", 2)
    end })

    getgenv().TROLL_UNLOAD = function()
        tpOn = false
        removeTpTool()
        stopAllFd()
    end
end

-- ============================================================
-- ФАРМ (только базовый V3, без Advanced)
-- ============================================================
do
    local tF = Tabs.Farm
    local farmSec = tF:AddSection({ Name = "Автофарм" })
    local active = false
    local mode = "Basic"
    local speed = 23
    local avoid = false
    local fullAction = "Respawn"
    local ncCache = {}
    local farmTarget = nil
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
        coinsDone = false
        sawCoins = false
        farmTarget = nil
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
            if coinOK(v) then out[#out + 1] = v end
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
    local mhrpCache, mhrpT = nil, 0
    local function murdererHRP()
        local now = os.clock()
        if now - mhrpT < 0.25 then return mhrpCache end
        mhrpT = now
        mhrpCache = nil
        local d = getRoundData()
        if type(d) ~= "table" then return nil end
        for name, info in pairs(d) do
            if type(info) == "table" and info.Role == "Murderer" and not info.Dead and name ~= LocalPlayer.Name then
                local pl = Players:FindFirstChild(name)
                local ch = pl and pl.Character
                local hh = ch and ch:FindFirstChild("HumanoidRootPart")
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if hh and (not hum or hum.Health > 0) then mhrpCache = hh end
                break
            end
        end
        return mhrpCache
    end
    local function flatDist(a, b)
        return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
    end
    local function fireTouch(coin)
        if type(firetouchinterest) ~= "function" then return end
        if not coin or not coin.Parent then return end
        local now = os.clock()
        if now - lastTouch < 0.05 then return end
        lastTouch = now
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
    local function pickCoin(pos, list, mpos)
        if not (avoid and mpos) then return nearest(pos, list) end
        local safe, sd = nil, math.huge
        local far, fd = nil, -1
        for _, v in ipairs(list) do
            local md = flatDist(v.Position, mpos)
            if md > fd then fd = md; far = v end
            if md >= AVOID_DIST then
                local d = (v.Position - pos).Magnitude
                if d < sd then sd = d; safe = v end
            end
        end
        return safe or (fd >= AVOID_DIST * 0.6 and far or nil)
    end
    local function coinOKNow(v, mpos)
        if not coinOK(v) then return false end
        if avoid and mpos and flatDist(v.Position, mpos) < AVOID_DIST * 0.6 then return false end
        return true
    end
    local function avoidSteer(cur, dest, mpos)
        if not (avoid and mpos) then return dest end
        local dm = flatDist(cur, mpos)
        if dm >= AVOID_DIST then return dest end
        local away = Vector3.new(cur.X - mpos.X, 0, cur.Z - mpos.Z)
        if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
        away = away.Unit
        local want = Vector3.new(dest.X - cur.X, 0, dest.Z - cur.Z)
        local mag = want.Magnitude
        if mag < 0.1 then return dest end
        local w = 1 + (1 - dm / AVOID_DIST) * 2
        local blend = want.Unit + away * w
        if blend.Magnitude < 0.1 then blend = away else blend = blend.Unit end
        local np = cur + blend * mag
        return Vector3.new(np.X, dest.Y, np.Z)
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
            cf = cf * CFrame.Angles(-math.pi * 0.5, 0, 0)
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
        local origin = my.Position
        upParams.FilterDescendantsInstances = { LocalPlayer.Character }
        local res = Workspace:Raycast(origin, Vector3.new(0, 400, 0), upParams)
        local y = res and (res.Position.Y + 5) or (downRefY and downRefY + 5 or nil)
        if not y then return end
        pcall(function()
            my.CFrame = CFrame.new(origin.X, y, origin.Z)
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
    local function killAllPlayersViaKA()
        local char = LocalPlayer.Character
        if not char then return end
        local knife = char:FindFirstChild("Knife")
        if not knife then
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            knife = bp and bp:FindFirstChild("Knife")
            if knife then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:EquipTool(knife)
                    task.wait(0.1)
                end
            end
        end
        if not knife then return end
        local ev = knife:FindFirstChild("Events")
        if not ev then return end
        local stabbed = ev:FindFirstChild("KnifeStabbed")
        local touched = ev:FindFirstChild("HandleTouched")
        if not stabbed or not touched then return end
        local my = char:FindFirstChild("HumanoidRootPart")
        if not my then return end
        for _ = 1, 3 do
            local victims = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local tc = p.Character
                    if tc then
                        local th = tc:FindFirstChildOfClass("Humanoid")
                        local tp = tc:FindFirstChild("HumanoidRootPart")
                        if th and th.Health > 0 and tp and (tp.Position - my.Position).Magnitude <= 60 then
                            victims[#victims + 1] = tp
                        end
                    end
                end
            end
            if #victims > 0 then
                pcall(function() stabbed:FireServer() end)
                for _, v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            end
            task.wait(0.05)
        end
    end
    local function fireFullAction()
        if fullAction == "Respawn" then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health = 0 end) end
        elseif fullAction == "Auto" then
            local myRole = getRoleFromData(LocalPlayer)
            if myRole == "murderer" then
                task.spawn(killAllPlayersViaKA)
            end
        end
    end

    local CONFLICT_OPTS = {
        "KAOn", "SilentAuto", "SilentEnabled", "AutoGrabGun",
        "ToolFling", "ToolTP", "FXOn", "TracerOn",
        "FreezeToggle", "Noclip", "Spinbot", "SpeedGlitchOn",
        "BhopOn", "InfJump",
    }
    local savedConflicts = {}
    local function disableConflicts()
        savedConflicts = {}
        for _, name in ipairs(CONFLICT_OPTS) do
            local opt = Options[name]
            if opt and opt.Value == true then
                savedConflicts[name] = true
                pcall(function() opt:SetValue(false) end)
            end
        end
        if next(savedConflicts) then
            Notify("FH", "Конфликтующие функции отключены", 3)
        end
    end
    local function restoreConflicts()
        for name, _ in pairs(savedConflicts) do
            local opt = Options[name]
            if opt then pcall(function() opt:SetValue(true) end) end
        end
        if next(savedConflicts) then
            Notify("FH", "Функции восстановлены", 2)
        end
        savedConflicts = {}
    end

    RunService.Stepped:Connect(function(_, dt)
        if not active then return end
        if not canFarm() then
            farmTarget = nil
            wasDown = false
            setNoclip(false)
            return
        end
        local my = hrp()
        if not my then return end
        local list = coinList()
        local function finish()
            farmTarget = nil
            farmRelease()
            if not coinsDone then
                coinsDone = true
                fireFullAction()
            end
        end
        if sawCoins and bagsFull() then finish(); return end
        if #list > 0 then
            sawCoins = true
            if coinsDone then coinsDone = false end
            local mhrp = avoid and murdererHRP() or nil
            local mpos = mhrp and mhrp.Position or nil
            if not coinOKNow(farmTarget, mpos) then
                farmTarget = pickCoin(my.Position, list, mpos)
            end
            if farmTarget then
                setNoclip(true)
                local cpos = farmTarget.Position
                downRefY = cpos.Y
                local dest = cpos
                if mode == "Down" then
                    local xz = flatDist(my.Position, cpos)
                    local safe = (not mpos) or flatDist(my.Position, mpos) > RISE_SAFE_DIST
                    if xz <= DOWN_RISE_XZ and safe then
                        dest = cpos
                        fireTouch(farmTarget)
                    else
                        dest = Vector3.new(cpos.X, cpos.Y - DOWN_DEPTH, cpos.Z)
                    end
                elseif (cpos - my.Position).Magnitude <= 6 then
                    fireTouch(farmTarget)
                end
                dest = avoidSteer(my.Position, dest, mpos)
                farmMove(my, dest, dt)
            elseif mpos then
                setNoclip(true)
                local away = Vector3.new(my.Position.X - mpos.X, 0, my.Position.Z - mpos.Z)
                if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
                away = away.Unit
                local y = my.Position.Y
                if mode == "Down" and downRefY then y = downRefY - DOWN_DEPTH end
                farmMove(my, my.Position + away * 40 + Vector3.new(0, y - my.Position.Y, 0), dt)
            end
        else
            farmTarget = nil
            farmRelease()
            if sawCoins and not coinsDone then finish() end
        end
    end)
    addOpt(farmSec, "AddToggle", "FarmV3On", { Title = "Включить автофарм", Default = false }, function(v)
        active = v
        if v then
            disableConflicts()
        else
            restoreConflicts()
            farmRelease()
        end
        resetProgress()
    end)
    addOpt(farmSec, "AddDropdown", "FarmV3Mode", { Title = "Тип", Values = { "Basic", "Down" }, Default = "Basic" }, function(v)
        mode = v or "Basic"
        farmTarget = nil
        if mode == "Basic" and wasDown then
            wasDown = false
            returnToSurface()
        end
    end)
    addOpt(farmSec, "AddSlider", "FarmV3Speed", { Title = "Скорость", Min = 5, Max = 60, Default = 23, Rounding = 1 }, function(v)
        speed = tonumber(v) or 23
    end)
    addOpt(farmSec, "AddToggle", "FarmV3Avoid", { Title = "Избегать маньяка", Default = false }, function(v)
        avoid = v
        farmTarget = nil
    end)
    addOpt(farmSec, "AddDropdown", "FarmFullAction", { Title = "При полном мешке", Values = { "Respawn", "Auto" }, Default = "Respawn" }, function(v)
        fullAction = v or "Respawn"
    end)
    getgenv().FARMV3_UNLOAD = function()
        active = false
        farmTarget = nil
        farmRelease()
        restoreConflicts()
    end
end

-- ============================================================
-- ФИНАЛ
-- ============================================================
pcall(function() Window:SelectTab(1) end)

print("[FH] ============================================")
print("[FH] Part 3/3 — Effects, Emotes (FIXED), Utilities, Troll, Farm")
print("[FH] UI Sounds FIXED, KITI sounds integrated, Game Sounds REMOVED")
print("[FH] Emotes via Animator (fixed), PlayerList placeholder, Advanced Farm REMOVED")
print("[FH] FortniHub v" .. VERSION .. " — " .. CREDITS)
print("[FH] ============================================")
