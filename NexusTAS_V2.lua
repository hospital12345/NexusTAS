-- NexusTAS V2.0
-- Client-side TAS recorder / player for Solara.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local PLAYER = Players.LocalPlayer
local GENV = (type(getgenv) == "function" and getgenv()) or _G

local VERSION = "2.0.1"
GENV.__NexusDiscord = "https://discord.gg/MTf3F56QH"

-- ==================== UNSUPPORTED GAME GUARD ====================
-- NexusTAS needs a standard R6 character with Roblox's default Animator. If the
-- game uses R15, a custom rig, custom physics or a custom animation system, the
-- recorder cannot work correctly, so show a clear notice and stop.
do
    local function gameTitle()
        local name = ""
        pcall(function() name = game.Name end)
        if name == nil or name == "" then name = "This game" end
        return name
    end

    local gameName = gameTitle()
    local isEternal = false
    pcall(function()
        isEternal = game.GameId == 10760327147 or game.PlaceId == 82754897145520
    end)
    if isEternal then
        gameName = "Eternal Obbying"
    end

    local reason = nil
    if isEternal then
        reason = "This game uses a custom physics engine and character controller."
    end

    if not reason then
        local players = game:GetService("Players")
        local character = players.LocalPlayer.Character
        if not character then
            local deadline = os.clock() + 3
            repeat
                task.wait(0.2)
                character = players.LocalPlayer.Character
            until character or os.clock() >= deadline
        end

        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local r15 = false
            pcall(function()
                r15 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R15
            end)
            if not r15 then
                r15 = character:FindFirstChild("UpperTorso") ~= nil
                    or character:FindFirstChild("LowerTorso") ~= nil
            end

            local customRig = character:FindFirstChild("Torso") == nil
                or character:FindFirstChild("HumanoidRootPart") == nil

            local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
            local animate = character:FindFirstChild("Animate")
            local customAnim = humanoid ~= nil and animator == nil and animate == nil

            local gravity = workspace.Gravity
            local customPhysics = gravity == 0
                or (humanoid ~= nil and humanoid.WalkSpeed <= 0 and humanoid.AutoRotate == false
                    and math.abs(gravity - 196.2) > 1)

            if r15 then
                reason = "This game uses an R15 character rig. NexusTAS currently supports R6 only."
            elseif customRig then
                reason = "This game uses a custom character rig."
            elseif customPhysics then
                reason = "This game uses a custom physics engine or custom movement controller."
            elseif customAnim then
                reason = "This game uses a custom animation system instead of Roblox's default Animator."
            end
        end
    end

    if reason then
        local log = "[NexusTAS] " .. gameName .. ": " .. reason
        warn(log)
        print(log)

        local discordInvite = GENV.__NexusDiscord or ""
        local parent
        pcall(function() parent = gethui and gethui() end)
        if not parent then
            pcall(function() parent = game:GetService("CoreGui") end)
        end
        if not parent then
            parent = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        end

        if parent then
            local old = parent:FindFirstChild("NexusTASUnsupported")
            if old then old:Destroy() end

            local gui = Instance.new("ScreenGui")
            gui.Name = "NexusTASUnsupported"
            gui.IgnoreGuiInset = true
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999999
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 580, 0, 200)
            frame.Position = UDim2.new(0.5, 0, 0, 80)
            frame.AnchorPoint = Vector2.new(0.5, 0)
            frame.BackgroundColor3 = Color3.fromRGB(7, 18, 31)
            frame.BackgroundTransparency = 0
            frame.BorderSizePixel = 0
            frame.Parent = gui

            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.fromRGB(62, 145, 215)
            stroke.Thickness = 1
            stroke.Transparency = 0.15
            stroke.Parent = frame

            local titleBar = Instance.new("Frame")
            titleBar.Size = UDim2.new(1, 0, 0, 34)
            titleBar.BackgroundColor3 = Color3.fromRGB(9, 30, 52)
            titleBar.BackgroundTransparency = 0
            titleBar.BorderSizePixel = 0
            titleBar.ZIndex = 2
            titleBar.Parent = frame

            local title = Instance.new("TextLabel")
            title.BackgroundTransparency = 1
            title.Position = UDim2.new(0, 12, 0, 0)
            title.Size = UDim2.new(1, -52, 1, 0)
            title.Font = Enum.Font.GothamMedium
            title.Text = "NexusTAS V" .. tostring(VERSION)
            title.TextColor3 = Color3.fromRGB(235, 245, 255)
            title.TextSize = 16
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.ZIndex = 3
            title.Parent = titleBar

            local close = Instance.new("TextButton")
            close.Size = UDim2.new(0, 22, 0, 22)
            close.Position = UDim2.new(1, -32, 0, 6)
            close.BackgroundColor3 = Color3.fromRGB(25, 86, 142)
            close.BackgroundTransparency = 0
            close.BorderSizePixel = 0
            close.Font = Enum.Font.GothamBold
            close.Text = "X"
            close.TextColor3 = Color3.fromRGB(235, 245, 255)
            close.TextSize = 12
            close.AutoButtonColor = true
            close.ZIndex = 4
            close.Parent = titleBar

            local accent = Instance.new("Frame")
            accent.Size = UDim2.new(1, 0, 0, 2)
            accent.Position = UDim2.new(0, 0, 0, 34)
            accent.BackgroundColor3 = Color3.fromRGB(62, 145, 215)
            accent.BackgroundTransparency = 0
            accent.BorderSizePixel = 0
            accent.ZIndex = 3
            accent.Parent = frame

            local function addLine(text, y, size, height, color, font)
                local label = Instance.new("TextLabel")
                label.BackgroundTransparency = 1
                label.Size = UDim2.new(1, -40, 0, height)
                label.Position = UDim2.fromOffset(20, y)
                label.Font = font or Enum.Font.Gotham
                label.Text = text
                label.TextColor3 = color
                label.TextSize = size
                label.TextWrapped = true
                label.TextXAlignment = Enum.TextXAlignment.Center
                label.ZIndex = 3
                label.Parent = frame
                return label
            end

            addLine(gameName .. " is not supported right now.", 44, 15, 24,
                Color3.fromRGB(235, 245, 255), Enum.Font.GothamMedium)
            addLine("We are actively working on expanding NexusTAS capabilities.", 72, 12, 22,
                Color3.fromRGB(150, 190, 220))
            addLine("Reason: " .. reason, 100, 12, 44,
                Color3.fromRGB(210, 228, 245))
            local contact = "If you think this is a mistake, please contact us on Discord."
            if discordInvite ~= "" then
                contact = "If you think this is a mistake, contact us on Discord: " .. discordInvite
            end
            addLine(contact, 154, 11, 34,
                Color3.fromRGB(110, 150, 180))

            close.MouseButton1Click:Connect(function()
                gui:Destroy()
            end)

            gui.Parent = parent
            local deadline = os.clock() + 15
            while gui.Parent and os.clock() < deadline do
                task.wait(0.1)
            end
            if gui.Parent then gui:Destroy() end
        else
            task.wait(3)
        end
        return
    end
end

-- Resolve a character without infinite WaitForChild hangs. Some custom rigs
-- have no Animator (or a differently named root), so create one and fall back
-- to Humanoid.RootPart.
local function waitForChildSafe(parent, name, timeout)
    if not parent then return nil end
    local child = parent:FindFirstChild(name)
    if child then return child end
    local deadline = tick() + (timeout or 5)
    while tick() < deadline do
        task.wait(0.1)
        child = parent:FindFirstChild(name)
        if child then return child end
    end
    return nil
end

local function waitForClassSafe(parent, className, timeout)
    if not parent then return nil end
    local child = parent:FindFirstChildOfClass(className)
    if child then return child end
    local deadline = tick() + (timeout or 5)
    while tick() < deadline do
        task.wait(0.1)
        child = parent:FindFirstChildOfClass(className)
        if child then return child end
    end
    return nil
end

local function resolveCharacter(char)
    if not char then return nil end
    local human = waitForClassSafe(char, "Humanoid", 5)
    if not human then return nil end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        pcall(function() root = human.RootPart end)
    end
    if not root then root = char.PrimaryPart end
    if not root then root = waitForChildSafe(char, "HumanoidRootPart", 5) end
    if not root or not root:IsA("BasePart") then return nil end

    local animator = human:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = human
    end
    return root, human, animator
end

-- ==================== RE-INJECT CLEANUP ====================
local function destroyOldGuis()
    local parents = {}
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then parents[#parents + 1] = hui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then parents[#parents + 1] = core end
    local pg = PLAYER:FindFirstChild("PlayerGui")
    if pg then parents[#parents + 1] = pg end
    local names = { "NexusTASLocal", "NexusTASLocalToasts", "NexusTASHUD", "NexusTASImport", "NexusTASLoader", "NexusTASPrompt", "NexusTASFPS", "NexusTASUnsupported" }
    for _, parent in ipairs(parents) do
        for _, name in ipairs(names) do
            local obj = parent:FindFirstChild(name)
            if obj then pcall(function() obj:Destroy() end) end
        end
    end
end

local function cleanupPrevious()
    -- Stop any previous injection without hard-coding its name, so both the
    -- current build and older builds are replaced cleanly on re-inject.
    local stopKeys, connLists = {}, {}
    local seenStops, seenLists = {}, {}
    local function scan(env)
        for key, value in pairs(env) do
            if type(key) == "string" then
                if key:match("^__%a+Shutdown$") and type(value) == "function" then
                    if not seenStops[key] then
                        seenStops[key] = true
                        stopKeys[#stopKeys + 1] = key
                    end
                elseif key:match("^__%a+Connections$") and type(value) == "table" then
                    if not seenLists[value] then
                        seenLists[value] = true
                        connLists[#connLists + 1] = value
                    end
                end
            end
        end
    end
    scan(_G)
    if GENV ~= _G then scan(GENV) end

    for _, key in ipairs(stopKeys) do
        local fn = _G[key] or GENV[key]
        if fn then pcall(fn) end
        _G[key] = nil
        GENV[key] = nil
    end
    for _, list in ipairs(connLists) do
        for _, conn in ipairs(list) do
            pcall(function() conn:Disconnect() end)
        end
    end
    _G.__NexusConnections = nil
    GENV.__NexusConnections = nil
    pcall(function() RunService:UnbindFromRenderStep("NexusTASCamera") end)
    pcall(function() RunService:UnbindFromRenderStep("NexusTASSingleTick") end)
    pcall(function() RunService:UnbindFromRenderStep("NexusTASMenuMouse") end)
    destroyOldGuis()
    for _, name in ipairs({ "NXRuntime", "TASRS" }) do
        local rs = ReplicatedStorage:FindFirstChild(name)
        if rs then pcall(function() rs:Destroy() end) end
    end
end

cleanupPrevious()

-- ==================== STARTUP LOADER ====================
-- A small pre-flight window that works before the character/humanoid exists.
-- It reports what the executor can do and waits for a character if needed.
do
    local showLoader = true
    local cached = GENV.__NexusSettings
    if type(cached) == "table" and type(cached.settings) == "table"
        and cached.settings.showLoader == false then
        showLoader = false
    end
    if showLoader and type(readfile) == "function" and HttpService then
        local candidates = {
            "NexusTAS/settings.json",
            "workspace/NexusTAS/settings.json",
            "./NexusTAS/settings.json",
        }
        for _, path in ipairs(candidates) do
            local ok, raw = pcall(function() return readfile(path) end)
            if ok and type(raw) == "string" and raw ~= "" then
                local okJson, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
                if okJson and type(decoded) == "table" and type(decoded.settings) == "table"
                    and decoded.settings.showLoader == false then
                    showLoader = false
                end
                break
            end
        end
    end

    if not showLoader then
        GENV.__NexusLoader = nil
    end

    if showLoader then
    local parent
    pcall(function() parent = gethui and gethui() end)
    if not parent then
        pcall(function() parent = game:GetService("CoreGui") end)
    end
    if not parent then
        parent = PLAYER:FindFirstChild("PlayerGui")
    end

    if parent then
        local old = parent:FindFirstChild("NexusTASLoader")
        if old then old:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name = "NexusTASLoader"
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.DisplayOrder = 999997
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local TweenService = nil
        pcall(function() TweenService = game:GetService("TweenService") end)

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 560, 0, 300)
        frame.Position = UDim2.new(0.5, 0, 0.5, 0)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundColor3 = Color3.fromRGB(7, 18, 31)
        frame.BackgroundTransparency = 0
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local uiScale = Instance.new("UIScale")
        uiScale.Scale = 0.94
        uiScale.Parent = frame
        if TweenService then
            frame.Position = UDim2.new(0.5, 0, 0.5, 18)
            TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, 0, 0.5, 0),
            }):Play()
            TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Scale = 1,
            }):Play()
        end

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(62, 145, 215)
        stroke.Thickness = 1
        stroke.Transparency = 0.15
        stroke.Parent = frame

        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1, 0, 0, 34)
        titleBar.BackgroundColor3 = Color3.fromRGB(9, 30, 52)
        titleBar.BorderSizePixel = 0
        titleBar.Parent = frame

        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 12, 0, 0)
        title.Size = UDim2.new(1, -52, 1, 0)
        title.Font = Enum.Font.GothamMedium
        title.Text = "NexusTAS Loader V" .. tostring(VERSION)
        title.TextColor3 = Color3.fromRGB(235, 245, 255)
        title.TextSize = 16
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = titleBar

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 22, 0, 22)
        close.Position = UDim2.new(1, -32, 0, 6)
        close.BackgroundColor3 = Color3.fromRGB(25, 86, 142)
        close.BorderSizePixel = 0
        close.Font = Enum.Font.GothamBold
        close.Text = "X"
        close.TextColor3 = Color3.fromRGB(235, 245, 255)
        close.TextSize = 12
        close.Parent = titleBar

        local accent = Instance.new("Frame")
        accent.Size = UDim2.new(1, 0, 0, 2)
        accent.Position = UDim2.new(0, 0, 0, 34)
        accent.BackgroundColor3 = Color3.fromRGB(62, 145, 215)
        accent.BorderSizePixel = 0
        accent.Parent = frame

        local statusLabel = Instance.new("TextLabel")
        statusLabel.BackgroundTransparency = 1
        statusLabel.Position = UDim2.new(0, 16, 0, 44)
        statusLabel.Size = UDim2.new(1, -32, 0, 20)
        statusLabel.Font = Enum.Font.GothamMedium
        statusLabel.Text = "Preparing..."
        statusLabel.TextColor3 = Color3.fromRGB(235, 245, 255)
        statusLabel.TextSize = 13
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.Parent = frame

        local countdownLabel = Instance.new("TextLabel")
        countdownLabel.BackgroundTransparency = 1
        countdownLabel.Position = UDim2.new(1, -92, 0, 42)
        countdownLabel.Size = UDim2.new(0, 72, 0, 24)
        countdownLabel.Font = Enum.Font.GothamBold
        countdownLabel.Text = ""
        countdownLabel.TextColor3 = Color3.fromRGB(62, 145, 215)
        countdownLabel.TextSize = 18
        countdownLabel.TextXAlignment = Enum.TextXAlignment.Right
        countdownLabel.Visible = false
        countdownLabel.Parent = frame

        local logLabel = Instance.new("TextLabel")
        logLabel.BackgroundTransparency = 1
        logLabel.Position = UDim2.new(0, 16, 0, 70)
        logLabel.Size = UDim2.new(1, -32, 0, 160)
        logLabel.Font = Enum.Font.Code
        logLabel.Text = ""
        logLabel.TextColor3 = Color3.fromRGB(160, 200, 225)
        logLabel.TextSize = 11
        logLabel.TextXAlignment = Enum.TextXAlignment.Left
        logLabel.TextYAlignment = Enum.TextYAlignment.Top
        logLabel.TextWrapped = true
        logLabel.Parent = frame

        local barBg = Instance.new("Frame")
        barBg.Position = UDim2.new(0, 16, 1, -64)
        barBg.Size = UDim2.new(1, -32, 0, 4)
        barBg.BackgroundColor3 = Color3.fromRGB(13, 40, 65)
        barBg.BorderSizePixel = 0
        barBg.Parent = frame

        local barFill = Instance.new("Frame")
        barFill.Size = UDim2.new(0, 0, 1, 0)
        barFill.BackgroundColor3 = Color3.fromRGB(62, 145, 215)
        barFill.BorderSizePixel = 0
        barFill.Parent = barBg

        local icon = Instance.new("Frame")
        icon.Size = UDim2.new(0, 24, 0, 24)
        icon.Position = UDim2.new(0, 16, 0, 254)
        icon.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        icon.BorderSizePixel = 0
        icon.Parent = frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = icon
        local iconText = Instance.new("TextLabel")
        iconText.BackgroundTransparency = 1
        iconText.Size = UDim2.new(1, 0, 1, 0)
        iconText.Font = Enum.Font.GothamBold
        iconText.Text = "D"
        iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
        iconText.TextSize = 14
        iconText.Parent = icon

        local join = Instance.new("TextButton")
        join.Position = UDim2.new(0, 48, 0, 252)
        join.Size = UDim2.new(0, 190, 0, 28)
        join.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        join.BorderSizePixel = 0
        join.Font = Enum.Font.GothamMedium
        join.Text = "Join to NexusTAS"
        join.TextColor3 = Color3.fromRGB(255, 255, 255)
        join.TextSize = 12
        join.Parent = frame

        local logs = {}
        local loader = { done = false, counting = false, bootAt = os.clock() }
        function loader.log(text)
            text = tostring(text)
            statusLabel.Text = text
            logs[#logs + 1] = text
            if #logs > 9 then table.remove(logs, 1) end
            logLabel.Text = table.concat(logs, "\n")
        end
        function loader.close()
            loader.done = true
            loader.doneAt = os.clock()
            if gui.Parent then gui:Destroy() end
        end
        function loader.startCountdown()
            if loader.counting or loader.done or not gui.Parent then return end
            loader.counting = true
            loader.countStart = os.clock()
            countdownLabel.Visible = true
            barFill.Size = UDim2.new(0, 0, 1, 0)
            if TweenService then
                TweenService:Create(barFill, TweenInfo.new(5, Enum.EasingStyle.Linear), {
                    Size = UDim2.new(1, 0, 1, 0),
                }):Play()
            else
                barFill.Size = UDim2.new(1, 0, 1, 0)
            end
            task.spawn(function()
                for i = 5, 1, -1 do
                    if not gui.Parent or loader.done then break end
                    statusLabel.Text = "NexusTAS will start in " .. i
                        .. (i == 1 and " second..." or " seconds...")
                    countdownLabel.Text = tostring(i)
                    countdownLabel.TextSize = 22
                    if TweenService then
                        TweenService:Create(countdownLabel,
                            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                            { TextSize = 15 }):Play()
                    end
                    loader.log("Starting in " .. i .. "...")
                    task.wait(1)
                end
                loader.done = true
                loader.doneAt = os.clock()
                if gui.Parent then gui:Destroy() end
            end)
        end
        function loader.wait()
            local deadline = os.clock() + 12
            while not loader.done and os.clock() < deadline do
                task.wait(0.05)
            end
        end
        GENV.__NexusLoader = loader

        close.MouseButton1Click:Connect(loader.close)
        join.MouseButton1Click:Connect(function()
            local invite = GENV.__NexusDiscord
            if type(invite) == "string" and invite ~= "" then
                local opened = false
                pcall(function()
                    opened = game:GetService("GuiService"):OpenBrowserWindow(invite)
                end)
                if opened then
                    loader.log("Opening Discord...")
                else
                    local copied = false
                    if type(setclipboard) == "function" then
                        copied = pcall(setclipboard, invite)
                    end
                    loader.log(copied and "Link copied!" or "Could not copy link")
                end
            else
                loader.log("Discord link is not configured yet")
            end
        end)

        local executor = "?"
        pcall(function()
            local name, version = identifyexecutor()
            executor = tostring(name) .. " " .. tostring(version)
        end)
        loader.log("Executor: " .. executor)
        loader.log("Drawing: " .. ((Drawing and Drawing.new) and "ok" or "missing"))
        loader.log("File API: " .. ((writefile and readfile and listfiles) and "ok" or "missing"))
        loader.log("Character: waiting")
        loader.log("Humanoid: waiting")
        gui.Parent = parent
    end
    end
end

local RUN_ID = (_G.__NexusRunID or 0) + 1
_G.__NexusRunID = RUN_ID
local FORK_ID = 0
_G.__NexusForkID = 0

local CONNECTIONS = {}
_G.__NexusConnections = CONNECTIONS
local function connect(signal, callback)
    local conn = signal:Connect(callback)
    CONNECTIONS[#CONNECTIONS + 1] = conn
    return conn
end

-- ==================== CHARACTER ====================
local CHARACTER = PLAYER.Character
if not CHARACTER then
    local deadline = os.clock() + 30
    while not CHARACTER and os.clock() < deadline do
        if GENV.__NexusLoader then
            GENV.__NexusLoader.log("Waiting for character...")
        end
        task.wait(0.25)
        CHARACTER = PLAYER.Character
    end
end
if not CHARACTER then
    if GENV.__NexusLoader then
        GENV.__NexusLoader.log("No character found.")
        GENV.__NexusLoader.log("Join a game and execute NexusTAS again.")
    end
    return
end
if GENV.__NexusLoader then GENV.__NexusLoader.log("Character: found") end
local ROOT, HUMAN, ANIMATOR = resolveCharacter(CHARACTER)
if not ROOT or not HUMAN then
    warn("[NexusTAS] Unsupported character (Humanoid or root part not found).")
    if GENV.__NexusLoader then GENV.__NexusLoader.log("Humanoid: not found") end
    return
end
if GENV.__NexusLoader then
    GENV.__NexusLoader.log("Humanoid: found")
    local torso = CHARACTER:FindFirstChild("Torso")
    local rig = (torso and torso:FindFirstChild("Right Shoulder")) and "R6" or "R15/custom"
    GENV.__NexusLoader.log("Rig: " .. rig)
end
local ANIMATE_SCRIPT = CHARACTER:FindFirstChild("Animate")

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local originalWalkSpeed = HUMAN.WalkSpeed
if originalWalkSpeed <= 0 then originalWalkSpeed = 16 end
local originalJumpPower = HUMAN.JumpPower
if originalJumpPower <= 0 then originalJumpPower = 50 end
local originalAutoRotate = HUMAN.AutoRotate

local function isR6()
    if not CHARACTER then return false end
    local torso = CHARACTER:FindFirstChild("Torso")
    return torso ~= nil and torso:FindFirstChild("Right Shoulder") ~= nil
end

-- ==================== INPUT DEFAULTS ====================
local CONTROLS = {
    Idle = Enum.KeyCode.One,
    Create = Enum.KeyCode.Two,
    Test = Enum.KeyCode.Three,
    Pause = Enum.UserInputType.MouseButton1,
    Unpause = Enum.UserInputType.MouseButton1,
    Forward = Enum.KeyCode.T,
    Back = Enum.KeyCode.R,
    Forward1F = Enum.KeyCode.G,
    Back1F = Enum.KeyCode.F,
    Unpause1F = Enum.KeyCode.V,
    Return = Enum.KeyCode.E,
    Look = Enum.KeyCode.L,
    Optimize = Enum.KeyCode.Q,
    Delete = Enum.KeyCode.Backspace,
    Menu = Enum.KeyCode.M,
    ShiftLock = Enum.KeyCode.LeftShift,
}

local DEFAULT_CONTROLS = {}
for k, v in pairs(CONTROLS) do DEFAULT_CONTROLS[k] = v end

local KEY_NUM = {
    One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
    Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
}

local function keyName(bind)
    if not bind then return "?" end
    local name = bind.Name
    if name then
        if name == "MouseButton1" then return "Left Click" end
        if name == "MouseButton2" then return "Right Click" end
        if name == "MouseButton3" then return "Middle Click" end
        return KEY_NUM[name] or name
    end
    return tostring(bind)
end

local CONTROL_LABELS = {
    Idle = "Idle",
    Create = "Create",
    Test = "Test",
    Pause = "Pause",
    Unpause = "Unpause",
    Forward = "Forward",
    Back = "Back",
    Forward1F = "Forward 1 Frame",
    Back1F = "Back 1 Frame",
    Unpause1F = "Unpause 1 Frame",
    Return = "Return",
    Look = "Look Around",
    Optimize = "Optimize TAS",
    Delete = "Delete TAS",
    Menu = "Menu",
}

local function bindConflictFor(key)
    local bind = CONTROLS[key]
    if bind == nil then return nil end
    local names = {}
    for other, otherBind in pairs(CONTROLS) do
        if other ~= key and other ~= "ShiftLock" and otherBind == bind then
            local allowedPair = (key == "Pause" and other == "Unpause")
                or (key == "Unpause" and other == "Pause")
            if not allowedPair then
                names[#names + 1] = CONTROL_LABELS[other] or other
            end
        end
    end
    if #names > 0 then return table.concat(names, ", ") end
    return nil
end

local function findBindConflicts()
    local groups, order = {}, {}
    for key, bind in pairs(CONTROLS) do
        if key ~= "ShiftLock" then
            local id = tostring(bind)
            if not groups[id] then
                groups[id] = {}
                order[#order + 1] = id
            end
            table.insert(groups[id], key)
        end
    end
    local result = {}
    for _, id in ipairs(order) do
        local keys = groups[id]
        if #keys > 1 then
            local onlyPause = (#keys == 2)
                and ((keys[1] == "Pause" and keys[2] == "Unpause")
                    or (keys[1] == "Unpause" and keys[2] == "Pause"))
            if not onlyPause then
                local names = {}
                for _, k in ipairs(keys) do
                    names[#names + 1] = CONTROL_LABELS[k] or k
                end
                table.insert(result,
                    keyName(CONTROLS[keys[1]]) .. ": " .. table.concat(names, ", "))
            end
        end
    end
    return result
end

local settings = {
    lockCamPaused = true,
    lockCamTest = true,
    interpolate = true,
    playbackSpeed = 1,
    showStats = true,
    restartTesting = true,
    statsSize = 11,
    ghostMode = false,
    safeTest = false,
    showLoader = true,
    theme = "Midnight",
    relativeTest = false,
    yOffset = 0,
}

-- ==================== RUNTIME BINDABLES ====================
-- Recreated on Ghost Mode swaps so an old Animate fork cannot keep receiving
-- SetAnimation/LockAnimations events for a character that is no longer active.
local TASRS, BE, BF
local SetAnimation, LockAnimations, ShiftlockSwitch, LockShiftlock
local SetZoom, RemoveZoomSpring, ShiftlockRotation, SetTAS
local GetAnimation, GetZoom, GetTAS

local function makeEvent(name)
    local e = Instance.new("BindableEvent", BE)
    e.Name = name
    return e
end
local function makeFunction(name)
    local f = Instance.new("BindableFunction", BF)
    f.Name = name
    return f
end

-- ==================== RUN STATE ====================
local mode = "idle"          -- idle / create / test
local paused = true
local data = {}
local frame = 1
local lastPauseFrame = 1
local firstFrameRecord = false
local lastFrameTime = 1 / 60
local testingTimer = 0
local playbackOffset = nil
local freezeTimeRemaining = 0
local lookAround = false
local confirmDelete = false
local confirmOptimize = false
local backHeld = false
local forwHeld = false
local cameraTarget = nil
local cameraFollow = false
local shiftLockLocked = false
local statusText = "Ready"
local popupText = ""
local popupUntil = 0
local animAvailable = false
local drawMenuVisible = false
local drawTab = "player"
local searchQuery = ""
local searchActive = false
local themeMenuOpen = false
local folderMenuOpen = false
local drawHits = {}
local drawMenuX, drawMenuY
local bindingControl = nil
local ghost = {
    active = false,
    lastJump = false,
    swapped = false,
    noMoveFrames = 0,
    mirrorControls = false,
    ignoreChars = setmetatable({}, { __mode = "k" }),
}
local safeTest = {
    waiting = false,
    aligning = false,
    frame = nil,
    alignStart = 0,
}

local function cancelSafeTest()
    safeTest.waiting = false
    safeTest.aligning = false
    safeTest.frame = nil
end
local enterGhost, exitGhost, updateGhost

-- Small read-only debug surface (useful for external tooling / smoke tests).
_G.__NexusDebug = {
    frames = function() return #data end,
    index = function() return frame end,
    mode = function() return mode end,
    paused = function() return paused end,
    speed = function() return settings.playbackSpeed end,
    setSpeed = function(n) settings.playbackSpeed = math.clamp(tonumber(n) or 1, 0.1, 4) end,
    popup = function() return popupText end,
    menu = function() return drawMenuVisible end,
    ghost = function() return ghost.active end,
    setGhost = function(v) settings.ghostMode = v and true or false end,
    setSafeTest = function(v) settings.safeTest = v and true or false end,
    safeWaiting = function() return safeTest.waiting end,
    safeEnabled = function() return settings.safeTest end,
    ghostInfo = function()
        if not ghost.active then return "off" end
        local h, r = ghost.cloneHuman, ghost.cloneRoot
        if not h or not r then return "clone missing" end
        return string.format(
            "state=%s anchored=%s walk=%.1f jump=%.1f rootPart=%s swapped=%s mirror=%s dir=%.2f vel=%.1f pos=(%.1f, %.1f, %.1f)",
            tostring(h:GetState()), tostring(r.Anchored),
            h.WalkSpeed, h.JumpPower,
            (h.RootPart and "yes" or "nil"),
            tostring(ghost.swapped == true),
            tostring(ghost.mirrorControls == true),
            h.MoveDirection.Magnitude,
            r.AssemblyLinearVelocity.Magnitude,
            r.Position.X, r.Position.Y, r.Position.Z)
    end,
}

local function setStatus(text)
    statusText = tostring(text)
end

local function popup(text, duration)
    popupText = tostring(text)
    popupUntil = tick() + (duration or 2.5)
end

local function round(n, d)
    local v = math.round(n * d) / d
    if v == -0 then v = 0 end
    return v
end

local function timeString(t)
    local secs = t - (t - t % 60)
    local mins = (t - t % 60) / 60
    return tostring(math.floor(mins)) .. ":" .. string.format("%06.3f", secs)
end

local function charLoaded()
    return CHARACTER and CHARACTER.Parent ~= nil
        and HUMAN and HUMAN.Parent ~= nil
        and ROOT and ROOT.Parent ~= nil
end

local function notDead()
    return HUMAN and HUMAN:GetState() ~= Enum.HumanoidStateType.Dead
end

local function anchor(value)
    if ROOT then ROOT.Anchored = value end
    if HUMAN then HUMAN.AutoRotate = (not value) end
    -- Let the camera rotate the character only while playing/recording.
    if value then
        pcall(function() HUMAN:ChangeState(HUMAN:GetState()) end)
    end
end

-- ==================== SHIFT LOCK ====================
local PLAYER_MOUSE = nil
pcall(function() PLAYER_MOUSE = PLAYER:GetMouse() end)

local function isShiftLocked()
    local mouse = PLAYER_MOUSE
    if mouse and mouse.Icon == "rbxasset://textures/MouseLockedCursor.png" then
        return true
    end
    return UIS.MouseBehavior == Enum.MouseBehavior.LockCenter
end

local lastShiftTry = 0
local lastShiftWant = nil

local function setShiftLock(desired, force)
    if shiftLockLocked and not force then return end
    if isShiftLocked() == desired then return end
    if lastShiftWant == desired and tick() - lastShiftTry < 0.2 then return end
    lastShiftTry = tick()
    lastShiftWant = desired
    if not VIM then return end
    local bind = CONTROLS.ShiftLock
    task.spawn(function()
        pcall(function() VIM:SendKeyEvent(true, bind, false, game) end)
        task.wait(0.05)
        pcall(function() VIM:SendKeyEvent(false, bind, false, game) end)
    end)
end

-- ==================== CAMERA ====================
local function camZoom()
    local cam = workspace.CurrentCamera
    if not cam then return 0 end
    local d = (cam.CFrame.Position - cam.Focus.Position).Magnitude
    if d and d > 0.01 then return d end
    return 0
end

local function setCameraOverride(target)
    cameraTarget = target
end

local function cameraShouldLock()
    if safeTest.waiting then return false end
    if cameraFollow then return false end
    if lookAround and mode == "create" and paused then return false end
    if mode == "test" then return settings.lockCamTest end
    if mode == "create" and paused then return settings.lockCamPaused end
    return false
end

local renderCamera = function()
    if not cameraTarget then return end
    if not cameraShouldLock() then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    pcall(function() cam.CFrame = cameraTarget.cf end)
    pcall(function() cam.FieldOfView = cameraTarget.fov end)
    if cameraTarget.shift ~= nil and cameraTarget.shift ~= isShiftLocked() then
        setShiftLock(cameraTarget.shift, true)
    end
end
RunService:BindToRenderStep("NexusTASCamera", Enum.RenderPriority.Camera.Value + 20, renderCamera)

-- ==================== ANIMATE FORK ====================
-- The R6 Animate fork. It is executed with the real Animate
-- instance as `script`, so all of its config/PlayEmote lookups keep working.
local ANIMATE_SOURCE = [==[
-- humanoidAnimatePlayEmote.lua
-- TAS variables
local FrameAnims = {}
local LockAnimations = false

local Figure = script.Parent
local Torso = Figure:WaitForChild("Torso")
local RightShoulder = Torso:WaitForChild("Right Shoulder")
local LeftShoulder = Torso:WaitForChild("Left Shoulder")
local RightHip = Torso:WaitForChild("Right Hip")
local LeftHip = Torso:WaitForChild("Left Hip")
local Neck = Torso:WaitForChild("Neck")
local Humanoid = Figure:WaitForChild("Humanoid")
local pose = "Standing"

local EMOTE_TRANSITION_TIME = 0.1

local userAnimateScaleRunSuccess, userAnimateScaleRunValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserAnimateScaleRun") end)
local userAnimateScaleRun = userAnimateScaleRunSuccess and userAnimateScaleRunValue

local function getRigScale()
	if userAnimateScaleRun then
		return Figure:GetScale()
	else
		return 1
	end
end

local currentAnim = ""
local currentAnimInstance = nil
local currentAnimTrack = nil
local currentAnimKeyframeHandler = nil
local currentAnimSpeed = 1.0
local animTable = {}
local animNames = { 
	idle = 	{	
				{ id = "http://www.roblox.com/asset/?id=180435571", weight = 9 },
				{ id = "http://www.roblox.com/asset/?id=180435792", weight = 1 }
			},
	walk = 	{ 	
				{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 } 
			}, 
	run = 	{
				{ id = "run.xml", weight = 10 } 
			}, 
	jump = 	{
				{ id = "http://www.roblox.com/asset/?id=125750702", weight = 10 } 
			}, 
	fall = 	{
				{ id = "http://www.roblox.com/asset/?id=180436148", weight = 10 } 
			}, 
	climb = {
				{ id = "http://www.roblox.com/asset/?id=180436334", weight = 10 } 
			}, 
	sit = 	{
				{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 } 
			},	
	toolnone = {
				{ id = "http://www.roblox.com/asset/?id=182393478", weight = 10 } 
			},
	toolslash = {
				{ id = "http://www.roblox.com/asset/?id=129967390", weight = 10 } 
--				{ id = "slash.xml", weight = 10 } 
			},
	toollunge = {
				{ id = "http://www.roblox.com/asset/?id=129967478", weight = 10 } 
			},
	wave = {
				{ id = "http://www.roblox.com/asset/?id=128777973", weight = 10 } 
			},
	point = {
				{ id = "http://www.roblox.com/asset/?id=128853357", weight = 10 } 
			},
	dance1 = {
				{ id = "http://www.roblox.com/asset/?id=182435998", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491037", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491065", weight = 10 } 
			},
	dance2 = {
				{ id = "http://www.roblox.com/asset/?id=182436842", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491248", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491277", weight = 10 } 
			},
	dance3 = {
				{ id = "http://www.roblox.com/asset/?id=182436935", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491368", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491423", weight = 10 } 
			},
	laugh = {
				{ id = "http://www.roblox.com/asset/?id=129423131", weight = 10 } 
			},
	cheer = {
				{ id = "http://www.roblox.com/asset/?id=129423030", weight = 10 } 
			},
}
local dances = {"dance1", "dance2", "dance3"}

-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
local emoteNames = { wave = false, point = false, dance1 = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

function configureAnimationSet(name, fileList)
	if (animTable[name] ~= nil) then
		for _, connection in pairs(animTable[name].connections) do
			connection:disconnect()
		end
	end
	animTable[name] = {}
	animTable[name].count = 0
	animTable[name].totalWeight = 0	
	animTable[name].connections = {}

	-- check for config values
	local config = script:FindFirstChild(name)
	if (config ~= nil) then
--		print("Loading anims " .. name)
		table.insert(animTable[name].connections, config.ChildAdded:connect(function(child) configureAnimationSet(name, fileList) end))
		table.insert(animTable[name].connections, config.ChildRemoved:connect(function(child) configureAnimationSet(name, fileList) end))
		local idx = 1
		for _, childPart in pairs(config:GetChildren()) do
			if (childPart:IsA("Animation")) then
				table.insert(animTable[name].connections, childPart.Changed:connect(function(property) configureAnimationSet(name, fileList) end))
				animTable[name][idx] = {}
				animTable[name][idx].anim = childPart
				local weightObject = childPart:FindFirstChild("Weight")
				if (weightObject == nil) then
					animTable[name][idx].weight = 1
				else
					animTable[name][idx].weight = weightObject.Value
				end
				animTable[name].count = animTable[name].count + 1
				animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
	--			print(name .. " [" .. idx .. "] " .. animTable[name][idx].anim.AnimationId .. " (" .. animTable[name][idx].weight .. ")")
				idx = idx + 1
			end
		end
	end

	-- fallback to defaults
	if (animTable[name].count <= 0) then
		for idx, anim in pairs(fileList) do
			animTable[name][idx] = {}
			animTable[name][idx].anim = Instance.new("Animation")
			animTable[name][idx].anim.Name = name
			animTable[name][idx].anim.AnimationId = anim.id
			animTable[name][idx].weight = anim.weight
			animTable[name].count = animTable[name].count + 1
			animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
--			print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")
		end
	end
end

-- Setup animation objects
function scriptChildModified(child)
	local fileList = animNames[child.Name]
	if (fileList ~= nil) then
		configureAnimationSet(child.Name, fileList)
	end	
end

script.ChildAdded:connect(scriptChildModified)
script.ChildRemoved:connect(scriptChildModified)

-- Clear any existing animation tracks
-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
if animator then
	local animTracks = animator:GetPlayingAnimationTracks()
	for i,track in ipairs(animTracks) do
		track:Stop(0)
		track:Destroy()
	end
end


for name, fileList in pairs(animNames) do 
	configureAnimationSet(name, fileList)
end	

-- ANIMATION

-- declarations
local toolAnim = "None"
local toolAnimTime = 0

local jumpAnimTime = 0
local jumpAnimDuration = 0.3

local toolTransitionTime = 0.1
local fallTransitionTime = 0.3
local jumpMaxLimbVelocity = 0.75

-- functions

function stopAllAnimations()
	local oldAnim = currentAnim

	-- return to idle if finishing an emote
	if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
		oldAnim = "idle"
	end

	currentAnim = ""
	currentAnimInstance = nil
	if (currentAnimKeyframeHandler ~= nil) then
		currentAnimKeyframeHandler:disconnect()
	end

	if (currentAnimTrack ~= nil) then
		currentAnimTrack:Stop()
		currentAnimTrack:Destroy()
		currentAnimTrack = nil
	end
	return oldAnim
end

function setAnimationSpeed(speed,TASanim)
	if (speed ~= currentAnimSpeed and LockAnimations == false) or TASanim then
		currentAnimSpeed = speed
		currentAnimTrack:AdjustSpeed(currentAnimSpeed)
	end
end

function keyFrameReachedFunc(frameName)
	if (frameName == "End") then

		local repeatAnim = currentAnim
		-- return to idle if finishing an emote
		if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
			repeatAnim = "idle"
		end
		
		local animSpeed = currentAnimSpeed
		playAnimation(repeatAnim, 0.0, Humanoid)
		setAnimationSpeed(animSpeed, false)
	end
end

local AnimToNumber = {
	['idle'] = 1,
	['walk'] = 2,
	['fall'] = 3,
	['jump'] = 4,
	['climb'] = 5,
	['sit'] = 6,
	['dance'] = 7,
	['dance2'] = 8,
	['dance3'] = 9,
	['wave'] = 10,
	['cheer'] = 11,
	['point'] = 12,
	['laugh'] = 13
}

local NumberToAnim = {
	'idle',
	'walk',
	'fall',
	'jump',
	'climb',
	'sit',
	'dance',
	'dance2',
	'dance3',
	'wave',
	'cheer',
	'point',
	'laugh'
}

-- Preload animations
function playAnimation(animName, transitionTime, humanoid, TASanim)
	if (not TASanim and LockAnimations) then
		return
	end
	
	local roll = math.random(1, animTable[animName].totalWeight) 
	local origRoll = roll
	local idx = 1
	while (roll > animTable[animName][idx].weight) do
		roll = roll - animTable[animName][idx].weight
		idx = idx + 1
	end
--		print(animName .. " " .. idx .. " [" .. origRoll .. "]")
	local anim = animTable[animName][idx].anim

	-- switch animation		
	if (anim ~= currentAnimInstance) then
		
		if not TASanim then
			table.insert(FrameAnims,{AnimToNumber[animName],transitionTime})
		end
		
		if (currentAnimTrack ~= nil) then
			currentAnimTrack:Stop(transitionTime)
			currentAnimTrack:Destroy()
		end

		currentAnimSpeed = 1.0
	
		-- load it to the humanoid; get AnimationTrack
		currentAnimTrack = humanoid:LoadAnimation(anim)
		currentAnimTrack.Priority = Enum.AnimationPriority.Core
		 
		-- play the animation
		currentAnimTrack:Play(transitionTime)
		currentAnim = animName
		currentAnimInstance = anim

		-- set up keyframe name triggers
		if (currentAnimKeyframeHandler ~= nil) then
			currentAnimKeyframeHandler:disconnect()
		end
		currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:connect(keyFrameReachedFunc)
		
	end

end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------

local toolAnimName = ""
local toolAnimTrack = nil
local toolAnimInstance = nil
local currentToolAnimKeyframeHandler = nil

function toolKeyFrameReachedFunc(frameName)
	if (frameName == "End") then
--		print("Keyframe : ".. frameName)	
		playToolAnimation(toolAnimName, 0.0, Humanoid)
	end
end


function playToolAnimation(animName, transitionTime, humanoid, priority)	 
		
		local roll = math.random(1, animTable[animName].totalWeight) 
		local origRoll = roll
		local idx = 1
		while (roll > animTable[animName][idx].weight) do
			roll = roll - animTable[animName][idx].weight
			idx = idx + 1
		end
--		print(animName .. " * " .. idx .. " [" .. origRoll .. "]")
		local anim = animTable[animName][idx].anim

		if (toolAnimInstance ~= anim) then
			
			if (toolAnimTrack ~= nil) then
				toolAnimTrack:Stop()
				toolAnimTrack:Destroy()
				transitionTime = 0
			end
					
			-- load it to the humanoid; get AnimationTrack
			toolAnimTrack = humanoid:LoadAnimation(anim)
			if priority then
				toolAnimTrack.Priority = priority
			end
			 
			-- play the animation
			toolAnimTrack:Play(transitionTime)
			toolAnimName = animName
			toolAnimInstance = anim

			currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:connect(toolKeyFrameReachedFunc)
		end
end

function stopToolAnimations()
	local oldAnim = toolAnimName

	if (currentToolAnimKeyframeHandler ~= nil) then
		currentToolAnimKeyframeHandler:disconnect()
	end

	toolAnimName = ""
	toolAnimInstance = nil
	if (toolAnimTrack ~= nil) then
		toolAnimTrack:Stop()
		toolAnimTrack:Destroy()
		toolAnimTrack = nil
	end


	return oldAnim
end

-------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------


function onRunning(speed)
	speed /= getRigScale()
	
	if speed > 0.01 then
		playAnimation("walk", 0.1, Humanoid)
		if currentAnimInstance and currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
			setAnimationSpeed(speed / 14.5, false)
		end
		pose = "Running"
	else
		if emoteNames[currentAnim] == nil then
			playAnimation("idle", 0.1, Humanoid)
			pose = "Standing"
		end
	end
end

function onDied()
	pose = "Dead"
end

function onJumping()
	playAnimation("jump", 0.1, Humanoid)
	jumpAnimTime = jumpAnimDuration
	pose = "Jumping"
end

function onClimbing(speed)
	speed /= getRigScale()
	
	playAnimation("climb", 0.1, Humanoid)
	setAnimationSpeed(speed / 12.0, false)
	pose = "Climbing"
end

function onGettingUp()
	pose = "GettingUp"
end

function onFreeFall()
	if (jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	end
	pose = "FreeFall"
end

function onFallingDown()
	pose = "FallingDown"
end

function onSeated()
	pose = "Seated"
end

function onPlatformStanding()
	pose = "PlatformStanding"
end

function onSwimming(speed)
	if speed > 0 then
		pose = "Running"
	else
		pose = "Standing"
	end
end

function getTool()	
	for _, kid in ipairs(Figure:GetChildren()) do
		if kid.className == "Tool" then return kid end
	end
	return nil
end

function getToolAnim(tool)
	for _, c in ipairs(tool:GetChildren()) do
		if c.Name == "toolanim" and c.className == "StringValue" then
			return c
		end
	end
	return nil
end

function animateTool()
	
	if (toolAnim == "None") then
		playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
		return
	end

	if (toolAnim == "Slash") then
		playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end

	if (toolAnim == "Lunge") then
		playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
		return
	end
end

function moveSit()
	RightShoulder.MaxVelocity = 0.15
	LeftShoulder.MaxVelocity = 0.15
	RightShoulder:SetDesiredAngle(3.14 /2)
	LeftShoulder:SetDesiredAngle(-3.14 /2)
	RightHip:SetDesiredAngle(3.14 /2)
	LeftHip:SetDesiredAngle(-3.14 /2)
end

local lastTick = 0

function move(time)
	local amplitude = 1
	local frequency = 1
  	local deltaTime = time - lastTick
  	lastTick = time

	local climbFudge = 0
	local setAngles = false

  	--if (jumpAnimTime > 0) then
  	--	jumpAnimTime = jumpAnimTime - deltaTime
  	--end

	if (pose == "FreeFall" and jumpAnimTime <= 0) then
		playAnimation("fall", fallTransitionTime, Humanoid)
	elseif (pose == "Seated") then
		playAnimation("sit", 0.5, Humanoid)
		return
	elseif (pose == "Running") then
		playAnimation("walk", 0.1, Humanoid)
	elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding") then
--		print("Wha " .. pose)
		stopAllAnimations()
		amplitude = 0.1
		frequency = 1
		setAngles = true
	end

	if (setAngles) then
		local desiredAngle = amplitude * math.sin(time * frequency)

		RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
		LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
		RightHip:SetDesiredAngle(-desiredAngle)
		LeftHip:SetDesiredAngle(-desiredAngle)
	end

	-- Tool Animation handling
	local tool = getTool()
	if tool and tool:FindFirstChild("Handle") then
	
		local animStringValueObject = getToolAnim(tool)

		if animStringValueObject then
			toolAnim = animStringValueObject.Value
			-- message recieved, delete StringValue
			animStringValueObject.Parent = nil
			toolAnimTime = time + .3
		end

		if time > toolAnimTime then
			toolAnimTime = 0
			toolAnim = "None"
		end

		animateTool()		
	else
		stopToolAnimations()
		toolAnim = "None"
		toolAnimInstance = nil
		toolAnimTime = 0
	end
end

-- connect events
Humanoid.Died:connect(onDied)
Humanoid.Running:connect(onRunning)
Humanoid.Jumping:connect(onJumping)
Humanoid.Climbing:connect(onClimbing)
Humanoid.GettingUp:connect(onGettingUp)
Humanoid.FreeFalling:connect(onFreeFall)
Humanoid.FallingDown:connect(onFallingDown)
Humanoid.Seated:connect(onSeated)
Humanoid.PlatformStanding:connect(onPlatformStanding)
Humanoid.Swimming:connect(onSwimming)

---- setup emote chat hook
game:GetService("Players").LocalPlayer.Chatted:connect(function(msg)
	local emote = ""
	if msg == "/e dance" then
		emote = dances[math.random(1, #dances)]
	elseif (string.sub(msg, 1, 3) == "/e ") then
		emote = string.sub(msg, 4)
	elseif (string.sub(msg, 1, 7) == "/emote ") then
		emote = string.sub(msg, 8)
	end
	
	if (pose == "Standing" and emoteNames[emote] ~= nil) then
		playAnimation(emote, 0.1, Humanoid)
	end

end)

-- emote bindable hook
script:WaitForChild("PlayEmote").OnInvoke = function(emote)
	-- Only play emotes when idling
	if pose ~= "Standing" then
		return
	end
	if emoteNames[emote] ~= nil then
		-- Default emotes
		playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)

		return true, currentAnimTrack
	end

	-- Return false to indicate that the emote could not be played
	return false
end

local PoseToNumber = {
	['Running'] = 1,
	['Standing'] = 2,
	['Jumping'] = 3,
	['Climbing'] = 4,
	['GettingUp'] = 5,
	['FreeFall'] = 6,
	['FallingDown'] = 7,
	['Seated'] = 8,
	['PlatformStanding'] = 9,
}

local NumberToPose = {
	'Running',
	'Standing',
	'Jumping',
	'Climbing',
	'GettingUp',
	'FreeFall',
	'FallingDown',
	'Seated',
	'PlatformStanding'
}
-- main program

game.ReplicatedStorage.NXRuntime.BindableFunctions.GetAnimation.OnInvoke = function(StartOfTAS)
	if currentAnimTrack ~= nil then
		return {
			Pose = PoseToNumber[pose] or 0,
			JumpTime = math.round(jumpAnimTime*1000)/1000,
			Speed = math.round(currentAnimSpeed*1000)/1000,
			Anims = StartOfTAS and {{AnimToNumber[currentAnim],0}} or FrameAnims
		}
	end
	return nil
end

game.ReplicatedStorage.NXRuntime.BindableEvents.SetAnimation.Event:Connect(function(AnimData,anim,PlaybackSpeed, TimeDifference)
	if anim then
		for _,v in pairs(anim) do
			if NumberToAnim[v[1]] ~= currentAnim then
				playAnimation(NumberToAnim[v[1]],v[2],Humanoid,true)
			end
		end
	end
	
	pose = NumberToPose[AnimData.Pose]
	jumpAnimTime = AnimData.JumpTime
	setAnimationSpeed(AnimData.Speed * (PlaybackSpeed or 1),true)
	if TimeDifference then
		currentAnimTrack.TimePosition = TimeDifference
	else
		
		--currentAnimTrack.TimePosition = 0
	end
end)

game.ReplicatedStorage.NXRuntime.BindableEvents.LockAnimations.Event:Connect(function(lock)
	LockAnimations = lock
end)

-- initialize to idle
playAnimation("idle", 0.1, Humanoid)
pose = "Standing"

game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
	FrameAnims = {}
	if (jumpAnimTime > 0) then
		jumpAnimTime = jumpAnimTime - deltaTime
	end
end)

while Figure.Parent ~= nil do
	local _, time = wait(0.1)
	move(time)
end

]==]

local function setupAnimateFork()
    if not ANIMATE_SCRIPT or not isR6() then
        animAvailable = false
        return
    end
    animAvailable = true
    pcall(function() ANIMATE_SCRIPT.Disabled = true end)
    -- Stop tracks produced by the default Animate before the fork takes over.
    pcall(function()
        for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
    end)

    -- The fork sets PlayEmote.OnInvoke, so it must be a BindableFunction.
    local playEmote = ANIMATE_SCRIPT:FindFirstChild("PlayEmote")
    if playEmote and not playEmote:IsA("BindableFunction") then
        pcall(function() playEmote:Destroy() end)
        playEmote = nil
    end
    if not playEmote then
        playEmote = Instance.new("BindableFunction")
        playEmote.Name = "PlayEmote"
        playEmote.Parent = ANIMATE_SCRIPT
    end

    FORK_ID += 1
    _G.__NexusForkID = FORK_ID
    local src = ANIMATE_SOURCE:gsub(
        "while Figure%.Parent ~= nil do",
        "while Figure.Parent ~= nil and _G.__NexusRunID == " .. tostring(RUN_ID)
            .. " and _G.__NexusForkID == " .. tostring(FORK_ID) .. " do")
    local fn, err = loadstring("local script = ...\n" .. src, "NexusAnimateFork")
    if not fn then
        warn("[NexusTAS] Animate fork compile error: " .. tostring(err))
        animAvailable = false
        return
    end
    -- Isolate the fork's globals per run when setfenv is available, so a
    -- re-injected instance cannot fight the previous fork through shared globals.
    if setfenv and getfenv then
        pcall(function()
            local env = setmetatable({}, { __index = getfenv() })
            setfenv(fn, env)
        end)
    end
    task.spawn(function()
        local ok, err2 = pcall(fn, ANIMATE_SCRIPT)
        if not ok then
            warn("[NexusTAS] Animate fork error: " .. tostring(err2))
            animAvailable = false
        end
    end)
end

-- ==================== FRAME HELPERS ====================
local function captureAnims(startOfTAS)
    if not animAvailable then return nil end
    local ok, result = pcall(function() return GetAnimation:Invoke(startOfTAS and true or false) end)
    if ok then return result end
    return nil
end

local function animAtStart()
    if not animAvailable then return nil end
    local ok, result = pcall(function() return GetAnimation:Invoke(true) end)
    if ok then return result end
    return nil
end

local function buildFrame()
    local cam = workspace.CurrentCamera
    local f = {
        cf = ROOT.CFrame,
        vel = ROOT.AssemblyLinearVelocity,
        ang = ROOT.AssemblyAngularVelocity,
        state = HUMAN:GetState(),
        camCFrame = cam and cam.CFrame or CFrame.new(),
        camFOV = cam and cam.FieldOfView or 70,
        zoom = camZoom(),
        shiftLock = isShiftLocked(),
        anim = animAtStart(),
        dt = 0,
        t = 0,
    }
    return f
end

local function shiftCF(cf)
    if not cf then return cf end
    local yOffset = 0
    if mode == "test" then
        yOffset = tonumber(settings.yOffset) or 0
    end
    if not playbackOffset and yOffset == 0 then return cf end
    local p = cf.Position
    local ox = playbackOffset and playbackOffset.X or 0
    local oy = (playbackOffset and playbackOffset.Y or 0) - yOffset
    local oz = playbackOffset and playbackOffset.Z or 0
    local ok, shifted = pcall(function()
        local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
        return CFrame.new(
            p.X + ox, p.Y + oy, p.Z + oz,
            r00, r01, r02, r10, r11, r12, r20, r21, r22)
    end)
    if ok and shifted then return shifted end
    return cf
end

local function applyPose(f, interpolateOnlyCam)
    if not f then return end
    pcall(function() ROOT.CFrame = shiftCF(f.cf) end)
    pcall(function()
        ROOT.AssemblyLinearVelocity = f.vel
        ROOT.AssemblyAngularVelocity = f.ang
    end)
    if HUMAN and f.state then
        pcall(function() HUMAN:ChangeState(f.state) end)
    end
    if not interpolateOnlyCam then
        setCameraOverride({
            cf = shiftCF(f.camCFrame), fov = f.camFOV, shift = f.shiftLock, zoom = f.zoom,
        })
    end
end

local function fireAnimation(f, anims, speed, timeDiff)
    if not animAvailable or not f or not f.anim then return end
    local list = anims or f.anim.Anims or {}
    pcall(function() SetAnimation:Fire(f.anim, list, speed or 1, timeDiff) end)
end

local function findBacktrack()
    local backAnim, backSpeed, animTime
    if frame > 2 and mode == "create" then
        local accumulated = 0
        for i = frame, 1, -1 do
            local fd = data[i]
            if not fd or not fd.anim then break end
            accumulated += (fd.dt or 0) * (fd.anim.Speed or 1)
            local anims = fd.anim.Anims
            if anims and #anims > 0 then
                if backAnim and backAnim[1][1] ~= anims[#anims][1] then
                    break
                end
                backAnim = { anims[#anims] }
                backSpeed = fd.anim.Speed or 1
                animTime = accumulated
                break
            end
        end
    end
    return backAnim, backSpeed, animTime
end

local function loadFrame(f, unpausing, backtrack)
    if not f then return end
    if not unpausing then
        anchor(true)
        applyPose(f)
    else
        lastPauseFrame = frame
        anchor(false)
        applyPose(f)
        setCameraOverride({
            cf = f.camCFrame, fov = f.camFOV, shift = f.shiftLock, zoom = f.zoom,
        })
    end

    local backAnim, backSpeed, animTime = nil, nil, nil
    if backtrack then
        backAnim, backSpeed, animTime = findBacktrack()
    end
    if f.anim then
        local list = backAnim or f.anim.Anims or {}
        local speed = 0
        if unpausing then
            speed = backSpeed or 1
        end
        fireAnimation(f, list, speed, backtrack and animTime or nil)
    end
end

local function removeCutFrames()
    for i = #data, frame + 1, -1 do
        data[i] = nil
    end
end

local function trimIncomplete()
    while #data > 0 and data[#data].cf == nil do
        data[#data] = nil
    end
    if #data == 0 then frame = 0 else frame = math.clamp(frame, 1, #data) end
end

local function recomputeTimes()
    local total = 0
    for i, f in ipairs(data) do
        total = total + (f.dt or (1 / 60))
        f.t = total
    end
end

-- ==================== MODES ====================
local function goIdle(keepMenu)
    if ghost.active and exitGhost then exitGhost() end
    playbackOffset = nil
    cancelSafeTest()
    bindingControl = nil
    if not keepMenu then drawMenuVisible = false end
    mode = "idle"
    frame = 1
    paused = false
    lookAround = false
    cameraFollow = false
    anchor(false)
    setCameraOverride(nil)
    pcall(function() LockAnimations:Fire(false) end)
    pcall(function() LockShiftlock:Fire(false) end)
    if HUMAN then
        HUMAN.WalkSpeed = originalWalkSpeed
        HUMAN.JumpPower = originalJumpPower
        HUMAN.AutoRotate = originalAutoRotate
    end
    setStatus("Idle")
end

local function enterCreate()
    playbackOffset = nil
    cancelSafeTest()
    bindingControl = nil
    drawMenuVisible = false
    mode = "create"
    frame = #data
    paused = true
    lookAround = false
    cameraFollow = false
    if #data == 0 then
        local store = GENV.__NexusStore
        if store then
            store.loadedFPS = nil
            store.currentRunKey = nil
        end
    end
    pcall(function() LockAnimations:Fire(true) end)
    pcall(function() LockShiftlock:Fire(false) end)
    if settings.ghostMode then
        -- Ghost recording: the real character stays in place while the
        -- clone records.
        anchor(true)
    elseif #data > 0 then
        loadFrame(data[#data], false, true)
    else
        anchor(true)
    end
    setStatus(settings.ghostMode and "Ghost Mode paused - LMB to record" or "Paused")
end

local function pauseNow()
    if mode ~= "create" then return end
    if not ROOT or not HUMAN then return end
    trimIncomplete()
    paused = true
    cameraFollow = false
    pcall(function() LockAnimations:Fire(true) end)
    if #data > 0 then
        lastPauseFrame = frame
        loadFrame(data[#data], false, false)
    else
        anchor(true)
    end
    setStatus(ghost.active and "Ghost clone paused - LMB to resume" or "Paused")
end

local function unpauseNow()
    if mode ~= "create" then return end
    if not ROOT or not HUMAN then return end
    bindingControl = nil
    drawMenuVisible = false
    removeCutFrames()
    lookAround = false
    cameraFollow = true
    -- Legacy/Nexus-style timing: create the ghost clone right when recording
    -- starts. The native PlayerModule is actively controlling at this moment,
    -- so the Player.Character swap takes effect reliably.
    if settings.ghostMode and not ghost.active and enterGhost then
        enterGhost()
    end
    pcall(function() LockAnimations:Fire(false) end)
    if data[#data] then
        setCameraOverride({
            cf = data[#data].camCFrame, fov = data[#data].camFOV,
            shift = data[#data].shiftLock, zoom = data[#data].zoom,
        })
    end
    anchor(false)
    firstFrameRecord = true
    if data[#data] then
        loadFrame(data[#data], true)
    end
    pcall(function() HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
    RunService.Heartbeat:Wait()
    RunService.RenderStepped:Wait()
    pcall(function() HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
    paused = false
    firstFrameRecord = false
    setStatus("Recording")
    if ghost.active then popup("Recording on ghost clone", 2.5) end
end

local function newFirstFrame()
    -- Used when starting with an empty recording: the very first frame comes
    -- from the current live pose instead of a pause frame.
    local f = buildFrame()
    f.anim = animAtStart()
    data = { f }
    frame = 1
    recomputeTimes()
end

local function leapOffLadder()
    if #data < 2 or frame < 2 then return false end
    return data[frame].state == Enum.HumanoidStateType.Jumping
        and data[frame - 1].state == Enum.HumanoidStateType.Climbing
end

local function unpause1F()
    if mode ~= "create" or not paused then return end
    if not ROOT or not HUMAN then return end
    bindingControl = nil
    drawMenuVisible = false
    if #data == 0 then
        newFirstFrame()
        pauseNow()
        return
    end

    local frameCount = 1
    if #data > 1 and frame > 1 and leapOffLadder() then
        frame -= 1
        frameCount = 2
    end
    if #data > 1 and data[frame].state == Enum.HumanoidStateType.Landed then
        frameCount = 2
    end

    removeCutFrames()
    lookAround = false
    cameraFollow = true
    if settings.ghostMode and not ghost.active and enterGhost then
        enterGhost()
    end
    pcall(function() LockAnimations:Fire(false) end)
    if #data > 0 then
        setCameraOverride({
            cf = data[#data].camCFrame, fov = data[#data].camFOV,
            shift = data[#data].shiftLock, zoom = data[#data].zoom,
        })
    end
    anchor(false)
    firstFrameRecord = true
    loadFrame(data[#data], true)
    pcall(function() HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)

    RunService.Heartbeat:Wait()
    RunService.RenderStepped:Wait()

    pcall(function() HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
    paused = false
    firstFrameRecord = false

    for _ = 1, frameCount do
        RunService.RenderStepped:Wait()
    end

    pcall(function() LockAnimations:Fire(true) end)
    trimIncomplete()
    paused = true
    cameraFollow = false
    if #data > 0 then
        loadFrame(data[#data], false, true)
    end
    setStatus(string.format("Step +%d (frame %d/%d)", frameCount, frame, #data))
end

local function beginTestPlayback(forceStart)
    drawMenuVisible = false
    mode = "test"
    paused = false
    lookAround = false
    cameraFollow = false
    anchor(false)
    pcall(function() LockAnimations:Fire(true) end)
    pcall(function() LockShiftlock:Fire(true) end)
    if HUMAN then
        HUMAN.WalkSpeed = 0
        HUMAN.JumpPower = 0
        HUMAN.AutoRotate = false
    end

    local startIndex
    if forceStart or settings.restartTesting then
        startIndex = 1
    else
        startIndex = math.clamp(frame, 1, #data)
    end

    -- Ghost Mode: the real character never moved with the clone, so replay the
    -- recorded path relative to where the real character is standing now.
    -- This is still playback on the real character, but without teleporting it
    -- to the clone's recorded coordinates.
    playbackOffset = nil
    local startFrame = data[startIndex]
    if (settings.ghostMode or settings.relativeTest) and startFrame and startFrame.cf and ROOT then
        local startPos = startFrame.cf.Position
        local realPos = ROOT.Position
        local dx = realPos.X - startPos.X
        local dy = realPos.Y - startPos.Y
        local dz = realPos.Z - startPos.Z
        if math.abs(dx) + math.abs(dy) + math.abs(dz) > 1e-4 then
            playbackOffset = Vector3.new(dx, dy, dz)
        end
    end
    frame = startIndex
    testingTimer = (startIndex == 1) and 0 or (data[startIndex].t or 0)
    freezeTimeRemaining = 0

    local f = data[startIndex]
    if f then
        setShiftLock(f.shiftLock and true or false, true)
        applyPose(f)
        fireAnimation(f, f.anim and f.anim.Anims, 0)
    end
    setStatus("Playback")
end

local function startSafeTest()
    playbackOffset = nil
    local f = data[1]
    if not f then
        beginTestPlayback(true)
        return
    end
    cancelSafeTest()
    drawMenuVisible = false
    mode = "test"
    paused = false
    lookAround = false
    cameraFollow = false
    bindingControl = nil
    anchor(false)
    setCameraOverride(nil)
    pcall(function() LockAnimations:Fire(false) end)
    pcall(function() LockShiftlock:Fire(false) end)
    if HUMAN then
        HUMAN.WalkSpeed = originalWalkSpeed
        HUMAN.JumpPower = originalJumpPower
        HUMAN.AutoRotate = true
    end
    safeTest.waiting = true
    safeTest.aligning = false
    safeTest.frame = f
    safeTest.alignStart = 0
    setStatus("[SAFE TEST] Waiting to position to start")
    popup("[SAFE TEST] Waiting to position to start", 5)
end

local function updateSafeTest()
    if not safeTest.waiting then return end
    if not ROOT or not safeTest.frame then
        cancelSafeTest()
        return
    end
    local startCF = safeTest.frame.cf
    if not startCF then
        cancelSafeTest()
        return
    end
    local dist = (ROOT.Position - startCF.Position).Magnitude
    if dist <= 1.2 then
        pcall(function() ROOT.CFrame = startCF end)
        safeTest.waiting = false
        safeTest.aligning = false
        beginTestPlayback(true)
        popup("[SAFE TEST] Aligned - starting playback", 2.5)
        return
    end
    if safeTest.aligning then
        local elapsed = tick() - safeTest.alignStart
        if dist <= 1.2 or (elapsed >= 1.2 and dist <= 3) then
            pcall(function() ROOT.CFrame = startCF end)
            safeTest.waiting = false
            safeTest.aligning = false
            beginTestPlayback(true)
            popup("[SAFE TEST] Aligned - starting playback", 2.5)
        elseif elapsed >= 1.2 then
            -- The player walked away; let them return instead of teleporting.
            safeTest.aligning = false
            safeTest.alignStart = 0
        end
        return
    end
    if dist <= 6 then
        safeTest.aligning = true
        safeTest.alignStart = tick()
        pcall(function() HUMAN:MoveTo(startCF.Position) end)
        setStatus("[SAFE TEST] Aligning to start...")
        popup("[SAFE TEST] Aligning to start...", 2)
    end
end

local function enterTest()
    if mode == "test" then
        goIdle()
        return
    end
    if #data == 0 then
        setStatus("TAS is empty")
        return
    end
    if ghost.active and exitGhost then exitGhost() end
    bindingControl = nil
    local function start()
        if settings.safeTest then
            startSafeTest()
        else
            beginTestPlayback(false)
        end
    end
    local store = GENV.__NexusStore
    if store and store.checkFPS then
        store.checkFPS(store.currentRunKey or "current", start)
    else
        start()
    end
end

local function finishTest()
    local total = #data > 0 and (data[#data].t or 0) or 0
    goIdle()
    local msg = "TAS Completed [Time: " .. timeString(total) .. "]"
    setStatus(msg)
    popup(msg, 3)
end

local function stepBack()
    if #data == 0 then return end
    if not ROOT or not HUMAN then return end
    if settings.ghostMode and not ghost.active and enterGhost then enterGhost() end
    frame = math.max(1, frame - 1)
    paused = true
    cameraFollow = false
    pcall(function() LockAnimations:Fire(true) end)
    loadFrame(data[frame], false, true)
end

local function stepForward()
    if #data == 0 then return end
    if not ROOT or not HUMAN then return end
    if settings.ghostMode and not ghost.active and enterGhost then enterGhost() end
    frame = math.min(#data, frame + 1)
    paused = true
    cameraFollow = false
    pcall(function() LockAnimations:Fire(true) end)
    loadFrame(data[frame], false, true)
end

local function returnToPause()
    if #data == 0 then return end
    if not ROOT or not HUMAN then return end
    if settings.ghostMode and not ghost.active and enterGhost then enterGhost() end
    frame = math.clamp(lastPauseFrame, 1, #data)
    paused = true
    cameraFollow = false
    pcall(function() LockAnimations:Fire(true) end)
    loadFrame(data[frame], false, true)
end

local function deleteTAS()
    if confirmDelete then
        if mode == "test" then goIdle() end
        data = {}
        frame = 1
        lastPauseFrame = 1
        local store = GENV.__NexusStore
        if store then
            store.loadedFPS = nil
            store.currentRunKey = nil
        end
        if mode == "create" then
            paused = true
            anchor(true)
        end
        setStatus("TAS deleted")
        popup("TAS deleted", 1.8)
        confirmDelete = false
    else
        confirmDelete = true
        local msg = "Delete TAS? [" .. keyName(CONTROLS.Delete) .. "] To Confirm"
        setStatus(msg)
        popup(msg, 2.5)
        task.delay(2, function() confirmDelete = false end)
    end
end

local function optimizeTAS()
    if mode ~= "idle" then
        setStatus("Switch to Idle to optimize")
        popup("Switch to Idle to optimize", 2)
        return
    end
    if not confirmOptimize then
        confirmOptimize = true
        local msg = "Optimize TAS? [" .. keyName(CONTROLS.Optimize) .. "] To Confirm"
        setStatus(msg)
        popup(msg, 2.5)
        task.delay(2, function() confirmOptimize = false end)
        return
    end
    confirmOptimize = false
    local newData = {}
    local prevCam
    for i = 2, #data do
        local f = data[i]
        local comps = { f.camCFrame:GetComponents() }
        local same = 0
        if prevCam then
            for k = 1, 12 do
                if prevCam[k] == comps[k] then same += 1 end
            end
        end
        prevCam = comps
        if same < 12 or (f.anim and f.anim.Anims and #f.anim.Anims > 0) then
            newData[#newData + 1] = f
        end
    end
    data = newData
    recomputeTimes()
    frame = #data
    setStatus("TAS optimized (" .. #data .. " frames)")
    popup("TAS optimized", 1.8)
end

-- ==================== SAVE / LOAD ====================
-- Flat files in the executor workspace: NexusTAS_run_*.json. No subfolders,
-- because some Solara builds cannot create directories under their workspace.
local FILE_PREFIX = "NexusTAS_"
local LEGACY_MANIFEST = "NexusTAS_index.json"
local STORE = GENV.__NexusStore
if type(STORE) ~= "table" then
    STORE = {
        root = "NexusTAS",
        runs = "NexusTAS/runs",
        settingsFile = "NexusTAS/settings.json",
        manifestFile = "NexusTAS/index.json",
        legacyManifest = LEGACY_MANIFEST,
        folder = "runs",
        folders = { runs = true },
        meta = {},
        currentRunKey = nil,
        loadedFPS = nil,
        fpsEMA = 60,
        fpsWarned = {},
        settingsLoaded = false,
    }
    GENV.__NexusStore = STORE
end
local MANIFEST = STORE.manifestFile
local savedRuns = {}
local runsLoading = false
local fileStorageUsable = nil
local memorySaves = GENV.__NexusMemorySaves
if type(memorySaves) ~= "table" then
    memorySaves = {}
    GENV.__NexusMemorySaves = memorySaves
end
-- Exact paths of files saved during this executor session. Solara's listfiles
-- can resolve relative paths differently from writefile, so merge both.
local saveIndex = GENV.__NexusSaveIndex
if type(saveIndex) ~= "table" then
    saveIndex = {}
    GENV.__NexusSaveIndex = saveIndex
end

local function hasFileApi()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(listfiles) == "function"
end

local function fileExists(path)
    if type(isfile) ~= "function" then return false end
    local ok, result = pcall(isfile, path)
    return ok and result
end

function STORE.sanitize(value)
    local text = tostring(value or "run")
    text = text:gsub('[<>:"/\\|?*]', "_")
    text = text:gsub("[\r\n\t]", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then text = "run" end
    if #text > 64 then text = text:sub(1, 64) end
    return text
end

function STORE.ensureFolders(base)
    if not base then return end
    if type(makefolder) ~= "function" then return end
    pcall(makefolder, base .. STORE.root)
    pcall(makefolder, base .. STORE.runs)
    for folder in pairs(STORE.folders) do
        if type(folder) == "string" and folder ~= "runs" and folder ~= "" then
            pcall(makefolder, base .. STORE.runs .. "/" .. folder)
        end
    end
end

local function nameInUse(name)
    if memorySaves[name] then return true end
    for _, storedName in pairs(saveIndex) do
        if storedName == name then return true end
    end
    return false
end

-- writefile and readfile can resolve relative paths differently in Solara.
-- Probe a few locations once and use the first one that round-trips.
local fileBase = nil

local function testFileBase(prefix)
    local probe = prefix .. "NexusTAS_probe.txt"
    local okWrite = pcall(function() writefile(probe, "ok") end)
    if not okWrite then return false end
    for _ = 1, 6 do
        task.wait(0.1)
        if type(isfile) == "function" then
            local ok, exists = pcall(isfile, probe)
            if ok and exists then
                pcall(function() delfile(probe) end)
                return true
            end
        else
            local ok, content = pcall(function() return readfile(probe) end)
            if ok and content == "ok" then
                pcall(function() delfile(probe) end)
                return true
            end
        end
    end
    task.delay(1, function()
        if type(delfile) == "function" then pcall(function() delfile(probe) end) end
    end)
    return false
end

local function resolveFileBase()
    if fileBase ~= nil then return fileBase or nil end
    if not hasFileApi() then
        fileBase = false
        return nil
    end

    local candidates, seen = {}, {}
    local function add(path)
        if type(path) ~= "string" or path == "" then return end
        if path:sub(-1) ~= "/" and path:sub(-1) ~= "\\" then path = path .. "/" end
        if not seen[path] then
            seen[path] = true
            candidates[#candidates + 1] = path
        end
    end

    local override = GENV.__NexusFileBase
    if type(override) == "string" and override ~= "" then
        if testFileBase(override) then
            fileBase = override
            return override
        end
    end

    pcall(function()
        local fn
        if type(getworkspace) == "function" then
            fn = getworkspace
        elseif getgenv and type(getgenv().getworkspace) == "function" then
            fn = getgenv().getworkspace
        end
        if fn then
            local ok, path = pcall(fn)
            if ok then add(path) end
        end
    end)

    if getgenv then
        local genv
        pcall(function() genv = getgenv() end)
        if type(genv) == "table" then
            for _, value in pairs(genv) do
                if type(value) == "string" and #value < 260 and not value:find("\n")
                    and (value:match("^%a:[/\\]") or value:lower():find("solara", 1, true)) then
                    add(value)
                    add(value .. "/workspace")
                    add(value .. "\\workspace")
                end
            end
        end
    end

    local env = {}
    pcall(function()
        if type(os) == "table" and type(os.getenv) == "function" then
            for _, key in ipairs({ "LOCALAPPDATA", "APPDATA", "USERPROFILE", "TEMP", "TMP" }) do
                local ok, value = pcall(os.getenv, key)
                if ok and type(value) == "string" and value ~= "" then env[key] = value end
            end
        end
    end)

    local function addSolara(base)
        add(base .. "\\Solara\\workspace")
        add(base .. "\\Solara")
        add(base .. "\\Programs\\Solara\\workspace")
        add(base .. "\\Programs\\Solara")
    end
    if env.LOCALAPPDATA then addSolara(env.LOCALAPPDATA) end
    if env.APPDATA then addSolara(env.APPDATA) end
    if env.USERPROFILE then
        addSolara(env.USERPROFILE)
        add(env.USERPROFILE .. "\\Downloads\\Solara\\workspace")
        add(env.USERPROFILE .. "\\Desktop\\Solara\\workspace")
    end
    if env.TEMP then add(env.TEMP .. "\\Solara\\workspace") end

    local userName = PLAYER and PLAYER.Name or ""
    if userName ~= "" then
        add("C:\\Users\\" .. userName .. "\\AppData\\Local\\Solara\\workspace")
        add("C:\\Users\\" .. userName .. "\\AppData\\Roaming\\Solara\\workspace")
        add("C:\\Users\\" .. userName .. "\\AppData\\Local\\Programs\\Solara\\workspace")
        add("C:\\Users\\" .. userName .. "\\Solara\\workspace")
        add("C:\\Users\\" .. userName .. "\\Downloads\\Solara\\workspace")
        add("C:\\Users\\" .. userName .. "\\Desktop\\Solara\\workspace")
        add("C:\\Users\\" .. userName .. "\\AppData\\Local\\Temp\\Solara\\workspace")
    end

    local defaults = {
        "",
        "workspace/",
        "./",
        "C:/Users/Public/",
        "C:\\Users\\Public\\",
        "C:/Users/Public/Documents/",
        "C:\\Users\\Public\\Documents\\",
        "C:/Windows/System32/workspace/",
        "C:\\Windows\\System32\\workspace\\",
    }
    for _, path in ipairs(defaults) do add(path) end

    for _, prefix in ipairs(candidates) do
        if testFileBase(prefix) then
            fileBase = prefix
            return prefix
        end
    end
    fileBase = false
    return nil
end

task.spawn(function()
    resolveFileBase()
end)

local function mergeManifest()
    if not hasFileApi() or not HttpService then return end
    local base = resolveFileBase()
    if not base then return end

    local function apply(raw)
        if type(raw) ~= "string" or raw == "" then return end
        local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok or type(data) ~= "table" then return end
        if type(data.folders) == "table" then
            for _, folder in ipairs(data.folders) do
                if type(folder) == "string" and folder ~= "" then
                    STORE.folders[folder] = true
                end
            end
        end
        if type(data.runs) == "table" then
            for path, meta in pairs(data.runs) do
                if type(path) == "string" and type(meta) == "table" then
                    STORE.meta[path] = meta
                    if type(meta.name) == "string" then
                        saveIndex[path] = meta.name
                    end
                end
            end
        else
            for name, path in pairs(data) do
                if type(name) == "string" and type(path) == "string" then
                    saveIndex[path] = name
                    STORE.meta[path] = STORE.meta[path] or { name = name, folder = "runs" }
                end
            end
        end
    end

    local okNew, rawNew = pcall(function() return readfile(base .. MANIFEST) end)
    if okNew then apply(rawNew) end
    local okOld, rawOld = pcall(function() return readfile(base .. LEGACY_MANIFEST) end)
    if okOld then apply(rawOld) end
    STORE.folders.runs = true
end

local function writeManifest()
    if not hasFileApi() or not HttpService then return end
    local base = resolveFileBase()
    if not base then return end
    if type(makefolder) == "function" then
        pcall(makefolder, base .. STORE.root)
    end

    local folders = {}
    for folder in pairs(STORE.folders) do
        if type(folder) == "string" and folder ~= "" then
            folders[#folders + 1] = folder
        end
    end
    table.sort(folders)

    local runs = {}
    for path, meta in pairs(STORE.meta) do
        if type(path) == "string" and type(meta) == "table" and path:sub(1, 4) ~= "mem:" then
            runs[path] = {
                name = meta.name or saveIndex[path] or path,
                folder = meta.folder or "runs",
                fps = meta.fps,
                frames = meta.frames,
                savedAt = meta.savedAt,
            }
        end
    end
    for path, name in pairs(saveIndex) do
        if type(path) == "string" and type(name) == "string"
            and path:sub(1, 4) ~= "mem:" and not runs[path] then
            runs[path] = { name = name, folder = "runs" }
        end
    end

    local payload = { version = 2, folders = folders, runs = runs }
    local okJson, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if not okJson then return end
    pcall(function() writefile(base .. MANIFEST, json) end)
end

local function encVec(v)
    if not v then return nil end
    return { x = v.X, y = v.Y, z = v.Z }
end

local function decVec(t)
    if type(t) ~= "table" then return Vector3.zero end
    return Vector3.new(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0)
end

local function encCF(cf)
    if not cf then return nil end
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
    return {
        x = x, y = y, z = z,
        r00 = r00, r01 = r01, r02 = r02,
        r10 = r10, r11 = r11, r12 = r12,
        r20 = r20, r21 = r21, r22 = r22,
    }
end

local function decCF(t)
    if type(t) ~= "table" then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    local r00, r01, r02 = tonumber(t.r00), tonumber(t.r01), tonumber(t.r02)
    local r10, r11, r12 = tonumber(t.r10), tonumber(t.r11), tonumber(t.r12)
    local r20, r21, r22 = tonumber(t.r20), tonumber(t.r21), tonumber(t.r22)
    if not (x and y and z and r00 and r01 and r02 and r10 and r11 and r12 and r20 and r21 and r22) then
        return nil
    end
    local ok, cf = pcall(function()
        return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    end)
    if ok then return cf end
    return nil
end

local function encodeFrame(f)
    return {
        cf = encCF(f.cf),
        vel = encVec(f.vel),
        ang = encVec(f.ang),
        state = f.state and f.state.Name or "Running",
        camCFrame = encCF(f.camCFrame),
        camFOV = f.camFOV,
        zoom = f.zoom,
        shiftLock = f.shiftLock and true or false,
        dt = f.dt,
        t = f.t,
        anim = f.anim and {
            Pose = f.anim.Pose,
            JumpTime = f.anim.JumpTime,
            Speed = f.anim.Speed,
            Anims = f.anim.Anims,
        } or nil,
    }
end

local function decodeFrame(t)
    if type(t) ~= "table" then return nil end
    local cf = decCF(t.cf)
    if not cf then return nil end
    local f = {
        cf = cf,
        vel = decVec(t.vel),
        ang = decVec(t.ang),
        state = Enum.HumanoidStateType.Running,
        camCFrame = decCF(t.camCFrame),
        camFOV = tonumber(t.camFOV) or 70,
        zoom = tonumber(t.zoom) or 0,
        shiftLock = t.shiftLock and true or false,
        dt = tonumber(t.dt) or (1 / 60),
        t = tonumber(t.t) or 0,
    }
    if type(t.state) == "string" then
        pcall(function()
            f.state = Enum.HumanoidStateType[t.state] or f.state
        end)
    end
    if type(t.anim) == "table" then
        f.anim = {
            Pose = tonumber(t.anim.Pose) or 0,
            JumpTime = tonumber(t.anim.JumpTime) or 0,
            Speed = tonumber(t.anim.Speed) or 1,
            Anims = {},
        }
        if type(t.anim.Anims) == "table" then
            for _, a in ipairs(t.anim.Anims) do
                if type(a) == "table" then
                    f.anim.Anims[#f.anim.Anims + 1] = {
                        tonumber(a[1]) or 0,
                        tonumber(a[2]) or 0,
                    }
                end
            end
        end
    end
    return f
end

local function refreshSavedRuns()
    savedRuns = {}
    local seenPaths = {}
    local seenNames = {}

    mergeManifest()

    local function addRun(path, name, folder, meta)
        if type(path) ~= "string" or path == "" or seenPaths[path] then return end
        seenPaths[path] = true
        local m = meta or STORE.meta[path] or {}
        local resolvedName = name or m.name or path
        local resolvedFolder = folder or m.folder or "runs"
        local key = tostring(resolvedName) .. "|" .. tostring(resolvedFolder)
        if seenNames[key] then return end
        seenNames[key] = true
        savedRuns[#savedRuns + 1] = {
            path = path,
            name = resolvedName,
            folder = resolvedFolder,
            fps = m.fps,
            frames = m.frames,
            savedAt = m.savedAt,
        }
    end

    for path, name in pairs(saveIndex) do
        if type(path) == "string" and type(name) == "string" then
            addRun(path, name, STORE.meta[path] and STORE.meta[path].folder, STORE.meta[path])
        end
    end

    if hasFileApi() then
        local base = resolveFileBase()
        if base then
            fileStorageUsable = true
            local function fullPath(entry, rel)
                if type(entry) ~= "string" then return nil end
                if entry:find("[/\\]") then return entry end
                return base .. rel .. entry
            end
            local function scan(rel, folder, legacyOnly)
                local ok, files = pcall(function() return listfiles(base .. rel) end)
                if not ok or type(files) ~= "table" then return end
                for _, entry in ipairs(files) do
                    if type(entry) == "string" then
                        local baseName = entry:match("([^/\\]+)$") or entry
                        if baseName:sub(-5) == ".json" then
                            if legacyOnly and baseName:sub(1, #FILE_PREFIX) ~= FILE_PREFIX then
                                continue
                            end
                            local name = baseName:sub(1, -6)
                            if name:sub(1, #FILE_PREFIX) == FILE_PREFIX then
                                name = name:sub(#FILE_PREFIX + 1)
                            end
                            if name == "index" or name == "settings" then
                                continue
                            end
                            addRun(fullPath(entry, rel), name, folder)
                        end
                    end
                end
            end
            for folder in pairs(STORE.folders) do
                if type(folder) == "string" and folder ~= "" then
                    local rel = STORE.runs .. "/"
                    if folder ~= "runs" then rel = rel .. folder .. "/" end
                    scan(rel, folder, false)
                end
            end
            local okDirs, dirs = pcall(function() return listfiles(base .. STORE.runs) end)
            if okDirs and type(dirs) == "table" then
                for _, entry in ipairs(dirs) do
                    if type(entry) == "string" then
                        local name = entry:match("([^/\\]+)$") or entry
                        if name ~= "" and name:sub(-5) ~= ".json" then
                            STORE.folders[name] = true
                        end
                    end
                end
            end
            scan("", "runs", true)
        else
            fileStorageUsable = false
        end
    end

    for name, content in pairs(memorySaves) do
        if type(name) == "string" and type(content) == "string" then
            addRun("mem:" .. name, name, "runs")
        end
    end

    table.sort(savedRuns, function(a, b)
        return (a.savedAt or a.name) > (b.savedAt or b.name)
    end)
    runsLoading = false
end

local function makeRunPayload()
    if #data == 0 then return nil, "Nothing to save" end
    if not HttpService then return nil, "JSON service unavailable" end

    local stamp
    pcall(function()
        stamp = DateTime.now():FormatLocalTime("YYYY-MM-DD_HH-mm-ss", "en-us")
    end)
    if not stamp then stamp = tostring(math.floor(tick())) end

    local total = 0
    for _, f in ipairs(data) do
        total += f.dt or 0
    end
    local fps = total > 0 and math.floor(#data / total + 0.5) or math.floor(STORE.fpsEMA + 0.5)
    fps = math.clamp(fps, 1, 1000)

    local frames = {}
    for i, f in ipairs(data) do frames[i] = encodeFrame(f) end
    return {
        format = 2,
        version = VERSION,
        savedAt = stamp,
        frameCount = #data,
        fps = fps,
        folder = STORE.folder,
        frames = frames,
    }, stamp
end

local function saveCurrentRun()
    local payload, stamp = makeRunPayload()
    if not payload then
        popup(stamp, 2)
        return
    end

    local folder = STORE.folder or "runs"
    if folder == "" then folder = "runs" end
    STORE.folders[folder] = true

    local base = "run_" .. stamp
    local fileBasePath = hasFileApi() and resolveFileBase() or nil
    local saveName = STORE.sanitize(base)
    local suffix = 2
    while nameInUse(saveName) do
        saveName = STORE.sanitize(base .. "_" .. suffix)
        suffix += 1
    end

    local okJson, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if not okJson or type(json) ~= "string" then
        popup("Could not encode run", 3)
        return
    end

    memorySaves[saveName] = json
    local memoryPath = "mem:" .. saveName
    saveIndex[memoryPath] = saveName
    STORE.meta[memoryPath] = {
        name = saveName,
        folder = folder,
        fps = payload.fps,
        frames = #data,
        savedAt = stamp,
    }

    local savedToFile = false
    local savedPath = nil
    local writeError = nil
    if fileBasePath then
        STORE.ensureFolders(fileBasePath)
        local folderPart = (folder ~= "runs") and (folder .. "/") or ""
        local relative = STORE.runs .. "/" .. folderPart .. FILE_PREFIX .. saveName .. ".json"
        local path = fileBasePath .. relative
        savedPath = path
        local okWrite, err = pcall(function() writefile(path, json) end)
        if okWrite then
            savedToFile = true
            fileStorageUsable = true
            saveIndex[path] = saveName
            STORE.meta[path] = {
                name = saveName,
                folder = folder,
                fps = payload.fps,
                frames = #data,
                savedAt = stamp,
            }
            STORE.currentRunKey = path
            STORE.loadedFPS = payload.fps
            GENV.__NexusLastSave = { path = path, json = json }
            writeManifest()
            task.delay(1, function() writeManifest() end)
        else
            fileStorageUsable = false
            writeError = err
        end
    end

    if writeError then
        warn("[NexusTAS] File save unavailable, using session storage: " .. tostring(writeError))
    end

    if savedToFile then
        saveIndex[memoryPath] = nil
        STORE.meta[memoryPath] = nil
    end

    if savedToFile and savedPath and type(isfile) == "function" then
        task.delay(2, function()
            local ok, exists = pcall(isfile, savedPath)
            if ok and not exists then
                fileStorageUsable = false
                popup("File storage unavailable - using session storage", 3)
            end
        end)
    end

    refreshSavedRuns()
    local fpsText = tostring(payload.fps or "?")
    setStatus(string.format("Saved run (%d frames, %s FPS)", #data, fpsText))
    popup(savedToFile and ("Run saved (" .. fpsText .. " FPS)") or "Run saved (session)", 2)
end

local function loadRunFromString(raw)
    if not HttpService then return false, "JSON service unavailable" end
    if type(raw) ~= "string" or raw == "" then return false, "Could not read run" end

    local okJson, payload = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okJson or type(payload) ~= "table" or type(payload.frames) ~= "table" then
        return false, "Invalid run file"
    end

    local frames = {}
    for _, t in ipairs(payload.frames) do
        local f = decodeFrame(t)
        if f then frames[#frames + 1] = f end
    end
    if #frames == 0 then return false, "Run has no frames" end

    goIdle(true)
    data = frames
    frame = 1
    lastPauseFrame = 1
    recomputeTimes()
    STORE.loadedFPS = tonumber(payload.fps)
    setStatus(string.format("Loaded run (%d frames)", #frames))
    return true, payload
end

local function loadSavedRun(path)
    local name
    local raw
    if path:sub(1, 4) == "mem:" then
        name = path:sub(5)
        raw = memorySaves[name]
    else
        name = saveIndex[path]
        if not name then
            local baseName = path:match("([^/\\]+)$") or path
            if baseName:sub(1, #FILE_PREFIX) == FILE_PREFIX then
                name = baseName:sub(#FILE_PREFIX + 1, -6)
            end
        end
        if hasFileApi() then
            local okRead, content = pcall(function() return readfile(path) end)
            if okRead and type(content) == "string" and content ~= "" then
                raw = content
            end
        end
        if (not raw or raw == "") and name and type(memorySaves[name]) == "string" then
            raw = memorySaves[name]
        end
    end
    if type(raw) ~= "string" or raw == "" then
        popup("Could not read run", 3)
        return
    end

    local ok, payloadOrError = loadRunFromString(raw)
    if ok then
        STORE.currentRunKey = path
        STORE.loadedFPS = tonumber(payloadOrError and payloadOrError.fps) or STORE.loadedFPS
        popup("Run loaded", 2)
    else
        popup(payloadOrError, 3)
    end
end

local function exportRunToClipboard()
    local payload = makeRunPayload()
    if not payload then
        popup("Nothing to export", 2)
        return
    end
    if type(setclipboard) ~= "function" then
        popup("Clipboard unavailable", 3)
        return
    end
    if not HttpService then
        popup("JSON service unavailable", 3)
        return
    end
    local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
    if not ok or type(json) ~= "string" then
        popup("Could not encode run", 3)
        return
    end
    local okClip = pcall(setclipboard, json)
    if okClip then
        popup("Run copied to clipboard", 2)
    else
        popup("Clipboard failed", 3)
    end
end

local function importRunFromText(text)
    local ok, err = loadRunFromString(text)
    if ok then
        popup("Run imported", 2)
    else
        popup(err, 3)
    end
end

local function openImportBox()
    local getClip = getclipboard or (getgenv and getgenv().getclipboard)
    if type(getClip) == "function" then
        local ok, text = pcall(getClip)
        if ok and type(text) == "string" and text ~= "" then
            importRunFromText(text)
            return
        end
    end

    local parent
    pcall(function()
        if type(gethui) == "function" then parent = gethui() end
    end)
    if not parent then
        pcall(function() parent = game:GetService("CoreGui") end)
    end
    if not parent then
        pcall(function() parent = PLAYER:FindFirstChild("PlayerGui") end)
    end
    if not parent then
        popup("Clipboard import unavailable", 3)
        return
    end

    local old = parent:FindFirstChild("NexusTASImport")
    if old then pcall(function() old:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NexusTASImport"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.Parent = parent

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.6, 0, 0.32, 0)
    box.Position = UDim2.new(0.2, 0, 0.34, 0)
    box.BackgroundColor3 = Color3.fromRGB(10, 20, 30)
    box.TextColor3 = Color3.fromRGB(235, 245, 250)
    box.BorderSizePixel = 0
    box.TextWrapped = true
    box.MultiLine = true
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Code
    box.TextSize = 14
    box.PlaceholderText = "Paste NexusTAS run data and press Enter"
    box.Text = ""
    box.Parent = gui
    pcall(function() box:CaptureFocus() end)
    box.FocusLost:Connect(function(enter)
        local text = box.Text
        gui:Destroy()
        if enter and text ~= "" then importRunFromText(text) end
    end)
end

local function deleteSavedRun(path)
    if path:sub(1, 4) == "mem:" then
        memorySaves[path:sub(5)] = nil
        STORE.meta[path] = nil
    else
        if type(delfile) ~= "function" then
            popup("File API unavailable", 3)
            return
        end
        local ok = pcall(delfile, path)
        if not ok then
            popup("Delete failed", 3)
            return
        end
        local name = saveIndex[path]
        if not name then
            local baseName = path:match("([^/\\]+)$") or path
            if baseName:sub(1, #FILE_PREFIX) == FILE_PREFIX then
                name = baseName:sub(#FILE_PREFIX + 1, -6)
            end
        end
        saveIndex[path] = nil
        STORE.meta[path] = nil
        if name then memorySaves[name] = nil end
        if STORE.currentRunKey == path then STORE.currentRunKey = nil end
        writeManifest()
    end
    refreshSavedRuns()
    popup("Run deleted", 2)
end

function STORE.uiParent()
    local parent
    pcall(function() parent = gethui and gethui() end)
    if not parent then
        pcall(function() parent = game:GetService("CoreGui") end)
    end
    if not parent then
        parent = PLAYER:FindFirstChild("PlayerGui")
    end
    return parent
end

function STORE.prompt(title, defaultText, callback)
    local parent = STORE.uiParent()
    if not parent then return end
    local old = parent:FindFirstChild("NexusTASPrompt")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NexusTASPrompt"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999998
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 460, 0, 150)
    frame.Position = UDim2.new(0.5, 0, 0.5, -75)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(7, 18, 31)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(62, 145, 215)
    stroke.Thickness = 1
    stroke.Transparency = 0.15
    stroke.Parent = frame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = Color3.fromRGB(9, 30, 52)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.BackgroundTransparency = 1
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Size = UDim2.new(1, -24, 1, 0)
    titleLabel.Font = Enum.Font.GothamMedium
    titleLabel.Text = tostring(title or "NexusTAS")
    titleLabel.TextColor3 = Color3.fromRGB(235, 245, 255)
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

    local box = Instance.new("TextBox")
    box.Position = UDim2.new(0, 16, 0, 48)
    box.Size = UDim2.new(1, -32, 0, 30)
    box.BackgroundColor3 = Color3.fromRGB(13, 40, 65)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextColor3 = Color3.fromRGB(235, 245, 255)
    box.TextSize = 14
    box.Text = tostring(defaultText or "")
    box.ClearTextOnFocus = false
    box.Parent = frame

    local function finish(value)
        gui:Destroy()
        if value ~= nil and callback then callback(value) end
    end

    local okButton = Instance.new("TextButton")
    okButton.Position = UDim2.new(1, -196, 0, 94)
    okButton.Size = UDim2.new(0, 90, 0, 26)
    okButton.BackgroundColor3 = Color3.fromRGB(25, 86, 142)
    okButton.BorderSizePixel = 0
    okButton.Font = Enum.Font.GothamMedium
    okButton.Text = "OK"
    okButton.TextColor3 = Color3.fromRGB(235, 245, 255)
    okButton.TextSize = 12
    okButton.Parent = frame
    okButton.MouseButton1Click:Connect(function() finish(box.Text) end)

    local cancel = okButton:Clone()
    cancel.Position = UDim2.new(1, -102, 0, 94)
    cancel.BackgroundColor3 = Color3.fromRGB(13, 40, 65)
    cancel.Text = "Cancel"
    cancel.Parent = frame
    cancel.MouseButton1Click:Connect(function() finish(nil) end)

    box.FocusLost:Connect(function(enter)
        if enter then finish(box.Text) end
    end)

    gui.Parent = parent
    pcall(function() box:CaptureFocus() end)
end

function STORE.createFolder(name)
    local folder = STORE.sanitize(name)
    if folder == "" then return end
    STORE.folders[folder] = true
    STORE.folder = folder
    local base = hasFileApi() and resolveFileBase() or nil
    if base then
        STORE.ensureFolders(base)
        pcall(makefolder, base .. STORE.runs .. "/" .. folder)
    end
    writeManifest()
    refreshSavedRuns()
    STORE.saveSettings()
    popup("Folder: " .. folder, 2)
end

function STORE.renameRun(path, newName)
    local clean = STORE.sanitize(newName)
    if clean == "" then return end

    if path:sub(1, 4) == "mem:" then
        local oldName = path:sub(5)
        local raw = memorySaves[oldName]
        if type(raw) ~= "string" then return end
        memorySaves[oldName] = nil
        memorySaves[clean] = raw
        saveIndex[path] = clean
        STORE.meta[path] = STORE.meta[path] or { folder = "runs" }
        STORE.meta[path].name = clean
        writeManifest()
        refreshSavedRuns()
        popup("Run renamed", 2)
        return
    end

    local raw
    local okRead = pcall(function() raw = readfile(path) end)
    if not okRead or type(raw) ~= "string" then
        popup("Could not read run", 3)
        return
    end

    local base = hasFileApi() and resolveFileBase() or nil
    if not base then
        popup("File API unavailable", 3)
        return
    end

    local meta = STORE.meta[path] or {}
    local folder = meta.folder or "runs"
    local folderPart = (folder ~= "runs") and (folder .. "/") or ""
    local newPath = base .. STORE.runs .. "/" .. folderPart .. FILE_PREFIX .. clean .. ".json"
    if newPath ~= path and fileExists(newPath) then
        popup("Name already exists", 3)
        return
    end
    local okWrite = pcall(function() writefile(newPath, raw) end)
    if not okWrite then
        popup("Rename failed", 3)
        return
    end
    pcall(delfile, path)

    local oldName = saveIndex[path] or meta.name
    saveIndex[path] = nil
    STORE.meta[path] = nil
    if oldName then memorySaves[oldName] = nil end
    saveIndex[newPath] = clean
    STORE.meta[newPath] = {
        name = clean,
        folder = folder,
        fps = meta.fps,
        frames = meta.frames,
        savedAt = meta.savedAt,
    }
    memorySaves[clean] = raw
    if STORE.currentRunKey == path then STORE.currentRunKey = newPath end

    writeManifest()
    refreshSavedRuns()
    popup("Run renamed", 2)
end

function STORE.saveSettings()
    local payload = { version = 1, folder = STORE.folder, settings = {}, controls = {} }
    for key, value in pairs(settings) do
        local valueType = type(value)
        if valueType == "boolean" or valueType == "number" or valueType == "string" then
            payload.settings[key] = value
        end
    end
    for key, value in pairs(CONTROLS) do
        if typeof(value) == "EnumItem" then
            payload.controls[key] = { enum = tostring(value.EnumType), name = value.Name }
        end
    end

    local base = hasFileApi() and resolveFileBase() or nil
    if base and HttpService then
        STORE.ensureFolders(base)
        local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
        if ok then
            pcall(function() writefile(base .. STORE.settingsFile, json) end)
        end
    end
    GENV.__NexusSettings = payload
end

function STORE.loadSettings()
    local payload = GENV.__NexusSettings
    local base = hasFileApi() and resolveFileBase() or nil
    if base and HttpService then
        local ok, raw = pcall(function() return readfile(base .. STORE.settingsFile) end)
        if ok and type(raw) == "string" and raw ~= "" then
            local okJson, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
            if okJson and type(decoded) == "table" then payload = decoded end
        end
    end
    if type(payload) ~= "table" then return false end

    if type(payload.folder) == "string" and payload.folder ~= "" then
        STORE.folders[payload.folder] = true
        STORE.folder = payload.folder
    end
    if type(payload.settings) == "table" then
        for key, value in pairs(payload.settings) do
            if settings[key] ~= nil and type(settings[key]) == type(value) then
                settings[key] = value
            end
        end
    end
    if type(payload.controls) == "table" then
        for key, entry in pairs(payload.controls) do
            if CONTROLS[key] ~= nil and type(entry) == "table" and type(entry.name) == "string" then
                local value
                if entry.enum == "Enum.KeyCode" then
                    value = Enum.KeyCode[entry.name]
                elseif entry.enum == "Enum.UserInputType" then
                    value = Enum.UserInputType[entry.name]
                end
                if value then CONTROLS[key] = value end
            end
        end
    end
    STORE.settingsLoaded = true
    GENV.__NexusSettings = payload
    return true
end

function STORE.checkFPS(runKey, callback)
    local finished = false
    local function finish(change)
        if finished then return end
        finished = true
        if change then
            local target = tonumber(STORE.loadedFPS)
            if target and type(setfpscap) == "function" then
                pcall(setfpscap, target)
            elseif target then
                popup("Executor cannot change FPS cap", 3)
            end
        end
        if callback then callback() end
    end

    local target = tonumber(STORE.loadedFPS)
    if not target or target <= 0 then
        finish(false)
        return
    end
    runKey = tostring(runKey or "current")
    if STORE.fpsWarned[runKey] then
        finish(false)
        return
    end

    local current = math.floor((STORE.fpsEMA or 60) + 0.5)
    if math.abs(current - target) <= 2 then
        finish(false)
        return
    end
    STORE.fpsWarned[runKey] = true

    local parent = STORE.uiParent()
    if not parent then
        finish(false)
        return
    end
    local old = parent:FindFirstChild("NexusTASFPS")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NexusTASFPS"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999998
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 500, 0, 190)
    frame.Position = UDim2.new(0.5, 0, 0.5, -95)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundColor3 = Color3.fromRGB(7, 18, 31)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(62, 145, 215)
    stroke.Thickness = 1
    stroke.Transparency = 0.15
    stroke.Parent = frame

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3 = Color3.fromRGB(9, 30, 52)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 12, 0, 0)
    title.Size = UDim2.new(1, -24, 1, 0)
    title.Font = Enum.Font.GothamMedium
    title.Text = "FPS Mismatch"
    title.TextColor3 = Color3.fromRGB(235, 245, 255)
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local function addLine(text, y, size, color, font)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(16, y)
        label.Size = UDim2.new(1, -32, 0, size + 8)
        label.Font = font or Enum.Font.Gotham
        label.Text = text
        label.TextColor3 = color
        label.TextSize = size
        label.TextWrapped = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        return label
    end

    addLine(string.format("This run was recorded at %d FPS.", target), 42, 13,
        Color3.fromRGB(235, 245, 255), Enum.Font.GothamMedium)
    addLine(string.format("Current FPS: %d.", current), 66, 12,
        Color3.fromRGB(190, 215, 235))
    addLine(string.format("Change the FPS cap to %d for this run?", target), 90, 12,
        Color3.fromRGB(150, 190, 220))

    local function button(text, x, color, onClick)
        local btn = Instance.new("TextButton")
        btn.Position = UDim2.new(1, x, 0, 140)
        btn.Size = UDim2.new(0, 100, 0, 28)
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(235, 245, 255)
        btn.TextSize = 12
        btn.Parent = frame
        btn.MouseButton1Click:Connect(onClick)
        return btn
    end

    button("Dismiss", -224, Color3.fromRGB(13, 40, 65), function()
        gui:Destroy()
        finish(false)
    end)
    button("Yes", -116, Color3.fromRGB(25, 86, 142), function()
        gui:Destroy()
        finish(true)
    end)

    gui.Parent = parent
end

if _G.__NexusDebug then    _G.__NexusDebug.saveRun = function() saveCurrentRun() end
    _G.__NexusDebug.loadRun = function(path) loadSavedRun(path) end
    _G.__NexusDebug.runs = function()
        refreshSavedRuns()
        return savedRuns
    end
    _G.__NexusDebug.storageInfo = function()
        local out = {}
        local execName, execVersion = "?", "?"
        pcall(function() execName, execVersion = identifyexecutor() end)
        out[#out + 1] = "executor: " .. tostring(execName) .. " " .. tostring(execVersion)
        out[#out + 1] = "api: write=" .. type(writefile)
            .. " read=" .. type(readfile)
            .. " list=" .. type(listfiles)
            .. " isfile=" .. type(isfile)
            .. " isfolder=" .. type(isfolder)
            .. " makefolder=" .. type(makefolder)
            .. " delfile=" .. type(delfile)

        local ws
        pcall(function()
            if type(getworkspace) == "function" then ws = getworkspace() end
        end)
        out[#out + 1] = "getworkspace: " .. tostring(ws)
        if getgenv then
            local gws
            pcall(function() gws = getgenv().workspace end)
            out[#out + 1] = "getgenv().workspace: " .. tostring(gws)
        end

        local function list(path)
            local ok, files = pcall(function() return listfiles(path) end)
            if not ok then
                out[#out + 1] = "listfiles(" .. tostring(path) .. ") error: " .. tostring(files)
                return
            end
            local n = type(files) == "table" and #files or -1
            out[#out + 1] = "listfiles(" .. tostring(path) .. ") count=" .. tostring(n)
            if type(files) == "table" then
                for i = 1, math.min(#files, 8) do
                    out[#out + 1] = "  " .. tostring(files[i])
                end
            end
        end
        list("")
        list("workspace")
        list("C:/Users/Public/")

        local candidates = {
            "",
            "workspace/",
            "./",
            "C:/Users/Public/",
            "C:/Users/Public/Documents/",
            "C:/Windows/System32/workspace/",
        }
        for _, prefix in ipairs(candidates) do
            local probe = prefix .. "NexusTAS_diag.txt"
            local okW, errW = pcall(function() writefile(probe, "ok") end)
            local okR, content = pcall(function() return readfile(probe) end)
            local exists
            if type(isfile) == "function" then
                local okI, v = pcall(isfile, probe)
                exists = okI and v
            end
            out[#out + 1] = string.format(
                "%s write=%s(%s) read=%s(%s) isfile=%s",
                probe, tostring(okW), tostring(errW),
                tostring(okR), tostring(content), tostring(exists))
            pcall(function()
                if type(delfile) == "function" then delfile(probe) end
            end)
        end

        -- Delayed check: Solara may flush files asynchronously.
        local delayed = "NexusTAS_diag_delayed.txt"
        local okWrite = pcall(function() writefile(delayed, "ok") end)
        task.wait(2)
        local okExists, exists = pcall(function() return isfile(delayed) end)
        local okRead, content = pcall(function() return readfile(delayed) end)
        out[#out + 1] = string.format(
            "delayed %s write=%s isfile=%s(%s) read=%s(%s)",
            delayed, tostring(okWrite), tostring(okExists), tostring(exists),
            tostring(okRead), tostring(content))
        list("")
        pcall(function()
            if type(delfile) == "function" then delfile(delayed) end
        end)

        return table.concat(out, "\n")
    end
end

-- ==================== RECORDING / PLAYBACK TIMING ====================
local function onPreRender()
    if not charLoaded() then return end
    if mode == "create" and not paused then
        if firstFrameRecord and #data > 0 then
            -- Keep the existing pause frame instead of inserting a duplicate.
        else
            local cam = workspace.CurrentCamera
            local f = {
                camCFrame = cam and cam.CFrame or CFrame.new(),
                camFOV = cam and cam.FieldOfView or 70,
                zoom = camZoom(),
                shiftLock = isShiftLocked(),
                dt = 0,
                t = 0,
                anim = nil,
            }
            data[#data + 1] = f
        end
    end
end

local function onPreSimulation()
    if not charLoaded() then return end
    if mode == "create" and not paused and not firstFrameRecord and notDead() then
        local f = data[#data]
        if f then
            f.cf = ROOT.CFrame
            f.vel = ROOT.AssemblyLinearVelocity
            f.ang = ROOT.AssemblyAngularVelocity
            f.state = HUMAN:GetState()
            f.anim = captureAnims(#data <= 2)
        end
    elseif mode == "test" and not safeTest.waiting and data[frame + 1] then
        pcall(function() HUMAN:Move(ROOT.AssemblyLinearVelocity) end)
    end
end

local function recordHeartbeat()
    if mode ~= "create" or paused then return end
    trimIncomplete()
    local f = data[#data]
    if f and f.cf then
        f.dt = lastFrameTime
        local prev = data[#data - 1]
        f.t = (prev and prev.t or 0) + f.dt
        frame = #data
    end
end

local function updateTest()
    if mode ~= "test" or #data == 0 then return end
    local speed = settings.playbackSpeed

    if settings.interpolate then
        local prev = frame
        testingTimer += lastFrameTime * speed

        while data[frame + 1] and testingTimer > data[frame + 1].t do
            frame += 1
        end
        while frame > 1 and testingTimer < data[frame - 1].t do
            frame -= 1
        end

        if not data[frame + 1] then
            finishTest()
            return
        end

        local a, b = data[frame], data[frame + 1]
        if b.dt > 0.1 then
            -- Long frame: hold this pose like the original Showcase mode.
            applyPose(a)
            fireAnimation(a, a.anim and a.anim.Anims, 0)
            return
        end

        local alpha = 0
        if b.t > a.t then
            alpha = (testingTimer - a.t) / (b.t - a.t)
        end
        alpha = math.clamp(alpha, 0, 1)

        pcall(function() ROOT.CFrame = shiftCF(a.cf:Lerp(b.cf, alpha)) end)
        pcall(function()
            ROOT.AssemblyLinearVelocity = a.vel:Lerp(b.vel, alpha)
            ROOT.AssemblyAngularVelocity = a.ang:Lerp(b.ang, alpha)
        end)
        pcall(function() HUMAN:ChangeState(a.state) end)

        local camCF = a.camCFrame
        if b.camCFrame then camCF = a.camCFrame:Lerp(b.camCFrame, alpha) end
        setCameraOverride({
            cf = shiftCF(camCF),
            fov = a.camFOV + ((b.camFOV or a.camFOV) - a.camFOV) * alpha,
            shift = a.shiftLock,
            zoom = a.zoom,
        })

        for i = prev + 1, frame do
            local f = data[i]
            if f then fireAnimation(f, f.anim and f.anim.Anims, speed) end
        end
    else
        if freezeTimeRemaining > lastFrameTime then
            freezeTimeRemaining -= lastFrameTime
            return
        end
        local b = data[frame + 1]
        if not b then
            finishTest()
            return
        end
        frame += 1
        local hold = (b.dt or (1 / 60)) / math.max(speed, 0.01)
        freezeTimeRemaining = math.max(0, hold - lastFrameTime)
        applyPose(b)
        fireAnimation(b, b.anim and b.anim.Anims, speed)
    end
end

-- ==================== MAIN LOOP ====================
connect(RunService.PreRender, onPreRender)
connect(RunService.PreSimulation, onPreSimulation)
connect(RunService.Heartbeat, function(dt)
    if ghost.active and updateGhost then updateGhost() end
    if mode == "create" and not paused then
        recordHeartbeat()
    elseif mode == "create" and paused then
        if backHeld and frame > 1 then
            frame -= 1
            loadFrame(data[frame], false, true)
        elseif forwHeld and frame < #data then
            frame += 1
            loadFrame(data[frame], false, true)
        end
    elseif mode == "test" then
        if safeTest.waiting then
            updateSafeTest()
        else
            updateTest()
        end
    end
    if dt and dt > 0 then
        local instant = 1 / dt
        STORE.fpsEMA = math.clamp((STORE.fpsEMA or 60) * 0.9 + instant * 0.1, 1, 1000)
    end
    lastFrameTime = dt
end)

-- ==================== INPUT ====================
local drawInputBegan, drawInputChanged, drawInputEnded
local drawSearchInput

local function matches(inp, bind)
    return inp.KeyCode == bind or inp.UserInputType == bind
end

local function toggleGui()
    drawMenuVisible = not drawMenuVisible
    if not drawMenuVisible then
        themeMenuOpen = false
        folderMenuOpen = false
        if GENV.__NexusSetSearch then
            GENV.__NexusSetSearch(false)
        end
    end
end

connect(UIS.JumpRequest, function()
    if ghost.active then return end
    if not HUMAN or mode ~= "create" or frame < 2 then return end
    local cur = data[frame]
    local prev = data[frame - 1]
    if cur and prev
        and HUMAN:GetState() == Enum.HumanoidStateType.Running
        and cur.state == Enum.HumanoidStateType.Running
        and prev.state == Enum.HumanoidStateType.Running then
        pcall(function() HUMAN:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end)

connect(UIS.InputBegan, function(inp, processed)
    if drawInputBegan then
        local ok, consumed = pcall(drawInputBegan, inp)
        if ok and consumed then return end
    end
    if drawSearchInput then
        local ok, consumed = pcall(drawSearchInput, inp)
        if ok and consumed then return end
    end
    if bindingControl then
        local captured
        if inp.UserInputType == Enum.UserInputType.Keyboard then
            captured = inp.KeyCode
        elseif inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.MouseButton2
            or inp.UserInputType == Enum.UserInputType.MouseButton3 then
            captured = inp.UserInputType
        end
        if captured then
            CONTROLS[bindingControl] = captured
            if STORE and STORE.saveSettings then STORE.saveSettings() end
            local conflict = bindConflictFor(bindingControl)
            if conflict then
                popup("Key conflict: " .. keyName(captured) .. " also used by " .. conflict, 3.5)
            end
        end
        bindingControl = nil
        return
    end

    -- Menu and pause/unpause are core TAS inputs; keep them working even when
    -- the game has processed the input (chat, game GUI) or the character is
    -- temporarily unavailable (respawn / ghost swap).
    if matches(inp, CONTROLS.Menu) then
        toggleGui()
        return
    end
    if mode == "create" and (matches(inp, CONTROLS.Pause) or matches(inp, CONTROLS.Unpause)) then
        if paused then unpauseNow() else pauseNow() end
        return
    end

    local focused = nil
    pcall(function() focused = UIS:GetFocusedTextBox() end)
    if processed and focused then return end
    local loaded = charLoaded()

    if matches(inp, CONTROLS.Idle) then
        if loaded then goIdle() end
    elseif matches(inp, CONTROLS.Create) then
        if loaded then enterCreate() end
    elseif matches(inp, CONTROLS.Test) and #data > 0 then
        if loaded then enterTest() end
    elseif matches(inp, CONTROLS.Unpause1F) and mode == "create" and paused then
        unpause1F()
    elseif matches(inp, CONTROLS.Return) and mode == "create" and #data > 0 then
        returnToPause()
    elseif matches(inp, CONTROLS.Forward1F) and mode == "create" and frame < #data then
        stepForward()
    elseif matches(inp, CONTROLS.Back1F) and mode == "create" and frame > 1 then
        stepBack()
    elseif matches(inp, CONTROLS.Forward) and mode == "create" then
        forwHeld = true
    elseif matches(inp, CONTROLS.Back) and mode == "create" then
        backHeld = true
    elseif matches(inp, CONTROLS.Look) and mode == "create" and paused then
        lookAround = not lookAround
        if lookAround then
            setCameraOverride(nil)
        elseif data[frame] then
            setCameraOverride({
                cf = data[frame].camCFrame, fov = data[frame].camFOV,
                shift = data[frame].shiftLock, zoom = data[frame].zoom,
            })
        end
    elseif matches(inp, CONTROLS.Optimize) then
        optimizeTAS()
    elseif matches(inp, CONTROLS.Delete) then
        deleteTAS()
    end
end)

connect(UIS.InputEnded, function(inp)
    if drawInputEnded then pcall(drawInputEnded, inp) end
    if matches(inp, CONTROLS.Forward) then forwHeld = false end
    if matches(inp, CONTROLS.Back) then backHeld = false end
end)

-- ==================== BINDABLE IMPLEMENTATIONS ====================
local function createBindables()
    if TASRS then pcall(function() TASRS:Destroy() end) end
    TASRS = Instance.new("Folder", ReplicatedStorage)
    TASRS.Name = "NXRuntime"
    BE = Instance.new("Folder", TASRS)
    BE.Name = "BindableEvents"
    BF = Instance.new("Folder", TASRS)
    BF.Name = "BindableFunctions"

    SetAnimation = makeEvent("SetAnimation")
    LockAnimations = makeEvent("LockAnimations")
    ShiftlockSwitch = makeEvent("ShiftlockSwitch")
    LockShiftlock = makeEvent("LockShiftlock")
    SetZoom = makeEvent("SetZoom")
    RemoveZoomSpring = makeEvent("RemoveZoomSpring")
    ShiftlockRotation = makeEvent("ShiftlockRotation")
    SetTAS = makeEvent("SetTAS")

    GetAnimation = makeFunction("GetAnimation")
    GetZoom = makeFunction("GetZoom")
    GetTAS = makeFunction("GetTAS")

    GetZoom.OnInvoke = function()
        return camZoom()
    end

    SetZoom.Event:Connect(function()
        -- The camera is applied directly in renderCamera; nothing to do here.
    end)
    RemoveZoomSpring.Event:Connect(function() end)
    ShiftlockRotation.Event:Connect(function() end)
    LockShiftlock.Event:Connect(function(lock)
        shiftLockLocked = lock and true or false
    end)
    ShiftlockSwitch.Event:Connect(function(enable)
        setShiftLock(enable and true or false)
    end)
    GetTAS.OnInvoke = function()
        return data
    end
    SetTAS.Event:Connect(function() end)
end

createBindables()

-- ==================== GHOST MODE ====================
-- Clone-based recording: the real character is hidden and anchored, the clone
-- is recorded, and playback later uses the real character.
local function saveSourceVisuals(src)
    ghost.savedParts = {}
    for _, d in ipairs(src:GetDescendants()) do
        if d:IsA("BasePart") then
            ghost.savedParts[d] = {
                kind = "part",
                itm = d.LocalTransparencyModifier,
                transparency = d.Transparency,
                cc = d.CanCollide,
            }
            d.LocalTransparencyModifier = 1
            d.Transparency = 1
            d.CanCollide = false
        elseif d:IsA("Decal") or d:IsA("Texture") then
            ghost.savedParts[d] = { kind = "decal", transparency = d.Transparency }
            d.Transparency = 1
        end
    end
end

local function restoreSourceVisuals()
    if not ghost.savedParts then return end
    for obj, saved in pairs(ghost.savedParts) do
        if obj and obj.Parent then
            if saved.kind == "part" then
                obj.LocalTransparencyModifier = saved.itm or 0
                obj.Transparency = saved.transparency or 0
                obj.CanCollide = saved.cc
            else
                obj.Transparency = saved.transparency or 0
            end
        end
    end
    ghost.savedParts = nil
end

enterGhost = function()
    if ghost.active then return true end
    if not settings.ghostMode then return false end
    local src = CHARACTER
    if not src or not src.Parent or not ROOT or not HUMAN then return false end
    local wasLive = (mode == "create" and not paused)

    local wasArchivable = src.Archivable
    local archived = {}
    for _, d in ipairs(src:GetDescendants()) do
        archived[d] = d.Archivable
        d.Archivable = true
    end
    src.Archivable = true
    local clone = src:Clone()
    src.Archivable = wasArchivable
    for d, a in pairs(archived) do
        if d then d.Archivable = a end
    end
    if not clone then return false end

    local cRoot, cHuman, cAnimator = resolveCharacter(clone)
    if not cRoot or not cHuman then
        clone:Destroy()
        return false
    end

    clone.Name = src.Name
    pcall(function()
        cHuman.MaxHealth = 9e9
        cHuman.Health = 9e9
        cHuman.DisplayName = ""
        cHuman.NameDisplayDistance = 0
        cHuman.HealthDisplayDistance = 0
    end)
    cHuman.BreakJointsOnDeath = false
    cHuman.WalkSpeed = originalWalkSpeed
    cHuman.JumpPower = originalJumpPower
    cHuman.AutoRotate = true

    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then d.Anchored = false end
    end
    cRoot.Anchored = true
    clone.Parent = workspace
    pcall(function() clone:PivotTo(src:GetPivot()) end)
    local cAnimate = clone:FindFirstChild("Animate")
    if cAnimate then cAnimate.Disabled = true end

    saveSourceVisuals(src)
    ghost.sourceChar = src
    ghost.sourceRoot = ROOT
    ghost.sourceHuman = HUMAN
    ghost.sourceAnimator = ANIMATOR
    ghost.sourceAnimate = ANIMATE_SCRIPT
    ghost.savedName = {
        displayName = HUMAN and HUMAN.DisplayName or "",
        nameDist = HUMAN and HUMAN.NameDisplayDistance or 100,
        healthDist = HUMAN and HUMAN.HealthDisplayDistance or 100,
    }
    if HUMAN then
        pcall(function()
            HUMAN.DisplayName = ""
            HUMAN.NameDisplayDistance = 0
            HUMAN.HealthDisplayDistance = 0
        end)
    end
    local cam = workspace.CurrentCamera
    ghost.savedCameraSubject = cam and cam.CameraSubject or HUMAN

    if HUMAN then
        HUMAN.Sit = false
        HUMAN.AutoRotate = false
        HUMAN.WalkSpeed = originalWalkSpeed
        HUMAN.JumpPower = originalJumpPower
        pcall(function() HUMAN:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    if ROOT then ROOT.Anchored = true end

    ghost.active = true
    ghost.clone = clone
    ghost.cloneRoot = cRoot
    ghost.cloneHuman = cHuman
    ghost.cloneAnimator = cAnimator
    ghost.cloneAnimate = cAnimate
    ghost.lastJump = false
    ghost.swapped = false
    ghost.noMoveFrames = 0
    ghost.mirrorControls = false
    ghost.ignoreChars = setmetatable({}, { __mode = "k" })

    CHARACTER = clone
    ROOT = cRoot
    HUMAN = cHuman
    ANIMATOR = cAnimator
    ANIMATE_SCRIPT = cAnimate
    if cam then cam.CameraSubject = cHuman end
    cRoot.Anchored = not wasLive
    if wasLive then
        pcall(function() cHuman:ChangeState(Enum.HumanoidStateType.Running) end)
    end

    -- Use the clone as the local character so its Humanoid/Animator are
    -- initialised by the engine and the overhead name tag is hidden.
    if PLAYER.Character == src then
        ghost.ignoreChars[clone] = true
        local ok = pcall(function() PLAYER.Character = clone end)
        if ok and PLAYER.Character == clone then
            ghost.swapped = true
        end
    end

    -- Stop the source fork cleanly and start a new one for the clone.
    pcall(function() if LockAnimations then LockAnimations:Fire(true) end end)
    FORK_ID += 1
    _G.__NexusForkID = FORK_ID
    createBindables()
    setupAnimateFork()

    connect(cHuman.Died, function()
        if ghost.active then
            exitGhost()
            setStatus("Ghost clone died")
        end
    end)

    if mode == "create" and paused then
        pcall(function() LockAnimations:Fire(true) end)
        if #data > 0 then
            loadFrame(data[math.clamp(frame, 1, #data)], false, true)
        end
    end

    setStatus("Ghost Mode ON (clone)")
    popup("Ghost clone ready - LMB to start recording", 3)
    return true
end

exitGhost = function()
    if not ghost.active then return end
    ghost.active = false

    local sourceChar = ghost.sourceChar
    local sourceRoot = ghost.sourceRoot
    local sourceHuman = ghost.sourceHuman
    local sourceAnimator = ghost.sourceAnimator
    local sourceAnimate = ghost.sourceAnimate
    local clone = ghost.clone
    local savedSubject = ghost.savedCameraSubject

    pcall(function() if LockAnimations then LockAnimations:Fire(true) end end)

    -- Hand the character back to the real one before destroying the clone.
    if ghost.swapped and clone and sourceChar and sourceChar.Parent
        and PLAYER.Character == clone then
        ghost.ignoreChars[sourceChar] = true
        pcall(function() PLAYER.Character = sourceChar end)
        task.delay(1, function()
            if ghost.ignoreChars then ghost.ignoreChars[sourceChar] = nil end
        end)
    end
    ghost.swapped = false

    -- Stop the clone's animation tracks before the clone is destroyed.
    if ghost.cloneAnimator then
        pcall(function()
            for _, track in pairs(ghost.cloneAnimator:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end)
    end

    -- The real character stayed planted during ghost recording: never copy the
    -- clone's pose/velocity onto it, otherwise the server sees a teleport.
    if sourceRoot then
        pcall(function()
            sourceRoot.AssemblyLinearVelocity = Vector3.zero
            sourceRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    restoreSourceVisuals()

    -- Restore the real character's overhead name/health display settings.
    if sourceHuman and ghost.savedName then
        pcall(function()
            sourceHuman.DisplayName = ghost.savedName.displayName
            sourceHuman.NameDisplayDistance = ghost.savedName.nameDist
            sourceHuman.HealthDisplayDistance = ghost.savedName.healthDist
        end)
    end
    ghost.savedName = nil

    if sourceRoot then pcall(function() sourceRoot.Anchored = false end) end
    if sourceHuman then
        pcall(function()
            sourceHuman.Sit = false
            sourceHuman.AutoRotate = originalAutoRotate
            sourceHuman.WalkSpeed = originalWalkSpeed
            sourceHuman.JumpPower = originalJumpPower
            sourceHuman:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end

    if clone then pcall(function() clone:Destroy() end) end

    CHARACTER = sourceChar or CHARACTER
    ROOT = sourceRoot
    HUMAN = sourceHuman
    ANIMATOR = sourceAnimator
    ANIMATE_SCRIPT = sourceAnimate
    local cam = workspace.CurrentCamera
    if cam then cam.CameraSubject = sourceHuman or savedSubject end

    FORK_ID += 1
    _G.__NexusForkID = FORK_ID
    createBindables()
    setupAnimateFork()

    ghost.clone = nil
    ghost.cloneRoot = nil
    ghost.cloneHuman = nil
    ghost.cloneAnimator = nil
    ghost.cloneAnimate = nil
    ghost.sourceChar = nil
    ghost.sourceRoot = nil
    ghost.sourceHuman = nil
    ghost.sourceAnimator = nil
    ghost.sourceAnimate = nil
    ghost.savedCameraSubject = nil
    ghost.savedParts = nil
    ghost.savedName = nil
    ghost.lastJump = false
    ghost.swapped = false
    ghost.noMoveFrames = 0
    ghost.mirrorControls = false
    ghost.ignoreChars = setmetatable({}, { __mode = "k" })

    if mode == "create" and paused then
        pcall(function() LockAnimations:Fire(true) end)
        -- Never apply a recorded frame to the real character here. It must
        -- stay exactly where it was standing, otherwise pressing Test/Idle
        -- after a paused ghost recording teleports it to the clone's pose.
        anchor(true)
    end
    setStatus("Ghost Mode OFF")
end

updateGhost = function()
    if not ghost.active then return end
    local cam = workspace.CurrentCamera
    local dstH = ghost.cloneHuman
    local srcH = ghost.sourceHuman
    if not dstH then return end
    if cam and cam.CameraSubject ~= dstH then cam.CameraSubject = dstH end

    -- Keep both the clone and the hidden real character from showing an
    -- overhead name/health tag, even if a custom game writes those back.
    pcall(function()
        if dstH.NameDisplayDistance ~= 0 then dstH.NameDisplayDistance = 0 end
        if dstH.HealthDisplayDistance ~= 0 then dstH.HealthDisplayDistance = 0 end
        if dstH.DisplayName ~= "" then dstH.DisplayName = "" end
        if srcH then
            if srcH.NameDisplayDistance ~= 0 then srcH.NameDisplayDistance = 0 end
            if srcH.HealthDisplayDistance ~= 0 then srcH.HealthDisplayDistance = 0 end
            if srcH.DisplayName ~= "" then srcH.DisplayName = "" end
        end
    end)

    -- Drive the clone only while recording. Input comes from the real
    -- character; if the swap did not rebind native controls, mirror it.
    local activeRecording = mode == "create" and not paused
    if not activeRecording then
        pcall(function() dstH:Move(Vector3.zero, false) end)
        ghost.lastJump = srcH and srcH.Jump or false
        return
    end

    if not srcH then return end

    if not ghost.swapped then
        pcall(function() dstH:Move(srcH.MoveDirection, false) end)
    else
        -- The clone may be driven natively by the PlayerModule. Only take over
        -- if the real character keeps moving while the clone stands still for
        -- several frames (custom controls that ignore the swap).
        local srcDir = srcH.MoveDirection
        local cloneDir = dstH.MoveDirection
        if srcDir.Magnitude > 0.1 and cloneDir.Magnitude < 0.05 then
            ghost.noMoveFrames = (ghost.noMoveFrames or 0) + 1
            if ghost.noMoveFrames >= 10 then
                ghost.mirrorControls = true
            end
        elseif cloneDir.Magnitude > 0.05 then
            ghost.noMoveFrames = 0
        end
        if ghost.mirrorControls then
            -- Mirror every frame, including zero, so releasing the keys also
            -- clears the clone's move direction (no runaway).
            pcall(function() dstH:Move(srcDir, false) end)
        end
    end

    local jump = srcH.Jump
    if jump and not ghost.lastJump then
        pcall(function() dstH.Jump = true end)
    end
    ghost.lastJump = jump

    if (not ghost.swapped or ghost.mirrorControls)
        and dstH.WalkSpeed ~= srcH.WalkSpeed then
        dstH.WalkSpeed = srcH.WalkSpeed
    end
end

-- ==================== RESPAWN ====================
local function onDied()
    if ghost.active and exitGhost then exitGhost() end
    playbackOffset = nil
    cancelSafeTest()
    mode = "idle"
    paused = false
    cameraFollow = false
    anchor(false)
    pcall(function() LockAnimations:Fire(false) end)
    if #data > 0 then
        table.remove(data, #data)
    end
    if #data == 0 then frame = 1 end
end

connect(PLAYER.CharacterAdded, function(char)
    if ghost.ignoreChars[char] then return end
    if ghost.active and exitGhost then exitGhost() end
    playbackOffset = nil
    cancelSafeTest()
    local newRoot, newHuman, newAnimator = resolveCharacter(char)
    if not newRoot or not newHuman then return end
    CHARACTER = char
    ROOT = newRoot
    HUMAN = newHuman
    ANIMATOR = newAnimator
    ANIMATE_SCRIPT = char:FindFirstChild("Animate")
    originalWalkSpeed = HUMAN.WalkSpeed
    if originalWalkSpeed <= 0 then originalWalkSpeed = 16 end
    originalJumpPower = HUMAN.JumpPower
    if originalJumpPower <= 0 then originalJumpPower = 50 end
    originalAutoRotate = HUMAN.AutoRotate
    mode = "idle"
    paused = false
    frame = 1
    cameraTarget = nil
    animAvailable = false
    connect(HUMAN.Died, onDied)
    setupAnimateFork()
    anchor(false)
end)

if HUMAN then
    connect(HUMAN.Died, onDied)
end

-- ==================== GUI (DRAW API) ====================
-- The GUI has its own function so its locals do not count against the main
-- chunk's 200-register limit.
local drawShutdown
local function setupGui()

-- Everything is rendered with Solara's Drawing API. Input is handled by
-- hit-testing rectangles against UserInputService:GetMouseLocation().

local COL = {
    bg = Color3.fromRGB(7, 18, 31),
    title = Color3.fromRGB(9, 30, 52),
    panel = Color3.fromRGB(10, 28, 46),
    row = Color3.fromRGB(13, 40, 65),
    rowAlt = Color3.fromRGB(11, 33, 54),
    button = Color3.fromRGB(25, 86, 142),
    buttonHover = Color3.fromRGB(38, 112, 178),
    accent = Color3.fromRGB(62, 145, 215),
    text = Color3.fromRGB(222, 238, 252),
    subtext = Color3.fromRGB(125, 170, 205),
    border = Color3.fromRGB(30, 83, 125),
    danger = Color3.fromRGB(220, 95, 105),
    white = Color3.fromRGB(240, 248, 255),
}

local THEMES = {
    Midnight = {
        bg = Color3.fromRGB(7, 18, 31), title = Color3.fromRGB(9, 30, 52),
        panel = Color3.fromRGB(10, 28, 46), row = Color3.fromRGB(13, 40, 65),
        rowAlt = Color3.fromRGB(11, 33, 54), button = Color3.fromRGB(25, 86, 142),
        buttonHover = Color3.fromRGB(38, 112, 178), accent = Color3.fromRGB(62, 145, 215),
        text = Color3.fromRGB(222, 238, 252), subtext = Color3.fromRGB(125, 170, 205),
        border = Color3.fromRGB(30, 83, 125), danger = Color3.fromRGB(220, 95, 105),
        white = Color3.fromRGB(240, 248, 255),
    },
    Ocean = {
        bg = Color3.fromRGB(4, 16, 24), title = Color3.fromRGB(7, 34, 46),
        panel = Color3.fromRGB(7, 26, 38), row = Color3.fromRGB(10, 40, 54),
        rowAlt = Color3.fromRGB(9, 34, 48), button = Color3.fromRGB(20, 92, 120),
        buttonHover = Color3.fromRGB(30, 125, 155), accent = Color3.fromRGB(64, 205, 220),
        text = Color3.fromRGB(225, 248, 252), subtext = Color3.fromRGB(130, 185, 205),
        border = Color3.fromRGB(28, 105, 130), danger = Color3.fromRGB(220, 90, 100),
        white = Color3.fromRGB(242, 252, 255),
    },
    Sakura = {
        bg = Color3.fromRGB(28, 13, 21), title = Color3.fromRGB(50, 22, 35),
        panel = Color3.fromRGB(40, 18, 28), row = Color3.fromRGB(57, 24, 38),
        rowAlt = Color3.fromRGB(49, 20, 33), button = Color3.fromRGB(150, 58, 95),
        buttonHover = Color3.fromRGB(185, 78, 118), accent = Color3.fromRGB(246, 142, 178),
        text = Color3.fromRGB(255, 236, 244), subtext = Color3.fromRGB(205, 150, 175),
        border = Color3.fromRGB(105, 44, 68), danger = Color3.fromRGB(235, 80, 95),
        white = Color3.fromRGB(255, 246, 250),
    },
    Matrix = {
        bg = Color3.fromRGB(4, 17, 9), title = Color3.fromRGB(6, 36, 18),
        panel = Color3.fromRGB(6, 28, 14), row = Color3.fromRGB(10, 46, 23),
        rowAlt = Color3.fromRGB(8, 39, 19), button = Color3.fromRGB(20, 110, 50),
        buttonHover = Color3.fromRGB(30, 155, 72), accent = Color3.fromRGB(64, 232, 112),
        text = Color3.fromRGB(222, 255, 232), subtext = Color3.fromRGB(122, 205, 152),
        border = Color3.fromRGB(30, 105, 56), danger = Color3.fromRGB(215, 80, 80),
        white = Color3.fromRGB(240, 255, 245),
    },
    Sunset = {
        bg = Color3.fromRGB(26, 11, 9), title = Color3.fromRGB(50, 21, 15),
        panel = Color3.fromRGB(41, 17, 13), row = Color3.fromRGB(62, 26, 20),
        rowAlt = Color3.fromRGB(52, 22, 17), button = Color3.fromRGB(152, 68, 28),
        buttonHover = Color3.fromRGB(195, 95, 42), accent = Color3.fromRGB(255, 162, 72),
        text = Color3.fromRGB(255, 240, 230), subtext = Color3.fromRGB(220, 160, 120),
        border = Color3.fromRGB(112, 50, 28), danger = Color3.fromRGB(230, 80, 80),
        white = Color3.fromRGB(255, 246, 236),
    },
    Mono = {
        bg = Color3.fromRGB(14, 14, 16), title = Color3.fromRGB(30, 30, 34),
        panel = Color3.fromRGB(22, 22, 25), row = Color3.fromRGB(33, 33, 37),
        rowAlt = Color3.fromRGB(27, 27, 30), button = Color3.fromRGB(72, 72, 80),
        buttonHover = Color3.fromRGB(98, 98, 108), accent = Color3.fromRGB(205, 205, 215),
        text = Color3.fromRGB(242, 242, 246), subtext = Color3.fromRGB(150, 150, 160),
        border = Color3.fromRGB(62, 62, 70), danger = Color3.fromRGB(210, 80, 80),
        white = Color3.fromRGB(252, 252, 255),
    },
}

function THEMES.apply(name)
    if type(THEMES[name]) ~= "table" then
        name = "Midnight"
        settings.theme = name
    end
    local theme = THEMES[name] or THEMES.Midnight
    for key, value in pairs(theme) do
        COL[key] = value
    end
    THEMES.applied = name
end

function THEMES.cycle(direction)
    local names = {}
    for name, theme in pairs(THEMES) do
        if type(name) == "string" and type(theme) == "table" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    local index = 1
    for i, name in ipairs(names) do
        if name == settings.theme then index = i end
    end
    index += (direction or 1)
    if index < 1 then index = #names end
    if index > #names then index = 1 end
    settings.theme = names[index]
    THEMES.apply(settings.theme)
    if STORE and STORE.saveSettings then STORE.saveSettings() end
end

local function matchesSearch(label)
    if searchQuery == "" then return true end
    return tostring(label):lower():find(searchQuery:lower(), 1, true) ~= nil
end

drawSearchInput = function(inp)
    if not drawMenuVisible or not searchActive then return false end
    if inp.UserInputType ~= Enum.UserInputType.Keyboard then return false end
    local key = inp.KeyCode
    if key == Enum.KeyCode.Escape or key == Enum.KeyCode.Return then
        if GENV.__NexusSetSearch then GENV.__NexusSetSearch(false) else searchActive = false end
        return true
    end
    if key == Enum.KeyCode.Backspace then
        searchQuery = searchQuery:sub(1, -2)
        return true
    end
    local name = key.Name
    if key == Enum.KeyCode.Space then
        searchQuery = searchQuery .. " "
    elseif type(name) == "string" and #name == 1 then
        searchQuery = searchQuery .. name:lower()
    end
    if #searchQuery > 32 then searchQuery = searchQuery:sub(1, 32) end
    return true
end

if _G.__NexusDebug then
    _G.__NexusDebug.setSearch = function(query)
        searchQuery = tostring(query or "")
        if GENV.__NexusSetSearch then
            GENV.__NexusSetSearch(true)
        else
            searchActive = true
        end
    end
end

function GENV.__NexusSetSearch(active)
    active = active == true
    if active == searchActive then return end
    searchActive = active
    if active then
        GENV.__NexusSearchSaved = {
            walk = HUMAN and HUMAN.WalkSpeed or 0,
            jump = HUMAN and HUMAN.JumpPower or 0,
        }
        if HUMAN then
            HUMAN.WalkSpeed = 0
            HUMAN.JumpPower = 0
            pcall(function() HUMAN:Move(Vector3.zero, false) end)
        end
    else
        local saved = GENV.__NexusSearchSaved
        if saved and HUMAN then
            HUMAN.WalkSpeed = saved.walk or 0
            HUMAN.JumpPower = saved.jump or 0
        end
        GENV.__NexusSearchSaved = nil
    end
end

local drawW, drawH = 700, 600
local drawHover = nil
local drawDragging = false
local drawDragMX, drawDragMY = 0, 0
local drawDragWX, drawDragWY = 0, 0
local drawToastVisible = true

local drawPool = {}
local drawKinds = {}
local drawCount = 0

local function drawViewport()
    local cam = workspace.CurrentCamera
    if cam then return cam.ViewportSize end
    return Vector2.new(1920, 1080)
end

local function addDraw(kind, props)
    drawCount += 1
    local obj = drawPool[drawCount]
    if not obj or drawKinds[drawCount] ~= kind then
        if obj then pcall(function() obj:Remove() end) end
        obj = Drawing.new(kind)
        drawPool[drawCount] = obj
        drawKinds[drawCount] = kind
    end
    obj.Visible = true
    obj.ZIndex = props.ZIndex or 1
    -- Solara's Drawing "Transparency" is actually opacity: 1 = fully visible.
    -- Older drawing libs use 0 = visible; hard-set opacity to avoid invisible UI.
    obj.Transparency = 1
    obj.Color = props.Color or COL.text
    if kind == "Square" then
        obj.Position = props.Position or Vector2.new(0, 0)
        obj.Size = props.Size or Vector2.new(0, 0)
        obj.Filled = props.Filled ~= false
        obj.Thickness = props.Thickness or 1
    elseif kind == "Text" then
        obj.Text = props.Text or ""
        obj.Size = props.Size or 12
        obj.Font = props.Font or Drawing.Fonts.UI
        obj.Center = false
        obj.Outline = props.Outline ~= false
        obj.OutlineColor = Color3.fromRGB(0, 0, 0)
        obj.Position = props.Position or Vector2.new(0, 0)
    elseif kind == "Line" then
        obj.From = props.From or Vector2.new(0, 0)
        obj.To = props.To or Vector2.new(0, 0)
        obj.Thickness = props.Thickness or 1
    elseif kind == "Circle" then
        obj.Position = props.Position or Vector2.new(0, 0)
        obj.Radius = props.Radius or 10
        obj.Thickness = props.Thickness or 1
        obj.Filled = props.Filled == true
    end
    return obj
end

local function line(x1, y1, x2, y2, color, opacity, z, thickness)
    local obj = addDraw("Line", {
        From = Vector2.new(x1, y1),
        To = Vector2.new(x2, y2),
        Color = color,
        ZIndex = z or 10,
        Thickness = thickness or 1,
    })
    obj.Transparency = opacity or 1
    return obj
end

local function circle(x, y, radius, color, opacity, z, filled, thickness)
    local obj = addDraw("Circle", {
        Position = Vector2.new(x, y),
        Radius = radius,
        Color = color,
        ZIndex = z or 10,
        Filled = filled == true,
        Thickness = thickness or 1,
    })
    obj.Transparency = opacity or 1
    return obj
end

local function sq(x, y, w, h, color, alpha, z, filled, thickness)
    addDraw("Square", {
        Position = Vector2.new(x, y),
        Size = Vector2.new(w, h),
        Color = color,
        Transparency = alpha or 0,
        ZIndex = z or 10,
        Filled = filled ~= false,
        Thickness = thickness or 1,
    })
end

local TEXT_FONT_ENUM = {
    [0] = Enum.Font.Roboto,
    [1] = Enum.Font.Legacy,
    [2] = Enum.Font.SourceSans,
    [3] = Enum.Font.RobotoMono,
}
local textService = nil
pcall(function() textService = game:GetService("TextService") end)
local textWidthCache = {}
local textWidthCacheCount = 0

local function measureText(text, size, font)
    text = tostring(text)
    local key = tostring(font) .. "|" .. tostring(size) .. "|" .. text
    local cached = textWidthCache[key]
    if cached then return cached end
    local width
    if textService then
        local ok, bounds = pcall(function()
            return textService:GetTextSize(
                text, size, TEXT_FONT_ENUM[font] or Enum.Font.Roboto,
                Vector2.new(10000, 1000))
        end)
        if ok and bounds and bounds.X and bounds.X > 0 then
            width = bounds.X
        end
    end
    if not width or width <= 0 then
        width = #text * size * 0.52
    end
    if textWidthCacheCount > 800 then
        textWidthCache = {}
        textWidthCacheCount = 0
    end
    textWidthCache[key] = width
    textWidthCacheCount += 1
    return width
end

local function txt(x, y, size, text, color, font, alpha, z, centered, outline)
    local obj = addDraw("Text", {
        Position = Vector2.new(x, y),
        Size = size,
        Text = text,
        Color = color or COL.text,
        Font = font or Drawing.Fonts.UI,
        Transparency = alpha or 0,
        ZIndex = z or 20,
        Outline = outline ~= false,
    })
    if centered then
        local boundsX = measureText(text, size, font)
        obj.Position = Vector2.new(x - boundsX * 0.5, y)
    end
    return obj
end

local function addHit(id, x, y, w, h, fn)
    drawHits[#drawHits + 1] = { id = id, x = x, y = y, w = w, h = h, fn = fn }
end

local function inside(mx, my, h)
    return mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h
end

local function drawButton(id, x, y, w, h, label, onClick, active)
    local hover = drawHover == id
    local color = active and COL.accent or (hover and COL.buttonHover or COL.button)
    sq(x, y, w, h, color, 0.05, 12, true)
    sq(x, y, w, h, COL.border, 0.55, 13, false, 1)
    txt(x + w * 0.5, y + h * 0.5 - 6, 12, label, COL.text, Drawing.Fonts.UI, 0, 21, true, true)
    addHit(id, x, y, w, h, onClick)
end

local function drawToggle(id, x, y, w, h, label, value, onClick)
    local hover = drawHover == id
    sq(x, y, w, h, hover and COL.rowAlt or COL.row, 0.1, 12, true)
    if value then
        sq(x, y, 2, h, COL.accent, 0.05, 13, true)
    end
    txt(x + 12, y + h * 0.5 - 6, 11, label, COL.text, Drawing.Fonts.UI, 0, 21, false, true)
    local trackX, trackY = x + w - 52, y + h * 0.5 - 7
    sq(trackX, trackY, 40, 14, value and COL.button or COL.panel, 0.05, 13, true)
    sq(trackX, trackY, 40, 14, COL.border, 0.45, 14, false, 1)
    local knobX = trackX + (value and 33 or 7)
    circle(knobX, y + h * 0.5, 5.5, value and COL.white or COL.subtext, 1, 15, true, 1)
    addHit(id, x, y, w, h, onClick)
end

local function buildMenuPrimitives()
    local vp = drawViewport()
    if not drawMenuX then
        drawMenuX = math.max(0, math.floor((vp.X - drawW) * 0.5))
        drawMenuY = math.max(0, math.floor((vp.Y - drawH) * 0.5))
    end
    local x, y = drawMenuX, drawMenuY
    local w, h = drawW, drawH

    -- Base panel + any click inside is consumed by the menu.
    sq(x, y, w, h, COL.bg, 0.02, 10, true)
    sq(x, y, w, h, COL.border, 0.12, 11, false, 1)
    addHit("menu_bg", x, y, w, h, function() end)

    -- Header / watermark
    sq(x, y, w, 36, COL.title, 0.02, 12, true)
    sq(x, y + 36, w, 1, COL.border, 0.35, 12, true)
    txt(x + 14, y + 9, 17, "NexusTAS", COL.text, Drawing.Fonts.UI, 0, 22, false, true)
    txt(x + 118, y + 14, 10, "V" .. tostring(VERSION), COL.subtext, Drawing.Fonts.Monospace, 0, 22, false, true)

    local searchW, searchH = 200, 22
    local searchX, searchY = x + w - 44 - searchW, y + 7
    sq(searchX, searchY, searchW, searchH, COL.panel, 0.08, 13, true)
    sq(searchX, searchY, searchW, searchH, searchActive and COL.accent or COL.border, 0.45, 14, false, 1)
    local searchText = searchQuery ~= "" and searchQuery or "Search... (Esc)"
    txt(searchX + 8, searchY + 5, 10, searchText .. (searchActive and "|" or ""),
        searchQuery ~= "" and COL.text or COL.subtext, Drawing.Fonts.Monospace, 0, 22, false, true)
    GENV.__NexusSearchRect = { x = searchX, y = searchY, w = searchW, h = searchH }
    addHit("search_box", searchX, searchY, searchW, searchH, function()
        if GENV.__NexusSetSearch then
            GENV.__NexusSetSearch(not searchActive)
        else
            searchActive = not searchActive
        end
    end)

    addHit("menu_drag", x, y, w - 300, 36, function()
        drawDragging = true
        local m = UIS:GetMouseLocation()
        drawDragMX, drawDragMY = m.X, m.Y
        drawDragWX, drawDragWY = drawMenuX, drawMenuY
    end)

    -- Close
    local closeHover = drawHover == "menu_close"
    sq(x + w - 32, y + 7, 22, 22, closeHover and COL.danger or COL.button, 0.08, 13, true)
    txt(x + w - 21, y + 10, 12, "X", COL.text, Drawing.Fonts.UI, 0, 23, true, true)
    addHit("menu_close", x + w - 32, y + 7, 22, 22, function()
        drawMenuVisible = false
        themeMenuOpen = false
        folderMenuOpen = false
        if GENV.__NexusSetSearch then GENV.__NexusSetSearch(false) end
    end)

    -- Left category rail
    local sidebarW = 166
    sq(x, y + 37, sidebarW, h - 37, COL.panel, 0.04, 11, true)
    sq(x + sidebarW, y + 37, 1, h - 37, COL.border, 0.25, 12, true)

    local categories = {
        { "player", "TAS Settings" },
        { "saves", "Saves" },
        { "binds", "Binds" },
        { "client", "Client" },
        { "info", "Info" },
    }
    local sy = y + 50
    for _, category in ipairs(categories) do
        local key, label = category[1], category[2]
        local active = drawTab == key
        local id = "tab_" .. key
        local hover = drawHover == id
        sq(x + 10, sy, sidebarW - 20, 30,
            active and COL.button or (hover and COL.buttonHover or COL.panel), 0.05, 13, true)
        if active then
            sq(x + 10, sy, 3, 30, COL.accent, 0.02, 14, true)
        end
        txt(x + 26, sy + 8, 12, label, active and COL.text or COL.subtext,
            Drawing.Fonts.UI, 0, 22, false, true)
        addHit(id, x + 10, sy, sidebarW - 20, 30, function()
            drawTab = key
            themeMenuOpen = false
            folderMenuOpen = false
            if key == "saves" then
                runsLoading = true
                task.spawn(function()
                    task.wait(0.12)
                    refreshSavedRuns()
                    runsLoading = false
                end)
            end
        end)
        sy += 34
    end

    -- Watermark
    local discordLabel = tostring(GENV.__NexusDiscord or "")
    if discordLabel ~= "" then
        local dw = measureText(discordLabel, 9, Drawing.Fonts.Monospace)
        txt(x + w - 20 - dw, y + h - 22, 9, discordLabel, COL.subtext,
            Drawing.Fonts.Monospace, 0, 20, false, true)
        addHit("menu_discord", x + w - 24 - dw, y + h - 25, dw + 8, 18, function()
            if type(setclipboard) == "function" then
                local copied = pcall(setclipboard, discordLabel)
                popup(copied and "Link copied!" or "Could not copy link", 2)
            end
        end)
    end

    local cx, cy = x + sidebarW + 16, y + 82
    local cw = w - sidebarW - 32

    -- Category title
    local titleText = "Main"
    for _, category in ipairs(categories) do
        if category[1] == drawTab then titleText = category[2] end
    end
    txt(cx, y + 50, 15, titleText, COL.text, Drawing.Fonts.UI, 0, 21, false, true)
    sq(cx, y + 70, 28, 2, COL.accent, 0.05, 21, true)

    if drawTab == "binds" then
        txt(cx, cy, 10, "Click on any control to change the keybind.", COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
        local conflicts = findBindConflicts()
        local rowStart = cy + 18
        if #conflicts > 0 then
            local warning = "Key conflict: " .. conflicts[1]
            if #conflicts > 1 then warning = warning .. " (+" .. (#conflicts - 1) .. ")" end
            txt(cx, cy + 14, 10, warning, COL.danger, Drawing.Fonts.UI, 0, 22, false, true)
            rowStart = cy + 32
        end
        local rows = {
            { "Idle", "Idle" }, { "Create", "Create" }, { "Test", "Test" },
            { "Pause", "Pause" }, { "Unpause", "Unpause" },
            { "Forward", "Forward" }, { "Back", "Back" },
            { "Forward1F", "Forward 1 Frame" }, { "Back1F", "Back 1 Frame" },
            { "Unpause1F", "Unpause 1 Frame" }, { "Return", "Return" },
            { "Look", "Look Around" }, { "Optimize", "Optimize TAS" },
            { "Delete", "Delete TAS" }, { "Menu", "Menu" },
        }
        local rowH, rowGap = 22, 3
        local ry = rowStart
        local shownBinds = 0
        for i, row in ipairs(rows) do
            local key, label = row[1], row[2]
            if matchesSearch(label) then
                shownBinds += 1
                sq(cx, ry, cw, rowH, (shownBinds % 2 == 0) and COL.rowAlt or COL.row, 0.1, 12, true)
                txt(cx + 10, ry + 5, 11, label, COL.text, Drawing.Fonts.UI, 0, 21, false, true)
                local keyW, keyH = 176, 18
                local kx, ky = cx + cw - keyW - 4, ry + 2
                local binding = bindingControl == key
                local hover = drawHover == ("bind_" .. key)
                sq(kx, ky, keyW, keyH, binding and COL.accent or (hover and COL.buttonHover or COL.button), 0.05, 13, true)
                local keyText = binding and "Press a key..." or keyName(CONTROLS[key])
                txt(kx + keyW * 0.5, ky + 3, 10, keyText, COL.text, Drawing.Fonts.UI, 0, 22, true, true)
                addHit("bind_" .. key, kx, ky, keyW, keyH, function() bindingControl = key end)
                ry += rowH + rowGap
            end
        end
        if shownBinds == 0 then
            txt(cx, ry, 11, "No modules found.", COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
        end
        local resetY = ry + (shownBinds == 0 and 24 or 3)
        drawButton("controls_reset", cx, resetY, cw, 20, "Reset to Defaults", function()
            for k, v in pairs(DEFAULT_CONTROLS) do CONTROLS[k] = v end
            bindingControl = nil
            if STORE and STORE.saveSettings then STORE.saveSettings() end
        end)
    elseif drawTab == "player" then
        local rows = {
            { "interpolate", "Interpolate Playback" },
            { "lockCamPaused", "Lock Camera (Paused)" },
            { "lockCamTest", "Lock Camera (Test)" },
            { "restartTesting", "Restart When Testing" },
            { "showStats", "Show Stats" },
            { "safeTest", "Safe Test (walk to start)" },
            { "ghostMode", "Ghost Mode (clone recording)" },
            { "relativeTest", "Relative Test (start from here)" },
        }
        local y2 = cy
        local shown = 0
        for i, row in ipairs(rows) do
            local key, label = row[1], row[2]
            if matchesSearch(label) then
                shown += 1
                drawToggle("set_" .. key, cx, y2, cw, 24, label, settings[key], function()
                    settings[key] = not settings[key]
                    if STORE and STORE.saveSettings then STORE.saveSettings() end
                    if key == "ghostMode" then
                        if settings.ghostMode then
                            if mode == "create" and enterGhost then
                                if not enterGhost() then settings.ghostMode = false end
                            end
                        elseif ghost.active and exitGhost then
                            exitGhost()
                        end
                    end
                end)
                y2 += 27
            end
        end
        if shown == 0 then
            txt(cx, cy, 11, "No modules found.", COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
        end
    elseif drawTab == "client" then
        drawToggle("set_showLoader", cx, cy, cw, 26, "Show Loader on Startup", settings.showLoader, function()
            settings.showLoader = not settings.showLoader
            if STORE and STORE.saveSettings then STORE.saveSettings() end
        end)

        local y2 = cy + 36
        sq(cx, y2, cw, 26, COL.row, 0.1, 12, true)
        txt(cx + 10, y2 + 7, 11, "Playback Speed", COL.text, Drawing.Fonts.UI, 0, 21, false, true)
        local minusX = cx + cw - 130
        local plusX = cx + cw - 34
        drawButton("speed_minus", minusX, y2 + 4, 24, 18, "-", function()
            settings.playbackSpeed = math.clamp(round(settings.playbackSpeed - 0.25, 100), 0.1, 4)
            if STORE and STORE.saveSettings then STORE.saveSettings() end
        end)
        drawButton("speed_plus", plusX, y2 + 4, 24, 18, "+", function()
            settings.playbackSpeed = math.clamp(round(settings.playbackSpeed + 0.25, 100), 0.1, 4)
            if STORE and STORE.saveSettings then STORE.saveSettings() end
        end)
        txt(minusX + 27, y2 + 7, 11, string.format("%.2f", settings.playbackSpeed),
            COL.text, Drawing.Fonts.Monospace, 0, 21, false, true)

        drawButton("client_discord", cx, y2 + 42, 190, 28, "Join Discord", function()
            local invite = GENV.__NexusDiscord
            if type(invite) ~= "string" or invite == "" then
                popup("Discord link is not configured", 2)
                return
            end
            local copied = false
            if type(setclipboard) == "function" then
                copied = pcall(setclipboard, invite)
            end
            popup(copied and "Link copied!" or "Could not copy link", 2)
        end)
        txt(cx, y2 + 78, 10, "Discord: " .. tostring(GENV.__NexusDiscord or ""),
            COL.subtext, Drawing.Fonts.Monospace, 0, 21, false, true)

        local themeY = y2 + 102
        sq(cx, themeY, cw, 26, COL.row, 0.1, 12, true)
        txt(cx + 12, themeY + 7, 11, "Theme: " .. tostring(settings.theme),
            COL.text, Drawing.Fonts.UI, 0, 21, false, true)
        txt(cx + cw - 24, themeY + 7, 10, themeMenuOpen and "^" or "v",
            COL.subtext, Drawing.Fonts.Monospace, 0, 21, false, true)
        addHit("theme_dropdown", cx, themeY, cw, 26, function()
            themeMenuOpen = not themeMenuOpen
        end)

        if themeMenuOpen then
            local themeNames = {}
            for name, theme in pairs(THEMES) do
                if type(name) == "string" and type(theme) == "table" then
                    themeNames[#themeNames + 1] = name
                end
            end
            table.sort(themeNames)
            local optionY = themeY + 29
            for index, name in ipairs(themeNames) do
                local active = settings.theme == name
                sq(cx, optionY, cw, 20, active and COL.button or COL.rowAlt, 0.08, 12, true)
                txt(cx + 10, optionY + 4, 10, name,
                    active and COL.text or COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
                addHit("theme_opt_" .. index, cx, optionY, cw, 20, function()
                    settings.theme = name
                    THEMES.apply(name)
                    themeMenuOpen = false
                    if STORE and STORE.saveSettings then STORE.saveSettings() end
                end)
                optionY += 21
            end
        end
    elseif drawTab == "saves" then
        local basePath = fileBase
        local fileMode = hasFileApi() and fileStorageUsable ~= false
            and basePath ~= nil and basePath ~= false
        local folder = STORE.folder or "runs"
        STORE.folders[folder] = true

        drawButton("save_run", cx, cy, 170, 24, "Save Current Run", function()
            saveCurrentRun()
        end)
        drawButton("new_folder", cx + 178, cy, 108, 24, "New Folder", function()
            STORE.prompt("New folder", "My Game", function(text)
                STORE.createFolder(text)
            end)
        end)
        drawButton("refresh_runs", cx + 294, cy, 80, 24, "Refresh", function()
            runsLoading = true
            task.spawn(function()
                task.wait(0.12)
                refreshSavedRuns()
                runsLoading = false
            end)
        end)

        local folders = {}
        for name in pairs(STORE.folders) do
            if type(name) == "string" and name ~= "" then
                folders[#folders + 1] = name
            end
        end
        table.sort(folders)
        local folderOptionHits = {}
        sq(cx, cy + 30, cw, 24, COL.row, 0.1, 12, true)
        txt(cx + 10, cy + 36, 11, "Folder: " .. folder,
            COL.text, Drawing.Fonts.UI, 0, 21, false, true)
        txt(cx + cw - 24, cy + 36, 10, folderMenuOpen and "^" or "v",
            COL.subtext, Drawing.Fonts.Monospace, 0, 21, false, true)
        addHit("folder_dropdown", cx, cy + 30, cw, 24, function()
            folderMenuOpen = not folderMenuOpen
        end)

        if folderMenuOpen then
            local optionY = cy + 57
            local maxOptions = 8
            for index = 1, math.min(#folders, maxOptions) do
                local name = folders[index]
                local active = name == folder
                sq(cx, optionY, cw, 20, active and COL.button or COL.rowAlt, 0.06, 30, true)
                txt(cx + 10, optionY + 4, 10, name,
                    active and COL.text or COL.subtext, Drawing.Fonts.UI, 0, 31, false, true)
                folderOptionHits[#folderOptionHits + 1] = {
                    name = name, x = cx, y = optionY, w = cw, h = 20,
                }
                optionY += 21
            end
        end

        local storageLabel
        if fileMode then
            storageLabel = "Path: " .. tostring(basePath) .. STORE.root
            if #storageLabel > 66 then storageLabel = storageLabel:sub(1, 63) .. "..." end
        else
            storageLabel = hasFileApi() and basePath == nil
                and "Checking storage..."
                or "Session storage (no persistent path)"
        end
        txt(cx, cy + 55, 9, storageLabel,
            fileMode and COL.subtext or COL.danger,
            Drawing.Fonts.UI, 0, 21, false, true)

        drawButton("export_run", cx, cy + 72, 150, 20, "Export Clipboard", function()
            exportRunToClipboard()
        end)
        drawButton("import_run", cx + 160, cy + 72, 150, 20, "Import Clipboard", function()
            openImportBox()
        end)

        local list = {}
        for _, run in ipairs(savedRuns) do
            if run.folder == folder and matchesSearch(run.name) then list[#list + 1] = run end
        end

        local ry = cy + 100
        if runsLoading then
            txt(cx + 2, ry, 11, "Loading...",
                COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
        elseif #list == 0 then
            txt(cx + 2, ry, 11, "No saved runs in this folder.",
                COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
        else
            local maxRows = 9
            for i = 1, math.min(#list, maxRows) do
                local run = list[i]
                sq(cx, ry, cw, 22, (i % 2 == 0) and COL.rowAlt or COL.row, 0.1, 12, true)
                local label = run.name
                if #label > 30 then label = label:sub(1, 27) .. "..." end
                txt(cx + 8, ry + 5, 10, label,
                    COL.text, Drawing.Fonts.Monospace, 0, 21, false, true)
                local fpsText = run.fps and (tostring(run.fps) .. " FPS") or "? FPS"
                txt(cx + cw - 250, ry + 5, 9, fpsText,
                    COL.subtext, Drawing.Fonts.Monospace, 0, 21, false, true)
                drawButton("load_run_" .. i, cx + cw - 126, ry + 2, 54, 18, "Load", function()
                    loadSavedRun(run.path)
                end)
                drawButton("ren_run_" .. i, cx + cw - 68, ry + 2, 30, 18, "Ren", function()
                    STORE.prompt("Rename run", run.name, function(text)
                        STORE.renameRun(run.path, text)
                    end)
                end)
                drawButton("del_run_" .. i, cx + cw - 34, ry + 2, 30, 18, "Del", function()
                    deleteSavedRun(run.path)
                end)
                ry += 25
            end
            if #list > maxRows then
                txt(cx + 2, ry, 10, "+" .. (#list - maxRows) .. " more",
                    COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
            end
        end

        for index, option in ipairs(folderOptionHits) do
            addHit("folder_opt_" .. index, option.x, option.y, option.w, option.h, function()
                STORE.folder = option.name
                folderMenuOpen = false
                STORE.saveSettings()
            end)
        end
    elseif drawTab == "help" then
        local lines = {
            "CONTROLS", "",
            "1   Idle",
            "2   Create / record",
            "3   Playback / test",
            "LMB   Pause / resume",
            "V   Step one frame",
            "F / G   Previous / next frame",
            "T / R   Hold to seek",
            "E   Return to pause point",
            "L   Look around",
            "Q   Optimize TAS",
            "Backspace   Delete TAS",
            keyName(CONTROLS.Menu) .. "   Open / close menu", "",
            "Stepping runs real physics for 1-2 frames.",
            "Camera follows the character while stepping and re-locks on pause.",
            "",
            "Ghost Mode: record and play back on a local clone.",
            "Safe Test: walk to the START marker before playback.",
        }
        for i, line in ipairs(lines) do
            txt(cx, cy + (i - 1) * 16, 11, line, COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
        end
    elseif drawTab == "info" then
        local lines = {
            "NexusTAS " .. VERSION, "",
            "WHAT'S NEW",
            "- Relative Test: start playback where you stand",
            "- Y Offset: lower playback height",
            "- Folder dropdown for organizing runs",
            "- FPS is saved with every run",
            "- Menu search and six themes",
            "- Settings save automatically", "",
            "TIPS",
            "- Y Offset only affects playback",
            "- R6 is required for recording",
            "- Export/Import uses the clipboard",
            "- Re-injecting replaces the old instance",
        }
        for i, line in ipairs(lines) do
            txt(cx, cy + (i - 1) * 17, 11, line, COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
        end
    end

    local yBar = y + h - 64
    sq(cx, yBar, cw, 40, COL.row, 0.08, 12, true)
    txt(cx + 10, yBar + 6, 11, "Y Offset (lower)", COL.text,
        Drawing.Fonts.UI, 0, 21, false, true)
    txt(cx + 10, yBar + 22, 8, "Don't touch unless you know what this does.",
        COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
    drawButton("yoff_minus", cx + cw - 104, yBar + 9, 24, 18, "-", function()
        settings.yOffset = math.clamp(round((settings.yOffset or 0) - 0.5, 10), -50, 50)
        if STORE and STORE.saveSettings then STORE.saveSettings() end
    end)
    drawButton("yoff_plus", cx + cw - 34, yBar + 9, 24, 18, "+", function()
        settings.yOffset = math.clamp(round((settings.yOffset or 0) + 0.5, 10), -50, 50)
        if STORE and STORE.saveSettings then STORE.saveSettings() end
    end)
    txt(cx + cw - 65, yBar + 12, 10, string.format("%.1f", settings.yOffset or 0),
        COL.text, Drawing.Fonts.Monospace, 0, 21, false, true)

    local footer = statusText
    if ghost.active then footer = footer .. "  [GHOST]" end
    txt(cx, y + h - 20, 10, footer, COL.subtext, Drawing.Fonts.UI, 0, 21, false, true)
end

local function hudFrameData()
    local isCreate = (mode == "create")
    local f = nil
    local frameNo = frame
    if #data > 0 then
        if isCreate and paused then
            f = data[math.clamp(frame, 1, #data)]
        elseif isCreate then
            f = data[#data]
            frameNo = #data
        end
    end
    if f and not f.cf then f = nil end
    return f, frameNo, isCreate
end

local function buildHudPrimitives()
    if not settings.showStats then return end
    local vp = drawViewport()
    if mode == "test" then
        local w, h = 300, 54
        local x, y = vp.X - w - 16, vp.Y - h - 16
        sq(x, y, w, h, COL.bg, 0.08, 30, true)
        sq(x, y, w, h, COL.border, 0.35, 31, false, 1)
        txt(x + 10, y + 9, 11, "Time:", COL.subtext, Drawing.Fonts.Monospace, 0, 32, false, true)
        txt(x + 120, y + 9, 11, timeString(testingTimer), COL.white, Drawing.Fonts.Monospace, 0, 32, false, true)
        txt(x + 10, y + 29, 11, "Playback Speed:", COL.subtext, Drawing.Fonts.Monospace, 0, 32, false, true)
        txt(x + 120, y + 29, 11, string.format("%g", settings.playbackSpeed), COL.white, Drawing.Fonts.Monospace, 0, 32, false, true)
        return
    end

    local f, frameNo, isCreate = hudFrameData()
    local w, h = isCreate and 380 or 340, isCreate and 205 or 172
    local x, y = vp.X - w - 16, vp.Y - h - 16
    sq(x, y, w, h, COL.bg, 0.08, 30, true)
    sq(x, y, w, h, COL.border, 0.35, 31, false, 1)

    local cf, vel, ang, state, ft, total, zoom
    if f then
        cf = f.cf
        vel = f.vel
        ang = f.ang
        state = f.state
        ft = f.dt
        total = f.t
        zoom = f.zoom
    else
        cf = ROOT and ROOT.CFrame or CFrame.new()
        vel = ROOT and ROOT.AssemblyLinearVelocity or Vector3.zero
        ang = ROOT and ROOT.AssemblyAngularVelocity or Vector3.zero
        state = HUMAN and HUMAN:GetState() or Enum.HumanoidStateType.Freefall
        ft = lastFrameTime
        total = (#data > 0 and data[#data].t) or 0
        zoom = camZoom()
    end
    if not cf then cf = CFrame.new() end

    local rx, ry, rz = cf:ToEulerAnglesYXZ()
    local cam = workspace.CurrentCamera
    local crx, cry, crz = 0, 0, 0
    if cam then crx, cry, crz = cam.CFrame:ToEulerAnglesYXZ() end
    local pos = cf.Position

    local rows = {}
    if isCreate then
        rows[#rows + 1] = { "Frame:", tostring(frameNo) }
        rows[#rows + 1] = { "Frame Time:", string.format("%.6f", ft or 0) }
        rows[#rows + 1] = { "Total Time:", timeString(total or 0) }
    else
        rows[#rows + 1] = { "Frame Time:", string.format("%.6f", ft or 0) }
    end
    rows[#rows + 1] = { "Root Position:", string.format("%.4f, %.4f, %.4f", pos.X, pos.Y, pos.Z) }
    rows[#rows + 1] = { "Root Rotation:", string.format("%.1f, %.1f, %.1f", math.deg(rx), math.deg(ry), math.deg(rz)) }
    rows[#rows + 1] = { "Root Linear Velocity:", string.format("%.1f, %.1f, %.1f", vel.X, vel.Y, vel.Z) }
    rows[#rows + 1] = { "Root Angular Velocity:", string.format("%.1f, %.1f, %.1f", ang.X, ang.Y, ang.Z) }
    rows[#rows + 1] = { "Camera Rotation:", string.format("%.1f, %.1f, %.1f", math.deg(crx), math.deg(cry), math.deg(crz)) }
    rows[#rows + 1] = { "Humanoid State:", tostring(state and state.Name or "?") }
    rows[#rows + 1] = { "Zoom:", string.format("%.3f", zoom or 0) }

    for i, row in ipairs(rows) do
        local ry2 = y + 8 + (i - 1) * 15
        txt(x + 10, ry2, 11, row[1], COL.subtext, Drawing.Fonts.Monospace, 0, 32, false, true)
        txt(x + 170, ry2, 11, row[2], COL.white, Drawing.Fonts.Monospace, 0, 32, false, true)
    end
end

local function buildToastPrimitives()
    if not drawToastVisible then return end
    local vp = drawViewport()
    local w, h = 320, 56
    local x, y = 16, vp.Y - h - 16
    sq(x, y, w, h, COL.bg, 0.05, 40, true)
    sq(x, y, w, h, COL.border, 0.2, 41, false, 1)
    txt(x + 14, y + 8, 14, "NexusTAS V" .. VERSION .. " Loaded", COL.text, Drawing.Fonts.UI, 0, 42, false, true)
    txt(x + 14, y + 31, 11, "M - Main Menu", COL.subtext, Drawing.Fonts.UI, 0, 42, false, true)
    txt(x + w - 20, y + 8, 11, "X", COL.subtext, Drawing.Fonts.UI, 0, 42, true, true)

    -- The X closes the notification; the body opens the menu.
    addHit("toast_close", x + w - 32, y + 3, 28, 22, function() drawToastVisible = false end)
    addHit("toast_body", x, y, w - 34, h, function() drawMenuVisible = true end)
end

local function buildPopupPrimitives()
    if popupText == "" then return end
    local now = tick()
    if now >= popupUntil then return end
    local vp = drawViewport()
    local alpha = math.clamp((popupUntil - now) / 0.45, 0, 1)
    txt(vp.X * 0.5, vp.Y - 110, 24, popupText, COL.white, Drawing.Fonts.UI, alpha, 60, true, true)
end

local function buildSafeTestNotice()
    if not safeTest.waiting then return end
    local vp = drawViewport()
    local dist = 0
    if ROOT and safeTest.frame and safeTest.frame.cf then
        dist = (ROOT.Position - safeTest.frame.cf.Position).Magnitude
    end
    local title = safeTest.aligning
        and "[SAFE TEST] Aligning to start..."
        or "[SAFE TEST] Waiting to position to start"
    txt(vp.X * 0.5, vp.Y - 170, 18, title, COL.white, Drawing.Fonts.UI, 0, 55, true, true)
    txt(vp.X * 0.5, vp.Y - 145, 11,
        string.format("Follow the on-screen START icon  (%.1f m)", dist),
        COL.subtext, Drawing.Fonts.UI, 0, 55, true, true)
end

-- Screen-space waypoint icon for Safe Test. Unlike the neon beam it is drawn
-- by the Drawing API, so it is always visible through walls. Off-screen it
-- becomes an arrow clamped to the screen edge.
local SAFE_GREEN = Color3.fromRGB(90, 255, 150)
local SAFE_WHITE = Color3.fromRGB(235, 255, 240)

local function buildSafeTestMarker()
    if not safeTest.waiting or not safeTest.frame or not safeTest.frame.cf then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local startCF = safeTest.frame.cf
    local world = startCF.Position + Vector3.new(0, 7.5, 0)
    local ok, sp = pcall(function() return cam:WorldToScreenPoint(world) end)
    if not ok or not sp then return end

    local vp = drawViewport()
    local cx, cy = vp.X * 0.5, vp.Y * 0.5
    local dist = ROOT and (ROOT.Position - startCF.Position).Magnitude or 0
    local onScreen = sp.Z > 0 and sp.X >= 0 and sp.X <= vp.X
        and sp.Y >= 0 and sp.Y <= vp.Y
    local nx, ny = sp.X, sp.Y
    local ux, uy = 0, 1

    if not onScreen then
        local dx, dy = sp.X - cx, sp.Y - cy
        if sp.Z <= 0 then dx, dy = -dx, -dy end
        local mag = math.sqrt(dx * dx + dy * dy)
        if mag < 1 then dx, dy, mag = 0, 1, 1 end
        ux, uy = dx / mag, dy / mag

        -- Ray/box intersection against an inset rectangle so the icon stays
        -- clear of the toast (bottom-left) and the Safe Test notice (bottom).
        local minX, maxX = 80, vp.X - 80
        local minY, maxY = 90, vp.Y - 220
        local t = math.huge
        if ux > 0.0001 then t = math.min(t, (maxX - cx) / ux)
        elseif ux < -0.0001 then t = math.min(t, (minX - cx) / ux) end
        if uy > 0.0001 then t = math.min(t, (maxY - cy) / uy)
        elseif uy < -0.0001 then t = math.min(t, (minY - cy) / uy) end
        if t == math.huge or t < 0 then t = 0 end
        nx, ny = cx + ux * t, cy + uy * t
    end

    local pulse = 0.5 + 0.5 * math.sin(tick() * 5)

    if onScreen then
        circle(nx, ny, 14 + pulse * 5, SAFE_GREEN, 0.18 + (1 - pulse) * 0.25, 70, false, 1.5)
        circle(nx, ny, 8, SAFE_GREEN, 1, 71, true, 1)
        circle(nx, ny, 4, SAFE_WHITE, 1, 72, true, 1)
        line(nx, ny + 8, nx, ny + 22, SAFE_GREEN, 1, 71, 2)
        txt(nx, ny + 23, 12, "START", SAFE_WHITE, Drawing.Fonts.UI, 0, 73, true, true)
        txt(nx, ny + 37, 11, string.format("%.1f m", dist), SAFE_GREEN, Drawing.Fonts.UI, 0, 73, true, true)
    else
        local px, py = -uy, ux
        local tipX, tipY = nx + ux * 9, ny + uy * 9
        line(nx - ux * 3 - px * 7, ny - uy * 3 - py * 7, tipX, tipY, SAFE_GREEN, 1, 71, 3)
        line(nx - ux * 3 + px * 7, ny - uy * 3 + py * 7, tipX, tipY, SAFE_GREEN, 1, 71, 3)
        circle(nx, ny, 8, SAFE_GREEN, 0.85, 70, true, 1)
        txt(nx, ny + 14, 11, "START", SAFE_WHITE, Drawing.Fonts.UI, 0, 72, true, true)
        txt(nx, ny + 27, 10, string.format("%.1f m", dist), SAFE_GREEN, Drawing.Fonts.UI, 0, 72, true, true)
    end
end

local function renderDraw()
    if not Drawing then return end
    if THEMES.applied ~= settings.theme then
        THEMES.apply(settings.theme)
    end
    if searchActive and HUMAN then
        HUMAN.WalkSpeed = 0
        HUMAN.JumpPower = 0
    end
    local mouse = UIS:GetMouseLocation()
    local hover = nil
    for i = #drawHits, 1, -1 do
        local h = drawHits[i]
        if inside(mouse.X, mouse.Y, h) then
            hover = h.id
            break
        end
    end
    drawHover = hover

    drawHits = {}
    drawCount = 0

    -- Draw the always-on elements first so their drawing-pool indices stay
    -- stable when the menu opens. Previously the menu was built first, which
    -- shifted the toast/HUD objects for one frame and made them flicker.
    buildToastPrimitives()
    buildHudPrimitives()
    buildPopupPrimitives()
    buildSafeTestMarker()
    buildSafeTestNotice()
    if drawMenuVisible then
        buildMenuPrimitives()
    end

    for i = drawCount + 1, #drawPool do
        drawPool[i].Visible = false
    end
end

drawInputBegan = function(inp)
    if not Drawing then return false end
    if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return false end
    -- A pending keybind must not swallow the next world click / pause input.
    if bindingControl then bindingControl = nil end
    local m = UIS:GetMouseLocation()

    if searchActive then
        local rect = GENV.__NexusSearchRect
        local inSearch = rect and m.X >= rect.x and m.X <= rect.x + rect.w
            and m.Y >= rect.y and m.Y <= rect.y + rect.h
        if not inSearch then
            if GENV.__NexusSetSearch then
                GENV.__NexusSetSearch(false)
            else
                searchActive = false
            end
        end
    end

    if drawToastVisible then
        local vp = drawViewport()
        local w = 320
        local x, y = 16, vp.Y - 56 - 16
        if m.X >= x + w - 32 and m.X <= x + w and m.Y >= y and m.Y <= y + 25 then
            drawToastVisible = false
            return true
        end
        if m.X >= x and m.X <= x + w - 34 and m.Y >= y and m.Y <= y + 56 then
            drawMenuVisible = true
            return true
        end
    end

    if not drawMenuVisible then return false end
    for i = #drawHits, 1, -1 do
        local h = drawHits[i]
        if inside(m.X, m.Y, h) then
            local id = tostring(h.id or "")
            local isDropdown = id == "theme_dropdown" or id:find("^theme_opt_")
                or id == "folder_dropdown" or id:find("^folder_opt_")
            if not isDropdown then
                themeMenuOpen = false
                folderMenuOpen = false
            end
            if h.fn then task.spawn(h.fn) end
            return true
        end
    end
    themeMenuOpen = false
    folderMenuOpen = false
    return false
end

drawInputChanged = function(inp)
    if drawDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
        local m = UIS:GetMouseLocation()
        drawMenuX = drawDragWX + (m.X - drawDragMX)
        drawMenuY = drawDragWY + (m.Y - drawDragMY)
        local vp = drawViewport()
        drawMenuX = math.clamp(drawMenuX, -drawW + 80, vp.X - 80)
        drawMenuY = math.clamp(drawMenuY, 0, vp.Y - 40)
    end
end

drawInputEnded = function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        drawDragging = false
    end
end

-- While the menu is open, release the mouse from Shift Lock / first person so
-- the Draw UI can actually be clicked. Restored when the menu closes.
local drawMouseUnlocked = false
local drawSavedMouseBehavior = nil
local drawSavedMouseIcon = true

local function applyDrawMouse()
    if not drawMenuVisible then
        if drawMouseUnlocked then
            pcall(function()
                UIS.MouseBehavior = drawSavedMouseBehavior or Enum.MouseBehavior.Default
                UIS.MouseIconEnabled = drawSavedMouseIcon
            end)
            drawMouseUnlocked = false
        end
        return
    end
    if not drawMouseUnlocked then
        drawSavedMouseBehavior = UIS.MouseBehavior
        drawSavedMouseIcon = UIS.MouseIconEnabled
        drawMouseUnlocked = true
    end
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end)
end

RunService:BindToRenderStep("NexusTASMenuMouse", Enum.RenderPriority.Camera.Value + 30, applyDrawMouse)

connect(UIS.InputChanged, function(inp)
    if drawInputChanged then drawInputChanged(inp) end
end)

connect(RunService.RenderStepped, renderDraw)

function drawShutdown()
    if GENV.__NexusSetSearch then pcall(GENV.__NexusSetSearch, false) end
    for _, obj in ipairs(drawPool) do
        pcall(function() obj:Remove() end)
    end
    drawPool = {}
    drawKinds = {}
    drawCount = 0
    drawHits = {}
end

end

task.spawn(function()
    local ok = false
    if STORE and STORE.loadSettings then
        ok = STORE.loadSettings()
    end
    local base = hasFileApi() and resolveFileBase() or nil
    if GENV.__NexusLoader then
        GENV.__NexusLoader.log("Settings: " .. (ok and "loaded" or "defaults"))
        GENV.__NexusLoader.log("Storage: " .. (base and (base .. STORE.root) or "session only"))
        GENV.__NexusLoader.log("Status: ready")
        if GENV.__NexusLoader.startCountdown then
            GENV.__NexusLoader.startCountdown()
        end
    end
end)

if _G.__NexusDebug then
    _G.__NexusDebug.beginCreate = function() enterCreate() end
    _G.__NexusDebug.beginRecord = function() unpauseNow() end
    _G.__NexusDebug.pauseRecord = function() pauseNow() end
    _G.__NexusDebug.beginTest = function() enterTest() end
    _G.__NexusDebug.goIdle = function() goIdle() end
    _G.__NexusDebug.folder = function(name)
        if type(name) == "string" and name ~= "" then
            GENV.__NexusStore.folder = name
        end
        return GENV.__NexusStore and GENV.__NexusStore.folder
    end
    _G.__NexusDebug.setSetting = function(key, value)
        if settings[key] ~= nil then
            settings[key] = value
            if GENV.__NexusStore and GENV.__NexusStore.saveSettings then
                GENV.__NexusStore.saveSettings()
            end
            return true
        end
        return false
    end
    _G.__NexusDebug.toggleMenu = function()
        toggleGui()
        return drawMenuVisible
    end
    _G.__NexusDebug.setTab = function(tab)
        drawTab = tostring(tab)
        drawMenuVisible = true
        return drawTab
    end
    _G.__NexusDebug.themeMenu = function(value)
        themeMenuOpen = value == nil and not themeMenuOpen or value == true
        return themeMenuOpen
    end
    _G.__NexusDebug.folderMenu = function(value)
        folderMenuOpen = value == nil and not folderMenuOpen or value == true
        return folderMenuOpen
    end
    _G.__NexusDebug.setYOffset = function(value)
        settings.yOffset = math.clamp(tonumber(value) or 0, -50, 50)
        return settings.yOffset
    end
end

if GENV.__NexusLoader and GENV.__NexusLoader.wait then
    GENV.__NexusLoader.wait()
end

setupGui()

-- ==================== START ====================
setupAnimateFork()
if not setfenv then
    warn("[NexusTAS] setfenv unavailable: hot re-inject may leave old animation handlers; rejoin once if animations double.")
end
mode = "idle"
paused = false
anchor(false)
pcall(function() LockAnimations:Fire(false) end)
if isR6() then
    setStatus("Ready - press 2 for Create")
else
    setStatus("R6 character required for animations")
end

-- ==================== HOT-SWAP SHUTDOWN ====================
_G.__NexusShutdown = function()
    if ghost.active and exitGhost then pcall(exitGhost) end
    cancelSafeTest()
    FORK_ID += 1
    _G.__NexusForkID = FORK_ID

    -- Flush the last save and the manifest before the instance is replaced.
    if GENV.__NexusLastSave then
        local last = GENV.__NexusLastSave
        if type(last) == "table" and last.path and last.json then
            pcall(function() writefile(last.path, last.json) end)
        end
    end
    if writeManifest then pcall(writeManifest) end
    if STORE and STORE.saveSettings then pcall(STORE.saveSettings) end

    for _, conn in ipairs(CONNECTIONS) do
        pcall(function() conn:Disconnect() end)
    end
    for i = #CONNECTIONS, 1, -1 do CONNECTIONS[i] = nil end

    pcall(function() RunService:UnbindFromRenderStep("NexusTASCamera") end)
    pcall(function() RunService:UnbindFromRenderStep("NexusTASSingleTick") end)
    pcall(function() RunService:UnbindFromRenderStep("NexusTASMenuMouse") end)

    cameraTarget = nil
    -- Keep the previous fork's automatic animation locked out. Its Humanoid
    -- signal handlers survive this instance, so we must not leave it unlocked.
    pcall(function() LockAnimations:Fire(true) end)
    pcall(function() LockShiftlock:Fire(false) end)

    if ANIMATE_SCRIPT then
        pcall(function() ANIMATE_SCRIPT.Disabled = false end)
    end
    if ANIMATOR then
        for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
            pcall(function() track:Stop(0.1) end)
        end
    end
    if HUMAN then
        pcall(function()
            HUMAN.Sit = false
            HUMAN.AutoRotate = originalAutoRotate
            HUMAN.WalkSpeed = originalWalkSpeed
            HUMAN.JumpPower = originalJumpPower
            HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
            HUMAN:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
    if ROOT then
        pcall(function()
            ROOT.Anchored = false
            ROOT.AssemblyLinearVelocity = Vector3.zero
            ROOT.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if drawShutdown then pcall(drawShutdown) end
    if TASRS then pcall(function() TASRS:Destroy() end) end
    _G.__NexusGuiScreen = nil
    _G.__NexusGui = nil
end
GENV.__NexusShutdown = _G.__NexusShutdown

print("[NexusTAS] Loaded v" .. VERSION .. " | R6 fork: " .. tostring(isR6()))
print("[NexusTAS] 1 Idle | 2 Create | 3 Test | LMB pause | V step | F/G frames | "
    .. keyName(CONTROLS.Menu) .. " menu")
