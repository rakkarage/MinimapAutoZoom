-- 🗺️ MinimapAutoZoom: Automatically zooms out the minimap after a configurable delay.

local addonName, ns = ...

ns.MAZ = CreateFrame("Frame")
local MAZ = ns.MAZ
MAZ.name = addonName

MAZ.defaults = { delay = 7, combat = true }
MAZ.zoomTimer = nil
MAZ.pendingZoomOut = false
MAZ.zoneChangeTimer = nil

function MAZ:OnZoneChanged()
	if self.zoneChangeTimer then
		self.zoneChangeTimer:Cancel()
	end
	self.zoneChangeTimer = C_Timer.NewTimer(0.5, function()
		self.zoneChangeTimer = nil
		self:OnMinimapZoomChanged()
	end)
end

function MAZ:ZoomOutToMax()
	self.zoomTimer = nil
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then
		self.pendingZoomOut = true
		return
	end
	self.pendingZoomOut = false
	Minimap:SetZoom(0)
end

function MAZ:StartZoomTimer()
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then
		self.pendingZoomOut = true
		return
	end
	if self.zoomTimer then
		self.zoomTimer:Cancel()
		self.zoomTimer = nil
	end
	self.zoomTimer = C_Timer.NewTimer(MinimapAutoZoomDB.delay, function()
		MAZ:ZoomOutToMax()
	end)
end

function MAZ:OnMinimapZoomChanged()
	if Minimap:GetZoom() > 0 then
		self:StartZoomTimer()
	else
		if self.zoomTimer then
			self.zoomTimer:Cancel()
			self.zoomTimer = nil
		end
		self.pendingZoomOut = false
	end
end

function MAZ:InitializeZoomHooks()
	hooksecurefunc(Minimap, "SetZoom", function()
		self:OnMinimapZoomChanged()
	end)
	Minimap:HookScript("OnMouseWheel", function()
		C_Timer.After(0.1, function() self:OnMinimapZoomChanged() end)
	end)
end

MAZ:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= self.name then return end

		MinimapAutoZoomDB = MinimapAutoZoomDB or {}
		for key, value in pairs(self.defaults) do
			if MinimapAutoZoomDB[key] == nil then
				MinimapAutoZoomDB[key] = value
			end
		end

		self:InitializeOptions()
		self:InitializeZoomHooks()
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		self:RegisterEvent("ZONE_CHANGED")
		self:UnregisterEvent(event)
	elseif event == "PLAYER_REGEN_DISABLED" then
		if not MinimapAutoZoomDB.combat then
			if self.zoomTimer then
				self.zoomTimer:Cancel()
				self.zoomTimer = nil
			end
			if Minimap:GetZoom() > 0 then
				self.pendingZoomOut = true
			end
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if self.pendingZoomOut or Minimap:GetZoom() > 0 then
			self.pendingZoomOut = false
			self:StartZoomTimer()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		C_Timer.After(1, function()
			self.pendingZoomOut = false
			self:OnMinimapZoomChanged()
		end)
	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
		self:OnZoneChanged()
	end
end)
MAZ:RegisterEvent("ADDON_LOADED")

function MAZ:InitializeOptions()
	local category = Settings.RegisterVerticalLayoutCategory(self.name)
	self.category = category

	local delaySetting = Settings.RegisterAddOnSetting(category,
		"MAZ_Delay", "delay", MinimapAutoZoomDB, Settings.VarType.Number, "Zoom-Out Delay", self.defaults.delay)
	local delayOptions = Settings.CreateSliderOptions(0.1, 30, 0.1)
	delayOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return string.format("%.1f sec", value) end)
	Settings.CreateSlider(category, delaySetting, delayOptions, "How long after zooming in before the minimap resets.")

	local combatSetting = Settings.RegisterAddOnSetting(category,
		"MAZ_Combat", "combat", MinimapAutoZoomDB, Settings.VarType.Boolean, "Allow in Combat", self.defaults.combat)
	Settings.CreateCheckbox(category, combatSetting, "Zoom out automatically while in combat.")

	Settings.RegisterAddOnCategory(category)
end

function MAZ_Settings()
	if not InCombatLockdown() then
		Settings.OpenToCategory(MAZ.category:GetID())
	end
end

SLASH_MAZ1 = "/maz"
SLASH_MAZ2 = "/minimapautozoom"
SlashCmdList["MAZ"] = MAZ_Settings
