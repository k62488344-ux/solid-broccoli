repeat task.wait() until game:IsLoaded()
pcall(function() setfpscap(999) end)

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Stats            = game:GetService("Stats")
local Lighting         = game:GetService("Lighting")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local ReplicatedFirst  = game:GetService("ReplicatedFirst")
local TextChatService  = game:GetService("TextChatService")
local CoreGui          = game:GetService("CoreGui")
local Workspace        = game:GetService("Workspace")

local lp     = Players.LocalPlayer
local player = lp

local character, hrp, hum

local progressBarBg, progressFill, percentLabel
local speedBox, stealBox, jumpBox

local autoStealEnabled    = false
local isStealing          = false
local STEAL_RADIUS        = 7.4
local STEAL_DURATION      = 0.2
local goingSpeed          = 59
local returnSpeed         = 30
local batAimbotEnabled    = false
local infiniteJumpEnabled = true
local noWalkAnimEnabled   = false
local configToggles       = {}
local saveConfig

local savedBtnX, savedBtnY
local savedHubX, savedHubY
local savedTopX, savedTopY
local savedMainX, savedMainY
local savedAutoPlayX, savedAutoPlayY
local savedAimbotX, savedAimbotY
local savedTauntX, savedTauntY
local savedDropX, savedDropY
local savedTpDownX, savedTpDownY

local FOV_VALUE        = 70
local guiScale         = 1
local mainHubFrame     = nil
local speedLbl         = nil

local antiRagdollMode    = nil
local ragdollConnections = {}
local cachedCharData     = {}

local antiFlingEnabled = false
local antiFlingConn    = nil

local MEDUSA_RADIUS      = 15
local SPAM_DELAY         = 0.15
local medusaPart         = nil
local lastUseMedusa      = 0
local AutoMedusaEnabled  = false
local MedusaInitialized  = false

local AS         = { animalCache={}, promptCache={}, stealCache={}, stealConn=nil }
local AnimalsData= {}

local espConnections = {}
local espEnabled     = false

local galaxyOn       = false
local galaxyDefaults = {}

local optimizerEnabled = false
local savedLighting    = {}
local optimized        = {}

local tpDownGui    = nil
local tpDownButton = nil

local speedDisplayBillboard = nil
local speedDisplayText = nil

local DRAG_THRESHOLD = 6
local buttonsLocked = false

local fullAutoPlayLeftEnabled = false
local fullAutoPlayRightEnabled = false
local autoPlayGui = nil

local function safe(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[NovaHub]["..label.."] "..tostring(err)) end
end

local function makeDragSafeClick(btn, action)
    local downPos = nil
    btn.MouseButton1Down:Connect(function(x, y) downPos = Vector2.new(x, y) end)
    btn.MouseButton1Up:Connect(function(x, y)
        if downPos then
            local dist = (Vector2.new(x, y) - downPos).Magnitude
            if dist <= DRAG_THRESHOLD then action() end
            downPos = nil
        end
    end)
    btn:GetPropertyChangedSignal("Draggable"):Connect(function()
        if buttonsLocked then btn.Draggable = false end
    end)
end

local function setupCharacterRefs(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart", 10)
    hum = char:WaitForChild("Humanoid", 10)
end

local function getHRP()
    local c = lp.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = lp.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

if lp.Character then task.spawn(function() setupCharacterRefs(lp.Character) end) end
lp.CharacterAdded:Connect(function(c) task.wait(0.5); setupCharacterRefs(c) end)

-- ==================== SPEED DISPLAY ====================
local function createSpeedDisplay()
    if not character or not hrp then return end
    local head = character:FindFirstChild("Head")
    if not head then return end
    local existing = head:FindFirstChild("SpeedDisplayBillboard")
    if existing then existing:Destroy() end
    speedDisplayBillboard = Instance.new("BillboardGui")
    speedDisplayBillboard.Name = "SpeedDisplayBillboard"
    speedDisplayBillboard.Size = UDim2.new(0, 150, 0, 40)
    speedDisplayBillboard.StudsOffset = Vector3.new(0, 2.5, 0)
    speedDisplayBillboard.AlwaysOnTop = true
    speedDisplayBillboard.ResetOnSpawn = false
    speedDisplayBillboard.Parent = head
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 0.5
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.Parent = speedDisplayBillboard
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    speedDisplayText = Instance.new("TextLabel")
    speedDisplayText.Size = UDim2.new(1, 0, 1, 0)
    speedDisplayText.BackgroundTransparency = 1
    speedDisplayText.Text = "Speed: 0"
    speedDisplayText.TextColor3 = Color3.fromRGB(0, 200, 255)
    speedDisplayText.Font = Enum.Font.GothamBold
    speedDisplayText.TextSize = 16
    speedDisplayText.TextStrokeTransparency = 1
    speedDisplayText.Parent = frame
end

local function updateSpeedDisplay()
    if speedDisplayText and hrp then
        pcall(function()
            local vel = hrp.AssemblyLinearVelocity
            local horizontalSpeed = math.sqrt(vel.X^2 + vel.Z^2)
            speedDisplayText.Text = string.format("Speed: %d", math.floor(horizontalSpeed))
            speedDisplayText.TextColor3 = Color3.fromRGB(0, 200, 255)
        end)
    end
end

RunService.RenderStepped:Connect(updateSpeedDisplay)

-- ==================== AUTO PLAY ====================
local fullAutoPlayLeftConn = nil
local fullAutoPlayRightConn = nil
local FAP_LeftPhase = 1
local FAP_RightPhase = 1

local FAP_L1 = Vector3.new(-476.48, -6.28, 92.73)
local FAP_L2 = Vector3.new(-482.85, -5.03, 93.13)
local FAP_L3 = Vector3.new(-475.68, -6.89, 92.76)
local FAP_L4 = Vector3.new(-476.50, -6.46, 27.58)
local FAP_L5 = Vector3.new(-482.42, -5.03, 27.84)
local FACE_FAP_L = Vector3.new(-482.25, -4.96, 92.09)

local FAP_R1 = Vector3.new(-476.16, -6.52, 25.62)
local FAP_R2 = Vector3.new(-483.06, -5.03, 27.51)
local FAP_R3 = Vector3.new(-476.21, -6.63, 27.46)
local FAP_R4 = Vector3.new(-476.66, -6.39, 92.44)
local FAP_R5 = Vector3.new(-481.94, -5.03, 92.42)
local FACE_FAP_R = Vector3.new(-482.06, -6.93, 35.47)

local function getGoingSpeed()
    return tonumber(speedBox and speedBox.Text) or goingSpeed
end

local function getReturnSpeed()
    return tonumber(stealBox and stealBox.Text) or returnSpeed
end

local function stopAutoPlayLeft()
    if fullAutoPlayLeftConn then fullAutoPlayLeftConn:Disconnect(); fullAutoPlayLeftConn = nil end
    FAP_LeftPhase = 1
    fullAutoPlayLeftEnabled = false
    local char = lp.Character
    if char then
        local humLocal = char:FindFirstChildOfClass("Humanoid")
        if humLocal then humLocal:Move(Vector3.zero, false) end
        local rp = char:FindFirstChild("HumanoidRootPart")
        if rp then rp.AssemblyLinearVelocity = Vector3.zero end
    end
end

local function stopAutoPlayRight()
    if fullAutoPlayRightConn then fullAutoPlayRightConn:Disconnect(); fullAutoPlayRightConn = nil end
    FAP_RightPhase = 1
    fullAutoPlayRightEnabled = false
    local char = lp.Character
    if char then
        local humLocal = char:FindFirstChildOfClass("Humanoid")
        if humLocal then humLocal:Move(Vector3.zero, false) end
        local rp = char:FindFirstChild("HumanoidRootPart")
        if rp then rp.AssemblyLinearVelocity = Vector3.zero end
    end
end

local function startAutoPlayLeft()
    stopAutoPlayLeft()
    FAP_LeftPhase = 1
    fullAutoPlayLeftEnabled = true
    fullAutoPlayLeftConn = RunService.Heartbeat:Connect(function()
        if not fullAutoPlayLeftEnabled then return end
        local char = lp.Character if not char then return end
        local rp = char:FindFirstChild("HumanoidRootPart")
        local humLocal = char:FindFirstChildOfClass("Humanoid")
        if not rp or not humLocal then return end
        local ph = FAP_LeftPhase
        local pts = {FAP_L1, FAP_L2, FAP_L3, FAP_L4, FAP_L5}
        local tgt = pts[ph]
        local spd = (ph >= 3) and getReturnSpeed() or getGoingSpeed()
        if (Vector3.new(tgt.X, rp.Position.Y, tgt.Z) - rp.Position).Magnitude < 1.5 then
            if ph == 5 then
                humLocal:Move(Vector3.zero, false)
                rp.AssemblyLinearVelocity = Vector3.zero
                fullAutoPlayLeftEnabled = false
                stopAutoPlayLeft()
                local dir = Vector3.new(FACE_FAP_L.X, rp.Position.Y, FACE_FAP_L.Z) - rp.Position
                if dir.Magnitude > 0.01 then rp.CFrame = CFrame.new(rp.Position, rp.Position + dir.Unit) end
                return
            elseif ph == 2 then
                humLocal:Move(Vector3.zero, false)
                rp.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.05)
                FAP_LeftPhase = 3
                return
            else
                FAP_LeftPhase = ph + 1
                return
            end
        end
        local d = tgt - rp.Position
        local mv = Vector3.new(d.X, 0, d.Z).Unit
        humLocal:Move(mv, false)
        rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
    end)
end

local function startAutoPlayRight()
    stopAutoPlayRight()
    FAP_RightPhase = 1
    fullAutoPlayRightEnabled = true
    fullAutoPlayRightConn = RunService.Heartbeat:Connect(function()
        if not fullAutoPlayRightEnabled then return end
        local char = lp.Character if not char then return end
        local rp = char:FindFirstChild("HumanoidRootPart")
        local humLocal = char:FindFirstChildOfClass("Humanoid")
        if not rp or not humLocal then return end
        local ph = FAP_RightPhase
        local pts = {FAP_R1, FAP_R2, FAP_R3, FAP_R4, FAP_R5}
        local tgt = pts[ph]
        local spd = (ph >= 3) and getReturnSpeed() or getGoingSpeed()
        if (Vector3.new(tgt.X, rp.Position.Y, tgt.Z) - rp.Position).Magnitude < 1.5 then
            if ph == 5 then
                humLocal:Move(Vector3.zero, false)
                rp.AssemblyLinearVelocity = Vector3.zero
                fullAutoPlayRightEnabled = false
                stopAutoPlayRight()
                local dir = Vector3.new(FACE_FAP_R.X, rp.Position.Y, FACE_FAP_R.Z) - rp.Position
                if dir.Magnitude > 0.01 then rp.CFrame = CFrame.new(rp.Position, rp.Position + dir.Unit) end
                return
            elseif ph == 2 then
                humLocal:Move(Vector3.zero, false)
                rp.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.05)
                FAP_RightPhase = 3
                return
            else
                FAP_RightPhase = ph + 1
                return
            end
        end
        local d = tgt - rp.Position
        local mv = Vector3.new(d.X, 0, d.Z).Unit
        humLocal:Move(mv, false)
        rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Z then
        if batAimbotEnabled then print("Cannot start Auto Play while Bat Aimbot is enabled!") return end
        if fullAutoPlayRightEnabled then stopAutoPlayRight() end
        if fullAutoPlayLeftEnabled then stopAutoPlayLeft() else startAutoPlayLeft(); print("Auto Left Started") end
        local apGui = CoreGui:FindFirstChild("AutoPlayGui")
        if apGui then
            local leftBtn = apGui:FindFirstChildOfClass("Frame"):FindFirstChild("LEFT")
            if leftBtn then
                leftBtn.BackgroundColor3 = fullAutoPlayLeftEnabled and Color3.fromRGB(0,200,80) or Color3.fromRGB(25,25,25)
                leftBtn.Text = fullAutoPlayLeftEnabled and "L ✓" or "LEFT"
            end
        end
    end
    if input.KeyCode == Enum.KeyCode.C then
        if batAimbotEnabled then print("Cannot start Auto Play while Bat Aimbot is enabled!") return end
        if fullAutoPlayLeftEnabled then stopAutoPlayLeft() end
        if fullAutoPlayRightEnabled then stopAutoPlayRight() else startAutoPlayRight(); print("Auto Right Started") end
        local apGui = CoreGui:FindFirstChild("AutoPlayGui")
        if apGui then
            local rightBtn = apGui:FindFirstChildOfClass("Frame"):FindFirstChild("RIGHT")
            if rightBtn then
                rightBtn.BackgroundColor3 = fullAutoPlayRightEnabled and Color3.fromRGB(0,200,80) or Color3.fromRGB(25,25,25)
                rightBtn.Text = fullAutoPlayRightEnabled and "R ✓" or "RIGHT"
            end
        end
    end
end)

function createAutoPlayGui()
    if autoPlayGui then return end
    autoPlayGui = Instance.new("ScreenGui")
    autoPlayGui.Name = "AutoPlayGui"
    autoPlayGui.ResetOnSpawn = false
    autoPlayGui.Parent = CoreGui
    local frame = Instance.new("Frame", autoPlayGui)
    frame.Size = UDim2.new(0,180,0,65)
    frame.Position = UDim2.new(1,-190,0,10)
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.25
    frame.Active = true; frame.Draggable = true
    Instance.new("UICorner",frame).CornerRadius = UDim.new(0,8)
    local fs = Instance.new("UIStroke",frame)
    fs.Color = Color3.fromRGB(0,120,255); fs.Thickness = 1.5
    local titleLbl = Instance.new("TextLabel",frame)
    titleLbl.Size=UDim2.new(1,0,0,20); titleLbl.Position=UDim2.new(0,0,0,2)
    titleLbl.BackgroundTransparency=1; titleLbl.Text="Auto Play"
    titleLbl.TextColor3=Color3.fromRGB(0,120,255)
    titleLbl.Font=Enum.Font.GothamBold; titleLbl.TextSize=11
    titleLbl.TextXAlignment=Enum.TextXAlignment.Center
    local buttonRow = Instance.new("Frame",frame)
    buttonRow.Size=UDim2.new(1,-10,0,30); buttonRow.Position=UDim2.new(0,5,0,28)
    buttonRow.BackgroundTransparency=1
    local leftBtn = Instance.new("TextButton",buttonRow)
    leftBtn.Size=UDim2.new(0.48,0,1,0); leftBtn.BackgroundColor3=Color3.fromRGB(25,25,25)
    leftBtn.Text="LEFT"; leftBtn.TextColor3=Color3.fromRGB(255,255,255)
    leftBtn.Font=Enum.Font.GothamBold; leftBtn.TextSize=12
    leftBtn.Name = "LEFT"
    Instance.new("UICorner",leftBtn).CornerRadius=UDim.new(0,4)
    Instance.new("UIStroke",leftBtn).Color=Color3.fromRGB(0,120,255)
    local rightBtn = Instance.new("TextButton",buttonRow)
    rightBtn.Size=UDim2.new(0.48,0,1,0); rightBtn.Position=UDim2.new(0.52,0,0,0)
    rightBtn.BackgroundColor3=Color3.fromRGB(25,25,25)
    rightBtn.Text="RIGHT"; rightBtn.TextColor3=Color3.fromRGB(255,255,255)
    rightBtn.Font=Enum.Font.GothamBold; rightBtn.TextSize=12
    rightBtn.Name = "RIGHT"
    Instance.new("UICorner",rightBtn).CornerRadius=UDim.new(0,4)
    Instance.new("UIStroke",rightBtn).Color=Color3.fromRGB(0,120,255)
    local function updateButtons()
        leftBtn.BackgroundColor3  = fullAutoPlayLeftEnabled and Color3.fromRGB(0,200,80) or Color3.fromRGB(25,25,25)
        leftBtn.Text              = fullAutoPlayLeftEnabled and "L ✓" or "LEFT"
        rightBtn.BackgroundColor3 = fullAutoPlayRightEnabled and Color3.fromRGB(0,200,80) or Color3.fromRGB(25,25,25)
        rightBtn.Text             = fullAutoPlayRightEnabled and "R ✓" or "RIGHT"
    end
    leftBtn.MouseButton1Click:Connect(function()
        if batAimbotEnabled then print("Cannot start Auto Play while Bat Aimbot is enabled!") return end
        if fullAutoPlayRightEnabled then stopAutoPlayRight() end
        if fullAutoPlayLeftEnabled then stopAutoPlayLeft() else startAutoPlayLeft() end
        updateButtons()
    end)
    rightBtn.MouseButton1Click:Connect(function()
        if batAimbotEnabled then print("Cannot start Auto Play while Bat Aimbot is enabled!") return end
        if fullAutoPlayLeftEnabled then stopAutoPlayLeft() end
        if fullAutoPlayRightEnabled then stopAutoPlayRight() else startAutoPlayRight() end
        updateButtons()
    end)
    frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        savedAutoPlayX=frame.AbsolutePosition.X; savedAutoPlayY=frame.AbsolutePosition.Y
        pcall(saveConfig)
    end)
    frame:GetPropertyChangedSignal("Draggable"):Connect(function()
        if buttonsLocked then frame.Draggable = false end
    end)
    if savedAutoPlayX and savedAutoPlayY then
        frame.Position=UDim2.new(0,savedAutoPlayX,0,savedAutoPlayY)
    end
    updateButtons()
    RunService.Heartbeat:Connect(updateButtons)
end

function destroyAutoPlayGui()
    stopAutoPlayLeft()
    stopAutoPlayRight()
    if autoPlayGui then autoPlayGui:Destroy(); autoPlayGui=nil end
end

-- ==================== RESET SETTINGS (FIXED) ====================
local function applyToggleAction(text, enabled)
    safe("Toggle:"..text, function()
        if text == "Speed Customizer" then
            local bg = CoreGui:FindFirstChild("BoosterCustomizer")
            if bg then bg.Enabled = enabled end
        elseif text == "Optimizer" then
            if enabled then enableOptimizer() else disableOptimizer() end
        elseif text == "Infinite Jump" then
            infiniteJumpEnabled = enabled
        elseif text == "ESP Players" then
            toggleESPPlayers(enabled)
        elseif text == "Galaxy Mode" then
            if enabled then enableGalaxy() else disableGalaxy() end
        elseif text == "No Walk Animation" then
            noWalkAnimEnabled = enabled
        elseif text == "Bat Aimbot" then
            if enabled then createBatAimbotGui() else destroyBatAimbotGui() end
        elseif text == "Drop Br" then
            if enabled then createDropGui() else destroyDropGui() end
        elseif text == "Auto Play" then
            if enabled then createAutoPlayGui() else destroyAutoPlayGui() end
        elseif text == "TP Down" then
            if enabled then createTpDownGui() else destroyTpDownGui() end
        elseif text == "Taunt Spam" then
            if enabled then createTauntGui() else destroyTauntGui() end
        elseif text == "Anti Ragdoll" then
            toggleAntiRagdoll(enabled)
        elseif text == "Anti Fling" then
            if enabled then enableAntiFling() else disableAntiFling() end
        elseif text == "Auto Medusa" then
            AutoMedusaEnabled = enabled; InitMedusa()
        elseif text == "FOV Changer" then
            if enabled then createFovGui() else destroyFovGui() end
        end
    end)
end

-- Default states for every toggle
local TOGGLE_DEFAULTS = {
    ["Bat Aimbot"]        = false,
    ["Auto Steal Nearest"]= false,
    ["Auto Play"]         = false,
    ["Drop Br"]           = false,
    ["TP Down"]           = false,
    ["Taunt Spam"]        = false,
    ["Auto Medusa"]       = false,
    ["Speed Customizer"]  = false,
    ["Infinite Jump"]     = true,
    ["No Walk Animation"] = true,
    ["Anti Ragdoll"]      = true,
    ["Anti Fling"]        = false,
    ["Galaxy Mode"]       = false,
    ["Optimizer"]         = true,
    ["ESP Players"]       = true,
    ["FOV Changer"]       = false,
}

-- toggleButtonRefs holds {fireToggle=fn, getState=fn} for each toggle by name
local toggleButtonRefs = {}

local function resetAllSettings()
    STEAL_RADIUS   = 7.4
    STEAL_DURATION = 0.2
    MEDUSA_RADIUS  = 15
    goingSpeed     = 59
    returnSpeed    = 30
    FOV_VALUE      = 70
    buttonsLocked  = false

    if speedBox then speedBox.Text = "59" end
    if stealBox then stealBox.Text = "30" end
    if jumpBox  then jumpBox.Text  = "60" end

    pcall(function() workspace.CurrentCamera.FieldOfView = 70 end)

    if fullAutoPlayLeftEnabled  then stopAutoPlayLeft()  end
    if fullAutoPlayRightEnabled then stopAutoPlayRight() end
    if batAimbotEnabled         then stopBatAimbot()     end
    if galaxyOn                 then disableGalaxy()     end

    -- FIXED: set each toggle to its default via the button ref
    for name, defaultOn in pairs(TOGGLE_DEFAULTS) do
        local ref = toggleButtonRefs[name]
        if ref then
            local currentState = ref.getState()
            if currentState ~= defaultOn then
                ref.fireToggle()
            end
        else
            -- fallback: apply action directly
            applyToggleAction(name, defaultOn)
        end
        configToggles[name] = defaultOn
    end

    pcall(saveConfig)
    print("All settings have been reset to default values!")

    local confirmGui = Instance.new("ScreenGui")
    confirmGui.Name = "ResetConfirmGui"
    confirmGui.ResetOnSpawn = false
    confirmGui.Parent = CoreGui
    local confirmFrame = Instance.new("Frame")
    confirmFrame.Size = UDim2.new(0, 300, 0, 60)
    confirmFrame.Position = UDim2.new(0.5, -150, 0.5, -30)
    confirmFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    confirmFrame.BackgroundTransparency = 0.1
    confirmFrame.Parent = confirmGui
    Instance.new("UICorner", confirmFrame).CornerRadius = UDim.new(0, 12)
    Instance.new("UIStroke", confirmFrame).Color = Color3.fromRGB(0, 255, 0)
    local confirmText = Instance.new("TextLabel")
    confirmText.Size = UDim2.new(1, 0, 1, 0)
    confirmText.BackgroundTransparency = 1
    confirmText.Text = "✓ All settings reset to default!"
    confirmText.TextColor3 = Color3.fromRGB(0, 255, 0)
    confirmText.Font = Enum.Font.GothamBold
    confirmText.TextSize = 16
    confirmText.Parent = confirmFrame
    task.delay(2, function() confirmGui:Destroy() end)
end

-- ==================== BAT AIMBOT ====================
local batAimbotGui  = nil
local batButton     = nil
local aimbotConn    = nil
local lockedTarget  = nil
local BAT_ENGAGE_RANGE = 6
local AIMBOT_SPEED     = 60
local MELEE_OFFSET     = 3.5

do
    local aimbotHighlight = Instance.new("Highlight")
    aimbotHighlight.Name             = "NovaAimbotESP"
    aimbotHighlight.FillColor        = Color3.fromRGB(180, 0, 255)
    aimbotHighlight.OutlineColor     = Color3.fromRGB(255, 255, 255)
    aimbotHighlight.FillTransparency = 0.5
    aimbotHighlight.OutlineTransparency = 0
    pcall(function() aimbotHighlight.Parent = lp:WaitForChild("PlayerGui") end)

    local function isTargetValid(targetChar)
        if not targetChar or not targetChar.Parent then return false end
        local hum2 = targetChar:FindFirstChildOfClass("Humanoid")
        local hrp2 = targetChar:FindFirstChild("HumanoidRootPart")
        local ff   = targetChar:FindFirstChildOfClass("ForceField")
        return hum2 and hrp2 and hum2.Health > 0 and not ff
    end

    local function getBestTarget(myHRP)
        if not myHRP then return nil, nil end
        if lockedTarget and isTargetValid(lockedTarget) then
            return lockedTarget:FindFirstChild("HumanoidRootPart"), lockedTarget
        end
        local shortestDist, newTargetChar, newTargetHRP = math.huge, nil, nil
        for _, targetPlayer in ipairs(Players:GetPlayers()) do
            if targetPlayer ~= player then
                local targetChar = targetPlayer.Character
                if targetChar and isTargetValid(targetChar) then
                    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
                    if targetHRP then
                        local distance = (targetHRP.Position - myHRP.Position).Magnitude
                        if distance < shortestDist then
                            shortestDist = distance
                            newTargetHRP = targetHRP
                            newTargetChar = targetChar
                        end
                    end
                end
            end
        end
        lockedTarget = newTargetChar
        return newTargetHRP, newTargetChar
    end

    local function findBatTool()
        local c = lp.Character
        if not c then return nil end
        local bp = lp:FindFirstChildOfClass("Backpack")
        for _, ch in ipairs(c:GetChildren()) do
            if ch:IsA("Tool") then
                local nameLower = ch.Name:lower()
                if nameLower:find("bat") or nameLower:find("slap") then return ch end
            end
        end
        if bp then
            for _, ch in ipairs(bp:GetChildren()) do
                if ch:IsA("Tool") then
                    local nameLower = ch.Name:lower()
                    if nameLower:find("bat") or nameLower:find("slap") then return ch end
                end
            end
        end
        return nil
    end

    function startBatAimbot()
        if aimbotConn then return end
        if fullAutoPlayLeftEnabled then stopAutoPlayLeft(); print("Auto Play Left disabled by Bat Aimbot") end
        if fullAutoPlayRightEnabled then stopAutoPlayRight(); print("Auto Play Right disabled by Bat Aimbot") end
        local apGui = CoreGui:FindFirstChild("AutoPlayGui")
        if apGui then
            local f = apGui:FindFirstChildOfClass("Frame")
            local lb = f and f:FindFirstChild("LEFT")
            local rb = f and f:FindFirstChild("RIGHT")
            if lb then lb.BackgroundColor3 = Color3.fromRGB(25,25,25); lb.Text = "LEFT" end
            if rb then rb.BackgroundColor3 = Color3.fromRGB(25,25,25); rb.Text = "RIGHT" end
        end
        local c = lp.Character
        if not c then task.wait(0.5); c = lp.Character; if not c then return end end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hmLocal = c:FindFirstChildOfClass("Humanoid")
        if not h or not hmLocal then return end
        pcall(function() hmLocal.AutoRotate = false end)
        local attachment = h:FindFirstChild("AimbotAttachment") or Instance.new("Attachment")
        attachment.Name = "AimbotAttachment"
        attachment.Parent = h
        local align = h:FindFirstChild("AimbotAlign") or Instance.new("AlignOrientation")
        align.Name = "AimbotAlign"
        align.Mode = Enum.OrientationAlignmentMode.OneAttachment
        align.Attachment0 = attachment
        align.MaxTorque = math.huge
        align.Responsiveness = 200
        align.Parent = h
        batAimbotEnabled = true
        aimbotConn = RunService.Heartbeat:Connect(function()
            if not batAimbotEnabled then return end
            local c2 = lp.Character
            if not c2 then return end
            local h2 = c2:FindFirstChild("HumanoidRootPart")
            local hm2 = c2:FindFirstChildOfClass("Humanoid")
            if not h2 or not hm2 then return end
            local bat = findBatTool()
            if bat and bat.Parent ~= c2 then pcall(function() hm2:EquipTool(bat) end) end
            local targetHRP, targetChar = getBestTarget(h2)
            if targetHRP and targetChar then
                aimbotHighlight.Adornee = targetChar
                local targetVel = targetHRP.AssemblyLinearVelocity
                local speed = math.min(targetVel.Magnitude, 50)
                local predictTime = math.clamp(speed / 180, 0.05, 0.25)
                local predictedPos = targetHRP.Position + (targetVel * predictTime)
                local lookDir = (predictedPos - h2.Position).Unit
                local targetCFrame = CFrame.lookAt(h2.Position, h2.Position + lookDir)
                align.CFrame = targetCFrame
                local standPos = predictedPos - (lookDir * MELEE_OFFSET)
                local moveDir = (standPos - h2.Position)
                local distToStand = moveDir.Magnitude
                if distToStand > 1.5 then
                    h2.AssemblyLinearVelocity = moveDir.Unit * AIMBOT_SPEED
                else
                    h2.AssemblyLinearVelocity = h2.AssemblyLinearVelocity * 0.95
                end
                if distToStand <= BAT_ENGAGE_RANGE then
                    bat = findBatTool()
                    if bat and bat.Parent == c2 then
                        pcall(function() bat:Activate(); task.wait(0.05); bat:Activate() end)
                    end
                end
            else
                lockedTarget = nil
                aimbotHighlight.Adornee = nil
                if h2 then h2.AssemblyLinearVelocity = Vector3.new(0, h2.AssemblyLinearVelocity.Y, 0) end
            end
        end)
    end

    function stopBatAimbot()
        batAimbotEnabled = false
        if aimbotConn then aimbotConn:Disconnect(); aimbotConn = nil end
        local c = lp.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local hmLocal = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            local att = h:FindFirstChild("AimbotAttachment"); if att then att:Destroy() end
            local al = h:FindFirstChild("AimbotAlign"); if al then al:Destroy() end
            h.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
        if hmLocal then pcall(function() hmLocal.AutoRotate = true end) end
        lockedTarget = nil
        aimbotHighlight.Adornee = nil
    end

    local function toggleBatAimbot()
        if batAimbotEnabled then stopBatAimbot() else startBatAimbot() end
        if batButton then
            batButton.Text = batAimbotEnabled and "🏏 AIMING" or "🏏 AIMBOT"
            batButton.BackgroundColor3 = batAimbotEnabled and Color3.fromRGB(200,80,80) or Color3.fromRGB(0,120,255)
        end
    end

    function createBatAimbotGui()
        if batAimbotGui then return end
        batAimbotGui = Instance.new("ScreenGui")
        batAimbotGui.Name = "BatAimbotGui"
        batAimbotGui.ResetOnSpawn = false
        batAimbotGui.Parent = CoreGui
        batButton = Instance.new("TextButton")
        batButton.Size = UDim2.new(0, 120, 0, 50)
        batButton.Position = UDim2.new(1, -135, 0, 155)
        batButton.Text = "🏏 AIMBOT"
        batButton.Font = Enum.Font.GothamBold
        batButton.TextSize = 16
        batButton.TextColor3 = Color3.new(1, 1, 1)
        batButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        batButton.Active = true
        batButton.Draggable = true
        batButton.Parent = batAimbotGui
        Instance.new("UICorner", batButton).CornerRadius = UDim.new(0, 16)
        batButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            savedAimbotX = batButton.AbsolutePosition.X
            savedAimbotY = batButton.AbsolutePosition.Y
            pcall(saveConfig)
        end)
        batButton:GetPropertyChangedSignal("Draggable"):Connect(function()
            if buttonsLocked then batButton.Draggable = false end
        end)
        makeDragSafeClick(batButton, toggleBatAimbot)
        if savedAimbotX and savedAimbotY then
            batButton.Position = UDim2.new(0, savedAimbotX, 0, savedAimbotY)
        end
    end

    function destroyBatAimbotGui()
        stopBatAimbot()
        if batAimbotGui then batAimbotGui:Destroy(); batAimbotGui = nil; batButton = nil end
    end

    lp.CharacterAdded:Connect(function(char)
        task.wait(1.0)
        if batAimbotEnabled then
            if aimbotConn then aimbotConn:Disconnect(); aimbotConn = nil end
            startBatAimbot()
        end
    end)
end

-- ==================== FOV CHANGER ====================
local fovGui   = nil
local fovFrame = nil

do
    local function setFOV(value)
        FOV_VALUE = math.clamp(value, 30, 120)
        workspace.CurrentCamera.FieldOfView = FOV_VALUE
        pcall(saveConfig)
    end

    function createFovGui()
        if fovGui then return end
        fovGui = Instance.new("ScreenGui")
        fovGui.Name = "FovGui"
        fovGui.ResetOnSpawn = false
        fovGui.Parent = CoreGui
        fovFrame = Instance.new("Frame", fovGui)
        fovFrame.Size = UDim2.new(0,200,0,60)
        fovFrame.Position = UDim2.new(0,10,0.5,-30)
        fovFrame.BackgroundColor3 = Color3.fromRGB(20,20,40)
        fovFrame.BackgroundTransparency = 0.1
        fovFrame.Active = true
        fovFrame.Draggable = true
        Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(0,8)
        Instance.new("UIStroke", fovFrame).Color = Color3.fromRGB(0,120,255)
        fovFrame:GetPropertyChangedSignal("Draggable"):Connect(function()
            if buttonsLocked then fovFrame.Draggable = false end
        end)
        local title = Instance.new("TextLabel", fovFrame)
        title.Size = UDim2.new(1,0,0,25)
        title.Position = UDim2.new(0,10,0,5)
        title.BackgroundTransparency = 1
        title.Text = "🔭 Field of View"
        title.TextColor3 = Color3.fromRGB(0,120,255)
        title.TextSize = 12
        title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        local minus = Instance.new("TextButton", fovFrame)
        minus.Size = UDim2.new(0,35,0,30)
        minus.Position = UDim2.new(0,10,0,35)
        minus.BackgroundColor3 = Color3.fromRGB(40,40,60)
        minus.Text = "-"
        minus.TextColor3 = Color3.fromRGB(255,255,255)
        minus.TextSize = 18
        Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)
        local valueBox = Instance.new("TextBox", fovFrame)
        valueBox.Size = UDim2.new(0,80,0,30)
        valueBox.Position = UDim2.new(0,55,0,35)
        valueBox.BackgroundColor3 = Color3.fromRGB(30,30,50)
        valueBox.Text = tostring(FOV_VALUE)
        valueBox.TextColor3 = Color3.fromRGB(255,255,255)
        valueBox.TextSize = 14
        valueBox.Font = Enum.Font.GothamBold
        Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0,6)
        local plus = Instance.new("TextButton", fovFrame)
        plus.Size = UDim2.new(0,35,0,30)
        plus.Position = UDim2.new(1,-45,0,35)
        plus.BackgroundColor3 = Color3.fromRGB(40,40,60)
        plus.Text = "+"
        plus.TextColor3 = Color3.fromRGB(255,255,255)
        plus.TextSize = 18
        Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)
        fovFrame:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            savedTopX = fovFrame.AbsolutePosition.X
            savedTopY = fovFrame.AbsolutePosition.Y
            pcall(saveConfig)
        end)
        minus.MouseButton1Click:Connect(function()
            setFOV(FOV_VALUE - 5); valueBox.Text = tostring(FOV_VALUE)
        end)
        plus.MouseButton1Click:Connect(function()
            setFOV(FOV_VALUE + 5); valueBox.Text = tostring(FOV_VALUE)
        end)
        valueBox.FocusLost:Connect(function()
            local v = tonumber(valueBox.Text)
            if v then setFOV(v) end
            valueBox.Text = tostring(FOV_VALUE)
        end)
        if savedTopX and savedTopY then
            fovFrame.Position = UDim2.new(0, savedTopX, 0, savedTopY)
        end
    end

    function destroyFovGui()
        if fovGui then fovGui:Destroy(); fovGui = nil; fovFrame = nil end
    end
end

-- ==================== TP DOWN ====================
local function tpDownAction()
    local char = lp.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    root.CFrame = root.CFrame * CFrame.new(0, -20, 0)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

function createTpDownGui()
    if tpDownGui then return end
    pcall(function()
        if CoreGui:FindFirstChild("TpDownGui") then CoreGui.TpDownGui:Destroy() end
    end)
    tpDownGui = Instance.new("ScreenGui")
    tpDownGui.Name = "TpDownGui"
    tpDownGui.ResetOnSpawn = false
    tpDownGui.Parent = CoreGui
    tpDownButton = Instance.new("TextButton")
    tpDownButton.Size = UDim2.new(0,130,0,50)
    tpDownButton.Position = UDim2.new(0,10,0,130)
    tpDownButton.Text = "⬇ TP DOWN"
    tpDownButton.Font = Enum.Font.GothamBold
    tpDownButton.TextSize = 16
    tpDownButton.TextColor3 = Color3.new(1,1,1)
    tpDownButton.BackgroundColor3 = Color3.fromRGB(0,120,255)
    tpDownButton.Active = true
    tpDownButton.Draggable = true
    tpDownButton.Parent = tpDownGui
    Instance.new("UICorner", tpDownButton).CornerRadius = UDim.new(0,16)
    tpDownButton:GetPropertyChangedSignal("Draggable"):Connect(function()
        if buttonsLocked then tpDownButton.Draggable = false end
    end)
    tpDownButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        savedTpDownX = tpDownButton.AbsolutePosition.X
        savedTpDownY = tpDownButton.AbsolutePosition.Y
        pcall(saveConfig)
    end)
    local function animateClick()
        TweenService:Create(tpDownButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(200,80,80)}):Play()
        task.delay(0.1, function()
            if tpDownButton and tpDownButton.Parent then
                TweenService:Create(tpDownButton, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(0,120,255)}):Play()
            end
        end)
    end
    makeDragSafeClick(tpDownButton, function() tpDownAction(); animateClick() end)
    if savedTpDownX and savedTpDownY then
        tpDownButton.Position = UDim2.new(0, savedTpDownX, 0, savedTpDownY)
    end
end

function destroyTpDownGui()
    if tpDownGui then tpDownGui:Destroy(); tpDownGui = nil; tpDownButton = nil end
end

_G._novaTpDown = tpDownAction

-- ==================== TAUNT ====================
local tauntActive = false
local tauntLoop   = nil
local tauntGui    = nil
local tauntButton = nil

do
    local tauntMessage = "Nova on top lol"

    local function sendTaunt()
        pcall(function()
            local ch = TextChatService and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if ch then ch:SendAsync(tauntMessage); return end
            local ce = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
            if ce then
                local sm = ce:FindFirstChild("SayMessageRequest")
                if sm then sm:FireServer(tauntMessage, "All"); return end
            end
            local cf = ReplicatedFirst:FindFirstChild("DefaultChatSystemChatEvents")
            if cf then
                local sm = cf:FindFirstChild("SayMessageRequest")
                if sm then sm:FireServer(tauntMessage, "All"); return end
            end
        end)
    end

    local function startTaunt()
        if tauntLoop then return end
        tauntActive = true
        tauntLoop = task.spawn(function()
            while tauntActive do sendTaunt(); task.wait(0.4) end
        end)
    end

    local function stopTaunt()
        tauntActive = false
        if tauntLoop then task.cancel(tauntLoop); tauntLoop = nil end
    end

    function toggleTaunt()
        if tauntActive then stopTaunt() else startTaunt() end
        if tauntButton then
            tauntButton.Text = tauntActive and "🔊 TAUNTING" or "💬 TAUNT"
            tauntButton.BackgroundColor3 = tauntActive and Color3.fromRGB(200,80,80) or Color3.fromRGB(0,120,255)
        end
    end

    function createTauntGui()
        if tauntGui then return end
        pcall(function()
            if CoreGui:FindFirstChild("TauntGui") then CoreGui.TauntGui:Destroy() end
        end)
        tauntGui = Instance.new("ScreenGui")
        tauntGui.Name = "TauntGui"
        tauntGui.ResetOnSpawn = false
        tauntGui.Parent = CoreGui
        tauntButton = Instance.new("TextButton")
        tauntButton.Size = UDim2.new(0,120,0,50)
        tauntButton.Position = UDim2.new(0,150,0,130)
        tauntButton.Text = "💬 TAUNT"
        tauntButton.Font = Enum.Font.GothamBold
        tauntButton.TextSize = 16
        tauntButton.TextColor3 = Color3.new(1,1,1)
        tauntButton.BackgroundColor3 = Color3.fromRGB(0,120,255)
        tauntButton.Active = true
        tauntButton.Draggable = true
        tauntButton.Parent = tauntGui
        Instance.new("UICorner", tauntButton).CornerRadius = UDim.new(0,16)
        tauntButton:GetPropertyChangedSignal("Draggable"):Connect(function()
            if buttonsLocked then tauntButton.Draggable = false end
        end)
        tauntButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            savedTauntX = tauntButton.AbsolutePosition.X
            savedTauntY = tauntButton.AbsolutePosition.Y
            pcall(saveConfig)
        end)
        makeDragSafeClick(tauntButton, toggleTaunt)
        if savedTauntX and savedTauntY then
            tauntButton.Position = UDim2.new(0, savedTauntX, 0, savedTauntY)
        end
    end

    function destroyTauntGui()
        stopTaunt()
        if tauntGui then tauntGui:Destroy(); tauntGui = nil; tauntButton = nil end
    end
end

-- ==================== DROP BRAINROT ====================
local dropGui    = nil
local dropButton = nil
local dropActive = false

do
    local _wfConns = {}
    local _wfActive = false

    local function startWalkFling()
        _wfActive = true
        table.insert(_wfConns, RunService.Stepped:Connect(function()
            if not _wfActive then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and p.Character then
                    for _, part in ipairs(p.Character:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end
        end))
        local co = coroutine.create(function()
            while _wfActive do
                RunService.Heartbeat:Wait()
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root then continue end
                local vel = root.Velocity
                root.Velocity = vel * 10000 + Vector3.new(0,10000,0)
                RunService.RenderStepped:Wait()
                if root and root.Parent then root.Velocity = vel end
                RunService.Stepped:Wait()
                if root and root.Parent then root.Velocity = vel + Vector3.new(0,0.1,0) end
            end
        end)
        coroutine.resume(co)
        table.insert(_wfConns, co)
    end

    local function stopWalkFling()
        _wfActive = false
        for _, c in ipairs(_wfConns) do
            if typeof(c) == "RBXScriptConnection" then c:Disconnect()
            elseif typeof(c) == "thread" then pcall(task.cancel, c) end
        end
        _wfConns = {}
    end

    local function doDropBrainrot()
        if dropActive then return end
        dropActive = true
        startWalkFling()
        task.delay(0.4, function()
            stopWalkFling()
            task.delay(0.1, function()
                dropActive = false
                if dropButton and dropButton.Parent then
                    dropButton.Text = "DROP"
                    dropButton.BackgroundColor3 = Color3.fromRGB(0,120,255)
                end
            end)
        end)
    end

    function createDropGui()
        if dropGui then return end
        pcall(function()
            if CoreGui:FindFirstChild("DropButtonGui") then CoreGui.DropButtonGui:Destroy() end
        end)
        dropGui = Instance.new("ScreenGui")
        dropGui.Name = "DropButtonGui"
        dropGui.ResetOnSpawn = false
        dropGui.Parent = CoreGui
        dropButton = Instance.new("TextButton")
        dropButton.Size = UDim2.new(0,120,0,50)
        dropButton.Position = UDim2.new(1,-135,0,290)
        dropButton.Text = "DROP"
        dropButton.Font = Enum.Font.GothamBold
        dropButton.TextSize = 18
        dropButton.TextColor3 = Color3.new(1,1,1)
        dropButton.BackgroundColor3 = Color3.fromRGB(0,120,255)
        dropButton.Active = true
        dropButton.Draggable = true
        dropButton.Parent = dropGui
        Instance.new("UICorner", dropButton).CornerRadius = UDim.new(0,16)
        dropButton:GetPropertyChangedSignal("Draggable"):Connect(function()
            if buttonsLocked then dropButton.Draggable = false end
        end)
        dropButton:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
            savedDropX = dropButton.AbsolutePosition.X
            savedDropY = dropButton.AbsolutePosition.Y
            pcall(saveConfig)
        end)
        makeDragSafeClick(dropButton, function()
            if dropActive then return end
            dropButton.Text = "DROPPING"
            dropButton.BackgroundColor3 = Color3.fromRGB(200,0,0)
            task.spawn(doDropBrainrot)
        end)
        if savedDropX and savedDropY then
            dropButton.Position = UDim2.new(0, savedDropX, 0, savedDropY)
        end
    end

    function destroyDropGui()
        dropActive = false
        stopWalkFling()
        if dropGui then dropGui:Destroy(); dropGui = nil; dropButton = nil end
    end
end

-- ==================== ANTI FLING ====================
do
    function enableAntiFling()
        if antiFlingEnabled then return end
        antiFlingEnabled = true
        antiFlingConn = RunService.Stepped:Connect(function()
            if not antiFlingEnabled then return end
            local char = lp.Character
            if not char then return end
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then pcall(function() obj.CanCollide = false end) end
            end
        end)
    end

    function disableAntiFling()
        if not antiFlingEnabled then return end
        antiFlingEnabled = false
        if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn = nil end
    end
end

-- ==================== AUTO STEAL ====================
do
    pcall(function()
        local datas = ReplicatedStorage:FindFirstChild("Datas")
        if datas then
            local animals = datas:FindFirstChild("Animals")
            if animals then
                local ok, data = pcall(require, animals)
                if ok and data then AnimalsData = data end
            end
        end
    end)

    local function asHRP()
        local c = lp.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso"))
    end

    local function isMyBase(plotName)
        local plots = workspace:FindFirstChild("Plots")
        local plot = plots and plots:FindFirstChild(plotName)
        if not plot then return false end
        local sign = plot:FindFirstChild("PlotSign")
        if not sign then return false end
        local yb = sign:FindFirstChild("YourBase")
        return yb and yb:IsA("BillboardGui") and yb.Enabled == true
    end

    local function asScanPlot(plot)
        if not plot or not plot:IsA("Model") then return end
        if isMyBase(plot.Name) then return end
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then return end
        for _, pod in ipairs(podiums:GetChildren()) do
            if pod:IsA("Model") and pod:FindFirstChild("Base") then
                local name = "Unknown"
                local spawn = pod.Base:FindFirstChild("Spawn")
                if spawn then
                    for _, child in ipairs(spawn:GetChildren()) do
                        if child:IsA("Model") and child.Name ~= "PromptAttachment" then
                            name = child.Name
                            local info = AnimalsData[name]
                            if info and info.DisplayName then name = info.DisplayName end
                            break
                        end
                    end
                end
                table.insert(AS.animalCache, {
                    name = name, plot = plot.Name, slot = pod.Name,
                    worldPosition = pod:GetPivot().Position,
                    uid = plot.Name .. "_" .. pod.Name,
                })
            end
        end
    end

    local function asFindPrompt(ad)
        if not ad then return nil end
        local cp = AS.promptCache[ad.uid]
        if cp and cp.Parent then return cp end
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return nil end
        local plot = plots:FindFirstChild(ad.plot)
        if not plot then return nil end
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then return nil end
        local pod = pods:FindFirstChild(ad.slot)
        if not pod then return nil end
        local base = pod:FindFirstChild("Base")
        if not base then return nil end
        local sp = base:FindFirstChild("Spawn")
        if not sp then return nil end
        local att = sp:FindFirstChild("PromptAttachment")
        if not att then return nil end
        for _, p in ipairs(att:GetChildren()) do
            if p:IsA("ProximityPrompt") then AS.promptCache[ad.uid] = p; return p end
        end
    end

    local function asBuildCallbacks(prompt)
        if AS.stealCache[prompt] then return end
        local data = {holdCallbacks={}, triggerCallbacks={}, ready=true, useFirePrompt=false}
        local ok1, c1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
        if ok1 and type(c1) == "table" then
            for _, conn in ipairs(c1) do
                if type(conn.Function) == "function" then
                    table.insert(data.holdCallbacks, conn.Function)
                end
            end
        end
        local ok2, c2 = pcall(getconnections, prompt.Triggered)
        if ok2 and type(c2) == "table" then
            for _, conn in ipairs(c2) do
                if type(conn.Function) == "function" then
                    table.insert(data.triggerCallbacks, conn.Function)
                end
            end
        end
        if #data.holdCallbacks == 0 and #data.triggerCallbacks == 0 then
            data.useFirePrompt = true
        end
        AS.stealCache[prompt] = data
    end

    local function asExecSteal(prompt)
        local data = AS.stealCache[prompt]
        if not data or not data.ready then return false end
        data.ready = false
        isStealing = true
        if progressFill then
            progressFill.Size = UDim2.new(0,0,1,0)
            TweenService:Create(progressFill, TweenInfo.new(STEAL_DURATION, Enum.EasingStyle.Linear),
                {Size = UDim2.new(1,0,1,0)}):Play()
        end
        local fillStart = tick()
        local labelConn
        local labelDone = false
        labelConn = RunService.Heartbeat:Connect(function()
            if labelDone then return end
            local pct = math.clamp((tick() - fillStart) / STEAL_DURATION, 0, 1)
            if percentLabel then percentLabel.Text = math.floor(pct * 100) .. "%" end
            if pct >= 1 then
                labelDone = true
                labelConn:Disconnect()
                task.delay(0.05, function()
                    if progressFill then progressFill.Size = UDim2.new(0,0,1,0) end
                    if percentLabel then percentLabel.Text = "0%" end
                end)
            end
        end)
        task.spawn(function()
            if data.useFirePrompt then
                pcall(function() fireproximityprompt(prompt) end)
                task.wait(STEAL_DURATION)
            else
                for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
                task.wait(STEAL_DURATION - 0.02)
                for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
                task.wait(0.02)
            end
            data.ready = true
            task.wait(0.01)
            isStealing = false
        end)
        return true
    end

    local function asNearestAnimal()
        local h = asHRP()
        if not h then return nil end
        local best, bestD = nil, math.huge
        for _, ad in ipairs(AS.animalCache) do
            if not isMyBase(ad.plot) and ad.worldPosition then
                local d = (h.Position - ad.worldPosition).Magnitude
                if d < bestD then bestD = d; best = ad end
            end
        end
        return best
    end

    function startAutoSteal()
        if AS.stealConn then AS.stealConn:Disconnect() end
        AS.stealConn = RunService.Heartbeat:Connect(function()
            if not autoStealEnabled or isStealing then return end
            local target = asNearestAnimal()
            if not target then return end
            local h = asHRP()
            if not h then return end
            if (h.Position - target.worldPosition).Magnitude > STEAL_RADIUS then return end
            local prompt = AS.promptCache[target.uid]
            if not prompt or not prompt.Parent then prompt = asFindPrompt(target) end
            if prompt then asBuildCallbacks(prompt); asExecSteal(prompt) end
        end)
    end

    function stopAutoSteal()
        if AS.stealConn then AS.stealConn:Disconnect(); AS.stealConn = nil end
        isStealing = false
        if progressFill then progressFill.Size = UDim2.new(0,0,1,0) end
        if percentLabel then percentLabel.Text = "0%" end
    end

    function setAutoSteal(state)
        if autoStealEnabled == state then return end
        autoStealEnabled = state
        if state then startAutoSteal() else stopAutoSteal() end
    end

    task.spawn(function()
        task.wait(2)
        local plots = workspace:WaitForChild("Plots", 10)
        if not plots then return end
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:IsA("Model") then asScanPlot(plot) end
        end
        plots.ChildAdded:Connect(function(plot)
            if plot:IsA("Model") then task.wait(0.5); asScanPlot(plot) end
        end)
        task.spawn(function()
            while task.wait(5) do
                AS.animalCache = {}
                for _, plot in ipairs(plots:GetChildren()) do
                    if plot:IsA("Model") then asScanPlot(plot) end
                end
            end
        end)
    end)
end

-- ==================== ANTI RAGDOLL ====================
do
    local AntiRagdollConns = {}
    local antiRagdollEnabled = false

    local function startAntiRagdoll()
        if #AntiRagdollConns > 0 then return end
        local char = player.Character or player.CharacterAdded:Wait()
        local humanoid = char:WaitForChild("Humanoid")
        local root = char:WaitForChild("HumanoidRootPart")
        local animator = humanoid:WaitForChild("Animator")
        local maxVelocity = 40
        local clampVelocity = 25
        local maxClamp = 15
        local lastVelocity = Vector3.new(0,0,0)

        local function isRagdollState()
            local state = humanoid:GetState()
            return state == Enum.HumanoidStateType.Physics
                or state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.FallingDown
                or state == Enum.HumanoidStateType.GettingUp
        end

        local function cleanRagdoll()
            for _, obj in pairs(char:GetDescendants()) do
                if obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint")
                or obj:IsA("NoCollisionConstraint")
                or (obj:IsA("Attachment") and (obj.Name == "A" or obj.Name == "B")) then
                    obj:Destroy()
                elseif obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
                    obj:Destroy()
                elseif obj:IsA("Motor6D") then
                    obj.Enabled = true
                end
            end
            for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                local name = track.Animation and track.Animation.Name:lower() or ""
                if name:find("rag") or name:find("fall") or name:find("hurt") or name:find("down") then
                    track:Stop(0)
                end
            end
        end

        local function reEnableControls()
            pcall(function()
                require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls():Enable()
            end)
        end

        table.insert(AntiRagdollConns, humanoid.StateChanged:Connect(function()
            if isRagdollState() then
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
                cleanRagdoll()
                workspace.CurrentCamera.CameraSubject = humanoid
                reEnableControls()
            end
        end))
        table.insert(AntiRagdollConns, RunService.Heartbeat:Connect(function()
            if not antiRagdollEnabled then return end
            if isRagdollState() then
                cleanRagdoll()
                local vel = root.AssemblyLinearVelocity
                if (vel - lastVelocity).Magnitude > maxVelocity and vel.Magnitude > clampVelocity then
                    root.AssemblyLinearVelocity = vel.Unit * math.min(vel.Magnitude, maxClamp)
                end
                lastVelocity = vel
            end
        end))
        table.insert(AntiRagdollConns, char.DescendantAdded:Connect(function()
            if isRagdollState() then cleanRagdoll() end
        end))
        table.insert(AntiRagdollConns, player.CharacterAdded:Connect(function(newChar)
            char = newChar
            humanoid = newChar:WaitForChild("Humanoid")
            root = newChar:WaitForChild("HumanoidRootPart")
            animator = humanoid:WaitForChild("Animator")
            lastVelocity = Vector3.new(0,0,0)
            reEnableControls()
            cleanRagdoll()
        end))
        reEnableControls()
        cleanRagdoll()
    end

    local function stopAntiRagdoll()
        for _, conn in pairs(AntiRagdollConns) do
            if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
        end
        AntiRagdollConns = {}
    end

    function toggleAntiRagdoll(enable)
        if enable then
            antiRagdollEnabled = true
            antiRagdollMode = "v2"
            startAntiRagdoll()
        else
            antiRagdollEnabled = false
            antiRagdollMode = nil
            stopAntiRagdoll()
            cachedCharData = {}
            ragdollConnections = {}
        end
    end
end

-- ==================== AUTO MEDUSA ====================
do
    function InitMedusa()
        if MedusaInitialized then return end
        MedusaInitialized = true

        local function createRadius()
            if medusaPart then medusaPart:Destroy() end
            medusaPart = Instance.new("Part")
            medusaPart.Name = "MedusaRadius"
            medusaPart.Anchored = true
            medusaPart.CanCollide = false
            medusaPart.Transparency = 1
            medusaPart.Material = Enum.Material.Neon
            medusaPart.Color = Color3.fromRGB(255,0,0)
            medusaPart.Shape = Enum.PartType.Cylinder
            medusaPart.Size = Vector3.new(0.05, MEDUSA_RADIUS*2, MEDUSA_RADIUS*2)
            medusaPart.Parent = workspace
        end

        local function isMedusaEquipped()
            local char2 = lp.Character
            if not char2 then return nil end
            for _, tool in ipairs(char2:GetChildren()) do
                if tool:IsA("Tool") and tool.Name == "Medusa's Head" then return tool end
            end
            return nil
        end

        createRadius()

        RunService.RenderStepped:Connect(function()
            if not AutoMedusaEnabled then
                if medusaPart then medusaPart.Transparency = 1 end
                return
            end
            if not medusaPart then return end
            medusaPart.Size = Vector3.new(0.05, MEDUSA_RADIUS*2, MEDUSA_RADIUS*2)
            medusaPart.Transparency = 0.75
            local char2 = lp.Character
            if not char2 then return end
            local root2 = char2:FindFirstChild("HumanoidRootPart")
            if not root2 then return end
            medusaPart.CFrame = CFrame.new(root2.Position + Vector3.new(0,-2.5,0)) * CFrame.Angles(0,0,math.rad(90))
        end)

        RunService.Heartbeat:Connect(function()
            if not AutoMedusaEnabled then return end
            local char2 = lp.Character
            if not char2 then return end
            local root2 = char2:FindFirstChild("HumanoidRootPart")
            if not root2 then return end
            local tool = isMedusaEquipped()
            if not tool then return end
            if tick() - lastUseMedusa < SPAM_DELAY then return end
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp then
                    local pChar = plr.Character
                    local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                    if pRoot and (pRoot.Position - root2.Position).Magnitude <= MEDUSA_RADIUS then
                        tool:Activate()
                        lastUseMedusa = tick()
                        break
                    end
                end
            end
        end)
    end
end

-- ==================== GALAXY MODE ====================
do
    local function captureGalaxyDefaults()
        if galaxyDefaults.captured then return end
        galaxyDefaults.captured = true
        galaxyDefaults.Brightness = Lighting.Brightness
        galaxyDefaults.ClockTime = Lighting.ClockTime
        galaxyDefaults.OutdoorAmbient = Lighting.OutdoorAmbient
        pcall(function() galaxyDefaults.ExposureCompensation = Lighting.ExposureCompensation end)
    end

    function enableGalaxy()
        if galaxyOn then return end
        captureGalaxyDefaults()
        galaxyOn = true
        pcall(function()
            local sky = Lighting:FindFirstChild("GalaxySky") or Instance.new("Sky")
            sky.Name = "GalaxySky"
            sky.SkyboxBk = "rbxassetid://159454299"
            sky.SkyboxDn = "rbxassetid://159454296"
            sky.SkyboxFt = "rbxassetid://159454293"
            sky.SkyboxLf = "rbxassetid://159454286"
            sky.SkyboxRt = "rbxassetid://159454289"
            sky.SkyboxUp = "rbxassetid://159454291"
            sky.Parent = Lighting
        end)
        Lighting.Brightness = 0
        Lighting.ClockTime = 0
        Lighting.OutdoorAmbient = Color3.fromRGB(0,0,0)
        pcall(function() Lighting.ExposureCompensation = -2 end)
    end

    function disableGalaxy()
        if not galaxyOn then return end
        galaxyOn = false
        local sky = Lighting:FindFirstChild("GalaxySky")
        if sky then sky:Destroy() end
        Lighting.Brightness = galaxyDefaults.Brightness or 1
        Lighting.ClockTime = galaxyDefaults.ClockTime or 14
        Lighting.OutdoorAmbient = galaxyDefaults.OutdoorAmbient or Color3.fromRGB(127,127,127)
        pcall(function() Lighting.ExposureCompensation = galaxyDefaults.ExposureCompensation or 0 end)
    end
end

-- ==================== OPTIMIZER ====================
do
    function enableOptimizer()
        if optimizerEnabled then return end
        optimizerEnabled = true
        savedLighting = {
            GlobalShadows = Lighting.GlobalShadows,
            FogStart = Lighting.FogStart,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        }
        Lighting.GlobalShadows = false
        Lighting.FogStart = 0
        Lighting.FogEnd = 1e9
        Lighting.Brightness = 1
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                optimized[v] = {v.Material, v.Reflectance}
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                optimized[v] = v.Transparency
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
                optimized[v] = v.Enabled
                v.Enabled = false
            end
        end
    end

    function disableOptimizer()
        if not optimizerEnabled then return end
        optimizerEnabled = false
        for k, v in pairs(savedLighting) do Lighting[k] = v end
        for obj, val in pairs(optimized) do
            if obj and obj.Parent then
                if typeof(val) == "table" then
                    obj.Material = val[1]; obj.Reflectance = val[2]
                elseif typeof(val) == "boolean" then
                    obj.Enabled = val
                else
                    obj.Transparency = val
                end
            end
        end
        optimized = {}
    end
end

-- ==================== ESP ====================
do
    local function createESP(plr)
        if plr == lp then return end
        if not plr.Character then return end
        if plr.Character:FindFirstChild("ESP_BLUE") then return end
        local char = plr.Character
        local hrp2 = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not (hrp2 and head) then return end
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_BLUE"
        hl.FillColor = Color3.fromRGB(0,120,255)
        hl.OutlineColor = Color3.fromRGB(0,120,255)
        hl.FillTransparency = 0.2
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        local hb = Instance.new("BoxHandleAdornment")
        hb.Name = "ESP_Hitbox"
        hb.Adornee = hrp2
        hb.Size = Vector3.new(4,6,2)
        hb.Color3 = Color3.fromRGB(0,120,255)
        hb.Transparency = 0.5
        hb.AlwaysOnTop = true
        hb.ZIndex = 10
        hb.Parent = char
        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_Name"
        bb.Adornee = head
        bb.Size = UDim2.new(0,200,0,50)
        bb.StudsOffset = Vector3.new(0,3,0)
        bb.AlwaysOnTop = true
        bb.Parent = char
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = plr.DisplayName or plr.Name
        lbl.TextColor3 = Color3.fromRGB(0,120,255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.TextStrokeTransparency = 0.6
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        lbl.Parent = bb
    end

    local function removeESP(plr)
        if not plr.Character then return end
        for _, n in ipairs({"ESP_BLUE", "ESP_Hitbox", "ESP_Name"}) do
            local obj = plr.Character:FindFirstChild(n)
            if obj then obj:Destroy() end
        end
    end

    function toggleESPPlayers(enable)
        espEnabled = enable
        if enable then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= lp then
                    if plr.Character then createESP(plr) end
                    local conn = plr.CharacterAdded:Connect(function()
                        task.wait(0.2)
                        if espEnabled then createESP(plr) end
                    end)
                    table.insert(espConnections, conn)
                end
            end
            local pac = Players.PlayerAdded:Connect(function(plr)
                if plr == lp then return end
                local cac = plr.CharacterAdded:Connect(function()
                    task.wait(0.2)
                    if espEnabled then createESP(plr) end
                end)
                table.insert(espConnections, cac)
            end)
            table.insert(espConnections, pac)
        else
            for _, plr in ipairs(Players:GetPlayers()) do removeESP(plr) end
            for _, conn in ipairs(espConnections) do
                if conn and conn.Connected then conn:Disconnect() end
            end
            espConnections = {}
        end
    end
end

-- ==================== HEAD TAG ====================
do
    local TAG_TEXT = "discord.gg/VHU5rhjq9u"
    local function setupHeadTag(char)
        if not char then return end
        local head = char:WaitForChild("Head", 10)
        if not head then return end
        local existing = head:FindFirstChild("NovaTag")
        if existing then existing:Destroy() end
        local bb = Instance.new("BillboardGui", head)
        bb.Name = "NovaTag"
        bb.Size = UDim2.new(0,200,0,22)
        bb.StudsOffset = Vector3.new(0,2.2,0)
        bb.AlwaysOnTop = true
        bb.ResetOnSpawn = false
        local lbl = Instance.new("TextLabel", bb)
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = TAG_TEXT
        lbl.TextColor3 = Color3.fromRGB(0,180,255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 13
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    end
    if lp.Character then task.spawn(function() setupHeadTag(lp.Character) end) end
    lp.CharacterAdded:Connect(function(char) task.wait(0.6); setupHeadTag(char) end)
end

-- ==================== CONFIG SAVE/LOAD ====================
local CONFIG_FILE = "NovaHub_config.json"

local function encodeJSON(t)
    local parts = {}
    for k, v in pairs(t) do
        local key = '"' .. tostring(k) .. '"'
        local val
        if type(v) == "boolean" then
            val = v and "true" or "false"
        elseif type(v) == "number" then
            val = tostring(v)
        elseif type(v) == "string" then
            local esc = v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
            val = '"' .. esc .. '"'
        elseif type(v) == "table" then
            val = encodeJSON(v)
        end
        if val then table.insert(parts, key .. ":" .. val) end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function decodeJSONFlat(s)
    local t = {}
    local inner = s:match("^%s*{(.+)}%s*$")
    if not inner then return t end
    local pos = 1
    while pos <= #inner do
        local ks, ke, key = inner:find('"([^"]*)"', pos)
        if not ks then break end
        pos = ke + 1
        local cs = inner:find(':', pos)
        if not cs then break end
        pos = cs + 1
        while pos <= #inner and inner:sub(pos, pos):match('%s') do pos = pos + 1 end
        if pos > #inner then break end
        local ch = inner:sub(pos, pos)
        local val
        if ch == '"' then
            local vs = pos + 1
            local ve = vs
            while ve <= #inner do
                if inner:sub(ve, ve) == '\\' then ve = ve + 2
                elseif inner:sub(ve, ve) == '"' then break
                else ve = ve + 1 end
            end
            val = inner:sub(vs, ve - 1):gsub('\\"', '"'):gsub('\\\\', '\\'):gsub('\\n', '\n')
            pos = ve + 1
        elseif inner:sub(pos, pos+3) == "true" then
            val = true; pos = pos + 4
        elseif inner:sub(pos, pos+4) == "false" then
            val = false; pos = pos + 5
        else
            local ne = inner:find('[,%}%s]', pos)
            if ne then val = tonumber(inner:sub(pos, ne-1)); pos = ne
            else val = tonumber(inner:sub(pos)); pos = #inner + 1 end
        end
        if val ~= nil then t[key] = val end
        local nc = inner:find(',', pos)
        local nk = inner:find('"', pos)
        if nc and (not nk or nc < nk) then pos = nc + 1 end
    end
    return t
end

local function loadConfigEarly()
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw or raw == "" then return end
    local data = decodeJSONFlat(raw)
    if not data then return end
    if data.btn_x      then savedBtnX     = data.btn_x;     savedBtnY     = data.btn_y     end
    if data.hub_x      then savedHubX     = data.hub_x;     savedHubY     = data.hub_y     end
    if data.top_x      then savedTopX     = data.top_x;     savedTopY     = data.top_y     end
    if data.main_x     then savedMainX    = data.main_x;    savedMainY    = data.main_y    end
    if data.autoPlay_x then savedAutoPlayX= data.autoPlay_x;savedAutoPlayY= data.autoPlay_y end
    if data.aimbot_x   then savedAimbotX  = data.aimbot_x;  savedAimbotY  = data.aimbot_y  end
    if data.taunt_x    then savedTauntX   = data.taunt_x;   savedTauntY   = data.taunt_y   end
    if data.drop_x     then savedDropX    = data.drop_x;    savedDropY    = data.drop_y    end
    if data.tpdown_x   then savedTpDownX  = data.tpdown_x;  savedTpDownY  = data.tpdown_y  end
    if data.steal_radius  then STEAL_RADIUS  = data.steal_radius  end
    if data.medusa_radius then MEDUSA_RADIUS = data.medusa_radius end
    if data.fov_value  then FOV_VALUE = data.fov_value; pcall(function() workspace.CurrentCamera.FieldOfView = FOV_VALUE end) end
    if data.gui_scale  then guiScale = data.gui_scale end
    if data.sc_going   then goingSpeed  = data.sc_going  end
    if data.sc_return  then returnSpeed = data.sc_return end
    if data.sc_active ~= nil then _G._novaScActive = data.sc_active end
    if data.buttons_locked ~= nil then buttonsLocked = data.buttons_locked end
    local i = 0
    while true do
        local name = data["tn_"..i]
        local val  = data["tv_"..i]
        if name == nil then break end
        configToggles[name] = val
        i = i + 1
    end
end
pcall(loadConfigEarly)

-- ==================== MAIN HUB GUI ====================
local ok_main, err_main = pcall(function()

local sg = Instance.new("ScreenGui")
sg.Name = "NovaHub"
sg.ResetOnSpawn = false
sg.Parent = CoreGui

progressBarBg = Instance.new("Frame")
progressBarBg.Size = UDim2.new(0,240,0,10)
progressBarBg.Position = UDim2.new(0.5,-120,0,52)
progressBarBg.BackgroundColor3 = Color3.fromRGB(15,15,15)
progressBarBg.BackgroundTransparency = 0.25
progressBarBg.Visible = true
progressBarBg.Active = false
progressBarBg.Parent = sg
Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(0,8)

progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0,0,1,0)
progressFill.BackgroundColor3 = Color3.fromRGB(0,120,255)
progressFill.Parent = progressBarBg
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0,8)

percentLabel = Instance.new("TextLabel")
percentLabel.Size = UDim2.new(0.55,0,1,0)
percentLabel.BackgroundTransparency = 1
percentLabel.Font = Enum.Font.GothamBold
percentLabel.TextSize = 11
percentLabel.TextColor3 = Color3.fromRGB(220,220,220)
percentLabel.Text = "0%"
percentLabel.Parent = progressBarBg

local radiusBox = Instance.new("TextBox")
radiusBox.Size = UDim2.new(0.42,0,1,0)
radiusBox.Position = UDim2.new(0.57,0,0,0)
radiusBox.BackgroundColor3 = Color3.fromRGB(20,20,20)
radiusBox.BackgroundTransparency = 0.3
radiusBox.TextColor3 = Color3.fromRGB(220,220,220)
radiusBox.Font = Enum.Font.GothamBold
radiusBox.TextSize = 11
radiusBox.ClearTextOnFocus = false
radiusBox.Text = tostring(STEAL_RADIUS)
radiusBox.Parent = progressBarBg
Instance.new("UICorner", radiusBox).CornerRadius = UDim.new(0,4)

local stealSquarePart = nil
local circleConnection = nil

local function hideSquare()
    if stealSquarePart then stealSquarePart:Destroy(); stealSquarePart = nil end
end

local function createOrUpdateSquare(radius)
    if not stealSquarePart then
        stealSquarePart = Instance.new("Part")
        stealSquarePart.Name = "StealCircle"
        stealSquarePart.Anchored = true
        stealSquarePart.CanCollide = false
        stealSquarePart.Transparency = 0.7
        stealSquarePart.Material = Enum.Material.Neon
        stealSquarePart.Color = Color3.fromRGB(0,120,255)
        stealSquarePart.Shape = Enum.PartType.Cylinder
        stealSquarePart.Size = Vector3.new(0.05, radius*2, radius*2)
        stealSquarePart.Parent = workspace
    else
        stealSquarePart.Size = Vector3.new(0.05, radius*2, radius*2)
    end
end

local function updateSquarePosition()
    if stealSquarePart and lp.Character then
        local r = lp.Character:FindFirstChild("HumanoidRootPart")
        if r then
            stealSquarePart.CFrame = CFrame.new(r.Position + Vector3.new(0,-2.5,0)) * CFrame.Angles(0,0,math.rad(90))
        end
    end
end

radiusBox.FocusLost:Connect(function()
    local num = tonumber(radiusBox.Text:gsub("%D",""))
    if num then
        num = math.clamp(num, 1, 50)
        STEAL_RADIUS = num
        radiusBox.Text = tostring(num)
        createOrUpdateSquare(STEAL_RADIUS)
        pcall(saveConfig)
    else
        radiusBox.Text = tostring(STEAL_RADIUS)
    end
end)

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(0,240,0,32)
topBar.Position = UDim2.new(0.5,-120,0,15)
topBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
topBar.BackgroundTransparency = 0.15
topBar.Active = false
topBar.Draggable = false
topBar.Parent = sg
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", topBar).Color = Color3.fromRGB(0,120,255)

local topLabel = Instance.new("TextLabel")
topLabel.Size = UDim2.new(1,0,1,0)
topLabel.BackgroundTransparency = 1
topLabel.Font = Enum.Font.GothamBold
topLabel.TextSize = 14
topLabel.TextColor3 = Color3.fromRGB(0,120,255)
topLabel.Parent = topBar

local fps, framesCount, lastTick = 60, 0, tick()
RunService.RenderStepped:Connect(function()
    framesCount = framesCount + 1
    if tick() - lastTick >= 1 then
        fps = framesCount; framesCount = 0; lastTick = tick()
    end
    local ping = 0
    local net = Stats:FindFirstChild("Network")
    if net and net:FindFirstChild("ServerStatsItem") then
        local dp = net.ServerStatsItem:FindFirstChild("Data Ping")
        if dp then ping = math.floor(dp:GetValue()) end
    end
    topLabel.Text = "Nova Hub | " .. fps .. " FPS | " .. ping .. " ms"
end)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0,55,0,55)
toggleBtn.Position = UDim2.new(1,-70,0,70)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0,120,255)
toggleBtn.Text = "\u{2261}"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 38
toggleBtn.TextColor3 = Color3.new(1,1,1)
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = sg
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,14)
if savedBtnX and savedBtnY then toggleBtn.Position = UDim2.new(0, savedBtnX, 0, savedBtnY) end
toggleBtn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
    savedBtnX = toggleBtn.AbsolutePosition.X
    savedBtnY = toggleBtn.AbsolutePosition.Y
    pcall(saveConfig)
end)
toggleBtn:GetPropertyChangedSignal("Draggable"):Connect(function()
    if buttonsLocked then toggleBtn.Draggable = false end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.U then toggleBtn.MouseButton1Click:Fire() end
end)

local HUB_WIDTH  = 280
local HUB_HEIGHT = 430
local hub = Instance.new("Frame")
hub.Size = UDim2.new(0, HUB_WIDTH, 0, HUB_HEIGHT)
hub.Position = UDim2.new(0, -350, 0.5, -HUB_HEIGHT/2)
hub.BackgroundColor3 = Color3.fromRGB(0,0,0)
hub.BackgroundTransparency = 0.25
hub.Active = true
hub.Draggable = true
hub.Parent = sg
Instance.new("UICorner", hub).CornerRadius = UDim.new(0,14)
local strokeHub = Instance.new("UIStroke", hub)
strokeHub.Color = Color3.fromRGB(0,120,255)
strokeHub.Thickness = 2
if savedHubX and savedHubY then hub.Position = UDim2.new(0, savedHubX, 0, savedHubY) end
hub:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
    savedHubX = hub.AbsolutePosition.X
    savedHubY = hub.AbsolutePosition.Y
    pcall(saveConfig)
end)
hub:GetPropertyChangedSignal("Draggable"):Connect(function()
    if buttonsLocked then hub.Draggable = false end
end)
mainHubFrame = hub

local hubTitle = Instance.new("TextLabel")
hubTitle.Size = UDim2.new(1,0,0,40)
hubTitle.Position = UDim2.new(0,12,0,8)
hubTitle.BackgroundTransparency = 1
hubTitle.Font = Enum.Font.GothamBold
hubTitle.TextSize = 20
hubTitle.TextXAlignment = Enum.TextXAlignment.Left
hubTitle.TextColor3 = Color3.fromRGB(0,120,255)
hubTitle.Text = "Nova Hub"
hubTitle.Parent = hub

local sections = {"Combat", "Player", "Visual", "Settings"}
local sectionButtons = {}
local sectionFrames = {}
local startX = 8
local spacing = 5
local sectionWidth = (280 - 2*startX - (spacing * (#sections - 1))) / #sections
local sectionY = 55

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -120)
content.Position = UDim2.new(0, 10, 0, 95)
content.BackgroundTransparency = 1
content.Parent = hub

for _, name in ipairs(sections) do
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,1,0)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.ScrollBarThickness = 4
    scroll.BackgroundTransparency = 1
    scroll.Visible = false
    scroll.Name = name .. "Frame"
    scroll.Parent = content
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,8)
    layout.Parent = scroll
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0, layout.AbsoluteContentSize.Y + 10)
    end)
    sectionFrames[name] = scroll
end

local function ShowSection(sectionName)
    for _, f in pairs(sectionFrames) do f.Visible = false end
    sectionFrames[sectionName].Visible = true
    for _, b in pairs(sectionButtons) do b.BackgroundColor3 = Color3.fromRGB(10,10,10) end
    for _, b in pairs(sectionButtons) do
        if b.Text == sectionName then b.BackgroundColor3 = Color3.fromRGB(0,120,255) end
    end
end

for i, v in ipairs(sections) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, sectionWidth, 0, 28)
    btn.Position = UDim2.new(0, startX + (i-1)*(sectionWidth+spacing), 0, sectionY)
    btn.BackgroundColor3 = Color3.fromRGB(10,10,10)
    btn.Text = v
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = hub
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", btn).Color = Color3.fromRGB(0,120,255)
    table.insert(sectionButtons, btn)
    btn.MouseButton1Click:Connect(function() ShowSection(v) end)
end

-- LOCK BUTTON
local lockContainer = Instance.new("Frame")
lockContainer.Size = UDim2.new(1,0,0,45)
lockContainer.BackgroundColor3 = Color3.fromRGB(15,15,15)
lockContainer.BackgroundTransparency = 0.2
lockContainer.Parent = sectionFrames["Settings"]
Instance.new("UICorner", lockContainer).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", lockContainer).Color = Color3.fromRGB(0,120,255)

local lockLbl = Instance.new("TextLabel")
lockLbl.Size = UDim2.new(0.6,0,1,0)
lockLbl.Position = UDim2.new(0,12,0,0)
lockLbl.BackgroundTransparency = 1
lockLbl.Font = Enum.Font.GothamBold
lockLbl.TextSize = 14
lockLbl.TextColor3 = Color3.fromRGB(0,120,255)
lockLbl.TextXAlignment = Enum.TextXAlignment.Left
lockLbl.Text = "🔒 Lock All Buttons"
lockLbl.Parent = lockContainer

local lockBtn = Instance.new("TextButton")
lockBtn.Size = UDim2.new(0,50,0,22)
lockBtn.Position = UDim2.new(1,-60,0.5,-11)
lockBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
lockBtn.Text = ""
lockBtn.Parent = lockContainer
Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(1,0)

local lockCircle = Instance.new("Frame")
lockCircle.Size = UDim2.new(0,18,0,18)
lockCircle.Position = UDim2.new(0,2,0.5,-9)
lockCircle.BackgroundColor3 = Color3.fromRGB(220,220,220)
lockCircle.Parent = lockBtn
Instance.new("UICorner", lockCircle).CornerRadius = UDim.new(1,0)

local function updateLockButtonUI()
    if buttonsLocked then
        TweenService:Create(lockBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(0,120,255)}):Play()
        TweenService:Create(lockCircle, TweenInfo.new(0.25), {Position = UDim2.new(1,-20,0.5,-9)}):Play()
        lockLbl.Text = "🔒 Buttons Locked"
    else
        TweenService:Create(lockBtn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(50,50,50)}):Play()
        TweenService:Create(lockCircle, TweenInfo.new(0.25), {Position = UDim2.new(0,2,0.5,-9)}):Play()
        lockLbl.Text = "🔒 Lock All Buttons"
    end
end

local function applyButtonLockToAll()
    local draggableItems = {toggleBtn, hub, fovFrame, batButton, tpDownButton, tauntButton, dropButton}
    if autoPlayGui then
        local apFrame = autoPlayGui:FindFirstChildOfClass("Frame")
        if apFrame then table.insert(draggableItems, apFrame) end
    end
    for _, item in pairs(draggableItems) do
        if item and item:IsA("GuiObject") then
            item.Draggable = not buttonsLocked
        end
    end
end

lockBtn.MouseButton1Click:Connect(function()
    buttonsLocked = not buttonsLocked
    updateLockButtonUI()
    applyButtonLockToAll()
    pcall(saveConfig)
end)

if buttonsLocked then
    updateLockButtonUI()
    task.defer(applyButtonLockToAll)
end

-- RESET BUTTON
local resetContainer = Instance.new("Frame")
resetContainer.Size = UDim2.new(1,0,0,45)
resetContainer.BackgroundColor3 = Color3.fromRGB(15,15,15)
resetContainer.BackgroundTransparency = 0.2
resetContainer.Parent = sectionFrames["Settings"]
Instance.new("UICorner", resetContainer).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", resetContainer).Color = Color3.fromRGB(255, 100, 100)

local resetLbl = Instance.new("TextLabel")
resetLbl.Size = UDim2.new(0.6,0,1,0)
resetLbl.Position = UDim2.new(0,12,0,0)
resetLbl.BackgroundTransparency = 1
resetLbl.Font = Enum.Font.GothamBold
resetLbl.TextSize = 14
resetLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
resetLbl.TextXAlignment = Enum.TextXAlignment.Left
resetLbl.Text = "⚠ Reset All Settings"
resetLbl.Parent = resetContainer

local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(0,80,0,28)
resetBtn.Position = UDim2.new(1,-90,0.5,-14)
resetBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
resetBtn.Text = "RESET"
resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 14
resetBtn.Parent = resetContainer
Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 8)

local resetConfirmActive = false
resetBtn.MouseButton1Click:Connect(function()
    if not resetConfirmActive then
        resetConfirmActive = true
        resetBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        resetBtn.Text = "CONFIRM?"
        resetLbl.Text = "⚠ Click CONFIRM to reset ALL settings!"
        task.delay(3, function()
            if resetConfirmActive then
                resetConfirmActive = false
                resetBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                resetBtn.Text = "RESET"
                resetLbl.Text = "⚠ Reset All Settings"
            end
        end)
    else
        resetConfirmActive = false
        resetBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        resetBtn.Text = "RESET"
        resetLbl.Text = "⚠ Reset All Settings"
        resetAllSettings()
    end
end)

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, -20, 0, 32)
saveBtn.Position = UDim2.new(0, 10, 1, -42)
saveBtn.BackgroundColor3 = Color3.fromRGB(0,90,200)
saveBtn.TextColor3 = Color3.fromRGB(255,255,255)
saveBtn.Text = "💾 Save Config"
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 14
saveBtn.Parent = hub
Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", saveBtn).Color = Color3.fromRGB(0,120,255)
saveBtn.MouseButton1Click:Connect(function()
    pcall(saveConfig)
    saveBtn.Text = "✓ Saved!"
    saveBtn.BackgroundColor3 = Color3.fromRGB(0,160,60)
    task.delay(1.5, function()
        if saveBtn and saveBtn.Parent then
            saveBtn.Text = "💾 Save Config"
            saveBtn.BackgroundColor3 = Color3.fromRGB(0,90,200)
        end
    end)
end)

local function CreateSlider(sectionName, labelText, minVal, maxVal, currentVal, onChanged)
    local parentFrame = sectionFrames[sectionName]
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,60)
    container.BackgroundColor3 = Color3.fromRGB(15,15,15)
    container.BackgroundTransparency = 0.2
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", container).Color = Color3.fromRGB(0,120,255)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65,0,0,20)
    lbl.Position = UDim2.new(0,10,0,5)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextColor3 = Color3.fromRGB(0,120,255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = labelText
    lbl.Parent = container
    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.3,0,0,20)
    valLbl.Position = UDim2.new(0.68,0,0,5)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 13
    valLbl.TextColor3 = Color3.fromRGB(255,255,255)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Text = tostring(currentVal)
    valLbl.Parent = container
    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0,28,0,26)
    minus.Position = UDim2.new(0,8,0,30)
    minus.BackgroundColor3 = Color3.fromRGB(40,40,60)
    minus.Text = "-"
    minus.TextColor3 = Color3.fromRGB(255,255,255)
    minus.TextSize = 18
    minus.Font = Enum.Font.GothamBold
    minus.Parent = container
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0,6)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0,90,0,26)
    box.Position = UDim2.new(0,40,0,30)
    box.BackgroundColor3 = Color3.fromRGB(20,20,30)
    box.Text = tostring(currentVal)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.TextSize = 13
    box.Font = Enum.Font.GothamBold
    box.ClearTextOnFocus = false
    box.Parent = container
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", box).Color = Color3.fromRGB(0,120,255)
    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0,28,0,26)
    plus.Position = UDim2.new(0,134,0,30)
    plus.BackgroundColor3 = Color3.fromRGB(40,40,60)
    plus.Text = "+"
    plus.TextColor3 = Color3.fromRGB(255,255,255)
    plus.TextSize = 18
    plus.Font = Enum.Font.GothamBold
    plus.Parent = container
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0,6)
    local function applyVal(v)
        v = math.clamp(math.floor(v), minVal, maxVal)
        box.Text = tostring(v)
        valLbl.Text = tostring(v)
        onChanged(v)
        pcall(saveConfig)
    end
    minus.MouseButton1Click:Connect(function()
        local cur = tonumber(box.Text) or currentVal; applyVal(cur - 1)
    end)
    plus.MouseButton1Click:Connect(function()
        local cur = tonumber(box.Text) or currentVal; applyVal(cur + 1)
    end)
    box.FocusLost:Connect(function()
        local v = tonumber(box.Text)
        if v then applyVal(v) else box.Text = valLbl.Text end
    end)
end

-- FIXED: CreateToggle now registers itself in toggleButtonRefs
local function CreateToggle(sectionName, text, defaultOn)
    local parentFrame = sectionFrames[sectionName]
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,45)
    container.BackgroundColor3 = Color3.fromRGB(15,15,15)
    container.BackgroundTransparency = 0.2
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", container).Color = Color3.fromRGB(0,120,255)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6,0,1,0)
    lbl.Position = UDim2.new(0,12,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.TextColor3 = Color3.fromRGB(0,120,255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text
    lbl.Parent = container

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,50,0,22)
    btn.Position = UDim2.new(1,-60,0.5,-11)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    btn.Text = ""
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,18,0,18)
    circle.Position = UDim2.new(0,2,0.5,-9)
    circle.BackgroundColor3 = Color3.fromRGB(220,220,220)
    circle.Parent = btn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)

    local enabled = false

    local function fireToggle()
        enabled = not enabled
        if enabled then
            TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(0,120,255)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.25), {Position = UDim2.new(1,-20,0.5,-9)}):Play()
        else
            TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(50,50,50)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.25), {Position = UDim2.new(0,2,0.5,-9)}):Play()
        end
        configToggles[text] = enabled
        pcall(saveConfig)
        applyToggleAction(text, enabled)
        -- also handle Auto Steal circle here since it needs closures
        if text == "Auto Steal Nearest" then
            setAutoSteal(enabled)
            if enabled then
                createOrUpdateSquare(STEAL_RADIUS)
                if circleConnection then circleConnection:Disconnect() end
                circleConnection = RunService.RenderStepped:Connect(updateSquarePosition)
            else
                hideSquare()
                if circleConnection then circleConnection:Disconnect(); circleConnection = nil end
            end
        end
    end

    -- FIXED: register in toggleButtonRefs so resetAllSettings can call fireToggle
    toggleButtonRefs[text] = {
        fireToggle = fireToggle,
        getState   = function() return enabled end,
    }

    btn.MouseButton1Click:Connect(fireToggle)
    local savedState = configToggles[text]
    local shouldEnable = (savedState ~= nil) and savedState or (defaultOn == true)
    if shouldEnable then task.defer(fireToggle) end
end

for _, f in ipairs({"Bat Aimbot", "Auto Steal Nearest", "Auto Play", "Drop Br", "TP Down", "Taunt Spam", "Auto Medusa"}) do
    CreateToggle("Combat", f)
end
CreateToggle("Player", "Speed Customizer")
CreateToggle("Player", "Infinite Jump", true)
CreateToggle("Player", "No Walk Animation", true)
CreateToggle("Player", "Anti Ragdoll", true)
CreateToggle("Player", "Anti Fling")
CreateToggle("Visual", "Galaxy Mode")
CreateToggle("Visual", "Optimizer", true)
CreateToggle("Visual", "ESP Players", true)
CreateToggle("Visual", "FOV Changer", false)

do
    local hdrMed = Instance.new("TextLabel")
    hdrMed.Size = UDim2.new(1,0,0,22)
    hdrMed.BackgroundTransparency = 1
    hdrMed.Font = Enum.Font.GothamBold
    hdrMed.TextSize = 12
    hdrMed.TextColor3 = Color3.fromRGB(180,180,180)
    hdrMed.TextXAlignment = Enum.TextXAlignment.Left
    hdrMed.Text = "  🐍 Auto Medusa Settings"
    hdrMed.Parent = sectionFrames["Settings"]

    CreateSlider("Settings", "Medusa Radius", 1, 60, MEDUSA_RADIUS, function(v)
        MEDUSA_RADIUS = v
        if medusaPart and medusaPart.Parent then
            medusaPart.Size = Vector3.new(0.05, MEDUSA_RADIUS*2, MEDUSA_RADIUS*2)
        end
    end)
end

lp.CharacterAdded:Connect(function()
    task.wait(0.5); createSpeedDisplay()
end)
if lp.Character then
    task.spawn(function() task.wait(0.5); createSpeedDisplay() end)
end

ShowSection("Combat")

local opened = false
toggleBtn.MouseButton1Click:Connect(function()
    opened = not opened
    if opened then
        TweenService:Create(hub, TweenInfo.new(0.3), {Position = UDim2.new(0,20,0.5,-HUB_HEIGHT/2)}):Play()
    else
        TweenService:Create(hub, TweenInfo.new(0.3), {Position = UDim2.new(0,-350,0.5,-HUB_HEIGHT/2)}):Play()
    end
end)

end)

if not ok_main then
    warn("[NovaHub] UI build error: " .. tostring(err_main))
end

-- ==================== SPEED CUSTOMIZER ====================
local ok_sc, err_sc = pcall(function()
    local scGui = Instance.new("ScreenGui")
    scGui.Name = "BoosterCustomizer"
    scGui.ResetOnSpawn = false
    scGui.Enabled = false
    scGui.Parent = CoreGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0,240,0,215)
    main.Position = UDim2.new(0.5,-120,0.15,0)
    main.BackgroundColor3 = Color3.fromRGB(0,0,0)
    main.BackgroundTransparency = 0.35
    main.Active = true
    main.Draggable = true
    main.Parent = scGui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)
    local scStroke = Instance.new("UIStroke", main)
    scStroke.Color = Color3.fromRGB(0,120,255)
    scStroke.Thickness = 2
    if savedMainX and savedMainY then main.Position = UDim2.new(0, savedMainX, 0, savedMainY) end
    main:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
        savedMainX = main.AbsolutePosition.X
        savedMainY = main.AbsolutePosition.Y
        pcall(saveConfig)
    end)
    main:GetPropertyChangedSignal("Draggable"):Connect(function()
        if buttonsLocked then main.Draggable = false end
    end)

    local titleSC = Instance.new("TextLabel")
    titleSC.Size = UDim2.new(1,0,0,35)
    titleSC.Position = UDim2.new(0,10,0,5)
    titleSC.BackgroundTransparency = 1
    titleSC.Text = "Speed Customizer"
    titleSC.Font = Enum.Font.GothamBold
    titleSC.TextSize = 18
    titleSC.TextColor3 = Color3.fromRGB(0,120,255)
    titleSC.TextXAlignment = Enum.TextXAlignment.Left
    titleSC.Parent = main

    local activate = Instance.new("TextButton")
    activate.Size = UDim2.new(1,-20,0,35)
    activate.Position = UDim2.new(0,10,0,40)
    activate.BackgroundColor3 = Color3.fromRGB(25,25,25)
    activate.TextColor3 = Color3.fromRGB(255,255,255)
    activate.Text = "OFF"
    activate.Font = Enum.Font.GothamBold
    activate.TextSize = 16
    activate.Parent = main
    Instance.new("UICorner", activate).CornerRadius = UDim.new(0,8)
    Instance.new("UIStroke", activate).Color = Color3.fromRGB(0,120,255)

    local function createRow(text, posY, default)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55,0,0,28)
        lbl.Position = UDim2.new(0,10,0,posY)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = main
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.35,0,0,28)
        box.Position = UDim2.new(0.6,0,0,posY)
        box.BackgroundColor3 = Color3.fromRGB(20,20,20)
        box.TextColor3 = Color3.fromRGB(255,255,255)
        box.Text = tostring(default)
        box.Font = Enum.Font.GothamBold
        box.TextSize = 14
        box.ClearTextOnFocus = false
        box.Parent = main
        Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
        Instance.new("UIStroke", box).Color = Color3.fromRGB(0,120,255)
        return box
    end

    speedBox = createRow("Going Speed", 85, goingSpeed)
    stealBox = createRow("Return Speed", 120, returnSpeed)
    jumpBox  = createRow("Jump Power",  155, 60)
    speedBox.Text = tostring(goingSpeed)
    stealBox.Text = tostring(returnSpeed)

    local scActive = (_G._novaScActive == true)
    local speedConnection = nil

    local function applyInput(box, mn, mx, def)
        box.FocusLost:Connect(function()
            local txt = box.Text:match("^%d*%.?%d*") or ""
            local num = math.clamp(tonumber(txt) or def, mn, mx)
            box.Text = tostring(num)
            goingSpeed  = tonumber(speedBox.Text) or 59
            returnSpeed = tonumber(stealBox.Text) or 30
            pcall(saveConfig)
        end)
    end
    applyInput(speedBox, 1, 200, 59)
    applyInput(stealBox, 1, 200, 30)
    applyInput(jumpBox,  1, 200, 60)

    local function applyScActive()
        _G._novaScActive = scActive
        if scActive then
            activate.Text = "ON"
            activate.BackgroundColor3 = Color3.fromRGB(0,120,255)
            if not speedConnection then
                speedConnection = RunService.Heartbeat:Connect(function()
                    if not (character and hrp and hum) then return end
                    goingSpeed  = tonumber(speedBox.Text) or 59
                    returnSpeed = tonumber(stealBox.Text) or 30
                    if fullAutoPlayLeftEnabled or fullAutoPlayRightEnabled then return end
                    if batAimbotEnabled then return end
                    local md = hum.MoveDirection
                    if md.Magnitude > 0 then
                        hrp.AssemblyLinearVelocity = Vector3.new(md.X * goingSpeed, hrp.AssemblyLinearVelocity.Y, md.Z * goingSpeed)
                    end
                end)
            end
        else
            activate.Text = "OFF"
            activate.BackgroundColor3 = Color3.fromRGB(25,25,25)
            if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
        end
        pcall(saveConfig)
    end

    applyScActive()
    activate.MouseButton1Click:Connect(function()
        scActive = not scActive; applyScActive()
    end)

    UserInputService.JumpRequest:Connect(function()
        if not character or not hum or not hrp then return end
        local state = hum:GetState()
        if scActive then
            if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
                local jp = tonumber(jumpBox.Text) or 60
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jp, hrp.AssemblyLinearVelocity.Z)
            end
        end
        if infiniteJumpEnabled then
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 50, hrp.AssemblyLinearVelocity.Z)
        end
    end)
end)

if not ok_sc then warn("[NovaHub] Speed Customizer error: " .. tostring(err_sc)) end

-- ==================== CHARACTER HANDLING ====================
local function onCharacterAdded(char)
    task.wait(0.5)
    setupCharacterRefs(char)
    if batAimbotEnabled then
        task.spawn(function() task.wait(0.8); startBatAimbot() end)
    end
    if autoStealEnabled then startAutoSteal() end
    task.spawn(function() task.wait(0.5); createSpeedDisplay() end)
    if noWalkAnimEnabled then
        local animate = char:FindFirstChild("Animate")
        if animate then animate.Disabled = true end
        local hmLocal = char:FindFirstChildOfClass("Humanoid")
        if hmLocal then
            for _, tr in ipairs(hmLocal:GetPlayingAnimationTracks()) do tr:Stop() end
        end
    end
end

if lp.Character then task.spawn(function() onCharacterAdded(lp.Character) end) end
lp.CharacterAdded:Connect(onCharacterAdded)

-- ==================== SAVE CONFIG ====================
saveConfig = function()
    local data = {}
    data.steal_radius  = STEAL_RADIUS
    data.medusa_radius = MEDUSA_RADIUS
    data.sc_going      = tonumber(speedBox and speedBox.Text) or goingSpeed
    data.sc_return     = tonumber(stealBox and stealBox.Text) or returnSpeed
    data.sc_jump       = tonumber(jumpBox  and jumpBox.Text)  or 60
    data.sc_active     = _G._novaScActive or false
    data.fov_value     = FOV_VALUE
    data.gui_scale     = guiScale
    data.buttons_locked= buttonsLocked

    if toggleBtn     and toggleBtn.Parent     then savedBtnX    = toggleBtn.AbsolutePosition.X;    savedBtnY    = toggleBtn.AbsolutePosition.Y    end
    if mainHubFrame  and mainHubFrame.Parent  then savedHubX    = mainHubFrame.AbsolutePosition.X; savedHubY    = mainHubFrame.AbsolutePosition.Y end
    if fovFrame      and fovFrame.Parent      then savedTopX    = fovFrame.AbsolutePosition.X;     savedTopY    = fovFrame.AbsolutePosition.Y     end
    if batButton     and batButton.Parent     then savedAimbotX = batButton.AbsolutePosition.X;    savedAimbotY = batButton.AbsolutePosition.Y    end
    if tpDownButton  and tpDownButton.Parent  then savedTpDownX = tpDownButton.AbsolutePosition.X; savedTpDownY = tpDownButton.AbsolutePosition.Y end
    if tauntButton   and tauntButton.Parent   then savedTauntX  = tauntButton.AbsolutePosition.X;  savedTauntY  = tauntButton.AbsolutePosition.Y  end
    if dropButton    and dropButton.Parent    then savedDropX   = dropButton.AbsolutePosition.X;   savedDropY   = dropButton.AbsolutePosition.Y   end
    if autoPlayGui then
        local apFrame = autoPlayGui:FindFirstChildOfClass("Frame")
        if apFrame then savedAutoPlayX = apFrame.AbsolutePosition.X; savedAutoPlayY = apFrame.AbsolutePosition.Y end
    end

    if savedBtnX     then data.btn_x      = savedBtnX;     data.btn_y      = savedBtnY     end
    if savedHubX     then data.hub_x      = savedHubX;     data.hub_y      = savedHubY     end
    if savedTopX     then data.top_x      = savedTopX;     data.top_y      = savedTopY     end
    if savedMainX    then data.main_x     = savedMainX;    data.main_y     = savedMainY    end
    if savedAutoPlayX then data.autoPlay_x= savedAutoPlayX; data.autoPlay_y= savedAutoPlayY end
    if savedAimbotX  then data.aimbot_x   = savedAimbotX;  data.aimbot_y   = savedAimbotY  end
    if savedTauntX   then data.taunt_x    = savedTauntX;   data.taunt_y    = savedTauntY   end
    if savedDropX    then data.drop_x     = savedDropX;    data.drop_y     = savedDropY    end
    if savedTpDownX  then data.tpdown_x   = savedTpDownX;  data.tpdown_y   = savedTpDownY  end

    local toggleNames = {}
    for name in pairs(configToggles) do table.insert(toggleNames, name) end
    table.sort(toggleNames)
    for i, name in ipairs(toggleNames) do
        local idx = i - 1
        data["tn_"..idx] = name
        data["tv_"..idx] = configToggles[name]
    end

    pcall(function() writefile(CONFIG_FILE, encodeJSON(data)) end)
end

local _lastSave = 0
RunService.Heartbeat:Connect(function()
    local now = tick()
    if now - _lastSave >= 5 then
        _lastSave = now
        pcall(saveConfig)
    end
end)

print("Nova Hub Loaded")
print("Keybinds: Z = Auto Left | C = Auto Right")
print("Speed display above head shows your current speed")
