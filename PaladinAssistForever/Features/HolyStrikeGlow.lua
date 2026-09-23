local _, addon = ...
local feature = {
    spells = {},
    owner = "holy-strike-ready",
    settingKey = "cooldownGlowEnabled",
}
addon.HolyStrikeGlow = feature
addon:RegisterFeature(feature)

function feature:ApplySettings()
    self.activeStyle = nil

    if not addon.Config.Get("holyStrikeCheckEnabled") and self.spells.holyStrike then
        addon.Cooldowns.Invalidate(self.spells.holyStrike)
    end
end

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

    -- Evaluate both enabled spells so each receives its cooldown-event snapshot.
    local judgementReady = addon.Cooldowns.IsReady(self.spells.judgement, cooldownEvent) == true
    local holyStrikeReady = false
    if addon.Config.Get("holyStrikeCheckEnabled") then
        holyStrikeReady = addon.Cooldowns.IsReady(self.spells.holyStrike, cooldownEvent) == true
    end

    local style = judgementReady and "judgement" or (holyStrikeReady and "holyStrike" or nil)
    if style and self.activeStyle ~= style then
        local nativeKey = style == "judgement" and "judgementNativeColor" or "glowNativeColor"
        local colorKey = style == "judgement" and "judgementGlowColor" or "glowColor"
        local color = not addon.Config.Get(nativeKey) and addon.Config.GetColor(colorKey) or nil
        addon.Glow.ConfigureOwner(self.owner, { color = color, priority = 0 })
    end

    self.activeStyle = style
    local ready = style ~= nil
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
    self.activeStyle = nil
end
