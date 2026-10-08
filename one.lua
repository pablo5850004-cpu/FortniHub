-- ============================================================
-- FortniHub v20.2 BETA — main.lua — ЧАСТЬ 1/2
-- Fixed build. By HOTI & Ve315. Refactor: pablo5850004-cpu
-- ============================================================

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local CoreGui              = game:GetService("CoreGui")
local Workspace            = game:GetService("Workspace")
local Lighting             = game:GetService("Lighting")
local HttpService          = game:GetService("HttpService")
local TeleportService      = game:GetService("TeleportService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local VirtualUser          = game:GetService("VirtualUser")
local TweenService         = game:GetService("TweenService")
local Stats                = game:GetService("Stats")
local CollectionService    = game:GetService("CollectionService")
local SoundService         = game:GetService("SoundService")
local Debris               = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local VERSION = "20.2.0 BETA"
local CREDITS = "by HOTI and Ve315"

local S = {
    frozen         = false,
    freezeUpKey    = Enum.KeyCode.Space,
    freezeDownKey  = Enum.KeyCode.LeftAlt,
}

local knifeSilent = {
    enabled = false, radius = 20, fov = 120,
    showFov = true, checkWalls = false, instaKill = true, predict = true,
}

local killAuraVersion = "v2"
local kaV1 = { on = false, dist = 30, lastHit = 0 }
local kaV2 = { on = false, dist = 30, lastHit = 0 }

local Connections = {}
local function AddConn(name, conn)
    if Connections[name] then
        pcall(function() Connections[name]:Disconnect() end)
    end
    Connections[name] = conn
end

-- ============================================================
-- CACHE персонажа
-- ============================================================
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

-- ============================================================
-- ROLE / ROUND
-- ============================================================
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
            if d.Role == "Sheriff"  then return "sheriff" end
            if d.Role == "Hero"     then return "hero" end
            return "innocent"
        end
    end
    local c = p:FindFirstChild("Character")
    -- fallback: смотрим по inventory
    c = p.Character
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

local function isMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRoleFromData(p) == "murderer" then return p end
    end
    return nil
end

-- ============================================================
-- SAFE RANDOM
-- ============================================================
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

-- ============================================================
-- OnChanged registry (для конфигов)
-- ============================================================
local OnChangedRegistry = {}
getgenv().FH_OnChangedRegistry = OnChangedRegistry

local function registerOnChanged(name, cb)
    OnChangedRegistry[name] = cb
end
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

-- ============================================================
-- Адаптер методов таба (для совместимости API Fluent)
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

-- ============================================================
-- ОКНО
-- ============================================================
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
Tabs.Combat     = Window:AddTab({Title = "Бой"})
Tabs.Movement   = Window:AddTab({Title = "Движение"})
Tabs.Binds      = Window:AddTab({Title = "Бинды"})
Tabs.Visual     = Window:AddTab({Title = "Визуал"})
Tabs.Effects    = Window:AddTab({Title = "Эффекты"})
Tabs.Farm       = Window:AddTab({Title = "Фарм"})
Tabs.Animations = Window:AddTab({Title = "Анимации"})
Tabs.Utility    = Window:AddTab({Title = "Утилиты"})
Tabs.Troll      = Window:AddTab({Title = "Троллинг"})
Tabs.Settings   = Window:AddTab({Title = "Настройки"})

-- ============================================================
-- УНИВЕРСАЛЬНЫЙ ХЕЛПЕР
-- ============================================================
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
    Notify("FortniHub", "Скрипт был создан HOTI и Ve315.", 7)
    task.wait(1.2)
    Notify("FortniHub", "Скрипт находится в BETA версии, могут быть баги.", 7)
end)

-- ============================================================
-- HUD (верхний pill: FH · FPS · ms) — Watermark НЕ создаём
-- ============================================================
local HUDGui, FPSLabel, PingLabel, Pill
do
    pcall(function()
        for _, name in ipairs({
            "FH_HUD_v18","FH_HUD","FH_HUD_v19","FH_HUD_v20","FH_HUD_v21",
            "FH_Watermark_v21","FH_Watermark",
        }) do
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
    Pill.Size = UDim2.fromOffset(320, 40)
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
        if i.UserInputType == Enum.UserInputType.MouseButton1 or
           i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragMoved = false
            dragStart = i.Position
            posStart = Pill.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or
           i.UserInputType == Enum.UserInputType.Touch then
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
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 and
           i.UserInputType ~= Enum.UserInputType.Touch then return end
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

    local s1 = seg(8, 90)
    local logo = Instance.new("TextLabel")
    logo.BackgroundTransparency = 1
    logo.Size = UDim2.fromOffset(80, 40)
    logo.Position = UDim2.fromOffset(12, 0)
    logo.Font = Enum.Font.GothamBold
    logo.Text = "FH"
    logo.TextSize = 20
    logo.TextColor3 = Color3.fromRGB(178, 152, 255)
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = s1
    div(102)

    local s2 = seg(106, 110)
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
    div(220)

    local s3 = seg(224, 96)
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
            local cur = fc
            fc = 0
            lastSec = now
            local c = cur < 30 and Color3.fromRGB(255, 80, 80)
                or (cur < 60 and Color3.fromRGB(255, 200, 80)
                or Color3.fromRGB(80, 240, 120))
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
            local c = p < 60 and Color3.fromRGB(80, 240, 120)
                or (p < 120 and Color3.fromRGB(255, 200, 80)
                or Color3.fromRGB(255, 80, 80))
            PingLabel.Text = tostring(p)
            PingLabel.TextColor3 = c
        end
    end))
end

-- ============================================================
-- SILENT AIM
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
        enabled = false,
        predict = true,
        force = false,
        auto_on = false,
        auto_delay = 0,
        am_sheriff = false,
        fire_gap = 0,
        last_shot = 0,
        stand_off = 15,
    }
    local SS = getgenv().SILENT_S

    local silent_section = Tabs.Combat:AddSection({Name = "Тихий выстрел"})

    local gap_min, gap_seen, gap_gun, want_since = 0, false, nil, 0

    local function gap_reset()
        gap_min = 0
        gap_seen = false
        SS.fire_gap = 0
    end

    local function gap_push(value)
        if value <= 0 then return end
        if not gap_seen or value < gap_min then
            gap_min = value
            gap_seen = true
            SS.fire_gap = value
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
            target_char = nil
            target_part = nil
            target_hum = nil
        end
        if not found then return end
        local char = found.Character
        if char ~= target_char then
            target_char = char
            target_part = nil
            target_hum = nil
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
            for k = 1, #tagged do
                ignore_base[#ignore_base + 1] = tagged[k]
            end
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
        return nil
    end

    local function grav()
        local ok, g = pcall(function() return workspace.Gravity end)
        if ok and type(g) == "number" and g > 0 then return g end
        return 0
    end

    local P = {
        snap = 48, ring = 48, hit_r = 2.1, pad = 2.6,
        min_span = 5, max_span = 90, acc_t = 0.15,
        acc_max = 280, acc_min = 40,
        speed_floor = 26, speed_head = 1.3,
    }

    local snap_t = table.create(P.snap, 0)
    local snap_p = table.create(P.snap, Vector3.zero)
    local snap_n, snap_i = 0, 0

    local TR = {
        part = nil, pos = nil, time = 0, vel = Vector3.zero,
        gap = 0, ready = false, fresh = Vector3.zero,
        air = false, air_since = 0, jumping = false,
        jump_v = 0, fresh_ok = false, turn = 0, spoof = 0,
        clr = 0, air_edge = 0, jump_fresh = false,
    }

    local SK = {
        vt = table.create(P.ring, 0),
        dx = table.create(P.ring, 0),
        dz = table.create(P.ring, 0),
        vn = 0, vi = 0,
    }

    local EC = { ping = 0, rtt = 0, jitter = 0, seen = false, step = 0, step_seen = false }

    local function step_push(dt)
        if dt <= 0 or dt > 0.5 then return end
        if EC.step_seen then
            EC.step = EC.step * 0.85 + dt * 0.15
        else
            EC.step = dt
            EC.step_seen = true
        end
    end

    local function sample_span()
        local span = math.max(EC.step, TR.gap)
        if span <= 0 then return 0 end
        return span
    end

    local HY = { pos = {}, w = {}, n = 0, weight = 0, primary = nil, stamp = 0, conf = 0 }

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
        return nil
    end

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

    local KIN = { ok = false, ax = 0, az = 0, smax = 0 }
    local function kin_clear() KIN.ok = false; KIN.ax = 0; KIN.az = 0; KIN.smax = 0 end

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
        local det = n * (s2 * s4 - s3 * s3)
            - s1 * (s1 * s4 - s3 * s2)
            + s2 * (s1 * s3 - s2 * s2)
        if math.abs(det) < 1e-9 then return nil end
        local function solve(b0, b1, b2)
            local d1 = n * (b1 * s4 - s3 * b2)
                - b0 * (s1 * s4 - s3 * s2)
                + s2 * (s1 * b2 - b1 * s2)
            local d2 = n * (s2 * b2 - b1 * s3)
                - s1 * (s1 * b2 - b1 * s2)
                + b0 * (s1 * s3 - s2 * s2)
            return d1 / det, d2 / det
        end
        local cx1, cx2 = solve(bx0, bx1, bx2)
        local cz1, cz2 = solve(bz0, bz1, bz2)
        local vx, vz = cx1 / scale, cz1 / scale
        local ax, az = 2 * cx2 / (scale * scale), 2 * cz2 / (scale * scale)
        if vx ~= vx or vz ~= vz or ax ~= ax or az ~= az then return nil end
        return Vector3.new(vx, 0, vz), Vector3.new(ax, 0, az)
    end

    local function kin_update()
        local kv, ka = fit_kin()
        if not kv then KIN.ok = false; KIN.ax = 0; KIN.az = 0; return nil end
        KIN.ok = true
        local sp = math.sqrt(kv.X * kv.X + kv.Z * kv.Z)
        if sp > KIN.smax then KIN.smax = sp
        else KIN.smax = KIN.smax * 0.985 + sp * 0.015 end
        if ka and not TR.air then
            local am = math.sqrt(ka.X * ka.X + ka.Z * ka.Z)
            local ax, az = ka.X, ka.Z
            if am > P.acc_max and am > 0 then
                ax = ax * P.acc_max / am
                az = az * P.acc_max / am
            end
            KIN.ax = KIN.ax * 0.5 + ax * 0.5
            KIN.az = KIN.az * 0.5 + az * 0.5
        else
            KIN.ax = KIN.ax * 0.5
            KIN.az = KIN.az * 0.5
        end
        return kv
    end

    local function snap_vel(k)
        local t0, p0 = snap_get(k)
        local t1, p1 = snap_get(k + 1)
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
                best = (head.Y - p.Y) / dt - 0.5 * g * dt
                if dt >= want then break end
            end
        end
        return best
    end

    local function body_clearance()
        local part = target_part
        local hum = target_hum
        if not part or not hum then return 0 end
        local ok, value = pcall(function() return part.Size.Y * 0.5 + hum.HipHeight end)
        if ok and type(value) == "number" and value > 0 then return value end
        return 0
    end

    local GC = { base = 0, seen = false }
    local JL = { v = 0, seen = false }
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

    local function vel_trust(pv, ev)
        if not pv or not ev then return 0 end
        local ph = Vector3.new(pv.X, 0, pv.Z)
        local eh = Vector3.new(ev.X, 0, ev.Z)
        local pm, em = ph.Magnitude, eh.Magnitude
        if pm < 1 and em < 1 then return 1 end
        if pm < 1 or em < 1 then return 0 end
        local ratio = em / pm
        if ratio > 1.5 or ratio < 0.6 then return 0 end
        local align = ph.Unit:Dot(eh.Unit)
        if align < 0.7 then return 0 end
        local a = math.clamp((align - 0.7) / 0.25, 0, 1)
        local r = 1 - math.clamp(math.abs(ratio - 1) / 0.4, 0, 1)
        return a * r
    end

    local function phase_velocity(v, age, air)
        if not v then return nil end
        local y = 0
        if air then
            y = v.Y - grav() * math.clamp(age or 0, 0, sample_span() * 4)
        end
        return Vector3.new(v.X, y, v.Z)
    end

    local function merge_vel(fit, fit_age, fast, fast_age, engine, engine_age, air)
        local stable = phase_velocity(fit, fit_age, air)
        local instant = phase_velocity(fast, fast_age, air)
        local turn = 0
        if stable and instant then
            local sh = Vector3.new(stable.X, 0, stable.Z)
            local ih = Vector3.new(instant.X, 0, instant.Z)
            if sh.Magnitude > 1 and ih.Magnitude > 1 then
                turn = math.acos(math.clamp(sh.Unit:Dot(ih.Unit), -1, 1)) / math.pi
            end
        end
        local base = instant or stable
        if not base then return Vector3.zero, 0, nil, 0 end
        if stable and instant then
            local agility = math.clamp(turn * 2.2, 0, 1)
            base = stable:Lerp(instant, 0.4 + 0.6 * agility)
        end
        local trust = 0
        if engine then
            local live = phase_velocity(engine, engine_age, air)
            trust = vel_trust(base, live)
            if trust > 0 and air then
                base = Vector3.new(base.X, base.Y, base.Z)
                    :Lerp(Vector3.new(base.X, live.Y, base.Z), trust * 0.35)
            end
        end
        return base, turn, instant or stable, trust
    end

    local function vel_push(now, hx, hz)
        SK.vi = SK.vi % P.ring + 1
        SK.vt[SK.vi] = now
        SK.dx[SK.vi] = hx
        SK.dz[SK.vi] = hz
        if SK.vn < P.ring then SK.vn = SK.vn + 1 end
    end

    local function track_clear()
        TR.part = nil; TR.pos = nil; TR.vel = Vector3.zero; TR.gap = 0
        TR.ready = false; TR.fresh = Vector3.zero; TR.air = false
        TR.jumping = false; TR.jump_v = 0; TR.fresh_ok = false
        TR.turn = 0; TR.spoof = 0; TR.clr = 0; TR.air_edge = 0; TR.jump_fresh = false
        GC.base = 0; GC.seen = false
        JL.v = 0; JL.seen = false
        snap_n, snap_i = 0, 0
        SK.vn, SK.vi = 0, 0
        kin_clear()
    end

    local function track_seed(part, pos, now)
        TR.part = part; TR.pos = pos; TR.time = now
        TR.vel = Vector3.zero; TR.fresh = Vector3.zero; TR.fresh_ok = false
        TR.turn = 0; TR.jump_v = 0; TR.gap = 0; TR.ready = false
        TR.spoof = 0; TR.air_edge = 0; TR.jump_fresh = false
        GC.base = 0; GC.seen = false
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
        local falling = accel ~= nil and accel < -g * 0.5
        local guess = stand_clearance()
        local reach = guess + 6 + math.abs(vy) * sample_span() * 4
        local air
        local gy = ground_below(pos, reach)
        if gy then
            local clr = pos.Y - gy
            TR.clr = clr
            if math.abs(vy) < 1 and not falling then
                if GC.seen then
                    if clr < GC.base then GC.base = GC.base * 0.7 + clr * 0.3
                    else GC.base = GC.base * 0.98 + clr * 0.02 end
                else
                    GC.base = clr; GC.seen = true
                end
            end
            local floor = GC.seen and GC.base or guess
            local tol = math.max(floor * 0.35, 1)
            air = clr > floor + tol
            if not air and falling and math.abs(vy) > 4 and clr > floor + 0.35 then
                air = true
            end
        else
            air = true
        end
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
        local model_vy = TR.jump_v - g * math.max(0, now - TR.air_since)
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
        if (pos - TR.pos).Magnitude == 0 then
            if TR.gap > 0 and dt >= TR.gap then
                TR.vel = Vector3.zero
                TR.fresh = Vector3.zero
            end
            return
        end
        step_push(dt)
        TR.gap = dt
        snap_push(now, pos)
        TR.pos = pos
        TR.time = now
        local fit, fit_age = fit_velocity()
        local fast, fast_age = recent_velocity()
        local engine = engine_vel(part)
        local fresh, turn, instant, trust = merge_vel(
            fit, fit_age, fast, fast_age, engine, sample_span() * 0.5, TR.air)
        local kv = kin_update()
        if kv then fresh = Vector3.new(kv.X, fresh.Y, kv.Z) end
        if engine and trust <= 0 then
            if TR.spoof < 20 then TR.spoof = TR.spoof + 1 end
        elseif TR.spoof > 0 then
            TR.spoof = TR.spoof - 1
        end
        if TR.air then
            local vy = air_vy()
            if vy then
                fresh = Vector3.new(fresh.X, vy, fresh.Z)
                local since = math.max(0, now - TR.air_edge)
                if TR.jump_fresh and since <= 0.2 then
                    local impulse = vy + grav() * since
                    if impulse > 1 then
                        if JL.seen then JL.v = JL.v * 0.7 + impulse * 0.3
                        else JL.v = impulse; JL.seen = true end
                        if impulse > TR.jump_v then TR.jump_v = impulse end
                    end
                else
                    TR.jump_fresh = false
                end
            end
        end
        TR.vel = fresh
        TR.ready = fit ~= nil or fast ~= nil
        TR.fresh = TR.vel
        TR.fresh_ok = TR.ready
        TR.turn = turn
        local raw = instant or fresh
        vel_push(now, raw.X, raw.Z)
    end

    local function raw_rtt()
        local a, b
        local ok, ms = pcall(function()
            return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and type(ms) == "number" and ms == ms and ms > 4 and ms < 800 then
            a = ms / 1000
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

    local function rotate_y(v, ang)
        local c, s = math.cos(ang), math.sin(ang)
        return Vector3.new(v.X * c - v.Z * s, v.Y, v.X * s + v.Z * c)
    end

    local function dir_stats(win)
        if SK.vn < 4 then return 1, 0 end
        win = math.max(win, sample_span() * 3)
        local newest = SK.vt[SK.vi]
        local sx, sz, n = 0, 0, 0
        local prev
        local turn, turn_n = 0, 0
        local oldest = newest
        for k = 0, SK.vn - 1 do
            local idx = (SK.vi - k - 1) % P.ring + 1
            local t = SK.vt[idx]
            if newest - t > win then break end
            local hx, hz = SK.dx[idx], SK.dz[idx]
            local m = math.sqrt(hx * hx + hz * hz)
            if m > 0 then
                sx = sx + hx / m
                sz = sz + hz / m
                n = n + 1
                local ang = math.atan2(hz, hx)
                if prev then
                    local d = ang - prev
                    while d > math.pi do d = d - 6.2831853 end
                    while d < -math.pi do d = d + 6.2831853 end
                    turn = turn + d
                    turn_n = turn_n + 1
                end
                prev = ang
                oldest = t
            end
        end
        if n < 2 then return 1, 0 end
        local coh = math.clamp(math.sqrt(sx * sx + sz * sz) / n, 0, 1)
        local omega = 0
        local elapsed = newest - oldest
        if turn_n >= 1 and elapsed > 1e-3 then omega = -turn / elapsed end
        return coh, omega
    end

    local function predict_from(base, sa, sb, fh, now)
        local span = math.max(0, sa + sb)
        local g = grav()
        local dir = fh
        if dir.Magnitude == 0 then dir = Vector3.new(TR.vel.X, 0, TR.vel.Z) end
        local x, z
        if span > 0 and KIN.ok then
            local age = math.clamp(now - TR.time, 0, sample_span() * 2)
            local ax, az = KIN.ax, KIN.az
            if TR.air or math.sqrt(ax * ax + az * az) < P.acc_min then ax, az = 0, 0 end
            local vx = dir.X + ax * age
            local vz = dir.Z + az * age
            local ta = math.min(span, P.acc_t)
            local dx = vx * span + 0.5 * ax * ta * ta
            local dz = vz * span + 0.5 * az * ta * ta
            local reach = math.sqrt(dx * dx + dz * dz)
            local cap = math.max(KIN.smax * P.speed_head, P.speed_floor) * span
            if reach > cap and reach > 1e-6 then
                dx = dx * cap / reach
                dz = dz * cap / reach
            end
            x = base.X + dx
            z = base.Z + dz
        else
            local hspan = span
            if span > 0 and dir.Magnitude > 0 and not TR.air then
                local coh, omega = dir_stats(span)
                local conf = math.clamp(coh, 0, 1) * (1 - math.clamp(TR.turn, 0, 1) * 0.5)
                if omega ~= 0 then
                    dir = rotate_y(dir, math.clamp(omega * span * 0.5 * conf, -0.6, 0.6))
                end
                hspan = span * (0.85 + 0.15 * conf)
            end
            x = base.X + dir.X * hspan
            z = base.Z + dir.Z * hspan
        end
        local y = base.Y
        if TR.air and span > 0 then
            local vy = TR.vel.Y
            local phase = math.max(0, now - TR.air_since)
            local modeled = TR.jump_v - g * phase
            if TR.jumping and TR.jump_v > 0 and g > 0
                and phase <= TR.jump_v / g and modeled > vy then
                vy = modeled
            end
            y = base.Y + vy * span - 0.5 * g * span * span
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

    local function build_hyps(base, now)
        table.clear(HY.pos)
        table.clear(HY.w)
        local horizon = (SS.predict and not SS.force) and TR.ready and lead_time() or 0
        local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
        HY.primary = predict_from(base, 0, horizon, fh, now)
        HY.n = 1
        HY.pos[1] = HY.primary
        HY.w[1] = 1
        HY.weight = 1
        HY.stamp = now
    end

    local function score_axis(anchor, axis)
        local covered = 0
        local lo, hi = 0, 0
        for k = 1, HY.n do
            local d = HY.pos[k] - anchor
            local a = d:Dot(axis)
            local perp = (d - axis * a).Magnitude
            if perp <= P.hit_r then
                covered = covered + HY.w[k]
                if a < lo then lo = a end
                if a > hi then hi = a end
            end
        end
        return covered, lo, hi
    end

    local function corridor_axes(anchor)
        table.clear(axis_pool)
        local n = 0
        local function add(v)
            if typeof(v) ~= "Vector3" or v.Magnitude < 1e-4 then return end
            local u = v.Unit
            for k = 1, n do
                if axis_pool[k]:Dot(u) > 0.985 then return end
            end
            n = n + 1
            axis_pool[n] = u
        end
        local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
        if TR.air then add(TR.fresh) end
        add(fh)
        for k = 1, HY.n do add(HY.pos[k] - anchor) end
        add(TR.fresh)
        add(Vector3.new(0, 1, 0))
        return n
    end

    local function build_corridor(now)
        local part = target_part
        if not part or not part.Parent then return nil end
        local base = part.Position
        build_hyps(base, now)
        local anchor = HY.primary or base
        local count = corridor_axes(anchor)
        local best_axis, best_cov, best_lo, best_hi = nil, -1, 0, 0
        for k = 1, count do
            local axis = axis_pool[k]
            local cov, lo, hi = score_axis(anchor, axis)
            if cov > best_cov then best_axis, best_cov, best_lo, best_hi = axis, cov, lo, hi end
        end
        if not best_axis then return nil end
        HY.conf = HY.weight > 0 and best_cov / HY.weight or 0
        local pad = P.pad
        local origin = anchor + best_axis * (best_lo - pad)
        local aim = anchor + best_axis * (best_hi + pad)
        if (aim - origin).Magnitude < 4 then
            origin = anchor - best_axis * 4
            aim = anchor + best_axis * 4
        end
        return origin, aim, HY.conf, anchor
    end

    local pred_off, pred_stamp = Vector3.zero, 0

    local function lead_offset()
        local part = target_part
        if not part or not part.Parent then return Vector3.zero end
        if not SS.predict or not TR.ready or SS.force then return Vector3.zero end
        local base = part.Position
        local now = os.clock()
        local fh = Vector3.new(TR.fresh.X, 0, TR.fresh.Z)
        local point = predict_from(base, 0, lead_time(), fh, now)
        local off = point - base
        pred_stamp = now
        pred_off = off
        return pred_off
    end

    local hit_names = {
        "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "Head",
        "RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm",
        "RightUpperLeg", "LeftUpperLeg", "Right Leg", "Left Leg",
        "RightLowerLeg", "LeftLowerLeg",
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
        local first
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
        force_att = nil
        force_saved = nil
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
            force_att = att
            force_saved = saved
        end
        force_stamp = os.clock()
        local ok = pcall(function() att.WorldCFrame = cf end)
        if not ok then restore_origin() return false end
        task.defer(restore_origin)
        return true
    end

    local function is_target_hit(inst)
        local char = target_char
        if not inst or not char then return false end
        return inst == char or inst:IsDescendantOf(char)
    end

    local function force_clear(origin, aim)
        local hit = trace(origin, aim - origin)
        if not hit then return false end
        return is_target_hit(hit.Instance)
    end

    local function force_velocity()
        if TR.fresh_ok and TR.fresh.Magnitude > 0.5 then return TR.fresh end
        if TR.ready and TR.vel.Magnitude > 0.5 then return TR.vel end
        return Vector3.zero
    end

    local function resolve_force()
        local part = target_part
        if not part or not part.Parent then return nil end
        local live = part.Position
        local now = os.clock()
        local origin, aim, conf, anchor = build_corridor(now)
        if origin and aim then
            local axis = aim - origin
            local span = axis.Magnitude
            if span > 1e-3 then
                local u = axis / span
                local mark = anchor or live
                local behind = (mark - origin):Dot(u)
                if behind < P.pad then origin = origin - u * (P.pad - behind) end
                local ahead = (aim - mark):Dot(u)
                if ahead < P.min_span then aim = mark + u * P.min_span end
                local want = SS.stand_off
                while want > 0 do
                    local probe = origin - u * want
                    if (aim - probe).Magnitude <= P.max_span
                        and los_clear(probe, mark)
                        and los_clear(probe, live) then
                        origin = probe
                        break
                    end
                    want = want - 3
                end
                if (aim - origin).Magnitude > P.max_span then
                    origin = aim - u * P.max_span
                end
                return CFrame.new(origin, aim), CFrame.new(aim), conf or 0, mark
            end
        end
        local vel = force_velocity()
        local dir = Vector3.new(0, -1, 0)
        if vel.Magnitude > 3 then dir = vel.Unit
        else
            local mine = origin_cframe()
            if mine then
                local delta = live - mine.Position
                if delta.Magnitude > 2 then dir = delta.Unit end
            end
        end
        local back = live - dir * 6
        local front = live + dir * math.max(P.min_span, vel.Magnitude * lead_time() + 8)
        if not force_clear(back, front) then back = live - dir * 2.5 end
        return CFrame.new(back, front), CFrame.new(front), 0, live
    end

    local function shot_shift(dt)
        if not SS.predict or not TR.ready or dt <= 0 then return Vector3.zero end
        local shift = Vector3.new(TR.vel.X * dt, 0, TR.vel.Z * dt)
        if TR.air then
            local g = grav()
            local horizon = lead_time()
            local vy = TR.vel.Y
            local phase = math.max(0, os.clock() - TR.air_since)
            local modeled = TR.jump_v - g * phase
            if TR.jumping and TR.jump_v > 0 and g > 0
                and phase <= TR.jump_v / g and modeled > vy then
                vy = modeled
            end
            shift = Vector3.new(shift.X, vy * dt - g * horizon * dt - 0.5 * g * dt * dt, shift.Z)
        end
        return shift
    end

    local function compensate_force(origin_cf, aim_cf, started)
        if SS.force then return origin_cf, aim_cf end
        local shift = shot_shift(math.max(0, os.clock() - started))
        if shift == Vector3.zero then return origin_cf, aim_cf end
        local origin = origin_cf.Position + shift
        local aim = aim_cf.Position + shift
        return CFrame.new(origin, aim), CFrame.new(aim)
    end

    local function resolve_shot()
        if not SS.enabled or not SS.am_sheriff or not target_alive() then return nil end
        if SS.force then
            local started = os.clock()
            local origin_cf, aim_cf = resolve_force()
            if origin_cf and aim_cf then
                origin_cf, aim_cf = compensate_force(origin_cf, aim_cf, started)
                if push_origin(origin_cf) then return aim_cf end
            end
        end
        local cf = origin_cframe()
        local aim = pick_point(cf and cf.Position or nil, false)
        if not aim then return nil end
        return CFrame.new(aim)
    end

    local function compensate_resolve(cf)
        if SS.force or typeof(cf) ~= "CFrame" then return cf end
        return CFrame.new(cf.Position + shot_shift(math.max(0, os.clock() - pred_stamp)))
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
                local ok, cf = pcall(resolve_shot)
                if ok and cf then return compensate_resolve(cf) end
                return orig_mouse(self, ...)
            end
            hook_screen = function(self, x, y, ...)
                sample_ping()
                local ok, cf = pcall(resolve_shot)
                if ok and cf then return compensate_resolve(cf) end
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
        return (pcall(function() remote:FireServer(start_cf, aim_cf) end))
    end

    local function auto_step(now)
        if not SS.auto_on or not SS.enabled or not SS.am_sheriff or not target_alive() then
            want_since = 0
            return
        end
        local gun, equipped = get_gun()
        if not gun then want_since = 0 return end
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
        if SS.force then
            local started = os.clock()
            local origin_cf, aim_cf = resolve_force()
            if not origin_cf or not aim_cf then return end
            origin_cf, aim_cf = compensate_force(origin_cf, aim_cf, started)
            if push_origin(origin_cf) then
                if fire_gun(gun, origin_cf, aim_cf) then SS.last_shot = now end
            end
            return
        end
        local cf = origin_cframe()
        if not cf then return end
        local aim = pick_point(cf.Position, true)
        if not aim then return end
        local aim_cf = compensate_resolve(CFrame.new(aim))
        if fire_gun(gun, cf, aim_cf) then SS.last_shot = now end
    end

    local watch_conns = {}
    local function clear_watch()
        for k = 1, #watch_conns do
            pcall(function() watch_conns[k]:Disconnect() end)
        end
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

    addOpt(silent_section, "AddToggle", "SilentEnabled", {
        Title = "Включить", Default = false, Flag = "SilentEnabled",
    }, function(v)
        SS.enabled = v
        getgenv().SILENT_AIM_ACTIVE = v
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

    addOpt(silent_section, "AddToggle", "SilentPredict", {
        Title = "Предсказание", Default = true, Flag = "SilentPredict",
    }, function(v)
        SS.predict = v
        if not v then track_clear() end
    end)

    addOpt(silent_section, "AddToggle", "SilentForce", {
        Title = "Стрельба через стены", Default = false, Flag = "SilentForce",
    }, function(v)
        SS.force = v
        if v then
            local so = Options.SilentStandoff
            if so then
                pcall(function() if so.Lock then so:Lock() end end)
                pcall(function() so.Locked = true end)
            end
            local pr = Options.SilentPredict
            if pr then pcall(function() pr:SetValue(false) end) end
            SS.predict = false
            Notify("FH", "Force ВКЛ — предикт выключен", 3)
        else
            restore_origin()
            local so = Options.SilentStandoff
            if so then
                pcall(function() if so.Unlock then so:Unlock() end end)
                pcall(function() so.Locked = false end)
            end
        end
    end)

    addOpt(silent_section, "AddSlider", "SilentStandoff", {
        Title = "Отступ", Default = 15, Min = 0, Max = 40, Rounding = 0, Flag = "SilentStandoff",
    }, function(v) SS.stand_off = tonumber(v) or 15 end)

    addOpt(silent_section, "AddToggle", "SilentAuto", {
        Title = "Авто-выстрел", Default = false, Flag = "SilentAuto",
    }, function(v) SS.auto_on = v end)

    addOpt(silent_section, "AddSlider", "SilentAutoDelay", {
        Title = "Задержка авто", Default = 0, Min = 0, Max = 600, Rounding = 0, Flag = "SilentAutoDelay",
    }, function(v) SS.auto_delay = (tonumber(v) or 0) / 1000 end)

    getgenv().SILENT_INSTALL_HOOKS = function() pcall(install_hooks) end
    getgenv().SILENT_UNLOAD = function()
        SS.enabled = false
        SS.predict = false
        SS.force = false
        SS.auto_on = false
        getgenv().SILENT_AIM_ACTIVE = false
        restore_origin()
        clear_watch()
        track_clear()
        if gun_fired_conn then
            pcall(function() gun_fired_conn:Disconnect() end)
            gun_fired_conn = nil
        end
        if main_conn then
            pcall(function() main_conn:Disconnect() end)
            main_conn = nil
        end
        local m = weapon_service
        if m then
            pcall(function() setreadonly(m, false) end)
            if orig_mouse then pcall(function() m.GetMouseTargetCFrame = orig_mouse end) end
            if orig_screen then pcall(function() m.GetTargetPosition = orig_screen end) end
        end
    end
end

-- ============================================================
-- ТИХИЙ БРОСОК НОЖА (заглушка)
-- ============================================================
do
    local knifeSec = Tabs.Combat:AddSection({Name = "Тихий бросок ножа"})
    addOpt(knifeSec, "AddToggle", "KnifeSilentOn", {
        Title = "Включить", Default = false, Flag = "KnifeSilentOn",
    }, function(v)
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

-- ============================================================
-- КИЛЛ АУРА
-- ============================================================
do
    local tC = Tabs.Combat
    local kaSec = tC:AddSection({Name = "Килл Аура"})

    addOpt(kaSec, "AddDropdown", "KAVersion", {
        Title = "Версия", Values = {"v1", "v2"}, Default = "v2",
    }, function(v)
        killAuraVersion = v
        kaV1.on = false
        kaV2.on = false
        if Options.KAOn and Options.KAOn.Value then
            kaV1.on = v == "v1"
            kaV2.on = v == "v2"
        end
    end)

    addOpt(kaSec, "AddToggle", "KAOn", {Title = "Включить", Default = false}, function(v)
        kaV1.on = v and killAuraVersion == "v1"
        kaV2.on = v and killAuraVersion == "v2"
    end)

    addOpt(kaSec, "AddSlider", "KADist", {
        Title = "Радиус", Min = 5, Max = 60, Default = 30, Rounding = 0,
    }, function(v)
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
                    if th and th.Health > 0 and tp
                        and (tp.Position - my.Position).Magnitude <= kaV1.dist then
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
                    if th and th.Health > 0 and tp
                        and (tp.Position - my.Position).Magnitude <= kaV2.dist then
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
end

-- ============================================================
-- АВТО-ПОДБОР ПИСТОЛЕТА
-- ============================================================
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
            end)
        end
    end)

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
    addOpt(tC, "AddToggle", "AutoGrabGun", {
        Title = "Авто-подбор пистолета", Default = false,
    }, function(v) autoGrabEnabled = v end)

    AddConn("AutoGrabTick", RunService.Heartbeat:Connect(function()
        if not autoGrabEnabled then return end
        if getgenv().FH_INVIS_ACTIVE then return end
        if getRoleFromData(LocalPlayer) == "murderer" then return end
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
                if getgenv().FH_INVIS_ACTIVE then break end
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
-- FLING (с предиктом для ходящих)
-- ============================================================
do
    local fling_state = {
        enabled = false,
        mode = "Predict",
        velocity_check = false,
        hold_time = 2,
        iterations = 3,
    }
    getgenv().FH_FLING = fling_state

    local active_thread = nil

    local function get_ping()
        local ok, v = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        if ok and type(v) == "number" and v == v then
            return math.clamp(v, 0.03, 0.5)
        end
        return 0.12
    end

    local function predict_cframe(hrp, target_root, ping)
        local hum = target_root.Parent and target_root.Parent:FindFirstChildOfClass("Humanoid")
        if not hum then return target_root.CFrame end
        local speed = hum.MoveDirection.Magnitude * (hum.WalkSpeed or 16)
        if speed < 0.5 then return target_root.CFrame end
        local predicted = target_root.Position + hum.MoveDirection * hum.WalkSpeed * ping
        return CFrame.new(predicted) * (target_root.CFrame - target_root.Position)
    end

    local function do_fling(tp)
        if not tp or not tp.Character then return end
        local hrp = getHRP()
        local hum = getHum()
        if not hrp or not hum then return end
        local tc = tp.Character
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        local th = tc:FindFirstChildOfClass("Humanoid")
        if not thrp then return end
        getgenv().FLING_ACTIVE = (getgenv().FLING_ACTIVE or 0) + 1
        local old_pos = hrp.CFrame
        local camera = Workspace.CurrentCamera
        local old_subject = camera.CameraSubject
        camera.CameraSubject = th or thrp
        local old_fdh = Workspace.FallenPartsDestroyHeight
        pcall(function() Workspace.FallenPartsDestroyHeight = 0 / 0 end)

        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)

        local se = hum and hum:GetStateEnabled(Enum.HumanoidStateType.Seated)
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false) end

        local start = tick()
        local ang = 0
        local ping = get_ping()

        repeat
            if hrp and th and thrp and thrp.Parent then
                local target_cf
                if fling_state.mode == "Predict" then
                    target_cf = predict_cframe(hrp, thrp, ping)
                else
                    target_cf = thrp.CFrame
                end
                local tv
                if fling_state.velocity_check then
                    tv = th.MoveDirection * th.WalkSpeed
                else
                    tv = thrp.Velocity
                end
                ang = ang + 100
                hrp.CFrame = CFrame.new(target_cf.Position) * CFrame.new(0, 1.5, 0)
                hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(ang), 0, 0)
                pcall(function()
                    local c = lp_char()
                    if c then c:SetPrimaryPartCFrame(hrp.CFrame) end
                end)
                hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                task.wait()
                hrp.CFrame = CFrame.new(target_cf.Position) * CFrame.new(0, -1.5, 0)
                hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(ang), 0, 0)
                pcall(function()
                    local c = lp_char()
                    if c then c:SetPrimaryPartCFrame(hrp.CFrame) end
                end)
                hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
                task.wait()
            end
        until tick() - start > fling_state.hold_time or not fling_state.enabled

        if bv then bv:Destroy() end
        if hum and se ~= nil then
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, se)
        end
        camera.CameraSubject = old_subject
        if hrp then
            pcall(function()
                hrp.CFrame = old_pos
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                Workspace.FallenPartsDestroyHeight = old_fdh
            end)
        end
        getgenv().FLING_ACTIVE = math.max(0, (getgenv().FLING_ACTIVE or 1) - 1)
    end

    function lp_char()
        return LocalPlayer.Character
    end

    local function clicked_player()
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

    local flingSec = Tabs.Troll:AddSection({Name = "Отброс"})

    addOpt(flingSec, "AddToggle", "ToolFling", {Title = "Флинг тул", Default = false}, function(v)
        fling_state.enabled = v
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        local char = LocalPlayer.Character
        if v then
            if bp and not bp:FindFirstChild("fling") then
                local tool = Instance.new("Tool")
                tool.Name = "fling"
                tool.RequiresHandle = false
                tool.CanBeDropped = false
                tool.Activated:Connect(function()
                    local tp = clicked_player()
                    if tp then do_fling(tp) end
                end)
                tool.Parent = bp
            end
        else
            if bp then
                local t = bp:FindFirstChild("fling")
                if t then t:Destroy() end
            end
            if char then
                local t = char:FindFirstChild("fling")
                if t then t:Destroy() end
            end
        end
    end)

    addOpt(flingSec, "AddDropdown", "FlingMode", {
        Title = "Режим", Values = {"Predict", "Raw"}, Default = "Predict",
    }, function(v) fling_state.mode = v or "Predict" end)

    addOpt(flingSec, "AddToggle", "FlingBypassVel", {
        Title = "Bypass velocity check", Default = false,
    }, function(v) fling_state.velocity_check = v end)

    addOpt(flingSec, "AddSlider", "FlingHold", {
        Title = "Длительность", Min = 0.5, Max = 5, Default = 2, Rounding = 1,
    }, function(v) fling_state.hold_time = tonumber(v) or 2 end)
end

-- ============================================================
-- ДВИЖЕНИЕ
-- ============================================================
do
    local tM = Tabs.Movement
    local mvSec = tM:AddSection({Name = "Основное"})

    addOpt(mvSec, "AddToggle", "SpeedToggle", {Title = "Скорость", Default = false}, function() end)
    addOpt(mvSec, "AddSlider", "SpeedValue", {Title = "Скорость ходьбы", Min = 16, Max = 500, Default = 32, Rounding = 0}, function() end)
    addOpt(mvSec, "AddToggle", "Noclip", {Title = "Noclip", Default = false}, function() end)
    addOpt(mvSec, "AddToggle", "Spinbot", {Title = "Spinbot", Default = false}, function() end)
    addOpt(mvSec, "AddSlider", "SpinSpeed", {Title = "Скорость кручения", Min = 1, Max = 50, Default = 8, Rounding = 0}, function() end)
    addOpt(mvSec, "AddToggle", "InfJump", {Title = "Бесконечный прыжок", Default = false}, function() end)
    addOpt(mvSec, "AddToggle", "JumpPowerToggle", {Title = "Своя сила прыжка", Default = false}, function() end)
    addOpt(mvSec, "AddSlider", "JumpPowerVal", {Title = "Сила прыжка", Min = 50, Max = 500, Default = 100, Rounding = 0}, function() end)
    addOpt(mvSec, "AddToggle", "FlyToggle", {Title = "Полёт", Default = false}, function() end)
    addOpt(mvSec, "AddSlider", "FlySpeed", {Title = "Скорость полёта", Min = 20, Max = 500, Default = 60, Rounding = 0}, function() end)
    addOpt(mvSec, "AddToggle", "BhopOn", {Title = "Банихоп", Default = false}, function() end)
    addOpt(mvSec, "AddSlider", "BhopPower", {Title = "Сила банихопа", Min = 10, Max = 150, Default = 40, Rounding = 0}, function() end)
    addOpt(mvSec, "AddToggle", "BhopStrafe", {Title = "Стрейф", Default = false}, function() end)

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
                    if md.Magnitude > 0.1 then
                        dir = Vector3.new(md.X, 0, md.Z).Unit
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

    addOpt(mvSec, "AddToggle", "SpeedGlitchOn", {Title = "Спидглитч", Default = false}, function(v) sgOn = v end)
    addOpt(mvSec, "AddSlider", "SpeedGlitchPower", {Title = "Скорость в прыжке", Min = 30, Max = 250, Default = 90, Rounding = 0}, function(v) sgPower = tonumber(v) or 90 end)
    addOpt(mvSec, "AddSlider", "SpeedGlitchAccel", {Title = "Разгон", Min = 0.1, Max = 1, Default = 0.6, Rounding = 2}, function(v) sgAccel = tonumber(v) or 0.6 end)

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
            local dir = flat.Magnitude > 0.1 and flat.Unit
                or (function()
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

    local freezeSec = tM:AddSection({Name = "Заморозка"})
    addOpt(freezeSec, "AddToggle", "FreezeToggle", {Title = "Включить", Default = false}, function(v) S.frozen = v end)
    addOpt(freezeSec, "AddSlider", "FreezeSpeed", {Title = "Скорость", Min = 20, Max = 300, Default = 60, Rounding = 0}, function() end)

    local fUp = freezeSec:AddKeybind("FreezeUpKey", {Title = "Кнопка ВВЕРХ", Default = "Space"})
    fUp:OnChanged(function(k) if typeof(k) == "EnumItem" then S.freezeUpKey = k end end)
    registerOnChanged("FreezeUpKey", function(k)
        if typeof(k) == "EnumItem" then S.freezeUpKey = k end
    end)

    local fDown = freezeSec:AddKeybind("FreezeDownKey", {Title = "Кнопка ВНИЗ", Default = "LeftAlt"})
    fDown:OnChanged(function(k) if typeof(k) == "EnumItem" then S.freezeDownKey = k end end)
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
        {id = "SilentEnabled", title = "Тихий выстрел", cat = "Бой", opt = "SilentEnabled"},
        {id = "KAOn", title = "Килл Аура", cat = "Бой", opt = "KAOn"},
        {id = "AutoGrabGun", title = "Авто-подбор пистолета", cat = "Бой", opt = "AutoGrabGun"},
        {id = "SpeedToggle", title = "Скорость", cat = "Движение", opt = "SpeedToggle"},
        {id = "Noclip", title = "Noclip", cat = "Движение", opt = "Noclip"},
        {id = "Spinbot", title = "Спинбот", cat = "Движение", opt = "Spinbot"},
        {id = "InfJump", title = "Бесконечный прыжок", cat = "Движение", opt = "InfJump"},
        {id = "JumpPowerToggle", title = "Своя сила прыжка", cat = "Движение", opt = "JumpPowerToggle"},
        {id = "SpeedGlitchOn", title = "Спидглитч", cat = "Движение", opt = "SpeedGlitchOn"},
        {id = "FlyToggle", title = "Полёт", cat = "Движение", opt = "FlyToggle"},
        {id = "BhopOn", title = "Банихоп", cat = "Движение", opt = "BhopOn"},
        {id = "FreezeToggle", title = "Заморозка", cat = "Движение", opt = "FreezeToggle"},
        {id = "InvisOn", title = "Невидимость", cat = "Другое", opt = "InvisOn"},
    }

    local BindState = {}
    for _, e in ipairs(BIND_LIST) do
        BindState[e.id] = {key = nil, touchOn = false, btn = nil, def = e}
    end
    getgenv().FH_BindState = BindState

    local touchGui = Instance.new("ScreenGui")
    touchGui.Name = "FH_TouchBinds_v22"
    touchGui.ResetOnSpawn = false
    touchGui.IgnoreGuiInset = true
    touchGui.DisplayOrder = 400
    pcall(function()
        touchGui.Parent = (gethui and gethui()) or CoreGui
    end)
    if not touchGui.Parent then touchGui.Parent = CoreGui end

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

    local function makeTouchButton(id)
        local st = BindState[id]
        if not st or st.btn then return end
        local def = st.def
        local btn = Instance.new("TextButton")
        btn.Name = "FH_BTN_" .. id
        btn.Size = UDim2.fromOffset(150, 34)
        local vp = (Camera and Camera.ViewportSize) or Vector2.new(1280, 720)
        btn.Position = UDim2.fromOffset(vp.X * 0.5 - 75, vp.Y * 0.5 - 17)
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
            if i.UserInputType == Enum.UserInputType.MouseButton1 or
               i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                moved = false
                dragStart = i.Position
                posStart = btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if getgenv().FH_ButtonsFrozen then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or
               i.UserInputType == Enum.UserInputType.Touch then
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
            if i.UserInputType ~= Enum.UserInputType.MouseButton1 and
               i.UserInputType ~= Enum.UserInputType.Touch then return end
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

    local listSec = tB:AddSection({Name = "Модули"})
    local currentCat
    for _, def in ipairs(BIND_LIST) do
        if def.cat ~= currentCat then
            currentCat = def.cat
            pcall(function()
                listSec:AddButton({Title = "--- " .. currentCat .. " ---", Callback = function() end})
            end)
        end
        local st = BindState[def.id]
        local kb = listSec:AddKeybind("BIND_KEY_" .. def.id, {Title = def.title, Default = "Unknown"})
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

    local setSec = tB:AddSection({Name = "Настройки биндов"})
    addOpt(setSec, "AddToggle", "BIND_FREEZE", {
        Title = "Заморозка кнопок", Default = false,
    }, function(v)
        getgenv().FH_ButtonsFrozen = v
        Notify("FH", v and "Кнопки заморожены" or "Кнопки разморожены", 1.5)
    end)

    setSec:AddButton({Title = "Сбросить все бинды", Callback = function()
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

    setSec:AddButton({Title = "Удалить все кнопки", Callback = function()
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
        for id, st in pairs(BindState) do killTouchButton(id) end
        pcall(function() touchGui:Destroy() end)
    end
end

-- ============================================================
-- НАСТРОЙКИ + КОНФИГИ (исправлено)
-- ============================================================
do
    local tS = Tabs.Settings
    local setSec = tS:AddSection({Name = "Основные"})

    addOpt(setSec, "AddToggle", "ShowHUD", {Title = "Показывать HUD", Default = true}, function(v)
        if HUDGui then HUDGui.Enabled = v end
    end)

    addOpt(setSec, "AddSlider", "FPSCap", {
        Title = "Лимит FPS (0 - без лимита)", Min = 0, Max = 9999, Default = 0, Rounding = 0,
    }, function(v)
        pcall(function()
            if setfpscap then setfpscap(tonumber(v) or 0) end
        end)
    end)

    setSec:AddButton({Title = "Переподключиться к серверу", Callback = function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end})

    setSec:AddButton({Title = "Сменить сервер", Callback = function()
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

    addOpt(setSec, "AddToggle", "AntiAFK", {Title = "Anti-AFK", Default = true}, function() end)
    AddConn("AntiAFK", LocalPlayer.Idled:Connect(function()
        if Options.AntiAFK and Options.AntiAFK.Value then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Camera.CFrame)
            end)
        end
    end))

    setSec:AddButton({Title = "Выгрузить скрипт", Callback = function()
        for _, c in pairs(Connections) do
            pcall(function() c:Disconnect() end)
        end
        Connections = {}
        if HUDGui then HUDGui:Destroy() end
        if Window then pcall(function() Window:Destroy() end) end
        Notify("FH", "Скрипт выгружен", 3)
    end})

    -- ============================================================
    -- КОНФИГИ (ИСПРАВЛЕНО)
    -- ============================================================
    local cfgSec = tS:AddSection({Name = "Конфиги"})
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

    local function serializeValue(v)
        if typeof(v) == "Color3" then
            return string.format("C:%.6f,%.6f,%.6f", v.R, v.G, v.B)
        end
        if typeof(v) == "EnumItem" then
            if v.EnumType == Enum.KeyCode then
                return "K:" .. v.Name
            end
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
        if prefix == "K" then return Enum.KeyCode[rest] end
        if prefix == "C" then
            local r, g, b = string.match(rest, "([^,]+),([^,]+),([^,]+)")
            if r and g and b then
                return Color3.new(tonumber(r), tonumber(g), tonumber(b))
            end
            return nil
        end
        if prefix == "E" then
            local enumType, name = string.match(rest, "^([^|]+)|(.+)$")
            if enumType and name then
                local et = Enum[enumType]
                if et and et[name] then return et[name] end
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
                if n then out[#out + 1] = n else out[#out + 1] = piece end
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
            Notify("FH", "Нет writefile", 4)
            return false
        end
        if not ensureConfigDir() then
            Notify("FH", "Не создал папку", 4)
            return false
        end
        local lines = {
            "-- FortniHub Config: " .. tostring(name),
            "-- " .. os.date("%Y-%m-%d %H:%M:%S"),
        }
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
        local loaded = 0
        local bindLoaded = 0
        local BS = getgenv().FH_BindState
        for line in string.gmatch(data, "[^\r\n]+") do
            if line:sub(1, 2) ~= "--" then
                local key, ser = string.match(line, "^([^\t]+)\t(.+)$")
                if key and ser then
                    if key:sub(1, 9) == "BIND_KEY_" then
                        local id = key:sub(10)
                        local enumVal
                        if ser:sub(1, 2) == "K:" then
                            enumVal = Enum.KeyCode[ser:sub(3)]
                        elseif ser:sub(1, 2) == "E:" then
                            local raw = ser:sub(3)
                            local enumType, keyName = string.match(raw, "^([^|]+)|(.+)$")
                            if enumType and keyName then
                                local et = Enum[enumType]
                                if et and et[keyName] then enumVal = et[keyName] end
                            end
                        elseif ser:sub(1, 2) == "S:" then
                            enumVal = Enum.KeyCode[ser:sub(3)]
                        end
                        if enumVal then
                            pcall(function() Options[key]:SetValue(enumVal) end)
                            if BS and BS[id] then BS[id].key = enumVal end
                            bindLoaded = bindLoaded + 1
                        else
                            pcall(function() Options[key]:SetValue(Enum.KeyCode.Unknown) end)
                            if BS and BS[id] then BS[id].key = nil end
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
    if #currentList == 0 then currentList = {"(нет конфигов)"} end
    local drop = cfgSec:AddDropdown("ConfigPick", {
        Title = "Выбрать конфиг", Values = currentList, Default = currentList[1],
    })

    local function refreshList()
        local list = listConfigs()
        if #list == 0 then list = {"(нет конфигов)"} end
        pcall(function()
            drop:SetValues(list)
            if drop.Generate then drop:Generate() end
        end)
    end

    cfgSec:AddInput("ConfigName", {Title = "Имя конфига", Default = "my_config"})

    cfgSec:AddButton({Title = "Сохранить", Callback = function()
        local nameOpt = Options.ConfigName
        local name = nameOpt and nameOpt.Value or "my_config"
        if type(name) ~= "string" or name == "" then
            Notify("FH", "Введи имя", 3)
            return
        end
        if saveConfig(name) then refreshList() end
    end})

    cfgSec:AddButton({Title = "Загрузить", Callback = function()
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

    if HUDGui then HUDGui.Enabled = true end
end

-- ============================================================
-- ESP / ВИЗУАЛЫ (сокращённая версия — полный код в Part 2)
-- ============================================================
do
    local espState = {
        enabled = false, box = false,
        boxCol = {Color3.fromRGB(255, 255, 255), 1},
        boxType = "Static",
        boxGrd = false, boxGrd1 = Color3.fromRGB(255, 60, 60), boxGrd2 = Color3.fromRGB(255, 180, 60),
        boxFill = false, boxFillCol = {Color3.fromRGB(255, 60, 60), 0.5},
        name = false, nameCol = {Color3.new(1, 1, 1), 1},
        dist = false, distCol = {Color3.fromRGB(220, 220, 220), 1},
        avatar = false, skel = false, skelCol = {Color3.new(1, 1, 1), 1},
        chams = false,
        chamsFMur = {Color3.fromRGB(255, 60, 60), 0.55},
        chamsOMur = {Color3.fromRGB(255, 60, 60), 0.15},
        chamsFInno = {Color3.new(1, 1, 1), 0.55},
        chamsOInno = {Color3.new(1, 1, 1), 0.15},
        chamsFShf = {Color3.fromRGB(0, 153, 255), 0.55},
        chamsOShf = {Color3.fromRGB(0, 153, 255), 0.15},
        chamsFHero = {Color3.fromRGB(255, 215, 0), 0.55},
        chamsOHero = {Color3.fromRGB(255, 215, 0), 0.15},
        matChams = false, matType = "ForceField",
        matColMur = Color3.fromRGB(255, 60, 60),
        matColInno = Color3.new(1, 1, 1),
        matColShf = Color3.fromRGB(0, 153, 255),
        matColHero = Color3.fromRGB(255, 215, 0),
        flags = false,
        flagMur = {Color3.fromRGB(255, 60, 60), 1},
        flagShf = {Color3.fromRGB(0, 153, 255), 1},
        flagHero = {Color3.fromRGB(255, 215, 0), 1},
        arrows = false,
        arrowMur = Color3.fromRGB(255, 60, 60),
        arrowInno = Color3.new(1, 1, 1),
        arrowShf = Color3.fromRGB(0, 153, 255),
        arrowHero = Color3.fromRGB(255, 215, 0),
        arrowSize = 42, arrowDist = 260, maxDist = 500, allowLocal = false,
    }
    _G.FH_ESP = espState

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
        if role == "Mur" then return Color3.fromRGB(255, 60, 60) end
        if role == "Shf" then return Color3.fromRGB(0, 153, 255) end
        if role == "Hero" then return Color3.fromRGB(255, 215, 0) end
        return Color3.new(1, 1, 1)
    end

    local function getDraw(p)
        local d = drawCache[p]
        if d then return d end
        d = {
            box = {}, boxFill = nil, name = nil, dist = nil,
            avatar = nil, skel = {}, flags = {}, arrow = nil,
        }
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

    RunService.RenderStepped:Connect(function(dt)
        local seen = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer and not espState.allowLocal then
                killCham(p)
            else
                local char = p.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart")
                    or char:FindFirstChild("UpperTorso")
                    or char:FindFirstChild("Torso"))
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
                                local col = espState.boxGrd
                                    and grad(espState.boxGrd1, espState.boxGrd2)
                                    or espState.boxCol[1]
                                local a = (espState.boxCol[2] or 1) * fade
                                if espState.boxType == "Corners" then
                                    local sg = math.min(w, bot - top) * 0.25
                                    local lines = {
                                        {l, top, l + sg, top}, {l, top, l, top + sg},
                                        {r, top, r - sg, top}, {r, top, r, top + sg},
                                        {l, bot, l + sg, bot}, {l, bot, l, bot - sg},
                                        {r, bot, r - sg, bot}, {r, bot, r, bot - sg},
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
                                    local lines = {
                                        {l, top, r, top}, {r, top, r, bot},
                                        {r, bot, l, bot}, {l, bot, l, top},
                                    }
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
                                elseif e.boxFill then
                                    e.boxFill.Visible = false
                                end
                            else
                                for _, ln in pairs(e.box) do ln.Visible = false end
                                if e.boxFill then e.boxFill.Visible = false end
                            end

                            if espState.name then
                                if not e.name then
                                    e.name = Drawing.new("Text")
                                    e.name.Size = 13
                                    e.name.Center = true
                                    e.name.Outline = true
                                end
                                e.name.Text = p.Name
                                e.name.Position = Vector2.new((hsp.X + fsp.X) * 0.5, hsp.Y - 18)
                                e.name.Color = espState.nameCol[1]
                                e.name.Transparency = (espState.nameCol[2] or 1) * fade
                                e.name.Visible = true
                            elseif e.name then
                                e.name.Visible = false
                            end

                            if espState.dist then
                                if not e.dist then
                                    e.dist = Drawing.new("Text")
                                    e.dist.Size = 12
                                    e.dist.Center = true
                                    e.dist.Outline = true
                                end
                                e.dist.Text = string.format("%d studs", math.floor(dist))
                                e.dist.Position = Vector2.new((hsp.X + fsp.X) * 0.5, fsp.Y + 4)
                                e.dist.Color = espState.distCol[1]
                                e.dist.Transparency = (espState.distCol[2] or 1) * fade
                                e.dist.Visible = true
                            elseif e.dist then
                                e.dist.Visible = false
                            end

                            if espState.avatar then
                                if not e.avatar then
                                    e.avatar = Drawing.new("Image")
                                    e.avatar.Size = Vector2.new(40, 40)
                                    pcall(function()
                                        e.avatar.Data = Players:GetUserThumbnailAsync(
                                            p.UserId,
                                            Enum.ThumbnailType.HeadShot,
                                            Enum.ThumbnailSize.Size100x100)
                                    end)
                                end
                                e.avatar.Position = Vector2.new((hsp.X + fsp.X) * 0.5 - 20, hsp.Y - 60)
                                e.avatar.Transparency = fade
                                e.avatar.Visible = true
                            elseif e.avatar then
                                e.avatar.Visible = false
                            end

                            if espState.skel then
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
                                        else
                                            dr.Visible = false
                                        end
                                    elseif e.skel[i] then
                                        e.skel[i].Visible = false
                                    end
                                end
                                for i = #bones + 1, #e.skel do e.skel[i].Visible = false end
                            else
                                for _, dr in pairs(e.skel) do dr.Visible = false end
                            end

                            if espState.flags then
                                local txt = role == "Mur" and "[MURD]"
                                    or (role == "Shf" and "[SHF]"
                                    or (role == "Hero" and "[HERO]" or ""))
                                if txt ~= "" then
                                    if not e.flags[1] then
                                        e.flags[1] = Drawing.new("Text")
                                        e.flags[1].Size = 13
                                        e.flags[1].Outline = true
                                    end
                                    local dr = e.flags[1]
                                    dr.Text = txt
                                    dr.Position = Vector2.new(hsp.X + 60, hsp.Y - 10)
                                    dr.Color = role == "Mur" and espState.flagMur[1]
                                        or (role == "Hero" and espState.flagHero[1] or espState.flagShf[1])
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
                                local onScreen = hsp.X >= 0 and hsp.X <= vp.X
                                    and hsp.Y >= 0 and hsp.Y <= vp.Y
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
                                    e.arrow.PointB = Vector2.new(px - dir.X * sz * 0.5 + perp.X * sz * 0.5,
                                                                   py - dir.Y * sz * 0.5 + perp.Y * sz * 0.5)
                                    e.arrow.PointC = Vector2.new(px - dir.X * sz * 0.5 - perp.X * sz * 0.5,
                                                                   py - dir.Y * sz * 0.5 - perp.Y * sz * 0.5)
                                    e.arrow.Color = role == "Mur" and espState.arrowMur
                                        or (role == "Shf" and espState.arrowShf
                                        or (role == "Hero" and espState.arrowHero or espState.arrowInno))
                                    e.arrow.Transparency = fade
                                    e.arrow.Visible = true
                                end
                            elseif e.arrow then
                                e.arrow.Visible = false
                            end
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
                    else
                        killCham(p)
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
    end)

    Players.PlayerRemoving:Connect(function(p) killCham(p) end)

    local tV = Tabs.Visual
    local espSec = tV:AddSection({Name = "ESP Игроков"})

    addOpt(espSec, "AddToggle", "ESPOn", {Title = "Включить ESP", Default = false}, function(v)
        espState.enabled = v
        if not v then
            for _, e in pairs(drawCache) do dispose(e) end
            drawCache = {}
        end
    end)
    addOpt(espSec, "AddToggle", "ESPBox", {Title = "Рамка", Default = false}, function(v) espState.box = v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxCol", {Title = "Цвет рамки", Default = Color3.new(1, 1, 1)}, function(c) espState.boxCol[1] = c end)
    addOpt(espSec, "AddSlider", "ESPBoxAlpha", {Title = "Прозрачность рамки", Min = 0, Max = 1, Default = 1, Rounding = 2}, function(v) espState.boxCol[2] = tonumber(v) or 1 end)
    addOpt(espSec, "AddDropdown", "ESPBoxType", {Title = "Тип рамки", Values = {"Прямоугольник", "Уголки"}, Default = "Прямоугольник"}, function(v) espState.boxType = (v == "Уголки") and "Corners" or "Static" end)
    addOpt(espSec, "AddToggle", "ESPName", {Title = "Имя", Default = false}, function(v) espState.name = v end)
    addOpt(espSec, "AddToggle", "ESPDist", {Title = "Дистанция", Default = false}, function(v) espState.dist = v end)
    addOpt(espSec, "AddToggle", "ESPChams", {Title = "Свечение", Default = false}, function(v) espState.chams = v end)
    addOpt(espSec, "AddToggle", "ESPMatChams", {Title = "Материал-чамсы", Default = false}, function(v) espState.matChams = v end)
    addOpt(espSec, "AddDropdown", "ESPMatType", {Title = "Материал", Values = {"ForceField", "Flat", "Chromatic"}, Default = "ForceField"}, function(v) espState.matType = v end)
    addOpt(espSec, "AddToggle", "ESPFlags", {Title = "Метки ролей", Default = false}, function(v) espState.flags = v end)
    addOpt(espSec, "AddToggle", "ESPArrows", {Title = "Стрелки", Default = false}, function(v) espState.arrows = v end)
    addOpt(espSec, "AddSlider", "ESPMaxDist", {Title = "Макс дистанция ESP", Min = 50, Max = 1000, Default = 500, Rounding = 0}, function(v) espState.maxDist = tonumber(v) or 500 end)
    addOpt(espSec, "AddToggle", "ESPAllowLocal", {Title = "Показывать себя", Default = false}, function(v) espState.allowLocal = v end)
end

-- ============================================================
-- ГРАФИК СКОРОСТИ (ИСПРАВЛЕНО — race condition при старте)
-- ============================================================
do
    local lvSec = Tabs.Visual:AddSection({Name = "Свои визуалы"})

    -- ====== China Hat ======
    local chGui = Instance.new("ScreenGui")
    chGui.Name = "FH_ChinaHat_v22"
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
        for _, f in ipairs(chRows) do
            if f.Visible then f.Visible = false end
        end
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
            while #lo >= 2 and cross(lo[#lo - 1], lo[#lo], p) <= 0 do
                table.remove(lo)
            end
            lo[#lo + 1] = p
        end
        local up = {}
        for i = #pts, 1, -1 do
            local p = pts[i]
            while #up >= 2 and cross(up[#up - 1], up[#up], p) <= 0 do
                table.remove(up)
            end
            up[#up + 1] = p
        end
        table.remove(lo)
        table.remove(up)
        local out = {}
        for _, p in ipairs(lo) do out[#out + 1] = p end
        for _, p in ipairs(up) do out[#out + 1] = p end
        return out
    end

    RunService.RenderStepped:Connect(function()
        if not chOn then chHideAll() return end
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head then chHideAll() return end
        local cam = Workspace.CurrentCamera
        if not cam then chHideAll() return end
        local base = Vector3.new(head.Position.X, head.Position.Y + head.Size.Y * 0.5 - DROP, head.Position.Z)
        local apex2d, ok = proj(base + Vector3.new(0, HEIGHT, 0))
        if not ok then chHideAll() return end
        local pts = {apex2d}
        for i = 1, SEG do
            local a = (i - 1) / SEG * math.pi * 2
            local p, ok2 = proj(base + Vector3.new(math.cos(a) * RAD, 0, math.sin(a) * RAD))
            if not ok2 then chHideAll() return end
            pts[#pts + 1] = p
        end
        local h = hull(pts)
        if #h < 3 then chHideAll() return end
        local minY, maxY = math.huge, -math.huge
        for _, p in ipairs(h) do
            if p.Y < minY then minY = p.Y end
            if p.Y > maxY then maxY = p.Y end
        end
        minY = math.max(0, math.floor(minY))
        maxY = math.min(cam.ViewportSize.Y, math.ceil(maxY))
        if maxY - minY < 2 then chHideAll() return end
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
                local col = chCol:Lerp(Color3.new(1, 1, 1), light * 0.26)
                    :Lerp(Color3.new(0, 0, 0), dark * 0.12)
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

    addOpt(lvSec, "AddToggle", "ChinaHatOn", {Title = "Китайская шляпа", Default = false}, function(v) chOn = v end)
    addOpt(lvSec, "AddColorPicker", "ChinaHatCol", {Title = "Цвет", Default = Color3.fromRGB(170, 85, 255)}, function(c) chCol = c end)

    -- ====== Land Circle ======
    local lcOn, lcCol, lcTr, lcDur = false, Color3.new(1, 1, 1), 1, 0.82
    local lcConn

    local function lcHit(char, root)
        local prm = RaycastParams.new()
        prm.FilterType = Enum.RaycastFilterType.Exclude
        prm.FilterDescendantsInstances = {char}
        prm.IgnoreWater = true
        local hit = Workspace:Raycast(root.Position + Vector3.new(0, 1, 0),
            Vector3.new(0, -16, 0), prm)
        if hit then return hit.Position, hit.Normal end
    end

    local function lcMake(p, n)
        local ref = math.abs(n.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
        local right = n:Cross(ref).Unit
        local front = right:Cross(n).Unit
        local pt = Instance.new("Part")
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
            if state == Enum.HumanoidStateType.Jumping or
               state == Enum.HumanoidStateType.Freefall then
                air = true
            elseif state == Enum.HumanoidStateType.Landed and air and lcOn then
                air = false
                local p, n = lcHit(char, root)
                if p and n then lcMake(p, n) end
            end
        end)
    end

    addOpt(lvSec, "AddToggle", "LandCircleOn", {Title = "Круг падения", Default = false}, function(v)
        lcOn = v
        if v then lcBind()
        elseif lcConn then
            pcall(function() lcConn:Disconnect() end)
            lcConn = nil
        end
    end)
    addOpt(lvSec, "AddColorPicker", "LandCircleCol", {Title = "Цвет", Default = Color3.new(1, 1, 1)}, function(c) lcCol = c end)
    addOpt(lvSec, "AddSlider", "LandCircleTr", {Title = "Прозрачность", Min = 0, Max = 1, Default = 1, Rounding = 2}, function(v) lcTr = tonumber(v) or 1 end)
    addOpt(lvSec, "AddSlider", "LandCircleDur", {Title = "Длительность", Min = 0.1, Max = 3, Default = 0.82, Rounding = 2}, function(v) lcDur = tonumber(v) or 0.82 end)

    -- ====== ГРАФИК СКОРОСТИ (ИСПРАВЛЕНО) ======
    local mgOn, mgCol = false, Color3.fromRGB(242, 242, 242)
    local mgWidth, mgHeight, mgOffset = 280, 72, 180
    local mgLines, mgShadows = {}, {}
    local mgCurrent
    local mgHist, mgAccum, mgSmooth = {}, 0, 0
    local mgSpan, mgStep = 2.8, 1 / 45
    local mgConn

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
        -- ИСПРАВЛЕНИЕ: сначала инициализируем гладкую скорость ДО заполнения истории
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
                while #mgHist > 2 and mgHist[2].t < cutoff do
                    table.remove(mgHist, 1)
                end
            end
            local vp = Camera.ViewportSize
            local w = math.min(mgWidth, math.max(120, vp.X - 48))
            local h = math.min(mgHeight, math.max(36, vp.Y - 32))
            local left = math.floor(vp.X * 0.5 - w * 0.5)
            local center = math.clamp(math.floor(vp.Y * 0.5 + mgOffset),
                h * 0.5 + 8, vp.Y - h * 0.5 - 8)
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

    addOpt(lvSec, "AddToggle", "MovGraphOn", {Title = "График скорости", Default = false}, function(v)
        mgOn = v
        if v then mgStart() else mgClear() end
    end)
    addOpt(lvSec, "AddColorPicker", "MovGraphCol", {Title = "Цвет", Default = Color3.fromRGB(242, 242, 242)}, function(c)
        mgCol = c
        for i = 1, #mgLines do mgLines[i].Color = c end
    end)
    addOpt(lvSec, "AddSlider", "MovGraphW", {Title = "Ширина", Min = 180, Max = 420, Default = 280, Rounding = 0}, function(v) mgWidth = tonumber(v) or 280 end)
    addOpt(lvSec, "AddSlider", "MovGraphH", {Title = "Высота", Min = 40, Max = 120, Default = 72, Rounding = 0}, function(v) mgHeight = tonumber(v) or 72 end)
    addOpt(lvSec, "AddSlider", "MovGraphY", {Title = "Смещение Y", Min = -200, Max = 400, Default = 180, Rounding = 0}, function(v) mgOffset = tonumber(v) or 180 end)

    -- ====== Прицел ======
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
            {cx, cy - gap, cx, cy - gap - len},
            {cx, cy + gap, cx, cy + gap + len},
            {cx - gap, cy, cx - gap - len, cy},
            {cx + gap, cy, cx + gap + len, cy},
        }
        for i = 1, 4 do
            local a = arr[i]
            chLines[i].From = Vector2.new(a[1], a[2])
            chLines[i].To = Vector2.new(a[3], a[4])
            chLines[i].Color = chCol2
            chLines[i].Visible = true
        end
    end)
    addOpt(lvSec, "AddToggle", "CrosshairOn", {Title = "Прицел", Default = false}, function(v)
        chOn2 = v
        pcall(function() UserInputService.MouseIconEnabled = not v end)
    end)
    addOpt(lvSec, "AddColorPicker", "CrosshairCol", {Title = "Цвет", Default = Color3.new(1, 1, 1)}, function(c) chCol2 = c end)
end

-- ============================================================
-- БЭКТРЕК (Classic) — с заготовкой под 2-й режим (Ghost)
-- ============================================================
do
    local sv = Tabs.Visual:AddSection({Name = "Бэктрек"})

    local players = Players
    local run = RunService
    local stats = Stats
    local lp = LocalPlayer
    local ws = Workspace

    local bt_on = false
    local bt_col = Color3.fromRGB(255, 60, 60)
    local bt_mode = "Classic"          -- Classic | Ghost
    local bt_model
    local BT_CAP = 256
    local bt_hist = table.create(BT_CAP)
    for i = 1, BT_CAP do bt_hist[i] = {0, CFrame.identity} end
    local bt_first, bt_count = 1, 0
    local bt_ping, bt_ping_at = 0.15, 0
    local bt_pairs = {}

    local function bt_read_ping()
        local ok, v = pcall(function()
            return stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
        if ok and type(v) == "number" and v == v then return v end
        return 0.15
    end

    local function bt_destroy()
        if bt_model then
            if _G.BACKTRACK_CLONES then _G.BACKTRACK_CLONES[bt_model] = nil end
            pcall(function() bt_model:Destroy() end)
            bt_model = nil
        end
        bt_pairs = {}
        bt_first, bt_count = 1, 0
    end

    local function bt_build()
        bt_destroy()
        local char = lp.Character
        if not char then return end
        local rhrp = char:FindFirstChild("HumanoidRootPart")
        if not rhrp then return end
        char.Archivable = true
        local ok, m = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not m then return end
        _G.BACKTRACK_CLONES = _G.BACKTRACK_CLONES or {}
        local rparts = {}
        for _, o in char:GetDescendants() do
            if o:IsA("BasePart") then rparts[#rparts + 1] = o end
        end
        local ci = 0
        for _, o in m:GetDescendants() do
            if o:IsA("Script") or o:IsA("LocalScript") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail")
                or o:IsA("PointLight") or o:IsA("SpotLight") or o:IsA("SurfaceLight") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("BasePart") then
                o.Anchored = true
                o.CanCollide = false
                o.CanQuery = false
                o.Massless = true
                o.CastShadow = false
                if o.Name == "HumanoidRootPart" then
                    o.Transparency = 1
                else
                    o.Material = Enum.Material.ForceField
                    o.Color = bt_col
                    o.Transparency = 0
                end
                ci = ci + 1
                bt_pairs[#bt_pairs + 1] = {o, rparts[ci]}
            end
        end
        local hum = m:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:Destroy() end) end
        m.Parent = ws
        bt_model = m
        _G.BACKTRACK_CLONES[m] = true
    end

    local function bt_update()
        local char = lp.Character
        local rhrp = char and char:FindFirstChild("HumanoidRootPart")
        if not rhrp then return end
        if getgenv().FAKE_POS_ACTIVE then
            if bt_model and bt_model.Parent then bt_model.Parent = nil end
            return
        end
        if not bt_model then
            bt_build()
            if not bt_model then return end
        end
        if not bt_model.Parent then bt_model.Parent = ws end
        local now = os.clock()
        local base_cf = rhrp.CFrame
        if bt_count < BT_CAP then
            bt_count = bt_count + 1
        else
            bt_first = bt_first % BT_CAP + 1
        end
        local slot = bt_hist[(bt_first + bt_count - 2) % BT_CAP + 1]
        slot[1] = now
        slot[2] = base_cf
        if now - bt_ping_at >= 0.2 then
            bt_ping_at = now
            local v = bt_read_ping()
            bt_ping = math.clamp(v, 0.05, 0.6)
        end
        local target = now - bt_ping
        local cf = base_cf
        for k = bt_count, 1, -1 do
            local s = bt_hist[(bt_first + k - 2) % BT_CAP + 1]
            if s[1] <= target then cf = s[2]; break end
        end
        while bt_count > 0 and bt_hist[bt_first][1] < now - 1 do
            bt_first = bt_first % BT_CAP + 1
            bt_count = bt_count - 1
        end
        local baseInv = rhrp.CFrame:Inverse()
        for i = 1, #bt_pairs do
            local cp, rp = bt_pairs[i][1], bt_pairs[i][2]
            if cp and cp.Parent and rp and rp.Parent then
                cp.CFrame = cf * (baseInv * rp.CFrame)
            end
        end
    end

    -- ===== Заготовка под 2-й режим (Client Ghost) — доделаем в Part 2 =====
    local function ghost_enable(v)
        -- В Part 2 будет полная реализация
        if v then
            Notify("FH", "Client Ghost: реализация в Part 2", 3)
        end
    end

    addOpt(sv, "AddToggle", "BacktrackOn", {Title = "Включить бэктрек", Default = false}, function(v)
        bt_on = v
        if v then
            if not _G.FH_BT_CONN then
                _G.FH_BT_CONN = RunService.Heartbeat:Connect(function()
                    if bt_on and bt_mode == "Classic" then bt_update() end
                end)
            end
            if not bt_model then bt_build() end
        else
            if bt_mode == "Classic" then bt_destroy() end
            if bt_mode == "Ghost" then ghost_enable(false) end
        end
    end)

    addOpt(sv, "AddDropdown", "BacktrackMode", {
        Title = "Режим", Values = {"Classic", "Ghost"}, Default = "Classic",
    }, function(v)
        bt_mode = v or "Classic"
        if bt_mode == "Classic" then
            ghost_enable(false)
            if bt_model then bt_model.Parent = ws end
        else
            bt_destroy()
            ghost_enable(bt_on)
        end
    end)

    addOpt(sv, "AddColorPicker", "BacktrackCol", {
        Title = "Цвет", Default = Color3.fromRGB(255, 60, 60),
    }, function(c)
        bt_col = c
        if bt_model then
            for _, p in ipairs(bt_model:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    p.Color = c
                end
            end
        end
    end)
end

-- ============================================================
-- АНИМАЦИИ (эмоции работают как анимации — подменяем Animate)
-- ============================================================
do
    local animSec = Tabs.Animations:AddSection({Name = "Анимации персонажа"})

    local ORIG_ANIMS = {
        idle = "rbxassetid://180435571",
        walk = "rbxassetid://180426354",
        run  = "rbxassetid://180426354",
        jump = "rbxassetid://125750702",
        fall = "rbxassetid://180436148",
        climb = "rbxassetid://180436334",
        swim = "rbxassetid://180436334",
    }

    local PACKS = {
        ["Default"] = nil,
        ["Zombie"]  = {idle = "rbxassetid://616158929", walk = "rbxassetid://616160636"},
        ["Ninja"]   = {idle = "rbxassetid://656117400", walk = "rbxassetid://656118341"},
        ["Robot"]   = {idle = "rbxassetid://616088211", walk = "rbxassetid://616090535"},
        ["Pirate"]  = {idle = "rbxassetid://750781874", walk = "rbxassetid://750782230"},
        ["Levitate"] = {idle = "rbxassetid://616006778", walk = "rbxassetid://616008087"},
    }
    local packNames = {}
    for k in pairs(PACKS) do packNames[#packNames + 1] = k end
    table.sort(packNames)

    local activePack = "Default"

    local function applyPack(packName)
        local char = LocalPlayer.Character
        if not char then return end
        local animate = char:FindFirstChild("Animate")
        if not animate then return end
        local pack = PACKS[packName]
        local source = pack or ORIG_ANIMS
        for cat, id in pairs(source) do
            local folder = animate:FindFirstChild(cat)
            if folder then
                local anim = folder:FindFirstChildWhichIsA("Animation")
                if anim then
                    anim.AnimationId = id
                    anim.Parent = nil
                    anim.Parent = folder
                end
            end
        end
        -- триггерим перезагрузку Animate
        if char:FindFirstChildOfClass("Humanoid") then
            animate.Disabled = true
            task.wait()
            animate.Disabled = false
        end
    end

    addOpt(animSec, "AddDropdown", "AnimPack", {
        Title = "Пакет анимаций", Values = packNames, Default = "Default",
    }, function(v)
        activePack = v or "Default"
        applyPack(activePack)
        Notify("FH", "Анимации: " .. activePack, 2)
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if activePack ~= "Default" then applyPack(activePack) end
    end)
end

-- ============================================================
-- УТИЛИТЫ: НЕВИДИМОСТЬ + ЗВУКИ (KITI) + UI SOUNDS + АНТИ
-- ============================================================
do
    local tU = Tabs.Utility

    -- ===== УВЕДОМЛЕНИЯ О РОЛИ =====
    local notifySec = tU:AddSection({Name = "Уведомления"})
    local notifyOn, rolesOn = false, false
    local lastRole
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
    addOpt(notifySec, "AddToggle", "NotifyOn", {Title = "Включить", Default = false}, function(v) notifyOn = v end)
    addOpt(notifySec, "AddToggle", "NotifyRoles", {Title = "Показывать роль", Default = false}, function(v) rolesOn = v end)

    -- ===== НЕВИДИМОСТЬ =====
    local invisSec = tU:AddSection({Name = "Невидимость"})
    local invis = {
        active = false, realCF = nil, hbConn = nil,
        bindName = "FH_InvisClient", savedLTM = {}, savedDecals = {},
        savedFallenHeight = nil,
    }
    local HIDDEN_CF = CFrame.new(0, -50000, 0)
    getgenv().FH_INVIS_ACTIVE = false

    local function invisRestoreParts()
        local char = LocalPlayer.Character
        if char then
            for p, v in pairs(invis.savedLTM) do
                if p and p.Parent then
                    pcall(function() p.LocalTransparencyModifier = v end)
                end
            end
            for d, v in pairs(invis.savedDecals) do
                if d and d.Parent then
                    pcall(function() d.Transparency = v end)
                end
            end
        end
        invis.savedLTM = {}
        invis.savedDecals = {}
    end

    local function invisBegin()
        if invis.active then return end
        local char = LocalPlayer.Character
        if not char then Notify("FH", "Персонаж не загружен", 2) return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then Notify("FH", "Персонаж не загружен", 2) return end
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
        RunService:BindToRenderStep(invis.bindName,
            Enum.RenderPriority.Camera.Value - 1, function()
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

    addOpt(invisSec, "AddToggle", "InvisOn", {Title = "Включить невидимость", Default = false}, function(v)
        if v then invisBegin() else invisEnd() end
    end)
    getgenv().INVIS_UNLOAD = function() if invis.active then invisEnd() end end

    -- ===== KITI ЗВУКИ (только убийства/выстрелы, без GameSounds) =====
    local sndSec = tU:AddSection({Name = "Звуки (KITI)"})

    local SND_CACHE_DIR = "shitaro_sounds/"
    local SND_USER_DIR = "sounds/"
    local SND_USER_EXTS = {[".ogg"] = true, [".mp3"] = true, [".wav"] = true}
    local SND_BASE_URL = "https://github.com/khenn791/lmao/raw/refs/heads/main/"

    local SND_LIST = {
        "primordial", "neverlose", "sparkle", "mc bow", "skeet",
        "break", "rust", "applepay", "bubble", "combobreak",
        "killcard", "xp", "na naxuy", "stony", "hentai",
    }

    local snd_cfg = {
        sheriff = {on = false, name = "mc bow", volume = 1},
        murder = {on = false, name = "skeet", volume = 1},
        knife = {on = false, name = "sparkle", volume = 0.8},
    }

    local snd_cache = {}
    local snd_pool = {}
    local snd_last = {sheriff = 0, murder = 0, knife = 0}
    local snd_hooked = {}

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
            pcall(function()
                if type(delfile) == "function" then delfile(tmp) end
            end)
            return nil
        end
        return asset, tmp
    end

    local function snd_resolve(name)
        local cached = snd_cache[name]
        if cached then return cached end
        if not snd_fs_ready() then return nil end
        local dirs = {SND_USER_DIR, "", SND_CACHE_DIR, "shitaroebet/", "assets/"}
        local exts = {".ogg", ".mp3", ".wav", ""}
        for _, dir in ipairs(dirs) do
            for _, ext in ipairs(exts) do
                local asset = snd_load_path(dir .. name .. ext)
                if asset then
                    snd_cache[name] = asset
                    return asset
                end
            end
        end
        -- попытка скачать
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not pcall(isfolder, SND_CACHE_DIR) then
                pcall(makefolder, SND_CACHE_DIR)
            end
            local path = SND_CACHE_DIR .. name .. ".ogg"
            local hasFile = pcall(isfile, path) and isfile(path)
            if not hasFile then
                local url = SND_BASE_URL .. (string.gsub(name, " ", "%%20")) .. ".ogg"
                local ok_dl, data = pcall(function() return game:HttpGet(url) end)
                if ok_dl and type(data) == "string" and #data > 1024 then
                    pcall(writefile, path, data)
                end
            end
            if pcall(isfile, path) and isfile(path) then
                local ok_as, asset = pcall(getcustomasset, path)
                if ok_as and asset then
                    snd_cache[name] = asset
                    return asset
                end
            end
        end
        return nil
    end

    local function snd_play(kind)
        local cfg = snd_cfg[kind]
        if not cfg or not cfg.on then return end
        local id = snd_resolve(cfg.name)
        if not id then return end
        if os.clock() - snd_last[kind] < 0.15 then return end
        snd_last[kind] = os.clock()
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = cfg.volume
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 8)
        end)
    end

    -- хуки на звуки игры
    local function snd_hook(inst, kind)
        if snd_hooked[inst] then return end
        local entry = {kind = kind, vol = inst.Volume, conns = {}}
        snd_hooked[inst] = entry
        entry.conns[#entry.conns + 1] = inst.Played:Connect(function()
            if snd_cfg[kind].on then
                pcall(function() inst:Stop() end)
                snd_play(kind)
            end
        end)
        entry.conns[#entry.conns + 1] = inst.Destroying:Connect(function()
            snd_hooked[inst] = nil
        end)
    end

    local function snd_tool_kind(tool)
        if tool:FindFirstChild("GunClient") or tool:FindFirstChild("Shoot") or tool.Name == "Gun" then
            return "sheriff"
        end
        if tool:FindFirstChild("KnifeClient") or tool:FindFirstChild("Events") or tool.Name == "Knife" then
            return "knife"
        end
        return nil
    end

    local function snd_consider(inst)
        if not inst:IsA("Sound") then return end
        if inst.Name ~= "GunKill" and inst.Name ~= "Kill" and inst.Name ~= "Gunshot" then return end
        local handle = inst.Parent
        if not handle or handle.Name ~= "Handle" then return end
        local tool = handle.Parent
        if not tool or not tool:IsA("Tool") then return end
        local kind = snd_tool_kind(tool)
        if kind then snd_hook(inst, kind) end
    end

    local function snd_scan()
        local function scan(container)
            if not container then return end
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local handle = tool:FindFirstChild("Handle")
                    if handle then
                        for _, child in ipairs(handle:GetChildren()) do
                            if child:IsA("Sound") then snd_consider(child) end
                        end
                    end
                end
            end
        end
        scan(LocalPlayer.Character)
        scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    end

    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(snd_scan)
        end
    end)

    addOpt(sndSec, "AddToggle", "SndSheriffKill", {Title = "Шериф убил маньяка", Default = false}, function(v)
        snd_cfg.sheriff.on = v
    end)
    addOpt(sndSec, "AddDropdown", "SndSheriffKillName", {
        Title = "  Звук", Values = SND_LIST, Default = "mc bow",
    }, function(v) snd_cfg.sheriff.name = v end)
    addOpt(sndSec, "AddSlider", "SndSheriffKillVol", {
        Title = "  Громкость", Min = 0.1, Max = 5, Default = 1, Rounding = 1,
    }, function(v) snd_cfg.sheriff.volume = tonumber(v) or 1 end)
    sndSec:AddButton({Title = "  Прослушать", Callback = function()
        local id = snd_resolve(snd_cfg.sheriff.name)
        if id then
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = snd_cfg.sheriff.volume
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 8)
        end
    end})

    addOpt(sndSec, "AddToggle", "SndKnifeKill", {Title = "Убийство ножом", Default = false}, function(v)
        snd_cfg.knife.on = v
    end)
    addOpt(sndSec, "AddDropdown", "SndKnifeKillName", {
        Title = "  Звук", Values = SND_LIST, Default = "sparkle",
    }, function(v) snd_cfg.knife.name = v end)
    addOpt(sndSec, "AddSlider", "SndKnifeKillVol", {
        Title = "  Громкость", Min = 0.1, Max = 5, Default = 0.8, Rounding = 1,
    }, function(v) snd_cfg.knife.volume = tonumber(v) or 0.8 end)

    addOpt(sndSec, "AddToggle", "SndMurderKill", {Title = "Мы убили (за маньяка)", Default = false}, function(v)
        snd_cfg.murder.on = v
    end)
    addOpt(sndSec, "AddDropdown", "SndMurderKillName", {
        Title = "  Звук", Values = SND_LIST, Default = "skeet",
    }, function(v) snd_cfg.murder.name = v end)
    addOpt(sndSec, "AddSlider", "SndMurderKillVol", {
        Title = "  Громкость", Min = 0.1, Max = 5, Default = 1, Rounding = 1,
    }, function(v) snd_cfg.murder.volume = tonumber(v) or 1 end)

    -- ===== UI SOUNDS (ИСПРАВЛЕНО) =====
    local uiSec = tU:AddSection({Name = "Звуки интерфейса"})
    local UI_SOUNDS = {
        ["Enable 1"]   = "rbxassetid://100772509583336",
        ["Sparkle"]    = "rbxassetid://110241936966089",
        ["Laser Click"] = "rbxassetid://18913006341",
        ["Enable 2"]   = "rbxassetid://84626036868067",
        ["Notify"]     = "rbxassetid://103421304020039",
    }
    local uiCfg = {
        enabled = true,
        enableSound = "Enable 1",
        disableSound = "Enable 1",
    }
    getgenv().FH_UISoundCfg = uiCfg

    -- ИСПРАВЛЕНИЕ: играем звук через единственный создаваемый Sound на событие,
    -- а не через Played:Connect, который нестабилен на коротких кликах.
    local function playUiSound(id)
        if not uiCfg.enabled or not id then return end
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = 1
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 5)
        end)
    end
    getgenv().FH_PlayUISound = playUiSound

    addOpt(uiSec, "AddToggle", "FH_UISoundsOn", {
        Title = "Звуки интерфейса", Default = true,
    }, function(v)
        uiCfg.enabled = v
        if v then playUiSound(UI_SOUNDS[uiCfg.enableSound]) end
    end)
    addOpt(uiSec, "AddDropdown", "FH_UISoundEnable", {
        Title = "Звук включения",
        Values = {"Enable 1", "Sparkle", "Laser Click", "Enable 2", "Notify"},
        Default = "Enable 1",
    }, function(v)
        uiCfg.enableSound = v or "Enable 1"
        playUiSound(UI_SOUNDS[uiCfg.enableSound])
    end)
    addOpt(uiSec, "AddDropdown", "FH_UISoundDisable", {
        Title = "Звук выключения",
        Values = {"Enable 1", "Sparkle", "Laser Click", "Enable 2", "Notify"},
        Default = "Enable 1",
    }, function(v)
        uiCfg.disableSound = v or "Enable 1"
        playUiSound(UI_SOUNDS[uiCfg.disableSound])
    end)
    uiSec:AddButton({Title = "Проверить звук включения", Callback = function()
        playUiSound(UI_SOUNDS[uiCfg.enableSound])
    end})
    uiSec:AddButton({Title = "Проверить звук выключения", Callback = function()
        playUiSound(UI_SOUNDS[uiCfg.disableSound])
    end})

    -- ===== АНТИ =====
    local antiSec = tU:AddSection({Name = "Анти"})

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

    addOpt(antiSec, "AddToggle", "AntiFling", {Title = "Анти-отброс", Default = false}, function(v)
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
    addOpt(antiSec, "AddToggle", "AntiVoid", {Title = "Анти-падение", Default = false}, function(v)
        antiVoidOn = v
    end)

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
    addOpt(antiSec, "AddToggle", "AntiTrap", {Title = "Анти-ловушка", Default = false}, function(v)
        antiTrapOn = v
    end)

    getgenv().ANTI_UNLOAD = function()
        antiFlingOn, antiVoidOn, antiTrapOn = false, false, false
        restoreFling()
    end
end

-- ============================================================
-- ТРОЛЛИНГ: ТП-ТУЛ, ФЕЙК-СМЕРТЬ, ТЕЛЕПОРТ
-- ============================================================
do
    local tT = Tabs.Troll

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
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            local t = bp:FindFirstChild("tp")
            if t then pcall(function() t:Destroy() end) end
        end
        local c = LocalPlayer.Character
        if c then
            local t = c:FindFirstChild("tp")
            if t then pcall(function() t:Destroy() end) end
        end
    end

    addOpt(tT:AddSection({Name = "Инструменты"}), "AddToggle", "ToolTP", {
        Title = "ТП-тул", Default = false,
    }, function(v)
        tpOn = v
        if v then giveTpTool() else removeTpTool() end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if tpOn then giveTpTool() end
    end)

    -- ===== Фейк-смерть =====
    local fdSec = tT:AddSection({Name = "Фейк-смерть"})
    local FAKE_DEATH_1_ID = "132384701706046"
    local FAKE_DEATH_2_ID = "125032357496729"
    local fdTrack1, fdTrack2

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

    local function playFd(id, slot)
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then Notify("FH", "Персонаж не загружен", 2) return end
        local resolved = resolveId(id)
        if not resolved then return end
        if slot == 1 and fdTrack1 then
            pcall(function() fdTrack1:Stop() end); fdTrack1 = nil
        end
        if slot == 2 and fdTrack2 then
            pcall(function() fdTrack2:Stop() end); fdTrack2 = nil
        end
        local anim = Instance.new("Animation")
        anim.AnimationId = resolved
        local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
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

    fdSec:AddButton({Title = "Фейк-смерть 1", Callback = function() playFd(FAKE_DEATH_1_ID, 1) end})
    fdSec:AddButton({Title = "Фейк-смерть 2", Callback = function() playFd(FAKE_DEATH_2_ID, 2) end})
    fdSec:AddButton({Title = "Остановить", Callback = function()
        stopAllFd()
        Notify("FH", "Остановлено", 2)
    end})

    -- ===== Телепорт =====
    local function inLobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby" or p.Name == "Lobby" then return true end
            p = p.Parent
        end
        return false
    end

    local tpBtnSec = tT:AddSection({Name = "Телепорт"})
    tpBtnSec:AddButton({Title = "ТП в лобби", Callback = function()
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
    end})
    tpBtnSec:AddButton({Title = "ТП на карту", Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        local spawns = {}
        for _, o in ipairs(Workspace:GetDescendants()) do
            if (o:IsA("SpawnLocation") or (o:IsA("BasePart") and o.Name == "Spawn"))
                and not inLobby(o) then
                spawns[#spawns + 1] = o
            end
        end
        if #spawns > 0 then
            local s = spawns[math.random(1, #spawns)]
            hrp.CFrame = s.CFrame + Vector3.new(0, 5, 0)
        end
    end})

    getgenv().TROLL_UNLOAD = function()
        tpOn = false
        removeTpTool()
        stopAllFd()
    end
end

-- ============================================================
-- ФАРМ (только Basic — второй режим удалён)
-- ============================================================
do
    local tF = Tabs.Farm
    local farmSec = tF:AddSection({Name = "Автофарм"})

    local active = false
    local speed = 23
    local avoid = false
    local fullAction = "Respawn"
    local ncCache = {}
    local farmTarget
    local coinsDone, sawCoins = false, false
    local lastTouch = 0
    local AVOID_DIST = 40

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
            return ReplicatedStorage:WaitForChild("Remotes")
                :WaitForChild("Gameplay"):WaitForChild("CoinsStarted", 15)
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
            if type(info) == "table" and info.Role == "Murderer"
                and not info.Dead and name ~= LocalPlayer.Name then
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
        local targets = {coin}
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
        if avoid and mpos and flatDist(v.Position, mpos) < AVOID_DIST * 0.6 then
            return false
        end
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
        local blend = (want.Unit + away * w)
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
        pcall(function()
            my.CFrame = cf
            my.AssemblyLinearVelocity = Vector3.zero
            my.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local function farmRelease()
        setNoclip(false)
    end

    local function fireFullAction()
        if fullAction == "Respawn" then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health = 0 end) end
        elseif fullAction == "Auto" then
            local myRole = getRoleFromData(LocalPlayer)
            if myRole == "murderer" then
                task.spawn(function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    local knife = char:FindFirstChild("Knife")
                    if not knife then
                        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                        knife = bp and bp:FindFirstChild("Knife")
                    end
                    if not knife then return end
                    local ev = knife:FindFirstChild("Events")
                    local stabbed = ev and ev:FindFirstChild("KnifeStabbed")
                    local touched = ev and ev:FindFirstChild("HandleTouched")
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
                                    if th and th.Health > 0 and tp
                                        and (tp.Position - my.Position).Magnitude <= 60 then
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
                        end
                        task.wait(0.05)
                    end
                end)
            end
        end
    end

    local CONFLICT_OPTS = {
        "KAOn", "SilentAuto", "SilentEnabled", "AutoGrabGun",
        "ToolFling", "ToolTP",
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
        for name, was in pairs(savedConflicts) do
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
        if sawCoins and bagsFull() then finish() return end
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
                local dest = cpos
                if (cpos - my.Position).Magnitude <= 6 then
                    fireTouch(farmTarget)
                end
                dest = avoidSteer(my.Position, dest, mpos)
                farmMove(my, dest, dt)
            elseif mpos then
                setNoclip(true)
                local away = Vector3.new(my.Position.X - mpos.X, 0, my.Position.Z - mpos.Z)
                if away.Magnitude < 0.1 then away = Vector3.new(1, 0, 0) end
                away = away.Unit
                farmMove(my, my.Position + away * 40, dt)
            end
        else
            farmTarget = nil
            farmRelease()
            if sawCoins and not coinsDone then finish() end
        end
    end)

    addOpt(farmSec, "AddToggle", "FarmV3On", {Title = "Включить автофарм", Default = false}, function(v)
        active = v
        if v then disableConflicts() else restoreConflicts(); farmRelease() end
        resetProgress()
    end)
    addOpt(farmSec, "AddSlider", "FarmV3Speed", {
        Title = "Скорость", Min = 5, Max = 60, Default = 23, Rounding = 1,
    }, function(v) speed = tonumber(v) or 23 end)
    addOpt(farmSec, "AddToggle", "FarmV3Avoid", {
        Title = "Избегать маньяка", Default = false,
    }, function(v) avoid = v; farmTarget = nil end)
    addOpt(farmSec, "AddDropdown", "FarmFullAction", {
        Title = "При полном мешке", Values = {"Respawn", "Auto"}, Default = "Respawn",
    }, function(v) fullAction = v or "Respawn" end)

    getgenv().FARMV3_UNLOAD = function()
        active = false
        farmTarget = nil
        farmRelease()
        restoreConflicts()
    end
end

-- ============================================================
-- ИГРОКИ (заглушка — полноценный в Part 2)
-- ============================================================
do
    local tP = Tabs.Troll:AddSection({Name = "Игроки"})
    tP:AddLabel("Player List будет в Part 2.")
    tP:AddButton({Title = "Обновить (заглушка)", Callback = function()
        Notify("FH", "Список игроков в Part 2", 3)
    end})
end

-- ============================================================
-- ФИНАЛЬНЫЙ PRINT
-- ============================================================
pcall(function() Window:SelectTab(1) end)
print("[FH] ============================================")
print("[FH] Part 1/2 — FortniHub v20.2 — " .. CREDITS)
print("[FH] Silent | Kill Aura | Fling | Movement | Binds | Settings")
print("[FH] Visual/ESP | Backtrack | Animations | Utility | Troll | Farm")
print("[FH] ============================================")
print("[FH] Часть 2/2 будет содержать: Aura 2.0, Client Ghost как 2-й режим")
print("[FH] бэктрека, новый Skybox Manager, KITI звуки убийств, Player List,")
print("[FH] Trade Helper, Emotes/animation pack расширения, Fake Death, и др.")
-- ============================================================
-- FortniHub v20.2 BETA — Part 2/2
-- Aura 2.0 | Client Ghost | Skybox Manager | Trade Helper
-- Player List | Vote Duper | Advance Farm | RTX | PNG Avatars
-- Water Protection | Fade Disabler | Anti-Coin | Beam Effects
-- Extra Auras | Jump Circle | Fake Korblox/Headless/Model
-- ============================================================

if not (Window and Options and Tabs and Notify and addOpt and registerOnChanged) then
    warn("[FH Part 2] Part 1 не загружена — Part 2 пропущена.")
    return
end

local _Players         = game:GetService("Players")
local _RunService      = game:GetService("RunService")
local _UserInput       = game:GetService("UserInputService")
local _CoreGui         = game:GetService("CoreGui")
local _Lighting        = game:GetService("Lighting")
local _TweenService    = game:GetService("TweenService")
local _Debris          = game:GetService("Debris")
local _Stats           = game:GetService("Stats")
local _SoundService    = game:GetService("SoundService")
local _Workspace       = workspace
local _LP              = _Players.LocalPlayer

local function _getHRP()
    local c = _LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function _getHum()
    local c = _LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
-- ==================== AURA 2.0 (Effects) ====================
-- Работает как второй режим: Classic (из Part 1, там нет — поэтому
-- просто Aura 2.0). KITI-style с покраской партиклов/света,
-- авто-реапплай при респавне.
-- ============================================================
do
    local auraSec = Tabs.Effects:AddSection({Name = "Aura 2.0"})

    local AURA_IDS = {
        angel     = "97658130917593",
        starlight = "134645216613107",
        heavenly  = "139300897520961",
        ribbon    = "132069507632161",
        sakura    = "81755778619404",
        wind      = "80694081850877",
        flow      = "119913533725648",
        star      = "73754563740680",
    }
    local AURA_ORDER = {"angel", "starlight", "heavenly", "ribbon", "sakura", "wind", "flow", "star"}

    local aura_cache, aura_parts = {}, {}
    local aura_on, aura_type, aura_col = false, "angel", Color3.fromRGB(133, 220, 255)
    local aura_conn, aura_sync_conn = nil, nil
    local aura_host = nil

    local function load_aura(name)
        if aura_cache[name] then return aura_cache[name] end
        local id = AURA_IDS[name]
        if not id then return nil end
        local ok, objs = pcall(game.GetObjects, game, "rbxassetid://" .. id)
        if ok and objs and objs[1] then
            aura_cache[name] = objs[1]
            return objs[1]
        end
        return nil
    end

    local function color_aura(model, color)
        local seq = ColorSequence.new(color)
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("PointLight") or d:IsA("SpotLight") then
                d.Color = color
            elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
                pcall(function() d.Color = seq end)
            end
        end
    end

    local function clear_aura()
        for i = #aura_parts, 1, -1 do
            pcall(function() aura_parts[i]:Destroy() end)
            aura_parts[i] = nil
        end
        aura_host = nil
    end

    local function apply_aura()
        clear_aura()
        local char = _LP.Character
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
                    aura_parts[#aura_parts + 1] = child
                end
            end
        end
        clone:Destroy()
        aura_host = char
    end

    local function start_aura()
        clear_aura()
        if not aura_on then return end
        task.spawn(apply_aura)
        if aura_conn then pcall(function() aura_conn:Disconnect() end) end
        aura_conn = _LP.CharacterAdded:Connect(function()
            task.wait(0.5)
            if aura_on then apply_aura() end
        end)
        -- периодическая пересинхронизация (part очищается при смерти)
        if aura_sync_conn then pcall(function() aura_sync_conn:Disconnect() end) end
        aura_sync_conn = _RunService.Heartbeat:Connect(function()
            if not aura_on then return end
            if aura_host ~= _LP.Character then
                apply_aura()
                return
            end
            local first = aura_parts[1]
            if first and not first.Parent then
                apply_aura()
            end
        end)
    end

    local function stop_aura()
        clear_aura()
        if aura_conn then pcall(function() aura_conn:Disconnect() end); aura_conn = nil end
        if aura_sync_conn then pcall(function() aura_sync_conn:Disconnect() end); aura_sync_conn = nil end
    end

    addOpt(auraSec, "AddToggle", "Aura2On", {
        Title = "Aura 2.0", Default = false,
    }, function(v)
        aura_on = v
        if v then start_aura() else stop_aura() end
        Notify("FH", "Aura 2.0 " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    addOpt(auraSec, "AddDropdown", "Aura2Type", {
        Title = "Тип", Values = AURA_ORDER, Default = "angel",
    }, function(v)
        aura_type = tostring(v)
        if aura_on then task.spawn(apply_aura) end
    end)

    addOpt(auraSec, "AddColorPicker", "Aura2Color", {
        Title = "Цвет", Default = Color3.fromRGB(133, 220, 255),
    }, function(c)
        aura_col = c
        for _, m in pairs(aura_cache) do color_aura(m, c) end
        if aura_on then task.spawn(apply_aura) end
    end)

    getgenv().AURA2_UNLOAD = function()
        aura_on = false
        stop_aura()
    end
end

-- ============================================================
-- ============= CLIENT GHOST (2-й режим бэктрека) ============
-- Настоящая реализация. Клонирует персонажа локально,
-- отображает отставание от сервера, при необходимости
-- синхронизирует по ping.
-- ============================================================
do
    local ghost = {
        active = false,
        transparency = 50,
        color = Color3.fromRGB(255, 100, 100),
        no_texture = false,
        backtrack = true,
        backtrack_time = 0.15,
        clone = nil,
        pairs = {},
        history = {},
        last_char = nil,
    }
    getgenv().FH_GHOST = ghost

    local folder = _Workspace:FindFirstChild("FH_ClientVisuals")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "FH_ClientVisuals"
        folder.Parent = _Workspace
    end

    local function cleanup()
        if ghost.clone then pcall(function() ghost.clone:Destroy() end) end
        ghost.clone = nil
        ghost.pairs = {}
        ghost.history = {}
        ghost.last_char = nil
    end

    local function paint()
        if not ghost.clone then return end
        local tr = ghost.transparency / 100
        pcall(function()
            local bc = ghost.clone:FindFirstChildOfClass("BodyColors")
            if bc then bc:Destroy() end
        end)
        for _, pair in ipairs(ghost.pairs) do
            local g = pair.ghost
            pcall(function()
                if g:IsA("BasePart") then
                    g.Transparency = tr
                    g.Color = ghost.color
                    if ghost.no_texture then
                        g.Material = Enum.Material.SmoothPlastic
                        if g:IsA("MeshPart") then g.TextureID = "" end
                    end
                end
            end)
        end
    end

    local function build(char)
        cleanup()
        ghost.last_char = char
        char.Archivable = true
        local ok, clone = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not clone then return end
        ghost.clone = clone
        clone.Name = "FH_ClientGhost"
        clone.Parent = folder
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
        ghost.pairs = {}
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
                    table.insert(ghost.pairs, {real = d, ghost = g})
                end
            end
        end
        paint()
    end

    _RunService.RenderStepped:Connect(function()
        if not ghost.active then
            if ghost.clone then cleanup() end
            return
        end
        local char = _LP.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            if ghost.clone then cleanup() end
            return
        end
        if ghost.last_char ~= char then build(char) end
        if not ghost.clone or ghost.clone.Parent ~= folder then return end

        local snap = {t = tick(), parts = {}}
        for _, pair in ipairs(ghost.pairs) do
            snap.parts[pair.real] = pair.real.CFrame
        end
        table.insert(ghost.history, snap)
        local cutoff = tick() - 2
        while #ghost.history > 0 and ghost.history[1].t < cutoff do
            table.remove(ghost.history, 1)
        end

        local want = tick()
        if ghost.backtrack then
            local ping = 0
            pcall(function()
                ping = _Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            local off = math.clamp(ghost.backtrack_time or (ping / 1000), 0, 1)
            want = tick() - off
        end

        local chosen
        for i = #ghost.history, 1, -1 do
            if ghost.history[i].t <= want then
                chosen = ghost.history[i]
                break
            end
        end
        if not chosen and #ghost.history > 0 then chosen = ghost.history[1] end
        if chosen then
            for _, pair in ipairs(ghost.pairs) do
                local cf = chosen.parts[pair.real]
                if cf then pair.ghost.CFrame = cf end
            end
        end
    end)

    local gSec = Tabs.Visual:AddSection({Name = "Client Ghost (2-й режим бэктрека)"})

    addOpt(gSec, "AddToggle", "GhostOn", {
        Title = "Включить Client Ghost", Default = false,
    }, function(v)
        ghost.active = v
        if not v then cleanup() end
        Notify("FH", "Ghost " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)
    addOpt(gSec, "AddSlider", "GhostTransparency", {
        Title = "Прозрачность (%)", Min = 0, Max = 100, Default = 50, Rounding = 0,
    }, function(v) ghost.transparency = tonumber(v) or 50; paint() end)
    addOpt(gSec, "AddColorPicker", "GhostColor", {
        Title = "Цвет", Default = Color3.fromRGB(255, 100, 100),
    }, function(c) ghost.color = c; paint() end)
    addOpt(gSec, "AddToggle", "GhostNoTexture", {
        Title = "Убрать текстуры", Default = false,
    }, function(v) ghost.no_texture = v; paint() end)
    addOpt(gSec, "AddToggle", "GhostBacktrack", {
        Title = "Бэктрек (задержка)", Default = true,
    }, function(v) ghost.backtrack = v end)
    addOpt(gSec, "AddSlider", "GhostBacktrackTime", {
        Title = "Время бэктрека (сек)", Min = 0, Max = 0.8, Default = 0.15, Rounding = 2,
    }, function(v) ghost.backtrack_time = tonumber(v) or 0.15 end)

    getgenv().GHOST_UNLOAD = function()
        ghost.active = false
        cleanup()
    end
end

-- ============================================================
-- =================== SKYBOX MANAGER =========================
-- Новый дизайн: toggle + dropdown-меню (по типу kill aura).
-- Никаких custom ID. Одно небо за раз.
-- ============================================================
do
    local skyboxSec = Tabs.Effects:AddSection({Name = "Skybox Manager"})

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
    }
    local SKY_ASSETS = {
        ["Galaxy"]    = 15983996673,
        ["Anime"]     = 13107361022,
        ["Minecraft"] = 2758029221,
    }
    local SKY_ORDER = {
        "Jungle", "Blossom", "Red night", "Purple", "Foggy",
        "Galaxy", "Anime", "Minecraft",
    }

    local sky_on = false
    local sky_name = "Jungle"
    local created_sky, original_sky, original_sky_parent = nil, nil, nil

    local function detach_original()
        if original_sky then return end
        local existing = _Lighting:FindFirstChildOfClass("Sky")
        if existing and existing ~= created_sky then
            original_sky = existing
            original_sky_parent = existing.Parent
            pcall(function() existing.Parent = nil end)
        end
    end

    local function clear_created()
        if created_sky then
            pcall(function() created_sky:Destroy() end)
            created_sky = nil
        end
    end

    local function apply_textures(data)
        detach_original()
        clear_created()
        local sky = Instance.new("Sky")
        sky.Name = "FH_Sky"
        for k, v in pairs(data) do
            pcall(function() sky[k] = v end)
        end
        sky.Parent = _Lighting
        created_sky = sky
        _Lighting.ClockTime = 14
        _Lighting.Brightness = 0.5
    end

    local function apply_asset(id)
        task.spawn(function()
            local ok, objs = pcall(function()
                return game:GetObjects("rbxassetid://" .. id)
            end)
            if not ok or type(objs) ~= "table" then return end
            local found
            for _, o in ipairs(objs) do
                if o:IsA("Sky") then
                    found = o
                    break
                end
                local s = o:FindFirstChildWhichIsA("Sky", true)
                if s then
                    found = s
                    break
                end
            end
            if not found or not sky_on then return end
            detach_original()
            clear_created()
            found.Name = "FH_Sky"
            found.Parent = _Lighting
            created_sky = found
            _Lighting.ClockTime = 14
            _Lighting.Brightness = 0.5
        end)
    end

    local function apply_sky(name)
        if SKY_PRESETS[name] then
            apply_textures(SKY_PRESETS[name])
        elseif SKY_ASSETS[name] then
            apply_asset(SKY_ASSETS[name])
        end
    end

    local function restore_sky()
        clear_created()
        if original_sky then
            pcall(function() original_sky.Parent = original_sky_parent or _Lighting end)
            original_sky = nil
            original_sky_parent = nil
        end
    end

    addOpt(skyboxSec, "AddToggle", "SkyboxOn", {
        Title = "Включить скайбокс", Default = false,
    }, function(v)
        sky_on = v
        if v then
            apply_sky(sky_name)
            Notify("FH", "Скайбокс: " .. sky_name, 2)
        else
            restore_sky()
            Notify("FH", "Скайбокс выключен", 1.5)
        end
    end)

    addOpt(skyboxSec, "AddDropdown", "SkyboxPreset", {
        Title = "Небо", Values = SKY_ORDER, Default = "Jungle",
    }, function(v)
        sky_name = tostring(v)
        if sky_on then apply_sky(sky_name) end
    end)

    getgenv().SKYBOX_UNLOAD = function()
        sky_on = false
        restore_sky()
    end
end

-- ============================================================
-- =============== ДОП. ЭФФЕКТЫ: Beam / Tracer ================
-- ============================================================
do
    local tracerSec = Tabs.Effects:AddSection({Name = "Трассер пули"})
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
        pt.Parent = _Workspace
        _Debris:AddItem(pt, life)
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
                _TweenService:Create(beam, TweenInfo.new(0.2), {Width0 = 0, Width1 = 0}):Play()
            end
        end)
    end

    local tracerConn
    local function connectTracer()
        if tracerConn then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices")
                :WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if not ok or not remote then return end
        tracerConn = remote.OnClientEvent:Connect(function(gun, sv, ev)
            if not tracerOn then return end
            local c = _LP.Character
            if not c then return end
            if not (typeof(gun) == "Instance" and gun:IsDescendantOf(c)) then return end
            if tracerTrackBullet then createTracer(sv, ev) end
        end)
    end

    addOpt(tracerSec, "AddToggle", "TracerOn", {Title = "Включить трассер", Default = false}, function(v)
        tracerOn = v
        if v then connectTracer() end
    end)
    addOpt(tracerSec, "AddToggle", "TracerTrackBullet", {Title = "Отслеживание пуль", Default = true}, function(v)
        tracerTrackBullet = v
    end)
    addOpt(tracerSec, "AddColorPicker", "TracerCol", {Title = "Цвет", Default = Color3.fromRGB(133, 220, 255)}, function(c)
        tracerCol = c
    end)
    addOpt(tracerSec, "AddSlider", "TracerDur", {Title = "Длительность", Min = 0.1, Max = 5, Default = 1, Rounding = 1}, function(v)
        tracerDur = tonumber(v) or 1
    end)

    getgenv().TRACER_UNLOAD = function()
        tracerOn = false
        if tracerConn then pcall(function() tracerConn:Disconnect() end); tracerConn = nil end
    end
end

-- ============================================================
-- ============== ДОП. ЭФФЕКТЫ: Дополнительные ауры ===========
-- ============================================================
do
    local sec = Tabs.Effects:AddSection({Name = "Extra Auras (кнопки)"})
    local activeAura, activeAuraName = nil, nil

    local function clearAura()
        if activeAura then
            for _, obj in ipairs(activeAura) do
                if obj and obj.Parent then pcall(function() obj:Destroy() end) end
            end
        end
        activeAura = nil
        activeAuraName = nil
    end

    local function applyAura(assetId, name)
        if activeAuraName == name then
            clearAura()
            Notify("FH", name .. " выключена", 1.5)
            return
        end
        clearAura()
        local ok, objs = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(assetId))
        end)
        if not ok or type(objs) ~= "table" or #objs == 0 then
            Notify("FH", "Не удалось загрузить ауру: " .. name, 3)
            return
        end
        local model = objs[1]
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
                d:Destroy()
            elseif d:IsA("ParticleEmitter") then
                d.LightEmission = 1
                d.Rate = math.clamp(d.Rate * 0.35, 1, 40)
            elseif d:IsA("Beam") then
                d.LightEmission = 1
            end
        end
        local char = _LP.Character
        if not char then Notify("FH", "Персонаж не загружен", 2) return end
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if not torso then Notify("FH", "Нет торса", 2) return end

        local tracked = {}
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = false
                d.CanCollide = false
            elseif d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
                d:Destroy()
            end
        end
        local auraPart = model:FindFirstChild("Aura")
        if auraPart and auraPart:IsA("BasePart") then
            auraPart.Parent = char
            auraPart.CFrame = torso.CFrame * CFrame.new(0, 0.5, 0)
            local w = Instance.new("WeldConstraint")
            w.Part0 = torso
            w.Part1 = auraPart
            w.Parent = auraPart
            table.insert(tracked, w)
            table.insert(tracked, auraPart)
            for _, ch in ipairs(auraPart:GetChildren()) do
                if ch:IsA("ParticleEmitter") or ch:IsA("Beam") or ch:IsA("Highlight") then
                    local cl = ch:Clone()
                    cl.Parent = torso
                    table.insert(tracked, cl)
                end
            end
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Beam") then
                local cl = d:Clone()
                cl.Parent = torso
                table.insert(tracked, cl)
            end
        end
        model:Destroy()
        activeAura = tracked
        activeAuraName = name
        Notify("FH", name .. " включена", 1.5)
    end

    local AURAS = {
        {"Midnight Blues", "12002206611"},
        {"Rainbow Effect", "8509695714"},
        {"Red Shield",     "14598330167"},
        {"Crimson King",   "11955208820"},
        {"Daemon of Cards","10373359918"},
        {"Angel Wings",    "97658130917593"},
        {"Starlight",      "134645216613107"},
        {"Heavenly",       "139300897520961"},
    }
    for _, a in ipairs(AURAS) do
        sec:AddButton({Title = a[1], Callback = function() applyAura(a[2], a[1]) end})
    end
    sec:AddButton({Title = "Очистить ауру", Callback = function()
        clearAura()
        Notify("FH", "Аура очищена", 1.5)
    end})

    getgenv().EXTRA_AURAS_UNLOAD = clearAura
end

-- ============================================================
-- ==================== TRADE HELPER ==========================
-- (адаптированный SHITARO-вариант)
-- ============================================================
do
    getgenv().TH = getgenv().TH or {}
    local th = getgenv().TH
    th.TradeValues = th.TradeValues or {}
    th.On = false
    th.LoopThread = nil
    th.Loaded = false

    local function normalizeKey(str)
        if not str then return "" end
        return str:lower():gsub("[%s%_'%.-]", "")
    end

    local function addValue(name, value)
        if not name or not value then return end
        local clean = name:gsub("<[^>]+>", ""):match("^%s*(.-)%s*$")
        if not clean or #clean <= 1 then return end
        th.TradeValues[clean] = value
        th.TradeValues[normalizeKey(clean)] = value
    end

    local shhttp = rawget(getfenv(), "request")
        or (syn and syn.request)
        or (http and http.request)
        or (getgenv and getgenv().request)

    local function fetchWithProxy(url)
        local list = {
            "https://api.codetabs.com/v1/proxy?quest=" .. url,
            "https://corsproxy.io/?" .. url,
            "https://api.allorigins.win/raw?url=" .. url,
            url,
        }
        for _, u in ipairs(list) do
            local body = nil
            local done = false
            task.spawn(function()
                local ok, r = pcall(function() return game:HttpGet(u, true) end)
                if ok and type(r) == "string" and #r > 300 then body = r end
                done = true
            end)
            local t0 = tick()
            while not done and tick() - t0 < 3 do task.wait(0.1) end
            if body then return body end
        end
        return nil
    end

    local function parseMM2Values(html)
        html = html:gsub("[\r\n]", " ")
        local n = 0
        for block in html:gmatch("<div%s+class=stackable>(.-)</div>") do
            local valStr = block:match("Value:%s*([%d,]+)")
            if valStr then
                local num = tonumber((valStr:gsub(",", "")))
                local name = block:match("<b>([^<]+)</b>")
                    or block:match('<span%s+class="[^"]+">([^<]+)</span>')
                    or block:match("<span%s+class=[^>]+>([^<]+)</span>")
                    or block:match("([%w%s%_'%.-]+)%s*<br>%s*Value:")
                if name and num then
                    addValue(name, num)
                    n = n + 1
                end
            end
        end
        return n
    end

    local function parseMM2Checker(html)
        html = html:gsub("[\r\n]", " ")
        local n = 0
        for name, valStr in html:gmatch('<div%s+class="box"%s+id="([^"]+)".-class="itemvalue">%s*([%d,]+)%s*</span>') do
            local num = tonumber((valStr:gsub(",", "")))
            if name and num then
                addValue(name, num)
                n = n + 1
            end
        end
        return n
    end

    local function fmtValue(v)
        if not v or v == 0 then return "0" end
        if v >= 1000000 then return string.format("%.1fM", v / 1000000) end
        if v >= 1000 then return string.format("%.1fK", v / 1000) end
        return tostring(v)
    end

    local function valueColor(v)
        if v >= 100000 then return Color3.fromRGB(255, 50, 50) end
        if v >= 10000 then return Color3.fromRGB(255, 100, 50) end
        if v >= 1000 then return Color3.fromRGB(255, 215, 0) end
        if v >= 100 then return Color3.fromRGB(0, 200, 100) end
        if v >= 10 then return Color3.fromRGB(100, 200, 255) end
        return Color3.fromRGB(180, 180, 180)
    end

    local function lookupValue(name)
        if not name then return 0 end
        if th.TradeValues[name] then return th.TradeValues[name] end
        return th.TradeValues[normalizeKey(name)] or 0
    end

    local function attachValueLabel(container, itemName)
        if not container then return end
        local old = container:FindFirstChild("FH_ValueLabel")
        if old then old:Destroy() end
        local val = lookupValue(itemName)
        if val == 0 then return end
        local lbl = Instance.new("TextLabel")
        lbl.Name = "FH_ValueLabel"
        lbl.Size = UDim2.new(0.96, 0, 0, 16)
        lbl.Position = UDim2.new(0.02, 0, 1, -18)
        lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        lbl.BackgroundTransparency = 0.25
        lbl.Text = "$" .. fmtValue(val)
        lbl.TextColor3 = valueColor(val)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBold
        lbl.ZIndex = 1000
        lbl.Parent = container
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 4)
    end

    local function processCard(obj)
        if not obj or not obj:IsA("GuiObject") then return end
        local container = obj:FindFirstChild("Container") or obj
        local name
        local nameFrame = obj:FindFirstChild("ItemName")
        if nameFrame then
            local lbl = nameFrame:FindFirstChild("Label")
            if lbl and lbl.Text ~= "" and lbl.Text ~= "Loading..." then
                name = lbl.Text
            end
        end
        if name then attachValueLabel(container, name) end
    end

    local function scanTradeGui()
        local pg = _LP:FindFirstChild("PlayerGui")
        if not pg then return end
        local main = pg:FindFirstChild("MainGUI")
        if main then
            for _, d in ipairs(main:GetDescendants()) do
                if d:IsA("GuiObject") and d:FindFirstChild("ItemName") and d:FindFirstChild("Container") then
                    processCard(d)
                end
            end
        end
    end

    local function loadValues()
        if th.Loaded then return end
        th.Loaded = true
        local sources = {
            {url = "https://mm2values.com/?p=godly",   type = "values"},
            {url = "https://mm2values.com/?p=chroma",  type = "values"},
            {url = "https://mm2values.com/?p=ancient", type = "values"},
            {url = "https://mm2checker.com/godlies.html",     type = "checker"},
            {url = "https://mm2checker.com/ancients.html",    type = "checker"},
            {url = "https://mm2checker.com/legendaries.html", type = "checker"},
        }
        task.spawn(function()
            local loaded = 0
            for _, src in ipairs(sources) do
                task.spawn(function()
                    local html = fetchWithProxy(src.url)
                    if html then
                        if src.type == "values" then
                            parseMM2Values(html)
                        else
                            parseMM2Checker(html)
                        end
                    end
                    loaded = loaded + 1
                    if loaded == #sources then
                        Notify("Trade Helper", "Значения загружены", 2)
                    end
                end)
            end
        end)
    end

    local function loop()
        while th.On do
            task.wait(0.5)
            pcall(scanTradeGui)
        end
        th.LoopThread = nil
    end

    function th.Start()
        if not th.On then
            th.On = true
            loadValues()
            th.LoopThread = task.spawn(loop)
        end
    end
    function th.Stop()
        th.On = false
        if th.LoopThread then
            pcall(task.cancel, th.LoopThread)
            th.LoopThread = nil
        end
    end

    local thSec = Tabs.Visual:AddSection({Name = "Trade Helper"})
    addOpt(thSec, "AddToggle", "THOn", {
        Title = "Trade Helper (MM2 Values)", Default = false,
    }, function(v)
        if v then
            th.Start()
            Notify("FH", "Trade Helper ВКЛ", 1.5)
        else
            th.Stop()
            Notify("FH", "Trade Helper ВЫКЛ", 1.5)
        end
    end)
    thSec:AddButton({Title = "Обновить значения", Callback = function()
        th.Loaded = false
        th.TradeValues = {}
        loadValues()
        Notify("FH", "Обновляю значения...", 3)
    end})

    getgenv().TH_UNLOAD = function()
        th.On = false
        if th.LoopThread then pcall(task.cancel, th.LoopThread) end
    end
end

-- ============================================================
-- ==================== PLAYER LIST ============================
-- Полноценная панель с аватарками и поиском.
-- ============================================================
do
    local targetSec = Tabs.Troll:AddSection({Name = "Player List"})

    local panelGui, frame, scroll, search

    local function createPanel()
        if panelGui then
            pcall(function() panelGui:Destroy() end)
        end
        panelGui = Instance.new("ScreenGui")
        panelGui.Name = "FH_PlayerListPanel"
        panelGui.ResetOnSpawn = false
        panelGui.IgnoreGuiInset = true
        panelGui.DisplayOrder = 450
        panelGui.Enabled = false
        pcall(function() panelGui.Parent = (gethui and gethui()) or _CoreGui end)
        if not panelGui.Parent then panelGui.Parent = _CoreGui end

        frame = Instance.new("Frame")
        frame.Name = "Panel"
        frame.Size = UDim2.fromOffset(440, 380)
        frame.Position = UDim2.new(0.5, -220, 0.5, -190)
        frame.BackgroundColor3 = Color3.fromRGB(16, 12, 9)
        frame.BackgroundTransparency = 0.08
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

        local close = Instance.new("TextButton")
        close.Size = UDim2.fromOffset(22, 22)
        close.Position = UDim2.new(1, -30, 0, 7)
        close.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
        close.BorderSizePixel = 0
        close.Text = "X"
        close.Font = Enum.Font.GothamBold
        close.TextColor3 = Color3.fromRGB(255, 200, 200)
        close.TextSize = 12
        close.Parent = frame
        Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)
        close.MouseButton1Click:Connect(function() panelGui.Enabled = false end)

        search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -24, 0, 28)
        search.Position = UDim2.new(0, 12, 0, 36)
        search.BackgroundColor3 = Color3.fromRGB(15, 13, 11)
        search.BackgroundTransparency = 0.15
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
        local sp = Instance.new("UIPadding", search)
        sp.PaddingLeft = UDim.new(0, 8)

        scroll = Instance.new("ScrollingFrame")
        scroll.Name = "Cards"
        scroll.Position = UDim2.new(0, 12, 0, 72)
        scroll.Size = UDim2.new(1, -24, 1, -84)
        scroll.BackgroundColor3 = Color3.fromRGB(10, 9, 8)
        scroll.BackgroundTransparency = 0.4
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
        local pad = Instance.new("UIPadding", scroll)
        pad.PaddingTop = UDim.new(0, 7)
        pad.PaddingLeft = UDim.new(0, 7)
        pad.PaddingRight = UDim.new(0, 7)
        pad.PaddingBottom = UDim.new(0, 7)
    end

    local selectedPlayer

    local function refresh()
        if not scroll then return end
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local query = string.lower(search.Text or "")
        local order = 0
        for _, pl in ipairs(_Players:GetPlayers()) do
            if pl ~= _LP then
                local dn = string.lower(pl.DisplayName or "")
                local nm = string.lower(pl.Name or "")
                if query == "" or dn:find(query, 1, true) or nm:find(query, 1, true) then
                    order = order + 1
                    local btn = Instance.new("TextButton")
                    btn.Name = "P_" .. pl.Name
                    btn.LayoutOrder = order
                    btn.AutoButtonColor = false
                    btn.BackgroundColor3 = Color3.fromRGB(15, 13, 11)
                    btn.BackgroundTransparency = 0.18
                    btn.BorderSizePixel = 0
                    btn.Text = ""
                    btn.Parent = scroll
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
                    local st = Instance.new("UIStroke", btn)
                    st.Color = Color3.fromRGB(138, 92, 246)
                    st.Thickness = 1
                    st.Transparency = 0.75
                    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                    local img = Instance.new("ImageLabel")
                    img.Size = UDim2.fromOffset(42, 42)
                    img.Position = UDim2.new(0, 7, 0.5, 0)
                    img.AnchorPoint = Vector2.new(0, 0.5)
                    img.BackgroundColor3 = Color3.fromRGB(10, 9, 8)
                    img.BackgroundTransparency = 0.15
                    img.BorderSizePixel = 0
                    img.ScaleType = Enum.ScaleType.Crop
                    img.Parent = btn
                    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 6)

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, -57, 1, -6)
                    lbl.Position = UDim2.new(0, 55, 0, 3)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.Gotham
                    lbl.Text = pl.DisplayName ~= pl.Name
                        and pl.DisplayName or pl.Name
                    lbl.TextColor3 = Color3.fromRGB(245, 242, 238)
                    lbl.TextSize = 12
                    lbl.TextWrapped = true
                    lbl.TextTruncate = Enum.TextTruncate.AtEnd
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = btn

                    task.spawn(function()
                        local ok, av = pcall(function()
                            return _Players:GetUserThumbnailAsync(
                                pl.UserId,
                                Enum.ThumbnailType.HeadShot,
                                Enum.ThumbnailSize.Size100x100)
                        end)
                        if ok and av and img.Parent then img.Image = av end
                    end)

                    btn.Activated:Connect(function()
                        selectedPlayer = pl
                        getgenv().FH_SelectedPlayer = pl
                        Notify("FH", "Выбран: " .. pl.Name, 1.2)
                    end)
                end
            end
        end
    end

    createPanel()
    search:GetPropertyChangedSignal("Text"):Connect(refresh)
    _Players.PlayerAdded:Connect(refresh)
    _Players.PlayerRemoving:Connect(function(pl)
        if selectedPlayer == pl then
            selectedPlayer = nil
            getgenv().FH_SelectedPlayer = nil
        end
        refresh()
    end)
    refresh()

    addOpt(targetSec, "AddToggle", "FHPlayerPanelOn", {
        Title = "Открыть Player List", Default = false,
    }, function(v)
        if panelGui then
            panelGui.Enabled = v
            if v then refresh() end
        end
    end)

    targetSec:AddButton({Title = "ТП к выбранному", Callback = function()
        local pl = selectedPlayer
        if not pl or not pl.Character then
            Notify("FH", "Игрок не выбран или мёртв", 2)
            return
        end
        local hrp = _getHRP()
        if not hrp then return end
        local t = pl.Character:FindFirstChild("HumanoidRootPart")
        if t then hrp.CFrame = t.CFrame + Vector3.new(0, 5, 0) end
    end})

    targetSec:AddButton({Title = "ТП игрока к себе", Callback = function()
        local pl = selectedPlayer
        if not pl or not pl.Character then
            Notify("FH", "Игрок не выбран", 2)
            return
        end
        local hrp = _getHRP()
        if not hrp then return end
        local t = pl.Character:FindFirstChild("HumanoidRootPart")
        if t then t.CFrame = hrp.CFrame + Vector3.new(0, 3, 0) end
    end})

    getgenv().PLAYERLIST_UNLOAD = function()
        if panelGui then pcall(function() panelGui:Destroy() end); panelGui = nil end
    end
end

-- ============================================================
-- ===================== VOTE DUPER ===========================
-- ============================================================
do
    local voteSec = Tabs.Troll:AddSection({Name = "Vote Duper"})
    local voteDupEnabled = false
    local DELAY_ON_PAD = 0.38
    local dupeThread, dupeCounter = nil, 0
    local selectedVotePad, padRefs = nil, {}

    local function safeText(obj)
        if not obj then return "" end
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            return tostring(obj.Text or "")
        end
        return ""
    end

    local function getVoteMapName(pad)
        if not pad then return "" end
        local v = pad:FindFirstChild("VoteInfoGui", true)
        if v then v = v:FindFirstChild("MapName", true) end
        return safeText(v)
    end

    local function collectPads()
        local lobby = _Workspace:FindFirstChild("RegularLobby")
            or _Workspace:FindFirstChild("SummerLobby")
            or _Workspace:FindFirstChild("Lobby")
        if not lobby then return {} end
        local out = {}
        for _, nm in ipairs({"VotePad1", "VotePad2", "VotePad3"}) do
            local obj = lobby:FindFirstChild(nm)
            if obj and obj:FindFirstChild("Pad", true) then
                table.insert(out, obj)
            end
        end
        return out
    end

    local function getVoteGuiVisible()
        if not selectedVotePad then return false end
        local v = selectedVotePad:FindFirstChild("VoteInfoGui", true)
        if not v then return false end
        local ok, res = pcall(function()
            if v:IsA("LayerCollector") then return v.Enabled == true end
            if v:IsA("GuiObject") then return v.Visible == true end
            return v.Enabled == true
        end)
        return ok and res
    end

    local function getVotePadCFrame()
        if not selectedVotePad then return nil end
        local pad = selectedVotePad:FindFirstChild("Pad", true)
        if pad and pad:IsA("BasePart") then return pad.CFrame end
    end

    local function dupeLoop()
        local myToken = dupeCounter
        while voteDupEnabled and dupeCounter == myToken do
            if not getVoteGuiVisible() then
                task.wait(0.3)
            else
                local char = _LP.Character
                local tries = 0
                while not char and voteDupEnabled and dupeCounter == myToken and tries < 50 do
                    task.wait(0.1); char = _LP.Character; tries = tries + 1
                end
                if not char then break end
                local hrp = char:WaitForChild("HumanoidRootPart", 5)
                local hum = char:WaitForChild("Humanoid", 5)
                if hrp and hum and hum.Health > 0 then
                    local cf = getVotePadCFrame()
                    if cf then
                        pcall(function() char:PivotTo(cf * CFrame.new(0, 1.5, 0)) end)
                        task.wait(DELAY_ON_PAD)
                        if voteDupEnabled and dupeCounter == myToken and getVoteGuiVisible() and hum.Health > 0 then
                            hum.Health = 0
                            char:BreakJoints()
                            local tries2 = 0
                            while _LP.Character and voteDupEnabled and dupeCounter == myToken and tries2 < 50 do
                                task.wait(0.1); tries2 = tries2 + 1
                            end
                            task.wait(0.05)
                        end
                    end
                else
                    task.wait(0.2)
                end
            end
        end
        if dupeCounter == myToken then
            dupeThread = nil
            if voteDupEnabled then
                voteDupEnabled = false
                pcall(function()
                    local o = Options.THVoteDuper
                    if o then o:SetValue(false) end
                end)
            end
        end
    end

    local function startDupe()
        if dupeThread then return end
        dupeCounter = dupeCounter + 1
        dupeThread = task.spawn(dupeLoop)
    end

    local function stopDupe()
        voteDupEnabled = false
        dupeCounter = dupeCounter + 1
        if dupeThread then
            pcall(task.cancel, dupeThread)
            dupeThread = nil
        end
    end

    addOpt(voteSec, "AddToggle", "THVoteDuper", {
        Title = "Vote Duper", Default = false,
    }, function(v)
        voteDupEnabled = v
        if v then
            if not selectedVotePad then
                local pads = collectPads()
                if #pads > 0 then selectedVotePad = pads[1] end
            end
            startDupe()
            Notify("FH", "Vote Duper ВКЛ", 1.5)
        else
            stopDupe()
            Notify("FH", "Vote Duper ВЫКЛ", 1.5)
        end
    end)

    addOpt(voteSec, "AddSlider", "THDupeDelay", {
        Title = "Задержка на пэде", Min = 0.1, Max = 1.5, Default = 0.38, Rounding = 2,
    }, function(v) DELAY_ON_PAD = tonumber(v) or 0.38 end)

    getgenv().VOTEDUPER_UNLOAD = stopDupe
end

-- ============================================================
-- ================ ADVANCED AUTOFARM (Underground) ===========
-- ============================================================
do
    local advSec = Tabs.Farm:AddSection({Name = "Advanced AutoFarm"})

    local cfg = {
        Mode = "Underground",
        TweenSpeed = 25,
        AutoReset = false,
        AvoidMurder = false,
        UndergroundOffset = 4,
        MaxDistance = 600,
        Active = false,
    }
    local state = {
        farming = false, flying = false, target = nil,
        ignored = {}, tween = nil,
    }

    local function getChar()
        local c = _LP.Character
        return c, c and (c:FindFirstChild("Torso")
            or c:FindFirstChild("LowerTorso")
            or c:FindFirstChild("HumanoidRootPart"))
    end

    local function findCoinContainer()
        for _, d in ipairs(_Workspace:GetDescendants()) do
            if d.Name == "CoinContainer" then return d end
        end
        return nil
    end

    local function findNearestCoin(pos)
        local cc = findCoinContainer()
        if not cc then return nil end
        local best, bd = nil, math.huge
        for _, c in ipairs(cc:GetChildren()) do
            if c.Name == "Coin_Server" and c:IsA("BasePart") and not state.ignored[c] then
                local d = (pos - c.Position).Magnitude
                if d < bd and d <= cfg.MaxDistance then bd = d; best = c end
            end
        end
        return best
    end

    local function checkBags()
        local pg = _LP:FindFirstChild("PlayerGui")
        if not pg then return false end
        local main = pg:FindFirstChild("MainGUI")
        local lobby = main and main:FindFirstChild("Lobby")
        if lobby then
            local dock = lobby:FindFirstChild("Dock")
            if dock then
                local cb = dock:FindFirstChild("CoinBags")
                if cb then
                    local fn = cb:FindFirstChild("FullBagNotification")
                    if fn and fn.Visible then return true end
                end
            end
        end
        return false
    end

    local function murdererNear(pos)
        if not cfg.AvoidMurder then return false end
        for _, pl in ipairs(_Players:GetPlayers()) do
            if pl ~= _LP and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local bp = pl:FindFirstChild("Backpack")
                local hasKnife = pl.Character:FindFirstChild("Knife")
                    or (bp and bp:FindFirstChild("Knife"))
                if hrp and hasKnife and (hrp.Position - pos).Magnitude <= 10 then
                    return true
                end
            end
        end
        return false
    end

    local function stopFarming()
        state.farming = false
        state.flying = false
        state.target = nil
        if state.tween then
            pcall(function() state.tween:Cancel() end)
            state.tween = nil
        end
        local char = _LP.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local bv = hrp:FindFirstChild("FH_FarmBV")
                if bv then bv:Destroy() end
                local bg = hrp:FindFirstChild("FH_FarmBG")
                if bg then bg:Destroy() end
                hrp.Anchored = false
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false end
        end
    end

    local function ensureBV()
        local c = _LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not hrp:FindFirstChild("FH_FarmBV") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "FH_FarmBV"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.zero
            bv.Parent = hrp
        end
        if not hrp:FindFirstChild("FH_FarmBG") then
            local bg = Instance.new("BodyGyro")
            bg.Name = "FH_FarmBG"
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 50000
            bg.Parent = hrp
        end
    end

    local function disableCollide()
        local c = _LP.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") then d.CanCollide = false end
        end
    end

    local function travelTo(dest, target)
        local c = _LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local dist = (dest - hrp.Position).Magnitude
        local dur = dist / math.max(cfg.TweenSpeed, 1)
        state.tween = _TweenService:Create(hrp,
            TweenInfo.new(dur, Enum.EasingStyle.Linear),
            {CFrame = CFrame.new(dest)})
        local done = false
        local hb = _RunService.Heartbeat:Connect(function()
            if not state.farming or not target or not target.Parent then
                state.tween:Cancel()
                hb:Disconnect()
            end
            if (hrp.Position - dest).Magnitude <= 1.5 then
                done = true
                state.tween:Cancel()
                hb:Disconnect()
            end
        end)
        state.tween:Play()
        local t0 = tick()
        while not done and state.farming and tick() - t0 < 30 do
            task.wait(0.1)
            if target and target.Parent then
                pcall(function()
                    firetouchinterest(hrp, target, 0)
                    firetouchinterest(hrp, target, 1)
                end)
            end
        end
        return done
    end

    local function loop()
        state.farming = true
        while state.farming do
            task.wait()
            local char, part = getChar()
            if not char then
                task.wait(1)
            else
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not part or not hum or hum.Health <= 0 then
                    stopFarming()
                    break
                elseif murdererNear(part.Position) then
                    task.wait(1)
                elseif checkBags() then
                    stopFarming()
                    if cfg.AutoReset then
                        task.wait(0.3)
                        pcall(function() hum.Health = 0 end)
                    end
                    break
                else
                    local coin = findNearestCoin(part.Position)
                    if not coin then
                        task.wait(0.5)
                    else
                        state.target = coin
                        if cfg.Mode == "Underground" then
                            disableCollide()
                            ensureBV()
                            local dest = coin.Position - Vector3.new(0, cfg.UndergroundOffset, 0)
                            if travelTo(dest, coin) then
                                state.ignored[coin] = true
                                task.delay(5, function() state.ignored[coin] = nil end)
                            end
                        elseif cfg.Mode == "Sit" then
                            local hum2 = char:FindFirstChildOfClass("Humanoid")
                            if hum2 then hum2.Sit = true end
                            local hrp = char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local dest = coin.Position + Vector3.new(0, 2, 0)
                                hrp.CFrame = CFrame.new(dest)
                                task.wait(0.3)
                                pcall(function()
                                    firetouchinterest(hrp, coin, 0)
                                    task.wait(0.05)
                                    firetouchinterest(hrp, coin, 1)
                                end)
                            end
                            if hum2 then hum2.Sit = false end
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
        state.farming = false
    end

    local function start()
        if state.farming then return end
        task.spawn(loop)
    end

    addOpt(advSec, "AddToggle", "FHAdvFarmOn", {
        Title = "Включить Advanced Farm", Default = false,
    }, function(v)
        if v then
            start()
            Notify("FH", "Advanced Farm ВКЛ", 1.5)
        else
            stopFarming()
            Notify("FH", "Advanced Farm ВЫКЛ", 1.5)
        end
    end)

    addOpt(advSec, "AddDropdown", "FHAdvFarmMode", {
        Title = "Режим", Values = {"Underground", "Sit"}, Default = "Underground",
    }, function(v) cfg.Mode = tostring(v) end)
    addOpt(advSec, "AddSlider", "FHAdvFarmSpeed", {
        Title = "Скорость перемещения", Min = 5, Max = 100, Default = 25, Rounding = 0,
    }, function(v) cfg.TweenSpeed = tonumber(v) or 25 end)
    addOpt(advSec, "AddSlider", "FHAdvFarmOffset", {
        Title = "Смещение под землёй", Min = 0, Max = 20, Default = 4, Rounding = 0,
    }, function(v) cfg.UndergroundOffset = tonumber(v) or 4 end)
    addOpt(advSec, "AddSlider", "FHAdvFarmDist", {
        Title = "Макс. дистанция монет", Min = 50, Max = 2000, Default = 600, Rounding = 0,
    }, function(v) cfg.MaxDistance = tonumber(v) or 600 end)
    addOpt(advSec, "AddToggle", "FHAdvFarmAutoReset", {
        Title = "Авто-ресет при полных мешках", Default = false,
    }, function(v) cfg.AutoReset = v end)
    addOpt(advSec, "AddToggle", "FHAdvFarmAvoid", {
        Title = "Избегать маньяка", Default = false,
    }, function(v) cfg.AvoidMurder = v end)

    getgenv().ADVFARM_UNLOAD = stopFarming
end

-- ============================================================
-- ============ WATER PROTECTION (Utility) ====================
-- ============================================================
do
    local waterSec = Tabs.Utility:AddSection({Name = "Water Protection"})
    local offDamageWater = false
    local modifiedWaterParts = {}

    local function isWater(instance)
        if not instance then return false end
        local n = instance.Name:lower()
        if n:find("water") or n:find("river") or n:find("ocean") then return true end
        if instance:FindFirstChild("Splash") or instance:FindFirstChild("HitWater") then
            return true
        end
        return false
    end

    local function neutralize(instance)
        if not instance or not instance:IsA("BasePart") then return end
        if modifiedWaterParts[instance] == nil then
            modifiedWaterParts[instance] = instance.CanTouch
        end
        instance.CanTouch = false
    end

    local function applyAll()
        for _, d in ipairs(_Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local p = d
                while p and p ~= _Workspace do
                    if isWater(p) then neutralize(d); break end
                    p = p.Parent
                end
            end
        end
    end

    local function restoreAll()
        for part, ct in pairs(modifiedWaterParts) do
            if part and part.Parent then
                pcall(function() part.CanTouch = ct end)
            end
        end
        table.clear(modifiedWaterParts)
    end

    _Workspace.DescendantAdded:Connect(function(d)
        if offDamageWater and d:IsA("BasePart") then
            task.spawn(function()
                task.wait()
                local p = d
                while p and p ~= _Workspace do
                    if isWater(p) then neutralize(d); break end
                    p = p.Parent
                end
            end)
        end
    end)

    addOpt(waterSec, "AddToggle", "WaterProtOn", {
        Title = "Off Damage Water", Default = false,
    }, function(v)
        offDamageWater = v
        if v then applyAll() else restoreAll() end
    end)

    getgenv().WATER_UNLOAD = function()
        offDamageWater = false
        restoreAll()
    end
end

-- ============================================================
-- ============== FADE DISABLER (Utility) =====================
-- ============================================================
do
    local fadeSec = Tabs.Utility:AddSection({Name = "Fade Disabler"})
    local fadeNames = {CameraFade = true, Fade = true, SpawnFade = true, DeathFade = true}
    local tracked, fade_conn = {}, nil
    local fade_on = false

    local function handle(obj)
        if not obj or not obj:IsDescendantOf(game) then return end
        if fadeNames[obj.Name] then
            if not tracked[obj] then tracked[obj] = obj.Parent end
            pcall(function() obj.Visible = false end)
        end
    end

    local function apply()
        local pg = _LP:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, d in ipairs(pg:GetDescendants()) do
            if fadeNames[d.Name] then handle(d) end
        end
        if not fade_conn then
            fade_conn = pg.DescendantAdded:Connect(function(d)
                if fade_on and fadeNames[d.Name] then handle(d) end
            end)
        end
    end

    local function restore()
        if fade_conn then fade_conn:Disconnect(); fade_conn = nil end
        for obj, _ in pairs(tracked) do
            if obj and obj.Parent then
                pcall(function() obj.Visible = true end)
            end
        end
        table.clear(tracked)
    end

    addOpt(fadeSec, "AddToggle", "FadeDisablerOn", {
        Title = "Убрать чёрный экран", Default = false,
    }, function(v)
        fade_on = v
        if v then apply() else restore() end
    end)

    getgenv().FADE_UNLOAD = function()
        fade_on = false
        restore()
    end
end

-- ============================================================
-- ==================== ANTI-COIN (Utility) ===================
-- ============================================================
do
    local coinSec = Tabs.Utility:AddSection({Name = "Anti-Coin"})
    local coin_on = false
    local saved = {}

    local function hideCoin(part)
        if not saved[part] then
            saved[part] = {
                CanTouch = part.CanTouch,
                CanCollide = part.CanCollide,
                Transparency = part.Transparency,
            }
        end
        part.CanTouch = false
        part.CanCollide = false
        part.Transparency = 1
    end

    local function scan()
        for _, d in ipairs(_Workspace:GetDescendants()) do
            if d:IsA("Model") and d.Name:lower():find("coin") then
                for _, p in ipairs(d:GetDescendants()) do
                    if p:IsA("BasePart") then hideCoin(p) end
                end
            end
        end
    end

    local function restore()
        for part, o in pairs(saved) do
            if part and part.Parent then
                pcall(function()
                    part.CanTouch = o.CanTouch
                    part.CanCollide = o.CanCollide
                    part.Transparency = o.Transparency
                end)
            end
        end
        table.clear(saved)
    end

    addOpt(coinSec, "AddToggle", "AntiCoinOn", {
        Title = "Скрыть монеты", Default = false,
    }, function(v)
        coin_on = v
        if v then
            task.spawn(function()
                while coin_on do
                    pcall(scan)
                    task.wait(0.5)
                end
            end)
        else
            restore()
        end
    end)

    getgenv().ANTICOIN_UNLOAD = function()
        coin_on = false
        restore()
    end
end

-- ============================================================
-- ==================== JUMP CIRCLE ===========================
-- ============================================================
do
    local jcSec = Tabs.Visual:AddSection({Name = "Jump Circle"})
    local jc = {enabled = false, color = Color3.fromRGB(255, 105, 180)}
    local jc_conn

    local function spawnCircle(pos)
        if not jc.enabled then return end
        local part = Instance.new("Part")
        part.Name = "FH_JumpCircle"
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Size = Vector3.new(0.5, 0.05, 0.5)
        part.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0))
        part.Transparency = 1
        part.Parent = _Workspace
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.AlwaysOnTop = true
        sg.LightInfluence = 0
        sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 100
        sg.Parent = part
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = "rbxassetid://133238425773760"
        img.ImageColor3 = jc.color
        img.ImageTransparency = 0
        img.Parent = sg
        local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        _TweenService:Create(part, info, {Size = Vector3.new(7, 0.05, 7)}):Play()
        _TweenService:Create(img, info, {ImageTransparency = 1}):Play()
        _Debris:AddItem(part, 0.9)
    end

    local function bind(char)
        if jc_conn then pcall(function() jc_conn:Disconnect() end); jc_conn = nil end
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        jc_conn = hum.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Jumping and jc.enabled then
                spawnCircle(hrp.Position - Vector3.new(0, 2.8, 0))
            end
        end)
    end

    _LP.CharacterAdded:Connect(bind)
    if _LP.Character then bind(_LP.Character) end

    addOpt(jcSec, "AddToggle", "JumpCircleOn", {
        Title = "Круг при прыжке", Default = false,
    }, function(v)
        jc.enabled = v
        if v and _LP.Character then bind(_LP.Character) end
    end)
    addOpt(jcSec, "AddColorPicker", "JumpCircleCol", {
        Title = "Цвет", Default = Color3.fromRGB(255, 105, 180),
    }, function(c) jc.color = c end)
end

-- ============================================================
-- ==================== RTX SHADER ============================
-- ============================================================
do
    local rtxSec = Tabs.Effects:AddSection({Name = "RTX Shader"})
    local rtxOn = false
    local saved, savedChildren, addedFx = {}, {}, {}
    local vignette

    local function enable()
        if rtxOn then return end
        rtxOn = true
        local props = {
            "Ambient", "Brightness", "ColorShift_Bottom", "ColorShift_Top",
            "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
            "GlobalShadows", "OutdoorAmbient", "ShadowSoftness",
            "ClockTime", "GeographicLatitude", "ExposureCompensation",
        }
        for _, p in ipairs(props) do
            pcall(function() saved[p] = _Lighting[p] end)
        end
        savedChildren = {}
        for _, ch in ipairs(_Lighting:GetChildren()) do
            if ch:IsA("PostEffect") or ch:IsA("Sky") or ch:IsA("Atmosphere") then
                ch.Parent = nil
                table.insert(savedChildren, ch)
            end
        end
        local bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.35
        bloom.Size = 20
        bloom.Threshold = 0.85
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Brightness = 0.05
        cc.Contrast = 0.25
        cc.Saturation = 0.15
        cc.TintColor = Color3.fromRGB(255, 245, 230)
        local sr = Instance.new("SunRaysEffect")
        sr.Intensity = 0.12
        sr.Spread = 0.8
        local sky = Instance.new("Sky")
        sky.SkyboxBk = "http://www.roblox.com/asset/?id=151165214"
        sky.SkyboxDn = "http://www.roblox.com/asset/?id=151165197"
        sky.SkyboxFt = "http://www.roblox.com/asset/?id=151165224"
        sky.SkyboxLf = "http://www.roblox.com/asset/?id=151165191"
        sky.SkyboxRt = "http://www.roblox.com/asset/?id=151165206"
        sky.SkyboxUp = "http://www.roblox.com/asset/?id=151165227"
        sky.SunAngularSize = 11
        local atm = Instance.new("Atmosphere")
        atm.Density = 0.3
        atm.Offset = 0.25
        atm.Color = Color3.fromRGB(199, 175, 166)
        atm.Decay = Color3.fromRGB(44, 39, 33)
        atm.Glare = 0.35
        atm.Haze = 1.2
        addedFx = {bloom, cc, sr, sky, atm}
        for _, fx in ipairs(addedFx) do fx.Parent = _Lighting end
        pcall(function() _Lighting.Technology = Enum.Technology.Future end)
        _Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        _Lighting.Brightness = 2
        _Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
        _Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
        _Lighting.EnvironmentDiffuseScale = 1
        _Lighting.EnvironmentSpecularScale = 1
        _Lighting.GlobalShadows = true
        _Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 100)
        _Lighting.ShadowSoftness = 0.15
        _Lighting.ClockTime = 14
        _Lighting.GeographicLatitude = 45
        _Lighting.ExposureCompensation = 0.1
        vignette = Instance.new("ScreenGui")
        vignette.Name = "FH_RTXVignette"
        vignette.IgnoreGuiInset = true
        vignette.ResetOnSpawn = false
        vignette.Parent = _LP:WaitForChild("PlayerGui")
        local img = Instance.new("ImageLabel")
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.new(0.5, 0, 1, 0)
        img.Size = UDim2.new(1, 0, 1.05, 0)
        img.BackgroundTransparency = 1
        img.Image = "rbxassetid://4576475446"
        img.ImageTransparency = 0.35
        img.ZIndex = 10
        img.Parent = vignette
    end

    local function disable()
        if not rtxOn then return end
        rtxOn = false
        for _, fx in ipairs(addedFx) do pcall(function() fx:Destroy() end) end
        addedFx = {}
        for _, ch in ipairs(savedChildren) do pcall(function() ch.Parent = _Lighting end) end
        savedChildren = {}
        for k, v in pairs(saved) do pcall(function() _Lighting[k] = v end) end
        saved = {}
        if vignette then pcall(function() vignette:Destroy() end); vignette = nil end
    end

    addOpt(rtxSec, "AddToggle", "RTXOn", {Title = "Включить RTX", Default = false}, function(v)
        if v then enable() else disable() end
        Notify("FH", "RTX " .. (v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)

    getgenv().RTX_UNLOAD = function()
        if rtxOn then disable() end
    end
end

-- ============================================================
-- ============= CUSTOM PNG AVATARS (для Player List) =========
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
    }
    local cache, userToUrl = {}, {}
    local folder = "FortniHub_Configs/avatars"
    if type(makefolder) == "function" and type(isfolder) == "function" then
        if not isfolder(folder) then pcall(makefolder, folder) end
    end

    local function resolveLocal(url, idx)
        if cache[url] then return cache[url] end
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
            cache[url] = asset
            return asset
        end
        return url
    end

    local function getAvatarFor(player)
        if not getgenv().FH_CustomAvatarsEnabled then
            if not player then return "" end
            local ok, img = pcall(function()
                return _Players:GetUserThumbnailAsync(player.UserId,
                    Enum.ThumbnailType.HeadShot,
                    Enum.ThumbnailSize.Size100x100)
            end)
            return ok and img or ""
        end
        if not player then
            return resolveLocal(avatarUrls[math.random(1, #avatarUrls)],
                math.random(1, #avatarUrls))
        end
        if userToUrl[player.UserId] then
            local idx
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
        local pick = pool[math.random(1, #pool)] or avatarUrls[1]
        userToUrl[player.UserId] = pick
        return resolveLocal(pick, 1)
    end

    getgenv().FH_GetAvatarFor = getAvatarFor
end

-- ============================================================
-- ========== FAKE KORBLOX / HEADLESS / MODEL CHANGER =========
-- ============================================================
do
    local charSec = Tabs.Visual:AddSection({Name = "Персонаж (fake)"})

    local korblox_on, headless_on = false, false
    local korblox_backup, head_backup = {}, {}
    local char_conn

    local function restore_korblox()
        local c = _LP.Character
        if not c then return end
        local ru = c:FindFirstChild("RightUpperLeg")
        local rl = c:FindFirstChild("RightLowerLeg")
        local rf = c:FindFirstChild("RightFoot")
        if ru and korblox_backup.RU then
            pcall(function()
                ru.TextureID = korblox_backup.RU.TextureID or ""
                ru.MeshId = korblox_backup.RU.MeshId or ""
            end)
        end
        if rl and korblox_backup.RL then
            pcall(function()
                rl.MeshId = korblox_backup.RL.MeshId or ""
                rl.Transparency = korblox_backup.RL.Transparency or 0
            end)
        end
        if rf and korblox_backup.RF then
            pcall(function()
                rf.MeshId = korblox_backup.RF.MeshId or ""
                rf.Transparency = korblox_backup.RF.Transparency or 0
            end)
        end
        korblox_backup = {}
    end

    local function apply_korblox()
        if not korblox_on then return end
        local c = _LP.Character
        if not c then return end
        local ru = c:FindFirstChild("RightUpperLeg")
        local rl = c:FindFirstChild("RightLowerLeg")
        local rf = c:FindFirstChild("RightFoot")
        if not ru then return end
        korblox_backup = {}
        if ru then
            korblox_backup.RU = {MeshId = ru.MeshId, TextureID = ru.TextureID}
            pcall(function()
                ru.MeshId = "rbxassetid://902942096"
                ru.TextureID = "rbxassetid://902843398"
            end)
        end
        if rl then
            korblox_backup.RL = {MeshId = rl.MeshId, Transparency = rl.Transparency}
            pcall(function()
                rl.MeshId = "rbxassetid://902942093"
                rl.Transparency = 1
            end)
        end
        if rf then
            korblox_backup.RF = {MeshId = rf.MeshId, Transparency = rf.Transparency}
            pcall(function()
                rf.MeshId = "rbxassetid://902942089"
                rf.Transparency = 1
            end)
        end
    end

    local function restore_headless()
        local c = _LP.Character
        if not c then return end
        local head = c:FindFirstChild("Head")
        if head and head_backup.Head then
            pcall(function()
                head.Transparency = head_backup.Head
                if head_backup.MeshId then head.MeshId = head_backup.MeshId end
                if head_backup.TextureID then head.TextureID = head_backup.TextureID end
            end)
        end
        for _, v in ipairs(head_backup.Children or {}) do
            if v.Obj and v.Obj.Parent then
                pcall(function() v.Obj.Transparency = v.Val end)
            end
        end
        head_backup = {}
    end

    local function apply_headless()
        if not headless_on then return end
        restore_headless()
        local c = _LP.Character
        if not c then return end
        local head = c:FindFirstChild("Head")
        if not head then return end
        head_backup.Head = head.Transparency
        head_backup.MeshId = head.MeshId
        head_backup.TextureID = head.TextureID
        head_backup.Children = {}
        pcall(function()
            head.MeshId = "rbxassetid://6686307858"
            head.TextureID = "rbxassetid://6686307858"
            head.Transparency = 1
        end)
        for _, child in ipairs(head:GetDescendants()) do
            if child:IsA("BasePart") or child:IsA("Decal")
                or child:IsA("MeshPart") or child:IsA("SpecialMesh") then
                local hasTrans = pcall(function() return child.Transparency end)
                if hasTrans then
                    local orig = child.Transparency
                    head_backup.Children[#head_backup.Children + 1] = {Obj = child, Val = orig}
                    pcall(function() child.Transparency = 1 end)
                end
            end
        end
    end

    local function apply_all()
        if korblox_on then apply_korblox() end
        if headless_on then apply_headless() end
    end

    local function connect_char()
        if char_conn then pcall(function() char_conn:Disconnect() end); char_conn = nil end
        char_conn = _LP.CharacterAdded:Connect(function()
            task.wait(1)
            apply_all()
        end)
    end

    addOpt(charSec, "AddToggle", "FakeKorblox", {
        Title = "Fake Korblox", Default = false,
    }, function(v)
        korblox_on = v
        if v then
            if not char_conn then connect_char() end
            apply_korblox()
        else
            restore_korblox()
        end
    end)

    addOpt(charSec, "AddToggle", "FakeHeadless", {
        Title = "Fake Headless", Default = false,
    }, function(v)
        headless_on = v
        if v then
            if not char_conn then connect_char() end
            apply_headless()
        else
            restore_headless()
        end
    end)

    getgenv().CHAR_FAKE_UNLOAD = function()
        korblox_on, headless_on = false, false
        if char_conn then pcall(function() char_conn:Disconnect() end); char_conn = nil end
        restore_korblox()
        restore_headless()
    end
end

-- ============================================================
-- ================== УВЕДОМЛЕНИЯ О СМЕРТИ ====================
-- ============================================================
do
    local meSec = Tabs.Effects:AddSection({Name = "Смерть убийцы"})

    local mOn = false
    local mCloneOn, mPartOn, mEmitOn = false, false, false
    local mCloneCol = Color3.fromRGB(255, 0, 0)
    local mPartCol = Color3.fromRGB(255, 0, 0)
    local mEmitCol = Color3.fromRGB(255, 100, 100)
    local mCloneDur, mEmitDur = 3, 1.2
    local mClones, mConns, mRoles = {}, {}, {}
    local mActive = {}

    local function spawnEmitter(char, tint, dur)
        if not char or not char.Parent then return end
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
        root.Parent = _Workspace
        local rec = {part = root, balls = {}}
        mActive[#mActive + 1] = rec
        local golden = math.pi * (3 - math.sqrt(5))
        local created = 0
        for _, source in ipairs(bodyParts) do
            local sz = source.Size
            local count = source.Name == "Head" and 20 or 10
            count = math.min(count, 140 - created)
            for index = 1, count do
                local dia = 0.13 + math.random() * 0.05
                local y = 1 - 2 * ((index - 0.5) / count)
                local angle = index * golden
                local radial = math.sqrt(math.max(0, 1 - y * y))
                local dir = Vector3.new(radial * math.cos(angle), y, radial * math.sin(angle))
                local half = sz * 0.5
                local pos = source.CFrame:PointToWorldSpace(Vector3.new(
                    dir.X * (half.X + dia * 0.5),
                    dir.Y * (half.Y + dia * 0.5),
                    dir.Z * (half.Z + dia * 0.5)))
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
                task.delay(0.1 + created * 0.005, function()
                    if not root.Parent then return end
                    _TweenService:Create(ball, TweenInfo.new(0.2),
                        {Size = Vector3.new(dia, dia, dia), Transparency = 0.05}):Play()
                    task.delay(dur * 0.5, function()
                        if not ball.Parent then return end
                        _TweenService:Create(ball, TweenInfo.new(dur * 0.4),
                            {Size = Vector3.new(dia * 0.58, dia * 0.58, dia * 0.58),
                             Transparency = 1}):Play()
                    end)
                end)
            end
            if created >= 140 then break end
        end
        task.delay(dur + 0.2, function()
            if root.Parent then root:Destroy() end
        end)
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
            elseif d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript")
                or d:IsA("ModuleScript") or d:IsA("Sound")
                or d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter")
                or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("PointLight") or d:IsA("SpotLight")
                or d:IsA("SurfaceLight") or d:IsA("Highlight") then
                pcall(function() d:Destroy() end)
            end
        end
        clone.Name = "FH_MurderClone"
        clone.Parent = _Workspace
        mClones[#mClones + 1] = clone
        task.delay(mCloneDur, function()
            if not clone.Parent then return end
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    _TweenService:Create(d, TweenInfo.new(1.5), {Transparency = 1}):Play()
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

    local function onDeath(char)
        if mCloneOn then makeClone(char) end
        if mPartOn then spawnEmitter(char, mPartCol, 1.2) end
        if mEmitOn then spawnEmitter(char, mEmitCol, mEmitDur) end
    end

    local function hookPlayer(pl)
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            mConns[#mConns + 1] = hum.Died:Connect(function()
                if mOn and mRoles[pl.Name] == "Murderer" then onDeath(char) end
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

    addOpt(meSec, "AddToggle", "MEOn", {Title = "Включить эффект", Default = false}, function(v)
        mOn = v
        if v then
            task.spawn(function()
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
            for _, pl in ipairs(_Players:GetPlayers()) do
                if pl ~= _LP then hookPlayer(pl) end
            end
            _Players.PlayerAdded:Connect(function(pl)
                if pl ~= _LP and mOn then hookPlayer(pl) end
            end)
        else
            stopMurder()
        end
    end)

    addOpt(meSec, "AddToggle", "MEClone", {Title = "Клон", Default = false}, function(v) mCloneOn = v end)
    addOpt(meSec, "AddColorPicker", "MECloneCol", {Title = "Цвет клона", Default = Color3.fromRGB(255, 0, 0)}, function(c) mCloneCol = c end)
    addOpt(meSec, "AddSlider", "MECloneDur", {Title = "Длительность клона", Min = 1, Max = 5, Default = 3, Rounding = 1}, function(v) mCloneDur = tonumber(v) or 3 end)
    addOpt(meSec, "AddToggle", "MEPart", {Title = "Частицы", Default = false}, function(v) mPartOn = v end)
    addOpt(meSec, "AddColorPicker", "MEPartCol", {Title = "Цвет частиц", Default = Color3.fromRGB(255, 0, 0)}, function(c) mPartCol = c end)
    addOpt(meSec, "AddToggle", "MEEmit", {Title = "Emitter", Default = false}, function(v) mEmitOn = v end)
    addOpt(meSec, "AddColorPicker", "MEEmitCol", {Title = "Цвет emitter", Default = Color3.fromRGB(255, 100, 100)}, function(c) mEmitCol = c end)
    addOpt(meSec, "AddSlider", "MEEmitDur", {Title = "Длительность emitter", Min = 1, Max = 5, Default = 1, Rounding = 1}, function(v) mEmitDur = tonumber(v) or 1 end)

    getgenv().MURDERFX_UNLOAD = function()
        mOn = false
        stopMurder()
    end
end

-- ============================================================
-- ================== ЯЗЫК (RU/EN) ============================
-- ============================================================
do
    local langSec = Tabs.Settings:AddSection({Name = "Язык"})
    local currentLang = "RU"
    getgenv().FH_CurrentLang = currentLang
    addOpt(langSec, "AddDropdown", "FH_Lang", {
        Title = "Язык интерфейса", Values = {"RU", "EN"}, Default = "RU",
    }, function(v)
        currentLang = v or "RU"
        getgenv().FH_CurrentLang = currentLang
        Notify("FH", "Язык: " .. currentLang, 1.5)
    end)
    langSec:AddButton({Title = "Применить сейчас", Callback = function()
        Notify("FH", "Язык: " .. currentLang, 1.5)
    end})
end

-- ============================================================
-- ================== UNLOAD ALL (Part 2) =====================
-- ============================================================
local PART2_UNLOADS = {
    "AURA2_UNLOAD", "GHOST_UNLOAD", "SKYBOX_UNLOAD",
    "TRACER_UNLOAD", "EXTRA_AURAS_UNLOAD", "TH_UNLOAD",
    "PLAYERLIST_UNLOAD", "VOTEDUPER_UNLOAD", "ADVFARM_UNLOAD",
    "WATER_UNLOAD", "FADE_UNLOAD", "ANTICOIN_UNLOAD",
    "RTX_UNLOAD", "CHAR_FAKE_UNLOAD", "MURDERFX_UNLOAD",
}
getgenv().FH_PART2_UNLOAD = function()
    for _, key in ipairs(PART2_UNLOADS) do
        local fn = getgenv()[key]
        if type(fn) == "function" then
            pcall(fn)
            getgenv()[key] = nil
        end
    end
end

pcall(function() Window:SelectTab(1) end)

print("[FH] ============================================")
print("[FH] Part 2/2 — FortniHub v20.2 — " .. CREDITS)
print("[FH] Aura 2.0 | Client Ghost | Skybox Manager")
print("[FH] Trade Helper | Player List | Vote Duper")
print("[FH] Advanced Farm | Water Prot | Fade Disabler")
print("[FH] Anti-Coin | Jump Circle | RTX | PNG Avatars")
print("[FH] Fake Korblox/Headless | Murder FX | Language")
print("[FH] ============================================")
