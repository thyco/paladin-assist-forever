# Righteous Fury popup reminder

## Intent and scope

Add a paladin-only, free-floating Righteous Fury reminder to Paladin Assist Forever. Its icon appears with the existing LibCustomGlow proc effect when Righteous Fury is absent or has at most five minutes remaining, and only while a shield is equipped. The icon is visual only: it does not cast, target, or change an action button. It can be dragged and resized, with its position and size stored in the addon settings.

The normal reminder is visible in and out of combat. A temporary positioning preview in the settings panel may show the icon without a shield or a due reminder; leaving the panel ends the preview. The feature is enabled by default. The popup uses the spell's own icon and Blizzard-native glow by default.

## State and timing

The spell is assumed to last 30 minutes. A successful player `UNIT_SPELLCAST_SUCCEEDED` event for Righteous Fury starts a session-local 25-minute timer. The feature observes casts even while its popup is disabled, as the seal reminder does. A new cast restarts the timer. Death marks the reminder due, subject to the next readable aura check.

When Righteous Fury's player aura is accessible, the addon reads its expiration time and sets the reminder deadline to `expirationTime - 300` seconds. This recovers the actual remaining time after login or reload and corrects timer drift or early removal. A readable check that finds no buff makes the reminder due immediately. Following an observed cast, aura absence is ignored briefly so the client can publish the new buff before it is treated as missing.

When the client provides a per-spell secrecy check, aura queries are attempted only when it says Righteous Fury is readable. On clients without that check, the adapter attempts a guarded lookup only outside combat. It guards returned aura values and handles an unavailable API or rejected lookup without a Lua error. While the aura is restricted, the feature uses its last event-derived timer. If neither a readable aura nor an observed cast provides timing, the reminder is due until better information arrives. Readable aura state takes precedence over a prior estimate. The feature never branches on a secret value.

## Shield eligibility

The client adapter checks the player's off-hand equipment slot (17). An item qualifies only when its instant item data reports `INVTYPE_SHIELD`. Missing, unreadable, or non-shield equipment hides the normal popup. Equipment changes refresh the reminder immediately; ordinary polling also recovers from missed or delayed item data. The timer continues while the popup is hidden, so equipping a shield later reveals an already-due reminder.

## Popup and configuration

A reusable popup-icon service owns an unprotected frame under `UIParent`, its spell texture, size, position, visibility, and drag handling. It prepares the existing reusable glow overlay before combat; `LibCustomGlow-1.0` renders the effect. A newly shown reminder flashes if combat is active and starts directly in its loop outside combat. An already visible reminder does not flash again on combat entry, matching the seal reminder. Hiding or disabling the popup releases only its own glow owner.

The popup starts at 64 pixels square near the center of the screen, clamped to the screen edges. Dragging it with the left mouse button saves its center-relative position. The settings panel gains a bordered **Righteous Fury** section with an enable checkbox, a size control covering 32–128 pixels, and a temporary **Preview and position** control. Settings changes apply immediately. Preview is for placement only and never indicates buff status; it ends when the settings panel closes.

The feature module owns the Righteous Fury name, cast matching, timer, and due rule. Reusable services contain no paladin spell names. The existing `Timers`, `Glow`, `Config`, and settings-widget services are extended only where needed. No aura data is saved to disk; only preferences and popup placement persist.

## Validation

Add behavior tests for readable present and absent auras, the five-minute boundary, reload recovery, restricted aura fallback, cast resynchronization, death, shield versus other off-hand items, equipment changes, disabled behavior, popup drag/size persistence, preview lifecycle, and paladin-only startup. Run the complete Lua test suite and bundled-glow integration tests. In the Forever beta, manually verify aura access outside combat, a cast during combat, shield swapping, drag and resize persistence, and the no-shield hidden state. The addon must produce no cast or action-button automation.

## Client API basis and limits

Blizzard's generated API documents `C_UnitAuras.GetPlayerAuraBySpellID` as restricted when unit auras are restricted: <https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua>. Instant item data provides the equipment location: <https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua>. The Forever beta must confirm these APIs' runtime behavior for Righteous Fury. A timer cannot detect an early dispel or manual cancellation while the aura is secret; the next readable aura check corrects it.
