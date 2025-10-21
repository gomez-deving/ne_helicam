Config = {}

--Allowed Helicopter Models
Config.AllowedModels = { "polmav", "frogger", "maverick", "policeheli" }

--Key Bindings
Config.ToggleKey = "toggle_heliplatecam"  -- Toggle HeliCam (default: H)
Config.CaptureKey = "capture_heliplatecam" -- Capture Target (default: G)
Config.ModeKey = "cycle_helicam_mode"      -- Cycle Vision Mode (default: N)
Config.TrackKey = "track_vehicle"          -- Lock/Unlock Target (default: E)

--Camera Settings
Config.MaxRange = 2000.0
Config.MinFov = 10.0
Config.MaxFov = 60.0
Config.ZoomSpeed = 2.0
Config.CameraOffset = vector3(0.0, 0.0, -2.5)

--Crosshair + HUD
Config.CrosshairColor = {255, 255, 255, 200}
Config.DrawScale = 0.45
Config.HUDPosition = { x = 0.50, y = 0.92 }
Config.AimScreenThreshold = 0.03 -- how centered target must be (~3%)

--Postal Integration
Config.PostalResource = "nearest-postal"

--Discord Webhook
Config.WebhookURL = "https://discord.com/api/webhooks/XXXXXXXXX/XXXXXXXXX" -- replace with yours
