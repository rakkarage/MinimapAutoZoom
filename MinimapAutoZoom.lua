-- MinimapAutoZoom
-- Automatically zooms the minimap back out after a configurable delay.
-- Handles combat transitions, zone changes, and loading screens robustly.

--#region Setup
MAZ = CreateFrame("Frame")
MAZ.name = ...
MAZ.defaults = { delay = 10, combat = true }
MAZ.zoomTimer = nil
MAZ.pendingZoomOut = false -- true if zoom-out was blocked (e.g. in combat)

function MAZ:OnEvent(event, ...)
	if self[event] then self[event](self, event, ...) end
end

MAZ:SetScript("OnEvent", MAZ.OnEvent)
MAZ:RegisterEvent("ADDON_LOADED")

function MAZ:ADDON_LOADED(event, name)
	if name ~= MAZ.name then return end

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

	C_Timer.After(1, function() MAZ:OnMinimapZoomChanged() end)
	self:UnregisterEvent(event)
end

--#endregion

--#region Events
function MAZ:PLAYER_REGEN_DISABLED()
	if not MinimapAutoZoomDB.combat then
		if self.zoomTimer then
			self.zoomTimer:Cancel()
			self.zoomTimer = nil
		end
		if Minimap:GetZoom() > 0 then
			self.pendingZoomOut = true
		end
	end
end

function MAZ:PLAYER_REGEN_ENABLED()
	if self.pendingZoomOut or Minimap:GetZoom() > 0 then
		self.pendingZoomOut = false
		self:StartZoomTimer()
	end
end

function MAZ:PLAYER_ENTERING_WORLD()
	C_Timer.After(1, function()
		MAZ.pendingZoomOut = false
		MAZ:OnMinimapZoomChanged()
	end)
end

function MAZ:ZONE_CHANGED_NEW_AREA()
	C_Timer.After(0.5, function() MAZ:OnMinimapZoomChanged() end)
end

function MAZ:ZONE_CHANGED()
	C_Timer.After(0.5, function() MAZ:OnMinimapZoomChanged() end)
end

--#endregion

--#region Zoom Logic
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
		MAZ:OnMinimapZoomChanged()
	end)
	Minimap:HookScript("OnMouseWheel", function(_, delta)
		C_Timer.After(0.1, function() MAZ:OnMinimapZoomChanged() end)
	end)
end

--#endregion

--#region Settings Panel
function MAZ:InitializeOptions()
	local category = Settings.RegisterVerticalLayoutCategory(MAZ.name)
	MAZ.category = category

	local delaySetting = Settings.RegisterAddOnSetting(category,
		"MAZ_Delay", "delay", MinimapAutoZoomDB, Settings.VarType.Number, "Zoom-Out Delay", MAZ.defaults.delay)
	local delayOptions = Settings.CreateSliderOptions(0.1, 30, 0.1)
	delayOptions:SetLabelFormatter(
		MinimalSliderWithSteppersMixin.Label.Right,
		function(value) return string.format("%.1f sec", value) end
	)
	Settings.CreateSlider(category, delaySetting, delayOptions, "How long after zooming in before the minimap resets.")

	local combatSetting = Settings.RegisterAddOnSetting(category,
		"MAZ_Combat", "combat", MinimapAutoZoomDB, Settings.VarType.Boolean, "Allow in Combat", MAZ.defaults.combat)
	Settings.CreateCheckbox(category, combatSetting, "Zoom out automatically while in combat.")

	Settings.RegisterAddOnCategory(category)
end

function MAZ_Settings()
	if not InCombatLockdown() then Settings.OpenToCategory(MAZ.category:GetID()) end
end

SLASH_MAZ1 = "/maz"
SLASH_MAZ2 = "/minimapautozoom"
SlashCmdList["MAZ"] = MAZ_Settings
--#endregion
