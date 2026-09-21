# Paladin Assist Forever: first feature

Approved scope: paladin-only, default action bars, glow the Holy Strike macro button when Judgement OR Holy Strike is off cooldown. Ignore mana, range and target. Support the supplied #showtooltip holy strike /cast judgement /cast holy strike /startattack macro. Keep discovery and rendering reusable.

Use separate Lua modules for client API adaptation, macro matching, default button discovery, owner-scoped glow rendering, cooldown evaluation, and the paladin rule. A small core starts registered features only for paladins. No external libraries or protected button changes.

Ignore the global cooldown when distinguishable from the spell cooldown. Unknown/unlearned spells never count as ready. Unreadable cooldowns return unknown; another readable, ready spell can still trigger the glow. Match exact spell names in simple /cast lines, not arbitrary substrings. Do not execute or rewrite macros. Match direct Holy Strike actions too. Duplicate placements each receive the glow.

Prefer automatic discovery to a manually configured slot (which becomes stale when moving the macro). Prefer an addon-owned golden border to Blizzard's shared proc overlay (which other UI code can hide). Reuse one overlay per button and track feature owners so one feature cannot clear another feature's glow.

Refresh on action-bar, macro, spell and cooldown events, with a 0.1-second update for cooldown expiry and a 0.5-second discovery refresh for paging and late-created buttons. Pre-create overlays outside combat. Include a diagnostic slash command and installation/manual validation instructions. Current client compatibility must be verified in game; local tests use WoW API doubles.

## Configuration (0.2.0)

A native AddOns settings category exposes an enabled-by-default cooldown glow checkbox, accessible through `/paf config`. A generic Config service owns account-wide SavedVariables defaults and change subscribers. Features opt into settings through `settingKey`; the core calls their `Stop` method when disabled and performs fresh discovery on re-enable. Disabled features are skipped during event and polling updates. The panel remains accessible on non-paladins without starting feature updates.

## Combat-only glow (0.2.1)

The Holy Strike feature requests its glow only while `UnitAffectingCombat("player")` is true and either spell is ready. Combat entry and exit events trigger immediate refreshes. Cooldown event snapshots continue updating outside combat. Shared glow and cooldown services remain independent of this feature-specific visibility rule.
