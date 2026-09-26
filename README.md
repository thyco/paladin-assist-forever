# Paladin Assist Forever

An expandable, paladin-only addon for WoW Forever. Version 0.8.4 provides an animated Blizzard-style proc glow to one manually selected default action-bar button while you are **in combat** and either **Judgement** or enabled **Holy Strike** is off cooldown. The same button glows for both spells; a separate Judgement button is not highlighted. Exorcism has its own combat-only button glow when a living attackable undead or demon is selected or moused over.

Mana, target and range are ignored. The global cooldown is ignored when the client provides enough information to distinguish it from the spell cooldown. The glow is enabled by default and can be disabled in the settings panel. LibCustomGlow-1.0 and LibStub are bundled; no separate library installation is needed.

## Install

1. Extract `dist/PaladinAssistForever-0.8.4.zip` into your WoW Forever client's `Interface/AddOns` directory, or copy the repository's `PaladinAssistForever` folder there.
2. Check the resulting path is `Interface/AddOns/PaladinAssistForever/PaladinAssistForever.toc` (no extra nested directory).
3. Enable **Paladin Assist Forever** in the character-selection AddOns menu, then log in as a paladin. If installing while the game is running, restart the client if the addon does not appear.
4. Put this macro on a default action bar:

```text
#showtooltip holy strike
/cast judgement
/cast holy strike
/startattack
```

The macro name can be anything. Keep the `#` in `#showtooltip`; do not add a backslash before it.

Open `/paf config` and choose **Action bar** and **Button** in the **Holy Strike / Judgement** group. The default is **Bottom right bar → Button 3**, including when the beta loses saved settings. Existing valid saved selections are preserved. Only your selected visible button glows. It stays at that physical position when spells move or bar pages change, so update the selection if you move your macro. The addon no longer inspects macro contents for this feature. Spell lookup still uses English names. Third-party action bars, pet bars and vehicle bars are outside this version's scope.

## Configuration

Open **Settings → AddOns → Paladin Assist Forever**, or type `/paf config`.

The panel has three bordered groups: **Holy Strike / Judgement**, **Seal reminder**, and **Exorcism**. Each contains its own enable toggle, bar/button selectors and color controls. Scroll when needed; changes apply immediately and existing saved preferences are retained.

- **Holy strike glow on Holy strike and judgement** is checked by default. Its default position is **Bottom right bar → Button 3**; you can change it below the checkbox.
- **Check Holy Strike** is on by default. Uncheck it if you want only Judgement readiness to trigger the selected button.
- **Holy Strike: Blizzard native glow** is off by default, with a teal custom color selected (`#00BFA5`). **Judgement: Blizzard native glow** is on by default. Each spell has its own color controls, and saved choices remain unchanged on upgrade.
- Uncheck a spell's native option, then choose its color below. Judgement's appearance takes priority whenever it is ready, including when Holy Strike is also ready. For example, set Judgement to red and leave Holy Strike teal: both ready means red; only Holy Strike ready means teal.
- Color changes update active glows immediately without replaying the flash. Cancel restores the previous custom color.
- You can choose a custom color while native mode is enabled; it is saved for later. Switching back to native retains that custom color.
- Unchecking the feature toggle immediately removes this feature's glow and stops its cooldown/button checks.
- Checking the feature toggle again immediately uses the selected position and reevaluates readiness. The Holy Strike/Judgement glow appears only in combat. The seal reminder also appears outside combat when your target or mouseover is a unit you can attack, including attackable neutral units and unit-frame mouseovers. Target changes refresh immediately; mouseover departure is also checked every 0.1 seconds.
- All preferences are saved account-wide across reloads and logouts. Existing installations default to enabled on upgrade.
- The panel is available on all characters; the glow feature still runs only for paladins.

## Exorcism glow

The **Exorcism** group has its own enable checkbox, action-bar/button selector, and native/custom color controls. It is enabled by default on **Bottom right bar → Button 5** with Blizzard's native glow. Select the physical button where you placed Exorcism if it is elsewhere.

The button glows only in combat when Exorcism is off cooldown and either your target or mouseover is a living unit you can attack whose creature type is **Demon** or **Undead**. With no living attackable target or mouseover unit, the icon keeps its normal color even while Exorcism is on cooldown. When at least one living attackable unit is present, the icon is desaturated to grayscale if the cooldown or eligible-target check fails, including outside combat; a ready spell with a valid target looks normal outside combat. This uses the action icon's `SetDesaturation` visual effect, as in GreyOnCooldown, instead of a grey overlay. It uses the locale-independent creature type ID returned by `UnitCreatureType` when available, with a localized-name fallback for clients that only provide the name. If the creature type is unreadable, the glow stays off and the selected button remains desaturated. As with the other attack glow, it does not check range, mana, or whether a cast would succeed. No spell is cast by the addon.

Exorcism has its own glow owner, so disabling or moving it does not remove another reminder. If reminders share a button, the seal reminder's color takes priority, then Exorcism, then Holy Strike/Judgement.

## Seal refresh reminder

In `/paf config`, check **Enable seal reminder** (enabled by default) inside the **Seal reminder** group, then choose its **Action bar** and **Button**. The default is **Bottom right bar → Button 4**, including when saved settings are missing. Its **Glow color** defaults to red and is independent of the Holy Strike color.

- A successful player seal cast starts a timer. **Remind after** defaults to **26 seconds**, configurable from 1–30 seconds. At that time the chosen button glows, giving 4 seconds before the assumed 30-second expiry with the default. Changing the setting recalculates the current timer from the last cast; casting any recognized seal resets it.
- New glows flash once in combat. Outside combat the seal glow starts directly in its loop. Entering combat does not reflash an existing glow; leaving combat cancels any unfinished flash.
- The glow appears in combat or with a living attackable target/mouseover unit. Casts while the reminder is hidden or disabled still update its timer. Losing the visibility condition hides the glow without resetting the timer.
- This is a refresh estimate, not an aura check: it never reads buff data and cannot detect an early dispel or manual removal. After login/reload or death, it assumes a refresh is due until it observes another seal cast.
- Successful cast events may themselves contain restricted values. Unreadable unit/spell data is ignored safely; such a cast cannot restart the timer. `/paf` reports ignored restricted casts for troubleshooting. Verify successful seal casts hide the reminder in your client, including in combat.
- Selection refers to a physical button position, not a spell or key binding. It stays on that position when you change bar pages or move spells. Only that selected, visible button is highlighted; it is up to you to keep your seal there. No binding or action is changed.
- If both reminders target the same button, the seal color takes priority while a seal refresh is due. When you cast a seal, the Holy Strike glow resumes if you are in combat and either tracked attack is ready.
- English spell names are supported across ranks: Righteousness, the Crusader, Command, Justice, Light, Wisdom, Fury, Blood, the Martyr, Vengeance and Corruption, all prefixed with “Seal of”. No cast is executed by the addon.

## Diagnostics

Type `/paf` to print the client build/interface, all selected bar/button positions, spell IDs, cooldown states and seal timer diagnostics. If a target says **not selected**, choose its bar and button in `/paf config`.

The manifest targets interface **16001**. If a later beta marks it outdated, compare the fourth value printed by `/run print(GetBuildInfo())` with the TOC's `## Interface` line before updating the manifest. Merely changing that number does not validate compatibility with API changes.

Cooldown APIs can return restricted values in combat. The service uses public state flags where available, retains event-authoritative GCD state between updates, and never performs arithmetic on secret values. Missing or unreadable data never independently triggers a glow. A readable, ready companion spell can still trigger it. A newly created button encountered in combat waits until combat ends to receive its glow overlay; icon desaturation needs no overlay.

## Glow rendering

Version 0.3.0 uses **LibCustomGlow-1.0**'s `ProcGlow_Start` / `ProcGlow_Stop`, with the native artwork, a combat-only initial flash and a looping animation, matching DK Force's renderer. It replaces the previous static border. The adapter uses a dedicated addon overlay and key, leaving Blizzard's own proc glow alone. Repeated updates do not restart the animation; it stops only when the last feature releases ownership.

The library copy is the same minor version 25 bundled with DK Force. See `PaladinAssistForever/Libs/README.md` for provenance and license notices. Existing settings are preserved when upgrading.

## Reuse and extension

Every file receives the private addon namespace through `local _, addon = ...`. Services contain no paladin spell names. Spell-specific rules live in `Features/HolyStrikeGlow.lua`, `Features/ExorcismGlow.lua`, and `Features/SealReminder.lua`.

| Module | Reusable interface | Responsibility |
| --- | --- | --- |
| `Services/Client.lua` | `SpellID(name)`, `SpellName(id)`, `IsKnown(id)`, `Cooldown(id)`, `Action(slot)`, `Readable(value)`, `HasGlowContext()`, `HasUnit(unit)`, `HasAttackableCreatureType(unit, types)` | Adapts modern APIs and available legacy equivalents; isolates client changes and guarded creature-type reads. |
| `Services/Macros.lua` | `Casts(body, spellName)` | Exact, case-insensitive matching of simple cast lines; never executes macros. |
| `Services/Buttons.lua` | `All()`, `FindSpell(spellName)`, `Bars()`, `Selected(bar, index)` | Enumerates default buttons and resolves current slots, including macros and paging. |
| `Services/Glow.lua` | `Prepare(button)`, `Set(button, owner, active, options)`, `ClearOwner(owner)`, `Configure(options)`, `ConfigureOwner(owner, options)` | Renders LibCustomGlow proc animations on reused addon-owned overlays. Multiple features may own one glow; one owner cannot clear another's request. |
| `Services/ButtonDesaturation.lua` | `Prepare(button)`, `Set(button, owner, active)`, `ClearOwner(owner)` | Desaturates the existing action icon to grayscale without changing action attributes or casting; multiple features can request it independently. |
| `Services/Cooldowns.lua` | `IsReady(spellID, cooldownEvent)`, `AnyReady(spellIDs, cooldownEvent)`, `Invalidate(spellID)` | Evaluates ordinary, non-charge spell cooldowns. `IsReady` returns true, false, or nil for unavailable data; `AnyReady` returns a boolean. |
| `Services/Timers.lua` | `New()` → `Start(seconds)`, `SetDuration(seconds)`, `IsDue()`, `Remaining()`, `Clear()` | Independent session timers; no aura reads. Missing timers are due. |
| `Services/Config.lua` | `Initialize()`, `Get(key)`, `GetDefault(key)`, `GetColor(key)`, `Set(key, value)`, `Subscribe(listener)` | Saves typed defaults and preferences; notifies consumers when a setting changes. |
| `Services/SettingsWidgets.lua` | `Section`, `Text`, `Checkbox`, `Dropdown`, `Color` | Reusable bordered settings groups and controls; setters use existing proxy settings. |
| `SettingsPanel.lua` | `Initialize()`, `Open()` | Registers a scrollable canvas in the native AddOns category, with a bordered group for each reminder. |
| `Core.lua` | `RegisterFeature(feature)` | Starts paladin features and calls `Refresh(discover, cooldownEvent)` only when their optional `settingKey` is enabled. Calls `Stop()` immediately when disabled. Optional `ApplySettings()` configures feature appearance; `OnEvent(event, ...)` continues observing events even while disabled. |

`Glow.Configure({ color = nil })` selects native artwork; pass `{ color = { r, g, b, a } }` for a shared custom tint. The service copies the color and updates active effects without replaying their initial flash. `Glow.Set` accepts optional `{ startAnim = false }` to skip or cancel startup animation; the seal feature uses this outside combat. Use `Glow.ConfigureOwner(owner, { color = ..., priority = ... })` for independent feature colors; higher priority wins on shared buttons, and owner names break ties deterministically. Saved preferences stay in Config; Glow remains independent of the settings panel.

Automatic spell discovery remains available as a reusable service for future features, but all current reminders use manual selection. A future feature can reuse discovery and rendering without copying them:

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

Load feature files after the services and before `Bootstrap.lua` in the TOC. Retain and clear previous button matches when a rule's target moves, as the shipped feature does. Glow overlays are allocated out of combat; the core also prepares icon desaturation on existing default buttons at login. `Glow.Set` starts/stops the library effect and shows/hides this addon's overlay, while `ButtonDesaturation.Set` updates the existing icon, preserving macro contents and action attributes. Event callbacks refresh promptly; the core polls cooldown expiry every 0.1 seconds and discovery every 0.5 seconds.

## Verification

Run from the repository root with Lua installed:

```sh
lua tests/run.lua
lua tests/glow_integration.lua
```

The tests run real services and feature code against small WoW API/frame doubles. They cover each OR combination, unknown/unlearned spells, cooldown expiry, GCD-only timing, restricted values, macro matching, live slot paging, shared glow ownership, combat allocation, manifest loading, paladin/non-paladin startup, enabled defaults, saved disabled preferences, immediate checkbox effects, re-enabling after moving the macro, and ownership isolation, combat entry/exit and enabling while outside combat. The separate integration script loads the actual bundled libraries against frame/pool doubles and checks proc animation startup, looping, cleanup, pooling, duplicate library loads, live custom tinting and restoring native artwork without restarting animations. These tests do not prove rendering or API behavior inside WoW Forever; in-game testing remains necessary.

In-game acceptance checks:

- Enable Lua errors with `/console scriptErrors 1`, then `/reload`.
- In combat, check that each newly activated glow flashes once, then loops without repeated startup flashes.
- With both attacks ready outside combat, confirm Holy Strike stays dark even with an attackable target or mouseover. Enter combat and confirm it glows; leave combat and confirm it clears. A due seal reminder should still glow outside combat with an attackable target/mouseover, and clear when neither qualifies.
- Put Holy Strike and Judgement on cooldown; confirm their glow disappears. When Judgement finishes first, confirm the button glows again. Confirm Holy Strike can also trigger it when it finishes first.
- In combat, check with no target, out of range and without enough mana. After combat the Holy Strike glow must remain hidden regardless of target, mouseover or readiness.
- Trigger only the global cooldown while both tracked abilities are otherwise ready; confirm no flicker where the client exposes the distinction.
- Move the macro or change bar pages; confirm the glow remains on the selected physical position. Change the selector to the new position and confirm the old glow clears immediately. Reload and confirm the selection persists.
- Log into a non-paladin; confirm no feature updates or glow.
- Open `/paf config`; disable the glow while it is visible and confirm it disappears immediately. Reload and confirm the checkbox remains off. Enable it again and confirm readiness is reflected immediately.
- Set Judgement to custom red. In combat, both ready should show red; only Holy Strike ready should show teal. Swap each native/custom option and confirm changes apply immediately without repeating the flash. Cancel a color change and reload to verify saved appearance.
- Uncheck **Check Holy Strike**: only Judgement readiness should trigger the glow, even when Holy Strike is ready. Re-enable it and confirm Holy Strike can trigger the glow again.
- With Exorcism ready, target a living attackable undead or demon in combat and confirm its selected button glows with a full-color icon. Repeat with only a mouseover. Switch to an attackable humanoid, or start Exorcism's cooldown with a living attackable unit selected: the glow should clear and the icon should turn grayscale. Switch to a friendly unit or dead enemy, or clear both target and mouseover: the icon should return to color, even if Exorcism is on cooldown. Outside combat with a valid target, the glow should be off and the icon should look normal. Disable the Exorcism setting and confirm the icon returns to color. If a beta treats creature type as restricted, the glow remains off for that unit and should not cause a Lua error.
- Choose your seal bar/button, cast a seal out of combat, enter combat, and confirm only the selected button turns red at the configured delay (26 seconds by default). Cast another seal and confirm the glow disappears immediately. Repeat the cast in combat to check event visibility in your client.
- Change the selected button and color, disable/re-enable the reminder, and confirm no leftover glow. Check the shared-button priority if you deliberately select the Holy Strike button.
- Report `/paf` output and any Lua error if a beta API differs.

## API references

- [Blizzard spell API source mirror](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [Cooldown structure and GCD event contract](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua)
- [Default action button implementation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua)
- [Forever interface 16001 in an existing addon's repository](https://github.com/TheMizeGuy/WowForeverTwitchEmotes)

- [Native Settings registration API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua)

- [Default action-bar combat visibility handling](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ActionBar/Shared/ActionBar.lua)

- [LibCustomGlow upstream](https://github.com/Stanzilla/LibCustomGlow)

- [Creature-type API and restricted-return contract](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Successful spell-cast event contract](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)

## Addon icon

Flat golden paladin-style hammer with transparent background, generated using the built-in image tool. The addon list and settings header use `PaladinAssistForever/Media/Icon.tga` (256×256 RGBA). The full-size PNG is `artwork/Paladin-flat.png`; a matching green hunter bow is `artwork/Hunter-flat.png`. Prompts and provenance are recorded alongside them. This is custom artwork, not Blizzard's class-icon asset.

Dead or ghost targets and mouseover units do not activate the seal reminder outside combat. Death is detected by the existing 0.1-second refresh; a living attackable companion target/mouseover can still qualify.
