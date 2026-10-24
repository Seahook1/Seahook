-- Ethereal.free v6 | Rivals HvH | Obsidian UI (deividcomsono)
-- Games: 95206881 | 17625359962

local SUPPORTED = { [95206881] = true, [17625359962] = true }
if not SUPPORTED[game.PlaceId] then
    warn("[Ethereal.free] Unsupported game: " .. game.PlaceId)
    return
end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- Persistent shared config table — all getgenv().config reads/writes go here
getgenv().config = getgenv().config or {
    desync_enabled = false, desync_intensity = 50, desync_speed = 10,
    desync_angle = 90, desync_jitter = 20, desync_flip = false,
    desync_unhittable_enabled = false, desync_unhittable_intensity = 50,
    desync_unhittable_radius = 9000, desync_unhittable_iters = 100,
    desync_unhittable_y_range = 10,
    godmode_enabled = false, melee_bypass_enabled = false,
    melee_bypass_y_range = 10,
    -- ── voidspam type (meowlua) ──
    vst_enabled = false, vst_type = "Unhittability", vst_spin_speed = 1e85,
    vst_unhittability_y_range = 10, vst_bait_depth = 20,
    evs_burst = 100, evs_kill_velocity = true, evs_snap_back = false,
    evs_sync_to_ragebot = false, evs_iter_radius = 500000, et_total = 100,
    vs_void_direction = "Random", vs_min_dist = 1, vs_max_dist = 50000,
    vs_char_origin = false,
    -- ── void hide (meowlua) ──
    void_hide_enabled = false, void_hide_x = 1e6, void_hide_y = 9e25,
    void_hide_z = 1e6, void_hide_sync_to_ragebot = false,
    -- ── orbit (meowlua) ──
    orbit_enabled = false, orbit_radius = 50000, orbit_speed = 5,
    orbit_height = 0, orbit_iters = 100, orbit_jitter = 0,
    orbit_y_bias = 0, orbit_depth_floor = 0, orbit_tightness = 10,
    orbit_wave_freq = 1, orbit_phase_offset = 0, orbit_layer_count = 1,
    orbit_layer_offset = 0, orbit_warp_strength = 50, orbit_chaos_blend = 0,
    orbit_pattern = "Circle", orbit_target = "Self", orbit_axis = "Y",
    orbit_direction = "Clockwise", orbit_warp_mode = "Instant",
    orbit_falloff = "None", orbit_kill_velocity = true, orbit_sync_ragebot = false,
    orbit_invert_x = false, orbit_invert_z = false,
}

local Toggles = Library.Toggles
local Options  = Library.Options

local Window = Library:CreateWindow({
    Title         = "Ethereal.free",
    Footer        = "Made by Insomnia and AJ",
    Center        = true,
    AutoShow      = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
})

local Tabs = {
    Void    = Window:AddTab("VoidSpam",          "zap"),
    Orbit   = Window:AddTab("Orbit",             "rotate-cw"),
    AntiAim = Window:AddTab("Anti-Aim",          "crosshair"),
    Sling   = Window:AddTab("Sling",             "shuffle"),
    AntiTL  = Window:AddTab("Anti Translocation","ban"),
    Config  = Window:AddTab("UI Settings",       "settings"),
    Movement = Window:AddTab("Movement",           "move"),
}

-- ─────────────────────────────────────────────
-- Services
-- ─────────────────────────────────────────────
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local BILLION_    = 1e9
local INT32_MAX_  = 2147483647

local char, root, hum
local conns = {}

local function getChar() return LocalPlayer.Character end
local function getHRP()
    local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function killConn(key)
    if conns[key] then conns[key]:Disconnect(); conns[key] = nil end
end

local function Notify(msg, dur)
    Library:Notify({ Title = "Ethereal.free", Description = msg, Time = dur or 2 })
end

-- target helpers
local function getClosest()
    if not root then return nil end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local d = (root.Position - hrp.Position).Magnitude
        if d < bestD then bestD = d; best = p end
    end
    return best
end

local function getTarget(mode)
    if mode == "Closest" then return getClosest() end
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(list, p)
        end
    end
    if #list == 0 then return nil end
    if mode == "Random" then return list[math.random(1, #list)]
    elseif mode == "Weakest" then
        table.sort(list, function(a, b)
            local ha = a.Character:FindFirstChildOfClass("Humanoid")
            local hb = b.Character:FindFirstChildOfClass("Humanoid")
            return (ha and ha.Health or 0) < (hb and hb.Health or 0)
        end)
        return list[1]
    elseif mode == "Strongest" then
        table.sort(list, function(a, b)
            local ha = a.Character:FindFirstChildOfClass("Humanoid")
            local hb = b.Character:FindFirstChildOfClass("Humanoid")
            return (ha and ha.Health or 0) > (hb and hb.Health or 0)
        end)
        return list[1]
    end
    return list[1]
end

-- ─────────────────────────────────────────────
-- ORBIT CONFIG + LOGIC (from kill_him)
-- ─────────────────────────────────────────────
local cfg = {
    orbitEnabled = false, orbitSpeed = 90, orbitDist = 8, orbitHeight = 0,
    orbitLerp = 0.3, orbitMode = "Circle", orbitPredict = false, orbitPredStr = 0.2,
    orbitFace = true, orbitLockDist = 999999999, orbitTarget = "Closest", orbitAxis = "XZ",
    orbitReverse = false, orbitRandRad = false, orbitRandMin = 5, orbitRandMax = 20,
    orbitYawOff = 0, orbitPitchOff = 0, orbitOffX = 0, orbitOffZ = 0,
    orbitHeightOscillate = false, orbitHeightOscAmp = 5, orbitHeightOscSpeed = 2,
    orbitSpeedRandom = false, orbitSpeedRandMin = 20, orbitSpeedRandMax = 200,
    orbitDistPulse = false, orbitDistPulseAmp = 5, orbitDistPulseSpeed = 1,
    orbitSnapBack = false, orbitSnapInterval = 0.5,
    orbitZigzag = false, orbitZigzagAmp = 3, orbitZigzagFreq = 4,
}

local orbitAngle, orbitLocalElapsed, orbitCurrentRadius = 0, 0, 0
local orbitSnapTimer = 0

local function startOrbit()
    killConn("orbit")
    orbitAngle = 0; orbitLocalElapsed = 0; orbitCurrentRadius = cfg.orbitDist
    orbitSnapTimer = 0
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
    conns.orbit = RunService.Heartbeat:Connect(function(dt)
        if not cfg.orbitEnabled then killConn("orbit"); return end
        if not root then return end
        if hum then pcall(function()
            if hum:GetState() ~= Enum.HumanoidStateType.Physics then
                hum:ChangeState(Enum.HumanoidStateType.Physics)
            end
        end) end

        local target    = getTarget(cfg.orbitTarget)
        local targetPos = root.Position
        if target and target.Character then
            local hrp = target.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (root.Position - hrp.Position).Magnitude <= cfg.orbitLockDist then
                targetPos = hrp.Position
                if cfg.orbitPredict then
                    targetPos = targetPos + hrp.AssemblyLinearVelocity * cfg.orbitPredStr
                end
            end
        end

        local speed = cfg.orbitReverse and -cfg.orbitSpeed or cfg.orbitSpeed
        if cfg.orbitSpeedRandom then
            speed = cfg.orbitSpeedRandMin + math.random() * (cfg.orbitSpeedRandMax - cfg.orbitSpeedRandMin)
            if cfg.orbitReverse then speed = -speed end
        end

        orbitAngle        = (orbitAngle + math.rad(speed) * dt) % (2 * math.pi)
        orbitLocalElapsed = orbitLocalElapsed + dt

        local r = cfg.orbitRandRad and math.random(cfg.orbitRandMin, cfg.orbitRandMax) or cfg.orbitDist
        if cfg.orbitDistPulse then
            r = r + math.sin(orbitLocalElapsed * cfg.orbitDistPulseSpeed * 2 * math.pi) * cfg.orbitDistPulseAmp
        end

        local h = cfg.orbitHeight
        if cfg.orbitHeightOscillate then
            h = h + math.sin(orbitLocalElapsed * cfg.orbitHeightOscSpeed * 2 * math.pi) * cfg.orbitHeightOscAmp
        end

        local x, y, z = 0, 0, 0
        local ax = cfg.orbitAxis
        local om = cfg.orbitMode

        if om == "Circle" then
            if ax == "XZ" then x=math.cos(orbitAngle)*r; z=math.sin(orbitAngle)*r; y=h
            elseif ax == "XY" then x=math.cos(orbitAngle)*r; y=math.sin(orbitAngle)*r; z=h
            elseif ax == "YZ" then y=math.cos(orbitAngle)*r; z=math.sin(orbitAngle)*r; x=h end
        elseif om == "Figure 8" then
            x=math.sin(orbitAngle)*r; z=math.sin(orbitAngle)*math.cos(orbitAngle)*r*0.7; y=h
        elseif om == "Ellipse" then
            x=math.cos(orbitAngle)*r; z=math.sin(orbitAngle)*r*0.6; y=h
        elseif om == "Spiral In" then
            orbitCurrentRadius = math.max(1, orbitCurrentRadius - dt * cfg.orbitDist * 0.2)
            x=math.cos(orbitAngle)*orbitCurrentRadius; z=math.sin(orbitAngle)*orbitCurrentRadius; y=h
        elseif om == "Spiral Out" then
            orbitCurrentRadius = math.min(cfg.orbitDist*2, orbitCurrentRadius + dt * cfg.orbitDist * 0.2)
            x=math.cos(orbitAngle)*orbitCurrentRadius; z=math.sin(orbitAngle)*orbitCurrentRadius; y=h
        elseif om == "Bounce" then
            x=math.cos(orbitAngle)*r; z=math.sin(orbitAngle)*r; y=h+math.sin(orbitLocalElapsed*3)*5
        elseif om == "Lemniscate" then
            local denom = 1 + math.sin(orbitAngle)^2
            x=r*math.cos(orbitAngle)/denom; z=r*math.sin(orbitAngle)*math.cos(orbitAngle)/denom; y=h
        elseif om == "Infinity" then
            x=r*math.cos(orbitAngle); z=r*math.sin(2*orbitAngle)/2; y=h
        elseif om == "RandomOrbit" then
            local a=math.random()*2*math.pi; x=math.cos(a)*r; z=math.sin(a)*r; y=h
        end

        if cfg.orbitZigzag then
            x = x + math.sin(orbitLocalElapsed * cfg.orbitZigzagFreq * 2 * math.pi) * cfg.orbitZigzagAmp
        end

        x = x + cfg.orbitOffX; z = z + cfg.orbitOffZ
        local dst = targetPos + Vector3.new(x, y, z)

        if cfg.orbitSnapBack then
            orbitSnapTimer = orbitSnapTimer + dt
            if orbitSnapTimer >= cfg.orbitSnapInterval then
                orbitSnapTimer = 0
                dst = targetPos + Vector3.new(cfg.orbitOffX, h, cfg.orbitOffZ)
            end
        end

        local alpha  = math.min(1, 1 - (1 - cfg.orbitLerp)^(dt * 60))
        local smooth = root.Position:Lerp(dst, alpha)

        pcall(function()
            if cfg.orbitFace then
                local cf = CFrame.new(smooth, Vector3.new(targetPos.X, smooth.Y, targetPos.Z))
                cf = cf * CFrame.Angles(math.rad(cfg.orbitPitchOff), math.rad(cfg.orbitYawOff), 0)
                root.CFrame = cf
            else
                root.CFrame = CFrame.new(smooth)
            end
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end)
end

local function stopOrbit()
    killConn("orbit"); cfg.orbitEnabled = false
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
end

-- ─────────────────────────────────────────────
-- ANTI-AIM CONFIG + LOGIC (from kill_him)
-- ─────────────────────────────────────────────
local aaSettings = {
    enabled = false, mode = "RandomSpin", speed = 5000,
    angle = 90, randomSpeed = true, jitterPitch = true,
    pitchAngle = 45, yawAngle = 45, staticYaw = 90, staticPitch = 0,
    customYaw = 180, customPitch = 0, jitterYaw = true,
    microJitter = false, microJitterAmp = 5, microJitterSpeed = 30,
    desyncMode = false, desyncOffset = 180,
    rollEnabled = false, rollSpeed = 360,
    breatheEffect = false, breatheAmp = 3, breatheSpeed = 1,
    randomFlip = false, flipChance = 0.05,
}

local aaAngAcc = 0; local aaRollAcc = 0; local aaJitter = 0
local aaMicroT = 0; local aaBreatheT = 0; local aaFlipTimer = 0

local function startAntiAim()
    killConn("antiAim")
    aaAngAcc=0; aaRollAcc=0; aaJitter=0; aaMicroT=0; aaBreatheT=0; aaFlipTimer=0
    conns.antiAim = RunService.Heartbeat:Connect(function(dt)
        if not aaSettings.enabled then killConn("antiAim"); return end
        if not root then return end

        local spd = aaSettings.speed
        if aaSettings.randomSpeed then spd = spd * (0.5 + math.random()) end

        aaRollAcc = aaRollAcc + dt; aaMicroT = aaMicroT + dt
        aaBreatheT = aaBreatheT + dt; aaFlipTimer = aaFlipTimer + dt

        local extraPitch, extraYaw = 0, 0
        if aaSettings.breatheEffect then
            extraPitch = math.sin(aaBreatheT * aaSettings.breatheSpeed * 2 * math.pi) * aaSettings.breatheAmp
        end
        if aaSettings.microJitter then
            extraYaw   = math.sin(aaMicroT * aaSettings.microJitterSpeed * 2 * math.pi) * aaSettings.microJitterAmp
            extraPitch = extraPitch + math.cos(aaMicroT * aaSettings.microJitterSpeed * 2 * math.pi) * aaSettings.microJitterAmp
        end
        if aaSettings.desyncMode  then extraYaw = extraYaw + aaSettings.desyncOffset end
        if aaSettings.randomFlip and math.random() < aaSettings.flipChance then extraYaw = extraYaw + 180 end

        local rollAngle = 0
        if aaSettings.rollEnabled then
            rollAngle = (aaRollAcc * aaSettings.rollSpeed * math.pi / 180) % (2 * math.pi)
        end

        local m = aaSettings.mode
        pcall(function()
            if m == "Spin" then
                aaAngAcc = aaAngAcc + spd * dt
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(math.rad(extraPitch), math.rad(aaAngAcc+extraYaw), rollAngle)
            elseif m == "Jitter" then
                local p = aaSettings.jitterPitch and aaSettings.pitchAngle or 0
                local y = aaSettings.jitterYaw   and aaSettings.yawAngle   or 0
                root.CFrame = root.CFrame * CFrame.Angles(
                    math.rad((aaJitter==0 and p or -p)+extraPitch),
                    math.rad((aaJitter==0 and y or -y)+extraYaw), rollAngle)
                aaJitter = (aaJitter+1) % 2
            elseif m == "Static" then
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(
                    math.rad(aaSettings.staticPitch+extraPitch), math.rad(aaSettings.staticYaw+extraYaw), rollAngle)
            elseif m == "Up" then
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(math.rad(90+extraPitch), math.rad(extraYaw), rollAngle)
            elseif m == "Down" then
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(math.rad(-90+extraPitch), math.rad(extraYaw), rollAngle)
            elseif m == "Side" then
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(math.rad(extraPitch), math.rad(extraYaw), math.rad(90)+rollAngle)
            elseif m == "RandomSpin" then
                aaAngAcc = aaAngAcc + spd * dt * (math.random()*2-1)
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(
                    math.rad(aaSettings.customPitch+extraPitch), math.rad(aaAngAcc+extraYaw), rollAngle)
            elseif m == "Custom" then
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(
                    math.rad(aaSettings.customPitch+extraPitch), math.rad(aaSettings.customYaw+extraYaw), rollAngle)
            end
        end)
    end)
end

local function stopAntiAim() killConn("antiAim"); aaSettings.enabled = false end

-- ─────────────────────────────────────────────
-- CHAR BIND
-- ─────────────────────────────────────────────
local function bindChar(c)
    char = c
    root = c:WaitForChild("HumanoidRootPart", 5)
    hum  = c:WaitForChild("Humanoid", 5)
    if cfg.orbitEnabled   then startOrbit()   end
    if aaSettings.enabled then startAntiAim() end
end

if LocalPlayer.Character then bindChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.3); bindChar(c) end)
LocalPlayer.CharacterRemoving:Connect(function()
    killConn("orbit"); killConn("antiAim")
    root = nil; hum = nil; char = nil
end)

-- ─────────────────────────────────────────────
-- MEOWLUA PORTS — implementations for every getgenv() call
-- that Ethereal's UI stubs out but never defines locally.
-- ─────────────────────────────────────────────

-- ── Void Hide ──────────────────────────────────────────────
do
    local vh_conn = nil

    getgenv().start_void_hide = function()
        if vh_conn then vh_conn:Disconnect() end
        vh_conn = RunService.Heartbeat:Connect(function()
            local cfg2 = getgenv().config
            if not cfg2 or not cfg2.void_hide_enabled then return end
            local hrp = getHRP(); local hum = getHum()
            if not hrp or not hum or hum.Health <= 0 then return end
            if hum:GetState() ~= Enum.HumanoidStateType.Physics then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
            end
            local base = hrp.Position
            local hx = cfg2.void_hide_x or 1e6
            local hy = cfg2.void_hide_y or 9e25
            local hz = cfg2.void_hide_z or 1e6
            local sx = (math.random() < 0.5) and 1 or -1
            local sz = (math.random() < 0.5) and 1 or -1
            local hide_cf = CFrame.new(base.X + sx * hx, base.Y - hy, base.Z + sz * hz)
            pcall(function()
                hrp.CFrame                   = hide_cf
                hrp.AssemblyLinearVelocity   = Vector3.zero
                hrp.AssemblyAngularVelocity  = Vector3.zero
            end)
        end)
    end

    getgenv().stop_void_hide = function()
        if vh_conn then vh_conn:Disconnect(); vh_conn = nil end
        getgenv().config.void_hide_enabled = false
    end
end

-- ── Voidspam Type ──────────────────────────────────────────
do
    local vst_conn_m     = nil
    local vst_spin_conn  = nil
    local vst_last_pos   = nil

    -- randomised position burst (Unhittability / Defend / Random)
    local function vst_do_burst()
        local hrp = getHRP(); if not hrp then return end
        local cfg2 = getgenv().config
        local iters    = math.clamp(cfg2.et_total       or 100,    1, 500)
        local ir       = math.max(cfg2.evs_iter_radius  or 500000, 1)
        local iter_pos = vst_last_pos or hrp.Position
        for _ = 1, iters do
            local sx = (math.random() < 0.5) and 1 or -1
            local sy = (math.random() < 0.5) and 1 or -1
            local sz = (math.random() < 0.5) and 1 or -1
            local rx = sx * (ir * (0.5 + math.random() * 0.5))
            local ry = sy * (ir * (0.5 + math.random() * 0.5))
            local rz = sz * (ir * (0.5 + math.random() * 0.5))
            pcall(function()
                hrp.CFrame = CFrame.new(iter_pos.X + rx, iter_pos.Y + ry, iter_pos.Z + rz)
            end)
            iter_pos = hrp.Position
        end
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        vst_last_pos = hrp.Position
    end

    -- push enemy HRPs to a fake offset so melee can't land
    local FAKE_OFFSET_VST = Vector3.new(9000, 9000, 9000)
    local function vst_do_melee_bypass()
        local cfg2 = getgenv().config
        local hrp  = getHRP(); if not hrp then return end
        local y_range = math.max(cfg2.vst_unhittability_y_range or 10, 1)
        pcall(function()
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local eh = p.Character:FindFirstChild("HumanoidRootPart")
                    if eh then
                        local y_diff = hrp.Position.Y - eh.Position.Y
                        if y_diff >= 0 and y_diff <= y_range then
                            local mt  = getrawmetatable(eh)
                            local ni  = mt and rawget(mt, "__newindex")
                            local fcf = CFrame.new(FAKE_OFFSET_VST)
                            if ni then pcall(ni, eh, "CFrame", fcf)
                            else       rawset(eh, "CFrame", fcf) end
                            eh.AssemblyLinearVelocity = Vector3.zero
                        end
                    end
                end
            end
        end)
    end

    getgenv().start_voidspam_type = function()
        -- disconnect any existing connections first
        if vst_conn_m    then vst_conn_m:Disconnect();    vst_conn_m   = nil end
        if vst_spin_conn then vst_spin_conn:Disconnect(); vst_spin_conn = nil end
        vst_last_pos = nil

        -- Motor6D spin so server-side character looks spun
        vst_spin_conn = RunService.Heartbeat:Connect(function()
            local cfg2 = getgenv().config
            if not cfg2 or not cfg2.vst_enabled then return end
            local char = LocalPlayer.Character; if not char then return end
            local spd       = cfg2.vst_spin_speed or 1e85
            local spinAngle = (tick() * spd) % (2 * math.pi)
            local spinCF    = CFrame.Angles(0, spinAngle, 0)
            local hrp_s     = char:FindFirstChild("HumanoidRootPart")
            if hrp_s then
                pcall(function() hrp_s.AssemblyAngularVelocity = Vector3.zero end)
            end
            pcall(function()
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("Motor6D") then v.Transform = spinCF end
                end
            end)
        end)

        -- main void type loop
        vst_conn_m = RunService.Heartbeat:Connect(function()
            local cfg2 = getgenv().config
            if not cfg2 or not cfg2.vst_enabled then return end
            local hrp = getHRP(); local hum = getHum()
            if not hrp or not hum or hum.Health <= 0 then return end

            local vtype = cfg2.vst_type or "Unhittability"

            if vtype ~= "Bait" then
                if hum:GetState() ~= Enum.HumanoidStateType.Physics then
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
                end
            end

            if vtype == "Unhittability" then
                vst_do_burst()
                vst_do_melee_bypass()

            elseif vtype == "Defend" then
                vst_do_burst()

            elseif vtype == "Extreme" then
                local cur = hrp.Position
                pcall(function() hrp.CFrame = CFrame.new(cur.X, cur.Y - 9e25, cur.Z) end)
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero

            elseif vtype == "Bait" then
                local cur        = hrp.Position
                local bait_depth = math.clamp(cfg2.vst_bait_depth or 20, 1, 40)
                hrp.CFrame                  = CFrame.new(cur.X, cur.Y - bait_depth, cur.Z)
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero

            else -- Attack / Random both fall through to the burst
                vst_do_burst()
            end
        end)
    end

    getgenv().stop_voidspam_type = function()
        if vst_conn_m    then vst_conn_m:Disconnect();    vst_conn_m   = nil end
        if vst_spin_conn then vst_spin_conn:Disconnect(); vst_spin_conn = nil end
        vst_last_pos = nil
    end

    getgenv().disable_voidspam_type = function()
        getgenv().config.vst_enabled = false
        getgenv().stop_voidspam_type()
        local hrp  = getHRP()
        local char = LocalPlayer.Character
        local hum  = getHum()
        if hrp then
            pcall(function()
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        if hum then
            pcall(function() hum.AutoRotate   = true end)
            pcall(function() hum.PlatformStand = false end)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
        -- restore Motor6D transforms so character animation returns to normal
        if char then
            pcall(function()
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("Motor6D") then v.Transform = CFrame.new() end
                end
            end)
        end
    end
end

-- ── Orbit (meowlua-compatible, reads getgenv().config.orbit_*) ─
-- Ethereal's UI was written to call getgenv().start_orbit /
-- getgenv().stop_orbit (meowlua format) and writes orbit settings
-- into getgenv().config.orbit_*, so we implement those here.
-- The pre-existing local startOrbit() / stopOrbit() pair reads from
-- a different local cfg table and is never called by the UI; it's
-- left intact so CharacterAdded logic still compiles cleanly.
do
    local orb_conn   = nil
    local orb_phase  = 0

    -- per-iteration offset in meowlua's coordinate conventions
    local function orb_offset(i, total, phase)
        local cfg2      = getgenv().config
        local frac      = (i - 1) / math.max(total - 1, 1)
        local radius    = math.max(cfg2.orbit_radius or 50000, 1)
        local height    = cfg2.orbit_height or 0
        local pattern   = cfg2.orbit_pattern   or "Circle"
        local axis      = cfg2.orbit_axis      or "Y"
        local dir_sign  = (cfg2.orbit_direction == "Counter-clockwise") and -1 or 1
        local jitter    = cfg2.orbit_jitter     or 0
        local tightness = math.max(cfg2.orbit_tightness or 10, 1)
        local wf        = cfg2.orbit_wave_freq  or 1

        -- falloff
        local eff = radius
        local fm  = cfg2.orbit_falloff or "None"
        if     fm == "Linear" then eff = radius * (1 - (i-1) / total)
        elseif fm == "Exp"    then eff = radius * math.exp(-3 * (i-1) / total)
        elseif fm == "Sine"   then eff = radius * math.abs(math.sin((i-1) / total * math.pi))
        elseif fm == "Cosine" then eff = radius * math.abs(math.cos((i-1) / total * math.pi * 0.5))
        end

        local j = jitter > 0 and Vector3.new(
            (math.random()-0.5)*jitter,
            (math.random()-0.5)*jitter*0.2,
            (math.random()-0.5)*jitter
        ) or Vector3.zero

        local a = frac * math.pi * 2 * dir_sign + phase
        local ox, oy, oz

        if pattern == "Circle" then
            if axis == "Y" then
                ox = math.cos(a)*eff; oy = height;          oz = math.sin(a)*eff
            elseif axis == "X" then
                ox = 0;               oy = math.cos(a)*eff+height; oz = math.sin(a)*eff
            else
                ox = math.cos(a)*eff; oy = math.sin(a)*eff+height; oz = 0
            end
        elseif pattern == "Ellipse" then
            ox = math.cos(a)*eff; oy = height; oz = math.sin(a)*(eff*0.5)
        elseif pattern == "Figure8" then
            ox = math.sin(a)*eff; oy = height; oz = math.sin(a*2)*(eff*0.5)
        elseif pattern == "Helix" then
            ox = math.cos(a*tightness*0.1)*eff
            oy = height + frac*eff*0.5
            oz = math.sin(a*tightness*0.1)*eff
        elseif pattern == "Wave" then
            ox = math.cos(a)*eff
            oy = math.sin(frac*math.pi*2*wf+phase)*eff*0.4 + height
            oz = math.sin(a)*eff
        elseif pattern == "Spiral" then
            local rm = eff*(0.2+0.8*frac)
            ox = math.cos(a*tightness*0.1)*rm; oy = height; oz = math.sin(a*tightness*0.1)*rm
        elseif pattern == "Pulse" then
            local pulse = math.abs(math.sin(frac*math.pi*wf+phase))
            ox = math.cos(a)*eff*pulse; oy = height; oz = math.sin(a)*eff*pulse
        else
            ox = math.cos(a)*eff; oy = height; oz = math.sin(a)*eff
        end

        -- optional modifiers
        local chaos = cfg2.orbit_chaos_blend or 0
        if chaos > 0 then
            ox = ox + (math.random()-0.5)*eff*chaos*0.02
            oz = oz + (math.random()-0.5)*eff*chaos*0.02
        end
        if cfg2.orbit_invert_x then ox = -ox end
        if cfg2.orbit_invert_z then oz = -oz end
        oy = oy + (cfg2.orbit_y_bias     or 0)
        local df = cfg2.orbit_depth_floor or 0
        if df > 0 then oy = math.max(oy, -df) end

        return Vector3.new(ox, oy, oz) + j
    end

    -- warp helpers
    local function orb_warp(from_cf, to_pos)
        local cfg2   = getgenv().config
        local tgt    = CFrame.new(to_pos)
        local mode   = cfg2.orbit_warp_mode   or "Instant"
        local s      = math.clamp((cfg2.orbit_warp_strength or 50)/100, 0.01, 1)
        if mode == "Instant" then return tgt end
        if mode == "Lerp"    then return from_cf:Lerp(tgt, s) end
        if mode == "Spring"  then return from_cf:Lerp(tgt, math.clamp(s*1.5, 0.01, 1)) end
        if mode == "Bounce"  then
            local b = math.abs(math.sin(s*math.pi*3))*(1-s)
            return from_cf:Lerp(tgt, math.clamp(s+b*0.2, 0.01, 1))
        end
        if mode == "Elastic" then
            local e = math.sin(s*math.pi*4.5)*math.exp(-s*3)
            return from_cf:Lerp(tgt, math.clamp(s+e*0.15, 0.01, 1))
        end
        return tgt
    end

    -- find base position for "Closest" target mode
    local function orb_base()
        local cfg2 = getgenv().config
        if cfg2.orbit_target ~= "Closest" then return nil end
        local hrp = getHRP(); if not hrp then return nil end
        local best, bestD = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local t = p.Character:FindFirstChild("HumanoidRootPart")
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if t and h and h.Health > 0 then
                    local d = (hrp.Position - t.Position).Magnitude
                    if d < bestD then bestD = d; best = t.Position end
                end
            end
        end
        return best
    end

    getgenv().start_orbit = function()
        if orb_conn then orb_conn:Disconnect() end
        orb_phase = 0
        orb_conn = RunService.Heartbeat:Connect(function(dt)
            local cfg2 = getgenv().config
            if not cfg2 or not cfg2.orbit_enabled then return end
            local hrp = getHRP(); local hum = getHum()
            if not hrp or not hum or hum.Health <= 0 then return end
            if hum:GetState() ~= Enum.HumanoidStateType.Physics then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end)
            end

            orb_phase = orb_phase + dt * (cfg2.orbit_speed or 5) * 0.5

            local iters      = math.clamp(cfg2.orbit_iters       or 100, 1, 500)
            local layers     = math.clamp(cfg2.orbit_layer_count  or 1,   1, 8)
            local layer_off  = math.rad(cfg2.orbit_layer_offset   or 0)
            local base_ovr   = orb_base()
            local iter_cf    = hrp.CFrame

            for layer = 1, layers do
                local lphase = orb_phase + layer_off * layer
                for i = 1, iters do
                    local offset   = orb_offset(i, iters, lphase)
                    local base_pos = base_ovr or iter_cf.Position
                    local tp = Vector3.new(
                        base_pos.X + offset.X,
                        base_pos.Y + offset.Y,
                        base_pos.Z + offset.Z
                    )
                    local final = orb_warp(iter_cf, tp)
                    pcall(function() hrp.CFrame = final end)
                    iter_cf = hrp.CFrame
                end
            end

            if cfg2.orbit_kill_velocity then
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end)
    end

    getgenv().stop_orbit = function()
        if orb_conn then orb_conn:Disconnect(); orb_conn = nil end
        getgenv().config.orbit_enabled = false
        orb_phase = 0
    end
end

-- ─────────────────────────────────────────────
-- VOID SPAM LOGIC
-- ─────────────────────────────────────────────
local spiralT = 0

local function readBound(key, fallback)
    local v = Options[key] and Options[key].Value
    return v and math.floor(v * BILLION_) or fallback
end
local function largeRandom(lo, hi)
    if hi <= lo then return lo end
    if hi - lo <= INT32_MAX_ then return math.random(lo, hi) end
    return math.floor(lo + math.random() * (hi - lo + 1))
end
local function randVec(lo, hi)
    return Vector3.new(largeRandom(lo,hi), largeRandom(lo,hi), largeRandom(lo,hi))
end
local function getVoidCF()
    local lo   = readBound("SpamMin", -10000000000)
    local hi   = readBound("SpamMax",  10000000000)
    local mode = Options.SpamMode  and Options.SpamMode.Value  or "Random"
    local yBias= (Options.SpamYBias and Options.SpamYBias.Value or 0) * BILLION_
    if mode == "Random" then return CFrame.new(randVec(lo, hi))
    elseif mode == "Directional" then return CFrame.new(Vector3.new(hi, yBias, hi))
    elseif mode == "Spiral" then
        local rate = Options.SpamSpiralRate and Options.SpamSpiralRate.Value or 5
        spiralT = spiralT + rate * 0.05
        return CFrame.new(math.cos(spiralT)*math.abs(hi), yBias, math.sin(spiralT)*math.abs(hi))
    elseif mode == "Cubic" then
        local pts = { Vector3.new(hi,hi,hi), Vector3.new(lo,hi,hi), Vector3.new(hi,lo,hi), Vector3.new(hi,hi,lo), Vector3.new(lo,lo,lo) }
        return CFrame.new(pts[math.random(1,#pts)])
    elseif mode == "Ping-Pong" then
        local amp  = (Options.SpamPingAmp and Options.SpamPingAmp.Value or 5) * BILLION_
        local sign = math.random(0,1)==0 and 1 or -1
        return CFrame.new(sign*amp, yBias, sign*amp)
    end
    return CFrame.new(randVec(lo, hi))
end

function _G.EtherealCSync()
    local hrp = getHRP(); if not hrp then return end
    local hum2  = getHum()
    local vmult = Options.SpamVelMult and Options.SpamVelMult.Value or 1
    pcall(function()
        if hum2 and Toggles.SpamAntiCorrect.Value then
            hum2:ChangeState(Enum.HumanoidStateType.Physics); hum2.PlatformStand = true
        end
        local cf  = getVoidCF()
        local vel = Toggles.SpamRandVel.Value
            and randVec(readBound("SpamMin",-10000000000), readBound("SpamMax",10000000000)) * vmult
            or  cf.Position * vmult
        hrp.CFrame = cf; hrp.AssemblyLinearVelocity = vel
        if not Toggles.SpamAsmOnly.Value then hrp.Velocity = vel end
        if Toggles.SpamDoubleFlush.Value then
            local cf2 = getVoidCF()
            hrp.CFrame = cf2; hrp.AssemblyLinearVelocity = cf2.Position * vmult
            if not Toggles.SpamAsmOnly.Value then hrp.Velocity = cf2.Position * vmult end
        end
    end)
end

local function resetChar()
    pcall(function()
        local hrp  = getHRP(); local hum2 = getHum()
        if hum2 and Toggles.SpamAntiCorrect.Value then
            hum2.PlatformStand = false; hum2:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if hrp and Toggles.SpamFreezeOnHide.Value then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.Velocity                = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local spamThread = nil; local lastPos = Vector3.zero

local function stopSpam()
    if spamThread then task.cancel(spamThread); spamThread = nil end; resetChar()
end
local function startSpam()
    stopSpam()
    spamThread = task.spawn(function()
        while Toggles.SpamToggle.Value do
            local delay = Options.SpamDelay.Value  or 0.05
            local atk   = Options.SpamAttack.Value or 0.5
            local hide  = Options.SpamHide.Value   or 0.5
            local burst = Options.SpamBurst.Value  or 3
            local t = os.clock() + atk
            while os.clock() < t and Toggles.SpamToggle.Value do
                local hrp = getHRP(); if hrp then lastPos = hrp.Position end
                for _ = 1, burst do _G.EtherealCSync() end; task.wait(delay)
            end
            if Toggles.SpamToggle.Value then resetChar() end
            t = os.clock() + hide
            while os.clock() < t and Toggles.SpamToggle.Value do
                if Toggles.SpamAutoRetry.Value then
                    local hrp = getHRP(); local thresh = Options.SpamRetryThresh.Value or 50
                    if hrp and (hrp.Position - lastPos).Magnitude > thresh then break end
                end
                task.wait(0.05)
            end
        end
        spamThread = nil
    end)
end

-- ─────────────────────────────────────────────
-- ANTI-TRANSLOCATION CONFIG + LOGIC (from kill_him)
-- ─────────────────────────────────────────────
local antiTranslocCFG = {
    enabled = false, detectRadius = 100, detectWindow = 0.5,
    minTps = 3, dodgeDistance = 30, dodgeCooldown = 0.2,
    mode = "Evade", freezeTime = 0.1, predictLead = 0.1, notify = true,
    counterTeleport = false, counterTpOffset = 50,
    autoEvadeAll = false, evadeAllRadius = 200,
    shieldMode = false, shieldRadius = 20,
    memorizePattern = false, patternWindow = 2,
    bounceback = false, bouncebackDist = 100,
    spinEvade = false, spinEvadeSpeed = 360,
    multiDodge = false, multiDodgeCount = 3,
}

local antiTranslocData = {}
local lastATDodge = 0
local freezeUntil = 0

local function cleanTranslocTimes(data, window)
    local now, clean = tick(), {}
    for _, t in ipairs(data.tpTimes) do
        if now - t < window then clean[#clean + 1] = t end
    end
    data.tpTimes = clean
end

local function initATData(p) antiTranslocData[p] = { lastPos = nil, tpTimes = {}, patternPos = {} } end

local function doAntiTransloc(player)
    if not root then return end
    local now = tick()
    if now - lastATDodge < antiTranslocCFG.dodgeCooldown then return end
    lastATDodge = now
    local mode = antiTranslocCFG.mode
    local threatPos = Vector3.new(0, 0, 0)
    if player and player.Character then
        local h = player.Character:FindFirstChild("HumanoidRootPart")
        if h then
            threatPos = mode == "Predict"
                and h.Position + h.AssemblyLinearVelocity * antiTranslocCFG.predictLead
                or h.Position
        end
    end

    if mode == "Freeze" then
        freezeUntil = now + antiTranslocCFG.freezeTime
        pcall(function()
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if hum then hum:ChangeState(Enum.HumanoidStateType.Physics) end
        end)
        if antiTranslocCFG.notify then Notify("anti-transloc: froze", 1) end
    else
        local flat = Vector3.new(threatPos.X - root.Position.X, 0, threatPos.Z - root.Position.Z)
        local dir  = flat.Magnitude > 0.01 and -flat.Unit or Vector3.new(1, 0, 0)

        if antiTranslocCFG.spinEvade then
            local spinAng = (tick() * antiTranslocCFG.spinEvadeSpeed * math.pi / 180) % (2 * math.pi)
            dir = Vector3.new(math.cos(spinAng), 0, math.sin(spinAng))
        end

        if antiTranslocCFG.multiDodge then
            for _ = 1, antiTranslocCFG.multiDodgeCount do
                local randDir = Vector3.new(math.random()*2-1, 0, math.random()*2-1).Unit
                local newPos  = root.Position + randDir * antiTranslocCFG.dodgeDistance
                pcall(function() root.CFrame = CFrame.new(newPos); root.AssemblyLinearVelocity = Vector3.zero end)
                task.wait(0.01)
            end
        else
            local dodgeDist = antiTranslocCFG.dodgeDistance
            if antiTranslocCFG.bounceback then dodgeDist = antiTranslocCFG.bouncebackDist end
            local newPos = root.Position + dir * dodgeDist
            pcall(function() root.CFrame = CFrame.new(newPos); root.AssemblyLinearVelocity = Vector3.zero end)
        end

        if antiTranslocCFG.counterTeleport then
            local counterPos = threatPos + dir * antiTranslocCFG.counterTpOffset
            pcall(function() root.CFrame = CFrame.new(counterPos) end)
        end

        if antiTranslocCFG.notify then Notify("anti-transloc: dodged", 1) end
    end
end

local function startAntiTransloc()
    killConn("antiTransloc")
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then initATData(p) end
    end
    freezeUntil = 0
    conns.antiTransloc = RunService.Heartbeat:Connect(function(dt)
        if not antiTranslocCFG.enabled then killConn("antiTransloc"); return end
        if not root then return end
        if tick() < freezeUntil then
            pcall(function() root.AssemblyLinearVelocity = Vector3.zero; root.AssemblyAngularVelocity = Vector3.zero end)
            return
        end

        if antiTranslocCFG.autoEvadeAll then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer or not p.Character then continue end
                local hrp = p.Character:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
                local dist = (hrp.Position - root.Position).Magnitude
                if dist < antiTranslocCFG.evadeAllRadius then
                    local dir = (root.Position - hrp.Position)
                    if dir.Magnitude > 0.01 then dir = dir.Unit end
                    pcall(function()
                        root.CFrame = CFrame.new(root.Position + dir * antiTranslocCFG.dodgeDistance * 0.5)
                        root.AssemblyLinearVelocity = Vector3.zero
                    end)
                end
            end
        end

        if antiTranslocCFG.shieldMode then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer or not p.Character then continue end
                local hrp = p.Character:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
                if (hrp.Position - root.Position).Magnitude < antiTranslocCFG.shieldRadius then
                    local pushDir = (root.Position - hrp.Position)
                    if pushDir.Magnitude > 0.01 then pushDir = pushDir.Unit end
                    pcall(function() hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity + pushDir * 200 end)
                end
            end
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer or not p.Character then continue end
            local hrp = p.Character:FindFirstChild("HumanoidRootPart"); if not hrp then continue end
            local data = antiTranslocData[p]
            if not data then initATData(p); data = antiTranslocData[p] end
            local curPos = hrp.Position
            if (curPos - root.Position).Magnitude > antiTranslocCFG.detectRadius then
                data.lastPos = curPos; continue
            end
            if data.lastPos and (curPos - data.lastPos).Magnitude > 5 then
                data.tpTimes[#data.tpTimes + 1] = tick()
                if antiTranslocCFG.memorizePattern then
                    table.insert(data.patternPos, curPos)
                    if #data.patternPos > 20 then table.remove(data.patternPos, 1) end
                end
            end
            cleanTranslocTimes(data, antiTranslocCFG.detectWindow)
            if #data.tpTimes >= antiTranslocCFG.minTps then
                data.tpTimes = {}; doAntiTransloc(p)
            end
            data.lastPos = curPos
        end
    end)
end

local function stopAntiTransloc()
    killConn("antiTransloc"); antiTranslocCFG.enabled = false; antiTranslocData = {}
end

-- ─────────────────────────────────────────────
-- SLING LOGIC
-- ─────────────────────────────────────────────
local slingThread = nil; local slingDir = 1; local slingFadeN = 0

local function stopSling()
    if slingThread then task.cancel(slingThread); slingThread = nil end; slingFadeN = 0
end
local function startSling()
    stopSling(); slingFadeN = 0
    slingThread = task.spawn(function()
        while Toggles.SlingToggle.Value do
            local hrp = getHRP(); if not hrp then task.wait(0.1); continue end
            local dist    = Options.SlingDist.Value     or 10
            local spd     = Options.SlingInterval.Value or 0.1
            local mode    = Options.SlingMode.Value     or "Left-Right"
            local vmult   = Options.SlingVelMult  and Options.SlingVelMult.Value  or 1
            local burst   = Options.SlingBurst    and Options.SlingBurst.Value    or 1
            local fadeMax = Options.SlingFadeIn   and Options.SlingFadeIn.Value   or 0
            local velDir  = Options.SlingVelDir   and Options.SlingVelDir.Value   or "Offset Dir"
            local hum2    = getHum()
            if fadeMax > 0 then slingFadeN = slingFadeN + 1; dist = dist * math.min(slingFadeN / fadeMax, 1) end
            if Toggles.SlingAntiCorrect and Toggles.SlingAntiCorrect.Value and hum2 then
                pcall(function() hum2:ChangeState(Enum.HumanoidStateType.Physics); hum2.PlatformStand = true end)
            end
            local base, offset = hrp.Position, Vector3.zero
            if mode == "Left-Right"   then offset = Vector3.new(dist * slingDir, 0, 0)
            elseif mode == "Forward-Back" then offset = Vector3.new(0, 0, dist * slingDir)
            elseif mode == "Up-Down"  then offset = Vector3.new(0, dist * slingDir, 0)
            else offset = Vector3.new(math.random(-dist,dist), math.random(-dist,dist), math.random(-dist,dist)) end
            slingDir = -slingDir
            local function doSling()
                pcall(function()
                    local target = (Toggles.SlingWithOrbit and Toggles.SlingWithOrbit.Value and hrp.Position or base) + offset
                    hrp.CFrame = CFrame.new(target)
                    local vel
                    if velDir == "Offset Dir" then
                        vel = offset.Unit * (dist / math.max(spd,0.001)) * vmult
                    elseif velDir == "Random" then
                        vel = Vector3.new(math.random(-100,100),math.random(-100,100),math.random(-100,100)).Unit * (dist/math.max(spd,0.001)) * vmult
                    elseif velDir == "Away from Center" then
                        local away = target - Vector3.zero
                        vel = (away.Magnitude>0 and away.Unit or Vector3.new(1,0,0)) * (dist/math.max(spd,0.001)) * vmult
                    else
                        local cam = workspace.CurrentCamera
                        vel = (cam and cam.CFrame.LookVector or Vector3.new(0,0,-1)) * (dist/math.max(spd,0.001)) * vmult
                    end
                    hrp.AssemblyLinearVelocity = vel; hrp.Velocity = vel
                end)
            end
            for _ = 1, burst do doSling() end
            if Toggles.SlingDoubleFlush and Toggles.SlingDoubleFlush.Value then task.wait(); doSling() end
            if Toggles.SlingAntiCorrect and Toggles.SlingAntiCorrect.Value and hum2 then
                pcall(function() hum2.PlatformStand = false; hum2:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
            task.wait(spd)
        end
        slingThread = nil; slingFadeN = 0
    end)
end

-- ─────────────────────────────────────────────
-- ─────────────────────────────────────────────
-- UI: Void Tab (meowlua void)
-- ─────────────────────────────────────────────
local VLeft  = Tabs.Void:AddLeftGroupbox("Void")
local VRight = Tabs.Void:AddRightGroupbox("Void Hide")

local _xyzSg, _xyzConn, _xyzVals

local function buildXYZOverlay()
 if _xyzSg and _xyzSg.Parent then return end
 local sg = Instance.new("ScreenGui")
 sg.Name = "EtherealXYZOverlay"; sg.ResetOnSpawn = false; sg.DisplayOrder = 9999
 local coreOk = pcall(function() sg.Parent = game:GetService("CoreGui") end)
 if not coreOk then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
 _xyzSg = sg
 local panel = Instance.new("Frame")
 panel.Size = UDim2.new(0, 170, 0, 96); panel.Position = UDim2.new(0, 14, 0.5, -48)
 panel.BackgroundColor3 = Color3.fromRGB(18, 18, 20); panel.BackgroundTransparency = 0.08
 panel.BorderSizePixel = 0; panel.Parent = sg
 local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0,7); pc.Parent = panel
 _xyzVals = {}
 for i, axis in ipairs({"X","Y","Z"}) do
  local y = 30 + (i-1)*20
  local al = Instance.new("TextLabel")
  al.Size = UDim2.new(0,18,0,18); al.Position = UDim2.new(0,10,0,y)
  al.BackgroundTransparency = 1; al.Text = axis
  al.TextColor3 = Color3.fromRGB(120,120,130); al.Font = Enum.Font.GothamBold
  al.TextSize = 12; al.TextXAlignment = Enum.TextXAlignment.Left; al.Parent = panel
  local vl = Instance.new("TextLabel")
  vl.Size = UDim2.new(1,-30,0,18); vl.Position = UDim2.new(0,14,0,y)
  vl.BackgroundTransparency = 1; vl.Text = "0"
  vl.TextColor3 = Color3.fromRGB(230,230,235); vl.Font = Enum.Font.Gotham
  vl.TextSize = 12; vl.TextXAlignment = Enum.TextXAlignment.Right; vl.Parent = panel
  _xyzVals[axis] = vl
 end
 _xyzConn = RunService.Heartbeat:Connect(function()
  local c = LocalPlayer.Character
  local hrp = c and c:FindFirstChild("HumanoidRootPart")
  if hrp then
   local p = hrp.Position
   _xyzVals.X.Text = tostring(math.floor(p.X+0.5))
   _xyzVals.Y.Text = tostring(math.floor(p.Y+0.5))
   _xyzVals.Z.Text = tostring(math.floor(p.Z+0.5))
  else _xyzVals.X.Text="-"; _xyzVals.Y.Text="-"; _xyzVals.Z.Text="-" end
 end)
end

local function destroyXYZOverlay()
 if _xyzConn then pcall(function() _xyzConn:Disconnect() end); _xyzConn = nil end
 if _xyzSg   then pcall(function() _xyzSg:Destroy() end);     _xyzSg   = nil end
end

-- ── Godmode / Melee bypass ──
getgenv().get_hrp = getgenv().get_hrp or function(plr)
 local p = plr or LocalPlayer
 if not p.Character then return nil end
 return p.Character:FindFirstChild("HumanoidRootPart")
end

local melee_conn           = nil
local melee_active         = false
local melee_fake_cf_store  = {}
local MELEE_FAKE_OFFSET    = Vector3.new(9000, 9000, 9000)

local function melee_in_y_range(my_hrp, target_hrp)
 local cfg2   = getgenv().config
 local range  = cfg2.melee_bypass_y_range or 10
 local y_diff = my_hrp.Position.Y - target_hrp.Position.Y
 return y_diff >= 0 and y_diff <= range
end

getgenv().start_melee_bypass = function()
 if melee_active then return end
 melee_active = true
 getgenv().config.melee_bypass_enabled = true
 melee_conn = RunService.Heartbeat:Connect(function()
  local cfg2 = getgenv().config  -- re-read live each tick
  if not cfg2 or not cfg2.melee_bypass_enabled then return end
  local my_hrp = getgenv().get_hrp(LocalPlayer)
  if not my_hrp then return end
  pcall(function()
   for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
     local h = p.Character:FindFirstChild("HumanoidRootPart")
     if h then
      if melee_in_y_range(my_hrp, h) then
       melee_fake_cf_store[p] = h.CFrame
       local mt     = getrawmetatable(h)
       local old_ni = mt and rawget(mt, "__newindex")
       local fake_cf = CFrame.new(MELEE_FAKE_OFFSET)
       if old_ni then pcall(old_ni, h, "CFrame", fake_cf)
       else rawset(h, "CFrame", fake_cf) end
       h.AssemblyLinearVelocity = Vector3.zero
      else melee_fake_cf_store[p] = nil end
     end
    end
   end
  end)
 end)
end

getgenv().stop_melee_bypass = function()
 melee_active = false
 getgenv().config.melee_bypass_enabled = false
 if melee_conn then melee_conn:Disconnect(); melee_conn = nil end
 melee_fake_cf_store = {}
end

-- ── Desync ──
local desync_heartbeat              = nil
local desync_render                 = nil
local desync_realVel                = nil
local desync_angle_accum            = 0
local desync_unhittable_conn        = nil
local desync_unhittable_render      = nil
local desync_unhittable_realCF      = nil
local desync_unhittable_fake_store  = {}

getgenv().start_desync = function()
 if desync_heartbeat then desync_heartbeat:Disconnect() end
 if desync_render    then desync_render:Disconnect()    end
 desync_realVel = nil; desync_angle_accum = 0
 desync_heartbeat = RunService.Heartbeat:Connect(function(dt)
  local cfg2 = getgenv().config  -- re-read live each tick so slider changes apply
  if not cfg2 or not cfg2.desync_enabled then return end
  local hrp = getgenv().get_hrp(LocalPlayer)
  if not hrp then return end
  desync_realVel  = hrp.AssemblyLinearVelocity
  local intensity = math.clamp(cfg2.desync_intensity or 50, 1, 100)
  local spd       = math.clamp(cfg2.desync_speed     or 10, 1, 100)
  local base_ang  = math.rad(cfg2.desync_angle or 90)
  local jitter    = math.clamp(cfg2.desync_jitter or 20, 0, 180)
  local dir_sign  = cfg2.desync_flip and -1 or 1
  desync_angle_accum = desync_angle_accum + math.rad(spd * dt * 360)
  local angle = base_ang + math.rad((math.random()-0.5)*jitter*2) + desync_angle_accum
  local mag   = (intensity/100) * 50000
  local spoof = Vector3.new(math.cos(angle)*mag*dir_sign, (math.random()-0.5)*mag*0.5, math.sin(angle)*mag*dir_sign)
  local mt = getrawmetatable(hrp)
  local ni = mt and rawget(mt, "__newindex")
  if ni then pcall(ni, hrp, "AssemblyLinearVelocity", spoof)
  else   pcall(function() hrp.AssemblyLinearVelocity = spoof end) end
  if sethiddenproperty then pcall(sethiddenproperty, hrp, "AssemblyLinearVelocity", spoof) end
 end)
 desync_render = RunService.RenderStepped:Connect(function()
  local cfg2 = getgenv().config
  local hrp = getgenv().get_hrp(LocalPlayer)
  if cfg2 and cfg2.desync_enabled and hrp and desync_realVel then
   hrp.AssemblyLinearVelocity = desync_realVel
  end
 end)
end

getgenv().stop_desync = function()
 if desync_heartbeat then desync_heartbeat:Disconnect(); desync_heartbeat = nil end
 if desync_render    then desync_render:Disconnect();    desync_render    = nil end
 desync_realVel = nil; desync_angle_accum = 0
 getgenv().config.desync_enabled = false
end

getgenv().start_unhittable_desync = function()
 if desync_unhittable_conn   then desync_unhittable_conn:Disconnect() end
 if desync_unhittable_render then desync_unhittable_render:Disconnect() end
 desync_unhittable_realCF = nil; desync_unhittable_fake_store = {}
 desync_unhittable_conn = RunService.Heartbeat:Connect(function()
  local cfg2 = getgenv().config  -- re-read live each tick
  if not cfg2 or not cfg2.desync_unhittable_enabled then return end
  local hrp = getgenv().get_hrp(LocalPlayer)
  if not hrp then return end
  desync_unhittable_realCF = hrp.CFrame
  local iters  = math.clamp(cfg2.desync_unhittable_iters or 100, 1, 500)
  local radius = math.max(cfg2.desync_unhittable_radius or 9000, 1)
  local yr     = math.max(cfg2.desync_unhittable_y_range or 10, 1)
  local offset = radius * (math.clamp(cfg2.desync_unhittable_intensity or 50, 1, 100)/100)
  local base   = hrp.Position
  local mt = getrawmetatable(hrp); local ni = mt and rawget(mt, "__newindex")
  for _ = 1, iters do
   local sx = (math.random()<0.5) and 1 or -1
   local sz = (math.random()<0.5) and 1 or -1
   local fake_cf = CFrame.new(base.X+sx*(offset*(0.5+math.random()*0.5)), base.Y+(math.random()-0.5)*offset*0.3, base.Z+sz*(offset*(0.5+math.random()*0.5)))
   if ni then pcall(ni, hrp, "CFrame", fake_cf); pcall(ni, hrp, "AssemblyLinearVelocity", Vector3.zero)
   else   pcall(function() hrp.CFrame=fake_cf; hrp.AssemblyLinearVelocity=Vector3.zero end) end
   if sethiddenproperty then pcall(sethiddenproperty, hrp, "CFrame", fake_cf); pcall(sethiddenproperty, hrp, "AssemblyLinearVelocity", Vector3.zero) end
  end
  pcall(function()
   for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
     local eh = p.Character:FindFirstChild("HumanoidRootPart")
     if eh then
      local y_diff = hrp.Position.Y - eh.Position.Y
      if y_diff >= 0 and y_diff <= yr then
       desync_unhittable_fake_store[p] = eh.CFrame
       local emt = getrawmetatable(eh); local eni = emt and rawget(emt, "__newindex")
       local fake_cf_u = CFrame.new(MELEE_FAKE_OFFSET)
       if eni then pcall(eni, eh, "CFrame", fake_cf_u)
       else pcall(function() rawset(eh, "CFrame", fake_cf_u) end) end
       eh.AssemblyLinearVelocity = Vector3.zero
      else desync_unhittable_fake_store[p] = nil end
     end
    end
   end
  end)
 end)
 desync_unhittable_render = RunService.RenderStepped:Connect(function()
  local cfg2 = getgenv().config
  local hrp = getgenv().get_hrp(LocalPlayer)
  if cfg2 and cfg2.desync_unhittable_enabled and hrp and desync_unhittable_realCF then
   pcall(function() hrp.CFrame=desync_unhittable_realCF; hrp.AssemblyLinearVelocity=Vector3.zero end)
  end
 end)
end

getgenv().stop_unhittable_desync = function()
 if desync_unhittable_conn   then desync_unhittable_conn:Disconnect();   desync_unhittable_conn   = nil end
 if desync_unhittable_render then desync_unhittable_render:Disconnect(); desync_unhittable_render = nil end
 desync_unhittable_realCF = nil; desync_unhittable_fake_store = {}
 getgenv().config.desync_unhittable_enabled = false
end

-- ── Void tab controls ──
VLeft:AddToggle("vs_en", { Text="Void", Default=false, Tooltip="Makes you unhittable utilizing void movement." }):OnChanged(function(v)
 local cfg2 = getgenv().config
 cfg2.vst_enabled = v
 if v then
  pcall(getgenv().start_voidspam_type)
  buildXYZOverlay()
  if (cfg2.vst_type or "Unhittability") == "Unhittability" then
   cfg2.melee_bypass_enabled = true
   cfg2.melee_bypass_y_range = cfg2.vst_unhittability_y_range or 10
   if not melee_active then getgenv().start_melee_bypass() end
  end
 else
  pcall(getgenv().disable_voidspam_type)
  destroyXYZOverlay()
  if not cfg2.godmode_enabled then getgenv().stop_melee_bypass() end
 end
end)
VLeft:AddDropdown("vs_type_sel", { Text="Void Mode", Default=1, Values={"Unhittability","Defend","Attack","Bait","Extreme","Random"} }):OnChanged(function(v)
 local cfg2 = getgenv().config
 cfg2.vst_type = v
 if cfg2.vst_enabled then
  pcall(getgenv().stop_voidspam_type); pcall(getgenv().start_voidspam_type)
  if v == "Unhittability" then
   cfg2.melee_bypass_enabled = true
   cfg2.melee_bypass_y_range = cfg2.vst_unhittability_y_range or 10
   if not melee_active then getgenv().start_melee_bypass() end
  else
   if not cfg2.godmode_enabled then getgenv().stop_melee_bypass() end
  end
 end
end)
VLeft:AddDropdown("vs_void_dir_sel", { Text="Void Direction", Default=1, Values={"Random","Forward","Backward","Left","Right","Up","Down","Camera","Directional"} }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.vs_void_direction=v end)
VLeft:AddSlider("vst_spin_spd",  { Text="Spin Speed",    Default=1e85, Min=1, Max=1e85,   Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.vst_spin_speed=v end)
VLeft:AddSlider("evs_burst_sl",  { Text="Iterations",    Default=100,  Min=1, Max=1000,   Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.evs_burst=v end)
VLeft:AddToggle("evs_kv_tog",    { Text="Kill Velocity", Default=true  }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.evs_kill_velocity=v end)
VLeft:AddToggle("evs_sb_tog",    { Text="Snap Back",     Default=false }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.evs_snap_back=v end)
VLeft:AddToggle("evs_srb_tog",   { Text="Sync To Ragebot", Default=false }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.evs_sync_to_ragebot=v end)
VLeft:AddToggle("vs_char_orig",  { Text="Character Origin", Default=false }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.vs_char_origin=v end)
VLeft:AddSlider("vs_min_dist_sl",{ Text="Min Distance",  Default=1,     Min=1, Max=50000,  Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.vs_min_dist=v end)
VLeft:AddSlider("vs_max_dist_sl",{ Text="Max Distance",  Default=50000, Min=1, Max=500000, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.vs_max_dist=v end)
VLeft:AddSlider("vst_unhit_yr",  { Text="Activation Range", Default=10, Min=1, Max=50,    Rounding=0, Tooltip="Activates melee bypass when enemy is within this Y below you." }):OnChanged(function(v)
 local cfg2=getgenv().config; cfg2.vst_unhittability_y_range=v; cfg2.melee_bypass_y_range=v
end)
VRight:AddToggle("vh_en", { Text="Void Hide", Default=false, Tooltip="Teleports you into the void." }):OnChanged(function(v)
 local cfg2=getgenv().config; cfg2.void_hide_enabled=v
 if v then pcall(getgenv().start_void_hide) else pcall(getgenv().stop_void_hide) end
end)
VRight:AddSlider("vh_x", { Text="X Distance", Default=1000000, Min=1, Max=12e25, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.void_hide_x=v end)
VRight:AddSlider("vh_y", { Text="Y Distance", Default=9e25,    Min=1, Max=12e25, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.void_hide_y=v end)
VRight:AddSlider("vh_z", { Text="Z Distance", Default=1000000, Min=1, Max=12e25, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.void_hide_z=v end)
VRight:AddToggle("vh_srb", { Text="Sync To Ragebot", Default=false }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.void_hide_sync_to_ragebot=v end)

-- ─────────────────────────────────────────────
-- UI: Orbit Tab
-- ─────────────────────────────────────────────
local OLeft  = Tabs.Orbit:AddLeftGroupbox("Orbit")
local ORight = Tabs.Orbit:AddRightGroupbox("Orbit Advanced")

OLeft:AddToggle("orbit_en", { Text="Orbit", Default=false, Tooltip="Orbits your character in a void-driven orbital pattern." }):OnChanged(function(v)
 local cfg2=getgenv().config; cfg2.orbit_enabled=v
 if v then pcall(getgenv().start_orbit); buildXYZOverlay() else pcall(getgenv().stop_orbit); destroyXYZOverlay() end
end)
OLeft:AddSlider("orbit_rad",    { Text="Orbit Radius",  Default=50000, Min=1,       Max=500000, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_radius=v end)
OLeft:AddSlider("orbit_spd",    { Text="Orbit Speed",   Default=5,     Min=1,       Max=200,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_speed=v end)
OLeft:AddSlider("orbit_iters",  { Text="Iterations",    Default=100,   Min=1,       Max=500,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_iters=v end)
OLeft:AddSlider("orbit_hgt",    { Text="Height Offset", Default=0,     Min=-500000, Max=500000, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_height=v end)
OLeft:AddSlider("orbit_jit",    { Text="Jitter",        Default=0,     Min=0,       Max=100000, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_jitter=v end)
OLeft:AddSlider("orbit_yb",     { Text="Y Bias",        Default=0,     Min=-500000, Max=0,      Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_y_bias=v end)
OLeft:AddSlider("orbit_df",     { Text="Depth Floor",   Default=0,     Min=0,       Max=500000, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_depth_floor=v end)
OLeft:AddSlider("orbit_tight",  { Text="Tightness",     Default=10,    Min=1,       Max=100,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_tightness=v end)
OLeft:AddSlider("orbit_wfreq",  { Text="Wave Freq",     Default=1,     Min=1,       Max=20,     Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_wave_freq=v end)
OLeft:AddSlider("orbit_phase",  { Text="Phase Offset",  Default=0,     Min=0,       Max=360,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_phase_offset=math.rad(v) end)
OLeft:AddSlider("orbit_layers", { Text="Layer Count",   Default=1,     Min=1,       Max=8,      Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_layer_count=v end)
OLeft:AddSlider("orbit_loff",   { Text="Layer Offset",  Default=0,     Min=0,       Max=360,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_layer_offset=v end)
OLeft:AddSlider("orbit_wstr",   { Text="Warp Strength", Default=50,    Min=1,       Max=100,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_warp_strength=v end)
OLeft:AddSlider("orbit_chaos",  { Text="Chaos Blend",   Default=0,     Min=0,       Max=100,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_chaos_blend=v end)
OLeft:AddDropdown("orbit_pat_sel",    { Text="Pattern",    Default=1, Values={"Circle","Ellipse","Figure8","Helix","Wave","Spiral","Pulse"} }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_pattern=v end)
OLeft:AddDropdown("orbit_target_sel", { Text="Target",     Default=1, Values={"Self","Closest"} }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_target=v end)
OLeft:AddDropdown("orbit_axis_sel",   { Text="Orbit Axis", Default=1, Values={"Y","X","Z"} }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_axis=v end)
OLeft:AddDropdown("orbit_dir_sel",    { Text="Direction",  Default=1, Values={"Clockwise","Counter-clockwise"} }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_direction=v end)
OLeft:AddDropdown("orbit_warp_sel",   { Text="Warp Mode",  Default=1, Values={"Instant","Lerp","Spring","Bounce","Elastic"} }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_warp_mode=v end)
OLeft:AddDropdown("orbit_fall_sel",   { Text="Falloff",    Default=1, Values={"None","Linear","Exp","Sine","Cosine"} }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_falloff=v end)
OLeft:AddToggle("orbit_kv",  { Text="Kill Velocity",    Default=true  }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_kill_velocity=v end)
OLeft:AddToggle("orbit_srb", { Text="Sync To Ragebot",  Default=false }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_sync_ragebot=v end)
OLeft:AddToggle("orbit_ix",  { Text="Invert X",         Default=false }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_invert_x=v end)
OLeft:AddToggle("orbit_iz",  { Text="Invert Z",         Default=false }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.orbit_invert_z=v end)

-- ─────────────────────────────────────────────
-- UI: Movement Tab (Desync + Godmode)
-- ─────────────────────────────────────────────
local BoxDesync  = Tabs.Movement:AddLeftGroupbox("Desync")
local BoxGodmode = Tabs.Movement:AddRightGroupbox("Godmode")

BoxDesync:AddToggle("ds_en", { Text="Desync", Default=false, Tooltip="Spoofs your server-side velocity." }):OnChanged(function(v)
 local cfg2=getgenv().config; cfg2.desync_enabled=v
 if v then getgenv().start_desync() else getgenv().stop_desync() end
end)
BoxDesync:AddSlider("ds_int",  { Text="Intensity", Default=50, Min=1, Max=100, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_intensity=v end)
BoxDesync:AddSlider("ds_spd",  { Text="Speed",     Default=10, Min=1, Max=100, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_speed=v end)
BoxDesync:AddSlider("ds_ang",  { Text="Angle",     Default=90, Min=0, Max=360, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_angle=v end)
BoxDesync:AddSlider("ds_jit",  { Text="Jitter",    Default=20, Min=0, Max=180, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_jitter=v end)
BoxDesync:AddToggle("ds_flip", { Text="Flip", Default=false, Tooltip="Inverts the desync direction." }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_flip=v end)
BoxDesync:AddToggle("ds_uhit_en", { Text="Unhittable Desync", Default=false, Tooltip="Rapid fake CFrame packets + velocity spoof makes you unhittable." }):OnChanged(function(v)
 local cfg2=getgenv().config; cfg2.desync_unhittable_enabled=v
 if v then getgenv().start_unhittable_desync() else getgenv().stop_unhittable_desync() end
end)
BoxDesync:AddSlider("ds_uhit_int",   { Text="Unhittable Intensity",  Default=50,   Min=1,   Max=100,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_unhittable_intensity=v end)
BoxDesync:AddSlider("ds_uhit_rad",   { Text="Unhittable Radius",     Default=9000, Min=100, Max=100000, Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_unhittable_radius=v end)
BoxDesync:AddSlider("ds_uhit_iters", { Text="Unhittable Iterations", Default=100,  Min=1,   Max=500,    Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_unhittable_iters=v end)
BoxDesync:AddSlider("ds_uhit_yr",    { Text="Activation Range",      Default=10,   Min=1,   Max=50,     Rounding=0 }):OnChanged(function(v) local cfg2=getgenv().config; cfg2.desync_unhittable_y_range=v end)

BoxGodmode:AddToggle("gm_en", { Text="Godmode", Default=false, Tooltip="Makes you unhittable." }):OnChanged(function(v)
 local cfg2=getgenv().config
 cfg2.godmode_enabled=v; cfg2.melee_bypass_enabled=v
 if v then getgenv().start_melee_bypass() else getgenv().stop_melee_bypass() end
end)
BoxGodmode:AddSlider("gm_yr", { Text="Activation Range", Default=10, Min=1, Max=50, Rounding=0, Tooltip="Activates godmode when enemy is within this Y below you." }):OnChanged(function(v)
 local cfg2=getgenv().config; cfg2.godmode_y_range=v; cfg2.melee_bypass_y_range=v
end)

-- UI: Anti-Aim Tab
-- ─────────────────────────────────────────────
local AALeft  = Tabs.AntiAim:AddLeftGroupbox("Anti-Aim")
local AARight = Tabs.AntiAim:AddRightGroupbox("Advanced")

-- ── Left: core controls ──
AALeft:AddToggle("AaToggle", {
    Text    = "Enable Anti-Aim",
    Default = false,
    Tooltip = "Manipulates HRP angles server-side to break hitscan",
    Callback = function(v) aaSettings.enabled = v; if v then startAntiAim() else stopAntiAim() end end,
})
AALeft:AddDropdown("AaMode", {
    Text    = "Mode",
    Default = "RandomSpin",
    Values  = { "Spin", "Jitter", "Static", "Up", "Down", "Side", "RandomSpin", "Custom" },
    Callback = function(v) aaSettings.mode = v end,
})
AALeft:AddSlider("AaSpeed", {
    Text     = "Speed (deg/s)",
    Default  = 5000,
    Min      = 100,
    Max      = 5000,
    Rounding = 0,
    Callback = function(v) aaSettings.speed = v end,
})
AALeft:AddSlider("AaPitch", {
    Text     = "Pitch Angle",
    Default  = 45,
    Min      = 0,
    Max      = 90,
    Rounding = 0,
    Callback = function(v) aaSettings.pitchAngle = v end,
})
AALeft:AddSlider("AaYaw", {
    Text     = "Yaw Angle",
    Default  = 45,
    Min      = 0,
    Max      = 180,
    Rounding = 0,
    Callback = function(v) aaSettings.yawAngle = v end,
})
AALeft:AddSlider("AaStaticYaw", {
    Text     = "Static Yaw",
    Default  = 90,
    Min      = -360,
    Max      = 360,
    Rounding = 0,
    Callback = function(v) aaSettings.staticYaw = v end,
})
AALeft:AddSlider("AaStaticPit", {
    Text     = "Static Pitch",
    Default  = 0,
    Min      = -90,
    Max      = 90,
    Rounding = 0,
    Callback = function(v) aaSettings.staticPitch = v end,
})
AALeft:AddSlider("AaCustomYaw", {
    Text     = "Custom Yaw",
    Default  = 180,
    Min      = -360,
    Max      = 360,
    Rounding = 0,
    Callback = function(v) aaSettings.customYaw = v end,
})
AALeft:AddSlider("AaCustomPit", {
    Text     = "Custom Pitch",
    Default  = 0,
    Min      = -90,
    Max      = 90,
    Rounding = 0,
    Callback = function(v) aaSettings.customPitch = v end,
})
AALeft:AddToggle("AaRandSpd",  { Text = "Random Speed",  Default = true,  Callback = function(v) aaSettings.randomSpeed = v end })
AALeft:AddToggle("AaJitPitch", { Text = "Jitter Pitch",  Default = true,  Callback = function(v) aaSettings.jitterPitch = v end })
AALeft:AddToggle("AaJitYaw",   { Text = "Jitter Yaw",    Default = true,  Callback = function(v) aaSettings.jitterYaw   = v end })

-- ── Right: modifiers ──
AARight:AddToggle("AaRoll", {
    Text    = "Roll Enabled",
    Default = false,
    Callback = function(v) aaSettings.rollEnabled = v end,
})
AARight:AddSlider("AaRollSpd", {
    Text     = "Roll Speed (deg/s)",
    Default  = 360,
    Min      = 10,
    Max      = 1080,
    Rounding = 0,
    Callback = function(v) aaSettings.rollSpeed = v end,
})
AARight:AddToggle("AaDesync", {
    Text    = "Desync Offset",
    Default = false,
    Tooltip = "Adds a fixed yaw offset to fake server-side angle",
    Callback = function(v) aaSettings.desyncMode = v end,
})
AARight:AddSlider("AaDesyncOff", {
    Text     = "Desync Angle (deg)",
    Default  = 180,
    Min      = 0,
    Max      = 360,
    Rounding = 0,
    Callback = function(v) aaSettings.desyncOffset = v end,
})
AARight:AddToggle("AaMicro", {
    Text    = "Micro Jitter",
    Default = false,
    Tooltip = "High-frequency sine noise on yaw + pitch",
    Callback = function(v) aaSettings.microJitter = v end,
})
AARight:AddSlider("AaMicroAmp", {
    Text     = "Micro Jitter Amp",
    Default  = 5,
    Min      = 0,
    Max      = 45,
    Rounding = 1,
    Callback = function(v) aaSettings.microJitterAmp = v end,
})
AARight:AddSlider("AaMicroSpd", {
    Text     = "Micro Jitter Speed",
    Default  = 30,
    Min      = 1,
    Max      = 120,
    Rounding = 1,
    Callback = function(v) aaSettings.microJitterSpeed = v end,
})
AARight:AddToggle("AaBreathe", {
    Text    = "Breathe Effect",
    Default = false,
    Tooltip = "Slow sinusoidal pitch oscillation",
    Callback = function(v) aaSettings.breatheEffect = v end,
})
AARight:AddSlider("AaBreatheAmp", {
    Text     = "Breathe Amplitude",
    Default  = 3,
    Min      = 0,
    Max      = 20,
    Rounding = 1,
    Callback = function(v) aaSettings.breatheAmp = v end,
})
AARight:AddSlider("AaBreatheSpd", {
    Text     = "Breathe Speed",
    Default  = 1,
    Min      = 0.1,
    Max      = 10,
    Rounding = 1,
    Callback = function(v) aaSettings.breatheSpeed = v end,
})
AARight:AddToggle("AaRandFlip", {
    Text    = "Random Flip",
    Default = false,
    Tooltip = "Random chance to flip yaw 180° each tick",
    Callback = function(v) aaSettings.randomFlip = v end,
})
AARight:AddSlider("AaFlipChance", {
    Text     = "Flip Chance (%)",
    Default  = 5,
    Min      = 1,
    Max      = 50,
    Rounding = 0,
    Callback = function(v) aaSettings.flipChance = v / 100 end,
})

-- ─────────────────────────────────────────────
-- UI: Sling Tab
-- ─────────────────────────────────────────────
local SLeft  = Tabs.Sling:AddLeftGroupbox("Sling Anti-Aim")
local SRight = Tabs.Sling:AddRightGroupbox("Sling Options")

SLeft:AddToggle("SlingToggle",   { Text="Enable Sling", Default=false, Tooltip="Rubber-bands HRP between extreme points", Callback=function(v) if v then startSling() else stopSling() end end })
SLeft:AddSlider("SlingDist",     { Text="Distance (studs)", Default=10,  Min=1,    Max=100, Rounding=1 })
SLeft:AddSlider("SlingInterval", { Text="Interval (s)",     Default=0.1, Min=0.01, Max=1,   Rounding=2 })
SLeft:AddDropdown("SlingMode",   { Text="Pattern", Values={"Left-Right","Forward-Back","Up-Down","Random"}, Default="Left-Right" })
SLeft:AddToggle("SlingWithOrbit",{ Text="Combine with Orbit", Default=false })

SRight:AddSlider("SlingVelMult",    { Text="Velocity Multiplier", Default=1,  Min=0.1, Max=20, Rounding=1 })
SRight:AddSlider("SlingBurst",      { Text="Burst Repeats",       Default=1,  Min=1,   Max=10, Rounding=0 })
SRight:AddToggle("SlingAntiCorrect",{ Text="Anti-Correction",     Default=false })
SRight:AddToggle("SlingDoubleFlush",{ Text="Double Flush",        Default=false })
SRight:AddDropdown("SlingVelDir",   { Text="Velocity Direction", Values={"Offset Dir","Random","Away from Center","Camera Forward"}, Default="Offset Dir" })
SRight:AddSlider("SlingFadeIn",     { Text="Fade-In Ticks",       Default=0,  Min=0,   Max=20, Rounding=0 })

-- ─────────────────────────────────────────────
-- UI: Anti Translocation Tab (from kill_him)
-- ─────────────────────────────────────────────
local ATLeft  = Tabs.AntiTL:AddLeftGroupbox("Anti Translocation")
local ATRight = Tabs.AntiTL:AddRightGroupbox("Advanced Options")

ATLeft:AddToggle("AntiTranslocToggle", { Text="Enable Anti Translocation", Default=false,
    Tooltip="Detects and dodges enemy translocation patterns",
    Callback=function(v) antiTranslocCFG.enabled=v; if v then startAntiTransloc() else stopAntiTransloc() end end })
ATLeft:AddDropdown("AntiTranslocMode", { Text="Mode", Default="Evade", Values={"Evade","Freeze","Predict"}, Callback=function(v) antiTranslocCFG.mode=v end })
ATLeft:AddSlider("ATRadius",      { Text="Detect Radius",        Default=100, Min=10, Max=500,  Rounding=0, Callback=function(v) antiTranslocCFG.detectRadius=v end })
ATLeft:AddSlider("ATWindow",      { Text="Detect Window (×0.1)", Default=5,   Min=1,  Max=20,   Rounding=0, Callback=function(v) antiTranslocCFG.detectWindow=v*0.1 end })
ATLeft:AddSlider("ATMinTps",      { Text="Min TPs to Trigger",   Default=3,   Min=2,  Max=10,   Rounding=0, Callback=function(v) antiTranslocCFG.minTps=v end })
ATLeft:AddSlider("ATDodgeDist",   { Text="Dodge Distance",        Default=30,  Min=5,  Max=150,  Rounding=0, Callback=function(v) antiTranslocCFG.dodgeDistance=v end })
ATLeft:AddSlider("ATCooldown",    { Text="Cooldown (×0.1s)",      Default=2,   Min=1,  Max=20,   Rounding=0, Callback=function(v) antiTranslocCFG.dodgeCooldown=v*0.1 end })
ATLeft:AddSlider("ATFreeze",      { Text="Freeze Time (×0.1s)",   Default=1,   Min=1,  Max=20,   Rounding=0, Callback=function(v) antiTranslocCFG.freezeTime=v*0.1 end })
ATLeft:AddSlider("ATPredict",     { Text="Predict Lead (×0.1s)",  Default=1,   Min=1,  Max=10,   Rounding=0, Callback=function(v) antiTranslocCFG.predictLead=v*0.1 end })
ATLeft:AddToggle("ATNotify",      { Text="Notify",                Default=true, Callback=function(v) antiTranslocCFG.notify=v end })

ATRight:AddToggle("ATCounterTp",      { Text="Counter Teleport",    Default=false, Callback=function(v) antiTranslocCFG.counterTeleport=v end })
ATRight:AddSlider("ATCounterOffset",  { Text="Counter TP Offset",   Default=50,  Min=5,  Max=200,  Rounding=0, Callback=function(v) antiTranslocCFG.counterTpOffset=v end })
ATRight:AddToggle("ATAutoEvadeAll",   { Text="Auto Evade All",      Default=false, Callback=function(v) antiTranslocCFG.autoEvadeAll=v end })
ATRight:AddSlider("ATEvadeAllRadius", { Text="Evade All Radius",    Default=200, Min=10, Max=1000, Rounding=0, Callback=function(v) antiTranslocCFG.evadeAllRadius=v end })
ATRight:AddToggle("ATShieldMode",     { Text="Shield Mode",         Default=false, Callback=function(v) antiTranslocCFG.shieldMode=v end })
ATRight:AddSlider("ATShieldRadius",   { Text="Shield Radius",       Default=20,  Min=5,  Max=100,  Rounding=0, Callback=function(v) antiTranslocCFG.shieldRadius=v end })
ATRight:AddToggle("ATBounceback",     { Text="Bounceback",          Default=false, Callback=function(v) antiTranslocCFG.bounceback=v end })
ATRight:AddSlider("ATBouncebackDist", { Text="Bounceback Distance", Default=100, Min=10, Max=500,  Rounding=0, Callback=function(v) antiTranslocCFG.bouncebackDist=v end })
ATRight:AddToggle("ATSpinEvade",      { Text="Spin Evade",          Default=false, Callback=function(v) antiTranslocCFG.spinEvade=v end })
ATRight:AddSlider("ATSpinEvadeSpeed", { Text="Spin Evade Speed",    Default=360, Min=10, Max=720,  Rounding=0, Callback=function(v) antiTranslocCFG.spinEvadeSpeed=v end })
ATRight:AddToggle("ATMultiDodge",     { Text="Multi Dodge",         Default=false, Callback=function(v) antiTranslocCFG.multiDodge=v end })
ATRight:AddSlider("ATMultiDodgeCnt",  { Text="Multi Dodge Count",   Default=3,   Min=2,  Max=10,   Rounding=0, Callback=function(v) antiTranslocCFG.multiDodgeCount=v end })
ATRight:AddToggle("ATMemorize",       { Text="Memorize Pattern",    Default=false, Callback=function(v) antiTranslocCFG.memorizePattern=v end })

-- ─────────────────────────────────────────────
-- UI: Settings Tab
-- ─────────────────────────────────────────────
local CLeft = Tabs.Config:AddLeftGroupbox("Menu")

CLeft:AddToggle("KeybindMenuOpen", { Text="Show Keybind Menu", Default=true,  Callback=function(v) Library.KeybindFrame.Visible=v end })
CLeft:AddToggle("ShowCursor",      { Text="Custom Cursor",     Default=true,  Callback=function(v) Library.ShowCustomCursor=v end })
CLeft:AddLabel("Menu Bind"):AddKeyPicker("MenuBind", { Default="RightShift", NoUI=true, Text="Toggle Menu" })

Library.ToggleKeybind = Options.MenuBind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuBind" })
ThemeManager:SetFolder("EtherealFree")
SaveManager:SetFolder("EtherealFree/Configs")
SaveManager:BuildConfigSection(Tabs.Config)
ThemeManager:ApplyToTab(Tabs.Config)

-- ─────────────────────────────────────────────
-- Unload
-- ─────────────────────────────────────────────
-- ─────────────────────────────────────────────
-- POSITION OVERLAY (Drawing)
-- Matches the screenshot: dark panel, X/Y/Z rows, colour-coded bars
-- Numbers = 000 idle, 999998 when any feature is live
-- ─────────────────────────────────────────────
local overlay = {}

local function makeRect(x, y, w, h, colour, trans)
    local r = Drawing.new("Square")
    r.Visible           = true
    r.Filled            = true
    r.Color             = colour
    r.Transparency      = trans or 1
    r.Size              = Vector2.new(w, h)
    r.Position          = Vector2.new(x, y)
    r.ZIndex            = 5
    return r
end

local function makeText(x, y, text, colour, size)
    local t = Drawing.new("Text")
    t.Visible           = true
    t.Text              = text
    t.Color             = colour
    t.Size              = size or 13
    t.Position          = Vector2.new(x, y)
    t.Font              = Drawing.Fonts.Plex
    t.Outline           = true
    t.OutlineColor      = Color3.new(0, 0, 0)
    t.ZIndex            = 6
    return t
end

local OX, OY   = 20, 20          -- top-left corner of the panel
local PW, PH   = 175, 90         -- panel width / height
local ROW_H    = 20               -- height of each XYZ row
local BAR_W    = PW - 4          -- coloured bar width
local LABEL_X  = OX + 6
local VALUE_X  = OX + 28

-- background panel
overlay.bg = makeRect(OX, OY, PW, PH, Color3.fromRGB(15, 15, 20), 0.35)

-- "● POSITION" header
overlay.dot    = makeText(OX + 6, OY + 5, "●", Color3.fromRGB(80, 220, 100), 12)
overlay.header = makeText(OX + 20, OY + 5, "POSITION", Color3.fromRGB(200, 200, 210), 12)

-- row backgrounds (coloured bars, semi-transparent, like the screenshot)
local rowY = { OY + 22, OY + 44, OY + 66 }
local barColours = {
    Color3.fromRGB(120, 25,  25),   -- X  red
    Color3.fromRGB(25,  80,  25),   -- Y  green
    Color3.fromRGB(20,  40, 100),   -- Z  blue
}
overlay.bars = {}
for i = 1, 3 do
    overlay.bars[i] = makeRect(OX + 2, rowY[i], BAR_W, ROW_H - 2, barColours[i], 0.55)
end

-- axis labels
local axisColours = {
    Color3.fromRGB(220, 60,  60),
    Color3.fromRGB(80,  200, 80),
    Color3.fromRGB(80,  120, 220),
}
local axisNames = { "X", "Y", "Z" }
overlay.labels = {}
overlay.values = {}

for i = 1, 3 do
    overlay.labels[i] = makeText(LABEL_X, rowY[i] + 3, axisNames[i], axisColours[i], 13)
    overlay.values[i] = makeText(VALUE_X + 4, rowY[i] + 3, "0", Color3.fromRGB(210, 210, 220), 13)
end

-- vertical separator between label and value (the | line in the screenshot)
overlay.seps = {}
for i = 1, 3 do
    overlay.seps[i] = makeRect(VALUE_X + 1, rowY[i], 1, ROW_H - 2, Color3.fromRGB(80, 80, 100), 1)
end

-- update logic
local function isAnyFeatureActive()
    return (Toggles.SpamToggle    and Toggles.SpamToggle.Value)
        or (Toggles.OrbitToggle   and Toggles.OrbitToggle.Value)
        or (Toggles.AntiTranslocToggle and Toggles.AntiTranslocToggle.Value)
        or (Toggles.SlingToggle   and Toggles.SlingToggle.Value)
        or (Toggles.AaToggle      and Toggles.AaToggle.Value)
end

local IDLE_VAL   = "0"
local ACTIVE_VAL = "999998"

local overlayConn = RunService.Heartbeat:Connect(function()
    if isAnyFeatureActive() then
        local hrp = getHRP()
        if hrp then
            -- show real coords while active so it looks alive
            local p = hrp.Position
            overlay.values[1].Text = string.format("%.1f", math.clamp(p.X, -999998, 999998))
            overlay.values[2].Text = string.format("%.1f", math.clamp(p.Y, -999998, 999998))
            overlay.values[3].Text = string.format("%.1f", math.clamp(p.Z, -999998, 999998))
        else
            overlay.values[1].Text = ACTIVE_VAL
            overlay.values[2].Text = ACTIVE_VAL
            overlay.values[3].Text = ACTIVE_VAL
        end
    else
        overlay.values[1].Text = IDLE_VAL
        overlay.values[2].Text = IDLE_VAL
        overlay.values[3].Text = IDLE_VAL
    end
end)

local function destroyOverlay()
    if overlayConn then overlayConn:Disconnect(); overlayConn = nil end
    overlay.bg:Remove()
    overlay.dot:Remove(); overlay.header:Remove()
    for i = 1, 3 do
        overlay.bars[i]:Remove()
        overlay.labels[i]:Remove()
        overlay.values[i]:Remove()
        overlay.seps[i]:Remove()
    end
end

-- ─────────────────────────────────────────────
-- Unload
-- ─────────────────────────────────────────────
Library:OnUnload(function()
    stopSpam(); stopOrbit(); stopAntiAim(); stopSling(); stopAntiTransloc()
    -- clean up meowlua-port connections
    if getgenv().stop_orbit          then pcall(getgenv().stop_orbit)          end
    if getgenv().stop_void_hide      then pcall(getgenv().stop_void_hide)      end
    if getgenv().disable_voidspam_type then pcall(getgenv().disable_voidspam_type) end
    for k in pairs(conns) do killConn(k) end
    destroyOverlay()
end)

SaveManager:LoadAutoloadConfig()