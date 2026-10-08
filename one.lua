-- ============================================================
-- main.lua — FortniHub MM2 v20.1 — ЧАСТЬ 1/2
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
local LocalPlayer=Players.LocalPlayer
local Camera=Workspace.CurrentCamera
local VERSION="20.1.0 BETA"
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
local function isMurderer()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and getRoleFromData(p)=="murderer" then return p end
    end
    return nil
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

local HUDGui,FPSLabel,PingLabel,Pill
do
    pcall(function()
        for _,name in ipairs({"FH_HUD_v18","FH_HUD","FH_HUD_v182","FH_HUD_v1821","FH_HUD_v183","FH_HUD_v184","FH_HUD_v185","FH_HUD_v186","FH_HUD_v19","FH_HUD_v20"}) do
            local old=CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
    HUDGui=Instance.new("ScreenGui")
    HUDGui.Name="FH_HUD_v21"
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

    local gap_min = 0
    local gap_seen = false
    local gap_gun = nil
    local want_since = 0

    local function gap_reset() gap_min=0 gap_seen=false SS.fire_gap=0 end
    local function gap_push(value)
        if value <= 0 then return end
        if not gap_seen or value < gap_min then
            gap_min=value gap_seen=true SS.fire_gap=value
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

    local target_player = nil
    local target_char = nil
    local target_part = nil
    local target_hum = nil

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

    local ignore_base = {}
    local ignore_work = {}
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

    local P = {
        snap=48, ring=48, hit_r=2.1, pad=2.6, min_span=5, max_span=90,
        acc_t=0.15, acc_max=280, acc_min=40, speed_floor=26, speed_head=1.3,
    }

    local snap_t = table.create(P.snap, 0)
    local snap_p = table.create(P.snap, Vector3.zero)
    local snap_n = 0
    local snap_i = 0

    local TR = {
        part=nil, pos=nil, time=0, vel=Vector3.zero, gap=0,
        ready=false, fresh=Vector3.zero, air=false, air_since=0,
        jumping=false, jump_v=0, fresh_ok=false, turn=0,
        spoof=0, clr=0, air_edge=0, jump_fresh=false,
    }

    local SK = {
        vt=table.create(P.ring, 0), dx=table.create(P.ring, 0), dz=table.create(P.ring, 0),
        vn=0, vi=0,
    }

    local EC = { ping=0, rtt=0, jitter=0, seen=false, step=0, step_seen=false }

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

    local HY = { pos={}, w={}, n=0, weight=0, primary=nil, stamp=0, conf=0 }

    local ground_params = RaycastParams.new()
    ground_params.FilterType = Enum.RaycastFilterType.Exclude
    ground_params.IgnoreWater = true
    local ground_filter = {}
    local axis_pool = {}

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

    local KIN = { ok=false, ax=0, az=0, smax=0 }
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
            if am > P.acc_max and am > 0 then
                ax = ax * P.acc_max / am
                az = az * P.acc_max / am
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

    local GC = { base=0, seen=false }
    local JL = { v=0, seen=false }
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
        local a = math.clamp((align - 0.7)/0.25, 0, 1)
        local r = 1 - math.clamp(math.abs(ratio - 1)/0.4, 0, 1)
        return a * r
    end
    local function phase_velocity(v, age, air)
        if not v then return nil end
        local y = 0
        if air then y = v.Y - grav() * math.clamp(age or 0, 0, sample_span() * 4) end
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
                base = Vector3.new(base.X, base.Y, base.Z):Lerp(Vector3.new(base.X, live.Y, base.Z), trust * 0.35)
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
        local ok, ms = pcall(function()
            return stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
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
        if TR.time > 0 and EC.step_seen then
            stale = math.clamp(os.clock() - TR.time, 0, EC.step)
        end
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
            if reach > cap and reach > 1e-6 then
                dx = dx*cap/reach
                dz = dz*cap/reach
            end
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
        local best_axis, best_cov, best_lo, best_hi = nil, -1, 0, 0
        for k = 1, count do
            local axis = axis_pool[k]
            local cov, lo, hi = score_axis(anchor, axis)
            if cov > best_cov then best_axis, best_cov, best_lo, best_hi = axis, cov, lo, hi end
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

    local hit_names = {
        "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "Head",
        "RightUpperArm", "LeftUpperArm", "Right Arm", "Left Arm",
        "RightUpperLeg", "LeftUpperLeg", "Right Leg", "Left Leg",
        "RightLowerLeg", "LeftLowerLeg",
    }
    local hit_parts = {}
    local hit_count = 0
    local hit_char = nil
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

    local force_att = nil
    local force_saved = nil
    local force_stamp = 0
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
                if behind < P.pad then origin = origin - u*(P.pad - behind) end
                local ahead = (aim - mark):Dot(u)
                if ahead < P.min_span then aim = mark + u*P.min_span end
                local want = SS.stand_off
                while want > 0 do
                    local probe = origin - u*want
                    if (aim - probe).Magnitude <= P.max_span
                        and los_clear(probe, mark)
                        and los_clear(probe, live) then
                        origin = probe
                        break
                    end
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

    local weapon_service = nil
    local orig_mouse = nil
    local orig_screen = nil
    local hook_mouse = nil
    local hook_screen = nil

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

    local gun_fired_conn = nil
    local last_fire_stamp = 0
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
                if fire_gun(gun, origin_cf, aim_cf) then
                    SS.last_shot = now
                end
            end
            return
        end
        local cf = origin_cframe()
        if not cf then return end
        local aim = pick_point(cf.Position, true)
        if not aim then return end
        local aim_cf = compensate_resolve(CFrame.new(aim))
        if fire_gun(gun, cf, aim_cf) then
            SS.last_shot = now
        end
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
            watch_conns[#watch_conns+1] = m.PlayerDataChanged.Event:Connect(function()
                pcall(refresh_target)
            end)
        end
        watch_conns[#watch_conns+1] = lp.CharacterAdded:Connect(function()
            task.wait(0.3)
            pcall(refresh_target)
        end)
    end

    local next_role = 0
    local next_hook = 0
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
        Notify("FH", "Silent "..(v and "ВКЛ" or "ВЫКЛ"), 1.5)
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
-- ТИХИЙ БРОСОК НОЖА (заглушка)
-- ============================================================
do
    local knifeSec = Tabs.Combat:AddSection({Name="Тихий бросок ножа"})
    addOpt(knifeSec, "AddToggle", "KnifeSilentOn", {Title="Включить", Default=false, Flag="KnifeSilentOn"}, function(v)
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
-- БИНДЫ (с фиксом сохранения)
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
    for _,e in ipairs(BIND_LIST) do
        BindState[e.id]={key=nil,touchOn=false,btn=nil,def=e}
    end
    getgenv().FH_BindState = BindState

    local touchGui=Instance.new("ScreenGui")
    touchGui.Name="FH_TouchBinds_v21"
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
    getgenv().FH_MakeTouchButton = makeTouchButton

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
            if typeof(k)=="EnumItem" then
                st.key=k
            else
                st.key=nil
            end
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
-- НАСТРОЙКИ (с фиксом биндов в конфигах)
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
    local function serializeValue(v)
        if typeof(v)=="Color3" then
            return string.format("C:%.6f,%.6f,%.6f", v.R, v.G, v.B)
        end
        if typeof(v)=="EnumItem" then
            if v.EnumType == Enum.KeyCode then
                return "K:"..v.Name
            end
            return "E:"..tostring(v.EnumType).."|"..v.Name
        end
        local t=type(v)
        if t=="number" then return "N:"..tostring(v) end
        if t=="boolean" then return "B:"..tostring(v) end
        if t=="string" then
            if Enum.KeyCode[v] then return "K:"..v end
            v = v:gsub("\n","\\n"):gsub("\t","\\t")
            return "S:"..v
        end
        if t=="table" then
            local isArray=true
            for k in pairs(v) do if type(k)~="number" then isArray=false break end end
            if isArray then
                local parts={}
                for i=1,#v do parts[#parts+1]=tostring(v[i]) end
                return "L:"..table.concat(parts,",")
            else
                local parts={}
                for k,val in pairs(v) do parts[#parts+1]=tostring(k).."="..tostring(val) end
                return "D:"..table.concat(parts,";")
            end
        end
        return nil
    end
    local function deserializeValue(s)
        local prefix,rest=string.match(s,"^(%a):(.*)$")
        if not prefix then return nil end
        if prefix=="K" then
            return Enum.KeyCode[rest]
        end
        if prefix=="C" then
            local r,g,b=string.match(rest,"([^,]+),([^,]+),([^,]+)")
            if r and g and b then return Color3.new(tonumber(r),tonumber(g),tonumber(b)) end
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
            return rest:gsub("\\n","\n"):gsub("\\t","\t")
        end
        if prefix=="L" then
            local out={}
            for piece in string.gmatch(rest,"[^,]+") do
                local n=tonumber(piece)
                if n then out[#out+1]=n else out[#out+1]=piece end
            end
            return out
        end
        if prefix=="D" then
            local out={}
            for pair in string.gmatch(rest,"[^;]+") do
                local k,val=string.match(pair,"^(.-)=(.*)$")
                if k then
                    local n=tonumber(val)
                    if n then out[k]=n
                    elseif val=="true" then out[k]=true
                    elseif val=="false" then out[k]=false
                    else out[k]=val end
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
        local loaded=0
        local bindLoaded=0
        local BS = getgenv().FH_BindState
        for line in string.gmatch(data,"[^\r\n]+") do
            if line:sub(1,2)~="--" then
                local key,ser=string.match(line,"^([^\t]+)\t(.+)$")
                if key and ser then
                    if key:sub(1,9)=="BIND_KEY_" then
                        local id = key:sub(10)
                        local enumVal = nil
                        if ser:sub(1,2)=="K:" then
                            local sname = ser:sub(3)
                            if Enum.KeyCode[sname] then enumVal = Enum.KeyCode[sname] end
                        elseif ser:sub(1,2)=="E:" then
                            local raw = ser:sub(3)
                            local enumType,keyName=string.match(raw,"^([^|]+)|(.+)$")
                            if enumType and keyName then
                                local et=Enum[enumType]
                                if et and et[keyName] then enumVal = et[keyName] end
                            end
                        elseif ser:sub(1,2)=="S:" then
                            local sname = ser:sub(3)
                            if Enum.KeyCode[sname] then enumVal = Enum.KeyCode[sname] end
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
                            pcall(function() Options[key]:SetValue(val) end)
                            fireRegistered(key, val)
                            loaded=loaded+1
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
-- ============================================================
-- FORTNIHUB v20.1 — EXTRA FEATURES — ЧАСТЬ 2/2 (FIXED)
-- ============================================================

if not (Window and Options and Notify and getRoundData and getRoleFromData and getHRP and getHum) then
    warn("[FH] Part 1 не загружена — Extra Part 2/2 пропущена.")
    return
end
local Tabs = getgenv().FH_Tabs
if not Tabs then warn("[FH] FH_Tabs не найден.") return end
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
-- 1. TRADE HELPER (ЗАГЛУШКА — по запросу)
-- ============================================================
do
    local thSec = Tabs.Visual:AddSection({Name="Trade Helper"})
    _addOpt(thSec, "AddToggle", "THOn", {Title="Trade Helper (временно отключён)", Default=false}, function(v)
        if v then
            Notify("FH", "Trade Helper временно отключён", 3)
            task.delay(0.3, function()
                local opt = Options.THOn
                if opt then pcall(function() opt:SetValue(false) end) end
            end)
        end
    end)
    thSec:AddButton({Title="Информация", Callback=function()
        Notify("FH", "Trade Helper в разработке. Следи за обновлениями.", 4)
    end})
end

-- ============================================================
-- 2. ADVANCED VOTE DUPER
-- ============================================================
do
    local selectedVotePad = nil
    local voteMapName = ""
    local voteDupeEnabled = false
    local DELAY_ON_PAD = 0.38
    local dupeThread = nil
    local dupeCounter = 0

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
    local function getVoteCount(pad)
        if not pad then return "" end
        local v = pad:FindFirstChild("VoteInfoGui", true)
        if v then v = v:FindFirstChild("Votes", true) end
        return safeText(v)
    end
    local function getMapIcon(pad)
        if not pad then return "" end
        local m = pad:FindFirstChild("MapInfoGui", true)
        local ic = m and m:FindFirstChild("MapIcon", true)
        if ic then return tostring(ic.Image or "") end
        return ""
    end
    local function collectPads()
        local lobby = Workspace:FindFirstChild("RegularLobby")
            or Workspace:FindFirstChild("SummerLobby")
            or Workspace:FindFirstChild("Lobby")
        if not lobby then return {} end
        local out = {}
        for _, nm in ipairs({"VotePad1","VotePad2","VotePad3"}) do
            local obj = lobby:FindFirstChild(nm)
            if obj and obj:FindFirstChild("Pad", true) and obj:FindFirstChild("MapInfoGui", true) and obj:FindFirstChild("VoteInfoGui", true) then
                table.insert(out, obj)
            end
        end
        if #out == 0 then
            local vp = lobby:FindFirstChild("VotePads")
            if vp then
                for _, child in ipairs(vp:GetChildren()) do
                    if child:FindFirstChild("Pad", true) and child:FindFirstChild("MapInfoGui", true) and child:FindFirstChild("VoteInfoGui", true) then
                        table.insert(out, child)
                    end
                end
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
                task.wait(0.3)
            else
                local char = LocalPlayer.Character
                local tries = 0
                while not char and voteDupeEnabled and dupeCounter == myToken and tries < 50 do
                    task.wait(0.1); char = LocalPlayer.Character; tries = tries + 1
                end
                if not char then break end
                local hrp = char:WaitForChild("HumanoidRootPart", 5)
                local hum = char:WaitForChild("Humanoid", 5)
                if not (hrp and hum and hum.Health > 0) then task.wait(0.2) else
                    local cf = getVotePadCFrame()
                    if cf then
                        pcall(function() char:PivotTo(cf * CFrame.new(0, 1.5, 0)) end)
                        task.wait(DELAY_ON_PAD)
                        if voteDupeEnabled and dupeCounter == myToken and getVoteGuiVisible() and hum.Health > 0 then
                            hum.Health = 0
                            char:BreakJoints()
                            local tries2 = 0
                            while LocalPlayer.Character and voteDupeEnabled and dupeCounter == myToken and tries2 < 50 do
                                task.wait(0.1); tries2 = tries2 + 1
                            end
                            task.wait(0.05)
                        end
                    else
                        task.wait(0.2)
                    end
                end
            end
        end
        if dupeCounter == myToken then
            dupeThread = nil
            if voteDupeEnabled then
                voteDupeEnabled = false
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
        local t = task.spawn(dupeLoop)
        dupeThread = t
    end
    local function stopDupe()
        voteDupeEnabled = false
        dupeCounter = dupeCounter + 1
        if dupeThread then
            pcall(task.cancel, dupeThread)
            dupeThread = nil
        end
    end

    local thSec = Tabs.Troll:AddSection({Name="Vote Duper (Advanced)"})
    _addOpt(thSec, "AddToggle", "THVoteDuper", {Title="Vote Duper", Default=false}, function(v)
        voteDupeEnabled = v
        if v then
            if not selectedVotePad then
                local pads = collectPads()
                if #pads > 0 then selectedVotePad = pads[1] end
            end
            startDupe()
            Notify("FH", "Vote Duper ВКЛ", 2)
        else
            stopDupe()
            Notify("FH", "Vote Duper ВЫКЛ", 2)
        end
    end)
    _addOpt(thSec, "AddSlider", "THDupeDelay", {Title="Задержка на пэде (сек)", Min=0.1, Max=1.5, Default=0.38, Rounding=2}, function(v)
        DELAY_ON_PAD = tonumber(v) or 0.38
    end)

    local padNames = {}
    local padRefs = {}
    local function refreshPads()
        local pads = collectPads()
        padRefs = pads
        padNames = {}
        for i, p in ipairs(pads) do
            local n = getVoteMapName(p)
            if n == "" then n = "Pad "..i end
            padNames[i] = n
        end
        if #padNames == 0 then padNames = {"(нет пэдов)"} end
        local drop = Options.THPadPick
        if drop then pcall(function() drop:SetValues(padNames); drop:Generate() end) end
    end
    _addOpt(thSec, "AddDropdown", "THPadPick", {Title="Пэд для голосования", Values={"Pad 1","Pad 2","Pad 3"}, Default="Pad 1"}, function(v)
        for i, name in ipairs(padNames) do
            if name == v then
                selectedVotePad = padRefs[i]
                voteMapName = getVoteMapName(selectedVotePad)
                Notify("FH", "Пэд выбран: "..voteMapName, 2)
                return
            end
        end
    end)
    thSec:AddButton({Title="Обновить список пэдов", Callback=function()
        refreshPads()
        Notify("FH", "Пэды обновлены", 2)
    end})
    task.spawn(function()
        while true do
            task.wait(3)
            if #padRefs > 0 then
                local anyOK = false
                for _, p in ipairs(padRefs) do
                    if p and p.Parent then anyOK = true; break end
                end
                if not anyOK then refreshPads() end
            else
                refreshPads()
            end
        end
    end)
    refreshPads()
end

-- ============================================================
-- 3. BIG EMOTE LIST
-- ============================================================
do
    local emoteTab = Tabs.Animations
    local emoteSec = emoteTab:AddSection({Name="Эмоции (расширенные)"})

    local EMOTE_LIST = {
        ["Around Town"]=3576747102, ["Fashionable"]=3576745472, ["Swish"]=3821527813,
        ["Top Rock"]=3570535774, ["Fancy Feet"]=3934988903, ["Idol"]=4102317848,
        ["Sneaky"]=3576754235, ["Robot"]=3576721660, ["Louder"]=3576751796,
        ["Twirl"]=3716633898, ["Bodybuilder"]=3994130516, ["Jacks"]=3570649048,
        ["Shuffle"]=4391208058, ["Dorky Dance"]=4212499637, ["Dizzy"]=3934986896,
        ["T"]=3576719440, ["Air Dance"]=4646302011, ["TMNT Dance"]=18665886405,
        ["Line Dance"]=4049646104, ["Break Dance"]=5915773992, ["Zombie"]=4212496830,
        ["Baby Dance"]=4272484885, ["Cha Cha"]=6865013133, ["Dolphin Dance"]=5938365243,
        ["Y"]=4391211308, ["Wanna play?"]=16646438742, ["Samba"]=6869813008,
        ["Side to Side"]=3762641826, ["Tree"]=4049634387, ["Godlike"]=3823158750,
        ["Keeping Time"]=4646306072, ["Tantrum"]=5104374556, ["Rock On"]=5915782672,
        ["Hero Landing"]=5104377791, ["Fishing"]=3994129128, ["Floss Dance"]=5917570207,
        ["Get Out"]=3934984583, ["Victory Dance"]=15506503658, ["Monkey"]=3716636630,
        ["Greatest"]=3762654854, ["Jumping Wave"]=4940602656, ["Haha"]=4102315500,
        ["Agree"]=4849487550, ["Mini Kong"]=17000058939, ["Festive Dance"]=15679955281,
        ["Jumping Cheer"]=5895009708, ["Sleep"]=4689362868, ["Disagree"]=4849495710,
        ["Happy"]=4849499887, ["Bored"]=5230661597, ["High Wave"]=5915776835,
        ["Cower"]=4940597758, ["Rock n Roll"]=15506496093, ["Shy"]=3576717965,
        ["Curtsy"]=4646306583, ["Celebrate"]=3994127840, ["Confused"]=4940592718,
        ["Beckon"]=5230615437, ["Sad"]=4849502101, ["Cha-Cha"]=3696764866,
        ["Chicken Dance"]=4849493309, ["Sandwich Dance"]=4390121879, ["Salute"]=3360689775,
        ["Stadium"]=3360686498, ["Bunny Hop"]=4646296016, ["Swag Walk"]=10478377385,
        ["Superhero Reveal"]=3696759798, ["Hype Dance"]=3696757129, ["Heisman Pose"]=3696763549,
        ["Point2"]=3576823880, ["Vroom Vroom"]=18526410572, ["Tilt"]=3360692915,
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
        ["SpongeBob Shuffle"]=107899954696611, ["Electro Shuffle"]=96426537876059,
        ["Foreign Shuffle"]=101507732056031, ["Caipirinha"]=100165303717371,
        ["Squidward Yell"]=109244554368414, ["Teto Dance"]=93031502567721,
        ["Michael Myers"]=88229016850146, ["Torture Dance"]=116099356619436,
        ["Mewing / Mogging"]=135493514352956, ["Cute Jump"]=80556794144838,
        ["Billy Bounce"]=126516908191316, ["Dio Pose"]=76736978166708,
        ["Golden Freddy"]=122463450997235, ["Lethal Dance"]=77108921633993,
        ["Plug Walk"]=100359724990859, ["At Ease"]=76993139936388,
        ["Conga"]=97547955535086, ["Barrel"]=84511772437190,
        ["Helicopter"]=84555218084038, ["Jersey Joe2"]=115782117564871,
        ["California Girl"]=132074413582912, ["Shocked meme"]=129501229484294,
        ["Car Transformation"]=96887377943085, ["Insanity"]=129843344424281,
        ["Honored One"]=121643381580730, ["Sukuna"]=91839607010745,
        ["Dropper"]=130358790702800, ["Be Not Afraid"]=70635223083942,
        ["Helicopter2"]=119431985170060, ["Nya Anime Dance"]=126647057611522,
        ["Do that thang"]=113772829398170, ["Squat?"]=95441477641149,
    }

    local emoteNames = {}
    for name in pairs(EMOTE_LIST) do emoteNames[#emoteNames+1] = name end
    table.sort(emoteNames, function(a,b) return a:lower() < b:lower() end)

    local searchInput = emoteSec:AddInput("FHBigEmoteSearch", {Title="Поиск эмоции", Default=""})
    local drop = emoteSec:AddDropdown("FHBigEmotePick", {
        Title="Выбрать эмоцию",
        Values=emoteNames,
        Default=emoteNames[1] or "Default Dance",
    })

    local currentTrack = nil
    local currentName = nil
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
            currentName = name
            Notify("FH", "Эмоция: "..name, 2)
        else
            Notify("FH", "Не удалось запустить: "..name, 2)
        end
    end

    emoteSec:AddButton({Title="Запустить эмоцию", Callback=function()
        local v = drop.Value
        if type(v) == "table" then v = v[1] end
        if type(v) == "string" then playEmoteByName(v) end
    end})
    emoteSec:AddButton({Title="Остановить эмоцию", Callback=function()
        stopCurrent()
        Notify("FH","Эмоция остановлена", 2)
    end})

    _addOpt(emoteSec, "AddInput", "FHBigEmoteSearchReal", {
        Title = "Строка поиска",
        Default = "",
    }, function(v)
        local q = tostring(v or ""):lower()
        local filtered = {}
        if q == "" then
            filtered = emoteNames
        else
            for _, n in ipairs(emoteNames) do
                if n:lower():find(q, 1, true) then filtered[#filtered+1] = n end
            end
            if #filtered == 0 then filtered = {"(ничего не найдено)"} end
        end
        pcall(function() drop:SetValues(filtered); drop:Generate() end)
    end)

    local favorites = {}
    local favFile = "FortniHub_Configs/emote_favorites.txt"
    local function saveFav()
        if type(writefile) ~= "function" then return end
        local lines = {}
        for k in pairs(favorites) do lines[#lines+1] = k end
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
    emoteSec:AddButton({Title="Добавить/убрать из избранного", Callback=function()
        local v = drop.Value
        if type(v)=="table" then v=v[1] end
        if type(v)~="string" or v=="" then return end
        favorites[v] = not favorites[v] or nil
        saveFav()
        Notify("FH", favorites[v] and ("Добавлено: "..v) or ("Удалено: "..v), 2)
    end})
    emoteSec:AddButton({Title="Показать избранное", Callback=function()
        local list = {}
        for k in pairs(favorites) do list[#list+1] = k end
        if #list == 0 then
            Notify("FH", "Избранное пусто", 2)
        else
            table.sort(list)
            pcall(function() drop:SetValues(list); drop:Generate() end)
            Notify("FH", "Показано "..#list.." избранных", 2)
        end
    end})
end

-- ============================================================
-- 4. WATER PROTECTION
-- ============================================================
do
    local offDamageWater = false
    local disabledConnections = {}
    local modifiedWaterParts = {}

    local function isWater(instance)
        if not instance then return false end
        local n = instance.Name:lower()
        if n:find("water") or n:find("river") or n:find("ocean") then return true end
        if instance:FindFirstChild("Splash") or instance:FindFirstChild("HitWater") then return true end
        return false
    end
    local function neutralize(instance)
        if not instance or not instance:IsA("BasePart") then return end
        if modifiedWaterParts[instance] == nil then
            modifiedWaterParts[instance] = instance.CanTouch
        end
        instance.CanTouch = false
        if getconnections then
            pcall(function()
                for _, c in ipairs(getconnections(instance.Touched)) do
                    c:Disable()
                    table.insert(disabledConnections, c)
                end
            end)
        end
    end
    local function applyAll()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local p = d
                while p and p ~= Workspace do
                    if isWater(p) then
                        neutralize(d)
                        break
                    end
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
        for _, c in ipairs(disabledConnections) do
            pcall(function() c:Enable() end)
        end
        table.clear(disabledConnections)
    end
    Workspace.DescendantAdded:Connect(function(d)
        if offDamageWater and d:IsA("BasePart") then
            task.spawn(function()
                task.wait()
                local p = d
                while p and p ~= Workspace do
                    if isWater(p) then neutralize(d); break end
                    p = p.Parent
                end
            end)
        end
    end)

    local utilsSec = Tabs.Utility:AddSection({Name="Water Protection"})
    _addOpt(utilsSec, "AddToggle", "WaterProtOn", {Title="Off Damage Water", Default=false}, function(v)
        offDamageWater = v
        if v then
            applyAll()
            Notify("FH", "Защита от воды ВКЛ", 2)
        else
            restoreAll()
            Notify("FH", "Защита от воды ВЫКЛ", 2)
        end
    end)
end

-- ============================================================
-- 5. FADE DISABLER (расширенный)
-- ============================================================
do
    local savedFadeGuis = ReplicatedStorage:FindFirstChild("FH_SavedFadeGuis")
    if not savedFadeGuis then
        savedFadeGuis = Instance.new("Folder")
        savedFadeGuis.Name = "FH_SavedFadeGuis"
        savedFadeGuis.Parent = ReplicatedStorage
    end
    local fadeNames = {CameraFade=true, Fade=true, SpawnFade=true, DeathFade=true}
    local tracked = {}
    local conn = nil

    local function handle(obj)
        if not obj or not obj:IsDescendantOf(game) then return end
        if obj:IsDescendantOf(savedFadeGuis) then return end
        if fadeNames[obj.Name] then
            if not tracked[obj] then tracked[obj] = obj.Parent end
            obj.Parent = savedFadeGuis
        end
    end
    local function apply()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, d in ipairs(pg:GetDescendants()) do handle(d) end
        if not conn then
            conn = pg.DescendantAdded:Connect(handle)
        end
    end
    local function restore()
        if conn then conn:Disconnect(); conn = nil end
        for obj, parent in pairs(tracked) do
            if obj and obj.Parent == savedFadeGuis then
                if parent and parent:IsDescendantOf(game) then
                    obj.Parent = parent
                else
                    local pg = LocalPlayer:FindFirstChild("PlayerGui")
                    if pg then obj.Parent = pg end
                end
            end
        end
        table.clear(tracked)
    end

    local utilsSec = Tabs.Utility:AddSection({Name="Fade Disabler"})
    _addOpt(utilsSec, "AddToggle", "FadeDisablerOn", {Title="Убрать чёрный экран", Default=false}, function(v)
        if v then
            apply()
            Notify("FH", "Fade Disabler ВКЛ", 2)
        else
            restore()
            Notify("FH", "Fade Disabler ВЫКЛ", 2)
        end
    end)
end

-- ============================================================
-- 6. ANTI-COIN
-- ============================================================
do
    local antiCoinOn = false
    local saved = {}
    local function hideCoin(part)
        if not saved[part] then
            saved[part] = {CanTouch = part.CanTouch, CanCollide = part.CanCollide, Transparency = part.Transparency}
        end
        part.CanTouch = false
        part.CanCollide = false
        part.Transparency = 1
    end
    local function scan()
        local m2 = Workspace:FindFirstChild("Mansion2")
        if m2 then m2 = m2:FindFirstChild("CoinContainer") end
        if not m2 then
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("Model") and d.Name:lower():find("coin") then
                    for _, p in ipairs(d:GetDescendants()) do
                        if p:IsA("BasePart") then hideCoin(p) end
                    end
                end
            end
        else
            for _, d in ipairs(m2:GetDescendants()) do
                if d:IsA("BasePart") then hideCoin(d) end
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

    local utilsSec = Tabs.Utility:AddSection({Name="Anti-Coin"})
    _addOpt(utilsSec, "AddToggle", "AntiCoinOn", {Title="Скрыть монеты", Default=false}, function(v)
        antiCoinOn = v
        if v then
            task.spawn(function()
                while antiCoinOn do
                    pcall(scan)
                    task.wait(0.5)
                end
            end)
            Notify("FH", "Anti-Coin ВКЛ", 2)
        else
            restore()
            Notify("FH", "Anti-Coin ВЫКЛ", 2)
        end
    end)
end

-- ============================================================
-- 7. CUSTOM GUN MODELS (CFrame)
-- ============================================================
do
    local gunModelCache = {}
    local customModelEnabled = false
    local selectedModelName = "AWP"
    local KITI_Models = {}

    do local a = {id = "4531395275"}; a.rot = CFrame.Angles(0, 0, 0); a.pos = CFrame.new(0, 0, -0.5); KITI_Models.AWP = a end
    do local a = {id = "5102714039"}; a.rot = CFrame.Angles(0, math.pi, 0); a.pos = CFrame.new(0, 0, 0.5); KITI_Models.Pistol = a end
    do local a = {id = "5294131243"}; a.rot = CFrame.Angles(0, math.pi, 0); a.pos = CFrame.new(0, 0, 0.8); KITI_Models.Shotgun = a end
    do local a = {id = "542699703"}; a.rot = CFrame.Angles(0, math.pi, 0); a.pos = CFrame.new(0, 0, 0.2); KITI_Models.RayGun = a end
    do local a = {id = "127200798279812"}; a.rot = CFrame.Angles(math.pi/2, 0, -math.pi/2); a.pos = CFrame.new(0, -0.3, 0.3); KITI_Models["AK-47"] = a end
    do local a = {id = "18610978709"}; a.rot = CFrame.Angles(0, 0, 0); a.pos = CFrame.new(0, 0, -0.3); KITI_Models.PinkGun = a end
    do local a = {id = "10656806096"}; a.rot = CFrame.Angles(-math.pi/2, math.pi/2, math.pi/2); a.pos = CFrame.new(2.1, 0, -0.3); KITI_Models.FlameGun = a end
    do local a = {id = "62932622"}; a.rot = CFrame.Angles(math.pi/2, 0, 0); a.pos = CFrame.new(0, 0, 0); KITI_Models.MiniBlackGun = a end
    do local a = {id = "87594143804300"}; a.rot = CFrame.Angles(-math.pi/2, math.pi/2, math.pi/2); a.pos = CFrame.new(0, -0.3, 0.5); KITI_Models.BlueGun = a end
    do local a = {id = "12899296613"}; a.rot = CFrame.Angles(0, 0, 0); a.pos = CFrame.new(0, 0, -1.3); KITI_Models["BigUSP-S"] = a end
    do local a = {id = "1297856838"}; a.rot = CFrame.Angles(math.pi/2, 0, 0); a.pos = CFrame.new(0, -0.3, 0); KITI_Models.GreenGun = a end

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
        if not customModelEnabled then restoreGun(tool); return end
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
            if d:IsA("BasePart") and not d:IsDescendantOf(model) then d.Transparency = 1
            elseif (d:IsA("Decal") or d:IsA("Texture")) and not d:IsDescendantOf(model) then d.Transparency = 1 end
        end
        local anchorPart = nil
        if model:IsA("BasePart") then anchorPart = model
        elseif model.PrimaryPart then anchorPart = model.PrimaryPart
        elseif model:FindFirstChild("Handle") then anchorPart = model.Handle
        else anchorPart = model:FindFirstChildWhichIsA("BasePart", true) end
        if not anchorPart then model:Destroy(); return end
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
            baseOffset = CFrame.new(0, -0.25, -0.1) * CFrame.Angles(-math.pi/2, 0, 0)
        else
            baseOffset = CFrame.new(0, -1, -0.1) * CFrame.Angles(-math.pi/2, 0, 0)
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
            if g then if customModelEnabled then applyGun(g) else restoreGun(g) end end
        end
        local char = LocalPlayer.Character
        if char then
            local g = char:FindFirstChild("Gun")
            if g then if customModelEnabled then applyGun(g) else restoreGun(g) end end
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
                if customModelEnabled and child.Parent == LocalPlayer.Character then
                    applyGun(child)
                end
            end
        end)
        local g = cont:FindFirstChild("Gun")
        if g then
            g.Equipped:Connect(function()
                if customModelEnabled then
                    task.wait(0.02)
                    applyGun(g)
                end
            end)
            g.Unequipped:Connect(function()
                local old = g:FindFirstChild("FH_CustomGunModel")
                if old then old:Destroy() end
            end)
            if customModelEnabled and g.Parent == LocalPlayer.Character then
                applyGun(g)
            end
        end
    end
    task.spawn(function()
        local bp = LocalPlayer:WaitForChild("Backpack")
        if bp then hookContainer(bp) end
        if LocalPlayer.Character then hookContainer(LocalPlayer.Character) end
        LocalPlayer.CharacterAdded:Connect(hookContainer)
    end)

    local sec = Tabs.Visual:AddSection({Name="Custom Gun Models (CFrame)"})
    _addOpt(sec, "AddToggle", "FHGunModelOn", {Title="Заменить модель оружия", Default=false}, function(v)
        customModelEnabled = v
        refreshAll()
        Notify("FH", v and "Модель оружия ВКЛ" or "Модель оружия ВЫКЛ", 2)
    end)
    _addOpt(sec, "AddDropdown", "FHGunModelPick", {Title="Модель", Values=MODEL_LIST, Default="AWP"}, function(v)
        selectedModelName = v or "AWP"
        if customModelEnabled then refreshAll() end
    end)
    sec:AddButton({Title="Применить к текущему оружию", Callback=function()
        refreshAll()
        Notify("FH", "Обновлено", 2)
    end})
end

-- ============================================================
-- 8. BEAM EFFECTS
-- ============================================================
do
    local BeamCfg = {Type = "Default", Color = Color3.fromRGB(0, 240, 255)}
    getgenv().FH_BeamCfg = BeamCfg
    local function beamColor() return BeamCfg.Color or Color3.fromRGB(0, 240, 255) end
    local function makeCyl(p1, p2, thickness, color)
        local len = (p2 - p1).Magnitude
        if len < 1 then return end
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = color or beamColor()
        part.Shape = Enum.PartType.Cylinder
        part.Size = Vector3.new(len, thickness, thickness)
        part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -len/2) * CFrame.Angles(0, math.pi/2, 0)
        part.Parent = workspace.Terrain
        TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = Vector3.new(len, 0, 0), Transparency = 1
        }):Play()
        task.delay(0.25, function() part:Destroy() end)
    end
    local function makeImpact(pos, dir, color)
        local ball = Instance.new("Part")
        ball.Shape = Enum.PartType.Ball
        ball.Material = Enum.Material.Neon
        ball.Color = color or beamColor()
        ball.Size = Vector3.new(0.4, 0.4, 0.4)
        ball.Position = pos
        ball.Anchored = true
        ball.CanCollide = false
        ball.Parent = workspace.Terrain
        local burst = Instance.new("Part")
        burst.Shape = Enum.PartType.Cylinder
        burst.Material = Enum.Material.Neon
        burst.Color = Color3.fromRGB(255, 255, 255)
        burst.Size = Vector3.new(0.1, 0.4, 0.4)
        burst.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi/2, 0)
        burst.Anchored = true
        burst.CanCollide = false
        burst.Parent = workspace.Terrain
        local light = Instance.new("PointLight")
        light.Color = color or beamColor()
        light.Range = 16
        light.Brightness = 3.5
        light.Parent = ball
        local info = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
        TweenService:Create(ball, info, {Size = Vector3.new(8, 8, 8), Transparency = 1}):Play()
        TweenService:Create(burst, info, {Size = Vector3.new(0.1, 15, 15), Transparency = 1}):Play()
        TweenService:Create(light, info, {Brightness = 0, Range = 0}):Play()
        task.delay(1.2, function() ball:Destroy(); burst:Destroy() end)
    end
    local function makeZigzag(p1, p2, color)
        local len = (p2 - p1).Magnitude
        local segs = math.clamp(math.floor(len / 6), 4, 12)
        local prev = p1
        for i = 1, segs do
            local cur = p1:Lerp(p2, i / segs)
            if i < segs then
                cur = cur + Vector3.new(math.random(-2, 2), math.random(-2, 2), math.random(-2, 2))
            end
            makeCyl(prev, cur, 0.4, color)
            prev = cur
        end
    end
    local function makeOrbital(pos, color)
        local top = pos + Vector3.new(0, 100, 0)
        local part = Instance.new("Part")
        part.Shape = Enum.PartType.Cylinder
        part.Material = Enum.Material.Neon
        part.Color = color or beamColor()
        part.Size = Vector3.new(100, 2.5, 2.5)
        part.CFrame = CFrame.lookAt(top, pos) * CFrame.new(0, 0, -50) * CFrame.Angles(0, math.pi/2, 0)
        part.Anchored = true
        part.CanCollide = false
        part.Parent = workspace.Terrain
        local light = Instance.new("PointLight")
        light.Color = color or beamColor()
        light.Range = 25
        light.Brightness = 5
        light.Parent = part
        local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(part, info, {Size = Vector3.new(100, 0, 0), Transparency = 1}):Play()
        TweenService:Create(light, info, {Brightness = 0, Range = 0}):Play()
        task.delay(0.42, function() part:Destroy() end)
    end
    local function makeBlackHole(pos)
        local dark = Instance.new("Part")
        dark.Shape = Enum.PartType.Ball
        dark.Material = Enum.Material.SmoothPlastic
        dark.Color = Color3.fromRGB(10, 10, 15)
        dark.Size = Vector3.new(0.2, 0.2, 0.2)
        dark.Position = pos
        dark.Anchored = true
        dark.CanCollide = false
        dark.Parent = workspace.Terrain
        local glow = Instance.new("Part")
        glow.Shape = Enum.PartType.Ball
        glow.Material = Enum.Material.Neon
        glow.Color = beamColor()
        glow.Size = Vector3.new(0.3, 0.3, 0.3)
        glow.Position = pos
        glow.Anchored = true
        glow.CanCollide = false
        glow.Parent = workspace.Terrain
        local light = Instance.new("PointLight")
        light.Color = beamColor()
        light.Range = 14
        light.Brightness = 3
        light.Parent = glow
        local i1 = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        local i2 = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(dark, i1, {Size = Vector3.new(4, 4, 4)}):Play()
        TweenService:Create(glow, i1, {Size = Vector3.new(5.5, 5.5, 5.5)}):Play()
        task.delay(0.3, function()
            TweenService:Create(dark, i2, {Size = Vector3.new(0, 0, 0), Transparency = 1}):Play()
            TweenService:Create(glow, i2, {Size = Vector3.new(0, 0, 0), Transparency = 1}):Play()
            TweenService:Create(light, i2, {Brightness = 0, Range = 0}):Play()
            task.delay(0.52, function() dark:Destroy(); glow:Destroy() end)
        end)
    end
    local function processBeam(beam)
        if not beam:IsA("Beam") then return end
        if BeamCfg.Type == "Default" then return end
        local a0, a1 = beam.Attachment0, beam.Attachment1
        if not a0 or not a1 then return end
        local p1, p2 = a0.WorldPosition, a1.WorldPosition
        local dir = (p2 - p1).Unit
        local t = BeamCfg.Type
        if t == "Neon Fat" then
            beam.Width0 = 1.8; beam.Width1 = 1.2
            beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),ColorSequenceKeypoint.new(0.2, beamColor()),ColorSequenceKeypoint.new(1, beamColor())})
            makeCyl(p1, p2, 1.0)
        elseif t == "Nuke" then
            beam.Width0 = 1.4; beam.Width1 = 0.8
            beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),ColorSequenceKeypoint.new(0.1, beamColor()),ColorSequenceKeypoint.new(1, beamColor())})
            makeCyl(p1, p2, 0.8); makeImpact(p2, dir)
        elseif t == "Zigzag Light" then
            beam.Width0 = 0.1; beam.Width1 = 0.1
            makeZigzag(p1, p2)
        elseif t == "Orbital Strike" then
            beam.Width0 = 1.5; beam.Width1 = 0.8
            beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),ColorSequenceKeypoint.new(0.2, beamColor()),ColorSequenceKeypoint.new(1, beamColor())})
            makeCyl(p1, p2, 0.8); makeOrbital(p2)
        elseif t == "Black Hole" then
            beam.Width0 = 1.2; beam.Width1 = 0.6
            beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),ColorSequenceKeypoint.new(0.2, beamColor()),ColorSequenceKeypoint.new(1, beamColor())})
            makeCyl(p1, p2, 0.7); makeBlackHole(p2)
        elseif t == "Rainbow RGB" then
            beam.Width0 = 1.8; beam.Width1 = 1.2
            beam.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 255, 0)),ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 255, 255)),ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))})
            makeCyl(p1, p2, 1.0, Color3.fromRGB(255, 255, 255))
        end
    end
    Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Beam") and BeamCfg.Type ~= "Default" then
            task.wait()
            pcall(processBeam, d)
        end
    end)
    task.spawn(function()
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Beam") and BeamCfg.Type ~= "Default" then
                pcall(processBeam, d)
                task.wait()
            end
        end
    end)
    local sec = Tabs.Effects:AddSection({Name="Gun Beam Effects"})
    _addOpt(sec, "AddDropdown", "FHBeamType", {Title="Тип луча", Values={"Default", "Neon Fat", "Nuke", "Zigzag Light", "Orbital Strike", "Black Hole", "Rainbow RGB"}, Default="Default"}, function(v)
        BeamCfg.Type = v or "Default"
        if BeamCfg.Type ~= "Default" then
            task.spawn(function()
                for _, d in ipairs(Workspace:GetDescendants()) do
                    if d:IsA("Beam") then pcall(processBeam, d); task.wait() end
                end
            end)
        end
        Notify("FH", "Beam: "..BeamCfg.Type, 2)
    end)
    _addOpt(sec, "AddColorPicker", "FHBeamColor", {Title="Цвет луча", Default=Color3.fromRGB(0, 240, 255)}, function(c)
        BeamCfg.Color = c
    end)
end

-- ============================================================
-- 9. SKYBOX MANAGER
-- ============================================================
do
    local skyboxEnabled = false
    local currentSkyId = nil
    local currentSkyName = nil

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
                Notify("FH", "Sky не найден в модели", 3)
                return
            end
            local existing = Lighting:FindFirstChildOfClass("Sky")
            if existing then existing:Destroy() end
            Lighting.ClockTime = 14
            Lighting.Brightness = 0.5
            sky.Name = "FH_SkyboxManaged"
            sky.Parent = Lighting
            if first ~= sky then pcall(function() first:Destroy() end) end
            skyboxEnabled = true
            currentSkyId = id
            currentSkyName = name
            Notify("FH", "Skybox: "..tostring(name), 2)
        end)
    end
    local function removeSky()
        destroySky()
        skyboxEnabled = false
        currentSkyId = nil
        currentSkyName = nil
        Notify("FH", "Skybox удалён", 2)
    end

    local sec = Tabs.Effects:AddSection({Name="Skybox Manager"})
    sec:AddButton({Title="Убрать небо", Callback=removeSky})
    sec:AddButton({Title="Snow Skybox", Callback=function() applySkybox(4604073339, "Snow") end})
    sec:AddButton({Title="Realistic Space", Callback=function() applySkybox(136402262, "Realistic Space") end})
    sec:AddButton({Title="Purple Nebula", Callback=function() applySkybox(83555979203508, "Purple Nebula") end})
    sec:AddButton({Title="Blue Nebula", Callback=function() applySkybox(130093177270069, "Blue Nebula") end})
    sec:AddButton({Title="SpongeBob Sky", Callback=function() applySkybox(114523453023009, "SpongeBob") end})
    sec:AddButton({Title="Night Sky Vibe", Callback=function() applySkybox(78613024128163, "Night Sky") end})
    sec:AddButton({Title="Geoz Skybox", Callback=function() applySkybox(97573261671957, "Geoz") end})
    sec:AddButton({Title="Asteroid Space", Callback=function() applySkybox(295604372, "Asteroid") end})
    local input = sec:AddInput("FHSkyboxCustomId", {Title="Свой Skybox ID", Default=""})
    sec:AddButton({Title="Применить свой ID", Callback=function()
        local v = input.Value
        if type(v)=="table" then v=v[1] end
        local num = tonumber(v)
        if num then applySkybox(num, "Custom #"..num)
        else Notify("FH", "Введи число", 2) end
    end})
end

-- ============================================================
-- 10. ADVANCED AURAS
-- ============================================================
do
    local activeAura = nil
    local activeAuraName = nil
    local pendingAura = nil

    local function clearAura()
        if activeAura then
            for _, obj in ipairs(activeAura) do
                if obj and obj.Parent then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
        activeAura = nil
        activeAuraName = nil
    end
    local function applyAura(assetId, name)
        if activeAuraName == name then
            clearAura()
            pendingAura = nil
            Notify("FH", name.." выключена", 2)
            return
        end
        clearAura()
        local ok, objs = pcall(function() return game:GetObjects("rbxassetid://"..tostring(assetId)) end)
        if not ok or type(objs) ~= "table" or #objs == 0 then
            Notify("FH", "Не удалось загрузить ауру: "..name, 3)
            return
        end
        local model = objs[1]
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
                d:Destroy()
            elseif d:IsA("ParticleEmitter") then
                d.LightEmission = 1
                d.Rate = math.clamp(d.Rate * 0.35, 1, 40)
                pcall(function()
                    local kps = {}
                    for _, k in ipairs(d.Transparency.Keypoints) do
                        local v = math.clamp(k.Value + (1 - k.Value) * 0.45, 0.3, 1)
                        table.insert(kps, NumberSequenceKeypoint.new(k.Time, v, k.Envelope))
                    end
                    d.Transparency = NumberSequence.new(kps)
                end)
            elseif d:IsA("Beam") then
                d.LightEmission = 1
                pcall(function()
                    local kps = {}
                    for _, k in ipairs(d.Transparency.Keypoints) do
                        local v = math.clamp(k.Value + (1 - k.Value) * 0.4, 0.25, 1)
                        table.insert(kps, NumberSequenceKeypoint.new(k.Time, v, k.Envelope))
                    end
                    d.Transparency = NumberSequence.new(kps)
                end)
            elseif d:IsA("BasePart") then
                if d.Material == Enum.Material.Neon then
                    d.Transparency = math.max(d.Transparency, 0.5)
                end
            end
        end
        local char = LocalPlayer.Character
        if not char then
            Notify("FH", "Персонаж не загружен", 2)
            return
        end
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        local head = char:FindFirstChild("Head")
        if not torso or not head then
            Notify("FH", "Части персонажа не найдены", 2)
            return
        end
        local nameMap = {
            Torso = torso.Name, Head = "Head",
            ["Left Arm"] = "LeftUpperArm", ["Right Arm"] = "RightUpperArm",
            ["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg",
        }
        local tracked = {}
        local multiplier = (name == "Red Shield") and 4 or 1

        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Anchored = false
                part.CanCollide = false
            elseif part:IsA("Weld") or part:IsA("WeldConstraint") or part:IsA("Motor6D") or part:IsA("Snap") then
                part:Destroy()
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
                    if cl:IsA("ParticleEmitter") then
                        local lt = cl.Lifetime
                        cl.Lifetime = NumberRange.new(lt.Min * multiplier, lt.Max * multiplier)
                    end
                    cl.Parent = torso
                    table.insert(tracked, cl)
                end
            end
        end
        for _, part in ipairs(model:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "Aura" then
                local target = char:FindFirstChild(nameMap[part.Name] or part.Name)
                if target then
                    for _, ch in ipairs(part:GetChildren()) do
                        if ch:IsA("ParticleEmitter") or ch:IsA("Attachment") or ch:IsA("Highlight") then
                            local cl = ch:Clone()
                            if cl:IsA("ParticleEmitter") then
                                local lt = cl.Lifetime
                                cl.Lifetime = NumberRange.new(lt.Min * multiplier, lt.Max * multiplier)
                            end
                            cl.Parent = target
                            table.insert(tracked, cl)
                        end
                    end
                end
            end
        end
        local crownBase = model:FindFirstChild("Crown Base")
        if crownBase and name == "Crimson King" then
            crownBase.Parent = char
            crownBase.CFrame = head.CFrame * CFrame.new(0, 1.5, 0)
            local w = Instance.new("WeldConstraint")
            w.Part0 = head
            w.Part1 = crownBase
            w.Parent = crownBase
            table.insert(tracked, w)
            table.insert(tracked, crownBase)
            local cb = crownBase:FindFirstChild("Crown Beams")
            if cb then
                for _, d in ipairs(cb:GetDescendants()) do
                    if d:IsA("Beam") then
                        local cl = d:Clone()
                        if cl.Attachment0 and crownBase:FindFirstChild(cl.Attachment0.Name) then
                            cl.Attachment0 = crownBase[cl.Attachment0.Name]
                        end
                        if cl.Attachment1 and crownBase:FindFirstChild(cl.Attachment1.Name) then
                            cl.Attachment1 = crownBase[cl.Attachment1.Name]
                        end
                        cl.Parent = torso
                        table.insert(tracked, cl)
                    end
                end
            end
        end
        for _, d in ipairs(model:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Beam") or d:IsA("Attachment") then
                local cl = d:Clone()
                if cl:IsA("Beam") then
                    if cl.Attachment0 and torso:FindFirstChild(cl.Attachment0.Name) then
                        cl.Attachment0 = torso[cl.Attachment0.Name]
                    end
                    if cl.Attachment1 and torso:FindFirstChild(cl.Attachment1.Name) then
                        cl.Attachment1 = torso[cl.Attachment1.Name]
                    end
                end
                if cl:IsA("ParticleEmitter") then
                    local lt = cl.Lifetime
                    cl.Lifetime = NumberRange.new(lt.Min * multiplier, lt.Max * multiplier)
                    if name == "Red Shield" then cl.LockedToPart = true end
                end
                cl.Parent = torso
                table.insert(tracked, cl)
            end
        end
        model:Destroy()
        activeAura = tracked
        activeAuraName = name
        pendingAura = {assetId = assetId, name = name}
        Notify("FH", name.." включена", 2)
    end
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if pendingAura and not activeAura then
            task.wait(0.3)
            applyAura(pendingAura.assetId, pendingAura.name)
        end
    end)

    local sec = Tabs.Effects:AddSection({Name="Auras (расширенные)"})
    local AURAS = {
        {"Midnight Blues", "12002206611"},
        {"Rainbow Effect", "8509695714"},
        {"Red Shield", "14598330167"},
        {"Crimson King", "11955208820"},
        {"Daemon of Cards", "10373359918"},
        {"Angel Wings", "97658130917593"},
        {"Starlight", "134645216613107"},
        {"Heavenly", "139300897520961"},
        {"Ribbon", "132069507632161"},
        {"Sakura", "81755778619404"},
        {"Wind", "80694081850877"},
        {"Flow", "119913533725648"},
        {"Star", "73754563740680"},
    }
    for _, a in ipairs(AURAS) do
        sec:AddButton({Title=a[1], Callback=function()
            applyAura(a[2], a[1])
        end})
    end
    sec:AddButton({Title="Очистить ауру", Callback=function()
        clearAura()
        pendingAura = nil
        Notify("FH", "Аура очищена", 2)
    end})
end

-- ============================================================
-- 11. ANTI-AIM
-- ============================================================
do
    local enabled = false
    local token = 0
    local savedCollide = {}
    local stepConn = nil
    local dieConn = nil

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
                if part and part.Parent then
                    pcall(function() part.CanCollide = ct end)
                end
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
        table.clear(savedCollide)
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
                    local cam = workspace.CurrentCamera
                    if cam then cam.CameraType = Enum.CameraType.Custom end
                end
            end)
        end

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
                    if savedCollide[d] == nil then
                        savedCollide[d] = d.CanCollide
                    end
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
                    local push = oldVel * 10000
                    root.Velocity = push + Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    if enabled and token == myToken and c.Parent and h.Health > 0 and root.Parent then
                        root.Velocity = oldVel
                    end
                    RunService.Stepped:Wait()
                    if enabled and token == myToken and c.Parent and h.Health > 0 and root.Parent then
                        root.Velocity = oldVel + Vector3.new(0, wobble, 0)
                        wobble = wobble * -1
                    end
                end
            end
        end)
    end

    local sec = Tabs.Utility:AddSection({Name="Anti-Aim"})
    _addOpt(sec, "AddToggle", "FHAntiAimOn", {Title="Анти-аим", Default=false}, function(v)
        if v then
            start()
            Notify("FH", "Anti-Aim ВКЛ", 2)
        else
            stop()
            Notify("FH", "Anti-Aim ВЫКЛ", 2)
        end
    end)
    getgenv().FH_AntiAimCleanup = stop
end

-- ============================================================
-- 12. CLIENT GHOST
-- ============================================================
do
    local folder = Workspace:FindFirstChild("FH_ClientVisuals")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "FH_ClientVisuals"
        folder.Parent = Workspace
    end

    local ghostModel = nil
    local ghostPairs = {}
    local history = {}
    local lastChar = nil
    local active = false

    local cfg = {
        Transparency = 50,
        Color = Color3.fromRGB(255, 100, 100),
        DeleteTexture = false,
        Backtrack = true,
        BacktrackTime = 0.15,
    }

    local function cleanup()
        if ghostModel then pcall(function() ghostModel:Destroy() end) end
        ghostModel = nil
        ghostPairs = {}
        history = {}
        lastChar = nil
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
                    if cfg.DeleteTexture then
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
        ghostModel.Name = "FH_ClientGhost"
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
                local g = nil
                if d.Parent == char then
                    g = clone:FindFirstChild(d.Name)
                elseif d.Parent and d.Parent:IsA("Accessory") then
                    local acc = clone:FindFirstChild(d.Parent.Name)
                    if acc then g = acc:FindFirstChild(d.Name) end
                end
                if g and g:IsA("BasePart") then
                    table.insert(ghostPairs, {real = d, ghost = g})
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
        table.insert(history, snap)
        local cutoff = tick() - 2
        while #history > 0 and history[1].t < cutoff do
            table.remove(history, 1)
        end
        local ping = 0
        pcall(function()
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        local wantTime = cfg.Backtrack and tick() - math.clamp(ping / 1000, 0.02, 0.5) or tick()
        if cfg.Backtrack and cfg.BacktrackTime and cfg.BacktrackTime > 0 then
            wantTime = tick() - math.clamp(cfg.BacktrackTime, 0, 1)
        end
        local chosen = nil
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

    local sec = Tabs.Visual:AddSection({Name="Client Ghost"})
    _addOpt(sec, "AddToggle", "FHGhostOn", {Title="Включить Client Ghost", Default=false}, function(v)
        active = v
        if not v then cleanup() end
        Notify("FH", v and "Ghost ВКЛ" or "Ghost ВЫКЛ", 2)
    end)
    _addOpt(sec, "AddSlider", "FHGhostTransparency", {Title="Прозрачность (%)", Min = 0, Max = 100, Default = 50, Rounding = 0}, function(v)
        cfg.Transparency = tonumber(v) or 50
        paint()
    end)
    _addOpt(sec, "AddColorPicker", "FHGhostColor", {Title="Цвет", Default = Color3.fromRGB(255, 100, 100)}, function(c)
        cfg.Color = c
        paint()
    end)
    _addOpt(sec, "AddToggle", "FHGhostNoTexture", {Title="Убрать текстуры", Default = false}, function(v)
        cfg.DeleteTexture = v
        paint()
    end)
    _addOpt(sec, "AddToggle", "FHGhostBacktrack", {Title="Бэктрек (задержка)", Default = true}, function(v)
        cfg.Backtrack = v
    end)
    _addOpt(sec, "AddSlider", "FHGhostBacktrackTime", {Title="Время бэктрека (сек)", Min = 0, Max = 0.8, Default = 0.15, Rounding = 2}, function(v)
        cfg.BacktrackTime = tonumber(v) or 0.15
    end)
end

-- ============================================================
-- 13. CUSTOM PNG AVATARS
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
        local path = folder .. "/avatar_"..tostring(idx or 1)..".png"
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
        if not getgenv().FH_CustomAvatarsEnabled then
            if not player then return "" end
            local ok, img = pcall(function()
                return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            return ok and img or ""
        end
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
    getgenv().FH_RefreshAvatars = function() end
end

-- ============================================================
-- 14. PLAYER LIST PANEL
-- ============================================================
do
    local targetSection = Tabs.Troll:AddSection({Name="Player List Panel"})

    local function createPanelGui()
        if getgenv().FH_PlayerPanelGui then
            pcall(function() getgenv().FH_PlayerPanelGui:Destroy() end)
        end
        local gui = Instance.new("ScreenGui")
        gui.Name = "FH_PlayerListPanel"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 450
        gui.Enabled = false
        pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
        if not gui.Parent then gui.Parent = CoreGui end

        local frame = Instance.new("Frame")
        frame.Name = "Panel"
        frame.Size = UDim2.fromOffset(440, 380)
        frame.Position = UDim2.new(0.5, -220, 0.5, -190)
        frame.BackgroundColor3 = Color3.fromRGB(16, 12, 9)
        frame.BackgroundTransparency = 0.08
        frame.BorderSizePixel = 0
        frame.Active = true
        frame.Draggable = true
        frame.Parent = gui
        local c = Instance.new("UICorner", frame)
        c.CornerRadius = UDim.new(0, 10)
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
        closeBtn.MouseButton1Click:Connect(function()
            gui.Enabled = false
        end)

        local searchInner = Instance.new("TextBox")
        searchInner.Size = UDim2.new(1, -24, 0, 28)
        searchInner.Position = UDim2.new(0, 12, 0, 36)
        searchInner.BackgroundColor3 = Color3.fromRGB(15, 13, 11)
        searchInner.BackgroundTransparency = 0.15
        searchInner.BorderSizePixel = 0
        searchInner.ClearTextOnFocus = false
        searchInner.Font = Enum.Font.Gotham
        searchInner.PlaceholderText = "Поиск игроков..."
        searchInner.PlaceholderColor3 = Color3.fromRGB(150, 145, 140)
        searchInner.Text = ""
        searchInner.TextColor3 = Color3.fromRGB(245, 242, 238)
        searchInner.TextSize = 13
        searchInner.TextXAlignment = Enum.TextXAlignment.Left
        searchInner.Parent = frame
        Instance.new("UICorner", searchInner).CornerRadius = UDim.new(0, 6)
        local sp = Instance.new("UIPadding", searchInner)
        sp.PaddingLeft = UDim.new(0, 8)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Name = "PlayerCards"
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

        getgenv().FH_PlayerPanelGui = gui
        getgenv().FH_PlayerPanel = {
            Frame = frame, Scroll = scroll, Search = searchInner,
            SelectedPlayer = nil,
            CardMap = {},
        }
    end
    createPanelGui()

    local panel = getgenv().FH_PlayerPanel

    local function refreshCards()
        if not panel then return end
        local scroll = panel.Scroll
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        panel.CardMap = {}
        local query = string.lower(panel.Search.Text or "")
        local order = 0
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer then
                local dn = string.lower(pl.DisplayName or "")
                local nm = string.lower(pl.Name or "")
                if query == "" or dn:find(query, 1, true) or nm:find(query, 1, true) then
                    order = order + 1
                    local btn = Instance.new("TextButton")
                    btn.Name = "P_"..pl.Name
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
                    lbl.Text = pl.DisplayName ~= pl.Name and pl.DisplayName or pl.Name
                    lbl.TextColor3 = Color3.fromRGB(245, 242, 238)
                    lbl.TextSize = 12
                    lbl.TextWrapped = true
                    lbl.TextTruncate = Enum.TextTruncate.AtEnd
                    lbl.TextXAlignment = Enum.TextXAlignment.Left
                    lbl.Parent = btn
                    img.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
                    task.spawn(function()
                        local av = getgenv().FH_GetAvatarFor and getgenv().FH_GetAvatarFor(pl)
                        if av and img.Parent then img.Image = av end
                    end)
                    btn.Activated:Connect(function()
                        panel.SelectedPlayer = pl
                        getgenv().FH_SelectedPlayer = pl
                        Notify("FH", "Выбран: "..pl.Name, 1.5)
                    end)
                    panel.CardMap[pl] = btn
                end
            end
        end
    end
    panel.Search:GetPropertyChangedSignal("Text"):Connect(refreshCards)
    Players.PlayerAdded:Connect(refreshCards)
    Players.PlayerRemoving:Connect(function(pl)
        local c = panel.CardMap[pl]
        if c and c.Parent then c:Destroy() end
        panel.CardMap[pl] = nil
        if panel.SelectedPlayer == pl then
            panel.SelectedPlayer = nil
            getgenv().FH_SelectedPlayer = nil
        end
        refreshCards()
    end)
    refreshCards()

    _addOpt(targetSection, "AddToggle", "FHPlayerPanelOn", {Title = "Открыть Player List Panel", Default = false}, function(v)
        if panel and panel.Frame then
            panel.Frame.Parent.Enabled = v
            if v then refreshCards() end
        end
    end)

    targetSection:AddButton({Title="Телепорт к выбранному", Callback=function()
        local pl = getgenv().FH_SelectedPlayer
        if not pl or not pl.Character then Notify("FH","Игрок не выбран или мёртв", 2) return end
        local hrp = getHRP()
        if not hrp then return end
        local t = pl.Character:FindFirstChild("HumanoidRootPart")
        if t then hrp.CFrame = t.CFrame + Vector3.new(0, 5, 0) end
    end})
    targetSection:AddButton({Title="Телепорт игрока к себе", Callback=function()
        local pl = getgenv().FH_SelectedPlayer
        if not pl or not pl.Character then Notify("FH","Игрок не выбран", 2) return end
        local hrp = getHRP()
        if not hrp then return end
        local t = pl.Character:FindFirstChild("HumanoidRootPart")
        if t then t.CFrame = hrp.CFrame + Vector3.new(0, 3, 0) end
    end})
    targetSection:AddButton({Title="Замутить выбранного (AntiFling)", Callback=function()
        local pl = getgenv().FH_SelectedPlayer
        if not pl or not pl.Character then Notify("FH","Игрок не выбран", 2) return end
        for _, d in ipairs(pl.Character:GetDescendants()) do
            if d:IsA("BasePart") then d.CanCollide = false end
        end
        Notify("FH", pl.Name.." замучен", 2)
    end})
end

-- ============================================================
-- 15. UI SOUNDS (ФИКС: рабочие ID + SoundService)
-- ============================================================
do
    local SoundIds = {
        ["Enable 1"] = "rbxassetid://9120386436",
        ["Sparkle"] = "rbxassetid://7149482321",
        ["Laser Click"] = "rbxassetid://5686032130",
        ["Enable 2"] = "rbxassetid://9120386436",
        ["Notify"] = "rbxassetid://6042053626",
    }
    local cfg = {
        Enabled = true,
        EnableSound = "Enable 1",
        DisableSound = "Enable 1",
    }
    getgenv().FH_UISoundCfg = cfg

    task.spawn(function()
        local ids = {}
        for _, id in pairs(SoundIds) do table.insert(ids, id) end
        pcall(function() game:GetService("ContentProvider"):PreloadAsync(ids) end)
    end)

    local function play(id)
        if not cfg.Enabled then return end
        if not id or id == "" then return end
        task.spawn(function()
            local ok, s = pcall(function()
                local snd = Instance.new("Sound")
                snd.Name = "FH_UISound"
                snd.SoundId = id
                snd.Volume = 1
                snd.Looped = false
                snd.PlayOnRemove = true
                snd.Parent = SoundService
                snd:Play()
                return snd
            end)
            if ok and s then
                task.delay(5, function() pcall(function() s:Destroy() end) end)
            end
        end)
    end
    local function playEnable() play(SoundIds[cfg.EnableSound]) end
    local function playDisable() play(SoundIds[cfg.DisableSound]) end
    getgenv().FH_PlayUISound = play
    getgenv().FH_PlayUISoundEnable = playEnable
    getgenv().FH_PlayUISoundDisable = playDisable

    local sec = Tabs.Utility:AddSection({Name="UI Sounds"})
    _addOpt(sec, "AddToggle", "FH_UISoundsOn", {Title = "Звуки интерфейса", Default = true}, function(v)
        cfg.Enabled = v
        if v then playEnable() end
    end)
    _addOpt(sec, "AddDropdown", "FH_UISoundEnable", {Title = "Звук включения", Values = {"Enable 1", "Sparkle", "Laser Click", "Enable 2", "Notify"}, Default = "Enable 1"}, function(v)
        cfg.EnableSound = v or "Enable 1"
        play(SoundIds[cfg.EnableSound])
    end)
    _addOpt(sec, "AddDropdown", "FH_UISoundDisable", {Title = "Звук выключения", Values = {"Enable 1", "Sparkle", "Laser Click", "Enable 2", "Notify"}, Default = "Enable 1"}, function(v)
        cfg.DisableSound = v or "Enable 1"
        play(SoundIds[cfg.DisableSound])
    end)
    sec:AddButton({Title="Проверить включение", Callback=function() playEnable() end})
    sec:AddButton({Title="Проверить выключение", Callback=function() playDisable() end})
end

-- ============================================================
-- 16. CUSTOM GAME SOUNDS (~50)
-- ============================================================
do
    local GameSounds = {
        ["Rust Headshot"]="138750331387064",["Neverlose"]="110168723447153",["Bubble"]="6534947588",
        ["Steve"]="4965083997",["Call of Duty"]="5952120301",["Bat"]="3333907347",["TF2 Critical"]="296102734",
        ["Saber"]="8415678813",["Bameware"]="3124331820",["Money"]="13956013041",["Notif"]="6696469190",
        ["Shutter"]="10066921516",["RIFK7"]="9102080552",["LazerBeam"]="130791043",["WindowsXPError"]="160715357",
        ["TF2Hitsound"]="3455144981",["TF2Bat"]="3333907347",["BowHit"]="1053296915",["Bow"]="3442683707",
        ["OSU"]="7147454322",["OneNN"]="7349055654",["TF2Pan"]="3431749479",["Mario"]="5709456554",
        ["Bell"]="6534947240",["Pick"]="1347140027",["Fart"]="130833677",["Big"]="5332005053",
        ["Vine"]="5332680810",["Bruh"]="4578740568",["Skeet"]="5633695679",["Fatality"]="6534947869",
        ["Bonk"]="5766898159",["Minecraft"]="5869422451",["Gamesense"]="4817809188",["Bamboo"]="3769434519",
        ["Weeb"]="6442965016",["Beep"]="8177256015",["Bambi"]="8437203821",["Stone"]="3581383408",
        ["Old Fatality"]="6607142036",["Click"]="8053704437",["Ding"]="7149516994",["Snow"]="6455527632",
        ["Osu"]="7149255551",["TF2"]="2868331684",["Slime"]="6916371803",["Among Us"]="5700183626",
        ["One"]="7380502345",["BulletDeflect"]="1657157666",["Default Sound"]="330595293",["UwU"]="8679659744",
        ["Cod"]="160432334",["Blood SFX"]="8164951181",["Blood Burst"]="3781479909",
    }
    local list = {"Default"}
    for k in pairs(GameSounds) do table.insert(list, k) end
    table.sort(list, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)

    local cfg = {
        SheriffKill="Default", MurderKill="Default", KnifeKill="Default",
        Gunshot="Default", Shoot="Default", MutedReload=false,
    }
    getgenv().FH_GameSoundCfg = cfg

    local function play(name)
        local id = GameSounds[name]
        if not id then return end
        pcall(function()
            local s = Instance.new("Sound")
            s.SoundId = "rbxassetid://"..id
            s.Volume = 1
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 5)
        end)
    end

    local tracked = {}
    local function hookSound(snd)
        if not snd:IsA("Sound") or tracked[snd] then return end
        tracked[snd] = true
        snd.Played:Connect(function()
            local n = snd.Name
            local map = nil
            if n == "GunKill" or n == "SheriffKill" then map = cfg.SheriffKill
            elseif n == "Kill" then map = cfg.KnifeKill
            elseif n == "Gunshot" or n == "Shoot" then map = cfg.Gunshot
            end
            if n == "Reload" and cfg.MutedReload then
                snd.Volume = 0
                snd:Stop()
                return
            end
            if map and map ~= "Default" and GameSounds[map] then
                snd.SoundId = "rbxassetid://"..GameSounds[map]
                snd.TimePosition = 0
                snd:Play()
            end
        end)
    end
    Workspace.DescendantAdded:Connect(function(d)
        if d:IsA("Sound") and (d.Name == "GunKill" or d.Name == "SheriffKill" or d.Name == "Kill" or d.Name == "Gunshot" or d.Name == "Shoot" or d.Name == "Reload") then
            hookSound(d)
        end
    end)
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Sound") and (d.Name == "GunKill" or d.Name == "SheriffKill" or d.Name == "Kill" or d.Name == "Gunshot" or d.Name == "Shoot" or d.Name == "Reload") then
            hookSound(d)
        end
    end

    local sec = Tabs.Utility:AddSection({Name="Game Sounds"})
    _addOpt(sec, "AddDropdown", "FH_SheriffKill", {Title = "Мы убили убийцу", Values = list, Default = "Default"}, function(v) cfg.SheriffKill = v or "Default" end)
    _addOpt(sec, "AddDropdown", "FH_MurderKill", {Title = "Убийца кого-то убил", Values = list, Default = "Default"}, function(v) cfg.MurderKill = v or "Default" end)
    _addOpt(sec, "AddDropdown", "FH_KnifeKill", {Title = "Убийство ножом", Values = list, Default = "Default"}, function(v) cfg.KnifeKill = v or "Default" end)
    _addOpt(sec, "AddDropdown", "FH_Gunshot", {Title = "Выстрел", Values = list, Default = "Default"}, function(v) cfg.Gunshot = v or "Default" end)
    _addOpt(sec, "AddToggle", "FH_MuteReload", {Title = "Заглушить перезарядку", Default = false}, function(v) cfg.MutedReload = v end)
    sec:AddButton({Title="Проверить (текущий)", Callback=function() play(cfg.SheriffKill) end})
end

-- ============================================================
-- 17. LANGUAGE SYSTEM (RU/EN)
-- ============================================================
do
    local currentLang = "EN"
    local textMap = {EN = {}, RU = {}}
    getgenv().FH_CurrentLang = currentLang
    getgenv().FH_TextMap = textMap
    local function translate(str)
        if currentLang == "RU" then return textMap.RU[str] or str end
        return str
    end
    getgenv().FH_Translate = translate
    local sec = Tabs.Settings:AddSection({Name="Language"})
    _addOpt(sec, "AddDropdown", "FH_Lang", {Title = "Язык интерфейса", Values = {"EN", "RU"}, Default = "EN"}, function(v)
        currentLang = v or "EN"
        getgenv().FH_CurrentLang = currentLang
        Notify("FH", "Язык: "..currentLang, 2)
    end)
    sec:AddButton({Title="Применить сейчас", Callback=function()
        Notify("FH", "Язык: "..currentLang, 2)
    end})
end

-- ============================================================
-- 18. WATERMARK (FPS/ping pill)
-- ============================================================
do
    pcall(function()
        local old = CoreGui:FindFirstChild("FH_Watermark_v21")
        if old then old:Destroy() end
    end)
    local gui = Instance.new("ScreenGui")
    gui.Name = "FH_Watermark_v21"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 480
    pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
    if not gui.Parent then gui.Parent = CoreGui end

    local frame = Instance.new("Frame")
    frame.AnchorPoint = Vector2.new(0.5, 1)
    frame.Position = UDim2.new(0.5, 0, 1, -70)
    frame.Size = UDim2.fromOffset(240, 30)
    frame.BackgroundColor3 = Color3.fromRGB(16, 12, 9)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(224, 116, 24)
    stroke.Thickness = 1.2
    stroke.Transparency = 0.35
    local grad = Instance.new("UIGradient", stroke)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(224, 116, 24)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 90, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(224, 116, 24)),
    })

    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.fromOffset(60, 30)
    logo.Position = UDim2.fromOffset(8, 0)
    logo.BackgroundTransparency = 1
    logo.Font = Enum.Font.GothamBold
    logo.Text = "FH"
    logo.TextColor3 = Color3.fromRGB(224, 116, 24)
    logo.TextSize = 14
    logo.TextXAlignment = Enum.TextXAlignment.Left
    logo.Parent = frame

    local fps = Instance.new("TextLabel")
    fps.Size = UDim2.fromOffset(70, 30)
    fps.Position = UDim2.fromOffset(50, 0)
    fps.BackgroundTransparency = 1
    fps.Font = Enum.Font.GothamBold
    fps.Text = "60 fps"
    fps.TextColor3 = Color3.fromRGB(80, 240, 120)
    fps.TextSize = 12
    fps.TextXAlignment = Enum.TextXAlignment.Center
    fps.Parent = frame

    local ping = Instance.new("TextLabel")
    ping.Size = UDim2.fromOffset(70, 30)
    ping.Position = UDim2.fromOffset(120, 0)
    ping.BackgroundTransparency = 1
    ping.Font = Enum.Font.GothamBold
    ping.Text = "0 ms"
    ping.TextColor3 = Color3.fromRGB(80, 240, 120)
    ping.TextSize = 12
    ping.TextXAlignment = Enum.TextXAlignment.Center
    ping.Parent = frame

    local version = Instance.new("TextLabel")
    version.Size = UDim2.fromOffset(60, 30)
    version.Position = UDim2.fromOffset(185, 0)
    version.BackgroundTransparency = 1
    version.Font = Enum.Font.GothamBold
    version.Text = "v20.1"
    version.TextColor3 = Color3.fromRGB(170, 90, 255)
    version.TextSize = 11
    version.TextXAlignment = Enum.TextXAlignment.Right
    version.Parent = frame

    task.spawn(function()
        while true do
            task.wait(0.5)
            local fpsCount = 0
            do
                local t = tick()
                local frames = 0
                local conn
                conn = RunService.RenderStepped:Connect(function()
                    frames = frames + 1
                    if tick() - t >= 0.5 then
                        conn:Disconnect()
                    end
                end)
                task.wait(0.55)
                fpsCount = math.floor(frames / 0.5)
            end
            local p = 0
            pcall(function() p = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
            fps.Text = tostring(fpsCount).." fps"
            ping.Text = tostring(p).." ms"
            fps.TextColor3 = fpsCount < 30 and Color3.fromRGB(255, 80, 80) or (fpsCount < 60 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(80, 240, 120))
            ping.TextColor3 = p < 60 and Color3.fromRGB(80, 240, 120) or (p < 120 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 80, 80))
        end
    end)

    local sec = Tabs.Settings:AddSection({Name="Watermark"})
    _addOpt(sec, "AddToggle", "FH_WatermarkOn", {Title = "Показывать Watermark", Default = true}, function(v)
        frame.Visible = v
    end)
end

-- ============================================================
-- 19. JUMP CIRCLE
-- ============================================================
do
    local settings = getgenv().FH_JumpCircleSettings or {enabled = false, color = Color3.fromRGB(255, 105, 180)}
    getgenv().FH_JumpCircleSettings = settings

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
        img.Size = UDim2.fromScale(1, 1)
        img.Image = image
        img.ImageColor3 = settings.color
        img.ImageTransparency = 0
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
    _addOpt(sec, "AddToggle", "FH_JumpCircleOn", {Title = "Круг при прыжке", Default = false}, function(v)
        settings.enabled = v
        if v and LocalPlayer.Character then bind(LocalPlayer.Character) end
    end)
    _addOpt(sec, "AddColorPicker", "FH_JumpCircleCol", {Title = "Цвет", Default = Color3.fromRGB(255, 105, 180)}, function(c) settings.color = c end)
end

-- ============================================================
-- 20. RTX SHADER
-- ============================================================
do
    local rtxOn = false
    local saved = {}
    local savedChildren = {}
    local addedFx = {}
    local vignette = nil

    local function enable()
        if rtxOn then return end
        rtxOn = true
        local props = {
            "Ambient","Brightness","ColorShift_Bottom","ColorShift_Top",
            "EnvironmentDiffuseScale","EnvironmentSpecularScale","GlobalShadows",
            "OutdoorAmbient","ShadowSoftness","ClockTime","GeographicLatitude",
            "ExposureCompensation",
        }
        for _, p in ipairs(props) do
            pcall(function() saved[p] = Lighting[p] end)
        end
        savedChildren = {}
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
        sky.SunAngularSize = 11
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
        Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
        Lighting.ColorShift_Top = Color3.fromRGB(0, 0, 0)
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 100)
        Lighting.ShadowSoftness = 0.15
        Lighting.ClockTime = 14
        Lighting.GeographicLatitude = 45
        Lighting.ExposureCompensation = 0.1
        vignette = Instance.new("ScreenGui")
        vignette.Name = "FH_RTXVignette"
        vignette.IgnoreGuiInset = true
        vignette.ResetOnSpawn = false
        vignette.Parent = LocalPlayer:WaitForChild("PlayerGui")
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
        for _, ch in ipairs(savedChildren) do pcall(function() ch.Parent = Lighting end) end
        savedChildren = {}
        for k, v in pairs(saved) do pcall(function() Lighting[k] = v end) end
        saved = {}
        if vignette then pcall(function() vignette:Destroy() end); vignette = nil end
    end

    local sec = Tabs.Effects:AddSection({Name="RTX Shader"})
    _addOpt(sec, "AddToggle", "FH_RTXOn", {Title = "Включить RTX", Default = false}, function(v)
        if v then enable() else disable() end
        Notify("FH", "RTX "..(v and "ВКЛ" or "ВЫКЛ"), 2)
    end)
end

-- ============================================================
-- 21. ADVANCED AUTOFARM
-- ============================================================
do
    local cfg = {
        Mode = "Underground",
        TweenSpeed = 25,
        AutoReset = false,
        AvoidMurder = false,
        UndergroundOffset = 4,
        MaxDistance = 600,
        CoinLimit = 40,
        Active = false,
    }
    local state = {farming = false, flying = false, target = nil, ignored = {}, tween = nil}

    local function getChar()
        local c = LocalPlayer.Character
        return c, c and (c:FindFirstChild("Torso") or c:FindFirstChild("LowerTorso") or c:FindFirstChild("HumanoidRootPart"))
    end
    local function findCoinContainer()
        for _, d in ipairs(Workspace:GetDescendants()) do
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
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
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
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LocalPlayer and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local bp = pl:FindFirstChild("Backpack")
                local hasKnife = pl.Character:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife"))
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
        if state.tween then pcall(function() state.tween:Cancel() end); state.tween = nil end
        local char = LocalPlayer.Character
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
        local c = LocalPlayer.Character
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
        local c = LocalPlayer.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BasePart") then d.CanCollide = false end
        end
    end
    local function travelTo(dest, target)
        local c = LocalPlayer.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local dist = (dest - hrp.Position).Magnitude
        local dur = dist / math.max(cfg.TweenSpeed, 1)
        state.tween = TweenService:Create(hrp, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = CFrame.new(dest)})
        local done = false
        local hb = RunService.Heartbeat:Connect(function()
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
            if not char then task.wait(1) else
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
                            local ok = travelTo(dest, coin)
                            if ok then
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

    local sec = Tabs.Farm:AddSection({Name="Advanced AutoFarm"})
    _addOpt(sec, "AddToggle", "FHAdvFarmOn", {Title = "Включить Advanced Farm", Default = false}, function(v)
        if v then
            start()
            Notify("FH", "Advanced Farm ВКЛ", 2)
        else
            stopFarming()
            Notify("FH", "Advanced Farm ВЫКЛ", 2)
        end
    end)
    _addOpt(sec, "AddDropdown", "FHAdvFarmMode", {Title = "Режим", Values = {"Underground", "Sit"}, Default = "Underground"}, function(v) cfg.Mode = v or "Underground" end)
    _addOpt(sec, "AddSlider", "FHAdvFarmSpeed", {Title = "Скорость", Min = 5, Max = 100, Default = 25, Rounding = 0}, function(v) cfg.TweenSpeed = tonumber(v) or 25 end)
    _addOpt(sec, "AddSlider", "FHAdvFarmOffset", {Title = "Смещение под землёй", Min = 0, Max = 20, Default = 4, Rounding = 0}, function(v) cfg.UndergroundOffset = tonumber(v) or 4 end)
    _addOpt(sec, "AddSlider", "FHAdvFarmDist", {Title = "Макс. дистанция монет", Min = 50, Max = 2000, Default = 600, Rounding = 0}, function(v) cfg.MaxDistance = tonumber(v) or 600 end)
    _addOpt(sec, "AddSlider", "FHAdvFarmCoinLimit", {Title = "Лимит монет", Min = 5, Max = 200, Default = 40, Rounding = 0}, function(v) cfg.CoinLimit = tonumber(v) or 40 end)
    _addOpt(sec, "AddToggle", "FHAdvFarmAutoReset", {Title = "Авто-ресет", Default = false}, function(v) cfg.AutoReset = v end)
    _addOpt(sec, "AddToggle", "FHAdvFarmAvoid", {Title = "Избегать маньяка", Default = false}, function(v) cfg.AvoidMurder = v end)
    getgenv().FH_AdvFarmStop = stopFarming
end

pcall(function() Window:SelectTab(1) end)

print("[FH] ============================================")
print("[FH] Part 2/2 — Extra Features v20.1 — "..CREDITS)
print("[FH] TradeHelper(stub), VoteDuper, Emotes, WaterProt, FadeDisabler, AntiCoin")
print("[FH] GunModels, BeamEffects, Skybox, Auras, AntiAim, Ghost, Avatars")
print("[FH] PlayerPanel, UISounds(FIX), GameSounds, Language, Watermark, JumpCircle")
print("[FH] RTX, Advanced AutoFarm")
print("[FH] Скрипт создан HOTI и Ve315. BETA версия.")
print("[FH] ============================================")
