-- Nova Desync | Standalone Module
local Players        = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")

local lp   = Players.LocalPlayer
local char = lp.Character or lp.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

lp.CharacterAdded:Connect(function(c)
    char = c
    hrp  = c:WaitForChild("HumanoidRootPart")
end)

-- State
local desyncing = false

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name          = "NovaDesync"
ScreenGui.ResetOnSpawn  = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent        = gethui and gethui() or game:GetService("CoreGui")

-- Main Frame
local Frame = Instance.new("Frame")
Frame.Size            = UDim2.new(0, 180, 0, 80)
Frame.Position        = UDim2.new(0.5, -90, 0.5, -40)
Frame.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
Frame.BackgroundTransparency = 0.85
Frame.BorderSizePixel = 0
Frame.Active          = true
Frame.Draggable       = true
Frame.Parent          = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke", Frame)
mainStroke.Color     = Color3.fromRGB(100, 180, 255)
mainStroke.Thickness = 1.8
mainStroke.Transparency = 0.5

-- Title bar
local TitleBar = Instance.new("Frame", Frame)
TitleBar.Size             = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
TitleBar.BackgroundTransparency = 0.7
TitleBar.BorderSizePixel  = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleLbl = Instance.new("TextLabel", TitleBar)
TitleLbl.Size                = UDim2.new(1, -10, 1, 0)
TitleLbl.Position            = UDim2.new(0, 10, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text                = "Nova Desync"
TitleLbl.TextColor3          = Color3.fromRGB(180, 220, 255)
TitleLbl.TextSize            = 13
TitleLbl.Font                = Enum.Font.GothamBold
TitleLbl.TextXAlignment      = Enum.TextXAlignment.Left

local titleDiv = Instance.new("Frame", Frame)
titleDiv.Size             = UDim2.new(1, -16, 0, 1)
titleDiv.Position         = UDim2.new(0, 8, 0, 34)
titleDiv.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
titleDiv.BackgroundTransparency = 0.5
titleDiv.BorderSizePixel  = 0

----------------------------------------------------------------
-- Helper: make a row with dot indicator
----------------------------------------------------------------
local function makeRow(parent, labelText, yPos)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(1, -16, 0, 36)
    row.Position         = UDim2.new(0, 8, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
    row.BackgroundTransparency = 0.7
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    local rowStroke = Instance.new("UIStroke", row)
    rowStroke.Color     = Color3.fromRGB(100, 180, 255)
    rowStroke.Thickness = 1
    rowStroke.Transparency = 0.5

    -- Label
    local lbl = Instance.new("TextLabel", row)
    lbl.Size                = UDim2.new(0.6, 0, 1, 0)
    lbl.Position            = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = labelText
    lbl.TextColor3          = Color3.fromRGB(200, 220, 255)
    lbl.TextSize            = 11
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextXAlignment      = Enum.TextXAlignment.Left

    -- Dot indicator (Green/Red)
    local dot = Instance.new("Frame", row)
    dot.Size               = UDim2.new(0, 14, 0, 14)
    dot.Position           = UDim2.new(1, -30, 0.5, -7)
    dot.BackgroundColor3   = Color3.fromRGB(255, 0, 0) -- Red (off by default)
    dot.BorderSizePixel    = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    
    -- Glow effect for dot
    local glow = Instance.new("Frame", dot)
    glow.Size               = UDim2.new(1, 4, 1, 4)
    glow.Position           = UDim2.new(0, -2, 0, -2)
    glow.BackgroundColor3   = Color3.fromRGB(255, 0, 0)
    glow.BackgroundTransparency = 0.7
    glow.BorderSizePixel    = 0
    Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

    -- Invisible click button over whole row
    local btn = Instance.new("TextButton", row)
    btn.Size               = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text               = ""

    local function setState(isOn)
        local targetColor = isOn and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        TweenService:Create(dot, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(glow, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        rowStroke.Color = isOn and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(100, 180, 255)
    end

    return btn, setState
end

-- Desync row (y = 42)
local desyncBtn, setDesyncUI = makeRow(Frame, "Desync", 42)

-- Set initial state to OFF (Red)
setDesyncUI(false)

----------------------------------------------------------------
-- Toggle function
----------------------------------------------------------------
local function toggleDesync()
    desyncing = not desyncing
    setDesyncUI(desyncing)
    pcall(function()
        if desyncing then raknet.desync(true) else raknet.desync(false) end
    end)
end

desyncBtn.MouseButton1Click:Connect(toggleDesync)
