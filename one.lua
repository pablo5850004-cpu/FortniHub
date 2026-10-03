--[[
================================================================
    FortniHub MM2 — v18.5.0
    by HOTI and Ve315
    Split build — Part 1 / 2
================================================================
    Этот файл идёт как основа. Part 2 добавляется сразу после.
    Все общие объекты (lib, window, Tabs, Wrap, CFG, утилиты)
    публикуются в getgenv().FH — чтобы Part 2 имел доступ,
    даже если скрипт будет загружен двумя отдельными кусками.
================================================================
]]

-- ==============================================================
-- 0. ЗАЩИТА ОТ ДВОЙНОЙ ЗАГРУЗКИ
-- ==============================================================
if getgenv().FORTNIHUB_MM2_LOADED then
    local old = getgenv().FORTNIHUB_MM2
    if old and type(old.unload) == "function" then
        pcall(function()
            old.unload()
        end)
    end
end

-- ==============================================================
-- 1. ОБЩИЙ NAMESPACE (шарится между Part 1 и Part 2)
-- ==============================================================
local FH = {}
getgenv().FH = FH
FH.threads = {}
FH.unloadFuncs = {}
FH.conns = {}

function FH.track(co)
    table.insert(FH.threads, co)
    return co
end

function FH.onUnload(fn)
    if type(fn) == "function" then
        table.insert(FH.unloadFuncs, fn)
    end
end

-- ==============================================================
-- 2. СЕРВИСЫ И КОНСТАНТЫ
-- ==============================================================
do
    local services = {}
    local names = {
        "Players", "RunService", "ReplicatedStorage",
        "CollectionService", "HttpService", "UserInputService",
        "TweenService", "Stats", "ContentProvider", "Lighting",
    }

    for _, name in ipairs(names) do
        services[name] = game:GetService(name)
    end

    FH.Players            = services.Players
    FH.RunService         = services.RunService
    FH.ReplicatedStorage  = services.ReplicatedStorage
    FH.CollectionService  = services.CollectionService
    FH.HttpService        = services.HttpService
    FH.UserInputService   = services.UserInputService
    FH.TweenService       = services.TweenService
    FH.Stats              = services.Stats
    FH.ContentProvider    = services.ContentProvider
    FH.Lighting           = services.Lighting

    FH.Workspace   = workspace
    FH.LocalPlayer = services.Players.LocalPlayer

    FH.ADDON_NAME    = "FortniHub MM2"
    FH.ADDON_VERSION = "v18.5.0"

    FH.CFG_ROOT  = "fortnihub"
    FH.CFG_DIR   = "fortnihub/cfg"
    FH.CFG_CACHE = "fortnihub/cache"

    FH.VALUES_VAULT = string.char(109, 109, 50, 95, 118, 97, 108, 117, 101, 115, 46, 108, 117, 97)
end

-- ==============================================================
-- 3. FS BOOTSTRAP
-- ==============================================================
do
    local fs_ok = type(isfolder) == "function"
        and type(makefolder) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"

    if fs_ok then
        if not isfolder(FH.CFG_ROOT)  then makefolder(FH.CFG_ROOT)  end
        if not isfolder(FH.CFG_DIR)   then makefolder(FH.CFG_DIR)   end
        if not isfolder(FH.CFG_CACHE) then makefolder(FH.CFG_CACHE) end
    end

    FH.fs_ok = fs_ok
end

-- ==============================================================
-- 4. CFG SYSTEM
-- ==============================================================
do
    local CFG = {}
    CFG.elements = {}
    CFG.loaded = {}
    CFG.ignores = {}

    local HttpService = FH.HttpService

    local function safe_json(val)
        local t = typeof(val)

        if t == "Color3" then
            return { __c = { val.R, val.G, val.B } }
        end

        if t == "Vector3" then
            return { __v = { val.X, val.Y, val.Z } }
        end

        if t == "Vector2" then
            return { __v2 = { val.X, val.Y } }
        end

        if t == "CFrame" then
            local a, b, c, d, e, f, g, h, i, j, k, l = val:GetComponents()
            return { __cf = { a, b, c, d, e, f, g, h, i, j, k, l } }
        end

        if t == "EnumItem" then
            return { __e = tostring(val) }
        end

        if t == "table" then
            local out = {}
            for k, v in pairs(val) do
                out[k] = safe_json(v)
            end
            return out
        end

        return val
    end

    local function unsafe_json(val)
        if type(val) ~= "table" then
            return val
        end

        if val.__c then
            return Color3.new(val.__c[1] or 0, val.__c[2] or 0, val.__c[3] or 0)
        end

        if val.__v then
            return Vector3.new(val.__v[1] or 0, val.__v[2] or 0, val.__v[3] or 0)
        end

        if val.__v2 then
            return Vector2.new(val.__v2[1] or 0, val.__v2[2] or 0)
        end

        if val.__cf then
            return CFrame.new(table.unpack(val.__cf))
        end

        if val.__e then
            local a, b = tostring(val.__e):match("^Enum%.([%w_]+)%.([%w_]+)$")
            if a and b then
                local ok, e = pcall(function()
                    return Enum[a][b]
                end)
                if ok then
                    return e
                end
            end
            return val.__e
        end

        local out = {}
        for k, v in pairs(val) do
            out[k] = unsafe_json(v)
        end
        return out
    end

    function CFG.Register(flag, kind, setter, getter)
        if type(flag) ~= "string" or flag == "" then
            return
        end
        CFG.elements[flag] = {
            kind    = kind,
            set     = setter,
            get     = getter,
        }
    end

    function CFG.Save(name)
        if not FH.fs_ok then
            return false
        end
        if type(name) ~= "string" or name == "" then
            return false
        end

        local dump = {
            _meta     = { version = FH.ADDON_VERSION, at = os.time() },
            toggles   = {},
            sliders   = {},
            dropdowns = {},
            keys      = {},
            colors    = {},
            values    = {},
        }

        for flag, elem in pairs(CFG.elements) do
            local ok, v = pcall(elem.get)
            if ok and v ~= nil then
                local bucket = "values"
                if elem.kind == "toggle"   then bucket = "toggles"   end
                if elem.kind == "slider"   then bucket = "sliders"   end
                if elem.kind == "dropdown" then bucket = "dropdowns" end
                if elem.kind == "keybind"  then bucket = "keys"      end
                if elem.kind == "color"    then bucket = "colors"    end

                dump[bucket][flag] = safe_json(v)
            end
        end

        local ok, encoded = pcall(function()
            return HttpService:JSONEncode(dump)
        end)
        if not ok then
            return false
        end

        local path = FH.CFG_DIR .. "/" .. name .. ".json"
        return pcall(writefile, path, encoded)
    end

    function CFG.Load(name)
        if not FH.fs_ok then
            return false
        end
        if type(name) ~= "string" or name == "" then
            return false
        end

        local path = FH.CFG_DIR .. "/" .. name .. ".json"
        if not isfile(path) then
            return false
        end

        local ok, raw = pcall(readfile, path)
        if not ok or type(raw) ~= "string" then
            return false
        end

        local ok2, data = pcall(function()
            return HttpService:JSONDecode(raw)
        end)
        if not ok2 or type(data) ~= "table" then
            return false
        end

        local buckets = { "toggles", "sliders", "dropdowns", "keys", "colors", "values" }
        for _, bucket in ipairs(buckets) do
            for flag, val in pairs(data[bucket] or {}) do
                local elem = CFG.elements[flag]
                if elem then
                    CFG.ignores[flag] = true
                    local ok3, decoded = pcall(unsafe_json, val)
                    if ok3 then
                        pcall(elem.set, decoded)
                    end
                    CFG.ignores[flag] = nil
                end
            end
        end

        CFG.loaded[name] = os.time()
        return true
    end

    function CFG.List()
        local out = {}
        if not FH.fs_ok then
            return out
        end
        if type(listfiles) ~= "function" then
            return out
        end

        local ok, rows = pcall(listfiles, FH.CFG_DIR)
        if not ok or type(rows) ~= "table" then
            return out
        end

        for _, f in ipairs(rows) do
            local n = string.match(f, "([^/\\]+)%.json$")
            if n then
                table.insert(out, n)
            end
        end

        table.sort(out)
        return out
    end

    function CFG.Delete(name)
        if not FH.fs_ok then
            return false
        end

        local path = FH.CFG_DIR .. "/" .. name .. ".json"
        if isfile(path) and type(delfile) == "function" then
            pcall(delfile, path)
            return true
        end
        return false
    end

    FH.CFG = CFG
end

-- ==============================================================
-- 5. UTILS
-- ==============================================================
do
    local U = {}
    local LocalPlayer = FH.LocalPlayer
    local Workspace = FH.Workspace

    function U.my_char()
        return LocalPlayer.Character
    end

    function U.my_hrp()
        local c = LocalPlayer.Character
        if not c then
            return nil
        end
        return c:FindFirstChild("HumanoidRootPart")
    end

    function U.my_hum()
        local c = LocalPlayer.Character
        if not c then
            return nil
        end
        return c:FindFirstChildOfClass("Humanoid")
    end

    function U.flat(v)
        return Vector3.new(v.X, 0, v.Z)
    end

    function U.flat_unit(v)
        local f = Vector3.new(v.X, 0, v.Z)
        if f.Magnitude > 1e-4 then
            return f.Unit
        end
        return Vector3.zero
    end

    function U.in_lobby(obj)
        local p = obj.Parent
        while p and p ~= Workspace do
            if p.Name == "RegularLobby"
                or p.Name == "Lobby"
                or p.Name == "SummerLobby" then
                return true
            end
            p = p.Parent
        end
        return false
    end

    function U.resolve_custom_asset(path)
        local fn = getcustomasset
            or getsynasset
            or (syn and syn.get_custom_asset)
            or (fluxus and fluxus.get_custom_asset)

        if type(fn) ~= "function" then
            return nil
        end

        local ok, id = pcall(fn, path)
        if ok and type(id) == "string" and id ~= "" then
            return id
        end
        return nil
    end

    FH.U = U
end

-- ==============================================================
-- 6. ICON ALIASES
-- ==============================================================
do
    local ICON_ALIAS = {
        crosshair = "crosshair",
        gun       = "target",
        shield    = "shield-check",
        sword     = "swords",
        person    = "user",
        heart     = "heart",
        ghost     = "ghost",
        skull     = "skull",
        save      = "save",
        folder    = "folder",
        trash     = "trash-2",
        refresh   = "rotate-ccw",
        map       = "map",
        move      = "move",
        eye       = "eye",
        palette   = "palette",
        sparkles  = "sparkles",
        wheat     = "wheat",
        run       = "footprints",
        swords    = "swords",
        settings  = "settings",
        video     = "video",
        keyboard  = "keyboard",
        users     = "users",
    }

    FH.I = function(icon, fallback)
        if type(icon) ~= "string" or icon == "" then
            return fallback or "circle-dot"
        end
        local low = string.lower(icon)
        if ICON_ALIAS[low] then
            return ICON_ALIAS[low]
        end
        return icon
    end
end

-- ==============================================================
-- 7. UI LIBRARY LOADER + FLUENT ADAPTER
-- ==============================================================
do
    -- ------------------------------------------------------
    -- 7.1 АДАПТЕР ДЛЯ FLUENT (Fluent:CreateWindow → lib:window)
    -- ------------------------------------------------------
    local function build_fluent_adapter(F)
        local A = {}

        -- ---------- element wrappers ----------
        local function w_toggle(el)
            local o = {}
            o.__el = el
            function o:get() return el:GetValue() end
            function o:set(v) pcall(function() el:SetValue(v and true or false) end) end
            o.GetValue = function() return el:GetValue() end
            o.SetValue = function(_, v) pcall(function() el:SetValue(v) end) end
            return o
        end

        local function w_slider(el)
            local o = {}
            o.__el = el
            function o:get() return el:GetValue() end
            function o:set(v) pcall(function() el:SetValue(tonumber(v) or 0) end) end
            o.GetValue = function() return el:GetValue() end
            o.SetValue = function(_, v) pcall(function() el:SetValue(tonumber(v) or 0) end) end
            return o
        end

        local function w_dropdown(el)
            local o = {}
            o.__el = el
            function o:get() return el:GetValue() end
            function o:set(v) pcall(function() el:SetValue(v) end) end
            function o:setlist(v)
                pcall(function()
                    if type(el.Refresh) == "function" then el:Refresh(v) end
                end)
                pcall(function()
                    if type(el.SetValues) == "function" then el:SetValues(v) end
                end)
            end
            o.GetValue = function() return el:GetValue() end
            o.SetValue = function(_, v) pcall(function() el:SetValue(v) end) end
            o.SetValues = function(_, v) o.setlist(v) end
            return o
        end

        local function w_keybind(el)
            local o = {}
            o.__el = el
            function o:get() return el.Value end
            function o:set(v)
                pcall(function()
                    if type(v) == "string" then
                        v = Enum.KeyCode[v] or Enum.KeyCode.Unknown
                    end
                    el:SetValue(v)
                end)
            end
            o.GetValue = function() return el.Value end
            o.SetValue = function(_, v) o.set(v) end
            return o
        end

        local function w_color(el)
            local o = {}
            o.__el = el
            function o:get() return el:GetValue() end
            function o:set(v) pcall(function() el:SetValue(v) end) end
            o.GetValue = function() return el:GetValue() end
            o.SetValue = function(_, v) pcall(function() el:SetValue(v) end) end
            return o
        end

        local function w_button(el)
            return { __el = el }
        end

        -- ---------- section wrapper ----------
        local function make_section(sec)
            local s = {}
            s.__sec = sec

            function s:toggle(cfg)
                cfg = cfg or {}
                local el = sec:AddToggle({
                    Title = cfg.name or "toggle",
                    Default = cfg.default and true or false,
                    Callback = cfg.callback,
                })
                local t = w_toggle(el)
                if cfg.option then
                    t.Option = make_section(sec)
                end
                return t
            end

            function s:slider(cfg)
                cfg = cfg or {}
                local el = sec:AddSlider({
                    Title = cfg.name or "slider",
                    Min = tonumber(cfg.min) or 0,
                    Max = tonumber(cfg.max) or 100,
                    Default = tonumber(cfg.default) or 0,
                    Rounding = tonumber(cfg.round) or 0,
                    Suffix = type(cfg.type) == "string" and cfg.type or "",
                    Callback = cfg.callback,
                })
                return w_slider(el)
            end

            function s:dropdown(cfg)
                cfg = cfg or {}
                local el = sec:AddDropdown({
                    Title = cfg.name or "dropdown",
                    Values = cfg.values or {},
                    Default = cfg.default,
                    Multi = cfg.multi and true or false,
                    Callback = cfg.callback,
                })
                return w_dropdown(el)
            end

            function s:button(cfg)
                cfg = cfg or {}
                local el = sec:AddButton({
                    Title = cfg.name or "button",
                    Callback = cfg.callback,
                })
                return w_button(el)
            end

            function s:keybind(cfg)
                cfg = cfg or {}
                local def = Enum.KeyCode.Unknown
                if type(cfg.default) == "string" then
                    def = Enum.KeyCode[cfg.default] or def
                elseif typeof(cfg.default) == "EnumItem" then
                    def = cfg.default
                end
                local el = sec:AddKeybind({
                    Title = cfg.name or "keybind",
                    Default = def,
                    Callback = cfg.callback,
                })
                return w_keybind(el)
            end

            function s:colorpicker(cfg)
                cfg = cfg or {}
                local el = sec:AddColorPicker({
                    Title = cfg.name or "color",
                    Default = cfg.default or Color3.new(1, 1, 1),
                    Callback = cfg.callback,
                })
                return w_color(el)
            end

            function s:label(text)
                local el
                pcall(function()
                    el = sec:AddParagraph({
                        Title = tostring(text or ""),
                        Content = "",
                    })
                end)
                if not el then
                    el = sec:AddButton({
                        Title = tostring(text or ""),
                        Callback = function() end,
                    })
                end
                return {
                    __el = el,
                    SetValue = function() end,
                    GetValue = function() return "" end,
                }
            end

            -- Fluent не имеет gallery — фолбэк на dropdown
            function s:gallery(cfg)
                cfg = cfg or {}
                local values = cfg.values or {}
                local names = {}
                for i, v in ipairs(values) do
                    if type(v) == "table" and v.name then
                        names[i] = v.name
                    else
                        names[i] = tostring(v)
                    end
                end
                local el = sec:AddDropdown({
                    Title = cfg.name or "list",
                    Values = names,
                    Default = nil,
                    Multi = cfg.multi and true or false,
                    Callback = cfg.callback,
                })
                local o = w_dropdown(el)
                function o:setdata(v)
                    local new = {}
                    for i, x in ipairs(v or {}) do
                        if type(x) == "table" and x.name then
                            new[i] = x.name
                        else
                            new[i] = tostring(x)
                        end
                    end
                    pcall(function()
                        if type(el.Refresh) == "function" then el:Refresh(new) end
                    end)
                    pcall(function()
                        if type(el.SetValues) == "function" then el:SetValues(new) end
                    end)
                end
                o.SetData = function(_, v) o.setdata(v) end
                function o:clear() end
                function o:refresh() end
                return o
            end

            return s
        end

        -- ---------- window wrapper ----------
        function A:window(cfg)
            cfg = cfg or {}
            local bind = Enum.KeyCode.Insert
            if type(cfg.bind) == "string" and Enum.KeyCode[cfg.bind] then
                bind = Enum.KeyCode[cfg.bind]
            end

            local win = F:CreateWindow({
                Title = cfg.title or "FortniHub",
                SubTitle = "",
                TabWidth = 160,
                Size = UDim2.fromOffset(580, 460),
                Acrylic = true,
                Theme = "Dark",
                MinimizeKey = bind,
            })

            local w = {}

            function w:tab(tcfg)
                tcfg = tcfg or {}
                local tab = win:AddTab({
                    Title = tcfg.name or "Tab",
                    Icon = tcfg.icon or "",
                })

                local tab_wrap = {}
                tab_wrap.__tab = tab

                function tab_wrap:section(scfg)
                    scfg = scfg or {}
                    local name = scfg.Name or scfg.name or "Section"
                    local sec = tab:AddSection(name)
                    return make_section(sec)
                end

                function tab_wrap:toggle(cfg) return make_section(tab):toggle(cfg) end
                function tab_wrap:slider(cfg) return make_section(tab):slider(cfg) end
                function tab_wrap:dropdown(cfg) return make_section(tab):dropdown(cfg) end
                function tab_wrap:button(cfg) return make_section(tab):button(cfg) end
                function tab_wrap:keybind(cfg) return make_section(tab):keybind(cfg) end
                function tab_wrap:colorpicker(cfg) return make_section(tab):colorpicker(cfg) end
                function tab_wrap:label(t) return make_section(tab):label(t) end
                function tab_wrap:gallery(cfg) return make_section(tab):gallery(cfg) end

                return tab_wrap
            end

            function w:button(_cfg) end
            function w:finish() end

            return w
        end

        return A
    end

    -- ------------------------------------------------------
    -- 7.2 ВЫБОР БИБЛИОТЕКИ
    -- ------------------------------------------------------
    local lib = nil
    local g = getgenv()

    -- приоритет 1: уже готовый кастомный lib в namespace
    if type(g.fortnitehublib) == "table"
        and type(g.fortnitehublib.window) == "function" then
        lib = g.fortnitehublib
    end

    if not lib and type(g.fortnihublib) == "table"
        and type(g.fortnihublib.window) == "function" then
        lib = g.fortnihublib
    end

    -- приоритет 2: Fluent (адаптер)
    if not lib then
        local F = g.Fluent
        if type(F) ~= "table" then
            local ok, val = pcall(function() return Fluent end)
            if ok then F = val end
        end
        if type(F) == "table" and type(F.CreateWindow) == "function" then
            lib = build_fluent_adapter(F)
            print("[FortniHub] Fluent adapter built.")
        end
    end

    -- приоритет 3: свой SDK по URL
    if not lib then
        local LIB_URLS = {
            "https://raw.githubusercontent.com/fortnitehub-org/library/main/lib.lua",
            "https://cdn.jsdelivr.net/gh/fortnitehub-org/library@main/lib.lua",
            "https://fortnitehub.xyz/sdk/library.lua",
        }
        for _, url in ipairs(LIB_URLS) do
            local ok, body = pcall(function() return game:HttpGet(url) end)
            if ok and type(body) == "string" and #body > 32 then
                local f = loadstring(body, "@fortnihub-lib")
                if f then
                    local ok2, res = pcall(f)
                    if ok2 and type(res) == "table"
                        and type(res.window) == "function" then
                        lib = res
                        break
                    end
                end
            end
        end
    end

    -- приоритет 4: заглушка
    if not lib then
        warn("[FortniHub] UI library not found — using stub.")

        local stub = { _stub = true }

        stub.window = function()
            local w = {}

            w.tab = function()
                local t = {}

                t.section = function()
                    local s = {}

                    s.toggle = function()
                        return {
                            get = function() return false end,
                            set = function() end,
                            GetValue = function() return false end,
                            SetValue = function() end,
                            Option = s,
                        }
                    end

                    s.slider   = s.toggle
                    s.dropdown = s.toggle
                    s.button   = s.toggle
                    s.keybind  = s.toggle
                    s.colorpicker = s.toggle
                    s.label    = s.toggle
                    s.gallery  = s.toggle

                    return s
                end

                t.button  = function() end
                t.toggle  = function() end
                t.gallery = function() end

                return t
            end

            w.button = function() end
            w.finish = function() end

            return w
        end

        lib = stub
    end

    g.fortnihublib = lib
    FH.lib = lib

    print("[FortniHub] UI source: "
        .. (lib._stub and "stub" or
            (lib == g.fortnitehublib and "custom" or
             (lib == g.fortnihublib and "cached" or "adapter"))))
end

-- ==============================================================
-- 8. WINDOW + TABS
-- ==============================================================
do
    local lib = FH.lib
    local I = FH.I

    local window = lib:window({
        title = FH.ADDON_NAME .. " " .. FH.ADDON_VERSION,
        bind  = "Insert",
    })

    local Tabs = {}

    Tabs.Combat = window:tab({ name = "Бой",       icon = I("swords")   })
    Tabs.Move   = window:tab({ name = "Движение",  icon = I("run")      })
    Tabs.Binds  = window:tab({ name = "Бинды",     icon = I("keyboard") })
    Tabs.Visual = window:tab({ name = "Визуал",    icon = I("eye")      })
    Tabs.Fx     = window:tab({ name = "Эффекты",   icon = I("sparkles") })
    Tabs.Farm   = window:tab({ name = "Фарм",      icon = I("wheat")    })
    Tabs.Anim   = window:tab({ name = "Анимации",  icon = I("video")    })
    Tabs.Util   = window:tab({ name = "Утилиты",   icon = I("settings") })
    Tabs.Troll  = window:tab({ name = "Троллинг",  icon = I("ghost")    })
    Tabs.Skins  = window:tab({ name = "Скины",     icon = I("palette")  })
    Tabs.Cfg    = window:tab({ name = "Настройки", icon = I("save")     })

    FH.window = window
    FH.Tabs = Tabs

    print("[FortniHub] Все 11 вкладок созданы.")
end

-- ==============================================================
-- 9. WRAPPERS + АВТО-РЕГИСТРАЦИЯ В CFG
-- ==============================================================
do
    local Wrap = {}

    function Wrap.section(tab, cfg)
        cfg = cfg or {}
        local name = cfg.Name or "SECTION"
        local side = cfg.Side or "left"
        return tab:section({ name = name, side = side })
    end

    FH.Wrap = Wrap

    local CFG = FH.CFG

    function FH.reg_toggle(flag, setter, getter)
        if flag then
            CFG.Register(flag, "toggle", setter, getter)
        end
    end

    function FH.reg_slider(flag, setter, getter)
        if flag then
            CFG.Register(flag, "slider", setter, getter)
        end
    end

    function FH.reg_drop(flag, setter, getter)
        if flag then
            CFG.Register(flag, "dropdown", setter, getter)
        end
    end

    function FH.reg_key(flag, setter, getter)
        if flag then
            CFG.Register(flag, "keybind", setter, getter)
        end
    end

    function FH.reg_color(flag, setter, getter)
        if flag then
            CFG.Register(flag, "color", setter, getter)
        end
    end
end

-- ==============================================================
-- 10. TROLLING — ИНСТРУМЕНТЫ + ОТБРОС + ТЕЛЕПОРТ + ФЕЙК-СМЕРТЬ
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local U = FH.U
    local Players = FH.Players
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer

    local TrollSec = Wrap.section(Tabs.Troll, { Name = "Инструменты", Side = "left"  })
    local FlingSec = Wrap.section(Tabs.Troll, { Name = "Отброс",      Side = "right" })
    local TpSec    = Wrap.section(Tabs.Troll, { Name = "Телепорт",    Side = "left"  })
    local FdSec    = Wrap.section(Tabs.Troll, { Name = "Фейк смерть", Side = "right" })

    local TROLL = {
        tp_tool_on   = false,
        tp_tool      = nil,
        tp_act_conn  = nil,
        tp_add_conn  = nil,

        fling_on     = false,
        fling_mode   = "classic",
        fling_tool   = nil,
        fling_act_conn = nil,
        fling_add_conn = nil,
        fling_bypass = false,

        fd_track     = nil,
        fd_conn      = nil,
        fd_anim1     = "rbxassetid://3333499562",
        fd_anim2     = "rbxassetid://184701493",

        old_pos      = nil,
    }

    FH.TROLL = TROLL
    getgenv().FH_FLING_ACTIVE = 0

    -- ----------------------------------------
    -- ТП-тул (по клику)
    -- ----------------------------------------
    local function give_tp_tool()
        if not TROLL.tp_tool_on then
            return
        end

        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then
            return
        end

        local existing = bp:FindFirstChild("tp")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("tp")
        end
        if existing then
            TROLL.tp_tool = existing
            return
        end

        if TROLL.tp_act_conn then
            pcall(function() TROLL.tp_act_conn:Disconnect() end)
            TROLL.tp_act_conn = nil
        end

        local tool = Instance.new("Tool")
        tool.Name = "tp"
        tool.RequiresHandle = false
        tool.CanBeDropped = false
        tool.Parent = bp

        TROLL.tp_tool = tool

        TROLL.tp_act_conn = tool.Activated:Connect(function()
            local hrp = U.my_hrp()
            local mouse = LocalPlayer:GetMouse()
            local pos = mouse.Hit

            if not hrp or not pos then
                return
            end

            pcall(function()
                hrp.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end)
    end

    local function remove_tp_tool()
        if TROLL.tp_act_conn then
            pcall(function() TROLL.tp_act_conn:Disconnect() end)
            TROLL.tp_act_conn = nil
        end

        if TROLL.tp_tool then
            pcall(function() TROLL.tp_tool:Destroy() end)
            TROLL.tp_tool = nil
        end

        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            local t = bp:FindFirstChild("tp")
            if t then
                t:Destroy()
            end
        end

        local c = LocalPlayer.Character
        if c then
            local t = c:FindFirstChild("tp")
            if t then
                t:Destroy()
            end
        end
    end

    local tp_tgl = TrollSec:toggle({
        name = "ТП-тул (по клику)",
        default = false,
        flag = "troll_tp_tool",
        callback = function(v)
            TROLL.tp_tool_on = v

            if v then
                give_tp_tool()

                if not TROLL.tp_add_conn then
                    TROLL.tp_add_conn = LocalPlayer.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if TROLL.tp_tool_on then
                            give_tp_tool()
                        end
                    end)
                end
            else
                if TROLL.tp_add_conn then
                    pcall(function() TROLL.tp_add_conn:Disconnect() end)
                    TROLL.tp_add_conn = nil
                end
                remove_tp_tool()
            end
        end,
    })

    FH.reg_toggle(
        "troll_tp_tool",
        function(v) TROLL.tp_tool_on = v end,
        function() return TROLL.tp_tool_on end
    )

    -- ----------------------------------------
    -- Выбор игрока по клику
    -- ----------------------------------------
    local function clicked_player()
        local mouse = LocalPlayer:GetMouse()
        local tgt = mouse.Target

        if tgt then
            local node = tgt
            while node and node ~= Workspace do
                local p = Players:GetPlayerFromCharacter(node)
                if p and p ~= LocalPlayer then
                    return p
                end
                node = node.Parent
            end
        end

        local cam = Workspace.CurrentCamera
        if not cam then
            return nil
        end

        local mp = Vector2.new(mouse.X, mouse.Y)
        local best, bestd = nil, 120

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    or p.Character:FindFirstChild("Head")

                if hrp then
                    local sp, on = cam:WorldToViewportPoint(hrp.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - mp).Magnitude
                        if d < bestd then
                            bestd = d
                            best = p
                        end
                    end
                end
            end
        end

        return best
    end

    -- ----------------------------------------
    -- Флинг — режим classic
    -- ----------------------------------------
    local function fling_classic(tp)
        if not tp or not tp.Character then
            return
        end

        local hrp = U.my_hrp()
        local hum = U.my_hum()
        if not hrp then
            return
        end

        local tc = tp.Character
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        local th = tc:FindFirstChildOfClass("Humanoid")

        if not thrp or not th then
            return
        end

        getgenv().FH_FLING_ACTIVE = (getgenv().FH_FLING_ACTIVE or 0) + 1

        if hrp.AssemblyLinearVelocity.Magnitude < 50 then
            TROLL.old_pos = hrp.CFrame
        end

        local cam = Workspace.CurrentCamera
        local old_fdh = Workspace.FallenPartsDestroyHeight

        cam.CameraSubject = thrp
        pcall(function()
            Workspace.FallenPartsDestroyHeight = 0 / 0
        end)

        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)

        local se = nil
        if hum then
            se = hum:GetStateEnabled(Enum.HumanoidStateType.Seated)
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        end

        local t_end = tick() + 2
        local ang = 0

        repeat
            if hrp and th then
                local tv
                if TROLL.fling_bypass then
                    tv = th.MoveDirection * th.WalkSpeed
                else
                    tv = thrp.AssemblyLinearVelocity
                end

                if tv.Magnitude < 50 then
                    ang = ang + 100

                    local offsets = { 1.5, -1.5, 1.5, -1.5 }
                    for _, off in ipairs(offsets) do
                        hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, off, 0)
                            + th.MoveDirection * tv.Magnitude / 1.25
                        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(ang), 0, 0)
                        LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                        hrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                        hrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                        task.wait()
                    end
                else
                    local offsets = {
                        { 1.5, th.WalkSpeed },
                        { -1.5, -th.WalkSpeed },
                        { 1.5, th.WalkSpeed },
                        { -1.5, 0 },
                    }

                    for _, off in ipairs(offsets) do
                        hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, off[1], off[2])
                        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
                        LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                        hrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                        hrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                        task.wait()
                    end
                end
            end
        until tick() > t_end or (getgenv().FH_FLING_ACTIVE or 0) == 0

        if bv then
            bv:Destroy()
        end

        if hum and se ~= nil then
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, se)
        end

        cam.CameraSubject = hum

        if TROLL.old_pos and hrp then
            hrp.CFrame = TROLL.old_pos * CFrame.new(0, 0.5, 0)
            if hum then
                hum:ChangeState("GettingUp")
            end

            for _, p in ipairs(LocalPlayer.Character:GetChildren()) do
                if p:IsA("BasePart") then
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end
            end

            pcall(function()
                Workspace.FallenPartsDestroyHeight = old_fdh
            end)
        end

        getgenv().FH_FLING_ACTIVE = math.max(0, (getgenv().FH_FLING_ACTIVE or 1) - 1)
    end

    -- ----------------------------------------
    -- Флинг — режим shitaro (из скрипта друга)
    -- ----------------------------------------
    local function fling_shitaro(tp)
        if not tp or not tp.Character then
            return
        end

        local hrp = U.my_hrp()
        local hum = U.my_hum()
        if not hrp then
            return
        end

        local tc = tp.Character
        local thrp = tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Head")
        local th = tc:FindFirstChildOfClass("Humanoid")

        if not thrp or not th then
            return
        end

        getgenv().FH_FLING_ACTIVE = (getgenv().FH_FLING_ACTIVE or 0) + 1

        if hrp.AssemblyLinearVelocity.Magnitude < 50 then
            TROLL.old_pos = hrp.CFrame
        end

        if th.Sit then
            getgenv().FH_FLING_ACTIVE = math.max(0, (getgenv().FH_FLING_ACTIVE or 1) - 1)
            return
        end

        local cam = Workspace.CurrentCamera
        local old_fdh = Workspace.FallenPartsDestroyHeight

        cam.CameraSubject = thrp
        pcall(function()
            Workspace.FallenPartsDestroyHeight = 0 / 0
        end)

        local bv = Instance.new("BodyVelocity")
        bv.Parent = hrp
        bv.Velocity = Vector3.zero
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)

        local se = nil
        if hum then
            se = hum:GetStateEnabled(Enum.HumanoidStateType.Seated)
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        end

        local tw = 2
        local tm = tick()
        local ang = 0

        repeat
            if hrp and th then
                local tv
                if TROLL.fling_bypass then
                    tv = th.MoveDirection * th.WalkSpeed
                else
                    tv = thrp.AssemblyLinearVelocity
                end

                if tv.Magnitude < 50 then
                    ang = ang + 100

                    local offsets = { 1.5, -1.5, 1.5, -1.5, 1.5, -1.5 }
                    for _, off in ipairs(offsets) do
                        hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, off, 0)
                            + th.MoveDirection * tv.Magnitude / 1.25
                        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(ang), 0, 0)
                        LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                        hrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                        hrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                        task.wait()
                    end
                else
                    local offsets = {
                        { 1.5, th.WalkSpeed },
                        { -1.5, -th.WalkSpeed },
                        { 1.5, th.WalkSpeed },
                        { -1.5, 0 },
                        { -1.5, 0 },
                        { -1.5, 0 },
                    }

                    for _, off in ipairs(offsets) do
                        hrp.CFrame = CFrame.new(thrp.Position) * CFrame.new(0, off[1], off[2])
                        hrp.CFrame = hrp.CFrame * CFrame.Angles(math.rad(90), 0, 0)
                        LocalPlayer.Character:SetPrimaryPartCFrame(hrp.CFrame)
                        hrp.AssemblyLinearVelocity = Vector3.new(9e7, 9e7 * 10, 9e7)
                        hrp.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
                        task.wait()
                    end
                end
            end
        until tm + tw < tick() or (getgenv().FH_FLING_ACTIVE or 0) == 0

        if bv then
            bv:Destroy()
        end

        if hum and se ~= nil then
            hum:SetStateEnabled(Enum.HumanoidStateType.Seated, se)
        end

        cam.CameraSubject = hum

        if TROLL.old_pos and hrp then
            hrp.CFrame = TROLL.old_pos * CFrame.new(0, 0.5, 0)
            LocalPlayer.Character:SetPrimaryPartCFrame(TROLL.old_pos * CFrame.new(0, 0.5, 0))

            if hum then
                hum:ChangeState("GettingUp")
            end

            for _, p in ipairs(LocalPlayer.Character:GetChildren()) do
                if p:IsA("BasePart") then
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end
            end

            pcall(function()
                Workspace.FallenPartsDestroyHeight = old_fdh
            end)
        end

        getgenv().FH_FLING_ACTIVE = math.max(0, (getgenv().FH_FLING_ACTIVE or 1) - 1)
    end

    local function fling_target(tp)
        if TROLL.fling_mode == "shitaro" then
            fling_shitaro(tp)
        else
            fling_classic(tp)
        end
    end

    -- ----------------------------------------
    -- Тул отброса — выдача/удаление
    -- ----------------------------------------
    local function give_fling_tool()
        if not TROLL.fling_on then
            return
        end

        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not bp then
            return
        end

        local existing = bp:FindFirstChild("fling")
        if not existing and LocalPlayer.Character then
            existing = LocalPlayer.Character:FindFirstChild("fling")
        end
        if existing then
            TROLL.fling_tool = existing
            return
        end

        if TROLL.fling_act_conn then
            pcall(function() TROLL.fling_act_conn:Disconnect() end)
            TROLL.fling_act_conn = nil
        end

        local tool = Instance.new("Tool")
        tool.Name = "fling"
        tool.RequiresHandle = false
        tool.CanBeDropped = false
        tool.Parent = bp

        TROLL.fling_tool = tool

        TROLL.fling_act_conn = tool.Activated:Connect(function()
            local tp = clicked_player()
            if tp then
                FH.track(task.spawn(fling_target, tp))
            end
        end)
    end

    local function remove_fling_tool()
        if TROLL.fling_act_conn then
            pcall(function() TROLL.fling_act_conn:Disconnect() end)
            TROLL.fling_act_conn = nil
        end

        if TROLL.fling_tool then
            pcall(function() TROLL.fling_tool:Destroy() end)
            TROLL.fling_tool = nil
        end

        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp then
            local t = bp:FindFirstChild("fling")
            if t then t:Destroy() end
        end

        local c = LocalPlayer.Character
        if c then
            local t = c:FindFirstChild("fling")
            if t then t:Destroy() end
        end
    end

    local fling_outer = FlingSec:toggle({
        name = "Тул отброса",
        default = false,
        flag = "troll_fling_tool",
        option = true,
        callback = function(v)
            TROLL.fling_on = v

            if v then
                give_fling_tool()

                if not TROLL.fling_add_conn then
                    TROLL.fling_add_conn = LocalPlayer.CharacterAdded:Connect(function()
                        task.wait(0.5)
                        if TROLL.fling_on then
                            give_fling_tool()
                        end
                    end)
                end
            else
                if TROLL.fling_add_conn then
                    pcall(function() TROLL.fling_add_conn:Disconnect() end)
                    TROLL.fling_add_conn = nil
                end
                remove_fling_tool()
            end
        end,
    })

    FH.reg_toggle(
        "troll_fling_tool",
        function(v) TROLL.fling_on = v end,
        function() return TROLL.fling_on end
    )

    if fling_outer and fling_outer.Option then
        fling_outer.Option:dropdown({
            name = "Режим флинга",
            default = "classic",
            values = { "classic", "shitaro" },
            flag = "troll_fling_mode",
            callback = function(v)
                if type(v) == "table" then
                    v = v[1]
                end
                TROLL.fling_mode = tostring(v or "classic")
            end,
        })

        FH.reg_drop(
            "troll_fling_mode",
            function(v) TROLL.fling_mode = tostring(v or "classic") end,
            function() return TROLL.fling_mode end
        )

        fling_outer.Option:toggle({
            name = "bypass velocity",
            default = false,
            flag = "troll_fling_bypass",
            callback = function(v)
                TROLL.fling_bypass = v
            end,
        })

        FH.reg_toggle(
            "troll_fling_bypass",
            function(v) TROLL.fling_bypass = v end,
            function() return TROLL.fling_bypass end
        )
    end

    -- ----------------------------------------
    -- Телепорты
    -- ----------------------------------------
    local function stable_tp(cf)
        local hrp = U.my_hrp()
        if not hrp then return end

        pcall(function()
            hrp.CFrame = cf
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        task.spawn(function()
            local h = U.my_hrp()
            if not h then return end

            local t = os.clock()
            while os.clock() - t < 0.25 and h.Parent do
                pcall(function()
                    h.AssemblyLinearVelocity = Vector3.zero
                    h.AssemblyAngularVelocity = Vector3.zero
                end)
                task.wait()
            end
        end)
    end

    local function teleport_to_lobby()
        local lobby = Workspace:FindFirstChild("RegularLobby")
            or Workspace:FindFirstChild("Lobby")
            or Workspace:FindFirstChild("SummerLobby")

        if not lobby then return end

        local locs = {}
        for _, o in ipairs(lobby:GetDescendants()) do
            if o:IsA("SpawnLocation")
                or (o:IsA("BasePart") and o.Name == "Spawn") then
                table.insert(locs, o)
            end
        end

        if #locs > 0 then
            local pick = locs[math.random(1, #locs)]
            stable_tp(pick.CFrame + Vector3.new(0, 3, 0))
        else
            local ok, pv = pcall(function()
                return lobby:GetPivot()
            end)
            if ok then
                stable_tp(pv + Vector3.new(0, 5, 0))
            end
        end
    end

    local function teleport_to_map()
        local list = {}
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("SpawnLocation")
                or (o:IsA("BasePart") and o.Name == "Spawn") then
                if not U.in_lobby(o) then
                    table.insert(list, o)
                end
            end
        end

        if #list == 0 then return end

        local pick = list[math.random(1, #list)]
        stable_tp(pick.CFrame + Vector3.new(0, 5, 0))
    end

    TpSec:button({
        name = "ТП в лобби",
        icon = FH.I("map"),
        callback = teleport_to_lobby,
    })

    TpSec:button({
        name = "ТП на карту",
        icon = FH.I("map"),
        callback = teleport_to_map,
    })

    -- ----------------------------------------
    -- Фейк-смерть
    -- ----------------------------------------
    local function stop_fake_death()
        if TROLL.fd_track then
            pcall(function() TROLL.fd_track:Stop() end)
            TROLL.fd_track = nil
        end

        if TROLL.fd_conn then
            pcall(function() TROLL.fd_conn:Disconnect() end)
            TROLL.fd_conn = nil
        end
    end

    local function play_fake_death(anim_id, loop)
        if type(anim_id) ~= "string" or anim_id == "" then
            return
        end

        local hum = U.my_hum()
        if not hum then return end

        stop_fake_death()

        local anim = Instance.new("Animation")
        anim.AnimationId = anim_id

        local ok, track = pcall(function()
            return hum:LoadAnimation(anim)
        end)

        if not ok or not track then return end

        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = loop and true or false
        track:Play()

        TROLL.fd_track = track

        TROLL.fd_conn = hum.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Running
                or new == Enum.HumanoidStateType.Jumping
                or new == Enum.HumanoidStateType.Freefall then
                stop_fake_death()
            end
        end)

        if not loop then
            task.delay(3, stop_fake_death)
        end
    end

    FdSec:button({
        name = "Фейк смерть 1",
        icon = FH.I("skull"),
        callback = function()
            play_fake_death(TROLL.fd_anim1, true)
        end,
    })

    FdSec:button({
        name = "Фейк смерть 2",
        icon = FH.I("skull"),
        callback = function()
            play_fake_death(TROLL.fd_anim2, true)
        end,
    })

    FdSec:button({
        name = "Остановить",
        icon = FH.I("trash"),
        callback = stop_fake_death,
    })
end

-- ==============================================================
-- 11. CONFIG TAB
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local CFG = FH.CFG
    local I = FH.I

    local CfgSec = Wrap.section(Tabs.Cfg, { Name = "Конфиги", Side = "left" })

    local cfg_drop = CfgSec:dropdown({
        name = "Файл",
        default = "",
        values = CFG.List(),
        flag = "cfg_picker",
        callback = function() end,
    })

    local function cfg_sel()
        local v = cfg_drop:get()
        if type(v) == "table" then
            v = v[1]
        end
        return v
    end

    local function cfg_refresh()
        pcall(function()
            cfg_drop:setlist(CFG.List())
        end)
    end

    CfgSec:button({
        name = "Сохранить",
        icon = I("save"),
        callback = function()
            local n = cfg_sel()
            if n and n ~= "" then
                CFG.Save(n)
                cfg_refresh()
            end
        end,
    })

    CfgSec:button({
        name = "Загрузить",
        icon = I("folder"),
        callback = function()
            local n = cfg_sel()
            if n and n ~= "" then
                CFG.Load(n)
            end
        end,
    })

    CfgSec:button({
        name = "Удалить",
        icon = I("trash"),
        callback = function()
            local n = cfg_sel()
            if n and n ~= "" then
                CFG.Delete(n)
                cfg_refresh()
            end
        end,
    })

    CfgSec:button({
        name = "Обновить список",
        icon = I("refresh"),
        callback = cfg_refresh,
    })
end

-- ==============================================================
-- 12. COMBAT (Aim + Silent + Wallshot)
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local U = FH.U
    local I = FH.I
    local Players = FH.Players
    local ReplicatedStorage = FH.ReplicatedStorage
    local CollectionService = FH.CollectionService
    local RunService = FH.RunService
    local UserInputService = FH.UserInputService
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer

    local CombatAim    = Wrap.section(Tabs.Combat, { Name = "Aim",    Side = "left"  })
    local CombatSilent = Wrap.section(Tabs.Combat, { Name = "Silent", Side = "right" })

    local CB = {
        aim_on = false,
        aim_fov = 120,
        aim_smooth = 0.15,
        aim_part = "Head",
        aim_visible = true,
        aim_hold = false,
        aim_key = Enum.UserInputType.MouseButton2,

        silent_on = false,
        silent_force = false,
        silent_auto = false,
        silent_auto_delay = 0,
        silent_stand_off = 15,

        target_player = nil,
        target_part = nil,
        target_char = nil,
        target_hum = nil,

        fire_gap = 0,
        last_shot = 0,
        want_since = 0,
    }

    FH.CB = CB

    local function hrp_of(char)
        if not char then return nil end
        return char:FindFirstChild("HumanoidRootPart")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
    end

    local function is_alive(char)
        if not char then return false end
        local h = char:FindFirstChildOfClass("Humanoid")
        if not h then return false end
        return h.Health > 0
    end

    local function lp_has_gun()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Gun") then
            return true
        end

        local b = LocalPlayer:FindFirstChildOfClass("Backpack")
        if b and b:FindFirstChild("Gun") then
            return true
        end
        return false
    end

    FH.hrp_of = hrp_of
    FH.is_alive = is_alive

    -- Raycast
    local ray_params = RaycastParams.new()
    ray_params.FilterType = Enum.RaycastFilterType.Exclude
    ray_params.IgnoreWater = false

    local ignore_base = {}
    local ignore_work = {}
    local ignore_time = 0

    local function refresh_ignore()
        local t = os.clock()
        if #ignore_base > 0 and t - ignore_time < 0.5 then
            return
        end

        ignore_time = t
        table.clear(ignore_base)

        if LocalPlayer.Character then
            ignore_base[1] = LocalPlayer.Character
        end

        local ok, tagged = pcall(function()
            return CollectionService:GetTagged("WeaponPassthrough")
        end)

        if ok and type(tagged) == "table" then
            for i = 1, #tagged do
                ignore_base[#ignore_base + 1] = tagged[i]
            end
        end
    end

    local function trace(origin, direction)
        refresh_ignore()
        table.clear(ignore_work)

        for i = 1, #ignore_base do
            ignore_work[i] = ignore_base[i]
        end

        local result = nil
        for _ = 1, 6 do
            ray_params.FilterDescendantsInstances = ignore_work
            result = Workspace:Raycast(origin, direction, ray_params)
            if not result then break end

            local inst = result.Instance
            if not inst then break end

            local ok, tr = pcall(function()
                return inst.Transparency
            end)
            if not ok or tr ~= 1 then break end

            ignore_work[#ignore_work + 1] = inst
        end

        return result
    end

    local function can_see(from_pos, to_pos, target_char)
        if not from_pos or not to_pos then
            return false
        end

        local delta = to_pos - from_pos
        local dist = delta.Magnitude

        if dist < 1 then
            return true
        end

        local hit = trace(from_pos, delta)
        if not hit then
            return true
        end

        local inst = hit.Instance
        if target_char and (inst == target_char or inst:IsDescendantOf(target_char)) then
            return true
        end

        return (hit.Position - from_pos).Magnitude >= dist - 0.75
    end

    FH.can_see = can_see

    -- Wall-shot
    local WALLSHOT = {
        force_att = nil,
        force_saved = nil,
        force_stamp = 0,
    }

    local function gun_attachment()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return nil, nil
        end
        return hrp:FindFirstChild("GunRaycastAttachment"), hrp
    end

    local function restore_origin()
        local att = WALLSHOT.force_att
        if not att then return end

        local saved = WALLSHOT.force_saved
        WALLSHOT.force_att = nil
        WALLSHOT.force_saved = nil

        if saved then
            pcall(function()
                if att.Parent then
                    att.CFrame = saved
                end
            end)
        end
    end

    FH.restore_origin = restore_origin

    local function push_origin(cf)
        local att = gun_attachment()
        if not att then
            return false
        end

        if WALLSHOT.force_att and WALLSHOT.force_att ~= att then
            restore_origin()
        end

        if not WALLSHOT.force_att then
            local ok, saved = pcall(function()
                return att.CFrame
            end)
            if not ok or typeof(saved) ~= "CFrame" then
                return false
            end
            WALLSHOT.force_att = att
            WALLSHOT.force_saved = saved
        end

        WALLSHOT.force_stamp = os.clock()

        local ok = pcall(function()
            att.WorldCFrame = cf
        end)

        if not ok then
            restore_origin()
            return false
        end

        task.defer(restore_origin)
        return true
    end

    FH.push_origin = push_origin

    local function resolve_wall_cframe(target_part, target_char, stand_off)
        if not target_part or not target_part.Parent then
            return nil
        end

        stand_off = stand_off or 15
        local live = target_part.Position

        local att, hrp = gun_attachment()
        if not hrp then return nil end

        local origin = att and att.WorldCFrame.Position or hrp.Position
        local dir = live - origin

        if dir.Magnitude < 1 then
            return nil
        end

        dir = dir.Unit

        local back = live - dir * stand_off
        local front = live + dir * 8

        local hit = trace(back, front - back)
        local blocked = hit and not (hit.Instance == target_char
            or hit.Instance:IsDescendantOf(target_char))

        if blocked then
            back = live + Vector3.new(0, 6, 0) - dir * 4
            front = live
        end

        return CFrame.new(back, live)
    end

    -- Aim
    local function pick_target_aim()
        local cam = Workspace.CurrentCamera
        if not cam then return nil, nil end

        local origin_pos = cam.CFrame.Position
        local best, best_part, best_d = nil, nil, math.huge
        local center = cam.ViewportSize * 0.5

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer
                and plr.Character
                and is_alive(plr.Character) then
                local char = plr.Character
                local part = char:FindFirstChild(CB.aim_part)
                    or char:FindFirstChild("Head")
                    or hrp_of(char)

                if part then
                    local sp, on = cam:WorldToViewportPoint(part.Position)
                    if on then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= CB.aim_fov and d < best_d then
                            if not CB.aim_visible
                                or can_see(origin_pos, part.Position, char) then
                                best = plr
                                best_part = part
                                best_d = d
                            end
                        end
                    end
                end
            end
        end

        return best, best_part
    end

    local aim_tgl = CombatAim:toggle({
        name = "Aim",
        default = false,
        flag = "combat_aim",
        option = true,
        callback = function(v)
            CB.aim_on = v

            if v then
                FH.track(task.spawn(function()
                    while CB.aim_on do
                        local pressed = true

                        if CB.aim_hold then
                            if CB.aim_key == Enum.UserInputType.MouseButton2 then
                                pressed = UserInputService:IsMouseButtonPressed(
                                    Enum.UserInputType.MouseButton2)
                            elseif CB.aim_key == Enum.UserInputType.MouseButton1 then
                                pressed = UserInputService:IsMouseButtonPressed(
                                    Enum.UserInputType.MouseButton1)
                            elseif typeof(CB.aim_key) == "EnumItem" then
                                pressed = UserInputService:IsKeyDown(CB.aim_key)
                            end
                        end

                        if pressed then
                            local _, part = pick_target_aim()
                            if part then
                                local cam = Workspace.CurrentCamera
                                if cam then
                                    local cf = CFrame.new(cam.CFrame.Position, part.Position)
                                    local alpha = 1 - math.clamp(CB.aim_smooth, 0, 0.99)
                                    cam.CFrame = cam.CFrame:Lerp(cf, alpha)
                                end
                            end
                        end

                        RunService.RenderStepped:Wait()
                    end
                end))
            end
        end,
    })

    FH.reg_toggle(
        "combat_aim",
        function(v) CB.aim_on = v end,
        function() return CB.aim_on end
    )

    if aim_tgl.Option then
        aim_tgl.Option:slider({
            name = "FOV",
            min = 20,
            max = 400,
            default = 120,
            round = 0,
            flag = "combat_aim_fov",
            callback = function(v) CB.aim_fov = v end,
        })
        FH.reg_slider(
            "combat_aim_fov",
            function(v) CB.aim_fov = v end,
            function() return CB.aim_fov end
        )

        aim_tgl.Option:slider({
            name = "Smooth",
            min = 0,
            max = 0.95,
            default = 0.15,
            round = 2,
            flag = "combat_aim_smooth",
            callback = function(v) CB.aim_smooth = v end,
        })
        FH.reg_slider(
            "combat_aim_smooth",
            function(v) CB.aim_smooth = v end,
            function() return CB.aim_smooth end
        )

        aim_tgl.Option:dropdown({
            name = "Hitbox",
            default = "Head",
            values = { "Head", "HumanoidRootPart", "UpperTorso", "Torso" },
            flag = "combat_aim_part",
            callback = function(v)
                if type(v) == "table" then v = v[1] end
                CB.aim_part = v
            end,
        })
        FH.reg_drop(
            "combat_aim_part",
            function(v)
                if type(v) == "table" then v = v[1] end
                CB.aim_part = v
            end,
            function() return CB.aim_part end
        )

        aim_tgl.Option:toggle({
            name = "Visible check",
            default = true,
            flag = "combat_aim_vis",
            callback = function(v) CB.aim_visible = v end,
        })
        FH.reg_toggle(
            "combat_aim_vis",
            function(v) CB.aim_visible = v end,
            function() return CB.aim_visible end
        )

        aim_tgl.Option:toggle({
            name = "Hold key",
            default = false,
            flag = "combat_aim_hold",
            callback = function(v) CB.aim_hold = v end,
        })
        FH.reg_toggle(
            "combat_aim_hold",
            function(v) CB.aim_hold = v end,
            function() return CB.aim_hold end
        )

        aim_tgl.Option:keybind({
            name = "Key",
            default = "MouseButton2",
            flag = "combat_aim_key",
            callback = function(k)
                if type(k) == "string" then
                    if k == "MouseButton2" then
                        CB.aim_key = Enum.UserInputType.MouseButton2
                    elseif k == "MouseButton1" then
                        CB.aim_key = Enum.UserInputType.MouseButton1
                    else
                        local ok, e = pcall(function()
                            return Enum.KeyCode[k]
                        end)
                        if ok then CB.aim_key = e end
                    end
                else
                    CB.aim_key = k
                end
            end,
        })
        FH.reg_key(
            "combat_aim_key",
            function(k)
                if type(k) == "string" then
                    if k == "MouseButton2" then
                        CB.aim_key = Enum.UserInputType.MouseButton2
                    elseif k == "MouseButton1" then
                        CB.aim_key = Enum.UserInputType.MouseButton1
                    else
                        local ok, e = pcall(function()
                            return Enum.KeyCode[k]
                        end)
                        if ok then CB.aim_key = e end
                    end
                else
                    CB.aim_key = k
                end
            end,
            function()
                if CB.aim_key == Enum.UserInputType.MouseButton2 then
                    return "MouseButton2"
                end
                if CB.aim_key == Enum.UserInputType.MouseButton1 then
                    return "MouseButton1"
                end
                return tostring(CB.aim_key)
            end
        )
    end

    -- Silent
    local function refresh_target()
        local found = nil

        local ok, mod = pcall(function()
            return require(ReplicatedStorage:WaitForChild("Modules")
                :WaitForChild("CurrentRoundClient"))
        end)

        if ok and type(mod) == "table" and type(mod.PlayerData) == "table" then
            for name, d in pairs(mod.PlayerData) do
                if type(d) == "table" and d.Role == "Murderer" and not d.Dead then
                    found = Players:FindFirstChild(name)
                    break
                end
            end
        end

        if not found then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    local c = plr.Character
                    if c and c:FindFirstChild("Knife") then
                        found = plr
                        break
                    end
                end
            end
        end

        if found ~= CB.target_player then
            CB.target_player = found
            CB.target_char = nil
            CB.target_part = nil
            CB.target_hum = nil
        end

        if not found then return end

        local char = found.Character
        if char ~= CB.target_char then
            CB.target_char = char
            CB.target_part = nil
            CB.target_hum = nil
        end

        if not char then return end

        if not CB.target_part or not CB.target_part.Parent then
            CB.target_part = char:FindFirstChild("HumanoidRootPart")
                or char:FindFirstChild("UpperTorso")
                or char:FindFirstChild("Torso")
        end

        if not CB.target_hum or not CB.target_hum.Parent then
            CB.target_hum = char:FindFirstChildOfClass("Humanoid")
        end
    end

    FH.refresh_target = refresh_target

    local function target_alive()
        if not CB.target_part or not CB.target_part.Parent then
            return false
        end
        if not CB.target_hum or not CB.target_hum.Parent then
            return false
        end
        return CB.target_hum.Health > 0
    end

    FH.target_alive = target_alive

    local HOOK = {
        installed = false,
        orig_mouse = nil,
        orig_screen = nil,
        ws = nil,
    }
    FH.HOOK = HOOK

    local function silent_resolve_shot()
        if not CB.silent_on then return nil end
        if not lp_has_gun() then return nil end
        if not target_alive() then return nil end

        if CB.silent_force then
            local cf = resolve_wall_cframe(CB.target_part, CB.target_char, CB.silent_stand_off)
            if cf and push_origin(cf) then
                return CFrame.new(CB.target_part.Position)
            end
        end

        local att = gun_attachment()
        if not att then return nil end

        if can_see(att.WorldCFrame.Position, CB.target_part.Position, CB.target_char) then
            return CFrame.new(CB.target_part.Position)
        end

        return nil
    end

    local function install_silent_hooks()
        if HOOK.installed then return end

        local ok, m = pcall(function()
            return require(ReplicatedStorage:WaitForChild("ClientServices")
                :WaitForChild("WeaponService"))
        end)

        if not ok or type(m) ~= "table" then return end

        HOOK.ws = m
        pcall(function() setreadonly(m, false) end)

        if type(m.GetMouseTargetCFrame) == "function" then
            HOOK.orig_mouse = m.GetMouseTargetCFrame
            m.GetMouseTargetCFrame = function(self, ...)
                local cf = silent_resolve_shot()
                if cf then return cf end
                return HOOK.orig_mouse(self, ...)
            end
        end

        if type(m.GetTargetPosition) == "function" then
            HOOK.orig_screen = m.GetTargetPosition
            m.GetTargetPosition = function(self, x, y, ...)
                local cf = silent_resolve_shot()
                if cf then return cf end
                return HOOK.orig_screen(self, x, y, ...)
            end
        end

        HOOK.installed = true

        FH.track(task.spawn(function()
            while CB.silent_on do
                if WALLSHOT.force_att and os.clock() - WALLSHOT.force_stamp > 0.05 then
                    restore_origin()
                end
                task.wait(0.05)
            end
        end))
    end

    local function get_gun()
        local c = LocalPlayer.Character
        if c then
            local g = c:FindFirstChild("Gun")
            if g then return g, true end
        end

        local b = LocalPlayer:FindFirstChildOfClass("Backpack")
        if b then
            local g = b:FindFirstChild("Gun")
            if g then return g, false end
        end
        return nil, false
    end

    local function fire_gun(gun, start_cf, aim_cf)
        if not gun or not start_cf or not aim_cf then
            return false
        end

        local r = gun:FindFirstChild("Shoot")
        if not r or not r:IsA("RemoteEvent") then
            return false
        end

        return (pcall(function()
            r:FireServer(start_cf, aim_cf)
        end))
    end

    local function silent_auto_step()
        if not CB.silent_on or not CB.silent_auto then
            return
        end
        if getgenv().AUTOFARM_HOLD then
            return
        end
        if not target_alive() then
            return
        end

        local gun, equipped = get_gun()
        if not gun then return end

        if not equipped then
            local hum = U.my_hum()
            if hum then
                pcall(function()
                    hum:EquipTool(gun)
                end)
            end
            return
        end

        if CB.want_since == 0 then
            CB.want_since = os.clock()
        end

        local hold = CB.silent_auto_delay
        if hold < CB.fire_gap then
            hold = CB.fire_gap
        end

        local since = CB.last_shot > 0 and CB.last_shot or 0
        if os.clock() - since < hold then
            return
        end

        local att = gun_attachment()
        if not att then return end

        local start_cf = att.WorldCFrame
        local aim_cf = silent_resolve_shot()
        if not aim_cf then return end

        if fire_gun(gun, start_cf, aim_cf) then
            CB.last_shot = os.clock()
        end
    end

    local silent_tgl = CombatSilent:toggle({
        name = "Silent Aim",
        default = false,
        flag = "combat_silent",
        option = true,
        callback = function(v)
            CB.silent_on = v

            if v then
                install_silent_hooks()

                FH.track(task.spawn(function()
                    while CB.silent_on do
                        refresh_target()
                        silent_auto_step()
                        task.wait(0.05)
                    end
                end))
            else
                restore_origin()
            end
        end,
    })

    FH.reg_toggle(
        "combat_silent",
        function(v) CB.silent_on = v end,
        function() return CB.silent_on end
    )

    if silent_tgl.Option then
        silent_tgl.Option:toggle({
            name = "Force shoot (через стены)",
            default = false,
            flag = "combat_silent_force",
            callback = function(v)
                CB.silent_force = v
                if not v then
                    restore_origin()
                end
            end,
        })
        FH.reg_toggle(
            "combat_silent_force",
            function(v) CB.silent_force = v end,
            function() return CB.silent_force end
        )

        silent_tgl.Option:slider({
            name = "Stand off",
            min = 0,
            max = 40,
            default = 15,
            round = 0,
            flag = "combat_silent_stand_off",
            callback = function(v) CB.silent_stand_off = v end,
        })
        FH.reg_slider(
            "combat_silent_stand_off",
            function(v) CB.silent_stand_off = v end,
            function() return CB.silent_stand_off end
        )

        silent_tgl.Option:toggle({
            name = "Auto shoot",
            default = false,
            flag = "combat_silent_auto",
            callback = function(v) CB.silent_auto = v end,
        })
        FH.reg_toggle(
            "combat_silent_auto",
            function(v) CB.silent_auto = v end,
            function() return CB.silent_auto end
        )

        silent_tgl.Option:slider({
            name = "Auto delay (ms)",
            min = 0,
            max = 600,
            default = 0,
            round = 0,
            flag = "combat_silent_auto_delay",
            callback = function(v) CB.silent_auto_delay = v / 1000 end,
        })
        FH.reg_slider(
            "combat_silent_auto_delay",
            function(v) CB.silent_auto_delay = v / 1000 end,
            function() return CB.silent_auto_delay * 1000 end
        )
    end
end

-- ==============================================================
-- 13. MOVEMENT
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local U = FH.U
    local RunService = FH.RunService
    local UserInputService = FH.UserInputService
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer

    local MoveSpeed = Wrap.section(Tabs.Move, { Name = "Speed", Side = "left"  })
    local MoveFly   = Wrap.section(Tabs.Move, { Name = "Fly",   Side = "right" })
    local MoveExtra = Wrap.section(Tabs.Move, { Name = "Extra", Side = "left"  })

    local MV = {
        ws_on = false,
        ws_value = 40,
        ws_orig = nil,

        jp_on = false,
        jp_value = 80,
        jp_orig = nil,
        jp_use_orig = nil,

        fly_on = false,
        fly_speed = 60,
        fly_up_kc = Enum.KeyCode.Space,
        fly_down_kc = Enum.KeyCode.LeftControl,
        fly_grav_orig = Workspace.Gravity,

        noclip_on = false,
        noclip_cache = {},

        bhop_on = false,
        bhop_power = 40,
        bhop_speed = 0,
        was_jumping = false,

        inf_jump_on = false,
        wallhop_on = false,
    }

    FH.MV = MV

    local ws_tgl = MoveSpeed:toggle({
        name = "Walkspeed",
        default = false,
        flag = "move_ws",
        option = true,
        callback = function(v)
            MV.ws_on = v
            local hum = U.my_hum()

            if v then
                if hum then
                    MV.ws_orig = hum.WalkSpeed
                end
            else
                if hum and MV.ws_orig then
                    hum.WalkSpeed = MV.ws_orig
                end
            end
        end,
    })

    FH.reg_toggle(
        "move_ws",
        function(v) MV.ws_on = v end,
        function() return MV.ws_on end
    )

    if ws_tgl.Option then
        ws_tgl.Option:slider({
            name = "Value",
            min = 16,
            max = 300,
            default = 40,
            round = 0,
            flag = "move_ws_value",
            callback = function(v) MV.ws_value = v end,
        })
        FH.reg_slider(
            "move_ws_value",
            function(v) MV.ws_value = v end,
            function() return MV.ws_value end
        )
    end

    local jp_tgl = MoveSpeed:toggle({
        name = "JumpPower",
        default = false,
        flag = "move_jp",
        option = true,
        callback = function(v)
            MV.jp_on = v
            local hum = U.my_hum()

            if v then
                if hum then
                    MV.jp_use_orig = hum.UseJumpPower
                    MV.jp_orig = hum.JumpPower
                end
            else
                if hum then
                    if MV.jp_use_orig ~= nil then
                        hum.UseJumpPower = MV.jp_use_orig
                    end
                    if MV.jp_orig then
                        hum.JumpPower = MV.jp_orig
                    end
                end
            end
        end,
    })

    FH.reg_toggle(
        "move_jp",
        function(v) MV.jp_on = v end,
        function() return MV.jp_on end
    )

    if jp_tgl.Option then
        jp_tgl.Option:slider({
            name = "Value",
            min = 0,
            max = 500,
            default = 80,
            round = 0,
            flag = "move_jp_value",
            callback = function(v) MV.jp_value = v end,
        })
        FH.reg_slider(
            "move_jp_value",
            function(v) MV.jp_value = v end,
            function() return MV.jp_value end
        )
    end

    local fly_tgl = MoveFly:toggle({
        name = "Fly",
        default = false,
        flag = "move_fly",
        option = true,
        callback = function(v)
            MV.fly_on = v
            if v then
                Workspace.Gravity = 0
            else
                Workspace.Gravity = MV.fly_grav_orig
                local hrp = U.my_hrp()
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end,
    })

    FH.reg_toggle(
        "move_fly",
        function(v) MV.fly_on = v end,
        function() return MV.fly_on end
    )

    if fly_tgl.Option then
        fly_tgl.Option:slider({
            name = "Speed",
            min = 10,
            max = 400,
            default = 60,
            round = 0,
            flag = "move_fly_speed",
            callback = function(v) MV.fly_speed = v end,
        })
        FH.reg_slider(
            "move_fly_speed",
            function(v) MV.fly_speed = v end,
            function() return MV.fly_speed end
        )
    end

    local noc_tgl = MoveExtra:toggle({
        name = "Noclip",
        default = false,
        flag = "move_noclip",
        callback = function(v)
            MV.noclip_on = v
            if not v then
                for p, c in pairs(MV.noclip_cache) do
                    if p and p.Parent then
                        pcall(function() p.CanCollide = c end)
                    end
                end
                MV.noclip_cache = {}
            end
        end,
    })

    FH.reg_toggle(
        "move_noclip",
        function(v) MV.noclip_on = v end,
        function() return MV.noclip_on end
    )

    local bhop_tgl = MoveExtra:toggle({
        name = "Bhop",
        default = false,
        flag = "move_bhop",
        option = true,
        callback = function(v)
            MV.bhop_on = v
            if not v then
                MV.bhop_speed = 0
                MV.was_jumping = false
            end
        end,
    })

    FH.reg_toggle(
        "move_bhop",
        function(v) MV.bhop_on = v end,
        function() return MV.bhop_on end
    )

    if bhop_tgl.Option then
        bhop_tgl.Option:slider({
            name = "Power",
            min = 10,
            max = 200,
            default = 40,
            round = 0,
            flag = "move_bhop_power",
            callback = function(v) MV.bhop_power = v end,
        })
        FH.reg_slider(
            "move_bhop_power",
            function(v) MV.bhop_power = v end,
            function() return MV.bhop_power end
        )
    end

    local infj_tgl = MoveExtra:toggle({
        name = "Infinite Jump",
        default = false,
        flag = "move_inf_jump",
        callback = function(v) MV.inf_jump_on = v end,
    })

    FH.reg_toggle(
        "move_inf_jump",
        function(v) MV.inf_jump_on = v end,
        function() return MV.inf_jump_on end
    )

    local wh_tgl = MoveExtra:toggle({
        name = "Wallhop",
        default = false,
        flag = "move_wallhop",
        callback = function(v) MV.wallhop_on = v end,
    })

    FH.reg_toggle(
        "move_wallhop",
        function(v) MV.wallhop_on = v end,
        function() return MV.wallhop_on end
    )

    -- Сердцебиение: WS, JP, Noclip, Bhop
    FH.track(task.spawn(function()
        while true do
            task.wait()

            local hum = U.my_hum()
            local hrp = U.my_hrp()

            if MV.ws_on and hum and hum.WalkSpeed ~= MV.ws_value then
                hum.WalkSpeed = MV.ws_value
            end

            if MV.jp_on and hum then
                if not hum.UseJumpPower then
                    hum.UseJumpPower = true
                end
                if hum.JumpPower ~= MV.jp_value then
                    hum.JumpPower = MV.jp_value
                end
            end

            if MV.noclip_on then
                local char = LocalPlayer.Character
                if char then
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") and p.CanCollide then
                            if MV.noclip_cache[p] == nil then
                                MV.noclip_cache[p] = p.CanCollide
                            end
                            p.CanCollide = false
                        end
                    end
                end
            end

            if MV.bhop_on and hum and hrp then
                local st = hum:GetState()
                local jumping = st == Enum.HumanoidStateType.Jumping
                local airborne = jumping
                    or st == Enum.HumanoidStateType.Freefall

                local base = math.max(hum.WalkSpeed, 1)
                local cap = math.max(MV.bhop_power, base)
                local step = math.max(MV.bhop_power * 0.1, 1)

                if MV.bhop_speed < base then
                    MV.bhop_speed = base
                end

                if jumping and not MV.was_jumping then
                    MV.bhop_speed = math.min(MV.bhop_speed + step, cap)

                    local v = hrp.AssemblyLinearVelocity
                    local xz = Vector3.new(v.X, 0, v.Z)
                    local dir

                    if xz.Magnitude > 0.1 then
                        dir = xz.Unit
                    else
                        local md = hum.MoveDirection
                        if md.Magnitude > 0.1 then
                            dir = U.flat_unit(md)
                        else
                            dir = U.flat_unit(hrp.CFrame.LookVector)
                        end
                    end

                    if dir.Magnitude > 0 then
                        hrp.AssemblyLinearVelocity = Vector3.new(
                            dir.X * MV.bhop_speed,
                            v.Y,
                            dir.Z * MV.bhop_speed
                        )
                    end
                end

                if not airborne then
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        hum.Jump = true
                    else
                        MV.bhop_speed = 0
                    end
                end

                MV.was_jumping = jumping
            end
        end
    end))

    -- Fly loop
    FH.track(task.spawn(function()
        while true do
            RunService.RenderStepped:Wait()

            if MV.fly_on then
                local hrp = U.my_hrp()
                if hrp then
                    local cam = Workspace.CurrentCamera
                    if cam then
                        local dir = Vector3.zero

                        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                            dir = dir + cam.CFrame.LookVector
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                            dir = dir - cam.CFrame.LookVector
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                            dir = dir - cam.CFrame.RightVector
                        end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                            dir = dir + cam.CFrame.RightVector
                        end
                        if UserInputService:IsKeyDown(MV.fly_up_kc) then
                            dir = dir + Vector3.yAxis
                        end
                        if UserInputService:IsKeyDown(MV.fly_down_kc) then
                            dir = dir - Vector3.yAxis
                        end

                        if dir.Magnitude > 0 then
                            dir = dir.Unit * MV.fly_speed
                        end

                        hrp.AssemblyLinearVelocity = dir
                    end
                end
            end
        end
    end))

    -- Infinite jump + Wallhop
    UserInputService.JumpRequest:Connect(function()
        if MV.inf_jump_on then
            local hum = U.my_hum()
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            return
        end

        if MV.wallhop_on then
            local hum = U.my_hum()
            local hrp = U.my_hrp()
            if not hum or not hrp then return end
            if hum.FloorMaterial ~= Enum.Material.Air then return end

            local hp = RaycastParams.new()
            hp.FilterType = Enum.RaycastFilterType.Exclude
            hp.IgnoreWater = true
            hp.FilterDescendantsInstances = { LocalPlayer.Character }

            local cam = Workspace.CurrentCamera
            local base = U.flat_unit(hum.MoveDirection)
            if base == Vector3.zero and cam then
                base = U.flat_unit(cam.CFrame.LookVector)
            end
            if base == Vector3.zero then return end

            local pos = hrp.Position
            local angles = { 0, 0.45, -0.45, 0.9, -0.9, 1.4, -1.4, 2, -2, 2.6, -2.6, 3.14 }

            for _, a in ipairs(angles) do
                local c, s = math.cos(a), math.sin(a)
                local dir = Vector3.new(
                    base.X * c + base.Z * s,
                    0,
                    base.Z * c - base.X * s
                ) * 3

                local hit = Workspace:Raycast(pos, dir, hp)

                if hit and math.abs(hit.Normal.Y) < 0.5 then
                    local n = U.flat_unit(hit.Normal)
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)

                    local v = hrp.AssemblyLinearVelocity
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        v.X + n.X * 3,
                        v.Y,
                        v.Z + n.Z * 3
                    )
                    break
                end
            end
        end
    end)
end

print("[FortniHub " .. FH.ADDON_VERSION .. "] Part 1/2 loaded.")
--[[
================================================================
    FortniHub MM2 — v18.5.0
    by HOTI and Ve315
    Split build — Part 2 / 2
================================================================
    Идёт СРАЗУ после Part 1 в том же файле (или после INJECT,
    если у тебя два инжекта). Использует namespace getgenv().FH,
    который публикует Part 1.
================================================================
]]

local FH = getgenv().FH
if not FH or not FH.CFG then
    warn("[FortniHub Part 2] Part 1 не загружен — abort.")
    return
end

-- Удобные локальные ссылки (ограничены — все они уйдут после этого блока
-- в конец файла, никаких проблем с регистрами не будет)
local ADDON_VERSION = FH.ADDON_VERSION
local CFG           = FH.CFG
local U             = FH.U
local I             = FH.I
local Tabs          = FH.Tabs
local Wrap          = FH.Wrap
local CFG_ROOT      = FH.CFG_ROOT
local fs_ok         = FH.fs_ok

-- ==============================================================
-- 14. VISUAL — ESP
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local I = FH.I
    local U = FH.U

    local Players = FH.Players
    local RunService = FH.RunService
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer

    local VisEsp = Wrap.section(Tabs.Visual, { Name = "ESP", Side = "left" })

    local VIS = {
        esp_on         = false,
        esp_box        = false,
        esp_box_color  = Color3.fromRGB(255, 60, 60),
        esp_name       = false,
        esp_name_color = Color3.fromRGB(255, 255, 255),
        esp_dist       = false,
        esp_dist_color = Color3.fromRGB(255, 255, 255),
        esp_health     = false,
        drawings       = {},
        conn           = nil,
    }

    FH.VIS = VIS

    local Drawing_new = Drawing and Drawing.new

    local function new_drawing(class_name, props)
        if not Drawing_new then
            return nil
        end

        local d = Drawing_new(class_name)

        if props then
            for k, v in pairs(props) do
                pcall(function()
                    d[k] = v
                end)
            end
        end

        return d
    end

    local function esp_pool_get(idx)
        if not VIS.drawings[idx] then
            VIS.drawings[idx] = {
                box = new_drawing("Square", {
                    Thickness = 1,
                    Filled = false,
                    Transparency = 1,
                    Visible = false,
                    ZIndex = 2,
                }),
                box_ol = new_drawing("Square", {
                    Thickness = 3,
                    Filled = false,
                    Color = Color3.new(0, 0, 0),
                    Transparency = 1,
                    Visible = false,
                    ZIndex = 1,
                }),
                name = new_drawing("Text", {
                    Center = true,
                    Outline = true,
                    Size = 14,
                    Color = Color3.new(1, 1, 1),
                    Visible = false,
                    ZIndex = 3,
                }),
                dist = new_drawing("Text", {
                    Center = true,
                    Outline = true,
                    Size = 12,
                    Color = Color3.new(1, 1, 1),
                    Visible = false,
                    ZIndex = 3,
                }),
                hp = new_drawing("Line", {
                    Thickness = 2,
                    Color = Color3.new(0, 1, 0),
                    Visible = false,
                    ZIndex = 3,
                }),
            }
        end

        return VIS.drawings[idx]
    end

    local function esp_hide_all()
        for _, t in pairs(VIS.drawings) do
            for _, d in pairs(t) do
                if d then
                    pcall(function()
                        d.Visible = false
                    end)
                end
            end
        end
    end

    local function esp_render()
        if not VIS.esp_on then
            esp_hide_all()
            return
        end

        local cam = Workspace.CurrentCamera
        if not cam then
            return
        end

        local idx = 0

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer
                and plr.Character
                and FH.is_alive(plr.Character) then

                local char = plr.Character
                local hrp = FH.hrp_of(char)
                local head = char:FindFirstChild("Head")

                if hrp and head then
                    idx = idx + 1
                    local pool = esp_pool_get(idx)

                    local hrp_sp, on1 = cam:WorldToViewportPoint(hrp.Position)
                    local head_sp, on2 = cam:WorldToViewportPoint(
                        head.Position + Vector3.new(0, 0.5, 0))

                    if on1 and on2 and hrp_sp.Z > 0 then
                        local h = math.abs(head_sp.Y - hrp_sp.Y) * 2.2
                        local w = h * 0.55
                        local x = hrp_sp.X - w * 0.5
                        local y = hrp_sp.Y - h * 0.75

                        if VIS.esp_box then
                            pool.box.Position = Vector2.new(x, y)
                            pool.box.Size = Vector2.new(w, h)
                            pool.box.Color = VIS.esp_box_color
                            pool.box.Visible = true

                            pool.box_ol.Position = Vector2.new(x, y)
                            pool.box_ol.Size = Vector2.new(w, h)
                            pool.box_ol.Visible = true
                        else
                            pool.box.Visible = false
                            pool.box_ol.Visible = false
                        end

                        if VIS.esp_name then
                            pool.name.Text = plr.Name
                            pool.name.Position = Vector2.new(hrp_sp.X, y - 16)
                            pool.name.Color = VIS.esp_name_color
                            pool.name.Visible = true
                        else
                            pool.name.Visible = false
                        end

                        if VIS.esp_dist then
                            local my = U.my_hrp()
                            local dist = 0
                            if my then
                                dist = math.floor(
                                    (my.Position - hrp.Position).Magnitude)
                            end

                            pool.dist.Text = tostring(dist) .. "m"
                            pool.dist.Position = Vector2.new(
                                hrp_sp.X, y + h + 2)
                            pool.dist.Color = VIS.esp_dist_color
                            pool.dist.Visible = true
                        else
                            pool.dist.Visible = false
                        end

                        if VIS.esp_health then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            local hp = hum and hum.Health or 0
                            local max = hum and hum.MaxHealth or 100
                            local pct = math.clamp(hp / max, 0, 1)

                            pool.hp.From = Vector2.new(x - 4, y + h)
                            pool.hp.To = Vector2.new(x - 4, y + h - h * pct)
                            pool.hp.Color = Color3.fromRGB(
                                255 * (1 - pct),
                                255 * pct,
                                0
                            )
                            pool.hp.Visible = true
                        else
                            pool.hp.Visible = false
                        end
                    else
                        pool.box.Visible = false
                        pool.box_ol.Visible = false
                        pool.name.Visible = false
                        pool.dist.Visible = false
                        pool.hp.Visible = false
                    end
                end
            end
        end

        for i = idx + 1, #VIS.drawings do
            local pool = VIS.drawings[i]
            for _, d in pairs(pool) do
                if d then
                    pcall(function()
                        d.Visible = false
                    end)
                end
            end
        end
    end

    local esp_tgl = VisEsp:toggle({
        name = "ESP",
        default = false,
        flag = "vis_esp",
        option = true,
        callback = function(v)
            VIS.esp_on = v

            if v then
                if not VIS.conn then
                    VIS.conn = RunService.RenderStepped:Connect(function()
                        pcall(esp_render)
                    end)
                end
            else
                esp_hide_all()
            end
        end,
    })

    FH.reg_toggle(
        "vis_esp",
        function(v) VIS.esp_on = v end,
        function() return VIS.esp_on end
    )

    if esp_tgl.Option then
        esp_tgl.Option:toggle({
            name = "Box",
            default = false,
            flag = "vis_esp_box",
            callback = function(v) VIS.esp_box = v end,
        })

        FH.reg_toggle(
            "vis_esp_box",
            function(v) VIS.esp_box = v end,
            function() return VIS.esp_box end
        )

        esp_tgl.Option:colorpicker({
            name = "Box color",
            default = Color3.fromRGB(255, 60, 60),
            flag = "vis_esp_box_color",
            callback = function(c) VIS.esp_box_color = c end,
        })

        FH.reg_color(
            "vis_esp_box_color",
            function(c) VIS.esp_box_color = c end,
            function() return VIS.esp_box_color end
        )

        esp_tgl.Option:toggle({
            name = "Name",
            default = false,
            flag = "vis_esp_name",
            callback = function(v) VIS.esp_name = v end,
        })

        FH.reg_toggle(
            "vis_esp_name",
            function(v) VIS.esp_name = v end,
            function() return VIS.esp_name end
        )

        esp_tgl.Option:colorpicker({
            name = "Name color",
            default = Color3.fromRGB(255, 255, 255),
            flag = "vis_esp_name_color",
            callback = function(c) VIS.esp_name_color = c end,
        })

        FH.reg_color(
            "vis_esp_name_color",
            function(c) VIS.esp_name_color = c end,
            function() return VIS.esp_name_color end
        )

        esp_tgl.Option:toggle({
            name = "Distance",
            default = false,
            flag = "vis_esp_dist",
            callback = function(v) VIS.esp_dist = v end,
        })

        FH.reg_toggle(
            "vis_esp_dist",
            function(v) VIS.esp_dist = v end,
            function() return VIS.esp_dist end
        )

        esp_tgl.Option:colorpicker({
            name = "Distance color",
            default = Color3.fromRGB(255, 255, 255),
            flag = "vis_esp_dist_color",
            callback = function(c) VIS.esp_dist_color = c end,
        })

        FH.reg_color(
            "vis_esp_dist_color",
            function(c) VIS.esp_dist_color = c end,
            function() return VIS.esp_dist_color end
        )

        esp_tgl.Option:toggle({
            name = "Health",
            default = false,
            flag = "vis_esp_hp",
            callback = function(v) VIS.esp_health = v end,
        })

        FH.reg_toggle(
            "vis_esp_health",
            function(v) VIS.esp_health = v end,
            function() return VIS.esp_health end
        )
    end
end

-- ==============================================================
-- 15. VISUAL — WORLD
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local Lighting = FH.Lighting
    local Workspace = FH.Workspace

    local VisWorld = Wrap.section(Tabs.Visual, { Name = "World", Side = "right" })

    local WORLD = {
        fb_on = false,

        fog_on    = false,
        fog_color = Color3.fromRGB(192, 192, 192),
        fog_start = 0,
        fog_end   = 1000,

        ambient_on    = false,
        ambient_color = Color3.fromRGB(128, 128, 128),

        skybox_on    = false,
        skybox_name  = "Jungle",
        created_sky  = nil,

        orig = {
            brightness = Lighting.Brightness,
            shadows    = Lighting.GlobalShadows,
            fog_color  = Lighting.FogColor,
            fog_start  = Lighting.FogStart,
            fog_end    = Lighting.FogEnd,
            ambient    = Lighting.Ambient,
            outdoor    = Lighting.OutdoorAmbient,
        },
    }

    FH.WORLD = WORLD

    local SKYBOXES = {
        ["Jungle"] = {
            SkyboxBk = "http://www.roblox.com/asset/?id=214399891",
            SkyboxDn = "http://www.roblox.com/asset/?id=214399887",
            SkyboxFt = "http://www.roblox.com/asset/?id=214399894",
            SkyboxLf = "http://www.roblox.com/asset/?id=214405668",
            SkyboxRt = "http://www.roblox.com/asset/?id=214399899",
            SkyboxUp = "http://www.roblox.com/asset/?id=214399889",
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
    }

    local function apply_skybox(name)
        if WORLD.created_sky then
            pcall(function()
                WORLD.created_sky:Destroy()
            end)
            WORLD.created_sky = nil
        end

        local data = SKYBOXES[name]
        if not data then
            return
        end

        local sky = Instance.new("Sky")
        sky.Name = "FH_Sky"

        for k, v in pairs(data) do
            pcall(function()
                sky[k] = v
            end)
        end

        sky.Parent = Lighting
        WORLD.created_sky = sky
    end

    local function clear_skybox()
        if WORLD.created_sky then
            pcall(function()
                WORLD.created_sky:Destroy()
            end)
            WORLD.created_sky = nil
        end
    end

    FH.apply_skybox = apply_skybox
    FH.clear_skybox = clear_skybox

    local fb_tgl = VisWorld:toggle({
        name = "Fullbright",
        default = false,
        flag = "world_fb",
        callback = function(v)
            WORLD.fb_on = v

            if v then
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 100000
                Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
            else
                Lighting.Brightness = WORLD.orig.brightness
                Lighting.GlobalShadows = WORLD.orig.shadows
                Lighting.FogEnd = WORLD.orig.fog_end
                Lighting.OutdoorAmbient = WORLD.orig.outdoor
            end
        end,
    })

    FH.reg_toggle(
        "world_fb",
        function(v) WORLD.fb_on = v end,
        function() return WORLD.fb_on end
    )

    local fog_tgl = VisWorld:toggle({
        name = "Custom Fog",
        default = false,
        flag = "world_fog",
        option = true,
        callback = function(v)
            WORLD.fog_on = v

            if v then
                Lighting.FogColor = WORLD.fog_color
                Lighting.FogStart = WORLD.fog_start
                Lighting.FogEnd = WORLD.fog_end
            else
                Lighting.FogColor = WORLD.orig.fog_color
                Lighting.FogStart = WORLD.orig.fog_start
                Lighting.FogEnd = WORLD.orig.fog_end
            end
        end,
    })

    FH.reg_toggle(
        "world_fog",
        function(v) WORLD.fog_on = v end,
        function() return WORLD.fog_on end
    )

    if fog_tgl.Option then
        fog_tgl.Option:colorpicker({
            name = "Color",
            default = Color3.fromRGB(192, 192, 192),
            flag = "world_fog_color",
            callback = function(c)
                WORLD.fog_color = c
                if WORLD.fog_on then
                    Lighting.FogColor = c
                end
            end,
        })

        FH.reg_color(
            "world_fog_color",
            function(c) WORLD.fog_color = c end,
            function() return WORLD.fog_color end
        )

        fog_tgl.Option:slider({
            name = "Start",
            min = 0,
            max = 1000,
            default = 0,
            round = 0,
            flag = "world_fog_start",
            callback = function(v)
                WORLD.fog_start = v
                if WORLD.fog_on then
                    Lighting.FogStart = v
                end
            end,
        })

        FH.reg_slider(
            "world_fog_start",
            function(v) WORLD.fog_start = v end,
            function() return WORLD.fog_start end
        )

        fog_tgl.Option:slider({
            name = "End",
            min = 0,
            max = 1000,
            default = 1000,
            round = 0,
            flag = "world_fog_end",
            callback = function(v)
                WORLD.fog_end = v
                if WORLD.fog_on then
                    Lighting.FogEnd = v
                end
            end,
        })

        FH.reg_slider(
            "world_fog_end",
            function(v) WORLD.fog_end = v end,
            function() return WORLD.fog_end end
        )
    end

    local amb_tgl = VisWorld:toggle({
        name = "Ambient",
        default = false,
        flag = "world_ambient",
        option = true,
        callback = function(v)
            WORLD.ambient_on = v

            if v then
                Lighting.Ambient = WORLD.ambient_color
                Lighting.OutdoorAmbient = WORLD.ambient_color
            else
                Lighting.Ambient = WORLD.orig.ambient
                Lighting.OutdoorAmbient = WORLD.orig.outdoor
            end
        end,
    })

    FH.reg_toggle(
        "world_ambient",
        function(v) WORLD.ambient_on = v end,
        function() return WORLD.ambient_on end
    )

    if amb_tgl.Option then
        amb_tgl.Option:colorpicker({
            name = "Color",
            default = Color3.fromRGB(128, 128, 128),
            flag = "world_ambient_color",
            callback = function(c)
                WORLD.ambient_color = c
                if WORLD.ambient_on then
                    Lighting.Ambient = c
                    Lighting.OutdoorAmbient = c
                end
            end,
        })

        FH.reg_color(
            "world_ambient_color",
            function(c) WORLD.ambient_color = c end,
            function() return WORLD.ambient_color end
        )
    end

    local sky_tgl = VisWorld:toggle({
        name = "Skybox",
        default = false,
        flag = "world_skybox",
        option = true,
        callback = function(v)
            WORLD.skybox_on = v
            if v then
                apply_skybox(WORLD.skybox_name)
            else
                clear_skybox()
            end
        end,
    })

    FH.reg_toggle(
        "world_skybox",
        function(v) WORLD.skybox_on = v end,
        function() return WORLD.skybox_on end
    )

    if sky_tgl.Option then
        sky_tgl.Option:dropdown({
            name = "Preset",
            default = "Jungle",
            values = { "Jungle", "Red night", "Purple" },
            flag = "world_skybox_name",
            callback = function(v)
                if type(v) == "table" then
                    v = v[1]
                end
                WORLD.skybox_name = v
                if WORLD.skybox_on then
                    apply_skybox(v)
                end
            end,
        })

        FH.reg_drop(
            "world_skybox_name",
            function(v)
                if type(v) == "table" then v = v[1] end
                WORLD.skybox_name = v
            end,
            function() return WORLD.skybox_name end
        )
    end
end

-- ==============================================================
-- 16. EFFECTS
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local I = FH.I

    local ReplicatedStorage = FH.ReplicatedStorage
    local TweenService = FH.TweenService
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer
    local RunService = FH.RunService
    local Players = FH.Players

    local FxTracer = Wrap.section(Tabs.Fx, { Name = "Tracers", Side = "left" })
    local FxChams  = Wrap.section(Tabs.Fx, { Name = "Chams", Side = "right" })
    local FxWorld  = Wrap.section(Tabs.Fx, { Name = "World", Side = "left" })
    local FxDeath  = Wrap.section(Tabs.Fx, { Name = "Death", Side = "right" })

    local FX = {
        tracer_on    = false,
        tracer_color = Color3.fromRGB(133, 220, 255),
        tracer_dur   = 1,

        chams_on      = false,
        chams_mur     = Color3.fromRGB(255, 0, 0),
        chams_inno    = Color3.fromRGB(255, 255, 255),
        chams_sheriff = Color3.fromRGB(0, 153, 255),
        chams_objs    = {},

        world_fx_on    = false,
        world_fx_type  = "Snow",
        world_fx_color = Color3.fromRGB(150, 200, 255),
        world_fx_rate  = 250,
        world_fx_part  = nil,
        world_fx_emit  = nil,

        murder_on    = false,
        murder_clone = false,
        murder_col   = Color3.fromRGB(255, 0, 0),
        murder_conns = {},
    }

    FH.FX = FX

    -- Tracers
    local tracer_fade = TweenInfo.new(
        0.2,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    )

    local function make_tracer_point(pos, lifetime)
        local p = Instance.new("Part")
        p.Transparency = 1
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.Size = Vector3.new(1, 1, 1)
        p.CFrame = CFrame.new(pos)

        Instance.new("Attachment", p)
        game:GetService("Debris"):AddItem(p, lifetime)
        p.Parent = Workspace
        return p
    end

    local function to_pos(v)
        if typeof(v) == "Vector3" then
            return v
        end
        if typeof(v) == "CFrame" then
            return v.Position
        end
        if typeof(v) == "Instance" then
            if v:IsA("Attachment") then
                return v.WorldPosition
            end
            if v:IsA("BasePart") then
                return v.Position
            end
        end
        return nil
    end

    local function create_tracer(start_v, end_v)
        local sp = to_pos(start_v)
        local ep = to_pos(end_v)

        if not sp or not ep then
            return
        end

        local dur = FX.tracer_dur
        local spart = make_tracer_point(sp, dur + 0.5)
        local epart = make_tracer_point(ep, dur + 0.5)

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
        beam.Color = ColorSequence.new(FX.tracer_color)
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 0.1),
        })

        beam.Attachment0 = spart:FindFirstChildOfClass("Attachment")
        beam.Attachment1 = epart:FindFirstChildOfClass("Attachment")
        beam.Parent = spart

        task.delay(dur, function()
            if beam.Parent then
                TweenService:Create(
                    beam,
                    tracer_fade,
                    { Width0 = 0, Width1 = 0 }
                ):Play()
            end
        end)
    end

    local tracer_conn = nil

    local function connect_tracer()
        if tracer_conn then
            return
        end

        local ok, remote = pcall(function()
            return ReplicatedStorage
                :WaitForChild("ClientServices")
                :WaitForChild("WeaponService")
                :WaitForChild("GunFired")
        end)

        if not ok or not remote then
            return
        end

        tracer_conn = remote.OnClientEvent:Connect(function(gun, sv, ev)
            if not FX.tracer_on then
                return
            end

            local char = LocalPlayer.Character
            if not char then
                return
            end

            if not (typeof(gun) == "Instance"
                and gun:IsDescendantOf(char)) then
                return
            end

            create_tracer(sv, ev)
        end)
    end

    local tr_tgl = FxTracer:toggle({
        name = "Bullet Tracer",
        default = false,
        flag = "fx_tracer",
        option = true,
        callback = function(v)
            FX.tracer_on = v
            if v then
                connect_tracer()
            end
        end,
    })

    FH.reg_toggle(
        "fx_tracer",
        function(v) FX.tracer_on = v end,
        function() return FX.tracer_on end
    )

    if tr_tgl.Option then
        tr_tgl.Option:colorpicker({
            name = "Color",
            default = Color3.fromRGB(133, 220, 255),
            flag = "fx_tracer_color",
            callback = function(c) FX.tracer_color = c end,
        })

        FH.reg_color(
            "fx_tracer_color",
            function(c) FX.tracer_color = c end,
            function() return FX.tracer_color end
        )

        tr_tgl.Option:slider({
            name = "Duration",
            min = 0.1,
            max = 5,
            default = 1,
            round = 1,
            flag = "fx_tracer_dur",
            callback = function(v) FX.tracer_dur = v end,
        })

        FH.reg_slider(
            "fx_tracer_dur",
            function(v) FX.tracer_dur = v end,
            function() return FX.tracer_dur end
        )
    end

    -- Chams
    local function chams_apply(char, plr)
        if not FX.chams_on or not char then
            return
        end

        local old = char:FindFirstChild("FH_Chams")
        if old then
            old:Destroy()
        end

        local hl = Instance.new("Highlight")
        hl.Name = "FH_Chams"
        hl.Adornee = char
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

        local color = FX.chams_inno

        if plr then
            local ok, mod = pcall(function()
                return require(ReplicatedStorage
                    :WaitForChild("Modules")
                    :WaitForChild("CurrentRoundClient"))
            end)

            if ok
                and type(mod) == "table"
                and type(mod.PlayerData) == "table" then

                local d = mod.PlayerData[plr.Name]

                if d then
                    if d.Role == "Murderer" then
                        color = FX.chams_mur
                    elseif d.Role == "Sheriff" or d.Role == "Hero" then
                        color = FX.chams_sheriff
                    end
                end
            end
        end

        hl.FillColor = color
        hl.OutlineColor = color
        hl.Parent = char

        FX.chams_objs[char] = hl
    end

    local function chams_clear()
        for _, hl in pairs(FX.chams_objs) do
            pcall(function()
                hl:Destroy()
            end)
        end
        FX.chams_objs = {}
    end

    FH.chams_clear = chams_clear

    local chams_tgl = FxChams:toggle({
        name = "Chams",
        default = false,
        flag = "fx_chams",
        option = true,
        callback = function(v)
            FX.chams_on = v

            if v then
                FH.track(task.spawn(function()
                    while FX.chams_on do
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if plr ~= LocalPlayer and plr.Character then
                                chams_apply(plr.Character, plr)
                            end
                        end
                        task.wait(0.5)
                    end
                end))
            else
                chams_clear()
            end
        end,
    })

    FH.reg_toggle(
        "fx_chams",
        function(v) FX.chams_on = v end,
        function() return FX.chams_on end
    )

    if chams_tgl.Option then
        chams_tgl.Option:colorpicker({
            name = "Murder",
            default = Color3.fromRGB(255, 0, 0),
            flag = "fx_chams_mur",
            callback = function(c) FX.chams_mur = c end,
        })

        FH.reg_color(
            "fx_chams_mur",
            function(c) FX.chams_mur = c end,
            function() return FX.chams_mur end
        )

        chams_tgl.Option:colorpicker({
            name = "Innocent",
            default = Color3.fromRGB(255, 255, 255),
            flag = "fx_chams_inno",
            callback = function(c) FX.chams_inno = c end,
        })

        FH.reg_color(
            "fx_chams_inno",
            function(c) FX.chams_inno = c end,
            function() return FX.chams_inno end
        )

        chams_tgl.Option:colorpicker({
            name = "Sheriff",
            default = Color3.fromRGB(0, 153, 255),
            flag = "fx_chams_sheriff",
            callback = function(c) FX.chams_sheriff = c end,
        })

        FH.reg_color(
            "fx_chams_sheriff",
            function(c) FX.chams_sheriff = c end,
            function() return FX.chams_sheriff end
        )
    end

    -- World FX
    local function style_world_emitter()
        local e = FX.world_fx_emit
        if not e then
            return
        end

        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.LightInfluence = 0
        e.LightEmission = 0.4
        e.Rate = FX.world_fx_rate
        e.Color = ColorSequence.new(FX.world_fx_color)

        if FX.world_fx_type == "Snow" then
            e.Lifetime = NumberRange.new(4, 6)
            e.Speed = NumberRange.new(6, 12)
            e.Acceleration = Vector3.new(2, -6, 1)
            e.SpreadAngle = Vector2.new(35, 35)
            e.Size = NumberSequence.new(0.55)
        else
            e.Lifetime = NumberRange.new(5, 7)
            e.Speed = NumberRange.new(5, 10)
            e.Acceleration = Vector3.new(4, -5, 2)
            e.SpreadAngle = Vector2.new(40, 40)
            e.Size = NumberSequence.new(0.5)
        end
    end

    local function world_fx_start()
        if not FX.world_fx_part then
            FX.world_fx_part = Instance.new("Part")
            FX.world_fx_part.Name = "FH_WorldFX"
            FX.world_fx_part.Anchored = true
            FX.world_fx_part.CanCollide = false
            FX.world_fx_part.CanQuery = false
            FX.world_fx_part.CanTouch = false
            FX.world_fx_part.Transparency = 1
            FX.world_fx_part.Size = Vector3.new(260, 140, 260)
            FX.world_fx_part.Parent = Workspace

            FX.world_fx_emit = Instance.new("ParticleEmitter")

            pcall(function()
                FX.world_fx_emit.Shape = Enum.ParticleEmitterShape.Box
                FX.world_fx_emit.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
            end)

            FX.world_fx_emit.Parent = FX.world_fx_part
            style_world_emitter()
        end

        FH.track(task.spawn(function()
            while FX.world_fx_on do
                local cam = Workspace.CurrentCamera
                if cam and FX.world_fx_part then
                    local flat = FH.U.flat_unit(cam.CFrame.LookVector)
                    FX.world_fx_part.CFrame = CFrame.new(
                        cam.CFrame.Position
                            + flat * 60
                            + Vector3.new(0, 44, 0)
                    )
                end
                task.wait()
            end
        end))
    end

    local function world_fx_stop()
        if FX.world_fx_part then
            pcall(function()
                FX.world_fx_part:Destroy()
            end)
            FX.world_fx_part = nil
            FX.world_fx_emit = nil
        end
    end

    FH.world_fx_stop = world_fx_stop

    local wfx_tgl = FxWorld:toggle({
        name = "World Effects",
        default = false,
        flag = "fx_world",
        option = true,
        callback = function(v)
            FX.world_fx_on = v
            if v then
                world_fx_start()
            else
                world_fx_stop()
            end
        end,
    })

    FH.reg_toggle(
        "fx_world",
        function(v) FX.world_fx_on = v end,
        function() return FX.world_fx_on end
    )

    if wfx_tgl.Option then
        wfx_tgl.Option:dropdown({
            name = "Preset",
            default = "Snow",
            values = { "Snow", "Sakura" },
            flag = "fx_world_type",
            callback = function(v)
                if type(v) == "table" then
                    v = v[1]
                end
                FX.world_fx_type = v
                if FX.world_fx_on then
                    style_world_emitter()
                end
            end,
        })

        FH.reg_drop(
            "fx_world_type",
            function(v)
                if type(v) == "table" then v = v[1] end
                FX.world_fx_type = v
            end,
            function() return FX.world_fx_type end
        )

        wfx_tgl.Option:colorpicker({
            name = "Color",
            default = Color3.fromRGB(150, 200, 255),
            flag = "fx_world_color",
            callback = function(c)
                FX.world_fx_color = c
                if FX.world_fx_emit then
                    FX.world_fx_emit.Color = ColorSequence.new(c)
                end
            end,
        })

        FH.reg_color(
            "fx_world_color",
            function(c) FX.world_fx_color = c end,
            function() return FX.world_fx_color end
        )

        wfx_tgl.Option:slider({
            name = "Rate",
            min = 20,
            max = 900,
            default = 250,
            round = 0,
            flag = "fx_world_rate",
            callback = function(v)
                FX.world_fx_rate = v
                if FX.world_fx_emit then
                    style_world_emitter()
                end
            end,
        })

        FH.reg_slider(
            "fx_world_rate",
            function(v) FX.world_fx_rate = v end,
            function() return FX.world_fx_rate end
        )
    end

    -- Murder Effect
    local function make_death_clone(char, color)
        local ok, clone = pcall(function()
            return char:Clone()
        end)
        if not ok or not clone then
            return
        end

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
                    d.Color = color
                end
            elseif d:IsA("Humanoid")
                or d:IsA("Script")
                or d:IsA("LocalScript")
                or d:IsA("ModuleScript")
                or d:IsA("Sound")
                or d:IsA("ParticleEmitter")
                or d:IsA("Trail")
                or d:IsA("Beam")
                or d:IsA("PointLight")
                or d:IsA("SpotLight")
                or d:IsA("SurfaceLight")
                or d:IsA("Highlight")
                or d:IsA("SurfaceAppearance") then
                pcall(function()
                    d:Destroy()
                end)
            end
        end

        clone.Name = "FH_DeathClone"
        clone.Parent = Workspace

        task.delay(3, function()
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                    pcall(function()
                        TweenService:Create(
                            d,
                            TweenInfo.new(1.5),
                            { Transparency = 1 }
                        ):Play()
                    end)
                end
            end

            task.delay(1.6, function()
                pcall(function()
                    clone:Destroy()
                end)
            end)
        end)
    end

    local murder_tgl = FxDeath:toggle({
        name = "Murder Death Effect",
        default = false,
        flag = "fx_murder",
        option = true,
        callback = function(v)
            FX.murder_on = v

            if v then
                FH.track(task.spawn(function()
                    while FX.murder_on do
                        for _, plr in ipairs(Players:GetPlayers()) do
                            if plr ~= LocalPlayer and plr.Character then
                                local hum = plr.Character
                                    :FindFirstChildOfClass("Humanoid")

                                if hum and not FX.murder_conns[plr] then
                                    FX.murder_conns[plr] = hum.Died:Connect(function()
                                        if not FX.murder_on then
                                            return
                                        end

                                        local ok, mod = pcall(function()
                                            return require(ReplicatedStorage
                                                :WaitForChild("Modules")
                                                :WaitForChild("CurrentRoundClient"))
                                        end)

                                        if ok
                                            and type(mod) == "table"
                                            and type(mod.PlayerData) == "table" then

                                            local d = mod.PlayerData[plr.Name]

                                            if d
                                                and d.Role == "Murderer"
                                                and FX.murder_clone then

                                                make_death_clone(
                                                    plr.Character,
                                                    FX.murder_col
                                                )
                                            end
                                        end
                                    end)
                                end
                            end
                        end
                        task.wait(1)
                    end
                end))
            else
                for _, c in pairs(FX.murder_conns) do
                    pcall(function()
                        c:Disconnect()
                    end)
                end
                FX.murder_conns = {}
            end
        end,
    })

    FH.reg_toggle(
        "fx_murder",
        function(v) FX.murder_on = v end,
        function() return FX.murder_on end
    )

    if murder_tgl.Option then
        murder_tgl.Option:toggle({
            name = "Show clone",
            default = false,
            flag = "fx_murder_clone",
            callback = function(v) FX.murder_clone = v end,
        })

        FH.reg_toggle(
            "fx_murder_clone",
            function(v) FX.murder_clone = v end,
            function() return FX.murder_clone end
        )

        murder_tgl.Option:colorpicker({
            name = "Color",
            default = Color3.fromRGB(255, 0, 0),
            flag = "fx_murder_col",
            callback = function(c) FX.murder_col = c end,
        })

        FH.reg_color(
            "fx_murder_col",
            function(c) FX.murder_col = c end,
            function() return FX.murder_col end
        )
    end
end

-- ==============================================================
-- 17. FARM
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local U = FH.U

    local Players = FH.Players
    local ReplicatedStorage = FH.ReplicatedStorage
    local CollectionService = FH.CollectionService
    local RunService = FH.RunService
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer

    local FarmAuto = Wrap.section(Tabs.Farm, { Name = "Auto", Side = "left" })
    local FarmGuns = Wrap.section(Tabs.Farm, { Name = "Guns", Side = "right" })

    local FARM = {
        on            = false,
        mode          = "Basic",
        avoid_murder  = false,
        auto_reset    = false,
        auto_kill     = false,
        target        = nil,
        saw_coins     = false,
        coins_done    = false,
        collected_ids = {},
        collected_count = 0,
        last_touch    = 0,
        was_down      = false,
        down_ref_y    = nil,
        nc_cache      = {},

        speed         = 23,
        DOWN_DEPTH    = 14,
        DOWN_RISE_XZ  = 4,
        AVOID_DIST    = 40,
        RISE_SAFE_DIST = 20,

        murder_cache   = nil,
        murder_cache_t = 0,
    }

    FH.FARM = FARM
    getgenv().AUTOFARM_HOLD = false

    local function farm_hrp()
        return U.my_hrp()
    end

    local function farm_round_data()
        local ok, m = pcall(function()
            return require(ReplicatedStorage
                :WaitForChild("Modules")
                :WaitForChild("CurrentRoundClient"))
        end)

        if ok and type(m) == "table" then
            return m.PlayerData
        end
        return nil
    end

    local function farm_can()
        local hum = U.my_hum()
        if not hum or hum.Health <= 0 then
            return false
        end

        local d = farm_round_data()
        if type(d) == "table" then
            local me = d[LocalPlayer.Name]
            if not me or not me.Role or me.Dead then
                return false
            end
        end
        return true
    end

    local function coin_bags_full()
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        local main = pg and pg:FindFirstChild("MainGUI")
        local gg = main and main:FindFirstChild("Game")
        local bags = gg and gg:FindFirstChild("CoinBags")
        local container = bags and bags:FindFirstChild("Container")

        if not container then
            return false
        end

        local any = false

        for _, v in ipairs(container:GetChildren()) do
            if v:IsA("Frame") and v.Visible then
                any = true
                local full = v:FindFirstChild("Full")

                if not (full and full.Visible) then
                    return false
                end
            end
        end

        return any
    end

    local function farm_hold_update()
        getgenv().AUTOFARM_HOLD =
            FARM.on and FARM.auto_kill and not FARM.coins_done
    end

    local function farm_reset_progress()
        FARM.collected_ids = {}
        FARM.collected_count = 0
        FARM.coins_done = false
        FARM.saw_coins = false
        FARM.target = nil
        farm_hold_update()
    end

    pcall(function()
        local remote = ReplicatedStorage
            :WaitForChild("Remotes")
            :WaitForChild("Gameplay")
            :WaitForChild("CoinsStarted", 15)

        if remote then
            remote.OnClientEvent:Connect(farm_reset_progress)
        end
    end)

    LocalPlayer.CharacterAdded:Connect(farm_reset_progress)

    local function coin_available(v)
        return v
            and v.Parent
            and v:IsA("BasePart")
            and not v:GetAttribute("Collected")
            and not v:GetAttribute("Delete")
    end

    local function set_farm_noclip(state)
        local char = LocalPlayer.Character
        local hum = U.my_hum()

        if state then
            if not char then
                return
            end

            if hum then
                pcall(function()
                    hum.PlatformStand = true
                end)
            end

            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    if FARM.nc_cache[p] == nil then
                        FARM.nc_cache[p] = p.CanCollide
                    end
                    p.CanCollide = false
                end
            end
        else
            if hum then
                pcall(function()
                    hum.PlatformStand = false
                end)
            end

            for p, v in pairs(FARM.nc_cache) do
                if p and p.Parent then
                    pcall(function()
                        p.CanCollide = v
                    end)
                end
            end

            FARM.nc_cache = {}
        end
    end

    local up_params = RaycastParams.new()
    up_params.FilterType = Enum.RaycastFilterType.Exclude
    up_params.IgnoreWater = true

    local function return_to_surface()
        local hrp = farm_hrp()
        if not hrp then
            return
        end

        local origin = hrp.Position
        up_params.FilterDescendantsInstances = { LocalPlayer.Character }

        local res = Workspace:Raycast(
            origin,
            Vector3.new(0, 400, 0),
            up_params
        )

        local y
        if res then
            y = res.Position.Y + 5
        elseif FARM.down_ref_y then
            y = FARM.down_ref_y + 5
        end

        if not y then
            return
        end

        pcall(function()
            hrp.CFrame = CFrame.new(origin.X, y, origin.Z)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local function farm_release()
        if FARM.was_down then
            FARM.was_down = false
            return_to_surface()
        end
        set_farm_noclip(false)
    end

    local function murderer_hrp()
        local now = os.clock()
        if now - FARM.murder_cache_t < 0.25 then
            return FARM.murder_cache
        end

        FARM.murder_cache_t = now
        FARM.murder_cache = nil

        local d = farm_round_data()
        if type(d) == "table" then
            local me = d[LocalPlayer.Name]
            if me and me.Role == "Murderer" then
                return nil
            end

            for name, info in pairs(d) do
                if type(info) == "table"
                    and info.Role == "Murderer"
                    and not info.Dead
                    and name ~= LocalPlayer.Name then

                    local pl = Players:FindFirstChild(name)
                    local char = pl and pl.Character
                    local h = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")

                    if h and (not hum or hum.Health > 0) then
                        FARM.murder_cache = h
                    end
                    break
                end
            end
        end

        return FARM.murder_cache
    end

    local function flat_dist(a, b)
        return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
    end

    local function nearest_coin(pos, list)
        local best, bd = nil, math.huge

        for _, v in ipairs(list) do
            local d = (v.Position - pos).Magnitude
            if d < bd then
                bd = d
                best = v
            end
        end

        return best
    end

    local function pick_coin(pos, list, mpos)
        if not (FARM.avoid_murder and mpos) then
            return nearest_coin(pos, list)
        end

        local safe, sd = nil, math.huge
        local far, fd = nil, -1

        for _, v in ipairs(list) do
            local md = flat_dist(v.Position, mpos)
            if md > fd then
                fd = md
                far = v
            end

            if md >= FARM.AVOID_DIST then
                local d = (v.Position - pos).Magnitude
                if d < sd then
                    sd = d
                    safe = v
                end
            end
        end

        if safe then
            return safe
        end
        if far and fd >= FARM.AVOID_DIST * 0.6 then
            return far
        end
        return nil
    end

    local function coin_ok_now(v, mpos)
        if not coin_available(v) then
            return false
        end

        if FARM.avoid_murder
            and mpos
            and flat_dist(v.Position, mpos) < FARM.AVOID_DIST * 0.6 then
            return false
        end

        return true
    end

    local function avoid_steer(cur, dest, mpos)
        if not (FARM.avoid_murder and mpos) then
            return dest
        end

        local dm = flat_dist(cur, mpos)
        if dm >= FARM.AVOID_DIST then
            return dest
        end

        local away = Vector3.new(cur.X - mpos.X, 0, cur.Z - mpos.Z)
        if away.Magnitude < 0.1 then
            away = Vector3.new(1, 0, 0)
        end
        away = away.Unit

        local want = Vector3.new(dest.X - cur.X, 0, dest.Z - cur.Z)
        local mag = want.Magnitude

        if mag < 0.1 then
            return dest
        end

        local weight = 1 + (1 - dm / FARM.AVOID_DIST) * 2
        local blend = want.Unit + away * weight

        if blend.Magnitude < 0.1 then
            blend = away
        else
            blend = blend.Unit
        end

        local np = cur + blend * mag
        return Vector3.new(np.X, dest.Y, np.Z)
    end

    local function touch_targets(coin)
        local list = {}
        local seen = {}

        local function add(p)
            if p
                and not seen[p]
                and p:IsA("BasePart")
                and p:FindFirstChildOfClass("TouchTransmitter") then

                seen[p] = true
                list[#list + 1] = p
            end
        end

        add(coin)
        for _, v in ipairs(coin:GetChildren()) do
            add(v)
        end

        local par = coin.Parent
        if par then
            if par:IsA("BasePart") then
                add(par)
            end
            for _, v in ipairs(par:GetChildren()) do
                add(v)
            end
        end

        if #list == 0 then
            list[1] = coin
        end

        return list
    end

    local function fire_touch(coin)
        if type(firetouchinterest) ~= "function" then
            return
        end
        if not coin or not coin.Parent then
            return
        end

        local now = os.clock()
        if now - FARM.last_touch < 0.05 then
            return
        end
        FARM.last_touch = now

        local hrp = farm_hrp()
        if not hrp then
            return
        end

        for _, p in ipairs(touch_targets(coin)) do
            pcall(firetouchinterest, hrp, p, 0)
            pcall(firetouchinterest, hrp, p, 1)
        end
    end

    local function farm_move(hrp, dest, dt)
        local dir = dest - hrp.Position
        local dist = dir.Magnitude
        local np = dest

        if dist > 0.1 then
            np = hrp.Position + dir.Unit * math.min(FARM.speed * dt, dist)
        end

        local cf = CFrame.new(np)

        if FARM.mode == "Down" then
            cf = cf * CFrame.Angles(-math.pi * 0.5, 0, 0)
            FARM.was_down = true
        end

        pcall(function()
            hrp.CFrame = cf
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    local function farm_finish()
        FARM.target = nil
        farm_release()

        if not FARM.coins_done then
            FARM.coins_done = true
            farm_hold_update()

            if FARM.auto_reset then
                local hum = U.my_hum()
                if hum then
                    pcall(function()
                        hum.Health = 0
                    end)
                end
            end
        end
    end

    local function farm_loop()
        while FARM.on do
            RunService.Stepped:Wait()

            if not farm_can() then
                FARM.target = nil
                FARM.was_down = false
                set_farm_noclip(false)
                continue
            end

            local hrp = farm_hrp()
            if not hrp then
                continue
            end

            local list = {}

            for _, v in ipairs(CollectionService:GetTagged("CoinVisual")) do
                if v and v.Parent and v:IsA("BasePart") then
                    if v:GetAttribute("Collected") then
                        local id = v:GetAttribute("CoinID")
                        if id and not FARM.collected_ids[id] then
                            FARM.collected_ids[id] = true
                            FARM.collected_count = FARM.collected_count + 1
                        end
                    elseif not v:GetAttribute("Delete") then
                        list[#list + 1] = v
                    end
                end
            end

            if FARM.saw_coins and coin_bags_full() then
                farm_finish()
                continue
            end

            if #list > 0 then
                FARM.saw_coins = true

                if FARM.coins_done then
                    FARM.coins_done = false
                    farm_hold_update()
                end

                local mhrp = FARM.avoid_murder and murderer_hrp() or nil
                local mpos = mhrp and mhrp.Position or nil

                if not coin_ok_now(FARM.target, mpos) then
                    FARM.target = pick_coin(hrp.Position, list, mpos)
                end

                if FARM.target then
                    set_farm_noclip(true)

                    local cpos = FARM.target.Position
                    FARM.down_ref_y = cpos.Y
                    local dest = cpos

                    if FARM.mode == "Down" then
                        local xz = flat_dist(hrp.Position, cpos)
                        local safe_to_rise = (not mpos)
                            or flat_dist(hrp.Position, mpos) > FARM.RISE_SAFE_DIST

                        if xz <= FARM.DOWN_RISE_XZ and safe_to_rise then
                            dest = cpos
                            fire_touch(FARM.target)
                        else
                            dest = Vector3.new(
                                cpos.X,
                                cpos.Y - FARM.DOWN_DEPTH,
                                cpos.Z
                            )
                        end
                    elseif (cpos - hrp.Position).Magnitude <= 6 then
                        fire_touch(FARM.target)
                    end

                    dest = avoid_steer(hrp.Position, dest, mpos)
                    farm_move(hrp, dest, 0.016)

                elseif mpos then
                    set_farm_noclip(true)

                    local away = Vector3.new(
                        hrp.Position.X - mpos.X,
                        0,
                        hrp.Position.Z - mpos.Z
                    )

                    if away.Magnitude < 0.1 then
                        away = Vector3.new(1, 0, 0)
                    end
                    away = away.Unit

                    local y = hrp.Position.Y
                    if FARM.mode == "Down" and FARM.down_ref_y then
                        y = FARM.down_ref_y - FARM.DOWN_DEPTH
                    end

                    farm_move(
                        hrp,
                        hrp.Position
                            + away * 40
                            + Vector3.new(0, y - hrp.Position.Y, 0),
                        0.016
                    )
                end
            else
                FARM.target = nil
                farm_release()

                if FARM.saw_coins
                    and not FARM.coins_done
                    and FARM.collected_count > 0 then
                    farm_finish()
                end
            end
        end
    end

    local farm_tgl = FarmAuto:toggle({
        name = "Farm",
        default = false,
        flag = "farm_on",
        option = true,
        callback = function(v)
            FARM.on = v
            farm_reset_progress()

            if v then
                FH.track(task.spawn(farm_loop))
            else
                farm_release()
            end
        end,
    })

    FH.reg_toggle(
        "farm_on",
        function(v) FARM.on = v end,
        function() return FARM.on end
    )

    if farm_tgl.Option then
        farm_tgl.Option:dropdown({
            name = "Type",
            default = "Basic",
            values = { "Basic", "Down" },
            flag = "farm_mode",
            callback = function(v)
                if type(v) == "table" then
                    v = v[1]
                end
                if v ~= "Basic" and v ~= "Down" then
                    v = "Basic"
                end
                if v == FARM.mode then
                    return
                end

                FARM.mode = v
                FARM.target = nil

                if FARM.mode == "Basic" and FARM.was_down then
                    FARM.was_down = false
                    return_to_surface()
                end
            end,
        })

        FH.reg_drop(
            "farm_mode",
            function(v)
                if type(v) == "table" then v = v[1] end
                FARM.mode = v
            end,
            function() return FARM.mode end
        )

        farm_tgl.Option:toggle({
            name = "Murder check",
            default = false,
            flag = "farm_murder_check",
            callback = function(v)
                FARM.avoid_murder = v
                FARM.target = nil
            end,
        })

        FH.reg_toggle(
            "farm_murder_check",
            function(v) FARM.avoid_murder = v end,
            function() return FARM.avoid_murder end
        )

        farm_tgl.Option:toggle({
            name = "Auto reset",
            default = false,
            flag = "farm_auto_reset",
            callback = function(v) FARM.auto_reset = v end,
        })

        FH.reg_toggle(
            "farm_auto_reset",
            function(v) FARM.auto_reset = v end,
            function() return FARM.auto_reset end
        )

        farm_tgl.Option:toggle({
            name = "Auto kill",
            default = false,
            flag = "farm_auto_kill",
            callback = function(v)
                FARM.auto_kill = v
                farm_hold_update()
            end,
        })

        FH.reg_toggle(
            "farm_auto_kill",
            function(v) FARM.auto_kill = v end,
            function() return FARM.auto_kill end
        )
    end

    -- Grab Gun
    local GRAB = {
        on   = false,
        conn = nil,
    }

    FH.GRAB = GRAB

    local function grab_has_knife()
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("Knife") then
            return true
        end

        local b = LocalPlayer:FindFirstChildOfClass("Backpack")
        if b and b:FindFirstChild("Knife") then
            return true
        end

        return false
    end

    local function grab_round_ok()
        local d = farm_round_data()
        if type(d) ~= "table" then
            return false
        end

        local me = d[LocalPlayer.Name]
        return me ~= nil and me.Role ~= nil and not me.Dead
    end

    local function grab_gun(obj)
        if not GRAB.on or grab_has_knife() then
            return
        end
        if not grab_round_ok() then
            return
        end

        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end

        pcall(function()
            obj.CFrame = root.CFrame
        end)

        local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            pcall(function()
                fireproximityprompt(prompt)
            end)
        end
    end

    local function grab_scan()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "GunDrop" and obj:IsA("BasePart") then
                grab_gun(obj)
            end
        end
    end

    local function grab_start()
        if GRAB.conn then
            return
        end

        GRAB.conn = Workspace.DescendantAdded:Connect(function(obj)
            if obj.Name == "GunDrop" and obj:IsA("BasePart") then
                task.wait(0.1)
                grab_gun(obj)
            end
        end)

        FH.track(task.spawn(grab_scan))
    end

    local function grab_stop()
        if GRAB.conn then
            pcall(function()
                GRAB.conn:Disconnect()
            end)
            GRAB.conn = nil
        end
    end

    FarmGuns:toggle({
        name = "Auto Grab Gun",
        default = false,
        flag = "farm_grab",
        callback = function(v)
            GRAB.on = v
            if v then
                grab_start()
            else
                grab_stop()
            end
        end,
    })

    FH.reg_toggle(
        "farm_grab",
        function(v) GRAB.on = v end,
        function() return GRAB.on end
    )
end

-- ==============================================================
-- 18. ANIMATIONS
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local U = FH.U

    local HttpService = FH.HttpService
    local LocalPlayer = FH.LocalPlayer

    local AnimEmotes = Wrap.section(Tabs.Anim, { Name = "Emotes", Side = "left" })
    local AnimBundles = Wrap.section(Tabs.Anim, { Name = "Bundles", Side = "right" })

    -- Emotes
    local EMOTE = {
        track = nil,
        cur_id = nil,
        anim_cache = {},
    }

    FH.EMOTE = EMOTE

    local function stop_emote()
        if EMOTE.track then
            pcall(function()
                EMOTE.track:Stop()
            end)
            EMOTE.track = nil
        end
    end

    FH.stop_emote = stop_emote

    local function resolve_anim_id(id)
        if EMOTE.anim_cache[id] then
            return EMOTE.anim_cache[id]
        end

        if string.find(id, "://") then
            EMOTE.anim_cache[id] = id
            return id
        end

        local raw = string.gsub(id, "%D", "")
        local ok, objs = pcall(game.GetObjects, game, "rbxassetid://" .. raw)

        if ok and type(objs) == "table" then
            local found

            local function scan(inst)
                if found then
                    return
                end

                if inst:IsA("Animation") and inst.AnimationId ~= "" then
                    found = inst.AnimationId
                    return
                end

                for _, c in ipairs(inst:GetChildren()) do
                    scan(c)
                end
            end

            for _, o in ipairs(objs) do
                scan(o)
                pcall(function()
                    o:Destroy()
                end)
            end

            if found then
                EMOTE.anim_cache[id] = found
                return found
            end
        end

        local url = "rbxassetid://" .. raw
        EMOTE.anim_cache[id] = url
        return url
    end

    local function play_emote(id, loop)
        if not id then
            stop_emote()
            return
        end

        local hum = U.my_hum()
        if not hum then
            return
        end

        stop_emote()

        local anim = Instance.new("Animation")
        anim.AnimationId = resolve_anim_id(tostring(id))

        local ok, track = pcall(function()
            return hum:LoadAnimation(anim)
        end)

        anim:Destroy()

        if ok and track then
            track.Priority = Enum.AnimationPriority.Action
            track.Looped = loop and true or false
            track:Play()
            EMOTE.track = track
            EMOTE.cur_id = tostring(id)
        end
    end

    local EMOTE_LIST_URLS = {
        "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/EmoteSniper.json",
    }

    local EMOTE_LIST = {}
    local EMOTE_MAP = {}

    local STATIC_EMOTES = {
        { "Griddy",        "129149402922241" },
        { "Fake Dead",     "3333499562"      },
        { "MM2 Fake Dead", "184701493"       },
        { "Faint",         "184701493"       },
        { "Fallen",        "282037400"       },
        { "Floss",         "128777973"       },
        { "Dab",           "248263260"       },
    }

    local function emotes_build()
        EMOTE_LIST = {}
        EMOTE_MAP = {}

        for _, e in ipairs(STATIC_EMOTES) do
            local name, id = e[1], e[2]

            if EMOTE_MAP[name] then
                name = name .. " [" .. tostring(id) .. "]"
            end

            EMOTE_MAP[name] = tostring(id)
            EMOTE_LIST[#EMOTE_LIST + 1] = {
                name = name,
                id = tonumber((tostring(id):gsub("%D", ""))) or id,
            }
        end
    end

    local function emotes_fetch_remote()
        for _, url in ipairs(EMOTE_LIST_URLS) do
            local ok, raw = pcall(function()
                return game:HttpGet(url)
            end)

            if ok and type(raw) == "string" and #raw > 32 then
                local dok, data = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)

                if dok and type(data) == "table" then
                    local list = data.data or data
                    local seen = {}

                    for _, item in pairs(list) do
                        local id = tonumber(item.id)

                        if id and id > 0 and not seen[id] then
                            seen[id] = true
                            local nm = tostring(item.name or ("Emote_" .. id))

                            if EMOTE_MAP[nm] then
                                nm = nm .. " [" .. id .. "]"
                            end

                            EMOTE_MAP[nm] = tostring(id)
                            EMOTE_LIST[#EMOTE_LIST + 1] = {
                                name = nm,
                                id = id,
                            }
                        end
                    end
                end
            end
        end
    end

    emotes_build()

    local emote_list_el
    if type(AnimEmotes.gallery) == "function" then
        emote_list_el = AnimEmotes:gallery({
            name = "Emotes",
            values = EMOTE_LIST,
            thumb = "Asset",
            height = 300,
            cell = 74,
            search = true,
            tools = false,
            empty = "loading emotes",
            callback = function(v)
                local name = type(v) == "table" and v.name or v

                if type(name) ~= "string" or name == "" then
                    stop_emote()
                    return
                end

                local id = EMOTE_MAP[name]
                if id then
                    play_emote(id, true)
                else
                    stop_emote()
                end
            end,
        })
    end

    FH.track(task.spawn(function()
        emotes_fetch_remote()

        if emote_list_el then
            pcall(function()
                emote_list_el:setdata(EMOTE_LIST)
            end)
        end
    end))

    -- Animation Bundles
    local BUNDLE = {
        enabled = false,
        cats = {
            { "Idle", "idle" },
            { "Walk", "walk" },
            { "Run", "run" },
            { "Jump", "jump" },
            { "Fall", "fall" },
            { "Climb", "climb" },
            { "Swim", "swim" },
            { "Swim Idle", "swimidle" },
        },
        sel = {},
        by_name = {},
        map_cache = {},
        orig_map = {},
        items = {},
        fetched = false,
        lock_until = 0,
        token = 0,
        respawn_conn = nil,
    }

    FH.BUNDLE = BUNDLE

    local ANIM_URLS = {
        "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/AnimationSniper.json",
        "https://raw.githubusercontent.com/7yd7/sniper-Emote/refs/heads/test/AnimationSniperoffsale.json",
    }

    local function anim_cat_map(data)
        local key = tostring(data.id)
        if BUNDLE.map_cache[key] then
            return BUNDLE.map_cache[key]
        end

        local bundled = data.bundledItems
        if type(bundled) ~= "table" then
            return nil
        end

        local map = {}

        for _, ids in pairs(bundled) do
            if type(ids) == "table" then
                for _, asset_id in pairs(ids) do
                    local ok, objs = pcall(game.GetObjects, game,
                        "rbxassetid://" .. asset_id)

                    if ok and objs then
                        local function scan(parent, path)
                            for _, child in ipairs(parent:GetChildren()) do
                                if child:IsA("Animation") then
                                    local parts = {}
                                    local full = path .. "." .. child.Name

                                    for seg in string.gmatch(full, "[^%.]+") do
                                        parts[#parts + 1] = seg
                                    end

                                    map[#map + 1] = {
                                        category = parts[#parts - 1],
                                        name = parts[#parts],
                                        id = child.AnimationId,
                                    }
                                elseif #child:GetChildren() > 0 then
                                    scan(child, path .. "." .. child.Name)
                                end
                            end
                        end

                        for _, o in ipairs(objs) do
                            scan(o, o.Name)
                            pcall(function()
                                o:Destroy()
                            end)
                        end
                    end
                end
            end
        end

        BUNDLE.map_cache[key] = map
        return map
    end

    local function anim_cat_items(data, folder)
        local map = anim_cat_map(data)
        if not map then
            return nil
        end

        local out = {}

        for _, m in ipairs(map) do
            if m.category
                and string.lower(m.category) == folder then
                out[string.lower(m.name)] = m.id
            end
        end

        return out
    end

    local function anim_apply_cat(animate, folder, data)
        if not (animate and data) then
            return
        end

        local items = anim_cat_items(data, folder)
        if not (items and next(items)) then
            return
        end

        local f = animate:FindFirstChild(folder)
        if not f then
            return
        end

        local _, first = next(items)

        for _, a in ipairs(f:GetChildren()) do
            if a:IsA("Animation") then
                local id = items[string.lower(a.Name)] or first

                if id then
                    if BUNDLE.orig_map[a] == nil then
                        BUNDLE.orig_map[a] = a.AnimationId
                    end

                    a.AnimationId = id
                    a.Parent = nil
                    a.Parent = f
                end
            end
        end
    end

    local function anim_apply_all(animate)
        for _, c in ipairs(BUNDLE.cats) do
            local name = BUNDLE.sel[c[2]]

            if name
                and name ~= "none"
                and BUNDLE.by_name[name] then

                anim_apply_cat(animate, c[2], BUNDLE.by_name[name])
            end
        end
    end

    local function anim_restore()
        for a, id in pairs(BUNDLE.orig_map) do
            if a and a.Parent then
                pcall(function()
                    local f = a.Parent
                    a.AnimationId = id
                    a.Parent = nil
                    a.Parent = f
                end)
            end
        end

        BUNDLE.orig_map = {}
    end

    FH.anim_restore = anim_restore

    local function anim_do_apply()
        BUNDLE.token = BUNDLE.token + 1
        local token = BUNDLE.token

        local char = LocalPlayer.Character
        local hum = U.my_hum()
        local animate = char and char:FindFirstChild("Animate")

        if not animate then
            return
        end

        if hum then
            for _, t in pairs(hum:GetPlayingAnimationTracks()) do
                pcall(function()
                    t:Stop()
                end)
            end
        end

        anim_restore()

        if token ~= BUNDLE.token then
            return
        end

        anim_apply_all(animate)

        if animate and hum then
            animate.Disabled = true
            animate.Disabled = false
        end
    end

    local function anim_settle()
        local any = false

        for _, v in pairs(BUNDLE.sel) do
            if v then
                any = true
                break
            end
        end

        BUNDLE.enabled = any

        if any then
            if not BUNDLE.respawn_conn then
                BUNDLE.respawn_conn =
                    LocalPlayer.CharacterAdded:Connect(function(c)
                        c:WaitForChild("Humanoid", 5)
                        c:WaitForChild("Animate", 5)
                        task.wait(0.3)

                        BUNDLE.orig_map = {}

                        if BUNDLE.enabled then
                            anim_do_apply()
                        end
                    end)
            end

            anim_do_apply()
        else
            if BUNDLE.respawn_conn then
                pcall(function()
                    BUNDLE.respawn_conn:Disconnect()
                end)
                BUNDLE.respawn_conn = nil
            end

            anim_restore()
        end
    end

    local function bundle_fetch()
        local seen = {}

        for _, url in ipairs(ANIM_URLS) do
            local ok, raw = pcall(function()
                return game:HttpGet(url)
            end)

            if ok and type(raw) == "string" and #raw > 32 then
                local dok, data = pcall(function()
                    return HttpService:JSONDecode(raw)
                end)

                if dok and type(data) == "table" then
                    local list = data.data or data

                    for _, item in pairs(list) do
                        local id = tonumber(item.id)

                        if id
                            and id > 0
                            and item.bundledItems
                            and not seen[id] then

                            seen[id] = true
                            local nm = tostring(item.name or ("Animation_" .. id))

                            if BUNDLE.by_name[nm] then
                                nm = nm .. " [" .. id .. "]"
                            end

                            BUNDLE.by_name[nm] = {
                                id = id,
                                bundledItems = item.bundledItems,
                            }
                            BUNDLE.items[#BUNDLE.items + 1] = {
                                name = nm,
                                id = id,
                            }
                        end
                    end
                end
            end
        end

        BUNDLE.fetched = true
    end

    local function bundle_used()
        local out = {}

        for _, c in ipairs(BUNDLE.cats) do
            local nm = BUNDLE.sel[c[2]]

            if type(nm) == "string"
                and nm ~= ""
                and nm ~= "none" then
                out[nm] = true
            end
        end

        return out
    end

    local bundle_sel_el

    local function bundle_push_sel()
        if not bundle_sel_el then
            return
        end

        local names = {}

        for nm in pairs(bundle_used()) do
            names[#names + 1] = nm
        end

        pcall(function()
            bundle_sel_el:setvalue(names)
        end)
    end

    if type(AnimBundles.gallery) == "function" then
        bundle_sel_el = AnimBundles:gallery({
            name = "Bundles",
            values = BUNDLE.items,
            thumb = "BundleThumbnail",
            height = 300,
            cell = 74,
            multi = true,
            tools = false,
            empty = "loading bundles",
            search = true,
            callback = function(v)
                if os.clock() < BUNDLE.lock_until then
                    return
                end

                local names = {}

                if type(v) == "table" then
                    for _, nm in ipairs(v) do
                        if type(nm) == "string" and nm ~= "" then
                            names[#names + 1] = nm
                        end
                    end
                elseif type(v) == "string" and v ~= "" then
                    names[1] = v
                end

                local map = {}
                for i = 1, #names do
                    map[names[i]] = true
                end

                local prev = bundle_used()

                for nm in next, map do
                    if not prev[nm] then
                        for _, c in ipairs(BUNDLE.cats) do
                            BUNDLE.sel[c[2]] = nm
                        end
                    end
                end

                for nm in next, prev do
                    if not map[nm] then
                        for _, c in ipairs(BUNDLE.cats) do
                            if BUNDLE.sel[c[2]] == nm then
                                BUNDLE.sel[c[2]] = nil
                            end
                        end
                    end
                end

                bundle_push_sel()
                anim_settle()
            end,
        })
    end

    FH.track(task.spawn(function()
        bundle_fetch()

        if bundle_sel_el then
            pcall(function()
                bundle_sel_el:setdata(BUNDLE.items)
            end)
        end

        bundle_push_sel()
    end))
end

-- ==============================================================
-- 19. UTILS — FakePos / Velocity / AspectRatio / FOV / China Hat
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local U = FH.U
    local I = FH.I

    local RunService = FH.RunService
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer
    local UserInputService = FH.UserInputService

    local UtilMisc = Wrap.section(Tabs.Util, { Name = "Misc", Side = "left" })
    local UtilExtra = Wrap.section(Tabs.Util, { Name = "Extra", Side = "right" })

    -- Fake Position
    local FP = {
        on = false,
        range_x = 9e9,
        range_y = 9e9,
        range_z = 9e9,
        marker = true,
        marker_color = Color3.fromRGB(193, 247, 255),
        self_pos = nil,
        client_pos = CFrame.new(),
        parts = {},
        anti = {},
        heartbeat = nil,
        hooked_meta = {},
        grav_orig = Workspace.FallenPartsDestroyHeight,
        sender_rate = nil,
    }

    FH.FP = FP
    getgenv().FAKE_POS_ACTIVE = false

    pcall(function()
        if type(getfflag) == "function" then
            FP.sender_rate = getfflag("S2PhysicsSenderRate")
        end
    end)

    local function fp_init_char(char)
        if not char then
            return
        end

        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if not hrp then
            return
        end

        FP.parts["HumanoidRootPart"] = hrp

        local hum = char:WaitForChild("Humanoid", 5)
        FP.parts["Humanoid"] = hum

        if not FP.hooked_meta[hrp]
            and type(getrawmetatable) == "function"
            and type(newcclosure) == "function" then

            local mt = getrawmetatable(hrp)

            if mt then
                local oi = mt.__index
                local oni = mt.__newindex
                local new_mt = {}

                for k, v in pairs(mt) do
                    new_mt[k] = v
                end

                new_mt.__index = newcclosure(function(self, idx)
                    if not checkcaller()
                        and self
                        and idx == "CFrame"
                        and #FP.anti ~= 0 then
                        return FP.client_pos
                    end
                    return oi(self, idx)
                end)

                new_mt.__newindex = newcclosure(function(self, idx, val)
                    if not checkcaller() and self then
                        if idx == "Anchored" then
                            return
                        end
                        if (idx == "CFrame" or idx == "Position")
                            and #FP.anti ~= 0 then
                            return
                        end
                    end
                    return oni(self, idx, val)
                end)

                pcall(setrawmetatable, hrp, new_mt)
                FP.hooked_meta[hrp] = true
            end
        end
    end

    local function fp_do_swap(dt, hrp)
        if not hrp then
            return
        end

        pcall(function()
            if type(setfflag) == "function" then
                setfflag("S2PhysicsSenderRate", "200")
            end
        end)

        if dt > 0.45 then
            return
        end

        local x = (math.random() * 2 - 1) * FP.range_x
        local y = -(math.random()) * FP.range_y
        local z = (math.random() * 2 - 1) * FP.range_z

        local old = hrp.CFrame
        local fake = CFrame.new(x, y, z)
            * CFrame.Angles(
                math.rad(math.random(1, 359)),
                math.rad(math.random(1, 359)),
                math.rad(math.random(1, 359))
            )

        FP.self_pos = fake.Position
        hrp.CFrame = fake

        RunService.RenderStepped:Wait()
        hrp.CFrame = old
    end

    local function fp_enable(state)
        FP.on = state
        getgenv().FAKE_POS_ACTIVE = state
        FP.anti = {}

        if state then
            pcall(function()
                Workspace.FallenPartsDestroyHeight = -9e9
            end)

            FP.anti[1] = fp_do_swap

            task.spawn(function()
                FP.client_pos = FP.parts["HumanoidRootPart"]
                    and FP.parts["HumanoidRootPart"].CFrame
                    or CFrame.new()
            end)
        else
            pcall(function()
                Workspace.FallenPartsDestroyHeight = FP.grav_orig
            end)

            pcall(function()
                if type(setfflag) == "function" then
                    setfflag("S2PhysicsSenderRate",
                        FP.sender_rate or "15")
                end
            end)

            local hrp = FP.parts["HumanoidRootPart"]
            if hrp and FP.client_pos then
                pcall(function()
                    hrp.CFrame = FP.client_pos
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end)
            end

            FP.self_pos = nil
        end
    end

    FH.fp_enable = fp_enable

    local function fp_heartbeat()
        if not FP.heartbeat then
            FP.heartbeat = RunService.Heartbeat:Connect(function(dt)
                local hrp = FP.parts["HumanoidRootPart"]

                if hrp then
                    FP.client_pos = hrp.CFrame
                end

                for _, fn in ipairs(FP.anti) do
                    pcall(fn, dt, hrp)
                end
            end)
        end
    end

    fp_init_char(LocalPlayer.Character)
    LocalPlayer.CharacterAdded:Connect(function(c)
        task.wait(0.5)
        fp_init_char(c)
    end)

    local fp_tgl = UtilMisc:toggle({
        name = "Fake Position",
        default = false,
        flag = "util_fakepos",
        option = true,
        callback = function(v)
            fp_enable(v)
            if v then
                fp_heartbeat()
            end
        end,
    })

    FH.reg_toggle(
        "util_fakepos",
        function(v) FP.on = v end,
        function() return FP.on end
    )

    if fp_tgl.Option then
        fp_tgl.Option:slider({
            name = "Range X (×1e9)",
            min = 1,
            max = 9,
            default = 9,
            round = 0,
            flag = "util_fakepos_x",
            callback = function(v) FP.range_x = v * 1e9 end,
        })

        FH.reg_slider(
            "util_fakepos_x",
            function(v) FP.range_x = v * 1e9 end,
            function() return FP.range_x / 1e9 end
        )

        fp_tgl.Option:slider({
            name = "Range Y (×1e9)",
            min = 1,
            max = 9,
            default = 9,
            round = 0,
            flag = "util_fakepos_y",
            callback = function(v) FP.range_y = v * 1e9 end,
        })

        FH.reg_slider(
            "util_fakepos_y",
            function(v) FP.range_y = v * 1e9 end,
            function() return FP.range_y / 1e9 end
        )

        fp_tgl.Option:slider({
            name = "Range Z (×1e9)",
            min = 1,
            max = 9,
            default = 9,
            round = 0,
            flag = "util_fakepos_z",
            callback = function(v) FP.range_z = v * 1e9 end,
        })

        FH.reg_slider(
            "util_fakepos_z",
            function(v) FP.range_z = v * 1e9 end,
            function() return FP.range_z / 1e9 end
        )
    end

    -- Velocity Spoof
    local VEL = {
        on = false,
        mode = "low",
        rotate = false,
    }

    FH.VEL = VEL

    local function vel_do(dt, hrp)
        if not hrp then
            return
        end

        if getgenv().VELOCITY_DESYNC_UNTIL
            and os.clock() < getgenv().VELOCITY_DESYNC_UNTIL then
            return
        end

        pcall(function()
            if type(setfflag) == "function" then
                setfflag("S2PhysicsSenderRate", "200")
            end
        end)

        pcall(function()
            if type(sethiddenproperty) == "function" then
                sethiddenproperty(hrp, "NetworkIsSleeping", false)
            end
        end)

        local old_l = hrp.AssemblyLinearVelocity
        local old_a = hrp.AssemblyAngularVelocity

        local v

        if VEL.mode == "y high" then
            v = Vector3.new(0, 16384, 0)
        elseif VEL.mode == "limit" then
            v = Vector3.new(
                math.random(-2147483648, 2147483647),
                math.random(-2147483648, 2147483647),
                math.random(-2147483648, 2147483647)
            )
        elseif VEL.mode == "low" then
            v = Vector3.new(
                math.random(1, 2) == 1 and -300 or 300,
                math.random(1, 2) == 1 and -300 or 300,
                math.random(1, 2) == 1 and -300 or 300
            )
        elseif VEL.mode == "high" then
            v = Vector3.new(
                math.random(1, 2) == 1 and -16384 or 16384,
                math.random(1, 2) == 1 and -14384 or 16384,
                math.random(1, 2) == 1 and -16384 or 16384
            )
        else
            v = Vector3.zero
        end

        getgenv().VELOCITY_DESYNC_UNTIL = os.clock() + 0.35
        hrp.AssemblyLinearVelocity = v

        if VEL.rotate then
            hrp.AssemblyAngularVelocity = v
        end

        RunService.RenderStepped:Wait()

        hrp.AssemblyLinearVelocity = old_l
        hrp.AssemblyAngularVelocity = old_a

        getgenv().VELOCITY_DESYNC_UNTIL = os.clock() + 0.05
    end

    local vel_tgl = UtilMisc:toggle({
        name = "Velocity Spoof",
        default = false,
        flag = "util_vel",
        option = true,
        callback = function(v)
            VEL.on = v

            if not v then
                pcall(function()
                    if type(setfflag) == "function" then
                        setfflag("S2PhysicsSenderRate",
                            FP.sender_rate or "15")
                    end
                end)
            end
        end,
    })

    FH.reg_toggle(
        "util_vel",
        function(v) VEL.on = v end,
        function() return VEL.on end
    )

    if vel_tgl.Option then
        vel_tgl.Option:dropdown({
            name = "Mode",
            default = "low",
            values = { "low", "high", "y high", "limit", "zero" },
            flag = "util_vel_mode",
            callback = function(v)
                if type(v) == "table" then
                    v = v[1]
                end
                VEL.mode = v
            end,
        })

        FH.reg_drop(
            "util_vel_mode",
            function(v)
                if type(v) == "table" then v = v[1] end
                VEL.mode = v
            end,
            function() return VEL.mode end
        )

        vel_tgl.Option:toggle({
            name = "Rotate too",
            default = false,
            flag = "util_vel_rotate",
            callback = function(v) VEL.rotate = v end,
        })

        FH.reg_toggle(
            "util_vel_rotate",
            function(v) VEL.rotate = v end,
            function() return VEL.rotate end
        )
    end

    FH.track(task.spawn(function()
        while true do
            RunService.Heartbeat:Wait()

            if VEL.on then
                local hrp = U.my_hrp()
                pcall(vel_do, 0.016, hrp)
            end
        end
    end))

    -- Aspect Ratio
    local ASP = {
        on = false,
        value = 100,
        mult = CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
    }

    FH.ASP = ASP

    local asp_tgl = UtilExtra:toggle({
        name = "Aspect Ratio",
        default = false,
        flag = "util_aspect",
        option = true,
        callback = function(v)
            ASP.on = v

            if v then
                RunService:BindToRenderStep(
                    "FH_Aspect",
                    Enum.RenderPriority.Camera.Value + 1,
                    function()
                        if ASP.on then
                            local cam = Workspace.CurrentCamera
                            if cam then
                                cam.CFrame = cam.CFrame * ASP.mult
                            end
                        end
                    end
                )
            else
                pcall(function()
                    RunService:UnbindFromRenderStep("FH_Aspect")
                end)
            end
        end,
    })

    FH.reg_toggle(
        "util_aspect",
        function(v) ASP.on = v end,
        function() return ASP.on end
    )

    if asp_tgl.Option then
        asp_tgl.Option:slider({
            name = "Value",
            min = 1,
            max = 200,
            default = 100,
            round = 0,
            flag = "util_aspect_value",
            callback = function(v)
                ASP.value = v
                ASP.mult = CFrame.new(0, 0, 0, 1, 0, 0, 0, v / 100, 0, 0, 0, 1)
            end,
        })

        FH.reg_slider(
            "util_aspect_value",
            function(v)
                ASP.value = v
                ASP.mult = CFrame.new(0, 0, 0, 1, 0, 0, 0, v / 100, 0, 0, 0, 1)
            end,
            function() return ASP.value end
        )
    end

    -- Custom FOV
    local FOVS = {
        on = false,
        value = 70,
        orig = nil,
    }

    FH.FOVS = FOVS

    local fov_tgl = UtilExtra:toggle({
        name = "Custom FOV",
        default = false,
        flag = "util_fov",
        option = true,
        callback = function(v)
            FOVS.on = v
            local cam = Workspace.CurrentCamera

            if v then
                if cam then
                    FOVS.orig = cam.FieldOfView
                    cam.FieldOfView = FOVS.value
                end

                RunService:BindToRenderStep(
                    "FH_FOV",
                    Enum.RenderPriority.Camera.Value,
                    function()
                        if FOVS.on then
                            local c = Workspace.CurrentCamera
                            if c and c.FieldOfView ~= FOVS.value then
                                c.FieldOfView = FOVS.value
                            end
                        end
                    end
                )
            else
                if cam and FOVS.orig then
                    cam.FieldOfView = FOVS.orig
                end

                pcall(function()
                    RunService:UnbindFromRenderStep("FH_FOV")
                end)
            end
        end,
    })

    FH.reg_toggle(
        "util_fov",
        function(v) FOVS.on = v end,
        function() return FOVS.on end
    )

    if fov_tgl.Option then
        fov_tgl.Option:slider({
            name = "Value",
            min = 30,
            max = 130,
            default = 70,
            round = 0,
            flag = "util_fov_value",
            callback = function(v)
                FOVS.value = v
                if FOVS.on then
                    local cam = Workspace.CurrentCamera
                    if cam then
                        cam.FieldOfView = v
                    end
                end
            end,
        })

        FH.reg_slider(
            "util_fov_value",
            function(v) FOVS.value = v end,
            function() return FOVS.value end
        )
    end

    -- China Hat
    local CH = {
        on = false,
        color = Color3.fromRGB(170, 85, 255),
        rows = {},
        conn = nil,
    }

    FH.CH = CH

    local CH_RADIUS = 1.55
    local CH_HEIGHT = 0.82
    local CH_SEG = 48
    local CH_TAU = math.pi * 2
    local CH_ALPHA = 0.72

    local function ch_row(i)
        local r = CH.rows[i]
        if r then
            return r
        end

        r = Drawing.new("Square")
        r.Filled = true
        r.Thickness = 0
        r.Transparency = CH_ALPHA
        r.Visible = false
        r.ZIndex = 1

        CH.rows[i] = r
        return r
    end

    local function ch_clear()
        for i = 1, #CH.rows do
            pcall(function()
                CH.rows[i]:Remove()
            end)
        end
        CH.rows = {}
    end

    FH.ch_clear = ch_clear

    local function ch_update()
        if not CH.on then
            return
        end

        local cam = Workspace.CurrentCamera
        local char = LocalPlayer.Character
        local head = char and char:FindFirstChild("Head")

        if not head or not cam then
            for i = 1, #CH.rows do
                pcall(function()
                    CH.rows[i].Visible = false
                end)
            end
            return
        end

        local head_pos = head.Position
        local base_y = head_pos.Y + head.Size.Y * 0.5 - 0.02
        local center = Vector3.new(head_pos.X, base_y, head_pos.Z)

        local cos_t, sin_t = {}, {}

        for i = 1, CH_SEG do
            local a = (i - 1) / CH_SEG * CH_TAU
            cos_t[i] = math.cos(a) * CH_RADIUS
            sin_t[i] = math.sin(a) * CH_RADIUS
        end

        local apex = cam:WorldToViewportPoint(
            center + Vector3.new(0, CH_HEIGHT, 0)
        )

        if apex.Z <= 0 then
            for i = 1, #CH.rows do
                pcall(function()
                    CH.rows[i].Visible = false
                end)
            end
            return
        end

        local pts = {}

        for i = 1, CH_SEG do
            local p = cam:WorldToViewportPoint(
                center + Vector3.new(cos_t[i], 0, sin_t[i])
            )
            if p.Z > 0 then
                pts[i] = Vector2.new(p.X, p.Y)
            end
        end

        local min_x, max_x = math.huge, -math.huge
        local min_y, max_y = math.huge, -math.huge

        for _, p in pairs(pts) do
            if p.X < min_x then min_x = p.X end
            if p.X > max_x then max_x = p.X end
            if p.Y < min_y then min_y = p.Y end
            if p.Y > max_y then max_y = p.Y end
        end

        if min_x == math.huge then
            return
        end

        local ROWS = 40

        for i = 1, ROWS do
            local t = (i - 1) / ROWS
            local y = min_y + (max_y - min_y) * t
            local half = (max_x - min_x) * 0.5 * (1 - t)
            local cx = (min_x + max_x) * 0.5
            local row = ch_row(i)

            row.Position = Vector2.new(cx - half, y)
            row.Size = Vector2.new(
                half * 2,
                (max_y - min_y) / ROWS + 1
            )

            local light = 1 - t * 1.35
            if light < 0 then
                light = 0
            end

            row.Color = CH.color:Lerp(Color3.new(1, 1, 1), light * 0.26)
            row.Visible = true
        end

        for i = ROWS + 1, #CH.rows do
            pcall(function()
                CH.rows[i].Visible = false
            end)
        end
    end

    local ch_tgl = UtilExtra:toggle({
        name = "China Hat",
        default = false,
        flag = "util_china",
        option = true,
        callback = function(v)
            CH.on = v

            if v then
                if not CH.conn then
                    CH.conn = RunService.RenderStepped:Connect(ch_update)
                end
            else
                if CH.conn then
                    pcall(function()
                        CH.conn:Disconnect()
                    end)
                    CH.conn = nil
                end
                ch_clear()
            end
        end,
    })

    FH.reg_toggle(
        "util_china",
        function(v) CH.on = v end,
        function() return CH.on end
    )

    if ch_tgl.Option then
        ch_tgl.Option:colorpicker({
            name = "Color",
            default = Color3.fromRGB(170, 85, 255),
            flag = "util_china_color",
            callback = function(c) CH.color = c end,
        })

        FH.reg_color(
            "util_china_color",
            function(c) CH.color = c end,
            function() return CH.color end
        )
    end
end

-- ==============================================================
-- 20. SKINS — Model Changer + Weapon Skins + Prices
-- ==============================================================
do
    local Tabs = FH.Tabs
    local Wrap = FH.Wrap
    local I = FH.I
    local U = FH.U

    local RunService = FH.RunService
    local Workspace = FH.Workspace
    local LocalPlayer = FH.LocalPlayer

    local SkinLibrary = Wrap.section(Tabs.Skins, { Name = "Library", Side = "left" })
    local SkinApplied = Wrap.section(Tabs.Skins, { Name = "Applied", Side = "right" })

    -- Model Changer
    local MODELS = {
        on = false,
        cache = {},
        list = {
            { Name = "Tung Tung Sahur", Id = "138151705692565" },
            { Name = "Ballerina Cappuccina", Id = "138151705692565" },
        },
        pick = nil,
        inst = nil,
        conn = nil,
        hide_body = {},
        made = {},
    }

    FH.MODELS = MODELS

    local function model_scrub(inst)
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("JointInstance")
                or d:IsA("Constraint")
                or d:IsA("BodyMover")
                or d:IsA("LuaSourceContainer")
                or d:IsA("Humanoid") then
                pcall(function()
                    d:Destroy()
                end)
            end
        end
    end

    local function model_hide_body(char)
        MODELS.hide_body = {}

        if not char then
            return
        end

        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") then
                MODELS.hide_body[#MODELS.hide_body + 1] = {
                    Obj = d,
                    Val = d.Transparency,
                }
                pcall(function()
                    d.Transparency = 1
                end)
            end
        end
    end

    local function model_restore_body()
        for _, entry in ipairs(MODELS.hide_body) do
            if entry.Obj and entry.Obj.Parent then
                pcall(function()
                    entry.Obj.Transparency = entry.Val
                end)
            end
        end

        MODELS.hide_body = {}
    end

    local function model_template(def)
        if MODELS.cache[def.Name] then
            return MODELS.cache[def.Name]
        end

        if not def.Id then
            return nil
        end

        local ok, objs = pcall(game.GetObjects, game,
            "rbxassetid://" .. def.Id)

        if not ok or type(objs) ~= "table" then
            return nil
        end

        local root = objs[1]
        if not root then
            return nil
        end

        if not root:IsA("Model") then
            local holder = Instance.new("Model")
            root.Parent = holder
            root = holder
        end

        model_scrub(root)

        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("BasePart") then
                d.Anchored = true
                d.CanCollide = false
                d.CanQuery = false
                d.CanTouch = false
                d.Massless = true
                d.CastShadow = false
                d.Locked = true
            end
        end

        MODELS.cache[def.Name] = root
        return root
    end

    local function model_build(def)
        local tpl = model_template(def)
        if not tpl then
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not hrp then
            return
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        local clone = tpl:Clone()

        local _, char_size = char:GetBoundingBox()
        local _, raw_size = clone:GetBoundingBox()

        if raw_size.Y > 0.05 and char_size.Y > 0.05 then
            local scale = char_size.Y / raw_size.Y

            if math.abs(scale - 1) > 0.02 then
                pcall(function()
                    clone:ScaleTo(scale)
                end)
            end
        end

        local box, size = clone:GetBoundingBox()
        local pivot_fix = (clone:GetPivot():Inverse() * box):Inverse()
        local y_offset = size.Y * 0.5
            - hrp.Size.Y * 0.5
            - (hum and hum.HipHeight or 0)

        clone.Name = "FH_FakeModel"
        clone.Parent = Workspace
        MODELS.inst = clone
        _G.FH_FAKE_MODEL_RIG = clone

        model_hide_body(char)

        local last

        MODELS.conn = RunService.RenderStepped:Connect(function()
            if not MODELS.on or not clone.Parent then
                return
            end

            local c = LocalPlayer.Character
            local root = c and c:FindFirstChild("HumanoidRootPart")

            if not root then
                return
            end

            local cf = root.CFrame
            if last == cf then
                return
            end
            last = cf

            local look = cf.LookVector
            local pos = cf.Position

            clone:PivotTo(
                CFrame.new(pos.X, pos.Y + y_offset, pos.Z)
                    * CFrame.fromEulerAnglesYXZ(
                        0,
                        math.atan2(-look.X, -look.Z),
                        0
                    )
                    * pivot_fix
            )
        end)
    end

    local function model_clear()
        MODELS.on = false

        if MODELS.conn then
            pcall(function()
                MODELS.conn:Disconnect()
            end)
            MODELS.conn = nil
        end

        if MODELS.inst then
            pcall(function()
                MODELS.inst:Destroy()
            end)
            MODELS.inst = nil
        end

        _G.FH_FAKE_MODEL_RIG = nil
        model_restore_body()
    end

    FH.model_clear = model_clear

    local model_outer = SkinLibrary:toggle({
        name = "Model Changer",
        default = false,
        flag = "skin_model",
        option = true,
        callback = function(v)
            MODELS.on = v

            if v then
                if MODELS.pick then
                    model_build(MODELS.pick)
                end
            else
                model_clear()
            end
        end,
    })

    FH.reg_toggle(
        "skin_model",
        function(v) MODELS.on = v end,
        function() return MODELS.on end
    )

    if model_outer.Option then
        local names = {}

        for i = 1, #MODELS.list do
            names[i] = MODELS.list[i].Name
        end

        model_outer.Option:dropdown({
            name = "Model",
            default = names[1] or "",
            values = names,
            flag = "skin_model_pick",
            callback = function(v)
                if type(v) == "table" then
                    v = v[1]
                end

                for _, d in ipairs(MODELS.list) do
                    if d.Name == v then
                        MODELS.pick = d

                        if MODELS.on then
                            model_clear()
                            MODELS.on = true

                            task.spawn(function()
                                model_build(d)
                            end)
                        end
                        break
                    end
                end
            end,
        })

        FH.reg_drop(
            "skin_model_pick",
            function(v)
                if type(v) == "table" then
                    v = v[1]
                end

                for _, d in ipairs(MODELS.list) do
                    if d.Name == v then
                        MODELS.pick = d
                        break
                    end
                end
            end,
            function()
                return MODELS.pick and MODELS.pick.Name or ""
            end
        )
    end

    -- Weapon Skins
    local WS_SKIN = {
        picks = { Knife = nil, Gun = nil },
        made = {},
        origin = {},
    }

    FH.WS_SKIN = WS_SKIN

    local function ws_get_tool(name)
        local char = LocalPlayer.Character
        if char and char:FindFirstChild(name) then
            return char:FindFirstChild(name), true
        end

        local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
        if bp and bp:FindFirstChild(name) then
            return bp:FindFirstChild(name), false
        end

        return nil, false
    end

    local function ws_skin_clear(owner)
        for i = #WS_SKIN.made, 1, -1 do
            local entry = WS_SKIN.made[i]

            if entry.owner == owner then
                if entry.inst then
                    pcall(function()
                        entry.inst:Destroy()
                    end)
                end
                table.remove(WS_SKIN.made, i)
            end
        end
    end

    local function ws_apply(tool, kind, cfg)
        if not tool or not cfg or not cfg.mesh then
            return
        end

        local handle = tool:FindFirstChild("Handle")
            or tool:FindFirstChildWhichIsA("BasePart")

        if not handle then
            return
        end

        ws_skin_clear(tool)

        if not WS_SKIN.origin[tool] then
            WS_SKIN.origin[tool] = {
                size = handle.Size,
                trans = handle.Transparency,
                ltm = handle.LocalTransparencyModifier,
            }
        end

        handle.LocalTransparencyModifier = 1
        handle.Transparency = 1
        handle.Size = Vector3.new(0.3, 0.3, 0.3)

        local body = Instance.new("Part")
        body.Name = "FH_SkinBody"
        body.Size = Vector3.new(1, 1, 1)
        body.Anchored = false
        body.CanCollide = false
        body.CanQuery = false
        body.Massless = true
        body.Transparency = 0
        body.CFrame = handle.CFrame
        body.Parent = tool

        WS_SKIN.made[#WS_SKIN.made + 1] = {
            owner = tool,
            inst = body,
        }

        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.FileMesh
        mesh.MeshId = cfg.mesh
        mesh.Scale = cfg.scale or Vector3.one

        if cfg.texture then
            mesh.TextureId = cfg.texture
        end

        mesh.Parent = body

        local weld = Instance.new("Weld")
        weld.Part0 = handle
        weld.Part1 = body
        weld.C0 = CFrame.new(0, 0, 0)
        weld.Parent = body
    end

    local function ws_restore(tool)
        if not tool then
            return
        end

        ws_skin_clear(tool)

        local old = WS_SKIN.origin[tool]
        if not old then
            return
        end

        local handle = tool:FindFirstChild("Handle")
            or tool:FindFirstChildWhichIsA("BasePart")

        if handle then
            pcall(function()
                handle.LocalTransparencyModifier = old.ltm or 0
                handle.Transparency = old.trans or 0
                handle.Size = old.size
            end)
        end

        WS_SKIN.origin[tool] = nil
    end

    local SKIN_LIB = {
        { name = "Default", mesh = nil },
        {
            name = "AWP",
            mesh = "rbxassetid://6001168571",
            texture = "",
            scale = Vector3.new(1, 1, 1),
        },
        {
            name = "AK-47",
            mesh = "rbxassetid://1278764214",
            texture = "",
            scale = Vector3.new(1, 1, 1),
        },
    }

    local KNIFE_LIST, GUN_LIST = {}, {}

    for _, s in ipairs(SKIN_LIB) do
        KNIFE_LIST[#KNIFE_LIST + 1] = s.name
        GUN_LIST[#GUN_LIST + 1] = s.name
    end

    local function ws_by_name(name)
        for _, s in ipairs(SKIN_LIB) do
            if s.name == name then
                return s
            end
        end
        return nil
    end

    local function ws_do_apply(kind, name)
        local cfg = ws_by_name(name)
        if not cfg then
            return
        end

        local tool = ws_get_tool(kind)

        if tool then
            if cfg.name == "Default" then
                ws_restore(tool)
            else
                ws_apply(tool, kind, cfg)
            end
        end

        WS_SKIN.picks[kind] = name
    end

    SkinApplied:dropdown({
        name = "Knife Skin",
        default = "Default",
        values = KNIFE_LIST,
        flag = "skin_knife",
        callback = function(v)
            if type(v) == "table" then
                v = v[1]
            end
            ws_do_apply("Knife", v)
        end,
    })

    FH.reg_drop(
        "skin_knife",
        function(v)
            if type(v) == "table" then
                v = v[1]
            end
            ws_do_apply("Knife", v)
        end,
        function() return WS_SKIN.picks.Knife or "Default" end
    )

    SkinApplied:dropdown({
        name = "Gun Skin",
        default = "Default",
        values = GUN_LIST,
        flag = "skin_gun",
        callback = function(v)
            if type(v) == "table" then
                v = v[1]
            end
            ws_do_apply("Gun", v)
        end,
    })

    FH.reg_drop(
        "skin_gun",
        function(v)
            if type(v) == "table" then
                v = v[1]
            end
            ws_do_apply("Gun", v)
        end,
        function() return WS_SKIN.picks.Gun or "Default" end
    )

    SkinApplied:button({
        name = "Restore Knife",
        icon = I("refresh"),
        callback = function()
            local t = ws_get_tool("Knife")
            if t then
                ws_restore(t)
            end
            WS_SKIN.picks.Knife = nil
        end,
    })

    SkinApplied:button({
        name = "Restore Gun",
        icon = I("refresh"),
        callback = function()
            local t = ws_get_tool("Gun")
            if t then
                ws_restore(t)
            end
            WS_SKIN.picks.Gun = nil
        end,
    })

    FH.track(task.spawn(function()
        while true do
            task.wait(0.5)

            for _, kind in ipairs({ "Knife", "Gun" }) do
                local pick = WS_SKIN.picks[kind]

                if pick and pick ~= "Default" then
                    local tool = ws_get_tool(kind)

                    if tool then
                        local has = false

                        for _, entry in ipairs(WS_SKIN.made) do
                            if entry.owner == tool then
                                has = true
                                break
                            end
                        end

                        if not has then
                            pcall(function()
                                ws_do_apply(kind, pick)
                            end)
                        end
                    end
                end
            end
        end
    end))

    -- mm2_values integration
    local PRICES = {
        mod = nil,
        on = false,
        ready = false,
    }

    FH.PRICES = PRICES

    local function prices_init()
        if PRICES.mod then
            return PRICES.mod
        end

        if not fs_ok then
            return nil
        end

        local path = CFG_ROOT .. "/mm2_values.lua"
        if not isfile(path) then
            return nil
        end

        local ok, raw = pcall(readfile, path)
        if not ok or type(raw) ~= "string" then
            return nil
        end

        local fn = loadstring(raw, "@mm2_values")
        if not fn then
            return nil
        end

        local ok2, mod = pcall(fn)

        if ok2
            and type(mod) == "table"
            and type(mod.resolve_item) == "function" then
            PRICES.mod = mod
            return mod
        end

        return nil
    end

    SkinLibrary:toggle({
        name = "Show Weapon Prices",
        default = false,
        flag = "skin_prices",
        callback = function(v)
            PRICES.on = v

            if v then
                local mod = prices_init()

                if not mod then
                    warn("[FortniHub] mm2_values.lua не найден в " .. CFG_ROOT)
                    return
                end

                task.spawn(function()
                    pcall(function()
                        mod.preload_all()
                    end)
                    PRICES.ready = true
                end)
            end
        end,
    })

    FH.reg_toggle(
        "skin_prices",
        function(v) PRICES.on = v end,
        function() return PRICES.on end
    )
end

-- ==============================================================
-- 21. FINAL — CFG, unload, notify
-- ==============================================================
do
    -- Автозагрузка default.cfg если есть
    pcall(function()
        CFG.Load("default")
    end)

    -- Финализируем UI-библиотеку если есть метод
    pcall(function()
        local window = FH.window
        if window and type(window.finish) == "function" then
            window:finish()
        end
    end)

    -- Большой unload
    FH.onUnload(function()
        -- Combat
        local CB = FH.CB
        if CB then
            CB.aim_on = false
            CB.silent_on = false
        end

        if FH.restore_origin then
            FH.restore_origin()
        end

        local HOOK = FH.HOOK
        if HOOK and HOOK.installed and HOOK.ws then
            pcall(function()
                setreadonly(HOOK.ws, false)
            end)

            if HOOK.orig_mouse then
                pcall(function()
                    HOOK.ws.GetMouseTargetCFrame = HOOK.orig_mouse
                end)
            end

            if HOOK.orig_screen then
                pcall(function()
                    HOOK.ws.GetTargetPosition = HOOK.orig_screen
                end)
            end
        end

        -- Movement
        local MV = FH.MV
        if MV then
            MV.ws_on = false
            MV.jp_on = false
            MV.fly_on = false
            MV.noclip_on = false
            MV.bhop_on = false
            MV.inf_jump_on = false
            MV.wallhop_on = false

            pcall(function()
                FH.Workspace.Gravity = MV.fly_grav_orig
            end)

            pcall(function()
                FH.RunService:UnbindFromRenderStep("FH_Aspect")
            end)

            pcall(function()
                FH.RunService:UnbindFromRenderStep("FH_FOV")
            end)
        end

        -- Visual
        local VIS = FH.VIS
        if VIS then
            VIS.esp_on = false

            if VIS.conn then
                pcall(function()
                    VIS.conn:Disconnect()
                end)
                VIS.conn = nil
            end
        end

        if FH.clear_skybox then
            FH.clear_skybox()
        end

        local WORLD = FH.WORLD
        if WORLD then
            pcall(function()
                local L = FH.Lighting
                L.Brightness = WORLD.orig.brightness
                L.GlobalShadows = WORLD.orig.shadows
                L.FogEnd = WORLD.orig.fog_end
                L.FogColor = WORLD.orig.fog_color
                L.FogStart = WORLD.orig.fog_start
                L.Ambient = WORLD.orig.ambient
                L.OutdoorAmbient = WORLD.orig.outdoor
            end)
        end

        -- Effects
        if FH.chams_clear then
            FH.chams_clear()
        end

        if FH.world_fx_stop then
            FH.world_fx_stop()
        end

        -- Farm
        local FARM = FH.FARM
        if FARM then
            FARM.on = false
        end

        getgenv().AUTOFARM_HOLD = false

        local GRAB = FH.GRAB
        if GRAB then
            GRAB.on = false
            if GRAB.conn then
                pcall(function()
                    GRAB.conn:Disconnect()
                end)
                GRAB.conn = nil
            end
        end

        -- Animations
        if FH.stop_emote then
            FH.stop_emote()
        end

        local BUNDLE = FH.BUNDLE
        if BUNDLE then
            BUNDLE.enabled = false
        end

        if FH.anim_restore then
            FH.anim_restore()
        end

        -- Utils
        if FH.fp_enable then
            pcall(function()
                FH.fp_enable(false)
            end)
        end

        local FP = FH.FP
        if FP and FP.heartbeat then
            pcall(function()
                FP.heartbeat:Disconnect()
            end)
            FP.heartbeat = nil
        end

        local VEL = FH.VEL
        if VEL then
            VEL.on = false
        end

        local ASP = FH.ASP
        if ASP then
            ASP.on = false
        end

        local FOVS = FH.FOVS
        if FOVS then
            FOVS.on = false
        end

        local CH = FH.CH
        if CH then
            CH.on = false

            if CH.conn then
                pcall(function()
                    CH.conn:Disconnect()
                end)
                CH.conn = nil
            end
        end

        if FH.ch_clear then
            FH.ch_clear()
        end

        -- Skins
        if FH.model_clear then
            FH.model_clear()
        end

        -- Trolling
        local TROLL = FH.TROLL
        if TROLL then
            TROLL.tp_tool_on = false
            TROLL.fling_on = false
        end
    end)

    -- Notify
    pcall(function()
        local lib = FH.lib
        if lib and type(lib.notify) == "function" then
            lib.notify({
                title = "FortniHub MM2 " .. ADDON_VERSION,
                text = "Загружен. Insert — меню. CFG — в Настройках.",
                duration = 6,
            })
        end
    end)

    -- Публикуем глобальный объект
    getgenv().FORTNIHUB_MM2_LOADED = true
    getgenv().FORTNIHUB_MM2 = {
        unload = function()
            for _, fn in ipairs(FH.unloadFuncs) do
                pcall(fn)
            end

            for _, co in ipairs(FH.threads) do
                pcall(function()
                    task.cancel(co)
                end)
            end

            for _, conn in ipairs(FH.conns) do
                pcall(function()
                    conn:Disconnect()
                end)
            end

            pcall(function()
                FH.lib:unload()
            end)

            getgenv().FORTNIHUB_MM2_LOADED = nil
            getgenv().FORTNIHUB_MM2 = nil
        end,
        version = ADDON_VERSION,
        cfg = CFG,
        tabs = Tabs,
    }

    -- Кнопка Unload в окне (если либа поддерживает)
    pcall(function()
        local window = FH.window
        if window and type(window.button) == "function" then
            window:button({
                name = "Unload",
                icon = FH.I("trash"),
                callback = getgenv().FORTNIHUB_MM2.unload,
            })
        end
    end)
end

print("[FortniHub " .. ADDON_VERSION .. "] Part 2/2 loaded. Ready.")
