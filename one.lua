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
local VERSION="18.4.0"
local CREDITS="by HOTI and Ve315"
local S={frozen=false,freezeUpKey=Enum.KeyCode.Space,freezeDownKey=Enum.KeyCode.LeftAlt}
local silent={enabled=false,predict=true,force=false,bindKey=Enum.KeyCode.E,standoff=15,lastShot=0}
local knifeSilent={enabled=false,bindKey=Enum.KeyCode.R,radius=20,fov=120,showFov=true,checkWalls=false,instaKill=true,predict=true}
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
        Size=UDim2.fromOffset(820,520),
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
Tabs.Animations=Window:AddTab({Title="Анимации"})
Tabs.Utility=Window:AddTab({Title="Утилиты"})
Tabs.Troll=Window:AddTab({Title="Троллинг"})
Tabs.Settings=Window:AddTab({Title="Настройки"})
local lastNotify={}
local function Notify(title,content,dur)
    local k=tostring(title).."|"..tostring(content)
    if lastNotify[k] and (tick()-lastNotify[k])<0.5 then return end
    lastNotify[k]=tick()
    pcall(function() Fluent:Notify({Title=title,Content=content,Duration=dur or 3}) end)
end
getgenv().FH_Notify=Notify
local HUDGui,FPSLabel,PingLabel,Pill
do
    pcall(function()
        for _,name in ipairs({"FH_HUD_v18","FH_HUD","FH_HUD_v182","FH_HUD_v1821","FH_HUD_v183"}) do
            local old=CoreGui:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
    HUDGui=Instance.new("ScreenGui")
    HUDGui.Name="FH_HUD_v184"
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
do
    local MAX_RANGE=300
    local snap_t=table.create(48,0)
    local snap_p=table.create(48,Vector3.zero)
    local snap_n,snap_i=0,0
    local TRK={target=nil,char=nil,part=nil,hum=nil,pos=nil,time=0,vel=Vector3.zero,gap=0,ready=false,fresh=Vector3.zero,air=false,air_since=0,jumping=false,jump_v=0,fresh_ok=false,turn=0,spoof=0,clr=0,air_edge=0,jump_fresh=false}
    local SK={vt=table.create(48,0),dx=table.create(48,0),dz=table.create(48,0),vn=0,vi=0}
    local EC={ping=0,rtt=0,jitter=0,seen=false,step=0,step_seen=false}
    local P={snap=48,ring=48,hit_r=2.1,pad=2.6,min_span=5,max_span=90,acc_t=0.15,acc_max=280,acc_min=40,speed_floor=26,speed_head=1.3}
    local KIN={ok=false,ax=0,az=0,smax=0}
    local GC={base=0,seen=false}
    local JL={v=0,seen=false}
    local HY={pos={},w={},n=0,weight=0,primary=nil,stamp=0,conf=0}
    local function step_push(dt) if dt<=0 or dt>0.5 then return end if EC.step_seen then EC.step=EC.step*0.85+dt*0.15 else EC.step=dt EC.step_seen=true end end
    local function sample_span() local span=math.max(EC.step,TRK.gap) if span<=0 then return 0 end return span end
    local function snap_push(now,pos) snap_i=snap_i%P.snap+1 snap_t[snap_i]=now snap_p[snap_i]=pos if snap_n<P.snap then snap_n=snap_n+1 end end
    local function snap_get(k) local idx=(snap_i-k-1)%P.snap+1 return snap_t[idx],snap_p[idx] end
    local function fit_velocity() if snap_n<3 then return nil,0 end local newest=select(1,snap_get(0)) local used,sum_d=0,0 local win=math.max(sample_span()*4,0.08) for k=0,snap_n-1 do local t=select(1,snap_get(k)) if newest-t>win then break end used=used+1 sum_d=sum_d+(t-newest) end if used<3 then return nil,0 end local mean_d=sum_d/used local num,den=Vector3.zero,0 for k=0,used-1 do local t,p=snap_get(k) local d=(t-newest)-mean_d num=num+p*d den=den+d*d end if den<1e-8 then return nil,0 end return num/den,-mean_d end
    local function recent_velocity() if snap_n<2 then return nil,nil end local newest,head=snap_get(0) local fallback,fallback_age=nil,nil local target_span=sample_span()*2 local max_span=target_span*2 for k=1,snap_n-1 do local t,p=snap_get(k) local dt=newest-t if dt>max_span then break end if dt>0 then fallback=(head-p)/dt fallback_age=dt*0.5 if dt>=target_span then return fallback,fallback_age end end end return fallback,fallback_age end
    local function fit_kin() if snap_n<5 then return nil end local t0=snap_get(0) local win=math.max(sample_span()*5,0.12) local scale=win local n,s1,s2,s3,s4=0,0,0,0,0 local bx0,bx1,bx2=0,0,0 local bz0,bz1,bz2=0,0,0 for k=0,snap_n-1 do local t,p=snap_get(k) local age=t0-t if age>win then break end local u=-age/scale local u2=u*u n=n+1 s1=s1+u s2=s2+u2 s3=s3+u2*u s4=s4+u2*u2 bx0=bx0+p.X bx1=bx1+p.X*u bx2=bx2+p.X*u2 bz0=bz0+p.Z bz1=bz1+p.Z*u bz2=bz2+p.Z*u2 end if n<5 then return nil end local det=n*(s2*s4-s3*s3)-s1*(s1*s4-s3*s2)+s2*(s1*s3-s2*s2) if math.abs(det)<1e-9 then return nil end local function solve(b0,b1,b2) local d1=n*(b1*s4-s3*b2)-b0*(s1*s4-s3*s2)+s2*(s1*b2-b1*s2) local d2=n*(s2*b2-b1*s3)-s1*(s1*b2-b1*s2)+b0*(s1*s3-s2*s2) return d1/det,d2/det end local cx1,cx2=solve(bx0,bx1,bx2) local cz1,cz2=solve(bz0,bz1,bz2) local vx,vz=cx1/scale,cz1/scale local ax,az=2*cx2/(scale*scale),2*cz2/(scale*scale) if vx~=vx or vz~=vz or ax~=ax or az~=az then return nil end return Vector3.new(vx,0,vz),Vector3.new(ax,0,az) end
    local function kin_update() local kv,ka=fit_kin() if not kv then KIN.ok=false KIN.ax=0 KIN.az=0 return nil end KIN.ok=true local sp=math.sqrt(kv.X*kv.X+kv.Z*kv.Z) if sp>KIN.smax then KIN.smax=sp else KIN.smax=KIN.smax*0.985+sp*0.015 end if ka and not TRK.air then local am=math.sqrt(ka.X*ka.X+ka.Z*ka.Z) local ax,az=ka.X,ka.Z if am>P.acc_max and am>0 then ax=ax*P.acc_max/am az=az*P.acc_max/am end KIN.ax=KIN.ax*0.5+ax*0.5 KIN.az=KIN.az*0.5+az*0.5 else KIN.ax=KIN.ax*0.5 KIN.az=KIN.az*0.5 end return kv end
    local function snap_vel(k) local t0,p0=snap_get(k) local t1,p1=snap_get(k+1) local d=t0-t1 if d<=0 then return nil end return (p0-p1)/d,d end
    local function vert_accel() if snap_n<3 then return nil end local v0,d0=snap_vel(0) local v1,d1=snap_vel(1) if not v0 or not v1 then return nil end local span=(d0+d1)*0.5 if span<=1e-4 then return nil end return (v0.Y-v1.Y)/span end
    local function grav() local ok,g=pcall(function() return Workspace.Gravity end) if ok and type(g)=="number" and g>0 then return g end return 0 end
    local function air_vy() if snap_n<2 then return nil end local edge=TRK.air_edge if edge<=0 then return nil end local g=grav() local newest,head=snap_get(0) local want=sample_span()*2 local best=nil for k=1,snap_n-1 do local t,p=snap_get(k) if t<edge then break end local dt=newest-t if dt>1e-4 then best=(head.Y-p.Y)/dt-0.5*g*dt if dt>=want then break end end end return best end
    local function body_clearance() local part=TRK.part local hum=TRK.hum if not part or not hum then return 0 end local ok,v=pcall(function() return part.Size.Y*0.5+hum.HipHeight end) if ok and type(v)=="number" and v>0 then return v end return 0 end
    local function stand_clearance() if GC.seen then return GC.base end return body_clearance() end
    local function engine_vel(part) local ok,v=pcall(function() return part.AssemblyLinearVelocity end) if not ok or typeof(v)~="Vector3" then ok,v=pcall(function() return part.Velocity end) end if not ok or typeof(v)~="Vector3" then return nil end if v.Magnitude~=v.Magnitude then return nil end return v end
    local function vel_trust(pv,ev) if not pv or not ev then return 0 end local ph=Vector3.new(pv.X,0,pv.Z) local eh=Vector3.new(ev.X,0,ev.Z) local pm,em=ph.Magnitude,eh.Magnitude if pm<1 and em<1 then return 1 end if pm<1 or em<1 then return 0 end local ratio=em/pm if ratio>1.5 or ratio<0.6 then return 0 end local align=ph.Unit:Dot(eh.Unit) if align<0.7 then return 0 end local a=math.clamp((align-0.7)/0.25,0,1) local r=1-math.clamp(math.abs(ratio-1)/0.4,0,1) return a*r end
    local function phase_velocity(v,age,air) if not v then return nil end local y=0 if air then y=v.Y-grav()*math.clamp(age or 0,0,sample_span()*4) end return Vector3.new(v.X,y,v.Z) end
    local function merge_vel(fit,fit_age,fast,fast_age,engine,engine_age,air) local stable=phase_velocity(fit,fit_age,air) local instant=phase_velocity(fast,fast_age,air) local turn=0 if stable and instant then local sh=Vector3.new(stable.X,0,stable.Z) local ih=Vector3.new(instant.X,0,instant.Z) if sh.Magnitude>1 and ih.Magnitude>1 then turn=math.acos(math.clamp(sh.Unit:Dot(ih.Unit),-1,1))/math.pi end end local base=instant or stable if not base then return Vector3.zero,0,nil,0 end if stable and instant then local agility=math.clamp(turn*2.2,0,1) base=stable:Lerp(instant,0.4+0.6*agility) end local trust=0 if engine then local live=phase_velocity(engine,engine_age,air) trust=vel_trust(base,live) if trust>0 and air then base=Vector3.new(base.X,base.Y,base.Z):Lerp(Vector3.new(base.X,live.Y,base.Z),trust*0.35) end end return base,turn,instant or stable,trust end
    local function vel_push(now,hx,hz) SK.vi=SK.vi%P.ring+1 SK.vt[SK.vi]=now SK.dx[SK.vi]=hx SK.dz[SK.vi]=hz if SK.vn<P.ring then SK.vn=SK.vn+1 end end
    local function track_clear() TRK.part=nil TRK.pos=nil TRK.vel=Vector3.zero TRK.gap=0 TRK.ready=false TRK.fresh=Vector3.zero TRK.air=false TRK.jumping=false TRK.jump_v=0 TRK.fresh_ok=false TRK.turn=0 TRK.spoof=0 TRK.clr=0 TRK.air_edge=0 TRK.jump_fresh=false GC.base=0 GC.seen=false JL.v=0 JL.seen=false snap_n,snap_i=0,0 SK.vn,SK.vi=0,0 KIN.ok=false KIN.ax=0 KIN.az=0 KIN.smax=0 end
    local function track_seed(part,pos,now) TRK.part=part TRK.pos=pos TRK.time=now TRK.vel=Vector3.zero TRK.fresh=Vector3.zero TRK.fresh_ok=false TRK.turn=0 TRK.jump_v=0 TRK.gap=0 TRK.ready=false TRK.spoof=0 TRK.air_edge=0 TRK.jump_fresh=false GC.base=0 GC.seen=false snap_n,snap_i=0,0 KIN.ok=false KIN.ax=0 KIN.az=0 snap_push(now,pos) end
    local ground_params=RaycastParams.new() ground_params.FilterType=Enum.RaycastFilterType.Exclude ground_params.IgnoreWater=true local ground_filter={}
    local function ground_below(pos,reach) table.clear(ground_filter) local n=0 local char=TRK.char if char then n=n+1 ground_filter[n]=char end local mine=LocalPlayer.Character if mine then n=n+1 ground_filter[n]=mine end ground_params.FilterDescendantsInstances=ground_filter local res=Workspace:Raycast(pos,Vector3.new(0,-reach,0),ground_params) if res then return res.Position.Y end return nil end
    local function track_fresh(now) local part=TRK.part if not part or not part.Parent then TRK.fresh_ok=false return end local pos=part.Position local g=grav() local sv=snap_vel(0) local vy=sv and sv.Y or 0 local accel=vert_accel() local falling=accel~=nil and accel<-g*0.5 local guess=stand_clearance() local reach=guess+6+math.abs(vy)*sample_span()*4 local air local gy=ground_below(pos,reach) if gy then local clr=pos.Y-gy TRK.clr=clr if math.abs(vy)<1 and not falling then if GC.seen then if clr<GC.base then GC.base=GC.base*0.7+clr*0.3 else GC.base=GC.base*0.98+clr*0.02 end else GC.base=clr GC.seen=true end end local floor=GC.seen and GC.base or guess local tol=math.max(floor*0.35,1) air=clr>floor+tol if not air and falling and math.abs(vy)>4 and clr>floor+0.35 then air=true end else air=true end if air~=TRK.air then TRK.air_edge=now if air then TRK.air_since=now TRK.jump_fresh=true TRK.jump_v=JL.seen and JL.v or math.max(vy,0) else TRK.jump_fresh=false TRK.jump_v=0 end end local model_vy=TRK.jump_v-g*math.max(0,now-TRK.air_since) TRK.air=air TRK.jumping=air and (vy>1 or model_vy>1) end
    local function track(now) local part=TRK.part if not part or not part.Parent then if TRK.part then track_clear() end return end track_fresh(now) local pos=part.Position if part~=TRK.part or not TRK.pos then track_seed(part,pos,now) return end local dt=now-TRK.time if dt>0.75 or (pos-TRK.pos).Magnitude>140 then track_seed(part,pos,now) return end if dt<=0 then return end if (pos-TRK.pos).Magnitude==0 then if TRK.gap>0 and dt>=TRK.gap then TRK.vel=Vector3.zero TRK.fresh=Vector3.zero end return end step_push(dt) TRK.gap=dt snap_push(now,pos) TRK.pos=pos TRK.time=now local fit,fit_age=fit_velocity() local fast,fast_age=recent_velocity() local engine=engine_vel(part) local fresh,turn,instant,trust=merge_vel(fit,fit_age,fast,fast_age,engine,sample_span()*0.5,TRK.air) local kv=kin_update() if kv then fresh=Vector3.new(kv.X,fresh.Y,kv.Z) end if engine and trust<=0 then if TRK.spoof<20 then TRK.spoof=TRK.spoof+1 end elseif TRK.spoof>0 then TRK.spoof=TRK.spoof-1 end if TRK.air then local vy=air_vy() if vy then fresh=Vector3.new(fresh.X,vy,fresh.Z) local since=math.max(0,now-TRK.air_edge) if TRK.jump_fresh and since<=0.2 then local impulse=vy+grav()*since if impulse>1 then if JL.seen then JL.v=JL.v*0.7+impulse*0.3 else JL.v=impulse JL.seen=true end if impulse>TRK.jump_v then TRK.jump_v=impulse end end else TRK.jump_fresh=false end end end TRK.vel=fresh TRK.ready=fit~=nil or fast~=nil TRK.fresh=TRK.vel TRK.fresh_ok=TRK.ready TRK.turn=turn local raw=instant or fresh vel_push(now,raw.X,raw.Z) end
    local function raw_rtt() local a,b local ok,ms=pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end) if ok and type(ms)=="number" and ms==ms and ms>4 and ms<800 then a=ms/1000 end local fine,v=pcall(function() return LocalPlayer:GetNetworkPing() end) if fine and type(v)=="number" and v==v and v>0 then local rtt=v*2 if rtt>0.004 and rtt<0.8 then b=rtt end end if a and b then return (a+b)*0.5 end return a or b end
    local function sample_ping() local rtt=raw_rtt() if not rtt or rtt~=rtt then return end rtt=math.clamp(rtt,0,1) if EC.seen then EC.jitter=EC.jitter*0.9+math.abs(rtt-EC.rtt)*0.1 EC.rtt=EC.rtt*0.82+rtt*0.18 else EC.rtt=rtt EC.jitter=0 EC.seen=true end EC.ping=EC.rtt end
    local function lead_time() if not EC.seen then return 0 end local stale=0 if TRK.time>0 and EC.step_seen then stale=math.clamp(os.clock()-TRK.time,0,EC.step) end return math.clamp(EC.rtt+EC.jitter*0.5+stale,0,1) end
    local function rotate_y(v,ang) local c,s=math.cos(ang),math.sin(ang) return Vector3.new(v.X*c-v.Z*s,v.Y,v.X*s+v.Z*c) end
    local function dir_stats(win) if SK.vn<4 then return 1,0 end win=math.max(win,sample_span()*3) local newest=SK.vt[SK.vi] local sx,sz,n=0,0,0 local prev=nil local turn,turn_n=0,0 local oldest=newest for k=0,SK.vn-1 do local idx=(SK.vi-k-1)%P.ring+1 local t=SK.vt[idx] if newest-t>win then break end local hx,hz=SK.dx[idx],SK.dz[idx] local m=math.sqrt(hx*hx+hz*hz) if m>0 then sx=sx+hx/m sz=sz+hz/m n=n+1 local ang=math.atan2(hz,hx) if prev then local d=ang-prev while d>math.pi do d=d-6.2831853 end while d<-math.pi do d=d+6.2831853 end turn=turn+d turn_n=turn_n+1 end prev=ang oldest=t end end if n<2 then return 1,0 end local coh=math.clamp(math.sqrt(sx*sx+sz*sz)/n,0,1) local omega=0 local elapsed=newest-oldest if turn_n>=1 and elapsed>1e-3 then omega=-turn/elapsed end return coh,omega end
    local function predict_from(base,sa,sb,fh,now) local span=math.max(0,sa+sb) local g=grav() local dir=fh if dir.Magnitude==0 then dir=Vector3.new(TRK.vel.X,0,TRK.vel.Z) end local x,z if span>0 and KIN.ok then local age=math.clamp(now-TRK.time,0,sample_span()*2) local ax,az=KIN.ax,KIN.az if TRK.air or math.sqrt(ax*ax+az*az)<P.acc_min then ax,az=0,0 end local vx=dir.X+ax*age local vz=dir.Z+az*age local ta=math.min(span,P.acc_t) local dx=vx*span+0.5*ax*ta*ta local dz=vz*span+0.5*az*ta*ta local reach=math.sqrt(dx*dx+dz*dz) local cap=math.max(KIN.smax*P.speed_head,P.speed_floor)*span if reach>cap and reach>1e-6 then dx=dx*cap/reach dz=dz*cap/reach end x=base.X+dx z=base.Z+dz else local hspan=span if span>0 and dir.Magnitude>0 and not TRK.air then local coh,omega=dir_stats(span) local conf=math.clamp(coh,0,1)*(1-math.clamp(TRK.turn,0,1)*0.5) if omega~=0 then dir=rotate_y(dir,math.clamp(omega*span*0.5*conf,-0.6,0.6)) end hspan=span*(0.85+0.15*conf) end x=base.X+dir.X*hspan z=base.Z+dir.Z*hspan end local y=base.Y if TRK.air and span>0 then local vy=TRK.vel.Y local phase=math.max(0,now-TRK.air_since) local modeled=TRK.jump_v-g*phase if TRK.jumping and TRK.jump_v>0 and g>0 and phase<=TRK.jump_v/g and modeled>vy then vy=modeled end y=base.Y+vy*span-0.5*g*span*span if y<base.Y then local clearance=stand_clearance() local reach=base.Y-y+clearance local gy=ground_below(Vector3.new(x,base.Y,z),reach) if gy then local floor=gy+clearance if y<floor then y=floor end end end end return Vector3.new(x,y,z) end
    local function build_hyps(base,now) table.clear(HY.pos) table.clear(HY.w) local horizon=silent.predict and TRK.ready and lead_time() or 0 local fh=Vector3.new(TRK.fresh.X,0,TRK.fresh.Z) HY.primary=predict_from(base,0,horizon,fh,now) HY.n=1 HY.pos[1]=HY.primary HY.w[1]=1 HY.weight=1 HY.stamp=now end
    local axis_pool={}
    local function corridor_axes(anchor) table.clear(axis_pool) local n=0 local function add(v) if typeof(v)~="Vector3" or v.Magnitude<1e-4 then return end local u=v.Unit for k=1,n do if axis_pool[k]:Dot(u)>0.985 then return end end n=n+1 axis_pool[n]=u end local fh=Vector3.new(TRK.fresh.X,0,TRK.fresh.Z) if TRK.air then add(TRK.fresh) end add(fh) for k=1,HY.n do add(HY.pos[k]-anchor) end add(TRK.fresh) add(Vector3.new(0,1,0)) return n end
    local function score_axis(anchor,axis) local covered=0 local lo,hi=0,0 for k=1,HY.n do local d=HY.pos[k]-anchor local a=d:Dot(axis) local perp=(d-axis*a).Magnitude if perp<=P.hit_r then covered=covered+HY.w[k] if a<lo then lo=a end if a>hi then hi=a end end end return covered,lo,hi end
    local function build_corridor(now) local part=TRK.part if not part or not part.Parent then return nil end local base=part.Position build_hyps(base,now) local anchor=HY.primary or base local count=corridor_axes(anchor) local best_axis,best_cov,best_lo,best_hi=nil,-1,0,0 for k=1,count do local axis=axis_pool[k] local cov,lo,hi=score_axis(anchor,axis) if cov>best_cov then best_axis,best_cov,best_lo,best_hi=axis,cov,lo,hi end end if not best_axis then return nil end HY.conf=HY.weight>0 and best_cov/HY.weight or 0 local pad=P.pad local origin=anchor+best_axis*(best_lo-pad) local aim=anchor+best_axis*(best_hi+pad) if (aim-origin).Magnitude<4 then origin=anchor-best_axis*4 aim=anchor+best_axis*4 end return origin,aim,HY.conf,anchor end
    local function lead_offset() local part=TRK.part if not part or not part.Parent then return Vector3.zero end if not silent.predict or not TRK.ready then return Vector3.zero end local base=part.Position local now=os.clock() local fh=Vector3.new(TRK.fresh.X,0,TRK.fresh.Z) local point=predict_from(base,0,lead_time(),fh,now) return point-base end
    local trace_params=RaycastParams.new() trace_params.FilterType=Enum.RaycastFilterType.Exclude trace_params.IgnoreWater=false local ignore_base,ignore_work={},{}
    local function refresh_ignore() table.clear(ignore_base) local char=LocalPlayer.Character if char then ignore_base[1]=char end local ok,tagged=pcall(function() return CollectionService:GetTagged("WeaponPassthrough") end) if ok and type(tagged)=="table" then for k=1,#tagged do ignore_base[#ignore_base+1]=tagged[k] end end end
    local function trace(origin,direction) refresh_ignore() table.clear(ignore_work) for k=1,#ignore_base do ignore_work[k]=ignore_base[k] end local result=nil for _=1,6 do trace_params.FilterDescendantsInstances=ignore_work result=Workspace:Raycast(origin,direction,trace_params) if not result then break end local inst=result.Instance if not inst then break end local ok,tr=pcall(function() return inst.Transparency end) if not ok or tr~=1 then break end ignore_work[#ignore_work+1]=inst end return result end
    local function los_clear(origin,point) if not origin or not point then return false end local delta=point-origin local dist=delta.Magnitude if dist<0.5 then return true end if dist>MAX_RANGE then return false end local hit=trace(origin,delta) if not hit then return true end local inst=hit.Instance local char=TRK.char if inst and char and (inst==char or inst:IsDescendantOf(char)) then return true end return (hit.Position-origin).Magnitude>=dist-0.75 end
    local hit_names={"HumanoidRootPart","UpperTorso","Torso","LowerTorso","Head","RightUpperArm","LeftUpperArm","Right Arm","Left Arm","RightUpperLeg","LeftUpperLeg","Right Leg","Left Leg","RightLowerLeg","LeftLowerLeg"}
    local hit_parts,hit_count,hit_char={},0,nil
    local function refresh_parts() local char=TRK.char if char==hit_char then return end table.clear(hit_parts) hit_count=0 hit_char=char if not char then return end for k=1,#hit_names do local part=char:FindFirstChild(hit_names[k]) if part and part:IsA("BasePart") then hit_count=hit_count+1 hit_parts[hit_count]=part end end end
    local function getGunOrigin() local c=LocalPlayer.Character if not c then return nil end local hrp=c:FindFirstChild("HumanoidRootPart") if not hrp then return nil end local att=hrp:FindFirstChild("GunRaycastAttachment") if att then return att.WorldCFrame end return hrp.CFrame end
    local function pick_point(origin,strict) refresh_parts() if hit_count==0 then return nil end local off=lead_offset() local first=nil for k=1,hit_count do local part=hit_parts[k] if not part.Parent then hit_char=nil else local point=part.Position+off if not origin then return point end if not first then first=point end if los_clear(origin,point) then return point end end end if strict then return nil end return first end
    local force_att,force_saved=nil,nil
    local function restore_origin() local att=force_att if not att then return end local saved=force_saved force_att,force_saved=nil,nil if saved then pcall(function() if att.Parent then att.CFrame=saved end end) end end
    local function push_origin(cf) local c=LocalPlayer.Character if not c then return false end local hrp=c:FindFirstChild("HumanoidRootPart") if not hrp then return false end local att=hrp:FindFirstChild("GunRaycastAttachment") if not att then return false end if force_att and force_att~=att then restore_origin() end if not force_att then local ok,saved=pcall(function() return att.CFrame end) if not ok or typeof(saved)~="CFrame" then return false end force_att=att force_saved=saved end local ok=pcall(function() att.WorldCFrame=cf end) if not ok then restore_origin() return false end task.defer(restore_origin) return true end
    local function force_clear(origin,aim) local hit=trace(origin,aim-origin) if not hit then return false end local char=TRK.char if not char then return false end return hit.Instance==char or hit.Instance:IsDescendantOf(char) end
    local function force_velocity() if TRK.fresh_ok and TRK.fresh.Magnitude>0.5 then return TRK.fresh end if TRK.ready and TRK.vel.Magnitude>0.5 then return TRK.vel end return Vector3.zero end
    local function resolve_force() local part=TRK.part if not part or not part.Parent then return nil end local live=part.Position local now=os.clock() local origin,aim,conf,anchor=build_corridor(now) if origin and aim then local axis=aim-origin local span=axis.Magnitude if span>1e-3 then local u=axis/span local mark=anchor or live local behind=(mark-origin):Dot(u) if behind<P.pad then origin=origin-u*(P.pad-behind) end local ahead=(aim-mark):Dot(u) if ahead<P.min_span then aim=mark+u*P.min_span end local want=silent.standoff while want>0 do local probe=origin-u*want if (aim-probe).Magnitude<=P.max_span and los_clear(probe,mark) and los_clear(probe,live) then origin=probe break end want=want-3 end if (aim-origin).Magnitude>P.max_span then origin=aim-u*P.max_span end return CFrame.new(origin,aim),CFrame.new(aim),conf or 0,mark end end local vel=force_velocity() local dir=Vector3.new(0,-1,0) if vel.Magnitude>3 then dir=vel.Unit else local mine=getGunOrigin() if mine then local delta=live-mine.Position if delta.Magnitude>2 then dir=delta.Unit end end end local back=live-dir*6 local front=live+dir*math.max(P.min_span,vel.Magnitude*lead_time()+8) if not force_clear(back,front) then back=live-dir*2.5 end return CFrame.new(back,front),CFrame.new(front),0,live end
    local function resolve_shot() if not silent.enabled then return nil end if not TRK.part or not TRK.part.Parent then return nil end if TRK.hum and TRK.hum.Health<=0 then return nil end if silent.force then local origin_cf,aim_cf=resolve_force() if origin_cf and aim_cf then if push_origin(origin_cf) then return aim_cf end end end local cf=getGunOrigin() local aim=pick_point(cf and cf.Position or nil,false) if not aim then return nil end return CFrame.new(aim) end
    local weapon_service,orig_mouse,orig_screen
    local function getWeaponService() if weapon_service then return weapon_service end local ok,m=pcall(function() return require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("WeaponService")) end) if ok and type(m)=="table" then weapon_service=m end return weapon_service end
    local function install_hooks() local m=getWeaponService() if not m then return end pcall(function() setreadonly(m,false) end) if type(m.GetMouseTargetCFrame)=="function" and not orig_mouse then orig_mouse=m.GetMouseTargetCFrame local old=orig_mouse m.GetMouseTargetCFrame=function(self,...) sample_ping() if silent.enabled then local ok,cf=pcall(resolve_shot) if ok and cf then return cf end end return old(self,...) end end if type(m.GetTargetPosition)=="function" and not orig_screen then orig_screen=m.GetTargetPosition local old=orig_screen m.GetTargetPosition=function(self,x,y,...) sample_ping() if silent.enabled then local ok,cf=pcall(resolve_shot) if ok and cf then return cf end end return old(self,x,y,...) end end end
    local function uninstall_hooks() if not weapon_service then return end pcall(function() setreadonly(weapon_service,false) end) if orig_mouse then pcall(function() weapon_service.GetMouseTargetCFrame=orig_mouse end) end if orig_screen then pcall(function() weapon_service.GetTargetPosition=orig_screen end) end end
    local function findMurderer() local d=getRoundData() if type(d)=="table" then for name,info in pairs(d) do if type(info)=="table" and info.Role=="Murderer" and not info.Dead then local p=Players:FindFirstChild(name) if p then return p end end end end return isMurderer() end
    local function updateTarget() local t=findMurderer() if t~=TRK.target then TRK.target=t TRK.char=t and t.Character or nil TRK.part=nil TRK.hum=nil TRK.ready=false snap_n,snap_i=0,0 end if not t or not t.Character then return end if t.Character~=TRK.char then TRK.char=t.Character TRK.part=nil TRK.hum=nil end if not TRK.part or not TRK.part.Parent then TRK.part=t.Character:FindFirstChild("HumanoidRootPart") or t.Character:FindFirstChild("UpperTorso") or t.Character:FindFirstChild("Torso") end if not TRK.hum or not TRK.hum.Parent then TRK.hum=t.Character:FindFirstChildOfClass("Humanoid") end end
    AddConn("SilentTick",RunService.Heartbeat:Connect(function()
        if not silent.enabled then return end
        local now=os.clock()
        pcall(updateTarget)
        pcall(track,now)
    end))
    getgenv().FH_ShootSilent=function()
        if not silent.enabled then return end
        local char=LocalPlayer.Character
        if not char then return end
        local gun=char:FindFirstChild("Gun")
        if not gun then
            local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
            gun=bp and bp:FindFirstChild("Gun")
        end
        if not gun then return end
        if gun.Parent~=char then
            local hum=char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(gun) end
            task.wait(0.05)
        end
        pcall(function() gun:Activate() end)
    end
    task.spawn(function() task.wait(1) pcall(install_hooks) end)
    AddConn("SilentHookRetry",RunService.Heartbeat:Connect(function()
        if silent.enabled and not orig_mouse then pcall(install_hooks) end
    end))
    local tC=Tabs.Combat
    local silentSec=tC:AddSection({Name="Тихий выстрел"})
    silentSec:AddToggle("SilentEnabled",{Title="Включить тихий выстрел",Default=false}):OnChanged(function(v)
        silent.enabled=v
        if v then task.spawn(function() pcall(install_hooks) pcall(updateTarget) end)
        else pcall(uninstall_hooks) end
        Notify("FH","Silent "..(v and "ВКЛ" or "ВЫКЛ"),1.5)
    end)
    silentSec:AddToggle("SilentPredict",{Title="Предсказание",Default=true}):OnChanged(function(v) silent.predict=v end)
    silentSec:AddToggle("SilentForce",{Title="Стрельба через стены",Default=false}):OnChanged(function(v) silent.force=v end)
    silentSec:AddSlider("SilentStandoff",{Title="Отступ (студы)",Min=0,Max=40,Default=15,Rounding=0}):OnChanged(function(v) silent.standoff=tonumber(v) or 15 end)
    local silentBindOpt=silentSec:AddKeybind("SilentBind",{Title="Кнопка выстрела",Default="E"})
    silentBindOpt:OnChanged(function(k)
        if typeof(k)=="EnumItem" then silent.bindKey=k Notify("FH","Кнопка: "..tostring(k),2) end
    end)
    UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe then return end
        if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==silent.bindKey then
            if silent.enabled and getgenv().FH_ShootSilent then pcall(getgenv().FH_ShootSilent) end
        end
    end)
    local knifeSec=tC:AddSection({Name="Тихий бросок ножа"})
    knifeSec:AddToggle("KnifeSilentOn",{Title="Включить",Default=false}):OnChanged(function(v)
        knifeSilent.enabled=v
        Notify("FH","Knife Silent "..(v and "ВКЛ" or "ВЫКЛ"),1.5)
    end)
    knifeSec:AddToggle("KnifeInsta",{Title="Insta Kill",Default=true}):OnChanged(function(v) knifeSilent.instaKill=v end)
    knifeSec:AddToggle("KnifePredict",{Title="Предсказание",Default=true}):OnChanged(function(v) knifeSilent.predict=v end)
    knifeSec:AddSlider("KnifeRadius",{Title="Радиус (студы)",Min=5,Max=60,Default=20,Rounding=0}):OnChanged(function(v) knifeSilent.radius=tonumber(v) or 20 end)
    knifeSec:AddSlider("KnifeFov",{Title="FOV",Min=10,Max=360,Default=120,Rounding=0}):OnChanged(function(v) knifeSilent.fov=tonumber(v) or 120 end)
    knifeSec:AddToggle("KnifeShowFov",{Title="Показывать круг FOV",Default=true}):OnChanged(function(v) knifeSilent.showFov=v end)
    knifeSec:AddToggle("KnifeCheckWalls",{Title="Проверять стены",Default=false}):OnChanged(function(v) knifeSilent.checkWalls=v end)
    local knifeBindOpt=knifeSec:AddKeybind("KnifeBind",{Title="Кнопка броска",Default="R"})
    knifeBindOpt:OnChanged(function(k)
        if typeof(k)=="EnumItem" then knifeSilent.bindKey=k Notify("FH","Нож: "..tostring(k),2) end
    end)
    local function throwKnifeAtNearest()
        if not knifeSilent.enabled then Notify("FH","Включи тихий бросок ножа",2) return end
        local char=LocalPlayer.Character
        if not char then return end
        local knife=char:FindFirstChild("Knife")
        if not knife then
            local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
            knife=bp and bp:FindFirstChild("Knife")
            if knife then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum:EquipTool(knife) end task.wait(0.05) end
        end
        if not knife then Notify("FH","Нужен нож",2) return end
        local myHRP=char:FindFirstChild("HumanoidRootPart")
        if not myHRP then return end
        local best,bestDist=nil,math.huge
        local myPos=myHRP.Position
        local cam=Workspace.CurrentCamera
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local tHRP=p.Character:FindFirstChild("HumanoidRootPart")
                local tHum=p.Character:FindFirstChildOfClass("Humanoid")
                if tHRP and tHum and tHum.Health>0 then
                    local dist=(tHRP.Position-myPos).Magnitude
                    if dist<=knifeSilent.radius then
                        if cam then
                            local sp,on=cam:WorldToViewportPoint(tHRP.Position)
                            if on then
                                local center=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
                                local angle=math.deg(math.atan2(sp.Y-center.Y,sp.X-center.X))
                                if math.abs(angle)<=knifeSilent.fov/2 then
                                    if knifeSilent.checkWalls then
                                        local ray=Ray.new(myPos,(tHRP.Position-myPos).Unit*dist)
                                        local hitPart=Workspace:FindPartOnRay(ray,char)
                                        if hitPart and hitPart:IsDescendantOf(p.Character) and dist<bestDist then bestDist=dist best=tHRP end
                                    elseif dist<bestDist then bestDist=dist best=tHRP end
                                end
                            end
                        elseif dist<bestDist then bestDist=dist best=tHRP end
                    end
                end
            end
        end
        if not best then Notify("FH","Цель не найдена",2) return end
        local events=knife:FindFirstChild("Events")
        if events then
            local throwRemote=events:FindFirstChild("KnifeThrown") or events:FindFirstChild("Throw")
            if throwRemote then pcall(function() throwRemote:FireServer(best) end) end
        end
        pcall(function() knife:Activate() end)
        Notify("FH","Нож брошен!",1.5)
    end
    getgenv().FH_ThrowKnife=throwKnifeAtNearest
    UserInputService.InputBegan:Connect(function(input,gpe)
        if gpe then return end
        if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==knifeSilent.bindKey then
            throwKnifeAtNearest()
        end
    end)
    local fovCircle=Drawing.new("Circle")
    fovCircle.Thickness=1 fovCircle.Color=Color3.fromRGB(255,255,255)
    fovCircle.Transparency=0.7 fovCircle.NumSides=64
    fovCircle.Radius=knifeSilent.fov fovCircle.Filled=false fovCircle.Visible=false
    AddConn("KnifeFovTick",RunService.RenderStepped:Connect(function()
        if knifeSilent.showFov and knifeSilent.enabled then
            fovCircle.Visible=true
            fovCircle.Position=UserInputService:GetMouseLocation()
            fovCircle.Radius=knifeSilent.fov
        else fovCircle.Visible=false end
    end))
    local kaSec=tC:AddSection({Name="Килл Аура"})
    kaSec:AddDropdown("KAVersion",{Title="Версия",Values={"v1","v2"},Default="v2"}):OnChanged(function(v)
        killAuraVersion=v
        kaV1.on=false kaV2.on=false
        if Options.KAOn and Options.KAOn.Value then kaV1.on=v=="v1" kaV2.on=v=="v2" end
    end)
    kaSec:AddToggle("KAOn",{Title="Включить",Default=false}):OnChanged(function(v)
        kaV1.on=v and killAuraVersion=="v1"
        kaV2.on=v and killAuraVersion=="v2"
    end)
    kaSec:AddSlider("KADist",{Title="Радиус",Min=5,Max=60,Default=30,Rounding=0}):OnChanged(function(v)
        local n=tonumber(v) or 30 kaV1.dist=n kaV2.dist=n
    end)
    AddConn("KAv1Tick",RunService.Heartbeat:Connect(function()
        if not kaV1.on then return end
        if tick()-kaV1.lastHit<0.05 then return end
        local char=LocalPlayer.Character if not char then return end
        local knife=char:FindFirstChild("Knife") if not knife then return end
        local ev=knife:FindFirstChild("Events") if not ev then return end
        local stabbed=ev:FindFirstChild("KnifeStabbed") local touched=ev:FindFirstChild("HandleTouched")
        if not stabbed or not touched then return end
        local my=char:FindFirstChild("HumanoidRootPart") if not my then return end
        local victims={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer then
                local tc=p.Character
                if tc then
                    local th=tc:FindFirstChildOfClass("Humanoid")
                    local tp=tc:FindFirstChild("HumanoidRootPart")
                    if th and th.Health>0 and tp and (tp.Position-my.Position).Magnitude<=kaV1.dist then victims[#victims+1]=tp end
                end
            end
        end
        if #victims>0 then
            pcall(function() stabbed:FireServer() end)
            for _,v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            kaV1.lastHit=tick()
        end
    end))
    AddConn("KAv2Tick",RunService.Heartbeat:Connect(function()
        if not kaV2.on then return end
        if tick()-kaV2.lastHit<0.05 then return end
        local char=LocalPlayer.Character if not char then return end
        local knife=char:FindFirstChild("Knife")
        if not knife then
            local hum=char:FindFirstChildOfClass("Humanoid")
            local bpk=LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife")
            if hum and bpk then hum:EquipTool(bpk) end
            return
        end
        local ev=knife:FindFirstChild("Events") if not ev then return end
        local stabbed=ev:FindFirstChild("KnifeStabbed") local touched=ev:FindFirstChild("HandleTouched")
        if not stabbed or not touched then return end
        local my=char:FindFirstChild("HumanoidRootPart") if not my then return end
        local victims={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer then
                local tc=p.Character
                if tc then
                    local th=tc:FindFirstChildOfClass("Humanoid")
                    local tp=tc:FindFirstChild("HumanoidRootPart")
                    if th and th.Health>0 and tp and (tp.Position-my.Position).Magnitude<=kaV2.dist then victims[#victims+1]=tp end
                end
            end
        end
        if #victims>0 then
            pcall(function() stabbed:FireServer() end)
            for _,v in ipairs(victims) do pcall(function() touched:FireServer(v) end) end
            kaV2.lastHit=tick()
        end
    end))
    local grabFailedRound,isGrabbing=false,false
    local gunCache={}
    for _,v in ipairs(Workspace:GetDescendants()) do if v.Name=="GunDrop" then gunCache[v]=true end end
    AddConn("GunCacheAdd",Workspace.DescendantAdded:Connect(function(v) if v.Name=="GunDrop" then gunCache[v]=true end end))
    AddConn("GunCacheRem",Workspace.DescendantRemoving:Connect(function(v) if v.Name=="GunDrop" then gunCache[v]=nil end end))
    task.spawn(function()
        local ok,remote=pcall(function() return ReplicatedStorage:WaitForChild("Remotes",15):WaitForChild("Gameplay",15):WaitForChild("CoinsStarted",15) end)
        if ok and remote then remote.OnClientEvent:Connect(function() grabFailedRound=false isGrabbing=false end) end
    end)
    local function findNearestGun(my)
        local best,bd=nil,math.huge
        for gun in pairs(gunCache) do
            if gun.Parent and gun:IsA("BasePart") then
                local d=(gun.Position-my.Position).Magnitude
                if d<bd then bd=d best=gun end
            end
        end
        return best
    end
    local autoGrabEnabled=false
    tC:AddToggle("AutoGrabGun",{Title="Авто-подбор пистолета",Default=false}):OnChanged(function(v) autoGrabEnabled=v end)
    AddConn("AutoGrabTick",RunService.Heartbeat:Connect(function()
        if not autoGrabEnabled then return end
        if getgenv().FH_INVIS_ACTIVE then return end
        if getRoleFromData(LocalPlayer)=="murderer" then return end
        if grabFailedRound or isGrabbing then return end
        local char=LocalPlayer.Character if not char then return end
        if char:FindFirstChild("Gun") then return end
        local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp and bp:FindFirstChild("Gun") then return end
        local my=char:FindFirstChild("HumanoidRootPart") if not my then return end
        local gun=findNearestGun(my) if not gun then return end
        isGrabbing=true
        task.spawn(function()
            local rp=my.CFrame local grabbed=false
            for i=1,3 do
                if getgenv().FH_INVIS_ACTIVE then break end
                if my and my.Parent then my.CFrame=gun.CFrame end
                task.wait(0.04)
                pcall(function() firetouchinterest(my,gun,0) task.wait(0.02) firetouchinterest(my,gun,1) end)
                local c=LocalPlayer.Character
                if c and c:FindFirstChild("Gun") then grabbed=true break end
                local b=LocalPlayer:FindFirstChildOfClass("Backpack")
                if b and b:FindFirstChild("Gun") then grabbed=true break end
            end
            if my and my.Parent then
                my.CFrame=rp
                my.AssemblyLinearVelocity=Vector3.zero
                my.AssemblyAngularVelocity=Vector3.zero
            end
            if not grabbed then grabFailedRound=true Notify("FH","Пистолет не подобран.",4) end
            isGrabbing=false
        end)
    end))
    AddConn("AutoGrabReset",LocalPlayer.CharacterAdded:Connect(function() isGrabbing=false end))
    getgenv().SILENT_UNLOAD=function()
        silent.enabled=false silent.predict=false silent.force=false
        restore_origin() track_clear() pcall(uninstall_hooks)
    end
end
do
    local tM=Tabs.Movement
    local mvSec=tM:AddSection({Name="Основное"})
    mvSec:AddToggle("SpeedToggle",{Title="Скорость",Default=false})
    mvSec:AddSlider("SpeedValue",{Title="Скорость ходьбы",Min=16,Max=500,Default=32,Rounding=0})
    mvSec:AddToggle("Noclip",{Title="Noclip",Default=false})
    mvSec:AddToggle("Spinbot",{Title="Spinbot",Default=false})
    mvSec:AddSlider("SpinSpeed",{Title="Скорость кручения",Min=1,Max=50,Default=8,Rounding=0})
    mvSec:AddToggle("InfJump",{Title="Бесконечный прыжок",Default=false})
    mvSec:AddToggle("JumpPowerToggle",{Title="Своя сила прыжка",Default=false})
    mvSec:AddSlider("JumpPowerVal",{Title="Сила прыжка",Min=50,Max=500,Default=100,Rounding=0})
    mvSec:AddToggle("FlyToggle",{Title="Полёт",Default=false})
    mvSec:AddSlider("FlySpeed",{Title="Скорость полёта",Min=20,Max=500,Default=60,Rounding=0})
    mvSec:AddToggle("BhopOn",{Title="Банихоп",Default=false})
    mvSec:AddSlider("BhopPower",{Title="Сила банихопа",Min=10,Max=150,Default=40,Rounding=0})
    mvSec:AddToggle("BhopStrafe",{Title="Стрейф",Default=false})
    mvSec:AddToggle("BhopAuto",{Title="Авто-стрейф",Default=false})
    local bhopOn,bhopPower,bhopStrafe,bhopAuto=false,40,false,false
    local bhopSpeed,wasJumping,isBoosting=0,false,false
    local lastCamYaw,jumpHoldAt=nil,0
    if Options.BhopOn then Options.BhopOn:OnChanged(function(v) bhopOn=v end) end
    if Options.BhopPower then Options.BhopPower:OnChanged(function(v) bhopPower=tonumber(v) or 40 end) end
    if Options.BhopStrafe then Options.BhopStrafe:OnChanged(function(v) bhopStrafe=v end) end
    if Options.BhopAuto then Options.BhopAuto:OnChanged(function(v) bhopAuto=v end) end
    UserInputService.JumpRequest:Connect(function() jumpHoldAt=os.clock() end)
    local function jumpHeld()
        if os.clock()-jumpHoldAt<0.2 then return true end
        return UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end
    local function camYaw()
        local cam=Workspace.CurrentCamera
        if not cam then return nil end
        local l=cam.CFrame.LookVector
        return math.atan2(-l.X,-l.Z)
    end
    AddConn("BhopTick",RunService.Heartbeat:Connect(function()
        if not bhopOn then wasJumping=false isBoosting=false bhopSpeed=0 lastCamYaw=nil return end
        local c=LocalPlayer.Character
        local hum=c and c:FindFirstChildOfClass("Humanoid")
        local hrp=c and c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local st=hum:GetState()
        local jumping=st==Enum.HumanoidStateType.Jumping
        local airborne=jumping or st==Enum.HumanoidStateType.Freefall
        if bhopStrafe or bhopAuto then
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
                if bhopAuto then
                    local yaw=camYaw()
                    if yaw and lastCamYaw then
                        local delta=yaw-lastCamYaw
                        while delta>math.pi do delta=delta-math.pi*2 end
                        while delta<-math.pi do delta=delta+math.pi*2 end
                        if math.abs(delta)>0.0005 then
                            local v=hrp.AssemblyLinearVelocity
                            local xz=Vector3.new(v.X,0,v.Z)
                            if xz.Magnitude>1 then
                                local rot=CFrame.fromEulerAnglesYXZ(0,delta,0)*xz
                                hrp.AssemblyLinearVelocity=Vector3.new(rot.X,v.Y,rot.Z)
                            end
                        end
                    end
                end
                local dir=hum.MoveDirection
                if dir.Magnitude>0.1 then
                    dir=Vector3.new(dir.X,0,dir.Z).Unit
                    local v=hrp.AssemblyLinearVelocity
                    local cur=Vector3.new(v.X,0,v.Z)
                    local tgt=dir*bhopPower
                    local nxz=cur:Lerp(tgt,0.3)
                    hrp.AssemblyLinearVelocity=Vector3.new(nxz.X,v.Y,nxz.Z)
                elseif bhopAuto then
                    local v=hrp.AssemblyLinearVelocity
                    local xz=Vector3.new(v.X,0,v.Z)
                    if xz.Magnitude>0.1 and xz.Magnitude<bhopPower then
                        local kp=xz.Unit*bhopPower
                        hrp.AssemblyLinearVelocity=Vector3.new(kp.X,v.Y,kp.Z)
                    end
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
        lastCamYaw=camYaw()
        wasJumping=jumping
    end))
    local sgOn,sgPower,sgAccel,sgGround=false,90,0.6,16
    mvSec:AddToggle("SpeedGlitchOn",{Title="Спидглитч",Default=false}):OnChanged(function(v) sgOn=v end)
    mvSec:AddSlider("SpeedGlitchPower",{Title="Скорость в прыжке",Min=30,Max=250,Default=90,Rounding=0}):OnChanged(function(v) sgPower=tonumber(v) or 90 end)
    mvSec:AddSlider("SpeedGlitchAccel",{Title="Разгон (0-1)",Min=0.1,Max=1,Default=0.6,Rounding=2}):OnChanged(function(v) sgAccel=tonumber(v) or 0.6 end)
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
    local flyGrav=Workspace.Gravity
    if Options.FlyToggle then
        Options.FlyToggle:OnChanged(function(v)
            if v then flyGrav=Workspace.Gravity Workspace.Gravity=0
            else Workspace.Gravity=flyGrav local hrp=getHRP() if hrp then hrp.AssemblyLinearVelocity=Vector3.zero end end
        end)
    end
    AddConn("FlyTick",RunService.RenderStepped:Connect(function()
        if not (Options.FlyToggle and Options.FlyToggle.Value) then return end
        local hrp=getHRP() local hum=getHum()
        if not hrp or not hum then return end
        hum.PlatformStand=true
        local sp=(Options.FlySpeed and tonumber(Options.FlySpeed.Value)) or 60
        local dir=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir-Vector3.new(0,1,0) end
        hrp.Velocity=dir.Magnitude>0 and dir.Unit*sp or Vector3.zero
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
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-Camera.CFrame.RightVector end
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
    freezeSec:AddToggle("FreezeToggle",{Title="Включить заморозку",Default=false}):OnChanged(function(v) S.frozen=v end)
    freezeSec:AddSlider("FreezeSpeed",{Title="Скорость заморозки",Min=20,Max=300,Default=60,Rounding=0})
    local fUp=freezeSec:AddKeybind("FreezeUpKey",{Title="Кнопка ВВЕРХ",Default="Space"})
    fUp:OnChanged(function(k) if typeof(k)=="EnumItem" then S.freezeUpKey=k end end)
    local fDown=freezeSec:AddKeybind("FreezeDownKey",{Title="Кнопка ВНИЗ",Default="LeftAlt"})
    fDown:OnChanged(function(k) if typeof(k)=="EnumItem" then S.freezeDownKey=k end end)
    getgenv().MOVE_UNLOAD=function()
        S.frozen=false
        local hrp=getHRP()
        if hrp then local bv=hrp:FindFirstChild("FH_FreezeBV") if bv then bv:Destroy() end end
        Workspace.Gravity=flyGrav
    end
end
do
    local tB=Tabs.Binds
    local BIND_LIST={
        {id="SilentEnabled",title="Тихий выстрел",cat="Бой",opt="SilentEnabled"},
        {id="SilentShoot",title="Выстрел (Shoot)",cat="Бой",action="ShootSilent"},
        {id="KnifeSilentOn",title="Тихий бросок ножа",cat="Бой",opt="KnifeSilentOn"},
        {id="KnifeThrow",title="Бросок ножа",cat="Бой",action="ThrowKnife"},
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
    }
    local BindState={}
    for _,e in ipairs(BIND_LIST) do
        BindState[e.id]={key=nil,touchOn=false,btn=nil,def=e}
    end
    local touchGui=Instance.new("ScreenGui")
    touchGui.Name="FH_TouchBinds_v184"
    touchGui.ResetOnSpawn=false
    touchGui.IgnoreGuiInset=true
    touchGui.DisplayOrder=400
    pcall(function() touchGui.Parent=(gethui and gethui()) or CoreGui end)
    if not touchGui.Parent then touchGui.Parent=CoreGui end
    local buttonsFrozen=false
    getgenv().FH_ButtonsFrozen=false
    local spawnPosY,spawnPosX=90,16
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
        elseif def.action=="ShootSilent" then
            if getgenv().FH_ShootSilent then pcall(getgenv().FH_ShootSilent) end
        elseif def.action=="ThrowKnife" then
            if getgenv().FH_ThrowKnife then pcall(getgenv().FH_ThrowKnife) end
        end
    end
    local function makeTouchButton(id)
        local st=BindState[id]
        if not st or st.btn then return end
        local def=st.def
        local btn=Instance.new("TextButton")
        btn.Name="FH_BTN_"..id
        btn.Size=UDim2.fromOffset(150,34)
        btn.Position=UDim2.fromOffset(spawnPosX,spawnPosY)
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
        spawnPosY=spawnPosY+40
        if spawnPosY>700 then spawnPosY=90 spawnPosX=spawnPosX+160 end
        local dragging,dragStart,posStart,moved=false,nil,nil,false
        btn.InputBegan:Connect(function(i)
            if getgenv().FH_ButtonsFrozen then return end
            if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                dragging=true moved=false
                dragStart=i.Position posStart=btn.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging or getgenv().FH_ButtonsFrozen then return end
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
            if wasTap and not getgenv().FH_ButtonsFrozen then fireBind(id) end
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
            pcall(function() listSec:AddButton({Title="=== "..currentCat.." ===",Callback=function() end}) end)
        end
        local st=BindState[def.id]
        listSec:AddKeybind("BIND_KEY_"..def.id,{Title=def.title,Default="Unknown"}):OnChanged(function(k)
            if typeof(k)=="EnumItem" then
                st.key=k
                Notify("FH","Бинд: "..def.title.." → "..tostring(k),2)
            else st.key=nil end
        end)
        listSec:AddToggle("BIND_TCH_"..def.id,{Title="  Кнопка: "..def.title,Default=false}):OnChanged(function(v)
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
    setSec:AddToggle("BIND_FREEZE",{Title="Заморозка кнопок",Default=false}):OnChanged(function(v)
        buttonsFrozen=v
        getgenv().FH_ButtonsFrozen=v
        Notify("FH",v and "Кнопки заморожены" or "Кнопки разморожены",1.5)
    end)
    setSec:AddButton({Title="Сбросить все бинды",Callback=function()
        for id,st in pairs(BindState) do
            st.key=nil
            if Options["BIND_KEY_"..id] then pcall(function() Options["BIND_KEY_"..id]:SetValue(nil) end) end
        end
        Notify("FH","Все бинды сброшены",2)
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
do
    local tS=Tabs.Settings
    local setSec=tS:AddSection({Name="Основные"})
    setSec:AddToggle("ShowHUD",{Title="Показывать HUD",Default=true}):OnChanged(function(v) if HUDGui then HUDGui.Enabled=v end end)
    setSec:AddSlider("FPSCap",{Title="Лимит FPS (0 = без лимита)",Min=0,Max=9999,Default=0,Rounding=0}):OnChanged(function(v) pcall(function() if setfpscap then setfpscap(tonumber(v) or 0) end end) end)
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
    setSec:AddToggle("AntiAFK",{Title="Anti-AFK",Default=true})
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
        if typeof(v)=="Color3" then return "C:"..tostring(v.R)..","..tostring(v.G)..","..tostring(v.B) end
        if typeof(v)=="EnumItem" then return "E:"..tostring(v.EnumType).."|"..v.Name end
        local t=type(v)
        if t=="number" then return "N:"..tostring(v) end
        if t=="boolean" then return "B:"..tostring(v) end
        if t=="string" then return "S:"..v end
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
        if prefix=="S" then return rest end
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
        for line in string.gmatch(data,"[^\r\n]+") do
            if line:sub(1,2)~="--" then
                local key,ser=string.match(line,"^([^\t]+)\t(.+)$")
                if key and ser then
                    local val=deserializeValue(ser)
                    if val~=nil and Options[key] then pcall(function() Options[key]:SetValue(val) end) loaded=loaded+1 end
                end
            end
        end
        Notify("FH","Загружено: "..name.." ("..loaded..")",3)
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
    cfgSec:AddButton({Title="Сохранить (Save)",Callback=function()
        local nameOpt=Options.ConfigName
        local name=nameOpt and nameOpt.Value or "my_config"
        if type(name)~="string" or name=="" then Notify("FH","Введи имя",3) return end
        if saveConfig(name) then refreshList() end
    end})
    cfgSec:AddButton({Title="Загрузить (Load)",Callback=function()
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
pcall(function() Window:SelectTab(1) end)
task.spawn(function()
    task.wait(1)
    Notify("FortniHub","Part 1/2 v18.4.0 загружена! 10 вкладок готовы. P — меню.",6)
end)
print("[FH] ============================================")
print("[FH] Part 1/2 — FortniHub v18.4.0 — "..CREDITS)
print("[FH] Все 10 вкладок созданы.")
print("[FH] ============================================")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local CoreGui=game:GetService("CoreGui")
local CollectionService=game:GetService("CollectionService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local SoundService=game:GetService("SoundService")
local TeleportService=game:GetService("TeleportService")
local Stats=game:GetService("Stats")
local HttpService=game:GetService("HttpService")
local Debris=game:GetService("Debris")
local LocalPlayer=Players.LocalPlayer
local Camera=Workspace.CurrentCamera
if not (Window and Options and Notify and getRoundData and getRoleFromData and getHRP and getHum) then
    warn("[FH] Part 1 не загружена.")
    return
end
local Tabs=getgenv().FH_Tabs
if not Tabs then warn("[FH] FH_Tabs не найден.") return end
local function uiRoot() return (gethui and gethui()) or CoreGui end
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
                                        line.Color=col
                                        line.Transparency=a
                                        line.Visible=true
                                    end
                                    for i=#lines+1,#e.box do e.box[i].Visible=false end
                                else
                                    local lines={{l,top,r,top},{r,top,r,bot},{r,bot,l,bot},{l,bot,l,top}}
                                    for i,ln in ipairs(lines) do
                                        local line=ensureBox(e,i)
                                        line.From=Vector2.new(ln[1],ln[2])
                                        line.To=Vector2.new(ln[3],ln[4])
                                        line.Color=col
                                        line.Transparency=a
                                        line.Visible=true
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
                                    e.name.Size=13
                                    e.name.Center=true
                                    e.name.Outline=true
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
                                    e.dist.Size=12
                                    e.dist.Center=true
                                    e.dist.Outline=true
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
                                    pcall(function()
                                        e.avatar.Data=Players:GetUserThumbnailAsync(p.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
                                    end)
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
                                            dr.Thickness=1
                                            dr.Transparency=1
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
                                        e.flags[1].Size=13
                                        e.flags[1].Outline=true
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
            if not seen[p] then
                dispose(e)
                drawCache[p]=nil
            end
        end
        updateMatChams()
        gunRender(dt)
    end)
    Players.PlayerRemoving:Connect(function(p) killCham(p) end)
    local tV=Tabs.Visual
    local espSec=tV:AddSection({Name="ESP Игроков"})
    espSec:AddToggle("ESPOn",{Title="Включить ESP",Default=false}):OnChanged(function(v)
        espState.enabled=v
        if not v then
            for _,e in pairs(drawCache) do dispose(e) end
            drawCache={}
        end
    end)
    espSec:AddToggle("ESPBox",{Title="Рамка",Default=false}):OnChanged(function(v) espState.box=v end)
    espSec:AddColorPicker("ESPBoxCol",{Title="Цвет рамки",Default=Color3.new(1,1,1)}):OnChanged(function(c) espState.boxCol[1]=c end)
    espSec:AddSlider("ESPBoxAlpha",{Title="Прозрачность рамки",Min=0,Max=1,Default=1,Rounding=2}):OnChanged(function(v) espState.boxCol[2]=tonumber(v) or 1 end)
    espSec:AddDropdown("ESPBoxType",{Title="Тип рамки",Values={"Прямоугольник","Уголки"},Default="Прямоугольник"}):OnChanged(function(v) espState.boxType=(v=="Уголки") and "Corners" or "Static" end)
    espSec:AddToggle("ESPBoxGrd",{Title="Градиент рамки",Default=false}):OnChanged(function(v) espState.boxGrd=v end)
    espSec:AddColorPicker("ESPBoxGrd1",{Title="Цвет 1",Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) espState.boxGrd1=c end)
    espSec:AddColorPicker("ESPBoxGrd2",{Title="Цвет 2",Default=Color3.fromRGB(255,180,60)}):OnChanged(function(c) espState.boxGrd2=c end)
    espSec:AddToggle("ESPBoxFill",{Title="Заливка",Default=false}):OnChanged(function(v) espState.boxFill=v end)
    espSec:AddColorPicker("ESPBoxFillCol",{Title="Цвет заливки",Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) espState.boxFillCol[1]=c end)
    espSec:AddSlider("ESPBoxFillAlpha",{Title="Прозрачность заливки",Min=0,Max=1,Default=0.5,Rounding=2}):OnChanged(function(v) espState.boxFillCol[2]=tonumber(v) or 0.5 end)
    espSec:AddToggle("ESPName",{Title="Имя",Default=false}):OnChanged(function(v) espState.name=v end)
    espSec:AddColorPicker("ESPNameCol",{Title="Цвет имени",Default=Color3.new(1,1,1)}):OnChanged(function(c) espState.nameCol[1]=c end)
    espSec:AddToggle("ESPDist",{Title="Дистанция",Default=false}):OnChanged(function(v) espState.dist=v end)
    espSec:AddColorPicker("ESPDistCol",{Title="Цвет дистанции",Default=Color3.fromRGB(220,220,220)}):OnChanged(function(c) espState.distCol[1]=c end)
    espSec:AddToggle("ESPAvatar",{Title="Аватарка",Default=false}):OnChanged(function(v) espState.avatar=v end)
    espSec:AddToggle("ESPSkel",{Title="Скелет",Default=false}):OnChanged(function(v) espState.skel=v end)
    espSec:AddColorPicker("ESPSkelCol",{Title="Цвет скелета",Default=Color3.new(1,1,1)}):OnChanged(function(c) espState.skelCol[1]=c end)
    espSec:AddToggle("ESPChams",{Title="Свечение (сквозь стены)",Default=false}):OnChanged(function(v) espState.chams=v end)
    local function chamsPair(prefix,role,defFill,defOut)
        espSec:AddColorPicker("ChamsF"..prefix,{Title=role.." заливка",Default=defFill}):OnChanged(function(c) espState["chamsF"..prefix][1]=c end)
        espSec:AddSlider("ChamsFA"..prefix,{Title=role.." прозр.",Min=0,Max=1,Default=0.55,Rounding=2}):OnChanged(function(v) espState["chamsF"..prefix][2]=tonumber(v) or 0.55 end)
        espSec:AddColorPicker("ChamsO"..prefix,{Title=role.." обводка",Default=defOut}):OnChanged(function(c) espState["chamsO"..prefix][1]=c end)
        espSec:AddSlider("ChamsOA"..prefix,{Title=role.." прозр. обводки",Min=0,Max=1,Default=0.15,Rounding=2}):OnChanged(function(v) espState["chamsO"..prefix][2]=tonumber(v) or 0.15 end)
    end
    chamsPair("Mur","Убийца",Color3.fromRGB(255,60,60),Color3.fromRGB(255,120,120))
    chamsPair("Inno","Мирный",Color3.new(1,1,1),Color3.new(1,1,1))
    chamsPair("Shf","Шериф",Color3.fromRGB(0,153,255),Color3.fromRGB(120,200,255))
    chamsPair("Hero","Герой",Color3.fromRGB(255,215,0),Color3.fromRGB(255,240,140))
    espSec:AddToggle("ESPMatChams",{Title="Материал-чамсы",Default=false}):OnChanged(function(v) espState.matChams=v end)
    espSec:AddDropdown("ESPMatType",{Title="Материал",Values={"ForceField","Flat","Chromatic"},Default="ForceField"}):OnChanged(function(v) espState.matType=v end)
    espSec:AddColorPicker("ESPMatMur",{Title="Убийца",Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) espState.matColMur=c end)
    espSec:AddColorPicker("ESPMatInno",{Title="Мирный",Default=Color3.new(1,1,1)}):OnChanged(function(c) espState.matColInno=c end)
    espSec:AddColorPicker("ESPMatShf",{Title="Шериф",Default=Color3.fromRGB(0,153,255)}):OnChanged(function(c) espState.matColShf=c end)
    espSec:AddColorPicker("ESPMatHero",{Title="Герой",Default=Color3.fromRGB(255,215,0)}):OnChanged(function(c) espState.matColHero=c end)
    espSec:AddToggle("ESPFlags",{Title="Метки ролей",Default=false}):OnChanged(function(v) espState.flags=v end)
    espSec:AddToggle("ESPArrows",{Title="Стрелки к игрокам",Default=false}):OnChanged(function(v) espState.arrows=v end)
    espSec:AddColorPicker("ESPArrMur",{Title="Убийца",Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c) espState.arrowMur=c end)
    espSec:AddColorPicker("ESPArrInno",{Title="Мирный",Default=Color3.new(1,1,1)}):OnChanged(function(c) espState.arrowInno=c end)
    espSec:AddColorPicker("ESPArrShf",{Title="Шериф",Default=Color3.fromRGB(0,153,255)}):OnChanged(function(c) espState.arrowShf=c end)
    espSec:AddColorPicker("ESPArrHero",{Title="Герой",Default=Color3.fromRGB(255,215,0)}):OnChanged(function(c) espState.arrowHero=c end)
    espSec:AddSlider("ESPArrSz",{Title="Размер стрелок",Min=16,Max=96,Default=42,Rounding=0}):OnChanged(function(v) espState.arrowSize=tonumber(v) or 42 end)
    espSec:AddSlider("ESPArrDist",{Title="Дистанция стрелок",Min=40,Max=520,Default=260,Rounding=0}):OnChanged(function(v) espState.arrowDist=tonumber(v) or 260 end)
    espSec:AddSlider("ESPMaxDist",{Title="Макс. дистанция ESP",Min=50,Max=1000,Default=500,Rounding=0}):OnChanged(function(v) espState.maxDist=tonumber(v) or 500 end)
    espSec:AddToggle("ESPAllowLocal",{Title="Показывать себя",Default=false}):OnChanged(function(v) espState.allowLocal=v end)
    local gunSec=tV:AddSection({Name="ESP Пистолета"})
    gunSec:AddToggle("GunEspOn",{Title="ESP пистолета",Default=false}):OnChanged(function(v)
        espState.gunEspOn=v
        if v then collectCandidates() else clearGuns() end
    end)
    gunSec:AddToggle("GunTextOn",{Title="Текст",Default=false}):OnChanged(function(v) espState.gunTextOn=v end)
    gunSec:AddColorPicker("GunTextCol",{Title="Цвет текста",Default=Color3.new(1,1,1)}):OnChanged(function(c) espState.gunTextCol=c end)
    gunSec:AddToggle("GunHlOn",{Title="Обводка",Default=false}):OnChanged(function(v) espState.gunHlOn=v end)
    gunSec:AddColorPicker("GunHlCol",{Title="Цвет обводки",Default=Color3.new(1,1,1)}):OnChanged(function(c) espState.gunHlCol=c end)
    local camSec=tV:AddSection({Name="Камера"})
    local ratioOn,ratioValue=false,100
    local aspectMul=CFrame.new(0,0,0,1,0,0,0,1,0,0,0,1)
    RunService:BindToRenderStep("FH_aspect",Enum.RenderPriority.Camera.Value+1,function()
        if not ratioOn then return end
        local cam=Workspace.CurrentCamera
        if cam then cam.CFrame=cam.CFrame*aspectMul end
    end)
    camSec:AddToggle("AspectOn",{Title="Aspect ratio",Default=false}):OnChanged(function(v) ratioOn=v end)
    camSec:AddSlider("AspectVal",{Title="Значение",Min=1,Max=100,Default=100,Rounding=0}):OnChanged(function(v)
        ratioValue=tonumber(v) or 100
        aspectMul=CFrame.new(0,0,0,1,0,0,0,ratioValue/100,0,0,0,1)
    end)
    local fovOn,fovValue,fovOrig=false,70,nil
    RunService.RenderStepped:Connect(function()
        if not fovOn then return end
        local cam=Workspace.CurrentCamera
        if cam and cam.FieldOfView~=fovValue then cam.FieldOfView=fovValue end
    end)
    camSec:AddToggle("FovOn",{Title="Своё FOV",Default=false}):OnChanged(function(v)
        fovOn=v
        local cam=Workspace.CurrentCamera
        if v then if cam then fovOrig=cam.FieldOfView cam.FieldOfView=fovValue end
        else if cam and fovOrig then cam.FieldOfView=fovOrig end end
    end)
    camSec:AddSlider("FovVal",{Title="FOV",Min=30,Max=120,Default=70,Rounding=0}):OnChanged(function(v)
        fovValue=tonumber(v) or 70
        if fovOn then
            local cam=Workspace.CurrentCamera
            if cam then cam.FieldOfView=fovValue end
        end
    end)
end
do
    local lvSec=Tabs.Visual:AddSection({Name="Свои визуалы"})
    local chGui=Instance.new("ScreenGui")
    chGui.Name="FH_ChinaHat_v184"
    chGui.ResetOnSpawn=false
    chGui.IgnoreGuiInset=true
    chGui.DisplayOrder=999
    chGui.Parent=uiRoot()
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
    local function cross(o,a,b)
        return (a.X-o.X)*(b.Y-o.Y)-(a.Y-o.Y)*(b.X-o.X)
    end
    local function hull(pts)
        table.sort(pts,function(a,b)
            if a.X==b.X then return a.Y<b.Y end
            return a.X<b.X
        end)
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
    lvSec:AddToggle("ChinaHatOn",{Title="Китайская шляпа",Default=false}):OnChanged(function(v) chOn=v end)
    lvSec:AddColorPicker("ChinaHatCol",{Title="Цвет шляпы",Default=Color3.fromRGB(170,85,255)}):OnChanged(function(c) chCol=c end)
    local btOn,btCol=false,Color3.fromRGB(255,60,60)
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
                o.Anchored=true
                o.CanCollide=false
                o.CanQuery=false
                o.CastShadow=false
                if o.Name=="HumanoidRootPart" then o.Transparency=1
                else
                    o.Material=Enum.Material.ForceField
                    o.Color=btCol
                    o.Transparency=0
                end
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
    lvSec:AddToggle("BacktrackOn",{Title="Бэктрек",Default=false}):OnChanged(function(v)
        btOn=v
        if v then
            if not _G.FH_BT_CONN then
                _G.FH_BT_CONN=RunService.Heartbeat:Connect(function() if btOn then btUpdate() end end)
            end
            if not btModel then btBuild() end
        else btKill() end
    end)
    lvSec:AddColorPicker("BacktrackCol",{Title="Цвет",Default=Color3.fromRGB(255,60,60)}):OnChanged(function(c)
        btCol=c
        if btModel then
            for _,p in ipairs(btModel:GetDescendants()) do
                if p:IsA("BasePart") and p.Name~="HumanoidRootPart" then p.Color=c end
            end
        end
    end)
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
        pt.Anchored=true
        pt.CanCollide=false
        pt.CanQuery=false
        pt.CanTouch=false
        pt.CastShadow=false
        pt.Transparency=1
        pt.Size=Vector3.new(0.3,0.01,0.3)
        pt.CFrame=CFrame.fromMatrix(p+n*0.012,right,n,front)
        pt.Parent=Workspace
        local sg=Instance.new("SurfaceGui")
        sg.Face=Enum.NormalId.Top
        sg.AlwaysOnTop=true
        sg.LightInfluence=0
        sg.ZOffset=4
        sg.CanvasSize=Vector2.new(1024,1024)
        sg.Parent=pt
        local img=Instance.new("ImageLabel")
        img.BackgroundTransparency=1
        img.Size=UDim2.fromScale(1,1)
        img.Image="rbxassetid://7185003058"
        img.ImageColor3=lcCol
        img.ImageTransparency=1-lcTr
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
            if state==Enum.HumanoidStateType.Jumping or state==Enum.HumanoidStateType.Freefall then
                air=true
            elseif state==Enum.HumanoidStateType.Landed and air and lcOn then
                air=false
                local p,n=lcHit(char,root)
                if p and n then lcMake(p,n) end
            end
        end)
    end
    lvSec:AddToggle("LandCircleOn",{Title="Круг падения",Default=false}):OnChanged(function(v)
        lcOn=v
        if v then lcBind()
        elseif lcConn then pcall(function() lcConn:Disconnect() end) lcConn=nil end
    end)
    lvSec:AddColorPicker("LandCircleCol",{Title="Цвет",Default=Color3.new(1,1,1)}):OnChanged(function(c) lcCol=c end)
    lvSec:AddSlider("LandCircleTr",{Title="Прозрачность",Min=0,Max=1,Default=1,Rounding=2}):OnChanged(function(v) lcTr=tonumber(v) or 1 end)
    lvSec:AddSlider("LandCircleDur",{Title="Длительность",Min=0.1,Max=3,Default=0.82,Rounding=2}):OnChanged(function(v) lcDur=tonumber(v) or 0.82 end)
    local mgOn,mgCol=false,Color3.fromRGB(242,242,242)
    local mgWidth,mgHeight,mgOffset=280,72,180
    local mgLines,mgShadows={},{}
    local mgCurrent=nil
    local mgHist,mgAccum,mgSmooth={},0,0
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
        mgLines,mgShadows={},{}
        mgHist={}
        mgAccum=0
    end
    local function mgStart()
        mgClear()
        mgSmooth=mgSpeed()
        local now=os.clock()
        local cnt=math.ceil(mgSpan/mgStep)
        for i=0,cnt do mgHist[#mgHist+1]={t=now-mgSpan+i*mgStep,v=mgSmooth} end
        for i=1,300 do
            local s=Drawing.new("Line")
            s.Color=Color3.new(0,0,0);s.Thickness=3;s.Transparency=0.4;s.Visible=false
            mgShadows[#mgShadows+1]=s
            local l=Drawing.new("Line")
            l.Color=mgCol;l.Thickness=1.5;l.Transparency=1;l.Visible=false
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
                mgLines[i].Visible=false
                mgShadows[i].Visible=false
            end
            if not mgCurrent then
                mgCurrent=Drawing.new("Text")
                mgCurrent.Center=false
                mgCurrent.Outline=true
                mgCurrent.Size=12
            end
            mgCurrent.Text=tostring(math.floor(mgSmooth+0.5))
            mgCurrent.Position=Vector2.new(left+w+5,center-7)
            mgCurrent.Color=mgCol
            mgCurrent.Visible=true
        end)
    end
    lvSec:AddToggle("MovGraphOn",{Title="График скорости",Default=false}):OnChanged(function(v)
        mgOn=v
        if v then mgStart() else mgClear() end
    end)
    lvSec:AddColorPicker("MovGraphCol",{Title="Цвет",Default=Color3.fromRGB(242,242,242)}):OnChanged(function(c)
        mgCol=c
        for i=1,#mgLines do mgLines[i].Color=c end
    end)
    lvSec:AddSlider("MovGraphW",{Title="Ширина",Min=180,Max=420,Default=280,Rounding=0}):OnChanged(function(v) mgWidth=tonumber(v) or 280 end)
    lvSec:AddSlider("MovGraphH",{Title="Высота",Min=40,Max=120,Default=72,Rounding=0}):OnChanged(function(v) mgHeight=tonumber(v) or 72 end)
    lvSec:AddSlider("MovGraphY",{Title="Смещение Y",Min=-200,Max=400,Default=180,Rounding=0}):OnChanged(function(v) mgOffset=tonumber(v) or 180 end)
    local chOn2,chCol2=false,Color3.new(1,1,1)
    local chLines={}
    for i=1,4 do
        local l=Drawing.new("Line")
        l.Thickness=2
        l.Color=chCol2
        l.Visible=false
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
    lvSec:AddToggle("CrosshairOn",{Title="Прицел",Default=false}):OnChanged(function(v)
        chOn2=v
        pcall(function() UserInputService.MouseIconEnabled=not v end)
    end)
    lvSec:AddColorPicker("CrosshairCol",{Title="Цвет прицела",Default=Color3.new(1,1,1)}):OnChanged(function(c) chCol2=c end)
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
    lvSec:AddToggle("SelfChamsOn",{Title="Чамсы на себе",Default=false}):OnChanged(function(v)
        scOn=v
        if v then
            if not scConn then scConn=RunService.Heartbeat:Connect(function() if scOn then scApply() end end) end
        else scRestore() end
    end)
    lvSec:AddDropdown("SelfChamsType",{Title="Пресет",Values={"ForceField","Flat","Chromatic"},Default="ForceField"}):OnChanged(function(v) scType=v end)
    lvSec:AddColorPicker("SelfChamsCol",{Title="Цвет",Default=Color3.fromRGB(0,200,255)}):OnChanged(function(c) scCol=c end)
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
    lvSec:AddToggle("ToolChamsOn",{Title="Чамсы оружия",Default=false}):OnChanged(function(v)
        tcOn=v
        if v then
            if not tcConn then tcConn=RunService.Heartbeat:Connect(function() if tcOn then tcApply() end end) end
        else tcRestore() end
    end)
    lvSec:AddDropdown("ToolChamsType",{Title="Пресет",Values={"ForceField","Flat","Chromatic"},Default="ForceField"}):OnChanged(function(v) tcType=v end)
    lvSec:AddColorPicker("ToolChamsCol",{Title="Цвет",Default=Color3.fromRGB(255,200,0)}):OnChanged(function(c) tcCol=c end)
    local bodySec=Tabs.Visual:AddSection({Name="Фейк-внешность"})
    local kbOn=false
    local kbBackup={}
    local function kbRestore()
        local c=LocalPlayer.Character
        if not c then kbBackup={} return end
        local ru=c:FindFirstChild("RightUpperLeg") or c:FindFirstChild("Right Leg")
        local rl=c:FindFirstChild("RightLowerLeg")
        local rf=c:FindFirstChild("RightFoot")
        if ru and kbBackup.RU then
            pcall(function() ru.TextureID=kbBackup.RU.TextureID or "" ru.MeshId=kbBackup.RU.MeshId or "" end)
        end
        if rl and kbBackup.RL then
            pcall(function() rl.MeshId=kbBackup.RL.MeshId or "" rl.Transparency=kbBackup.RL.Transparency or 0 end)
        end
        if rf and kbBackup.RF then
            pcall(function() rf.MeshId=kbBackup.RF.MeshId or "" rf.Transparency=kbBackup.RF.Transparency or 0 end)
        end
        kbBackup={}
    end
    local function kbApply()
        if not kbOn then return end
        local c=LocalPlayer.Character
        if not c then return end
        local ru=c:FindFirstChild("RightUpperLeg") or c:FindFirstChild("Right Leg")
        local rl=c:FindFirstChild("RightLowerLeg")
        local rf=c:FindFirstChild("RightFoot")
        if not ru then return end
        kbBackup={}
        if ru then
            kbBackup.RU={MeshId=ru.MeshId,TextureID=ru.TextureID}
            pcall(function() ru.MeshId="rbxassetid://902942096" ru.TextureID="rbxassetid://902843398" end)
        end
        if rl then
            kbBackup.RL={MeshId=rl.MeshId,Transparency=rl.Transparency}
            pcall(function() rl.MeshId="rbxassetid://902942093" rl.Transparency=1 end)
        end
        if rf then
            kbBackup.RF={MeshId=rf.MeshId,Transparency=rf.Transparency}
            pcall(function() rf.MeshId="rbxassetid://902942089" rf.Transparency=1 end)
        end
    end
    bodySec:AddToggle("KorbloxOn",{Title="Fake Korblox",Default=false}):OnChanged(function(v)
        kbOn=v
        if v then kbApply() else kbRestore() end
        Notify("FH","Korblox "..(v and "ВКЛ" or "ВЫКЛ"),1.5)
    end)
    local hlOn=false
    local hlBackup={}
    local function hlRestore()
        local c=LocalPlayer.Character
        if not c then hlBackup={} return end
        local head=c:FindFirstChild("Head")
        if head and hlBackup.Head then
            pcall(function() head.Transparency=hlBackup.Head.Transparency end)
            pcall(function() head.LocalTransparencyModifier=hlBackup.Head.LTM end)
            pcall(function() head.Size=hlBackup.Head.Size end)
            pcall(function() head.MeshId=hlBackup.Head.MeshId end)
        end
        if head then
            for _,d in ipairs(head:GetDescendants()) do
                if hlBackup[d] then
                    if d:IsA("Decal") or d:IsA("Texture") then
                        pcall(function() d.Transparency=hlBackup[d] end)
                    elseif d:IsA("Accessory") or d:IsA("Accoutrement") then
                        local h=d:FindFirstChild("Handle")
                        if h and hlBackup[h] then pcall(function() h.Transparency=hlBackup[h] end) end
                    end
                end
            end
        end
        hlBackup={}
    end
    local function hlApply()
        if not hlOn then return end
        local c=LocalPlayer.Character
        if not c then return end
        local head=c:FindFirstChild("Head")
        if not head then return end
        hlBackup={}
        hlBackup.Head={Transparency=head.Transparency,LTM=head.LocalTransparencyModifier,Size=head.Size,MeshId=head.MeshId}
        pcall(function() head.Transparency=1 end)
        pcall(function() head.LocalTransparencyModifier=1 end)
        for _,d in ipairs(head:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then
                hlBackup[d]=d.Transparency
                pcall(function() d.Transparency=1 end)
            elseif d:IsA("Accessory") or d:IsA("Accoutrement") then
                local h=d:FindFirstChild("Handle")
                if h then
                    hlBackup[h]=h.Transparency
                    pcall(function() h.Transparency=1 end)
                end
                for _,sub in ipairs(d:GetDescendants()) do
                    if sub:IsA("Decal") or sub:IsA("Texture") then
                        hlBackup[sub]=sub.Transparency
                        pcall(function() sub.Transparency=1 end)
                    end
                end
            end
        end
        for _,acc in ipairs(c:GetChildren()) do
            if acc:IsA("Accessory") or acc:IsA("Accoutrement") then
                if acc:FindFirstChild("Handle") and acc.AccessoryType==Enum.AccessoryType.Hat then
                    local h=acc:FindFirstChild("Handle")
                    hlBackup[h]=h.Transparency
                    pcall(function() h.Transparency=1 end)
                    for _,sub in ipairs(acc:GetDescendants()) do
                        if sub:IsA("Decal") or sub:IsA("Texture") then
                            hlBackup[sub]=sub.Transparency
                            pcall(function() sub.Transparency=1 end)
                        end
                    end
                end
            end
        end
    end
    bodySec:AddToggle("HeadlessOn",{Title="Fake Headless (без головы)",Default=false}):OnChanged(function(v)
        hlOn=v
        if v then hlApply() else hlRestore() end
        Notify("FH","Headless "..(v and "ВКЛ" or "ВЫКЛ"),1.5)
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if kbOn then kbApply() end
        if hlOn then hlApply() end
    end)
end
do
    local tE=Tabs.Effects
    local tracerSec=tE:AddSection({Name="Трассер пули"})
    local tracerOn,tracerCol,tracerDur=false,Color3.fromRGB(133,220,255),1
    local tracerTrackBullet=true
    local function makePoint(pos,life)
        local pt=Instance.new("Part")
        pt.Transparency=1
        pt.Anchored=true
        pt.CanCollide=false
        pt.CanQuery=false
        pt.Size=Vector3.new(1,1,1)
        pt.CFrame=CFrame.new(pos)
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
        beam.FaceCamera=true
        beam.TextureSpeed=1.5
        beam.TextureLength=2
        beam.Width0=0.25
        beam.Width1=0.25
        beam.LightEmission=3
        beam.LightInfluence=0
        beam.Brightness=2.5
        beam.Texture="rbxassetid://12781800668"
        beam.Color=ColorSequence.new(tracerCol)
        beam.Transparency=NumberSequence.new(0.1)
        beam.Attachment0=p1:FindFirstChildOfClass("Attachment")
        beam.Attachment1=p2:FindFirstChildOfClass("Attachment")
        beam.Parent=p1
        task.delay(tracerDur,function()
            if beam.Parent then
                TweenService:Create(beam,TweenInfo.new(0.2),{Width0=0,Width1=0}):Play()
            end
        end)
    end
    local function createGunTracer()
        local c=LocalPlayer.Character
        if not c then return end
        local hrp=c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local att=hrp:FindFirstChild("GunRaycastAttachment")
        local origin=att and att.WorldPosition or hrp.Position
        local dir=Camera.CFrame.LookVector*8
        local p1=makePoint(origin,tracerDur+0.5)
        local p2=makePoint(origin+dir,tracerDur+0.5)
        local beam=Instance.new("Beam")
        beam.FaceCamera=true
        beam.TextureSpeed=1.5
        beam.TextureLength=2
        beam.Width0=0.2
        beam.Width1=0.2
        beam.LightEmission=3
        beam.LightInfluence=0
        beam.Brightness=2.5
        beam.Texture="rbxassetid://12781800668"
        beam.Color=ColorSequence.new(tracerCol)
        beam.Transparency=NumberSequence.new(0.1)
        beam.Attachment0=p1:FindFirstChildOfClass("Attachment")
        beam.Attachment1=p2:FindFirstChildOfClass("Attachment")
        beam.Parent=p1
        task.delay(tracerDur,function()
            if beam.Parent then
                TweenService:Create(beam,TweenInfo.new(0.2),{Width0=0,Width1=0}):Play()
            end
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
            if tracerTrackBullet then createTracer(sv,ev)
            else createGunTracer() end
        end)
    end
    tracerSec:AddToggle("TracerOn",{Title="Включить трассер",Default=false}):OnChanged(function(v)
        tracerOn=v
        if v then connectTracer() end
    end)
    tracerSec:AddToggle("TracerTrackBullet",{Title="Отслеживание пуль",Default=true}):OnChanged(function(v) tracerTrackBullet=v end)
    tracerSec:AddColorPicker("TracerCol",{Title="Цвет",Default=Color3.fromRGB(133,220,255)}):OnChanged(function(c) tracerCol=c end)
    tracerSec:AddSlider("TracerDur",{Title="Длительность",Min=0.1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) tracerDur=tonumber(v) or 1 end)
    local auraSec=tE:AddSection({Name="Аура"})
    local auraOn,auraType,auraCol=false,"angel",Color3.fromRGB(133,220,255)
    local auraIds={angel="97658130917593",starlight="134645216613107",heavenly="139300897520961",ribbon="132069507632161",sakura="81755778619404",wind="80694081850877",flow="119913533725648",star="73754563740680"}
    local auraCache,auraParts,auraConn={},{},nil
    local function loadAura(name)
        if auraCache[name] then return auraCache[name] end
        local id=auraIds[name]
        if not id then return nil end
        local ok,objs=pcall(game.GetObjects,game,"rbxassetid://"..id)
        if ok and objs and objs[1] then auraCache[name]=objs[1] return objs[1] end
    end
    local function colorAura(m,c)
        local seq=ColorSequence.new(c)
        for _,d in ipairs(m:GetDescendants()) do
            if d:IsA("PointLight") then d.Color=c
            elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then d.Color=seq end
        end
    end
    local function clearAura()
        for i=#auraParts,1,-1 do
            pcall(function() auraParts[i]:Destroy() end)
            auraParts[i]=nil
        end
    end
    local function applyAura()
        clearAura()
        local c=LocalPlayer.Character
        if not c then return end
        local src=loadAura(auraType)
        if not src then return end
        colorAura(src,auraCol)
        local clone=src:Clone()
        for _,part in ipairs(clone:GetChildren()) do
            local tgt=c:FindFirstChild(part.Name)
            if tgt and tgt:IsA("BasePart") then
                for _,child in ipairs(part:GetChildren()) do
                    child.Parent=tgt
                    auraParts[#auraParts+1]=child
                end
            end
        end
        clone:Destroy()
    end
    local function startAura()
        if auraConn then return end
        auraConn=LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if auraOn then applyAura() end
        end)
        task.spawn(applyAura)
    end
    local function stopAura()
        if auraConn then pcall(function() auraConn:Disconnect() end) auraConn=nil end
        clearAura()
    end
    auraSec:AddToggle("AuraOn",{Title="Включить ауру",Default=false}):OnChanged(function(v)
        auraOn=v
        if v then startAura() else stopAura() end
    end)
    auraSec:AddDropdown("AuraType",{Title="Тип",Values={"angel","starlight","heavenly","ribbon","sakura","wind","flow","star"},Default="angel"}):OnChanged(function(v)
        auraType=v
        if auraOn then task.spawn(applyAura) end
    end)
    auraSec:AddColorPicker("AuraCol",{Title="Цвет",Default=Color3.fromRGB(133,220,255)}):OnChanged(function(c)
        auraCol=c
        for _,m in pairs(auraCache) do colorAura(m,c) end
        if auraOn then task.spawn(applyAura) end
    end)
    local fxSec=tE:AddSection({Name="Эффекты мира"})
    local fxOn,fxType,fxCol,fxRate=false,"Snow",Color3.fromRGB(150,200,255),250
    local fxPart,fxEmit,fxConn=nil,nil,nil
    local function styleFX()
        local e=fxEmit
        if not e then return end
        e.Texture="rbxasset://textures/particles/smoke_main.dds"
        e.LightInfluence=0
        e.LightEmission=0.4
        e.EmissionDirection=Enum.NormalId.Bottom
        e.Rate=fxRate
        e.Color=ColorSequence.new(fxCol)
        if fxType=="Snow" then
            e.Lifetime=NumberRange.new(4,6)
            e.Speed=NumberRange.new(6,12)
            e.Acceleration=Vector3.new(2,-6,1)
            e.SpreadAngle=Vector2.new(35,35)
            e.Rotation=NumberRange.new(0,360)
            e.RotSpeed=NumberRange.new(-40,40)
            e.Size=NumberSequence.new(0.55)
            e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(0.8,0.3),NumberSequenceKeypoint.new(1,1)})
        else
            e.Lifetime=NumberRange.new(5,7)
            e.Speed=NumberRange.new(5,10)
            e.Acceleration=Vector3.new(4,-5,2)
            e.SpreadAngle=Vector2.new(40,40)
            e.Rotation=NumberRange.new(0,360)
            e.RotSpeed=NumberRange.new(-80,80)
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
        fxPart.Anchored=true
        fxPart.CanCollide=false
        fxPart.CanQuery=false
        fxPart.CanTouch=false
        fxPart.Transparency=1
        fxPart.Size=Vector3.new(260,140,260)
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
    fxSec:AddToggle("FXOn",{Title="Включить эффекты",Default=false}):OnChanged(function(v)
        fxOn=v
        if v then startFX() else stopFX() end
    end)
    fxSec:AddDropdown("FXType",{Title="Тип",Values={"Снег","Сакура"},Default="Снег"}):OnChanged(function(v)
        fxType=(v=="Сакура") and "Sakura" or "Snow"
        if fxOn then styleFX() end
    end)
    fxSec:AddColorPicker("FXCol",{Title="Цвет",Default=Color3.fromRGB(150,200,255)}):OnChanged(function(c)
        fxCol=c
        if fxEmit then fxEmit.Color=ColorSequence.new(c) end
    end)
    fxSec:AddSlider("FXRate",{Title="Интенсивность",Min=20,Max=900,Default=250,Rounding=1}):OnChanged(function(v)
        fxRate=tonumber(v) or 250
        if fxEmit then styleFX() end
    end)
    local wSec=tE:AddSection({Name="Мир"})
    local orig={
        Amb=Lighting.Ambient,Br=Lighting.Brightness,CT=Lighting.ClockTime,
        CSB=Lighting.ColorShift_Bottom,CST=Lighting.ColorShift_Top,
        Exp=Lighting.ExposureCompensation,
        FC=Lighting.FogColor,FS=Lighting.FogStart,FE=Lighting.FogEnd,
        OA=Lighting.OutdoorAmbient,GS=Lighting.GlobalShadows,
    }
    wSec:AddToggle("FBOn",{Title="Fullbright",Default=false}):OnChanged(function(v)
        if v then
            Lighting.Brightness=2
            Lighting.ClockTime=14
            Lighting.GlobalShadows=false
            Lighting.OutdoorAmbient=Color3.fromRGB(128,128,128)
            Lighting.FogEnd=100000
        else
            Lighting.Brightness=orig.Br
            Lighting.ClockTime=orig.CT
            Lighting.GlobalShadows=orig.GS
            Lighting.OutdoorAmbient=orig.OA
            Lighting.FogEnd=orig.FE
        end
    end)
    local timeOn,timeVal=false,12
    wSec:AddToggle("TimeOn",{Title="Своё время",Default=false}):OnChanged(function(v)
        timeOn=v
        Lighting.ClockTime=v and timeVal or orig.CT
    end)
    wSec:AddSlider("TimeVal",{Title="Час",Min=0,Max=24,Default=12,Rounding=0}):OnChanged(function(v)
        timeVal=tonumber(v) or 12
        if timeOn then Lighting.ClockTime=timeVal end
    end)
    local expOn,expVal=false,0
    wSec:AddToggle("ExpOn",{Title="Экспозиция",Default=false}):OnChanged(function(v)
        expOn=v
        Lighting.ExposureCompensation=v and expVal or orig.Exp
    end)
    wSec:AddSlider("ExpVal",{Title="Значение",Min=-5,Max=5,Default=0,Rounding=2}):OnChanged(function(v)
        expVal=tonumber(v) or 0
        if expOn then Lighting.ExposureCompensation=expVal end
    end)
    local fogOn,fogCol,fogStart,fogEnd=false,Color3.fromRGB(192,192,192),0,1000
    wSec:AddToggle("FogOn",{Title="Свой туман",Default=false}):OnChanged(function(v)
        fogOn=v
        if v then
            Lighting.FogColor=fogCol
            Lighting.FogStart=fogStart
            Lighting.FogEnd=fogEnd
        else
            Lighting.FogColor=orig.FC
            Lighting.FogStart=orig.FS
            Lighting.FogEnd=orig.FE
        end
    end)
    wSec:AddColorPicker("FogCol",{Title="Цвет тумана",Default=Color3.fromRGB(192,192,192)}):OnChanged(function(c)
        fogCol=c
        if fogOn then Lighting.FogColor=c end
    end)
    wSec:AddSlider("FogStart",{Title="Начало",Min=0,Max=1000,Default=0,Rounding=0}):OnChanged(function(v)
        fogStart=tonumber(v) or 0
        if fogOn then Lighting.FogStart=fogStart end
    end)
    wSec:AddSlider("FogEnd",{Title="Конец",Min=0,Max=1000,Default=1000,Rounding=0}):OnChanged(function(v)
        fogEnd=tonumber(v) or 1000
        if fogOn then Lighting.FogEnd=fogEnd end
    end)
    local ambOn,ambCol=false,Color3.fromRGB(128,128,128)
    wSec:AddToggle("AmbOn",{Title="Свой ambient",Default=false}):OnChanged(function(v)
        ambOn=v
        if v then
            Lighting.Ambient=ambCol
            Lighting.OutdoorAmbient=ambCol
        else
            Lighting.Ambient=orig.Amb
            Lighting.OutdoorAmbient=orig.OA
        end
    end)
    wSec:AddColorPicker("AmbCol",{Title="Цвет ambient",Default=Color3.fromRGB(128,128,128)}):OnChanged(function(c)
        ambCol=c
        if ambOn then Lighting.Ambient=c Lighting.OutdoorAmbient=c end
    end)
    local skyOn,skyName=false,"Jungle"
    local createdSky,origSky,origSkyParent=nil,nil,nil
    local skyboxes={
        ["Jungle"]={SkyboxBk="http://www.roblox.com/asset/?id=214399891",SkyboxDn="http://www.roblox.com/asset/?id=214399887",SkyboxFt="http://www.roblox.com/asset/?id=214399894",SkyboxLf="http://www.roblox.com/asset/?id=214405668",SkyboxRt="http://www.roblox.com/asset/?id=214399899",SkyboxUp="http://www.roblox.com/asset/?id=214399889"},
        ["Blossom"]={SkyboxBk="http://www.roblox.com/asset/?id=271042516",SkyboxDn="http://www.roblox.com/asset/?id=271077243",SkyboxFt="http://www.roblox.com/asset/?id=271042556",SkyboxLf="http://www.roblox.com/asset/?id=271042310",SkyboxRt="http://www.roblox.com/asset/?id=271042467",SkyboxUp="http://www.roblox.com/asset/?id=271077958"},
        ["Red night"]={SkyboxBk="http://www.roblox.com/Asset/?ID=401664839",SkyboxDn="http://www.roblox.com/Asset/?ID=401664862",SkyboxFt="http://www.roblox.com/Asset/?ID=401664960",SkyboxLf="http://www.roblox.com/Asset/?ID=401664881",SkyboxRt="http://www.roblox.com/Asset/?ID=401664901",SkyboxUp="http://www.roblox.com/Asset/?ID=401664936"},
        ["Purple"]={SkyboxBk="http://www.roblox.com/asset/?id=13694952867",SkyboxDn="http://www.roblox.com/asset/?id=13694968325",SkyboxFt="http://www.roblox.com/asset/?id=13694980654",SkyboxLf="http://www.roblox.com/asset/?id=13694998113",SkyboxRt="http://www.roblox.com/asset/?id=13695002700",SkyboxUp="http://www.roblox.com/asset/?id=13695007103"},
        ["Foggy"]={SkyboxBk="rbxassetid://1370717244",SkyboxDn="rbxassetid://1370717336",SkyboxFt="rbxassetid://1370717438",SkyboxLf="rbxassetid://1370717567",SkyboxRt="rbxassetid://1370717698",SkyboxUp="rbxassetid://1370717782"},
    }
    local skyAssets={Galaxy=15983996673,Anime=13107361022,Minecraft=2758029221}
    local function clearSky()
        if createdSky then pcall(function() createdSky:Destroy() end) createdSky=nil end
    end
    local function applySky(name)
        if not origSky then
            local existing=Lighting:FindFirstChildOfClass("Sky")
            if existing and existing~=createdSky then
                origSky=existing
                origSkyParent=existing.Parent
                pcall(function() existing.Parent=nil end)
            end
        end
        clearSky()
        if skyboxes[name] then
            local sky=Instance.new("Sky")
            sky.Name="FH_CustomSky"
            for k,v in pairs(skyboxes[name]) do pcall(function() sky[k]=v end) end
            sky.Parent=Lighting
            createdSky=sky
        elseif skyAssets[name] then
            task.spawn(function()
                local ok,objs=pcall(game.GetObjects,game,"rbxassetid://"..skyAssets[name])
                if not ok or type(objs)~="table" then return end
                local found
                for _,o in ipairs(objs) do
                    if o:IsA("Sky") then found=o break end
                    local s=o:FindFirstChildWhichIsA("Sky",true)
                    if s then found=s break end
                end
                if not found or not skyOn then return end
                clearSky()
                found.Name="FH_CustomSky"
                found.Parent=Lighting
                createdSky=found
            end)
        end
    end
    local function restoreSky()
        clearSky()
        if origSky then
            pcall(function() origSky.Parent=origSkyParent or Lighting end)
            origSky,origSkyParent=nil,nil
        end
    end
    wSec:AddToggle("SkyOn",{Title="Небо",Default=false}):OnChanged(function(v)
        skyOn=v
        if v then applySky(skyName) else restoreSky() end
    end)
    wSec:AddDropdown("SkyName",{Title="Пресет",Values={"Jungle","Blossom","Red night","Purple","Foggy","Galaxy","Anime","Minecraft"},Default="Jungle"}):OnChanged(function(v)
        skyName=v
        if skyOn then applySky(v) end
    end)
    getgenv().EFFECTS_UNLOAD=function()
        tracerOn=false
        if tracerConn then pcall(function() tracerConn:Disconnect() end) end
        auraOn=false
        stopAura()
        stopFX()
        restoreSky()
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
do
    local meSec=Tabs.Effects:AddSection({Name="Эффект при смерти убийцы"})
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
            if mActive[i]==rec then
                mActive[i]=mActive[#mActive]
                mActive[#mActive]=nil
                break
            end
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
        root.Name="FH_MurderFX"
        root.Parent=Workspace
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
            local ax=sz.Y*sz.Z
            local ay=sz.X*sz.Z
            local az=sz.X*sz.Y
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
                ball.Anchored=true
                ball.CanCollide=false
                ball.CanQuery=false
                ball.CanTouch=false
                ball.CastShadow=false
                ball.Massless=true
                ball.Transparency=1
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
                d.Anchored=true
                d.CanCollide=false
                d.CanQuery=false
                d.CanTouch=false
                if d.Name=="HumanoidRootPart" then d.Transparency=1
                else
                    d.Material=Enum.Material.ForceField
                    d.Color=mCloneCol
                end
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
    meSec:AddToggle("MEOn",{Title="Включить эффект",Default=false}):OnChanged(function(v)
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
    meSec:AddToggle("MEClone",{Title="Клон",Default=false}):OnChanged(function(v) mCloneOn=v end)
    meSec:AddColorPicker("MECloneCol",{Title="Цвет клона",Default=Color3.fromRGB(255,0,0)}):OnChanged(function(c) mCloneCol=c end)
    meSec:AddSlider("MECloneDur",{Title="Длительность клона",Min=1,Max=5,Default=3,Rounding=1}):OnChanged(function(v) mCloneDur=tonumber(v) or 3 end)
    meSec:AddToggle("MEPart",{Title="Частицы",Default=false}):OnChanged(function(v) mPartOn=v end)
    meSec:AddColorPicker("MEPartCol",{Title="Цвет частиц",Default=Color3.fromRGB(255,0,0)}):OnChanged(function(c) mPartCol=c end)
    meSec:AddToggle("MEEmit",{Title="Neverlose emitter",Default=false}):OnChanged(function(v) mEmitOn=v end)
    meSec:AddColorPicker("MEEmitCol",{Title="Цвет emitter",Default=Color3.fromRGB(255,100,100)}):OnChanged(function(c)
        mEmitCol=c
        for i=1,#mActive do
            local e=mActive[i]
            if e and e.channel=="emitter" then
                for _,b in ipairs(e.balls) do
                    if b.Parent then b.Color=c end
                end
            end
        end
    end)
    meSec:AddSlider("MEEmitDur",{Title="Длительность emitter",Min=1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) mEmitDur=tonumber(v) or 1 end)
    getgenv().MURDER_UNLOAD=function()
        mOn=false
        stopMurder()
        if mThread then pcall(function() task.cancel(mThread) end) mThread=nil end
    end
end
do
    local tF=Tabs.Farm
    local farmSec=tF:AddSection({Name="Автофарм v3"})
    local active=false
    local mode="Basic"
    local speed=23
    local avoid=false
    local fullAction="Respawn"
    local ncCache={}
    local farmTarget=nil
    local coinsDone,sawCoins=false,false
    local wasDown,downRefY=false,nil
    local lastTouch=0
    local DOWN_DEPTH,DOWN_RISE_XZ,AVOID_DIST,RISE_SAFE_DIST=14,4,40,20
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
        coinsDone=false
        sawCoins=false
        farmTarget=nil
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
        mhrpT=now
        mhrpCache=nil
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
    local function flatDist(a,b)
        return Vector3.new(a.X-b.X,0,a.Z-b.Z).Magnitude
    end
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
        if mode=="Down" then
            cf=cf*CFrame.Angles(-math.pi*0.5,0,0)
            wasDown=true
        end
        pcall(function()
            my.CFrame=cf
            my.AssemblyLinearVelocity=Vector3.zero
            my.AssemblyAngularVelocity=Vector3.zero
        end)
    end
    local upParams=RaycastParams.new()
    upParams.FilterType=Enum.RaycastFilterType.Exclude
    upParams.IgnoreWater=true
    local function returnToSurface()
        local my=hrp()
        if not my then return end
        local origin=my.Position
        upParams.FilterDescendantsInstances={LocalPlayer.Character}
        local res=Workspace:Raycast(origin,Vector3.new(0,400,0),upParams)
        local y=res and (res.Position.Y+5) or (downRefY and downRefY+5 or nil)
        if not y then return end
        pcall(function()
            my.CFrame=CFrame.new(origin.X,y,origin.Z)
            my.AssemblyLinearVelocity=Vector3.zero
            my.AssemblyAngularVelocity=Vector3.zero
        end)
    end
    local function farmRelease()
        if wasDown then
            wasDown=false
            returnToSurface()
        end
        setNoclip(false)
    end
    -- ИСПОЛЬЗУЕМ FLING ИЗ ПЕРВОЙ ВЕРСИИ СКРИПТА (через BodyVelocity)
    local function flingTargetOnce(tp)
        if not tp or not tp.Character then return end
        local my=hrp()
        if not my then return end
        local tc=tp.Character
        local thrp=tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        if not thrp then return end
        local oldPos=my.CFrame
        local bv=Instance.new("BodyVelocity")
        bv.Parent=my
        bv.Velocity=Vector3.zero
        bv.MaxForce=Vector3.new(9e9,9e9,9e9)
        local tm=tick()
        repeat
            if my and my.Parent and thrp and thrp.Parent then
                my.CFrame=CFrame.new(thrp.Position)*CFrame.new(0,1.5,0)
                my.AssemblyLinearVelocity=Vector3.new(9e7,9e7*10,9e7)
                my.AssemblyAngularVelocity=Vector3.new(9e8,9e8,9e8)
            end
            RunService.Heartbeat:Wait()
        until tick()-tm>1.5
        if bv then bv:Destroy() end
        if my then my.CFrame=oldPos end
    end
    local function shootMurderer()
        local m=nil
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and getRoleFromData(p)=="murderer" then m=p break end
        end
        if not m or not m.Character then return end
        local my=LocalPlayer.Character
        if not my then return end
        local gun=my:FindFirstChild("Gun")
        if not gun then
            local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
            gun=bp and bp:FindFirstChild("Gun")
            if gun then
                local hum=my:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(gun) task.wait(0.1) end
            end
        end
        if not gun then return end
        local thrp=m.Character:FindFirstChild("HumanoidRootPart")
        local myHRP=my:FindFirstChild("HumanoidRootPart")
        if thrp and myHRP then
            local to=(thrp.Position-myHRP.Position)
            if to.Magnitude>0 then
                myHRP.CFrame=CFrame.lookAt(myHRP.Position,myHRP.Position+to.Unit)
            end
        end
        pcall(function() gun:Activate() end)
    end
    local function killAllPlayers()
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local h=p.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    pcall(function() h.Health=0 end)
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead) end)
                end
            end
        end
    end
    local function fireFullAction()
        if fullAction=="Respawn" then
            local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.Health=0 end) end
        elseif fullAction=="Fling Murderer" then
            local m=nil
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and getRoleFromData(p)=="murderer" then m=p break end
            end
            if m then task.spawn(function() flingTargetOnce(m) end) end
        elseif fullAction=="Shoot Murderer" then
            task.spawn(shootMurderer)
        elseif fullAction=="Kill All" then
            task.spawn(killAllPlayers)
        end
    end
    RunService.Stepped:Connect(function(_,dt)
        if not active then return end
        if not canFarm() then
            farmTarget=nil;wasDown=false
            setNoclip(false)
            return
        end
        local my=hrp()
        if not my then return end
        local list=coinList()
        local function finish()
            farmTarget=nil
            farmRelease()
            if not coinsDone then
                coinsDone=true
                fireFullAction()
            end
        end
        if sawCoins and bagsFull() then finish() return end
        if #list>0 then
            sawCoins=true
            if coinsDone then coinsDone=false end
            local mhrp=avoid and murdererHRP() or nil
            local mpos=mhrp and mhrp.Position or nil
            if not coinOKNow(farmTarget,mpos) then
                farmTarget=pickCoin(my.Position,list,mpos)
            end
            if farmTarget then
                setNoclip(true)
                local cpos=farmTarget.Position
                downRefY=cpos.Y
                local dest=cpos
                if mode=="Down" then
                    local xz=flatDist(my.Position,cpos)
                    local safe=(not mpos) or flatDist(my.Position,mpos)>RISE_SAFE_DIST
                    if xz<=DOWN_RISE_XZ and safe then
                        dest=cpos
                        fireTouch(farmTarget)
                    else
                        dest=Vector3.new(cpos.X,cpos.Y-DOWN_DEPTH,cpos.Z)
                    end
                elseif (cpos-my.Position).Magnitude<=6 then
                    fireTouch(farmTarget)
                end
                dest=avoidSteer(my.Position,dest,mpos)
                farmMove(my,dest,dt)
            elseif mpos then
                setNoclip(true)
                local away=Vector3.new(my.Position.X-mpos.X,0,my.Position.Z-mpos.Z)
                if away.Magnitude<0.1 then away=Vector3.new(1,0,0) end
                away=away.Unit
                local y=my.Position.Y
                if mode=="Down" and downRefY then y=downRefY-DOWN_DEPTH end
                farmMove(my,my.Position+away*40+Vector3.new(0,y-my.Position.Y,0),dt)
            end
        else
            farmTarget=nil
            farmRelease()
            if sawCoins and not coinsDone then finish() end
        end
    end)
    farmSec:AddToggle("FarmV3On",{Title="Включить автофарм v3",Default=false}):OnChanged(function(v)
        active=v
        if v and Options.FarmOn and Options.FarmOn.Value then
            pcall(function() Options.FarmOn:SetValue(false) end)
        end
        resetProgress()
        if not v then farmRelease() end
    end)
    farmSec:AddDropdown("FarmV3Mode",{Title="Тип",Values={"Basic","Down"},Default="Basic"}):OnChanged(function(v)
        mode=v or "Basic"
        farmTarget=nil
        if mode=="Basic" and wasDown then wasDown=false returnToSurface() end
    end)
    farmSec:AddSlider("FarmV3Speed",{Title="Скорость",Min=5,Max=60,Default=23,Rounding=1}):OnChanged(function(v) speed=tonumber(v) or 23 end)
    farmSec:AddToggle("FarmV3Avoid",{Title="Избегать маньяка",Default=false}):OnChanged(function(v) avoid=v farmTarget=nil end)
    farmSec:AddToggle("FarmV3Reset",{Title="Авто-ресет при полных мешках",Default=false}):OnChanged(function(v) if v then fullAction="Respawn" end end)
    farmSec:AddDropdown("FarmFullAction",{Title="При полном мешке",Values={"Fling Murderer","Shoot Murderer","Kill All","Respawn"},Default="Respawn"}):OnChanged(function(v) fullAction=v or "Respawn" end)
    getgenv().FARMV3_UNLOAD=function()
        active=false
        farmTarget=nil
        farmRelease()
    end
end
do
    local tA=Tabs.Animations
    local statEmotes={
        {"Salute","12888162088"},{"Applaud","12888160997"},{"Tilt","12888159317"},
        {"Griddy","129149402922241"},{"Floss","129149402922241"},{"Dab","11953266178"},
        {"Default Dance","10272060486"},{"Kazotsky Kick","11397105951"},
        {"Robot","11953266178"},{"Orange Justice","11970665200"},{"Take the L","12327207789"},
    }
    local emoteMap,emoteList={},{}
    for _,e in ipairs(statEmotes) do
        if not emoteMap[e[1]] then
            emoteMap[e[1]]=e[2]
            emoteList[#emoteList+1]=e[1]
        end
    end
    local curTrack,selId=nil,nil
    local autoEmoteOn=false
    local animCache={}
    local function getHumLocal()
        local c=LocalPlayer.Character
        return c and c:FindFirstChildOfClass("Humanoid")
    end
    local function stopEmote()
        if curTrack then
            pcall(function() curTrack:Stop() end)
            curTrack=nil
        end
    end
    local function resolveId(id)
        if animCache[id] then return animCache[id] end
        if id:find("://") then animCache[id]=id return id end
        local raw=id:gsub("%D","")
        local ok,objs=pcall(game.GetObjects,game,"rbxassetid://"..raw)
        if ok and type(objs)=="table" then
            local found
            local function scan(inst)
                if found then return end
                if inst:IsA("Animation") and inst.AnimationId~="" then found=inst.AnimationId return end
                for _,c in ipairs(inst:GetChildren()) do scan(c) end
            end
            for _,o in ipairs(objs) do scan(o) pcall(function() o:Destroy() end) end
            if found then animCache[id]=found return found end
        end
        local url="rbxassetid://"..raw
        animCache[id]=url
        return url
    end
    local function playEmote(id)
        local hum=getHumLocal()
        if not hum or not id then return end
        stopEmote()
        local anim=Instance.new("Animation")
        anim.AnimationId=resolveId(id)
        local ok,track=pcall(function() return hum:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority=Enum.AnimationPriority.Action
            track.Looped=true
            track:Play()
            curTrack=track
        else
            Notify("FH","Не удалось запустить эмоцию",2)
        end
    end
    local emoteSec=tA:AddSection({Name="Эмоции"})
    local drop=emoteSec:AddDropdown("EmoteList",{Title="Выбрать эмоцию",Values=emoteList,Default=emoteList[1]}):OnChanged(function(v) selId=emoteMap[v] end)
    emoteSec:AddButton({Title="Активировать эмоцию",Callback=function()
        if selId then playEmote(selId) Notify("FH","Эмоция запущена",2)
        else Notify("FH","Выбери эмоцию",2) end
    end})
    emoteSec:AddButton({Title="Остановить эмоцию",Callback=function() stopEmote() Notify("FH","Эмоция остановлена",2) end})
    emoteSec:AddToggle("EmoteAuto",{Title="Авто-использование после респавна",Default=false}):OnChanged(function(v)
        autoEmoteOn=v
        if v and selId then task.wait(1) playEmote(selId) end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        if autoEmoteOn and selId then playEmote(selId) end
    end)
    task.spawn(function()
        local ok,res=pcall(function()
            local c=game:HttpGet("https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json")
            return c~="" and HttpService:JSONDecode(c) or nil
        end)
        if ok and type(res)=="table" then
            local list=res.data or res
            local seen={}
            for _,item in pairs(list) do
                if #emoteList>=200 then break end
                local id=tonumber(item.id)
                if id and id>0 and not seen[id] then
                    seen[id]=true
                    local nm=tostring(item.name or ("Emote_"..id))
                    if not emoteMap[nm] then
                        emoteMap[nm]=tostring(id)
                        emoteList[#emoteList+1]=nm
                    end
                end
            end
            pcall(function() drop:SetValues(emoteList) drop:Generate() end)
        end
    end)
    local animSec=tA:AddSection({Name="Анимации"})
    local knownAnims={
        {"Ninja",656118852},{"Zombie",616006778},{"Levitate",616008936},
        {"Astronaut",891603798},{"Cartwheel",129423030},{"T-pose",4680610777},
        {"Sneaky",4830543155},{"Old School",3333499706},{"Kick",5435202357},
        {"Dance",1824359985},{"Griddy",129149402922241},{"Salute",12888162088},
        {"Applaud",12888160997},{"Tilt",12888159317},
    }
    local animMap,animNames={},{}
    for _,e in ipairs(knownAnims) do
        animMap[e[1]]=e[2]
        animNames[#animNames+1]=e[1]
    end
    local currentTrack,currentEmote=nil,nil
    local function stopAnim()
        if currentTrack then
            pcall(function() currentTrack:Stop() end)
            currentTrack=nil
        end
    end
    local function playAnim(name)
        local id=animMap[name]
        if not id then Notify("FH","Анимация не найдена",2) return end
        local c=LocalPlayer.Character
        local hum=c and c:FindFirstChildOfClass("Humanoid")
        if not hum then Notify("FH","Персонаж не загружен",2) return end
        stopAnim()
        local anim=Instance.new("Animation")
        anim.AnimationId="rbxassetid://"..tostring(id)
        local ok,track=pcall(function() return hum:LoadAnimation(anim) end)
        anim:Destroy()
        if ok and track then
            track.Priority=Enum.AnimationPriority.Action
            track.Looped=true
            pcall(function() track:Play() end)
            currentTrack=track
            currentEmote=name
            Notify("FH","Играю: "..name,2)
        else
            Notify("FH","Не удалось запустить: "..name,2)
        end
    end
    local pick=animSec:AddDropdown("AnimPick",{Title="Выбрать анимацию",Values=animNames,Default="Ninja"})
    animSec:AddButton({Title="? Запустить",Callback=function()
        local v=pick and pick.Value
        if type(v)=="table" then v=v[1] end
        if type(v)=="string" and v~="" then playAnim(v) end
    end})
    animSec:AddButton({Title="¦ Остановить",Callback=function() stopAnim() Notify("FH","Остановлено",2) end})
    animSec:AddToggle("AnimAuto",{Title="Авто-воспроизведение после респавна",Default=false})
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        if Options.AnimAuto and Options.AnimAuto.Value and currentEmote then
            playAnim(currentEmote)
        end
    end)
    getgenv().ANIM_UNLOAD=function() stopEmote() stopAnim() end
end
do
    local tU=Tabs.Utility
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
    notifySec:AddToggle("NotifyOn",{Title="Включить",Default=false}):OnChanged(function(v) notifyOn=v end)
    notifySec:AddToggle("NotifyRoles",{Title="Показывать роль",Default=false}):OnChanged(function(v) rolesOn=v end)
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
        invis.savedLTM={}
        invis.savedDecals={}
    end
    local function invisBegin()
        if invis.active then return end
        local char=LocalPlayer.Character
        if not char then Notify("FH","Персонаж не загружен",2) return end
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then Notify("FH","Персонаж не загружен",2) return end
        invis.savedLTM={}
        invis.savedDecals={}
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
        getgenv().FH_INVIS_ACTIVE=true
        Notify("FH","Невидимость ВКЛ (авто-подбор заблокирован)",2)
    end
    local function invisEnd()
        if not invis.active then return end
        local char=LocalPlayer.Character
        local hrp=char and char:FindFirstChild("HumanoidRootPart")
        local finalCF=invis.realCF
        invis.active=false
        getgenv().FH_INVIS_ACTIVE=false
        if invis.hbConn then
            pcall(function() invis.hbConn:Disconnect() end)
            invis.hbConn=nil
        end
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
        getgenv().FH_INVIS_ACTIVE=false
        Notify("FH","Невидимость ВЫКЛ (авто-подбор разблокирован)",2)
    end
    invisSec:AddToggle("InvisOn",{Title="Включить невидимость",Default=false}):OnChanged(function(v)
        if v then invisBegin() else invisEnd() end
    end)
    getgenv().INVIS_UNLOAD=function() if invis.active then invisEnd() end end
    local sndSec=tU:AddSection({Name="Звуки убийства"})
    local SND_BASES={
        "https://cdn.jsdelivr.net/gh/khenn791/lmao@main/",
        "https://raw.githack.com/khenn791/lmao/main/",
        "https://github.com/khenn791/lmao/raw/refs/heads/main/",
        "https://raw.githubusercontent.com/khenn791/lmao/main/",
    }
    local SND_CACHE_DIR="shitaro_sounds/"
    local SND_LIST={"primordial","neverlose","sparkle","mc bow","skeet","break","rust","applepay","bubble","combobreak","killcard","xp","na naxuy","stony","hentai"}
    local sndCfg={sheriff={on=false,name="mc bow",volume=1},murder={on=false,name="skeet",volume=1}}
    local sndLast={sheriff=0,murder=0}
    local murderHRPs={}
    local function ensureFs()
        return type(isfile)=="function" and type(readfile)=="function" and type(writefile)=="function" and type(getcustomasset)=="function"
    end
    local function loadSoundPath(path)
        local okI,has=pcall(isfile,path)
        if not (okI and has) then return nil end
        local okR,data=pcall(readfile,path)
        if not (okR and type(data)=="string" and #data>0) then return nil end
        local ext=string.match(path,"(%.[^%./\\]+)$") or ".ogg"
        local tmp="fh_snd_"..tostring(math.random(100000,999999))..ext
        if not pcall(writefile,tmp,data) then return nil end
        local okA,asset=pcall(getcustomasset,tmp)
        if not (okA and type(asset)=="string" and asset~="") then return nil end
        return asset
    end
    local function resolveSound(name)
        local dirs={"shitaroebet/","assets/","",SND_CACHE_DIR}
        local exts={".ogg",".mp3",".wav",""}
        for _,dir in ipairs(dirs) do
            for _,ext in ipairs(exts) do
                local a=loadSoundPath(dir..name..ext)
                if a then return a end
            end
        end
        if ensureFs() and type(makefolder)=="function" then
            if not isfolder(SND_CACHE_DIR) then pcall(makefolder,SND_CACHE_DIR) end
            local path=SND_CACHE_DIR..name..".ogg"
            if not isfile(path) then
                local encoded=name:gsub(" ","%%20")
                for _,base in ipairs(SND_BASES) do
                    local url=base..encoded..".ogg"
                    local ok,data=pcall(function() return game:HttpGet(url,true) end)
                    if ok and type(data)=="string" and #data>1024 and not data:find("<html") then
                        pcall(writefile,path,data)
                        if isfile(path) then break end
                    end
                end
            end
            if isfile(path) then
                local okA,a=pcall(getcustomasset,path)
                if okA and a then return a end
            end
        end
        return nil
    end
    local function playSound(name,volume)
        local id=resolveSound(name)
        if not id then Notify("FH","Не нашёл звук: "..name,3) return end
        local s=Instance.new("Sound")
        s.SoundId=id
        s.Volume=volume or 1
        s.Parent=SoundService
        s:Play()
        task.delay(8,function() pcall(function() s:Destroy() end) end)
    end
    local function getMyRole()
        local d=getRoundData()
        return d and d[LocalPlayer.Name] and d[LocalPlayer.Name].Role or nil
    end
    local function hookMurdererDeath(pl)
        if not pl or pl==LocalPlayer then return end
        local function onChar(char)
            local hum=char:WaitForChild("Humanoid",8)
            if not hum then return end
            hum.Died:Connect(function()
                local myRole=getMyRole()
                if myRole~="Sheriff" and myRole~="Hero" then return end
                if not sndCfg.sheriff.on then return end
                if os.clock()-sndLast.sheriff<0.15 then return end
                sndLast.sheriff=os.clock()
                playSound(sndCfg.sheriff.name,sndCfg.sheriff.volume)
            end)
        end
        if pl.Character then task.spawn(onChar,pl.Character) end
        pl.CharacterAdded:Connect(onChar)
    end
    local function hookMyDeath()
        local char=LocalPlayer.Character
        if not char then return end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum.Died:Connect(function()
            local myRole=getMyRole()
            if myRole~="Murderer" then return end
            if not sndCfg.murder.on then return end
            if os.clock()-sndLast.murder<0.15 then return end
            sndLast.murder=os.clock()
            playSound(sndCfg.murder.name,sndCfg.murder.volume)
        end)
    end
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        hookMyDeath()
    end)
    task.spawn(function() task.wait(1) hookMyDeath() end)
    task.spawn(function()
        while task.wait(3) do
            if sndCfg.sheriff.on then
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=LocalPlayer and not murderHRPs[p] then
                        murderHRPs[p]=true
                        hookMurdererDeath(p)
                    end
                end
            end
        end
    end)
    Players.PlayerAdded:Connect(function(p) hookMurdererDeath(p) end)
    Players.PlayerRemoving:Connect(function(p) murderHRPs[p]=nil end)
    sndSec:AddToggle("SndSheriff",{Title="Звук убийства Шерифа/Героя",Default=false}):OnChanged(function(v) sndCfg.sheriff.on=v end)
    sndSec:AddDropdown("SndSheriffName",{Title="Звук",Values=SND_LIST,Default="mc bow"}):OnChanged(function(v) sndCfg.sheriff.name=v end)
    sndSec:AddSlider("SndSheriffVol",{Title="Громкость",Min=0.1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) sndCfg.sheriff.volume=tonumber(v) or 1 end)
    sndSec:AddButton({Title="? Прослушать шериф",Callback=function() playSound(sndCfg.sheriff.name,sndCfg.sheriff.volume) end})
    sndSec:AddToggle("SndMurder",{Title="Звук своей смерти (маньяк)",Default=false}):OnChanged(function(v) sndCfg.murder.on=v end)
    sndSec:AddDropdown("SndMurderName",{Title="Звук",Values=SND_LIST,Default="skeet"}):OnChanged(function(v) sndCfg.murder.name=v end)
    sndSec:AddSlider("SndMurderVol",{Title="Громкость",Min=0.1,Max=5,Default=1,Rounding=1}):OnChanged(function(v) sndCfg.murder.volume=tonumber(v) or 1 end)
    sndSec:AddButton({Title="? Прослушать маньяк",Callback=function() playSound(sndCfg.murder.name,sndCfg.murder.volume) end})
    local mvSec=tU:AddSection({Name="Голосование за карту"})
    local mvDupCap=3
    local function findPadsRoot()
        for _,nm in ipairs({"SummerLobby","Lobby","RegularLobby"}) do
            local lobby=Workspace:FindFirstChild(nm)
            local vp=lobby and lobby:FindFirstChild("VotePads")
            if vp then return vp end
        end
        return nil
    end
    local function collectPads()
        local pads,folder={},findPadsRoot()
        if not folder then return pads end
        for _,model in ipairs(folder:GetChildren()) do
            local pad=model:FindFirstChild("Pad")
            local info=model:FindFirstChild("MapInfoGui")
            local vote=model:FindFirstChild("VoteInfoGui")
            local icon=info and info:FindFirstChild("MapIcon")
            local box=vote and vote:FindFirstChild("Container")
            local title=box and box:FindFirstChild("MapName")
            if pad and info and icon and title then pads[#pads+1]={pad=pad,info=info,icon=icon,title=title} end
        end
        return pads
    end
    local function standPoint(pad)
        local prm=RaycastParams.new()
        prm.FilterType=Enum.RaycastFilterType.Exclude
        prm.FilterDescendantsInstances={LocalPlayer.Character}
        local hit=Workspace:Raycast(pad.Position+Vector3.new(0,8,0),Vector3.new(0,-40,0),prm)
        local y=hit and (hit.Position.Y+3.2) or pad.Position.Y
        return Vector3.new(pad.Position.X,y,pad.Position.Z)
    end
    -- ДЮП V3 с Anchored + длинной задержкой (идея из Patch v4)
    local function DupeVoteV3(padPart,times)
        local hrp=getHRP()
        local hum=getHum()
        if not hrp or not hum then
            Notify("FH","Персонаж не загружен",2)
            return
        end
        task.spawn(function()
            for i=1,times do
                local ch=LocalPlayer.Character
                local cHrp=ch and ch:FindFirstChild("HumanoidRootPart")
                local cHum=ch and ch:FindFirstChildOfClass("Humanoid")
                if not cHrp or not cHum or cHum.Health<=0 then
                    LocalPlayer.CharacterAdded:Wait()
                    task.wait(0.5)
                    ch=LocalPlayer.Character
                    cHrp=ch and ch:FindFirstChild("HumanoidRootPart")
                    cHum=ch and ch:FindFirstChildOfClass("Humanoid")
                    if not cHrp or not cHum then break end
                end
                cHrp.CFrame=padPart.CFrame+Vector3.new(0,3,0)
                cHrp.AssemblyLinearVelocity=Vector3.zero
                cHrp.AssemblyAngularVelocity=Vector3.zero
                cHrp.Anchored=true
                if type(firetouchinterest)=="function" then
                    pcall(firetouchinterest,cHrp,padPart,0)
                    task.wait(0.1)
                    pcall(firetouchinterest,cHrp,padPart,1)
                end
                task.wait(0.5)
                cHrp.Anchored=false
                pcall(function() cHum.Health=0 end)
                pcall(function() cHum:ChangeState(Enum.HumanoidStateType.Dead) end)
                if ch then pcall(function() ch:BreakJoints() end) end
                Notify("FH","Голос "..i.."/"..times.." отправлен",2)
                if i<times then
                    LocalPlayer.CharacterAdded:Wait()
                    task.wait(0.6)
                end
            end
            Notify("FH","Дюп завершён",3)
        end)
    end
    mvSec:AddSlider("MVDupeCap",{Title="Кол-во голосов",Min=1,Max=10,Default=3,Rounding=0}):OnChanged(function(v) mvDupCap=tonumber(v) or 3 end)
    mvSec:AddButton({Title="Дюпнуть голос",Callback=function()
        task.spawn(function()
            local chosen=nil
            while not chosen do
                local pads=collectPads()
                for _,p in ipairs(pads) do
                    if p.info.Enabled and p.title.Text~="" and p.title.Text~="MAP NAME" then
                        chosen=p
                        break
                    end
                end
                if not chosen then task.wait(0.3) end
            end
            DupeVoteV3(chosen.pad,math.clamp(math.floor(mvDupCap),1,10))
        end)
    end})
    local antiSec=tU:AddSection({Name="Анти"})
    local antiFlingOn=false
    local flingCache,flingReg={},{}
    local function regFling(model)
        if not antiFlingOn or not model then return end
        if flingReg[model] or model==LocalPlayer.Character then return end
        flingReg[model]={}
        for _,d in ipairs(model:GetDescendants()) do
            if d:IsA("BasePart") then
                if flingCache[d]==nil then flingCache[d]=d.CanCollide end
                flingReg[model][d]=true
                pcall(function() d.CanCollide=false end)
            end
        end
    end
    local function restoreFling()
        for _,model in pairs(flingReg) do
            for part in pairs(model) do
                if part.Parent and flingCache[part]~=nil then
                    pcall(function() part.CanCollide=flingCache[part] end)
                end
            end
        end
        flingReg,flingCache={},{}
    end
    RunService.Stepped:Connect(function()
        if not antiFlingOn then return end
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then regFling(p.Character) end
        end
        local hrp=getHRP()
        if hrp then
            local v=hrp.AssemblyLinearVelocity
            if v.Magnitude>250 then
                hrp.AssemblyLinearVelocity=Vector3.zero
                hrp.AssemblyAngularVelocity=Vector3.zero
            end
        end
    end)
    antiSec:AddToggle("AntiFling",{Title="Анти-отброс",Default=false}):OnChanged(function(v)
        antiFlingOn=v
        if not v then restoreFling() end
    end)
    local antiVoidOn=false
    local voidOrig=Workspace.FallenPartsDestroyHeight
    RunService.Heartbeat:Connect(function()
        pcall(function() Workspace.FallenPartsDestroyHeight=antiVoidOn and -9e9 or voidOrig end)
    end)
    antiSec:AddToggle("AntiVoid",{Title="Анти-падение",Default=false}):OnChanged(function(v) antiVoidOn=v end)
    local antiTrapOn=false
    local trapSpeedCache,trapJumpCache=16,50
    RunService.Heartbeat:Connect(function()
        if not antiTrapOn then return end
        local hum=getHum()
        if not hum then return end
        if hum.WalkSpeed>1 then trapSpeedCache=hum.WalkSpeed end
        if hum.JumpPower>1 then trapJumpCache=hum.JumpPower end
        pcall(function()
            if hum.WalkSpeed<=1 then hum.WalkSpeed=trapSpeedCache end
            if hum.JumpPower<=1 then hum.JumpPower=trapJumpCache end
        end)
        local pg=LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _,g in ipairs(pg:GetChildren()) do
                if g.Name=="TrapGUI" then pcall(function() g:Destroy() end) end
            end
        end
    end)
    antiSec:AddToggle("AntiTrap",{Title="Анти-ловушка",Default=false}):OnChanged(function(v) antiTrapOn=v end)
    local antiFadeOn=false
    local fadeCache,fadeConns={},{}
    local fadeNames={CameraFade=true,SpawnFade=true,Fade=true,DeathFade=true}
    local function fadeHide(frame)
        if not frame or not frame.Parent or not frame:IsA("GuiObject") then return end
        if fadeCache[frame]==nil then fadeCache[frame]=frame.Visible end
        if frame.Visible then pcall(function() frame.Visible=false end) end
        if not fadeConns[frame] then
            fadeConns[frame]=frame:GetPropertyChangedSignal("Visible"):Connect(function()
                if antiFadeOn and frame.Visible then pcall(function() frame.Visible=false end) end
            end)
        end
    end
    local function fadeApply()
        local pg=LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        for _,child in ipairs(pg:GetChildren()) do
            if child:IsA("ScreenGui") and fadeNames[child.Name] then
                for _,sub in ipairs(child:GetChildren()) do
                    if sub:IsA("GuiObject") and (sub.Name=="Fade" or sub.Name=="Frame") then fadeHide(sub) end
                end
            end
        end
        local main=pg:FindFirstChild("MainGUI")
        local gg=main and main:FindFirstChild("Game")
        local gf=gg and gg:FindFirstChild("Fade")
        if gf and gf:IsA("GuiObject") then fadeHide(gf) end
    end
    local function fadeRestore()
        for _,c in pairs(fadeConns) do pcall(function() c:Disconnect() end) end
        fadeConns={}
        for frame,v in pairs(fadeCache) do
            if frame and frame.Parent then pcall(function() frame.Visible=v end) end
        end
        fadeCache={}
    end
    antiSec:AddToggle("AntiFade",{Title="Убрать чёрный экран",Default=false}):OnChanged(function(v)
        antiFadeOn=v
        if v then fadeApply() else fadeRestore() end
    end)
    getgenv().ANTI_UNLOAD=function()
        antiFlingOn,antiVoidOn,antiTrapOn,antiFadeOn=false,false,false,false
        restoreFling()
        fadeRestore()
    end
end
do
    local tT=Tabs.Troll
    local tpOn,tpTool,tpActConn=false,nil,nil
    local function giveTpTool()
        if not tpOn then return end
        local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing=bp:FindFirstChild("tp")
        if not existing and LocalPlayer.Character then existing=LocalPlayer.Character:FindFirstChild("tp") end
        if existing then tpTool=existing return end
        tpTool=Instance.new("Tool")
        tpTool.Name="tp"
        tpTool.RequiresHandle=false
        tpTool.CanBeDropped=false
        tpTool.Parent=bp
        tpActConn=tpTool.Activated:Connect(function()
            local hrp=getHRP()
            local m=LocalPlayer:GetMouse()
            if not hrp or not m.Hit then return end
            hrp.CFrame=CFrame.new(m.Hit.X,m.Hit.Y+3,m.Hit.Z)
        end)
    end
    local function removeTpTool()
        if tpActConn then pcall(function() tpActConn:Disconnect() end) tpActConn=nil end
        if tpTool then pcall(function() tpTool:Destroy() end) tpTool=nil end
        local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t=bp:FindFirstChild("tp") if t then pcall(function() t:Destroy() end) end end
        local c=LocalPlayer.Character
        if c then local t=c:FindFirstChild("tp") if t then pcall(function() t:Destroy() end) end end
    end
    tT:AddSection({Name="Инструменты"}):AddToggle("ToolTP",{Title="ТП-тул (по клику)",Default=false}):OnChanged(function(v)
        tpOn=v
        if v then giveTpTool() else removeTpTool() end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if tpOn then giveTpTool() end
    end)
    local ftOn,ftTool,ftActConn=false,nil,nil
    local function clickedPlayer()
        local m=LocalPlayer:GetMouse()
        local tgt=m.Target
        if tgt then
            local node=tgt
            while node and node~=Workspace do
                local p=Players:GetPlayerFromCharacter(node)
                if p and p~=LocalPlayer then return p end
                node=node.Parent
            end
        end
        local cam=Workspace.CurrentCamera
        local mp=Vector2.new(m.X,m.Y)
        local best,bd=nil,110
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                local hrp=p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local sp,on=cam:WorldToViewportPoint(hrp.Position)
                    if on then
                        local d=(Vector2.new(sp.X,sp.Y)-mp).Magnitude
                        if d<bd then bd=d best=p end
                    end
                end
            end
        end
        return best
    end
    -- FLING через BodyVelocity (старый рабочий метод из первой версии)
    local function doFling(tp)
        if not tp or not tp.Character then return end
        local hrp=getHRP()
        if not hrp then return end
        local tc=tp.Character
        local thrp=tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        if not thrp then return end
        local oldPos=hrp.CFrame
        local cam=Workspace.CurrentCamera
        cam.CameraSubject=thrp
        local bv=Instance.new("BodyVelocity")
        bv.Parent=hrp
        bv.Velocity=Vector3.zero
        bv.MaxForce=Vector3.new(9e9,9e9,9e9)
        local tm=tick()
        repeat
            if hrp and hrp.Parent and thrp and thrp.Parent then
                hrp.CFrame=CFrame.new(thrp.Position)*CFrame.new(0,1.5,0)
                hrp.AssemblyLinearVelocity=Vector3.new(9e7,9e7*10,9e7)
                hrp.AssemblyAngularVelocity=Vector3.new(9e8,9e8,9e8)
            end
            RunService.Heartbeat:Wait()
        until tick()-tm>1.5 or not ftOn
        if bv then bv:Destroy() end
        local hum=LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        cam.CameraSubject=hum
        if hrp then hrp.CFrame=oldPos end
    end
    local function giveFlingTool()
        if not ftOn then return end
        local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then return end
        local existing=bp:FindFirstChild("fling")
        if not existing and LocalPlayer.Character then existing=LocalPlayer.Character:FindFirstChild("fling") end
        if existing then ftTool=existing return end
        ftTool=Instance.new("Tool")
        ftTool.Name="fling"
        ftTool.RequiresHandle=false
        ftTool.CanBeDropped=false
        ftTool.Parent=bp
        ftActConn=ftTool.Activated:Connect(function()
            local tp=clickedPlayer()
            if tp then doFling(tp) end
        end)
    end
    local function removeFlingTool()
        if ftActConn then pcall(function() ftActConn:Disconnect() end) ftActConn=nil end
        if ftTool then pcall(function() ftTool:Destroy() end) ftTool=nil end
        local bp=LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then local t=bp:FindFirstChild("fling") if t then pcall(function() t:Destroy() end) end end
        local c=LocalPlayer.Character
        if c then local t=c:FindFirstChild("fling") if t then pcall(function() t:Destroy() end) end end
    end
    tT:AddSection({Name="Отброс"}):AddToggle("ToolFling",{Title="Тул отброса (по клику)",Default=false}):OnChanged(function(v)
        ftOn=v
        if v then giveFlingTool() else removeFlingTool() end
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if ftOn then giveFlingTool() end
    end)
    local function inLobby(obj)
        local p=obj.Parent
        while p and p~=Workspace do
            if p.Name=="RegularLobby" or p.Name=="Lobby" then return true end
            p=p.Parent
        end
        return false
    end
    local tpBtnSec=tT:AddSection({Name="Телепорт"})
    tpBtnSec:AddButton({Title="ТП в лобби",Callback=function()
        local hrp=getHRP()
        if not hrp then return end
        local lobby=Workspace:FindFirstChild("RegularLobby") or Workspace:FindFirstChild("Lobby")
        if not lobby then return end
        local locs={}
        for _,o in ipairs(lobby:GetDescendants()) do
            if o:IsA("SpawnLocation") or (o:IsA("BasePart") and o.Name=="Spawn") then locs[#locs+1]=o end
        end
        if #locs>0 then
            local s=locs[math.random(1,#locs)]
            hrp.CFrame=s.CFrame+Vector3.new(0,3,0)
        end
    end})
    tpBtnSec:AddButton({Title="ТП на карту",Callback=function()
        local hrp=getHRP()
        if not hrp then return end
        local spawns={}
        for _,o in ipairs(Workspace:GetDescendants()) do
            if (o:IsA("SpawnLocation") or (o:IsA("BasePart") and o.Name=="Spawn")) and not inLobby(o) then
                spawns[#spawns+1]=o
            end
        end
        if #spawns>0 then
            local s=spawns[math.random(1,#spawns)]
            hrp.CFrame=s.CFrame+Vector3.new(0,5,0)
        end
    end})
    getgenv().TROLL_UNLOAD=function()
        tpOn,ftOn=false,false
        removeTpTool()
        removeFlingTool()
    end
end
task.spawn(function()
    task.wait(1)
    Notify("FortniHub","Part 2/2 v18.4.0 загружена! by HOTI and Ve315",6)
end)
print("[FH] ============================================")
print("[FH] Part 2/2 — FortniHub v18.4.0 — by HOTI and Ve315")
print("[FH] ============================================")
-- ============================================================
-- FortniHub MM2 v18.4.0 — Part 3/3 (Extended Final)
-- by HOTI and Ve315
-- Tracer V2 • Invis bind • Fling V2 • SupremeValues
-- ============================================================
task.wait(2)

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")
local Debris            = game:GetService("Debris")
local LocalPlayer       = Players.LocalPlayer
local Camera            = Workspace.CurrentCamera

local Tabs    = getgenv().FH_Tabs
local Options = getgenv().Options
local Notify  = getgenv().FH_Notify
if not (Tabs and Options and Notify) then
    warn("[FH3] Part 1 или Part 2 не загружены")
    return
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
    return "innocent"
end

local function findPlayerByRole(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and getRoleFromData(p) == role then return p end
    end
    return nil
end

local function getHRPFromPlayer(p)
    if not p then return nil end
    local c = p.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
        or c:FindFirstChild("UpperTorso")
        or c:FindFirstChild("Torso")
        or c:FindFirstChild("Head")
end

local function myHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- ============================================================
-- TRACER V2 — от пистолета до убийцы
-- ============================================================
do
    local tE = Tabs.Effects
    local tSec = tE:AddSection({Name = "Трассер V2"})
    local tOn, tCol, tDur = false, Color3.fromRGB(133,220,255), 1
    local conn = nil

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

    local function beam(from, to)
        local p1 = makePoint(from, tDur + 0.5)
        local p2 = makePoint(to, tDur + 0.5)
        local b = Instance.new("Beam")
        b.FaceCamera = true
        b.TextureSpeed = 1.5
        b.TextureLength = 2
        b.Width0 = 0.25
        b.Width1 = 0.25
        b.LightEmission = 3
        b.LightInfluence = 0
        b.Brightness = 2.5
        b.Texture = "rbxassetid://12781800668"
        b.Color = ColorSequence.new(tCol)
        b.Transparency = NumberSequence.new(0.1)
        b.Attachment0 = p1:FindFirstChildOfClass("Attachment")
        b.Attachment1 = p2:FindFirstChildOfClass("Attachment")
        b.Parent = p1
        task.delay(tDur, function()
            if b.Parent then
                TweenService:Create(b, TweenInfo.new(0.2), {Width0 = 0, Width1 = 0}):Play()
            end
        end)
    end

    local function handler(gun, sv, ev)
        if not tOn then return end
        local c = LocalPlayer.Character
        if not c then return end
        if not (typeof(gun) == "Instance" and gun:IsDescendantOf(c)) then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local att = hrp:FindFirstChild("GunRaycastAttachment")
        local origin = att and att.WorldPosition or hrp.Position
        local murdererPart = getHRPFromPlayer(findPlayerByRole("murderer"))
        local target
        if murdererPart then target = murdererPart.Position
        else target = origin + Camera.CFrame.LookVector * 30 end
        beam(origin, target)
    end

    local function tryConnect()
        if conn then return end
        local ok, remote = pcall(function()
            return ReplicatedStorage:WaitForChild("ClientServices", 10):WaitForChild("WeaponService", 10):WaitForChild("GunFired", 10)
        end)
        if ok and remote then conn = remote.OnClientEvent:Connect(handler) end
    end

    tSec:AddToggle("TracerV2On", {Title = "Включить трассер V2", Default = false}):OnChanged(function(v)
        tOn = v
        if v then
            if Options.TracerOn then pcall(function() Options.TracerOn:SetValue(false) end) end
            tryConnect()
        end
    end)
    tSec:AddColorPicker("TracerV2Col", {Title = "Цвет", Default = Color3.fromRGB(133,220,255)}):OnChanged(function(c) tCol = c end)
    tSec:AddSlider("TracerV2Dur", {Title = "Длительность", Min = 0.1, Max = 5, Default = 1, Rounding = 1}):OnChanged(function(v) tDur = tonumber(v) or 1 end)
    task.spawn(function() task.wait(1) tryConnect() end)
end

-- ============================================================
-- БИНД НЕВИДИМОСТИ (универсальный)
-- ============================================================
do
    local tB = Tabs.Binds
    if not Options.BIND_KEY_InvisOn then
        local bSec = tB:AddSection({Name = "Утилиты"})
        bSec:AddKeybind("BIND_KEY_InvisOn", {Title = "Невидимость", Default = "Unknown"}):OnChanged(function(k)
            if typeof(k) == "EnumItem" then
                Notify("FH", "Невидимость → " .. tostring(k), 2)
            end
        end)

        local btn = Instance.new("TextButton")
        btn.Name = "FH_BTN_InvisOn_P3"
        btn.Size = UDim2.fromOffset(150, 34)
        btn.Position = UDim2.fromOffset(380, 90)
        btn.BackgroundColor3 = Color3.fromRGB(28, 22, 42)
        btn.BorderSizePixel = 0
        btn.Text = "Невидимость"
        btn.TextColor3 = Color3.fromRGB(235, 225, 255)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 13
        btn.Active = true
        btn.ZIndex = 3
        btn.Visible = false
        btn.Parent = (gethui and gethui()) or game:GetService("CoreGui")
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(138, 92, 246)
        stroke.Thickness = 1
        stroke.Transparency = 0.35

        local function fire()
            if Options.InvisOn then
                Options.InvisOn:SetValue(not Options.InvisOn.Value)
                Notify("FH", "Невидимость: " .. tostring(Options.InvisOn.Value), 1.5)
            end
        end

        local dragging, dragStart, posStart, moved = false, nil, nil, false
        btn.InputBegan:Connect(function(i)
            if getgenv().FH_ButtonsFrozen then return end
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true moved = false dragStart = i.Position posStart = btn.Position
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
            local tap = not moved
            dragging = false
            if tap and not getgenv().FH_ButtonsFrozen then fire() end
        end)
        bSec:AddToggle("BIND_TCH_InvisOn", {Title = "  Кнопка: Невидимость", Default = false}):OnChanged(function(v) btn.Visible = v end)
    end

    if not getgenv().FH_INVIS_BIND_HOOKED then
        getgenv().FH_INVIS_BIND_HOOKED = true
        UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local bindOpt = Options.BIND_KEY_InvisOn
            if not bindOpt then return end
            local bound = bindOpt.Value
            if not bound then return end
            local matched = false
            if typeof(bound) == "EnumItem" then
                matched = (input.KeyCode == bound)
            elseif type(bound) == "string" then
                matched = (tostring(input.KeyCode.Name) == bound) or (tostring(input.KeyCode) == bound)
            end
            if matched then
                local toggle = Options.InvisOn
                if toggle then
                    toggle:SetValue(not toggle.Value)
                    Notify("FH", "Невидимость: " .. tostring(toggle.Value), 1.5)
                end
            end
        end)
        Notify("FH", "Бинд невидимости загружен", 2)
    end
end

-- ============================================================
-- FLING V2 (старый рабочий метод через BodyVelocity)
-- ============================================================
do
    local tT = Tabs.Troll
    local fSec = tT:AddSection({Name = "Fling V2"})

    local autoMurderer = false
    local autoSheriff = false
    local autoAll = false
    local autoInterval = 0.5
    local lastAuto = 0

    local function flingVictim(victimPlayer)
        if not victimPlayer then return end
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local hrp = myChar:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local tc = victimPlayer.Character
        if not tc then return end
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        if not thrp then return end

        local oldPos = hrp.CFrame
        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        local tm = tick()
        repeat
            if hrp and hrp.Parent and thrp and thrp.Parent then
                hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, 1.5, 0)
                hrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                hrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
            end
            RunService.Heartbeat:Wait()
        until tick() - tm > 1.5
        if bv then bv:Destroy() end
        if hrp and hrp.Parent then hrp.CFrame = oldPos end
    end

    local playerList = {}
    local playerMap = {}
    local function refreshPlayerList()
        table.clear(playerList)
        table.clear(playerMap)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                playerList[#playerList + 1] = p.Name
                playerMap[p.Name] = p
            end
        end
        if #playerList == 0 then playerList = {"(нет игроков)"} end
        local dp = Options.FV2Pick
        if dp then
            pcall(function() dp:SetValues(playerList) if dp.Generate then dp:Generate() end end)
        end
    end

    fSec:AddDropdown("FV2Pick", {Title = "Цель (выбор игрока)", Values = playerList, Default = playerList[1] or "?"})
    fSec:AddButton({Title = "Флингнуть выбранного", Callback = function()
        local dp = Options.FV2Pick
        local name = dp and dp.Value
        if playerMap[name] then task.spawn(function() flingVictim(playerMap[name]) end)
        else Notify("FH", "Выбери игрока", 2) end
    end})
    fSec:AddButton({Title = "Обновить список игроков", Callback = refreshPlayerList})

    task.spawn(function()
        task.wait(2)
        refreshPlayerList()
        Players.PlayerAdded:Connect(function(p)
            if p ~= LocalPlayer then task.wait(0.5) refreshPlayerList() end
        end)
        Players.PlayerRemoving:Connect(function(p)
            if p ~= LocalPlayer then task.wait(0.5) refreshPlayerList() end
        end)
    end)

    fSec:AddToggle("FV2AutoMurderer", {Title = "Авто-флинг убийцы", Default = false}):OnChanged(function(v) autoMurderer = v end)
    fSec:AddToggle("FV2AutoSheriff", {Title = "Авто-флинг шерифа/героя", Default = false}):OnChanged(function(v) autoSheriff = v end)
    fSec:AddToggle("FV2AutoAll", {Title = "Флинговать всех", Default = false}):OnChanged(function(v) autoAll = v end)
    fSec:AddSlider("FV2AutoInterval", {Title = "Интервал авто-флинга (сек)", Min = 0.1, Max = 3, Default = 0.5, Rounding = 1}):OnChanged(function(v) autoInterval = tonumber(v) or 0.5 end)

    task.spawn(function()
        while task.wait(0.2) do
            if not (autoMurderer or autoSheriff or autoAll) then continue end
            local now = tick()
            if now - lastAuto < autoInterval then continue end
            lastAuto = now
            if autoAll then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        task.spawn(function() flingVictim(p) end)
                    end
                end
            else
                if autoMurderer then
                    local m = findPlayerByRole("murderer")
                    if m and m.Character then task.spawn(function() flingVictim(m) end) end
                end
                if autoSheriff then
                    local s = findPlayerByRole("sheriff") or findPlayerByRole("hero")
                    if s and s.Character then task.spawn(function() flingVictim(s) end) end
                end
            end
        end
    end)
end

-- ============================================================
-- SUPREMEVALUES (панель + multi-mirror + regex parse)
-- ============================================================
do
    local tU = Tabs.Utility
    local svSec = tU:AddSection({Name = "SupremeValues (трейды)"})

    local svEnabled = false
    local svNotifyExtra = false
    local svGui, svFrame, svYour, svTheir, svDiff
    local svData = nil
    local svLastFetch = 0

    local function uiRoot2() return (gethui and gethui()) or game:GetService("CoreGui") end

    local function buildGui()
        if svGui then return end
        svGui = Instance.new("ScreenGui")
        svGui.Name = "FH_SupremeValues"
        svGui.ResetOnSpawn = false
        svGui.IgnoreGuiInset = true
        svGui.DisplayOrder = 600
        svGui.Parent = uiRoot2()

        svFrame = Instance.new("Frame")
        svFrame.Name = "SV_Panel"
        svFrame.AnchorPoint = Vector2.new(1, 0.5)
        svFrame.Position = UDim2.new(1, -20, 0.5, 0)
        svFrame.Size = UDim2.fromOffset(250, 130)
        svFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
        svFrame.BackgroundTransparency = 0.1
        svFrame.BorderSizePixel = 0
        svFrame.Visible = false
        svFrame.Parent = svGui
        Instance.new("UICorner", svFrame).CornerRadius = UDim.new(0, 10)
        local stroke = Instance.new("UIStroke", svFrame)
        stroke.Color = Color3.fromRGB(138, 92, 246)
        stroke.Thickness = 1.5
        stroke.Transparency = 0.3

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 10, 0, 6)
        title.Size = UDim2.new(1, -20, 0, 22)
        title.Font = Enum.Font.GothamBold
        title.Text = "SupremeValues"
        title.TextSize = 15
        title.TextColor3 = Color3.fromRGB(178, 152, 255)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = svFrame

        svYour = Instance.new("TextLabel")
        svYour.BackgroundTransparency = 1
        svYour.Position = UDim2.new(0, 10, 0, 32)
        svYour.Size = UDim2.new(1, -20, 0, 22)
        svYour.Font = Enum.Font.GothamSemibold
        svYour.Text = "Ты: —"
        svYour.TextSize = 13
        svYour.TextColor3 = Color3.fromRGB(100, 240, 140)
        svYour.TextXAlignment = Enum.TextXAlignment.Left
        svYour.Parent = svFrame

        svTheir = Instance.new("TextLabel")
        svTheir.BackgroundTransparency = 1
        svTheir.Position = UDim2.new(0, 10, 0, 54)
        svTheir.Size = UDim2.new(1, -20, 0, 22)
        svTheir.Font = Enum.Font.GothamSemibold
        svTheir.Text = "Он: —"
        svTheir.TextSize = 13
        svTheir.TextColor3 = Color3.fromRGB(255, 120, 120)
        svTheir.TextXAlignment = Enum.TextXAlignment.Left
        svTheir.Parent = svFrame

        svDiff = Instance.new("TextLabel")
        svDiff.Name = "DiffLabel"
        svDiff.BackgroundTransparency = 1
        svDiff.Position = UDim2.new(0, 10, 0, 78)
        svDiff.Size = UDim2.new(1, -20, 0, 30)
        svDiff.Font = Enum.Font.GothamBold
        svDiff.Text = "Разница: —"
        svDiff.TextSize = 14
        svDiff.TextColor3 = Color3.fromRGB(255, 220, 80)
        svDiff.TextXAlignment = Enum.TextXAlignment.Left
        svDiff.Parent = svFrame

        local info = Instance.new("TextLabel")
        info.BackgroundTransparency = 1
        info.Position = UDim2.new(0, 10, 0, 106)
        info.Size = UDim2.new(1, -20, 0, 18)
        info.Font = Enum.Font.Gotham
        info.Text = "supremevalues.com"
        info.TextSize = 10
        info.TextColor3 = Color3.fromRGB(120, 120, 150)
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Parent = svFrame

        local dragging, dragStart, posStart = false, nil, nil
        svFrame.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true dragStart = i.Position posStart = svFrame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if not dragging then return end
            if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - dragStart
                svFrame.Position = UDim2.new(posStart.X.Scale, posStart.X.Offset + d.X, posStart.Y.Scale, posStart.Y.Offset + d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    -- Список зеркал базы MM2 values
    local SV_MIRRORS = {
        "https://raw.githubusercontent.com/Auxtric/SupremeValues-API/main/values.json",
        "https://raw.githubusercontent.com/MurderMystery2-Values/values/main/mm2.json",
        "https://cdn.jsdelivr.net/gh/Auxtric/SupremeValues-API@main/values.json",
        "https://raw.githack.com/Auxtric/SupremeValues-API/main/values.json",
        "https://raw.githubusercontent.com/mfd-files/mm2values/main/values.json",
    }

    local function fetchValues()
        local now = os.clock()
        if svData and now - svLastFetch < 300 then return svData end
        svLastFetch = now
        for _, url in ipairs(SV_MIRRORS) do
            local ok, res = pcall(function() return game:HttpGet(url, true) end)
            if ok and type(res) == "string" and #res > 100 and not res:find("<html") then
                local okD, data = pcall(function() return HttpService:JSONDecode(res) end)
                if okD and type(data) == "table" then
                    svData = data
                    Notify("SV", "База загружена", 3)
                    return data
                end
            end
        end
        Notify("SV", "Все зеркала мертвы (кроме supremevalues.com)", 4)
        return nil
    end

    local function normalizeName(s)
        if type(s) ~= "string" then return "" end
        return s:lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("’", "'")
    end

    local function getItemValue(name)
        if not svData or type(name) ~= "string" then return nil end
        local target = normalizeName(name)
        -- прямое совпадение
        for key, val in pairs(svData) do
            if type(key) == "string" and normalizeName(key) == target then
                if type(val) == "table" then return val.value or val.price or val.val or 0 end
                if type(val) == "number" then return val end
            end
        end
        -- частичное
        for key, val in pairs(svData) do
            if type(key) == "string" then
                local nk = normalizeName(key)
                if nk:find(target, 1, true) or target:find(nk, 1, true) then
                    if type(val) == "table" then return val.value or val.price or val.val or 0 end
                    if type(val) == "number" then return val end
                end
            end
        end
        return nil
    end

    -- Парсим GUI трейда
    local function findTradeGui()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return nil end
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") then
                local n = g.Name:lower()
                if n:find("trade") or n:find("trading") or n:find("обмен") then
                    return g
                end
            end
        end
        return nil
    end

    local function parseSide(side)
        local items = {}
        for _, d in ipairs(side:GetDescendants()) do
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                local nm = d:GetAttribute("ItemName") or d:GetAttribute("Name") or d.Name
                -- Попытка вытащить из Tooltip / TextLabel рядом
                local parent = d.Parent
                if parent then
                    for _, ch in ipairs(parent:GetChildren()) do
                        if ch:IsA("TextLabel") and ch.Text and #ch.Text > 1 and ch.Text ~= "ItemName" then
                            nm = ch.Text
                            break
                        end
                    end
                end
                if type(nm) == "string" and #nm > 1 then
                    items[#items + 1] = nm
                end
            end
        end
        return items
    end

    local function scanTrade()
        local g = findTradeGui()
        if not g then
            if svFrame then svFrame.Visible = false end
            return
        end
        -- Ищем разделы "Ваше предложение" / "Их предложение"
        local yourSection, theirSection
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("TextLabel") then
                local t = d.Text:lower()
                if t:find("ваше предложение") or t:find("your offer") then
                    yourSection = d.Parent
                elseif t:find("их предложение") or t:find("their offer") then
                    theirSection = d.Parent
                end
            end
        end
        if not (yourSection and theirSection) then
            if svFrame then svFrame.Visible = false end
            return
        end

        local yourItems = parseSide(yourSection)
        local theirItems = parseSide(theirSection)

        if #yourItems == 0 and #theirItems == 0 then
            if svFrame then svFrame.Visible = false end
            return
        end

        local data = fetchValues()
        if not svFrame then buildGui() end
        svFrame.Visible = true

        if not data then
            if svYour then svYour.Text = "Ты: (нет базы)" end
            if svTheir then svTheir.Text = "Он: (нет базы)" end
            if svDiff then svDiff.Text = "Разница: —" end
            return
        end

        local yourVal, theirVal = 0, 0
        for _, n in ipairs(yourItems) do yourVal = yourVal + (getItemValue(n) or 0) end
        for _, n in ipairs(theirItems) do theirVal = theirVal + (getItemValue(n) or 0) end

        if svYour then svYour.Text = string.format("Ты: %d (x%d)", yourVal, #yourItems) end
        if svTheir then svTheir.Text = string.format("Он: %d (x%d)", theirVal, #theirItems) end
        if svDiff then
            local d = theirVal - yourVal
            local sign = d >= 0 and "+" or ""
            local col
            if d > 0 then col = Color3.fromRGB(100, 240, 140)
            elseif d < 0 then col = Color3.fromRGB(255, 100, 100)
            else col = Color3.fromRGB(255, 220, 80) end
            svDiff.Text = string.format("Разница: %s%d", sign, d)
            svDiff.TextColor3 = col
        end

        if svNotifyExtra and (yourVal > 0 or theirVal > 0) then
            Notify("SV", string.format("Ты: %d | Он: %d | Δ%d", yourVal, theirVal, theirVal - yourVal), 3)
        end
    end

    svSec:AddToggle("SVEnabled", {Title = "Показывать оценку трейда", Default = false}):OnChanged(function(v)
        svEnabled = v
        if v then
            buildGui()
            if svFrame then svFrame.Visible = true end
        else
            if svFrame then svFrame.Visible = false end
        end
    end)
    svSec:AddToggle("SVNotify", {Title = "Дополнительно уведомлять", Default = false}):OnChanged(function(v) svNotifyExtra = v end)
    svSec:AddButton({Title = "Обновить базу SupremeValues", Callback = function()
        svData = nil
        svLastFetch = 0
        local d = fetchValues()
        if d then Notify("SV", "База загружена", 3) end
    end})

    task.spawn(function()
        while task.wait(1) do
            if svEnabled then pcall(scanTrade) end
        end
    end)

    -- Автозагрузка базы
    task.spawn(function()
        task.wait(3)
        if not svData then pcall(fetchValues) end
    end)
end

print("[FH3] Part 3/3 — FortniHub v18.4.0 — расширение загружено")
