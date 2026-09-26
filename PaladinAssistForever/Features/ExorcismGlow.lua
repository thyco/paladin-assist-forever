local _, addon = ...
local feature = {
    owner = "exorcism-ready",
    settingKey = "exorcismGlowEnabled",
}
addon.ExorcismGlow = feature
addon:RegisterFeature(feature)

local eligibleTypes = { [3] = true, [6] = true } -- Demon, Undead.

function feature:ApplySettings()
    local color = not addon.Config.Get("exorcismNativeColor")
        and addon.Config.GetColor("exorcismGlowColor") or nil
    addon.Glow.ConfigureOwner(self.owner, { color = color, priority = 1 })
end

function feature:Refresh(discover, cooldownEvent)
    if discover then
        self.spellID = addon.Client.SpellID("Exorcism")
    end

    local button = addon.Buttons.Selected(addon.Config.Get("exorcismBar"), addon.Config.Get("exorcismButton"))
    if self.button and self.button ~= button then
        addon.Glow.Set(self.button, self.owner, false)
        addon.ButtonDesaturation.Set(self.button, self.owner, false)
    end

    self.button = button

    local ready = addon.Cooldowns.IsReady(self.spellID, cooldownEvent) == true
    local hasAttackableUnit = addon.Client.CanAttack("target") or addon.Client.CanAttack("mouseover")
    local usable = ready and (addon.Client.HasAttackableCreatureType("target", eligibleTypes)
        or addon.Client.HasAttackableCreatureType("mouseover", eligibleTypes))
    local combat = UnitAffectingCombat("player")
    local inCombat = addon.Client.Readable(combat) and combat

    if button then
        local visible = button:IsVisible()
        addon.ButtonDesaturation.Set(button, self.owner, visible and hasAttackableUnit and not usable)
        addon.Glow.Set(button, self.owner, visible and inCombat and usable)
    end
end

function feature:Stop()
    addon.Glow.ClearOwner(self.owner)
    addon.ButtonDesaturation.ClearOwner(self.owner)
    addon.Cooldowns.Invalidate(self.spellID)
    self.button = nil
end
