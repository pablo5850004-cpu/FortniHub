-- ============================================================
-- lib/ui.lua — уведомления и UI
-- ============================================================

local FH = getgenv().FH
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

FH.Notify = FH.Notify or {}

local NotifyGui = Instance.new("ScreenGui")
NotifyGui.Name = "FH_Notify"
NotifyGui.ResetOnSpawn = false
NotifyGui.Parent = CoreGui

local NotifyHolder = Instance.new("Frame")
NotifyHolder.Name = "Holder"
NotifyHolder.Size = UDim2.new(0, 300, 1, -40)
NotifyHolder.Position = UDim2.new(1, -320, 0, 20)
NotifyHolder.BackgroundTransparency = 1
NotifyHolder.Parent = NotifyGui

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.VerticalAlignment = Enum.VerticalAlignment.Top
Layout.Parent = NotifyHolder

local lastNotify = {}

function FH.Notify(title, content, duration)
    local key = tostring(title) .. "|" .. tostring(content)
    if lastNotify[key] and (tick() - lastNotify[key]) < 0.6 then return end
    lastNotify[key] = tick()

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1, 0, 0, 56)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 18, 28)
    Frame.BackgroundTransparency = 0.1
    Frame.BorderSizePixel = 0
    Frame.Parent = NotifyHolder

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(138, 92, 246)
    Stroke.Thickness = 1.5
    Stroke.Parent = Frame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -16, 0, 22)
    Title.Position = UDim2.fromOffset(8, 6)
    Title.BackgroundTransparency = 1
    Title.Font = Enum.Font.GothamBold
    Title.Text = tostring(title)
    Title.TextColor3 = Color3.fromRGB(178, 152, 255)
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Frame

    local Content = Instance.new("TextLabel")
    Content.Size = UDim2.new(1, -16, 0, 22)
    Content.Position = UDim2.fromOffset(8, 28)
    Content.BackgroundTransparency = 1
    Content.Font = Enum.Font.Gotham
    Content.Text = tostring(content)
    Content.TextColor3 = Color3.fromRGB(220, 220, 240)
    Content.TextSize = 12
    Content.TextXAlignment = Enum.TextXAlignment.Left
    Content.TextWrapped = true
    Content.Parent = Frame

    task.delay(duration or 3, function()
        local tween = TweenService:Create(Frame, TweenInfo.new(0.4), {
            BackgroundTransparency = 1,
        })
        tween:Play()
        tween.Completed:Wait()
        Frame:Destroy()
    end)
end

print("[FH] ui загружен")
