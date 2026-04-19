-- 🗺️ MinimapAutoZoom: Automatically zooms out the minimap after a configurable delay.

local _addonName = ...

local _frame = CreateFrame("Frame")

local _defaults = { delay = 7, combat = true }

local _category
local _zoomTimer
local _pendingZoomOut = false
local _zoneChangeTimer

local function OnZoneChanged()
	if _zoneChangeTimer then
		_zoneChangeTimer:Cancel()
	end
	_zoneChangeTimer = C_Timer.NewTimer(0.5, function()
		_zoneChangeTimer = nil
		OnMinimapZoomChanged()
	end)
end

local function ZoomOutToMax()
	_zoomTimer = nil
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then
		_pendingZoomOut = true
		return
	end
	_pendingZoomOut = false
	Minimap:SetZoom(0)
end

local function StartZoomTimer()
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then
		_pendingZoomOut = true
		return
	end
	if _zoomTimer then
		_zoomTimer:Cancel()
		_zoomTimer = nil
	end
	_zoomTimer = C_Timer.NewTimer(MinimapAutoZoomDB.delay, function()
		ZoomOutToMax()
	end)
end

function OnMinimapZoomChanged()
	if Minimap:GetZoom() > 0 then
		StartZoomTimer()
	else
		if _zoomTimer then
			_zoomTimer:Cancel()
			_zoomTimer = nil
		end
		_pendingZoomOut = false
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
	_category = Settings.RegisterVerticalLayoutCategory(_addonName)

	local delaySetting = Settings.RegisterAddOnSetting(_category,
		"MAZ_Delay", "delay", MinimapAutoZoomDB, Settings.VarType.Number, "Zoom-Out Delay", _defaults.delay)
	local delayOptions = Settings.CreateSliderOptions(0.1, 30, 0.1)
	delayOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return string.format("%.1f sec", value) end)
	Settings.CreateSlider(_category, delaySetting, delayOptions, "How long after zooming in before the minimap resets.")

	local combatSetting = Settings.RegisterAddOnSetting(_category,
		"MAZ_Combat", "combat", MinimapAutoZoomDB, Settings.VarType.Boolean, "Allow in Combat", _defaults.combat)
	Settings.CreateCheckbox(_category, combatSetting, "Zoom out automatically while in combat.")

	Settings.RegisterAddOnCategory(_category)
end

_frame:RegisterEvent("ADDON_LOADED")
_frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= _addonName then return end

		MinimapAutoZoomDB = MinimapAutoZoomDB or {}
		for key, value in pairs(_defaults) do
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
			if _zoomTimer then
				_zoomTimer:Cancel()
				_zoomTimer = nil
			end
			if Minimap:GetZoom() > 0 then
				_pendingZoomOut = true
			end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if _pendingZoomOut or Minimap:GetZoom() > 0 then
			_pendingZoomOut = false
			StartZoomTimer()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(1, function()
			_pendingZoomOut = false
			OnMinimapZoomChanged()
		end)
	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
		OnZoneChanged()
	end
end)

function MAZ_Settings()
	if not InCombatLockdown() and _category then
		Settings.OpenToCategory(_category:GetID())
	end
end

SLASH_MAZ1 = "/maz"
SLASH_MAZ2 = "/minimapautozoom"
SlashCmdList["MAZ"] = MAZ_Settings
