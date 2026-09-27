-- ============================================================
-- FORTNIHUB v18.1 — ЧАСТЬ 1/2: Core + HUD + Combat + Movement + Settings
-- FIXED BUILD — by Bean
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
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local VERSION = "18.1.0-FIXED"

-- ============================================================
-- SAFE RANDOM
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
-- STATE
-- ============================================================
local S = {
    frozen = false,
    freezeUpKey = Enum.KeyCode.Space,
    freezeDownKey = Enum.KeyCode.LeftAlt,
}

-- FIX: убрал hitChance, silent теперь всегда 100% при попадании
local silent = {
    enabled = false,
    predict = true,
    force = true,
    autoShoot = false,
    autoDelay = 0.08,
    bindKey = Enum.KeyCode.E,
    lastShot = 0,
    fov = 500,
}

local knifeSilent = {
    enabled = false,
    bindKey = Enum.KeyCode.R,
    radius = 20,
    fov = 120,
    showFov = true,
    checkWalls = false,
    instaKill = true,
    predict = true,
}

local kaV1 = { on = false, dist = 30, lastHit = 0 }
local kaV2 = { on = false, dist = 30, lastHit = 0 }
local killAuraVersion = "v2"

-- ============================================================
-- HELPERS
-- ============================================================
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

-- FIX: кэш модуля + retry, чтобы silent и farm не сдыхали
local _roundModule, _roundFetched = nil, false
local function getRoundModule()
    if _roundModule then return _roundModule end
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules", 10):WaitForChild("CurrentRoundClient", 10))
    end)
    if ok and type(m) == "table" then
        _roundModule = m
        return m
    end
    return nil
end

local function getRoundData()
    local m = getRoundModule()
    if m and type(m.PlayerData) == "table" then return m.PlayerData end
    return nil
end

-- FIX: роли с более надёжным резервным определением по инструментам
local function getRoleFromData(p)
    if not p then return "lobby" end
    local m = getRoundModule()
    if m and type(m.PlayerData) == "table" then
        local d = m.PlayerData[p.Name]
        if d and not d.Dead then
            if d.Role == "Murderer" then return "murderer" end
            if d.Role == "Sheriff" then return "sheriff" end
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

-- FIX: надёжный поиск маньяка (сначала модуль, потом инструмент)
local function isMurderer()
    local m = getRoundModule()
    if m and type(m.PlayerData) == "table" then
        for name, info in pairs(m.PlayerData) do
            if type(info) == "table" and info.Role == "Murderer" and not info.Dead then
                local pl = Players:FindFirstChild(name)
                if pl and pl ~= LocalPlayer then return pl end
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local c = p.Character
            if c then
                local bp = p:FindFirstChild("Backpack")
                if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then
                    return p
                end
            end
        end
    end
    return nil
end

local function isSheriffOrHero()
    local m = getRoundModule()
    if m and type(m.PlayerData) == "table" then
        for name, info in pairs(m.PlayerData) do
            if type(info) == "table" and (info.Role == "Sheriff" or info.Role == "Hero") and not info.Dead then
                local pl = Players:FindFirstChild(name)
                if pl and pl ~= LocalPlayer then return pl end
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local c = p.Character
            if c then
                local bp = p:FindFirstChild("Backpack")
                if c:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then
                    return p
                end
            end
        end
    end
    return nil
end

-- ============================================================
-- FLUENT LOADER + ADAPTER
-- ============================================================
local Fluent
do
    print("[FH][INFO] Загружаю Fluent UI...")
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
    print("[FH][INFO] Fluent загружен")
end

local function adaptTab(tab)
    if not tab then return tab end
    for _, name in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput",
                            "AddButton","AddLabel","AddKeybind","AddColorpicker","AddColorPicker"}) do
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

local Window, Options, Tabs = nil, nil, {}

do
    Window = Fluent:CreateWindow({
        Title = "FortniHub MM2",
        SubTitle = "v"..VERSION.." FIXED",
        TabWidth = 130,
        Size = UDim2.fromOffset(500, 380),
        Theme = "Darker",
        -- FIX: НЕ ставим MinimizeKey здесь, чтобы Fluent не вешал свой бинд.
        -- Мы сами будем управлять открытием/закрытием.
    })
    Options = Fluent.Options
    local origAddTab = Window.AddTab
    Window.AddTab = function(self, ...)
        local tab = origAddTab(self, ...)
        return adaptTab(tab)
    end
    print("[FH][INFO] Окно создано")
end

-- ============================================================
-- FIX: РУЧНОЙ KEYBIND ДЛЯ МЕНЮ
-- Fluent не даёт менять MinimizeKey после CreateWindow.
-- Вешаем свой InputBegan и дёргаем Window:Toggle()
-- ============================================================
local MenuKey = Enum.KeyCode.P
do
    local menuOpen = true
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == MenuKey then
            menuOpen = not menuOpen
            pcall(function()
                if menuOpen then
                    if Window.Open then Window:Open()
                    elseif Window.Show then Window:Show() end
                else
                    if Window.Close then Window:Close()
                    elseif Window.Hide then Window:Hide() end
                end
            end)
        end
    end)
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
-- HUD
-- ============================================================
local HUDGui, FPSLabel, PingLabel
do
    HUDGui = Instance.new("ScreenGui")
    HUDGui.Name = "FH_HUD_v18"
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
    stroke.Color = Color3.fromRGB(138, 92, 246)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    drag(Pill)

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

    local s1 = seg(8, 130)
    local logoIcon = Instance.new("TextLabel")
    logoIcon.BackgroundTransparency = 1
    logoIcon.Size = UDim2.fromOffset(24, 40)
    logoIcon.Position = UDim2.fromOffset(6, 0)
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.Text = "⚡"
    logoIcon.TextSize = 20
    logoIcon.TextColor3 = Color3.fromRGB(178, 152, 255)
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

    local s2 = seg(146, 120)
    local fpsIcon = Instance.new("TextLabel")
    fpsIcon.BackgroundTransparency = 1
    fpsIcon.Size = UDim2.fromOffset(20, 40)
    fpsIcon.Position = UDim2.fromOffset(6, 0)
    fpsIcon.Font = Enum.Font.GothamBold
    fpsIcon.Text = "F"
    fpsIcon.TextSize = 16
    fpsIcon.TextColor3 = Color3.fromRGB(80, 240, 120)
    fpsIcon.TextXAlignment = Enum.TextXAlignment.Left
    fpsIcon.Parent = s2

    FPSLabel = Instance.new("TextLabel")
    FPSLabel.BackgroundTransparency = 1
    FPSLabel.Size = UDim2.fromOffset(50, 40)
    FPSLabel.Position = UDim2.fromOffset(26, 0)
    FPSLabel.Font = Enum.Font.GothamBold
    FPSLabel.Text = "60"
    FPSLabel.TextSize = 15
    FPSLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
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

    local s3 = seg(274, 110)
    local pingIcon = Instance.new("TextLabel")
    pingIcon.BackgroundTransparency = 1
    pingIcon.Size = UDim2.fromOffset(20, 40)
    pingIcon.Position = UDim2.fromOffset(6, 0)
    pingIcon.Font = Enum.Font.GothamBold
    pingIcon.Text = "P"
    pingIcon.TextSize = 16
    pingIcon.TextColor3 = Color3.fromRGB(80, 240, 120)
    pingIcon.TextXAlignment = Enum.TextXAlignment.Left
    pingIcon.Parent = s3

    PingLabel = Instance.new("TextLabel")
    PingLabel.BackgroundTransparency = 1
    PingLabel.Size = UDim2.fromOffset(48, 40)
    PingLabel.Position = UDim2.fromOffset(26, 0)
    PingLabel.Font = Enum.Font.GothamBold
    PingLabel.Text = "0"
    PingLabel.TextSize = 15
    PingLabel.TextColor3 = Color3.fromRGB(80, 240, 120)
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

    local fc, lastSec = 0, os.clock()
    AddConn("HUD_FPS", RunService.Heartbeat:Connect(function()
        fc = fc + 1
        local now = os.clock()
        if now - lastSec >= 1 then
            local cur = fc
            fc = 0; lastSec = now
            local c = cur < 30 and Color3.fromRGB(255, 80, 80) or (cur < 60 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 240, 120))
            FPSLabel.Text = tostring(cur)
            FPSLabel.TextColor3 = c
            fpsIcon.TextColor3 = c
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
        if ok then
            local c = p < 60 and Color3.fromRGB(80, 240, 120) or (p < 120 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 80, 80))
            PingLabel.Text = tostring(p)
            PingLabel.TextColor3 = c
            pingIcon.TextColor3 = c
        end
    end))

    print("[FH][INFO] HUD v18.1 готов")
end

-- ============================================================
-- SILENT AIM v4 (FIXED)
-- - убран шанс попадания
-- - цель ищется надёжно (модуль + инструмент)
-- - перехват и через WeaponService, и через прямое позиционирование
-- ============================================================
do
    local TRK = {
        target = nil, char = nil, part = nil, hum = nil,
        pos = nil, time = 0, vel = Vector3.zero, gap = 0, ready = false,
    }

    local function updateTarget()
        local t = isMurderer()
        if t ~= TRK.target then
            TRK.target = t
            TRK.char = t and t.Character or nil
            TRK.part = nil
            TRK.hum = nil
            TRK.ready = false
            TRK.pos = nil
        end
        if not t or not t.Character then return end
        if t.Character ~= TRK.char then
            TRK.char = t.Character
            TRK.part = nil
            TRK.hum = nil
            TRK.pos = nil
        end
        if not TRK.part or not TRK.part.Parent then
            TRK.part = t.Character:FindFirstChild("HumanoidRootPart")
                or t.Character:FindFirstChild("UpperTorso")
                or t.Character:FindFirstChild("Torso")
                or t.Character:FindFirstChild("Head")
        end
        if not TRK.hum or not TRK.hum.Parent then
            TRK.hum = t.Character:FindFirstChildOfClass("Humanoid")
        end
    end

    local function targetAlive()
        return TRK.part and TRK.part.Parent and TRK.hum and TRK.hum.Parent and TRK.hum.Health > 0
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
            return
        end
        local dt = now - TRK.time
        if dt > 0.5 or (pos - TRK.pos).Magnitude > 100 then
            TRK.pos = pos
            TRK.time = now
            TRK.ready = false
            TRK.vel = Vector3.zero
            return
        end
        if dt <= 0 then return end
        if (pos - TRK.pos).Magnitude < 0.01 then return end
        local inst = (pos - TRK.pos) / dt
        TRK.vel = TRK.vel:Lerp(inst, 0.4)
        TRK.ready = true
        TRK.pos = pos
        TRK.time = now
        TRK.gap = dt
    end

    local function getPing()
        local ok, v = pcall(function() return LocalPlayer:GetNetworkPing() * 2 end)
        if ok and type(v) == "number" and v == v and v > 0 then
            return math.clamp(v, 0.02, 0.5)
        end
        return 0.08
    end

    local function getTargetPoint()
        if not targetAlive() then return nil end
        local pt = TRK.part.Position
        if silent.predict and TRK.ready then
            local horizon = math.clamp(getPing() + (TRK.gap or 0), 0, 0.4)
            pt = pt + TRK.vel * horizon
        end
        return pt
    end

    local weapon_service, origMouse, origScreen

    local function getWeaponService()
        if weapon_service then return weapon_service end
        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("ClientServices", 10):WaitForChild("WeaponService", 10))
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
                    local pt = getTargetPoint()
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
                    local pt = getTargetPoint()
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

    AddConn("SilentTick", RunService.Heartbeat:Connect(function()
        if not silent.enabled then return end
        local now = os.clock()
        pcall(updateTarget)
        pcall(trackTick, now)
    end))

    task.spawn(function()
        task.wait(1)
        pcall(installHooks)
    end)
    AddConn("SilentHookRetry", RunService.Heartbeat:Connect(function()
        if silent.enabled and not origMouse then pcall(installHooks) end
    end))

    -- FIX: прямое наведение через мышь (на случай если хуки не зашли)
    AddConn("SilentMouseAim", RunService.RenderStepped:Connect(function()
        if not silent.enabled then return end
        if not targetAlive() then return end
        local pt = getTargetPoint()
        if not pt then return end
        pcall(function()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local sp = cam:WorldToViewportPoint(pt)
            if sp.Z > 0 then
                local m = LocalPlayer:GetMouse()
                m.Target = TRK.part
            end
        end)
    end))

    local function manualShoot()
        if not silent.enabled then Notify("FH", "Включи Silent Aim", 2) return end
        local char = LocalPlayer.Character
        if not char then return end
        local gun = char:FindFirstChild("Gun")
        if not gun then
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            gun = bp and bp:FindFirstChild("Gun")
        end
        if not gun then Notify("FH", "Нужен пистолет", 2) return end
        if gun.Parent ~= char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(gun) end
            task.wait(0.05)
        end
        pcall(function() gun:Activate() end)
        pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
    end

    local tC = Window:AddTab({Title = "Бой"})
    Tabs.Combat = tC

    local silentSec = tC:AddSection({Name = "Silent Aim v4 (FIXED)"})

    silentSec:AddToggle("SilentEnabled", {Title = "Включить Silent Aim", Default = false}):OnChanged(function(v)
        silent.enabled = v
        if v then
            task.spawn(function()
                pcall(installHooks)
                pcall(updateTarget)
            end)
        else
            pcall(uninstallHooks)
        end
        Notify("FH", "Silent " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    silentSec:AddToggle("SilentPredict", {Title = "Предсказание", Default = true}):OnChanged(function(v) silent.predict = v end)
    silentSec:AddToggle("SilentForce", {Title = "Стрельба через стены (wallbang)", Default = true}):OnChanged(function(v) silent.force = v end)

    local silentBindOpt = silentSec:AddKeybind("SilentBind", {Title = "Кнопка выстрела", Default = "E"})
    silentBindOpt:OnChanged(function(k)
        if typeof(k) == "EnumItem" then
            silent.bindKey = k
            Notify("FH", "Кнопка: " .. tostring(k), 2)
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == silent.bindKey then
            manualShoot()
        end
    end)

    -- ============ KNIFE SILENT (FIXED) ============
    -- FIX: угол считается в мировых координатах, а не в экранных
    local knifeSec = tC:AddSection({Name = "Тихий бросок ножа (FIXED)"})

    knifeSec:AddToggle("KnifeSilentOn", {Title = "Включить", Default = false}):OnChanged(function(v)
        knifeSilent.enabled = v
        Notify("FH", "Knife Silent " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    knifeSec:AddToggle("KnifeInsta", {Title = "Insta Kill", Default = true}):OnChanged(function(v) knifeSilent.instaKill = v end)
    knifeSec:AddToggle("KnifePredict", {Title = "Предсказание", Default = true}):OnChanged(function(v) knifeSilent.predict = v end)
    knifeSec:AddSlider("KnifeRadius", {Title = "Радиус (студы)", Min = 5, Max = 60, Default = 20, Rounding = 0}):OnChanged(function(v) knifeSilent.radius = tonumber(v) or 20 end)
    knifeSec:AddSlider("KnifeFov", {Title = "FOV (градусы)", Min = 10, Max = 360, Default = 120, Rounding = 0}):OnChanged(function(v) knifeSilent.fov = tonumber(v) or 120 end)
    knifeSec:AddToggle("KnifeShowFov", {Title = "Показывать круг FOV", Default = true}):OnChanged(function(v) knifeSilent.showFov = v end)
    knifeSec:AddToggle("KnifeCheckWalls", {Title = "Проверять стены", Default = false}):OnChanged(function(v) knifeSilent.checkWalls = v end)

    local knifeBindOpt = knifeSec:AddKeybind("KnifeBind", {Title = "Кнопка броска", Default = "R"})
    knifeBindOpt:OnChanged(function(k)
        if typeof(k) == "EnumItem" then
            knifeSilent.bindKey = k
            Notify("FH", "Нож: " .. tostring(k), 2)
        end
    end)

    local function findKnifeTarget()
        local char = LocalPlayer.Character
        if not char then return nil end
        local myHRP = char:FindFirstChild("HumanoidRootPart")
        if not myHRP then return nil end

        local cam = Workspace.CurrentCamera
        if not cam then return nil end
        local myPos = myHRP.Position
        local look = cam.CFrame.LookVector

        local best, bestScore = nil, math.huge
        local cosLimit = math.cos(math.rad(knifeSilent.fov / 2))

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
                local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                if tHRP and tHum and tHum.Health > 0 then
                    local dir = tHRP.Position - myPos
                    local dist = dir.Magnitude
                    if dist <= knifeSilent.radius and dist > 0 then
                        local dirN = dir / dist
                        -- FIX: FOV в мировых координатах
                        local dot = look:Dot(dirN)
                        if dot >= cosLimit then
                            local ok = true
                            if knifeSilent.checkWalls then
                                local prm = RaycastParams.new()
                                prm.FilterType = Enum.RaycastFilterType.Exclude
                                prm.FilterDescendantsInstances = {char, p.Character}
                                local hit = Workspace:Raycast(myPos, dir, prm)
                                if hit then ok = false end
                            end
                            if ok then
                                local score = dist * (1.5 - dot)
                                if score < bestScore then
                                    bestScore = score
                                    best = tHRP
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function throwKnifeAtNearest()
        if not knifeSilent.enabled then
            Notify("FH", "Включи тихий бросок ножа", 2)
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        local knife = char:FindFirstChild("Knife")
        if not knife then
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            knife = bp and bp:FindFirstChild("Knife")
            if knife then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(knife) end
                task.wait(0.05)
            end
        end
        if not knife then
            Notify("FH", "Нужен нож", 2)
            return
        end

        local best = findKnifeTarget()
        if not best then
            Notify("FH", "Цель не найдена", 2)
            return
        end

        local events = knife:FindFirstChild("Events")
        if events then
            local throwRemote = events:FindFirstChild("KnifeThrown") or events:FindFirstChild("Throw")
            if throwRemote then
                pcall(function() throwRemote:FireServer(best) end)
            end
        end
        pcall(function() knife:Activate() end)
        Notify("FH", "Нож брошен!", 1.5)
    end

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == knifeSilent.bindKey then
            throwKnifeAtNearest()
        end
    end)

    local fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Transparency = 0.7
    fovCircle.NumSides = 64
    fovCircle.Radius = knifeSilent.fov
    fovCircle.Filled = false
    fovCircle.Visible = false

    AddConn("KnifeFovTick", RunService.RenderStepped:Connect(function()
        if knifeSilent.showFov and knifeSilent.enabled then
            fovCircle.Visible = true
            fovCircle.Position = UserInputService:GetMouseLocation()
            fovCircle.Radius = knifeSilent.fov
        else
            fovCircle.Visible = false
        end
    end))

    -- ============ KILL AURA ============
    local kaSec = tC:AddSection({Name = "Килл Аура"})

    kaSec:AddDropdown("KAVersion", {Title = "Версия", Values = {"v1", "v2"}, Default = "v2"}):OnChanged(function(v)
        killAuraVersion = v
        kaV1.on = false
        kaV2.on = false
        if Options.KAOn and Options.KAOn.Value then
            kaV1.on = v == "v1"
            kaV2.on = v == "v2"
        end
    end)

    kaSec:AddToggle("KAOn", {Title = "Включить", Default = false}):OnChanged(function(v)
        kaV1.on = v and killAuraVersion == "v1"
        kaV2.on = v and killAuraVersion == "v2"
    end)

    kaSec:AddSlider("KADist", {Title = "Радиус", Min = 5, Max = 60, Default = 30, Rounding = 0}):OnChanged(function(v)
        local n = tonumber(v) or 30
        kaV1.dist = n
        kaV2.dist = n
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
            for _, v in ipairs(victims) do
                pcall(function() touched:FireServer(v) end)
            end
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
            for _, v in ipairs(victims) do
                pcall(function() touched:FireServer(v) end)
            end
            kaV2.lastHit = tick()
        end
    end))

    -- ============ AUTOGRAB GUN ============
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

    local autoGrabEnabled = false
    local autoGrabToggle = tC:AddToggle("AutoGrabGun", {Title = "Авто-подбор пистолета", Default = false})
    autoGrabToggle:OnChanged(function(v)
        autoGrabEnabled = v
    end)

    AddConn("AutoGrabTick", RunService.Heartbeat:Connect(function()
        if not autoGrabEnabled then return end
        local myRole = getRoleFromData(LocalPlayer)
        if myRole == "murderer" then return end

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
                Notify("FH", "Пистолет не подобран.", 4)
            end
            isGrabbing = false
        end)
    end))

    AddConn("AutoGrabReset", LocalPlayer.CharacterAdded:Connect(function()
        isGrabbing = false
    end))

    print("[FH][INFO] Combat v18.1 готов")
end

-- ============================================================
-- MOVEMENT
-- ============================================================
do
    local tM = Window:AddTab({Title = "Движение"})
    Tabs.Movement = tM
    local mvSec = tM:AddSection({Name = "Основное"})

    mvSec:AddToggle("SpeedToggle", {Title = "Скорость", Default = false})
    mvSec:AddSlider("SpeedValue", {Title = "Скорость ходьбы", Min = 16, Max = 500, Default = 32, Rounding = 0})
    mvSec:AddToggle("FlyToggle", {Title = "Полёт", Default = false})
    mvSec:AddSlider("FlySpeed", {Title = "Скорость полёта", Min = 20, Max = 500, Default = 60, Rounding = 0})
    mvSec:AddToggle("Noclip", {Title = "Noclip", Default = false})
    mvSec:AddToggle("Spinbot", {Title = "Spinbot", Default = false})
    mvSec:AddSlider("SpinSpeed", {Title = "Скорость кручения", Min = 1, Max = 50, Default = 8, Rounding = 0})
    mvSec:AddToggle("InfJump", {Title = "Бесконечный прыжок", Default = false})
    mvSec:AddToggle("JumpPowerToggle", {Title = "Своя сила прыжка", Default = false})
    mvSec:AddSlider("JumpPowerVal", {Title = "Сила прыжка", Min = 50, Max = 500, Default = 100, Rounding = 0})

    AddConn("MovementTick", RunService.Heartbeat:Connect(function()
        local hum = getHum()
        if not hum then return end
        local speedOn = Options.SpeedToggle and Options.SpeedToggle.Value
        if speedOn then
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
        local jpOn = Options.JumpPowerToggle and Options.JumpPowerToggle.Value
        if jpOn then
            hum.UseJumpPower = true
            local jp = (Options.JumpPowerVal and tonumber(Options.JumpPowerVal.Value)) or 100
            if hum.JumpPower ~= jp then hum.JumpPower = jp end
        end
        local spinOn = Options.Spinbot and Options.Spinbot.Value
        if spinOn and getHRP() then
            local hrp = getHRP()
            local s = (Options.SpinSpeed and tonumber(Options.SpinSpeed.Value)) or 8
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(s), 0)
        end
    end))

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

    AddConn("InfJump", UserInputService.JumpRequest:Connect(function()
        local on = Options.InfJump and Options.InfJump.Value
        if on then
            local hum = getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))

    AddConn("FlyTick", RunService.RenderStepped:Connect(function()
        local on = Options.FlyToggle and Options.FlyToggle.Value
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then return end
        if on then
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
        elseif hum.PlatformStand then
            hum.PlatformStand = false
        end
    end))

    local freezeSec = tM:AddSection({Name = "Заморозка"})
    freezeSec:AddToggle("FreezeToggle", {Title = "Включить заморозку", Default = false}):OnChanged(function(v)
        S.frozen = v
    end)
    freezeSec:AddSlider("FreezeSpeed", {Title = "Скорость заморозки", Min = 20, Max = 300, Default = 60, Rounding = 0})
    local fUp = freezeSec:AddKeybind("FreezeUpKey", {Title = "Кнопка ВВЕРХ", Default = "Space"})
    fUp:OnChanged(function(k)
        if typeof(k) == "EnumItem" then S.freezeUpKey = k end
    end)
    local fDown = freezeSec:AddKeybind("FreezeDownKey", {Title = "Кнопка ВНИЗ", Default = "LeftAlt"})
    fDown:OnChanged(function(k)
        if typeof(k) == "EnumItem" then S.freezeDownKey = k end
    end)

    print("[FH][INFO] Movement v18.1 готов")
end

-- ============================================================
-- SETTINGS (FIX: РАБОЧАЯ СМЕНА КНОПКИ МЕНЮ)
-- ============================================================
do
    local tS = Window:AddTab({Title = "Настройки"})
    Tabs.Settings = tS
    local setSec = tS:AddSection({Name = "Основные"})

    setSec:AddToggle("ShowHUD", {Title = "Показывать HUD", Default = true}):OnChanged(function(v)
        if HUDGui then HUDGui.Enabled = v end
    end)

    setSec:AddSlider("FPSCap", {Title = "Лимит FPS (0 = без лимита)", Min = 0, Max = 9999, Default = 0, Rounding = 0}):OnChanged(function(v)
        pcall(function() if setfpscap then setfpscap(tonumber(v) or 0) end end)
    end)

    -- FIX: наш собственный бинд поверх Fluent, меняем глобальную MenuKey
    local menuKeyOpt = setSec:AddKeybind("MenuKeyBind", {Title = "Клавиша открытия меню", Default = "P"})
    menuKeyOpt:OnChanged(function(k)
        if typeof(k) == "EnumItem" then
            MenuKey = k
            Notify("FH", "Меню: " .. tostring(k), 2)
        end
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

    setSec:AddToggle("AntiAFK", {Title = "Anti-AFK", Default = true})
    AddConn("AntiAFKv18", LocalPlayer.Idled:Connect(function()
        if Options.AntiAFK and Options.AntiAFK.Value then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
            end)
        end
    end))

    setSec:AddButton({Title = "Выгрузить скрипт", Callback = function()
        for _, c in pairs(Connections) do pcall(function() c:Disconnect() end) end
        Connections = {}
        if HUDGui then HUDGui:Destroy() end
        if Window then pcall(function() Window:Destroy() end) end
        Notify("FH", "Скрипт выгружен", 3)
    end})

    if HUDGui then HUDGui.Enabled = true end
end

-- ============================================================
-- ФИНАЛЬНАЯ ОБВЯЗКА
-- ============================================================
pcall(function() Window:SelectTab(1) end)

print("[FH][INFO] ================================")
print("[FH][INFO] PART 1/2 v18.1 FIXED ЗАГРУЖЕН")
print("[FH][INFO] ================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "Часть 1/2 v18.1 FIXED загружена! Меню — по своей кнопке", 5)
end)
-- ============================================================
-- ПАТЧ 18.3 — ФИНАЛЬНЫЙ ФИКС КНОПКИ МЕНЮ
-- Перебиваем СЛОМАННЫЕ методы Fluent (Minimize, Toggle и т.д.)
-- своими безопасными версиями. Ошибок больше не будет.
-- ============================================================
task.spawn(function()
    task.wait(2)

    local UIS = game:GetService("UserInputService")
    local CoreGuiSvc = game:GetService("CoreGui")
    local LocalPlr = game:GetService("Players").LocalPlayer
    local PatchKey = Enum.KeyCode.P
    local fluentGui = nil

    local function findGui()
        if fluentGui and fluentGui.Parent then return fluentGui end
        local parents = {CoreGuiSvc, LocalPlr:FindFirstChild("PlayerGui")}
        for _, p in ipairs(parents) do
            if p then
                for _, g in ipairs(p:GetChildren()) do
                    if g:IsA("ScreenGui") and g.Name ~= "FH_HUD_v18" then
                        local hasMain = g:FindFirstChild("Main", true)
                            or g:FindFirstChild("Window", true)
                            or g:FindFirstChildWhichIsA("Frame", true)
                        if hasMain then
                            fluentGui = g
                            return g
                        end
                    end
                end
            end
        end
        return nil
    end

    -- Перебиваем сломанные методы Fluent СВОИМИ безопасными
    if Window then
        local function safeToggle()
            local g = findGui()
            if g then g.Enabled = not g.Enabled end
        end
        Window.Minimize = safeToggle
        Window.ToggleMinimize = safeToggle
        Window.Toggle = safeToggle
        Window.Open = function() local g = findGui(); if g then g.Enabled = true end end
        Window.Close = function() local g = findGui(); if g then g.Enabled = false end end
        Window.Show = Window.Open
        Window.Hide = Window.Close

        -- отрубаем встроенный бинд Fluent, чтобы не конфликтовал
        pcall(function() Window.MinimizeKey = Enum.KeyCode.Unknown end)
    end

    -- наш собственный обработчик
    UIS.InputBegan:Connect(function(input, gpe)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode ~= PatchKey then return end
        local g = findGui()
        if g then g.Enabled = not g.Enabled end
    end)

    -- синхронизация с настройкой "Клавиша открытия меню"
    task.spawn(function()
        while not Options or not Options.MenuKeyBind do task.wait(0.2) end
        Options.MenuKeyBind:OnChanged(function(k)
            if typeof(k) == "EnumItem" then
                PatchKey = k
            end
        end)
        pcall(function()
            local v = Options.MenuKeyBind.Value
            if typeof(v) == "EnumItem" then PatchKey = v end
        end)
    end)

    print("[FH][PATCH 18.3] Menu key override done, default P")
end)
-- ============================================================
-- FORTNIHUB v18.1 — ЧАСТЬ 2/2: Visuals + Effects + Farm + Tools + Anti + Sounds + Anim + Vote + Configs
-- FIXED BUILD — by Bean
-- ============================================================

-- ============================================================
-- ESP ENGINE (FIXED: чамсы теперь на всех, Adornee обновляется)
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
        chamsFHero = {Color3.fromRGB(255, 215, 0), 0.5}, chamsOHero = {Color3.fromRGB(255, 215, 0), 0},
        matChams = false, matType = "ForceField",
        matColMur = Color3.fromRGB(255, 60, 60),
        matColInno = Color3.new(1, 1, 1),
        matColShf = Color3.fromRGB(0, 153, 255),
        matColHero = Color3.fromRGB(255, 215, 0),
        flags = false,
        flagMur = {Color3.fromRGB(255, 60, 60), 1}, flagShf = {Color3.fromRGB(0, 153, 255), 1},
        flagHero = {Color3.fromRGB(255, 215, 0), 1},
        arrows = false,
        arrowMur = Color3.fromRGB(255, 60, 60),
        arrowInno = Color3.new(1, 1, 1),
        arrowShf = Color3.fromRGB(0, 153, 255),
        arrowHero = Color3.fromRGB(255, 215, 0),
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
        local r = getRoleFromData(p)
        if r == "murderer" then return "murder" end
        if r == "sheriff" then return "sheriff" end
        if r == "hero" then return "hero" end
        return "inno"
    end

    local function roleColor(role)
        if role == "murder" then return Color3.fromRGB(255, 60, 60) end
        if role == "sheriff" then return Color3.fromRGB(0, 153, 255) end
        if role == "hero" then return Color3.fromRGB(255, 215, 0) end
        return Color3.new(1, 1, 1)
    end

    local function grad(c1, c2)
        local t = math.sin(os.clock() * 3) * 0.5 + 0.5
        return c1:Lerp(c2, t)
    end

    -- FIX: чамсы обновляются для ВСЕХ игроков, Adornee ре-сетапится при респавне
    local function updateChams(p, role)
        if not esp.chams then
            local h = chamsFolder:FindFirstChild(p.Name)
            if h then h:Destroy() end
            return
        end
        local char = p.Character
        if not char then
            local h = chamsFolder:FindFirstChild(p.Name)
            if h then h:Destroy() end
            return
        end
        local h = chamsFolder:FindFirstChild(p.Name)
        if not h then
            h = Instance.new("Highlight")
            h.Name = p.Name
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = chamsFolder
        end
        -- FIX: обновляем Adornee при смене персонажа
        if h.Adornee ~= char then
            h.Adornee = char
        end
        local rk
        if role == "murder" then rk = "Mur"
        elseif role == "sheriff" then rk = "Shf"
        elseif role == "hero" then rk = "Hero"
        else rk = "Inno" end
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
                local col
                if role == "murder" then col = esp.matColMur
                elseif role == "sheriff" then col = esp.matColShf
                elseif role == "hero" then col = esp.matColHero
                else col = esp.matColInno end
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

            -- FIX: сначала обновляем чамсы для ВСЕХ игроков (даже вне камеры)
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer and not esp.allowLocal then continue end
                if p.Character then
                    local role = classifyRole(p)
                    updateChams(p, role)
                else
                    local h = chamsFolder:FindFirstChild(p.Name)
                    if h then h:Destroy() end
                end
            end

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
                    -- чамсы уже обновлены выше
                    continue
                end

                local role = classifyRole(p)
                local dcol = roleColor(role)
                local dist = (cam.CFrame.Position - hrp.Position).Magnitude
                local fade = math.clamp(1 - dist / esp.maxDist, 0.15, 1)

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

                if esp.flags then
                    local txt = role == "murder" and "[MURD]" or (role == "sheriff" and "[SHF]" or (role == "hero" and "[HERO]" or ""))
                    if txt ~= "" then
                        if not e.flags[1] then
                            e.flags[1] = Drawing.new("Text")
                            e.flags[1].Size = 13
                            e.flags[1].Outline = true
                        end
                        local d = e.flags[1]
                        d.Text = txt
                        d.Position = Vector2.new(hsp.X + 60, hsp.Y - 10)
                        d.Color = role == "murder" and esp.flagMur[1] or (role == "hero" and esp.flagHero[1] or esp.flagShf[1])
                        d.Transparency = fade
                        d.Visible = true
                        for i = 2, #e.flags do e.flags[i].Visible = false end
                    else
                        for _, d in pairs(e.flags) do d.Visible = false end
                    end
                else
                    for _, d in pairs(e.flags) do d.Visible = false end
                end

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
                            or (role == "sheriff" and esp.arrowShf or (role == "hero" and esp.arrowHero or esp.arrowInno))
                        e.arrow.Transparency = fade
                        e.arrow.Visible = true
                    end
                elseif e.arrow then e.arrow.Visible = false end
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

    local tV = Window:AddTab({Title = "Визуал"})
    Tabs.Visual = tV
    local espSec = tV:AddSection({Name = "ESP Игроков"})

    espSec:AddToggle("ESPOn", {Title = "Включить ESP", Default = false}):OnChanged(function(v)
        esp.on = v
        if v then startRender() else stopRender() end
        Notify("FH", "ESP " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    espSec:AddToggle("ESPBox", {Title = "Рамка", Default = false}):OnChanged(function(v) esp.box = v end)
    espSec:AddColorPicker("ESPBoxCol", {Title = "Цвет рамки", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.boxCol[1] = c end)
    espSec:AddSlider("ESPBoxAlpha", {Title = "Прозрачность рамки", Min = 0, Max = 1, Default = 1, Rounding = 2}):OnChanged(function(v) esp.boxCol[2] = tonumber(v) or 1 end)
    espSec:AddDropdown("ESPBoxType", {Title = "Тип рамки", Values = {"Прямоугольник", "Уголки"}, Default = "Прямоугольник"}):OnChanged(function(v)
        esp.boxType = (v == "Уголки") and "Corners" or "Static"
    end)
    espSec:AddToggle("ESPBoxGrd", {Title = "Градиент рамки", Default = false}):OnChanged(function(v) esp.boxGrd = v end)
    espSec:AddColorPicker("ESPBoxGrd1", {Title = "Цвет 1", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.boxGrd1 = c end)
    espSec:AddColorPicker("ESPBoxGrd2", {Title = "Цвет 2", Default = Color3.fromRGB(255, 180, 60)}):OnChanged(function(c) esp.boxGrd2 = c end)
    espSec:AddToggle("ESPBoxFill", {Title = "Заливка", Default = false}):OnChanged(function(v) esp.boxFill = v end)
    espSec:AddColorPicker("ESPBoxFillCol", {Title = "Цвет заливки", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.boxFillCol[1] = c end)
    espSec:AddSlider("ESPBoxFillAlpha", {Title = "Прозрачность заливки", Min = 0, Max = 1, Default = 0.5, Rounding = 2}):OnChanged(function(v) esp.boxFillCol[2] = tonumber(v) or 0.5 end)

    espSec:AddToggle("ESPName", {Title = "Имя", Default = false}):OnChanged(function(v) esp.name = v end)
    espSec:AddColorPicker("ESPNameCol", {Title = "Цвет имени", Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.nameCol[1] = c end)

    espSec:AddToggle("ESPDist", {Title = "Дистанция", Default = false}):OnChanged(function(v) esp.dist = v end)
    espSec:AddColorPicker("ESPDistCol", {Title = "Цвет дистанции", Default = Color3.fromRGB(220, 220, 220)}):OnChanged(function(c) esp.distCol[1] = c end)

    espSec:AddToggle("ESPAvatar", {Title = "Аватарка", Default = false}):OnChanged(function(v) esp.avatar = v end)

    espSec:AddToggle("ESPSkel", {Title = "Скелет", Default = false}):OnChanged(function(v) esp.skel = v end)
    espSec:AddColorPicker("ESPSkelCol", {Title = "Цвет скелета", Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.skelCol[1] = c end)

    espSec:AddToggle("ESPChams", {Title = "Свечение (Chams)", Default = false}):OnChanged(function(v) esp.chams = v end)
    espSec:AddColorPicker("ESPChamsFMur", {Title = "Убийца заливка", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.chamsFMur[1] = c end)
    espSec:AddColorPicker("ESPChamsOMur", {Title = "Убийца обводка", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.chamsOMur[1] = c end)
    espSec:AddColorPicker("ESPChamsFInno", {Title = "Мирный заливка", Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.chamsFInno[1] = c end)
    espSec:AddColorPicker("ESPChamsOInno", {Title = "Мирный обводка", Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.chamsOInno[1] = c end)
    espSec:AddColorPicker("ESPChamsFShf", {Title = "Шериф заливка", Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.chamsFShf[1] = c end)
    espSec:AddColorPicker("ESPChamsOShf", {Title = "Шериф обводка", Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.chamsOShf[1] = c end)
    espSec:AddColorPicker("ESPChamsFHero", {Title = "Герой заливка", Default = Color3.fromRGB(255, 215, 0)}):OnChanged(function(c) esp.chamsFHero[1] = c end)
    espSec:AddColorPicker("ESPChamsOHero", {Title = "Герой обводка", Default = Color3.fromRGB(255, 215, 0)}):OnChanged(function(c) esp.chamsOHero[1] = c end)

    espSec:AddToggle("ESPMatChams", {Title = "Материал-чамсы", Default = false}):OnChanged(function(v) esp.matChams = v end)
    espSec:AddDropdown("ESPMatType", {Title = "Тип материала", Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"}):OnChanged(function(v) esp.matType = v end)
    espSec:AddColorPicker("ESPMatMur", {Title = "Убийца", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.matColMur = c end)
    espSec:AddColorPicker("ESPMatInno", {Title = "Мирный", Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.matColInno = c end)
    espSec:AddColorPicker("ESPMatShf", {Title = "Шериф", Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.matColShf = c end)
    espSec:AddColorPicker("ESPMatHero", {Title = "Герой", Default = Color3.fromRGB(255, 215, 0)}):OnChanged(function(c) esp.matColHero = c end)

    espSec:AddToggle("ESPFlags", {Title = "Метки ролей", Default = false}):OnChanged(function(v) esp.flags = v end)

    espSec:AddToggle("ESPArrows", {Title = "Стрелки к игрокам", Default = false}):OnChanged(function(v) esp.arrows = v end)
    espSec:AddColorPicker("ESPArrMur", {Title = "Убийца", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) esp.arrowMur = c end)
    espSec:AddColorPicker("ESPArrInno", {Title = "Мирный", Default = Color3.new(1, 1, 1)}):OnChanged(function(c) esp.arrowInno = c end)
    espSec:AddColorPicker("ESPArrShf", {Title = "Шериф", Default = Color3.fromRGB(0, 153, 255)}):OnChanged(function(c) esp.arrowShf = c end)
    espSec:AddColorPicker("ESPArrHero", {Title = "Герой", Default = Color3.fromRGB(255, 215, 0)}):OnChanged(function(c) esp.arrowHero = c end)
    espSec:AddSlider("ESPArrSz", {Title = "Размер стрелок", Min = 16, Max = 96, Default = 42, Rounding = 0}):OnChanged(function(v) esp.arrowSize = tonumber(v) or 42 end)
    espSec:AddSlider("ESPArrDist", {Title = "Дистанция стрелок", Min = 40, Max = 520, Default = 260, Rounding = 0}):OnChanged(function(v) esp.arrowDist = tonumber(v) or 260 end)

    espSec:AddToggle("ESPAllowLocal", {Title = "Показывать себя", Default = false}):OnChanged(function(v) esp.allowLocal = v end)

    print("[FH][INFO] ESP Engine v18.1 готов")
end

-- ============================================================
-- EFFECTS
-- ============================================================
do
    local tE = Window:AddTab({Title = "Эффекты"})
    Tabs.Effects = tE

    -- TRACER
    local tracerSec = tE:AddSection({Name = "Трассер пули"})
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
    tracerSec:AddColorPicker("TracerCol", {Title = "Цвет", Default = Color3.fromRGB(133, 220, 255)}):OnChanged(function(c) tracerCol = c end)
    tracerSec:AddSlider("TracerDur", {Title = "Длительность", Min = 0.1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v) tracerDur = tonumber(v) or 1 end)

    -- ============================================================
    -- AURA (FIXED: МУЛЬТИВЫБОР)
    -- ============================================================
    local auraSec = tE:AddSection({Name = "Аура (мультивыбор)"})
    local auraOn, auraCol = false, Color3.fromRGB(133, 220, 255)
    local auraSelected = {}  -- FIX: таблица выбранных аур
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
    local auraNames = {"angel", "starlight", "heavenly", "ribbon", "sakura", "wind", "flow", "star"}
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
        -- FIX: применяем ВСЕ выбранные ауры
        for auraType in pairs(auraSelected) do
            local src = loadAura(auraType)
            if src then
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
        end
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
    -- FIX: Multi = true
    local auraDrop = auraSec:AddDropdown("AuraType", {
        Title = "Аура (можно несколько)",
        Values = auraNames,
        Multi = true,
        Default = {},
    })
    auraDrop:OnChanged(function(v)
        auraSelected = {}
        if type(v) == "table" then
            for _, name in ipairs(v) do auraSelected[name] = true end
        elseif type(v) == "string" then
            auraSelected[v] = true
        end
        if auraOn then task.spawn(applyAura) end
    end)
    auraSec:AddColorPicker("AuraCol", {Title = "Цвет", Default = Color3.fromRGB(133, 220, 255)}):OnChanged(function(c)
        auraCol = c
        for _, m in pairs(auraCache) do colorAura(m, c) end
        if auraOn then task.spawn(applyAura) end
    end)

    -- WORLD FX
    local fxSec = tE:AddSection({Name = "Эффекты мира"})
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
    fxSec:AddDropdown("FXType", {Title = "Тип", Values = {"Снег", "Сакура"}, Default = "Снег"}):OnChanged(function(v)
        fxType = (v == "Сакура") and "Sakura" or "Snow"
        if fxOn then styleFX() end
    end)
    fxSec:AddColorPicker("FXCol", {Title = "Цвет", Default = Color3.fromRGB(150, 200, 255)}):OnChanged(function(c)
        fxCol = c
        if fxEmit then fxEmit.Color = ColorSequence.new(c) end
    end)
    fxSec:AddSlider("FXRate", {Title = "Интенсивность", Min = 20, Max = 900, Default = 250, Rounding = 1}):OnChanged(function(v)
        fxRate = tonumber(v) or 250
        if fxEmit then styleFX() end
    end)

    -- SHADERS
    local shaderSec = tE:AddSection({Name = "Шейдеры"})
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
        Title = "Пресет",
        Values = {"Утро", "День", "Вечер", "Ночь"},
        Default = "Утро",
    }):OnChanged(function(v)
        local map = {["Утро"]="morning", ["День"]="midday", ["Вечер"]="evening", ["Ночь"]="night"}
        shaderType = map[v] or "morning"
        if shaderOn then applyShader() end
    end)

    -- WORLD
    local wSec = tE:AddSection({Name = "Мир"})

    local fogOn, fogCol, fogStart, fogEnd = false, Color3.fromRGB(192, 192, 192), 0, 1000
    wSec:AddToggle("FogOn", {Title = "Свой туман", Default = false}):OnChanged(function(v)
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
    wSec:AddColorPicker("FogCol", {Title = "Цвет", Default = Color3.fromRGB(192, 192, 192)}):OnChanged(function(c)
        fogCol = c
        if fogOn then Lighting.FogColor = c end
    end)
    wSec:AddSlider("FogStart", {Title = "Начало", Min = 0, Max = 1000, Default = 0, Rounding = 0}):OnChanged(function(v)
        fogStart = tonumber(v) or 0
        if fogOn then Lighting.FogStart = fogStart end
    end)
    wSec:AddSlider("FogEnd", {Title = "Конец", Min = 0, Max = 1000, Default = 1000, Rounding = 0}):OnChanged(function(v)
        fogEnd = tonumber(v) or 1000
        if fogOn then Lighting.FogEnd = fogEnd end
    end)

    local ambOn, ambCol = false, Color3.fromRGB(128, 128, 128)
    wSec:AddToggle("AmbOn", {Title = "Свой ambient", Default = false}):OnChanged(function(v)
        ambOn = v
        if v then
            Lighting.Ambient = ambCol
            Lighting.OutdoorAmbient = ambCol
        else
            Lighting.Ambient = origLight.Amb
            Lighting.OutdoorAmbient = origLight.OA
        end
    end)
    wSec:AddColorPicker("AmbCol", {Title = "Цвет ambient", Default = Color3.fromRGB(128, 128, 128)}):OnChanged(function(c)
        ambCol = c
        if ambOn then
            Lighting.Ambient = c
            Lighting.OutdoorAmbient = c
        end
    end)

    local expOn, expVal = false, 0
    wSec:AddToggle("ExpOn", {Title = "Экспозиция", Default = false}):OnChanged(function(v)
        expOn = v
        if v then Lighting.ExposureCompensation = expVal
        else Lighting.ExposureCompensation = origLight.Exp end
    end)
    wSec:AddSlider("ExpVal", {Title = "Значение", Min = -5, Max = 5, Default = 0, Rounding = 2}):OnChanged(function(v)
        expVal = tonumber(v) or 0
        if expOn then Lighting.ExposureCompensation = expVal end
    end)

    -- SKYBOX
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

    wSec:AddToggle("SkyOn", {Title = "Небо", Default = false}):OnChanged(function(v)
        skyOn = v
        if v then applySky(skyName) else restoreSky() end
    end)
    wSec:AddDropdown("SkyName", {
        Title = "Пресет",
        Values = {"Jungle", "Blossom", "Red night", "Purple", "Foggy", "Galaxy", "Anime", "Minecraft"},
        Default = "Jungle",
    }):OnChanged(function(v)
        skyName = v
        if skyOn then applySky(v) end
    end)

    print("[FH][INFO] Effects v18.1 готов")
end

-- ============================================================
-- MURDER DEATH EFFECT
-- ============================================================
do
    local meSec = Tabs.Effects:AddSection({Name = "Эффект при смерти убийцы"})
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
            mAddConn = Players.PlayerAdded:Connect(function(pl)
                if pl ~= LocalPlayer then hookPlayer(pl) end
            end)
        else
            stopMurder()
            if mThread then pcall(function() task.cancel(mThread) end) mThread = nil end
        end
    end)
    meSec:AddToggle("MEClone", {Title = "Клон", Default = false}):OnChanged(function(v) mCloneOn = v end)
    meSec:AddColorPicker("MECloneCol", {Title = "Цвет клона", Default = Color3.fromRGB(255, 0, 0)}):OnChanged(function(c)
        mCloneCol = c
        for _, cl in ipairs(mClones) do
            for _, d in ipairs(cl:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then d.Color = c end
            end
        end
    end)
    meSec:AddSlider("MECloneDur", {Title = "Длительность клона", Min = 1, Max = 5, Default = 3, Rounding = 1}):OnChanged(function(v) mCloneDur = tonumber(v) or 3 end)
    meSec:AddToggle("MEPart", {Title = "Частицы", Default = false}):OnChanged(function(v) mPartOn = v end)
    meSec:AddColorPicker("MEPartCol", {Title = "Цвет частиц", Default = Color3.fromRGB(255, 0, 0)}):OnChanged(function(c) mPartCol = c end)
    meSec:AddToggle("MEEmit", {Title = "Neverlose emitter", Default = false}):OnChanged(function(v) mEmitOn = v end)
    meSec:AddColorPicker("MEEmitCol", {Title = "Цвет emitter", Default = Color3.fromRGB(255, 100, 100)}):OnChanged(function(c)
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
    meSec:AddSlider("MEEmitDur", {Title = "Длительность emitter", Min = 1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v) mEmitDur = tonumber(v) or 1 end)

    print("[FH][INFO] Murder Effect v18.1 готов")
end

-- ============================================================
-- LOCAL VISUALS (FIXED: bэктрек после респавна)
-- ============================================================
do
    local lvSec = Tabs.Visual:AddSection({Name = "Свои визуалы"})

    -- CHINA HAT
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

    lvSec:AddToggle("ChinaHatOn", {Title = "Китайская шляпа", Default = false}):OnChanged(function(v)
        chOn = v
        if v then
            if not chConn then
                chConn = RunService.RenderStepped:Connect(function()
                    if chOn then chUpdate() end
                end)
            end
        else
            if chConn then pcall(function() chConn:Disconnect() end) chConn = nil end
            chClear()
        end
    end)
    lvSec:AddColorPicker("ChinaHatCol", {Title = "Цвет шляпы", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c) chCol = c end)

    -- ============================================================
    -- BACKTRACK (FIXED: перестройка при респавне)
    -- ============================================================
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

    lvSec:AddToggle("BacktrackOn", {Title = "Бэктрек", Default = false}):OnChanged(function(v)
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
    lvSec:AddColorPicker("BacktrackCol", {Title = "Цвет", Default = Color3.fromRGB(255, 60, 60)}):OnChanged(function(c)
        btCol = c
        if btModel then
            for _, p in ipairs(btModel:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Color = c end
            end
        end
    end)

    -- FIX: перестройка бэктрэка при респавне
    AddConn("BacktrackRespawn", LocalPlayer.CharacterAdded:Connect(function()
        btKill()
        if btOn then
            task.wait(0.4)
            if btOn then btBuild() end
        end
    end))

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

    lvSec:AddToggle("LandCircleOn", {Title = "Круг падения", Default = false}):OnChanged(function(v)
        lcOn = v
        if v then lcBind()
        elseif lcConn then pcall(function() lcConn:Disconnect() end) lcConn = nil end
    end)
    lvSec:AddColorPicker("LandCircleCol", {Title = "Цвет", Default = Color3.new(1, 1, 1)}):OnChanged(function(c) lcCol = c end)
    lvSec:AddSlider("LandCircleTr", {Title = "Прозрачность", Min = 0, Max = 1, Default = 1, Rounding = 2}):OnChanged(function(v) lcTr = tonumber(v) or 1 end)
    lvSec:AddSlider("LandCircleDur", {Title = "Длительность", Min = 0.1, Max = 3, Default = 0.82, Rounding = 2}):OnChanged(function(v) lcDur = tonumber(v) or 0.82 end)

    -- MOVEMENT GRAPH
    local mgOn, mgCol = false, Color3.fromRGB(242, 242, 242)
    local mgWidth, mgHeight, mgOffset = 280, 72, 180
    local mgLines, mgShadows = {}, {}
    local mgCurrent, mgConn = nil, nil
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

    local function mgStart()
        mgClear()
        mgSmooth = mgSpeed()
        local now = os.clock()
        local cnt = math.ceil(mgSpan / mgStep)
        for i = 0, cnt do
            mgHist[#mgHist + 1] = {t = now - mgSpan + i * mgStep, v = mgSmooth}
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
                mgHist[#mgHist + 1] = {t = now, v = mgSmooth}
                local cutoff = now - mgSpan
                while #mgHist > 2 and mgHist[2].t < cutoff do table.remove(mgHist, 1) end
            end

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

    lvSec:AddToggle("MovGraphOn", {Title = "График скорости", Default = false}):OnChanged(function(v)
        mgOn = v
        if v then mgStart() else mgClear() end
    end)
    lvSec:AddColorPicker("MovGraphCol", {Title = "Цвет графика", Default = Color3.fromRGB(242, 242, 242)}):OnChanged(function(c)
        mgCol = c
        for i = 1, #mgLines do mgLines[i].Color = c end
    end)
    lvSec:AddSlider("MovGraphW", {Title = "Ширина", Min = 180, Max = 420, Default = 280, Rounding = 0}):OnChanged(function(v) mgWidth = tonumber(v) or 280 end)
    lvSec:AddSlider("MovGraphH", {Title = "Высота", Min = 40, Max = 120, Default = 72, Rounding = 0}):OnChanged(function(v) mgHeight = tonumber(v) or 72 end)
    lvSec:AddSlider("MovGraphY", {Title = "Смещение по Y", Min = -200, Max = 400, Default = 180, Rounding = 0}):OnChanged(function(v) mgOffset = tonumber(v) or 180 end)

    print("[FH][INFO] Local Visuals v18.1 готов")
end

-- ============================================================
-- SELF/TOOL CHAMS
-- ============================================================
do
    local scSec = Tabs.Visual:AddSection({Name = "Чамсы на себе и оружии"})
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

    scSec:AddToggle("SCOn", {Title = "Чамсы на себе", Default = false}):OnChanged(function(v)
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
    scSec:AddDropdown("SCType", {Title = "Пресет", Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"}):OnChanged(function(v) scType = v end)
    scSec:AddColorPicker("SCCol", {Title = "Цвет", Default = Color3.fromRGB(0, 200, 255)}):OnChanged(function(c) scCol = c end)

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

    scSec:AddToggle("TCOn", {Title = "Чамсы оружия", Default = false}):OnChanged(function(v)
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
    scSec:AddDropdown("TCType", {Title = "Пресет", Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"}):OnChanged(function(v) tcType = v end)
    scSec:AddColorPicker("TCCol", {Title = "Цвет", Default = Color3.fromRGB(255, 200, 0)}):OnChanged(function(c) tcCol = c end)

    print("[FH][INFO] Self/Tool Chams v18.1 готов")
end

-- ============================================================
-- AUTOFARM (FIXED: фоллбэк по имени, более безопасное движение)
-- ============================================================
do
    local tF = Window:AddTab({Title = "Фарм"})
    Tabs.Farm = tF
    local farmSec = tF:AddSection({Name = "Автофарм"})

    local farm_on = false
    local farm_speed = 23
    local farm_avoid = false
    local farm_autoreset = false
    local farm_version = "v2"
    local nc_cache = {}
    local last_touch = 0
    local mhrp_cache, mhrp_t = nil, 0
    local saw_coins = false
    local done_flag = false
    local collected = {}

    local DISABLE_LIST = {
        "SilentEnabled", "SilentAuto", "SilentForce",
        "KAOn", "KnifeSilentOn", "KnifeInsta",
        "SpeedToggle", "FlyToggle", "Noclip", "Spinbot",
        "InfJump", "JumpPowerToggle", "BhopOn", "BhopStrafe", "BhopAuto",
        "SpeedGlitchOn",
    }

    local saved_states = {}

    local function hrp()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function can_farm()
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return false end
        local d = getRoundData()
        if type(d) == "table" then
            local me = d[LocalPlayer.Name]
            if not me or not me.Role or me.Dead then return false end
        end
        return true
    end

    local function bags_full()
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

    local function reset_progress()
        collected = {}
        done_flag = false
        saw_coins = false
    end

    task.spawn(function()
        local ok, r = pcall(function()
            return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("CoinsStarted", 15)
        end)
        if ok and r then r.OnClientEvent:Connect(reset_progress) end
    end)
    LocalPlayer.CharacterAdded:Connect(reset_progress)

    local function coin_ok(v)
        return v and v.Parent and v:IsA("BasePart")
            and not v:GetAttribute("Collected") and not v:GetAttribute("Delete")
    end

    -- FIX: фоллбэк по имени, если CollectionService пуст
    local coinCacheList, lastCoinScan = {}, 0
    local function coin_list()
        local now = os.clock()
        if now - lastCoinScan < 0.3 then return coinCacheList end
        lastCoinScan = now
        local out = {}
        local seen = {}
        for _, v in ipairs(CollectionService:GetTagged("CoinVisual")) do
            if coin_ok(v) and not seen[v] then out[#out + 1] = v; seen[v] = true end
        end
        if #out == 0 then
            local container = Workspace:FindFirstChild("CoinContainer")
                or Workspace:FindFirstChild("Coins")
                or Workspace:FindFirstChild("CoinFolder")
            local scanRoot = container or Workspace
            local list = container and container:GetDescendants() or Workspace:GetChildren()
            for _, v in ipairs(list) do
                if v:IsA("BasePart") and not seen[v] and coin_ok(v) then
                    local n = v.Name:lower()
                    if n:find("coin") then
                        out[#out + 1] = v; seen[v] = true
                    end
                end
            end
        end
        coinCacheList = out
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
        local c = LocalPlayer.Character
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
        local d = getRoundData()
        if type(d) ~= "table" then return nil end
        for name, info in pairs(d) do
            if type(info) == "table" and info.Role == "Murderer"
                and not info.Dead and name ~= LocalPlayer.Name then
                local pl = Players:FindFirstChild(name)
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
        local step = math.min(farm_speed * dt, dist)
        local cf = CFrame.new(my.Position + dir.Unit * step)
        pcall(function()
            my.CFrame = cf
            my.AssemblyLinearVelocity = Vector3.zero
            my.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local function silence_features()
        table.clear(saved_states)
        for _, name in ipairs(DISABLE_LIST) do
            local opt = Options[name]
            if opt and opt.Value ~= nil then
                saved_states[name] = opt.Value
                pcall(function()
                    if opt.Value then opt:SetValue(false) end
                end)
            end
        end
    end

    local function restore_features()
        for name, val in pairs(saved_states) do
            local opt = Options[name]
            if opt and val then
                pcall(function() opt:SetValue(true) end)
            end
        end
        saved_states = {}
    end

    local function farm_loop(dt)
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
                if farm_autoreset then
                    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if h then pcall(function() h.Health = 0 end) end
                end
            end
            return
        end

        if #list == 0 then
            set_noclip(false)
            if saw_coins and not done_flag then
                done_flag = true
                if farm_autoreset then
                    local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if h then pcall(function() h.Health = 0 end) end
                end
            end
            return
        end

        saw_coins = true
        if done_flag then done_flag = false end

        local mh = farm_avoid and murderer_hrp() or nil
        local mp = mh and mh.Position or nil

        if mp and (mp - my.Position).Magnitude < 40 then
            local away = my.Position - mp
            if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
            away = Vector3.new(away.X, 0, away.Z).Unit
            set_noclip(true)
            move_to(my, my.Position + away * 25, dt)
            return
        end

        local best
        if farm_avoid and mp then
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
    end

    local function farm_v1(dt)
        if not can_farm() then return end
        local char = LocalPlayer.Character
        local my = char:FindFirstChild("HumanoidRootPart")
        if not my then return end
        local coins = coin_list()
        if #coins == 0 then return end
        local best = nearest(my.Position, coins)
        if not best then return end
        local dir = best.Position - my.Position
        local dist = dir.Magnitude
        if dist > 0.5 then
            local step = math.min(farm_speed * dt, dist)
            pcall(function()
                my.CFrame = CFrame.new(my.Position + dir.Unit * step)
                my.AssemblyLinearVelocity = Vector3.zero
            end)
        end
        if dist < 6 then fire_touch(best) end
    end

    AddConn("FarmTickV18", RunService.Heartbeat:Connect(function(_, dt)
        if not farm_on then return end
        if farm_version == "v1" then
            pcall(farm_v1, dt)
        else
            pcall(farm_loop, dt)
        end
    end))

    farmSec:AddDropdown("FarmVersion", {
        Title = "Версия автофарма",
        Values = {"v1 (простой)", "v2 (продвинутый)"},
        Default = "v2 (продвинутый)",
    }):OnChanged(function(v)
        farm_version = v:sub(1, 2) == "v1" and "v1" or "v2"
        Notify("FH", "Фарм: " .. farm_version, 2)
    end)

    farmSec:AddToggle("FarmOn", {Title = "Включить автофарм", Default = false}):OnChanged(function(v)
        farm_on = v
        if v then
            silence_features()
            Notify("FH", "Автофарм ВКЛ — комбат и мув заглушены", 2)
        else
            restore_features()
            set_noclip(false)
            Notify("FH", "Автофарм ВЫКЛ — всё вернулось", 2)
        end
    end)

    farmSec:AddSlider("FarmSpeed", {Title = "Скорость фарма", Min = 5, Max = 60, Default = 23, Rounding = 1}):OnChanged(function(v)
        farm_speed = tonumber(v) or 23
    end)

    farmSec:AddToggle("FarmAvoid", {Title = "Избегать маньяка", Default = false}):OnChanged(function(v) farm_avoid = v end)
    farmSec:AddToggle("FarmAutoreset", {Title = "Авто-ресет при полных мешках", Default = false}):OnChanged(function(v) farm_autoreset = v end)

    print("[FH][INFO] AutoFarm v18.1 готов")
end

-- ============================================================
-- TOOLS
-- ============================================================
do
    local tT = Window:AddTab({Title = "Троллинг"})
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

    toolsSec:AddToggle("ToolTP", {Title = "ТП-тул", Default = false}):OnChanged(function(v)
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
                    hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                    hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, -1.5, 0) + th.MoveDirection * tv.Magnitude / 1.25
                    hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(ang), 0, 0)
                    hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                else
                    hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, 1.5, th.WalkSpeed) * CFrame.Angles(math.rad(90), 0, 0)
                    hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                    hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, -1.5, -th.WalkSpeed)
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

    toolsSec:AddToggle("ToolFling", {Title = "Тул отброса", Default = false}):OnChanged(function(v)
        ftOn = v
        if v then giveFlingTool() else removeFlingTool() end
    end)
    toolsSec:AddToggle("ToolFlingBypass", {Title = "Обход velocity", Default = false}):OnChanged(function(v)
        ftBypass = v
    end)
    AddConn("FlingToolCheck", LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if ftOn then giveFlingTool() end
    end))

    local fmOn, fsOn, flingThread = false, false, nil

    local function startFlingLoop()
        if flingThread then return end
        flingThread = task.spawn(function()
            while fmOn or fsOn do
                local tgt = nil
                if fmOn then tgt = isMurderer() end
                if not tgt and fsOn then tgt = isSheriffOrHero() end
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

    toolsSec:AddToggle("ToolFlingMurder", {Title = "Авто-отброс убийцы", Default = false}):OnChanged(function(v)
        fmOn = v
        if v then startFlingLoop() end
    end)
    toolsSec:AddToggle("ToolFlingSheriff", {Title = "Авто-отброс шерифа", Default = false}):OnChanged(function(v)
        fsOn = v
        if v then startFlingLoop() end
    end)

    local function inLobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby" or p.Name == "Lobby" then return true end
            p = p.Parent
        end
        return false
    end

    toolsSec:AddButton({Title = "ТП в лобби", Callback = function()
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

    toolsSec:AddButton({Title = "ТП на карту", Callback = function()
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

    print("[FH][INFO] Tools v18.1 готов")
end

-- ============================================================
-- ANTI
-- ============================================================
do
    local tU = Window:AddTab({Title = "Утилиты"})
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

    AddConn("AntiFlingV18", RunService.Stepped:Connect(function()
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

    antiSec:AddToggle("AntiFling", {Title = "Анти-отброс", Default = false}):OnChanged(function(v)
        antiFlingOn = v
        if not v then restoreFling() end
        Notify("FH", "Anti-Fling " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    local antiVoidOn = false
    local voidOrig = Workspace.FallenPartsDestroyHeight
    AddConn("AntiVoidV18", RunService.Heartbeat:Connect(function()
        if antiVoidOn then
            pcall(function() Workspace.FallenPartsDestroyHeight = -9e9 end)
        else
            pcall(function() Workspace.FallenPartsDestroyHeight = voidOrig end)
        end
    end))
    antiSec:AddToggle("AntiVoid", {Title = "Анти-падение", Default = false}):OnChanged(function(v)
        antiVoidOn = v
    end)

    local antiTrapOn = false
    local trapSpeedCache, trapJumpCache = 16, 50

    local function trapUnlock(hum)
        if not hum or not hum.Parent then return end
        pcall(function()
            if hum.WalkSpeed <= 1 then hum.WalkSpeed = trapSpeedCache end
            if hum.JumpPower <= 1 then hum.JumpPower = trapJumpCache end
        end)
    end

    AddConn("AntiTrapV18", RunService.Heartbeat:Connect(function()
        if not antiTrapOn then return end
        local hum = getHum()
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

    antiSec:AddToggle("AntiTrap", {Title = "Анти-ловушка", Default = false}):OnChanged(function(v)
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

    antiSec:AddToggle("AntiCoin", {Title = "Удаление монет", Default = false}):OnChanged(function(v)
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

    antiSec:AddToggle("AntiFade", {Title = "Убрать чёрный экран смерти", Default = false}):OnChanged(function(v)
        antiFadeOn = v
        if v then fadeApply() else fadeRestore() end
    end)

    print("[FH][INFO] Anti v18.1 готов")
end

-- ============================================================
-- NOTIFY
-- ============================================================
do
    local notifySec = Tabs.Utility:AddSection({Name = "Уведомления"})

    local notifyOn, missOn, killOn, rolesOn = false, false, false, false
    local lastRole, gunConn, hookedGun = nil, nil, nil
    local curMurdererName, killedFlag = nil, false
    local lastMiss = 0

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
        if r == "Sheriff" then return "Sheriff" end
        if r == "Hero" then return "Hero" end
        if lpHasGun() and r ~= "Sheriff" then return "Hero" end
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
        Notify("FH", text, 4)
    end

    task.spawn(function()
        while task.wait(0.5) do
            if notifyOn and rolesOn then
                local r = myRole()
                if r and r ~= lastRole then
                    lastRole = r
                    local ru = (r == "Sheriff" and "Шериф")
                        or (r == "Hero" and "Герой")
                        or (r == "Murderer" and "Маньяк")
                        or (r == "Innocent" and "Мирный")
                        or r
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
                if missOn and os.clock() - lastMiss > 1.5 then
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
    notifySec:AddToggle("NotifyMiss", {Title = "Промахи", Default = false}):OnChanged(function(v)
        missOn = v
        if v and notifyOn then task.spawn(ensureGunHook) end
    end)
    notifySec:AddToggle("NotifyKill", {Title = "Убил убийцу", Default = false}):OnChanged(function(v)
        killOn = v
        if v and notifyOn then task.spawn(ensureGunHook) end
    end)
    notifySec:AddToggle("NotifyRoles", {Title = "Роли", Default = false}):OnChanged(function(v)
        rolesOn = v
    end)

    print("[FH][INFO] Notify v18.1 готов")
end

-- ============================================================
-- SOUNDS
-- ============================================================
do
    local sndSec = Tabs.Utility:AddSection({Name = "Звуки убийства"})

    local SND_REMOTE = {"primordial", "neverlose", "sparkle", "mc bow", "skeet", "break", "rust"}
    local SND_LOCAL = {"applepay", "bubble", "combobreak", "killcard", "xp", "na naxuy", "stony", "hentai"}
    local SND_FILES = {hentai = "hentai1"}
    local SND_CACHE_DIR = "shitaro_sounds/"
    local SND_USER_DIR = "sounds/"
    local SND_USER_EXTS = {[".ogg"] = true, [".mp3"] = true, [".wav"] = true}
    local SND_DIRS = {"shitaroebet/", "assets/", SND_USER_DIR, "", SND_CACHE_DIR}
    local SND_EXTS = {".ogg", ".mp3", ".wav", ""}
    local SND_BASE = "https://github.com/khenn791/lmao/raw/refs/heads/main/"

    local FALLBACK = {
        neverlose = "rbxassetid://9120386433",
        skeet = "rbxassetid://9120386433",
        ["mc bow"] = "rbxassetid://9120386433",
        primordial = "rbxassetid://9120386433",
        sparkle = "rbxassetid://9120386433",
        ["break"] = "rbxassetid://9120386433",
        rust = "rbxassetid://9120386433",
    }

    local SND_LIST, sndRemote = {}, {}
    for _, n in ipairs(SND_REMOTE) do SND_LIST[#SND_LIST + 1] = n; sndRemote[n] = true end
    for _, n in ipairs(SND_LOCAL) do SND_LIST[#SND_LIST + 1] = n end

    local sndCache, sndFetched, sndHooked, sndPool = {}, {}, {}, {}
    local sndLast = {sheriff = 0, murder = 0}
    local sndCfg = {
        sheriff = {on = false, name = "mc bow", vol = 1},
        murder = {on = false, name = "neverlose", vol = 1},
    }

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
        local id = sndResolve(cfg.name) or FALLBACK[cfg.name]
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

    sndSec:AddToggle("SndSheriff", {Title = "Звук убийства Шерифа", Default = false}):OnChanged(function(v)
        sndCfg.sheriff.on = v
        if v then pcall(sndTemplate, "sheriff") pcall(sndScanAll) end
    end)
    sndSec:AddDropdown("SndSheriffName", {Title = "Звук", Values = SND_LIST, Default = "mc bow"}):OnChanged(function(v)
        sndCfg.sheriff.name = v
        if sndCfg.sheriff.on then pcall(sndTemplate, "sheriff") end
    end)
    sndSec:AddSlider("SndSheriffVol", {Title = "Громкость", Min = 0.1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v)
        sndCfg.sheriff.vol = tonumber(v) or 1
        local s = sndPool.sheriff
        if s then pcall(function() s.Volume = sndCfg.sheriff.vol end) end
    end)

    sndSec:AddToggle("SndMurder", {Title = "Звук убийства Маньяка", Default = false}):OnChanged(function(v)
        sndCfg.murder.on = v
        if v then pcall(sndTemplate, "murder") pcall(sndScanAll) end
    end)
    sndSec:AddDropdown("SndMurderName", {Title = "Звук", Values = SND_LIST, Default = "neverlose"}):OnChanged(function(v)
        sndCfg.murder.name = v
        if sndCfg.murder.on then pcall(sndTemplate, "murder") end
    end)
    sndSec:AddSlider("SndMurderVol", {Title = "Громкость", Min = 0.1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v)
        sndCfg.murder.vol = tonumber(v) or 1
        local s = sndPool.murder
        if s then pcall(function() s.Volume = sndCfg.murder.vol end) end
    end)

    print("[FH][INFO] Sounds v18.1 готов")
end

-- ============================================================
-- EMOTES (FIXED: Animator вместо Humanoid:LoadAnimation)
-- ============================================================
do
    local emoteSec = Tabs.Troll:AddSection({Name = "Эмоции"})

    local statEmotes = {
        {"Salute", "12888162088"},
        {"Applaud", "12888160997"},
        {"Tilt", "12888159317"},
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

    -- FIX: используем Animator:LoadAnimation
    local function getAnimator()
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        return animator
    end

    local function playEmote(id)
        local animator = getAnimator()
        if not animator or not id then
            Notify("FH", "Animator не найден", 2)
            return
        end
        stopEmote()
        local anim = Instance.new("Animation")
        anim.AnimationId = resolveId(id)
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            pcall(function() track:Play(0.1) end)
            curTrack = track
        else
            Notify("FH", "Не удалось запустить эмоцию", 2)
        end
    end

    for _, e in ipairs(statEmotes) do
        if not emoteMap[e[1]] then
            emoteMap[e[1]] = e[2]
            emoteList[#emoteList + 1] = e[1]
        end
    end

    local drop = emoteSec:AddDropdown("EmoteListV18", {
        Title = "Выбрать эмоцию",
        Values = emoteList,
        Default = emoteList[1],
    }):OnChanged(function(v)
        selId = emoteMap[v]
    end)

    emoteSec:AddButton({Title = "Активировать эмоцию", Callback = function()
        if selId then
            playEmote(selId)
            Notify("FH", "Эмоция запущена", 2)
        else
            Notify("FH", "Выбери эмоцию", 2)
        end
    end})

    emoteSec:AddButton({Title = "Остановить эмоцию", Callback = function()
        stopEmote()
        Notify("FH", "Эмоция остановлена", 2)
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

    AddConn("EmoteAutoRebindV18", LocalPlayer.CharacterAdded:Connect(function()
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
                if drop.Generate then drop:Generate() end
            end)
            print("[FH][INFO] Emotes: загружено " .. #emoteList .. " штук")
        end
    end)

    print("[FH][INFO] Emotes v18.1 готов")
end

-- ============================================================
-- ANIMATIONS
-- ============================================================
do
    local animSec = Tabs.Troll:AddSection({Name = "Анимации"})

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
        {"Salute", 12888162088},
        {"Applaud", 12888160997},
        {"Tilt", 12888159317},
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
        if not id then
            Notify("FH", "Анимация не найдена", 2)
            return
        end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then
            Notify("FH", "Персонаж не загружен", 2)
            return
        end
        -- FIX: Animator
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        stopAnim()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. tostring(id)
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            pcall(function() track:Play(0.1) end)
            currentTrack = track
            currentEmote = name
            Notify("FH", "Играю: " .. name, 2)
        else
            Notify("FH", "Не удалось запустить: " .. name, 2)
        end
    end

    local pick = animSec:AddDropdown("AnimPickV18", {
        Title = "Выбрать анимацию",
        Values = animNames,
        Default = "Ninja",
    })

    animSec:AddButton({Title = "▶ Запустить", Callback = function()
        local v = pick and pick.Value
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" and v ~= "" then
            playAnim(v)
        end
    end})

    animSec:AddButton({Title = "■ Остановить", Callback = function()
        stopAnim()
        Notify("FH", "Остановлено", 2)
    end})

    animSec:AddToggle("AnimAuto", {
        Title = "Авто-воспроизведение после респавна",
        Default = false,
    })

    AddConn("AnimRespawnV18", LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        if Options.AnimAuto and Options.AnimAuto.Value and currentEmote then
            playAnim(currentEmote)
        end
    end))

    print("[FH][INFO] Animations v18.1 готов")
end

-- ============================================================
-- MAP VOTE (FIXED: firetouchinterest + нормальный сброс dupeOn)
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
        local v = grid.Value
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
        -- FIX: сброс dupeOn
        dupeOn = false
    end

    local function standPoint(pad)
        local prm = RaycastParams.new()
        prm.FilterType = Enum.RaycastFilterType.Exclude
        prm.FilterDescendantsInstances = {LocalPlayer.Character, root}
        local hit = Workspace:Raycast(pad.Position + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), prm)
        local y = hit and (hit.Position.Y + 3.2) or pad.Position.Y
        return Vector3.new(pad.Position.X, y, pad.Position.Z)
    end

    -- FIX: добавлен firetouchinterest
    local function plant(point, pad)
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        hrp.CFrame = CFrame.new(point)
        if pad and type(firetouchinterest) == "function" then
            pcall(function()
                firetouchinterest(hrp, pad, 0)
                task.wait(0.02)
                firetouchinterest(hrp, pad, 1)
            end)
        end
        return true
    end

    local function killSelf()
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildWhichIsA("Humanoid")
        if hum then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Dead)
                hum.Health = 0
            end)
        elseif c then
            pcall(function() c:BreakJoints() end)
        end
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
        if not plant(spot, entry.pad) then finish() return end

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

        local total = math.clamp(dupeCap or 3, 1, 10)

        local function finish_cycle()
            if session ~= id then return end
            local c2 = LocalPlayer.Character
            local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
            if h2 and origin then h2.CFrame = origin end
            finish()
        end

        local function step()
            if session ~= id or not dupeOn then finish_cycle() return end
            if dupeUsed >= total then finish_cycle() return end
            dupeUsed = dupeUsed + 1
            killSelf()
        end

        spawnConn = LocalPlayer.CharacterAdded:Connect(function(char)
            if session ~= id or not dupeOn then return end
            local h2 = char:WaitForChild("HumanoidRootPart", 6)
            if not h2 then return end
            if dupeUsed >= total then
                if origin then h2.CFrame = origin end
                finish_cycle()
                return
            end
            h2.CFrame = CFrame.new(spot)
            -- FIX: firetouchinterest на каждом респавне
            if type(firetouchinterest) == "function" then
                pcall(function()
                    firetouchinterest(h2, entry.pad, 0)
                    task.wait(0.02)
                    firetouchinterest(h2, entry.pad, 1)
                end)
            end
            task.wait(0.15)
            step()
        end)

        task.delay(0.15, function()
            if session ~= id then return end
            step()
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

    mvSec:AddToggle("MVAuto", {Title = "Авто-голосование", Default = false}):OnChanged(function(v)
        voteOn = v
        if v then schedule() else finish() end
    end)

    mvSec:AddSlider("MVDupeCap", {
        Title = "Максимум голосов за раз",
        Min = 1, Max = 10, Default = 3, Rounding = 0,
    }):OnChanged(function(v) dupeCap = tonumber(v) or 3 end)

    mvSec:AddButton({Title = "Дюпнуть голос (мульти-голос)", Callback = function()
        if not voteOn then
            Notify("FH", "Сначала включи Авто-голосование", 3)
            return
        end
        if running then
            Notify("FH", "Уже голосуем...", 2)
            return
        end
        dupeOn = true
        running = true
        session = session + 1
        Notify("FH", "Мульти-голос запущен (" .. dupeCap .. " раз)", 2)
        task.spawn(function()
            begin(session)
            task.wait(15)
            dupeOn = false
        end)
    end})

    grid = mvSec:AddDropdown("MVMaps", {
        Title = "Приоритетные карты",
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

    print("[FH][INFO] Map Vote v18.1 готов (dupe — кнопка, firetouchinterest)")
end

-- ============================================================
-- CONFIGS
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
            local isArray = true
            for k in pairs(v) do
                if type(k) ~= "number" then isArray = false break end
            end
            if isArray then
                local parts = {}
                for i = 1, #v do parts[#parts + 1] = tostring(v[i]) end
                return "L:" .. table.concat(parts, ",")
            else
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
            Notify("FH", "Экзекутор не поддерживает writefile", 4)
            return false
        end
        if not ensureConfigDir() then
            Notify("FH", "Не удалось создать папку конфигов", 4)
            return false
        end
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
            Notify("FH", "Сохранено: " .. name, 3)
            return true
        else
            Notify("FH", "Ошибка сохранения", 3)
            return false
        end
    end

    local function loadConfig(name)
        if type(readfile) ~= "function" then
            Notify("FH", "Экзекутор не поддерживает readfile", 4)
            return false
        end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        if type(isfile) == "function" then
            local ok, has = pcall(isfile, path)
            if not ok or not has then
                Notify("FH", "Конфиг не найден: " .. name, 3)
                return false
            end
        end
        local ok, data = pcall(readfile, path)
        if not ok or type(data) ~= "string" then
            Notify("FH", "Ошибка чтения", 3)
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
        Notify("FH", "Загружено: " .. name .. " (" .. loaded .. ")", 3)
        return true
    end

    local function deleteConfig(name)
        if type(delfile) ~= "function" then
            Notify("FH", "Экзекутор не поддерживает delfile", 4)
            return false
        end
        local path = CONFIG_DIR .. name .. CONFIG_EXT
        local ok = pcall(delfile, path)
        if ok then
            Notify("FH", "Удалено: " .. name, 2)
            return true
        end
        return false
    end

    local cfgSec = Tabs.Settings:AddSection({Name = "Конфиги"})

    local currentList = listConfigs()
    if #currentList == 0 then currentList = {"(нет конфигов)"} end

    local drop = cfgSec:AddDropdown("ConfigPick", {
        Title = "Выбрать конфиг",
        Values = currentList,
        Default = currentList[1],
    })

    local function refreshList()
        local list = listConfigs()
        if #list == 0 then list = {"(нет конфигов)"} end
        pcall(function()
            drop:SetValues(list)
            if drop.Generate then drop:Generate() end
        end)
    end

    cfgSec:AddInput("ConfigName", {
        Title = "Имя конфига",
        Default = "my_config",
    })

    cfgSec:AddButton({Title = "Сохранить (Save)", Callback = function()
        local nameOpt = Options.ConfigName
        local name = nameOpt and nameOpt.Value or "my_config"
        if type(name) ~= "string" or name == "" then
            Notify("FH", "Введи имя конфига", 3)
            return
        end
        if saveConfig(name) then refreshList() end
    end})

    cfgSec:AddButton({Title = "Загрузить (Load)", Callback = function()
        local pickOpt = Options.ConfigPick
        local name = pickOpt and pickOpt.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3)
            return
        end
        loadConfig(name)
    end})

    cfgSec:AddButton({Title = "Удалить", Callback = function()
        local pickOpt = Options.ConfigPick
        local name = pickOpt and pickOpt.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3)
            return
        end
        if deleteConfig(name) then refreshList() end
    end})

    cfgSec:AddButton({Title = "Обновить список", Callback = refreshList})

    print("[FH][INFO] Configs v18.1 готов")
end

-- ============================================================
-- ФИНАЛЬНАЯ ОБВЯЗКА
-- ============================================================
pcall(function() Window:SelectTab(1) end)

print("[FH][INFO] ================================")
print("[FH][INFO] PART 2/2 v18.1 FIXED УСПЕШНО ЗАГРУЖЕН")
print("[FH][INFO] FortniHub v18.1 FINAL")
print("[FH][INFO] ================================")

task.spawn(function()
    task.wait(1)
    Notify("FortniHub", "Часть 2/2 v18.1 FIXED загружена!", 6)
end)
