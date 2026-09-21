local _, addon = ...
local Config = {}
addon.Config = Config

local defaults = {
    cooldownGlowEnabled = true,
    holyStrikeBar = 0,
    holyStrikeButton = 1,
    glowNativeColor = true,
    glowColor = "ff00e633",
    sealGlowEnabled = true,
    sealBar = 0,
    sealButton = 1,
    sealGlowColor = "ffff0000",
}
local values
local listeners = {}

local function validValue(key, value)
    if type(value) ~= type(defaults[key]) then
        return false
    end

    if key == "glowColor" or key == "sealGlowColor" then
        return #value == 8 and value:match("^%x+$") ~= nil
    end

    if key == "sealBar" or key == "holyStrikeBar" then
        return value >= 0 and value <= 8 and value == math.floor(value)
    elseif key == "sealButton" or key == "holyStrikeButton" then
        return value >= 1 and value <= 12 and value == math.floor(value)
    end

    return true
end

local function normalize(key, value)
    if key == "glowColor" or key == "sealGlowColor" then
        -- The native RGB picker can return a zero alpha byte. Glow opacity is
        -- always opaque; only RGB is configurable.
        return "ff" .. value:sub(3):lower()
    end

    return value
end

function Config.Initialize()
    if type(PaladinAssistForeverDB) ~= "table" then
        PaladinAssistForeverDB = {}
    end

    values = PaladinAssistForeverDB
    for key, default in pairs(defaults) do
        if not validValue(key, values[key]) then
            values[key] = default
        else
            values[key] = normalize(key, values[key])
        end
    end
end

function Config.GetDefault(key)
    return defaults[key]
end

function Config.GetColor(key)
    local hex = Config.Get(key)
    return {
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        tonumber(hex:sub(7, 8), 16) / 255,
        1,
    }
end

function Config.Get(key)
    if values and values[key] ~= nil then
        return values[key]
    end

    return defaults[key]
end

function Config.Set(key, value)
    assert(defaults[key] ~= nil, "Unknown configuration key: " .. key)
    assert(validValue(key, value), "Invalid configuration value: " .. key)
    value = normalize(key, value)

    if not values then
        Config.Initialize()
    end

    if values[key] == value then
        return
    end

    values[key] = value
    for _, listener in ipairs(listeners) do
        listener(key, value)
    end
end

function Config.Subscribe(listener)
    listeners[#listeners + 1] = listener
end
