# Paladin cooldown glow implementation plan

**Goal:** Glow the Holy Strike action when either of the two spells is ready.
**Architecture:** Client adapters feed reusable macro/button discovery and cooldown services; an owner-aware glow service renders results. A paladin feature and lifecycle core compose them.
**Tech stack:** WoW Lua, TOC manifest, standalone Lua regression tests.
**Spec:** ../../design.md

## Constraints
Paladins only; default action bars; cooldown-only OR condition; preserve macro and protected action attributes. Separate reusable services from spell-specific policy. Blank lines between logical blocks. No external dependencies.

- [x] Write tests/run.lua with the supplied macro, separate readiness combinations, moving/page-changing actions, shared glow ownership, unknown and restricted cooldown data, GCD handling and non-paladin startup. Run `lua tests/run.lua` and observe missing-feature failures.
- [x] Implement PaladinAssistForever/Services/{Client,Macros,Buttons,Glow,Cooldowns}.lua. Interfaces: Client.SpellID(name), Client.IsKnown(id), Client.Cooldown(id), Client.Action(slot); Macros.Casts(body,name); Buttons.FindSpell(name); Glow.Set(button,owner,active), Glow.ClearOwner(owner); Cooldowns.IsReady(id), Cooldowns.AnyReady(ids).
- [x] Implement Features/HolyStrikeGlow.lua with Refresh and Stop methods. Core.lua registers feature definitions; Bootstrap.lua starts them at PLAYER_LOGIN only for paladins, then services events and throttled updates.
- [x] Add manifest, README with setup, service interfaces, diagnostics and in-game acceptance checks. Run standalone regression tests and Lua syntax checks for every shipped Lua file. Inspect manifest load order and repository diff.
