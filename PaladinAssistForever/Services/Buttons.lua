local _, addon = ...
local Buttons = {}
addon.Buttons = Buttons

local prefixes = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button",
    "MultiBar6Button", "MultiBar7Button",
}

-- Stable physical bar/button selections, independent of spell discovery.
function Buttons.Bars()
    return {
        "Main bar", "Bottom left bar", "Bottom right bar",
        "Right bar", "Left bar (second right bar)", "Action bar 6",
        "Action bar 7", "Action bar 8",
    }
end

function Buttons.Selected(bar, index)
    if type(bar) ~= "number" or type(index) ~= "number"
        or not prefixes[bar] or index < 1 or index > 12 or index ~= math.floor(index) then
        return nil
    end

    return _G[prefixes[bar] .. index]
end

function Buttons.All()
    local buttons = {}
    for _, prefix in ipairs(prefixes) do
        for index = 1, 12 do
            local button = _G[prefix .. index]
            if button then
                buttons[#buttons + 1] = button
            end
        end
    end

    return buttons
end

function Buttons.FindSpell(spellName)
    local matches = {}
    for _, button in ipairs(Buttons.All()) do
        if button:IsVisible() then
            -- Read the live slot; button IDs alone ignore action-bar paging.
            local slot = button.action
            local action = addon.Client.Action(slot)
            local matchesSpell = false

            if action and action.kind == "spell" then
                local name = addon.Client.SpellName(action.id)
                matchesSpell = name and name:lower() == spellName:lower()
            elseif action and action.kind == "macro" then
                matchesSpell = addon.Macros.Casts(action.body, spellName)
            end

            if matchesSpell then
                matches[#matches + 1] = button
            end
        end
    end

    return matches
end
