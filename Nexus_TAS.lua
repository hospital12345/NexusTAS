-- === SETTINGS ===
local RECORD_INTERVAL = 1/60
local SEEK_SPEED = 1 / RECORD_INTERVAL

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local PLAYER = Players.LocalPlayer
local CHARACTER = PLAYER.Character or PLAYER.CharacterAdded:Wait()
local ROOT = CHARACTER:WaitForChild("HumanoidRootPart")
local HUMAN = CHARACTER:WaitForChild("Humanoid")
local ANIMATOR = HUMAN:FindFirstChildOfClass("Animator") or HUMAN:WaitForChild("Animator")
local ANIMATE_SCRIPT = CHARACTER:FindFirstChild("Animate")

local CAMERA = workspace.CurrentCamera
local cameraLocked = true

local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

-- === KEYBINDS ===
local DEFAULT_BINDS = {
    idle         = Enum.KeyCode.One,
    create       = Enum.KeyCode.Two,
    test         = Enum.KeyCode.Three,
    edittest     = Enum.KeyCode.Four,
    recordMouse  = Enum.UserInputType.MouseButton3,
    tick         = Enum.KeyCode.V,
    seekBack     = Enum.KeyCode.Q,
    seekFwd      = Enum.KeyCode.E,
    stepBack     = Enum.KeyCode.F,
    stepFwd      = Enum.KeyCode.G,
    removePauses = Enum.KeyCode.L,
    cameraLock   = Enum.KeyCode.C,
    clear        = Enum.KeyCode.F3,
    save         = Enum.KeyCode.F4,
    toggleGui    = Enum.KeyCode.F2,
    toggleHud    = Enum.KeyCode.F5,
    edittestPlay = Enum.KeyCode.Space,
}

local keybinds = {}
for k, v in pairs(DEFAULT_BINDS) do keybinds[k] = v end

local listeningForBind = nil

local function bindToString(bind)
    if not bind then return "?" end
    if typeof(bind) == "EnumItem" then
        if bind.EnumType == Enum.KeyCode then
            local n = bind.Name
            local numMap = {One="1",Two="2",Three="3",Four="4",Five="5",Six="6",
                Seven="7",Eight="8",Nine="9",Zero="0"}
            return numMap[n] or n
        elseif bind.EnumType == Enum.UserInputType then
            local n = bind.Name
            if n == "MouseButton1" then return "LMB" end
            if n == "MouseButton2" then return "RMB" end
            if n == "MouseButton3" then return "MMB" end
            return n
        end
    end
    return tostring(bind)
end

local function inputMatchesBind(input, bind)
    if not bind or typeof(bind) ~= "EnumItem" then return false end
    if bind.EnumType == Enum.KeyCode then
        return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind
    elseif bind.EnumType == Enum.UserInputType then
        return input.UserInputType == bind
    end
    return false
end

local function isTasKey(input)
    for _, bind in pairs(keybinds) do
        if inputMatchesBind(input, bind) then return true end
    end
    return false
end

-- === STATE ===
local state = "idle"
local isRecording = false
local isPaused = false
local isSeeking = false
local seekDirection = 0
local seekAccumulator = 0
local recordedData = {}
local playIndex = 0
local playStartTime = 0
local originalWalkSpeed = HUMAN.WalkSpeed
local originalJumpPower = HUMAN.JumpPower
local originalAutoRotate = HUMAN.AutoRotate

local recordingClock = 0
local frozenFrame = nil
local transitioning = false
local stepRequested = false
local manualTick = false

local pendingInputs = {}
local replayingInputs = false
local lastInputFrameIndex = 0
local activeReplayInputs = {}

-- === ANIMATIONS ===
local pendingAnimSync = nil
local frozenTracks = {}

local function freezeAnimations()
    if not ANIMATOR then return end
    for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
        if track.IsPlaying then
            if not frozenTracks[track] then
                local s = track.Speed
                if not s or s <= 0 then s = 1 end
                frozenTracks[track] = { speed = s }
            end
            if track.Speed ~= 0 then track:AdjustSpeed(0) end
        end
    end
end
local function clearFrozen() frozenTracks = {} end

local function captureTargetAnim()
    if not ANIMATOR then return nil end
    local best = nil
    for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
        if track.IsPlaying and track.Animation and track.Animation.AnimationId then
            local s = track.Speed
            if frozenTracks[track] then s = frozenTracks[track].speed end
            if not s or s <= 0 then s = 1 end
            local tp = track.TimePosition
            if not best or tp > best.timePos then
                best = { animId = track.Animation.AnimationId, timePos = tp, speed = s }
            end
        end
    end
    return best
end

local function setAnimateEnabled(enabled)
    if ANIMATE_SCRIPT then ANIMATE_SCRIPT.Disabled = not enabled end
end
local function setAutoRotate(enabled)
    if HUMAN then HUMAN.AutoRotate = enabled end
end
local function currentCamera()
    local cam = workspace.CurrentCamera
    if cam then CAMERA = cam end
    return CAMERA
end
local function captureCamera()
    local cam = currentCamera()
    if not cam then return CFrame.new(), 70 end
    return cam.CFrame, cam.FieldOfView
end

local function capturePlayingAnims()
    local result = {}
    if not ANIMATOR then return result end
    for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
        if track.IsPlaying and track.Animation and track.Animation.AnimationId then
            local speed = track.Speed
            if frozenTracks[track] then speed = frozenTracks[track].speed end
            if not speed or speed <= 0 then speed = 1 end
            table.insert(result, {
                id = track.Animation.AnimationId,
                speed = speed,
                timePosition = track.TimePosition,
            })
        end
    end
    return result
end

local function applyAnimations(anims, noFade)
    if not ANIMATOR then return end
    anims = anims or {}
    local wanted = {}
    for _, a in ipairs(anims) do wanted[a.id] = a end
    for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
        if track.IsPlaying and track.Animation then
            if not wanted[track.Animation.AnimationId] then
                track:Stop(noFade and 0 or 0.1)
            end
        end
    end
    for _, a in ipairs(anims) do
        local existing = nil
        for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
            if track.IsPlaying and track.Animation and track.Animation.AnimationId == a.id then
                existing = track; break
            end
        end
        if existing then
            existing.TimePosition = a.timePosition or 0
            existing:AdjustSpeed(a.speed or 1)
        else
            local anim = Instance.new("Animation")
            anim.AnimationId = a.id
            local track = ANIMATOR:LoadAnimation(anim)
            track:Play(noFade and 0 or 0.1)
            track.TimePosition = a.timePosition or 0
            track:AdjustSpeed(a.speed or 1)
        end
    end
end

local function captureCurrentPose()
    local camCF, camFOV = captureCamera()
    return {
        cf = ROOT and ROOT.CFrame or CFrame.new(),
        cameraCFrame = camCF,
        cameraFOV = camFOV,
        anims = capturePlayingAnims(),
        velocity = ROOT and ROOT.AssemblyLinearVelocity or Vector3.zero,
        rotVelocity = ROOT and ROOT.AssemblyAngularVelocity or Vector3.zero,
        humState = HUMAN and HUMAN:GetState() or Enum.HumanoidStateType.Freefall,
    }
end

-- === PHYSICS ===
local function zeroVelocity()
    if not ROOT then return end
    ROOT.Velocity = Vector3.zero
    ROOT.RotVelocity = Vector3.zero
    ROOT.AssemblyLinearVelocity = Vector3.zero
    ROOT.AssemblyAngularVelocity = Vector3.zero
end
local function setAnchored(anchored)
    if ROOT and ROOT.Anchored ~= anchored then ROOT.Anchored = anchored end
end
local function applyVelocityFromFrame(frame, alpha, nextFrame)
    if not ROOT or not frame then return end
    local v = frame.velocity or Vector3.zero
    local rv = frame.rotVelocity or Vector3.zero
    if nextFrame and nextFrame.velocity and alpha and alpha > 0 then
        v = v:Lerp(nextFrame.velocity, alpha)
    end
    if nextFrame and nextFrame.rotVelocity and alpha and alpha > 0 then
        rv = rv:Lerp(nextFrame.rotVelocity, alpha)
    end
    ROOT.AssemblyLinearVelocity = v
    ROOT.Velocity = v
    ROOT.AssemblyAngularVelocity = rv
    ROOT.RotVelocity = rv
end

local function findFrameAt(elapsed)
    local n = #recordedData
    if n == 0 then return nil, 0 end
    if elapsed <= recordedData[1].t then return 1, 0 end
    if elapsed >= recordedData[n].t then return n, 0 end
    local lo, hi = 1, n
    while lo < hi - 1 do
        local mid = (lo + hi) // 2
        if recordedData[mid].t <= elapsed then lo = mid else hi = mid end
    end
    local a, b = recordedData[lo], recordedData[hi]
    local alpha = 0
    if b.t > a.t then alpha = (elapsed - a.t) / (b.t - a.t) end
    return lo, alpha
end

-- === INPUT REPLAY ===
local function trackReplayInput(evt)
    local key
    if evt.inputType == Enum.UserInputType.Keyboard then
        key = "kb_" .. tostring(evt.keyCode)
    else
        key = tostring(evt.inputType)
    end
    if evt.phase == "began" then
        activeReplayInputs[key] = evt
    elseif evt.phase == "ended" then
        activeReplayInputs[key] = nil
    end
end

local function replayInputEvent(evt)
    if not VIM then return end
    local phase = evt.phase
    local it = evt.inputType
    if it == Enum.UserInputType.Keyboard then
        local down = (phase == "began")
        if phase == "began" or phase == "ended" then
            pcall(function() VIM:SendKeyEvent(down, evt.keyCode, false, game) end)
            trackReplayInput(evt)
        end
    elseif it == Enum.UserInputType.MouseButton1 then
        pcall(function() VIM:SendMouseButtonEvent(evt.position.X, evt.position.Y, 0, phase=="began", game, 1) end)
        trackReplayInput(evt)
    elseif it == Enum.UserInputType.MouseButton2 then
        pcall(function() VIM:SendMouseButtonEvent(evt.position.X, evt.position.Y, 1, phase=="began", game, 1) end)
        trackReplayInput(evt)
    elseif it == Enum.UserInputType.MouseButton3 then
        pcall(function() VIM:SendMouseButtonEvent(evt.position.X, evt.position.Y, 2, phase=="began", game, 1) end)
        trackReplayInput(evt)
    elseif it == Enum.UserInputType.MouseMovement then
        if phase == "changed" then
            pcall(function() VIM:SendMouseMoveEvent(evt.position.X, evt.position.Y, game) end)
        end
    elseif it == Enum.UserInputType.MouseWheel then
        if phase == "changed" and evt.delta then
            local forward = evt.delta.Z > 0
            pcall(function() VIM:SendMouseWheelEvent(evt.position.X, evt.position.Y, forward, game) end)
        end
    end
end

local function releaseAllReplayInputs()
    if not VIM then activeReplayInputs = {} return end
    for _, evt in pairs(activeReplayInputs) do
        local it = evt.inputType
        if it == Enum.UserInputType.Keyboard then
            pcall(function() VIM:SendKeyEvent(false, evt.keyCode, false, game) end)
        elseif it == Enum.UserInputType.MouseButton1 then
            pcall(function() VIM:SendMouseButtonEvent(evt.position.X, evt.position.Y, 0, false, game, 1) end)
        elseif it == Enum.UserInputType.MouseButton2 then
            pcall(function() VIM:SendMouseButtonEvent(evt.position.X, evt.position.Y, 1, false, game, 1) end)
        elseif it == Enum.UserInputType.MouseButton3 then
            pcall(function() VIM:SendMouseButtonEvent(evt.position.X, evt.position.Y, 2, false, game, 1) end)
        end
    end
    activeReplayInputs = {}
end

local function fireInputsUpTo(index)
    if index <= lastInputFrameIndex then return end
    for i = lastInputFrameIndex + 1, index do
        local frame = recordedData[i]
        if frame and frame.inputs then
            for _, evt in ipairs(frame.inputs) do
                replayingInputs = true
                replayInputEvent(evt)
                replayingInputs = false
            end
        end
    end
    lastInputFrameIndex = index
end

-- === APPLY FRAME ===
local function applyFrame(index, freeze, alpha)
    if index < 1 or index > #recordedData then return end
    local a = recordedData[index]
    if not a then return end
    local b = recordedData[index + 1] or a
    alpha = alpha or 0
    if freeze or alpha <= 0 then ROOT.CFrame = a.cf
    else ROOT.CFrame = a.cf:Lerp(b.cf, alpha) end
    applyVelocityFromFrame(a, alpha, b)
    if cameraLocked then
        local cam = currentCamera()
        if cam then
            if a.cameraCFrame and b.cameraCFrame and not freeze then
                cam.CFrame = a.cameraCFrame:Lerp(b.cameraCFrame, alpha)
            elseif a.cameraCFrame then cam.CFrame = a.cameraCFrame end
            if a.cameraFOV and b.cameraFOV and not freeze then
                cam.FieldOfView = a.cameraFOV + (b.cameraFOV - a.cameraFOV) * alpha
            elseif a.cameraFOV then cam.FieldOfView = a.cameraFOV end
        end
    end
    local anims = a.anims
    if freeze then
        if anims then applyAnimations(anims, true) end
        freezeAnimations()
        lastInputFrameIndex = index
    else
        if anims and b and b.anims and b.t > a.t and alpha > 0 then
            local dtSec = (b.t - a.t) * alpha
            local bById = {}
            for _, anim in ipairs(b.anims) do bById[anim.id] = anim end
            local out = {}
            for _, anim in ipairs(anims) do
                local bb = bById[anim.id]
                if bb then
                    table.insert(out, {
                        id = anim.id,
                        speed = anim.speed,
                        timePosition = anim.timePosition + dtSec * (anim.speed or 1),
                    })
                else
                    table.insert(out, anim)
                end
            end
            anims = out
        end
        applyAnimations(anims, false)
        fireInputsUpTo(index)
    end
    playIndex = index
end

local function setMovementEnabled(enabled)
    if not HUMAN then return end
    if enabled then
        HUMAN.WalkSpeed = originalWalkSpeed
        HUMAN.JumpPower = originalJumpPower
        HUMAN.Sit = false
    else
        HUMAN.WalkSpeed = 0
        HUMAN.JumpPower = 0
    end
end

-- === MODES ===
local function goIdle()
    if state == "idle" then return end
    releaseAllReplayInputs()
    clearFrozen()
    setAnimateEnabled(true)
    pendingAnimSync = nil
    if HUMAN then
        HUMAN.Sit = false
        HUMAN.AutoRotate = originalAutoRotate
        HUMAN.WalkSpeed = originalWalkSpeed
        HUMAN.JumpPower = originalJumpPower
        pcall(function() HUMAN:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    if ROOT then
        zeroVelocity(); setAnchored(false); zeroVelocity()
    end
    state="idle"; isRecording=false; isPaused=false; isSeeking=false
    seekDirection=0; seekAccumulator=0; frozenFrame=nil
    stepRequested=false; manualTick=false; pendingInputs={}; lastInputFrameIndex=0
end

local function enterCreate()
    if state == "create" then return end
    state="create"; isRecording=false; isPaused=true
    isSeeking=false; seekDirection=0; seekAccumulator=0
    setAnimateEnabled(false); setAutoRotate(false); setMovementEnabled(false); zeroVelocity()
    if #recordedData > 0 then
        local startIndex = #recordedData
        applyFrame(startIndex, true)
        frozenFrame = recordedData[startIndex]
    else
        playIndex = 0
        frozenFrame = captureCurrentPose()
        freezeAnimations()
    end
    setAnchored(true)
end

local function toggleRecording()
    if state ~= "create" and state ~= "edittest" then return end
    if not isPaused then
        if #pendingInputs > 0 and #recordedData > 0 then
            local lastFrame = recordedData[#recordedData]
            lastFrame.inputs = lastFrame.inputs or {}
            for _, inp in ipairs(pendingInputs) do table.insert(lastFrame.inputs, inp) end
        end
        pendingInputs = {}
        isRecording=false; isPaused=true
        setMovementEnabled(false); setAutoRotate(false); setAnimateEnabled(false)
        releaseAllReplayInputs()
        frozenFrame = captureCurrentPose()
        freezeAnimations()
        setAnchored(true)
        return
    end
    local targetAnim = captureTargetAnim()
    clearFrozen()
    pendingInputs = {}
    if playIndex < #recordedData then
        for i = #recordedData, playIndex + 1, -1 do table.remove(recordedData, i) end
    end
    if playIndex > 0 and recordedData[playIndex] then
        recordingClock = recordedData[playIndex].t
    else recordingClock = 0 end
    local currentCF = ROOT.CFrame
    local anims = capturePlayingAnims()
    local vNow = ROOT.AssemblyLinearVelocity
    local rvNow = ROOT.AssemblyAngularVelocity
    local stNow = HUMAN and HUMAN:GetState() or Enum.HumanoidStateType.Freefall
    local cf, fov = captureCamera()
    table.insert(recordedData, {
        cf=currentCF, cameraCFrame=cf, cameraFOV=fov, anims=anims,
        t=recordingClock, velocity=vNow, rotVelocity=rvNow, humState=stNow, inputs={},
    })
    playIndex = #recordedData
    frozenFrame = nil
    transitioning = true
    if HUMAN then
        HUMAN.Sit = false
        HUMAN.JumpPower = originalJumpPower
        HUMAN.AutoRotate = originalAutoRotate
        HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    end
    setAnchored(false)
    local lastFrame = recordedData[playIndex]
    applyVelocityFromFrame(lastFrame, 0, nil)
    if HUMAN and lastFrame.humState then
        pcall(function() HUMAN:ChangeState(lastFrame.humState) end)
    end
    setAnimateEnabled(true)
    if HUMAN then HUMAN.WalkSpeed = originalWalkSpeed end
    if targetAnim then
        pendingAnimSync = {
            animId = targetAnim.animId,
            timePos = targetAnim.timePos,
            speed = targetAnim.speed,
            frames = 60,
        }
    end
    RunService.Heartbeat:Wait()
    RunService.RenderStepped:Wait()
    if HUMAN then HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
    isRecording = true; isPaused = false; transitioning = false
end

local function recordFrame()
    if not isRecording or not ROOT then return end
    local cf = ROOT.CFrame
    local anims = capturePlayingAnims()
    local v = ROOT.AssemblyLinearVelocity
    local rv = ROOT.AssemblyAngularVelocity
    local st = HUMAN and HUMAN:GetState() or Enum.HumanoidStateType.Freefall
    if playIndex < #recordedData then
        for i = #recordedData, playIndex + 1, -1 do table.remove(recordedData, i) end
    end
    local camCF, camFOV = captureCamera()
    table.insert(recordedData, {
        cf=cf, cameraCFrame=camCF, cameraFOV=camFOV, anims=anims,
        t=recordingClock, velocity=v, rotVelocity=rv, humState=st, inputs=pendingInputs,
    })
    pendingInputs = {}
    playIndex = #recordedData
end

-- === SEEK ===
local function startSeek(direction)
    if (state ~= "create" and state ~= "edittest") or not isPaused then return end
    if #recordedData == 0 then return end
    isSeeking=true; seekDirection=direction; seekAccumulator=0
end
local function stopSeek()
    isSeeking=false; seekDirection=0; seekAccumulator=0
    if playIndex >= 1 and recordedData[playIndex] then frozenFrame = recordedData[playIndex] end
end
local function stepSeek(dt)
    if not isSeeking or seekDirection == 0 then return end
    seekAccumulator = seekAccumulator + dt * SEEK_SPEED
    local steps = math.floor(seekAccumulator)
    if steps > 0 then
        seekAccumulator = seekAccumulator - steps
        local newIndex = math.clamp(playIndex + (seekDirection * steps), 1, #recordedData)
        if newIndex ~= playIndex then
            applyFrame(newIndex, true)
            frozenFrame = recordedData[newIndex]
        end
    end
end

local function enterTest()
    if state == "test" then goIdle() return end
    if #recordedData == 0 then return end
    clearFrozen()
    setAnimateEnabled(false); setAutoRotate(false)
    pendingAnimSync = nil
    state = "test"; isRecording=false; isPaused=false; isSeeking=false
    playIndex = 1
    playStartTime = tick() - (recordedData[1].t or 0)
    frozenFrame = nil
    lastInputFrameIndex = 0
    zeroVelocity(); setMovementEnabled(false); setAnchored(false)
    applyFrame(1, false, 0)
end
local function updateTest()
    if state ~= "test" then return end
    local elapsed = tick() - playStartTime
    local last = recordedData[#recordedData]
    if last and elapsed >= last.t then
        applyFrame(#recordedData, false, 0)
        setAnimateEnabled(true)
        goIdle()
        return
    end
    local idx, alpha = findFrameAt(elapsed)
    if idx then applyFrame(idx, false, alpha) end
end

local function enterEdittest()
    if state == "edittest" then goIdle() return end
    if #recordedData == 0 then return end
    clearFrozen(); setAnimateEnabled(false); setAutoRotate(false)
    pendingAnimSync = nil
    state="edittest"; isRecording=false; isPaused=true; isSeeking=false
    seekDirection=0; seekAccumulator=0; lastInputFrameIndex=0
    playIndex = 1
    applyFrame(playIndex, true)
    frozenFrame = recordedData[playIndex]
    setAnchored(true)
    zeroVelocity(); setMovementEnabled(false)
end

local function toggleEdittestPlayback()
    if state ~= "edittest" or isRecording then return end
    if isPaused then
        transitioning = true
        clearFrozen()
        pendingAnimSync = nil
        if HUMAN then HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end
        setAnimateEnabled(false); setAutoRotate(false); setMovementEnabled(false)
        if playIndex >= #recordedData then playIndex = 1 end
        setAnchored(false)
        lastInputFrameIndex = playIndex - 1
        applyFrame(playIndex, false, 0)
        RunService.Heartbeat:Wait()
        RunService.RenderStepped:Wait()
        if HUMAN then HUMAN:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
        isPaused = false; isRecording = false; frozenFrame = nil
        local frameT = (recordedData[playIndex] and recordedData[playIndex].t) or 0
        playStartTime = tick() - frameT
        transitioning = false
    else
        local elapsed = tick() - playStartTime
        local idx, alpha = findFrameAt(elapsed)
        if idx and recordedData[idx] then
            local a = recordedData[idx]
            local b = recordedData[idx + 1] or a
            local camCF, camFOV
            if a.cameraCFrame and b.cameraCFrame then camCF = a.cameraCFrame:Lerp(b.cameraCFrame, alpha)
            else camCF = a.cameraCFrame end
            if a.cameraFOV and b.cameraFOV then camFOV = a.cameraFOV + (b.cameraFOV - a.cameraFOV) * alpha
            else camFOV = a.cameraFOV end
            frozenFrame = { cf=a.cf:Lerp(b.cf,alpha), cameraCFrame=camCF, cameraFOV=camFOV,
                anims=a.anims, velocity=a.velocity, rotVelocity=a.rotVelocity, humState=a.humState }
            playIndex = idx
        end
        isPaused = true; setAnimateEnabled(false)
        applyFrame(playIndex, true)
        frozenFrame = frozenFrame or recordedData[playIndex]
        freezeAnimations()
        setAnchored(true)
        releaseAllReplayInputs()
    end
end

local function updateEdittest()
    if state ~= "edittest" or isPaused or isRecording then return end
    local elapsed = tick() - playStartTime
    local last = recordedData[#recordedData]
    if last and elapsed >= last.t then
        playIndex = #recordedData
        applyFrame(playIndex, true)
        frozenFrame = recordedData[playIndex]
        isPaused = true; setAnimateEnabled(false)
        freezeAnimations(); setAnchored(true)
        releaseAllReplayInputs()
        return
    end
    local idx, alpha = findFrameAt(elapsed)
    if idx then applyFrame(idx, false, alpha) end
end

-- === SINGLE PHYSICS TICK ===
local function stepOnePhysicsTick()
    if state ~= "create" then return end
    if not isPaused or isRecording or manualTick then return end
    task.spawn(function()
        while transitioning do RunService.Heartbeat:Wait() end
        transitioning = true
        manualTick = true
        clearFrozen()
        pendingInputs = {}
        if playIndex < #recordedData then
            for i = #recordedData, playIndex + 1, -1 do table.remove(recordedData, i) end
        end
        if playIndex > 0 and recordedData[playIndex] then recordingClock = recordedData[playIndex].t
        else recordingClock = 0 end
        if #recordedData == 0 then
            local camCF, camFOV = captureCamera()
            table.insert(recordedData, {
                cf=ROOT.CFrame, cameraCFrame=camCF, cameraFOV=camFOV,
                anims=capturePlayingAnims(), t=0,
                velocity=ROOT.AssemblyLinearVelocity,
                rotVelocity=ROOT.AssemblyAngularVelocity,
                humState = HUMAN and HUMAN:GetState() or Enum.HumanoidStateType.Freefall,
                inputs = {},
            })
            playIndex = #recordedData
        end
        local lastFrame = recordedData[playIndex]
        if not lastFrame then manualTick=false; transitioning=false; return end
        local lv  = lastFrame.velocity    or Vector3.zero
        local lrv = lastFrame.rotVelocity or Vector3.zero
        if HUMAN then
            HUMAN.Sit = false; HUMAN.AutoRotate = false
            HUMAN.WalkSpeed = originalWalkSpeed; HUMAN.JumpPower = originalJumpPower
        end
        setAnimateEnabled(true)
        isPaused = false; isRecording = false
        setAnchored(false)
        if HUMAN and lastFrame.humState then
            pcall(function() HUMAN:ChangeState(lastFrame.humState) end)
        end
        RunService.PreSimulation:Wait()
        ROOT.AssemblyLinearVelocity  = lv
        ROOT.AssemblyAngularVelocity = lrv
        local dt = RunService.PostSimulation:Wait()
        local cf = ROOT.CFrame
        local v  = ROOT.AssemblyLinearVelocity
        local rv = ROOT.AssemblyAngularVelocity
        local st = HUMAN and HUMAN:GetState() or Enum.HumanoidStateType.Freefall
        local anims = capturePlayingAnims()
        local camCF, camFOV = captureCamera()
        isPaused = true
        setAnchored(true)
        recordingClock = recordingClock + dt
        table.insert(recordedData, {
            cf=cf, cameraCFrame=camCF, cameraFOV=camFOV, anims=anims,
            t=recordingClock, velocity=v, rotVelocity=rv, humState=st, inputs=pendingInputs,
        })
        playIndex = #recordedData
        pendingInputs = {}
        setMovementEnabled(false); setAutoRotate(false); setAnimateEnabled(false)
        frozenFrame = recordedData[playIndex]
        freezeAnimations()
        manualTick = false
        transitioning = false
    end)
end

local function requestSingleStep()
    if not isPaused then return end
    if state ~= "create" and state ~= "edittest" then return end
    if #recordedData == 0 then return end
    if stepRequested then return end
    stepRequested = true
    task.spawn(function()
        if state == "create" then toggleRecording()
        elseif state == "edittest" then toggleEdittestPlayback() end
    end)
end

-- === REMOVE PAUSES ===
local function removePauses()
    if #recordedData < 3 then return end
    local POS_THRESHOLD, ROT_THRESHOLD = 0.05, 0.01
    local isIdle = {}; isIdle[1] = false
    for i = 2, #recordedData do
        local prev = recordedData[i - 1]; local curr = recordedData[i]
        local posDiff = (curr.cf.Position - prev.cf.Position).Magnitude
        local rotDiff = (curr.cf.LookVector - prev.cf.LookVector).Magnitude
        isIdle[i] = (posDiff < POS_THRESHOLD and rotDiff < ROT_THRESHOLD)
    end
    local newData = {}; local removed = 0; local i = 1
    while i <= #recordedData do
        if isIdle[i] then
            local j = i
            while j + 1 <= #recordedData and isIdle[j + 1] do j = j + 1 end
            table.insert(newData, recordedData[i])
            removed = removed + (j - i)
            local keptFrame = newData[#newData]
            keptFrame.inputs = keptFrame.inputs or {}
            for k = i + 1, j do
                local f = recordedData[k]
                if f and f.inputs then
                    for _, inp in ipairs(f.inputs) do table.insert(keptFrame.inputs, inp) end
                end
            end
            i = j + 1
        else
            table.insert(newData, recordedData[i]); i = i + 1
        end
    end
    for idx, frame in ipairs(newData) do frame.t = (idx - 1) * RECORD_INTERVAL end
    recordedData = newData
    playIndex = math.clamp(playIndex, 1, #recordedData)
    frozenFrame = recordedData[playIndex]
    recordingClock = recordedData[#recordedData].t
    lastInputFrameIndex = 0
    if ROOT then ROOT.CFrame = recordedData[playIndex].cf end
end

-- === CLEAR / SERIALIZE ===
local function clearRecording()
    if state ~= "idle" then goIdle() end
    recordedData = {}; playIndex = 0; recordingClock = 0
    frozenFrame = nil; pendingAnimSync = nil; pendingInputs = {}
    lastInputFrameIndex = 0; clearFrozen()
end

local function serializeValue(v, out)
    local tv = type(v)
    if tv == "number" then
        if v ~= v then out[#out+1] = "(0/0)"
        elseif v == math.huge then out[#out+1] = "math.huge"
        elseif v == -math.huge then out[#out+1] = "-math.huge"
        else out[#out+1] = string.format("%.9g", v) end
    elseif tv == "string" then out[#out+1] = string.format("%q", v)
    elseif tv == "boolean" then out[#out+1] = tostring(v)
    elseif tv == "nil" then out[#out+1] = "nil"
    elseif tv == "table" then
        out[#out+1] = "{"
        for k, val in pairs(v) do
            if type(k) == "number" then out[#out+1] = "[" .. string.format("%d", k) .. "]="
            else out[#out+1] = "[" .. string.format("%q", tostring(k)) .. "]=" end
            serializeValue(val, out)
            out[#out+1] = ","
        end
        out[#out+1] = "}"
    else
        local t = typeof(v)
        if t == "Vector3" then
            out[#out+1] = string.format("Vector3.new(%.9g,%.9g,%.9g)", v.X, v.Y, v.Z)
        elseif t == "Vector2" then
            out[#out+1] = string.format("Vector2.new(%.9g,%.9g)", v.X, v.Y)
        elseif t == "CFrame" then
            local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22 = v:GetComponents()
            out[#out+1] = string.format(
                "CFrame.new(%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g,%.9g)",
                x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22)
        elseif t == "EnumItem" then out[#out+1] = tostring(v)
        else out[#out+1] = "nil" end
    end
end

local function serializeRecording()
    local out = {}
    serializeValue(recordedData, out)
    return table.concat(out)
end

local function saveToClipboard()
    if #recordedData == 0 then return end
    local data = serializeRecording()
    pcall(function()
        if setclipboard then setclipboard(data)
        elseif toclipboard then toclipboard(data) end
    end)
end

local function importRecording(str)
    if type(str) ~= "string" or #str == 0 then return false end
    local fn = loadstring("return " .. str)
    if not fn then return false end
    local ok, result = pcall(fn)
    if not ok or type(result) ~= "table" then return false end
    local newData = {}
    for i = 1, #result do
        local f = result[i]
        if type(f) == "table" and typeof(f.cf) == "CFrame" then
            newData[#newData+1] = {
                cf=f.cf, cameraCFrame=f.cameraCFrame, cameraFOV=f.cameraFOV,
                anims=f.anims or {}, t=f.t or 0,
                velocity=f.velocity or Vector3.zero,
                rotVelocity=f.rotVelocity or Vector3.zero,
                humState=f.humState or Enum.HumanoidStateType.Freefall,
                inputs=f.inputs or {},
            }
        end
    end
    if #newData == 0 then return false end
    if state ~= "idle" then goIdle() end
    recordedData = newData
    playIndex = 0
    recordingClock = recordedData[#recordedData].t or 0
    frozenFrame = nil; pendingAnimSync = nil; pendingInputs = {}
    lastInputFrameIndex = 0; clearFrozen()
    return true
end

_G.importReplay = importRecording
if getgenv then getgenv().importReplay = importRecording end
if shared  then shared.importReplay  = importRecording end

-- === INPUT HANDLERS ===
local function pushRecordedInput(input, phase)
    if listeningForBind then return end
    if not isRecording and not manualTick then return end
    if replayingInputs then return end
    if isTasKey(input) then return end
    table.insert(pendingInputs, {
        phase = phase,
        inputType = input.UserInputType,
        keyCode = input.KeyCode,
        position = input.Position,
        delta = input.Delta,
    })
end

UserInputService.InputBegan:Connect(function(input, processed)
    if listeningForBind then
        local captured
        if input.UserInputType == Enum.UserInputType.Keyboard then
            captured = input.KeyCode
        elseif input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.MouseButton3 then
            captured = input.UserInputType
        end
        if captured then
            keybinds[listeningForBind] = captured
            local changed = listeningForBind
            listeningForBind = nil
            if _G.__NexusOnBindChanged then _G.__NexusOnBindChanged(changed) end
        end
        return
    end

    pushRecordedInput(input, "began")

    if transitioning or replayingInputs then return end

    if inputMatchesBind(input, keybinds.recordMouse) then
        if state == "create" or state == "edittest" then toggleRecording() end
        return
    end

    if inputMatchesBind(input, keybinds.edittestPlay) and state == "edittest" then
        toggleEdittestPlayback()
        return
    end

    if processed then return end

    if inputMatchesBind(input, keybinds.idle) then goIdle()
    elseif inputMatchesBind(input, keybinds.create) then enterCreate()
    elseif inputMatchesBind(input, keybinds.test) then enterTest()
    elseif inputMatchesBind(input, keybinds.edittest) then enterEdittest()
    elseif inputMatchesBind(input, keybinds.removePauses) then
        if state == "create" and isPaused then removePauses() end
    elseif inputMatchesBind(input, keybinds.seekBack) then
        if (state=="create" or state=="edittest") and isPaused and #recordedData>0 then startSeek(-1) end
    elseif inputMatchesBind(input, keybinds.seekFwd) then
        if (state=="create" or state=="edittest") and isPaused and #recordedData>0 then startSeek(1) end
    elseif inputMatchesBind(input, keybinds.stepFwd) then
        if (state=="create" or state=="edittest") and isPaused and #recordedData>0 then
            local ni = math.min(playIndex + 1, #recordedData)
            if ni ~= playIndex then applyFrame(ni, true); frozenFrame = recordedData[ni] end
        end
    elseif inputMatchesBind(input, keybinds.stepBack) then
        if (state=="create" or state=="edittest") and isPaused and #recordedData>0 then
            local ni = math.max(playIndex - 1, 1)
            if ni ~= playIndex then applyFrame(ni, true); frozenFrame = recordedData[ni] end
        end
    elseif inputMatchesBind(input, keybinds.tick) then
        if state == "create" then stepOnePhysicsTick() else requestSingleStep() end
    elseif inputMatchesBind(input, keybinds.cameraLock) then
        cameraLocked = not cameraLocked
        if _G.__NexusUpdateCamBtn then _G.__NexusUpdateCamBtn() end
    elseif inputMatchesBind(input, keybinds.clear) then
        clearRecording()
    elseif inputMatchesBind(input, keybinds.save) then
        saveToClipboard()
    elseif inputMatchesBind(input, keybinds.toggleGui) then
        if _G.__NexusScreen then _G.__NexusScreen.Enabled = not _G.__NexusScreen.Enabled end
    elseif inputMatchesBind(input, keybinds.toggleHud) then
        if _G.__NexusHudScreen then _G.__NexusHudScreen.Enabled = not _G.__NexusHudScreen.Enabled end
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if listeningForBind then return end
    pushRecordedInput(input, "ended")
    if processed then return end
    if inputMatchesBind(input, keybinds.seekBack) or inputMatchesBind(input, keybinds.seekFwd) then
        if isSeeking then stopSeek() end
    end
end)

UserInputService.InputChanged:Connect(function(input, processed)
    if listeningForBind then return end
    pushRecordedInput(input, "changed")
end)

-- === MAIN LOOP ===
RunService.Heartbeat:Connect(function(dt)
    if pendingAnimSync and ANIMATOR then
        local applied = false
        for _, track in pairs(ANIMATOR:GetPlayingAnimationTracks()) do
            if track.IsPlaying and track.Animation
                and track.Animation.AnimationId == pendingAnimSync.animId then
                track.TimePosition = pendingAnimSync.timePos
                if pendingAnimSync.speed then track:AdjustSpeed(pendingAnimSync.speed) end
                applied = true; break
            end
        end
        if applied then pendingAnimSync = nil
        else
            pendingAnimSync.frames = pendingAnimSync.frames - 1
            if pendingAnimSync.frames <= 0 then pendingAnimSync = nil end
        end
    end
    if transitioning then return end
    if isRecording and not manualTick then
        recordingClock = recordingClock + dt
        recordFrame()
    end
    if state == "test" then updateTest()
    elseif state == "edittest" then updateEdittest() end
    if (state == "create" or state == "edittest") and isPaused and isSeeking then stepSeek(dt) end

    local shouldAnchor = (state == "create" or state == "edittest")
        and isPaused and not isRecording and not manualTick
    if ROOT and ROOT.Anchored ~= shouldAnchor then ROOT.Anchored = shouldAnchor end
    if shouldAnchor then
        local frame = frozenFrame
        if not frame and playIndex >= 1 then frame = recordedData[playIndex] end
        if frame and frame.cf and ROOT then ROOT.CFrame = frame.cf end
        if frame then applyVelocityFromFrame(frame, 0, nil) end
        if isPaused and not isSeeking then freezeAnimations() end
    end
    local disableAutoRotate = false
    if state == "create" and isPaused then disableAutoRotate = true
    elseif state == "test" then disableAutoRotate = true
    elseif state == "edittest" and not isRecording then disableAutoRotate = true end
    if disableAutoRotate and HUMAN and HUMAN.AutoRotate then HUMAN.AutoRotate = false end

    if (state=="create" or state=="edittest") and isPaused and frozenFrame and cameraLocked then
        local cam = currentCamera()
        if cam then
            if frozenFrame.cameraCFrame then cam.CFrame = frozenFrame.cameraCFrame end
            if frozenFrame.cameraFOV then cam.FieldOfView = frozenFrame.cameraFOV end
        end
    end

    if stepRequested and not transitioning and not isPaused then
        stepRequested = false
        if state == "create" then toggleRecording()
        elseif state == "edittest" then toggleEdittestPlayback() end
    end
end)

-- === RESPAWN ===
PLAYER.CharacterAdded:Connect(function(newChar)
    clearFrozen(); pendingAnimSync = nil
    transitioning=false; stepRequested=false; manualTick=false
    pendingInputs={}; lastInputFrameIndex=0; activeReplayInputs={}
    CHARACTER = newChar
    ROOT = CHARACTER:WaitForChild("HumanoidRootPart")
    HUMAN = CHARACTER:WaitForChild("Humanoid")
    ANIMATOR = HUMAN:FindFirstChildOfClass("Animator") or HUMAN:WaitForChild("Animator")
    ANIMATE_SCRIPT = CHARACTER:FindFirstChild("Animate")
    originalWalkSpeed = HUMAN.WalkSpeed
    originalJumpPower = HUMAN.JumpPower
    originalAutoRotate = HUMAN.AutoRotate
    CAMERA = workspace.CurrentCamera
    state="idle"; isRecording=false; isPaused=false; isSeeking=false
    recordingClock=0; frozenFrame=nil
    setAnchored(false)
end)

-- ============================================================
-- ========================  GUI  =============================
-- ============================================================
do
    local GuiThemes = {
        Midnight = { bg=Color3.fromRGB(13,13,18), panel=Color3.fromRGB(20,20,28), panelAlt=Color3.fromRGB(28,28,38),
            button=Color3.fromRGB(34,34,46), buttonHover=Color3.fromRGB(46,46,60),
            accent=Color3.fromRGB(130,100,255), accentHover=Color3.fromRGB(155,125,255),
            text=Color3.fromRGB(242,242,250), subtext=Color3.fromRGB(140,140,165),
            border=Color3.fromRGB(45,45,60),
            success=Color3.fromRGB(80,220,130), danger=Color3.fromRGB(255,90,100), warning=Color3.fromRGB(255,190,90) },
        Ocean = { bg=Color3.fromRGB(10,18,28), panel=Color3.fromRGB(16,26,38), panelAlt=Color3.fromRGB(22,36,52),
            button=Color3.fromRGB(28,42,60), buttonHover=Color3.fromRGB(40,58,80),
            accent=Color3.fromRGB(80,180,255), accentHover=Color3.fromRGB(110,200,255),
            text=Color3.fromRGB(230,245,255), subtext=Color3.fromRGB(120,150,180),
            border=Color3.fromRGB(35,55,78),
            success=Color3.fromRGB(80,220,180), danger=Color3.fromRGB(255,100,110), warning=Color3.fromRGB(255,200,100) },
        Sakura = { bg=Color3.fromRGB(24,14,22), panel=Color3.fromRGB(34,20,30), panelAlt=Color3.fromRGB(46,28,40),
            button=Color3.fromRGB(52,32,46), buttonHover=Color3.fromRGB(70,44,60),
            accent=Color3.fromRGB(255,120,180), accentHover=Color3.fromRGB(255,150,200),
            text=Color3.fromRGB(255,235,245), subtext=Color3.fromRGB(190,150,175),
            border=Color3.fromRGB(72,46,62),
            success=Color3.fromRGB(140,220,160), danger=Color3.fromRGB(255,100,120), warning=Color3.fromRGB(255,200,130) },
        Matrix = { bg=Color3.fromRGB(8,14,10), panel=Color3.fromRGB(14,22,16), panelAlt=Color3.fromRGB(20,32,24),
            button=Color3.fromRGB(22,36,26), buttonHover=Color3.fromRGB(32,50,38),
            accent=Color3.fromRGB(80,230,120), accentHover=Color3.fromRGB(110,255,150),
            text=Color3.fromRGB(210,255,220), subtext=Color3.fromRGB(110,150,120),
            border=Color3.fromRGB(30,50,36),
            success=Color3.fromRGB(80,230,120), danger=Color3.fromRGB(255,100,100), warning=Color3.fromRGB(255,210,100) },
        Sunset = { bg=Color3.fromRGB(28,16,14), panel=Color3.fromRGB(38,22,18), panelAlt=Color3.fromRGB(52,30,24),
            button=Color3.fromRGB(58,34,28), buttonHover=Color3.fromRGB(78,46,36),
            accent=Color3.fromRGB(255,140,70), accentHover=Color3.fromRGB(255,170,100),
            text=Color3.fromRGB(255,240,230), subtext=Color3.fromRGB(190,150,130),
            border=Color3.fromRGB(80,50,40),
            success=Color3.fromRGB(180,220,130), danger=Color3.fromRGB(255,100,90), warning=Color3.fromRGB(255,200,120) },
        Mono = { bg=Color3.fromRGB(12,12,12), panel=Color3.fromRGB(20,20,20), panelAlt=Color3.fromRGB(28,28,28),
            button=Color3.fromRGB(34,34,34), buttonHover=Color3.fromRGB(48,48,48),
            accent=Color3.fromRGB(230,230,230), accentHover=Color3.fromRGB(255,255,255),
            text=Color3.fromRGB(240,240,240), subtext=Color3.fromRGB(140,140,140),
            border=Color3.fromRGB(48,48,48),
            success=Color3.fromRGB(160,220,160), danger=Color3.fromRGB(230,100,100), warning=Color3.fromRGB(230,200,120) },
    }

    local C = GuiThemes.Midnight
    local themed = {}

    local function reg(obj, key, prop)
        prop = prop or "BackgroundColor3"
        table.insert(themed, {obj = obj, key = key, prop = prop})
        obj[prop] = C[key]
        return obj
    end

    local function applyTheme(name)
        if not GuiThemes[name] then return end
        C = GuiThemes[name]
        for _, t in ipairs(themed) do
            local col = C[t.key]
            if col and t.obj and t.obj.Parent then
                pcall(function()
                    TweenService:Create(t.obj, TweenInfo.new(0.22), {[t.prop] = col}):Play()
                end)
            end
        end
    end

    local function corner(p, r)
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p; return c
    end
    local function stroke(p, color, th)
        local s = Instance.new("UIStroke")
        s.Color = color or C.border; s.Thickness = th or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = p; return s
    end
    local function pad(p, n)
        local u = Instance.new("UIPadding")
        u.PaddingTop = UDim.new(0, n); u.PaddingBottom = UDim.new(0, n)
        u.PaddingLeft = UDim.new(0, n); u.PaddingRight = UDim.new(0, n)
        u.Parent = p; return u
    end
    local function tween(obj, time, props, style)
        if not obj or not obj.Parent then return end
        local t = TweenService:Create(obj,
            TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            props)
        t:Play(); return t
    end
    local function makeDraggable(frame, dragArea)
        local dragging, dragStart, startPos
        dragArea.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = frame.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
    end

    local parent = (gethui and gethui()) or game:GetService("CoreGui")
    local screen = Instance.new("ScreenGui")
    screen.Name = "NexusTAS"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() screen.Parent = parent end)
    if not screen.Parent then screen.Parent = PLAYER:WaitForChild("PlayerGui") end
    _G.__NexusScreen = screen

    -- ---------- WINDOW ----------
    local win = Instance.new("Frame")
    win.Name = "Window"
    win.Size = UDim2.new(0, 580, 0, 520)
    win.Position = UDim2.new(0.5, -290, 0.5, -260)
    win.BackgroundColor3 = C.bg
    win.BorderSizePixel = 0
    win.Active = true
    win.Parent = screen
    corner(win, 14)
    stroke(win, C.border, 1)
    reg(win, "bg")

    local shadow = Instance.new("ImageLabel")
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5028857084"
    shadow.ImageColor3 = Color3.new(0,0,0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(24,24,276,276)
    shadow.Size = UDim2.new(1, 40, 1, 40)
    shadow.Position = UDim2.new(0, -20, 0, -20)
    shadow.ZIndex = -1
    shadow.Parent = win

    -- ---------- HEADER ----------
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 46)
    header.BackgroundColor3 = C.panel
    header.BorderSizePixel = 0
    header.Parent = win
    corner(header, 14)
    reg(header, "panel")

    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 14)
    headerFix.Position = UDim2.new(0, 0, 1, -14)
    headerFix.BackgroundColor3 = C.panel
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header
    reg(headerFix, "panel")

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 18, 0.5, -5)
    dot.BackgroundColor3 = C.accent
    dot.BorderSizePixel = 0
    dot.Parent = header
    corner(dot, 5)
    reg(dot, "accent")

    local dotGlow = Instance.new("UIStroke")
    dotGlow.Color = C.accent
    dotGlow.Thickness = 3
    dotGlow.Transparency = 0.5
    dotGlow.Parent = dot
    task.spawn(function()
        while dot.Parent do
            tween(dotGlow, 1.2, {Transparency = 0.85})
            task.wait(1.2)
            tween(dotGlow, 1.2, {Transparency = 0.4})
            task.wait(1.2)
        end
    end)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 38, 0, 0)
    title.Size = UDim2.new(0, 220, 1, 0)
    title.Font = Enum.Font.GothamBold
    title.Text = "NexusTAS"
    title.TextSize = 15
    title.TextColor3 = C.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    reg(title, "text", "TextColor3")

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.new(0, 148, 0, 0)
    subtitle.Size = UDim2.new(0, 200, 1, 0)
    subtitle.Font = Enum.Font.Gotham
    subtitle.Text = "BETA V 1.0"
    subtitle.TextSize = 12
    subtitle.TextColor3 = C.subtext
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = header
    reg(subtitle, "subtext", "TextColor3")

    local function headerBtn(txt, order, onClick, hoverColorKey)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 30, 0, 30)
        b.Position = UDim2.new(1, -44 - order*36, 0.5, -15)
        b.BackgroundColor3 = C.button
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.Text = txt
        b.TextSize = 15
        b.TextColor3 = C.text
        b.AutoButtonColor = false
        b.Parent = header
        corner(b, 9)
        reg(b, "button")
        reg(b, "text", "TextColor3")
        b.MouseEnter:Connect(function()
            tween(b, 0.15, {BackgroundColor3 = C[hoverColorKey or "buttonHover"]})
        end)
        b.MouseLeave:Connect(function()
            tween(b, 0.15, {BackgroundColor3 = C.button})
        end)
        b.MouseButton1Click:Connect(function()
            pcall(onClick)
        end)
        return b
    end

    headerBtn("—", 0, function()
        local targetH = (win.Size.Y.Offset > 50) and 46 or 520
        tween(win, 0.25, {Size = UDim2.new(0, 580, 0, targetH)}, Enum.EasingStyle.Quart)
    end, "buttonHover")

    headerBtn("X", 1, function()
        screen.Enabled = false
    end, "danger")

    makeDraggable(win, header)

    -- ---------- TABS ----------
    local tabBar = Instance.new("Frame")
    tabBar.Position = UDim2.new(0, 14, 0, 56)
    tabBar.Size = UDim2.new(1, -28, 0, 38)
    tabBar.BackgroundColor3 = C.panelAlt
    tabBar.BorderSizePixel = 0
    tabBar.Parent = win
    corner(tabBar, 10)
    reg(tabBar, "panelAlt")
    stroke(tabBar, C.border, 1)

    local tabList = Instance.new("Frame")
    tabList.Size = UDim2.new(1, 0, 1, 0)
    tabList.BackgroundTransparency = 1
    tabList.Parent = tabBar
    local tl = Instance.new("UIListLayout")
    tl.FillDirection = Enum.FillDirection.Horizontal
    tl.Padding = UDim.new(0, 4)
    tl.Parent = tabList
    pad(tabList, 4)

    local content = Instance.new("Frame")
    content.Position = UDim2.new(0, 14, 0, 104)
    content.Size = UDim2.new(1, -28, 1, -166)
    content.BackgroundTransparency = 1
    content.Parent = win

    local pages = {}
    local function makeTab(name, label)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 0, 1, 0)
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.BackgroundColor3 = C.button
        btn.BackgroundTransparency = 1
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamSemibold
        btn.Text = "  " .. label .. "  "
        btn.TextSize = 12
        btn.TextColor3 = C.subtext
        btn.AutoButtonColor = false
        btn.Parent = tabList
        corner(btn, 7)
        reg(btn, "subtext", "TextColor3")

        local page = Instance.new("Frame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = content
        pages[name] = {btn = btn, page = page}

        btn.MouseButton1Click:Connect(function()
            for k, v in pairs(pages) do
                local active = (k == name)
                v.page.Visible = active
                tween(v.btn, 0.15, {
                    BackgroundTransparency = active and 0 or 1,
                    BackgroundColor3 = C.accent,
                    TextColor3 = active and Color3.fromRGB(255,255,255) or C.subtext,
                })
            end
        end)
        return page
    end

    local bindsPage    = makeTab("binds",    "Binds")
    local themePage    = makeTab("theme",    "Themes")
    local settingsPage = makeTab("settings", "Settings")
    local infoPage     = makeTab("info",     "Info")

    do
        local v = pages["binds"]
        v.page.Visible = true
        v.btn.BackgroundTransparency = 0
        v.btn.BackgroundColor3 = C.accent
        v.btn.TextColor3 = Color3.fromRGB(255,255,255)
    end

    -- ---------- HELPERS ----------
    local function makeBtn(parent, opts)
        local b = Instance.new("TextButton")
        b.Size = opts.size or UDim2.new(0, 100, 0, 36)
        b.Position = opts.pos or UDim2.new(0, 0, 0, 0)
        b.BackgroundColor3 = opts.bg or C.button
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamSemibold
        b.Text = opts.text or "Button"
        b.TextSize = opts.textSize or 13
        b.TextColor3 = opts.textColor or C.text
        b.AutoButtonColor = false
        b.Parent = parent
        corner(b, opts.radius or 9)
        if opts.role then reg(b, opts.role) end
        if opts.roleText then reg(b, opts.roleText, "TextColor3") end
        local baseBg = opts.bg or C.button
        b.MouseEnter:Connect(function()
            tween(b, 0.12, {BackgroundColor3 = opts.hover or C.buttonHover})
        end)
        b.MouseLeave:Connect(function()
            tween(b, 0.12, {BackgroundColor3 = baseBg})
        end)
        if opts.onClick then
            b.MouseButton1Click:Connect(function()
                local target = b.Size
                tween(b, 0.08, {Size = UDim2.new(target.X.Scale, target.X.Offset - 3,
                    target.Y.Scale, target.Y.Offset - 3)})
                task.delay(0.08, function() tween(b, 0.1, {Size = target}) end)
                pcall(opts.onClick)
            end)
        end
        return b
    end

    local function makeSectionTitle(parent, text, yPos)
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Position = UDim2.new(0, 2, 0, yPos or 0)
        lbl.Size = UDim2.new(1, 0, 0, 14)
        lbl.Font = Enum.Font.GothamBold
        lbl.Text = text
        lbl.TextSize = 10
        lbl.TextColor3 = C.subtext
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent
        reg(lbl, "subtext", "TextColor3")
        return lbl
    end

    local function makeRow(parent, yPos, height)
        local row = Instance.new("Frame")
        row.Position = UDim2.new(0, 0, 0, yPos)
        row.Size = UDim2.new(1, 0, 0, height or 42)
        row.BackgroundTransparency = 1
        row.Parent = parent
        local rl = Instance.new("UIListLayout")
        rl.FillDirection = Enum.FillDirection.Horizontal
        rl.Padding = UDim.new(0, 8)
        rl.Parent = row
        return row
    end

    -- ================= BINDS =================
    do
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = C.accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = bindsPage

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 6)
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Parent = scroll

        local BIND_LABELS = {
            {key="idle",         label="Idle mode"},
            {key="create",       label="Create mode"},
            {key="test",         label="Test mode"},
            {key="edittest",     label="Editable Test mode"},
            {key="recordMouse",  label="Start / Pause recording (mouse)"},
            {key="edittestPlay", label="Editable Test play / pause"},
            {key="tick",         label="Single physics tick"},
            {key="seekBack",     label="Seek backward (hold)"},
            {key="seekFwd",      label="Seek forward (hold)"},
            {key="stepBack",     label="Step back one frame"},
            {key="stepFwd",      label="Step forward one frame"},
            {key="removePauses", label="Remove pauses"},
            {key="cameraLock",   label="Toggle camera lock"},
            {key="clear",        label="Clear recording"},
            {key="save",         label="Save to clipboard"},
            {key="toggleGui",    label="Toggle GUI"},
            {key="toggleHud",    label="Toggle HUD"},
        }

        local bindButtons = {}

        local function makeBindRow(order, actionKey, actionLabel)
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -10, 0, 34)
            row.BackgroundColor3 = C.panelAlt
            row.BorderSizePixel = 0
            row.LayoutOrder = order
            row.Parent = scroll
            corner(row, 8)
            reg(row, "panelAlt")

            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Position = UDim2.new(0, 12, 0, 0)
            lbl.Size = UDim2.new(0.6, 0, 1, 0)
            lbl.Font = Enum.Font.Gotham
            lbl.Text = actionLabel
            lbl.TextSize = 12
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = row
            reg(lbl, "text", "TextColor3")

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 140, 0, 24)
            btn.Position = UDim2.new(1, -152, 0.5, -12)
            btn.BackgroundColor3 = C.button
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.GothamSemibold
            btn.Text = bindToString(keybinds[actionKey])
            btn.TextSize = 12
            btn.TextColor3 = C.text
            btn.AutoButtonColor = false
            btn.Parent = row
            corner(btn, 6)
            reg(btn, "button")
            reg(btn, "text", "TextColor3")

            btn.MouseEnter:Connect(function()
                if listeningForBind ~= actionKey then
                    tween(btn, 0.12, {BackgroundColor3 = C.buttonHover})
                end
            end)
            btn.MouseLeave:Connect(function()
                if listeningForBind ~= actionKey then
                    tween(btn, 0.12, {BackgroundColor3 = C.button})
                end
            end)
            btn.MouseButton1Click:Connect(function()
                if listeningForBind and bindButtons[listeningForBind] then
                    local pb = bindButtons[listeningForBind].btn
                    if pb and pb.Parent then
                        pb.Text = bindToString(keybinds[listeningForBind])
                        tween(pb, 0.15, {BackgroundColor3 = C.button})
                    end
                end
                listeningForBind = actionKey
                btn.Text = "Press a key..."
                tween(btn, 0.15, {BackgroundColor3 = C.accent})
            end)

            bindButtons[actionKey] = {btn = btn, label = lbl}
        end

        for i, entry in ipairs(BIND_LABELS) do
            makeBindRow(i, entry.key, entry.label)
        end

        local resetRow = Instance.new("Frame")
        resetRow.Size = UDim2.new(1, -10, 0, 40)
        resetRow.BackgroundTransparency = 1
        resetRow.LayoutOrder = #BIND_LABELS + 1
        resetRow.Parent = scroll

        local resetBtn = Instance.new("TextButton")
        resetBtn.Size = UDim2.new(1, 0, 1, 0)
        resetBtn.BackgroundColor3 = C.button
        resetBtn.BorderSizePixel = 0
        resetBtn.Font = Enum.Font.GothamSemibold
        resetBtn.Text = "Reset to Defaults"
        resetBtn.TextSize = 13
        resetBtn.TextColor3 = C.text
        resetBtn.AutoButtonColor = false
        resetBtn.Parent = resetRow
        corner(resetBtn, 9)
        reg(resetBtn, "button")
        reg(resetBtn, "text", "TextColor3")
        resetBtn.MouseEnter:Connect(function()
            tween(resetBtn, 0.12, {BackgroundColor3 = C.buttonHover})
        end)
        resetBtn.MouseLeave:Connect(function()
            tween(resetBtn, 0.12, {BackgroundColor3 = C.button})
        end)
        resetBtn.MouseButton1Click:Connect(function()
            for k, v in pairs(DEFAULT_BINDS) do keybinds[k] = v end
            for k, entry in pairs(bindButtons) do
                if entry.btn and entry.btn.Parent then
                    entry.btn.Text = bindToString(keybinds[k])
                end
            end
        end)

        _G.__NexusOnBindChanged = function(actionKey)
            local entry = bindButtons[actionKey]
            if entry and entry.btn and entry.btn.Parent then
                entry.btn.Text = bindToString(keybinds[actionKey])
                tween(entry.btn, 0.15, {BackgroundColor3 = C.button})
            end
        end
    end

    -- ================= THEMES =================
    do
        makeSectionTitle(themePage, "THEMES", 0)

        local grid = Instance.new("ScrollingFrame")
        grid.Position = UDim2.new(0, 0, 0, 20)
        grid.Size = UDim2.new(1, 0, 1, -20)
        grid.BackgroundTransparency = 1
        grid.BorderSizePixel = 0
        grid.ScrollBarThickness = 4
        grid.ScrollBarImageColor3 = C.accent
        grid.CanvasSize = UDim2.new(0, 0, 0, 0)
        grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
        grid.Parent = themePage

        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(0, 165, 0, 90)
        gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.Parent = grid

        local order = 0
        for name, t in pairs(GuiThemes) do
            order = order + 1
            local card = Instance.new("TextButton")
            card.Size = UDim2.new(0, 165, 0, 90)
            card.BackgroundColor3 = t.bg
            card.BorderSizePixel = 0
            card.Text = ""
            card.AutoButtonColor = false
            card.LayoutOrder = order
            card.Parent = grid
            corner(card, 10)
            local cardStroke = Instance.new("UIStroke")
            cardStroke.Color = t.border; cardStroke.Thickness = 1
            cardStroke.Parent = card

            local ac = Instance.new("Frame")
            ac.Size = UDim2.new(0, 40, 0, 40)
            ac.Position = UDim2.new(0, 12, 0, 12)
            ac.BackgroundColor3 = t.accent
            ac.BorderSizePixel = 0
            ac.Parent = card
            corner(ac, 8)

            local bt1 = Instance.new("Frame")
            bt1.Size = UDim2.new(0, 60, 0, 14)
            bt1.Position = UDim2.new(0, 12, 0, 60)
            bt1.BackgroundColor3 = t.button
            bt1.BorderSizePixel = 0
            bt1.Parent = card
            corner(bt1, 4)

            local bt2 = Instance.new("Frame")
            bt2.Size = UDim2.new(0, 30, 0, 14)
            bt2.Position = UDim2.new(0, 78, 0, 60)
            bt2.BackgroundColor3 = t.buttonHover
            bt2.BorderSizePixel = 0
            bt2.Parent = card
            corner(bt2, 4)

            local nlbl = Instance.new("TextLabel")
            nlbl.BackgroundTransparency = 1
            nlbl.Position = UDim2.new(0, 60, 0, 8)
            nlbl.Size = UDim2.new(1, -66, 0, 24)
            nlbl.Font = Enum.Font.GothamBold
            nlbl.Text = name
            nlbl.TextSize = 14
            nlbl.TextColor3 = t.text
            nlbl.TextXAlignment = Enum.TextXAlignment.Left
            nlbl.TextYAlignment = Enum.TextYAlignment.Top
            nlbl.Parent = card

            local slbl = Instance.new("TextLabel")
            slbl.BackgroundTransparency = 1
            slbl.Position = UDim2.new(0, 60, 0, 28)
            slbl.Size = UDim2.new(1, -66, 0, 26)
            slbl.Font = Enum.Font.Gotham
            slbl.Text = "Click to apply"
            slbl.TextSize = 10
            slbl.TextColor3 = t.subtext
            slbl.TextXAlignment = Enum.TextXAlignment.Left
            slbl.TextYAlignment = Enum.TextYAlignment.Top
            slbl.TextWrapped = true
            slbl.Parent = card

            card.MouseEnter:Connect(function()
                tween(cardStroke, 0.15, {Color = t.accent, Thickness = 2})
            end)
            card.MouseLeave:Connect(function()
                tween(cardStroke, 0.15, {Color = t.border, Thickness = 1})
            end)
            card.MouseButton1Click:Connect(function()
                applyTheme(name)
                if _G.__NexusUpdateCamBtn then _G.__NexusUpdateCamBtn() end
            end)
        end
    end

    -- ================= SETTINGS =================
    do
        makeSectionTitle(settingsPage, "SETTINGS", 0)

        local function makeToggle(yPos, labelText, defaultOn, onChange)
            local row = Instance.new("Frame")
            row.Position = UDim2.new(0, 0, 0, yPos)
            row.Size = UDim2.new(1, 0, 0, 42)
            row.BackgroundColor3 = C.panelAlt
            row.BorderSizePixel = 0
            row.Parent = settingsPage
            corner(row, 10)
            reg(row, "panelAlt")

            local lbl = Instance.new("TextLabel")
            lbl.BackgroundTransparency = 1
            lbl.Position = UDim2.new(0, 14, 0, 0)
            lbl.Size = UDim2.new(1, -100, 1, 0)
            lbl.Font = Enum.Font.GothamSemibold
            lbl.Text = labelText
            lbl.TextSize = 13
            lbl.TextColor3 = C.text
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = row
            reg(lbl, "text", "TextColor3")

            local switch = Instance.new("TextButton")
            switch.Size = UDim2.new(0, 50, 0, 26)
            switch.Position = UDim2.new(1, -62, 0.5, -13)
            switch.BackgroundColor3 = defaultOn and C.accent or C.button
            switch.BorderSizePixel = 0
            switch.Text = ""
            switch.AutoButtonColor = false
            switch.Parent = row
            corner(switch, 13)

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 20, 0, 20)
            knob.Position = UDim2.new(0, defaultOn and 27 or 3, 0.5, -10)
            knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
            knob.BorderSizePixel = 0
            knob.Parent = switch
            corner(knob, 10)

            local stateOn = defaultOn
            switch.MouseButton1Click:Connect(function()
                stateOn = not stateOn
                tween(switch, 0.15, {BackgroundColor3 = stateOn and C.accent or C.button})
                tween(knob, 0.18, {Position = UDim2.new(0, stateOn and 27 or 3, 0.5, -10)},
                    Enum.EasingStyle.Quart)
                if onChange then pcall(onChange, stateOn) end
            end)
            return switch
        end

        makeToggle(20, "Camera Lock", cameraLocked, function(v)
            cameraLocked = v
            if _G.__NexusUpdateCamBtn then _G.__NexusUpdateCamBtn() end
        end)
        makeToggle(70, "Show HUD", true, function(v)
            if _G.__NexusHudScreen then _G.__NexusHudScreen.Enabled = v end
        end)
        makeToggle(120, "Smooth Animations", true, function(v)
            _G.__NexusSmooth = v
        end)

        makeSectionTitle(settingsPage, "QUICK ACTIONS", 178)

        local rowA = makeRow(settingsPage, 198, 42)
        makeBtn(rowA, {text="Reset Camera", size=UDim2.new(0.34,-6,1,0),
            onClick=function()
                cameraLocked = true
                if _G.__NexusUpdateCamBtn then _G.__NexusUpdateCamBtn() end
            end})
        makeBtn(rowA, {text="Clear Recording", size=UDim2.new(0.34,-6,1,0),
            onClick=function() clearRecording() end})
        makeBtn(rowA, {text="Idle", size=UDim2.new(0.32,-6,1,0),
            onClick=function() goIdle() end})
    end

    -- ================= INFO =================
    do
        local info = Instance.new("TextLabel")
        info.BackgroundTransparency = 1
        info.Size = UDim2.new(1, 0, 1, 0)
        info.Font = Enum.Font.Gotham
        info.TextSize = 12
        info.TextColor3 = C.text
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextYAlignment = Enum.TextYAlignment.Top
        info.TextWrapped = true
        info.Text = table.concat({
            "NexusTAS - Advanced TAS System",
            "BETA V 1.0",
            "",
            "Quick Start:",
            "  1. Enter Create mode",
            "  2. Press MMB (middle mouse) to begin recording",
            "  3. Perform your actions",
            "  4. Press MMB again to pause",
            "  5. Switch to Test mode to replay the recording",
            "",
            "Editing:",
            "  Use seek / step binds to navigate the recording",
            "  Press MMB while paused to continue recording",
            "  Remove Pauses strips idle frames",
            "",
            "Customization:",
            "  See the Binds tab to change any key",
            "  See the Themes tab to change appearance",
            "",
            "Data:",
            "  Save    - serializes recording to clipboard",
            "  Import  - reads from clipboard",
            "  External: _G.importReplay(<string>)",
        }, "\n")
        info.Parent = infoPage
        reg(info, "text", "TextColor3")
    end

    -- ================= STATUS BAR =================
    local status = Instance.new("Frame")
    status.Position = UDim2.new(0, 14, 1, -54)
    status.Size = UDim2.new(1, -28, 0, 40)
    status.BackgroundColor3 = C.panelAlt
    status.BorderSizePixel = 0
    status.Parent = win
    corner(status, 10)
    reg(status, "panelAlt")
    stroke(status, C.border, 1)

    local function makeStat(xScale, xOff, width, labelText)
        local wrap = Instance.new("Frame")
        wrap.Position = UDim2.new(xScale, xOff, 0, 0)
        wrap.Size = UDim2.new(0, width, 1, 0)
        wrap.BackgroundTransparency = 1
        wrap.Parent = status

        local l = Instance.new("TextLabel")
        l.Position = UDim2.new(0, 0, 0, 4)
        l.Size = UDim2.new(1, 0, 0, 12)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.Text = labelText
        l.TextSize = 9
        l.TextColor3 = C.subtext
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = wrap
        reg(l, "subtext", "TextColor3")

        local v = Instance.new("TextLabel")
        v.Position = UDim2.new(0, 0, 0, 15)
        v.Size = UDim2.new(1, 0, 0, 18)
        v.BackgroundTransparency = 1
        v.Font = Enum.Font.GothamBold
        v.Text = "-"
        v.TextSize = 13
        v.TextColor3 = C.text
        v.TextXAlignment = Enum.TextXAlignment.Left
        v.Parent = wrap
        reg(v, "text", "TextColor3")
        return v
    end

    local statState  = makeStat(0, 14,  130, "STATE")
    local statFrames = makeStat(0, 150, 90,  "FRAMES")
    local statIdx    = makeStat(0, 245, 90,  "INDEX")
    local statTime   = makeStat(0, 340, 90,  "TIME")
    local statRec    = makeStat(1, -70, 60,  "REC")

    -- ================= HUD =================
    local hudScreen = Instance.new("ScreenGui")
    hudScreen.Name = "NexusTASHUD"
    hudScreen.ResetOnSpawn = false
    hudScreen.IgnoreGuiInset = true
    hudScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() hudScreen.Parent = parent end)
    if not hudScreen.Parent then hudScreen.Parent = PLAYER:WaitForChild("PlayerGui") end
    _G.__NexusHudScreen = hudScreen

    local hud = Instance.new("Frame")
    hud.Size = UDim2.new(0, 340, 0, 262)
    hud.AnchorPoint = Vector2.new(1, 1)
    hud.Position = UDim2.new(1, -16, 1, -16)
    hud.BackgroundColor3 = C.panel
    hud.BackgroundTransparency = 0.08
    hud.BorderSizePixel = 0
    hud.Parent = hudScreen
    corner(hud, 10)
    stroke(hud, C.accent, 1)
    reg(hud, "panel")

    local hudHeader = Instance.new("Frame")
    hudHeader.Size = UDim2.new(1, 0, 0, 26)
    hudHeader.BackgroundColor3 = C.panelAlt
    hudHeader.BorderSizePixel = 0
    hudHeader.Parent = hud
    corner(hudHeader, 10)
    reg(hudHeader, "panelAlt")

    local hudDot = Instance.new("Frame")
    hudDot.Size = UDim2.new(0, 8, 0, 8)
    hudDot.Position = UDim2.new(0, 12, 0.5, -4)
    hudDot.BackgroundColor3 = C.subtext
    hudDot.BorderSizePixel = 0
    hudDot.Parent = hudHeader
    corner(hudDot, 4)
    reg(hudDot, "subtext")

    local hudTitle = Instance.new("TextLabel")
    hudTitle.BackgroundTransparency = 1
    hudTitle.Position = UDim2.new(0, 26, 0, 0)
    hudTitle.Size = UDim2.new(1, -34, 1, 0)
    hudTitle.Font = Enum.Font.GothamBold
    hudTitle.Text = "NexusTAS - IDLE"
    hudTitle.TextSize = 12
    hudTitle.TextColor3 = C.text
    hudTitle.TextXAlignment = Enum.TextXAlignment.Left
    hudTitle.Parent = hudHeader
    reg(hudTitle, "text", "TextColor3")

    local hudText = Instance.new("TextLabel")
    hudText.BackgroundTransparency = 1
    hudText.Position = UDim2.new(0, 12, 0, 34)
    hudText.Size = UDim2.new(1, -24, 1, -42)
    hudText.Font = Enum.Font.Code
    hudText.Text = "Loading..."
    hudText.TextSize = 12
    hudText.TextColor3 = C.text
    hudText.TextXAlignment = Enum.TextXAlignment.Left
    hudText.TextYAlignment = Enum.TextYAlignment.Top
    hudText.Parent = hud
    reg(hudText, "text", "TextColor3")

    makeDraggable(hud, hudHeader)

    -- ================= LIVE UPDATE =================
    RunService.RenderStepped:Connect(function()
        pcall(function()
            if not screen.Parent or not win.Parent then return end

            local stColor = C.text
            local stText = string.upper(state)
            if isRecording then
                stText = "RECORD"; stColor = C.danger
            elseif state == "test" then
                stColor = C.success
            elseif state == "create" then
                stColor = C.accent
            elseif state == "edittest" then
                stColor = C.warning
            elseif isPaused and (state=="create" or state=="edittest") then
                stColor = C.warning
                stText = stText .. " / PAUSED"
            end

            if statState.Text ~= stText then statState.Text = stText end
            if statState.TextColor3 ~= stColor then statState.TextColor3 = stColor end
            local nf = tostring(#recordedData)
            if statFrames.Text ~= nf then statFrames.Text = nf end
            local pi = tostring(playIndex)
            if statIdx.Text ~= pi then statIdx.Text = pi end
            local tm = string.format("%.2fs", recordingClock)
            if statTime.Text ~= tm then statTime.Text = tm end
            local recTxt = isRecording and "ON" or (isPaused and "PAUSE" or "OFF")
            if statRec.Text ~= recTxt then statRec.Text = recTxt end
            local recColor = isRecording and C.danger
                or (isPaused and C.warning or C.subtext)
            if statRec.TextColor3 ~= recColor then statRec.TextColor3 = recColor end
        end)

        pcall(function()
            if not hudScreen.Enabled or not hudText.Parent then return end

            local char = PLAYER.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not root or not hum then
                hudText.Text = "Character not found"
                return
            end

            local pos, rot, linVel, angVel, stateName, camRot, zoom, frameTime, frameIdx

            local useFrozen = (state == "create" or state == "edittest")
                and isPaused and frozenFrame

            if useFrozen then
                local f = frozenFrame
                pos      = f.cf.Position
                rot      = f.cf.Rotation
                linVel   = f.velocity    or Vector3.zero
                angVel   = f.rotVelocity or Vector3.zero
                stateName = f.humState and f.humState.Name or "Unknown"
                camRot = Vector3.zero
                zoom   = 0
                if f.cameraCFrame then
                    local rx, ry, rz = f.cameraCFrame:ToOrientation()
                    camRot = Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
                    zoom = (f.cameraCFrame.Position - pos).Magnitude
                end
                frameTime = f.t or 0
                frameIdx  = playIndex
            else
                pos    = root.Position
                rot    = root.Rotation
                linVel = root.AssemblyLinearVelocity
                angVel = root.AssemblyAngularVelocity
                camRot = Vector3.zero
                zoom   = 0
                local cam = workspace.CurrentCamera
                if cam then
                    local rx, ry, rz = cam.CFrame:ToOrientation()
                    camRot = Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
                    zoom = (cam.CFrame.Position - root.Position).Magnitude
                end
                local st = hum:GetState()
                stateName = st and st.Name or "Unknown"
                frameTime = recordingClock
                frameIdx  = playIndex
            end

            hudText.Text = string.format(
                "Frame:        %d\n" ..
                "Frame Time:   %.5f\n" ..
                "Position:     %.2f, %.2f, %.2f\n" ..
                "Rotation:     %.2f, %.2f, %.2f\n" ..
                "Lin. Vel:     %.2f, %.2f, %.2f\n" ..
                "Ang. Vel:     %.2f, %.2f, %.2f\n" ..
                "Cam Rotation: %.2f, %.2f, %.2f\n" ..
                "State:        %s\n" ..
                "Zoom:         %.3f",
                frameIdx or 0,
                frameTime or 0,
                pos.X, pos.Y, pos.Z,
                math.deg(rot.X), math.deg(rot.Y), math.deg(rot.Z),
                linVel.X, linVel.Y, linVel.Z,
                angVel.X, angVel.Y, angVel.Z,
                camRot.X, camRot.Y, camRot.Z,
                stateName,
                zoom
            )

            local hudStateText = string.upper(state)
            if isRecording then
                hudStateText = "RECORD"
            elseif isPaused and (state=="create" or state=="edittest") then
                hudStateText = hudStateText .. " / PAUSED"
            end
            local newTitle = "NexusTAS - " .. hudStateText
            if hudTitle.Text ~= newTitle then hudTitle.Text = newTitle end

            local col = C.text
            if isRecording then col = C.danger
            elseif state == "test" then col = C.success
            elseif state == "create" then col = C.accent
            elseif state == "edittest" then col = C.warning end
            if hudDot.BackgroundColor3 ~= col then hudDot.BackgroundColor3 = col end
        end)
    end)

    print("[NexusTAS] GUI loaded.")
end

print("[NexusTAS] System loaded.")
if not VIM then
    warn("[NexusTAS] VirtualInputManager unavailable: input replay disabled.")
end
print("[NexusTAS] Default binds: 1 Idle | 2 Create | 3 Test | 4 Edittest")
print("[NexusTAS] MMB - record toggle | V - single tick")
print("[NexusTAS] Q / E - seek (hold) | F / G - frame step")
print("[NexusTAS] L - remove pauses | Space - play/pause in edittest | C - camera lock")
print("[NexusTAS] F3 - clear | F4 - save to clipboard | F2 - toggle GUI | F5 - toggle HUD")
print("[NexusTAS] Import: _G.importReplay(<string>)")
