local _, addon = ...
local Timers = {}
addon.Timers = Timers

-- Session-local deadlines. Missing timers are due until an event starts them.
-- Inputs must be ordinary addon-owned values, never secret aura data.
function Timers.New()
    local timer = {}

    function timer:Start(seconds)
        self.startedAt = GetTime()
        self.deadline = self.startedAt + seconds
    end

    -- Recalculate from the observed event, never from the settings change.
    function timer:SetDuration(seconds)
        if self.startedAt then
            self.deadline = self.startedAt + seconds
        end
    end

    function timer:Clear()
        self.startedAt = nil
        self.deadline = nil
    end

    function timer:IsDue()
        return self.deadline == nil or GetTime() >= self.deadline
    end

    function timer:Remaining()
        return self.deadline and math.max(0, self.deadline - GetTime()) or 0
    end

    return timer
end
