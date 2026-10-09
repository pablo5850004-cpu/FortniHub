-- ============================================================
-- FortniHub MM2 v20.3 BETA — ЧАСТЬ 1/2
-- Combat / Movement / Binds / Settings
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

local VERSION = "20.3.0 BETA"
local CREDITS = "by HOTI and Ve315"

-- ============================================================
-- STATE
-- ============================================================
local S = {
    frozen = false,
    freezeUpKey = Enum.KeyCode.Space,
    freezeDownKey = Enum.KeyCode.LeftControl,
}
local kaV1 = {on=false, dist=30, lastHit=0}
local kaV2 = {on=false, dist=30, lastHit=0}
local killAuraVersion = "v2"
local Connections = {}

local function AddConn(name, conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name] = conn
end

-- ============================================================
-- HELPERS
-- ============================================================
local Cache = {hrp=nil, hum=nil, cacheTime=0}
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

local roundModule = nil
local function getRoundModule()
    if roundModule then return roundModule end
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
    end)
    if ok and type(m) == "table" then roundModule = m end
    return roundModule
end

local function getRoundData()
    local m = getRoundModule()
    return m and m.PlayerData or nil
end

local function getRoleFromData(p)
    if not p then return "lobby" end
    local m = getRoundModule()
    if m and type(m.PlayerData) == "table" then
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
        if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then return "murderer" end
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

local function adaptTab(tab)
    if not tab then return tab end
    for _, name in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput","AddButton","AddKeybind","AddColorpicker","AddColorPicker"}) do
        local orig = tab[name]
        if type(orig) == "function" and not rawget(tab, "__"..name) then
            rawset(tab, "__"..name, true)
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
            if type(arg) == "table" then arg = arg.Name or arg.name or "Section" end
            if arg == nil then arg = "Section" end
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
        SubTitle = "v"..VERSION.." — "..CREDITS,
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
Tabs.Combat = Window:AddTab({Title="Бой"})
Tabs.Movement = Window:AddTab({Title="Движение"})
Tabs.Binds = Window:AddTab({Title="Бинды"})
Tabs.Visual = Window:AddTab({Title="Визуал"})
Tabs.Effects = Window:AddTab({Title="Эффекты"})
Tabs.Farm = Window:AddTab({Title="Фарм"})
Tabs.Animations = Window:AddTab({Title="Эмоции"})
Tabs.Utility = Window:AddTab({Title="Утилиты"})
Tabs.Troll = Window:AddTab({Title="Троллинг"})
Tabs.Settings = Window:AddTab({Title="Настройки"})

local OnChangedRegistry = {}
getgenv().FH_OnChangedRegistry = OnChangedRegistry

local function addOpt(container, method, name, opts, callback)
    if type(opts) == "table" and opts.Title == nil then
        opts.Title = opts.Name or opts.name or name
    end
    local ok, opt = pcall(function()
        return container[method](container, name, opts)
    end)
    if not ok then
        warn("[FH] addOpt ошибка: "..tostring(opt))
        return nil
    end
    if opt and callback then
        opt:OnChanged(callback)
        OnChangedRegistry[name] = callback
    end
    return opt
end

local lastNotify = {}
local function Notify(title, content, dur)
    local k = tostring(title).."|"..tostring(content)
    if lastNotify[k] and (tick() - lastNotify[k]) < 0.5 then return end
    lastNotify[k] = tick()
    pcall(function()
        Fluent:Notify({Title = title, Content = content, Duration = dur or 3})
    end)
end
getgenv().FH_Notify = Notify

task.spawn(function()
    task.wait(0.8)
    Notify("FortniHub", "Скрипт создан HOTI и Ve315.", 7)
    task.wait(1.2)
    Notify("FortniHub", "v20.3 — исправленная", 7)
end)

-- ============================================================
-- HUD (FPS/Ping)
-- ============================================================
local HUDGui, FPSLabel, PingLabel, Pill
do
    pcall(function()
        for _, name in ipairs({"FH_HUD_v18","FH_HUD","FH_HUD_v19","FH_HUD_v20","FH_HUD_v21","FH_HUD_v22"}) do
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
            dragging = true
            dragMoved = false
            dragStart = i.Position
            posStart = Pill.Position
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
            local cur = fc
            fc = 0
            lastSec = now
            local c = cur < 30 and Color3.fromRGB(255,80,80) or (cur < 60 and Color3.fromRGB(255,200,80) or Color3.fromRGB(80,240,120))
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
            local c = p < 60 and Color3.fromRGB(80,240,120) or (p < 120 and Color3.fromRGB(255,200,80) or Color3.fromRGB(255,80,80))
            PingLabel.Text = tostring(p)
            PingLabel.TextColor3 = c
        end
    end))
end

-- ============================================================
-- SILENT AIM (с предсказанием, отступом, force shoot)
-- ============================================================
do
    local MAX_RANGE = 500
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
        predict_studs = 1,
        predict_ms = 100,
    }
    local SS = getgenv().SILENT_S
    local silent_section = Tabs.Combat:AddSection({Name="Тихий выстрел"})

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

    local function holds(container, name)
        return container ~= nil and container:FindFirstChild(name) ~= nil
    end
    local function lp_has_gun()
        return holds(lp.Character, "Gun") or holds(lp:FindFirstChildOfClass("Backpack"), "Gun")
    end

    local target_player, target_char, target_part, target_hum = nil, nil, nil, nil
    local function refresh_target()
        local found = nil
        local data = getRoundData()
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

    -- Predict: используем AssemblyLinearVelocity + ping + studs offset
    local function predictPosition(part, hum)
        local base = part.Position
        if not SS.predict then return base end
        local ping = 0
        pcall(function()
            local v = lp:GetNetworkPing() * 2
            if v == v and v > 0 then ping = v end
        end)
        ping = math.clamp(ping, 0.02, 0.6)
        -- override через настройки
        local msOverride = SS.predict_ms / 1000
        if msOverride > 0 then ping = msOverride end
        local vel = part.AssemblyLinearVelocity
        local shift = Vector3.new(vel.X, 0, vel.Z) * ping * SS.predict_studs
        if hum then
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Freefall or st == Enum.HumanoidStateType.Jumping then
                local g = Workspace.Gravity
                shift = shift + Vector3.new(0, vel.Y * ping - 0.5 * g * ping * ping, 0)
            end
        end
        return base + shift
    end

    -- Force shoot: ищем точку за укрытием, ставим attachment туда
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
        if not ok then
            restore_origin()
            return false
        end
        task.defer(restore_origin)
        return true
    end

    -- Проверяем LOS через raycast
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

    local hit_names = {
        "HumanoidRootPart","UpperTorso","Torso","LowerTorso","Head",
        "RightUpperArm","LeftUpperArm","RightUpperLeg","LeftUpperLeg",
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

    local function pick_point(origin, strict)
        refresh_parts()
        if hit_count == 0 then return nil end
        local first = nil
        for k = 1, hit_count do
            local part = hit_parts[k]
            if part.Parent then
                local point = predictPosition(part, target_hum)
                if not origin then return point end
                if not first then first = point end
                if los_clear(origin, point) then return point end
            else
                hit_char = nil
            end
        end
        if strict then return nil end
        return first
    end

    -- FFS (force): ищем позицию origin за стеной
    local function findForceOrigin(targetPos)
        local myPos = nil
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then myPos = hrp.Position end
        if not myPos then return nil end
        local dir = (targetPos - myPos)
        if dir.Magnitude < 1 then return nil end
        dir = dir.Unit
        -- отступаем назад
        local stand = SS.stand_off
        if stand < 1 then stand = 15 end
        local back = targetPos - dir * stand
        -- проверяем чтобы origin не был внутри цели
        return CFrame.new(back, targetPos)
    end

    local function resolve_shot()
        if not SS.enabled or not SS.am_sheriff or not target_alive() then return nil end
        if SS.force then
            -- force shoot: если нет LOS — пробуем force
            local cf = origin_cframe()
            if not cf then return nil end
            local aim = pick_point(cf.Position, false)
            if not aim then return nil end
            -- проверим LOS
            if los_clear(cf.Position, aim) then
                return CFrame.new(aim)
            end
            -- нет LOS — двигаем origin за укрытие
            local forceOrigin = findForceOrigin(aim)
            if forceOrigin then
                if push_origin(forceOrigin) then
                    return CFrame.new(aim)
                end
            end
            return CFrame.new(aim)
        end
        local cf = origin_cframe()
        if not cf then return nil end
        local aim = pick_point(cf.Position, false)
        if not aim then return nil end
        return CFrame.new(aim)
    end

    -- Hook WeaponService
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
                local ok, cf = pcall(resolve_shot)
                if ok and cf then return cf end
                return orig_mouse(self, ...)
            end
            hook_screen = function(self, x, y, ...)
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

    -- Auto fire
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
        if not SS.auto_on or not SS.enabled or not SS.am_sheriff then
            want_since = 0
            return
        end
        if not target_alive() then
            want_since = 0
            return
        end
        local gun, equipped = get_gun()
        if not gun then
            want_since = 0
            return
        end
        if gun ~= gap_gun then
            gap_gun = gun
            gap_reset()
        end
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
        if SS.force then
            if not los_clear(cf.Position, aim) then
                local forceOrigin = findForceOrigin(aim)
                if forceOrigin then push_origin(forceOrigin) end
            end
        end
        if fire_gun(gun, cf, aim_cf) then SS.last_shot = now end
    end

    local next_role, next_hook = 0, 0
    local main_conn = run.Heartbeat:Connect(function()
        if force_att and os.clock() - force_stamp > 0.05 then restore_origin() end
        if not SS.enabled then return end
        local now = os.clock()
        if now >= next_role then
            next_role = now + 0.2
            refresh_target()
        end
        if now >= next_hook then
            next_hook = now + 1
            install_hooks()
            connect_gun_fired()
        end
        auto_step(now)
    end)

    addOpt(silent_section, "AddToggle", "SilentEnabled", {Title="Включить", Default=false}, function(v)
        SS.enabled = v
        getgenv().SILENT_AIM_ACTIVE = v
        if v then
            task.spawn(function()
                pcall(install_hooks)
                pcall(connect_gun_fired)
                pcall(refresh_target)
            end)
            Notify("FH", "Silent ON", 1.5)
        else
            restore_origin()
            Notify("FH", "Silent OFF", 1.5)
        end
    end)

    local predTog = addOpt(silent_section, "AddToggle", "SilentPredict", {Title="Предсказание", Default=true}, function(v)
        SS.predict = v
    end)

    addOpt(silent_section, "AddSlider", "SilentPredictStuds",
        {Title="Множитель предсказания", Min=0, Max=5, Default=1, Rounding=2},
        function(v) SS.predict_studs = tonumber(v) or 1 end)

    addOpt(silent_section, "AddSlider", "SilentPredictMS",
        {Title="Задержка (мс) — 0 = авто по пингу", Min=0, Max=500, Default=0, Rounding=0},
        function(v) SS.predict_ms = tonumber(v) or 0 end)

    local forceTog = addOpt(silent_section, "AddToggle", "SilentForce",
        {Title="Стрельба через стены", Default=false}, function(v)
        SS.force = v
        if v then
            Notify("FH", "Force shoot ON", 2)
        else
            restore_origin()
        end
    end)

    addOpt(silent_section, "AddSlider", "SilentStandoff",
        {Title="Отступ через стену (студы)", Min=0, Max=80, Default=15, Rounding=0},
        function(v) SS.stand_off = tonumber(v) or 15 end)

    addOpt(silent_section, "AddToggle", "SilentAuto", {Title="Авто-выстрел", Default=false},
        function(v) SS.auto_on = v end)

    addOpt(silent_section, "AddSlider", "SilentAutoDelay",
        {Title="Задержка авто (мс)", Default=0, Min=0, Max=600, Rounding=0},
        function(v) SS.auto_delay = (tonumber(v) or 0) / 1000 end)

    getgenv().SILENT_UNLOAD = function()
        SS.enabled = false
        SS.predict = false
        SS.force = false
        SS.auto_on = false
        restore_origin()
        if gun_fired_conn then pcall(function() gun_fired_conn:Disconnect() end) gun_fired_conn = nil end
        if main_conn then pcall(function() main_conn:Disconnect() end) main_conn = nil end
        local m = weapon_service
        if m then
            pcall(function() setreadonly(m, false) end)
            if orig_mouse then pcall(function() m.GetMouseTargetCFrame = orig_mouse end) end
            if orig_screen then pcall(function() m.GetTargetPosition = orig_screen end) end
        end
    end
end

-- ============================================================
-- КИЛЛ АУРА (v1 + v2)
-- ============================================================
do
    local tC = Tabs.Combat
    local kaSec = tC:AddSection({Name="Килл Аура"})
    addOpt(kaSec, "AddDropdown", "KAVersion", {Title="Версия", Values={"v1","v2"}, Default="v2"}, function(v)
        killAuraVersion = v
        kaV1.on = false
        kaV2.on = false
        if Options.KAOn and Options.KAOn.Value then
            kaV1.on = v == "v1"
            kaV2.on = v == "v2"
        end
    end)
    addOpt(kaSec, "AddToggle", "KAOn", {Title="Включить", Default=false}, function(v)
        kaV1.on = v and killAuraVersion == "v1"
        kaV2.on = v and killAuraVersion == "v2"
    end)
    addOpt(kaSec, "AddSlider", "KADist", {Title="Радиус", Min=5, Max=80, Default=30, Rounding=0}, function(v)
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
                        victims[#victims+1] = tp
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
                        victims[#victims+1] = tp
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
-- AUTO GRAB GUN
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
                :WaitForChild("Gameplay", 15):WaitForChild("CoinsStarted", 15)
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
                if d < bd then
                    bd = d
                    best = gun
                end
            end
        end
        return best
    end
    local autoGrabEnabled = false
    addOpt(tC, "AddToggle", "AutoGrabGun", {Title="Авто-подбор пистолета", Default=false},
        function(v) autoGrabEnabled = v end)
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
                if c and c:FindFirstChild("Gun") then
                    grabbed = true
                    break
                end
                local b = LocalPlayer:FindFirstChildOfClass("Backpack")
                if b and b:FindFirstChild("Gun") then
                    grabbed = true
                    break
                end
            end
            if my and my.Parent then
                my.CFrame = rp
                my.AssemblyLinearVelocity = Vector3.zero
                my.AssemblyAngularVelocity = Vector3.zero
            end
            if not grabbed then
                grabFailedRound = true
                Notify("FH", "Пистолет не подобран", 4)
            end
            isGrabbing = false
        end)
    end))
    AddConn("AutoGrabReset", LocalPlayer.CharacterAdded:Connect(function()
        isGrabbing = false
    end))
end

-- ============================================================
-- ДВИЖЕНИЕ
-- ============================================================
do
    local tM = Tabs.Movement
    local mvSec = tM:AddSection({Name="Основное"})

    -- Speed
    addOpt(mvSec, "AddToggle", "SpeedToggle", {Title="Скорость", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "SpeedValue", {Title="Скорость ходьбы", Min=16, Max=500, Default=32, Rounding=0}, function() end)

    -- Noclip
    addOpt(mvSec, "AddToggle", "Noclip", {Title="Noclip", Default=false}, function() end)

    -- Spinbot
    addOpt(mvSec, "AddToggle", "Spinbot", {Title="Spinbot", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "SpinSpeed", {Title="Скорость кручения", Min=1, Max=50, Default=8, Rounding=0}, function() end)

    -- Inf jump
    addOpt(mvSec, "AddToggle", "InfJump", {Title="Бесконечный прыжок", Default=false}, function() end)

    -- Jump power
    addOpt(mvSec, "AddToggle", "JumpPowerToggle", {Title="Своя сила прыжка", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "JumpPowerVal", {Title="Сила прыжка", Min=50, Max=500, Default=100, Rounding=0}, function() end)

    -- Fly
    addOpt(mvSec, "AddToggle", "FlyToggle", {Title="Полёт", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "FlySpeed", {Title="Скорость полёта", Min=20, Max=500, Default=60, Rounding=0}, function() end)
    addOpt(mvSec, "AddToggle", "FlyUp", {Title="Вверх (Space)", Default=true}, function() end)
    addOpt(mvSec, "AddToggle", "FlyDown", {Title="Вниз (Shift)", Default=true}, function() end)

    -- Bhop
    addOpt(mvSec, "AddToggle", "BhopOn", {Title="Банихоп", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "BhopPower", {Title="Сила банихопа", Min=10, Max=150, Default=40, Rounding=0}, function() end)
    addOpt(mvSec, "AddToggle", "BhopStrafe", {Title="Стрейф", Default=false}, function() end)

    -- SpeedGlitch
    addOpt(mvSec, "AddToggle", "SpeedGlitchOn", {Title="Спидглитч", Default=false}, function() end)
    addOpt(mvSec, "AddSlider", "SpeedGlitchPower", {Title="Скорость в прыжке", Min=30, Max=250, Default=90, Rounding=0}, function() end)

    -- ============================================================
    -- SPEED/NOCLIP/SPIN/INFJUMP/JUMP/SPINGLITCH
    -- ============================================================
    AddConn("MovementTick", RunService.Heartbeat:Connect(function()
        local hum = getHum()
        local hrp = getHRP()
        if not hum then return end

        -- Speed
        if Options.SpeedToggle and Options.SpeedToggle.Value then
            local sp = (Options.SpeedValue and tonumber(Options.SpeedValue.Value)) or 32
            if hum.WalkSpeed ~= sp then hum.WalkSpeed = sp end
        end

        -- Jump power
        if Options.JumpPowerToggle and Options.JumpPowerToggle.Value then
            local jp = (Options.JumpPowerVal and tonumber(Options.JumpPowerVal.Value)) or 100
            hum.UseJumpPower = true
            if hum.JumpPower ~= jp then hum.JumpPower = jp end
        end

        -- Spinbot
        if Options.Spinbot and Options.Spinbot.Value and hrp then
            local s = (Options.SpinSpeed and tonumber(Options.SpinSpeed.Value)) or 8
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(s), 0)
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

    -- ============================================================
    -- FLY (с правильным выключением и без провала под землю)
    -- ============================================================
    local flyGrav = Workspace.Gravity
    local flyWasActive = false

    local function safeLand()
        local hrp = getHRP()
        if not hrp then return end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {LocalPlayer.Character}
        local hit = Workspace:Raycast(hrp.Position, Vector3.new(0, -300, 0), params)
        if hit then
            hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
        else
            -- если вообще нет поверхности — наверх на 5 студов
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 5, 0)
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    local function flyOff()
        if not flyWasActive then return end
        flyWasActive = false
        Workspace.Gravity = flyGrav
        local hum = getHum()
        if hum then
            pcall(function() hum.PlatformStand = false end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end
        task.defer(function()
            task.wait(0.1)
            safeLand()
        end)
    end

    local function flyOn()
        flyWasActive = true
        flyGrav = Workspace.Gravity
        Workspace.Gravity = 0
    end

    registerOnChanged("FlyToggle", function(v)
        if v then flyOn() else flyOff() end
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
        if Options.FlyUp and Options.FlyUp.Value then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                dir = dir + Vector3.new(0, 1, 0)
            end
        end
        if Options.FlyDown and Options.FlyDown.Value then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                dir = dir - Vector3.new(0, 1, 0)
            end
        end
        hrp.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero
    end))

    -- ============================================================
    -- FREEZE (висение + ноклип + вверх/вниз)
    -- ============================================================
    local freezeSec = tM:AddSection({Name="Заморозка"})
    local frozenNow = false
    local frozenY = nil
    local fBV = nil

    local function freezeEnd()
        frozenNow = false
        S.frozen = false
        local hrp = getHRP()
        if hrp and fBV then
            pcall(function() fBV:Destroy() end)
            fBV = nil
        end
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.CanCollide = true end)
                end
            end
        end
        safeLand()
    end

    local function freezeBegin()
        frozenNow = true
        S.frozen = true
        local hum = getHum()
        local hrp = getHRP()
        if not hum or not hrp then return end
        frozenY = hrp.Position.Y
        if fBV then pcall(function() fBV:Destroy() end) end
        fBV = Instance.new("BodyVelocity")
        fBV.Name = "FH_FreezeBV"
        fBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        fBV.Velocity = Vector3.zero
        fBV.Parent = hrp
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then
                    pcall(function() p.CanCollide = false end)
                end
            end
        end
    end

    addOpt(freezeSec, "AddToggle", "FreezeToggle", {Title="Включить", Default=false}, function(v)
        if v then freezeBegin() else freezeEnd() end
    end)
    addOpt(freezeSec, "AddSlider", "FreezeSpeed", {Title="Скорость", Min=20, Max=300, Default=60, Rounding=0}, function() end)

    local fUp = freezeSec:AddKeybind("FreezeUpKey", {Title="Кнопка ВВЕРХ", Default="Space"})
    fUp:OnChanged(function(k)
        if typeof(k) == "EnumItem" then S.freezeUpKey = k end
    end)
    local fDown = freezeSec:AddKeybind("FreezeDownKey", {Title="Кнопка ВНИЗ", Default="LeftControl"})
    fDown:OnChanged(function(k)
        if typeof(k) == "EnumItem" then S.freezeDownKey = k end
    end)

    -- Ноклип + вверх/вниз во время заморозки
    RunService.Stepped:Connect(function()
        if not frozenNow then return end
        local hrp = getHRP()
        if not hrp then return end
        local c = LocalPlayer.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
            end
        end
        local sp = (Options.FreezeSpeed and tonumber(Options.FreezeSpeed.Value)) or 60
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(S.freezeUpKey) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(S.freezeDownKey) then dir = dir - Vector3.new(0, 1, 0) end
        if fBV then
            fBV.Velocity = dir.Magnitude > 0 and dir.Unit * sp or Vector3.zero
        end
    end)

    getgenv().MOVE_UNLOAD = function()
        freezeEnd()
        flyOff()
    end
end

-- ============================================================
-- БИНДЫ
-- ============================================================
do
    local tB = Tabs.Binds
    local BIND_LIST = {
        {id="SilentEnabled", title="Тихий выстрел", cat="Бой", opt="SilentEnabled"},
        {id="KAOn", title="Килл Аура", cat="Бой", opt="KAOn"},
        {id="AutoGrabGun", title="Авто-подбор пистолета", cat="Бой", opt="AutoGrabGun"},
        {id="SpeedToggle", title="Скорость", cat="Движение", opt="SpeedToggle"},
        {id="Noclip", title="Noclip", cat="Движение", opt="Noclip"},
        {id="Spinbot", title="Спинбот", cat="Движение", opt="Spinbot"},
        {id="InfJump", title="Бесконечный прыжок", cat="Движение", opt="InfJump"},
        {id="JumpPowerToggle", title="Своя сила прыжка", cat="Движение", opt="JumpPowerToggle"},
        {id="FlyToggle", title="Полёт", cat="Движение", opt="FlyToggle"},
        {id="BhopOn", title="Банихоп", cat="Движение", opt="BhopOn"},
        {id="SpeedGlitchOn", title="Спидглитч", cat="Движение", opt="SpeedGlitchOn"},
        {id="FreezeToggle", title="Заморозка", cat="Движение", opt="FreezeToggle"},
        {id="InvisOn", title="Невидимость", cat="Другое", opt="InvisOn"},
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
        local def = st.def
        if def.opt then
            local o = Options[def.opt]
            if o and o.Value ~= nil then
                o:SetValue(not o.Value)
                Notify("FH", def.title..": "..tostring(o.Value), 1.2)
            end
        end
    end

    local function makeTouchButton(id)
        local st = BindState[id]
        if not st or st.btn then return end
        local def = st.def
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(150, 34)
        btn.Position = UDim2.fromOffset(20, 20 + (#BIND_LIST * 40))
        btn.BackgroundColor3 = Color3.fromRGB(28, 22, 42)
        btn.BorderSizePixel = 0
        btn.Text = def.title
        btn.TextColor3 = Color3.fromRGB(235, 225, 255)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.Parent = touchGui
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local dragging, dragStart, posStart = false, nil, nil
        btn.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = i.Position
                posStart = btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - dragStart
                btn.Position = UDim2.new(posStart.X.Scale, posStart.X.Offset + d.X, posStart.Y.Scale, posStart.Y.Offset + d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        btn.Activated:Connect(function() fireBind(id) end)
        st.btn = btn
    end

    local function killTouchButton(id)
        local st = BindState[id]
        if not st then return end
        if st.btn then pcall(function() st.btn:Destroy() end) st.btn = nil end
    end

    local listSec = tB:AddSection({Name="Модули"})
    local currentCat = nil
    for _, def in ipairs(BIND_LIST) do
        if def.cat ~= currentCat then
            currentCat = def.cat
        end
        local st = BindState[def.id]
        local kb = listSec:AddKeybind("BIND_KEY_"..def.id, {Title=def.title, Default="Unknown"})
        kb:OnChanged(function(k)
            if typeof(k) == "EnumItem" then
                st.key = k
                Notify("FH", "Бинд: "..def.title.." > "..tostring(k), 2)
            else
                st.key = nil
            end
        end)
        addOpt(listSec, "AddToggle", "BIND_TCH_"..def.id, {Title="  Кнопка: "..def.title, Default=false}, function(v)
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
            if Options["BIND_KEY_"..id] then
                pcall(function() Options["BIND_KEY_"..id]:SetValue(Enum.KeyCode.Unknown) end)
                count = count + 1
            end
        end
        Notify("FH", "Сброшено биндов: "..count, 2)
    end})
end

-- ============================================================
-- НАСТРОЙКИ (конфиги)
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

    -- Конфиги
    local cfgSec = tS:AddSection({Name="Конфиги"})
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
            local name = string.match(f, "([^/\\]+)"..CONFIG_EXT.."$")
            if name then out[#out+1] = name end
        end
        return out
    end

    local function serializeValue(v, depth)
        depth = depth or 0
        if depth > 12 then return nil end
        if typeof(v) == "Color3" then
            return string.format("C:%.6f,%.6f,%.6f", v.R, v.G, v.B)
        end
        if typeof(v) == "EnumItem" then
            if v.EnumType == Enum.KeyCode then return "K:"..v.Name end
            return "E:"..tostring(v.EnumType).."|"..v.Name
        end
        if typeof(v) == "Vector3" then
            return string.format("V:%.4f,%.4f,%.4f", v.X, v.Y, v.Z)
        end
        local t = type(v)
        if t == "number" then return "N:"..tostring(v) end
        if t == "boolean" then return "B:"..tostring(v) end
        if t == "string" then
            if Enum.KeyCode[v] then return "K:"..v end
            v = v:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t")
            return "S:"..v
        end
        if t == "table" then
            local isArray = true
            for k in pairs(v) do
                if type(k) ~= "number" then
                    isArray = false
                    break
                end
            end
            if isArray then
                local parts = {}
                for i = 1, #v do
                    local sv = serializeValue(v[i], depth+1)
                    parts[#parts+1] = sv or "X:"
                end
                return "L:"..table.concat(parts, "\2")
            else
                local parts = {}
                for k, val in pairs(v) do
                    local sv = serializeValue(val, depth+1)
                    if sv then parts[#parts+1] = tostring(k).."="..sv end
                end
                return "D:"..table.concat(parts, "\3")
            end
        end
        return nil
    end

    local function deserializeValue(s, depth)
        depth = depth or 0
        if depth > 12 then return nil end
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
        if prefix == "V" then
            local x, y, z = string.match(rest, "([^,]+),([^,]+),([^,]+)")
            if x and y and z then
                return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
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
        if prefix == "S" then
            return rest:gsub("\\t", "\t"):gsub("\\n", "\n"):gsub("\\\\", "\\")
        end
        if prefix == "L" then
            local out = {}
            for piece in string.gmatch(rest, "([^\2]*)") do
                if piece ~= "" and piece ~= "X:" then
                    out[#out+1] = deserializeValue(piece, depth+1)
                end
            end
            return out
        end
        if prefix == "D" then
            local out = {}
            for pair in string.gmatch(rest, "([^\3]*)") do
                if pair ~= "" then
                    local k, val = string.match(pair, "^(.-)=(.*)$")
                    if k and val then
                        out[k] = deserializeValue(val, depth+1)
                    end
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
        local lines = {"-- FortniHub Config: "..tostring(name), "-- "..os.date("%Y-%m-%d %H:%M:%S")}
        for optionName, option in pairs(Options) do
            if option and option.Value ~= nil then
                local ser = serializeValue(option.Value)
                if ser then lines[#lines+1] = optionName.."\t"..ser end
            end
        end
        local path = CONFIG_DIR..name..CONFIG_EXT
        local ok = pcall(writefile, path, table.concat(lines, "\n"))
        if ok then
            Notify("FH", "Сохранено: "..name, 3)
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
        local path = CONFIG_DIR..name..CONFIG_EXT
        local ok, data = pcall(readfile, path)
        if not ok or type(data) ~= "string" then
            Notify("FH", "Ошибка чтения", 3)
            return false
        end
        local loaded = 0
        for line in string.gmatch(data, "[^\r\n]+") do
            if line:sub(1,2) ~= "--" then
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
        Notify("FH", "Загружено: "..name.." ("..loaded..")", 4)
        return true
    end

    local function deleteConfig(name)
        if type(delfile) ~= "function" then
            Notify("FH", "Нет delfile", 4)
            return false
        end
        local ok = pcall(delfile, CONFIG_DIR..name..CONFIG_EXT)
        if ok then
            Notify("FH", "Удалено: "..name, 2)
            return true
        end
        return false
    end

    local currentList = listConfigs()
    if #currentList == 0 then currentList = {"(нет конфигов)"} end
    local drop = cfgSec:AddDropdown("ConfigPick", {Title="Выбрать конфиг", Values=currentList, Default=currentList[1]})

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
        local nameOpt = Options.ConfigName
        local name = nameOpt and nameOpt.Value or "my_config"
        if type(name) ~= "string" or name == "" then
            Notify("FH", "Введи имя", 3)
            return
        end
        if saveConfig(name) then refreshList() end
    end})
    cfgSec:AddButton({Title="Загрузить", Callback=function()
        local pickOpt = Options.ConfigPick
        local name = pickOpt and pickOpt.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3)
            return
        end
        loadConfig(name)
    end})
    cfgSec:AddButton({Title="Удалить", Callback=function()
        local pickOpt = Options.ConfigPick
        local name = pickOpt and pickOpt.Value
        if type(name) ~= "string" or name == "" or name == "(нет конфигов)" then
            Notify("FH", "Выбери конфиг", 3)
            return
        end
        if deleteConfig(name) then refreshList() end
    end})
    cfgSec:AddButton({Title="Обновить список", Callback=refreshList})
    if HUDGui then HUDGui.Enabled = true end
end

-- ============================================================
-- ЭКСПОРТ ДЛЯ PART 2
-- ============================================================
getgenv().FH_Window = Window
getgenv().Options = Options
getgenv().FH_Notify = Notify
getgenv().getRoundData = getRoundData
getgenv().getRoleFromData = getRoleFromData
getgenv().getHRP = getHRP
getgenv().getHum = getHum
getgenv().getRoundModule = getRoundModule

print("[FH] ============================================")
print("[FH] Part 1/2 v20.3 — "..CREDITS)
print("[FH] Combat / Movement / Binds / Settings")
print("[FH] ============================================")
-- ============================================================
-- FortniHub MM2 v20.3 BETA — ЧАСТЬ 2/2
-- Visual / Effects / Farm / Utility / Troll / Extra
-- ============================================================
-- Part 2 — переменные Window/Options/Notify/Tabs уже в области видимости
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

local OnChangedRegistry = getgenv().FH_OnChangedRegistry or {}
getgenv().FH_OnChangedRegistry = OnChangedRegistry

local function addOpt(container, method, name, opts, callback)
    if type(opts) == "table" and opts.Title == nil then
        opts.Title = opts.Name or opts.name or name
    end
    local ok, opt = pcall(function()
        return container[method](container, name, opts)
    end)
    if not ok then
        warn("[FH] addOpt ошибка: "..tostring(opt))
        return nil
    end
    if opt and callback then
        opt:OnChanged(callback)
        OnChangedRegistry[name] = callback
    end
    return opt
end

local _uiRoot = function() return (gethui and gethui()) or CoreGui end

-- ============================================================
-- ESP ИГРОКОВ
-- ============================================================
do
    local espState = {
        enabled=false, box=false, boxCol={Color3.fromRGB(255,255,255),1}, boxType="Static",
        boxGrd=false, boxGrd1=Color3.fromRGB(255,60,60), boxGrd2=Color3.fromRGB(255,180,60),
        boxFill=false, boxFillCol={Color3.fromRGB(255,60,60),0.5},
        name=false, nameCol={Color3.new(1,1,1),1}, dist=false, distCol={Color3.fromRGB(220,220,220),1},
        avatar=false, skel=false, skelCol={Color3.new(1,1,1),1}, chams=false,
        chamsFMur={Color3.fromRGB(255,60,60),0.55}, chamsOMur={Color3.fromRGB(255,60,60),0.15},
        chamsFInno={Color3.new(1,1,1),0.55}, chamsOInno={Color3.new(1,1,1),0.15},
        chamsFShf={Color3.fromRGB(0,153,255),0.55}, chamsOShf={Color3.fromRGB(0,153,255),0.15},
        chamsFHero={Color3.fromRGB(255,215,0),0.55}, chamsOHero={Color3.fromRGB(255,215,0),0.15},
        matChams=false, matType="ForceField", matColMur=Color3.fromRGB(255,60,60),
        matColInno=Color3.new(1,1,1), matColShf=Color3.fromRGB(0,153,255), matColHero=Color3.fromRGB(255,215,0),
        flags=false, flagMur={Color3.fromRGB(255,60,60),1}, flagShf={Color3.fromRGB(0,153,255),1}, flagHero={Color3.fromRGB(255,215,0),1},
        arrows=false, arrowMur=Color3.fromRGB(255,60,60), arrowInno=Color3.new(1,1,1),
        arrowShf=Color3.fromRGB(0,153,255), arrowHero=Color3.fromRGB(255,215,0),
        arrowSize=42, arrowDist=260, maxDist=500, allowLocal=false,
        gunEspOn=false, gunTextOn=false, gunTextCol=Color3.new(1,1,1),
        gunHlOn=false, gunHlCol=Color3.new(1,1,1),
    }
    _G.FH_ESP = espState
    local drawCache = {}
    local chamsFolder = Instance.new("Folder") chamsFolder.Name = "FH_Chams" chamsFolder.Parent = Workspace
    local gunFolder = Instance.new("Folder") gunFolder.Name = "FH_GunChams" gunFolder.Parent = Workspace

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
        d = {box={}, boxFill=nil, name=nil, dist=nil, avatar=nil, skel={}, flags={}, arrow=nil}
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
        local t = math.sin(os.clock()*3)*0.5 + 0.5
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
        if h then
            pcall(function() h:Destroy() end)
            chams[p] = nil
        end
    end
    local function ensureCham(p, char)
        local h = chams[p]
        if h and h.Parent and h.Adornee == char then return h end
        if h then pcall(function() h:Destroy() end) end
        h = Instance.new("Highlight")
        h.Name = "FH_"..p.Name
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
                        if not matCache[part] then matCache[part] = {m=part.Material, c=part.Color} end
                        pcall(function() part.Material = mat end)
                        pcall(function() part.Color = col end)
                    end
                end
            end
        end
    end

    -- ESP рендер
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
                    local fade = math.clamp(1 - dist/espState.maxDist, 0.15, 1)
                    if espState.enabled then
                        local headPos = head.Position + Vector3.new(0, head.Size.Y*0.5, 0)
                        local footPos = hrp.Position - Vector3.new(0, hrp.Size.Y*0.5 + (hum.HipHeight or 0), 0)
                        local hsp,hon = Camera:WorldToViewportPoint(headPos)
                        local fsp,fon = Camera:WorldToViewportPoint(footPos)
                        if hon or fon then
                            local e = getDraw(p)
                            if espState.box then
                                local w = math.max(40, (hsp.Y-fsp.Y)*0.5)
                                local cx = (hsp.X+fsp.X)*0.5
                                local top,bot = hsp.Y, fsp.Y
                                local l,r = cx-w, cx+w
                                local col = espState.boxGrd and grad(espState.boxGrd1, espState.boxGrd2) or espState.boxCol[1]
                                local a = (espState.boxCol[2] or 1)*fade
                                if espState.boxType == "Corners" then
                                    local sg = math.min(w, bot-top)*0.25
                                    local lines = {
                                        {l,top,l+sg,top},{l,top,l,top+sg},
                                        {r,top,r-sg,top},{r,top,r,top+sg},
                                        {l,bot,l+sg,bot},{l,bot,l,bot-sg},
                                        {r,bot,r-sg,bot},{r,bot,r,bot-sg},
                                    }
                                    for i,ln in ipairs(lines) do
                                        local line = ensureBox(e, i)
                                        line.From = Vector2.new(ln[1], ln[2])
                                        line.To = Vector2.new(ln[3], ln[4])
                                        line.Color = col line.Transparency = a line.Visible = true
                                    end
                                    for i = #lines+1, #e.box do e.box[i].Visible = false end
                                else
                                    local lines = {{l,top,r,top},{r,top,r,bot},{r,bot,l,bot},{l,bot,l,top}}
                                    for i,ln in ipairs(lines) do
                                        local line = ensureBox(e, i)
                                        line.From = Vector2.new(ln[1], ln[2])
                                        line.To = Vector2.new(ln[3], ln[4])
                                        line.Color = col line.Transparency = a line.Visible = true
                                    end
                                    for i = 5, #e.box do e.box[i].Visible = false end
                                end
                            else
                                for _, ln in pairs(e.box) do ln.Visible = false end
                            end
                            if espState.name then
                                if not e.name then
                                    e.name = Drawing.new("Text")
                                    e.name.Size = 13 e.name.Center = true e.name.Outline = true
                                end
                                e.name.Text = p.Name
                                e.name.Position = Vector2.new((hsp.X+fsp.X)*0.5, hsp.Y-18)
                                e.name.Color = espState.nameCol[1]
                                e.name.Transparency = (espState.nameCol[2] or 1)*fade
                                e.name.Visible = true
                            elseif e.name then e.name.Visible = false end
                            if espState.dist then
                                if not e.dist then
                                    e.dist = Drawing.new("Text")
                                    e.dist.Size = 12 e.dist.Center = true e.dist.Outline = true
                                end
                                e.dist.Text = string.format("%d studs", math.floor(dist))
                                e.dist.Position = Vector2.new((hsp.X+fsp.X)*0.5, fsp.Y+4)
                                e.dist.Color = espState.distCol[1]
                                e.dist.Transparency = (espState.distCol[2] or 1)*fade
                                e.dist.Visible = true
                            elseif e.dist then e.dist.Visible = false end
                            if espState.avatar then
                                if not e.avatar then
                                    e.avatar = Drawing.new("Image")
                                    e.avatar.Size = Vector2.new(40,40)
                                    local av = getgenv().FH_GetAvatarFor and getgenv().FH_GetAvatarFor(p)
                                    if av then e.avatar.Data = av end
                                end
                                e.avatar.Position = Vector2.new((hsp.X+fsp.X)*0.5-20, hsp.Y-60)
                                e.avatar.Transparency = fade
                                e.avatar.Visible = true
                            elseif e.avatar then e.avatar.Visible = false end
                            if espState.skel then
                                local bones = {
                                    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
                                    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
                                    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
                                    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
                                    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
                                }
                                for i,b in ipairs(bones) do
                                    local p1 = char:FindFirstChild(b[1])
                                    local p2 = char:FindFirstChild(b[2])
                                    if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                                        local s1,o1 = Camera:WorldToViewportPoint(p1.Position)
                                        local s2,o2 = Camera:WorldToViewportPoint(p2.Position)
                                        if not e.skel[i] then
                                            local dr = Drawing.new("Line")
                                            dr.Thickness = 1 dr.Transparency = 1
                                            e.skel[i] = dr
                                        end
                                        local dr = e.skel[i]
                                        if o1 and o2 then
                                            dr.From = Vector2.new(s1.X, s1.Y)
                                            dr.To = Vector2.new(s2.X, s2.Y)
                                            dr.Color = espState.skelCol[1]
                                            dr.Transparency = (espState.skelCol[2] or 1)*fade
                                            dr.Visible = true
                                        else dr.Visible = false end
                                    elseif e.skel[i] then e.skel[i].Visible = false end
                                end
                                for i = #bones+1, #e.skel do e.skel[i].Visible = false end
                            else
                                for _, dr in pairs(e.skel) do dr.Visible = false end
                            end
                            if espState.flags then
                                local txt = role=="Mur" and "[MURD]" or (role=="Shf" and "[SHF]" or (role=="Hero" and "[HERO]" or ""))
                                if txt ~= "" then
                                    if not e.flags[1] then
                                        e.flags[1] = Drawing.new("Text")
                                        e.flags[1].Size = 13 e.flags[1].Outline = true
                                    end
                                    local dr = e.flags[1]
                                    dr.Text = txt
                                    dr.Position = Vector2.new(hsp.X+60, hsp.Y-10)
                                    dr.Color = role=="Mur" and espState.flagMur[1] or (role=="Hero" and espState.flagHero[1] or espState.flagShf[1])
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
                                    local cx,cy = vp.X*0.5, vp.Y*0.5
                                    local dir = Vector2.new(hsp.X-cx, hsp.Y-cy)
                                    if dir.Magnitude < 0.01 then dir = Vector2.new(0,1) end
                                    dir = dir.Unit
                                    local px = cx + dir.X*espState.arrowDist
                                    local py = cy + dir.Y*espState.arrowDist
                                    local sz = espState.arrowSize
                                    local perp = Vector2.new(-dir.Y, dir.X)
                                    e.arrow.PointA = Vector2.new(px+dir.X*sz*0.5, py+dir.Y*sz*0.5)
                                    e.arrow.PointB = Vector2.new(px-dir.X*sz*0.5+perp.X*sz*0.5, py-dir.Y*sz*0.5+perp.Y*sz*0.5)
                                    e.arrow.PointC = Vector2.new(px-dir.X*sz*0.5-perp.X*sz*0.5, py-dir.Y*sz*0.5-perp.Y*sz*0.5)
                                    e.arrow.Color = role=="Mur" and espState.arrowMur or (role=="Shf" and espState.arrowShf or (role=="Hero" and espState.arrowHero or espState.arrowInno))
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
                        if e.avatar then e.avatar.Visible = false end
                        for _, dr in pairs(e.skel) do dr.Visible = false end
                        for _, dr in pairs(e.flags) do dr.Visible = false end
                        if e.arrow then e.arrow.Visible = false end
                    end
                    killCham(p)
                end
            end
        end
        for p,e in pairs(drawCache) do
            if not seen[p] then dispose(e) drawCache[p] = nil end
        end
        updateMatChams()
    end)

    Players.PlayerRemoving:Connect(function(p) killCham(p) end)

    local tV = Tabs.Visual
    local espSec = tV:AddSection({Name="ESP Игроков"})
    addOpt(espSec, "AddToggle", "ESPOn", {Title="Включить ESP", Default=false}, function(v)
        espState.enabled = v
        if not v then
            for _, e in pairs(drawCache) do dispose(e) end
            drawCache = {}
        end
    end)
    addOpt(espSec, "AddToggle", "ESPBox", {Title="Рамка", Default=false}, function(v) espState.box = v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxCol", {Title="Цвет рамки", Default=Color3.new(1,1,1)}, function(c) espState.boxCol[1] = c end)
    addOpt(espSec, "AddSlider", "ESPBoxAlpha", {Title="Прозрачность рамки", Min=0, Max=1, Default=1, Rounding=2}, function(v) espState.boxCol[2] = tonumber(v) or 1 end)
    addOpt(espSec, "AddDropdown", "ESPBoxType", {Title="Тип рамки", Values={"Прямоугольник","Уголки"}, Default="Прямоугольник"}, function(v) espState.boxType = (v == "Уголки") and "Corners" or "Static" end)
    addOpt(espSec, "AddToggle", "ESPBoxGrd", {Title="Градиент рамки", Default=false}, function(v) espState.boxGrd = v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxGrd1", {Title="Цвет 1", Default=Color3.fromRGB(255,60,60)}, function(c) espState.boxGrd1 = c end)
    addOpt(espSec, "AddColorPicker", "ESPBoxGrd2", {Title="Цвет 2", Default=Color3.fromRGB(255,180,60)}, function(c) espState.boxGrd2 = c end)
    addOpt(espSec, "AddToggle", "ESPName", {Title="Имя", Default=false}, function(v) espState.name = v end)
    addOpt(espSec, "AddToggle", "ESPDist", {Title="Дистанция", Default=false}, function(v) espState.dist = v end)
    addOpt(espSec, "AddToggle", "ESPAvatar", {Title="Аватарка", Default=false}, function(v) espState.avatar = v end)
    addOpt(espSec, "AddToggle", "ESPSkel", {Title="Скелет", Default=false}, function(v) espState.skel = v end)
    addOpt(espSec, "AddToggle", "ESPChams", {Title="Свечение", Default=false}, function(v) espState.chams = v end)
    addOpt(espSec, "AddToggle", "ESPMatChams", {Title="Материал-чамсы", Default=false}, function(v) espState.matChams = v end)
    addOpt(espSec, "AddDropdown", "ESPMatType", {Title="Материал", Values={"ForceField","Flat","Chromatic"}, Default="ForceField"}, function(v) espState.matType = v end)
    addOpt(espSec, "AddToggle", "ESPFlags", {Title="Метки ролей", Default=false}, function(v) espState.flags = v end)
    addOpt(espSec, "AddToggle", "ESPArrows", {Title="Стрелки", Default=false}, function(v) espState.arrows = v end)
    addOpt(espSec, "AddSlider", "ESPMaxDist", {Title="Макс дистанция ESP", Min=50, Max=1000, Default=500, Rounding=0}, function(v) espState.maxDist = tonumber(v) or 500 end)
    addOpt(espSec, "AddToggle", "ESPAllowLocal", {Title="Показывать себя", Default=false}, function(v) espState.allowLocal = v end)

    local camSec = tV:AddSection({Name="Камера"})
    local ratioOn, ratioValue = false, 100
    local aspectMul = CFrame.new(0,0,0,1,0,0,0,1,0,0,0,1)
    RunService:BindToRenderStep("FH_aspect", Enum.RenderPriority.Camera.Value+1, function()
        if not ratioOn then return end
        local cam = Workspace.CurrentCamera
        if cam then cam.CFrame = cam.CFrame * aspectMul end
    end)
    addOpt(camSec, "AddToggle", "AspectOn", {Title="Aspect ratio", Default=false}, function(v) ratioOn = v end)
    addOpt(camSec, "AddSlider", "AspectVal", {Title="Значение", Min=1, Max=100, Default=100, Rounding=0}, function(v)
        ratioValue = tonumber(v) or 100
        aspectMul = CFrame.new(0,0,0,1,0,0,0,ratioValue/100,0,0,0,1)
    end)
    local fovOn, fovValue, fovOrig = false, 70, nil
    RunService.RenderStepped:Connect(function()
        if not fovOn then return end
        local cam = Workspace.CurrentCamera
        if cam and cam.FieldOfView ~= fovValue then cam.FieldOfView = fovValue end
    end)
    addOpt(camSec, "AddToggle", "FovOn", {Title="Своё FOV", Default=false}, function(v)
        fovOn = v
        local cam = Workspace.CurrentCamera
        if v then
            if cam then fovOrig = cam.FieldOfView cam.FieldOfView = fovValue end
        else
            if cam and fovOrig then cam.FieldOfView = fovOrig end
        end
    end)
    addOpt(camSec, "AddSlider", "FovVal", {Title="FOV", Min=30, Max=120, Default=70, Rounding=0}, function(v)
        fovValue = tonumber(v) or 70
        if fovOn then
            local cam = Workspace.CurrentCamera
            if cam then cam.FieldOfView = fovValue end
        end
    end)
end

-- ============================================================
-- CHINA HAT (нормальная — цилиндр + конус)
-- ============================================================
do
    local lvSec = Tabs.Visual:AddSection({Name="Китайская шляпа"})
    local chOn, chCol = false, Color3.fromRGB(170,85,255)
    local chModel, chCharRef = nil, nil

    local function buildHat(char)
        if not char then return end
        local head = char:FindFirstChild("Head")
        if not head then return end
        -- удаляем старую
        if chModel then pcall(function() chModel:Destroy() end) chModel = nil end
        chCharRef = char

        local model = Instance.new("Model")
        model.Name = "FH_ChinaHat"

        -- основной купол (цилиндр)
        local cone = Instance.new("Part")
        cone.Name = "Cone"
        cone.Shape = Enum.PartType.Cylinder
        cone.Size = Vector3.new(0.4, 2.4, 2.4)
        cone.Material = Enum.Material.SmoothPlastic
        cone.Color = chCol
        cone.TopSurface = Enum.SurfaceType.Smooth
        cone.BottomSurface = Enum.SurfaceType.Smooth
        cone.CanCollide = false
        cone.CanQuery = false
        cone.CanTouch = false
        cone.Massless = true
        cone.CFrame = head.CFrame * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi/2)
        cone.Parent = model

        -- верхний конус через SpecialMesh
        local top = Instance.new("Part")
        top.Name = "Top"
        top.Shape = Enum.PartType.Ball
        top.Size = Vector3.new(0.1, 1.4, 1.4)
        top.Material = Enum.Material.SmoothPlastic
        top.Color = chCol
        top.CanCollide = false
        top.CanQuery = false
        top.CanTouch = false
        top.Massless = true
        top.CFrame = cone.CFrame * CFrame.new(0, 0.85, 0)
        top.Parent = model
        local sm = Instance.new("SpecialMesh")
        sm.MeshType = Enum.MeshType.Sphere
        sm.Scale = Vector3.new(0.15, 1, 1)
        sm.Parent = top

        -- обод
        local brim = Instance.new("Part")
        brim.Name = "Brim"
        brim.Shape = Enum.PartType.Cylinder
        brim.Size = Vector3.new(0.05, 2.6, 2.6)
        brim.Material = Enum.Material.SmoothPlastic
        brim.Color = chCol
        brim.CanCollide = false
        brim.CanQuery = false
        brim.CanTouch = false
        brim.Massless = true
        brim.CFrame = head.CFrame * CFrame.new(0, 0.95, 0) * CFrame.Angles(0, 0, math.pi/2)
        brim.Parent = model

        -- конус сверху через Mesh
        local spike = Instance.new("Part")
        spike.Name = "Spike"
        spike.Size = Vector3.new(0.5, 0.5, 0.5)
        spike.Material = Enum.Material.SmoothPlastic
        spike.Color = chCol
        spike.CanCollide = false
        spike.CanQuery = false
        spike.CanTouch = false
        spike.Massless = true
        spike.CFrame = head.CFrame * CFrame.new(0, 1.65, 0)
        spike.Parent = model
        local spikeMesh = Instance.new("SpecialMesh")
        spikeMesh.MeshType = Enum.MeshType.FileMesh
        spikeMesh.MeshId = "rbxassetid://1033714"
        spikeMesh.Scale = Vector3.new(1.6, 1.0, 1.6)
        spikeMesh.Parent = spike

        -- вельды
        for _, part in ipairs({cone, top, brim, spike}) do
            local wc = Instance.new("WeldConstraint")
            wc.Part0 = head
            wc.Part1 = part
            wc.Parent = part
        end

        model.Parent = char
        chModel = model
    end

    local function destroyHat()
        if chModel then pcall(function() chModel:Destroy() end) chModel = nil end
        chCharRef = nil
    end

    LocalPlayer.CharacterAdded:Connect(function(c)
        if chOn then
            task.wait(0.5)
            buildHat(c)
        end
    end)

    addOpt(lvSec, "AddToggle", "ChinaHatOn", {Title="Китайская шляпа", Default=false}, function(v)
        chOn = v
        if v then
            buildHat(LocalPlayer.Character)
        else
            destroyHat()
        end
    end)
    addOpt(lvSec, "AddColorPicker", "ChinaHatCol", {Title="Цвет", Default=Color3.fromRGB(170,85,255)}, function(c)
        chCol = c
        if chModel then
            for _, p in ipairs(chModel:GetDescendants()) do
                if p:IsA("BasePart") then p.Color = c end
            end
        end
    end)
end

-- ============================================================
-- BACKTRACK (Simple + Ghost)
-- ============================================================
do
    local lvSec = Tabs.Visual:AddSection({Name="Backtrack"})
    local btMode = "Simple"
    local btSimpleOn = false
    local btGhostOn = false
    local btCol = Color3.fromRGB(255,60,60)

    -- Simple Backtrack
    local btModel, btPairs = nil, {}
    local BTCAP = 120
    local btHist = {}
    local btFirst, btCount = 1, 0
    local btLastChar = nil
    local btAccum = 0

    local function btKill()
        if btModel then pcall(function() btModel:Destroy() end) btModel = nil end
        btPairs = {}
        btHist = {}
        btFirst, btCount = 1, 0
        btLastChar = nil
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
        local src = {}
        for _, o in ipairs(char:GetDescendants()) do
            if o:IsA("BasePart") then src[#src+1] = o end
        end
        local ci = 0
        for _, o in ipairs(m:GetDescendants()) do
            if o:IsA("Script") or o:IsA("LocalScript") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("Humanoid") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then
                pcall(function() o:Destroy() end)
            elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") then
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
                    o.Color = btCol
                    o.Transparency = 0.3
                end
                ci = ci + 1
                if src[ci] then
                    btPairs[#btPairs+1] = {ghost=o, real=src[ci]}
                end
            end
        end
        m.Parent = Workspace
        btModel = m
        btLastChar = char
    end

    RunService.RenderStepped:Connect(function(dt)
        if not btSimpleOn then return end
        btAccum = btAccum + dt
        if btAccum < 0.03 then return end
        btAccum = 0
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            if btModel then btKill() end
            return
        end
        if btLastChar ~= char or not btModel or not btModel.Parent then
            btBuild()
            return
        end
        local now = tick()
        local snap = {t = now, parts = {}}
        for _, p in ipairs(btPairs) do
            if p.real and p.real.Parent then
                snap.parts[p.real] = p.real.CFrame
            end
        end
        table.insert(btHist, snap)
        while #btHist > BTCAP do table.remove(btHist, 1) end
        local ping = 0.15
        pcall(function()
            local v = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
            if v == v and v > 0.01 and v < 0.6 then ping = v end
        end)
        local want = now - ping
        local chosen = nil
        for i = #btHist, 1, -1 do
            if btHist[i].t <= want then chosen = btHist[i] break end
        end
        if not chosen and #btHist > 0 then chosen = btHist[1] end
        if chosen then
            for _, p in ipairs(btPairs) do
                if p.ghost and p.ghost.Parent and chosen.parts[p.real] then
                    p.ghost.CFrame = chosen.parts[p.real]
                end
            end
        end
    end)

    -- Ghost (v2)
    local ghFolder = Workspace:FindFirstChild("FH_ClientVisuals")
    if not ghFolder then
        ghFolder = Instance.new("Folder")
        ghFolder.Name = "FH_ClientVisuals"
        ghFolder.Parent = Workspace
    end
    local ghModel, ghPairs, ghHistory, ghLastChar = nil, {}, {}, nil
    local ghCfg = {Transparency=50, Color=Color3.fromRGB(255,100,100), DeleteTexture=false, BacktrackTime=0.15}

    local function ghCleanup()
        if ghModel then pcall(function() ghModel:Destroy() end) end
        ghModel = nil ghPairs = {} ghHistory = {} ghLastChar = nil
    end
    local function ghPaint()
        if not ghModel then return end
        local tr = ghCfg.Transparency / 100
        for _, pair in ipairs(ghPairs) do
            local g = pair.ghost
            pcall(function()
                if g:IsA("BasePart") then
                    g.Transparency = tr
                    g.Color = ghCfg.Color
                    if ghCfg.DeleteTexture then
                        g.Material = Enum.Material.SmoothPlastic
                        if g:IsA("MeshPart") then g.TextureID = "" end
                    end
                end
            end)
        end
    end
    local function ghBuild(char)
        ghCleanup()
        ghLastChar = char
        char.Archivable = true
        local ok, clone = pcall(function() return char:Clone() end)
        char.Archivable = false
        if not ok or not clone then return end
        ghModel = clone
        ghModel.Name = "FH_ClientGhost"
        ghModel.Parent = ghFolder
        local hum = clone:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
        local hrp = clone:FindFirstChild("HumanoidRootPart")
        if hrp then hrp:Destroy() end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy()
            elseif d:IsA("BasePart") then
                d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false d.Massless = true
            end
        end
        ghPairs = {}
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                local g = nil
                if d.Parent == char then g = clone:FindFirstChild(d.Name)
                elseif d.Parent and d.Parent:IsA("Accessory") then
                    local acc = clone:FindFirstChild(d.Parent.Name)
                    if acc then g = acc:FindFirstChild(d.Name) end
                end
                if g and g:IsA("BasePart") then
                    table.insert(ghPairs, {real=d, ghost=g})
                end
            end
        end
        ghPaint()
    end

    RunService.RenderStepped:Connect(function()
        if not btGhostOn then
            if ghModel then ghCleanup() end
            return
        end
        local char = LocalPlayer.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then
            if ghModel then ghCleanup() end
            return
        end
        if ghLastChar ~= char then ghBuild(char) end
        if not ghModel or ghModel.Parent ~= ghFolder then return end
        local snap = {t = tick(), parts = {}}
        for _, pair in ipairs(ghPairs) do
            snap.parts[pair.real] = pair.real.CFrame
        end
        table.insert(ghHistory, snap)
        local cutoff = tick() - 2
        while #ghHistory > 0 and ghHistory[1].t < cutoff do table.remove(ghHistory, 1) end
        local wantTime = tick() - math.clamp(ghCfg.BacktrackTime, 0, 1)
        local chosen = nil
        for i = #ghHistory, 1, -1 do
            if ghHistory[i].t <= wantTime then chosen = ghHistory[i] break end
        end
        if not chosen and #ghHistory > 0 then chosen = ghHistory[1] end
        if chosen then
            for _, pair in ipairs(ghPairs) do
                if chosen.parts[pair.real] then pair.ghost.CFrame = chosen.parts[pair.real] end
            end
        end
    end)

    addOpt(lvSec, "AddDropdown", "BacktrackMode", {Title="Режим", Values={"Simple","Ghost"}, Default="Simple"}, function(v)
        btMode = v or "Simple"
        btSimpleOn = false
        btGhostOn = false
        btKill()
        ghCleanup()
    end)
    addOpt(lvSec, "AddToggle", "BacktrackOn", {Title="Backtrack (Simple)", Default=false}, function(v)
        if btMode ~= "Simple" then
            Notify("FH", "Переключи режим на Simple", 2)
            return
        end
        btSimpleOn = v
        if v then
            btHist = {}
            btBuild()
        else
            btKill()
        end
    end)
    addOpt(lvSec, "AddToggle", "GhostOn", {Title="Ghost (задержка)", Default=false}, function(v)
        if btMode ~= "Ghost" then
            Notify("FH", "Переключи режим на Ghost", 2)
            return
        end
        btGhostOn = v
        if not v then ghCleanup() end
    end)
    addOpt(lvSec, "AddColorPicker", "BacktrackCol", {Title="Цвет", Default=Color3.fromRGB(255,60,60)}, function(c)
        btCol = c
        ghCfg.Color = c
        if btModel then
            for _, p in ipairs(btModel:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.Color = c end
            end
        end
        ghPaint()
    end)
    addOpt(lvSec, "AddSlider", "GhostTransparency", {Title="Ghost прозрачность (%)", Min=0, Max=100, Default=50, Rounding=0}, function(v)
        ghCfg.Transparency = tonumber(v) or 50
        ghPaint()
    end)
    addOpt(lvSec, "AddSlider", "GhostBacktrackTime", {Title="Ghost задержка (сек)", Min=0, Max=0.8, Default=0.15, Rounding=2}, function(v)
        ghCfg.BacktrackTime = tonumber(v) or 0.15
    end)
end

-- ============================================================
-- MOV GRAPH + CROSSHAIR + SELF CHAMS + TOOL CHAMS
-- ============================================================
do
    local lvSec = Tabs.Visual:AddSection({Name="Прочее"})

    -- Mov graph
    local mgOn, mgCol = false, Color3.fromRGB(242,242,242)
    local mgWidth, mgHeight, mgOffset = 280, 72, 180
    local mgLines, mgShadows = {}, {}
    local mgCurrent = nil
    local mgHist = {}
    local mgAccum = 0
    local mgSmooth = 0
    local mgSpan, mgStep = 2.8, 1/45
    local mgConn = nil
    local function mgSpeed()
        local c = LocalPlayer.Character
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if not r then return 0 end
        local v = r.AssemblyLinearVelocity
        return Vector3.new(v.X,0,v.Z).Magnitude
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
        mgLines = {} mgShadows = {} mgHist = {} mgAccum = 0
    end
    local function mgStart()
        mgClear()
        mgSmooth = mgSpeed()
        local now = os.clock()
        local cnt = math.ceil(mgSpan/mgStep)
        for i = 0, cnt do mgHist[#mgHist+1] = {t=now-mgSpan+i*mgStep, v=mgSmooth} end
        for i = 1, 300 do
            local s = Drawing.new("Line")
            s.Color = Color3.new(0,0,0) s.Thickness = 3 s.Transparency = 0.4 s.Visible = false
            mgShadows[#mgShadows+1] = s
            local l = Drawing.new("Line")
            l.Color = mgCol l.Thickness = 1.5 l.Transparency = 1 l.Visible = false
            mgLines[#mgLines+1] = l
        end
        mgConn = RunService.RenderStepped:Connect(function(dt)
            if not mgOn then
                for i = 1, #mgLines do mgLines[i].Visible = false mgShadows[i].Visible = false end
                if mgCurrent then mgCurrent.Visible = false end
                return
            end
            local raw = mgSpeed()
            mgSmooth = mgSmooth + (raw - mgSmooth)*(1 - math.exp(-dt*18))
            mgAccum = mgAccum + dt
            local now2 = os.clock()
            if mgAccum >= mgStep then
                mgAccum = mgAccum % mgStep
                mgHist[#mgHist+1] = {t=now2, v=mgSmooth}
                local cutoff = now2 - mgSpan
                while #mgHist > 2 and mgHist[2].t < cutoff do table.remove(mgHist, 1) end
            end
            local vp = Camera.ViewportSize
            local w = math.min(mgWidth, math.max(120, vp.X-48))
            local h = math.min(mgHeight, math.max(36, vp.Y-32))
            local left = math.floor(vp.X*0.5 - w*0.5)
            local center = math.clamp(math.floor(vp.Y*0.5 + mgOffset), h*0.5+8, vp.Y-h*0.5-8)
            local ref = mgRef()
            local startT = now2 - mgSpan
            local count = #mgHist
            for i = 1, count-1 do
                local a,b = mgHist[i], mgHist[i+1]
                local ap = math.clamp((a.t-startT)/mgSpan, 0, 1)
                local bp = math.clamp((b.t-startT)/mgSpan, 0, 1)
                local fade = math.clamp(math.min((ap+bp)*6, (2-ap-bp)*5), 0, 1)
                local ay = center - (math.clamp(a.v/ref-1, -1, 1))*h*0.44
                local by = center - (math.clamp(b.v/ref-1, -1, 1))*h*0.44
                local from = Vector2.new(left+ap*w, ay)
                local to = Vector2.new(left+bp*w, by)
                if mgLines[i] then
                    mgLines[i].From = from
                    mgLines[i].To = to
                    mgLines[i].Transparency = fade
                    mgLines[i].Visible = fade > 0.02
                    mgLines[i].Color = mgCol
                    mgShadows[i].From = from
                    mgShadows[i].To = to
                    mgShadows[i].Transparency = fade*0.42
                    mgShadows[i].Visible = fade > 0.02
                end
            end
            for i = count, #mgLines do
                mgLines[i].Visible = false mgShadows[i].Visible = false
            end
            if not mgCurrent then
                mgCurrent = Drawing.new("Text")
                mgCurrent.Center = false mgCurrent.Outline = true mgCurrent.Size = 12
            end
            mgCurrent.Text = tostring(math.floor(mgSmooth+0.5))
            mgCurrent.Position = Vector2.new(left+w+5, center-7)
            mgCurrent.Color = mgCol
            mgCurrent.Visible = true
        end)
    end
    addOpt(lvSec, "AddToggle", "MovGraphOn", {Title="График скорости", Default=false}, function(v)
        mgOn = v
        if v then mgStart() else mgClear() end
    end)
    addOpt(lvSec, "AddColorPicker", "MovGraphCol", {Title="Цвет графика", Default=Color3.fromRGB(242,242,242)}, function(c)
        mgCol = c
        for i = 1, #mgLines do mgLines[i].Color = c end
    end)

    -- Crosshair
    local chOn2, chCol2 = false, Color3.new(1,1,1)
    local chLines = {}
    for i = 1, 4 do
        local l = Drawing.new("Line")
        l.Thickness = 2 l.Color = chCol2 l.Visible = false
        chLines[i] = l
    end
    RunService.RenderStepped:Connect(function()
        if not chOn2 then
            for i = 1, #chLines do chLines[i].Visible = false end
            return
        end
        local mp = UserInputService:GetMouseLocation()
        local gap,len = 4,8
        local cx,cy = mp.X,mp.Y
        local arr = {
            {cx,cy-gap,cx,cy-gap-len},
            {cx,cy+gap,cx,cy+gap+len},
            {cx-gap,cy,cx-gap-len,cy},
            {cx+gap,cy,cx+gap+len,cy},
        }
        for i = 1, 4 do
            local a = arr[i]
            chLines[i].From = Vector2.new(a[1], a[2])
            chLines[i].To = Vector2.new(a[3], a[4])
            chLines[i].Color = chCol2
            chLines[i].Visible = true
        end
    end)
    addOpt(lvSec, "AddToggle", "CrosshairOn", {Title="Прицел", Default=false}, function(v)
        chOn2 = v
        pcall(function() UserInputService.MouseIconEnabled = not v end)
    end)
    addOpt(lvSec, "AddColorPicker", "CrosshairCol", {Title="Цвет прицела", Default=Color3.new(1,1,1)}, function(c) chCol2 = c end)

    -- Self Chams
    local scOn, scType, scCol = false, "ForceField", Color3.fromRGB(0,200,255)
    local scCache, scConn = {}, nil
    local function scRestore()
        if scConn then pcall(function() scConn:Disconnect() end) scConn = nil end
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
    addOpt(lvSec, "AddToggle", "SelfChamsOn", {Title="Чамсы на себе", Default=false}, function(v)
        scOn = v
        if v then
            if not scConn then
                scConn = RunService.Heartbeat:Connect(function() if scOn then scApply() end end)
            end
        else
            scRestore()
        end
    end)
    addOpt(lvSec, "AddDropdown", "SelfChamsType", {Title="Пресет себе", Values={"ForceField","Flat","Chromatic"}, Default="ForceField"}, function(v) scType = v end)
    addOpt(lvSec, "AddColorPicker", "SelfChamsCol", {Title="Цвет себе", Default=Color3.fromRGB(0,200,255)}, function(c) scCol = c end)

    -- Tool Chams
    local tcOn, tcType, tcCol = false, "ForceField", Color3.fromRGB(255,200,0)
    local tcCache, tcConn = {}, nil
    local function tcRestore()
        if tcConn then pcall(function() tcConn:Disconnect() end) tcConn = nil end
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
    addOpt(lvSec, "AddToggle", "ToolChamsOn", {Title="Чамсы оружия", Default=false}, function(v)
        tcOn = v
        if v then
            if not tcConn then
                tcConn = RunService.Heartbeat:Connect(function() if tcOn then tcApply() end end)
            end
        else
            tcRestore()
        end
    end)
    addOpt(lvSec, "AddDropdown", "ToolChamsType", {Title="Пресет оружия", Values={"ForceField","Flat","Chromatic"}, Default="ForceField"}, function(v) tcType = v end)
    addOpt(lvSec, "AddColorPicker", "ToolChamsCol", {Title="Цвет оружия", Default=Color3.fromRGB(255,200,0)}, function(c) tcCol = c end)
end

-- ============================================================
-- ЭФФЕКТЫ (Tracer, Aura 2.0, FX, World, Murder Death)
-- ============================================================
do
    local tE = Tabs.Effects

    -- Tracer
    local tracerSec = tE:AddSection({Name="Трассер пули"})
    local tracerOn, tracerCol, tracerDur = false, Color3.fromRGB(133,220,255), 1
    local function makePoint(pos, life)
        local pt = Instance.new("Part")
        pt.Transparency = 1
        pt.Anchored = true
        pt.CanCollide = false
        pt.CanQuery = false
        pt.Size = Vector3.new(1,1,1)
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
        local p1 = makePoint(sp, tracerDur+0.5)
        local p2 = makePoint(ep, tracerDur+0.5)
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
    addOpt(tracerSec, "AddToggle", "TracerOn", {Title="Включить трассер", Default=false}, function(v)
        tracerOn = v
        if v then connectTracer() end
    end)
    addOpt(tracerSec, "AddColorPicker", "TracerCol", {Title="Цвет трассера", Default=Color3.fromRGB(133,220,255)}, function(c) tracerCol = c end)
    addOpt(tracerSec, "AddSlider", "TracerDur", {Title="Длительность", Min=0.1, Max=5, Default=1, Rounding=1}, function(v) tracerDur = tonumber(v) or 1 end)

    -- Aura 2.0 (С СОХРАНЕНИЕМ ПОСЛЕ СМЕРТИ)
    local auraSec = tE:AddSection({Name="Aura 2.0"})
    local auraActive = nil
    local auraLastAssetId = nil
    local auraLastColor = nil

    local AURA_PRESETS = {
        ["Angel Wings"]="97658130917593",
        ["Starlight"]="134645216613107",
        ["Heavenly"]="139300897520961",
        ["Ribbon"]="132069507632161",
        ["Sakura"]="81755778619404",
        ["Wind"]="80694081850877",
        ["Flow"]="119913533725648",
        ["Star"]="73754563740680",
        ["Midnight Blues"]="12002206611",
        ["Rainbow Effect"]="8509695714",
        ["Red Shield"]="14598330167",
        ["Crimson King"]="11955208820",
        ["Daemon of Cards"]="10373359918",
    }
    local AURA_NAMES = {}
    for k in pairs(AURA_PRESETS) do AURA_NAMES[#AURA_NAMES+1] = k end
    table.sort(AURA_NAMES)

    local function clearAura()
        if auraActive then
            for _, obj in ipairs(auraActive) do
                if obj and obj.Parent then pcall(function() obj:Destroy() end) end
            end
        end
        auraActive = nil
    end

    local function applyAura(assetId, color)
        clearAura()
        local ok, objs = pcall(function() return game:GetObjects("rbxassetid://"..tostring(assetId)) end)
        if not ok or type(objs) ~= "table" or #objs == 0 then
            Notify("FH", "Не удалось загрузить ауру", 3)
            return
        end
        local model = objs[1]
        local char = LocalPlayer.Character
        if not char then return end
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if not torso then return end
        local tracked = {}
        local mult = 1
        -- Обрабатываем Particles/Beams/Highlights
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("ParticleEmitter") then
                d.LightEmission = 1
                d.Rate = math.clamp(d.Rate * 0.35, 1, 40)
                if color then d.Color = ColorSequence.new(color) end
            elseif d:IsA("Beam") then
                d.LightEmission = 1
                if color then d.Color = ColorSequence.new(color) end
            elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
                if color then d.Color = color end
            end
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Highlight") or d:IsA("Attachment") then
                local cl = d:Clone()
                if color and (cl:IsA("ParticleEmitter") or cl:IsA("Beam")) then
                    cl.Color = ColorSequence.new(color)
                elseif color and cl:IsA("Highlight") then
                    cl.FillColor = color
                    cl.OutlineColor = color
                end
                cl.Parent = torso
                tracked[#tracked+1] = cl
            end
        end
        model:Destroy()
        auraActive = tracked
    end

    -- авто-восстановление при респавне
    LocalPlayer.CharacterAdded:Connect(function()
        if auraLastAssetId and (Options.Aura2On and Options.Aura2On.Value) then
            task.wait(1)
            applyAura(auraLastAssetId, auraLastColor)
        end
    end)

    addOpt(auraSec, "AddToggle", "Aura2On", {Title="Включить Aura 2.0", Default=false}, function(v)
        if v then
            local name = Options.Aura2Pick and Options.Aura2Pick.Value
            if type(name) == "table" then name = name[1] end
            local id = AURA_PRESETS[name]
            if id then
                auraLastAssetId = id
                applyAura(id, auraLastColor)
            end
        else
            clearAura()
            auraLastAssetId = nil
        end
    end)
    addOpt(auraSec, "AddDropdown", "Aura2Pick", {Title="Выбрать ауру", Values=AURA_NAMES, Default=AURA_NAMES[1] or "Angel Wings"}, function(v)
        local id = AURA_PRESETS[v]
        if id then
            auraLastAssetId = id
            if Options.Aura2On and Options.Aura2On.Value then
                applyAura(id, auraLastColor)
            end
        end
    end)
    addOpt(auraSec, "AddColorPicker", "Aura2Col", {Title="Цвет ауры (опционально)", Default=Color3.fromRGB(255,255,255)}, function(c)
        auraLastColor = c
        if auraLastAssetId and Options.Aura2On and Options.Aura2On.Value then
            applyAura(auraLastAssetId, c)
        end
    end)

    -- FX Snow/Sakura
    local fxSec = tE:AddSection({Name="Эффекты мира"})
    local fxOn, fxType, fxCol, fxRate = false, "Snow", Color3.fromRGB(150,200,255), 250
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
            e.Lifetime = NumberRange.new(4,6)
            e.Speed = NumberRange.new(6,12)
            e.Acceleration = Vector3.new(2,-6,1)
            e.SpreadAngle = Vector2.new(35,35)
            e.Rotation = NumberRange.new(0,360)
            e.RotSpeed = NumberRange.new(-40,40)
            e.Size = NumberSequence.new(0.55)
            e.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,0.2),
                NumberSequenceKeypoint.new(0.8,0.3),
                NumberSequenceKeypoint.new(1,1),
            })
        else
            e.Lifetime = NumberRange.new(5,7)
            e.Speed = NumberRange.new(5,10)
            e.Acceleration = Vector3.new(4,-5,2)
            e.SpreadAngle = Vector2.new(40,40)
            e.Rotation = NumberRange.new(0,360)
            e.RotSpeed = NumberRange.new(-80,80)
            e.Size = NumberSequence.new(0.5)
            e.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0,0.15),
                NumberSequenceKeypoint.new(0.85,0.25),
                NumberSequenceKeypoint.new(1,1),
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
        fxPart.Size = Vector3.new(260,140,260)
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
            local flat = Vector3.new(d.X,0,d.Z)
            if flat.Magnitude < 0.05 then flat = Vector3.new(0,0,-1) else flat = flat.Unit end
            fxPart.CFrame = CFrame.new(cf.Position + flat*57 + Vector3.new(0,44,0))
        end)
    end
    addOpt(fxSec, "AddToggle", "FXOn", {Title="Включить эффекты", Default=false}, function(v)
        fxOn = v
        if v then startFX() else stopFX() end
    end)
    addOpt(fxSec, "AddDropdown", "FXType", {Title="Тип", Values={"Снег","Сакура"}, Default="Снег"}, function(v)
        fxType = (v == "Сакура") and "Sakura" or "Snow"
        if fxOn then styleFX() end
    end)
    addOpt(fxSec, "AddColorPicker", "FXCol", {Title="Цвет", Default=Color3.fromRGB(150,200,255)}, function(c)
        fxCol = c
        if fxEmit then fxEmit.Color = ColorSequence.new(c) end
    end)
    addOpt(fxSec, "AddSlider", "FXRate", {Title="Интенсивность", Min=20, Max=900, Default=250, Rounding=1}, function(v)
        fxRate = tonumber(v) or 250
        if fxEmit then styleFX() end
    end)

    -- World
    local wSec = tE:AddSection({Name="Мир"})
    local orig = {
        Amb=Lighting.Ambient, Br=Lighting.Brightness, CT=Lighting.ClockTime,
        Exp=Lighting.ExposureCompensation,
        FC=Lighting.FogColor, FS=Lighting.FogStart, FE=Lighting.FogEnd,
        OA=Lighting.OutdoorAmbient, GS=Lighting.GlobalShadows,
    }
    addOpt(wSec, "AddToggle", "FBOn", {Title="Fullbright", Default=false}, function(v)
        if v then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
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
    addOpt(wSec, "AddToggle", "TimeOn", {Title="Своё время", Default=false}, function(v)
        timeOn = v
        Lighting.ClockTime = v and timeVal or orig.CT
    end)
    addOpt(wSec, "AddSlider", "TimeVal", {Title="Час", Min=0, Max=24, Default=12, Rounding=0}, function(v)
        timeVal = tonumber(v) or 12
        if timeOn then Lighting.ClockTime = timeVal end
    end)
    local fogOn, fogCol, fogStart, fogEnd = false, Color3.fromRGB(192,192,192), 0, 1000
    addOpt(wSec, "AddToggle", "FogOn", {Title="Свой туман", Default=false}, function(v)
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
    addOpt(wSec, "AddColorPicker", "FogCol", {Title="Цвет тумана", Default=Color3.fromRGB(192,192,192)}, function(c)
        fogCol = c
        if fogOn then Lighting.FogColor = c end
    end)
    addOpt(wSec, "AddSlider", "FogStart", {Title="Начало", Min=0, Max=1000, Default=0, Rounding=0}, function(v)
        fogStart = tonumber(v) or 0
        if fogOn then Lighting.FogStart = fogStart end
    end)
    addOpt(wSec, "AddSlider", "FogEnd", {Title="Конец", Min=0, Max=1000, Default=1000, Rounding=0}, function(v)
        fogEnd = tonumber(v) or 1000
        if fogOn then Lighting.FogEnd = fogEnd end
    end)

    -- Смерть убийцы
    local meSec = tE:AddSection({Name="Смерть убийцы"})
    local mOn, mCloneOn, mPartOn = false, false, false
    local mCloneCol = Color3.fromRGB(255,0,0)
    local mPartCol = Color3.fromRGB(255,0,0)
    local mCloneDur = 3
    local mClones, mConns, mRoles = {}, {}, {}
    local mThread = nil
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
            elseif d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
                pcall(function() d:Destroy() end)
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("PointLight") or d:IsA("Highlight") then
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
    local function spawnParticles(char)
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                local emitter = Instance.new("ParticleEmitter")
                emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
                emitter.Rate = 50
                emitter.Lifetime = NumberRange.new(0.5, 1)
                emitter.Speed = NumberRange.new(5, 10)
                emitter.SpreadAngle = Vector2.new(180, 180)
                emitter.Color = ColorSequence.new(mPartCol)
                emitter.LightEmission = 0.5
                emitter.Parent = p
                Debris:AddItem(emitter, 1.5)
            end
        end
    end
    local function onMurderDeath(char)
        if mCloneOn then makeClone(char) end
        if mPartOn then spawnParticles(char) end
    end
    local function hookPlayer(pl)
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if not hum then return end
            mConns[#mConns+1] = hum.Died:Connect(function()
                if mOn and mRoles[pl.Name] == "Murderer" then
                    onMurderDeath(char)
                end
            end)
        end
        if pl.Character then task.spawn(onChar, pl.Character) end
        mConns[#mConns+1] = pl.CharacterAdded:Connect(onChar)
    end
    local function stopMurder()
        for _, c in ipairs(mConns) do pcall(function() c:Disconnect() end) end
        mConns = {}
        for _, c in ipairs(mClones) do pcall(function() c:Destroy() end) end
        mClones = {}
    end
    addOpt(meSec, "AddToggle", "MEOn", {Title="Включить эффект", Default=false}, function(v)
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
        else
            stopMurder()
            if mThread then pcall(function() task.cancel(mThread) end) mThread = nil end
        end
    end)
    addOpt(meSec, "AddToggle", "MEClone", {Title="Клон", Default=false}, function(v) mCloneOn = v end)
    addOpt(meSec, "AddColorPicker", "MECloneCol", {Title="Цвет клона", Default=Color3.fromRGB(255,0,0)}, function(c) mCloneCol = c end)
    addOpt(meSec, "AddSlider", "MECloneDur", {Title="Длительность клона", Min=1, Max=5, Default=3, Rounding=1}, function(v) mCloneDur = tonumber(v) or 3 end)
    addOpt(meSec, "AddToggle", "MEPart", {Title="Частицы", Default=false}, function(v) mPartOn = v end)
    addOpt(meSec, "AddColorPicker", "MEPartCol", {Title="Цвет частиц", Default=Color3.fromRGB(255,0,0)}, function(c) mPartCol = c end)
end

-- ============================================================
-- АВТОФАРМ (Basic / Down)
-- ============================================================
do
    local tF = Tabs.Farm
    local farmSec = tF:AddSection({Name="Автофарм"})

    local active = false
    local mode = "Basic"
    local speed = 23
    local avoid = false
    local fullAction = "Respawn"
    local DOWN_DEPTH = 14
    local AVOID_DIST = 40
    local RISE_SAFE_DIST = 20
    local ncCache = {}
    local farmTarget = nil
    local coinsDone, sawCoins = false, false
    local lastTouch = 0
    local wasDown = false
    local downRefY = nil
    local currentModeLabel = "Basic"

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
            and not v:GetAttribute("Collected")
            and not v:GetAttribute("Delete")
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
            if d < bd then
                bd = d
                b = v
            end
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
    local function release()
        if wasDown then
            wasDown = false
            returnToSurface()
        end
        setNoclip(false)
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
        return Vector3.new(a.X-b.X, 0, a.Z-b.Z).Magnitude
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
            if v:IsA("BasePart") then targets[#targets+1] = v end
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
            if md > fd then
                fd = md
                far = v
            end
            if md >= AVOID_DIST then
                local d = (v.Position - pos).Magnitude
                if d < sd then
                    sd = d
                    safe = v
                end
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
        local away = Vector3.new(cur.X-mpos.X, 0, cur.Z-mpos.Z)
        if away.Magnitude < 0.1 then away = Vector3.new(1,0,0) end
        away = away.Unit
        local want = Vector3.new(dest.X-cur.X, 0, dest.Z-cur.Z)
        local mag = want.Magnitude
        if mag < 0.1 then return dest end
        local w = 1 + (1 - dm/AVOID_DIST) * 2
        local blend = (want.Unit + away*w)
        if blend.Magnitude < 0.1 then blend = away else blend = blend.Unit end
        local np = cur + blend*mag
        return Vector3.new(np.X, dest.Y, np.Z)
    end
    local function farmMove(my, dest, dt)
        local dir = dest - my.Position
        local dist = dir.Magnitude
        local np = dest
        if dist > 0.1 then
            np = my.Position + dir.Unit * math.min(speed*dt, dist)
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
    local function fireFullAction()
        if fullAction == "Respawn" then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health = 0 end) end
        end
    end
    local CONFLICT_OPTS = {"KAOn","SilentEnabled","AutoGrabGun","FreezeToggle","Noclip","Spinbot","BhopOn","InfJump","FlyToggle"}
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
        if next(savedConflicts) then Notify("FH", "Конфликтующие функции отключены", 3) end
    end
    local function restoreConflicts()
        for name, _ in pairs(savedConflicts) do
            local opt = Options[name]
            if opt then pcall(function() opt:SetValue(true) end) end
        end
        if next(savedConflicts) then Notify("FH", "Функции восстановлены", 2) end
        savedConflicts = {}
    end

    RunService.Stepped:Connect(function(_, dt)
        if not active then return end
        if not canFarm() then
            farmTarget = nil
            release()
            return
        end
        local my = hrp()
        if not my then return end
        local list = coinList()
        local function finish()
            farmTarget = nil
            release()
            if not coinsDone then
                coinsDone = true
                fireFullAction()
            end
        end
        if sawCoins and bagsFull() then
            finish()
            return
        end
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
                    local safeToRise = (not mpos) or flatDist(my.Position, mpos) > RISE_SAFE_DIST
                    if xz <= 4 and safeToRise then
                        dest = cpos
                        fireTouch(farmTarget)
                    else
                        dest = Vector3.new(cpos.X, cpos.Y - DOWN_DEPTH, cpos.Z)
                    end
                else
                    if (cpos - my.Position).Magnitude <= 6 then
                        fireTouch(farmTarget)
                    end
                end
                dest = avoidSteer(my.Position, dest, mpos)
                farmMove(my, dest, dt)
            elseif mpos then
                setNoclip(true)
                local away = Vector3.new(my.Position.X - mpos.X, 0, my.Position.Z - mpos.Z)
                if away.Magnitude < 0.1 then away = Vector3.new(1,0,0) end
                away = away.Unit
                local y = my.Position.Y
                if mode == "Down" and downRefY then
                    y = downRefY - DOWN_DEPTH
                end
                farmMove(my, my.Position + away*40 + Vector3.new(0, y - my.Position.Y, 0), dt)
            end
        else
            farmTarget = nil
            release()
            if sawCoins and not coinsDone then
                finish()
            end
        end
    end)

    addOpt(farmSec, "AddToggle", "FarmV3On", {Title="Включить автофарм", Default=false}, function(v)
        active = v
        if v then disableConflicts() else restoreConflicts() release() end
        resetProgress()
    end)
    addOpt(farmSec, "AddDropdown", "FarmV3Mode", {Title="Режим фарма", Values={"Basic","Down"}, Default="Basic"}, function(v)
        if v ~= "Basic" and v ~= "Down" then v = "Basic" end
        if mode == v then return end
        mode = v
        currentModeLabel = v
        farmTarget = nil
        if mode == "Basic" and wasDown then
            wasDown = false
            returnToSurface()
        end
        Notify("FH", "Режим фарма: "..mode, 2)
    end)
    addOpt(farmSec, "AddSlider", "FarmV3Speed", {Title="Скорость", Min=5, Max=60, Default=23, Rounding=1}, function(v) speed = tonumber(v) or 23 end)
    addOpt(farmSec, "AddToggle", "FarmV3Avoid", {Title="Избегать маньяка", Default=false}, function(v) avoid = v farmTarget = nil end)
    addOpt(farmSec, "AddDropdown", "FarmFullAction", {Title="При полном мешке", Values={"Respawn","Nothing"}, Default="Respawn"}, function(v) fullAction = v or "Respawn" end)

    getgenv().FARMV3_UNLOAD = function()
        active = false
        farmTarget = nil
        release()
        restoreConflicts()
    end
end

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
do
    local tU = Tabs.Utility

    -- Notify
    local notifySec = tU:AddSection({Name="Уведомления"})
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
                    Notify("FH", "Роль: "..ru, 4)
                elseif not r then
                    lastRole = nil
                end
            end
        end
    end)
    addOpt(notifySec, "AddToggle", "NotifyOn", {Title="Включить", Default=false}, function(v) notifyOn = v end)
    addOpt(notifySec, "AddToggle", "NotifyRoles", {Title="Показывать роль", Default=false}, function(v) rolesOn = v end)

    -- Invisible
    local invisSec = tU:AddSection({Name="Невидимость"})
    local invis = {
        active=false, realCF=nil, hbConn=nil, bindName="FH_InvisClient",
        savedLTM={}, savedDecals={}, savedFallenHeight=nil,
    }
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
        invis.savedLTM = {} invis.savedDecals = {}
    end
    local function invisBegin()
        if invis.active then return end
        local char = LocalPlayer.Character
        if not char then Notify("FH", "Персонаж не загружен", 2) return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then Notify("FH", "Персонаж не загружен", 2) return end
        invis.savedLTM = {} invis.savedDecals = {}
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
        RunService:BindToRenderStep(invis.bindName, Enum.RenderPriority.Camera.Value-1, function()
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
        if invis.hbConn then pcall(function() invis.hbConn:Disconnect() end) invis.hbConn = nil end
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
    addOpt(invisSec, "AddToggle", "InvisOn", {Title="Включить невидимость", Default=false}, function(v)
        if v then invisBegin() else invisEnd() end
    end)
    getgenv().INVIS_UNLOAD = function() if invis.active then invisEnd() end end

    -- UI Sounds
    local UISoundIds = {
        ["Enable 1"] = "rbxassetid://100772509583336",
        ["Sparkle"] = "rbxassetid://110241936966089",
        ["Laser Click"] = "rbxassetid://18913006341",
        ["Enable 2"] = "rbxassetid://84626036868067",
        ["Notify"] = "rbxassetid://103421304020039",
    }
    local uiCfg = {Enabled=true, EnableSound="Enable 1", DisableSound="Enable 1"}
    local function playUISound(id)
        if not id then return end
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = 1
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 5)
        end)
    end
    local uiSoundSec = tU:AddSection({Name="UI Sounds"})
    addOpt(uiSoundSec, "AddToggle", "FH_UISoundsOn", {Title="Звуки интерфейса", Default=true}, function(v)
        if v then
            uiCfg.Enabled = true
            playUISound(UISoundIds[uiCfg.EnableSound])
        else
            playUISound(UISoundIds[uiCfg.DisableSound])
            uiCfg.Enabled = false
        end
    end)
    addOpt(uiSoundSec, "AddDropdown", "FH_UISoundEnable", {Title="Звук включения",
        Values={"Enable 1","Sparkle","Laser Click","Enable 2","Notify"}, Default="Enable 1"}, function(v)
        uiCfg.EnableSound = v or "Enable 1"
        if uiCfg.Enabled then playUISound(UISoundIds[uiCfg.EnableSound]) end
    end)
    addOpt(uiSoundSec, "AddDropdown", "FH_UISoundDisable", {Title="Звук выключения",
        Values={"Enable 1","Sparkle","Laser Click","Enable 2","Notify"}, Default="Enable 1"}, function(v)
        uiCfg.DisableSound = v or "Enable 1"
        if uiCfg.Enabled then playUISound(UISoundIds[uiCfg.DisableSound]) end
    end)
end

-- ============================================================
-- ТРОЛЛИНГ (Fake Death — АНИМАЦИЯ, Fling Tool, TP Tool, Vote Duper)
-- ============================================================
do
    local tT = Tabs.Troll

    -- FAKE DEATH (через Animate, без респавна)
    local fdSec = tT:AddSection({Name="Fake Death"})
    local fakeDeathActive = false
    local fakeDeathToken = 0

    local FAKE_DEATH_ID_R15 = "rbxassetid://3333484302"
    local FAKE_DEATH_ID_R6 = "rbxassetid://3333484302"

    local function stopFakeDeath()
        fakeDeathToken = fakeDeathToken + 1
        fakeDeathActive = false
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        -- Останавливаем анимацию
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                pcall(function()
                    if track.Animation and tostring(track.Animation.AnimationId):find("3333484302") then
                        track:Stop(0.2)
                    end
                end)
            end
        end
        -- Восстанавливаем Animate
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = false end
    end

    local function startFakeDeath()
        stopFakeDeath()
        local myToken = fakeDeathToken
        local char = LocalPlayer.Character
        if not char then Notify("FH", "Нет персонажа", 2) return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then Notify("FH", "Нет Humanoid", 2) return end
        -- Определяем R6/R15
        local isR6 = char:FindFirstChild("Torso") ~= nil
            or (hum.RigType == Enum.HumanoidRigType.R6)
        -- Отключаем стандартный Animate
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        -- Загружаем анимацию
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        local anim = Instance.new("Animation")
        anim.AnimationId = isR6 and FAKE_DEATH_ID_R6 or FAKE_DEATH_ID_R15
        local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
        if not ok or not track then
            Notify("FH", "Не удалось загрузить анимацию", 2)
            if animate then animate.Disabled = false end
            return
        end
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = true
        pcall(function() track:Play(0.1) end)
        fakeDeathActive = true
        Notify("FH", "Fake Death ON (анимация)", 2)
        -- Авто-выключение по таймеру
        task.delay(2.5, function()
            if myToken == fakeDeathToken and fakeDeathActive then
                stopFakeDeath()
                Notify("FH", "Fake Death OFF", 2)
            end
        end)
    end

    addOpt(fdSec, "AddToggle", "FakeDeathOn", {Title="Fake Death (анимация)", Default=false}, function(v)
        if v then startFakeDeath() else stopFakeDeath() end
    end)
    fdSec:AddButton({Title="Trigger Fake Death (2 сек)", Callback=function()
        startFakeDeath()
    end})
    fdSec:AddButton({Title="Stop Fake Death", Callback=function()
        stopFakeDeath()
    end})

    -- VOTE DUPER с выбором пэда + быстрее
    local vdSec = tT:AddSection({Name="Vote Duper"})
    local selectedVotePad = nil
    local voteDupeEnabled = false
    local DELAY_ON_PAD = 0.15
    local dupeThread = nil
    local dupeCounter = 0
    local padList = {}

    local function collectPads()
        local lobby = Workspace:FindFirstChild("RegularLobby")
            or Workspace:FindFirstChild("SummerLobby")
            or Workspace:FindFirstChild("Lobby")
        if not lobby then return {} end
        local out = {}
        for _, nm in ipairs({"VotePad1","VotePad2","VotePad3"}) do
            local obj = lobby:FindFirstChild(nm)
            if obj and obj:FindFirstChild("Pad", true) then
                local mapName = ""
                pcall(function()
                    local info = obj:FindFirstChild("MapInfoGui", true)
                    local mn = info and info:FindFirstChild("MapName", true)
                    if mn then mapName = mn.Text end
                end)
                table.insert(out, {obj=obj, name=(mapName ~= "" and mapName) or nm})
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
        return nil
    end
    local function dupeLoop()
        local myToken = dupeCounter
        while voteDupeEnabled and dupeCounter == myToken do
            local visible = getVoteGuiVisible()
            if not visible then
                task.wait(0.15)
            else
                local char = LocalPlayer.Character
                local tries = 0
                while not char and voteDupeEnabled and dupeCounter == myToken and tries < 50 do
                    task.wait(0.05)
                    char = LocalPlayer.Character
                    tries = tries + 1
                end
                if not char then break end
                local hrp = char:WaitForChild("HumanoidRootPart", 5)
                local hum = char:WaitForChild("Humanoid", 5)
                if hrp and hum and hum.Health > 0 then
                    local cf = getVotePadCFrame()
                    if cf then
                        pcall(function() char:PivotTo(cf * CFrame.new(0, 1.5, 0)) end)
                        task.wait(DELAY_ON_PAD)
                        if voteDupeEnabled and dupeCounter == myToken and getVoteGuiVisible() and hum.Health > 0 then
                            hum.Health = 0
                            pcall(function() char:BreakJoints() end)
                            local tries2 = 0
                            while LocalPlayer.Character and voteDupeEnabled and dupeCounter == myToken and tries2 < 50 do
                                task.wait(0.05)
                                tries2 = tries2 + 1
                            end
                            task.wait(0.05)
                        end
                    else
                        task.wait(0.1)
                    end
                end
            end
        end
        if dupeCounter == myToken then
            dupeThread = nil
            voteDupeEnabled = false
            pcall(function()
                local o = Options.THVoteDuper
                if o then o:SetValue(false) end
            end)
        end
    end
    local function startDupe()
        if dupeThread then return end
        dupeCounter = dupeCounter + 1
        dupeThread = task.spawn(dupeLoop)
    end
    local function stopDupe()
        voteDupeEnabled = false
        dupeCounter = dupeCounter + 1
        if dupeThread then
            pcall(task.cancel, dupeThread)
            dupeThread = nil
        end
    end

    local padDrop = addOpt(vdSec, "AddDropdown", "THPadPick", {Title="Выбрать пэд для голосования", Values={"(обновить список)"}, Default="(обновить список)"}, function(v)
        for _, entry in ipairs(padList) do
            if entry.name == v then
                selectedVotePad = entry.obj
                Notify("FH", "Выбран пэд: "..v, 2)
                return
            end
        end
    end)

    vdSec:AddButton({Title="Обновить список пэдов", Callback=function()
        padList = collectPads()
        local names = {}
        for _, entry in ipairs(padList) do
            names[#names+1] = entry.name
        end
        if #names == 0 then names = {"(нет пэдов)"} end
        if padDrop then
            pcall(function()
                padDrop:SetValues(names)
                if padDrop.Generate then padDrop:Generate() end
            end)
        end
        if #padList > 0 and not selectedVotePad then
            selectedVotePad = padList[1].obj
            if padDrop then pcall(function() padDrop:SetValue(padList[1].name) end) end
        end
        Notify("FH", "Пэдов найдено: "..#padList, 2)
    end})

    addOpt(vdSec, "AddToggle", "THVoteDuper", {Title="Vote Duper", Default=false}, function(v)
        voteDupeEnabled = v
        if v then
            if not selectedVotePad then
                padList = collectPads()
                if #padList > 0 then
                    selectedVotePad = padList[1].obj
                end
            end
            startDupe()
            Notify("FH", "Vote Duper ВКЛ", 2)
        else
            stopDupe()
            Notify("FH", "Vote Duper ВЫКЛ", 2)
        end
    end)
    addOpt(vdSec, "AddSlider", "THDupeDelay", {Title="Задержка на пэде (сек)", Min=0.05, Max=1.5, Default=0.15, Rounding=2}, function(v)
        DELAY_ON_PAD = tonumber(v) or 0.15
    end)

    -- FLING TOOL с выбором режима
    local ftSec = tT:AddSection({Name="Fling Tool"})
    local flingOn = false
    local flingMode = "Once"
    local flingTool = nil
    local flingActConn = nil
    local flingAddConn = nil

    local function clickedPlayer()
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
        return nil
    end

    local function doFling(target)
        if not target or not target.Character then return end
        local hrp = getHRP()
        if not hrp then return end
        local thrp = target.Character:FindFirstChild("HumanoidRootPart")
        if not thrp then return end
        -- телепорт к цели + толчок
        pcall(function()
            hrp.CFrame = thrp.CFrame * CFrame.new(0, 1.5, 0)
            hrp.AssemblyLinearVelocity = Vector3.new(1e5, 1e5, 1e5)
        end)
        task.wait(0.05)
        pcall(function()
            thrp.AssemblyLinearVelocity = Vector3.new(1e5, 1e5, 1e5)
        end)
    end

    local function giveFlingTool()
        if not flingOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("flingtool")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("flingtool")
        end
        if existing then flingTool = existing return end
        if flingActConn then pcall(function() flingActConn:Disconnect() end) flingActConn = nil end
        flingTool = Instance.new("Tool")
        flingTool.Name = "flingtool"
        flingTool.RequiresHandle = false
        flingTool.CanBeDropped = false
        flingTool.Parent = bp
        flingActConn = flingTool.Activated:Connect(function()
            local tp = clickedPlayer()
            if not tp then return end
            if flingMode == "Once" then
                doFling(tp)
            elseif flingMode == "DeathLoop" then
                task.spawn(function()
                    for i = 1, 30 do
                        local hrp = getHRP()
                        if not hrp or not tp.Character then break end
                        doFling(tp)
                        task.wait(0.1)
                    end
                end)
            elseif flingMode == "Auto" then
                task.spawn(function()
                    for i = 1, 100 do
                        if not flingOn then break end
                        doFling(tp)
                        task.wait(0.05)
                    end
                end)
            end
        end)
    end
    local function removeFlingTool()
        if flingActConn then pcall(function() flingActConn:Disconnect() end) flingActConn = nil end
        if flingTool then pcall(function() flingTool:Destroy() end) flingTool = nil end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t = bp:FindFirstChild("flingtool") if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("flingtool") if t then pcall(function() t:Destroy() end) end end
    end

    addOpt(ftSec, "AddToggle", "FlingToolOn", {Title="Fling Tool (нажми на игрока)", Default=false}, function(v)
        flingOn = v
        if v then
            giveFlingTool()
            if not flingAddConn then
                flingAddConn = LocalPlayer.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if flingOn then giveFlingTool() end
                end)
            end
        else
            if flingAddConn then pcall(function() flingAddConn:Disconnect() end) flingAddConn = nil end
            removeFlingTool()
        end
    end)
    addOpt(ftSec, "AddDropdown", "FlingToolMode", {Title="Режим флинга", Values={"Once","DeathLoop","Auto"}, Default="Once"}, function(v)
        flingMode = v or "Once"
    end)

    -- Fling to Role (Murderer / Sheriff / All)
    local flingRoleSec = tT:AddSection({Name="Fling по роли"})
    local flingLoopOn = false
    local flingLoopThread = nil
    local flingLoopRole = "Murderer"

    local function flingLoopFunc()
        while flingLoopOn do
            local d = getRoundData()
            local targets = {}
            if type(d) == "table" then
                for name, info in pairs(d) do
                    if type(info) == "table" and not info.Dead and name ~= LocalPlayer.Name then
                        if flingLoopRole == "All"
                            or (flingLoopRole == "Murderer" and info.Role == "Murderer")
                            or (flingLoopRole == "Sheriff" and (info.Role == "Sheriff" or info.Role == "Hero"))
                            or (flingLoopRole == "Innocent" and info.Role == "Innocent") then
                            local pl = Players:FindFirstChild(name)
                            if pl then targets[#targets+1] = pl end
                        end
                    end
                end
            end
            for _, t in ipairs(targets) do
                if flingLoopOn then doFling(t) end
            end
            task.wait(0.1)
        end
        flingLoopThread = nil
    end

    addOpt(flingRoleSec, "AddToggle", "FlingRoleOn", {Title="Авто-флинг по роли", Default=false}, function(v)
        flingLoopOn = v
        if v then
            if not flingLoopThread then flingLoopThread = task.spawn(flingLoopFunc) end
        end
    end)
    addOpt(flingRoleSec, "AddDropdown", "FlingRoleTarget", {Title="Кого флингать", Values={"Murderer","Sheriff","Innocent","All"}, Default="Murderer"}, function(v)
        flingLoopRole = v or "Murderer"
    end)

    -- TP Tool
    local tpSec = tT:AddSection({Name="TP Tool"})
    local tpToolOn = false
    local tpTool = nil
    local tpActConn = nil
    local tpAddConn = nil
    local function giveTpTool()
        if not tpToolOn then return end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing = bp:FindFirstChild("tptool")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("tptool")
        end
        if existing then tpTool = existing return end
        if tpActConn then pcall(function() tpActConn:Disconnect() end) tpActConn = nil end
        tpTool = Instance.new("Tool")
        tpTool.Name = "tptool"
        tpTool.RequiresHandle = false
        tpTool.CanBeDropped = false
        tpTool.Parent = bp
        tpActConn = tpTool.Activated:Connect(function()
            local root = getHRP()
            local m = LocalPlayer:GetMouse()
            local pos = m.Hit
            if not root or not pos then return end
            root.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z, select(4, root.CFrame:components()))
        end)
    end
    local function removeTpTool()
        if tpActConn then pcall(function() tpActConn:Disconnect() end) tpActConn = nil end
        if tpTool then pcall(function() tpTool:Destroy() end) tpTool = nil end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t = bp:FindFirstChild("tptool") if t then pcall(function() t:Destroy() end) end end
        local c = LocalPlayer.Character
        if c then local t = c:FindFirstChild("tptool") if t then pcall(function() t:Destroy() end) end end
    end
    addOpt(tpSec, "AddToggle", "ToolTP", {Title="TP Tool (клик по точке)", Default=false}, function(v)
        tpToolOn = v
        if v then
            giveTpTool()
            if not tpAddConn then
                tpAddConn = LocalPlayer.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if tpToolOn then giveTpTool() end
                end)
            end
        else
            if tpAddConn then pcall(function() tpAddConn:Disconnect() end) tpAddConn = nil end
            removeTpTool()
        end
    end)

    -- TP to map/lobby
    local tpMapSec = tT:AddSection({Name="Телепорт"})
    local function stableTp(cf)
        local root = getHRP()
        if not root then return end
        root.CFrame = cf
        if getgenv().FAKE_POS_ACTIVE then return end
        task.spawn(function()
            local t = os.clock()
            while os.clock() - t < 0.25 and root.Parent do
                pcall(function()
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end)
                task.wait()
            end
        end)
    end
    local function inLobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby" or p.Name == "Lobby" or p.Name == "SummerLobby" then
                return true
            end
            p = p.Parent
        end
        return false
    end
    tpMapSec:AddButton({Title="Телепорт на карту", Callback=function()
        local root = getHRP()
        if not root then return end
        local spawnParts = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if (obj:IsA("SpawnLocation") or (obj:IsA("BasePart") and obj.Name == "Spawn")) and not inLobby(obj) then
                spawnParts[#spawnParts+1] = obj
            end
        end
        if #spawnParts > 0 then
            local s = spawnParts[math.random(1, #spawnParts)]
            stableTp(s.CFrame + Vector3.new(0, 5, 0))
        end
    end})
    tpMapSec:AddButton({Title="Телепорт в лобби", Callback=function()
        local lobby = Workspace:FindFirstChild("RegularLobby")
            or Workspace:FindFirstChild("Lobby")
            or Workspace:FindFirstChild("SummerLobby")
        if not lobby then return end
        local locs = {}
        for _, obj in ipairs(lobby:GetDescendants()) do
            if obj:IsA("SpawnLocation") or (obj:IsA("BasePart") and obj.Name == "Spawn") then
                locs[#locs+1] = obj
            end
        end
        if #locs > 0 then
            local s = locs[math.random(1, #locs)]
            stableTp(s.CFrame + Vector3.new(0, 3, 0))
        end
    end})

    -- TP to player
    local tpPlayerSec = tT:AddSection({Name="ТП к игроку"})
    addOpt(tpPlayerSec, "AddInput", "TPPlayerName", {Title="Имя игрока", Default=""})
    tpPlayerSec:AddButton({Title="ТП к игроку", Callback=function()
        local nameOpt = Options.TPPlayerName
        local name = nameOpt and nameOpt.Value
        if type(name) ~= "string" or name == "" then
            Notify("FH", "Введи имя", 2)
            return
        end
        local pl = Players:FindFirstChild(name)
        if not pl or not pl.Character then
            Notify("FH", "Игрок не найден", 2)
            return
        end
        local tHrp = pl.Character:FindFirstChild("HumanoidRootPart")
        local myHrp = getHRP()
        if tHrp and myHrp then
            myHrp.CFrame = tHrp.CFrame + Vector3.new(0, 5, 0)
        end
    end})
end

-- ============================================================
-- CUSTOM GUN MODELS (из KITI)
-- ============================================================
do
    local gvSec = Tabs.Visual:AddSection({Name="Custom Gun Models"})
    local gunModelCache = {}
    local customModelEnabled = false
    local selectedModelName = "AWP"

    local KITI_Models = {}
    do local a = {id="4531395275"} a.rot = CFrame.Angles(0,0,0) a.pos = CFrame.new(0,0,-0.5) KITI_Models.AWP = a end
    do local a = {id="5102714039"} a.rot = CFrame.Angles(0,math.pi,0) a.pos = CFrame.new(0,0,0.5) KITI_Models.Pistol = a end
    do local a = {id="5294131243"} a.rot = CFrame.Angles(0,math.pi,0) a.pos = CFrame.new(0,0,0.8) KITI_Models.Shotgun = a end
    do local a = {id="542699703"} a.rot = CFrame.Angles(0,math.pi,0) a.pos = CFrame.new(0,0,0.2) KITI_Models.RayGun = a end
    do local a = {id="127200798279812"} a.rot = CFrame.Angles(math.pi/2,0,-math.pi/2) a.pos = CFrame.new(0,-0.3,0.3) KITI_Models["AK-47"] = a end
    do local a = {id="18610978709"} a.rot = CFrame.Angles(0,0,0) a.pos = CFrame.new(0,0,-0.3) KITI_Models.PinkGun = a end
    do local a = {id="10656806096"} a.rot = CFrame.Angles(-math.pi/2,math.pi/2,math.pi/2) a.pos = CFrame.new(2.1,0,-0.3) KITI_Models.FlameGun = a end
    do local a = {id="62932622"} a.rot = CFrame.Angles(math.pi/2,0,0) a.pos = CFrame.new(0,0,0) KITI_Models.MiniBlackGun = a end
    do local a = {id="87594143804300"} a.rot = CFrame.Angles(-math.pi/2,math.pi/2,math.pi/2) a.pos = CFrame.new(0,-0.3,0.5) KITI_Models.BlueGun = a end
    do local a = {id="12899296613"} a.rot = CFrame.Angles(0,0,0) a.pos = CFrame.new(0,0,-1.3) KITI_Models["BigUSP-S"] = a end
    do local a = {id="1297856838"} a.rot = CFrame.Angles(math.pi/2,0,0) a.pos = CFrame.new(0,-0.3,0) KITI_Models.GreenGun = a end

    local MODEL_LIST = {"AWP","Pistol","Shotgun","RayGun","AK-47","PinkGun","FlameGun","MiniBlackGun","BlueGun","BigUSP-S","GreenGun"}

    local function fetchModel(id)
        local key = tostring(id)
        if gunModelCache[key] then return gunModelCache[key]:Clone() end
        local ok, objs = pcall(function() return game:GetObjects("rbxassetid://"..key) end)
        if ok and type(objs) == "table" and #objs > 0 then
            gunModelCache[key] = objs[1]
            return objs[1]:Clone()
        end
        return nil
    end
    local function restoreGun(tool)
        if not tool or not tool:IsA("Tool") or tool.Name ~= "Gun" then return end
        local custom = tool:FindFirstChild("FH_CustomGunModel")
        if custom then custom:Destroy() end
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("BasePart") then d.Transparency = 0
            elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 0 end
        end
    end
    local function applyGun(tool)
        if not tool or not tool:IsA("Tool") or tool.Name ~= "Gun" then return end
        if not customModelEnabled then restoreGun(tool) return end
        local preset = KITI_Models[selectedModelName]
        if not preset then return end
        local char = LocalPlayer.Character
        if not char or tool.Parent ~= char then return end
        local rightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        if not rightHand then return end
        local old = tool:FindFirstChild("FH_CustomGunModel")
        if old then old:Destroy() end
        local model = fetchModel(preset.id)
        if not model then return end
        model.Name = "FH_CustomGunModel"
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("BasePart") and not d:IsDescendantOf(model) then
                d.Transparency = 1
            elseif (d:IsA("Decal") or d:IsA("Texture")) and not d:IsDescendantOf(model) then
                d.Transparency = 1
            end
        end
        local anchorPart = nil
        if model:IsA("BasePart") then anchorPart = model
        elseif model.PrimaryPart then anchorPart = model.PrimaryPart
        elseif model:FindFirstChild("Handle") then anchorPart = model.Handle
        else anchorPart = model:FindFirstChildWhichIsA("BasePart", true) end
        if not anchorPart then model:Destroy() return end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                d.CanCollide = false
                d.Anchored = false
                d.Massless = true
            end
        end
        local isR15 = char:FindFirstChild("UpperTorso") ~= nil
        local baseOffset
        if isR15 then
            baseOffset = CFrame.new(0,-0.25,-0.1)*CFrame.Angles(-math.pi/2,0,0)
        else
            baseOffset = CFrame.new(0,-1,-0.1)*CFrame.Angles(-math.pi/2,0,0)
        end
        local targetCF = rightHand.CFrame * baseOffset * preset.rot * preset.pos
        if model:IsA("Model") then model:PivotTo(targetCF)
        elseif model:IsA("BasePart") then model.CFrame = targetCF end
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = rightHand
        weld.Part1 = anchorPart
        weld.Parent = anchorPart
        for _, p in ipairs(model:GetDescendants()) do
            if p:IsA("BasePart") and p ~= anchorPart then
                local w2 = Instance.new("WeldConstraint")
                w2.Part0 = anchorPart
                w2.Part1 = p
                w2.Parent = p
            end
        end
        model.Parent = tool
    end
    local function refreshAll()
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            local g = bp:FindFirstChild("Gun")
            if g then
                if customModelEnabled then applyGun(g) else restoreGun(g) end
            end
        end
        local char = LocalPlayer.Character
        if char then
            local g = char:FindFirstChild("Gun")
            if g then
                if customModelEnabled then applyGun(g) else restoreGun(g) end
            end
        end
    end
    local function hookContainer(cont)
        if not cont then return end
        cont.ChildAdded:Connect(function(child)
            if child:IsA("Tool") and child.Name == "Gun" then
                task.wait(0.05)
                child.Equipped:Connect(function()
                    if customModelEnabled then
                        task.wait(0.02)
                        applyGun(child)
                    end
                end)
                child.Unequipped:Connect(function()
                    local old = child:FindFirstChild("FH_CustomGunModel")
                    if old then old:Destroy() end
                end)
            end
        end)
    end
    task.spawn(function()
        local bp = LocalPlayer:WaitForChild("Backpack")
        if bp then hookContainer(bp) end
        if LocalPlayer.Character then hookContainer(LocalPlayer.Character) end
        LocalPlayer.CharacterAdded:Connect(hookContainer)
    end)

    addOpt(gvSec, "AddToggle", "FHGunModelOn", {Title="Заменить модель оружия", Default=false}, function(v)
        customModelEnabled = v
        refreshAll()
        Notify("FH", v and "Модель оружия ВКЛ" or "Модель оружия ВЫКЛ", 2)
    end)
    addOpt(gvSec, "AddDropdown", "FHGunModelPick", {Title="Модель оружия", Values=MODEL_LIST, Default="AWP"}, function(v)
        selectedModelName = v or "AWP"
        if customModelEnabled then refreshAll() end
    end)
end

-- ============================================================
-- BEAM EFFECTS
-- ============================================================
do
    local BeamCfg = {Type = "Default", Color = Color3.fromRGB(0, 240, 255)}
    local function beamColor() return BeamCfg.Color or Color3.fromRGB(0,240,255) end
    local function makeCyl(p1, p2, thickness, color)
        local len = (p2-p1).Magnitude
        if len < 1 then return end
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = color or beamColor()
        part.Shape = Enum.PartType.Cylinder
        part.Size = Vector3.new(len, thickness, thickness)
        part.CFrame = CFrame.lookAt(p1, p2)*CFrame.new(0,0,-len/2)*CFrame.Angles(0, math.pi/2, 0)
        part.Parent = workspace.Terrain
        TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size=Vector3.new(len,0,0), Transparency=1}):Play()
        task.delay(0.25, function() part:Destroy() end)
    end
    local function makeImpact(pos, dir, color)
        local ball = Instance.new("Part")
        ball.Shape = Enum.PartType.Ball
        ball.Material = Enum.Material.Neon
        ball.Color = color or beamColor()
        ball.Size = Vector3.new(0.4,0.4,0.4)
        ball.Position = pos
        ball.Anchored = true
        ball.CanCollide = false
        ball.Parent = workspace.Terrain
        local light = Instance.new("PointLight")
        light.Color = color or beamColor()
        light.Range = 16
        light.Brightness = 3.5
        light.Parent = ball
        local info = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TweenService:Create(ball, info, {Size=Vector3.new(8,8,8), Transparency=1}):Play()
        TweenService:Create(light, info, {Brightness=0, Range=0}):Play()
        task.delay(1.2, function() ball:Destroy() end)
    end
    local function processBeam(beam)
        if not beam:IsA("Beam") then return end
        if BeamCfg.Type == "Default" then return end
        local a0, a1 = beam.Attachment0, beam.Attachment1
        if not a0 or not a1 then return end
        local p1, p2 = a0.WorldPosition, a1.WorldPosition
        local dir = (p2-p1).Unit
        local t = BeamCfg.Type
        if t == "Neon Fat" then
            beam.Width0 = 1.8
            beam.Width1 = 1.2
            beam.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(0.2, beamColor()),
                ColorSequenceKeypoint.new(1, beamColor()),
            })
            makeCyl(p1, p2, 1.0)
        elseif t == "Nuke" then
            beam.Width0 = 1.4
            beam.Width1 = 0.8
            beam.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(0.1, beamColor()),
                ColorSequenceKeypoint.new(1, beamColor()),
            })
            makeCyl(p1, p2, 0.8)
            makeImpact(p2, dir)
        elseif t == "Zigzag" then
            beam.Width0 = 0.1
            beam.Width1 = 0.1
            local len = (p2-p1).Magnitude
            local segs = math.clamp(math.floor(len/6), 4, 12)
            local prev = p1
            for i = 1, segs do
                local cur = p1:Lerp(p2, i/segs)
                if i < segs then
                    cur = cur + Vector3.new(math.random(-2,2), math.random(-2,2), math.random(-2,2))
                end
                makeCyl(prev, cur, 0.4)
                prev = cur
            end
        end
    end
    Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Beam") and BeamCfg.Type ~= "Default" then
            task.wait()
            pcall(processBeam, d)
        end
    end)
    local sec = Tabs.Effects:AddSection({Name="Gun Beam Effects"})
    addOpt(sec, "AddDropdown", "FHBeamType", {Title="Тип луча", Values={"Default","Neon Fat","Nuke","Zigzag"}, Default="Default"}, function(v)
        BeamCfg.Type = v or "Default"
        Notify("FH", "Beam: "..BeamCfg.Type, 2)
    end)
    addOpt(sec, "AddColorPicker", "FHBeamColor", {Title="Цвет луча", Default=Color3.fromRGB(0,240,255)}, function(c)
        BeamCfg.Color = c
    end)
end

-- ============================================================
-- SKYBOX MANAGER (тоггл + dropdown)
-- ============================================================
do
    local SKY_PRESETS = {
        ["Snow"] = 4604073339,
        ["Realistic Space"] = 136402262,
        ["Purple Nebula"] = 83555979203508,
        ["Blue Nebula"] = 130093177270069,
        ["SpongeBob"] = 114523453023009,
        ["Night Sky Vibe"] = 78613024128163,
        ["Geoz Skybox"] = 97573261671957,
        ["Asteroid Space"] = 295604372,
    }
    local SKY_NAMES = {}
    for k in pairs(SKY_PRESETS) do SKY_NAMES[#SKY_NAMES+1] = k end
    table.sort(SKY_NAMES)
    local function destroySky()
        local sky = Lighting:FindFirstChild("FH_SkyboxManaged")
        if sky then sky:Destroy() end
    end
    local function applySkybox(id, name)
        task.spawn(function()
            local ok, objs = pcall(function() return game:GetObjects("rbxassetid://"..tostring(id)) end)
            if not ok or type(objs) ~= "table" or #objs == 0 then
                Notify("FH", "Не удалось загрузить skybox: "..tostring(name), 3)
                return
            end
            local first = objs[1]
            local sky = nil
            if first:IsA("Sky") then sky = first
            else
                sky = first:FindFirstChildOfClass("Sky")
                if not sky then
                    local s = first:FindFirstChildWhichIsA("Sky", true)
                    if s then sky = s end
                end
            end
            if not sky then
                pcall(function() first:Destroy() end)
                Notify("FH", "Sky не найден", 3)
                return
            end
            local existing = Lighting:FindFirstChildOfClass("Sky")
            if existing then existing:Destroy() end
            Lighting.ClockTime = 14
            Lighting.Brightness = 0.5
            sky.Name = "FH_SkyboxManaged"
            sky.Parent = Lighting
            if first ~= sky then pcall(function() first:Destroy() end) end
            Notify("FH", "Skybox: "..tostring(name), 2)
        end)
    end
    local function removeSky()
        destroySky()
        Notify("FH", "Skybox удалён", 2)
    end
    local sec = Tabs.Effects:AddSection({Name="Skybox Manager"})
    addOpt(sec, "AddToggle", "FHSkyboxOn", {Title="Включить скайбокс", Default=false}, function(v)
        if v then
            local pick = Options.FHSkyboxPick and Options.FHSkyboxPick.Value
            if type(pick) == "table" then pick = pick[1] end
            local id = SKY_PRESETS[pick]
            if id then applySkybox(id, pick) end
        else
            removeSky()
        end
    end)
    addOpt(sec, "AddDropdown", "FHSkyboxPick", {Title="Выбрать небо", Values=SKY_NAMES, Default=SKY_NAMES[1] or "Snow"}, function(v)
        if Options.FHSkyboxOn and Options.FHSkyboxOn.Value then
            local id = SKY_PRESETS[v]
            if id then applySkybox(id, v) end
        end
    end)
end

-- ============================================================
-- ANTI-AIM
-- ============================================================
do
    local enabled = false
    local token = 0
    local savedCollide = {}
    local stepConn = nil
    local function getRoot(char)
        if not char then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.RootPart then return hum.RootPart end
        return char:FindFirstChild("HumanoidRootPart")
    end
    local function stop()
        enabled = false
        token = token + 1
        if stepConn then pcall(function() stepConn:Disconnect() end) stepConn = nil end
        local char = LocalPlayer.Character
        if char then
            for part, ct in pairs(savedCollide) do
                if part and part.Parent then
                    pcall(function() part.CanCollide = ct end)
                end
            end
        end
        table.clear(savedCollide)
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
                stop()
                return
            end
            for _, d in ipairs(c:GetDescendants()) do
                if d:IsA("BasePart") then
                    if savedCollide[d] == nil then savedCollide[d] = d.CanCollide end
                    d.CanCollide = false
                end
            end
        end)
    end
    local sec = Tabs.Utility:AddSection({Name="Anti-Aim"})
    addOpt(sec, "AddToggle", "FHAntiAimOn", {Title="Анти-аим", Default=false}, function(v)
        if v then
            start()
            Notify("FH", "Anti-Aim ВКЛ", 2)
        else
            stop()
            Notify("FH", "Anti-Aim ВЫКЛ", 2)
        end
    end)
end

-- ============================================================
-- PNG Avatars
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
    local avatarCache = {}
    local userToUrl = {}
    local folder = "FortniHub_Configs/avatars"
    if type(makefolder) == "function" and type(isfolder) == "function" then
        if not isfolder(folder) then pcall(makefolder, folder) end
    end
    local function resolveLocal(url, idx)
        if avatarCache[url] then return avatarCache[url] end
        if type(getcustomasset) ~= "function" or type(writefile) ~= "function" then return url end
        local path = folder.."/avatar_"..tostring(idx or 1)..".png"
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
                if u == userToUrl[player.UserId] then idx = i break end
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
        for i, u in ipairs(avatarUrls) do if u == pick then idx = i break end end
        return resolveLocal(pick, idx)
    end
    getgenv().FH_GetAvatarFor = getAvatarFor
end

-- ============================================================
-- Jump Circle
-- ============================================================
do
    local settings = {enabled=false, color=Color3.fromRGB(255,105,180)}
    local image = "rbxassetid://133238425773760"
    local conn = nil
    local function spawnCircle(pos)
        if not settings.enabled then return end
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
        part.Parent = Workspace
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Top
        sg.AlwaysOnTop = true
        sg.LightInfluence = 0
        sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 100
        sg.Parent = part
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1,1)
        img.Image = image
        img.ImageColor3 = settings.color
        img.ImageTransparency = 0
        img.Parent = sg
        local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(part, info, {Size=Vector3.new(7,0.05,7)}):Play()
        TweenService:Create(img, info, {ImageTransparency=1}):Play()
        Debris:AddItem(part, 0.9)
    end
    local function bind(char)
        if conn then conn:Disconnect() conn = nil end
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
    addOpt(sec, "AddColorPicker", "FH_JumpCircleCol", {Title="Цвет", Default=Color3.fromRGB(255,105,180)}, function(c) settings.color = c end)
end

-- ============================================================
-- RTX
-- ============================================================
do
    local rtxOn = false
    local saved = {}
    local addedFx = {}
    local vignette = nil
    local function enable()
        if rtxOn then return end
        rtxOn = true
        local props = {"Ambient","Brightness","GlobalShadows","OutdoorAmbient","ClockTime","ExposureCompensation"}
        for _, p in ipairs(props) do pcall(function() saved[p] = Lighting[p] end) end
        local bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.35
        bloom.Size = 20
        bloom.Threshold = 0.85
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Brightness = 0.05
        cc.Contrast = 0.25
        cc.Saturation = 0.15
        cc.TintColor = Color3.fromRGB(255,245,230)
        addedFx = {bloom, cc}
        for _, fx in ipairs(addedFx) do fx.Parent = Lighting end
        Lighting.Ambient = Color3.fromRGB(70,70,70)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(100,100,100)
        Lighting.ClockTime = 14
        Lighting.ExposureCompensation = 0.1
        vignette = Instance.new("ScreenGui")
        vignette.Name = "FH_RTXVignette"
        vignette.IgnoreGuiInset = true
        vignette.ResetOnSpawn = false
        vignette.Parent = LocalPlayer:WaitForChild("PlayerGui")
        local img = Instance.new("ImageLabel")
        img.AnchorPoint = Vector2.new(0.5,1)
        img.Position = UDim2.new(0.5,0,1,0)
        img.Size = UDim2.new(1,0,1.05,0)
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
        for k, v in pairs(saved) do pcall(function() Lighting[k] = v end) end
        saved = {}
        if vignette then pcall(function() vignette:Destroy() end) vignette = nil end
    end
    local sec = Tabs.Effects:AddSection({Name="RTX Shader"})
    addOpt(sec, "AddToggle", "FH_RTXOn", {Title="Включить RTX", Default=false}, function(v)
        if v then enable() else disable() end
        Notify("FH", "RTX "..(v and "ВКЛ" or "ВЫКЛ"), 2)
    end)
end

pcall(function() Window:SelectTab(1) end)

print("[FH] ============================================")
print("[FH] Part 2/2 v20.3 — loaded")
print("[FH] Fake Death (animation) / Vote Duper (pad select)")
print("[FH] Fling Tool (modes) / Gun Models / China Hat")
print("[FH] Aura 2.0 (persistent) / Farm (Basic/Down)")
print("[FH] ============================================")
