-- MinimapAutoZoom: Automatically zooms out the minimap after a configurable delay

local addonName = "MinimapAutoZoom"
local MAZ = CreateFrame("Frame")
local zoomTimer = nil
local defaultDelay = 3 -- seconds

-- Saved variables (will persist between sessions)
MinimapAutoZoomDB = MinimapAutoZoomDB or {
    enabled = true,
    delay = defaultDelay
}

-- Function to zoom out to maximum
local function ZoomOutToMax()
    Minimap:SetZoom(0) -- 0 is maximum zoom out in WoW
    zoomTimer = nil
end

-- Function to start/reset the zoom-out timer
local function StartZoomTimer()
    if not MinimapAutoZoomDB.enabled then return end
    
    -- Cancel existing timer if it exists
    if zoomTimer then
        zoomTimer:Cancel()
    end
    
    -- Create new timer
    zoomTimer = C_Timer.NewTimer(MinimapAutoZoomDB.delay, ZoomOutToMax)
end

-- Hook into minimap zoom changes
local function OnMinimapZoomChanged()
    local currentZoom = Minimap:GetZoom()
    
    -- Only start timer if we're zoomed in (not at max zoom out)
    if currentZoom > 0 then
        StartZoomTimer()
    else
        -- If already at max zoom out, cancel any pending timer
        if zoomTimer then
            zoomTimer:Cancel()
            zoomTimer = nil
        end
    end
end

-- Hook the minimap's zoom in/out functions
hooksecurefunc(Minimap, "SetZoom", OnMinimapZoomChanged)

-- Also hook mouse wheel zoom
Minimap:HookScript("OnMouseWheel", function(self, delta)
    -- Small delay to let the zoom change register
    C_Timer.After(0.1, OnMinimapZoomChanged)
end)

-- Slash commands
SLASH_MINIMAPAUTOZOOM1 = "/maz"
SLASH_MINIMAPAUTOZOOM2 = "/minimapautoZoom"

SlashCmdList["MINIMAPAUTOZOOM"] = function(msg)
    msg = string.lower(msg)
    
    if msg == "on" or msg == "enable" then
        MinimapAutoZoomDB.enabled = true
        print("|cff00ff00MinimapAutoZoom:|r Enabled")
        
    elseif msg == "off" or msg == "disable" then
        MinimapAutoZoomDB.enabled = false
        if zoomTimer then
            zoomTimer:Cancel()
            zoomTimer = nil
        end
        print("|cffff0000MinimapAutoZoom:|r Disabled")
        
    elseif msg == "status" then
        print("|cff00ff00MinimapAutoZoom:|r " .. (MinimapAutoZoomDB.enabled and "Enabled" or "Disabled"))
        print("Delay: " .. MinimapAutoZoomDB.delay .. " seconds")
        
    elseif msg:match("^delay%s+(%d+%.?%d*)$") then
        local delay = tonumber(msg:match("^delay%s+(%d+%.?%d*)$"))
        if delay and delay > 0 and delay <= 30 then
            MinimapAutoZoomDB.delay = delay
            print("|cff00ff00MinimapAutoZoom:|r Delay set to " .. delay .. " seconds")
        else
            print("|cffff0000MinimapAutoZoom:|r Please enter a delay between 0.1 and 30 seconds")
        end
        
    else
        print("|cff00ff00MinimapAutoZoom Commands:|r")
        print("/maz on|off - Enable/disable auto zoom-out")
        print("/maz delay <seconds> - Set delay (0.1-30 seconds)")
        print("/maz status - Show current settings")
    end
end

-- Initialization message
MAZ:RegisterEvent("PLAYER_LOGIN")
MAZ:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        print("|cff00ff00MinimapAutoZoom|r loaded! Type /maz for commands")
        print("Current delay: " .. MinimapAutoZoomDB.delay .. " seconds")
    end
end)
