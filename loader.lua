-- loader.lua — FortniHub v15.2.5 (Fluent API auto-fix)
local BASE = "https://raw.githubusercontent.com/pablo5850004-cpu/FortniHub/main/"
local url = BASE .. "one.lua?t=" .. os.time()

print("[FH] Загружаю FortniHub v15.2.5...")
local body = game:HttpGet(url, true)
if type(body) ~= "string" or #body < 100 then
    warn("[FH] one.lua не скачался")
    return
end
print("[FH] Скачано: " .. #body .. " байт")

-- Убираем служебные === в начале
body = body:gsub("^=+%s*\n", "")

-- ============================================================
-- SafeRandom
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

-- Патч math.random
body = body:gsub("math%.random%s*=%s*function", "_G.__patchedRandom = function")
body = body:gsub("string%.random%s*=%s*function", "_G.__patchedStringRandom = function")
body = body:gsub("math%.random%s*%(", "safeRandom(")

-- ============================================================
-- ИНЖЕКТ: патч Fluent API
-- Вставляем СРАЗУ ПОСЛЕ "Fluent загружен", чтобы обернуть
-- CreateWindow до того, как он будет вызван
-- ============================================================
local FLUENT_PATCH = [[

-- ⚡ Auto-injected Fluent API patch
do
    if type(Fluent) == "table" and type(Fluent.CreateWindow) == "function" then
        local _origCreate = Fluent.CreateWindow
        Fluent.CreateWindow = function(self, ...)
            local win = _origCreate(self, ...)
            if type(win) == "table" or type(win) == "userdata" then
                local _origAddTab = win.AddTab
                win.AddTab = function(w, ...)
                    local tab = _origAddTab(w, ...)
                    if tab and not rawget(tab, "__fh_patched") then
                        rawset(tab, "__fh_patched", true)
                        -- AddSection: принимает и строку и {Name=...}
                        if type(tab.AddSection) == "function" then
                            local _origAS = tab.AddSection
                            tab.AddSection = function(t, arg)
                                if type(arg) == "table" then
                                    arg = arg.Name or arg.name or "section"
                                end
                                if arg == nil then arg = "section" end
                                return _origAS(t, arg)
                            end
                        end
                        -- AddColorPicker → AddColorpicker
                        if type(tab.AddColorpicker) == "function" and type(tab.AddColorPicker) ~= "function" then
                            tab.AddColorPicker = tab.AddColorpicker
                        end
                        -- Keybind также в lowercase у старой версии
                        if type(tab.AddKeybind) == "function" then
                            -- уже есть
                        elseif type(tab.AddKeybind) ~= "function" and type(tab.AddKeyBind) == "function" then
                            tab.AddKeybind = tab.AddKeyBind
                        end
                    end
                    return tab
                end
            end
            return win
        end
        print("[FH] Fluent API patch применён")
    else
        warn("[FH] Fluent patch: пропуск (Fluent не найден)")
    end
end

]]

-- Инжект после "Fluent загружен"
local injected = false
body = body:gsub(
    '(logInfo%("Fluent загружен"%)%s*\n)',
    function(m)
        injected = true
        return m .. FLUENT_PATCH
    end,
    1
)
if not injected then
    warn("[FH] Не нашёл точку инжекта Fluent patch")
end

-- ============================================================
-- Компиляция
-- ============================================================
local fn, err = loadstring(body, "@FortniHub_v15.2.5")
if type(fn) ~= "function" then
    warn("[FH] Компиляция упала: " .. tostring(err))
    return
end

print("[FH] Компиляция OK, запускаю...")
local ok, err2 = pcall(fn)
if not ok then
    warn("[FH] Runtime упал: " .. tostring(err2))
else
    print("[FH] FortniHub v15.2.5 загружен успешно")
end
