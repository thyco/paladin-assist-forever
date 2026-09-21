local passed, failed = 0, 0
local function test(name, run)
    local ok, message = pcall(run)

    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. tostring(message))
    end
end

local function equal(actual, expected)
    assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local addon = {}
local files = { 'Core', 'Services/Config', 'Services/Client', 'Services/Macros', 'Services/Buttons', 'Services/Glow', 'Services/Cooldowns', 'Features/HolyStrikeGlow' }
for _, name in ipairs(files) do
    local chunk = loadfile('PaladinAssistForever/' .. name .. '.lua')

    if chunk then
        chunk('PaladinAssistForever', addon)
    end
end

local macro = '#showtooltip holy strike\n/cast judgement\n/cast holy strike\n/startattack'
local now = 100
local known = { [1] = true, [2] = true }
local cooldowns = {}
local secret = setmetatable({}, { __eq = function() error('secret comparison') end, __add = function() error('secret arithmetic') end })
_G.issecretvalue = function(value) return rawequal(value, secret) end
_G.GetTime = function() return now end
_G.C_Spell = {
    GetSpellInfo = function(value)
        if value == 'Holy Strike' or value == 1 then return { spellID = 1, name = 'Holy Strike' } end
        if value == 'Judgement' or value == 2 then return { spellID = 2, name = 'Judgement' } end
    end,
    GetSpellCooldown = function(id) return cooldowns[id] end,
}
_G.C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }

local function ready() return { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1 } end
local function cooling() return { startTime = 99, duration = 6, isEnabled = true, isActive = true, modRate = 1 } end

-- A mistaken AND, or testing only Holy Strike, breaks these separate cases.
test('either-ready: only Judgement ready', function()
    cooldowns = { [1] = cooling(), [2] = ready() }

    equal(addon.Cooldowns.AnyReady({1, 2}), true)
end)
test('either-ready: only Holy Strike ready', function()
    cooldowns = { [1] = ready(), [2] = cooling() }

    equal(addon.Cooldowns.AnyReady({1, 2}), true)
end)
test('either-ready: both cooling down', function()
    cooldowns = { [1] = cooling(), [2] = cooling() }

    equal(addon.Cooldowns.AnyReady({1, 2}), false)
end)
test('either-ready: both ready', function()
    cooldowns = { [1] = ready(), [2] = ready() }

    equal(addon.Cooldowns.AnyReady({1, 2}), true)
end)
test('unlearned spells do not appear ready', function()
    cooldowns = { [3] = ready() }

    equal(addon.Cooldowns.IsReady(3), false)
end)
test('missing cooldown is unknown', function()
    cooldowns = {}

    equal(addon.Cooldowns.IsReady(1), nil)
end)
test('expiry works without a fresh cooldown event', function()
    cooldowns = { [1] = { startTime = 90, duration = 6, isEnabled = true, isActive = true, modRate = 1 } }

    equal(addon.Cooldowns.IsReady(1), true)
end)
test('global cooldown alone does not suppress glow', function()
    cooldowns = { [1] = { startTime = 99, duration = 1.5, isEnabled = true, modRate = 1 }, [61304] = { startTime = 99, duration = 1.5, isEnabled = true, modRate = 1 } }

    equal(addon.Cooldowns.IsReady(1), true)
end)
test('short real cooldown is not assumed to be GCD', function()
    cooldowns = { [1] = { startTime = 99, duration = 1.5, isEnabled = true, modRate = 1 } }

    equal(addon.Cooldowns.IsReady(1), false)
end)
test('restricted timing uses public inactive flag', function()
    cooldowns = { [1] = { startTime = secret, duration = secret, isEnabled = true, isActive = false } }

    equal(addon.Cooldowns.IsReady(1), true)
end)
test('restricted timing with no definitive flag is unknown', function()
    cooldowns = { [1] = { startTime = secret, duration = secret, isEnabled = true } }

    equal(addon.Cooldowns.IsReady(1), nil)
end)
test('unknown spell does not mask another ready spell', function()
    cooldowns = { [2] = ready() }

    equal(addon.Cooldowns.AnyReady({1, 2}), true)
end)
test('supplied macro matches Holy Strike case-insensitively', function()
    equal(addon.Macros.Casts(macro, 'Holy Strike'), true)
end)
test('macro tooltip alone does not count as a cast', function()
    equal(addon.Macros.Casts('#showtooltip Holy Strike\n/cast Judgement', 'Holy Strike'), false)
end)
test('macro spell substring does not count', function()
    equal(addon.Macros.Casts('/cast Improved Holy Strike', 'Holy Strike'), false)
end)
test('macro supports rank suffix and whitespace', function()
    equal(addon.Macros.Casts(' /CAST   Holy Strike(Rank 2)  \r\n/startattack', 'Holy Strike'), true)
end)

local actions = { [1] = { 'macro', 7 }, [2] = { 'spell', 2 } }
_G.GetActionInfo = function(slot) local a = actions[slot]; if a then return a[1], a[2], a[3] end end
_G.GetMacroInfo = function(id) if id == 7 or id == 'Strike' then return 'Strike', 123, macro end end
_G.GetActionText = function(slot) if slot == 1 then return 'Strike' end end
local button = { action = 1, IsVisible = function() return true end }
_G.ActionButton1 = button
_G.ActionButton2 = { action = 2, IsVisible = function() return true end }

test('finds macro button without selecting Judgement button', function()
    local found = addon.Buttons.FindSpell('Holy Strike')

    equal(#found, 1)
    equal(found[1], button)
end)
test('modern macro action with spell ID still resolves body', function()
    actions[1] = { 'macro', 2, 'spell' }

    equal(addon.Buttons.FindSpell('Holy Strike')[1], button)
    actions[1] = { 'macro', 7 }
end)
test('button paging follows current action slot', function()
    button.action = 2

    equal(#addon.Buttons.FindSpell('Holy Strike'), 0)
    button.action = 1
end)

-- Only frame rendering is simulated; ownership and feature rules run for real.
local overlays = {}
local lastFrame
local function texture()
    return { SetAllPoints = function() end, SetTexture = function() end, SetBlendMode = function() end, SetVertexColor = function() end, SetPoint = function() end, SetColorTexture = function() end, SetSize = function() end }
end
local playerInCombat = true
_G.UnitAffectingCombat = function(unit)
    assert(unit == 'player')
    return playerInCombat
end
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function(_, _, parent)
    local frame = { parent = parent, visible = false }
    function frame:SetAllPoints() end
    function frame:SetFrameLevel() end
    function frame:EnableMouse() end
    function frame:CreateTexture() return texture() end
    function frame:Show() self.visible = true end
    function frame:Hide() self.visible = false end
    function frame:SetShown(show) self.visible = show end
    function frame:SetPoint() end
    function frame:CreateAnimationGroup()
        return { SetLooping = function() end, Play = function() end, Stop = function() end, CreateAnimation = function() return { SetFromAlpha = function() end, SetToAlpha = function() end, SetDuration = function() end, SetSmoothing = function() end } end }
    end
    function frame:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
    function frame:UnregisterAllEvents() self.events = {} end
    function frame:SetScript(event, callback) self.scripts = self.scripts or {}; self.scripts[event] = callback end
    lastFrame = frame
    if parent then overlays[parent] = frame end

    return frame
end
button.GetFrameLevel = function() return 1 end
_G.ActionButton2.GetFrameLevel = function() return 1 end

test('another owner keeps shared glow visible', function()
    addon.Glow.Set(button, 'first', true)
    addon.Glow.Set(button, 'second', true)
    addon.Glow.Set(button, 'first', false)

    equal(overlays[button].visible, true)
    addon.Glow.ClearOwner('second')
    equal(overlays[button].visible, false)
end)
test('feature glows macro when only Judgement is ready', function()
    cooldowns = { [1] = cooling(), [2] = ready() }

    addon.HolyStrikeGlow:Refresh(true)

    equal(overlays[button].visible, true)
end)
test('feature removes glow when macro moves away', function()
    button.action = 2

    addon.HolyStrikeGlow:Refresh(true)

    equal(overlays[button].visible, false)
    button.action = 1
end)
test('feature clears glow when both cooldowns start', function()
    cooldowns = { [1] = cooling(), [2] = cooling() }

    addon.HolyStrikeGlow:Refresh(true)

    equal(overlays[button].visible, false)
end)
test('non-paladin core never starts features', function()
    _G.UnitClass = function() return 'Warrior', 'WARRIOR' end

    addon:Start()

    equal(addon.started, false)
end)

test('restricted GCD readiness remains stable between cooldown events', function()
    cooldowns = { [1] = { startTime = secret, duration = secret, isEnabled = true, isActive = true, isOnGCD = true } }

    equal(addon.Cooldowns.IsReady(1, true), true)
    equal(addon.Cooldowns.IsReady(1), true)

    cooldowns[1].isOnGCD = false
    equal(addon.Cooldowns.IsReady(1, true), false)
end)
test('glow reuses overlay without recreating frames', function()
    addon.Glow.Set(button, 'reuse', true)
    local first = overlays[button]

    addon.Glow.Set(button, 'reuse', false)
    addon.Glow.Set(button, 'reuse', true)

    equal(overlays[button], first)
    addon.Glow.ClearOwner('reuse')
end)
test('new overlays wait until combat ends', function()
    local newButton = { GetFrameLevel = function() return 1 end }
    _G.InCombatLockdown = function() return true end

    addon.Glow.Set(newButton, 'combat', true)

    equal(overlays[newButton], nil)
    _G.InCombatLockdown = function() return false end
end)

-- WoW's native Settings UI drives the real addon getter/setter callbacks.
local settingsControls = {}
local openedCategory
_G.Settings = {
    VarType = { Boolean = 'boolean' },
    RegisterVerticalLayoutCategory = function(name)
        return { GetID = function() return 42 end }
    end,
    RegisterProxySetting = function(category, variable, valueType, name, default, getter, setter)
        return { GetValue = getter, SetValue = function(_, value) setter(value) end }
    end,
    CreateCheckbox = function(category, setting)
        settingsControls[#settingsControls + 1] = setting
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) openedCategory = id end,
}

local function loadBootstrap(class)
    local instance = {}
    _G.UnitClass = function() return class, class end
    _G.SlashCmdList = {}
    for line in io.lines('PaladinAssistForever/PaladinAssistForever.toc') do
        if line:match('%.lua$') then
            assert(loadfile('PaladinAssistForever/' .. line))('PaladinAssistForever', instance)
        end
    end

    return instance, lastFrame
end

test('manifest bootstraps paladin and updates glow after expiry', function()
    cooldowns = { [1] = cooling(), [2] = cooling() }
    local instance, events = loadBootstrap('PALADIN')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.started, true)
    equal(overlays[button].visible, false)
    now = 106
    events.scripts.OnUpdate(events, 0.1)
    equal(overlays[button].visible, true)
    now = 100
end)
test('non-paladin bootstrap registers no update loop', function()
    local instance, events = loadBootstrap('WARRIOR')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.started, false)
    equal(events.scripts.OnUpdate, nil)
    equal(next(events.events), nil)
end)

test('fresh settings default to enabled and show ready glow', function()
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = ready(), [2] = cooling() }
    local instance, events = loadBootstrap('PALADIN')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.Config.Get('cooldownGlowEnabled'), true)
    equal(overlays[button].visible, true)
end)
test('settings checkbox disables glow immediately and polling keeps it off', function()
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    local checkbox = settingsControls[#settingsControls]

    checkbox:SetValue(false)

    equal(overlays[button].visible, false)
    equal(_G.PaladinAssistForeverDB.cooldownGlowEnabled, false)
    events.scripts.OnUpdate(events, 0.5)
    equal(overlays[button].visible, false)
end)
test('disabled preference survives a reload', function()
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false, futureOption = 'keep' }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.Config.Get('cooldownGlowEnabled'), false)
    equal(settingsControls[#settingsControls]:GetValue(), false)
    equal(_G.PaladinAssistForeverDB.futureOption, 'keep')
    equal(overlays[button].visible, false)
end)
test('re-enabling discovers moved macro and refreshes immediately', function()
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    button.action = 2
    _G.ActionButton2.action = 1

    settingsControls[#settingsControls]:SetValue(true)

    equal(overlays[_G.ActionButton2].visible, true)
    equal(overlays[button].visible, false)
    button.action = 1
    _G.ActionButton2.action = 2
end)
test('disabling feature preserves glow owned by another feature', function()
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    instance.Glow.Set(button, 'other-feature', true)

    settingsControls[#settingsControls]:SetValue(false)

    equal(overlays[button].visible, true)
    instance.Glow.ClearOwner('other-feature')
    equal(overlays[button].visible, false)
end)
test('config slash command opens panel on a non-paladin without enabling features', function()
    _G.PaladinAssistForeverDB = nil
    local instance, events = loadBootstrap('WARRIOR')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    openedCategory = nil

    _G.SlashCmdList.PALADINASSISTFOREVER('config')

    equal(openedCategory, 42)
    equal(instance.started, false)
    equal(events.scripts.OnUpdate, nil)
end)

test('disabled at login can be enabled during combat', function()
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false }
    cooldowns = { [1] = ready(), [2] = ready() }
    overlays[button] = nil
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    _G.InCombatLockdown = function() return true end

    settingsControls[#settingsControls]:SetValue(true)
    _G.InCombatLockdown = function() return false end

    equal(overlays[button] and overlays[button].visible, true)
end)
test('re-enabling discards readiness cached before disabling', function()
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = { startTime = 99, duration = 1.5, isEnabled = true, isActive = true, isOnGCD = true }, [2] = cooling() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    events.scripts.OnEvent(events, 'SPELL_UPDATE_COOLDOWN')
    equal(overlays[button].visible, true)
    settingsControls[#settingsControls]:SetValue(false)
    cooldowns = { [1] = cooling(), [2] = cooling() }
    events.scripts.OnEvent(events, 'SPELL_UPDATE_COOLDOWN')

    settingsControls[#settingsControls]:SetValue(true)

    equal(overlays[button].visible, false)
end)

test('ready spells do not glow outside combat', function()
    playerInCombat = false
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    events.scripts.OnUpdate(events, 0.5)

    equal(overlays[button].visible, false)
end)
test('entering combat immediately highlights a ready spell', function()
    playerInCombat = false
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = cooling(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    playerInCombat = true
    equal(events.events.PLAYER_REGEN_DISABLED, true)
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')

    equal(overlays[button].visible, true)
end)
test('leaving combat immediately clears glow and polling keeps it off', function()
    playerInCombat = true
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    equal(overlays[button].visible, true)

    playerInCombat = false
    events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')

    equal(overlays[button].visible, false)
    events.scripts.OnUpdate(events, 0.5)
    equal(overlays[button].visible, false)
end)
test('enabling setting outside combat waits until combat starts', function()
    playerInCombat = false
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    settingsControls[#settingsControls]:SetValue(true)

    equal(overlays[button].visible, false)
end)
test('entering combat respects the disabled setting', function()
    playerInCombat = false
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    playerInCombat = true
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')

    equal(overlays[button].visible, false)
end)

print(string.format('\n%d passed; %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
