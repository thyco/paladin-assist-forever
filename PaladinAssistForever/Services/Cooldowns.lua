local _, addon = ...
local Client = addon.Client
local Cooldowns = {}
addon.Cooldowns = Cooldowns

local gcdOnly = {}

local function readableNumber(value)
    return Client.Readable(value) and type(value) == "number"
end

-- Returns true (ready), false (cooling/unlearned), or nil (unavailable data).
-- These helpers evaluate cooldowns only; they never check cast usability.
function Cooldowns.IsReady(id, cooldownEvent)
    if not id or not Client.IsKnown(id) then
        return false
    end

    local info = Client.Cooldown(id)
    if cooldownEvent then
        gcdOnly[id] = info and Client.Readable(info.isOnGCD) and info.isOnGCD == true or nil
    end

    if not info then
        return nil
    end

    if Client.Readable(info.isEnabled) and info.isEnabled == false then
        return false
    end

    if Client.Readable(info.isActive) and info.isActive == false then
        return true
    end

    -- Capture the event-authoritative GCD flag; keep it between events when
    -- timing is restricted so the polling loop does not undo a ready signal.
    if gcdOnly[id] then
        return true
    end

    local startTime, duration = info.startTime, info.duration
    if not readableNumber(startTime) or not readableNumber(duration) then
        if Client.Readable(info.isActive) and info.isActive == true then
            return false
        end

        return nil
    end

    if startTime == 0 or duration == 0 then
        return true
    end

    -- Compare against the actual GCD, never a guessed duration threshold.
    local gcd = Client.Cooldown(61304)
    if gcd and readableNumber(gcd.startTime) and readableNumber(gcd.duration)
        and gcd.duration > 0 and startTime == gcd.startTime and duration == gcd.duration then
        return true
    end

    return GetTime() >= startTime + duration
end

-- A feature that stops receiving events must release its cached snapshot.
function Cooldowns.Invalidate(id)
    gcdOnly[id] = nil
end

function Cooldowns.AnyReady(ids, cooldownEvent)
    local ready = false
    for _, id in pairs(ids) do
        -- Read every spell so each receives the latest event snapshot.
        if Cooldowns.IsReady(id, cooldownEvent) == true then
            ready = true
        end
    end

    return ready
end
