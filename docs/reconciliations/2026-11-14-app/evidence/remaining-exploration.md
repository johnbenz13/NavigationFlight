# Remaining exploration — observation ledger

[Back to the map](../README.md) · [Owner's review order](../review.md#remaining-product-exploration)

John requested this follow-up after approving S01–S56. Existing gap decisions remain
pending until product exploration finishes. This ledger records each remaining branch
as observed or bounded by a named limitation. The reachable follow-up pass is complete;
partial and unverified rows below remain explicit validation limits, not accepted behavior. Source inspection is
preparation only; it never substitutes for a runtime observation.

## Flight Plans and ready navigation

| Branch | Status | Evidence or limit |
| --- | --- | --- |
| Multiple saved plans and ordering | Observed | S66: import-recency order with three plans. |
| Loaded-version identity after replacement | Observed | S68: newer saved revision loses exact-loaded badge; Continue and Load Updated Plan are distinct. |
| Different-plan load with protected work | Observed | S67: confirmation, cancel, and confirmed replacement. |
| Cancellation preserves edits/checklist | Observed | S67: open heading draft and checklist chip retained; exhaustive draft combinations not claimed. |
| Save failure preserves an existing plan | Observed | S69: existing12:01 retained after injected failure. |
| Load Updated Plan action | Observed | S91: protected confirmation, cancel retains review, confirm opens Ready. |
| Import through the system Files picker | Observed | S75: real Downloads selection, save, review and load of exact synthetic attachment. |
| Choose a starting leg | Observed discrepancy | S57: Ready Leg2 becomes Active Leg1 on direct Start; G20. |
| Choose an available calculation mode before Start | Observed discrepancy | S76: selected No wind ETA changes to Wind at Start; checklist/console headings disagree. G20. |

## Active navigation and map

| Branch | Status | Evidence or limit |
| --- | --- | --- |
| Revert committed heading/ETA | Observed available controls | S58/S63: baseline-valued commits remain Revised; no dedicated Revert offered. |
| Reject a draft ETA behind elapsed time | Observed | S59: stale draft Commit disabled as moving minimum advances. |
| Reach Undo expiry | Observed | S60: disappears after twenty-one-second wait in foreground. |
| Later state action invalidates Undo | Observed | S64: successor heading commit removes earlier Undo at elapsed00:03. |
| Duplicate reach attempt | Partly observed | S65: duplicate Undo-location tap has no repeat action. Simultaneous duplicate reach is not established. |
| Map focus and transient controls | Partly observed | S62: Whole Active Leg recenters; Destination focus has no visible effect in bounded attempts; S85: controls disappear after six seconds. |
| Planned VOR label dragging | Observed | S62: visible grip moves label; hierarchy hitpoint instead pans map. |
| Skip an IP and inspect its history | Observed | S80: Passed without report, no timestamp/Actual ETA, no revision action. |
| Review completed revisions and requested Check | Observed discrepancy | S83: heading retained; ETA revision/reference not shown; early delta compares hidden revision. Settled panel scroll adds no fields; completed editor cannot be reopened in bounded attempts. G23. |
| Operational cue transitions | Partly observed | S84: altitude DUE, later altitude/frequency values, offscreen update without replay. Exact brief frequency/simultaneous emphasis and announcements unverified. |
| Manual progression | Observed | S82: successor ready00:00, explicit Start activates leg2. Debug-only policy. |

## Position Check

| Branch | Status | Evidence or limit |
| --- | --- | --- |
| On-track guidance | Observed | S71: position without a corrective course. |
| Position without guidance | Observed | S71: position retained; recovery guidance unavailable. |
| No sensible forward intercept | Observed | S71: review plan, no backward intercept. |
| Extreme displacement | Observed | S71: outside range, no tactical course/time. |
| Permission revoked during disclosure | Observed | S74: synthetic revocation clears disclosure, GPS Gap; G18 map collapse. |
| Retry after acquisition failure | Observed attempt | S73 plus batch17: fresh exact-control hold/tap leave timeout unchanged; G22. Successful live recovery unverified. |
| Repeat hold during active disclosure | Observed, bounded | S86: second hold retains10s, rotation shows7s. Exact extended deadline/nonstacking not isolated. |
| Leave Cockpit during disclosure | Observed | S72: fresh disclosure clears on immediate tab return; G18 map collapse. |
| Background during disclosure | Observed | S72: fresh disclosure clears; G14 annotation loss. |
| Real system permission recovery | Unverified after bounded attempt | S92: real location-service launch without a new prompt; Settings attempt loses simulator session. No permissions changed; denial/regrant remains unverified. |

## Recordings and recovery

| Branch | Status | Evidence or limit |
| --- | --- | --- |
| Action-only recording from Start to close | Observed | S81: Complete/Manual/GPSUnavailable after completed navigation; no GPX export. Stale continuation wording G19. |
| Durable recording checkpoint after relaunch | Observed, bounded | S79: actual disk checkpoint restores356° and continuing elapsed time; map collapses. Clean relaunch, not crash/reboot/long-duration durability. |
| Recovery expiry/stale Continue | Observed, bounded | S78: natural foreground expiry closes recording and removes gate, but omits result explanation (G11). Exact concurrent tap/background boundary unverified. |
| Choose one of multiple recovery candidates | Observed discrepancy | S77: direct resume and other candidate closed as superseded, without confirmation; G12. |
| Retry after export/delete failure | Observed attempts, bounded | S93: export Retry and repeated confirmed deletion retain detail without renewed visible error/share. Successful recovery after clearing the static fault and package persistence remain unverified. |
| Retry after failed recording closure | Unobserved: no existing launch hook | RootView injects create/remove failure only; close-failure support exists in test store but is not wired to runtime setup. No claim about observed retry UI. |
| Exported GPX contents | Observed, bounded | S70: retained UI-export file parses; expected metadata and two points. Gap segmentation/invalid-value omission unverified. |

## Devices and interaction variants

| Branch | Status | Evidence or limit |
| --- | --- | --- |
| Real-chart route | Observed | S75–76: synthetic Editor route over bundled chart in ready and active states. |
| Canonical iPhone 16 Pro active workflows | Environment unavailable; substitute observed | Tool rejects16Pro. S90 observes iPhone17 checklist, active cues, Position Check and heading editor; G24 missing header. Canonical acceptance remains open. |
| iPad landscape active workflows | Observed, representative | S86: active disclosure, timer, right console and later altitudeDUE. Full editor/layout matrix unverified. |
| VoiceOver interactions/announcements | Partly observed | S88: actual On, control focus, default-action attempt remains Ready, restoredOff. No audio; activation/focus-order usability unverified. |
| Reduce Motion | Observed, bounded | S87: actual On, successful disclosure, restoredOff. Still frames cannot verify all animation behavior. |
| Window resizing | Unverified after bounded attempt | S89: activating SpringBoard-owned resize handle sends Home before drag; no verified app resize. |

Real sensor accuracy, physical landing/takeoff, prolonged background/lock acquisition,
real disk exhaustion and exhaustive timing races remain validation limits. They do not
silently block all product mapping, and no fixture screenshot certifies those guarantees.

## Boundaries of the existing reproduction setup

Read-only source inspection identifies limits; it does not establish product behavior:

- Low-storage launch input sets a presentation status. Degradation input adds a
  track-write-failure event; neither reproduces genuine exhausted storage.
- Injected export/delete failure persists for that launch. A later successful launch
  cannot establish recovery of the same interrupted operation after the fault clears.
- Permission-required input always emits denied. A real permission-recovery observation
  must omit that fixture and exercise CoreLocation and system Settings.
- A synchronized competing-reach race has no existing hook. A bounded second tap is
  useful interaction evidence but cannot establish exhaustive idempotency under races.
- Existing lifecycle input can potentially generate multiple GPS segments. Existing
  position-only input omits groundspeed. No existing fixture supplies every invalid or
  nonfinite GPX field; full serialization edge coverage remains separate validation.
