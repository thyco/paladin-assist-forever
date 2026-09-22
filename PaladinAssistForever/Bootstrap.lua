local _, addon = ...
local frame = CreateFrame("Frame")
local elapsedSinceUpdate, elapsedSinceDiscovery = 0, 0
local discoveryEvents = {
    "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
    "UPDATE_BONUS_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
    "UPDATE_MACROS", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
}

frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        addon.Config.Initialize()
        addon.SettingsPanel:Initialize()
        addon:Start()
        if not addon.started then
            self:UnregisterAllEvents()
            return
        end

        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterEvent("PLAYER_DEAD")
        self:RegisterEvent("PLAYER_TARGET_CHANGED")
        self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        for _, name in ipairs(discoveryEvents) do
            self:RegisterEvent(name)
        end

        self:SetScript("OnUpdate", function(_, elapsed)
            elapsedSinceUpdate = elapsedSinceUpdate + elapsed
            elapsedSinceDiscovery = elapsedSinceDiscovery + elapsed
            if elapsedSinceUpdate < 0.1 then
                return
            end

            local discover = elapsedSinceDiscovery >= 0.5
            elapsedSinceUpdate = 0
            if discover then
                elapsedSinceDiscovery = 0
            end

            addon:Refresh(discover)
        end)
        return
    end

    addon:OnEvent(event, ...)

    if event == "PLAYER_REGEN_ENABLED" then
        addon:PrepareButtons()
    end

    local discover = false
    for _, name in ipairs(discoveryEvents) do
        if event == name then
            discover = true
            break
        end
    end

    addon:Refresh(discover, event == "SPELL_UPDATE_COOLDOWN")
end)

SLASH_PALADINASSISTFOREVER1 = "/paf"
SlashCmdList.PALADINASSISTFOREVER = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "config" then
        addon.SettingsPanel:Open()
        return
    end

    local version, build, _, interface = GetBuildInfo()
    print("Paladin Assist Forever 0.6.6 | client " .. version .. " (" .. build .. ") | interface " .. interface)
    if not addon.started then
        print("Paladin features are inactive on this character.")
        return
    end

    print("Cooldown glow: " .. (addon.Config.Get("cooldownGlowEnabled") and "enabled" or "disabled") .. " | /paf config to configure")
    addon:Refresh(true)
    local seal = addon.SealReminder
    local target = addon.Buttons.Bars()[addon.Config.Get("sealBar")]
    print("Seal reminder: " .. (addon.Config.Get("sealGlowEnabled") and "enabled" or "disabled")
        .. " | target: " .. (target and (target .. " / " .. addon.Config.Get("sealButton")) or "not selected")
        .. " | refresh due in: " .. string.format("%.1fs", seal.timer:Remaining())
        .. " | ignored restricted casts: " .. seal.ignoredRestrictedCasts)
    local holyBar = addon.Buttons.Bars()[addon.Config.Get("holyStrikeBar")]
    print("Holy Strike/Judgement target: "
        .. (holyBar and (holyBar .. " / " .. addon.Config.Get("holyStrikeButton")) or "not selected"))
    for _, name in ipairs({ "Holy Strike", "Judgement" }) do
        local id = addon.Client.SpellID(name)
        local ready = addon.Cooldowns.IsReady(id)
        local state = "unavailable"
        if ready == true then
            state = "ready"
        elseif ready == false then
            state = "on cooldown or unlearned"
        end

        print(name .. ": " .. state .. " (spell " .. tostring(id) .. ")")
    end
end
