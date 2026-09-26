local _, addon = ...
local Shade = {}
addon.ButtonShade = Shade

local entries = {}

local function update(entry)
    local visible = next(entry.owners) ~= nil
    if visible == entry.visible then
        return
    end

    if visible then
        entry.texture:Show()
    else
        entry.texture:Hide()
    end

    entry.visible = visible
end

-- Create only outside combat. The texture changes appearance without
-- changing a protected button's action, attributes, or click behavior.
function Shade.Prepare(button)
    if entries[button] then
        return entries[button]
    end

    if InCombatLockdown() or not button.CreateTexture then
        return nil
    end

    local texture = button:CreateTexture(nil, "ARTWORK", nil, -1)
    texture:SetAllPoints(button.icon or button.Icon or button)
    texture:SetColorTexture(0.2, 0.2, 0.2, 0.7)
    texture:Hide()

    local entry = { texture = texture, owners = {}, visible = false }
    entries[button] = entry
    return entry
end

function Shade.Set(button, owner, active)
    local entry = entries[button]
    if not entry and active then
        entry = Shade.Prepare(button)
    end

    if not entry then
        return
    end

    entry.owners[owner] = active and true or nil
    update(entry)
end

function Shade.ClearOwner(owner)
    for _, entry in pairs(entries) do
        if entry.owners[owner] then
            entry.owners[owner] = nil
            update(entry)
        end
    end
end
