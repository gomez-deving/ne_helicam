# 📸 NorthEast Development - Advanced Helicopter Camera System

**A realistic, standalone FLIR and Night Vision camera system for police and tactical helicopters in FiveM.**  
Designed for immersive law enforcement roleplay, this system provides advanced aerial surveillance with full tracking, detection, and Discord integration.

---

## 🚀 Features

- 🎯 **Precision Crosshair Detection** – Detects the exact vehicle under your crosshair, even at long range.  
- 🔭 **Long-Range Vision** – Up to 2000 meters of effective scanning range.  
- 🧭 **HUD Overlay** – Displays speed, plate, zoom level, camera mode, and tracking status at the bottom of the screen.  
- 🌙 **Night Vision & FLIR** – Toggle between Normal, Night Vision, and Thermal FLIR modes.  
- 🎥 **Free Camera System** – Fully mouse/controller-controlled with a centered targeting dot.  
- 🔒 **Target Tracking** – Lock onto a vehicle to automatically follow it while the camera moves.  
- 📡 **Discord Webhook Logging** – Sends captured vehicle data (plate, speed, street, postal) to a Discord channel.  
- 🗺️ **Street & Postal Lookup** – Integrates with `nearest-postal` or any other postal script.  
- 🪶 **Lightweight & Optimized** – Efficient, low-latency client design with virtually zero performance impact.  

---

## 🧠 Controls

| Key | Action |
|-----|--------|
| **H** | Toggle HeliCam on/off |
| **G** | Capture vehicle info |
| **N** | Cycle camera mode *(Normal / Night Vision / FLIR)* |
| **E** | Lock or unlock target tracking |
| **L** | Toggle spotlight on/off |
| **Left Shift + Scroll** | Adjust spotlight beam wider/narrower |
|**Left Ctrl + Scroll** | Adjust spotlight brightness up/down |
| **Mouse Scroll** | Zoom in/out |
| **ESC** | Exit camera view |

---

⚙️ Configuration
```local Config = {
    AllowedModels = { "polmav", "frogger", "maverick", "policeheli" },
    PostalResource = "nearest-postal", -- Postal script name
    MaxRange = 2000.0,
    MinFov = 10.0,
    MaxFov = 60.0,
    ZoomSpeed = 2.0,
    CameraOffset = vector3(0.0, 0.0, -2.5), -- Camera under helicopter
}
