local _, addon = ...
local feature = {
    owner = "seal-reminder",
    settingKey = "sealGlowEnabled",
    timer = addon.Timers.New(),
    ignoredRestrictedCasts = 0,
}
addon.SealReminder = feature
addon:RegisterFeature(feature)

-- Match spell names so all ranks share one timer. English client, as with
-- Holy Strike discovery. Add future seal names here without changing services.
local seals = {
    ["Seal of Righteousness"] = true,
    ["Seal of the Crusader"] = true,
    ["Seal of Command"] = true,
    ["Seal of Justice"] = true,
    ["Seal of Light"] = true,
    ["Seal of Wisdom"] = true,
    ["Seal of Fury"] = true,
    ["Seal of Blood"] = true,
    ["Seal of the Martyr"] = true,
    ["Seal of Vengeance"] = true,
    ["Seal of Corruption"] = true,
}

function feature:ApplySettings()
    addon.Glow.ConfigureOwner(self.owner, { color = addon.Config.GetColor("sealGlowColor"), priority = 10 })
end

function feature:OnEvent(event, unit, castGUID, spellID)
    if event == "PLAYER_DEAD" then
        self.timer:Clear()
        return
    end

    if event ~= "UNIT_SPELLCAST_SUCCEEDED" then
        return
    end

    if not addon.Client.Readable(unit) then
        self.ignoredRestrictedCasts = self.ignoredRestrictedCasts + 1
        return
    end

    if unit ~= "player" then
        return
    end

    if not addon.Client.Readable(spellID) then
        self.ignoredRestrictedCasts = self.ignoredRestrictedCasts + 1
        return
    end

    if type(spellID) ~= "number" then
        return
    end

    local name = addon.Client.SpellName(spellID)
    if not addon.Client.Readable(name) then
        self.ignoredRestrictedCasts = self.ignoredRestrictedCasts + 1
        return
    end

    if name and seals[name] then
        self.timer:Start(27)
    end
end

function feature:Refresh()
    local button = addon.Buttons.Selected(addon.Config.Get("sealBar"), addon.Config.Get("sealButton"))
    if self.button and self.button ~= button then
        addon.Glow.Set(self.button, self.owner, false)
    end

    self.button = button
    if not button then
        return
    end

    local show = button:IsVisible() and addon.Client.HasGlowContext() and self.timer:IsDue()
    addon.Glow.Set(button, self.owner, show)
end

function feature:Stop()
    addon.Glow.ClearOwner(self.owner)
    self.button = nil
    -- Keep observing casts while disabled so enabling preserves the timer.
end
