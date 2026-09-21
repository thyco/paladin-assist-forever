local _, addon = ...
local Glow = {}
local library = LibStub("LibCustomGlow-1.0")
local glowKey = "PaladinAssistForever"
addon.Glow = Glow

-- State lives here, never on Blizzard's protected action buttons.
local entries = {}
local appearanceColor

local function start(frame)
    library.ProcGlow_Start(frame, { key = glowKey, startAnim = true, color = appearanceColor })
end

local function sameColor(first, second)
    if first == second then
        return true
    end

    if not first or not second then
        return false
    end

    for index = 1, 4 do
        if first[index] ~= second[index] then
            return false
        end
    end

    return true
end

-- Applies a shared appearance without knowing anything about saved settings.
-- A nil color preserves Blizzard's native artwork; RGBA selects a custom tint.
function Glow.Configure(options)
    local color = options.color
    if sameColor(appearanceColor, color) then
        return
    end

    appearanceColor = color and { color[1], color[2], color[3], color[4] } or nil
    for _, entry in pairs(entries) do
        if entry.active then
            -- LibCustomGlow updates an existing effect in place. Its OnShow
            -- animation does not restart because the frame is already shown.
            start(entry.frame)
        end
    end
end

function Glow.Prepare(button)
    if entries[button] then
        return entries[button]
    end

    -- Prepare default buttons on login and after combat, including empty ones.
    if InCombatLockdown() then
        return nil
    end

    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints(button)
    frame:SetFrameLevel(button:GetFrameLevel() + 6)
    frame:EnableMouse(false)

    frame:Hide()

    local entry = { frame = frame, owners = {}, active = false }
    entries[button] = entry
    return entry
end

function Glow.Set(button, owner, active)
    local entry = entries[button]
    if not entry and active then
        entry = Glow.Prepare(button)
    end

    if not entry then
        return
    end

    entry.owners[owner] = active and true or nil
    local wanted = next(entry.owners) ~= nil
    if wanted == entry.active then
        return
    end

    if wanted then
        entry.frame:Show()
        start(entry.frame)
    else
        library.ProcGlow_Stop(entry.frame, glowKey)
        entry.frame:Hide()
    end

    entry.active = wanted
end

function Glow.ClearOwner(owner)
    for button in pairs(entries) do
        Glow.Set(button, owner, false)
    end
end
