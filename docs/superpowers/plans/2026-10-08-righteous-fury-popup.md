# Righteous Fury Popup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a movable, resizable, shield-only Righteous Fury reminder when the buff is missing or has no more than five minutes remaining.

**Architecture:** A client adapter safely reads a public player aura and off-hand equipment, falling back to an observed-cast timer when aura data is restricted. A reusable popup-icon service owns an unprotected frame and delegates its glow to the existing LibCustomGlow adapter. A paladin feature connects the adapter, timer, popup, and settings.

**Tech Stack:** WoW Forever interface 16001, Lua, native WoW frames and Settings, bundled LibCustomGlow-1.0, existing `lua tests/run.lua` and `lua tests/glow_integration.lua` harnesses.

**Spec:** `docs/superpowers/specs/2026-10-08-righteous-fury-popup-design.md`

## Global Constraints

- The reminder is paladin-only, visual-only, and never casts, targets, or changes an action button.
- Righteous Fury is assumed to last 30 minutes; its default reminder threshold is five minutes before expiration (25 minutes after an observed cast).
- A normal popup requires an equipped shield in off-hand slot 17 and appears in or out of combat; a temporary settings preview is the only exception.
- Default popup size is 64 pixels; size choices cover 32–128 pixels. Position and size are stored in addon settings; aura data and timer state remain session-local.
- Secret aura values must never be compared, formatted, or used in arithmetic. Keep the existing timer, glow, and settings behavior for other reminders.
- Spell discovery follows the addon's existing English-name convention; the popup uses the discovered spell texture or a neutral placeholder until it resolves.
- Use blank lines between logical blocks as required by the repository instructions. Do not introduce automated casting.

## Review Focus

- An item ID may be readable while instant item data is unavailable: hide the popup and recover on a later equipment read (Task 1 test).
- A player aura lookup may return nil or secret data during a restriction: keep the cast estimate instead of treating it as a confirmed missing buff (Tasks 1 and 3 tests).
- The aura may arrive a moment after `UNIT_SPELLCAST_SUCCEEDED`: the popup must not reappear during that gap (Task 3 test).
- A saved popup position may be outside a smaller display: clamp the frame onscreen and keep drag persistence usable (Task 2 test).
- A preview can outlive a setting change unless explicitly cleared: closing settings or disabling the reminder must leave no misleading active glow (Task 4 test).

---

### Task 1: Add shield, spell icon, and guarded player-aura adapters

**Files:**
- Modify: `PaladinAssistForever/Services/Client.lua`
- Test: `tests/run.lua`

**Interfaces:**
- Consumes: `Client.Readable(value)` and WoW's `GetInventoryItemID`, `C_Item.GetItemInfoInstant`, `C_Spell.GetSpellTexture`, `C_Secrets.ShouldSpellAuraBeSecret`, `C_UnitAuras.GetPlayerAuraBySpellID`.
- Produces: `Client.HasShieldEquipped() -> boolean`, `Client.SpellIcon(spellID) -> textureID|string|nil`, and `Client.PlayerAuraExpiration(spellID) -> "present"|"absent"|"unknown", expirationTime|nil`.

- [ ] **Step 1: Write failing adapter tests.** In `tests/run.lua`, provide item, aura, and secrecy doubles and restore changed globals after each test. Assert that an off-hand shield (`INVTYPE_SHIELD`) passes, an off-hand weapon or missing instant item data fails, and unreadable values fail safely. Assert that a readable aura returns its numeric expiration, a readable nil lookup returns `"absent"`, and a secret/rejected lookup returns `"unknown"`. Assert `Client.SpellIcon(8)` returns the mocked texture. Use `pcall` in the test to ensure secret values cannot cause a Lua error. For example:

```lua
test('shield adapter needs shield equipment data', function()
    local oldID, oldItem = GetInventoryItemID, C_Item
    _G.GetInventoryItemID = function(_, slot) equal(slot, 17); return 901 end
    _G.C_Item = { GetItemInfoInstant = function() return 901, nil, nil, 'INVTYPE_SHIELD' end }

    local ok, message = pcall(function()
        equal(addon.Client.HasShieldEquipped(), true)
        _G.C_Item.GetItemInfoInstant = function() return 901, nil, nil, 'INVTYPE_WEAPONOFFHAND' end
        equal(addon.Client.HasShieldEquipped(), false)
        _G.C_Item.GetItemInfoInstant = function() return nil end
        equal(addon.Client.HasShieldEquipped(), false)
    end)

    _G.GetInventoryItemID, _G.C_Item = oldID, oldItem
    assert(ok, message)
end)
```

- [ ] **Step 2: Verify red.** Run `lua tests/run.lua`; expect failures naming missing `HasShieldEquipped`, `SpellIcon`, and `PlayerAuraExpiration` functions, with existing tests still passing.

- [ ] **Step 3: Implement minimal guarded adapters.** Use slot 17 and compare only a readable equipment-location string. Resolve the spell icon through `C_Spell.GetSpellTexture` and a guarded legacy fallback. For aura lookup, return `"unknown"` if the API or spell ID is unavailable, if the per-spell secrecy predicate says secret, or if `pcall` rejects the lookup; when the predicate is absent, attempt lookup only outside combat. Check `Client.Readable(aura)` and `Client.Readable(expirationTime)` before inspecting them. A safely readable nil aura is `"absent"`; a present aura with a nonpositive or unreadable expiration is `"unknown"`. The core branch should have this shape:

```lua
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
```

- [ ] **Step 4: Verify green.** Run `lua tests/run.lua` and `lua tests/glow_integration.lua`; both must pass.
- [ ] **Step 5: Commit.** Commit only `Client.lua` and the adapter tests with message `feat: add safe aura and shield adapters`.

### Task 2: Add a reusable movable popup icon

**Files:**
- Create: `PaladinAssistForever/Services/PopupIcons.lua`
- Modify: `PaladinAssistForever/Services/Glow.lua`
- Modify: `PaladinAssistForever/PaladinAssistForever.toc`
- Test: `tests/run.lua`

**Interfaces:**
- Consumes: `addon.Glow.Prepare(frame, allowInCombat)`, `addon.Glow.Set(frame, owner, active, { startAnim = boolean })`, `UIParent`, and the native frame drag API.
- Produces: `addon.PopupIcons.New(owner, onMoved) -> popup` with `popup.frame`, `popup:SetIcon(texture)`, `popup:SetSize(pixels)`, `popup:SetPosition(x, y)`, and `popup:SetVisible(reminder, preview, flash)`.

- [ ] **Step 1: Write failing popup tests.** Add `Services/PopupIcons` to the initial `files` loader in `tests/run.lua`. Extend the frame double with `SetMovable`, `RegisterForDrag`, `StartMoving`, `StopMovingOrSizing`, `GetCenter`, `GetEffectiveScale`, `GetFrameLevel`, and captured `SetPoint`. Give `UIParent` a center and effective scale. Assert creation yields a 64-pixel frame, `SetVisible(true, false, false)` shows the native glow without a flash, `SetVisible(false, true, false)` shows a static preview with no glow, and `SetVisible(false, false, false)` hides both. Simulate `OnDragStop` and assert center-relative offsets reach `onMoved`. Set a stored position beyond `UIParent` bounds and assert the frame is clamped. Also assert a missing spell texture uses a neutral placeholder, `Glow.Prepare` still refuses a protected action button during combat, and the explicitly unprotected popup can get its overlay in combat.

```lua
test('popup preview is visible without an active glow', function()
    local popup = addon.PopupIcons.New('popup-test', function() end)

    popup:SetVisible(false, true, false)

    equal(popup.frame.visible, true)
    equal(overlays[popup.frame].visible, false)

    popup:SetVisible(false, false, false)
    equal(popup.frame.visible, false)
end)
```

- [ ] **Step 2: Verify red.** Run `lua tests/run.lua`; expect the popup creation test to fail because `addon.PopupIcons` does not exist.

- [ ] **Step 3: Implement the popup service.** Add `Services/PopupIcons.lua` after `Services/Glow.lua` in the TOC. Create a plain `Frame` under `UIParent`, a full-size texture, and left-button drag scripts. `SetSize` keeps the frame square; `SetPosition` anchors its center relative to `UIParent` and clamps it onscreen. On drag stop, convert the frame center to parent-scale, center-relative offsets and call `onMoved(roundedX, roundedY)`. `SetIcon` uses a neutral question-mark texture when spell discovery is pending. `SetVisible` calls `Glow.Set` only for a true reminder, shows the frame for either reminder or preview, and always releases the glow when hiding. Permit `Glow.Prepare(frame, true)` for this unprotected frame while preserving the default combat guard for action buttons. Change the existing signature to `function Glow.Prepare(button, allowInCombat)` and replace its guard with:

```lua
if InCombatLockdown() and not allowInCombat then
    return nil
end
```

- [ ] **Step 4: Verify green.** Run both Lua suites and `git diff --check`.
- [ ] **Step 5: Commit.** Commit the popup service, Glow extension, TOC entry, and popup tests with message `feat: add reusable movable popup icon`.

### Task 3: Connect Righteous Fury aura, timer, shield, and popup

**Files:**
- Create: `PaladinAssistForever/Features/RighteousFuryReminder.lua`
- Modify: `PaladinAssistForever/Services/Config.lua`
- Modify: `PaladinAssistForever/Bootstrap.lua`
- Modify: `PaladinAssistForever/PaladinAssistForever.toc`
- Test: `tests/run.lua`

**Interfaces:**
- Consumes: `Client.PlayerAuraExpiration`, `Client.HasShieldEquipped`, `Client.SpellID`, `Client.SpellIcon`, `Client.SpellName`, `Timers.New`, `PopupIcons.New`, and `Config`.
- Produces: `addon.RighteousFuryReminder` feature with `ApplySettings`, `OnEvent`, `Refresh`, `Stop`, and `SetPreview(boolean)`.

- [ ] **Step 1: Write failing feature tests.** Add a Righteous Fury spell with ID 8 to the spell doubles and build a `righteousFuryFixture` that controls `GetTime`, aura status, shield item data, cast events, and the feature's popup. Assert: a readable buff expiring in 20 minutes stays hidden until exactly five minutes remain; a missing readable buff shows immediately; an observed cast hides until 1,500 seconds later when aura data is secret; a subsequent cast resets that deadline; a secret aura does not erase a previous deadline; an out-of-combat readable buff after reload supplies its actual deadline; a two-second grace prevents a nil aura immediately after cast from re-showing the popup; death makes it due; unequipping a shield hides it and re-equipping reveals an already-due reminder; an unlearned Righteous Fury never appears. Exercise cast observation while the feature is disabled and verify enabling retains timing.

```lua
test('Righteous Fury cast timer becomes due at 25 minutes', function()
    local instance, events, cast, tick, popup = righteousFuryFixture({ aura = 'unknown', shield = true })
    equal(popup.frame.visible, true)

    cast(8)
    equal(popup.frame.visible, false)
    tick(1599.99)
    equal(popup.frame.visible, false)
    tick(1600)
    equal(popup.frame.visible, true)
end)
```

- [ ] **Step 2: Verify red.** Run `lua tests/run.lua`; expect failures because `addon.RighteousFuryReminder` is absent.

- [ ] **Step 3: Implement the feature and defaults.** Add defaults `righteousFuryEnabled=true`, `righteousFuryPopupSize=64`, `righteousFuryPopupX=0`, `righteousFuryPopupY=-160`. Validate size as an integer between 32 and 128 in eight-pixel steps and position as integer offsets within ±4096. Load the feature after Timers and PopupIcons. In `OnEvent`, guard unit and spell ID before comparing the player and the spell name, start a 1,500-second timer on success, and delay absence reconciliation for two seconds. Clear the timer on `PLAYER_DEAD` and schedule an immediate aura check on `PLAYER_REGEN_ENABLED`. Register `PLAYER_EQUIPMENT_CHANGED` in Bootstrap; its normal refresh updates visibility at once. In `Refresh`, discover spell/icon, query accessible aura at most once per second, set the timer to `math.max(0, expirationTime - GetTime() - 300)` when present, clear it when confirmed absent outside the cast grace period, and show the reminder only when enabled, known, shield-equipped, and due. Keep `OnEvent` observing casts while disabled. `SetPreview` can show a static popup even if disabled; `Stop` releases the active glow.

```lua
local status, expiration = addon.Client.PlayerAuraExpiration(self.spellID)
if status == 'present' then
    self.timer:Start(math.max(0, expiration - GetTime() - 300))
elseif status == 'absent' and GetTime() >= self.castGraceUntil then
    self.timer:Clear()
end

local combat = UnitAffectingCombat('player')
local flash = addon.Client.Readable(combat) and not not combat
local due = addon.Client.IsKnown(self.spellID)
    and addon.Client.HasShieldEquipped() and self.timer:IsDue()
self.popup:SetVisible(due, self.preview, flash)
```

- [ ] **Step 4: Verify green.** Run both Lua suites and `git diff --check`.
- [ ] **Step 5: Commit.** Commit the feature, config defaults, event registration, TOC entry, and feature tests with message `feat: remind when Righteous Fury needs refresh`.

### Task 4: Add settings placement controls and release the addon

**Files:**
- Modify: `PaladinAssistForever/Services/SettingsWidgets.lua`
- Modify: `PaladinAssistForever/SettingsPanel.lua`
- Modify: `PaladinAssistForever/PaladinAssistForever.toc`
- Modify: `PaladinAssistForever/Bootstrap.lua`
- Modify: `README.md`
- Test: `tests/run.lua`
- Create: `dist/PaladinAssistForever-0.9.0.zip` (distribution artifact)

**Interfaces:**
- Consumes: `RighteousFuryReminder:SetPreview(boolean)`, the new Config keys, and existing `SettingsWidgets.Dropdown`/`Checkbox`.
- Produces: a bordered Righteous Fury settings group with an enable checkbox, 32–128-pixel size dropdown, and a temporary preview-position button. The addon version becomes 0.9.0.

- [ ] **Step 1: Write failing settings tests.** Add checks that the new checkbox defaults on, size defaults to 64, size changes resize the popup immediately and survive reload, drag offsets are stored, clicking the preview button shows the frame without a glow even without a shield, and closing the settings canvas clears preview. Verify disabling the feature while preview is open never leaves an active glow. Add frame-double `SetText` support for the preview button.

```lua
test('closing settings ends Righteous Fury placement preview', function()
    local instance, events = righteousFuryFixture({ aura = 'present', shield = false })
    local preview = instance.SettingsPanel.controls.righteousFuryPreview

    preview.scripts.OnClick(preview)
    equal(instance.RighteousFuryReminder.popup.frame.visible, true)

    instance.SettingsPanel.canvas.scripts.OnHide(instance.SettingsPanel.canvas)
    equal(instance.RighteousFuryReminder.popup.frame.visible, false)
end)
```

- [ ] **Step 2: Verify red.** Run `lua tests/run.lua`; expect the new settings-control test to fail because the preview control is missing.

- [ ] **Step 3: Implement settings and documentation.** Add a reusable `SettingsWidgets.ActionButton(parent, label, y, onClick, tooltip)` that refreshes its label and supports the existing panel refresh loop. Increase the scroll content height and add a fourth bordered section under Exorcism. Register the enable and size settings using proxy settings; populate size choices every eight pixels from 32 through 128. Wire preview toggle to `RighteousFuryReminder:SetPreview`, clear it in the canvas `OnHide` script, and explain the shield-only normal mode. Update the TOC/diagnostic version to 0.9.0 and add Righteous Fury behavior, setup, and beta limitations to README. The preview button must never cast Righteous Fury.

```lua
local sizes = {}
for pixels = 32, 128, 8 do
    sizes[#sizes + 1] = { value = pixels, label = pixels .. ' pixels' }
end

local size = registerSetting('righteousFuryPopupSize',
    'PaladinAssistForever_RighteousFuryPopupSize', 'Popup size', Settings.VarType.Number)
panel.controls.righteousFuryPopupSize = widgets.Dropdown(section, 'Popup size', -110, size, sizes,
    'Change the movable reminder icon size.')
```

- [ ] **Step 4: Verify green.** Run `lua tests/run.lua`, `lua tests/glow_integration.lua`, `git diff --check`, and Lua syntax checks for all addon files.
- [ ] **Step 5: Package.** Build `dist/PaladinAssistForever-0.9.0.zip` with only the `PaladinAssistForever/` tree and verify every ZIP entry byte-for-byte against the source:

```python
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path('PaladinAssistForever')
files = sorted(path for path in root.rglob('*') if path.is_file() and path.name != '.DS_Store')
output = Path('dist/PaladinAssistForever-0.9.0.zip')

with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for path in files:
        archive.write(path, path.as_posix())

with ZipFile(output) as archive:
    assert sorted(archive.namelist()) == sorted(path.as_posix() for path in files)
    assert all(archive.read(path.as_posix()) == path.read_bytes() for path in files)
```

- [ ] **Step 6: Commit.** Commit the settings, docs, tests, and release metadata with message `feat: configure Righteous Fury popup` (the ignored ZIP stays as a downloadable artifact).

- [ ] **Step 7: Perform final review.** Read the spec and this plan against the final diff, then manually list the in-game checks that cannot run here: existing buff on login, cast in combat, shield swap, drag/resize persistence, and secret aura fallback. Report test counts and the ZIP path without claiming live-client verification.
