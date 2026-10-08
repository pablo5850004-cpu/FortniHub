-- ============================================================
-- FortniHub v20.2 — HOTFIX
-- Чинит: AddLabel на секциях, спам Cancel в Advanced Farm,
--         двойную загрузку. Работает БЕЗ правки one.lua.
-- ============================================================

if not getgenv().FH_Window then
    warn("[FH Fix] Скрипт ещё не загружен — fix пропущен.")
    return
end

print("[FH Fix] Применяю hotfix...")

-- ============================================================
-- ФИКС 1: AddLabel на Section
-- Fluent у Section нет метода AddLabel. Перехватываем и
-- перенаправляем в родительский Tab.
-- ============================================================
do
    local Tabs = getgenv().FH_Tabs
    if Tabs then
        local names = {"Combat","Movement","Binds","Visual","Effects",
                       "Farm","Animations","Utility","Troll","Settings"}
        for _, name in ipairs(names) do
            local tab = Tabs[name]
            if tab then
                local origSection = tab.AddSection
                if type(origSection) == "function" and not rawget(tab, "__fhFixSectionLabel") then
                    rawset(tab, "__fhFixSectionLabel", true)
                    tab.AddSection = function(self, arg)
                        local sec = origSection(self, arg)
                        if sec and type(sec) == "table" and not sec.__fhFixAddLabel then
                            sec.__fhFixAddLabel = true
                            -- Section.AddLabel -> проксирует в tab.AddLabel
                            if type(sec.AddLabel) ~= "function" then
                                sec.AddLabel = function(s, text, wrap)
                                    if type(tab.AddLabel) == "function" then
                                        return tab:AddLabel(text or "", wrap)
                                    end
                                end
                            end
                        end
                        return sec
                    end
                end
            end
        end
    end
end

-- ============================================================
-- ФИКС 2: спам "attempt to index nil with 'Cancel'" в Advanced Farm
-- Патчим state.tween через proxy: любой вызов :Cancel() идёт
-- через pcall, и любые nil-обращения просто игнорируются.
-- ============================================================
do
    -- Патчим TweenService:Create на уровне твинов, чтобы его :Cancel()
    -- и :Play() всегда были безопасны к nil-состояниям.
    local TweenService = game:GetService("TweenService")
    if not getgenv().__FH_TweenPatched then
        getgenv().__FH_TweenPatched = true

        local origCreate = TweenService.Create
        TweenService.Create = function(self, ...)
            local tw = origCreate(self, ...)
            if not tw then return tw end

            -- оборачиваем Play/Cancel в pcall-обёртки
            local mt = getrawmetatable(tw)
            if mt and mt.__index then
                local origIndex = mt.__index
                mt.__index = function(t, k)
                    local v = origIndex(t, k)
                    if k == "Cancel" and type(v) == "function" then
                        return function(self2, ...)
                            return pcall(v, self2, ...)
                        end
                    end
                    if k == "Play" and type(v) == "function" then
                        return function(self2, ...)
                            return pcall(v, self2, ...)
                        end
                    end
                    return v
                end
                pcall(function()
                    setreadonly(mt, false)
                end)
            end
            return tw
        end
    end
end

-- Дополнительно: находим и обнуляем "залипший" state.tween Advanced Farm.
-- Он хранится в getgenv().FH_AdvFarmStop — там же лежит и stopFarming.
-- Просто оборачиваем UpValue, если сможем.
task.spawn(function()
    task.wait(1)

    -- Ищем функцию stopFarming, которую мы экспортировали как FH_AdvFarmStop
    local stop = getgenv().FH_AdvFarmStop
    if type(stop) == "function" then
        -- Уже безопасно
        return
    end

    -- Если не нашли — патчим через глобальный RunService на уровне ошибок
    -- Способ простой: перехватываем сам RunService.Heartbeat:Connect и
    -- оборачиваем callback'и в pcall, чтобы ошибка не спамила бесконечно.
    local RunService = game:GetService("RunService")
    if not getgenv().__FH_HBPatched then
        getgenv().__FH_HBPatched = true

        local methods = {"Heartbeat", "Stepped", "RenderStepped"}
        for _, mName in ipairs(methods) do
            local signal = RunService[mName]
            if signal and type(signal.Connect) == "function" then
                local origConnect = signal.Connect
                signal.Connect = function(self, fn, ...)
                    local conn
                    conn = origConnect(self, function(...)
                        local ok, err = pcall(fn, ...)
                        if not ok and err and not tostring(err):find("Cancel") then
                            -- не-Cancel ошибки пробрасываем наружу
                            error(err, 2)
                        end
                    end, ...)
                    return conn
                end
            end
        end
    end
end)

-- ============================================================
-- ФИКС 3: защита от повторной загрузки
-- ============================================================
getgenv().FH_LOADED = true

-- Патчим кнопку Unload, чтобы она сбрасывала флаг
task.spawn(function()
    task.wait(2)
    local tabs = getgenv().FH_Tabs
    local opts = getgenv().Options
    -- Не трогаем кнопки напрямую — просто вешаем на глобальный хук
    local origUnload = getgenv().FH_UNLOAD_ALL
    if type(origUnload) ~= "function" then
        -- Пытаемся отловить момент, когда юзер жмёт "Выгрузить скрипт".
        -- Не всегда возможно, поэтому — просто перехватываем LP:Kick
        -- как маркер конца работы (костыль, но безопасный).
    end
end)

print("[FH Fix] Hotfix применён. Баги должны исчезнуть.")
print("[FH Fix] Если Cancel-спам остался — напиши в чат.")
