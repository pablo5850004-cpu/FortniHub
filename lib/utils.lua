-- ============================================================
-- lib/utils.lua — общие утилиты
-- ============================================================

local FH = getgenv().FH
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

FH.Utils = FH.Utils or {}

-- ============================================================
-- Кэш персонажа
-- ============================================================
local CachedHRP, CachedHum, LastCache = nil, nil, 0

function FH.Utils.RefreshCharCache()
    if tick() - LastCache < 0.5 then return end
    LastCache = tick()
    if LocalPlayer.Character then
        CachedHRP = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        CachedHum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    else
        CachedHRP = nil
        CachedHum = nil
    end
end

function FH.Utils.GetHRP(player)
    if player and player ~= LocalPlayer then
        if player.Character then
            return player.Character:FindFirstChild("HumanoidRootPart")
        end
        return nil
    end
    FH.Utils.RefreshCharCache()
    return CachedHRP
end

function FH.Utils.GetHum()
    FH.Utils.RefreshCharCache()
    return CachedHum
end

-- ============================================================
-- Определение роли в MM2
-- ============================================================
function FH.Utils.GetRole(player)
    if not player or not player.Character then return "lobby" end
    local char = player.Character
    local bp = player:FindFirstChild("Backpack")
    if char:FindFirstChild("Knife") then return "murderer" end
    if bp and bp:FindFirstChild("Knife") then return "murderer" end
    if char:FindFirstChild("Gun") then return "sheriff" end
    if bp and bp:FindFirstChild("Gun") then return "sheriff" end
    return "innocent"
end

function FH.Utils.GetRoleColor(role)
    if role == "murderer" then return Color3.fromRGB(255, 60, 60) end
    if role == "sheriff" then return Color3.fromRGB(60, 140, 255) end
    if role == "lobby" then return Color3.fromRGB(180, 180, 180) end
    return Color3.fromRGB(60, 220, 100)
end

-- ============================================================
-- Обёртка для соединений
-- ============================================================
function FH.Utils.Connect(name, event, callback)
    if FH.Connections[name] then
        pcall(function() FH.Connections[name]:Disconnect() end)
    end
    FH.Connections[name] = event:Connect(callback)
    return FH.Connections[name]
end

print("[FH] utils загружен")
return FH.Utils
