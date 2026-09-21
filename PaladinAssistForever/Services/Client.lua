local _, addon = ...
local Client = {}
addon.Client = Client

-- Never compare, stringify, or calculate with a restricted value.
function Client.Readable(value)
    return not issecretvalue or not issecretvalue(value)
end

function Client.SpellID(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        return info and info.spellID
    end

    if GetSpellInfo then
        return select(7, GetSpellInfo(name))
    end
end

function Client.SpellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end

    if GetSpellInfo then
        return GetSpellInfo(id)
    end
end

function Client.IsKnown(id)
    if not id then
        return false
    end

    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(id)
    end

    if IsSpellKnownOrOverridesKnown then
        return IsSpellKnownOrOverridesKnown(id)
    end

    return IsSpellKnown and IsSpellKnown(id) or false
end

function Client.Cooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        return C_Spell.GetSpellCooldown(id)
    end

    if GetSpellCooldown then
        local startTime, duration, enabled, modRate = GetSpellCooldown(id)
        if startTime == nil then
            return nil
        end

        return { startTime = startTime, duration = duration, isEnabled = enabled == 1, modRate = modRate or 1 }
    end
end

function Client.Action(slot)
    if not Client.Readable(slot) or type(slot) ~= "number" or slot < 1 then
        return nil
    end

    local getInfo = GetActionInfo or (C_ActionBar and C_ActionBar.GetActionInfo)
    if not getInfo then
        return nil
    end

    local kind, id, subtype = getInfo(slot)
    if not Client.Readable(kind) or not Client.Readable(id) or not Client.Readable(subtype) then
        return nil
    end

    local body
    if kind == "macro" and GetMacroInfo then
        -- Modern GetActionInfo may return the macro's displayed spell ID.
        -- Older versions return the macro index instead.
        if subtype == nil or subtype == "macro" then
            body = select(3, GetMacroInfo(id))
        else
            local getText = C_ActionBar and C_ActionBar.GetActionText or GetActionText
            local name = getText and getText(slot)
            if Client.Readable(name) and name then
                body = select(3, GetMacroInfo(name))
            end
        end
    end

    return { kind = kind, id = id, body = body }
end
