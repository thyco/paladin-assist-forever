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

function Client.SpellIcon(id)
    if not Client.Readable(id) or not id then
        return nil
    end

    local getTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
    if not getTexture then
        return nil
    end

    local ok, texture = pcall(getTexture, id)
    if ok and Client.Readable(texture) then
        return texture
    end
end

function Client.HasShieldEquipped()
    if not GetInventoryItemID or not C_Item or not C_Item.GetItemInfoInstant then
        return false
    end

    local ok, itemID = pcall(GetInventoryItemID, 'player', 17)
    if not ok or not Client.Readable(itemID) or not itemID then
        return false
    end

    local itemOk, _, _, _, equipLocation = pcall(C_Item.GetItemInfoInstant, itemID)
    return itemOk and Client.Readable(equipLocation) and equipLocation == 'INVTYPE_SHIELD' or false
end

function Client.PlayerAuraExpiration(spellID)
    if not Client.Readable(spellID) or not spellID
        or not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then
        return 'unknown'
    end

    local isSecret = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
    if isSecret then
        local ok, restricted = pcall(isSecret, spellID)
        if not ok or not Client.Readable(restricted) or restricted then
            return 'unknown'
        end
    elseif InCombatLockdown and InCombatLockdown() then
        return 'unknown'
    end

    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or not Client.Readable(aura) then
        return 'unknown'
    end

    if aura == nil then
        return 'absent'
    end

    local read, expiration = pcall(function() return aura.expirationTime end)
    if not read or not Client.Readable(expiration) or type(expiration) ~= 'number' or expiration <= 0 then
        return 'unknown'
    end

    return 'present', expiration
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

-- Use attackability rather than reaction: neutral units that the player can
-- attack also qualify, but corpses do not. Guard client values before branching.
function Client.HasUnit(unit)
    local exists = UnitExists(unit)
    return Client.Readable(exists) and not not exists
end

function Client.CanAttack(unit)
    if not Client.HasUnit(unit) then
        return false
    end

    local dead = UnitIsDeadOrGhost(unit)
    if not Client.Readable(dead) or dead then
        return false
    end

    local attackable = UnitCanAttack("player", unit)
    return Client.Readable(attackable) and not not attackable
end

-- A non-nil range result means the spell accepts this unit as a target.
-- Both true and false qualify; actual distance is not part of this check.
function Client.CanSpellTargetUnit(spellID, unit)
    if not spellID or not C_Spell or not C_Spell.IsSpellInRange then
        return false
    end

    local inRange = C_Spell.IsSpellInRange(spellID, unit)
    return Client.Readable(inRange) and type(inRange) == "boolean"
end

-- Creature-type IDs avoid locale-dependent names. Older clients may return
-- only a localized name. Instance identity restrictions can hide both values.
function Client.HasAttackableCreatureType(unit, acceptedTypes, spellID)
    if not Client.CanAttack(unit) then
        return false
    end

    if UnitCreatureType then
        local name, id = UnitCreatureType(unit)
        if Client.Readable(id) and type(id) == "number" then
            return acceptedTypes[id] == true
        end

        if Client.Readable(name) and type(name) == "string"
            and C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo then
            for acceptedID in pairs(acceptedTypes) do
                local info = C_CreatureInfo.GetCreatureTypeInfo(acceptedID)
                if Client.Readable(info) and info and Client.Readable(info.name) and name == info.name then
                    return true
                end
            end

            return false
        end
    end

    return Client.CanSpellTargetUnit(spellID, unit)
end

function Client.HasGlowContext()
    local combat = UnitAffectingCombat("player")
    if Client.Readable(combat) and combat then
        return true
    end

    return Client.CanAttack("target") or Client.CanAttack("mouseover")
end
