-- ============================================================
-- modules/autofarm.lua — автофарм (заглушка)
-- ============================================================

local FH = getgenv().FH
local U = FH.Utils

FH.AutoFarm = FH.AutoFarm or {}
FH.AutoFarm.Enabled = false

function FH.AutoFarm.Toggle(state)
    FH.AutoFarm.Enabled = state
    FH.Notify("AutoFarm", state and "ВКЛ" or "ВЫКЛ")
end

-- Здесь будет логика сбора монет (обсудим отдельно)

print("[FH] autofarm загружен")
return FH.AutoFarm
