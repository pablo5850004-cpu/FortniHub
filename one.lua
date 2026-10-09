-- ============================================================
-- FortniHub MM2 v20.2 BETA — ЧАСТЬ 1/2
-- ============================================================

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local VirtualInputManager=game:GetService("VirtualInputManager")
local CoreGui=game:GetService("CoreGui")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local VirtualUser=game:GetService("VirtualUser")
local TweenService=game:GetService("TweenService")
local Stats=game:GetService("Stats")
local CollectionService=game:GetService("CollectionService")
local SoundService=game:GetService("SoundService")
local Debris=game:GetService("Debris")
local LocalPlayer=Players.LocalPlayer
local Camera=Workspace.CurrentCamera
local VERSION="20.2.0 BETA"
local CREDITS="by HOTI and Ve315"
local S={frozen=false,freezeUpKey=Enum.KeyCode.Space,freezeDownKey=Enum.KeyCode.LeftAlt}
local silent={enabled=false,predict=true,force=false,standoff=15,lastShot=0}
local knifeSilent={enabled=false,radius=20,fov=120,showFov=true,checkWalls=false,instaKill=true,predict=true}
local kaV1={on=false,dist=30,lastHit=0}
local kaV2={on=false,dist=30,lastHit=0}
local killAuraVersion="v2"
local Connections={}
local function AddConn(name,conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name]=conn
end
local Cache={hrp=nil,hum=nil,cacheTime=0}
local function refreshChar()
    if tick()-Cache.cacheTime<0.5 then return end
    Cache.cacheTime=tick()
    local c=LocalPlayer.Character
    if c then Cache.hrp=c:FindFirstChild("HumanoidRootPart");Cache.hum=c:FindFirstChildOfClass("Humanoid")
    else Cache.hrp,Cache.hum=nil,nil end
end
local function getHRP() refreshChar() return Cache.hrp end
local function getHum() refreshChar() return Cache.hum end
local function getRoundData()
    local ok,m=pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient")) end)
    if ok and type(m)=="table" then return m.PlayerData end
    return nil
end
local function getRoleFromData(p)
    if not p then return "lobby" end
    local ok,m=pcall(function() return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CurrentRoundClient")) end)
    if ok and type(m)=="table" and type(m.PlayerData)=="table" then
        local d=m.PlayerData[p.Name]
        if d and not d.Dead then
            if d.Role=="Murderer" then return "murderer" end
            if d.Role=="Sheriff" then return "sheriff" end
            if d.Role=="Hero" then return "hero" end
            return "innocent"
        end
    end
    local c=p.Character
    if c then
        local bp=p:FindFirstChild("Backpack")
        if c:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")) then return "murderer" end
        if c:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun")) then
            local allData=getRoundData()
            if allData then
                for _,info in pairs(allData) do
                    if type(info)=="table" and info.Role=="Sheriff" and info.Dead then return "hero" end
                end
            end
            return "sheriff"
        end
    end
    return "innocent"
end
local function srand(a,b)
    local _orig=math.random
    if a==nil then return _orig() end
    if b==nil then
        if type(a)~="number" or a~=a or a<1 then a=1 end
        if a>2147483647 then a=2147483647 end
        return _orig(math.floor(a))
    end
    a,b=tonumber(a) or 0,tonumber(b) or 0
    if b<a then a,b=b,a end
    if a==b then return a end
    return _orig(math.floor(a),math.floor(b))
end

local OnChangedRegistry={}
getgenv().FH_OnChangedRegistry=OnChangedRegistry
local function registerOnChanged(name, cb) OnChangedRegistry[name]=cb end
local function fireRegistered(name, value)
    local cb=OnChangedRegistry[name]
    if cb then pcall(cb, value) end
end

local Fluent
do
    print("[FH] Загружаю Fluent UI...")
    local urls={
        "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/src/init.lua",
        "https://raw.githubusercontent.com/dawid-scripts/Fluent/master/src/init.lua",
        "https://cdn.jsdelivr.net/gh/dawid-scripts/Fluent@main/src/init.lua",
        "https://raw.githack.com/dawid-scripts/Fluent/main/src/init.lua",
    }
    local body
    for _,u in ipairs(urls) do
        local ok,b=pcall(function() return game:HttpGet(u,true) end)
        if ok and type(b)=="string" and #b>1000 and not b:find("<html") then body=b;break end
    end
    if not body then error("[FH] Не удалось загрузить Fluent UI") end
    local fn=loadstring(body,"@Fluent")
    Fluent=fn and fn()
    if type(Fluent)~="table" then error("[FH] Fluent не таблица") end
    print("[FH] Fluent загружен")
end
local function adaptTab(tab)
    if not tab then return tab end
    for _,name in ipairs({"AddToggle","AddSlider","AddDropdown","AddInput","AddButton","AddLabel","AddKeybind","AddColorpicker","AddColorPicker"}) do
        local orig=tab[name]
        if type(orig)=="function" and not rawget(tab,"__"..name) then
            rawset(tab,"__"..name,true)
            tab[name]=function(self,...)
                local r=orig(self,...)
                if type(r)=="table" and r.Option==nil then r.Option=r end
                return r
            end
        end
    end
    if type(tab.AddColorpicker)=="function" and type(tab.AddColorPicker)~="function" then tab.AddColorPicker=tab.AddColorpicker end
    if type(tab.AddSection)=="function" and not rawget(tab,"__AS") then
        rawset(tab,"__AS",true)
        local origAS=tab.AddSection
        tab.AddSection=function(self,arg)
            if type(arg)=="table" then arg=arg.Name or arg.name or "Секция" end
            if arg==nil then arg="Секция" end
            local sec=origAS(self,arg)
            if sec then
                if sec.Option==nil then sec.Option=sec end
                adaptTab(sec)
            end
            return sec
        end
    end
    return tab
end
local Window,Options=nil,nil
do
    Window=Fluent:CreateWindow({
        Title="FortniHub MM2",
        SubTitle="v"..VERSION.." — "..CREDITS,
        TabWidth=130,
        Size=UDim2.fromOffset(420,300),
        Theme="Darker",
        MinimizeKey=Enum.KeyCode.P,
    })
    Options=Fluent.Options
    getgenv().FH_Window=Window
    getgenv().Options=Options
    local origAddTab=Window.AddTab
    Window.AddTab=function(self,...)
        local tab=origAddTab(self,...)
        return adaptTab(tab)
    end
end
local Tabs={}
getgenv().FH_Tabs=Tabs
Tabs.Combat=Window:AddTab({Title="Бой"})
Tabs.Movement=Window:AddTab({Title="Движение"})
Tabs.Binds=Window:AddTab({Title="Бинды"})
Tabs.Visual=Window:AddTab({Title="Визуал"})
Tabs.Effects=Window:AddTab({Title="Эффекты"})
Tabs.Farm=Window:AddTab({Title="Фарм"})
Tabs.Animations=Window:AddTab({Title="Эмоции"})
Tabs.Utility=Window:AddTab({Title="Утилиты"})
Tabs.Troll=Window:AddTab({Title="Троллинг"})
Tabs.Settings=Window:AddTab({Title="Настройки"})

local function addOpt(container, method, name, opts, callback)
    local opt = container[method](container, name, opts)
    if opt and callback then
        opt:OnChanged(callback)
        registerOnChanged(name, callback)
    end
    return opt
end

local lastNotify={}
local function Notify(title,content,dur)
    local k=tostring(title).."|"..tostring(content)
    if lastNotify[k] and (tick()-lastNotify[k])<0.5 then return end
    lastNotify[k]=tick()
    pcall(function() Fluent:Notify({Title=title,Content=content,Duration=dur or 3}) end)
end
getgenv().FH_Notify=Notify

task.spawn(function()
    task.wait(0.8)
    Notify("FortniHub","Скрипт был создан HOTI и Ve315.", 7)
    task.wait(1.2)
    Notify("FortniHub","Скрипт находится в BETA версии, могут быть баги.", 7)
end)

-- ============================================================
-- HUD (FPS/Ping)
-- ============================================================
local HUDGui,FPSLabel,PingLabel,Pill
do
    pcall(function()
        for _,name in ipairs({"FH_HUD_v18","FH_HUD","FH_HUD_v182","FH_HUD_v1821","FH_HUD_v183","FH_HUD_v184","FH_HUD_v185","FH_HUD_v186","FH_HUD_v19","FH_HUD_v20","FH_HUD_v21"}) do
            local old=CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
    HUDGui=Instance.new("ScreenGui")
    HUDGui.Name="FH_HUD_v22"
    HUDGui.ResetOnSpawn=false
    HUDGui.IgnoreGuiInset=true
    HUDGui.DisplayOrder=500
    HUDGui.Parent=CoreGui
    Pill=Instance.new("Frame")
    Pill.Name="Pill"
    Pill.AnchorPoint=Vector2.new(0.5,0)
    Pill.Position=UDim2.new(0.5,0,0,12)
    Pill.Size=UDim2.fromOffset(400,40)
    Pill.BackgroundColor3=Color3.fromRGB(15,15,20)
    Pill.BorderSizePixel=0
    Pill.Active=true
    Pill.Parent=HUDGui
    Instance.new("UICorner",Pill).CornerRadius=UDim.new(1,0)
    local stroke=Instance.new("UIStroke",Pill)
    stroke.Color=Color3.fromRGB(138,92,246)
    stroke.Thickness=1
    stroke.Transparency=0.5
    local grad=Instance.new("UIGradient",Pill)
    grad.Rotation=45
    grad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(40,30,60)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(20,20,28)),ColorSequenceKeypoint.new(1,Color3.fromRGB(40,30,60))})
    local dragging,dragStart,posStart,dragMoved=false,nil,nil,false
    local TAP=6
    local function toggleMenu()
        local w=getgenv().FH_Window
        if w and type(w.Toggle)=="function" then
            local ok=pcall(function() w:Toggle() end)
            if ok then return end
        end
        pcall(function()
            VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.P,false,game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.P,false,game)
        end)
    end
    Pill.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true;dragMoved=false;dragStart=i.Position;posStart=Pill.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local d=i.Position-dragStart
            if math.abs(d.X)>TAP or math.abs(d.Y)>TAP then dragMoved=true end
            if dragMoved then Pill.Position=UDim2.new(posStart.X.Scale,posStart.X.Offset+d.X,posStart.Y.Scale,posStart.Y.Offset+d.Y) end
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end
        if not dragging then return end
        local wasTap=not dragMoved
        dragging=false
        if wasTap then toggleMenu() end
    end)
    local function seg(x,w)
        local f=Instance.new("Frame")
        f.BackgroundTransparency=1
        f.Position=UDim2.fromOffset(x,0)
        f.Size=UDim2.fromOffset(w,40)
        f.Parent=Pill
        return f
    end
    local function div(x)
        local d=Instance.new("Frame")
        d.BackgroundColor3=Color3.fromRGB(70,70,85)
        d.BorderSizePixel=0
        d.Position=UDim2.new(0,x,0.5,-10)
        d.Size=UDim2.fromOffset(1,20)
        d.Parent=Pill
    end
    local s1=seg(8,130)
    local logo=Instance.new("TextLabel")
    logo.BackgroundTransparency=1
    logo.Size=UDim2.fromOffset(120,40)
    logo.Position=UDim2.fromOffset(12,0)
    logo.Font=Enum.Font.GothamBold
    logo.Text="FH"
    logo.TextSize=20
    logo.TextColor3=Color3.fromRGB(178,152,255)
    logo.TextXAlignment=Enum.TextXAlignment.Left
    logo.Parent=s1
    div(142)
    local s2=seg(146,120)
    local fpsIcon=Instance.new("TextLabel")
    fpsIcon.BackgroundTransparency=1
    fpsIcon.Size=UDim2.fromOffset(40,40)
    fpsIcon.Position=UDim2.fromOffset(6,0)
    fpsIcon.Font=Enum.Font.GothamBold
    fpsIcon.Text="FPS"
    fpsIcon.TextSize=13
    fpsIcon.TextColor3=Color3.fromRGB(140,140,160)
    fpsIcon.TextXAlignment=Enum.TextXAlignment.Left
    fpsIcon.Parent=s2
    FPSLabel=Instance.new("TextLabel")
    FPSLabel.BackgroundTransparency=1
    FPSLabel.Size=UDim2.fromOffset(60,40)
    FPSLabel.Position=UDim2.fromOffset(46,0)
    FPSLabel.Font=Enum.Font.GothamBold
    FPSLabel.Text="60"
    FPSLabel.TextSize=15
    FPSLabel.TextColor3=Color3.fromRGB(80,240,120)
    FPSLabel.TextXAlignment=Enum.TextXAlignment.Left
    FPSLabel.Parent=s2
    div(270)
    local s3=seg(274,110)
    local pingIcon=Instance.new("TextLabel")
    pingIcon.BackgroundTransparency=1
    pingIcon.Size=UDim2.fromOffset(30,40)
    pingIcon.Position=UDim2.fromOffset(6,0)
    pingIcon.Font=Enum.Font.GothamBold
    pingIcon.Text="ms"
    pingIcon.TextSize=13
    pingIcon.TextColor3=Color3.fromRGB(140,140,160)
    pingIcon.TextXAlignment=Enum.TextXAlignment.Left
    pingIcon.Parent=s3
    PingLabel=Instance.new("TextLabel")
    PingLabel.BackgroundTransparency=1
    PingLabel.Size=UDim2.fromOffset(60,40)
    PingLabel.Position=UDim2.fromOffset(36,0)
    PingLabel.Font=Enum.Font.GothamBold
    PingLabel.Text="0"
    PingLabel.TextSize=15
    PingLabel.TextColor3=Color3.fromRGB(80,240,120)
    PingLabel.TextXAlignment=Enum.TextXAlignment.Left
    PingLabel.Parent=s3
    local function lockLabels()
        if FPSLabel and FPSLabel.Parent then
            local ok,cur=pcall(function() return FPSLabel.Text end)
            if not ok or type(cur)~="string" or not tonumber(cur) then FPSLabel.Text="60" end
        end
        if PingLabel and PingLabel.Parent then
            local ok,cur=pcall(function() return PingLabel.Text end)
            if not ok or type(cur)~="string" or not tonumber(cur) then PingLabel.Text="0" end
        end
    end
    local fc,lastSec=0,os.clock()
    AddConn("HUD_FPS",RunService.Heartbeat:Connect(function()
        fc=fc+1
        local now=os.clock()
        if now-lastSec>=1 then
            local cur=fc;fc=0;lastSec=now
            local c=cur<30 and Color3.fromRGB(255,80,80) or (cur<60 and Color3.fromRGB(255,200,80) or Color3.fromRGB(80,240,120))
            if FPSLabel and FPSLabel.Parent then FPSLabel.Text=tostring(cur) FPSLabel.TextColor3=c end
        end
    end))
    local lastPing=0
    AddConn("HUD_PING",RunService.Heartbeat:Connect(function()
        local now=os.clock()
        if now-lastPing<0.4 then return end
        lastPing=now
        local ok,p=pcall(function()
            local v=LocalPlayer:GetNetworkPing()*1000
            if v~=v or v<0 then v=0 end
            return math.floor(v)
        end)
        if ok and PingLabel and PingLabel.Parent then
            local c=p<60 and Color3.fromRGB(80,240,120) or (p<120 and Color3.fromRGB(255,200,80) or Color3.fromRGB(255,80,80))
            PingLabel.Text=tostring(p) PingLabel.TextColor3=c
        end
    end))
    task.spawn(function() while true do task.wait(0.5) lockLabels() end end)
    task.delay(0.5,lockLabels)
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
        enabled=false, predict=true, force=false, auto_on=false, auto_delay=0,
        am_sheriff=false, fire_gap=0, last_shot=0, stand_off=15,
    }
    local SS = getgenv().SILENT_S
    local silent_section = Tabs.Combat:AddSection({Name="Тихий выстрел"})
    local gap_min,gap_seen,gap_gun,want_since=0,false,nil,0
    local function gap_reset() gap_min=0 gap_seen=false SS.fire_gap=0 end
    local function gap_push(value)
        if value <= 0 then return end
        if not gap_seen or value < gap_min then gap_min=value gap_seen=true SS.fire_gap=value end
    end
    local round_mod = nil
    local function get_round()
        if round_mod then return round_mod end
        local ok, m = pcall(function() return require(rs:WaitForChild("Modules"):WaitForChild("CurrentRoundClient")) end)
        if ok and type(m) == "table" then round_mod = m end
        return round_mod
    end
    local function holds(container, name)
        return container ~= nil and container:FindFirstChild(name) ~= nil
    end
    local function lp_has_gun()
        return holds(lp.Character, "Gun") or holds(lp:FindFirstChildOfClass("Backpack"), "Gun")
    end
    local target_player,target_char,target_part,target_hum=nil,nil,nil,nil
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
                if plr ~= lp and holds(plr.Character, "Knife") then found = plr break end
            end
        end
        if found ~= target_player then
            target_player = found
            target_char,target_part,target_hum=nil,nil,nil
        end
        if not found then return end
        local char = found.Character
        if char ~= target_char then target_char=char target_part=nil target_hum=nil end
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
    local ignore_base,ignore_work,ignore_time={},{},0
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
    local P = {snap=48,ring=48,hit_r=2.1,pad=2.6,min_span=5,max_span=90,acc_t=0.15,acc_max=280,acc_min=40,speed_floor=26,speed_head=1.3}
    local snap_t = table.create(P.snap, 0)
    local snap_p = table.create(P.snap, Vector3.zero)
    local snap_n,snap_i=0,0
    local TR = {part=nil,pos=nil,time=0,vel=Vector3.zero,gap=0,ready=false,fresh=Vector3.zero,air=false,air_since=0,jumping=false,jump_v=0,fresh_ok=false,turn=0,spoof=0,clr=0,air_edge=0,jump_fresh=false}
    local SK = {vt=table.create(P.ring,0),dx=table.create(P.ring,0),dz=table.create(P.ring,0),vn=0,vi=0}
    local EC = {ping=0,rtt=0,jitter=0,seen=false,step=0,step_seen=false}
    local function step_push(dt)
        if dt <= 0 or dt > 0.5 then return end
        if EC.step_seen then EC.step = EC.step * 0.85 + dt * 0.15
        else EC.step = dt EC.step_seen = true end
    end
    local function sample_span()
        local span = math.max(EC.step, TR.gap)
        if span <= 0 then return 0 end
        return span
    end
    local HY = {pos={},w={},n=0,weight=0,primary=nil,stamp=0,conf=0}
    local ground_params = RaycastParams.new()
    ground_params.FilterType = Enum.RaycastFilterType.Exclude
    ground_params.IgnoreWater = true
    local ground_filter,axis_pool={},{}
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
        local used,sum_d=0,0
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
    local KIN = {ok=false,ax=0,az=0,smax=0}
    local function kin_clear() KIN.ok=false KIN.ax=0 KIN.az=0 KIN.smax=0 end
    local function fit_kin()
        if snap_n < 5 then return nil end
        local t0 = snap_get(0)
        local win = math.max(sample_span() * 5, 0.12)
        local scale = win
        local n, s1, s2, s3, s4 = 0, 0, 0, 0, 0
        local bx0,bx1,bx2=0,0,0
        local bz0,bz1,bz2=0,0,0
        for k = 0, snap_n - 1 do
            local t, p = snap_get(k)
            local age = t0 - t
            if age > win then break end
            local u = -age / scale
            local u2 = u * u
            n = n + 1
            s1=s1+u;s2=s2+u2;s3=s3+u2*u;s4=s4+u2*u2
            bx0=bx0+p.X;bx1=bx1+p.X*u;bx2=bx2+p.X*u2
            bz0=bz0+p.Z;bz1=bz1+p.Z*u;bz2=bz2+p.Z*u2
        end
        if n < 5 then return nil end
        local det = n*(s2*s4-s3*s3)-s1*(s1*s4-s3*s2)+s2*(s1*s3-s2*s2)
        if math.abs(det) < 1e-9 then return nil end
        local function solve(b0,b1,b2)
            local d1 = n*(b1*s4-s3*b2)-b0*(s1*s4-s3*s2)+s2*(s1*b2-b1*s2)
            local d2 = n*(s2*b2-b1*s3)-s1*(s1*b2-b1*s2)+b0*(s1*s3-s2*s2)
            return d1/det, d2/det
        end
        local cx1,cx2 = solve(bx0,bx1,bx2)
        local cz1,cz2 = solve(bz0,bz1,bz2)
        local vx,vz = cx1/scale, cz1/scale
        local ax,az = 2*cx2/(scale*scale), 2*cz2/(scale*scale)
        if vx~=vx or vz~=vz or ax~=ax or az~=az then return nil end
        return Vector3.new(vx,0,vz), Vector3.new(ax,0,az)
    end
    local function kin_update()
        local kv, ka = fit_kin()
        if not kv then KIN.ok=false KIN.ax=0 KIN.az=0 return nil end
        KIN.ok = true
        local sp = math.sqrt(kv.X*kv.X + kv.Z*kv.Z)
        if sp > KIN.smax then KIN.smax = sp
        else KIN.smax = KIN.smax*0.985 + sp*0.015 end
        if ka and not TR.air then
            local am = math.sqrt(ka.X*ka.X + ka.Z*ka.Z)
            local ax, az = ka.X, ka.Z
            if am > P.acc_max and am > 0 then ax=ax*P.acc_max/am az=az*P.acc_max/am end
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
        local best = nil
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
        local part = target_part
        local hum = target_hum
        if not part or not hum then return 0 end
        local ok, value = pcall(function() return part.Size.Y * 0.5 + hum.HipHeight end)
        if ok and type(value) == "number" and value > 0 then return value end
        return 0
    end
    local GC = {base=0,seen=false}
    local JL = {v=0,seen=false}
    local function stand_clearance()
        if GC.seen then return GC.base end
        return body_clearance()
    end
    local function engine_vel(part)
        local ok, v = pcall(function() return part.AssemblyLinearVelocity end)
        if not ok or typeof(v) ~= "Vector3" then ok, v = pcall(function() return part.Velocity end) end
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
        local a = math.clamp((align - 0.7)/0.25, 0, 1)
        local r = 1 - math.clamp(math.abs(ratio - 1)/0.4, 0, 1)
        return a * r
    end
    local function phase_velocity(v, age, air)
        if not v then return nil end
        local y = 0
        if air then y = v.Y - grav() * math.clamp(age or 0, 0, sample_span()*4) end
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
            base = stable:Lerp(instant, 0.4 + 0.6*agility)
        end
        local trust = 0
        if engine then
            local live = phase_velocity(engine, engine_age, air)
            trust = vel_trust(base, live)
            if trust > 0 and air then
                base = Vector3.new(base.X, base.Y, base.Z):Lerp(Vector3.new(base.X, live.Y, base.Z), trust*0.35)
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
        TR.part=nil TR.pos=nil TR.vel=Vector3.zero TR.gap=0
        TR.ready=false TR.fresh=Vector3.zero TR.air=false
        TR.jumping=false TR.jump_v=0 TR.fresh_ok=false
        TR.turn=0 TR.spoof=0 TR.clr=0 TR.air_edge=0 TR.jump_fresh=false
        GC.base=0 GC.seen=false
        JL.v=0 JL.seen=false
        snap_n,snap_i=0,0
        SK.vn,SK.vi=0,0
        kin_clear()
    end
    local function track_seed(part, pos, now)
        TR.part=part TR.pos=pos TR.time=now
        TR.vel=Vector3.zero TR.fresh=Vector3.zero TR.fresh_ok=false
        TR.turn=0 TR.jump_v=0 TR.gap=0 TR.ready=false
        TR.spoof=0 TR.air_edge=0 TR.jump_fresh=false
        GC.base=0 GC.seen=false
        snap_n,snap_i=0,0
        kin_clear()
        snap_push(now, pos)
    end
    local function track_fresh(now)
        local part = target_part
        if not part or not part.Parent then TR.fresh_ok = false return end
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
                else GC.base=clr GC.seen=true end
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
        if part ~= TR.part or not TR.pos then track_seed(part,pos,now) return end
        local dt = now - TR.time
        if dt > 0.75 or (pos - TR.pos).Magnitude > 140 then track_seed(part,pos,now) return end
        if dt <= 0 then return end
        if (pos - TR.pos).Magnitude == 0 then
            if TR.gap > 0 and dt >= TR.gap then TR.vel=Vector3.zero TR.fresh=Vector3.zero end
            return
        end
        step_push(dt)
        TR.gap = dt
        snap_push(now,pos)
        TR.pos=pos TR.time=now
        local fit,fit_age = fit_velocity()
        local fast,fast_age = recent_velocity()
        local engine = engine_vel(part)
        local fresh, turn, instant, trust = merge_vel(fit, fit_age, fast, fast_age, engine, sample_span()*0.5, TR.air)
        local kv = kin_update()
        if kv then fresh = Vector3.new(kv.X, fresh.Y, kv.Z) end
        if engine and trust <= 0 then
            if TR.spoof < 20 then TR.spoof = TR.spoof + 1 end
        elseif TR.spoof > 0 then TR.spoof = TR.spoof - 1 end
        if TR.air then
            local vy = air_vy()
            if vy then
                fresh = Vector3.new(fresh.X, vy, fresh.Z)
                local since = math.max(0, now - TR.air_edge)
                if TR.jump_fresh and since <= 0.2 then
                    local impulse = vy + grav()*since
                    if impulse > 1 then
                        if JL.seen then JL.v = JL.v*0.7 + impulse*0.3
                        else JL.v = impulse JL.seen = true end
                        if impulse > TR.jump_v then TR.jump_v = impulse end
                    end
                else TR.jump_fresh = false end
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
        local ok, ms = pcall(function() return stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
        if ok and type(ms) == "number" and ms == ms and ms > 4 and ms < 800 then a = ms/1000 end
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
        else EC.rtt=rtt EC.jitter=0 EC.seen=true end
        EC.ping = EC.rtt
    end
    local function lead_time()
        if not EC.seen then return 0 end
        local stale = 0
        if TR.time > 0 and EC.step_seen then stale = math.clamp(os.clock() - TR.time, 0, EC.step) end
        return math.clamp(EC.rtt + EC.jitter*0.5 + stale, 0, 1)
    end
    local function rotate_y(v, ang)
        local c, s = math.cos(ang), math.sin(ang)
        return Vector3.new(v.X*c - v.Z*s, v.Y, v.X*s + v.Z*c)
    end
    local function dir_stats(win)
        if SK.vn < 4 then return 1, 0 end
        win = math.max(win, sample_span()*3)
        local newest = SK.vt[SK.vi]
        local sx, sz, n = 0, 0, 0
        local prev = nil
        local turn, turn_n = 0, 0
        local oldest = newest
        for k = 0, SK.vn - 1 do
            local idx = (SK.vi - k - 1) % P.ring + 1
            local t = SK.vt[idx]
            if newest - t > win then break end
            local hx, hz = SK.dx[idx], SK.dz[idx]
            local m = math.sqrt(hx*hx + hz*hz)
            if m > 0 then
                sx = sx + hx/m
                sz = sz + hz/m
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
        local coh = math.clamp(math.sqrt(sx*sx + sz*sz)/n, 0, 1)
        local omega = 0
        local elapsed = newest - oldest
        if turn_n >= 1 and elapsed > 1e-3 then omega = -turn/elapsed end
        return coh, omega
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
            if TR.air or math.sqrt(ax*ax + az*az) < P.acc_min then ax, az = 0, 0 end
            local vx = dir.X + ax*age
            local vz = dir.Z + az*age
            local ta = math.min(span, P.acc_t)
            local dx = vx*span + 0.5*ax*ta*ta
            local dz = vz*span + 0.5*az*ta*ta
            local reach = math.sqrt(dx*dx + dz*dz)
            local cap = math.max(KIN.smax*P.speed_head, P.speed_floor)*span
            if reach > cap and reach > 1e-6 then dx = dx*cap/reach dz = dz*cap/reach end
            x = base.X + dx
            z = base.Z + dz
        else
            local hspan = span
            if span > 0 and dir.Magnitude > 0 and not TR.air then
                local coh, omega = dir_stats(span)
                local conf = math.clamp(coh, 0, 1) * (1 - math.clamp(TR.turn, 0, 1)*0.5)
                if omega ~= 0 then dir = rotate_y(dir, math.clamp(omega*span*0.5*conf, -0.6, 0.6)) end
                hspan = span * (0.85 + 0.15*conf)
            end
            x = base.X + dir.X*hspan
            z = base.Z + dir.Z*hspan
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
            local perp = (d - axis*a).Magnitude
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
            for k = 1, n do if axis_pool[k]:Dot(u) > 0.985 then return end end
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
        local best_axis,best_cov,best_lo,best_hi=nil,-1,0,0
        for k = 1, count do
            local axis = axis_pool[k]
            local cov, lo, hi = score_axis(anchor, axis)
            if cov > best_cov then best_axis,best_cov,best_lo,best_hi=axis,cov,lo,hi end
        end
        if not best_axis then return nil end
        HY.conf = HY.weight > 0 and best_cov / HY.weight or 0
        local pad = P.pad
        local origin = anchor + best_axis*(best_lo - pad)
        local aim = anchor + best_axis*(best_hi + pad)
        if (aim - origin).Magnitude < 4 then
            origin = anchor - best_axis*4
            aim = anchor + best_axis*4
        end
        return origin, aim, HY.conf, anchor
    end
    local pred_off = Vector3.zero
    local pred_stamp = 0
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
    local hit_names = {"HumanoidRootPart","UpperTorso","Torso","LowerTorso","Head","RightUpperArm","LeftUpperArm","Right Arm","Left Arm","RightUpperLeg","LeftUpperLeg","Right Leg","Left Leg","RightLowerLeg","LeftLowerLeg"}
    local hit_parts,hit_count,hit_char={},0,nil
    local function refresh_parts()
        local char = target_char
        if char == hit_char then return end
        table.clear(hit_parts)
        hit_count = 0
        hit_char = char
        if not char then return end
        for k = 1, #hit_names do
            local part = char:FindFirstChild(hit_names[k])
            if part and part:IsA("BasePart") then hit_count=hit_count+1 hit_parts[hit_count]=part end
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
            if not part.Parent then hit_char = nil
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
    local force_att,force_saved,force_stamp=nil,nil,0
    local function restore_origin()
        local att = force_att
        if not att then return end
        local saved = force_saved
        force_att=nil force_saved=nil
        if saved then pcall(function() if att.Parent then att.CFrame = saved end end) end
    end
    local function push_origin(cf)
        local att = gun_attachment()
        if not att then return false end
        if force_att and force_att ~= att then restore_origin() end
        if not force_att then
            local ok, saved = pcall(function() return att.CFrame end)
            if not ok or typeof(saved) ~= "CFrame" then return false end
            force_att=att force_saved=saved
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
                if behind < P.pad then origin = origin - u*(P.pad - behind) end
                local ahead = (aim - mark):Dot(u)
                if ahead < P.min_span then aim = mark + u*P.min_span end
                local want = SS.stand_off
                while want > 0 do
                    local probe = origin - u*want
                    if (aim - probe).Magnitude <= P.max_span and los_clear(probe, mark) and los_clear(probe, live) then origin = probe break end
                    want = want - 3
                end
                if (aim - origin).Magnitude > P.max_span then origin = aim - u*P.max_span end
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
        local back = live - dir*6
        local front = live + dir*math.max(P.min_span, vel.Magnitude*lead_time() + 8)
        if not force_clear(back, front) then back = live - dir*2.5 end
        return CFrame.new(back, front), CFrame.new(front), 0, live
    end
    local function shot_shift(dt)
        if not SS.predict or not TR.ready or dt <= 0 then return Vector3.zero end
        local shift = Vector3.new(TR.vel.X*dt, 0, TR.vel.Z*dt)
        if TR.air then
            local g = grav()
            local horizon = lead_time()
            local vy = TR.vel.Y
            local phase = math.max(0, os.clock() - TR.air_since)
            local modeled = TR.jump_v - g*phase
            if TR.jumping and TR.jump_v > 0 and g > 0 and phase <= TR.jump_v/g and modeled > vy then vy = modeled end
            shift = Vector3.new(shift.X, vy*dt - g*horizon*dt - 0.5*g*dt*dt, shift.Z)
        end
        return shift
    end
    local function compensate_force(origin_cf, aim_cf, started)
        if SS.force then return origin_cf, aim_cf end
        local shift = shot_shift(math.max(0, os.clock() - started))
        if shift == Vector3.zero then return origin_cf, aim_cf end
        return CFrame.new(origin_cf.Position + shift, aim_cf.Position + shift), CFrame.new(aim_cf.Position + shift)
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
    local weapon_service,orig_mouse,orig_screen,hook_mouse,hook_screen=nil,nil,nil,nil,nil
    local function get_weapon_service()
        if weapon_service then return weapon_service end
        local ok, m = pcall(function() return require(rs:WaitForChild("ClientServices"):WaitForChild("WeaponService")) end)
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
    local gun_fired_conn,last_fire_stamp=nil,0
    local function on_gun_fired(tool)
        if typeof(tool) ~= "Instance" then return end
        local char = lp.Character
        if not char then return end
        local ok, mine = pcall(function() return tool:IsDescendantOf(char) end)
        if not ok or not mine then return end
        local now = os.clock()
        if last_fire_stamp > 0 and want_since > 0 and want_since <= last_fire_stamp then gap_push(now - last_fire_stamp) end
        last_fire_stamp = now
    end
    local function connect_gun_fired()
        if gun_fired_conn then return end
        local m = get_weapon_service()
        if not m then return end
        local ev = m.GunFired
        if typeof(ev) ~= "Instance" then return end
        gun_fired_conn = ev.OnClientEvent:Connect(function(tool) pcall(on_gun_fired, tool) end)
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
        if not SS.auto_on or not SS.enabled or not SS.am_sheriff or not target_alive() then want_since = 0 return end
        local gun, equipped = get_gun()
        if not gun then want_since = 0 return end
        if gun ~= gap_gun then gap_gun = gun gap_reset() end
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
        for k = 1, #watch_conns do pcall(function() watch_conns[k]:Disconnect() end) end
        table.clear(watch_conns)
    end
    local function setup_watch()
        clear_watch()
        local m = get_round()
        if m and m.PlayerDataChanged then
            watch_conns[#watch_conns+1] = m.PlayerDataChanged.Event:Connect(function() pcall(refresh_target) end)
        end
        watch_conns[#watch_conns+1] = lp.CharacterAdded:Connect(function()
            task.wait(0.3)
            pcall(refresh_target)
        end)
    end
    local next_role,next_hook=0,0
    local function tick_silent()
        if force_att and os.clock() - force_stamp > 0.05 then restore_origin() end
        if not SS.enabled then return end
        local now = os.clock()
        if now >= next_role then next_role = now + 0.2 refresh_target() end
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

    addOpt(silent_section, "AddToggle", "SilentEnabled", {Title="Включить", Default=false, Flag="SilentEnabled"}, function(v)
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
        Notify("FH", "Silent "..(v and "ВКЛ" or "ВЫКЛ"), 1.5)
    end)
    addOpt(silent_section, "AddToggle", "SilentPredict", {Title="Предсказание", Default=true, Flag="SilentPredict"}, function(v)
        SS.predict = v
        if not v then track_clear() end
    end)
    addOpt(silent_section, "AddToggle", "SilentForce", {Title="Стрельба через стены", Default=false, Flag="SilentForce"}, function(v)
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
            Notify("FH","Force ВКЛ — предикт выключен", 3)
        else
            restore_origin()
            local so = Options.SilentStandoff
            if so then
                pcall(function() if so.Unlock then so:Unlock() end end)
                pcall(function() so.Locked = false end)
            end
        end
    end)
    addOpt(silent_section, "AddSlider", "SilentStandoff", {Title="Отступ", Default=15, Min=0, Max=40, Rounding=0, Flag="SilentStandoff"}, function(v) SS.stand_off = tonumber(v) or 15 end)
    addOpt(silent_section, "AddToggle", "SilentAuto", {Title="Авто-выстрел", Default=false, Flag="SilentAuto"}, function(v) SS.auto_on = v end)
    addOpt(silent_section, "AddSlider", "SilentAutoDelay", {Title="Задержка авто", Default=0, Min=0, Max=600, Rounding=0, Flag="SilentAutoDelay"}, function(v) SS.auto_delay = (tonumber(v) or 0) / 1000 end)

    getgenv().SILENT_UNLOAD = function()
        SS.enabled=false SS.predict=false SS.force=false SS.auto_on=false
        getgenv().SILENT_AIM_ACTIVE = false
        restore_origin() clear_watch() track_clear()
        if gun_fired_conn then pcall(function() gun_fired_conn:Disconnect() end) gun_fired_conn=nil end
        if main_conn then pcall(function() main_conn:Disconnect() end) main_conn=nil end
        local m = weapon_service
        if m then
            pcall(function() setreadonly(m, false) end)
            if orig_mouse then pcall(function() m.GetMouseTargetCFrame = orig_mouse end) end
            if orig_screen then pcall(function() m.GetTargetPosition = orig_screen end) end
        end
    end
end

-- ============================================================
-- КИЛЛ АУРА
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
    addOpt(kaSec, "AddSlider", "KADist", {Title="Радиус", Min=5, Max=60, Default=30, Rounding=0}, function(v)
        local n = tonumber(v) or 30
        kaV1.dist = n
        kaV2.dist = n
    end)
    AddConn("KAv1Tick",RunService.Heartbeat:Connect(function()
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
                    if th and th.Health > 0 and tp and (tp.Position - my.Position).Magnitude <= kaV1.dist then victims[#victims+1] = tp end
                end
            end
        end
        if #victims > 0 then
            pcall(function() stabbed:FireServer() end)
            for _, v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            kaV1.lastHit = tick()
        end
    end))
    AddConn("KAv2Tick",RunService.Heartbeat:Connect(function()
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
                    if th and th.Health > 0 and tp and (tp.Position - my.Position).Magnitude <= kaV2.dist then victims[#victims+1] = tp end
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
            return ReplicatedStorage:WaitForChild("Remotes", 15):WaitForChild("Gameplay", 15):WaitForChild("CoinsStarted", 15)
        end)
        if ok and remote then
            remote.OnClientEvent:Connect(function() grabFailedRound = false; isGrabbing = false end)
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
    addOpt(tC, "AddToggle", "AutoGrabGun", {Title="Авто-подбор пистолета", Default=false}, function(v) autoGrabEnabled = v end)
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
                pcall(function() firetouchinterest(my, gun, 0) task.wait(0.02) firetouchinterest(my, gun, 1) end)
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
    AddConn("AutoGrabReset", LocalPlayer.CharacterAdded:Connect(function() isGrabbing = false end))
end

-- ============================================================
-- ДВИЖЕНИЕ
-- ============================================================
do
    local tM = Tabs.Movement
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
    addOpt(mvSec, "AddToggle", "BhopStrafe", {Title="Стрейф", Default=false}, function() end)
    local bhopOn,bhopPower,bhopStrafe=false,40,false
    local bhopSpeed,wasJumping,isBoosting=0,false,false
    registerOnChanged("BhopOn", function(v) bhopOn=v end)
    registerOnChanged("BhopPower", function(v) bhopPower=tonumber(v) or 40 end)
    registerOnChanged("BhopStrafe", function(v) bhopStrafe=v end)
    local jumpHoldAt=0
    UserInputService.JumpRequest:Connect(function() jumpHoldAt=os.clock() end)
    local function jumpHeld()
        if os.clock()-jumpHoldAt<0.2 then return true end
        return UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end
    AddConn("BhopTick",RunService.Heartbeat:Connect(function()
        if not bhopOn then wasJumping=false isBoosting=false bhopSpeed=0 return end
        local c=LocalPlayer.Character
        local hum=c and c:FindFirstChildOfClass("Humanoid")
        local hrp=c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local st=hum:GetState()
        local jumping=st==Enum.HumanoidStateType.Jumping
        local airborne=jumping or st==Enum.HumanoidStateType.Freefall
        if bhopStrafe then
            bhopSpeed=0
            if jumping and not wasJumping then
                local dir=hum.MoveDirection
                if dir.Magnitude<0.1 then dir=hrp.CFrame.LookVector end
                dir=Vector3.new(dir.X,0,dir.Z)
                if dir.Magnitude>0 then
                    dir=dir.Unit
                    local v=hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity=Vector3.new(dir.X*bhopPower,v.Y,dir.Z*bhopPower)
                    isBoosting=true
                end
            end
            if isBoosting and airborne then
                local dir=hum.MoveDirection
                if dir.Magnitude>0.1 then
                    dir=Vector3.new(dir.X,0,dir.Z).Unit
                    local v=hrp.AssemblyLinearVelocity
                    local cur=Vector3.new(v.X,0,v.Z)
                    local tgt=dir*bhopPower
                    local nxz=cur:Lerp(tgt,0.3)
                    hrp.AssemblyLinearVelocity=Vector3.new(nxz.X,v.Y,nxz.Z)
                end
            end
            if not airborne then isBoosting=false end
        else
            local base=math.max(hum.WalkSpeed,1)
            local cap=math.max(bhopPower,base)
            local step=math.max(bhopPower*0.1,1)
            if bhopSpeed<base then bhopSpeed=base end
            if jumping and not wasJumping then
                bhopSpeed=math.min(bhopSpeed+step,cap)
                local v=hrp.AssemblyLinearVelocity
                local xz=Vector3.new(v.X,0,v.Z)
                local dir
                if xz.Magnitude>0.1 then dir=xz.Unit
                else
                    local md=hum.MoveDirection
                    if md.Magnitude>0.1 then dir=Vector3.new(md.X,0,md.Z).Unit
                    else local lv=hrp.CFrame.LookVector dir=Vector3.new(lv.X,0,lv.Z) dir=(dir.Magnitude>0) and dir.Unit or Vector3.zero end
                end
                if dir.Magnitude>0 then hrp.AssemblyLinearVelocity=Vector3.new(dir.X*bhopSpeed,v.Y,dir.Z*bhopSpeed) isBoosting=true end
            end
            if airborne and isBoosting then
                local v=hrp.AssemblyLinearVelocity
                local xz=Vector3.new(v.X,0,v.Z)
                local md=hum.MoveDirection
                local dir
                if md.Magnitude>0.1 then dir=Vector3.new(md.X,0,md.Z).Unit
                elseif xz.Magnitude>0.1 then dir=xz.Unit end
                if dir then local sp=math.max(xz.Magnitude,bhopSpeed) hrp.AssemblyLinearVelocity=Vector3.new(dir.X*sp,v.Y,dir.Z*sp) end
            end
            if not airborne then
                isBoosting=false
                if jumpHeld() then hum.Jump=true else bhopSpeed=0 end
            end
        end
        wasJumping=jumping
    end))
    local sgOn,sgPower,sgAccel,sgGround=false,90,0.6,16
    addOpt(mvSec, "AddToggle", "SpeedGlitchOn", {Title="Спидглитч", Default=false}, function(v) sgOn=v end)
    addOpt(mvSec, "AddSlider", "SpeedGlitchPower", {Title="Скорость в прыжке", Min=30, Max=250, Default=90, Rounding=0}, function(v) sgPower=tonumber(v) or 90 end)
    addOpt(mvSec, "AddSlider", "SpeedGlitchAccel", {Title="Разгон", Min=0.1, Max=1, Default=0.6, Rounding=2}, function(v) sgAccel=tonumber(v) or 0.6 end)
    AddConn("SpeedGlitchTick",RunService.Heartbeat:Connect(function()
        if not sgOn then return end
        local c=LocalPlayer.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        local hrp=c and c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return end
        local st=h:GetState()
        local air=st==Enum.HumanoidStateType.Jumping or st==Enum.HumanoidStateType.Freefall
        if air then
            local v=hrp.AssemblyLinearVelocity
            local flat=Vector3.new(v.X,0,v.Z)
            local dir=flat.Magnitude>0.1 and flat.Unit or (function() local lv=hrp.CFrame.LookVector return Vector3.new(lv.X,0,lv.Z).Unit end)()
            local cur=flat.Magnitude
            local target=math.max(cur,sgPower)
            local new_mag=cur+(target-cur)*sgAccel
            hrp.AssemblyLinearVelocity=Vector3.new(dir.X*new_mag,v.Y,dir.Z*new_mag)
        else
            local v=hrp.AssemblyLinearVelocity
            local flat=Vector3.new(v.X,0,v.Z)
            if flat.Magnitude>sgGround then local dir=flat.Unit hrp.AssemblyLinearVelocity=Vector3.new(dir.X*sgGround,v.Y,dir.Z*sgGround) end
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
        if v then flyGrav = Workspace.Gravity Workspace.Gravity = 0
        else flyOff() end
    end)
    if Options.FlyToggle then
        Options.FlyToggle:OnChanged(function(v)
            if v then flyGrav = Workspace.Gravity Workspace.Gravity = 0
            else flyOff() end
        end)
    end
    AddConn("FlyTick",RunService.RenderStepped:Connect(function()
        if not (Options.FlyToggle and Options.FlyToggle.Value) then return end
        local hrp=getHRP() local hum=getHum()
        if not hrp or not hum then return end
        hum.PlatformStand = true
        local sp = (Options.FlySpeed and tonumber(Options.FlySpeed.Value)) or 60
        local dir=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir-Vector3.new(0,1,0) end
        hrp.Velocity = dir.Magnitude>0 and dir.Unit*sp or Vector3.zero
    end))
    AddConn("MovementTick",RunService.Heartbeat:Connect(function()
        local hum=getHum()
        if not hum then return end
        if Options.SpeedToggle and Options.SpeedToggle.Value then
            hum.WalkSpeed=(Options.SpeedValue and tonumber(Options.SpeedValue.Value)) or 32
        end
        if S.frozen then
            hum.WalkSpeed=0
            local hrp=getHRP()
            if hrp then
                if not hrp:FindFirstChild("FH_FreezeBV") then
                    local bv=Instance.new("BodyVelocity")
                    bv.Name="FH_FreezeBV"
                    bv.MaxForce=Vector3.new(1e5,1e5,1e5)
                    bv.Velocity=Vector3.zero
                    bv.Parent=hrp
                end
                local sp=(Options.FreezeSpeed and tonumber(Options.FreezeSpeed.Value)) or 60
                local dir=Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir+Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(S.freezeUpKey) then dir=dir+Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(S.freezeDownKey) then dir=dir-Vector3.new(0,1,0) end
                local bv=hrp:FindFirstChild("FH_FreezeBV")
                if bv then bv.Velocity=dir.Magnitude>0 and dir.Unit*sp or Vector3.zero end
            end
        else
            local hrp=getHRP()
            if hrp then local bv=hrp:FindFirstChild("FH_FreezeBV") if bv then bv:Destroy() end end
        end
        if Options.JumpPowerToggle and Options.JumpPowerToggle.Value then
            hum.UseJumpPower=true
            local jp=(Options.JumpPowerVal and tonumber(Options.JumpPowerVal.Value)) or 100
            if hum.JumpPower~=jp then hum.JumpPower=jp end
        end
        if Options.Spinbot and Options.Spinbot.Value then
            local hrp=getHRP()
            if hrp then
                local s=(Options.SpinSpeed and tonumber(Options.SpinSpeed.Value)) or 8
                hrp.CFrame=hrp.CFrame*CFrame.Angles(0,math.rad(s),0)
            end
        end
    end))
    AddConn("NoclipTick",RunService.Stepped:Connect(function()
        if Options.Noclip and Options.Noclip.Value then
            local c=LocalPlayer.Character
            if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
        end
    end))
    AddConn("InfJump",UserInputService.JumpRequest:Connect(function()
        if Options.InfJump and Options.InfJump.Value then
            local hum=getHum()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))
    local freezeSec=tM:AddSection({Name="Заморозка"})
    addOpt(freezeSec, "AddToggle", "FreezeToggle", {Title="Включить", Default=false}, function(v) S.frozen=v end)
    addOpt(freezeSec, "AddSlider", "FreezeSpeed", {Title="Скорость", Min=20, Max=300, Default=60, Rounding=0}, function() end)
    local fUp=freezeSec:AddKeybind("FreezeUpKey",{Title="Кнопка ВВЕРХ",Default="Space"})
    fUp:OnChanged(function(k) if typeof(k)=="EnumItem" then S.freezeUpKey=k end end)
    registerOnChanged("FreezeUpKey", function(k) if typeof(k)=="EnumItem" then S.freezeUpKey=k end end)
    local fDown=freezeSec:AddKeybind("FreezeDownKey",{Title="Кнопка ВНИЗ",Default="LeftAlt"})
    fDown:OnChanged(function(k) if typeof(k)=="EnumItem" then S.freezeDownKey=k end end)
    registerOnChanged("FreezeDownKey", function(k) if typeof(k)=="EnumItem" then S.freezeDownKey=k end end)
    getgenv().MOVE_UNLOAD=function()
        S.frozen=false
        local hrp=getHRP()
        if hrp then local bv=hrp:FindFirstChild("FH_FreezeBV") if bv then bv:Destroy() end end
        flyOff()
    end
end

-- ============================================================
-- БИНДЫ
-- ============================================================
do
    local tB=Tabs.Binds
    local BIND_LIST={
        {id="SilentEnabled",title="Тихий выстрел",cat="Бой",opt="SilentEnabled"},
        {id="KAOn",title="Килл Аура",cat="Бой",opt="KAOn"},
        {id="AutoGrabGun",title="Авто-подбор пистолета",cat="Бой",opt="AutoGrabGun"},
        {id="SpeedToggle",title="Скорость",cat="Движение",opt="SpeedToggle"},
        {id="Noclip",title="Noclip",cat="Движение",opt="Noclip"},
        {id="Spinbot",title="Спинбот",cat="Движение",opt="Spinbot"},
        {id="InfJump",title="Бесконечный прыжок",cat="Движение",opt="InfJump"},
        {id="JumpPowerToggle",title="Своя сила прыжка",cat="Движение",opt="JumpPowerToggle"},
        {id="SpeedGlitchOn",title="Спидглитч",cat="Движение",opt="SpeedGlitchOn"},
        {id="FlyToggle",title="Полёт",cat="Движение",opt="FlyToggle"},
        {id="BhopOn",title="Банихоп",cat="Движение",opt="BhopOn"},
        {id="FreezeToggle",title="Заморозка",cat="Движение",opt="FreezeToggle"},
        {id="InvisOn",title="Невидимость",cat="Другое",opt="InvisOn"},
    }
    local BindState={}
    for _,e in ipairs(BIND_LIST) do BindState[e.id]={key=nil,touchOn=false,btn=nil,def=e} end
    getgenv().FH_BindState = BindState
    local touchGui=Instance.new("ScreenGui")
    touchGui.Name="FH_TouchBinds_v22"
    touchGui.ResetOnSpawn=false
    touchGui.IgnoreGuiInset=true
    touchGui.DisplayOrder=400
    pcall(function() touchGui.Parent=(gethui and gethui()) or CoreGui end)
    if not touchGui.Parent then touchGui.Parent=CoreGui end
    local buttonsFrozen=false
    getgenv().FH_ButtonsFrozen=false
    local function fireBind(id)
        local st=BindState[id]
        if not st then return end
        local def=st.def
        if def.opt then
            local o=Options[def.opt]
            if o and o.Value~=nil then
                o:SetValue(not o.Value)
                Notify("FH",def.title..": "..tostring(o.Value),1.2)
            end
        end
    end
    local function centerSpawn()
        local vp=(Camera and Camera.ViewportSize) or Vector2.new(1280,720)
        return vp.X*0.5-75, vp.Y*0.5-17
    end
    local function makeTouchButton(id)
        local st=BindState[id]
        if not st or st.btn then return end
        local def=st.def
        local btn=Instance.new("TextButton")
        btn.Name="FH_BTN_"..id
        btn.Size=UDim2.fromOffset(150,34)
        local sx,sy=centerSpawn()
        btn.Position=UDim2.fromOffset(sx,sy)
        btn.BackgroundColor3=Color3.fromRGB(28,22,42)
        btn.BorderSizePixel=0
        btn.Text=def.title
        btn.TextColor3=Color3.fromRGB(235,225,255)
        btn.Font=Enum.Font.GothamSemibold
        btn.TextSize=13
        btn.AutoButtonColor=true
        btn.Active=true
        btn.ZIndex=3
        btn.Parent=touchGui
        Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
        local stroke=Instance.new("UIStroke",btn)
        stroke.Color=Color3.fromRGB(138,92,246)
        stroke.Thickness=1
        stroke.Transparency=0.35
        local dragging,dragStart,posStart,moved=false,nil,nil,false
        btn.InputBegan:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                dragging=true moved=false
                dragStart=i.Position posStart=btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if getgenv().FH_ButtonsFrozen then return end
            if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
                local d=i.Position-dragStart
                if math.abs(d.X)>4 or math.abs(d.Y)>4 then moved=true end
                if moved then
                    btn.Position=UDim2.new(posStart.X.Scale,posStart.X.Offset+d.X,posStart.Y.Scale,posStart.Y.Offset+d.Y)
                end
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end
            if not dragging then return end
            local wasTap=not moved
            dragging=false
            if wasTap then fireBind(id) end
        end)
        st.btn=btn
    end
    local function killTouchButton(id)
        local st=BindState[id]
        if not st then return end
        if st.btn then pcall(function() st.btn:Destroy() end) st.btn=nil end
    end
    local listSec=tB:AddSection({Name="Модули"})
    local currentCat=nil
    for _,def in ipairs(BIND_LIST) do
        if def.cat~=currentCat then
            currentCat=def.cat
            pcall(function() listSec:AddButton({Title="--- "..currentCat.." ---",Callback=function() end}) end)
        end
        local st=BindState[def.id]
        local kb = listSec:AddKeybind("BIND_KEY_"..def.id,{Title=def.title,Default="Unknown"})
        kb:OnChanged(function(k)
            if typeof(k)=="EnumItem" then
                st.key=k
                Notify("FH","Бинд: "..def.title.." > "..tostring(k),2)
            else st.key=nil end
        end)
        registerOnChanged("BIND_KEY_"..def.id, function(k)
            if typeof(k)=="EnumItem" then st.key=k else st.key=nil end
        end)
        addOpt(listSec, "AddToggle", "BIND_TCH_"..def.id, {Title="  Кнопка: "..def.title, Default=false}, function(v)
            st.touchOn=v
            if v then makeTouchButton(def.id) else killTouchButton(def.id) end
        end)
    end
    UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe then return end
        if input.UserInputType~=Enum.UserInputType.Keyboard then return end
        for id,st in pairs(BindState) do
            if st.key and input.KeyCode==st.key then fireBind(id) end
        end
    end)
    local setSec=tB:AddSection({Name="Настройки биндов"})
    addOpt(setSec, "AddToggle", "BIND_FREEZE", {Title="Заморозка кнопок", Default=false}, function(v)
        buttonsFrozen=v
        getgenv().FH_ButtonsFrozen=v
        Notify("FH",v and "Кнопки заморожены" or "Кнопки разморожены",1.5)
    end)
    setSec:AddButton({Title="Сбросить все бинды",Callback=function()
        local count=0
        for id,st in pairs(BindState) do
            st.key=nil
            if Options["BIND_KEY_"..id] then
                pcall(function() Options["BIND_KEY_"..id]:SetValue(Enum.KeyCode.Unknown) end)
                count=count+1
            end
        end
        Notify("FH","Сброшено биндов: "..count,2)
    end})
    setSec:AddButton({Title="Удалить все кнопки",Callback=function()
        for id,st in pairs(BindState) do
            st.touchOn=false
            if Options["BIND_TCH_"..id] then pcall(function() Options["BIND_TCH_"..id]:SetValue(false) end) end
            killTouchButton(id)
        end
        Notify("FH","Все кнопки удалены",2)
    end})
    getgenv().BINDS_UNLOAD=function()
        for id,st in pairs(BindState) do killTouchButton(id) end
        pcall(function() touchGui:Destroy() end)
    end
end

-- ============================================================
-- НАСТРОЙКИ (с фиксом конфигов — полный рекурсивный serialize)
-- ============================================================
do
    local tS=Tabs.Settings
    local setSec=tS:AddSection({Name="Основные"})
    addOpt(setSec, "AddToggle", "ShowHUD", {Title="Показывать HUD", Default=true}, function(v) if HUDGui then HUDGui.Enabled=v end end)
    addOpt(setSec, "AddSlider", "FPSCap", {Title="Лимит FPS (0 - без лимита)", Min=0, Max=9999, Default=0, Rounding=0}, function(v) pcall(function() if setfpscap then setfpscap(tonumber(v) or 0) end end) end)
    setSec:AddButton({Title="Переподключиться к серверу",Callback=function() TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer) end})
    setSec:AddButton({Title="Сменить сервер",Callback=function()
        pcall(function()
            local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
            local data=game:HttpGet(url)
            local parsed=HttpService:JSONDecode(data)
            for _,s in ipairs(parsed.data) do
                if s.playing<s.maxPlayers and s.id~=game.JobId then TeleportService:TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer) break end
            end
        end)
    end})
    addOpt(setSec, "AddToggle", "AntiAFK", {Title="Anti-AFK", Default=true}, function() end)
    AddConn("AntiAFK",LocalPlayer.Idled:Connect(function()
        if Options.AntiAFK and Options.AntiAFK.Value then
            pcall(function() VirtualUser:Button2Down(Vector2.new(0,0),Camera.CFrame) task.wait(1) VirtualUser:Button2Up(Vector2.new(0,0),Camera.CFrame) end)
        end
    end))
    setSec:AddButton({Title="Выгрузить скрипт",Callback=function()
        for _,c in pairs(Connections) do pcall(function() c:Disconnect() end) end
        Connections={}
        if HUDGui then HUDGui:Destroy() end
        if Window then pcall(function() Window:Destroy() end) end
        Notify("FH","Скрипт выгружен",3)
    end})

    local cfgSec=tS:AddSection({Name="Конфиги"})
    local CONFIG_DIR="FortniHub_Configs/"
    local CONFIG_EXT=".txt"
    local function ensureConfigDir()
        if type(isfolder)~="function" or type(makefolder)~="function" then return false end
        local ok,has=pcall(isfolder,CONFIG_DIR)
        if not ok then return false end
        if has then return true end
        return pcall(makefolder,CONFIG_DIR)==true
    end
    local function listConfigs()
        local out={}
        if type(listfiles)~="function" then return out end
        if not ensureConfigDir() then return out end
        local ok,files=pcall(listfiles,CONFIG_DIR)
        if not ok or type(files)~="table" then return out end
        for _,f in ipairs(files) do
            local name=string.match(f,"([^/\\]+)"..CONFIG_EXT.."$")
            if name then out[#out+1]=name end
        end
        return out
    end

    -- ============================================================
    -- РЕКУРСИВНАЯ СЕРИАЛИЗАЦИЯ (фикс конфигов с вложенными таблицами)
    -- ============================================================
    local function serializeValue(v, depth)
        depth = depth or 0
        if depth > 12 then return nil end
        if typeof(v)=="Color3" then
            return string.format("C:%.6f,%.6f,%.6f", v.R, v.G, v.B)
        end
        if typeof(v)=="EnumItem" then
            if v.EnumType == Enum.KeyCode then return "K:"..v.Name end
            return "E:"..tostring(v.EnumType).."|"..v.Name
        end
        if typeof(v)=="Vector3" then
            return string.format("V:%.4f,%.4f,%.4f", v.X, v.Y, v.Z)
        end
        local t=type(v)
        if t=="number" then return "N:"..tostring(v) end
        if t=="boolean" then return "B:"..tostring(v) end
        if t=="string" then
            if Enum.KeyCode[v] then return "K:"..v end
            v = v:gsub("\\","\\\\"):gsub("\n","\\n"):gsub("\t","\\t")
            return "S:"..v
        end
        if t=="table" then
            local isArray=true
            for k in pairs(v) do
                if type(k)~="number" then isArray=false break end
            end
            if isArray then
                local parts={}
                for i=1,#v do
                    local sv = serializeValue(v[i], depth+1)
                    if sv then parts[#parts+1]=sv else parts[#parts+1]="X:" end
                end
                return "L:"..table.concat(parts,"\2")
            else
                local parts={}
                for k,val in pairs(v) do
                    local sv = serializeValue(val, depth+1)
                    if sv then
                        parts[#parts+1]=tostring(k).."="..sv
                    end
                end
                return "D:"..table.concat(parts,"\3")
            end
        end
        return nil
    end

    local function deserializeValue(s, depth)
        depth = depth or 0
        if depth > 12 then return nil end
        local prefix,rest=string.match(s,"^(%a):(.*)$")
        if not prefix then return nil end
        if prefix=="K" then return Enum.KeyCode[rest] end
        if prefix=="C" then
            local r,g,b=string.match(rest,"([^,]+),([^,]+),([^,]+)")
            if r and g and b then return Color3.new(tonumber(r),tonumber(g),tonumber(b)) end
            return nil
        end
        if prefix=="V" then
            local x,y,z=string.match(rest,"([^,]+),([^,]+),([^,]+)")
            if x and y and z then return Vector3.new(tonumber(x),tonumber(y),tonumber(z)) end
            return nil
        end
        if prefix=="E" then
            local enumType,name=string.match(rest,"^([^|]+)|(.+)$")
            if enumType and name then
                local et=Enum[enumType]
                if et and et[name] then return et[name] end
            end
            return nil
        end
        if prefix=="N" then return tonumber(rest) end
        if prefix=="B" then return rest=="true" end
        if prefix=="S" then
            return rest:gsub("\\t","\t"):gsub("\\n","\n"):gsub("\\\\","\\")
        end
        if prefix=="L" then
            local out={}
            for piece in string.gmatch(rest,"([^\2]*)") do
                if piece~="" and piece~="X:" then
                    local val=deserializeValue(piece,depth+1)
                    out[#out+1]=val
                end
            end
            return out
        end
        if prefix=="D" then
            local out={}
            for pair in string.gmatch(rest,"([^\3]*)") do
                if pair~="" then
                    local k,val=string.match(pair,"^(.-)=(.*)$")
                    if k and val then
                        out[k]=deserializeValue(val,depth+1)
                    end
                end
            end
            return out
        end
        return nil
    end

    local function saveConfig(name)
        if type(writefile)~="function" then Notify("FH","Нет writefile",4) return false end
        if not ensureConfigDir() then Notify("FH","Не создал папку",4) return false end
        local lines={"-- FortniHub Config: "..tostring(name),"-- "..os.date("%Y-%m-%d %H:%M:%S")}
        for optionName,option in pairs(Options) do
            if option and option.Value~=nil then
                local ser=serializeValue(option.Value)
                if ser then lines[#lines+1]=optionName.."\t"..ser end
            end
        end
        local path=CONFIG_DIR..name..CONFIG_EXT
        local ok=pcall(writefile,path,table.concat(lines,"\n"))
        if ok then Notify("FH","Сохранено: "..name,3) return true end
        Notify("FH","Ошибка сохранения",3)
        return false
    end

    local function loadConfig(name)
        if type(readfile)~="function" then Notify("FH","Нет readfile",4) return false end
        local path=CONFIG_DIR..name..CONFIG_EXT
        local ok,data=pcall(readfile,path)
        if not ok or type(data)~="string" then Notify("FH","Ошибка чтения",3) return false end
        local loaded,bindLoaded=0,0
        local BS = getgenv().FH_BindState
        for line in string.gmatch(data,"[^\r\n]+") do
            if line:sub(1,2)~="--" then
                local key,ser=string.match(line,"^([^\t]+)\t(.+)$")
                if key and ser then
                    if key:sub(1,9)=="BIND_KEY_" then
                        local id = key:sub(10)
                        local enumVal = nil
                        if ser:sub(1,2)=="K:" then
                            enumVal = Enum.KeyCode[ser:sub(3)]
                        elseif ser:sub(1,2)=="E:" then
                            local raw = ser:sub(3)
                            local et,kn = string.match(raw,"^([^|]+)|(.+)$")
                            if et and kn then local E=Enum[et] if E and E[kn] then enumVal=E[kn] end end
                        elseif ser:sub(1,2)=="S:" then
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
                        local val=deserializeValue(ser)
                        if val~=nil and Options[key] then
                            local okSet = pcall(function() Options[key]:SetValue(val) end)
                            fireRegistered(key, val)
                            if okSet then loaded=loaded+1 end
                        end
                    end
                end
            end
        end
        Notify("FH","Загружено: "..name.." ("..loaded..", биндов: "..bindLoaded..")",4)
        return true
    end
    local function deleteConfig(name)
        if type(delfile)~="function" then Notify("FH","Нет delfile",4) return false end
        local ok=pcall(delfile,CONFIG_DIR..name..CONFIG_EXT)
        if ok then Notify("FH","Удалено: "..name,2) return true end
        return false
    end
    local currentList=listConfigs()
    if #currentList==0 then currentList={"(нет конфигов)"} end
    local drop=cfgSec:AddDropdown("ConfigPick",{Title="Выбрать конфиг",Values=currentList,Default=currentList[1]})
    local function refreshList()
        local list=listConfigs()
        if #list==0 then list={"(нет конфигов)"} end
        pcall(function() drop:SetValues(list) if drop.Generate then drop:Generate() end end)
    end
    cfgSec:AddInput("ConfigName",{Title="Имя конфига",Default="my_config"})
    cfgSec:AddButton({Title="Сохранить",Callback=function()
        local nameOpt=Options.ConfigName
        local name=nameOpt and nameOpt.Value or "my_config"
        if type(name)~="string" or name=="" then Notify("FH","Введи имя",3) return end
        if saveConfig(name) then refreshList() end
    end})
    cfgSec:AddButton({Title="Загрузить",Callback=function()
        local pickOpt=Options.ConfigPick
        local name=pickOpt and pickOpt.Value
        if type(name)~="string" or name=="" or name=="(нет конфигов)" then Notify("FH","Выбери конфиг",3) return end
        loadConfig(name)
    end})
    cfgSec:AddButton({Title="Удалить",Callback=function()
        local pickOpt=Options.ConfigPick
        local name=pickOpt and pickOpt.Value
        if type(name)~="string" or name=="" or name=="(нет конфигов)" then Notify("FH","Выбери конфиг",3) return end
        if deleteConfig(name) then refreshList() end
    end})
    cfgSec:AddButton({Title="Обновить список",Callback=refreshList})
    if HUDGui then HUDGui.Enabled=true end
end

print("[FH] ============================================")
print("[FH] Part 1/2 v20.2 — "..CREDITS)
print("[FH] Combat / Movement / Binds / Settings")
print("[FH] ============================================")
-- ============================================================
-- FortniHub MM2 v20.2 BETA — ЧАСТЬ 2/2
-- Visual / Effects / Farm / Utility / Troll / Extra
-- ============================================================

if not (Window and Options and Notify and getRoundData and getRoleFromData and getHRP and getHum) then
    warn("[FH] Part 1 не загружена.")
    return
end
local Tabs=getgenv().FH_Tabs
if not Tabs then warn("[FH] FH_Tabs не найден.") return end
local OnChangedRegistry=getgenv().FH_OnChangedRegistry or {}
getgenv().FH_OnChangedRegistry=OnChangedRegistry
local function registerOnChanged(name, cb) OnChangedRegistry[name]=cb end
local function addOpt(container, method, name, opts, callback)
    local opt = container[method](container, name, opts)
    if opt and callback then
        opt:OnChanged(callback)
        registerOnChanged(name, callback)
    end
    return opt
end
local _uiRoot = function() return (gethui and gethui()) or CoreGui end

-- ============================================================
-- ESP ИГРОКОВ
-- ============================================================
do
    local espState={
        enabled=false,box=false,boxCol={Color3.fromRGB(255,255,255),1},boxType="Static",
        boxGrd=false,boxGrd1=Color3.fromRGB(255,60,60),boxGrd2=Color3.fromRGB(255,180,60),
        boxFill=false,boxFillCol={Color3.fromRGB(255,60,60),0.5},
        name=false,nameCol={Color3.new(1,1,1),1},dist=false,distCol={Color3.fromRGB(220,220,220),1},
        avatar=false,skel=false,skelCol={Color3.new(1,1,1),1},chams=false,
        chamsFMur={Color3.fromRGB(255,60,60),0.55},chamsOMur={Color3.fromRGB(255,60,60),0.15},
        chamsFInno={Color3.new(1,1,1),0.55},chamsOInno={Color3.new(1,1,1),0.15},
        chamsFShf={Color3.fromRGB(0,153,255),0.55},chamsOShf={Color3.fromRGB(0,153,255),0.15},
        chamsFHero={Color3.fromRGB(255,215,0),0.55},chamsOHero={Color3.fromRGB(255,215,0),0.15},
        matChams=false,matType="ForceField",matColMur=Color3.fromRGB(255,60,60),
        matColInno=Color3.new(1,1,1),matColShf=Color3.fromRGB(0,153,255),matColHero=Color3.fromRGB(255,215,0),
        flags=false,flagMur={Color3.fromRGB(255,60,60),1},flagShf={Color3.fromRGB(0,153,255),1},flagHero={Color3.fromRGB(255,215,0),1},
        arrows=false,arrowMur=Color3.fromRGB(255,60,60),arrowInno=Color3.new(1,1,1),
        arrowShf=Color3.fromRGB(0,153,255),arrowHero=Color3.fromRGB(255,215,0),
        arrowSize=42,arrowDist=260,maxDist=500,allowLocal=false,
        gunEspOn=false,gunTextOn=false,gunTextCol=Color3.new(1,1,1),
        gunHlOn=false,gunHlCol=Color3.new(1,1,1),
    }
    _G.FH_ESP=espState
    local drawCache={}
    local chamsFolder=Instance.new("Folder") chamsFolder.Name="FH_Chams" chamsFolder.Parent=Workspace
    local gunFolder=Instance.new("Folder") gunFolder.Name="FH_GunChams" gunFolder.Parent=Workspace
    local function classifyRole(p)
        local r=getRoleFromData(p)
        if r=="murderer" then return "Mur" end
        if r=="sheriff" then return "Shf" end
        if r=="hero" then return "Hero" end
        return "Inno"
    end
    local function roleColor(role)
        if role=="Mur" then return Color3.fromRGB(255,60,60) end
        if role=="Shf" then return Color3.fromRGB(0,153,255) end
        if role=="Hero" then return Color3.fromRGB(255,215,0) end
        return Color3.new(1,1,1)
    end
    local function getDraw(p)
        local d=drawCache[p]
        if d then return d end
        d={box={},boxFill=nil,name=nil,dist=nil,avatar=nil,skel={},flags={},arrow=nil}
        drawCache[p]=d
        return d
    end
    local function ensureBox(e,i)
        if e.box[i] then return e.box[i] end
        local d=Drawing.new("Line") d.Thickness=1.5 d.Transparency=1 d.Visible=false e.box[i]=d return d
    end
    local function grad(c1,c2)
        local t=math.sin(os.clock()*3)*0.5+0.5
        return c1:Lerp(c2,t)
    end
    local function dispose(e)
        for _,d in pairs(e.box) do pcall(function() d:Remove() end) end
        if e.boxFill then pcall(function() e.boxFill:Remove() end) end
        if e.name then pcall(function() e.name:Remove() end) end
        if e.dist then pcall(function() e.dist:Remove() end) end
        if e.avatar then pcall(function() e.avatar:Remove() end) end
        for _,d in pairs(e.skel) do pcall(function() d:Remove() end) end
        for _,d in pairs(e.flags) do pcall(function() d:Remove() end) end
        if e.arrow then pcall(function() e.arrow:Remove() end) end
    end
    local chams={}
    local function killCham(p)
        local h=chams[p]
        if h then pcall(function() h:Destroy() end) chams[p]=nil end
    end
    local function ensureCham(p,char)
        local h=chams[p]
        if h and h.Parent and h.Adornee==char then return h end
        if h then pcall(function() h:Destroy() end) end
        h=Instance.new("Highlight")
        h.Name="FH_"..p.Name
        h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee=char
        h.Parent=chamsFolder
        chams[p]=h
        return h
    end
    local matCache={}
    local function restoreMat()
        for part,o in pairs(matCache) do
            if part.Parent then
                pcall(function() part.Material=o.m end)
                pcall(function() part.Color=o.c end)
            end
        end
        table.clear(matCache)
    end
    local function updateMatChams()
        if not espState.matChams then
            if next(matCache) then restoreMat() end
            return
        end
        local mat=Enum.Material.ForceField
        if espState.matType=="Flat" then mat=Enum.Material.SmoothPlastic
        elseif espState.matType=="Chromatic" then mat=Enum.Material.Foil end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local role=classifyRole(p)
                local col
                if role=="Mur" then col=espState.matColMur
                elseif role=="Shf" then col=espState.matColShf
                elseif role=="Hero" then col=espState.matColHero
                else col=espState.matColInno end
                for _,part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then
                        if not matCache[part] then matCache[part]={m=part.Material,c=part.Color} end
                        pcall(function() part.Material=mat end)
                        pcall(function() part.Color=col end)
                    end
                end
            end
        end
    end
    local gunCache,gunCandidates,gunScanAcc={},{},0
    local function inCharacter(obj)
        local node=obj.Parent
        while node and node~=Workspace do
            if node:IsA("Model") and Players:GetPlayerFromCharacter(node) then return true end
            node=node.Parent
        end
        return false
    end
    local function renderPart(obj)
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true) end
        return obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart",true)
    end
    local function collectGuns()
        local list={}
        for obj in pairs(gunCandidates) do
            if obj.Name=="GunDrop" and obj.Parent and not inCharacter(obj) then
                local part=renderPart(obj)
                if part then
                    local adorn=(obj:IsA("BasePart") or obj:IsA("Model")) and obj or part
                    list[#list+1]={obj=obj,part=part,adorn=adorn}
                end
            end
        end
        return list
    end
    local function clearGun(obj)
        local e=gunCache[obj]
        if e then
            if e.hl then pcall(function() e.hl:Destroy() end) end
            if e.txt then pcall(function() e.txt:Remove() end) end
            gunCache[obj]=nil
        end
    end
    local function clearGuns()
        for obj in pairs(gunCache) do clearGun(obj) end
    end
    local gunParts={}
    local function gunRender(dt)
        if not espState.gunEspOn then
            if next(gunCache) then clearGuns() end
            return
        end
        gunScanAcc=gunScanAcc+dt
        if gunScanAcc>=0.25 then
            gunScanAcc=0
            gunParts=collectGuns()
            local set={}
            for _,entry in ipairs(gunParts) do set[entry.obj]=true end
            for obj in pairs(gunCache) do if not set[obj] then clearGun(obj) end end
        end
        for _,entry in ipairs(gunParts) do
            local obj,part=entry.obj,entry.part
            if obj.Parent and part and part.Parent then
                local e=gunCache[obj]
                if not e then e={} gunCache[obj]=e end
                if espState.gunHlOn then
                    if not e.hl then
                        local hl=Instance.new("Highlight")
                        hl.FillTransparency=1
                        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent=gunFolder
                        e.hl=hl
                    end
                    e.hl.Adornee=entry.adorn
                    e.hl.OutlineColor=espState.gunHlCol
                    e.hl.OutlineTransparency=0
                    e.hl.Enabled=true
                elseif e.hl then e.hl.Enabled=false end
                if espState.gunTextOn then
                    local sp=Camera:WorldToViewportPoint(part.Position)
                    if not e.txt then
                        local t=Drawing.new("Text")
                        t.Center=true t.Outline=true t.Size=13
                        e.txt=t
                    end
                    if sp.Z>0 then
                        e.txt.Position=Vector2.new(sp.X,sp.Y)
                        e.txt.Text="Gun"
                        e.txt.Color=espState.gunTextCol
                        e.txt.Visible=true
                    else e.txt.Visible=false end
                elseif e.txt then e.txt.Visible=false end
            else clearGun(obj) end
        end
    end
    local function collectCandidates()
        table.clear(gunCandidates)
        for _,obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name=="GunDrop" and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool")) then
                gunCandidates[obj]=true
            end
        end
    end
    Workspace.DescendantAdded:Connect(function(obj)
        if obj.Name=="GunDrop" and (obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Tool")) then gunCandidates[obj]=true end
    end)
    Workspace.DescendantRemoving:Connect(function(obj)
        if obj.Name=="GunDrop" then gunCandidates[obj]=nil end
    end)
    RunService.RenderStepped:Connect(function(dt)
        local seen={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p==LocalPlayer and not espState.allowLocal then
                killCham(p)
            else
                local char=p.Character
                local hrp=char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
                local head=char and char:FindFirstChild("Head")
                local hum=char and char:FindFirstChildOfClass("Humanoid")
                if char and hrp and head and hum and hum.Health>0 then
                    seen[p]=true
                    local role=classifyRole(p)
                    local dcol=roleColor(role)
                    local dist=(Camera.CFrame.Position-hrp.Position).Magnitude
                    local fade=math.clamp(1-dist/espState.maxDist,0.15,1)
                    if espState.enabled then
                        local headPos=head.Position+Vector3.new(0,head.Size.Y*0.5,0)
                        local footPos=hrp.Position-Vector3.new(0,hrp.Size.Y*0.5+(hum.HipHeight or 0),0)
                        local hsp,hon=Camera:WorldToViewportPoint(headPos)
                        local fsp,fon=Camera:WorldToViewportPoint(footPos)
                        if hon or fon then
                            local e=getDraw(p)
                            if espState.box then
                                local w=math.max(40,(hsp.Y-fsp.Y)*0.5)
                                local cx=(hsp.X+fsp.X)*0.5
                                local top,bot=hsp.Y,fsp.Y
                                local l,r=cx-w,cx+w
                                local col=espState.boxGrd and grad(espState.boxGrd1,espState.boxGrd2) or espState.boxCol[1]
                                local a=(espState.boxCol[2] or 1)*fade
                                if espState.boxType=="Corners" then
                                    local sg=math.min(w,bot-top)*0.25
                                    local lines={
                                        {l,top,l+sg,top},{l,top,l,top+sg},
                                        {r,top,r-sg,top},{r,top,r,top+sg},
                                        {l,bot,l+sg,bot},{l,bot,l,bot-sg},
                                        {r,bot,r-sg,bot},{r,bot,r,bot-sg},
                                    }
                                    for i,ln in ipairs(lines) do
                                        local line=ensureBox(e,i)
                                        line.From=Vector2.new(ln[1],ln[2])
                                        line.To=Vector2.new(ln[3],ln[4])
                                        line.Color=col line.Transparency=a line.Visible=true
                                    end
                                    for i=#lines+1,#e.box do e.box[i].Visible=false end
                                else
                                    local lines={{l,top,r,top},{r,top,r,bot},{r,bot,l,bot},{l,bot,l,top}}
                                    for i,ln in ipairs(lines) do
                                        local line=ensureBox(e,i)
                                        line.From=Vector2.new(ln[1],ln[2])
                                        line.To=Vector2.new(ln[3],ln[4])
                                        line.Color=col line.Transparency=a line.Visible=true
                                    end
                                    for i=5,#e.box do e.box[i].Visible=false end
                                end
                                if espState.boxFill then
                                    if not e.boxFill then
                                        e.boxFill=Drawing.new("Square")
                                        e.boxFill.Filled=true
                                        e.boxFill.Thickness=0
                                    end
                                    e.boxFill.Position=Vector2.new(l,top)
                                    e.boxFill.Size=Vector2.new(r-l,bot-top)
                                    e.boxFill.Color=dcol
                                    e.boxFill.Transparency=(espState.boxFillCol[2] or 0.5)*fade
                                    e.boxFill.Visible=true
                                elseif e.boxFill then e.boxFill.Visible=false end
                            else
                                for _,ln in pairs(e.box) do ln.Visible=false end
                                if e.boxFill then e.boxFill.Visible=false end
                            end
                            if espState.name then
                                if not e.name then
                                    e.name=Drawing.new("Text")
                                    e.name.Size=13 e.name.Center=true e.name.Outline=true
                                end
                                e.name.Text=p.Name
                                e.name.Position=Vector2.new((hsp.X+fsp.X)*0.5,hsp.Y-18)
                                e.name.Color=espState.nameCol[1]
                                e.name.Transparency=(espState.nameCol[2] or 1)*fade
                                e.name.Visible=true
                            elseif e.name then e.name.Visible=false end
                            if espState.dist then
                                if not e.dist then
                                    e.dist=Drawing.new("Text")
                                    e.dist.Size=12 e.dist.Center=true e.dist.Outline=true
                                end
                                e.dist.Text=string.format("%d studs",math.floor(dist))
                                e.dist.Position=Vector2.new((hsp.X+fsp.X)*0.5,fsp.Y+4)
                                e.dist.Color=espState.distCol[1]
                                e.dist.Transparency=(espState.distCol[2] or 1)*fade
                                e.dist.Visible=true
                            elseif e.dist then e.dist.Visible=false end
                            if espState.avatar then
                                if not e.avatar then
                                    e.avatar=Drawing.new("Image")
                                    e.avatar.Size=Vector2.new(40,40)
                                    local av = getgenv().FH_GetAvatarFor and getgenv().FH_GetAvatarFor(p)
                                    if av then e.avatar.Data=av end
                                end
                                e.avatar.Position=Vector2.new((hsp.X+fsp.X)*0.5-20,hsp.Y-60)
                                e.avatar.Transparency=fade
                                e.avatar.Visible=true
                            elseif e.avatar then e.avatar.Visible=false end
                            if espState.skel then
                                local bones={
                                    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
                                    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
                                    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
                                    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
                                    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
                                }
                                for i,b in ipairs(bones) do
                                    local p1=char:FindFirstChild(b[1])
                                    local p2=char:FindFirstChild(b[2])
                                    if p1 and p2 and p1:IsA("BasePart") and p2:IsA("BasePart") then
                                        local s1,o1=Camera:WorldToViewportPoint(p1.Position)
                                        local s2,o2=Camera:WorldToViewportPoint(p2.Position)
                                        if not e.skel[i] then
                                            local dr=Drawing.new("Line")
                                            dr.Thickness=1 dr.Transparency=1
                                            e.skel[i]=dr
                                        end
                                        local dr=e.skel[i]
                                        if o1 and o2 then
                                            dr.From=Vector2.new(s1.X,s1.Y)
                                            dr.To=Vector2.new(s2.X,s2.Y)
                                            dr.Color=espState.skelCol[1]
                                            dr.Transparency=(espState.skelCol[2] or 1)*fade
                                            dr.Visible=true
                                        else dr.Visible=false end
                                    elseif e.skel[i] then e.skel[i].Visible=false end
                                end
                                for i=#bones+1,#e.skel do e.skel[i].Visible=false end
                            else
                                for _,dr in pairs(e.skel) do dr.Visible=false end
                            end
                            if espState.flags then
                                local txt=role=="Mur" and "[MURD]" or (role=="Shf" and "[SHF]" or (role=="Hero" and "[HERO]" or ""))
                                if txt~="" then
                                    if not e.flags[1] then
                                        e.flags[1]=Drawing.new("Text")
                                        e.flags[1].Size=13 e.flags[1].Outline=true
                                    end
                                    local dr=e.flags[1]
                                    dr.Text=txt
                                    dr.Position=Vector2.new(hsp.X+60,hsp.Y-10)
                                    dr.Color=role=="Mur" and espState.flagMur[1] or (role=="Hero" and espState.flagHero[1] or espState.flagShf[1])
                                    dr.Transparency=fade
                                    dr.Visible=true
                                else
                                    for _,dr in pairs(e.flags) do dr.Visible=false end
                                end
                            else
                                for _,dr in pairs(e.flags) do dr.Visible=false end
                            end
                            if espState.arrows then
                                local vp=Camera.ViewportSize
                                local onScreen=hsp.X>=0 and hsp.X<=vp.X and hsp.Y>=0 and hsp.Y<=vp.Y
                                if onScreen then
                                    if e.arrow then e.arrow.Visible=false end
                                else
                                    if not e.arrow then
                                        e.arrow=Drawing.new("Triangle")
                                        e.arrow.Filled=true
                                    end
                                    local cx,cy=vp.X*0.5,vp.Y*0.5
                                    local dir=Vector2.new(hsp.X-cx,hsp.Y-cy)
                                    if dir.Magnitude<0.01 then dir=Vector2.new(0,1) end
                                    dir=dir.Unit
                                    local px=cx+dir.X*espState.arrowDist
                                    local py=cy+dir.Y*espState.arrowDist
                                    local sz=espState.arrowSize
                                    local perp=Vector2.new(-dir.Y,dir.X)
                                    e.arrow.PointA=Vector2.new(px+dir.X*sz*0.5,py+dir.Y*sz*0.5)
                                    e.arrow.PointB=Vector2.new(px-dir.X*sz*0.5+perp.X*sz*0.5,py-dir.Y*sz*0.5+perp.Y*sz*0.5)
                                    e.arrow.PointC=Vector2.new(px-dir.X*sz*0.5-perp.X*sz*0.5,py-dir.Y*sz*0.5-perp.Y*sz*0.5)
                                    e.arrow.Color=role=="Mur" and espState.arrowMur or (role=="Shf" and espState.arrowShf or (role=="Hero" and espState.arrowHero or espState.arrowInno))
                                    e.arrow.Transparency=fade
                                    e.arrow.Visible=true
                                end
                            elseif e.arrow then e.arrow.Visible=false end
                        end
                    else
                        local e=drawCache[p]
                        if e then
                            for _,ln in pairs(e.box) do ln.Visible=false end
                            if e.boxFill then e.boxFill.Visible=false end
                            if e.name then e.name.Visible=false end
                            if e.dist then e.dist.Visible=false end
                            if e.avatar then e.avatar.Visible=false end
                            for _,dr in pairs(e.skel) do dr.Visible=false end
                            for _,dr in pairs(e.flags) do dr.Visible=false end
                            if e.arrow then e.arrow.Visible=false end
                        end
                    end
                    if espState.chams then
                        local h=ensureCham(p,char)
                        local fill=espState["chamsF"..role] or espState.chamsFInno
                        local outl=espState["chamsO"..role] or espState.chamsOInno
                        h.FillColor=fill[1]
                        h.FillTransparency=fill[2]
                        h.OutlineColor=outl[1]
                        h.OutlineTransparency=outl[2]
                    else killCham(p) end
                else
                    local e=drawCache[p]
                    if e then
                        for _,ln in pairs(e.box) do ln.Visible=false end
                        if e.boxFill then e.boxFill.Visible=false end
                        if e.name then e.name.Visible=false end
                        if e.dist then e.dist.Visible=false end
                        if e.avatar then e.avatar.Visible=false end
                        for _,dr in pairs(e.skel) do dr.Visible=false end
                        for _,dr in pairs(e.flags) do dr.Visible=false end
                        if e.arrow then e.arrow.Visible=false end
                    end
                    killCham(p)
                end
            end
        end
        for p,e in pairs(drawCache) do
            if not seen[p] then dispose(e) drawCache[p]=nil end
        end
        updateMatChams()
        gunRender(dt)
    end)
    Players.PlayerRemoving:Connect(function(p) killCham(p) end)
    local tV=Tabs.Visual
    local espSec=tV:AddSection({Name="ESP Игроков"})
    addOpt(espSec, "AddToggle", "ESPOn", {Title="Включить ESP", Default=false}, function(v)
        espState.enabled=v
        if not v then
            for _,e in pairs(drawCache) do dispose(e) end
            drawCache={}
        end
    end)
    addOpt(espSec, "AddToggle", "ESPBox", {Title="Рамка", Default=false}, function(v) espState.box=v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxCol", {Title="Цвет рамки", Default=Color3.new(1,1,1)}, function(c) espState.boxCol[1]=c end)
    addOpt(espSec, "AddSlider", "ESPBoxAlpha", {Title="Прозрачность рамки", Min=0, Max=1, Default=1, Rounding=2}, function(v) espState.boxCol[2]=tonumber(v) or 1 end)
    addOpt(espSec, "AddDropdown", "ESPBoxType", {Title="Тип рамки", Values={"Прямоугольник","Уголки"}, Default="Прямоугольник"}, function(v) espState.boxType=(v=="Уголки") and "Corners" or "Static" end)
    addOpt(espSec, "AddToggle", "ESPBoxGrd", {Title="Градиент рамки", Default=false}, function(v) espState.boxGrd=v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxGrd1", {Title="Цвет 1", Default=Color3.fromRGB(255,60,60)}, function(c) espState.boxGrd1=c end)
    addOpt(espSec, "AddColorPicker", "ESPBoxGrd2", {Title="Цвет 2", Default=Color3.fromRGB(255,180,60)}, function(c) espState.boxGrd2=c end)
    addOpt(espSec, "AddToggle", "ESPBoxFill", {Title="Заливка", Default=false}, function(v) espState.boxFill=v end)
    addOpt(espSec, "AddColorPicker", "ESPBoxFillCol", {Title="Цвет заливки", Default=Color3.fromRGB(255,60,60)}, function(c) espState.boxFillCol[1]=c end)
    addOpt(espSec, "AddSlider", "ESPBoxFillAlpha", {Title="Прозрачность заливки", Min=0, Max=1, Default=0.5, Rounding=2}, function(v) espState.boxFillCol[2]=tonumber(v) or 0.5 end)
    addOpt(espSec, "AddToggle", "ESPName", {Title="Имя", Default=false}, function(v) espState.name=v end)
    addOpt(espSec, "AddColorPicker", "ESPNameCol", {Title="Цвет имени", Default=Color3.new(1,1,1)}, function(c) espState.nameCol[1]=c end)
    addOpt(espSec, "AddToggle", "ESPDist", {Title="Дистанция", Default=false}, function(v) espState.dist=v end)
    addOpt(espSec, "AddColorPicker", "ESPDistCol", {Title="Цвет дистанции", Default=Color3.fromRGB(220,220,220)}, function(c) espState.distCol[1]=c end)
    addOpt(espSec, "AddToggle", "ESPAvatar", {Title="Аватарка", Default=false}, function(v) espState.avatar=v end)
    addOpt(espSec, "AddToggle", "ESPSkel", {Title="Скелет", Default=false}, function(v) espState.skel=v end)
    addOpt(espSec, "AddColorPicker", "ESPSkelCol", {Title="Цвет скелета", Default=Color3.new(1,1,1)}, function(c) espState.skelCol[1]=c end)
    addOpt(espSec, "AddToggle", "ESPChams", {Title="Свечение", Default=false}, function(v) espState.chams=v end)
    local function chamsPair(prefix,role,defFill,defOut)
        addOpt(espSec, "AddColorPicker", "ChamsF"..prefix, {Title=role.." заливка", Default=defFill}, function(c) espState["chamsF"..prefix][1]=c end)
        addOpt(espSec, "AddSlider", "ChamsFA"..prefix, {Title=role.." прозр", Min=0, Max=1, Default=0.55, Rounding=2}, function(v) espState["chamsF"..prefix][2]=tonumber(v) or 0.55 end)
        addOpt(espSec, "AddColorPicker", "ChamsO"..prefix, {Title=role.." обводка", Default=defOut}, function(c) espState["chamsO"..prefix][1]=c end)
        addOpt(espSec, "AddSlider", "ChamsOA"..prefix, {Title=role.." прозр обводки", Min=0, Max=1, Default=0.15, Rounding=2}, function(v) espState["chamsO"..prefix][2]=tonumber(v) or 0.15 end)
    end
    chamsPair("Mur","Убийца",Color3.fromRGB(255,60,60),Color3.fromRGB(255,120,120))
    chamsPair("Inno","Мирный",Color3.new(1,1,1),Color3.new(1,1,1))
    chamsPair("Shf","Шериф",Color3.fromRGB(0,153,255),Color3.fromRGB(120,200,255))
    chamsPair("Hero","Герой",Color3.fromRGB(255,215,0),Color3.fromRGB(255,240,140))
    addOpt(espSec, "AddToggle", "ESPMatChams", {Title="Материал-чамсы", Default=false}, function(v) espState.matChams=v end)
    addOpt(espSec, "AddDropdown", "ESPMatType", {Title="Материал", Values={"ForceField","Flat","Chromatic"}, Default="ForceField"}, function(v) espState.matType=v end)
    addOpt(espSec, "AddColorPicker", "ESPMatMur", {Title="Убийца", Default=Color3.fromRGB(255,60,60)}, function(c) espState.matColMur=c end)
    addOpt(espSec, "AddColorPicker", "ESPMatInno", {Title="Мирный", Default=Color3.new(1,1,1)}, function(c) espState.matColInno=c end)
    addOpt(espSec, "AddColorPicker", "ESPMatShf", {Title="Шериф", Default=Color3.fromRGB(0,153,255)}, function(c) espState.matColShf=c end)
    addOpt(espSec, "AddColorPicker", "ESPMatHero", {Title="Герой", Default=Color3.fromRGB(255,215,0)}, function(c) espState.matColHero=c end)
    addOpt(espSec, "AddToggle", "ESPFlags", {Title="Метки ролей", Default=false}, function(v) espState.flags=v end)
    addOpt(espSec, "AddToggle", "ESPArrows", {Title="Стрелки", Default=false}, function(v) espState.arrows=v end)
    addOpt(espSec, "AddColorPicker", "ESPArrMur", {Title="Убийца", Default=Color3.fromRGB(255,60,60)}, function(c) espState.arrowMur=c end)
    addOpt(espSec, "AddColorPicker", "ESPArrInno", {Title="Мирный", Default=Color3.new(1,1,1)}, function(c) espState.arrowInno=c end)
    addOpt(espSec, "AddColorPicker", "ESPArrShf", {Title="Шериф", Default=Color3.fromRGB(0,153,255)}, function(c) espState.arrowShf=c end)
    addOpt(espSec, "AddColorPicker", "ESPArrHero", {Title="Герой", Default=Color3.fromRGB(255,215,0)}, function(c) espState.arrowHero=c end)
    addOpt(espSec, "AddSlider", "ESPArrSz", {Title="Размер стрелок", Min=16, Max=96, Default=42, Rounding=0}, function(v) espState.arrowSize=tonumber(v) or 42 end)
    addOpt(espSec, "AddSlider", "ESPArrDist", {Title="Дистанция стрелок", Min=40, Max=520, Default=260, Rounding=0}, function(v) espState.arrowDist=tonumber(v) or 260 end)
    addOpt(espSec, "AddSlider", "ESPMaxDist", {Title="Макс дистанция ESP", Min=50, Max=1000, Default=500, Rounding=0}, function(v) espState.maxDist=tonumber(v) or 500 end)
    addOpt(espSec, "AddToggle", "ESPAllowLocal", {Title="Показывать себя", Default=false}, function(v) espState.allowLocal=v end)
    local gunSec=tV:AddSection({Name="ESP Пистолета"})
    addOpt(gunSec, "AddToggle", "GunEspOn", {Title="ESP пистолета", Default=false}, function(v)
        espState.gunEspOn=v
        if v then collectCandidates() else clearGuns() end
    end)
    addOpt(gunSec, "AddToggle", "GunTextOn", {Title="Текст", Default=false}, function(v) espState.gunTextOn=v end)
    addOpt(gunSec, "AddColorPicker", "GunTextCol", {Title="Цвет текста", Default=Color3.new(1,1,1)}, function(c) espState.gunTextCol=c end)
    addOpt(gunSec, "AddToggle", "GunHlOn", {Title="Обводка", Default=false}, function(v) espState.gunHlOn=v end)
    addOpt(gunSec, "AddColorPicker", "GunHlCol", {Title="Цвет обводки", Default=Color3.new(1,1,1)}, function(c) espState.gunHlCol=c end)
    local camSec=tV:AddSection({Name="Камера"})
    local ratioOn,ratioValue=false,100
    local aspectMul=CFrame.new(0,0,0,1,0,0,0,1,0,0,0,1)
    RunService:BindToRenderStep("FH_aspect",Enum.RenderPriority.Camera.Value+1,function()
        if not ratioOn then return end
        local cam=Workspace.CurrentCamera
        if cam then cam.CFrame=cam.CFrame*aspectMul end
    end)
    addOpt(camSec, "AddToggle", "AspectOn", {Title="Aspect ratio", Default=false}, function(v) ratioOn=v end)
    addOpt(camSec, "AddSlider", "AspectVal", {Title="Значение", Min=1, Max=100, Default=100, Rounding=0}, function(v)
        ratioValue=tonumber(v) or 100
        aspectMul=CFrame.new(0,0,0,1,0,0,0,ratioValue/100,0,0,0,1)
    end)
    local fovOn,fovValue,fovOrig=false,70,nil
    RunService.RenderStepped:Connect(function()
        if not fovOn then return end
        local cam=Workspace.CurrentCamera
        if cam and cam.FieldOfView~=fovValue then cam.FieldOfView=fovValue end
    end)
    addOpt(camSec, "AddToggle", "FovOn", {Title="Своё FOV", Default=false}, function(v)
        fovOn=v
        local cam=Workspace.CurrentCamera
        if v then if cam then fovOrig=cam.FieldOfView cam.FieldOfView=fovValue end
        else if cam and fovOrig then cam.FieldOfView=fovOrig end end
    end)
    addOpt(camSec, "AddSlider", "FovVal", {Title="FOV", Min=30, Max=120, Default=70, Rounding=0}, function(v)
        fovValue=tonumber(v) or 70
        if fovOn then
            local cam=Workspace.CurrentCamera
            if cam then cam.FieldOfView=fovValue end
        end
    end)
end

-- ============================================================
-- СВОИ ВИЗУАЛЫ (без модели оружия)
-- ============================================================
do
    local lvSec=Tabs.Visual:AddSection({Name="Свои визуалы"})
    -- China Hat
    local chGui=Instance.new("ScreenGui")
    chGui.Name="FH_ChinaHat_v22"
    chGui.ResetOnSpawn=false
    chGui.IgnoreGuiInset=true
    chGui.DisplayOrder=999
    chGui.Parent=_uiRoot()
    local holder=Instance.new("Frame")
    holder.Size=UDim2.fromScale(1,1)
    holder.BackgroundTransparency=1
    holder.BorderSizePixel=0
    holder.Parent=chGui
    local chRows={}
    local chOn,chCol=false,Color3.fromRGB(170,85,255)
    local SEG,RAD,HEIGHT,DROP,ALPHA=36,1.6,0.9,0.02,0.28
    local MAX_ROWS=120
    local function chEnsure(n)
        for i=#chRows+1,n do
            local f=Instance.new("Frame")
            f.BorderSizePixel=0
            f.BackgroundTransparency=ALPHA
            f.Visible=false
            f.ZIndex=5
            f.Parent=holder
            chRows[i]=f
        end
    end
    local function chHideAll()
        for _,f in ipairs(chRows) do if f.Visible then f.Visible=false end end
    end
    local function proj(p)
        local sp,on=Camera:WorldToViewportPoint(p)
        if sp.Z<=0 then return nil,false end
        return Vector2.new(sp.X,sp.Y),true
    end
    local function cross(o,a,b) return (a.X-o.X)*(b.Y-o.Y)-(a.Y-o.Y)*(b.X-o.X) end
    local function hull(pts)
        table.sort(pts,function(a,b) if a.X==b.X then return a.Y<b.Y end return a.X<b.X end)
        local lo={}
        for _,p in ipairs(pts) do
            while #lo>=2 and cross(lo[#lo-1],lo[#lo],p)<=0 do table.remove(lo) end
            lo[#lo+1]=p
        end
        local up={}
        for i=#pts,1,-1 do
            local p=pts[i]
            while #up>=2 and cross(up[#up-1],up[#up],p)<=0 do table.remove(up) end
            up[#up+1]=p
        end
        table.remove(lo);table.remove(up)
        local out={}
        for _,p in ipairs(lo) do out[#out+1]=p end
        for _,p in ipairs(up) do out[#out+1]=p end
        return out
    end
    RunService.RenderStepped:Connect(function()
        if not chOn then chHideAll() return end
        local char=LocalPlayer.Character
        local head=char and char:FindFirstChild("Head")
        if not head then chHideAll() return end
        local cam=Workspace.CurrentCamera
        if not cam then chHideAll() return end
        local base=Vector3.new(head.Position.X,head.Position.Y+head.Size.Y*0.5-DROP,head.Position.Z)
        local apex2d,ok=proj(base+Vector3.new(0,HEIGHT,0))
        if not ok then chHideAll() return end
        local pts={apex2d}
        for i=1,SEG do
            local a=(i-1)/SEG*math.pi*2
            local p,ok2=proj(base+Vector3.new(math.cos(a)*RAD,0,math.sin(a)*RAD))
            if not ok2 then chHideAll() return end
            pts[#pts+1]=p
        end
        local h=hull(pts)
        if #h<3 then chHideAll() return end
        local minY,maxY=math.huge,-math.huge
        for _,p in ipairs(h) do
            if p.Y<minY then minY=p.Y end
            if p.Y>maxY then maxY=p.Y end
        end
        minY=math.max(0,math.floor(minY))
        maxY=math.min(cam.ViewportSize.Y,math.ceil(maxY))
        if maxY-minY<2 then chHideAll() return end
        local span=math.max(1,maxY-minY)
        local step=math.max(1,math.ceil((maxY-minY)/MAX_ROWS))
        chEnsure(MAX_ROWS)
        local used=0
        for y0=minY,maxY-1,step do
            local hh=math.min(step,maxY-y0)
            local y=y0+hh*0.5
            local left,right=math.huge,-math.huge
            local ax,ay=h[#h].X,h[#h].Y
            for i=1,#h do
                local bx,by=h[i].X,h[i].Y
                if (ay<=y and by>y) or (by<=y and ay>y) then
                    local x=ax+(y-ay)*(bx-ax)/(by-ay)
                    if x<left then left=x end
                    if x>right then right=x end
                end
                ax,ay=bx,by
            end
            local w=right-left
            if w>=2 then
                used=used+1
                local t=(y-minY)/span
                local light=math.max(0,1-t*1.35)
                local dark=math.max(0,(t-0.58)/0.42)
                local col=chCol:Lerp(Color3.new(1,1,1),light*0.26):Lerp(Color3.new(0,0,0),dark*0.12)
                local f=chRows[used]
                f.Position=UDim2.fromOffset(left,y0)
                f.Size=UDim2.fromOffset(w,hh)
                f.BackgroundColor3=col
                f.Visible=true
            end
        end
        for i=used+1,#chRows do
            if chRows[i].Visible then chRows[i].Visible=false end
        end
    end)
    addOpt(lvSec, "AddToggle", "ChinaHatOn", {Title="Китайская шляпа", Default=false}, function(v) chOn=v end)
    addOpt(lvSec, "AddColorPicker", "ChinaHatCol", {Title="Цвет", Default=Color3.fromRGB(170,85,255)}, function(c) chCol=c end)

    -- ============================================================
    -- BACKTRACK (v1 + v2 Client Ghost, единый раздел)
    -- ============================================================
    local btMode = "Simple"
    local btSimpleOn = false
    local btGhostOn = false

    -- Simple Backtrack (клон модели)
    local btCol=Color3.fromRGB(255,60,60)
    local btModel=nil
    local btPairs={}
    local BTCAP=256
    local btHist=table.create(BTCAP)
    for i=1,BTCAP do btHist[i]={0,CFrame.identity} end
    local btFirst,btCount=1,0
    local btPing,btPingAt=0.15,0
    local function btKill()
        if btModel then pcall(function() btModel:Destroy() end) btModel=nil end
        btPairs={}
        btFirst,btCount=1,0
    end
    local function btBuild()
        btKill()
        local char=LocalPlayer.Character
        if not char then return end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        char.Archivable=true
        local ok,m=pcall(function() return char:Clone() end)
        char.Archivable=false
        if not ok or not m then return end
        local rp={}
        for _,o in ipairs(char:GetDescendants()) do
            if o:IsA("BasePart") then rp[#rp+1]=o end
        end
        local ci=0
        for _,o in ipairs(m:GetDescendants()) do
            if o:IsA("Script") or o:IsA("LocalScript") then pcall(function() o:Destroy() end)
            elseif o:IsA("Decal") or o:IsA("Texture") or o:IsA("SurfaceAppearance") then pcall(function() o:Destroy() end)
            elseif o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("PointLight") then pcall(function() o:Destroy() end)
            elseif o:IsA("BasePart") then
                o.Anchored=true o.CanCollide=false o.CanQuery=false o.CastShadow=false
                if o.Name=="HumanoidRootPart" then o.Transparency=1
                else o.Material=Enum.Material.ForceField o.Color=btCol o.Transparency=0 end
                ci=ci+1
                btPairs[#btPairs+1]={o,rp[ci]}
            end
        end
        local h=m:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:Destroy() end) end
        m.Parent=Workspace
        btModel=m
    end
    local function btUpdate()
        local char=LocalPlayer.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        if not btModel then btBuild() if not btModel then return end end
        if not btModel.Parent then btModel.Parent=Workspace end
        local now=os.clock()
        local cf=hrp.CFrame
        if btCount<BTCAP then btCount=btCount+1
        else btFirst=btFirst%BTCAP+1 end
        local slot=btHist[(btFirst+btCount-2)%BTCAP+1]
        slot[1],slot[2]=now,cf
        if now-btPingAt>=0.2 then
            btPingAt=now
            local ok,v=pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
            btPing=math.clamp((ok and v) or 0.15,0.05,0.6)
        end
        local target=now-btPing
        local tcf=cf
        for k=btCount,1,-1 do
            local s=btHist[(btFirst+k-2)%BTCAP+1]
            if s[1]<=target then tcf=s[2] break end
        end
        local inv=hrp.CFrame:Inverse()
        for i=1,#btPairs do
            local cp,rp=btPairs[i][1],btPairs[i][2]
            if cp and cp.Parent and rp and rp.Parent then
                cp.CFrame=tcf*(inv*rp.CFrame)
            end
        end
    end

    -- Ghost (v2)
    local ghFolder = Workspace:FindFirstChild("FH_ClientVisuals")
    if not ghFolder then
        ghFolder = Instance.new("Folder")
        ghFolder.Name = "FH_ClientVisuals"
        ghFolder.Parent = Workspace
    end
    local ghModel,ghPairs,ghHistory,ghLastChar = nil,{},{},nil
    local ghCfg = {Transparency=50, Color=Color3.fromRGB(255,100,100), DeleteTexture=false, Backtrack=true, BacktrackTime=0.15}
    local function ghCleanup()
        if ghModel then pcall(function() ghModel:Destroy() end) end
        ghModel=nil ghPairs={} ghHistory={} ghLastChar=nil
    end
    local function ghPaint()
        if not ghModel then return end
        local tr = ghCfg.Transparency / 100
        pcall(function()
            local bc = ghModel:FindFirstChildOfClass("BodyColors")
            if bc then bc:Destroy() end
        end)
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
                d.Anchored=true d.CanCollide=false d.CanQuery=false d.CanTouch=false d.Massless=true
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
        for _, pair in ipairs(ghPairs) do snap.parts[pair.real] = pair.real.CFrame end
        table.insert(ghHistory, snap)
        local cutoff = tick() - 2
        while #ghHistory > 0 and ghHistory[1].t < cutoff do table.remove(ghHistory, 1) end
        local wantTime = tick() - math.clamp(ghCfg.BacktrackTime, 0, 1)
        local chosen = nil
        for i = #ghHistory, 1, -1 do
            if ghHistory[i].t <= wantTime then chosen = ghHistory[i]; break end
        end
        if not chosen and #ghHistory > 0 then chosen = ghHistory[1] end
        if chosen then
            for _, pair in ipairs(ghPairs) do
                if chosen.parts[pair.real] then pair.ghost.CFrame = chosen.parts[pair.real] end
            end
        end
    end)

    addOpt(lvSec, "AddDropdown", "BacktrackMode", {Title="Режим бэктрека", Values={"Simple","Ghost"}, Default="Simple"}, function(v)
        btMode = v or "Simple"
        btSimpleOn = false
        btGhostOn = false
        btKill()
        ghCleanup()
        local o1 = Options.BacktrackOn
        local o2 = Options.GhostOn
        if o1 then o1:SetValue(false) end
        if o2 then o2:SetValue(false) end
    end)
    addOpt(lvSec, "AddToggle", "BacktrackOn", {Title="Backtrack (Simple)", Default=false}, function(v)
        if btMode ~= "Simple" then
            Notify("FH","Переключи режим на Simple",2)
            local o = Options.BacktrackOn
            if o then o:SetValue(false) end
            return
        end
        btSimpleOn = v
        if v then
            if not _G.FH_BT_CONN then
                _G.FH_BT_CONN=RunService.Heartbeat:Connect(function() if btSimpleOn then btUpdate() end end)
            end
            if not btModel then btBuild() end
        else btKill() end
    end)
    addOpt(lvSec, "AddToggle", "GhostOn", {Title="Ghost (задержка)", Default=false}, function(v)
        if btMode ~= "Ghost" then
            Notify("FH","Переключи режим на Ghost",2)
            local o = Options.GhostOn
            if o then o:SetValue(false) end
            return
        end
        btGhostOn = v
        if not v then ghCleanup() end
    end)
    addOpt(lvSec, "AddColorPicker", "BacktrackCol", {Title="Цвет (Simple/Ghost)", Default=Color3.fromRGB(255,60,60)}, function(c)
        btCol=c
        ghCfg.Color=c
        if btModel then
            for _,p in ipairs(btModel:GetDescendants()) do
                if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then p.Color=c end
            end
        end
        ghPaint()
    end)
    addOpt(lvSec, "AddSlider", "GhostTransparency", {Title="Ghost прозрачность (%)", Min=0, Max=100, Default=50, Rounding=0}, function(v)
        ghCfg.Transparency=tonumber(v) or 50
        ghPaint()
    end)
    addOpt(lvSec, "AddToggle", "GhostNoTexture", {Title="Ghost убрать текстуры", Default=false}, function(v)
        ghCfg.DeleteTexture=v
        ghPaint()
    end)
    addOpt(lvSec, "AddSlider", "GhostBacktrackTime", {Title="Ghost задержка (сек)", Min=0, Max=0.8, Default=0.15, Rounding=2}, function(v)
        ghCfg.BacktrackTime=tonumber(v) or 0.15
    end)

    -- Land Circle
    local lcOn,lcCol,lcTr,lcDur=false,Color3.new(1,1,1),1,0.82
    local lcConn
    local function lcHit(char,root)
        local prm=RaycastParams.new()
        prm.FilterType=Enum.RaycastFilterType.Exclude
        prm.FilterDescendantsInstances={char}
        prm.IgnoreWater=true
        local hit=Workspace:Raycast(root.Position+Vector3.new(0,1,0),Vector3.new(0,-16,0),prm)
        if hit then return hit.Position,hit.Normal end
    end
    local function lcMake(p,n)
        local ref=math.abs(n.Y)>0.98 and Vector3.xAxis or Vector3.yAxis
        local right=n:Cross(ref).Unit
        local front=right:Cross(n).Unit
        local pt=Instance.new("Part")
        pt.Anchored=true pt.CanCollide=false pt.CanQuery=false pt.CanTouch=false pt.CastShadow=false
        pt.Transparency=1 pt.Size=Vector3.new(0.3,0.01,0.3)
        pt.CFrame=CFrame.fromMatrix(p+n*0.012,right,n,front)
        pt.Parent=Workspace
        local sg=Instance.new("SurfaceGui")
        sg.Face=Enum.NormalId.Top sg.AlwaysOnTop=true sg.LightInfluence=0 sg.ZOffset=4
        sg.CanvasSize=Vector2.new(1024,1024)
        sg.Parent=pt
        local img=Instance.new("ImageLabel")
        img.BackgroundTransparency=1 img.Size=UDim2.fromScale(1,1)
        img.Image="rbxassetid://7185003058"
        img.ImageColor3=lcCol img.ImageTransparency=1-lcTr
        img.ScaleType=Enum.ScaleType.Stretch
        img.Parent=sg
        local info=TweenInfo.new(lcDur,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
        TweenService:Create(pt,info,{Size=Vector3.new(6.4,0.01,6.4)}):Play()
        TweenService:Create(img,info,{ImageTransparency=1}):Play()
        Debris:AddItem(pt,lcDur+0.2)
    end
    local function lcBind()
        if lcConn then pcall(function() lcConn:Disconnect() end) lcConn=nil end
        if not lcOn then return end
        local char=LocalPlayer.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end
        local air=false
        lcConn=hum.StateChanged:Connect(function(_,state)
            if state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall then air=true
            elseif state==Enum.HumanoidStateType.Landed and air and lcOn then
                air=false
                local p,n=lcHit(char,root)
                if p and n then lcMake(p,n) end
            end
        end)
    end
    addOpt(lvSec, "AddToggle", "LandCircleOn", {Title="Круг падения", Default=false}, function(v)
        lcOn=v
        if v then lcBind()
        elseif lcConn then pcall(function() lcConn:Disconnect() end) lcConn=nil end
    end)
    addOpt(lvSec, "AddColorPicker", "LandCircleCol", {Title="Цвет", Default=Color3.new(1,1,1)}, function(c) lcCol=c end)
    addOpt(lvSec, "AddSlider", "LandCircleTr", {Title="Прозрачность", Min=0, Max=1, Default=1, Rounding=2}, function(v) lcTr=tonumber(v) or 1 end)
    addOpt(lvSec, "AddSlider", "LandCircleDur", {Title="Длительность", Min=0.1, Max=3, Default=0.82, Rounding=2}, function(v) lcDur=tonumber(v) or 0.82 end)

    -- ============================================================
    -- MOV GRAPH (с фиксом — принудительное создание Drawing через defer)
    -- ============================================================
    local mgOn,mgCol=false,Color3.fromRGB(242,242,242)
    local mgWidth,mgHeight,mgOffset=280,72,180
    local mgLines,mgShadows={},{}
    local mgCurrent=nil
    local mgHist={}
    local mgAccum=0
    local mgSmooth=0
    local mgSpan,mgStep=2.8,1/45
    local mgConn=nil
    local function mgSpeed()
        local c=LocalPlayer.Character
        local r=c and c:FindFirstChild("HumanoidRootPart")
        if not r then return 0 end
        local v=r.AssemblyLinearVelocity
        return Vector3.new(v.X,0,v.Z).Magnitude
    end
    local function mgRef()
        local c=LocalPlayer.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        return math.max(1,(h and h.WalkSpeed) or 16)
    end
    local function mgClear()
        if mgConn then pcall(function() mgConn:Disconnect() end) mgConn=nil end
        if mgCurrent then pcall(function() mgCurrent:Remove() end) mgCurrent=nil end
        for i=1,#mgLines do
            pcall(function() mgLines[i]:Remove() end)
            pcall(function() mgShadows[i]:Remove() end)
        end
        mgLines={} mgShadows={} mgHist={} mgAccum=0
    end
    local function mgStart()
        mgClear()
        mgSmooth=mgSpeed()
        local now=os.clock()
        local cnt=math.ceil(mgSpan/mgStep)
        for i=0,cnt do mgHist[#mgHist+1]={t=now-mgSpan+i*mgStep,v=mgSmooth} end
        for i=1,300 do
            local s=Drawing.new("Line")
            s.Color=Color3.new(0,0,0) s.Thickness=3 s.Transparency=0.4 s.Visible=false
            mgShadows[#mgShadows+1]=s
            local l=Drawing.new("Line")
            l.Color=mgCol l.Thickness=1.5 l.Transparency=1 l.Visible=false
            mgLines[#mgLines+1]=l
        end
        mgConn=RunService.RenderStepped:Connect(function(dt)
            if not mgOn then
                for i=1,#mgLines do mgLines[i].Visible=false mgShadows[i].Visible=false end
                if mgCurrent then mgCurrent.Visible=false end
                return
            end
            local raw=mgSpeed()
            mgSmooth=mgSmooth+(raw-mgSmooth)*(1-math.exp(-dt*18))
            mgAccum=mgAccum+dt
            local now=os.clock()
            if mgAccum>=mgStep then
                mgAccum=mgAccum%mgStep
                mgHist[#mgHist+1]={t=now,v=mgSmooth}
                local cutoff=now-mgSpan
                while #mgHist>2 and mgHist[2].t<cutoff do table.remove(mgHist,1) end
            end
            local vp=Camera.ViewportSize
            local w=math.min(mgWidth,math.max(120,vp.X-48))
            local h=math.min(mgHeight,math.max(36,vp.Y-32))
            local left=math.floor(vp.X*0.5-w*0.5)
            local center=math.clamp(math.floor(vp.Y*0.5+mgOffset),h*0.5+8,vp.Y-h*0.5-8)
            local ref=mgRef()
            local startT=now-mgSpan
            local count=#mgHist
            for i=1,count-1 do
                local a,b=mgHist[i],mgHist[i+1]
                local ap=math.clamp((a.t-startT)/mgSpan,0,1)
                local bp=math.clamp((b.t-startT)/mgSpan,0,1)
                local fade=math.clamp(math.min((ap+bp)*6,(2-ap-bp)*5),0,1)
                local ay=center-(math.clamp(a.v/ref-1,-1,1))*h*0.44
                local by=center-(math.clamp(b.v/ref-1,-1,1))*h*0.44
                local from=Vector2.new(left+ap*w,ay)
                local to=Vector2.new(left+bp*w,by)
                if mgLines[i] then
                    mgLines[i].From=from
                    mgLines[i].To=to
                    mgLines[i].Transparency=fade
                    mgLines[i].Visible=fade>0.02
                    mgLines[i].Color=mgCol
                    mgShadows[i].From=from
                    mgShadows[i].To=to
                    mgShadows[i].Transparency=fade*0.42
                    mgShadows[i].Visible=fade>0.02
                end
            end
            for i=count,#mgLines do
                mgLines[i].Visible=false mgShadows[i].Visible=false
            end
            if not mgCurrent then
                mgCurrent=Drawing.new("Text")
                mgCurrent.Center=false mgCurrent.Outline=true mgCurrent.Size=12
            end
            mgCurrent.Text=tostring(math.floor(mgSmooth+0.5))
            mgCurrent.Position=Vector2.new(left+w+5,center-7)
            mgCurrent.Color=mgCol
            mgCurrent.Visible=true
        end)
    end
    addOpt(lvSec, "AddToggle", "MovGraphOn", {Title="График скорости", Default=false}, function(v)
        mgOn=v
        if v then mgStart() else mgClear() end
    end)
    addOpt(lvSec, "AddColorPicker", "MovGraphCol", {Title="Цвет", Default=Color3.fromRGB(242,242,242)}, function(c)
        mgCol=c
        for i=1,#mgLines do mgLines[i].Color=c end
    end)
    addOpt(lvSec, "AddSlider", "MovGraphW", {Title="Ширина", Min=180, Max=420, Default=280, Rounding=0}, function(v) mgWidth=tonumber(v) or 280 end)
    addOpt(lvSec, "AddSlider", "MovGraphH", {Title="Высота", Min=40, Max=120, Default=72, Rounding=0}, function(v) mgHeight=tonumber(v) or 72 end)
    addOpt(lvSec, "AddSlider", "MovGraphY", {Title="Смещение Y", Min=-200, Max=400, Default=180, Rounding=0}, function(v) mgOffset=tonumber(v) or 180 end)

    -- Crosshair
    local chOn2,chCol2=false,Color3.new(1,1,1)
    local chLines={}
    for i=1,4 do
        local l=Drawing.new("Line")
        l.Thickness=2 l.Color=chCol2 l.Visible=false
        chLines[i]=l
    end
    RunService.RenderStepped:Connect(function()
        if not chOn2 then
            for i=1,#chLines do chLines[i].Visible=false end
            return
        end
        local mp=UserInputService:GetMouseLocation()
        local gap,len=4,8
        local cx,cy=mp.X,mp.Y
        local arr={
            {cx,cy-gap,cx,cy-gap-len},
            {cx,cy+gap,cx,cy+gap+len},
            {cx-gap,cy,cx-gap-len,cy},
            {cx+gap,cy,cx+gap+len,cy},
        }
        for i=1,4 do
            local a=arr[i]
            chLines[i].From=Vector2.new(a[1],a[2])
            chLines[i].To=Vector2.new(a[3],a[4])
            chLines[i].Color=chCol2
            chLines[i].Visible=true
        end
    end)
    addOpt(lvSec, "AddToggle", "CrosshairOn", {Title="Прицел", Default=false}, function(v)
        chOn2=v
        pcall(function() UserInputService.MouseIconEnabled=not v end)
    end)
    addOpt(lvSec, "AddColorPicker", "CrosshairCol", {Title="Цвет", Default=Color3.new(1,1,1)}, function(c) chCol2=c end)

    -- Self Chams
    local scOn,scType,scCol=false,"ForceField",Color3.fromRGB(0,200,255)
    local scCache={}
    local scConn=nil
    local function scRestore()
        if scConn then pcall(function() scConn:Disconnect() end) scConn=nil end
        for part,d in pairs(scCache) do
            if part and part.Parent then
                pcall(function() part.Material=d[1] end)
                pcall(function() part.Color=d[2] end)
            end
        end
        scCache={}
    end
    local function scApply()
        local c=LocalPlayer.Character
        if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then
                if not scCache[p] then scCache[p]={p.Material,p.Color} end
                if scType=="ForceField" then
                    pcall(function() p.Material=Enum.Material.ForceField end)
                    pcall(function() p.Color=scCol end)
                elseif scType=="Flat" then
                    pcall(function() p.Material=Enum.Material.SmoothPlastic end)
                    pcall(function() p.Color=scCol end)
                elseif scType=="Chromatic" then
                    pcall(function() p.Material=Enum.Material.Foil end)
                    pcall(function() p.Color=scCol end)
                end
            end
        end
    end
    addOpt(lvSec, "AddToggle", "SelfChamsOn", {Title="Чамсы на себе", Default=false}, function(v)
        scOn=v
        if v then
            if not scConn then scConn=RunService.Heartbeat:Connect(function() if scOn then scApply() end end) end
        else scRestore() end
    end)
    addOpt(lvSec, "AddDropdown", "SelfChamsType", {Title="Пресет", Values={"ForceField","Flat","Chromatic"}, Default="ForceField"}, function(v) scType=v end)
    addOpt(lvSec, "AddColorPicker", "SelfChamsCol", {Title="Цвет", Default=Color3.fromRGB(0,200,255)}, function(c) scCol=c end)

    -- Tool Chams
    local tcOn,tcType,tcCol=false,"ForceField",Color3.fromRGB(255,200,0)
    local tcCache={}
    local tcConn=nil
    local function tcRestore()
        if tcConn then pcall(function() tcConn:Disconnect() end) tcConn=nil end
        for part,d in pairs(tcCache) do
            if part and part.Parent then
                pcall(function() part.Material=d[1] end)
                pcall(function() part.Color=d[2] end)
            end
        end
        tcCache={}
    end
    local function tcApply()
        local c=LocalPlayer.Character
        if not c then return end
        for _,t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") then
                for _,p in ipairs(t:GetDescendants()) do
                    if p:IsA("BasePart") then
                        if not tcCache[p] then tcCache[p]={p.Material,p.Color} end
                        if tcType=="ForceField" then
                            pcall(function() p.Material=Enum.Material.ForceField end)
                            pcall(function() p.Color=tcCol end)
                        elseif tcType=="Flat" then
                            pcall(function() p.Material=Enum.Material.SmoothPlastic end)
                            pcall(function() p.Color=tcCol end)
                        elseif tcType=="Chromatic" then
                            pcall(function() p.Material=Enum.Material.Foil end)
                            pcall(function() p.Color=tcCol end)
                        end
                    end
                end
            end
        end
    end
    addOpt(lvSec, "AddToggle", "ToolChamsOn", {Title="Чамсы оружия", Default=false}, function(v)
        tcOn=v
        if v then
            if not tcConn then tcConn=RunService.Heartbeat:Connect(function() if tcOn then tcApply() end end) end
        else tcRestore() end
    end)
    addOpt(lvSec, "AddDropdown", "ToolChamsType", {Title="Пресет", Values={"ForceField","Flat","Chromatic"}, Default="ForceField"}, function(v) tcType=v end)
    addOpt(lvSec, "AddColorPicker", "ToolChamsCol", {Title="Цвет", Default=Color3.fromRGB(255,200,0)}, function(c) tcCol=c end)
end

-- ============================================================
-- ЭФФЕКТЫ
-- ============================================================
do
    local tE=Tabs.Effects
    -- Tracer
    local tracerSec=tE:AddSection({Name="Трассер пули"})
    local tracerOn,tracerCol,tracerDur=false,Color3.fromRGB(133,220,255),1
    local tracerTrackBullet=true
    local function makePoint(pos,life)
        local pt=Instance.new("Part")
        pt.Transparency=1 pt.Anchored=true pt.CanCollide=false pt.CanQuery=false
        pt.Size=Vector3.new(1,1,1) pt.CFrame=CFrame.new(pos)
        Instance.new("Attachment",pt)
        pt.Parent=Workspace
        Debris:AddItem(pt,life)
        return pt
    end
    local function toPos(v)
        if typeof(v)=="Vector3" then return v end
        if typeof(v)=="CFrame" then return v.Position end
        if typeof(v)=="Instance" then
            if v:IsA("Attachment") then return v.WorldPosition end
            if v:IsA("BasePart") then return v.Position end
        end
    end
    local function createTracer(sv,ev)
        local sp,ep=toPos(sv),toPos(ev)
        if not sp or not ep then return end
        local p1=makePoint(sp,tracerDur+0.5)
        local p2=makePoint(ep,tracerDur+0.5)
        local beam=Instance.new("Beam")
        beam.FaceCamera=true beam.TextureSpeed=1.5 beam.TextureLength=2
        beam.Width0=0.25 beam.Width1=0.25
        beam.LightEmission=3 beam.LightInfluence=0 beam.Brightness=2.5
        beam.Texture="rbxassetid://12781800668"
        beam.Color=ColorSequence.new(tracerCol)
        beam.Transparency=NumberSequence.new(0.1)
        beam.Attachment0=p1:FindFirstChildOfClass("Attachment")
        beam.Attachment1=p2:FindFirstChildOfClass("Attachment")
        beam.Parent=p1
        task.delay(tracerDur,function()
            if beam.Parent then TweenService:Create(beam,TweenInfo.new(0.2),{Width0=0,Width1=0}):Play() end
        end)
    end
    local tracerConn
    local function connectTracer()
        if tracerConn then return end
        local ok,remote=pcall(function() return ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService"):WaitForChild("GunFired") end)
        if not ok or not remote then return end
        tracerConn=remote.OnClientEvent:Connect(function(gun,sv,ev)
            if not tracerOn then return end
            local c=LocalPlayer.Character
            if not c then return end
            if not (typeof(gun)=="Instance" and gun:IsDescendantOf(c)) then return end
            createTracer(sv,ev)
        end)
    end
    addOpt(tracerSec, "AddToggle", "TracerOn", {Title="Включить трассер", Default=false}, function(v)
        tracerOn=v
        if v then connectTracer() end
    end)
    addOpt(tracerSec, "AddColorPicker", "TracerCol", {Title="Цвет", Default=Color3.fromRGB(133,220,255)}, function(c) tracerCol=c end)
    addOpt(tracerSec, "AddSlider", "TracerDur", {Title="Длительность", Min=0.1, Max=5, Default=1, Rounding=1}, function(v) tracerDur=tonumber(v) or 1 end)

    -- Aura 2.0 (единый дропдаун)
    local auraSec=tE:AddSection({Name="Aura 2.0"})
    local auraActive = nil
    local auraName = nil
    local auraPending = nil
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
    for k in pairs(AURA_PRESETS) do AURA_NAMES[#AURA_NAMES+1]=k end
    table.sort(AURA_NAMES)
    local function clearAura()
        if auraActive then
            for _,obj in ipairs(auraActive) do
                if obj and obj.Parent then pcall(function() obj:Destroy() end) end
            end
        end
        auraActive=nil auraName=nil
    end
    local function applyAura(assetId, name)
        clearAura()
        local ok,objs=pcall(function() return game:GetObjects("rbxassetid://"..tostring(assetId)) end)
        if not ok or type(objs)~="table" or #objs==0 then Notify("FH","Не удалось загрузить ауру",3) return end
        local model=objs[1]
        for _,d in ipairs(model:GetDescendants()) do
            if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then d:Destroy()
            elseif d:IsA("ParticleEmitter") then
                d.LightEmission=1
                d.Rate=math.clamp(d.Rate*0.35,1,40)
                pcall(function()
                    local kps={}
                    for _,k in ipairs(d.Transparency.Keypoints) do
                        local v=math.clamp(k.Value+(1-k.Value)*0.45,0.3,1)
                        table.insert(kps,NumberSequenceKeypoint.new(k.Time,v,k.Envelope))
                    end
                    d.Transparency=NumberSequence.new(kps)
                end)
            elseif d:IsA("Beam") then
                d.LightEmission=1
            elseif d:IsA("BasePart") then
                if d.Material==Enum.Material.Neon then d.Transparency=math.max(d.Transparency,0.5) end
            end
        end
        local char=LocalPlayer.Character
        if not char then Notify("FH","Персонаж не загружен",2) return end
        local torso=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        local head=char:FindFirstChild("Head")
        if not torso or not head then Notify("FH","Части не найдены",2) return end
        local nameMap={Torso=torso.Name,Head="Head",["Left Arm"]="LeftUpperArm",["Right Arm"]="RightUpperArm",["Left Leg"]="LeftUpperLeg",["Right Leg"]="RightUpperLeg"}
        local tracked={}
        local mult=(name=="Red Shield") and 4 or 1
        for _,part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored=false part.CanCollide=false
            elseif part:IsA("Weld") or part:IsA("WeldConstraint") or part:IsA("Motor6D") or part:IsA("Snap") then part:Destroy() end
        end
        local auraPart=model:FindFirstChild("Aura")
        if auraPart and auraPart:IsA("BasePart") then
            auraPart.Parent=char
            auraPart.CFrame=torso.CFrame*CFrame.new(0,0.5,0)
            local w=Instance.new("WeldConstraint")
            w.Part0=torso w.Part1=auraPart w.Parent=auraPart
            table.insert(tracked,w) table.insert(tracked,auraPart)
            for _,ch in ipairs(auraPart:GetChildren()) do
                if ch:IsA("ParticleEmitter") or ch:IsA("Beam") or ch:IsA("Highlight") then
                    local cl=ch:Clone()
                    if cl:IsA("ParticleEmitter") then
                        local lt=cl.Lifetime
                        cl.Lifetime=NumberRange.new(lt.Min*mult,lt.Max*mult)
                    end
                    cl.Parent=torso
                    table.insert(tracked,cl)
                end
            end
        end
        for _,part in ipairs(model:GetChildren()) do
            if part:IsA("BasePart") and part.Name~="Aura" then
                local target=char:FindFirstChild(nameMap[part.Name] or part.Name)
                if target then
                    for _,ch in ipairs(part:GetChildren()) do
                        if ch:IsA("ParticleEmitter") or ch:IsA("Attachment") or ch:IsA("Highlight") then
                            local cl=ch:Clone()
                            if cl:IsA("ParticleEmitter") then
                                local lt=cl.Lifetime
                                cl.Lifetime=NumberRange.new(lt.Min*mult,lt.Max*mult)
                            end
                            cl.Parent=target
                            table.insert(tracked,cl)
                        end
                    end
                end
            end
        end
        local crown=model:FindFirstChild("Crown Base")
        if crown and name=="Crimson King" then
            crown.Parent=char
            crown.CFrame=head.CFrame*CFrame.new(0,1.5,0)
            local w=Instance.new("WeldConstraint")
            w.Part0=head w.Part1=crown w.Parent=crown
            table.insert(tracked,w) table.insert(tracked,crown)
        end
        for _,d in ipairs(model:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Beam") or d:IsA("Attachment") then
                local cl=d:Clone()
                if cl:IsA("Beam") then
                    if cl.Attachment0 and torso:FindFirstChild(cl.Attachment0.Name) then cl.Attachment0=torso[cl.Attachment0.Name] end
                    if cl.Attachment1 and torso:FindFirstChild(cl.Attachment1.Name) then cl.Attachment1=torso[cl.Attachment1.Name] end
                end
                if cl:IsA("ParticleEmitter") then
                    local lt=cl.Lifetime
                    cl.Lifetime=NumberRange.new(lt.Min*mult,lt.Max*mult)
                    if name=="Red Shield" then cl.LockedToPart=true end
                end
                cl.Parent=torso
                table.insert(tracked,cl)
            end
        end
        model:Destroy()
        auraActive=tracked
        auraName=name
        auraPending={assetId=assetId,name=name}
    end
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if auraPending and not auraActive then
            task.wait(0.3)
            applyAura(auraPending.assetId, auraPending.name)
        end
    end)
    addOpt(auraSec, "AddToggle", "Aura2On", {Title="Включить Aura 2.0", Default=false}, function(v)
        if v then
            local name = Options.Aura2Pick and Options.Aura2Pick.Value
            if type(name)=="table" then name=name[1] end
            local id = AURA_PRESETS[name]
            if id then applyAura(id, name) end
        else
            clearAura()
            auraPending=nil
        end
    end)
    addOpt(auraSec, "AddDropdown", "Aura2Pick", {Title="Выбрать ауру", Values=AURA_NAMES, Default=AURA_NAMES[1] or "Angel Wings"}, function(v)
        if Options.Aura2On and Options.Aura2On.Value then
            local id = AURA_PRESETS[v]
            if id then applyAura(id, v) end
        end
    end)

    -- FX Snow/Sakura
    local fxSec=tE:AddSection({Name="Эффекты мира"})
    local fxOn,fxType,fxCol,fxRate=false,"Snow",Color3.fromRGB(150,200,255),250
    local fxPart,fxEmit,fxConn=nil,nil,nil
    local function styleFX()
        local e=fxEmit
        if not e then return end
        e.Texture="rbxasset://textures/particles/smoke_main.dds"
        e.LightInfluence=0 e.LightEmission=0.4
        e.EmissionDirection=Enum.NormalId.Bottom
        e.Rate=fxRate e.Color=ColorSequence.new(fxCol)
        if fxType=="Snow" then
            e.Lifetime=NumberRange.new(4,6) e.Speed=NumberRange.new(6,12)
            e.Acceleration=Vector3.new(2,-6,1) e.SpreadAngle=Vector2.new(35,35)
            e.Rotation=NumberRange.new(0,360) e.RotSpeed=NumberRange.new(-40,40)
            e.Size=NumberSequence.new(0.55)
            e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(0.8,0.3),NumberSequenceKeypoint.new(1,1)})
        else
            e.Lifetime=NumberRange.new(5,7) e.Speed=NumberRange.new(5,10)
            e.Acceleration=Vector3.new(4,-5,2) e.SpreadAngle=Vector2.new(40,40)
            e.Rotation=NumberRange.new(0,360) e.RotSpeed=NumberRange.new(-80,80)
            e.Size=NumberSequence.new(0.5)
            e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(0.85,0.25),NumberSequenceKeypoint.new(1,1)})
        end
    end
    local function stopFX()
        if fxConn then pcall(function() fxConn:Disconnect() end) fxConn=nil end
        if fxPart then pcall(function() fxPart:Destroy() end) fxPart=nil end
        fxEmit=nil
    end
    local function startFX()
        stopFX()
        fxPart=Instance.new("Part")
        fxPart.Name="FH_WORLD_FX"
        fxPart.Anchored=true fxPart.CanCollide=false fxPart.CanQuery=false fxPart.CanTouch=false
        fxPart.Transparency=1 fxPart.Size=Vector3.new(260,140,260)
        fxPart.Parent=Workspace
        fxEmit=Instance.new("ParticleEmitter")
        pcall(function() fxEmit.Shape=Enum.ParticleEmitterShape.Box fxEmit.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume end)
        fxEmit.Parent=fxPart
        styleFX()
        fxConn=RunService.RenderStepped:Connect(function()
            local cam=Workspace.CurrentCamera
            if not cam then return end
            local cf=cam.CFrame
            local d=cf.LookVector
            local flat=Vector3.new(d.X,0,d.Z)
            if flat.Magnitude<0.05 then flat=Vector3.new(0,0,-1) else flat=flat.Unit end
            fxPart.CFrame=CFrame.new(cf.Position+flat*57+Vector3.new(0,44,0))
        end)
    end
    addOpt(fxSec, "AddToggle", "FXOn", {Title="Включить эффекты", Default=false}, function(v)
        fxOn=v
        if v then startFX() else stopFX() end
    end)
    addOpt(fxSec, "AddDropdown", "FXType", {Title="Тип", Values={"Снег","Сакура"}, Default="Снег"}, function(v)
        fxType=(v=="Сакура") and "Sakura" or "Snow"
        if fxOn then styleFX() end
    end)
    addOpt(fxSec, "AddColorPicker", "FXCol", {Title="Цвет", Default=Color3.fromRGB(150,200,255)}, function(c)
        fxCol=c
        if fxEmit then fxEmit.Color=ColorSequence.new(c) end
    end)
    addOpt(fxSec, "AddSlider", "FXRate", {Title="Интенсивность", Min=20, Max=900, Default=250, Rounding=1}, function(v)
        fxRate=tonumber(v) or 250
        if fxEmit then styleFX() end
    end)

    -- World
    local wSec=tE:AddSection({Name="Мир"})
    local orig={
        Amb=Lighting.Ambient,Br=Lighting.Brightness,CT=Lighting.ClockTime,
        CSB=Lighting.ColorShift_Bottom,CST=Lighting.ColorShift_Top,
        Exp=Lighting.ExposureCompensation,
        FC=Lighting.FogColor,FS=Lighting.FogStart,FE=Lighting.FogEnd,
        OA=Lighting.OutdoorAmbient,GS=Lighting.GlobalShadows,
    }
    addOpt(wSec, "AddToggle", "FBOn", {Title="Fullbright", Default=false}, function(v)
        if v then
            Lighting.Brightness=2 Lighting.ClockTime=14 Lighting.GlobalShadows=false
            Lighting.OutdoorAmbient=Color3.fromRGB(128,128,128)
            Lighting.FogEnd=100000
        else
            Lighting.Brightness=orig.Br Lighting.ClockTime=orig.CT
            Lighting.GlobalShadows=orig.GS Lighting.OutdoorAmbient=orig.OA
            Lighting.FogEnd=orig.FE
        end
    end)
    local timeOn,timeVal=false,12
    addOpt(wSec, "AddToggle", "TimeOn", {Title="Своё время", Default=false}, function(v)
        timeOn=v
        Lighting.ClockTime=v and timeVal or orig.CT
    end)
    addOpt(wSec, "AddSlider", "TimeVal", {Title="Час", Min=0, Max=24, Default=12, Rounding=0}, function(v)
        timeVal=tonumber(v) or 12
        if timeOn then Lighting.ClockTime=timeVal end
    end)
    local expOn,expVal=false,0
    addOpt(wSec, "AddToggle", "ExpOn", {Title="Экспозиция", Default=false}, function(v)
        expOn=v
        Lighting.ExposureCompensation=v and expVal or orig.Exp
    end)
    addOpt(wSec, "AddSlider", "ExpVal", {Title="Значение", Min=-5, Max=5, Default=0, Rounding=2}, function(v)
        expVal=tonumber(v) or 0
        if expOn then Lighting.ExposureCompensation=expVal end
    end)
    local fogOn,fogCol,fogStart,fogEnd=false,Color3.fromRGB(192,192,192),0,1000
    addOpt(wSec, "AddToggle", "FogOn", {Title="Свой туман", Default=false}, function(v)
        fogOn=v
        if v then
            Lighting.FogColor=fogCol Lighting.FogStart=fogStart Lighting.FogEnd=fogEnd
        else
            Lighting.FogColor=orig.FC Lighting.FogStart=orig.FS Lighting.FogEnd=orig.FE
        end
    end)
    addOpt(wSec, "AddColorPicker", "FogCol", {Title="Цвет тумана", Default=Color3.fromRGB(192,192,192)}, function(c)
        fogCol=c
        if fogOn then Lighting.FogColor=c end
    end)
    addOpt(wSec, "AddSlider", "FogStart", {Title="Начало", Min=0, Max=1000, Default=0, Rounding=0}, function(v)
        fogStart=tonumber(v) or 0
        if fogOn then Lighting.FogStart=fogStart end
    end)
    addOpt(wSec, "AddSlider", "FogEnd", {Title="Конец", Min=0, Max=1000, Default=1000, Rounding=0}, function(v)
        fogEnd=tonumber(v) or 1000
        if fogOn then Lighting.FogEnd=fogEnd end
    end)
    local ambOn,ambCol=false,Color3.fromRGB(128,128,128)
    addOpt(wSec, "AddToggle", "AmbOn", {Title="Свой ambient", Default=false}, function(v)
        ambOn=v
        if v then
            Lighting.Ambient=ambCol Lighting.OutdoorAmbient=ambCol
        else
            Lighting.Ambient=orig.Amb Lighting.OutdoorAmbient=orig.OA
        end
    end)
    addOpt(wSec, "AddColorPicker", "AmbCol", {Title="Цвет ambient", Default=Color3.fromRGB(128,128,128)}, function(c)
        ambCol=c
        if ambOn then Lighting.Ambient=c Lighting.OutdoorAmbient=c end
    end)
    getgenv().EFFECTS_UNLOAD=function()
        tracerOn=false
        if tracerConn then pcall(function() tracerConn:Disconnect() end) end
        clearAura()
        stopFX()
        Lighting.Ambient=orig.Amb
        Lighting.Brightness=orig.Br
        Lighting.ClockTime=orig.CT
        Lighting.ColorShift_Bottom=orig.CSB
        Lighting.ColorShift_Top=orig.CST
        Lighting.ExposureCompensation=orig.Exp
        Lighting.FogColor=orig.FC
        Lighting.FogStart=orig.FS
        Lighting.FogEnd=orig.FE
        Lighting.OutdoorAmbient=orig.OA
        Lighting.GlobalShadows=orig.GS
    end
end

-- ============================================================
-- СМЕРТЬ УБИЙЦЫ
-- ============================================================
do
    local meSec=Tabs.Effects:AddSection({Name="Смерть убийцы"})
    local mOn,mCloneOn,mPartOn,mEmitOn=false,false,false,false
    local mCloneCol=Color3.fromRGB(255,0,0)
    local mPartCol=Color3.fromRGB(255,0,0)
    local mEmitCol=Color3.fromRGB(255,100,100)
    local mCloneDur,mEmitDur=3,1.2
    local mClones,mConns,mRoles={},{},{}
    local mThread,mAddConn=nil,nil
    local mActive={}
    local function removeEmitter(rec)
        for i=1,#mActive do
            if mActive[i]==rec then mActive[i]=mActive[#mActive] mActive[#mActive]=nil break end
        end
        if rec.part and rec.part.Parent then rec.part:Destroy() end
    end
    local function spawnEmitter(char,tint,dur,channel)
        if not char or not char.Parent then return end
        if #mActive>=3 then removeEmitter(mActive[1]) end
        dur=math.max(dur,0.2)
        local bodyParts={}
        for _,s in ipairs(char:GetChildren()) do
            if s:IsA("BasePart") and s.Name~="HumanoidRootPart" and #bodyParts<15 then bodyParts[#bodyParts+1]=s end
        end
        if #bodyParts==0 then return end
        local root=Instance.new("Folder")
        root.Name="FH_MurderFX" root.Parent=Workspace
        local rec={part=root,balls={},channel=channel}
        mActive[#mActive+1]=rec
        local rnd=srand
        local golden=math.pi*(3-math.sqrt(5))
        local function surfPos(source,radius,index,count,headSeed)
            local sz=source.Size
            local pad=radius*0.92
            if source.Name=="Head" then
                local y=1-2*((index-0.5)/count)
                local angle=index*golden+headSeed
                local radial=math.sqrt(math.max(0,1-y*y))
                local dir=Vector3.new(radial*math.cos(angle),y,radial*math.sin(angle))
                local half=sz*0.5
                return source.CFrame:PointToWorldSpace(Vector3.new(dir.X*(half.X+pad),dir.Y*(half.Y+pad),dir.Z*(half.Z+pad)))
            end
            local ax=sz.Y*sz.Z local ay=sz.X*sz.Z local az=sz.X*sz.Y
            local pick=rnd()*(ax+ay+az)
            local pos
            if pick<ax then
                local side=rnd()<0.5 and -1 or 1
                pos=Vector3.new(side*(sz.X*0.5+pad),(rnd()-0.5)*sz.Y,(rnd()-0.5)*sz.Z)
            elseif pick<ax+ay then
                local side=rnd()<0.5 and -1 or 1
                pos=Vector3.new((rnd()-0.5)*sz.X,side*(sz.Y*0.5+pad),(rnd()-0.5)*sz.Z)
            else
                local side=rnd()<0.5 and -1 or 1
                pos=Vector3.new((rnd()-0.5)*sz.X,(rnd()-0.5)*sz.Y,side*(sz.Z*0.5+pad))
            end
            return source.CFrame:PointToWorldSpace(pos)
        end
        local minY,maxY=math.huge,-math.huge
        for _,s in ipairs(bodyParts) do
            local hy=s.Size.Y*0.5
            minY=math.min(minY,s.Position.Y-hy)
            maxY=math.max(maxY,s.Position.Y+hy)
        end
        local phaseCount=8
        local groups={}
        for i=1,phaseCount do groups[i]={} end
        local headSeed=rnd()*math.pi*2
        local height=math.max(maxY-minY,0.01)
        local created=0
        for _,s in ipairs(bodyParts) do
            local sz=s.Size
            local surface=2*(sz.X*sz.Y+sz.X*sz.Z+sz.Y*sz.Z)
            local count=s.Name=="Head" and 24 or math.clamp(math.floor(surface*0.65+0.5),7,12)
            count=math.min(count,140-created)
            for index=1,count do
                local dia=s.Name=="Head" and (0.115+rnd()*0.045) or (0.13+rnd()*0.06)
                local tsz=Vector3.new(dia,dia,dia)
                local pos=surfPos(s,dia*0.5,index,count,headSeed)
                local ball=Instance.new("Part")
                ball.Shape=Enum.PartType.Ball
                ball.Material=Enum.Material.Neon
                ball.Color=tint
                ball.Size=Vector3.new(0.015,0.015,0.015)
                ball.Position=pos
                ball.Anchored=true ball.CanCollide=false ball.CanQuery=false ball.CanTouch=false
                ball.CastShadow=false ball.Massless=true ball.Transparency=1
                ball.Parent=root
                rec.balls[#rec.balls+1]=ball
                created=created+1
                local v=math.clamp((pos.Y-minY)/height,0,1)
                local phase=math.clamp(math.floor(v*(phaseCount-1)+1.5)+rnd(-1,1),1,phaseCount)
                groups[phase][#groups[phase]+1]={ball=ball,size=tsz}
            end
            if created>=140 then break end
        end
        local revealWindow=math.min(0.34,dur*0.26)
        local revealTime=math.min(0.2,dur*0.18)
        local fadeBegin=math.max(revealWindow+revealTime+0.06,dur*0.42)
        local fadeWindow=math.min(0.28,dur*0.18)
        local fadeTime=math.max(dur-fadeBegin-fadeWindow,0.1)
        for phase=1,phaseCount do
            local alpha=(phase-1)/(phaseCount-1)
            local group=groups[phase]
            task.delay(revealWindow*alpha,function()
                if not root.Parent then return end
                for _,item in ipairs(group) do
                    if item.ball.Parent then
                        TweenService:Create(item.ball,TweenInfo.new(revealTime,Enum.EasingStyle.Sine),{Size=item.size,Transparency=0.05}):Play()
                    end
                end
            end)
            task.delay(fadeBegin+fadeWindow*alpha,function()
                if not root.Parent then return end
                for _,item in ipairs(group) do
                    if item.ball.Parent then
                        TweenService:Create(item.ball,TweenInfo.new(fadeTime,Enum.EasingStyle.Sine),{Size=item.size*0.58,Transparency=1}):Play()
                    end
                end
            end)
        end
        task.delay(dur+0.12,function() removeEmitter(rec) end)
    end
    local function makeClone(char)
        local ok,clone=pcall(function() return char:Clone() end)
        if not ok or not clone then return end
        for _,d in ipairs(clone:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored=true d.CanCollide=false d.CanQuery=false d.CanTouch=false
                if d.Name=="HumanoidRootPart" then d.Transparency=1
                else d.Material=Enum.Material.ForceField d.Color=mCloneCol end
            elseif d:IsA("Humanoid") or d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") or d:IsA("Sound") or d:IsA("SurfaceAppearance") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") or d:IsA("Highlight") then
                pcall(function() d:Destroy() end)
            end
        end
        clone.Name="FH_MurderClone"
        clone.Parent=Workspace
        mClones[#mClones+1]=clone
        task.delay(mCloneDur,function()
            if not clone.Parent then return end
            for _,d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") and d.Name~="HumanoidRootPart" then
                    TweenService:Create(d,TweenInfo.new(1.5),{Transparency=1}):Play()
                end
            end
            task.delay(1.6,function()
                for i=#mClones,1,-1 do
                    if mClones[i]==clone then table.remove(mClones,i) end
                end
                if clone.Parent then clone:Destroy() end
            end)
        end)
    end
    local function onMurderDeath(char)
        if mCloneOn then makeClone(char) end
        if mPartOn then spawnEmitter(char,mPartCol,1.2,"particle") end
        if mEmitOn then spawnEmitter(char,mEmitCol,mEmitDur,"emitter") end
    end
    local function hookPlayer(pl)
        local function onChar(char)
            local hum=char:WaitForChild("Humanoid",5)
            if not hum then return end
            mConns[#mConns+1]=hum.Died:Connect(function()
                if mOn and mRoles[pl.Name]=="Murderer" then onMurderDeath(char) end
            end)
        end
        if pl.Character then task.spawn(onChar,pl.Character) end
        mConns[#mConns+1]=pl.CharacterAdded:Connect(onChar)
    end
    local function stopMurder()
        for _,c in ipairs(mConns) do pcall(function() c:Disconnect() end) end
        mConns={}
        for i=1,#mActive do
            local p=mActive[i]
            if p then pcall(function() p.part:Destroy() end) end
        end
        mActive={}
        if mAddConn then pcall(function() mAddConn:Disconnect() end) mAddConn=nil end
        for _,c in ipairs(mClones) do pcall(function() c:Destroy() end) end
        mClones={}
    end
    addOpt(meSec, "AddToggle", "MEOn", {Title="Включить эффект", Default=false}, function(v)
        mOn=v
        if v then
            mThread=task.spawn(function()
                while mOn do
                    pcall(function()
                        local data=getRoundData()
                        if type(data)=="table" then
                            local m={}
                            for name,d in pairs(data) do
                                if type(d)=="table" and d.Role then m[name]=d.Role end
                            end
                            mRoles=m
                        end
                    end)
                    task.wait(1)
                end
            end)
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl~=LocalPlayer then hookPlayer(pl) end
            end
            mAddConn=Players.PlayerAdded:Connect(function(pl)
                if pl~=LocalPlayer then hookPlayer(pl) end
            end)
        else
            stopMurder()
            if mThread then pcall(function() task.cancel(mThread) end) mThread=nil end
        end
    end)
    addOpt(meSec, "AddToggle", "MEClone", {Title="Клон", Default=false}, function(v) mCloneOn=v end)
    addOpt(meSec, "AddColorPicker", "MECloneCol", {Title="Цвет клона", Default=Color3.fromRGB(255,0,0)}, function(c) mCloneCol=c end)
    addOpt(meSec, "AddSlider", "MECloneDur", {Title="Длительность клона", Min=1, Max=5, Default=3, Rounding=1}, function(v) mCloneDur=tonumber(v) or 3 end)
    addOpt(meSec, "AddToggle", "MEPart", {Title="Частицы", Default=false}, function(v) mPartOn=v end)
    addOpt(meSec, "AddColorPicker", "MEPartCol", {Title="Цвет частиц", Default=Color3.fromRGB(255,0,0)}, function(c) mPartCol=c end)
    addOpt(meSec, "AddToggle", "MEEmit", {Title="Emitter", Default=false}, function(v) mEmitOn=v end)
    addOpt(meSec, "AddColorPicker", "MEEmitCol", {Title="Цвет emitter", Default=Color3.fromRGB(255,100,100)}, function(c)
        mEmitCol=c
        for i=1,#mActive do
            local e=mActive[i]
            if e and e.channel=="emitter" then
                for _,b in ipairs(e.balls) do if b.Parent then b.Color=c end end
            end
        end
    end)
    addOpt(meSec, "AddSlider", "MEEmitDur", {Title="Длительность emitter", Min=1, Max=5, Default=1, Rounding=1}, function(v) mEmitDur=tonumber(v) or 1 end)
    getgenv().MURDER_UNLOAD=function()
        mOn=false stopMurder()
        if mThread then pcall(function() task.cancel(mThread) end) mThread=nil end
    end
end

-- ============================================================
-- ФАРМ (только Advanced, без Down)
-- ============================================================
do
    local tF=Tabs.Farm
    local farmSec=tF:AddSection({Name="Автофарм"})
    local active=false
    local mode="Basic"
    local speed=23
    local avoid=false
    local fullAction="Respawn"
    local ncCache={}
    local farmTarget=nil
    local coinsDone,sawCoins=false,false
    local lastTouch=0
    local AVOID_DIST=40
    local function hrp()
        local c=LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function canFarm()
        local char=LocalPlayer.Character
        local h=char and char:FindFirstChildOfClass("Humanoid")
        if not h or h.Health<=0 then return false end
        local d=getRoundData()
        if type(d)=="table" then
            local me=d[LocalPlayer.Name]
            if not me or not me.Role or me.Dead then return false end
        end
        return true
    end
    local function bagsFull()
        local pg=LocalPlayer:FindFirstChild("PlayerGui")
        local main=pg and pg:FindFirstChild("MainGUI")
        local gg=main and main:FindFirstChild("Game")
        local b=gg and gg:FindFirstChild("CoinBags")
        local cont=b and b:FindFirstChild("Container")
        if not cont then return false end
        local any=false
        for _,v in ipairs(cont:GetChildren()) do
            if v:IsA("Frame") and v.Visible then
                any=true
                local full=v:FindFirstChild("Full")
                if not (full and full.Visible) then return false end
            end
        end
        return any
    end
    local function resetProgress()
        coinsDone=false sawCoins=false farmTarget=nil
    end
    task.spawn(function()
        local ok,r=pcall(function() return ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay"):WaitForChild("CoinsStarted",15) end)
        if ok and r then r.OnClientEvent:Connect(resetProgress) end
    end)
    LocalPlayer.CharacterAdded:Connect(resetProgress)
    local function coinOK(v)
        return v and v.Parent and v:IsA("BasePart") and not v:GetAttribute("Collected") and not v:GetAttribute("Delete")
    end
    local function coinList()
        local out={}
        for _,v in ipairs(CollectionService:GetTagged("CoinVisual")) do
            if coinOK(v) then out[#out+1]=v end
        end
        return out
    end
    local function nearest(pos,list)
        local b,bd=nil,math.huge
        for _,v in ipairs(list) do
            local d=(v.Position-pos).Magnitude
            if d<bd then bd=d b=v end
        end
        return b
    end
    local function setNoclip(on)
        local c=LocalPlayer.Character
        local h=c and c:FindFirstChildOfClass("Humanoid")
        if on then
            if not c then return end
            if h then pcall(function() h.PlatformStand=true end) end
            for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    if ncCache[p]==nil then ncCache[p]=p.CanCollide end
                    p.CanCollide=false
                end
            end
        else
            if h then pcall(function() h.PlatformStand=false end) end
            for p,v in pairs(ncCache) do
                if p and p.Parent then pcall(function() p.CanCollide=v end) end
            end
            ncCache={}
        end
    end
    local mhrpCache,mhrpT=nil,0
    local function murdererHRP()
        local now=os.clock()
        if now-mhrpT<0.25 then return mhrpCache end
        mhrpT=now mhrpCache=nil
        local d=getRoundData()
        if type(d)~="table" then return nil end
        for name,info in pairs(d) do
            if type(info)=="table" and info.Role=="Murderer" and not info.Dead and name~=LocalPlayer.Name then
                local pl=Players:FindFirstChild(name)
                local ch=pl and pl.Character
                local hh=ch and ch:FindFirstChild("HumanoidRootPart")
                local hum=ch and ch:FindFirstChildOfClass("Humanoid")
                if hh and (not hum or hum.Health>0) then mhrpCache=hh end
                break
            end
        end
        return mhrpCache
    end
    local function flatDist(a,b) return Vector3.new(a.X-b.X,0,a.Z-b.Z).Magnitude end
    local function fireTouch(coin)
        if type(firetouchinterest)~="function" then return end
        if not coin or not coin.Parent then return end
        local now=os.clock()
        if now-lastTouch<0.05 then return end
        lastTouch=now
        local my=hrp()
        if not my then return end
        local targets={coin}
        for _,v in ipairs(coin:GetChildren()) do
            if v:IsA("BasePart") then targets[#targets+1]=v end
        end
        for _,p in ipairs(targets) do
            pcall(firetouchinterest,my,p,0)
            pcall(firetouchinterest,my,p,1)
        end
    end
    local function pickCoin(pos,list,mpos)
        if not (avoid and mpos) then return nearest(pos,list) end
        local safe,sd=nil,math.huge
        local far,fd=nil,-1
        for _,v in ipairs(list) do
            local md=flatDist(v.Position,mpos)
            if md>fd then fd=md far=v end
            if md>=AVOID_DIST then
                local d=(v.Position-pos).Magnitude
                if d<sd then sd=d safe=v end
            end
        end
        return safe or (fd>=AVOID_DIST*0.6 and far or nil)
    end
    local function coinOKNow(v,mpos)
        if not coinOK(v) then return false end
        if avoid and mpos and flatDist(v.Position,mpos)<AVOID_DIST*0.6 then return false end
        return true
    end
    local function avoidSteer(cur,dest,mpos)
        if not (avoid and mpos) then return dest end
        local dm=flatDist(cur,mpos)
        if dm>=AVOID_DIST then return dest end
        local away=Vector3.new(cur.X-mpos.X,0,cur.Z-mpos.Z)
        if away.Magnitude<0.1 then away=Vector3.new(1,0,0) end
        away=away.Unit
        local want=Vector3.new(dest.X-cur.X,0,dest.Z-cur.Z)
        local mag=want.Magnitude
        if mag<0.1 then return dest end
        local w=1+(1-dm/AVOID_DIST)*2
        local blend=(want.Unit+away*w)
        if blend.Magnitude<0.1 then blend=away else blend=blend.Unit end
        local np=cur+blend*mag
        return Vector3.new(np.X,dest.Y,np.Z)
    end
    local function farmMove(my,dest,dt)
        local dir=dest-my.Position
        local dist=dir.Magnitude
        local np=dest
        if dist>0.1 then np=my.Position+dir.Unit*math.min(speed*dt,dist) end
        local cf=CFrame.new(np)
        pcall(function()
            my.CFrame=cf
            my.AssemblyLinearVelocity=Vector3.zero
            my.AssemblyAngularVelocity=Vector3.zero
        end)
    end
    local function killAllPlayersViaKA()
        local char=LocalPlayer.Character
        if not char then return end
        local knife=char:FindFirstChild("Knife")
        if not knife then
            local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
            knife=bp and bp:FindFirstChild("Knife")
            if knife then
                local hum=char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(knife) task.wait(0.1) end
            end
        end
        if not knife then return end
        local ev=knife:FindFirstChild("Events")
        if not ev then return end
        local stabbed=ev:FindFirstChild("KnifeStabbed")
        local touched=ev:FindFirstChild("HandleTouched")
        if not stabbed or not touched then return end
        local my=char:FindFirstChild("HumanoidRootPart")
        if not my then return end
        for _=1,3 do
            local victims={}
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer then
                    local tc=p.Character
                    if tc then
                        local th=tc:FindFirstChildOfClass("Humanoid")
                        local tp=tc:FindFirstChild("HumanoidRootPart")
                        if th and th.Health>0 and tp and (tp.Position-my.Position).Magnitude<=60 then
                            victims[#victims+1]=tp
                        end
                    end
                end
            end
            if #victims>0 then
                pcall(function() stabbed:FireServer() end)
                for _,v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            end
            task.wait(0.05)
        end
    end
    local function fireFullAction()
        if fullAction=="Respawn" then
            local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health=0 end) end
        elseif fullAction=="Auto" then
            local myRole=getRoleFromData(LocalPlayer)
            if myRole=="murderer" then task.spawn(killAllPlayersViaKA) end
        end
    end
    local CONFLICT_OPTS={"KAOn","SilentAuto","SilentEnabled","AutoGrabGun","ToolFling","ToolTP","Aura2On","FXOn","TracerOn","FreezeToggle","Noclip","Spinbot","SpeedGlitchOn","BhopOn","InfJump"}
    local savedConflicts={}
    local function disableConflicts()
        savedConflicts={}
        for _,name in ipairs(CONFLICT_OPTS) do
            local opt=Options[name]
            if opt and opt.Value==true then
                savedConflicts[name]=true
                pcall(function() opt:SetValue(false) end)
            end
        end
        if next(savedConflicts) then Notify("FH","Конфликтующие функции отключены",3) end
    end
    local function restoreConflicts()
        for name,was in pairs(savedConflicts) do
            local opt=Options[name]
            if opt then pcall(function() opt:SetValue(true) end) end
        end
        if next(savedConflicts) then Notify("FH","Функции восстановлены",2) end
        savedConflicts={}
    end
    RunService.Stepped:Connect(function(_,dt)
        if not active then return end
        if not canFarm() then
            farmTarget=nil setNoclip(false) return
        end
        local my=hrp()
        if not my then return end
        local list=coinList()
        local function finish()
            farmTarget=nil
            setNoclip(false)
            if not coinsDone then coinsDone=true fireFullAction() end
        end
        if sawCoins and bagsFull() then finish() return end
        if #list>0 then
            sawCoins=true
            if coinsDone then coinsDone=false end
            local mhrp=avoid and murdererHRP() or nil
            local mpos=mhrp and mhrp.Position or nil
            if not coinOKNow(farmTarget,mpos) then farmTarget=pickCoin(my.Position,list,mpos) end
            if farmTarget then
                setNoclip(true)
                local cpos=farmTarget.Position
                local dest=cpos
                if (cpos-my.Position).Magnitude<=6 then fireTouch(farmTarget) end
                dest=avoidSteer(my.Position,dest,mpos)
                farmMove(my,dest,dt)
            elseif mpos then
                setNoclip(true)
                local away=Vector3.new(my.Position.X-mpos.X,0,my.Position.Z-mpos.Z)
                if away.Magnitude<0.1 then away=Vector3.new(1,0,0) end
                away=away.Unit
                farmMove(my,my.Position+away*40,dt)
            end
        else
            farmTarget=nil
            setNoclip(false)
            if sawCoins and not coinsDone then finish() end
        end
    end)
    addOpt(farmSec, "AddToggle", "FarmV3On", {Title="Включить автофарм", Default=false}, function(v)
        active=v
        if v then disableConflicts() else restoreConflicts() setNoclip(false) end
        resetProgress()
    end)
    addOpt(farmSec, "AddSlider", "FarmV3Speed", {Title="Скорость", Min=5, Max=60, Default=23, Rounding=1}, function(v) speed=tonumber(v) or 23 end)
    addOpt(farmSec, "AddToggle", "FarmV3Avoid", {Title="Избегать маньяка", Default=false}, function(v) avoid=v farmTarget=nil end)
    addOpt(farmSec, "AddDropdown", "FarmFullAction", {Title="При полном мешке", Values={"Respawn","Auto"}, Default="Respawn"}, function(v) fullAction=v or "Respawn" end)
    getgenv().FARMV3_UNLOAD=function()
        active=false
        farmTarget=nil
        setNoclip(false)
        restoreConflicts()
    end
end

-- ============================================================
-- ЭМОЦИИ (работают как АНИМАЦИИ через Animate)
-- ============================================================
do
    local animTab=Tabs.Animations
    local animSec=animTab:AddSection({Name="Эмоции"})

    local EMOTE_LIST = {
        ["Around Town"]=3576747102, ["Fashionable"]=3576745472, ["Swish"]=3821527813,
        ["Top Rock"]=3570535774, ["Fancy Feet"]=3934988903, ["Idol"]=4102317848,
        ["Sneaky"]=3576754235, ["Robot"]=3576721660, ["Louder"]=3576751796,
        ["Twirl"]=3716633898, ["Bodybuilder"]=3994130516, ["Jacks"]=3570649048,
        ["Shuffle"]=4391208058, ["Dorky Dance"]=4212499637, ["Dizzy"]=3934986896,
        ["Air Dance"]=4646302011, ["TMNT Dance"]=18665886405, ["Line Dance"]=4049646104,
        ["Break Dance"]=5915773992, ["Zombie"]=4212496830, ["Baby Dance"]=4272484885,
        ["Cha Cha"]=6865013133, ["Dolphin Dance"]=5938365243, ["Wanna play?"]=16646438742,
        ["Samba"]=6869813008, ["Side to Side"]=3762641826, ["Tree"]=4049634387,
        ["Godlike"]=3823158750, ["Keeping Time"]=4646306072, ["Tantrum"]=5104374556,
        ["Rock On"]=5915782672, ["Hero Landing"]=5104377791, ["Fishing"]=3994129128,
        ["Floss Dance"]=5917570207, ["Get Out"]=3934984583, ["Victory Dance"]=15506503658,
        ["Monkey"]=3716636630, ["Greatest"]=3762654854, ["Jumping Wave"]=4940602656,
        ["Haha"]=4102315500, ["Agree"]=4849487550, ["Mini Kong"]=17000058939,
        ["Festive Dance"]=15679955281, ["Jumping Cheer"]=5895009708, ["Sleep"]=4689362868,
        ["Disagree"]=4849495710, ["Happy"]=4849499887, ["Bored"]=5230661597,
        ["High Wave"]=5915776835, ["Cower"]=4940597758, ["Rock n Roll"]=15506496093,
        ["Shy"]=3576717965, ["Curtsy"]=4646306583, ["Celebrate"]=3994127840,
        ["Confused"]=4940592718, ["Beckon"]=5230615437, ["Sad"]=4849502101,
        ["Cha-Cha"]=3696764866, ["Chicken Dance"]=4849493309, ["Sandwich Dance"]=4390121879,
        ["Salute"]=3360689775, ["Stadium"]=3360686498, ["Bunny Hop"]=4646296016,
        ["Swag Walk"]=10478377385, ["Superhero Reveal"]=3696759798, ["Hype Dance"]=3696757129,
        ["Heisman Pose"]=3696763549, ["Vroom Vroom"]=18526410572, ["Tilt"]=3360692915,
        ["Applaud"]=5915779043, ["Hello"]=3576686446, ["Vans Ollie"]=18305539673,
        ["Shrug"]=3576968026, ["Wally West"]=133948663586698, ["Take The L"]=123159156696507,
        ["Belly Dancing"]=131939729732240, ["CaramellDansen"]=93105950995997,
        ["Rambunctious"]=134311528115559, ["Ballin"]=96293409369770,
        ["Nyan Nyan!"]=73796726960568, ["Skibidi"]=124828909173982,
        ["Chronoshift"]=92600655160976, ["Floating on Clouds"]=111426928948833,
        ["Jersey Joe"]=134149640725489, ["Virtual Insanity"]=83261816934732,
        ["Doodle Dance"]=107091254142209, ["Club Penguin"]=98099211500155,
        ["Kazotsky"]=97629500912487, ["Miku Dance"]=117734400993750,
        ["Gangnam Style"]=77205409178702, ["Push-Up"]=117922227854118,
        ["Split"]=98522218962476, ["PROXIMA"]=81390693780805,
        ["HeadBanging"]=87447252507832, ["Assumptions"]=127507691649322,
        ["Jumpstyle"]=99563839802389, ["Flopping Fish"]=133142324349281,
        ["Fancy Feets"]=124512151372711, ["Absolute Cinema"]=97258018304125,
        ["Griddy"]=116065653184749, ["Paranoid"]=123407922818447,
        ["Kawaii Groove"]=77152953688098, ["Smeeze"]=131683926643291,
        ["Onion"]=113890289455724, ["Thinking"]=124584711308900,
        ["Slenderman"]=81926508907412, ["Macarena"]=91274761264433,
        ["RONALDO"]=97547486465713, ["Slickback"]=103789826265487,
        ["Default Dance"]=80877772569772, ["Family Guy"]=78459263478161,
    }

    local emoteNames = {}
    for name in pairs(EMOTE_LIST) do emoteNames[#emoteNames+1] = name end
    table.sort(emoteNames, function(a,b) return a:lower() < b:lower() end)

    local currentTrack = nil
    local function stopCurrent()
        if currentTrack then
            pcall(function() currentTrack:Stop() end)
            currentTrack = nil
        end
    end
    -- Работает как АНИМАЦИЯ, а не как эмоция
    local function playEmoteByName(name)
        local id = EMOTE_LIST[name]
        if not id then return end
        local c = LocalPlayer.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then Notify("FH","Персонаж не загружен",2) return end
        stopCurrent()
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://"..tostring(id)
        local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = true
            pcall(function() track:Play(0) end)
            currentTrack = track
            Notify("FH", name, 2)
        else
            Notify("FH", "Не удалось запустить", 2)
        end
    end

    addOpt(animSec, "AddToggle", "EmoteAnimOn", {Title="Включить эмоцию", Default=false}, function(v)
        if v then
            local name = Options.EmoteAnimPick and Options.EmoteAnimPick.Value
            if type(name)=="table" then name=name[1] end
            if type(name)=="string" then playEmoteByName(name) end
        else
            stopCurrent()
        end
    end)
    addOpt(animSec, "AddDropdown", "EmoteAnimPick", {Title="Выбрать эмоцию", Values=emoteNames, Default=emoteNames[1] or "Default Dance"}, function(v)
        if Options.EmoteAnimOn and Options.EmoteAnimOn.Value then
            playEmoteByName(v)
        end
    end)
    addOpt(animSec, "AddButton", "EmoteStopBtn", {Title="Остановить эмоцию", Callback=function()
        stopCurrent()
        local o = Options.EmoteAnimOn
        if o then o:SetValue(false) end
        Notify("FH","Остановлено",2)
    end})
end

-- ============================================================
-- УТИЛИТЫ
-- ============================================================
do
    local tU=Tabs.Utility
    -- Уведомления
    local notifySec=tU:AddSection({Name="Уведомления"})
    local notifyOn,rolesOn=false,false
    local lastRole=nil
    task.spawn(function()
        while task.wait(0.5) do
            if notifyOn and rolesOn then
                local d=getRoundData()
                local r=d and d[LocalPlayer.Name] and d[LocalPlayer.Name].Role
                if r and r~=lastRole then
                    lastRole=r
                    local ru=(r=="Sheriff" and "Шериф") or (r=="Hero" and "Герой") or (r=="Murderer" and "Маньяк") or (r=="Innocent" and "Мирный") or r
                    Notify("FH","Роль: "..ru,4)
                elseif not r then lastRole=nil end
            end
        end
    end)
    addOpt(notifySec, "AddToggle", "NotifyOn", {Title="Включить", Default=false}, function(v) notifyOn=v end)
    addOpt(notifySec, "AddToggle", "NotifyRoles", {Title="Показывать роль", Default=false}, function(v) rolesOn=v end)

    -- Невидимость
    local invisSec=tU:AddSection({Name="Невидимость"})
    local invis={active=false,realCF=nil,hbConn=nil,bindName="FH_InvisClient",savedLTM={},savedDecals={},savedFallenHeight=nil}
    local HIDDEN_CF=CFrame.new(0,-50000,0)
    getgenv().FH_INVIS_ACTIVE=false
    local function invisRestoreParts()
        local char=LocalPlayer.Character
        if char then
            for p,v in pairs(invis.savedLTM) do
                if p and p.Parent then pcall(function() p.LocalTransparencyModifier=v end) end
            end
            for d,v in pairs(invis.savedDecals) do
                if d and d.Parent then pcall(function() d.Transparency=v end) end
            end
        end
        invis.savedLTM={} invis.savedDecals={}
    end
    local function invisBegin()
        if invis.active then return end
        local char=LocalPlayer.Character
        if not char then Notify("FH","Персонаж не загружен",2) return end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then Notify("FH","Персонаж не загружен",2) return end
        invis.savedLTM={} invis.savedDecals={}
        invis.realCF=hrp.CFrame
        invis.active=true
        getgenv().FH_INVIS_ACTIVE=true
        invis.savedFallenHeight=Workspace.FallenPartsDestroyHeight
        pcall(function() Workspace.FallenPartsDestroyHeight=-9e9 end)
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                invis.savedLTM[p]=p.LocalTransparencyModifier
                p.LocalTransparencyModifier=0.5
            elseif p:IsA("Decal") or p:IsA("Texture") then
                invis.savedDecals[p]=p.Transparency
                p.Transparency=0.5
            end
        end
        invis.hbConn=RunService.Heartbeat:Connect(function()
            if not invis.active then return end
            local c=LocalPlayer.Character
            local h=c and c:FindFirstChild("HumanoidRootPart")
            if not h then return end
            invis.realCF=h.CFrame
            h.CFrame=HIDDEN_CF
        end)
        RunService:BindToRenderStep(invis.bindName,Enum.RenderPriority.Camera.Value-1,function()
            if not invis.active then return end
            local c=LocalPlayer.Character
            local h=c and c:FindFirstChild("HumanoidRootPart")
            if h and invis.realCF then h.CFrame=invis.realCF end
        end)
        Notify("FH","Невидимость ВКЛ",2)
    end
    local function invisEnd()
        if not invis.active then return end
        local char=LocalPlayer.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        local finalCF=invis.realCF
        invis.active=false
        getgenv().FH_INVIS_ACTIVE=false
        if invis.hbConn then pcall(function() invis.hbConn:Disconnect() end) invis.hbConn=nil end
        pcall(function() RunService:UnbindFromRenderStep(invis.bindName) end)
        if hrp and finalCF then
            pcall(function()
                hrp.CFrame=finalCF
                hrp.AssemblyLinearVelocity=Vector3.zero
                hrp.AssemblyAngularVelocity=Vector3.zero
            end)
        end
        invisRestoreParts()
        if invis.savedFallenHeight~=nil then
            pcall(function() Workspace.FallenPartsDestroyHeight=invis.savedFallenHeight end)
            invis.savedFallenHeight=nil
        end
        invis.realCF=nil
        Notify("FH","Невидимость ВЫКЛ",2)
    end
    addOpt(invisSec, "AddToggle", "InvisOn", {Title="Включить невидимость", Default=false}, function(v)
        if v then invisBegin() else invisEnd() end
    end)
    getgenv().INVIS_UNLOAD=function() if invis.active then invisEnd() end end

    -- ============================================================
    -- ЗВУКИ (новые из KITI, заменили старые)
    -- ============================================================
    local SND_BASES={
        "https://cdn.jsdelivr.net/gh/khenn791/lmao@main/",
        "https://raw.githack.com/khenn791/lmao/main/",
        "https://github.com/khenn791/lmao/raw/refs/heads/main
