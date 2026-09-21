local addonName, addon = ...

addon.name = addonName
addon.features = {}
addon.started = false

function addon:RegisterFeature(feature)
    self.features[#self.features + 1] = feature
end

function addon:Start()
    local _, class = UnitClass("player")
    if class ~= "PALADIN" or self.started then
        return
    end

    self.started = true
    self:PrepareButtons()
    self.Config.Subscribe(function()
        self:ApplySettings()
    end)
    self:ApplySettings()
end

function addon:PrepareButtons()
    for _, button in ipairs(self.Buttons.All()) do
        self.Glow.Prepare(button)
    end
end

function addon:IsFeatureEnabled(feature)
    return not feature.settingKey or self.Config.Get(feature.settingKey) == true
end

function addon:ApplySettings()
    local color
    if not self.Config.Get("glowNativeColor") then
        color = self.Config.GetColor("glowColor")
    end

    self.Glow.Configure({ color = color })

    for _, feature in ipairs(self.features) do
        if not self:IsFeatureEnabled(feature) and feature.Stop then
            feature:Stop()
        end
    end

    self:Refresh(true)
end

function addon:Refresh(discover, cooldownEvent)
    if not self.started then
        return
    end

    local anyEnabled = false
    for _, feature in ipairs(self.features) do
        if self:IsFeatureEnabled(feature) then
            anyEnabled = true
            break
        end
    end

    if not anyEnabled then
        return
    end

    if discover then
        self:PrepareButtons()
    end

    for _, feature in ipairs(self.features) do
        if self:IsFeatureEnabled(feature) then
            feature:Refresh(discover, cooldownEvent)
        end
    end
end
