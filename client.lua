local fov = Config.MaxFov
local heliCam, camActive = nil, false
local modeIndex, trackedEntity = 0, nil

-- Spotlight
local spotlightActive = false
local spotLightHandle = nil
local spotlightIntensity = Config.Spotlight.Intensity
local spotlightRadius = Config.Spotlight.Radius

-- Notifications
local function Notify(msg)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

-- Convert rotation to direction vector
local function RotAnglesToVec(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local cx, sx = math.cos(x), math.sin(x)
    local cz, sz = math.cos(z), math.sin(z)
    return vector3(-cx * sz, cx * cz, sx)
end

-- Verify allowed models
local function IsAllowedModel(model)
    local name = tostring(GetDisplayNameFromVehicleModel(model)):lower()
    for _, allowed in ipairs(Config.AllowedModels) do
        if allowed:lower() == name then return true end
    end
    return false
end

-- Screen distance from center
local function GetScreenDistanceFromCenter(entity)
    local pos = GetEntityCoords(entity)
    local onScreen, sx, sy = World3dToScreen2d(pos.x, pos.y, pos.z)
    if not onScreen then return 9999 end
    local dx, dy = sx - 0.5, sy - 0.5
    return math.sqrt(dx * dx + dy * dy)
end

-- Detect peds or vehicles under crosshair
local function DetectEntityUnderCrosshair(cam)
    local camPos = GetCamCoord(cam)
    local camDir = RotAnglesToVec(GetCamRot(cam, 2))
    local bestEntity, bestDist = nil, 99999
    local entities = {}

    for _, veh in ipairs(GetGamePool("CVehicle")) do table.insert(entities, veh) end
    for _, ped in ipairs(GetGamePool("CPed")) do
        if ped ~= PlayerPedId() then table.insert(entities, ped) end
    end

    for _, ent in ipairs(entities) do
        if DoesEntityExist(ent) then
            local entPos = GetEntityCoords(ent)
            local toEnt = entPos - camPos
            local dist = #(toEnt)
            if dist < Config.MaxRange then
                local dirToEnt = toEnt / dist
                local dot = camDir.x * dirToEnt.x + camDir.y * dirToEnt.y + camDir.z * dirToEnt.z
                if dot > 0.985 then
                    local screenDist = GetScreenDistanceFromCenter(ent)
                    if screenDist < Config.AimScreenThreshold and dist < bestDist then
                        bestEntity, bestDist = ent, dist
                    end
                end
            end
        end
    end
    return bestEntity
end

-- Crosshair
local function DrawCrosshair()
    DrawRect(0.5, 0.5, 0.002, 0.002,
        Config.CrosshairColor[1],
        Config.CrosshairColor[2],
        Config.CrosshairColor[3],
        Config.CrosshairColor[4])
end

-- Street & postal helpers
local function GetStreetName(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(s1)
    local cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or nil
    return cross and (street .. " & " .. cross) or street
end

local function GetNearestPostal(coords)
    if GetResourceState(Config.PostalResource) == "started"
    and exports[Config.PostalResource]
    and exports[Config.PostalResource].getPostal then
        return exports[Config.PostalResource]:getPostal(coords) or "N/A"
    end
    return "N/A"
end

--HUD
local function DrawTextHUD(plate, speed, zoom, mode, tracking)
    local modeLabel = ({"NORMAL", "NIGHT", "FLIR"})[mode + 1] or "NORMAL"
    local status = tracking and "~g~LOCKED" or "~r~FREE"
    local spotlightStatus = spotlightActive and "~g~ON" or "~w~OFF"
    local x, y = 0.83, 0.865

    SetTextFont(4)
    SetTextScale(0.36, 0.36)
    SetTextRightJustify(true)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(string.format(
        "~w~Plate: %s\n~w~Speed: %s mph\n~w~Zoom: x%.1f\n~w~%s | %s\n~w~Spotlight: %s",
        plate or "N/A",
        speed or "0",
        (Config.MaxFov / zoom),
        modeLabel,
        status,
        spotlightStatus
    ))
    DrawText(x + 0.16, y - 0.01)
end


-- Vision modes
local function ApplyVisionMode()
    SetNightvision(false)
    SetSeethrough(false)
    if modeIndex == 1 then
        SetNightvision(true)
    elseif modeIndex == 2 then
        SetSeethrough(true)
    end
end

-- Spotlight logic
local function ToggleSpotlight()
    spotlightActive = not spotlightActive
    if not spotlightActive then
        if spotLightHandle then
            RemoveNamedPtfxAsset("core")
            spotLightHandle = nil
        end
        Notify("~r~Spotlight Disabled")
    else
        Notify("~g~Spotlight Enabled")
    end
end

local function UpdateSpotlight(cam)
    if not spotlightActive or not cam then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped)
    local height = 0.0

    if DoesEntityExist(vehicle) then
        local vehCoords = GetEntityCoords(vehicle)
        local _, gz = GetGroundZFor_3dCoord(vehCoords.x, vehCoords.y, vehCoords.z, false)
        height = math.max(0.0, vehCoords.z - gz)
    end

    local camPos = GetCamCoord(cam)
    local dir = RotAnglesToVec(GetCamRot(cam, 2))

    local dist = Config.Spotlight.Distance
    if height > 100.0 then
        dist = math.min(height + 200.0, 1200.0)
    end

    DrawSpotLight(
        camPos.x, camPos.y, camPos.z,
        dir.x, dir.y, dir.z,
        Config.Spotlight.Color[1],
        Config.Spotlight.Color[2],
        Config.Spotlight.Color[3],
        dist,
        spotlightIntensity,
        0.0,
        spotlightRadius,
        1.0
    )
end

-- Zoom + Spotlight
local function HandleZoomAndSpotlight()
    DisableHeliInputs()
    if IsControlPressed(0, 21) then -- Left Shift => beam width
        if IsControlJustPressed(0, 241) then
            spotlightRadius = math.min(spotlightRadius + Config.Spotlight.AdjustSpeed, 30.0)
            Notify("~b~Spotlight Beam Wider")
        elseif IsControlJustPressed(0, 242) then
            spotlightRadius = math.max(spotlightRadius - Config.Spotlight.AdjustSpeed, 5.0)
            Notify("~b~Spotlight Beam Narrower")
        end
    elseif IsControlPressed(0, 36) then -- Left Ctrl => brightness
        if IsControlJustPressed(0, 241) then
            spotlightIntensity = math.min(spotlightIntensity + Config.Spotlight.AdjustSpeed, 50.0)
            Notify("~b~Spotlight Brighter")
        elseif IsControlJustPressed(0, 242) then
            spotlightIntensity = math.max(spotlightIntensity - Config.Spotlight.AdjustSpeed, 1.0)
            Notify("~b~Spotlight Dimmer")
        end
    else
        if IsControlJustPressed(0, 241) then
            fov = math.max(fov - Config.ZoomSpeed, Config.MinFov)
            SetCamFov(heliCam, fov)
        elseif IsControlJustPressed(0, 242) then
            fov = math.min(fov + Config.ZoomSpeed, Config.MaxFov)
            SetCamFov(heliCam, fov)
        end
    end
end

-- Enable/disable heli cam
local function EnableHeliCam(vehicle)
    if heliCam and DoesCamExist(heliCam) then DestroyCam(heliCam, false) end
    local coords = GetOffsetFromEntityInWorldCoords(
        vehicle,
        Config.CameraOffset.x,
        Config.CameraOffset.y,
        Config.CameraOffset.z
    )
    heliCam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    SetCamCoord(heliCam, coords.x, coords.y, coords.z)
    SetCamRot(heliCam, 0.0, 0.0, GetEntityHeading(vehicle))
    SetCamFov(heliCam, fov)
    AttachCamToEntity(heliCam, vehicle, Config.CameraOffset.x, Config.CameraOffset.y, Config.CameraOffset.z, true)
    RenderScriptCams(true, false, 0, true, true)
    camActive, trackedEntity, modeIndex = true, nil, 0
    ApplyVisionMode()
    Notify("~g~HeliCam Activated | G=Capture | N=Mode | E=Track | L=Spotlight | Hold Shift/Ctrl+Scroll to Adjust")
end

local function DisableHeliCam()
    if heliCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(heliCam, false)
        heliCam = nil
    end
    SetNightvision(false)
    SetSeethrough(false)
    trackedEntity = nil
    camActive = false
    spotlightActive = false
    Notify("~r~HeliCam Deactivated")
end

-- Disable controls 
local function DisableHeliInputs()
    -- Do NOT disable 220/221 (look), 241/242 (wheel up/down) because we use them for zoom & spotlight
    local toDisable = {
        24, 25,               -- attack / aim
        37,                   -- weapon wheel
        45, 44,               -- reload / cover
        14, 15, 16, 17,       -- next/prev weapon + select/deselect (mouse wheel related)
        80, 99, 100,          -- misc menu/radio interactions
        85, 86, 81, 82, 83,   -- vehicle radio next/prev and radio wheel
        106, 107,             -- vehicle mouse control (drive-by etc.)
        200, 202,             -- pause / cancel
        261, 262, 263, 264    -- first-person phone/camera extra binds (prevent bleed-through)
    }
    for _, c in ipairs(toDisable) do
        DisableControlAction(0, c, true)
    end
    DisablePlayerFiring(PlayerPedId(), true)
end

-- Zoom + Spotlight Adjustments
local function HandleZoomAndSpotlight()
    DisableHeliInputs()
    if IsControlPressed(0, 21) then -- Left Shift => adjust beam width
        if IsControlJustPressed(0, 241) then
            spotlightRadius = math.min(spotlightRadius + Config.Spotlight.AdjustSpeed, 50.0)
            --Notify("~b~Spotlight Beam Wider")
        elseif IsControlJustPressed(0, 242) then
            spotlightRadius = math.max(spotlightRadius - Config.Spotlight.AdjustSpeed, 5.0)
            --Notify("~b~Spotlight Beam Narrower")
        end
    elseif IsControlPressed(0, 36) then -- Left Ctrl => adjust intensity
        if IsControlJustPressed(0, 241) then
            spotlightIntensity = math.min(spotlightIntensity + Config.Spotlight.AdjustSpeed, 50.0)
            --Notify("~b~Spotlight Brighter")
        elseif IsControlJustPressed(0, 242) then
            spotlightIntensity = math.max(spotlightIntensity - Config.Spotlight.AdjustSpeed, 1.0)
            --Notify("~b~Spotlight Dimmer")
        end
    else
        -- Zoom
        if IsControlJustPressed(0, 241) then
            fov = math.max(fov - Config.ZoomSpeed, Config.MinFov)
            SetCamFov(heliCam, fov)
        elseif IsControlJustPressed(0, 242) then
            fov = math.min(fov + Config.ZoomSpeed, Config.MaxFov)
            SetCamFov(heliCam, fov)
        end
    end
end

-- Capture entity
local function OnCapture(entity)
    local plate, speed, model = "N/A", 0, "PLAYER"

    if IsEntityAVehicle(entity) then
        plate = GetVehicleNumberPlateText(entity) or "UNKNOWN"
        speed = math.floor(GetEntitySpeed(entity) * 2.236936)
        model = GetDisplayNameFromVehicleModel(GetEntityModel(entity))
    elseif IsEntityAPed(entity) then
        speed = math.floor(GetEntitySpeed(entity) * 2.236936)
    end

    local coords = GetEntityCoords(entity)
    local street = GetStreetName(coords)
    local postal = GetNearestPostal(coords)
    Notify(("Captured: %s | %s mph | %s"):format(plate, speed, street))
    TriggerServerEvent("ne_helicam:capture", plate, speed, model, street, postal)
end

-- Commands
RegisterCommand(Config.ToggleKey, function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or not IsPedInAnyHeli(ped) then
        return Notify("~r~Must be in a helicopter.")
    end
    local seat = -2
    for i = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
        if GetPedInVehicleSeat(veh, i) == ped then seat = i break end
    end
    if not Config.Testing and seat ~= 0 then
        return Notify("~r~You must be in the copilot seat to use the HeliCam.")
    end

    if not IsAllowedModel(GetEntityModel(veh)) then
        return Notify("~r~This helicopter has no camera system.")
    end

    if camActive then DisableHeliCam() else EnableHeliCam(veh) end
end)
RegisterKeyMapping(Config.ToggleKey, "Toggle HeliCam", "keyboard", "H")

RegisterCommand(Config.CaptureKey, function()
    if not camActive or not heliCam then return end
    local ent = trackedEntity or DetectEntityUnderCrosshair(heliCam)
    if ent then OnCapture(ent) else Notify("~r~No entity detected.") end
end)
RegisterKeyMapping(Config.CaptureKey, "Capture Target", "keyboard", "G")

RegisterCommand(Config.ModeKey, function()
    if not camActive then return end
    modeIndex = (modeIndex + 1) % 3
    ApplyVisionMode()
end)
RegisterKeyMapping(Config.ModeKey, "Cycle Vision Mode", "keyboard", "N")

RegisterCommand(Config.TrackKey, function()
    if not camActive or not heliCam then return end
    if trackedEntity then
        trackedEntity = nil
        StopCamPointing(heliCam)
        return
    end
    local ent = DetectEntityUnderCrosshair(heliCam)
    if ent then
        trackedEntity = ent
    else
        Notify("~r~No entity detected.")
    end
end)
RegisterKeyMapping(Config.TrackKey, "Lock/Unlock Target", "keyboard", "E")

-- Toggle Spotlight
RegisterCommand("spotlight_toggle", function()
    if not camActive then return end
    ToggleSpotlight()
end)
RegisterKeyMapping("spotlight_toggle", "Toggle Spotlight", "keyboard", "L")

-- Main loop
CreateThread(function()
    while true do
        Wait(0)
        if camActive and heliCam then
            DisableHeliInputs()
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if not DoesEntityExist(vehicle) or not IsPedInAnyHeli(ped) then
                DisableHeliCam()
            else
                HandleZoomAndSpotlight()
                DrawCrosshair()
                UpdateSpotlight(heliCam)

                local plate, speed = "N/A", 0
                if trackedEntity and DoesEntityExist(trackedEntity) then
                    PointCamAtEntity(heliCam, trackedEntity, 0.0, 0.0, 0.0, true)
                    if IsEntityAVehicle(trackedEntity) then
                        plate = GetVehicleNumberPlateText(trackedEntity)
                        speed = math.floor(GetEntitySpeed(trackedEntity) * 2.236936)
                    else
                        speed = math.floor(GetEntitySpeed(trackedEntity) * 2.236936)
                    end
                else
                    local rightX = GetControlNormal(0, 220)
                    local rightY = GetControlNormal(0, 221)
                    local rot = GetCamRot(heliCam, 2)
                    local newX = math.max(math.min(rot.x + rightY * -10.0, 80.0), -80.0)
                    local newZ = rot.z + rightX * -10.0
                    SetCamRot(heliCam, newX, 0.0, newZ, 2)
                end

                DrawTextHUD(plate, speed, fov, modeIndex, trackedEntity ~= nil)

                if IsControlJustPressed(0, 200) then
                    DisableHeliCam()
                end
            end
        else
            Wait(400)
        end
    end
end)
