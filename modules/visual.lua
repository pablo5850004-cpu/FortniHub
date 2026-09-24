-- ============================================================
-- modules/visual.lua — визуал (ESP)
-- ============================================================

local FH = getgenv().FH
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local U = FH.Utils

FH.Visual = FH.Visual or {}
FH.Visual.ESPEnabled = false

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "FH_ESP"
ESPFolder.Parent = CoreGui

local lastUpdate = 0

function FH.Visual.ToggleESP(state)
    FH.Visual.ESPEnabled = state
    FH.Notify("Visual", "Player ESP: " .. (state and "ВКЛ" or "ВЫКЛ"))
    if not state then
        ESPFolder:ClearAllChildren()
    end
end

U.Connect("VisualLoop", RunService.Heartbeat, function()
    if not FH.Visual.ESPEnabled then return end
    if os.clock() - lastUpdate < 0.2 then return end
    lastUpdate = os.clock()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hlName = "ESP_" .. p.Name
            local hl = ESPFolder:FindFirstChild(hlName)
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name = hlName
            end
            hl.Adornee = p.Character
            hl.FillColor = U.GetRoleColor(U.GetRole(p))
            hl.FillTransparency = 0.5
            hl.OutlineColor = Color3.new(1, 1, 1)
            hl.Parent = ESPFolder
        end
    end

    for _, hl in ipairs(ESPFolder:GetChildren()) do
        if hl:IsA("Highlight") then
            local pname = string.gsub(hl.Name, "ESP_", "")
            local found = false
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl.Name == pname and pl.Character then
                    found = true
                    break
                end
            end
            if not found then hl:Destroy() end
        end
    end
end)

print("[FH] visual загружен")
return FH.Visual
