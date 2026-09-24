-- ============================================================
-- FORTNIHUB ADDON — two.lua
-- Silent / Knife / KillAura v2 / AutoFarm v2 / Backtrack / Tracer
-- China Hat / Self Chams / Movement Graph / Anti / Tools / FakePos
-- Sound Replacer / FLING TAB (new!)
-- ============================================================

local FH = getgenv().FH
if not FH then warn("[FH] two.lua: сначала загрузи one.lua"); return end

local Options = FH.Options
local Window = FH.Window
local Tabs = FH.Tabs
local Notify = FH.Notify
local GetRole = FH.GetRole
local GetHRP = FH.GetHRP
local AddConnection = FH.AddConnection
local LocalPlayer = FH.LocalPlayer
local Players = FH.Players
local RunService = FH.RunService
local UserInputService = FH.UserInputService
local ReplicatedStorage = FH.ReplicatedStorage
local Workspace = FH.Workspace
local CoreGui = FH.CoreGui
local Camera = FH.Camera
local logInfo = FH.logInfo
local logWarn = FH.logWarn
local logErr = FH.logErr
local safeHttpGet = FH.safeHttpGet
local safeLoadstring = FH.safeLoadstring
local safeRun = FH.safeRun
local ModuleNameToTitle = FH.ModuleNameToTitle
local L = FH.L
local TweenService = game:GetService("TweenService")

-- ============================================================
-- STATE
-- ============================================================
local Addon = {
    silentMode = "v2", silentOn = false, autoShootOn = false, autoDelay = 0,
    forceShootOn = false, forceStandOff = 15,
    originalMouseTarget = nil, originalTargetPos = nil, weaponService = nil,
    lastFireStamp = 0, fireGap = 0,
    knifeSilentOn = false, knifePredOn = false, knifeInstaOn = false,
    knifeRadius = 12, knifeLead = 1.0, knifeAir = 0.35, knifeOffset = 0, knifeSpeed = 96,
    knifeTrackers = {}, knifeOriginalKnifeAim = nil,
    kaV2On = false, kaV2Dist = 30,
    farmV2On = false, farmDownDepth = 14,
    btOn = false, btColor = Color3.fromRGB(255, 60, 60),
    btModel = nil, btHistory = {}, btCap = 256, btFirst = 1, btCount = 0, btPairs = {},
    tracerOn = false, tracerColor = Color3.fromRGB(133, 220, 255), tracerDur = 1, tracerConn = nil,
    soundOn = false, soundSheriff = "mc bow", soundMurder = "skeet", soundVol = 1,
    soundHooked = {}, soundPool = {}, soundLast = {sheriff = 0, murder = 0},
    antiFlingOn = false, antiVoidOn = false, antiTrapOn = false,
    antiFlingCache = {}, antiVoidOrig = workspace.FallenPartsDestroyHeight,
    antiTrapSpeedCache = 16, antiTrapJumpCache = 50,
    tpToolOn = false, flingToolOn = false, flingBypassVel = false,
    tpToolObj = nil, flingToolObj = nil, flingActive = 0,
    fakePosOn = false, fakePosX = 9e9, fakePosY = 9e9, fakePosZ = 9e9,
    fakePosClientCF = CFrame.identity, fakePosHookedMT = {}, fakePosActive = false,
    chinaHatOn = false, chinaHatColor = Color3.fromRGB(255, 60, 60), chinaHatParts = {},
    selfChamsOn = false, selfChamsColor = Color3.fromRGB(120, 60, 255), selfChamsCache = {},
    movGraphOn = false, movGraphColor = Color3.fromRGB(242, 242, 242),
    movGraphWidth = 280, movGraphHeight = 72, movGraphY = 180,
    movGraphLines = {}, movGraphShadows = {}, movGraphText = nil, movGraphHistory = {},
    -- FLING
    flingOn = false,
    flingMode = "murderer",     -- "specific" / "murderer" / "sheriff" / "all"
    flingTarget = "",           -- имя игрока для "specific"
    flingThread = nil,
    flingCooldown = 0,
    flingRange = 500,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function GetRoundData()
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient"))
    end)
    if ok and type(m) == "table" then return m.PlayerData end
    return nil
end

local function AmMurderer()
    local d = GetRoundData()
    if type(d) ~= "table" then return false end
    local me = d[LocalPlayer.Name]
    return me ~= nil and me.Role == "Murderer" and not me.Dead
end

local function AmSheriff()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Gun") then return true end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild("Gun") then return true end
    local d = GetRoundData()
    if type(d) == "table" then
        local me = d[LocalPlayer.Name]
        return me ~= nil and (me.Role == "Sheriff" or me.Role == "Hero")
    end
    return false
end

local function GetGun()
    local c = LocalPlayer.Character
    if c then local g = c:FindFirstChild("Gun"); if g then return g, true end end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local g = bp:FindFirstChild("Gun"); if g then return g, false end end
    return nil, false
end

local function GetKnife()
    local c = LocalPlayer.Character
    if c then local k = c:FindFirstChild("Knife"); if k then return k, true end end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local k = bp:FindFirstChild("Knife"); if k then return k, false end end
    return nil, false
end

local function FindMurderer()
    local d = GetRoundData()
    if type(d) == "table" then
        for name, info in pairs(d) do
            if type(info) == "table" and info.Role == "Murderer" and not info.Dead then
                local p = Players:FindFirstChild(name)
                if p and p ~= LocalPlayer then return p end
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Knife") then
            return p
        end
    end
    return nil
end

local function FindSheriff()
    local d = GetRoundData()
    if type(d) == "table" then
        for name, info in pairs(d) do
            if type(info) == "table" and not info.Dead and (info.Role == "Sheriff" or info.Role == "Hero") then
                local p = Players:FindFirstChild(name)
                if p and p ~= LocalPlayer then return p end
            end
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Gun") then
            return p
        end
    end
    return nil
end

-- ============================================================
-- SILENT AIM
-- ============================================================
local function InstallSilentHook()
    if Addon.silentMode ~= "v2" then return end
    local ok, m = pcall(function()
        return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"))
    end)
    if not ok or type(m) ~= "table" then return end
    Addon.weaponService = m
    if type(m.GetMouseTargetCFrame) == "function" and not Addon.originalMouseTarget then
        Addon.originalMouseTarget = m.GetMouseTargetCFrame
        local orig = Addon.originalMouseTarget
        pcall(function() setreadonly(m, false) end)
        pcall(function()
            m.GetMouseTargetCFrame = function(self, ...)
                if not Addon.silentOn then return orig(self, ...) end
                local target = FindMurderer()
                if not target or not target.Character then return orig(self, ...) end
                local thrp = target.Character:FindFirstChild("HumanoidRootPart")
                if not thrp then return orig(self, ...) end
                local ping = 0
                pcall(function() ping = LocalPlayer:GetNetworkPing() * 2 end)
                ping = math.clamp(ping, 0.02, 0.35)
                local vel = thrp.AssemblyLinearVelocity
                return CFrame.new(thrp.Position + Vector3.new(vel.X, 0, vel.Z) * ping)
            end
        end)
    end
    if type(m.GetTargetPosition) == "function" and not Addon.originalTargetPos then
        Addon.originalTargetPos = m.GetTargetPosition
        local orig2 = Addon.originalTargetPos
        pcall(function()
            m.GetTargetPosition = function(self, x, y, ...)
                if not Addon.silentOn then return orig2(self, x, y, ...) end
                local target = FindMurderer()
                if not target or not target.Character then return orig2(self, x, y, ...) end
                local thrp = target.Character:FindFirstChild("HumanoidRootPart")
                if not thrp then return orig2(self, x, y, ...) end
                local ping = 0
                pcall(function() ping = LocalPlayer:GetNetworkPing() * 2 end)
                ping = math.clamp(ping, 0.02, 0.35)
                local vel = thrp.AssemblyLinearVelocity
                return CFrame.new(thrp.Position + Vector3.new(vel.X, 0, vel.Z) * ping)
            end
        end)
    end
end

local function UninstallSilentHook()
    local m = Addon.weaponService
    if not m then return end
    pcall(function() setreadonly(m, false) end)
    if Addon.originalMouseTarget then pcall(function() m.GetMouseTargetCFrame = Addon.originalMouseTarget end) end
    if Addon.originalTargetPos then pcall(function() m.GetTargetPosition = Addon.originalTargetPos end) end
end

local function RestoreForceOrigin() end  -- заглушка (Force Shoot использует origin-хук, см. ниже)

local function InitSilent()
    AddConnection("AddonAutoShoot", RunService.Heartbeat:Connect(function()
        if not Addon.autoShootOn then return end
        if not AmSheriff() then return end
        local target = FindMurderer()
        if not target then return end
        local gun, equipped = GetGun()
        if not gun then return end
        local now = os.clock()
        if now - Addon.lastFireStamp < math.max(0, Addon.autoDelay / 1000) then return end
        if not equipped then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(gun) end) end
            return
        end
        local thrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if not thrp then return end
        local remote = gun:FindFirstChild("Shoot")
        if remote and remote:IsA("RemoteEvent") then
            local origin = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if origin then
                pcall(function() remote:FireServer(origin.CFrame, CFrame.new(thrp.Position)) end)
                Addon.lastFireStamp = now
            end
        end
    end))
end

-- ============================================================
-- KNIFE SILENT
-- ============================================================
local function KnifeTrack(p, now)
    if not p or not p.Character then return nil end
    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local t = Addon.knifeTrackers[p]
    if not t then
        t = { s = {}, n = 0, i = 0, vel = Vector3.zero, lastPos = nil, lastTime = now }
        Addon.knifeTrackers[p] = t
    end
    local pos = hrp.Position
    if t.lastPos and (pos - t.lastPos).Magnitude > 0.005 then
        t.i = t.i % 16 + 1
        t.s[t.i] = { t = now, p = pos }
        if t.n < 16 then t.n = t.n + 1 end
        if t.n >= 3 then
            local newest = t.s[t.i].t
            local used, sumD = 0, 0
            for k = 0, t.n - 1 do
                local idx = (t.i - k - 1) % 16 + 1
                local s = t.s[idx]
                if not s or newest - s.t > 0.25 then break end
                used = used + 1; sumD = sumD + (s.t - newest)
            end
            if used >= 3 then
                local meanD = sumD / used
                local num, den = Vector3.zero, 0
                for k = 0, used - 1 do
                    local idx = (t.i - k - 1) % 16 + 1
                    local s = t.s[idx]
                    if not s then break end
                    local dd = (s.t - newest) - meanD
                    num = num + s.p * dd; den = den + dd * dd
                end
                if den > 1e-8 then t.vel = num / den end
            end
        end
    end
    t.lastPos, t.lastTime = pos, now
    return t, hrp
end

local function KnifeResolveAim()
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("Knife") then return nil end
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end
    local best, bestDist = nil, math.huge
    local now = os.clock()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local t, hrp = KnifeTrack(p, now)
            if hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < bestDist then bestDist = d; best = { p = p, hrp = hrp, track = t } end
            end
        end
    end
    if not best then return nil end
    local base = best.hrp.Position
    local vel = best.track and best.track.vel or best.hrp.AssemblyLinearVelocity
    local lead = Addon.knifeLead + Addon.knifeOffset
    local aim = base + Vector3.new(vel.X, 0, vel.Z) * lead
    local hum = best.p.Character and best.p.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then
            local g = workspace.Gravity
            aim = Vector3.new(aim.X, base.Y + vel.Y * lead - 0.5 * g * lead * lead + Addon.knifeAir, aim.Z)
        end
    end
    return aim
end

local function InitKnife()
    AddConnection("KnifeHook", RunService.Heartbeat:Connect(function()
        if not Addon.knifeSilentOn then return end
        local m = Addon.weaponService
        if not m then
            local ok, mm = pcall(function()
                return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"))
            end)
            if ok then m = mm; Addon.weaponService = m end
        end
        if not m then return end
        if not Addon.knifeOriginalKnifeAim then
            Addon.knifeOriginalKnifeAim = m.GetMouseTargetCFrame
        end
        local orig = Addon.knifeOriginalKnifeAim
        local hasKnife = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife")
        if not hasKnife then
            if m.GetMouseTargetCFrame ~= orig and orig then
                pcall(function() setreadonly(m, false); m.GetMouseTargetCFrame = orig end)
            end
            return
        end
        pcall(function() setreadonly(m, false) end)
        pcall(function()
            m.GetMouseTargetCFrame = function(self, ...)
                if Addon.knifeSilentOn then
                    local aim = KnifeResolveAim()
                    if aim then return CFrame.new(aim) end
                end
                if orig then return orig(self, ...) end
            end
        end)
    end))

    AddConnection("KnifeInsta", RunService.Heartbeat:Connect(function()
        if not Addon.knifeInstaOn then return end
        if not AmMurderer() then return end
        local knife, equipped = GetKnife()
        if not knife or not equipped then return end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end
        local events = knife:FindFirstChild("Events")
        if not events then return end
        local stab = events:FindFirstChild("KnifeStabbed")
        local touch = events:FindFirstChild("HandleTouched")
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                if thrp and (thrp.Position - myHRP.Position).Magnitude <= Addon.knifeRadius then
                    if stab then pcall(function() stab:FireServer() end) end
                    if touch then pcall(function() touch:FireServer(thrp) end) end
                    break
                end
            end
        end
    end))
end

-- ============================================================
-- KILL AURA v2
-- ============================================================
local function InitKAv2()
    AddConnection("KAv2", RunService.Heartbeat:Connect(function()
        if not Addon.kaV2On then return end
        if not AmMurderer() then return end
        local char = LocalPlayer.Character
        if not char then return end
        local knife = char:FindFirstChild("Knife")
        if not knife then return end
        local events = knife:FindFirstChild("Events")
        if not events then return end
        local stab = events:FindFirstChild("KnifeStabbed")
        local touch = events:FindFirstChild("HandleTouched")
        if not stab or not touch then return end
        local myHRP = char:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end
        local victims = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                if thrp and (thrp.Position - myHRP.Position).Magnitude <= Addon.kaV2Dist then
                    victims[#victims+1] = thrp
                end
            end
        end
        if #victims > 0 then
            pcall(function() stab:FireServer() end)
            for _, v in ipairs(victims) do
                pcall(function() touch:FireServer(v) end)
            end
        end
    end))
end

-- ============================================================
-- BACKTRACK
-- ============================================================
local function BtDestroy()
    if Addon.btModel then pcall(function() Addon.btModel:Destroy() end) Addon.btModel = nil end
    Addon.btFirst, Addon.btCount = 1, 0
end

local function BtBuild()
    BtDestroy()
    local char = LocalPlayer.Character
    if not char then return end
    char.Archivable = true
    local ok, m = pcall(function() return char:Clone() end)
    char.Archivable = false
    if not ok or not m then return end
    local rparts = {}
    for _, o in char:GetDescendants() do
        if o:IsA("BasePart") then rparts[#rparts+1] = o end
    end
    local ci = 0
    Addon.btPairs = {}
    for _, o in m:GetDescendants() do
        if o:IsA("Script") or o:IsA("LocalScript") then pcall(function() o:Destroy() end)
        elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then pcall(function() o:Destroy() end)
        elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") then pcall(function() o:Destroy() end)
        elseif o:IsA("BasePart") then
            o.Anchored = true; o.CanCollide = false; o.CanQuery = false; o.CastShadow = false
            if o.Name == "HumanoidRootPart" then o.Transparency = 1
            else o.Material = Enum.Material.ForceField; o.Color = Addon.btColor; o.Transparency = 0 end
            ci = ci + 1
            Addon.btPairs[#Addon.btPairs+1] = { o, rparts[ci] }
        end
    end
    local hum = m:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:Destroy() end) end
    m.Parent = workspace
    Addon.btModel = m
end

local function InitBacktrack()
    AddConnection("BtLoop", RunService.Heartbeat:Connect(function()
        if not Addon.btOn then
            if Addon.btModel then BtDestroy() end
            return
        end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not Addon.btModel then BtBuild(); if not Addon.btModel then return end end
        if not Addon.btModel.Parent then Addon.btModel.Parent = workspace end
        local now = os.clock()
        local baseCF = hrp.CFrame
        if Addon.btCount < Addon.btCap then Addon.btCount = Addon.btCount + 1
        else Addon.btFirst = Addon.btFirst % Addon.btCap + 1 end
        local slotIdx = (Addon.btFirst + Addon.btCount - 2) % Addon.btCap + 1
        Addon.btHistory[slotIdx] = { now, baseCF }
        local ping = 0.15
        pcall(function() ping = math.clamp(LocalPlayer:GetNetworkPing() * 2, 0.05, 0.6) end)
        local target = now - ping
        local cf = baseCF
        for k = Addon.btCount, 1, -1 do
            local s = Addon.btHistory[(Addon.btFirst + k - 2) % Addon.btCap + 1]
            if s and s[1] <= target then cf = s[2]; break end
        end
        local baseInv = hrp.CFrame:Inverse()
        for i = 1, #Addon.btPairs do
            local cp, rp = Addon.btPairs[i][1], Addon.btPairs[i][2]
            if cp and cp.Parent and rp and rp.Parent then
                cp.CFrame = cf * (baseInv * rp.CFrame)
            end
        end
    end))
end

-- ============================================================
-- TRACER
-- ============================================================
local function InitTracer()
    AddConnection("TracerCheck", RunService.Heartbeat:Connect(function()
        if not Addon.tracerOn or Addon.tracerConn then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"):WaitForChild("GunFired")
        end)
        if not ok or not remote then return end
        Addon.tracerConn = remote.OnClientEvent:Connect(function(gun, startV, endV)
            if not Addon.tracerOn then return end
            local char = LocalPlayer.Character
            if not char or not (typeof(gun) == "Instance" and gun:IsDescendantOf(char)) then return end
            local startPos = typeof(startV) == "Vector3" and startV or (typeof(startV) == "CFrame" and startV.Position or nil)
            local endPos = typeof(endV) == "Vector3" and endV or (typeof(endV) == "CFrame" and endV.Position or nil)
            if not startPos or not endPos then return end
            local p1 = Instance.new("Part")
            p1.Transparency = 1; p1.Anchored = true; p1.CanCollide = false; p1.CanQuery = false
            p1.Size = Vector3.new(1,1,1); p1.CFrame = CFrame.new(startPos)
            Instance.new("Attachment", p1); p1.Parent = workspace
            local p2 = Instance.new("Part")
            p2.Transparency = 1; p2.Anchored = true; p2.CanCollide = false; p2.CanQuery = false
            p2.Size = Vector3.new(1,1,1); p2.CFrame = CFrame.new(endPos)
            Instance.new("Attachment", p2); p2.Parent = workspace
            local beam = Instance.new("Beam")
            beam.FaceCamera = true
            beam.Width0 = 0.25; beam.Width1 = 0.25
            beam.LightEmission = 3; beam.LightInfluence = 0; beam.Brightness = 2.5
            beam.Texture = "rbxassetid://12781800668"; beam.TextureSpeed = 1.5
            beam.Color = ColorSequence.new(Addon.tracerColor)
            beam.Transparency = NumberSequence.new(0.1)
            beam.Attachment0 = p1:FindFirstChildOfClass("Attachment")
            beam.Attachment1 = p2:FindFirstChildOfClass("Attachment")
            beam.Parent = p1
            task.delay(Addon.tracerDur, function()
                pcall(function()
                    TweenService:Create(beam, TweenInfo.new(0.2), { Width0 = 0, Width1 = 0 }):Play()
                end)
            end)
            task.delay(Addon.tracerDur + 0.5, function()
                pcall(function() p1:Destroy() end)
                pcall(function() p2:Destroy() end)
            end)
        end)
    end))
end

-- ============================================================
-- CHINA HAT
-- ============================================================
local function ChinaHatClear()
    for _, p in ipairs(Addon.chinaHatParts) do
        if p and p.Parent then pcall(function() p:Destroy() end) end
    end
    Addon.chinaHatParts = {}
end

local function InitChinaHat()
    AddConnection("ChinaHat", RunService.Heartbeat:Connect(function()
        if not Addon.chinaHatOn then
            if #Addon.chinaHatParts > 0 then ChinaHatClear() end
            return
        end
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then return end
        if #Addon.chinaHatParts == 0 then
            local segments = 12
            local radius = 0.9
            local height = 0.3
            for i = 1, segments do
                local angle = (i - 1) / segments * math.pi * 2
                local nextAngle = i / segments * math.pi * 2
                local midAngle = (angle + nextAngle) / 2
                local r1 = radius
                local x1, z1 = math.cos(angle) * r1, math.sin(angle) * r1
                local x1n, z1n = math.cos(nextAngle) * r1, math.sin(nextAngle) * r1
                local p = Instance.new("WedgePart")
                p.Anchored = false; p.CanCollide = false; p.CanQuery = false; p.Massless = true
                p.Color = Addon.chinaHatColor; p.Material = Enum.Material.SmoothPlastic
                p.Size = Vector3.new(r1 * 0.35, 0.1, height)
                p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
                p.Parent = head
                local center = Vector3.new((x1 + x1n) / 2 * 0.5, head.Size.Y * 0.5 + 0.3, (z1 + z1n) / 2 * 0.5)
                p.CFrame = head.CFrame * CFrame.new(center) * CFrame.Angles(0, midAngle, math.rad(-10))
                local wc = Instance.new("WeldConstraint")
                wc.Part0 = head; wc.Part1 = p; wc.Parent = p
                table.insert(Addon.chinaHatParts, p)
            end
        else
            for _, p in ipairs(Addon.chinaHatParts) do
                if p.Parent and p.Color ~= Addon.chinaHatColor then p.Color = Addon.chinaHatColor end
            end
        end
    end))
end

-- ============================================================
-- SELF CHAMS
-- ============================================================
local function SelfChamsClear()
    for part, old in pairs(Addon.selfChamsCache) do
        if part and part.Parent then
            pcall(function() part.Material = old.mat; part.Color = old.col end)
        end
    end
    Addon.selfChamsCache = {}
end

local function InitSelfChams()
    AddConnection("SelfChams", RunService.Heartbeat:Connect(function()
        if not Addon.selfChamsOn then
            if next(Addon.selfChamsCache) then SelfChamsClear() end
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                if not Addon.selfChamsCache[p] then
                    Addon.selfChamsCache[p] = { mat = p.Material, col = p.Color }
                end
                if p.Material ~= Enum.Material.ForceField then pcall(function() p.Material = Enum.Material.ForceField end) end
                if p.Color ~= Addon.selfChamsColor then pcall(function() p.Color = Addon.selfChamsColor end) end
            end
        end
    end))
end

-- ============================================================
-- MOVEMENT GRAPH
-- ============================================================
local function MovGraphClear()
    for i = 1, #Addon.movGraphLines do pcall(function() Addon.movGraphLines[i]:Remove() end) end
    for i = 1, #Addon.movGraphShadows do pcall(function() Addon.movGraphShadows[i]:Remove() end) end
    if Addon.movGraphText then pcall(function() Addon.movGraphText:Remove() end) end
    Addon.movGraphLines, Addon.movGraphShadows, Addon.movGraphText = {}, {}, nil
    Addon.movGraphHistory = {}
end

local function InitMovGraph()
    AddConnection("MovGraph", RunService.RenderStepped:Connect(function(dt)
        if not Addon.movGraphOn then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local v = hrp.AssemblyLinearVelocity
        local speed = math.sqrt(v.X * v.X + v.Z * v.Z)
        local now = os.clock()
        table.insert(Addon.movGraphHistory, { t = now, v = speed })
        while #Addon.movGraphHistory > 200 do table.remove(Addon.movGraphHistory, 1) end
        while #Addon.movGraphHistory > 0 and now - Addon.movGraphHistory[1].t > 3 do table.remove(Addon.movGraphHistory, 1) end
        local w, h = Addon.movGraphWidth, Addon.movGraphHeight
        local vp = Camera.ViewportSize
        local x0 = vp.X * 0.5 - w * 0.5
        local y0 = vp.Y * 0.5 + Addon.movGraphY - h * 0.5
        local maxSpeed = 30
        for _, s in ipairs(Addon.movGraphHistory) do if s.v > maxSpeed then maxSpeed = s.v end end
        maxSpeed = math.max(maxSpeed, 20)
        if not Addon.movGraphText then
            Addon.movGraphText = Drawing.new("Text")
            Addon.movGraphText.Size = 14; Addon.movGraphText.Outline = true
        end
        Addon.movGraphText.Text = string.format("%d", math.floor(speed + 0.5))
        Addon.movGraphText.Position = Vector2.new(x0 + w + 6, y0 + h * 0.5 - 8)
        Addon.movGraphText.Color = Addon.movGraphColor
        Addon.movGraphText.Visible = true
        if #Addon.movGraphLines == 0 then
            for i = 1, 200 do
                local sh = Drawing.new("Line")
                sh.Color = Color3.new(0,0,0); sh.Thickness = 3; sh.Transparency = 0.4; sh.Visible = false
                table.insert(Addon.movGraphShadows, sh)
                local ln = Drawing.new("Line")
                ln.Color = Addon.movGraphColor; ln.Thickness = 1.5; ln.Transparency = 1; ln.Visible = false
                table.insert(Addon.movGraphLines, ln)
            end
        end
        local hist = Addon.movGraphHistory
        for i = 1, #Addon.movGraphLines do
            if i < #hist then
                local a, b = hist[i], hist[i+1]
                local ax = x0 + (a.t - (now - 3)) / 3 * w
                local ay = y0 + h - (a.v / maxSpeed) * h
                local bx = x0 + (b.t - (now - 3)) / 3 * w
                local by = y0 + h - (b.v / maxSpeed) * h
                local ln = Addon.movGraphLines[i]
                local sh = Addon.movGraphShadows[i]
                ln.From = Vector2.new(ax, ay); ln.To = Vector2.new(bx, by)
                sh.From = ln.From; sh.To = ln.To
                ln.Color = Addon.movGraphColor
                ln.Visible, sh.Visible = true, true
            else
                Addon.movGraphLines[i].Visible = false
                Addon.movGraphShadows[i].Visible = false
            end
        end
    end))
end

-- ============================================================
-- SOUND REPLACER
-- ============================================================
local function InitSounds()
    local BASE = "https://github.com/khenn791/lmao/raw/refs/heads/main/"
    local CACHE = "shitaro_sounds/"
    local REMOTE = { ["mc bow"]=true, ["skeet"]=true, ["neverlose"]=true, ["rust"]=true, ["primordial"]=true, ["sparkle"]=true, ["break"]=true }

    local function Pull(name)
        if Addon.soundPool[name] then return Addon.soundPool[name] end
        if not REMOTE[name] then return nil end
        if type(isfile) ~= "function" or type(writefile) ~= "function" then return nil end
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return nil end
        pcall(function() if not isfolder(CACHE) then makefolder(CACHE) end end)
        local path = CACHE .. name .. ".ogg"
        if not isfile(path) then
            local url = BASE .. (string.gsub(name, " ", "%%20")) .. ".ogg"
            local ok, data = pcall(function() return game:HttpGet(url) end)
            if not ok or type(data) ~= "string" or #data < 1024 then return nil end
            if not pcall(writefile, path, data) then return nil end
        end
        local custom = getcustomasset or getsynasset
        if type(custom) ~= "function" then return nil end
        local ok, id = pcall(custom, path)
        if not ok or type(id) ~= "string" then return nil end
        Addon.soundPool[name] = id
        return id
    end

    local function PlaySound(kind)
        if not Addon.soundOn then return end
        local name = kind == "sheriff" and Addon.soundSheriff or Addon.soundMurder
        local id = Pull(name)
        if not id then return end
        local now = os.clock()
        if now - (Addon.soundLast[kind] or 0) < 0.15 then return end
        Addon.soundLast[kind] = now
        local SS = game:GetService("SoundService")
        local s = Instance.new("Sound")
        s.SoundId = id; s.Volume = Addon.soundVol; s.Parent = SS
        s:Play()
        task.delay(8, function() pcall(function() s:Destroy() end) end)
    end

    local function Hook(inst, kind)
        if Addon.soundHooked[inst] then return end
        Addon.soundHooked[inst] = true
        inst.Played:Connect(function() PlaySound(kind) end)
        inst:GetPropertyChangedSignal("Playing"):Connect(function()
            if inst.Playing then PlaySound(kind) end
        end)
    end

    AddConnection("SoundScan", RunService.Heartbeat:Connect(function()
        if not Addon.soundOn then return end
        local function scan(container)
            if not container then return end
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local kind = tool.Name == "Gun" and "sheriff" or (tool.Name == "Knife" and "murder" or nil)
                    if kind then
                        local handle = tool:FindFirstChild("Handle")
                        if handle then
                            for _, c in ipairs(handle:GetChildren()) do
                                if c:IsA("Sound") and (c.Name == "GunKill" or c.Name == "Kill") then
                                    Hook(c, kind)
                                end
                            end
                        end
                    end
                end
            end
        end
        scan(LocalPlayer.Character)
        scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    end))
end

-- ============================================================
-- ANTI FLING / VOID / TRAP
-- ============================================================
local function InitAnti()
    AddConnection("AntiVoid", RunService.Heartbeat:Connect(function()
        if Addon.antiVoidOn then
            pcall(function() workspace.FallenPartsDestroyHeight = -9e9 end)
        else
            pcall(function() workspace.FallenPartsDestroyHeight = Addon.antiVoidOrig end)
        end
    end))

    AddConnection("AntiFling", RunService.Stepped:Connect(function()
        if not Addon.antiFlingOn then
            for c, entry in pairs(Addon.antiFlingCache) do
                for p, v in pairs(entry) do
                    if p and p.Parent then pcall(function() p.CanCollide = v end) end
                end
            end
            Addon.antiFlingCache = {}
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local v = hrp.AssemblyLinearVelocity
                if v.Magnitude > 250 then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end
            return
        end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local c = p.Character
                local entry = Addon.antiFlingCache[c]
                if not entry then entry = {}; Addon.antiFlingCache[c] = entry end
                for _, part in ipairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if entry[part] == nil then entry[part] = part.CanCollide end
                        if part.CanCollide then part.CanCollide = false end
                    end
                end
            end
        end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local v = hrp.AssemblyLinearVelocity
            if v.Magnitude > 250 then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end))

    AddConnection("AntiTrap", RunService.Heartbeat:Connect(function()
        if not Addon.antiTrapOn then return end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if hum.WalkSpeed <= 1 then hum.WalkSpeed = Addon.antiTrapSpeedCache
        else Addon.antiTrapSpeedCache = hum.WalkSpeed end
        if hum.JumpPower <= 1 then hum.JumpPower = Addon.antiTrapJumpCache
        else Addon.antiTrapJumpCache = hum.JumpPower end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do
                if g.Name == "TrapGUI" then pcall(function() g:Destroy() end) end
            end
        end
    end))
end

-- ============================================================
-- TP / FLING TOOL
-- ============================================================
local function GiveTPTool()
    if not Addon.tpToolOn then return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then return end
    if bp:FindFirstChild("tp") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("tp")) then return end
    local tool = Instance.new("Tool")
    tool.Name = "tp"; tool.RequiresHandle = false; tool.CanBeDropped = false
    tool.Parent = bp
    Addon.tpToolObj = tool
    tool.Activated:Connect(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local mouse = LocalPlayer:GetMouse()
        local hit = mouse.Hit
        if hit then hrp.CFrame = CFrame.new(hit.X, hit.Y + 3, hit.Z) end
    end)
end

local function RemoveTPTool()
    if Addon.tpToolObj then pcall(function() Addon.tpToolObj:Destroy() end) Addon.tpToolObj = nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local t = bp:FindFirstChild("tp"); if t then pcall(function() t:Destroy() end) end end
    if LocalPlayer.Character then
        local t = LocalPlayer.Character:FindFirstChild("tp")
        if t then pcall(function() t:Destroy() end) end
    end
end

local function GiveFlingTool()
    if not Addon.flingToolOn then return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not bp then return end
    if bp:FindFirstChild("fling") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("fling")) then return end
    local tool = Instance.new("Tool")
    tool.Name = "fling"; tool.RequiresHandle = false; tool.CanBeDropped = false
    tool.Parent = bp
    Addon.flingToolObj = tool
    tool.Activated:Connect(function()
        local mouse = LocalPlayer:GetMouse()
        local target = mouse.Target
        local found = nil
        if target then
            local node = target
            while node and node ~= workspace do
                local p = Players:GetPlayerFromCharacter(node)
                if p and p ~= LocalPlayer then found = p; break end
                node = node.Parent
            end
        end
        if not found then return end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local thrp = found.Character and found.Character:FindFirstChild("HumanoidRootPart")
        if not myHRP or not thrp then return end
        Addon.flingActive = (Addon.flingActive or 0) + 1
        local orig = myHRP.CFrame
        local t0 = tick()
        task.spawn(function()
            repeat
                if myHRP and myHRP.Parent and thrp and thrp.Parent then
                    myHRP.CFrame = CFrame.new(thrp.Position) * CFrame.Angles(math.rad(math.random(0,360)), math.rad(math.random(0,360)), math.rad(math.random(0,360)))
                    myHRP.AssemblyLinearVelocity = Vector3.new(9e7, 9e7, 9e7)
                    myHRP.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                end
                task.wait()
            until tick() - t0 > 2
            if myHRP and myHRP.Parent then
                pcall(function() myHRP.CFrame = orig end)
                myHRP.AssemblyLinearVelocity = Vector3.zero
                myHRP.AssemblyAngularVelocity = Vector3.zero
            end
            Addon.flingActive = math.max(0, (Addon.flingActive or 1) - 1)
        end)
    end)
end

local function RemoveFlingTool()
    if Addon.flingToolObj then pcall(function() Addon.flingToolObj:Destroy() end) Addon.flingToolObj = nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local t = bp:FindFirstChild("fling"); if t then pcall(function() t:Destroy() end) end end
    if LocalPlayer.Character then
        local t = LocalPlayer.Character:FindFirstChild("fling")
        if t then pcall(function() t:Destroy() end) end
    end
end

local function InitTools()
    AddConnection("ToolsLoop", RunService.Heartbeat:Connect(function()
        if Addon.tpToolOn then GiveTPTool() end
        if Addon.flingToolOn then GiveFlingTool() end
    end))
end

-- ============================================================
-- FAKE POSITION
-- ============================================================
local function InitFakePos()
    local hookedMT = {}
    local function Hook(hrp)
        if hookedMT[hrp] then return end
        hookedMT[hrp] = true
        local mt = getrawmetatable(hrp)
        if not mt then return end
        local oldIdx = mt.__index
        local oldNew = mt.__newindex
        Addon.fakePosHookedMT[hrp] = { mt = mt }
        local newMT = {}
        for k, v in pairs(mt) do newMT[k] = v end
        newMT.__index = newcclosure(function(self, key)
            if not checkcaller() and key == "CFrame" and Addon.fakePosActive then
                return Addon.fakePosClientCF
            end
            return oldIdx(self, key)
        end)
        newMT.__newindex = newcclosure(function(self, key, value)
            if not checkcaller() and Addon.fakePosActive and (key == "CFrame" or key == "Position") then
                return
            end
            return oldNew(self, key, value)
        end)
        pcall(function() setrawmetatable(hrp, newMT) end)
    end
    AddConnection("FakePos", RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if Addon.fakePosOn then
            if not Addon.fakePosActive then
                Addon.fakePosActive = true
                Addon.fakePosClientCF = hrp.CFrame
                Hook(hrp)
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                        pcall(function() p.LocalTransparencyModifier = 0.6 end)
                    end
                end
            end
            Addon.fakePosClientCF = hrp.CFrame
            local oldCF = hrp.CFrame
            local fake = CFrame.new(
                math.random(-Addon.fakePosX, Addon.fakePosX),
                -math.random(0, Addon.fakePosY),
                math.random(-Addon.fakePosZ, Addon.fakePosZ)
            )
            pcall(function() sethiddenproperty(hrp, "NetworkIsSleeping", false) end)
            hrp.CFrame = fake
            RunService.RenderStepped:Wait()
            hrp.CFrame = oldCF
        else
            if Addon.fakePosActive then
                Addon.fakePosActive = false
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function() p.LocalTransparencyModifier = 0 end) end
                end
                for target, data in pairs(Addon.fakePosHookedMT) do
                    if data.mt then pcall(function() setrawmetatable(target, data.mt) end) end
                end
                Addon.fakePosHookedMT = {}
            end
        end
    end))
end

-- ============================================================
-- FLING — новая вкладка
-- ============================================================
local function FlingPlayer(target)
    if not target or not target.Character then return end
    local char = LocalPlayer.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    local thrp = target.Character:FindFirstChild("HumanoidRootPart")
    local th = target.Character:FindFirstChildOfClass("Humanoid")
    if not myHRP or not thrp or not th then return end
    if th.Health <= 0 then return end
    if th.Sit then return end

    Addon.flingActive = (Addon.flingActive or 0) + 1
    local orig = myHRP.CFrame
    local t0 = tick()
    local dur = 2
    task.spawn(function()
        repeat
            if myHRP and myHRP.Parent and thrp and thrp.Parent then
                local v = Addon.flingBypassVel and th.MoveDirection * th.WalkSpeed or thrp.AssemblyLinearVelocity
                local tv = v.Magnitude
                if tv < 50 then
                    for _ = 1, 4 do
                        myHRP.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(math.random(0,360)), 0, 0)
                        myHRP.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                        myHRP.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                        task.wait()
                        myHRP.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, -1.5, 0)
                        myHRP.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                        myHRP.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                        task.wait()
                    end
                else
                    myHRP.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, 1.5, th.WalkSpeed) * CFrame.Angles(math.rad(90), 0, 0)
                    myHRP.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    myHRP.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                    myHRP.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, -1.5, -th.WalkSpeed)
                    myHRP.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                    myHRP.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                    task.wait()
                end
            end
        until tick() - t0 > dur or not Addon.flingOn

        if myHRP and myHRP.Parent then
            pcall(function() myHRP.CFrame = orig end)
            myHRP.AssemblyLinearVelocity = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
        end
        Addon.flingActive = math.max(0, (Addon.flingActive or 1) - 1)
    end)
end

local function GetFlingTargets()
    local out = {}
    if Addon.flingMode == "specific" then
        local name = Addon.flingTarget
        local p = name and name ~= "" and Players:FindFirstChild(name)
        if p and p ~= LocalPlayer then out[1] = p end
    elseif Addon.flingMode == "murderer" then
        local m = FindMurderer()
        if m then out[1] = m end
    elseif Addon.flingMode == "sheriff" then
        local s = FindSheriff()
        if s then out[1] = s end
    elseif Addon.flingMode == "all" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then out[#out+1] = p end
        end
    end
    return out
end

local function InitFling()
    AddConnection("FlingLoop", RunService.Heartbeat:Connect(function()
        if not Addon.flingOn then return end
        if Addon.flingActive > 0 then return end
        if tick() < (Addon.flingCooldown or 0) then return end
        local targets = GetFlingTargets()
        if #targets == 0 then return end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end
        for _, t in ipairs(targets) do
            local thrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
            if thrp and (thrp.Position - myHRP.Position).Magnitude <= Addon.flingRange then
                FlingPlayer(t)
                Addon.flingCooldown = tick() + 0.5
                break
            end
        end
    end))
end

-- ============================================================
-- UI HOOKS — добавляем в существующие табы
-- ============================================================
local function BuildUI()
    local tabCombat = Tabs.Combat
    local tabVisual = Tabs.Visual
    local tabUtility = Tabs.Utility
    local tabSettings = Tabs.Settings
    local tabAutoFarm = Tabs.AutoFarm

    -- Silent Aim (в Бой)
    tabCombat:AddDropdown("SilentAimMode", {
        Title = L("silent_aim_mode"),
        Values = { L("silent_aim_v1"), L("silent_aim_v2") },
        Default = L("silent_aim_v2"),
    }):OnChanged(function(v)
        Addon.silentMode = (v == L("silent_aim_v1")) and "v1" or "v2"
        if Addon.silentMode == "v1" then UninstallSilentHook() else InstallSilentHook() end
    end)
    tabCombat:AddToggle("SilentAim", { Title = L("silent_aim"), Default = false }):OnChanged(function(v)
        Addon.silentOn = v
        if v and Addon.silentMode == "v2" then InstallSilentHook() end
    end)
    tabCombat:AddToggle("AutoShoot", { Title = L("auto_shoot"), Default = false }):OnChanged(function(v)
        Addon.autoShootOn = v
    end)
    tabCombat:AddSlider("AutoShootDelay", { Title = L("auto_shoot_delay"), Min = 0, Max = 600, Default = 0, Rounding = 0 }):OnChanged(function(v)
        Addon.autoDelay = v
    end)

    -- Нож
    tabCombat:AddToggle("KnifeSilent", { Title = L("knife_silent"), Default = false }):OnChanged(function(v) Addon.knifeSilentOn = v end)
    tabCombat:AddToggle("KnifePred", { Title = L("knife_pred"), Default = true }):OnChanged(function(v) Addon.knifePredOn = v end)
    tabCombat:AddSlider("KnifeLead", { Title = L("knife_lead"), Min = 0, Max = 320, Default = 100, Rounding = 0 }):OnChanged(function(v) Addon.knifeLead = v / 100 end)
    tabCombat:AddSlider("KnifeAir", { Title = L("knife_air"), Min = 0, Max = 120, Default = 35, Rounding = 0 }):OnChanged(function(v) Addon.knifeAir = v / 100 end)
    tabCombat:AddSlider("KnifeOffset", { Title = L("knife_offset"), Min = -80, Max = 220, Default = 0, Rounding = 0 }):OnChanged(function(v) Addon.knifeOffset = v / 1000 end)
    tabCombat:AddToggle("KnifeInsta", { Title = L("knife_insta"), Default = false }):OnChanged(function(v) Addon.knifeInstaOn = v end)
    tabCombat:AddSlider("KnifeRadius", { Title = L("knife_radius"), Min = 2, Max = 40, Default = 12, Rounding = 0 }):OnChanged(function(v) Addon.knifeRadius = v end)

    -- KillAura v2
    tabCombat:AddDropdown("KillAuraVersion", {
        Title = L("kill_aura_version"),
        Values = { L("kill_aura_v1"), L("kill_aura_v2") },
        Default = L("kill_aura_v1"),
    }):OnChanged(function(v)
        if v == L("kill_aura_v2") then
            Addon.kaV2On = true
            if Options.KillAura then Options.KillAura:SetValue(false) end
        else
            Addon.kaV2On = false
        end
    end)

    -- Backtrack
    tabVisual:AddToggle("Backtrack", { Title = L("backtrack"), Default = false }):OnChanged(function(v)
        Addon.btOn = v
        if not v then BtDestroy() end
    end)
    tabVisual:AddColorPicker("BtColor", { Title = L("backtrack_color"), Default = Color3.fromRGB(255, 60, 60) }):OnChanged(function(c) Addon.btColor = c end)

    -- Tracer
    tabVisual:AddToggle("Tracer", { Title = L("tracer"), Default = false }):OnChanged(function(v) Addon.tracerOn = v end)
    tabVisual:AddColorPicker("TracerColor", { Title = L("tracer_color"), Default = Color3.fromRGB(133, 220, 255) }):OnChanged(function(c) Addon.tracerColor = c end)
    tabVisual:AddSlider("TracerDur", { Title = L("tracer_duration"), Min = 0.1, Max = 5, Default = 1, Rounding = 1 }):OnChanged(function(v) Addon.tracerDur = v end)

    -- China Hat
    tabVisual:AddToggle("ChinaHat", { Title = L("china_hat"), Default = false }):OnChanged(function(v)
        Addon.chinaHatOn = v
        if not v then ChinaHatClear() end
    end)
    tabVisual:AddColorPicker("ChinaHatColor", { Title = L("china_hat_color"), Default = Color3.fromRGB(255, 60, 60) }):OnChanged(function(c) Addon.chinaHatColor = c end)

    -- Self Chams
    tabVisual:AddToggle("SelfChams", { Title = L("self_chams"), Default = false }):OnChanged(function(v)
        Addon.selfChamsOn = v
        if not v then SelfChamsClear() end
    end)
    tabVisual:AddColorPicker("SelfChamsColor", { Title = L("self_chams_color"), Default = Color3.fromRGB(120, 60, 255) }):OnChanged(function(c) Addon.selfChamsColor = c end)

    -- Movement Graph
    tabVisual:AddToggle("MovGraph", { Title = L("mov_graph"), Default = false }):OnChanged(function(v)
        Addon.movGraphOn = v
        if not v then MovGraphClear() end
    end)
    tabVisual:AddColorPicker("MovGraphColor", { Title = L("mov_graph_color"), Default = Color3.fromRGB(242, 242, 242) }):OnChanged(function(c) Addon.movGraphColor = c end)
    tabVisual:AddSlider("MovGraphWidth", { Title = L("mov_graph_width"), Min = 180, Max = 420, Default = 280, Rounding = 0 }):OnChanged(function(v) Addon.movGraphWidth = v end)
    tabVisual:AddSlider("MovGraphHeight", { Title = L("mov_graph_height"), Min = 40, Max = 120, Default = 72, Rounding = 0 }):OnChanged(function(v) Addon.movGraphHeight = v end)
    tabVisual:AddSlider("MovGraphY", { Title = L("mov_graph_y"), Min = -200, Max = 400, Default = 180, Rounding = 0 }):OnChanged(function(v) Addon.movGraphY = v end)

    -- Anti
    tabUtility:AddToggle("AntiFling", { Title = L("anti_fling"), Default = false }):OnChanged(function(v) Addon.antiFlingOn = v end)
    tabUtility:AddToggle("AntiVoid", { Title = L("anti_void"), Default = false }):OnChanged(function(v) Addon.antiVoidOn = v end)
    tabUtility:AddToggle("AntiTrap", { Title = L("anti_trap"), Default = false }):OnChanged(function(v) Addon.antiTrapOn = v end)

    -- FakePos
    tabUtility:AddToggle("FakePos", { Title = L("fake_pos"), Default = false }):OnChanged(function(v) Addon.fakePosOn = v end)
    tabUtility:AddSlider("FakePosX", { Title = L("fake_pos_x"), Min = 1, Max = 9, Default = 9, Rounding = 0 }):OnChanged(function(v) Addon.fakePosX = v * 1e9 end)
    tabUtility:AddSlider("FakePosY", { Title = L("fake_pos_y"), Min = 1, Max = 9, Default = 9, Rounding = 0 }):OnChanged(function(v) Addon.fakePosY = v * 1e9 end)
    tabUtility:AddSlider("FakePosZ", { Title = L("fake_pos_z"), Min = 1, Max = 9, Default = 9, Rounding = 0 }):OnChanged(function(v) Addon.fakePosZ = v * 1e9 end)

    -- Tools
    tabUtility:AddToggle("TPTool", { Title = L("tp_tool"), Default = false }):OnChanged(function(v)
        Addon.tpToolOn = v
        if not v then RemoveTPTool() end
    end)
    tabUtility:AddToggle("FlingTool", { Title = L("fling_tool"), Default = false }):OnChanged(function(v)
        Addon.flingToolOn = v
        if not v then RemoveFlingTool() end
    end)
    tabUtility:AddToggle("FlingBypass", { Title = L("fling_bypass"), Default = false }):OnChanged(function(v) Addon.flingBypassVel = v end)

    -- Sound Replacer
    tabSettings:AddToggle("SoundReplacer", { Title = L("sound_replacer"), Default = false }):OnChanged(function(v) Addon.soundOn = v end)
    tabSettings:AddDropdown("SoundSheriff", { Title = L("sound_sheriff"), Values = { "mc bow", "neverlose", "rust", "primordial", "sparkle", "break" }, Default = "mc bow" }):OnChanged(function(v) Addon.soundSheriff = v end)
    tabSettings:AddDropdown("SoundMurder", { Title = L("sound_murder"), Values = { "skeet", "neverlose", "rust", "primordial", "sparkle", "break" }, Default = "skeet" }):OnChanged(function(v) Addon.soundMurder = v end)
    tabSettings:AddSlider("SoundVol", { Title = L("sound_volume"), Min = 0.1, Max = 5, Default = 1, Rounding = 1 }):OnChanged(function(v) Addon.soundVol = v end)

    -- AutoFarm v2 (mode dropdown в существующий таб)
    tabAutoFarm:AddDropdown("AutoFarmVersion", {
        Title = L("autofarm_version"),
        Values = { L("autofarm_v1"), L("autofarm_v2") },
        Default = L("autofarm_v1"),
    }):OnChanged(function(v)
        Addon.farmV2On = (v == L("autofarm_v2"))
        if Options.AutoFarmCoins and Options.AutoFarmCoins.Value then
            Options.AutoFarmCoins:SetValue(false)
        end
    end)
    tabAutoFarm:AddSlider("FarmDownDepth", {
        Title = L("farm_down_depth"),
        Min = 5, Max = 40, Default = 14, Rounding = 0,
    }):OnChanged(function(v) Addon.farmDownDepth = v end)

    -- ========== FLING — новая вкладка ==========
    local tabFling = Window:AddTab({ Title = "Fling" })

    local function Reg(mn, t) ModuleNameToTitle[mn] = t end
    Reg("FlingToggle", "Fling")
    Reg("FlingMode", "Fling Mode")
    Reg("FlingTarget", "Fling Target")

    local function RefreshPlayerDropdown()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then list[#list+1] = p.Name end
        end
        table.sort(list)
        local cur = Options.FlingTarget and Options.FlingTarget.Value
        pcall(function()
            Options.FlingTarget:SetValues(list)
            Options.FlingTarget:Generate()
            if cur and cur ~= "" then
                for _, n in ipairs(list) do
                    if n == cur then Options.FlingTarget:SetValue(cur); return end
                end
            end
            if list[1] then Options.FlingTarget:SetValue(list[1]) end
        end)
    end

    tabFling:AddDropdown("FlingMode", {
        Title = "Режим таргета",
        Values = { "Murderer", "Sheriff", "Specific Player", "All Players" },
        Default = "Murderer",
        Multi = false,
    }):OnChanged(function(v)
        if v == "Murderer" then Addon.flingMode = "murderer"
        elseif v == "Sheriff" then Addon.flingMode = "sheriff"
        elseif v == "Specific Player" then Addon.flingMode = "specific"
        elseif v == "All Players" then Addon.flingMode = "all" end
    end)

    tabFling:AddDropdown("FlingTarget", {
        Title = "Игрок (для Specific)",
        Values = (function()
            local l = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then l[#l+1] = p.Name end
            end
            return l
        end)(),
        Default = nil,
        Multi = false,
    }):OnChanged(function(v)
        if type(v) == "table" then v = v[1] end
        Addon.flingTarget = v or ""
    end)

    tabFling:AddSlider("FlingRange", {
        Title = "Дальность флинга",
        Min = 20, Max = 2000, Default = 500, Rounding = 0,
    }):OnChanged(function(v) Addon.flingRange = v end)

    tabFling:AddToggle("FlingBypassVelTab", {
        Title = "Bypass Velocity",
        Default = false,
    }):OnChanged(function(v) Addon.flingBypassVel = v end)

    tabFling:AddToggle("FlingToggle", {
        Title = "Fling ON",
        Default = false,
    }):OnChanged(function(v)
        Addon.flingOn = v
        Notify(L("notify_title"), "Fling " .. (v and "ON" or "OFF"), 1.5)
    end)

    tabFling:AddButton({
        Title = "Fling один раз",
        Callback = function()
            local targets = GetFlingTargets()
            if #targets == 0 then Notify(L("notify_title"), "Нет таргета", 2); return end
            FlingPlayer(targets[1])
            Notify(L("notify_title"), "Fling: " .. targets[1].Name, 2)
        end,
    })

    -- автообновление списка игроков
    AddConnection("FlingPlayerAdd", Players.PlayerAdded:Connect(function() task.wait(1); RefreshPlayerDropdown() end))
    AddConnection("FlingPlayerRem", Players.PlayerRemoving:Connect(function()
        task.wait(0.5)
        RefreshPlayerDropdown()
    end))

    -- регистрация в биндах
    if Tabs.Keybinds then
        pcall(function()
            -- уже нечего добавлять, биндов в FH.Core нет для Fling
        end)
    end
end

-- ============================================================
-- ЗАПУСК
-- ============================================================
logInfo("Addon two.lua загружается...")

local ok, err = pcall(function()
    InstallSilentHook()
    InitSilent()
    InitKnife()
    InitKAv2()
    InitBacktrack()
    InitTracer()
    InitChinaHat()
    InitSelfChams()
    InitMovGraph()
    InitSounds()
    InitAnti()
    InitTools()
    InitFakePos()
    InitFling()
end)
if not ok then logErr("Ошибка инициализации: " .. tostring(err)) end

local okUI, errUI = pcall(BuildUI)
if not okUI then logErr("Ошибка UI: " .. tostring(errUI)) else logInfo("Addon UI собран") end

logInfo("two.lua полностью загружен")
