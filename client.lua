local fov = Config.MaxFov
local heliCam, camActive = nil, false
local modeIndex, trackedVehicle = 0, nil

--Notification
local function Notify(msg)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(msg)
    DrawNotification(false, false)
end

--Helpers
local function RotAnglesToVec(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local cx, sx = math.cos(x), math.sin(x)
    local cz, sz = math.cos(z), math.sin(z)
    return vector3(-cx * sz, cx * cz, sx)
end

local function IsAllowedModel(model)
    local name = tostring(GetDisplayNameFromVehicleModel(model)):lower()
    for _, allowed in ipairs(Config.AllowedModels) do
        if allowed:lower() == name then return true end
    end
    return false
end

local function GetScreenDistanceFromCenter(entity)
    local pos = GetEntityCoords(entity)
    local onScreen, sx, sy = World3dToScreen2d(pos.x, pos.y, pos.z)
    if not onScreen then return 9999 end
    local dx, dy = sx - 0.5, sy - 0.5
    return math.sqrt(dx * dx + dy * dy)
end

local function DetectVehicleUnderCrosshair(cam)
    local camPos = GetCamCoord(cam)
    local camDir = RotAnglesToVec(GetCamRot(cam, 2))
    local vehicles = GetGamePool("CVehicle")
    local bestVeh, bestDist = nil, 99999

    for _, veh in ipairs(vehicles) do
        if DoesEntityExist(veh) then
            local vehPos = GetEntityCoords(veh)
            local toVeh = vehPos - camPos
            local dist = #(toVeh)
            if dist < Config.MaxRange then
                local dirToVeh = toVeh / dist
                local dot = camDir.x * dirToVeh.x + camDir.y * dirToVeh.y + camDir.z * dirToVeh.z
                if dot > 0.985 then
                    local screenDist = GetScreenDistanceFromCenter(veh)
                    if screenDist < Config.AimScreenThreshold and dist < bestDist then
                        bestVeh, bestDist = veh, dist
                    end
                end
            end
        end
    end
    return bestVeh
end

local function DrawCrosshair()
    DrawRect(0.5, 0.5, 0.002, 0.002, Config.CrosshairColor[1], Config.CrosshairColor[2], Config.CrosshairColor[3], Config.CrosshairColor[4])
end

local function GetStreetName(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(s1)
    local cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or nil
    return cross and (street .. " & " .. cross) or street
end

local function GetNearestPostal(coords)
    if GetResourceState(Config.PostalResource) == "started" and exports[Config.PostalResource] and exports[Config.PostalResource].getPostal then
        return exports[Config.PostalResource]:getPostal(coords) or "N/A"
    end
    return "N/A"
end

local function DrawTextHUD(plate, speed, zoom, mode, tracking)
    local modeLabel = ({"NORMAL", "NIGHT VISION", "FLIR"})[mode + 1] or "NORMAL"
    local status = tracking and "LOCKED" or "FREE"
    local x, y = Config.HUDPosition.x, Config.HUDPosition.y
    DrawRect(x, y + 0.015, 0.45, 0.06, 0, 0, 0, 160)
    SetTextFont(4)
    SetTextScale(Config.DrawScale, Config.DrawScale)
    SetTextCentre(true)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(("Plate: %s | Speed: %s mph | Zoom: x%.1f | %s | %s"):format(
        plate or "N/A", speed or "0", (Config.MaxFov / zoom), modeLabel, status
    ))
    DrawText(x, y)
end

local function ApplyVisionMode()
    SetNightvision(false)
    SetSeethrough(false)
    if modeIndex == 1 then
        SetNightvision(true)
        Notify("~g~Night Vision Enabled")
    elseif modeIndex == 2 then
        SetSeethrough(true)
        Notify("~g~FLIR Enabled")
    else
        Notify("~y~Normal Vision")
    end
end

--Activate / Deactivate
local function EnableHeliCam(vehicle)
    if heliCam and DoesCamExist(heliCam) then DestroyCam(heliCam, false) end
    local coords = GetOffsetFromEntityInWorldCoords(vehicle, Config.CameraOffset.x, Config.CameraOffset.y, Config.CameraOffset.z)
    heliCam = CreateCam("DEFAULT_SCRIPTED_FLY_CAMERA", true)
    SetCamCoord(heliCam, coords.x, coords.y, coords.z)
    SetCamRot(heliCam, 0.0, 0.0, GetEntityHeading(vehicle))
    SetCamFov(heliCam, fov)
    AttachCamToEntity(heliCam, vehicle, Config.CameraOffset.x, Config.CameraOffset.y, Config.CameraOffset.z, true)
    RenderScriptCams(true, false, 0, true, true)
    camActive, trackedVehicle, modeIndex = true, nil, 0
    ApplyVisionMode()
    Notify("~g~HeliCam Activated | G=Capture | N=Mode | E=Track")
end

local function DisableHeliCam()
    if heliCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(heliCam, false)
        heliCam = nil
    end
    SetNightvision(false)
    SetSeethrough(false)
    trackedVehicle = nil
    camActive = false
    Notify("~r~HeliCam Deactivated")
end

local function DisableHeliInputs()
    local groups = {0, 1, 2}
    local controls = {
        12,13,14,15,16,17,24,25,37,44,45,
        80,81,82,83,84,85,86,99,100,
        157,158,159,160,161,162,163,164
    }
    for _, group in ipairs(groups) do
        for _, control in ipairs(controls) do
            DisableControlAction(group, control, true)
        end
    end
    DisablePlayerFiring(PlayerPedId(), true)
end

local function HandleZoom()
    DisableHeliInputs()
    if IsControlJustPressed(0, 241) then
        fov = math.max(fov - Config.ZoomSpeed, Config.MinFov)
        SetCamFov(heliCam, fov)
    elseif IsControlJustPressed(0, 242) then
        fov = math.min(fov + Config.ZoomSpeed, Config.MaxFov)
        SetCamFov(heliCam, fov)
    end
end

local function OnCapture(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle) or "UNKNOWN"
    local speed = math.floor(GetEntitySpeed(vehicle) * 2.236936)
    local model = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    local coords = GetEntityCoords(vehicle)
    local street = GetStreetName(coords)
    local postal = GetNearestPostal(coords)
    Notify(("Captured: %s | %s mph | %s"):format(plate, speed, street))
    TriggerServerEvent("ne_helicam:capture", plate, speed, model, street, postal)
end

--Key Bindings
RegisterCommand(Config.ToggleKey, function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh == 0 or not IsPedInAnyHeli(ped) then
        return Notify("~r~Must be in a helicopter.")
    end

    local seat = -2
    for i = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
        if GetPedInVehicleSeat(veh, i) == ped then
            seat = i
            break
        end
    end

    if seat ~= 0 then
        return Notify("~r~You must be in the copilot seat to use the HeliCam.")
    end

    if not IsAllowedModel(GetEntityModel(veh)) then
        return Notify("~r~This helicopter has no camera system.")
    end

    if camActive then
        DisableHeliCam()
    else
        EnableHeliCam(veh)
    end
end)
RegisterKeyMapping(Config.ToggleKey, "Toggle HeliCam", "keyboard", "H")

RegisterCommand(Config.CaptureKey, function()
    if not camActive or not heliCam then return end
    local veh = trackedVehicle or DetectVehicleUnderCrosshair(heliCam)
    if veh then OnCapture(veh) else Notify("~r~No vehicle detected.") end
end)
RegisterKeyMapping(Config.CaptureKey, "Capture Vehicle", "keyboard", "G")

RegisterCommand(Config.ModeKey, function()
    if not camActive then return end
    modeIndex = (modeIndex + 1) % 3
    ApplyVisionMode()
end)
RegisterKeyMapping(Config.ModeKey, "Cycle Vision Mode", "keyboard", "N")

RegisterCommand(Config.TrackKey, function()
    if not camActive or not heliCam then return end
    if trackedVehicle then
        trackedVehicle = nil
        StopCamPointing(heliCam)
        Notify("~r~Tracking released.")
        return
    end
    local veh = DetectVehicleUnderCrosshair(heliCam)
    if veh then
        trackedVehicle = veh
        Notify("~g~Target locked.")
    else
        Notify("~r~No vehicle detected.")
    end
end)
RegisterKeyMapping(Config.TrackKey, "Lock/Unlock Target", "keyboard", "E")

--Main loop
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
                HandleZoom()
                DrawCrosshair()
                local plate, speed = "N/A", 0
                if trackedVehicle and DoesEntityExist(trackedVehicle) then
                    PointCamAtEntity(heliCam, trackedVehicle, 0.0, 0.0, 0.0, true)
                    plate = GetVehicleNumberPlateText(trackedVehicle)
                    speed = math.floor(GetEntitySpeed(trackedVehicle) * 2.236936)
                else
                    local veh = DetectVehicleUnderCrosshair(heliCam)
                    if veh then
                        plate = GetVehicleNumberPlateText(veh)
                        speed = math.floor(GetEntitySpeed(veh) * 2.236936)
                    end
                    local rightX = GetControlNormal(0, 220)
                    local rightY = GetControlNormal(0, 221)
                    local rot = GetCamRot(heliCam, 2)
                    SetCamRot(heliCam, math.max(math.min(rot.x + rightY * -10.0, 80.0), -80.0), 0.0, rot.z + rightX * -10.0, 2)
                end
                DrawTextHUD(plate, speed, fov, modeIndex, trackedVehicle ~= nil)
                if IsControlJustPressed(0, 200) then DisableHeliCam() end
            end
        else
            Wait(400)
        end
    end
end)
