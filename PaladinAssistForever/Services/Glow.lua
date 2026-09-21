local _, addon = ...
local Glow = {}
addon.Glow = Glow

-- State lives here, never on Blizzard's protected action buttons.
local entries = {}

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

    local border = frame:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -10, 10)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, -10)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetVertexColor(1, 0.82, 0.15, 1)
    frame:Hide()

    local entry = { frame = frame, owners = {} }
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
    entry.frame:SetShown(next(entry.owners) ~= nil)
end

function Glow.ClearOwner(owner)
    for button in pairs(entries) do
        Glow.Set(button, owner, false)
    end
end
