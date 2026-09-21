local _, addon = ...
local Macros = {}
addon.Macros = Macros

local function normalize(text)
    return text:lower():gsub("%s*%([^)]*%)%s*$", ""):match("^%s*(.-)%s*$")
end

-- Deliberately parses simple /cast lines, not conditional macro execution.
function Macros.Casts(body, spellName)
    if not addon.Client.Readable(body) or type(body) ~= "string" then
        return false
    end

    local wanted = normalize(spellName)
    for line in body:gmatch("[^\r\n]+") do
        local command, argument = line:match("^%s*(/%S+)%s+(.+)$")
        if command and command:lower() == "/cast" and normalize(argument) == wanted then
            return true
        end
    end

    return false
end
