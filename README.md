# Paladin Assist Forever

An expandable, paladin-only addon for WoW Forever. Version 0.2.1 provides a golden glow to the default action-bar button containing Holy Strike only while you are **in combat** and **Judgement OR Holy Strike is off cooldown**. The same button glows for both spells; a separate Judgement button is not highlighted.

Mana, target and range are ignored. The global cooldown is ignored when the client provides enough information to distinguish it from the spell cooldown. The glow is enabled by default and can be disabled in the settings panel.

## Install

1. Extract `dist/PaladinAssistForever-0.2.1.zip` into your WoW Forever client's `Interface/AddOns` directory, or copy the repository's `PaladinAssistForever` folder there.
2. Check the resulting path is `Interface/AddOns/PaladinAssistForever/PaladinAssistForever.toc` (no extra nested directory).
3. Enable **Paladin Assist Forever** in the character-selection AddOns menu, then log in as a paladin. If installing while the game is running, restart the client if the addon does not appear.
4. Put this macro on a default action bar:

```text
#showtooltip holy strike
/cast judgement
/cast holy strike
/startattack
```

The macro name can be anything, but use a unique name across account and character macros. Keep the `#` in `#showtooltip`; do not add a backslash before it.

The addon finds the button automatically, including when you move the macro or change bar pages. Multiple visible placements all glow. A direct Holy Strike spell button also matches. The first version supports English spell names and simple `/cast Spell` lines, including rank suffixes and case differences. Conditional macros, `/castsequence`, third-party action bars, pet bars and vehicle bars are outside this version's scope.

## Configuration

Open **Settings → AddOns → Paladin Assist Forever**, or type `/paf config`.

- **Enable cooldown glow** is checked by default.
- Unchecking it immediately removes this feature's glow and stops its cooldown/button checks.
- Checking it again immediately discovers the current macro position and reevaluates readiness. The glow stays hidden outside combat, appears on entering combat if either spell is ready, and clears immediately when combat ends.
- The preference is saved account-wide across reloads and logouts. Existing installations default to enabled on upgrade.
- The panel is available on all characters; the glow feature still runs only for paladins.

## Diagnostics

Type `/paf` to print the client build/interface, number of matching buttons, spell IDs and current cooldown states. Zero matching buttons means the macro is not on a visible supported bar or its cast lines did not match. Give macros unique names: on clients that expose a macro's displayed spell ID instead of its macro index, discovery resolves the macro body by name.

The manifest targets interface **16001**. If a later beta marks it outdated, compare the fourth value printed by `/run print(GetBuildInfo())` with the TOC's `## Interface` line before updating the manifest. Merely changing that number does not validate compatibility with API changes.

Cooldown APIs can return restricted values in combat. The service uses public state flags where available, retains event-authoritative GCD state between updates, and never performs arithmetic on secret values. Missing or unreadable data never independently triggers a glow. A readable, ready companion spell can still trigger it. A newly created button encountered in combat waits until combat ends to receive its overlay.

## Reuse and extension

Every file receives the private addon namespace through `local _, addon = ...`. Services contain no paladin spell names. Only `Features/HolyStrikeGlow.lua` defines the current spell-specific rule.

| Module | Reusable interface | Responsibility |
| --- | --- | --- |
| `Services/Client.lua` | `SpellID(name)`, `SpellName(id)`, `IsKnown(id)`, `Cooldown(id)`, `Action(slot)`, `Readable(value)` | Adapts modern APIs and available legacy equivalents; isolates client changes. |
| `Services/Macros.lua` | `Casts(body, spellName)` | Exact, case-insensitive matching of simple cast lines; never executes macros. |
| `Services/Buttons.lua` | `All()`, `FindSpell(spellName)` | Enumerates default buttons and resolves current slots, including macros and paging. |
| `Services/Glow.lua` | `Prepare(button)`, `Set(button, owner, active)`, `ClearOwner(owner)` | Reuses addon-owned overlays. Multiple features may own one glow; one owner cannot clear another's request. |
| `Services/Cooldowns.lua` | `IsReady(spellID, cooldownEvent)`, `AnyReady(spellIDs, cooldownEvent)`, `Invalidate(spellID)` | Evaluates ordinary, non-charge spell cooldowns. `IsReady` returns true, false, or nil for unavailable data; `AnyReady` returns a boolean. |
| `Services/Config.lua` | `Initialize()`, `Get(key)`, `Set(key, value)`, `Subscribe(listener)` | Saves typed defaults and preferences; notifies consumers when a setting changes. |
| `SettingsPanel.lua` | `Initialize()`, `Open()` | Registers the native AddOns settings category and checkbox. |
| `Core.lua` | `RegisterFeature(feature)` | Starts paladin features and calls `Refresh(discover, cooldownEvent)` only when their optional `settingKey` is enabled. Calls `Stop()` immediately when disabled. |

A future feature can reuse discovery and rendering without copying them:

```lua
local _, addon = ...
local feature = { owner = "my-feature" }

function feature:Refresh(discover, cooldownEvent)
    -- Evaluate this feature's rule, then request its own glow ownership.
    for _, button in ipairs(addon.Buttons.FindSpell("Holy Strike")) do
        addon.Glow.Set(button, self.owner, true)
    end
end

function feature:Stop()
    addon.Glow.ClearOwner(self.owner)
end

addon:RegisterFeature(feature)
```

For a future configurable feature, add a default in `Services/Config.lua`, set its `settingKey`, implement `Stop()` to release its glow ownership and invalidate cached cooldown snapshots, and register its UI control in `SettingsPanel.lua`. Features without a `settingKey` remain enabled.

Load feature files after the services and before `Bootstrap.lua` in the TOC. Retain and clear previous button matches when a rule's target moves, as the shipped feature does. `Prepare` allocates only out of combat; the core prepares all existing default buttons at login and after combat, even if empty or the feature is disabled. `Set` only changes this addon's overlay visibility, preserving macro contents, action attributes and Blizzard's own proc alerts. Event callbacks refresh promptly; the core polls cooldown expiry every 0.1 seconds and discovery every 0.5 seconds.

## Verification

Run from the repository root with Lua installed:

```sh
lua tests/run.lua
```

The tests run real services and feature code against small WoW API/frame doubles. They cover each OR combination, unknown/unlearned spells, cooldown expiry, GCD-only timing, restricted values, macro matching, live slot paging, shared glow ownership, combat allocation, manifest loading, paladin/non-paladin startup, enabled defaults, saved disabled preferences, immediate checkbox effects, re-enabling after moving the macro, and ownership isolation, combat entry/exit and enabling while outside combat. They do not prove rendering or API behavior inside WoW Forever; in-game testing remains necessary.

In-game acceptance checks:

- Enable Lua errors with `/console scriptErrors 1`, then `/reload`.
- With both spells ready outside combat, confirm there is no glow. Enter combat and confirm the Holy Strike macro button glows. Leave combat and confirm the glow disappears immediately.
- Put both spells on cooldown; confirm the glow disappears. When either finishes first, confirm the same button glows again.
- In combat, check with no target, out of range and without enough mana. After combat the glow must remain hidden regardless of readiness.
- Trigger only the global cooldown while both tracked abilities are otherwise ready; confirm no flicker where the client exposes the distinction.
- Move the macro, change bar pages and reload; confirm no leftover glow on its old slot.
- Log into a non-paladin; confirm no feature updates or glow.
- Open `/paf config`; disable the glow while it is visible and confirm it disappears immediately. Reload and confirm the checkbox remains off. Enable it again and confirm readiness is reflected immediately.
- Report `/paf` output and any Lua error if a beta API differs.

## API references

- [Blizzard spell API source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [Cooldown structure and GCD event contract](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua)
- [Default action button implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua)
- [Forever interface 16001 in an existing addon's repository](https://github.com/TheMizeGuy/WowForeverTwitchEmotes)

- [Native Settings registration API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua)

- [Default action-bar combat visibility handling](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ActionBar/Shared/ActionBar.lua)
