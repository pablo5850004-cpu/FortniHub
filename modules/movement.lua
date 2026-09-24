-- ============================================================
-- modules/movement.lua — движение
-- ============================================================

local FH = getgenv().FH
local RunService = game:GetService("RunService")
local U = FH.Utils

FH.Movement = FH.Movement or {}
FH.Movement.SpeedValue = 32
FH.Movement.SpeedEnabled = false
FH.Movement.NoclipEnabled = false

-- ============================================================
-- Speed
-- ============================================================
function FH.Movement.ToggleSpeed(state)
    FH.Movement.SpeedEnabled = state
    FH.Notify("Movement", "Speed: " .. (state and "ВКЛ" or "ВЫКЛ"))
    if not state then
        local hum = U.GetHum()
        if hum then hum.WalkSpeed = 16 end
    end
end

function FH.Movement.SetSpeedValue(value)
    FH.Movement.SpeedValue = value
end

-- ============================================================
-- Noclip
-- ============================================================
function FH.Movement.ToggleNoclip(state)
    FH.Movement.NoclipEnabled = state
    FH.Notify("Movement", "Noclip: " .. (state and "ВКЛ" or "ВЫКЛ"))
end

-- ============================================================
-- Main loop
-- ============================================================
U.Connect("MovementLoop", RunService.Heartbeat, function()
    local hum = U.GetHum()

    if FH.Movement.SpeedEnabled and hum then
        hum.WalkSpeed = FH.Movement.SpeedValue
    end

    if FH.Movement.NoclipEnabled and LocalPlayer.Character then
        for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

print("[FH] movement загружен")
return FH.Movement
