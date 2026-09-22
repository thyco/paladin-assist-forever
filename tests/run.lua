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

-- Adapter tests simulate the external renderer; glow_integration.lua loads
-- the actual bundled libraries against WoW frame/pool doubles.
local glowLibrary = {
    ProcGlow_Start = function(frame, options)
        frame.procStarts = (frame.procStarts or 0) + 1
        frame.procKey = options.key
        frame.procStartAnimation = options.startAnim
        frame.procColor = options.color
        frame.procVisible = true
    end,
    ProcGlow_Stop = function(frame, key)
        assert(key == frame.procKey, 'must stop the same keyed glow')
        frame.procStops = (frame.procStops or 0) + 1
        frame.procVisible = false
    end,
}
_G.LibStub = function(name)
    assert(name == 'LibCustomGlow-1.0')
    return glowLibrary
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
local unitPresence = {}
local unitAttackable = {}
local unitDead = {}
_G.UnitExists = function(unit) return unitPresence[unit] end
_G.UnitIsDeadOrGhost = function(unit) return unitDead[unit] or false end
_G.UnitCanAttack = function(player, unit)
    assert(player == 'player')
    return unitAttackable[unit]
end
local playerInCombat = true
_G.UnitAffectingCombat = function(unit)
    assert(unit == 'player')
    return playerInCombat
end
_G.InCombatLockdown = function() return false end
_G.CreateFrame = function(_, _, parent)
    local frame = { parent = parent, visible = false }
    local function fontString()
        return {
            SetPoint = function() end, SetJustifyH = function() end, SetTextColor = function() end,
            SetFontObject = function() end, SetText = function(self, text) self.text = text end,
        }
    end
    frame.Text = fontString()
    function frame:CreateFontString() return fontString() end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetHeight(height) self.height = height end
    function frame:SetWidth(width) self.width = width end
    function frame:GetWidth() return self.width or 580 end
    function frame:SetBackdrop(value) self.backdrop = value end
    function frame:SetBackdropColor() end
    function frame:SetBackdropBorderColor() end
    function frame:SetScrollChild(child) self.scrollChild = child end
    function frame:SetChecked(value) self.checked = value end
    function frame:GetChecked() return self.checked end
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
    function frame:RegisterUnitEvent(event, unit)
        assert(unit == 'player')
        self:RegisterEvent(event)
    end
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
test('feature glows selected button when only Judgement is ready', function()
    addon.Config.Initialize()
    addon.Config.Set('holyStrikeBar', 1)
    addon.Config.Set('holyStrikeButton', 1)
    cooldowns = { [1] = cooling(), [2] = ready() }

    addon.HolyStrikeGlow:Refresh(true)

    equal(overlays[button].visible, true)
end)
test('feature retains selected position when macro moves away', function()
    button.action = 2

    addon.HolyStrikeGlow:Refresh(true)

    equal(overlays[button].visible, true)
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
local settingsByVariable = {}
local openedCategory
_G.Settings = {
    VarType = { Boolean = 'boolean', String = 'string', Number = 'number' },
    RegisterCanvasLayoutCategory = function(canvas, name)
        return { GetID = function() return 42 end }
    end,
    RegisterVerticalLayoutCategory = function(name)
        return { GetID = function() return 42 end }
    end,
    RegisterProxySetting = function(category, variable, valueType, name, default, getter, setter)
        local setting = { GetValue = getter, SetValue = function(_, value) setter(value) end }
        settingsByVariable[variable] = setting
        return setting
    end,
    CreateCheckbox = function(category, setting)
        settingsControls[#settingsControls + 1] = setting
    end,
    CreateColorSwatch = function(category, setting)
        settingsControls[#settingsControls + 1] = setting
    end,
    CreateDropdown = function(category, setting, options)
        setting.options = options()
        settingsControls[#settingsControls + 1] = setting
    end,
    CreateControlTextContainer = function()
        local data = {}
        return {
            Add = function(_, value, label) data[#data + 1] = { value = value, label = label } end,
            GetData = function() return data end,
        }
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) openedCategory = id end,
}

local menuItems = {}
_G.UIDropDownMenu_SetWidth = function(frame, width) frame.menuWidth = width end
_G.UIDropDownMenu_Initialize = function(frame, callback)
    frame.menuInitializer = callback
    menuItems = {}
    callback()
end
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function(info) menuItems[#menuItems + 1] = info end
_G.UIDropDownMenu_SetText = function(frame, text) frame.menuText = text end
-- Blizzard refreshes labels/checks using the last shared popup menu, even
-- when SetSelectedValue is called on a different dropdown frame.
_G.UIDropDownMenu_SetSelectedValue = function(frame, value)
    frame.selectedValue = value
    frame.menuText = 'Custom'
    for _, item in ipairs(menuItems) do
        item.checked = item.value == value
        if item.checked then
            frame.menuText = item.text
        end
    end
end
_G.ColorPickerFrame = {
    SetupColorPickerAndShow = function(self, options) self.options = options end,
    GetColorRGB = function() return 1, 0, 0 end,
}

local function loadBootstrap(class, useSavedSelection)
    -- Existing behavior tests use an explicitly selected main-bar button.
    -- Selection default/migration tests opt out to exercise real saved data.
    if not useSavedSelection then
        _G.PaladinAssistForeverDB = _G.PaladinAssistForeverDB or {}
        if _G.PaladinAssistForeverDB.holyStrikeBar == nil then
            _G.PaladinAssistForeverDB.holyStrikeBar = 1
        end
        if _G.PaladinAssistForeverDB.holyStrikeButton == nil then
            _G.PaladinAssistForeverDB.holyStrikeButton = 1
        end
    end

    local instance = {}
    _G.UnitClass = function() return class, class end
    _G.SlashCmdList = {}
    for line in io.lines('PaladinAssistForever/PaladinAssistForever.toc') do
        if line:match('%.lua$') and not line:match('^Libs/') then
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
    local checkbox = settingsByVariable.PaladinAssistForever_CooldownGlowEnabled

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
    equal(settingsByVariable.PaladinAssistForever_CooldownGlowEnabled:GetValue(), false)
    equal(_G.PaladinAssistForeverDB.futureOption, 'keep')
    equal(overlays[button].visible, false)
end)
test('re-enabling retains selected position after macro moves', function()
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    button.action = 2
    _G.ActionButton2.action = 1

    settingsByVariable.PaladinAssistForever_CooldownGlowEnabled:SetValue(true)

    equal(overlays[_G.ActionButton2].visible, false)
    equal(overlays[button].visible, true)
    button.action = 1
    _G.ActionButton2.action = 2
end)
test('disabling feature preserves glow owned by another feature', function()
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    instance.Glow.Set(button, 'other-feature', true)

    settingsByVariable.PaladinAssistForever_CooldownGlowEnabled:SetValue(false)

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

    settingsByVariable.PaladinAssistForever_CooldownGlowEnabled:SetValue(true)
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
    settingsByVariable.PaladinAssistForever_CooldownGlowEnabled:SetValue(false)
    cooldowns = { [1] = cooling(), [2] = cooling() }
    events.scripts.OnEvent(events, 'SPELL_UPDATE_COOLDOWN')

    settingsByVariable.PaladinAssistForever_CooldownGlowEnabled:SetValue(true)

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

    settingsByVariable.PaladinAssistForever_CooldownGlowEnabled:SetValue(true)

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

test('proc animation starts once while multiple owners keep glow active', function()
    local target = { GetFrameLevel = function() return 1 end }

    addon.Glow.Set(target, 'first', true)
    addon.Glow.Set(target, 'first', true)
    addon.Glow.Set(target, 'second', true)
    addon.Glow.Set(target, 'first', false)

    equal(overlays[target].procStarts, 1)
    equal(overlays[target].procStartAnimation, true)
    equal(overlays[target].procColor, nil)
    equal(overlays[target].procVisible, true)
    equal(overlays[target].procStops, nil)

    addon.Glow.Set(target, 'second', false)
    equal(overlays[target].procStops, 1)
    equal(overlays[target].procVisible, false)
    equal(overlays[target].visible, false)
end)
test('a new glow activation restarts proc effect on the same overlay', function()
    local target = { GetFrameLevel = function() return 1 end }
    addon.Glow.Set(target, 'test', true)
    local overlay = overlays[target]

    addon.Glow.Set(target, 'test', false)
    addon.Glow.Set(target, 'test', true)

    equal(overlays[target], overlay)
    equal(overlay.procStarts, 2)
    equal(overlay.procVisible, true)
    addon.Glow.ClearOwner('test')
end)

test('upgrade preserves disabled setting and defaults to native glow', function()
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false }
    local instance, events = loadBootstrap('PALADIN')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.Config.Get('cooldownGlowEnabled'), false)
    equal(instance.Config.Get('glowNativeColor'), true)
    equal(instance.Config.Get('glowColor'), 'ff00e633')
end)
test('custom color and native mode update an already active glow', function()
    playerInCombat = true
    _G.PaladinAssistForeverDB = nil
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    local overlay = overlays[button]

    settingsByVariable.PaladinAssistForever_GlowColor:SetValue('00ff0000')
    equal(overlay.procColor, nil)
    settingsByVariable.PaladinAssistForever_GlowNativeColor:SetValue(false)

    equal(overlay.procColor[1], 1)
    equal(overlay.procColor[2], 0)
    equal(overlay.procColor[3], 0)
    equal(overlay.procColor[4], 1)
    equal(overlay.procVisible, true)
    equal(instance.Config.Get('glowColor'), 'ffff0000')

    settingsByVariable.PaladinAssistForever_GlowNativeColor:SetValue(true)
    equal(overlay.procColor, nil)
    equal(overlay.procVisible, true)
    equal(instance.Config.Get('glowColor'), 'ffff0000')
end)
test('saved custom appearance survives a reload', function()
    playerInCombat = true
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = true, glowNativeColor = false, glowColor = 'ff0000ff' }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(overlays[button].procColor[1], 0)
    equal(overlays[button].procColor[2], 0)
    equal(overlays[button].procColor[3], 1)
end)
test('color picker cancel restores prior custom color', function()
    playerInCombat = true
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = true, glowNativeColor = false, glowColor = 'ff0000ff' }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    local picker = settingsByVariable.PaladinAssistForever_GlowColor
    local previous = picker:GetValue()

    picker:SetValue('00ff0000')
    picker:SetValue(previous)

    equal(overlays[button].procColor[3], 1)
    equal(overlays[button].procColor[1], 0)
    equal(instance.Config.Get('glowNativeColor'), false)
end)
test('invalid saved color recovers to a valid default', function()
    _G.PaladinAssistForeverDB = { glowNativeColor = false, glowColor = 'invalid' }
    local instance, events = loadBootstrap('PALADIN')

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.Config.Get('glowColor'), 'ff00e633')
end)
test('appearance changes do not enable a disabled glow', function()
    _G.PaladinAssistForeverDB = { cooldownGlowEnabled = false }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    settingsByVariable.PaladinAssistForever_GlowNativeColor:SetValue(false)
    settingsByVariable.PaladinAssistForever_GlowColor:SetValue('ffff0000')

    equal(overlays[button].visible, false)
    equal(instance.Config.Get('cooldownGlowEnabled'), false)
end)


-- Seal events must be observed even with the reminder disabled or out of combat.
local function sealFixture(settings)
    now = 100
    playerInCombat = true
    _G.PaladinAssistForeverDB = settings or { cooldownGlowEnabled = false, sealBar = 1, sealButton = 2 }
    local original = C_Spell.GetSpellInfo
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    instance.Client.SpellName = function(id)
        if rawequal(id, secret) then error('secret spell ID reached spell lookup') end
        if id == 3 or id == 4 then return 'Seal of Righteousness' end
        if id == 5 then return 'Seal of Command' end
        if id == 6 then return secret end
        return original(id) and original(id).name
    end

    local function cast(id, unit)
        events.scripts.OnEvent(events, 'UNIT_SPELLCAST_SUCCEEDED', unit or 'player', secret, id)
    end
    local function tick(time)
        now = time
        events.scripts.OnUpdate(events, 0.1)
    end

    return instance, events, cast, tick, overlays[ActionButton2]
end

test('seal defaults enabled and red on bottom right bar', function()
    local instance = sealFixture({ cooldownGlowEnabled = false })

    equal(instance.Config.Get('sealGlowEnabled'), true)
    equal(instance.Config.Get('sealGlowColor'), 'ffff0000')
    equal(instance.Config.Get('sealBar'), 3)
    equal(overlays[ActionButton1].visible, false)
    equal(overlays[ActionButton2].visible, false)
end)
test('seal reminder starts due then appears at exactly 26 seconds after cast', function()
    local instance, events, cast, tick, overlay = sealFixture()
    equal(overlay.visible, true)
    equal(overlay.procColor[1], 1)
    equal(overlay.procColor[2], 0)
    equal(overlay.procColor[3], 0)

    cast(3)
    equal(overlay.visible, false)
    tick(125.99)
    equal(overlay.visible, false)
    tick(126)
    equal(overlay.visible, true)
    tick(135)
    equal(overlay.visible, true)
    equal(overlays[ActionButton1].visible, false)
end)
test('different seal and another rank restart the timer', function()
    local instance, events, cast, tick, overlay = sealFixture()
    cast(3)
    tick(120)
    cast(5)
    tick(127)
    equal(overlay.visible, false)
    tick(147)
    equal(overlay.visible, true)

    cast(4)
    equal(overlay.visible, false)
    tick(174)
    equal(overlay.visible, true)
end)
test('unrelated and other-unit casts do not restart seal timer', function()
    local instance, events, cast, tick, overlay = sealFixture()
    cast(3)
    tick(120)
    cast(1)
    cast(5, 'party1')
    events.scripts.OnEvent(events, 'UNIT_SPELLCAST_START', 'player', 'guid', 3)

    tick(127)

    equal(overlay.visible, true)
end)
test('secret cast unit ID and spell name are ignored without inspecting them', function()
    local instance, events, cast, tick, overlay = sealFixture()
    cast(3)
    tick(120)
    cast(secret)
    cast(5, secret)
    cast(6)

    tick(127)

    equal(overlay.visible, true)
end)
test('seal cast outside combat is tracked and combat exit keeps timer', function()
    local instance, events, cast, tick, overlay = sealFixture()
    playerInCombat = false
    events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')
    equal(overlay.visible, false)
    cast(3)
    tick(120)
    playerInCombat = true
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')
    equal(overlay.visible, false)

    tick(127)
    equal(overlay.visible, true)
    playerInCombat = false
    events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')
    equal(overlay.visible, false)
    tick(140)
    equal(overlay.visible, false)
end)
test('disabled seal reminder keeps observing casts', function()
    local instance, events, cast, tick, overlay = sealFixture()
    instance.Config.Set('sealGlowEnabled', false)
    equal(overlay.visible, false)
    cast(3)
    tick(120)
    equal(overlay.visible, false)

    instance.Config.Set('sealGlowEnabled', true)
    equal(overlay.visible, false)
    tick(127)
    equal(overlay.visible, true)
end)
test('changing selected button clears old glow immediately', function()
    local instance, events, cast, tick, overlay = sealFixture()

    settingsByVariable.PaladinAssistForever_SealButton:SetValue(1)

    equal(overlay.visible, false)
    equal(overlays[ActionButton1].visible, true)
    settingsByVariable.PaladinAssistForever_SealBar:SetValue(0)
    equal(overlays[ActionButton1].visible, false)
end)
test('hidden selected button does not glow', function()
    local instance, events, cast, tick, overlay = sealFixture()
    local old = ActionButton2.IsVisible
    ActionButton2.IsVisible = function() return false end

    tick(101)
    ActionButton2.IsVisible = old

    equal(overlay.visible, false)
end)
test('death discards an observed seal timer', function()
    local instance, events, cast, tick, overlay = sealFixture()
    cast(3)
    playerInCombat = false
    events.scripts.OnEvent(events, 'PLAYER_DEAD')
    playerInCombat = true

    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')

    equal(overlay.visible, true)
end)
test('seal takes color priority on shared button then restores Holy Strike glow', function()
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events, cast, tick = sealFixture({ sealBar = 1, sealButton = 1 })
    local overlay = overlays[button]
    equal(overlay.procColor[1], 1)
    equal(overlay.procColor[2], 0)

    cast(3)

    equal(overlay.visible, true)
    equal(overlay.procColor, nil)
    tick(127)
    equal(overlay.procColor[2], 0)
    instance.Config.Set('sealGlowEnabled', false)
    equal(overlay.visible, true)
    equal(overlay.procColor, nil)
end)
test('seal color settings are independent and apply immediately', function()
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events, cast, tick, overlay = sealFixture({ sealBar = 1, sealButton = 2 })

    settingsByVariable.PaladinAssistForever_SealGlowColor:SetValue('000000ff')

    equal(overlay.procColor[3], 1)
    equal(overlay.procColor[1], 0)
    equal(overlays[button].procColor, nil)
    equal(instance.Config.Get('sealGlowColor'), 'ff0000ff')
end)
test('invalid saved button selection and seal color recover safely', function()
    local instance = sealFixture({ cooldownGlowEnabled = false, sealBar = 9, sealButton = 1.5, sealGlowColor = 'bad' })

    equal(instance.Config.Get('sealBar'), 3)
    equal(instance.Config.Get('sealButton'), 4)
    equal(instance.Config.Get('sealGlowColor'), 'ffff0000')
end)
test('button selector exposes supported bars and twelve positions', function()
    local instance = sealFixture()

    equal(#instance.SettingsPanel.controls.sealBar.options, 9)
    equal(#instance.SettingsPanel.controls.sealButton.options, 12)
    equal(instance.Buttons.Selected(1, 2), ActionButton2)
    equal(instance.Buttons.Selected(0, 2), nil)
    equal(instance.Buttons.Selected(1, 13), nil)
end)


test('saved seal target and color survive reload with timer initially due', function()
    local instance, events, cast = sealFixture({ cooldownGlowEnabled = false,
        sealBar = 1, sealButton = 2, sealGlowColor = 'ff0000ff' })
    cast(3)
    equal(overlays[ActionButton2].visible, false)

    local reloaded, reloadEvents = loadBootstrap('PALADIN')
    reloadEvents.scripts.OnEvent(reloadEvents, 'PLAYER_LOGIN')

    equal(reloaded.Config.Get('sealBar'), 1)
    equal(reloaded.Config.Get('sealButton'), 2)
    equal(overlays[ActionButton2].visible, true)
    equal(overlays[ActionButton2].procColor[3], 1)
end)
test('reusable timers keep independent deadlines and clear to due', function()
    local instance = sealFixture()
    local first = instance.Timers.New()
    local second = instance.Timers.New()
    equal(first:IsDue(), true)

    first:Start(10)
    second:Start(20)
    now = 110

    equal(first:IsDue(), true)
    equal(second:IsDue(), false)
    equal(second:Remaining(), 10)
    second:Clear()
    equal(second:IsDue(), true)
    equal(second:Remaining(), 0)
end)
test('manual bar selection resolves each default bar without spell lookup', function()
    local instance = sealFixture()
    local names = { 'MultiBarBottomLeftButton', 'MultiBarBottomRightButton',
        'MultiBarRightButton', 'MultiBarLeftButton', 'MultiBar5Button',
        'MultiBar6Button', 'MultiBar7Button' }

    for index, name in ipairs(names) do
        local target = {}
        local previous = _G[name .. '12']
        _G[name .. '12'] = target

        local resolved = instance.Buttons.Selected(index + 1, 12)
        _G[name .. '12'] = previous

        equal(resolved, target)
    end
end)

local function contextFixture()
    unitDead = {}
    unitPresence = {}
    unitAttackable = { target = true, mouseover = true }
    cooldowns = { [1] = ready(), [2] = ready() }
    local instance, events, cast, tick = sealFixture({ sealBar = 1, sealButton = 2 })
    playerInCombat = false
    events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')

    return instance, events, cast, tick
end

test('target selection shows only the due seal glow outside combat', function()
    local instance, events = contextFixture()
    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
    equal(events.events.PLAYER_TARGET_CHANGED, true)

    unitPresence.target = true
    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)

    unitPresence.target = nil
    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
end)
test('mouseover shows only the due seal glow and polling handles departure', function()
    local instance, events, cast, tick = contextFixture()
    equal(events.events.UPDATE_MOUSEOVER_UNIT, true)

    unitPresence.mouseover = true
    events.scripts.OnEvent(events, 'UPDATE_MOUSEOVER_UNIT')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)

    unitPresence.mouseover = nil
    tick(101)

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
end)
test('target and mouseover do not bypass cooldowns seal timer or toggles', function()
    local instance, events, cast, tick = contextFixture()
    unitPresence.target = true
    unitPresence.mouseover = true
    cooldowns = { [1] = cooling(), [2] = cooling() }
    cast(3)

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)

    tick(127)
    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)
    instance.Config.Set('cooldownGlowEnabled', false)
    instance.Config.Set('sealGlowEnabled', false)

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
    unitPresence = {}
end)
test('losing target retains mouseover visibility and combat needs neither', function()
    local instance, events = contextFixture()
    unitPresence.target = true
    unitPresence.mouseover = true
    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')
    unitPresence.target = nil

    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)
    playerInCombat = true
    unitPresence = {}
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')

    equal(overlays[button].visible, true)
    equal(overlays[ActionButton2].visible, true)
end)
test('restricted target existence is ignored while readable mouseover still works', function()
    local instance, events, cast, tick = contextFixture()
    unitPresence.target = secret

    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
    unitPresence.mouseover = true
    events.scripts.OnEvent(events, 'UPDATE_MOUSEOVER_UNIT')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)
    unitPresence = {}
end)

test('friendly target and mouseover never enable glows outside combat', function()
    local instance, events = contextFixture()
    unitPresence = { target = true, mouseover = true }
    unitAttackable = { target = false, mouseover = false }

    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
    unitPresence = {}
end)
test('attackable mouseover enables seal glow even with a friendly selected target', function()
    local instance, events = contextFixture()
    unitPresence = { target = true, mouseover = true }
    unitAttackable.target = false

    events.scripts.OnEvent(events, 'UPDATE_MOUSEOVER_UNIT')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)
    unitPresence = {}
end)
test('losing attackability hides seal glow on polling', function()
    local instance, events, cast, tick = contextFixture()
    unitPresence.target = true
    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')
    equal(overlays[button].visible, false)

    unitAttackable.target = false
    tick(101)

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
    unitPresence = {}
end)
test('restricted attackability is not treated as permission to show a glow', function()
    local instance, events = contextFixture()
    unitPresence.target = true
    unitAttackable.target = secret

    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
    unitPresence = {}
end)

test('combat exit hides Holy Strike but retains due seal with attackable target', function()
    local instance, events = contextFixture()
    unitPresence.target = true
    playerInCombat = true
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')
    equal(overlays[button].visible, true)
    equal(overlays[ActionButton2].visible, true)

    playerInCombat = false
    events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)
    unitPresence = {}
end)

test('seal starts without flash outside combat and flashes on a fresh combat activation', function()
    local instance, events, cast, tick = contextFixture()
    unitPresence.target = true
    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[ActionButton2].procStartAnimation, false)
    playerInCombat = true
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')
    cast(3)
    tick(127)

    equal(overlays[ActionButton2].procStartAnimation, true)
    equal(overlays[button].procStartAnimation, true)
    unitPresence = {}
end)
test('leaving combat switches a visible seal glow to no-flash mode', function()
    local instance, events = contextFixture()
    unitPresence.target = true
    playerInCombat = true
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')
    equal(overlays[ActionButton2].procStartAnimation, true)

    playerInCombat = false
    events.scripts.OnEvent(events, 'PLAYER_REGEN_ENABLED')

    equal(overlays[ActionButton2].visible, true)
    equal(overlays[ActionButton2].procStartAnimation, false)
    equal(overlays[button].visible, false)
    unitPresence = {}
end)

test('Holy Strike upgrade supplies bottom right selection and preserves appearance', function()
    _G.PaladinAssistForeverDB = { glowNativeColor = false, glowColor = 'ff0000ff' }
    cooldowns = { [1] = ready(), [2] = ready() }
    playerInCombat = true
    local instance, events = loadBootstrap('PALADIN', true)

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.Config.Get('holyStrikeBar'), 3)
    equal(instance.Config.Get('holyStrikeButton'), 3)
    equal(instance.Config.Get('glowColor'), 'ff0000ff')
    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, false)
end)
test('Holy Strike selector moves one glow immediately without automatic discovery', function()
    local instance, events = contextFixture()
    playerInCombat = true
    instance.Config.Set('sealGlowEnabled', false)
    instance.Buttons.FindSpell = function() error('automatic discovery must not run') end
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')
    equal(overlays[button].visible, true)

    settingsByVariable.PaladinAssistForever_HolyStrikeButton:SetValue(2)

    equal(overlays[button].visible, false)
    equal(overlays[ActionButton2].visible, true)
    settingsByVariable.PaladinAssistForever_HolyStrikeBar:SetValue(0)
    equal(overlays[ActionButton2].visible, false)
end)
test('Holy Strike selection persists and hidden selected buttons do not glow', function()
    _G.PaladinAssistForeverDB = { holyStrikeBar = 1, holyStrikeButton = 2 }
    cooldowns = { [1] = ready(), [2] = ready() }
    playerInCombat = true
    local instance, events = loadBootstrap('PALADIN', true)
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    equal(overlays[ActionButton2].visible, true)
    equal(overlays[button].visible, false)
    local visible = ActionButton2.IsVisible
    ActionButton2.IsVisible = function() return false end

    events.scripts.OnUpdate(events, 0.1)
    ActionButton2.IsVisible = visible

    equal(overlays[ActionButton2].visible, false)
    equal(instance.Config.Get('holyStrikeButton'), 2)
end)
test('invalid Holy Strike selection falls back to bottom right button three', function()
    _G.PaladinAssistForeverDB = { holyStrikeBar = 99, holyStrikeButton = 0 }
    local instance, events = loadBootstrap('PALADIN', true)

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.Config.Get('holyStrikeBar'), 3)
    equal(instance.Config.Get('holyStrikeButton'), 3)
    equal(#instance.SettingsPanel.controls.holyStrikeBar.options, 9)
    equal(#instance.SettingsPanel.controls.holyStrikeButton.options, 12)
end)

test('settings groups contain their own controls and update saved values', function()
    _G.PaladinAssistForeverDB = nil
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    local panel = instance.SettingsPanel
    local controls = panel.controls
    equal(#panel.sections, 2)
    equal(panel.sections[1].backdrop.edgeSize, 1)
    equal(panel.sections[2].backdrop.edgeSize, 1)
    equal(controls.holyStrikeBar.parent, panel.sections[1])
    equal(controls.sealBar.parent, panel.sections[2])

    controls.cooldownGlowEnabled:SetChecked(false)
    controls.cooldownGlowEnabled.scripts.OnClick(controls.cooldownGlowEnabled)

    equal(instance.Config.Get('cooldownGlowEnabled'), false)
    equal(controls.cooldownGlowEnabled:GetChecked(), false)
    equal(instance.Config.Get('sealGlowEnabled'), true)

    menuItems = {}
    controls.holyStrikeButton.menuInitializer()
    menuItems[4].func()

    equal(instance.Config.Get('holyStrikeButton'), 4)
    equal(controls.holyStrikeButton.selectedValue, 4)
    equal(controls.holyStrikeButton.menuText, 'Button 4')
end)
test('custom panel color picker applies RGB and cancel restores saved color', function()
    _G.PaladinAssistForeverDB = { glowColor = 'ff0000ff', glowNativeColor = true }
    local instance, events = loadBootstrap('PALADIN')
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    local control = instance.SettingsPanel.controls.glowColor

    control.scripts.OnClick(control)
    ColorPickerFrame.options.swatchFunc()

    equal(instance.Config.Get('glowColor'), 'ffff0000')
    equal(instance.Config.Get('glowNativeColor'), true)
    ColorPickerFrame.options.cancelFunc()
    equal(instance.Config.Get('glowColor'), 'ff0000ff')
end)

test('seal delay defaults to 26 and updates a running timer from its original cast', function()
    local instance, events, cast, tick, overlay = sealFixture()
    equal(instance.Config.Get('sealReminderSeconds'), 26)
    cast(3)
    tick(120)
    equal(overlay.visible, false)

    settingsByVariable.PaladinAssistForever_SealReminderSeconds:SetValue(20)

    equal(overlay.visible, true)
    instance.Config.Set('sealReminderSeconds', 30)
    equal(overlay.visible, false)
    tick(129.99)
    equal(overlay.visible, false)
    tick(130)
    equal(overlay.visible, true)
end)
test('seal delay dropdown saves choice and casts use that duration', function()
    local instance, events, cast, tick, overlay = sealFixture()
    local dropdown = instance.SettingsPanel.controls.sealReminderSeconds
    menuItems = {}
    dropdown.menuInitializer()

    menuItems[24].func()
    cast(3)
    tick(123.99)

    equal(overlay.visible, false)
    tick(124)
    equal(overlay.visible, true)
    equal(instance.Config.Get('sealReminderSeconds'), 24)
    equal(dropdown.menuText, '24 seconds')
    local reloaded, reloadEvents = loadBootstrap('PALADIN')
    reloadEvents.scripts.OnEvent(reloadEvents, 'PLAYER_LOGIN')
    equal(reloaded.Config.Get('sealReminderSeconds'), 24)
end)
test('invalid saved seal duration defaults to 26 and cannot be set out of range', function()
    local instance = sealFixture({ sealReminderSeconds = 31 })

    equal(instance.Config.Get('sealReminderSeconds'), 26)
    equal(pcall(instance.Config.Set, 'sealReminderSeconds', 0), false)
    equal(pcall(instance.Config.Set, 'sealReminderSeconds', 2.5), false)
    equal(instance.Config.Get('sealReminderSeconds'), 26)
end)

test('dropdown captions stay independent of the shared seconds popup', function()
    _G.PaladinAssistForeverDB = { holyStrikeBar = 2, holyStrikeButton = 4,
        sealBar = 1, sealButton = 7, sealReminderSeconds = 26 }
    local instance, events = loadBootstrap('PALADIN', true)
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    local controls = instance.SettingsPanel.controls

    equal(controls.holyStrikeBar.menuText, 'Bottom left bar')
    equal(controls.holyStrikeButton.menuText, 'Button 4')
    equal(controls.sealBar.menuText, 'Main bar')
    equal(controls.sealButton.menuText, 'Button 7')
    equal(controls.sealReminderSeconds.menuText, '26 seconds')

    menuItems = {}
    controls.sealReminderSeconds.menuInitializer()
    menuItems[24].func()
    instance.SettingsPanel.canvas.scripts.OnShow()

    equal(controls.holyStrikeBar.menuText, 'Bottom left bar')
    equal(controls.holyStrikeButton.menuText, 'Button 4')
    equal(controls.sealBar.menuText, 'Main bar')
    equal(controls.sealButton.menuText, 'Button 7')
    equal(controls.sealReminderSeconds.menuText, '24 seconds')
    equal(instance.Config.Get('holyStrikeBar'), 2)
end)
test('refreshing other settings does not change the open menu checkmarks', function()
    _G.PaladinAssistForeverDB = { holyStrikeBar = 2, sealReminderSeconds = 26 }
    local instance, events = loadBootstrap('PALADIN', true)
    events.scripts.OnEvent(events, 'PLAYER_LOGIN')
    local controls = instance.SettingsPanel.controls
    menuItems = {}
    controls.holyStrikeBar.menuInitializer()
    equal(menuItems[3].checked, true)

    instance.Config.Set('sealReminderSeconds', 24)

    equal(menuItems[3].checked, true)
    equal(menuItems[2].checked, false)
    equal(controls.holyStrikeBar.menuText, 'Bottom left bar')
    equal(controls.sealReminderSeconds.menuText, '24 seconds')
end)

test('lost saved settings restore bottom right buttons three and four', function()
    _G.PaladinAssistForeverDB = nil
    playerInCombat = true
    cooldowns = { [1] = ready(), [2] = ready() }
    local holy = { GetFrameLevel = function() return 1 end, IsVisible = function() return true end }
    local seal = { GetFrameLevel = function() return 1 end, IsVisible = function() return true end }
    _G.MultiBarBottomRightButton3 = holy
    _G.MultiBarBottomRightButton4 = seal
    local instance, events = loadBootstrap('PALADIN', true)

    events.scripts.OnEvent(events, 'PLAYER_LOGIN')

    equal(instance.HolyStrikeGlow.button, holy)
    equal(instance.SealReminder.button, seal)
    equal(overlays[holy].visible, true)
    equal(overlays[seal].visible, true)
    equal(instance.SettingsPanel.controls.holyStrikeBar.menuText, 'Bottom right bar')
    equal(instance.SettingsPanel.controls.holyStrikeButton.menuText, 'Button 3')
    equal(instance.SettingsPanel.controls.sealBar.menuText, 'Bottom right bar')
    equal(instance.SettingsPanel.controls.sealButton.menuText, 'Button 4')
    _G.MultiBarBottomRightButton3 = nil
    _G.MultiBarBottomRightButton4 = nil
end)

test('dead enemy target stops seal glow outside combat on polling', function()
    local instance, events, cast, tick = contextFixture()
    unitPresence.target = true
    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')
    equal(overlays[ActionButton2].visible, true)

    unitDead.target = true
    tick(101)

    equal(overlays[ActionButton2].visible, false)
    equal(overlays[button].visible, false)
end)
test('dead enemy mouseover does not trigger seal but a living target does', function()
    local instance, events = contextFixture()
    unitPresence.mouseover = true
    unitDead.mouseover = true

    events.scripts.OnEvent(events, 'UPDATE_MOUSEOVER_UNIT')

    equal(overlays[ActionButton2].visible, false)
    unitPresence.target = true
    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')
    equal(overlays[ActionButton2].visible, true)
end)
test('dead target permits living mouseover and does not suppress combat reminders', function()
    local instance, events = contextFixture()
    unitPresence.target = true
    unitDead.target = true
    unitPresence.mouseover = true
    events.scripts.OnEvent(events, 'UPDATE_MOUSEOVER_UNIT')
    equal(overlays[ActionButton2].visible, true)

    unitDead.mouseover = true
    playerInCombat = true
    events.scripts.OnEvent(events, 'PLAYER_REGEN_DISABLED')

    equal(overlays[ActionButton2].visible, true)
    equal(overlays[button].visible, true)
end)
test('unreadable death state cannot trigger an out of combat seal glow', function()
    local instance, events = contextFixture()
    unitPresence.target = true
    unitDead.target = secret

    events.scripts.OnEvent(events, 'PLAYER_TARGET_CHANGED')

    equal(overlays[ActionButton2].visible, false)
end)

print(string.format('\n%d passed; %d failed', passed, failed))
os.exit(failed == 0 and 0 or 1)
