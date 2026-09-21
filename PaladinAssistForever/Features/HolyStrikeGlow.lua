local _, addon = ...
local feature = {
    buttons = {},
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

        local buttons = addon.Buttons.FindSpell("Holy Strike")
        local retained = {}
        for _, button in ipairs(buttons) do
            retained[button] = true
        end

        for _, button in ipairs(self.buttons) do
            if not retained[button] then
                addon.Glow.Set(button, self.owner, false)
            end
        end

        self.buttons = buttons
    end

    local ready = addon.Cooldowns.AnyReady(self.spells, cooldownEvent)
    local combat = UnitAffectingCombat("player")
    local showGlow = addon.Client.Readable(combat) and combat and ready or false

    for _, button in ipairs(self.buttons) do
        addon.Glow.Set(button, self.owner, showGlow)
    end
end

function feature:Stop()
    addon.Glow.ClearOwner(self.owner)
    for _, id in pairs(self.spells) do
        addon.Cooldowns.Invalidate(id)
    end

    self.buttons = {}
end
