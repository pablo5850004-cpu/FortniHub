-- loader.lua — FortniHub v15.5 FINAL
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua?t=" .. os.time()

print("[FH] FortniHub v15.5 запускается...")
local body = game:HttpGet(url, true)
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua не скачался")
    return
end

body = body:gsub("^=+%s*\n", "")

-- ============================================================
-- 1. SafeRandom
-- ============================================================
if not getgenv().safeRandom then
    local orig = math.random
    getgenv().safeRandom = function(a, b)
        if a == nil then return orig() end
        if b == nil then
            if type(a) ~= "number" or a ~= a or a < 1 then a = 1 end
            if a > 2147483647 then a = 2147483647 end
            return orig(math.floor(a))
        end
        a, b = tonumber(a) or 0, tonumber(b) or 0
        if a ~= a then a = 0 end
        if b ~= b then b = 0 end
        if b < a then a, b = b, a end
        if a == b then return a end
        return orig(math.floor(a), math.floor(b))
    end
end
safeRandom = getgenv().safeRandom

-- ============================================================
-- 2. Безопасные замены (без capture)
-- ============================================================
body = body:gsub("math%.random%s*=%s*function", "_G.__patchedRandom = function")
body = body:gsub("string%.random%s*=%s*function", "_G.__patchedStringRandom = function")
body = body:gsub("math%.random%s*%(", "safeRandom(")
body = body:gsub("AddColorPicker", "AddColorpicker")

-- ============================================================
-- 3. INJECT: Fluent monkey-patch + Русский + Silent Bind + AWP
-- ============================================================
local INJECT = [[

-- ⚡ FortniHub v15.5 inject
do
    -- ============ FLUENT MONKEY-PATCH ============
    if type(Fluent) == "table" and type(Fluent.CreateWindow) == "function" then
        local origCreate = Fluent.CreateWindow
        Fluent.CreateWindow = function(self, ...)
            local win = origCreate(self, ...)
            if not win then return win end
            local origAddTab = win.AddTab
            win.AddTab = function(w, ...)
                local tab = origAddTab(w, ...)
                if not tab then return tab end

                local function hook(container)
                    if type(container) ~= "table" then return end

                    for _, name in ipairs({"AddToggle","AddSlider","AddDropdown",
                                            "AddInput","AddButton","AddLabel",
                                            "AddKeybind","AddColorpicker","AddColorPicker"}) do
                        local orig = container[name]
                        if type(orig) == "function" and not container["__hk_"..name] then
                            container["__hk_"..name] = true
                            container[name] = function(c, ...)
                                local r = orig(c, ...)
                                if type(r) == "table" and r.Option == nil then r.Option = r end
                                return r
                            end
                        end
                    end

                    if type(container.AddColorpicker) == "function" and type(container.AddColorPicker) ~= "function" then
                        container.AddColorPicker = container.AddColorpicker
                    end

                    if type(container.AddSection) == "function" and not container.__hk_AS then
                        container.__hk_AS = true
                        local origAS = container.AddSection
                        container.AddSection = function(c, a)
                            if type(a) == "table" then a = a.Name or a.name or "section" end
                            if a == nil then a = "section" end
                            local sec = origAS(c, a)
                            if sec then
                                if sec.Option == nil then sec.Option = sec end
                                hook(sec)
                            end
                            return sec
                        end
                    end
                end

                hook(tab)
                return tab
            end
            return win
        end
        print("[FH] Fluent patch v15.5 применён")
    end

    -- ============ SILENT AIM BIND ============
    _G.FH_SILENT_BIND = Enum.KeyCode.E
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode ~= _G.FH_SILENT_BIND then return end
        if not (SILENT and SILENT.enabled) then
            pcall(function() Notify("FortniHub", "Включи Silent Aim в Бой", 2) end)
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        local gun = char:FindFirstChild("Gun")
        if not gun then
            local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
            gun = bp and bp:FindFirstChild("Gun")
            if gun then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:EquipTool(gun) end
                task.wait(0.05)
            end
        end
        if not gun then return end
        pcall(function() gun:Activate() end)
        pcall(function() VirtualUser:ClickButton1(Vector2.new(0, 0)) end)
    end)

    -- UI для бинда (после загрузки Part 1)
    task.spawn(function()
        task.wait(4)
        if not (Tabs and Tabs.Combat) then return end
        pcall(function()
            local sec = Tabs.Combat:AddSection("silent_bind")
            if sec.AddKeybind then
                sec:AddKeybind("SilentBindKey", {
                    Title = "Кнопка тихого выстрела (Silent)",
                    Default = "E",
                }):OnChanged(function(k)
                    local ok, kc = pcall(function() return Enum.KeyCode[k] end)
                    if ok and kc then
                        _G.FH_SILENT_BIND = kc
                        print("[FH] Silent bind: " .. tostring(kc))
                    end
                end)
            end
        end)
    end)

    print("[FH] Silent Aim Bind активен (E)")

    -- ============ AUTOFARM DIAG ============
    task.spawn(function()
        task.wait(3)
        local ok, coins = pcall(function() return CollectionService:GetTagged("CoinVisual") end)
        if ok and type(coins) == "table" then
            print("[FH] CoinVisual найдено: " .. #coins .. " шт.")
        else
            warn("[FH] CoinVisual тег не работает в этой версии MM2!")
        end
    end)

    -- ============ AWP REPLACE ============
    task.spawn(function()
        task.wait(5)
        if not (Tabs and Tabs.Visual) then return end
        local sec
        pcall(function() sec = Tabs.Visual:AddSection("awp_replace") end)
        if not sec then return end

        local awp_on = false
        local parts_list = {}

        local function clear_awp()
            for i = #parts_list, 1, -1 do
                pcall(function() parts_list[i]:Destroy() end)
                parts_list[i] = nil
            end
        end

        local function build_awp(handle)
            if not handle or handle:GetAttribute("FH_AWP") then return end
            handle:SetAttribute("FH_AWP", true)
            local tool = handle.Parent
            if not tool then return end

            local function part(name, size, color, off)
                local p = Instance.new("Part")
                p.Name = name
                p.Size = size
                p.Color = color
                p.Material = Enum.Material.Metal
                p.Anchored = true
                p.CanCollide = false
                p.CanQuery = false
                p.CanTouch = false
                p.Massless = true
                p.Parent = tool
                p.CFrame = handle.CFrame * off
                parts_list[#parts_list + 1] = p
                return p
            end

            local body = part("AWP_Body", Vector3.new(0.12, 0.16, 1.2), Color3.fromRGB(50, 60, 40), CFrame.new(0, 0, -0.4))
            local barrel = part("AWP_Barrel", Vector3.new(0.06, 0.06, 1.0), Color3.fromRGB(25, 25, 28), CFrame.new(0, 0, -1.5))
            local scope = part("AWP_Scope", Vector3.new(0.06, 0.06, 0.5), Color3.fromRGB(25, 25, 28), CFrame.new(0, 0.15, -0.3))
            local stock = part("AWP_Stock", Vector3.new(0.1, 0.14, 0.6), Color3.fromRGB(50, 60, 40), CFrame.new(0, 0, 0.55))

            task.spawn(function()
                while awp_on and handle.Parent do
                    if body.Parent then body.CFrame = handle.CFrame * CFrame.new(0, 0, -0.4) end
                    if barrel.Parent then barrel.CFrame = handle.CFrame * CFrame.new(0, 0, -1.5) end
                    if scope.Parent then scope.CFrame = handle.CFrame * CFrame.new(0, 0.15, -0.3) end
                    if stock.Parent then stock.CFrame = handle.CFrame * CFrame.new(0, 0, 0.55) end
                    task.wait()
                end
            end)
        end

        pcall(function()
            sec:AddToggle("AWP_Replace", {Title = "Замена на AWP", Default = false}):OnChanged(function(v)
                awp_on = v
                if v then
                    local char = LocalPlayer.Character
                    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                    for _, root in ipairs({char, bp}) do
                        if root then
                            local g = root:FindFirstChild("Gun")
                            if g then
                                local h = g:FindFirstChild("Handle")
                                if h then build_awp(h) end
                            end
                        end
                    end
                else
                    clear_awp()
                end
            end)
        end)

        task.spawn(function()
            while true do
                task.wait(0.5)
                if awp_on then
                    local char = LocalPlayer.Character
                    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
                    for _, root in ipairs({char, bp}) do
                        if root then
                            local g = root:FindFirstChild("Gun")
                            if g then
                                local h = g:FindFirstChild("Handle")
                                if h and not h:GetAttribute("FH_AWP") then build_awp(h) end
                            end
                        end
                    end
                end
            end
        end)

        print("[FH] AWP Replace готов (Визуал → Замена на AWP)")
    end)
end

]]

-- Инжект после "Fluent загружен"
local injected = false
body = body:gsub('(logInfo%("Fluent загружен"%)%s*\n)', function(m)
    injected = true
    return m .. INJECT
end, 1)
if not injected then warn("[FH] Не нашёл точку инжекта") end

-- ============================================================
-- Compile + Run
-- ============================================================
local fn, err = loadstring(body, "@FortniHub_v15.5")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok, err2 = pcall(fn)
if not ok then
    warn("[FH] Runtime упал: " .. tostring(err2))
else
    print("[FH] FortniHub v15.5 загружен успешно!")
end
