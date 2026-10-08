local _, addon = ...
local feature = {
    owner = 'righteous-fury-reminder',
    settingKey = 'righteousFuryEnabled',
    timer = addon.Timers.New(),
    preview = false,
}
addon.RighteousFuryReminder = feature
addon:RegisterFeature(feature)

local spellName = 'Righteous Fury'
local reminderSeconds = 1500
local graceSeconds = 2

function feature:EnsurePopup()
    if self.popup then
        return
    end

    self.popup = addon.PopupIcons.New(self.owner, function(x, y)
        addon.Config.Set('righteousFuryPopupX', x)
        addon.Config.Set('righteousFuryPopupY', y)
    end)
end

function feature:ApplySettings()
    self:EnsurePopup()
    self.popup:SetSize(addon.Config.Get('righteousFuryPopupSize'))
    self.popup:SetPosition(addon.Config.Get('righteousFuryPopupX'), addon.Config.Get('righteousFuryPopupY'))
    addon.Glow.ConfigureOwner(self.owner, { color = nil, priority = 10 })
end

function feature:OnEvent(event, unit, castGUID, spellID)
    if event == 'PLAYER_DEAD' then
        self.timer:Clear()
        self.lastAuraCheck = nil
        return
    end

    if event == 'PLAYER_REGEN_ENABLED' then
        self.lastAuraCheck = nil
        return
    end

    if event ~= 'UNIT_SPELLCAST_SUCCEEDED'
        or not addon.Client.Readable(unit) or unit ~= 'player'
        or not addon.Client.Readable(spellID) or type(spellID) ~= 'number' then
        return
    end

    local name = addon.Client.SpellName(spellID)
    if not addon.Client.Readable(name) or name ~= spellName then
        return
    end

    self.timer:Start(reminderSeconds)
    self.castGraceUntil = GetTime() + graceSeconds
    self.lastAuraCheck = nil
end

function feature:Refresh()
    self:EnsurePopup()
    self.spellID = addon.Client.SpellID(spellName)
    self.popup:SetIcon(addon.Client.SpellIcon(self.spellID))

    local time = GetTime()
    local graceActive = self.castGraceUntil and time < self.castGraceUntil
    local graceFinished = self.castGraceUntil and time >= self.castGraceUntil
    if self.spellID and not graceActive
        and (not self.lastAuraCheck or time - self.lastAuraCheck >= 1 or graceFinished) then
        self.lastAuraCheck = time
        self.castGraceUntil = nil

        local status, expiration = addon.Client.PlayerAuraExpiration(self.spellID)
        if status == 'present' then
            self.timer:Start(math.max(0, expiration - time - 300))
        elseif status == 'absent' then
            self.timer:Clear()
        end
    end

    local combat = UnitAffectingCombat('player')
    local flash = addon.Client.Readable(combat) and not not combat
    local due = not self.preview and addon.Config.Get(self.settingKey)
        and addon.Client.IsKnown(self.spellID)
        and addon.Client.HasShieldEquipped()
        and self.timer:IsDue()

    self.popup:SetVisible(due, self.preview, flash)
end

function feature:SetPreview(show)
    if not addon.started then
        return
    end

    self.preview = not not show
    self:Refresh()
end

function feature:Stop()
    if self.popup then
        self.popup:SetVisible(false, self.preview, false)
    end
end
