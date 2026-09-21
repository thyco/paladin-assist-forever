# Paladin Assist Forever: first feature

Approved scope: paladin-only, default action bars, glow the Holy Strike macro button when Judgement OR Holy Strike is off cooldown. Ignore mana, range and target. Support the supplied #showtooltip holy strike /cast judgement /cast holy strike /startattack macro. Keep discovery and rendering reusable.

Use separate Lua modules for client API adaptation, macro matching, default button discovery, owner-scoped glow rendering, cooldown evaluation, and the paladin rule. A small core starts registered features only for paladins. No protected button changes. Rendering now uses bundled libraries as described in the 0.3.0 update below.

Ignore the global cooldown when distinguishable from the spell cooldown. Unknown/unlearned spells never count as ready. Unreadable cooldowns return unknown; another readable, ready spell can still trigger the glow. Match exact spell names in simple /cast lines, not arbitrary substrings. Do not execute or rewrite macros. Match direct Holy Strike actions too. Duplicate placements each receive the glow.

Prefer automatic discovery to a manually configured slot (which becomes stale when moving the macro). Prefer an addon-owned golden border to Blizzard's shared proc overlay (which other UI code can hide). Reuse one overlay per button and track feature owners so one feature cannot clear another feature's glow.

Refresh on action-bar, macro, spell and cooldown events, with a 0.1-second update for cooldown expiry and a 0.5-second discovery refresh for paging and late-created buttons. Pre-create overlays outside combat. Include a diagnostic slash command and installation/manual validation instructions. Current client compatibility must be verified in game; local tests use WoW API doubles.

## Configuration (0.2.0)

A native AddOns settings category exposes an enabled-by-default cooldown glow checkbox, accessible through `/paf config`. A generic Config service owns account-wide SavedVariables defaults and change subscribers. Features opt into settings through `settingKey`; the core calls their `Stop` method when disabled and performs fresh discovery on re-enable. Disabled features are skipped during event and polling updates. The panel remains accessible on non-paladins without starting feature updates.

## Combat-only glow (0.2.1)

Both features use `Client.HasGlowContext()`: combat, an attackable target, or an attackable mouseover unit. Holy Strike additionally requires either spell to be ready. Combat entry and exit events trigger immediate refreshes. Cooldown event snapshots continue updating outside combat. The shared visibility check reads no identity or aura data. Target/mouseover events refresh immediately, and polling handles mouseover departure.

## LibCustomGlow renderer (0.3.0)

Bundle the LibStub minor 2 and LibCustomGlow minor 25 files from DK Force without modification, with upstream and distribution license notices. Load them before addon modules. Keep the Glow service API and ownership model; replace the static texture with a keyed native proc animation on the existing addon-owned frame. Start the animation only on inactive-to-active transitions, and stop/release it only when the final owner clears. No spell rules, combat conditions or settings defaults change.

## Glow appearance settings (0.4.0)

Rename the feature toggle to the requested "Holy strike glow on Holy strike and judgement". Match DK Force's single proc style with a Use Blizzard native glow toggle (default true) and a custom RGB color picker. Preserve existing enabled preferences and saved custom colors. Color selection does not silently toggle native mode, so cancel remains predictable. Store validated opaque ARGB hex strings compatible with native Settings color swatches. Core translates saved preferences into generic Glow.Configure options; the renderer updates active effects in place without restarting their initial animation.


## Seal reminder (0.5.0)

A second independently enabled feature tracks readable successful player seal casts, across ranks by English spell name. Its session timer becomes due at 27 seconds, ahead of the user-specified 30-second duration. It does not query auras or infer restricted data. Unknown initial state after reload and death are treated as due; early dispels cannot be detected. Secret successful-cast payloads are skipped and counted in diagnostics.

Selection is one physical default bar/button, configured through two native dropdowns. No target is selected by default; the feature defaults enabled and red. It shows in combat or with an attackable target/mouseover unit, and observes casts while disabled or hidden. Shared overlay ownership now supports per-owner tint and deterministic priority: seal reminder priority 10 overrides the default Holy Strike style until the seal request clears.

Reusable components: `Timers.New` returns independent deadline timers; `Buttons.Selected` resolves a physical position; `Glow.ConfigureOwner` assigns feature appearance; `Core.OnEvent` forwards observations separately from enabled-only rendering. Only player successful-cast events are subscribed; existing bar discovery cadence is retained.
