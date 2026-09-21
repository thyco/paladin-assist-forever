local _, addon = ...
local feature = {
    spells = {},
    owner = "holy-strike-ready",
    settingKey = "cooldownGlowEnabled",
}
addon.HolyStrikeGlow = feature
addon:RegisterFeature(feature)

function feature:Refresh(discover, cooldownEvent)
    if discover then
        self.spells = {
            holyStrike = addon.Client.SpellID("Holy Strike"),
            judgement = addon.Client.SpellID("Judgement"),
        }
    end

    local button = addon.Buttons.Selected(addon.Config.Get("holyStrikeBar"), addon.Config.Get("holyStrikeButton"))
    if self.button and self.button ~= button then
        addon.Glow.Set(self.button, self.owner, false)
    end

    self.button = button

    local ready = addon.Cooldowns.AnyReady(self.spells, cooldownEvent)
    local combat = UnitAffectingCombat("player")
    local showGlow = addon.Client.Readable(combat) and combat and ready or false

    if button then
        addon.Glow.Set(button, self.owner, button:IsVisible() and showGlow)
    end
end

function feature:Stop()
    addon.Glow.ClearOwner(self.owner)
    for _, id in pairs(self.spells) do
        addon.Cooldowns.Invalidate(id)
    end

    self.button = nil
end
