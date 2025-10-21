local Webhook = Config.WebhookURL

if not Webhook or Webhook == "" then
    print("^1[ne_helicam] Warning: No Discord webhook set in config.lua!^0")
end

RegisterNetEvent("ne_helicam:capture")
AddEventHandler("ne_helicam:capture", function(plate, speed, model, street, postal)
    if not Webhook or Webhook == "" then return end

    local src = source
    local name = GetPlayerName(src)
    local embed = {{
        title = "Helicopter Camera Capture",
        color = 3447003,
        fields = {
            { name = "Officer", value = name or ("ID "..src), inline = true },
            { name = "Plate", value = plate, inline = true },
            { name = "Speed (mph)", value = tostring(speed), inline = true },
            { name = "Model", value = model, inline = true },
            { name = "Street", value = street, inline = false },
            { name = "Postal", value = postal, inline = true }
        },
        footer = { text = "NorthEast Development | HeliCam" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }}

    PerformHttpRequest(Webhook, function() end, "POST",
        json.encode({ embeds = embed }),
        { ["Content-Type"] = "application/json" }
    )
end)
