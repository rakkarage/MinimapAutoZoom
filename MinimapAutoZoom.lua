-- 🗺️ MinimapAutoZoom: Automatically zooms out the minimap after a configurable delay.

local addonName = ...

local frame = CreateFrame("Frame")

local defaults = { delay = 7, combat = true }

local category
local zoomTimer = nil
local pendingZoomOut = false
local zoneChangeTimer = nil

local function OnZoneChanged()
	if zoneChangeTimer then
		zoneChangeTimer:Cancel()
	end
	zoneChangeTimer = C_Timer.NewTimer(0.5, function()
		zoneChangeTimer = nil
		OnMinimapZoomChanged()
	end)
end

local function ZoomOutToMax()
	zoomTimer = nil
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then
		pendingZoomOut = true
		return
	end
	pendingZoomOut = false
	Minimap:SetZoom(0)
end

local function StartZoomTimer()
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then
		pendingZoomOut = true
		return
	end
	if zoomTimer then
		zoomTimer:Cancel()
		zoomTimer = nil
	end
	zoomTimer = C_Timer.NewTimer(MinimapAutoZoomDB.delay, function()
		ZoomOutToMax()
	end)
end

function OnMinimapZoomChanged()
	if Minimap:GetZoom() > 0 then
		StartZoomTimer()
	else
		if zoomTimer then
			zoomTimer:Cancel()
			zoomTimer = nil
		end
		pendingZoomOut = false
	end
end

local function InitializeZoomHooks()
	hooksecurefunc(Minimap, "SetZoom", function()
		OnMinimapZoomChanged()
	end)
	Minimap:HookScript("OnMouseWheel", function()
		C_Timer.After(0.1, function() OnMinimapZoomChanged() end)
	end)
end

local function InitializeOptions()
	category = Settings.RegisterVerticalLayoutCategory(addonName)

	local delaySetting = Settings.RegisterAddOnSetting(category,
		"MAZ_Delay", "delay", MinimapAutoZoomDB, Settings.VarType.Number, "Zoom-Out Delay", defaults.delay)
	local delayOptions = Settings.CreateSliderOptions(0.1, 30, 0.1)
	delayOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return string.format("%.1f sec", value) end)
	Settings.CreateSlider(category, delaySetting, delayOptions, "How long after zooming in before the minimap resets.")

	local combatSetting = Settings.RegisterAddOnSetting(category,
		"MAZ_Combat", "combat", MinimapAutoZoomDB, Settings.VarType.Boolean, "Allow in Combat", defaults.combat)
	Settings.CreateCheckbox(category, combatSetting, "Zoom out automatically while in combat.")

	Settings.RegisterAddOnCategory(category)
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName then return end

		MinimapAutoZoomDB = MinimapAutoZoomDB or {}
		for key, value in pairs(defaults) do
			if MinimapAutoZoomDB[key] == nil then
				MinimapAutoZoomDB[key] = value
			end
		end

		InitializeOptions()
		InitializeZoomHooks()
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		self:RegisterEvent("ZONE_CHANGED")
		self:UnregisterEvent(event)
	elseif event == "PLAYER_REGEN_DISABLED" then
		if not MinimapAutoZoomDB.combat then
			if zoomTimer then
				zoomTimer:Cancel()
				zoomTimer = nil
			end
			if Minimap:GetZoom() > 0 then
				pendingZoomOut = true
			end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingZoomOut or Minimap:GetZoom() > 0 then
			pendingZoomOut = false
			StartZoomTimer()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(1, function()
			pendingZoomOut = false
			OnMinimapZoomChanged()
		end)
	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
		OnZoneChanged()
	end
end)

function MAZ_Settings()
	if not InCombatLockdown() and category then
		Settings.OpenToCategory(category:GetID())
	end
end

SLASH_MAZ1 = "/maz"
SLASH_MAZ2 = "/minimapautozoom"
SlashCmdList["MAZ"] = MAZ_Settings
