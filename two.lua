-- ============================================================
-- FORTNIHUB v14.2.0 — two.lua
-- Silent / Knife / KillAura v2 / AutoFarm v2 / Backtrack / Tracer
-- China Hat / Self Chams / Movement Graph / Anti / Tools / FakePos
-- Sound Replacer / Fling tab
-- NEW: Off-screen arrows, Material Chams, Custom Crosshair,
--      Shaders, Time Changer, Custom Fog, World Effects,
--      World Aura, Landing Circle
-- ============================================================

local FH = (getgenv and getgenv().FH) or _G.FH or rawget(_G, "FH")
if not FH then warn("[FH] two.lua: FH не найден"); return end
if type(FH.Tabs) ~= "table" then warn("[FH] two.lua: FH.Tabs пустой"); return end

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
local Lighting = FH.Lighting
local logInfo = FH.logInfo
local logWarn = FH.logWarn
local logErr = FH.logErr
local ModuleNameToTitle = FH.ModuleNameToTitle
local L = FH.L
local TweenService = game:GetService("TweenService")

-- ============================================================
-- STATE
-- ============================================================
local A = {
    silentMode="v2", silentOn=false, autoShootOn=false, autoDelay=0,
    origMouseTarget=nil, origTargetPos=nil, weaponService=nil, lastFire=0,
    knifeSilent=false, knifeInsta=false, knifeRadius=12, knifeLead=1.0, knifeAir=0.35, knifeOffset=0, knifeTrackers={}, knifeOrigAim=nil,
    kaV2=false, kaV2Dist=30,
    farmV2=false, farmDownDepth=14,
    btOn=false, btColor=Color3.fromRGB(255,60,60), btModel=nil, btHistory={}, btCap=256, btFirst=1, btCount=0, btPairs={},
    tracerOn=false, tracerColor=Color3.fromRGB(133,220,255), tracerDur=1, tracerConn=nil,
    soundOn=false, soundSheriff="mc bow", soundMurder="skeet", soundVol=1, soundHooked={}, soundPool={}, soundLast={sheriff=0,murder=0},
    antiFling=false, antiVoid=false, antiTrap=false, antiFlingCache={}, antiVoidOrig=workspace.FallenPartsDestroyHeight, antiTrapSpd=16, antiTrapJmp=50,
    tpToolOn=false, flingToolOn=false, flingBypass=false, tpToolObj=nil, flingToolObj=nil,
    fakePosOn=false, fakePosX=9e9, fakePosY=9e9, fakePosZ=9e9, fakePosCF=CFrame.identity, fakePosHooked={}, fakePosActive=false,
    chinaHatOn=false, chinaHatColor=Color3.fromRGB(255,60,60), chinaHatParts={},
    selfChamsOn=false, selfChamsColor=Color3.fromRGB(120,60,255), selfChamsCache={},
    movGraphOn=false, movGraphColor=Color3.fromRGB(242,242,242), movGraphW=280, movGraphH=72, movGraphY=180, movGraphLines={}, movGraphShadows={}, movGraphText=nil, movGraphHist={},

    -- Fling
    flingOn=false, flingMode="murderer", flingTarget="", flingCooldown=0, flingRange=500, flingActive=0,

    -- NEW: Off-screen arrows
    arrowsOn=false, arrowsColorMur=Color3.fromRGB(255,60,60), arrowsColorShf=Color3.fromRGB(60,140,255),
    arrowsColorInno=Color3.fromRGB(255,255,255), arrowsSize=42, arrowsDist=260, arrowsPool={},

    -- NEW: Material Chams
    matChamsOn=false, matChamsType="ForceField",
    matChamsVisMur=Color3.fromRGB(255,60,60), matChamsOccMur=Color3.fromRGB(80,0,0),
    matChamsVisShf=Color3.fromRGB(60,140,255), matChamsOccShf=Color3.fromRGB(0,30,80),
    matChamsVisInno=Color3.fromRGB(255,255,255), matChamsOccInno=Color3.fromRGB(80,80,80),
    matChamsCache={},

    -- NEW: Custom Crosshair
    crosshairOn=false, crosshairHide=false, crosshairGap=4, crosshairLen=8, crosshairThick=2,
    crosshairColor=Color3.fromRGB(255,255,255), crosshairOutline=Color3.fromRGB(0,0,0), crosshairRot=0,
    crosshairLines={}, crosshairConn=nil, crosshairRotNow=0, crosshairGameGui=nil, crosshairOrigCursorIcon="",

    -- NEW: Shaders
    shaderOn=false, shaderType="morning", shaderConn=nil, shaderOrigEffects={}, shaderAccum=0,

    -- NEW: Time / Fog
    timeOn=false, timeValue=12,
    fogOn=false, fogColor=Color3.fromRGB(192,192,192), fogStart=0, fogEnd=1000,

    -- NEW: World FX
    fxOn=false, fxType="Snow", fxColor=Color3.fromRGB(150,200,255), fxRate=250, fxPart=nil, fxEmitter=nil, fxConn=nil,

    -- NEW: World Aura
    auraOn=false, auraType="angel", auraColor=Color3.fromRGB(133,220,255), auraParticles={}, auraCache={}, auraConn=nil, auraBT={},

    -- NEW: Landing Circle
    landOn=false, landColor=Color3.fromRGB(255,255,255), landTransp=1, landDur=0.82, landConn=nil,
}

local auraIds = { angel="97658130917593", starlight="134645216613107", heavenly="139300897520961", ribbon="132069507632161", sakura="81755778619404", wind="80694081850877", flow="119913533725648", star="73754563740680" }
local auraOrder = {"angel","starlight","heavenly","ribbon","sakura","wind","flow","star"}

-- ============================================================
-- HELPERS
-- ============================================================
local function GetRoundData()
    local ok, m = pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient")) end)
    if ok and type(m)=="table" then return m.PlayerData end
    return nil
end
local function AmMurderer()
    local d = GetRoundData(); if type(d)~="table" then return false end
    local me = d[LocalPlayer.Name]
    return me~=nil and me.Role=="Murderer" and not me.Dead
end
local function AmSheriff()
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("Gun") then return true end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp and bp:FindFirstChild("Gun") then return true end
    local d = GetRoundData()
    if type(d)=="table" then
        local me = d[LocalPlayer.Name]
        return me~=nil and (me.Role=="Sheriff" or me.Role=="Hero")
    end
    return false
end
local function GetGun()
    local c=LocalPlayer.Character
    if c then local g=c:FindFirstChild("Gun"); if g then return g,true end end
    local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local g=bp:FindFirstChild("Gun"); if g then return g,false end end
    return nil,false
end
local function GetKnife()
    local c=LocalPlayer.Character
    if c then local k=c:FindFirstChild("Knife"); if k then return k,true end end
    local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local k=bp:FindFirstChild("Knife"); if k then return k,false end end
    return nil,false
end
local function FindMurderer()
    local d = GetRoundData()
    if type(d)=="table" then
        for name,info in pairs(d) do
            if type(info)=="table" and info.Role=="Murderer" and not info.Dead then
                local p = Players:FindFirstChild(name)
                if p and p~=LocalPlayer then return p end
            end
        end
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Knife") then return p end
    end
    return nil
end
local function FindSheriff()
    local d = GetRoundData()
    if type(d)=="table" then
        for name,info in pairs(d) do
            if type(info)=="table" and not info.Dead and (info.Role=="Sheriff" or info.Role=="Hero") then
                local p = Players:FindFirstChild(name)
                if p and p~=LocalPlayer then return p end
            end
        end
    end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
    return nil
end
local function GetCachedGuns()
    local list={}
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v.Name=="GunDrop" and v:IsA("BasePart") then list[#list+1]=v end
    end
    return list
end

-- ============================================================
-- SILENT AIM
-- ============================================================
local function InstallSilent()
    if A.silentMode~="v2" then return end
    local ok,m = pcall(function() return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService")) end)
    if not ok or type(m)~="table" then return end
    A.weaponService = m
    if type(m.GetMouseTargetCFrame)=="function" and not A.origMouseTarget then
        A.origMouseTarget = m.GetMouseTargetCFrame
        local orig = A.origMouseTarget
        pcall(function() setreadonly(m,false) end)
        pcall(function()
            m.GetMouseTargetCFrame = function(self,...)
                if not A.silentOn then return orig(self,...) end
                local t = FindMurderer()
                if not t or not t.Character then return orig(self,...) end
                local thrp = t.Character:FindFirstChild("HumanoidRootPart")
                if not thrp then return orig(self,...) end
                local ping=0; pcall(function() ping=LocalPlayer:GetNetworkPing()*2 end)
                ping=math.clamp(ping,0.02,0.35)
                local v = thrp.AssemblyLinearVelocity
                return CFrame.new(thrp.Position + Vector3.new(v.X,0,v.Z)*ping)
            end
        end)
    end
    if type(m.GetTargetPosition)=="function" and not A.origTargetPos then
        A.origTargetPos = m.GetTargetPosition
        local o2 = A.origTargetPos
        pcall(function()
            m.GetTargetPosition = function(self,x,y,...)
                if not A.silentOn then return o2(self,x,y,...) end
                local t = FindMurderer()
                if not t or not t.Character then return o2(self,x,y,...) end
                local thrp = t.Character:FindFirstChild("HumanoidRootPart")
                if not thrp then return o2(self,x,y,...) end
                local ping=0; pcall(function() ping=LocalPlayer:GetNetworkPing()*2 end)
                ping=math.clamp(ping,0.02,0.35)
                local v = thrp.AssemblyLinearVelocity
                return CFrame.new(thrp.Position + Vector3.new(v.X,0,v.Z)*ping)
            end
        end)
    end
end
local function UninstallSilent()
    local m=A.weaponService; if not m then return end
    pcall(function() setreadonly(m,false) end)
    if A.origMouseTarget then pcall(function() m.GetMouseTargetCFrame=A.origMouseTarget end) end
    if A.origTargetPos then pcall(function() m.GetTargetPosition=A.origTargetPos end) end
end
local function InitSilent()
    AddConnection("AutoShoot", RunService.Heartbeat:Connect(function()
        if not A.autoShootOn then return end
        if not AmSheriff() then return end
        local t = FindMurderer(); if not t then return end
        local gun, eq = GetGun(); if not gun then return end
        local now=os.clock()
        if now-A.lastFire < math.max(0,A.autoDelay/1000) then return end
        if not eq then
            local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum:EquipTool(gun) end) end
            return
        end
        local thrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
        if not thrp then return end
        local rem = gun:FindFirstChild("Shoot")
        if rem and rem:IsA("RemoteEvent") then
            local o = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if o then
                pcall(function() rem:FireServer(o.CFrame, CFrame.new(thrp.Position)) end)
                A.lastFire = now
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
    local t = A.knifeTrackers[p]
    if not t then t={s={},n=0,i=0,vel=Vector3.zero,lastPos=nil,lastTime=now}; A.knifeTrackers[p]=t end
    local pos = hrp.Position
    if t.lastPos and (pos-t.lastPos).Magnitude > 0.005 then
        t.i = t.i%16+1
        t.s[t.i] = {t=now,p=pos}
        if t.n<16 then t.n=t.n+1 end
        if t.n>=3 then
            local newest = t.s[t.i].t
            local used, sumD = 0,0
            for k=0,t.n-1 do
                local idx = (t.i-k-1)%16+1
                local s = t.s[idx]
                if not s or newest-s.t>0.25 then break end
                used=used+1; sumD=sumD+(s.t-newest)
            end
            if used>=3 then
                local meanD = sumD/used
                local num, den = Vector3.zero, 0
                for k=0,used-1 do
                    local idx=(t.i-k-1)%16+1
                    local s=t.s[idx]; if not s then break end
                    local dd=(s.t-newest)-meanD
                    num=num+s.p*dd; den=den+dd*dd
                end
                if den>1e-8 then t.vel = num/den end
            end
        end
    end
    t.lastPos, t.lastTime = pos, now
    return t, hrp
end
local function KnifeResolve()
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("Knife") then return nil end
    local myHRP = c:FindFirstChild("HumanoidRootPart"); if not myHRP then return nil end
    local best, bd = nil, math.huge
    local now = os.clock()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local t,hrp = KnifeTrack(p, now)
            if hrp then
                local d = (hrp.Position-myHRP.Position).Magnitude
                if d<bd then bd=d; best={p=p,hrp=hrp,track=t} end
            end
        end
    end
    if not best then return nil end
    local base = best.hrp.Position
    local vel = best.track and best.track.vel or best.hrp.AssemblyLinearVelocity
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
local function InitKnife()
    AddConnection("KnifeHook", RunService.Heartbeat:Connect(function()
        if not A.knifeSilent then return end
        local m = A.weaponService
        if not m then
            local ok,mm = pcall(function() return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService")) end)
            if ok then m=mm; A.weaponService=m end
        end
        if not m then return end
        if not A.knifeOrigAim then A.knifeOrigAim = m.GetMouseTargetCFrame end
        local orig = A.knifeOrigAim
        local hasK = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife")
        if not hasK then
            if m.GetMouseTargetCFrame ~= orig and orig then
                pcall(function() setreadonly(m,false); m.GetMouseTargetCFrame=orig end)
            end
            return
        end
        pcall(function() setreadonly(m,false) end)
        pcall(function()
            m.GetMouseTargetCFrame = function(self,...)
                if A.knifeSilent then
                    local aim = KnifeResolve()
                    if aim then return CFrame.new(aim) end
                end
                if orig then return orig(self,...) end
            end
        end)
    end))
    AddConnection("KnifeInsta", RunService.Heartbeat:Connect(function()
        if not A.knifeInsta then return end
        if not AmMurderer() then return end
        local k, eq = GetKnife(); if not k or not eq then return end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end
        local ev = k:FindFirstChild("Events"); if not ev then return end
        local stab = ev:FindFirstChild("KnifeStabbed")
        local touch = ev:FindFirstChild("HandleTouched")
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                if thrp and (thrp.Position-myHRP.Position).Magnitude<=A.knifeRadius then
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
        if not A.kaV2 then return end
        if not AmMurderer() then return end
        local c = LocalPlayer.Character; if not c then return end
        local k = c:FindFirstChild("Knife"); if not k then return end
        local ev = k:FindFirstChild("Events"); if not ev then return end
        local stab = ev:FindFirstChild("KnifeStabbed")
        local touch = ev:FindFirstChild("HandleTouched")
        if not stab or not touch then return end
        local myHRP = c:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
        local vic = {}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local thrp = p.Character:FindFirstChild("HumanoidRootPart")
                if thrp and (thrp.Position-myHRP.Position).Magnitude<=A.kaV2Dist then
                    vic[#vic+1]=thrp
                end
            end
        end
        if #vic>0 then
            pcall(function() stab:FireServer() end)
            for _,v in ipairs(vic) do pcall(function() touch:FireServer(v) end) end
        end
    end))
end

-- ============================================================
-- BACKTRACK
-- ============================================================
local function BtDestroy()
    if A.btModel then pcall(function() A.btModel:Destroy() end) A.btModel=nil end
    A.btFirst, A.btCount = 1,0
end
local function BtBuild()
    BtDestroy()
    local c = LocalPlayer.Character; if not c then return end
    c.Archivable = true
    local ok, m = pcall(function() return c:Clone() end)
    c.Archivable = false
    if not ok or not m then return end
    local rp = {}
    for _,o in c:GetDescendants() do if o:IsA("BasePart") then rp[#rp+1]=o end end
    local ci = 0; A.btPairs = {}
    for _,o in m:GetDescendants() do
        if o:IsA("Script") or o:IsA("LocalScript") then pcall(function() o:Destroy() end)
        elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then pcall(function() o:Destroy() end)
        elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") then pcall(function() o:Destroy() end)
        elseif o:IsA("BasePart") then
            o.Anchored=true; o.CanCollide=false; o.CanQuery=false; o.CastShadow=false
            if o.Name=="HumanoidRootPart" then o.Transparency=1
            else o.Material=Enum.Material.ForceField; o.Color=A.btColor; o.Transparency=0 end
            ci=ci+1; A.btPairs[#A.btPairs+1]={o,rp[ci]}
        end
    end
    local hum = m:FindFirstChildOfClass("Humanoid"); if hum then pcall(function() hum:Destroy() end) end
    m.Parent = workspace; A.btModel = m
end
local function InitBt()
    AddConnection("Bt", RunService.Heartbeat:Connect(function()
        if not A.btOn then if A.btModel then BtDestroy() end return end
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        if not A.btModel then BtBuild(); if not A.btModel then return end end
        if not A.btModel.Parent then A.btModel.Parent = workspace end
        local now = os.clock(); local base = hrp.CFrame
        if A.btCount < A.btCap then A.btCount = A.btCount+1
        else A.btFirst = A.btFirst%A.btCap+1 end
        A.btHistory[(A.btFirst+A.btCount-2)%A.btCap+1] = {now, base}
        local ping=0.15
        pcall(function() ping = math.clamp(LocalPlayer:GetNetworkPing()*2, 0.05, 0.6) end)
        local target = now - ping; local cf = base
        for k=A.btCount,1,-1 do
            local s = A.btHistory[(A.btFirst+k-2)%A.btCap+1]
            if s and s[1]<=target then cf=s[2]; break end
        end
        local inv = hrp.CFrame:Inverse()
        for i=1,#A.btPairs do
            local cp,rp2 = A.btPairs[i][1], A.btPairs[i][2]
            if cp and cp.Parent and rp2 and rp2.Parent then
                cp.CFrame = cf*(inv*rp2.CFrame)
            end
        end
    end))
end

-- ============================================================
-- TRACER
-- ============================================================
local function InitTracer()
    AddConnection("TracerCheck", RunService.Heartbeat:Connect(function()
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
            local beam = Instance.new("Beam")
            beam.FaceCamera=true; beam.Width0=0.25; beam.Width1=0.25
            beam.LightEmission=3; beam.LightInfluence=0; beam.Brightness=2.5
            beam.Texture="rbxassetid://12781800668"; beam.TextureSpeed=1.5
            beam.Color=ColorSequence.new(A.tracerColor); beam.Transparency=NumberSequence.new(0.1)
            beam.Attachment0=p1:FindFirstChildOfClass("Attachment"); beam.Attachment1=p2:FindFirstChildOfClass("Attachment")
            beam.Parent=p1
            task.delay(A.tracerDur, function() pcall(function() TweenService:Create(beam,TweenInfo.new(0.2),{Width0=0,Width1=0}):Play() end) end)
            task.delay(A.tracerDur+0.5, function() pcall(function() p1:Destroy() end); pcall(function() p2:Destroy() end) end)
        end)
    end))
end

-- ============================================================
-- CHINA HAT
-- ============================================================
local function ChinaHatClear()
    for _,p in ipairs(A.chinaHatParts) do if p and p.Parent then pcall(function() p:Destroy() end) end end
    A.chinaHatParts = {}
end
local function InitChinaHat()
    AddConnection("ChinaHat", RunService.Heartbeat:Connect(function()
        if not A.chinaHatOn then if #A.chinaHatParts>0 then ChinaHatClear() end return end
        local c = LocalPlayer.Character; local head = c and c:FindFirstChild("Head")
        if not head or not head:IsA("BasePart") then return end
        if #A.chinaHatParts==0 then
            local seg, r, h = 12, 0.9, 0.3
            for i=1,seg do
                local ang = (i-1)/seg*math.pi*2
                local nang = i/seg*math.pi*2
                local mid = (ang+nang)/2
                local x1,z1 = math.cos(ang)*r, math.sin(ang)*r
                local x1n,z1n = math.cos(nang)*r, math.sin(nang)*r
                local p = Instance.new("WedgePart")
                p.Anchored=false; p.CanCollide=false; p.CanQuery=false; p.Massless=true
                p.Color=A.chinaHatColor; p.Material=Enum.Material.SmoothPlastic
                p.Size=Vector3.new(r*0.35,0.1,h)
                p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
                p.Parent=head
                local ctr = Vector3.new((x1+x1n)/2*0.5, head.Size.Y*0.5+0.3, (z1+z1n)/2*0.5)
                p.CFrame = head.CFrame*CFrame.new(ctr)*CFrame.Angles(0,mid,math.rad(-10))
                local wc = Instance.new("WeldConstraint"); wc.Part0=head; wc.Part1=p; wc.Parent=p
                table.insert(A.chinaHatParts, p)
            end
        else
            for _,p in ipairs(A.chinaHatParts) do
                if p.Parent and p.Color~=A.chinaHatColor then p.Color=A.chinaHatColor end
            end
        end
    end))
end

-- ============================================================
-- SELF CHAMS
-- ============================================================
local function SelfChamsClear()
    for part,old in pairs(A.selfChamsCache) do
        if part and part.Parent then
            pcall(function() part.Material=old.mat; part.Color=old.col end)
        end
    end
    A.selfChamsCache = {}
end
local function InitSelfChams()
    AddConnection("SelfChams", RunService.Heartbeat:Connect(function()
        if not A.selfChamsOn then if next(A.selfChamsCache) then SelfChamsClear() end return end
        local c = LocalPlayer.Character; if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
                if not A.selfChamsCache[p] then A.selfChamsCache[p]={mat=p.Material,col=p.Color} end
                if p.Material~=Enum.Material.ForceField then pcall(function() p.Material=Enum.Material.ForceField end) end
                if p.Color~=A.selfChamsColor then pcall(function() p.Color=A.selfChamsColor end) end
            end
        end
    end))
end

-- ============================================================
-- MOVEMENT GRAPH
-- ============================================================
local function MovClear()
    for i=1,#A.movGraphLines do pcall(function() A.movGraphLines[i]:Remove() end) end
    for i=1,#A.movGraphShadows do pcall(function() A.movGraphShadows[i]:Remove() end) end
    if A.movGraphText then pcall(function() A.movGraphText:Remove() end) end
    A.movGraphLines={}; A.movGraphShadows={}; A.movGraphText=nil; A.movGraphHist={}
end
local function InitMov()
    AddConnection("Mov", RunService.RenderStepped:Connect(function(dt)
        if not A.movGraphOn then return end
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local v = hrp.AssemblyLinearVelocity
        local spd = math.sqrt(v.X*v.X+v.Z*v.Z)
        local now = os.clock()
        table.insert(A.movGraphHist, {t=now, v=spd})
        while #A.movGraphHist>200 do table.remove(A.movGraphHist,1) end
        while #A.movGraphHist>0 and now-A.movGraphHist[1].t>3 do table.remove(A.movGraphHist,1) end
        local w,h = A.movGraphW, A.movGraphH
        local vp = Camera.ViewportSize
        local x0 = vp.X*0.5-w*0.5
        local y0 = vp.Y*0.5+A.movGraphY-h*0.5
        local maxS = 30
        for _,s in ipairs(A.movGraphHist) do if s.v>maxS then maxS=s.v end end
        maxS = math.max(maxS,20)
        if not A.movGraphText then
            A.movGraphText = Drawing.new("Text"); A.movGraphText.Size=14; A.movGraphText.Outline=true
        end
        A.movGraphText.Text = string.format("%d", math.floor(spd+0.5))
        A.movGraphText.Position = Vector2.new(x0+w+6, y0+h*0.5-8)
        A.movGraphText.Color = A.movGraphColor
        A.movGraphText.Visible = true
        if #A.movGraphLines==0 then
            for i=1,200 do
                local sh = Drawing.new("Line"); sh.Color=Color3.new(0,0,0); sh.Thickness=3; sh.Transparency=0.4; sh.Visible=false
                table.insert(A.movGraphShadows, sh)
                local ln = Drawing.new("Line"); ln.Color=A.movGraphColor; ln.Thickness=1.5; ln.Transparency=1; ln.Visible=false
                table.insert(A.movGraphLines, ln)
            end
        end
        local hist = A.movGraphHist
        for i=1,#A.movGraphLines do
            if i<#hist then
                local a,b = hist[i], hist[i+1]
                local ax = x0+(a.t-(now-3))/3*w
                local ay = y0+h-(a.v/maxS)*h
                local bx = x0+(b.t-(now-3))/3*w
                local by = y0+h-(b.v/maxS)*h
                local ln = A.movGraphLines[i]; local sh = A.movGraphShadows[i]
                ln.From=Vector2.new(ax,ay); ln.To=Vector2.new(bx,by)
                sh.From=ln.From; sh.To=ln.To
                ln.Color=A.movGraphColor
                ln.Visible, sh.Visible = true, true
            else
                A.movGraphLines[i].Visible=false
                A.movGraphShadows[i].Visible=false
            end
        end
    end))
end

-- ============================================================
-- SOUND REPLACER
-- ============================================================
local function InitSounds()
    local BASE="https://github.com/khenn791/lmao/raw/refs/heads/main/"
    local CACHE="shitaro_sounds/"
    local REMOTE={["mc bow"]=true,["skeet"]=true,["neverlose"]=true,["rust"]=true,["primordial"]=true,["sparkle"]=true,["break"]=true}
    local function pull(name)
        if A.soundPool[name] then return A.soundPool[name] end
        if not REMOTE[name] then return nil end
        if type(isfile)~="function" or type(writefile)~="function" then return nil end
        if type(isfolder)~="function" or type(makefolder)~="function" then return nil end
        pcall(function() if not isfolder(CACHE) then makefolder(CACHE) end end)
        local path = CACHE..name..".ogg"
        if not isfile(path) then
            local url = BASE..(string.gsub(name," ","%%20"))..".ogg"
            local ok,data = pcall(function() return game:HttpGet(url) end)
            if not ok or type(data)~="string" or #data<1024 then return nil end
            if not pcall(writefile,path,data) then return nil end
        end
        local cust = getcustomasset or getsynasset
        if type(cust)~="function" then return nil end
        local ok,id = pcall(cust,path)
        if not ok or type(id)~="string" then return nil end
        A.soundPool[name]=id; return id
    end
    local function play(kind)
        if not A.soundOn then return end
        local name = kind=="sheriff" and A.soundSheriff or A.soundMurder
        local id = pull(name); if not id then return end
        local now = os.clock()
        if now-(A.soundLast[kind] or 0)<0.15 then return end
        A.soundLast[kind]=now
        local SS = game:GetService("SoundService")
        local s = Instance.new("Sound"); s.SoundId=id; s.Volume=A.soundVol; s.Parent=SS
        s:Play()
        task.delay(8, function() pcall(function() s:Destroy() end) end)
    end
    local function hook(inst,kind)
        if A.soundHooked[inst] then return end
        A.soundHooked[inst]=true
        inst.Played:Connect(function() play(kind) end)
        inst:GetPropertyChangedSignal("Playing"):Connect(function() if inst.Playing then play(kind) end end)
    end
    AddConnection("SoundScan", RunService.Heartbeat:Connect(function()
        if not A.soundOn then return end
        local function scan(cont)
            if not cont then return end
            for _,t in ipairs(cont:GetChildren()) do
                if t:IsA("Tool") then
                    local kind = t.Name=="Gun" and "sheriff" or (t.Name=="Knife" and "murder" or nil)
                    if kind then
                        local h = t:FindFirstChild("Handle")
                        if h then
                            for _,c2 in ipairs(h:GetChildren()) do
                                if c2:IsA("Sound") and (c2.Name=="GunKill" or c2.Name=="Kill") then hook(c2,kind) end
                            end
                        end
                    end
                end
            end
        end
        scan(LocalPlayer.Character); scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    end))
end

-- ============================================================
-- ANTI
-- ============================================================
local function InitAnti()
    AddConnection("AntiVoid", RunService.Heartbeat:Connect(function()
        if A.antiVoid then pcall(function() workspace.FallenPartsDestroyHeight=-9e9 end)
        else pcall(function() workspace.FallenPartsDestroyHeight=A.antiVoidOrig end) end
    end))
    AddConnection("AntiFling", RunService.Stepped:Connect(function()
        if not A.antiFling then
            for c,entry in pairs(A.antiFlingCache) do
                for p,v in pairs(entry) do if p and p.Parent then pcall(function() p.CanCollide=v end) end end
            end
            A.antiFlingCache={}
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then local v=hrp.AssemblyLinearVelocity; if v.Magnitude>250 then hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end end
            return
        end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local c = p.Character
                local entry = A.antiFlingCache[c]; if not entry then entry={}; A.antiFlingCache[c]=entry end
                for _,part in ipairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if entry[part]==nil then entry[part]=part.CanCollide end
                        if part.CanCollide then part.CanCollide=false end
                    end
                end
            end
        end
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then local v=hrp.AssemblyLinearVelocity; if v.Magnitude>250 then hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end end
    end))
    AddConnection("AntiTrap", RunService.Heartbeat:Connect(function()
        if not A.antiTrap then return end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end
        if hum.WalkSpeed<=1 then hum.WalkSpeed=A.antiTrapSpd else A.antiTrapSpd=hum.WalkSpeed end
        if hum.JumpPower<=1 then hum.JumpPower=A.antiTrapJmp else A.antiTrapJmp=hum.JumpPower end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _,g in ipairs(pg:GetChildren()) do
                if g.Name=="TrapGUI" then pcall(function() g:Destroy() end) end
            end
        end
    end))
end

-- ============================================================
-- TOOLS
-- ============================================================
local function giveTP()
    if not A.tpToolOn then return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack"); if not bp then return end
    if bp:FindFirstChild("tp") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("tp")) then return end
    local t = Instance.new("Tool"); t.Name="tp"; t.RequiresHandle=false; t.CanBeDropped=false
    t.Parent=bp; A.tpToolObj=t
    t.Activated:Connect(function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        local mouse = LocalPlayer:GetMouse(); local h = mouse.Hit
        if h then hrp.CFrame = CFrame.new(h.X,h.Y+3,h.Z) end
    end)
end
local function rmTP()
    if A.tpToolObj then pcall(function() A.tpToolObj:Destroy() end) A.tpToolObj=nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local t=bp:FindFirstChild("tp"); if t then pcall(function() t:Destroy() end) end end
    if LocalPlayer.Character then local t=LocalPlayer.Character:FindFirstChild("tp"); if t then pcall(function() t:Destroy() end) end end
end
local function giveFlingTool()
    if not A.flingToolOn then return end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack"); if not bp then return end
    if bp:FindFirstChild("fling") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("fling")) then return end
    local t = Instance.new("Tool"); t.Name="fling"; t.RequiresHandle=false; t.CanBeDropped=false
    t.Parent=bp; A.flingToolObj=t
    t.Activated:Connect(function()
        local mouse = LocalPlayer:GetMouse(); local tgt = mouse.Target
        local found = nil
        if tgt then
            local node = tgt
            while node and node~=workspace do
                local p = Players:GetPlayerFromCharacter(node)
                if p and p~=LocalPlayer then found=p; break end
                node = node.Parent
            end
        end
        if not found then return end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local thrp = found.Character and found.Character:FindFirstChild("HumanoidRootPart")
        if not myHRP or not thrp then return end
        A.flingActive = (A.flingActive or 0)+1
        local orig = myHRP.CFrame; local t0 = tick()
        task.spawn(function()
            repeat
                if myHRP and myHRP.Parent and thrp and thrp.Parent then
                    myHRP.CFrame = CFrame.new(thrp.Position)*CFrame.Angles(math.rad(math.random(0,360)),math.rad(math.random(0,360)),math.rad(math.random(0,360)))
                    myHRP.AssemblyLinearVelocity = Vector3.new(9e7,9e7,9e7)
                    myHRP.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                end
                task.wait()
            until tick()-t0>2
            if myHRP and myHRP.Parent then
                pcall(function() myHRP.CFrame=orig end)
                myHRP.AssemblyLinearVelocity = Vector3.zero
                myHRP.AssemblyAngularVelocity = Vector3.zero
            end
            A.flingActive = math.max(0,(A.flingActive or 1)-1)
        end)
    end)
end
local function rmFlingTool()
    if A.flingToolObj then pcall(function() A.flingToolObj:Destroy() end) A.flingToolObj=nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then local t=bp:FindFirstChild("fling"); if t then pcall(function() t:Destroy() end) end end
    if LocalPlayer.Character then local t=LocalPlayer.Character:FindFirstChild("fling"); if t then pcall(function() t:Destroy() end) end end
end
local function InitTools()
    AddConnection("Tools", RunService.Heartbeat:Connect(function()
        if A.tpToolOn then giveTP() end
        if A.flingToolOn then giveFlingTool() end
    end))
end

-- ============================================================
-- FAKE POS
-- ============================================================
local function InitFakePos()
    local hooked = {}
    local function hook(hrp)
        if hooked[hrp] then return end
        hooked[hrp] = true
        local mt = getrawmetatable(hrp); if not mt then return end
        local oi = mt.__index; local on = mt.__newindex
        A.fakePosHooked[hrp] = { mt=mt }
        local nmt = {}; for k,v in pairs(mt) do nmt[k]=v end
        nmt.__index = newcclosure(function(self,key)
            if not checkcaller() and key=="CFrame" and A.fakePosActive then return A.fakePosCF end
            return oi(self,key)
        end)
        nmt.__newindex = newcclosure(function(self,key,value)
            if not checkcaller() and A.fakePosActive and (key=="CFrame" or key=="Position") then return end
            return on(self,key,value)
        end)
        pcall(function() setrawmetatable(hrp, nmt) end)
    end
    AddConnection("FakePos", RunService.Heartbeat:Connect(function()
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart"); if not hrp then return end
        if A.fakePosOn then
            if not A.fakePosActive then
                A.fakePosActive = true; A.fakePosCF = hrp.CFrame
                hook(hrp)
                for _,p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then pcall(function() p.LocalTransparencyModifier=0.6 end) end
                end
            end
            A.fakePosCF = hrp.CFrame
            local old = hrp.CFrame
            local fake = CFrame.new(math.random(-A.fakePosX,A.fakePosX), -math.random(0,A.fakePosY), math.random(-A.fakePosZ,A.fakePosZ))
            pcall(function() sethiddenproperty(hrp,"NetworkIsSleeping",false) end)
            hrp.CFrame = fake
            RunService.RenderStepped:Wait()
            hrp.CFrame = old
        else
            if A.fakePosActive then
                A.fakePosActive = false
                for _,p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then pcall(function() p.LocalTransparencyModifier=0 end) end
                end
                for t,d in pairs(A.fakePosHooked) do
                    if d.mt then pcall(function() setrawmetatable(t,d.mt) end) end
                end
                A.fakePosHooked = {}
            end
        end
    end))
end

-- ============================================================
-- FLING
-- ============================================================
local function DoFling(target)
    if not target or not target.Character then return end
    local c = LocalPlayer.Character
    local myHRP = c and c:FindFirstChild("HumanoidRootPart")
    local thrp = target.Character:FindFirstChild("HumanoidRootPart")
    local th = target.Character:FindFirstChildOfClass("Humanoid")
    if not myHRP or not thrp or not th then return end
    if th.Health<=0 or th.Sit then return end
    A.flingActive = (A.flingActive or 0)+1
    local orig = myHRP.CFrame; local t0 = tick()
    task.spawn(function()
        repeat
            if myHRP and myHRP.Parent and thrp and thrp.Parent then
                local v = A.flingBypass and th.MoveDirection*th.WalkSpeed or thrp.AssemblyLinearVelocity
                if v.Magnitude<50 then
                    for _=1,4 do
                        myHRP.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,1.5,0)*CFrame.Angles(math.rad(math.random(0,360)),0,0)
                        myHRP.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                        myHRP.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                        task.wait()
                        myHRP.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,-1.5,0)
                        myHRP.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                        myHRP.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                        task.wait()
                    end
                else
                    myHRP.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,1.5,th.WalkSpeed)*CFrame.Angles(math.rad(90),0,0)
                    myHRP.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                    myHRP.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                    task.wait()
                    myHRP.CFrame = CFrame.new(thrp.Position)*CFrame.new(0,-1.5,-th.WalkSpeed)
                    myHRP.AssemblyLinearVelocity = Vector3.new(9e7,9e7*10,9e7)
                    myHRP.AssemblyAngularVelocity = Vector3.new(9e8,9e8,9e8)
                    task.wait()
                end
            end
        until tick()-t0>2 or not A.flingOn
        if myHRP and myHRP.Parent then
            pcall(function() myHRP.CFrame=orig end)
            myHRP.AssemblyLinearVelocity = Vector3.zero
            myHRP.AssemblyAngularVelocity = Vector3.zero
        end
        A.flingActive = math.max(0,(A.flingActive or 1)-1)
    end)
end
local function GetFlingTargets()
    local out = {}
    if A.flingMode=="specific" then
        local p = A.flingTarget~="" and Players:FindFirstChild(A.flingTarget)
        if p and p~=LocalPlayer then out[1]=p end
    elseif A.flingMode=="murderer" then local m=FindMurderer(); if m then out[1]=m end
    elseif A.flingMode=="sheriff" then local s=FindSheriff(); if s then out[1]=s end
    elseif A.flingMode=="all" then
        for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then out[#out+1]=p end end
    end
    return out
end
local function InitFling()
    AddConnection("FlingLoop", RunService.Heartbeat:Connect(function()
        if not A.flingOn then return end
        if A.flingActive>0 then return end
        if tick()<A.flingCooldown then return end
        local tgs = GetFlingTargets(); if #tgs==0 then return end
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
        for _,t in ipairs(tgs) do
            local thrp = t.Character and t.Character:FindFirstChild("HumanoidRootPart")
            if thrp and (thrp.Position-myHRP.Position).Magnitude<=A.flingRange then
                DoFling(t); A.flingCooldown = tick()+0.5; break
            end
        end
    end))
end

-- ============================================================
-- NEW: OFF-SCREEN ARROWS
-- ============================================================
local function arrowsGetSlot(i)
    if A.arrowsPool[i] then return A.arrowsPool[i] end
    local img = Drawing.new("Triangle")
    img.Filled = true
    img.Thickness = 1
    img.Transparency = 1
    img.Visible = false
    A.arrowsPool[i] = img
    return img
end
local function InitArrows()
    AddConnection("Arrows", RunService.RenderStepped:Connect(function()
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
                    local arrow = arrowsGetSlot(idx)
                    if on and sp.X>0 and sp.X<vp.X and sp.Y>0 and sp.Y<vp.Y then
                        arrow.Visible = false
                    else
                        local dir = Vector2.new(sp.X-cx, sp.Y-cy)
                        if dir.Magnitude<0.01 then dir = Vector2.new(0,1) end
                        dir = dir.Unit
                        local px = cx + dir.X*A.arrowsDist
                        local py = cy + dir.Y*A.arrowsDist
                        local sz = A.arrowsSize
                        local perp = Vector2.new(-dir.Y, dir.X)
                        local tip = Vector2.new(px+dir.X*sz*0.5, py+dir.Y*sz*0.5)
                        local l = Vector2.new(px-dir.X*sz*0.5+perp.X*sz*0.5, py-dir.Y*sz*0.5+perp.Y*sz*0.5)
                        local r = Vector2.new(px-dir.X*sz*0.5-perp.X*sz*0.5, py-dir.Y*sz*0.5-perp.Y*sz*0.5)
                        arrow.PointA = tip
                        arrow.PointB = l
                        arrow.PointC = r
                        local role = GetRole(p)
                        local col = A.arrowsColorInno
                        if role=="murderer" then col = A.arrowsColorMur
                        elseif role=="sheriff" then col = A.arrowsColorShf end
                        arrow.Color = col
                        arrow.Visible = true
                    end
                end
            end
        end
        for i=idx+1,#A.arrowsPool do
            pcall(function() A.arrowsPool[i].Visible=false end)
        end
    end))
end

-- ============================================================
-- NEW: MATERIAL CHAMS
-- ============================================================
local function MatChamsClear()
    for c, entry in pairs(A.matChamsCache) do
        for part, old in pairs(entry) do
            if part and part.Parent then
                pcall(function() part.Material=old.mat end)
            end
        end
    end
    A.matChamsCache = {}
end
local function InitMatChams()
    AddConnection("MatChams", RunService.Heartbeat:Connect(function()
        if not A.matChamsOn then if next(A.matChamsCache) then MatChamsClear() end return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local c = p.Character
                local entry = A.matChamsCache[c]
                if not entry then entry={}; A.matChamsCache[c]=entry end
                local role = GetRole(p)
                local mat = Enum.Material.ForceField
                if A.matChamsType=="Flat" then mat = Enum.Material.SmoothPlastic
                elseif A.matChamsType=="Chromatic" then mat = Enum.Material.Foil end
                for _,part in ipairs(c:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not entry[part] then entry[part]={mat=part.Material} end
                        if part.Material~=mat then pcall(function() part.Material=mat end) end
                    end
                end
            end
        end
    end))
end

-- ============================================================
-- NEW: CUSTOM CROSSHAIR
-- ============================================================
local function CrosshairClear()
    for i=1,#A.crosshairLines do pcall(function() A.crosshairLines[i]:Remove() end) end
    A.crosshairLines = {}
    if A.crosshairConn then pcall(function() A.crosshairConn:Disconnect() end) A.crosshairConn=nil end
end
local function CrosshairBuild()
    CrosshairClear()
    for i=1,8 do
        local ln = Drawing.new("Line")
        ln.Visible = false
        ln.Color = (i%2==0) and A.crosshairOutline or A.crosshairColor
        ln.Thickness = (i%2==0) and (A.crosshairThick+2) or A.crosshairThick
        ln.Transparency = 1
        ln.ZIndex = (i%2==0) and 999 or 1000
        A.crosshairLines[i] = ln
    end
    A.crosshairConn = RunService.RenderStepped:Connect(function(dt)
        if not A.crosshairOn then
            for i=1,#A.crosshairLines do A.crosshairLines[i].Visible = false end
            return
        end
        local hasGun = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
        if not hasGun then
            for i=1,#A.crosshairLines do A.crosshairLines[i].Visible = false end
            return
        end
        if A.crosshairRot>0 then A.crosshairRotNow = (A.crosshairRotNow + dt*A.crosshairRot*100)%360
        else A.crosshairRotNow = 0 end
        local mp = UserInputService:GetMouseLocation()
        local cx, cy = mp.X, mp.Y
        local rad = math.rad(A.crosshairRotNow)
        local angles = {rad, math.pi/2+rad, math.pi+rad, 3*math.pi/2+rad}
        for i=1,4 do
            local a = angles[i]
            local li = (i-1)*2+1
            local oi = li+1
            local sx = cx + A.crosshairGap*math.cos(a)
            local sy = cy + A.crosshairGap*math.sin(a)
            local ex = cx + (A.crosshairGap+A.crosshairLen)*math.cos(a)
            local ey = cy + (A.crosshairGap+A.crosshairLen)*math.sin(a)
            local ox1 = cx + (A.crosshairGap-1)*math.cos(a)
            local oy1 = cy + (A.crosshairGap-1)*math.sin(a)
            local ox2 = cx + (A.crosshairGap+A.crosshairLen+1)*math.cos(a)
            local oy2 = cy + (A.crosshairGap+A.crosshairLen+1)*math.sin(a)
            local l1 = A.crosshairLines[li]; local l2 = A.crosshairLines[oi]
            if l1 then l1.From=Vector2.new(sx,sy); l1.To=Vector2.new(ex,ey); l1.Visible=true; l1.Color=A.crosshairColor; l1.Thickness=A.crosshairThick end
            if l2 then l2.From=Vector2.new(ox1,oy1); l2.To=Vector2.new(ox2,oy2); l2.Visible=true; l2.Color=A.crosshairOutline; l2.Thickness=A.crosshairThick+2 end
        end
    end)
end
local function InitCrosshair()
    AddConnection("CrosshairWatch", RunService.Heartbeat:Connect(function()
        if A.crosshairOn and #A.crosshairLines==0 then CrosshairBuild() end
    end))
end

-- ============================================================
-- NEW: SHADERS / TIME / FOG
-- ============================================================
local shaderPresets = {
    morning = { amb=Color3.fromRGB(10,10,10), bright=1.5, clock=7.5, cshiftB=Color3.fromRGB(0,0,0), cshiftT=Color3.fromRGB(200,200,200), exposure=0.3 },
    midday  = { amb=Color3.fromRGB(2,2,2), bright=3.25, clock=8, cshiftB=Color3.fromRGB(0,0,0), cshiftT=Color3.fromRGB(255,247,237), exposure=0.85 },
    evening = { amb=Color3.fromRGB(2,2,2), bright=2.25, clock=16, cshiftB=Color3.fromRGB(0,0,0), cshiftT=Color3.fromRGB(255,247,237), exposure=0.65 },
    night   = { amb=Color3.fromRGB(33,33,33), bright=3.25, clock=20, cshiftB=Color3.fromRGB(0,0,0), cshiftT=Color3.fromRGB(255,247,237), exposure=0.85 },
}
local origLighting = {
    Ambient = Lighting.Ambient, Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime, ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top, ExposureCompensation = Lighting.ExposureCompensation,
    FogColor = Lighting.FogColor, FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd,
    OutdoorAmbient = Lighting.OutdoorAmbient, GlobalShadows = Lighting.GlobalShadows,
}
local function ApplyShader()
    if not A.shaderOn then return end
    local p = shaderPresets[A.shaderType] or shaderPresets.morning
    Lighting.Ambient = p.amb
    Lighting.Brightness = p.bright
    Lighting.ClockTime = p.clock
    Lighting.ColorShift_Bottom = p.cshiftB
    Lighting.ColorShift_Top = p.cshiftT
    Lighting.ExposureCompensation = p.exposure
end
local function RestoreShader()
    Lighting.Ambient = origLighting.Ambient
    Lighting.Brightness = origLighting.Brightness
    Lighting.ClockTime = origLighting.ClockTime
    Lighting.ColorShift_Bottom = origLighting.ColorShift_Bottom
    Lighting.ColorShift_Top = origLighting.ColorShift_Top
    Lighting.ExposureCompensation = origLighting.ExposureCompensation
end
local function InitShaders()
    AddConnection("ShaderLoop", RunService.Heartbeat:Connect(function()
        if A.shaderOn then ApplyShader() end
    end))
end

-- ============================================================
-- NEW: TIME / FOG
-- ============================================================
local function InitTimeFog()
    AddConnection("TimeLoop", RunService.Heartbeat:Connect(function()
        if A.timeOn then
            if Lighting.ClockTime ~= A.timeValue then Lighting.ClockTime = A.timeValue end
        end
    end))
    AddConnection("FogLoop", RunService.Heartbeat:Connect(function()
        if A.fogOn then
            if Lighting.FogColor ~= A.fogColor then Lighting.FogColor = A.fogColor end
            if Lighting.FogStart ~= A.fogStart then Lighting.FogStart = A.fogStart end
            if Lighting.FogEnd ~= A.fogEnd then Lighting.FogEnd = A.fogEnd end
        end
    end))
end

-- ============================================================
-- NEW: WORLD EFFECTS (Snow / Sakura)
-- ============================================================
local function FXStop()
    if A.fxConn then pcall(function() A.fxConn:Disconnect() end) A.fxConn=nil end
    if A.fxPart then pcall(function() A.fxPart:Destroy() end) A.fxPart=nil end
    A.fxEmitter = nil
end
local function FXStyle()
    local e = A.fxEmitter; if not e then return end
    e.Texture = "rbxasset://textures/particles/smoke_main.dds"
    e.LightInfluence = 0
    e.LightEmission = 0.4
    e.Drag = 0
    e.EmissionDirection = Enum.NormalId.Bottom
    e.Rate = A.fxRate
    e.Color = ColorSequence.new(A.fxColor)
    if A.fxType=="Snow" then
        e.Lifetime = NumberRange.new(4,6)
        e.Speed = NumberRange.new(6,12)
        e.Acceleration = Vector3.new(2,-6,1)
        e.SpreadAngle = Vector2.new(35,35)
        e.Rotation = NumberRange.new(0,360)
        e.RotSpeed = NumberRange.new(-40,40)
        e.Size = NumberSequence.new(0.55)
        e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(0.8,0.3),NumberSequenceKeypoint.new(1,1)})
    else
        e.Lifetime = NumberRange.new(5,7)
        e.Speed = NumberRange.new(5,10)
        e.Acceleration = Vector3.new(4,-5,2)
        e.SpreadAngle = Vector2.new(40,40)
        e.Rotation = NumberRange.new(0,360)
        e.RotSpeed = NumberRange.new(-80,80)
        e.Size = NumberSequence.new(0.5)
        e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(0.85,0.25),NumberSequenceKeypoint.new(1,1)})
    end
end
local function FXStart()
    FXStop()
    local part = Instance.new("Part")
    part.Name="FH_WorldFX"; part.Anchored=true; part.CanCollide=false; part.CanQuery=false; part.CanTouch=false
    part.Transparency=1; part.Size=Vector3.new(260,140,260); part.Parent=workspace
    A.fxPart = part
    local e = Instance.new("ParticleEmitter")
    pcall(function() e.Shape=Enum.ParticleEmitterShape.Box; e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume end)
    e.Parent = part; A.fxEmitter = e
    FXStyle()
    A.fxConn = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera; if not cam then return end
        local cf = cam.CFrame
        local d = cf.LookVector
        local flat = Vector3.new(d.X,0,d.Z)
        if flat.Magnitude<0.05 then flat = Vector3.new(0,0,-1) else flat = flat.Unit end
        part.CFrame = CFrame.new(cf.Position + flat*57 + Vector3.new(0,44,0))
    end)
end
local function InitFX()
    AddConnection("FXCheck", RunService.Heartbeat:Connect(function()
        if A.fxOn and not A.fxPart then FXStart() end
        if not A.fxOn and A.fxPart then FXStop() end
    end))
end

-- ============================================================
-- NEW: WORLD AURA
-- ============================================================
local function AuraClear()
    for i=#A.auraParticles,1,-1 do
        pcall(function() A.auraParticles[i]:Destroy() end)
        A.auraParticles[i] = nil
    end
end
local function AuraLoad(name)
    if A.auraCache[name] then return A.auraCache[name] end
    local id = auraIds[name]; if not id then return nil end
    local ok, objs = pcall(game.GetObjects, game, "rbxassetid://"..id)
    if ok and objs and objs[1] then A.auraCache[name]=objs[1]; return objs[1] end
    return nil
end
local function AuraApply()
    AuraClear()
    local c = LocalPlayer.Character; if not c then return end
    local src = AuraLoad(A.auraType); if not src then return end
    local col = A.auraColor
    local seq = ColorSequence.new(col)
    for _, d in ipairs(src:GetDescendants()) do
        if d:IsA("PointLight") then d.Color = col
        elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Color = seq end
    end
    local cloned = src:Clone()
    for _, part in ipairs(cloned:GetChildren()) do
        local target = c:FindFirstChild(part.Name)
        if target and target:IsA("BasePart") then
            for _, child in ipairs(part:GetChildren()) do
                child.Parent = target
                A.auraParticles[#A.auraParticles+1] = child
            end
        end
    end
    cloned:Destroy()
end
local function InitAura()
    AddConnection("AuraCheck", RunService.Heartbeat:Connect(function()
        if not A.auraOn then
            if #A.auraParticles>0 then AuraClear() end
            return
        end
        local c = LocalPlayer.Character; if not c then return end
        local first = A.auraParticles[1]
        if not first or not first.Parent then AuraApply() end
    end))
end

-- ============================================================
-- NEW: LANDING CIRCLE
-- ============================================================
local function MakeLanding(p, n)
    local ref = math.abs(n.Y)>0.98 and Vector3.xAxis or Vector3.yAxis
    local right = n:Cross(ref).Unit
    local front = right:Cross(n).Unit
    local part = Instance.new("Part")
    part.Name="FH_LandCircle"; part.Anchored=true; part.CanCollide=false; part.CanQuery=false; part.CanTouch=false
    part.CastShadow=false; part.Transparency=1
    part.Size=Vector3.new(0.3,0.01,0.3)
    part.CFrame = CFrame.fromMatrix(p + n*0.012, right, n, front)
    part.Parent = workspace
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Top
    sg.AlwaysOnTop = true
    sg.LightInfluence = 0
    sg.ZOffset = 4
    sg.CanvasSize = Vector2.new(1024,1024)
    sg.Parent = part
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Size = UDim2.fromScale(1,1)
    img.Image = "rbxassetid://7185003058"
    img.ImageColor3 = A.landColor
    img.ImageTransparency = 1 - A.landTransp
    img.ScaleType = Enum.ScaleType.Stretch
    img.Parent = sg
    local info = TweenInfo.new(A.landDur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(part, info, {Size=Vector3.new(6.4,0.01,6.4)}):Play()
    TweenService:Create(img, info, {ImageTransparency=1}):Play()
    game:GetService("Debris"):AddItem(part, A.landDur+0.2)
end
local function InitLand()
    AddConnection("Land", RunService.Heartbeat:Connect(function()
        if not A.landOn then
            if A.landConn then pcall(function() A.landConn:Disconnect() end) A.landConn=nil end
            return
        end
        if A.landConn then return end
        local c = LocalPlayer.Character; local hum = c and c:FindFirstChildOfClass("Humanoid")
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local air = false
        A.landConn = hum.StateChanged:Connect(function(_, state)
            if state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall then
                air = true
            elseif state==Enum.HumanoidStateType.Landed and air then
                air = false
                local prm = RaycastParams.new()
                prm.FilterType = Enum.RaycastFilterType.Exclude
                prm.FilterDescendantsInstances = { c }
                prm.IgnoreWater = true
                local hit = workspace:Raycast(hrp.Position+Vector3.new(0,1,0), Vector3.new(0,-16,0), prm)
                if hit then MakeLanding(hit.Position, hit.Normal) end
            end
        end)
    end))
end

-- ============================================================
-- UI
-- ============================================================
local function BuildUI()
    local tC, tV, tU, tS, tAF = Tabs.Combat, Tabs.Visual, Tabs.Utility, Tabs.Settings, Tabs.AutoFarm
    if not (tC and tV and tU and tS and tAF) then logErr("two.lua: нет основных табов"); return end
    local function Reg(mn,t) ModuleNameToTitle[mn]=t end

    -- SILENT
    Reg("SilentAim","Silent Aim"); Reg("SilentAimMode","Silent Mode"); Reg("AutoShoot","Auto Shoot")
    tC:AddDropdown("SilentAimMode",{Title=L("silent_aim_mode"),Values={L("silent_aim_v1"),L("silent_aim_v2")},Default=L("silent_aim_v2")}):OnChanged(function(v)
        A.silentMode = (v==L("silent_aim_v1")) and "v1" or "v2"
        if A.silentMode=="v1" then UninstallSilent() else InstallSilent() end
    end)
    tC:AddToggle("SilentAim",{Title=L("silent_aim"),Default=false}):OnChanged(function(v)
        A.silentOn = v; if v and A.silentMode=="v2" then InstallSilent() end
    end)
    tC:AddToggle("AutoShoot",{Title=L("auto_shoot"),Default=false}):OnChanged(function(v) A.autoShootOn=v end)
    tC:AddSlider("AutoShootDelay",{Title=L("auto_shoot_delay"),Min=0,Max=600,Default=0,Rounding=0}):OnChanged(function(v) A.autoDelay=v end)

    -- KNIFE
    tC:AddToggle("KnifeSilent",{Title=L("knife_silent"),Default=false}):OnChanged(function(v) A.knifeSilent=v end)
    tC:AddSlider("KnifeLead",{Title=L("knife_lead"),Min=0,Max=320,Default=100,Rounding=0}):OnChanged(function(v) A.knifeLead=v/100 end)
    tC:AddSlider("KnifeAir",{Title=L("knife_air"),Min=0,Max=120,Default=35,Rounding=0}):OnChanged(function(v) A.knifeAir=v/100 end)
    tC:AddSlider("KnifeOffset",{Title=L("knife_offset"),Min=-80,Max=220,Default=0,Rounding=0}):OnChanged(function(v) A.knifeOffset=v/1000 end)
    tC:AddToggle("KnifeInsta",{Title=L("knife_insta"),Default=false}):OnChanged(function(v) A.knifeInsta=v end)
    tC:AddSlider("KnifeRadius",{Title=L("knife_radius"),Min=2,Max=40,Default=12,Rounding=0}):OnChanged(function(v) A.knifeRadius=v end)

    -- KILLAURA VERSION
    tC:AddDropdown("KillAuraVersion",{Title=L("kill_aura_version"),Values={L("kill_aura_v1"),L("kill_aura_v2")},Default=L("kill_aura_v1")}):OnChanged(function(v)
        if v==L("kill_aura_v2") then A.kaV2=true; if Options.KillAura then Options.KillAura:SetValue(false) end
        else A.kaV2=false end
    end)

    -- AUTOFARM V2
    tAF:AddDropdown("AutoFarmVersion",{Title=L("autofarm_version"),Values={L("autofarm_v1"),L("autofarm_v2")},Default=L("autofarm_v1")}):OnChanged(function(v)
        A.farmV2 = (v==L("autofarm_v2"))
        if Options.AutoFarmCoins and Options.AutoFarmCoins.Value then Options.AutoFarmCoins:SetValue(false) end
    end)
    tAF:AddSlider("FarmDownDepth",{Title=L("farm_down_depth"),Min=5,Max=40,Default=14,Rounding=0}):OnChanged(function(v) A.farmDownDepth=v end)

    -- BACKTRACK / TRACER
    tV:AddToggle("Backtrack",{Title=L("backtrack"),Default=false}):OnChanged(function(v) A.btOn=v; if not v then BtDestroy() end end)
    tV:AddColorPicker("BtColor",{Title=L("backtrack_color"),Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) A.btColor=c end)
    tV:AddToggle("Tracer",{Title=L("tracer"),Default=false}):OnChanged(function(v) A.tracerOn=v end)
    tV:AddColorPicker("TracerColor",{Title=L("tracer_color"),Default=Color3.fromRGB(133,220,255)}):OnChanged(function(c) A.tracerColor=c end)
    tV:AddSlider("TracerDur",{Title=L("tracer_duration"),Min=0.1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) A.tracerDur=v end)

    -- CHINA / CHAMS / GRAPH
    tV:AddToggle("ChinaHat",{Title=L("china_hat"),Default=false}):OnChanged(function(v) A.chinaHatOn=v; if not v then ChinaHatClear() end end)
    tV:AddColorPicker("ChinaHatColor",{Title=L("china_hat_color"),Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) A.chinaHatColor=c end)
    tV:AddToggle("SelfChams",{Title=L("self_chams"),Default=false}):OnChanged(function(v) A.selfChamsOn=v; if not v then SelfChamsClear() end end)
    tV:AddColorPicker("SelfChamsColor",{Title=L("self_chams_color"),Default=Color3.fromRGB(120,60,255)}):OnChanged(function(c) A.selfChamsColor=c end)
    tV:AddToggle("MovGraph",{Title=L("mov_graph"),Default=false}):OnChanged(function(v) A.movGraphOn=v; if not v then MovClear() end end)
    tV:AddColorPicker("MovGraphColor",{Title=L("mov_graph_color"),Default=Color3.fromRGB(242,242,242)}):OnChanged(function(c) A.movGraphColor=c end)
    tV:AddSlider("MovGraphWidth",{Title=L("mov_graph_width"),Min=180,Max=420,Default=280,Rounding=0}):OnChanged(function(v) A.movGraphW=v end)
    tV:AddSlider("MovGraphHeight",{Title=L("mov_graph_height"),Min=40,Max=120,Default=72,Rounding=0}):OnChanged(function(v) A.movGraphH=v end)
    tV:AddSlider("MovGraphY",{Title=L("mov_graph_y"),Min=-200,Max=400,Default=180,Rounding=0}):OnChanged(function(v) A.movGraphY=v end)

    -- NEW VISUALS
    tV:AddToggle("OffArrows",{Title=L("off_arrows"),Default=false}):OnChanged(function(v) A.arrowsOn=v end)
    tV:AddSlider("OffArrowsSize",{Title=L("off_arrows_size"),Min=16,Max=96,Default=42,Rounding=0}):OnChanged(function(v) A.arrowsSize=v end)
    tV:AddSlider("OffArrowsDist",{Title=L("off_arrows_dist"),Min=40,Max=520,Default=260,Rounding=0}):OnChanged(function(v) A.arrowsDist=v end)
    tV:AddColorPicker("ArrowsMur",{Title="Маньяк",Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) A.arrowsColorMur=c end)
    tV:AddColorPicker("ArrowsShf",{Title="Шериф",Default=Color3.fromRGB(60,140,255)}):OnChanged(function(c) A.arrowsColorShf=c end)
    tV:AddColorPicker("ArrowsInno",{Title="Невиновный",Default=Color3.fromRGB(255,255,255)}):OnChanged(function(c) A.arrowsColorInno=c end)

    tV:AddToggle("MatChams",{Title=L("mat_chams"),Default=false}):OnChanged(function(v) A.matChamsOn=v; if not v then MatChamsClear() end end)
    tV:AddDropdown("MatChamsType",{Title=L("mat_chams_type"),Values={"ForceField","Flat","Chromatic"},Default="ForceField"}):OnChanged(function(v) A.matChamsType=v end)

    tV:AddToggle("Crosshair",{Title=L("crosshair"),Default=false}):OnChanged(function(v)
        A.crosshairOn=v; if v then CrosshairBuild() else CrosshairClear() end
    end)
    tV:AddSlider("CrosshairGap",{Title=L("crosshair_gap"),Min=0,Max=20,Default=4,Rounding=1}):OnChanged(function(v) A.crosshairGap=v end)
    tV:AddSlider("CrosshairLen",{Title=L("crosshair_len"),Min=2,Max=30,Default=8,Rounding=1}):OnChanged(function(v) A.crosshairLen=v end)
    tV:AddSlider("CrosshairThick",{Title=L("crosshair_thick"),Min=1,Max=5,Default=2,Rounding=1}):OnChanged(function(v) A.crosshairThick=v end)
    tV:AddSlider("CrosshairRot",{Title=L("crosshair_rotate"),Min=0,Max=10,Default=0,Rounding=1}):OnChanged(function(v) A.crosshairRot=v end)
    tV:AddColorPicker("CrosshairColor",{Title=L("crosshair_color"),Default=Color3.fromRGB(255,255,255)}):OnChanged(function(c) A.crosshairColor=c end)
    tV:AddColorPicker("CrosshairOutline",{Title=L("crosshair_outline"),Default=Color3.fromRGB(0,0,0)}):OnChanged(function(c) A.crosshairOutline=c end)

    tV:AddToggle("Shader",{Title=L("shader"),Default=false}):OnChanged(function(v)
        A.shaderOn=v; if not v then RestoreShader() end
    end)
    tV:AddDropdown("ShaderType",{Title=L("shader_preset"),Values={"morning","midday","evening","night"},Default="morning"}):OnChanged(function(v) A.shaderType=v end)

    tV:AddToggle("TimeChanger",{Title=L("time_changer"),Default=false}):OnChanged(function(v)
        A.timeOn=v; if not v then Lighting.ClockTime=origLighting.ClockTime end
    end)
    tV:AddSlider("TimeValue",{Title=L("time_value"),Min=0,Max=24,Default=12,Rounding=1}):OnChanged(function(v) A.timeValue=v end)

    tV:AddToggle("CustomFog",{Title=L("custom_fog"),Default=false}):OnChanged(function(v)
        A.fogOn=v
        if not v then
            Lighting.FogColor=origLighting.FogColor; Lighting.FogStart=origLighting.FogStart; Lighting.FogEnd=origLighting.FogEnd
        end
    end)
    tV:AddColorPicker("FogColor",{Title=L("fog_color"),Default=Color3.fromRGB(192,192,192)}):OnChanged(function(c) A.fogColor=c end)
    tV:AddSlider("FogStart",{Title=L("fog_start"),Min=0,Max=1000,Default=0,Rounding=1}):OnChanged(function(v) A.fogStart=v end)
    tV:AddSlider("FogEnd",{Title=L("fog_end"),Min=0,Max=1000,Default=1000,Rounding=1}):OnChanged(function(v) A.fogEnd=v end)

    tV:AddToggle("WorldFX",{Title=L("world_fx"),Default=false}):OnChanged(function(v) A.fxOn=v end)
    tV:AddDropdown("WorldFXType",{Title=L("world_fx_type"),Values={"Snow","Sakura"},Default="Snow"}):OnChanged(function(v)
        A.fxType=v; if A.fxEmitter then FXStyle() end
    end)
    tV:AddColorPicker("WorldFXColor",{Title=L("world_fx_color"),Default=Color3.fromRGB(150,200,255)}):OnChanged(function(c) A.fxColor=c; if A.fxEmitter then A.fxEmitter.Color=ColorSequence.new(c) end end)
    tV:AddSlider("WorldFXRate",{Title=L("world_fx_rate"),Min=20,Max=900,Default=250,Rounding=1}):OnChanged(function(v) A.fxRate=v; if A.fxEmitter then FXStyle() end end)

    tV:AddToggle("WorldAura",{Title=L("world_aura"),Default=false}):OnChanged(function(v) A.auraOn=v; if not v then AuraClear() end end)
    tV:AddDropdown("WorldAuraType",{Title=L("world_aura_type"),Values=auraOrder,Default="angel"}):OnChanged(function(v) A.auraType=v; if A.auraOn then AuraApply() end end)
    tV:AddColorPicker("WorldAuraColor",{Title=L("world_aura_color"),Default=Color3.fromRGB(133,220,255)}):OnChanged(function(c)
        A.auraColor=c
        if A.auraOn then
            for _,m in pairs(A.auraCache) do
                local seq=ColorSequence.new(c)
                for _,d in ipairs(m:GetDescendants()) do
                    if d:IsA("PointLight") then d.Color=c
                    elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Color=seq end
                end
            end
            AuraApply()
        end
    end)

    tV:AddToggle("LandCircle",{Title=L("land_circle"),Default=false}):OnChanged(function(v) A.landOn=v end)
    tV:AddColorPicker("LandColor",{Title=L("land_circle_color"),Default=Color3.fromRGB(255,255,255)}):OnChanged(function(c) A.landColor=c end)
    tV:AddSlider("LandTransp",{Title="Прозрачность",Min=0,Max=1,Default=1,Rounding=2}):OnChanged(function(v) A.landTransp=v end)
    tV:AddSlider("LandDur",{Title=L("land_circle_dur"),Min=0.1,Max=3,Default=0.82,Rounding=2}):OnChanged(function(v) A.landDur=v end)

    -- ANTI
    tU:AddToggle("AntiFling",{Title=L("anti_fling"),Default=false}):OnChanged(function(v) A.antiFling=v end)
    tU:AddToggle("AntiVoid",{Title=L("anti_void"),Default=false}):OnChanged(function(v) A.antiVoid=v end)
    tU:AddToggle("AntiTrap",{Title=L("anti_trap"),Default=false}):OnChanged(function(v) A.antiTrap=v end)

    -- FAKEPOS
    tU:AddToggle("FakePos",{Title=L("fake_pos"),Default=false}):OnChanged(function(v) A.fakePosOn=v end)
    tU:AddSlider("FakePosX",{Title=L("fake_pos_x"),Min=1,Max=9,Default=9,Rounding=0}):OnChanged(function(v) A.fakePosX=v*1e9 end)
    tU:AddSlider("FakePosY",{Title=L("fake_pos_y"),Min=1,Max=9,Default=9,Rounding=0}):OnChanged(function(v) A.fakePosY=v*1e9 end)
    tU:AddSlider("FakePosZ",{Title=L("fake_pos_z"),Min=1,Max=9,Default=9,Rounding=0}):OnChanged(function(v) A.fakePosZ=v*1e9 end)

    -- TOOLS
    tU:AddToggle("TPTool",{Title=L("tp_tool"),Default=false}):OnChanged(function(v) A.tpToolOn=v; if not v then rmTP() end end)
    tU:AddToggle("FlingTool",{Title=L("fling_tool"),Default=false}):OnChanged(function(v) A.flingToolOn=v; if not v then rmFlingTool() end end)
    tU:AddToggle("FlingBypass",{Title=L("fling_bypass"),Default=false}):OnChanged(function(v) A.flingBypass=v end)

    -- SOUND
    tS:AddToggle("SoundReplacer",{Title=L("sound_replacer"),Default=false}):OnChanged(function(v) A.soundOn=v end)
    tS:AddDropdown("SoundSheriff",{Title=L("sound_sheriff"),Values={"mc bow","neverlose","rust","primordial","sparkle","break"},Default="mc bow"}):OnChanged(function(v) A.soundSheriff=v end)
    tS:AddDropdown("SoundMurder",{Title=L("sound_murder"),Values={"skeet","neverlose","rust","primordial","sparkle","break"},Default="skeet"}):OnChanged(function(v) A.soundMurder=v end)
    tS:AddSlider("SoundVol",{Title=L("sound_volume"),Min=0.1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) A.soundVol=v end)

    -- FLING TAB
    local tabFling = Window:AddTab({ Title = "Fling", Icon = "wind" })
    local function RefreshPlayers()
        local list={}
        for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then list[#list+1]=p.Name end end
        table.sort(list)
        local cur = Options.FlingTarget and Options.FlingTarget.Value
        pcall(function()
            Options.FlingTarget:SetValues(list); Options.FlingTarget:Generate()
            if cur and cur~="" then
                for _,n in ipairs(list) do if n==cur then Options.FlingTarget:SetValue(cur); return end end
            end
            if list[1] then Options.FlingTarget:SetValue(list[1]) end
        end)
    end
    tabFling:AddDropdown("FlingMode",{Title="Режим",Values={"Murderer","Sheriff","Specific","All"},Default="Murderer"}):OnChanged(function(v)
        if v=="Murderer" then A.flingMode="murderer"
        elseif v=="Sheriff" then A.flingMode="sheriff"
        elseif v=="Specific" then A.flingMode="specific"
        elseif v=="All" then A.flingMode="all" end
    end)
    tabFling:AddDropdown("FlingTarget",{Title="Игрок",Values=(function() local l={} for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then l[#l+1]=p.Name end end return l end)(),Default=nil}):OnChanged(function(v)
        if type(v)=="table" then v=v[1] end
        A.flingTarget = v or ""
    end)
    tabFling:AddSlider("FlingRange",{Title="Дальность",Min=20,Max=2000,Default=500,Rounding=0}):OnChanged(function(v) A.flingRange=v end)
    tabFling:AddToggle("FlingToggle",{Title="Fling ON",Default=false}):OnChanged(function(v)
        A.flingOn=v
        Notify(L("notify_title"), "Fling "..(v and "ON" or "OFF"), 1.5)
    end)
    tabFling:AddButton({Title="Fling раз",Callback=function()
        local tgs = GetFlingTargets()
        if #tgs==0 then Notify(L("notify_title"),"Нет таргета",2); return end
        DoFling(tgs[1]); Notify(L("notify_title"), "Fling: "..tgs[1].Name, 2)
    end})
    AddConnection("FlingAdd", Players.PlayerAdded:Connect(function() task.wait(1); RefreshPlayers() end))
    AddConnection("FlingRem", Players.PlayerRemoving:Connect(function() task.wait(0.5); RefreshPlayers() end))
end

-- ============================================================
-- LAUNCH
-- ============================================================
logInfo("two.lua загружается...")
pcall(function()
    InstallSilent(); InitSilent(); InitKnife(); InitKAv2()
    InitBt(); InitTracer(); InitChinaHat(); InitSelfChams(); InitMov()
    InitSounds(); InitAnti(); InitTools(); InitFakePos(); InitFling()
    InitArrows(); InitMatChams(); InitCrosshair(); InitShaders()
    InitTimeFog(); InitFX(); InitAura(); InitLand()
end)
local okUI, errUI = pcall(BuildUI)
if not okUI then logErr("two.lua UI: "..tostring(errUI)) else logInfo("two.lua UI собран") end
logInfo("two.lua полностью загружен")
