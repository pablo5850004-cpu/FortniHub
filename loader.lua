-- ============================================================
-- loader.lua — FortniHub v20.0 BETA
-- ============================================================

local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url  = BASE .. "one.lua"

print("[FH] FortniHub loader запускается...")

local ok_http, body = pcall(function() return game:HttpGet(url) end)
if not ok_http then warn("[FH] HttpGet упал: "..tostring(body)) return end
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua пустой. size="..tostring(type(body)=="string" and #body or "nil")) return
end
print("[FH] one.lua скачан, размер: "..#body.." байт")
body = body:gsub("^=+%s*\n", "")

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

local INJECT = [[

do
    local function dummyElement()
        local d = {}
        d.SetValue = function() end
        d.GetValue = function() return "" end
        d.OnChanged = function() return d end
        d.Option = d
        return d
    end
    local function makeForward(sec, method)
        return function(_, ...)
            local args = table.pack(...)
            if type(sec) == "table" and type(sec[method]) == "function" then
                local ok, r = pcall(function()
                    return sec[method](sec, table.unpack(args, 1, args.n))
                end)
                if ok and r ~= nil then return r end
            end
            return dummyElement()
        end
    end
    local function makeOptionProxy(sec)
        local opt = {}
        for _, m in ipairs({
            "AddToggle","AddSlider","AddDropdown","AddInput","AddButton",
            "AddKeybind","AddColorPicker","AddParagraph","AddLabel",
        }) do
            opt[m] = makeForward(sec, m)
        end
        opt.AddColorpicker = opt.AddColorPicker
        opt.Option = opt
        return opt
    end
    local function installFallbacks(container)
        if type(container) ~= "table" then return end
        if rawget(container, "__fh_shim") then return end
        rawset(container, "__fh_shim", true)
        if type(container.AddLabel) ~= "function" then
            rawset(container, "AddLabel", function(self, text, _wrap)
                if type(self.AddParagraph) == "function" then
                    local ok, r = pcall(function() return self:AddParagraph(tostring(text or "")) end)
                    if ok and type(r) == "table" then
                        if rawget(r, "SetValue") == nil then rawset(r, "SetValue", function() end) end
                        if rawget(r, "GetValue") == nil then rawset(r, "GetValue", function() return "" end) end
                        if rawget(r, "Option") == nil then rawset(r, "Option", r) end
                        return r
                    end
                end
                return dummyElement()
            end)
        end
        if type(container.AddColorpicker) ~= "function" and type(container.AddColorPicker) == "function" then
            rawset(container, "AddColorpicker", container.AddColorPicker)
        end
        local creators = {
            "AddToggle","AddSlider","AddDropdown","AddInput","AddButton",
            "AddKeybind","AddColorPicker","AddParagraph",
        }
        for _, name in ipairs(creators) do
            local orig = rawget(container, name)
            if type(orig) == "function" and not rawget(container, "__fh_wrap_" .. name) then
                rawset(container, "__fh_wrap_" .. name, true)
                rawset(container, name, function(self, ...)
                    local args = table.pack(...)
                    local r = orig(self, table.unpack(args, 1, args.n))
                    if type(r) == "table" and rawget(r, "Option") == nil then
                        rawset(r, "Option", makeOptionProxy(self))
                    end
                    return r
                end)
            end
        end
        if type(container.AddSection) == "function" and not rawget(container, "__fh_sec") then
            rawset(container, "__fh_sec", true)
            local origAS = container.AddSection
            rawset(container, "AddSection", function(self, arg)
                if type(arg) == "table" then arg = arg.Name or arg.name or "section" end
                if arg == nil then arg = "section" end
                local sec = origAS(self, arg)
                if sec then
                    if rawget(sec, "Option") == nil then rawset(sec, "Option", sec) end
                    installFallbacks(sec)
                end
                return sec
            end)
        end
    end
    if type(Fluent) == "table" and type(Fluent.CreateWindow) == "function" and not rawget(Fluent, "__fh_patched") then
        rawset(Fluent, "__fh_patched", true)
        local origCreate = rawget(Fluent, "CreateWindow")
        rawset(Fluent, "CreateWindow", function(self, ...)
            local args = table.pack(...)
            local win = origCreate(self, table.unpack(args, 1, args.n))
            if not win then return win end
            if type(win.AddTab) == "function" and not rawget(win, "__fh_tab") then
                rawset(win, "__fh_tab", true)
                local origAddTab = win.AddTab
                rawset(win, "AddTab", function(w, ...)
                    local a2 = table.pack(...)
                    local tab = origAddTab(w, table.unpack(a2, 1, a2.n))
                    if tab then installFallbacks(tab) end
                    return tab
                end)
            end
            return win
        end)
    end
end

]]

local injected = false
body = body:gsub('(print%s*%(%s*"[^"]*Fluent загружен[^"]*"%s*%)%s*\n)', function(m)
    injected = true
    return m .. INJECT
end, 1)
if not injected then body = body .. "\n" .. INJECT end

print("[FH] Компилирую "..#body.." байт...")
local fn, err = loadstring(body, "@FortniHub_v20")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: "..tostring(err))
    return
end
print("[FH] Компиляция OK, запускаю...")
local ok_run, run_err = pcall(fn)
if not ok_run then
    warn("[FH] Runtime упал: "..tostring(run_err))
else
    print("[FH] FortniHub загружен успешно!")
end
