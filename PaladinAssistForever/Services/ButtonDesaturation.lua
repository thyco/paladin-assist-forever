local _, addon = ...
local Desaturation = {}
addon.ButtonDesaturation = Desaturation

local entries = {}

local function apply(entry)
    if next(entry.owners) then
        -- Reapply on refresh because the action bar or another addon may have
        -- updated the icon since the last reminder check.
        entry.icon:SetDesaturation(1)
        entry.active = true
    elseif entry.active then
        entry.icon:SetDesaturation(0)
        entry.active = false
    end
end

local function iconFor(button)
    local icon = button.icon or button.Icon
    if not icon and button.GetName then
        local name = button:GetName()
        icon = name and _G[name .. "Icon"]
    end

    if icon and type(icon.SetDesaturation) == "function" then
        return icon
    end
end

function Desaturation.Prepare(button)
    if entries[button] then
        return entries[button]
    end

    local icon = iconFor(button)
    if not icon then
        return nil
    end

    local entry = { icon = icon, owners = {}, active = false }
    entries[button] = entry

    if hooksecurefunc then
        for _, method in ipairs({ "Update", "UpdateUsable", "UpdateAction" }) do
            if type(button[method]) == "function" then
                hooksecurefunc(button, method, function()
                    if entry.active then
                        entry.icon:SetDesaturation(1)
                    end
                end)
            end
        end
    end

    return entry
end

function Desaturation.Set(button, owner, active)
    local entry = entries[button]
    if not entry and active then
        entry = Desaturation.Prepare(button)
    end

    if not entry then
        return
    end

    entry.owners[owner] = active and true or nil
    apply(entry)
end

function Desaturation.ClearOwner(owner)
    for _, entry in pairs(entries) do
        if entry.owners[owner] then
            entry.owners[owner] = nil
            apply(entry)
        end
    end
end
