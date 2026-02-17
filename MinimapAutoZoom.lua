MAZ = CreateFrame("Frame")
MAZ.name = "MinimapAutoZoom"
MAZ.defaults = { delay = 3, combat = true }
MAZ.zoomTimer = nil

function MAZ:OnEvent(event, ...)
	self[event](self, event, ...)
end

MAZ:SetScript("OnEvent", MAZ.OnEvent)
MAZ:RegisterEvent("ADDON_LOADED")

function MAZ:ADDON_LOADED(event, name)
	if name == MAZ.name then
		MinimapAutoZoomDB = MinimapAutoZoomDB or {}
		for key, value in pairs(self.defaults) do
			if MinimapAutoZoomDB[key] == nil then
				MinimapAutoZoomDB[key] = value
			end
		end
		self:InitializeOptions()
		self:InitializeZoomHooks()

		C_Timer.After(1, function()
			MAZ:OnMinimapZoomChanged()
		end)

		self:UnregisterEvent(event)
	end
end

function MAZ:ZoomOutToMax()
	Minimap:SetZoom(0)
	self.zoomTimer = nil
end

function MAZ:StartZoomTimer()
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then return end

	if self.zoomTimer then
		self.zoomTimer:Cancel()
	end

	self.zoomTimer = C_Timer.NewTimer(MinimapAutoZoomDB.delay, function()
		MAZ:ZoomOutToMax()
	end)
end

function MAZ:OnMinimapZoomChanged()
	if not MinimapAutoZoomDB.combat and InCombatLockdown() then return end

	local currentZoom = Minimap:GetZoom()

	if currentZoom > 0 then
		self:StartZoomTimer()
	else
		if self.zoomTimer then
			self.zoomTimer:Cancel()
			self.zoomTimer = nil
		end
	end
end

function MAZ:InitializeZoomHooks()
	hooksecurefunc(Minimap, "SetZoom", function()
		MAZ:OnMinimapZoomChanged()
	end)

	Minimap:HookScript("OnMouseWheel", function(self, delta)
		C_Timer.After(0.1, function()
			MAZ:OnMinimapZoomChanged()
		end)
	end)
end

SLASH_MAZ1 = "/maz"
SLASH_MAZ2 = "/minimapautozoom"
SlashCmdList["MAZ"] = MAZ_Settings()

function MinimapAutoZoom_AddonCompartmentClick(addonName, buttonName, menuButtonFrame)
	if addonName == "MinimapAutoZoom" then
		MAZ_Settings()
	end
end

function MAZ_Settings()
	if not InCombatLockdown() then
		Settings.OpenToCategory(MAZ.category:GetID())
	end
end

function MAZ:InitializeOptions()
	local category, layout = Settings.RegisterVerticalLayoutCategory(MAZ.name)
	MAZ.category = category
	Settings.RegisterAddOnCategory(category)

	local sliderOptions = Settings.CreateSliderOptions(0.1, 30, 0.1)
	sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return string.format("%.1f sec", value)
	end)

	Settings.CreateSlider(category,
		Settings.RegisterAddOnSetting(category, "MAZ_Delay", "delay", MinimapAutoZoomDB, Settings.VarType.Number,
			"Auto Zoom-Out Delay", MAZ.defaults.delay),
		sliderOptions, "Delay before automatically zooming out minimap")

	Settings.CreateCheckbox(category,
	Settings.RegisterAddOnSetting(category, "MAZ_Combat", "combat", MinimapAutoZoomDB, Settings.VarType.Boolean,
			"Active in combat", MAZ.defaults.combat),
		"Allow auto zoom-out during combat")
end
