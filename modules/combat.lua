-- ============================================================
-- modules/combat.lua — боевые функции
-- ============================================================

local FH = getgenv().FH
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local U = FH.Utils

FH.Combat = FH.Combat or {}
FH.Combat.Enabled = false

-- ============================================================
-- Kill Aura
-- ============================================================
local lastHit = 0

function FH.Combat.ToggleKillAura(state)
    FH.Combat.Enabled = state
    FH.Notify("Combat", "Kill Aura: " .. (state and "ВКЛ" or "ВЫКЛ"))
end

U.Connect("CombatLoop", RunService.Heartbeat, function()
    if not FH.Combat.Enabled then return end
    if tick() - lastHit < 0.25 then return end

    local myHRP = U.GetHRP()
    if not myHRP then return end
    local char = LocalPlayer.Character
    if not char then return end
    local knife = char:FindFirstChild("Knife")
    if not knife then return end

    local RADIUS = 25
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local thrp = U.GetHRP(p)
            if thrp and (thrp.Position - myHRP.Position).Magnitude <= RADIUS then
                myHRP.CFrame = thrp.CFrame * CFrame.new(0, 0, 1.5)
                task.wait(0.08)
                pcall(function()
                    local stab = knife:FindFirstChild("Stab")
                        or knife:FindFirstChild("Slash")
                        or knife:FindFirstChild("Hit")
                    if stab then
                        if stab:IsA("RemoteEvent") then stab:FireServer()
                        elseif stab:IsA("RemoteFunction") then stab:InvokeServer() end
                    end
                end)
                lastHit = tick()
                break
            end
        end
    end
end)

print("[FH] combat загружен")
return FH.Combat
